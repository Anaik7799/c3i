defmodule Indrajaal.Claude.Logger do
  @moduledoc """
  Claude AI Activity Logging System

  MANDATORY: All Claude-generated logs MUST be stored in ./__data/tmp folder

  Features:
  - Comprehensive activity tracking and audit trail
  - Session management with unique session identifiers
  - Task completion logging with timestamps and outcomes
  - Code generation tracking with TDG compliance validation
  - Performance metrics and execution timing
  - Error tracking and recovery documentation
  - Integration with SOPv5.1 cybernetic coordination

  Agent: Supervisor-1 coordinates all Claude logging activities
  SOPv5.1 Compliance: ✅ Cybernetic feedback loops, comprehensive audit trail
  """

  use GenServer
  require Logger

  @log_directory "./__data/tmp"
  @session_file_prefix "claude_session"
  @activity_file_prefix "claude_activity"
  # 50MB
  @max_log_file_size 50_000_000
  @log_retention_days 30

  # ============================================================================
  # Public API
  # ============================================================================

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generic logging function for backward compatibility.
  Delegates to log_activity/2.
  """
  @spec log(any(), any()) :: any()
  def log(activity_type, details \\ %{}) do
    log_activity(activity_type, details)
  end

  @doc """
  Log Claude activity with comprehensive details.
  MANDATORY: Must be called for ALL significant Claude operations.
  """
  @spec log_activity(any(), any()) :: any()
  def log_activity(activitytype, details \\ %{}) do
    GenServer.cast(__MODULE__, {:log_activity, activitytype, details})
  end

  @doc """
  Start a new Claude session with unique identifier.
  """
  @spec start_session(any()) :: any()
  def start_session(sessioncontext \\ %{}) do
    GenServer.call(__MODULE__, {:start_session, sessioncontext})
  end

  @doc """
  End current Claude session with summary.
  """
  @spec end_session(any()) :: any()
  def end_session(sessionsummary \\ %{}) do
    GenServer.call(__MODULE__, {:end_session, sessionsummary})
  end

  @doc """
  Log task completion with SOPv5.1 compliance details.
  """
  @spec log_task_completion(any(), any()) :: any()
  def log_task_completion(taskid, completion_details) do
    GenServer.cast(__MODULE__, {:log_task_completion, taskid, completion_details})
  end

  @doc """
  Log code generation activity with TDG compliance validation.
  """
  @spec log_code_generation(any(), any()) :: any()
  def log_code_generation(generationtype, code_details) do
    GenServer.cast(__MODULE__, {:log_code_generation, generationtype, code_details})
  end

  @doc """
  Log error or exception with recovery actions.
  """
  @spec log_error(any(), any()) :: any()
  def log_error(errortype, error_details) do
    GenServer.cast(__MODULE__, {:log_error, errortype, error_details})
  end

  @doc """
  Log performance metrics and timing data.
  """
  @spec log_performance(any(), any()) :: any()
  def log_performance(operation, metrics) do
    GenServer.cast(__MODULE__, {:log_performance, operation, metrics})
  end

  @doc """
  Get current session statistics and summary.
  """
  @spec get_session_stats() :: any()
  def get_session_stats do
    GenServer.call(__MODULE__, :get_session_stats)
  end

  @doc """
  Clean up old log files based on retention policy.
  """
  @spec cleanup_old_logs() :: any()
  def cleanup_old_logs do
    GenServer.cast(__MODULE__, :cleanup_old_logs)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  @spec init(any()) :: any()
  def init(opts) do
    # Ensure log directory exists
    File.mkdir_p!(@log_directory)

    # Initialize session
    session_id = generate_session_id()
    session_start_time = DateTime.utc_now()

    state = %{
      current_session_id: session_id,
      session_start_time: session_start_time,
      session_file: get_session_file_path(session_id),
      activity_file: get_activity_file_path(session_id),
      activities_logged: 0,
      tasks_completed: 0,
      code_generations: 0,
      errors_logged: 0,
      retention_days: Keyword.get(opts, :retention_days, @log_retention_days)
    }

    # Write session header
    write_session_header(%{}, state)

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Claude Logger initialized",
      session_id: session_id,
      log_directory: @log_directory
    )

    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), GenServer.from(), map()) :: {:reply, term(), map()}
  def handle_call({:start_session, session_context}, _from, state) do
    new_session_id = generate_session_id()
    new_session_start_time = DateTime.utc_now()

    # End current session if active
    if state.current_session_id do
      write_session_footer(%{}, state)
    end

    new_state = %{
      state
      | current_session_id: new_session_id,
        session_start_time: new_session_start_time,
        session_file: get_session_file_path(new_session_id),
        activity_file: get_activity_file_path(new_session_id),
        activities_logged: 0,
        tasks_completed: 0,
        code_generations: 0,
        errors_logged: 0
    }

    # Write new session header
    write_session_header(session_context, new_state)

    {:reply, {:ok, new_session_id}, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:end_session, _from, state) do
    # Write session footer with summary
    summary = %{
      activities_logged: state.activities_logged,
      tasks_completed: state.tasks_completed,
      code_generations: state.code_generations,
      errors_logged: state.errors_logged
    }

    write_session_footer(summary, state)

    final_stats = %{
      session_id: state.current_session_id,
      duration: DateTime.diff(DateTime.utc_now(), state.session_start_time, :second),
      activities_logged: state.activities_logged,
      tasks_completed: state.tasks_completed,
      code_generations: state.code_generations,
      errors_logged: state.errors_logged
    }

    new_state = %{state | current_session_id: nil}

    {:reply, {:ok, final_stats}, new_state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:getstats, _from, state) do
    stats = %{
      session_id: state.current_session_id,
      session_duration: get_session_duration(state),
      activities_logged: state.activities_logged,
      tasks_completed: state.tasks_completed,
      code_generations: state.code_generations,
      errors_logged: state.errors_logged,
      log_directory: @log_directory,
      session_file: state.session_file,
      activity_file: state.activity_file
    }

    {:reply, stats, state}
  end

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:log_activity, activitytype, details}, state) do
    log_entry = create_log_entry(:activity, activitytype, details)
    write_to_activity_log(state.activity_file, log_entry)

    new_state = %{state | activities_logged: state.activities_logged + 1}
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:task_completed, taskid, completion_details}, state) do
    enhanced_details =
      Map.merge(completion_details, %{
        task_id: taskid,
        completion_timestamp: DateTime.utc_now(),
        session_id: state.current_session_id,
        sopv51_compliance: validate_sopv51_compliance(completion_details)
      })

    log_entry = create_log_entry(:task_completion, :task_completed, enhanced_details)
    write_to_activity_log(state.activity_file, log_entry)

    new_state = %{
      state
      | activities_logged: state.activities_logged + 1,
        tasks_completed: state.tasks_completed + 1
    }

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:code_generated, generationtype, code_details}, state) do
    enhanced_details =
      Map.merge(code_details, %{
        generation_type: generationtype,
        timestamp: DateTime.utc_now(),
        session_id: state.current_session_id,
        tdg_compliance: validate_tdg_compliance(code_details),
        sopv51_agent_coordination: extract_agent_info(code_details)
      })

    log_entry = create_log_entry(:code_generation, generationtype, enhanced_details)
    write_to_activity_log(state.activity_file, log_entry)

    new_state = %{
      state
      | activities_logged: state.activities_logged + 1,
        code_generations: state.code_generations + 1
    }

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:error_occurred, errortype, error_details}, state) do
    enhanced_details =
      Map.merge(error_details, %{
        error_type: errortype,
        timestamp: DateTime.utc_now(),
        session_id: state.current_session_id,
        recovery_actions: Map.get(error_details, :recovery_actions, []),
        impact_assessment: assess_error_impact(error_details)
      })

    log_entry = create_log_entry(:error, errortype, enhanced_details)
    write_to_activity_log(state.activity_file, log_entry)

    new_state = %{
      state
      | activities_logged: state.activities_logged + 1,
        errors_logged: state.errors_logged + 1
    }

    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:log_performance, operation, metrics}, state) do
    enhanced_metrics =
      Map.merge(metrics, %{
        operation: operation,
        timestamp: DateTime.utc_now(),
        session_id: state.current_session_id,
        performance_classification: classify_performance(metrics)
      })

    log_entry = create_log_entry(:performance, operation, enhanced_metrics)
    write_to_activity_log(state.activity_file, log_entry)

    new_state = %{state | activities_logged: state.activities_logged + 1}
    {:noreply, new_state}
  end

  @impl true
  @spec handle_cast(any(), any()) :: any()
  def handle_cast(:cleanup_expired_logs, state) do
    cleanup_expired_logs(state.retention_days)
    {:noreply, state}
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info(:scheduled_cleanup, state) do
    cleanup_expired_logs(state.retention_days)
    schedule_cleanup()
    {:noreply, state}
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  @spec generate_session_id() :: any()
  defp generate_session_id do
    timestamp = DateTime.to_unix(DateTime.utc_now(), :microsecond)
    random_bytes = :crypto.strong_rand_bytes(8)
    random = Base.encode16(random_bytes, case: :lower)
    "claude_#{timestamp}_#{random}"
  end

  @spec get_session_file_path(term()) :: term()
  defp get_session_file_path(sessionid) do
    Path.join(@log_directory, "#{@session_file_prefix}_#{sessionid}.log")
  end

  @spec get_activity_file_path(term()) :: term()
  defp get_activity_file_path(sessionid) do
    Path.join(@log_directory, "#{@activity_file_prefix}_#{sessionid}.jsonl")
  end

  @spec write_session_header(term(), map()) :: term()
  defp write_session_header(context, state) do
    header = %{
      __event: "session_start",
      session_id: state.current_session_id,
      timestamp: DateTime.utc_now(),
      claude_version: "claude-sonnet-4-20250514",
      sopv51_compliance: true,
      __context: context,
      environment: %{
        working_directory: "/home/an/dev/elixir/ash/indrajaal-demo",
        git_branch: get_git_branch(),
        elixir_version: System.version(),
        log_directory: @log_directory
      }
    }

    content = Jason.encode!(header, pretty: true) <> "

# Agent: Supervisor-1 (AI Coordination)
# SOPv5.1 Compliance: ✅ AI coordination and intelligent system management with cybernetic feedback
# Domain: Claude
# Responsibilities: Strategic oversight, coordination, quality assurance, cybernetic goal achievement
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n"
    File.write!(state.session_file, content)
  end

  @spec write_session_footer(term(), map()) :: term()
  defp write_session_footer(summary, state) do
    footer = %{
      __event: "session_end",
      session_id: state.current_session_id,
      timestamp: DateTime.utc_now(),
      session_duration_seconds: get_session_duration(state),
      summary:
        Map.merge(
          %{
            activities_logged: state.activities_logged,
            tasks_completed: state.tasks_completed,
            code_generations: state.code_generations,
            errors_logged: state.errors_logged
          },
          summary
        )
    }

    content = Jason.encode!(footer, pretty: true) <> "\n"
    File.write!(state.session_file, content, [:append])
  end

  @spec write_to_activity_log(term(), term()) :: term()
  defp write_to_activity_log(activityfile, log_entry) do
    content = Jason.encode!(log_entry) <> "\n"
    File.write!(activityfile, content, [:append])

    # Check file size and rotate if necessary
    check_and_rotate_log(activityfile)
  end

  defp create_log_entry(category, type, details) do
    %{
      category: category,
      type: type,
      timestamp: DateTime.utc_now(),
      details: details,
      meta_data: %{
        pid: self() |> :erlang.pid_to_list() |> to_string(),
        node: Node.self(),
        system_time: System.system_time(:microsecond)
      }
    }
  end

  @spec validate_sopv51_compliance(term()) :: term()
  defp validate_sopv51_compliance(completiondetails) do
    %{
      cybernetic_coordination:
        Map.has_key?(
          completiondetails,
          :agent_coordination
        ),
      tps_methodology: Map.has_key?(completiondetails, :tps_analysis),
      stamp_analysis: Map.has_key?(completiondetails, :stamp_validation),
      systematic_execution:
        Map.has_key?(
          completiondetails,
          :systematic_approach
        ),
      quality_gates: Map.has_key?(completiondetails, :quality_validation)
    }
  end

  @spec validate_tdg_compliance(term()) :: term()
  defp validate_tdg_compliance(codedetails) do
    %{
      tests_written_first: Map.get(codedetails, :tests_written_first, false),
      test_coverage: Map.get(codedetails, :test_coverage, 0),
      ai_generated: Map.get(codedetails, :ai_generated, true),
      validation_performed: Map.get(codedetails, :validation_performed, false),
      compliance_score: calculate_tdg_score(codedetails)
    }
  end

  @spec extract_agent_info(term()) :: term()
  defp extract_agent_info(codedetails) do
    %{
      supervisor_oversight: Map.get(codedetails, :supervisor_oversight, false),
      helper_agents_used: Map.get(codedetails, :helper_agents, []),
      worker_agents_used: Map.get(codedetails, :worker_agents, []),
      coordination_level: Map.get(codedetails, :coordination_level, 1),
      cybernetic_feedback: Map.get(codedetails, :cybernetic_feedback, false)
    }
  end

  @spec assess_error_impact(term()) :: term()
  defp assess_error_impact(errordetails) do
    severity = Map.get(errordetails, :severity, :medium)
    scope = Map.get(errordetails, :scope, :local)

    %{
      severity: severity,
      scope: scope,
      business_impact: calculate_business_impact(severity, scope),
      recovery_complexity: Map.get(errordetails, :recovery_complexity, :moderate),
      lessons_learned: Map.get(errordetails, :lessons_learned, [])
    }
  end

  @spec classify_performance(term()) :: term()
  defp classify_performance(metrics) do
    execution_time = Map.get(metrics, :execution_time_ms, 1000)

    cond do
      execution_time < 100 -> :excellent
      execution_time < 500 -> :good
      execution_time < 2000 -> :acceptable
      execution_time < 10_000 -> :slow
      true -> :critical
    end
  end

  @spec get_session_duration(term()) :: term()
  defp get_session_duration(state) do
    DateTime.diff(DateTime.utc_now(), state.session_start_time, :second)
  end

  @spec get_git_branch() :: any()
  def get_git_branch() do
    case System.cmd("git", ["branch", "--show-current"], cd: ".") do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end

  @spec calculate_tdg_score(term()) :: term()
  defp calculate_tdg_score(codedetails) do
    score = 0
    score = if Map.get(codedetails, :tests_written_first, false), do: score + 40, else: score
    score = score + min(Map.get(codedetails, :test_coverage, 0), 40)
    score = if Map.get(codedetails, :validation_performed, false), do: score + 20, else: score
    score
  end

  @spec calculate_business_impact(term(), term()) :: term()
  defp calculate_business_impact(severity, scope) do
    case {severity, scope} do
      {:critical, :system_wide} -> :high
      {:critical, :service} -> :medium_high
      {:high, :system_wide} -> :medium_high
      {:high, :service} -> :medium
      {:medium, :system_wide} -> :medium
      _ -> :low
    end
  end

  @spec check_and_rotate_log(term()) :: term()
  defp check_and_rotate_log(filepath) do
    case File.stat(filepath) do
      {:ok, %{size: size}} when size > @max_log_file_size ->
        rotate_log_file(filepath)

      _ ->
        :ok
    end
  end

  @spec rotate_log_file(term()) :: term()
  defp rotate_log_file(filepath) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    backup_path = "#{filepath}.#{timestamp}"
    File.rename!(filepath, backup_path)
  end

  @spec cleanup_expired_logs(term()) :: term()
  defp cleanup_expired_logs(retentiondays) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-retentiondays, :day)

    case File.ls(@log_directory) do
      {:ok, files} ->
        for file <- files do
          file_path = Path.join(@log_directory, file)

          case File.stat(file_path) do
            {:ok, %{mtime: mtime}} ->
              file_date = mtime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")

              if DateTime.compare(file_date, cutoff_date) == :lt do
                File.rm(file_path)
                Logger.info("Cleaned up expired log file", file: file)
              end

            _ ->
              :ok
          end
        end

      _ ->
        :ok
    end
  end

  @spec schedule_cleanup() :: any()
  defp schedule_cleanup do
    # Schedule cleanup every 24 hours
    Process.send_after(self(), :scheduled_cleanup, :timer.hours(24))
  end
end
