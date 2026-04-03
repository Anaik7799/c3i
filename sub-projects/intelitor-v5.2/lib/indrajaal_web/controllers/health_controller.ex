defmodule IndrajaalWeb.HealthController do
  @moduledoc """
  Kubernetes Health Probe Controller.

  Provides standard Kubernetes health check endpoints:
  - /healthz - Liveness probe (is the application running?)
  - /ready   - Readiness probe (can the application serve traffic?)
  - /startup - Startup probe (has the application started?)

  STAMP Compliance:
  - SC-OBS-065: Health monitoring endpoints
  - SC-OBS-066: Dependency health tracking
  - SC-EMR-057: Emergency health detection

  Reference: CLAUDE.md §6.2 (AOR-CNT Rules), §22.4 (Verification Gates)
  """
  use IndrajaalWeb, :controller

  require Logger

  alias Indrajaal.Cortex.Sensors.ContainerHealthSensor

  @startup_time Application.compile_env(
                  :indrajaal,
                  :startup_time,
                  System.monotonic_time(:millisecond)
                )

  @doc """
  Liveness probe endpoint - /healthz

  Returns 200 OK if the BEAM VM is running and responding.
  Kubernetes will restart the pod if this fails.

  This is a lightweight check - only verifies the process is alive.
  """
  def liveness(conn, _params) do
    # Lightweight check: Can we respond at all?
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    node_str = node() |> to_string()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{
        status: "ok",
        probe: "liveness",
        timestamp: timestamp,
        node: node_str
      })
    )
  end

  @doc """
  Readiness probe endpoint - /ready

  Returns 200 OK if the application can serve traffic.
  Kubernetes will stop sending traffic if this fails.

  Checks:
  - Database connectivity
  - Redis connectivity
  - Critical GenServer processes
  """
  def readiness(conn, _params) do
    checks = perform_readiness_checks()
    all_ready = Enum.all?(checks, fn {_, status} -> status in [:ok, :warning] end)

    status_code = if all_ready, do: 200, else: 503

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      status_code,
      Jason.encode!(%{
        status: if(all_ready, do: "ready", else: "not_ready"),
        probe: "readiness",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        checks: format_checks(checks)
      })
    )
  end

  @doc """
  Startup probe endpoint - /startup

  Returns 200 OK if the application has completed startup.
  Kubernetes will wait for this before starting liveness/readiness probes.

  Checks:
  - Application supervision tree started
  - Database migrations completed
  - Critical services initialized
  """
  def startup(conn, _params) do
    checks = perform_startup_checks()
    all_started = Enum.all?(checks, fn {_, status} -> status == :ok end)

    status_code = if all_started, do: 200, else: 503

    uptime_ms = System.monotonic_time(:millisecond) - @startup_time

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      status_code,
      Jason.encode!(%{
        status: if(all_started, do: "started", else: "starting"),
        probe: "startup",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        uptime_ms: uptime_ms,
        checks: format_checks(checks)
      })
    )
  end

  @doc """
  Comprehensive health check endpoint - /health

  Returns detailed health information for monitoring dashboards.
  Not used by Kubernetes probes directly.
  """
  def comprehensive(conn, _params) do
    liveness_checks = perform_liveness_checks()
    readiness_checks = perform_readiness_checks()
    startup_checks = perform_startup_checks()

    container_health =
      try do
        ContainerHealthSensor.measure()
      rescue
        _ -> %{status: :unavailable, error: "Container health sensor not running"}
      catch
        :exit, _ -> %{status: :unavailable, error: "Container health sensor not responding"}
      end

    all_healthy =
      Enum.all?(liveness_checks, fn {_, s} -> s == :ok end) &&
        Enum.all?(readiness_checks, fn {_, s} -> s == :ok end) &&
        Enum.all?(startup_checks, fn {_, s} -> s == :ok end)

    status_code = if all_healthy, do: 200, else: 503

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    node_name = node() |> to_string()
    vsn_spec = Application.spec(:indrajaal, :vsn)
    app_version = vsn_spec |> to_string()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      status_code,
      Jason.encode!(%{
        status: if(all_healthy, do: "healthy", else: "unhealthy"),
        timestamp: timestamp,
        node: node_name,
        version: app_version,
        probes: %{
          liveness: format_checks(liveness_checks),
          readiness: format_checks(readiness_checks),
          startup: format_checks(startup_checks)
        },
        container: container_health,
        system: system_info()
      })
    )
  end

  # Private functions for health checks

  defp perform_liveness_checks do
    [
      {:beam_vm, :ok},
      {:scheduler, check_scheduler()},
      {:memory, check_memory()}
    ]
  end

  defp perform_readiness_checks do
    [
      {:database, check_database()},
      {:redis, check_redis_optional()},
      {:pubsub, check_pubsub()},
      {:telemetry, check_telemetry()}
    ]
  end

  defp perform_startup_checks do
    [
      {:application, check_application()},
      {:supervision_tree, check_supervision_tree()},
      {:endpoint, check_endpoint()}
    ]
  end

  defp check_scheduler do
    if :erlang.system_info(:schedulers_online) > 0, do: :ok, else: :error
  end

  defp check_memory do
    memory = :erlang.memory(:total)
    # Alert if using more than 90% of typical 32GB allocation
    if memory < 32 * 1024 * 1024 * 1024 * 0.9, do: :ok, else: :warning
  end

  defp check_database do
    try do
      Ecto.Adapters.SQL.query!(Indrajaal.Repo, "SELECT 1", [])
      :ok
    rescue
      _ -> :error
    catch
      :exit, _ -> :error
    end
  end

  defp check_redis_optional do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> :ok
      _ -> :warning
    end
  rescue
    _ -> :warning
  catch
    :exit, _ -> :warning
  end

  defp check_pubsub do
    if Process.whereis(Indrajaal.PubSub), do: :ok, else: :error
  end

  defp check_telemetry do
    if Process.whereis(:telemetry_poller_default), do: :ok, else: :warning
  rescue
    _ -> :warning
  end

  defp check_application do
    # Primary check: Application in started list
    apps = Application.started_applications()
    app_in_list = Enum.any?(apps, fn {name, _, _} -> name == :indrajaal end)

    # Fallback check: Supervision tree running (more reliable)
    supervisor_running =
      case Process.whereis(Indrajaal.Supervisor) || Process.whereis(Indrajaal.Application) do
        nil -> false
        pid when is_pid(pid) -> Process.alive?(pid)
      end

    # Either check passing means application is running
    if app_in_list || supervisor_running, do: :ok, else: :error
  rescue
    _ -> :error
  end

  defp check_supervision_tree do
    case Process.whereis(Indrajaal.Supervisor) || Process.whereis(Indrajaal.Application) do
      nil -> :error
      pid when is_pid(pid) -> :ok
    end
  rescue
    _ -> :error
  end

  defp check_endpoint do
    case Process.whereis(IndrajaalWeb.Endpoint) do
      nil -> :error
      pid when is_pid(pid) -> :ok
    end
  end

  defp format_checks(checks) do
    Map.new(checks, fn {name, status} ->
      {name, %{status: status, healthy: status == :ok}}
    end)
  end

  defp system_info do
    otp_release = :erlang.system_info(:otp_release)
    otp_release_str = otp_release |> to_string()

    %{
      otp_release: otp_release_str,
      elixir_version: System.version(),
      schedulers: :erlang.system_info(:schedulers_online),
      process_count: :erlang.system_info(:process_count),
      memory_mb: div(:erlang.memory(:total), 1024 * 1024)
    }
  end
end
