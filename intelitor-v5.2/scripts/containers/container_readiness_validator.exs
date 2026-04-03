#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ContainerReadinessValidator do
  @moduledoc """
  Comprehensive container readiness validation with STAMP safety constraints
  Implements TDG methodology with property-based testing principles
  
  STAMP Safety Constraints:
  SC-CONTAINER-001: Container must be accessible and responsive
  SC-CONTAINER-002: SSL certificates must be loadable (minimum 100)
  SC-CONTAINER-003: Development tools must be available and functional
  SC-CONTAINER-004: Compilation environment must be ready
  SC-CONTAINER-005: Patient mode environment must be configured
  """
  
  def main(args) do
    IO.puts("🔍 Container Readiness Validation - STAMP Safety Framework")
    IO.puts("=" |> String.duplicate(65))
    IO.puts("Date: #{DateTime.utc_now() |> DateTime.to_string()}")
    IO.puts("")
    
    container = get_container_name(args)
    comprehensive = Enum.member?(args, "--comprehensive")
    verbose = Enum.member?(args, "--verbose")
    debug = Enum.member?(args, "--debug")
    
    IO.puts("Container: #{container}")
    IO.puts("Mode: #{if comprehensive, do: "Comprehensive", else: "Standard"}")
    IO.puts("Verbosity: #{cond do
      debug -> "Debug"
      verbose -> "Verbose"
      true -> "Standard"
    end}")
    IO.puts("")
    
    validate_container_readiness(container, comprehensive, verbose, debug)
  end
  
  def validate_container_readiness(container, comprehensive, verbose, debug) do
    IO.puts("🧪 Running STAMP Safety Constraint Validation...")
    IO.puts("")
    
    # Define validation suite
    validations = [
      # Core Infrastructure
      {"SC-001: Container Accessibility", &validate_container_running/1, true},
      {"SC-002: SSL Certificate Loading", &validate_ssl_certificates/1, true},
      {"SC-003: Development Tools", &validate_development_tools/1, true},
      {"SC-004: Compilation Readiness", &validate_compilation_readiness/1, true},
      {"SC-005: Patient Mode Environment", &validate_patient_mode_env/1, true},
      
      # Comprehensive validations (optional)
      {"Network Connectivity", &validate_network_connectivity/1, comprehensive},
      {"File System Access", &validate_filesystem_access/1, comprehensive},
      {"Memory and Resources", &validate_system_resources/1, comprehensive},
      {"Database Connectivity", &validate_database_connectivity/1, comprehensive},
      {"Phoenix Environment", &validate_phoenix_environment/1, comprehensive}
    ]
    
    # Execute validations
    _results = Enum.map(validations, fn {name, validator, enabled} ->
      if enabled do
        if verbose or debug, do: IO.puts("🔍 Testing: #{name}")
        
        start_time = System.monotonic_time(:millisecond)
        result = validator.({container, debug})
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        {_status_icon, _status_text} = case result do
          :ok -> 
            {"✅", "PASS"}
          {:ok, message} ->
            if verbose or debug, do: IO.puts("   Details: #{message}")
            {"✅", "PASS"}
          {:warning, message} ->
            if verbose, do: IO.puts("   Warning: #{message}")
            {"⚠️", "WARN"}
          {:error, reason} -> 
            if verbose, do: IO.puts("   Error: #{reason}")
            {"❌", "FAIL"}
        end
        
        duration_text = if debug, do: " (#{duration}ms)", else: ""
        IO.puts("#{status_icon} #{String.pad_trailing(name, 35)} #{status_text}#{duration_text}")
        
        {name, result, duration}
      else
        {name, :skipped, 0}
      end
    end)
    
    # Analyze results
    analyze_validation_results(results, verbose, debug)
  end
  
  # Core Validation Functions
  
  defp validate_container_running({container, debug}) do
    case System.cmd("podman", ["ps", "--filter", "name=#{container}", "--format", "{{.Names}}"]) do
      {output, 0} when output != "" -> 
        if debug, do: {:ok, "Container #{container} is running"}, else: :ok
      {_output, 0} -> 
        {:error, "Container #{container} not found or not running"}
      {error, exit_code} ->
        {:error, "Failed to check container status (exit #{exit_code}): #{error}"}
    end
  end
  
  defp validate_ssl_certificates({container, debug}) do
    case System.cmd("podman", ["exec", container, "elixir", "-e", "length(:pubkey_os_cacerts.get()) |> IO.puts"]) do
      {output, 0} ->
        cert_count = output |> String.trim() |> String.to_integer()
        
        cond do
          cert_count >= 100 -> 
            if debug, do: {:ok, "#{cert_count} certificates loaded"}, else: :ok
          cert_count > 0 ->
            {:warning, "Only #{cert_count} certificates loaded (< 100 recommended)"}
          true ->
            {:error, "No certificates loaded"}
        end
        
      {error, exit_code} ->
        {:error, "SSL certificate test failed (exit #{exit_code}): #{error}"}
    end
  end
  
  defp validate_development_tools({container, debug}) do
    tools = [
      {"Elixir", "elixir --version"},
      {"Mix", "mix --version"},
      {"Make", "make --version"},
      {"GCC", "gcc --version"}
    ]
    
    missing_tools = Enum.filter(tools, fn {_tool_name, command} ->
      case System.cmd("podman", ["exec", container, "sh", "-c", command]) do
        {_output, 0} -> false  # Tool available
        _ -> true  # Tool missing
      end
    end)
    
    case missing_tools do
      [] -> 
        if debug, do: {:ok, "All development tools available"}, else: :ok
      [missing_tool] ->
        {_tool_name, __} = missing_tool
        {:warning, "Missing development tool: #{tool_name}"}
      multiple_missing ->
        _tool_names = Enum.map(multiple_missing, fn {name, _} -> name end)
        {:error, "Missing development tools: #{Enum.join(tool_names, ", ")}"}
    end
  end
  
  defp validate_compilation_readiness({container, debug}) do
    # Test basic compilation environment
    case System.cmd("podman", ["exec", container, "sh", "-c", "cd /workspace && mix compile --jobs 16 --dry-run"]) do
      {_output, 0} -> 
        if debug, do: {:ok, "Compilation environment ready"}, else: :ok
      {error, exit_code} ->
        if String.contains?(error, "deps.get") do
          {:warning, "Dependencies not installed (run mix deps.get)"}
        else
          {:error, "Compilation test failed (exit #{exit_code}): #{String.slice(error, 0, 100)}"}
        end
    end
  end
  
  defp validate_patient_mode_env({container, debug}) do
    env_vars = [
      "NO_TIMEOUT",
      "PATIENT_MODE", 
      "INFINITE_PATIENCE"
    ]
    
    # Check environment variables
    missing_vars = Enum.filter(env_vars, fn var ->
      case System.cmd("podman", ["exec", container, "sh", "-c", "echo $#{var}"]) do
        {output, 0} when output != "" and output != "\\n" -> false  # Variable set
        _ -> true  # Variable missing
      end
    end)
    
    case missing_vars do
      [] ->
        if debug, do: {:ok, "Patient mode environment configured"}, else: :ok
      vars ->
        {:warning, "Patient mode variables not set: #{Enum.join(vars, ", ")}"}
    end
  end
  
  # Comprehensive Validation Functions
  
  defp validate_network_connectivity({container, debug}) do
    case System.cmd("podman", ["exec", container, "ping", "-c", "1", "-W", "3", "8.8.8.8"]) do
      {_output, 0} ->
        if debug, do: {:ok, "Network connectivity available"}, else: :ok
      {_error, exit_code} ->
        {:warning, "Network connectivity test failed (exit #{exit_code}): limited connectivity"}
    end
  end
  
  defp validate_filesystem_access({container, debug}) do
    # Test workspace access
    case System.cmd("podman", ["exec", container, "ls", "/workspace"]) do
      {_output, 0} ->
        case System.cmd("podman", ["exec", container, "touch", "/workspace/.test_write"]) do
          {_output, 0} ->
            System.cmd("podman", ["exec", container, "rm", "-f", "/workspace/.test_write"])
            if debug, do: {:ok, "Workspace read/write access confirmed"}, else: :ok
          {error, exit_code} ->
            {:error, "Workspace write access failed (exit #{exit_code}): #{error}"}
        end
      {error, exit_code} ->
        {:error, "Workspace access failed (exit #{exit_code}): #{error}"}
    end
  end
  
  defp validate_system_resources({container, debug}) do
    case System.cmd("podman", ["exec", container, "sh", "-c", "free -m | grep Mem"]) do
      {output, 0} ->
        # Extract available memory
        memory_info = String.split(output) |> Enum.at(1, "0")
        total_mem = String.to_integer(memory_info)
        
        if total_mem > 1000 do
          if debug, do: {:ok, "Sufficient memory available: #{total_mem}MB"}, else: :ok
        else
          {:warning, "Limited memory available: #{total_mem}MB"}
        end
        
      {_error, _exit_code} ->
        {:warning, "Unable to determine system resources"}
    end
  end
  
  defp validate_database_connectivity({container, debug}) do
    # Test PostgreSQL connectivity if available
    case System.cmd("podman", ["exec", container, "which", "psql"]) do
      {_output, 0} ->
        case System.cmd("podman", ["exec", container, "sh", "-c", "pg_isready -h localhost -p 5433"]) do
          {_output, 0} ->
            if debug, do: {:ok, "Database connectivity confirmed"}, else: :ok
          {_error, _exit_code} ->
            {:warning, "Database not accessible (may not be started)"}
        end
      {_error, _exit_code} ->
        {:warning, "PostgreSQL client not available"}
    end
  end
  
  defp validate_phoenix_environment({container, debug}) do
    # Test Phoenix environment readiness
    case System.cmd("podman", ["exec", container, "sh", "-c", "cd /workspace && mix phx.routes 2>/dev/null | head -1"]) do
      {output, 0} when output != "" ->
        if debug, do: {:ok, "Phoenix environment ready"}, else: :ok
      {_output, _exit_code} ->
        {:warning, "Phoenix environment not ready (may need deps.get)"}
    end
  end
  
  # Results Analysis
  
  defp analyze_validation_results(results, _verbose, debug) do
    total_tests = length(Enum.reject(results, fn {_, result, _} -> result == :skipped end))
    passed = length(Enum.filter(results, fn {_, result, _} -> 
      result == :ok or (is_tuple(result) and elem(result, 0) == :ok)
    end))
    warned = length(Enum.filter(results, fn {_, result, _} -> 
      is_tuple(result) and elem(result, 0) == :warning 
    end))
    failed = length(Enum.filter(results, fn {_, result, _} -> 
      is_tuple(result) and elem(result, 0) == :error 
    end))
    
    if debug do
      total_duration = Enum.sum(Enum.map(results, fn {_, _, duration} -> duration end))
      IO.puts("")
      IO.puts("🕒 Total validation time: #{total_duration}ms")
    end
    
    IO.puts("")
    IO.puts("📊 Validation Summary:")
    IO.puts("   Total Tests: #{total_tests}")
    IO.puts("   ✅ Passed: #{passed}")
    IO.puts("   ⚠️ Warnings: #{warned}")
    IO.puts("   ❌ Failed: #{failed}")
    
    # Determine overall status
    cond do
      failed == 0 and warned == 0 ->
        IO.puts("")
        IO.puts("🎉 CONTAINER READINESS: FULLY VALIDATED")
        IO.puts("🛡️ All STAMP safety constraints satisfied")
        IO.puts("🚀 Ready for Patient Mode development workflow")
        System.halt(0)
        
      failed == 0 and warned > 0 ->
        IO.puts("")
        IO.puts("⚠️ CONTAINER READINESS: VALIDATED WITH WARNINGS")
        IO.puts("🛡️ Critical STAMP safety constraints satisfied")
        IO.puts("🔧 Some optimizations recommended")
        System.halt(0)
        
      true ->
        IO.puts("")
        IO.puts("💥 CONTAINER READINESS: VALIDATION FAILED")
        IO.puts("🚨 STAMP safety constraint violations detected")
        
        # Show failed tests
        failed_tests = Enum.filter(results, fn {_, result, _} -> 
          is_tuple(result) and elem(result, 0) == :error 
        end)
        
        if not Enum.empty?(failed_tests) do
          IO.puts("")
          IO.puts("Critical issues __requiring attention:")
          Enum.each(failed_tests, fn {name, {_, reason}, _} ->
            IO.puts("   • #{name}: #{reason}")
          end)
        end
        
        System.halt(1)
    end
  end
  
  defp get_container_name(args) do
    case Enum.find_index(args, &(&1 == "--container")) do
      nil -> "indrajaal-dev-app"
      index -> Enum.at(args, index + 1, "indrajaal-dev-app")
    end
  end
end

# Help information
if Enum.member?(System.argv(), "--help") do
  IO.puts("""
  Container Readiness Validator - STAMP Safety Framework
  
  Usage: elixir container_readiness_validator.exs [options]
  
  Options:
    --container NAME     Container name (default: indrajaal-dev-app)
    --comprehensive      Run comprehensive validation suite
    --verbose            Enable verbose output
    --debug              Enable debug output with timing
    --help               Show this help
    
  Examples:
    elixir container_readiness_validator.exs
    elixir container_readiness_validator.exs --comprehensive --verbose
    elixir container_readiness_validator.exs --container my-container --debug
    
  STAMP Safety Constraints Validated:
    SC-CONTAINER-001: Container accessibility and responsiveness
    SC-CONTAINER-002: SSL certificate loading (minimum 100 certificates)
    SC-CONTAINER-003: Development tools availability and functionality
    SC-CONTAINER-004: Compilation environment readiness
    SC-CONTAINER-005: Patient mode environment configuration
    
  Exit Codes:
    0: All validations passed (may include warnings)
    1: Critical validation failures detected
  """)
  
  System.halt(0)
end

ContainerReadinessValidator.main(System.argv())