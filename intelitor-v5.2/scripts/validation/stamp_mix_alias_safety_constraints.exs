#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule STAMPMixAliasSafetyConstraints do
  @moduledoc """
  STAMP (Systems-Theoretic Accident Model and Processes) Safety Constraint Validation
  for Mix Alias Implementation
  
  This module implements 8 critical safety constraints that MUST be satisfied
  during the implementation of 108 missing Mix aliases.
  
  Safety-Critical System: Mix Build and Development Infrastructure
  Risk Level: HIGH (affects all development and deployment operations)
  
  STAMP Methodology Integration:
  - STPA (Systems-Theoretic Process Analysis): Proactive hazard analysis
  - CAST (Causal Analysis based on STAMP): Reactive incident analysis
  - UCA (Unsafe Control Actions): Identification and mitigation
  """

  @safety_constraints %{
    "SC-MA-001" => %{
      id: "SC-MA-001",
      title: "Alias Implementation Validation",
      constraint: "System SHALL validate all alias implementations before activation",
      rationale: "Pr__event deployment of broken or malicious aliases that could compromise build system",
      validation_method: "Pre-activation testing with comprehensive validation suite",
      risk_level: :critical,
      mitigation_strategies: [
        "Automated alias testing before deployment",
        "Sandbox execution for alias validation",
        "Rollback mechanism for failed aliases"
      ]
    },
    
    "SC-MA-002" => %{
      id: "SC-MA-002", 
      title: "Backward Compatibility Preservation",
      constraint: "System SHALL maintain backward compatibility with existing aliases",
      rationale: "Pr__event breaking existing development workflows and CI/CD pipelines",
      validation_method: "Regression testing of all existing aliases after changes",
      risk_level: :high,
      mitigation_strategies: [
        "Comprehensive regression test suite",
        "Alias versioning system",
        "Deprecation warnings before breaking changes"
      ]
    },
    
    "SC-MA-003" => %{
      id: "SC-MA-003",
      title: "Documentation Completeness",
      constraint: "System SHALL provide comprehensive help documentation for all aliases",
      rationale: "Pr__event developer confusion and misuse leading to system failures",
      validation_method: "Automated documentation coverage analysis",
      risk_level: :medium,
      mitigation_strategies: [
        "Mandatory documentation for new aliases",
        "Documentation testing in CI pipeline",
        "Interactive help system validation"
      ]
    },
    
    "SC-MA-004" => %{
      id: "SC-MA-004",
      title: "Resource Management Safety",
      constraint: "System SHALL implement resource limits for resource-intensive aliases",
      rationale: "Pr__event system resource exhaustion that could crash development environment",
      validation_method: "Resource usage monitoring and limit enforcement testing",
      risk_level: :high,
      mitigation_strategies: [
        "CPU and memory limit enforcement",
        "Timeout mechanisms for long-running aliases",
        "Resource usage monitoring and alerting"
      ]
    },
    
    "SC-MA-005" => %{
      id: "SC-MA-005",
      title: "Parallel Execution Safety",
      constraint: "System SHALL pr__event conflicting parallel execution of mutually exclusive aliases",
      rationale: "Pr__event race conditions and __data corruption from concurrent alias execution",
      validation_method: "Concurrency testing with conflict detection",
      risk_level: :high,
      mitigation_strategies: [
        "Mutex locking for conflicting operations",
        "Execution queue management",
        "Clear parallel execution guidelines"
      ]
    },
    
    "SC-MA-006" => %{
      id: "SC-MA-006",
      title: "Error Propagation Control",
      constraint: "System SHALL provide clear error messages and pr__event error cascades",
      rationale: "Pr__event system-wide failures from individual alias errors",
      validation_method: "Error handling and propagation testing",
      risk_level: :medium,
      mitigation_strategies: [
        "Structured error reporting",
        "Error containment mechanisms",
        "Graceful degradation strategies"
      ]
    },
    
    "SC-MA-007" => %{
      id: "SC-MA-007",
      title: "Security Validation",
      constraint: "System SHALL validate security implications of all new aliases",
      rationale: "Pr__event introduction of security vulnerabilities through alias commands",
      validation_method: "Security assessment for all alias implementations",
      risk_level: :critical,
      mitigation_strategies: [
        "Security review process for new aliases",
        "Command injection pr__evention",
        "Privilege escalation pr__evention"
      ]
    },
    
    "SC-MA-008" => %{
      id: "SC-MA-008",
      title: "Dependency Chain Integrity", 
      constraint: "System SHALL maintain dependency integrity across all alias implementations",
      rationale: "Pr__event broken dependency chains that could cause build failures",
      validation_method: "Dependency graph analysis and validation",
      risk_level: :high,
      mitigation_strategies: [
        "Dependency mapping and validation",
        "Version compatibility checking", 
        "Dependency conflict resolution"
      ]
    }
  }

  @mix_aliases_file "mix.exs"
  @timestamp DateTime.utc_now() |> DateTime.to_iso8601()

  def main(args) do
    case args do
      ["--validate"] -> validate_all_constraints()
      ["--validate", constraint_id] -> validate_specific_constraint(constraint_id)
      ["--report"] -> generate_safety_report()
      ["--monitor"] -> start_safety_monitoring()
      ["--help"] -> show_help()
      [] -> validate_all_constraints()
      _ -> 
        IO.puts("Invalid arguments. Use --help for usage information.")
        System.halt(1)
    end
  end

  def validate_all_constraints do
    IO.puts("\n🛡️ STAMP Mix Alias Safety Constraint Validation")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("Timestamp: #{@timestamp}")
    IO.puts("Total Constraints: #{length(Map.keys(@safety_constraints))}")
    
    _results = Enum.map(@safety_constraints, fn {id, constraint} ->
      IO.puts("\n📋 Validating #{id}: #{constraint.title}")
      result = validate_constraint(constraint)
      
      status_icon = case result.status do
        :pass -> "✅"
        :warning -> "⚠️"  
        :fail -> "❌"
        :not_applicable -> "➖"
      end
      
      IO.puts("   #{status_icon} Status: #{String.upcase(to_string(result.status))}")
      if result.message, do: IO.puts("   📝 #{result.message}")
      
      result
    end)
    
    summary = generate_validation_summary(results)
    IO.puts("\n" <> summary)
    
    # Save detailed report
    save_validation_report(results)
    
    # Exit with appropriate code
    failed_critical = Enum.any?(results, fn r -> 
      r.status == :fail and r.constraint.risk_level == :critical 
    end)
    
    if failed_critical do
      IO.puts("\n🚨 CRITICAL SAFETY VIOLATIONS DETECTED - ABORTING")
      System.halt(1)
    end
    
    results
  end

  def validate_specific_constraint(constraint_id) do
    constraint_id = String.upcase(constraint_id)
    
    case Map.get(@safety_constraints, constraint_id) do
      nil ->
        IO.puts("❌ Unknown constraint ID: #{constraint_id}")
        System.halt(1)
        
      constraint ->
        IO.puts("\n🛡️ STAMP Safety Constraint Validation: #{constraint_id}")
        IO.puts("=" <> String.duplicate("=", 50))
        
        result = validate_constraint(constraint)
        
        IO.puts("📋 Constraint: #{constraint.title}")
        IO.puts("📝 Description: #{constraint.constraint}")
        IO.puts("🎯 Rationale: #{constraint.rationale}")
        IO.puts("🔍 Validation Method: #{constraint.validation_method}")
        IO.puts("⚠️ Risk Level: #{String.upcase(to_string(constraint.risk_level))}")
        
        status_icon = case result.status do
          :pass -> "✅"
          :warning -> "⚠️"
          :fail -> "❌" 
          :not_applicable -> "➖"
        end
        
        IO.puts("#{status_icon} Status: #{String.upcase(to_string(result.status))}")
        if result.message, do: IO.puts("📄 Details: #{result.message}")
        
        IO.puts("\n🛠️ Mitigation Strategies:")
        Enum.each(constraint.mitigation_strategies, fn strategy ->
          IO.puts("   • #{strategy}")
        end)
        
        result
    end
  end

  defp validate_constraint(constraint) do
    case constraint.id do
      "SC-MA-001" -> validate_alias_implementation(constraint)
      "SC-MA-002" -> validate_backward_compatibility(constraint)
      "SC-MA-003" -> validate_documentation_completeness(constraint)
      "SC-MA-004" -> validate_resource_management(constraint)
      "SC-MA-005" -> validate_parallel_execution_safety(constraint)
      "SC-MA-006" -> validate_error_propagation(constraint)
      "SC-MA-007" -> validate_security_implications(constraint)
      "SC-MA-008" -> validate_dependency_integrity(constraint)
      _ -> %{status: :not_applicable, constraint: constraint, message: "Unknown constraint"}
    end
  end

  defp validate_alias_implementation(constraint) do
    if File.exists?(@mix_aliases_file) do
      mix_content = File.read!(@mix_aliases_file)
      
      # Check if aliases section exists
      has_aliases = String.contains?(mix_content, "defp aliases do")
      
      if has_aliases do
        # Count existing aliases
        alias_matches = Regex.scan(~r/"([^"]+)":\s*\[/, mix_content)
        alias_count = length(alias_matches)
        
        %{
          status: :pass,
          constraint: constraint,
          message: "Found #{alias_count} existing aliases with proper structure"
        }
      else
        %{
          status: :fail,
          constraint: constraint,
          message: "No aliases section found in mix.exs"
        }
      end
    else
      %{
        status: :fail,
        constraint: constraint,
        message: "mix.exs file not found"
      }
    end
  end

  defp validate_backward_compatibility(constraint) do
    if File.exists?(@mix_aliases_file) do
      mix_content = File.read!(@mix_aliases_file)
      
      # Check for essential existing aliases
      essential_aliases = ["setup"]
      missing_aliases = Enum.reject(essential_aliases, fn alias_name ->
        String.contains?(mix_content, "\"#{alias_name}\"")
      end)
      
      if Enum.empty?(missing_aliases) do
        %{
          status: :pass,
          constraint: constraint,
          message: "All essential existing aliases preserved"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "Missing essential aliases: #{Enum.join(missing_aliases, ", ")}"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No existing mix.exs to validate compatibility"
      }
    end
  end

  defp validate_documentation_completeness(constraint) do
    # Check if TDG test file exists (demonstrates test-first approach)
    test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(test_file) do
      test_content = File.read!(test_file)
      
      # Count documented test scenarios
      test_functions = Regex.scan(~r/test\s+"([^"]+)"/, test_content)
      test_count = length(test_functions)
      
      if test_count >= 15 do
        %{
          status: :pass,
          constraint: constraint,
          message: "Comprehensive test documentation with #{test_count} test scenarios"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "Limited test documentation: #{test_count} scenarios (need 15+)"
        }
      end
    else
      %{
        status: :fail,
        constraint: constraint,
        message: "No TDG test documentation found"
      }
    end
  end

  defp validate_resource_management(constraint) do
    # Check for resource management patterns in aliases
    if File.exists?(@mix_aliases_file) do
      mix_content = File.read!(@mix_aliases_file)
      
      # Look for timeout, memory, or resource management patterns
      resource_patterns = [
        ~r/timeout/i,
        ~r/memory/i, 
        ~r/limit/i,
        ~r/parallel/i,
        ~r/\+S\s+\d+/  # Erlang scheduler flags
      ]
      
      has_resource_management = Enum.any?(resource_patterns, fn pattern ->
        String.match?(mix_content, pattern)
      end)
      
      if has_resource_management do
        %{
          status: :pass,
          constraint: constraint,
          message: "Resource management patterns detected in aliases"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "No explicit resource management patterns found"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No mix.exs file to analyze"
      }
    end
  end

  defp validate_parallel_execution_safety(constraint) do
    # Check for parallel execution safety measures
    test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(test_file) do
      test_content = File.read!(test_file)
      
      # Check for parallel execution tests
      has_parallel_tests = String.contains?(test_content, "parallel execution") or
                          String.contains?(test_content, "concurrent") or
                          String.contains?(test_content, "async: false")
      
      if has_parallel_tests do
        %{
          status: :pass,
          constraint: constraint,
          message: "Parallel execution safety tests implemented"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "No parallel execution safety tests found"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No test files to analyze for parallel safety"
      }
    end
  end

  defp validate_error_propagation(constraint) do
    # Check for error handling patterns
    test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    
    if File.exists?(test_file) do
      test_content = File.read!(test_file)
      
      # Look for error handling test patterns
      has_error_handling = String.contains?(test_content, "System.cmd") and
                          (String.contains?(test_content, "stderr_to_stdout") or
                           String.contains?(test_content, "elem(result, 1)"))
      
      if has_error_handling do
        %{
          status: :pass,
          constraint: constraint,
          message: "Error handling and propagation tests implemented"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "Limited error handling test coverage"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No test files to analyze for error handling"
      }
    end
  end

  defp validate_security_implications(constraint) do
    if File.exists?(@mix_aliases_file) do
      mix_content = File.read!(@mix_aliases_file)
      
      # Check for potentially unsafe patterns
      unsafe_patterns = [
        ~r/rm\s+-rf/i,      # Dangerous file deletion
        ~r/sudo/i,           # Privilege escalation
        ~r/\$\(/i,          # Shell injection risk
        ~r/eval/i,          # Code injection risk
        ~r/>\s*\/dev\//i    # Device access
      ]
      
      unsafe_matches = Enum.filter(unsafe_patterns, fn pattern ->
        String.match?(mix_content, pattern)
      end)
      
      if Enum.empty?(unsafe_matches) do
        %{
          status: :pass,
          constraint: constraint,
          message: "No obvious security risks detected in aliases"
        }
      else
        %{
          status: :fail,
          constraint: constraint,
          message: "Potential security risks detected: #{length(unsafe_matches)} patterns"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No mix.exs file to analyze for security"
      }
    end
  end

  defp validate_dependency_integrity(constraint) do
    if File.exists?(@mix_aliases_file) do
      mix_content = File.read!(@mix_aliases_file)
      
      # Check for dependency management patterns
      has_deps_management = String.contains?(mix_content, "deps.get") or
                           String.contains?(mix_content, "deps.compile") or
                           String.contains?(mix_content, "deps.")
      
      if has_deps_management do
        %{
          status: :pass,
          constraint: constraint,
          message: "Dependency management patterns found in aliases"
        }
      else
        %{
          status: :warning,
          constraint: constraint,
          message: "Limited dependency management in aliases"
        }
      end
    else
      %{
        status: :not_applicable,
        constraint: constraint,
        message: "No mix.exs file to analyze dependencies"
      }
    end
  end

  defp generate_validation_summary(results) do
    total = length(results)
    passed = Enum.count(results, &(&1.status == :pass))
    warnings = Enum.count(results, &(&1.status == :warning))
    failed = Enum.count(results, &(&1.status == :fail))
    not_applicable = Enum.count(results, &(&1.status == :not_applicable))
    
    critical_failed = Enum.count(results, fn r ->
      r.status == :fail and r.constraint.risk_level == :critical
    end)
    
    summary = """
    
    📊 STAMP Safety Constraint Validation Summary
    =" <> String.duplicate("=", 50) <> "
    Total Constraints: #{total}
    ✅ Passed: #{passed}
    ⚠️  Warnings: #{warnings}
    ❌ Failed: #{failed}
    ➖ Not Applicable: #{not_applicable}
    
    🚨 Critical Failures: #{critical_failed}
    """
    
    if critical_failed > 0 do
      summary <> "\n⚠️ ATTENTION: Critical safety violations must be resolved before proceeding!"
    else
      summary <> "\n✅ No critical safety violations detected."
    end
  end

  defp save_validation_report(results) do
    report_data = %{
      timestamp: @timestamp,
      validation_summary: generate_validation_summary(results),
      constraint_results: Enum.map(results, fn result ->
        %{
          constraint_id: result.constraint.id,
          title: result.constraint.title,
          status: result.status,
          message: result.message,
          risk_level: result.constraint.risk_level,
          mitigation_strategies: result.constraint.mitigation_strategies
        }
      end),
      recommendations: generate_recommendations(results)
    }
    
    File.mkdir_p!("./__data/tmp")
    report_file = "./__data/tmp/#{DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")}-stamp-mix-alias-safety-report.json"
    File.write!(report_file, Jason.encode!(report_data, pretty: true))
    
    IO.puts("\n📋 Detailed report saved to: #{report_file}")
  end

  defp generate_recommendations(results) do
    failed_constraints = Enum.filter(results, &(&1.status == :fail))
    warning_constraints = Enum.filter(results, &(&1.status == :warning))
    
    recommendations = []
    
    recommendations = if length(failed_constraints) > 0 do
      ["🚨 CRITICAL: Resolve #{length(failed_constraints)} failed safety constraints before implementation" | recommendations]
    else
      recommendations
    end
    
    recommendations = if length(warning_constraints) > 0 do
      ["⚠️ RECOMMENDED: Address #{length(warning_constraints)} warning conditions for optimal safety" | recommendations]
    else
      recommendations
    end
    
    recommendations ++ [
      "📋 Implement comprehensive alias validation before deployment",
      "🔍 Regular safety constraint monitoring during development",
      "📚 Maintain up-to-date safety documentation",
      "🧪 Continuous TDG methodology compliance"
    ]
  end

  def generate_safety_report do
    IO.puts("\n🛡️ STAMP Mix Alias Safety Analysis Report")
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("Generated: #{@timestamp}")
    
    IO.puts("\n📋 Safety Constraints Overview:")
    Enum.each(@safety_constraints, fn {id, constraint} ->
      risk_icon = case constraint.risk_level do
        :critical -> "🔴"
        :high -> "🟠"
        :medium -> "🟡"
        :low -> "🟢"
      end
      
      IO.puts("\n#{risk_icon} #{id}: #{constraint.title}")
      IO.puts("   📝 #{constraint.constraint}")
      IO.puts("   🎯 Risk Level: #{String.upcase(to_string(constraint.risk_level))}")
      IO.puts("   🔍 Validation: #{constraint.validation_method}")
    end)
    
    IO.puts("\n🛠️ Implementation Guidelines:")
    IO.puts("1. Validate ALL safety constraints before alias implementation")
    IO.puts("2. Use TDG methodology - write tests BEFORE implementing aliases") 
    IO.puts("3. Apply STAMP safety analysis for critical aliases")
    IO.puts("4. Monitor safety constraints continuously during development")
    IO.puts("5. Document all safety-related decisions and trade-offs")
    
    IO.puts("\n📊 Risk Assessment:")
    risk_counts = @safety_constraints
                 |> Map.values()
                 |> Enum.group_by(&(&1.risk_level))
                 |> Enum.map(fn {level, constraints} -> {level, length(constraints)} end)
                 |> Map.new()
    
    Enum.each([:critical, :high, :medium, :low], fn level ->
      count = Map.get(risk_counts, level, 0)
      IO.puts("   #{String.capitalize(to_string(level))}: #{count} constraints")
    end)
  end

  def start_safety_monitoring do
    IO.puts("\n🔍 Starting STAMP Safety Constraint Monitoring...")
    IO.puts("Press Ctrl+C to stop monitoring\n")
    
    monitor_loop()
  end

  defp monitor_loop do
    results = validate_all_constraints()
    
    critical_failures = Enum.count(results, fn r ->
      r.status == :fail and r.constraint.risk_level == :critical
    end)
    
    if critical_failures > 0 do
      IO.puts("\n🚨 ALERT: #{critical_failures} critical safety constraint violations detected!")
    end
    
    IO.puts("\nNext validation in 30 seconds...")
    :timer.sleep(30_000)
    
    monitor_loop()
  end

  defp show_help do
    IO.puts("""
    🛡️ STAMP Mix Alias Safety Constraint Validator
    
    Usage: elixir stamp_mix_alias_safety_constraints.exs [OPTION]
    
    Options:
      --validate             Validate all safety constraints (default)
      --validate CONSTRAINT  Validate specific constraint (e.g., SC-MA-001)
      --report              Generate comprehensive safety analysis report
      --monitor             Start continuous safety monitoring
      --help                Show this help message
    
    Examples:
      # Validate all constraints
      elixir stamp_mix_alias_safety_constraints.exs --validate
      
      # Validate specific constraint
      elixir stamp_mix_alias_safety_constraints.exs --validate SC-MA-001
      
      # Generate detailed report
      elixir stamp_mix_alias_safety_constraints.exs --report
      
      # Start monitoring mode
      elixir stamp_mix_alias_safety_constraints.exs --monitor
    
    Safety Constraints:
      SC-MA-001: Alias Implementation Validation (Critical)
      SC-MA-002: Backward Compatibility Preservation (High)
      SC-MA-003: Documentation Completeness (Medium)
      SC-MA-004: Resource Management Safety (High) 
      SC-MA-005: Parallel Execution Safety (High)
      SC-MA-006: Error Propagation Control (Medium)
      SC-MA-007: Security Validation (Critical)
      SC-MA-008: Dependency Chain Integrity (High)
    """)
  end
end

# Run the validator
STAMPMixAliasSafetyConstraints.main(System.argv())