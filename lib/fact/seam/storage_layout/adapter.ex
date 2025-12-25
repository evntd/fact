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

      def records_path(%Context{:database_path => root, @key => instance}) do
        __seam_call__(instance, :records_path, [root])
      end

      def indices_path(%Context{:database_path => root, @key => instance}) do
        __seam_call__(instance, :indices_path, [root])
      end

      def ledger_path(%Context{:database_path => root, @key => instance}) do
        __seam_call__(instance, :ledger_path, [root])
      end
    end
  end
end
