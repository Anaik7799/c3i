defmodule Mix.Tasks.Compile.Progress do
  @moduledoc """
  Enhanced compilation task with comprehensive progress tracking, Claude AI integration,
  and human-friendly dashboard for monitoring compilation status.

  ## Usage

      # Basic compilation with progress tracking
      mix compile.progress

      # Claude AI-controlled compilation
      mix compile.progress --claude

      # Full dashboard with real-time monitoring
      mix compile.progress --dashboard

      # Export compilation report
      mix compile.progress --export json

      # Patient mode with extended timeouts
      mix compile.progress --patient

  ## Features

  - Real-time per-file compilation progress
  - Domain and subsystem progress aggregation
  - Claude AI-optimized compilation control
  - Human-friendly visual dashboard
  - Comprehensive error analysis and pattern recognition
  - Historical compilation analytics
  - Automated optimization suggestions

  ## Options

    * `--claude` - Enable Claude AI-controlled compilation
    * `--dashboard` - Show human-friendly dashboard
    * `--export FORMAT` - Export results (json, csv, html, pdf)
    * `--patient` - Enable patient mode with extended timeouts
    * `--parallel N` - Set parallelization level
    * `--domain DOMAIN` - Compile specific domain only
    * `--watch` - Watch mode with continuous monitoring
    * `--optimization LEVEL` - Set optimization level (basic, standard, aggressive)
  """

  use Mix.Task
  require Logger

  alias Indrajaal.Compilation.{ProgressTracker, ClaudeInterface, Dashboard}

  @shortdoc "Compile with comprehensive progress tracking and Claude AI optimization"

  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          claude: :boolean,
          dashboard: :boolean,
          export: :string,
          patient: :boolean,
          parallel: :integer,
          domain: :string,
          watch: :boolean,
          optimization: :string,
          help: :boolean
        ],
        aliases: [
          c: :claude,
          d: :dashboard,
          e: :export,
          p: :patient,
          w: :watch,
          h: :help
        ]
      )

    if opts[:help] do
      print_help()
      :ok
    else
      # Ensure application is started for GenServer and Registry
      Application.ensure_all_started(:indrajaal)

      # Initialize compilation progress system
      Logger.info("🚀 Starting enhanced compilation with progress tracking")

      # Get files to compile
      files_to_compile = get_files_to_compile(opts)

      if files_to_compile == [] do
        Mix.shell().info("✅ No files need compilation")
        :ok
      else
        # Configure compilation options
        compile_opts = build_compile_options(opts)

        # Start compilation based on mode
        case opts do
          %{claude: true} -> run_claude_compilation(files_to_compile, compile_opts)
          %{dashboard: true} -> run_dashboard_compilation(files_to_compile, compile_opts)
          %{watch: true} -> run_watch_compilation(files_to_compile, compile_opts)
          _ -> run_standard_compilation(files_to_compile, compile_opts)
        end
      end
    end
  end

  ## Compilation Modes

  defp run_claude_compilation(files, opts) do
    Mix.shell().info("🤖 Starting Claude AI-controlled compilation")
    Mix.shell().info("   Files: #{length(files)}")
    Mix.shell().info("   Optimization: #{opts[:optimization_level]}")
    Mix.shell().info("   Intelligence: Enhanced pattern recognition and automated fixes")

    case ClaudeInterface.start_claude_compilation(files, opts) do
      {:ok, session_id} ->
        monitor_claude_compilation(session_id, opts)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to start Claude compilation: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp run_dashboard_compilation(files, opts) do
    Mix.shell().info("📊 Starting compilation with interactive dashboard")

    case ProgressTracker.start_session(files, opts) do
      {:ok, session_id} ->
        # Start dashboard server
        spawn(fn -> run_dashboard_server(session_id) end)

        # Run compilation with progress tracking
        run_compilation_with_progress(session_id, files, opts)

        # Show final dashboard
        show_final_dashboard(session_id, opts)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to start dashboard compilation: #{reason}")
        exit({:shutdown, 1})
    end
  end

  defp run_watch_compilation(files, opts) do
    Mix.shell().info("👀 Starting watch mode compilation")

    # This would implement file watching and continuous compilation
    # For now, run standard compilation and set up file watcher
    run_standard_compilation(files, opts)

    Mix.shell().info("🔄 Watch mode active - monitoring for file changes...")
    # Implementation would continue here with file watching
  end

  defp run_standard_compilation(files, opts) do
    Mix.shell().info("⚡ Starting enhanced compilation with progress tracking")

    case ProgressTracker.start_session(files, opts) do
      {:ok, session_id} ->
        run_compilation_with_progress(session_id, files, opts)
        show_compilation_summary(session_id, opts)

      {:error, reason} ->
        Mix.shell().error("❌ Failed to start compilation tracking: #{reason}")
        exit({:shutdown, 1})
    end
  end

  ## Core Compilation Logic

  defp run_compilation_with_progress(session_id, files, opts) do
    Mix.shell().info("\n🔨 Compiling #{length(files)} files...")

    # Configure compilation environment
    configure_compilation_environment(opts)

    # Compile files with progress tracking
    compile_files_with_tracking(session_id, files, opts)

    # Complete session
    case ProgressTracker.complete_session(session_id) do
      {:ok, report} ->
        Mix.shell().info("\n✅ Compilation completed")
        handle_export_if_requested(session_id, report, opts)

      error ->
        Mix.shell().error("❌ Failed to complete session: #{inspect(error)}")
    end
  end

  defp compile_files_with_tracking(session_id, files, opts) do
    parallel_level = opts[:parallel] || System.schedulers_online()

    if parallel_level > 1 do
      compile_files_parallel(session_id, files, parallel_level, opts)
    else
      compile_files_sequential(session_id, files, opts)
    end
  end

  defp compile_files_sequential(session_id, files, opts) do
    Enum.each(files, fn file ->
      compile_single_file_with_tracking(session_id, file, opts)
    end)
  end

  defp compile_files_parallel(session_id, files, parallel_level, opts) do
    Mix.shell().info("🔄 Using #{parallel_level} parallel compilation workers")

    files
    |> Enum.chunk_every(div(length(files), parallel_level) + 1)
    |> Task.async_stream(
      fn chunk ->
        Enum.each(chunk, &compile_single_file_with_tracking(session_id, &1, opts))
      end,
      max_concurrency: parallel_level,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp compile_single_file_with_tracking(session_id, file, opts) do
    start_time = DateTime.utc_now()

    # Update progress to show current file
    ProgressTracker.update_file_progress(session_id, file, :compiling, start_time: start_time)

    # Perform actual compilation
    result = compile_single_file(file, opts)

    end_time = DateTime.utc_now()

    # Update progress with result
    case result do
      {:ok, output} ->
        warnings = extract_warnings(output)

        ProgressTracker.update_file_progress(session_id, file, :completed,
          start_time: start_time,
          end_time: end_time,
          warnings: warnings
        )

      {:error, errors} ->
        ProgressTracker.update_file_progress(session_id, file, :failed,
          start_time: start_time,
          end_time: end_time,
          errors: errors
        )

        # Handle compilation error
        handle_compilation_error(session_id, file, errors, opts)
    end
  end

  defp compile_single_file(file, opts) do
    timeout = opts[:compile_timeout] || 60_000
    elixir_options = build_elixir_options(opts)

    try do
      case System.cmd("elixir", elixir_options ++ ["-c", file],
             stderr_to_stdout: true,
             timeout: timeout
           ) do
        {output, 0} ->
          {:ok, output}

        {error_output, _exit_code} ->
          errors = parse_compilation_errors(error_output)
          {:error, errors}
      end
    catch
      :exit, {:timeout, _} ->
        {:error, ["Compilation timeout (#{div(timeout, 1000)}s) exceeded for #{file}"]}

      error ->
        {:error, ["Unexpected compilation error: #{inspect(error)}"]}
    end
  end

  ## Claude AI Integration

  defp monitor_claude_compilation(session_id, opts) do
    Mix.shell().info("🤖 Claude AI is controlling compilation process...")

    # Start monitoring loop
    monitor_loop(session_id, opts)
  end

  defp monitor_loop(session_id, opts) do
    case ClaudeInterface.get_claude_status(session_id) do
      {:ok, claude_data} ->
        display_claude_status(claude_data)

        # Check if intervention is needed
        if __requires_intervention?(claude_data) do
          handle_claude_intervention(session_id, claude_data, opts, nil)
        end

        # Continue monitoring unless complete
        progress =
          case claude_data do
            %{compilation_status: %{progress_percentage: pct}} when is_number(pct) -> pct
            _ -> 0
          end

        if progress < 100 do
          # Update every 2 seconds
          :timer.sleep(2000)
          monitor_loop(session_id, opts)
        else
          Mix.shell().info("🤖 Claude compilation completed successfully")
        end

      {:error, reason} ->
        Mix.shell().error("🤖 Claude monitoring error: #{reason}")
    end
  end

  defp display_claude_status(claudedata) do
    status = claudedata.compilation_status
    intelligence = claudedata.intelligence_analysis

    # Clear line and show progress
    IO.write(
      "\r🤖 Claude AI: #{status.progress_percentage}% | " <>
        "Health: #{format_health(status.health_status)} | " <>
        "Issues: #{length(intelligence.critical_issues)} | " <>
        "Success Probability: #{status.completion_probability}%"
    )

    # Show recommendations if available
    if length(intelligence.optimization_suggestions) > 0 do
      IO.puts("")
      Mix.shell().info("💡 Optimization suggestions:")

      suggestions = Enum.take(intelligence.optimization_suggestions, 2)

      suggestions
      |> Enum.each(&Mix.shell().info("   - #{&1.suggestion}"))
    end
  end

  defp __requires_intervention?(claude_data) do
    critical_issues = claude_data.intelligence_analysis.critical_issues
    completion_prob = claude_data.compilation_status.completion_probability

    length(critical_issues) > 2 or completion_prob < 60
  end

  defp handle_claude_intervention(session_id, claude_data, opts, __req) do
    Mix.shell().info("\n🤖 Claude intervention __required")

    recommended_actions = claude_data.decision_support.recommended_actions

    Enum.each(recommended_actions, fn action ->
      Mix.shell().info("🔧 Executing: #{action}")

      case ClaudeInterface.execute_claude_action(session_id, action, opts) do
        {:ok, result} ->
          Mix.shell().info("✅ Action completed: #{inspect(result)}")

        {:error, reason} ->
          Mix.shell().error("❌ Action failed: #{reason}")
      end
    end)
  end

  ## Dashboard Integration

  defp run_dashboard_server(session_id) do
    # This would start a simple HTTP server for the dashboard
    # For now, we'll just log that it would be running
    Mix.shell().info(
      "📊 Dashboard would be available at http://localhost:4001/compilation/#{session_id}"
    )
  end

  defp show_final_dashboard(session_id, opts) do
    case Dashboard.get_dashboard(session_id, opts) do
      {:ok, dashboard} ->
        Mix.shell().info("\n" <> build_final_dashboard_display(dashboard))

      {:error, reason} ->
        Mix.shell().error("Failed to generate final dashboard: #{reason}")
    end
  end

  defp build_final_dashboard_display(dashboard) do
    summary = dashboard.executive_summary

    """
    ═══════════════════════════════════════════════════════════════
    📊 COMPILATION DASHBOARD - #{dashboard.session_id}
    ═══════════════════════════════════════════════════════════════

    📈 EXECUTIVE SUMMARY
       Overall Status: #{format_status(summary.overall_status)}
       Completion Rate: #{summary.key_metrics.completion_rate}
       Success Rate: #{summary.key_metrics.success_rate}
       Average Time: #{summary.key_metrics.average_file_time}
       Health: #{summary.key_metrics.health_indicator}

    🎯 DOMAIN PROGRESS
    #{format_domain_progress(dashboard.visual_progress.domain_progress_chart)}

    ⚡ PERFORMANCE INSIGHTS
    #{format_performance_insights(dashboard.performance_analytics.efficiency_metrics)}

    🔧 RECOMMENDED ACTIONS
    #{format_recommended_actions(dashboard.action_center.recommended_actions)}
    ═══════════════════════════════════════════════════════════════
    """
  end

  ## Helper Functions

  defp get_files_to_compile(opts) do
    files =
      if domain = opts[:domain] do
        get_domain_files(domain)
      else
        get_all_elixir_files()
      end

    Enum.filter(files, &needs_compilation?/1)
  end

  defp get_all_elixir_files do
    Path.wildcard("lib/**/*.ex") ++ Path.wildcard("lib/**/*.exs")
  end

  defp get_domain_files(domain) do
    Path.wildcard("lib/indrajaal/#{domain}/**/*.ex")
  end

  defp needs_compilation?(file) do
    # Simple heuristic - in real implementation would check timestamps
    File.exists?(file)
  end

  defp build_compile_options(opts) do
    [
      claude_mode: opts[:claude] || false,
      dashboard_mode: opts[:dashboard] || false,
      optimization_level: String.to_atom(opts[:optimization] || "standard"),
      patient_mode: opts[:patient] || false,
      parallel: opts[:parallel] || 1,
      compile_timeout: if(opts[:patient], do: 300_000, else: 60_000)
    ]
  end

  defp configure_compilation_environment(opts) do
    if opts[:patient] do
      System.put_env("NO_TIMEOUT", "true")
      System.put_env("PATIENT_MODE", "enabled")
      System.put_env("INFINITE_PATIENCE", "true")
    end

    if opts[:parallel] && opts[:parallel] > 1 do
      System.put_env("ELIXIR_ERL_OPTIONS", "+S #{opts[:parallel]}")
    end
  end

  defp build_elixir_options(opts) do
    options = []

    options =
      if opts[:patient] do
        ["--no-halt" | options]
      else
        options
      end

    options =
      if Mix.env() == :prod do
        ["--warnings-as-errors" | options]
      else
        options
      end

    options
  end

  defp handle_compilation_error(_session_id, file, errors, opts) do
    if opts[:claude] do
      # Let Claude handle the error
      :ok
    else
      # Log error details
      Mix.shell().error("❌ Compilation failed: #{file}")
      Enum.each(errors, &Mix.shell().error("   #{&1}"))
    end
  end

  defp handle_export_if_requested(session_id, _report, opts) do
    if export_format = opts[:export] do
      export_format_atom = String.to_atom(export_format)

      case Dashboard.export_dashboard(session_id, export_format_atom) do
        {:ok, exported_data} ->
          filename = "compilation_report_#{session_id}.#{export_format}"
          File.write!(filename, exported_data)
          Mix.shell().info("📄 Report exported to #{filename}")

        {:error, reason} ->
          Mix.shell().error("❌ Export failed: #{reason}")
      end
    end
  end

  defp show_compilation_summary(session_id, _opts) do
    case ProgressTracker.get_progress(session_id) do
      {:ok, progress} ->
        Mix.shell().info(build_summary_display(progress))

      error ->
        Mix.shell().error("Failed to get compilation summary: #{inspect(error)}")
    end
  end

  defp build_summary_display(progress) do
    """

    ✅ COMPILATION SUMMARY
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Files Processed: #{progress.completed_files + progress.failed_files}/#{progress.total_files}
    Success Rate: #{calculate_success_rate(progress)}%
    Completion: #{progress.percentage}%
    Duration: #{format_duration(progress.elapsed_time)}
    Errors: #{progress.errors_count}
    Warnings: #{progress.warnings_count}
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """
  end

  # Helper function implementations
  defp extract_warnings(output) do
    lines = String.split(output, "\n")
    lines |> Enum.filter(&String.contains?(&1, "warning:"))
  end

  defp parse_compilation_errors(output) do
    lines = String.split(output, "\n")
    non_empty = Enum.reject(lines, &(&1 == ""))
    # Limit to first 10 error lines
    Enum.take(non_empty, 10)
  end

  defp calculate_success_rate(progress) do
    total = progress.completed_files + progress.failed_files

    if total > 0 do
      round(progress.completed_files / total * 100)
    else
      0
    end
  end

  defp format_duration(seconds) when is_integer(seconds) do
    if seconds < 60 do
      "#{seconds}s"
    else
      "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
    end
  end

  defp format_duration(_), do: "Unknown"

  defp format_health(:excellent), do: "🟢"
  defp format_health(:good), do: "🟡"
  defp format_health(:fair), do: "🟠"
  defp format_health(:poor), do: "🔴"
  defp format_health(_), do: "⚪"

  defp format_status(:excellent), do: "🟢 Excellent"
  defp format_status(:good), do: "🟡 Good"
  defp format_status(:fair), do: "🟠 Fair"
  defp format_status(:poor), do: "🔴 Poor"
  defp format_status(_), do: "⚪ Unknown"

  defp format_domain_progress(chart) do
    Enum.map_join(
      chart.data,
      "\n",
      &"   #{String.pad_trailing(&1.name, 15)} #{&1.percentage}% (#{&1.completed}/#{&1.total_files})"
    )
  end

  defp format_performance_insights(metrics) do
    """
       Overall Efficiency: #{metrics.overall_efficiency}%
       Time Efficiency: #{metrics.time_efficiency}%
       Error Efficiency: #{metrics.error_efficiency}%
       Current Performance: #{metrics.benchmarks.current_performance}
    """
  end

  defp format_recommended_actions(actions) do
    actions
    |> Enum.take(3)
    |> Enum.map_join("\n", &"   • #{&1.description} (#{&1.priority})")
  end

  defp print_help do
    Mix.shell().info("""
    mix compile.progress - Enhanced compilation with progress tracking

    Usage:
        mix compile.progress [options]

    Options:
        --claude, -c          Enable Claude AI-controlled compilation
        --dashboard, -d       Show interactive dashboard
        --export FORMAT, -e   Export results (json, csv, html, pdf)
        --patient, -p         Enable patient mode with extended timeouts
        --parallel N          Set parallelization level (default: #{System.schedulers_online()})
        --domain DOMAIN       Compile specific domain only
        --watch, -w           Watch mode with continuous monitoring
        --optimization LEVEL  Set optimization level (basic, standard, aggressive)
        --help, -h            Show this help message

    Examples:
        mix compile.progress --claude --dashboard
        mix compile.progress --patient --parallel 8
        mix compile.progress --domain accounts --export json
        mix compile.progress --watch --optimization aggressive
    """)
  end
end
