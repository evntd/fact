# Encryption at Rest

This guide explains Fact's encryption-at-rest feature, which protects event record files on disk using
authenticated encryption. It covers the motivation, how to create and open an encrypted database, key
management, and recovery procedures.

At a high level:

- Event record files are encrypted using **AES-256-GCM** (authenticated encryption)
- Encryption is configured at **database creation time** and backed by the seam architecture
- Keys use **envelope encryption** — a Data Encryption Key (DEK) encrypts records, and a Key Encryption
  Key (KEK) wraps the DEK
- The DEK never appears in plaintext on disk
- A **recovery KEK** is required at creation time to prevent permanent data loss

## Motivation

Event stores accumulate history that is never deleted. This makes them high-value targets for data
exfiltration — a single disk image or backup copy exposes every event ever written. Encryption at rest
ensures that even if the underlying storage is compromised, the event data remains unreadable without
the encryption key.

Fact encrypts at the **record file level**. Each event record file on disk is individually encrypted with
its own random nonce, providing strong confidentiality guarantees even if an attacker obtains partial
access to the storage directory.

Ledger files, index files, checkpoint files, and lock files are **not encrypted**. These contain only
record IDs (opaque identifiers) and operational metadata, not event payloads.

## Envelope Encryption

Fact uses envelope encryption with two layers of keys:

- **Data Encryption Key (DEK)** — A 256-bit key generated at database creation time. Used to encrypt
  and decrypt every event record file. One DEK per database.
- **Key Encryption Key (KEK)** — Supplied by the operator at runtime. Wraps (encrypts) the DEK so it
  can be stored safely on disk. Never touches disk in plaintext.
- **Recovery KEK** — A second KEK that can also unwrap the DEK. Required at creation time. Stored
  separately by the operator for disaster recovery.

The wrapped DEK (encrypted with both the primary and recovery KEKs) is stored in the `.bootstrap` file
alongside the database configuration. The KEKs themselves are never written to disk.

```
              ┌────────────────┐
              │  Primary KEK   │ (runtime only, never on disk)
              └────────┬───────┘
                       │ wraps
                       ▼
              ┌────────────────┐
              │      DEK       │ (wrapped form stored in .bootstrap)
              └────────┬───────┘
                       │ encrypts
                       ▼
              ┌────────────────┐
              │  Record Files  │ (encrypted on disk)
              └────────────────┘
```

## Creating an Encrypted Database

Use `mix fact.create` with the `--encrypted` flag:

```sh
$ mix fact.create -p data/secure_turtles --encrypted
```

The primary key and recovery key are **generated automatically** and displayed in the output:

```
  ================================================================
   🔐 ENCRYPTION KEYS — SAVE THESE NOW
  ================================================================

       KEY: dGhpcyBpcyBhIHNhbXBsZSBrZXkgZm9yIGRvY3M=
  RECOVERY: cmVjb3Zlcnkga2V5IGZvciBkb2NzIHNhbXBsZQ==

  ================================================================

   Store the key securely (secrets manager, environment variable).
   Store the recovery key separately in a safe, offline location.

   These keys will NOT be shown again. If you lose both keys,
   your data is unrecoverable.
  ================================================================
```

You can also provide your own keys via `--key` and `--recovery-key` (base64-encoded, 16, 24, or
32 bytes decoded):

```sh
$ mix fact.create -p data/secure_turtles --encrypted \
    --key=$MY_KEY \
    --recovery-key=$MY_RECOVERY_KEY
```

Store the primary key securely (e.g., in a secrets manager or vault). Store the recovery key
in a separate, offline location (e.g., a printed key in a safe, a hardware security module).

## Opening an Encrypted Database

Supply the base64-encoded key via the `:encryption_key` option. The bootstrapper reads the
wrapped DEK from the `.bootstrap` file automatically — you only need to provide the key itself:

```elixir
{:ok, db} = Fact.open("data/secure_turtles",
  encryption_key: System.fetch_env!("FACT_KEY")
)
```

