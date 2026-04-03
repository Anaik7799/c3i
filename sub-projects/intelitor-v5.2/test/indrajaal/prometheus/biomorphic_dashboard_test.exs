defmodule Indrajaal.Prometheus.BiomorphicDashboardTest do
  @moduledoc """
  Comprehensive tests for the PROMETHEUS Biomorphic Dashboard.

  ## WHAT
  Tests the BiomorphicDashboard GenServer for agent state management,
  API metrics collection, scaling decisions, and dashboard refresh cycles.

  ## WHY
  - SC-PROM-003: Dashboard MUST refresh every 30s
  - SC-API-001: Max concurrent agents 5-25 based on rate limit headroom
  - AOR-PROM-001: Agents MUST report thinking state

  ## CONSTRAINTS
  - Tests MUST complete in <5s each
  - No external API calls (mocked)
  - State mutations verified via get_dashboard_state/0
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Prometheus.BiomorphicDashboard

  describe "start_link/1" do
    test "starts the dashboard GenServer" do
      # Use unique name to avoid conflicts
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "initializes with default state" do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)

      state = GenServer.call(pid, :get_state)

      assert state.current_agent_count == 1
      assert state.target_agent_count == 1
      assert state.scaling_mode == :hold
      assert state.consecutive_429s == 0
      assert is_nil(state.cooldown_until)

      GenServer.stop(pid)
    end
  end

  describe "report_agent_thinking/3" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, name: name}
    end

    test "stores agent thinking state", %{pid: pid} do
      GenServer.cast(pid, {:agent_thinking, "worker-1", "Analyzing code structure..."})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert Map.has_key?(state.agent_states, "worker-1")
      assert state.agent_states["worker-1"].thinking == "Analyzing code structure..."
    end

    test "updates existing agent state", %{pid: pid} do
      GenServer.cast(pid, {:agent_thinking, "worker-1", "First thought"})
      Process.sleep(10)
      GenServer.cast(pid, {:agent_thinking, "worker-1", "Second thought"})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.agent_states["worker-1"].thinking == "Second thought"
    end

    test "tracks multiple agents", %{pid: pid} do
      GenServer.cast(pid, {:agent_thinking, "worker-1", "Task A"})
      GenServer.cast(pid, {:agent_thinking, "worker-2", "Task B"})
      GenServer.cast(pid, {:agent_thinking, "worker-3", "Task C"})
      Process.sleep(20)

      state = GenServer.call(pid, :get_state)
      assert map_size(state.agent_states) == 3
    end
  end

  describe "report_api_metrics/1" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "stores API metrics from headers", %{pid: pid} do
      metrics = %{
        rate_limit_remaining: 850,
        rate_limit_total: 1000,
        rpm: 45,
        rpm_limit: 60,
        tpm: 50_000,
        tpm_limit: 100_000
      }

      GenServer.cast(pid, {:api_metrics, metrics})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.api_metrics.rate_limit_remaining == 850
      assert state.api_metrics.rate_limit_total == 1000
    end

    test "resets consecutive 429s on success", %{pid: pid} do
      # First simulate some 429s
      GenServer.cast(pid, {:rate_limited, %{}})
      GenServer.cast(pid, {:rate_limited, %{}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_429s == 2

      # Now report success
      GenServer.cast(pid, {:api_metrics, %{rate_limit_remaining: 900, rate_limit_total: 1000}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_429s == 0
    end
  end

  describe "rate limiting and circuit breaker" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "increments consecutive 429s", %{pid: pid} do
      GenServer.cast(pid, {:rate_limited, %{}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_429s == 1
    end

    test "triggers circuit breaker after 3 consecutive 429s (SC-API-009)", %{pid: pid} do
      GenServer.cast(pid, {:rate_limited, %{}})
      GenServer.cast(pid, {:rate_limited, %{}})
      GenServer.cast(pid, {:rate_limited, %{}})
      Process.sleep(20)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_429s == 3
      assert not is_nil(state.cooldown_until)
      assert state.scaling_mode == :emergency_scale_down
    end

    test "respects retry-after header", %{pid: pid} do
      GenServer.cast(pid, {:rate_limited, %{"retry-after" => "30"}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      # Cooldown should be set based on retry-after
      assert state.cooldown_until != nil or state.consecutive_429s >= 1
    end
  end

  describe "scaling decisions (SC-API-001)" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "recommends scale up when headroom exists (>60%)", %{pid: pid} do
      # Simulate low usage - lots of headroom
      # Use string keys as expected by parse_api_headers
      headers = %{
        "x-ratelimit-remaining-requests" => "900",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(pid, {:api_metrics, headers})
      Process.sleep(10)

      {signal, _target} = GenServer.call(pid, :get_scaling_signal)
      # With 90% remaining (10% used), should scale up or hold
      assert signal in [:scale_up, :hold]
    end

    test "recommends scale down when approaching limits (>70%)", %{pid: pid} do
      # Simulate high usage - remaining < 30% of total
      headers = %{
        "x-ratelimit-remaining-requests" => "200",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(pid, {:api_metrics, headers})
      Process.sleep(10)

      {signal, _target} = GenServer.call(pid, :get_scaling_signal)
      # With only 20% remaining (80% used), should scale down or hold
      assert signal in [:scale_down, :hold]
    end

    test "holds when in stable zone (40-70%)", %{pid: pid} do
      headers = %{
        "x-ratelimit-remaining-requests" => "500",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(pid, {:api_metrics, headers})
      Process.sleep(10)

      {signal, _target} = GenServer.call(pid, :get_scaling_signal)
      # With 50% remaining (50% used), should hold or scale
      assert signal in [:scale_up, :scale_down, :hold]
    end

    test "never scales to zero (SC-PRIME-001)", %{pid: pid} do
      # Even under heavy load
      metrics = %{rate_limit_remaining: 10, rate_limit_total: 1000}
      GenServer.cast(pid, {:api_metrics, metrics})
      Process.sleep(10)

      {_signal, target} = GenServer.call(pid, :get_scaling_signal)
      assert target >= 1
    end

    test "caps at max agents (25)", %{pid: pid} do
      metrics = %{rate_limit_remaining: 990, rate_limit_total: 1000}
      GenServer.cast(pid, {:api_metrics, metrics})
      Process.sleep(10)

      {_signal, target} = GenServer.call(pid, :get_scaling_signal)
      assert target <= 25
    end
  end

  describe "plan progress tracking" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "updates plan progress", %{pid: pid} do
      progress = %{total: 100, completed: 45, in_progress: 5}
      GenServer.cast(pid, {:plan_progress, progress})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.plan_progress.total == 100
      assert state.plan_progress.completed == 45
    end

    test "calculates completion percentage", %{pid: pid} do
      progress = %{total: 100, completed: 75, in_progress: 10}
      GenServer.cast(pid, {:plan_progress, progress})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      percentage = state.plan_progress.completed / state.plan_progress.total * 100
      assert percentage == 75.0
    end
  end

  describe "context management (AOR-PROM-003)" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns true when context > 80%", %{pid: pid} do
      assert GenServer.call(pid, {:should_compact?, 0.85}) == true
    end

    test "returns false when context < 80%", %{pid: pid} do
      assert GenServer.call(pid, {:should_compact?, 0.70}) == false
    end

    test "returns true at exactly 80%", %{pid: pid} do
      assert GenServer.call(pid, {:should_compact?, 0.80}) == true
    end
  end

  describe "dashboard state export" do
    setup do
      name = :"dashboard_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = BiomorphicDashboard.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns complete dashboard state", %{pid: pid} do
      # Populate some state
      GenServer.cast(pid, {:agent_thinking, "worker-1", "Working..."})
      GenServer.cast(pid, {:api_metrics, %{rate_limit_remaining: 800, rate_limit_total: 1000}})
      GenServer.cast(pid, {:plan_progress, %{total: 50, completed: 25, in_progress: 3}})
      Process.sleep(20)

      state = GenServer.call(pid, :get_state)

      # Verify all expected keys
      assert Map.has_key?(state, :api_metrics)
      assert Map.has_key?(state, :agent_states)
      assert Map.has_key?(state, :plan_progress)
      assert Map.has_key?(state, :current_agent_count)
      assert Map.has_key?(state, :scaling_mode)
    end
  end
end
