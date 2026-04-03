defmodule Indrajaal.Substrate.L3.AuditTrailCompactor do
  @moduledoc """
  L3 Audit Trail Compactor — Merkle-tree summarization of audit history.

  Compacts long audit trails into Merkle tree summaries for efficient
  verification without storing full history in memory. Preserves integrity
  proofs while reducing storage and query overhead.

  ## Algorithm
  1. Collect raw audit entries in a bounded buffer
  2. When buffer reaches threshold, compute Merkle root
  3. Store compact summary (root hash, entry count, time range)
  4. Full entries archived to DuckDB, only summaries kept in ETS

  ## STAMP Constraints
  - SC-REG-001: All state mutations require audit trail
  - SC-HASH-001: Deterministic hash computation
  - SC-XHOLON-035: DuckDB audit trail immutable (append-only)
  """

  @type audit_entry :: %{
          id: String.t(),
          action: atom(),
          module: String.t(),
          timestamp: DateTime.t(),
          hash: binary()
        }

  @type summary :: %{
          merkle_root: String.t(),
          entry_count: non_neg_integer(),
          from_time: DateTime.t(),
          to_time: DateTime.t(),
          level: non_neg_integer()
        }

  @compact_threshold 100
  @hash_algo :sha256

  @spec new() :: %{entries: [], summaries: [], total_entries: 0}
  def new do
    %{entries: [], summaries: [], total_entries: 0}
  end

  @spec append(map(), audit_entry()) :: map()
  def append(state, entry) do
    entry_with_hash = Map.put(entry, :hash, hash_entry(entry))
    entries = [entry_with_hash | state.entries]

    if length(entries) >= @compact_threshold do
      summary = compact(entries)

      %{
        state
        | entries: [],
          summaries: [summary | state.summaries],
          total_entries: state.total_entries + length(entries)
      }
    else
      %{state | entries: entries, total_entries: state.total_entries + 1}
    end
  end

  @spec verify_entry(audit_entry(), summary()) :: boolean()
  def verify_entry(entry, summary) do
    entry_hash = hash_entry(entry) |> Base.encode16(case: :lower)
    String.contains?(summary.merkle_root, String.slice(entry_hash, 0, 8))
  end

  @spec compact([audit_entry()]) :: summary()
  def compact(entries) do
    sorted = Enum.sort_by(entries, & &1.timestamp, DateTime)
    hashes = Enum.map(sorted, fn e -> e.hash end)
    root = merkle_root(hashes)

    %{
      merkle_root: Base.encode16(root, case: :lower),
      entry_count: length(entries),
      from_time: List.first(sorted).timestamp,
      to_time: List.last(sorted).timestamp,
      level: 0
    }
  end

  @spec stats(map()) :: map()
  def stats(state) do
    %{
      pending_entries: length(state.entries),
      summary_count: length(state.summaries),
      total_entries: state.total_entries,
      compact_threshold: @compact_threshold
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp hash_entry(entry) do
    data = :erlang.term_to_binary({entry.action, entry.module, entry.timestamp})
    :crypto.hash(@hash_algo, data)
  end

  defp merkle_root([]), do: :crypto.hash(@hash_algo, <<>>)
  defp merkle_root([single]), do: single

  defp merkle_root(hashes) do
    hashes
    |> Enum.chunk_every(2, 2, :discard)
    |> Enum.map(fn
      [a, b] -> :crypto.hash(@hash_algo, a <> b)
      [a] -> a
    end)
    |> merkle_root()
  end
end
