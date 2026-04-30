import Config

# Tests manage their own gRPC endpoint and databases directly.
# Disable the auto-start so the application supervisor stays minimal.
config :fact, :fact_server, database: nil
