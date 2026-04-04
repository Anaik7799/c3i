#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AEE.PHICSContainerDeployment do
  @moduledoc """
  Deploy 10 PHICS-enabled containers for autonomous compilation fixing
  Part of the AEE autonomous execution framework
  SOPv5.1 Compliance: Complete with TPS, STAMP, TDG, GDE integration
  """

  @container_count 10
  @base_image "localhost/indrajaal-sopv51-app:latest"
  @network_name "aee-compilation-net"
  @workspace_path File.cwd!()

  def main(_args) do
    IO.puts("🚀 AEE PHICS Container Deployment Starting...")
    
    # TPS: Jidoka - Stop and check at each step
    with :ok <- ensure_network_exists(),
         :ok <- stop_old_containers(),
         :ok <- deploy_all_containers(),
         :ok <- verify_all_containers() do
      IO.puts("\n✅ ALL PHICS CONTAINERS DEPLOYED SUCCESSFULLY!")
      print_container_status()
    else
      {:error, reason} -> 
        IO.puts("\n❌ Deployment failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp ensure_network_exists do
    IO.puts("\n📡 Ensuring network #{@network_name} exists...")
    case System.cmd("podman", ["network", "exists", @network_name]) do
      {_, 0} -> 
        IO.puts("  ✅ Network already exists")
        :ok
      _ ->
        IO.puts("  🔧 Creating network...")
        case System.cmd("podman", ["network", "create", @network_name]) do
          {_, 0} -> 
            IO.puts("  ✅ Network created")
            :ok
          {error, _} -> {:error, "Failed to create network: #{error}"}
        end
    end
  end

  defp stop_old_containers do
    IO.puts("\n🧹 Cleaning up old AEE containers...")
    
    # Get list of existing AEE containers
    case System.cmd("podman", ["ps", "-a", "--filter", "name=aee-container-", "--format", "{{.Names}}"]) do
      {output, 0} ->
        containers = String.split(output, "\n", trim: true)
        
        if Enum.empty?(containers) do
          IO.puts("  ✅ No old containers to clean")
          :ok
        else
          IO.puts("  🔧 Stopping #{length(containers)} containers...")
          Enum.each(containers, fn container ->
            System.cmd("podman", ["stop", container])
            System.cmd("podman", ["rm", container])
          end)
          IO.puts("  ✅ Old containers cleaned")
          :ok
        end
      _ -> :ok
    end
  end

  defp deploy_all_containers do
    IO.puts("\n🐳 Deploying #{@container_count} PHICS-enabled containers...")
    
    results = 1..@container_count
    |> Enum.map(&deploy_single_container/1)
    
    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, "Some containers failed to deploy"}
    end
  end

  defp deploy_single_container(num) do
    IO.puts("\n  📦 Deploying Container-#{num}...")
    
    container_name = "aee-container-#{num}"
    resources = get_container_resources(num)
    
    args = [
      "run", "-d",
      "--name", container_name,
      "--network", @network_name,
      "-v", "#{@workspace_path}:/workspace:z",
      "-e", "CONTAINER_NUM=#{num}",
      "-e", "PHICS_ENABLED=true",
      "-e", "HOT_RELOAD=true",
      "-e", "MIX_ENV=dev",
      "-e", "ELIXIR_ERL_OPTIONS=+fnu +S 16",
      "-e", "NO_TIMEOUT=true",
      "--cpus", resources.cpus,
      "--memory", resources.memory,
      @base_image,
      "tail", "-f", "/dev/null"  # Keep container running
    ]
    
    case System.cmd("podman", args) do
      {container_id, 0} ->
        IO.puts("    ✅ Container-#{num} deployed: #{String.trim(container_id) |> String.slice(0..12)}")
        :ok
      {error, _} ->
        IO.puts("    ❌ Failed to deploy Container-#{num}: #{error}")
        {:error, "Container-#{num} deployment failed"}
    end
  end

  defp get_container_resources(container_num) do
    # STAMP: Resource allocation based on container role
    cond do
      container_num == 1 -> %{cpus: "3", memory: "6g"}  # Critical errors
      container_num == 2 -> %{cpus: "2", memory: "4g"}  # Logging warnings
      container_num == 3 -> %{cpus: "2", memory: "4g"}  # Analytics warnings
      container_num == 4 -> %{cpus: "2", memory: "4g"}  # Service layer
      container_num == 5 -> %{cpus: "2", memory: "4g"}  # GenServer callbacks
      container_num >= 6 and container_num <= 8 -> %{cpus: "2", memory: "4g"}  # Distributed cleanup
      container_num == 9 -> %{cpus: "2", memory: "4g"}  # Integration testing
      container_num == 10 -> %{cpus: "1", memory: "2g"}  # Final merge
      true -> %{cpus: "2", memory: "4g"}  # Default
    end
  end

  defp verify_all_containers do
    IO.puts("\n🔍 Verifying all containers are running...")
    Process.sleep(2000)  # Give containers time to start
    
    results = 1..@container_count
    |> Enum.map(&verify_container/1)
    
    if Enum.all?(results, &(&1 == :ok)) do
      IO.puts("\n✅ All containers verified and running!")
      :ok
    else
      {:error, "Some containers are not running properly"}
    end
  end

  defp verify_container(num) do
    container_name = "aee-container-#{num}"
    
    case System.cmd("podman", ["ps", "--filter", "name=#{container_name}", "--format", "{{.Status}}"]) do
      {status, 0} when status != "" ->
        if String.contains?(status, "Up") do
          IO.puts("  ✅ Container-#{num}: Running")
          :ok
        else
          IO.puts("  ❌ Container-#{num}: Not running properly")
          {:error, "Container-#{num} not running"}
        end
      _ ->
        IO.puts("  ❌ Container-#{num}: Not found")
        {:error, "Container-#{num} not found"}
    end
  end

  defp print_container_status do
    IO.puts("\n📊 CONTAINER STATUS SUMMARY:")
    IO.puts("=" <> String.duplicate("=", 70))
    
    {output, 0} = System.cmd("podman", [
      "ps", 
      "--filter", "name=aee-container-",
      "--format", "table {{.Names}}\t{{.Status}}\t{{.Command}}"
    ])
    
    IO.puts(output)
    
    # Print connection info
    IO.puts("\n🔧 CONTAINER ACCESS:")
    IO.puts("=" <> String.duplicate("=", 70))
    1..@container_count |> Enum.each(fn num ->
      IO.puts("Container-#{num}: podman exec -it aee-container-#{num} /bin/bash")
    end)
    
    # GDE: Goal achievement metrics
    IO.puts("\n📈 DEPLOYMENT METRICS:")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Total containers: #{@container_count}")
    IO.puts("Network: #{@network_name}")
    IO.puts("PHICS status: Enabled")
    IO.puts("Hot-reload: Active")
    IO.puts("Total resources: 20 CPUs, 40GB RAM")
  end
end

AEE.PHICSContainerDeployment.main(System.argv())