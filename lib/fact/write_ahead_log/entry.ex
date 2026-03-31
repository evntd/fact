defmodule Fact.WriteAheadLog.Entry do
  @moduledoc """
  Represents a WAL entry. Serialized using :erlang.term_to_binary.
  """

  defstruct [
    :lsn,
    :data,
    :crc,
    is_checkpoint: false
  ]

  @type t :: %__MODULE__{
          lsn: non_neg_integer(),
          data: binary(),
          crc: non_neg_integer(),
          is_checkpoint: boolean()
        }

  @doc """
  Creates a new WAL entry and computes the CRC (IEEE).
  """
  def create(lsn, data, is_checkpoint \\ false) do
    crc = :erlang.crc32(data <> <<lsn::64-little>>)

    %__MODULE__{
      lsn: lsn,
      data: data,
      crc: crc,
      is_checkpoint: is_checkpoint
    }
  end

  @doc """
  Serialize entry to binary.
  """
  def serialize(%__MODULE__{} = entry) do
    :erlang.term_to_binary(entry)
  end

  @doc """
  Deserialize from binary and validate CRC.
  """
  def deserialize(bin) do
    case :erlang.binary_to_term(bin) do
      %__MODULE__{} = entry ->
        expected = :erlang.crc32(entry.data <> <<entry.lsn::64-little>>)

        if expected == entry.crc do
          {:ok, entry}
        else
          {:error, :crc_mismatch}
        end

      other ->
        {:error, {:unexpected_format, other}}
    end
  end
end
