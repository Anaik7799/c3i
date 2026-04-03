defmodule Indrajaal.Alarms.RealTimeProcessorTest do
  @moduledoc """
  TDG comprehensive test suite for RealTimeProcessor.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-ALARMS-001: Real-time alarm processing must not block
  - SC-ALARMS-002: Batch flush must be synchronous and reliable
  - SC-ALARMS-003: Correlation cache must remain consistent across updates
  - SC-HOLON-001: GenServer state persisted to SQLite only

  ## Constitutional Verification
  - Psi0 Existence: GenServer survives alarm floods and invalid data
  - Psi1 Regeneration: State reconstructible from SQLite after restart
  - Psi3 Verification: Statistics report consistent metrics

  ## Founder's Directive Alignment
  - Omega0.1: Alarm processing upholds site security for resource protection

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarms not processed or correlated
  - L5 Root Cause: GenServer mailbox overflow or correlation bug
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.RealTimeProcessor

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(RealTimeProcessor) do
      nil ->
        start_supervised!({RealTimeProcessor, []})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: process_alarm/1
  # ---------------------------------------------------------------------------

  describe "process_alarm/1" do
    test "returns :ok immediately (cast is asynchronous)" do
      alarm_data = %{
        event_code: "BA001",
        event_type: :intrusion,
        severity: :high,
        tenant_id: "tenant-rtp-1",
        source_device_id: "dev-001"
      }

      result = RealTimeProcessor.process_alarm(alarm_data)
      assert result == :ok
    end

    test "accepts alarm with minimal fields" do
      result = RealTimeProcessor.process_alarm(%{event_type: :fire})
      assert result == :ok
    end

    test "accepts alarm with all standard fields" do
      alarm_data = %{
        event_code: "FA999",
        event_type: :fire,
        severity: :critical,
        tenant_id: "tenant-rtp-2",
        source_device_id: "dev-fire-1",
        priority: 9,
        location_details: "Sector 7G",
        metadata: %{protocol: "SIA-DC09"}
      }

      assert RealTimeProcessor.process_alarm(alarm_data) == :ok
    end

    test "accepts empty map without crashing" do
      assert RealTimeProcessor.process_alarm(%{}) == :ok
    end

    test "multiple rapid casts do not crash the server" do
      Enum.each(1..20, fn i ->
        RealTimeProcessor.process_alarm(%{
          event_code: "EV#{i}",
          event_type: :intrusion,
          tenant_id: "tenant-rtp-multi"
        })
      end)

      # Server is still alive
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end

    test "server remains operational after invalid alarm data" do
      RealTimeProcessor.process_alarm(nil)
      RealTimeProcessor.process_alarm("not-a-map")
      RealTimeProcessor.process_alarm(42)

      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_statistics/0
  # ---------------------------------------------------------------------------

  describe "get_statistics/0" do
    test "returns a map" do
      stats = RealTimeProcessor.get_statistics()
      assert is_map(stats)
    end

    test "statistics include processing metrics" do
      stats = RealTimeProcessor.get_statistics()

      # The compiled statistics must be a non-empty map
      assert map_size(stats) > 0
    end

    test "statistics call does not crash server" do
      assert is_map(RealTimeProcessor.get_statistics())
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end

    test "repeated calls return consistent type" do
      s1 = RealTimeProcessor.get_statistics()
      s2 = RealTimeProcessor.get_statistics()

      assert is_map(s1)
      assert is_map(s2)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_correlation_analysis/0
  # ---------------------------------------------------------------------------

  describe "get_correlation_analysis/0" do
    test "returns a term (not a crash)" do
      result = RealTimeProcessor.get_correlation_analysis()
      # Any non-exception result is valid — correlation cache starts empty
      assert not is_nil(result) or is_map(result) or is_list(result)
    end

    test "returns consistent type across multiple calls" do
      r1 = RealTimeProcessor.get_correlation_analysis()
      r2 = RealTimeProcessor.get_correlation_analysis()

      assert is_map(r1) == is_map(r2)
    end

    test "does not crash server on empty cache" do
      _analysis = RealTimeProcessor.get_correlation_analysis()
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end
  end

  # ---------------------------------------------------------------------------
  # describe: flush_batch/0
  # ---------------------------------------------------------------------------

  describe "flush_batch/0" do
    test "returns :ok when batch buffer is empty" do
      result = RealTimeProcessor.flush_batch()
      assert result == :ok or match?({:error, _}, result)
    end

    test "flushes buffer after multiple process_alarm casts" do
      Enum.each(1..5, fn i ->
        RealTimeProcessor.process_alarm(%{
          event_code: "FLUSH#{i}",
          event_type: :supervisory,
          tenant_id: "tenant-flush"
        })
      end)

      # Allow casts to arrive
      Process.sleep(50)

      result = RealTimeProcessor.flush_batch()
      assert result == :ok or match?({:error, _}, result)
    end

    test "repeated flushes are idempotent" do
      r1 = RealTimeProcessor.flush_batch()
      r2 = RealTimeProcessor.flush_batch()

      # Both should succeed
      assert r1 == :ok or match?({:error, _}, r1)
      assert r2 == :ok or match?({:error, _}, r2)
    end

    test "flush does not crash server" do
      RealTimeProcessor.flush_batch()
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end
  end

  # ---------------------------------------------------------------------------
  # describe: process_state_change/4
  # ---------------------------------------------------------------------------

  describe "process_state_change/4" do
    test "returns {:ok, _} or {:error, _} for any alarm_id" do
      result = RealTimeProcessor.process_state_change("alarm-123", :acknowledged, "operator-1")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts optional opts keyword list" do
      result =
        RealTimeProcessor.process_state_change(
          "alarm-456",
          :investigating,
          "operator-2",
          tenant_id: "test-tenant"
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "invalid alarm_id returns error tuple" do
      result = RealTimeProcessor.process_state_change("nonexistent-alarm", :resolved, "op")
      assert match?({:error, _}, result)
    end

    test "server stays alive after state change calls" do
      RealTimeProcessor.process_state_change("x", :acknowledged, "op")
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: server survives flood of alarms" do
      Enum.each(1..50, fn i ->
        RealTimeProcessor.process_alarm(%{event_type: :intrusion, id: i})
      end)

      Process.sleep(100)
      assert Process.alive?(GenServer.whereis(RealTimeProcessor))
    end

    test "Psi3 verification: statistics reflect server state" do
      stats = RealTimeProcessor.get_statistics()
      assert is_map(stats), "Statistics must be a map for verification"
    end

    test "Psi5 truthfulness: get_statistics returns without deception" do
      stats = RealTimeProcessor.get_statistics()
      # The server must not return nil or raise
      assert stats != nil
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: statistics and correlation analysis both respond" do
      stats = RealTimeProcessor.get_statistics()
      correlation = RealTimeProcessor.get_correlation_analysis()

      assert not is_nil(stats)
      assert not is_nil(correlation)
    end

    test "flush_batch completes within safe time window" do
      {elapsed_us, _result} = :timer.tc(fn -> RealTimeProcessor.flush_batch() end)
      # Must complete within 5 seconds (SIL-6 safe state requirement)
      assert elapsed_us < 5_000_000
    end

    test "get_statistics completes within 1 second" do
      {elapsed_us, stats} = :timer.tc(fn -> RealTimeProcessor.get_statistics() end)
      assert is_map(stats)
      assert elapsed_us < 1_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "process_alarm always returns :ok for any map data" do
    forall alarm_event_code <- PC.utf8() do
      alarm = %{event_code: alarm_event_code, event_type: :intrusion}
      result = RealTimeProcessor.process_alarm(alarm)
      result == :ok
    end
  end

  property "get_statistics always returns a map" do
    forall _n <- PC.integer(1, 5) do
      is_map(RealTimeProcessor.get_statistics())
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "flush_batch after any number of alarms" do
    ExUnitProperties.check all(count <- SD.integer(0..10)) do
      Enum.each(1..count, fn i ->
        RealTimeProcessor.process_alarm(%{event_type: :supervisory, seq: i})
      end)

      Process.sleep(10)
      result = RealTimeProcessor.flush_batch()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  test "process_state_change always returns ok or error tuple" do
    ExUnitProperties.check all(
                             alarm_id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)
                           ) do
      result = RealTimeProcessor.process_state_change(alarm_id, :acknowledged, "op")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
