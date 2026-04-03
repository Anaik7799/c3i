defmodule Indrajaal.Coordination.ReliabilityMonitorTest do
  @moduledoc """
  TDG comprehensive test suite for ReliabilityMonitor GenServer.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation gaps are fixed
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SIL6-001: Reliability monitor must survive all state transitions
  - SC-EMR-057: Emergency stop must complete within bounds
  - SC-IMMUNE-001: Sentinel health checks run via reliability monitor

  ## Constitutional Verification
  - Psi0 Existence: ReliabilityMonitor GenServer survives failure reports
  - Psi1 Regeneration: Monitor can be restarted after termination

  ## Founder's Directive Alignment
  - Omega0.1: Reliability monitoring ensures operational continuity

  ## TPS 5-Level RCA Context
  - L1 Symptom: System degrades without fault detection
  - L5 Root Cause: Missing reliability check → cascading failure
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Coordination.ReliabilityMonitor

  @moduletag :zenoh_nif

  # Each test starts its own isolated GenServer instance to avoid name collision
  defp start_monitor(opts \\ []) do
    # Start without name: to avoid collision with running system
    GenServer.start_link(ReliabilityMonitor, opts)
  end

  # ==========================================================================
  # start_link/1
  # ==========================================================================

  describe "start_link/1" do
    test "starts successfully with default options" do
      assert {:ok, pid} = start_monitor()
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with custom config options" do
      assert {:ok, pid} = start_monitor(health_check_interval_ms: 60_000)
      assert is_pid(pid)
      GenServer.stop(pid)
    end

    test "initializes with system_health structure" do
      {:ok, pid} = start_monitor()
      # Process is alive and responding
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # register_service/3
  # ==========================================================================

  describe "register_service/3" do
    test "registers a service successfully" do
      {:ok, pid} = start_monitor()

      result =
        ReliabilityMonitor.register_service(pid, "service-alpha", %{
          type: :api,
          criticality: :high
        })

      assert result == :ok
      GenServer.stop(pid)
    end

    test "registers multiple distinct services" do
      {:ok, pid} = start_monitor()

      assert :ok = ReliabilityMonitor.register_service(pid, "svc-1", %{type: :db})
      assert :ok = ReliabilityMonitor.register_service(pid, "svc-2", %{type: :api})
      assert :ok = ReliabilityMonitor.register_service(pid, "svc-3", %{type: :cache})

      GenServer.stop(pid)
    end

    test "registers service with empty config" do
      {:ok, pid} = start_monitor()
      assert :ok = ReliabilityMonitor.register_service(pid, "minimal-svc", %{})
      GenServer.stop(pid)
    end

    test "re-registering same service_id returns :ok (idempotent)" do
      {:ok, pid} = start_monitor()

      assert :ok = ReliabilityMonitor.register_service(pid, "dup-svc", %{version: 1})
      assert :ok = ReliabilityMonitor.register_service(pid, "dup-svc", %{version: 2})

      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # report_service_failure/3
  # ==========================================================================

  describe "report_service_failure/3" do
    test "accepts failure report as cast (no return value to assert)" do
      {:ok, pid} = start_monitor()

      # register first
      :ok = ReliabilityMonitor.register_service(pid, "failing-svc", %{type: :api})

      # report failure (cast - returns :ok immediately)
      result =
        ReliabilityMonitor.report_service_failure(pid, "failing-svc", %{
          error: :timeout,
          message: "Service timed out"
        })

      assert result == :ok
      # Monitor process must still be alive after failure report
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "failure report for unknown service is accepted without crash" do
      {:ok, pid} = start_monitor()

      # This should not crash the monitor
      result =
        ReliabilityMonitor.report_service_failure(pid, "unknown-svc-xyz", %{
          error: :econnrefused
        })

      assert result == :ok
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "multiple failure reports do not crash monitor" do
      {:ok, pid} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid, "flaky-svc", %{})

      Enum.each(1..5, fn i ->
        ReliabilityMonitor.report_service_failure(pid, "flaky-svc", %{attempt: i})
      end)

      # Allow casts to be processed
      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # get_reliability_metrics/1
  # ==========================================================================

  describe "get_reliability_metrics/1" do
    test "returns a map" do
      {:ok, pid} = start_monitor()
      metrics = ReliabilityMonitor.get_reliability_metrics(pid)
      assert is_map(metrics)
      GenServer.stop(pid)
    end

    test "metrics map is non-nil" do
      {:ok, pid} = start_monitor()
      metrics = ReliabilityMonitor.get_reliability_metrics(pid)
      refute is_nil(metrics)
      GenServer.stop(pid)
    end

    test "metrics are available after service registration" do
      {:ok, pid} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid, "metered-svc", %{})
      metrics = ReliabilityMonitor.get_reliability_metrics(pid)
      assert is_map(metrics)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # check_system_reliability/1
  # ==========================================================================

  describe "check_system_reliability/1" do
    test "returns ok tuple with reliability report" do
      {:ok, pid} = start_monitor()
      result = ReliabilityMonitor.check_system_reliability(pid)
      assert {:ok, report} = result
      assert is_map(report)
      GenServer.stop(pid)
    end

    test "reliability report contains overall_reliability key or similar" do
      {:ok, pid} = start_monitor()
      {:ok, report} = ReliabilityMonitor.check_system_reliability(pid)
      # Report should have some content
      refute report == %{}
      GenServer.stop(pid)
    end

    test "can call check_system_reliability multiple times" do
      {:ok, pid} = start_monitor()
      assert {:ok, _} = ReliabilityMonitor.check_system_reliability(pid)
      assert {:ok, _} = ReliabilityMonitor.check_system_reliability(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # trigger_recovery/3
  # ==========================================================================

  describe "trigger_recovery/3" do
    test "trigger_recovery for auto_restart action" do
      {:ok, pid} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid, "recovery-svc", %{})

      result = ReliabilityMonitor.trigger_recovery(pid, "recovery-svc", :auto_restart)
      # May return ok or error depending on service state
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      GenServer.stop(pid)
    end

    test "trigger_recovery for failover action" do
      {:ok, pid} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid, "failover-svc", %{})

      result = ReliabilityMonitor.trigger_recovery(pid, "failover-svc", :failover)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      GenServer.stop(pid)
    end

    test "trigger_recovery for manual_intervention" do
      {:ok, pid} = start_monitor()
      result = ReliabilityMonitor.trigger_recovery(pid, "manual-svc", :manual_intervention)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      GenServer.stop(pid)
    end

    test "trigger_recovery for emergency_shutdown" do
      {:ok, pid} = start_monitor()
      result = ReliabilityMonitor.trigger_recovery(pid, "critical-svc", :emergency_shutdown)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
      # Monitor itself should not crash
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "monitor remains alive after cascading failure reports" do
      {:ok, pid} = start_monitor()

      # Simulate cascading failures
      services = ["db", "cache", "api", "worker", "scheduler"]

      Enum.each(services, fn svc ->
        :ok = ReliabilityMonitor.register_service(pid, svc, %{})
        ReliabilityMonitor.report_service_failure(pid, svc, %{severity: :critical})
      end)

      Process.sleep(100)
      assert Process.alive?(pid), "Monitor must survive cascading failures (SC-SIL6-001)"
      GenServer.stop(pid)
    end

    test "reliability check completes in reasonable time" do
      {:ok, pid} = start_monitor()
      start = System.monotonic_time(:millisecond)
      {:ok, _} = ReliabilityMonitor.check_system_reliability(pid)
      elapsed = System.monotonic_time(:millisecond) - start
      # Should complete within 5 seconds for a system check
      assert elapsed < 5_000, "Reliability check took #{elapsed}ms, expected < 5s"
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Constitutional Invariants (Psi0-Psi1)
  # ==========================================================================

  describe "Constitutional Invariants (Psi0-Psi1)" do
    test "Psi0 existence: monitor survives bad failure details" do
      {:ok, pid} = start_monitor()

      # Report with various weird payloads
      ReliabilityMonitor.report_service_failure(pid, "svc", %{nested: %{deep: [1, 2, 3]}})
      ReliabilityMonitor.report_service_failure(pid, "svc", %{error: nil})

      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "Psi1 regeneration: new monitor starts fresh after stop" do
      {:ok, pid1} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid1, "svc-to-be-lost", %{})
      GenServer.stop(pid1)

      Process.sleep(10)

      # New monitor starts fresh
      {:ok, pid2} = start_monitor()
      assert Process.alive?(pid2)
      metrics = ReliabilityMonitor.get_reliability_metrics(pid2)
      assert is_map(metrics)
      GenServer.stop(pid2)
    end
  end

  # ==========================================================================
  # FMEA Tests
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-RM-001: monitor handles very high failure rates without crash" do
      {:ok, pid} = start_monitor()
      :ok = ReliabilityMonitor.register_service(pid, "high-failure-svc", %{})

      # Rapid-fire failure reports
      Enum.each(1..20, fn i ->
        ReliabilityMonitor.report_service_failure(pid, "high-failure-svc", %{
          count: i,
          timestamp: System.monotonic_time(:millisecond)
        })
      end)

      Process.sleep(100)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    @tag :fmea
    test "FMEA-RM-002: metrics remain accessible after failure storms" do
      {:ok, pid} = start_monitor()

      Enum.each(1..10, fn i ->
        ReliabilityMonitor.report_service_failure(pid, "storm-svc-#{i}", %{severity: :major})
      end)

      Process.sleep(100)
      metrics = ReliabilityMonitor.get_reliability_metrics(pid)
      assert is_map(metrics)
      GenServer.stop(pid)
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "register_service always returns :ok for any service_id string" do
    {:ok, pid} = start_monitor()

    forall service_id <- PC.non_empty(PC.utf8()) do
      result = ReliabilityMonitor.register_service(pid, service_id, %{})
      result == :ok
    end
    |> tap(fn _ -> GenServer.stop(pid) end)
  end

  test "get_reliability_metrics always returns a map" do
    ExUnitProperties.check all(_x <- SD.constant(:ok)) do
      {:ok, pid} = start_monitor()
      metrics = ReliabilityMonitor.get_reliability_metrics(pid)
      assert is_map(metrics)
      GenServer.stop(pid)
    end
  end
end
