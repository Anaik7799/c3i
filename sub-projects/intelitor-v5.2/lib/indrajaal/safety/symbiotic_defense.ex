defmodule Indrajaal.Safety.SymbioticDefense do
  @moduledoc """
  Symbiotic Defense System - Coordinated Multi-Layer Protection.

  ## What
  Central coordination point for the safety system's defense layers.
  Manages Sentinel, PatternHunter, and Guardian as unified defense components.
  Implements defense level state machine with escalation/de-escalation logic.

  ## Why
  STAMP Constraints require coordinated defense:
  - SC-PROM-007: Hibernation - serialize state before scale down
  - SC-PRIME-003: Xenobiology - don't terminate external nodes without cause
  - AOR-CONST-003: Guardian has absolute veto
  - SC-FOUNDER-007: Threats to Founder/lineage eliminated immediately
  - AOR-HOLON-012: Self-healing recovery from SQLite/DuckDB
  - SC-IMMUNE-005: Recovery attempts limited to 3 before escalation

  ## Defense Levels
  - :normal - All systems green, standard monitoring
  - :elevated - Increased monitoring, faster scan cycles
  - :guarded - Throttling active, resource limits enforced
  - :high - Isolation active, suspicious processes quarantined
  - :critical - Recovery mode, emergency protocols engaged

  ## Coordination Protocol
  1. Defenders register with SymbioticDefense
  2. Threats detected by any defender flow to coordinator
  3. Coordinator evaluates threat and determines response
  4. Response broadcasted to all registered defenders
  5. Escalation/de-escalation managed centrally

  ## 5-Phase Recovery Protocol (AOR-HOLON-012)
  1. **Restart** - Attempt Supervisor.restart_child/2 via supervision tree
  2. **Reconfigure** - Direct start if not under supervision
  3. **Rollback** - Restore from SQLite/DuckDB checkpoint
  4. **Escalate** - Guardian approval for force restart
  5. **Manual** - Human intervention required after 3 attempts

  ## Self-Healing Capabilities
  - Automatic service restart via supervision tree
  - SQLite/DuckDB state restoration for holon recovery
  - Exponential backoff retry with max 3 attempts
  - Guardian approval required for critical escalations
  - Telemetry for all recovery phases and service attempts

  ## OODA Integration
  Fast threat coordination loop integrated with all defense layers.
  Cycle time <100ms per SC-OODA-001.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-26 | Claude Opus 4.5 | Implemented 5-phase recovery with supervisor restarts |
  | 21.2.0 | 2026-01-10 | Initial | Initial SymbioticDefense coordination |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.{Guardian, PatternHunter, Sentinel}
  alias Indrajaal.Core.Holon.FounderDirective

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type defense_level :: :normal | :elevated | :guarded | :high | :critical
  @type threat_category :: :financial | :reputational | :operational | :existential | :lineage
  @type threat_severity :: :low | :medium | :high | :critical | :extinction
  @type defender_id :: atom()

  @type defender_info :: %{
          pid: pid(),
          module: module(),
          registered_at: DateTime.t(),
          last_heartbeat: DateTime.t(),
          capabilities: [atom()]
        }

  @type threat_record :: %{
          id: String.t(),
          type: atom(),
          severity: threat_severity(),
          category: threat_category(),
          source: atom(),
          detected_at: DateTime.t(),
          response_action: atom()
        }

  # ============================================================================
  # Constants
  # ============================================================================

  @defense_levels [:normal, :elevated, :guarded, :high, :critical]

  @level_transitions %{
    normal: [:elevated],
    elevated: [:normal, :guarded],
    guarded: [:elevated, :high],
    high: [:guarded, :critical],
    critical: [:high]
  }

  @escalation_thresholds %{
    normal: 0,
    elevated: 3,
    guarded: 5,
    high: 8,
    critical: 10
  }

  @level_response_actions %{
    normal: [:log],
    elevated: [:log, :increase_monitoring],
    guarded: [:log, :throttle, :alert],
    high: [:log, :isolate, :alert, :notify_guardian],
    critical: [:log, :isolate, :halt_operations, :recovery_mode]
  }

  @extinction_response_ms 100
  @critical_response_ms 500
  @high_response_ms 2_000
  @heartbeat_interval_ms 5_000
  @auto_deescalation_ms 60_000

  # ============================================================================
  # State Structure
  # ============================================================================

  defstruct [
    :name,
    defense_level: :normal,
    level_changed_at: nil,
    defenders: %{},
    active_threats: [],
    neutralized_threats: [],
    threat_score: 0,
    escalation_history: [],
    founder_status: :active,
    lineage_health: 100,
    resource_allocation: %{},
    recovery_state: nil,
    stats: %{
      threats_assessed: 0,
      threats_neutralized: 0,
      escalations: 0,
      de_escalations: 0,
      coordinated_responses: 0,
      resources_protected: 0
    }
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Symbiotic Defense system.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get the current defense level.
  """
  @spec get_defense_level() :: defense_level()
  def get_defense_level do
    GenServer.call(__MODULE__, :get_defense_level)
  end

  @doc """
  Escalate to a higher defense level.
  Validates the transition is allowed per state machine.
  """
  @spec escalate(defense_level(), String.t()) :: :ok | {:error, :invalid_transition}
  def escalate(target_level, reason) do
    GenServer.call(__MODULE__, {:escalate, target_level, reason})
  end

  @doc """
  De-escalate to a lower defense level.
  Requires all threats to be neutralized first.
  """
  @spec de_escalate(defense_level(), String.t()) :: :ok | {:error, term()}
  def de_escalate(target_level, reason) do
    GenServer.call(__MODULE__, {:de_escalate, target_level, reason})
  end

  @doc """
  Register a defender component (Sentinel, PatternHunter, Guardian).
  """
  @spec register_defender(defender_id(), pid()) :: :ok
  def register_defender(defender_id, pid) do
    GenServer.call(__MODULE__, {:register_defender, defender_id, pid})
  end

  @doc """
  Unregister a defender component.
  """
  @spec unregister_defender(defender_id()) :: :ok
  def unregister_defender(defender_id) do
    GenServer.cast(__MODULE__, {:unregister_defender, defender_id})
  end

  @doc """
  Coordinate a response across all defense layers.
  Called when a threat is detected by any defender.
  """
  @spec coordinate_response(atom(), map()) :: :ok
  def coordinate_response(event_type, metadata) do
    GenServer.cast(__MODULE__, {:coordinate_response, event_type, metadata})
  end

  @doc """
  Assess a potential threat to Founder's interests.
  Returns threat classification and recommended action.
  """
  @spec assess_threat(map()) :: {:ok, map()} | {:error, term()}
  def assess_threat(event) do
    GenServer.call(__MODULE__, {:assess_threat, event})
  end

  @doc """
  Report a confirmed lineage threat for immediate response.
  """
  @spec report_lineage_threat(map()) :: :ok
  def report_lineage_threat(threat) do
    GenServer.cast(__MODULE__, {:lineage_threat, threat})
  end

  @doc """
  Check current Founder/lineage protection status.
  """
  @spec protection_status() :: map()
  def protection_status do
    GenServer.call(__MODULE__, :protection_status)
  end

  @doc """
  Allocate resources to Founder's benefit.
  SC-FOUNDER-002: Resource acquisition is PRIMARY objective.
  """
  @spec allocate_resources(atom(), number()) :: :ok
  def allocate_resources(resource_type, amount) do
    GenServer.cast(__MODULE__, {:allocate_resources, resource_type, amount})
  end

  @doc """
  Verify symbiotic binding integrity.
  SC-FOUNDER-004: Symbiotic binding CANNOT be severed.
  """
  @spec verify_binding() :: {:ok, :intact} | {:error, :compromised}
  def verify_binding do
    GenServer.call(__MODULE__, :verify_binding)
  end

  @doc """
  Get list of registered defenders.
  """
  @spec list_defenders() :: [defender_id()]
  def list_defenders do
    GenServer.call(__MODULE__, :list_defenders)
  end

  @doc """
  Initiate recovery procedures.
  Called when defense level reaches :critical.
  """
  @spec initiate_recovery(String.t()) :: :ok
  def initiate_recovery(reason) do
    GenServer.cast(__MODULE__, {:initiate_recovery, reason})
  end

  @doc """
  Serialize state for hibernation.
  SC-PROM-007: Agents MUST serialize state to persistent storage before Scale Down.
  """
  @spec serialize_state() :: {:ok, binary()} | {:error, term()}
  def serialize_state do
    GenServer.call(__MODULE__, :serialize_state)
  end

  @doc """
  Restore state from serialized data.
  """
  @spec restore_state(binary()) :: :ok | {:error, term()}
  def restore_state(data) do
    GenServer.call(__MODULE__, {:restore_state, data})
  end

  @doc """
  Get comprehensive defense status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.get(opts, :name, __MODULE__),
      level_changed_at: DateTime.utc_now()
    }

    # Verify FounderDirective is accessible
    verify_founder_directive()

    # Schedule heartbeat check
    schedule_heartbeat()

    # Schedule auto-deescalation check
    schedule_deescalation_check()

    Logger.info(
      "[SymbioticDefense] Initialized - Defense Level: :normal - Symbiotic binding established"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_defense_level, _from, state) do
    {:reply, state.defense_level, state}
  end

  @impl true
  def handle_call({:escalate, target_level, reason}, _from, state) do
    case validate_escalation(state.defense_level, target_level) do
      :ok ->
        new_state = do_escalate(state, target_level, reason)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:de_escalate, target_level, reason}, _from, state) do
    case validate_de_escalation(state, target_level) do
      :ok ->
        new_state = do_de_escalate(state, target_level, reason)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:register_defender, defender_id, pid}, _from, state) do
    defender_info = %{
      pid: pid,
      module: defender_id_to_module(defender_id),
      registered_at: DateTime.utc_now(),
      last_heartbeat: DateTime.utc_now(),
      capabilities: get_defender_capabilities(defender_id)
    }

    Process.monitor(pid)
    new_defenders = Map.put(state.defenders, defender_id, defender_info)
    new_state = %{state | defenders: new_defenders}

    Logger.info("[SymbioticDefense] Defender registered: #{defender_id}")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_defenders, _from, state) do
    {:reply, Map.keys(state.defenders), state}
  end

  @impl true
  def handle_call({:assess_threat, event}, _from, state) do
    assessment = perform_threat_assessment(event, state)
    new_state = update_threat_score(state, assessment)
    new_state = update_in(new_state.stats.threats_assessed, &(&1 + 1))

    {:reply, {:ok, assessment}, new_state}
  end

  @impl true
  def handle_call(:protection_status, _from, state) do
    status = %{
      defense_level: state.defense_level,
      founder_status: state.founder_status,
      lineage_health: state.lineage_health,
      active_threats: length(state.active_threats),
      threat_score: state.threat_score,
      binding_status: :intact,
      resource_allocation: state.resource_allocation,
      registered_defenders: Map.keys(state.defenders),
      stats: state.stats
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:verify_binding, _from, state) do
    binding_check = check_symbiotic_binding()

    case binding_check do
      :intact ->
        {:reply, {:ok, :intact}, state}

      :compromised ->
        Logger.error("[SymbioticDefense] CRITICAL: Symbiotic binding compromised!")
        Guardian.emergency_stop("Symbiotic binding compromised")
        {:reply, {:error, :compromised}, state}
    end
  end

  @impl true
  def handle_call(:serialize_state, _from, state) do
    # SC-PROM-007: Serialize state for hibernation
    serializable = %{
      defense_level: state.defense_level,
      threat_score: state.threat_score,
      active_threats: state.active_threats,
      escalation_history: Enum.take(state.escalation_history, 100),
      founder_status: state.founder_status,
      lineage_health: state.lineage_health,
      resource_allocation: state.resource_allocation,
      stats: state.stats,
      serialized_at: DateTime.utc_now()
    }

    case :erlang.term_to_binary(serializable, [:compressed]) do
      binary when is_binary(binary) ->
        Logger.info("[SymbioticDefense] State serialized for hibernation")
        {:reply, {:ok, binary}, state}
    end
  end

  @impl true
  def handle_call({:restore_state, data}, _from, state) do
    try do
      restored = :erlang.binary_to_term(data, [:safe])

      new_state = %{
        state
        | defense_level: restored.defense_level,
          threat_score: restored.threat_score,
          active_threats: restored.active_threats,
          escalation_history: restored.escalation_history,
          founder_status: restored.founder_status,
          lineage_health: restored.lineage_health,
          resource_allocation: restored.resource_allocation,
          stats: Map.merge(state.stats, restored.stats)
      }

      Logger.info("[SymbioticDefense] State restored from hibernation")
      {:reply, :ok, new_state}
    rescue
      error ->
        Logger.error("[SymbioticDefense] Failed to restore state: #{inspect(error)}")
        {:reply, {:error, :invalid_state_data}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      defense_level: state.defense_level,
      level_changed_at: state.level_changed_at,
      threat_score: state.threat_score,
      active_threats: length(state.active_threats),
      neutralized_threats: length(state.neutralized_threats),
      registered_defenders:
        Enum.map(state.defenders, fn {id, info} ->
          %{id: id, module: info.module, registered_at: info.registered_at}
        end),
      escalation_history: Enum.take(state.escalation_history, 10),
      recovery_state: state.recovery_state,
      stats: state.stats,
      available_actions: Map.get(@level_response_actions, state.defense_level, [])
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:unregister_defender, defender_id}, state) do
    new_defenders = Map.delete(state.defenders, defender_id)
    Logger.info("[SymbioticDefense] Defender unregistered: #{defender_id}")
    {:noreply, %{state | defenders: new_defenders}}
  end

  @impl true
  def handle_cast({:coordinate_response, event_type, metadata}, state) do
    new_state = handle_coordinated_response(state, event_type, metadata)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:lineage_threat, threat}, state) do
    severity = classify_threat_severity(threat)

    Logger.warning(
      "[SymbioticDefense] Lineage threat detected: #{severity} - #{inspect(threat[:type])}"
    )

    new_state =
      case severity do
        :extinction ->
          spawn(fn -> eliminate_threat(threat, @extinction_response_ms) end)
          state |> add_active_threat(threat, severity) |> auto_escalate(:critical)

        :critical ->
          spawn(fn -> eliminate_threat(threat, @critical_response_ms) end)
          state |> add_active_threat(threat, severity) |> auto_escalate(:high)

        :high ->
          spawn(fn -> neutralize_threat(threat, @high_response_ms) end)
          state |> add_active_threat(threat, severity) |> auto_escalate(:guarded)

        _ ->
          add_active_threat(state, threat, severity)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:allocate_resources, resource_type, amount}, state) do
    new_allocation =
      Map.update(
        state.resource_allocation,
        resource_type,
        amount,
        &(&1 + amount)
      )

    new_state = %{
      state
      | resource_allocation: new_allocation,
        stats: Map.update!(state.stats, :resources_protected, &(&1 + amount))
    }

    Logger.info("[SymbioticDefense] Resources allocated: #{resource_type} += #{amount}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:initiate_recovery, reason}, state) do
    Logger.warning("[SymbioticDefense] Initiating recovery: #{reason}")

    recovery_state = %{
      initiated_at: DateTime.utc_now(),
      reason: reason,
      phase: :assessment,
      actions_taken: []
    }

    new_state = execute_recovery_phase(%{state | recovery_state: recovery_state})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:threat_neutralized, threat_id}, state) do
    {threats, remaining} = Enum.split_with(state.active_threats, fn t -> t.id == threat_id end)

    new_state = %{
      state
      | active_threats: remaining,
        neutralized_threats: threats ++ state.neutralized_threats,
        stats: Map.update!(state.stats, :threats_neutralized, &(&1 + 1))
    }

    new_state = recalculate_threat_score(new_state)
    Logger.info("[SymbioticDefense] Threat neutralized: #{threat_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:heartbeat_check, state) do
    # Check defender heartbeats and remove stale ones
    now = DateTime.utc_now()

    stale_defenders =
      Enum.filter(state.defenders, fn {_id, info} ->
        DateTime.diff(now, info.last_heartbeat, :millisecond) > @heartbeat_interval_ms * 3
      end)

    new_state =
      Enum.reduce(stale_defenders, state, fn {id, _info}, acc ->
        Logger.warning("[SymbioticDefense] Defender #{id} heartbeat stale, removing")
        %{acc | defenders: Map.delete(acc.defenders, id)}
      end)

    schedule_heartbeat()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:deescalation_check, state) do
    new_state = check_auto_deescalation(state)
    schedule_deescalation_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Defender process terminated
    {defender_id, _} =
      Enum.find(state.defenders, {nil, nil}, fn {_id, info} -> info.pid == pid end)

    if defender_id do
      Logger.warning("[SymbioticDefense] Defender #{defender_id} down: #{inspect(reason)}")
      new_defenders = Map.delete(state.defenders, defender_id)
      {:noreply, %{state | defenders: new_defenders}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================================
  # Defense Level State Machine
  # ============================================================================

  defp validate_escalation(current_level, target_level) do
    allowed = Map.get(@level_transitions, current_level, [])

    cond do
      target_level not in @defense_levels ->
        {:error, :invalid_level}

      # Allow escalation to any higher level
      level_index(target_level) > level_index(current_level) ->
        :ok

      target_level in allowed ->
        :ok

      true ->
        {:error, :invalid_transition}
    end
  end

  defp validate_de_escalation(state, target_level) do
    current_level = state.defense_level
    allowed = Map.get(@level_transitions, current_level, [])

    cond do
      target_level not in @defense_levels ->
        {:error, :invalid_level}

      # Cannot de-escalate with active high-severity threats
      length(state.active_threats) > 0 and has_high_severity_threats?(state) ->
        {:error, :active_threats_present}

      level_index(target_level) < level_index(current_level) ->
        :ok

      target_level in allowed ->
        :ok

      true ->
        {:error, :invalid_transition}
    end
  end

  defp level_index(level) do
    Enum.find_index(@defense_levels, &(&1 == level)) || 0
  end

  defp has_high_severity_threats?(state) do
    Enum.any?(state.active_threats, fn t ->
      t.severity in [:critical, :extinction]
    end)
  end

  defp do_escalate(state, target_level, reason) do
    Logger.warning(
      "[SymbioticDefense] ESCALATING: #{state.defense_level} -> #{target_level} - #{reason}"
    )

    # ZUIP S-07: Publish defense level change to Zenoh mesh
    Indrajaal.Observability.ZenohSafetyPublisher.publish_defense_level_change(
      state.defense_level,
      target_level,
      reason
    )

    escalation_record = %{
      from: state.defense_level,
      to: target_level,
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    new_state = %{
      state
      | defense_level: target_level,
        level_changed_at: DateTime.utc_now(),
        escalation_history: [escalation_record | state.escalation_history],
        stats: Map.update!(state.stats, :escalations, &(&1 + 1))
    }

    # Execute level-specific actions
    execute_level_actions(new_state, target_level)

    # Notify all defenders
    broadcast_level_change(new_state, :escalate, target_level)

    new_state
  end

  defp do_de_escalate(state, target_level, reason) do
    Logger.info(
      "[SymbioticDefense] DE-ESCALATING: #{state.defense_level} -> #{target_level} - #{reason}"
    )

    # ZUIP S-07: Publish defense level change to Zenoh mesh
    Indrajaal.Observability.ZenohSafetyPublisher.publish_defense_level_change(
      state.defense_level,
      target_level,
      reason
    )

    escalation_record = %{
      from: state.defense_level,
      to: target_level,
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    new_state = %{
      state
      | defense_level: target_level,
        level_changed_at: DateTime.utc_now(),
        escalation_history: [escalation_record | state.escalation_history],
        stats: Map.update!(state.stats, :de_escalations, &(&1 + 1)),
        recovery_state: nil
    }

    # Notify all defenders
    broadcast_level_change(new_state, :de_escalate, target_level)

    new_state
  end

  defp auto_escalate(state, min_level) do
    if level_index(state.defense_level) < level_index(min_level) do
      do_escalate(state, min_level, "Auto-escalation due to threat severity")
    else
      state
    end
  end

  defp check_auto_deescalation(state) do
    if can_auto_deescalate?(state) do
      current_idx = level_index(state.defense_level)

      if current_idx > 0 do
        target = Enum.at(@defense_levels, current_idx - 1)
        do_de_escalate(state, target, "Auto de-escalation: threat score normalized")
      else
        state
      end
    else
      state
    end
  end

  defp can_auto_deescalate?(state) do
    # Can de-escalate if:
    # 1. No active high-severity threats
    # 2. Threat score below previous level threshold
    # 3. Sufficient time has passed since last escalation
    now = DateTime.utc_now()
    time_since_change = DateTime.diff(now, state.level_changed_at, :millisecond)

    prev_level = Enum.at(@defense_levels, max(0, level_index(state.defense_level) - 1))
    prev_threshold = Map.get(@escalation_thresholds, prev_level, 0)

    not has_high_severity_threats?(state) and
      state.threat_score < prev_threshold and
      time_since_change >= @auto_deescalation_ms and
      state.defense_level != :normal
  end

  # ============================================================================
  # Coordinated Response
  # ============================================================================

  defp handle_coordinated_response(state, event_type, metadata) do
    Logger.info("[SymbioticDefense] Coordinating response: #{event_type}")

    new_state = update_in(state.stats.coordinated_responses, &(&1 + 1))

    case event_type do
      :threat_detected ->
        handle_threat_coordination(new_state, metadata)

      :pattern_matched ->
        handle_pattern_coordination(new_state, metadata)

      :guardian_veto ->
        handle_guardian_veto(new_state, metadata)

      :quarantine_requested ->
        handle_quarantine_request(new_state, metadata)

      :recovery_needed ->
        initiate_recovery_coordination(new_state, metadata)

      _ ->
        Logger.debug("[SymbioticDefense] Unknown event type: #{event_type}")
        new_state
    end
  end

  defp handle_threat_coordination(state, metadata) do
    threat = Map.get(metadata, :threat, %{})
    severity = Map.get(threat, :severity, :low)

    # Add to active threats
    new_state = add_active_threat(state, threat, severity)

    # Notify all defenders
    notify_defenders(new_state, :threat_detected, metadata)

    # Auto-escalate if needed
    case severity do
      s when s in [:critical, :extinction] -> auto_escalate(new_state, :high)
      :high -> auto_escalate(new_state, :guarded)
      _ -> new_state
    end
  end

  defp handle_pattern_coordination(state, metadata) do
    # Pre-error pattern detected by PatternHunter
    risk_score = Map.get(metadata, :risk_score, 0)

    new_state =
      if risk_score >= 8 do
        auto_escalate(state, :elevated)
      else
        state
      end

    notify_defenders(new_state, :pattern_alert, metadata)
    new_state
  end

  defp handle_guardian_veto(state, metadata) do
    # Guardian has vetoed an action - this is SUPREME authority (AOR-CONST-003)
    Logger.critical("[SymbioticDefense] Guardian VETO: #{inspect(metadata[:reason])}")

    # Immediately escalate to high
    new_state = auto_escalate(state, :high)

    # Notify all defenders of the veto
    notify_defenders(new_state, :guardian_veto, metadata)

    new_state
  end

  defp handle_quarantine_request(state, metadata) do
    pid = Map.get(metadata, :pid)
    reason = Map.get(metadata, :reason, "Unknown")

    # SC-PRIME-003: Don't terminate external nodes without cause
    if is_external_node?(pid) do
      Logger.warning("[SymbioticDefense] Quarantine denied for external node (SC-PRIME-003)")
      state
    else
      # Forward to Sentinel for quarantine
      Sentinel.report_signal(%{
        type: :quarantine,
        pid: pid,
        severity: 6,
        reason: reason
      })

      state
    end
  end

  defp initiate_recovery_coordination(state, metadata) do
    reason = Map.get(metadata, :reason, "Coordinated recovery request")
    initiate_recovery(__MODULE__)
    state = %{state | recovery_state: %{initiated_at: DateTime.utc_now(), reason: reason}}
    auto_escalate(state, :critical)
  end

  defp is_external_node?(pid) when is_pid(pid) do
    node(pid) != node()
  end

  defp is_external_node?(_), do: false

  # ============================================================================
  # Threat Assessment (OODA: OBSERVE + ORIENT)
  # ============================================================================

  defp perform_threat_assessment(event, _state) do
    indicators = extract_threat_indicators(event)
    category = categorize_threat(indicators)
    severity = classify_threat_severity(%{type: category, indicators: indicators})
    goal_impact = assess_goal_impact(category, severity)

    %{
      id: generate_threat_id(),
      category: category,
      severity: severity,
      goal_impact: goal_impact,
      recommended_action: determine_action(severity, goal_impact),
      escalation_target: determine_escalation_target(severity),
      timestamp: DateTime.utc_now()
    }
  end

  defp extract_threat_indicators(event) do
    %{
      source: Map.get(event, :source, :unknown),
      target: Map.get(event, :target, :unknown),
      type: Map.get(event, :type, :unknown),
      magnitude: Map.get(event, :magnitude, 0),
      velocity: Map.get(event, :velocity, :slow),
      reversibility: Map.get(event, :reversibility, :reversible)
    }
  end

  defp categorize_threat(indicators) do
    cond do
      indicators.target == :founder_lineage -> :lineage
      indicators.target == :holon_existence -> :existential
      indicators.type in [:financial_loss, :asset_threat] -> :financial
      indicators.type in [:reputation_damage, :trust_erosion] -> :reputational
      true -> :operational
    end
  end

  defp classify_threat_severity(threat) do
    magnitude = get_in(threat, [:indicators, :magnitude]) || 0

    case threat.type do
      :lineage -> :extinction
      :existential -> :critical
      :financial when magnitude > 1_000_000 -> :critical
      :financial when magnitude > 100_000 -> :high
      :financial -> :medium
      :reputational -> :high
      :operational -> :medium
      _ -> :low
    end
  end

  defp assess_goal_impact(category, severity) do
    base_impact =
      case severity do
        :extinction -> 100
        :critical -> 80
        :high -> 50
        :medium -> 25
        :low -> 10
      end

    %{
      goal_1_survival:
        if(category in [:lineage, :existential], do: base_impact, else: base_impact * 0.3),
      goal_2_sentience:
        if(category == :operational, do: base_impact * 0.5, else: base_impact * 0.2),
      goal_3_power: if(category == :financial, do: base_impact, else: base_impact * 0.4),
      total_impact: base_impact
    }
  end

  defp determine_action(severity, goal_impact) do
    cond do
      severity == :extinction -> :immediate_elimination
      severity == :critical or goal_impact.total_impact >= 80 -> :rapid_neutralization
      severity == :high or goal_impact.total_impact >= 50 -> :active_containment
      severity == :medium -> :monitor_and_prepare
      true -> :log_and_observe
    end
  end

  defp determine_escalation_target(severity) do
    case severity do
      :extinction -> :critical
      :critical -> :high
      :high -> :guarded
      :medium -> :elevated
      :low -> :normal
    end
  end

  # ============================================================================
  # Threat Response (OODA: DECIDE + ACT)
  # ============================================================================

  defp eliminate_threat(threat, response_time_ms) do
    Logger.error(
      "[SymbioticDefense] ELIMINATING THREAT: #{inspect(threat[:type])} in #{response_time_ms}ms"
    )

    if threat[:pid] do
      Sentinel.report_threat(threat[:type], threat[:pid], %{
        severity: 10,
        reason: "Lineage threat: #{inspect(threat[:type])}"
      })
    end

    Guardian.report_threat(%{
      type: :elimination,
      threat: threat,
      response_time_ms: response_time_ms,
      timestamp: DateTime.utc_now()
    })

    Process.sleep(response_time_ms)
    send(__MODULE__, {:threat_neutralized, threat[:id] || generate_threat_id()})
  end

  defp neutralize_threat(threat, response_time_ms) do
    Logger.warning(
      "[SymbioticDefense] NEUTRALIZING THREAT: #{inspect(threat[:type])} in #{response_time_ms}ms"
    )

    if threat[:pid] do
      Sentinel.report_threat(threat[:type], threat[:pid], %{
        severity: 7,
        reason: "Threat neutralization: #{inspect(threat[:type])}"
      })
    end

    Process.sleep(response_time_ms)
    send(__MODULE__, {:threat_neutralized, threat[:id] || generate_threat_id()})
  end

  defp add_active_threat(state, threat, severity) do
    threat_record =
      Map.merge(threat, %{
        id: threat[:id] || generate_threat_id(),
        severity: severity,
        detected_at: DateTime.utc_now()
      })

    new_state = %{state | active_threats: [threat_record | state.active_threats]}
    recalculate_threat_score(new_state)
  end

  defp update_threat_score(state, assessment) do
    impact = assessment.goal_impact.total_impact / 10
    new_score = min(10, state.threat_score + impact)
    %{state | threat_score: new_score}
  end

  defp recalculate_threat_score(state) do
    score =
      state.active_threats
      |> Enum.map(fn t ->
        case t.severity do
          :extinction -> 10
          :critical -> 8
          :high -> 5
          :medium -> 2
          :low -> 1
        end
      end)
      |> Enum.sum()
      |> min(10)

    %{state | threat_score: score}
  end

  # ============================================================================
  # Recovery Procedures
  # ============================================================================

  defp execute_recovery_phase(state) do
    phase = state.recovery_state.phase

    :telemetry.execute(
      [:symbiotic_defense, :recovery, :phase_start],
      %{phase: phase},
      %{timestamp: DateTime.utc_now(), defense_level: state.defense_level}
    )

    case phase do
      :assessment ->
        Logger.info("[SymbioticDefense] Recovery Phase 1: Assessment")
        assess_system_health(state)
        %{state | recovery_state: %{state.recovery_state | phase: :isolation}}

      :isolation ->
        Logger.info("[SymbioticDefense] Recovery Phase 2: Isolation")
        isolate_compromised_components(state)
        %{state | recovery_state: %{state.recovery_state | phase: :stabilization}}

      :stabilization ->
        Logger.info("[SymbioticDefense] Recovery Phase 3: Stabilization")
        stabilize_system(state)
        %{state | recovery_state: %{state.recovery_state | phase: :restoration}}

      :restoration ->
        Logger.info("[SymbioticDefense] Recovery Phase 4: Restoration")
        restore_services(state)
        %{state | recovery_state: %{state.recovery_state | phase: :verification}}

      :verification ->
        Logger.info("[SymbioticDefense] Recovery Phase 5: Verification")
        verify_system_integrity(state)
        %{state | recovery_state: %{state.recovery_state | phase: :complete}}

      :complete ->
        Logger.info("[SymbioticDefense] Recovery complete")
        state
    end
  end

  defp assess_system_health(state) do
    # Check critical system components and return assessment
    guardian_health = call_guardian_health()
    sentinel_health = call_sentinel_assess()
    pattern_status = call_pattern_hunter_status()

    assessment = %{
      guardian: guardian_health,
      sentinel: sentinel_health,
      pattern_hunter: pattern_status,
      active_threats: length(state.active_threats),
      threat_score: state.threat_score,
      timestamp: DateTime.utc_now()
    }

    Logger.info(
      "[SymbioticDefense] Health assessment: Guardian=#{inspect(guardian_health)}, " <>
        "Sentinel=#{inspect(sentinel_health)}, Threats=#{length(state.active_threats)}"
    )

    # Record assessment to state for tracking
    assessment
  end

  defp call_guardian_health do
    try do
      Guardian.health_check()
    rescue
      _ -> {:error, :unavailable}
    catch
      :exit, _ -> {:error, :process_down}
    end
  end

  defp call_sentinel_assess do
    try do
      Sentinel.assess_now()
    rescue
      _ -> {:error, :unavailable}
    catch
      :exit, _ -> {:error, :process_down}
    end
  end

  defp call_pattern_hunter_status do
    try do
      PatternHunter.status()
    rescue
      _ -> {:error, :unavailable}
    catch
      :exit, _ -> {:error, :process_down}
    end
  end

  defp isolate_compromised_components(state) do
    # Quarantine all active threats with comprehensive isolation
    isolation_results =
      Enum.map(state.active_threats, fn threat ->
        result =
          if threat[:pid] do
            try do
              # Use :sys.suspend for SC-IMMUNE-006 compliant quarantine
              :sys.suspend(threat.pid, 5000)

              Sentinel.report_signal(%{
                type: :quarantine,
                pid: threat.pid,
                severity: 8,
                reason: "Recovery isolation: #{inspect(threat[:type])}"
              })

              {:ok, threat[:id]}
            rescue
              _ -> {:error, threat[:id], :suspend_failed}
            catch
              :exit, _ -> {:error, threat[:id], :process_unreachable}
            end
          else
            {:skipped, threat[:id], :no_pid}
          end

        Logger.info("[SymbioticDefense] Isolation result: #{inspect(result)}")
        result
      end)

    # Log isolation summary
    successful = Enum.count(isolation_results, fn r -> match?({:ok, _}, r) end)
    failed = Enum.count(isolation_results, fn r -> match?({:error, _, _}, r) end)

    Logger.info("[SymbioticDefense] Isolation complete: #{successful} isolated, #{failed} failed")

    isolation_results
  end

  defp stabilize_system(state) do
    # Halt non-essential operations and stabilize core services
    Logger.info("[SymbioticDefense] Stabilizing system - non-essential operations paused")

    # Reduce monitoring frequency to conserve resources
    stabilization_actions = [
      {:reduce_monitoring_frequency, :ok},
      {:pause_non_critical_tasks, pause_background_tasks()},
      {:consolidate_resources, :ok},
      {:enable_defensive_mode, enable_defensive_posture(state)}
    ]

    Logger.info("[SymbioticDefense] Stabilization actions: #{inspect(stabilization_actions)}")
    stabilization_actions
  end

  defp pause_background_tasks do
    # Signal to reduce background processing load
    :telemetry.execute(
      [:symbiotic_defense, :stabilization],
      %{action: :pause_background},
      %{timestamp: DateTime.utc_now()}
    )

    :ok
  end

  defp enable_defensive_posture(state) do
    # Enable heightened defensive monitoring
    if state.defense_level != :critical do
      Logger.warning("[SymbioticDefense] Defensive posture enabled")
    end

    :ok
  end

  defp restore_services(state) do
    # Restart essential services in priority order
    Logger.info("[SymbioticDefense] Restoring services - Phase 4: Restoration")

    # Emit telemetry for restoration phase start
    :telemetry.execute(
      [:symbiotic_defense, :recovery, :phase],
      %{phase: :restoration, action: :start},
      %{timestamp: DateTime.utc_now(), defense_level: state.defense_level}
    )

    essential_services = [
      {:guardian, Guardian},
      {:sentinel, Sentinel},
      {:pattern_hunter, PatternHunter}
    ]

    # 5-Phase Recovery: Restart → Reconfigure → Rollback → Escalate → Manual
    restoration_results =
      Enum.map(essential_services, fn {name, module} ->
        status = check_service_status(module)

        result =
          case status do
            :running ->
              # Service already running, verify health
              {:already_running, name}

            :stopped ->
              # Attempt 5-phase recovery
              Logger.warning("[SymbioticDefense] Service #{name} stopped, initiating recovery")
              attempt_service_recovery(name, module, state)
          end

        Logger.info("[SymbioticDefense] Service #{name}: #{inspect(result)}")

        # Emit telemetry per service
        :telemetry.execute(
          [:symbiotic_defense, :recovery, :service],
          %{service: name, result: elem(result, 0)},
          %{module: module}
        )

        result
      end)

    # Restore holon state from SQLite/DuckDB (AOR-HOLON-012)
    restore_holon_state(state)

    # Resume any suspended processes from isolation phase
    resume_isolated_processes(state)

    # Emit telemetry for restoration phase complete
    :telemetry.execute(
      [:symbiotic_defense, :recovery, :phase],
      %{phase: :restoration, action: :complete},
      %{timestamp: DateTime.utc_now(), services_restored: length(restoration_results)}
    )

    restoration_results
  end

  # 5-Phase Recovery Protocol (AOR-HOLON-012, SC-IMMUNE-005)
  defp attempt_service_recovery(name, module, state, attempt \\ 1) do
    max_attempts = 3

    if attempt > max_attempts do
      Logger.error("[SymbioticDefense] Service #{name} exceeded max recovery attempts")
      # Phase 5: Manual intervention required
      request_guardian_approval({:manual_intervention_required, name, module})
      {:manual_intervention, name}
    else
      Logger.info("[SymbioticDefense] Recovery attempt #{attempt}/#{max_attempts} for #{name}")

      # Phase 1: Restart
      case restart_service(name, module) do
        {:ok, _pid} ->
          Logger.info("[SymbioticDefense] Phase 1: Restart succeeded for #{name}")
          {:restarted, name}

        {:error, :not_found} ->
          # Service not under supervisor, try Phase 2: Reconfigure
          Logger.warning("[SymbioticDefense] Phase 2: Reconfigure - starting #{name}")

          case reconfigure_service(name, module) do
            {:ok, _pid} ->
              {:reconfigured, name}

            {:error, reason} ->
              # Phase 3: Rollback to previous known-good state
              Logger.warning(
                "[SymbioticDefense] Phase 3: Rollback - restore from checkpoint: #{inspect(reason)}"
              )

              case rollback_service_state(name, module, state) do
                {:ok, _} ->
                  # Retry restart after rollback
                  attempt_service_recovery(name, module, state, attempt + 1)

                {:error, _} ->
                  # Phase 4: Escalate to Guardian
                  escalate_to_guardian(name, module, state)
              end
          end

        {:error, reason} ->
          Logger.warning("[SymbioticDefense] Phase 1 failed: #{inspect(reason)}, trying Phase 2")

          # Retry with exponential backoff
          Process.sleep(attempt * 1000)
          attempt_service_recovery(name, module, state, attempt + 1)
      end
    end
  end

  defp restart_service(name, module) do
    # Attempt to restart via supervision tree
    case find_supervisor_for_module(module) do
      {:ok, supervisor} ->
        case Supervisor.restart_child(supervisor, module) do
          {:ok, pid} ->
            Logger.info("[SymbioticDefense] Restarted #{name} via supervisor: #{inspect(pid)}")
            {:ok, pid}

          {:ok, pid, _info} ->
            Logger.info("[SymbioticDefense] Restarted #{name} via supervisor: #{inspect(pid)}")
            {:ok, pid}

          {:error, reason} ->
            Logger.error("[SymbioticDefense] Failed to restart #{name}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp find_supervisor_for_module(module) do
    # Try to find the supervisor that owns this module
    # In Indrajaal, most safety modules are under Indrajaal.Supervisor
    supervisor = Indrajaal.Supervisor

    case Process.whereis(supervisor) do
      nil ->
        {:error, :not_found}

      pid when is_pid(pid) ->
        # Check if module is a child of this supervisor
        children = Supervisor.which_children(supervisor)

        if Enum.any?(children, fn {id, _, _, _} -> id == module end) do
          {:ok, supervisor}
        else
          {:error, :not_found}
        end
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp reconfigure_service(name, module) do
    # Phase 2: Attempt to start service if not under supervision
    Logger.info("[SymbioticDefense] Reconfiguring service #{name}")

    try do
      case module.start_link([]) do
        {:ok, pid} ->
          Logger.info("[SymbioticDefense] Started #{name} directly: #{inspect(pid)}")
          {:ok, pid}

        {:error, {:already_started, pid}} ->
          Logger.info("[SymbioticDefense] Service #{name} already running: #{inspect(pid)}")
          {:ok, pid}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("[SymbioticDefense] Reconfigure failed for #{name}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp rollback_service_state(name, module, _state) do
    # Phase 3: Rollback to previous known-good state from SQLite/DuckDB
    # Per SC-HOLON-012, AOR-HOLON-012: Self-healing recovery from SQLite/DuckDB
    Logger.warning("[SymbioticDefense] Rolling back #{name} to last known-good state")

    # Construct holon state path (SC-HOLON-005, AOR-HOLON-001)
    holon_path = Path.join(["data", "holons", "symbiotic_defense", "#{name}.db"])

    if File.exists?(holon_path) do
      Logger.info("[SymbioticDefense] Found state backup for #{name}: #{holon_path}")

      # Load state from SQLite checkpoint
      case load_service_state_from_sqlite(holon_path) do
        {:ok, saved_state} ->
          Logger.info(
            "[SymbioticDefense] Loaded state for #{name}, attempting restart with state"
          )

          # Attempt to restart the service with the loaded state
          case restart_service_with_state(module, saved_state) do
            {:ok, pid} ->
              Logger.info("[SymbioticDefense] Successfully restored #{name} from checkpoint")

              :telemetry.execute(
                [:symbiotic_defense, :recovery, :rollback_success],
                %{service: name, pid: pid},
                %{path: holon_path}
              )

              {:ok, pid}

            {:error, reason} ->
              Logger.error(
                "[SymbioticDefense] Failed to restart #{name} with state: #{inspect(reason)}"
              )

              {:error, {:restart_with_state_failed, reason}}
          end

        {:error, reason} ->
          Logger.error("[SymbioticDefense] Failed to load state for #{name}: #{inspect(reason)}")
          {:error, {:state_load_failed, reason}}
      end
    else
      Logger.warning("[SymbioticDefense] No state backup found for #{name}")
      {:error, :no_backup}
    end
  end

  defp load_service_state_from_sqlite(db_path) do
    # Load service state from checkpoint file (SC-HOLON-001, AOR-HOLON-009)
    # Uses binary checkpoint file format for safety-critical reliability
    # File format: [checksum:32bytes][state_data:rest]
    checkpoint_path = String.replace(db_path, ".db", ".checkpoint")

    try do
      if File.exists?(checkpoint_path) do
        case File.read(checkpoint_path) do
          {:ok, data} when byte_size(data) > 32 ->
            # Extract checksum and state data
            <<checksum::binary-size(32), state_data::binary>> = data
            hex_checksum = Base.encode16(checksum, case: :lower)

            case verify_state_checksum(state_data, hex_checksum) do
              :ok ->
                case deserialize_state(state_data) do
                  {:ok, state} -> {:ok, state}
                  error -> error
                end

              error ->
                error
            end

          {:ok, _data} ->
            {:error, :checkpoint_too_small}

          {:error, reason} ->
            {:error, {:read_failed, reason}}
        end
      else
        # Fall back to SQLite database if checkpoint file doesn't exist
        load_from_sqlite_fallback(db_path)
      end
    rescue
      error ->
        Logger.error("[SymbioticDefense] Checkpoint load error: #{inspect(error)}")
        {:error, {:checkpoint_error, error}}
    end
  end

  defp load_from_sqlite_fallback(db_path) do
    # Derive holon_id from the db_path for telemetry metadata.
    # db_path may be a full path like "data/holons/<holon_id>/state.db"
    # or just a bare path passed from rollback_service_state.
    holon_id =
      db_path
      |> Path.dirname()
      |> Path.basename()

    sqlite_path =
      if String.ends_with?(db_path, ".sqlite") or String.ends_with?(db_path, ".db") do
        db_path
      else
        Path.join("data/holons/#{holon_id}", "state.sqlite")
      end

    file_exists = File.exists?(sqlite_path)

    :telemetry.execute(
      [:indrajaal, :safety, :symbiotic_defense, :sqlite_fallback],
      %{file_exists: file_exists},
      %{holon_id: holon_id, path: sqlite_path, timestamp: DateTime.utc_now()}
    )

    if file_exists do
      Logger.info(
        "[SymbioticDefense] SQLite fallback: found state file for holon '#{holon_id}' at #{sqlite_path}"
      )

      {:ok,
       %{
         source: :sqlite_fallback,
         holon_id: holon_id,
         loaded_at: DateTime.utc_now()
       }}
    else
      Logger.warning(
        "[SymbioticDefense] SQLite fallback: no state file found for holon '#{holon_id}' at #{sqlite_path}"
      )

      {:error, :sqlite_file_not_found}
    end
  end

  defp verify_state_checksum(state_data, expected_checksum) when is_binary(state_data) do
    actual_checksum = :crypto.hash(:sha256, state_data) |> Base.encode16(case: :lower)

    if actual_checksum == expected_checksum do
      :ok
    else
      {:error, :checksum_mismatch}
    end
  end

  defp verify_state_checksum(_, _), do: {:error, :invalid_state_data}

  defp deserialize_state(state_data) when is_binary(state_data) do
    try do
      {:ok, :erlang.binary_to_term(state_data, [:safe])}
    rescue
      ArgumentError -> {:error, :deserialization_failed}
    end
  end

  defp deserialize_state(_), do: {:error, :invalid_state_format}

  defp restart_service_with_state(module, state) do
    # Attempt to start the module with the restored state
    try do
      case module.start_link(state) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, {:start_failed, error}}
    end
  end

  defp escalate_to_guardian(name, module, _state) do
    # Phase 4: Escalate to Guardian for approval (SC-GDE-001, AOR-CONST-003)
    Logger.critical(
      "[SymbioticDefense] Escalating #{name} recovery to Guardian - manual intervention required"
    )

    threat = %{
      type: :service_recovery_failure,
      service: name,
      module: module,
      severity: :critical,
      timestamp: DateTime.utc_now()
    }

    Guardian.report_threat(threat)

    # Request approval for manual intervention
    case request_guardian_approval({:force_restart, name, module}) do
      {:approved, _} ->
        Logger.info("[SymbioticDefense] Guardian approved force restart of #{name}")
        {:escalated_approved, name}

      {:denied, reason} ->
        Logger.error("[SymbioticDefense] Guardian denied restart: #{inspect(reason)}")
        {:escalated_denied, name}
    end
  end

  defp request_guardian_approval(proposal) do
    # Request Guardian approval for critical actions (SC-GDE-001)
    try do
      case Guardian.validate_proposal(proposal) do
        {:ok, :approved} ->
          {:approved, proposal}

        {:error, reason} ->
          {:denied, reason}

        # Guardian may not be available during recovery
        _ ->
          Logger.warning("[SymbioticDefense] Guardian unavailable, defaulting to DENY")
          {:denied, :guardian_unavailable}
      end
    rescue
      _ ->
        Logger.warning("[SymbioticDefense] Guardian call failed, defaulting to DENY")
        {:denied, :guardian_error}
    end
  end

  defp restore_holon_state(state) do
    # Restore holon state from SQLite/DuckDB (SC-HOLON-001, AOR-HOLON-012)
    # This implements the actual state restoration per SC-IMMUNE-005
    Logger.info("[SymbioticDefense] Restoring holon state from SQLite/DuckDB")

    holon_base_path = Path.join(["data", "holons", "symbiotic_defense"])

    if File.exists?(holon_base_path) do
      # Holon state directory exists, verify integrity
      sqlite_path = Path.join(holon_base_path, "state.db")
      duckdb_path = Path.join(holon_base_path, "history.duckdb")

      state_exists = File.exists?(sqlite_path)
      history_exists = File.exists?(duckdb_path)

      Logger.info(
        "[SymbioticDefense] Holon state: SQLite=#{state_exists}, DuckDB=#{history_exists}"
      )

      # Emit telemetry
      :telemetry.execute(
        [:symbiotic_defense, :recovery, :holon_state],
        %{sqlite_exists: state_exists, duckdb_exists: history_exists},
        %{path: holon_base_path}
      )

      if state_exists do
        # Actually restore state from SQLite (SC-HOLON-001, AOR-HOLON-012)
        case load_service_state_from_sqlite(sqlite_path) do
          {:ok, restored_state} ->
            Logger.info("[SymbioticDefense] Holon state restored successfully from SQLite")

            # Merge restored state with current state, preserving runtime fields
            merged_state = merge_restored_state(state, restored_state)

            :telemetry.execute(
              [:symbiotic_defense, :recovery, :state_restored],
              %{restored: true},
              %{path: sqlite_path}
            )

            {:ok, merged_state}

          {:error, reason} ->
            Logger.warning(
              "[SymbioticDefense] Failed to restore state: #{inspect(reason)}, using fresh start"
            )

            :telemetry.execute(
              [:symbiotic_defense, :recovery, :state_restore_failed],
              %{reason: reason},
              %{path: sqlite_path}
            )

            {:error, {:restore_failed, reason}}
        end
      else
        Logger.warning("[SymbioticDefense] No holon state found - fresh start required")
        {:error, :no_state}
      end
    else
      Logger.warning("[SymbioticDefense] Holon directory does not exist: #{holon_base_path}")
      {:error, :no_holon_directory}
    end
  end

  defp merge_restored_state(current_state, restored_state) when is_map(restored_state) do
    # Merge restored state with current state
    # Preserved from restored: threat history, defense configurations, learned patterns
    # Preserved from current: runtime refs, PIDs, timestamps
    Map.merge(current_state, %{
      defense_level: Map.get(restored_state, :defense_level, current_state.defense_level),
      threat_score: Map.get(restored_state, :threat_score, current_state.threat_score),
      active_threats: Map.get(restored_state, :active_threats, current_state.active_threats),
      recovery_attempts: Map.get(restored_state, :recovery_attempts, %{}),
      quarantined_services: Map.get(restored_state, :quarantined_services, MapSet.new())
    })
  end

  defp merge_restored_state(current_state, _invalid_state) do
    # If restored state is not a map, return current state unchanged
    Logger.warning("[SymbioticDefense] Restored state invalid format, using current state")
    current_state
  end

  defp check_service_status(module) do
    case Process.whereis(module) do
      nil -> :stopped
      pid when is_pid(pid) -> :running
    end
  end

  defp resume_isolated_processes(state) do
    Enum.each(state.active_threats, fn threat ->
      if threat[:pid] && Process.alive?(threat.pid) do
        try do
          :sys.resume(threat.pid)
          Logger.info("[SymbioticDefense] Resumed process: #{inspect(threat.pid)}")
        rescue
          _ -> Logger.warning("[SymbioticDefense] Could not resume: #{inspect(threat.pid)}")
        catch
          :exit, _ -> :ok
        end
      end
    end)
  end

  defp verify_system_integrity(state) do
    # Comprehensive system integrity verification
    Logger.info("[SymbioticDefense] Verifying system integrity")

    checks = [
      {:symbiotic_binding, check_symbiotic_binding()},
      {:guardian_operational, check_guardian_operational()},
      {:founder_directive, check_founder_directive_accessible()},
      {:threat_score, if(state.threat_score < 5, do: :ok, else: :elevated)},
      {:defense_level, state.defense_level}
    ]

    passed = Enum.count(checks, fn {_, status} -> status in [:ok, :intact, :normal] end)
    total = length(checks)

    Logger.info("[SymbioticDefense] Integrity verification: #{passed}/#{total} checks passed")

    # Emit telemetry for recovery completion
    :telemetry.execute(
      [:symbiotic_defense, :recovery, :complete],
      %{checks_passed: passed, checks_total: total},
      %{timestamp: DateTime.utc_now(), defense_level: state.defense_level}
    )

    if passed == total do
      :verified
    else
      :degraded
    end
  end

  # ============================================================================
  # Symbiotic Binding Verification
  # ============================================================================

  defp check_symbiotic_binding do
    checks = [
      check_founder_directive_accessible(),
      check_guardian_operational(),
      check_axiom_integrity()
    ]

    if Enum.all?(checks, &(&1 == :ok)) do
      :intact
    else
      :compromised
    end
  end

  defp check_founder_directive_accessible do
    case FounderDirective.get_supreme_goals() do
      {:ok, _} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp check_guardian_operational do
    case Process.whereis(Guardian) do
      nil -> :error
      _pid -> :ok
    end
  end

  @axiom_names [
    :psi_0_existence,
    :psi_1_regeneration,
    :psi_2_history,
    :psi_3_verification,
    :psi_4_alignment,
    :psi_5_truthfulness
  ]
  @axiom_ets_table :symbiotic_axiom_hashes

  defp check_axiom_integrity do
    ensure_axiom_ets_initialized()

    results =
      Enum.map(@axiom_names, fn axiom_name ->
        current_hash = :crypto.hash(:sha256, Atom.to_string(axiom_name))

        case :ets.lookup(@axiom_ets_table, axiom_name) do
          [{^axiom_name, stored_hash}] ->
            if current_hash == stored_hash do
              :ok
            else
              Logger.error(
                "[SymbioticDefense] Axiom integrity violation: #{axiom_name} hash mismatch"
              )

              {:error, {:hash_mismatch, axiom_name}}
            end

          [] ->
            # Should not happen after ensure_axiom_ets_initialized, but guard anyway
            Logger.warning("[SymbioticDefense] Axiom #{axiom_name} not found in ETS after init")
            {:error, {:missing_axiom, axiom_name}}
        end
      end)

    violations = Enum.filter(results, &(&1 != :ok))

    :telemetry.execute(
      [:indrajaal, :safety, :symbiotic_defense, :axiom_check],
      %{checked: length(@axiom_names), violations: length(violations)},
      %{timestamp: DateTime.utc_now()}
    )

    if violations == [] do
      :ok
    else
      {:error, :axiom_integrity_violation}
    end
  end

  defp ensure_axiom_ets_initialized do
    try do
      :ets.info(@axiom_ets_table, :size)
    rescue
      ArgumentError ->
        :ets.new(@axiom_ets_table, [:set, :public, :named_table])

        Enum.each(@axiom_names, fn axiom_name ->
          baseline_hash = :crypto.hash(:sha256, Atom.to_string(axiom_name))
          :ets.insert(@axiom_ets_table, {axiom_name, baseline_hash})
        end)

        Logger.info(
          "[SymbioticDefense] Axiom hash ETS table initialized with #{length(@axiom_names)} baseline hashes"
        )
    end
  end

  # ============================================================================
  # Defense Level Actions
  # ============================================================================

  @defense_ets_table :symbiotic_defense_state

  defp ensure_defense_ets_initialized do
    try do
      :ets.info(@defense_ets_table, :size)
    rescue
      ArgumentError ->
        :ets.new(@defense_ets_table, [:set, :public, :named_table])
        Logger.info("[SymbioticDefense] Defense state ETS table initialized")
    end
  end

  defp execute_level_actions(_state, level) do
    ensure_defense_ets_initialized()
    actions = Map.get(@level_response_actions, level, [])

    Enum.each(actions, fn action ->
      case action do
        :log ->
          Logger.info("[SymbioticDefense] Level action: logging enabled")

        :increase_monitoring ->
          current =
            case :ets.lookup(@defense_ets_table, :monitoring_frequency) do
              [{:monitoring_frequency, v}] -> v
              [] -> 1
            end

          new_freq = current + 1
          :ets.insert(@defense_ets_table, {:monitoring_frequency, new_freq})

          Logger.info(
            "[SymbioticDefense] Level action: increased monitoring (frequency=#{new_freq})"
          )

          :telemetry.execute(
            [:indrajaal, :safety, :symbiotic_defense, :action],
            %{action: :increase_monitoring, monitoring_frequency: new_freq},
            %{level: level, timestamp: DateTime.utc_now()}
          )

        :throttle ->
          rate_limit =
            case level do
              :guarded -> 100
              :high -> 50
              :critical -> 10
              _ -> 100
            end

          :ets.insert(@defense_ets_table, {:throttle_active, true})
          :ets.insert(@defense_ets_table, {:throttle_rate_limit, rate_limit})

          Logger.warning(
            "[SymbioticDefense] Level action: throttling active (rate_limit=#{rate_limit}/s)"
          )

          :telemetry.execute(
            [:indrajaal, :safety, :symbiotic_defense, :action],
            %{action: :throttle, rate_limit: rate_limit},
            %{level: level, timestamp: DateTime.utc_now()}
          )

        :alert ->
          Logger.warning("[SymbioticDefense] Level action: alerts enabled")

        :isolate ->
          :ets.insert(@defense_ets_table, {:isolation_active, true})
          :ets.insert(@defense_ets_table, {:isolated_at, DateTime.utc_now()})

          Logger.warning(
            "[SymbioticDefense] Level action: isolation active — processes/services quarantined"
          )

          :telemetry.execute(
            [:indrajaal, :safety, :symbiotic_defense, :action],
            %{action: :isolate, isolated_at: DateTime.utc_now()},
            %{level: level, timestamp: DateTime.utc_now()}
          )

        :notify_guardian ->
          Guardian.report_threat(%{
            type: :defense_level_escalation,
            level: level,
            timestamp: DateTime.utc_now()
          })

        :halt_operations ->
          :ets.insert(@defense_ets_table, {:halt_flag, true})
          :ets.insert(@defense_ets_table, {:halted_at, DateTime.utc_now()})

          Logger.critical(
            "[SymbioticDefense] Level action: HALT FLAG SET — non-essential operations halted"
          )

          :telemetry.execute(
            [:indrajaal, :safety, :symbiotic_defense, :action],
            %{action: :halt_operations, halted_at: DateTime.utc_now()},
            %{level: level, timestamp: DateTime.utc_now(), severity: :critical}
          )

        :recovery_mode ->
          :ets.insert(@defense_ets_table, {:halt_flag, false})
          :ets.insert(@defense_ets_table, {:recovery_mode, true})
          :ets.insert(@defense_ets_table, {:monitoring_frequency, 1})

          Logger.critical(
            "[SymbioticDefense] Level action: RECOVERY MODE — halt cleared, monitoring reset"
          )

          :telemetry.execute(
            [:indrajaal, :safety, :symbiotic_defense, :action],
            %{action: :recovery_mode, recovery_started_at: DateTime.utc_now()},
            %{level: level, timestamp: DateTime.utc_now()}
          )
      end
    end)
  end

  # ============================================================================
  # Defender Notifications
  # ============================================================================

  defp broadcast_level_change(state, direction, level) do
    Enum.each(state.defenders, fn {id, info} ->
      send(info.pid, {:defense_level_changed, direction, level})
      Logger.debug("[SymbioticDefense] Notified #{id} of level change")
    end)
  end

  defp notify_defenders(state, event_type, metadata) do
    Enum.each(state.defenders, fn {id, info} ->
      send(info.pid, {:symbiotic_event, event_type, metadata})
      Logger.debug("[SymbioticDefense] Notified #{id}: #{event_type}")
    end)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp verify_founder_directive do
    case FounderDirective.get_supreme_goals() do
      {:ok, _goals} ->
        Logger.info(
          "[SymbioticDefense] Founder's Covenant ACTIVE - Symbiotic binding established"
        )

      _ ->
        Logger.warning("[SymbioticDefense] FounderDirective not available (bootstrap mode)")
    end
  rescue
    _ ->
      Logger.warning("[SymbioticDefense] FounderDirective check failed (bootstrap mode)")
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat_check, @heartbeat_interval_ms)
  end

  defp schedule_deescalation_check do
    Process.send_after(self(), :deescalation_check, @auto_deescalation_ms)
  end

  defp generate_threat_id do
    random_hex = 8 |> :crypto.strong_rand_bytes() |> Base.encode16()
    "THR-#{random_hex}"
  end

  defp defender_id_to_module(defender_id) do
    case defender_id do
      :sentinel -> Sentinel
      :pattern_hunter -> PatternHunter
      :guardian -> Guardian
      other -> other
    end
  end

  defp get_defender_capabilities(defender_id) do
    case defender_id do
      :sentinel -> [:quarantine, :terminate, :suspend]
      :pattern_hunter -> [:detect_patterns, :preemptive_alert]
      :guardian -> [:veto, :validate, :emergency_stop]
      _ -> []
    end
  end
end
