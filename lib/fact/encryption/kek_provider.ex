defmodule Fact.Encryption.KEKProvider do
  @moduledoc """
  Behaviour for providing Key Encryption Keys (KEKs) at runtime.

  A KEK provider is responsible for supplying the key used to unwrap the
  Data Encryption Key (DEK) when a database is opened. The DEK is stored
  in the `.bootstrap` file in wrapped (encrypted) form and must be unwrapped
  before the database can read or write encrypted record files.

  ## Implementations

    * `Fact.Encryption.KEKProvider.Explicit` — takes the KEK directly from options.
  """
  @moduledoc since: "0.4.0"

  @typedoc """
  A module implementing the `Fact.Encryption.KEKProvider` behaviour.
  """
  @typedoc since: "0.4.0"
  @type t :: module()

  @typedoc """
  Options passed to `c:fetch_kek/1`. The shape depends on the provider implementation.
  """
  @typedoc since: "0.4.0"
  @type opts :: keyword()

  @doc """
  Fetches the Key Encryption Key.

  Returns `{:ok, kek}` where `kek` is a binary encryption key, or
  `{:error, reason}` if the key cannot be retrieved.
  """
  @doc since: "0.4.0"
  @callback fetch_kek(opts()) :: {:ok, binary()} | {:error, term()}
end
