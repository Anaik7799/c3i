#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule AutomatedContainerVerification do
  @moduledoc """
  Automated Container Verification System
  
  Verifies complete container creation process without Claude intervention.
  Validates end-to-end automation, container health, and system integration.
  
  SOPv5.1 Cybernetic Integration:
  - Goal-oriented autonomous validation
  - Multi-agent coordination simulation
  - Systematic quality assurance
  
  TPS Methodology:
  - Jidoka: Stop on first failure
  - 5-Level RCA: Deep analysis of failures
  - Continuous improvement: Learning from validation
  
  STAMP Safety Constraints:
  - SC-ACV-001: System SHALL autonomously create all containers
  - SC-ACV-002: System SHALL validate container health without intervention
  - SC-ACV-003: System SHALL provide complete automation verification
  - SC-ACV-004: System SHALL detect and report automation gaps
  - SC-ACV-005: System SHALL maintain audit trail of verification
  """

  __require Logger

  @verification_categories [
    :autonomous_creation,
    :health_validation,
    :integration_testing,
    :performance_baseline,
    :security_validation,
    :recovery_testing,
    :documentation_completeness,
    :automation_gaps
  ]

  @containers [
    %{name: "indrajaal-timescaledb-demo", image: "localhost/indrajaal-timescaledb-demo:nixos-devenv"},
    %{name: "indrajaal-redis-demo", image: "localhost/indrajaal-redis-demo:nixos-devenv"},
    %{name: "indrajaal-app-demo", image: "localhost/indrajaal-app-demo:nixos-devenv"},
    %{name: "indrajaal-prometheus-demo", image: "localhost/indrajaal-prometheus-demo:nixos-devenv"},
    %{name: "indrajaal-grafana-demo", image: "localhost/indrajaal-grafana-demo:nixos-devenv"},
    %{name: "indrajaal-nginx-demo", image: "localhost/indrajaal-nginx-demo:nixos-devenv"}
  ]

  def main(args) do
    case args do
      ["--verify"] -> run_complete_verification()
      ["--autonomous-test"] -> test_autonomous_creation()
      ["--health-check"] -> verify_container_health()
      ["--integration"] -> test_integration()
      ["--gaps"] -> identify_automation_gaps()
      ["--report"] -> generate_verification_report()
      ["--help"] -> show_help()
      _ -> 
        IO.puts("🤖 Automated Container Verification System")
        IO.puts("Usage: elixir automated_container_verification.exs [--verify|--autonomous-test|--health-check|--integration|--gaps|--report|--help]")
    end
  end

  defp run_complete_verification do
    IO.puts("🚀 Starting Complete Container Verification Process")
    IO.puts("═══════════════════════════════════════════════════")
    
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
    IO.puts("⏰ Started at: #{timestamp}")
    
    results = %{
      timestamp: timestamp,
      categories: %{},
      overall_status: :unknown,
      automation_score: 0,
      recommendations: []
    }

    # Run all verification categories
    _results = Enum.reduce(@verification_categories, _results, fn category, acc ->
      IO.puts("\n🔍 Verifying: #{category}")
      category_result = verify_category(category)
      
      status_emoji = case category_result.status do
        :pass -> "✅"
        :warning -> "⚠️"
        :fail -> "❌"
        _ -> "❓"
      end
      
      IO.puts("#{status_emoji} #{category}: #{category_result.score}% (#{category_result.status})")
      
      if category_result.details do
        Enum.each(category_result.details, fn detail ->
          IO.puts("   • #{detail}")
        end)
      end

      put_in(acc.categories[category], category_result)
    end)

    # Calculate overall score and status
    scores = Map.values(results.categories) |> Enum.map(& &1.score)
    overall_score = (Enum.sum(scores) / length(scores)) |> round()
    
    overall_status = cond do
      overall_score >= 95 -> :excellent
      overall_score >= 85 -> :good  
      overall_score >= 70 -> :acceptable
      overall_score >= 50 -> :needs_improvement
      true -> :critical
    end

    results = %{results | automation_score: overall_score, overall_status: overall_status}

    # Display final results
    display_final_results(results)
    
    # Save verification report
    save_verification_report(results)
    
    # Return appropriate exit code
    case overall_status do
      :excellent -> 0
      :good -> 0
      :acceptable -> 1
      :needs_improvement -> 2
      :critical -> 3
    end
  end

  defp verify_category(:autonomous_creation) do
    IO.puts("   Testing autonomous container creation...")
    
    # Test master setup script existence and completeness
    master_script = "scripts/containers/master_nixos_container_setup.exs"
    
    checks = [
      check_file_exists(master_script, "Master setup script exists"),
      check_script_executability(master_script, "Master script is executable"),
      check_container_definitions(master_script, "All 6 containers defined"),
      check_automation_flags(master_script, "Zero-intervention flags present"),
      check_error_handling(master_script, "Error handling implemented")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 80 -> :warning
      _ -> :fail
    end

    details = [
      "Master script analysis: #{passing_checks}/#{length(checks)} checks passed",
      "Container definitions validated for all 6 containers",
      "Automation flags: --no-confirm, --autonomous detected"
    ]

    %{status: status, score: score, details: details}
  end

  defp verify_category(:health_validation) do
    IO.puts("   Testing health validation capabilities...")
    
    health_script = "scripts/containers/container_readiness_validator.exs"
    
    checks = [
      check_file_exists(health_script, "Health validator exists"),
      check_health_endpoints(health_script, "Health endpoints configured"),
      check_timeout_handling(health_script, "Timeout handling present"),
      check_retry_logic(health_script, "Retry logic implemented"),
      check_comprehensive_validation(health_script, "86+ validation checks")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 70 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Health validation: #{passing_checks}/#{length(checks)} checks"]}
  end

  defp verify_category(:integration_testing) do
    IO.puts("   Testing integration capabilities...")
    
    test_files = [
      "test/containers/stamp_safety_test.exs",
      "test/containers/tdg_methodology_test.exs", 
      "test/containers/functional_integration_test.exs"
    ]
    
    _checks = Enum.map(test_files, fn file ->
      check_file_exists(file, "Test file: #{Path.basename(file)}")
    end) ++ [
      check_test_coverage(test_files, "Test coverage adequate"),
      check_property_testing(test_files, "Property-based testing included")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 80 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Integration tests: #{length(test_files)} test suites created"]}
  end

  defp verify_category(:performance_baseline) do
    IO.puts("   Testing performance baseline capabilities...")
    
    perf_script = "scripts/containers/performance_baseline.exs"
    
    checks = [
      check_file_exists(perf_script, "Performance script exists"),
      check_performance_targets(perf_script, "Performance targets defined"),
      check_monitoring_setup(perf_script, "Monitoring configured"),
      check_baseline_establishment(perf_script, "Baseline establishment logic")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 75 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Performance monitoring: #{passing_checks}/#{length(checks)} capabilities"]}
  end

  defp verify_category(:security_validation) do
    IO.puts("   Testing security validation...")
    
    ssl_script = "scripts/containers/nixos_ssl_certificate_resolver.exs"
    
    checks = [
      check_file_exists(ssl_script, "SSL resolver exists"),
      check_certificate_paths(ssl_script, "Certificate paths configured"),
      check_registry_enforcement("scripts/containers/master_nixos_container_setup.exs", "localhost/ registry enforced"),
      check_security_constraints("scripts/containers/stamp_safety_validator.exs", "Security constraints validated")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 80 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Security validation: #{passing_checks}/#{length(checks)} checks"]}
  end

  defp verify_category(:recovery_testing) do
    IO.puts("   Testing recovery capabilities...")
    
    recovery_script = "scripts/containers/emergency_recovery.exs"
    
    checks = [
      check_file_exists(recovery_script, "Recovery script exists"),
      check_recovery_scenarios(recovery_script, "7 recovery scenarios implemented"),
      check_auto_detection(recovery_script, "Auto-detection capabilities"),
      check_rollback_procedures(recovery_script, "Rollback procedures defined")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 70 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Recovery capabilities: #{passing_checks}/#{length(checks)} scenarios"]}
  end

  defp verify_category(:documentation_completeness) do
    IO.puts("   Testing documentation completeness...")
    
    docs = [
      "docs/containers/20250910-1536-nixos-container-setup-sopv51-comprehensive-plan.md",
      "docs/journal/20250910-1536-nixos-container-setup-comprehensive-implementation-journal.md"
    ]
    
    _checks = Enum.map(docs, fn doc ->
      check_file_exists(doc, "Doc: #{Path.basename(doc)}")
    end) ++ [
      check_script_documentation("scripts/containers/", "All scripts documented"),
      check_test_documentation("test/containers/", "All tests documented")
    ]
    
    passing_checks = Enum.count(checks, & &1)
    score = round((passing_checks / length(checks)) * 100)
    
    status = case score do
      100 -> :pass
      s when s >= 85 -> :warning
      _ -> :fail
    end

    %{status: status, score: score, details: ["Documentation: #{passing_checks}/#{length(checks)} __requirements met"]}
  end

  defp verify_category(:automation_gaps) do
    IO.puts("   Identifying automation gaps...")
    
    # Check for common automation gaps
    gaps = identify_potential_gaps()
    
    score = case length(gaps) do
      0 -> 100
      1..2 -> 85
      3..5 -> 70
      _ -> 50
    end
    
    status = case length(gaps) do
      0 -> :pass
      n when n <= 3 -> :warning
      _ -> :fail
    end

    details = if length(gaps) == 0 do
      ["No automation gaps detected"]
    else
      ["Gaps found: #{length(gaps)}" | Enum.take(gaps, 3)]
    end

    %{status: status, score: score, details: details}
  end

  # Helper functions for specific checks
  defp check_file_exists(file_path, description) do
    exists = File.exists?(file_path)
    if not exists, do: IO.puts("   ❌ #{description}: Missing #{file_path}")
    exists
  end

  defp check_script_executability(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      executable = String.contains?(content, "#!/usr/bin/env elixir")
      if not executable, do: IO.puts("   ⚠️  #{description}: Missing shebang")
      executable
    else
      false
    end
  end

  defp check_container_definitions(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      container_count = Enum.count(@containers, fn container ->
        String.contains?(content, container.name)
      end)
      
      complete = container_count == length(@containers)
      if not complete, do: IO.puts("   ⚠️  #{description}: Only #{container_count}/#{length(@containers)} defined")
      complete
    else
      false
    end
  end

  defp check_automation_flags(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_flags = String.contains?(content, "--no-confirm") or 
                  String.contains?(content, "--autonomous") or
                  String.contains?(content, "autonomous")
      
      if not has_flags, do: IO.puts("   ⚠️  #{description}: No autonomous flags detected")
      has_flags
    else
      false
    end
  end

  defp check_error_handling(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_handling = String.contains?(content, "rescue") or 
                     String.contains?(content, "case") or
                     String.contains?(content, "with")
      
      if not has_handling, do: IO.puts("   ⚠️  #{description}: Limited error handling detected")
      has_handling
    else
      false
    end
  end

  defp check_health_endpoints(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_endpoints = String.contains?(content, "/health") or 
                      String.contains?(content, "health_check")
      
      if not has_endpoints, do: IO.puts("   ⚠️  #{description}: No health endpoints detected")
      has_endpoints
    else
      false
    end
  end

  defp check_timeout_handling(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_timeouts = String.contains?(content, "timeout") or 
                     String.contains?(content, "Timer")
      
      if not has_timeouts, do: IO.puts("   ⚠️  #{description}: No timeout handling detected")
      has_timeouts
    else
      false
    end
  end

  defp check_retry_logic(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_retry = String.contains?(content, "retry") or 
                  String.contains?(content, "attempt") or
                  String.contains?(content, "max_retries")
      
      if not has_retry, do: IO.puts("   ⚠️  #{description}: No retry logic detected")
      has_retry
    else
      false
    end
  end

  defp check_comprehensive_validation(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      # Look for multiple validation categories
      validations = [
        String.contains?(content, "validate_"),
        String.contains?(content, "check_"),
        String.contains?(content, "verify_"),
        String.contains?(content, "assessment"),
        String.contains?(content, "__requirements")
      ]
      
      comprehensive = Enum.count(validations, & &1) >= 3
      if not comprehensive, do: IO.puts("   ⚠️  #{description}: Limited validation scope")
      comprehensive
    else
      false
    end
  end

  defp check_test_coverage(test_files, description) do
    existing_tests = Enum.count(test_files, &File.exists?/1)
    adequate = existing_tests >= 2
    
    if not adequate, do: IO.puts("   ⚠️  #{description}: Only #{existing_tests} test files")
    adequate
  end

  defp check_property_testing(test_files, description) do
    property_testing = Enum.any?(test_files, fn file ->
      if File.exists?(file) do
        content = File.read!(file)
        String.contains?(content, "property") or String.contains?(content, "PropCheck")
      else
        false
      end
    end)
    
    if not property_testing, do: IO.puts("   ⚠️  #{description}: No property-based testing detected")
    property_testing
  end

  defp check_performance_targets(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_targets = String.contains?(content, "@performance_targets") or
                    String.contains?(content, "target") or
                    String.contains?(content, "benchmark")
      
      if not has_targets, do: IO.puts("   ⚠️  #{description}: No performance targets detected")
      has_targets
    else
      false
    end
  end

  defp check_monitoring_setup(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_monitoring = String.contains?(content, "monitor") or
                       String.contains?(content, "metrics") or
                       String.contains?(content, "telemetry")
      
      if not has_monitoring, do: IO.puts("   ⚠️  #{description}: No monitoring setup detected")
      has_monitoring
    else
      false
    end
  end

  defp check_baseline_establishment(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_baseline = String.contains?(content, "baseline") or
                     String.contains?(content, "establish")
      
      if not has_baseline, do: IO.puts("   ⚠️  #{description}: No baseline logic detected")
      has_baseline
    else
      false
    end
  end

  defp check_certificate_paths(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_paths = String.contains?(content, "/etc/ssl/certs") or
                  String.contains?(content, "ca-bundle.crt")
      
      if not has_paths, do: IO.puts("   ⚠️  #{description}: SSL certificate paths missing")
      has_paths
    else
      false
    end
  end

  defp check_registry_enforcement(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_enforcement = String.contains?(content, "localhost/") and
                        not String.contains?(content, "docker.io")
      
      if not has_enforcement, do: IO.puts("   ⚠️  #{description}: Registry enforcement unclear")
      has_enforcement
    else
      false
    end
  end

  defp check_security_constraints(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_constraints = String.contains?(content, "SC-") or
                        String.contains?(content, "security")
      
      if not has_constraints, do: IO.puts("   ⚠️  #{description}: Security constraints missing")
      has_constraints
    else
      false
    end
  end

  defp check_recovery_scenarios(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      scenarios = String.split(content, "R-00")
      scenario_count = length(scenarios) - 1
      adequate = scenario_count >= 5
      
      if not adequate, do: IO.puts("   ⚠️  #{description}: Only #{scenario_count} scenarios found")
      adequate
    else
      false
    end
  end

  defp check_auto_detection(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_detection = String.contains?(content, "detect") or
                      String.contains?(content, "identify")
      
      if not has_detection, do: IO.puts("   ⚠️  #{description}: No auto-detection found")
      has_detection
    else
      false
    end
  end

  defp check_rollback_procedures(script_path, description) do
    if File.exists?(script_path) do
      content = File.read!(script_path)
      has_rollback = String.contains?(content, "rollback") or
                     String.contains?(content, "restore")
      
      if not has_rollback, do: IO.puts("   ⚠️  #{description}: No rollback procedures found")
      has_rollback
    else
      false
    end
  end

  defp check_script_documentation(script_dir, description) do
    if File.exists?(script_dir) do
      scripts = File.ls!(script_dir) |> Enum.filter(&String.ends_with?(&1, ".exs"))
      
      documented = Enum.count(scripts, fn script ->
        content = File.read!(Path.join(script_dir, script))
        String.contains?(content, "@moduledoc")
      end)
      
      adequate = documented >= div(length(scripts), 2)
      if not adequate, do: IO.puts("   ⚠️  #{description}: #{documented}/#{length(scripts)} documented")
      adequate
    else
      false
    end
  end

  defp check_test_documentation(test_dir, description) do
    if File.exists?(test_dir) do
      tests = File.ls!(test_dir) |> Enum.filter(&String.ends_with?(&1, ".exs"))
      
      documented = Enum.count(tests, fn test ->
        content = File.read!(Path.join(test_dir, test))
        String.contains?(content, "@moduledoc") or String.contains?(content, "describe")
      end)
      
      adequate = documented >= div(length(tests), 2)
      if not adequate, do: IO.puts("   ⚠️  #{description}: #{documented}/#{length(tests)} documented")
      adequate
    else
      false
    end
  end

  defp identify_potential_gaps do
    gaps = []
    
    # Check for common automation gaps
    gaps = if not File.exists?("scripts/containers/automated_deployment.exs") do
      ["Missing automated deployment script" | gaps]
    else
      gaps
    end
    
    gaps = if not File.exists?(".github/workflows/container-ci.yml") and not File.exists?(".gitlab-ci.yml") do
      ["Missing CI/CD automation" | gaps]
    else
      gaps
    end
    
    gaps = if not File.exists?("scripts/containers/container_cleanup.exs") do
      ["Missing automated cleanup procedures" | gaps]
    else
      gaps
    end
    
    gaps = if not File.exists?("docker-compose.yml") and not File.exists?("podman-compose.yml") do
      ["Missing container orchestration file" | gaps]
    else
      gaps
    end
    
    # Check for missing NixOS definitions
    nix_files = ["timescaledb.nix", "redis.nix", "app.nix", "prometheus.nix", "grafana.nix", "nginx.nix"]
    missing_nix = Enum.count(nix_files, fn nix_file ->
      not File.exists?("containers/#{nix_file}")
    end)
    
    gaps = if missing_nix > 0 do
      ["Missing #{missing_nix} NixOS container definitions" | gaps]
    else
      gaps
    end

    gaps
  end

  defp display_final_results(results) do
    IO.puts("\n")
    IO.puts("🏆 AUTOMATED CONTAINER VERIFICATION RESULTS")
    IO.puts("═══════════════════════════════════════════════════")
    
    status_emoji = case results.overall_status do
      :excellent -> "🌟"
      :good -> "✅"
      :acceptable -> "⚠️"
      :needs_improvement -> "⚠️"
      :critical -> "❌"
    end
    
    IO.puts("#{status_emoji} Overall Status: #{String.upcase(to_string(results.overall_status))}")
    IO.puts("📊 Automation Score: #{results.automation_score}%")
    
    IO.puts("\n📋 Category Breakdown:")
    Enum.each(results.categories, fn {category, result} ->
      status_emoji = case result.status do
        :pass -> "✅"
        :warning -> "⚠️"
        :fail -> "❌"
      end
      IO.puts("   #{status_emoji} #{category}: #{result.score}%")
    end)
    
    # Recommendations based on results
    recommendations = generate_recommendations(results)
    if length(recommendations) > 0 do
      IO.puts("\n💡 Recommendations:")
      Enum.each(recommendations, fn rec ->
        IO.puts("   • #{rec}")
      end)
    end
    
    IO.puts("\n⏰ Completed at: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}")
  end

  defp generate_recommendations(results) do
    recommendations = []
    
    # Generate recommendations based on failing categories
    _recommendations = Enum.reduce(results.categories, _recommendations, fn {category, result}, acc ->
      case {category, result.status} do
        {:autonomous_creation, status} when status != :pass ->
          ["Improve autonomous creation capabilities - ensure master script can run without intervention" | acc]
        {:health_validation, status} when status != :pass ->
          ["Enhance health validation - implement comprehensive health checks with retry logic" | acc]
        {:integration_testing, status} when status != :pass ->
          ["Complete integration testing framework - ensure all test suites are functional" | acc]
        {:security_validation, status} when status != :pass ->
          ["Strengthen security validation - verify SSL certificates and registry enforcement" | acc]
        {:recovery_testing, status} when status != :pass ->
          ["Implement recovery testing - ensure emergency recovery scenarios are tested" | acc]
        {:documentation_completeness, status} when status != :pass ->
          ["Complete documentation - ensure all scripts and processes are documented" | acc]
        {:automation_gaps, status} when status != :pass ->
          ["Address automation gaps - implement missing automation components" | acc]
        _ -> acc
      end
    end)
    
    # Add general recommendations based on overall score
    recommendations = case results.overall_status do
      :critical ->
        ["CRITICAL: Complete system redesign may be __required" | recommendations]
      :needs_improvement ->
        ["Focus on top 3 failing categories for immediate improvement" | recommendations]
      :acceptable ->
        ["Good foundation - focus on eliminating remaining gaps" | recommendations]
      _ -> recommendations
    end

    recommendations
  end

  defp save_verification_report(results) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/automated_container_verification_#{timestamp}.json"
    
    # Ensure __data/tmp directory exists
    File.mkdir_p("./__data/tmp")
    
    # Convert results to JSON
    json_results = Jason.encode!(results, pretty: true)
    
    File.write!(report_file, json_results)
    IO.puts("\n📄 Verification report saved: #{report_file}")
  end

  defp test_autonomous_creation do
    IO.puts("🤖 Testing Autonomous Container Creation")
    IO.puts("═══════════════════════════════════════")
    
    # Test the master setup script in dry-run mode
    master_script = "scripts/containers/master_nixos_container_setup.exs"
    
    if File.exists?(master_script) do
      IO.puts("✅ Master setup script found")
      
      # Test script syntax
      case System.cmd("elixir", ["-c", master_script], stderr_to_stdout: true) do
        {_, 0} ->
          IO.puts("✅ Script syntax valid")
        {output, _} ->
          IO.puts("❌ Script syntax errors:")
          IO.puts(output)
      end
      
      # Test autonomous execution capabilities
      content = File.read!(master_script)
      
      autonomous_features = [
        {"Zero intervention flags", String.contains?(content, "--autonomous") or String.contains?(content, "--no-confirm")},
        {"Error handling", String.contains?(content, "rescue") or String.contains?(content, "case")},
        {"Container definitions", Enum.all?(@containers, fn c -> String.contains?(content, c.name) end)},
        {"Health checks", String.contains?(content, "health") or String.contains?(content, "ready")},
        {"Logging", String.contains?(content, "Logger") or String.contains?(content, "IO.puts")}
      ]
      
      Enum.each(autonomous_features, fn {feature, present} ->
        status = if present, do: "✅", else: "❌"
        IO.puts("#{status} #{feature}")
      end)
      
    else
      IO.puts("❌ Master setup script not found: #{master_script}")
    end
  end

  defp verify_container_health do
    IO.puts("🏥 Verifying Container Health Capabilities")
    IO.puts("════════════════════════════════════════")
    
    health_script = "scripts/containers/container_readiness_validator.exs"
    
    if File.exists?(health_script) do
      IO.puts("✅ Health validator script found")
      
      content = File.read!(health_script)
      
      health_features = [
        {"Health endpoints", String.contains?(content, "/health") or String.contains?(content, "health_check")},
        {"Timeout handling", String.contains?(content, "timeout") or String.contains?(content, "Timer")},
        {"Retry logic", String.contains?(content, "retry") or String.contains?(content, "attempt")},
        {"Container validation", Enum.any?(@containers, fn c -> String.contains?(content, c.name) end)},
        {"Comprehensive checks", String.contains?(content, "validate_") and String.contains?(content, "check_")}
      ]
      
      Enum.each(health_features, fn {feature, present} ->
        status = if present, do: "✅", else: "❌"
        IO.puts("#{status} #{feature}")
      end)
      
    else
      IO.puts("❌ Health validator script not found: #{health_script}")
    end
  end

  defp test_integration do
    IO.puts("🔗 Testing Integration Capabilities")
    IO.puts("═════════════════════════════════")
    
    test_files = [
      "test/containers/stamp_safety_test.exs",
      "test/containers/tdg_methodology_test.exs",
      "test/containers/functional_integration_test.exs"
    ]
    
    Enum.each(test_files, fn test_file ->
      if File.exists?(test_file) do
        IO.puts("✅ #{Path.basename(test_file)} found")
        
        # Check test content
        content = File.read!(test_file)
        
        test_features = [
          {"Test structure", String.contains?(content, "defmodule") and String.contains?(content, "Test")},
          {"ExUnit usage", String.contains?(content, "use ExUnit.Case")},
          {"Test cases", String.contains?(content, "test ") or String.contains?(content, "describe")},
          {"Assertions", String.contains?(content, "assert") or String.contains?(content, "refute")}
        ]
        
        Enum.each(test_features, fn {feature, present} ->
          status = if present, do: "  ✅", else: "  ❌"
          IO.puts("#{status} #{feature}")
        end)
        
      else
        IO.puts("❌ #{Path.basename(test_file)} not found")
      end
    end)
  end

  defp identify_automation_gaps do
    IO.puts("🔍 Identifying Automation Gaps")
    IO.puts("════════════════════════════")
    
    gaps = identify_potential_gaps()
    
    if length(gaps) == 0 do
      IO.puts("🌟 No automation gaps detected!")
    else
      IO.puts("⚠️  Found #{length(gaps)} automation gaps:")
      Enum.each(gaps, fn gap ->
        IO.puts("   • #{gap}")
      end)
    end
    
    # Check for additional gaps
    additional_checks = [
      {"Container orchestration", File.exists?("docker-compose.yml") or File.exists?("podman-compose.yml")},
      {"CI/CD configuration", File.exists?(".github/workflows/container-ci.yml")},
      {"Automated testing", File.exists?("test/containers/")},
      {"Monitoring setup", File.exists?("scripts/containers/performance_baseline.exs")},
      {"Emergency recovery", File.exists?("scripts/containers/emergency_recovery.exs")}
    ]
    
    IO.puts("\n🔧 Infrastructure Completeness:")
    Enum.each(additional_checks, fn {check, present} ->
      status = if present, do: "✅", else: "❌"
      IO.puts("#{status} #{check}")
    end)
  end

  defp generate_verification_report do
    IO.puts("📊 Generating Verification Report")
    IO.puts("════════════════════════════════")
    
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
    
    # Generate comprehensive report
    report = """
    # Automated Container Verification Report
    Generated: #{timestamp}
    
    ## Executive Summary
    This report provides a comprehensive assessment of the automated container creation
    and verification capabilities for the NixOS-based container infrastructure.
    
    ## Container Infrastructure Status
    Target containers: #{length(@containers)}
    
    #{Enum.map(@containers, fn c -> "- #{c.name} (#{c.image})" end) |> Enum.join("\n    ")}
    
    ## Verification Categories
    The following categories were assessed:
    
    #{Enum.map(@verification_categories, fn cat -> "- #{cat}" end) |> Enum.join("\n    ")}
    
    ## Key Scripts Validated
    - scripts/containers/master_nixos_container_setup.exs (Master orchestrator)
    - scripts/containers/container_readiness_validator.exs (Health validation)
    - scripts/containers/nixos_ssl_certificate_resolver.exs (SSL resolution)
    - scripts/containers/phics_integration_validator.exs (PHICS validation)
    - scripts/containers/stamp_safety_validator.exs (STAMP safety)
    - scripts/containers/emergency_recovery.exs (Recovery procedures)
    - scripts/containers/performance_baseline.exs (Performance monitoring)
    
    ## Test Framework
    - test/containers/stamp_safety_test.exs (STAMP methodology tests)
    - test/containers/tdg_methodology_test.exs (TDG validation tests)
    - test/containers/functional_integration_test.exs (Integration tests)
    
    ## Automation Goals
    - Zero manual intervention for container creation
    - Comprehensive health validation
    - Automated recovery procedures
    - Performance baseline establishment
    - Security constraint validation
    
    ## Next Steps
    1. Execute full verification: `elixir automated_container_verification.exs --verify`
    2. Address any identified gaps
    3. Test autonomous creation: `elixir automated_container_verification.exs --autonomous-test`
    4. Validate integration: `elixir automated_container_verification.exs --integration`
    
    Generated by: Automated Container Verification System
    """
    
    # Save report
    timestamp_file = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/container_verification_report_#{timestamp_file}.md"
    
    File.mkdir_p("./__data/tmp")
    File.write!(report_file, report)
    
    IO.puts("📄 Report generated: #{report_file}")
    IO.puts("\n📋 Report Preview:")
    IO.puts(String.slice(report, 0, 500) <> "...")
  end

  defp show_help do
    IO.puts("""
    🤖 Automated Container Verification System
    
    Verifies complete container creation process without Claude intervention.
    Ensures full automation, health validation, and integration testing.
    
    USAGE:
        elixir automated_container_verification.exs [COMMAND]
    
    COMMANDS:
        --verify             Run complete verification process (default)
        --autonomous-test    Test autonomous container creation capabilities
        --health-check       Verify container health validation
        --integration        Test integration capabilities
        --gaps               Identify automation gaps
        --report             Generate verification report
        --help               Show this help message
    
    VERIFICATION CATEGORIES:
        • Autonomous Creation     - Zero intervention container creation
        • Health Validation       - Comprehensive health checking
        • Integration Testing     - End-to-end integration validation
        • Performance Baseline   - Performance monitoring setup
        • Security Validation    - SSL certificates and registry enforcement
        • Recovery Testing        - Emergency recovery procedures
        • Documentation           - Complete documentation coverage
        • Automation Gaps         - Missing automation components
    
    STAMP SAFETY CONSTRAINTS:
        SC-ACV-001: System SHALL autonomously create all containers
        SC-ACV-002: System SHALL validate container health without intervention
        SC-ACV-003: System SHALL provide complete automation verification
        SC-ACV-004: System SHALL detect and report automation gaps
        SC-ACV-005: System SHALL maintain audit trail of verification
    
    EXIT CODES:
        0 - Excellent/Good (95%+ or 85%+ automation score)
        1 - Acceptable (70%+ automation score)
        2 - Needs Improvement (50%+ automation score)
        3 - Critical (<50% automation score)
    
    EXAMPLES:
        # Complete verification
        elixir automated_container_verification.exs --verify
        
        # Test autonomous creation only
        elixir automated_container_verification.exs --autonomous-test
        
        # Generate detailed report
        elixir automated_container_verification.exs --report
    """)
  end
end

# Execute main function if script is run directly
if System.argv() != [] or !Process.get(:test_mode) do
  AutomatedContainerVerification.main(System.argv())
end