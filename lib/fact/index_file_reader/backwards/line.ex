defmodule Fact.IndexFileReader.Backwards.Line do
  @moduledoc """
  Provides a naive, line-based reader for traversing an index file backwards.
    
  This implementation exists as the simplest way to read event ids in reverse order.
  It demonstrates correctness but is not efficient. Each line is read with a separate `:file.pread/3` call, which means
  one system call per line, incurring significant IO overhead. For large files, this results in poor throughput compared
  to buffered or block-based readers.
    
  This is suitable for small files and test scenarios only.
   
  """

  # a base16 encoded guid string with a newline
  @line_size 33

  @doc """
  Returns a lazy stream of event ids from the given index file, in reverse order.
    
  Each element in the stream is a 32 character base16 encoded UUID string.
    
  ## Example
    
      iex>  Fact.IndexFileReader.Backwards.Line.read(".fact/indices/event_stream/customer-1234") |> Enum.take(1)
      ["4c4417b5b78740ffa764354434174c66"]
    
  """
  def read(path) do
    read(@line_size - 1, path)
  end

  def read(length, path) do
    line_length = length + 1
    size = File.stat!(path).size
    total = div(size, line_length)

    Stream.unfold(total - 1, fn
      -1 ->
        nil

      idx ->
        {:ok, {:ok, data}} =
          File.open(path, [:raw, :read], fn fd ->
            :file.pread(fd, idx * line_length, line_length)
          end)

        <<event_id::binary-size(length), _newline::binary>> = data
        {event_id, idx - 1}
    end)
  end
end
