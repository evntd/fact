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
    allowed_impls_opt = Keyword.get(opts, :allowed_impls, nil)
    default_impl = Keyword.get(opts, :default_impl, nil)
    fixed_options = Keyword.get(opts, :fixed_options, Macro.escape(%{}))

    required_behaviours = 
      Keyword.get(opts, :required_behaviours, nil)
      |> case do
        nil -> nil
        behaviours when is_list(behaviours) ->
          Enum.map(behaviours, &Macro.expand(&1, __CALLER__))
      end
      
    IO.puts(inspect(required_behaviours))
      
    if allowed_impls_opt && required_behaviours do
      raise ArgumentError, """
      #{__MODULE__}: you must specify either :allowed_impls or define requirements via
      :required_behaviours and/or :required_capabilities, not both.
      """
    end
    
    allowed_impls =
      cond do
        is_list(required_behaviours) ->
          impls = registry.implements_behaviours(required_behaviours)
          if impls == [] do
            raise ArgumentError, """
            #{__MODULE__}: no implementations satisfy the required behaviours #{inspect(required_behaviours)}
            """
          end
          impls
        is_list(allowed_impls_opt) ->
          allowed_impls_opt
        true ->
          registry.all()
      end

    quote do
      @behaviour Fact.Seam.Adapter

      import Fact.Seam.Adapter, only: [__seam_call__: 3]

      @registry unquote(registry)
      @allowed_impls unquote(allowed_impls)
      @fixed_options unquote(fixed_options)

      # when default_impl is undefined, and there is only 1 allowed_impls, 
      # just default to the one, otherwise raise an exception.
      cond do
        unquote(default_impl) ->
          if unquote(default_impl) not in @allowed_impls do
            raise ArgumentError, """
            #{__MODULE__}: default_impl #{inspect(unquote(default_impl))} is not an allowed impl.
            Use one of the following: #{Enum.map(@allowed_impls, &inspect/1) |> Enum.intersperse(", ")}
            """
          end
          @default_impl unquote(default_impl)

        length(@allowed_impls) == 1 ->
          @default_impl hd(@allowed_impls)

        true ->
          raise ArgumentError, """
          #{__MODULE__}: must define :default_impl when multiple allowed_impls exist.
          Use one of the following: #{Enum.map(@allowed_impls, &inspect/1) |> Enum.intersperse(", ")}
          """
      end

      def registry(), do: @registry
      def allowed_impls(), do: @allowed_impls
      def default_impl(), do: @default_impl
      def fixed_options(impl_id), do: Map.get(@fixed_options, impl_id, %{})

      def init(options \\ %{}), do: init(@default_impl, options)

      def init(impl_id, options) do
        case registry().resolve(impl_id) do
          {:error, _} = error ->
            error

          impl ->
            opts =
              impl.default_options()
              |> Map.merge(options)
              |> Map.merge(fixed_options(impl_id))
              |> impl.normalize_options()

            case impl.init(opts) do
              s when is_struct(s) ->
                %Fact.Seam.Instance{module: impl, struct: s}

              {:error, _} = error ->
                error
            end
        end
      end
    end
  end
end
