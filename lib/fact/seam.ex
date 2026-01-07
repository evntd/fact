defmodule Fact.Seam do
  @moduledoc """
  This module is the foundation for building flexible, versioned, and configurable
  components throughout the Fact system, providing consistency and reducing boilerplate.

  `Fact.Seam` defines a standard interface and default implementation for modules
  that expose configurable components, providing:

    * **Identification**: `id/0`, `family/0`, and `version/0` to uniquely identify implementations.
    * **Options management**: mechanisms to define default options, validate user-provided options,
      normalize options, and prepare them for internal use.
    * **Meta-programming helpers**: a `__using__/1` macro to easily inject behaviour and
      standard implementation into other modules.

  ## Key Features

  1. **Behaviour Definition**
     Modules that `use Fact.Seam` must implement:
       - `id/0` – returns a `{family, version}` tuple
       - `family/0` – the component family
       - `version/0` – numeric version of the component
       - `default_options/0` – default configuration options
       - `init/1` – initializes the module with validated options
       - `normalize_options/1` – normalizes and validates a given options map
       - `option_specs/0` – specifications for each option including parsing and allowed values
       - `prepare_options/1` – prepares the validated options for struct creation

  2. **Option Validation**
     Validates options against a provided `option_specs/0` map, applying parsing
     functions, checking allowed values, and returning detailed errors for unknown
     or invalid options.

  3. **Struct Initialization**
     Automatically merges user-provided options with defaults, validates them,
     and constructs a struct for the module.

  4. **Meta-programming Convenience**
     Injects default implementations for behaviours via the `__using__/1` macro,
     allowing modules to focus on implementing only unique functionality.
  """

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
          end

          def normalize_options(nil) do
            normalize_options(default_options())
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
