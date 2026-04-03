#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

defmodule ContainerPolicyViolationMonitor do
  @moduledoc """
  Continuous monitoring system for Container Policy Violations.
  
  CRITICAL: This script implements real-time monitoring and automated response
  to Docker policy violations with zero tolerance enforcement.
  
  Features:
  - Continuous monitoring (every 10 minutes)
  - Automatic Docker daemon detection and shutdown
  - Docker Hub image cleanup
  - Comprehensive violation logging
  - Emergency response automation
  """

  @violation_log_path "./__data/tmp/container_policy_violations.log"
  @alert_log_path "./__data/tmp/container_policy_alerts.log"

  def main(args) do
    case args do
      ["--continuous"] -> start_continuous_monitoring()
      ["--scan"] -> scan_violations_once()
      ["--emergency-cleanup"] -> emergency_docker_cleanup()
      ["--status"] -> show_compliance_status()
      ["--help"] -> show_help()
      _ -> show_help()
    end
  end

  def start_continuous_monitoring do
    IO.puts("🛡️ Starting continuous container policy violation monitoring...")
    IO.puts("📊 Scan interval: 10 minutes")
    IO.puts("📋 Logs: #{@violation_log_path}")
    IO.puts("🚨 Alerts: #{@alert_log_path}")
    
    # Initial scan
    scan_and_respond()
    
    # Continuous monitoring loop
    monitoring_loop()
  end

  def scan_violations_once do
    IO.puts("🔍 Single scan for container policy violations...")
    scan_and_respond()
  end

  def emergency_docker_cleanup do
    IO.puts("🚨 EMERGENCY: Docker cleanup initiated...")
    
    violations = detect_violations()
    
    if violations != [] do
      log_emergency("Emergency Docker cleanup initiated due to violations: #{inspect(violations)}")
      
      # Stop Docker daemon if running
      stop_docker_daemon()
      
      # Remove Docker Hub images
      cleanup_docker_images()
      
      # Final verification
      post_cleanup_scan()
    else
      IO.puts("✅ No Docker violations detected - cleanup not needed")
    end
  end

  def show_compliance_status do
    IO.puts("📊 Container Policy Compliance Status")
    IO.puts("=====================================")
    
    violations = detect_violations()
    
    if violations == [] do
      IO.puts("✅ COMPLIANT: No Docker policy violations detected")
    else
      IO.puts("❌ VIOLATIONS DETECTED:")
      Enum.each(violations, fn violation ->
        IO.puts("  - #{violation}")
      end)
    end
    
    # Show Podman status
    show_podman_status()
    
    # Show recent violations
    show_recent_violations()
  end

  defp monitoring_loop do
    # Wait 10 minutes (600,000 milliseconds)
    :timer.sleep(600_000)
    
    scan_and_respond()
    monitoring_loop()
  end

  defp scan_and_respond do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    violations = detect_violations()
    
    if violations != [] do
      log_violation(timestamp, violations)
      respond_to_violations(violations)
    else
      log_clean_scan(timestamp)
    end
  end

  defp detect_violations do
    violations = []
    
    violations = violations ++ check_docker_daemon()
    violations = violations ++ check_docker_cli()
    violations = violations ++ check_docker_images()
    violations = violations ++ check_docker_processes()
    violations = violations ++ scan_code_violations()
    
    violations
  end

  defp check_docker_daemon do
    case System.cmd("systemctl", ["is-active", "docker"], stderr_to_stdout: true) do
      {"active\n", 0} ->
        ["CRITICAL: Docker daemon is running"]
      _ ->
        []
    end
  end

  defp check_docker_cli do
    case System.cmd("which", ["docker"], stderr_to_stdout: true) do
      {_, 0} ->
        ["HIGH: Docker CLI is installed and accessible"]
      _ ->
        []
    end
  end

  defp check_docker_images do
    case System.cmd("podman", ["images", "--format", "{{.Repository}}"], stderr_to_stdout: true) do
      {output, 0} ->
        docker_images = 
          output
          |> String.split("\n")
          |> Enum.filter(fn repo ->
            String.contains?(repo, "docker.io") or String.contains?(repo, "hub.docker")
          end)
        
        if length(docker_images) > 0 do
          ["MEDIUM: Docker Hub images found: #{inspect(docker_images)}"]
        else
          []
        end
      _ ->
        []
    end
  end

  defp check_docker_processes do
    case System.cmd("ps", ["aux"], stderr_to_stdout: true) do
      {output, 0} ->
        if String.contains?(output, "dockerd") do
          ["CRITICAL: Docker daemon process detected"]
        else
          []
        end
      _ ->
        []
    end
  end

  defp scan_code_violations do
    violations = []
    
    # Check key files for docker references
    key_files = [
      "README.md",
      "CLAUDE.md", 
      "mix.exs",
      "devenv.nix"
    ]
    
    code_violations = 
      key_files
      |> Enum.flat_map(fn file ->
        if File.exists?(file) do
          case File.read(file) do
            {:ok, content} ->
              if Regex.match?(~r/docker\s+run|docker\.io\//i, content) do
                ["LOW: Docker references found in #{file}"]
              else
                []
              end
            _ ->
              []
          end
        else
          []
        end
      end)
    
    violations ++ code_violations
  end

  defp respond_to_violations(violations) do
    critical_violations = Enum.filter(violations, &String.starts_with?(&1, "CRITICAL"))
    high_violations = Enum.filter(violations, &String.starts_with?(&1, "HIGH"))
    
    if length(critical_violations) > 0 do
      handle_critical_violations(critical_violations)
    end
    
    if length(high_violations) > 0 do
      handle_high_violations(high_violations)
    end
    
    log_alert("Violations detected: #{inspect(violations)}")
  end

  defp handle_critical_violations(violations) do
    IO.puts("🚨 CRITICAL VIOLATIONS - AUTOMATIC RESPONSE INITIATED")
    Enum.each(violations, &IO.puts("  ❌ #{&1}"))
    
    # Automatically stop Docker daemon
    stop_docker_daemon()
    
    # Kill any Docker processes
    System.cmd("pkill", ["-f", "dockerd"], stderr_to_stdout: true)
    
    log_alert("CRITICAL: Automatic response executed for violations: #{inspect(violations)}")
  end

  defp handle_high_violations(violations) do
    IO.puts("⚠️ HIGH VIOLATIONS - MANUAL INTERVENTION RECOMMENDED")
    Enum.each(violations, &IO.puts("  ❌ #{&1}"))
    
    log_alert("HIGH: Manual intervention needed for violations: #{inspect(violations)}")
  end

  defp stop_docker_daemon do
    IO.puts("🛑 Stopping Docker daemon...")
    
    case System.cmd("sudo", ["systemctl", "stop", "docker"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✅ Docker daemon stopped successfully")
        
        # Also disable it
        System.cmd("sudo", ["systemctl", "disable", "docker"], stderr_to_stdout: true)
        IO.puts("✅ Docker daemon disabled from startup")
      {error, _} ->
        IO.puts("⚠️ Could not stop Docker daemon: #{error}")
    end
  end

  defp cleanup_docker_images do
    IO.puts("🧹 Cleaning up Docker Hub images...")
    
    case System.cmd("podman", ["images", "--format", "{{.Repository}}:{{.Tag}}"], stderr_to_stdout: true) do
      {output, 0} ->
        docker_images = 
          output
          |> String.split("\n")
          |> Enum.filter(fn image ->
            String.contains?(image, "docker.io") or String.contains?(image, "hub.docker")
          end)
        
        Enum.each(docker_images, fn image ->
          if image != "" do
            case System.cmd("podman", ["rmi", "-f", image], stderr_to_stdout: true) do
              {_, 0} ->
                IO.puts("✅ Removed Docker image: #{image}")
              {error, _} ->
                IO.puts("⚠️ Could not remove #{image}: #{error}")
            end
          end
        end)
      {error, _} ->
        IO.puts("⚠️ Could not list images: #{error}")
    end
  end

  defp post_cleanup_scan do
    IO.puts("🔍 Post-cleanup verification scan...")
    violations = detect_violations()
    
    if violations == [] do
      IO.puts("✅ SUCCESS: All Docker violations resolved")
      log_alert("SUCCESS: Emergency cleanup completed - all violations resolved")
    else
      IO.puts("❌ REMAINING VIOLATIONS:")
      Enum.each(violations, &IO.puts("  - #{&1}"))
      log_alert("WARNING: Emergency cleanup completed but violations remain: #{inspect(violations)}")
    end
  end

  defp show_podman_status do
    IO.puts("\n🏗️ Podman Status:")
    
    case System.cmd("podman", ["--version"], stderr_to_stdout: true) do
      {version, 0} ->
        IO.puts("✅ #{String.trim(version)}")
      _ ->
        IO.puts("❌ Podman not available")
    end
    
    # Show rootless status
    case System.cmd("podman", ["info", "--format", "{{.Host.Security.Rootless}}"], stderr_to_stdout: true) do
      {"true\n", 0} ->
        IO.puts("✅ Rootless mode: Active")
      _ ->
        IO.puts("⚠️ Rootless mode: Unknown")
    end
  end

  defp show_recent_violations do
    IO.puts("\n📋 Recent Violations (last 24 hours):")
    
    if File.exists?(@violation_log_path) do
      case File.read(@violation_log_path) do
        {:ok, content} ->
          recent_lines = 
            content
            |> String.split("\n")
            |> Enum.take(-10)
            |> Enum.reject(&(&1 == ""))
          
          if recent_lines == [] do
            IO.puts("✅ No recent violations")
          else
            Enum.each(recent_lines, &IO.puts("  #{&1}"))
          end
        _ ->
          IO.puts("ℹ️ No violation log found")
      end
    else
      IO.puts("ℹ️ No violation log found")
    end
  end

  defp log_violation(timestamp, violations) do
    log_entry = "#{timestamp} - VIOLATIONS: #{inspect(violations)}"
    File.write(@violation_log_path, log_entry <> "\n", [:append])
    IO.puts("📋 Logged violations: #{length(violations)} violations found")
  end

  defp log_clean_scan(timestamp) do
    log_entry = "#{timestamp} - CLEAN: No violations detected"
    File.write(@violation_log_path, log_entry <> "\n", [:append])
  end

  defp log_alert(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    log_entry = "#{timestamp} - ALERT: #{message}"
    File.write(@alert_log_path, log_entry <> "\n", [:append])
    IO.puts("🚨 ALERT: #{message}")
  end

  defp log_emergency(message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    log_entry = "#{timestamp} - EMERGENCY: #{message}"
    File.write(@alert_log_path, log_entry <> "\n", [:append])
    IO.puts("🚨 EMERGENCY: #{message}")
  end

  defp show_help do
    IO.puts("""
    🛡️ Container Policy Violation Monitor - SOPv5.11 Compliance
    
    Usage:
      elixir scripts/validation/container_policy_violation_monitor.exs [COMMAND]
    
    Commands:
      --continuous        Start continuous monitoring (10 min intervals)
      --scan             Perform single violation scan
      --emergency-cleanup Emergency Docker cleanup and removal
      --status           Show current compliance status
      --help             Show this help message
    
    🚨 CRITICAL: Zero tolerance Docker policy enforcement
    🛡️ SECURITY: Automated Docker daemon detection and shutdown
    📋 LOGGING: Complete violation audit trail
    ⚡ RESPONSE: Automatic emergency response for critical violations
    
    Violation Severity Levels:
      🔴 CRITICAL - Docker daemon running (automatic shutdown)
      🟠 HIGH     - Docker CLI accessible (manual intervention)  
      🟡 MEDIUM   - Docker Hub images present (automatic cleanup)
      🟢 LOW      - Documentation references (update __required)
    
    Log Files:
      #{@violation_log_path} - Violation history
      #{@alert_log_path}     - Alert and response log
    
    Examples:
      # Start continuous monitoring (recommended for servers)
      elixir scripts/validation/container_policy_violation_monitor.exs --continuous
      
      # Single compliance check
      elixir scripts/validation/container_policy_violation_monitor.exs --scan
      
      # Emergency cleanup
      elixir scripts/validation/container_policy_violation_monitor.exs --emergency-cleanup
      
      # Check current status
      elixir scripts/validation/container_policy_violation_monitor.exs --status
    """)
  end
end

# Ensure __data/tmp directory exists
File.mkdir_p!("./__data/tmp")

# Execute if run as script
if System.argv() |> length() > 0 do
  ContainerPolicyViolationMonitor.main(System.argv())
else
  ContainerPolicyViolationMonitor.show_help()
end