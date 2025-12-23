defmodule Fact.StorageLayoutFormat.Default.V1 do
  @behaviour Fact.StorageLayoutFormat

  defstruct []

  @impl true
  def id(), do: :default

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{}

  @impl true
  def init(_metadata), do: %__MODULE__{}

  @impl true
  def normalize_options(%{} = _options), do: {:ok, %{}}

  @impl true
  def init_storage(format, path) do
    # INVARIANTS
    # - Path MUST be a directory
    # - Path SHOULD not exist
    # - IF path exists, it must be empty

    with :ok <- ensure_is_dir_or_does_not_exist(path),
         :ok <- ensure_empty_if_exists(path),
         :ok <- create_filesystem_layout(format, path) do
      :ok
    end
  end

  @impl true
  def records_path(_format, root), do: Path.join(root, "events")

  @impl true
  def indices_path(_format, root), do: Path.join(root, "indices")

  @impl true
  def ledger_path(_format, root), do: Path.join(root, ".ledger")

  defp ensure_is_dir_or_does_not_exist(path) do
    cond do
      not File.exists?(path) ->
        :ok

      File.dir?(path) ->
        :ok

      true ->
        {:error, {:path_not_directory, path}}
    end
  end

  defp ensure_empty_if_exists(path) do
    if File.exists?(path) do
      case File.ls(path) do
        {:ok, []} ->
          :ok

        {:ok, _} ->
          {:error, {:path_not_empty, path}}

        {:error, reason} ->
          {:error, {:cannot_list_dir, path, reason}}
      end
    else
      :ok
    end
  end

  defp create_filesystem_layout(format, path) do
    with :ok <- File.mkdir_p(path),
         :ok <- File.mkdir_p(records_path(format, path)),
         :ok <- File.mkdir_p(indices_path(format, path)),
         :ok <- File.touch(ledger_path(format, path)),
         :ok <- File.write(Path.join(path, ".gitignore"), "*") do
      :ok
    end
  end
end
