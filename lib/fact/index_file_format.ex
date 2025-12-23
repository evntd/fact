defmodule Fact.IndexFileFormat do
  use Fact.Seam

  @callback encode(format :: t(), Fact.Types.event_record()) :: iodata()
end
