defmodule Fact.EventWriter.Json do
  @moduledoc false
  use Fact.EventKeys
  @file_extension ".json"
  def write(path, event) do
    encoded_event = JSON.encode!(event)
    File.write(path <> @file_extension, encoded_event, [:exclusive])
  end
end
