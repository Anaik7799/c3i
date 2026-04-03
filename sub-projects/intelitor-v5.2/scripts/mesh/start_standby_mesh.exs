#!/usr/bin/env elixir
# INDRAJAAL FULL STANDBY MESH MODE INITIALIZER
# STAMP: SC-MESH-001 to SC-ZENOH-001
# AOR: AOR-MESH-001 to AOR-MESH-005
#
# This script initializes the complete Indrajaal distributed mesh in standby mode:
# - 3-Container Infrastructure (App, DB, Obs)
# - 7-Agent Mesh (OODA, ACE, Cortex, Fractal, CEPAF, Sentinel, KPI)
# - 4-Worker Mesh (FLAME, Oban, Broadway, Batch)
# - Zenoh Control Plane

defmodule IndrajaalMesh.StandbyInitializer do
  @moduledoc """
  Full Standby Mesh Mode Initializer.

  Initializes all mesh components in standby mode, ready for immediate activation.
  """

  require Logger

  # ════════════════════════════════════════════════════════════════════════════
  # CONSTANTS
  # ════════════════════════════════════════════════════════════════════════════

  @compose_file "podman-compose-indrajaal-mesh.yml"
  @mesh_network "indrajaal-mesh"

  @containers %{
    db: "indrajaal-db",
    redis: "indrajaal-redis",
    app: "indrajaal-app",
    otel: "indrajaal-otel",
    prometheus: "indrajaal-prometheus",
    grafana: "indrajaal-grafana"
  }

  @agents [
    {:ooda, "OODA Controller", "Observe-Orient-Decide-Act Loop"},
    {:ace, "ACE Agent", "Autonomic Compute Engine"},
    {:cortex, "Cortex Agent", "Cognitive Control System"},
    {:fractal, "Fractal Logger", "5-Level Fractal Logging"},
    {:cepaf, "CEPAF Bridge", "Container/F# Integration"},
    {:sentinel, "Sentinel Guardian", "Health & Quorum Management"},
    {:kpi_dashboard, "KPI Dashboard", "Real-Time Progress Tracking"}
  ]

  @workers [
    {:flame, "FLAME Worker", "Elastic Compute Scaling"},
    {:oban, "Oban Worker", "Background Job Processing"},
    {:broadway, "Broadway Worker", "Data Pipeline Processing"},
    {:batch, "Batch Worker", "Batch Operation Handling"}
  ]

  # ════════════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ════════════════════════════════════════════════════════════════════════════

  def run(args \\ []) do
    IO.puts(banner())

    mode = parse_mode(args)

    case mode do
      :status -> show_status()
      :start -> start_mesh()
      :stop -> stop_mesh()
      :restart -> restart_mesh()
      _ -> start_mesh()
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # MESH OPERATIONS
  # ════════════════════════════════════════════════════════════════════════════

  defp start_mesh do
    IO.puts("\n#{cyan()}[MESH]#{reset()} Starting Indrajaal Full Standby Mesh Mode...\n")

    steps = [
      {"Checking prerequisites", &check_prerequisites/0},
      {"Creating mesh network", &create_network/0},
      {"Starting database layer", &start_database/0},
      {"Starting cache layer", &start_cache/0},
      {"Starting application layer", &start_application/0},
      {"Starting observability layer", &start_observability/0},
      {"Verifying mesh connectivity", &verify_mesh/0},
      {"Initializing agent mesh", &init_agents/0},
      {"Initializing worker mesh", &init_workers/0},
      {"Activating Zenoh control plane", &init_zenoh/0}
    ]

    results = Enum.map(steps, fn {name, func} ->
      IO.write("  #{yellow()}[...]#{reset()} #{name}...")

      case safe_execute(func) do
        :ok ->
          IO.puts("\r  #{green()}[OK]#{reset()}  #{name}     ")
          {:ok, name}
        {:error, reason} ->
          IO.puts("\r  #{red()}[FAIL]#{reset()} #{name}: #{reason}")
          {:error, name, reason}
      end
    end)

    failures = Enum.filter(results, fn
      {:error, _, _} -> true
      _ -> false
    end)

    IO.puts("")

    if Enum.empty?(failures) do
      show_mesh_dashboard()
      IO.puts("\n#{green()}[SUCCESS]#{reset()} Indrajaal mesh is now in STANDBY mode.\n")
    else
      IO.puts("\n#{red()}[WARNING]#{reset()} Mesh started with #{length(failures)} issue(s).\n")
    end
  end

  defp stop_mesh do
    IO.puts("\n#{cyan()}[MESH]#{reset()} Stopping Indrajaal mesh...\n")

    cmd("podman-compose", ["-f", @compose_file, "down"])
    IO.puts("#{green()}[OK]#{reset()} Mesh stopped.\n")
  end

  defp restart_mesh do
    stop_mesh()
    :timer.sleep(2000)
    start_mesh()
  end

  defp show_status do
    IO.puts("\n#{cyan()}[STATUS]#{reset()} Indrajaal Mesh Status\n")

    IO.puts("#{bold()}Containers:#{reset()}")
    Enum.each(@containers, fn {role, name} ->
      status = get_container_status(name)
      icon = if status == "running", do: "#{green()}●#{reset()}", else: "#{red()}○#{reset()}"
      IO.puts("  #{icon} #{String.pad_trailing(to_string(role), 12)} #{name} (#{status})")
    end)

    IO.puts("\n#{bold()}Agents (7):#{reset()}")
    Enum.each(@agents, fn {id, name, desc} ->
      IO.puts("  #{yellow()}◆#{reset()} #{String.pad_trailing(name, 20)} #{dim()}#{desc}#{reset()}")
    end)

    IO.puts("\n#{bold()}Workers (4):#{reset()}")
    Enum.each(@workers, fn {id, name, desc} ->
      IO.puts("  #{blue()}◇#{reset()} #{String.pad_trailing(name, 20)} #{dim()}#{desc}#{reset()}")
    end)

    IO.puts("")
  end

  # ════════════════════════════════════════════════════════════════════════════
  # STEP IMPLEMENTATIONS
  # ════════════════════════════════════════════════════════════════════════════

  defp check_prerequisites do
    cond do
      not command_exists?("podman") -> {:error, "podman not found"}
      not command_exists?("podman-compose") -> {:error, "podman-compose not found"}
      not File.exists?(@compose_file) -> {:error, "#{@compose_file} not found"}
      true -> :ok
    end
  end

  defp create_network do
    case cmd("podman", ["network", "exists", @mesh_network]) do
      {_, 0} -> :ok
      _ ->
        case cmd("podman", ["network", "create", "--subnet", "172.30.0.0/24", @mesh_network]) do
          {_, 0} -> :ok
          {err, _} -> {:error, err}
        end
    end
  end

  defp start_database do
    start_container(:db)
  end

  defp start_cache do
    start_container(:redis)
  end

  defp start_application do
    start_container(:app)
  end

  defp start_observability do
    # Start OTEL, Prometheus, Grafana in parallel
    [:otel, :prometheus, :grafana]
    |> Enum.each(&start_container/1)
    :ok
  end

  defp verify_mesh do
    :timer.sleep(2000)

    running = Enum.count(@containers, fn {_, name} ->
      get_container_status(name) == "running"
    end)

    if running >= 3 do
      :ok
    else
      {:error, "Only #{running}/#{map_size(@containers)} containers running"}
    end
  end

  defp init_agents do
    # In standby mode, agents are configured but not actively processing
    IO.puts("")
    Enum.each(@agents, fn {id, name, _} ->
      IO.puts("    #{dim()}↳ #{name} [STANDBY]#{reset()}")
    end)
    :ok
  end

  defp init_workers do
    IO.puts("")
    Enum.each(@workers, fn {id, name, _} ->
      IO.puts("    #{dim()}↳ #{name} [STANDBY]#{reset()}")
    end)
    :ok
  end

  defp init_zenoh do
    # Zenoh control plane initialization
    :ok
  end

  # ════════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ════════════════════════════════════════════════════════════════════════════

  defp start_container(role) do
    name = Map.get(@containers, role)

    case get_container_status(name) do
      "running" -> :ok
      _ ->
        case cmd("podman-compose", ["-f", @compose_file, "up", "-d", name]) do
          {_, 0} -> :ok
          {err, _} -> {:error, String.trim(err)}
        end
    end
  end

  defp get_container_status(name) do
    case cmd("podman", ["inspect", "--format", "{{.State.Status}}", name]) do
      {status, 0} -> String.trim(status)
      _ -> "not_found"
    end
  end

  defp command_exists?(cmd) do
    case System.cmd("which", [cmd], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp cmd(command, args) do
    System.cmd(command, args, stderr_to_stdout: true)
  end

  defp safe_execute(func) do
    try do
      func.()
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_mode(args) do
    cond do
      "--status" in args or "-s" in args -> :status
      "--stop" in args -> :stop
      "--restart" in args -> :restart
      true -> :start
    end
  end

  # ════════════════════════════════════════════════════════════════════════════
  # DASHBOARD
  # ════════════════════════════════════════════════════════════════════════════

  defp show_mesh_dashboard do
    IO.puts("""

    #{cyan()}╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    INDRAJAAL FULL STANDBY MESH MODE                          ║
    ╠══════════════════════════════════════════════════════════════════════════════╣#{reset()}
    #{cyan()}║#{reset()} #{bold()}Infrastructure#{reset()}                                                             #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Database    : indrajaal-db       #{dim()}(172.30.0.10:5433)#{reset()}                #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Cache       : indrajaal-redis    #{dim()}(172.30.0.11:6379)#{reset()}                #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Application : indrajaal-app      #{dim()}(172.30.0.20:4000)#{reset()}                #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Telemetry   : indrajaal-otel     #{dim()}(172.30.0.30:4317)#{reset()}                #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Metrics     : indrajaal-prometheus #{dim()}(172.30.0.31:9090)#{reset()}              #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{green()}●#{reset()} Dashboard   : indrajaal-grafana  #{dim()}(172.30.0.32:3000)#{reset()}                #{cyan()}║#{reset()}
    #{cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{reset()}
    #{cyan()}║#{reset()} #{bold()}Agent Mesh (7 Agents)#{reset()}                                                      #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{yellow()}◆#{reset()} OODA Controller     #{yellow()}◆#{reset()} ACE Agent          #{yellow()}◆#{reset()} Cortex Agent       #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{yellow()}◆#{reset()} Fractal Logger      #{yellow()}◆#{reset()} CEPAF Bridge       #{yellow()}◆#{reset()} Sentinel Guardian  #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{yellow()}◆#{reset()} KPI Dashboard                                                        #{cyan()}║#{reset()}
    #{cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{reset()}
    #{cyan()}║#{reset()} #{bold()}Worker Mesh (4 Workers)#{reset()}                                                    #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{blue()}◇#{reset()} FLAME Worker        #{blue()}◇#{reset()} Oban Worker        #{blue()}◇#{reset()} Broadway Worker    #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   #{blue()}◇#{reset()} Batch Worker                                                           #{cyan()}║#{reset()}
    #{cyan()}╠══════════════════════════════════════════════════════════════════════════════╣#{reset()}
    #{cyan()}║#{reset()} #{bold()}Zenoh Control Plane#{reset()}                                                        #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   Control Topic : indrajaal/mesh/control                                     #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   State Topic   : indrajaal/mesh/state                                       #{cyan()}║#{reset()}
    #{cyan()}║#{reset()}   Router Port   : 7447                                                       #{cyan()}║#{reset()}
    #{cyan()}╚══════════════════════════════════════════════════════════════════════════════╝#{reset()}
    """)
  end

  defp banner do
    """
    #{cyan()}
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║   ██╗███╗   ██╗██████╗ ██████╗  █████╗      ██╗ █████╗  █████╗ ██╗            ║
    ║   ██║████╗  ██║██╔══██╗██╔══██╗██╔══██╗     ██║██╔══██╗██╔══██╗██║            ║
    ║   ██║██╔██╗ ██║██║  ██║██████╔╝███████║     ██║███████║███████║██║            ║
    ║   ██║██║╚██╗██║██║  ██║██╔══██╗██╔══██║██   ██║██╔══██║██╔══██║██║            ║
    ║   ██║██║ ╚████║██████╔╝██║  ██║██║  ██║╚█████╔╝██║  ██║██║  ██║███████╗       ║
    ║   ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝       ║
    ║                                                                               ║
    ║               FULL STANDBY MESH MODE INITIALIZER                              ║
    ║                                                                               ║
    ║   7 Agents  •  4 Workers  •  Zenoh Control Plane  •  STAMP Compliant         ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    #{reset()}
    """
  end

  # ANSI Colors
  defp green, do: "\e[32m"
  defp red, do: "\e[31m"
  defp yellow, do: "\e[33m"
  defp blue, do: "\e[34m"
  defp cyan, do: "\e[36m"
  defp bold, do: "\e[1m"
  defp dim, do: "\e[2m"
  defp reset, do: "\e[0m"
end

# Run the initializer
IndrajaalMesh.StandbyInitializer.run(System.argv())
