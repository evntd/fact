defmodule Fact.RecordFileFormat do
  use Fact.Seam

  @callback encode(format :: t(), Fact.Types.event_record()) :: {:ok, iodata()} | {:error, term()}
  @callback decode(format :: t(), binary()) :: Fact.Types.event_record()

  def encode(
        %Fact.Context{record_file_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.encode(s, event_record)
  end

  def decode(
        %Fact.Context{record_file_format: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record
      ) do
    mod.decode(s, event_record)
  end
end
