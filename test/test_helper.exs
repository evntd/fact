defmodule Fact.TestHelper do
  require Logger

  def create(name, template \\ :default, args \\ []) when is_atom(template) and is_list(args) do
    {database_name, _} =
      name
      |> String.downcase()
      |> then(fn lcn -> lcn <> Fact.Uuid.v4() end)
      |> String.split_at(63)

    database_path = Path.join("tmp", database_name)
    default_args = ["--name", database_name, "--path", database_path, "--quiet"]
    create_args = apply(__MODULE__, template, [])
    Mix.Tasks.Fact.Create.run(default_args ++ create_args ++ args)
    database_path
  end

  def default, do: []
  def all_indexers, do: ["--all-indexers"]

  def rm_rf(path) do
    case File.rm_rf(path) do
      {:ok, _} ->
        :ok

      {:error, reason, _} ->
        Logger.warning("failed to clean up reason = #{reason}: #{path}")
        :ok
    end
  end
end

ExUnit.start()
