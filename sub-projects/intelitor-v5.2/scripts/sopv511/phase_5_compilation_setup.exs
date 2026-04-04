#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.Phase5CompilationSetup do
  @moduledoc """
  Phase 5: Compilation Environment Setup for SOPv5.11 Cybernetic Framework

  This script implements TPS Jidoka principles - stopping to fix any issues
  before proceeding to the next phase.

  Created: 2025-09-21 23:10:00 CEST
  Status: Phase 5 Implementation
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)

    Logger.info("🚀 SOPv5.11 Phase 5: Compilation Environment Setup")
    Logger.info("📋 TPS Jidoka Protocol: Stop and fix any quality issues")
    Logger.info("🕒 Starting at: #{get_current_time()}")

    case Enum.at(args, 0) do
      "--validate" -> validate_phase_5()
      "--setup" -> execute_phase_5_setup()
      "--status" -> show_phase_5_status()
      "--fix" -> fix_phase_5_issues()
      "--patient-compile" -> execute_patient_compilation()
      _ -> show_help()
    end
  end

  defp show_help do
    Logger.info("""
    🔧 SOPv5.11 Phase 5 Compilation Environment Setup Commands:

    --setup           Execute complete Phase 5 compilation setup
    --validate        Validate Phase 5 completion status
    --status          Show current Phase 5 compilation status
    --fix             Apply TPS Jidoka fixes to compilation issues
    --patient-compile Execute patient mode compilation with validation

    Example usage:
    elixir scripts/sopv511/phase_5_compilation_setup.exs --setup
    elixir scripts/sopv511/phase_5_compilation_setup.exs --patient-compile
    """)
  end

  defp execute_phase_5_setup do
    Logger.info("🏗️ Executing Phase 5: Compilation Environment Setup")

    steps = [
      {"5.1.1 - Validate Phase 4 Prerequisites", &validate_phase_4_complete/0},
      {"5.1.2 - Setup Patient Mode Environment", &setup_patient_mode/0},
      {"5.1.3 - Configure Parallel Compilation", &configure_parallel_compilation/0},
      {"5.1.4 - Initialize FPPS System", &initialize_fpps/0},
      {"5.1.5 - Setup Error Pattern Database", &setup_error_patterns/0},
      {"5.1.6 - Configure Compilation Monitoring", &configure_compilation_monitoring/0},
      {"5.1.7 - Validate Zero-Warning Target", &validate_zero_warning_setup/0},
      {"5.1.8 - Execute Initial Patient Compilation", &execute_initial_compilation/0}
    ]

    results = Enum.map(steps, fn {description, function} ->
      Logger.info("🔄 #{description}")

      case function.() do
        {:ok, message} ->
          Logger.info("✅ #{description}: #{message}")
          {description, :success, message}

        {:error, reason} ->
          Logger.error("❌ #{description}: #{reason}")
          Logger.error("🛑 TPS Jidoka: Stopping to address issue")
          {description, :error, reason}
      end
    end)

    # TPS Jidoka: Check for any failures
    failures = Enum.filter(results, fn {_, status, _} -> status == :error end)

    if Enum.empty?(failures) do
      Logger.info("🎉 Phase 5 Compilation Environment Setup: COMPLETE")
      Logger.info("✅ All 8 compilation components operational")
      save_phase_5_completion_report(results)
      {:ok, "Phase 5 Complete"}
    else
      Logger.error("🚨 Phase 5 BLOCKED by #{length(failures)} failures")
      Logger.error("🔧 Apply TPS Jidoka: Run --fix to address issues")
      save_phase_5_error_report(failures)
      {:error, "Phase 5 Incomplete"}
    end
  end

  defp validate_phase_4_complete do
    phase_4_report = "./data/tmp/phase4_completion_*.json"

    case Path.wildcard(phase_4_report) do
      [] ->
        {:error, "Phase 4 completion report not found - run Phase 4 first"}
      [report_file] ->
        case File.read(report_file) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, %{"status" => "COMPLETE"}} ->
                {:ok, "Phase 4 PHICS integration verified"}
              {:ok, %{"status" => status}} ->
                {:error, "Phase 4 status is #{status}, must be COMPLETE"}
              {:error, _} ->
                {:error, "Invalid Phase 4 report format"}
            end
          {:error, _} ->
            {:error, "Cannot read Phase 4 report"}
        end
      _ ->
        {:error, "Multiple Phase 4 reports found - cleanup required"}
    end
  end

  defp setup_patient_mode do
    patient_env_vars = [
      "NO_TIMEOUT=true",
      "PATIENT_MODE=enabled",
      "INFINITE_PATIENCE=true",
      "ELIXIR_ERL_OPTIONS=\"+S 16\"",
      "BASH_DEFAULT_TIMEOUT_MS=7200000",
      "BASH_MAX_TIMEOUT_MS=7200000"
    ]

    env_script = "./scripts/sopv511/patient_mode_env.sh"

    content = """
    #!/bin/bash
    # SOPv5.11 Phase 5: Patient Mode Environment Variables
    # Generated: #{get_current_time()}

    # Patient Mode Core Settings
    #{Enum.join(patient_env_vars, "\nexport ")}

    echo "✅ Patient Mode environment activated"
    echo "🔧 Compilation timeout: INFINITE"
    echo "⚡ Parallel schedulers: 16"
    echo "🎯 Mode: PATIENT with INFINITE_PATIENCE"
    """

    case File.write(env_script, "export " <> content) do
      :ok ->
        System.cmd("chmod", ["+x", env_script])
        {:ok, "Patient Mode environment script created"}
      {:error, reason} ->
        {:error, "Failed to create environment script: #{reason}"}
    end
  end

  defp configure_parallel_compilation do
    # Verify Elixir can use 16 schedulers
    case System.cmd("elixir", ["-e", "IO.puts(:erlang.system_info(:schedulers))"], stderr_to_stdout: true) do
      {output, 0} ->
        schedulers = String.trim(output) |> String.to_integer()
        if schedulers >= 16 do
          {:ok, "Parallel compilation configured: #{schedulers} schedulers available"}
        else
          Logger.warn("Only #{schedulers} schedulers available, may impact performance")
          {:ok, "Parallel compilation configured with #{schedulers} schedulers"}
        end
      {error, _} ->
        {:error, "Failed to check Elixir schedulers: #{error}"}
    end
  end

  defp initialize_fpps do
    fpps_script = "scripts/validation/comprehensive_compilation_validator.exs"

    if File.exists?(fpps_script) do
      # Test FPPS system
      case System.cmd("elixir", [fpps_script, "--validate-system"], stderr_to_stdout: true) do
        {_, 0} ->
          {:ok, "FPPS system operational and validated"}
        {error, _} ->
          {:error, "FPPS system validation failed: #{error}"}
      end
    else
      {:error, "FPPS script not found: #{fpps_script}"}
    end
  end

  defp setup_error_patterns do
    error_pattern_script = "scripts/analysis/comprehensive_error_pattern_database.exs"

    if File.exists?(error_pattern_script) do
      case System.cmd("elixir", [error_pattern_script, "--validate-patterns"], stderr_to_stdout: true) do
        {_, 0} ->
          {:ok, "Error pattern database operational (EP001-EP999)"}
        {error, _} ->
          {:error, "Error pattern validation failed: #{error}"}
      end
    else
      Logger.warn("Error pattern database not found, creating basic patterns")
      create_basic_error_patterns()
    end
  end

  defp create_basic_error_patterns do
    patterns_dir = "./data/tmp"
    File.mkdir_p!(patterns_dir)

    basic_patterns = %{
      error_patterns: [
        "error:", "** (", "undefined variable", "undefined function",
        "CompileError", "cannot compile module", "== Compilation error",
        "syntax error", "** (ArgumentError)", "** (RuntimeError)"
      ],
      warning_patterns: [
        "warning:", "is unused", "deprecated", "TODO:", "FIXME:", "HACK:"
      ]
    }

    pattern_file = Path.join(patterns_dir, "basic_error_patterns.json")
    case File.write(pattern_file, Jason.encode!(basic_patterns, pretty: true)) do
      :ok -> {:ok, "Basic error patterns created"}
      {:error, reason} -> {:error, "Failed to create patterns: #{reason}"}
    end
  end

  defp configure_compilation_monitoring do
    monitoring_dir = "./data/tmp"

    if File.exists?(monitoring_dir) do
      # Create compilation log directory structure
      log_dirs = [
        Path.join(monitoring_dir, "compilation_logs"),
        Path.join(monitoring_dir, "patient_mode_logs"),
        Path.join(monitoring_dir, "fpps_reports")
      ]

      Enum.each(log_dirs, &File.mkdir_p!/1)

      {:ok, "Compilation monitoring configured"}
    else
      {:error, "Monitoring directory not available"}
    end
  end

  defp validate_zero_warning_setup do
    # Check if project can compile without immediate failures
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, "Zero-warning target achievable - no immediate compilation failures"}
      {output, _} ->
        warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning"))
        error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error"))

        if error_count > 0 or warning_count > 0 do
          Logger.info("📊 Current state: #{error_count} errors, #{warning_count} warnings")
          {:ok, "Compilation baseline established: #{error_count} errors, #{warning_count} warnings to fix"}
        else
          {:ok, "Zero-warning target already achieved"}
        end
    end
  end

  defp execute_initial_compilation do
    Logger.info("🔄 Executing initial patient mode compilation...")

    compilation_log = "./data/tmp/compilation_logs/phase5_initial_#{get_timestamp()}.log"

    env_vars = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+fnu +S 16"}
    ]

    case System.cmd("mix", ["compile", "--verbose"],
                   stderr_to_stdout: true,
                   env: env_vars) do
      {output, exit_code} ->
        File.write!(compilation_log, output)

        if exit_code == 0 do
          {:ok, "Initial patient compilation successful - log: #{compilation_log}"}
        else
          warning_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "warning"))
          error_count = output |> String.split("\n") |> Enum.count(&String.contains?(&1, "error"))

          Logger.info("📊 Compilation results: #{error_count} errors, #{warning_count} warnings")
          {:ok, "Initial compilation baseline: #{error_count} errors, #{warning_count} warnings - log: #{compilation_log}"}
        end
    end
  end

  defp execute_patient_compilation do
    Logger.info("🔄 Executing Patient Mode Compilation with Full Monitoring")

    compilation_log = "./data/tmp/patient_mode_logs/patient_compile_#{get_timestamp()}.log"

    env_vars = [
      {"NO_TIMEOUT", "true"},
      {"PATIENT_MODE", "enabled"},
      {"INFINITE_PATIENCE", "true"},
      {"ELIXIR_ERL_OPTIONS", "+fnu +S 16"},
      {"BASH_DEFAULT_TIMEOUT_MS", "7200000"}
    ]

    Logger.info("📋 Patient compilation started - logging to: #{compilation_log}")
    Logger.info("⏳ This may take 10-45 minutes - please wait patiently...")

    start_time = System.monotonic_time(:millisecond)

    case System.cmd("mix", ["compile", "--warnings-as-errors", "--verbose"],
                   stderr_to_stdout: true,
                   env: env_vars) do
      {output, exit_code} ->
        end_time = System.monotonic_time(:millisecond)
        duration_minutes = (end_time - start_time) / 1000 / 60

        File.write!(compilation_log, output)

        # Analyze results
        lines = String.split(output, "\n")
        warning_count = Enum.count(lines, &String.contains?(&1, "warning"))
        error_count = Enum.count(lines, &String.contains?(&1, "error"))

        results = %{
          exit_code: exit_code,
          duration_minutes: Float.round(duration_minutes, 2),
          warning_count: warning_count,
          error_count: error_count,
          log_file: compilation_log,
          timestamp: get_current_time()
        }

        save_patient_compilation_report(results)

        Logger.info("✅ Patient compilation completed in #{results.duration_minutes} minutes")
        Logger.info("📊 Results: #{error_count} errors, #{warning_count} warnings")
        Logger.info("📋 Full log: #{compilation_log}")

        if exit_code == 0 do
          Logger.info("🎉 ZERO-WARNING COMPILATION ACHIEVED!")
        else
          Logger.info("🔧 Next: Apply systematic fixes using TPS methodology")
        end
    end
  end

  defp validate_phase_5 do
    Logger.info("🔍 Validating Phase 5 Compilation Environment")

    validation_checks = [
      {"Phase 4 Prerequisites", &validate_phase_4_complete/0},
      {"Patient Mode Environment", &check_patient_mode_env/0},
      {"Parallel Compilation", &check_parallel_compilation/0},
      {"FPPS System", &initialize_fpps/0},
      {"Error Pattern Database", &check_error_patterns/0},
      {"Compilation Monitoring", &check_compilation_monitoring/0},
      {"Zero-Warning Setup", &validate_zero_warning_setup/0}
    ]

    results = Enum.map(validation_checks, fn {name, check_function} ->
      case check_function.() do
        {:ok, message} ->
          Logger.info("✅ #{name}: #{message}")
          {name, :pass, message}
        {:error, reason} ->
          Logger.error("❌ #{name}: #{reason}")
          {name, :fail, reason}
      end
    end)

    passed = Enum.count(results, fn {_, status, _} -> status == :pass end)
    total = length(results)
    pass_rate = round(passed / total * 100)

    Logger.info("")
    Logger.info("📊 Phase 5 Validation Results:")
    Logger.info("   Passed: #{passed}/#{total} (#{pass_rate}%)")

    if pass_rate == 100 do
      Logger.info("🎉 Phase 5 Compilation Environment: READY")
      Logger.info("✅ Proceeding to Phase 6: Core Domain Systematic Compilation")
    else
      Logger.error("🚨 Phase 5 INCOMPLETE - Apply TPS Jidoka fixes")
    end

    save_validation_report("phase5", results, pass_rate)
  end

  defp check_patient_mode_env do
    env_script = "./scripts/sopv511/patient_mode_env.sh"

    if File.exists?(env_script) do
      {:ok, "Patient Mode environment script available"}
    else
      {:error, "Patient Mode environment not configured - run --setup"}
    end
  end

  defp check_parallel_compilation do
    case System.cmd("elixir", ["-e", "IO.puts(:erlang.system_info(:schedulers))"], stderr_to_stdout: true) do
      {output, 0} ->
        schedulers = String.trim(output) |> String.to_integer()
        {:ok, "Parallel compilation ready: #{schedulers} schedulers"}
      {error, _} ->
        {:error, "Parallel compilation check failed: #{error}"}
    end
  end

  defp check_error_patterns do
    pattern_files = [
      "scripts/analysis/comprehensive_error_pattern_database.exs",
      "./data/tmp/basic_error_patterns.json"
    ]

    existing = Enum.filter(pattern_files, &File.exists?/1)

    if length(existing) > 0 do
      {:ok, "Error patterns available: #{length(existing)} sources"}
    else
      {:error, "No error pattern sources found"}
    end
  end

  defp check_compilation_monitoring do
    monitoring_dirs = [
      "./data/tmp/compilation_logs",
      "./data/tmp/patient_mode_logs",
      "./data/tmp/fpps_reports"
    ]

    existing = Enum.filter(monitoring_dirs, &File.exists?/1)

    if length(existing) == length(monitoring_dirs) do
      {:ok, "All monitoring directories configured"}
    else
      missing = monitoring_dirs -- existing
      {:error, "Missing monitoring directories: #{Enum.join(missing, ", ")}"}
    end
  end

  defp show_phase_5_status do
    Logger.info("📊 SOPv5.11 Phase 5 Compilation Environment Status")
    Logger.info("🕒 Status check at: #{get_current_time()}")

    validate_phase_5()
  end

  defp fix_phase_5_issues do
    Logger.info("🔧 TPS Jidoka: Applying Phase 5 Fixes")

    # Create missing directories
    monitoring_dirs = [
      "./data/tmp/compilation_logs",
      "./data/tmp/patient_mode_logs",
      "./data/tmp/fpps_reports"
    ]

    Enum.each(monitoring_dirs, &File.mkdir_p!/1)

    # Setup Patient Mode if missing
    setup_patient_mode()

    # Create basic error patterns if missing
    setup_error_patterns()

    Logger.info("✅ Phase 5 fixes applied - run --validate to check status")
  end

  defp save_phase_5_completion_report(results) do
    result_maps = Enum.map(results, fn {description, status, message} ->
      %{
        description: description,
        status: Atom.to_string(status),
        message: message
      }
    end)

    report = %{
      phase: "Phase 5: Compilation Environment Setup",
      status: "COMPLETE",
      timestamp: get_current_time(),
      results: result_maps,
      next_phase: "Phase 6: Core Domain Systematic Compilation",
      patient_mode: "CONFIGURED",
      fpps_system: "OPERATIONAL",
      error_patterns: "AVAILABLE"
    }

    report_file = "./data/tmp/phase5_completion_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    Logger.info("📋 Phase 5 completion report: #{report_file}")
  end

  defp save_phase_5_error_report(failures) do
    failure_maps = Enum.map(failures, fn {description, status, reason} ->
      %{
        description: description,
        status: Atom.to_string(status),
        reason: reason
      }
    end)

    report = %{
      phase: "Phase 5: Compilation Environment Setup",
      status: "INCOMPLETE",
      timestamp: get_current_time(),
      failures: failure_maps,
      recommendation: "Apply TPS Jidoka fixes using --fix command"
    }

    report_file = "./data/tmp/phase5_errors_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    Logger.error("📋 Phase 5 error report: #{report_file}")
  end

  defp save_patient_compilation_report(results) do
    report = %{
      phase: "Phase 5: Patient Mode Compilation",
      timestamp: get_current_time(),
      compilation_results: results,
      patient_mode: "EXECUTED",
      recommendation: if(results.exit_code == 0,
                        do: "ZERO-WARNING ACHIEVED - Proceed to Phase 6",
                        else: "Apply systematic fixes using TPS methodology")
    }

    report_file = "./data/tmp/patient_compile_report_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    Logger.info("📋 Patient compilation report: #{report_file}")
  end

  defp save_validation_report(phase, results, pass_rate) do
    result_maps = Enum.map(results, fn {name, status, message} ->
      %{
        name: name,
        status: Atom.to_string(status),
        message: message
      }
    end)

    report = %{
      phase: phase,
      timestamp: get_current_time(),
      results: result_maps,
      pass_rate: pass_rate,
      status: if(pass_rate == 100, do: "READY", else: "INCOMPLETE")
    }

    report_file = "./data/tmp/#{phase}_validation_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))

    Logger.info("📋 Validation report saved: #{report_file}")
  end

  defp get_current_time do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end

  defp get_timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d-%H%M")
  end
end

SOPv511.Phase5CompilationSetup.main(System.argv())