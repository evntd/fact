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
      @callback option_specs() :: %{atom() => map()}
      @callback prepare_options(map()) :: map()

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
          def option_specs(), do: %{}

          @impl true
          def init(options \\ %{}) when is_map(options) do
            default_options()
            |> Map.merge(options)
            |> validate_options(option_specs())
            |> case do
              {:ok, valid_options} ->
                prepared_options = prepare_options(valid_options)
                struct(__MODULE__, prepared_options)

              {:error, _} =
                  error ->
                error
            end
          end

          @impl true
          def normalize_options(%{} = options) when is_map(options) do
            options
            |> Map.take(Map.keys(option_specs()))
            |> validate_options(option_specs())
            |> case do
              {:ok, valid_options} -> valid_options
              {:error, _} = error -> error
            end
          end

          @impl true
          def prepare_options(%{} = options) when is_map(options), do: options

          def validate_options(options, specs) do
            Enum.reduce_while(options, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
              case Map.fetch(specs, key) do
                :error ->
                  {:halt, {:error, {:unknown_option, key}}}

                {:ok, %{parse: parse, allowed: allowed, error: error}} ->
                  case parse.(value) do
                    {:ok, parsed_value} ->
                      cond do
                        allowed == :any ->
                          {:cont, {:ok, Map.put(acc, key, parsed_value)}}

                        parsed_value in allowed ->
                          {:cont, {:ok, Map.put(acc, key, parsed_value)}}

                        true ->
                          {:halt, {:error, {error, value}}}
                      end

                    _ ->
                      {:halt, {:error, {error, value}}}
                  end
              end
            end)
          end

          defoverridable default_options: 0,
                         init: 1,
                         normalize_options: 1,
                         option_specs: 0,
                         prepare_options: 1
        end
      end
    end
  end
end
