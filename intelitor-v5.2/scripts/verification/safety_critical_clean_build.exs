#!/usr/bin/env elixir

# ==============================================================================
# INTELITOR SAFETY-CRITICAL RUNTIME INTEGRITY PROTOCOL (SOPv5.11)
# ==============================================================================
# Classification: SAFETY-CRITICAL / MANDATORY
# Objective:      Clean room build, deployment, and verification of runtime versions.
# Constraints:    Elixir >= 1.19, OTP >= 28, Latest Rebar.
# Methodology:    STAMP (Safety Constraints), FMEA (Failure Mode Analysis), 5-Level RCA.
# ==============================================================================

defmodule SafetyCritical.CleanBuild do
  @moduledoc """
  Implements a NASA/Medical-grade checklist for ensuring runtime integrity.
  Replaces previous shell scripts to ensure consistent execution within the BEAM.
  """

  require Logger

  @log_dir "logs"
  @log_file Path.join(@log_dir, "safety_protocol_#{Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M%S")}.log")
  @required_elixir_min "1.19"
  @required_otp_min 28

  def run do
    setup_logging()
    print_banner()
    perform_rca_and_risk_analysis()
    
    if confirm_action("Initiate CLEAN STATE protocol? This will STOP all containers and DELETE build artifacts.") do
      perform_clean_state()
    else
      log(:warn, "Protocol aborted by user.")
      System.halt(0)
    end

    perform_artifact_build()
    perform_deployment()
    verify_runtime_integrity()
    
    log(:success, "Protocol Complete. System is Verified and Compliant.")
  end

  # ============================================================================
  # SECTION 1: ANALYSIS & DOCUMENTATION
  # ============================================================================

  defp perform_rca_and_risk_analysis do
    log(:info, ">>> [PHASE 0] SYSTEM ANALYSIS (RCA & FMEA)")
    
    rca = """
    [5-LEVEL ROOT CAUSE ANALYSIS]
    1. SURFACE:   Application container crashed with 'erts-16.1.1 not found'.
    2. DIRECT:    Release built for OTP 28, but Container Runtime was OTP 27.
    3. MECHANISM: Dockerfile explicitly pulled 'erlang_27' via Nix, mismatching mix.exs 'erlang: \"~> 28.0"'.
    4. PROCESS:   No pre-build gate to verify Infrastructure-as-Code against Application Config.
    5. SYSTEMIC:  Safety Constraints (STAMP) not enforced at infrastructure generation layer.
    """
    IO.puts(rca)
    log(:data, rca)

    fmea = """
    [FAILURE MODE & EFFECTS ANALYSIS (FMEA)]
    - Failure: Runtime Version Mismatch (OTP 27 vs 28)
    - Severity: 10 (Critical) - Total System Failure / Crash Loop.
    - Probability: High (Configuration drift).
    - Detection: High (Immediate Crash), but expensive (runtime vs build time).
    - Mitigation: Enforced Clean Room Build + Explicit Version Verification Steps.
    """
    IO.puts(fmea)
    log(:data, fmea)
  end

  # ============================================================================
  # SECTION 2: CLEAN STATE (STERILIZATION)
  # ============================================================================

  defp perform_clean_state do
    log(:info, ">>> [PHASE 1] CLEAN STATE (STERILIZATION)")

    # 1. Container Shutdown
    log(:action, "Identifying running containers...")
    case System.cmd("podman", ["ps", "-a", "--filter", "name=indrajaal", "--format", "{{.Names}}"])
    do
      {output, 0} ->
        containers = String.split(output, "\n", trim: true)
        if length(containers) > 0 do
          log(:action, "Stopping and removing containers: #{Enum.join(containers, ", ")}")
          System.cmd("podman-compose", ["-f", "podman-compose-3container.yml", "down"])
          Enum.each(containers, fn c -> 
            System.cmd("podman", ["rm", "-f", c]) 
          end)
        else
          log(:info, "No running containers found.")
        end
      {_, _} -> log(:error, "Failed to list containers.")
    end

    # 2. Artifact Purge
    log(:action, "Purging host-side build artifacts (_build, deps)...")
    File.rm_rf!("_build")
    File.rm_rf!("deps")
    log(:success, "Host environment sterilized.")
  end

  # ============================================================================
  # SECTION 3: ARTIFACT GENERATION
  # ============================================================================

  defp perform_artifact_build do
    log(:info, ">>> [PHASE 2] ARTIFACT GENERATION (CLEAN ROOM BUILD)")

    # 1. Base Image
    log(:action, "Building SOPv5.1 Base Image (OS + Runtime)...")
    log(:expect, "Dockerfile.sopv51-base must provide Erlang 28 and Elixir 1.19+")
    
    case System.cmd("podman", ["build", "-f", "Dockerfile.sopv51-base", "-t", "localhost/sopv51-base:latest", "."], stderr_to_stdout: true) do
      {_, 0} -> log(:success, "Base image built successfully.")
      {out, _} -> 
        log(:critical, "Base image build failed:\n#{out}")
        System.halt(1)
    end

    # 2. App Image
    log(:action, "Building Indrajaal App Image (Compilation)...")
    case System.cmd("podman", ["build", "-f", "Dockerfile.sopv51-app", "-t", "localhost:5000/indrajaal-sopv51-elixir-app:nixos-devenv", "."], stderr_to_stdout: true) do
      {_, 0} -> log(:success, "App image built successfully.")
      {out, _} -> 
        log(:critical, "App image build failed:\n#{out}")
        System.halt(1)
    end
  end

  # ============================================================================
  # SECTION 4: DEPLOYMENT & VERIFICATION
  # ============================================================================

  defp perform_deployment do
    log(:info, ">>> [PHASE 3] DEPLOYMENT")
    log(:action, "Starting infrastructure via Podman Compose...")
    
    case System.cmd("podman-compose", ["-f", "podman-compose-3container.yml", "up", "-d"], stderr_to_stdout: true) do
      {_, 0} -> log(:success, "Infrastructure start command issued.")
      {out, _} -> 
        log(:critical, "Infrastructure start failed:\n#{out}")
        System.halt(1)
    end

    log(:wait, "Waiting 15 seconds for container stabilization...")
    Process.sleep(15_000)
  end

  defp verify_runtime_integrity do
    log(:info, ">>> [PHASE 4] RUNTIME INTEGRITY VERIFICATION (AUDIT)")
    
    # Check 1: Elixir Version
    {elixir_out, _} = System.cmd("podman", ["exec", "indrajaal-app", "elixir", "--version"], stderr_to_stdout: true)
    log(:data, "Raw Elixir Output: #{String.replace(elixir_out, "\n", " ")}")
    
    # Check 2: OTP Version (via erl call or derived from Elixir output)
    # Elixir 1.19 output typically includes "(compiled with Erlang/OTP XX)"
    
    # Check 3: Rebar3 Version
    {rebar_out, _} = System.cmd("podman", ["exec", "indrajaal-app", "rebar3", "--version"], stderr_to_stdout: true)
    log(:data, "Raw Rebar3 Output: #{String.replace(rebar_out, "\n", " ")}")

    # Strict Checks
    elixir_match = Regex.run(~r/Elixir (\d+\.\d+\.\d+)/, elixir_out)
    otp_match = Regex.run(~r/Erlang\/OTP (\d+)/, elixir_out)

    check_elixir(elixir_match)
    check_otp(otp_match)
  end

  defp check_elixir([_, version]) do
    if Version.match?(version, ">= #{@required_elixir_min}.0") do
      log(:pass, "Elixir Version #{version} meets requirement >= #{@required_elixir_min}")
    else
      log(:fail, "Elixir Version #{version} is too old!")
      System.halt(1)
    end
  end
  defp check_elixir(_), do: log(:fail, "Could not parse Elixir version") && System.halt(1)

  defp check_otp([_, version]) do
    {ver_int, _} = Integer.parse(version)
    if ver_int >= @required_otp_min do
      log(:pass, "OTP Version #{version} meets requirement >= #{@required_otp_min}")
    else
      log(:fail, "OTP Version #{version} is too old!")
      System.halt(1)
    end
  end
  defp check_otp(_), do: log(:fail, "Could not parse OTP version") && System.halt(1)

  # ============================================================================
  # UTILITIES
  # ============================================================================

  defp setup_logging do
    File.mkdir_p!(@log_dir)
    log(:init, "Protocol initialized. Logging to #{@log_file}")
  end

  defp log(level, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    formatted = "[#{timestamp}] [#{String.upcase(to_string(level))}] #{message}"
    
    IO.puts(formatted)
    File.write!(@log_file, formatted <> "\n", [:append])
  end

  defp confirm_action(prompt) do
    IO.puts("\n⚠️  #{prompt} [Y/n]")
    answer = IO.gets("> ") |> String.trim() |> String.downcase()
    answer == "y" or answer == "yes" or answer == ""
  end

  defp print_banner do
    IO.puts """
    ================================================================================
       INTELITOR SAFETY-CRITICAL BUILD PROTOCOL (SOPv5.11)
       Targets: Elixir 1.19+ | OTP 28+ | Clean Room Build
    ================================================================================
    """
  end
end

SafetyCritical.CleanBuild.run()
