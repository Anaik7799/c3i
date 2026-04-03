defmodule Intelitor.ComprehensiveCompilationTest do
  @moduledoc """
  Comprehensive compilation test suite for ALL domains and resources.

  This test ensures:
  1. All 12 Ash domains compile successfully
  2. All 227+ resources are properly structured
  3. All observability infrastructure is functional
  4. Zero compilation warnings (treated as errors)
  5. Performance monitoring during compilation

  MANDATORY: This test MUST pass before any new feature is merged.
  """

  use ExUnit.Case

  alias Intelitor.Shared.CompilationUtilities
  import ExUnit.CaptureIO

  # 10 minutes for full compilation
  @timeout 600_000
  @compilation_start_time System.monotonic_time(:millisecond)

  # All 12 Ash domains in the Intelitor system
  @ash_domains [
    Intelitor.Core,
    Intelitor.Accounts,
    Intelitor.Policy,
    Intelitor.Sites,
    Intelitor.Devices,
    Intelitor.Alarms,
    Intelitor.Video,
    Intelitor.Dispatch,
    Intelitor.Maintenance,
    Intelitor.Compliance,
    Intelitor.Billing,
    Intelitor.Integrations
  ]

  # Additional domains that may exist
  @extended_domains [
    Intelitor.Analytics,
    Intelitor.RiskManagement,
    Intelitor.AssetManagement,
    Intelitor.GuardTour,
    Intelitor.AccessControl,
    Intelitor.Communication
  ]

  # Core observability modules
  @observability_modules [
    Intelitor.Tracing,
    Intelitor.Tracing.ResourceHelpers,
    Intelitor.Logging,
    Intelitor.Telemetry,
    Intelitor.Errors,
    Intelitor.ObservabilityDashboard
  ]

  # Error hierarchy modules
  @error_modules [
    Intelitor.Errors.Forbidden,
    Intelitor.Errors.Business,
    Intelitor.Errors.System,
    Intelitor.Errors.External,
    Intelitor.Errors.Invalid,
    Intelitor.Errors.Unauthorized,
    Intelitor.Errors.NotFound,
    Intelitor.Errors.Conflict,
    Intelitor.Errors.Timeout,
    Intelitor.Errors.ServiceUnavailable,
    Intelitor.Errors.Unknown
  ]

  setup_all do
    # Start compilation timing
    start_time = System.monotonic_time(:millisecond)

    # Ensure clean compilation environment
    Mix.Task.run("clean")

    %{start_time: start_time}
  end

  describe "Domain Compilation Tests" do
    @tag timeout: @timeout
    test "all core Ash domains compile successfully" do
      compilation_results = []

      for domain <- @ash_domains do
        result = compile_domain_with_timing(domain)
        compilation_results = [result | compilation_results]

        assert result.status == :ok,
               "Domain #{domain} failed to compile: #{inspect(result.error)}"
      end

      # Log compilation statistics
      log_compilation_stats("Core Domains", compilation_results)
    end

    @tag timeout: @timeout
    test "all extended domains compile successfully" do
      compilation_results = []

      for domain <- @extended_domains do
        if domain_exists?(domain) do
          result = compile_domain_with_timing(domain)
          compilation_results = [result | compilation_results]

          assert result.status == :ok,
                 "Extended domain #{domain} failed to compile: #{inspect(result.error)}"
        end
      end

      log_compilation_stats("Extended Domains", compilation_results)
    end

    @tag timeout: @timeout
    test "all resources within domains compile and load correctly" do
      all_resources = discover_all_resources()

      assert length(all_resources) > 200,
             "Expected at least 200 resources, found #{length(all_resources)}"

      compilation_failures = []

      for resource <- all_resources do
        case compile_and_validate_resource(resource) do
          {:error, reason} ->
            compilation_failures = [%{resource: resource, reason: reason} | compilation_failures]

          :ok ->
            :ok
        end
      end

      if length(compilation_failures) > 0 do
        perform_rca_on_failures(compilation_failures)

        flunk(
          "#{length(compilation_failures)} resources failed compilation: #{inspect(compilation_failures)}"
        )
      end
    end
  end

  describe "Observability Infrastructure Tests" do
    @tag timeout: 30_000
    test "all observability modules compile and are functional" do
      for module <- @observability_modules do
        assert Code.ensure_loaded(module) == {:module, module},
               "Observability module #{module} failed to load"

        # Test basic functionality
        case module do
          Intelitor.Tracing ->
            assert function_exported?(module, :with_span, 3)
            assert function_exported?(module, :trace_ash_operation, 5)

          Intelitor.Logging ->
            assert function_exported?(module, :log_security_event, 3)
            assert function_exported?(module, :log_device_event, 3)

          Intelitor.Telemetry ->
            assert function_exported?(module, :handle_event, 4)

          Intelitor.Errors ->
            assert function_exported?(module, :emit_error_telemetry, 2)

          _ ->
            # For other modules, just ensure they loaded
            :ok
        end
      end
    end

    @tag timeout: 30_000
    test "all error hierarchy modules compile correctly" do
      for error_module <- @error_modules do
        assert Code.ensure_loaded(error_module) == {:module, error_module},
               "Error module #{error_module} failed to load"

        # Verify error module has proper Splode structure
        assert function_exported?(error_module, :exception, 1)
      end
    end
  end

  describe "Compilation Warning Analysis" do
    @tag timeout: @timeout
    test "compilation produces zero warnings (warnings treated as errors)" do
      {output, exit_code} = run_compilation_with_warnings_capture()

      warnings = extract_warnings_from_output(output)

      if length(warnings) > 0 do
        perform_rca_on_warnings(warnings)

        warning_summary =
          Enum.map(warnings, fn w ->
            "#{w.file}:#{w.line} - #{w.message}"
          end)
          |> Enum.join("\n")

        flunk("""
        Compilation produced #{length(warnings)} warnings (treated as errors):

        #{warning_summary}

        All warnings must be resolved before merging new features.
        """)
      end

      assert exit_code == 0, "Compilation failed with exit code #{exit_code}"
    end
  end

  describe "Performance and Resource Usage" do
    @tag timeout: @timeout
    test "compilation completes within acceptable time limits" do
      start_time = System.monotonic_time(:millisecond)

      # Force full recompilation
      {_output, exit_code} =
        System.cmd("mix", ["compile", "--force"],
          cd: System.cwd!(),
          stderr_to_stdout: true
        )

      end_time = System.monotonic_time(:millisecond)
      compilation_time_ms = end_time - start_time

      assert exit_code == 0, "Compilation failed"

      # Log compilation performance
      IO.puts("""

      📊 COMPILATION PERFORMANCE METRICS:
      =====================================
      Total compilation time: #{compilation_time_ms}ms (#{Float.round(compilation_time_ms / 1000, 2)}s)
      Average time per file: #{Float.round(compilation_time_ms / 227, 2)}ms

      Performance thresholds:
      - Acceptable: < 300 seconds (5 minutes)
      - Warning: 300-600 seconds (5-10 minutes)
      - Critical: > 600 seconds (10+ minutes)
      """)

      cond do
        compilation_time_ms > 600_000 ->
          flunk(
            "Compilation took #{Float.round(compilation_time_ms / 1000, 2)}s - exceeds critical threshold of 10 minutes"
          )

        compilation_time_ms > 300_000 ->
          IO.puts(
            "⚠️  WARNING: Compilation took #{Float.round(compilation_time_ms / 1000, 2)}s - approaching timeout threshold"
          )

        true ->
          IO.puts(
            "✅ Compilation performance acceptable: #{Float.round(compilation_time_ms / 1000, 2)}s"
          )
      end
    end

    @tag timeout: 60_000
    test "memory usage during compilation stays within limits" do
      # Monitor memory usage during compilation
      memory_samples = monitor_memory_during_compilation()

      max_memory_mb = Enum.max(memory_samples) / (1024 * 1024)
      avg_memory_mb = Enum.sum(memory_samples) / length(memory_samples) / (1024 * 1024)

      IO.puts("""

      🧠 MEMORY USAGE ANALYSIS:
      =========================
      Maximum memory usage: #{Float.round(max_memory_mb, 2)} MB
      Average memory usage: #{Float.round(avg_memory_mb, 2)} MB
      Memory samples taken: #{length(memory_samples)}
      """)

      # Set reasonable memory limits for compilation
      assert max_memory_mb < 2048,
             "Compilation exceeded memory limit: #{Float.round(max_memory_mb, 2)} MB (limit: 2048 MB)"
    end
  end

  describe "Dependency and Configuration Validation" do
    @tag timeout: 30_000
    test "all required dependencies are properly configured" do
      # Check mix.exs dependencies
      deps = Mix.Project.config()[:deps]

      required_observability_deps = [
        :opentelemetry,
        :opentelemetry_api,
        :opentelemetry_ecto,
        :opentelemetry_phoenix,
        :logger_json,
        :telemetry
      ]

      dep_names =
        Enum.map(deps, fn
          {name, _} -> name
          {name, _, _} -> name
        end)

      for required_dep <- required_observability_deps do
        assert required_dep in dep_names,
               "Required observability dependency #{required_dep} not found in mix.exs"
      end
    end

    @tag timeout: 30_000
    test "OpenTelemetry configuration is valid" do
      # Verify OpenTelemetry configuration
      otel_config = Application.get_env(:opentelemetry, :tracer, %{})

      assert is_map(otel_config) or is_atom(otel_config),
             "OpenTelemetry tracer configuration invalid: #{inspect(otel_config)}"

      # Test basic tracing functionality
      require OpenTelemetry.Tracer

      OpenTelemetry.Tracer.with_span "test_span" do
        # Basic span functionality test
        OpenTelemetry.Tracer.set_attribute("test.attribute", "compilation_test")
      end
    end
  end

  ## PRIVATE HELPER FUNCTIONS

  defp compile_domain_with_timing(domain) do
    start_time = System.monotonic_time(:millisecond)

    try do
      case Code.ensure_loaded(domain) do
        {:module, ^domain} ->
          end_time = System.monotonic_time(:millisecond)

          %{
            domain: domain,
            status: :ok,
            compilation_time: end_time - start_time,
            error: nil
          }

        {:error, reason} ->
          %{
            domain: domain,
            status: :error,
            compilation_time: 0,
            error: reason
          }
      end
    rescue
      error ->
        %{
          domain: domain,
          status: :error,
          compilation_time: 0,
          error: error
        }
    end
  end

  defp domain_exists?(domain) do
    case Code.ensure_loaded(domain) do
      {:module, ^domain} -> true
      {:error, :nofile} -> false
      _ -> false
    end
  end

  defp discover_all_resources() do
    # Discover all modules that use Ash.Resource
    {:ok, modules} = :application.get_key(:intelitor, :modules)

    modules
    |> Enum.filter(fn module ->
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          try do
            function_exported?(module, :spark_dsl_config, 0) and
              function_exported?(module, :ash_dsl_config, 0)
          rescue
            _ -> false
          end

        _ ->
          false
      end
    end)
  end

  defp compile_and_validate_resource(resource) do
    try do
      case Code.ensure_loaded(resource) do
        {:module, ^resource} ->
          # Additional validation for Ash resources
          if function_exported?(resource, :spark_dsl_config, 0) do
            # Test that the resource has basic Ash structure
            _ = resource.__ash_info__(:resource)
            :ok
          else
            {:error, "Not a valid Ash resource"}
          end

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp run_compilation_with_warnings_capture() do
    CompilationUtilities.run_compilation_with_warnings_capture([
      "compile",
      "--warnings-as-errors",
      "--force"
    ])
  end

  defp extract_warnings_from_output(output) do
    CompilationUtilities.extract_warnings_from_output(output)
  end

  # Note: Warning parsing moved to CompilationUtilities shared module

  defp monitor_memory_during_compilation() do
    CompilationUtilities.monitor_memory_during_compilation(fn ->
      # Run a quick recompilation for memory monitoring
      {output, _exit_code} =
        System.cmd("mix", ["compile"],
          cd: System.cwd!(),
          stderr_to_stdout: true
        )

      output
    end)
  end

  # Alternative simpler implementation for test use
  defp simple_monitor_memory_during_compilation() do
    # Simple memory monitoring during a quick recompilation
    start_memory = :erlang.memory(:total)

    # Start a background process to sample memory
    parent = self()

    memory_monitor =
      spawn(fn ->
        memory_sampling_loop(parent, [start_memory])
      end)

    # Trigger compilation
    System.cmd("mix", ["compile"], cd: System.cwd!())

    # Stop monitoring and get results
    send(memory_monitor, :stop)

    receive do
      {:memory_samples, samples} -> samples
    after
      5000 -> [start_memory]
    end
  end

  defp memory_sampling_loop(parent, samples) do
    receive do
      :stop ->
        send(parent, {:memory_samples, Enum.reverse(samples)})
    after
      100 ->
        current_memory = :erlang.memory(:total)
        memory_sampling_loop(parent, [current_memory | samples])
    end
  end

  defp log_compilation_stats(domain_type, results) do
    successful = Enum.count(results, &(&1.status == :ok))
    failed = Enum.count(results, &(&1.status == :error))
    total_time = Enum.sum(Enum.map(results, & &1.compilation_time))

    IO.puts("""

    📊 #{domain_type} Compilation Statistics:
    ========================================
    ✅ Successful: #{successful}
    ❌ Failed: #{failed}
    🕐 Total time: #{total_time}ms
    📈 Average per domain: #{if length(results) > 0, do: Float.round(total_time / length(results), 2), else: 0}ms
    """)
  end

  defp perform_rca_on_failures(failures) do
    IO.puts("""

    🔍 5-LEVEL ROOT CAUSE ANALYSIS - COMPILATION FAILURES
    ====================================================
    """)

    for failure <- failures do
      IO.puts("""
      Resource: #{failure.resource}
      Error: #{inspect(failure.reason)}

      5-Level RCA:
      Level 1 (What): Resource #{failure.resource} failed to compile
      Level 2 (Why): #{analyze_failure_reason(failure.reason)}
      Level 3 (Why): #{analyze_underlying_cause(failure.reason)}
      Level 4 (Why): Development process allowed invalid code to be committed
      Level 5 (Why): Insufficient automated validation in development workflow

      Recommended Actions:
      - Fix immediate compilation error in #{failure.resource}
      - Add pre-commit hooks for compilation validation
      - Implement CI/CD pipeline with compilation gates
      - Regular dependency and API compatibility audits

      ----------------------------------------
      """)
    end
  end

  defp perform_rca_on_warnings(warnings) do
    IO.puts("""

    🔍 5-LEVEL ROOT CAUSE ANALYSIS - COMPILATION WARNINGS
    ====================================================
    """)

    warning_categories =
      warnings
      |> Enum.group_by(&categorize_warning/1)

    for {category, warning_list} <- warning_categories do
      IO.puts("""

      Warning Category: #{category}
      Count: #{length(warning_list)}

      5-Level RCA:
      Level 1 (What): #{length(warning_list)} #{category} warnings detected
      Level 2 (Why): #{analyze_warning_category(category)}
      Level 3 (Why): Code quality standards not enforced during development
      Level 4 (Why): Missing automated warning detection in development tools
      Level 5 (Why): Development workflow lacks comprehensive quality gates

      Sample warnings:
      #{warning_list |> Enum.take(3) |> Enum.map(&"  - #{&1.file}:#{&1.line} - #{&1.message}") |> Enum.join("\n")}

      Recommended Actions:
      - Fix all #{category} warnings immediately
      - Configure editor/IDE for real-time warning detection
      - Add warning-as-error configuration to development environment
      - Implement automated code quality checks in CI/CD

      ----------------------------------------
      """)
    end
  end

  defp analyze_failure_reason(reason) do
    case reason do
      :nofile -> "Module file not found - missing implementation"
      :badfile -> "Corrupted or invalid file format"
      %CompileError{} -> "Syntax or semantic compilation error"
      _ -> "Unknown compilation failure: #{inspect(reason)}"
    end
  end

  defp analyze_underlying_cause(reason) do
    case reason do
      :nofile -> "Missing file indicates incomplete feature implementation"
      :badfile -> "File corruption suggests development environment issues"
      %CompileError{} -> "Code quality issue - syntax or logic errors"
      _ -> "System-level issue __requiring investigation"
    end
  end

  defp categorize_warning(warning) do
    cond do
      String.contains?(warning.message, "unused") -> "unused_variables"
      String.contains?(warning.message, "deprecated") -> "deprecated_apis"
      String.contains?(warning.message, "regex") -> "regex_deprecation"
      String.contains?(warning.message, "variable") -> "variable_issues"
      true -> "other"
    end
  end

  defp analyze_warning_category(category) do
    case category do
      "unused_variables" -> "Variables declared but not used - code cleanup needed"
      "deprecated_apis" -> "Using deprecated APIs - modernization required"
      "regex_deprecation" -> "Regex syntax changes in OTP 28 - pattern updates needed"
      "variable_issues" -> "Variable naming or scoping problems"
      "other" -> "Miscellaneous code quality issues"
    end
  end
end
