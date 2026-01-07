defmodule Fact.Seam.Storage.Adapter do
  @moduledoc """
  Meta module providing an adapter for accessing storage-related functionality
  via a `Fact.Seam.Storage` implementation.

  This module is intended to be `use`d by other modules to inject functions
  that simplify retrieval of paths associated with a database context:

    * `path/2` – the root path for the database storage.
    * `records_path/2` – path for storing event records.
    * `indices_path/2` – path for storing index files.
    * `ledger_path/2` – path for the event ledger.
    * `locks_path/2` – path for database locks.

  Each function can be called with either a database id (`String.t()`) or a
  `Fact.Context` containing the configured storage instance. When called with a
  database ID, the adapter automatically retrieves the corresponding context.

  All operations are delegated to the underlying storage implementation
  using the configured seam instance. This module primarily provides
  compile-time injection of these helper functions.
  """

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

      def path(database_id, options) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          path(context, options)
        end
      end

      def path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :path, [[{:__context__, context} | options]])
      end

      def records_path(database, options \\ [])

      def records_path(database_id, options) when is_binary(database_id) do
        with {:ok, context} <- Fact.Registry.get_context(database_id) do
          records_path(context, options)
        end
      end

      def records_path(%Context{@key => instance} = context, options) do
        __seam_call__(instance, :records_path, [[{:__context__, context} | options]])
      end

      def indices_path(database, options \\ [])

      def indices_path(database_id, options) when is_binary(database_id) do
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
