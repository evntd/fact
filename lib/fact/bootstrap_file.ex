defmodule Fact.BootstrapFile do
  @moduledoc """
  This module encapsulates the adapters used for working with the bootstrap record file.
  """
  @moduledoc since: "0.2.0"

  @typedoc """
  A small subset of a `t:Fact.Context.t/0` containing the following keys with .
    
    * record_id - `t:Fact.record_id/0`
    * record_file_decoder - `t:Fact.Genesis.Event.DatabaseCreated.V1.component_config/0`
    * record_file_reader - `t:Fact.Genesis.Event.DatabaseCreated.V1.component_config/0`
    * event_schema - `t:Fact.Genesis.Event.DatabaseCreated.V1.component_config/0`
    * storage - `t:Fact.Genesis.Event.DatabaseCreated.V1.component_config/0`

  """
  @typedoc since: "0.2.0"
  @type bootstrap_record :: map()

  defmodule Context do
    @moduledoc """
    The context for a bootstrapping the Fact database.

    The `Fact.BootstrapFile.Context` holds all the configuration, for reading,
    and writing the bootstrap file, which contains just enough configuration information
    to read the `Fact.Context` when bootstrapping a database.
    """
    @moduledoc since: "0.2.0"

    defstruct [
      :decoder,
      :encoder,
      :name,
      :reader,
      :writer
    ]

    @type t :: %{
            decoder: Fact.Seam.Instance.t(),
            encoder: Fact.Seam.Instance.t(),
            name: Fact.Seam.Instance.t(),
            reader: Fact.Seam.Instance.t(),
            writer: Fact.Seam.Instance.t()
          }
  end

  defmodule Encoder do
    @moduledoc """
    Adapter for encoding the contents of the bootstrap file.
    """
    @moduledoc since: "0.2.0"
    use Fact.Seam.Adapter,
      registry: Fact.Seam.Encoder.Registry,
      allowed_impls: [{:json, 1}]

    @doc """
    Helper function to encode the bootstrap file using the configured `Fact.Seam.Encoder`.
    """
    @doc since: "0.2.0"
    @spec encode(Context.t(), term()) :: {:ok, iodata()} | {:error, term()}
    def encode(%Context{encoder: this}, value) do
      __seam_call__(this, :encode, [value, []])
    end
  end

  defmodule Decoder do
    @moduledoc """
    Adapter for decoding the contents of the bootstrap file.
    """
    @moduledoc since: "0.2.0"
    use Fact.Seam.Adapter,
      registry: Fact.Seam.Decoder.Registry,
      allowed_impls: [{:json, 1}]

    @doc """
    Helper function to decode the bootstrap file using the configured `Fact.Seam.Decoder`.
    """
    @doc since: "0.2.0"
    @spec decode(Context.t(), binary()) :: {:ok, term()} | {:error, term()}
    def decode(%Context{decoder: this}, value) do
      __seam_call__(this, :decode, [value, []])
    end
  end

  defmodule Name do
    @moduledoc """
    Adapter for naming the bootstrap file.
    """
    @moduledoc since: "0.2.0"
    use Fact.Seam.Adapter,
      registry: Fact.Seam.FileName.Registry,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: ".bootstrap"}
      }

    @doc """
    Helper function to get the file name using the configured `Fact.Seam.FileName`.
    """
    @spec get(Context.t()) :: String.t()
    def get(%Context{name: this}) do
      {:ok, name} = __seam_call__(this, :get, [nil, []])
      name
    end
  end

  defmodule Reader do
    @moduledoc """
    Adapter for reading the bootstrap file.
    """
    @moduledoc since: "0.2.0"
    use Fact.Seam.Adapter,
      registry: Fact.Seam.FileReader.Registry,
      allowed_impls: [{:full, 1}]

    @doc """
    Helper function to read the bootstrap file using the configured `Fact.Seam.FileReader`.
    """
    @doc since: "0.2.0"
    def read(%Context{reader: this}, path) do
      {:ok, stream} = __seam_call__(this, :read, [path, []])
      Enum.at(stream, 0)
    end
  end

  defmodule Writer do
    @moduledoc """
    Adapter for writing the bootstrap file.
    """
    @moduledoc since: "0.2.0"
    use Fact.Seam.Adapter,
      registry: Fact.Seam.FileWriter.Registry,
      allowed_impls: [{:standard, 1}],
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: false,
          raw: false,
          sync: false,
          worm: true
        }
      }

    @doc """
    Helper function to write the bootstrap file using the configured `Fact.Seam.FileWriter`.
    """
    @doc since: "0.2.0"
    def write(%Context{writer: this}, path, record) do
      __seam_call__(this, :write, [path, record, []])
    end
  end

  @decoder_config %{family: :json, version: 1, options: %{}}
  @encoder_config %{family: :json, version: 1, options: %{}}
  @name_config %{family: :fixed, version: 1, options: %{}}
  @reader_config %{family: :full, version: 1, options: %{}}
  @writer_config %{family: :standard, version: 1, options: %{}}

  @doc """
  Reads the bootstrap file.
  """
  @doc since: "0.2.0"
  @spec read(Path.t()) :: {:ok, bootstrap_record()}
  def read(path) do
    this = get_bootstrap_read_context()

    if File.exists?(bootstrap_path = Path.join(path, Name.get(this))) do
      Decoder.decode(this, Reader.read(this, bootstrap_path))
    else
      {:error, :bootstraps_not_found}
    end
  end

  defp get_bootstrap_read_context() do
    %Context{
      decoder: Decoder.from_config(@decoder_config),
      name: Name.from_config(@name_config),
      reader: Reader.from_config(@reader_config)
    }
  end

  @doc """
  Writes a minimal amount of the `Fact.Context` structure to the bootstrap file.
    
  It writes just enough configuration, so that the genesis record (`Fact.Genesis.Event.DatabaseCreated.V1`)
  can be read and a full `Fact.Context` can be loaded.
  """
  @doc since: "0.2.0"
  @spec write(Path.t(), genesis_record :: Fact.record()) :: :ok | {:error, term()}
  def write(path, {record_id, event}) do
    this = get_bootstrap_write_context()

    {:ok, bootstrap_record} =
      Encoder.encode(this, %{
        record_id: record_id,
        event_schema: event.event_schema,
        record_file_decoder: event.record_file_decoder,
        record_file_reader: event.record_file_reader,
        storage: event.storage
      })

    Writer.write(this, Path.join(path, Name.get(this)), bootstrap_record)
  end

  defp get_bootstrap_write_context() do
    %Context{
      encoder: Encoder.from_config(@encoder_config),
      name: Name.from_config(@name_config),
      writer: Writer.from_config(@writer_config)
    }
  end
end
