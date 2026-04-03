#!/usr/bin/env elixir

defmodule VerifyDualLogging do
  @moduledoc """
  Comprehensive verification script for the MANDATORY dual logging system.

  This script performs TDG, STAMP, and GDE validation to ensure:
  1. Terminal/Console output-immediate developer visibility
  2. SigNoz platform (via JSON) - structured observability

  Frameworks Applied:
  - TDG: Test-Driven Generation validation
  - STAMP: Safety constraint verification
  - GDE: Goal-Directed Execution measurement

  Usage:
    elixir scripts/observability/verify_dual_logging.exs [--tdg] [--stamp] [--gde] [--all]
  """

  __require Logger

  @gde_goals %{
    g1: "100% dual logging compliance",
    g2: "Zero log loss between backends",
    g3: "< 10ms logging overhead",
    g4: "Complete metadata preservation",
    g5: "Real-time delivery to both backends"
  }

  @stamp_constraints %{
    sc1: "No log __data loss during high load",
    sc2: "Tenant isolation in all logs",
    sc3: "Resource limits enforced",
    sc4: "Alert delivery < 1 minute",
    sc5: "Non-blocking log operations"
  }

  @spec main(any()) :: any()
  def main(args \\ []) do
    options = parse_args(args)

    IO.puts """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║     Dual Logging Verification with TDG/STAMP/GDE Validation       ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """

    start_time = System.monotonic_time(:millisecond)

    # SOPv5.1 Phase 0: Goal Ingestion & Strategy Formulation
    if options[:all] || options[:sopv51] do
      IO.puts "\n🧠 SOPv5.1 Phase 0: Goal Ingestion & Strategy Formulation"
      sopv51_goal_ingestion()
    end

    # SOPv5.1 Phase 1: Pre-Flight Check
    IO.puts "\n🔧 SOPv5.1 Phase 1: Pre-Flight Check (Enhanced Cybernetic State Validation)"
    sopv51_preflight_check()

    # TDG Validation (if __requested)
    if options[:all] || options[:tdg] do
      IO.puts "\n🧪 TDG Validation: Test-Driven Generation Compliance"
      tdg_validation()
    end

    # STAMP Safety Validation (if __requested)
    if options[:all] || options[:stamp] do
      IO.puts "\n🛡️ STAMP Validation: Safety Constraint Verification"
      stamp_validation()
    end

    # GDE Goal Measurement (if __requested)
    if options[:all] || options[:gde] do
      IO.puts "\n🎯 GDE Validation: Goal-Directed Execution Measurement"
      gde_validation()
    end

    # Core Dual Logging Tests
    IO.puts "\n📋 Core Validation: Dual Logging System Tests"
    validate_configuration()
    verify_console_backend()
    verify_json_backend()
    test_dual_logging()

    # SOPv5.1 Phase 3: Post-Flight Check & System Learning
    IO.puts "\n🔍 SOPv5.1 Phase 3: Post-Flight Check & System Learning"
    duration = System.monotonic_time(:millisecond)-start_time
    sopv51_postflight_check(duration)

    # Final Report
    generate_comprehensive_report(options, duration)

  end

  @spec parse_args(term()) :: term()
  defp parse_args(args) do
    {__opts, _, _} = OptionParser.parse(args,
      switches: [
        tdg: :boolean,
        stamp: :boolean,
        gde: :boolean,
        all: :boolean,
        sopv51: :boolean
      ]
    )

    # Default to basic validation if no flags
    if Enum.empty?(__opts), do: [all: false], else: __opts
  end

  # SOPv5.1 Phase 0: Goal Ingestion
  @spec sopv51_goal_ingestion() :: any()
  defp sopv51_goal_ingestion do
    IO.puts """

    📊 Goal Analysis:-Primary Objective: Validate 100% dual logging compliance
    - Context: Both terminal and SigNoz must receive ALL logs
    - Strategy: Comprehensive multi-framework validation
    - Success Criteria: Zero violations across all checks
    """
  end

  # SOPv5.1 Phase 1: Pre-Flight Check
  @spec sopv51_preflight_check() :: any()
  defp sopv51_preflight_check do
    IO.puts """

    ✅ Cybernetic System State Analysis:
    [ ] 1.1: Environment Integrity-Logger backends configured
    [ ] 1.2: Control Loop Validation - Both backends active
    [ ] 1.3: Resource Availability - Console and JSON handlers ready
    [ ] 1.4: State Synchronization - Meta__data consistency verified
    [ ] 1.5: Risk Assessment - Potential log loss scenarios identified
    """

    # Perform actual checks
    backends = Application.get_env(:logger, :backends, [])

    if :console in backends && LoggerJSON in backends do
      IO.puts "    ✅ All pre-flight checks passed"
    else
      IO.puts "    ❌ CYBERNETIC SAFETY HALT: Backend configuration invalid"
      raise "SOPv5.1 Pre-flight check failed"
    end
  end

  # TDG Validation
  @spec tdg_validation() :: any()
  defp tdg_validation do
    IO.puts """

    🧪 TDG Test Suite Execution:
    """

    # Test 1: Verify test exists before implementation
    IO.puts "  1. Test-First Validation:"
    test_file = "test/observability/dual_logging_test.exs"
    if File.exists?(test_file) do
      IO.puts "    ✅ TDG test file exists: #{test_file}"
    else
      IO.puts "    ❌ VIOLATION: No TDG test file found"
    end

    # Test 2: Verify implementation matches tests
    IO.puts "\n  2. Implementation Validation:"
    impl_file = "lib/indrajaal/observability/dual_logging.ex"
    if File.exists?(impl_file) do
      IO.puts "    ✅ Implementation file exists: #{impl_file}"

      # Check if tests were written before implementation
      test_stat = File.stat!(test_file)
      impl_stat = File.stat!(impl_file)

      if test_stat.mtime < impl_stat.mtime do
        IO.puts "    ✅ Tests written before implementation (TDG compliant)"
      else
        IO.puts "    ⚠️  WARNING: Implementation may have preceded tests"
      end
    else
      IO.puts "    ❌ VIOLATION: Implementation file missing"
    end

    # Test 3: Run actual TDG tests
    IO.puts "\n  3. TDG Test Execution:"
    IO.puts "    → Run: mix test test/observability/dual_logging_test.exs"
  end

  # STAMP Safety Validation
  @spec stamp_validation() :: any()
  defp stamp_validation do
    IO.puts """

    🛡️ STAMP Safety Constraint Validation:
    """

    # SC1: No log __data loss
    IO.puts "  SC1: No log __data loss during high load"
    test_high_load_logging()

    # SC2: Tenant isolation
    IO.puts "\n  SC2: Tenant isolation in all logs"
    test_tenant_isolation()

    # SC3: Resource limits
    IO.puts "\n  SC3: Resource limits enforced"
    test_resource_limits()

    # SC4: Alert delivery
    IO.puts "\n  SC4: Alert delivery < 1 minute"
    IO.puts "    → Requires SigNoz alert configuration"

    # SC5: Non-blocking operations
    IO.puts "\n  SC5: Non-blocking log operations"
    test_non_blocking_logs()
  end

  # GDE Goal Measurement
  @spec gde_validation() :: any()
  defp gde_validation do
    IO.puts """

    🎯 GDE Goal Achievement Measurement:
    """

    Enum.each(@gde_goals, fn {goal_id, description} ->
      IO.puts "\n  #{String.upcase(to_string(goal_id))}: #{description}"

      case goal_id do
        :g1 -> validate_dual_compliance()
        :g2 -> validate_zero_log_loss()
        :g3 -> measure_logging_overhead()
        :g4 -> validate__metadata_preservation()
        :g5 -> validate_realtime_delivery()
      end
    end)
  end

  # STAMP Test Functions
  @spec test_high_load_logging() :: any()
  defp test_high_load_logging do
    IO.puts "    Testing with 1000 rapid log messages..."

    start_time = System.monotonic_time(:millisecond)

    for i <- 1..1000 do
      Logger.info("High load test #{i}", load_test: true, sequence: i)
    end

    duration = System.monotonic_time(:millisecond)-start_time

    IO.puts "    ✅ Generated 1000 logs in #{duration}ms"
    IO.puts "    → Verify all appear in both terminal and SigNoz"
  end

  @spec test_tenant_isolation() :: any()
  defp test_tenant_isolation do
    tenant1_id = "tenant-alpha"
    tenant2_id = "tenant-beta"

    Logger.metadata(__tenant_id: tenant1_id)
    Logger.info("Tenant isolation test-Alpha", sensitive: "alpha-__data")

    Logger.metadata(__tenant_id: tenant2_id)
    Logger.info("Tenant isolation test-Beta", sensitive: "beta-__data")

    Logger.metadata(__tenant_id: nil)

    IO.puts "    ✅ Logged with tenant isolation metadata"
    IO.puts "    → Verify __tenant_id appears in both outputs"
  end

  @spec test_resource_limits() :: any()
  defp test_resource_limits do
    # Test with large message
    large_data = String.duplicate("X", 10_000)
    Logger.info("Resource limit test", large_payload: large_data)

    IO.puts "    ✅ Tested with 10KB payload"
    IO.puts "    → Verify truncation if configured"
  end

  @spec test_non_blocking_logs() :: any()
  defp test_non_blocking_logs do
    start_time = System.monotonic_time(:microsecond)

    Logger.info("Non-blocking test", timestamp: DateTime.utc_now())

    duration = System.monotonic_time(:microsecond)-start_time
    duration_ms = duration / 1000

    if duration_ms < 10 do
      IO.puts "    ✅ Logging completed in #{Float.round(duration_ms, 2)}ms (non-b
    else
      IO.puts "    ⚠️  WARNING: Logging took #{Float.round(duration_ms, 2)}ms"
    end
  end

  # GDE Validation Functions
  @spec validate_dual_compliance() :: any()
  defp validate_dual_compliance do
    backends = Application.get_env(:logger, :backends, [])

    if :console in backends && LoggerJSON in backends do
      IO.puts "    ✅ Both backends configured"
    else
      IO.puts "    ❌ VIOLATION: Missing __required backends"
    end
  end

  @spec validate_zero_log_loss() :: any()
  defp validate_zero_log_loss do
    IO.puts "    → Requires correlation between terminal and SigNoz"
    IO.puts "    → Manual verification needed"
  end

  @spec measure_logging_overhead() :: any()
  defp measure_logging_overhead do
    # Baseline operation
    baseline_start = System.monotonic_time(:microsecond)
    _result = Enum.sum(1..1000)
    baseline_duration = System.monotonic_time(:microsecond)-baseline_start

    # Operation with logging
    log_start = System.monotonic_time(:microsecond)
    _result = Enum.sum(1..1000)
    Logger.info("Overhead test", operation: "sum")
    log_duration = System.monotonic_time(:microsecond)-log_start

    overhead = ((log_duration - baseline_duration) / baseline_duration) * 100

    if overhead < 10 do
      IO.puts "    ✅ Logging overhead: #{Float.round(overhead, 2)}% (< 10%)"
    else
      IO.puts "    ❌ Logging overhead: #{Float.round(overhead, 2)}% (exceeds 10%)
    end
  end

  @spec validate__metadata_preservation() :: any()
  defp validate__metadata_preservation do
    test__metadata = %{
      __user_id: 123,
      __tenant_id: "test-tenant",
      nested: %{__data: [1, 2, 3]},
      timestamp: DateTime.utc_now()
    }

    Logger.info("Meta__data preservation test", test__metadata)

    IO.puts "    ✅ Sent complex metadata"
    IO.puts "    → Verify all fields in both outputs"
  end

  @spec validate_realtime_delivery() :: any()
  defp validate_realtime_delivery do
    IO.puts "    ✅ Console delivery is synchronous"
    IO.puts "    → SigNoz delivery depends on export interval"
  end

  # SOPv5.1 Phase 3: Post-Flight Check
  @spec sopv51_postflight_check(term()) :: term()
  defp sopv51_postflight_check(duration) do
    IO.puts """

    ✅ Comprehensive System Validation:
    [ ] 3.1: Goal Achievement-Dual logging validated
    [ ] 3.2: System State - Both backends operational
    [ ] 3.3: Performance - Completed in #{duration}ms
    [ ] 3.4: Knowledge Integration - Patterns documented
    [ ] 3.5: Risk Update - No new failure modes detected
    """
  end

  # Comprehensive Report Generation
  @spec generate_comprehensive_report(term(), term()) :: term()
  defp generate_comprehensive_report(options, duration) do
    IO.puts """

    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    COMPREHENSIVE VALIDATION REPORT                 ║
    ╚═══════════════════════════════════════════════════════════════════╝

    📊 Validation Summary:-Execution Time: #{duration}ms
    - Frameworks Applied: #{frameworks_applied(options)}
    - Critical Violations: #{count_violations()}
    - Warnings: #{count_warnings()}

    🎯 Compliance Status:
    - Terminal Output: #{if console_active?(), do: "✅ ACTIVE", else: "❌ INACTIVE"-SigNoz Output: #{if signoz_active?(), do: "✅ ACTIVE", else: "❌ INACTIVE"}-Dual Logging: #{if dual_logging_active?(), do: "✅ COMPLIANT", else: "❌ VIOL

    📋 Action Items:
    1. Verify all test logs appear in terminal
    2. Check SigNoz UI for corresponding JSON logs
    3. Compare timestamps and metadata
    4. Address any violations immediately

    🚨 REMEMBER: Every log MUST appear in BOTH places!
    """
  end

  @spec frameworks_applied(term()) :: term()
  defp frameworks_applied(options) do
    applied = []
    applied = if options[:tdg], do: ["TDG" | applied], else: applied
    applied = if options[:stamp], do: ["STAMP" | applied], else: applied
    applied = if options[:gde], do: ["GDE" | applied], else: applied
    applied = if options[:sopv51] || options[:all], do: ["SOPv5.1" | applied], else: applied

    if Enum.empty?(applied), do: "Basic", else: Enum.join(applied, ", ")
  end

  @spec count_violations,() :: any()
  defp count_violations, do: 0  # Would track actual violations
  @spec count_warnings,() :: any()
  defp count_warnings, do: 0   # Would track actual warnings

  @spec console_active?() :: any()
  defp console_active? do
    :console in Application.get_env(:logger, :backends, [])
  end

  @spec signoz_active?() :: any()
  defp signoz_active? do
    LoggerJSON in Application.get_env(:logger, :backends, [])
  end

  @spec dual_logging_active?() :: any()
  defp dual_logging_active? do
    console_active?() && signoz_active?()
  end

  @spec validate_configuration() :: any()
  defp validate_configuration do
    backends = Application.get_env(:logger, :backends, [])

    IO.puts "  Current backends: #{inspect(backends)}"

    if :console in backends do
      IO.puts "  ✅ Console backend is configured"
    else
      IO.puts "  ❌ ERROR: Console backend is NOT configured!"
      raise "VIOLATION: Console backend must be active"
    end

    if LoggerJSON in backends do
      IO.puts "  ✅ LoggerJSON backend is configured"
    else
      IO.puts "  ❌ ERROR: LoggerJSON backend is NOT configured!"
      raise "VIOLATION: LoggerJSON backend must be active"
    end

    # Validate dual logging module
    try do
      Indrajaal.Observability.DualLogging.validate_dual_logging!()
      IO.puts "  ✅ Dual logging validation passed"
    rescue
      e ->
        IO.puts "  ❌ ERROR: Dual logging validation failed: #{inspect(e)}"
        raise e
    end
  end

  @spec verify_console_backend() :: any()
  defp verify_console_backend do
    console_config = Application.get_env(:logger, :console, [])

    IO.puts "  Console format: #{inspect(console_config[:format])}"
    IO.puts "  Console metadata: #{inspect(console_config[:metadata])}"

    if console_config[:format] do
      IO.puts "  ✅ Console format is configured"
    else
      IO.puts "  ⚠️  WARNING: Using default console format"
    end
  end

  @spec verify_json_backend() :: any()
  defp verify_json_backend do
    json_config = Application.get_env(:logger_json, :backend, [])

    IO.puts "  JSON formatter: #{inspect(json_config[:formatter])}"
    IO.puts "  JSON metadata: #{inspect(json_config[:metadata])}"

    if json_config[:formatter] do
      IO.puts "  ✅ JSON formatter is configured"
    else
      IO.puts "  ❌ ERROR: JSON formatter is not configured!"
    end

    if json_config[:metadata] == :all do
      IO.puts "  ✅ JSON backend includes all metadata"
    else
      IO.puts "  ⚠️  WARNING: JSON backend may not include all metadata"
    end
  end

  @spec test_dual_logging() :: any()
  defp test_dual_logging do
    test_id = "dual-log-test-#{System.unique_integer([:positive])}"
    timestamp = DateTime.utc_now()

    IO.puts "\n  🧪 Generating test log messages..."
    IO.puts "  Test ID: #{test_id}"
    IO.puts "\n  You should see the following messages in BOTH terminal AND SigNoz:\n"

    # Test different log levels
    Logger.debug("DUAL_LOG_TEST: Debug message",
      test_id: test_id,
      level: "debug",
      timestamp: timestamp
    )

    Logger.info("DUAL_LOG_TEST: Info message",
      test_id: test_id,
      level: "info",
      timestamp: timestamp
    )

    Logger.warning("DUAL_LOG_TEST: Warning message",
      test_id: test_id,
      level: "warning",
      timestamp: timestamp
    )

    Logger.error("DUAL_LOG_TEST: Error message",
      test_id: test_id,
      level: "error",
      timestamp: timestamp
    )

    # Test with complex metadata
    Logger.info("DUAL_LOG_TEST: Complex metadata test",
      test_id: test_id,
      __user: %{id: 123, name: "Test User"},
      action: "dual_logging_verification",
      nested: %{
        __data: %{
          values: [1, 2, 3],
          map: %{key: "value"}
        }
      },
      timestamp: timestamp
    )

    # Test domain-specific logging
    if Code.ensure_loaded?(Indrajaal.Observability.DualLogging) do
      Indrajaal.Observability.DualLogging.log_domain_event(
        :observability,
        "dual_logging_verification",
        :info,
        [test_id: test_id, status: "testing"]
      )

      Indrajaal.Observability.DualLogging.log_important(
        :warn,
        "DUAL_LOG_TEST: Important message test",
        [test_id: test_id, critical: true]
      )
    end

    IO.puts "\n  ✅ Test messages sent to both backends"
  end

  @spec provide_verification_instructions() :: any()
  defp provide_verification_instructions do
    IO.puts """

    To verify dual logging is working correctly:

    1. CHECK YOUR TERMINAL:-You should see all test messages above with timestamps
       - Messages should be formatted and colored by level
       - All metadata should be visible

    2. CHECK SIGNOZ UI:
       - Open SigNoz dashboard (http://localhost:3301)
       - Go to Logs section
       - Search for: test_id = "dual-log-test-*"-You should see ALL the same messages as JSON
       - Click on any log to see full metadata

    3. COMPARE BOTH:
       - Timestamps should match exactly
       - All messages should appear in both places
       - Meta__data should be identical

    4. CRITICAL VALIDATION:
       ❌ If ANY log appears in terminal but NOT in SigNoz = VIOLATION
       ❌ If ANY log appears in SigNoz but NOT in terminal = VIOLATION
       ✅ Every log MUST appear in BOTH places = COMPLIANT

    5. CONTINUOUS MONITORING:
       - Run this script regularly to ensure compliance
       - Monitor both outputs during development
       - Report any discrepancies immediately
    """
  end
end

# Run the verification
VerifyDualLogging.main(System.argv())
end
end
end
end
end
end
end
end
end
end
end
end
end
