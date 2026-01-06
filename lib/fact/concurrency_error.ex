defmodule Fact.ConcurrencyError do
  @moduledoc """
  This exception is raised when the optimistic concurrency control logic determines an event or events
  cannot be written to the ledger.
    
  The following fields of this exception are public and can be accessed:
    
  * `:source` - the event store (`:all`) or the event stream 
  * `:expected` - the expectation or position during the append operation
  * `:actual` - the actual position during the append operation
  """

  defexception [:source, :expected, :actual]

  @impl true
  def message(exception),
    do: message(exception.source, exception.expected, exception.actual) |> String.trim()

  defp message(:all, expected, actual) do
    "expected to be #{expected}, but was #{actual}"
  end

  defp message(source, :none, _actual) do
    """
    expected "#{source}" stream to not exist
    """
  end

  defp message(source, :exists, 0) do
    """
    expected "#{source}" stream to exist
    """
  end

  defp message(source, expected, actual) do
    """
    expected "#{source}" to be #{expected}, but was #{actual}
    """
  end
end
