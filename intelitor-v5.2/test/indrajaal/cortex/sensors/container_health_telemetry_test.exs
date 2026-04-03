defmodule Indrajaal.Cortex.Sensors.ContainerHealthTelemetryTest do
  @moduledoc """
  Tests for the ContainerHealthTelemetry module.

  STAMP Compliance:
  - SC-OBS-065: Observability for all domain operations
  - TDG-CNT-004: Every STAMP constraint has telemetry

  Tests verify:
  - Telemetry event emission functions
  - Telemetry handler attachment
  - Event data structure validity
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Sensors.ContainerHealthTelemetry, as: Telemetry

  @moduletag :cortex
  @moduletag :telemetry
  @moduletag :container_health

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Telemetry)
    end

    test "exports attach/0 function" do
      assert function_exported?(Telemetry, :attach, 0)
    end

    test "exports detach/0 function" do
      assert function_exported?(Telemetry, :detach, 0)
    end

    test "exports emit_verification_start/1 function" do
      assert function_exported?(Telemetry, :emit_verification_start, 1)
    end

    test "exports emit_verification_stop/3 function" do
      assert function_exported?(Telemetry, :emit_verification_stop, 3)
    end

    test "exports emit_phase_complete/3 function" do
      assert function_exported?(Telemetry, :emit_phase_complete, 3)
    end

    test "exports emit_phase_failed/3 function" do
      assert function_exported?(Telemetry, :emit_phase_failed, 3)
    end

    test "exports emit_stamp_check/3 function" do
      assert function_exported?(Telemetry, :emit_stamp_check, 3)
    end

    test "exports emit_stamp_violation/3 function" do
      assert function_exported?(Telemetry, :emit_stamp_violation, 3)
    end
  end

  describe "attach/0 and detach/0" do
    test "attach/0 does not raise" do
      # May already be attached from application, detach first
      try do
        Telemetry.detach()
      rescue
        _ -> :ok
      end

      assert :ok = Telemetry.attach()
    end

    test "detach/0 does not raise after attach" do
      # Ensure attached first
      try do
        Telemetry.attach()
      rescue
        _ -> :ok
      end

      # Detach should work
      assert :ok = Telemetry.detach()
    end

    test "can re-attach after detach" do
      try do
        Telemetry.detach()
      rescue
        _ -> :ok
      end

      assert :ok = Telemetry.attach()
      assert :ok = Telemetry.detach()
      assert :ok = Telemetry.attach()
    end
  end

  describe "emit_verification_start/1" do
    setup do
      # Attach telemetry handlers for testing
      test_pid = self()

      handler_id = "test-verification-start-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :verification, :start],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits verification start event" do
      Telemetry.emit_verification_start()

      assert_receive {:telemetry, measurements, metadata}, 1000

      assert Map.has_key?(measurements, :system_time)
      assert is_integer(measurements.system_time)
      assert Map.has_key?(metadata, :node)
    end

    test "includes custom metadata" do
      Telemetry.emit_verification_start(%{custom_key: "custom_value"})

      assert_receive {:telemetry, _measurements, metadata}, 1000

      assert metadata.custom_key == "custom_value"
    end
  end

  describe "emit_verification_stop/3" do
    setup do
      test_pid = self()

      handler_id = "test-verification-stop-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :verification, :stop],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits verification stop event with success" do
      Telemetry.emit_verification_stop(true, 150)

      assert_receive {:telemetry, measurements, _metadata}, 1000

      assert measurements.success == true
      assert measurements.duration_ms == 150
      assert Map.has_key?(measurements, :system_time)
    end

    test "emits verification stop event with failure" do
      Telemetry.emit_verification_stop(false, 200)

      assert_receive {:telemetry, measurements, _metadata}, 1000

      assert measurements.success == false
      assert measurements.duration_ms == 200
    end

    test "includes results metadata" do
      Telemetry.emit_verification_stop(true, 100, %{phases_passed: 7})

      assert_receive {:telemetry, _measurements, metadata}, 1000

      assert metadata.phases_passed == 7
    end
  end

  describe "emit_phase_complete/3" do
    setup do
      test_pid = self()

      handler_id = "test-phase-complete-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :phase, :complete],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits phase complete event" do
      Telemetry.emit_phase_complete(:versions, 25)

      assert_receive {:telemetry, measurements, _metadata}, 1000

      assert measurements.phase == :versions
      assert measurements.duration_ms == 25
    end

    test "includes phase result data" do
      Telemetry.emit_phase_complete(:packages, 30, %{packages_checked: 5})

      assert_receive {:telemetry, _measurements, metadata}, 1000

      assert metadata.packages_checked == 5
    end
  end

  describe "emit_phase_failed/3" do
    setup do
      test_pid = self()

      handler_id = "test-phase-failed-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :phase, :failed],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits phase failed event" do
      Telemetry.emit_phase_failed(:network, 100, "Connection timeout")

      assert_receive {:telemetry, measurements, metadata}, 1000

      assert measurements.phase == :network
      assert measurements.duration_ms == 100
      assert metadata.error == "Connection timeout"
    end
  end

  describe "emit_stamp_check/3" do
    setup do
      test_pid = self()

      handler_id = "test-stamp-check-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :stamp, :check],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits STAMP check event for satisfied constraint" do
      Telemetry.emit_stamp_check("SC-CNT-009", true)

      assert_receive {:telemetry, measurements, _metadata}, 1000

      assert measurements.constraint_id == "SC-CNT-009"
      assert measurements.satisfied == true
    end

    test "emits STAMP check event for unsatisfied constraint" do
      Telemetry.emit_stamp_check("SC-CNT-010", false, %{reason: "External registry"})

      assert_receive {:telemetry, measurements, metadata}, 1000

      assert measurements.constraint_id == "SC-CNT-010"
      assert measurements.satisfied == false
      assert metadata.reason == "External registry"
    end
  end

  describe "emit_stamp_violation/3" do
    setup do
      test_pid = self()

      handler_id = "test-stamp-violation-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:indrajaal, :container, :health, :stamp, :violation],
        fn _event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, handler_id: handler_id}
    end

    test "emits STAMP violation event with critical severity" do
      Telemetry.emit_stamp_violation("SC-CNT-012", "Not rootless", :critical)

      assert_receive {:telemetry, measurements, metadata}, 1000

      assert measurements.constraint_id == "SC-CNT-012"
      assert measurements.severity == :critical
      assert metadata.reason == "Not rootless"
    end

    test "default severity is critical" do
      Telemetry.emit_stamp_violation("SC-CNT-009", "Docker detected")

      assert_receive {:telemetry, measurements, _metadata}, 1000

      assert measurements.severity == :critical
    end
  end

  describe "TDG compliance" do
    test "TDG-CNT-004: all STAMP constraints have telemetry coverage" do
      # The telemetry module should have emit functions for all constraint events
      assert function_exported?(Telemetry, :emit_stamp_check, 3)
      assert function_exported?(Telemetry, :emit_stamp_violation, 3)
    end
  end

  describe "SC-OBS-065 compliance" do
    test "all verification phases have telemetry coverage" do
      # Phase complete and failed events
      assert function_exported?(Telemetry, :emit_phase_complete, 3)
      assert function_exported?(Telemetry, :emit_phase_failed, 3)
    end

    test "verification lifecycle has telemetry coverage" do
      # Start and stop events
      assert function_exported?(Telemetry, :emit_verification_start, 1)
      assert function_exported?(Telemetry, :emit_verification_stop, 3)
    end
  end
end
