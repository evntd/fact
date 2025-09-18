defmodule Fact.EventWriter do
  @moduledoc false
  use Fact.EventKeys

  def db_dir, do: Application.get_env(:fact, :db)

  def write_event(event) do
    path = Path.join(db_dir(), event[@event_id])
    do_write_event(path, event)
  end

  defdelegate do_write_event(path, event), to: Fact.EventWriter.Json, as: :write
end
