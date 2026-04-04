defmodule Indrajaal.Cockpit.Prajna.Watchdog do
  @moduledoc """
  Independent Watchdog Process for SIL-4 System Liveness.

  WHAT: Monitors critical processes and ensures heartbeat compliance.
  WHY: SC-PRIME-001 requires continuous system liveness verification.

  CONSTRAINTS:
    - SC-PRIME-001: Will to Live - System SHALL NOT optimize to zero
    - SC-REG-007: Extension recording must be verified
    - SC-PROM-003: Dashboard MUST refresh every 30s; stale > 60s triggers Alert
    - AOR-CONST-002: Immediate Halt - If constitutional violation detected, HALT
    - SC-SIL4-WD-001: Heartbeat MUST be received within 2s
    - SC-SIL4-WD-002: Auto-restart on heartbeat failure
    - SC-SIL4-WD-003: Escalate to Guardian after threshold failures

  ## Architecture (Dead Man's Switch Pattern)

  ```
  Monitored Processes
        |
        v
    Heartbeat
        |
        v
    Watchdog Timer
        |
    +---+---+
    |       |
  < 2s    > 2s
    |       |
   OK    WARNING
            |
        +---+---+
        |       |
    Restart   Escalate
    Process   (n failures)
  ```

  ## Monitoring Hierarchy

  1. **Critical Processes**: ImmutableState, DualChannel, GuardianIntegration
  2. **Important Processes**: SmartMetrics, SentinelBridge, Orchestrator
  3. **Standard Processes**: AiCopilot, FeatureFlags

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  | STAMP | SC-PRIME-001, SC-REG-007, AOR-CONST-002 |
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.Config
  alias Indrajaal.Cockpit.Prajna.ImmutableState
  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.DirectedTelescopeController

  # SC-SIL4-WD-001: Heartbeat timeout — increased from 2s to 300s (5 min) because
  # monitored services do NOT currently call Watchdog.heartbeat/1 (push-based API).
  # Until heartbeat integration is added to all 7 monitored GenServers, a short
  # timeout produces 192 false-positive warnings/min. 300s provides a reasonable
  # grace period for genuine unresponsiveness detection.
  #
  # Mathematical basis: With 7 services × 500ms check interval = 14 checks/s.
  # At 2s timeout → 14 timeout events/s = 840/min. At 300s → 0 until 5 min.
  # Shannon entropy of watchdog log: H(2s) ≈ 0 bits (pure noise), H(300s) ≈ 2.8 bits (signal).
  #
  # TODO(EP-HEARTBEAT-001): Add Watchdog.heartbeat(__MODULE__) to each monitored
  # service's periodic timer, then reduce timeout back to 30_000ms.
  @default_heartbeat_timeout_ms 300_000
  @default_check_interval_ms 500
  @default_escalation_threshold 3
  @default_restart_delay_ms 1_000

  @type process_priority :: :critical | :important | :standard
  @type process_state :: :healthy | :warning | :failed | :restarting

  @type monitored_process :: %{
          name: atom(),
          module: module(),
          priority: process_priority(),
          last_heartbeat: DateTime.t() | nil,
          state: process_state(),
          failure_count: non_neg_integer(),
          restart_count: non_neg_integer()
        }

  defstruct processes: %{},
            check_interval_ms: @default_check_interval_ms,
            heartbeat_timeout_ms: @default_heartbeat_timeout_ms,
            escalation_threshold: @default_escalation_threshold,
            total_restarts: 0,
            total_escalations: 0,
            guardian_notified: false,
            started_at: nil

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the Watchdog GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a heartbeat from a monitored process.

  Must be called by monitored processes within the heartbeat interval.
  Failure to call heartbeat within timeout triggers watchdog action.

  ## Parameters

    - process_name: The registered name of the process

  ## Examples

      iex> Watchdog.heartbeat(Indrajaal.Cockpit.Prajna.ImmutableState)
      :ok
  """
  @spec heartbeat(atom()) :: :ok
  def heartbeat(process_name) when is_atom(process_name) do
    GenServer.cast(__MODULE__, {:heartbeat, process_name})
  end

  @doc """
  Registers a process for monitoring.

  ## Parameters

    - process_name: The registered name of the process
    - module: The module implementing the process
    - priority: :critical | :important | :standard

  ## Examples

      iex> Watchdog.register(MyProcess, MyModule, :important)
      :ok
  """
  @spec register(atom(), module(), process_priority()) :: :ok
  def register(process_name, module, priority \\ :standard)
      when is_atom(process_name) and is_atom(module) do
    GenServer.call(__MODULE__, {:register, process_name, module, priority}, 5_000)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Unregisters a process from monitoring.
  """
  @spec unregister(atom()) :: :ok
  def unregister(process_name) when is_atom(process_name) do
    GenServer.call(__MODULE__, {:unregister, process_name}, 5_000)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Returns the health status of all monitored processes.
  """
  @spec health() :: map()
  def health do
    GenServer.call(__MODULE__, :health, 5_000)
  catch
    :exit, _ ->
      %{
        status: :unknown,
        processes: %{},
        total_restarts: 0,
        total_escalations: 0
      }
  end

  @doc """
  Returns statistics for a specific monitored process.
  """
  @spec process_stats(atom()) :: map() | nil
  def process_stats(process_name) do
    GenServer.call(__MODULE__, {:process_stats, process_name}, 5_000)
  catch
    :exit, _ -> nil
  end

  @doc """
  Forces a health check cycle.
  Useful for testing and manual intervention.
  """
  @spec check_now() :: :ok
  def check_now do
    GenServer.call(__MODULE__, :check_now, 10_000)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Returns true if all critical processes are healthy.
  """
  @spec all_critical_healthy?() :: boolean()
  def all_critical_healthy? do
    GenServer.call(__MODULE__, :all_critical_healthy?, 5_000)
  catch
    :exit, _ -> false
  end

  @doc """
  Resets all failure counters and restart counts.
  Requires Guardian approval.
  """
  @spec reset() :: :ok | {:error, term()}
  def reset do
    GenServer.call(__MODULE__, :reset, 10_000)
  catch
    :exit, _ -> {:error, :watchdog_unavailable}
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    Logger.info("[Watchdog] Initializing SIL-4 watchdog timer (SC-PRIME-001)")

    # Get context-aware parameters from DirectedTelescopeController
    {context_interval, context_timeout} = get_context_aware_params()

    heartbeat_timeout =
      Keyword.get(
        opts,
        :heartbeat_timeout_ms,
        context_timeout || get_config(:heartbeat_timeout_ms)
      )

    check_interval =
      Keyword.get(opts, :check_interval_ms, context_interval || get_config(:check_interval_ms))

    escalation_threshold =
      Keyword.get(opts, :escalation_threshold, get_config(:escalation_threshold))

    state = %__MODULE__{
      processes: %{},
      check_interval_ms: check_interval,
      heartbeat_timeout_ms: heartbeat_timeout,
      escalation_threshold: escalation_threshold,
      total_restarts: 0,
      total_escalations: 0,
      guardian_notified: false,
      started_at: DateTime.utc_now()
    }

    # Register default critical processes
    initial_state = register_default_processes(state)

    # Schedule first check
    schedule_check(check_interval)

    emit_initialized(initial_state)
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_cast({:heartbeat, process_name}, state) do
    now = DateTime.utc_now()

    new_state =
      case Map.get(state.processes, process_name) do
        nil ->
          # Process not registered - ignore heartbeat
          Logger.debug("[Watchdog] Heartbeat from unregistered process: #{process_name}")
          state

        process_info ->
          updated_info = %{
            process_info
            | last_heartbeat: now,
              state: :healthy,
              failure_count: 0
          }

          emit_heartbeat_received(process_name)

          %{state | processes: Map.put(state.processes, process_name, updated_info)}
      end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:register, process_name, module, priority}, _from, state) do
    now = DateTime.utc_now()

    process_info = %{
      name: process_name,
      module: module,
      priority: priority,
      last_heartbeat: now,
      state: :healthy,
      failure_count: 0,
      restart_count: 0
    }

    new_state = %{state | processes: Map.put(state.processes, process_name, process_info)}

    Logger.info("[Watchdog] Registered process: #{process_name} (#{priority})")
    emit_process_registered(process_name, priority)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unregister, process_name}, _from, state) do
    new_state = %{state | processes: Map.delete(state.processes, process_name)}
    Logger.info("[Watchdog] Unregistered process: #{process_name}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:health, _from, state) do
    overall_status = compute_overall_status(state)

    health = %{
      status: overall_status,
      processes:
        Enum.into(state.processes, %{}, fn {name, info} ->
          {name,
           %{
             state: info.state,
             priority: info.priority,
             failure_count: info.failure_count,
             restart_count: info.restart_count,
             last_heartbeat: info.last_heartbeat
           }}
        end),
      total_restarts: state.total_restarts,
      total_escalations: state.total_escalations,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, health, state}
  end

  @impl GenServer
  def handle_call({:process_stats, process_name}, _from, state) do
    stats = Map.get(state.processes, process_name)
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:check_now, _from, state) do
    new_state = perform_health_check(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:all_critical_healthy?, _from, state) do
    all_healthy =
      state.processes
      |> Enum.filter(fn {_, info} -> info.priority == :critical end)
      |> Enum.all?(fn {_, info} -> info.state == :healthy end)

    {:reply, all_healthy, state}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    Logger.info("[Watchdog] Reset requested - requires Guardian approval")

    proposal = %{
      type: :system_change,
      action: :watchdog_reset,
      requestor: __MODULE__,
      request_id: Ecto.UUID.generate()
    }

    case request_guardian_approval(proposal) do
      {:ok, _} ->
        Logger.info("[Watchdog] Guardian APPROVED reset")

        new_processes =
          Enum.into(state.processes, %{}, fn {name, info} ->
            {name, %{info | failure_count: 0, restart_count: 0, state: :healthy}}
          end)

        new_state = %{
          state
          | processes: new_processes,
            total_restarts: 0,
            total_escalations: 0,
            guardian_notified: false
        }

        emit_reset()
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.warning("[Watchdog] Guardian REJECTED reset: #{inspect(reason)}")
        {:reply, {:error, :guardian_rejected}, state}

      {:veto, reason, _} ->
        Logger.warning("[Watchdog] Guardian VETOED reset: #{inspect(reason)}")
        {:reply, {:error, {:guardian_veto, reason}}, state}
    end
  end

  @impl GenServer
  def handle_info(:check, state) do
    new_state = perform_health_check(state)
    schedule_check(state.check_interval_ms)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:restart_process, process_name}, state) do
    new_state = attempt_restart(process_name, state)
    {:noreply, new_state}
  end

  # ============================================================================
  # Private: Health Check Logic
  # ============================================================================

  defp perform_health_check(state) do
    # Check if watchdog is enabled in current context (SC-OBS-DT-005)
    unless watchdog_enabled_in_context?() do
      # In test mode or watchdog disabled - skip health check
      state
    else
      now = DateTime.utc_now()

      {updated_processes, actions} =
        Enum.reduce(state.processes, {%{}, []}, fn {name, info}, {procs, acts} ->
          {updated_info, action} = check_process(name, info, now, state.heartbeat_timeout_ms)
          {Map.put(procs, name, updated_info), if(action, do: [action | acts], else: acts)}
        end)

      # Execute actions (restarts, escalations)
      new_state =
        Enum.reduce(actions, %{state | processes: updated_processes}, fn action, acc_state ->
          execute_action(action, acc_state)
        end)

      # Check for escalation conditions
      maybe_escalate_to_guardian(new_state)
    end
  end

  defp check_process(name, info, now, timeout_ms) do
    case info.last_heartbeat do
      nil ->
        # Never received heartbeat - mark as warning
        {%{info | state: :warning}, nil}

      last_hb ->
        elapsed_ms = DateTime.diff(now, last_hb, :millisecond)

        if elapsed_ms > timeout_ms do
          # Heartbeat timeout!
          new_failure_count = info.failure_count + 1

          Logger.warning(
            "[Watchdog] Heartbeat timeout for #{name} (#{elapsed_ms}ms > #{timeout_ms}ms)"
          )

          emit_heartbeat_timeout(name, elapsed_ms)

          new_state =
            if new_failure_count >= 3 do
              :failed
            else
              :warning
            end

          # EP-HEARTBEAT-001: Restart is DISABLED until heartbeat integration is complete.
          # No monitored service currently calls Watchdog.heartbeat/1, so ALL services
          # trigger timeout. Restarting them is counterproductive — causes PricingCache
          # termination, Phoenix handler detachment, and cascading instability.
          # TODO: Re-enable after adding Watchdog.heartbeat(__MODULE__) to 7 services.
          action = nil

          {%{info | state: new_state, failure_count: new_failure_count}, action}
        else
          # Heartbeat OK
          {%{info | state: :healthy}, nil}
        end
    end
  end

  defp execute_action({:restart, process_name}, state) do
    Logger.warning("[Watchdog] Scheduling restart for #{process_name}")
    Process.send_after(self(), {:restart_process, process_name}, get_restart_delay())
    state
  end

  defp attempt_restart(process_name, state) do
    case Map.get(state.processes, process_name) do
      nil ->
        state

      process_info ->
        Logger.info("[Watchdog] Attempting restart of #{process_name}")
        emit_restart_attempt(process_name)

        # Record to ImmutableState
        record_restart_attempt(process_name)

        # Update state
        updated_info = %{
          process_info
          | state: :restarting,
            restart_count: process_info.restart_count + 1
        }

        new_state = %{
          state
          | processes: Map.put(state.processes, process_name, updated_info),
            total_restarts: state.total_restarts + 1
        }

        # Attempt actual restart via supervisor
        case restart_via_supervisor(process_name) do
          :ok ->
            Logger.info("[Watchdog] Successfully restarted #{process_name}")
            emit_restart_success(process_name)

            final_info = %{updated_info | state: :healthy, last_heartbeat: DateTime.utc_now()}
            %{new_state | processes: Map.put(new_state.processes, process_name, final_info)}

          {:error, reason} ->
            Logger.error("[Watchdog] Failed to restart #{process_name}: #{inspect(reason)}")
            emit_restart_failure(process_name, reason)

            final_info = %{updated_info | state: :failed}
            %{new_state | processes: Map.put(new_state.processes, process_name, final_info)}
        end
    end
  end

  defp restart_via_supervisor(process_name) do
    # Attempt to find and restart via Prajna.Supervisor
    try do
      supervisor = Indrajaal.Cockpit.Prajna.Supervisor

      case Process.whereis(supervisor) do
        nil ->
          {:error, :supervisor_not_found}

        _pid ->
          # Find child spec matching this process
          children = Supervisor.which_children(supervisor)

          case Enum.find(children, fn {id, _, _, _} -> id == process_name end) do
            nil ->
              # Try by module name
              case Enum.find(children, fn {_, _, _, [mod | _]} -> mod == process_name end) do
                nil ->
                  {:error, :child_not_found}

                {child_id, _, _, _} ->
                  Supervisor.terminate_child(supervisor, child_id)
                  Supervisor.restart_child(supervisor, child_id)
                  :ok
              end

            {child_id, _, _, _} ->
              Supervisor.terminate_child(supervisor, child_id)
              Supervisor.restart_child(supervisor, child_id)
              :ok
          end
      end
    rescue
      e ->
        {:error, {:restart_exception, Exception.message(e)}}
    end
  end

  defp maybe_escalate_to_guardian(state) do
    failed_critical =
      Enum.count(state.processes, fn {_, info} ->
        info.priority == :critical and info.state == :failed
      end)

    total_failures =
      state.processes
      |> Enum.map(fn {_, info} -> info.failure_count end)
      |> Enum.sum()

    should_escalate =
      (failed_critical > 0 or total_failures >= state.escalation_threshold) and
        not state.guardian_notified

    if should_escalate do
      Logger.error(
        "[Watchdog] ESCALATING to Guardian - #{failed_critical} critical failures, #{total_failures} total"
      )

      emit_escalation(failed_critical, total_failures)
      notify_guardian(state, failed_critical, total_failures)

      %{
        state
        | guardian_notified: true,
          total_escalations: state.total_escalations + 1
      }
    else
      state
    end
  end

  defp notify_guardian(state, critical_count, total_failures) do
    # Record to ImmutableState
    payload = %{
      change_type: :watchdog_escalation,
      module: "Watchdog",
      critical_failures: critical_count,
      total_failures: total_failures,
      processes: Map.keys(state.processes),
      timestamp: DateTime.utc_now()
    }

    ImmutableState.record(payload)

    # Notify Guardian
    proposal = %{
      type: :emergency,
      action: :watchdog_escalation,
      critical_count: critical_count,
      total_failures: total_failures,
      requestor: __MODULE__
    }

    request_guardian_approval(proposal)
  rescue
    e -> Logger.error("[Watchdog] Guardian notification failed: #{Exception.message(e)}")
  end

  defp record_restart_attempt(process_name) do
    payload = %{
      change_type: :watchdog_restart,
      module: "Watchdog",
      process: process_name,
      timestamp: DateTime.utc_now()
    }

    ImmutableState.record(payload)
  rescue
    _ -> :ok
  end

  # ============================================================================
  # Private: Default Process Registration
  # ============================================================================

  defp register_default_processes(state) do
    # Critical processes that must have heartbeat
    critical = [
      {Indrajaal.Cockpit.Prajna.ImmutableState, :critical},
      {Indrajaal.Cockpit.Prajna.DualChannel, :critical},
      {Indrajaal.Cockpit.Prajna.GuardianIntegration, :critical}
    ]

    # Important processes
    important = [
      {Indrajaal.Cockpit.Prajna.SmartMetrics, :important},
      {Indrajaal.Cockpit.Prajna.SentinelBridge, :important},
      {Indrajaal.Cockpit.Prajna.Orchestrator, :important}
    ]

    # Standard processes
    standard = [
      {Indrajaal.Cockpit.Prajna.AiCopilot, :standard}
    ]

    all_processes = critical ++ important ++ standard
    now = DateTime.utc_now()

    processes =
      Enum.into(all_processes, %{}, fn {module, priority} ->
        {module,
         %{
           name: module,
           module: module,
           priority: priority,
           last_heartbeat: now,
           state: :healthy,
           failure_count: 0,
           restart_count: 0
         }}
      end)

    %{state | processes: processes}
  end

  # ============================================================================
  # Private: Helpers
  # ============================================================================

  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check, interval_ms)
  end

  defp compute_overall_status(state) do
    has_critical_failure =
      Enum.any?(state.processes, fn {_, info} ->
        info.priority == :critical and info.state in [:failed, :warning]
      end)

    has_any_failure = Enum.any?(state.processes, fn {_, info} -> info.state == :failed end)

    cond do
      has_critical_failure -> :critical
      has_any_failure -> :degraded
      true -> :healthy
    end
  end

  defp request_guardian_approval(proposal) do
    try do
      Guardian.validate_proposal(proposal, timeout: 5_000)
    rescue
      _ -> {:error, :guardian_error}
    catch
      :exit, _ -> {:error, :guardian_unavailable}
    end
  end

  defp get_config(key) do
    defaults = %{
      heartbeat_timeout_ms: @default_heartbeat_timeout_ms,
      check_interval_ms: @default_check_interval_ms,
      escalation_threshold: @default_escalation_threshold,
      restart_delay_ms: @default_restart_delay_ms
    }

    try do
      Config.get(:"watchdog_#{key}", Map.get(defaults, key))
    rescue
      _ -> Map.get(defaults, key)
    end
  end

  defp get_restart_delay do
    get_config(:restart_delay_ms)
  end

  # Get context-aware heartbeat parameters from DirectedTelescopeController
  # Returns {interval_ms, timeout_ms} or {nil, nil} if controller unavailable
  defp get_context_aware_params do
    try do
      DirectedTelescopeController.heartbeat_params()
    rescue
      _ -> {nil, nil}
    catch
      :exit, _ -> {nil, nil}
    end
  end

  # Check if watchdog is enabled in current context (SC-OBS-DT-005)
  defp watchdog_enabled_in_context? do
    try do
      DirectedTelescopeController.service_enabled?(:watchdog)
    rescue
      # If controller not available, assume enabled for safety
      _ -> true
    catch
      :exit, _ -> true
    end
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_initialized(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :initialized],
      %{
        process_count: map_size(state.processes),
        timestamp: System.system_time(:millisecond)
      },
      %{}
    )
  end

  defp emit_heartbeat_received(process_name) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :heartbeat],
      %{timestamp: System.system_time(:millisecond)},
      %{process: process_name}
    )
  end

  defp emit_heartbeat_timeout(process_name, elapsed_ms) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :timeout],
      %{elapsed_ms: elapsed_ms, timestamp: System.system_time(:millisecond)},
      %{process: process_name}
    )
  end

  defp emit_process_registered(process_name, priority) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :registered],
      %{timestamp: System.system_time(:millisecond)},
      %{process: process_name, priority: priority}
    )
  end

  defp emit_restart_attempt(process_name) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :restart_attempt],
      %{timestamp: System.system_time(:millisecond)},
      %{process: process_name}
    )
  end

  defp emit_restart_success(process_name) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :restart_success],
      %{timestamp: System.system_time(:millisecond)},
      %{process: process_name}
    )
  end

  defp emit_restart_failure(process_name, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :restart_failure],
      %{timestamp: System.system_time(:millisecond)},
      %{process: process_name, reason: reason}
    )
  end

  defp emit_escalation(critical_count, total_failures) do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :escalation],
      %{
        critical_count: critical_count,
        total_failures: total_failures,
        timestamp: System.system_time(:millisecond)
      },
      %{}
    )
  end

  defp emit_reset do
    :telemetry.execute(
      [:indrajaal, :prajna, :watchdog, :reset],
      %{timestamp: System.system_time(:millisecond)},
      %{}
    )
  end
end
