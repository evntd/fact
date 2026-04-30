import Config

config :fact, :fact_server,
  port: 50051,
  database: {"tmp/db", cache: [max_size: 64 * 1024 * 1024]}

import_config "#{config_env()}.exs"
