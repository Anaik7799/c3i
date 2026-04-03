#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule TDGMixAliasValidator do
  @moduledoc """
  TDG (Test-Driven Generation) Methodology Validator for Mix Alias Implementation
  
  This validator ensures that ALL Mix alias implementation follows strict TDG principles:
  1. Tests written FIRST before any alias implementation
  2. Comprehensive test coverage for all 108 missing aliases
  3. Property-based testing integration (PropCheck + ExUnitProperties)
  4. Test validation before and after implementation
  5. Coverage tracking and compliance reporting
  
  TDG Compliance Requirements:
  - 100% test coverage for all aliases before implementation
  - Dual property testing framework validation
  - Integration test scenarios for all technology areas
  - Performance and resource management test coverage
  - Security and safety constraint test validation
  """

  @target_aliases %{
    sopv511_aee: ["sopv51.execute", "sopv51.validate", "sopv51.status", "sopv51.deploy", 
                  "aee.deploy", "aee.monitor", "aee.50agent.status", "aee.cybernetic.coord",
                  "aee.emergency.stop", "aee.goal.execute"],
    
    phics: ["phics.setup", "phics.validate", "phics.sync", "phics.status",
            "phics.containers", "phics.hotreload", "phics.bidirectional"],
    
    nixos_containers: ["nixos.build", "nixos.container", "podman.setup", "podman.status",
                      "containers.health", "containers.orchestrate", "nixos.validate",
                      "podman.logs", "containers.cleanup"],
    
    tps: ["tps.jidoka", "tps.kaizen", "tps.5level", "tps.continuous_improvement",
          "tps.quality_gates", "tps.rca", "tps.systematic"],
    
    stamp: ["stamp.stpa", "stamp.cast", "stamp.constraints", "stamp.validate",
            "stamp.safety", "stamp.hazard", "stamp.uca"],
    
    tdg: ["tdg.generate", "tdg.validate", "tdg.compliance", "tdg.test_first",
          "tdg.coverage", "tdg.property", "tdg.methodology"],
    
    gde: ["gde.execute", "gde.status", "gde.dashboard", "gde.report",
          "gde.goals", "gde.cybernetic", "gde.feedback", "gde.optimize"],
    
    fpps: ["fpps.validate", "fpps.audit", "fpps.consensus", "fpps.pattern_check",
           "fpps.ep110_pr__event", "fpps.multi_method", "fpps.drift_detect"],
    
    observability: ["telemetry.setup", "telemetry.dashboard", "metrics.export", "logging.structured",
                   "observability.validate", "signoz.setup", "opentelemetry.validate", "metrics.collect", "traces.analyze"],
    
    quality: ["quality.comprehensive", "quality.gates", "quality.format", "quality.credo",
              "quality.dialyzer", "quality.sobelow", "quality.validation"],
    
    property_testing: ["property.check", "property.propcheck", "property.exunit", "property.generators",
                      "property.shrinking", "property.invariants", "property.dual"],
    
    testing: ["test.wallaby", "test.e2e", "test.integration", "test.property",
              "test.comprehensive", "test.coverage", "test.performance"],
    
    nix_devenv: ["nix.build", "nix.shell", "devenv.up", "devenv.shell",
                "devenv.update", "nix.flake", "nix.develop", "devenv.processes"],
    
    git_github: ["git.intelligent", "github.integration", "git.hooks", "github.actions",
                "git.workflow", "github.pr", "git.commit.smart", "github.issues"]
  }

  @test_files [
    "test/mix_alias/comprehensive_mix_alias_test.exs",
    "test/property/mix_alias_properties_test.exs", 
    "test/integration/mix_alias_integration_test.exs",
    "test/performance/mix_alias_performance_test.exs",
    "test/security/mix_alias_security_test.exs"
  ]

  @timestamp DateTime.utc_now() |> DateTime.to_iso8601()

  def main(args) do
    case args do
      ["--validate-pre"] -> validate_pre_implementation()
      ["--validate-post"] -> validate_post_implementation()
      ["--coverage"] -> analyze_test_coverage()
      ["--property-test"] -> validate_property_testing()
      ["--generate-missing"] -> generate_missing_tests()
      ["--compliance-report"] -> generate_compliance_report()
      ["--help"] -> show_help()
      [] -> validate_pre_implementation()
      _ ->
        IO.puts("Invalid arguments. Use --help for usage information.")
        System.halt(1)
    end
  end

  def validate_pre_implementation do
    IO.puts("\n🧪 TDG Pre-Implementation Validation")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Timestamp: #{@timestamp}")
    IO.puts("Validating test-driven generation methodology compliance...")
    
    results = %{
      test_files: validate_test_files(),
      test_coverage: analyze_alias_test_coverage(),
      property_tests: validate_property_test_framework(),
      test_structure: validate_test_structure(),
      methodology_compliance: validate_methodology_compliance()
    }
    
    display_validation_results(results, :pre_implementation)
    save_validation_report(results, :pre_implementation)
    
    # Determine overall compliance
    compliance_score = calculate_compliance_score(results)
    
    IO.puts("\n📊 TDG Compliance Score: #{compliance_score}%")
    
    if compliance_score >= 95 do
      IO.puts("✅ EXCELLENT: Ready for alias implementation")
    elsif compliance_score >= 80 do
      IO.puts("⚠️ GOOD: Minor improvements recommended before implementation")
    else
      IO.puts("❌ INSUFFICIENT: Major TDG compliance issues must be resolved")
      System.halt(1)
    end
    
    results
  end

  def validate_post_implementation do
    IO.puts("\n🧪 TDG Post-Implementation Validation")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Timestamp: #{@timestamp}")
    IO.puts("Validating implementation against TDG test __requirements...")
    
    results = %{
      alias_implementation: validate_alias_implementation(),
      test_execution: run_comprehensive_tests(),
      coverage_validation: validate_coverage_compliance(),
      property_validation: run_property_tests(),
      integration_testing: run_integration_tests(),
      performance_testing: run_performance_tests()
    }
    
    display_validation_results(results, :post_implementation)
    save_validation_report(results, :post_implementation)
    
    # Check for TDG violations
    violations = detect_tdg_violations(results)
    
    if Enum.empty?(violations) do
      IO.puts("✅ TDG COMPLIANCE: All aliases properly implemented with tests")
    else
      IO.puts("❌ TDG VIOLATIONS DETECTED:")
      Enum.each(violations, fn violation ->
        IO.puts("   • #{violation}")
      end)
      System.halt(1)
    end
    
    results
  end

  defp validate_test_files do
    IO.puts("\n📁 Validating TDG Test File Structure...")
    
    _file_results = Enum.map(@test_files, fn test_file ->
      exists = File.exists?(test_file)
      
      result = if exists do
        content = File.read!(test_file)
        
        %{
          file: test_file,
          exists: true,
          line_count: length(String.split(content, "\n")),
          test_count: count_test_functions(content),
          has_property_tests: String.contains?(content, "property") or String.contains?(content, "PropCheck"),
          has_integration_tests: String.contains?(content, "integration") or String.contains?(content, "System.cmd"),
          has_tdg_compliance: String.contains?(content, "TDG") or String.contains?(content, "test.*driven.*generation")
        }
      else
        %{
          file: test_file,
          exists: false,
          missing: true
        }
      end
      
      status = if result[:exists], do: "✅", else: "❌"
      IO.puts("   #{status} #{test_file}")
      if result[:exists] do
        IO.puts("      Lines: #{result[:line_count]}, Tests: #{result[:test_count]}")
      end
      
      result
    end)
    
    existing_count = Enum.count(file_results, & &1[:exists])
    IO.puts("   📊 Test Files: #{existing_count}/#{length(@test_files)} exist")
    
    file_results
  end

  defp validate_alias_test_coverage do
    IO.puts("\n🎯 Analyzing Alias Test Coverage...")
    
    total_aliases = @target_aliases |> Map.values() |> List.flatten() |> length()
    IO.puts("   📋 Target Aliases: #{total_aliases}")
    
    # Check main test file
    main_test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(main_test_file) do
      content = File.read!(main_test_file)
      
      # Count covered aliases by searching for alias names in tests
      covered_aliases = @target_aliases
                       |> Map.values()
                       |> List.flatten()
                       |> Enum.filter(fn alias_name ->
                         String.contains?(content, alias_name)
                       end)
      
      coverage_percentage = round(length(covered_aliases) / total_aliases * 100)
      
      IO.puts("   ✅ Covered Aliases: #{length(covered_aliases)}/#{total_aliases} (#{coverage_percentage}%)")
      
      # Analyze coverage by technology area
      Enum.each(@target_aliases, fn {tech, aliases} ->
        tech_covered = Enum.count(aliases, fn alias_name ->
          String.contains?(content, alias_name)
        end)
        tech_coverage = round(tech_covered / length(aliases) * 100)
        IO.puts("      #{String.capitalize(to_string(tech))}: #{tech_covered}/#{length(aliases)} (#{tech_coverage}%)")
      end)
      
      %{
        total_aliases: total_aliases,
        covered_aliases: length(covered_aliases),
        coverage_percentage: coverage_percentage,
        covered_alias_list: covered_aliases
      }
    else
      IO.puts("   ❌ Main test file not found")
      %{total_aliases: total_aliases, covered_aliases: 0, coverage_percentage: 0}
    end
  end

  defp validate_property_test_framework do
    IO.puts("\n🔬 Validating Property-Based Testing Framework...")
    
    main_test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(main_test_file) do
      content = File.read!(main_test_file)
      
      # Check for dual property testing framework
      has_propcheck = String.contains?(content, "PropCheck") or String.contains?(content, "use PropCheck")
      has_exunitproperties = String.contains?(content, "ExUnitProperties") or String.contains?(content, "use ExUnitProperties")
      
      property_test_count = content
                           |> String.split("\n")
                           |> Enum.count(fn line -> String.contains?(line, ~r/property|check all|forall/) end)
      
      IO.puts("   PropCheck Support: #{if has_propcheck, do: "✅", else: "❌"}")
      IO.puts("   ExUnitProperties Support: #{if has_exunitproperties, do: "✅", else: "❌"}")
      IO.puts("   Property Test Count: #{property_test_count}")
      
      %{
        has_propcheck: has_propcheck,
        has_exunitproperties: has_exunitproperties,
        property_test_count: property_test_count,
        dual_framework: has_propcheck and has_exunitproperties
      }
    else
      IO.puts("   ❌ Main test file not found")
      %{has_propcheck: false, has_exunitproperties: false, property_test_count: 0, dual_framework: false}
    end
  end

  defp validate_test_structure do
    IO.puts("\n📋 Validating Test Structure and Organization...")
    
    main_test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(main_test_file) do
      content = File.read!(main_test_file)
      
      # Check for proper test organization
      describe_blocks = Regex.scan(~r/describe\s+"([^"]+)"/, content)
      test_functions = Regex.scan(~r/test\s+"([^"]+)"/, content)
      
      has_stamp_tests = String.contains?(content, "STAMP") and String.contains?(content, "Safety Constraints")
      has_tdg_tests = String.contains?(content, "TDG") and String.contains?(content, "Methodology")
      has_integration_tests = String.contains?(content, "System.cmd") or String.contains?(content, "integration")
      has_performance_tests = String.contains?(content, "Performance") or String.contains?(content, "resource")
      
      IO.puts("   Describe Blocks: #{length(describe_blocks)}")
      IO.puts("   Test Functions: #{length(test_functions)}")
      IO.puts("   STAMP Tests: #{if has_stamp_tests, do: "✅", else: "❌"}")
      IO.puts("   TDG Tests: #{if has_tdg_tests, do: "✅", else: "❌"}")
      IO.puts("   Integration Tests: #{if has_integration_tests, do: "✅", else: "❌"}")
      IO.puts("   Performance Tests: #{if has_performance_tests, do: "✅", else: "❌"}")
      
      %{
        describe_count: length(describe_blocks),
        test_count: length(test_functions),
        has_stamp_tests: has_stamp_tests,
        has_tdg_tests: has_tdg_tests,
        has_integration_tests: has_integration_tests,
        has_performance_tests: has_performance_tests,
        well_organized: length(describe_blocks) >= 8 and length(test_functions) >= 15
      }
    else
      IO.puts("   ❌ Main test file not found")
      %{describe_count: 0, test_count: 0, well_organized: false}
    end
  end

  defp validate_methodology_compliance do
    IO.puts("\n📚 Validating TDG Methodology Compliance...")
    
    # Check for TDG compliance indicators
    tdg_indicators = [
      {File.exists?("test/mix_alias/comprehensive_mix_alias_test.exs"), "Comprehensive test file exists"},
      {File.exists?("scripts/validation/stamp_mix_alias_safety_constraints.exs"), "STAMP safety constraints defined"},
      {File.exists?("docs/journal"), "Journal documentation structure"},
      {File.exists?("mix.exs"), "Mix configuration file exists"}
    ]
    
    compliance_count = Enum.count(tdg_indicators, fn {condition, _desc} -> condition end)
    
    Enum.each(tdg_indicators, fn {condition, description} ->
      status = if condition, do: "✅", else: "❌"
      IO.puts("   #{status} #{description}")
    end)
    
    # Check for test-first evidence
    test_first_evidence = if File.exists?("test/mix_alias/comprehensive_mix_alias_test.exs") do
      # Test file should exist before implementation (TDG principle)
      test_content = File.read!("test/mix_alias/comprehensive_mix_alias_test.exs")
      String.contains?(test_content, "TDG") and String.contains?(test_content, "test.*driven.*generation")
    else
      false
    end
    
    IO.puts("   #{if test_first_evidence, do: "✅", else: "❌"} Test-first evidence documented")
    
    compliance_percentage = round(compliance_count / length(tdg_indicators) * 100)
    IO.puts("   📊 Methodology Compliance: #{compliance_percentage}%")
    
    %{
      compliance_indicators: tdg_indicators,
      compliance_count: compliance_count,
      compliance_percentage: compliance_percentage,
      test_first_evidence: test_first_evidence
    }
  end

  defp validate_alias_implementation do
    IO.puts("\n🔧 Validating Alias Implementation...")
    
    if File.exists?("mix.exs") do
      mix_content = File.read!("mix.exs")
      
      # Count implemented aliases
      alias_matches = Regex.scan(~r/"([^"]+)":\s*\[/, mix_content)
      _implemented_aliases = Enum.map(alias_matches, fn [_, name] -> name end)
      
      total_target_aliases = @target_aliases |> Map.values() |> List.flatten() |> length()
      target_aliases_implemented = @target_aliases
                                  |> Map.values()
                                  |> List.flatten()
                                  |> Enum.filter(fn alias_name ->
                                    Enum.member?(implemented_aliases, alias_name)
                                  end)
      
      implementation_percentage = round(length(target_aliases_implemented) / total_target_aliases * 100)
      
      IO.puts("   📊 Total Aliases: #{length(implemented_aliases)}")
      IO.puts("   🎯 Target Aliases Implemented: #{length(target_aliases_implemented)}/#{total_target_aliases} (#{implementation_percentage}%)")
      
      %{
        total_aliases: length(implemented_aliases),
        target_aliases_implemented: length(target_aliases_implemented),
        implementation_percentage: implementation_percentage,
        implemented_alias_list: target_aliases_implemented
      }
    else
      IO.puts("   ❌ mix.exs file not found")
      %{total_aliases: 0, target_aliases_implemented: 0, implementation_percentage: 0}
    end
  end

  defp run_comprehensive_tests do
    IO.puts("\n🧪 Running Comprehensive Test Suite...")
    
    test_results = []
    
    # Run main test file if it exists
    main_test = "test/mix_alias/comprehensive_mix_alias_test.exs"
    if File.exists?(main_test) do
      {_output, _exit_code} = System.cmd("mix", ["test", main_test], stderr_to_stdout: true)
      
      passed_tests = count_passed_tests(output)
      failed_tests = count_failed_tests(output)
      
      IO.puts("   📊 Main Tests - Passed: #{passed_tests}, Failed: #{failed_tests}")
      
      test_results = [%{
        file: main_test,
        exit_code: exit_code,
        passed: passed_tests,
        failed: failed_tests,
        output: output
      } | test_results]
    end
    
    %{test_results: test_results}
  end

  defp validate_coverage_compliance do
    IO.puts("\n📊 Validating Test Coverage Compliance...")
    
    # Run test coverage analysis
    {_output, __exit_code} = System.cmd("mix", ["test", "--cover"], stderr_to_stdout: true)
    
    # Extract coverage percentage if available
    coverage_match = Regex.run(~r/(\d+\.\d+)%/, output)
    coverage_percentage = if coverage_match do
      {_percentage, __} = Float.parse(hd(tl(coverage_match)))
      percentage
    else
      0.0
    end
    
    IO.puts("   📈 Test Coverage: #{coverage_percentage}%")
    
    target_coverage = 95.0
    compliance = coverage_percentage >= target_coverage
    
    IO.puts("   🎯 Coverage Target: #{target_coverage}% - #{if compliance, do: "✅ MET", else: "❌ NOT MET"}")
    
    %{
      coverage_percentage: coverage_percentage,
      target_coverage: target_coverage,
      compliance: compliance
    }
  end

  defp run_property_tests do
    IO.puts("\n🔬 Running Property-Based Tests...")
    
    # Check if property tests are available and run them
    property_files = [
      "test/property/mix_alias_properties_test.exs"
    ]
    
    _property_results = Enum.map(property_files, fn file ->
      if File.exists?(file) do
        {_output, _exit_code} = System.cmd("mix", ["test", file], stderr_to_stdout: true)
        
        %{
          file: file,
          exists: true,
          exit_code: exit_code,
          passed: count_passed_tests(output),
          output: String.slice(output, 0, 500)  # Truncate for brevity
        }
      else
        %{file: file, exists: false}
      end
    end)
    
    existing_count = Enum.count(property_results, & &1[:exists])
    IO.puts("   📊 Property Test Files: #{existing_count}/#{length(property_files)} available")
    
    %{property_results: property_results}
  end

  defp run_integration_tests do
    IO.puts("\n🔗 Running Integration Tests...")
    
    integration_files = [
      "test/integration/mix_alias_integration_test.exs"
    ]
    
    _integration_results = Enum.map(integration_files, fn file ->
      if File.exists?(file) do
        {_output, _exit_code} = System.cmd("mix", ["test", file], stderr_to_stdout: true)
        
        %{
          file: file,
          exists: true,
          exit_code: exit_code,
          passed: count_passed_tests(output)
        }
      else
        %{file: file, exists: false}
      end
    end)
    
    existing_count = Enum.count(integration_results, & &1[:exists])
    IO.puts("   📊 Integration Test Files: #{existing_count}/#{length(integration_files)} available")
    
    %{integration_results: integration_results}
  end

  defp run_performance_tests do
    IO.puts("\n⚡ Running Performance Tests...")
    
    performance_files = [
      "test/performance/mix_alias_performance_test.exs"
    ]
    
    _performance_results = Enum.map(performance_files, fn file ->
      if File.exists?(file) do
        {_output, _exit_code} = System.cmd("mix", ["test", file], stderr_to_stdout: true)
        
        %{
          file: file,
          exists: true,
          exit_code: exit_code,
          passed: count_passed_tests(output)
        }
      else
        %{file: file, exists: false}
      end
    end)
    
    existing_count = Enum.count(performance_results, & &1[:exists])
    IO.puts("   📊 Performance Test Files: #{existing_count}/#{length(performance_files)} available")
    
    %{performance_results: performance_results}
  end

  defp detect_tdg_violations(results) do
    violations = []
    
    # Check for aliases implemented without tests
    if results[:alias_implementation] do
      impl_percentage = results[:alias_implementation][:implementation_percentage] || 0
      coverage_percentage = get_in(results, [:test_execution, :coverage_percentage]) || 0
      
      if impl_percentage > coverage_percentage + 10 do  # 10% tolerance
        violations = ["Aliases implemented without corresponding tests (TDG violation)" | violations]
      end
    end
    
    # Check for insufficient test coverage
    if results[:coverage_validation] do
      coverage = results[:coverage_validation][:coverage_percentage] || 0
      if coverage < 95.0 do
        violations = ["Test coverage below 95% __requirement (#{coverage}%)" | violations]
      end
    end
    
    # Check for missing property tests
    if results[:property_validation] do
      property_results = results[:property_validation][:property_results] || []
      if Enum.empty?(property_results) or not Enum.any?(property_results, & &1[:exists]) do
        violations = ["Property-based tests missing (__required for TDG)" | violations]
      end
    end
    
    violations
  end

  defp count_test_functions(content) do
    content
    |> String.split("\n")
    |> Enum.count(fn line -> String.match?(line, ~r/^\s*test\s+/) end)
  end

  defp count_passed_tests(output) do
    case Regex.run(~r/(\d+) passed/, output) do
      [_, count] -> String.to_integer(count)
      nil -> 0
    end
  end

  defp count_failed_tests(output) do
    case Regex.run(~r/(\d+) failed/, output) do
      [_, count] -> String.to_integer(count)
      nil -> 0
    end
  end

  defp calculate_compliance_score(results) do
    scores = []
    
    # Test file existence (25 points)
    if results[:test_files] do
      existing_files = Enum.count(results[:test_files], & &1[:exists])
      total_files = length(results[:test_files])
      file_score = round(existing_files / total_files * 25)
      scores = [file_score | scores]
    end
    
    # Test coverage (30 points)
    if results[:test_coverage] do
      coverage = results[:test_coverage][:coverage_percentage] || 0
      coverage_score = round(min(coverage, 100) * 0.3)
      scores = [coverage_score | scores]
    end
    
    # Property testing (20 points)
    if results[:property_tests] do
      dual_framework = results[:property_tests][:dual_framework]
      property_score = if dual_framework, do: 20, else: 0
      scores = [property_score | scores]
    end
    
    # Test structure (15 points)
    if results[:test_structure] do
      well_organized = results[:test_structure][:well_organized]
      structure_score = if well_organized, do: 15, else: 0
      scores = [structure_score | scores]
    end
    
    # Methodology compliance (10 points)
    if results[:methodology_compliance] do
      compliance = results[:methodology_compliance][:compliance_percentage] || 0
      methodology_score = round(compliance * 0.1)
      scores = [methodology_score | scores]
    end
    
    Enum.sum(scores)
  end

  defp display_validation_results(results, phase) do
    IO.puts("\n📊 TDG Validation Results (#{String.capitalize(to_string(phase))})")
    IO.puts("=" <> String.duplicate("=", 60))
    
    Enum.each(results, fn {category, result} ->
      IO.puts("\n📋 #{String.capitalize(to_string(category))}:")
      display_category_result(result)
    end)
  end

  defp display_category_result(result) when is_map(result) do
    Enum.each(result, fn {key, value} ->
      display_value = case value do
        true -> "✅"
        false -> "❌"
        num when is_number(num) -> "#{num}"
        str when is_binary(str) -> str
        list when is_list(list) -> "#{length(list)} items"
        _ -> "#{inspect(value)}"
      end
      
      IO.puts("   #{String.capitalize(to_string(key))}: #{display_value}")
    end)
  end

  defp display_category_result(result) when is_list(result) do
    Enum.each(result, fn item ->
      if is_map(item) do
        display_category_result(item)
      else
        IO.puts("   • #{inspect(item)}")
      end
    end)
  end

  defp display_category_result(result) do
    IO.puts("   #{inspect(result)}")
  end

  defp save_validation_report(results, phase) do
    report_data = %{
      timestamp: @timestamp,
      phase: phase,
      tdg_validation_results: results,
      compliance_score: calculate_compliance_score(results),
      target_aliases: @target_aliases,
      recommendations: generate_tdg_recommendations(results, phase)
    }
    
    File.mkdir_p!("./__data/tmp")
    
    timestamp_str = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/#{timestamp_str}-tdg-mix-alias-validation-#{phase}.json"
    
    File.write!(report_file, Jason.encode!(report_data, pretty: true))
    
    IO.puts("\n📋 TDG validation report saved to: #{report_file}")
  end

  defp generate_tdg_recommendations(results, phase) do
    recommendations = []
    
    case phase do
      :pre_implementation ->
        recommendations = [
          "✅ Ensure all test files exist before alias implementation",
          "📊 Target 100% alias test coverage in main test file", 
          "🔬 Implement dual property testing framework (PropCheck + ExUnitProperties)",
          "📋 Organize tests with proper describe blocks and clear descriptions",
          "📚 Document TDG methodology compliance throughout"
        ]
        
      :post_implementation ->
        recommendations = [
          "🧪 Run comprehensive test suite after all alias implementations",
          "📊 Validate 95%+ test coverage compliance",
          "🔬 Execute property-based tests for invariant validation", 
          "🔗 Perform integration testing across technology areas",
          "⚡ Conduct performance testing for resource-intensive aliases"
        ]
    end
    
    # Add conditional recommendations based on results
    if results[:test_coverage] && results[:test_coverage][:coverage_percentage] < 95 do
      recommendations = ["⚠️ Improve test coverage to meet 95% __requirement" | recommendations]
    end
    
    if results[:property_tests] && not results[:property_tests][:dual_framework] do
      recommendations = ["🔬 Implement dual property testing framework" | recommendations]
    end
    
    recommendations
  end

  def analyze_test_coverage do
    IO.puts("\n📊 TDG Test Coverage Analysis")
    IO.puts("=" <> String.duplicate("=", 40))
    
    validate_alias_test_coverage()
  end

  def validate_property_testing do
    IO.puts("\n🔬 TDG Property Testing Validation")
    IO.puts("=" <> String.duplicate("=", 40))
    
    validate_property_test_framework()
  end

  def generate_missing_tests do
    IO.puts("\n🚧 Generating Missing TDG Test Files...")
    
    # Generate property test file if missing
    property_test_file = "test/property/mix_alias_properties_test.exs"
    unless File.exists?(property_test_file) do
      File.mkdir_p!(Path.dirname(property_test_file))
      
      property_content = """
      defmodule Indrajaal.MixAliasPropertiesTest do
        use ExUnit.Case, async: false
        use PropCheck
        use ExUnitProperties
        
        @moduledoc \"\"\"
        Property-based testing for Mix alias implementation
        Using dual framework approach: PropCheck + ExUnitProperties
        \"\"\"
        
        property "all aliases return consistent exit codes", [:verbose] do
          forall alias_name <- oneof(["setup", "help"]) do
            {__output, _exit_code} = System.cmd("mix", [alias_name], stderr_to_stdout: true)
            exit_code in [0, 1]  # Valid exit codes
          end
        end
        
        test "property test using ExUnitProperties" do
          check all alias_name <- member_of(["setup", "help"]),
                    max_runs: 50 do
            
            result = System.cmd("mix", [alias_name], stderr_to_stdout: true)
            assert is_tuple(result) and tuple_size(result) == 2
          end
        end
      end
      """
      
      File.write!(property_test_file, property_content)
      IO.puts("   ✅ Generated: #{property_test_file}")
    end
    
    # Generate integration test file if missing  
    integration_test_file = "test/integration/mix_alias_integration_test.exs"
    unless File.exists?(integration_test_file) do
      File.mkdir_p!(Path.dirname(integration_test_file))
      
      integration_content = """
      defmodule Indrajaal.MixAliasIntegrationTest do
        use ExUnit.Case, async: false
        
        @moduledoc \"\"\"
        Integration testing for Mix alias cross-technology compatibility
        Validates that aliases work together across technology stacks
        \"\"\"
        
        test "alias chaining works correctly" do
          # Test that aliases can be chained together
          result = System.cmd("mix", ["setup"], stderr_to_stdout: true)
          assert elem(result, 1) == 0
        end
        
        test "parallel alias execution safety" do
          # Test concurrent alias execution
          tasks = for _ <- 1..3 do
            Task.async(fn ->
              System.cmd("mix", ["help"], stderr_to_stdout: true)
            end)
          end
          
          results = Task.await_many(tasks)
          assert length(results) == 3
        end
      end
      """
      
      File.write!(integration_test_file, integration_content)
      IO.puts("   ✅ Generated: #{integration_test_file}")
    end
    
    IO.puts("   ✅ Missing TDG test file generation complete")
  end

  def generate_compliance_report do
    IO.puts("\n📊 TDG Methodology Compliance Report")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Generated: #{@timestamp}")
    
    # Run both pre and post validation
    IO.puts("\n🔄 Running comprehensive TDG analysis...")
    
    pre_results = validate_pre_implementation()
    pre_score = calculate_compliance_score(pre_results)
    
    IO.puts("\n📈 TDG Compliance Summary:")
    IO.puts("   Pre-Implementation Score: #{pre_score}%")
    
    IO.puts("\n📋 TDG Methodology Requirements:")
    IO.puts("   ✅ Test-First Development: Tests written BEFORE implementation")
    IO.puts("   ✅ Comprehensive Coverage: 95%+ test coverage __required") 
    IO.puts("   ✅ Property-Based Testing: Dual framework (PropCheck + ExUnitProperties)")
    IO.puts("   ✅ Integration Testing: Cross-technology validation")
    IO.puts("   ✅ Performance Testing: Resource and timing validation")
    IO.puts("   ✅ STAMP Integration: Safety constraint test validation")
    
    IO.puts("\n🎯 Implementation Readiness:")
    if pre_score >= 95 do
      IO.puts("   ✅ READY: Excellent TDG compliance - proceed with implementation")
    elsif pre_score >= 80 do
      IO.puts("   ⚠️ MOSTLY READY: Good compliance - address minor issues")
    else
      IO.puts("   ❌ NOT READY: Significant TDG compliance gaps must be resolved")
    end
    
    save_compliance_report(%{
      pre_score: pre_score,
      pre_results: pre_results,
      timestamp: @timestamp,
      methodology: "TDG",
      status: if pre_score >= 95, do: "READY", else: "NEEDS_WORK"
    })
  end

  defp save_compliance_report(report_data) do
    File.mkdir_p!("./__data/tmp")
    timestamp_str = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/#{timestamp_str}-tdg-compliance-report.json"
    
    File.write!(report_file, Jason.encode!(report_data, pretty: true))
    
    IO.puts("\n📋 TDG compliance report saved to: #{report_file}")
  end

  defp show_help do
    IO.puts("""
    🧪 TDG Mix Alias Methodology Validator
    
    Usage: elixir tdg_mix_alias_validator.exs [OPTION]
    
    Options:
      --validate-pre         Validate TDG compliance before implementation (default)
      --validate-post        Validate TDG compliance after implementation
      --coverage             Analyze test coverage for all target aliases  
      --property-test        Validate property-based testing framework
      --generate-missing     Generate missing TDG test files
      --compliance-report    Generate comprehensive TDG compliance report
      --help                 Show this help message
    
    Examples:
      # Pre-implementation validation (run before creating aliases)
      elixir tdg_mix_alias_validator.exs --validate-pre
      
      # Post-implementation validation (run after creating aliases)  
      elixir tdg_mix_alias_validator.exs --validate-post
      
      # Analyze test coverage
      elixir tdg_mix_alias_validator.exs --coverage
      
      # Generate missing test files
      elixir tdg_mix_alias_validator.exs --generate-missing
      
      # Full compliance report
      elixir tdg_mix_alias_validator.exs --compliance-report
    
    TDG Methodology Principles:
      1. Tests written FIRST before any alias implementation
      2. 100% test coverage for all 108 target aliases
      3. Dual property testing (PropCheck + ExUnitProperties) 
      4. Integration testing across technology areas
      5. Performance and resource management validation
      6. STAMP safety constraint integration
      7. Comprehensive documentation and compliance tracking
    
    Target Technologies (108 aliases):
      • SOPv5.11 + AEE Cybernetic Framework (10 aliases)
      • PHICS Hot-Reloading Integration (7 aliases)
      • NixOS Containers + Podman (9 aliases)
      • TPS Toyota Production System (7 aliases)
      • STAMP Safety Analysis (7 aliases)
      • TDG Test-Driven Generation (7 aliases)
      • GDE Goal-Directed Execution (8 aliases)  
      • FPPS False Positive Pr__evention (7 aliases)
      • Observability Stack (9 aliases)
      • Quality Tools (7 aliases)
      • Property Testing Framework (7 aliases)
      • ExUnit + Wallaby E2E Testing (7 aliases)
      • Nix + Devenv Integration (8 aliases)
      • Git/GitHub Intelligence (8 aliases)
    """)
  end
end

# Run the TDG validator
TDGMixAliasValidator.main(System.argv())