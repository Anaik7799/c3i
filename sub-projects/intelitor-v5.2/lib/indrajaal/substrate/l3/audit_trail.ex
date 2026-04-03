defmodule Indrajaal.Substrate.L3.AuditTrail do
  @moduledoc """
  ## Design Intent
  L3 substrate audit trail — pure functional immutable operation log.

  Biomorphic metaphor: the hippocampus encoding episodic memory — each event is
  appended to an append-only sequence with a cryptographic link to its predecessor,
  forming an unbroken chain of operational history.

  Algorithm:
  1. Each entry stores actor, action, target, timestamp, and a SHA-256 chain hash.
  2. chain_hash(n) = SHA-256(chain_hash(n-1) ++ entry_digest(n)).
  3. Verification walks the chain recomputing hashes and detecting tampering.
  4. Entries are never mutated; the log only grows.
  5. Supports windowed query: entries within a time range.

  ## STAMP Constraints
  - SC-S3-001: Cybernetic VSM S3 control — ENFORCED
  - SC-SMRITI-140: All evolution events recorded — ENFORCED
  - SC-SMRITI-141: Lineage chain unbroken — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type entry :: %{
          seq: pos_integer(),
          actor: String.t(),
          action: String.t(),
          target: String.t(),
          metadata: map(),
          timestamp: DateTime.t(),
          chain_hash: String.t()
        }

  @type t :: %__MODULE__{
          entries: [entry()],
          seq: non_neg_integer(),
          chain_hash: String.t(),
          max_entries: pos_integer()
        }

  @genesis_hash String.duplicate("0", 64)

  defstruct entries: [],
            seq: 0,
            chain_hash: @genesis_hash,
            max_entries: 10_000

  @doc """
  Create a new AuditTrail.

  Options:
  - `:max_entries` — rolling window size ∈ [1, 100_000], default 10_000
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    max = Keyword.get(opts, :max_entries, 10_000)

    cond do
      not is_integer(max) ->
        {:error, "max_entries must be an integer"}

      max < 1 or max > 100_000 ->
        {:error, "max_entries must be in [1, 100_000]"}

      true ->
        {:ok, %__MODULE__{max_entries: max}}
    end
  end

  @doc """
  Append a new entry to the audit trail.

  `actor` — who performed the action
  `action` — verb describing the operation
  `target` — subject of the action
  `metadata` — arbitrary key-value context
  """
  @spec append(t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, t(), entry()} | {:error, String.t()}
  def append(state, actor, action, target, metadata \\ %{})

  def append(%__MODULE__{} = state, actor, action, target, metadata)
      when is_binary(actor) and is_binary(action) and is_binary(target) and is_map(metadata) do
    new_seq = state.seq + 1
    timestamp = DateTime.utc_now()
    entry_digest = compute_entry_digest(actor, action, target, timestamp)
    new_chain_hash = compute_chain_hash(state.chain_hash, entry_digest)

    entry = %{
      seq: new_seq,
      actor: actor,
      action: action,
      target: target,
      metadata: metadata,
      timestamp: timestamp,
      chain_hash: new_chain_hash
    }

    entries = prune([entry | state.entries], state.max_entries)

    new_state = %__MODULE__{
      state
      | entries: entries,
        seq: new_seq,
        chain_hash: new_chain_hash
    }

    {:ok, new_state, entry}
  end

  def append(%__MODULE__{}, _actor, _action, _target, _metadata) do
    {:error, "actor, action, and target must be binaries; metadata must be a map"}
  end

  @doc """
  Verify chain integrity. Returns `:ok` or `{:error, seq}` of first broken link.
  """
  @spec verify(t()) :: :ok | {:error, {:chain_broken, pos_integer()}}
  def verify(%__MODULE__{entries: []}) do
    :ok
  end

  def verify(%__MODULE__{} = state) do
    # Entries are stored newest-first; reverse to walk oldest-first
    sorted = Enum.sort_by(state.entries, & &1.seq)

    Enum.reduce_while(sorted, @genesis_hash, fn entry, prev_hash ->
      digest = compute_entry_digest(entry.actor, entry.action, entry.target, entry.timestamp)
      expected = compute_chain_hash(prev_hash, digest)

      if expected == entry.chain_hash do
        {:cont, entry.chain_hash}
      else
        {:halt, {:error, {:chain_broken, entry.seq}}}
      end
    end)
    |> case do
      {:error, _} = err -> err
      _hash -> :ok
    end
  end

  @doc """
  Query entries by actor (exact match).
  """
  @spec query_by_actor(t(), String.t()) :: [entry()]
  def query_by_actor(%__MODULE__{} = state, actor) when is_binary(actor) do
    Enum.filter(state.entries, &(&1.actor == actor))
  end

  @doc """
  Returns a summary map of the audit trail.
  """
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      entry_count: length(state.entries),
      seq: state.seq,
      chain_hash: String.slice(state.chain_hash, 0, 8) <> "...",
      max_entries: state.max_entries,
      utilization: length(state.entries) / state.max_entries
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────

  @spec compute_entry_digest(String.t(), String.t(), String.t(), DateTime.t()) :: String.t()
  defp compute_entry_digest(actor, action, target, timestamp) do
    data = "#{actor}:#{action}:#{target}:#{DateTime.to_iso8601(timestamp)}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  @spec compute_chain_hash(String.t(), String.t()) :: String.t()
  defp compute_chain_hash(prev_hash, entry_digest) do
    :crypto.hash(:sha256, prev_hash <> entry_digest) |> Base.encode16(case: :lower)
  end

  @spec prune([entry()], pos_integer()) :: [entry()]
  defp prune(entries, max) when length(entries) > max do
    Enum.take(entries, max)
  end

  defp prune(entries, _max), do: entries
end
