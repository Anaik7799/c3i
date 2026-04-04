#!/usr/bin/env elixir

defmodule SOPv511CompilationSupervisor do
  @moduledoc """
  SOPv5.11 Compilation Supervisor Agent
  
  Monitors compilation progress using tail -f on log file.
  Ensures NO_TIMEOUT policy is enforced.
  Provides real-time progress updates and completion detection.
  
  Created: 2025-09-03 20:35 CEST
  """
  
  __require Logger
  
  @log_file "1-compile.log"
  @progress_interval 5_000  # 5 seconds
  @completion_markers [
    "Compilation failed",
    "warnings generated",
    "errors generated",
    "Generated indrajaal app",
    "mix compile --jobs 16 exited with"
  ]
  
  def main(args) do
    Logger.info("🤖 SOPv5.11 Compilation Supervisor Agent Started")
    Logger.info("Monitoring: #{@log_file}")
    
    # Start compilation in background
    compilation_pid = spawn_compilation()
    
    # Start monitoring
    monitor_compilation(compilation_pid)
  end
  
  defp spawn_compilation do
    Logger.info("🚀 Starting patient mode compilation with NO_TIMEOUT policy")
    
    spawn(fn ->
      System.cmd("bash", ["-c", 
        "NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS='+fnu +S 16' mix compile --jobs 16 --verbose --warnings-as-errors 2>&1 | tee -a #{@log_file}"
      ], into: IO.stream(:stdio, :line))
    end)
  end
  
  defp monitor_compilation(compilation_pid) do
    # Start tail process
    port = Port.open({:spawn, "tail -f #{@log_file}"}, [:binary, :exit_status])
    
    # Initialize __state
    __state = %{
      start_time: System.monotonic_time(:second),
      last_update: System.monotonic_time(:second),
      compiled_count: 0,
      warning_count: 0,
      error_count: 0,
      total_files: 718,
      compilation_pid: compilation_pid,
      port: port,
      buffer: ""
    }
    
    # Start progress reporter
    Process.send_after(self(), :progress_report, @progress_interval)
    
    # Monitor loop
    monitor_loop(__state)
  end
  
  defp monitor_loop(state) do
    receive do
      {port, {:__data, __data}} when port == __state.port ->
        new_state = process_log_data(__state, __data)
        
        # Check for completion
        if compilation_complete?(new_state.buffer) do
          handle_completion(new_state)
        else
          monitor_loop(new_state)
        end
        
      :progress_report ->
        report_progress(__state)
        Process.send_after(self(), :progress_report, @progress_interval)
        monitor_loop(__state)
        
      {port, {:exit_status, _status}} when port == __state.port ->
        Logger.info("Tail process ended, checking final __state...")
        handle_completion(__state)
        
      _ ->
        monitor_loop(__state)
    end
  end
  
  defp process_log_data(state, __data) do
    buffer = __state.buffer <> __data
    lines = String.split(buffer, "\n")
    
    # Keep last incomplete line in buffer
    {_complete_lines, _new_buffer} = 
      case List.last(lines) do
        "" -> {lines, ""}
        incomplete -> {Enum.slice(lines, 0..-2), incomplete}
      end
    
    # Process each line
    _new_state = Enum.reduce(complete_lines, _state, fn line, acc ->
      cond do
        String.contains?(line, "Compiled lib/") ->
          %{acc | compiled_count: acc.compiled_count + 1, last_update: System.monotonic_time(:second)}
          
        String.contains?(line, "warning:") ->
          %{acc | warning_count: acc.warning_count + 1}
          
        String.contains?(line, "error:") ->
          %{acc | error_count: acc.error_count + 1}
          
        true ->
          acc
      end
    end)
    
    %{new_state | buffer: new_buffer}
  end
  
  defp compilation_complete?(buffer) do
    Enum.any?(@completion_markers, &String.contains?(buffer, &1))
  end
  
  defp report_progress(state) do
    elapsed = System.monotonic_time(:second) - __state.start_time
    percentage = Float.round(__state.compiled_count / __state.total_files * 100, 1)
    
    IO.puts("\n📊 Compilation Progress Report:")
    IO.puts("   Elapsed Time: #{format_time(elapsed)}")
    IO.puts("   Files Compiled: #{__state.compiled_count}/#{__state.total_files} (#{percentage}%)")
    IO.puts("   Warnings: #{__state.warning_count}")
    IO.puts("   Errors: #{__state.error_count}")
    IO.puts("   Status: #{get_status(__state)}")
    
    # Check if compilation is stuck
    if System.monotonic_time(:second) - __state.last_update > 60 do
      IO.puts("   ⚠️  No progress in last 60 seconds")
    end
  end
  
  defp handle_completion(state) do
    Port.close(__state.port)
    
    elapsed = System.monotonic_time(:second) - __state.start_time
    
    IO.puts("\n✅ Compilation Completed!")
    IO.puts("   Total Time: #{format_time(elapsed)}")
    IO.puts("   Files Compiled: #{__state.compiled_count}")
    IO.puts("   Warnings: #{__state.warning_count}")
    IO.puts("   Errors: #{__state.error_count}")
    
    # Generate summary
    generate_summary(__state)
  end
  
  defp generate_summary(state) do
    summary = %{
      timestamp: DateTime.utc_now(),
      duration_seconds: System.monotonic_time(:second) - __state.start_time,
      files_compiled: __state.compiled_count,
      warnings: __state.warning_count,
      errors: __state.error_count,
      success: __state.error_count == 0
    }
    
    File.mkdir_p!("__data/tmp")
    File.write!(
      "__data/tmp/claude_compilation_summary_#{DateTime.utc_now() |> DateTime.to_iso8601()}.json",
      Jason.encode!(summary, pretty: true)
    )
  end
  
  defp format_time(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    
    "#{hours}h #{minutes}m #{secs}s"
  end
  
  defp get_status(state) do
    cond do
      __state.error_count > 0 -> "❌ Errors detected"
      __state.warning_count > 0 -> "⚠️  Warnings detected"
      __state.compiled_count < __state.total_files -> "🔄 Compiling..."
      true -> "✅ Success"
    end
  end
end

# Handle Jason dependency
Mix.install([{:jason, "~> 1.4"}])


  @doc "Load dynamic resource configuration"
  defp load_dynamic_resource_config do
    config_script_path = "scripts/config/dynamic_resource_manager.exs"
    
    if File.exists?(config_script_path) do
      try do
        {_result, __} = Code.eval_file(config_script_path)
        case result do
          {:ok, config} -> config
          _ -> fallback_resource_config()
        end
      rescue
        _ -> fallback_resource_config()
      end
    else
      fallback_resource_config()
    end
  end

  defp fallback_resource_config do
    %{
      total_cores: 10,
      total_ram_gb: 48,
      container_count: 10,
      agent_count: 50,
      environment: "development"
    }
  end

SOPv511CompilationSupervisor.main(System.argv())