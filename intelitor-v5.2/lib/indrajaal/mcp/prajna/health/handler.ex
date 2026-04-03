defmodule Indrajaal.MCP.Prajna.Health.Handler do
  @moduledoc """
  MCP Handler for Prajna Health — Zenoh Mesh Status + Container Health

  WHAT: Provides real-time health data covering Zenoh mesh connectivity,
        container status, OTP runtime metrics, and service availability.
        Tools are namespaced under prajna.health.* for C3I cockpit access.
  WHY:  Operators and AI agents need a unified health surface without
        direct shell access. This handler satisfies SC-VER-031 (all containers
        healthy status queryable) and SC-ZENOH-007 (Zenoh health in /health).
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-VER-031, SC-ZENOH-007, SC-MON-001

  ## Tools Provided
  - prajna.health.status     - Overall health summary (Zenoh + containers + runtime)
  - prajna.health.zenoh      - Zenoh NIF status, connection state, cluster node count
  - prajna.health.containers - Container list with running/stopped status
  - prajna.health.services   - DB, OBS, App service availability
  - prajna.health.metrics    - OTP memory, processes, uptime, scheduler count

  ## STAMP Constraints
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-VER-031: All containers healthy status MUST be queryable
  - SC-ZENOH-007: Zenoh health MUST be included in observable surface
  - SC-MON-001: Metrics refresh target 30s

  ## Change History
  | Version | Date       | Author          | Change                  |
  |---------|------------|-----------------|-------------------------|
  | 21.3.0  | 2026-03-23 | Claude Opus 4.6 | Initial implementation  |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :health, namespace: :prajna

  alias Indrajaal.MCP.Foundation.Types

  require Logger

  # ---------------------------------------------------------------------------
  # Tool: prajna.health.status
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:status, args, context) do
    audit_log(@domain, :status, args, context)

    runtime = collect_runtime_metrics()
    zenoh = collect_zenoh_info()
    containers = collect_container_summary()
    sentinel_health = collect_sentinel_health()

    overall =
      cond do
        sentinel_health.score >= 80 and zenoh.connected -> "healthy"
        sentinel_health.score >= 60 -> "degraded"
        containers.total == 0 -> "degraded"
        true -> "unknown"
      end

    success(%{
      overall: overall,
      node: Node.self() |> Atom.to_string(),
      cluster_nodes: Node.list() |> length(),
      sentinel: %{
        health_score: sentinel_health.score,
        status: sentinel_health.status,
        threats: sentinel_health.threats
      },
      zenoh: %{
        connected: zenoh.connected,
        nif_loaded: zenoh.nif_loaded,
        nif_module: zenoh.nif_module
      },
      containers: %{
        total: containers.total,
        healthy: containers.healthy
      },
      runtime: %{
        process_count: runtime.process_count,
        memory_mb: runtime.memory_mb,
        uptime_seconds: runtime.uptime_seconds
      },
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: prajna.health.zenoh
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:zenoh, args, context) do
    audit_log(@domain, :zenoh, args, context)

    zenoh = collect_zenoh_info()
    cluster_nodes = Node.list()

    success(%{
      connected: zenoh.connected,
      nif_loaded: zenoh.nif_loaded,
      nif_module: zenoh.nif_module,
      zenoh_enabled_env: System.get_env("ZENOH_ENABLED", "not_set"),
      skip_nif_env: System.get_env("SKIP_ZENOH_NIF", "not_set"),
      cluster_node_count: length(cluster_nodes),
      cluster_nodes: Enum.map(cluster_nodes, &Atom.to_string/1),
      self_node: Node.self() |> Atom.to_string(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: prajna.health.containers
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:containers, args, context) do
    audit_log(@domain, :containers, args, context)

    filter = Map.get(args, "filter") || Map.get(args, :filter, "indrajaal")

    containers =
      try do
        {output, 0} =
          System.cmd("podman", [
            "ps",
            "--all",
            "--format",
            "{{.Names}}\t{{.Status}}\t{{.Ports}}"
          ])

        output
        |> String.trim()
        |> String.split("\n", trim: true)
        |> Enum.filter(fn line ->
          filter == "" or String.contains?(line, filter)
        end)
        |> Enum.map(fn line ->
          case String.split(line, "\t") do
            [name, status | rest] ->
              %{
                name: name,
                status: status,
                ports: List.first(rest, ""),
                healthy: String.contains?(status, "Up")
              }

            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      rescue
        _ -> []
      catch
        _, _ -> []
      end

    healthy_count = Enum.count(containers, & &1.healthy)

    success(%{
      containers: containers,
      total: length(containers),
      healthy: healthy_count,
      filter: filter,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: prajna.health.services
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:services, args, context) do
    audit_log(@domain, :services, args, context)

    db_status = check_db_service()
    app_status = check_app_service()
    zenoh_status = if collect_zenoh_info().nif_loaded, do: "loaded", else: "not_loaded"

    services = [
      %{name: "db", label: "PostgreSQL (indrajaal-db-prod)", status: db_status},
      %{name: "app", label: "Phoenix (indrajaal-ex-app-1)", status: app_status},
      %{name: "zenoh_nif", label: "Zenoh NIF", status: zenoh_status}
    ]

    healthy_count =
      Enum.count(services, fn s -> s.status in ["healthy", "loaded"] end)

    success(%{
      services: services,
      total: length(services),
      healthy: healthy_count,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: prajna.health.metrics
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:metrics, args, context) do
    audit_log(@domain, :metrics, args, context)

    metrics = collect_runtime_metrics()

    success(%{
      process_count: metrics.process_count,
      memory_mb: metrics.memory_mb,
      memory_bytes: metrics.memory_bytes,
      uptime_seconds: metrics.uptime_seconds,
      uptime_human: format_uptime(metrics.uptime_seconds),
      schedulers: metrics.schedulers,
      otp_release: metrics.otp_release,
      elixir_version: metrics.elixir_version,
      node: Node.self() |> Atom.to_string(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  @impl true
  def handle(action, args, context) do
    audit_log(@domain, action, args, context)
    not_implemented(action)
  end

  # ---------------------------------------------------------------------------
  # list_tools/0
  # ---------------------------------------------------------------------------

  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "prajna.health"

    [
      Types.new_tool_schema(
        "#{namespace}.status",
        "Overall system health: Sentinel score, Zenoh mesh state, container status, OTP runtime",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.zenoh",
        "Zenoh mesh status: NIF loaded flag, connection state, cluster node count, env vars",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.containers",
        "Container health for running Podman containers (default filter: indrajaal)",
        %{
          type: "object",
          properties: %{
            "filter" => %{
              type: "string",
              description: "Name substring filter (default: \"indrajaal\", empty string for all)"
            }
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.services",
        "Service availability for DB, Phoenix app, and Zenoh NIF",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.metrics",
        "OTP runtime metrics: memory usage, process count, uptime, schedulers, versions",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      )
    ]
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp collect_runtime_metrics do
    process_count = :erlang.system_info(:process_count)
    memory_bytes = :erlang.memory(:total)
    memory_mb = Float.round(memory_bytes / 1_048_576, 2)
    {wall_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(wall_ms, 1_000)
    schedulers = :erlang.system_info(:schedulers)
    otp_release = :erlang.system_info(:otp_release) |> List.to_string()
    elixir_version = System.version()

    %{
      process_count: process_count,
      memory_bytes: memory_bytes,
      memory_mb: memory_mb,
      uptime_seconds: uptime_seconds,
      schedulers: schedulers,
      otp_release: otp_release,
      elixir_version: elixir_version
    }
  end

  defp collect_zenoh_info do
    nif_module = Indrajaal.Native.Zenoh

    nif_loaded =
      case Code.ensure_loaded(nif_module) do
        {:module, _} ->
          function_exported?(nif_module, :open_session, 1)

        _ ->
          false
      end

    connected =
      if nif_loaded do
        try do
          # Check if a session or process is actually active
          case GenServer.whereis(Indrajaal.Observability.ZenohSession) do
            nil -> false
            _pid -> true
          end
        rescue
          _ -> false
        catch
          _, _ -> false
        end
      else
        # Fallback: check env var
        System.get_env("ZENOH_ENABLED") == "true"
      end

    %{
      nif_loaded: nif_loaded,
      nif_module: inspect(nif_module),
      connected: connected
    }
  end

  defp collect_container_summary do
    try do
      {output, 0} =
        System.cmd("podman", [
          "ps",
          "--all",
          "--format",
          "{{.Names}}\t{{.Status}}"
        ])

      lines =
        output
        |> String.trim()
        |> String.split("\n", trim: true)
        |> Enum.filter(&String.contains?(&1, "indrajaal"))

      healthy =
        Enum.count(lines, &String.contains?(&1, "Up"))

      %{total: length(lines), healthy: healthy}
    rescue
      _ -> %{total: 0, healthy: 0}
    catch
      _, _ -> %{total: 0, healthy: 0}
    end
  end

  defp collect_sentinel_health do
    sentinel_module = Indrajaal.Safety.Sentinel

    try do
      case GenServer.whereis(sentinel_module) do
        nil ->
          %{score: 50, status: "offline", threats: 0}

        _pid ->
          case sentinel_module.get_health() do
            {:ok, health} ->
              %{
                score: Map.get(health, :score, 50),
                status: Map.get(health, :status, "unknown") |> to_string(),
                threats: Map.get(health, :active_threats, 0)
              }

            _ ->
              %{score: 50, status: "unknown", threats: 0}
          end
      end
    rescue
      _ -> %{score: 50, status: "unavailable", threats: 0}
    catch
      :exit, _ -> %{score: 50, status: "noproc", threats: 0}
      _, _ -> %{score: 50, status: "error", threats: 0}
    end
  end

  defp check_db_service do
    try do
      case Ecto.Adapters.SQL.query(Indrajaal.Repo, "SELECT 1", []) do
        {:ok, _} -> "healthy"
        _ -> "unhealthy"
      end
    rescue
      _ -> "unavailable"
    catch
      _, _ -> "unavailable"
    end
  end

  defp check_app_service do
    if Process.whereis(Indrajaal.Endpoint) != nil do
      "healthy"
    else
      "unhealthy"
    end
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86_400)
    remaining = rem(seconds, 86_400)
    hours = div(remaining, 3_600)
    remaining2 = rem(remaining, 3_600)
    minutes = div(remaining2, 60)
    secs = rem(remaining2, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m #{secs}s"
      hours > 0 -> "#{hours}h #{minutes}m #{secs}s"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end
end
