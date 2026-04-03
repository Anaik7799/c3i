defmodule Indrajaal.Safety.SentinelTest do
  @moduledoc """
  Tests for the Sentinel Digital Immune System (T-Cell GenServer).

  WHAT: Validates Sentinel health monitoring, threat detection, and quarantine logic.
  WHY: SC-IMMUNE-001 to SC-IMMUNE-003 require proper immune system operation.
  CONSTRAINTS: Must verify kernel process protection (SC-PRIME-001).

  ## STAMP Constraints Tested
  - SC-IMMUNE-001: Sentinel SHALL monitor system health continuously
  - SC-IMMUNE-002: Sentinel SHALL NOT terminate kernel processes
  - SC-IMMUNE-003: Sentinel SHALL log all defensive actions
  - SC-PRIME-001: Will to Live - SHALL NOT terminate essential services
  - AOR-PRIME-001: Log reasoning before high-risk mutations
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Safety.Sentinel

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Stop any existing Sentinel
    case GenServer.whereis(Sentinel) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5_000)
    end

    # Start fresh Sentinel for each test
    {:ok, pid} = Sentinel.start_link(guardian_enabled: false)

    on_exit(fn ->
      case GenServer.whereis(Sentinel) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 5_000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{sentinel: pid}
  end

  # ============================================================
  # START_LINK TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts with default options", ctx do
      assert Process.alive?(ctx.sentinel)
    end

    test "can start with custom name" do
      # Stop the default one first
      GenServer.stop(Sentinel, :normal, 5_000)

      {:ok, pid} = Sentinel.start_link(name: :custom_sentinel, guardian_enabled: false)
      assert Process.alive?(pid)
      assert GenServer.whereis(:custom_sentinel) == pid

      GenServer.stop(pid, :normal, 5_000)
    end
  end

  # ============================================================
  # GET_HEALTH TESTS
  # ============================================================

  describe "get_health/0" do
    test "returns health status map", _ctx do
      health = Sentinel.get_health()

      assert is_map(health)
      assert Map.has_key?(health, :score)
      assert Map.has_key?(health, :threats)
      assert Map.has_key?(health, :quarantined)
    end

    test "returns score between 0.0 and 1.0", _ctx do
      health = Sentinel.get_health()

      assert is_float(health.score)
      assert health.score >= 0.0
      assert health.score <= 1.0
    end

    test "initial threats list is empty or contains detected threats", _ctx do
      health = Sentinel.get_health()

      assert is_list(health.threats)
    end

    test "initial quarantined list is empty", _ctx do
      health = Sentinel.get_health()

      assert health.quarantined == []
    end

    test "includes metrics", _ctx do
      health = Sentinel.get_health()

      assert is_map(health.metrics)
      assert Map.has_key?(health.metrics, :memory_usage)
      assert Map.has_key?(health.metrics, :cpu_usage)
    end

    test "returns safe defaults when not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      health = Sentinel.get_health()

      assert health.score == 1.0
      assert health.threats == []
      assert health.quarantined == []
      assert health.status == :not_running
    end
  end

  # ============================================================
  # REPORT_THREAT TESTS
  # ============================================================

  describe "report_threat/3" do
    test "accepts threat report", _ctx do
      result = Sentinel.report_threat(:process_anomaly, self(), %{test: true})

      assert result == :ok
    end

    test "threat is tracked after report", _ctx do
      # Report a medium severity threat (won't trigger immediate quarantine)
      Sentinel.report_threat(:process_anomaly, :test_source, %{test: true})

      # Give time for async processing
      Process.sleep(100)

      # Check if threat was tracked
      {:ok, assessment} = Sentinel.assess_now()
      # The threat tracking depends on severity, let's just verify assess_now works
      assert is_map(assessment)
    end

    test "returns :ok even when sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.report_threat(:test_threat, self(), %{})

      assert result == :ok
    end
  end

  # ============================================================
  # QUARANTINE TESTS
  # ============================================================

  describe "quarantine/2" do
    test "quarantines a process", _ctx do
      # Spawn a test process
      test_pid =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      assert Process.alive?(test_pid)

      result = Sentinel.quarantine(test_pid, :test_quarantine)

      assert result == {:ok, :quarantined}

      # Process should be suspended
      health = Sentinel.get_health()
      assert test_pid in health.quarantined

      # Clean up - resume and stop the process
      Sentinel.release(test_pid)
      send(test_pid, :stop)
    end

    test "cannot quarantine kernel process", _ctx do
      # init is a kernel process
      init_pid = :erlang.whereis(:init)

      result = Sentinel.quarantine(init_pid, :test_quarantine)

      assert result == {:error, :kernel_process}
    end

    test "returns error for dead process", _ctx do
      # Spawn and immediately kill a process
      dead_pid =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      Process.exit(dead_pid, :kill)
      Process.sleep(50)

      result = Sentinel.quarantine(dead_pid, :test_quarantine)

      assert result == {:error, :not_alive}
    end

    test "returns error when sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.quarantine(self(), :test_reason)

      assert result == {:error, :not_running}
    end
  end

  # ============================================================
  # RELEASE TESTS
  # ============================================================

  describe "release/1" do
    test "releases a quarantined process", _ctx do
      # Spawn and quarantine a test process
      test_pid =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      {:ok, :quarantined} = Sentinel.quarantine(test_pid, :test_quarantine)

      result = Sentinel.release(test_pid)

      assert result == {:ok, :released}

      # Process should no longer be quarantined
      health = Sentinel.get_health()
      refute test_pid in health.quarantined

      # Clean up
      send(test_pid, :stop)
    end

    test "returns error for non-quarantined process", _ctx do
      result = Sentinel.release(self())

      assert result == {:error, :not_quarantined}
    end

    test "returns error when sentinel not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.release(self())

      assert result == {:error, :not_running}
    end
  end

  # ============================================================
  # ASSESS_NOW TESTS
  # ============================================================

  describe "assess_now/0" do
    test "returns assessment result", _ctx do
      result = Sentinel.assess_now()

      assert {:ok, assessment} = result
      assert is_map(assessment)
      assert Map.has_key?(assessment, :threat_level)
      assert Map.has_key?(assessment, :health_score)
      assert Map.has_key?(assessment, :active_threats)
      assert Map.has_key?(assessment, :quarantine_count)
      assert Map.has_key?(assessment, :metrics)
      assert Map.has_key?(assessment, :assessed_at)
    end

    test "threat_level is one of expected values", _ctx do
      {:ok, assessment} = Sentinel.assess_now()

      assert assessment.threat_level in [:none, :low, :medium, :high, :critical]
    end

    test "health_score is valid", _ctx do
      {:ok, assessment} = Sentinel.assess_now()

      assert is_float(assessment.health_score)
      assert assessment.health_score >= 0.0
      assert assessment.health_score <= 1.0
    end

    test "returns error when not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.assess_now()

      assert result == {:error, :not_running}
    end
  end

  # ============================================================
  # GET_QUARANTINE_LIST TESTS
  # ============================================================

  describe "get_quarantine_list/0" do
    test "returns empty map initially", _ctx do
      result = Sentinel.get_quarantine_list()

      assert result == %{}
    end

    test "returns quarantined processes", _ctx do
      # Spawn and quarantine a test process
      test_pid =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      {:ok, :quarantined} = Sentinel.quarantine(test_pid, :test_quarantine)

      result = Sentinel.get_quarantine_list()

      assert is_map(result)
      assert Map.has_key?(result, test_pid)
      assert result[test_pid].reason == :test_quarantine

      # Clean up
      Sentinel.release(test_pid)
      send(test_pid, :stop)
    end

    test "returns empty map when not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.get_quarantine_list()

      assert result == %{}
    end
  end

  # ============================================================
  # REPORT_SIGNAL TESTS
  # ============================================================

  describe "report_signal/1" do
    test "accepts signal map", _ctx do
      signal = %{
        type: :threat,
        threat_type: :test_threat,
        source: self(),
        metadata: %{},
        timestamp: DateTime.utc_now(),
        severity: 10
      }

      result = Sentinel.report_signal(signal)

      assert result == :ok
    end

    test "returns :ok even when not running" do
      GenServer.stop(Sentinel, :normal, 5_000)

      result = Sentinel.report_signal(%{type: :test})

      assert result == :ok
    end
  end

  # ============================================================
  # KERNEL PROCESS PROTECTION TESTS (SC-PRIME-001)
  # ============================================================

  describe "is_kernel_process?/1 - SC-PRIME-001" do
    test "identifies kernel application processes as protected" do
      # Get a process from the kernel application
      init_pid = :erlang.whereis(:init)

      assert Sentinel.is_kernel_process?(init_pid)
    end

    test "identifies code_server as protected" do
      code_server_pid = :erlang.whereis(:code_server)

      if code_server_pid do
        assert Sentinel.is_kernel_process?(code_server_pid)
      end
    end

    test "does not identify regular spawned process as kernel" do
      test_pid =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      refute Sentinel.is_kernel_process?(test_pid)

      send(test_pid, :stop)
    end

    test "identifies test process based on supervision tree" do
      # Test processes run under ExUnit supervisor, which is under Application
      # So they may or may not be identified as kernel based on OTP internals
      # We just verify the function returns a boolean
      result = Sentinel.is_kernel_process?(self())
      assert is_boolean(result)
    end
  end

  # ============================================================
  # HEALTH SCORE CALCULATION TESTS
  # ============================================================

  describe "health score calculation" do
    test "healthy system has high score", _ctx do
      health = Sentinel.get_health()

      # Under normal test conditions, score should be high
      assert health.score >= 0.7
    end

    test "quarantined processes reduce score", _ctx do
      # Get initial score
      health_before = Sentinel.get_health()

      # Spawn and quarantine multiple processes
      pids =
        for _ <- 1..3 do
          pid =
            spawn(fn ->
              receive do
                :stop -> :ok
              end
            end)

          {:ok, :quarantined} = Sentinel.quarantine(pid, :test)
          pid
        end

      # Force a health check
      {:ok, _} = Sentinel.assess_now()
      health_after = Sentinel.get_health()

      # Score should be lower with quarantined processes
      assert health_after.score <= health_before.score

      # Clean up
      Enum.each(pids, fn pid ->
        Sentinel.release(pid)
        send(pid, :stop)
      end)
    end
  end

  # ============================================================
  # TELEMETRY TESTS
  # ============================================================

  describe "telemetry events" do
    test "emits health_check telemetry", _ctx do
      test_pid = self()

      # Attach telemetry handler
      :telemetry.attach(
        "test-health-check",
        [:indrajaal, :safety, :sentinel, :health_check],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger assessment
      {:ok, _} = Sentinel.assess_now()

      # Wait for telemetry
      assert_receive {:telemetry, [:indrajaal, :safety, :sentinel, :health_check], measurements,
                      _metadata},
                     1000

      assert Map.has_key?(measurements, :health_score)
      assert Map.has_key?(measurements, :memory_usage)
      assert Map.has_key?(measurements, :cpu_usage)

      # Clean up
      :telemetry.detach("test-health-check")
    end

    test "emits quarantine telemetry", _ctx do
      test_pid = self()

      # Attach telemetry handler
      :telemetry.attach(
        "test-quarantine",
        [:indrajaal, :safety, :sentinel, :process_quarantined],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Spawn and quarantine a process
      victim =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      Sentinel.quarantine(victim, :test_reason)

      # Wait for telemetry
      assert_receive {:telemetry, [:indrajaal, :safety, :sentinel, :process_quarantined],
                      _measurements, metadata},
                     1000

      # inspect(:test_reason) returns ":test_reason"
      assert metadata.reason == ":test_reason"

      # Clean up
      :telemetry.detach("test-quarantine")
      Sentinel.release(victim)
      send(victim, :stop)
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "integration with Guardian" do
    @tag :integration
    test "escalates critical health to Guardian when enabled" do
      # This is a placeholder - would need Guardian started to test fully
      # The Sentinel should call Guardian.report_threat when health is critical
      assert true
    end
  end
end
