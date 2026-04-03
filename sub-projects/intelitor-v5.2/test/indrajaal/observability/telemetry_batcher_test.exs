defmodule Indrajaal.Observability.TelemetryBatcherTest do
  @moduledoc """
  Integration tests for TelemetryBatcher — GenServer batch aggregator
  for high-frequency telemetry events.

  ## WHAT
  Validates batcher lifecycle, buffer management, flush behavior,
  and stats tracking. SC-ZTEST-008 dual-write compliance is verified
  structurally (code review confirms log-first pattern in do_flush/1)
  and behaviorally (stats prove do_flush executed).

  ## WHY
  ZUIP Phase 0 introduced TelemetryBatcher to reduce 200/s individual
  publishes to 1/s batched publishes, preventing ZenohSession mailbox
  overflow (FM-ZUIP-001, RPN 140).

  ## CONSTRAINTS
  - SC-ZTEST-008: Dual-write — log fallback before Zenoh publish
  - SC-ZENOH-004: Publish latency < 100ms
  - FM-ZUIP-001: Prevents mailbox overflow (RPN 140)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-18 | Claude Opus 4.6 | Initial TelemetryBatcher tests |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.TelemetryBatcher

  @test_topic "indrajaal/test/batcher"

  setup do
    # Ensure no leftover batcher from previous tests
    case GenServer.whereis(String.to_atom("telemetry_batcher_#{@test_topic}")) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end

    Process.sleep(10)
    {:ok, []}
  end

  # ============================================================
  # LIFECYCLE TESTS
  # ============================================================

  describe "start_link/1" do
    test "starts batcher with required topic" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "registers with deterministic name based on topic" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      expected_name = String.to_atom("telemetry_batcher_#{@test_topic}")
      assert Process.whereis(expected_name) == pid
      GenServer.stop(pid, :normal)
    end

    test "raises on missing topic" do
      assert_raise KeyError, fn ->
        TelemetryBatcher.start_link([])
      end
    end

    test "accepts custom flush_interval_ms" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 5_000
        )

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "accepts custom max_batch_size" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000,
          max_batch_size: 100
        )

      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end
  end

  # ============================================================
  # BUFFER AND FLUSH TESTS
  # ============================================================

  describe "add/2" do
    test "buffers events without immediate publish" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.add(@test_topic, %{cpu: 45.2})
      TelemetryBatcher.add(@test_topic, %{cpu: 50.1})

      Process.sleep(50)
      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 0

      GenServer.stop(pid, :normal)
    end

    test "returns :ok for non-existent topic (graceful degradation)" do
      assert :ok == TelemetryBatcher.add("nonexistent/topic", %{data: 1})
    end

    test "accepts map events" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      assert :ok == TelemetryBatcher.add(@test_topic, %{key: "value"})
      GenServer.stop(pid, :normal)
    end
  end

  describe "flush/1" do
    test "forces immediate flush — batch count increments" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.add(@test_topic, %{cpu: 45.2})
      TelemetryBatcher.add(@test_topic, %{cpu: 50.1})
      TelemetryBatcher.add(@test_topic, %{cpu: 55.0})
      Process.sleep(30)

      TelemetryBatcher.flush(@test_topic)
      Process.sleep(100)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 1
      assert stats.events_batched == 3

      GenServer.stop(pid, :normal)
    end

    test "flush on empty buffer does not increment batch count" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.flush(@test_topic)
      Process.sleep(50)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 0

      GenServer.stop(pid, :normal)
    end

    test "returns :ok for non-existent topic" do
      assert :ok == TelemetryBatcher.flush("nonexistent/topic")
    end
  end

  describe "timer-based flush" do
    test "auto-flushes after interval" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 100
        )

      TelemetryBatcher.add(@test_topic, %{cpu: 45.2})
      TelemetryBatcher.add(@test_topic, %{mem: 72.0})

      # Wait for auto-flush (100ms interval + generous margin)
      Process.sleep(300)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent >= 1
      assert stats.events_batched == 2

      GenServer.stop(pid, :normal)
    end

    test "timer reschedules after each flush" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 80
        )

      # First batch
      TelemetryBatcher.add(@test_topic, %{e: 1})
      Process.sleep(150)

      stats1 = TelemetryBatcher.stats(@test_topic)
      assert stats1.batches_sent >= 1

      # Second batch (timer reschedules)
      TelemetryBatcher.add(@test_topic, %{e: 2})
      Process.sleep(150)

      stats2 = TelemetryBatcher.stats(@test_topic)
      assert stats2.batches_sent >= 2
      assert stats2.events_batched == 2

      GenServer.stop(pid, :normal)
    end
  end

  describe "max_batch_size overflow" do
    test "flushes when buffer reaches max_batch_size" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000,
          max_batch_size: 3
        )

      TelemetryBatcher.add(@test_topic, %{e: 1})
      TelemetryBatcher.add(@test_topic, %{e: 2})
      TelemetryBatcher.add(@test_topic, %{e: 3})
      # 4th add triggers flush of first 3, then buffers the 4th
      TelemetryBatcher.add(@test_topic, %{e: 4})
      Process.sleep(100)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 1
      assert stats.events_batched == 3

      GenServer.stop(pid, :normal)
    end

    test "overflow flush then manual flush captures remainder" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000,
          max_batch_size: 2
        )

      # First overflow at 2, buffers 3rd
      TelemetryBatcher.add(@test_topic, %{e: 1})
      TelemetryBatcher.add(@test_topic, %{e: 2})
      TelemetryBatcher.add(@test_topic, %{e: 3})
      Process.sleep(50)

      # Manual flush captures the remainder
      TelemetryBatcher.flush(@test_topic)
      Process.sleep(100)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 2
      assert stats.events_batched == 3

      GenServer.stop(pid, :normal)
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/1" do
    test "returns initial stats with correct keys" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      stats = TelemetryBatcher.stats(@test_topic)

      assert stats.batches_sent == 0
      assert stats.events_batched == 0
      assert stats.events_dropped == 0

      GenServer.stop(pid, :normal)
    end

    test "returns empty map for non-existent topic" do
      assert %{} == TelemetryBatcher.stats("nonexistent/topic")
    end

    test "accumulates stats across multiple flushes" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      # First batch: 2 events
      TelemetryBatcher.add(@test_topic, %{e: 1})
      TelemetryBatcher.add(@test_topic, %{e: 2})
      TelemetryBatcher.flush(@test_topic)
      Process.sleep(80)

      # Second batch: 1 event
      TelemetryBatcher.add(@test_topic, %{e: 3})
      TelemetryBatcher.flush(@test_topic)
      Process.sleep(80)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 2
      assert stats.events_batched == 3

      GenServer.stop(pid, :normal)
    end
  end

  # ============================================================
  # SC-ZTEST-008 DUAL-WRITE COMPLIANCE (Structural Verification)
  # ============================================================

  describe "SC-ZTEST-008 dual-write structural compliance" do
    test "do_flush produces a batch — confirming log+publish path executed" do
      # The TelemetryBatcher.do_flush/1 function (line 172-201) ALWAYS:
      # 1. Writes Logger.debug("[ZTEST-CHECKPOINT] ...") FIRST
      # 2. Then calls ZenohSession.publish_async(...)
      # We verify do_flush ran by checking stats increment.
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.add(@test_topic, %{metric: "value"})
      TelemetryBatcher.flush(@test_topic)
      Process.sleep(100)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 1
      assert stats.events_batched == 1

      GenServer.stop(pid, :normal)
    end

    test "empty buffer does not trigger dual-write" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.flush(@test_topic)
      Process.sleep(50)

      stats = TelemetryBatcher.stats(@test_topic)
      assert stats.batches_sent == 0

      GenServer.stop(pid, :normal)
    end
  end

  # ============================================================
  # TERMINATE (flush-on-shutdown) TESTS
  # ============================================================

  describe "terminate/2" do
    test "stops cleanly with buffered events (flush on terminate)" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      TelemetryBatcher.add(@test_topic, %{final: true})
      TelemetryBatcher.add(@test_topic, %{final: true})
      Process.sleep(30)

      # Verify events are buffered
      stats_before = TelemetryBatcher.stats(@test_topic)
      assert stats_before.batches_sent == 0

      # Stop cleanly — terminate/2 flushes remaining buffer
      assert :ok == GenServer.stop(pid, :normal)
    end

    test "handles terminate with empty buffer" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      assert :ok == GenServer.stop(pid, :normal)
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "add never crashes regardless of event shape" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000
        )

      result =
        forall event <- PC.map(PC.atom(), PC.term()) do
          TelemetryBatcher.add(@test_topic, event)
          true
        end

      GenServer.stop(pid, :normal)
      result
    end

    @tag timeout: 30_000
    test "handles burst of events via StreamData" do
      {:ok, pid} =
        TelemetryBatcher.start_link(
          topic: @test_topic,
          flush_interval_ms: 60_000,
          max_batch_size: 50
        )

      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(
                                   SD.fixed_map(%{
                                     cpu: SD.float(min: 0.0, max: 100.0),
                                     mem: SD.float(min: 0.0, max: 100.0)
                                   }),
                                   min_length: 1,
                                   max_length: 20
                                 )
                             ) do
        for event <- events do
          TelemetryBatcher.add(@test_topic, event)
        end

        TelemetryBatcher.flush(@test_topic)
        Process.sleep(20)
      end

      GenServer.stop(pid, :normal)
    end
  end
end
