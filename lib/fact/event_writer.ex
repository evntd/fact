defmodule Fact.EventWriter do
  @moduledoc false
  
  defdelegate write_event(path, event), to: Fact.EventWriter.Json, as: :write
  
end
