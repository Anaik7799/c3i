defmodule Mix.Tasks.Test.Comprehensive do
  @moduledoc """
  Runs comprehensive test suite for all Indrajaal domains.

  This task runs the complete test suite including:
  - Unit tests for all domains
  - Integration tests
  - Security tests
  - Performance tests
  - Coverage analysis

  ## Usage

      mix test.comprehensive
      mix test.comprehensive --coverage
      mix test.comprehensive --performance
      mix test.comprehensive --security
  """

  use Mix.Task

  @shortdoc "Runs comprehensive test suite for all domains"

  @spec run(any()) :: any()
  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [
          coverage: :boolean,
          performance: :boolean,
          security: :boolean,
          verbose: :boolean,
          parallel: :boolean
        ]
      )

    Mix.shell().info("🧪 Starting Comprehensive Test Suite for Indrajaal Security Platform")
    Mix.shell().info("=" <> String.duplicate("=", 70))

    start_time = System.monotonic_time(:millisecond)

    # Prepare test environment
    prepare_test_environment()

    # Run tests based on options
    results = %{
      unit_tests: run_unit_tests(opts),
      integration_tests: run_integration_tests(opts),
      security_tests: if(opts[:security], do: run_security_tests(opts), else: :skipped),
      performance_tests: if(opts[:performance], do: run_performance_tests(opts), else: :skipped)
    }

    # Generate coverage report if __requested
    if opts[:coverage] do
      generate_coverage_report()
    end

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    # Print summary
    print_test_summary(results, duration)

    # Exit with appropriate status
    if all_tests_passed?(results) do
      Mix.shell().info("✅ All tests passed successfully!")
      System.halt(0)
    else
      Mix.shell().error("❌ Some tests failed!")
      System.halt(1)
    end
  end

  @spec prepare_test_environment() :: any()
  defp prepare_test_environment do
    Mix.shell().info("[FIX] Preparing test environment...")

    # Ensure test __database is ready
    Mix.Task.run("ecto.create", ["--quiet"])
    Mix.Task.run("ecto.migrate", ["--quiet"])

    # Generate any missing migrations
    Mix.Task.run("ash.gen.migrations", ["--name", "test_setup", "--check", "--quiet"])

    Mix.shell().info("✅ Test environment ready")
  end

  @spec run_unit_tests(term()) :: term()
  defp run_unit_tests(_opts) do
    Mix.shell().info("

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordinat
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
\n📋 Running Unit Tests...")
    Mix.shell().info("-" <> String.duplicate("-", 40))

    domains = [
      "core",
      "accounts",
      "policy",
      "sites",
      "devices",
      "alarms",
      "video",
      "dispatch",
      "maintenance",
      "compliance",
      "billing",
      "integrations"
    ]

    results =
      for domain <- domains do
        Mix.shell().info("Testing #{String.capitalize(domain)} domain...")

        test_files = "test / indrajaal/#{domain}/**/*_test.exs"

        case Mix.Task.run("test", [test_files, "--color"]) do
          :ok -> {domain, :passed}
          _ -> {domain, :failed}
        end
      end

    passed = Enum.count(results, fn {_, status} -> status == :passed end)
    total = length(results)

    Mix.shell().info("[STATS] Unit Tests: #{passed}/#{total} domains passed")

    %{passed: passed, total: total, details: results}
  end

  @spec run_integration_tests(term()) :: term()
  defp run_integration_tests(_opts) do
    Mix.shell().info("\n🔗 Running Integration Tests...")
    Mix.shell().info("-" <> String.duplicate("-", 40))

    test_files = [
      "test / integration/**/*_test.exs",
      "test / indrajaal_web/**/*_test.exs"
    ]

    results =
      for test_file <- test_files do
        case Mix.Task.run("test", [test_file, "--color"]) do
          :ok -> :passed
          _ -> :failed
        end
      end

    passed = Enum.count(results, &(&1 == :passed))
    total = length(results)

    Mix.shell().info("[STATS] Integration Tests: #{passed}/#{total} test suites passed")

    %{passed: passed, total: total}
  end

  @spec run_security_tests(term()) :: term()
  defp run_security_tests(_opts) do
    Mix.shell().info("\n🔐 Running Security Tests...")
    Mix.shell().info("-" <> String.duplicate("-", 40))

    # Run authentication tests
    auth_result = Mix.Task.run("test", ["test / indrajaal / auth/**/*_test.exs", "--color"])

    # Run security - specific tests
    security_result = Mix.Task.run("test", ["test / security/**/*_test.exs", "--color"])

    # Run tenant isolation tests
    isolation_tests = [
      "test / integration / domain_integration_test.exs:multi - tenant __data isolation",
      "test / integration / domain_integration_test.exs:policy - based access control"
    ]

    isolation_result = Mix.Task.run("test", isolation_tests ++ ["--color"])

    results = [auth_result, security_result, isolation_result]
    passed = Enum.count(results, &(&1 == :ok))
    total = length(results)

    Mix.shell().info("[STATS] Security Tests: #{passed}/#{total} test categories passed")

    %{passed: passed, total: total}
  end

  @spec run_performance_tests(term()) :: term()
  defp run_performance_tests(_opts) do
    Mix.shell().info("\n⚡ Running Performance Tests...")
    Mix.shell().info("-" <> String.duplicate("-", 40))

    # Performance tests would include:
    # - Database query performance
    # - Concurrent user simulation
    # - Memory usage tests
    # - Response time validation
    result = Mix.Task.run("test", ["test / performance/**/*_test.exs", "--color"])

    case result do
      :ok ->
        Mix.shell().info("[STATS] Performance Tests: All benchmarks within acceptable limits")
        %{passed: 1, total: 1}

      _ ->
        Mix.shell().info("[STATS] Performance Tests: Some benchmarks failed")
        %{passed: 0, total: 1}
    end
  end

  @spec generate_coverage_report() :: any()
  defp generate_coverage_report do
    Mix.shell().info("\n📈 Generating Coverage Report...")
    Mix.shell().info("-" <> String.duplicate("-", 40))

    Mix.Task.run("test.coverage", ["--html"])

    Mix.shell().info("[STATS] Coverage report generated in cover/ directory")
  end

  @spec print_test_summary(term(), term()) :: term()
  defp print_test_summary(results, duration_ms) do
    Mix.shell().info("\n" <> "=" <> String.duplicate("=", 70))
    Mix.shell().info("[STATS] COMPREHENSIVE TEST SUMMARY")
    Mix.shell().info("=" <> String.duplicate("=", 70))

    # Unit tests summary
    unit = results.unit_tests
    Mix.shell().info("📋 Unit Tests:       #{unit.passed}/#{unit.total} domains passed")

    # Integration tests summary
    integration = results.integration_tests

    Mix.shell().info(
      "🔗 Integration Tests: #{integration.passed}/#{integration.total} suites passed"
    )

    # Security tests summary
    case results.security_tests do
      :skipped ->
        Mix.shell().info("🔐 Security Tests:   SKIPPED (use --security flag)")

      security ->
        Mix.shell().info(
          "🔐 Security Tests:   #{security.passed}/#{security.total} categories passed"
        )
    end

    # Performance tests summary
    case results.performance_tests do
      :skipped ->
        Mix.shell().info("⚡ Performance Tests: SKIPPED (use --performance flag)")

      performance ->
        Mix.shell().info(
          "⚡ Performance Tests: #{performance.passed}/#{performance.total} benchmarks passed"
        )
    end

    # Timing
    duration_seconds = duration_ms / 1000
    Mix.shell().info("\n⏱️  Total Duration: #{Float.round(duration_seconds, 2)} seconds")

    # Domain - specific results
    if unit.details do
      Mix.shell().info("\n📝 Domain Test Results:")

      for {domain, status} <- unit.details do
        icon = if status == :passed, do: "✅", else: "❌"
        Mix.shell().info("   #{icon} #{String.capitalize(domain)}")
      end
    end

    Mix.shell().info("\n" <> "=" <> String.duplicate("=", 70))
  end

  @spec all_tests_passed?(term()) :: term()
  defp all_tests_passed?(results) do
    unit_passed = results.unit_tests.passed == results.unit_tests.total
    integration_passed = results.integration_tests.passed == results.integration_tests.total

    security_passed =
      case results.security_tests do
        :skipped -> true
        security -> security.passed == security.total
      end

    performance_passed =
      case results.performance_tests do
        :skipped -> true
        performance -> performance.passed == performance.total
      end

    unit_passed && integration_passed && security_passed && performance_passed
  end
end
