defmodule Fact.EventStreamsByCategoryIndexer do
  @moduledoc """
  Indexes the first event of each event stream by the stream **category**. 
  Like the `Fact.EventStreamCategoryIndexer` this splits the event stream using a specified
  separator (default: `"-"`) and returns the first segment.
    
  This indexer creates an index file for each category, each index file contains the first
  event in each stream within the category.
    
  Given the following events:
    
      [
        %{"event_id" => "1", "stream_id" => "user-1", "stream_position" => 1},
        %{"event_id" => "2", "stream_id" => "user-1", "stream_position" => 2},
        %{"event_id" => "3", "stream_id" => "company-1", "stream_position" => 1},
        %{"event_id" => "4", "stream_id" => "user-2", "stream_position" => 1},
        %{"event_id" => "5", "stream_id" => "project-1", "stream_position" => 1},
        %{"event_id" => "6", "stream_id" => "project-1", "stream_position" => 2},
        %{"event_id" => "7", "stream_id" => "project-1", "stream_position" => 3},
        %{"event_id" => "8", "stream_id" => "user-3", "stream_position" => 1},
      ] 

  Then this indexer will create the following three index files
    
  ```
  # Fact.EventStreamsByCategoryIndexer/user
  1
  4
  8
  ```

  ```
  # Fact.EventStreamsByCategoryIndexer/company
  3
  ```
    
  ```
  # Fact.EventStreamsByCategoryIndexer/project
  5
  ```
  """
  use Fact.EventIndexer

  @default_separator "-"

  @doc """
  Extracts the stream category from the first event of each event stream.
    
  ## Options
    
    * `:separator` - optional delimiter used to split the stream name.
      Defaults to "-".

  ## Examples
    
      iex> event = %{"stream_id" => "user-1", "stream_position" => 1}
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      "user"
    
      iex> event = %{"stream_id" => "user-1", "stream_position" => 2}
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      nil
    
      iex> event = %{"stream_id" => "company-1", "stream_position" => 1}
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, [])
      "company"
    
      iex> event = %{"stream_id" => "project:stardust", "stream_position" => 1}
      iex> Fact.EventStreamsByCategoryIndexer.index_event(event, separator: ":")
      "project"
  """
  @impl true
  def index_event(%{@event_stream => stream, @event_stream_position => 1}, opts) do
    separator = Keyword.get(opts, :separator, @default_separator)
    stream |> String.split(separator, parts: 2) |> List.first()
  end

  def index_event(_event, _opts), do: nil
end
