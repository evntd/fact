import Config

config :fact,
  indexers: [
    [enabled: true, 
      mod: Fact.EventStreamIndexer, opts: [path: ".fact/indices/event_stream"]],
    [enabled: true, 
      mod: Fact.EventTypeIndexer, opts: [path: ".fact/indices/event_type"]],
    [enabled: true, 
      mod: Fact.EventDataIndexer, opts: [path: ".fact/indices/event_data", key: "name"]]
  ],
  paths: [
    events: ".fact/events",
    indices: [
      event_type: ".fact/indices/type",
      event_stream: ".fact/indices/stream",
      event_data: ".fact/indices/data"
    ]
  ]