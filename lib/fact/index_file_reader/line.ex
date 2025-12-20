defmodule Fact.IndexFileReader.Line do
  @mode [:raw, :read, :binary]

  def forward(path, from_position, record_size) do
    line_length = record_size + 1

    Stream.resource(
      fn ->
        record_count = File.stat!(path).size |> div(line_length)

        start_position =
          cond do
            from_position === :start ->
              0

            from_position === :end ->
              record_count

            true ->
              from_position
          end

        {:ok, fd} = File.open(path, @mode)
        {:ok, _pos} = :file.position(fd, start_position * line_length)
        fd
      end,
      fn fd ->
        case :file.read(fd, line_length) do
          {:ok, data} ->
            <<event_id::binary-size(record_size), _newline::binary>> = data
            {[event_id], fd}

          :eof ->
            {:halt, fd}
        end
      end,
      &File.close/1
    )
  end

  def backward(path, from_position, record_size) do
    line_length = record_size + 1

    Stream.resource(
      fn ->
        record_count = File.stat!(path).size |> div(line_length)

        start_position =
          cond do
            from_position === :start -> 0
            from_position <= 0 -> 0
            from_position > record_count -> record_count
            from_position === :end -> record_count
            true -> from_position
          end

        {:ok, fd} = File.open(path, @mode)
        {fd, line_length * (start_position - 1)}
      end,
      fn
        {fd, offset} when offset < 0 ->
          {:halt, fd}

        {fd, offset} ->
          case :file.pread(fd, offset, record_size) do
            {:ok, data} ->
              {[data], {fd, offset - line_length}}

            :eof ->
              {:halt, fd}
          end
      end,
      &File.close/1
    )
  end
end
