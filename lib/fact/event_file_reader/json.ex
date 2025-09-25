defmodule Fact.EventFileReader.Json do
  @moduledoc false
  @file_extension ".json"
  def read(path) do
    File.read!(path <> @file_extension) |> JSON.decode!()
  end
end
