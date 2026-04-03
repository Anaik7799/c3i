#!/usr/bin/env elixir
# ═══════════════════════════════════════════════════════════════════════════════
# CEPAF SERVICE VERIFICATION SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════
#
# Verifies all services are running correctly for standalone distributed mode:
# - Database (PostgreSQL/TimescaleDB)
# - Observability (OpenTelemetry, Prometheus, Grafana)
# - Redis (Cache)
# - EPMD (Erlang Port Mapper)
# - Phoenix Application
# - Erlang Distribution
#
# STAMP Compliance: SC-CLU-001 to SC-CLU-005, SC-OBS-069
#
# Usage:
#   elixir scripts/standalone/verify_services.exs
#   elixir scripts/standalone/verify_services.exs --json
#
# ═══════════════════════════════════════════════════════════════════════════════

defmodule StandaloneVerifier do
  @moduledoc """
  Verifies standalone distributed mode services.
  """

  @services [
    {:database, "PostgreSQL/TimescaleDB", "localhost", 5433},
    {:redis, "Redis Cache", "localhost", 6379},
    {:epmd, "EPMD", "localhost", 4369},
    {:phoenix, "Phoenix HTTP", "localhost", 4000},
    {:otel, "OpenTelemetry gRPC", "localhost", 4317},
    {:prometheus, "Prometheus", "localhost", 9090},
    {:grafana, "Grafana", "localhost", 3000}
  ]

  @colors %{
    green: "\e[32m",
    red: "\e[31m",
    yellow: "\e[33m",
    blue: "\e[34m",
    cyan: "\e[36m",
    reset: "\e[0m"
  }

  def run(args \\ []) do
    json_mode = "--json" in args

    unless json_mode do
      print_header()
    end

    results = verify_all_services()
    container_status = verify_containers()
    erlang_status = verify_erlang_distribution()
    network_mode = detect_network_mode()

    all_results = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      network_mode: network_mode,
      services: results,
      containers: container_status,
      erlang: erlang_status,
      overall: calculate_overall(results, container_status, erlang_status)
    }

    if json_mode do
      IO.puts(Jason.encode!(all_results, pretty: true))
    else
      print_results(all_results)
      print_connection_info(all_results)
    end

    if all_results.overall.healthy do
      System.halt(0)
    else
      System.halt(1)
    end
  end

  defp print_header do
    IO.puts("""
    #{@colors.cyan}═══════════════════════════════════════════════════════════════════════════════#{@colors.reset}
    #{@colors.cyan}  INTELITOR STANDALONE DISTRIBUTED MODE - SERVICE VERIFICATION#{@colors.reset}
    #{@colors.cyan}═══════════════════════════════════════════════════════════════════════════════#{@colors.reset}
    """)
  end

  defp verify_all_services do
    Enum.map(@services, fn {id, name, host, port} ->
      status = check_port(host, port)
      {id, %{name: name, host: host, port: port, status: status}}
    end)
    |> Map.new()
  end

  defp check_port(host, port) do
    case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 2000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        :healthy

      {:error, :econnrefused} ->
        :down

      {:error, :timeout} ->
        :timeout

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_containers do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}\t{{.Status}}"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          case String.split(line, "\t") do
            [name, status] ->
              healthy = String.contains?(status, "healthy") or String.contains?(status, "Up")
              {name, %{status: status, healthy: healthy}}
            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      {error, _} ->
        %{error: error}
    end
  end

  defp verify_erlang_distribution do
    case System.cmd("epmd", ["-names"], stderr_to_stdout: true) do
      {output, 0} ->
        nodes =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&String.contains?(&1, "at port"))
          |> Enum.map(fn line ->
            case Regex.run(~r/name (\w+) at port (\d+)/, line) do
              [_, name, port] -> {name, String.to_integer(port)}
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        %{
          epmd_running: String.contains?(output, "up and running"),
          registered_nodes: nodes,
          node_count: length(nodes)
        }

      {error, _} ->
        %{epmd_running: false, error: error}
    end
  end

  defp detect_network_mode do
    case System.cmd("tailscale", ["status", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"BackendState" => "Running"}} ->
            %{mode: :tailscale, available: true}

          _ ->
            %{mode: :local, available: false}
        end

      _ ->
        %{mode: :local, available: false}
    end
  end

  defp calculate_overall(services, containers, erlang) do
    service_health =
      services
      |> Map.values()
      |> Enum.all?(fn %{status: s} -> s == :healthy end)

    container_health =
      case containers do
        %{error: _} -> false
        containers ->
          containers
          |> Map.values()
          |> Enum.all?(fn %{healthy: h} -> h end)
      end

    erlang_health = Map.get(erlang, :epmd_running, false)

    %{
      healthy: service_health and container_health and erlang_health,
      services_ok: service_health,
      containers_ok: container_health,
      erlang_ok: erlang_health
    }
  end

  defp print_results(results) do
    IO.puts("\n#{@colors.blue}[Services]#{@colors.reset}")

    Enum.each(results.services, fn {_id, svc} ->
      status_color = if svc.status == :healthy, do: @colors.green, else: @colors.red
      status_icon = if svc.status == :healthy, do: "✓", else: "✗"
      IO.puts("  #{status_color}#{status_icon}#{@colors.reset} #{svc.name} (#{svc.host}:#{svc.port})")
    end)

    IO.puts("\n#{@colors.blue}[Containers]#{@colors.reset}")

    case results.containers do
      %{error: error} ->
        IO.puts("  #{@colors.red}✗ Error: #{error}#{@colors.reset}")

      containers ->
        Enum.each(containers, fn {name, info} ->
          status_color = if info.healthy, do: @colors.green, else: @colors.red
          status_icon = if info.healthy, do: "✓", else: "✗"
          IO.puts("  #{status_color}#{status_icon}#{@colors.reset} #{name}: #{info.status}")
        end)
    end

    IO.puts("\n#{@colors.blue}[Erlang Distribution]#{@colors.reset}")

    if results.erlang.epmd_running do
      IO.puts("  #{@colors.green}✓#{@colors.reset} EPMD running on port 4369")
      IO.puts("  #{@colors.green}✓#{@colors.reset} Registered nodes: #{results.erlang.node_count}")

      Enum.each(results.erlang.registered_nodes, fn {name, port} ->
        IO.puts("    - #{name} @ port #{port}")
      end)
    else
      IO.puts("  #{@colors.red}✗#{@colors.reset} EPMD not running")
    end

    IO.puts("\n#{@colors.blue}[Network Mode]#{@colors.reset}")
    mode = results.network_mode.mode
    available = results.network_mode.available
    mode_color = if available, do: @colors.green, else: @colors.yellow
    IO.puts("  #{mode_color}#{mode}#{@colors.reset} (Tailscale: #{if available, do: "connected", else: "not available"})")

    IO.puts("\n#{@colors.blue}[Overall Status]#{@colors.reset}")

    if results.overall.healthy do
      IO.puts("  #{@colors.green}✓ ALL SYSTEMS OPERATIONAL#{@colors.reset}")
    else
      IO.puts("  #{@colors.red}✗ SOME SERVICES DOWN#{@colors.reset}")

      unless results.overall.services_ok, do: IO.puts("    - Service ports not responding")
      unless results.overall.containers_ok, do: IO.puts("    - Container health issues")
      unless results.overall.erlang_ok, do: IO.puts("    - EPMD not running")
    end
  end

  defp print_connection_info(results) do
    return unless results.overall.healthy

    cookie = System.get_env("RELEASE_COOKIE") || File.read!(Path.expand("~/.erlang.cookie")) |> String.trim()
    ip = get_ip()

    IO.puts("""

    #{@colors.cyan}═══════════════════════════════════════════════════════════════════════════════#{@colors.reset}
    #{@colors.cyan}  REMOTE ACCESS INFORMATION#{@colors.reset}
    #{@colors.cyan}═══════════════════════════════════════════════════════════════════════════════#{@colors.reset}

    #{@colors.green}Livebook Connection (Windows):#{@colors.reset}
      $env:LIVEBOOK_COOKIE = "#{cookie}"
      livebook server

      Then: Runtime → Attached node
        Name:   indrajaal@#{ip}
        Cookie: #{cookie}

    #{@colors.green}IEx Remote Shell:#{@colors.reset}
      iex --name client@#{ip} --cookie #{cookie} --remsh indrajaal@#{ip}

    #{@colors.green}API Access:#{@colors.reset}
      http://#{ip}:4000/api/v1/health

    #{@colors.cyan}═══════════════════════════════════════════════════════════════════════════════#{@colors.reset}
    """)
  rescue
    _ -> :ok
  end

  defp get_ip do
    case System.cmd("hostname", ["-I"]) do
      {output, 0} -> output |> String.split() |> List.first() || "localhost"
      _ -> "localhost"
    end
  end
end

# Add Jason for JSON output
Mix.install([:jason])

StandaloneVerifier.run(System.argv())
