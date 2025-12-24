defmodule Fact.Seam.FileName.ContentAddressable.V1 do
  use Fact.Seam.FileName,
    family: :content_addressable,
    version: 1

  defstruct [:algorithm, :encoding]

  @parser_funs %{
    algorithm: :parse_algorithm,
    encoding: :parse_encoding
  }

  @impl true
  def default_options(), do: %{algorithm: :sha256, encoding: :base64}

  @impl true
  def init(options), do: struct(__MODULE__, Map.merge(default_options(), options))

  @impl true
  def normalize_options(%{} = options) do
    options
    |> Map.take([:algorithm, :encoding])
    |> Enum.reduce({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      parsed = apply(__MODULE__, @parser_funs[key], [value])
      unless parsed, do: {:ok, acc}, else: {:ok, Map.put(acc, key, parsed)}
    end)
  end

  @impl true
  def for(%__MODULE__{algorithm: algorithm, encoding: encoding}, encoded_record) do
    hash = :crypto.hash(algorithm, encoded_record)

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
