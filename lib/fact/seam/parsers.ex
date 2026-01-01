defmodule Fact.Seam.Parsers do
  def parse_existing_atom(value) when is_binary(value) do
    {:ok, String.to_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def parse_existing_atom(value) when is_atom(value), do: {:ok, value}
  def parse_existing_atom(_), do: :error

  # Simple filenames...for compatibility.
  # - Alpha-numeric
  # - Dots, dashes, and underscores
  # - NO SPACES! They always become a PITA at some point.
  @filename_regex ~r/^[A-Za-z0-9._-]+$/
  def parse_filename(value) when is_binary(value) do
    # Reject anything that includes directory components
    if value == Path.basename(value) and Regex.match?(@filename_regex, value) do
      {:ok, value}
    else
      :error
    end
  end

  def parse_filename(_), do: :error

  @directory_regex ~r/^(\.|\.\.|(?:\/)?[^\/\0]+(?:\/[^\/\0]+)*)\/?$/
  def parse_directory(value) when is_binary(value) do
    if Regex.match?(@directory_regex, value) do
      {:ok, value}
    else
      :error
    end
  end

  def parse_pos_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  def parse_pos_integer(value) when is_binary(value) do
    parse_pos_integer(String.to_integer(value))
  rescue
    ArgumentError ->
      :error
  end

  def parse_pos_integer(_), do: :error

  def parse_non_neg_integer(value) when is_integer(value) and value >= 0, do: {:ok, value}

  def parse_non_neg_integer(value) when is_binary(value) do
    parse_non_neg_integer(String.to_integer(value))
  rescue
    ArgumentError ->
      :error
  end

  def parse_non_neg_integer(_), do: :error
end
