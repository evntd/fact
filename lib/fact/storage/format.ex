defmodule Fact.Storage.Format do
  @moduledoc """
  Behaviour definition for event encoding and decoding formats used by
  `Fact.Storage`.

  A storage *format* is responsible for converting event records between:

    * their in-memory Elixir representation (maps), and  
    * their on-disk binary representation (strings or raw bytes).

  Fact uses pluggable formats so that applications may choose how events are
  serialized. This enables JSON, MessagePack, binary formats, encrypted formats,
  or custom domain-specific encodings.

  ## Implementing a Format

  To define a format, implement the callbacks in this behaviour:

      defmodule MyApp.CustomFormat do
        @behaviour Fact.Storage.Format

        @impl true
        def encode(event_map) do
          :erlang.term_to_binary(event_map)
        end

        @impl true
        def decode(binary_data) do
          try do
            {:ok, :erlang.binary_to_term(binary_data)}
          rescue
            e -> {:error, e}
          end
        end
      end

  Once defined, the format can be supplied when starting a Fact instance:

      Fact.start_link(:my_instance, format: MyApp.CustomFormat)

  ## Contract

  The callbacks must obey these rules:

    * `encode/1`  
      Accepts an event represented as a map and returns a binary suitable for
      file system storage.

    * `decode/1`  
      Accepts a binary produced previously by `encode/1` and returns:

        * `{:ok, map()}` on successful decoding  
        * `{:error, term()}` if decoding fails for any reason

      Implementations should **never raise**—errors must be represented
      explicitly via `{:error, term()}`.

  ## Built-in Formats

  Fact ships with a JSON implementation:

      Fact.Storage.Format.Json

  This is suitable for most applications and is often used as the default.

  ## Examples

  Encoding an event:

      iex> MyFormat.encode(%{type: "UserRegistered"})
      <<...binary...>>

  Decoding an event:

      iex> MyFormat.decode(binary)
      {:ok, %{type: "UserRegistered"}}

  """

  @callback encode(map()) :: binary()
  @callback decode(binary()) :: {:ok, map()} | {:error, term()}
end
