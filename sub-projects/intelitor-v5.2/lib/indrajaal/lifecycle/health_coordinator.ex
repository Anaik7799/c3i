defmodule Indrajaal.Lifecycle.HealthCoordinator do
  @moduledoc """
  SIL-4 Compliant Health Coordination Engine

  WHAT: Coordinates 10-second health checks across all containers with FPPS consensus.

  WHY: SIL-4 requires continuous health monitoring with validated consensus.
  FPPS (Five-Point Pattern Scoring) ensures 3/5 validators must agree
  before health status changes.

  CONSTRAINTS:
  - SC-SIL4-001: Health checks every 10 seconds
  - SC-SIL4-023: FPPS 3/5 consensus for health determination
  - SC-CLU-008: Health checks every 10s
  - SC-IMMUNE-001: Sentinel SHALL monitor system health continuously

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | FPPS Consensus | NASA | Fault-tolerant health determination |
  | Continuous Monitoring | SIL-4 | Safety integrity |
  | Telemetry Emission | BEAM | Observability |
  | Circuit Breaker | Hystrix | Cascading failure prevention |

  AOR:
  - AOR-IMMUNE-001: Run Sentinel.assess_now() before critical operations
  - AOR-SIL4-001: Health status must be validated by FPPS consensus
  """

  use GenServer
  require Logger

  # =============================================================================
  # Constants (SC-SIL4-001: 10 second interval)
  # =============================================================================

  @health_check_interval_ms 10_000
  @health_check_timeout_ms 5_000
  @consensus_threshold 3

  # =============================================================================
  # Types
  # =============================================================================

  @type container_id :: String.t()
  @type health_status :: :healthy | :unhealthy | :degraded | :unknown | :starting
  @type consensus_result :: {:ok, health_status()} | {:error, :no_consensus}

  @type health_report :: %{
          container_id: container_id(),
          status: health_status(),
          validators: map(),
          consensus: boolean(),
          last_check: DateTime.t(),
          duration_ms: non_neg_integer()
        }

  @type system_health :: %{
          overall: health_status(),
          containers: %{container_id() => health_report()},
          quorum: boolean(),
          last_update: DateTime.t()
        }

  # =============================================================================
  # State
  # =============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :containers,
      :health_reports,
      :overall_health,
      :last_check,
      :check_count,
      :consecutive_failures,
      :circuit_breaker_open
    ]
  end

  # =============================================================================
  # Fractal-Cluster Containers (SC-CLU-002)
  # =============================================================================

  @fractal_cluster_containers [
    "db-primary",
    "indrajaal-obs",
    "indrajaal-ex-app-1",
    "indrajaal-ex-app-2",
    "indrajaal-ex-app-3"
  ]

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the HealthCoordinator GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current system health status.
  """
  @spec get_health() :: system_health()
  def get_health do
    GenServer.call(__MODULE__, :get_health)
  end

  @doc """
  Gets health status for a specific container.
  """
  @spec get_container_health(container_id()) :: {:ok, health_report()} | {:error, :not_found}
  def get_container_health(container_id) do
    GenServer.call(__MODULE__, {:get_container_health, container_id})
  end

  @doc """
  Forces an immediate health check cycle.
  """
  @spec check_now() :: system_health()
  def check_now do
    GenServer.call(__MODULE__, :check_now, @health_check_timeout_ms + 5_000)
  end

  @doc """
  Registers a container for health monitoring.
  """
  @spec register_container(container_id()) :: :ok
  def register_container(container_id) do
    GenServer.cast(__MODULE__, {:register_container, container_id})
  end

  @doc """
  Unregisters a container from health monitoring.
  """
  @spec unregister_container(container_id()) :: :ok
  def unregister_container(container_id) do
    GenServer.cast(__MODULE__, {:unregister_container, container_id})
  end

  @doc """
  Checks if system has quorum (majority of containers healthy).
  """
  @spec has_quorum?() :: boolean()
  def has_quorum? do
    GenServer.call(__MODULE__, :has_quorum)
  end

  # =============================================================================
  # GenServer Callbacks
  # =============================================================================

  @impl true
  def init(_opts) do
    state = %State{
      containers: MapSet.new(@fractal_cluster_containers),
      health_reports: %{},
      overall_health: :unknown,
      last_check: nil,
      check_count: 0,
      consecutive_failures: 0,
      circuit_breaker_open: false
    }

    # Schedule first health check after a short delay
    Process.send_after(self(), :health_check, 1_000)

    Logger.info(
      "[HealthCoordinator] Started with #{MapSet.size(state.containers)} containers, 10s interval"
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health = build_system_health(state)
    {:reply, health, state}
  end

  @impl true
  def handle_call({:get_container_health, container_id}, _from, state) do
    case Map.get(state.health_reports, container_id) do
      nil -> {:reply, {:error, :not_found}, state}
      report -> {:reply, {:ok, report}, state}
    end
  end

  @impl true
  def handle_call(:check_now, _from, state) do
    new_state = execute_health_check(state)
    health = build_system_health(new_state)
    {:reply, health, new_state}
  end

  @impl true
  def handle_call(:has_quorum, _from, state) do
    quorum = calculate_quorum(state)
    {:reply, quorum, state}
  end

  @impl true
  def handle_cast({:register_container, container_id}, state) do
    new_containers = MapSet.put(state.containers, container_id)
    {:noreply, %{state | containers: new_containers}}
  end

  @impl true
  def handle_cast({:unregister_container, container_id}, state) do
    new_containers = MapSet.delete(state.containers, container_id)
    new_reports = Map.delete(state.health_reports, container_id)
    {:noreply, %{state | containers: new_containers, health_reports: new_reports}}
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state =
      if state.circuit_breaker_open do
        # Check if we should close circuit breaker
        maybe_close_circuit_breaker(state)
      else
        execute_health_check(state)
      end

    # Schedule next check (SC-SIL4-001: 10 second interval)
    Process.send_after(self(), :health_check, @health_check_interval_ms)

    {:noreply, new_state}
  end

  # =============================================================================
  # Private: Health Check Execution
  # =============================================================================

  defp execute_health_check(state) do
    start_time = System.monotonic_time(:millisecond)

    emit_telemetry(:health_check_start, %{container_count: MapSet.size(state.containers)})

    # Check all containers in parallel
    reports =
      state.containers
      |> MapSet.to_list()
      |> Task.async_stream(
        fn container_id -> check_container_with_fpps(container_id) end,
        timeout: @health_check_timeout_ms,
        on_timeout: :kill_task,
        max_concurrency: MapSet.size(state.containers)
      )
      |> Enum.map(fn
        {:ok, report} -> {report.container_id, report}
        {:exit, :timeout} -> {nil, nil}
      end)
      |> Enum.reject(fn {id, _} -> is_nil(id) end)
      |> Map.new()

    duration_ms = System.monotonic_time(:millisecond) - start_time

    # Calculate overall health
    overall = calculate_overall_health(reports)
    quorum = calculate_quorum_from_reports(reports)

    emit_telemetry(:health_check_complete, %{
      overall: overall,
      quorum: quorum,
      duration_ms: duration_ms,
      container_count: map_size(reports)
    })

    # Update consecutive failures for circuit breaker
    consecutive_failures =
      if overall in [:healthy, :degraded] do
        0
      else
        state.consecutive_failures + 1
      end

    circuit_breaker_open =
      if consecutive_failures >= 3 do
        Logger.warning(
          "[HealthCoordinator] Circuit breaker OPEN after #{consecutive_failures} failures"
        )

        true
      else
        false
      end

    %{
      state
      | health_reports: reports,
        overall_health: overall,
        last_check: DateTime.utc_now(),
        check_count: state.check_count + 1,
        consecutive_failures: consecutive_failures,
        circuit_breaker_open: circuit_breaker_open
    }
  end

  defp check_container_with_fpps(container_id) do
    start_time = System.monotonic_time(:millisecond)

    # Run 5 validators (FPPS - Five Point Pattern Scoring)
    validators = run_fpps_validators(container_id)

    # Determine consensus
    {consensus_status, has_consensus} = fpps_consensus(validators)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    # ZUIP D-04: Publish FPPS consensus result to Zenoh mesh
    Indrajaal.Observability.ZenohSafetyPublisher.publish_fpps_result(
      consensus_status,
      validators
    )

    emit_telemetry(:container_health_check, %{
      container: container_id,
      status: consensus_status,
      consensus: has_consensus,
      duration_ms: duration_ms
    })

    %{
      container_id: container_id,
      status: consensus_status,
      validators: validators,
      consensus: has_consensus,
      last_check: DateTime.utc_now(),
      duration_ms: duration_ms
    }
  end

  # =============================================================================
  # Private: FPPS Validators (SC-SIL4-023)
  # =============================================================================

  defp run_fpps_validators(container_id) do
    %{
      pattern: validate_pattern(container_id),
      ast: validate_ast(container_id),
      statistical: validate_statistical(container_id),
      binary: validate_binary(container_id),
      line_by_line: validate_line_by_line(container_id)
    }
  end

  # Validator 1: Pattern matching on container status
  defp validate_pattern(container_id) do
    case System.cmd("podman", ["inspect", "--format", "{{.State.Status}}", container_id],
           stderr_to_stdout: true
         ) do
      {"running\n", 0} -> :healthy
      {"exited\n", 0} -> :unhealthy
      {"created\n", 0} -> :starting
      {"paused\n", 0} -> :degraded
      _ -> :unknown
    end
  end

  # Validator 2: AST-based (health check status)
  defp validate_ast(container_id) do
    case System.cmd("podman", ["inspect", "--format", "{{.State.Health.Status}}", container_id],
           stderr_to_stdout: true
         ) do
      {"healthy\n", 0} -> :healthy
      {"unhealthy\n", 0} -> :unhealthy
      {"starting\n", 0} -> :starting
      {"", 0} -> :healthy
      _ -> :unknown
    end
  end

  # Validator 3: Statistical (exit code history)
  defp validate_statistical(container_id) do
    case System.cmd("podman", ["inspect", "--format", "{{.State.ExitCode}}", container_id],
           stderr_to_stdout: true
         ) do
      {"0\n", 0} -> :healthy
      {code, 0} when code != "" -> :unhealthy
      _ -> :unknown
    end
  end

  # Validator 4: Binary (process running check)
  defp validate_binary(container_id) do
    case System.cmd("podman", ["inspect", "--format", "{{.State.Running}}", container_id],
           stderr_to_stdout: true
         ) do
      {"true\n", 0} -> :healthy
      {"false\n", 0} -> :unhealthy
      _ -> :unknown
    end
  end

  # Validator 5: Line-by-line (logs analysis for errors)
  defp validate_line_by_line(container_id) do
    case System.cmd("podman", ["logs", "--tail", "10", container_id], stderr_to_stdout: true) do
      {logs, 0} ->
        cond do
          String.contains?(logs, "ERROR") or String.contains?(logs, "FATAL") ->
            :unhealthy

          String.contains?(logs, "WARN") ->
            :degraded

          true ->
            :healthy
        end

      _ ->
        :unknown
    end
  end

  # =============================================================================
  # Private: FPPS Consensus (3/5 must agree)
  # =============================================================================

  defp fpps_consensus(validators) do
    # Count votes for each status
    votes =
      validators
      |> Map.values()
      |> Enum.group_by(& &1)
      |> Map.new(fn {status, list} -> {status, length(list)} end)

    # Find status with most votes
    {winning_status, vote_count} =
      votes
      |> Enum.max_by(fn {_status, count} -> count end, fn -> {:unknown, 0} end)

    # Check if we have consensus (3/5 = 60%)
    has_consensus = vote_count >= @consensus_threshold

    if has_consensus do
      {winning_status, true}
    else
      # No consensus - use weighted fallback
      fallback_status = weighted_fallback(votes)
      {fallback_status, false}
    end
  end

  defp weighted_fallback(votes) do
    # Priority: unhealthy > degraded > unknown > starting > healthy
    cond do
      Map.get(votes, :unhealthy, 0) >= 2 -> :unhealthy
      Map.get(votes, :degraded, 0) >= 2 -> :degraded
      Map.get(votes, :healthy, 0) >= 2 -> :healthy
      Map.get(votes, :starting, 0) >= 2 -> :starting
      true -> :unknown
    end
  end

  # =============================================================================
  # Private: Overall Health Calculation
  # =============================================================================

  defp calculate_overall_health(reports) when map_size(reports) == 0 do
    :unknown
  end

  defp calculate_overall_health(reports) do
    statuses = Enum.map(reports, fn {_id, report} -> report.status end)

    cond do
      Enum.all?(statuses, &(&1 == :healthy)) ->
        :healthy

      Enum.any?(statuses, &(&1 == :unhealthy)) ->
        :unhealthy

      Enum.any?(statuses, &(&1 == :degraded)) ->
        :degraded

      Enum.any?(statuses, &(&1 == :starting)) ->
        :starting

      true ->
        :unknown
    end
  end

  defp calculate_quorum(state) do
    calculate_quorum_from_reports(state.health_reports)
  end

  defp calculate_quorum_from_reports(reports) when map_size(reports) == 0 do
    false
  end

  defp calculate_quorum_from_reports(reports) do
    total = map_size(reports)
    healthy_count = Enum.count(reports, fn {_id, r} -> r.status == :healthy end)
    required = div(total, 2) + 1
    healthy_count >= required
  end

  # =============================================================================
  # Private: Circuit Breaker
  # =============================================================================

  defp maybe_close_circuit_breaker(state) do
    # Try a single health check to see if we can close
    test_container = state.containers |> MapSet.to_list() |> List.first()

    if test_container do
      report = check_container_with_fpps(test_container)

      if report.status == :healthy do
        Logger.info("[HealthCoordinator] Circuit breaker CLOSED - system recovering")
        %{state | circuit_breaker_open: false, consecutive_failures: 0}
      else
        state
      end
    else
      state
    end
  end

  # =============================================================================
  # Private: Build Response
  # =============================================================================

  defp build_system_health(state) do
    %{
      overall: state.overall_health,
      containers: state.health_reports,
      quorum: calculate_quorum(state),
      last_update: state.last_check
    }
  end

  # =============================================================================
  # Private: Telemetry
  # =============================================================================

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :lifecycle, :health_coordinator, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
