defmodule Mix.Tasks.Compile.Patient do
  @moduledoc """
  Patient compilation task that allows sufficient time for complex Ash resources.

  Accepts that complex Ash projects with 19 domains and 134+ resources
  may take up to 15 minutes to compile and provides appropriate feedback
  and progress monitoring.

  ## Usage

      mix compile.patient

  ## Options

    * `--timeout` - Maximum time to allow (default: 15 minutes)
    * `--progress` - Show compilation progress updates
    * `--memory - monitor` - Monitor memory usage during compilation

  ## Features

  - Realistic time expectations for complex Ash projects
  - Progress monitoring and feedback
  - Memory usage tracking
  - Graceful handling of long compilation times
  - Quality validation with warnings as errors

  This task is ideal for complete project compilation where quality
  and completeness are more important than speed.
  """
  use Mix.Task

  @shortdoc "Patient compilation with realistic time expectations"

  @switches [
    timeout: :integer,
    progress: :boolean,
    memory_monitor: :boolean
  ]

  @spec run(any()) :: any()
  def run(args) do
    {opts, _} = OptionParser.parse!(args, switches: @switches)

    timeout_minutes = opts[:timeout] || 15
    timeout_ms = timeout_minutes * 60 * 1000

    Mix.shell().info("""
    PATIENT COMPILATION STARTING
    ═══════════════════════════════════════════════════════════════════

    This is a complex Ash project with:
    - 19 Ash domains
    - 134+ resources
    - Multi - tenant architecture
    - Extensive relationships and validations

    Expected compilation time: 10 - 15 minutes
    Timeout: #{timeout_minutes} minutes
    ═══════════════════════════════════════════════════════════════════
    """)

    start_time = System.monotonic_time(:millisecond)

    # Start progress monitoring if __requested
    progress_pid =
      if opts[:progress] do
        spawn(fn -> monitor_progress(start_time, timeout_ms) end)
      end

    # Start memory monitoring if __requested
    memory_pid =
      if opts[:memory_monitor] do
        spawn(fn -> monitor_memory() end)
      end

    try do
      # Apply optimizations
      apply_patient_optimizations()

      # Run compilation with proper timeout
      Mix.shell().info("[LAUNCH] Starting compilation with patience...")

      task =
        Task.async(fn ->
          Mix.Task.run("compile", ["--warnings - as - errors", "--force"])
        end)

      result =
        case Task.yield(task, timeout_ms) || Task.shutdown(task) do
          {:ok, result} ->
            result

          nil ->
            Mix.shell().error("Compilation timed out after #{timeout_minutes} minutes")
            :timeout
        end

      # Stop monitoring processes
      if progress_pid, do: Process.exit(progress_pid, :normal)
      if memory_pid, do: Process.exit(memory_pid, :normal)

      # Report results
      report_compilation_results(start_time, result, timeout_minutes)

      result
    rescue
      error ->
        Mix.shell().error("Compilation failed: #{inspect(error)}")
        if progress_pid, do: Process.exit(progress_pid, :normal)
        if memory_pid, do: Process.exit(memory_pid, :normal)
        {:error, error}
    end
  end

  @spec apply_patient_optimizations() :: any()
  defp apply_patient_optimizations do
    # Apply memory optimizations for long compilation
    System.put_env("ERL_AFLAGS", "+P 10_000_000 +Q 1_000_000 +A 512 +hmbs 46_422")
    System.put_env("ELIXIR_ERL_OPTIONS", "+hmbs 46_422 +hms 8348")

    # Ensure we have sufficient resources
    Application.put_env(:ash, :disable_async?, false)
    Application.put_env(:logger, :level, :info)
  end

  @spec monitor_progress(term(), term()) :: term()
  defp monitor_progress(start_time, timeout_ms) do
    progress_loop(start_time, timeout_ms, 1)
  end

  defp progress_loop(start_time, timeout_ms, minute) do
    # Wait 1 minute
    :timer.sleep(60_000)

    elapsed = System.monotonic_time(:millisecond) - start_time
    elapsed_minutes = div(elapsed, 60_000)
    remaining_minutes = div(timeout_ms - elapsed, 60_000)

    if elapsed < timeout_ms do
      Mix.shell().info(
        "Compilation progress: #{elapsed_minutes} minutes elapsed, ~#{remaining_minutes} minutes remaining"
      )

      progress_loop(start_time, timeout_ms, minute + 1)
    end
  end

  @spec monitor_memory() :: any()
  defp monitor_memory do
    memory_loop()
  end

  @spec memory_loop() :: any()
  defp memory_loop do
    # Check every 30 seconds
    :timer.sleep(30_000)

    memory = :erlang.memory()
    total_mb = div(memory[:total], 1024 * 1024)
    processes_mb = div(memory[:processes], 1024 * 1024)

    # > 3GB
    if total_mb > 3000 do
      Mix.shell().info("High memory usage: #{total_mb}MB total, #{processes_mb}MB processes")
    end

    memory_loop()
  end

  defp report_compilation_results(start_time, result, timeout_minutes) do
    duration = System.monotonic_time(:millisecond) - start_time
    duration_minutes = Float.round(duration / 60_000, 2)

    Mix.shell().info("""

    ═══════════════════════════════════════════════════════════════════
    [STATS] PATIENT COMPILATION RESULTS
    ═══════════════════════════════════════════════════════════════════

    Duration: #{duration_minutes} minutes
    Timeout: #{timeout_minutes} minutes
    Result: #{format_result(result)}

    Performance Assessment:
    #{assess_performance(duration_minutes)}

    Memory Usage:
    #{format_memory_usage()}

    #{next_steps(result, duration_minutes)}
    ═══════════════════════════════════════════════════════════════════
    """)
  end

  @spec format_result(term()) :: term()
  defp format_result(:ok), do: "Success - All files compiled successfully"
  defp format_result(:timeout), do: "Timeout - Compilation exceeded time limit"
  defp format_result({:error, _}), do: "Error - Compilation failed"
  defp format_result(_), do: "Unknown - Compilation completed with warnings"

  defp assess_performance(duration_minutes) do
    cond do
      duration_minutes <= 5 ->
        "[LAUNCH] Excellent - Much faster than expected for this project size"

      duration_minutes <= 10 ->
        "Good - Within expected range for complex Ash project"

      duration_minutes <= 15 ->
        "Acceptable - At upper limit but still reasonable"

      true ->
        "Slow - Exceeds reasonable expectations, optimization needed"
    end
  end

  @spec format_memory_usage() :: any()
  defp format_memory_usage do
    memory = :erlang.memory()
    total_mb = div(memory[:total], 1024 * 1024)
    processes_mb = div(memory[:processes], 1024 * 1024)
    system_mb = div(memory[:system], 1024 * 1024)

    "Total: #{total_mb}MB | Processes: #{processes_mb}MB | System: #{system_mb}MB"
  end

  @spec next_steps(term(), term()) :: term()
  defp next_steps(:ok, duration_minutes) when duration_minutes <= 10 do
    Mix.shell().info("""
    NEXT STEPS:
    - Compilation successful within reasonable time
    - You can now start development: mix phx.server
    - Consider using mix compile.fast for daily development
    """)
  end

  defp next_steps(:ok, duration_minutes) when duration_minutes <= 15 do
    Mix.shell().info("""
    NEXT STEPS:
    - Compilation successful but slow
    - You can now start development: mix phx.server
    - Recommend using mix compile.ultra_fast for daily work
    - Consider compilation optimization strategies
    """)
  end

  defp next_steps(:ok, _duration_minutes) do
    Mix.shell().info("""
    NEXT STEPS:
    - Compilation successful but very slow
    - Review compilation optimization guide
    - Consider incremental compilation strategies
    - Monitor system resources during compilation
    """)
  end

  defp next_steps(_, _) do
    Mix.shell().info("""
    NEXT STEPS:
    - Compilation failed or timed out
    - Check available system memory (need 4 GB or more recommended)
    - Try: mix clean && mix compile.patient --timeout 20
    - Review error logs for specific issues
    - Consider incremental compilation approach
    """)
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
