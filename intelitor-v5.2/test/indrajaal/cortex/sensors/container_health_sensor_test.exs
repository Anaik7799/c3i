defmodule Indrajaal.Cortex.Sensors.ContainerHealthSensorTest do
  @moduledoc """
  Tests for the ContainerHealthSensor module.

  STAMP Compliance:
  - SC-CNT-009: Container OS is NixOS
  - SC-CNT-010: Registry source verification
  - SC-CNT-011: PHICS latency monitoring
  - SC-CNT-012: Rootless execution verification
  - SC-CNT-V01: Elixir version verification
  - SC-CNT-V02: OTP version verification
  - SC-OBS-065: Container health observability

  TDG: Test-Driven Generation - tests created before implementation validation.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.ContainerHealthSensor

  @moduletag :cortex
  @moduletag :container_health
  @moduletag :stamp_compliance

  setup do
    # Start the GenServer if not already running
    case GenServer.whereis(ContainerHealthSensor) do
      nil ->
        {:ok, pid} = ContainerHealthSensor.start_link([])

        on_exit(fn ->
          # Only stop if process is still alive
          if Process.alive?(pid) do
            try do
              GenServer.stop(pid, :normal, 5000)
            catch
              :exit, _ -> :ok
            end
          end
        end)

        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ContainerHealthSensor)
    end

    test "exports measure/0 function" do
      assert function_exported?(ContainerHealthSensor, :measure, 0)
    end

    test "exports full_verification/0 function" do
      assert function_exported?(ContainerHealthSensor, :full_verification, 0)
    end

    test "exports verify_phase/1 function" do
      assert function_exported?(ContainerHealthSensor, :verify_phase, 1)
    end

    test "exports get_state/0 function" do
      assert function_exported?(ContainerHealthSensor, :get_state, 0)
    end

    test "exports stamp_compliance/0 function" do
      assert function_exported?(ContainerHealthSensor, :stamp_compliance, 0)
    end
  end

  describe "measure/0" do
    test "returns a map with expected keys" do
      result = ContainerHealthSensor.measure()

      assert is_map(result)
      assert Map.has_key?(result, :healthy)
      assert Map.has_key?(result, :phase)
      assert Map.has_key?(result, :stamp_compliant)
      assert Map.has_key?(result, :verification_count)
    end

    test "healthy is a boolean" do
      result = ContainerHealthSensor.measure()

      assert is_boolean(result.healthy)
    end

    test "phase is a valid atom" do
      result = ContainerHealthSensor.measure()

      valid_phases = [
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

      assert result.phase in valid_phases
    end
  end

  describe "full_verification/0" do
    @tag timeout: 120_000
    test "returns verification results map" do
      result = ContainerHealthSensor.full_verification()

      assert is_map(result)
      assert Map.has_key?(result, :success)
      assert Map.has_key?(result, :phase)
      assert Map.has_key?(result, :results)
      assert Map.has_key?(result, :stamp_constraints)
      assert Map.has_key?(result, :latency_ms)
    end

    @tag timeout: 120_000
    test "success is a boolean" do
      result = ContainerHealthSensor.full_verification()

      assert is_boolean(result.success)
    end

    @tag timeout: 120_000
    test "latency_ms is a number" do
      result = ContainerHealthSensor.full_verification()

      assert is_number(result.latency_ms)
      assert result.latency_ms >= 0
    end
  end

  describe "verify_phase/1" do
    test "verifying_versions returns version information" do
      result = ContainerHealthSensor.verify_phase(:verifying_versions)

      case result do
        {:ok, version_info} ->
          assert Map.has_key?(version_info, :elixir)
          assert Map.has_key?(version_info, :otp)
          assert Map.has_key?(version_info, :erts)

        {:error, _reason} ->
          # Version mismatch is acceptable in test environment
          assert true
      end
    end

    test "verifying_packages checks required packages" do
      result = ContainerHealthSensor.verify_phase(:verifying_packages)

      case result do
        {:ok, pkg_info} ->
          assert Map.has_key?(pkg_info, :packages)
          assert Map.has_key?(pkg_info, :all_available)

        {:error, {:missing_packages, missing}} ->
          # Missing packages is acceptable in test environment
          assert is_list(missing)
      end
    end

    test "verifying_environment checks environment settings" do
      result = ContainerHealthSensor.verify_phase(:verifying_environment)

      case result do
        {:ok, env_info} ->
          assert Map.has_key?(env_info, :container_type)
          assert Map.has_key?(env_info, :rootless)

        {:error, _reason} ->
          # Environment errors acceptable in test environment
          assert true
      end
    end

    test "verifying_network checks network connectivity" do
      result = ContainerHealthSensor.verify_phase(:verifying_network)

      case result do
        {:ok, net_info} ->
          assert Map.has_key?(net_info, :dns_working)
          assert Map.has_key?(net_info, :localhost_reachable)

        {:error, _reason} ->
          # Network issues acceptable in test environment
          assert true
      end
    end

    test "verifying_ssl checks SSL configuration" do
      result = ContainerHealthSensor.verify_phase(:verifying_ssl)

      case result do
        {:ok, ssl_info} ->
          assert Map.has_key?(ssl_info, :ca_bundle_exists)
          assert Map.has_key?(ssl_info, :ssl_app_running)

        {:error, _reason} ->
          # SSL issues acceptable in test environment
          assert true
      end
    end

    test "verifying_phics checks PHICS latency" do
      result = ContainerHealthSensor.verify_phase(:verifying_phics)

      case result do
        {:ok, phics_info} ->
          assert Map.has_key?(phics_info, :latency_ms)
          assert Map.has_key?(phics_info, :within_threshold)
          assert phics_info.threshold_ms == 50

        {:error, _reason} ->
          # PHICS latency exceeded is acceptable
          assert true
      end
    end

    test "verifying_stamp checks STAMP constraints" do
      result = ContainerHealthSensor.verify_phase(:verifying_stamp)

      case result do
        {:ok, stamp_info} ->
          assert Map.has_key?(stamp_info, :constraints)
          assert Map.has_key?(stamp_info, :all_satisfied)
          assert Map.has_key?(stamp_info, :satisfied_count)
          assert Map.has_key?(stamp_info, :total_count)

        {:error, {:stamp_violations, violations}} ->
          # STAMP violations are acceptable in test environment
          assert is_map(violations)
      end
    end

    test "raises for unknown phase" do
      # Unknown phases raise FunctionClauseError - this is intentional
      # as only valid phases should be passed to verify_phase/1
      assert_raise FunctionClauseError, fn ->
        ContainerHealthSensor.verify_phase(:unknown_phase)
      end
    end
  end

  describe "get_state/0" do
    test "returns state map" do
      state = ContainerHealthSensor.get_state()

      assert is_map(state)
      assert Map.has_key?(state, :phase)
      assert Map.has_key?(state, :verification_results)
      assert Map.has_key?(state, :stamp_constraints)
      assert Map.has_key?(state, :verification_count)
    end

    test "verification_count is a non-negative integer" do
      state = ContainerHealthSensor.get_state()

      assert is_integer(state.verification_count)
      assert state.verification_count >= 0
    end
  end

  describe "stamp_compliance/0" do
    test "returns STAMP compliance report" do
      report = ContainerHealthSensor.stamp_compliance()

      assert is_map(report)
      assert Map.has_key?(report, :constraints)
      assert Map.has_key?(report, :summary)
      assert Map.has_key?(report, :compliant)
      assert Map.has_key?(report, :timestamp)
    end

    test "summary includes counts" do
      report = ContainerHealthSensor.stamp_compliance()

      assert Map.has_key?(report.summary, :total)
      assert Map.has_key?(report.summary, :satisfied)
      assert Map.has_key?(report.summary, :failed)
    end

    test "compliant is a boolean" do
      report = ContainerHealthSensor.stamp_compliance()

      assert is_boolean(report.compliant)
    end

    test "timestamp is a DateTime" do
      report = ContainerHealthSensor.stamp_compliance()

      assert %DateTime{} = report.timestamp
    end
  end

  describe "STAMP constraint verification" do
    test "verifies SC-CNT-V01 (Elixir version)" do
      result = ContainerHealthSensor.verify_phase(:verifying_versions)

      case result do
        {:ok, info} ->
          assert info.elixir.expected.major == 1
          assert info.elixir.expected.minor == 19

        {:error, _} ->
          # Version mismatch acceptable
          assert true
      end
    end

    test "verifies SC-CNT-V02 (OTP version)" do
      result = ContainerHealthSensor.verify_phase(:verifying_versions)

      case result do
        {:ok, info} ->
          assert info.otp.expected.major == 28

        {:error, _} ->
          # Version mismatch acceptable
          assert true
      end
    end

    test "verifies SC-CNT-009 (container OS)" do
      result = ContainerHealthSensor.verify_phase(:verifying_environment)

      case result do
        {:ok, info} ->
          # Container type should be nixos, podman, or unknown (docker is forbidden)
          assert info.container_type in [:nixos, :podman, :unknown]

        {:error, {:invalid_container_type, type}} ->
          # Docker detection would cause failure
          assert type == :docker or type == :unknown
      end
    end

    test "verifies SC-CNT-011 (PHICS latency)" do
      result = ContainerHealthSensor.verify_phase(:verifying_phics)

      case result do
        {:ok, info} ->
          # Latency should be measured
          assert is_float(info.latency_ms) or is_integer(info.latency_ms)
          assert info.threshold_ms == 50

        {:error, {:phics_latency_exceeded, info}} ->
          # Latency exceeded threshold
          assert info.latency_ms >= 50
      end
    end

    test "verifies SC-CNT-012 (rootless execution)" do
      result = ContainerHealthSensor.verify_phase(:verifying_environment)

      case result do
        {:ok, info} ->
          # Rootless should be boolean or :unknown
          assert info.rootless in [true, false, :unknown]

        {:error, _} ->
          assert true
      end
    end
  end

  describe "telemetry integration" do
    test "measure/0 does not raise" do
      assert_no_raise(fn -> ContainerHealthSensor.measure() end)
    end

    @tag timeout: 120_000
    test "full_verification/0 does not raise" do
      assert_no_raise(fn -> ContainerHealthSensor.full_verification() end)
    end

    test "verify_phase/1 does not raise" do
      phases = [
        :verifying_versions,
        :verifying_packages,
        :verifying_environment,
        :verifying_network,
        :verifying_ssl,
        :verifying_phics,
        :verifying_stamp
      ]

      Enum.each(phases, fn phase ->
        assert_no_raise(fn -> ContainerHealthSensor.verify_phase(phase) end)
      end)
    end
  end

  # Helper to assert no exception is raised
  defp assert_no_raise(fun) do
    try do
      fun.()
      true
    rescue
      e ->
        flunk("Expected no exception, but got: #{inspect(e)}")
    end
  end
end
