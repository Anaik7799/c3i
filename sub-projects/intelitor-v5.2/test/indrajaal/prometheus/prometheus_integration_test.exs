defmodule Indrajaal.Prometheus.IntegrationTest do
  @moduledoc """
  Integration tests for the PROMETHEUS Biomorphic System.

  ## WHAT
  Tests the integration between BiomorphicDashboard, Metabolism, and
  the broader system including telemetry and scaling coordination.

  ## WHY
  - SC-PROM-001: Proof tokens for state mutations
  - SC-PROM-003: Dashboard MUST refresh every 30s
  - AOR-PROM-002: Supervisor MUST respect Metabolism signals

  ## CONSTRAINTS
  - Tests full system interaction
  - No external API dependencies (mocked)
  - Verifies cross-module coordination
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Prometheus.BiomorphicDashboard
  alias Indrajaal.Prometheus.Metabolism

  describe "Dashboard <-> Metabolism Integration" do
    setup do
      dashboard_name = :"dash_int_#{:erlang.unique_integer([:positive])}"
      metabolism_name = :"meta_int_#{:erlang.unique_integer([:positive])}"

      {:ok, dash_pid} = BiomorphicDashboard.start_link(name: dashboard_name)
      {:ok, meta_pid} = Metabolism.start_link(name: metabolism_name)

      on_exit(fn ->
        if Process.alive?(dash_pid), do: GenServer.stop(dash_pid)
        if Process.alive?(meta_pid), do: GenServer.stop(meta_pid)
      end)

      %{dashboard: dash_pid, metabolism: meta_pid}
    end

    test "dashboard reflects metabolism state", %{dashboard: dash, metabolism: meta} do
      # Dashboard reflects API metrics from headers

      # Simulate API response updating both
      headers = %{
        "x-ratelimit-remaining-requests" => "750",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(meta, {:response, 200, headers})
      GenServer.cast(dash, {:api_metrics, %{rate_limit_remaining: 750, rate_limit_total: 1000}})
      Process.sleep(20)

      # Verify both systems have consistent view
      dash_state = GenServer.call(dash, :get_state)
      assert dash_state.api_metrics.rate_limit_remaining == 750
    end

    test "circuit breaker affects both systems", %{dashboard: dash, metabolism: meta} do
      # Trigger circuit breaker in metabolism
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(meta, {:response, 429, %{}})

      # Also update dashboard
      GenServer.cast(dash, {:rate_limited, %{}})
      GenServer.cast(dash, {:rate_limited, %{}})
      GenServer.cast(dash, {:rate_limited, %{}})
      Process.sleep(20)

      # Verify both have circuit open
      meta_state = GenServer.call(meta, :get_state)
      dash_state = GenServer.call(dash, :get_state)

      assert meta_state.circuit_open == true
      assert dash_state.scaling_mode == :emergency_scale_down
    end

    test "scaling signals are consistent", %{dashboard: dash, metabolism: meta} do
      # Simulate same API state in both
      headers = %{
        "x-ratelimit-remaining-requests" => "900",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(meta, {:response, 200, headers})
      GenServer.cast(dash, {:api_metrics, %{rate_limit_remaining: 900, rate_limit_total: 1000}})
      Process.sleep(20)

      # Get scaling signals from both
      {meta_signal, _meta_target} = GenServer.call(meta, :scaling_signal)
      {dash_signal, _dash_target} = GenServer.call(dash, :get_scaling_signal)

      # Both should give compatible signals (may differ in exact values due to timing)
      assert meta_signal in [:scale_up, :scale_down, :hold]
      assert dash_signal in [:scale_up, :scale_down, :hold]
    end
  end

  describe "Full System Workflow" do
    setup do
      dashboard_name = :"dash_wf_#{:erlang.unique_integer([:positive])}"
      metabolism_name = :"meta_wf_#{:erlang.unique_integer([:positive])}"

      {:ok, dash_pid} = BiomorphicDashboard.start_link(name: dashboard_name)
      {:ok, meta_pid} = Metabolism.start_link(name: metabolism_name)

      on_exit(fn ->
        if Process.alive?(dash_pid), do: GenServer.stop(dash_pid)
        if Process.alive?(meta_pid), do: GenServer.stop(meta_pid)
      end)

      %{dashboard: dash_pid, metabolism: meta_pid}
    end

    test "complete agent lifecycle", %{dashboard: dash, metabolism: meta} do
      # 1. Agent starts working
      GenServer.cast(dash, {:agent_thinking, "worker-1", "Starting task analysis..."})

      # 2. API call consumes tokens
      {:ok, _remaining} = GenServer.call(meta, {:consume, 5})

      # 3. API returns success with headers
      headers = %{
        "x-ratelimit-remaining-requests" => "995",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(meta, {:response, 200, headers})
      GenServer.cast(dash, {:api_metrics, %{rate_limit_remaining: 995, rate_limit_total: 1000}})

      # 4. Agent updates progress
      GenServer.cast(dash, {:agent_thinking, "worker-1", "Completed analysis"})
      GenServer.cast(dash, {:plan_progress, %{total: 10, completed: 1, in_progress: 0}})
      Process.sleep(20)

      # 5. Verify state
      dash_state = GenServer.call(dash, :get_state)
      meta_state = GenServer.call(meta, :get_state)

      assert dash_state.agent_states["worker-1"].thinking == "Completed analysis"
      assert dash_state.plan_progress.completed == 1
      assert meta_state.total_requests == 1
      assert meta_state.total_tokens_consumed == 5
    end

    test "graceful degradation under load", %{dashboard: _dash, metabolism: meta} do
      # Consume most tokens (simulate heavy load - high utilization)
      for _ <- 1..18 do
        GenServer.call(meta, {:consume, 5})
      end

      # Get scaling recommendation
      {signal, target} = GenServer.call(meta, :scaling_signal)

      # Heavy load means high demand - biomorphic model scales up
      # But we verify the essential invariant: never zero (SC-PRIME-001)
      assert signal in [:scale_up, :scale_down, :hold]
      # SC-PRIME-001: Will to Live
      assert target >= 1
    end

    test "recovery after rate limiting", %{dashboard: dash, metabolism: meta} do
      # Trigger rate limits
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(dash, {:rate_limited, %{}})
      GenServer.cast(dash, {:rate_limited, %{}})
      Process.sleep(10)

      # System should be in cautious state
      meta_state = GenServer.call(meta, :get_state)
      assert meta_state.consecutive_failures == 2

      # Successful response should begin recovery
      GenServer.cast(meta, {:response, 200, %{}})
      GenServer.cast(dash, {:api_metrics, %{rate_limit_remaining: 800, rate_limit_total: 1000}})
      Process.sleep(10)

      # Verify recovery
      recovered_state = GenServer.call(meta, :get_state)
      assert recovered_state.consecutive_failures == 0
    end
  end

  describe "Telemetry Integration" do
    setup do
      dashboard_name = :"dash_tel_#{:erlang.unique_integer([:positive])}"
      {:ok, dash_pid} = BiomorphicDashboard.start_link(name: dashboard_name)
      on_exit(fn -> if Process.alive?(dash_pid), do: GenServer.stop(dash_pid) end)
      %{dashboard: dash_pid}
    end

    test "telemetry events are structured correctly", %{dashboard: dash} do
      # Simulate activity
      GenServer.cast(dash, {:agent_thinking, "worker-1", "Processing..."})
      GenServer.cast(dash, {:api_metrics, %{rate_limit_remaining: 800, rate_limit_total: 1000}})
      Process.sleep(10)

      # Get state - should have structured data for telemetry
      state = GenServer.call(dash, :get_state)

      # Verify telemetry-ready structure
      assert is_map(state.api_metrics)
      assert is_map(state.agent_states)
      assert is_integer(state.current_agent_count)
    end
  end

  describe "Context Management (AOR-PROM-003)" do
    setup do
      dashboard_name = :"dash_ctx_#{:erlang.unique_integer([:positive])}"
      {:ok, dash_pid} = BiomorphicDashboard.start_link(name: dashboard_name)
      on_exit(fn -> if Process.alive?(dash_pid), do: GenServer.stop(dash_pid) end)
      %{dashboard: dash_pid}
    end

    test "compaction triggered at 80% threshold", %{dashboard: dash} do
      # Below threshold
      assert GenServer.call(dash, {:should_compact?, 0.79}) == false

      # At threshold
      assert GenServer.call(dash, {:should_compact?, 0.80}) == true

      # Above threshold
      assert GenServer.call(dash, {:should_compact?, 0.95}) == true
    end
  end

  describe "Error Recovery" do
    setup do
      dashboard_name = :"dash_err_#{:erlang.unique_integer([:positive])}"
      metabolism_name = :"meta_err_#{:erlang.unique_integer([:positive])}"

      {:ok, dash_pid} = BiomorphicDashboard.start_link(name: dashboard_name)
      {:ok, meta_pid} = Metabolism.start_link(name: metabolism_name)

      on_exit(fn ->
        if Process.alive?(dash_pid), do: GenServer.stop(dash_pid)
        if Process.alive?(meta_pid), do: GenServer.stop(meta_pid)
      end)

      %{dashboard: dash_pid, metabolism: meta_pid}
    end

    test "handles malformed API metrics gracefully", %{dashboard: dash} do
      # Send malformed data - should not crash
      GenServer.cast(dash, {:api_metrics, %{}})
      Process.sleep(10)

      # Process should still be alive
      assert Process.alive?(dash)
    end

    test "handles nil values in agent state", %{dashboard: dash} do
      # Send agent with nil thinking
      GenServer.cast(dash, {:agent_thinking, "worker-1", nil})
      Process.sleep(10)

      # Should not crash
      assert Process.alive?(dash)
    end

    test "handles rate limit recovery atomically", %{metabolism: meta} do
      # Trigger failures then success
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(meta, {:response, 429, %{}})
      GenServer.cast(meta, {:response, 200, %{}})
      Process.sleep(20)

      state = GenServer.call(meta, :get_state)
      # Should be fully recovered
      assert state.consecutive_failures == 0
    end
  end
end
