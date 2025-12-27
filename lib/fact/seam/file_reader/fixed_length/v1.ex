defmodule Fact.Seam.FileReader.FixedLength.V1 do
  use Fact.Seam.FileReader,
    family: :fixed_length,
    version: 1

  @type options ::
          {:direction, :forward | :backward}
          | {:position, :start | :end, non_neg_integer()}
          | {:size, pos_integer()}
          | {:padding, non_neg_integer()}

  @type reason ::
          :required_size_option

  @type t :: %{
          required(:length) => pos_integer(),
          required(:padding) => non_neg_integer()
        }

  @enforce_keys [:length, :padding]
  defstruct [:length, :padding]

  @option_specs %{
    length: %{
      allowed: :any,
      parse: &__MODULE__.parse_pos_integer/1,
      error: :invalid_length
    },
    padding: %{
      allowed: :any,
      parse: &__MODULE__.parse_non_neg_integer/1,
      error: :invalid_padding
    }
  }

  @modes [:raw, :read, :binary]
  @default_direction :forward
  @default_position :start

  @impl true
  def default_options(), do: %{padding: 0}

  @impl true
  def init(options) when is_map(options) do
    default_options()
    |> Map.merge(options)
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} ->
        struct(__MODULE__, valid)

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def normalize_options(%{} = options) do
    options
    |> Map.take(Map.keys(@option_specs))
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} -> valid
      {:error, _} = error -> error
    end
  end

  defp validate_options(options, specs) when is_map(options) do
    Enum.reduce_while(options, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Map.fetch(specs, key) do
        :error ->
          {:halt, {:error, {:unknown_option, key}}}

        {:ok, %{parse: parse, allowed: allowed, error: error}} ->
          case parse.(value) do
            {:ok, parsed} ->
              cond do
                allowed == :any ->
                  {:cont, {:ok, Map.put(acc, key, parsed)}}

                parsed in allowed ->
                  {:cont, {:ok, Map.put(acc, key, parsed)}}

                true ->
                  {:halt, {:error, {error, value}}}
              end

            _ ->
              {:halt, {:error, {error, value}}}
          end
      end
    end)
  end

  def parse_pos_integer(value) when is_integer(value) do
    if value > 0, do: {:ok, value}, else: :error
  end

  def parse_pos_integer(value) when is_binary(value) do
    if value = String.to_integer(value) > 0,
      do: {:ok, value},
      else: :error
  rescue
    ArgumentError ->
      :error
  end

  def parse_pos_integer(_value), do: :error

  def parse_non_neg_integer(value) when is_integer(value) do
    if value >= 0, do: {:ok, value}, else: :error
  end

  def parse_non_neg_integer(value) when is_binary(value) do
    if value = String.to_integer(value) >= 0,
      do: {:ok, value},
      else: :error
  rescue
    ArgumentError ->
      :error
  end

  def parse_non_neg_integer(_value), do: :error

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
        {:error, reason} ->
          raise File.Error, reason: reason, action: "open", path: path

        {fd, offset} when offset < 0 ->
          {:halt, fd}

        {fd, offset} ->
          case :file.pread(fd, offset, record_size) do
            {:ok, data} ->
              next_offset = offset - line_size
              {[data], {fd, next_offset}}
              :eof
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
