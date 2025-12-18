defmodule Fact.DatabaseError do
  @moduledoc """
  This exception is raised when something in the database doesn't go as expected.
  """

  defexception [:message]
end
