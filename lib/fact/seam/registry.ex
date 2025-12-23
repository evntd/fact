defmodule Fact.Seam.Registry do
  defmacro __using__(opts) do
    formats =
      Keyword.fetch!(opts, :formats)
      |> Enum.map(&Macro.expand(&1, __CALLER__))

    latest_versions =
      formats
      |> Enum.group_by(& &1.id())
      |> Enum.map(fn {id, mods} ->
        {id, Enum.max_by(mods, & &1.version())}
      end)
      |> Map.new()

    quote do
      @formats unquote(formats)
      @latest_versions unquote(Macro.escape(latest_versions))

      def resolve(id, version) do
        Enum.find(@formats, fn format ->
          format.id() == id and format.version() == version
        end) || {:error, {:unsupported_format, id, version}}
      end

      def latest(id) do
        case Map.get(@latest_versions, id) do
          nil -> {:error, :unsupported_format}
          format -> format
        end
      end

      def latest_version(id) do
        case Map.get(@latest_versions, id) do
          nil -> {:error, :unsupported_format}
          format -> format.version()
        end
      end
    end
  end
end
