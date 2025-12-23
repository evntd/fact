defmodule Fact.IndexFileName.Hash.V1 do
  @behaviour Fact.IndexFileName

  defstruct [:algorithm, :encoding]

  @parser_funs %{
    algorithm: :parse_algorithm,
    encoding: :parse_encoding
  }

  @impl true
  def id(), do: :hash

  @impl true
  def version(), do: 1

  @impl true
  def metadata(), do: %{algorithm: :sha, encoding: :base16}

  @impl true
  def init(metadata), do: struct(__MODULE__, Map.merge(metadata(), metadata))

  @impl true
  def normalize_options(%{} = options) do
    options
    |> Map.take([:algorithm, :encoding])
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      parsed = apply(__MODULE__, @parser_funs[key], [value])
      unless parsed, do: acc, else: Map.put(acc, key, parsed)
    end)
  end

  @impl true
  def filename(%__MODULE__{algorithm: algorithm, encoding: encoding} = _format, index_value) do
    hash = :crypto.hash(algorithm, to_string(index_value))

    case encoding do
      :base64 ->
        Base.url_encode64(hash, padding: false)

      :base32 ->
        Base.encode32(hash, case: :lower, padding: false)

      :base16 ->
        Base.encode16(hash, case: :lower)
    end
  end

  def parse_algorithm(value) do
    if value, do: String.to_atom(value), else: nil
  end

  def parse_encoding(value) do
    if value, do: String.to_atom(value), else: nil
  end
end
