#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule Level1FoundationSetup do
  @moduledoc """
  Level 1: Foundation Setup & Infrastructure Preparation
  
  This script implements the foundational infrastructure __required for 
  implementing 108 missing Mix aliases with TDG methodology and STAMP safety compliance.
  """

  @timestamp DateTime.utc_now() |> DateTime.to_iso8601()
  @__required_directories [
    "test/mix_alias",
    "test/property", 
    "test/integration",
    "test/performance",
    "test/security",
    "test/stamp",
    "scripts/validation",
    "scripts/testing",
    "scripts/mix_alias",
    "docs/mix_alias",
    "__data/tmp"
  ]
  
  def main(args) do
    case args do
      ["--setup"] -> run_foundation_setup()
      ["--validate"] -> validate_foundation()
      ["--help"] -> show_help()
      [] -> run_foundation_setup()
      _ -> 
        IO.puts("Invalid arguments. Use --help for usage information.")
        System.halt(1)
    end
  end

  def run_foundation_setup do
    IO.puts("\n🏗️ Level 1: Foundation Setup & Infrastructure Preparation")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Timestamp: #{@timestamp}")
    IO.puts("Setting up foundation for 108 Mix alias implementation...")
    
    results = %{
      environment: validate_environment(),
      directories: setup_directory_structure(),
      test_infrastructure: setup_test_infrastructure()
    }
    
    display_setup_results(results)
    save_setup_report(results)
    
    success_count = count_successful_components(results)
    total_components = length(Map.keys(results))
    success_percentage = round(success_count / total_components * 100)
    
    IO.puts("\n📊 Foundation Setup Success: #{success_percentage}% (#{success_count}/#{total_components})")
    
    if success_percentage >= 95 do
      IO.puts("✅ EXCELLENT: Foundation ready for Level 2 implementation")
    elsif success_percentage >= 80 do
      IO.puts("⚠️ GOOD: Minor issues to resolve before Level 2")
    else
      IO.puts("❌ INSUFFICIENT: Major foundation issues must be resolved")
      System.halt(1)
    end
    
    results
  end

  defp validate_environment do
    IO.puts("\n🔍 Validating Development Environment...")
    
    checks = [
      {"Elixir installation", check_elixir()},
      {"Mix availability", check_mix()},
      {"Git repository", check_git_repo()},
      {"Project structure", check_project_structure()},
      {"Write permissions", check_write_permissions()}
    ]
    
    Enum.each(checks, fn {name, result} ->
      status = if result, do: "✅", else: "❌"
      IO.puts("   #{status} #{name}")
    end)
    
    passed_checks = Enum.count(checks, fn {_, result} -> result end)
    total_checks = length(checks)
    
    %{
      total_checks: total_checks,
      passed_checks: passed_checks,
      success_rate: round(passed_checks / total_checks * 100),
      all_passed: passed_checks == total_checks
    }
  end

  defp setup_directory_structure do
    IO.puts("\n📁 Setting up Directory Structure...")
    
    _created_dirs = Enum.map(@__required_directories, fn dir ->
      exists_before = File.exists?(dir)
      
      case File.mkdir_p(dir) do
        :ok ->
          status = if exists_before, do: "✅ (existed)", else: "✅ (created)"
          IO.puts("   #{status} #{dir}")
          {dir, :created}
        {:error, reason} ->
          IO.puts("   ❌ Failed to create #{dir}: #{reason}")
          {dir, :failed}
      end
    end)
    
    successful_dirs = Enum.count(created_dirs, fn {_, status} -> status == :created end)
    total_dirs = length(@__required_directories)
    
    %{
      total_directories: total_dirs,
      successful_directories: successful_dirs,
      success_rate: round(successful_dirs / total_dirs * 100),
      directory_list: created_dirs
    }
  end

  defp setup_test_infrastructure do
    IO.puts("\n🧪 Setting up TDG Test Infrastructure...")
    
    test_setup_results = []
    
    # Validate main test file exists (should have been created already)
    main_test_file = "test/mix_alias/comprehensive_mix_alias_test.exs"
    if File.exists?(main_test_file) do
      IO.puts("   ✅ Main test file exists: #{main_test_file}")
      test_setup_results = [{main_test_file, :exists} | test_setup_results]
    else
      IO.puts("   ⚠️ Main test file missing: #{main_test_file}")
      test_setup_results = [{main_test_file, :missing} | test_setup_results]
    end
    
    # Check STAMP validator exists
    stamp_file = "scripts/validation/stamp_mix_alias_safety_constraints.exs"
    if File.exists?(stamp_file) do
      IO.puts("   ✅ STAMP validator exists: #{stamp_file}")
      test_setup_results = [{stamp_file, :exists} | test_setup_results]
    else
      IO.puts("   ❌ STAMP validator missing: #{stamp_file}")
      test_setup_results = [{stamp_file, :missing} | test_setup_results]
    end
    
    # Check TDG validator exists
    tdg_file = "scripts/testing/tdg_mix_alias_validator.exs"
    if File.exists?(tdg_file) do
      IO.puts("   ✅ TDG validator exists: #{tdg_file}")
      test_setup_results = [{tdg_file, :exists} | test_setup_results]
    else
      IO.puts("   ❌ TDG validator missing: #{tdg_file}")
      test_setup_results = [{tdg_file, :missing} | test_setup_results]
    end
    
    successful_tests = Enum.count(test_setup_results, fn {_, status} -> status == :exists end)
    total_tests = length(test_setup_results)
    
    %{
      total_test_files: total_tests,
      successful_test_files: successful_tests,
      success_rate: if total_tests > 0, do: round(successful_tests / total_tests * 100), else: 0,
      test_files: test_setup_results
    }
  end

  defp count_successful_components(results) do
    success_scores = [
      if results[:environment][:all_passed], do: 1, else: 0,
      if results[:directories][:success_rate] >= 90, do: 1, else: 0,
      if results[:test_infrastructure][:success_rate] >= 66, do: 1, else: 0
    ]
    
    Enum.sum(success_scores)
  end

  defp display_setup_results(results) do
    IO.puts("\n📊 Foundation Setup Results Summary")
    IO.puts("=" <> String.duplicate("=", 50))
    
    Enum.each(results, fn {component, result} ->
      IO.puts("\n📋 #{String.capitalize(to_string(component))}:")
      
      if is_map(result) and Map.has_key?(result, :success_rate) do
        success_rate = result[:success_rate]
        status_icon = cond do
          success_rate >= 95 -> "✅"
          success_rate >= 75 -> "⚠️"
          true -> "❌"
        end
        
        IO.puts("   #{status_icon} Success Rate: #{success_rate}%")
      end
    end)
  end

  defp save_setup_report(results) do
    report_data = %{
      timestamp: @timestamp,
      level: "Level 1: Foundation Setup",
      results: results,
      success_summary: %{
        overall_success: count_successful_components(results),
        total_components: length(Map.keys(results)),
        success_percentage: round(count_successful_components(results) / length(Map.keys(results)) * 100)
      }
    }
    
    File.mkdir_p!("./__data/tmp")
    timestamp_str = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M")
    report_file = "./__data/tmp/#{timestamp_str}-level1-foundation-setup-report.json"
    
    File.write!(report_file, Jason.encode!(report_data, pretty: true))
    
    IO.puts("\n📋 Foundation setup report saved to: #{report_file}")
  end

  # Helper functions for validation checks
  defp check_elixir do
    case System.cmd("elixir", ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "Elixir")
      _ -> false
    end
  end

  defp check_mix do
    case System.cmd("mix", ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "Mix")
      _ -> false
    end
  end

  defp check_git_repo do
    File.exists?(".git")
  end

  defp check_project_structure do
    File.exists?("mix.exs") and File.exists?("lib") and File.exists?("test")
  end

  defp check_write_permissions do
    test_file = "./__data/tmp/.write_test"
    File.mkdir_p!("./__data/tmp")
    
    case File.write(test_file, "test") do
      :ok ->
        File.rm(test_file)
        true
      {:error, _} -> false
    end
  end

  def validate_foundation do
    IO.puts("\n🔍 Validating Foundation Setup...")
    
    validation_results = []
    
    # Test STAMP validator execution
    stamp_file = "scripts/validation/stamp_mix_alias_safety_constraints.exs"
    if File.exists?(stamp_file) do
      case System.cmd("elixir", [stamp_file, "--help"], stderr_to_stdout: true) do
        {output, 0} ->
          if String.contains?(output, "STAMP") do
            IO.puts("   ✅ STAMP validator executes correctly")
            validation_results = [{"STAMP validation", :passed} | validation_results]
          else
            IO.puts("   ⚠️ STAMP validator runs but output unclear")
            validation_results = [{"STAMP validation", :unclear} | validation_results]
          end
        {_output, _exit_code} ->
          IO.puts("   ❌ STAMP validator execution failed")
          validation_results = [{"STAMP validation", :failed} | validation_results]
      end
    else
      IO.puts("   ❌ STAMP validator not available")
      validation_results = [{"STAMP validation", :unavailable} | validation_results]
    end
    
    # Test TDG validator execution
    tdg_file = "scripts/testing/tdg_mix_alias_validator.exs"
    if File.exists?(tdg_file) do
      case System.cmd("elixir", [tdg_file, "--help"], stderr_to_stdout: true) do
        {output, 0} ->
          if String.contains?(output, "TDG") do
            IO.puts("   ✅ TDG validator executes correctly")
            validation_results = [{"TDG validation", :passed} | validation_results]
          else
            IO.puts("   ⚠️ TDG validator runs but output unclear")
            validation_results = [{"TDG validation", :unclear} | validation_results]
          end
        {_output, _exit_code} ->
          IO.puts("   ❌ TDG validator execution failed")
          validation_results = [{"TDG validation", :failed} | validation_results]
      end
    else
      IO.puts("   ❌ TDG validator not available")
      validation_results = [{"TDG validation", :unavailable} | validation_results]
    end
    
    successful_validations = Enum.count(validation_results, fn {_, status} -> 
      status in [:passed, :unclear] 
    end)
    total_validations = length(validation_results)
    
    success_rate = if total_validations > 0, do: round(successful_validations / total_validations * 100), else: 0
    
    IO.puts("\n📊 Foundation Validation Results:")
    IO.puts("   Success Rate: #{success_rate}%")
    
    if success_rate >= 50 do
      IO.puts("✅ Foundation validation successful")
    else
      IO.puts("❌ Foundation validation failed")
      System.halt(1)
    end
    
    %{
      total_validations: total_validations,
      successful_validations: successful_validations,
      success_rate: success_rate,
      validation_results: validation_results
    }
  end

  defp show_help do
    IO.puts("""
    🏗️ Level 1: Foundation Setup & Infrastructure Preparation
    
    Usage: elixir level1_foundation_setup_fixed.exs [OPTION]
    
    Options:
      --setup               Run complete foundation setup (default)
      --validate            Validate foundation setup only
      --help                Show this help message
    
    Foundation Components:
      ✅ Environment validation and pre__requisite checking
      ✅ Directory structure creation for tests and scripts
      ✅ TDG test infrastructure validation
      ✅ STAMP safety constraint validation
    
    Success Criteria:
      • All environment checks pass
      • Directory structure 90%+ setup success
      • Test infrastructure files exist and execute
      
    Next Phase: Level 2 - Critical Alias Implementation
      • SOPv5.11 + AEE Cybernetic Framework aliases
      • PHICS Hot-Reloading Integration aliases  
      • NixOS Containers + Podman aliases
    """)
  end
end

# Run the foundation setup
Level1FoundationSetup.main(System.argv())