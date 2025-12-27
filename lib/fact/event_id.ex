defmodule Fact.EventId do
  use Fact.Seam.EventId.Adapter

  def generate(%Context{event_id: instance}) do
    __seam_call__(instance, :generate, [])
  end
end
