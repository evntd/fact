defmodule Fact.FileNameFormat.Hash.V1 do
  @behaviour Fact.Seam.FileNameFormat

  @type t :: %{
          required(:algorithm) => algorithm(),
          required(:encoding) => encoding()
        }

  @type algorithm ::
          :sha | :md5 | :sha256 | :sha512 | :sha3_256 | :sha3_512 | :blake2b | :blake2s

  @type encoding :: :base16 | :base32 | :base64url

  @type reason ::
          {:invalid_algorithm, term()}
          | {:invalid_encoding, term()}
          | {:unknown_option, term()}

  @enforce_keys [:algorithm, :encoding]
  defstruct [:algorithm, :encoding]

  @option_specs %{
    algorithm: %{
      allowed: [
        :sha,
        :md5,
        :sha256,
        :sha512,
        :sha3_256,
        :sha3_512,
        :blake2b,
        :blake2s
      ],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_algorithm
    },
    encoding: %{
      allowed: [
        :base16,
        :base32,
        :base64url
      ],
      parse: &__MODULE__.parse_existing_atom/1,
      error: :invalid_encoding
    }
  }

  @impl true
  def family(), do: :hash

  @impl true
  def version(), do: 1

  @impl true
  def default_options(), do: %{algorithm: :sha, encoding: :base16}

  @impl true
  @spec init(map()) :: t() | {:error, reason()}
  def init(options) when is_map(options) do
    default_options()
    |> Map.merge(options)
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} ->
        struct(__MODULE__, valid)

      {:error, _} = error ->
        error
    end
  end

  @impl true
  @spec normalize_options(%{atom() => String.t()}) :: t() | {:error, reason()}
  def normalize_options(%{} = options) do
    options
    |> Map.take(Map.keys(@option_specs))
    |> validate_options(@option_specs)
    |> case do
      {:ok, valid} ->
        valid

      {:error, _} = error ->
        error
    end
  end

  @impl true
  @spec for(t(), term()) :: Path.t() | {:error, reason()}
  def for(%__MODULE__{algorithm: algorithm, encoding: encoding} = impl_struct, index_value) do
    with {:ok, _} <- validate_options(Map.from_struct(impl_struct), @option_specs) do
      hash = :crypto.hash(algorithm, to_string(index_value))

      case encoding do
        :base64url ->
          Base.url_encode64(hash, padding: false)

        :base32 ->
          Base.encode32(hash, case: :lower, padding: false)

        :base16 ->
          Base.encode16(hash, case: :lower)
      end
    end
  end

  defp validate_options(options, specs) when is_map(options) do
    Enum.reduce_while(options, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case Map.fetch(specs, key) do
        :error ->
          {:halt, {:error, {:unknown_option, key}}}

        {:ok, %{parse: parse, allowed: allowed, error: error}} ->
          case parse.(value) do
            {:ok, parsed} ->
              if parsed in allowed do
                {:cont, {:ok, Map.put(acc, key, parsed)}}
              else
                {:halt, {:error, {error, value}}}
              end

            _ ->
              {:halt, {:error, {error, value}}}
          end
      end
    end)
  end

  def parse_existing_atom(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def parse_existing_atom(value) when is_atom(value), do: {:ok, value}
  def parse_existing_atom(_), do: :error
end
