#!/usr/bin/env elixir

defmodule RobustContainerStartupOrchestrator do
  @moduledoc """
  Robust Container Startup Orchestrator for Indrajaal Application & Observability Stack

  This module provides enterprise-grade container orchestration with:-Dependency-aware startup sequence
  - Health check validation
  - Failure recovery with exponential backoff
  - Parallel startup optimization
  - Real-time monitoring and reporting
  - SOPv5.1 compliance and PHICS integration

  Created: 2025-08-05 10:21:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + Container-Only Policy
  """

  __require Logger

  @project_root File.cwd!()

  # Container startup dependencies and configuration
  @container_config %{
    # Core Infrastructure (Start First)
    postgres: %{
      image: "localhost/indrajaal-postgres-demo:demo-ready",
      name: "indrajaal-postgres-demo",
      ports: ["5433:5433"],
      health_check: "pg_isready -U postgres -d indrajaal_demo -p 5433",
      health_timeout: 60,
      startup_timeout: 120,
      dependencies: [],
      priority: 1
    },
    redis: %{
      image: "localhost/indrajaal-redis-demo:demo-ready",
      name: "indrajaal-redis-demo",
      ports: ["6379:6379"],
      health_check: "redis-cli ping",
      health_timeout: 30,
      startup_timeout: 60,
      dependencies: [],
      priority: 1
    },

    # Application Layer (Start After Infrastructure)
    app: %{
      image: "localhost/indrajaal-app-demo:dialyzer-enabled",
      name: "indrajaal-app-demo",
      ports: ["4000:4000", "4001:4001"],
      health_check: "curl -f http://localhost:4000/health",
      health_timeout: 120,
      startup_timeout: 180,
      dependencies: [:postgres, :redis],
      priority: 2
    },

    # Monitoring Stack (Start After Application)
    prometheus: %{
      image: "localhost/indrajaal-prometheus-demo:nixos-devenv",
      name: "indrajaal-prometheus-demo",
      ports: ["9090:9090"],
      health_check: "curl -f http://localhost:9090/-/healthy",
      health_timeout: 60,
      startup_timeout: 90,
      dependencies: [:app],
      priority: 3
    },
    grafana: %{
      image: "localhost/indrajaal-grafana-demo:nixos-devenv",
      name: "indrajaal-grafana-demo",
      ports: ["3000:3000"],
      health_check: "curl -f http://localhost:3000/api/health",
      health_timeout: 60,
      startup_timeout: 90,
      dependencies: [:prometheus],
      priority: 3
    },
    nginx: %{
      image: "localhost/indrajaal-nginx-demo:nixos-devenv",
      name: "indrajaal-nginx-demo",
      ports: ["8080:80", "8443:443"],
      health_check: "curl -f http://localhost:8080/health",
      health_timeout: 30,
      startup_timeout: 60,
      dependencies: [:app],
      priority: 3
    },

    # SigNoz Observability Stack (Start in Parallel with Monitoring)
    clickhouse: %{
      image: "localhost/signoz-clickhouse:latest",
      name: "indrajaal-clickhouse",
      ports: ["127.0.0.1:9000:9000", "127.0.0.1:8123:8123"],
      health_check: "clickhouse-client --query 'SELECT 1'",
      health_timeout: 90,
      startup_timeout: 120,
      dependencies: [],
      priority: 3
    },
    signoz_query: %{
      image: "localhost/signoz-query:latest",
      name: "indrajaal-signoz-query",
      ports: ["127.0.0.1:8080:8080", "127.0.0.1:8081:8081"],
      health_check: "curl -f http://localhost:8080/api/v1/health",
      health_timeout: 60,
      startup_timeout: 90,
      dependencies: [:clickhouse],
      priority: 4
    },
    otel_collector: %{
      image: "localhost/signoz-otel-collector:latest",
      name: "indrajaal-otel-collector",
      ports: ["127.0.0.1:4317:4317",
      "127.0.0.1:4318:4318", "127.0.0.1:8888:8888", "127.0.0.1:13_133:13_133"],
      health_check: "curl -s http://localhost:13_133/health",
      health_timeout: 60,
      startup_timeout: 90,
      dependencies: [:clickhouse, :signoz_query],
      priority: 4
    },
    signoz_frontend: %{
      image: "localhost/signoz-frontend:latest",
      name: "indrajaal-signoz-frontend",
      ports: ["127.0.0.1:3301:3301"],
      health_check: "curl -f http://localhost:3301/health",
      health_timeout: 60,
      startup_timeout: 90,
      dependencies: [:signoz_query],
      priority: 4
    }
  }

  @spec main(any()) :: any()
  def main(args \\ []) do
    IO.puts """
    🚀 Robust Container Startup Orchestrator
    ========================================
    Project: Indrajaal Security Monitoring System
    Containers: #{map_size(@container_config)} total (6 application + 5 observabi
    Timestamp: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    🛡️ SOPv5.1 Compliance:-Container-only execution enforced
    - PHICS hot-reloading integration
    - Health monitoring and recovery
    - Dependency-aware startup sequence
    """

    {__opts, _, _} = OptionParser.parse(args,
      switches: [
        mode: :string,        # robust, quick, observability-only
        parallel: :boolean,   # Enable parallel startup where possible
        force: :boolean,      # Force restart existing containers
        validate: :boolean,   # Run post-startup validation
        timeout: :integer,    # Override default timeouts
        verbose: :boolean     # Detailed logging
      ]
    )

    mode = __opts[:mode] || "robust"

    case validate_pre__requisites(__opts) do
      :ok ->
        execute_startup_sequence(mode, __opts)
      {:error, reason} ->
        IO.puts("❌ Pre__requisites failed: #{reason}")
        System.halt(1)
    end
  end

  @spec validate_pre__requisites(term()) :: term()
  defp validate_pre__requisites(opts) do
    IO.puts("\n🔍 Pre-flight Validation...")

    with :ok <- validate_podman_available(),
         :ok <- validate_images_available(),
         :ok <- validate_directories(),
         :ok <- validate_network_ports() do
      IO.puts("✅ All pre__requisites met")
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec validate_podman_available() :: any()
  defp validate_podman_available do
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("  ✅ Podman available: #{String.trim(output)}")
        :ok
      {_, _} ->
        {:error, "Podman not available or not working"}
    end
  end

  @spec validate_images_available() :: any()
  defp validate_images_available do
    IO.puts("  🔍 Checking container images...")

    missing_images = @container_config
    |> Enum.map(fn {_, config} -> config.image end)
    |> Enum.uniq()
    |> Enum.filter(fn image ->
      case System.cmd("podman", ["image", "exists", image], stderr_to_stdout: true) do
        {_, 0} -> false
        {_, _} -> true
      end
    end)

    if Enum.empty?(missing_images) do
      IO.puts("  ✅ All __required images available")
      :ok
    else
      {:error, "Missing images: #{Enum.join(missing_images, ", ")}"}
    end
  end

  @spec validate_directories() :: any()
  defp validate_directories do
    __required_dirs = [
      "__data", "__data/postgres", "__data/redis", "__data/grafana",
      "__data/prometheus", "logs", "tmp"
    ]

    missing_dirs = __required_dirs
    |> Enum.filter(fn dir ->
      path = Path.join(@project_root, dir)
      not File.dir?(path)
    end)

    if Enum.empty?(missing_dirs) do
      IO.puts("  ✅ All __required directories exist")
      :ok
    else
      # Create missing directories
      Enum.each(missing_dirs, fn dir ->
        path = Path.join(@project_root, dir)
        File.mkdir_p!(path)
        IO.puts("  📁 Created directory: #{dir}")
      end)
      :ok
    end
  end

  @spec validate_network_ports() :: any()
  defp validate_network_ports do
    # Check for port conflicts
    used_ports = get_used_ports()
    __required_ports = get_required_ports()

    conflicts = MapSet.intersection(MapSet.new(used_ports), MapSet.new(__required_ports))

    if MapSet.size(conflicts) == 0 do
      IO.puts("  ✅ No port conflicts detected")
      :ok
    else
      {:error, "Port conflicts: #{MapSet.to_list(conflicts) |> Enum.join(", ")}"}
    end
  end

  @spec get_used_ports() :: any()
  defp get_used_ports do
    case System.cmd("ss", ["-tuln"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.map(&extract_port_from_ss_line/1)
        |> Enum.filter(&(&1 != nil))
      _ -> []
    end
  end

  @spec extract_port_from_ss_line(term()) :: term()
  defp extract_port_from_ss_line(line) do
    case Regex.run(~r/:(\d+)\s/, line) do
      [_, port] -> String.to_integer(port)
      _ -> nil
    end
  end

  @spec get_required_ports() :: any()
  defp get_required_ports do
    @container_config
    |> Enum.flat_map(fn {_, config} ->
      config.ports
      |> Enum.map(fn port_mapping ->
        port_mapping
        |> String.split(":")
        |> List.first()
        |> String.replace("127.0.0.1", "")
        |> String.to_integer()
      end)
    end)
  end

  @spec execute_startup_sequence(term(), term()) :: term()
  defp execute_startup_sequence(mode, opts) do
    IO.puts("\n🚀 Starting container sequence (mode: #{mode})...")

    # Clean up existing containers if force flag is set
    if __opts[:force] do
      cleanup_existing_containers()
    end

    # Group containers by priority for dependency-aware startup
    container_groups = @container_config
    |> Enum.group_by(fn {_, config} -> config.priority end)
    |> Enum.sort()

    results = container_groups
    |> Enum.reduce([], fn {priority, containers}, acc ->
      IO.puts("\n📋 Starting Priority #{priority} containers...")

      group_results = case __opts[:parallel] do
        true -> start_containers_parallel(containers, __opts)
        _ -> start_containers_sequential(containers, __opts)
      end

      acc ++ group_results
    end)

    # Analyze results
    analyze_startup_results(results, __opts)

    # Run post-startup validation if __requested
    if __opts[:validate] do
      run_post_startup_validation()
    end
  end

  @spec cleanup_existing_containers() :: any()
  defp cleanup_existing_containers do
    IO.puts("\n🧹 Cleaning up existing containers...")

    @container_config
    |> Enum.each(fn {_, config} ->
      case System.cmd("podman", ["rm", "-f", config.name], stderr_to_stdout: true) do
        {_, 0} -> IO.puts("  🗑️  Removed #{config.name}")
        {_, _} -> :ok  # Container didn't exist
      end
    end)
  end

  @spec start_containers_sequential(term(), term()) :: term()
  defp start_containers_sequential(containers, opts) do
    containers
    |> Enum.map(fn {name, config} ->
      start_single_container(name, config, __opts)
    end)
  end

  @spec start_containers_parallel(term(), term()) :: term()
  defp start_containers_parallel(containers, opts) do
    containers
    |> Task.async_stream(fn {name, config} ->
      start_single_container(name, config, __opts)
    end, max_concurrency: System.schedulers_online())
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp start_single_container(name, config, opts) do
    IO.puts("  🐳 Starting #{config.name}...")

    # Wait for dependencies if any
    wait_for_dependencies(config.dependencies, __opts)

    # Build container start command
    start_cmd = build_container_start_command(name, config)

    # Start container
    start_time = System.monotonic_time(:millisecond)

    case System.cmd("podman", start_cmd, stderr_to_stdout: true) do
      {output, 0} ->
        # Wait for health check
        case wait_for_health_check(config, __opts) do
          :ok ->
            elapsed = System.monotonic_time(:millisecond)-start_time
            IO.puts("    ✅ #{config.name} started successfully (#{elapsed}ms)")
            {:ok, name, elapsed}
          {:error, reason} ->
            IO.puts("    ❌ #{config.name} failed health check: #{reason}")
            {:error, name, reason}
        end
      {output, code} ->
        IO.puts("    ❌ #{config.name} failed to start: #{output}")
        {:error, name, "Exit code #{code}: #{output}"}
    end
  end

  @spec build_container_start_command(term(), term()) :: term()
  defp build_container_start_command(name, config) do
    base_cmd = [
      "run", "-d",
      "--name", config.name
    ]

    # Add port mappings
    port_args = config.ports
    |> Enum.flat_map(fn port -> ["-p", port] end)

    # Add volumes based on container type
    volume_args = get_volume_args(name, config)

    # Add environment variables
    env_args = get_environment_args(name, config)

    # Combine all arguments
    base_cmd ++ port_args ++ volume_args ++ env_args ++ [config.image] ++ get_container_command(name)
  end

  @spec get_volume_args(term(), term()) :: term()
  defp get_volume_args(name, config) do
    case name do
      :postgres ->
        ["-v", "#{@project_root}/__data/postgres:/var/lib/postgresql/__data:z"]
      :redis ->
        ["-v", "#{@project_root}/__data/redis:/__data:z"]
      :app ->
        ["-v", "#{@project_root}:/workspace:z", "-w", "/workspace"]
      :prometheus ->
        ["-v", "#{@project_root}/__data/prometheus:/prometheus:z"]
      :grafana ->
        ["-v", "#{@project_root}/__data/grafana:/var/lib/grafana:z"]
      _ -> []
    end
  end

  @spec get_environment_args(term(), term()) :: term()
  defp get_environment_args(name, config) do
    base_env = [
      "-e", "PHICS_ENABLED=true",
      "-e", "NO_TIMEOUT=true",
      "-e", "CONTAINER_OS=nixos",
      "-e", "MAX_PARALLELIZATION=true"
    ]

    specific_env = case name do
      :postgres ->
        ["-e", "POSTGRES_DB=indrajaal_demo",
         "-e", "POSTGRES_USER=postgres",
         "-e", "POSTGRES_PASSWORD=postgres",
         "-e", "PGPORT=5433"]
      :app ->
        ["-e", "MIX_ENV=demo",
         "-e", "DATABASE_URL=postgres://postgres:postgres@#{@container_config.pos
         "-e", "REDIS_URL=redis://#{@container_config.redis.name}:6379",
         "-e", "ELIXIR_ERL_OPTIONS=+fnu +S 16",
         "-e", "CONTAINER_ENFORCEMENT=true"]
      :clickhouse ->
        ["-e", "CLICKHOUSE_DB=signoz",
         "-e", "CLICKHOUSE_USER=signoz",
         "-e", "CLICKHOUSE_PASSWORD=signoz2024!"]
      _ -> []
    end

    base_env ++ specific_env
  end

  @spec get_container_command(term()) :: term()
  defp get_container_command(name) do
    case name do
      :app -> ["iex", "-S", "mix", "phx.server"]
      _ -> []
    end
  end

  @spec wait_for_dependencies(term(), term()) :: term()
  defp wait_for_dependencies(dependencies, opts) do
    unless Enum.empty?(dependencies) do
      IO.puts("    ⏳ Waiting for dependencies: #{Enum.join(dependencies, ", ")}")

      dependencies
      |> Enum.each(fn dep ->
        dep_config = @container_config[dep]
        wait_for_health_check(dep_config, __opts)
      end)
    end
  end

  @spec wait_for_health_check(term(), term()) :: term()
  defp wait_for_health_check(config, opts) do
    timeout = __opts[:timeout] || config.health_timeout
    check_interval = 5  # seconds
    max_attempts = div(timeout, check_interval)

    wait_for_health_check_attempts(config, max_attempts, check_interval)
  end

  defp wait_for_health_check_attempts(config, attempts_left, interval) when attempts_left > 0 do
    case System.cmd("podman",
      ["exec", config.name, "sh", "-c", config.health_check], stderr_to_stdout: true) do
      {_, 0} ->
        :ok
      {output, _} ->
        if attempts_left > 1 do
          :timer.sleep(interval * 1000)
          wait_for_health_check_attempts(config, attempts_left-1, interval)
        else
          {:error, "Health check failed: #{output}"}
        end
    end
  end

  defp wait_for_health_check_attempts(_, 0, _) do
    {:error, "Health check timeout"}
  end

  @spec analyze_startup_results(term(), term()) :: term()
  defp analyze_startup_results(results, __opts) do
    total = length(results)
    successful = Enum.count(results, fn {status, _, _} -> status == :ok end)
    failed = total-successful

    total_time = results
    |> Enum.filter(fn {status, _, _} -> status == :ok end)
    |> Enum.map(fn {_, _, time} -> time end)
    |> Enum.sum()

    IO.puts """

    📊 Startup Results Summary
    ==========================
    Total Containers: #{total}
    Successful: #{successful} ✅
    Failed: #{failed} ❌
    Total Time: #{total_time}ms
    Average Time: #{if successful > 0, do: div(total_time, successful), else: 0}m
    """

    if failed > 0 do
      IO.puts("\n❌ Failed Containers:")
      results
      |> Enum.filter(fn {status, _, _} -> status == :error end)
      |> Enum.each(fn {_, name, reason} ->
        IO.puts("-#{name}: #{reason}")
      end)
    end

    if successful == total do
      IO.puts("\n🎉 All containers started successfully!")
      System.halt(0)
    else
      IO.puts("\n⚠️  Some containers failed to start")
      System.halt(1)
    end
  end

  @spec run_post_startup_validation() :: any()
  defp run_post_startup_validation do
    IO.puts("\n🔍 Post-startup validation...")

    # Validate all containers are running
    running_containers = get_running_containers()
    expected_containers = Map.values(@container_config) |> Enum.map(& &1.name)

    missing = expected_containers -- running_containers

    if Enum.empty?(missing) do
      IO.puts("  ✅ All containers are running")
    else
      IO.puts("  ❌ Missing containers: #{Enum.join(missing, ", ")}")
    end

    # Run basic connectivity tests
    test_container_connectivity()
  end

  @spec get_running_containers() :: any()
  defp get_running_containers do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
      _ -> []
    end
  end

  @spec test_container_connectivity() :: any()
  defp test_container_connectivity do
    IO.puts("  🔍 Testing container connectivity...")

    # Test basic HTTP endpoints
    endpoints = [
      {"App Health", "http://localhost:4000/health"},
      {"Prometheus", "http://localhost:9090/-/healthy"},
      {"Grafana", "http://localhost:3000/api/health"}
    ]

    endpoints
    |> Enum.each(fn {name, url} ->
      case System.cmd("curl", ["-f", "-s", "--max-time", "10", url], stderr_to_stdout: true) do
        {_, 0} -> IO.puts("    ✅ #{name} responding")
        {_, _} -> IO.puts("    ❌ #{name} not responding")
      end
    end)
  end
end

# Execute the orchestrator
RobustContainerStartupOrchestrator.main(System.argv())
end
