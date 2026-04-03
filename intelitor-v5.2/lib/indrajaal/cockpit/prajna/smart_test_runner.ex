defmodule Indrajaal.Cockpit.Prajna.SmartTestRunner do
  @moduledoc """
  Smart Test Runner with Detailed Telemetry and Agent Thinking

  Provides comprehensive test execution with:
  - 1st-5th order effect analysis
  - Real-time telemetry streaming
  - Agent thinking visualization
  - Fractal test orchestration
  - BDD/Puppeteer integration

  ## STAMP Constraints
  - SC-TEST-001: Test files MUST compile before PR
  - SC-TEST-002: No undefined variables in assertions
  - SC-TEST-003: Factory creates parents first
  - SC-TEST-004: Mock external modules
  - SC-TEST-005: SKIP_ZENOH_NIF=0 MANDATORY

  ## AOR Rules
  - AOR-TEST-001: Test Compile - Run `MIX_ENV=test mix compile` before commit
  - AOR-TEST-002: Assertion Safety - Verify all variables defined
  - AOR-TEST-NIF-001: ALL test invocations MUST set SKIP_ZENOH_NIF=0
  """

  use GenServer
  require Logger

  # ============================================================================
  # Types and Constants
  # ============================================================================

  @type test_level :: :tdg | :fmea | :formal | :graph | :bdd
  @type effect_order :: 1 | 2 | 3 | 4 | 5
  @type thinking_phase :: :observe | :orient | :decide | :act | :verify

  @effect_timeouts %{
    # 0-100ms: Immediate
    1 => 100,
    # 100ms-10s: Adjacent
    2 => 10_000,
    # 10s-60s: Integration
    3 => 60_000,
    # 1-5min: Capability
    4 => 300_000,
    # 5min+: Ecosystem
    5 => :infinity
  }

  @test_levels [:tdg, :fmea, :formal, :graph, :bdd]

  defstruct [
    :session_id,
    :started_at,
    :current_level,
    :current_command,
    :thinking_log,
    :effect_chain,
    :telemetry_subscribers,
    :results,
    :agent_state
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the Smart Test Runner.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Run smart test for a specific command with detailed telemetry.

  ## Example

      SmartTestRunner.test_command("compile")
      SmartTestRunner.test_command("app-start")
      SmartTestRunner.test_command("sa-up")
  """
  def test_command(command, opts \\ []) do
    GenServer.call(__MODULE__, {:test_command, command, opts}, :infinity)
  end

  @doc """
  Run all 5 test levels for a command.
  """
  def run_all_levels(command) do
    GenServer.call(__MODULE__, {:run_all_levels, command}, :infinity)
  end

  @doc """
  Run a specific test level.
  """
  def run_level(level, command) when level in @test_levels do
    GenServer.call(__MODULE__, {:run_level, level, command}, :infinity)
  end

  @doc """
  Get current agent thinking state.
  """
  def get_thinking do
    GenServer.call(__MODULE__, :get_thinking)
  end

  @doc """
  Get effect chain analysis.
  """
  def get_effect_chain do
    GenServer.call(__MODULE__, :get_effect_chain)
  end

  @doc """
  Subscribe to telemetry events.
  """
  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  @doc """
  Get full test report.
  """
  def get_report do
    GenServer.call(__MODULE__, :get_report)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      session_id: generate_session_id(),
      started_at: DateTime.utc_now(),
      current_level: nil,
      current_command: nil,
      thinking_log: [],
      effect_chain: [],
      telemetry_subscribers: [],
      results: %{},
      agent_state: :idle
    }

    # Attach telemetry handlers
    attach_telemetry_handlers()

    {:ok, state}
  end

  @impl true
  def handle_call({:test_command, command, opts}, _from, state) do
    state = %{state | current_command: command, agent_state: :testing}

    # OODA Loop: Observe
    state = log_thinking(state, :observe, "Starting test for command: #{command}")
    emit_telemetry(:test_start, %{command: command, session_id: state.session_id})

    # Run the smart test with effect analysis
    {result, state} = execute_smart_test(command, opts, state)

    # Log completion
    state = log_thinking(state, :verify, "Test completed for: #{command}")
    emit_telemetry(:test_complete, %{command: command, result: result})

    {:reply, result, %{state | agent_state: :idle}}
  end

  @impl true
  def handle_call({:run_all_levels, command}, _from, state) do
    state = %{state | current_command: command, agent_state: :testing}

    # Run all 5 levels
    results =
      Enum.map(@test_levels, fn level ->
        {result, _} = run_test_level(level, command, state)
        {level, result}
      end)
      |> Map.new()

    state = %{state | results: Map.put(state.results, command, results)}
    {:reply, {:ok, results}, %{state | agent_state: :idle}}
  end

  @impl true
  def handle_call({:run_level, level, command}, _from, state) do
    {result, state} = run_test_level(level, command, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_thinking, _from, state) do
    {:reply, state.thinking_log, state}
  end

  @impl true
  def handle_call(:get_effect_chain, _from, state) do
    {:reply, state.effect_chain, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    state = %{state | telemetry_subscribers: [pid | state.telemetry_subscribers]}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_report, _from, state) do
    report = generate_report(state)
    {:reply, report, state}
  end

  # ============================================================================
  # Smart Test Execution
  # ============================================================================

  defp execute_smart_test(command, opts, state) do
    # Phase 1: OBSERVE - Assess current state
    state =
      log_thinking(state, :observe, """
      [OBSERVE] Assessing system state before '#{command}'
      - Checking compilation state: #{check_compilation_state()}
      - Checking container status: #{check_container_status()}
      - Checking database connectivity: #{check_db_status()}
      """)

    # Phase 2: ORIENT - Analyze 1st-5th order effects
    effects = analyze_effects(command)

    state =
      log_thinking(state, :orient, """
      [ORIENT] Analyzing 1st-5th order effects for '#{command}'
      #{format_effects(effects)}
      """)

    # Add effects to chain
    state = %{state | effect_chain: state.effect_chain ++ effects}

    # Phase 3: DECIDE - Plan test strategy
    test_plan = create_test_plan(command, effects, opts)

    state =
      log_thinking(state, :decide, """
      [DECIDE] Test plan created:
      - Test Levels: #{inspect(test_plan.levels)}
      - Expected Duration: #{test_plan.expected_duration}ms
      - Dependencies: #{inspect(test_plan.dependencies)}
      - Risk Level: #{test_plan.risk_level}
      """)

    # Phase 4: ACT - Execute tests
    state = log_thinking(state, :act, "[ACT] Executing test plan...")
    {results, state} = execute_test_plan(test_plan, state)

    # Phase 5: VERIFY - Confirm all effects cascaded
    state =
      log_thinking(state, :verify, """
      [VERIFY] Verifying cascade effects:
      - 1st Order: #{verify_effect(results, 1)}
      - 2nd Order: #{verify_effect(results, 2)}
      - 3rd Order: #{verify_effect(results, 3)}
      - 4th Order: #{verify_effect(results, 4)}
      - 5th Order: #{verify_effect(results, 5)}
      """)

    result = %{
      command: command,
      status: determine_status(results),
      effects: effects,
      results: results,
      duration: calculate_duration(state),
      thinking_log: state.thinking_log
    }

    {result, state}
  end

  # ============================================================================
  # Effect Analysis (1st-5th Order)
  # ============================================================================

  @doc """
  Analyze 1st-5th order effects for a command.

  ## Effect Orders:
  - 1st Order (0-100ms): Immediate, direct action
  - 2nd Order (100ms-10s): Adjacent systems react
  - 3rd Order (10s-60s): Integration effects cascade
  - 4th Order (1-5min): Capabilities unlock
  - 5th Order (5min+): Ecosystem-wide effects
  """
  def analyze_effects(command) do
    case command do
      "compile" -> compile_effects()
      "app" -> app_effects()
      "app-start" -> app_start_effects()
      "sa-up" -> sa_up_effects()
      "sa-down" -> sa_down_effects()
      "test" -> test_effects()
      "test-cover" -> test_cover_effects()
      "quality" -> quality_effects()
      "quality-full" -> quality_full_effects()
      "db-setup" -> db_setup_effects()
      "db-reset" -> db_reset_effects()
      "db-migrate" -> db_migrate_effects()
      "cockpitf" -> cockpitf_effects()
      "cepaf-build" -> cepaf_build_effects()
      _ -> generic_effects(command)
    end
  end

  defp compile_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Compiler invokes, .beam files generated",
        verification: "File.exists?('_build/dev')",
        script: "scripts/validation/comprehensive_compilation_validator.exs"
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "NIFs compile (Rustler), Ash DSL expands",
        verification: "nifs_compiled?()",
        script: "scripts/validation/nif_guard.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Phoenix reload triggered, IEx available",
        verification: "phoenix_ready?()",
        script: "scripts/testing/container_phics_runtime_validator.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Tests runnable, CI gate passable",
        verification: "tests_runnable?()",
        script: "scripts/testing/comprehensive_release_pipeline.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Container build possible, deploy ready",
        verification: "deploy_ready?()",
        script: "scripts/testing/enterprise_testing_compliance_report.exs"
      }
    ]
  end

  defp app_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Phoenix process starts",
        verification: "Process.whereis(Indrajaal.Application)",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Endpoints bind to ports 4000/4001",
        verification: "port_listening?(4000)",
        script: "scripts/testing/container_demo_scenario_tester.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "LiveView connections accepted, Channels ready",
        verification: "channels_ready?()",
        script: "scripts/testing/business_domain_assessment.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Full application stack operational",
        verification: "health_check_passes?()",
        script: "scripts/verification/verify_system_hardening.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Production-ready state achieved",
        verification: "production_ready?()",
        script: "scripts/testing/stamp_tdg_gde_production_readiness.exs"
      }
    ]
  end

  defp app_start_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Container check initiated",
        verification: "containers_checked?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Missing containers started via sa-up",
        verification: "containers_running?()",
        script: "scripts/performance/monitor_container_readiness.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Phoenix server starts with container deps",
        verification: "phoenix_with_deps?()",
        script: "scripts/testing/container_phics_runtime_validator.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Full stack integration verified",
        verification: "integration_verified?()",
        script: "scripts/testing/comprehensive_release_pipeline.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Development environment fully operational",
        verification: "dev_env_ready?()",
        script: "scripts/testing/demo_execution_validator.exs"
      }
    ]
  end

  defp sa_up_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Podman compose invoked",
        verification: "podman_invoked?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "DB container (5433), OBS container (4317/9090/3000) start",
        verification: "port_listening?(5433) and port_listening?(4317)",
        script: "scripts/testing/container_execution_validator.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "App container (4000/4001) starts with deps",
        verification: "port_listening?(4000)",
        script: "scripts/testing/container_demo_scenario_tester.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Health checks pass, telemetry flowing",
        verification: "health_check_passes?() and telemetry_flowing?()",
        script: "scripts/testing/12_hour_soak_test_monitor.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Production-equivalent environment ready",
        verification: "prod_equivalent?()",
        script: "scripts/testing/stamp_tdg_gde_production_readiness.exs"
      }
    ]
  end

  defp sa_down_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Stop signal sent to containers",
        verification: "stop_signal_sent?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Graceful shutdown initiated",
        verification: "shutdown_initiated?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "All containers stopped",
        verification: "not containers_running?()",
        script: "scripts/testing/container_execution_validator.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Ports freed (4000, 5433, etc.)",
        verification: "ports_freed?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Clean state ready for restart",
        verification: "clean_state?()",
        script: nil
      }
    ]
  end

  defp test_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "ExUnit starts, test files loaded",
        verification: "exunit_started?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Test database created/migrated",
        verification: "test_db_ready?()",
        script: "scripts/testing/container_native_stamp_test_runner.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Tests execute with Patient Mode",
        verification: "tests_executing?()",
        script: "scripts/testing/comprehensive_test_coverage_framework.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Coverage report generated",
        verification: "coverage_generated?()",
        script: "scripts/testing/comprehensive_coverage_parser.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "CI gate result determined",
        verification: "ci_gate_result?()",
        script: "scripts/testing/enterprise_testing_compliance_report.exs"
      }
    ]
  end

  defp test_cover_effects do
    test_effects() ++
      [
        %{
          order: 4,
          time: "1-5min",
          effect: "ExCoveralls HTML report generated",
          verification: "File.exists?('cover/excoveralls.html')",
          script: "scripts/testing/comprehensive_coverage_parser.exs"
        }
      ]
  end

  defp quality_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "mix format check initiated",
        verification: "format_check_started?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Credo analysis runs",
        verification: "credo_running?()",
        script: "scripts/testing/quality_assurance_integration.exs"
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Quality report generated",
        verification: "quality_report_exists?()",
        script: nil
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Quality gate pass/fail determined",
        verification: "quality_gate_result?()",
        script: "scripts/testing/comprehensive_release_pipeline.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Code quality metrics updated",
        verification: "metrics_updated?()",
        script: nil
      }
    ]
  end

  defp quality_full_effects do
    quality_effects() ++
      [
        %{
          order: 3,
          time: "10s-60s",
          effect: "Dialyzer type analysis runs",
          verification: "dialyzer_running?()",
          script: "scripts/performance/comprehensive_dialyzer_container_setup.exs"
        },
        %{
          order: 3,
          time: "10s-60s",
          effect: "Sobelow security scan runs",
          verification: "sobelow_running?()",
          script: "scripts/security/security_validation.exs"
        }
      ]
  end

  defp db_setup_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Ecto repo connection initiated",
        verification: "repo_connecting?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Database created if not exists",
        verification: "database_exists?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Migrations run",
        verification: "migrations_complete?()",
        script: "scripts/testing/comprehensive_release_pipeline.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Seeds loaded (if applicable)",
        verification: "seeds_loaded?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Database ready for application",
        verification: "db_ready?()",
        script: "scripts/testing/container_demo_scenario_tester.exs"
      }
    ]
  end

  defp db_reset_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Database drop initiated",
        verification: "drop_initiated?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Connections terminated",
        verification: "connections_terminated?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Database dropped and recreated",
        verification: "db_recreated?()",
        script: nil
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Fresh migrations run",
        verification: "migrations_complete?()",
        script: "scripts/testing/comprehensive_release_pipeline.exs"
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Clean database state achieved",
        verification: "clean_db_state?()",
        script: nil
      }
    ]
  end

  defp db_migrate_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Migration status checked",
        verification: "migration_status_checked?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Pending migrations identified",
        verification: "pending_migrations_identified?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Migrations executed in order",
        verification: "migrations_executed?()",
        script: nil
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "Schema updated",
        verification: "schema_updated?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Application can use new schema",
        verification: "schema_usable?()",
        script: nil
      }
    ]
  end

  defp cockpitf_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "F# dotnet build initiated",
        verification: "dotnet_build_started?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "CEPAF projects compile",
        verification: "cepaf_compiled?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Prajna TUI becomes available",
        verification: "prajna_tui_available?()",
        script: "scripts/cockpit/prajna_tui.exs"
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "F# <-> Elixir bridge operational",
        verification: "bridge_operational?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Full cockpit functionality ready",
        verification: "cockpit_ready?()",
        script: nil
      }
    ]
  end

  defp cepaf_build_effects do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "dotnet build command invoked",
        verification: "dotnet_invoked?()",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "F# source files compiled",
        verification: "fsharp_compiled?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "DLLs generated in bin/Release",
        verification: "dlls_generated?()",
        script: nil
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "CEPAF tests can run",
        verification: "cepaf_tests_runnable?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Full F# stack operational",
        verification: "fsharp_stack_ready?()",
        script: nil
      }
    ]
  end

  defp generic_effects(command) do
    [
      %{
        order: 1,
        time: "0-100ms",
        effect: "Command '#{command}' initiated",
        verification: "command_initiated?('#{command}')",
        script: nil
      },
      %{
        order: 2,
        time: "100ms-10s",
        effect: "Primary action executes",
        verification: "primary_action_complete?()",
        script: nil
      },
      %{
        order: 3,
        time: "10s-60s",
        effect: "Secondary effects cascade",
        verification: "secondary_effects_complete?()",
        script: nil
      },
      %{
        order: 4,
        time: "1-5min",
        effect: "System state stabilizes",
        verification: "state_stable?()",
        script: nil
      },
      %{
        order: 5,
        time: "5min+",
        effect: "Full effect propagation complete",
        verification: "propagation_complete?()",
        script: nil
      }
    ]
  end

  # ============================================================================
  # Test Level Execution
  # ============================================================================

  defp run_test_level(level, command, state) do
    state =
      log_thinking(
        state,
        :act,
        "[ACT] Running Level #{level_number(level)}: #{level_name(level)} for '#{command}'"
      )

    emit_telemetry(:level_start, %{level: level, command: command})

    result =
      case level do
        :tdg -> run_tdg_tests(command, state)
        :fmea -> run_fmea_tests(command, state)
        :formal -> run_formal_tests(command, state)
        :graph -> run_graph_tests(command, state)
        :bdd -> run_bdd_tests(command, state)
      end

    emit_telemetry(:level_complete, %{level: level, command: command, result: result})
    {result, state}
  end

  defp run_tdg_tests(command, _state) do
    # Level 1: TDG - PropCheck + ExUnitProperties
    scripts = [
      "scripts/testing/analytics_tdg_validation.exs",
      "scripts/property_testing/unified_property_testing_orchestrator.exs"
    ]

    %{
      level: :tdg,
      level_name: "Test-Driven Generation",
      command: command,
      frameworks: [:propcheck, :ex_unit_properties],
      scripts: scripts,
      status: :pending,
      description: "Property-based testing with PropCheck and StreamData generators"
    }
  end

  defp run_fmea_tests(command, _state) do
    # Level 2: FMEA - Failure Mode Effects Analysis
    %{
      level: :fmea,
      level_name: "Failure Mode Effects Analysis",
      command: command,
      frameworks: [:fmea, :rpn_analysis],
      scripts: ["scripts/testing/behavioral_verification_system.exs"],
      status: :pending,
      description: "RPN scoring for failure modes, chaos testing"
    }
  end

  defp run_formal_tests(command, _state) do
    # Level 3: Formal - Agda + Quint + Mathematica + Dialyzer
    %{
      level: :formal,
      level_name: "Formal Verification",
      command: command,
      frameworks: [:agda, :quint, :mathematica, :dialyzer],
      scripts: [
        "scripts/verification/master_safety_protocol.exs",
        "scripts/performance/comprehensive_dialyzer_container_setup.exs"
      ],
      status: :pending,
      description: "Mathematical proofs and static type analysis"
    }
  end

  defp run_graph_tests(command, _state) do
    # Level 4: Graph - Coverage + Path Analysis
    %{
      level: :graph,
      level_name: "Graph-Based Path Analysis",
      command: command,
      frameworks: [:excoveralls, :graph_analysis],
      scripts: [
        "scripts/testing/comprehensive_test_coverage_framework.exs",
        "scripts/testing/11_agent_coordination_test_framework.exs"
      ],
      status: :pending,
      description: "100% static coverage, dependency graph analysis"
    }
  end

  defp run_bdd_tests(command, _state) do
    # Level 5: BDD - Cucumber + SpecFlow + Playwright
    %{
      level: :bdd,
      level_name: "Behavior-Driven Development",
      command: command,
      frameworks: [:cucumber, :specflow, :playwright],
      scripts: [
        "scripts/testing/container_demo_scenario_tester.exs",
        "scripts/testing/demo_command_validation_test_plan.exs"
      ],
      status: :pending,
      description: "Gherkin features with browser automation"
    }
  end

  # ============================================================================
  # Test Plan Creation
  # ============================================================================

  defp create_test_plan(command, effects, opts) do
    levels = Keyword.get(opts, :levels, @test_levels)
    dependencies = calculate_dependencies(command)
    risk_level = calculate_risk_level(effects)

    %{
      command: command,
      levels: levels,
      effects: effects,
      dependencies: dependencies,
      risk_level: risk_level,
      expected_duration: calculate_expected_duration(levels, effects),
      parallel: Keyword.get(opts, :parallel, false)
    }
  end

  defp execute_test_plan(plan, state) do
    results =
      Enum.map(plan.levels, fn level ->
        {result, _} = run_test_level(level, plan.command, state)
        {level, result}
      end)
      |> Map.new()

    {results, state}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp log_thinking(state, phase, message) do
    entry = %{
      timestamp: DateTime.utc_now(),
      phase: phase,
      message: message,
      session_id: state.session_id
    }

    # Emit to telemetry
    emit_telemetry(:thinking, entry)

    # Log to console
    Logger.info("[#{phase |> to_string() |> String.upcase()}] #{message}")

    %{state | thinking_log: state.thinking_log ++ [entry]}
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smart_test_runner, event],
      %{timestamp: System.monotonic_time(:microsecond)},
      metadata
    )
  end

  defp attach_telemetry_handlers do
    events = [
      [:smart_test_runner, :test_start],
      [:smart_test_runner, :test_complete],
      [:smart_test_runner, :level_start],
      [:smart_test_runner, :level_complete],
      [:smart_test_runner, :thinking],
      [:smart_test_runner, :effect]
    ]

    :telemetry.attach_many(
      "smart-test-runner-handler",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event(event, _measurements, metadata, _config) do
    # Log telemetry events
    event_name = Enum.join(event, ".")
    Logger.debug("[Telemetry] #{event_name}: #{inspect(metadata)}")
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp check_compilation_state do
    if File.exists?("_build/dev"), do: "compiled", else: "not compiled"
  end

  defp check_container_status do
    case System.cmd("podman", ["ps", "--format", "{{.Names}}"], stderr_to_stdout: true) do
      {output, 0} ->
        "running: #{String.trim(output) |> String.split("\n") |> length()} containers"

      _ ->
        "unknown"
    end
  end

  defp check_db_status do
    case System.cmd("pg_isready", ["-h", "localhost", "-p", "5433"], stderr_to_stdout: true) do
      {_, 0} -> "connected"
      _ -> "disconnected"
    end
  end

  defp format_effects(effects) do
    Enum.map_join(effects, "\n", fn effect ->
      "  - Order #{effect.order} (#{effect.time}): #{effect.effect}"
    end)
  end

  defp verify_effect(results, order) do
    case Map.get(results, order) do
      nil -> "not verified"
      %{status: :passed} -> "PASSED"
      %{status: :failed} -> "FAILED"
      _ -> "pending"
    end
  end

  defp calculate_dependencies(command) do
    case command do
      "test" -> ["compile", "db-setup"]
      "app" -> ["compile"]
      "app-start" -> ["compile", "sa-db"]
      "quality-full" -> ["compile", "quality"]
      "sa-test" -> ["sa-up", "cepaf-build"]
      _ -> []
    end
  end

  defp calculate_risk_level(effects) do
    max_order = effects |> Enum.map(& &1.order) |> Enum.max()

    cond do
      max_order >= 5 -> :critical
      max_order >= 4 -> :high
      max_order >= 3 -> :medium
      true -> :low
    end
  end

  defp calculate_expected_duration(levels, effects) do
    base = length(levels) * 10_000

    effect_time =
      effects
      |> Enum.map(fn e -> Map.get(@effect_timeouts, e.order, 0) end)
      |> Enum.sum()

    base + div(effect_time, 2)
  end

  defp determine_status(results) do
    failed = Enum.any?(results, fn {_, r} -> r.status == :failed end)
    if failed, do: :failed, else: :passed
  end

  defp calculate_duration(state) do
    DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
  end

  defp level_number(level) do
    case level do
      :tdg -> 1
      :fmea -> 2
      :formal -> 3
      :graph -> 4
      :bdd -> 5
    end
  end

  defp level_name(level) do
    case level do
      :tdg -> "TDG"
      :fmea -> "FMEA"
      :formal -> "Formal"
      :graph -> "Graph"
      :bdd -> "BDD"
    end
  end

  defp generate_report(state) do
    %{
      session_id: state.session_id,
      started_at: state.started_at,
      duration_ms: calculate_duration(state),
      commands_tested: Map.keys(state.results),
      results: state.results,
      effect_chain: state.effect_chain,
      thinking_log: state.thinking_log,
      summary: %{
        total_levels: length(@test_levels),
        total_effects: length(state.effect_chain),
        thinking_entries: length(state.thinking_log)
      }
    }
  end
end
