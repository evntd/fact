defmodule Fact.EventPublisher do
  @moduledoc false

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  def start_link(_opts) do
    :pg.start_link()
    {:ok, self(), :ignore}
  end

  def subscribe(instance, pid) do
    :pg.join(group_name(instance), pid)
  end

  def publish(instance, event_ids) do
    subscribers = get_members(instance)

    Enum.each(event_ids, fn event_id ->
      record = Fact.Storage.read_event(instance, event_id)
      Enum.each(subscribers, &send(&1, {:appended, record}))
    end)

    :ok
  end

  defp get_members(instance) do
    :pg.get_members(group_name(instance))
  end

  defp group_name(instance) do
    Fact.Names.subscription(instance)
  end
end
