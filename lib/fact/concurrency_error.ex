defmodule Fact.ConcurrencyError do
  @moduledoc """
  An exception raised when events cannot be appended due to optimistic concurrency controls.
    
  The following fields of this exception are public and can be accessed:
    
  * `:source` - the event store (`:all`) or the event stream 
  * `:expected` - the expectation or position during the append operation
  * `:actual` - the actual position during the append operation
  """

  defexception [:source, :expected, :actual]

  @impl true
  def message(exception), do: message(exception.source, exception.expected, exception.actual)

  defp message(:all, expected, actual) do
    "expected store_position to be #{expected}, but was #{actual}"
  end

  defp message(source, :none, _actual) do
    "expected #{source} stream to not exist"
  end

  defp message(source, :exists, 0) do
    "expected #{source} to exist"
  end

  defp message(source, expected, actual) do
    "expected #{source} stream_position to be #{expected}, but was #{actual}"
  end
end
