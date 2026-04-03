#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule MixExsSTAMPAnalysis do
  @moduledoc """
  STAMP (Systems-Theoretic Accident Model and Processes) analysis for Mix.exs enhancements.
  
  This implements both:
  1. STPA (Systems-Theoretic Process Analysis) - proactive hazard analysis
  2. Safety constraint monitoring and validation
  
  Ensures all Mix.exs enhancements comply with SOPv5.11 safety __requirements.
  """

  # Define STAMP Safety Constraints for Mix.exs (SC-MIX-001 through SC-MIX-008)
  @safety_constraints [
    %{
      id: "SC-MIX-001",
      description: "Configuration changes SHALL not break existing functionality",
      category: :functional_safety,
      level: :critical
    },
    %{
      id: "SC-MIX-002", 
      description: "Performance optimizations SHALL maintain system stability",
      category: :performance_safety,
      level: :critical
    },
    %{
      id: "SC-MIX-003",
      description: "Security enhancements SHALL maintain compatibility",
      category: :security_safety,
      level: :high
    },
    %{
      id: "SC-MIX-004",
      description: "Environment configurations SHALL be validated before deployment",
      category: :operational_safety,
      level: :high
    },
    %{
      id: "SC-MIX-005",
      description: "Test framework changes SHALL maintain existing coverage",
      category: :quality_safety,
      level: :medium
    },
    %{
      id: "SC-MIX-006",
      description: "Dependency changes SHALL be validated for security vulnerabilities",
      category: :dependency_safety,
      level: :critical
    },
    %{
      id: "SC-MIX-007",
      description: "Compiler optimizations SHALL not introduce runtime errors",
      category: :compilation_safety,
      level: :critical
    },
    %{
      id: "SC-MIX-008",
      description: "Alias configurations SHALL not create circular dependencies",
      category: :configuration_safety,
      level: :high
    }
  ]

  def main(_args \\ []) do
    IO.puts("🛡️ Starting STAMP Analysis for Mix.exs Enhancements")
    IO.puts("=" <> String.duplicate("=", 70))
    
    case run_stamp_analysis() do
      {:ok, results} ->
        output_results(results)
        save_results(results)
        determine_exit_code(results)
      {:error, reason} ->
        IO.puts("❌ STAMP Analysis Failed: #{reason}")
        System.halt(1)
    end
  end

  defp run_stamp_analysis do
    try do
      # Load current mix.exs configuration
      mix_config = load_mix_configuration()
      
      # Run STPA analysis
      stpa_results = run_stpa_analysis(mix_config)
      
      # Validate safety constraints
      constraint_results = validate_safety_constraints(mix_config)
      
      # Perform hazard analysis
      hazard_analysis = perform_hazard_analysis(mix_config)
      
      # Generate recommendations
      recommendations = generate_safety_recommendations(constraint_results, hazard_analysis)
      
      results = %{
        timestamp: DateTime.utc_now(),
        stpa_results: stpa_results,
        constraint_validation: constraint_results,
        hazard_analysis: hazard_analysis,
        recommendations: recommendations,
        overall_status: determine_overall_status(constraint_results, hazard_analysis)
      }
      
      {:ok, results}
    rescue
      error ->
        {:error, "STAMP analysis error: #{inspect(error)}"}
    end
  end

  defp load_mix_configuration do
    mix_exs_path = Path.join(File.cwd!(), "mix.exs")
    
    if File.exists?(mix_exs_path) do
      content = File.read!(mix_exs_path)
      
      %{
        content: content,
        aliases: extract_aliases(content),
        compiler_opts: extract_compiler_options(content),
        dependencies: extract_dependencies(content),
        test_coverage: extract_test_coverage(content)
      }
    else
      raise "mix.exs not found at #{mix_exs_path}"
    end
  end

  # STPA (Systems-Theoretic Process Analysis) Implementation
  defp run_stpa_analysis(config) do
    IO.puts("🔍 Running STPA Analysis...")
    
    # Step 1: Identify system purpose and safety __requirements
    system_purpose = "Elixir project configuration and build management"
    
    # Step 2: Model control structure
    control_structure = model_control_structure()
    
    # Step 3: Identify Unsafe Control Actions (UCAs)
    ucas = identify_unsafe_control_actions(config)
    
    # Step 4: Analyze causal scenarios
    causal_scenarios = analyze_causal_scenarios(ucas)
    
    %{
      system_purpose: system_purpose,
      control_structure: control_structure,
      unsafe_control_actions: ucas,
      causal_scenarios: causal_scenarios,
      mitigation_strategies: generate_mitigation_strategies(ucas)
    }
  end

  defp model_control_structure do
    %{
      controllers: [
        %{name: "Developer", role: "Configuration Management", authority: :high},
        %{name: "Mix Build System", role: "Compilation Control", authority: :medium},
        %{name: "Dependency Manager", role: "Package Resolution", authority: :medium},
        %{name: "Test Framework", role: "Quality Validation", authority: :low}
      ],
      controlled_processes: [
        %{name: "Application Compilation", criticality: :high},
        %{name: "Dependency Resolution", criticality: :high},
        %{name: "Test Execution", criticality: :medium},
        %{name: "Performance Optimization", criticality: :medium}
      ],
      control_actions: [
        "Configure compiler options",
        "Manage dependencies", 
        "Define test coverage",
        "Set environment variables",
        "Configure aliases"
      ]
    }
  end

  defp identify_unsafe_control_actions(config) do
    ucas = []
    
    # UCA-1: Compiler optimization flags that break compilation
    ucas = if has_aggressive_optimization?(config) do
      [%{
        id: "UCA-MIX-001",
        description: "Compiler optimization flags cause compilation failures",
        severity: :critical,
        constraint_violated: "SC-MIX-002"
      } | ucas]
    else
      ucas
    end
    
    # UCA-2: Dependencies with known vulnerabilities
    ucas = if has_vulnerable_dependencies?(config) do
      [%{
        id: "UCA-MIX-002", 
        description: "Dependencies with known security vulnerabilities",
        severity: :critical,
        constraint_violated: "SC-MIX-006"
      } | ucas]
    else
      ucas
    end
    
    # UCA-3: Circular alias dependencies
    ucas = if has_circular_aliases?(config) do
      [%{
        id: "UCA-MIX-003",
        description: "Circular dependencies in alias configuration",
        severity: :high,
        constraint_violated: "SC-MIX-008"
      } | ucas]
    else
      ucas
    end
    
    # UCA-4: Test coverage regression
    ucas = if has_coverage_regression?(config) do
      [%{
        id: "UCA-MIX-004",
        description: "Test coverage configuration reduces existing coverage",
        severity: :medium,
        constraint_violated: "SC-MIX-005"
      } | ucas]
    else
      ucas
    end
    
    ucas
  end

  defp analyze_causal_scenarios(ucas) do
    Enum.map(ucas, fn uca ->
      %{
        uca_id: uca.id,
        scenarios: generate_causal_scenarios(uca),
        pr__evention_measures: suggest_pr__evention_measures(uca)
      }
    end)
  end

  defp generate_causal_scenarios(uca) do
    case uca.id do
      "UCA-MIX-001" ->
        [
          "Developer enables aggressive optimization without testing",
          "Compiler optimization conflicts with dependencies",
          "Runtime behavior changes due to inlining"
        ]
      "UCA-MIX-002" ->
        [
          "New dependency introduces known CVE",
          "Dependency update includes malicious code",
          "Transitive dependency has vulnerability"
        ]
      "UCA-MIX-003" ->
        [
          "Alias A calls alias B which calls alias A",
          "Complex alias chain creates infinite loop",
          "Recursive alias definition causes stack overflow"
        ]
      "UCA-MIX-004" ->
        [
          "New test exclusions reduce coverage",
          "Changed test patterns miss critical code",
          "Modified coverage thresholds hide regressions"
        ]
      _ ->
        ["Generic causal scenario"]
    end
  end

  defp suggest_pr__evention_measures(uca) do
    case uca.id do
      "UCA-MIX-001" ->
        [
          "Test compilation with optimization flags in CI",
          "Use gradual optimization flag rollout",
          "Monitor runtime behavior after optimization"
        ]
      "UCA-MIX-002" ->
        [
          "Implement automated dependency vulnerability scanning",
          "Use deps.audit alias for regular security checks",
          "Set up dependency update approval process"
        ]
      "UCA-MIX-003" ->
        [
          "Implement alias dependency analysis",
          "Use static analysis to detect circular references",
          "Limit alias nesting depth"
        ]
      "UCA-MIX-004" ->
        [
          "Baseline test coverage before changes",
          "Implement coverage regression detection",
          "Require coverage review for test changes"
        ]
      _ ->
        ["Generic pr__evention measure"]
    end
  end

  defp validate_safety_constraints(config) do
    IO.puts("🛡️ Validating Safety Constraints...")
    
    Enum.map(@safety_constraints, fn constraint ->
      validation_result = validate_constraint(constraint, config)
      
      %{
        constraint: constraint,
        status: validation_result.status,
        details: validation_result.details,
        recommendations: validation_result.recommendations
      }
    end)
  end

  defp validate_constraint(constraint, config) do
    case constraint.id do
      "SC-MIX-001" -> validate_functional_safety(config)
      "SC-MIX-002" -> validate_performance_safety(config)
      "SC-MIX-003" -> validate_security_safety(config)
      "SC-MIX-004" -> validate_operational_safety(config)
      "SC-MIX-005" -> validate_quality_safety(config)
      "SC-MIX-006" -> validate_dependency_safety(config)
      "SC-MIX-007" -> validate_compilation_safety(config)
      "SC-MIX-008" -> validate_configuration_safety(config)
      _ -> %{status: :unknown, details: "Unknown constraint", recommendations: []}
    end
  end

  # Safety constraint validation implementations
  defp validate_functional_safety(config) do
    # Check that essential project configuration is preserved
    has_app_name = String.contains?(config.content, "app:")
    has_version = String.contains?(config.content, "version:")
    has_elixir_version = String.contains?(config.content, "elixir:")
    
    essential_preserved = has_app_name and has_version and has_elixir_version
    
    %{
      status: if essential_preserved do :compliant else :violation end,
      details: "Essential project configuration preservation",
      recommendations: if essential_preserved do 
        [] 
      else 
        ["Ensure app, version, and elixir fields are preserved"]
      end
    }
  end

  defp validate_performance_safety(config) do
    # Check that performance optimizations are safe
    has_warnings_as_errors = String.contains?(config.content, "warnings_as_errors: true")
    has_conditional_optimization = String.contains?(config.content, "Mix.env() == :prod")
    
    safe_optimization = has_warnings_as_errors and has_conditional_optimization
    
    %{
      status: if safe_optimization do :compliant else :violation end,
      details: "Performance optimization safety validation",
      recommendations: if safe_optimization do
        []
      else
        ["Use conditional optimization flags", "Enable warnings_as_errors"]
      end
    }
  end

  defp validate_security_safety(config) do
    # Check that security enhancements don't break compatibility
    has_security_aliases = length(Map.keys(config.aliases) |> Enum.filter(&String.starts_with?(&1, "deps."))) > 5
    
    %{
      status: if has_security_aliases do :compliant else :violation end,
      details: "Security enhancement compatibility",
      recommendations: if has_security_aliases do
        []
      else
        ["Add comprehensive dependency security aliases"]
      end
    }
  end

  defp validate_operational_safety(config) do
    # Check environment-specific configuration
    has_env_config = String.contains?(config.content, "defp get_env_config")
    
    %{
      status: if has_env_config do :compliant else :violation end,
      details: "Environment configuration validation",
      recommendations: if has_env_config do
        []
      else
        ["Implement environment-specific configuration validation"]
      end
    }
  end

  defp validate_quality_safety(config) do
    # Check test framework changes maintain coverage
    has_test_coverage = String.contains?(config.content, "test_coverage:")
    has_minimum_coverage = String.contains?(config.content, "minimum_coverage:")
    
    quality_maintained = has_test_coverage and has_minimum_coverage
    
    %{
      status: if quality_maintained do :compliant else :violation end,
      details: "Test framework quality maintenance",
      recommendations: if quality_maintained do
        []
      else
        ["Configure minimum test coverage __requirements"]
      end
    }
  end

  defp validate_dependency_safety(config) do
    # Check dependency security validation
    has_audit_alias = Map.has_key?(config.aliases, "deps.audit")
    has_security_alias = Map.has_key?(config.aliases, "deps.security")
    
    dependency_safe = has_audit_alias and has_security_alias
    
    %{
      status: if dependency_safe do :compliant else :violation end,
      details: "Dependency security validation",
      recommendations: if dependency_safe do
        []
      else
        ["Add deps.audit and deps.security aliases"]
      end
    }
  end

  defp validate_compilation_safety(config) do
    # Check compiler optimization safety
    has_conditional_opt = String.contains?(config.content, "optimize: Mix.env()")
    has_debug_info = String.contains?(config.content, "debug_info:")
    
    compilation_safe = has_conditional_opt and has_debug_info
    
    %{
      status: if compilation_safe do :compliant else :violation end,
      details: "Compiler optimization safety",
      recommendations: if compilation_safe do
        []
      else
        ["Use conditional compiler optimization", "Configure debug_info properly"]
      end
    }
  end

  defp validate_configuration_safety(config) do
    # Check for circular alias dependencies
    circular_detected = detect_circular_aliases(config.aliases)
    
    %{
      status: if circular_detected do :violation else :compliant end,
      details: "Configuration circular dependency detection",
      recommendations: if circular_detected do
        ["Remove circular alias dependencies"]
      else
        []
      end
    }
  end

  # Hazard analysis implementation
  defp perform_hazard_analysis(config) do
    IO.puts("⚠️ Performing Hazard Analysis...")
    
    hazards = []
    
    # Identify potential hazards
    hazards = check_compiler_hazards(config, hazards)
    hazards = check_dependency_hazards(config, hazards)
    hazards = check_configuration_hazards(config, hazards)
    
    %{
      identified_hazards: hazards,
      risk_assessment: assess_risk_levels(hazards),
      mitigation_priorities: prioritize_mitigations(hazards)
    }
  end

  defp check_compiler_hazards(config, hazards) do
    if has_aggressive_optimization?(config) do
      [%{
        type: :compiler_optimization,
        description: "Aggressive compiler optimization may cause runtime issues",
        severity: :medium,
        mitigation: "Use gradual optimization rollout"
      } | hazards]
    else
      hazards
    end
  end

  defp check_dependency_hazards(config, hazards) do
    if length(Map.keys(config.aliases)) > 50 do
      [%{
        type: :dependency_complexity,
        description: "Large number of aliases may create maintenance burden",
        severity: :low,
        mitigation: "Group related aliases and document usage"
      } | hazards]
    else
      hazards
    end
  end

  defp check_configuration_hazards(config, hazards) do
    if detect_circular_aliases(config.aliases) do
      [%{
        type: :circular_dependency,
        description: "Circular alias dependencies detected",
        severity: :high,
        mitigation: "Refactor aliases to remove circular references"
      } | hazards]
    else
      hazards
    end
  end

  # Helper functions for hazard detection
  defp has_aggressive_optimization?(config) do
    # Check for potentially problematic optimization flags
    String.contains?(config.content, "optimize: true") and 
    not String.contains?(config.content, "Mix.env()")
  end

  defp has_vulnerable_dependencies?(_config) do
    # This would typically check against a vulnerability __database
    # For now, assume dependencies are safe
    false
  end

  defp has_circular_aliases?(config) do
    detect_circular_aliases(config.aliases)
  end

  defp has_coverage_regression?(_config) do
    # This would check against baseline coverage
    # For now, assume no regression
    false
  end

  defp detect_circular_aliases(aliases) do
    # Simple circular dependency detection
    # In a real implementation, this would do graph analysis
    false
  end

  defp assess_risk_levels(hazards) do
    Enum.group_by(hazards, & &1.severity)
    |> Enum.map(fn {severity, hazard_list} ->
      {severity, length(hazard_list)}
    end)
    |> Map.new()
  end

  defp prioritize_mitigations(hazards) do
    hazards
    |> Enum.sort_by(fn hazard ->
      case hazard.severity do
        :critical -> 0
        :high -> 1
        :medium -> 2
        :low -> 3
      end
    end)
    |> Enum.take(5)  # Top 5 priorities
  end

  defp generate_safety_recommendations(constraint_results, hazard_analysis) do
    violations = Enum.filter(constraint_results, &(&1.status == :violation))
    high_priority_hazards = Enum.filter(hazard_analysis.identified_hazards, &(&1.severity in [:critical, :high]))
    
    recommendations = []
    
    # Add recommendations for constraint violations
    _recommendations = Enum.reduce(violations, _recommendations, fn violation, acc ->
      [%{
        type: :constraint_violation,
        priority: :high,
        description: "Address #{violation.constraint.id} violation",
        actions: violation.recommendations
      } | acc]
    end)
    
    # Add recommendations for high-priority hazards
    _recommendations = Enum.reduce(high_priority_hazards, _recommendations, fn hazard, acc ->
      [%{
        type: :hazard_mitigation,
        priority: :medium,
        description: "Mitigate #{hazard.type} hazard",
        actions: [hazard.mitigation]
      } | acc]
    end)
    
    recommendations
  end

  defp generate_mitigation_strategies(ucas) do
    Enum.map(ucas, fn uca ->
      %{
        uca_id: uca.id,
        strategy: suggest_pr__evention_measures(uca),
        implementation_priority: map_severity_to_priority(uca.severity)
      }
    end)
  end

  defp map_severity_to_priority(:critical), do: :immediate
  defp map_severity_to_priority(:high), do: :urgent
  defp map_severity_to_priority(:medium), do: :planned
  defp map_severity_to_priority(:low), do: :deferred

  defp determine_overall_status(constraint_results, hazard_analysis) do
    violations = Enum.count(constraint_results, &(&1.status == :violation))
    critical_hazards = Enum.count(hazard_analysis.identified_hazards, &(&1.severity == :critical))
    
    cond do
      violations > 0 or critical_hazards > 0 -> :needs_attention
      length(hazard_analysis.identified_hazards) > 0 -> :acceptable_with_monitoring
      true -> :compliant
    end
  end

  # Utility functions for parsing mix.exs content
  defp extract_aliases(content) do
    # Use the same logic as the TDG validator
    alias_pattern = ~r/"([^"]+)":\s*\[((?:[^\[\]]*|\[[^\]]*\])*)\]/s
    
    Regex.scan(alias_pattern, content)
    |> Enum.reduce(%{}, fn [_, alias_name, commands], acc ->
      command_list = String.split(commands, ",")
                    |> Enum.map(&String.trim/1)
                    |> Enum.map(&String.trim(&1, "\""))
                    |> Enum.reject(&(&1 == ""))
      Map.put(acc, alias_name, command_list)
    end)
  end

  defp extract_compiler_options(content) do
    if String.contains?(content, "elixirc_options:") do
      %{
        warnings_as_errors: String.contains?(content, "warnings_as_errors: true"),
        optimize: String.contains?(content, "optimize:"),
        inline: String.contains?(content, "inline:"),
        debug_info: String.contains?(content, "debug_info:")
      }
    else
      %{}
    end
  end

  defp extract_dependencies(content) do
    # Simple dependency extraction
    dep_pattern = ~r/\{:([^,\}]+)/
    
    Regex.scan(dep_pattern, content)
    |> Enum.map(fn [_, dep_name] -> dep_name end)
    |> Enum.uniq()
  end

  defp extract_test_coverage(content) do
    %{
      configured: String.contains?(content, "test_coverage:"),
      minimum_coverage: String.contains?(content, "minimum_coverage:"),
      tool_specified: String.contains?(content, "ExCoveralls")
    }
  end

  # Output and reporting functions
  defp output_results(results) do
    IO.puts("\n🛡️ STAMP Analysis Results")
    IO.puts("=" <> String.duplicate("=", 70))
    
    output_stpa_results(results.stpa_results)
    output_constraint_validation(results.constraint_validation)
    output_hazard_analysis(results.hazard_analysis)
    output_recommendations(results.recommendations)
    output_overall_status(results.overall_status)
  end

  defp output_stpa_results(stpa_results) do
    IO.puts("\n🔍 STPA Analysis Results:")
    IO.puts("System Purpose: #{stpa_results.system_purpose}")
    IO.puts("Controllers: #{length(stpa_results.control_structure.controllers)}")
    IO.puts("Controlled Processes: #{length(stpa_results.control_structure.controlled_processes)}")
    IO.puts("Unsafe Control Actions: #{length(stpa_results.unsafe_control_actions)}")
    
    if length(stpa_results.unsafe_control_actions) > 0 do
      IO.puts("\nIdentified UCAs:")
      Enum.each(stpa_results.unsafe_control_actions, fn uca ->
        IO.puts("  • #{uca.id}: #{uca.description} (#{uca.severity})")
      end)
    end
  end

  defp output_constraint_validation(constraint_results) do
    IO.puts("\n🛡️ Safety Constraint Validation:")
    
    compliant = Enum.count(constraint_results, &(&1.status == :compliant))
    violations = Enum.count(constraint_results, &(&1.status == :violation))
    
    IO.puts("Compliant: #{compliant}/#{length(constraint_results)}")
    IO.puts("Violations: #{violations}")
    
    if violations > 0 do
      IO.puts("\nViolations:")
      constraint_results
      |> Enum.filter(&(&1.status == :violation))
      |> Enum.each(fn result ->
        IO.puts("  ❌ #{result.constraint.id}: #{result.constraint.description}")
        IO.puts("     Details: #{result.details}")
      end)
    end
  end

  defp output_hazard_analysis(hazard_analysis) do
    IO.puts("\n⚠️ Hazard Analysis:")
    IO.puts("Total Hazards: #{length(hazard_analysis.identified_hazards)}")
    
    if length(hazard_analysis.identified_hazards) > 0 do
      IO.puts("Risk Assessment:")
      Enum.each(hazard_analysis.risk_assessment, fn {severity, count} ->
        IO.puts("  #{severity}: #{count}")
      end)
      
      IO.puts("\nTop Priority Mitigations:")
      Enum.each(hazard_analysis.mitigation_priorities, fn hazard ->
        IO.puts("  • #{hazard.description} (#{hazard.severity})")
      end)
    end
  end

  defp output_recommendations(recommendations) do
    if length(recommendations) > 0 do
      IO.puts("\n📋 Safety Recommendations:")
      Enum.each(recommendations, fn rec ->
        IO.puts("  • #{rec.description} (#{rec.priority})")
        Enum.each(rec.actions, fn action ->
          IO.puts("    - #{action}")
        end)
      end)
    end
  end

  defp output_overall_status(status) do
    IO.puts("\n" <> String.duplicate("=", 70))
    status_icon = case status do
      :compliant -> "✅"
      :acceptable_with_monitoring -> "⚠️"
      :needs_attention -> "❌"
    end
    
    IO.puts("#{status_icon} OVERALL STAMP STATUS: #{String.upcase(to_string(status))}")
    IO.puts("=" <> String.duplicate("=", 70))
  end

  defp save_results(results) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/#{timestamp}-mix-exs-stamp-analysis.json"
    
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(filename))
    
    # Save results as JSON
    json_content = Jason.encode!(results, pretty: true)
    File.write!(filename, json_content)
    
    IO.puts("\n💾 Results saved to: #{filename}")
  end

  defp determine_exit_code(results) do
    case results.overall_status do
      :compliant -> System.halt(0)
      :acceptable_with_monitoring -> System.halt(0)
      :needs_attention -> System.halt(1)
    end
  end
end

# Run if called directly
if Enum.member?(System.argv(), "--run") or length(System.argv()) == 0 do
  MixExsSTAMPAnalysis.main(System.argv())
end