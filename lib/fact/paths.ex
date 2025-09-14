defmodule Fact.Paths do
  @app :fact
  @append_logfile ".log"
    
  def events, do: get_path([:events])
  
  def append_log, do: Path.join(events(), @append_logfile)
  
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