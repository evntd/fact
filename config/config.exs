import Config

config :fact,
  db: ".fact/events",
  ledger: ".fact/events/.log",
  indexers: [
    [
      enabled: true,
      mod: Fact.EventStreamIndexer,
      opts: [
        path: ".fact/indices/event_stream"
      ]
    ],
    [
      enabled: true,
      mod: Fact.EventTypeIndexer,
      opts: [
        path: ".fact/indices/event_type"
      ]
    ],
    [
      enabled: true,
      mod: Fact.EventTagsIndexer,
      opts: [
        path: ".fact/indices/tags"
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventDataIndexer,
      opts: [
        path: ".fact/indices/event_data",
        encoding: {:hash, :sha}
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventStreamCategoryIndexer,
      opts: [
        path: ".fact/indices/event_stream_category",
        opts: [
          separator: "-"
        ]
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventStreamsIndexer,
      opts: [
        path: ".fact/indices/streams"
      ]
    ]
  ]
