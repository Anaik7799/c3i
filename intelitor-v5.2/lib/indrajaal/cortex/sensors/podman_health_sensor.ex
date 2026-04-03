defmodule Indrajaal.Cortex.Sensors.PodmanHealthSensor do
  @moduledoc """
  Podman Container Health Sensor for Cortex.

  Polls container health status via Podman socket and emits telemetry events
  for health status changes. Integrates with the Cortex stress scoring system.

  WHAT:
    - Monitors container health via Podman REST API over Unix socket
    - Tracks health status changes per container
    - Provides aggregated health metrics for OODA loop observation
    - Supports configurable polling intervals

  WHY:
    - Enables proactive detection of container health issues
    - Provides real-time container health metrics for stress scoring
    - Integrates with F# Cepaf.Podman health probes architecture
    - Supports autonomous self-healing decisions

  CONSTRAINTS:
    - SC-CNT-009: Container OS must be NixOS/Podman
    - SC-CNT-012: Rootless execution required
    - SC-OBS-069: Dual logging (Terminal + SigNoz)
    - SC-PRF-050: Response < 50ms for health checks

  Integration with Cepaf.Podman:
    - Both access Podman socket directly (F# and Elixir)
    - Health status types aligned: Healthy, Unhealthy, Starting, NoHealthcheck
    - Compatible with Cepaf.Podman.Health.Probes API

  Usage:
      PodmanHealthSensor.start_link()
      PodmanHealthSensor.measure()
      PodmanHealthSensor.get_container_health("indrajaal-app")
      PodmanHealthSensor.get_health_summary()
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.Sensors.ContainerHealthTelemetry, as: Telemetry

  # Default Podman socket paths (aligned with Cepaf.Podman.Domain.PodmanSocket)
  @default_rootless_socket_path "/run/user/1000/podman/podman.sock"
  @default_rootful_socket_path "/run/podman/podman.sock"

  # Polling interval (aligned with Cepaf.Podman.Health.ProbeConfig.defaults: 30s)
  @default_poll_interval_ms 30_000

  # Health check timeout (aligned with Cepaf.Podman ProbeConfig)
  @health_check_timeout_ms 30_000

  # Health status types (aligned with Cepaf.Podman.Domain.HealthStatus)
  @type health_status ::
          :healthy
          | :unhealthy
          | :starting
          | :no_healthcheck
          | {:unknown, String.t()}

  @type container_health :: %{
          container_id: String.t(),
          container_name: String.t(),
          status: health_status(),
          message: String.t() | nil,
          timestamp: DateTime.t(),
          duration_ms: float(),
          failing_streak: non_neg_integer()
        }

  @type health_summary :: %{
          total: non_neg_integer(),
          healthy: non_neg_integer(),
          unhealthy: non_neg_integer(),
          starting: non_neg_integer(),
          no_healthcheck: non_neg_integer(),
          timestamp: DateTime.t()
        }

  # State
  defstruct [
    :socket_path,
    :poll_interval_ms,
    :last_poll,
    :poll_count,
    :failure_count,
    :container_health,
    :previous_health,
    :started_at,
    :enabled
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current health measurement for Cortex OODA loop.
  Returns a map with aggregated health metrics.
  """
  @spec measure() :: map()
  def measure do
    GenServer.call(__MODULE__, :measure, @health_check_timeout_ms)
  end

  @doc """
  Get health status for a specific container.
  """
  @spec get_container_health(String.t()) :: {:ok, container_health()} | {:error, :not_found}
  def get_container_health(container_name_or_id) do
    GenServer.call(__MODULE__, {:get_container_health, container_name_or_id})
  end

  @doc """
  Get aggregated health summary for all monitored containers.
  """
  @spec get_health_summary() :: health_summary()
  def get_health_summary do
    GenServer.call(__MODULE__, :get_health_summary)
  end

  @doc """
  Force an immediate health poll.
  """
  @spec poll_now() :: :ok
  def poll_now do
    GenServer.cast(__MODULE__, :poll_now)
  end

  @doc """
  Get the current sensor state.
  """
  @spec get_state() :: map()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Check if all containers are healthy.
  """
  @spec all_healthy?() :: boolean()
  def all_healthy? do
    GenServer.call(__MODULE__, :all_healthy?)
  end

  @doc """
  Get list of unhealthy containers.
  """
  @spec get_unhealthy() :: [container_health()]
  def get_unhealthy do
    GenServer.call(__MODULE__, :get_unhealthy)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("PodmanHealthSensor: Initializing Podman container health monitoring")

    socket_path = detect_socket_path(opts)
    poll_interval = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)
    enabled = Keyword.get(opts, :enabled, true)

    state = %__MODULE__{
      socket_path: socket_path,
      poll_interval_ms: poll_interval,
      last_poll: nil,
      poll_count: 0,
      failure_count: 0,
      container_health: %{},
      previous_health: %{},
      started_at: DateTime.utc_now(),
      enabled: enabled
    }

    if enabled and socket_available?(socket_path) do
      Logger.info("PodmanHealthSensor: Socket available at #{socket_path}")
      # Schedule initial poll
      send(self(), :poll)
      schedule_poll(poll_interval)
      {:ok, state}
    else
      Logger.warning(
        "PodmanHealthSensor: Socket not available at #{socket_path}, running in degraded mode"
      )

      {:ok, %{state | enabled: false}}
    end
  end

  @impl true
  def handle_call(:measure, _from, state) do
    measurement = build_measurement(state)
    {:reply, measurement, state}
  end

  @impl true
  def handle_call({:get_container_health, name_or_id}, _from, state) do
    result = find_container_health(state.container_health, name_or_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_health_summary, _from, state) do
    summary = build_health_summary(state.container_health)
    {:reply, summary, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state_map = %{
      socket_path: state.socket_path,
      poll_interval_ms: state.poll_interval_ms,
      last_poll: state.last_poll,
      poll_count: state.poll_count,
      failure_count: state.failure_count,
      container_count: map_size(state.container_health),
      started_at: state.started_at,
      enabled: state.enabled
    }

    {:reply, state_map, state}
  end

  @impl true
  def handle_call(:all_healthy?, _from, state) do
    all_healthy =
      state.container_health
      |> Map.values()
      |> Enum.all?(fn h ->
        h.status in [:healthy, :no_healthcheck]
      end)

    {:reply, all_healthy, state}
  end

  @impl true
  def handle_call(:get_unhealthy, _from, state) do
    unhealthy =
      state.container_health
      |> Map.values()
      |> Enum.filter(fn h -> h.status == :unhealthy end)

    {:reply, unhealthy, state}
  end

  @impl true
  def handle_cast(:poll_now, state) do
    new_state = do_poll(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state =
      if state.enabled do
        do_poll(state)
      else
        state
      end

    schedule_poll(state.poll_interval_ms)
    {:noreply, new_state}
  end

  ## Private Functions

  defp detect_socket_path(opts) do
    cond do
      Keyword.has_key?(opts, :socket_path) ->
        Keyword.get(opts, :socket_path)

      File.exists?(@default_rootless_socket_path) ->
        @default_rootless_socket_path

      File.exists?(@default_rootful_socket_path) ->
        @default_rootful_socket_path

      true ->
        # Try to detect from UID
        uid = System.get_env("UID") || "1000"
        "/run/user/#{uid}/podman/podman.sock"
    end
  end

  defp socket_available?(socket_path) do
    File.exists?(socket_path)
  end

  defp schedule_poll(interval_ms) do
    Process.send_after(self(), :poll, interval_ms)
  end

  defp do_poll(state) do
    start_time = System.monotonic_time(:millisecond)

    Logger.debug("PodmanHealthSensor: Polling container health")

    case poll_containers(state.socket_path) do
      {:ok, containers} ->
        health_results = check_all_health(state.socket_path, containers)
        duration_ms = System.monotonic_time(:millisecond) - start_time

        # Detect health changes and emit telemetry
        detect_and_emit_changes(state.previous_health, health_results)

        new_state = %{
          state
          | container_health: health_results,
            previous_health: state.container_health,
            last_poll: DateTime.utc_now(),
            poll_count: state.poll_count + 1
        }

        # Emit poll complete telemetry
        emit_poll_telemetry(health_results, duration_ms)

        Logger.debug(
          "PodmanHealthSensor: Poll complete in #{duration_ms}ms, #{map_size(health_results)} containers"
        )

        new_state

      {:error, reason} ->
        Logger.warning("PodmanHealthSensor: Poll failed: #{inspect(reason)}")

        %{state | failure_count: state.failure_count + 1}
    end
  end

  defp poll_containers(socket_path) do
    # Query Podman API for running containers
    endpoint = "/v5.0.0/libpod/containers/json"

    case http_request_unix(socket_path, "GET", endpoint) do
      {:ok, body} ->
        parse_container_list(body)

      {:error, _} = error ->
        error
    end
  end

  defp check_all_health(socket_path, containers) do
    containers
    |> Enum.map(fn container ->
      health = check_container_health(socket_path, container)
      {container["Id"], health}
    end)
    |> Map.new()
  end

  defp check_container_health(socket_path, container) do
    container_id = container["Id"]
    container_name = extract_container_name(container)
    start_time = System.monotonic_time(:millisecond)

    # First try healthcheck endpoint
    health_result = query_health_status(socket_path, container_id)
    duration_ms = (System.monotonic_time(:millisecond) - start_time) / 1.0

    %{
      container_id: container_id,
      container_name: container_name,
      status: health_result.status,
      message: health_result.message,
      timestamp: DateTime.utc_now(),
      duration_ms: duration_ms,
      failing_streak: health_result.failing_streak
    }
  end

  defp query_health_status(socket_path, container_id) do
    # Try the healthcheck endpoint
    endpoint = "/v5.0.0/libpod/containers/#{container_id}/healthcheck"

    case http_request_unix(socket_path, "GET", endpoint) do
      {:ok, body} ->
        parse_health_response(body)

      {:error, :not_found} ->
        # No healthcheck configured - check if container is running
        check_running_status(socket_path, container_id)

      {:error, reason} ->
        %{status: {:unknown, inspect(reason)}, message: inspect(reason), failing_streak: 0}
    end
  end

  defp check_running_status(socket_path, container_id) do
    endpoint = "/v5.0.0/libpod/containers/#{container_id}/json"

    case http_request_unix(socket_path, "GET", endpoint) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"State" => %{"Running" => true}}} ->
            %{
              status: :no_healthcheck,
              message: "Container running (no healthcheck)",
              failing_streak: 0
            }

          {:ok, %{"State" => %{"Running" => false}}} ->
            %{status: :unhealthy, message: "Container not running", failing_streak: 1}

          _ ->
            %{status: :no_healthcheck, message: nil, failing_streak: 0}
        end

      {:error, _} ->
        %{status: :no_healthcheck, message: nil, failing_streak: 0}
    end
  end

  defp parse_health_response(body) do
    case Jason.decode(body) do
      {:ok, %{"Status" => status} = data} ->
        parsed_status = parse_health_status(status)
        failing_streak = Map.get(data, "FailingStreak", 0)
        message = get_health_log_message(data)

        %{status: parsed_status, message: message, failing_streak: failing_streak}

      {:ok, _} ->
        %{status: :no_healthcheck, message: nil, failing_streak: 0}

      {:error, _} ->
        %{
          status: {:unknown, "parse_error"},
          message: "Failed to parse health response",
          failing_streak: 0
        }
    end
  end

  defp parse_health_status(status) when is_binary(status) do
    case String.downcase(status) do
      "healthy" -> :healthy
      "unhealthy" -> :unhealthy
      "starting" -> :starting
      "none" -> :no_healthcheck
      "" -> :no_healthcheck
      other -> {:unknown, other}
    end
  end

  defp parse_health_status(_), do: :no_healthcheck

  defp get_health_log_message(%{"Log" => [last_log | _]}) when is_map(last_log) do
    Map.get(last_log, "Output", nil)
  end

  defp get_health_log_message(_), do: nil

  defp parse_container_list(body) do
    case Jason.decode(body) do
      {:ok, containers} when is_list(containers) ->
        # Filter to intelitor containers if label present, else all
        filtered =
          containers
          |> Enum.filter(fn c ->
            labels = Map.get(c, "Labels", %{}) || %{}
            # Include all containers for now, can filter by label later
            is_map(labels)
          end)

        {:ok, filtered}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, {:json_decode, reason}}
    end
  end

  defp extract_container_name(container) do
    case container do
      %{"Names" => [name | _]} when is_binary(name) ->
        String.trim_leading(name, "/")

      %{"Name" => name} when is_binary(name) ->
        String.trim_leading(name, "/")

      _ ->
        container["Id"] || "unknown"
    end
  end

  defp http_request_unix(socket_path, method, endpoint) do
    # Use curl with Unix socket for HTTP request
    # This is a simple implementation; production would use a proper HTTP client
    args = [
      "--unix-socket",
      socket_path,
      "-s",
      "-X",
      method,
      "http://localhost#{endpoint}"
    ]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {body, 0} ->
        if String.contains?(body, "\"cause\":\"no such container\"") or
             String.contains?(body, "404 page not found") do
          {:error, :not_found}
        else
          {:ok, body}
        end

      {error, _code} ->
        {:error, {:curl_failed, error}}
    end
  rescue
    e -> {:error, {:exception, Exception.message(e)}}
  end

  defp find_container_health(health_map, name_or_id) do
    result =
      health_map
      |> Enum.find(fn {id, health} ->
        id == name_or_id or health.container_name == name_or_id
      end)

    case result do
      {_id, health} -> {:ok, health}
      nil -> {:error, :not_found}
    end
  end

  defp build_measurement(state) do
    summary = build_health_summary(state.container_health)

    # Compute cluster status for stress analyzer
    cluster_status =
      cond do
        not state.enabled -> :degraded
        summary.unhealthy > 0 -> :unhealthy
        summary.starting > 0 -> :starting
        true -> :healthy
      end

    # Compute health ratio
    health_ratio =
      if summary.total > 0 do
        (summary.healthy + summary.no_healthcheck) / summary.total
      else
        1.0
      end

    %{
      # For Cortex stress scoring
      healthy: summary.unhealthy == 0 and summary.starting == 0,
      container_health_ratio: health_ratio,

      # Detailed metrics
      containers_total: summary.total,
      containers_healthy: summary.healthy,
      containers_unhealthy: summary.unhealthy,
      containers_starting: summary.starting,
      containers_no_healthcheck: summary.no_healthcheck,

      # Sensor metadata
      last_poll: state.last_poll,
      poll_count: state.poll_count,
      failure_count: state.failure_count,
      enabled: state.enabled,

      # For stress analyzer
      cluster_status: cluster_status
    }
  end

  defp build_health_summary(health_map) do
    containers = Map.values(health_map)

    %{
      total: length(containers),
      healthy: Enum.count(containers, fn h -> h.status == :healthy end),
      unhealthy: Enum.count(containers, fn h -> h.status == :unhealthy end),
      starting: Enum.count(containers, fn h -> h.status == :starting end),
      no_healthcheck: Enum.count(containers, fn h -> h.status == :no_healthcheck end),
      timestamp: DateTime.utc_now()
    }
  end

  defp detect_and_emit_changes(previous_health, current_health) do
    # Detect containers with status changes
    Enum.each(current_health, fn {container_id, current} ->
      case Map.get(previous_health, container_id) do
        nil ->
          # New container
          emit_health_event(:container_discovered, current)

        previous when previous.status != current.status ->
          # Status changed
          emit_health_change(previous, current)

        _ ->
          # No change
          :ok
      end
    end)

    # Detect removed containers
    Enum.each(previous_health, fn {container_id, previous} ->
      unless Map.has_key?(current_health, container_id) do
        emit_health_event(:container_removed, previous)
      end
    end)
  end

  defp emit_health_change(previous, current) do
    Logger.info(
      "PodmanHealthSensor: Container #{current.container_name} health changed: " <>
        "#{inspect(previous.status)} -> #{inspect(current.status)}"
    )

    emit_health_event(:health_changed, current, %{previous_status: previous.status})

    # Emit specific events for unhealthy transitions
    case current.status do
      :unhealthy ->
        Telemetry.emit_stamp_violation(
          "SC-CNT-HEALTH",
          "Container #{current.container_name} is unhealthy: #{current.message}",
          :warning
        )

      :healthy when previous.status == :unhealthy ->
        Logger.info(
          "PodmanHealthSensor: Container #{current.container_name} recovered to healthy"
        )

      _ ->
        :ok
    end
  end

  defp emit_health_event(event_type, health, extra_metadata \\ %{}) do
    :telemetry.execute(
      [:indrajaal, :container, :podman, :health, event_type],
      %{
        duration_ms: health.duration_ms,
        failing_streak: health.failing_streak,
        system_time: System.system_time(:millisecond)
      },
      Map.merge(
        %{
          container_id: health.container_id,
          container_name: health.container_name,
          status: health.status,
          message: health.message,
          node: Node.self()
        },
        extra_metadata
      )
    )
  end

  defp emit_poll_telemetry(health_results, duration_ms) do
    summary = build_health_summary(health_results)

    :telemetry.execute(
      [:indrajaal, :container, :podman, :poll, :complete],
      %{
        duration_ms: duration_ms,
        container_count: summary.total,
        healthy_count: summary.healthy,
        unhealthy_count: summary.unhealthy,
        system_time: System.system_time(:millisecond)
      },
      %{node: Node.self()}
    )
  end
end
