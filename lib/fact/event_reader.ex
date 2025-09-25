defmodule Fact.EventReader do
  @moduledoc false

  def read_event(event_id) do
    do_read_event(Path.join(db_dir(), event_id))
  end

  defdelegate do_read_event(path), to: Fact.EventFileReader.Json, as: :read

  defp db_dir, do: Application.get_env(:fact, :db)
end
