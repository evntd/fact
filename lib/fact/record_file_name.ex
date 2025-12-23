defmodule Fact.RecordFileName do
  use Fact.Seam

  @callback for(format :: t(), record :: Fact.Types.event_record(), encoded :: binary()) ::
              Path.t()

  def for(
        %Fact.Context{record_file_name: %Fact.Seam.Instance{module: mod, struct: s}},
        event_record,
        encoded_record
      ) do
    mod.for(s, event_record, encoded_record)
  end
end
