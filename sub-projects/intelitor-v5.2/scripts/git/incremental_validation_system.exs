#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule GitIncrementalValidationSystem do
  @moduledoc """
  Git-Based Incremental Validation System for Phase 3.3
  
  Implements comprehensive validation tracking with:
  - Git hooks integration for automatic validation
  - Incremental validation __state management
  - TPS quality gates enforcement
  - SOPv5.1 cybernetic coordination
  - Systematic validation history tracking
  """

  require Logger

  @validation_state_file "./data/tmp/git_validation_state.json"
  @validation_history_file "./data/tmp/git_validation_history.jsonl"
  @quality_gates_config "./data/tmp/quality_gates_config.json"

  def main(args) do
    Logger.configure(level: :info)
    
    case args do
      ["--setup"] -> setup_validation_system()
      ["--validate"] -> run_incremental_validation()
      ["--status"] -> show_validation_status()
      ["--history"] -> show_validation_history()
      ["--install-hooks"] -> install_git_hooks()
      ["--quality-gates"] -> configure_quality_gates()
      ["--reset"] -> reset_validation_state()
      ["--comprehensive"] -> run_comprehensive_validation()
      _ -> show_help()
    end
  end

  defp setup_validation_system do
    Logger.info("🔧 Setting up Git-Based Incremental Validation System")
    
    # Ensure __data directories exist
    File.mkdir_p!(Path.dirname(@validation_state_file))
    File.mkdir_p!(Path.dirname(@validation_history_file))
    File.mkdir_p!(Path.dirname(@quality_gates_config))
    
    # Initialize validation __state
    initial_state = %{
      last_validated_commit: get_current_commit_hash(),
      validation_status: "clean",
      quality_gates_passed: [],
      quality_gates_failed: [],
      warnings_count: 0,
      errors_count: 0,
      last_validation_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      validation_history_entries: 0
    }
    
    save_validation_state(initial_state)
    
    # Initialize quality gates configuration
    quality_gates = %{
      compilation: %{
        enabled: true,
        command: "NO_TIMEOUT=true PATIENT_MODE=enabled mix compile --jobs 16 --warnings-as-errors",
        description: "Zero-tolerance compilation with warnings as errors",
        critical: true
      },
      format_check: %{
        enabled: true,
        command: "mix format --check-formatted",
        description: "Code formatting validation",
        critical: false
      },
      credo_analysis: %{
        enabled: true,
        command: "mix credo --strict",
        description: "Static code analysis with strict rules",
        critical: false
      },
      test_execution: %{
        enabled: true,
        command: "mix test --cover",
        description: "Comprehensive test suite execution",
        critical: true
      },
      dialyzer_check: %{
        enabled: false,
        command: "mix dialyzer",
        description: "Type analysis (disabled due to long runtime)",
        critical: false
      }
    }
    
    File.write!(@quality_gates_config, Jason.encode!(quality_gates, pretty: true))
    
    Logger.info("✅ Git-Based Incremental Validation System setup complete")
    Logger.info("📁 State file: #{@validation_state_file}")
    Logger.info("📁 History file: #{@validation_history_file}")
    Logger.info("📁 Quality gates config: #{@quality_gates_config}")
    
    install_git_hooks()
  end

  defp run_incremental_validation do
    Logger.info("🔍 Running Git-Based Incremental Validation")
    
    current_commit = get_current_commit_hash()
    current_state = load_validation_state()
    
    if current_commit == current_state.last_validated_commit do
      Logger.info("✅ No changes since last validation (#{current_commit})")
      show_validation_status()
    else
    
    Logger.info("🔄 Changes detected since last validation")
    Logger.info("   Previous: #{current_state.last_validated_commit}")
    Logger.info("   Current:  #{current_commit}")
    
      # Get changed files
    changed_files = get_changed_files(current_state.last_validated_commit, current_commit)
    Logger.info("📝 Changed files: #{length(changed_files)}")
    Enum.each(changed_files, fn file -> 
      Logger.info("   - #{file}")
    end)
    
    # Run quality gates
    quality_gates = load_quality_gates()
    results = run_quality_gates(quality_gates, changed_files)
    
    # Update validation __state
    new_state = %{
      current_state |
      last_validated_commit: current_commit,
      validation_status: if(Enum.all?(results, fn {_, result} -> result.passed end), do: "clean", else: "failed"),
      quality_gates_passed: Enum.filter(results, fn {_, result} -> result.passed end) |> Enum.map(fn {gate, _} -> gate end),
      quality_gates_failed: Enum.filter(results, fn {_, result} -> not result.passed end) |> Enum.map(fn {gate, _} -> gate end),
      warnings_count: calculate_total_warnings(results),
      errors_count: calculate_total_errors(results),
      last_validation_time: DateTime.utc_now() |> DateTime.to_iso8601(),
      validation_history_entries: current_state.validation_history_entries + 1
    }
    
    save_validation_state(new_state)
    
    # Log validation history
    history_entry = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      commit_hash: current_commit,
      changed_files_count: length(changed_files),
      validation_status: new_state.validation_status,
      quality_gates_results: Enum.map(results, fn {gate, result} ->
        %{
          gate: gate,
          passed: result.passed,
          exit_code: result.exit_code,
          duration_ms: result.duration_ms,
          warnings: result.warnings,
          errors: result.errors
        }
      end),
      warnings_count: new_state.warnings_count,
      errors_count: new_state.errors_count
    }
    
    append_validation_history(history_entry)
    
    # Report results
    Logger.info("📊 Validation Results:")
    Logger.info("   Status: #{new_state.validation_status}")
    Logger.info("   Gates Passed: #{length(new_state.quality_gates_passed)}")
    Logger.info("   Gates Failed: #{length(new_state.quality_gates_failed)}")
    Logger.info("   Warnings: #{new_state.warnings_count}")
    Logger.info("   Errors: #{new_state.errors_count}")
    
    if new_state.validation_status == "clean" do
      Logger.info("✅ All quality gates passed - validation successful!")
    else
      Logger.error("❌ Validation failed - quality gates not met")
      
      Enum.each(new_state.quality_gates_failed, fn gate ->
        Logger.error("   Failed gate: #{gate}")
      end)
    end
    end
  end

  defp run_quality_gates(quality_gates, _changed_files) do
    Logger.info("🚪 Running Quality Gates")
    
    Enum.map(quality_gates, fn {gate_name, gate_config} ->
      if gate_config.enabled do
        Logger.info("🔍 Running gate: #{gate_name}")
        
        start_time = System.monotonic_time(:millisecond)
        
        result = case System.cmd("sh", ["-c", gate_config.command], stderr_to_stdout: true) do
          {output, 0} ->
            %{
              passed: true,
              output: output,
              exit_code: 0,
              duration_ms: System.monotonic_time(:millisecond) - start_time,
              warnings: count_warnings_in_output(output),
              errors: count_errors_in_output(output)
            }
          {output, exit_code} ->
            %{
              passed: false,
              output: output,
              exit_code: exit_code,
              duration_ms: System.monotonic_time(:millisecond) - start_time,
              warnings: count_warnings_in_output(output),
              errors: count_errors_in_output(output)
            }
        end
        
        status = if result.passed, do: "✅", else: "❌"
        Logger.info("#{status} Gate #{gate_name}: #{result.duration_ms}ms")
        
        {gate_name, result}
      else
        Logger.info("⏭️  Gate #{gate_name}: disabled")
        {gate_name, %{passed: true, output: "disabled", exit_code: 0, duration_ms: 0, warnings: 0, errors: 0}}
      end
    end)
  end

  defp count_warnings_in_output(output) do
    output 
    |> String.split("\n")
    |> Enum.count(fn line -> String.contains?(line, "warning:") end)
  end

  defp count_errors_in_output(output) do
    error_patterns = ["error:", "** (", "CompileError", "== Compilation error"]
    
    output
    |> String.split("\n")
    |> Enum.count(fn line ->
      Enum.any?(error_patterns, fn pattern -> String.contains?(line, pattern) end)
    end)
  end

  defp calculate_total_warnings(results) do
    results
    |> Enum.map(fn {_, result} -> result.warnings end)
    |> Enum.sum()
  end

  defp calculate_total_errors(results) do
    results
    |> Enum.map(fn {_, result} -> result.errors end)
    |> Enum.sum()
  end

  defp install_git_hooks do
    Logger.info("🪝 Installing Git Hooks for Incremental Validation")
    
    hooks_dir = ".git/hooks"
    File.mkdir_p!(hooks_dir)
    
    # Pre-commit hook
    pre_commit_hook = """
    #!/bin/sh
    # Git-Based Incremental Validation - Pre-commit Hook
    echo "🔍 Running pre-commit validation..."
    elixir scripts/git/incremental_validation_system.exs --validate
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "❌ Pre-commit validation failed"
        echo "   Run 'elixir scripts/git/incremental_validation_system.exs --status' for details"
        exit 1
    fi
    
    echo "✅ Pre-commit validation passed"
    exit 0
    """
    
    File.write!("#{hooks_dir}/pre-commit", pre_commit_hook)
    File.chmod("#{hooks_dir}/pre-commit", 0o755)
    
    # Post-commit hook
    post_commit_hook = """
    #!/bin/sh
    # Git-Based Incremental Validation - Post-commit Hook
    echo "📊 Running post-commit validation update..."
    elixir scripts/git/incremental_validation_system.exs --validate >/dev/null 2>&1 &
    """
    
    File.write!("#{hooks_dir}/post-commit", post_commit_hook)
    File.chmod("#{hooks_dir}/post-commit", 0o755)
    
    Logger.info("✅ Git hooks installed successfully")
    Logger.info("   - Pre-commit: Validation before commits")
    Logger.info("   - Post-commit: Async validation after commits")
  end

  defp show_validation_status do
    Logger.info("📊 Git-Based Incremental Validation Status")

    state = load_validation_state()

    Logger.info("🔍 Current Status:")
    Logger.info("   Validation Status: #{state.validation_status}")
    Logger.info("   Last Validated Commit: #{state.last_validated_commit}")
    Logger.info("   Last Validation Time: #{state.last_validation_time}")
    Logger.info("   Warnings Count: #{state.warnings_count}")
    Logger.info("   Errors Count: #{state.errors_count}")
    Logger.info("   History Entries: #{state.validation_history_entries}")

    Logger.info("✅ Quality Gates Passed (#{length(state.quality_gates_passed)}):")
    Enum.each(state.quality_gates_passed, fn gate ->
      Logger.info("   - #{gate}")
    end)

    if length(state.quality_gates_failed) > 0 do
      Logger.info("❌ Quality Gates Failed (#{length(state.quality_gates_failed)}):")
      Enum.each(state.quality_gates_failed, fn gate ->
        Logger.info("   - #{gate}")
      end)
    end

    current_commit = get_current_commit_hash()
    if current_commit != state.last_validated_commit do
      Logger.info("⚠️  Changes detected since last validation")
      Logger.info("   Current commit: #{current_commit}")
      Logger.info("   Run --validate to update validation status")
    end
  end

  defp show_validation_history do
    Logger.info("📚 Git-Based Incremental Validation History")
    
    if not File.exists?(@validation_history_file) do
      Logger.info("   No validation history found")
    else
    
    history_entries = File.stream!(@validation_history_file)
    |> Stream.map(&String.trim/1)
    |> Stream.reject(fn line -> line == "" end)
    |> Stream.map(fn line -> Jason.decode!(line) end)
    |> Enum.to_list()
    |> Enum.take(-10)  # Show last 10 entries
    
    Logger.info("📊 Recent Validation History (last #{length(history_entries)} entries):")
    
      Enum.each(history_entries, fn entry ->
        timestamp = entry["timestamp"] |> String.slice(0, 19)
        status_icon = if entry["validation_status"] == "clean", do: "✅", else: "❌"
        
        Logger.info("#{status_icon} #{timestamp} | #{entry["commit_hash"] |> String.slice(0, 7)} | #{entry["changed_files_count"]} files | W:#{entry["warnings_count"]} E:#{entry["errors_count"]}")
      end)
    end
  end

  defp run_comprehensive_validation do
    Logger.info("🔍 Running Comprehensive Git-Based Validation")
    
    # Reset validation __state to force full validation
    reset_validation_state()
    
    # Run incremental validation (which will now validate everything)
    run_incremental_validation()
    
    # Show comprehensive status
    show_validation_status()
    show_validation_history()
    
    Logger.info("✅ Comprehensive validation complete")
  end

  defp configure_quality_gates do
    Logger.info("⚙️ Configuring Quality Gates")
    
    quality_gates = load_quality_gates()
    
    Logger.info("📋 Current Quality Gates Configuration:")
    Enum.each(quality_gates, fn {gate_name, gate_config} ->
      status = if gate_config.enabled, do: "✅", else: "❌"
      critical = if gate_config.critical, do: "[CRITICAL]", else: ""
      Logger.info("#{status} #{gate_name} #{critical}")
      Logger.info("   Command: #{gate_config.command}")
      Logger.info("   Description: #{gate_config.description}")
    end)
  end

  defp reset_validation_state do
    Logger.info("🔄 Resetting Git-Based Incremental Validation State")
    
    if File.exists?(@validation_state_file) do
      File.rm!(@validation_state_file)
      Logger.info("   Removed validation __state file")
    end
    
    Logger.info("✅ Validation __state reset complete")
  end

  # Helper functions
  
  defp get_current_commit_hash do
    case System.cmd("git", ["rev-parse", "HEAD"]) do
      {hash, 0} -> String.trim(hash)
      _ -> "unknown"
    end
  end

  defp get_changed_files(from_commit, to_commit) do
    case System.cmd("git", ["diff", "--name-only", "#{from_commit}...#{to_commit}"]) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.reject(fn line -> line == "" end)
      _ ->
        []
    end
  end

  defp load_validation_state do
    if File.exists?(@validation_state_file) do
      @validation_state_file
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
    else
      %{
        last_validated_commit: "none",
        validation_status: "unknown",
        quality_gates_passed: [],
        quality_gates_failed: [],
        warnings_count: 0,
        errors_count: 0,
        last_validation_time: "never",
        validation_history_entries: 0
      }
    end
  end

  defp save_validation_state(state) do
    File.write!(@validation_state_file, Jason.encode!(state, pretty: true))
  end

  defp load_quality_gates do
    if File.exists?(@quality_gates_config) do
      @quality_gates_config
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
    else
      %{}
    end
  end

  defp append_validation_history(entry) do
    File.open!(@validation_history_file, [:append], fn file ->
      IO.write(file, Jason.encode!(entry) <> "\n")
    end)
  end

  defp show_help do
    Logger.info("""
    Git-Based Incremental Validation System - Phase 3.3

    Usage: elixir scripts/git/incremental_validation_system.exs [OPTION]

    Options:
      --setup              Initialize the validation system and configuration
      --validate           Run incremental validation based on git changes
      --status             Show current validation status and __state
      --history            Show recent validation history
      --install-hooks      Install git hooks for automatic validation
      --quality-gates      Show quality gates configuration
      --reset              Reset validation __state (force full re-validation)
      --comprehensive      Run comprehensive validation of entire codebase

    Examples:
      # Setup the system (run once)
      elixir scripts/git/incremental_validation_system.exs --setup

      # Run validation after making changes
      elixir scripts/git/incremental_validation_system.exs --validate

      # Check current status
      elixir scripts/git/incremental_validation_system.exs --status

    Quality Gates:
      - Compilation: Zero-tolerance compilation with warnings as errors
      - Format Check: Code formatting validation
      - Credo Analysis: Static code analysis with strict rules  
      - Test Execution: Comprehensive test suite execution
      - Dialyzer Check: Type analysis (optional)

    Integration:
      - Git hooks automatically run validation on commits
      - Validation __state persisted across sessions
      - History tracking for trend analysis
      - SOPv5.1 cybernetic coordination support
    """)
  end
end

# Run the module if this file is executed directly
GitIncrementalValidationSystem.main(System.argv())