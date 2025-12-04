defmodule Fact.EventTagsIndexer do
  @moduledoc """
  An event indexer that indexes events by each associated tag.

  This module implements the `Fact.EventIndexer` behaviour and returns the value
  stored under an event's optional `tags` field. 

  This indexer should be used when the system uses dynamic consistency boundaries.
  """

  use Fact.EventIndexer

  @impl true
  @doc """
  Returns the tags defined on the event.

  ## Parameters

    * `event` — an event.
    * `opts` — indexing options (ignored).

  ## Returns

    * the event's tag list or tag value, if present
    * `nil` if the event has no tags field

  ## Examples

      iex> event = %{"type" => "StudentSubscribedToCourse", "data" => %{ "student_id" => "s1", "course_id" => "c1"}, "tags" => ["student:s1", "course:c1"]}
      iex> Fact.EventTagsIndexer.index_event(event, [])
      ["student:s1", "course:c1"]

      iex> event = %{"type" => "CourseDefined", "data" => %{ "course_id" => "c1", "course_name" => "Computer Science 101", "course_capacity" => 30 }, "tags" => "course:c1"} 
      iex> Fact.EventTagsIndexer.index_event(event, [])
      "course:c1"

      iex> event = %{"type" => "UserRegistered", "data" => %{ "user_id" => 1234 }}
      iex> Fact.EventTagsIndexer.index_event(event, [])
      nil

  """
  def index_event(%{@event_tags => tags}, _opts), do: tags
  def index_event(_event, _opts), do: nil
end
