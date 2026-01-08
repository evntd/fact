defmodule Fact.BuildInfo do
  @moduledoc """
  Compile-time build metadata for the project.
    
  > #### Fun Fact {: .info}
  >
  > I went live with my 0.1.0 release, never testing creation of a database outside of this project.
  > I made a piss poor assumption about Mix.Project, and the result  was databases could not be created
  > via `mix fact.create`. This module is the remedy. It stores some of the key metadata fields defined
  > in `mix.exs` at compile time so they can be used in downstream projects without bombing. 
  > 
  > Live and learn! 🍺
  """
  
  @config Mix.Project.config()
  
  @name @config[:name]
  @version @config[:version]
  @codename @config[:codename]
  @docs_url get_in(@config, [:docs, :canonical])

  @doc """
  The library name.
  """
  @spec name() :: binary()
  def name, do: @name
  
  @doc """
  The library version.
  """
  @spec version() :: binary()
  def version, do: @version
  
  @doc """
  The release code name.
  """
  @spec codename() :: binary()
  def codename, do: @codename
  
  @doc """
  The canonical url to the documentation.
  """
  @spec docs_url() :: binary()
  def docs_url, do: @docs_url
end
