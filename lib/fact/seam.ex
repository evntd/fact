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

      # A macro that injects a macro into the calling module. 
      # NEAT-O! Meta-programming is so much fun.
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
          def init(opts \\ %{}) when is_map(opts), do: struct(__MODULE__, opts)

          @impl true
          def normalize_options(%{} = _opts), do: %{}

          defoverridable default_options: 0, init: 1, normalize_options: 1
        end
      end
    end
  end
end
