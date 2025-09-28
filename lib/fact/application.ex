defmodule Fact.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Fact.Supervisor,
       name: Test,
       ledger: [
         path: ".fact_inst/log"
       ],
       storage: [
         path: ".fact_inst/events",
         driver: Fact.Storage.Driver.ByEventId
       ],
       indexers: [
         [
           enabled: true,
           mod: Fact.EventStreamIndexer,
           opts: [
             path: ".fact_inst/indices/event_stream"
           ]
         ],
         [
           enabled: true,
           mod: Fact.EventTypeIndexer,
           opts: [
             path: ".fact_inst/indices/event_type"
           ]
         ],
         [
           enabled: true,
           mod: Fact.EventTagsIndexer,
           opts: [
             path: ".fact_inst/indices/tags"
           ]
         ],
         [
           enabled: false,
           mod: Fact.EventDataIndexer,
           opts: [
             path: ".fact_inst/indices/event_data",
             encoding: {:hash, :sha}
           ]
         ]
       ]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Fact.Supervisor)
  end
end
