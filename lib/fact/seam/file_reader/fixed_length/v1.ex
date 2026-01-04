defmodule Fact.Seam.FileReader.FixedLength.V1 do
  use Fact.Seam.FileReader,
    family: :fixed_length,
    version: 1

  import Fact.Seam.Parsers, only: [parse_pos_integer: 1, parse_non_neg_integer: 1]

  @enforce_keys [:length, :padding]
  defstruct [:length, :padding]

  @modes [:raw, :read, :binary]
  @default_direction :forward
  @default_position :start

  @impl true
  def default_options(), do: %{length: nil, padding: 0}

  @impl true
  def option_specs() do
    %{
      length: %{
        allowed: :any,
        parse: &parse_pos_integer/1,
        error: :invalid_length
      },
      padding: %{
        allowed: :any,
        parse: &parse_non_neg_integer/1,
        error: :invalid_padding
      }
    }
  end

  @impl true
  def read(%__MODULE__{length: length, padding: padding}, path, options) do
    direction = Keyword.get(options, :direction, @default_direction)
    from_position = Keyword.get(options, :position, @default_position)
    stream = read(path, direction, from_position, length, padding)
    {:ok, stream}
  end

  defp read(path, :forward, from_position, record_size, padding) do
    line_size = record_size + padding

    Stream.resource(
      fn ->
        with {:ok, stat} <- File.stat(path) do
          start_position =
            cond do
              from_position === :start ->
                0

              from_position === :end ->
                div(stat.size, line_size)

              true ->
                from_position
            end

          start_offset = line_size * start_position

          case File.open(path, @modes) do
            {:ok, fd} ->
              case :file.position(fd, start_offset) do
                {:ok, _p} ->
                  fd

                {:error, _} = error ->
                  File.close(fd)
                  error
              end

            {:error, _} = error ->
              error
          end
        end
      end,
      fn
        {:error, :enoent} = error ->
          {:halt, error}

        {:error, reason} ->
          raise File.Error, reason: reason, action: "open", path: path

        fd ->
          case :file.read(fd, line_size) do
            {:ok, data} ->
              <<record::binary-size(record_size), _padding::binary-size(padding)>> = data
              {[record], fd}

            :eof ->
              {:halt, fd}

            {:error, reason} ->
              raise File.Error, reason: reason, action: "read", path: path
          end
      end,
      fn
        {:error, _} -> :ok
        fd -> File.close(fd)
      end
    )
  end

  defp read(path, :backward, from_position, record_size, padding) do
    line_size = record_size + padding

    Stream.resource(
      fn ->
        with {:ok, stat} <- File.stat(path) do
          record_count = div(stat.size, line_size)

          start_position =
            cond do
              from_position === :start or (is_integer(from_position) and from_position <= 0) ->
                0

              from_position === :end or
                  (is_integer(from_position) and from_position > record_count) ->
                record_count

              true ->
                from_position
            end

          start_offset = line_size * (start_position - 1)

          case File.open(path, @modes) do
            {:ok, fd} ->
              {fd, start_offset}

            {:error, _} = error ->
              error
          end
        end
      end,
      fn
        {:error, :enoent} = error ->
          {:halt, error}

        {:error, reason} ->
          raise File.Error, reason: reason, action: "open", path: path

        {fd, offset} when offset < 0 ->
          {:halt, fd}

        {fd, offset} ->
          case :file.pread(fd, offset, record_size) do
            {:ok, data} ->
              next_offset = offset - line_size
              {[data], {fd, next_offset}}

            :eof ->
              {:halt, fd}

            {:error, reason} ->
              raise File.Error, reason: reason, action: "read", path: path
          end
      end,
      fn
        {:error, _} -> :ok
        fd -> File.close(fd)
      end
    )
  end
end
