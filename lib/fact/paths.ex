defmodule Fact.Paths do
  @app :fact
  @append_logfile ".log"
  @checkpoint_logfile ".checkpoint"
  
  def events, do: get_path([:events])
  
  def append_log, do: Path.join(events(), @append_logfile)
  
  def index(name) when is_atom(name) or is_binary(name), do: get_path([:indices, name])
  def index({name, key}), do: Path.join(index(name), to_string(key))

  def index_checkpoint(index), do: Path.join(index(index), @checkpoint_logfile)
  
  defp get_path(keys) do
    path = 
      Enum.reduce(keys, Application.get_env(@app, :paths, []), fn key, acc ->
        case acc do
          kw when is_list(kw) -> Keyword.fetch!(kw, key)
          _ -> raise "Invalid configuration path for #{inspect(keys)}"
        end
      end)
    
    case Path.type(path) do
      :absolute -> path 
      :relative -> Path.join(File.cwd!(), path)
    end
  end
end