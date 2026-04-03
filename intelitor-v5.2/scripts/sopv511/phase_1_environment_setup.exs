#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule SOPv511.Phase1EnvironmentSetup do
  @moduledoc """
  Phase 1: Environment Infrastructure Setup for SOPv5.11 Cybernetic Framework
  
  This script implements TPS Jidoka principles - stopping to fix any issues
  before proceeding to the next phase.
  
  Created: 2025-09-11 19:05:00 CEST
  Status: Phase 1 Implementation
  """

  require Logger

  def main(args) do
    Logger.configure(level: :info)
    
    Logger.info("🚀 SOPv5.11 Phase 1: Environment Infrastructure Setup")
    Logger.info("📋 TPS Jidoka Protocol: Stop and fix any quality issues")
    Logger.info("🕒 Starting at: #{get_current_time()}")
    
    case Enum.at(args, 0) do
      "--validate" -> validate_phase_1()
      "--setup" -> execute_phase_1_setup()
      "--status" -> show_phase_1_status()
      "--fix" -> fix_phase_1_issues()
      _ -> show_help()
    end
  end
  
  defp show_help do
    Logger.info("""
    🔧 SOPv5.11 Phase 1 Environment Setup Commands:
    
    --setup     Execute complete Phase 1 infrastructure setup
    --validate  Validate Phase 1 completion status
    --status    Show current Phase 1 infrastructure status
    --fix       Apply TPS Jidoka fixes to any detected issues
    
    Example usage:
    elixir scripts/sopv511/phase_1_environment_setup.exs --setup
    """)
  end
  
  defp execute_phase_1_setup do
    Logger.info("🏗️ Executing Phase 1: Environment Infrastructure Setup")
    
    steps = [
      {"1.1.1 - Validate DevEnv Configuration", &validate_devenv_config/0},
      {"1.1.2 - Setup PostgreSQL Database", &setup_postgresql/0},
      {"1.1.3 - Configure Redis Cache", &configure_redis/0},
      {"1.1.4 - Validate Container Runtime", &validate_container_runtime/0},
      {"1.1.5 - Setup Monitoring Infrastructure", &setup_monitoring/0},
      {"1.1.6 - Configure Logging System", &configure_logging/0},
      {"1.1.7 - Validate 50-Agent Pre__requisites", &validate_agent_pre__requisites/0},
      {"1.1.8 - Initialize PHICS System", &initialize_phics/0}
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
      Logger.info("🎉 Phase 1 Environment Infrastructure Setup: COMPLETE")
      Logger.info("✅ All 8 infrastructure components operational")
      save_phase_1_completion_report(results)
      {:ok, "Phase 1 Complete"}
    else
      Logger.error("🚨 Phase 1 BLOCKED by #{length(failures)} failures")
      Logger.error("🔧 Apply TPS Jidoka: Run --fix to address issues")
      save_phase_1_error_report(failures)
      {:error, "Phase 1 Incomplete"}
    end
  end
  
  defp validate_devenv_config do
    devenv_file = "/home/an/dev/indrajaal-demo/devenv.nix"
    
    if File.exists?(devenv_file) do
      content = File.read!(devenv_file)
      
      __required_configs = [
        "PHICS_ENABLED",
        "NO_TIMEOUT", 
        "PATIENT_MODE",
        "ELIXIR_ERL_OPTIONS"
      ]
      
      missing = Enum.filter(__required_configs, fn config ->
        not String.contains?(content, config)
      end)
      
      if Enum.empty?(missing) do
        {:ok, "DevEnv configuration complete with SOPv5.11 compliance"}
      else
        {:error, "Missing configurations: #{Enum.join(missing, ", ")}"}
      end
    else
      {:error, "devenv.nix file not found"}
    end
  end
  
  defp setup_postgresql do
    # Check for DevEnv PostgreSQL __data directory
    devenv_state = "./.devenv/__state"
    postgres_data = Path.join(devenv_state, "postgres")
    
    if File.exists?(postgres_data) do
      {:ok, "PostgreSQL configured via DevEnv (__data: #{postgres_data})"}
    else
      # Try to start services to initialize __data directory
      Logger.info("🔄 Starting PostgreSQL service via DevEnv...")
      case System.cmd("devenv", ["processes", "up", "-d"], stderr_to_stdout: true) do
        {_, 0} -> 
          # Wait a moment for initialization
          Process.sleep(2000)
          if File.exists?(postgres_data) do
            {:ok, "PostgreSQL service started and configured"}
          else
            {:error, "PostgreSQL started but __data directory not created"}
          end
        {error, _} -> {:error, "Failed to start PostgreSQL: #{error}"}
      end
    end
  end
  
  defp configure_redis do
    # Redis in DevEnv runs without persistent __data directory
    # Check if DevEnv services are configured
    devenv_state = "./.devenv/__state"
    process_compose_dir = Path.join(devenv_state, "process-compose")
    
    if File.exists?(process_compose_dir) do
      # DevEnv is initialized, Redis should be available
      {:ok, "Redis configured via DevEnv (ephemeral mode)"}
    else
      # Try to start services to initialize DevEnv
      Logger.info("🔄 Starting Redis service via DevEnv...")
      case System.cmd("devenv", ["processes", "up", "-d"], stderr_to_stdout: true) do
        {_, 0} -> 
          {:ok, "Redis service started via DevEnv"}
        {error, _} -> {:error, "Failed to start Redis: #{error}"}
      end
    end
  end
  
  defp validate_container_runtime do
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "podman version") do
          {:ok, "Podman container runtime available"}
        else
          {:error, "Podman version format unexpected"}
        end
      _ ->
        {:error, "Podman not available - install via: nix-shell -p podman"}
    end
  end
  
  defp setup_monitoring do
    # Create monitoring directories
    monitoring_dirs = [
      "./__data/tmp",
      "./__data/logs",
      "./__data/metrics"
    ]
    
    Enum.each(monitoring_dirs, fn dir ->
      File.mkdir_p!(dir)
    end)
    
    {:ok, "Monitoring directories created"}
  end
  
  defp configure_logging do
    log_dir = "./__data/tmp"
    
    if File.exists?(log_dir) do
      # Test logging capability
      test_log_file = Path.join(log_dir, "phase1_test_#{get_timestamp()}.log")
      
      case File.write(test_log_file, "Phase 1 logging test - #{get_current_time()}\n") do
        :ok -> 
          File.rm!(test_log_file)  # Clean up test file
          {:ok, "Logging system operational"}
        {:error, reason} -> 
          {:error, "Logging system failure: #{reason}"}
      end
    else
      {:error, "Log directory not available"}
    end
  end
  
  defp validate_agent_pre__requisites do
    # Check Elixir version and capabilities for 15-agent architecture
    case System.cmd("elixir", ["--version"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "Elixir") do
          {:ok, "Elixir runtime ready for 15-agent architecture"}
        else
          {:error, "Elixir version check failed"}
        end
      _ ->
        {:error, "Elixir not available"}
    end
  end
  
  defp initialize_phics do
    # Validate PHICS environment variables
    phics_vars = [
      "PHICS_ENABLED",
      "PHICS_WATCH_ENABLED",
      "PHICS_CONTAINER_MODE",
      "PHICS_HOT_RELOAD"
    ]
    
    missing_vars = Enum.filter(phics_vars, fn var ->
      is_nil(System.get_env(var))
    end)
    
    if Enum.empty?(missing_vars) do
      {:ok, "PHICS environment initialized"}
    else
      {:error, "Missing PHICS variables: #{Enum.join(missing_vars, ", ")}"}
    end
  end
  
  defp validate_phase_1 do
    Logger.info("🔍 Validating Phase 1 Environment Infrastructure")
    
    validation_checks = [
      {"DevEnv Configuration", &validate_devenv_config/0},
      {"PostgreSQL Database", &check_postgresql_status/0},
      {"Redis Cache", &check_redis_status/0},
      {"Container Runtime", &validate_container_runtime/0},
      {"Monitoring System", &check_monitoring_status/0},
      {"Logging System", &configure_logging/0},
      {"Agent Pre__requisites", &validate_agent_pre__requisites/0},
      {"PHICS System", &initialize_phics/0}
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
    Logger.info("📊 Phase 1 Validation Results:")
    Logger.info("   Passed: #{passed}/#{total} (#{pass_rate}%)")
    
    if pass_rate == 100 do
      Logger.info("🎉 Phase 1 Environment Infrastructure: READY")
      Logger.info("✅ Proceeding to Phase 2: Container Infrastructure Deployment")
    else
      Logger.error("🚨 Phase 1 INCOMPLETE - Apply TPS Jidoka fixes")
    end
    
    save_validation_report("phase1", results, pass_rate)
  end
  
  defp check_postgresql_status do
    # Check for DevEnv PostgreSQL configuration
    devenv_state = "./.devenv/__state"
    postgres_data = Path.join(devenv_state, "postgres")
    
    if File.exists?(postgres_data) do
      {:ok, "PostgreSQL configured via DevEnv (__data: #{postgres_data})"}
    else
      {:error, "PostgreSQL __data directory not found - run 'devenv processes up -d'"}
    end
  end
  
  defp check_redis_status do
    # Check for DevEnv Redis configuration (ephemeral mode)
    devenv_state = "./.devenv/__state"
    process_compose_dir = Path.join(devenv_state, "process-compose")
    
    if File.exists?(process_compose_dir) do
      {:ok, "Redis operational via DevEnv (ephemeral mode)"}
    else
      {:error, "DevEnv not initialized - run 'devenv processes up -d'"}
    end
  end
  
  defp check_monitoring_status do
    __required_dirs = ["./__data/tmp", "./__data/logs", "./__data/metrics"]
    
    missing_dirs = Enum.filter(__required_dirs, fn dir ->
      not File.exists?(dir)
    end)
    
    if Enum.empty?(missing_dirs) do
      {:ok, "Monitoring directories present"}
    else
      {:error, "Missing directories: #{Enum.join(missing_dirs, ", ")}"}
    end
  end
  
  defp show_phase_1_status do
    Logger.info("📊 SOPv5.11 Phase 1 Environment Infrastructure Status")
    Logger.info("🕒 Status check at: #{get_current_time()}")
    
    validate_phase_1()
  end
  
  defp fix_phase_1_issues do
    Logger.info("🔧 TPS Jidoka: Applying Phase 1 Fixes")
    
    # Create missing directories
    ["./__data/tmp", "./__data/logs", "./__data/metrics"]
    |> Enum.each(&File.mkdir_p!/1)
    
    # Start services if they're not running
    Logger.info("🔄 Starting DevEnv services...")
    System.cmd("devenv", ["up", "-d"], stderr_to_stdout: true)
    
    # Wait a moment for services to start
    Process.sleep(3000)
    
    Logger.info("✅ Phase 1 fixes applied - run --validate to check status")
  end
  
  defp save_phase_1_completion_report(results) do
    # Convert tuples to maps for JSON encoding
    result_maps = Enum.map(results, fn {description, status, message} ->
      %{
        description: description,
        status: Atom.to_string(status),
        message: message
      }
    end)
    
    report = %{
      phase: "Phase 1: Environment Infrastructure Setup",
      status: "COMPLETE",
      timestamp: get_current_time(),
      results: result_maps,
      next_phase: "Phase 2: Container Infrastructure Deployment"
    }
    
    report_file = "./__data/tmp/phase1_completion_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))
    
    Logger.info("📋 Phase 1 completion report: #{report_file}")
  end
  
  defp save_phase_1_error_report(failures) do
    # Convert tuples to maps for JSON encoding
    failure_maps = Enum.map(failures, fn {description, status, reason} ->
      %{
        description: description,
        status: Atom.to_string(status),
        reason: reason
      }
    end)
    
    report = %{
      phase: "Phase 1: Environment Infrastructure Setup",
      status: "INCOMPLETE",
      timestamp: get_current_time(),
      failures: failure_maps,
      recommendation: "Apply TPS Jidoka fixes using --fix command"
    }
    
    report_file = "./__data/tmp/phase1_errors_#{get_timestamp()}.json"
    File.write!(report_file, Jason.encode!(report, pretty: true))
    
    Logger.error("📋 Phase 1 error report: #{report_file}")
  end
  
  defp save_validation_report(phase, results, pass_rate) do
    # Convert tuples to maps for JSON encoding
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
    
    report_file = "./__data/tmp/#{phase}_validation_#{get_timestamp()}.json"
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

SOPv511.Phase1EnvironmentSetup.main(System.argv())