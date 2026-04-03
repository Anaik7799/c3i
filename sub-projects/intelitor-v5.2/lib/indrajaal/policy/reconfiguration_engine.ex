defmodule Indrajaal.Policy.ReconfigurationEngine do
  @moduledoc """
  ## Design Intent

  L5 Policy Layer — manages safe system reconfiguration using a graph
  transformation model.

  The ReconfigurationEngine is the controlled mutation pathway for any
  configuration change in the Indrajaal mesh. All reconfigurations pass
  through a pre-validation pipeline, are applied atomically, and support
  rollback to the previous configuration state.

  Core responsibilities:
  - Accepts reconfiguration proposals (named `ConfigChange` maps)
  - Pre-validates invariants before applying any change
  - Stores the previous configuration to enable single-step rollback
  - Applies changes as graph transformations (node/edge add/remove/update)
  - Publishes reconfig events via PubSub `"policy:reconfig"`
  - Records applied changes in an append-only history ring

  ## STAMP Constraints

  - SC-RECONFIG-001: Graph transformation MUST be used for all configuration
    changes — no raw overwrite is permitted.
  - SC-RECONFIG-005: Lineage MUST be preserved through reconfiguration — the
    previous config is always stored before applying a new one.
  - SC-RECONFIG-007: Graceful degradation to older versions MUST be possible
    — the rollback function restores the previous config atomically.
  - SC-RECONFIG-009: Guardian approval REQUIRED — callers MUST obtain
    ConstitutionalGovernor approval before calling `apply_change/1`.
  - SC-RECONFIG-010: Federation peers MUST be notified on reconfiguration
    — PubSub broadcast covers local node; cross-holon notification is
    the caller's responsibility.
  - SC-FUNC-003: Rollback path MUST exist for every change.

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — L5 reconfiguration engine |
  """

  use GenServer
  require Logger

  @pubsub_topic "policy:reconfig"
  @history_max 200

  # ─── Types ───────────────────────────────────────────────────────────────────

  @type change_type ::
          :node_add
          | :node_remove
          | :node_update
          | :edge_add
          | :edge_remove
          | :edge_update
          | :config_patch

  @type config_change :: %{
          id: String.t(),
          type: change_type(),
          target: String.t(),
          payload: term(),
          proposer: String.t(),
          timestamp: DateTime.t()
        }

  @type change_result ::
          {:ok, map()}
          | {:error, :invariant_violation, String.t()}
          | {:error, :no_change_to_rollback}
          | {:error, term()}

  @type history_entry :: %{
          change_id: String.t(),
          type: change_type(),
          target: String.t(),
          applied_at: DateTime.t(),
          rolled_back: boolean()
        }

  @type t :: %{
          current_config: map(),
          previous_config: map() | nil,
          change_history: [history_entry()],
          applied_count: non_neg_integer(),
          rollback_count: non_neg_integer(),
          rejected_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ─── Public API ──────────────────────────────────────────────────────────────

  @doc "Start the ReconfigurationEngine GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Validate and apply a configuration change.

  Pre-conditions are checked before the change is applied. If any
  invariant is violated the change is rejected and the current config
  is left unmodified.

  Callers MUST have obtained constitutional approval from
  `Indrajaal.Policy.ConstitutionalGovernor` before calling this function
  (SC-RECONFIG-009).
  """
  @spec apply_change(config_change()) :: change_result()
  def apply_change(%{} = change) do
    GenServer.call(__MODULE__, {:apply_change, change})
  end

  @doc """
  Roll back to the previous configuration.

  Only one level of rollback is supported. A second rollback without an
  intervening `apply_change/1` returns `{:error, :no_change_to_rollback}`.
  """
  @spec rollback() :: change_result()
  def rollback do
    GenServer.call(__MODULE__, :rollback)
  end

  @doc "Get the current active configuration."
  @spec current_config() :: map()
  def current_config do
    GenServer.call(__MODULE__, :current_config)
  end

  @doc "Get the previous configuration (available for one rollback)."
  @spec previous_config() :: map() | nil
  def previous_config do
    GenServer.call(__MODULE__, :previous_config)
  end

  @doc "Get the most recent change history entries."
  @spec change_history(non_neg_integer()) :: [history_entry()]
  def change_history(limit \\ 50) do
    GenServer.call(__MODULE__, {:change_history, limit})
  end

  @doc "Get engine statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ─── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    initial_config = Keyword.get(opts, :initial_config, default_config())

    state = %{
      current_config: initial_config,
      previous_config: nil,
      change_history: [],
      applied_count: 0,
      rollback_count: 0,
      rejected_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[ReconfigurationEngine] Online — SC-RECONFIG-001, SC-RECONFIG-005 — rollback supported"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:apply_change, change}, _from, state) do
    {result, new_state} = do_apply_change(change, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:rollback, _from, state) do
    {result, new_state} = do_rollback(state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:current_config, _from, state) do
    {:reply, state.current_config, state}
  end

  @impl true
  def handle_call(:previous_config, _from, state) do
    {:reply, state.previous_config, state}
  end

  @impl true
  def handle_call({:change_history, limit}, _from, state) do
    history = Enum.take(state.change_history, limit)
    {:reply, history, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      applied_count: state.applied_count,
      rollback_count: state.rollback_count,
      rejected_count: state.rejected_count,
      has_rollback_available: state.previous_config != nil,
      history_length: length(state.change_history),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[ReconfigurationEngine] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  defp do_apply_change(change, state) do
    change_id = Map.get(change, :id, generate_change_id())
    change = Map.put_new(change, :id, change_id)

    case validate_change(change, state.current_config) do
      :ok ->
        # SC-RECONFIG-005: preserve lineage by saving previous config
        previous = state.current_config

        # SC-RECONFIG-001: apply as graph transformation
        new_config = apply_graph_transform(change, state.current_config)

        history_entry = %{
          change_id: change_id,
          type: Map.get(change, :type, :config_patch),
          target: Map.get(change, :target, "unknown"),
          applied_at: DateTime.utc_now(),
          rolled_back: false
        }

        new_history =
          [history_entry | state.change_history]
          |> Enum.take(@history_max)

        new_state = %{
          state
          | current_config: new_config,
            previous_config: previous,
            change_history: new_history,
            applied_count: state.applied_count + 1
        }

        publish_reconfig(:applied, change, new_config)

        Logger.info(
          "[ReconfigurationEngine] APPLIED change=#{change_id} " <>
            "type=#{Map.get(change, :type, :config_patch)} — SC-RECONFIG-001"
        )

        {{:ok, new_config}, new_state}

      {:error, reason} ->
        new_state = %{state | rejected_count: state.rejected_count + 1}

        publish_reconfig(:rejected, change, nil)

        Logger.warning(
          "[ReconfigurationEngine] REJECTED change=#{change_id} " <>
            "reason=#{reason} — invariant violation"
        )

        {{:error, :invariant_violation, reason}, new_state}
    end
  end

  defp do_rollback(%{previous_config: nil} = state) do
    Logger.warning("[ReconfigurationEngine] ROLLBACK requested but no previous config stored")
    {{:error, :no_change_to_rollback}, state}
  end

  defp do_rollback(state) do
    restored = state.previous_config

    # Mark most recent history entry as rolled back
    new_history =
      case state.change_history do
        [latest | rest] -> [%{latest | rolled_back: true} | rest]
        [] -> []
      end

    new_state = %{
      state
      | current_config: restored,
        previous_config: nil,
        change_history: new_history,
        rollback_count: state.rollback_count + 1
    }

    publish_reconfig(:rolled_back, %{id: "rollback"}, restored)

    Logger.info("[ReconfigurationEngine] ROLLBACK complete — SC-RECONFIG-007, SC-FUNC-003")

    {{:ok, restored}, new_state}
  end

  # Pre-validation invariants — SC-RECONFIG-001
  defp validate_change(change, _current_config) do
    cond do
      not is_map(change) ->
        {:error, "change MUST be a map"}

      not is_atom(Map.get(change, :type)) ->
        {:error, "change :type MUST be an atom"}

      Map.get(change, :target) == nil ->
        {:error, "change :target is required"}

      Map.get(change, :type) == :node_remove and
          Map.get(change, :target) in ["constitutional_governor", "guardian"] ->
        {:error,
         "safety-critical nodes (constitutional_governor, guardian) MUST NOT be removed — SC-RECONFIG-009"}

      true ->
        :ok
    end
  end

  # Graph transformation dispatcher — SC-RECONFIG-001
  defp apply_graph_transform(%{type: :node_add} = change, config) do
    node_key = "node.#{Map.get(change, :target)}"
    Map.put(config, node_key, Map.get(change, :payload, %{}))
  end

  defp apply_graph_transform(%{type: :node_remove} = change, config) do
    node_key = "node.#{Map.get(change, :target)}"
    Map.delete(config, node_key)
  end

  defp apply_graph_transform(%{type: :node_update} = change, config) do
    node_key = "node.#{Map.get(change, :target)}"
    existing = Map.get(config, node_key, %{})
    updated = Map.merge(existing, Map.get(change, :payload, %{}))
    Map.put(config, node_key, updated)
  end

  defp apply_graph_transform(%{type: :edge_add} = change, config) do
    edge_key = "edge.#{Map.get(change, :target)}"
    Map.put(config, edge_key, Map.get(change, :payload, %{}))
  end

  defp apply_graph_transform(%{type: :edge_remove} = change, config) do
    edge_key = "edge.#{Map.get(change, :target)}"
    Map.delete(config, edge_key)
  end

  defp apply_graph_transform(%{type: :edge_update} = change, config) do
    edge_key = "edge.#{Map.get(change, :target)}"
    existing = Map.get(config, edge_key, %{})
    updated = Map.merge(existing, Map.get(change, :payload, %{}))
    Map.put(config, edge_key, updated)
  end

  defp apply_graph_transform(%{type: :config_patch} = change, config) do
    payload = Map.get(change, :payload, %{})

    if is_map(payload) do
      Map.merge(config, payload)
    else
      config
    end
  end

  defp apply_graph_transform(_change, config), do: config

  defp publish_reconfig(outcome, change, new_config) do
    message = %{
      event: :reconfig,
      outcome: outcome,
      change_id: Map.get(change, :id, "unknown"),
      change_type: Map.get(change, :type, :config_patch),
      target: Map.get(change, :target, "unknown"),
      config_snapshot: new_config,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:reconfig_event, message})
  end

  defp default_config do
    %{
      "meta.version" => "21.3.1-SIL6",
      "meta.created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp generate_change_id do
    bytes = :crypto.strong_rand_bytes(6)
    "chg_#{Base.encode16(bytes, case: :lower)}"
  end
end
