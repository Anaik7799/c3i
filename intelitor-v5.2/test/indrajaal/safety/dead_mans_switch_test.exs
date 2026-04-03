defmodule Indrajaal.Safety.DeadMansSwitchTest do
  @moduledoc """
  Tests for the Dead Man's Switch module.

  WHAT: Validates heartbeat system and failsafe triggering.
  WHY: SC-DMS-001 to SC-DMS-004 require deterministic failsafe behavior.
  CONSTRAINTS: Must verify heartbeat timing and failsafe engagement.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Safety.DeadMansSwitch

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure DMS is not running before tests
    case GenServer.whereis(DeadMansSwitch) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    on_exit(fn ->
      case GenServer.whereis(DeadMansSwitch) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end
    end)

    :ok
  end

  # ============================================================
  # STATE TESTS
  # ============================================================

  describe "state/0 when not running" do
    test "returns :disabled" do
      assert DeadMansSwitch.state() == :disabled
    end
  end

  describe "stats/0 when not running" do
    test "returns default stats" do
      stats = DeadMansSwitch.stats()

      assert stats.state == :disabled
      assert stats.heartbeats_received == 0
      assert stats.heartbeats_missed == 0
      assert stats.failsafe_triggers == 0
      assert stats.last_heartbeat == nil
      assert stats.uptime_seconds == 0
    end
  end

  # ============================================================
  # START/STOP TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts with auto_arm: true by default" do
      {:ok, pid} = DeadMansSwitch.start_link()

      assert is_pid(pid)
      assert DeadMansSwitch.state() == :armed

      GenServer.stop(pid)
    end

    test "starts with auto_arm: false when specified" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      assert is_pid(pid)
      assert DeadMansSwitch.state() == :disabled

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # HEARTBEAT TESTS
  # ============================================================

  describe "heartbeat/1" do
    test "when not running returns error" do
      assert {:error, :not_running} = DeadMansSwitch.heartbeat()
    end

    test "when running returns ok with sequence number" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      assert {:ok, 1} = DeadMansSwitch.heartbeat(:cortex)
      assert {:ok, 2} = DeadMansSwitch.heartbeat(:cortex)
      assert {:ok, 3} = DeadMansSwitch.heartbeat(:synapse)

      GenServer.stop(pid)
    end

    test "updates state to healthy" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      assert {:ok, _seq} = DeadMansSwitch.heartbeat(:cortex)
      assert DeadMansSwitch.state() == :healthy

      GenServer.stop(pid)
    end

    test "updates stats correctly" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      assert {:ok, _} = DeadMansSwitch.heartbeat(:cortex)
      assert {:ok, _} = DeadMansSwitch.heartbeat(:cortex)
      assert {:ok, _} = DeadMansSwitch.heartbeat(:cortex)

      stats = DeadMansSwitch.stats()
      assert stats.heartbeats_received == 3
      assert stats.current_sequence == 3

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # ARM/DISARM TESTS
  # ============================================================

  describe "arm/0" do
    test "arms the switch" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      assert DeadMansSwitch.state() == :disabled
      assert :ok = DeadMansSwitch.arm()
      assert DeadMansSwitch.state() == :armed

      GenServer.stop(pid)
    end
  end

  describe "disarm/1" do
    test "with correct confirmation disarms the switch" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      assert DeadMansSwitch.state() == :armed
      assert :ok = DeadMansSwitch.disarm("I_UNDERSTAND_THIS_DISABLES_SAFETY")
      assert DeadMansSwitch.state() == :disabled

      GenServer.stop(pid)
    end

    test "with incorrect confirmation returns error" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      assert {:error, :invalid_confirmation} = DeadMansSwitch.disarm("wrong")
      assert DeadMansSwitch.state() == :armed

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # FAILSAFE TESTS
  # ============================================================

  describe "trigger_failsafe/1" do
    test "manually triggers failsafe" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      DeadMansSwitch.trigger_failsafe(:manual_test)
      # Give time for async cast to process
      Process.sleep(50)

      assert DeadMansSwitch.state() == :failsafe_triggered

      stats = DeadMansSwitch.stats()
      assert stats.failsafe_triggers == 1

      GenServer.stop(pid)
    end
  end

  describe "attempt_recovery/0" do
    test "when not in failsafe returns error" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      assert {:error, :not_in_failsafe} = DeadMansSwitch.attempt_recovery()

      GenServer.stop(pid)
    end

    test "when in failsafe attempts recovery" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      DeadMansSwitch.trigger_failsafe(:test)
      Process.sleep(50)

      assert DeadMansSwitch.state() == :failsafe_triggered

      # Recovery should succeed since Envelope health check returns healthy by default
      result = DeadMansSwitch.attempt_recovery()
      assert {:ok, :recovered} = result
      assert DeadMansSwitch.state() == :armed

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # HEARTBEAT VERIFICATION TESTS
  # ============================================================

  describe "verify_heartbeat/1" do
    test "verifies valid heartbeat" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      # First send a heartbeat to get a valid sequence
      assert {:ok, seq} = DeadMansSwitch.heartbeat(:cortex)

      # Now verify a heartbeat with correct parameters
      now = System.monotonic_time(:millisecond)

      heartbeat = %{
        sequence: seq + 1,
        timestamp: now,
        source: :cortex,
        signature: generate_test_signature(seq + 1, now, :cortex)
      }

      result = DeadMansSwitch.verify_heartbeat(heartbeat)
      assert {:ok, :verified} = result

      GenServer.stop(pid)
    end

    test "rejects stale sequence" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      # Send multiple heartbeats
      {:ok, _} = DeadMansSwitch.heartbeat(:cortex)
      {:ok, _} = DeadMansSwitch.heartbeat(:cortex)
      {:ok, _} = DeadMansSwitch.heartbeat(:cortex)

      # Try to verify with old sequence
      now = System.monotonic_time(:millisecond)

      heartbeat = %{
        sequence: 1,
        timestamp: now,
        source: :cortex,
        signature: generate_test_signature(1, now, :cortex)
      }

      result = DeadMansSwitch.verify_heartbeat(heartbeat)
      assert {:error, :stale_sequence} = result

      GenServer.stop(pid)
    end

    test "rejects invalid signature" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: false)

      {:ok, seq} = DeadMansSwitch.heartbeat(:cortex)
      now = System.monotonic_time(:millisecond)

      heartbeat = %{
        sequence: seq + 1,
        timestamp: now,
        source: :cortex,
        signature: <<1, 2, 3, 4>>
      }

      result = DeadMansSwitch.verify_heartbeat(heartbeat)
      assert {:error, :invalid_signature} = result

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # AUTOMATIC FAILSAFE TESTS
  # ============================================================

  describe "automatic failsafe on missed heartbeats" do
    @tag :slow
    test "triggers failsafe after max missed heartbeats" do
      # Start with auto_arm
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      # Send one heartbeat to establish baseline
      {:ok, _} = DeadMansSwitch.heartbeat(:cortex)

      # Wait for multiple heartbeat timeouts (150ms * 3 = 450ms + margin)
      Process.sleep(600)

      # Should now be in warning or failsafe_triggered state
      state = DeadMansSwitch.state()
      assert state in [:warning, :failsafe_triggered]

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0 when running" do
    test "returns complete stats" do
      {:ok, pid} = DeadMansSwitch.start_link(auto_arm: true)

      # Send some heartbeats
      {:ok, _} = DeadMansSwitch.heartbeat(:cortex)
      {:ok, _} = DeadMansSwitch.heartbeat(:synapse)

      stats = DeadMansSwitch.stats()

      assert stats.state == :healthy
      assert stats.heartbeats_received == 2
      assert stats.current_sequence == 2
      assert stats.last_heartbeat != nil
      assert stats.uptime_seconds >= 0

      GenServer.stop(pid)
    end
  end

  # ============================================================
  # HELPERS
  # ============================================================

  # Generate test signature matching DMS internal format
  defp generate_test_signature(sequence, timestamp, source) do
    # Use the same secret format as DMS
    secret = "indrajaal_dms_secret_test"
    data = "#{sequence}:#{timestamp}:#{source}"
    :crypto.mac(:hmac, :sha256, secret, data)
  end
end
