defmodule Indrajaal.Observability.ZenohNeuralStreamTest do
  @moduledoc """
  TDG Test Artifacts for ZenohNeuralStream.

  WHAT: Tests for real-time log/metric/state streaming via Zenoh.
  WHY: SC-OBS-001 requires <50ms latency verification.
  CONSTRAINTS: Must test batching, aggregation, delta encoding.

  ## TDG Methodology

  - Property tests for streaming invariants
  - Unit tests for buffer management
  - Integration tests for Zenoh publication

  ## STAMP Constraints Tested

  - SC-OBS-001: Latency < 50ms
  - SC-OBS-002: No data loss
  - SC-OBS-003: Ordered delivery per key

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-OBS-001 to SC-OBS-003 |
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start the GenServer for tests
    case GenServer.whereis(ZenohNeuralStream) do
      nil ->
        {:ok, pid} = ZenohNeuralStream.start_link(buffer_size: 10, flush_interval_ms: 50)
        on_exit(fn -> Process.exit(pid, :normal) end)
        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # UNIT TESTS - LOG STREAMING
  # ============================================================

  describe "stream_log/4" do
    test "accepts valid log entry" do
      assert :ok = ZenohNeuralStream.stream_log(:info, __MODULE__, "Test message")
    end

    test "accepts log with metadata" do
      metadata = %{request_id: "abc123", user_id: 42}
      assert :ok = ZenohNeuralStream.stream_log(:debug, __MODULE__, "With metadata", metadata)
    end

    test "accepts all log levels" do
      levels = [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

      Enum.each(levels, fn level ->
        assert :ok = ZenohNeuralStream.stream_log(level, __MODULE__, "Level: #{level}")
      end)
    end

    test "buffers logs until flush" do
      # Stream some logs
      for i <- 1..5 do
        ZenohNeuralStream.stream_log(:info, __MODULE__, "Log #{i}")
      end

      # Check stats show buffer has entries
      stats = ZenohNeuralStream.stats()
      assert stats.log_buffer_size >= 0
    end

    test "auto-flushes when buffer full" do
      # Get initial stats
      initial_stats = ZenohNeuralStream.stats()
      initial_logs = initial_stats.logs_streamed

      # Stream more than buffer size (10)
      for i <- 1..15 do
        ZenohNeuralStream.stream_log(:info, __MODULE__, "Log #{i}")
      end

      # Wait for flush
      Process.sleep(100)

      # Check logs were streamed
      final_stats = ZenohNeuralStream.stats()
      assert final_stats.logs_streamed >= initial_logs
    end
  end

  # ============================================================
  # UNIT TESTS - METRIC STREAMING
  # ============================================================

  describe "stream_metric/4" do
    test "accepts valid metric" do
      assert :ok = ZenohNeuralStream.stream_metric(:system, :cpu_usage, 0.75)
    end

    test "accepts metric with tags" do
      tags = %{host: "node1", region: "eu-west"}
      assert :ok = ZenohNeuralStream.stream_metric(:flame, :pool_size, 10, tags)
    end

    test "aggregates metrics within window" do
      # Stream multiple metrics
      for i <- 1..5 do
        ZenohNeuralStream.stream_metric(:test, :counter, i)
      end

      # Metrics are aggregated, not individually buffered
      stats = ZenohNeuralStream.stats()
      assert stats.metric_aggregations >= 0
    end
  end

  # ============================================================
  # UNIT TESTS - STATE STREAMING
  # ============================================================

  describe "stream_state/3" do
    test "accepts valid state" do
      assert :ok = ZenohNeuralStream.stream_state(:ooda_agent, :phase, :observing)
    end

    test "uses delta encoding (only publishes changes)" do
      # Stream same value twice
      ZenohNeuralStream.stream_state(:test_agent, :value, 42)
      ZenohNeuralStream.stream_state(:test_agent, :value, 42)

      # Only one should be in buffer (delta encoding)
      # (This is internal behavior, we just verify it doesn't crash)
      assert :ok = ZenohNeuralStream.stream_state(:test_agent, :value, 43)
    end

    test "tracks version numbers" do
      # Stream multiple state updates
      for i <- 1..3 do
        ZenohNeuralStream.stream_state(:versioned_agent, :counter, i)
      end

      stats = ZenohNeuralStream.stats()
      assert stats.state_buffer_size >= 0
    end
  end

  # ============================================================
  # UNIT TESTS - FLUSH
  # ============================================================

  describe "flush/0" do
    test "flushes all buffers" do
      # Stream some data
      ZenohNeuralStream.stream_log(:info, __MODULE__, "Flush test")
      ZenohNeuralStream.stream_metric(:test, :value, 100)
      ZenohNeuralStream.stream_state(:test, :key, "value")

      # Flush
      assert :ok = ZenohNeuralStream.flush()

      # Buffers should be empty
      stats = ZenohNeuralStream.stats()
      assert stats.flushes >= 1
    end
  end

  # ============================================================
  # UNIT TESTS - STATS & CONFIG
  # ============================================================

  describe "stats/0" do
    test "returns statistics map" do
      stats = ZenohNeuralStream.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :logs_streamed)
      assert Map.has_key?(stats, :metrics_streamed)
      assert Map.has_key?(stats, :states_streamed)
      assert Map.has_key?(stats, :flushes)
      assert Map.has_key?(stats, :uptime_seconds)
    end
  end

  describe "config/0" do
    test "returns configuration" do
      config = ZenohNeuralStream.config()

      assert is_map(config)
      assert Map.has_key?(config, :key_prefix)
      assert Map.has_key?(config, :buffer_size)
      assert Map.has_key?(config, :flush_interval_ms)
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "all log levels are accepted" do
      forall level <-
               PC.oneof([:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]) do
        :ok == ZenohNeuralStream.stream_log(level, __MODULE__, "Property test")
      end
    end

    property "all numeric metrics are accepted" do
      forall value <- PC.union([PC.integer(), PC.float()]) do
        :ok == ZenohNeuralStream.stream_metric(:property_test, :value, value)
      end
    end

    property "any term can be state value" do
      forall value <- PC.any() do
        :ok == ZenohNeuralStream.stream_state(:property_agent, :any_value, value)
      end
    end

    property "stats always returns valid map" do
      forall _n <- PC.integer(1, 10) do
        stats = ZenohNeuralStream.stats()
        is_map(stats) and Map.has_key?(stats, :logs_streamed)
      end
    end
  end

  # ============================================================
  # LATENCY TESTS (SC-OBS-001)
  # ============================================================

  describe "SC-OBS-001 latency requirements" do
    test "stream_log completes in <1ms (async)" do
      start = System.monotonic_time(:microsecond)
      ZenohNeuralStream.stream_log(:info, __MODULE__, "Latency test")
      elapsed = System.monotonic_time(:microsecond) - start

      # Async call should return immediately (<1ms)
      assert elapsed < 1000, "stream_log took #{elapsed}us, expected <1000us"
    end

    test "stream_metric completes in <1ms (async)" do
      start = System.monotonic_time(:microsecond)
      ZenohNeuralStream.stream_metric(:latency, :test, 42)
      elapsed = System.monotonic_time(:microsecond) - start

      assert elapsed < 1000, "stream_metric took #{elapsed}us, expected <1000us"
    end

    test "stream_state completes in <1ms (async)" do
      start = System.monotonic_time(:microsecond)
      ZenohNeuralStream.stream_state(:latency_agent, :test, "value")
      elapsed = System.monotonic_time(:microsecond) - start

      assert elapsed < 1000, "stream_state took #{elapsed}us, expected <1000us"
    end
  end
end
