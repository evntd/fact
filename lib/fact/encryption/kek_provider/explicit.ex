defmodule Fact.Encryption.KEKProvider.Explicit do
  @moduledoc """
  A `Fact.Encryption.KEKProvider` that takes the KEK directly from the options.

  This is the simplest provider — the caller supplies the key material when opening
  the database. Key sourcing (environment variables, vault clients, config files) is
  the caller's responsibility.

  ## Examples

      Fact.open("data/turtles",
        encryption: [
          kek_provider: Fact.Encryption.KEKProvider.Explicit,
          kek: System.fetch_env!("FACT_KEK") |> Base.decode64!()
        ]
      )
  """
  @moduledoc since: "0.4.0"

  @behaviour Fact.Encryption.KEKProvider

  @doc """
  Fetches the KEK from the `:kek` option.

  Expects `opts` to contain a `:kek` key with a binary value of 16, 24, or 32 bytes
  (corresponding to AES-128, AES-192, or AES-256).
  """
  @doc since: "0.4.0"
  @impl true
  @spec fetch_kek(keyword()) :: {:ok, binary()} | {:error, term()}
  def fetch_kek(opts) do
    case Keyword.fetch(opts, :kek) do
      {:ok, kek} when is_binary(kek) and byte_size(kek) in [16, 24, 32] ->
        {:ok, kek}

      {:ok, kek} when is_binary(kek) ->
        {:error, {:invalid_kek_size, byte_size(kek)}}

      {:ok, _} ->
        {:error, :kek_must_be_binary}

      :error ->
        {:error, :kek_not_provided}
    end
  end
end
