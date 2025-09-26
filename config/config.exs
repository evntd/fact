import Config

config :fact,
  db: ".fact_cas/events",
  ledger: ".fact_cas/events/.log",
  indexers: [
    [
      enabled: true,
      mod: Fact.EventStreamIndexer,
      opts: [
        path: ".fact_cas/indices/event_stream"
      ]
    ],
    [
      enabled: true,
      mod: Fact.EventTypeIndexer,
      opts: [
        path: ".fact_cas/indices/event_type"
      ]
    ],
    [
      enabled: true,
      mod: Fact.EventTagsIndexer,
      opts: [
        path: ".fact_cas/indices/tags"
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventDataIndexer,
      opts: [
        path: ".fact_cas/indices/event_data",
        encoding: {:hash, :sha}
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventStreamCategoryIndexer,
      opts: [
        path: ".fact_cas/indices/event_stream_category",
        opts: [
          separator: "-"
        ]
      ]
    ],
    [
      enabled: false,
      mod: Fact.EventStreamsIndexer,
      opts: [
        path: ".fact_cas/indices/streams"
      ]
    ]
  ]

config :fact, Fact.Storage,
  driver: Fact.Storage.Driver.ContentAddressable,
  format: Fact.Storage.Format.Json
  
    
  

