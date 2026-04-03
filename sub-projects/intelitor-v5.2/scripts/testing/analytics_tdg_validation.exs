#!/usr/bin/env elixir

# SOPv5.11 Analytics TDG Test Structure Validation Engine
# Framework: TDG (Test-Driven Generation) + STAMP + Property-Based Testing
# Purpose: Comprehensive validation of analytics module test coverage and TDG compliance

Mix.install([{:jason, "~> 1.4"}])

defmodule AnalyticsTDGValidation do
  @moduledoc """
  SOPv5.11 Analytics TDG Test Structure Validation Engine

  Validates Test-Driven Generation compliance for all analytics modules:
  1. TDG Test Structure Validation
  2. Property-Based Test Framework Setup
  3. STAMP Safety Constraint Implementation
  4. Comprehensive Coverage Analysis
  """

  require Logger

  @analytics_dir "lib/indrajaal/analytics"
  @test_dir "test"
  @log_file "./data/tmp/analytics-tdg-validation-#{DateTime.utc_now() |> DateTime.to_string() |> String.replace(~r/[:\s]/, "-") |> String.replace(".", "-")}.log"

  def main(args \\ []) do
    Logger.info("🧪 SOPv5.11 Analytics TDG Validation Engine Starting")

    case args do
      ["--validate"] -> validate_tdg_structure()
      ["--coverage"] -> analyze_test_coverage()
      ["--property-tests"] -> validate_property_tests()
      ["--stamp-constraints"] -> validate_stamp_constraints()
      ["--comprehensive"] -> run_comprehensive_validation()
      _ -> show_help()
    end
  end

  def run_comprehensive_validation do
    Logger.info("🚀 Running Comprehensive Analytics TDG Validation")

    results = %{
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      analytics_modules: discover_analytics_modules(),
      test_coverage: analyze_test_coverage(),
      property_tests: validate_property_tests(),
      stamp_constraints: validate_stamp_constraints(),
      tdg_compliance: validate_tdg_structure()
    }

    save_validation_report(results)
    display_validation_summary(results)

    results
  end

  def discover_analytics_modules do
    Logger.info("📂 Discovering Analytics Modules")

    analytics_files = File.ls!(@analytics_dir)
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
    |> Enum.reject(&String.starts_with?(&1, "."))

    subdirs = File.ls!(@analytics_dir)
    |> Enum.filter(fn file ->
      File.dir?(Path.join(@analytics_dir, file))
    end)

    subdir_files = Enum.flat_map(subdirs, fn subdir ->
      subdir_path = Path.join(@analytics_dir, subdir)
      if File.exists?(subdir_path) do
        File.ls!(subdir_path)
        |> Enum.filter(&String.ends_with?(&1, ".ex"))
        |> Enum.map(&Path.join(subdir, &1))
      else
        []
      end
    end)

    all_modules = analytics_files ++ subdir_files

    Logger.info("📊 Found #{length(all_modules)} analytics modules")

    %{
      total_modules: length(all_modules),
      root_modules: analytics_files,
      subdir_modules: subdir_files,
      all_modules: all_modules
    }
  end

  def analyze_test_coverage do
    Logger.info("🔍 Analyzing Test Coverage for Analytics Modules")

    test_files = find_analytics_tests()
    analytics_modules = discover_analytics_modules().all_modules

    coverage_analysis = Enum.map(analytics_modules, fn module ->
      module_name = Path.basename(module, ".ex")
      test_file = find_matching_test(module_name, test_files)

      %{
        module: module,
        module_name: module_name,
        has_test: test_file != nil,
        test_file: test_file,
        tdg_compliant: check_tdg_compliance(test_file)
      }
    end)

    covered_modules = Enum.count(coverage_analysis, & &1.has_test)
    tdg_compliant_modules = Enum.count(coverage_analysis, & &1.tdg_compliant)

    Logger.info("📈 Test Coverage: #{covered_modules}/#{length(analytics_modules)} modules (#{Float.round(covered_modules / length(analytics_modules) * 100, 1)}%)")
    Logger.info("🧪 TDG Compliance: #{tdg_compliant_modules}/#{length(analytics_modules)} modules (#{Float.round(tdg_compliant_modules / length(analytics_modules) * 100, 1)}%)")

    %{
      total_modules: length(analytics_modules),
      covered_modules: covered_modules,
      coverage_percentage: Float.round(covered_modules / length(analytics_modules) * 100, 1),
      tdg_compliant_modules: tdg_compliant_modules,
      tdg_compliance_percentage: Float.round(tdg_compliant_modules / length(analytics_modules) * 100, 1),
      uncovered_modules: Enum.filter(coverage_analysis, &(not &1.has_test)),
      coverage_analysis: coverage_analysis
    }
  end

  def validate_property_tests do
    Logger.info("🎲 Validating Property-Based Testing Framework")

    property_test_files = find_property_tests()

    property_analysis = Enum.map(property_test_files, fn test_file ->
      content = File.read!(test_file)

      %{
        file: test_file,
        has_propcheck: String.contains?(content, "use PropCheck"),
        has_exunit_properties: String.contains?(content, "use ExUnitProperties"),
        dual_framework: String.contains?(content, "use PropCheck") and String.contains?(content, "use ExUnitProperties"),
        property_count: count_properties(content)
      }
    end)

    dual_framework_count = Enum.count(property_analysis, & &1.dual_framework)

    Logger.info("🎲 Property Test Files: #{length(property_test_files)}")
    Logger.info("🔄 Dual Framework (PropCheck + ExUnitProperties): #{dual_framework_count}/#{length(property_test_files)}")

    %{
      total_property_files: length(property_test_files),
      dual_framework_count: dual_framework_count,
      dual_framework_percentage: if(length(property_test_files) > 0, do: Float.round(dual_framework_count / length(property_test_files) * 100, 1), else: 0),
      property_analysis: property_analysis
    }
  end

  def validate_stamp_constraints do
    Logger.info("🛡️ Validating STAMP Safety Constraints for Analytics")

    # STAMP Safety Constraints for Analytics (SC-ANALYTICS-001 to SC-ANALYTICS-005)
    constraints = [
      %{id: "SC-ANALYTICS-001", description: "System SHALL maintain data integrity during analytics processing", status: :pending},
      %{id: "SC-ANALYTICS-002", description: "System SHALL complete analytics computations within defined timeouts", status: :pending},
      %{id: "SC-ANALYTICS-003", description: "System SHALL validate input data before processing", status: :pending},
      %{id: "SC-ANALYTICS-004", description: "System SHALL handle analytics failures gracefully without data loss", status: :pending},
      %{id: "SC-ANALYTICS-005", description: "System SHALL maintain analytics result consistency across sessions", status: :pending}
    ]

    # Check for STAMP constraint tests
    stamp_test_files = find_stamp_constraint_tests()

    Logger.info("🛡️ STAMP Constraint Test Files: #{length(stamp_test_files)}")

    %{
      constraints: constraints,
      stamp_test_files: stamp_test_files,
      constraint_coverage: length(stamp_test_files)
    }
  end

  def validate_tdg_structure do
    Logger.info("🧪 Validating TDG (Test-Driven Generation) Structure")

    test_categories = [
      "Unit Tests",
      "Integration Tests",
      "End-to-End Tests",
      "Error Scenario Tests",
      "Performance Tests",
      "Property-Based Tests"
    ]

    category_analysis = Enum.map(test_categories, fn category ->
      test_files = find_tests_by_category(category)

      %{
        category: category,
        file_count: length(test_files),
        files: test_files
      }
    end)

    Logger.info("🧪 TDG Test Categories Analysis:")
    Enum.each(category_analysis, fn analysis ->
      Logger.info("  #{analysis.category}: #{analysis.file_count} files")
    end)

    %{
      test_categories: test_categories,
      category_analysis: category_analysis,
      total_test_files: Enum.sum(Enum.map(category_analysis, & &1.file_count))
    }
  end

  # Helper Functions

  defp find_analytics_tests do
    Path.wildcard("test/**/*analytics*test.exs") ++
    Path.wildcard("test/**/analytics/**/*test.exs")
  end

  defp find_property_tests do
    Path.wildcard("test/**/*property*test.exs") ++
    Path.wildcard("test/**/*analytics*property*.exs")
  end

  defp find_stamp_constraint_tests do
    Path.wildcard("test/**/*stamp*test.exs") ++
    Path.wildcard("test/**/*safety*test.exs") ++
    Path.wildcard("test/**/*constraint*test.exs")
  end

  defp find_tests_by_category("Unit Tests"), do: Path.wildcard("test/indrajaal/analytics/*_test.exs")
  defp find_tests_by_category("Integration Tests"), do: Path.wildcard("test/integration/analytics/*_test.exs")
  defp find_tests_by_category("End-to-End Tests"), do: Path.wildcard("test/e2e/analytics/*_test.exs")
  defp find_tests_by_category("Error Scenario Tests"), do: Path.wildcard("test/**/analytics/*error*test.exs")
  defp find_tests_by_category("Performance Tests"), do: Path.wildcard("test/**/analytics/*performance*test.exs")
  defp find_tests_by_category("Property-Based Tests"), do: find_property_tests()

  defp find_matching_test(module_name, test_files) do
    Enum.find(test_files, fn test_file ->
      test_basename = Path.basename(test_file, "_test.exs")
      String.contains?(test_basename, module_name) or String.contains?(test_file, module_name)
    end)
  end

  defp check_tdg_compliance(nil), do: false
  defp check_tdg_compliance(test_file) do
    if File.exists?(test_file) do
      content = File.read!(test_file)
      # Check for TDG indicators: comprehensive test structure, property tests, etc.
      String.contains?(content, "describe") and
      String.contains?(content, "test") and
      (String.contains?(content, "property") or String.contains?(content, "PropCheck"))
    else
      false
    end
  end

  defp count_properties(content) do
    property_patterns = [
      ~r/property\s+"/,
      ~r/check\s+all/,
      ~r/forall\s+/
    ]

    Enum.sum(Enum.map(property_patterns, fn pattern ->
      length(Regex.scan(pattern, content))
    end))
  end

  defp save_validation_report(results) do
    report_content = """
    # SOPv5.11 Analytics TDG Validation Report

    **Generated**: #{results.timestamp}
    **Framework**: SOPv5.11 + TDG + STAMP + Property-Based Testing

    ## Summary

    - **Total Analytics Modules**: #{results.analytics_modules.total_modules}
    - **Test Coverage**: #{results.test_coverage.coverage_percentage}% (#{results.test_coverage.covered_modules}/#{results.test_coverage.total_modules})
    - **TDG Compliance**: #{results.test_coverage.tdg_compliance_percentage}% (#{results.test_coverage.tdg_compliant_modules}/#{results.test_coverage.total_modules})
    - **Property Test Dual Framework**: #{results.property_tests.dual_framework_percentage}% (#{results.property_tests.dual_framework_count}/#{results.property_tests.total_property_files})
    - **STAMP Constraint Coverage**: #{results.stamp_constraints.constraint_coverage} test files

    ## Detailed Analysis

    #{Jason.encode!(results, pretty: true)}
    """

    File.write!(@log_file, report_content)
    Logger.info("📄 Validation report saved to: #{@log_file}")
  end

  defp display_validation_summary(results) do
    IO.puts("""

    🏆 SOPv5.11 Analytics TDG Validation Summary
    ============================================

    📊 Analytics Modules: #{results.analytics_modules.total_modules}
    📈 Test Coverage: #{results.test_coverage.coverage_percentage}%
    🧪 TDG Compliance: #{results.test_coverage.tdg_compliance_percentage}%
    🎲 Property Tests: #{results.property_tests.dual_framework_count} dual framework files
    🛡️ STAMP Constraints: #{length(results.stamp_constraints.constraints)} defined

    📋 Next Steps:
    1. Achieve 100% test coverage for all analytics modules
    2. Implement dual property-based testing (PropCheck + ExUnitProperties)
    3. Create STAMP safety constraint tests
    4. Ensure all tests follow TDG methodology

    """)
  end

  defp show_help do
    IO.puts("""
    SOPv5.11 Analytics TDG Validation Engine

    Usage:
      elixir #{__ENV__.file} [options]

    Options:
      --validate        Validate TDG structure
      --coverage        Analyze test coverage
      --property-tests  Validate property-based tests
      --stamp-constraints Validate STAMP safety constraints
      --comprehensive   Run complete validation suite

    Examples:
      elixir #{__ENV__.file} --comprehensive
      elixir #{__ENV__.file} --coverage
    """)
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.replace(~r/[:\s]/, "-")
    |> String.replace(".", "-")
  end
end

# Execute main function if run directly
if System.argv() != [] or __ENV__.file == :stdin do
  AnalyticsTDGValidation.main(System.argv())
else
  AnalyticsTDGValidation.main(["--comprehensive"])
end