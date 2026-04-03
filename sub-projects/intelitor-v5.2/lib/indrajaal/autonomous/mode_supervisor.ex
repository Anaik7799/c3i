defmodule Indrajaal.Autonomous.ModeSupervisor do
  @moduledoc """
  Autonomous Mode Supervisor - AEE + CAFE + Cybernetic Agent Integration

  WHAT: Autonomous execution supervisor that combines:
  - AEE (Autonomous Execution Environment): Runs without user input until completion
  - CAFE (Cybernetic Architect Framework for Execution): Multi-agent task orchestration
  - Cybernetic Agent: OODA loop, self-healing, adaptive learning

  WHY: Enables fully autonomous task completion with intelligent error recovery,
  real-time monitoring, and adaptive execution strategies.

  CONSTRAINTS:
  - SC-AGT-001: Agent efficiency must be >90%
  - SC-SAF-001: Halt <1s on STAMP violation
  - SC-OBS-069: Dual log output (Terminal + SigNoz)
  - SC-PRF-050: Response latency <50ms for OODA decisions

  Framework: SOPv5.11 + CAFE + Cybernetic + OODA + TPS + STAMP + TDG + GDE + AEE + PHICS
  Created: 2025-12-24
  """

  use GenServer
  require Logger

  @type execution_mode :: :autonomous | :supervised | :interactive
  @type task_status :: :pending | :in_progress | :completed | :failed | :retrying
  @type ooda_phase :: :observe | :orient | :decide | :act

  @ooda_interval_ms 100
  @max_retries 3
  @decision_confidence_threshold 0.7
  @health_check_interval_ms 5_000

  defstruct [
    :mode,
    :mission,
    :tasks,
    :current_task,
    :ooda_state,
    :agents,
    :metrics,
    :start_time,
    :config,
    :execution_log,
    :error_registry,
    :learning_state
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Start the Autonomous Mode Supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a mission autonomously until completion.
  Returns only when the mission is complete or max retries exhausted.
  """
  @spec execute_mission(map()) :: {:ok, map()} | {:error, term()}
  def execute_mission(mission_spec) do
    GenServer.call(__MODULE__, {:execute_mission, mission_spec}, :infinity)
  end

  @doc """
  Execute compilation error fixing mission autonomously.
  """
  @spec fix_compilation_errors() :: {:ok, map()} | {:error, term()}
  def fix_compilation_errors do
    mission = %{
      type: :compilation_fix,
      description: "Fix all compilation errors autonomously",
      phases: [
        :discover_errors,
        :analyze_errors,
        :generate_fixes,
        :apply_fixes,
        :verify_compilation,
        :report_results
      ],
      max_iterations: 10,
      success_criteria: %{
        errors: 0,
        warnings: 0
      }
    }

    execute_mission(mission)
  end

  @doc """
  Get current execution status.
  """
  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Trigger emergency stop.
  """
  @spec emergency_stop() :: :ok
  def emergency_stop do
    GenServer.cast(__MODULE__, :emergency_stop)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl GenServer
  def init(opts) do
    Logger.info("[AMS] Initializing Autonomous Mode Supervisor")

    state = %__MODULE__{
      mode: :autonomous,
      mission: nil,
      tasks: [],
      current_task: nil,
      ooda_state: initialize_ooda_state(),
      agents: initialize_agents(opts),
      metrics: initialize_metrics(),
      start_time: DateTime.utc_now(),
      config: build_config(opts),
      execution_log: [],
      error_registry: %{},
      learning_state: initialize_learning()
    }

    # Start background processes
    schedule_ooda_loop()
    schedule_health_check()

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute_mission, mission_spec}, _from, state) do
    Logger.info("[AMS] Starting mission: #{mission_spec.description}")
    log_event(state, :mission_start, mission_spec)

    # Initialize mission
    state =
      state
      |> Map.put(:mission, mission_spec)
      |> Map.put(:start_time, DateTime.utc_now())
      |> initialize_mission_tasks(mission_spec)

    # Execute mission autonomously
    result = execute_mission_loop(state, mission_spec.max_iterations || 10)

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      mode: state.mode,
      mission: summarize_mission(state.mission),
      current_task: state.current_task,
      tasks_completed: count_completed_tasks(state),
      tasks_remaining: count_pending_tasks(state),
      ooda_metrics: state.ooda_state,
      agent_status: summarize_agents(state.agents),
      execution_duration: calculate_duration(state),
      health: assess_health(state)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_cast(:emergency_stop, state) do
    Logger.warning("[AMS] Emergency stop triggered")
    log_event(state, :emergency_stop, %{reason: :user_requested})

    # Halt all agents
    halt_all_agents(state.agents)

    new_state =
      state
      |> Map.put(:mode, :halted)
      |> Map.put(:current_task, nil)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:ooda_loop, state) do
    if state.mode == :autonomous and state.mission != nil do
      state = execute_ooda_cycle(state)
      schedule_ooda_loop()
      {:noreply, state}
    else
      schedule_ooda_loop()
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:health_check, state) do
    state = perform_health_check(state)
    schedule_health_check()
    {:noreply, state}
  end

  # ============================================================================
  # Mission Execution (AEE Core)
  # ============================================================================

  defp execute_mission_loop(state, 0) do
    Logger.error("[AMS] Mission failed: Max iterations reached")
    {:error, %{reason: :max_iterations_exceeded, state: summarize_state(state)}}
  end

  defp execute_mission_loop(state, iterations_remaining) do
    Logger.info(
      "[AMS] Mission iteration #{state.mission.max_iterations - iterations_remaining + 1}"
    )

    # OODA-driven execution
    case execute_mission_phase(state) do
      {:completed, final_state} ->
        Logger.info("[AMS] Mission completed successfully")
        {:ok, generate_mission_report(final_state)}

      {:continue, updated_state} ->
        execute_mission_loop(updated_state, iterations_remaining - 1)

      {:retry, updated_state, reason} ->
        Logger.warning("[AMS] Retrying mission phase: #{reason}")
        execute_mission_loop(updated_state, iterations_remaining - 1)
    end
  end

  defp execute_mission_phase(state) do
    case state.mission.type do
      :compilation_fix -> execute_compilation_fix_phase(state)
      :test_suite -> execute_test_suite_phase(state)
      :code_analysis -> execute_code_analysis_phase(state)
      _ -> execute_generic_phase(state)
    end
  end

  # ============================================================================
  # Compilation Fix Mission (CAFE Integration)
  # ============================================================================

  defp execute_compilation_fix_phase(state) do
    current_phase = get_current_phase(state)

    case current_phase do
      :discover_errors ->
        {errors, warnings} = discover_compilation_errors()
        state = register_errors(state, errors, warnings)

        if errors == [] do
          Logger.info("[AMS] No compilation errors found")
          {:completed, state}
        else
          Logger.info(
            "[AMS] Found #{Enum.count(errors)} errors, #{Enum.count(warnings)} warnings"
          )

          {:continue, advance_phase(state)}
        end

      :analyze_errors ->
        analyzed = analyze_errors(state.error_registry)
        state = Map.put(state, :error_analysis, analyzed)
        {:continue, advance_phase(state)}

      :generate_fixes ->
        fixes = generate_fixes(state.error_analysis)
        state = Map.put(state, :pending_fixes, fixes)
        {:continue, advance_phase(state)}

      :apply_fixes ->
        results = apply_fixes(state.pending_fixes)
        state = Map.put(state, :fix_results, results)
        {:continue, advance_phase(state)}

      :verify_compilation ->
        {errors, warnings} = discover_compilation_errors()

        if errors == [] do
          Logger.info("[AMS] Compilation verified: 0 errors")
          {:continue, advance_phase(state)}
        else
          Logger.warning("[AMS] Still #{Enum.count(errors)} errors remaining")
          state = register_errors(state, errors, warnings)
          {:retry, reset_to_phase(state, :analyze_errors), :errors_remaining}
        end

      :report_results ->
        {:completed, state}

      nil ->
        {:completed, state}
    end
  end

  defp discover_compilation_errors do
    Logger.info("[AMS] Discovering compilation errors...")

    # Run compilation and capture output
    compile_cmd = """
    POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
    DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
    MIX_ENV=test mix compile 2>&1
    """

    {output, _exit_code} = System.cmd("sh", ["-c", compile_cmd], stderr_to_stdout: true)

    # Parse errors and warnings
    errors = parse_compilation_errors(output)
    warnings = parse_compilation_warnings(output)

    {errors, warnings}
  end

  defp parse_compilation_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "error:"))
    |> Enum.map(&parse_error_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_compilation_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "warning:"))
    |> Enum.map(&parse_warning_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_error_line(line) do
    # Pattern: file:line:col: error: message
    case Regex.run(~r/^([^:]+):(\d+):?(\d+)?: error: (.+)$/, line) do
      [_, file, line_num, col, message] ->
        %{
          file: file,
          line: String.to_integer(line_num),
          column: parse_column(col),
          message: message,
          type: :error
        }

      _ ->
        # Try simpler pattern
        case Regex.run(~r/^([^:]+):(\d+): error: (.+)$/, line) do
          [_, file, line_num, message] ->
            %{
              file: file,
              line: String.to_integer(line_num),
              column: nil,
              message: message,
              type: :error
            }

          _ ->
            nil
        end
    end
  end

  defp parse_warning_line(line) do
    case Regex.run(~r/^([^:]+):(\d+):?(\d+)?: warning: (.+)$/, line) do
      [_, file, line_num, col, message] ->
        %{
          file: file,
          line: String.to_integer(line_num),
          column: parse_column(col),
          message: message,
          type: :warning
        }

      _ ->
        case Regex.run(~r/warning: (.+)$/, line) do
          [_, message] ->
            %{file: nil, line: nil, column: nil, message: message, type: :warning}

          _ ->
            nil
        end
    end
  end

  defp parse_column(""), do: nil
  defp parse_column(col) when is_binary(col), do: String.to_integer(col)
  defp parse_column(_), do: nil

  defp register_errors(state, errors, warnings) do
    error_registry = %{
      errors: errors,
      warnings: warnings,
      by_file: group_by_file(errors ++ warnings),
      timestamp: DateTime.utc_now()
    }

    Map.put(state, :error_registry, error_registry)
  end

  defp group_by_file(issues) do
    Enum.group_by(issues, & &1.file)
  end

  defp analyze_errors(%{errors: errors}) do
    errors
    |> Enum.map(fn error ->
      analysis = %{
        original: error,
        category: categorize_error(error.message),
        fix_strategy: determine_fix_strategy(error),
        confidence: calculate_fix_confidence(error),
        priority: calculate_priority(error)
      }

      analysis
    end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  defp categorize_error(message) do
    cond do
      String.contains?(message, "undefined variable") -> :undefined_variable
      String.contains?(message, "undefined function") -> :undefined_function
      String.contains?(message, "no function clause") -> :pattern_match_error
      String.contains?(message, "is unused") -> :unused_variable
      String.contains?(message, "CompileError") -> :compile_error
      String.contains?(message, "SyntaxError") -> :syntax_error
      true -> :unknown
    end
  end

  defp determine_fix_strategy(error) do
    case categorize_error(error.message) do
      :undefined_variable ->
        %{
          type: :add_variable,
          action: :define_missing_variable,
          patterns: extract_variable_patterns(error.message)
        }

      :undefined_function ->
        %{
          type: :add_import,
          action: :add_missing_import,
          patterns: extract_function_patterns(error.message)
        }

      :unused_variable ->
        %{
          type: :prefix_underscore,
          action: :add_underscore_prefix,
          patterns: extract_unused_variable(error.message)
        }

      _ ->
        %{type: :manual, action: :requires_manual_review, patterns: []}
    end
  end

  defp extract_variable_patterns(message) do
    case Regex.run(~r/undefined variable "([^"]+)"/, message) do
      [_, var] -> [var]
      _ -> []
    end
  end

  defp extract_function_patterns(message) do
    case Regex.run(~r/undefined function ([^\/]+)\/(\d+)/, message) do
      [_, func, arity] -> [{func, String.to_integer(arity)}]
      _ -> []
    end
  end

  defp extract_unused_variable(message) do
    case Regex.run(~r/variable "([^"]+)" is unused/, message) do
      [_, var] -> [var]
      _ -> []
    end
  end

  defp calculate_fix_confidence(error) do
    case categorize_error(error.message) do
      :undefined_variable -> 0.9
      :unused_variable -> 0.95
      :undefined_function -> 0.7
      _ -> 0.3
    end
  end

  defp calculate_priority(error) do
    base_priority =
      case error.type do
        :error -> 100
        :warning -> 50
      end

    confidence_boost = calculate_fix_confidence(error) * 20
    base_priority + confidence_boost
  end

  defp generate_fixes(error_analysis) when is_list(error_analysis) do
    error_analysis
    |> Enum.filter(&(&1.confidence >= @decision_confidence_threshold))
    |> Enum.map(&generate_fix/1)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_fixes(_), do: []

  defp generate_fix(%{original: error, fix_strategy: strategy, confidence: confidence}) do
    case strategy.type do
      :prefix_underscore ->
        generate_underscore_fix(error, strategy, confidence)

      :add_variable ->
        generate_variable_fix(error, strategy, confidence)

      _ ->
        nil
    end
  end

  defp generate_underscore_fix(error, strategy, confidence) do
    case strategy.patterns do
      [var_name | _] ->
        %{
          file: error.file,
          line: error.line,
          type: :replace,
          old_text: var_name,
          new_text: "_#{var_name}",
          confidence: confidence,
          description: "Prefix unused variable with underscore"
        }

      _ ->
        nil
    end
  end

  defp generate_variable_fix(error, strategy, confidence) do
    case strategy.patterns do
      [var_name | _] ->
        %{
          file: error.file,
          line: error.line,
          type: :investigate,
          variable: var_name,
          confidence: confidence,
          description: "Define missing variable '#{var_name}'"
        }

      _ ->
        nil
    end
  end

  defp apply_fixes(fixes) when is_list(fixes) do
    Logger.info("[AMS] Applying #{length(fixes)} fixes")

    fixes
    |> Enum.map(&apply_single_fix/1)
    |> Enum.group_by(& &1.status)
  end

  defp apply_fixes(_), do: %{skipped: []}

  defp apply_single_fix(%{type: :replace, file: file} = fix) when is_binary(file) do
    try do
      if File.exists?(file) do
        content = File.read!(file)
        lines = String.split(content, "\n")

        if fix.line <= length(lines) do
          line_content = Enum.at(lines, fix.line - 1)
          new_line = String.replace(line_content, fix.old_text, fix.new_text, global: false)
          new_lines = List.replace_at(lines, fix.line - 1, new_line)
          new_content = Enum.join(new_lines, "\n")
          File.write!(file, new_content)
          Logger.info("[AMS] Fixed: #{fix.file}:#{fix.line} - #{fix.description}")
          %{status: :applied, fix: fix}
        else
          %{status: :skipped, fix: fix, reason: :line_out_of_range}
        end
      else
        %{status: :skipped, fix: fix, reason: :file_not_found}
      end
    rescue
      e ->
        Logger.warning("[AMS] Failed to apply fix: #{inspect(e)}")
        %{status: :failed, fix: fix, error: e}
    end
  end

  defp apply_single_fix(%{type: :investigate} = fix) do
    Logger.info("[AMS] Needs investigation: #{fix.file}:#{fix.line} - #{fix.description}")
    %{status: :needs_investigation, fix: fix}
  end

  defp apply_single_fix(fix) do
    %{status: :skipped, fix: fix, reason: :unsupported_fix_type}
  end

  # ============================================================================
  # OODA Loop (Cybernetic Agent Core)
  # ============================================================================

  defp initialize_ooda_state do
    %{
      phase: :observe,
      observations: [],
      orientation: nil,
      decision: nil,
      last_action: nil,
      cycle_count: 0,
      latency_history: [],
      confidence_history: []
    }
  end

  defp execute_ooda_cycle(state) do
    start_time = System.monotonic_time(:millisecond)

    state
    |> ooda_observe()
    |> ooda_orient()
    |> ooda_decide()
    |> ooda_act()
    |> record_ooda_latency(start_time)
  end

  defp ooda_observe(state) do
    observations = %{
      task_status: state.current_task,
      tasks_pending: count_pending_tasks(state),
      tasks_completed: count_completed_tasks(state),
      error_count: count_errors(state),
      agent_health: check_agent_health(state.agents),
      memory_usage: get_memory_usage(),
      timestamp: DateTime.utc_now()
    }

    put_in(state.ooda_state.observations, [observations | state.ooda_state.observations])
  end

  defp ooda_orient(state) do
    recent_observations = Enum.take(state.ooda_state.observations, 5)

    orientation = %{
      trend: analyze_observation_trend(recent_observations),
      anomalies: detect_anomalies(recent_observations),
      stress_level: calculate_stress_level(state),
      recommended_action: determine_recommended_action(recent_observations)
    }

    put_in(state.ooda_state.orientation, orientation)
  end

  defp ooda_decide(state) do
    orientation = state.ooda_state.orientation

    decision =
      case orientation.recommended_action do
        :continue -> %{action: :continue, confidence: 0.9}
        :scale_up -> %{action: :scale_agents, direction: :up, confidence: 0.8}
        :scale_down -> %{action: :scale_agents, direction: :down, confidence: 0.7}
        :investigate -> %{action: :investigate_errors, confidence: 0.6}
        :abort -> %{action: :abort_mission, confidence: 0.95}
        _ -> %{action: :continue, confidence: 0.5}
      end

    if decision.confidence >= @decision_confidence_threshold do
      put_in(state.ooda_state.decision, decision)
    else
      put_in(state.ooda_state.decision, %{action: :continue, confidence: 0.5})
    end
  end

  defp ooda_act(state) do
    decision = state.ooda_state.decision

    case decision.action do
      :scale_agents ->
        scale_agents(state.agents, decision.direction)
        put_in(state.ooda_state.last_action, decision)

      :investigate_errors ->
        Logger.debug("[OODA] Investigating errors...")
        put_in(state.ooda_state.last_action, decision)

      :abort_mission ->
        Logger.warning("[OODA] Recommending mission abort")
        put_in(state.ooda_state.last_action, decision)

      _ ->
        put_in(state.ooda_state.last_action, decision)
    end
  end

  defp record_ooda_latency(state, start_time) do
    latency = System.monotonic_time(:millisecond) - start_time
    history = Enum.take([latency | state.ooda_state.latency_history], 100)

    state
    |> put_in([Access.key(:ooda_state), :latency_history], history)
    |> put_in([Access.key(:ooda_state), :cycle_count], state.ooda_state.cycle_count + 1)
  end

  # ============================================================================
  # Agent Management (CAFE Multi-Agent)
  # ============================================================================

  defp initialize_agents(opts) do
    worker_count = Keyword.get(opts, :workers, 4)

    workers =
      1..worker_count
      |> Enum.map(fn i ->
        {:"worker_#{i}",
         %{
           id: "worker_#{i}",
           type: :worker,
           status: :idle,
           tasks_completed: 0,
           errors: 0,
           start_time: DateTime.utc_now()
         }}
      end)
      |> Map.new()

    coordinator = %{
      id: "coordinator",
      type: :coordinator,
      status: :active,
      workers_managed: worker_count,
      start_time: DateTime.utc_now()
    }

    Map.put(workers, :coordinator, coordinator)
  end

  defp summarize_agents(agents) do
    %{
      total: map_size(agents),
      active: Enum.count(agents, fn {_, a} -> a.status in [:active, :busy] end),
      idle: Enum.count(agents, fn {_, a} -> a.status == :idle end),
      errored: Enum.count(agents, fn {_, a} -> a.status == :error end)
    }
  end

  defp halt_all_agents(agents) do
    Enum.each(agents, fn {name, _agent} ->
      Logger.debug("[AMS] Halting agent: #{name}")
    end)
  end

  defp check_agent_health(agents) do
    active_count = Enum.count(agents, fn {_, a} -> a.status in [:active, :idle, :busy] end)
    total = map_size(agents)

    if active_count >= total * 0.8 do
      :healthy
    else
      :degraded
    end
  end

  defp scale_agents(agents, direction) do
    Logger.debug("[AMS] Scaling agents: #{direction}")
    # In production, this would spawn/kill worker processes
    agents
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp build_config(opts) do
    %{
      ooda_interval_ms: Keyword.get(opts, :ooda_interval, @ooda_interval_ms),
      max_retries: Keyword.get(opts, :max_retries, @max_retries),
      confidence_threshold:
        Keyword.get(opts, :confidence_threshold, @decision_confidence_threshold),
      health_check_interval: Keyword.get(opts, :health_check_interval, @health_check_interval_ms),
      patient_mode: Keyword.get(opts, :patient_mode, true)
    }
  end

  defp initialize_metrics do
    %{
      tasks_executed: 0,
      tasks_succeeded: 0,
      tasks_failed: 0,
      ooda_cycles: 0,
      fixes_applied: 0,
      errors_resolved: 0,
      start_time: DateTime.utc_now()
    }
  end

  defp initialize_learning do
    %{
      error_patterns: %{},
      fix_success_rate: %{},
      execution_history: []
    }
  end

  defp initialize_mission_tasks(state, mission_spec) do
    tasks =
      mission_spec.phases
      |> Enum.with_index()
      |> Enum.map(fn {phase, idx} ->
        %{
          id: idx,
          phase: phase,
          status: if(idx == 0, do: :in_progress, else: :pending),
          started_at: if(idx == 0, do: DateTime.utc_now(), else: nil),
          completed_at: nil
        }
      end)

    state
    |> Map.put(:tasks, tasks)
    |> Map.put(:current_task, hd(tasks))
  end

  defp get_current_phase(state) do
    case Enum.find(state.tasks, &(&1.status == :in_progress)) do
      %{phase: phase} -> phase
      nil -> nil
    end
  end

  defp advance_phase(state) do
    current_idx =
      Enum.find_index(state.tasks, &(&1.status == :in_progress))

    if current_idx != nil do
      tasks =
        state.tasks
        |> List.update_at(current_idx, fn task ->
          %{task | status: :completed, completed_at: DateTime.utc_now()}
        end)

      next_idx = current_idx + 1

      tasks =
        if next_idx < length(tasks) do
          List.update_at(tasks, next_idx, fn task ->
            %{task | status: :in_progress, started_at: DateTime.utc_now()}
          end)
        else
          tasks
        end

      current_task =
        Enum.find(tasks, &(&1.status == :in_progress))

      state
      |> Map.put(:tasks, tasks)
      |> Map.put(:current_task, current_task)
    else
      state
    end
  end

  defp reset_to_phase(state, target_phase) do
    target_idx = Enum.find_index(state.tasks, &(&1.phase == target_phase))

    if target_idx != nil do
      tasks =
        state.tasks
        |> Enum.with_index()
        |> Enum.map(fn {task, idx} ->
          cond do
            idx < target_idx -> %{task | status: :completed}
            idx == target_idx -> %{task | status: :in_progress, started_at: DateTime.utc_now()}
            true -> %{task | status: :pending, started_at: nil, completed_at: nil}
          end
        end)

      current_task = Enum.at(tasks, target_idx)

      state
      |> Map.put(:tasks, tasks)
      |> Map.put(:current_task, current_task)
    else
      state
    end
  end

  defp count_completed_tasks(state) do
    Enum.count(state.tasks, &(&1.status == :completed))
  end

  defp count_pending_tasks(state) do
    Enum.count(state.tasks, &(&1.status == :pending))
  end

  defp count_errors(state) do
    case state.error_registry do
      %{errors: errors} -> length(errors)
      _ -> 0
    end
  end

  defp summarize_mission(nil), do: nil

  defp summarize_mission(mission) do
    %{
      type: mission.type,
      description: mission.description,
      phases: mission.phases
    }
  end

  defp summarize_state(state) do
    %{
      mode: state.mode,
      tasks_completed: count_completed_tasks(state),
      tasks_remaining: count_pending_tasks(state),
      errors_found: count_errors(state),
      duration: calculate_duration(state)
    }
  end

  defp calculate_duration(state) do
    DateTime.diff(DateTime.utc_now(), state.start_time, :second)
  end

  defp generate_mission_report(state) do
    fix_results = Map.get(state, :fix_results, %{})
    applied = Map.get(fix_results, :applied, [])

    %{
      status: :completed,
      mission: state.mission.description,
      duration_seconds: calculate_duration(state),
      tasks_completed: count_completed_tasks(state),
      errors_fixed: length(applied),
      errors_remaining: count_errors(state),
      ooda_cycles: state.ooda_state.cycle_count,
      timestamp: DateTime.utc_now()
    }
  end

  defp assess_health(state) do
    cond do
      state.mode == :halted -> :halted
      check_agent_health(state.agents) == :degraded -> :degraded
      count_errors(state) > 50 -> :critical
      true -> :healthy
    end
  end

  defp perform_health_check(state) do
    health = assess_health(state)

    if health in [:degraded, :critical] do
      Logger.warning("[AMS] Health check: #{health}")
    end

    state
  end

  defp log_event(state, event, data) do
    entry = %{
      event: event,
      data: data,
      timestamp: DateTime.utc_now()
    }

    Map.update(state, :execution_log, [entry], &[entry | &1])
  end

  defp analyze_observation_trend([]), do: :stable
  defp analyze_observation_trend([_]), do: :stable

  defp analyze_observation_trend(observations) do
    error_counts = Enum.map(observations, & &1.error_count)

    if Enum.all?(error_counts, &(&1 == 0)) do
      :improving
    else
      :needs_attention
    end
  end

  defp detect_anomalies(_observations), do: []

  defp calculate_stress_level(state) do
    errors = count_errors(state)
    pending = count_pending_tasks(state)

    cond do
      errors > 20 -> :high
      errors > 5 -> :medium
      pending > 10 -> :medium
      true -> :low
    end
  end

  defp determine_recommended_action(observations) do
    case observations do
      [] ->
        :continue

      [latest | _] ->
        cond do
          latest.error_count > 50 -> :abort
          latest.error_count > 10 -> :investigate
          latest.agent_health == :degraded -> :scale_up
          true -> :continue
        end
    end
  end

  defp get_memory_usage do
    total_bytes = :erlang.memory(:total)
    div(total_bytes, 1024 * 1024)
  end

  # ============================================================================
  # Other Mission Types (Placeholders)
  # ============================================================================

  defp execute_test_suite_phase(state), do: {:continue, advance_phase(state)}
  defp execute_code_analysis_phase(state), do: {:continue, advance_phase(state)}
  defp execute_generic_phase(state), do: {:continue, advance_phase(state)}

  # ============================================================================
  # Scheduling
  # ============================================================================

  defp schedule_ooda_loop do
    Process.send_after(self(), :ooda_loop, @ooda_interval_ms)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval_ms)
  end
end
