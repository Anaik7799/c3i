#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ComprehensiveMixAliasGapAnalysis do
  @moduledoc """
  Comprehensive Mix Alias Gap Analysis for Technology Stack Alignment
  
  Analyzes existing mix.exs aliases against comprehensive technology list:
  - SOPv5.11 + AEE Cybernetic Framework
  - GDE Goal-Directed Execution
  - TPS Toyota Production System
  - STAMP Safety Analysis
  - TDG Test-Driven Generation 
  - PHICS Container Hot-Reloading
  - NixOS Containers + Podman + Nix + Devenv.sh
  - Git and GitHub Integrated Intelligence
  - FPPS False Positive Pr__evention System
  - ExUnit + Property Testing (PropCheck + StreamData)
  - Wallaby E2E Testing
  - Credo + Dialyzer + Sobelow
  - Logging + Metrics + Observability (OpenTelemetry, SigNoz)
  """

  @comprehensive_tech_stack %{
    # Core Framework Technologies
    sopv511_aee: %{
      name: "SOPv5.11 + AEE Cybernetic Framework",
      __required_aliases: [
        "sopv51.execute", "sopv51.validate", "sopv51.status", "sopv51.analyze",
        "agent.coordinate", "cybernetic.compile", "cybernetic.workflow",
        "aee.deploy", "aee.monitor", "aee.50agent.status"
      ],
      description: "15-agent cybernetic execution with autonomous coordination"
    },
    gde: %{
      name: "GDE Goal-Directed Execution", 
      __required_aliases: [
        "gde.define", "gde.track", "gde.progress", "gde.intervene", 
        "gde.goals", "gde.status", "gde.dashboard", "gde.report"
      ],
      description: "Systematic goal-oriented execution with cybernetic feedback"
    },
    tps: %{
      name: "TPS Toyota Production System",
      __required_aliases: [
        "tps.rca", "tps.analyze", "tps.quality", "tps.jidoka", 
        "tps.kaizen", "tps.5level", "tps.continuous_improvement"
      ],
      description: "5-Level RCA, Jidoka, continuous improvement methodology"
    },
    stamp: %{
      name: "STAMP Safety Analysis",
      __required_aliases: [
        "stamp.validate", "stamp.stpa", "stamp.cast", "stamp.safety",
        "stamp.constraints", "stamp.monitor", "stamp.compliance"
      ],
      description: "Systems-theoretic safety analysis and validation"
    },
    tdg: %{
      name: "TDG Test-Driven Generation",
      __required_aliases: [
        "tdg.validate", "tdg.coverage", "tdg.generate", "tdg.enforce",
        "tdg.compliance", "tdg.audit", "tdg.report"
      ],
      description: "Test-first AI code generation with validation"
    },
    phics: %{
      name: "PHICS Container Hot-Reloading", 
      __required_aliases: [
        "phics.setup", "phics.validate", "phics.sync", "phics.status",
        "phics.hot_reload", "phics.container_dev", "phics.monitor"
      ],
      description: "Phoenix hot-reloading integration for containers"
    },
    nixos_containers: %{
      name: "NixOS Containers + Podman",
      __required_aliases: [
        "container.validate", "container.setup", "container.compliance",
        "nixos.build", "nixos.container", "podman.setup", "podman.status",
        "containers.health", "containers.orchestrate"
      ],
      description: "NixOS-only container infrastructure with Podman"
    },
    nix_devenv: %{
      name: "Nix + Devenv.sh Integration",
      __required_aliases: [
        "devenv.setup", "devenv.shell", "devenv.update", "devenv.validate",
        "nix.build", "nix.develop", "nix.update", "nix.gc"
      ],
      description: "Nix package management and DevEnv integration"
    },
    git_github: %{
      name: "Git and GitHub Integrated Intelligence", 
      __required_aliases: [
        "git.smart_commit", "git.branch_sync", "git.pr_create", "git.hooks",
        "github.ci_status", "github.deploy", "git.backup", "git.validate"
      ],
      description: "Intelligent Git workflows and GitHub integration"
    },
    fpps: %{
      name: "FPPS False Positive Pr__evention System",
      __required_aliases: [
        "fpps.validate", "fpps.audit", "fpps.consensus", "fpps.pattern_check",
        "fpps.ep110_pr__event", "fpps.multi_method", "fpps.drift_detect"
      ],
      description: "Multi-method validation to pr__event false positives"
    },
    property_testing: %{
      name: "Property Testing (PropCheck + StreamData)",
      __required_aliases: [
        "test.property", "test.propcheck", "test.stream__data", "test.shrinking",
        "property.coverage", "property.generate", "property.validate"
      ],
      description: "Comprehensive property-based testing framework"
    },
    exunit_wallaby: %{
      name: "ExUnit + Wallaby E2E Testing",
      __required_aliases: [
        "test.wallaby", "test.e2e", "test.browser", "test.integration",
        "wallaby.setup", "wallaby.screenshots", "wallaby.headless"
      ],
      description: "End-to-end browser testing with Wallaby"
    },
    quality_tools: %{
      name: "Credo + Dialyzer + Sobelow",
      __required_aliases: [
        "quality", "quality.full", "credo.strict", "dialyzer.comprehensive",
        "sobelow.security", "quality.dashboard", "quality.report"
      ],
      description: "Comprehensive code quality and security analysis"
    },
    observability: %{
      name: "Logging + Metrics + Observability",
      __required_aliases: [
        "telemetry.setup", "telemetry.dashboard", "metrics.export",
        "logging.structured", "observability.validate", "signoz.setup",
        "opentelemetry.validate", "metrics.collect", "traces.analyze"
      ],
      description: "Complete observability with OpenTelemetry and SigNoz"
    }
  }

  def main(args) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    
    IO.puts("🔍 COMPREHENSIVE MIX ALIAS GAP ANALYSIS")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Timestamp: #{timestamp}")
    IO.puts("Analyzing: SOPv5.11 + AEE + GDE + TPS + STAMP + TDG + PHICS + NixOS + Podman + Nix + Devenv + Git/GitHub + FPPS + Testing + Observability")
    IO.puts("")

    case args do
      ["--comprehensive"] -> execute_comprehensive_analysis()
      ["--report"] -> generate_analysis_report()
      ["--gaps-only"] -> analyze_gaps_only()
      ["--recommendations"] -> generate_recommendations()
      ["--implementation"] -> generate_implementation_plan()
      _ -> execute_comprehensive_analysis()
    end
  end

  def execute_comprehensive_analysis do
    IO.puts("📊 PHASE 1: Loading Current Mix Aliases")
    current_aliases = load_current_mix_aliases()
    IO.puts("✅ Loaded #{length(current_aliases)} existing aliases")
    
    IO.puts("\n📊 PHASE 2: Technology Stack Mapping")
    tech_mapping = analyze_technology_coverage(current_aliases)
    
    IO.puts("\n📊 PHASE 3: Gap Analysis")
    gaps = identify_gaps(current_aliases)
    
    IO.puts("\n📊 PHASE 4: Recommendations Generation")
    recommendations = generate_specific_recommendations(gaps)
    
    IO.puts("\n📊 PHASE 5: Implementation Priority")
    priorities = prioritize_implementations(gaps, recommendations)
    
    # Generate comprehensive report
    report = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      current_aliases: current_aliases,
      technology_coverage: tech_mapping,
      identified_gaps: gaps,
      recommendations: recommendations,
      implementation_priorities: priorities,
      summary: generate_executive_summary(tech_mapping, gaps, recommendations)
    }
    
    save_analysis_report(report)
    display_analysis_summary(report)
    
    :ok
  end

  def load_current_mix_aliases do
    # Parse mix.exs to extract current aliases
    mix_exs_path = "/home/an/dev/indrajaal-demo/mix.exs"
    
    if File.exists?(mix_exs_path) do
      mix_content = File.read!(mix_exs_path)
      
      # Extract aliases section (simplified parsing)
      aliases_section = extract_aliases_section(mix_content)
      parse_aliases(aliases_section)
    else
      []
    end
  end
  
  defp extract_aliases_section(content) do
    # Find aliases function and extract its content
    case Regex.run(~r/defp aliases.*?do\s*\[(.*?)\]/s, content, capture: :all_but_first) do
      [aliases_content] -> aliases_content
      _ -> ""
    end
  end
  
  defp parse_aliases(aliases_content) do
    # Extract alias patterns like "alias_name": [...]
    Regex.scan(~r/"([^"]+)":|([a-zA-Z_][a-zA-Z0-9_.]*):/, aliases_content)
    |> Enum.map(fn 
      [_, alias_name, ""] when alias_name != "" -> alias_name
      [_, "", alias_name] when alias_name != "" -> alias_name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def analyze_technology_coverage(current_aliases) do
    @comprehensive_tech_stack
    |> Enum.map(fn {tech_key, tech_config} ->
      __required = tech_config.__required_aliases
      existing = Enum.filter(__required, fn alias_name -> 
        alias_name in current_aliases or partial_match?(alias_name, current_aliases)
      end)
      
      coverage_percent = if length(__required) > 0 do
        (length(existing) / length(__required) * 100) |> Float.round(1)
      else
        0.0
      end
      
      status = cond do
        coverage_percent >= 80 -> :excellent
        coverage_percent >= 60 -> :good 
        coverage_percent >= 30 -> :partial
        true -> :missing
      end
      
      {tech_key, %{
        name: tech_config.name,
        description: tech_config.description,
        __required_count: length(__required),
        existing_count: length(existing), 
        coverage_percent: coverage_percent,
        status: status,
        existing_aliases: existing,
        missing_aliases: __required -- existing
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp partial_match?(__required_alias, current_aliases) do
    # Check for partial matches (e.g., "sopv51.execute" matches "sopv51.*")
    base = __required_alias |> String.split(".") |> hd()
    Enum.any?(current_aliases, &String.starts_with?(&1, base <> "."))
  end

  def identify_gaps(current_aliases) do
    @comprehensive_tech_stack
    |> Enum.map(fn {tech_key, tech_config} ->
      missing_aliases = tech_config.__required_aliases
      |> Enum.reject(fn alias_name -> 
        alias_name in current_aliases or partial_match?(alias_name, current_aliases)
      end)
      
      if length(missing_aliases) > 0 do
        {tech_key, %{
          technology: tech_config.name,
          missing_count: length(missing_aliases),
          missing_aliases: missing_aliases,
          priority: determine_priority(tech_key, missing_aliases),
          impact: assess_impact(tech_key)
        }}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end
  
  defp determine_priority(tech_key, missing_aliases) do
    # Priority based on technology importance and missing count
    base_priority = case tech_key do
      tech when tech in [:sopv511_aee, :phics, :nixos_containers] -> :critical
      tech when tech in [:tps, :stamp, :tdg, :observability] -> :high
      tech when tech in [:gde, :fpps, :quality_tools] -> :medium
      _ -> :low
    end
    
    # Adjust based on missing count
    case {base_priority, length(missing_aliases)} do
      {:critical, count} when count >= 4 -> :critical
      {:critical, _} -> :high
      {:high, count} when count >= 6 -> :critical
      {:high, _} -> :high
      {:medium, count} when count >= 8 -> :high
      {priority, _} -> priority
    end
  end
  
  defp assess_impact(tech_key) do
    case tech_key do
      :sopv511_aee -> "Blocks cybernetic execution and 15-agent coordination"
      :phics -> "Pr__events container hot-reloading development workflow"
      :nixos_containers -> "Compromises container-only infrastructure policy"
      :observability -> "Limits production monitoring and troubleshooting"
      :fpps -> "Risk of false positive incidents (EP-110 pr__evention)"
      :tps -> "Reduces systematic quality improvement capability"
      :stamp -> "Compromises safety analysis and constraint validation"
      :tdg -> "Affects AI code generation quality and validation"
      _ -> "Reduces development efficiency and workflow automation"
    end
  end

  def generate_specific_recommendations(gaps) do
    gaps
    |> Enum.map(fn {tech_key, gap_info} ->
      {tech_key, %{
        technology: gap_info.technology,
        recommended_aliases: generate_alias_implementations(tech_key, gap_info.missing_aliases),
        implementation_effort: estimate_effort(gap_info.missing_aliases),
        suggested_scripts: suggest_supporting_scripts(tech_key),
        integration_points: identify_integration_points(tech_key)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp generate_alias_implementations(tech_key, missing_aliases) do
    missing_aliases
    |> Enum.map(fn alias_name ->
      command_impl = case {tech_key, alias_name} do
        {:sopv511_aee, "aee.deploy"} -> 
          ["cmd elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --deploy"]
        {:sopv511_aee, "aee.monitor"} ->
          ["cmd elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --monitor"]
        {:sopv511_aee, "aee.50agent.status"} ->
          ["cmd elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status"]
        
        {:phics, "phics.setup"} ->
          ["cmd elixir scripts/pcis/containers/setup_phoenix_container.exs --enable-phics"]
        {:phics, "phics.validate"} ->
          ["cmd elixir scripts/pcis/validation_cli.exs --phics-compliance"]
        {:phics, "phics.sync"} ->
          ["cmd elixir scripts/pcis/hot_reload_sync.exs --bidirectional"]
        {:phics, "phics.status"} ->
          ["cmd elixir scripts/pcis/validation_cli.exs --status"]
        
        {:nixos_containers, "nixos.build"} ->
          ["cmd nix-build containers/nixos-containers.nix"]
        {:nixos_containers, "nixos.container"} ->
          ["cmd elixir scripts/containers/verified_nixos_setup.exs --comprehensive"]
        {:nixos_containers, "podman.setup"} ->
          ["cmd elixir scripts/containers/podman_setup_validator.exs --setup"]
        {:nixos_containers, "podman.status"} ->
          ["cmd podman ps -a", "cmd podman stats --no-stream"]
        {:nixos_containers, "containers.health"} ->
          ["cmd elixir scripts/containers/comprehensive_health_monitor.exs"]
        {:nixos_containers, "containers.orchestrate"} ->
          ["cmd elixir scripts/containers/container_orchestrator.exs --start-all"]
        
        {:nix_devenv, "devenv.setup"} ->
          ["cmd devenv init", "devenv.shell"]
        {:nix_devenv, "devenv.shell"} ->
          ["cmd devenv shell"]
        {:nix_devenv, "devenv.update"} ->
          ["cmd devenv update"]
        {:nix_devenv, "devenv.validate"} ->
          ["cmd elixir scripts/devenv/devenv_validator.exs --comprehensive"]
        {:nix_devenv, "nix.build"} ->
          ["cmd nix build"]
        {:nix_devenv, "nix.develop"} ->
          ["cmd nix develop"]
        {:nix_devenv, "nix.update"} ->
          ["cmd nix flake update"]
        {:nix_devenv, "nix.gc"} ->
          ["cmd nix-collect-garbage -d"]
        
        {:git_github, "git.smart_commit"} ->
          ["cmd elixir scripts/git/smart_commit_creator.exs"]
        {:git_github, "git.branch_sync"} ->
          ["cmd elixir scripts/git/branch_synchronizer.exs"]
        {:git_github, "git.pr_create"} ->
          ["cmd elixir scripts/git/pr_creator.exs --comprehensive"]
        {:git_github, "git.hooks"} ->
          ["cmd elixir scripts/git/hook_installer.exs --all"]
        {:git_github, "github.ci_status"} ->
          ["cmd elixir scripts/github/ci_status_checker.exs"]
        {:git_github, "github.deploy"} ->
          ["cmd elixir scripts/github/deployment_orchestrator.exs"]
        {:git_github, "git.backup"} ->
          ["cmd elixir scripts/git/comprehensive_backup.exs --create"]
        {:git_github, "git.validate"} ->
          ["cmd elixir scripts/git/repository_validator.exs --comprehensive"]
        
        {:fpps, "fpps.validate"} ->
          ["cmd elixir scripts/validation/comprehensive_compilation_validator.exs --save-report"]
        {:fpps, "fpps.audit"} ->
          ["cmd elixir scripts/validation/daily_validation_audit.exs"]
        {:fpps, "fpps.consensus"} ->
          ["cmd elixir scripts/validation/unified_validation_command_center.exs consensus"]
        {:fpps, "fpps.pattern_check"} ->
          ["cmd elixir scripts/validation/pattern_validation_engine.exs --comprehensive"]
        {:fpps, "fpps.ep110_pr__event"} ->
          ["cmd elixir scripts/validation/ep110_pr__evention_system.exs --validate"]
        {:fpps, "fpps.multi_method"} ->
          ["cmd elixir scripts/validation/multi_method_validator.exs --all-methods"]
        {:fpps, "fpps.drift_detect"} ->
          ["cmd elixir scripts/validation/drift_detection_system.exs --monitor"]
        
        {:property_testing, "test.property"} ->
          ["test --only property"]
        {:property_testing, "test.propcheck"} ->
          ["cmd elixir scripts/testing/propcheck_runner.exs --comprehensive"]
        {:property_testing, "test.stream__data"} ->
          ["cmd elixir scripts/testing/stream__data_runner.exs --generate"]
        {:property_testing, "test.shrinking"} ->
          ["cmd elixir scripts/testing/shrinking_validator.exs --advanced"]
        {:property_testing, "property.coverage"} ->
          ["cmd elixir scripts/testing/property_coverage_analyzer.exs"]
        {:property_testing, "property.generate"} ->
          ["cmd elixir scripts/testing/property_generator.exs --create-tests"]
        {:property_testing, "property.validate"} ->
          ["cmd elixir scripts/testing/property_validator.exs --comprehensive"]
        
        {:observability, "telemetry.setup"} ->
          ["cmd elixir scripts/telemetry/telemetry_setup.exs --comprehensive"]
        {:observability, "telemetry.dashboard"} ->
          ["cmd elixir scripts/telemetry/dashboard_launcher.exs --signoz"]
        {:observability, "metrics.export"} ->
          ["cmd elixir scripts/telemetry/metrics_exporter.exs --format prometheus"]
        {:observability, "logging.structured"} ->
          ["cmd elixir scripts/logging/structured_logger_setup.exs"]
        {:observability, "observability.validate"} ->
          ["cmd elixir scripts/observability/comprehensive_validator.exs"]
        {:observability, "signoz.setup"} ->
          ["cmd elixir scripts/observability/signoz_setup.exs --docker-compose"]
        {:observability, "opentelemetry.validate"} ->
          ["cmd elixir scripts/telemetry/otel_validator.exs --comprehensive"]
        {:observability, "metrics.collect"} ->
          ["cmd elixir scripts/telemetry/metrics_collector.exs --start"]
        {:observability, "traces.analyze"} ->
          ["cmd elixir scripts/telemetry/trace_analyzer.exs --comprehensive"]
        
        {_, alias_name} ->
          # Generic implementation for unspecified aliases
          script_name = alias_name |> String.replace(".", "_")
          ["cmd elixir scripts/#{tech_key}/#{script_name}.exs"]
      end
      
      %{
        alias_name: alias_name,
        implementation: command_impl,
        description: generate_alias_description(tech_key, alias_name)
      }
    end)
  end
  
  defp generate_alias_description(tech_key, alias_name) do
    case {tech_key, alias_name} do
      {:sopv511_aee, "aee.deploy"} -> "Deploy 15-agent autonomous execution architecture"
      {:sopv511_aee, "aee.monitor"} -> "Monitor 15-agent coordination in real-time"  
      {:sopv511_aee, "aee.50agent.status"} -> "Check status of all 15 agents"
      {:phics, "phics.setup"} -> "Setup Phoenix hot-reloading in containers"
      {:phics, "phics.validate"} -> "Validate PHICS container integration"
      {:nixos_containers, "nixos.build"} -> "Build NixOS container images"
      {:nixos_containers, "podman.status"} -> "Check Podman container status"
      {:git_github, "git.smart_commit"} -> "Create intelligent commit with AI analysis"
      {:fpps, "fpps.validate"} -> "Run false positive pr__evention validation"
      {:observability, "telemetry.setup"} -> "Setup comprehensive telemetry stack"
      _ -> "Execute #{alias_name} functionality"
    end
  end
  
  defp estimate_effort(missing_aliases) do
    count = length(missing_aliases)
    cond do
      count <= 2 -> %{level: :low, hours: "2-4 hours", description: "Simple script creation"}
      count <= 4 -> %{level: :medium, hours: "1-2 days", description: "Multiple script development"}
      count <= 6 -> %{level: :high, hours: "3-5 days", description: "Complex integration work"}
      true -> %{level: :very_high, hours: "1-2 weeks", description: "Comprehensive framework implementation"}
    end
  end
  
  defp suggest_supporting_scripts(tech_key) do
    case tech_key do
      :sopv511_aee -> [
        "scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs",
        "scripts/coordination/agent_health_monitor.exs",
        "scripts/coordination/cybernetic_coordinator.exs"
      ]
      :phics -> [
        "scripts/pcis/hot_reload_sync.exs",
        "scripts/pcis/container_file_watcher.exs", 
        "scripts/pcis/bidirectional_sync_manager.exs"
      ]
      :nixos_containers -> [
        "scripts/containers/nixos_container_builder.exs",
        "scripts/containers/podman_orchestrator.exs",
        "scripts/containers/container_health_monitor.exs"
      ]
      :fpps -> [
        "scripts/validation/multi_method_consensus_validator.exs",
        "scripts/validation/false_positive_detector.exs",
        "scripts/validation/ep110_pr__evention_engine.exs"
      ]
      :observability -> [
        "scripts/telemetry/signoz_integration.exs",
        "scripts/telemetry/otel_setup_comprehensive.exs",
        "scripts/observability/metrics_dashboard.exs"
      ]
      _ -> []
    end
  end
  
  defp identify_integration_points(tech_key) do
    case tech_key do
      :sopv511_aee -> ["Existing sopv51.* aliases", "agent.* aliases", "cybernetic.* aliases"]
      :phics -> ["container.* aliases", "Demo aliases", "Development workflow"]
      :nixos_containers -> ["Container compliance aliases", "PHICS integration", "Demo system"]
      :fpps -> ["Quality aliases", "Validation system", "Compilation workflow"]  
      :observability -> ["Telemetry setup", "Monitoring dashboard", "Production deployment"]
      _ -> []
    end
  end

  def prioritize_implementations(gaps, recommendations) do
    gaps
    |> Enum.map(fn {tech_key, gap_info} ->
      rec = recommendations[tech_key]
      
      priority_score = calculate_priority_score(gap_info.priority, gap_info.missing_count, tech_key)
      
      {tech_key, %{
        technology: gap_info.technology,
        priority: gap_info.priority,
        priority_score: priority_score,
        missing_count: gap_info.missing_count,
        estimated_effort: rec.implementation_effort,
        business_impact: gap_info.impact,
        implementation_order: determine_implementation_order(tech_key, gap_info.priority)
      }}
    end)
    |> Enum.sort_by(fn {_, info} -> -info.priority_score end)
  end
  
  defp calculate_priority_score(priority, missing_count, tech_key) do
    base_score = case priority do
      :critical -> 100
      :high -> 80
      :medium -> 60
      :low -> 40
    end
    
    # Adjust for missing count
    count_multiplier = min(missing_count * 0.1, 0.5)
    
    # Adjust for technology strategic importance
    strategic_bonus = case tech_key do
      tech when tech in [:sopv511_aee, :phics, :nixos_containers] -> 20
      tech when tech in [:fpps, :observability, :tps, :stamp] -> 10
      _ -> 0
    end
    
    base_score + (base_score * count_multiplier) + strategic_bonus
  end
  
  defp determine_implementation_order(tech_key, priority) do
    case {tech_key, priority} do
      {tech, :critical} when tech in [:sopv511_aee, :phics, :nixos_containers] -> 1
      {tech, :high} when tech in [:sopv511_aee, :phics, :nixos_containers] -> 2
      {:fpps, :critical} -> 2
      {:observability, :critical} -> 3
      {_, :critical} -> 3
      {_, :high} -> 4
      {_, :medium} -> 5
      _ -> 6
    end
  end

  def generate_executive_summary(tech_mapping, gaps, _recommendations) do
    total_technologies = map_size(@comprehensive_tech_stack)
    technologies_with_gaps = map_size(gaps)
    total_missing_aliases = gaps |> Map.values() |> Enum.map(&(&1.missing_count)) |> Enum.sum()
    
    critical_gaps = gaps |> Enum.filter(fn {_, info} -> info.priority == :critical end) |> length()
    high_priority_gaps = gaps |> Enum.filter(fn {_, info} -> info.priority == :high end) |> length()
    
    coverage_stats = tech_mapping
    |> Map.values()
    |> Enum.group_by(&(&1.status))
    |> Enum.map(fn {status, techs} -> {status, length(techs)} end)
    |> Enum.into(%{})
    
    %{
      overall_assessment: %{
        total_technologies: total_technologies,
        technologies_with_gaps: technologies_with_gaps,
        gap_percentage: Float.round(technologies_with_gaps / total_technologies * 100, 1),
        total_missing_aliases: total_missing_aliases,
        critical_gaps: critical_gaps,
        high_priority_gaps: high_priority_gaps
      },
      coverage_breakdown: coverage_stats,
      top_priorities: [
        "SOPv5.11 + AEE Cybernetic Framework enhancement",
        "PHICS container hot-reloading integration",
        "NixOS container infrastructure completion",
        "FPPS false positive pr__evention system",
        "Observability and monitoring stack"
      ],
      immediate_actions: [
        "Implement missing SOPv5.11 AEE aliases for 15-agent coordination",
        "Add PHICS aliases for container development workflow",
        "Create NixOS/Podman management aliases",
        "Develop FPPS validation and consensus aliases",
        "Setup comprehensive observability aliases"
      ],
      business_impact: "Completing these gaps will enable full SOPv5.11 cybernetic execution, container-native development, and enterprise-grade observability"
    }
  end

  def save_analysis_report(report) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    filename = "./__data/tmp/#{timestamp}-comprehensive-mix-alias-gap-analysis-report.json"
    
    # Convert tuples to maps for JSON serialization
    serializable_report = %{
      timestamp: report.timestamp,
      current_aliases: report.current_aliases,
      technology_coverage: report.technology_coverage,
      identified_gaps: convert_map_to_serializable(report.identified_gaps),
      recommendations: convert_map_to_serializable(report.recommendations),
      implementation_priorities: convert_priorities_to_serializable(report.implementation_priorities),
      summary: report.summary
    }
    
    File.write!(filename, Jason.encode!(serializable_report, pretty: true))
    IO.puts("📄 Analysis report saved to: #{filename}")
  end
  
  defp convert_map_to_serializable(map_data) when is_map(map_data) do
    map_data
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end
  
  defp convert_priorities_to_serializable(priorities) when is_list(priorities) do
    priorities
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.into(%{})
  end

  def display_analysis_summary(report) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🏆 COMPREHENSIVE MIX ALIAS GAP ANALYSIS - EXECUTIVE SUMMARY")
    IO.puts(String.duplicate("=", 80))
    
    summary = report.summary
    
    IO.puts("📊 OVERALL ASSESSMENT:")
    IO.puts("   • Technologies Analyzed: #{summary.overall_assessment.total_technologies}")
    IO.puts("   • Technologies with Gaps: #{summary.overall_assessment.technologies_with_gaps}")
    IO.puts("   • Gap Percentage: #{summary.overall_assessment.gap_percentage}%")
    IO.puts("   • Total Missing Aliases: #{summary.overall_assessment.total_missing_aliases}")
    IO.puts("   • Critical Priority Gaps: #{summary.overall_assessment.critical_gaps}")
    IO.puts("   • High Priority Gaps: #{summary.overall_assessment.high_priority_gaps}")
    
    IO.puts("\n📈 TECHNOLOGY COVERAGE BREAKDOWN:")
    coverage = summary.coverage_breakdown
    [:excellent, :good, :partial, :missing]
    |> Enum.each(fn status ->
      count = Map.get(coverage, status, 0)
      percentage = if summary.overall_assessment.total_technologies > 0 do
        Float.round(count / summary.overall_assessment.total_technologies * 100, 1)
      else
        0.0
      end
      
      status_icon = case status do
        :excellent -> "🟢"
        :good -> "🟡" 
        :partial -> "🟠"
        :missing -> "🔴"
      end
      
      IO.puts("   #{status_icon} #{String.capitalize(to_string(status))}: #{count} technologies (#{percentage}%)")
    end)
    
    IO.puts("\n🎯 TOP IMPLEMENTATION PRIORITIES:")
    summary.top_priorities
    |> Enum.with_index(1)
    |> Enum.each(fn {priority, index} ->
      IO.puts("   #{index}. #{priority}")
    end)
    
    IO.puts("\n⚡ IMMEDIATE ACTION ITEMS:")
    summary.immediate_actions
    |> Enum.with_index(1)
    |> Enum.each(fn {action, index} ->
      IO.puts("   #{index}. #{action}")
    end)
    
    IO.puts("\n💰 BUSINESS IMPACT:")
    IO.puts("   #{summary.business_impact}")
    
    IO.puts("\n🔧 CRITICAL MISSING ALIASES BY TECHNOLOGY:")
    report.identified_gaps
    |> Enum.filter(fn {_, info} -> info.priority in [:critical, :high] end)
    |> Enum.sort_by(fn {_, info} -> info.missing_count end, :desc)
    |> Enum.take(5)
    |> Enum.each(fn {_tech_key, gap_info} ->
      IO.puts("   🚨 #{gap_info.technology}: #{gap_info.missing_count} missing aliases")
      gap_info.missing_aliases
      |> Enum.take(3)
      |> Enum.each(fn alias_name ->
        IO.puts("      - #{alias_name}")
      end)
      if length(gap_info.missing_aliases) > 3 do
        IO.puts("      - ... and #{length(gap_info.missing_aliases) - 3} more")
      end
    end)
    
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("✅ ANALYSIS COMPLETE - Ready for implementation planning")
    IO.puts(String.duplicate("=", 80))
  end

  def generate_analysis_report do
    execute_comprehensive_analysis()
  end

  def analyze_gaps_only do
    current_aliases = load_current_mix_aliases()
    gaps = identify_gaps(current_aliases)
    
    IO.puts("🔍 IDENTIFIED GAPS BY TECHNOLOGY:")
    IO.puts(String.duplicate("-", 60))
    
    gaps
    |> Enum.sort_by(fn {_, info} -> info.missing_count end, :desc)
    |> Enum.each(fn {_tech_key, gap_info} ->
      priority_icon = case gap_info.priority do
        :critical -> "🚨"
        :high -> "⚠️"
        :medium -> "📋"
        :low -> "ℹ️"
      end
      
      IO.puts("#{priority_icon} #{gap_info.technology}")
      IO.puts("   Priority: #{String.upcase(to_string(gap_info.priority))}")
      IO.puts("   Missing: #{gap_info.missing_count} aliases")
      IO.puts("   Impact: #{gap_info.impact}")
      IO.puts("   Aliases: #{Enum.join(gap_info.missing_aliases, ", ")}")
      IO.puts("")
    end)
  end

  def generate_recommendations do
    current_aliases = load_current_mix_aliases()
    gaps = identify_gaps(current_aliases)
    recommendations = generate_specific_recommendations(gaps)
    
    IO.puts("💡 IMPLEMENTATION RECOMMENDATIONS:")
    IO.puts(String.duplicate("-", 60))
    
    recommendations
    |> Enum.each(fn {_tech_key, rec_info} ->
      IO.puts("🔧 #{rec_info.technology}")
      IO.puts("   Effort: #{rec_info.implementation_effort.level} (#{rec_info.implementation_effort.hours})")
      IO.puts("   #{rec_info.implementation_effort.description}")
      
      if length(rec_info.recommended_aliases) > 0 do
        IO.puts("   Recommended aliases:")
        rec_info.recommended_aliases
        |> Enum.take(3)
        |> Enum.each(fn alias_rec ->
          IO.puts("     • #{alias_rec.alias_name}: #{alias_rec.description}")
        end)
      end
      
      if length(rec_info.suggested_scripts) > 0 do
        IO.puts("   Supporting scripts needed:")
        rec_info.suggested_scripts
        |> Enum.each(fn script ->
          IO.puts("     - #{script}")
        end)
      end
      
      IO.puts("")
    end)
  end

  def generate_implementation_plan do
    current_aliases = load_current_mix_aliases()
    gaps = identify_gaps(current_aliases)
    recommendations = generate_specific_recommendations(gaps)
    priorities = prioritize_implementations(gaps, recommendations)
    
    IO.puts("📋 IMPLEMENTATION PLAN:")
    IO.puts(String.duplicate("=", 60))
    
    priorities
    |> Enum.group_by(fn {_, info} -> info.implementation_order end)
    |> Enum.sort_by(fn {order, _} -> order end)
    |> Enum.each(fn {order, phase_items} ->
      IO.puts("🏗️  PHASE #{order} IMPLEMENTATION:")
      
      phase_items
      |> Enum.each(fn {_tech_key, info} ->
        priority_icon = case info.priority do
          :critical -> "🚨"
          :high -> "⚠️"
          :medium -> "📋"
          :low -> "ℹ️"
        end
        
        IO.puts("   #{priority_icon} #{info.technology}")
        IO.puts("      Missing: #{info.missing_count} aliases")
        IO.puts("      Effort: #{info.estimated_effort.level} (#{info.estimated_effort.hours})")
        IO.puts("      Impact: #{info.business_impact}")
      end)
      
      IO.puts("")
    end)
    
    # Generate specific next steps
    IO.puts("🎯 IMMEDIATE NEXT STEPS:")
    next_phase = priorities
    |> Enum.filter(fn {_, info} -> info.implementation_order == 1 end)
    |> Enum.take(3)
    
    next_phase
    |> Enum.with_index(1)
    |> Enum.each(fn {{tech_key, info}, index} ->
      rec = recommendations[tech_key]
      IO.puts("#{index}. #{info.technology}")
      IO.puts("   Create #{length(rec.recommended_aliases)} new mix aliases")
      IO.puts("   Develop #{length(rec.suggested_scripts)} supporting scripts")
      IO.puts("   Integrate with: #{Enum.join(rec.integration_points, ", ")}")
    end)
  end
end

# Execute the analysis
ComprehensiveMixAliasGapAnalysis.main(System.argv())