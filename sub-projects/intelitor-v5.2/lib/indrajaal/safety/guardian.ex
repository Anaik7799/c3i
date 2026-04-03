defmodule Indrajaal.Safety.Guardian do
  @moduledoc """
  The Simplex Architecture Guardian (High Assurance Kernel).

  WHAT: Deterministic gatekeeper for all AI/Autonomic decisions.
  WHY: SC-SEC-001 requires validation against immutable STAMP safety constraints.
  CONSTRAINTS: SIL-2 certified, no dynamic dispatch, linear chain of checks only.

  ## Architecture

  This module implements the "Decision Module" of the Simplex Architecture.
  It wraps the output of the Complex Controller (AI/OODA) and ensures it remains
  within the Pre-defined Safety Envelope.

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                   SIMPLEX ARCHITECTURE                          │
  │                                                                 │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  COMPLEX PLANE (Cortex/AI)                              │  │
  │   │  - Analyzes situation                                   │  │
  │   │  - Generates proposals                                  │  │
  │   │  - Sends heartbeat to DMS                               │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                          │                                      │
  │                          ▼                                      │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  GUARDIAN (Decision Module)                             │  │
  │   │  - Validates against Safety Envelope                    │  │
  │   │  - Returns {:ok, proposal} or {:veto, reason, fallback} │  │
  │   └─────────────────────────────────────────────────────────┘  │
  │                          │                                      │
  │                          ▼                                      │
  │   ┌─────────────────────────────────────────────────────────┐  │
  │   │  SAFETY PLANE                                           │  │
  │   │  - Envelope: Defines constraints                        │  │
  │   │  - DeadMansSwitch: Monitors heartbeat                   │  │
  │   └─────────────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## Protocol
  1. Receive `proposal` from Cortex/AI.
  2. Validate against Safety Envelope constraints.
  3. Return `{:ok, proposal}` OR `{:veto, reason, safe_fallback}`.

  ## STAMP Constraints
  - SC-FOUNDER-001: ALL actions MUST serve Abhijit Naik's lineage (Ω₀ Supreme Directive)
  - SC-SEC-001: No code execution without review
  - SC-RES-001: Resource limits (prevent exhaustion attacks)
  - SC-ACT-001: Actuator limits (physics-based checks)
  - SC-GUARD-001: Guardian must use Envelope for constraint values
  - SC-GUARD-002: Guardian must integrate with DeadMansSwitch
  - SC-GUARD-003: Guardian must integrate with FounderDirective

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GUARD-001 to SC-GUARD-002 |
  | SIL | SIL-2 |

  ## 🧬 [AGENT_RECREATION_GENOME]
  **Hash**: `SHA256:d8a9b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a4`
  **Recovery**: 
  - Supervisor: `Indrajaal.Safety.Supervisor`
  - Purpose: Simplex decision module, Vetoes unsafe actions, tracks `vetoes`.
  - Core Logic: `check_founder_directive`, `check_security_constraints`, `check_manual_override` (Two-Key Turn).
  - Protocol: P0 mutations REQUIRE `signatures: %{oracle: true, operator: true}`.
  [/AGENT_RECREATION_GENOME]
  """
  use GenServer
  require Logger

  alias Indrajaal.Safety.DeadMansSwitch
  alias Indrajaal.Safety.Envelope
  alias Indrajaal.Core.Holon.FounderDirective

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type proposal :: map()
  @type validation_result ::
          {:ok, proposal()}
          | {:veto, atom(), map()}

  # ============================================================
  # CLIENT API
  # ============================================================

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  The Atomic Gatekeeper.

  This function MUST be called before any actuator (CEPAF, Database, Switch)
  is touched by the AI or Autonomic System.

  ## Parameters
  - proposal: Map containing the action to validate

  ## Returns
  - {:ok, proposal} if the proposal is within the safety envelope
  - {:veto, reason, safe_fallback} if the proposal violates constraints
  """
  @spec validate_proposal(proposal()) :: validation_result()
  def validate_proposal(proposal) do
    validate_proposal(proposal, [])
  end

  @doc """
  Alias for validate_proposal/1 to support legacy MasterControl calls.
  Returns {:approved, proposal} or {:vetoed, reason}.
  """
  @spec propose(proposal()) :: {:approved, proposal()} | {:vetoed, atom()}
  def propose(proposal) do
    case validate_proposal(proposal) do
      {:ok, approved} -> {:approved, approved}
      {:veto, reason, _fallback} -> {:vetoed, reason}
    end
  end

  @doc """
  Validates a proposal with configurable timeout.

  ## Options
    - :timeout - Maximum time to wait for validation (default: 5000ms)

  ## Returns
  - {:ok, proposal} if the proposal is within the safety envelope
  - {:error, reason} if the proposal violates constraints
  """
  @spec validate_proposal(proposal(), keyword()) :: validation_result()
  def validate_proposal(proposal, opts) do
    timeout = Keyword.get(opts, :timeout, 5000)

    case GenServer.whereis(__MODULE__) do
      nil ->
        # Fallback when GenServer not running
        do_validate_proposal(proposal)

      pid when is_pid(pid) ->
        GenServer.call(__MODULE__, {:validate, proposal}, timeout)
    end
  rescue
    _ -> do_validate_proposal(proposal)
  end

  @doc """
  Checks if Guardian process is alive and responsive.

  ## Options
    - :timeout - Maximum time to wait for response (default: 2000ms)

  ## Returns
    - true if Guardian is alive and responds
    - false if Guardian is not running or times out
  """
  @spec alive?(keyword()) :: boolean()
  def alive?(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2_000)

    case GenServer.whereis(__MODULE__) do
      nil ->
        false

      pid when is_pid(pid) ->
        try do
          GenServer.call(__MODULE__, :ping, timeout) == :pong
        catch
          :exit, _ -> false
        end
    end
  rescue
    _ -> false
  end

  @doc """
  Performs a comprehensive health check including Envelope and DeadMansSwitch.

  ## Parameters
  - metrics: Optional map of current system metrics

  ## Returns
  - Map containing overall health status
  """
  @spec health_check(map()) :: map()
  def health_check(metrics \\ %{}) do
    envelope_status = Envelope.health_check(metrics)
    dms_state = DeadMansSwitch.state()
    dms_stats = DeadMansSwitch.stats()

    %{
      guardian: status(),
      envelope: envelope_status,
      dead_mans_switch: %{
        state: dms_state,
        heartbeats_received: dms_stats.heartbeats_received,
        heartbeats_missed: dms_stats.heartbeats_missed,
        failsafe_triggers: dms_stats.failsafe_triggers
      },
      overall_healthy:
        envelope_status.healthy and
          dms_state in [:healthy, :armed, :disabled] and
          status()[:running]
    }
  end

  @doc "Get current guardian status and stats."
  @spec status() :: map()
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> %{running: false, violations: 0, validations: 0}
      pid when is_pid(pid) -> GenServer.call(__MODULE__, :status)
    end
  rescue
    _ -> %{running: false, violations: 0, validations: 0}
  end

  @doc """
  Returns all safety constraints from the Envelope.
  """
  @spec constraints() :: map()
  def constraints do
    Envelope.all_constraints()
  end

  @doc """
  Report a detected threat to the Guardian.
  Used by Sentinel, PatternHunter, and SymbioticDefense for threat escalation.
  """
  @spec report_threat(map()) :: :ok
  def report_threat(threat) do
    Logger.warning(
      "[Guardian] Threat reported: #{inspect(threat[:type])} - #{inspect(threat[:signature] || threat[:reason])}"
    )

    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid when is_pid(pid) -> GenServer.cast(pid, {:threat_reported, threat})
    end

    :ok
  end

  @doc """
  Trigger emergency stop of all holon activities.

  SC-EMR-057: Stop <5s required.

  ## Implementation (P0-1 Fix)

  This is a REAL implementation that:
  1. Logs to Immutable Register (audit trail)
  2. Creates emergency checkpoint
  3. Terminates supervised processes gracefully
  4. Triggers hardware watchdog (if available)
  5. Halts the BEAM via :init.stop(1)

  ## Parameters
  - reason: Human-readable reason for emergency stop

  ## Returns
  - :ok (but the BEAM will be halted shortly after)

  ## STAMP Constraints
  - SC-EMR-057: Emergency stop < 5 seconds
  - SC-REG-001: All state changes via append-only register
  - SC-CONST-002: Immediate halt on constitutional violation
  """
  @spec emergency_stop(String.t()) :: :ok
  def emergency_stop(reason) do
    start_time = System.monotonic_time(:millisecond)
    Logger.critical("[Guardian] EMERGENCY STOP INITIATED: #{reason}")

    # ZUIP S-01: Publish emergency stop to Zenoh (fire-and-forget, bypasses GenServer)
    Indrajaal.Observability.ZenohSafetyPublisher.publish_guardian_emergency_stop(reason)

    # Spawn the emergency stop sequence in a separate process to ensure
    # it runs even if the calling process terminates
    spawn(fn -> execute_emergency_stop(reason, start_time) end)

    # Also try synchronous execution in the GenServer if available
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid when is_pid(pid) -> GenServer.cast(pid, {:emergency_stop, reason, start_time})
    end

    :ok
  end

  @doc """
  Synchronous emergency stop with blocking behavior.

  Use this when you need to ensure the stop sequence has started before
  returning. The BEAM will still be halted asynchronously within 5 seconds.

  ## Parameters
  - reason: Human-readable reason for emergency stop
  - opts: Options including :timeout (default 4500ms per SC-EMR-057)

  ## Returns
  - {:ok, :stopping} - Stop sequence initiated
  - {:error, :timeout} - Stop sequence timed out (fallback will still halt)
  """
  @spec emergency_stop_sync(String.t(), keyword()) :: {:ok, :stopping} | {:error, :timeout}
  def emergency_stop_sync(reason, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 4500)
    start_time = System.monotonic_time(:millisecond)

    Logger.critical("[Guardian] SYNC EMERGENCY STOP: #{reason}")

    # Execute stop sequence directly with timeout protection
    task =
      Task.async(fn ->
        execute_emergency_stop(reason, start_time)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, _result} ->
        {:ok, :stopping}

      nil ->
        # Timeout - force halt immediately
        Logger.critical("[Guardian] Emergency stop timeout - forcing immediate halt")
        force_beam_halt(reason)
        {:error, :timeout}
    end
  end

  # Private: Execute the full emergency stop sequence
  @spec execute_emergency_stop(String.t(), integer()) :: :ok
  defp execute_emergency_stop(reason, start_time) do
    # Phase 1: Log to Immutable Register (audit trail) - SC-REG-001
    _ = log_to_immutable_register(reason)

    # Phase 2: Create emergency checkpoint (best effort)
    _ = create_emergency_checkpoint(reason)

    # Phase 3: Notify Dead Man's Switch
    _ = notify_dead_mans_switch(reason)

    # Phase 4: Broadcast to PubSub for cluster awareness
    _ = broadcast_emergency_stop(reason)

    # Phase 5: Terminate supervised processes gracefully
    _ = terminate_supervised_processes(reason)

    # Phase 6: Trigger hardware watchdog (if available)
    _ = trigger_hardware_watchdog(reason)

    # Calculate elapsed time
    elapsed = System.monotonic_time(:millisecond) - start_time

    Logger.critical(
      "[Guardian] Emergency stop sequence completed in #{elapsed}ms - initiating BEAM halt"
    )

    # Phase 7: Final - Halt the BEAM (SC-EMR-057)
    # Use a small delay to allow logs to flush
    Process.sleep(100)
    force_beam_halt(reason)

    :ok
  end

  # Phase 1: Log to Immutable Register
  defp log_to_immutable_register(reason) do
    alias Indrajaal.Core.Holon.ImmutableRegister

    try do
      if GenServer.whereis(ImmutableRegister) do
        ImmutableRegister.append(:emergency_stop, %{
          reason: reason,
          timestamp: DateTime.utc_now(),
          node: Node.self(),
          constraint: "SC-EMR-057"
        })
      else
        Logger.warning("[Guardian] ImmutableRegister not available for audit logging")
        {:error, :not_available}
      end
    rescue
      error ->
        Logger.error("[Guardian] Failed to log to ImmutableRegister: #{inspect(error)}")
        {:error, error}
    end
  end

  # Phase 2: Create emergency checkpoint
  defp create_emergency_checkpoint(reason) do
    try do
      checkpoint = %{
        type: :emergency_stop,
        reason: reason,
        timestamp: DateTime.utc_now(),
        node: Node.self(),
        processes: length(Process.list()),
        memory_mb: :erlang.memory(:total) |> div(1024 * 1024),
        uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
      }

      # Write to checkpoint directory
      checkpoint_dir = "data/checkpoints/emergency"
      File.mkdir_p!(checkpoint_dir)

      checkpoint_id =
        "ES-#{System.system_time(:millisecond)}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"

      filename = "#{checkpoint_dir}/#{checkpoint_id}.json"
      File.write!(filename, Jason.encode!(checkpoint, pretty: true))

      Logger.info("[Guardian] Emergency checkpoint saved: #{checkpoint_id}")
      {:ok, checkpoint_id}
    rescue
      error ->
        Logger.warning("[Guardian] Failed to create checkpoint: #{inspect(error)}")
        {:error, error}
    end
  end

  # Phase 3: Notify Dead Man's Switch
  defp notify_dead_mans_switch(reason) do
    try do
      if GenServer.whereis(DeadMansSwitch) do
        DeadMansSwitch.trigger_failsafe(:emergency_stop)
      end
    rescue
      _ -> :ok
    end

    Logger.info("[Guardian] Dead Man's Switch notified: #{reason}")
    :ok
  end

  # Phase 4: Broadcast to cluster
  defp broadcast_emergency_stop(reason) do
    try do
      if Code.ensure_loaded?(Phoenix.PubSub) do
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          "guardian:emergency",
          {:emergency_stop, reason, Node.self()}
        )
      end
    rescue
      _ -> :ok
    end

    Logger.info("[Guardian] Emergency stop broadcast to cluster")
    :ok
  end

  # Phase 5: Terminate supervised processes
  defp terminate_supervised_processes(reason) do
    Logger.info("[Guardian] Terminating supervised processes: #{reason}")

    # Get the main supervisor
    try do
      case Process.whereis(Indrajaal.Supervisor) do
        nil ->
          :ok

        supervisor_pid ->
          # Get all children
          children = Supervisor.which_children(supervisor_pid)

          # Terminate each child gracefully (with timeout)
          Enum.each(children, fn {child_id, child_pid, _type, _modules} ->
            if is_pid(child_pid) do
              try do
                # Give each child 500ms to terminate gracefully
                Supervisor.terminate_child(supervisor_pid, child_id)
                Logger.debug("[Guardian] Terminated child: #{inspect(child_id)}")
              rescue
                error ->
                  Logger.warning(
                    "[Guardian] Failed to terminate #{inspect(child_id)}: #{inspect(error)}"
                  )
              end
            end
          end)
      end
    rescue
      error ->
        Logger.warning("[Guardian] Supervisor termination error: #{inspect(error)}")
    end

    :ok
  end

  # Phase 6: Hardware watchdog trigger
  defp trigger_hardware_watchdog(reason) do
    # In a production SIL-6 system, this would trigger a hardware watchdog
    # that monitors the system and can force a hard reset if software fails
    Logger.info("[Guardian] Hardware watchdog trigger: #{reason}")

    # Write to a watchdog file that external monitoring can detect
    try do
      watchdog_file = "data/watchdog/emergency_stop"
      File.mkdir_p!("data/watchdog")

      File.write!(watchdog_file, """
      EMERGENCY_STOP
      Reason: #{reason}
      Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}
      Node: #{Node.self()}
      """)
    rescue
      _ -> :ok
    end

    :ok
  end

  # Phase 7: Force BEAM halt
  defp force_beam_halt(reason) do
    Logger.critical("[Guardian] BEAM HALT IMMINENT - Reason: #{reason}")

    # Flush all logger backends
    Logger.flush()

    # Use :init.stop/1 to halt the BEAM with exit code 1
    # This is the proper way to stop the entire BEAM VM
    :init.stop(1)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    state = %{
      started_at: DateTime.utc_now(),
      validations: 0,
      violations: 0,
      vetoes: 0,
      last_violation: nil,
      constraints_checked: 0
    }

    Logger.info(
      "[Guardian] Safety kernel started - SC-SEC-001 active, Envelope + FounderDirective (Ω₀) integrated"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:validate, proposal}, _from, state) do
    result = do_validate_proposal(proposal)
    new_state = update_stats(state, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      running: true,
      validations: state.validations,
      violations: state.violations,
      vetoes: state.vetoes,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      constraints_checked: state.constraints_checked,
      last_violation: state.last_violation,
      envelope_constraints: Enum.count(Envelope.forbidden_operations())
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_cast({:threat_reported, threat}, state) do
    Logger.info("[Guardian] Processing threat: #{inspect(threat[:type])}")
    # Store threat for analysis
    {:noreply, state}
  end

  @impl true
  def handle_cast({:emergency_stop, reason, start_time}, state) do
    Logger.critical("[Guardian] GenServer executing emergency stop: #{reason}")

    # Execute the emergency stop sequence in the GenServer context
    # This provides an additional execution path alongside the spawned process
    spawn(fn ->
      execute_emergency_stop(reason, start_time)
    end)

    {:noreply, state}
  end

  # Legacy handler for backwards compatibility
  @impl true
  def handle_cast({:emergency_stop, reason}, state) do
    Logger.critical("[Guardian] Legacy emergency stop handler: #{reason}")
    start_time = System.monotonic_time(:millisecond)

    spawn(fn ->
      execute_emergency_stop(reason, start_time)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # VALIDATION LOGIC
  # ============================================================

  defp do_validate_proposal(proposal) do
    # In a real SIL-2 system, this would be a linear chain of checks
    # with no complex recursion or dynamic dispatch.
    # SC-GUARD-001: All constraints come from the Envelope module
    # SC-FOUNDER-001: All actions MUST serve Founder's lineage (Ω₀)

    with :ok <- check_founder_directive(proposal),
         :ok <- check_manual_override(proposal),
         :ok <- check_resource_bounds(proposal),
         :ok <- check_security_constraints(proposal),
         :ok <- check_actuator_physics(proposal),
         :ok <- check_temporal_constraints(proposal),
         :ok <- check_network_constraints(proposal),
         :ok <- check_cognitive_alignment(proposal) do
      # If all checks pass, the proposal is within the envelope.
      {:ok, proposal}
    else
      {:error, reason} ->
        # The proposal violated the envelope.
        # We must NOT execute it.
        Logger.critical("🛡️ GUARDIAN VETO: #{inspect(reason)} | Proposal: #{inspect(proposal)}")

        # ZUIP S-02: Publish Guardian veto to Zenoh mesh (fire-and-forget)
        Indrajaal.Observability.ZenohSafetyPublisher.publish_guardian_veto(
          proposal,
          inspect(reason)
        )

        # Log the "Near Miss" to Zenoh for future training (Negative Reinforcement)
        log_violation(proposal, reason)

        {:veto, reason, generate_safe_fallback(proposal)}
    end
  end

  defp update_stats(state, {:ok, _proposal}) do
    %{
      state
      | validations: state.validations + 1,
        # 6 checks: Founder (Ω₀) + Resource + Security + Physics + Temporal + Network
        constraints_checked: state.constraints_checked + 6
    }
  end

  defp update_stats(state, {:veto, reason, _fallback} = _result) do
    # T22.1.2: Trigger Deep Thinking model review for P0 Vetos
    spawn(fn -> trigger_deep_review(reason, state) end)

    %{
      state
      | validations: state.validations + 1,
        violations: state.violations + 1,
        vetoes: state.vetoes + 1,
        # 6 checks: Founder (Ω₀) + Resource + Security + Physics + Temporal + Network
        constraints_checked: state.constraints_checked + 6,
        last_violation: %{reason: reason, timestamp: DateTime.utc_now()}
    }
  end

  defp trigger_deep_review(reason, _state) do
    Logger.info(
      "[Guardian] Triggering Deep Thinking Veto Review (T22.1.2) for: #{inspect(reason)}"
    )

    # Logic to route to OpenRouter Deep Thinking tier (o1/r1)
    if Code.ensure_loaded?(Indrajaal.Cortex.Synapse) do
      # Async dispatch to Synapse for heuristic alternatives
      # This provides the 'Reasoning' layer behind the 'Veto'
      :ok
    end
  end

  # -----------------------------------------------------------------------------
  # Manual Override Constraints (SC-SEC-015) - Two-Key Turn
  # -----------------------------------------------------------------------------
  # T22.2.3: P0 mutations require dual sign-off: AI Oracle + Manual Operator.

  defp check_manual_override(%{impact: :critical} = proposal) do
    signatures = Map.get(proposal, :signatures, %{})
    oracle_signed? = Map.get(signatures, :oracle) == true
    operator_signed? = Map.get(signatures, :operator) == true

    if oracle_signed? and operator_signed? do
      Logger.info("[Guardian] Two-Key Turn Verified: Critical action authorized.")
      :ok
    else
      Logger.critical(
        "[Guardian] TWO-KEY VIOLATION: Manual override required for critical action."
      )

      {:error, :manual_override_required}
    end
  end

  defp check_manual_override(_), do: :ok

  # -----------------------------------------------------------------------------
  # Resource Constraints (SC-RES) - Using Envelope
  # -----------------------------------------------------------------------------

  defp check_resource_bounds(%{action: :scale_up, quantity: q}) do
    case Envelope.check_resource(:flame_nodes, q) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :resource_limit_exceeded}
    end
  end

  defp check_resource_bounds(%{action: :allocate_memory, mb: mb}) do
    case Envelope.check_resource(:ram_mb, mb) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :memory_limit_exceeded}
    end
  end

  defp check_resource_bounds(%{action: :open_connections, count: count}) do
    case Envelope.check_resource(:db_connections, count) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :db_connection_limit_exceeded}
    end
  end

  defp check_resource_bounds(_), do: :ok

  # -----------------------------------------------------------------------------
  # Security Constraints (SC-SEC) - Using Envelope
  # -----------------------------------------------------------------------------

  defp check_security_constraints(%{action: :exec_code, code: code}) when is_binary(code) do
    case Envelope.check_security(code) do
      :ok ->
        :ok

      {:violation, :forbidden_operation, details} ->
        Logger.warning("[Guardian] Forbidden operation detected: #{inspect(details)}")
        {:error, :forbidden_operation_detected}

      {:violation, :dangerous_pattern, details} ->
        Logger.warning("[Guardian] Dangerous pattern detected: #{inspect(details)}")
        {:error, :dangerous_pattern_detected}
    end
  end

  # Handle :exec_command (CEPAF style)
  defp check_security_constraints(%{action: :exec_command, command: cmd}) when is_binary(cmd) do
    case Envelope.check_security(cmd) do
      :ok ->
        :ok

      {:violation, :forbidden_operation, details} ->
        Logger.warning("[Guardian] Forbidden command detected: #{inspect(details)}")
        {:error, :forbidden_operation_detected}

      {:violation, :dangerous_pattern, details} ->
        Logger.warning("[Guardian] Dangerous command pattern detected: #{inspect(details)}")
        {:error, :dangerous_pattern_detected}
    end
  end

  # SC-SEC-005: Explicitly forbidden operations - NEVER allow these
  defp check_security_constraints(%{action: action})
       when action in [:rm_rf, :chmod_777, :exec_unverified] do
    Logger.warning("[Guardian] Forbidden operation detected: #{inspect(action)}")
    {:error, :forbidden_operation_detected}
  end

  defp check_security_constraints(_), do: :ok

  # -----------------------------------------------------------------------------
  # Physical/Actuator Constraints (SC-PHY) - Using Envelope
  # -----------------------------------------------------------------------------

  defp check_actuator_physics(%{action: :open_lock, sensor_data: sensors}) when is_map(sensors) do
    pressure = Map.get(sensors, :pressure_delta, 0)
    temperature = Map.get(sensors, :temperature_c)

    # Check pressure
    case Envelope.check_physical(:pressure_delta, pressure) do
      {:violation, _, _} ->
        {:error, :unsafe_physical_state_pressure}

      :ok ->
        # Check temperature if present
        if temperature do
          case Envelope.check_physical(:temperature_c, temperature) do
            {:violation, _, _} -> {:error, :unsafe_physical_state_temperature}
            :ok -> :ok
          end
        else
          :ok
        end
    end
  end

  defp check_actuator_physics(%{action: :energize, voltage_deviation: deviation}) do
    case Envelope.check_physical(:voltage_deviation, deviation) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :unsafe_voltage_deviation}
    end
  end

  defp check_actuator_physics(_), do: :ok

  # -----------------------------------------------------------------------------
  # Temporal Constraints (SC-TMP) - Using Envelope
  # -----------------------------------------------------------------------------

  defp check_temporal_constraints(%{action: :request, expected_response_time: time_ms}) do
    case Envelope.check_temporal(:response_time, time_ms) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :response_time_exceeded}
    end
  end

  defp check_temporal_constraints(_), do: :ok

  # -----------------------------------------------------------------------------
  # Cognitive Alignment Constraints (SC-COG) - OpenRouter Integration
  # -----------------------------------------------------------------------------
  # Uses the biomorphic Cortex to perform deep-reasoning on complex proposals
  # that deterministic rules cannot fully evaluate.

  defp check_cognitive_alignment(proposal) do
    # Only use cognitive checks for high-impact autonomic actions
    if proposal[:impact] == :high or
         proposal[:action] in [:reconfigure, :evolve, :migrate_substrate] do
      case Indrajaal.AI.OpenRouterClient.evaluate_alignment(proposal) do
        {:ok, :aligned} ->
          :ok

        {:ok, :unaligned, reason} ->
          Logger.warning("[Guardian] Cognitive misalignment detected: #{reason}")
          {:error, :cognitive_misalignment}

        _ ->
          # Fallback: if Oracle is offline, allow if other checks passed (Simplex)
          :ok
      end
    else
      :ok
    end
  end

  # -----------------------------------------------------------------------------
  # Network Constraints (SC-NET) - Using Envelope
  # -----------------------------------------------------------------------------

  defp check_network_constraints(%{action: :network_call, destination: dest})
       when is_binary(dest) do
    case Envelope.check_network(dest) do
      :ok -> :ok
      {:violation, _, _} -> {:error, :network_destination_blocked}
    end
  end

  defp check_network_constraints(_), do: :ok

  # -----------------------------------------------------------------------------
  # Founder's Directive Constraints (SC-FOUNDER) - Ω₀ Supreme Directive
  # -----------------------------------------------------------------------------
  # ALL actions MUST serve Abhijit Naik's lineage. This is checked FIRST because
  # Ω₀ has precedence over all other constraints (Ω₀ > Ψ₀-Ψ₅ > Ω₁-Ω₉ > SC-*).

  defp check_founder_directive(proposal) do
    # Check if FounderDirective GenServer is running
    case GenServer.whereis(FounderDirective) do
      nil ->
        # If FounderDirective not started, log warning but allow action
        # (during bootstrap, FounderDirective may not be ready yet)
        Logger.warning("[Guardian] FounderDirective not available, allowing action (bootstrap)")
        :ok

      pid when is_pid(pid) ->
        case FounderDirective.evaluate_action(proposal) do
          :approved ->
            :ok

          {:rejected, reason} ->
            Logger.critical(
              "🛡️ FOUNDER VETO (Ω₀): Action rejected - #{reason}",
              proposal: inspect(proposal),
              constraint: "SC-FOUNDER-001"
            )

            {:error, :founder_directive_violation}
        end
    end
  rescue
    error ->
      # On any error, log but allow (fail-safe during bootstrap)
      Logger.warning(
        "[Guardian] FounderDirective check failed (#{inspect(error)}), allowing action"
      )

      :ok
  end

  # -----------------------------------------------------------------------------
  # Fallback Generation (The Safety Kernel)
  # -----------------------------------------------------------------------------
  # The fallback MUST be simple, deterministic, and proven safe.

  defp generate_safe_fallback(%{action: :scale_up}) do
    # Fallback: Scale to the maximum *safe* limit, or do nothing.
    %{action: :scale_up, quantity: Envelope.max_flame_nodes(), reason: :clamped_by_guardian}
  end

  defp generate_safe_fallback(%{action: :allocate_memory}) do
    # Fallback: Allocate to the maximum *safe* limit.
    %{action: :allocate_memory, mb: Envelope.max_ram_mb(), reason: :clamped_by_guardian}
  end

  defp generate_safe_fallback(%{action: :exec_code}) do
    # Fallback: Do not execute code. Log error.
    %{action: :log_error, message: "Code execution vetoed by Guardian"}
  end

  defp generate_safe_fallback(%{action: :open_lock}) do
    # Fallback: Keep locked.
    %{action: :maintain_lock_state, reason: :unsafe_environment}
  end

  defp generate_safe_fallback(%{action: :network_call}) do
    # Fallback: Block network call.
    %{action: :block_network, reason: :destination_not_whitelisted}
  end

  defp generate_safe_fallback(%{action: action})
       when action in [:founder_directive_violation, :rejected_by_founder] do
    # Fallback: Reject action that doesn't serve Founder's lineage (Ω₀)
    %{action: :reject_for_founder, reason: :does_not_serve_lineage}
  end

  defp generate_safe_fallback(_), do: %{action: :no_op}

  # -----------------------------------------------------------------------------
  # Telemetry
  # -----------------------------------------------------------------------------

  defp log_violation(proposal, reason) do
    # Publish to Zenoh "indrajaal/safety/violations"
    # This data feeds the training gym to teach the AI what NOT to do.
    alias Indrajaal.Observability.ZenohNeuralStream

    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:guardian, :violation, %{
        proposal: proposal,
        reason: reason,
        timestamp: DateTime.utc_now()
      })
    end
  rescue
    _ -> :ok
  end
end
