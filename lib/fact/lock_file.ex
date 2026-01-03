defmodule Fact.LockFile do
  alias Fact.Context
  alias Fact.Storage

  defmodule Decoder do
    use Fact.Seam.Decoder.Adapter,
      context: :lock_file_decoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Encoder do
    use Fact.Seam.Encoder.Adapter,
      context: :lock_file_encoder,
      allowed_impls: [{:json, 1}]
  end

  defmodule Name do
    use Fact.Seam.FileName.Adapter,
      context: :lock_file_name,
      allowed_impls: [{:fixed, 1}],
      fixed_options: %{
        {:fixed, 1} => %{name: "lock"}
      }

    def get(%Context{} = context), do: get(context, nil, [])
  end

  defmodule Reader do
    use Fact.Seam.FileReader.Adapter,
      context: :lock_file_reader,
      allowed_impls: [{:full, 1}]
  end

  defmodule Writer do
    use Fact.Seam.FileWriter.Adapter,
      context: :lock_file_writer,
      fixed_options: %{
        {:standard, 1} => %{
          access: :write,
          binary: true,
          exclusive: false,
          raw: false,
          sync: false,
          worm: false
        }
      }
  end

  def delete(%Context{} = context) do
    with {:ok, filepath} <- path(context) do
      File.rm(filepath)
    end
  end

  def read(%Context{} = context) do
    with {:ok, filepath} <- path(context),
         {:ok, stream} <- Reader.read(context, filepath, []),
         encoded <- stream |> List.first(),
         {:ok, content} <- Decoder.decode(context, encoded) do
      content
    end
  end

  def write(%Context{} = context, lock_info) do
    with {:ok, encoded} <- Encoder.encode(context, lock_info),
         {:ok, filepath} <- path(context),
         :ok <- Writer.write(context, filepath, encoded) do
      :ok
    end
  end

  defp path(%Context{} = context) do
    with {:ok, filename} <- Name.get(context) do
      {:ok, Path.join(Storage.locks_path(context), filename)}
    end
  end
end