### In a Supervision Tree

```elixir
# application.ex
def start(_type, _args) do
  children = [
    {Fact.Supervisor,
      databases: [
        {"data/secure_turtles",
          encryption_key: System.fetch_env!("FACT_KEY")}
      ]}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

## KEK Providers

For advanced use cases (vault integrations, per-database key resolution), Fact supports a provider
behaviour (`Fact.Encryption.KEKProvider`). The `:encryption_key` option uses the built-in
`Fact.Encryption.KEKProvider.Explicit` provider under the hood.

Custom providers can integrate with external key management systems:

```elixir
defmodule MyApp.VaultKEKProvider do
  @behaviour Fact.Encryption.KEKProvider

  @impl true
  def fetch_kek(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    {:ok, MyApp.Vault.get_key("fact/#{database_id}/kek")}
  end
end
```

```elixir
Fact.open("data/secure_turtles",
  encryption: [
    kek_provider: MyApp.VaultKEKProvider,
    database_id: "my_db"
  ]
)
```

## Recovery

If the primary key is lost or compromised, use the `mix fact.recover` task with the recovery key.
This task generates a new DEK, a new primary key, and a new recovery key, then re-encrypts all
record files in place.

```sh
$ mix fact.recover -p data/secure_turtles --recovery-key=$RECOVERY_KEY
```

The recovery task will:

1. Unwrap the existing DEK using the recovery key
2. Decrypt all record files with the old DEK
3. Generate a new DEK, primary key, and recovery key
4. Re-encrypt all record files with the new DEK
5. Update the `.bootstrap` file with the new wrapped DEKs
6. Display the new keys

The recovery key **cannot** be used directly with `Fact.open`. Recovery is an offline operation
that must be performed while the database is not running. This ensures the key rotation is atomic
and no reads or writes occur with stale keys.

## File Format

Each encrypted record file has the following binary layout:

```
┌──────────┬──────────────┬─────────────────┐
│  Nonce   │  Auth Tag    │   Ciphertext    │
│ 12 bytes │  16 bytes    │   variable      │
└──────────┴──────────────┴─────────────────┘
```

- **Nonce** (12 bytes) — A random initialization vector, unique per file. Generated using
  `:crypto.strong_rand_bytes/1`.
- **Auth Tag** (16 bytes) — The GCM authentication tag. Verifies that the ciphertext has not been
  tampered with.
- **Ciphertext** (variable) — The encrypted event record payload.

Since record files are write-once (WORM), each file gets a unique nonce at write time. Nonce reuse
is impossible under normal operation.

## What is Not Encrypted

The following files remain in plaintext:

| File Type | Contents | Why Not Encrypted |
|-----------|----------|-------------------|
| `.bootstrap` | Database config + wrapped DEK | Must be readable to bootstrap |
| `.ledger` | Record IDs (opaque identifiers) | Performance; no event payloads |
| Index files | Record IDs grouped by dimension | Performance; no event payloads |
| Checkpoint files | Integer positions | Operational metadata only |
| Lock files | Process metadata | Operational metadata only |

Record IDs are opaque strings (UUIDs or content hashes) that do not reveal event content. The ledger
and index files enable efficient reads without decrypting every record on disk.

## Security Considerations

- **Key storage**: Never commit KEKs to source control or store them alongside the database. Use a
  secrets manager, environment variables injected at deploy time, or a hardware security module.
- **Key rotation**: The DEK is permanent for the lifetime of the database. To rotate the KEK, unwrap
  the DEK with the old KEK, re-wrap with a new KEK, and update the bootstrap file.
- **Backup encryption**: Database backups created with `mix fact.backup` include encrypted record files
  as-is. The backup is only useful to someone who also has the KEK.
- **Memory**: The DEK is held in memory by the `Fact.KeyRing` process for the lifetime of the database.
  It is not written to disk or logged.
