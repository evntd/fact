defmodule Fact.Seam.FileWriter.Standard.V1 do
  use Fact.Seam.FileWriter,
    family: :standard,
    version: 1

  @type t :: %{
          required(:access) => :write | :append,
          required(:binary) => boolean(),
          required(:exclusive) => boolean(),
          required(:sync) => boolean(),
          required(:worm) => boolean()
        }
  @type reason ::
          {:invalid_access_option, term()}
          | {:invalid_binary_option, term()}
          | {:invalid_exclusive_option, term()}
          | {:invalid_sync_option, term()}
          | {:invalid_worm_option, term()}
          | {:unknown_option, term()}

  @enforce_keys [:modes, :sync, :worm]
  defstruct [:modes, :sync, :worm]

  @option_specs %{
    access: %{
      allowed: [:write, :append],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_access_option
    },
    binary: %{
      allowed: [true, false],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_binary_option
    },
    exclusive: %{
      allowed: [true, false],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_exclusive_option
    },
    raw: %{
      allowed: [true, false],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_raw_option
    },
    sync: %{
      allowed: [true, false],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_sync_option
    },
    worm: %{
      allowed: [true, false],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_worm_option
    }
  }

  @impl true
  def default_options(),
    do: %{access: :write, binary: true, exclusive: true, raw: false, sync: false, worm: false}

  @impl true
  @spec init(map()) :: t() | {:error, reason()}
  def init(options) when is_map(options) do
    default_options()
    |> Map.merge(options)
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid_options} ->
        modes =
          [
            valid_options.access,
            if(valid_options.binary, do: :binary, else: nil),
            if(valid_options.exclusive, do: :exclusive, else: nil),
            if(valid_options.raw, do: :raw, else: nil)
          ]
          |> Enum.reject(&is_nil/1)

        data =
          valid_options
          |> Map.take([:sync, :worm])
          |> Map.put(:modes, modes)

        struct(__MODULE__, data)

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
      {:ok, valid} ->
        valid

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def write(%__MODULE__{modes: modes, sync: sync, worm: worm}, path, value, _options) do
    with {:ok, fd} <- File.open(path, modes),
         :ok <- IO.binwrite(fd, value),
         :ok <- if(sync, do: :file.sync(fd), else: :ok),
         :ok <- File.close(fd),
         :ok <- if(worm, do: File.chmod(path, 0o444), else: :ok) do
      :ok
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
              if parsed in allowed do
                {:cont, {:ok, Map.put(acc, key, parsed)}}
              else
                {:halt, {:error, {error, value}}}
              end

            _ ->
              {:halt, {:error, {error, value}}}
          end
      end
    end)
  end

  def parse_existing_atom(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def parse_existing_atom(value) when is_atom(value), do: {:ok, value}
  def parse_existing_atom(_), do: :error
end
