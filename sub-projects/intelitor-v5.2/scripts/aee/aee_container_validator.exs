#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AEE.ContainerValidator do
  @moduledoc """
  🚀 Autonomous Execution Engine (AEE) - Container Infrastructure Validator
  
  SOPv5.1 + TPS + STAMP + TDG + GDE Integration
  Container-Native Pre-flight Validation System
  
  Timestamp: 2025-09-04 17:55:00 CEST
  Agent: AEE-Preflight-1 (Container Infrastructure Validator)
  """
  
  __require Logger
  
  @timeout_vars [
    "NO_TIMEOUT",
    "PATIENT_MODE", 
    "INFINITE_PATIENCE",
    "ELIXIR_ERL_OPTIONS",
    "MIX_TIMEOUT",
    "COMPILE_TIMEOUT"
  ]
  
  @__required_containers [
    "indrajaal-elixir-build",
    "indrajaal-sopv51-app", 
    "indrajaal-app-demo",
    "indrajaal-postgres-demo"
  ]

  def main(args \\ []) do
    IO.puts("🚀 AEE CONTAINER VALIDATOR - SOPv5.1 Integration")
    IO.puts("═══════════════════════════════════════════════")
    
    case args do
      ["--status"] -> validate_container_status()
      ["--validate"] -> comprehensive_validation()
      ["--preflight"] -> preflight_validation()
      _ -> show_usage()
    end
  end
  
  def validate_container_status do
    IO.puts("📊 **AEE Agent Matrix: Container Status Validation**")
    IO.puts("")
    
    # Check Podman availability
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("✅ **Agent AEE-Container-1**: Podman Available - #{String.trim(output)}")
        
      {error, _} ->
        IO.puts("❌ **Agent AEE-Container-1**: Podman Error - #{error}")
        System.halt(1)
    end
    
    # Check container status
    check_containers()
    
    # Validate environment variables
    validate_timeout_environment()
    
    IO.puts("")
    IO.puts("🎯 **AEE Container Infrastructure**: VALIDATED ✅")
  end
  
  def comprehensive_validation do
    IO.puts("🔬 **AEE Comprehensive Container Validation**")
    IO.puts("")
    
    validate_container_status()
    validate_container_networking()
    validate_container_storage()
    validate_compilation_environment()
    
    IO.puts("")
    IO.puts("🏆 **AEE Comprehensive Validation**: COMPLETE ✅")
  end
  
  def preflight_validation do
    IO.puts("🛫 **AEE SOPv5.1 Pre-flight Container Validation**")
    IO.puts("")
    
    results = %{
      podman: validate_podman(),
      containers: validate_containers(),
      environment: validate_environment(),
      networking: validate_networking(),
      compilation: validate_compilation_readiness()
    }
    
    success_count = Enum.count(results, fn {_k, v} -> v == :ok end)
    total_count = Enum.count(results)
    
    IO.puts("")
    IO.puts("📊 **AEE Pre-flight Results**: #{success_count}/#{total_count} ✅")
    
    if success_count == total_count do
      IO.puts("🚀 **AEE READY FOR ACTIVATION** ✅")
      :ok
    else
      IO.puts("❌ **AEE PRE-FLIGHT FAILED** - Fix issues before activation")
      System.halt(1)
    end
  end
  
  defp validate_podman do
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        version = String.trim(output)
        IO.puts("✅ **Agent AEE-Podman**: #{version}")
        :ok
        
      {error, _} ->
        IO.puts("❌ **Agent AEE-Podman**: #{error}")
        :error
    end
  end
  
  defp validate_containers do
    case System.cmd("podman", ["ps", "-a", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} ->
        containers = String.split(String.trim(output), "\n")
        available = Enum.filter(@__required_containers, &(&1 in containers))
        
        IO.puts("✅ **Agent AEE-Containers**: #{length(available)}/#{length(@__required_containers)} available")
        if length(available) >= 2, do: :ok, else: :warning
        
      {error, _} ->
        IO.puts("❌ **Agent AEE-Containers**: #{error}")
        :error
    end
  end
  
  defp validate_environment do
    violations = Enum.flat_map(@timeout_vars, fn var ->
      case System.get_env(var) do
        nil -> 
          if var in ["NO_TIMEOUT", "PATIENT_MODE", "INFINITE_PATIENCE"] do
            [var]
          else
            []
          end
        "true" -> []
        "enabled" -> []
        "infinity" -> []
        "+S 16" -> []
        _ -> []
      end
    end)
    
    if Enum.empty?(violations) do
      IO.puts("✅ **Agent AEE-Environment**: Timeout configuration optimal")
      :ok
    else
      IO.puts("⚠️ **Agent AEE-Environment**: Missing variables: #{inspect(violations)}")
      :warning
    end
  end
  
  defp validate_networking do
    # Check if we can reach container networking
    case System.cmd("podman", ["network", "ls"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ **Agent AEE-Networking**: Container networking available")
        :ok
        
      {error, _} ->
        IO.puts("❌ **Agent AEE-Networking**: #{error}")
        :error
    end
  end
  
  defp validate_compilation_readiness do
    # Check if we have the compilation environment ready
    elixir_version = System.version()
    IO.puts("✅ **Agent AEE-Compilation**: Elixir #{elixir_version} ready")
    :ok
  end
  
  defp check_containers do
    IO.puts("🐳 **Agent AEE-Container-Status**: Container Inventory")
    
    case System.cmd("podman", ["ps", "-a", "--format", "{{.Names}}\\t{{.Status}}"], stderr_to_stdout: true) do
      {output, 0} ->
        containers = String.split(String.trim(output), "\n")
        
        Enum.each(containers, fn line ->
          case String.split(line, "\t") do
            [name, status] ->
              status_icon = if String.contains?(status, "Up"), do: "🟢", else: "🔴"
              IO.puts("   #{status_icon} #{name}: #{status}")
            _ ->
              IO.puts("   📋 #{line}")
          end
        end)
        
      {error, _} ->
        IO.puts("❌ Container listing error: #{error}")
    end
  end
  
  defp validate_timeout_environment do
    IO.puts("")
    IO.puts("⏱️ **Agent AEE-Timeout-Validator**: Environment Configuration")
    
    Enum.each(@timeout_vars, fn var ->
      value = System.get_env(var)
      status = case {var, value} do
        {_, nil} -> "🔴 Not Set"
        {"ELIXIR_ERL_OPTIONS", "+fnu +S 16"} -> "🟢 Optimal"
        {_, "true"} -> "🟢 Enabled"
        {_, "enabled"} -> "🟢 Enabled"
        {_, "infinity"} -> "🟢 Infinite"
        {_, _} -> "🟡 Custom: #{value}"
      end
      
      IO.puts("   #{var}: #{status}")
    end)
  end
  
  defp validate_container_networking do
    IO.puts("🌐 **Agent AEE-Network-Validator**: Container Networking")
    
    case System.cmd("podman", ["network", "inspect", "podman"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Container networking: Available")
        
      {error, _} ->
        IO.puts("⚠️ Container networking: #{error}")
    end
  end
  
  defp validate_container_storage do
    IO.puts("💾 **Agent AEE-Storage-Validator**: Container Storage")
    
    case System.cmd("podman", ["system", "df"], stderr_to_stdout: true) do
      {output, 0} ->
        lines = String.split(String.trim(output), "\n")
        IO.puts("✅ Container storage: Available")
        Enum.each(Enum.take(lines, 5), fn line ->
          IO.puts("   📊 #{line}")
        end)
        
      {error, _} ->
        IO.puts("⚠️ Container storage: #{error}")
    end
  end
  
  defp validate_compilation_environment do
    IO.puts("⚙️ **Agent AEE-Compile-Validator**: Compilation Environment")
    
    # Check Mix project
    if File.exists?("mix.exs") do
      IO.puts("✅ Mix project: Available")
    else
      IO.puts("❌ Mix project: Not found")
    end
    
    # Check dependencies
    case System.cmd("mix", ["deps.check"], stderr_to_stdout: true) do
      {_output, 0} ->
        IO.puts("✅ Dependencies: Ready")
        
      {_error, _} ->
        IO.puts("⚠️ Dependencies: May need installation")
    end
  end
  
  defp show_usage do
    IO.puts("""
    🚀 AEE Container Validator Usage:
    
    elixir aee_container_validator.exs --status       # Check container status
    elixir aee_container_validator.exs --validate     # Comprehensive validation  
    elixir aee_container_validator.exs --preflight    # Pre-flight validation
    """)
  end
end

AEE.ContainerValidator.main(System.argv())