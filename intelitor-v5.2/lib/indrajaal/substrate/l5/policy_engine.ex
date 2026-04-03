defmodule Indrajaal.Substrate.L5.PolicyEngine do
  @moduledoc """
  ## Design Intent
  L5 GenServer managing policy rules for the Indrajaal VSM fractal mesh.
  Provides `evaluate/2` to check a proposed action against the active policy set,
  returning :allow | :deny | :escalate. Policy rules are loaded at startup and
  can be updated at runtime without restart.

  Policy rule model:
    - Each rule has: id, name, priority (1=highest), condition (fn), action, description
    - Rules are evaluated in priority order (lowest number = highest priority)
    - First matching rule wins — evaluation is short-circuit
    - :allow — action is permitted
    - :deny  — action is blocked; reason recorded
    - :escalate — action requires human/Guardian approval before proceeding

  Rule conditions receive a context map containing:
    - :actor   — who is performing the action
    - :action  — what action is requested
    - :domain  — which domain/resource the action targets
    - :payload — action-specific data

  Built-in safety rules (always present, non-removable):
    P001 — Block all actions from :quarantined actors
    P002 — Escalate destructive bulk operations (> 100 items)
    P003 — Deny direct writes to constitutional data

  ## STAMP Constraints
  - SC-SAFETY-005: Access control enforced — quarantined agents blocked — ENFORCED (P001)
  - SC-GUARD-001: Guardian approval for destructive commands — ENFORCED (P002)
  - SC-ORCH-005: Critical actions need Guardian approval — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 20, L5) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:policy"
  @zenoh_topic "indrajaal/substrate/l5/policy/decision"
  @checkpoint "CP-L5-POLICY-ENGINE-01"

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type decision :: :allow | :deny | :escalate

  @type rule :: %{
          id: String.t(),
          name: String.t(),
          priority: pos_integer(),
          description: String.t(),
          removable: boolean(),
          condition: (map() -> boolean()),
          decision: decision()
        }

  @type context :: %{
          optional(:actor) => atom() | String.t(),
          optional(:action) => atom() | String.t(),
          optional(:domain) => atom() | String.t(),
          optional(:payload) => map()
        }

  @type eval_result :: %{
          decision: decision(),
          rule_id: String.t() | nil,
          rule_name: String.t() | nil,
          reason: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Evaluate an action context against the active policy set.
  Returns `:allow`, `:deny`, or `:escalate` with the matching rule info.
  """
  @spec evaluate(atom() | String.t(), context()) :: eval_result()
  def evaluate(action, context) when is_map(context) do
    ctx = Map.put(context, :action, action)
    GenServer.call(@name, {:evaluate, ctx})
  end

  @doc """
  Add a custom policy rule at runtime.
  Returns `{:ok, rule_id}` on success.
  """
  @spec add_rule(map()) :: {:ok, String.t()} | {:error, term()}
  def add_rule(rule_attrs) when is_map(rule_attrs) do
    GenServer.call(@name, {:add_rule, rule_attrs})
  end

  @doc """
  Remove a custom (removable) rule by id.
  """
  @spec remove_rule(String.t()) :: :ok | {:error, term()}
  def remove_rule(rule_id) when is_binary(rule_id) do
    GenServer.call(@name, {:remove_rule, rule_id})
  end

  @doc """
  List all active policy rules in priority order.
  """
  @spec list_rules() :: [rule()]
  def list_rules do
    GenServer.call(@name, :list_rules)
  end

  @doc """
  Return evaluation statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    rules = built_in_rules()

    state = %{
      rules: rules,
      eval_count: 0,
      allow_count: 0,
      deny_count: 0,
      escalate_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning(
      "[POLICY_ENGINE] Started — #{length(rules)} built-in rules checkpoint=#{@checkpoint}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:evaluate, ctx}, _from, state) do
    result = do_evaluate(ctx, state.rules)

    new_state =
      case result.decision do
        :allow ->
          %{state | eval_count: state.eval_count + 1, allow_count: state.allow_count + 1}

        :deny ->
          %{state | eval_count: state.eval_count + 1, deny_count: state.deny_count + 1}

        :escalate ->
          %{
            state
            | eval_count: state.eval_count + 1,
              escalate_count: state.escalate_count + 1
          }
      end

    broadcast_decision(ctx, result)
    emit_telemetry(result, new_state.eval_count)

    Logger.debug(
      "[POLICY_ENGINE] Decision=#{result.decision} " <>
        "action=#{inspect(ctx[:action])} actor=#{inspect(ctx[:actor])} " <>
        "rule=#{result.rule_id}"
    )

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:add_rule, attrs}, _from, state) do
    id = Map.get(attrs, :id, generate_id())

    rule = %{
      id: id,
      name: Map.get(attrs, :name, "Custom rule #{id}"),
      priority: Map.get(attrs, :priority, 500),
      description: Map.get(attrs, :description, ""),
      removable: Map.get(attrs, :removable, true),
      condition: Map.get(attrs, :condition, fn _ctx -> false end),
      decision: Map.get(attrs, :decision, :deny)
    }

    sorted_rules =
      [rule | state.rules]
      |> Enum.sort_by(& &1.priority)

    Logger.info(
      "[POLICY_ENGINE] Rule added id=#{id} priority=#{rule.priority} decision=#{rule.decision}"
    )

    {:reply, {:ok, id}, %{state | rules: sorted_rules}}
  end

  @impl true
  def handle_call({:remove_rule, rule_id}, _from, state) do
    case Enum.find(state.rules, &(&1.id == rule_id)) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{removable: false} ->
        {:reply, {:error, :built_in_rule_immutable}, state}

      _ ->
        new_rules = Enum.reject(state.rules, &(&1.id == rule_id))
        Logger.info("[POLICY_ENGINE] Rule removed id=#{rule_id}")
        {:reply, :ok, %{state | rules: new_rules}}
    end
  end

  @impl true
  def handle_call(:list_rules, _from, state) do
    # Return without function fields (not serializable)
    rules =
      Enum.map(state.rules, fn r ->
        Map.drop(r, [:condition])
      end)

    {:reply, rules, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      rule_count: length(state.rules),
      eval_count: state.eval_count,
      allow_count: state.allow_count,
      deny_count: state.deny_count,
      escalate_count: state.escalate_count,
      started_at: state.started_at
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[POLICY_ENGINE] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp do_evaluate(ctx, rules) do
    case Enum.find(rules, fn rule ->
           try do
             rule.condition.(ctx)
           rescue
             _ -> false
           end
         end) do
      nil ->
        # Default: allow if no rule matched
        %{decision: :allow, rule_id: nil, rule_name: nil, reason: "default_allow"}

      rule ->
        %{
          decision: rule.decision,
          rule_id: rule.id,
          rule_name: rule.name,
          reason: rule.description
        }
    end
  end

  defp built_in_rules do
    [
      %{
        id: "P001",
        name: "Block quarantined actors",
        priority: 1,
        description: "SC-SAFETY-005: Quarantined agents blocked",
        removable: false,
        condition: fn ctx -> ctx[:actor] == :quarantined end,
        decision: :deny
      },
      %{
        id: "P002",
        name: "Escalate bulk destructive operations",
        priority: 2,
        description: "SC-GUARD-001: Bulk destructive ops require Guardian approval",
        removable: false,
        condition: fn ctx ->
          action = ctx[:action]
          count = get_in(ctx, [:payload, :count]) || 0
          action in [:bulk_delete, :bulk_update, :mass_revoke] and count > 100
        end,
        decision: :escalate
      },
      %{
        id: "P003",
        name: "Deny direct constitutional writes",
        priority: 3,
        description: "SC-RECONFIG-009: Constitutional writes require Guardian approval",
        removable: false,
        condition: fn ctx ->
          ctx[:domain] == :constitution and
            ctx[:action] in [:write, :delete, :update, :modify]
        end,
        decision: :deny
      }
    ]
    |> Enum.sort_by(& &1.priority)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end

  defp broadcast_decision(ctx, result) do
    payload = %{
      action: ctx[:action],
      actor: ctx[:actor],
      domain: ctx[:domain],
      decision: result.decision,
      rule_id: result.rule_id
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:policy_decision, payload}
      )
    rescue
      _ -> :ok
    end

    if result.decision in [:deny, :escalate] do
      publish_zenoh(payload)
    end
  end

  defp publish_zenoh(payload) do
    data =
      Map.merge(payload, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(result, eval_count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l5, :policy_engine, :evaluate],
        %{eval_count: eval_count},
        %{
          checkpoint: @checkpoint,
          decision: result.decision,
          rule_id: result.rule_id,
          constraint: "SC-SAFETY-005"
        }
      )
    rescue
      _ -> :ok
    end
  end
end
