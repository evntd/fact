import Config

config :fact, 
  paths: [
    events: ".fact/events",
    indices: [
      event_type: ".fact/indices/type",
      event_stream: ".fact/indices/stream",
      event_data: ".fact/indices/data"
    ]
  ]