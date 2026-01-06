defmodule Fact.Seam.EventSchema.Adapter do
  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.EventSchema.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)
      
      def get(database, options \\ [])
      
      def get(database_id, options) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          get(context, options)
        end
      end
      
      def get(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :get, [[{:__context__, context} | options]])
      end
    end
  end
end
