#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule DynamicResourceManager do
  @moduledoc """
  Dynamic Resource Manager for SOPv5.11 Cybernetic Framework
  
  Manages system resource allocation with environment-specific configuration
  and automatic system resource detection and alignment.
  
  Features:
  - Dynamic core and RAM allocation per environment
  - System resource detection and validation
  - Container resource distribution optimization
  - SOPv5.11 15-agent architecture resource mapping
  - Real-time resource monitoring and adjustment
  """

  @default_config %{
    total_cores: 10,
    total_ram_gb: 48,
    environment: "development",
    container_count: 10,
    agent_count: 50,
    resource_safety_margin: 0.1,  # 10% safety margin
    min_cores_per_container: 0.5,
    min_ram_per_container_gb: 1.0
  }

  @environment_configs %{
    "development" => %{
      total_cores: 10,
      total_ram_gb: 48,
      container_count: 10,
      agent_count: 50,
      resource_utilization: 0.8  # Use 80% of available resources
    },
    "testing" => %{
      total_cores: 8,
      total_ram_gb: 32,
      container_count: 8,
      agent_count: 40,
      resource_utilization: 0.7
    },
    "staging" => %{
      total_cores: 12,
      total_ram_gb: 64,
      container_count: 12,
      agent_count: 60,
      resource_utilization: 0.85
    },
    "production" => %{
      total_cores: 16,
      total_ram_gb: 128,
      container_count: 16,
      agent_count: 80,
      resource_utilization: 0.9
    }
  }

  @container_complexity_weights %{
    "access_control" => %{complexity: :high, weight: 1.5},
    "accounts" => %{complexity: :medium, weight: 1.0},
    "alarms" => %{complexity: :high, weight: 1.4},
    "analytics" => %{complexity: :high, weight: 1.6},
    "communication" => %{complexity: :medium, weight: 1.0},
    "compliance" => %{complexity: :medium, weight: 1.1},
    "devices" => %{complexity: :low, weight: 0.8},
    "performance" => %{complexity: :high, weight: 1.5},
    "observability" => %{complexity: :very_high, weight: 2.0},
    "web_api" => %{complexity: :high, weight: 1.3}
  }

  def main(args) do
    case args do
      ["--status"] -> show_current_status()
      ["--detect"] -> detect_system_resources()
      ["--configure", env] -> configure_environment(env)
      ["--validate"] -> validate_configuration()
      ["--generate-allocation"] -> generate_container_allocation()
      ["--update-env", env] -> update_environment_config(env)
      ["--check-alignment"] -> check_system_alignment()
      ["--optimize"] -> optimize_resource_allocation()
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  defp show_current_status do
    IO.puts("🔧 Dynamic Resource Manager - Current Status")
    IO.puts("=" |> String.duplicate(50))
    
    config = load_current_config()
    system_info = get_system_info()
    
    IO.puts("📊 Current Configuration:")
    IO.puts("  Environment: #{config.environment}")
    IO.puts("  Total Cores: #{config.total_cores}")
    IO.puts("  Total RAM: #{config.total_ram_gb}GB")
    IO.puts("  Container Count: #{config.container_count}")
    IO.puts("  Agent Count: #{config.agent_count}")
    
    IO.puts("\n🖥️ System Resources:")
    IO.puts("  Detected Cores: #{system_info.cpu_cores}")
    IO.puts("  Detected RAM: #{system_info.total_ram_gb}GB")
    IO.puts("  Available RAM: #{system_info.available_ram_gb}GB")
    
    alignment_status = check_resource_alignment(config, system_info)
    IO.puts("\n🎯 Resource Alignment:")
    IO.puts("  Status: #{if alignment_status.aligned, do: "✅ ALIGNED", else: "❌ MISALIGNED"}")
    
    unless alignment_status.aligned do
      IO.puts("  Issues:")
      Enum.each(alignment_status.issues, fn issue ->
        IO.puts("    - #{issue}")
      end)
    end
  end

  defp detect_system_resources do
    IO.puts("🔍 Detecting System Resources...")
    
    system_info = get_system_info()
    
    IO.puts("📊 System Resource Detection Results:")
    IO.puts("  CPU Cores: #{system_info.cpu_cores}")
    IO.puts("  Total RAM: #{system_info.total_ram_gb}GB")
    IO.puts("  Available RAM: #{system_info.available_ram_gb}GB")
    IO.puts("  CPU Architecture: #{system_info.architecture}")
    IO.puts("  CPU Model: #{system_info.cpu_model}")
    
    # Save detection results
    detection_file = "./__data/tmp/system_resource_detection_#{timestamp()}.json"
    File.write!(detection_file, Jason.encode!(system_info, pretty: true))
    IO.puts("\n💾 Detection results saved to: #{detection_file}")
    
    # Generate recommended configuration
    recommended_config = generate_recommended_config(system_info)
    IO.puts("\n🎯 Recommended Configuration:")
    IO.puts("  Cores: #{recommended_config.total_cores} (#{recommended_config.utilization_percent}% utilization)")
    IO.puts("  RAM: #{recommended_config.total_ram_gb}GB (#{recommended_config.ram_utilization_percent}% utilization)")
    IO.puts("  Containers: #{recommended_config.container_count}")
    IO.puts("  Agents: #{recommended_config.agent_count}")
  end

  defp configure_environment(env) do
    IO.puts("⚙️ Configuring Environment: #{env}")
    
    if Map.has_key?(@environment_configs, env) do
      config = Map.merge(@default_config, @environment_configs[env])
      config = %{config | environment: env}
      
      # Validate against system resources
      system_info = get_system_info()
      alignment = check_resource_alignment(config, system_info)
      
      if alignment.aligned do
        save_configuration(config)
        IO.puts("✅ Environment configured successfully")
        show_configuration_summary(config)
      else
        IO.puts("❌ Configuration validation failed:")
        Enum.each(alignment.issues, fn issue ->
          IO.puts("  - #{issue}")
        end)
        IO.puts("\n🔧 Suggesting automatic adjustment...")
        adjusted_config = auto_adjust_configuration(config, system_info)
        save_configuration(adjusted_config)
        IO.puts("✅ Auto-adjusted configuration saved")
        show_configuration_summary(adjusted_config)
      end
    else
      IO.puts("❌ Unknown environment: #{env}")
      IO.puts("Available environments: #{Map.keys(@environment_configs) |> Enum.join(", ")}")
    end
  end

  defp generate_container_allocation do
    IO.puts("📊 Generating Container Resource Allocation...")
    
    config = load_current_config()
    allocation = calculate_container_allocation(config)
    
    IO.puts("\n🐳 Container Resource Allocation:")
    IO.puts("Environment: #{config.environment} (#{config.total_cores} cores, #{config.total_ram_gb}GB)")
    IO.puts("")
    
    {_total_allocated_cores, _total_allocated_ram} = allocation
    |> Enum.sort_by(fn {_name, alloc} -> alloc.weight end, :desc)
    |> Enum.reduce({0, 0}, fn {container_name, alloc}, {cores_acc, ram_acc} ->
      IO.puts("#{String.pad_trailing(container_name, 20)} | #{Float.round(alloc.cores, 1)} cores | #{Float.round(alloc.ram_gb, 1)}GB | #{alloc.complexity}")
      {cores_acc + alloc.cores, ram_acc + alloc.ram_gb}
    end)
    
    IO.puts("")
    IO.puts("Total Allocated: #{Float.round(total_allocated_cores, 1)} cores, #{Float.round(total_allocated_ram, 1)}GB")
    IO.puts("Utilization: #{Float.round(total_allocated_cores / config.total_cores * 100, 1)}% cores, #{Float.round(total_allocated_ram / config.total_ram_gb * 100, 1)}% RAM")
    
    # Save allocation to file
    allocation_file = "./__data/tmp/container_allocation_#{config.environment}_#{timestamp()}.json"
    allocation_data = %{
      environment: config.environment,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      total_resources: %{cores: config.total_cores, ram_gb: config.total_ram_gb},
      allocations: allocation,
      totals: %{
        allocated_cores: Float.round(total_allocated_cores, 2),
        allocated_ram_gb: Float.round(total_allocated_ram, 2),
        core_utilization: Float.round(total_allocated_cores / config.total_cores * 100, 1),
        ram_utilization: Float.round(total_allocated_ram / config.total_ram_gb * 100, 1)
      }
    }
    
    File.write!(allocation_file, Jason.encode!(allocation_data, pretty: true))
    IO.puts("💾 Allocation saved to: #{allocation_file}")
  end

  defp check_system_alignment do
    IO.puts("🎯 Checking System Resource Alignment...")
    
    config = load_current_config()
    system_info = get_system_info()
    alignment = check_resource_alignment(config, system_info)
    
    IO.puts("📊 Alignment Check Results:")
    IO.puts("  Configuration: #{config.total_cores} cores, #{config.total_ram_gb}GB")
    IO.puts("  System: #{system_info.cpu_cores} cores, #{system_info.total_ram_gb}GB")
    IO.puts("  Status: #{if alignment.aligned, do: "✅ ALIGNED", else: "❌ MISALIGNED"}")
    
    if alignment.aligned do
      IO.puts("  ✅ All resource allocations are within system limits")
      IO.puts("  ✅ Configuration is optimized for current system")
    else
      IO.puts("  ❌ Alignment Issues Found:")
      Enum.each(alignment.issues, fn issue ->
        IO.puts("    - #{issue}")
      end)
      
      IO.puts("\n🔧 Recommended Actions:")
      Enum.each(alignment.recommendations, fn rec ->
        IO.puts("    • #{rec}")
      end)
    end
  end

  # Helper Functions

  defp get_system_info do
    cpu_cores = get_cpu_cores()
    {_total_ram_gb, _available_ram_gb} = get_memory_info()
    architecture = get_cpu_architecture()
    cpu_model = get_cpu_model()
    
    %{
      cpu_cores: cpu_cores,
      total_ram_gb: total_ram_gb,
      available_ram_gb: available_ram_gb,
      architecture: architecture,
      cpu_model: cpu_model,
      detection_timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp get_cpu_cores do
    case System.cmd("nproc", []) do
      {output, 0} -> String.trim(output) |> String.to_integer()
      _ -> 
        # Fallback: try to read from /proc/cpuinfo
        case File.read("/proc/cpuinfo") do
          {:ok, content} ->
            content
            |> String.split("\n")
            |> Enum.count(fn line -> String.starts_with?(line, "processor") end)
          _ -> 4  # Default fallback
        end
    end
  end

  defp get_memory_info do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        lines = String.split(content, "\n")
        
        total_kb = lines
        |> Enum.find(fn line -> String.starts_with?(line, "MemTotal:") end)
        |> extract_memory_value()
        
        available_kb = lines
        |> Enum.find(fn line -> String.starts_with?(line, "MemAvailable:") end)
        |> extract_memory_value()
        
        total_gb = Float.round(total_kb / 1024 / 1024, 1)
        available_gb = Float.round(available_kb / 1024 / 1024, 1)
        
        {total_gb, available_gb}
      _ -> {8.0, 6.0}  # Default fallback
    end
  end

  defp extract_memory_value(nil), do: 0
  defp extract_memory_value(line) do
    line
    |> String.split()
    |> Enum.at(1)
    |> String.to_integer()
  end

  defp get_cpu_architecture do
    case System.cmd("uname", ["-m"]) do
      {output, 0} -> String.trim(output)
      _ -> "unknown"
    end
  end

  defp get_cpu_model do
    case File.read("/proc/cpuinfo") do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find(fn line -> String.starts_with?(line, "model name") end)
        |> case do
          nil -> "unknown"
          line -> 
            line
            |> String.split(":")
            |> Enum.at(1)
            |> String.trim()
        end
      _ -> "unknown"
    end
  end

  defp load_current_config do
    config_file = "./config/resource_config.json"
    
    if File.exists?(config_file) do
      case File.read(config_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, config_map} ->
              config_map
              |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
              |> Map.new()
            _ -> @default_config
          end
        _ -> @default_config
      end
    else
      @default_config
    end
  end

  defp save_configuration(config) do
    config_dir = "./config"
    File.mkdir_p!(config_dir)
    
    config_file = "#{config_dir}/resource_config.json"
    File.write!(config_file, Jason.encode!(config, pretty: true))
    
    # Also save a timestamped backup
    backup_file = "./__data/tmp/resource_config_backup_#{timestamp()}.json"
    File.write!(backup_file, Jason.encode!(config, pretty: true))
  end

  defp calculate_container_allocation(config) do
    available_cores = config.total_cores * (config.resource_utilization || 0.8)
    available_ram = config.total_ram_gb * (config.resource_utilization || 0.8)
    
    total_weight = @container_complexity_weights
    |> Map.values()
    |> Enum.map(& &1.weight)
    |> Enum.sum()
    
    @container_complexity_weights
    |> Enum.map(fn {container_name, %{complexity: complexity, weight: weight}} ->
      cores = (available_cores * weight / total_weight) |> Float.round(2)
      ram_gb = (available_ram * weight / total_weight) |> Float.round(2)
      
      {container_name, %{
        cores: cores,
        ram_gb: ram_gb,
        complexity: complexity,
        weight: weight,
        cpu_limit: "#{cores}",
        memory_limit: "#{trunc(ram_gb * 1024)}m"
      }}
    end)
    |> Map.new()
  end

  defp check_resource_alignment(config, system_info) do
    issues = []
    recommendations = []
    
    # Check CPU alignment
    {_issues, _recommendations} = if config.total_cores > system_info.cpu_cores do
      {
        ["Configured cores (#{config.total_cores}) exceed system cores (#{system_info.cpu_cores})" | issues],
        ["Reduce total_cores to #{system_info.cpu_cores} or less" | recommendations]
      }
    else
      {issues, recommendations}
    end
    
    # Check RAM alignment
    {_issues, _recommendations} = if config.total_ram_gb > system_info.available_ram_gb do
      {
        ["Configured RAM (#{config.total_ram_gb}GB) exceeds available RAM (#{system_info.available_ram_gb}GB)" | issues],
        ["Reduce total_ram_gb to #{trunc(system_info.available_ram_gb * 0.9)} GB or less" | recommendations]
      }
    else
      {issues, recommendations}
    end
    
    %{
      aligned: Enum.empty?(issues),
      issues: issues,
      recommendations: recommendations
    }
  end

  defp generate_recommended_config(system_info) do
    # Use 80% of system resources for safety
    recommended_cores = trunc(system_info.cpu_cores * 0.8)
    recommended_ram = trunc(system_info.available_ram_gb * 0.8)
    
    # Scale containers and agents based on resources
    container_count = max(6, min(16, recommended_cores))
    agent_count = container_count * 5  # 5 agents per container average
    
    %{
      total_cores: recommended_cores,
      total_ram_gb: recommended_ram,
      container_count: container_count,
      agent_count: agent_count,
      utilization_percent: 80,
      ram_utilization_percent: trunc(recommended_ram / system_info.total_ram_gb * 100)
    }
  end

  defp auto_adjust_configuration(config, system_info) do
    recommended = generate_recommended_config(system_info)
    
    %{config |
      total_cores: recommended.total_cores,
      total_ram_gb: recommended.total_ram_gb,
      container_count: recommended.container_count,
      agent_count: recommended.agent_count
    }
  end

  defp show_configuration_summary(config) do
    IO.puts("\n📊 Configuration Summary:")
    IO.puts("  Environment: #{config.environment}")
    IO.puts("  Total Cores: #{config.total_cores}")
    IO.puts("  Total RAM: #{config.total_ram_gb}GB")
    IO.puts("  Container Count: #{config.container_count}")
    IO.puts("  Agent Count: #{config.agent_count}")
    IO.puts("  Resource Utilization: #{trunc((config.resource_utilization || 0.8) * 100)}%")
  end

  defp validate_configuration do
    IO.puts("✅ Validating Resource Configuration...")
    
    config = load_current_config()
    system_info = get_system_info()
    
    # Validate configuration completeness
    __required_keys = [:total_cores, :total_ram_gb, :environment, :container_count, :agent_count]
    missing_keys = __required_keys -- Map.keys(config)
    
    if not Enum.empty?(missing_keys) do
      IO.puts("❌ Configuration incomplete. Missing keys: #{Enum.join(missing_keys, ", ")}")
      {:error, :incomplete_config}
    else
    
    # Validate resource alignment
    alignment = check_resource_alignment(config, system_info)
    
    if alignment.aligned do
      IO.puts("✅ Configuration validation successful")
      IO.puts("✅ All resource allocations are within system limits")
      
      # Test container allocation
      allocation = calculate_container_allocation(config)
      total_cores = allocation |> Map.values() |> Enum.map(& &1.cores) |> Enum.sum()
      total_ram = allocation |> Map.values() |> Enum.map(& &1.ram_gb) |> Enum.sum()
      
      IO.puts("✅ Container allocation validated:")
      IO.puts("  Total allocated: #{Float.round(total_cores, 1)} cores, #{Float.round(total_ram, 1)}GB")
      IO.puts("  Utilization: #{Float.round(total_cores / config.total_cores * 100, 1)}% cores, #{Float.round(total_ram / config.total_ram_gb * 100, 1)}% RAM")
    else
      IO.puts("❌ Configuration validation failed:")
      Enum.each(alignment.issues, fn issue ->
        IO.puts("  - #{issue}")
      end)
      {:error, :validation_failed}
    end
    end
  end

  defp optimize_resource_allocation do
    IO.puts("🚀 Optimizing Resource Allocation...")
    
    config = load_current_config()
    system_info = get_system_info()
    
    # Generate optimized allocation
    optimized_config = auto_adjust_configuration(config, system_info)
    allocation = calculate_container_allocation(optimized_config)
    
    IO.puts("📊 Optimization Results:")
    IO.puts("  Original: #{config.total_cores} cores, #{config.total_ram_gb}GB")
    IO.puts("  Optimized: #{optimized_config.total_cores} cores, #{optimized_config.total_ram_gb}GB")
    
    # Show efficiency gains
    original_allocation = calculate_container_allocation(config)
    original_total_cores = original_allocation |> Map.values() |> Enum.map(& &1.cores) |> Enum.sum()
    optimized_total_cores = allocation |> Map.values() |> Enum.map(& &1.cores) |> Enum.sum()
    
    efficiency_gain = (optimized_total_cores - original_total_cores) / original_total_cores * 100
    
    IO.puts("  Efficiency Gain: #{Float.round(efficiency_gain, 1)}%")
    
    if efficiency_gain > 0 do
      IO.puts("✅ Optimization beneficial - applying changes...")
      save_configuration(optimized_config)
      IO.puts("✅ Optimized configuration saved")
    else
      IO.puts("ℹ️ Current configuration is already optimal")
    end
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\-]/, "") |> String.slice(0, 13)
  end

  defp show_help do
    IO.puts("""
    🔧 Dynamic Resource Manager - SOPv5.11 Cybernetic Framework

    USAGE:
      elixir dynamic_resource_manager.exs [COMMAND]

    COMMANDS:
      --status              Show current resource configuration and system status
      --detect              Detect and analyze system resources
      --configure ENV       Configure resources for specific environment
      --validate            Validate current configuration against system
      --generate-allocation Generate container resource allocation
      --check-alignment     Check alignment between config and system resources
      --optimize            Optimize resource allocation for current system
      --update-env ENV      Update environment-specific configuration
      --help                Show this help message

    ENVIRONMENTS:
      development          10 cores, 48GB (default)
      testing              8 cores, 32GB
      staging              12 cores, 64GB
      production           16 cores, 128GB

    EXAMPLES:
      elixir dynamic_resource_manager.exs --status
      elixir dynamic_resource_manager.exs --configure development
      elixir dynamic_resource_manager.exs --detect
      elixir dynamic_resource_manager.exs --generate-allocation
      elixir dynamic_resource_manager.exs --optimize

    FILES:
      ./config/resource_config.json           Current configuration
      ./__data/tmp/system_resource_detection_*  Detection results
      ./__data/tmp/container_allocation_*       Allocation results
    """)
  end
end

DynamicResourceManager.main(System.argv())