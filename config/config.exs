import Config

config :fact,
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
      mod: Fact.EventDataIndexer,
      opts: [
        path: ".fact/indices/event_data",
        encoding: {:hash, :sha}
      ]
    ]
  ],
  ledger: [
    path: ".fact/events/"
  ]
