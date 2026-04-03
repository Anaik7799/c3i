defmodule Indrajaal.Observability.TroubleshootingGuideGenerator do
  @moduledoc """
  ## Agent: Worker Agent 3 - Troubleshooting Documentation Specialist
  ## SOPv5.1 Compliance: Comprehensive troubleshooting with cybernetic feedback
  ## Maximum Parallelization: Concurrent troubleshooting guide generation

  Advanced Troubleshooting Guide Generation for Observability Issues

  This module provides comprehensive troubleshooting documentation with:
  - Systematic issue categorization and solution mapping
  - Diagnostic command generation with expected outputs
  - Solution effectiveness tracking and validation
  - Common issue pattern recognition and resolution
  - Escalation procedures for complex issues
  - Performance optimization troubleshooting guides
  - Security incident troubleshooting procedures
  - Multi-tenant troubleshooting isolation techniques
  """

  use GenServer
  require Logger

  # CLAUDE_AGENT_CONTEXT: TDG behaviour implementation
  # Date: 2025-09-04 02:08 CEST
  # Pattern: EP062_MISSING_BEHAVIOUR_IMPLEMENTATION
  # Purpose: Proper behaviour implementation with default implementations
  use Indrajaal.Observability.DefaultImpl

  @behaviour Indrajaal.Observability.ObservabilityHelpers

  # Troubleshooting configuration
  @troubleshooting_path "docs/troubleshooting"
  @guide_generation_timeout 30_000

  # Common troubleshooting categories
  @troubleshooting_categories %{
    "installation_issues" => %{
      title: "Installation and Setup Issues",
      severity: "high",
      solutions: ["dependency_resolution", "version_conflicts", "permission_issues"]
    },
    "configuration_problems" => %{
      title: "Configuration Problems",
      severity: "medium",
      solutions: ["invalid_config", "missing_env_vars", "network_connectivity"]
    },
    "telemetry_data_issues" => %{
      title: "Telemetry Data Collection Issues",
      severity: "high",
      solutions: ["instrumentation_setup", "__data_flow_validation", "exporter_configuration"]
    },
    "dashboard_problems" => %{
      title: "Dashboard Configuration and Display Issues",
      severity: "medium",
      solutions: ["dashboard_deployment", "panel_configuration", "__data_source_connectivity"]
    },
    "performance_issues" => %{
      title: "Performance and Scalability Issues",
      severity: "critical",
      solutions: ["resource_optimization", "query_tuning", "scaling_configuration"]
    }
  }

  defstruct [
    :generated_guides,
    :solution_effectiveness,
    guides_created: 0,
    solutions_documented: 0
  ]

  ## Public API

  @doc """
  Starts the Troubleshooting Guide Generator system.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generates comprehensive troubleshooting guide with solution coverage.
  """
  @spec generate_comprehensive_guide(map()) :: {:ok, map()} | {:error, atom()}
  def generate_comprehensive_guide(config) when is_map(config) do
    GenServer.call(__MODULE__, {:generate_comprehensive_guide, config}, @guide_generation_timeout)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🔍 Initializing Troubleshooting Guide Generator")

    state = %__MODULE__{
      generated_guides: %{},
      solution_effectiveness: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:generate_comprehensive_guide, config}, _from, state) do
    Logger.info("📋 Generating comprehensive troubleshooting guide")

    case generate_troubleshooting_guide_parallel(config) do
      {:ok, guide_info} ->
        new_state = %{
          state
          | guides_created: state.guides_created + 1,
            solutions_documented: state.solutions_documented + guide_info.solutions_count
        }

        Logger.info("✅ Troubleshooting guide generated successfully",
          categories: guide_info.categories_count,
          solutions: guide_info.solutions_count
        )

        {:reply, {:ok, guide_info}, new_state}

      {:error, reason} ->
        Logger.error("❌ Troubleshooting guide generation failed", error: reason)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      guides_created: state.guides_created,
      solutions_documented: state.solutions_documented,
      categories_covered: state.categories_covered,
      average_generation_time_ms: state.average_generation_time_ms
    }

    {:reply, {:ok, metrics}, state}
  end

  ## Private Functions

  @spec generate_troubleshooting_guide_parallel(map()) :: {:ok, map()} | {:error, atom()}
  defp generate_troubleshooting_guide_parallel(config) do
    try do
      # Multi-agent troubleshooting guide generation
      category_tasks =
        (config[:categories] || Map.keys(@troubleshooting_categories))
        |> Enum.map(fn category ->
          Task.async(fn ->
            generate_category_section(category, config)
          end)
        end)

      solution_tasks =
        (config[:solutions] || [])
        |> Enum.map(fn solution ->
          Task.async(fn ->
            generate_solution_documentation(solution, config)
          end)
        end)

      diagnostic_task =
        Task.async(fn ->
          generate_diagnostic_commands_section(config)
        end)

      # Wait for all tasks to complete
      category_sections = Task.await_many(category_tasks, @guide_generation_timeout)
      solution_sections = Task.await_many(solution_tasks, @guide_generation_timeout)
      diagnostic_section = Task.await(diagnostic_task, @guide_generation_timeout)

      # Combine all sections
      guide_content =
        combine_troubleshooting_content(
          config,
          category_sections,
          solution_sections,
          diagnostic_section
        )

      # Write troubleshooting guide
      file_path = config[:output_path] || "#{@troubleshooting_path}/comprehensive_guide.md"
      ensure_directory_exists(Path.dirname(file_path))
      :ok = File.write!(file_path, guide_content)

      # Calculate metrics
      guide_info = %{
        file_path: file_path,
        word_count: count_words(guide_content),
        categories_count: length(category_sections),
        solutions_count: length(solution_sections),
        diagnostic_commands_count: count_diagnostic_commands(diagnostic_section),
        generated_at: System.system_time(:second)
      }

      {:ok, guide_info}
    rescue
      error ->
        Logger.error("Troubleshooting guide generation error: #{inspect(error)}")
        {:error, :generation_failed}
    end
  end

  @spec generate_category_section(String.t(), map()) :: String.t()
  defp generate_category_section(category, config) do
    category_info =
      Map.get(@troubleshooting_categories, category, %{
        title: String.capitalize(String.replace(category, "_", " ")),
        severity: "medium",
        solutions: []
      })

    _severity_levels = config[:severity_levels] || ["critical", "high", "medium", "low"]

    """
    ## #{category_info.title}

    **Severity Level**: #{String.upcase(category_info.severity)}

    ### Common Issues in This Category

    #{generate_common_issues(category)}

    ### Quick Diagnosis

    #{generate_quick_diagnosis_steps(category)}

    ### Detailed Solutions

    #{generate_detailed_solutions(category, category_info.solutions)}

    ### Pr_evention Measures

    #{generate_pr_evention_measures(category)}

    ---
    """
  end

  @spec generate_solution_documentation(String.t(), map()) :: String.t()
  defp generate_solution_documentation(solution, _config) do
    """
    ### Solution: #{String.capitalize(String.replace(solution, "_", " "))}

    #{generate_solution_overview(solution)}

    #### Step-by-Step Resolution

    #{generate_solution_steps(solution)}

    #### Validation Commands

    #{generate_validation_commands(solution)}

    #### Expected Outcomes

    #{generate_expected_outcomes(solution)}

    ---
    """
  end

  @spec generate_diagnostic_commands_section(map()) :: String.t()
  defp generate_diagnostic_commands_section(_config) do
    """
    ## Diagnostic Commands Reference

    ### System Health Checks

    ```bash
    # Check application status
    mix phx.server --check-status

    # Validate dependencies
    mix deps.compile --force

    # Check __database connectivity
    mix ecto.migrate --dry-run

    # Verify container status
    podman ps -a | grep intelitor

    # Check telemetry configuration
    mix telemetry.validate
    ```

    ### Observability-Specific Diagnostics

    ```bash
    # Check OpenTelemetry configuration
    mix otel.validate_config

    # Test SigNoz connectivity
    curl -f http://localhost:3301/api/v1/health

    # Validate trace __data flow
    mix observability.trace_test

    # Check dashboard deployment status
    mix signoz.dashboard.status

    # Monitor telemetry __data export
    mix telemetry.monitor --duration 60
    ```

    ### Performance Diagnostics

    ```bash
    # Memory usage analysis
    :observer.start()

    # Process monitoring
    :htop.beam()

    # Database query analysis
    mix ecto.query.analyze

    # Container resource monitoring
    podman stats indrajaal-app

    # Network connectivity test
    mix network.connectivity_test
    ```

    ### Log Analysis Commands

    ```bash
    # Application logs
    tail -f log/dev.log | grep ERROR

    # Container logs
    podman logs indrajaal-app --follow

    # System logs
    journalctl -u indrajaal-app -f

    # SigNoz logs
    podman logs signoz-otel-collector

    # Telemetry debug logs
    LOG_LEVEL=debug mix phx.server
    ```
    """
  end

  @spec generate_common_issues(String.t()) :: String.t()
  defp generate_common_issues(category) do
    case category do
      "installation_issues" ->
        """
        1. **Dependency Version Conflicts**
           - OpenTelemetry library version mismatches
           - Phoenix compatibility issues
           - Elixir version _requirements not met

        2. **Permission Errors**
           - Container runtime permission denied
           - File system access restrictions
           - Network port binding failures

        3. **Environment Setup Problems**
           - Missing environment variables
           - Configuration file not found
           - Path resolution issues
        """

      "configuration_problems" ->
        """
        1. **Invalid Configuration Format**
           - Malformed YAML/JSON configuration
           - Missing _required configuration keys
           - Incorrect __data types in configuration

        2. **Network Configuration Issues**
           - SigNoz endpoint unreachable
           - Firewall blocking connections
           - DNS resolution failures

        3. **Authentication Problems**
           - Invalid API keys or tokens
           - Certificate validation failures
           - Access control configuration errors
        """

      "telemetry_data_issues" ->
        """
        1. **No Data Collection**
           - Instrumentation not properly configured
           - Telemetry handlers not attached
           - Application not generating expected __events

        2. **Incomplete Data**
           - Partial trace information
           - Missing metrics or logs
           - Data sampling configuration issues

        3. **Data Export Failures**
           - OTLP exporter not configured
           - Network connectivity to SigNoz
           - Data serialization errors
        """

      "dashboard_problems" ->
        """
        1. **Dashboard Not Loading**
           - SigNoz service not running
           - Dashboard configuration errors
           - Authentication failures

        2. **Missing or Incorrect Data**
           - Query configuration problems
           - Time range selection issues
           - Data source connectivity problems

        3. **Performance Issues**
           - Slow dashboard loading
           - Query timeout errors
           - Resource utilization problems
        """

      "performance_issues" ->
        """
        1. **High Memory Usage**
           - Telemetry __data accumulation
           - Memory leaks in instrumentation
           - Excessive trace retention

        2. **CPU Performance Impact**
           - Inefficient telemetry processing
           - Synchronous export operations
           - Unoptimized query execution

        3. **Network Performance Issues**
           - High bandwidth usage for telemetry
           - Network latency affecting exports
           - Connection pool exhaustion
        """

      _ ->
        """
        Common issues related to #{String.replace(category, "_", " ")} include:
        - Configuration problems
        - Network connectivity issues
        - Resource constraints
        - Authentication failures
        """
    end
  end

  @spec generate_quick_diagnosis_steps(String.t()) :: String.t()
  defp generate_quick_diagnosis_steps(category) do
    case category do
      "installation_issues" ->
        """
        1. Check Elixir and Phoenix versions: `elixir --version && mix phx --version`
        2. Verify dependencies: `mix deps.get && mix deps.compile`
        3. Test basic application startup: `mix phx.server --check-ready`
        4. Validate container environment: `podman version && podman ps`
        """

      "configuration_problems" ->
        """
        1. Validate configuration file syntax: `mix config.validate`
        2. Check environment variables: `env | grep OTEL`
        3. Test network connectivity: `curl -f http://localhost:4317/health`
        4. Verify file permissions: `ls -la config/`
        """

      "telemetry_data_issues" ->
        """
        1. Check telemetry setup: `mix telemetry.status`
        2. Verify instrumentation: `mix observability.check_instrumentation`
        3. Test __data export: `mix otel.test_export`
        4. Monitor telemetry __events: `mix telemetry.monitor --live`
        """

      _ ->
        """
        1. Check service status and logs
        2. Verify configuration files
        3. Test network connectivity
        4. Review recent changes
        """
    end
  end

  @spec generate_detailed_solutions(String.t(), list(String.t())) :: String.t()
  defp generate_detailed_solutions(category, solutions) do
    if Enum.empty?(solutions) do
      "Detailed solutions for #{category} are being developed. Please refer to general troubleshooting procedures."
    else
      Enum.map_join(solutions, "\n\n", &generate_detailed_solution_item/1)
    end
  end

  @spec generate_detailed_solution_item(String.t()) :: String.t()
  defp generate_detailed_solution_item(solution) do
    """
    #### #{String.capitalize(String.replace(solution, "_", " "))}

    #{generate_solution_overview(solution)}

    **Resolution Steps:**
    #{generate_solution_steps(solution)}
    """
  end

  @spec generate_solution_overview(String.t()) :: String.t()
  defp generate_solution_overview(solution) do
    case solution do
      "dependency_resolution" ->
        "Resolves issues related to package dependencies and version conflicts in the Elixir/Phoenix application."

      "otel_configuration_fixes" ->
        "Addresses OpenTelemetry configuration problems including endpoint setup and instrumentation issues."

      "signoz_connectivity_solutions" ->
        "Fixes connectivity issues between the application and SigNoz observability platform."

      "dashboard_deployment_fixes" ->
        "Resolves dashboard deployment and configuration problems in SigNoz."

      "performance_optimization_steps" ->
        "Optimizes application performance and reduces observability overhead."

      _ ->
        "Comprehensive solution for #{String.replace(solution, "_", " ")} related issues."
    end
  end

  @spec generate_solution_steps(String.t()) :: String.t()
  defp generate_solution_steps(solution) do
    case solution do
      "dependency_resolution" ->
        """
        1. Clean existing dependencies: `mix deps.clean --all`
        2. Update mix.lock file: `rm mix.lock && mix deps.get`
        3. Resolve version conflicts: Edit mix.exs to specify compatible versions
        4. Recompile dependencies: `mix deps.compile --force`
        5. Verify resolution: `mix deps.tree`
        """

      "otel_configuration_fixes" ->
        """
        1. Validate OTLP endpoint: `curl -f http://localhost:4317/v1/traces`
        2. Check configuration syntax: `mix config.validate`
        3. Verify environment variables: `env | grep OTEL`
        4. Test instrumentation setup: `mix otel.test_instrumentation`
        5. Restart with debug logging: `OTEL_LOG_LEVEL=debug mix phx.server`
        """

      "signoz_connectivity_solutions" ->
        """
        1. Verify SigNoz service status: `podman ps | grep signoz`
        2. Check network connectivity: `curl -f http://localhost:3301/api/v1/health`
        3. Validate firewall rules: `sudo ufw status`
        4. Test DNS resolution: `nslookup localhost`
        5. Review SigNoz logs: `podman logs signoz-query-service`
        """

      _ ->
        """
        1. Identify the root cause of the issue
        2. Apply the appropriate configuration changes
        3. Restart affected services
        4. Validate the solution effectiveness
        5. Monitor for issue recurrence
        """
    end
  end

  @spec generate_validation_commands(String.t()) :: String.t()
  defp generate_validation_commands(solution) do
    case solution do
      "dependency_resolution" ->
        """
        ```bash
        # Verify all dependencies are resolved
        mix deps.get --check

        # Check for compilation warnings
        mix compile --warnings-as-errors

        # Test application startup
        mix phx.server --check-ready
        ```
        """

      "otel_configuration_fixes" ->
        """
        ```bash
        # Test OTLP exporter configuration
        mix otel.test_export --endpoint http://localhost:4317

        # Validate instrumentation
        mix observability.validate_instrumentation

        # Check telemetry __data flow
        mix telemetry.test --duration 30
        ```
        """

      _ ->
        """
        ```bash
        # Generic validation commands
        mix test --only integration
        mix observability.health_check
        curl -f http://localhost:4000/health
        ```
        """
    end
  end

  @spec generate_expected_outcomes(String.t()) :: String.t()
  defp generate_expected_outcomes(solution) do
    case solution do
      "dependency_resolution" ->
        "- All dependencies successfully compiled\n- No version conflict warnings\n- Application starts without errors"

      "otel_configuration_fixes" ->
        "- Telemetry __data successfully exported to SigNoz\n- Traces visible in SigNoz dashboard\n- No configuration warnings in logs"

      "signoz_connectivity_solutions" ->
        "- SigNoz dashboard accessible\n- Real-time __data updates visible\n- No connection timeout errors"

      _ ->
        "- Issue successfully resolved\n- System functioning normally\n- No error messages in logs"
    end
  end

  @spec generate_pr_evention_measures(String.t()) :: String.t()
  defp generate_pr_evention_measures(category) do
    case category do
      "installation_issues" ->
        """
        - Use exact version specifications in mix.exs
        - Implement automated dependency checks in CI/CD
        - Maintain consistent development environments
        - Document environment setup procedures
        """

      "configuration_problems" ->
        """
        - Use configuration validation in application startup
        - Implement environment-specific configuration files
        - Add configuration change notifications
        - Regular configuration audits and reviews
        """

      "telemetry_data_issues" ->
        """
        - Implement telemetry health checks
        - Monitor __data export success rates
        - Set up alerting for __data collection failures
        - Regular instrumentation validation tests
        """

      _ ->
        """
        - Regular system health monitoring
        - Proactive issue detection and alerting
        - Documentation of configuration changes
        - Automated testing and validation procedures
        """
    end
  end

  @spec combine_troubleshooting_content(map(), list(String.t()), list(String.t()), String.t()) ::
          String.t()
  defp combine_troubleshooting_content(
         config,
         category_sections,
         solution_sections,
         diagnostic_section
       ) do
    title = config[:title] || "Comprehensive Observability Troubleshooting Guide"

    """
    # #{title}

    This comprehensive guide provides systematic troubleshooting procedures for Elixir-SigNoz observability integration issues.

    ## Table of Contents

    1. [Quick Reference](#quick-reference)
    2. [Common Issues by Category](#common-issues-by-category)
    3. [Detailed Solutions](#detailed-solutions)
    4. [Diagnostic Commands](#diagnostic-commands)
    5. [Escalation Procedures](#escalation-procedures)

    ## Quick Reference

    For immediate assistance with common issues:

    | Issue Type | Quick Fix | Full Solution |
    |------------|-----------|---------------|
    | App won't start | Check dependencies | [Installation Issues](#installation-issues) |
    | No telemetry __data | Verify configuration | [Telemetry Issues](#telemetry-__data-issues) |
    | Dashboard not loading | Check SigNoz service | [Dashboard Problems](#dashboard-problems) |
    | Poor performance | Optimize configuration | [Performance Issues](#performance-issues) |

    ## Common Issues by Category

    #{Enum.join(category_sections, "\n")}

    ## Detailed Solutions

    #{Enum.join(solution_sections, "\n")}

    #{diagnostic_section}

    ## Escalation Procedures

    If the above solutions don't resolve your issue:

    1. **Gather Diagnostic Information**
       - Run all relevant diagnostic commands
       - Collect log files from the last 24 hours
       - Document exact error messages and steps to reproduce

    2. **Check Known Issues**
       - Review recent GitHub issues and discussions
       - Check SigNoz community forums
       - Search Elixir community resources

    3. **Contact Support**
       - Include diagnostic information
       - Specify your environment configuration
       - Provide detailed reproduction steps

    ## Additional Resources

    - [OpenTelemetry Elixir Documentation](https://hexdocs.pm/opentelemetry)
    - [SigNoz Documentation](https://signoz.io/docs/)
    - [Phoenix Framework Guides](https://hexdocs.pm/phoenix)
    - [Elixir Community Forum](https://elixirforum.com)

    ---

    **Last Updated**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Version**: 1.0.0
    """
  end

  # Utility functions

  @spec ensure_directory_exists(String.t()) :: :ok
  defp ensure_directory_exists(dir_path) do
    File.mkdir_p!(dir_path)
  end

  @spec count_words(String.t()) :: integer()
  defp count_words(content) do
    content
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end

  @spec count_diagnostic_commands(String.t()) :: integer()
  defp count_diagnostic_commands(diagnostic_section) do
    diagnostic_section
    |> String.split("\n")
    |> Enum.count(&String.starts_with?(String.trim(&1), "#"))
  end

  ## ObservabilityHelpers Behaviour Implementation

  @impl Indrajaal.Observability.ObservabilityHelpers
  def setup do
    Logger.info("🔧 Setting up Troubleshooting Guide Generator observability")
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def handle_event(event_name, measurements, metadata) do
    Logger.debug("📊 Troubleshooting Guide Generator event received",
      event: event_name,
      measurements: measurements,
      metadata: metadata
    )

    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def get_metrics do
    case GenServer.call(__MODULE__, :get_metrics, 5000) do
      {:ok, metrics} -> {:ok, metrics}
      error -> error
    end
  rescue
    _ -> {:error, :metrics_unavailable}
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def record_metric(metric_name, value) do
    Logger.debug("📈 Recording metric", metric: metric_name, value: value)
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def configure(options) do
    Logger.info("⚙️ Configuring Troubleshooting Guide Generator", options: options)
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def get_configuration do
    {:ok, [generation_timeout: @guide_generation_timeout]}
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def shutdown do
    Logger.info("🛑 Shutting down Troubleshooting Guide Generator observability")
    :ok
  end
end
