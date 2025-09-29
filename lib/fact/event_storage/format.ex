defmodule Fact.EventStorage.Format do
  @moduledoc false

  @callback encode(map()) :: binary()
  @callback decode(binary()) :: {:ok, map()} | {:error, term()}
end
