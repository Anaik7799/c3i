defmodule Indrajaal.Substrate.L0.MembraneFilter do
  @moduledoc """
  ## Design Intent
  L0 substrate membrane filter — accepts or rejects messages based on a set of
  declarative pattern rules stored in ETS. Rules have a priority, a match
  condition (key/value predicate), and an action (:allow | :deny).

  Rule evaluation:
    1. Rules sorted by priority (ascending — lowest number = highest priority)
    2. First matching rule determines outcome
    3. If no rule matches, default action is applied (:allow by default)
    4. Audit counters maintained per rule in ETS

  Message shape: any map. Rules match on top-level map keys/values.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-SAFETY-005: Access control enforced — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  require Logger

  @ets_rules :membrane_filter_rules
  @ets_stats :membrane_filter_stats

  @type rule_id :: String.t()
  @type action :: :allow | :deny
  @type match_fn :: (map() -> boolean())

  @type rule :: %{
          id: rule_id(),
          priority: non_neg_integer(),
          description: String.t(),
          match: match_fn(),
          action: action()
        }

  # ---------------------------------------------------------------------------
  # ETS initialisation — call once at application start or in a supervisor
  # ---------------------------------------------------------------------------

  @doc "Initialise the ETS tables. Idempotent — safe to call multiple times."
  @spec init_tables() :: :ok
  def init_tables do
    if :ets.whereis(@ets_rules) == :undefined do
      :ets.new(@ets_rules, [:ordered_set, :public, :named_table, read_concurrency: true])
    end

    if :ets.whereis(@ets_stats) == :undefined do
      :ets.new(@ets_stats, [:set, :public, :named_table, write_concurrency: true])
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Add or update a rule. If a rule with the same id already exists it is replaced.

  `priority` — lower value = evaluated first.
  `match`    — predicate function `(map() -> boolean())`.
  `action`   — `:allow` or `:deny`.
  """
  @spec add_rule(rule_id(), non_neg_integer(), String.t(), match_fn(), action()) :: :ok
  def add_rule(id, priority, description, match_fn, action)
      when is_binary(id) and is_integer(priority) and priority >= 0 and
             is_function(match_fn, 1) and action in [:allow, :deny] do
    ensure_tables()

    :ets.insert(
      @ets_rules,
      {{priority, id}, %{id: id, description: description, match: match_fn, action: action}}
    )

    :ets.insert(@ets_stats, {id, 0})
    :ok
  end

  @doc "Remove rule by id."
  @spec remove_rule(rule_id()) :: :ok
  def remove_rule(id) when is_binary(id) do
    ensure_tables()

    :ets.match_delete(@ets_rules, {{:_, id}, :_})
    :ets.delete(@ets_stats, id)
    :ok
  end

  @doc """
  Filter a message.

  Returns `{:allow, message}` or `{:deny, message, reason}`.
  `default` is the action when no rule matches (default `:allow`).
  """
  @spec filter(map(), action()) ::
          {:allow, map()} | {:deny, map(), String.t()}
  def filter(message, default \\ :allow) when is_map(message) and default in [:allow, :deny] do
    ensure_tables()
    apply_rules(:ets.first(@ets_rules), message, default)
  end

  @doc "List all rules ordered by priority."
  @spec list_rules() :: [rule()]
  def list_rules do
    ensure_tables()

    :ets.tab2list(@ets_rules)
    |> Enum.sort_by(fn {{p, _id}, _} -> p end)
    |> Enum.map(fn {_, rule} -> rule end)
  end

  @doc "Return hit count for rule id."
  @spec hit_count(rule_id()) :: non_neg_integer()
  def hit_count(id) when is_binary(id) do
    ensure_tables()

    case :ets.lookup(@ets_stats, id) do
      [{^id, count}] -> count
      [] -> 0
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec apply_rules(any(), map(), action()) :: {:allow, map()} | {:deny, map(), String.t()}
  defp apply_rules(:"$end_of_table", message, default) do
    case default do
      :allow -> {:allow, message}
      :deny -> {:deny, message, "default-deny: no matching rule"}
    end
  end

  defp apply_rules(key, message, default) do
    [{^key, rule}] = :ets.lookup(@ets_rules, key)

    if rule.match.(message) do
      :ets.update_counter(@ets_stats, rule.id, {2, 1})

      case rule.action do
        :allow ->
          {:allow, message}

        :deny ->
          {:deny, message, "rule #{rule.id}: #{rule.description}"}
      end
    else
      apply_rules(:ets.next(@ets_rules, key), message, default)
    end
  end

  defp ensure_tables do
    if :ets.whereis(@ets_rules) == :undefined, do: init_tables()
  end
end
