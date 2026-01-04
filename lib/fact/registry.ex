defmodule Fact.Registry do
  
  @doc """
  Get the `Fact.Context` for a running database by its `:database_id` or `:database_name`.
  """
  def get_context(id_or_name) when is_binary(id_or_name) do
    case Registry.lookup(__MODULE__, {:context, id_or_name}) do
      [{_pid, context}] ->
        {:ok, context}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Get the `:database_id` for a running database by its `:database_name`.
  """
  def get_database_id(name) when is_binary(name) do
    case Registry.lookup(__MODULE__, {:id, name}) do
      [{_pid, id}] ->
        {:ok, id}

      [] ->
        {:error, :not_found}
    end
  end
  
  def register(%Fact.Context{database_id: database_id, database_name: database_name} = context) do
    # Store the context by id and name within the registry for lookups when needed.
    Registry.register(__MODULE__, {:context, database_id}, context)
    Registry.register(__MODULE__, {:context, database_name}, context)
    # Store the id by name.
    Registry.register(__MODULE__, {:id, database_name}, database_id)
  end
end
