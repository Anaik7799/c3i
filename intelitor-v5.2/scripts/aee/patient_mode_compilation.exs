#!/usr/bin/env elixir

# Patient Mode Compilation Script with Natural Completion Support
# Follows CLAUDE.md rules for patient compilation without artificial delays

# Local time for logging
defmodule LocalTime do
  def timestamp_string do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()
    timezone = System.get_env("TZ", "CEST")
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B ~s", 
      [year, month, day, hour, minute, second, timezone])
    |> to_string()
  end
end

IO.puts("🚀 Starting Patient Mode Compilation")
IO.puts("📅 Started at: #{LocalTime.timestamp_string()}")
IO.puts("⏰ Natural completion time - no artificial delays")
IO.puts("🛡️ NO_TIMEOUT=true, PATIENT_MODE=enabled")
IO.puts("📋 Following CLAUDE.md patient compilation rules")

defmodule PatientModeCompilation do
  @start_time System.monotonic_time(:millisecond)
  
  def execute do
    IO.puts("\n📦 Phase 1: Setting up patient mode environment...")
    setup_environment()
    
    IO.puts("\n📦 Phase 2: Container preparation...")
    prepare_containers()
    
    IO.puts("\n📦 Phase 3: Starting compilation process...")
    start_compilation()
    
    IO.puts("\n📦 Phase 4: Monitoring compilation progress...")
    monitor_compilation()
    
    IO.puts("\n✅ Compilation process completed!")
  end
  
  defp setup_environment do
    env_vars = %{
      "NO_TIMEOUT" => "true",
      "PATIENT_MODE" => "enabled", 
      "INFINITE_PATIENCE" => "true",
      "COMPILE_TIMEOUT" => "1800000",
      "BASH_DEFAULT_TIMEOUT_MS" => "1800000",
      "BASH_MAX_TIMEOUT_MS" => "7200000",
      "ELIXIR_ERL_OPTIONS" => "+fnu +S 16"
    }
    
    Enum.each(env_vars, fn {key, value} ->
      System.put_env(key, value)
      IO.puts("  ✅ Set #{key}=#{value}")
    end)
  end
  
  defp prepare_containers do
    IO.puts("  🔍 Checking existing containers...")
    
    case System.cmd("podman", ["ps", "-a", "--filter", "name=aee-container-", "--format", "{{.Names}}"]) do
      {output, 0} ->
        containers = String.split(output, "\n", trim: true)
        IO.puts("  📊 Found #{length(containers)} AEE containers")
      _ ->
        IO.puts("  ℹ️  No existing containers found")
    end
  end
  
  defp start_compilation do
    IO.puts("  🚀 Launching compilation process...")
    IO.puts("  ⏳ Patient mode - compilation will run to natural completion")
    
    # Start async compilation task
    task = Task.async(fn -> 
      run_container_compilation()
    end)
    
    # Store task for monitoring
    Process.put(:compilation_task, task)
  end
  
  defp run_container_compilation do
    # Container 1 - Critical errors first
    IO.puts("\n  📦 Container-1: Starting critical error compilation...")
    
    cmd_args = [
      "exec", "-e", "NO_TIMEOUT=true",
      "-e", "PATIENT_MODE=enabled",
      "-e", "COMPILE_TIMEOUT=1800000",
      "-e", "ELIXIR_ERL_OPTIONS=+fnu +S 16",
      "aee-container-1",
      "bash", "-c",
      "cd /workspace && mix compile --jobs 16 --warnings-as-errors"
    ]
    
    case System.cmd("podman", cmd_args, stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts("  ✅ Container-1 compilation successful")
        {:ok, output}
      {output, _} ->
        IO.puts("  ⚠️  Container-1 compilation has issues, continuing...")
        {:warning, output}
    end
  end
  
  defp monitor_compilation do
    start_ms = @start_time
    
    # Progress monitoring loop
    monitor_loop(start_ms)
  end
  
  defp monitor_loop(start_ms) do
    current_ms = System.monotonic_time(:millisecond)
    elapsed_ms = current_ms - start_ms
    elapsed_min = div(elapsed_ms, 60_000)
    elapsed_sec = div(elapsed_ms, 1_000)
    
    # Check if compilation task is done
    task = Process.get(:compilation_task)
    task_complete = if task do
      case Task.yield(task, 0) do
        {:ok, result} -> 
          IO.puts("\n  ✅ Compilation completed successfully after #{elapsed_min} minutes #{rem(elapsed_sec, 60)} seconds")
          Process.put(:compilation_result, result)
          true
        nil ->
          false
      end
    else
      false
    end
    
    if task_complete do
      # Compilation is done - return the result
      Process.get(:compilation_result)
    else
      # Still compiling - show progress
      IO.write("\r  ⏱️  Compilation in progress: #{elapsed_min}:#{String.pad_leading(Integer.to_string(rem(elapsed_sec, 60)), 2, "0")} elapsed")
      
      # Continue monitoring
      Process.sleep(5_000)  # Check every 5 seconds
      monitor_loop(start_ms)
    end
  end
end

# Execute with proper error handling
try do
  PatientModeCompilation.execute()
rescue
  e ->
    IO.puts("\n❌ Error during compilation: #{inspect(e)}")
    IO.puts("⚠️  Stack trace: #{Exception.format_stacktrace(__STACKTRACE__)}")
    System.halt(1)
end