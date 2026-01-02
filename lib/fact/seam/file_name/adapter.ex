defmodule Fact.Seam.FileName.Adapter do
  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    required_behaviours = Keyword.get(opts, :required_behaviours, nil)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.FileName.Registry,
        required_behaviours: unquote(required_behaviours),
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def get(%Context{@key => instance} = context, value, options) do
        __seam_call__(instance, :get, [value, [{:__context__, context} | options]])
      end
    end
  end
end
