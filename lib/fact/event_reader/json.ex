defmodule Fact.EventReader.Json do
  @moduledoc false
  @file_extension ".json"
  def read_event(path) do
    File.read!(path <> @file_extension) |> JSON.decode!()
  end 
end
