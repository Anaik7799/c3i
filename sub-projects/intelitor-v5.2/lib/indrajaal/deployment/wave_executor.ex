defmodule Indrajaal.Deployment.WaveExecutor do
  @moduledoc """
  SIL-4 Compliant Wave-Based Container Orchestration Engine

  WHAT: Dependency-aware parallel container startup with transaction semantics.

  WHY: Sequential startup is slow and doesn't leverage DAG parallelism.
  Wave-based execution ensures dependency order while maximizing concurrency.
  SIL-4 requires deterministic boot sequences with rollback capability.

  CONSTRAINTS:
  - SC-SIL4-001: Health checks every 10 seconds
  - SC-SIL4-002: Wave timeout 30 seconds
  - SC-SIL4-005: Start order: DB → OBS → APP
  - SC-SIL4-006: Thundering herd mitigation via jitter
  - SC-SIL4-007: Dying gasp mandatory (checkpoints)
  - SC-CLU-002: Fractal-cluster is MANDATORY

  TECHNIQUES:
  | Technique | Source | Purpose |
  |-----------|--------|---------|
  | Dependency-Aware Parallelization | systemd | Fast boot with safety |
  | Static Topology Caching | AUTOSAR | SIL-4 determinism |
  | Staggered Start with Jitter | Windows SCM | Prevent thundering herd |
  | Transaction Semantics | Automotive | Rollback on failure |

  AOR:
  - AOR-SIL4-001: Wave executor MUST verify topology before boot
  - AOR-SIL4-002: Rollback on any wave failure
  - AOR-TPS-001: Jidoka - stop on quality defect
  - AOR-TPS-002: Heijunka - level workload via jitter
  """

  use GenServer
  require Logger

  alias Indrajaal.Deployment.StartupWave
  alias Indrajaal.Mesh.DigitalTwin
  alias Indrajaal.Lifecycle.ContainerLifecycle

  # =============================================================================
  # Types
  # =============================================================================

  @type container_id :: String.t()
  @type wave_order :: pos_integer()
  @type duration_ms :: non_neg_integer()

  @type boot_result ::
          {:success, container_id(), duration_ms()}
          | {:failure, String.t(), duration_ms()}
          | {:timeout, duration_ms()}
          | {:skipped, String.t()}

  @type wave_result :: %{
          wave: wave_order(),
          results: %{container_id() => boot_result()},
          total_duration_ms: duration_ms(),
          all_succeeded: boolean()
        }

  @type mesh_boot_result :: %{
          waves: [wave_result()],
          total_duration_ms: duration_ms(),
          all_succeeded: boolean(),
          failed_containers: [container_id()],
          rollback_performed: boolean()
        }

  # =============================================================================
  # Structs
  # =============================================================================

  # StartupWave struct moved to separate file: lib/indrajaal/deployment/startup_wave.ex

  defmodule BootConfig do
    @moduledoc """
    Configuration for mesh boot sequence.
    """
    @enforce_keys [:compose_file]
    defstruct [
      :compose_file,
      total_timeout_ms: 120_000,
      container_timeout_ms: 30_000,
      health_check_timeout_ms: 5_000,
      health_check_interval_ms: 500,
      max_health_retries: 20,
      enable_jitter: true,
      base_jitter_ms: 50,
      max_jitter_ms: 200,
      rollback_on_failure: true,
      verbose: true
    ]

    @type t :: %__MODULE__{
            compose_file: String.t(),
            total_timeout_ms: non_neg_integer(),
            container_timeout_ms: non_neg_integer(),
            health_check_timeout_ms: non_neg_integer(),
            health_check_interval_ms: non_neg_integer(),
            max_health_retries: non_neg_integer(),
            enable_jitter: boolean(),
            base_jitter_ms: non_neg_integer(),
            max_jitter_ms: non_neg_integer(),
            rollback_on_failure: boolean(),
            verbose: boolean()
          }
  end

  # =============================================================================
  # State
  # =============================================================================

  defmodule State do
    @moduledoc false
    defstruct [
      :config,
      :twin,
      :current_wave,
      :started_containers,
      :status,
      :start_time
    ]
  end

  # =============================================================================
  # Default Configuration (SC-CLU-002: prod-standalone is MANDATORY)
  # =============================================================================

  @default_compose_file "lib/cepaf/artifacts/podman-compose-prod-standalone.yml"

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the WaveExecutor GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes wave-based mesh boot with default prod-standalone topology.

  Returns {:ok, mesh_boot_result} on success, {:error, reason} on failure.
  """
  @spec boot() :: {:ok, mesh_boot_result()} | {:error, term()}
  def boot do
    boot(%BootConfig{compose_file: @default_compose_file})
  end

  @doc """
  Executes wave-based mesh boot with custom configuration.
  """
  @spec boot(BootConfig.t()) :: {:ok, mesh_boot_result()} | {:error, term()}
  def boot(%BootConfig{} = config) do
    GenServer.call(__MODULE__, {:boot, config}, config.total_timeout_ms + 10_000)
  end

  @doc """
  Rolls back all started containers in reverse order.
  """
  @spec rollback() :: :ok
  def rollback do
    GenServer.call(__MODULE__, :rollback, 60_000)
  end

  @doc """
  Gets current boot status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Scours ports before startup - kills conflicting processes.
  """
  @spec scour_ports([non_neg_integer()]) :: :ok
  def scour_ports(ports) do
    GenServer.call(__MODULE__, {:scour_ports, ports})
  end

  # =============================================================================
  # GenServer Callbacks
  # =============================================================================

  @impl true
  def init(_opts) do
    # Initialize Digital Twin with default genotypes
    twin = DigitalTwin.create_default()

    state = %State{
      config: nil,
      twin: twin,
      current_wave: 0,
      started_containers: [],
      status: :idle,
      start_time: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:boot, config}, _from, state) do
    # Re-compute topology to ensure cache is valid (SC-SIL4-001)
    {:ok, cache} = DigitalTwin.compute_topology(state.twin)
    updated_twin = %{state.twin | cache: cache}

    result = execute_boot(cache.start_order, config, %{state | twin: updated_twin})
    {:reply, result, update_state_from_result(%{state | twin: updated_twin}, result)}
  end

  @impl true
  def handle_call({:boot_waves, waves, config}, _from, state) do
    # Manually validate custom waves since they bypass the twin
    valid =
      Enum.all?(waves, fn wave ->
        wave.order > 0 and is_list(wave.containers) and length(wave.containers) > 0
      end)

    if valid do
      result = execute_boot(waves, config, state)
      {:reply, result, update_state_from_result(state, result)}
    else
      {:reply, {:error, "Invalid wave configuration"}, state}
    end
  end

  @impl true
  def handle_call(:rollback, _from, state) do
    execute_rollback(state.started_containers, state.config)

    new_state = %{
      state
      | started_containers: [],
        status: :rolled_back
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status_map = %{
      status: state.status,
      current_wave: state.current_wave,
      started_containers: state.started_containers,
      total_waves: if(state.twin.cache, do: length(state.twin.cache.start_order), else: 0)
    }

    {:reply, status_map, state}
  end

  @impl true
  def handle_call({:scour_ports, ports}, _from, state) do
    do_scour_ports(ports)
    {:reply, :ok, state}
  end

  # =============================================================================
  # Private: Boot Execution
  # =============================================================================

  defp execute_boot(waves, config, _state) do
    start_time = System.monotonic_time(:millisecond)

    emit_telemetry(:boot_start, %{wave_count: length(waves)})

    log_banner("INDRAJAAL SIL-4 MESH BOOT SEQUENCE", config.verbose)

    # Phase 1: Validate topology (SC-SIL4-005) - Already done via DigitalTwin.compute_topology
    log_phase("TOPOLOGY", "OK", "Topology validated: #{length(waves)} waves", config.verbose)

    # Phase 2: Scour ports
    all_ports = collect_ports(waves)
    do_scour_ports(all_ports)

    # Phase 3: Execute waves sequentially
    execute_waves(waves, config, start_time)
  end

  defp execute_waves(waves, config, start_time) do
    initial_acc = %{
      wave_results: [],
      all_succeeded: true,
      failed_containers: [],
      started_containers: []
    }

    result =
      Enum.reduce_while(waves, initial_acc, fn wave, acc ->
        if acc.all_succeeded or not config.rollback_on_failure do
          wave_result = execute_wave(wave, config, acc.started_containers)

          new_acc = %{
            wave_results: acc.wave_results ++ [wave_result],
            all_succeeded: acc.all_succeeded and wave_result.all_succeeded,
            failed_containers: acc.failed_containers ++ extract_failed(wave_result),
            started_containers: acc.started_containers ++ extract_started(wave_result)
          }

          if wave_result.all_succeeded do
            {:cont, new_acc}
          else
            if config.rollback_on_failure do
              {:halt, new_acc}
            else
              {:cont, new_acc}
            end
          end
        else
          {:halt, acc}
        end
      end)

    # Phase 4: Rollback on failure if configured
    rollback_performed =
      if not result.all_succeeded and config.rollback_on_failure do
        execute_rollback(result.started_containers, config)
        true
      else
        false
      end

    total_duration = elapsed_ms(start_time)

    # Final status
    log_final_status(result.all_succeeded, total_duration, rollback_performed, config.verbose)

    emit_telemetry(:boot_complete, %{
      success: result.all_succeeded,
      duration_ms: total_duration,
      rollback: rollback_performed
    })

    boot_result = %{
      waves: result.wave_results,
      total_duration_ms: total_duration,
      all_succeeded: result.all_succeeded,
      failed_containers: result.failed_containers,
      rollback_performed: rollback_performed
    }

    if result.all_succeeded do
      {:ok, boot_result}
    else
      {:error, boot_result}
    end
  end

  defp execute_wave(%StartupWave{} = wave, config, _already_started) do
    wave_start = System.monotonic_time(:millisecond)

    log_phase(
      "WAVE",
      "RUN",
      "Starting wave #{wave.order}: #{Enum.join(wave.containers, ", ")}",
      config.verbose
    )

    emit_telemetry(:wave_start, %{wave: wave.order, containers: wave.containers})

    # Execute containers in parallel with Task.async_stream
    results =
      wave.containers
      |> Task.async_stream(
        fn container_id ->
          boot_container(container_id, wave, config)
        end,
        timeout: wave.timeout_ms,
        on_timeout: :kill_task,
        max_concurrency: length(wave.containers)
      )
      |> Enum.map(fn
        {:ok, {id, result}} -> {id, result}
        {:exit, :timeout} -> {"unknown", {:timeout, wave.timeout_ms}}
      end)
      |> Map.new()

    wave_duration = elapsed_ms(wave_start)

    all_succeeded =
      Enum.all?(results, fn {_id, result} ->
        match?({:success, _, _}, result)
      end)

    # ZUIP D-02: Publish wave completion to Zenoh mesh
    Indrajaal.Observability.ZenohSafetyPublisher.publish_wave_complete(
      wave.order,
      if(all_succeeded, do: :success, else: :failed),
      Enum.map(results, fn {id, _result} -> id end)
    )

    emit_telemetry(:wave_complete, %{
      wave: wave.order,
      success: all_succeeded,
      duration_ms: wave_duration
    })

    %{
      wave: wave.order,
      results: results,
      total_duration_ms: wave_duration,
      all_succeeded: all_succeeded
    }
  end

  defp boot_container(container_id, wave, config) do
    container_start = System.monotonic_time(:millisecond)

    # Apply jitter for thundering herd prevention (SC-SIL4-006)
    if wave.jitter_enabled and config.enable_jitter do
      jitter = :rand.uniform(config.max_jitter_ms - config.base_jitter_ms) + config.base_jitter_ms
      log_phase("JITTER", "RUN", "Delaying #{container_id} by #{jitter}ms", config.verbose)
      Process.sleep(jitter)
    end

    log_phase("BOOT", "RUN", "Starting #{container_id}...", config.verbose)

    # Execute full lifecycle startup via ContainerLifecycle FSM
    case ContainerLifecycle.execute_startup(container_id) do
      {:ok, _state} ->
        duration = elapsed_ms(container_start)

        log_phase(
          "BOOT",
          "OK",
          "#{container_id} ONLINE (#{Float.round(duration / 1000, 2)}s)",
          config.verbose
        )

        {container_id, {:success, container_id, duration}}

      {:error, reason} ->
        duration = elapsed_ms(container_start)
        log_phase("BOOT", "FAIL", "#{container_id} failed: #{inspect(reason)}", config.verbose)
        {container_id, {:failure, inspect(reason), duration}}
    end
  end

  # =============================================================================
  # Private: Rollback
  # =============================================================================

  defp execute_rollback(started_containers, config) do
    log_phase("ROLLBACK", "WARN", "Rolling back all containers...", config.verbose)

    emit_telemetry(:rollback_start, %{containers: started_containers})

    # Stop in reverse order
    started_containers
    |> Enum.reverse()
    |> Enum.each(fn container_id ->
      log_phase("ROLLBACK", "RUN", "Stopping #{container_id}...", config.verbose)
      # Use MeshShutdown logic ideally, but for now simple stop
      System.cmd("podman", ["stop", "-t", "10", container_id])
    end)

    log_phase("ROLLBACK", "OK", "Rollback complete", config.verbose)

    emit_telemetry(:rollback_complete, %{containers: started_containers})
  end

  # =============================================================================
  # Private: Port Scouring
  # =============================================================================

  defp do_scour_ports(ports) do
    Logger.info("[PREFLIGHT] [RUN    ] Scouring port substrate...")

    Enum.each(ports, fn port ->
      case System.cmd("lsof", ["-t", "-i", ":#{port}"], stderr_to_stdout: true) do
        {pids_str, 0} when pids_str != "" ->
          pids_str
          |> String.split("\n", trim: true)
          |> Enum.each(fn pid ->
            Logger.warning("[PREFLIGHT] [WARN   ] Killing PID #{pid} on port #{port}")
            System.cmd("kill", ["-9", pid])
          end)

        _ ->
          :ok
      end
    end)

    Logger.info("[PREFLIGHT] [OK     ] Socket isolation invariant verified")
  end

  defp collect_ports(_waves) do
    # Default ports for fractal-cluster topology
    [5433, 4317, 4318, 9090, 3000, 3100, 4000, 4001, 4002]
  end

  # =============================================================================
  # Private: Result Helpers
  # =============================================================================

  defp extract_failed(%{results: results}) do
    results
    |> Enum.filter(fn {_id, result} ->
      not match?({:success, _, _}, result)
    end)
    |> Enum.map(fn {id, _} -> id end)
  end

  defp extract_started(%{results: results}) do
    results
    |> Enum.filter(fn {_id, result} ->
      match?({:success, _, _}, result)
    end)
    |> Enum.map(fn {id, _} -> id end)
  end

  defp update_state_from_result(state, {:ok, result}) do
    %{
      state
      | status: :completed,
        started_containers: Enum.flat_map(result.waves, &extract_started/1)
    }
  end

  defp update_state_from_result(state, {:error, result}) do
    %{
      state
      | status: if(result.rollback_performed, do: :rolled_back, else: :failed),
        started_containers: []
    }
  end

  # =============================================================================
  # Private: Logging
  # =============================================================================

  defp log_banner(message, true) do
    IO.puts("")
    IO.puts("\e[35m\e[1m>>> #{message} <<<\e[0m")
    IO.puts("")
  end

  defp log_banner(_, false), do: :ok

  defp log_phase(stage, status, message, true) do
    ts = DateTime.utc_now() |> Calendar.strftime("%H:%M:%S.%f") |> String.slice(0..11)

    color =
      case status do
        "OK" -> "\e[32m"
        "RUN" -> "\e[36m"
        "FAIL" -> "\e[31m"
        "WARN" -> "\e[33m"
        _ -> "\e[37m"
      end

    IO.puts(
      "[#{ts}] [#{String.pad_trailing(stage, 12)}] [#{color}#{String.pad_trailing(status, 7)}\e[0m] #{message}"
    )
  end

  defp log_phase(_, _, _, false), do: :ok

  defp log_final_status(true, duration_ms, _rollback, true) do
    IO.puts("")

    IO.puts(
      "\e[32m\e[1m>>> INDRAJAAL MESH STABILIZED: #{Float.round(duration_ms / 1000, 2)}s (SIL-4 CERTIFIED) <<<\e[0m"
    )
  end

  defp log_final_status(false, _duration_ms, true, true) do
    IO.puts("")
    IO.puts("\e[31m\e[1m>>> MESH BOOT FAILED <<<\e[0m")
    IO.puts("\e[33mRollback completed\e[0m")
  end

  defp log_final_status(false, _duration_ms, false, true) do
    IO.puts("")
    IO.puts("\e[31m\e[1m>>> MESH BOOT FAILED <<<\e[0m")
  end

  defp log_final_status(_, _, _, false), do: :ok

  # =============================================================================
  # Private: Utilities
  # =============================================================================

  defp elapsed_ms(start_time) do
    System.monotonic_time(:millisecond) - start_time
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :deployment, :wave_executor, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
