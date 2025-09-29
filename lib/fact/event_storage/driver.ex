defmodule Fact.EventStorage.Driver do
  @moduledoc false

  @type record_id :: String.t()
  @type record_data :: binary
  @type event :: map
  @type encode :: (map -> binary)

  @callback prepare_record(event, encode) :: {record_id, record_data}
  @callback record_id_length() :: integer
end
