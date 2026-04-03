#!/usr/bin/env elixir

defmodule DevEnvManager do
  @moduledoc """
  Starts development dependencies in containers using Podman.
  Aligned with SC-CNT-ENV-001 (5-Level Strategy).
  """

  @doc """
  Starts the development environment.
  Default: Level 1 (3-container setup for velocity)
  Optional: --full flag for complete core stack (Level 3)
  """
  def start(args) do
    # SC-CNT-ENV-001 Alignment: Default to 3-container variant
    strategy = if "--full" in args, do: :full, else: :dev
    
    compose_file = case strategy do
      :full -> "podman-compose.yml"
      :dev -> "podman-compose-3container.yml"
    end

    IO.puts("🚀 Starting Indrajaal Development Dependencies...")
    IO.puts("🎯 Strategy: #{if strategy == :full, do: "Level 3 (Full Stack)", else: "Level 1 (3-Container Velocity)"}")
    IO.puts("📄 Using: #{compose_file}")
    
    # 1. Check if Podman is available
    check_podman!()

    # 2. Start containers
    case System.cmd("podman-compose", ["-f", compose_file, "up", "-d"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts(output)
        IO.puts("✅ Dependencies are up and running.")
        display_config(strategy)
        
      {error, _} ->
        IO.puts("❌ Failed to start containers:\n#{error}")
        System.halt(1)
    end
  end

  def stop(args) do
    strategy = if "--full" in args, do: :full, else: :dev
    compose_file = if strategy == :full, do: "podman-compose.yml", else: "podman-compose-3container.yml"

    IO.puts("🛑 Stopping Indrajaal Development Dependencies (#{compose_file})...")
    
    case System.cmd("podman-compose", ["-f", compose_file, "stop"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts(output)
        IO.puts("✅ Containers stopped.")
      {error, _} ->
        IO.puts("❌ Failed to stop containers:\n#{error}")
    end
  end

  defp check_podman!() do
    case System.cmd("podman", ["--version"]) do
      {_, 0} -> :ok
      _ -> 
        IO.puts("❌ Podman not found. Please install Podman.")
        System.halt(1)
    end
  end

  defp display_config(strategy) do
    IO.puts("💡 Local Application Configuration:")
    IO.puts("   - PostgreSQL: localhost:5433 (user: indrajaal, pass: indrajaal_dev)")
    IO.puts("   - Redis: localhost:6379")
    IO.puts("   - KMS Catalog: Active (Shared Volume: ./data/kms)")
    
    if strategy == :full do
      IO.puts("   - Prometheus: localhost:9090")
      IO.puts("   - Grafana: localhost:3000")
      IO.puts("   - Zenoh: localhost:7447")
    end

    IO.puts("\n👉 Run your application locally with:")
    IO.puts("   export DATABASE_URL=postgres://indrajaal:indrajaal_dev@localhost:5433/indrajaal_dev")
    IO.puts("   mix phx.server")
  end
end

args = System.argv()
case args do
  ["stop" | rest] -> DevEnvManager.stop(rest)
  _ -> DevEnvManager.start(args)
end
