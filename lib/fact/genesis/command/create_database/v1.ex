defmodule Fact.Genesis.Command.CreateDatabase.V1 do
  @moduledoc """
  Command representing the creation of a new Fact database.

  This command is produced by the `mix fact.create` task and is processed by
  the `Fact.Genesis.Decider`. If the arguments are valid, the decider emits
  a `Fact.Genesis.Event.DatabaseCreated.V1` event, recording the creation of the
  database as a fact.

  The `args` field contains the keyword options passed to the task, such as the
  target path and configuration parameters.
  """

  defstruct [:args]

  @type t :: %__MODULE__{
          args: keyword
        }
end
