defmodule FactServer.Endpoint do
  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger)
  run(FactServer.Server)
end
