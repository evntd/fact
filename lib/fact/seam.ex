defmodule Fact.Seam do
  defmacro __using__(_opts) do
    quote do
      @type t :: struct()

      @callback id() :: {atom(), non_neg_integer()}
      @callback family() :: atom()
      @callback version() :: non_neg_integer()
      @callback default_options() :: map()
      @callback init(map()) :: struct() | {:error, term()}
      @callback normalize_options(map()) :: {:ok, map()} | {:error, term()}

      # A macro that injects a macro into the calling module. NEAT-O!
      # NEAT! Meta-programming is so much fun.
      defmacro __using__(opts) do
        family = Keyword.fetch!(opts, :family)
        version = Keyword.fetch!(opts, :version)

        quote do
          @behaviour unquote(__MODULE__)

          @family unquote(family)
          @version unquote(version)

          @impl true
          def id(), do: {@family, @version}

          @impl true
          def family(), do: @family

          @impl true
          def version(), do: @version

          @impl true
          def default_options(), do: %{}

          @impl true
          def init(%{} = _opts), do: struct(unquote(__MODULE__), %{})

          @impl true
          def normalize_options(%{} = _opts), do: %{}

          defoverridable default_options: 0, init: 1, normalize_options: 1
        end
      end

      #      defmacro __before_compile__(_env) do
      #        quote do
      #          unless Module.has_attribute?(__MODULE__, :__struct__) do
      #            raise ArgumentError, """
      #            #{inspect(__MODULE__)} must define a struct:
      #            
      #              defstruct []
      #            """
      #          end
      #        end
      #      end
    end
  end
end
