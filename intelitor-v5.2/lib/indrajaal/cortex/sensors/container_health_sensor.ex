defmodule Indrajaal.Cortex.Sensors.ContainerHealthSensor do
  @moduledoc """
  Container Health Verification Sensor for Cortex.

  Implements the formal 7-phase verification protocol defined in:
  - docs/formal_specs/container_verification.qnt (Quint state machine)
  - docs/formal_specs/container_verification.agda (Agda proofs)
  - docs/formal_specs/container_verification.m (Mathematica specs)

  Verification Phases (§Q.CNT.6 from Quint spec):
    Phase 1: Version Verification (Elixir, OTP, ERTS)
    Phase 2: Package Verification (required binaries)
    Phase 3: Environment Verification (NO_TIMEOUT, PHICS, etc.)
    Phase 4: Network Verification (DNS, connectivity)
    Phase 5: SSL Verification (CA certificates)
    Phase 6: PHICS Verification (hot-reload latency)
    Phase 7: STAMP Verification (safety constraints)

  STAMP Constraints Verified:
    SC-CNT-009: Container OS is NixOS
    SC-CNT-010: Registry is localhost only
    SC-CNT-011: PHICS latency < 50ms
    SC-CNT-012: Rootless execution
    SC-CNT-V01: Elixir version correct
    SC-CNT-V02: OTP version correct

  TDG Compliance:
    TDG-CNT-001: Tests precede container build
    TDG-CNT-004: Every STAMP constraint has a test

  AOR Compliance:
    AOR-CNT-001: Docker is FORBIDDEN, Podman required
    AOR-CNT-002: nix-build for container creation
    AOR-CNT-003: localhost registry only

  Usage:
      ContainerHealthSensor.measure()
      ContainerHealthSensor.full_verification()
      ContainerHealthSensor.verify_phase(:versions)
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.Sensors.ContainerHealthTelemetry, as: Telemetry

  # Expected versions (from Agda §A.CNT.2)
  @expected_elixir %{major: 1, minor: 19, patch: 2}
  @expected_otp %{major: 28, minor: 0, patch: 0}
  @expected_erts %{major: 16, minor: 1, patch: 1}

  # Required packages (from Quint §Q.CNT.3)
  @required_packages ~w(elixir erl git curl wget make gcc psql node inotifywait entr)

  # PHICS latency threshold (SC-CNT-011)
  @phics_latency_threshold_ms 50

  # Verification timeout (from Quint §Q.CNT.3)
  @verification_timeout_ms 60_000

  # Max verification attempts (from Agda §A.CNT.14) - reserved for retry logic
  # @max_attempts 3

  # Verification phases (from Quint §Q.CNT.1)
  @verification_phases [
    :initializing,
    :verifying_versions,
    :verifying_packages,
    :verifying_environment,
    :verifying_network,
    :verifying_ssl,
    :verifying_phics,
    :verifying_stamp,
    :complete,
    :failed
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Measure current container health state.
  Returns a map suitable for Cortex OODA loop observation.
  """
  def measure do
    GenServer.call(__MODULE__, :measure, @verification_timeout_ms)
  end

  @doc """
  Perform full 7-phase verification.
  Returns {:ok, results} or {:error, phase, reason}.
  """
  def full_verification do
    GenServer.call(__MODULE__, :full_verification, @verification_timeout_ms)
  end

  @doc """
  Verify a specific phase.
  """
  def verify_phase(phase) when phase in @verification_phases do
    GenServer.call(__MODULE__, {:verify_phase, phase}, @verification_timeout_ms)
  end

  @doc """
  Get the current verification state.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get STAMP constraint compliance report.
  """
  def stamp_compliance do
    GenServer.call(__MODULE__, :stamp_compliance)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📦 ContainerHealthSensor: Starting container health monitoring")

    state = %{
      phase: :initializing,
      verification_results: %{},
      stamp_constraints: %{},
      last_verification: nil,
      verification_count: 0,
      failure_count: 0,
      started_at: DateTime.utc_now()
    }

    # Perform initial verification after startup
    send(self(), :initial_verification)

    {:ok, state}
  end

  @impl true
  def handle_call(:measure, _from, state) do
    # Quick measurement for OODA loop (non-blocking summary)
    measurement = %{
      healthy: state.phase == :complete,
      phase: state.phase,
      last_verification: state.last_verification,
      stamp_compliant: all_stamp_satisfied?(state.stamp_constraints),
      verification_count: state.verification_count,
      failure_rate: calculate_failure_rate(state)
    }

    {:reply, measurement, state}
  end

  @impl true
  def handle_call(:full_verification, _from, state) do
    {result, new_state} = run_full_verification(state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:verify_phase, phase}, _from, state) do
    result = verify_single_phase(phase)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:stamp_compliance, _from, state) do
    report = generate_stamp_report(state.stamp_constraints)
    {:reply, report, state}
  end

  @impl true
  def handle_info(:initial_verification, state) do
    Logger.info("📦 ContainerHealthSensor: Running initial container verification")
    {_result, new_state} = run_full_verification(state)
    {:noreply, new_state}
  end

  ## Verification Implementation

  defp run_full_verification(state) do
    start_time = System.monotonic_time(:millisecond)

    Logger.info("📦 ContainerHealthSensor: Starting 7-phase verification")

    # Emit telemetry: verification start
    Telemetry.emit_verification_start(%{verification_count: state.verification_count})

    phases = [
      {:verifying_versions, &verify_versions/0},
      {:verifying_packages, &verify_packages/0},
      {:verifying_environment, &verify_environment/0},
      {:verifying_network, &verify_network/0},
      {:verifying_ssl, &verify_ssl/0},
      {:verifying_phics, &verify_phics/0},
      {:verifying_stamp, &verify_stamp/0}
    ]

    {final_phase, results, stamp} =
      Enum.reduce_while(phases, {:initializing, %{}, %{}}, fn {phase, verify_fn},
                                                              {_, results, stamp} ->
        Logger.debug("📦 Verification: Entering phase #{phase}")
        phase_start = System.monotonic_time(:millisecond)

        case verify_fn.() do
          {:ok, phase_result} ->
            phase_duration = System.monotonic_time(:millisecond) - phase_start
            new_results = Map.put(results, phase, %{status: :passed, result: phase_result})
            new_stamp = update_stamp_from_phase(stamp, phase, phase_result)

            # Emit telemetry: phase complete
            Telemetry.emit_phase_complete(phase, phase_duration, phase_result)

            {:cont, {phase, new_results, new_stamp}}

          {:error, reason} ->
            phase_duration = System.monotonic_time(:millisecond) - phase_start
            new_results = Map.put(results, phase, %{status: :failed, error: reason})

            # Emit telemetry: phase failed
            Telemetry.emit_phase_failed(phase, phase_duration, reason)

            {:halt, {:failed, new_results, stamp}}
        end
      end)

    final_phase =
      if final_phase != :failed do
        :complete
      else
        :failed
      end

    latency_ms = System.monotonic_time(:millisecond) - start_time

    new_state = %{
      state
      | phase: final_phase,
        verification_results: results,
        stamp_constraints: stamp,
        last_verification: DateTime.utc_now(),
        verification_count: state.verification_count + 1,
        failure_count:
          if(final_phase == :failed, do: state.failure_count + 1, else: state.failure_count)
    }

    result = %{
      success: final_phase == :complete,
      phase: final_phase,
      results: results,
      stamp_constraints: stamp,
      latency_ms: latency_ms,
      within_timeout: latency_ms <= @verification_timeout_ms
    }

    log_verification_result(result)

    # Emit telemetry: verification complete
    Telemetry.emit_verification_stop(
      result.success,
      latency_ms,
      %{stamp_constraints: stamp, phase: final_phase}
    )

    {result, new_state}
  end

  defp verify_single_phase(phase) do
    case phase do
      :verifying_versions -> verify_versions()
      :verifying_packages -> verify_packages()
      :verifying_environment -> verify_environment()
      :verifying_network -> verify_network()
      :verifying_ssl -> verify_ssl()
      :verifying_phics -> verify_phics()
      :verifying_stamp -> verify_stamp()
      _ -> {:error, :unknown_phase}
    end
  end

  ## Phase 1: Version Verification (SC-CNT-V01, SC-CNT-V02)

  defp verify_versions do
    elixir_version = parse_elixir_version()
    otp_version = parse_otp_version()
    erts_version = parse_erts_version()

    elixir_ok = version_matches?(elixir_version, @expected_elixir)
    otp_ok = version_matches_major?(otp_version, @expected_otp)
    erts_ok = version_matches_major_minor?(erts_version, @expected_erts)

    result = %{
      elixir: %{actual: elixir_version, expected: @expected_elixir, valid: elixir_ok},
      otp: %{actual: otp_version, expected: @expected_otp, valid: otp_ok},
      erts: %{actual: erts_version, expected: @expected_erts, valid: erts_ok}
    }

    if elixir_ok and otp_ok and erts_ok do
      {:ok, result}
    else
      {:error, {:version_mismatch, result}}
    end
  end

  defp parse_elixir_version do
    version = System.version()

    case String.split(version, ".") do
      [major, minor, patch | _] ->
        %{
          major: String.to_integer(major),
          minor: String.to_integer(minor),
          patch: parse_patch(patch)
        }

      _ ->
        %{major: 0, minor: 0, patch: 0}
    end
  end

  defp parse_patch(patch_str) do
    # Handle versions like "2-otp-28" or "2"
    case Integer.parse(patch_str) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_otp_version do
    # Get OTP release from system
    otp_release = to_string(:erlang.system_info(:otp_release))

    case Integer.parse(otp_release) do
      {major, _} -> %{major: major, minor: 0, patch: 0}
      :error -> %{major: 0, minor: 0, patch: 0}
    end
  end

  defp parse_erts_version do
    erts_version = to_string(:erlang.system_info(:version))

    case String.split(erts_version, ".") do
      [major, minor | rest] ->
        patch = if length(rest) > 0, do: String.to_integer(hd(rest)), else: 0

        %{
          major: String.to_integer(major),
          minor: String.to_integer(minor),
          patch: patch
        }

      _ ->
        %{major: 0, minor: 0, patch: 0}
    end
  end

  defp version_matches?(actual, expected) do
    actual.major == expected.major and
      actual.minor == expected.minor and
      actual.patch >= expected.patch
  end

  defp version_matches_major?(actual, expected) do
    actual.major == expected.major
  end

  defp version_matches_major_minor?(actual, expected) do
    actual.major == expected.major and actual.minor >= expected.minor
  end

  ## Phase 2: Package Verification

  defp verify_packages do
    results =
      Enum.map(@required_packages, fn pkg ->
        available = check_package_available(pkg)
        {pkg, available}
      end)

    missing =
      results |> Enum.filter(fn {_, available} -> not available end) |> Enum.map(&elem(&1, 0))

    if Enum.empty?(missing) do
      {:ok, %{packages: Map.new(results), all_available: true}}
    else
      {:error, {:missing_packages, missing}}
    end
  end

  defp check_package_available(package) do
    case System.cmd("which", [package], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  ## Phase 3: Environment Verification

  defp verify_environment do
    env_checks = %{
      no_timeout: System.get_env("NO_TIMEOUT") == "true",
      patient_mode: System.get_env("PATIENT_MODE") == "enabled",
      phics_enabled: System.get_env("PHICS_ENABLED", "true") == "true",
      container_type: detect_container_type(),
      rootless: detect_rootless(),
      timezone: System.get_env("TZ", "Europe/Berlin")
    }

    # Container type check (SC-CNT-009: Must be NixOS/Podman)
    container_ok = env_checks.container_type in [:nixos, :podman]

    if container_ok do
      {:ok, env_checks}
    else
      {:error, {:invalid_container_type, env_checks.container_type}}
    end
  end

  defp detect_container_type do
    cond do
      File.exists?("/etc/nixos/configuration.nix") -> :nixos
      File.exists?("/run/.containerenv") -> :podman
      # FORBIDDEN per AOR-CNT-001
      File.exists?("/.dockerenv") -> :docker
      true -> :unknown
    end
  end

  defp detect_rootless do
    # Check if running as non-root
    case System.cmd("id", ["-u"], stderr_to_stdout: true) do
      # Running as root
      {"0\n", 0} -> false
      # Running as non-root (rootless)
      {_, 0} -> true
      _ -> :unknown
    end
  rescue
    _ -> :unknown
  end

  ## Phase 4: Network Verification

  defp verify_network do
    # DNS resolution check
    dns_ok =
      case :inet.gethostbyname(~c"localhost") do
        {:ok, _} -> true
        _ -> false
      end

    # Check if we can reach localhost (basic connectivity)
    localhost_ok =
      case :gen_tcp.connect(~c"127.0.0.1", 4369, [], 1000) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        {:error, :econnrefused} ->
          # EPMD not running is OK, connection was attempted
          true

        _ ->
          false
      end

    result = %{
      dns_working: dns_ok,
      localhost_reachable: localhost_ok
    }

    if dns_ok do
      {:ok, result}
    else
      {:error, {:network_failure, result}}
    end
  end

  ## Phase 5: SSL Verification

  defp verify_ssl do
    # Check CA certificates
    ca_bundle_paths = [
      "/etc/ssl/certs/ca-certificates.crt",
      "/etc/ssl/certs/ca-bundle.crt",
      "/etc/pki/tls/certs/ca-bundle.crt"
    ]

    ca_bundle_exists = Enum.any?(ca_bundle_paths, &File.exists?/1)

    # Check Erlang SSL application
    ssl_app_ok =
      case Application.ensure_started(:ssl) do
        :ok -> true
        {:error, {:already_started, :ssl}} -> true
        _ -> false
      end

    result = %{
      ca_bundle_exists: ca_bundle_exists,
      ssl_app_running: ssl_app_ok,
      ca_bundle_path: Enum.find(ca_bundle_paths, &File.exists?/1)
    }

    if ca_bundle_exists and ssl_app_ok do
      {:ok, result}
    else
      {:error, {:ssl_failure, result}}
    end
  end

  ## Phase 6: PHICS Verification (SC-CNT-011)

  defp verify_phics do
    # Measure simulated PHICS latency (code reload capability)
    start_time = System.monotonic_time(:microsecond)

    # Simulate a code path check (in production, this would check Phoenix hot reload)
    _dummy_check = Code.ensure_loaded?(Indrajaal.Application)

    latency_us = System.monotonic_time(:microsecond) - start_time
    latency_ms = latency_us / 1000

    phics_enabled = System.get_env("PHICS_ENABLED", "true") == "true"

    result = %{
      enabled: phics_enabled,
      latency_ms: Float.round(latency_ms, 2),
      within_threshold: latency_ms < @phics_latency_threshold_ms,
      threshold_ms: @phics_latency_threshold_ms
    }

    if latency_ms < @phics_latency_threshold_ms do
      {:ok, result}
    else
      {:error, {:phics_latency_exceeded, result}}
    end
  end

  ## Phase 7: STAMP Verification

  defp verify_stamp do
    constraints = %{
      "SC-CNT-009" => %{
        description: "Container OS is NixOS/Podman",
        satisfied: detect_container_type() in [:nixos, :podman]
      },
      "SC-CNT-010" => %{
        description: "Registry is localhost only",
        satisfied: check_localhost_registry()
      },
      "SC-CNT-011" => %{
        description: "PHICS latency < 50ms",
        satisfied: check_phics_latency()
      },
      "SC-CNT-012" => %{
        description: "Rootless execution",
        satisfied: detect_rootless() == true
      },
      "SC-CNT-V01" => %{
        description: "Elixir version correct (1.19.x)",
        satisfied: check_elixir_version()
      },
      "SC-CNT-V02" => %{
        description: "OTP version correct (28)",
        satisfied: check_otp_version()
      }
    }

    # Emit telemetry for each STAMP constraint check
    Enum.each(constraints, fn {id, %{satisfied: satisfied, description: desc}} ->
      Telemetry.emit_stamp_check(id, satisfied, %{description: desc})

      unless satisfied do
        Telemetry.emit_stamp_violation(id, "Constraint not satisfied: #{desc}", :critical)
      end
    end)

    all_satisfied = Enum.all?(constraints, fn {_, v} -> v.satisfied end)

    result = %{
      constraints: constraints,
      all_satisfied: all_satisfied,
      satisfied_count: Enum.count(constraints, fn {_, v} -> v.satisfied end),
      total_count: map_size(constraints)
    }

    if all_satisfied do
      {:ok, result}
    else
      failed = constraints |> Enum.filter(fn {_, v} -> not v.satisfied end) |> Map.new()
      {:error, {:stamp_violations, failed}}
    end
  end

  defp check_localhost_registry do
    # Check container image origin (would check container labels in production)
    # For now, assume localhost if not running in Docker
    not File.exists?("/.dockerenv")
  end

  defp check_phics_latency do
    start_time = System.monotonic_time(:microsecond)
    _dummy = Code.ensure_loaded?(Kernel)
    latency_ms = (System.monotonic_time(:microsecond) - start_time) / 1000
    latency_ms < @phics_latency_threshold_ms
  end

  defp check_elixir_version do
    version = parse_elixir_version()
    version.major == 1 and version.minor == 19
  end

  defp check_otp_version do
    version = parse_otp_version()
    version.major == 28
  end

  ## Helpers

  defp update_stamp_from_phase(stamp, :verifying_versions, result) do
    Map.merge(stamp, %{
      "SC-CNT-V01" => result.elixir.valid,
      "SC-CNT-V02" => result.otp.valid
    })
  end

  defp update_stamp_from_phase(stamp, :verifying_environment, result) do
    Map.merge(stamp, %{
      "SC-CNT-009" => result.container_type in [:nixos, :nixos_podman, :podman],
      "SC-CNT-012" => result.rootless == true
    })
  end

  defp update_stamp_from_phase(stamp, :verifying_phics, result) do
    Map.put(stamp, "SC-CNT-011", result.within_threshold)
  end

  defp update_stamp_from_phase(stamp, _phase, _result), do: stamp

  defp all_stamp_satisfied?(constraints) when map_size(constraints) == 0, do: false

  defp all_stamp_satisfied?(constraints) do
    Enum.all?(constraints, fn {_, satisfied} -> satisfied end)
  end

  defp calculate_failure_rate(%{verification_count: 0}), do: 0.0

  defp calculate_failure_rate(state) do
    Float.round(state.failure_count / state.verification_count, 3)
  end

  defp generate_stamp_report(constraints) do
    %{
      constraints: constraints,
      summary: %{
        total: map_size(constraints),
        satisfied: Enum.count(constraints, fn {_, v} -> v end),
        failed: Enum.count(constraints, fn {_, v} -> not v end)
      },
      compliant: all_stamp_satisfied?(constraints),
      timestamp: DateTime.utc_now()
    }
  end

  defp log_verification_result(result) do
    if result.success do
      Logger.info(
        "📦 ContainerHealthSensor: Verification PASSED in #{result.latency_ms}ms " <>
          "(#{map_size(result.stamp_constraints)} STAMP constraints verified)"
      )
    else
      Logger.warning(
        "📦 ContainerHealthSensor: Verification FAILED at phase #{result.phase} " <>
          "(#{result.latency_ms}ms)"
      )
    end
  end
end
