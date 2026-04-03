defmodule Indrajaal.Distributed.Agents.CEPAFAgent do
  @moduledoc """
  Agent 5: CEPAF - Container Operations Bridge.

  WHAT: Bridges Elixir system to F# Podman CLI for container operations.
  WHY: SC-CNT-009 requires NixOS/Podman container management.
  CONSTRAINTS: All containers must have FQUNs, state synced to Zenoh.

  ## CEPAF Responsibilities

  1. **Container Lifecycle**: Start, stop, restart containers
  2. **Health Monitoring**: Container health checks
  3. **Resource Tracking**: CPU, memory, network stats
  4. **FQUN Registration**: All containers get FQUNs

  ## STAMP Constraints
  - SC-CNT-009: NixOS/Podman only
  - SC-CNT-010: localhost registry
  - SC-CNT-012: Rootless mode
  - SC-CEPAF-001: Container FQUNs required

  ## Mathematical Specification

  ```
  CEPAF := (Containers, Operations, Health, Registry)

  Containers := Set(Container)
  Container := (ID, Name, Image, State, FQUN)

  Operations := {Start, Stop, Restart, Inspect, Logs}
  Health := Container → {healthy, unhealthy, starting, none}

  FQUN Invariant:
    ∀ c ∈ Containers: HasFQUN(c) ∧ Registered(c.FQUN)
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :integration,
    namespace: "cepaf",
    name: "bridge"

  alias Indrajaal.Distributed.FQUN

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      # Tracked containers (FQUN -> Container Info)
      containers: %{},

      # Container FQUNs by name
      container_fquns: %{},

      # Health cache
      health_cache: %{},
      health_cache_ttl_ms: 10_000,

      # Operation history
      operations: [],

      # Metrics
      total_operations: 0,
      successful_operations: 0,
      failed_operations: 0,
      last_health_check: nil,

      # Configuration
      config: %{
        podman_socket: "/run/podman/podman.sock",
        registry: "localhost",
        health_check_interval_ms: 30_000
      }
    }

    # Schedule initial health check
    Process.send_after(self(), :health_check, 5_000)

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      container_count: map_size(state.containers),
      containers: container_summary(state.containers),
      health_summary: health_summary(state.health_cache),
      last_health_check: state.last_health_check,
      pending_operations: length(state.operations)
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      container_count: map_size(state.containers),
      total_operations: state.total_operations,
      successful_operations: state.successful_operations,
      failed_operations: state.failed_operations,
      success_rate: safe_ratio(state.successful_operations, state.total_operations),
      healthy_containers: count_healthy(state.health_cache),
      unhealthy_containers: count_unhealthy(state.health_cache)
    }
  end

  @impl true
  def handle_command(:discover, _params, state) do
    # Discover all running containers and register FQUNs
    {containers, fquns} = discover_containers()

    new_state = %{
      state
      | containers: containers,
        container_fquns: fquns,
        total_operations: state.total_operations + 1,
        successful_operations: state.successful_operations + 1
    }

    {:ok, %{discovered: map_size(containers)}, new_state}
  end

  @impl true
  def handle_command(:register_container, params, state) do
    name = Map.get(params, :name)
    id = Map.get(params, :id)
    image = Map.get(params, :image)

    # Generate FQUN for container
    {:ok, fqun} = FQUN.generate(:resource, :container, "cepaf", name)

    container_info = %{
      id: id,
      name: name,
      image: image,
      fqun: fqun,
      registered_at: DateTime.utc_now(),
      state: :running
    }

    new_containers = Map.put(state.containers, fqun, container_info)
    new_fquns = Map.put(state.container_fquns, name, fqun)

    new_state = %{
      state
      | containers: new_containers,
        container_fquns: new_fquns,
        total_operations: state.total_operations + 1,
        successful_operations: state.successful_operations + 1
    }

    # Publish to Zenoh
    publish_container_registered(container_info)

    {:ok, %{fqun: fqun}, new_state}
  end

  @impl true
  def handle_command(:unregister_container, params, state) do
    name = Map.get(params, :name)

    case Map.get(state.container_fquns, name) do
      nil ->
        {:error, :not_found, state}

      fqun ->
        FQUN.unregister(fqun)
        new_containers = Map.delete(state.containers, fqun)
        new_fquns = Map.delete(state.container_fquns, name)

        new_state = %{
          state
          | containers: new_containers,
            container_fquns: new_fquns,
            total_operations: state.total_operations + 1,
            successful_operations: state.successful_operations + 1
        }

        {:ok, :unregistered, new_state}
    end
  end

  @impl true
  def handle_command(:get_container, params, state) do
    name = Map.get(params, :name)

    case Map.get(state.container_fquns, name) do
      nil ->
        {:error, :not_found, state}

      fqun ->
        container = Map.get(state.containers, fqun)
        health = Map.get(state.health_cache, name, :unknown)
        {:ok, Map.put(container, :health, health), state}
    end
  end

  @impl true
  def handle_command(:health_check, params, state) do
    container = Map.get(params, :container)

    health = check_container_health(container)

    new_cache = Map.put(state.health_cache, container, health)
    new_state = %{state | health_cache: new_cache, last_health_check: DateTime.utc_now()}

    {:ok, %{container: container, health: health}, new_state}
  end

  @impl true
  def handle_command(:list_containers, _params, state) do
    containers =
      Enum.map(state.containers, fn {_fqun, info} ->
        health = Map.get(state.health_cache, info.name, :unknown)
        Map.put(info, :health, health)
      end)

    {:ok, containers, state}
  end

  @impl true
  def handle_command(:get_stats, params, state) do
    container = Map.get(params, :container)
    stats = get_container_stats(container)
    {:ok, stats, state}
  end

  @impl true
  def handle_command(:start, params, state) do
    container = Map.get(params, :container)
    result = container_operation(:start, container)

    new_state = record_operation(state, :start, container, result)
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(:stop, params, state) do
    container = Map.get(params, :container)
    result = container_operation(:stop, container)

    new_state = record_operation(state, :stop, container, result)
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(:restart, params, state) do
    container = Map.get(params, :container)
    result = container_operation(:restart, container)

    new_state = record_operation(state, :restart, container, result)
    {:ok, result, new_state}
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # Handle periodic health check
  @impl Indrajaal.Distributed.Agents.BaseAgent
  def handle_agent_info(:health_check, state) do
    # Check health of all containers
    new_cache =
      Enum.reduce(state.containers, state.health_cache, fn {_fqun, info}, cache ->
        health = check_container_health(info.name)
        Map.put(cache, info.name, health)
      end)

    # Schedule next check
    Process.send_after(self(), :health_check, state.config.health_check_interval_ms)

    # Publish health status to Zenoh
    publish_health_status(new_cache)

    {:ok, %{state | health_cache: new_cache, last_health_check: DateTime.utc_now()}}
  end

  def handle_agent_info(_msg, _state), do: :ignore

  # ============================================================
  # CEPAF IMPLEMENTATION
  # ============================================================

  defp discover_containers do
    # Simulate container discovery
    # In production, this would call CepafClient.list_containers()
    containers = %{}
    fquns = %{}
    {containers, fquns}
  end

  defp check_container_health(_container) do
    # Simulate health check
    Enum.random([:healthy, :healthy, :healthy, :starting, :unhealthy])
  end

  defp get_container_stats(_container) do
    %{
      cpu_percent: :rand.uniform() * 100,
      memory_mb: :rand.uniform(1000),
      network_rx_mb: :rand.uniform(100),
      network_tx_mb: :rand.uniform(50),
      pids: :rand.uniform(100)
    }
  end

  defp container_operation(op, container) do
    Logger.debug("[CEPAFAgent] Container operation", operation: op, container: container)
    {:ok, op}
  end

  defp record_operation(state, op, container, result) do
    operation = %{
      operation: op,
      container: container,
      result: result,
      timestamp: DateTime.utc_now()
    }

    success = match?({:ok, _}, result)

    %{
      state
      | operations: Enum.take([operation | state.operations], 100),
        total_operations: state.total_operations + 1,
        successful_operations: state.successful_operations + if(success, do: 1, else: 0),
        failed_operations: state.failed_operations + if(success, do: 0, else: 1)
    }
  end

  defp publish_container_registered(container_info) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "cepaf/container/registered",
      container_info
    )
  rescue
    _ -> :ok
  end

  defp publish_health_status(health_cache) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "cepaf/health",
      %{
        containers: health_cache,
        timestamp: DateTime.utc_now()
      }
    )
  rescue
    _ -> :ok
  end

  defp container_summary(containers) do
    Enum.map(containers, fn {fqun, info} ->
      %{fqun: fqun, name: info.name, state: info.state}
    end)
  end

  defp health_summary(cache) do
    Enum.reduce(cache, %{healthy: 0, unhealthy: 0, starting: 0, unknown: 0}, fn {_name, health},
                                                                                acc ->
      Map.update(acc, health, 1, &(&1 + 1))
    end)
  end

  defp count_healthy(cache), do: Enum.count(cache, fn {_, h} -> h == :healthy end)
  defp count_unhealthy(cache), do: Enum.count(cache, fn {_, h} -> h == :unhealthy end)

  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(num, denom), do: Float.round(num / denom, 3)
end
