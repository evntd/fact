defmodule Fact.Seam.FileWriter.Standard.V1 do
  @moduledoc """
  Standard V1 implementation of `Fact.Seam.FileWriter`.

  Provides configurable file writing with options for access mode, binary mode, exclusive/open flags, raw mode, synchronous writes, and WORM (write-once, read-many) file protection.
  """
  use Fact.Seam.FileWriter,
    family: :standard,
    version: 1

  import Fact.Seam.Parsers, only: [parse_existing_atom: 1]

  @enforce_keys [:modes, :sync, :worm]
  defstruct [:modes, :sync, :worm]

  @impl true
  def default_options(),
    do: %{access: :write, binary: true, exclusive: true, raw: false, sync: false, worm: false}

  @impl true
  def option_specs() do
    %{
      access: %{
        allowed: [:write, :append],
        parse: &parse_existing_atom/1,
        error: :invalid_access_option
      },
      binary: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_binary_option
      },
      exclusive: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_exclusive_option
      },
      raw: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_raw_option
      },
      sync: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_sync_option
      },
      worm: %{
        allowed: [true, false],
        parse: &parse_existing_atom/1,
        error: :invalid_worm_option
      }
    }
  end

  @impl true
  def prepare_options(options) do
    modes =
      [
        options.access,
        if(options.binary, do: :binary, else: nil),
        if(options.exclusive, do: :exclusive, else: nil),
        if(options.raw, do: :raw, else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    options
    |> Map.take([:sync, :worm])
    |> Map.put(:modes, modes)
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
end
