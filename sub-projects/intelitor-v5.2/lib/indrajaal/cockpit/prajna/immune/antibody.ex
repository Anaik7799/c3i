defmodule Indrajaal.Cockpit.Prajna.Immune.Antibody do
  @moduledoc """
  ## The Antibody Agent (SIL-4 Enhanced)

  Ephemeral agent spawned to hunt specific anomalies (Antigens).
  Implements the full immune response lifecycle for threat neutralization.

  ## Lifecycle Phases
  1. **Search** - Scan metrics for patterns matching search_image
  2. **Bind** - Lock onto target antigen process/resource
  3. **Opsonize** - Tag target for T-Cell (Guardian) intervention
  4. **Die** - Clean up and report findings

  ## STAMP Constraints
  - SC-IMMUNE-001: Cannot kill directly; must flag for T-Cells
  - SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
  - SC-IMMUNE-006: Quarantine uses `:sys.suspend/1` not `:erlang.exit/2`
  - SC-IMMUNE-007: Response time requirements per severity

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-27 |
  | Updated | 2026-01-01 |
  | Author | Cybernetic Architect |
  | STAMP | SC-IMMUNE-001, SC-IMMUNE-002, SC-IMMUNE-006, SC-IMMUNE-007 |
  """
  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.SentinelBridge

  @default_ttl_seconds 300
  @hunt_interval_ms 1000
  @max_bind_attempts 3

  # Telemetry event prefixes for phase transitions
  @telemetry_prefix [:indrajaal, :prajna, :immune, :antibody]

  defstruct [
    :search_image,
    :target_id,
    :target_pid,
    :ttl,
    :phase,
    :created_at,
    :bound_at,
    :opsonized_at,
    :findings,
    :bind_attempts,
    # Track processes we've quarantined for cleanup
    :quarantined_pids
  ]

  @type phase :: :searching | :binding | :opsonizing | :dying | :dead
  @type search_image :: %{
          required(:pattern) => Regex.t() | String.t() | atom(),
          optional(:severity) => atom(),
          optional(:metric_type) => atom(),
          optional(:threshold) => number()
        }

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Spawn a new Antibody to hunt for a specific pattern"
  @spec spawn_hunter(search_image()) :: {:ok, pid()} | {:error, term()}
  def spawn_hunter(search_image) do
    DynamicSupervisor.start_child(
      Indrajaal.Cockpit.Prajna.Immune.AntibodySupervisor,
      {__MODULE__, search_image}
    )
  end

  def start_link(search_image) do
    GenServer.start_link(__MODULE__, search_image)
  end

  @doc "Get current status of an Antibody agent"
  @spec status(pid()) :: map()
  def status(pid) do
    GenServer.call(pid, :status)
  end

  @doc "Force transition to dying phase"
  @spec terminate_hunt(pid()) :: :ok
  def terminate_hunt(pid) do
    GenServer.cast(pid, :terminate_hunt)
  end

  @doc "Bind to a target process (for external use)"
  @spec bind(pid()) :: :ok
  def bind(target) when is_pid(target) do
    # SC-IMMUNE-002: Check if target is a kernel process before binding
    if kernel_process?(target) do
      Logger.warning("[Antibody] Refusing to bind to critical process: #{inspect(target)}")
      :ok
    else
      Logger.debug("[Antibody] External bind request for: #{inspect(target)}")
      :ok
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(search_image) do
    # Start hunting immediately
    send(self(), :hunt)

    Logger.info("[Antibody:#{short_id()}] Spawned with search image: #{inspect(search_image)}")

    state = %__MODULE__{
      search_image: search_image,
      ttl: Map.get(search_image, :ttl, @default_ttl_seconds),
      phase: :searching,
      created_at: DateTime.utc_now(),
      findings: [],
      bind_attempts: 0,
      quarantined_pids: []
    }

    # Emit telemetry for spawn event
    emit_telemetry(:spawn, %{search_image: search_image}, state)

    # Schedule TTL expiration
    Process.send_after(self(), :ttl_expired, state.ttl * 1000)

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      phase: state.phase,
      search_image: state.search_image,
      target_id: state.target_id,
      ttl_remaining: calculate_ttl_remaining(state),
      findings_count: length(state.findings),
      bind_attempts: state.bind_attempts
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:terminate_hunt, state) do
    Logger.info("[Antibody:#{short_id()}] Forced termination requested")
    {:noreply, transition_to_dying(state, :forced_termination)}
  end

  @impl true
  def handle_info(:hunt, %{phase: :searching} = state) do
    case search_for_antigen(state.search_image) do
      {:found, target_id, target_data} ->
        Logger.info("[Antibody:#{short_id()}] Antigen found: #{target_id}")
        new_state = %{state | target_id: target_id, phase: :binding}

        # Emit telemetry for phase transition
        emit_telemetry(
          :phase_transition,
          %{from: :searching, to: :binding, target_id: target_id},
          new_state
        )

        send(self(), :bind)
        {:noreply, %{new_state | findings: [{:found, target_id, target_data} | state.findings]}}

      :not_found ->
        # Continue hunting
        Process.send_after(self(), :hunt, @hunt_interval_ms)
        {:noreply, state}
    end
  end

  def handle_info(:hunt, state) do
    # Not in searching phase, ignore
    {:noreply, state}
  end

  @impl true
  def handle_info(:bind, %{phase: :binding} = state) do
    case bind_to_target(state.target_id) do
      {:ok, target_pid} ->
        Logger.info("[Antibody:#{short_id()}] Bound to target: #{inspect(target_pid)}")

        new_state = %{
          state
          | target_pid: target_pid,
            phase: :opsonizing,
            bound_at: DateTime.utc_now()
        }

        # Emit telemetry for phase transition
        emit_telemetry(
          :phase_transition,
          %{from: :binding, to: :opsonizing, target_pid: target_pid},
          new_state
        )

        send(self(), :opsonize)
        {:noreply, new_state}

      {:error, reason} when state.bind_attempts < @max_bind_attempts ->
        Logger.warning(
          "[Antibody:#{short_id()}] Bind attempt #{state.bind_attempts + 1} failed: #{reason}"
        )

        # Emit telemetry for bind retry
        emit_telemetry(:bind_retry, %{attempt: state.bind_attempts + 1, reason: reason}, state)

        Process.send_after(self(), :bind, 500)
        {:noreply, %{state | bind_attempts: state.bind_attempts + 1}}

      {:error, reason} ->
        Logger.warning("[Antibody:#{short_id()}] Max bind attempts reached: #{reason}")
        {:noreply, transition_to_dying(state, {:bind_failed, reason})}
    end
  end

  def handle_info(:bind, state), do: {:noreply, state}

  @impl true
  def handle_info(:opsonize, %{phase: :opsonizing} = state) do
    case opsonize_target_with_state(state) do
      {:ok, updated_state} ->
        Logger.info("[Antibody:#{short_id()}] Target opsonized, flagged for T-Cell")

        new_state = %{updated_state | opsonized_at: DateTime.utc_now()}

        # Emit telemetry for successful opsonization
        emit_telemetry(
          :phase_transition,
          %{from: :opsonizing, to: :dying, reason: :mission_complete},
          new_state
        )

        {:noreply, transition_to_dying(new_state, :mission_complete)}

      {:error, reason} ->
        Logger.warning("[Antibody:#{short_id()}] Opsonization failed: #{reason}")
        {:noreply, transition_to_dying(state, {:opsonize_failed, reason})}
    end
  end

  def handle_info(:opsonize, state), do: {:noreply, state}

  @impl true
  def handle_info(:die, %{phase: :dying} = state) do
    # SC-IMMUNE-006: Cleanup quarantined processes (resume suspended)
    cleanup_quarantined_processes(state)

    # Final cleanup and reporting
    report_findings(state)

    # Emit telemetry for death
    emit_telemetry(
      :phase_transition,
      %{from: :dying, to: :dead, success: state.opsonized_at != nil},
      state
    )

    emit_telemetry(:die, %{lifecycle_duration_ms: calculate_lifecycle_duration(state)}, state)

    Logger.info("[Antibody:#{short_id()}] Antibody lifecycle complete")
    {:stop, :normal, %{state | phase: :dead}}
  end

  def handle_info(:die, state), do: {:noreply, state}

  def handle_info(:ttl_expired, state) do
    if state.phase != :dead do
      Logger.info("[Antibody:#{short_id()}] TTL expired in phase: #{state.phase}")
      {:noreply, transition_to_dying(state, :ttl_expired)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    # SC-IMMUNE-006: Always cleanup quarantined processes on termination
    # This ensures processes are resumed even if we crash unexpectedly
    cleanup_quarantined_processes(state)

    # Emit termination telemetry
    emit_telemetry(:terminate, %{reason: reason, phase: state.phase}, state)

    Logger.debug("[Antibody:#{short_id()}] Terminated with reason: #{inspect(reason)}")
    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 1: SEARCH - Scan for antigens matching the search image
  # ═══════════════════════════════════════════════════════════════════════════

  defp search_for_antigen(search_image) do
    # SIL-4 FIX: Gracefully handle missing SmartMetrics (test environment)
    metrics =
      try do
        case Process.whereis(SmartMetrics) do
          nil ->
            # SmartMetrics not running - return empty list
            []

          _pid ->
            SmartMetrics.all()
        end
      rescue
        ArgumentError ->
          # ETS table doesn't exist
          Logger.debug("[Antibody] SmartMetrics ETS table not available")
          []
      catch
        _, _ ->
          []
      end

    found =
      Enum.find(metrics, fn {metric_id, metric} ->
        matches_search_image?(metric_id, metric, search_image)
      end)

    case found do
      {target_id, target_data} -> {:found, target_id, target_data}
      nil -> :not_found
    end
  end

  defp matches_search_image?(metric_id, metric, search_image) do
    pattern_match =
      case search_image do
        %{pattern: %Regex{} = regex} ->
          Regex.match?(regex, metric_id)

        %{pattern: pattern} when is_binary(pattern) ->
          String.contains?(metric_id, pattern)

        %{pattern: pattern} when is_atom(pattern) ->
          String.contains?(metric_id, to_string(pattern))

        _ ->
          false
      end

    severity_match =
      case search_image do
        %{severity: severity} -> metric.level == severity
        _ -> true
      end

    threshold_match =
      case search_image do
        %{threshold: threshold} when is_number(threshold) ->
          is_number(metric.value) and metric.value >= threshold

        _ ->
          true
      end

    pattern_match and severity_match and threshold_match
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 2: BIND - Lock onto the target resource/process
  # ═══════════════════════════════════════════════════════════════════════════

  defp bind_to_target(target_id) do
    # Attempt to identify the source process for this metric
    # In a real system, this would look up the process registry
    case lookup_metric_source(target_id) do
      {:ok, pid} when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, :process_dead}
        end

      {:ok, :no_process} ->
        # Metric exists but no associated process (e.g., system metric)
        {:ok, :no_process}

      :not_found ->
        {:error, :metric_not_found}
    end
  end

  defp lookup_metric_source(target_id) do
    # In a real implementation, this would:
    # 1. Check a process registry
    # 2. Look up the metric's source in SmartMetrics metadata
    # 3. Return the owning process

    # Check if SmartMetrics has this target
    try do
      case Process.whereis(SmartMetrics) do
        nil ->
          :not_found

        _pid ->
          metrics = SmartMetrics.all()

          if Enum.any?(metrics, fn {id, _} -> String.contains?(to_string(id), target_id) end) do
            {:ok, :no_process}
          else
            :not_found
          end
      end
    rescue
      _ -> :not_found
    catch
      _, _ -> :not_found
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 3: OPSONIZE - Tag target for Guardian/T-Cell intervention
  # ═══════════════════════════════════════════════════════════════════════════

  defp opsonize_target_with_state(state) do
    # SC-IMMUNE-001: Cannot kill directly; must flag for T-Cells
    # SC-IMMUNE-002: Never terminate kernel processes
    # SC-IMMUNE-006: Use :sys.suspend/1 for quarantine, not :erlang.exit/2

    try do
      # 1. Tag via Membrane (if available)
      tag_via_membrane(state.target_id, state.target_pid)

      # 2. Report to Sentinel for threat tracking
      report_threat_to_sentinel(state.target_id, state.search_image)

      # 3. Optionally quarantine via suspension (not termination!)
      # Returns list of quarantined PIDs for later cleanup
      quarantined = maybe_quarantine_with_tracking(state.target_pid, state.search_image)

      updated_state = %{state | quarantined_pids: quarantined ++ (state.quarantined_pids || [])}

      {:ok, updated_state}
    rescue
      e ->
        {:error, Exception.message(e)}
    catch
      _, reason ->
        {:error, inspect(reason)}
    end
  end

  defp tag_via_membrane(target_id, _target_pid) do
    # Tag the metric/resource as compromised
    membrane_module = Indrajaal.Cockpit.Prajna.Bio.Membrane

    if Code.ensure_loaded?(membrane_module) and function_exported?(membrane_module, :tag, 2) do
      # Using apply() intentionally - function may not exist at compile time
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(membrane_module, :tag, [target_id, :compromised])
    else
      # Fallback: broadcast the tag via PubSub
      safe_broadcast("prajna:immune", {:tagged, target_id, :compromised})
    end
  end

  defp report_threat_to_sentinel(target_id, search_image) do
    if Process.whereis(SentinelBridge) do
      # Build threat report
      threat = %{
        type: :antibody_detection,
        target: target_id,
        severity: Map.get(search_image, :severity, :warning),
        pattern: inspect(Map.get(search_image, :pattern)),
        timestamp: DateTime.utc_now()
      }

      # Log for audit (SC-IMMUNE-003)
      Logger.info("[Antibody→Sentinel] Threat reported: #{inspect(threat)}")

      # Trigger Sentinel sync to pick up the threat
      SentinelBridge.sync_now()
    end
  end

  # Quarantine function that tracks quarantined PIDs for cleanup
  defp maybe_quarantine_with_tracking(target_pid, search_image) when is_pid(target_pid) do
    severity = Map.get(search_image, :severity, :warning)

    # SC-IMMUNE-006: Use :sys.suspend/1 not :erlang.exit/2
    # Only quarantine for critical/high severity threats
    if severity in [:critical, :high] and Process.alive?(target_pid) do
      # Check it's not a kernel process (SC-IMMUNE-002)
      if not kernel_process?(target_pid) do
        Logger.warning("[Antibody] Quarantining process: #{inspect(target_pid)}")

        # Use :sys.suspend for safe quarantine
        try do
          :sys.suspend(target_pid)
          safe_broadcast("prajna:immune", {:quarantined, target_pid})
          # Return the PID for tracking
          [target_pid]
        rescue
          _ -> []
        catch
          _, _ -> []
        end
      else
        []
      end
    else
      []
    end
  end

  defp maybe_quarantine_with_tracking(:no_process, _search_image), do: []
  defp maybe_quarantine_with_tracking(nil, _search_image), do: []

  # SIL-4 FIX: Expanded whitelist for safety-critical processes
  # SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
  # SC-SIL4-001: Safety functions must never be suspended
  @kernel_processes [
    # Erlang/OTP Core
    :init,
    :kernel_sup,
    :code_server,
    :file_server_2,
    :application_controller,
    :erl_prim_loader,
    :logger,
    :logger_std_h,
    :logger_sup,
    :global_name_server,
    :inet_db,
    :net_kernel,
    :rex,
    :user,
    :user_drv,
    :standard_error,
    :standard_error_sup
  ]

  # SIL-4 FIX: Safety-critical Indrajaal processes that must NEVER be suspended
  @safety_critical_processes [
    # Guardian and Safety Layer
    Indrajaal.Safety.Guardian,
    Indrajaal.Safety.Sentinel,
    Indrajaal.Safety.PatternHunter,
    Indrajaal.Safety.SymbioticDefense,
    # Prajna Core
    Indrajaal.Cockpit.Prajna.Supervisor,
    Indrajaal.Cockpit.Prajna.Orchestrator,
    Indrajaal.Cockpit.Prajna.SmartMetrics,
    Indrajaal.Cockpit.Prajna.SentinelBridge,
    Indrajaal.Cockpit.Prajna.PrometheusVerifier,
    Indrajaal.Cockpit.Prajna.ImmutableState,
    Indrajaal.Cockpit.Prajna.ConstitutionalChecker,
    Indrajaal.Cockpit.Prajna.GuardianIntegration,
    # Holon Core
    Indrajaal.Core.Holon.FounderDirective,
    Indrajaal.Core.Holon.ImmutableRegister,
    Indrajaal.Core.Constitution.Verifier,
    # Application Core
    Indrajaal.Application,
    Indrajaal.Supervisor,
    Indrajaal.Repo,
    Indrajaal.PubSub
  ]

  defp kernel_process?(pid) do
    # Check if this is a critical system process that should never be suspended
    # SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) ->
        name in @kernel_processes or name in @safety_critical_processes

      _ ->
        # Also check by module if not registered
        check_by_initial_call(pid)
    end
  end

  defp check_by_initial_call(pid) do
    # Check initial call to identify safety-critical GenServers
    case Process.info(pid, :initial_call) do
      {:initial_call, {module, _func, _arity}} ->
        module in @safety_critical_processes

      _ ->
        false
    end
  end

  @doc """
  Checks if a process is in the safety whitelist.
  Call this before any quarantine action.
  """
  @spec safety_whitelisted?(pid()) :: boolean()
  def safety_whitelisted?(pid) do
    kernel_process?(pid)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 4: DIE - Cleanup and reporting
  # ═══════════════════════════════════════════════════════════════════════════

  # Cleanup quarantined processes by resuming them.
  # SC-IMMUNE-006: Processes are quarantined with :sys.suspend/1, not :erlang.exit/2.
  # This function resumes all suspended processes to ensure they are not left in limbo.
  defp cleanup_quarantined_processes(%{quarantined_pids: nil}), do: :ok
  defp cleanup_quarantined_processes(%{quarantined_pids: []}), do: :ok

  defp cleanup_quarantined_processes(%{quarantined_pids: quarantined_pids})
       when is_list(quarantined_pids) do
    Enum.each(quarantined_pids, fn pid ->
      resume_quarantined_process(pid)
    end)

    :ok
  end

  defp cleanup_quarantined_processes(_state), do: :ok

  defp resume_quarantined_process(pid) when is_pid(pid) do
    # SC-IMMUNE-006: Resume suspended processes on cleanup
    # Only resume if the process is still alive
    if Process.alive?(pid) do
      try do
        :sys.resume(pid)
        safe_broadcast("prajna:immune", {:released, pid})
        Logger.info("[Antibody:#{short_id()}] Released quarantined process: #{inspect(pid)}")
      rescue
        e ->
          Logger.warning(
            "[Antibody:#{short_id()}] Failed to resume #{inspect(pid)}: #{Exception.message(e)}"
          )
      catch
        _, reason ->
          Logger.warning(
            "[Antibody:#{short_id()}] Failed to resume #{inspect(pid)}: #{inspect(reason)}"
          )
      end
    else
      Logger.debug(
        "[Antibody:#{short_id()}] Quarantined process #{inspect(pid)} already dead, no cleanup needed"
      )
    end
  end

  defp resume_quarantined_process(_), do: :ok

  defp transition_to_dying(state, reason) do
    Logger.info("[Antibody:#{short_id()}] Transitioning to dying phase: #{inspect(reason)}")

    new_state = %{
      state
      | phase: :dying,
        findings: [{:termination_reason, reason} | state.findings]
    }

    # Emit telemetry for transition to dying
    emit_telemetry(:phase_transition, %{from: state.phase, to: :dying, reason: reason}, new_state)

    # Schedule death
    Process.send_after(self(), :die, 100)
    new_state
  end

  defp report_findings(state) do
    report = %{
      antibody_id: short_id(),
      search_image: state.search_image,
      target_id: state.target_id,
      lifecycle_duration_ms: calculate_lifecycle_duration(state),
      phases_completed: phases_completed(state),
      findings: state.findings,
      success: state.opsonized_at != nil
    }

    # Broadcast findings for analysis
    safe_broadcast("prajna:immune", {:antibody_report, report})

    # Log summary
    Logger.info("[Antibody:#{short_id()}] Report: #{inspect(report, limit: 5)}")
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp short_id do
    self()
    |> :erlang.pid_to_list()
    |> List.to_string()
    |> String.slice(-8, 8)
  end

  defp calculate_ttl_remaining(state) do
    elapsed = DateTime.diff(DateTime.utc_now(), state.created_at, :second)
    max(0, state.ttl - elapsed)
  end

  defp calculate_lifecycle_duration(state) do
    DateTime.diff(DateTime.utc_now(), state.created_at, :millisecond)
  end

  defp phases_completed(state) do
    phases = [:searching]
    phases = if state.target_id, do: [:binding | phases], else: phases
    phases = if state.bound_at, do: [:binding_complete | phases], else: phases
    phases = if state.opsonized_at, do: [:opsonizing | phases], else: phases
    Enum.reverse(phases)
  end

  defp safe_broadcast(topic, message) do
    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, message)
    rescue
      ArgumentError -> :ok
    catch
      _, _ -> :ok
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # TELEMETRY
  # ═══════════════════════════════════════════════════════════════════════════

  defp emit_telemetry(event, measurements, state) do
    event_name = @telemetry_prefix ++ [event]

    metadata = %{
      antibody_id: short_id(),
      phase: state.phase,
      search_image: state.search_image,
      target_id: state.target_id
    }

    try do
      :telemetry.execute(event_name, measurements, metadata)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end
end
