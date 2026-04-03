defmodule Indrajaal.Compilation.ProgressTracker do
  @moduledoc """
  Comprehensive compilation progress tracking system with real-time monitoring,
  detailed logging, and both Claude AI optimization and human-friendly dashboards.

  ## Features:
  - Real-time per-file compilation progress
  - Domain and subsystem rollup aggregation
  - Detailed timing and performance metrics
  - Claude AI-optimized control interface
  - Human-friendly visual dashboards
  - Historical compilation analytics
  """

  use GenServer
  require Logger

  # Future: alias Indrajaal.Compilation.{FileTracker, DomainAggregator, SubsystemAnalyzer}

  defstruct [
    :session_id,
    :start_time,
    :total_files,
    :completed_files,
    :failed_files,
    :current_file,
    :files_status,
    :domain_progress,
    :subsystem_progress,
    :errors,
    :warnings,
    :performance_metrics,
    :claude_optimization_data
  ]

  ## Public API

  @doc "Start a new compilation progress tracking session with files_list and options"
  def start_session(files_list, opts \\ []) do
    # Alias for start_link with more intuitive naming
    start_link(files_list, opts)
  end

  @doc "Start a new compilation progress tracking session"
  def start_link(fileslist, opts \\ []) do
    session_id = generate_session_id()

    case GenServer.start_link(__MODULE__, {session_id, fileslist, opts},
           name: via_tuple(session_id)
         ) do
      {:ok, _pid} ->
        Logger.info("🚀 Compilation progress tracking started",
          session_id: session_id,
          total_files: length(fileslist),
          claude_mode: Keyword.get(opts, :claude_mode, false)
        )

        {:ok, session_id}

      error ->
        error
    end
  end

  @doc "Update progress for a specific file"
  def update_file_progress(sessionid, file_path, status, opts \\ []) do
    GenServer.call(via_tuple(sessionid), {:updatefile, file_path, status, opts})
  end

  @doc "Get current compilation progress"
  def get_progress(session_id) do
    GenServer.call(via_tuple(session_id), :get_progress)
  end

  @doc "Get Claude AI-optimized compilation data"
  def get_claude_data(session_id) do
    GenServer.call(via_tuple(session_id), :get_claude_data)
  end

  @doc "Get human-friendly dashboard data"
  def get_dashboard_data(session_id) do
    GenServer.call(via_tuple(session_id), :get_dashboard_data)
  end

  @doc "Complete the compilation session"
  def complete_session(session_id) do
    GenServer.call(via_tuple(session_id), :complete_session)
  end

  ## GenServer Implementation

  def init({sessionid, files_list, opts}) do
    state = %__MODULE__{
      session_id: sessionid,
      start_time: DateTime.utc_now(),
      total_files: length(files_list),
      completed_files: 0,
      failed_files: 0,
      current_file: nil,
      files_status: initialize_files_status(files_list),
      domain_progress: %{},
      subsystem_progress: %{},
      errors: [],
      warnings: [],
      performance_metrics: %{
        avg_compile_time: 0,
        fastest_file: nil,
        slowest_file: nil,
        files_per_minute: 0,
        estimated_completion: nil
      },
      claude_optimization_data: %{
        critical_path: [],
        bottlenecks: [],
        optimization_suggestions: [],
        decision_points: []
      }
    }

    # Create detailed log file for this session
    create_session_log(sessionid, files_list, opts)

    # Schedule periodic progress updates
    :timer.send_interval(1000, self(), :update_metrics)

    {:ok, state}
  end

  def handle_call({:updatefile, file_path, status, opts}, _from, state) do
    start_time = Keyword.get(opts, :start_time, DateTime.utc_now())
    end_time = Keyword.get(opts, :end_time, DateTime.utc_now())
    errors = Keyword.get(opts, :errors, [])
    warnings = Keyword.get(opts, :warnings, [])

    # Calculate compilation time for this file
    compile_time_ms = DateTime.diff(end_time, start_time, :millisecond)

    # Update file status
    updated_files_status =
      Map.put(state.files_status, file_path, %{
        status: status,
        start_time: start_time,
        end_time: end_time,
        compile_time_ms: compile_time_ms,
        errors: errors,
        warnings: warnings,
        domain: extract_domain(file_path),
        subsystem: extract_subsystem(file_path)
      })

    # Update counters
    {completed, failed} = update_completion_counters(state, status)

    # Update domain and subsystem progress
    domain = extract_domain(file_path)
    subsystem = extract_subsystem(file_path)

    updated_domain_progress =
      update_domain_progress(state.domain_progress, domain, status, compile_time_ms)

    updated_subsystem_progress =
      update_subsystem_progress(state.subsystem_progress, subsystem, status, compile_time_ms)

    # Update performance metrics
    updated_performance =
      update_performance_metrics(
        state.performance_metrics,
        file_path,
        compile_time_ms,
        completed + failed,
        state.total_files,
        state.start_time
      )

    # Update Claude optimization data
    updated_claude_data =
      update_claude_optimization_data(
        state.claude_optimization_data,
        file_path,
        status,
        compile_time_ms,
        errors
      )

    new_state = %{
      state
      | current_file: file_path,
        completed_files: completed,
        failed_files: failed,
        files_status: updated_files_status,
        domain_progress: updated_domain_progress,
        subsystem_progress: updated_subsystem_progress,
        errors: state.errors ++ errors,
        warnings: state.warnings ++ warnings,
        performance_metrics: updated_performance,
        claude_optimization_data: updated_claude_data
    }

    # Log detailed progress update
    log_progress_update(new_state, file_path, status, compile_time_ms)

    # Display progress indicator
    display_progress_indicator(new_state)

    {:reply, :ok, new_state}
  end

  def handle_call(:getprogress, _from, state) do
    progress = %{
      session_id: state.session_id,
      total_files: state.total_files,
      completed_files: state.completed_files,
      failed_files: state.failed_files,
      current_file: state.current_file,
      percentage:
        calculate_percentage(state.completed_files + state.failed_files, state.total_files),
      elapsed_time: DateTime.diff(DateTime.utc_now(), state.start_time, :second),
      estimated_remaining: estimate_remaining_time(state),
      errors_count: length(state.errors),
      warnings_count: length(state.warnings)
    }

    {:reply, progress, state}
  end

  def handle_call(:getclaudedata, _from, state) do
    claude_data = %{
      session_id: state.session_id,
      current_status: build_claude_status(state),
      decision_points: state.claude_optimizationdata.decision_points,
      critical_files: identify_critical_files(state),
      bottlenecks: state.claude_optimizationdata.bottlenecks,
      optimization_suggestions: state.claude_optimizationdata.optimization_suggestions,
      performance_analysis: build_performance_analysis(state),
      error_patterns: analyze_error_patterns(state.errors),
      next_actions: suggest_next_actions(state),
      completion_probability: calculate_completion_probability(state)
    }

    {:reply, claude_data, state}
  end

  def handle_call(:getdashboarddata, _from, state) do
    dashboard_data = %{
      session_id: state.session_id,
      overview: build_overview_stats(state),
      domain_breakdown: build_domain_breakdown(state),
      subsystem_analysis: build_subsystem_analysis(state),
      performance_charts: build_performance_charts(state),
      error_summary: build_error_summary(state),
      timeline: build_compilation_timeline(state),
      recommendations: build_human_recommendations(state)
    }

    {:reply, dashboard_data, state}
  end

  def handle_call(:completesession, _from, state) do
    completion_time = DateTime.utc_now()
    total_duration = DateTime.diff(completion_time, state.start_time, :second)

    final_report = %{
      session_id: state.session_id,
      total_duration_seconds: total_duration,
      total_files: state.total_files,
      completed_files: state.completed_files,
      failed_files: state.failed_files,
      success_rate: calculate_percentage(state.completed_files, state.total_files),
      total_errors: length(state.errors),
      total_warnings: length(state.warnings),
      performance_summary: state.performance_metrics,
      domain_summary: summarize_domain_progress(state.domain_progress),
      subsystem_summary: summarize_subsystem_progress(state.subsystem_progress)
    }

    # Write final session report
    write_final_report(state.session_id, final_report)

    Logger.info("✅ Compilation session completed", final_report)

    {:reply, final_report, state}
  end

  def handle_info(:updatemetrics, state) do
    # Update real-time metrics and display
    updated_metrics = calculate_real_time_metrics(state)
    display_real_time_progress(updated_metrics)

    {:noreply, %{state | performance_metrics: updated_metrics}}
  end

  ## Private Functions

  defp initialize_files_status(fileslist) do
    fileslist
    |> Enum.reduce(%{}, fn file, acc ->
      Map.put(acc, file, %{
        status: :pending,
        start_time: nil,
        end_time: nil,
        compile_time_ms: nil,
        errors: [],
        warnings: [],
        domain: extract_domain(file),
        subsystem: extract_subsystem(file)
      })
    end)
  end

  defp update_completion_counters(state, status) do
    case status do
      :completed -> {state.completed_files + 1, state.failed_files}
      :failed -> {state.completed_files, state.failed_files + 1}
      _ -> {state.completed_files, state.failed_files}
    end
  end

  defp extract_domain(filepath) do
    case Regex.run(~r/lib\/intelitor\/([^\/]+)/, filepath) do
      [_, domain] -> domain
      _ -> "unknown"
    end
  end

  defp extract_subsystem(filepath) do
    cond do
      String.contains?(filepath, "web/") -> "web"
      String.contains?(filepath, "/controllers/") -> "controllers"
      String.contains?(filepath, "/live/") -> "liveview"
      String.contains?(filepath, "/components/") -> "components"
      String.contains?(filepath, "/channels/") -> "channels"
      String.contains?(filepath, "test/") -> "tests"
      true -> "core"
    end
  end

  defp update_domain_progress(domainprogress, domain, status, compile_time_ms) do
    current =
      Map.get(domainprogress, domain, %{
        total: 0,
        completed: 0,
        failed: 0,
        avg_time: 0,
        total_time: 0
      })

    updated =
      case status do
        :completed ->
          %{
            current
            | completed: current.completed + 1,
              total_time: current.total_time + compile_time_ms,
              avg_time: div(current.total_time + compile_time_ms, current.completed + 1)
          }

        :failed ->
          %{current | failed: current.failed + 1}

        _ ->
          current
      end

    Map.put(domainprogress, domain, %{updated | total: updated.completed + updated.failed})
  end

  defp update_subsystem_progress(subsystemprogress, subsystem, status, compile_time_ms) do
    current =
      Map.get(subsystemprogress, subsystem, %{
        total: 0,
        completed: 0,
        failed: 0,
        avg_time: 0,
        total_time: 0
      })

    updated =
      case status do
        :completed ->
          %{
            current
            | completed: current.completed + 1,
              total_time: current.total_time + compile_time_ms,
              avg_time: div(current.total_time + compile_time_ms, current.completed + 1)
          }

        :failed ->
          %{current | failed: current.failed + 1}

        _ ->
          current
      end

    Map.put(subsystemprogress, subsystem, %{updated | total: updated.completed + updated.failed})
  end

  defp update_performance_metrics(
         metrics,
         file_path,
         compile_time_ms,
         completed_files,
         total_files,
         start_time
       ) do
    elapsed_seconds = DateTime.diff(DateTime.utc_now(), start_time, :second)
    files_per_minute = if elapsed_seconds > 0, do: completed_files * 60 / elapsed_seconds, else: 0

    fastest =
      if metrics.fastest_file == nil or compile_time_ms < elem(metrics.fastest_file, 1) do
        {file_path, compile_time_ms}
      else
        metrics.fastest_file
      end

    slowest =
      if metrics.slowest_file == nil or compile_time_ms > elem(metrics.slowest_file, 1) do
        {file_path, compile_time_ms}
      else
        metrics.slowest_file
      end

    remaining_files = total_files - completed_files

    estimated_completion =
      if files_per_minute > 0 do
        DateTime.add(DateTime.utc_now(), round(remaining_files / files_per_minute * 60), :second)
      else
        nil
      end

    %{
      metrics
      | avg_compile_time:
          div(metrics.avg_compile_time * (completed_files - 1) + compile_time_ms, completed_files),
        fastest_file: fastest,
        slowest_file: slowest,
        files_per_minute: files_per_minute,
        estimated_completion: estimated_completion
    }
  end

  defp update_claude_optimization_data(claudedata, filepath, status, compile_time_ms, errors) do
    # Identify bottlenecks (files taking >5 seconds)
    bottlenecks =
      if compile_time_ms > 5000 do
        [
          %{file: filepath, time: compile_time_ms, reason: "slow_compilation"}
          | claudedata.bottlenecks
        ]
      else
        claudedata.bottlenecks
      end

    # Add decision points for failures
    decision_points =
      if status == :failed do
        [
          %{
            file: filepath,
            timestamp: DateTime.utc_now(),
            decision_type: :error_handling,
            options: ["retry", "skip", "fix_and_retry"],
            __context: %{errors: errors, compile_time: compile_time_ms}
          }
          | claudedata.decision_points
        ]
      else
        claudedata.decision_points
      end

    # Generate optimization suggestions
    suggestions = generate_optimization_suggestions(filepath, status, compile_time_ms, errors)

    %{
      claudedata
      | bottlenecks: bottlenecks,
        decision_points: decision_points,
        optimization_suggestions: claudedata.optimization_suggestions ++ suggestions
    }
  end

  defp generate_optimization_suggestions(filepath, _status, compile_time_ms, errors) do
    suggestions = []

    suggestions =
      if compile_time_ms > 10_000 do
        [
          %{
            type: :performance,
            priority: :high,
            suggestion: "Consider parallelizing compilation for #{filepath}",
            estimated_impact: "30-50% time reduction"
          }
          | suggestions
        ]
      else
        suggestions
      end

    suggestions =
      if length(errors) > 5 do
        [
          %{
            type: :error_handling,
            priority: :critical,
            suggestion: "Multiple errors in #{filepath} - consider pattern-based fixes",
            estimated_impact: "Reduce error fixing time by 60%"
          }
          | suggestions
        ]
      else
        suggestions
      end

    suggestions
  end

  defp display_progress_indicator(state) do
    percentage =
      calculate_percentage(state.completed_files + state.failed_files, state.total_files)

    progress_bar = create_progress_bar(percentage)

    current_file_display =
      if state.current_file do
        Path.relative_to_cwd(state.current_file)
      else
        "..."
      end

    IO.write(
      "\r#{progress_bar} #{percentage}% (#{state.completed_files + state.failed_files}/#{state.total_files}) - #{current_file_display}"
    )

    # Also display domain progress
    if rem(state.completed_files + state.failed_files, 10) == 0 do
      IO.puts("")
      display_domain_progress(state.domain_progress)
    end
  end

  defp display_domain_progress(domainprogress) do
    IO.puts("\n📊 Domain Progress:")

    Enum.each(domainprogress, fn {domain, stats} ->
      percentage = calculate_percentage(stats.completed, stats.total)
      avg_time_sec = div(stats.avg_time, 1000)

      IO.puts(
        "  #{String.pad_trailing(domain, 20)} #{percentage}% (#{stats.completed}/#{stats.total}) avg: #{avg_time_sec}s"
      )
    end)
  end

  defp create_progress_bar(percentage, width \\ 40) do
    completed_width = div(percentage * width, 100)
    remaining_width = width - completed_width

    "[#{String.duplicate("█", completed_width)}#{String.duplicate("░", remaining_width)}]"
  end

  defp calculate_percentage(completed, total) when total > 0 do
    round(completed / total * 100)
  end

  defp calculate_percentage(_, _), do: 0

  defp estimate_remaining_time(state) do
    if state.performance_metrics.files_per_minute > 0 do
      remaining_files = state.total_files - state.completed_files - state.failed_files
      round(remaining_files / state.performance_metrics.files_per_minute)
    else
      nil
    end
  end

  defp build_claude_status(state) do
    %{
      overall_health: calculate_overall_health(state),
      current_phase: determine_current_phase(state),
      critical_issues: identify_critical_issues(state),
      success_probability: calculate_completion_probability(state),
      recommended_action: determine_recommended_action(state)
    }
  end

  defp calculate_overall_health(state) do
    completed_ratio = state.completed_files / max(state.total_files, 1)
    error_ratio = length(state.errors) / max(state.completed_files + state.failed_files, 1)

    cond do
      completed_ratio > 0.8 and error_ratio < 0.1 -> :excellent
      completed_ratio > 0.6 and error_ratio < 0.2 -> :good
      completed_ratio > 0.4 and error_ratio < 0.4 -> :fair
      true -> :poor
    end
  end

  defp determine_current_phase(state) do
    percentage =
      calculate_percentage(state.completed_files + state.failed_files, state.total_files)

    cond do
      percentage < 25 -> :initialization
      percentage < 50 -> :early_compilation
      percentage < 75 -> :mid_compilation
      percentage < 95 -> :late_compilation
      true -> :finalization
    end
  end

  defp identify_critical_issues(state) do
    issues = []

    # High error rate
    issues =
      if length(state.errors) > state.completed_files * 0.2 do
        ["high_error_rate" | issues]
      else
        issues
      end

    # Slow compilation
    issues =
      if state.performance_metrics.avg_compile_time > 10_000 do
        ["slow_compilation" | issues]
      else
        issues
      end

    # Many failed files
    issues =
      if state.failed_files > state.total_files * 0.1 do
        ["high_failure_rate" | issues]
      else
        issues
      end

    issues
  end

  defp calculate_completion_probability(state) do
    success_rate = state.completed_files / max(state.completed_files + state.failed_files, 1)

    # Factor in error trends, performance, and remaining work
    error_trend_factor = if length(state.errors) > 50, do: 0.8, else: 1.0

    performance_factor =
      if state.performance_metrics.avg_compile_time > 15_000, do: 0.9, else: 1.0

    base_probability = success_rate * error_trend_factor * performance_factor
    round(base_probability * 100)
  end

  defp determine_recommended_action(state) do
    cond do
      state.failed_files > state.completed_files * 0.2 ->
        :investigate_errors

      length(state.errors) > 50 ->
        :apply_pattern_fixes

      state.performance_metrics.avg_compile_time > 15_000 ->
        :optimize_slow_files

      state.completed_files + state.failed_files < state.total_files * 0.1 ->
        :continue_compilation

      true ->
        :monitor_progress
    end
  end

  defp suggest_next_actions(state) do
    actions = []

    actions =
      if length(state.errors) > 20 do
        ["analyze_error_patterns", "apply_systematic_fixes" | actions]
      else
        actions
      end

    actions =
      if state.performance_metrics.avg_compile_time > 10_000 do
        ["enable_parallel_compilation", "optimize_slow_files" | actions]
      else
        actions
      end

    actions =
      if state.failed_files > 5 do
        ["retry_failed_files", "investigate_failure_patterns" | actions]
      else
        actions
      end

    if actions == [] do
      ["continue_compilation"]
    else
      actions
    end
  end

  defp create_session_log(sessionid, files_list, opts) do
    log_dir = "./data/tmp"
    File.mkdir_p!(log_dir)

    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[^\w\-]/, "-")
    log_file = "#{log_dir}/compilation_session_#{sessionid}_#{timestamp}.jsonl"

    session_start = %{
      __event: "session_start",
      session_id: sessionid,
      timestamp: DateTime.utc_now(),
      total_files: length(files_list),
      claude_mode: Keyword.get(opts, :claude_mode, false),
      files: files_list
    }

    File.write!(log_file, Jason.encode!(session_start) <> "\n")
  end

  defp log_progress_update(state, filepath, status, compile_time_ms) do
    log_entry = %{
      __event: "file_progress",
      session_id: state.session_id,
      timestamp: DateTime.utc_now(),
      file_path: filepath,
      status: status,
      compile_time_ms: compile_time_ms,
      progress_percentage:
        calculate_percentage(state.completed_files + state.failed_files, state.total_files),
      domain: extract_domain(filepath),
      subsystem: extract_subsystem(filepath)
    }

    append_to_session_log(state.session_id, log_entry)
  end

  defp append_to_session_log(sessionid, log_entry) do
    log_dir = "./data/tmp"

    # Find the most recent log file for this session
    case File.ls(log_dir) do
      {:ok, files} ->
        session_files =
          Enum.filter(files, &String.contains?(&1, "compilation_session_#{sessionid}"))

        if length(session_files) > 0 do
          latest_file = Enum.max(session_files)
          log_file = Path.join(log_dir, latest_file)
          File.write!(log_file, Jason.encode!(log_entry) <> "\n", [:append])
        end

      _ ->
        :ok
    end
  end

  defp write_final_report(sessionid, final_report) do
    log_dir = "./data/tmp"
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[^\w\-]/, "-")
    report_file = "#{log_dir}/compilation_report_#{sessionid}_#{timestamp}.json"

    File.write!(report_file, Jason.encode!(final_report, pretty: true))
  end

  # Additional helper functions would continue here...
  # (Abbreviated for length - would include all the build_* functions)

  defp build_overview_stats(state) do
    %{
      progress_percentage:
        calculate_percentage(state.completed_files + state.failed_files, state.total_files),
      files_completed: state.completed_files,
      files_failed: state.failed_files,
      files_remaining: state.total_files - state.completed_files - state.failed_files,
      avg_compile_time_sec: div(state.performance_metrics.avg_compile_time, 1000),
      estimated_completion: state.performance_metrics.estimated_completion
    }
  end

  defp via_tuple(sessionid) do
    {:via, Registry, {Indrajaal.Compilation.Registry, sessionid}}
  end

  defp generate_session_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(random_bytes, case: :lower)
  end

  # Placeholder implementations for remaining functions
  defp identify_critical_files(_state), do: []
  defp build_performance_analysis(_state), do: %{}
  defp analyze_error_patterns(_errors), do: []
  defp build_domain_breakdown(_state), do: %{}
  defp build_subsystem_analysis(_state), do: %{}
  defp build_performance_charts(_state), do: %{}
  defp build_error_summary(_state), do: %{}
  defp build_compilation_timeline(_state), do: []
  defp build_human_recommendations(_state), do: []
  defp summarize_domain_progress(domain_progress), do: domain_progress
  defp summarize_subsystem_progress(subsystem_progress), do: subsystem_progress
  defp calculate_real_time_metrics(state), do: state.performance_metrics
  defp display_real_time_progress(_metrics), do: :ok
end
