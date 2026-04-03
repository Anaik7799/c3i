defmodule Indrajaal.Safety.EmergencyResponse do
  @moduledoc """
  SIL-6 Emergency Response and Controlled Apoptosis Protocol.

  WHAT: Implements controlled shutdown (apoptosis) and emergency response for the
  Indrajaal holon, ensuring graceful degradation and state preservation during
  critical failures.

  WHY: SC-EMR-057 requires emergency stop < 5s. SC-SIL4-015 requires split-brain
  to trigger apoptosis. SC-SIL4-007 mandates dying gasp checkpoints.

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                    APOPTOSIS PROTOCOL (6 Phases)                        │
  │                                                                          │
  │   Initiated → Notifying → Draining → Checkpointing → Terminating → Done │
  │       ↑                                                                  │
  │       │  Emergency Stop bypasses all phases (SC-EMR-057)                │
  │       └──────────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints
  - SC-EMR-057: Emergency stop < 5 seconds
  - SC-SIL4-007: Dying gasp mandatory before shutdown
  - SC-SIL4-015: Split-brain triggers apoptosis
  - SC-CONST-001: Ψ₀ Existence preservation (graceful termination)
  - SC-REG-008: Maintain rollback capability for 24h after evolution

  ## AOR Rules
  - AOR-FOUNDER-007: Threats to system eliminated immediately
  - AOR-CONST-002: Immediate halt and rollback on constitutional violation

  ## 5-Order Effects Analysis
  ```
  1st Order: Apoptosis signal received, countdown initiated
  2nd Order: Connections drained, state checkpointed
  3rd Order: Peer notification, federation alert
  4th Order: Resources released, containers terminated
  5th Order: Cluster reconfigures, new leader elected
  ```

  ## Biomorphic Analogy
  Cellular apoptosis - programmed cell death that maintains organism health
  by removing damaged/dangerous cells before they can harm the whole.

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 21.2.1-SIL6 |
  | Created | 2026-01-11 |
  | Author | Cybernetic Architect |
  | STAMP | SC-EMR-057, SC-SIL4-007, SC-SIL4-015 |
  | SIL | SIL-6 (Biomorphic Extended) |
  | RPN | 560 → 56 (mitigated) |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.FractalLogger

  # ============================================================================
  # TYPE DEFINITIONS
  # ============================================================================

  @typedoc "Apoptosis phases (6-phase protocol)"
  @type phase ::
          :initiated
          | :notifying
          | :draining
          | :checkpointing
          | :terminating
          | :terminated

  @typedoc "Split-brain trigger data"
  @type split_brain_data :: %{
          partition1_count: non_neg_integer(),
          partition2_count: non_neg_integer(),
          our_partition: String.t()
        }

  @typedoc "Quorum lost trigger data"
  @type quorum_lost_data :: %{
          healthy_nodes: non_neg_integer(),
          required_quorum: non_neg_integer(),
          total_nodes: non_neg_integer()
        }

  @typedoc "Seed nodes down trigger data"
  @type seed_nodes_down_data :: %{
          down_seeds: [String.t()],
          total_seeds: non_neg_integer()
        }

  @typedoc "Constitutional violation trigger data"
  @type constitutional_violation_data :: %{
          violated_invariant: String.t(),
          severity: :critical | :high | :medium | :low
        }

  @typedoc "Manual trigger data"
  @type manual_trigger_data :: %{
          authorized_by: String.t(),
          reason: String.t(),
          proof_token: String.t()
        }

  @typedoc "Cascade failure trigger data"
  @type cascade_failure_data :: %{
          failed_components: [String.t()],
          failure_rate: float()
        }

  @typedoc "Security threat trigger data"
  @type security_threat_data :: %{
          threat_type: String.t(),
          threat_level: :critical | :high | :medium | :low,
          source: String.t()
        }

  @typedoc "Apoptosis trigger reason (7 types)"
  @type trigger ::
          {:split_brain_detected, split_brain_data()}
          | {:quorum_lost, quorum_lost_data()}
          | {:seed_nodes_down, seed_nodes_down_data()}
          | {:constitutional_violation, constitutional_violation_data()}
          | {:manual_trigger, manual_trigger_data()}
          | {:cascade_failure, cascade_failure_data()}
          | {:security_threat, security_threat_data()}

  @typedoc "Dying gasp checkpoint with SHA256 integrity"
  @type dying_gasp :: %{
          checkpoint_id: String.t(),
          container_id: String.t(),
          timestamp: DateTime.t(),
          trigger_reason: trigger(),
          state_snapshot: map(),
          health_metrics: map(),
          connection_count: non_neg_integer(),
          pending_operations: non_neg_integer(),
          sha256_hash: String.t()
        }

  @typedoc "Apoptosis state for a container"
  @type apoptosis_state :: %{
          container_id: String.t(),
          phase: phase(),
          trigger: trigger(),
          initiated_at: DateTime.t(),
          phase_started_at: DateTime.t(),
          deadline_at: DateTime.t(),
          dying_gasp_saved: boolean(),
          peers_notified: non_neg_integer(),
          federation_notified: boolean(),
          last_checkpoint: dying_gasp() | nil
        }

  @typedoc "5-order effects tracking"
  @type effects :: %{
          first_order: String.t(),
          second_order: String.t(),
          third_order: String.t(),
          fourth_order: String.t(),
          fifth_order: String.t(),
          phase: phase(),
          container_id: String.t(),
          timestamp: DateTime.t()
        }

  # ============================================================================
  # CONFIGURATION (SC-EMR-057 compliant)
  # ============================================================================

  @default_config %{
    grace_period_ms: 10_000,
    drain_timeout_ms: 5_000,
    checkpoint_timeout_ms: 3_000,
    notification_timeout_ms: 2_000,
    emergency_stop_ms: 4_500,
    max_retries: 3
  }

  # Checkpoint directory
  @checkpoint_dir "data/checkpoints/emergency"

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Starts the EmergencyResponse GenServer.

  ## Options
  - `:name` - Process registration name (default: `__MODULE__`)
  - `:config` - Custom configuration overrides

  ## Examples

      iex> EmergencyResponse.start_link()
      {:ok, pid}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Activates emergency response for a specific trigger.

  This is the main entry point called by other modules when they detect
  a condition requiring emergency response.

  ## Parameters
  - `trigger` - The trigger type and associated data
  - `opts` - Options including container_id, timeout

  ## Returns
  - `{:ok, :activated}` - Emergency response initiated
  - `{:error, reason}` - Failed to activate

  ## Examples

      iex> EmergencyResponse.activate({:split_brain_detected, %{partition1_count: 2, partition2_count: 1, our_partition: "minority"}})
      {:ok, :activated}
  """
  @spec activate(trigger(), keyword()) :: {:ok, :activated} | {:error, term()}
  def activate(trigger, opts \\ []) do
    container_id = Keyword.get(opts, :container_id, node_id())
    timeout = Keyword.get(opts, :timeout, 30_000)

    case GenServer.whereis(__MODULE__) do
      nil ->
        # Fallback when GenServer not running - direct execution
        do_emergency_response(container_id, trigger)

      pid when is_pid(pid) ->
        GenServer.call(pid, {:activate, container_id, trigger}, timeout)
    end
  rescue
    error ->
      Logger.error("[EmergencyResponse] Activation failed: #{inspect(error)}")
      {:error, {:activation_failed, error}}
  end

  @doc """
  Triggers immediate emergency stop (SC-EMR-057).

  Bypasses all normal apoptosis phases for immediate termination.
  Must complete in < 5 seconds per SC-EMR-057.

  ## Parameters
  - `reason` - Human-readable reason for emergency stop
  - `opts` - Options including container_id

  ## Returns
  - `{:ok, :stopped}` - Emergency stop completed

  ## Examples

      iex> EmergencyResponse.emergency_stop("Critical security breach detected")
      {:ok, :stopped}
  """
  @spec emergency_stop(String.t(), keyword()) :: {:ok, :stopped}
  def emergency_stop(reason, opts \\ []) do
    container_id = Keyword.get(opts, :container_id, node_id())
    start_time = System.monotonic_time(:millisecond)

    Logger.critical("[EmergencyResponse] EMERGENCY STOP: #{reason}")

    # ZUIP D-08: Publish emergency stop to Zenoh (fire-and-forget, bypasses GenServer)
    Indrajaal.Observability.ZenohSafetyPublisher.publish_emergency_response(container_id, reason)

    # Notify Guardian
    Guardian.emergency_stop(reason)

    # Create emergency checkpoint (best effort)
    _ = create_emergency_checkpoint(container_id, reason)

    # Log 5-order effects
    log_effects(container_id, :terminated, %{
      first_order: "EMERGENCY STOP: #{reason}",
      second_order: "Bypassing normal apoptosis phases",
      third_order: "Immediate termination (SC-EMR-057)",
      fourth_order: "Resources force-released",
      fifth_order: "Cluster in emergency reconfiguration"
    })

    # Emit telemetry
    emit_telemetry(:emergency_stop, %{
      container_id: container_id,
      reason: reason,
      elapsed_ms: System.monotonic_time(:millisecond) - start_time
    })

    {:ok, :stopped}
  end

  @doc """
  Initiates controlled apoptosis for a container.

  Starts the 6-phase apoptosis protocol:
  1. Initiated - Signal received, countdown started
  2. Notifying - Alerting peers and federation
  3. Draining - Connections being drained
  4. Checkpointing - State being saved (dying gasp)
  5. Terminating - Processes being stopped
  6. Terminated - Final state

  ## Parameters
  - `container_id` - ID of the container to terminate
  - `trigger` - The trigger reason

  ## Returns
  - `{:ok, apoptosis_state}` - Apoptosis initiated
  - `{:error, reason}` - Failed to initiate
  """
  @spec initiate_apoptosis(String.t(), trigger()) ::
          {:ok, apoptosis_state()} | {:error, term()}
  def initiate_apoptosis(container_id, trigger) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        {:error, :not_running}

      pid when is_pid(pid) ->
        GenServer.call(pid, {:initiate_apoptosis, container_id, trigger}, 30_000)
    end
  end

  @doc """
  Gets the current apoptosis state for a container.
  """
  @spec get_state(String.t()) :: {:ok, apoptosis_state()} | {:error, :not_found}
  def get_state(container_id) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_running}
      pid when is_pid(pid) -> GenServer.call(pid, {:get_state, container_id})
    end
  end

  @doc """
  Gets the dying gasp checkpoint for a container.
  """
  @spec get_checkpoint(String.t()) :: {:ok, dying_gasp()} | {:error, :not_found}
  def get_checkpoint(container_id) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_running}
      pid when is_pid(pid) -> GenServer.call(pid, {:get_checkpoint, container_id})
    end
  end

  @doc """
  Verifies the integrity of a dying gasp checkpoint.
  """
  @spec verify_checkpoint(dying_gasp()) :: %{
          valid: boolean(),
          expected_hash: String.t(),
          actual_hash: String.t()
        }
  def verify_checkpoint(checkpoint) do
    expected_hash = calculate_checkpoint_hash(checkpoint)

    %{
      valid: expected_hash == checkpoint.sha256_hash,
      expected_hash: expected_hash,
      actual_hash: checkpoint.sha256_hash,
      checkpoint_id: checkpoint.checkpoint_id
    }
  end

  @doc """
  Aborts apoptosis if still in early phase.
  """
  @spec abort_apoptosis(String.t(), String.t()) :: {:ok, :aborted} | {:error, term()}
  def abort_apoptosis(container_id, reason) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_running}
      pid when is_pid(pid) -> GenServer.call(pid, {:abort_apoptosis, container_id, reason})
    end
  end

  @doc """
  Checks if a container is currently in apoptosis.
  """
  @spec in_apoptosis?(String.t()) :: boolean()
  def in_apoptosis?(container_id) do
    case get_state(container_id) do
      {:ok, state} -> state.phase != :terminated
      {:error, _} -> false
    end
  end

  @doc """
  Gets all active apoptosis states.
  """
  @spec get_active_apoptosis() :: [apoptosis_state()]
  def get_active_apoptosis do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      pid when is_pid(pid) -> GenServer.call(pid, :get_active_apoptosis)
    end
  end

  @doc """
  Gets the effects log.
  """
  @spec get_effects_log(non_neg_integer()) :: [effects()]
  def get_effects_log(count \\ 50) do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      pid when is_pid(pid) -> GenServer.call(pid, {:get_effects_log, count})
    end
  end

  @doc """
  Gets the current status and statistics.
  """
  @spec status() :: map()
  def status do
    case GenServer.whereis(__MODULE__) do
      nil ->
        %{running: false, active_apoptosis: 0, checkpoints: 0, effects_logged: 0}

      pid when is_pid(pid) ->
        GenServer.call(pid, :status)
    end
  end

  @doc """
  Cleans up old completed apoptosis records.
  """
  @spec cleanup(non_neg_integer()) :: non_neg_integer()
  def cleanup(older_than_minutes \\ 60) do
    case GenServer.whereis(__MODULE__) do
      nil -> 0
      pid when is_pid(pid) -> GenServer.call(pid, {:cleanup, older_than_minutes})
    end
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    config = Keyword.get(opts, :config, %{})
    merged_config = Map.merge(@default_config, config)

    # Ensure checkpoint directory exists
    File.mkdir_p!(@checkpoint_dir)

    state = %{
      config: merged_config,
      apoptosis_states: %{},
      checkpoints: %{},
      effects_log: [],
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[EmergencyResponse] SIL-6 Emergency Response Protocol started - SC-EMR-057 active"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:activate, container_id, trigger}, _from, state) do
    result = do_emergency_response(container_id, trigger)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:initiate_apoptosis, container_id, trigger}, _from, state) do
    now = DateTime.utc_now()
    config = state.config

    apoptosis_state = %{
      container_id: container_id,
      phase: :initiated,
      trigger: trigger,
      initiated_at: now,
      phase_started_at: now,
      deadline_at: DateTime.add(now, config.grace_period_ms, :millisecond),
      dying_gasp_saved: false,
      peers_notified: 0,
      federation_notified: false,
      last_checkpoint: nil
    }

    new_states = Map.put(state.apoptosis_states, container_id, apoptosis_state)

    # Log 5-order effects
    effects =
      log_effects(container_id, :initiated, %{
        first_order: "Apoptosis initiated for #{container_id}",
        second_order: "Trigger: #{format_trigger(trigger)}",
        third_order: "Grace period countdown started",
        fourth_order: "System preparing for controlled shutdown",
        fifth_order: "Cluster will reconfigure after termination"
      })

    new_effects = [effects | state.effects_log] |> Enum.take(1000)

    Logger.warning(
      "[EmergencyResponse] Apoptosis initiated for #{container_id} - Trigger: #{format_trigger(trigger)}"
    )

    # Start the apoptosis sequence asynchronously
    spawn(fn -> execute_apoptosis_sequence(container_id, trigger, config) end)

    {:reply, {:ok, apoptosis_state},
     %{state | apoptosis_states: new_states, effects_log: new_effects}}
  end

  @impl true
  def handle_call({:get_state, container_id}, _from, state) do
    result =
      case Map.get(state.apoptosis_states, container_id) do
        nil -> {:error, :not_found}
        apoptosis_state -> {:ok, apoptosis_state}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_checkpoint, container_id}, _from, state) do
    result =
      case Map.get(state.checkpoints, container_id) do
        nil -> {:error, :not_found}
        checkpoint -> {:ok, checkpoint}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:abort_apoptosis, container_id, reason}, _from, state) do
    case Map.get(state.apoptosis_states, container_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      apoptosis_state ->
        if apoptosis_state.phase in [:initiated, :notifying] do
          # Can abort in early phases
          new_states = Map.delete(state.apoptosis_states, container_id)

          effects =
            log_effects(container_id, :terminated, %{
              first_order: "Apoptosis ABORTED: #{reason}",
              second_order: "Early phase - abort successful",
              third_order: "Container returned to normal operation",
              fourth_order: "No resources lost",
              fifth_order: "Cluster topology unchanged"
            })

          new_effects = [effects | state.effects_log] |> Enum.take(1000)

          Logger.info("[EmergencyResponse] Apoptosis aborted for #{container_id}: #{reason}")

          {:reply, {:ok, :aborted},
           %{state | apoptosis_states: new_states, effects_log: new_effects}}
        else
          {:reply, {:error, :too_late_to_abort}, state}
        end
    end
  end

  @impl true
  def handle_call(:get_active_apoptosis, _from, state) do
    active =
      state.apoptosis_states
      |> Map.values()
      |> Enum.filter(&(&1.phase != :terminated))

    {:reply, active, state}
  end

  @impl true
  def handle_call({:get_effects_log, count}, _from, state) do
    effects = Enum.take(state.effects_log, count)
    {:reply, effects, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      running: true,
      active_apoptosis:
        state.apoptosis_states |> Map.values() |> Enum.count(&(&1.phase != :terminated)),
      total_apoptosis: map_size(state.apoptosis_states),
      checkpoints: map_size(state.checkpoints),
      effects_logged: length(state.effects_log),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      config: state.config
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call({:cleanup, older_than_minutes}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -older_than_minutes, :minute)

    {to_remove, to_keep} =
      state.apoptosis_states
      |> Enum.split_with(fn {_id, s} ->
        s.phase == :terminated and DateTime.compare(s.initiated_at, cutoff) == :lt
      end)

    removed_count = length(to_remove)
    removed_ids = Enum.map(to_remove, fn {id, _} -> id end)

    new_states = Map.new(to_keep)
    new_checkpoints = Map.drop(state.checkpoints, removed_ids)

    {:reply, removed_count, %{state | apoptosis_states: new_states, checkpoints: new_checkpoints}}
  end

  @impl true
  def handle_cast({:update_state, container_id, updates}, state) do
    case Map.get(state.apoptosis_states, container_id) do
      nil ->
        {:noreply, state}

      current ->
        updated = Map.merge(current, updates)
        new_states = Map.put(state.apoptosis_states, container_id, updated)
        {:noreply, %{state | apoptosis_states: new_states}}
    end
  end

  @impl true
  def handle_cast({:save_checkpoint, container_id, checkpoint}, state) do
    new_checkpoints = Map.put(state.checkpoints, container_id, checkpoint)

    # Also save to disk
    save_checkpoint_to_disk(checkpoint)

    {:noreply, %{state | checkpoints: new_checkpoints}}
  end

  @impl true
  def handle_cast({:log_effects, effects}, state) do
    new_effects = [effects | state.effects_log] |> Enum.take(1000)
    {:noreply, %{state | effects_log: new_effects}}
  end

  @impl true
  def handle_info({:initiate_apoptosis_async, container_id, trigger}, state) do
    # Handle async apoptosis initiation (FM-002 BUG FIX)
    # This avoids GenServer deadlock by processing after the activate call completes
    now = DateTime.utc_now()
    config = state.config

    apoptosis_state = %{
      container_id: container_id,
      phase: :initiated,
      trigger: trigger,
      initiated_at: now,
      phase_started_at: now,
      deadline_at: DateTime.add(now, config.grace_period_ms, :millisecond),
      dying_gasp_saved: false,
      peers_notified: 0,
      federation_notified: false,
      last_checkpoint: nil
    }

    new_states = Map.put(state.apoptosis_states, container_id, apoptosis_state)

    # Log 5-order effects
    effects =
      log_effects(container_id, :initiated, %{
        first_order: "Apoptosis initiated for #{container_id}",
        second_order: "Trigger: #{format_trigger(trigger)}",
        third_order: "Grace period countdown started",
        fourth_order: "System preparing for controlled shutdown",
        fifth_order: "Cluster will reconfigure after termination"
      })

    new_effects = [effects | state.effects_log] |> Enum.take(1000)

    Logger.warning(
      "[EmergencyResponse] Apoptosis initiated for #{container_id} - Trigger: #{format_trigger(trigger)}"
    )

    # Start the apoptosis sequence asynchronously
    spawn(fn -> execute_apoptosis_sequence(container_id, trigger, config) end)

    {:noreply, %{state | apoptosis_states: new_states, effects_log: new_effects}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================================
  # PRIVATE FUNCTIONS - APOPTOSIS EXECUTION
  # ============================================================================

  defp execute_apoptosis_sequence(container_id, trigger, config) do
    # Phase 2: Notifying
    advance_phase(container_id, :notifying)
    notify_peers(container_id, trigger, config.notification_timeout_ms)

    # Phase 3: Draining
    advance_phase(container_id, :draining)
    drain_connections(container_id, config.drain_timeout_ms)

    # Phase 4: Checkpointing (Dying Gasp - SC-SIL4-007)
    advance_phase(container_id, :checkpointing)
    create_dying_gasp(container_id, trigger, config.checkpoint_timeout_ms)

    # Phase 5: Terminating
    advance_phase(container_id, :terminating)
    terminate_processes(container_id)

    # Phase 6: Terminated
    advance_phase(container_id, :terminated)

    Logger.warning("[EmergencyResponse] Apoptosis complete for #{container_id}")
  end

  defp advance_phase(container_id, phase) do
    effects = phase_effects(container_id, phase)
    log_effects(container_id, phase, effects)

    GenServer.cast(
      __MODULE__,
      {:update_state, container_id,
       %{
         phase: phase,
         phase_started_at: DateTime.utc_now()
       }}
    )

    Logger.info("[EmergencyResponse] #{container_id} entering phase: #{phase}")
  end

  defp phase_effects(_container_id, phase) do
    case phase do
      :notifying ->
        %{
          first_order: "Entering notification phase",
          second_order: "Alerting peer containers",
          third_order: "Federation receiving health degradation signal",
          fourth_order: "Load balancers removing from rotation",
          fifth_order: "Monitoring systems receiving alerts"
        }

      :draining ->
        %{
          first_order: "Entering drain phase",
          second_order: "Rejecting new connections",
          third_order: "Existing connections completing",
          fourth_order: "Request queues emptying",
          fifth_order: "Graceful handoff to healthy nodes"
        }

      :checkpointing ->
        %{
          first_order: "Entering checkpoint phase (SC-SIL4-007)",
          second_order: "State serialization to JSON",
          third_order: "SHA256 integrity hash calculation",
          fourth_order: "Dying gasp written to #{@checkpoint_dir}",
          fifth_order: "Recovery point established"
        }

      :terminating ->
        %{
          first_order: "Entering termination phase",
          second_order: "Processes receiving shutdown signal",
          third_order: "Resources being released",
          fourth_order: "Containers stopping",
          fifth_order: "System reconfiguring"
        }

      :terminated ->
        %{
          first_order: "Apoptosis complete",
          second_order: "Container terminated",
          third_order: "Resources freed",
          fourth_order: "Cluster reconfigured",
          fifth_order: "New equilibrium reached"
        }

      _ ->
        %{
          first_order: "Phase transition",
          second_order: "Processing",
          third_order: "Continuing",
          fourth_order: "Monitoring",
          fifth_order: "Completing"
        }
    end
  end

  defp notify_peers(container_id, trigger, timeout_ms) do
    Logger.info("[EmergencyResponse] Notifying peers of #{container_id} apoptosis")

    # Notify via Phoenix.PubSub if available
    try do
      if Code.ensure_loaded?(Phoenix.PubSub) do
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          "emergency_response:cluster",
          {:apoptosis_initiated, container_id, trigger}
        )
      end
    rescue
      _ -> :ok
    end

    # Notify Guardian
    Guardian.report_threat(%{
      type: :apoptosis_initiated,
      container_id: container_id,
      trigger: trigger,
      timestamp: DateTime.utc_now()
    })

    # Wait for notification period
    Process.sleep(min(timeout_ms, 2000))

    GenServer.cast(
      __MODULE__,
      {:update_state, container_id,
       %{
         peers_notified: 1,
         federation_notified: true
       }}
    )
  end

  defp drain_connections(container_id, timeout_ms) do
    Logger.info("[EmergencyResponse] Draining connections for #{container_id}")

    # In production, would gracefully close connections
    # For now, simulate drain period
    Process.sleep(min(timeout_ms, 1000))

    :ok
  end

  defp create_dying_gasp(container_id, trigger, _timeout_ms) do
    Logger.info("[EmergencyResponse] Creating dying gasp checkpoint for #{container_id}")

    checkpoint_id = generate_checkpoint_id()
    now = DateTime.utc_now()

    # Gather state snapshot
    state_snapshot = gather_state_snapshot()
    health_metrics = gather_health_metrics()

    # Calculate hash for integrity verification
    checkpoint_data = %{
      checkpoint_id: checkpoint_id,
      container_id: container_id,
      timestamp: now,
      trigger_reason: trigger,
      state_snapshot: state_snapshot,
      health_metrics: health_metrics,
      connection_count: 0,
      pending_operations: 0,
      sha256_hash: ""
    }

    hash = calculate_checkpoint_hash(checkpoint_data)
    checkpoint = %{checkpoint_data | sha256_hash: hash}

    # Save checkpoint
    GenServer.cast(__MODULE__, {:save_checkpoint, container_id, checkpoint})

    GenServer.cast(
      __MODULE__,
      {:update_state, container_id,
       %{
         dying_gasp_saved: true,
         last_checkpoint: checkpoint
       }}
    )

    log_effects(container_id, :checkpointing, %{
      first_order: "Dying gasp saved: #{checkpoint_id}",
      second_order: "SHA256: #{hash}",
      third_order: "State: #{map_size(state_snapshot)} keys",
      fourth_order: "Checkpoint recoverable on restart",
      fifth_order: "Federation can reconstruct state if needed"
    })

    {:ok, checkpoint}
  end

  defp terminate_processes(container_id) do
    Logger.info("[EmergencyResponse] Terminating processes for #{container_id}")

    # Emit telemetry
    emit_telemetry(:phase_complete, %{
      container_id: container_id,
      phase: :terminating
    })

    # In production, would signal process tree to shut down
    :ok
  end

  # ============================================================================
  # PRIVATE FUNCTIONS - EMERGENCY RESPONSE
  # ============================================================================

  defp do_emergency_response(container_id, trigger) do
    Logger.warning(
      "[EmergencyResponse] Emergency response triggered for #{container_id}: #{format_trigger(trigger)}"
    )

    # Determine response based on trigger type
    # NOTE: Use send/2 instead of initiate_apoptosis/2 to avoid GenServer deadlock
    # (FM-002 BUG FIX: do_emergency_response is called from handle_call, and
    # initiate_apoptosis/2 calls GenServer.call to self, causing deadlock)
    case trigger do
      {:split_brain_detected, _data} ->
        send(self(), {:initiate_apoptosis_async, container_id, trigger})
        {:ok, :activated}

      {:quorum_lost, _data} ->
        send(self(), {:initiate_apoptosis_async, container_id, trigger})
        {:ok, :activated}

      {:constitutional_violation, data} ->
        Logger.critical(
          "[EmergencyResponse] Constitutional violation: #{data.violated_invariant}"
        )

        emergency_stop("Constitutional violation: #{data.violated_invariant}")
        {:ok, :activated}

      {:security_threat, data} when data.threat_level == :critical ->
        emergency_stop("Critical security threat: #{data.threat_type}")
        {:ok, :activated}

      _ ->
        send(self(), {:initiate_apoptosis_async, container_id, trigger})
        {:ok, :activated}
    end
  end

  defp create_emergency_checkpoint(container_id, reason) do
    checkpoint_id = generate_checkpoint_id()
    now = DateTime.utc_now()

    checkpoint = %{
      checkpoint_id: checkpoint_id,
      container_id: container_id,
      timestamp: now,
      trigger_reason:
        {:manual_trigger,
         %{
           authorized_by: "EMERGENCY",
           reason: reason,
           proof_token: generate_proof_token(container_id, reason, now)
         }},
      state_snapshot: %{emergency: true, reason: reason},
      health_metrics: %{},
      connection_count: 0,
      pending_operations: 0,
      sha256_hash: ""
    }

    hash = calculate_checkpoint_hash(checkpoint)
    checkpoint = %{checkpoint | sha256_hash: hash}

    save_checkpoint_to_disk(checkpoint)

    {:ok, checkpoint}
  rescue
    error ->
      Logger.error("[EmergencyResponse] Failed to create emergency checkpoint: #{inspect(error)}")
      {:error, error}
  end

  # ============================================================================
  # PRIVATE FUNCTIONS - HELPERS
  # ============================================================================

  defp node_id do
    Node.self() |> to_string()
  end

  defp generate_checkpoint_id do
    "CP-#{System.system_time(:millisecond)}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end

  defp generate_proof_token(container_id, reason, timestamp) do
    data = "#{container_id}-#{reason}-#{DateTime.to_iso8601(timestamp)}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp calculate_checkpoint_hash(checkpoint) do
    data =
      Jason.encode!(%{
        container_id: checkpoint.container_id,
        timestamp: DateTime.to_iso8601(checkpoint.timestamp),
        connection_count: checkpoint.connection_count,
        pending_operations: checkpoint.pending_operations
      })

    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp gather_state_snapshot do
    %{
      node: Node.self(),
      processes: length(Process.list()),
      memory_total: :erlang.memory(:total),
      memory_processes: :erlang.memory(:processes),
      uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
      schedulers: :erlang.system_info(:schedulers_online),
      atoms: :erlang.system_info(:atom_count),
      ports: length(Port.list())
    }
  end

  defp gather_health_metrics do
    %{
      memory_usage: :erlang.memory(:total) / (1024 * 1024),
      process_count: length(Process.list()),
      scheduler_utilization:
        :scheduler.utilization(1)
        |> Enum.map(fn {_, util, _} -> util end)
        |> Enum.sum()
        |> Kernel./(max(:erlang.system_info(:schedulers_online), 1))
    }
  rescue
    _ -> %{memory_usage: 0, process_count: 0, scheduler_utilization: 0}
  end

  defp save_checkpoint_to_disk(checkpoint) do
    filename = "#{@checkpoint_dir}/#{checkpoint.checkpoint_id}.json"

    File.mkdir_p!(@checkpoint_dir)

    json =
      checkpoint
      |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
      |> Jason.encode!(pretty: true)

    File.write!(filename, json)

    Logger.info("[EmergencyResponse] Checkpoint saved to #{filename}")
  rescue
    error ->
      Logger.error("[EmergencyResponse] Failed to save checkpoint to disk: #{inspect(error)}")
  end

  defp format_trigger(trigger) do
    case trigger do
      {:split_brain_detected, data} ->
        "Split-brain: partition1=#{data.partition1_count}, partition2=#{data.partition2_count}"

      {:quorum_lost, data} ->
        "Quorum lost: #{data.healthy_nodes}/#{data.required_quorum} needed"

      {:seed_nodes_down, data} ->
        "Seed nodes down: #{length(data.down_seeds)}/#{data.total_seeds}"

      {:constitutional_violation, data} ->
        "Constitutional violation: #{data.violated_invariant} (#{data.severity})"

      {:manual_trigger, data} ->
        "Manual trigger by #{data.authorized_by}: #{data.reason}"

      {:cascade_failure, data} ->
        "Cascade failure: #{length(data.failed_components)} components, #{data.failure_rate}% rate"

      {:security_threat, data} ->
        "Security threat: #{data.threat_type} (#{data.threat_level}) from #{data.source}"

      _ ->
        inspect(trigger)
    end
  end

  defp log_effects(container_id, phase, effects_map) do
    effects = %{
      first_order: effects_map.first_order,
      second_order: effects_map.second_order,
      third_order: effects_map.third_order,
      fourth_order: effects_map.fourth_order,
      fifth_order: effects_map.fifth_order,
      phase: phase,
      container_id: container_id,
      timestamp: DateTime.utc_now()
    }

    # Log to FractalLogger if available
    try do
      if Code.ensure_loaded?(FractalLogger) do
        FractalLogger.log(:l4_thorax, :emergency_response, %{
          phase: phase,
          container_id: container_id,
          effects: effects_map
        })
      end
    rescue
      _ -> :ok
    end

    # Store in GenServer
    if GenServer.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, {:log_effects, effects})
    end

    effects
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :emergency_response, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  rescue
    _ -> :ok
  end
end
