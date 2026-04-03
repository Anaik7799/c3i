defmodule Indrajaal.Substrate.L3.AccountabilityLedger do
  @moduledoc """
  L3 Accountability Ledger — append-only audit log for subsystem actions.

  Pure module (no GenServer, no side effects) implementing an in-process
  append-only ledger.  Each entry records the actor (who), action (what),
  outcome (result), and a monotonic timestamp.  The ledger is an ordered
  list; newer entries appear at the head.

  ## Guarantees
  - Entries are never removed or modified once appended.
  - `query/2` supports filtering by actor, action, or time range.
  - `audit/1` produces a summary report for a given actor.

  ## Entry Structure
    %{
      seq:        non_neg_integer(),       # monotonic sequence number
      actor:      actor_id(),
      action:     action_id(),
      outcome:    outcome(),
      timestamp:  DateTime.t(),
      metadata:   map()                    # optional key-value context
    }

  ## STAMP Constraints
  - SC-S3-001: S3 operational management constraints — ENFORCED
  - SC-S3-002: Append-only audit log — ENFORCED
  - SC-S3-003: Actor/action/outcome recording — ENFORCED
  - SC-S3-004: Query and audit capabilities — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type actor_id :: atom() | binary()
  @type action_id :: atom() | binary()
  @type outcome :: :success | :failure | :partial | {:error, term()}

  @type entry :: %{
          seq: non_neg_integer(),
          actor: actor_id(),
          action: action_id(),
          outcome: outcome(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @type ledger :: {non_neg_integer(), [entry()]}
  # {next_seq, entries_newest_first}

  @type query_filter ::
          {:actor, actor_id()}
          | {:action, action_id()}
          | {:outcome, outcome()}
          | {:since, DateTime.t()}
          | {:until, DateTime.t()}

  @type audit_report :: %{
          actor: actor_id(),
          total_actions: non_neg_integer(),
          successes: non_neg_integer(),
          failures: non_neg_integer(),
          partials: non_neg_integer(),
          unique_actions: [action_id()],
          first_seen: DateTime.t() | nil,
          last_seen: DateTime.t() | nil
        }

  # ── Public API ───────────────────────────────────────────────────────

  @doc "Creates an empty ledger."
  @spec new() :: ledger()
  def new, do: {0, []}

  @doc """
  Appends a new entry to the ledger.
  Returns the updated ledger (caller must keep the returned value).
  """
  @spec record(ledger(), actor_id(), action_id(), outcome(), map()) :: ledger()
  def record({next_seq, entries}, actor, action, outcome, metadata \\ %{}) do
    entry = %{
      seq: next_seq,
      actor: actor,
      action: action,
      outcome: outcome,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }

    {next_seq + 1, [entry | entries]}
  end

  @doc """
  Query the ledger with one or more filters.
  Returns matching entries in reverse-chronological order (newest first).

  Filters:
  - `{:actor, id}` — entries by a specific actor
  - `{:action, id}` — entries for a specific action
  - `{:outcome, o}` — entries with a specific outcome
  - `{:since, dt}` — entries at or after dt
  - `{:until, dt}` — entries at or before dt
  """
  @spec query(ledger(), [query_filter()]) :: [entry()]
  def query({_seq, entries}, filters) when is_list(filters) do
    Enum.filter(entries, fn entry ->
      Enum.all?(filters, &matches_filter?(entry, &1))
    end)
  end

  @doc """
  Produces an audit report for a given actor, summarising all recorded
  actions, outcomes, and timeline.
  """
  @spec audit(ledger(), actor_id()) :: audit_report()
  def audit({_seq, entries}, actor) do
    actor_entries = Enum.filter(entries, fn e -> e.actor == actor end)

    {successes, failures, partials} =
      Enum.reduce(actor_entries, {0, 0, 0}, fn e, {s, f, p} ->
        case e.outcome do
          :success -> {s + 1, f, p}
          :failure -> {s, f + 1, p}
          {:error, _} -> {s, f + 1, p}
          :partial -> {s, f, p + 1}
          _ -> {s, f, p}
        end
      end)

    unique_actions =
      actor_entries
      |> Enum.map(& &1.action)
      |> Enum.uniq()

    timestamps = Enum.map(actor_entries, & &1.timestamp)

    first_seen =
      case timestamps do
        [] -> nil
        ts -> Enum.min(ts, DateTime)
      end

    last_seen =
      case timestamps do
        [] -> nil
        ts -> Enum.max(ts, DateTime)
      end

    %{
      actor: actor,
      total_actions: length(actor_entries),
      successes: successes,
      failures: failures,
      partials: partials,
      unique_actions: unique_actions,
      first_seen: first_seen,
      last_seen: last_seen
    }
  end

  # ── Private ──────────────────────────────────────────────────────────

  @spec matches_filter?(entry(), query_filter()) :: boolean()
  defp matches_filter?(entry, {:actor, actor}), do: entry.actor == actor
  defp matches_filter?(entry, {:action, action}), do: entry.action == action
  defp matches_filter?(entry, {:outcome, outcome}), do: entry.outcome == outcome

  defp matches_filter?(entry, {:since, dt}) do
    DateTime.compare(entry.timestamp, dt) in [:gt, :eq]
  end

  defp matches_filter?(entry, {:until, dt}) do
    DateTime.compare(entry.timestamp, dt) in [:lt, :eq]
  end

  defp matches_filter?(_entry, _unknown_filter), do: true
end
