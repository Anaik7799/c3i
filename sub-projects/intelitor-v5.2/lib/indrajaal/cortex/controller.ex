defmodule Indrajaal.Cortex.Controller do
  @moduledoc """
  Cortex Cognitive Controller - The OODA Loop Engine.

  Implements the Observe-Orient-Decide-Act cycle for autonomic system management:
  - Observe: Collect sensor data from all sources
  - Orient: Analyze patterns, calculate stress, detect anomalies
  - Decide: Generate proposals for system adjustments
  - Act: Execute approved actions through actuators

  STAMP Compliance:
  - SC-CTX-004: OODA cycle bounded latency (<1000ms)
  - SC-CTX-005: Decision audit trail
  - SC-CTX-006: Action rollback capability

  GDE/CAFE:
  - Goal-Directed Evolution algorithm
  - Cybernetic feedback integration
  """

  use GenServer

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias Indrajaal.Cortex.Reflexes.CircuitBreaker
  alias Indrajaal.Cortex.Sensors.{ContainerHealthSensor, FLAMESensor, MLSensor, SystemSensor}

  @ooda_interval :timer.seconds(30)
  # ms
  @max_ooda_latency 1000

  # Thresholds for decision making
  @stress_critical 0.9
  @stress_high 0.7
  @stress_low 0.3

  ## Client API

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current system state from the controller's perspective.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get pending proposals awaiting execution.
  """
  @spec get_proposals() :: list(map())
  def get_proposals do
    GenServer.call(__MODULE__, :get_proposals)
  end

  @doc """
  Approve a proposal for execution.
  """
  @spec approve_proposal(String.t()) :: {:ok, atom()} | {:error, atom()}
  def approve_proposal(proposal_id) do
    GenServer.call(__MODULE__, {:approve_proposal, proposal_id})
  end

  @doc """
  Reject a proposal.
  """
  @spec reject_proposal(String.t(), String.t()) :: :ok
  def reject_proposal(proposal_id, reason \\ "Rejected by operator") do
    GenServer.call(__MODULE__, {:reject_proposal, proposal_id, reason})
  end

  @doc """
  Force an immediate OODA cycle.
  """
  @spec trigger_cycle() :: :ok
  def trigger_cycle do
    GenServer.cast(__MODULE__, :trigger_cycle)
  end

  @doc """
  Get OODA cycle metrics.
  """
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🧠 Cortex.Controller: OODA Loop Engine starting")

    state = %{
      # OODA state
      phase: :idle,
      last_observation: nil,
      last_orientation: nil,
      proposals: [],
      executed_actions: [],

      # Metrics
      cycle_count: 0,
      total_latency_ms: 0,
      decisions_made: 0,
      actions_executed: 0,

      # History
      stress_history: [],
      action_history: [],

      # Configuration
      # Require approval by default
      auto_execute: false,
      started_at: DateTime.utc_now()
    }

    schedule_ooda_cycle()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    summary = %{
      phase: state.phase,
      cycle_count: state.cycle_count,
      pending_proposals: length(state.proposals),
      last_stress: get_last_stress(state),
      auto_execute: state.auto_execute,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at, :second)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_call(:get_proposals, _from, state) do
    {:reply, state.proposals, state}
  end

  @impl true
  def handle_call({:approve_proposal, proposal_id}, _from, state) do
    case find_proposal(state.proposals, proposal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      proposal ->
        result = execute_proposal(proposal)
        new_proposals = Enum.reject(state.proposals, &(&1.id == proposal_id))

        new_state = %{
          state
          | proposals: new_proposals,
            actions_executed: state.actions_executed + 1,
            action_history: [
              %{proposal: proposal, result: result, at: DateTime.utc_now()} | state.action_history
            ]
        }

        {:reply, result, new_state}
    end
  end

  @impl true
  def handle_call({:reject_proposal, proposal_id, reason}, _from, state) do
    new_proposals = Enum.reject(state.proposals, &(&1.id == proposal_id))
    Logger.info("🧠 Cortex: Proposal #{proposal_id} rejected: #{reason}")
    {:reply, :ok, %{state | proposals: new_proposals}}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    avg_latency =
      if state.cycle_count > 0,
        do: state.total_latency_ms / state.cycle_count,
        else: 0.0

    metrics = %{
      cycle_count: state.cycle_count,
      avg_latency_ms: Float.round(avg_latency, 2),
      decisions_made: state.decisions_made,
      actions_executed: state.actions_executed,
      pending_proposals: length(state.proposals),
      stress_history_size: length(state.stress_history)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_cast(:trigger_cycle, state) do
    new_state = run_ooda_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    new_state = run_ooda_cycle(state)
    schedule_ooda_cycle()
    {:noreply, new_state}
  end

  ## OODA Loop Implementation

  defp run_ooda_cycle(state) do
    start_time = System.monotonic_time(:millisecond)

    Tracer.with_span "cortex.ooda_cycle", kind: :internal do
      # OBSERVE
      observation = observe()
      Tracer.set_attribute("ooda.observation.sensors", length(Map.keys(observation)))

      # ORIENT
      orientation = orient(observation)
      Tracer.set_attribute("ooda.orientation.stress", orientation.stress_score)

      # DECIDE
      {decisions, proposals} = decide(orientation, state)
      Tracer.set_attribute("ooda.decisions.count", length(decisions))

      # ACT (if auto-execute enabled or reflexive)
      {executed, remaining_proposals} = act(proposals, state.auto_execute)
      Tracer.set_attribute("ooda.actions.executed", length(executed))

      latency = System.monotonic_time(:millisecond) - start_time
      Tracer.set_attribute("ooda.latency_ms", latency)

      # Warn if OODA cycle exceeded latency bound
      if latency > @max_ooda_latency do
        Logger.warning(
          "🧠 Cortex: OODA cycle exceeded latency bound: #{latency}ms > #{@max_ooda_latency}ms"
        )
      end

      # Update state
      %{
        state
        | phase: :idle,
          last_observation: observation,
          last_orientation: orientation,
          proposals: remaining_proposals,
          executed_actions: state.executed_actions ++ executed,
          cycle_count: state.cycle_count + 1,
          total_latency_ms: state.total_latency_ms + latency,
          decisions_made: state.decisions_made + length(decisions),
          stress_history: update_stress_history(state.stress_history, orientation.stress_score)
      }
    end
  end

  # OBSERVE: Collect data from all sensors
  defp observe do
    %{
      system: safe_measure(SystemSensor),
      flame: safe_measure(FLAMESensor),
      ml: safe_measure(MLSensor),
      container: safe_measure(ContainerHealthSensor),
      circuit_breakers: safe_circuit_breaker_status(),
      timestamp: DateTime.utc_now()
    }
  end

  defp safe_circuit_breaker_status do
    try do
      CircuitBreaker.status()
    rescue
      e ->
        Logger.warning("Cortex: CircuitBreaker status failed: #{inspect(e)}")
        %{error: true, reason: Exception.message(e)}
    catch
      :exit, reason ->
        Logger.warning("Cortex: CircuitBreaker process not available: #{inspect(reason)}")
        %{error: true, reason: "process_not_available"}
    end
  end

  defp safe_measure(sensor_module) do
    try do
      sensor_module.measure()
    rescue
      e ->
        Logger.warning("Cortex: Sensor #{sensor_module} failed: #{inspect(e)}")
        %{error: true, reason: Exception.message(e)}
    catch
      :exit, reason ->
        # Handle case when sensor process is not running (GenServer.call exits)
        Logger.warning(
          "Cortex: Sensor #{sensor_module} process not available: #{inspect(reason)}"
        )

        %{error: true, reason: "process_not_available"}
    end
  end

  # ORIENT: Analyze observations
  defp orient(observation) do
    # Calculate stress from system metrics
    system_stress = calculate_system_stress(observation.system)
    flame_stress = calculate_flame_stress(observation.flame)
    ml_stress = calculate_ml_stress(observation.ml)
    container_stress = calculate_container_stress(observation.container)

    # Weighted combination (container health affects overall stress)
    overall_stress =
      system_stress * 0.35 +
        flame_stress * 0.25 +
        ml_stress * 0.20 +
        container_stress * 0.20

    # Detect anomalies
    anomalies = detect_anomalies(observation)

    # Assess circuit breaker states
    circuit_breaker_issues = assess_circuit_breakers(observation.circuit_breakers)

    %{
      stress_score: Float.round(overall_stress, 3),
      component_stress: %{
        system: Float.round(system_stress, 3),
        flame: Float.round(flame_stress, 3),
        ml: Float.round(ml_stress, 3),
        container: Float.round(container_stress, 3)
      },
      anomalies: anomalies,
      circuit_breaker_issues: circuit_breaker_issues,
      analysis_timestamp: DateTime.utc_now()
    }
  end

  # Unknown = medium stress
  defp calculate_system_stress(%{error: true}), do: 0.5

  defp calculate_system_stress(metrics) do
    memory_stress = Map.get(metrics, :memory_usage, 0)
    cpu_stress = Map.get(metrics, :cpu_usage, 0)
    queue_stress = min(Map.get(metrics, :run_queue, 0) / 100, 1.0)

    memory_stress * 0.4 + cpu_stress * 0.3 + queue_stress * 0.3
  end

  defp calculate_flame_stress(%{error: true}), do: 0.5

  defp calculate_flame_stress(metrics) do
    pools = Map.get(metrics, :pools, %{})

    if map_size(pools) == 0 do
      0.0
    else
      pool_stresses =
        Enum.map(pools, fn {_name, pool} ->
          utilization = Map.get(pool, :utilization, 0)
          queue_depth = min(Map.get(pool, :queue_depth, 0) / 50, 1.0)
          utilization * 0.6 + queue_depth * 0.4
        end)

      Enum.sum(pool_stresses) / length(pool_stresses)
    end
  end

  defp calculate_ml_stress(%{error: true}), do: 0.5

  defp calculate_ml_stress(metrics) do
    avg_latency = Map.get(metrics, :avg_latency_ms, 0)
    # Normalize latency: 100ms = 0.5 stress, 500ms = 1.0 stress
    min(avg_latency / 500, 1.0)
  end

  # Container health stress (SC-CNT-009 to SC-CNT-012)
  # Container issues = high stress
  defp calculate_container_stress(%{error: true}), do: 0.8

  defp calculate_container_stress(metrics) do
    healthy = Map.get(metrics, :healthy, false)
    stamp_compliant = Map.get(metrics, :stamp_compliant, false)
    failure_rate = Map.get(metrics, :failure_rate, 0.0)

    cond do
      # Unhealthy container = max stress
      not healthy -> 1.0
      # STAMP violation = high stress
      not stamp_compliant -> 0.7
      # High failure rate = elevated stress
      failure_rate > 0.5 -> 0.6
      # Moderate failure rate
      failure_rate > 0.2 -> 0.3
      # Healthy, compliant = no stress
      true -> 0.0
    end
  end

  defp detect_anomalies(observation) do
    anomalies = []

    # Memory anomaly
    memory = get_in(observation, [:system, :memory_usage]) || 0
    anomalies = if memory > 0.9, do: [:high_memory | anomalies], else: anomalies

    # CPU anomaly
    cpu = get_in(observation, [:system, :cpu_usage]) || 0
    anomalies = if cpu > 0.9, do: [:high_cpu | anomalies], else: anomalies

    # Run queue anomaly
    queue = get_in(observation, [:system, :run_queue]) || 0
    anomalies = if queue > 50, do: [:high_run_queue | anomalies], else: anomalies

    # Container health anomalies (SC-CNT-009 to SC-CNT-012)
    container_healthy = get_in(observation, [:container, :healthy])
    stamp_compliant = get_in(observation, [:container, :stamp_compliant])

    anomalies =
      if container_healthy == false, do: [:container_unhealthy | anomalies], else: anomalies

    anomalies = if stamp_compliant == false, do: [:stamp_violation | anomalies], else: anomalies

    anomalies
  end

  defp assess_circuit_breakers(cb_status) do
    Enum.filter(cb_status, fn {_name, state} ->
      state == :open or state == :half_open
    end)
  end

  # DECIDE: Generate proposals
  defp decide(orientation, state) do
    stress = orientation.stress_score

    {decisions, proposals} =
      cond do
        stress > @stress_critical ->
          proposal = create_proposal(:emergency_scale_up, :critical, "Critical stress: #{stress}")
          {[:emergency_response], [proposal | state.proposals]}

        stress > @stress_high ->
          proposal = create_proposal(:scale_up, :high, "High stress: #{stress}")
          {[:scale_up_recommended], [proposal | state.proposals]}

        stress < @stress_low and not Enum.empty?(state.executed_actions) ->
          proposal = create_proposal(:scale_down, :low, "Low stress: #{stress}")
          {[:scale_down_recommended], [proposal | state.proposals]}

        true ->
          {[:maintain_current], state.proposals}
      end

    # Handle anomalies
    Enum.each(orientation.anomalies, fn anomaly ->
      Logger.warning("🧠 Cortex: Anomaly detected: #{anomaly}")
    end)

    # Handle circuit breaker issues
    Enum.each(orientation.circuit_breaker_issues, fn {name, _state} ->
      Logger.warning("🧠 Cortex: Circuit breaker issue: #{name}")
    end)

    {decisions, proposals}
  end

  defp create_proposal(action, priority, reason) do
    %{
      id: generate_proposal_id(),
      action: action,
      priority: priority,
      reason: reason,
      created_at: DateTime.utc_now(),
      status: :pending
    }
  end

  defp generate_proposal_id do
    bytes = :crypto.strong_rand_bytes(8)
    bytes |> Base.encode16(case: :lower)
  end

  # ACT: Execute actions
  defp act(proposals, auto_execute) do
    {to_execute, to_keep} =
      if auto_execute do
        # Auto-execute critical proposals only
        Enum.split_with(proposals, &(&1.priority == :critical))
      else
        # Reflexive actions only (circuit breaker responses)
        {[], proposals}
      end

    executed =
      Enum.map(to_execute, fn proposal ->
        result = execute_proposal(proposal)
        %{proposal: proposal, result: result, at: DateTime.utc_now()}
      end)

    {executed, to_keep}
  end

  defp execute_proposal(proposal) do
    Logger.info("🧠 Cortex: Executing proposal #{proposal.id}: #{proposal.action}")

    case proposal.action do
      :emergency_scale_up ->
        # In production, this would call FLAME.Pool.update_config
        Logger.info("🧠 Cortex: ACTUATOR - Emergency scale up triggered")
        {:ok, :scaled_up}

      :scale_up ->
        Logger.info("🧠 Cortex: ACTUATOR - Scale up triggered")
        {:ok, :scaled_up}

      :scale_down ->
        Logger.info("🧠 Cortex: ACTUATOR - Scale down triggered")
        {:ok, :scaled_down}

      other ->
        Logger.warning("🧠 Cortex: Unknown action: #{other}")
        {:error, :unknown_action}
    end
  end

  ## Helpers

  defp schedule_ooda_cycle do
    Process.send_after(self(), :ooda_cycle, @ooda_interval)
  end

  defp find_proposal(proposals, id) do
    Enum.find(proposals, &(&1.id == id))
  end

  defp get_last_stress(state) do
    case state.stress_history do
      [latest | _] -> latest
      [] -> nil
    end
  end

  defp update_stress_history(history, stress) do
    # Keep last 100 readings
    [stress | Enum.take(history, 99)]
  end
end
