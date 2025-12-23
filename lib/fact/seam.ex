defmodule Fact.Seam do
  defmacro __using__(_opts) do
    quote do
      @type t :: struct()

      @callback id() :: atom()
      @callback version() :: non_neg_integer()
      @callback metadata() :: map()
      @callback init(metadata :: map()) :: struct()
      @callback normalize_options(map()) :: map()
    end
  end
end
