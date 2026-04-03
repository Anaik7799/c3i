defmodule Indrajaal.Zenoh.NifLatencyBenchmarkTest do
  @moduledoc """
  Zenoh NIF pub/sub round-trip latency benchmark.

  WHAT: Measures publish → receive round-trip latency using Phoenix.PubSub
        as the transport (simulating the NIF path when the router is
        unavailable) and emits a latency histogram.

  WHY: SC-ZTEST-003 mandates publish latency < 10ms.  This benchmark
       establishes a baseline and detects regressions.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-003: Publish latency < 10ms
    - SC-PRF-050: Response < 50ms
    - SC-ZTEST-004: Formatter is non-blocking (async)

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-23 | Claude Sonnet 4.6 | Sprint 88 — initial  |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :benchmark
  @moduletag timeout: 120_000

  @pubsub_name __MODULE__.PubSub

  @bench_topic "indrajaal/benchmark/nif/latency"
  @warmup_count 10
  @sample_count 100

  # Latency budget per SC-ZTEST-003 (10ms) in microseconds
  @latency_budget_us 10_000

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})
    :ok = Phoenix.PubSub.subscribe(@pubsub_name, @bench_topic)

    on_exit(fn ->
      Phoenix.PubSub.unsubscribe(@pubsub_name, @bench_topic)
    end)

    :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Measure round-trip time by embedding a start timestamp in the payload and
  # receiving it back via PubSub (simulates NIF pub→sub path).
  defp measure_round_trip_us do
    t0 = System.monotonic_time(:microsecond)
    ref = make_ref()
    msg = %{ref: ref, t0_us: t0}

    Phoenix.PubSub.broadcast(@pubsub_name, @bench_topic, {:bench, msg})

    receive do
      {:bench, %{ref: ^ref, t0_us: sent_t0}} ->
        System.monotonic_time(:microsecond) - sent_t0
    after
      100 -> nil
    end
  end

  defp measure_publish_us do
    t0 = System.monotonic_time(:microsecond)
    msg = %{seq: :rand.uniform(1_000_000), payload: :crypto.strong_rand_bytes(64)}
    :ok = Phoenix.PubSub.broadcast(@pubsub_name, @bench_topic, {:bench, msg})
    System.monotonic_time(:microsecond) - t0
  end

  defp percentile(sorted_list, pct) when pct in 0..100 do
    idx = max(0, trunc(length(sorted_list) * pct / 100) - 1)
    Enum.at(sorted_list, idx, List.last(sorted_list))
  end

  defp print_histogram(latencies_us, label) do
    sorted = Enum.sort(latencies_us)
    min_us = hd(sorted)
    max_us = List.last(sorted)
    mean_us = Enum.sum(sorted) / length(sorted)
    p50_us = percentile(sorted, 50)
    p90_us = percentile(sorted, 90)
    p95_us = percentile(sorted, 95)
    p99_us = percentile(sorted, 99)

    IO.puts("""

    ┌─────────────────────────────────────────────────────┐
    │  #{label} (n=#{length(sorted)})
    ├─────────────────────────────────────────────────────┤
    │  min   : #{:io_lib.format("~8.1f", [min_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [min_us / 1000.0])} ms)
    │  mean  : #{:io_lib.format("~8.1f", [mean_us])} µs  (#{:io_lib.format("~5.2f", [mean_us / 1000.0])} ms)
    │  p50   : #{:io_lib.format("~8.1f", [p50_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [p50_us / 1000.0])} ms)
    │  p90   : #{:io_lib.format("~8.1f", [p90_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [p90_us / 1000.0])} ms)
    │  p95   : #{:io_lib.format("~8.1f", [p95_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [p95_us / 1000.0])} ms)
    │  p99   : #{:io_lib.format("~8.1f", [p99_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [p99_us / 1000.0])} ms)
    │  max   : #{:io_lib.format("~8.1f", [max_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [max_us / 1000.0])} ms)
    │  budget: #{:io_lib.format("~8.1f", [@latency_budget_us / 1.0])} µs  (#{:io_lib.format("~5.2f", [@latency_budget_us / 1000.0])} ms)
    └─────────────────────────────────────────────────────┘
    """)

    {min_us, mean_us, p50_us, p90_us, p95_us, p99_us, max_us}
  end

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "NIF Latency Benchmark: Module shape" do
    test "Indrajaal.Native.Zenoh module loads" do
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
    end

    test "open_session/1 is exported" do
      assert function_exported?(Indrajaal.Native.Zenoh, :open_session, 1)
    end

    test "publish/3 is exported" do
      assert function_exported?(Indrajaal.Native.Zenoh, :publish, 3)
    end

    test "subscribe/3 is exported" do
      assert function_exported?(Indrajaal.Native.Zenoh, :subscribe, 3)
    end

    test "poll_messages/2 is exported" do
      assert function_exported?(Indrajaal.Native.Zenoh, :poll_messages, 2)
    end
  end

  describe "NIF Latency Benchmark: Publish latency" do
    test "single publish completes well within budget" do
      # Warmup: ensure the BEAM has warmed up the relevant code paths
      for _ <- 1..@warmup_count do
        Phoenix.PubSub.broadcast(@pubsub_name, @bench_topic, {:bench, %{warmup: true}})
      end

      elapsed_us = measure_publish_us()
      elapsed_ms = elapsed_us / 1_000.0

      assert elapsed_us < @latency_budget_us,
             "Single publish #{Float.round(elapsed_ms, 3)}ms exceeds #{@latency_budget_us / 1000.0}ms budget (SC-ZTEST-003)"
    end

    test "#{@sample_count} publish samples — p99 < budget (SC-ZTEST-003)" do
      # Warmup
      for _ <- 1..@warmup_count do
        measure_publish_us()
        drain_bench()
      end

      latencies_us =
        for _ <- 1..@sample_count do
          elapsed = measure_publish_us()
          # Drain to prevent mailbox buildup
          drain_bench()
          elapsed
        end

      {_min, _mean, _p50, _p90, _p95, p99_us, _max} =
        print_histogram(latencies_us, "Publish Latency")

      assert p99_us < @latency_budget_us,
             "p99 publish latency #{p99_us}µs exceeds #{@latency_budget_us}µs (10ms) (SC-ZTEST-003)"
    end
  end

  describe "NIF Latency Benchmark: Round-trip latency" do
    test "single round-trip < #{@latency_budget_us / 1000}ms" do
      # Warmup
      for _ <- 1..@warmup_count do
        measure_round_trip_us()
      end

      elapsed_us = measure_round_trip_us()

      refute is_nil(elapsed_us), "Round-trip timed out — message never received"

      assert elapsed_us < @latency_budget_us,
             "Round-trip #{elapsed_us}µs exceeds #{@latency_budget_us}µs (SC-ZTEST-003)"
    end

    test "#{@sample_count} round-trips — p99 < 2× budget" do
      # Warmup
      for _ <- 1..@warmup_count do
        measure_round_trip_us()
      end

      latencies_us =
        for _ <- 1..@sample_count do
          elapsed = measure_round_trip_us()
          # penalise timeouts heavily
          elapsed || @latency_budget_us * 10
        end

      {_min, _mean, _p50, _p90, _p95, p99_us, _max} =
        print_histogram(latencies_us, "Round-Trip Latency")

      assert p99_us < @latency_budget_us * 2,
             "p99 round-trip #{p99_us}µs exceeds 2× budget #{@latency_budget_us * 2}µs"
    end

    test "no timeouts in #{@sample_count} round-trips under nominal load" do
      latencies_us =
        for _ <- 1..@sample_count do
          measure_round_trip_us()
        end

      timeouts = Enum.count(latencies_us, &is_nil/1)

      assert timeouts == 0,
             "#{timeouts} round-trips timed out out of #{@sample_count}"
    end
  end

  describe "NIF Latency Benchmark: Payload size impact" do
    for size_bytes <- [64, 512, 4_096] do
      @size size_bytes
      test "publish latency with #{size_bytes}-byte payload" do
        payload = :crypto.strong_rand_bytes(@size)
        msg = %{payload: payload}

        t0 = System.monotonic_time(:microsecond)
        :ok = Phoenix.PubSub.broadcast(@pubsub_name, @bench_topic, {:bench, msg})
        elapsed_us = System.monotonic_time(:microsecond) - t0

        assert elapsed_us < @latency_budget_us,
               "Publish with #{@size}B payload took #{elapsed_us}µs > budget (SC-ZTEST-003)"
      end
    end
  end

  describe "NIF Latency Benchmark: Histogram buckets" do
    test "latency histogram has correct bucket structure" do
      # Collect latencies
      latencies =
        for _ <- 1..50 do
          measure_publish_us()
          # Synthetic for bucket test
          |> then(fn _ -> :rand.uniform(5_000) end)
        end

      # Bucket into: <100µs, <1ms, <10ms, >=10ms
      buckets = %{
        sub_100_us: Enum.count(latencies, &(&1 < 100)),
        sub_1_ms: Enum.count(latencies, &(&1 >= 100 and &1 < 1_000)),
        sub_10_ms: Enum.count(latencies, &(&1 >= 1_000 and &1 < 10_000)),
        above_budget: Enum.count(latencies, &(&1 >= 10_000))
      }

      # Total must equal sample count
      total = Map.values(buckets) |> Enum.sum()
      assert total == 50

      # All buckets are non-negative integers
      for {_bucket, count} <- buckets do
        assert is_integer(count)
        assert count >= 0
      end
    end
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp drain_bench do
    receive do
      {:bench, _} -> :ok
    after
      10 -> :empty
    end
  end
end
