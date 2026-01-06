defmodule Fact.Seam.Storage.Adapter do
  defmacro __using__(opts) do
    allowed_impls = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    quote do
      use Fact.Seam.Adapter,
        registry: Fact.Seam.Storage.Registry,
        allowed_impls: unquote(allowed_impls),
        default_impl: unquote(default_impl),
        fixed_options: unquote(fixed_options)

      alias Fact.Context

      @key :storage

      def path(database, options \\ [])
      
      def path(database_id, options) when is_binary(database_id)  do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          path(context, options)
        end
      end
      
      def path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :path, [[{:__context__, context} | options]])
      end

      def records_path(database, options \\ [])

      def records_path(database_id, options) when is_binary(database_id)  do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          records_path(context, options)
        end
      end

      def records_path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :records_path, [[{:__context__, context} | options]])
      end

      def indices_path(database, options \\ [])

      def indices_path(database_id, options) when is_binary(database_id)  do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          indices_path(context, options)
        end
      end

      def indices_path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :indices_path, [[{:__context__, context} | options]])
      end

      def ledger_path(database, options \\ [])

      def ledger_path(database_id, options) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          ledger_path(context, options)
        end
      end

      def ledger_path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :ledger_path, [[{:__context__, context} | options]])
      end

      def locks_path(database, options \\ [])

      def locks_path(database_id, options) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          locks_path(context, options)
        end
      end

      def locks_path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :locks_path, [[{:__context__, context} | options]])
      end
    end
  end
end
