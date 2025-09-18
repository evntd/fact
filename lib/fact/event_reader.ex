defmodule Fact.EventReader do
  @moduledoc false
  defdelegate read_event(path), to: Fact.EventReader.Json, as: :read
end
