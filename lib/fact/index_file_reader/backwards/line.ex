defmodule Fact.IndexFileReader.Backwards.Line do
  @moduledoc false

  # a base16 encoded guid string with a newline
  @line_size 33

  def read(path) do
    size = File.stat!(path).size
    total = div(size, @line_size)

    Stream.unfold(total - 1, fn
      -1 ->
        nil

      idx ->
        {:ok, {:ok, data}} =
          File.open(path, [:raw, :read], fn fd ->
            :file.pread(fd, idx * @line_size, @line_size)
          end)

        <<event_id::binary-size(32), _newline::binary>> = data
        {event_id, idx - 1}
    end)
  end
end
