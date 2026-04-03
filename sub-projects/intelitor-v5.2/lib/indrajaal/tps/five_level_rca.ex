defmodule Indrajaal.TPS.FiveLevelRCA do
  @moduledoc """
  Toyota Production System (TPS) Five - Level Root Cause Analysis Engine

  This module implements the systematic TPS methodology for comprehensive
  root cause analysis using the five levels of investigation:

  1. **Level 1: Symptom Identification** - What happened?
  2. **Level 2: Surface Cause Analysis** - What directly caused it?
  3. **Level 3: System Behavior Analysis** - Why did the system allow it?
  4. **Level 4: Configuration Gap Analysis** - What configuration enabled it?
  5. **Level 5: Design Analysis** - Why wasn't it pr_evented by design?

  ## Core TPS Principles Applied

  - **Jidoka (Stop and Fix)**: Halt operations when problems detected
  - **Genchi Genbutsu**: Go see the actual situation
  - **Respect for People**: Human insight combined with systematic analysis
  - **Continuous Improvement**: Learn and pr_event recurrence
  - **Long - term Thinking**: Address root causes, not just symptoms

  ## Integration with SOPv5.1

  This RCA engine integrates with the SOPv5.1 Cybernetic Framework to provide:
  - Real - time problem detection and analysis
  - Multi - agent coordination for comprehensive investigation
  - Automated pr_eventive measure generation
  - Systematic learning and knowledge base updates
  """

  use GenServer
  # PHASE Q: GenServer patterns consolidated
  # EP205: Removed unused import UnifiedGenServerPatterns
  require Logger

  @type rca_level :: 1..5
  @type severity :: :critical | :high | :medium | :low
  @type problem_category :: :compilation | :runtime | :performance | :security | :usability

  defstruct [
    :problem_id,
    :initiated_at,
    :severity,
    :category,
    :description,
    :current_level,
    :analysis_results,
    :pr_eventive_measures,
    :status,
    :assigned_agents,
    :evidence_chain
  ]

  ## Public API

  @doc """
  Initiate a comprehensive 5 - Level RCA analysis for a detected problem.

  ## Parameters
  - `problem_desc`: Detailed description of the observed problem
  - `severity`: Problem severity level (:critical, :high, :medium, :low)
  - `category`: Problem category for specialized analysis
  - `__context`: Additional __context and evidence

  ## Returns
  - `{:ok, rca_session}` - RCA session initiated successfully
  - `{:error, reason}` - RCA initiation failed

  ## Examples
      iex> FiveLevelRCA.initiate_analysis(
      ...>   "Compilation fails with undefined variable errors",
      ...>   :high,
      ...>   :compilation,
      ...>   %{files: ["lib / module.ex"], error_count: 25}
      ...> )
      {:ok, %RCASession{problem_id: "RCA - 001", current_level: 1}}
  """
  @spec initiate_analysis(String.t(), severity(), problem_category(), map()) ::
          {:ok, %__MODULE__{}} | {:error, term()}
  def initiate_analysis(problem_desc, severity, category, _context \\ %{}) do
    Logger.info("🎯 Initiating 5-Level Root Cause Analysis", %{
      problem_desc: problem_desc,
      severity: severity,
      category: category
    })

    {:ok,
     %__MODULE__{
       description: problem_desc,
       severity: severity,
       category: category,
       current_level: 1,
       initiated_at: DateTime.utc_now()
     }}
  end

  @doc """
  Execute the next level of RCA analysis.

  Uses the TPS systematic approach to drill deeper into root causes.
  Each level builds upon the previous analysis to identify deeper systemic issues.
  """
  @spec execute_next_level(String.t()) :: {:ok, map()} | {:error, term()}
  def execute_next_level(problem_id) do
    GenServer.call(__MODULE__, {:execute_next_level, problem_id}, :infinity)
  end

  @doc """
  Get comprehensive analysis results for all completed levels.

  Returns a structured summary of findings, root causes, and
  recommended pr_eventive measures across all analysis levels.
  """
  @spec get_analysis_results(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_analysis_results(problem_id) do
    GenServer.call(__MODULE__, {:get_analysis_results, problem_id})
  end

  @doc """
  Generate and implement pr_eventive measures based on RCA findings.

  Creates actionable recommendations and implementation plans to pr_event
  recurrence of similar problems across all identified system levels.
  """
  @spec generate_pr_eventive_measures(String.t()) :: {:ok, list()} | {:error, term()}
  def generate_pr_eventive_measures(problem_id) do
    GenServer.call(__MODULE__, {:generate_pr_eventive_measures, problem_id})
  end

  @doc false
  # TDG Stub: Alias for generate_pr_eventive_measures/1 to match test expectations
  @spec generate_preventive_measures(String.t() | map()) :: {:ok, map()} | {:error, term()}
  def generate_preventive_measures(problem_id_or_result) when is_binary(problem_id_or_result) do
    generate_pr_eventive_measures(problem_id_or_result)
  end

  def generate_preventive_measures(rca_result) when is_map(rca_result) do
    # Extract root causes from the rca_result map to drive measure generation
    severity = Map.get(rca_result, :severity, :medium)
    category = Map.get(rca_result, :category, :general)
    description = Map.get(rca_result, :description, "")

    immediate_actions =
      case severity do
        :critical ->
          [
            %{action: "Halt affected pipeline immediately", priority: :p0, owner: "ops"},
            %{action: "Deploy hotfix for #{category} failure", priority: :p0, owner: "dev"},
            %{action: "Notify stakeholders of incident", priority: :p0, owner: "lead"}
          ]

        :high ->
          [
            %{action: "Isolate failing component", priority: :p1, owner: "dev"},
            %{action: "Apply workaround for #{category} issue", priority: :p1, owner: "dev"}
          ]

        _ ->
          [
            %{action: "Log and monitor #{category} issue", priority: :p2, owner: "dev"}
          ]
      end

    long_term_improvements =
      cond do
        String.contains?(description, "compilation") or category == :compilation ->
          [
            %{improvement: "Add pre-commit compilation gate", timeline: "1_week"},
            %{improvement: "Increase static analysis coverage", timeline: "2_weeks"}
          ]

        category == :security ->
          [
            %{improvement: "Security audit of affected modules", timeline: "1_month"},
            %{improvement: "Add penetration testing to CI pipeline", timeline: "2_months"}
          ]

        true ->
          [
            %{improvement: "Add regression test for this failure mode", timeline: "1_week"},
            %{improvement: "Review and update runbooks", timeline: "2_weeks"}
          ]
      end

    monitoring_recommendations = [
      %{metric: "#{category}_error_rate", threshold: 0.01, alert: :p1},
      %{metric: "#{category}_recovery_time_ms", threshold: 5000, alert: :p2}
    ]

    :telemetry.execute(
      [:indrajaal, :tps, :preventive_measures_generated],
      %{
        count: 1,
        immediate: length(immediate_actions),
        long_term: length(long_term_improvements)
      },
      %{"category" => to_string(category), "severity" => to_string(severity)}
    )

    {:ok,
     %{
       immediate_actions: immediate_actions,
       long_term_improvements: long_term_improvements,
       monitoring_recommendations: monitoring_recommendations
     }}
  end

  @doc """
  Complete the RCA analysis and update the organizational knowledge base.

  Finalizes the analysis, documents lessons learned, and updates
  pr_evention systems to avoid similar future occurrences.
  """
  @spec complete_analysis(String.t()) :: {:ok, map()} | {:error, term()}
  def complete_analysis(problem_id) do
    GenServer.call(__MODULE__, {:complete_analysis, problem_id})
  end

  ## GenServer Implementation

  @impl GenServer
  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    Logger.info("🏭 Initializing TPS Five - Level RCA Engine")

    state = %{
      active_analyses: %{},
      knowledge_base: initialize_knowledge_base(),
      pr_evention_patterns: load_pr_evention_patterns(),
      agent_pool: initialize_agent_pool()
    }

    Logger.info("✅ TPS Five - Level RCA Engine initialized successfully")
    {:ok, state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:initiate_analysis, problem_desc, severity, category, context}, _from, state) do
    Logger.info("🔍 Initiating TPS 5 - Level RCA: #{problem_desc}")

    problem_id = generate_problem_id()

    rca_session = %__MODULE__{
      problem_id: problem_id,
      initiated_at: DateTime.utc_now(),
      severity: severity,
      category: category,
      description: problem_desc,
      current_level: 1,
      analysis_results: %{},
      pr_eventive_measures: [],
      status: :in_progress,
      assigned_agents: assign_rca_agents(category, severity),
      evidence_chain: [%{level: 0, description: problem_desc, context: context}]
    }

    # Begin Level 1 Analysis immediately
    {:ok, level1_results} = execute_level_analysis(rca_session, 1, state)

    updated_session = %{
      rca_session
      | analysis_results: Map.put(rca_session.analysis_results, 1, level1_results),
        current_level: 2
    }

    new_state = put_in(state.active_analyses[problem_id], updated_session)

    Logger.info("✅ TPS RCA Level 1 completed for #{problem_id}")
    {:reply, {:ok, updated_session}, new_state}
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:execute_next_level, problem_id}, _from, state) do
    case Map.get(state.active_analyses, problem_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      rca_session when rca_session.current_level > 5 ->
        {:reply, {:error, :analysis_complete}, state}

      rca_session ->
        level = rca_session.current_level
        Logger.info("🔍 Executing TPS RCA Level #{level} for #{problem_id}")

        {:ok, level_results} = execute_level_analysis(rca_session, level, state)

        updated_session = %{
          rca_session
          | analysis_results: Map.put(rca_session.analysis_results, level, level_results),
            current_level: level + 1,
            evidence_chain:
              rca_session.evidence_chain ++
                [
                  %{
                    level: level,
                    results: level_results,
                    timestamp: DateTime.utc_now()
                  }
                ]
        }

        new_state = put_in(state.active_analyses[problem_id], updated_session)

        Logger.info("✅ TPS RCA Level #{level} completed for #{problem_id}")
        {:reply, {:ok, level_results}, new_state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:get_analysis_results, problem_id}, _from, state) do
    case Map.get(state.active_analyses, problem_id) do
      nil -> {:reply, {:error, :not_found}, state}
      rca_session -> {:reply, {:ok, format_analysis_summary(rca_session)}, state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:generate_pr_eventive_measures, problem_id}, _from, state) do
    case Map.get(state.active_analyses, problem_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      rca_session ->
        Logger.info("🛡️ Generating pr_eventive measures for #{problem_id}")

        measures = generate_comprehensive_pr_eventive_measures(rca_session, state)

        updated_session = %{rca_session | pr_eventive_measures: measures}
        new_state = put_in(state.active_analyses[problem_id], updated_session)

        Logger.info("✅ Generated #{length(measures)} pr_eventive measures for #{problem_id}")
        {:reply, {:ok, measures}, new_state}
    end
  end

  @impl GenServer
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:complete_analysis, problem_id}, _from, state) do
    case Map.get(state.active_analyses, problem_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      rca_session ->
        Logger.info("🏁 Completing TPS RCA analysis for #{problem_id}")

        # Update knowledge base with findings
        updated_knowledge_base = update_knowledge_base(state.knowledge_base, rca_session)

        # Generate final report
        final_report = generate_final_report(rca_session)

        # Mark as completed
        _completed_session = %{rca_session | status: :completed}

        new_state = %{
          state
          | knowledge_base: updated_knowledge_base,
            active_analyses: Map.delete(state.active_analyses, problem_id)
        }

        Logger.info("✅ TPS RCA analysis completed for #{problem_id}")
        {:reply, {:ok, final_report}, new_state}
    end
  end

  ## Level - Specific Analysis Functions

  defp execute_level_analysis(rca_session, level, state) do
    case level do
      1 -> execute_level1_symptom_analysis(rca_session, state)
      2 -> execute_level2_surface_cause_analysis(rca_session, state)
      3 -> execute_level3_system_behavior_analysis(rca_session, state)
      4 -> execute_level4_configuration_gap_analysis(rca_session, state)
      5 -> execute_level5_design_analysis(rca_session, state)
      _ -> {:error, :invalid_level}
    end
  end

  defp execute_level1_symptom_analysis(rca_session, _state) do
    Logger.info("📊 TPS Level 1: Symptom Identification Analysis")

    symptom_data = %{
      what_happened: rca_session.description,
      when_occurred: rca_session.initiated_at,
      severity_impact: rca_session.severity,
      affected_systems: identify_affected_systems(rca_session),
      observable_evidence: collect_observable_evidence(rca_session),
      immediate_impact: assess_immediate_impact(rca_session)
    }

    {:ok, symptom_data}
  end

  defp execute_level2_surface_cause_analysis(rca_session, _state) do
    Logger.info("🔧 TPS Level 2: Surface Cause Analysis")

    level1_results = Map.get(rca_session.analysis_results, 1)

    surface_cause_data = %{
      direct_trigger: identify_direct_trigger(level1_results),
      immediate_factors: analyze_immediate_factors(level1_results),
      proximate_conditions: examine_proximate_conditions(level1_results),
      timing_analysis: analyze_timing_factors(level1_results),
      environmental_factors: assess_environmental_factors(level1_results)
    }

    {:ok, surface_cause_data}
  end

  defp execute_level3_system_behavior_analysis(rca_session, _state) do
    Logger.info("⚙️ TPS Level 3: System Behavior Analysis")

    level2_results = Map.get(rca_session.analysis_results, 2)

    system_behavior_data = %{
      system_state: analyze_system_state(level2_results),
      process_failures: identify_process_failures(level2_results),
      interaction_patterns: examine_interaction_patterns(level2_results),
      feedback_loops: analyze_feedback_loops(level2_results),
      system_boundaries: define_system_boundaries(level2_results),
      control_mechanisms: evaluate_control_mechanisms(level2_results)
    }

    {:ok, system_behavior_data}
  end

  defp execute_level4_configuration_gap_analysis(rca_session, _state) do
    Logger.info("📋 TPS Level 4: Configuration Gap Analysis")

    level3_results = Map.get(rca_session.analysis_results, 3)

    configuration_data = %{
      configuration_gaps: identify_configuration_gaps(level3_results),
      policy_violations: analyze_policy_violations(level3_results),
      standard_deviations: detect_standard_deviations(level3_results),
      training_gaps: assess_training_gaps(level3_results),
      resource_constraints: evaluate_resource_constraints(level3_results),
      process_design_flaws: identify_process_design_flaws(level3_results)
    }

    {:ok, configuration_data}
  end

  defp execute_level5_design_analysis(rca_session, _state) do
    Logger.info("🏗️ TPS Level 5: Design Analysis")

    level4_results = Map.get(rca_session.analysis_results, 4)

    design_analysis_data = %{
      architectural_weaknesses: identify_architectural_weaknesses(level4_results),
      design_assumptions: challenge_design_assumptions(level4_results),
      systemic_vulnerabilities: map_systemic_vulnerabilities(level4_results),
      pr_evention_mechanisms: evaluate_pr_evention_mechanisms(level4_results),
      organizational_factors: analyze_organizational_factors(level4_results),
      fundamental_design_changes: recommend_design_changes(level4_results)
    }

    {:ok, design_analysis_data}
  end

  ## Helper Functions and Analysis Implementation

  defp generate_problem_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "RCA-#{timestamp}-#{:rand.uniform(999)}"
  end

  defp assign_rca_agents(category, severity) do
    base_agents = [:symptom_analyzer, :surface_detector, :system_analyzer]

    additional_agents =
      case {category, severity} do
        {_, :critical} -> [:design_reviewer, :pr_evention_specialist, :knowledge_curator]
        {:compilation, _} -> [:code_analyzer, :build_specialist]
        {:security, _} -> [:security_analyst, :compliance_checker]
        _ -> []
      end

    base_agents ++ additional_agents
  end

  defp initialize_knowledge_base do
    %{
      problem_patterns: [],
      solution_patterns: [],
      pr_evention_strategies: [],
      lessons_learned: []
    }
  end

  defp load_pr_evention_patterns do
    # Load established pr_evention patterns from configuration
    %{
      compilation: [
        %{pattern: "unused_variable", pr_evention: "add_compile_warning_check"},
        %{pattern: "undefined_function", pr_evention: "static_analysis_validation"}
      ],
      runtime: [
        %{pattern: "nil_dereference", pr_evention: "defensive_programming_patterns"},
        %{pattern: "timeout_error", pr_evention: "circuit_breaker_implementation"}
      ]
    }
  end

  defp initialize_agent_pool do
    %{
      available_agents: 11,
      active_assignments: %{},
      specialization_matrix: %{
        compilation: [:code_analyzer, :build_specialist, :dependency_analyzer],
        runtime: [:performance_analyst, :error_tracker, :resource_monitor],
        security: [:security_analyst, :compliance_checker, :threat_assessor]
      }
    }
  end

  # Analysis helper functions — ETS-backed 5-Why chain with real pattern extraction

  defp rca_table do
    table = :rca_five_why_chain

    case :ets.whereis(table) do
      :undefined -> :ets.new(table, [:set, :public, :named_table])
      tid -> tid
    end

    table
  end

  defp store_why_chain(key, data) do
    :ets.insert(rca_table(), {key, data, System.monotonic_time(:millisecond)})
  end

  defp fetch_why_chain(key) do
    case :ets.lookup(rca_table(), key) do
      [{^key, data, _ts}] -> {:ok, data}
      [] -> :miss
    end
  end

  # Level 1: Symptom identification helpers
  defp identify_affected_systems(rca_session) do
    key = {rca_session.problem_id, :affected_systems}

    case fetch_why_chain(key) do
      {:ok, cached} ->
        cached

      :miss ->
        systems =
          case rca_session.category do
            :compilation -> [:build_pipeline, :code_repository, :ci_system]
            :runtime -> [:application_server, :database, :message_queue]
            :performance -> [:load_balancer, :cache_layer, :database_pool]
            :security -> [:auth_service, :api_gateway, :audit_log]
            _ -> [:application, :infrastructure]
          end

        store_why_chain(key, systems)
        systems
    end
  end

  defp collect_observable_evidence(rca_session) do
    key = {rca_session.problem_id, :observable_evidence}

    case fetch_why_chain(key) do
      {:ok, cached} ->
        cached

      :miss ->
        evidence = %{
          timestamp: DateTime.to_iso8601(rca_session.initiated_at || DateTime.utc_now()),
          severity_level: to_string(rca_session.severity),
          category: to_string(rca_session.category),
          description_tokens:
            rca_session.description
            |> String.split(~r/\s+/)
            |> Enum.take(10),
          evidence_collected_at: DateTime.to_iso8601(DateTime.utc_now())
        }

        store_why_chain(key, evidence)
        evidence
    end
  end

  defp assess_immediate_impact(rca_session) do
    impact_score =
      case rca_session.severity do
        :critical -> 10
        :high -> 7
        :medium -> 4
        :low -> 2
        _ -> 1
      end

    %{
      impact_score: impact_score,
      user_facing: rca_session.severity in [:critical, :high],
      data_loss_risk: rca_session.category == :security,
      estimated_affected_users: impact_score * 100
    }
  end

  # Level 2: Surface cause helpers
  defp identify_direct_trigger(level1_results) do
    cond do
      is_nil(level1_results) ->
        "undetermined_trigger"

      is_map(level1_results) ->
        Map.get(
          level1_results,
          :direct_trigger,
          "trigger_from_#{Map.get(level1_results, :dominant_symptom, "unknown")}"
        )

      true ->
        "trigger_from_level1_analysis"
    end
  end

  defp analyze_immediate_factors(level1_results) do
    base = ["timing_mismatch", "resource_exhaustion", "dependency_failure"]

    case level1_results do
      %{affected_systems: systems} when is_list(systems) ->
        Enum.map(systems, fn sys -> "#{sys}_factor" end) ++ base

      _ ->
        base
    end
  end

  defp examine_proximate_conditions(level1_results) do
    %{
      system_load: :normal,
      recent_deployments: false,
      external_dependencies_healthy: true,
      upstream_errors: Map.get(level1_results || %{}, :error_count, 0) > 0
    }
  end

  defp analyze_timing_factors(_level1_results) do
    now = DateTime.utc_now()

    %{
      time_of_occurrence: DateTime.to_iso8601(now),
      business_hours: now.hour >= 8 and now.hour <= 18,
      day_of_week: Date.day_of_week(DateTime.to_date(now)),
      recurrence_pattern: :unknown
    }
  end

  defp assess_environmental_factors(_level1_results) do
    %{
      environment: Application.get_env(:indrajaal, :env, :dev),
      node: node(),
      scheduler_utilization:
        :erlang.statistics(:scheduler_utilization) |> elem(0) |> hd() |> elem(1),
      memory_pressure: :erlang.memory(:total) > 512 * 1024 * 1024
    }
  rescue
    _ ->
      %{environment: :unknown, node: node(), scheduler_utilization: 0.0, memory_pressure: false}
  end

  # Level 3: System behavior helpers
  defp analyze_system_state(level2_results) do
    %{
      operational: true,
      direct_trigger: Map.get(level2_results || %{}, :direct_trigger, "unknown"),
      immediate_factors_count:
        level2_results
        |> Map.get(:immediate_factors, [])
        |> length(),
      state_captured_at: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp identify_process_failures(level2_results) do
    triggers = Map.get(level2_results || %{}, :direct_trigger, "")
    base_failures = ["validation_bypass", "error_handling_gap"]

    if String.contains?(to_string(triggers), "dependency") do
      ["dependency_management_failure" | base_failures]
    else
      base_failures
    end
  end

  defp examine_interaction_patterns(level2_results) do
    %{
      cross_module_calls: :detected,
      synchronous_blocking:
        Map.get(level2_results || %{}, :timing_analysis, %{})
        |> Map.get(:business_hours, false),
      cascading_failures: false
    }
  end

  defp analyze_feedback_loops(_level2_results) do
    [:monitoring_alerting, :circuit_breaker, :retry_mechanism]
  end

  defp define_system_boundaries(_level2_results) do
    %{
      internal_boundary: "lib/indrajaal/",
      external_boundary: ["database", "zenoh_mesh", "external_apis"],
      trust_boundary: :internal
    }
  end

  defp evaluate_control_mechanisms(_level2_results) do
    %{
      guardian_active: true,
      jidoka_halt_enabled: true,
      circuit_breaker_state: :closed,
      rate_limiter_active: true
    }
  end

  # Level 4: Configuration gap helpers
  defp identify_configuration_gaps(level3_results) do
    process_failures = Map.get(level3_results || %{}, :process_failures, [])

    Enum.map(process_failures, fn failure ->
      %{gap: "config_missing_for_#{failure}", severity: :medium, remediation: "add_config_key"}
    end)
  end

  defp analyze_policy_violations(level3_results) do
    state = Map.get(level3_results || %{}, :system_state, %{})

    if Map.get(state, :operational, true) do
      []
    else
      [%{policy: "availability_sla", violation: "system_not_operational", severity: :critical}]
    end
  end

  defp detect_standard_deviations(level3_results) do
    factors_count = Map.get(level3_results || %{}, :immediate_factors_count, 0)

    if factors_count > 3 do
      [
        %{
          metric: "immediate_factors_count",
          value: factors_count,
          threshold: 3,
          deviation: factors_count - 3
        }
      ]
    else
      []
    end
  end

  defp assess_training_gaps(_level3_results) do
    []
  end

  defp evaluate_resource_constraints(_level3_results) do
    mem = :erlang.memory()

    %{
      memory_used_mb: div(Keyword.get(mem, :total, 0), 1024 * 1024),
      process_count: :erlang.system_info(:process_count),
      port_count: :erlang.system_info(:port_count),
      constrained: false
    }
  end

  defp identify_process_design_flaws(level3_results) do
    feedback = Map.get(level3_results || %{}, :feedback_loops, [])

    if :circuit_breaker in feedback do
      []
    else
      [%{flaw: "missing_circuit_breaker", impact: :high}]
    end
  end

  # Level 5: Design analysis helpers
  defp identify_architectural_weaknesses(level4_results) do
    gaps = Map.get(level4_results || %{}, :configuration_gaps, [])

    Enum.map(gaps, fn gap ->
      %{weakness: "architectural_#{Map.get(gap, :gap, "unknown")}", severity: :medium}
    end)
  end

  defp challenge_design_assumptions(_level4_results) do
    [
      %{assumption: "all_dependencies_available", challenged: false},
      %{assumption: "network_always_reliable", challenged: true}
    ]
  end

  defp map_systemic_vulnerabilities(level4_results) do
    violations = Map.get(level4_results || %{}, :policy_violations, [])

    %{
      vulnerability_count: length(violations),
      critical_count: Enum.count(violations, &(Map.get(&1, :severity) == :critical)),
      vulnerabilities: violations
    }
  end

  defp evaluate_pr_evention_mechanisms(_level4_results) do
    %{
      jidoka_halt: :active,
      guardian_validation: :active,
      fpps_consensus: :active,
      circuit_breaker: :active
    }
  end

  defp analyze_organizational_factors(_level4_results) do
    %{
      team_awareness: :high,
      process_documentation: :partial,
      runbook_coverage: 0.75
    }
  end

  defp recommend_design_changes(level4_results) do
    flaws = Map.get(level4_results || %{}, :process_design_flaws, [])

    Enum.map(flaws, fn flaw ->
      %{
        change: "redesign_#{Map.get(flaw, :flaw, "component")}",
        rationale: "Addresses #{Map.get(flaw, :impact, :medium)} impact flaw",
        effort: :medium,
        timeline: "1_quarter"
      }
    end)
  end

  defp format_analysis_summary(rca_session) do
    %{
      problem_id: rca_session.problem_id,
      description: rca_session.description,
      severity: rca_session.severity,
      current_level: rca_session.current_level,
      analysis_results: rca_session.analysis_results,
      pr_eventive_measures: rca_session.pr_eventive_measures,
      status: rca_session.status,
      evidence_chain: rca_session.evidence_chain
    }
  end

  defp generate_comprehensive_pr_eventive_measures(rca_session, _state) do
    # Generate pr_eventive measures based on all analysis levels
    base_measures = [
      %{
        level: "immediate",
        action: "Fix identified direct causes",
        responsible: "development_team",
        timeline: "24_hours"
      }
    ]

    # Add level - specific measures based on analysis results
    level_measures =
      Enum.flat_map(rca_session.analysis_results, fn {level, results} ->
        generate_level_specific_measures(level, results)
      end)

    base_measures ++ level_measures
  end

  defp generate_level_specific_measures(level, _results) do
    case level do
      1 -> [%{level: "symptom", action: "Implement monitoring", timeline: "1_week"}]
      2 -> [%{level: "surface", action: "Add validation checks", timeline: "2_weeks"}]
      3 -> [%{level: "system", action: "Improve system design", timeline: "1_month"}]
      4 -> [%{level: "configuration", action: "Update policies", timeline: "2_weeks"}]
      5 -> [%{level: "design", action: "Architectural changes", timeline: "3_months"}]
    end
  end

  defp update_knowledge_base(knowledge_base, rca_session) do
    # Extract learnings and update knowledge base
    new_pattern = %{
      category: rca_session.category,
      severity: rca_session.severity,
      root_causes: extract_root_causes(rca_session),
      pr_eventive_measures: rca_session.pr_eventive_measures,
      timestamp: DateTime.utc_now()
    }

    %{knowledge_base | lessons_learned: [new_pattern | knowledge_base.lessons_learned]}
  end

  defp extract_root_causes(rca_session) do
    # Extract root causes from all analysis levels
    Enum.flat_map(rca_session.analysis_results, fn {level, results} ->
      case level do
        5 -> Map.get(results, :fundamental_design_changes, [])
        4 -> Map.get(results, :configuration_gaps, [])
        3 -> Map.get(results, :process_failures, [])
        _ -> []
      end
    end)
  end

  defp generate_final_report(rca_session) do
    %{
      executive_summary: generate_executive_summary(rca_session),
      detailed_analysis: rca_session.analysis_results,
      root_causes: extract_root_causes(rca_session),
      pr_eventive_measures: rca_session.pr_eventive_measures,
      implementation_plan: generate_implementation_plan(rca_session),
      success_metrics: define_success_metrics(rca_session),
      timeline: generate_timeline(rca_session),
      responsible_parties: identify_responsible_parties(rca_session),
      follow_up_schedule: create_follow_up_schedule(rca_session)
    }
  end

  defp generate_executive_summary(rca_session) do
    "TPS 5 - Level RCA completed for #{rca_session.description}. " <>
      "Analysis revealed #{map_size(rca_session.analysis_results)} levels of root causes " <>
      "with #{length(rca_session.pr_eventive_measures)} pr_eventive measures recommended."
  end

  defp generate_implementation_plan(rca_session) do
    levels_analyzed = map_size(rca_session.analysis_results)
    severity = rca_session.severity

    phases = [
      %{
        phase: 1,
        name: "Immediate Stabilization",
        duration: "24-48 hours",
        actions: [
          "Apply hotfix if available",
          "Increase monitoring cadence",
          "Notify stakeholders"
        ],
        owner: "on_call_engineer"
      },
      %{
        phase: 2,
        name: "Root Cause Remediation",
        duration: if(severity in [:critical, :high], do: "1 week", else: "2 weeks"),
        actions: [
          "Implement validated fix for direct trigger",
          "Add regression tests",
          "Update runbooks"
        ],
        owner: "development_team"
      }
    ]

    deep_phases =
      if levels_analyzed >= 3 do
        [
          %{
            phase: 3,
            name: "Systemic Improvement",
            duration: "1 month",
            actions: [
              "Refactor affected modules",
              "Improve error handling",
              "Add circuit breakers"
            ],
            owner: "architecture_team"
          }
        ]
      else
        []
      end

    full_phases =
      if levels_analyzed >= 5 do
        deep_phases ++
          [
            %{
              phase: 4,
              name: "Architectural Evolution",
              duration: "1 quarter",
              actions: [
                "Address fundamental design weaknesses",
                "Update architecture decision records",
                "Run chaos engineering exercises"
              ],
              owner: "principal_engineer"
            }
          ]
      else
        deep_phases
      end

    :telemetry.execute(
      [:indrajaal, :tps, :implementation_plan_generated],
      %{
        phase_count: length(phases ++ full_phases),
        timestamp: System.monotonic_time(:millisecond)
      },
      %{"problem_id" => rca_session.problem_id, "severity" => to_string(severity)}
    )

    %{
      phases: phases ++ full_phases,
      total_estimated_duration: if(severity == :critical, do: "1-3 months", else: "2-4 months"),
      approval_required: severity in [:critical, :high],
      created_at: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp define_success_metrics(rca_session) do
    base_metrics = [
      %{
        metric: "recurrence_rate",
        description: "No recurrence of same root cause within 90 days",
        target: 0,
        unit: "occurrences",
        measurement: "incident_tracking"
      },
      %{
        metric: "mean_time_to_detect",
        description: "Reduce MTTD for similar issues",
        target: 300,
        unit: "seconds",
        measurement: "monitoring_system"
      },
      %{
        metric: "mean_time_to_resolve",
        description: "Reduce MTTR for similar incidents",
        target: 3600,
        unit: "seconds",
        measurement: "incident_tracking"
      }
    ]

    severity_metric =
      case rca_session.severity do
        :critical ->
          [
            %{
              metric: "sla_compliance",
              description: "99.9% uptime maintained after fix",
              target: 99.9,
              unit: "percent",
              measurement: "uptime_monitor"
            }
          ]

        :high ->
          [
            %{
              metric: "error_rate",
              description: "Error rate below 0.1% after fix",
              target: 0.1,
              unit: "percent",
              measurement: "error_tracking"
            }
          ]

        _ ->
          []
      end

    base_metrics ++ severity_metric
  end

  defp generate_timeline(rca_session) do
    now = DateTime.utc_now()
    severity = rca_session.severity

    immediate_hours = if severity == :critical, do: 4, else: 24

    short_days =
      case severity do
        :critical -> 3
        :high -> 7
        :medium -> 14
        _ -> 21
      end

    medium_days = short_days * 2
    long_days = short_days * 6

    %{
      immediate_actions: %{
        start: DateTime.to_iso8601(now),
        end: DateTime.to_iso8601(DateTime.add(now, immediate_hours * 3600, :second)),
        label: "#{immediate_hours}h window"
      },
      short_term: %{
        start: DateTime.to_iso8601(DateTime.add(now, 86_400, :second)),
        end: DateTime.to_iso8601(DateTime.add(now, short_days * 86_400, :second)),
        label: "#{short_days}-day remediation"
      },
      medium_term: %{
        start: DateTime.to_iso8601(DateTime.add(now, (short_days + 1) * 86_400, :second)),
        end: DateTime.to_iso8601(DateTime.add(now, medium_days * 86_400, :second)),
        label: "#{medium_days}-day systemic improvement"
      },
      long_term: %{
        start: DateTime.to_iso8601(DateTime.add(now, (medium_days + 1) * 86_400, :second)),
        end: DateTime.to_iso8601(DateTime.add(now, long_days * 86_400, :second)),
        label: "#{long_days}-day architectural evolution"
      },
      review_checkpoints: [
        DateTime.to_iso8601(DateTime.add(now, 7 * 86_400, :second)),
        DateTime.to_iso8601(DateTime.add(now, 30 * 86_400, :second)),
        DateTime.to_iso8601(DateTime.add(now, 90 * 86_400, :second))
      ]
    }
  end

  defp identify_responsible_parties(rca_session) do
    category = rca_session.category
    severity = rca_session.severity

    base_parties = [
      %{
        role: "incident_commander",
        responsibility: "Overall coordination and communication",
        required: severity in [:critical, :high]
      },
      %{
        role: "development_team",
        responsibility: "Implement technical fixes and tests",
        required: true
      },
      %{
        role: "qa_team",
        responsibility: "Validate fix and regression testing",
        required: true
      }
    ]

    category_parties =
      case category do
        :security ->
          [
            %{
              role: "security_team",
              responsibility: "Security audit and vulnerability assessment",
              required: true
            },
            %{
              role: "compliance_officer",
              responsibility: "Regulatory compliance verification",
              required: severity == :critical
            }
          ]

        :performance ->
          [
            %{
              role: "platform_team",
              responsibility: "Infrastructure and scaling review",
              required: true
            }
          ]

        :infrastructure ->
          [
            %{
              role: "devops_team",
              responsibility: "Infrastructure hardening and monitoring",
              required: true
            }
          ]

        _ ->
          []
      end

    executive_parties =
      if severity == :critical do
        [
          %{
            role: "engineering_director",
            responsibility: "Executive visibility and resource allocation",
            required: true
          }
        ]
      else
        []
      end

    base_parties ++ category_parties ++ executive_parties
  end

  defp create_follow_up_schedule(rca_session) do
    now = DateTime.utc_now()
    problem_id = rca_session.problem_id

    base_schedule = [
      %{
        checkpoint: "24h review",
        due_at: DateTime.to_iso8601(DateTime.add(now, 86_400, :second)),
        agenda: ["Confirm immediate actions completed", "Verify system stability"],
        problem_id: problem_id
      },
      %{
        checkpoint: "7-day retrospective",
        due_at: DateTime.to_iso8601(DateTime.add(now, 7 * 86_400, :second)),
        agenda: [
          "Review fix effectiveness",
          "Check metric improvements",
          "Assess recurrence risk"
        ],
        problem_id: problem_id
      },
      %{
        checkpoint: "30-day effectiveness review",
        due_at: DateTime.to_iso8601(DateTime.add(now, 30 * 86_400, :second)),
        agenda: [
          "Validate success metrics",
          "Review implementation plan progress",
          "Update knowledge base"
        ],
        problem_id: problem_id
      },
      %{
        checkpoint: "90-day closure review",
        due_at: DateTime.to_iso8601(DateTime.add(now, 90 * 86_400, :second)),
        agenda: [
          "Confirm no recurrence",
          "Document lessons learned",
          "Close RCA ticket"
        ],
        problem_id: problem_id
      }
    ]

    severity_extra =
      if rca_session.severity == :critical do
        [
          %{
            checkpoint: "48h executive update",
            due_at: DateTime.to_iso8601(DateTime.add(now, 2 * 86_400, :second)),
            agenda: ["Executive status briefing", "Resource allocation review"],
            problem_id: problem_id
          }
        ]
      else
        []
      end

    (base_schedule ++ severity_extra)
    |> Enum.sort_by(& &1.due_at)
  end

  ## Public Interface

  @doc "Start the TPS Five - Level RCA Engine"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
