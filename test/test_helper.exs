defmodule Fact.TestHelper do
  def create(name, template \\ :default, args \\ []) do
    database_name = "#{name}-#{Fact.Uuid.v4()}"
    database_path = Path.join("tmp", database_name)
    default_args = ["--name", database_name, "--path", database_path, "--quiet"]
    create_args = apply(__MODULE__, template, args)
    Mix.Tasks.Fact.Create.run(default_args ++ create_args)
    database_path
  end

  def default, do: []
  def all_indexers, do: ["--all-indexers"]
end

ExUnit.start()
