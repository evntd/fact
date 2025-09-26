defmodule Fact.Storage do
  @moduledoc false
  
  @table :fact_storage
  
  def write_event(event) do
    driver().write_event(event)
  end
  
  def read_event(record_id) do
    driver().read_event(record_id)
  end

  def read_index_backward(index_file) do
    driver().read_index_backward(index_file)
  end

  def read_index_forward(index_file) do
    driver().read_index_forward(index_file)
  end
  
  def driver(), do: :persistent_term.get({@table, :driver})
  def format(), do: :persistent_term.get({@table, :format})
  
  def init! do
    config = Application.fetch_env!(:fact, Fact.Storage)    
    
    driver = Keyword.fetch!(config, :driver)
    Code.ensure_loaded!(driver)
    :persistent_term.put({@table, :driver}, driver)

    format = Keyword.fetch!(config, :format)
    Code.ensure_loaded!(format)    
    :persistent_term.put({@table, :format}, format)    
  end
end
