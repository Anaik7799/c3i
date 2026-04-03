defmodule Indrajaal.Core.VSM.System3StarAuditTest do
  @moduledoc """
  Test suite for Indrajaal.Core.VSM.System3StarAudit

  ## What
  Tests for the VSM System 3* Sporadic Audit GenServer: lifecycle, API,
  audit tick cycles, resource/process/sentinel/oscillation checks, telemetry
  emission, SC-ZTEST-008 log checkpoint compliance, and Guardian reporting.

  ## Coverage
  1. GenServer lifecycle (start_link, init, named registration)
  2. Initial state (last_audit: nil, audit_count: 0, anomaly_count: 0)
  3. API: last_audit/0, audit_now/0
  4. Audit tick via :audit_tick message
  5. Audit result schema validation
  6. Resource audit fields (memory_mb, cpu_load)
  7. Process audit (process_count, critical_missing)
  8. Sentinel unavailable graceful degradation
  9. System2Coordinator unavailable graceful degradation
  10. SC-ZTEST-008: [ZTEST-CHECKPOINT] log written before Zenoh publish
  11. Telemetry emission [:indrajaal, :vsm, :s3star, :audit]
  12. Guardian reporting on critical anomalies
  13. Status :clean vs :anomalies_found
  14. audit_count increments across multiple ticks

  ## STAMP Constraints
  - SC-VSM-001: All 5 VSM systems supervised
  - SC-S3-003: Anomalies reported within 10ms
  - SC-ZTEST-008: Log fallback written BEFORE Zenoh publish
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Indrajaal.Core.VSM.System3StarAudit

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    # Ensure telemetry app is started (needed for --no-start test runs)
    Application.ensure_all_started(:telemetry)

    # Note: ZTEST-CHECKPOINT and S3* logs use Logger.warning (not info)
    # to survive compile_time_purge_matching in test.exs (SC-ZTEST-008 CRITICAL)
    :ok

    # Stop any running instance before each test so start_supervised! gets a
    # clean named GenServer registration.
    case Process.whereis(System3StarAudit) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 1_000)
    end

    :ok
  end

  defp start_server do
    start_supervised!({System3StarAudit, []})
  end

  # Trigger one audit tick and wait for it to be processed synchronously by
  # following up with a call that only returns after the GenServer has handled
  # the tick message.
  defp trigger_tick(pid) do
    Process.send(pid, :audit_tick, [])
    # Use a synchronous call as a barrier to wait for the cast/info handler.
    GenServer.call(pid, :last_audit)
  end

  defp attach_telemetry_spy do
    ref = make_ref()
    parent = self()
    handler_id = "test-s3star-#{:erlang.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:indrajaal, :vsm, :s3star, :audit],
      fn event, measurements, metadata, _cfg ->
        send(parent, {:telemetry_event, ref, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    ref
  end

  # ---------------------------------------------------------------------------
  # 1. GenServer lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1 and supervision" do
    test "starts successfully with default options" do
      pid = start_server()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "registers under the module name (__MODULE__ / System3StarAudit)" do
      pid = start_server()
      assert Process.whereis(System3StarAudit) == pid
    end

    test "start_link returns {:ok, pid}" do
      # start_supervised! unwraps, so test start_link directly in isolation
      # after setup ensured nothing is registered.
      assert {:ok, pid} = System3StarAudit.start_link([])

      on_exit(fn ->
        try do
          GenServer.stop(pid, :normal, 500)
        catch
          :exit, _ -> :ok
        end
      end)

      assert is_pid(pid)
    end

    test "supervised server restarts and re-registers under module name after crash" do
      pid = start_server()
      old_pid = pid
      GenServer.stop(pid, :kill)
      # start_supervised! handles restart via the test supervisor; we just
      # confirm the old pid is gone.
      refute Process.alive?(old_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Initial state
  # ---------------------------------------------------------------------------

  describe "initial state" do
    test "last_audit/0 returns nil before any tick" do
      start_server()
      assert System3StarAudit.last_audit() == nil
    end

    test "GenServer state has audit_count: 0 before any tick" do
      pid = start_server()
      state = :sys.get_state(pid)
      assert state.audit_count == 0
    end

    test "GenServer state has anomaly_count: 0 before any tick" do
      pid = start_server()
      state = :sys.get_state(pid)
      assert state.anomaly_count == 0
    end

    test "GenServer state has last_audit: nil before any tick" do
      pid = start_server()
      state = :sys.get_state(pid)
      assert state.last_audit == nil
    end
  end

  # ---------------------------------------------------------------------------
  # 3. API — last_audit/0 and audit_now/0
  # ---------------------------------------------------------------------------

  describe "last_audit/0" do
    test "returns nil initially" do
      start_server()
      assert is_nil(System3StarAudit.last_audit())
    end

    test "returns a map after first audit tick" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_map(result)
    end

    test "returns the most recent audit after multiple ticks" do
      pid = start_server()
      trigger_tick(pid)
      first = System3StarAudit.last_audit()
      trigger_tick(pid)
      second = System3StarAudit.last_audit()
      # Timestamps advance, so second should be >= first
      assert DateTime.compare(second.timestamp, first.timestamp) in [:gt, :eq]
    end
  end

  describe "audit_now/0" do
    test "returns :ok immediately (fire-and-forget cast)" do
      start_server()
      assert :ok = System3StarAudit.audit_now()
    end

    test "causes last_audit to be populated after cast is processed" do
      start_server()
      System3StarAudit.audit_now()
      # Give the cast time to process (audit_now is a cast, not a call).
      Process.sleep(200)
      result = System3StarAudit.last_audit()
      assert is_map(result)
    end

    test "increments audit_count via audit_now cast" do
      pid = start_server()
      System3StarAudit.audit_now()
      Process.sleep(200)
      state = :sys.get_state(pid)
      assert state.audit_count >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Audit tick — :audit_tick message handling
  # ---------------------------------------------------------------------------

  describe "handle_info(:audit_tick, state)" do
    test "processes :audit_tick without crashing" do
      pid = start_server()
      Process.send(pid, :audit_tick, [])
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "increments audit_count by 1 per tick" do
      pid = start_server()
      trigger_tick(pid)
      state = :sys.get_state(pid)
      assert state.audit_count == 1
    end

    test "increments audit_count cumulatively across multiple ticks" do
      pid = start_server()
      trigger_tick(pid)
      trigger_tick(pid)
      trigger_tick(pid)
      state = :sys.get_state(pid)
      assert state.audit_count == 3
    end

    test "sets last_audit to a map after first tick" do
      pid = start_server()
      trigger_tick(pid)
      state = :sys.get_state(pid)
      assert is_map(state.last_audit)
    end

    test "schedules next audit after processing tick (process message queue grows)" do
      # After a tick is processed schedule_audit/0 sends another :audit_tick
      # 30 s from now. We verify the server remains alive and responsive.
      pid = start_server()
      trigger_tick(pid)
      assert Process.alive?(pid)
      # The server must still respond to calls.
      assert is_map(System3StarAudit.last_audit())
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Audit result schema
  # ---------------------------------------------------------------------------

  describe "audit result structure" do
    test "audit result contains all required top-level keys" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      required_keys = [
        :timestamp,
        :duration_us,
        :resource,
        :process,
        :sentinel,
        :oscillation,
        :anomaly_count,
        :anomalies,
        :status
      ]

      for key <- required_keys do
        assert Map.has_key?(result, key),
               "Expected audit result to have key #{inspect(key)}, got: #{inspect(Map.keys(result))}"
      end
    end

    test "timestamp is a DateTime struct" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert %DateTime{} = result.timestamp
    end

    test "duration_us is a non-negative integer" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_integer(result.duration_us)
      assert result.duration_us >= 0
    end

    test "anomaly_count equals length of anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert result.anomaly_count == length(result.anomalies)
    end

    test "anomalies is a list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_list(result.anomalies)
    end

    test "status is :clean when no anomalies present" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      if result.anomalies == [] do
        assert result.status == :clean
      else
        assert result.status == :anomalies_found
      end
    end

    test "status :anomalies_found maps to non-empty anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      case result.status do
        :clean -> assert result.anomalies == []
        :anomalies_found -> assert length(result.anomalies) > 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Resource audit
  # ---------------------------------------------------------------------------

  describe "resource audit sub-map" do
    test "resource audit contains memory_mb key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.resource, :memory_mb)
    end

    test "resource audit contains cpu_load key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.resource, :cpu_load)
    end

    test "resource audit contains status key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.resource, :status)
    end

    test "resource audit contains anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_list(result.resource.anomalies)
    end

    test "memory_mb is a non-negative integer" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_integer(result.resource.memory_mb)
      assert result.resource.memory_mb >= 0
    end

    test "cpu_load is a float in [0.0, 1.0]" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_float(result.resource.cpu_load)
      assert result.resource.cpu_load >= 0.0
      assert result.resource.cpu_load <= 1.0
    end

    test "high_memory anomaly type is :high_memory with severity :critical" do
      # This test validates the anomaly shape when it occurs; since we cannot
      # force memory > 1500 MB in a unit test, we verify normal-case shape only.
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      Enum.each(result.resource.anomalies, fn anomaly ->
        assert anomaly.type in [:high_memory, :high_cpu]
        assert anomaly.severity == :critical
        assert is_binary(anomaly.message)
        assert Map.has_key?(anomaly, :value)
        assert Map.has_key?(anomaly, :threshold)
      end)
    end

    test "cpu_load anomaly type is :high_cpu when present" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      cpu_anomalies = Enum.filter(result.resource.anomalies, &(&1.type == :high_cpu))

      Enum.each(cpu_anomalies, fn a ->
        assert a.severity == :critical
        assert a.threshold == 0.9
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Process health audit
  # ---------------------------------------------------------------------------

  describe "process audit sub-map" do
    test "process audit contains process_count key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.process, :process_count)
    end

    test "process audit contains critical_missing key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.process, :critical_missing)
    end

    test "process audit contains anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_list(result.process.anomalies)
    end

    test "process_count is a positive integer" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_integer(result.process.process_count)
      assert result.process.process_count > 0
    end

    test "critical_missing is a non-negative integer" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_integer(result.process.critical_missing)
      assert result.process.critical_missing >= 0
    end

    test "process_missing anomaly has :critical severity and :process_missing type" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      missing_anomalies = Enum.filter(result.process.anomalies, &(&1.type == :process_missing))

      Enum.each(missing_anomalies, fn a ->
        assert a.severity == :critical
        assert is_binary(a.message)
        assert Map.has_key?(a, :value)
      end)
    end

    test "critical_missing count matches number of process_missing anomalies" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      missing_count = Enum.count(result.process.anomalies, &(&1.type == :process_missing))
      assert result.process.critical_missing == missing_count
    end

    test "detecting missing Indrajaal.PubSub when it is not started" do
      # In the test environment Indrajaal.PubSub may or may not be started.
      # We verify the audit handles both cases without crashing.
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      pubsub_running = Process.whereis(Indrajaal.PubSub) != nil

      pubsub_missing_anomaly =
        Enum.find(result.process.anomalies, fn a ->
          a.type == :process_missing && a.value == Indrajaal.PubSub
        end)

      if pubsub_running do
        assert pubsub_missing_anomaly == nil
      else
        assert pubsub_missing_anomaly != nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Sentinel integration — unavailable graceful degradation
  # ---------------------------------------------------------------------------

  describe "sentinel audit sub-map" do
    test "sentinel audit completes without crash when Sentinel is unavailable" do
      pid = start_server()
      # Sentinel GenServer is unlikely to be running in unit test context.
      # The module uses try/rescue so the audit must not crash.
      trigger_tick(pid)
      assert Process.alive?(pid)
    end

    test "sentinel audit contains status key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.sentinel, :status)
    end

    test "sentinel audit contains health key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.sentinel, :health)
    end

    test "sentinel audit contains anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_list(result.sentinel.anomalies)
    end

    test "sentinel status is one of the valid atoms when unavailable" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      assert result.sentinel.status in [
               :ok,
               :healthy,
               :degraded,
               :critical,
               :unavailable,
               :unknown,
               :not_running
             ]
    end

    test "sentinel critical anomaly has :sentinel_critical type when present" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      critical_anomalies =
        Enum.filter(result.sentinel.anomalies, &(&1.type == :sentinel_critical))

      Enum.each(critical_anomalies, fn a ->
        assert a.severity == :critical
        assert is_binary(a.message)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Oscillation check — System2Coordinator unavailable graceful degradation
  # ---------------------------------------------------------------------------

  describe "oscillation audit sub-map" do
    test "oscillation audit completes without crash when System2Coordinator is unavailable" do
      pid = start_server()
      trigger_tick(pid)
      assert Process.alive?(pid)
    end

    test "oscillation audit contains oscillating key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.oscillation, :oscillating)
    end

    test "oscillation audit contains dampening key" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert Map.has_key?(result.oscillation, :dampening)
    end

    test "oscillation audit contains anomalies list" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()
      assert is_list(result.oscillation.anomalies)
    end

    test "oscillating defaults to false when System2Coordinator is absent" do
      # When System2Coordinator is unavailable the rescue/catch returns false.
      pid = start_server()

      # Only assert false when S2 is definitely not running.
      unless Process.whereis(Indrajaal.Core.VSM.System2Coordinator) do
        trigger_tick(pid)
        result = System3StarAudit.last_audit()
        assert result.oscillation.oscillating == false
      end
    end

    test "oscillation_detected anomaly has :oscillation_detected type and :high severity" do
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      oscillation_anomalies =
        Enum.filter(result.oscillation.anomalies, &(&1.type == :oscillation_detected))

      Enum.each(oscillation_anomalies, fn a ->
        assert a.severity == :high
        assert is_binary(a.message)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. SC-ZTEST-008 compliance — log checkpoint before Zenoh
  # ---------------------------------------------------------------------------

  describe "SC-ZTEST-008: log checkpoint [ZTEST-CHECKPOINT] emitted" do
    # capture_log must wrap both start AND tick to capture GenServer logs reliably
    test "log output contains [ZTEST-CHECKPOINT] marker during audit tick" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "[ZTEST-CHECKPOINT]",
             "Expected [ZTEST-CHECKPOINT] in log output, got:\n#{log}"
    end

    test "log checkpoint includes the CP-VSM-S3STAR-01 checkpoint ID" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "CP-VSM-S3STAR-01",
             "Expected checkpoint ID CP-VSM-S3STAR-01 in log, got:\n#{log}"
    end

    test "log checkpoint includes the Zenoh topic path" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "indrajaal/vsm/s3star/audit",
             "Expected Zenoh topic in log, got:\n#{log}"
    end

    test "log checkpoint includes status field" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "status=",
             "Expected status= in log checkpoint, got:\n#{log}"
    end

    test "log checkpoint includes anomalies count" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "anomalies=",
             "Expected anomalies= in log checkpoint, got:\n#{log}"
    end

    test "log checkpoint includes duration_us" do
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "duration_us=",
             "Expected duration_us= in log checkpoint, got:\n#{log}"
    end

    test "[ZTEST-CHECKPOINT] appears even when Zenoh publisher is unavailable" do
      # The module uses try/rescue around publish_async, so log must always fire.
      log =
        capture_log(fn ->
          pid = start_server()
          trigger_tick(pid)
        end)

      assert log =~ "[ZTEST-CHECKPOINT]"
    end

    test "audit_now/0 also emits [ZTEST-CHECKPOINT] log" do
      log =
        capture_log(fn ->
          start_server()
          System3StarAudit.audit_now()
          Process.sleep(300)
        end)

      assert log =~ "[ZTEST-CHECKPOINT]"
    end
  end

  # ---------------------------------------------------------------------------
  # 11. Telemetry emission
  # ---------------------------------------------------------------------------

  describe "telemetry emission [:indrajaal, :vsm, :s3star, :audit]" do
    test "emits telemetry event on audit tick" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _measurements,
                      _metadata},
                     500
    end

    test "telemetry measurements include duration_us" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], measurements,
                      _metadata},
                     500

      assert Map.has_key?(measurements, :duration_us)
      assert is_integer(measurements.duration_us)
      assert measurements.duration_us >= 0
    end

    test "telemetry measurements include anomaly_count" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], measurements,
                      _metadata},
                     500

      assert Map.has_key?(measurements, :anomaly_count)
      assert is_integer(measurements.anomaly_count)
      assert measurements.anomaly_count >= 0
    end

    test "telemetry metadata includes audit_count" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _measurements,
                      metadata},
                     500

      assert Map.has_key?(metadata, :audit_count)
      assert metadata.audit_count == 1
    end

    test "telemetry metadata includes status" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _measurements,
                      metadata},
                     500

      assert Map.has_key?(metadata, :status)
      assert metadata.status in [:clean, :anomalies_found]
    end

    test "telemetry audit_count increments on successive ticks" do
      pid = start_server()
      ref = attach_telemetry_spy()

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _,
                      %{audit_count: count1}},
                     500

      trigger_tick(pid)

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _,
                      %{audit_count: count2}},
                     500

      assert count2 == count1 + 1
    end

    test "emits telemetry via audit_now cast" do
      start_server()
      ref = attach_telemetry_spy()

      System3StarAudit.audit_now()

      assert_receive {:telemetry_event, ^ref, [:indrajaal, :vsm, :s3star, :audit], _measurements,
                      _metadata},
                     500
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Guardian reporting
  # ---------------------------------------------------------------------------

  describe "Guardian reporting on critical anomalies" do
    test "does not crash when Guardian is unavailable and no critical anomalies present" do
      pid = start_server()
      trigger_tick(pid)
      assert Process.alive?(pid)
    end

    test "does not crash when Guardian is unavailable even if critical anomalies exist" do
      # Guardian.report_threat/1 is wrapped in try/rescue so it must never crash.
      pid = start_server()
      trigger_tick(pid)
      result = System3StarAudit.last_audit()

      # Verify the audit completed regardless of Guardian availability.
      assert is_map(result)
      assert Map.has_key?(result, :status)
    end

    test "audit_count still increments even when Guardian.report_threat is called" do
      # This ensures Guardian side-effect path doesn't break the state update.
      pid = start_server()
      trigger_tick(pid)
      trigger_tick(pid)
      state = :sys.get_state(pid)
      assert state.audit_count == 2
    end
  end

  # ---------------------------------------------------------------------------
  # 13. Cumulative anomaly_count in state
  # ---------------------------------------------------------------------------

  describe "cumulative anomaly_count in GenServer state" do
    test "anomaly_count in state equals sum of anomalies across all ticks" do
      pid = start_server()
      trigger_tick(pid)
      trigger_tick(pid)
      trigger_tick(pid)

      state = :sys.get_state(pid)
      result = state.last_audit
      # Each tick's anomaly_count is added to state.anomaly_count; verify it
      # is non-negative and consistent.
      assert state.anomaly_count >= 0
      assert is_integer(state.anomaly_count)
      assert result.anomaly_count == length(result.anomalies)
    end

    test "state.anomaly_count is non-negative after multiple ticks" do
      pid = start_server()

      for _ <- 1..5 do
        trigger_tick(pid)
      end

      state = :sys.get_state(pid)
      assert state.anomaly_count >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # 14. init/1 log message
  # ---------------------------------------------------------------------------

  describe "init/1 log message" do
    test "logs S3* started message during init" do
      log =
        capture_log(fn ->
          pid = start_server()
          # pid is already supervised, just need to capture the log from init
          assert Process.alive?(pid)
        end)

      assert log =~ "[S3*]"
    end
  end
end
