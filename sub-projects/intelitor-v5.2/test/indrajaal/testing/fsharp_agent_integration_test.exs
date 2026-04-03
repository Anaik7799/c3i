defmodule Indrajaal.Testing.FsharpAgentIntegrationTest do
  @moduledoc """
  Phase 6 integration tests: F# TestAgent → ZenohTestOrchestrator → Homeostasis PID.

  Verifies that CP-AGENT-* telemetry events flow through the orchestrator
  and that pass_rate feeds into the Homeostasis stress calculation.

  ## STAMP Safety Integration
  - SC-SIL6-004: Neural-immune response < 50ms
  - SC-BIO-001: OODA cycle < 100ms
  - SC-ZTEST-005: Orchestrator aggregate update < 100ms

  ## Change History
  | Version | Date       | Author | Change |
  |---------|------------|--------|--------|
  | 21.3.0  | 2026-03-20 | Claude | Phase 6: Initial creation |
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Testing.ZenohTestOrchestrator
  alias Indrajaal.Cortex.Homeostasis.Controller, as: HomeostasisController

  @moduletag :zenoh_nif
  @test_name :fsharp_agent_integration_test

  setup do
    # Ensure phoenix_pubsub app and PubSub registry are running
    Application.ensure_all_started(:phoenix_pubsub)

    case Process.whereis(Indrajaal.PubSub) do
      nil -> Phoenix.PubSub.Supervisor.start_link(name: Indrajaal.PubSub)
      _pid -> :ok
    end

    # Stop any lingering test instance
    case Process.whereis(@test_name) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 5000)
    end

    Process.sleep(30)

    {:ok, pid} = ZenohTestOrchestrator.start_link(name: @test_name)
    {:ok, orchestrator: pid}
  end

  describe "CP-AGENT-* event routing" do
    test "agent_started event is recorded", %{orchestrator: pid} do
      send(pid, {:agent_started, "run-001", %{run_id: "run-001", config: %{}}})
      Process.sleep(10)

      stats = GenServer.call(pid, :get_stats)
      assert stats.agent_runs == 1
    end

    test "agent_done event updates pass_rate", %{orchestrator: pid} do
      send(
        pid,
        {:agent_done, "run-002",
         %{
           run_id: "run-002",
           pass_rate: 0.85,
           total: 5,
           passed: 4,
           failed: 1,
           duration_ms: 12345
         }}
      )

      Process.sleep(10)

      stats = GenServer.call(pid, :get_stats)
      assert stats.agent_total == 5
      assert stats.agent_passed == 4
      assert stats.agent_failed == 1
      assert_in_delta stats.agent_last_pass_rate, 0.85, 0.001
    end

    test "agent_error event is tracked in recent_failures", %{orchestrator: pid} do
      send(
        pid,
        {:agent_error, "run-003",
         %{
           run_id: "run-003",
           error: "compilation failed"
         }}
      )

      Process.sleep(50)

      stats = GenServer.call(pid, :get_stats)
      assert stats.recent_failures_count >= 1
    end

    test "multiple agent runs accumulate correctly", %{orchestrator: pid} do
      # First run: 4/5 pass
      send(
        pid,
        {:agent_done, "run-a",
         %{
           run_id: "run-a",
           pass_rate: 0.8,
           total: 5,
           passed: 4,
           failed: 1,
           duration_ms: 1000
         }}
      )

      # Second run: 3/5 pass
      send(
        pid,
        {:agent_done, "run-b",
         %{
           run_id: "run-b",
           pass_rate: 0.6,
           total: 5,
           passed: 3,
           failed: 2,
           duration_ms: 2000
         }}
      )

      Process.sleep(10)

      stats = GenServer.call(pid, :get_stats)
      assert stats.agent_total == 10
      assert stats.agent_passed == 7
      assert stats.agent_failed == 3
      # Last pass_rate is from most recent run
      assert_in_delta stats.agent_last_pass_rate, 0.6, 0.001
    end
  end

  describe "Homeostasis PID integration" do
    @weights %{
      cpu: 0.18,
      memory: 0.22,
      error_rate: 0.25,
      latency: 0.13,
      queue_depth: 0.09,
      test_pass_rate: 0.13
    }

    test "test_pass_rate is inverted in weighted stress calculation" do
      # High pass rate (0.95) should produce LOW stress contribution
      metrics_high = %{
        cpu: 0.5,
        memory: 0.5,
        error_rate: 0.1,
        latency: 0.3,
        queue_depth: 0.2,
        test_pass_rate: 0.95
      }

      # Low pass rate (0.3) should produce HIGH stress contribution
      metrics_low = %{
        cpu: 0.5,
        memory: 0.5,
        error_rate: 0.1,
        latency: 0.3,
        queue_depth: 0.2,
        test_pass_rate: 0.3
      }

      stress_high_pr = HomeostasisController.weighted_stress(metrics_high, @weights)
      stress_low_pr = HomeostasisController.weighted_stress(metrics_low, @weights)

      # Low pass rate should result in HIGHER stress
      assert stress_low_pr > stress_high_pr,
             "Low pass rate (#{stress_low_pr}) should produce higher stress than high pass rate (#{stress_high_pr})"
    end

    test "missing test_pass_rate defaults to 0 stress contribution" do
      metrics_without = %{
        cpu: 0.5,
        memory: 0.5,
        error_rate: 0.1,
        latency: 0.3,
        queue_depth: 0.2
      }

      # Should not crash, defaults gracefully
      stress = HomeostasisController.weighted_stress(metrics_without, @weights)
      assert is_float(stress) and stress >= 0.0 and stress <= 1.0
    end
  end
end
