defmodule Indrajaal.Cluster.Zenoh.BackpressureTest do
  @moduledoc """
  TDG-Compliant tests for Backpressure module.

  Tests circuit breaker functionality for Zenoh event flow control.

  STAMP Constraints:
  - SC-BUS-003: Circuit breaker at 1000 events/sec
  - SC-BUS-001: Async messaging only
  - SC-BUS-004: Event ordering preserved
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cluster.Zenoh.Backpressure

  describe "Backpressure.start_link/1" do
    test "starts with default options" do
      assert {:ok, pid} = Backpressure.start_link(name: :test_bp_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom rate limit" do
      opts = [name: :test_bp_2, rate_limit: 500]
      assert {:ok, pid} = Backpressure.start_link(opts)

      state = :sys.get_state(pid)
      assert state.rate_limit == 500
      GenServer.stop(pid)
    end

    test "accepts custom window size" do
      opts = [name: :test_bp_3, window_ms: 2000]
      assert {:ok, pid} = Backpressure.start_link(opts)

      state = :sys.get_state(pid)
      assert state.window_ms == 2000
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.allow?/2" do
    test "SC-BUS-003: allows events under rate limit" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_4, rate_limit: 100)

      # Should allow first 100 events
      results = for _ <- 1..50, do: Backpressure.allow?(pid, "test-key")

      assert Enum.all?(results, & &1)
      GenServer.stop(pid)
    end

    test "SC-BUS-003: blocks events when rate limit exceeded" do
      # Very low limit for testing
      {:ok, pid} = Backpressure.start_link(name: :test_bp_5, rate_limit: 10)

      # Send 15 events rapidly
      results = for _ <- 1..15, do: Backpressure.allow?(pid, "test-key")

      # First 10 should be allowed, rest blocked
      allowed = Enum.count(results, & &1)
      assert allowed <= 10
      GenServer.stop(pid)
    end

    test "tracks separate keys independently" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_6, rate_limit: 10)

      # Fill up key-1
      for _ <- 1..10, do: Backpressure.allow?(pid, "key-1")

      # key-2 should still be allowed
      assert Backpressure.allow?(pid, "key-2")
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.try_acquire/2" do
    test "returns :ok when allowed" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_7, rate_limit: 100)

      assert :ok = Backpressure.try_acquire(pid, "test-key")
      GenServer.stop(pid)
    end

    test "returns {:error, :rate_limited} when blocked" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_8, rate_limit: 5)

      # Exhaust the limit
      for _ <- 1..5, do: Backpressure.try_acquire(pid, "test-key")

      assert {:error, :rate_limited} = Backpressure.try_acquire(pid, "test-key")
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.get_state/2" do
    test "returns circuit breaker state for key" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_9)

      # Generate some events
      Backpressure.allow?(pid, "my-key")

      state = Backpressure.get_state(pid, "my-key")

      assert is_map(state)
      assert Map.has_key?(state, :count)
      assert Map.has_key?(state, :circuit_state)
      GenServer.stop(pid)
    end

    test "returns :closed for healthy circuit" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_10)

      state = Backpressure.get_state(pid, "healthy-key")

      assert state.circuit_state == :closed
      GenServer.stop(pid)
    end

    test "returns :open when rate limit exceeded" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_11, rate_limit: 5)

      # Exceed limit
      for _ <- 1..10, do: Backpressure.allow?(pid, "overloaded-key")

      state = Backpressure.get_state(pid, "overloaded-key")

      assert state.circuit_state == :open
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.reset/2" do
    test "resets counter for specific key" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_12, rate_limit: 10)

      # Fill up the key
      for _ <- 1..10, do: Backpressure.allow?(pid, "reset-key")
      refute Backpressure.allow?(pid, "reset-key")

      # Reset
      :ok = Backpressure.reset(pid, "reset-key")

      # Should be allowed again
      assert Backpressure.allow?(pid, "reset-key")
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.reset_all/1" do
    test "resets all counters" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_13, rate_limit: 5)

      # Fill up multiple keys
      for _ <- 1..5, do: Backpressure.allow?(pid, "key-a")
      for _ <- 1..5, do: Backpressure.allow?(pid, "key-b")

      refute Backpressure.allow?(pid, "key-a")
      refute Backpressure.allow?(pid, "key-b")

      # Reset all
      :ok = Backpressure.reset_all(pid)

      # Both should be allowed
      assert Backpressure.allow?(pid, "key-a")
      assert Backpressure.allow?(pid, "key-b")
      GenServer.stop(pid)
    end
  end

  describe "Backpressure.metrics/1" do
    test "returns rate limiting metrics" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_14, rate_limit: 100)

      # Generate some traffic
      for _ <- 1..50, do: Backpressure.allow?(pid, "metrics-key")

      metrics = Backpressure.metrics(pid)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :total_allowed)
      assert Map.has_key?(metrics, :total_rejected)
      assert Map.has_key?(metrics, :active_keys)
      assert metrics.total_allowed >= 50
      GenServer.stop(pid)
    end
  end

  describe "window sliding behavior" do
    test "allows events again after window expires" do
      # Short window for testing
      {:ok, pid} = Backpressure.start_link(name: :test_bp_15, rate_limit: 5, window_ms: 100)

      # Fill up limit
      for _ <- 1..5, do: Backpressure.allow?(pid, "window-key")
      refute Backpressure.allow?(pid, "window-key")

      # Wait for window to expire
      Process.sleep(150)

      # Should be allowed again
      assert Backpressure.allow?(pid, "window-key")
      GenServer.stop(pid)
    end
  end

  describe "circuit breaker states" do
    test "transitions through closed -> open -> half-open -> closed" do
      {:ok, pid} =
        Backpressure.start_link(
          name: :test_bp_16,
          rate_limit: 5,
          window_ms: 100,
          recovery_time_ms: 50
        )

      # Start closed
      state1 = Backpressure.get_state(pid, "circuit-key")
      assert state1.circuit_state == :closed

      # Exceed limit -> open
      for _ <- 1..10, do: Backpressure.allow?(pid, "circuit-key")
      state2 = Backpressure.get_state(pid, "circuit-key")
      assert state2.circuit_state == :open

      # Wait for recovery -> half-open
      Process.sleep(60)
      state3 = Backpressure.get_state(pid, "circuit-key")
      assert state3.circuit_state in [:half_open, :closed]

      GenServer.stop(pid)
    end
  end

  describe "Backpressure.health/1" do
    test "returns health status" do
      {:ok, pid} = Backpressure.start_link(name: :test_bp_17)

      health = Backpressure.health(pid)

      assert health.status == :healthy
      assert is_integer(health.uptime_ms)
      GenServer.stop(pid)
    end
  end

  # Property tests
  test "property: rate limit is never exceeded within window" do
    test_cases = [10, 50, 100, 200]

    for {limit, idx} <- Enum.with_index(test_cases) do
      name = String.to_atom("test_bp_prop_#{idx}")
      {:ok, pid} = Backpressure.start_link(name: name, rate_limit: limit, window_ms: 1000)

      # Try to send 2x the limit
      results = for _ <- 1..(limit * 2), do: Backpressure.allow?(pid, "prop-key")

      allowed = Enum.count(results, & &1)
      GenServer.stop(pid)

      # Should never allow more than the rate limit
      assert allowed <= limit
    end
  end
end
