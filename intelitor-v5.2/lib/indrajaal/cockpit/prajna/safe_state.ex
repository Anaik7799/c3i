defmodule Indrajaal.Cockpit.Prajna.SafeState do
  @moduledoc """
  Formal State Machine for Prajna System Health States.

  WHAT: A deterministic state machine that manages Prajna's operational states
  with hysteresis to prevent oscillation.

  WHY: SC-OODA-005 requires hysteresis (10% margin, 3-cycle hold) to prevent
  decision oscillation. This module provides a formal state machine with
  Guardian-approved transitions.

  ## State Definitions

  | State      | Health Range | Description                           |
  |------------|--------------|---------------------------------------|
  | :normal    | >= 80%       | Full operation, all systems nominal   |
  | :degraded  | 50-80%       | Reduced operation, non-critical down  |
  | :safe      | 20-50%       | Minimal operation, critical only      |
  | :emergency | < 20%        | Emergency stop, immediate action      |

  ## Transition Rules

  Forward (degradation) transitions are immediate when threshold crossed.
  Reverse (recovery) transitions require 3 consecutive healthy cycles (hysteresis).

  ```
  :normal ─(health < 80%)──> :degraded ─(health < 50%)──> :safe ─(health < 20%)──> :emergency
     ^                           ^                           ^
     |                           |                           |
     +───(3 healthy cycles)──────+───(3 healthy cycles)──────+
  ```

  ## STAMP Constraints
  - SC-BIO-001: OODA cycle < 100ms
  - SC-BIO-002: Quality gate > 80%
  - SC-OODA-005: Hysteresis (10% margin, 3-cycle hold)
  - SC-PRAJNA-001: Guardian approval for state changes

  ## AOR Rules
  - AOR-BIO-006: Graceful degradation before hitting redlines

  ## Document Control

  | Field   | Value                        |
  |---------|------------------------------|
  | Version | 1.0.0                        |
  | Created | 2026-01-02                   |
  | Author  | Cybernetic Architect         |
  | STAMP   | SC-BIO-001, SC-OODA-005      |
  | Sprint  | 31                           |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.GuardianIntegration
  alias Indrajaal.Cockpit.Prajna.ImmutableState

  # ============================================================================
  # Constants (SC-OODA-005 compliant)
  # ============================================================================

  # Health thresholds (with 10% hysteresis margin)
  @normal_threshold 80
  @degraded_threshold 50
  @safe_threshold 20

  # Hysteresis recovery thresholds (threshold + 10% margin)
  @normal_recovery_threshold 90
  @degraded_recovery_threshold 60
  @safe_recovery_threshold 30

  # Cycles required for recovery (SC-OODA-005: 3-cycle hold)
  @hysteresis_cycles 3

  # Threat severity escalation
  @critical_threat_severity :critical
  @extinction_threat_severity :extinction

  # ============================================================================
  # Types
  # ============================================================================

  @type state :: :normal | :degraded | :safe | :emergency
  @type health_percent :: 0..100
  @type threat_level :: :none | :low | :medium | :high | :critical | :extinction

  @type transition_result ::
          {:ok, state()}
          | {:held, state(), non_neg_integer()}
          | {:error, :guardian_veto, String.t()}

  defstruct current_state: :normal,
            previous_state: nil,
            health_percent: 100,
            threat_level: :none,
            recovery_cycles: 0,
            last_transition: nil,
            transition_count: 0,
            created_at: nil

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the SafeState GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Evaluates the current health and threat level, potentially triggering a state transition.

  Returns:
    - {:ok, new_state} if transition occurred
    - {:held, current_state, remaining_cycles} if in hysteresis hold
    - {:error, :guardian_veto, reason} if Guardian blocked transition
  """
  @spec evaluate(health_percent(), threat_level()) :: transition_result()
  def evaluate(health_percent, threat_level \\ :none) do
    GenServer.call(__MODULE__, {:evaluate, health_percent, threat_level}, 5_000)
  catch
    :exit, {:noproc, _} ->
      # Fallback for direct evaluation without GenServer
      evaluate_direct(health_percent, threat_level)
  end

  @doc """
  Gets the current state.
  """
  @spec current_state() :: state()
  def current_state do
    GenServer.call(__MODULE__, :current_state, 5_000)
  catch
    :exit, {:noproc, _} -> :normal
  end

  @doc """
  Gets the full state machine status including metrics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status, 5_000)
  catch
    :exit, {:noproc, _} ->
      %{
        current_state: :normal,
        health_percent: 100,
        threat_level: :none,
        recovery_cycles: 0,
        transition_count: 0,
        status: :unknown
      }
  end

  @doc """
  Forces an immediate transition to a specific state.
  Requires Guardian approval.
  Use only for emergency scenarios.
  """
  @spec force_transition(state()) :: transition_result()
  def force_transition(target_state) do
    GenServer.call(__MODULE__, {:force_transition, target_state}, 10_000)
  catch
    :exit, {:noproc, _} -> {:error, :not_running, "SafeState GenServer not running"}
  end

  @doc """
  Resets the state machine to :normal state.
  Requires Guardian approval.
  """
  @spec reset() :: :ok | {:error, :guardian_veto, String.t()}
  def reset do
    GenServer.call(__MODULE__, :reset, 10_000)
  catch
    :exit, {:noproc, _} -> :ok
  end

  @doc """
  Checks if system is in a safe operational state (not emergency).
  """
  @spec safe_to_operate?() :: boolean()
  def safe_to_operate? do
    current_state() != :emergency
  end

  @doc """
  Returns allowed actions for the current state.
  """
  @spec allowed_actions() :: list(atom())
  def allowed_actions do
    case current_state() do
      :normal -> [:all]
      :degraded -> [:critical, :essential, :monitoring]
      :safe -> [:critical, :monitoring]
      :emergency -> [:emergency_stop, :monitoring]
    end
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(_opts) do
    Logger.info("[SafeState] Initializing state machine (SC-OODA-005 hysteresis enabled)")
    now = DateTime.utc_now()

    state = %__MODULE__{
      current_state: :normal,
      previous_state: nil,
      health_percent: 100,
      threat_level: :none,
      recovery_cycles: 0,
      last_transition: now,
      transition_count: 0,
      created_at: now
    }

    emit_initialized(state)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:evaluate, health_percent, threat_level}, _from, state) do
    {result, new_state} = do_evaluate(state, health_percent, threat_level)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(:current_state, _from, state) do
    {:reply, state.current_state, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      current_state: state.current_state,
      previous_state: state.previous_state,
      health_percent: state.health_percent,
      threat_level: state.threat_level,
      recovery_cycles: state.recovery_cycles,
      remaining_cycles: max(0, @hysteresis_cycles - state.recovery_cycles),
      transition_count: state.transition_count,
      last_transition: state.last_transition,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.created_at, :second),
      allowed_actions: allowed_actions_for(state.current_state),
      status: :running
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call({:force_transition, target_state}, _from, state) do
    case request_guardian_approval(:force_transition, state.current_state, target_state) do
      {:ok, :approved} ->
        new_state = do_transition(state, target_state, :forced)
        {:reply, {:ok, new_state.current_state}, new_state}

      {:veto, reason, _fallback} ->
        emit_transition_vetoed(state.current_state, target_state, reason)
        {:reply, {:error, :guardian_veto, reason}, state}

      {:error, reason} ->
        {:reply, {:error, :guardian_error, inspect(reason)}, state}
    end
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    case request_guardian_approval(:reset, state.current_state, :normal) do
      {:ok, :approved} ->
        new_state = do_transition(state, :normal, :reset)
        {:reply, :ok, %{new_state | recovery_cycles: 0}}

      {:veto, reason, _fallback} ->
        emit_transition_vetoed(state.current_state, :normal, reason)
        {:reply, {:error, :guardian_veto, reason}, state}

      {:error, reason} ->
        {:reply, {:error, :guardian_error, inspect(reason)}, state}
    end
  end

  # ============================================================================
  # Private: State Evaluation Logic
  # ============================================================================

  defp do_evaluate(state, health_percent, threat_level) do
    # Update current metrics
    state = %{state | health_percent: health_percent, threat_level: threat_level}

    # Determine target state based on health and threats
    target_state = compute_target_state(health_percent, threat_level)

    cond do
      # Same state - no transition needed
      target_state == state.current_state ->
        # Reset recovery cycles if staying in degraded state
        new_state = %{state | recovery_cycles: 0}
        {{:ok, state.current_state}, new_state}

      # Degradation (forward) - immediate transition
      is_degradation?(state.current_state, target_state) ->
        apply_transition_with_guardian(state, target_state, :degradation)

      # Recovery (reverse) - requires hysteresis
      is_recovery?(state.current_state, target_state) ->
        apply_recovery_with_hysteresis(state, target_state, health_percent)
    end
  end

  defp compute_target_state(health_percent, threat_level) do
    cond do
      # Emergency: health critically low or extinction threat
      health_percent < @safe_threshold or threat_level == @extinction_threat_severity ->
        :emergency

      # Safe: health low or critical threat
      health_percent < @degraded_threshold or threat_level == @critical_threat_severity ->
        :safe

      # Degraded: health below normal
      health_percent < @normal_threshold ->
        :degraded

      # Normal: everything healthy
      true ->
        :normal
    end
  end

  defp is_degradation?(from, to) do
    state_severity(to) > state_severity(from)
  end

  defp is_recovery?(from, to) do
    state_severity(to) < state_severity(from)
  end

  defp state_severity(:normal), do: 0
  defp state_severity(:degraded), do: 1
  defp state_severity(:safe), do: 2
  defp state_severity(:emergency), do: 3

  # ============================================================================
  # Private: Hysteresis Logic (SC-OODA-005)
  # ============================================================================

  defp apply_recovery_with_hysteresis(state, target_state, health_percent) do
    # Check if health meets recovery threshold (10% margin above degradation threshold)
    recovery_threshold = get_recovery_threshold(target_state)

    if health_percent >= recovery_threshold do
      # Increment recovery cycle counter
      new_cycles = state.recovery_cycles + 1

      if new_cycles >= @hysteresis_cycles do
        # 3 consecutive healthy cycles - apply recovery transition
        apply_transition_with_guardian(state, target_state, :recovery)
      else
        # Still in hysteresis hold
        new_state = %{state | recovery_cycles: new_cycles}
        remaining = @hysteresis_cycles - new_cycles

        emit_hysteresis_hold(state.current_state, target_state, new_cycles, remaining)

        {{:held, state.current_state, remaining}, new_state}
      end
    else
      # Health dropped below recovery threshold - reset counter
      new_state = %{state | recovery_cycles: 0}
      {{:held, state.current_state, @hysteresis_cycles}, new_state}
    end
  end

  defp get_recovery_threshold(:normal), do: @normal_recovery_threshold
  defp get_recovery_threshold(:degraded), do: @degraded_recovery_threshold
  defp get_recovery_threshold(:safe), do: @safe_recovery_threshold
  defp get_recovery_threshold(:emergency), do: @safe_threshold

  # ============================================================================
  # Private: Guardian Integration (SC-PRAJNA-001)
  # ============================================================================

  defp apply_transition_with_guardian(state, target_state, trigger) do
    case request_guardian_approval(trigger, state.current_state, target_state) do
      {:ok, :approved} ->
        new_state = do_transition(state, target_state, trigger)
        {{:ok, new_state.current_state}, new_state}

      {:veto, reason, _fallback} ->
        emit_transition_vetoed(state.current_state, target_state, reason)
        {{:error, :guardian_veto, reason}, state}

      {:error, _reason} ->
        # Guardian error - apply transition anyway for safety (fail-open for degradation)
        if trigger == :degradation do
          Logger.warning(
            "[SafeState] Guardian error during degradation - applying safety transition"
          )

          new_state = do_transition(state, target_state, trigger)
          {{:ok, new_state.current_state}, new_state}
        else
          {{:held, state.current_state, @hysteresis_cycles}, state}
        end
    end
  end

  defp request_guardian_approval(trigger, from_state, to_state) do
    proposal = %{
      type: :state_transition,
      action: :safe_state_change,
      module: __MODULE__,
      trigger: trigger,
      from_state: from_state,
      to_state: to_state,
      timestamp: DateTime.utc_now(),
      request_id: Ecto.UUID.generate()
    }

    try do
      case GuardianIntegration.submit_proposal(proposal) do
        {:ok, _} -> {:ok, :approved}
        {:veto, reason, fallback} -> {:veto, reason, fallback}
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        Logger.warning("[SafeState] Guardian integration error: #{Exception.message(e)}")
        {:error, {:guardian_error, e}}
    catch
      :exit, reason ->
        Logger.warning("[SafeState] Guardian call failed: #{inspect(reason)}")
        {:error, {:guardian_unavailable, reason}}
    end
  end

  defp do_transition(state, target_state, trigger) do
    now = DateTime.utc_now()

    new_state = %{
      state
      | current_state: target_state,
        previous_state: state.current_state,
        last_transition: now,
        transition_count: state.transition_count + 1,
        recovery_cycles: 0
    }

    emit_transition(state.current_state, target_state, trigger, new_state.transition_count)
    log_to_immutable_register(state.current_state, target_state, trigger)

    new_state
  end

  # ============================================================================
  # Private: Direct Evaluation (Fallback)
  # ============================================================================

  defp evaluate_direct(health_percent, threat_level) do
    target_state = compute_target_state(health_percent, threat_level)
    {:ok, target_state}
  end

  # ============================================================================
  # Private: Allowed Actions
  # ============================================================================

  defp allowed_actions_for(:normal), do: [:all]
  defp allowed_actions_for(:degraded), do: [:critical, :essential, :monitoring]
  defp allowed_actions_for(:safe), do: [:critical, :monitoring]
  defp allowed_actions_for(:emergency), do: [:emergency_stop, :monitoring]

  # ============================================================================
  # Private: Immutable State Logging (SC-PRAJNA-003)
  # ============================================================================

  defp log_to_immutable_register(from_state, to_state, trigger) do
    payload = %{
      change_type: :safe_state_transition,
      from_state: from_state,
      to_state: to_state,
      trigger: trigger,
      timestamp: DateTime.utc_now(),
      module: __MODULE__
    }

    case ImmutableState.record(payload) do
      {:ok, block_hash} ->
        Logger.debug("[SafeState] Transition logged to ImmutableState: #{block_hash}")

      {:error, reason} ->
        Logger.warning("[SafeState] ImmutableState logging error: #{inspect(reason)}")
    end
  rescue
    e ->
      Logger.warning("[SafeState] ImmutableState logging error: #{Exception.message(e)}")
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_initialized(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :safe_state, :initialized],
      %{timestamp: System.system_time(:millisecond)},
      %{initial_state: state.current_state}
    )
  end

  defp emit_transition(from_state, to_state, trigger, transition_count) do
    severity = if is_degradation?(from_state, to_state), do: :degradation, else: :recovery

    :telemetry.execute(
      [:indrajaal, :prajna, :safe_state, :transition],
      %{
        timestamp: System.system_time(:millisecond),
        transition_count: transition_count
      },
      %{
        from_state: from_state,
        to_state: to_state,
        trigger: trigger,
        severity: severity
      }
    )

    Logger.info(
      "[SafeState] Transition #{from_state} -> #{to_state} (#{trigger}, #{severity}, count: #{transition_count})"
    )
  end

  defp emit_transition_vetoed(from_state, to_state, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :safe_state, :transition_vetoed],
      %{timestamp: System.system_time(:millisecond), count: 1},
      %{from_state: from_state, to_state: to_state, reason: reason}
    )

    Logger.warning("[SafeState] Transition #{from_state} -> #{to_state} VETOED: #{reason}")
  end

  defp emit_hysteresis_hold(current_state, target_state, cycles, remaining) do
    :telemetry.execute(
      [:indrajaal, :prajna, :safe_state, :hysteresis_hold],
      %{
        timestamp: System.system_time(:millisecond),
        cycles: cycles,
        remaining: remaining
      },
      %{current_state: current_state, target_state: target_state}
    )

    Logger.debug(
      "[SafeState] Hysteresis hold: #{current_state} (#{cycles}/#{@hysteresis_cycles} cycles to #{target_state})"
    )
  end
end
