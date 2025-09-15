defmodule Fact.FileReader do
  @moduledoc false

  def read_forward(path) do
    File.stream!(path) |> Stream.map(&String.trim/1)
  end

  def read_backward(path), do: read_backward_by_line(path)

  defp read_backward_by_line(path) do
    # a base16 encoded guid string with a newline
    line_size = 33
    size = File.stat!(path).size
    total = div(size, line_size)

    Stream.unfold(total - 1, fn
      -1 ->
        nil

      idx ->
        {:ok, {:ok, data}} =
          File.open(path, [:raw, :read], fn fd -> :file.pread(fd, idx * line_size, line_size) end)

        <<event_id::binary-size(32), _newline::binary>> = data
        {event_id, idx - 1}
    end)
  end
end
