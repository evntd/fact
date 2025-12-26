defmodule Fact.Seam.FileContent.Integer.V1 do
  use Fact.Seam.FileContent,
    family: :integer,
    version: 1
    
  @type t :: %__MODULE__{}
    
  defstruct []

  @impl true
  def decode(%__MODULE__{}, binary) when is_binary(binary) do
    String.to_integer(binary)
  end

  @impl true
  def encode(%__MODULE__{}, content) when is_integer(content) do
    Integer.to_string(content)
  end
  
end
