defmodule Fact.IndexFileReader do
  @moduledoc false
  
  @event_id_length 32

  def read_forward(path) do
    File.stream!(path) |> Stream.map(&String.slice(&1,0,@event_id_length))
  end

  defdelegate read_backward(path), to: Fact.IndexFileReader.Backwards.Line, as: :read
end
