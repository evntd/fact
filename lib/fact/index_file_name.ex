defmodule Fact.IndexFileName do
  @allowed_formats [
    {:raw, 1},
    {:hash, 1}
  ]
  @default_format {:raw, 1}
  
  def allowed(), do: @allowed_formats
  def default(), do: @default_format
  
end
