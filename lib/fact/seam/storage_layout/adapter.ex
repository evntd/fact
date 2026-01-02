defmodule Fact.Seam.StorageLayout.Adapter do
  defmacro __using__(opts) do
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.StorageLayout.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key :storage_layout

      def path(%Context{@key => instance} = context, options \\ []) do
        __seam_call__(instance, :path, [[{:__context__, context} | options]])
      end

      def records_path(%Context{@key => instance} = context, options \\ []) do
        __seam_call__(instance, :records_path, [[{:__context__, context} | options]])
      end

      def indices_path(%Context{@key => instance} = context, options \\ []) do
        __seam_call__(instance, :indices_path, [[{:__context__, context} | options]])
      end

      def ledger_path(%Context{@key => instance} = context, options \\ []) do
        __seam_call__(instance, :ledger_path, [[{:__context__, context} | options]])
      end
    end
  end
end
