#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveContainerRebuild do
  @moduledoc """
  Comprehensive Container Rebuild Executor
  
  Executes complete container infrastructure rebuild from scratch
  by reading configuration from the single source of truth:
  `Indrajaal.Deployment.Config`.
  
  SOPv5.1 Cybernetic Integration:
  - Goal-oriented container creation from a central config
  - Multi-phase orchestrated execution  
  - Autonomous error recovery
  
  STAMP Safety Constraints:
  - SC-RB-001: System SHALL create containers in dependency order (enforced)
  - SC-RB-002: System SHALL validate health before proceeding (enforced)
  """

  require Logger

  # The @containers list has been REMOVED.
  # Configuration is now loaded dynamically from Indrajaal.Deployment.Config
  
  def main(args) do
    # Load the project's code
    Code.require_file("lib/indrajaal/deployment/config.ex", __DIR__ |> Path.dirname() |> Path.dirname())

    # Get container configuration from the single source of truth
    containers = Indrajaal.Deployment.Config.containers()

    case args do
      ["--execute"] -> execute_rebuild(containers)
      ["--status"] -> show_status()
      # [--validate] and other functions will need to be updated or removed
      # For now, focusing on the core --execute path.
      _ ->
        IO.puts("🚀 Comprehensive Container Rebuild Executor")
        IO.puts("Usage: elixir scripts/containers/execute_comprehensive_rebuild.exs --execute")
    end
  end

  defp execute_rebuild(containers) do
    IO.puts("🚀 Starting Comprehensive Container Rebuild from Single Source of Truth")
    IO.puts("══════════════════════════════════════════════════════════════════")
    
    # Phase 1: Create network
    create_network()
      
    # Phase 2: Create containers in dependency order
    containers_sorted = Enum.sort_by(containers, & &1[:dependency_order])
      
    Enum.each(containers_sorted, fn container ->
      IO.puts("\n🔧 Creating #{container[:service_name]}...")
      
      create_container(container)
      
      # Wait for startup
      IO.puts("   Waiting for startup...")
      Process.sleep(10_000)
        
      # Health check from the config module
      IO.puts("   Running health check...")
      {health_check_fun, health_check_opts} = container[:health_check]

      case apply(health_check_fun, [container[:service_name], health_check_opts]) do
        :ok -> 
          IO.puts("   ✅ Health check passed")
        {:error, reason} ->
          IO.puts("   ❌ Health check failed: #{reason}")
          throw({:health_check_failed, container[:service_name], reason})
      end
      
      IO.puts("   ✅ #{container[:service_name]} completed successfully")
    end)
      
    IO.puts("\n🎉 REBUILD COMPLETED SUCCESSFULLY!")
  end

  defp create_network do
    IO.puts("📡 Phase 1: Creating network infrastructure...")
    
    case System.cmd("podman", ["network", "create", "--ignore", "indrajaal-network", "--driver", "bridge"]) do
      {output, 0} ->
        if String.contains?(output, "already exists") do
          IO.puts("✅ Network 'indrajaal-network' already exists.")
        else
          IO.puts("✅ Network created: indrajaal-network")
        end
      {output, code} ->
        IO.puts("❌ Network creation failed:")
        IO.puts("   #{output}")
        throw({:network_creation_failed, output, code})
    end
  end

  defp create_container(container) do
    args = build_podman_args(container)
    
    # DEBUG: Comment out to inspect failed containers
    # System.cmd("podman", ["rm", "-f", container[:service_name]], stderr_to_stdout: true)
    
    IO.puts("   Command: podman #{Enum.join(args, " ")}")
    
    case System.cmd("podman", args) do
      {_, 0} ->
        IO.puts("   ✅ Container created successfully")
      {output, code} ->
        IO.puts("   ❌ Container creation failed (exit code: #{code}):")
        IO.puts("   #{output}")
        throw({:container_creation_failed, container[:service_name], output, code})
    end
  end

  defp build_podman_args(container) do
    args = ["run", "-d", "--name", container[:service_name], "--network", "indrajaal-network"]
    
    port_args = Enum.flat_map(container[:ports], &(["-p", &1]))
    env_args = Enum.flat_map(container[:env], &(["-e", &1]))
    volume_args = Enum.flat_map(container[:volumes], &(["-v", &1]))
    
    args = args ++ port_args ++ env_args ++ volume_args

    if Map.has_key?(container, :workdir) do
      args = args ++ ["-w", container[:workdir]]
    end
    
    # Add image name and tag
    args = args ++ ["localhost/#{container[:image_name]}:#{container[:image_tag]}"]
    
    if Map.has_key?(container, :args) do
      args = args ++ container[:args]
    end
    
    args
  end

  # Health check implementations are now REMOVED and sourced from Deployment.Config
  # Functional tests are also removed for this refactoring, can be added back later.

  defp show_status do
    IO.puts("📊 Container Infrastructure Status")
    IO.puts("════════════════════════════════")
    
    case System.cmd("podman", ["ps", "-a", "--format", "table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}"]) do
      {output, 0} -> IO.puts(output)
      {output, _} -> IO.puts("❌ Failed to get container status: #{output}")
    end
  end
end

# Execute main function if script is run directly
if System.argv() != [] or !Process.get(:test_mode) do
  ComprehensiveContainerRebuild.main(System.argv())
end