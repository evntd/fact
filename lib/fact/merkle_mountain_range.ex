defmodule Fact.MerkleMountainRange do
  @moduledoc """
  A Merkle Mountain Range (MMR) for cryptographic verification of event history integrity.

  An MMR is an append-only authenticated data structure that commits to the full sequence
  of events in a database. Each event becomes a leaf in the tree, and internal nodes are
  computed by hashing pairs of children. The structure enables:

    * **Tamper detection** — any modification, deletion, reordering, or insertion of events
      changes the root hash
    * **Inclusion proofs** — compact O(log n) proofs that a specific event is part of the
      committed history
    * **External verification** — root hashes can be exported and shared with auditors for
      independent verification

  The MMR operates **out of the write path** by subscribing to event notifications via
  PubSub and processing them asynchronously. This adds zero latency to event writes.
  Batching is configurable via `:batch_size` and `:flush_interval`.

  Each leaf commits to the event's content hash, its ledger position, and the previous
  leaf's hash, forming a hash chain within the MMR that detects reordering and insertion.

  The MMR is stored as a flat binary file where node at position `i` is at byte offset
  `i * hash_size`, enabling O(1) random access for proof generation.

  This module requires CAS mode (`record_file_name` configured with `hash@1`). The leaf
  hash is the record ID, which is already the content hash of the event.

  ## Configuration

  The MMR is opt-in, configured via `Fact.open/2`:

      {:ok, db} = Fact.open("data/my_db", merkle: [
        batch_size: 10,
        flush_interval: 1_000
      ])

  See `t:merkle_option/0` for available options.
  """
  @moduledoc since: "0.3.0"
  use GenServer
  import Bitwise

  alias Fact.Event.Schema

  @typedoc """
  MMR configuration options.

    * `:batch_size` - Maximum number of events to buffer before flushing to the MMR file.
      Defaults to `1` (per-event).
    * `:flush_interval` - Maximum time in milliseconds before flushing a partial batch.
      Defaults to `1_000` (1 second).
  """
  @typedoc since: "0.3.0"
  @type merkle_option ::
          {:batch_size, pos_integer()}
          | {:flush_interval, pos_integer()}

  @typedoc """
  Options accepted by `start_link/1`.

    * `:database_id` - (required) The database identifier.
    * `:name` - (required) The registered process name, typically constructed via `Fact.Registry.via/2`.
    * `:batch_size` - See `t:merkle_option/0`.
    * `:flush_interval` - See `t:merkle_option/0`.
  """
  @typedoc since: "0.3.0"
  @type option ::
          {:database_id, Fact.database_id()}
          | {:name, GenServer.name()}
          | merkle_option()

  @typedoc """
  A compact proof that an event at a given position is included in the MMR.

    * `:leaf_index` - The zero-based leaf index in the MMR.
    * `:leaf_hash` - The hash of the leaf node.
    * `:sibling_hashes` - The sibling hashes needed to recompute the path from leaf to peak.
    * `:peaks` - The current peak hashes of the MMR.
  """
  @typedoc since: "0.3.0"
  @type inclusion_proof :: %{
          leaf_index: non_neg_integer(),
          leaf_hash: binary(),
          sibling_hashes: [binary()],
          peaks: [binary()]
        }

  @typedoc """
  The result of a full MMR verification.

    * `:ok` - The MMR matches the stored events.
    * `{:error, :tampered, positions}` - Discrepancies found at the given store positions.
    * `{:error, term()}` - An error occurred during verification.
  """
  @typedoc since: "0.3.0"
  @type verification_result ::
          :ok
          | {:error, :tampered, [non_neg_integer()]}
          | {:error, term()}

  @default_batch_size 1
  @default_flush_interval 1_000

  # -----------------------------
  # Public API
  # -----------------------------

  @doc """
  Starts a `Fact.MerkleMountainRange` process linked to the calling process.

  Requires `:database_id` and `:name` in `opts`. Additional `t:merkle_option/0` keys are optional.
  """
  @doc since: "0.3.0"
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Returns the current peak hashes of the MMR.

  The peaks represent the roots of the complete binary subtrees that make up the MMR.
  Together they form the "root hash" — a commitment to the entire event history.
  An external party can compare peaks against their own computation to verify integrity.
  """
  @doc since: "0.3.0"
  @spec peaks(Fact.database_id()) :: {:ok, [binary()]} | {:error, :not_enabled}
  def peaks(database_id) do
    with_mmr(database_id, fn -> GenServer.call(via(database_id), :peaks) end)
  end

  @doc """
  Creates an inclusion proof for the event at the given ledger position.

  The proof contains the sibling hashes needed to recompute the path from the leaf
  to its peak. An auditor can verify the proof without access to the full database.
  """
  @doc since: "0.3.0"
  @spec create_proof(Fact.database_id(), non_neg_integer()) ::
          {:ok, inclusion_proof()} | {:error, term()}
  def create_proof(database_id, position) when is_integer(position) and position > 0 do
    with_mmr(database_id, fn -> GenServer.call(via(database_id), {:create_proof, position}) end)
  end

  @doc """
  Verifies the integrity of the MMR against the stored events.

  Rebuilds the MMR from scratch by reading all events and comparing against the
  stored MMR file. Returns `:ok` if the MMR matches, or `{:error, :tampered, positions}`
  with a list of leaf positions where discrepancies were found.
  """
  @doc since: "0.3.0"
  @spec verify(Fact.database_id()) :: verification_result()
  def verify(database_id) do
    with_mmr(database_id, fn -> GenServer.call(via(database_id), :verify, :infinity) end)
  end

  @doc """
  Returns the number of leaves (events) committed to the MMR.
  """
  @doc since: "0.3.0"
  @spec leaf_count(Fact.database_id()) :: {:ok, non_neg_integer()} | {:error, :not_enabled}
  def leaf_count(database_id) do
    with_mmr(database_id, fn -> GenServer.call(via(database_id), :leaf_count) end)
  end

  @doc """
  Verifies an inclusion proof independently, without access to the database.

  Given a proof (as returned by `create_proof/2`) and the hash algorithm used by the database,
  recomputes the path from the leaf hash through the sibling hashes and checks that
  the result matches one of the peaks in the proof. This allows an external auditor to
  confirm that a specific event is part of the committed history.

  Returns `:ok` if the proof is valid, or `{:error, reason}` if verification fails.

  ## Example

      {:ok, proof} = Fact.MerkleMountainRange.create_proof(db, 1)
      :ok = Fact.MerkleMountainRange.verify_proof(proof, :sha256)

  """
  @doc since: "0.3.0"
  @spec verify_proof(inclusion_proof(), atom()) :: :ok | {:error, term()}
  def verify_proof(proof, hash_algorithm) do
    %{
      leaf_index: leaf_index,
      leaf_hash: leaf_hash,
      sibling_hashes: sibling_hashes,
      peaks: peaks
    } = proof

    computed_peak =
      sibling_hashes
      |> Enum.with_index()
      |> Enum.reduce(leaf_hash, fn {sibling, height}, current ->
        is_right = (leaf_index >>> height &&& 1) == 1

        if is_right do
          :crypto.hash(hash_algorithm, sibling <> current)
        else
          :crypto.hash(hash_algorithm, current <> sibling)
        end
      end)

    if computed_peak in peaks do
      :ok
    else
      {:error, :proof_invalid}
    end
  end

  defp via(database_id), do: Fact.Registry.via(database_id, __MODULE__)

  defp with_mmr(database_id, fun) do
    case Fact.Registry.lookup(database_id, __MODULE__) do
      [{_pid, _}] -> fun.()
      [] -> {:error, :not_enabled}
    end
  end

  # -----------------------------
  # GenServer Callbacks
  # -----------------------------

  @impl true
  def init(opts) do
    database_id = Keyword.fetch!(opts, :database_id)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    flush_interval = Keyword.get(opts, :flush_interval, @default_flush_interval)

    {:ok, context} = Fact.Registry.get_context(database_id)
    %{state: %{algorithm: hash_algorithm}} = context.record_file_name
    schema = Schema.get(database_id)

    hash_size = hash_byte_size(hash_algorithm)
    directory = Fact.Storage.merkle_mountain_range_path(database_id)
    File.mkdir_p!(directory)

    file = Path.join(directory, "mmr")
    checkpoint_file = Path.join(directory, ".checkpoint")

    {:ok, fd} = :file.open(file, [:read, :write, :binary, :raw])

    {checkpoint, leaf_count} = read_checkpoint(checkpoint_file)

    {mmr_size, leaf_count, prev_leaf_hash} =
      if checkpoint == 0 and leaf_count == 0 do
        # No checkpoint means no confirmed state — truncate any partial MMR data
        :file.truncate(fd)
        {0, 0, <<0::size(hash_size * 8)>>}
      else
        mmr_size = mmr_size_for_leaf_count(leaf_count)
        prev_leaf_hash = read_prev_leaf_hash(fd, leaf_count, hash_size, hash_algorithm)
        {mmr_size, leaf_count, prev_leaf_hash}
      end

    state = %{
      database_id: database_id,
      batch_size: batch_size,
      flush_interval: flush_interval,
      buffer: [],
      mmr_size: mmr_size,
      leaf_count: leaf_count,
      prev_leaf_hash: prev_leaf_hash,
      hash_algorithm: hash_algorithm,
      hash_size: hash_size,
      file: file,
      fd: fd,
      checkpoint: checkpoint,
      checkpoint_file: checkpoint_file,
      schema: schema
    }

    {:ok, state, {:continue, :catch_up}}
  end

  @impl true
  def handle_continue(:catch_up, state) do
    state = replay_from_checkpoint(state)
    :ok = Fact.EventPublisher.subscribe(state.database_id, :all)
    schedule_flush(state.flush_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info({:appended, {record_id, event}}, state) do
    position = event[state.schema.event_store_position]

    if position > state.checkpoint do
      buffer = [{record_id, position} | state.buffer]
      state = %{state | buffer: buffer}

      if length(buffer) >= state.batch_size do
        {:noreply, flush_buffer(state)}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info(:flush, state) do
    state = flush_buffer(state)
    schedule_flush(state.flush_interval)
    {:noreply, state}
  end

  @impl true
  def handle_call(:peaks, _from, state) do
    peak_hashes =
      peak_positions(state.leaf_count)
      |> Enum.map(&read_node(state.fd, &1, state.hash_size))

    {:reply, {:ok, peak_hashes}, state}
  end

  def handle_call({:create_proof, position}, _from, state) do
    leaf_index = position - 1

    if leaf_index < 0 or leaf_index >= state.leaf_count do
      {:reply, {:error, :position_out_of_range}, state}
    else
      mmr_pos = leaf_to_mmr_position(leaf_index)
      leaf_hash = read_node(state.fd, mmr_pos, state.hash_size)

      siblings =
        sibling_path(leaf_index, state.leaf_count)
        |> Enum.map(&read_node(state.fd, &1, state.hash_size))

      peak_hashes =
        peak_positions(state.leaf_count)
        |> Enum.map(&read_node(state.fd, &1, state.hash_size))

      proof = %{
        leaf_index: leaf_index,
        leaf_hash: leaf_hash,
        sibling_hashes: siblings,
        peaks: peak_hashes
      }

      {:reply, {:ok, proof}, state}
    end
  end

  def handle_call(:verify, _from, state) do
    result = do_verify(state)
    {:reply, result, state}
  end

  def handle_call(:leaf_count, _from, state) do
    {:reply, {:ok, state.leaf_count}, state}
  end

  # -----------------------------
  # Buffer Flush
  # -----------------------------

  defp flush_buffer(%{buffer: []} = state), do: state

  defp flush_buffer(state) do
    entries = Enum.reverse(state.buffer)

    state =
      Enum.reduce(entries, state, fn {record_id, position}, acc ->
        append_leaf(acc, record_id, position)
      end)

    :file.sync(state.fd)
    write_checkpoint(state.checkpoint_file, state.checkpoint, state.leaf_count)
    %{state | buffer: []}
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end

  # -----------------------------
  # Catch-up
  # -----------------------------

  defp replay_from_checkpoint(state) do
    Fact.LedgerFile.read(state.database_id, position: state.checkpoint)
    |> Enum.reduce(state, fn record_id, acc ->
      {^record_id, event} = Fact.RecordFile.read(state.database_id, record_id)
      position = event[state.schema.event_store_position]

      if position > acc.checkpoint do
        append_leaf(acc, record_id, position)
      else
        acc
      end
    end)
    |> then(fn state ->
      :file.sync(state.fd)
      write_checkpoint(state.checkpoint_file, state.checkpoint, state.leaf_count)
      state
    end)
  end

  # -----------------------------
  # MMR Append
  # -----------------------------

  defp append_leaf(state, record_id, position) do
    leaf_hash =
      compute_leaf_hash(
        state.hash_algorithm,
        record_id,
        position,
        state.prev_leaf_hash
      )

    leaf_index = state.leaf_count
    mmr_pos = state.mmr_size
    write_node(state.fd, mmr_pos, leaf_hash, state.hash_size)

    state = %{
      state
      | mmr_size: mmr_pos + 1,
        leaf_count: leaf_index + 1,
        prev_leaf_hash: leaf_hash,
        checkpoint: position
    }

    # The number of merges after appending leaf at index i is count_trailing_ones(i).
    # Each merge combines the current node with its left sibling subtree.
    merges = count_trailing_ones(leaf_index)
    do_merges(state, mmr_pos, leaf_hash, 0, merges)
  end

  defp do_merges(state, _pos, _hash, _height, 0), do: state

  defp do_merges(state, current_pos, current_hash, height, remaining) do
    # The left sibling subtree has (2^(height+1) - 1) nodes
    subtree_size = (1 <<< (height + 1)) - 1
    left_sibling_pos = current_pos - subtree_size
    left_hash = read_node(state.fd, left_sibling_pos, state.hash_size)

    parent_hash = compute_node_hash(state.hash_algorithm, left_hash, current_hash)
    parent_pos = state.mmr_size
    write_node(state.fd, parent_pos, parent_hash, state.hash_size)

    state = %{state | mmr_size: parent_pos + 1}
    do_merges(state, parent_pos, parent_hash, height + 1, remaining - 1)
  end

  # -----------------------------
  # Verification
  # -----------------------------

  defp do_verify(state) do
    {:ok, context} = Fact.Registry.get_context(state.database_id)
    prev_leaf_hash = <<0::size(state.hash_size * 8)>>

    tampered =
      Fact.LedgerFile.read(state.database_id)
      |> Enum.with_index()
      |> Enum.reduce({[], prev_leaf_hash}, fn {record_id, index}, {tampered, prev_hash} ->
        case verify_record(context, state, record_id, index, prev_hash) do
          {:ok, _store_position, leaf_hash} ->
            {tampered, leaf_hash}

          {:tampered, store_position, leaf_hash} ->
            {[store_position | tampered], leaf_hash}
        end
      end)
      |> elem(0)
      |> Enum.reverse()

    case tampered do
      [] -> :ok
      positions -> {:error, :tampered, positions}
    end
  end

  defp verify_record(context, state, record_id, index, prev_hash) do
    content_ok? = verify_content_hash(context, record_id)

    # Read event and extract position; if the file was corrupted beyond decoding,
    # treat it as tampered but continue verification with a poison hash.
    {position, decode_ok?} =
      case Fact.RecordFile.read(state.database_id, record_id) do
        {^record_id, event} ->
          pos = event[state.schema.event_store_position]
          if is_integer(pos), do: {pos, true}, else: {index + 1, false}

        _ ->
          {index + 1, false}
      end

    expected_hash = compute_leaf_hash(state.hash_algorithm, record_id, position, prev_hash)
    mmr_pos = leaf_to_mmr_position(index)
    stored_hash = read_node(state.fd, mmr_pos, state.hash_size)

    if content_ok? and decode_ok? and expected_hash == stored_hash do
      {:ok, position, expected_hash}
    else
      {:tampered, position, expected_hash}
    end
  end

  defp verify_content_hash(context, record_id) do
    record_path = Fact.Storage.records_path(context, record_id)

    with {:ok, raw_bytes} <- File.read(record_path),
         {:ok, expected_id} <- Fact.RecordFile.Name.get(context, raw_bytes, []) do
      expected_id == record_id
    else
      _ -> false
    end
  end

  # -----------------------------
  # MMR Position Arithmetic
  # -----------------------------

  @doc false
  def leaf_to_mmr_position(leaf_index) do
    # Each leaf i occupies 1 position, plus count_trailing_ones(i) parent nodes after it.
    # The MMR position of leaf i is: sum over j=0..i-1 of (1 + count_trailing_ones(j))
    do_leaf_to_mmr(0, 0, leaf_index)
  end

  defp do_leaf_to_mmr(mmr_pos, current_leaf, target_leaf) when current_leaf == target_leaf do
    mmr_pos
  end

  defp do_leaf_to_mmr(mmr_pos, current_leaf, target_leaf) do
    parents = count_trailing_ones(current_leaf)
    do_leaf_to_mmr(mmr_pos + 1 + parents, current_leaf + 1, target_leaf)
  end

  defp count_trailing_ones(n) do
    case n &&& 1 do
      0 -> 0
      1 -> 1 + count_trailing_ones(n >>> 1)
    end
  end

  @doc false
  def mmr_size_for_leaf_count(0), do: 0

  def mmr_size_for_leaf_count(n) do
    # mmr_size = 2*n - popcount(n)
    2 * n - popcount(n)
  end

  defp popcount(0), do: 0
  defp popcount(n), do: (n &&& 1) + popcount(n >>> 1)

  @doc false
  def peak_positions(0), do: []

  def peak_positions(leaf_count) do
    # Each set bit in leaf_count at position k (from high to low) corresponds to
    # a complete binary tree with 2^k leaves and (2^(k+1) - 1) nodes.
    do_peak_positions(leaf_count, 0, [])
  end

  defp do_peak_positions(0, _offset, peaks), do: Enum.reverse(peaks)

  defp do_peak_positions(remaining_leaves, offset, peaks) do
    # Find highest set bit
    height = highest_bit_position(remaining_leaves)
    tree_leaves = 1 <<< height
    tree_size = (1 <<< (height + 1)) - 1
    peak_pos = offset + tree_size - 1

    do_peak_positions(
      remaining_leaves - tree_leaves,
      offset + tree_size,
      [peak_pos | peaks]
    )
  end

  defp highest_bit_position(n) when n > 0 do
    do_highest_bit(n, 0)
  end

  defp do_highest_bit(1, pos), do: pos
  defp do_highest_bit(n, pos), do: do_highest_bit(n >>> 1, pos + 1)

  @doc false
  def sibling_path(leaf_index, leaf_count) do
    # Walk from the leaf up to its peak, collecting sibling positions.
    mmr_pos = leaf_to_mmr_position(leaf_index)
    do_sibling_path(mmr_pos, leaf_index, leaf_count, 0, [])
  end

  defp do_sibling_path(pos, leaf_index, leaf_count, height, siblings) do
    subtree_size = (1 <<< (height + 1)) - 1
    subtree_leaves = 1 <<< height

    # Determine if this node is a left or right child by checking
    # whether pairing happened at this height for this leaf.
    # At height h, a merge happened if bit h of leaf_index is 1.
    is_right = (leaf_index >>> height &&& 1) == 1

    cond do
      # Check if we've reached a peak (no more merges at this height)
      not is_right and leaf_index + subtree_leaves >= leaf_count ->
        # This is a peak — stop
        Enum.reverse(siblings)

      is_right ->
        # Right child — left sibling is at pos - subtree_size
        left_sibling = pos - subtree_size
        parent_pos = pos + 1
        do_sibling_path(parent_pos, leaf_index, leaf_count, height + 1, [left_sibling | siblings])

      true ->
        # Left child — right sibling is at pos + subtree_size
        right_sibling = pos + subtree_size
        parent_pos = right_sibling + 1

        do_sibling_path(parent_pos, leaf_index, leaf_count, height + 1, [right_sibling | siblings])
    end
  end

  # -----------------------------
  # Hashing
  # -----------------------------

  defp compute_leaf_hash(algorithm, content_hash, position, prev_leaf_hash) do
    data = to_string(content_hash) <> <<position::unsigned-little-64>> <> prev_leaf_hash
    :crypto.hash(algorithm, data)
  end

  defp compute_node_hash(algorithm, left, right) do
    :crypto.hash(algorithm, left <> right)
  end

  # -----------------------------
  # File I/O
  # -----------------------------

  defp read_node(fd, position, hash_size) do
    offset = position * hash_size
    {:ok, hash} = :file.pread(fd, offset, hash_size)
    hash
  end

  defp write_node(fd, position, hash, hash_size) do
    offset = position * hash_size
    :ok = :file.pwrite(fd, offset, hash)
    :ok = if byte_size(hash) != hash_size, do: raise("hash size mismatch"), else: :ok
  end

  defp read_prev_leaf_hash(_fd, 0, hash_size, _algorithm) do
    <<0::size(hash_size * 8)>>
  end

  defp read_prev_leaf_hash(fd, leaf_count, hash_size, _algorithm) do
    last_leaf_mmr_pos = leaf_to_mmr_position(leaf_count - 1)
    read_node(fd, last_leaf_mmr_pos, hash_size)
  end

  # -----------------------------
  # Checkpoint
  # -----------------------------

  defp read_checkpoint(path) do
    case File.read(path) do
      {:ok, data} ->
        case String.split(String.trim(data), "\n") do
          [pos_str, lc_str] ->
            with {pos, ""} <- Integer.parse(pos_str),
                 {lc, ""} <- Integer.parse(lc_str) do
              {pos, lc}
            else
              _ -> {0, 0}
            end

          [pos_str] ->
            # Legacy single-value checkpoint — leaf_count unknown, reset
            case Integer.parse(pos_str) do
              {_n, ""} -> {0, 0}
              _ -> {0, 0}
            end

          _ ->
            {0, 0}
        end

      {:error, :enoent} ->
        {0, 0}
    end
  end

  defp write_checkpoint(path, position, leaf_count) do
    File.write!(path, "#{position}\n#{leaf_count}")
  end

  # -----------------------------
  # Helpers
  # -----------------------------

  defp hash_byte_size(algorithm) do
    byte_size(:crypto.hash(algorithm, <<>>))
  end
end
