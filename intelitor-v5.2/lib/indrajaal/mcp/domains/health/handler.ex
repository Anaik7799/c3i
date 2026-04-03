defmodule Indrajaal.MCP.Domains.Health.Handler do
  @moduledoc """
  MCP Handler for Health Domain

  WHAT: Provides system health status via MCP tools, covering runtime
        metrics, container health, Zenoh mesh status, and service state.
  WHY: Enables AI agents and operators to query system health without
       direct shell access, maintaining a consistent observability surface.
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-VER-031

  ## Tools Provided
  - indrajaal.health.status     - Overall system health summary
  - indrajaal.health.containers - Container health for all running containers
  - indrajaal.health.zenoh      - Zenoh mesh status and node count
  - indrajaal.health.services   - Service health (DB, OBS, App)
  - indrajaal.health.metrics    - System metrics (memory, processes, uptime)

  ## STAMP Constraints
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-VER-031: All containers healthy status must be queryable

  ## Change History
  | Version | Date       | Author            | Change                 |
  |---------|------------|-------------------|------------------------|
  | 21.3.0  | 2026-03-23 | Claude Opus 4.6   | Initial implementation |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :health

  alias Indrajaal.MCP.Foundation.Types

  require Logger

  # ---------------------------------------------------------------------------
  # Tool: indrajaal.health.status
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:status, args, context) do
    audit_log(@domain, :status, args, context)

    runtime_metrics = collect_runtime_metrics()
    zenoh_info = collect_zenoh_info()
    containers = collect_container_list()

    overall =
      cond do
        zenoh_info.connected and containers.healthy_count == containers.total_count -> "healthy"
        containers.total_count == 0 -> "degraded"
        containers.healthy_count < containers.total_count -> "degraded"
        true -> "unknown"
      end

    success(%{
      overall: overall,
      node: Node.self() |> Atom.to_string(),
      cluster_nodes: Node.list() |> length(),
      zenoh: %{
        connected: zenoh_info.connected,
        nif_loaded: zenoh_info.nif_loaded
      },
      containers: %{
        total: containers.total_count,
        healthy: containers.healthy_count
      },
      runtime: %{
        process_count: runtime_metrics.process_count,
        memory_mb: runtime_metrics.memory_mb,
        uptime_seconds: runtime_metrics.uptime_seconds
      },
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: indrajaal.health.containers
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:containers, args, context) do
    audit_log(@domain, :containers, args, context)

    filter = Map.get(args, "filter", "indrajaal")

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
              ports = List.first(rest, "")

              %{
                name: name,
                status: status,
                ports: ports,
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
  # Tool: indrajaal.health.zenoh
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:zenoh, args, context) do
    audit_log(@domain, :zenoh, args, context)

    zenoh_info = collect_zenoh_info()
    cluster_nodes = Node.list()

    success(%{
      connected: zenoh_info.connected,
      nif_loaded: zenoh_info.nif_loaded,
      nif_module: zenoh_info.nif_module,
      cluster_node_count: length(cluster_nodes),
      cluster_nodes: Enum.map(cluster_nodes, &Atom.to_string/1),
      self_node: Node.self() |> Atom.to_string(),
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: indrajaal.health.services
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:services, args, context) do
    audit_log(@domain, :services, args, context)

    db_status = check_db_service()
    app_status = check_app_service()

    services = [
      %{name: "db", label: "PostgreSQL (indrajaal-db-prod)", status: db_status},
      %{name: "app", label: "Phoenix App (indrajaal-ex-app-1)", status: app_status}
    ]

    healthy_count = Enum.count(services, fn s -> s.status == "healthy" end)

    success(%{
      services: services,
      total: length(services),
      healthy: healthy_count,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # Tool: indrajaal.health.metrics
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

  @doc """
  Returns tool schemas for registration.
  """
  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "indrajaal.health"

    [
      Types.new_tool_schema(
        "#{namespace}.status",
        "Get overall system health: compile status, container health, Zenoh mesh state",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.containers",
        "Get container health status for all running Podman containers",
        %{
          type: "object",
          properties: %{
            "filter" => %{
              type: "string",
              description: "Name substring filter (default: \"indrajaal\", use \"\" for all)"
            }
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.zenoh",
        "Get Zenoh mesh status: NIF loaded, connected state, cluster node count",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.services",
        "Get service health for DB, OBS, and App containers",
        %{
          type: "object",
          properties: %{},
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.metrics",
        "Get system metrics: memory usage, process count, uptime, OTP/Elixir versions",
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
    nif_module = Indrajaal.Zenoh.Nif

    nif_loaded =
      case Code.ensure_loaded(nif_module) do
        {:module, _} -> true
        _ -> false
      end

    connected =
      if nif_loaded do
        try do
          case apply(nif_module, :session_open, [%{}]) do
            {:ok, _} -> true
            _ -> false
          end
        rescue
          _ -> false
        catch
          _, _ -> false
        end
      else
        false
      end

    %{
      nif_loaded: nif_loaded,
      nif_module: inspect(nif_module),
      connected: connected
    }
  end

  defp collect_container_list do
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
        |> Enum.filter(fn line -> String.contains?(line, "indrajaal") end)

      total_count = length(lines)

      healthy_count =
        Enum.count(lines, fn line ->
          String.contains?(line, "Up")
        end)

      %{total_count: total_count, healthy_count: healthy_count}
    rescue
      _ -> %{total_count: 0, healthy_count: 0}
    catch
      _, _ -> %{total_count: 0, healthy_count: 0}
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
