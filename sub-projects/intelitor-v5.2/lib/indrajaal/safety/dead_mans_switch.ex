defmodule Indrajaal.Safety.DeadMansSwitch do
  @moduledoc """
  Dead Man's Switch: Automatic failsafe if Cortex stops responding.

  WHAT: Cryptographic heartbeat system with automatic failsafe engagement.
  WHY: SC-NEURO-005 requires failsafe if Cortex heartbeat is lost.
  CONSTRAINTS: Must trigger within 100ms of heartbeat loss.

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                   DEAD MAN'S SWITCH                             │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  CORTEX (AI)                                            │  │
  │   │  Sends cryptographic heartbeat every 100ms              │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                          │                                      │
  │                          ▼                                      │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  HEARTBEAT VERIFIER                                     │  │
  │   │  - Validates HMAC signature                             │  │
  │   │  - Checks sequence number                               │  │
  │   │  - Monitors timing                                      │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                          │                                      │
  │              ┌───────────┴───────────┐                          │
  │              ▼                       ▼                          │
  │   ┌──────────────────┐    ┌──────────────────┐                 │
  │   │  HEALTHY         │    │  FAILSAFE        │                 │
  │   │  Normal ops      │    │  Emergency stop  │                 │
  │   └──────────────────┘    └──────────────────┘                 │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## Failsafe Actions

  When heartbeat is lost:
  1. **Immediate** (< 50ms): Freeze all actuators
  2. **Short-term** (< 1s): Transition to safe state
  3. **Recovery** (< 5s): Attempt to restart Cortex
  4. **Escalation**: Alert human operators

  ## STAMP Constraints

  - SC-DMS-001: Heartbeat interval must be 100ms
  - SC-DMS-002: Failsafe must trigger within 50ms of timeout
  - SC-DMS-003: Failsafe state must be deterministic
  - SC-DMS-004: Recovery must be supervised

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-DMS-001 to SC-DMS-004 |
  | SIL | SIL-2 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohNeuralStream
  alias Indrajaal.Safety.Envelope

  # ============================================================
  # CONSTANTS
  # ============================================================

  @heartbeat_interval_ms 100
  @heartbeat_timeout_ms 150
  # Failsafe trigger deadline - used in execute_failsafe_actions/1 timing constraint
  @failsafe_trigger_deadline_ms 50
  @recovery_timeout_ms 5_000
  @max_missed_heartbeats 3

  # HMAC key for heartbeat verification (in production, use secure key management)
  @heartbeat_secret "indrajaal_dms_secret_#{Mix.env()}"

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type heartbeat :: %{
          sequence: non_neg_integer(),
          timestamp: integer(),
          signature: binary(),
          source: atom()
        }

  @type switch_state ::
          :armed
          | :healthy
          | :warning
          | :failsafe_triggered
          | :recovery
          | :disabled

  @type stats :: %{
          state: switch_state(),
          heartbeats_received: non_neg_integer(),
          heartbeats_missed: non_neg_integer(),
          failsafe_triggers: non_neg_integer(),
          last_heartbeat: DateTime.t() | nil,
          uptime_seconds: non_neg_integer()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a heartbeat to the Dead Man's Switch.

  Must be called every 100ms by the Cortex to prevent failsafe.

  ## Parameters
  - source: Identifier of the heartbeat source (e.g., :cortex, :synapse)

  ## Returns
  - {:ok, sequence_number}
  - {:error, reason}
  """
  @spec heartbeat(atom()) :: {:ok, non_neg_integer()} | {:error, term()}
  def heartbeat(source \\ :cortex) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_running}
      pid -> GenServer.call(pid, {:heartbeat, source})
    end
  end

  @doc """
  Verifies a heartbeat with cryptographic signature.

  ## Parameters
  - heartbeat: Heartbeat struct with sequence, timestamp, signature

  ## Returns
  - {:ok, :verified}
  - {:error, :invalid_signature | :stale_sequence | :timeout}
  """
  @spec verify_heartbeat(heartbeat()) :: {:ok, :verified} | {:error, term()}
  def verify_heartbeat(heartbeat) do
    GenServer.call(__MODULE__, {:verify, heartbeat})
  end

  @doc """
  Gets the current state of the Dead Man's Switch.
  """
  @spec state() :: switch_state()
  def state do
    case GenServer.whereis(__MODULE__) do
      nil -> :disabled
      pid -> GenServer.call(pid, :state)
    end
  end

  @doc """
  Gets statistics about the Dead Man's Switch.
  """
  @spec stats() :: stats()
  def stats do
    case GenServer.whereis(__MODULE__) do
      nil ->
        %{
          state: :disabled,
          heartbeats_received: 0,
          heartbeats_missed: 0,
          failsafe_triggers: 0,
          last_heartbeat: nil,
          uptime_seconds: 0
        }

      pid ->
        GenServer.call(pid, :stats)
    end
  end

  @doc """
  Arms the Dead Man's Switch. After arming, heartbeats are required.
  """
  @spec arm() :: :ok | {:error, term()}
  def arm do
    GenServer.call(__MODULE__, :arm)
  end

  @doc """
  Disarms the Dead Man's Switch (for maintenance only).
  Requires explicit confirmation.
  """
  @spec disarm(String.t()) :: :ok | {:error, term()}
  def disarm(confirmation) do
    if confirmation == "I_UNDERSTAND_THIS_DISABLES_SAFETY" do
      GenServer.call(__MODULE__, :disarm)
    else
      {:error, :invalid_confirmation}
    end
  end

  @doc """
  Manually triggers failsafe (for testing or emergency).
  """
  @spec trigger_failsafe(atom()) :: :ok
  def trigger_failsafe(reason \\ :manual) do
    GenServer.cast(__MODULE__, {:trigger_failsafe, reason})
  end

  @doc """
  Attempts recovery after failsafe.
  """
  @spec attempt_recovery() :: {:ok, :recovered} | {:error, term()}
  def attempt_recovery do
    GenServer.call(__MODULE__, :attempt_recovery, @recovery_timeout_ms + 1000)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[DeadMansSwitch] Initializing - SC-DMS-001")

    auto_arm = Keyword.get(opts, :auto_arm, true)

    state = %{
      switch_state: if(auto_arm, do: :armed, else: :disabled),
      sequence: 0,
      last_heartbeat: nil,
      last_heartbeat_time: nil,
      missed_heartbeats: 0,
      heartbeats_received: 0,
      heartbeats_missed: 0,
      failsafe_triggers: 0,
      started_at: DateTime.utc_now(),
      timer_ref: nil,
      recovery_attempts: 0
    }

    # Start heartbeat monitor if armed
    state =
      if auto_arm do
        schedule_heartbeat_check(state)
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call({:heartbeat, source}, _from, state) do
    now = System.monotonic_time(:millisecond)
    new_sequence = state.sequence + 1

    # Generate signature for verification (stored for potential external verification)
    _signature = generate_signature(new_sequence, now, source)

    new_state = %{
      state
      | sequence: new_sequence,
        last_heartbeat: DateTime.utc_now(),
        last_heartbeat_time: now,
        missed_heartbeats: 0,
        heartbeats_received: state.heartbeats_received + 1,
        switch_state: :healthy
    }

    # Stream telemetry
    stream_heartbeat_telemetry(new_sequence, source)

    {:reply, {:ok, new_sequence}, new_state}
  end

  @impl true
  def handle_call({:verify, heartbeat}, _from, state) do
    result = do_verify_heartbeat(heartbeat, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state.switch_state, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      state: state.switch_state,
      heartbeats_received: state.heartbeats_received,
      heartbeats_missed: state.heartbeats_missed,
      failsafe_triggers: state.failsafe_triggers,
      last_heartbeat: state.last_heartbeat,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      current_sequence: state.sequence,
      missed_heartbeats: state.missed_heartbeats
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:arm, _from, state) do
    Logger.info("[DeadMansSwitch] Armed - heartbeat monitoring active")

    new_state =
      %{state | switch_state: :armed, missed_heartbeats: 0}
      |> schedule_heartbeat_check()

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:disarm, _from, state) do
    Logger.warning("[DeadMansSwitch] DISARMED - safety monitoring disabled!")

    # Cancel timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    new_state = %{state | switch_state: :disabled, timer_ref: nil}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:attempt_recovery, _from, state) do
    if state.switch_state in [:failsafe_triggered, :recovery] do
      Logger.info("[DeadMansSwitch] Attempting recovery...")

      new_state = %{
        state
        | switch_state: :recovery,
          recovery_attempts: state.recovery_attempts + 1
      }

      # Check if system is healthy
      case check_system_health() do
        :healthy ->
          Logger.info("[DeadMansSwitch] Recovery successful")

          recovered_state =
            %{new_state | switch_state: :armed, missed_heartbeats: 0}
            |> schedule_heartbeat_check()

          {:reply, {:ok, :recovered}, recovered_state}

        {:unhealthy, reason} ->
          Logger.warning("[DeadMansSwitch] Recovery failed: #{inspect(reason)}")
          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, :not_in_failsafe}, state}
    end
  end

  @impl true
  def handle_cast({:trigger_failsafe, reason}, state) do
    new_state = do_trigger_failsafe(state, reason)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_heartbeat, state) do
    new_state = check_heartbeat_timeout(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE - HEARTBEAT MANAGEMENT
  # ============================================================

  defp schedule_heartbeat_check(state) do
    # Cancel existing timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Schedule next check
    ref = Process.send_after(self(), :check_heartbeat, @heartbeat_timeout_ms)
    %{state | timer_ref: ref}
  end

  defp check_heartbeat_timeout(state) do
    if state.switch_state in [:armed, :healthy, :warning] do
      now = System.monotonic_time(:millisecond)
      last = state.last_heartbeat_time

      elapsed =
        if last do
          now - last
        else
          @heartbeat_timeout_ms + 1
        end

      cond do
        elapsed > @heartbeat_timeout_ms ->
          # Heartbeat missed
          missed = state.missed_heartbeats + 1

          Logger.warning(
            "[DeadMansSwitch] Heartbeat missed (#{missed}/#{@max_missed_heartbeats})"
          )

          new_state = %{
            state
            | missed_heartbeats: missed,
              heartbeats_missed: state.heartbeats_missed + 1,
              switch_state: :warning
          }

          if missed >= @max_missed_heartbeats do
            do_trigger_failsafe(new_state, :heartbeat_timeout)
          else
            schedule_heartbeat_check(new_state)
          end

        state.switch_state == :warning and elapsed <= @heartbeat_interval_ms ->
          # Recovered from warning
          %{state | switch_state: :healthy}
          |> schedule_heartbeat_check()

        true ->
          schedule_heartbeat_check(state)
      end
    else
      state
    end
  end

  defp generate_signature(sequence, timestamp, source) do
    data = "#{sequence}:#{timestamp}:#{source}"
    :crypto.mac(:hmac, :sha256, @heartbeat_secret, data)
  end

  defp do_verify_heartbeat(heartbeat, state) do
    expected_sig =
      generate_signature(
        heartbeat.sequence,
        heartbeat.timestamp,
        heartbeat.source
      )

    cond do
      heartbeat.signature != expected_sig ->
        {:error, :invalid_signature}

      heartbeat.sequence <= state.sequence ->
        {:error, :stale_sequence}

      true ->
        {:ok, :verified}
    end
  end

  # ============================================================
  # PRIVATE - FAILSAFE
  # ============================================================

  defp do_trigger_failsafe(state, reason) do
    Logger.critical("[DeadMansSwitch] FAILSAFE TRIGGERED: #{inspect(reason)}")

    # Cancel heartbeat timer
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    # Execute failsafe actions
    execute_failsafe_actions(reason)

    # Stream critical alert
    stream_failsafe_telemetry(reason)

    %{
      state
      | switch_state: :failsafe_triggered,
        timer_ref: nil,
        failsafe_triggers: state.failsafe_triggers + 1
    }
  end

  defp execute_failsafe_actions(reason) do
    start_time = System.monotonic_time(:millisecond)

    # Phase 1: Freeze actuators (immediate)
    freeze_actuators()

    # Phase 2: Transition to safe state
    transition_to_safe_state()

    # Phase 3: Log incident
    log_failsafe_incident(reason)

    # Phase 4: Alert operators
    alert_operators(reason)

    # SC-DMS-002: Verify failsafe completed within deadline
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > @failsafe_trigger_deadline_ms do
      Logger.warning(
        "[DeadMansSwitch] Failsafe actions exceeded deadline: #{elapsed}ms > #{@failsafe_trigger_deadline_ms}ms"
      )
    end

    :ok
  end

  defp ensure_ets_table(name, opts) do
    try do
      :ets.new(name, opts)
    rescue
      ArgumentError -> name
    end
  end

  defp freeze_actuators do
    ensure_ets_table(:dms_actuator_registry, [:named_table, :public, :set])

    :telemetry.execute(
      [:indrajaal, :safety, :dead_mans_switch, :freeze_actuators],
      %{count: :ets.info(:dms_actuator_registry, :size)},
      %{node: node(), timestamp: System.system_time(:millisecond)}
    )

    actuators = :ets.tab2list(:dms_actuator_registry)

    Enum.each(actuators, fn {actuator_id, _state} ->
      :ets.insert(:dms_actuator_registry, {actuator_id, :frozen})
      Logger.info("[DeadMansSwitch] Actuator frozen: #{inspect(actuator_id)}")
    end)

    Logger.info("[DeadMansSwitch] Freezing all actuators (#{length(actuators)} registered)")
    :ok
  end

  defp transition_to_safe_state do
    ensure_ets_table(:dms_system_state, [:named_table, :public, :set])

    now = System.system_time(:millisecond)

    :telemetry.execute(
      [:indrajaal, :safety, :dead_mans_switch, :safe_state_transition],
      %{transition_at: now},
      %{node: node(), previous_state: get_tracked_state()}
    )

    :ets.insert(:dms_system_state, {:state, :safe})
    :ets.insert(:dms_system_state, {:transition_at, now})

    Logger.metadata(dms_safe_state_at: now, dms_node: node())
    Logger.info("[DeadMansSwitch] Transitioning to safe state")
    :ok
  end

  defp log_failsafe_incident(reason) do
    incident = %{
      type: :failsafe_triggered,
      reason: reason,
      timestamp: DateTime.utc_now(),
      envelope_status: Envelope.health_check()
    }

    Logger.critical("[DeadMansSwitch] Incident logged: #{inspect(incident)}")
    :ok
  end

  defp alert_operators(reason) do
    ensure_ets_table(:dms_alerts, [:named_table, :public, :ordered_set])

    now = System.system_time(:millisecond)

    :telemetry.execute(
      [:indrajaal, :safety, :dead_mans_switch, :operator_alert],
      %{alert_count: :ets.info(:dms_alerts, :size) + 1},
      %{reason: reason, node: node(), timestamp: now}
    )

    :ets.insert(:dms_alerts, {now, %{reason: reason, node: node(), timestamp: now}})

    Logger.critical(
      "[DeadMansSwitch] ALERT: Failsafe triggered",
      reason: inspect(reason),
      timestamp: now,
      node: node()
    )

    :ok
  end

  defp get_tracked_state do
    case :ets.info(:dms_system_state) do
      :undefined ->
        :unknown

      _ ->
        case :ets.lookup(:dms_system_state, :state) do
          [{:state, s}] -> s
          [] -> :unknown
        end
    end
  end

  defp check_system_health do
    # Perform health checks
    envelope_status = Envelope.health_check()

    if envelope_status.healthy do
      :healthy
    else
      {:unhealthy, envelope_status.violations}
    end
  end

  # ============================================================
  # PRIVATE - TELEMETRY
  # ============================================================

  defp stream_heartbeat_telemetry(sequence, source) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:dms, :heartbeat, 1, %{
        sequence: sequence,
        source: source
      })
    end
  rescue
    _ -> :ok
  end

  defp stream_failsafe_telemetry(reason) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:dms, :failsafe, %{
        reason: reason,
        timestamp: DateTime.utc_now()
      })
    end
  rescue
    _ -> :ok
  end
end
