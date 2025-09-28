defmodule Fact do
  
  def start_link(name, opts \\ []) when is_binary(name) do
    Fact.Supervisor.start_link(Keyword.put(opts, :name, name))
  end
  
  defmacro __using__(opts) do
    instance = Keyword.fetch!(opts, :name)
    
    quote do
      @instance unquote(instance)
      
      def start_link(opts \\ []), do: Fact.start_link(@instance, opts)
      
    end
  end
  
end
