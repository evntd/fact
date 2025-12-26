defmodule Fact.Seam.FileContent.Adapter do
  defmacro __using__(opts) do
    context_key = Keyword.fetch!(opts, :context)
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
          registry: Fact.Seam.FileContent.Registry,
          allowed_impls: unquote(allowed_impls),
          default_impl: unquote(default_impl),
          fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key unquote(context_key)

      def encode(%Context{@key => instance}, value) do
        __seam_call__(instance, :encode, [value])
      end

      def decode(%Context{@key => instance}, binary) do
        __seam_call__(instance, :decode, [binary])
      end
    end
  end  
end
