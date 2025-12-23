defmodule Fact.Seam do
  defmacro __using__(_opts) do
    quote do
      @type t :: struct()

      @callback id() :: atom()
      @callback version() :: non_neg_integer()
      @callback metadata() :: map()
      @callback init(map()) :: struct() | {:error, term()}
      @callback normalize_options(map()) :: {:ok, map()} | {:error, term()}
    end
  end
end
