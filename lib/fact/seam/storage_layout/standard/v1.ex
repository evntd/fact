defmodule Fact.Seam.StorageLayout.Standard.V1 do
  use Fact.Seam.StorageLayout,
    family: :standard,
    version: 1

  import Fact.Seam.Parsers, only: [parse_directory: 1]

  @enforce_keys [:path]
  defstruct [:path]

  @impl true
  def default_options(), do: %{path: nil}

  @impl true
  def option_specs() do
    %{
      path: %{
        allowed: :any,
        parse: &parse_directory/1,
        error: :invalid_path_option
      }
    }
  end

  @impl true
  def records_path(%__MODULE__{path: root}, _opts), do: {:ok, Path.join(root, "events")}

  @impl true
  def indices_path(%__MODULE__{path: root}, _opts), do: {:ok, Path.join(root, "indices")}

  @impl true
  def ledger_path(%__MODULE__{path: root}, _opts), do: {:ok, root}

  def init_storage(%__MODULE__{path: root} = format) do
    # INVARIANTS
    # - Path MUST be a directory
    # - Path SHOULD not exist
    # - IF path exists, it must be empty

    with :ok <- ensure_is_dir_or_does_not_exist(root),
         :ok <- ensure_empty_if_exists(root),
         :ok <- create_filesystem_layout(format, root) do
      :ok
    end
  end

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
