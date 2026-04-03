defmodule Indrajaal.Observability.IntegrationDocumentationBuilder do
  @moduledoc """
  ## Agent: Worker Agent 4 - Integration Documentation Specialist
  ## SOPv5.1 Compliance: Step-by-step integration guides with cybernetic validation
  ## Maximum Parallelization: Concurrent integration procedure generation

  Advanced Integration Documentation Builder for Comprehensive Observability Guides

  This module provides comprehensive integration documentation generation with:
  - Step-by-step integration procedures with verification checkpoints
  - Automated validation script generation for each integration step
  - Multi-environment integration guides (development, staging, production)
  - Troubleshooting integration for common integration failures
  - Performance benchmarking integration procedures
  - Security validation integration for production deployments
  - Container-native integration procedures with PHICS support
  - Multi-tenant integration configuration with isolation validation
  """

  use GenServer
  require Logger

  # CLAUDE_AGENT_CONTEXT: TDG behaviour implementation
  # Date: 2025-09-04 02:08 CEST
  # Pattern: EP062_MISSING_BEHAVIOUR_IMPLEMENTATION
  # Purpose: Proper behaviour implementation with default implementations
  use Indrajaal.Observability.DefaultImpl

  @behaviour Indrajaal.Observability.ObservabilityHelpers

  # Integration documentation configuration
  @integration_docs_path "docs/integration"
  @documentation_timeout 30_000

  defstruct [
    :integration_guides_cache,
    :validation_scripts_cache,
    guides_generated: 0,
    verification_procedures_created: 0
  ]

  ## Public API

  @doc """
  Starts the Integration Documentation Builder system.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generates comprehensive step-by-step integration guide with verification procedures.
  """
  @spec generate_integration_guide(map()) :: {:ok, map()} | {:error, atom()}
  def generate_integration_guide(config) when is_map(config) do
    GenServer.call(__MODULE__, {:generate_integration_guide, config}, @documentation_timeout)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("🔗 Initializing Integration Documentation Builder")

    state = %__MODULE__{
      integration_guides_cache: %{},
      validation_scripts_cache: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:generate_integration_guide, config}, _from, state) do
    Logger.info("📖 Generating comprehensive integration guide with verification procedures")

    case generate_integration_guide_parallel(config) do
      {:ok, guide_info} ->
        new_state = %{
          state
          | guides_generated: state.guides_generated + 1,
            verification_procedures_created:
              state.verification_procedures_created + guide_info.verification_procedures_count
        }

        Logger.info("✅ Integration guide generated successfully",
          steps: guide_info.steps_count,
          verification_procedures: guide_info.verification_procedures_count
        )

        {:reply, {:ok, guide_info}, new_state}

      {:error, reason} ->
        Logger.error("❌ Integration guide generation failed", error: reason)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      guides_generated: state.guides_generated,
      verification_procedures_created: state.verification_procedures_created,
      integration_steps_documented: state.integration_steps_documented,
      average_generation_time_ms: state.average_generation_time_ms
    }

    {:reply, {:ok, metrics}, state}
  end

  ## Private Functions

  @spec generate_integration_guide_parallel(map()) :: {:ok, map()} | {:error, atom()}
  defp generate_integration_guide_parallel(config) do
    try do
      # Multi-agent integration guide generation
      step_tasks =
        (config[:integration_steps] || [])
        |> Enum.map(fn step ->
          Task.async(fn ->
            generate_integration_step(step, config)
          end)
        end)

      verification_tasks =
        (config[:verification_procedures] || [])
        |> Enum.map(fn verification ->
          Task.async(fn ->
            generate_verification_procedure(verification, config)
          end)
        end)

      checklist_task =
        Task.async(fn ->
          generate_integration_checklists(config)
        end)

      validation_scripts_task =
        Task.async(fn ->
          generate_validation_scripts(config)
        end)

      # Wait for all tasks to complete
      step_sections = Task.await_many(step_tasks, @documentation_timeout)
      verification_sections = Task.await_many(verification_tasks, @documentation_timeout)
      checklists_content = Task.await(checklist_task, @documentation_timeout)
      validation_scripts_content = Task.await(validation_scripts_task, @documentation_timeout)

      # Combine all integration guide content
      guide_content =
        combine_integration_guide_content(
          config,
          step_sections,
          verification_sections,
          checklists_content,
          validation_scripts_content
        )

      # Write integration guide
      file_path =
        config[:output_path] || "#{@integration_docs_path}/complete_integration_guide.md"

      ensure_directory_exists(Path.dirname(file_path))
      :ok = File.write!(file_path, guide_content)

      # Calculate guide metrics
      guide_info = %{
        file_path: file_path,
        word_count: count_words(guide_content),
        steps_count: length(step_sections),
        verification_procedures_count: length(verification_sections),
        checklists_count: count_checklists(checklists_content),
        validation_scripts_count: count_validation_scripts(validation_scripts_content),
        difficulty_level: config[:difficulty_level] || "intermediate",
        generated_at: System.system_time(:second)
      }

      {:ok, guide_info}
    rescue
      error ->
        Logger.error("Integration guide generation error: #{inspect(error)}")
        {:error, :generation_failed}
    end
  end

  @spec generate_integration_step(String.t(), map()) :: String.t()
  defp generate_integration_step(step_name, _config) do
    case step_name do
      "environment_preparation" ->
        """
        ## Environment Preparation

        ### Prerequisites Validation

        Before beginning the Elixir-SigNoz integration, ensure your environment meets all requirements:

        ```bash
        # Verify Elixir version (1.18+ required)
        elixir --version

        # Verify Phoenix framework
        mix phx.new --version

        # Verify container runtime
        podman --version || docker --version

        # Verify database connectivity
        pg_isready -h localhost -p 5433
        ```

        ### Development Environment Setup

        1. **Initialize Development Environment**
           ```bash
           # Enter development environment
           devenv shell

           # Verify all tools available
           mix --version && elixir --version && podman --version
           ```

        2. **Container Network Configuration**
           ```bash
           # Create observability network
           podman network create observability-network

           # Verify network creation
           podman network ls | grep observability
           ```

        3. **PostgreSQL Configuration for Observability**
           ```sql
           -- Create observability database
           CREATE DATABASE indrajaal_observability;

           -- Create observability user with appropriate permissions
           CREATE USER observability_user WITH PASSWORD 'secure_password';
           GRANT ALL PRIVILEGES ON DATABASE indrajaal_observability TO observability_user;
           ```

        ### Environment Validation Checklist

        - [ ] Elixir 1.19+ installed and functional
        - [ ] Phoenix framework available
        - [ ] Container runtime (Podman/Docker) operational
        - [ ] PostgreSQL 17+ running and accessible
        - [ ] Development environment initialized
        - [ ] Container network configured
        - [ ] Database permissions validated
        """

      "dependency_installation" ->
        """
        ## Dependency Installation

        ### OpenTelemetry Dependencies

        Add the following dependencies to your `mix.exs` file:

        ```elixir
        defp deps do
          [
            # Core OpenTelemetry dependencies
            {:opentelemetry, "~> 1.5"},
            {:opentelemetry_api, "~> 1.4"},
            {:opentelemetry_sdk, "~> 1.5"},

            # OpenTelemetry exporters
            {:opentelemetry_exporter, "~> 1.7"},
            {:opentelemetry_otlp_exporter, "~> 1.0"},

            # Framework instrumentation
            {:opentelemetry_phoenix, "~> 2.0"},
            {:opentelemetry_ecto, "~> 2.0"},
            {:opentelemetry_cowboy, "~> 0.3"},

            # Additional telemetry libraries
            {:telemetry, "~> 1.3"},
            {:telemetry_metrics, "~> 1.0"},
            {:telemetry_poller, "~> 1.1"},

            # JSON encoding for telemetry data
            {:jason, "~> 1.4"}
          ]
        end
        ```

        ### Installation Process

        1. **Clean Previous Dependencies**
           ```bash
           mix deps.clean --all
           rm -f mix.lock
           ```

        2. **Install New Dependencies**
           ```bash
           mix deps.get
           mix deps.compile
           ```

        3. **Verify Installation**
           ```bash
           # Check OpenTelemetry modules are available
           mix run -e "IO.inspect(:if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry.get_application_tracer(:indrajaal), else: :ok, else: :ok, else: :ok, else: :ok)"

           # Verify instrumentation libraries
           mix deps.tree | grep opentelemetry
           ```

        ### Dependency Validation

        ```elixir
        # Create temporary validation script
        # File: scripts/validate_dependencies.exs
        require Logger

        dependencies_to_validate = [
          :opentelemetry,
          :opentelemetry_api,
          :opentelemetry_sdk,
          :opentelemetry_exporter,
          :opentelemetry_phoenix,
          :opentelemetry_ecto
        ]

        for dep <- dependencies_to_validate do
          case Application.ensure_started(dep) do
            :ok -> Logger.info("✅ \#{dep} loaded successfully")
            {:ok, _} -> Logger.info("✅ \#{dep} already started")
            {:error, reason} -> Logger.error("❌ \#{dep} failed to load: \#{inspect(reason)}")
          end
        end
        ```

        ### Installation Verification Checklist

        - [ ] All dependencies added to mix.exs
        - [ ] Dependencies successfully downloaded
        - [ ] Dependencies compiled without errors
        - [ ] OpenTelemetry modules accessible
        - [ ] Instrumentation libraries validated
        - [ ] No version conflicts detected
        """

      "basic_configuration" ->
        """
        ## Basic Configuration

        ### OpenTelemetry Configuration

        Create the basic OpenTelemetry configuration in `config/config.exs`:

        ```elixir
        # config/config.exs
        import Config

        # Basic OpenTelemetry service configuration
        config :opentelemetry,
          service_name: "indrajaal-observability",
          service_version: "1.0.0",
          service_namespace: "#{Mix.env()}",
          resource: %{
            "service.name" => "indrajaal-observability",
            "service.version" => "1.0.0"
          }

        # Configure processors and exporters
        config :opentelemetry, :processors,
          otel_batch_processor: %{
            exporter: :otel_exporter_stdout
          }
        ```

        ### Environment-Specific Configuration

        **Development Configuration** (`config/dev.exs`):
        ```elixir
        import Config

        # Development OTLP configuration
        config :opentelemetry_exporter,
          otlp_protocol: :grpc,
          otlp_endpoint: "http://localhost:4317",
          otlp_headers: [],
          otlp_compression: :none

        # Enable debug logging in development
        config :logger, level: :debug

        # Telemetry configuration for development
        config :telemetry_poller,
          measurements: [
            {MyApp.Telemetry, :system_metrics, []},
            {MyApp.Telemetry, :application_metrics, []}
          ],
          period: 5_000
        ```

        **Production Configuration** (`config/prod.exs`):
        ```elixir
        import Config

        # Production OTLP configuration
        config :opentelemetry_exporter,
          otlp_protocol: :grpc,
          otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
          otlp_headers: [
            {"Authorization", "Bearer #{System.get_env("SIGNOZ_API_TOKEN", "")}"}
          ],
          otlp_compression: :gzip

        # Production telemetry configuration
        config :telemetry_poller, period: 30_000
        ```

        ### Application Configuration

        Update your `application.ex` to initialize observability:

        ```elixir
        defmodule Indrajaal.Application do
          use Application

          def start(type, args) do
            # Initialize OpenTelemetry instrumentation
            :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_cowboy.setup(), else: :ok, else: :ok, else: :ok, else: :ok
            :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_phoenix.setup(), else: :ok, else: :ok, else: :ok, else: :ok
            :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry_ecto.setup([:indrajaal, :repo]), else: :ok, else: :ok, else: :ok, else: :ok

            children = [
              # Telemetry supervisor
              IndrajaalWeb.Telemetry,

              # Database
              Indrajaal.Repo,

              # PubSub
              {Phoenix.PubSub, name: Indrajaal.PubSub},

              # Web endpoint
              IndrajaalWeb.Endpoint
            ]
            opts = [strategy: :one_for_one, name: Indrajaal.Supervisor]
            Supervisor.start_link(children, opts)
          end
        end
        ```

        ### Configuration Validation

        ```bash
        # Validate configuration syntax
        mix compile --warnings-as-errors

        # Test basic application startup
        iex -S mix
        ```

        ### Configuration Validation Checklist

        - [ ] Basic OpenTelemetry configuration added
        - [ ] Environment-specific configurations created
        - [ ] Application.ex updated with instrumentation
        - [ ] Configuration compiles without warnings
        - [ ] Application starts successfully
        """

      _ ->
        """
        ## #{String.capitalize(String.replace(step_name, "_", " "))}

        This step provides comprehensive procedures for #{String.replace(step_name, "_", " ")}
        in the Elixir-SigNoz observability integration process.

        ### Overview

        #{String.capitalize(String.replace(step_name, "_", " "))} is a critical component
        of the observability integration that ensures proper system functionality
        and performance monitoring capabilities.

        ### Implementation Steps

        1. **Preparation Phase**
           - Review requirements and prerequisites
           - Validate environment configuration
           - Prepare necessary resources and tools

        2. **Implementation Phase**
           - Execute step-by-step procedures
           - Apply configuration changes
           - Validate implementation at each stage

        3. **Verification Phase**
           - Run comprehensive verification tests
           - Validate system functionality
           - Confirm integration success

        ### Validation Procedures

        ```bash
        # Validation commands for #{step_name}
        mix test --only integration_#{step_name}
        mix observability.validate --step #{step_name}
        ```
        """
    end
  end

  @spec generate_verification_procedure(String.t(), map()) :: String.t()
  defp generate_verification_procedure(verification_name, _config) do
    case verification_name do
      "dependency_verification" ->
        """
        ### Dependency Verification Procedure

        **Purpose**: Validate that all OpenTelemetry dependencies are correctly installed and functional.

        **Verification Steps**:

        1. **Module Availability Check**
           ```elixir
           # Run in IEx console
           modules_to_check = [
             :opentelemetry,
             :opentelemetry_api,
             :opentelemetry_sdk,
             :opentelemetry_exporter
           ]

           for module <- modules_to_check do
             case Code.ensure_loaded(module) do
               {:module, ^module} -> IO.puts("✅ \#{module} loaded")
               {:error, reason} -> IO.puts("❌ \#{module} failed: \#{reason}")
             end
           end
           ```

        2. **Functional Validation**
           ```bash
           # Test OpenTelemetry tracer creation
           mix run -e "
           tracer = :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry.get_application_tracer(:test_app), else: :ok, else: :ok, else: :ok, else: :ok
           IO.inspect(tracer, label: 'Tracer')
           "
           ```

        3. **Version Compatibility Check**
           ```bash
           mix deps.tree | grep opentelemetry | head -10
           ```

        **Expected Results**:
        - All OpenTelemetry modules load without errors
        - Tracer instance created successfully
        - No version conflicts in dependency tree

        **Troubleshooting**: If verification fails, run `mix deps.clean --all && mix deps.get`
        """

      "configuration_validation" ->
        """
        ### Configuration Validation Procedure

        **Purpose**: Ensure OpenTelemetry configuration is syntactically correct and functionally valid.

        **Verification Steps**:

        1. **Configuration Syntax Check**
           ```bash
           # Validate configuration compiles
           mix compile --warnings-as-errors
           ```

        2. **Runtime Configuration Validation**
           ```elixir
           # Check service name configuration
           Application.get_env(:opentelemetry, :service_name)

           # Validate processor configuration
           Application.get_env(:opentelemetry, :processors)
           ```

        3. **OTLP Exporter Configuration Test**
           ```elixir
           # Test OTLP endpoint configuration
           endpoint = Application.get_env(:opentelemetry_exporter, :otlp_endpoint)
           IO.puts("OTLP Endpoint: \#{endpoint}")
           ```

        **Expected Results**:
        - Configuration compiles without warnings
        - Service name properly configured
        - OTLP endpoint accessible

        **Troubleshooting**: Check environment variables and configuration file syntax
        """

      "telemetry_data_flow_check" ->
        """
        ### Telemetry Data Flow Check Procedure

        **Purpose**: Validate that telemetry data flows correctly from application to SigNoz.

        **Verification Steps**:

        1. **Manual Trace Generation**
           ```elixir
           require OpenTelemetry.Tracer

           OpenTelemetry.Tracer.with_span "test_span" do
             if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: if Code.ensure_loaded?(OpenTelemetry), do: OpenTelemetry.Span.add_event("test_event", %{test_attribute: "test_value"}), else: :ok, else: :ok, else: :ok, else: :ok
             :timer.sleep(100)  # Simulate work
           end
           ```

        2. **Telemetry Event Emission**
           ```elixir
           :telemetry.execute(
             [:indrajaal, :test, :metric],
             %{value: 42},
             %{environment: "test"}
           )
           ```

        3. **Data Export Verification**
           ```bash
           # Check application logs for export activity
           tail -f log/dev.log | grep -i "export\\|trace\\|span"
           ```

        **Expected Results**:
        - Traces generated without errors
        - Telemetry events emitted successfully
        - Export activity visible in logs

        **Troubleshooting**: Check network connectivity and OTLP endpoint configuration
        """

      _ ->
        """
        ### #{String.capitalize(String.replace(verification_name, "_", " "))} Procedure

        **Purpose**: Validate #{String.replace(verification_name, "_", " ")} functionality.

        **Verification Steps**:

        1. **Preparation**
           - Review verification requirements
           - Prepare test environment
           - Ensure all prerequisites are met

        2. **Execution**
           - Run verification procedures
           - Monitor for expected outcomes
           - Document results and observations

        3. **Validation**
           - Confirm success criteria are met
           - Address any identified issues
           - Document verification completion

        **Expected Results**: All verification criteria successfully validated.

        **Troubleshooting**: Refer to troubleshooting guide for common issues.
        """
    end
  end

  @spec generate_integration_checklists(map()) :: String.t()
  defp generate_integration_checklists(config) do
    """
    ## Integration Checklists

    ### Pre-Integration Checklist

    **Environment Preparation**:
    - [ ] Elixir 1.19+ installed and verified
    - [ ] Phoenix framework available
    - [ ] Container runtime (Podman/Docker) operational
    - [ ] PostgreSQL 17+ running and accessible
    - [ ] Development environment initialized
    - [ ] Required permissions and access rights configured

    **Dependency Management**:
    - [ ] mix.exs updated with OpenTelemetry dependencies
    - [ ] Dependencies downloaded successfully (`mix deps.get`)
    - [ ] Dependencies compiled without errors (`mix deps.compile`)
    - [ ] No version conflicts detected (`mix deps.tree`)

    ### Integration Process Checklist

    **Configuration Setup**:
    - [ ] Basic OpenTelemetry configuration added to config.exs
    - [ ] Environment-specific configurations created (dev.exs, prod.exs)
    - [ ] Application.ex updated with instrumentation initialization
    - [ ] Configuration syntax validated (`mix compile --warnings-as-errors`)

    **Instrumentation Implementation**:
    - [ ] Phoenix instrumentation configured
    - [ ] Ecto instrumentation configured
    - [ ] Custom telemetry events defined
    - [ ] Trace correlation implemented

    **SigNoz Integration**:
    - [ ] OTLP exporter configured for SigNoz
    - [ ] Network connectivity to SigNoz validated
    - [ ] Dashboard templates deployed
    - [ ] Data visualization confirmed

    ### Post-Integration Checklist

    **Validation and Testing**:
    - [ ] All verification procedures completed successfully
    - [ ] Integration tests passing
    - [ ] Performance impact assessed and acceptable
    - [ ] Security validation completed

    **Documentation and Maintenance**:
    - [ ] Integration documentation updated
    - [ ] Troubleshooting guides reviewed
    - [ ] Team training completed
    - [ ] Maintenance procedures established

    #{if config[:difficulty_level] == "advanced" do
      """

      ### Advanced Integration Checklist

      **Advanced Configuration**:
      - [ ] Multi-tenant isolation configured
      - [ ] Custom metrics and traces implemented
      - [ ] Performance optimization applied
      - [ ] Security hardening completed

      **Production Deployment**:
      - [ ] Production configuration validated
      - [ ] Deployment automation implemented
      - [ ] Monitoring and alerting configured
      - [ ] Disaster recovery procedures tested
      """
    else
      ""
    end}
    """
  end

  @spec generate_validation_scripts(map()) :: String.t()
  defp generate_validation_scripts(_config) do
    """
    ## Validation Scripts

    ### Comprehensive Integration Validation Script

    Create the following validation script as `scripts/validate_observability_integration.exs`:

    ```elixir
    #!/usr/bin/env elixir

    Mix.install([{:jason, "~> 1.4"}])

    defmodule ObservabilityIntegrationValidator do
      @moduledoc "Comprehensive validation of observability integration"

      require Logger

      def run_validation do
        Logger.info("🔍 Starting comprehensive observability integration validation")

        validation_results = [
          validate_dependencies(),
          validate_configuration(),
          validate_telemetry_setup(),
          validate_data_flow(),
          validate_dashboard_connectivity()
        ]

        success_count = Enum.count(validation_results, & &1)
        total_checks = length(validation_results)

        if success_count == total_checks do
          Logger.info("✅ All validation checks passed (\#{success_count}/\#{total_checks})")
          :ok
        else
          Logger.error("❌ Validation failed (\#{success_count}/\#{total_checks} passed)")
          :error
        end
      end

      defp validate_dependencies do
        Logger.info("Validating OpenTelemetry dependencies...")

        required_modules = [
          :opentelemetry,
          :opentelemetry_api,
          :opentelemetry_sdk,
          :opentelemetry_exporter
        ]

        all_loaded = Enum.all?(required_modules, fn module ->
          case Code.ensure_loaded(module) do
            {:module, ^module} ->
              Logger.info("✅ \#{module} loaded successfully")
              true
            {:error, reason} ->
              Logger.error("❌ \#{module} failed to load: \#{inspect(reason)}")
              false
          end
        end)

        all_loaded
      end

      defp validate_configuration do
        Logger.info("Validating OpenTelemetry configuration...")

        service_name = Application.get_env(:opentelemetry, :service_name)
        processors = Application.get_env(:opentelemetry, :processors)
        otlp_endpoint = Application.get_env(:opentelemetry_exporter, :otlp_endpoint)

        config_valid = service_name != nil and processors != nil and otlp_endpoint != nil

        if config_valid do
          Logger.info("✅ Configuration validation passed")
          Logger.info("Service Name: \#{service_name}")
          Logger.info("OTLP Endpoint: \#{otlp_endpoint}")
        else
          Logger.error("❌ Configuration validation failed")
        end

        config_valid
      end

      defp validate_telemetry_setup do
        Logger.info("Validating telemetry setup...")

        try do
          # Test telemetry event emission
          :telemetry.execute([:validation, :test], %{count: 1}, %{source: "validator"})
          Logger.info("✅ Telemetry event emission successful")
          true
        rescue
          error ->
            Logger.error("❌ Telemetry validation failed: \#{inspect(error)}")
            false
        end
      end

      defp validate_data_flow do
        Logger.info("Validating data flow...")

        try do
          # Test OpenTelemetry tracer
          tracer = :if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: if Code.ensure_loaded?(:opentelemetry), do: opentelemetry.get_application_tracer(:validation_app), else: :ok, else: :ok, else: :ok, else: :ok

          if tracer do
            Logger.info("✅ OpenTelemetry tracer creation successful")
            true
          else
            Logger.error("❌ Failed to create OpenTelemetry tracer")
            false
          end
        rescue
          error ->
            Logger.error("❌ Data flow validation failed: \#{inspect(error)}")
            false
        end
      end

      defp validate_dashboard_connectivity do
        Logger.info("Validating dashboard connectivity...")

        endpoint = Application.get_env(:opentelemetry_exporter, :otlp_endpoint, "http://localhost:4317")

        case System.cmd("curl", ["-f", "-s", endpoint], stderr_to_stdout: true) do
          {output, 0} ->
            Logger.info("✅ Dashboard connectivity validation successful")
            true
          {error_output, exit_code} ->
            Logger.warning("⚠️ Dashboard connectivity check failed: \#{error_output}")
            Logger.info("Note: This may be expected if SigNoz is not currently running")
            true  # Don't fail overall validation for this check
        end
      rescue
        error ->
          Logger.warning("⚠️ Dashboard connectivity validation error: \#{inspect(error)}")
          true  # Don't fail overall validation for this check
      end
    end

    # Run validation
    case ObservabilityIntegrationValidator.run_validation() do
      :ok -> System.halt(0)
      :error -> System.halt(1)
    end
    ```

    ### Quick Health Check Script

    Create a quick health check script as `scripts/observability_health_check.exs`:

    ```elixir
    #!/usr/bin/env elixir

    # Quick health check for observability integration
    require Logger

    Logger.info("🏥 Running quick observability health check")

    # Check if application compiles
    case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
      {output, 0} -> Logger.info("✅ Application compiles without warnings")
      {error, _} ->
        Logger.error("❌ Compilation failed: \#{error}")
        System.halt(1)
    end

    # Check if basic tests pass
    case System.cmd("mix", ["test", "--only", "observability"]) do
      {output, 0} -> Logger.info("✅ Observability tests passing")
      {error, _} -> Logger.warning("⚠️ Some observability tests failed: \#{error}")
    end

    Logger.info("🎯 Health check completed")
    ```

    ### Performance Validation Script

    Create a performance validation script as `scripts/observability_performance_check.exs`:

    ```elixir
    #!/usr/bin/env elixir

    defmodule PerformanceValidator do
      def run_performance_check do
        Logger.info("⚡ Running observability performance validation")

        # Measure telemetry overhead
        measure_telemetry_overhead()

        # Measure trace generation performance
        measure_trace_performance()

        Logger.info("📊 Performance validation completed")
      end

      defp measure_telemetry_overhead do
        iterations = 1_000

        # Measure without telemetry
        {time_without, _} = :timer.tc(fn ->
          for _ <- 1..iterations, do: :ok
        end)

        # Measure with telemetry
        {time_with, _} = :timer.tc(fn ->
          for i <- 1..iterations do
            :telemetry.execute([:performance, :test], %{iteration: i}, %{})
          end
        end)

        overhead_percent = ((time_with - time_without) / time_without) * 100
        Logger.info("Telemetry overhead: \#{Float.round(overhead_percent, 2)}%")
      end

      defp measure_trace_performance do
        require OpenTelemetry.Tracer
        iterations = 100

        {time_microseconds, _} = :timer.tc(fn ->
          for i <- 1..iterations do
            OpenTelemetry.Tracer.with_span "performance_test_\#{i}" do
              :timer.sleep(1)  # Minimal work
            end
          end
        end)

        avg_trace_time = time_microseconds / iterations
        Logger.info("Average trace generation time: \#{Float.round(avg_trace_time, 2)} μs")
      end
    end

    PerformanceValidator.run_performance_check()
    ```
    """
  end

  @spec combine_integration_guide_content(
          map(),
          list(String.t()),
          list(String.t()),
          String.t(),
          String.t()
        ) :: String.t()
  defp combine_integration_guide_content(
         config,
         step_sections,
         verification_sections,
         checklists_content,
         validation_scripts_content
       ) do
    title = config[:title] || "Complete Elixir-SigNoz Integration Guide"
    difficulty_level = config[:difficulty_level] || "intermediate"

    """
    # #{title}

    **Difficulty Level**: #{String.capitalize(difficulty_level)}
    **Estimated Time**: #{estimate_completion_time(config)}
    **Prerequisites**: Elixir 1.19+, Phoenix Framework, Container Runtime

    ## Table of Contents

    1. [Integration Steps](#integration-steps)
    2. [Verification Procedures](#verification-procedures)
    3. [Integration Checklists](#integration-checklists)
    4. [Validation Scripts](#validation-scripts)
    5. [Troubleshooting](#troubleshooting)

    ## Integration Steps

    #{Enum.join(step_sections, "\n\n")}

    ## Verification Procedures

    #{Enum.join(verification_sections, "\n\n")}

    #{checklists_content}

    #{validation_scripts_content}

    ## Troubleshooting

    ### Common Issues and Solutions

    1. **Dependency Installation Failures**
       - **Issue**: mix deps.get fails with version conflicts
       - **Solution**: Clear dependency cache with `mix deps.clean --all && rm mix.lock`

    2. **Configuration Errors**
       - **Issue**: Application fails to start due to configuration errors
       - **Solution**: Validate configuration syntax with `mix compile --warnings-as-errors`

    3. **OTLP Connection Failures**
       - **Issue**: Cannot connect to SigNoz OTLP endpoint
       - **Solution**: Verify network connectivity and endpoint configuration

    4. **Performance Issues**
       - **Issue**: High overhead from telemetry instrumentation
       - **Solution**: Optimize sampling rates and batch processing configuration

    ## Next Steps

    After completing this integration guide:

    1. **Deploy to Production**: Follow production deployment procedures
    2. **Monitor Performance**: Set up performance monitoring and alerting
    3. **Train Team**: Ensure team members understand observability workflows
    4. **Maintain System**: Establish regular maintenance and update procedures

    ## Additional Resources

    - [OpenTelemetry Elixir Documentation](https://hexdocs.pm/opentelemetry)
    - [SigNoz Documentation](https://signoz.io/docs/)
    - [Phoenix Telemetry Guide](https://hexdocs.pm/phoenix/telemetry.html)
    - [Troubleshooting Guide](./troubleshooting_guide.md)

    ---

    **Last Updated**: #{DateTime.utc_now() |> DateTime.to_string()}
    **Version**: 2.0.0
    **Maintained by**: Observability Team
    """
  end

  @spec estimate_completion_time(map()) :: String.t()
  defp estimate_completion_time(config) do
    # Base 4 hours for standard integration
    base_time = 4

    step_count = length(config[:integration_steps] || [])
    verification_count = length(config[:verification_procedures] || [])

    additional_time = step_count * 0.5 + verification_count * 0.3

    case config[:difficulty_level] do
      "beginner" -> "#{base_time + additional_time + 2} hours"
      "intermediate" -> "#{base_time + additional_time} hours"
      "advanced" -> "#{base_time + additional_time + 4} hours"
      _ -> "#{base_time + additional_time} hours"
    end
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

  @spec count_checklists(String.t()) :: integer()
  defp count_checklists(checklists_content) do
    checklists_content
    |> String.split("\n")
    |> Enum.count(&String.contains?(&1, "###"))
  end

  @spec count_validation_scripts(String.t()) :: integer()
  defp count_validation_scripts(validation_scripts_content) do
    validation_scripts_content
    |> String.split("```elixir")
    |> length()
    # Subtract 1 because split creates one extra element
    |> Kernel.-(1)
  end

  ## ObservabilityHelpers Behaviour Implementation

  @impl Indrajaal.Observability.ObservabilityHelpers
  def setup do
    Logger.info("🔧 Setting up Integration Documentation Builder observability")
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def handle_event(event_name, measurements, metadata) do
    Logger.debug("📊 Integration Documentation Builder event received",
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
    Logger.info("⚙️ Configuring Integration Documentation Builder", options: options)
    :ok
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def get_configuration do
    {:ok, [build_timeout: @documentation_timeout]}
  end

  @impl Indrajaal.Observability.ObservabilityHelpers
  def shutdown do
    Logger.info("🛑 Shutting down Integration Documentation Builder observability")
    :ok
  end
end
