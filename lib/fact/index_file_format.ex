defmodule Fact.IndexFileFormat do
  use Fact.Seam

  @callback encode(format :: t(), list(Fact.Types.event_record())) :: iodata()
end
