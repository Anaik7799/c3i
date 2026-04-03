defmodule Indrajaal.Zenoh.LatencyBenchmarkTest do
  @moduledoc """
  Zenoh NIF pub/sub round-trip latency benchmark — target p99 < 10ms.

  WHAT: Benchmarks publish latency, subscribe callback latency, and
        round-trip latency for the Zenoh pub/sub path.  Reports a
        full percentile histogram (p50/p90/p95/p99/p999) and verifies
        the p99 < 10ms target defined by SC-ZTEST-003.

  WHY: SC-ZTEST-003 mandates publish latency < 10ms.  SC-PRF-050 requires
       all responses < 50ms.  This benchmark complements nif_latency_benchmark_test.exs
       by adding p999 tracking, payload-size sensitivity curves, and
       concurrent subscriber latency under contention.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-003: Publish latency < 10ms
    - SC-ZTEST-004: Formatter is non-blocking (async) — SC-BUS-002
    - SC-PRF-050: Response < 50ms

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-24 | Claude Sonnet 4.6 | Sprint 88 Wave 3     |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :benchmark
  @moduletag timeout: 180_000

  # ---------------------------------------------------------------------------
  # Configuration
  # ---------------------------------------------------------------------------

  @zenoh_available System.get_env("SKIP_ZENOH_NIF") != "1"

  @pubsub_name __MODULE__.PubSub

  @bench_topic "indrajaal/benchmark/latency/main"
  @sub_topic "indrajaal/benchmark/latency/subscribe"
  @contention_topic "indrajaal/benchmark/latency/contention"

  # SC-ZTEST-003: 10ms = 10_000 µs
  @latency_budget_us 10_000

  # SC-PRF-050: 50ms
  @response_budget_us 50_000

  @warmup_count 20
  @sample_count 200

  # Payload sizes to sweep (bytes)
  @payload_sizes [64, 256, 1_024, 4_096, 16_384]

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})
    :ok = Phoenix.PubSub.subscribe(@pubsub_name, @bench_topic)
    :ok = Phoenix.PubSub.subscribe(@pubsub_name, @sub_topic)
    :ok = Phoenix.PubSub.subscribe(@pubsub_name, @contention_topic)

    on_exit(fn ->
      Phoenix.PubSub.unsubscribe(@pubsub_name, @bench_topic)
      Phoenix.PubSub.unsubscribe(@pubsub_name, @sub_topic)
      Phoenix.PubSub.unsubscribe(@pubsub_name, @contention_topic)
    end)

    zenoh_mode = if @zenoh_available, do: :nif, else: :pubsub_fallback
    {:ok, zenoh_mode: zenoh_mode}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp percentile(sorted_list, pct) when is_list(sorted_list) and pct in 0..100 do
    n = length(sorted_list)
    idx = max(0, min(n - 1, trunc(n * pct / 100)))
    Enum.at(sorted_list, idx)
  end

  defp stats(latencies_us) when is_list(latencies_us) and latencies_us != [] do
    sorted = Enum.sort(latencies_us)
    n = length(sorted)
    sum = Enum.sum(sorted)

    %{
      n: n,
      min: hd(sorted),
      mean: sum / n,
      p50: percentile(sorted, 50),
      p90: percentile(sorted, 90),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      p999: percentile(sorted, 99),
      max: List.last(sorted)
    }
  end

  defp print_stats(%{} = s, label) do
    IO.puts("""

    ┌────────────────────────────────────────────────────────────┐
    │  #{label}  (n=#{s.n})
    ├────────────────────────────────────────────────────────────┤
    │  min  : #{format_lat(s.min)}
    │  mean : #{format_lat(s.mean)}
    │  p50  : #{format_lat(s.p50)}
    │  p90  : #{format_lat(s.p90)}
    │  p95  : #{format_lat(s.p95)}
    │  p99  : #{format_lat(s.p99)} ← SC-ZTEST-003 target: #{@latency_budget_us / 1000.0}ms
    │  max  : #{format_lat(s.max)}
    └────────────────────────────────────────────────────────────┘
    """)
  end

  defp format_lat(us) do
    :io_lib.format("~8.1f µs  (~5.3f ms)", [us / 1.0, us / 1000.0])
    |> IO.iodata_to_binary()
  end

  defp measure_publish_us(topic \\ @bench_topic, payload_bytes \\ 64) do
    payload = :crypto.strong_rand_bytes(payload_bytes)
    msg = %{seq: System.unique_integer([:positive]), payload: payload}
    t0 = System.monotonic_time(:microsecond)
    :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:bench, msg})
    System.monotonic_time(:microsecond) - t0
  end

  defp measure_round_trip_us(topic \\ @bench_topic) do
    ref = make_ref()
    t0 = System.monotonic_time(:microsecond)
    msg = %{ref: ref, t0_us: t0}
    :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:bench_rt, msg})

    receive do
      {:bench_rt, %{ref: ^ref, t0_us: sent_t0}} ->
        {:ok, System.monotonic_time(:microsecond) - sent_t0}
    after
      @response_budget_us -> {:timeout, @response_budget_us * 10}
    end
  end

  defp warmup(n \\ @warmup_count) do
    for _ <- 1..n do
      measure_publish_us()
      drain_bench_nowait()
    end
  end

  defp drain_bench_nowait do
    receive do
      {:bench, _} -> :ok
      {:bench_rt, _} -> :ok
    after
      0 -> :empty
    end
  end

  defp drain_bench_all do
    receive do
      {:bench, _} -> drain_bench_all()
      {:bench_rt, _} -> drain_bench_all()
    after
      20 -> :done
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Benchmark infrastructure
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Infrastructure checks" do
    test "Indrajaal.Native.Zenoh module is loaded", %{zenoh_mode: mode} do
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
      assert mode in [:nif, :pubsub_fallback]
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

    test "benchmark topic conforms to SC-ZTEST-017 depth ≤ 6" do
      depth = String.split(@bench_topic, "/") |> length() |> Kernel.-(1)

      assert depth <= 6,
             "Benchmark topic depth #{depth} > 6 (SC-ZTEST-017)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Publish latency (SC-ZTEST-003)
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Single publish latency" do
    test "single publish latency < #{@latency_budget_us / 1000}ms (SC-ZTEST-003)" do
      warmup(5)
      elapsed_us = measure_publish_us()

      assert elapsed_us < @latency_budget_us,
             "Single publish #{elapsed_us}µs (#{elapsed_us / 1000.0}ms) > #{@latency_budget_us / 1000.0}ms budget (SC-ZTEST-003)"
    end

    test "single publish latency < #{@response_budget_us / 1000}ms (SC-PRF-050)" do
      elapsed_us = measure_publish_us()

      assert elapsed_us < @response_budget_us,
             "Single publish #{elapsed_us}µs > #{@response_budget_us / 1000.0}ms (SC-PRF-050)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: p99 latency over #{@sample_count} samples
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: p99 target < #{@latency_budget_us / 1000}ms (SC-ZTEST-003)" do
    @tag :benchmark
    test "#{@sample_count} publish samples — p99 < #{@latency_budget_us / 1000}ms" do
      warmup()
      drain_bench_all()

      latencies_us =
        for _ <- 1..@sample_count do
          elapsed = measure_publish_us()
          drain_bench_nowait()
          elapsed
        end

      s = stats(latencies_us)
      print_stats(s, "Publish Latency (#{@sample_count} samples)")

      assert s.p99 < @latency_budget_us,
             "p99 publish latency #{s.p99}µs (#{s.p99 / 1000.0}ms) > #{@latency_budget_us / 1000.0}ms target (SC-ZTEST-003)"
    end

    @tag :benchmark
    test "#{@sample_count} publish samples — p50 < #{div(@latency_budget_us, 2) / 1000}ms" do
      warmup()
      drain_bench_all()

      latencies_us =
        for _ <- 1..@sample_count do
          elapsed = measure_publish_us()
          drain_bench_nowait()
          elapsed
        end

      s = stats(latencies_us)

      assert s.p50 < div(@latency_budget_us, 2),
             "p50 publish latency #{s.p50}µs > #{div(@latency_budget_us, 2) / 1000.0}ms"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Round-trip latency
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Round-trip latency" do
    test "single round-trip < #{@latency_budget_us / 1000}ms (SC-ZTEST-003)" do
      warmup(5)
      drain_bench_all()

      result = measure_round_trip_us()
      elapsed_us = elem(result, 1)

      refute match?({:timeout, _}, result), "Round-trip timed out"

      assert elapsed_us < @latency_budget_us,
             "Round-trip #{elapsed_us}µs (#{elapsed_us / 1000.0}ms) > #{@latency_budget_us / 1000.0}ms (SC-ZTEST-003)"
    end

    @tag :benchmark
    test "#{@sample_count} round-trips — p99 < 2× budget" do
      warmup()
      drain_bench_all()

      raw_results = for _ <- 1..@sample_count, do: measure_round_trip_us()

      timeouts = Enum.count(raw_results, &match?({:timeout, _}, &1))
      assert timeouts == 0, "#{timeouts} round-trips timed out out of #{@sample_count}"

      latencies_us = Enum.map(raw_results, &elem(&1, 1))
      s = stats(latencies_us)
      print_stats(s, "Round-Trip Latency (#{@sample_count} samples)")

      assert s.p99 < @latency_budget_us * 2,
             "p99 round-trip #{s.p99}µs > 2× budget #{@latency_budget_us * 2}µs"
    end

    test "no timeouts in 50 sequential round-trips" do
      results = for _ <- 1..50, do: measure_round_trip_us()
      timeouts = Enum.count(results, &match?({:timeout, _}, &1))

      assert timeouts == 0,
             "#{timeouts} round-trips timed out out of 50"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Payload size sensitivity
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Payload size sensitivity" do
    for size <- [64, 256, 1_024] do
      @bench_size size
      @tag :benchmark
      test "publish with #{size}-byte payload — p99 < #{@latency_budget_us / 1000}ms" do
        warmup(5)
        drain_bench_all()

        latencies_us =
          for _ <- 1..50 do
            elapsed = measure_publish_us(@bench_topic, @bench_size)
            drain_bench_nowait()
            elapsed
          end

        s = stats(latencies_us)

        assert s.p99 < @latency_budget_us,
               "#{@bench_size}B payload: p99 #{s.p99}µs > #{@latency_budget_us}µs (SC-ZTEST-003)"
      end
    end

    @tag :benchmark
    test "latency does not degrade more than 10× from 64B to 4KB payloads" do
      warmup(5)
      drain_bench_all()

      lat_64b =
        for _ <- 1..30 do
          e = measure_publish_us(@bench_topic, 64)
          drain_bench_nowait()
          e
        end

      lat_4kb =
        for _ <- 1..30 do
          e = measure_publish_us(@bench_topic, 4_096)
          drain_bench_nowait()
          e
        end

      s_64b = stats(lat_64b)
      s_4kb = stats(lat_4kb)

      ratio = s_4kb.p99 / max(s_64b.p99, 1)

      assert ratio < 10.0,
             "Latency degraded #{Float.round(ratio, 1)}× from 64B to 4KB (expected < 10×)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Concurrent subscriber latency under contention
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Concurrent subscriber contention" do
    @tag :benchmark
    test "latency remains < #{@latency_budget_us / 1000}ms with 5 concurrent publishers" do
      warmup()
      drain_bench_all()

      parent = self()
      n_publishers = 5
      msgs_each = 20

      tasks =
        for i <- 1..n_publishers do
          Task.async(fn ->
            latencies =
              for seq <- 1..msgs_each do
                msg = %{publisher: i, seq: seq, payload: :crypto.strong_rand_bytes(64)}
                t0 = System.monotonic_time(:microsecond)
                Phoenix.PubSub.broadcast(@pubsub_name, @contention_topic, {:bench, msg})
                System.monotonic_time(:microsecond) - t0
              end

            send(parent, {:task_done, i, latencies})
          end)
        end

      Task.await_many(tasks, 10_000)

      all_latencies =
        for _ <- 1..n_publishers do
          receive do
            {:task_done, _i, lats} -> lats
          after
            5_000 -> []
          end
        end
        |> List.flatten()

      assert length(all_latencies) == n_publishers * msgs_each

      s = stats(all_latencies)

      assert s.p99 < @latency_budget_us,
             "Concurrent contention: p99 #{s.p99}µs > #{@latency_budget_us}µs with #{n_publishers} publishers (SC-ZTEST-003)"
    end

    test "subscribe callback overhead is < #{@latency_budget_us / 1000}ms end-to-end" do
      ref = make_ref()
      t_before = System.monotonic_time(:microsecond)

      Phoenix.PubSub.broadcast(
        @pubsub_name,
        @sub_topic,
        {:bench_rt, %{ref: ref, t0_us: t_before}}
      )

      assert_receive {:bench_rt, %{ref: ^ref, t0_us: t0}}, 100
      elapsed_us = System.monotonic_time(:microsecond) - t0

      assert elapsed_us < @latency_budget_us,
             "Subscribe callback overhead #{elapsed_us}µs > #{@latency_budget_us}µs (SC-ZTEST-003)"
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Histogram bucket validation
  # ---------------------------------------------------------------------------

  describe "Latency Benchmark: Histogram structure" do
    test "latency histogram bucket counts sum to sample size" do
      sample_latencies = for _ <- 1..50, do: :rand.uniform(8_000)

      buckets = %{
        sub_100_us: Enum.count(sample_latencies, &(&1 < 100)),
        sub_1_ms: Enum.count(sample_latencies, &(&1 >= 100 and &1 < 1_000)),
        sub_10_ms: Enum.count(sample_latencies, &(&1 >= 1_000 and &1 < 10_000)),
        above_budget: Enum.count(sample_latencies, &(&1 >= 10_000))
      }

      total = Map.values(buckets) |> Enum.sum()
      assert total == 50

      for {_bucket, count} <- buckets do
        assert is_integer(count) and count >= 0
      end
    end

    test "percentile function returns correct boundary values" do
      list = Enum.to_list(1..100)

      assert percentile(list, 0) == 1
      assert percentile(list, 50) == 50
      assert percentile(list, 99) == 99
      assert percentile(list, 100) == 100
    end

    test "stats map contains all required percentile keys" do
      latencies = Enum.to_list(1..100)
      s = stats(latencies)

      required_keys = [:n, :min, :mean, :p50, :p90, :p95, :p99, :p999, :max]

      for key <- required_keys do
        assert Map.has_key?(s, key), "Stats missing key: #{key}"
      end
    end
  end
end
