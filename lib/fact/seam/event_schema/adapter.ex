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

      def get_event_data(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_data, [record, [{:__context__, context} | options]])
      end

      def set_event_data(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_data, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_id(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_id, [record, [{:__context__, context} | options]])
      end

      def set_event_id(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_id, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_metadata(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_metadata, [record, [{:__context__, context} | options]])
      end

      def set_event_metadata(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_metadata, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_tags(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_tags, [record, [{:__context__, context} | options]])
      end

      def set_event_tags(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_tags, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_type(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_type, [record, [{:__context__, context} | options]])
      end

      def set_event_type(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_type, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_store_position(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_store_position, [
          record,
          [{:__context__, context} | options]
        ])
      end

      def set_event_store_position(
            %Context{@key => instance} = context,
            record,
            value,
            options \\ []
          ) do
        __seam_call__(instance, :set_event_store_position, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_store_timestamp(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_store_timestamp, [
          record,
          [{:__context__, context} | options]
        ])
      end

      def set_event_store_timestamp(
            %Context{@key => instance} = context,
            record,
            value,
            options \\ []
          ) do
        __seam_call__(instance, :set_event_store_timestamp, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_stream_id(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_stream_id, [
          record,
          [{:__context__, context} | options]
        ])
      end

      def set_event_stream_id(%Context{@key => instance} = context, record, value, options \\ []) do
        __seam_call__(instance, :set_event_stream_id, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end

      def get_event_stream_position(%Context{@key => instance} = context, record, options \\ []) do
        __seam_call__(instance, :get_event_stream_position, [
          record,
          [{:__context__, context} | options]
        ])
      end

      def set_event_stream_position(
            %Context{@key => instance} = context,
            record,
            value,
            options \\ []
          ) do
        __seam_call__(instance, :set_event_stream_position, [
          record,
          value,
          [{:__context__, context} | options]
        ])
      end
    end
  end
end
