defmodule Fact.Genesis.Command.CreateDatabase.V1 do
  defstruct [:args]

  @type t :: %__MODULE__{
          args: keyword
        }
end
