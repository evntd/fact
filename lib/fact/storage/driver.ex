defmodule Fact.Storage.Driver do
  @moduledoc """
  Defines the behaviour for storage drivers used by the `Fact` event storage
  system.

  A storage driver is responsible for converting events into persistable
  records—including generating record identifiers—and reporting structural
  properties of those records. Implementations of this behaviour are used
  by `Fact.Storage` to encode, store, and retrieve events in a backend-agnostic way.

  Any module implementing this behaviour must define how to:

    * prepare a record for storage, given a raw event and an encoding function
    * specify the fixed length (in characters or bytes, depending on backend)
      of record identifiers
  """
  @type record_id :: String.t()
  @type record_data :: binary
  @type event :: map
  @type encode :: (map -> binary)

  @doc """
  Converts an event into a persistable record.

  Implementations must return a tuple `{record_id, record_data}`, where:

    * `record_id` — a unique identifier for the stored record, whose length
      must match the value returned by `c:record_id_length/0`.
    * `record_data` — the encoded representation of the event, typically a binary.

  The `encode` function provided by the caller should be used to transform the
  event into its binary representation (e.g., JSON, MessagePack, etc.).

  ## Callback Signature

      @callback prepare_record(event, encode) :: {record_id, record_data}
  """
  @callback prepare_record(event, encode) :: {record_id, record_data}

  @doc """
  Returns the expected length of all record identifiers produced by the driver.

  This allows storage backends to use fixed-width identifiers, which can
  simplify indexing and improve performance in certain implementations.

  ## Callback Signature

      @callback record_id_length() :: integer
  """
  @callback record_id_length() :: integer
end
