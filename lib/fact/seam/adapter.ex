defmodule Fact.Seam.Adapter do
  alias Fact.Seam.Instance

  @callback registry() :: module()
  @callback allowed_impls() :: list({atom(), pos_integer()})
  @callback default_impl() :: {atom(), pos_integer()}
  @callback fixed_options({atom(), pos_integer()}) :: map()

  @doc """
  Generic dispatch
  """
  def __seam_call__(%Instance{module: mod, struct: s}, fun, args) do
    apply(mod, fun, [s | args])
  end

  defmacro __using__(opts) do
    registry = Macro.expand(Keyword.fetch!(opts, :registry), __CALLER__)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, %{}) |> Macro.escape()

    quote do
      @behaviour Fact.Seam.Adapter

      import Fact.Seam.Adapter, only: [__seam_call__: 3]

      @registry unquote(registry)
      @fixed_options unquote(fixed_options)
      @allowed_impls unquote(allowed_impls || registry.all())

      # when default_impl is undefined, and there is only 1 allowed_impls, 
      # just default to the one, otherwise raise an exception.
      cond do
        unquote(default_impl) ->
          @default_impl unquote(default_impl)

        length(@allowed_impls) == 1 ->
          @default_impl hd(@allowed_impls)

        true ->
          raise ArgumentError,
                "#{__MODULE__} must define a default_impl when multiple allowed_impls exist"
      end

      def registry(), do: @registry
      def allowed_impls(), do: @allowed_impls
      def default_impl(), do: @default_impl
      def fixed_options(impl_id), do: Map.get(@fixed_options, impl_id, %{})
    end
  end
end
