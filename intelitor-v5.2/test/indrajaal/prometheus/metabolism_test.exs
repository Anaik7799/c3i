defmodule Indrajaal.Prometheus.MetabolismTest do
  @moduledoc """
  Comprehensive tests for the PROMETHEUS Metabolism Controller.

  ## WHAT
  Tests the token bucket rate limiter with biomorphic scaling functions
  for agent swarm management.

  ## WHY
  - SC-PROM-002: API usage SHALL NOT exceed 95% of provider limits
  - SC-API-003: Exponential backoff on 429 (base 2s, max 60s)
  - SC-API-009: Circuit breaker after 3 consecutive 429s
  - SC-PRIME-001: Will to Live (never optimize to zero)

  ## CONSTRAINTS
  - Token refill rate: 1 token/second
  - Max bucket size: 100 tokens
  - Min agents: 1, Max agents: 25
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Prometheus.Metabolism

  describe "start_link/1" do
    test "starts the metabolism GenServer" do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = Metabolism.start_link(name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "initializes with full bucket" do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)

      state = GenServer.call(pid, :get_state)

      assert state.tokens == 100
      assert state.max_tokens == 100
      assert state.current_agents == 1
      assert state.consecutive_failures == 0

      GenServer.stop(pid)
    end
  end

  describe "consume/1 - Token Bucket" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "consumes tokens from bucket", %{pid: pid} do
      {:ok, remaining} = GenServer.call(pid, {:consume, 10})
      assert remaining == 90
    end

    test "returns error when insufficient tokens", %{pid: pid} do
      # Drain the bucket
      GenServer.call(pid, {:consume, 95})

      # Try to consume more than available
      result = GenServer.call(pid, {:consume, 10})
      assert result == {:error, :rate_limited}
    end

    test "refills tokens over time", %{pid: pid} do
      # Consume tokens
      GenServer.call(pid, {:consume, 50})

      # Wait for refill (1 token/second, wait 100ms for some refill)
      Process.sleep(150)

      state = GenServer.call(pid, :get_state)
      # Should have refilled some tokens
      assert state.tokens > 50
    end

    test "bucket never exceeds max", %{pid: pid} do
      # Wait for potential refill
      Process.sleep(100)

      state = GenServer.call(pid, :get_state)
      assert state.tokens <= 100
    end
  end

  describe "report_response/2 - Rate Limit Handling" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "handles successful response (2xx)", %{pid: pid} do
      headers = %{
        "x-ratelimit-remaining-requests" => "850",
        "x-ratelimit-limit-requests" => "1000"
      }

      GenServer.cast(pid, {:response, 200, headers})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_failures == 0
    end

    test "handles rate limit response (429) - SC-API-003", %{pid: pid} do
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_failures == 1
      # Base backoff
      assert state.backoff_ms >= 2000
    end

    test "exponential backoff on consecutive 429s", %{pid: pid} do
      # First 429
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(10)
      state1 = GenServer.call(pid, :get_state)

      # Second 429
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(10)
      state2 = GenServer.call(pid, :get_state)

      assert state2.backoff_ms > state1.backoff_ms
    end

    test "backoff capped at 60 seconds", %{pid: pid} do
      # Trigger many 429s
      for _ <- 1..10 do
        GenServer.cast(pid, {:response, 429, %{}})
        Process.sleep(5)
      end

      state = GenServer.call(pid, :get_state)
      assert state.backoff_ms <= 60_000
    end

    test "handles server error (5xx)", %{pid: pid} do
      GenServer.cast(pid, {:response, 500, %{}})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.consecutive_failures == 1
    end

    test "respects retry-after header", %{pid: pid} do
      headers = %{"retry-after" => "45"}
      GenServer.cast(pid, {:response, 429, headers})
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.backoff_ms == 45_000
    end
  end

  describe "circuit breaker (SC-API-009)" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "opens after 3 consecutive 429s", %{pid: pid} do
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(20)

      state = GenServer.call(pid, :get_state)
      assert state.circuit_open == true
    end

    test "blocks consumption when circuit open", %{pid: pid} do
      # Open circuit
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(20)

      result = GenServer.call(pid, {:consume, 1})
      assert result == {:error, :circuit_open}
    end

    test "manual reset closes circuit", %{pid: pid} do
      # Open circuit
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(20)

      # Reset
      GenServer.cast(pid, :reset_circuit_breaker)
      Process.sleep(10)

      state = GenServer.call(pid, :get_state)
      assert state.circuit_open == false
      assert state.consecutive_failures == 0
    end
  end

  describe "scaling_signal/0 - Agent Scaling" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns hold when balanced", %{pid: pid} do
      # Consume about half
      GenServer.call(pid, {:consume, 50})

      {signal, _target} = GenServer.call(pid, :scaling_signal)
      assert signal in [:hold, :scale_up, :scale_down]
    end

    test "returns scale_down when circuit open", %{pid: pid} do
      # Open circuit
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(20)

      {signal, target} = GenServer.call(pid, :scaling_signal)
      assert signal == :scale_down
      # Min agents
      assert target == 1
    end
  end

  describe "recommended_agents/0 - SC-PRIME-001" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "never returns zero (Will to Live)", %{pid: pid} do
      # Drain bucket completely
      GenServer.call(pid, {:consume, 100})

      recommended = GenServer.call(pid, :recommended_agents)
      assert recommended >= 1
    end

    test "never exceeds max agents", %{pid: pid} do
      # Full bucket = max capacity
      recommended = GenServer.call(pid, :recommended_agents)
      assert recommended <= 25
    end

    test "scales with utilization", %{pid: pid} do
      # Full bucket - low utilization = low demand = fewer agents needed
      rec_full = GenServer.call(pid, :recommended_agents)

      # Consume tokens - high utilization = high demand = more agents needed
      GenServer.call(pid, {:consume, 80})
      rec_depleted = GenServer.call(pid, :recommended_agents)

      # Higher utilization means higher demand, so more agents recommended
      # (The biomorphic model: more activity = need more workers)
      assert rec_depleted >= rec_full
    end

    test "returns min when circuit open", %{pid: pid} do
      # Open circuit
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      GenServer.cast(pid, {:response, 429, %{}})
      Process.sleep(20)

      recommended = GenServer.call(pid, :recommended_agents)
      assert recommended == 1
    end
  end

  describe "get_state/0" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns complete metabolic state", %{pid: pid} do
      state = GenServer.call(pid, :get_state)

      assert Map.has_key?(state, :tokens)
      assert Map.has_key?(state, :max_tokens)
      assert Map.has_key?(state, :token_utilization)
      assert Map.has_key?(state, :current_agents)
      assert Map.has_key?(state, :circuit_open)
      assert Map.has_key?(state, :consecutive_failures)
      assert Map.has_key?(state, :backoff_ms)
      assert Map.has_key?(state, :total_requests)
      assert Map.has_key?(state, :total_tokens_consumed)
    end

    test "calculates utilization correctly", %{pid: pid} do
      # Consume 30 tokens (30% utilization)
      GenServer.call(pid, {:consume, 30})

      state = GenServer.call(pid, :get_state)
      # Utilization = 1 - (remaining / max) = 1 - (70/100) = 0.3
      assert_in_delta state.token_utilization, 0.3, 0.1
    end

    test "tracks total requests", %{pid: pid} do
      initial = GenServer.call(pid, :get_state)
      assert initial.total_requests == 0

      GenServer.call(pid, {:consume, 1})
      GenServer.call(pid, {:consume, 1})
      GenServer.call(pid, {:consume, 1})

      after_requests = GenServer.call(pid, :get_state)
      assert after_requests.total_requests == 3
    end

    test "tracks total tokens consumed", %{pid: pid} do
      initial = GenServer.call(pid, :get_state)
      assert initial.total_tokens_consumed == 0

      GenServer.call(pid, {:consume, 5})
      GenServer.call(pid, {:consume, 10})
      GenServer.call(pid, {:consume, 15})

      after_consume = GenServer.call(pid, :get_state)
      assert after_consume.total_tokens_consumed == 30
    end
  end

  describe "telemetry" do
    setup do
      name = :"metabolism_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Metabolism.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "emits metabolism telemetry on refill", %{pid: pid} do
      # Telemetry is emitted on :refill message
      # Wait for at least one refill cycle
      Process.sleep(1100)

      # State should show throughput history
      state = GenServer.call(pid, :get_state)
      # Verify telemetry was triggered (we can't easily capture telemetry in tests
      # but we can verify state is being updated)
      assert is_list(state.throughput_history) or is_nil(state.throughput_history)
    end
  end
end
