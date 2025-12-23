defmodule Mix.Tasks.Fact.Create2 do
  @moduledoc false

  use Mix.Task

  @switches [
    name: :string,
    path: :string,
    storage_layout: :string,
    storage_layout_options: :string,
    record_content: :string,
    record_content_options: :string,
    record_filename: :string,
    record_filename_options: :string,
    record_schema: :string,
    record_schema_options: :string,
    index_content: :string,
    index_content_options: :string,
    index_filename: :string,
    index_filename_options: :string
  ]

  @aliases [
    n: :name,
    p: :path
  ]

  @impl true
  def run(args) do
    {parsed, argv, invalid} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    if argv != [] do
      Mix.raise("Unexpected arguments: #{Enum.join(argv, " ")}")
    end

    name = Keyword.get(parsed, :name) || Mix.raise("--name is required")
    path = Keyword.get(parsed, :path) || Mix.raise("--path is required")

    resolved = %{
      name: name,
      path: path,
      storage_layout:
        resolve_format(
          Fact.StorageLayout.Registry,
          parse_format_selector(parsed[:storage_layout]),
          parse_format_options(parsed[:storage_layout_options])
        ),
      record_content:
        resolve_format(
          Fact.RecordFileFormat.Registry,
          parse_format_selector(parsed[:record_content]),
          parse_format_options(parsed[:record_content_options])
        ),
      record_filename:
        resolve_format(
          Fact.RecordFilename.Registry,
          parse_format_selector(parsed[:record_filename]),
          parse_format_options(parsed[:record_filename_options])
        ),
      record_schema:
        resolve_format(
          Fact.RecordSchema.Registry,
          parse_format_selector(parsed[:record_schema]),
          parse_format_options(parsed[:record_schema_options])
        ),
      #      index_content:
      #        resolve_format(
      #          Fact.IndexContentFormat.Registry,
      #          parse_format_selector(parsed[:index_content]),
      #          parse_format_options(parsed[:index_content_options])
      #        ),
      index_filename:
        resolve_format(
          Fact.IndexFilename.Registry,
          parse_format_selector(parsed[:index_filename]),
          parse_format_options(parsed[:index_filename_options])
        )
    }

    Mix.shell().info("\nResolved configuration:\n")
    IO.inspect(resolved, pretty: true)

    :ok
  end

  defp parse_format_selector(nil), do: :default

  defp parse_format_selector(value) do
    case String.split(value, "@") do
      [family, version] ->
        {String.to_atom(family), String.to_integer(version)}

      [family] ->
        {String.to_atom(family), :default}
    end
  end

  defp parse_format_options(nil), do: :default

  defp parse_format_options(value) do
    value
    |> String.split(",")
    |> Enum.map(fn pair ->
      [k, v] = String.split(pair, "=", parts: 2)
      {String.to_atom(k), v}
    end)
    |> Map.new()
  end

  defp resolve_format(registry, selector, options) do
    {id, version} =
      case selector do
        :default -> registry.default()
        {id, :default} -> {id, registry.latest_version(id)}
        {id, version} -> {id, version}
      end

    module = registry.resolve(id, version)

    final_options =
      module.metadata()
      |> Map.merge((options == :default && %{}) || module.normalize_options(options))

    %{
      id: id,
      version: version,
      options: final_options,
      module: module
    }
  end
end
