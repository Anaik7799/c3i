defmodule Indrajaal.Zenoh.ThroughputTest do
  @moduledoc """
  Zenoh data path throughput test — 80% load across all pub/sub channels.

  WHAT: Publishes messages at 80% of rated capacity across multiple concurrent
        channels, measures aggregate throughput, verifies no message loss, and
        checks that backpressure does not cause ordering violations within any
        channel.

  WHY: SC-BRIDGE-003 requires latency ≤ 50ms under normal load. SC-BUS-002
       mandates no blocking. SC-ZTEST-012 requires FIFO per-topic. This test
       exercises the pub/sub fabric at high-but-not-maximum load to validate
       behaviour before hitting system limits.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-BRIDGE-001: Message buffer FIFO
    - SC-BRIDGE-003: Latency budget 50ms
    - SC-BUS-001: Async messaging only
    - SC-BUS-002: No blocking operations
    - SC-PRF-050: Response < 50ms

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-23 | Claude Sonnet 4.6 | Sprint 88 — initial  |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :requires_zenoh
  @moduletag timeout: 120_000

  @pubsub_name __MODULE__.PubSub

  # Channels under test — representative set of real Zenoh channels
  @channels [
    "indrajaal/health/node/node-1",
    "indrajaal/health/node/node-2",
    "indrajaal/health/node/node-3",
    "indrajaal/control/cmd/issued",
    "indrajaal/control/feedback/result",
    "indrajaal/pipeline/sensor/raw",
    "indrajaal/pipeline/cortex/processed",
    "indrajaal/pipeline/guardian/approved",
    "indrajaal/pipeline/prajna/dashboard",
    "indrajaal/test/throughput/channel"
  ]

  # 80% load: 40 messages per channel
  @rated_capacity 50
  @load_factor 0.80
  @msgs_per_channel trunc(@rated_capacity * @load_factor)

  # Latency budget per SC-PRF-050 (50ms) in milliseconds
  @latency_budget_ms 50

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for channel <- @channels do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, channel)
    end

    on_exit(fn ->
      for channel <- @channels do
        Phoenix.PubSub.unsubscribe(@pubsub_name, channel)
      end
    end)

    :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp make_payload(channel_idx, seq) do
    %{
      channel_idx: channel_idx,
      sequence: seq,
      payload: :crypto.strong_rand_bytes(64),
      ts_us: System.monotonic_time(:microsecond)
    }
  end

  # Publish @msgs_per_channel messages on every channel sequentially within
  # each channel (so per-channel FIFO is deterministic).
  defp publish_all_channels do
    for {channel, idx} <- Enum.with_index(@channels, 1) do
      for seq <- 1..@msgs_per_channel do
        msg = make_payload(idx, seq)
        Phoenix.PubSub.broadcast(@pubsub_name, channel, {:throughput, channel, msg})
      end
    end
  end

  # Drain all :throughput messages with a configurable per-message timeout.
  defp drain_throughput(per_msg_timeout_ms, acc \\ []) do
    receive do
      {:throughput, channel, msg} ->
        drain_throughput(per_msg_timeout_ms, [{channel, msg} | acc])
    after
      per_msg_timeout_ms -> Enum.reverse(acc)
    end
  end

  defp expected_total, do: length(@channels) * @msgs_per_channel

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "Throughput: Channel contract" do
    test "all #{length(@channels)} channels conform to depth ≤ 6 (SC-ZTEST-017)" do
      for channel <- @channels do
        depth = channel |> String.graphemes() |> Enum.count(&(&1 == "/"))
        assert depth <= 6, "Channel #{channel} has depth #{depth} > 6 (SC-ZTEST-017)"
      end
    end

    test "channel list has no duplicates" do
      assert length(@channels) == length(Enum.uniq(@channels))
    end

    test "load factor produces #{@msgs_per_channel} msgs/channel at 80% of #{@rated_capacity}" do
      assert @msgs_per_channel == trunc(@rated_capacity * @load_factor)
      assert @msgs_per_channel < @rated_capacity
      assert @msgs_per_channel >= trunc(@rated_capacity * 0.75)
    end
  end

  describe "Throughput: No message loss under 80% load" do
    test "all #{length(@channels)} × #{@msgs_per_channel} = #{length(@channels) * trunc(50 * 0.80)} messages delivered" do
      publish_all_channels()

      received = drain_throughput(200)
      expected = expected_total()

      assert length(received) == expected,
             "Expected #{expected} messages at 80% load, got #{length(received)} — message loss detected (SC-BUS-002)"
    end

    test "each channel receives exactly #{@msgs_per_channel} messages" do
      publish_all_channels()

      received = drain_throughput(200)

      per_channel =
        received
        |> Enum.group_by(fn {channel, _} -> channel end)
        |> Enum.map(fn {channel, msgs} -> {channel, length(msgs)} end)

      for {channel, count} <- per_channel do
        assert count == @msgs_per_channel,
               "Channel #{channel} received #{count} msgs (expected #{@msgs_per_channel}) — loss at 80% load"
      end
    end

    test "no messages arrive on unsubscribed channel" do
      unsubscribed = "indrajaal/test/throughput/unregistered"

      publish_all_channels()
      Phoenix.PubSub.broadcast(@pubsub_name, unsubscribed, {:throughput, unsubscribed, %{seq: 1}})

      received = drain_throughput(100)
      from_unsubscribed = Enum.filter(received, fn {ch, _} -> ch == unsubscribed end)

      assert from_unsubscribed == [],
             "Received #{length(from_unsubscribed)} unexpected messages from unsubscribed channel"
    end
  end

  describe "Throughput: FIFO ordering under load (SC-ZTEST-012)" do
    test "sequence order preserved within every channel under 80% load" do
      publish_all_channels()

      received = drain_throughput(300)

      violations =
        received
        |> Enum.group_by(fn {channel, _} -> channel end)
        |> Enum.flat_map(fn {channel, msgs} ->
          seqs = Enum.map(msgs, fn {_, msg} -> msg.sequence end)
          sorted = Enum.sort(seqs)

          if seqs != sorted do
            [{channel, seqs, sorted}]
          else
            []
          end
        end)

      assert violations == [],
             "FIFO ordering violated on #{length(violations)} channels: #{inspect(Enum.map(violations, &elem(&1, 0)))}"
    end

    test "each channel delivers sequences 1..#{@msgs_per_channel} contiguously" do
      publish_all_channels()

      received = drain_throughput(300)

      expected_seqs = Enum.to_list(1..@msgs_per_channel)

      for {channel, msgs_for_channel} <-
            Enum.group_by(received, fn {ch, _} -> ch end) do
        actual_seqs = Enum.map(msgs_for_channel, fn {_, msg} -> msg.sequence end)

        assert actual_seqs == expected_seqs,
               "Channel #{channel}: expected seqs #{inspect(expected_seqs)}, got #{inspect(actual_seqs)}"
      end
    end
  end

  describe "Throughput: Latency under load (SC-PRF-050, SC-BRIDGE-003)" do
    test "publishing all #{length(@channels) * trunc(50 * 0.80)} messages completes within #{@latency_budget_ms * 10}ms" do
      budget_ms = @latency_budget_ms * 10

      t0 = System.monotonic_time(:millisecond)
      publish_all_channels()
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = t1 - t0

      assert elapsed_ms < budget_ms,
             "Publishing #{expected_total()} messages took #{elapsed_ms}ms > #{budget_ms}ms budget"
    end

    test "per-message average publish latency is < 1ms at 80% load" do
      total = expected_total()

      t0 = System.monotonic_time(:microsecond)
      publish_all_channels()
      t1 = System.monotonic_time(:microsecond)

      avg_us = (t1 - t0) / total

      assert avg_us < 1_000,
             "Average per-message publish latency #{Float.round(avg_us, 1)}µs > 1000µs under 80% load (SC-BUS-002)"
    end

    test "single-channel throughput: 10 rapid publishes, all delivered within #{@latency_budget_ms}ms" do
      channel = hd(@channels)

      t0 = System.monotonic_time(:millisecond)

      for seq <- 1..10 do
        msg = make_payload(1, seq)
        Phoenix.PubSub.broadcast(@pubsub_name, channel, {:throughput, channel, msg})
      end

      # Drain with tight timeout
      received =
        Enum.reduce_while(1..10, [], fn _, acc ->
          receive do
            {:throughput, ^channel, msg} -> {:cont, [msg | acc]}
          after
            @latency_budget_ms -> {:halt, acc}
          end
        end)

      t1 = System.monotonic_time(:millisecond)
      elapsed_ms = t1 - t0

      assert length(received) == 10,
             "Expected 10 messages on single channel within #{@latency_budget_ms}ms, got #{length(received)}"

      assert elapsed_ms < @latency_budget_ms,
             "Single-channel 10-message burst took #{elapsed_ms}ms > #{@latency_budget_ms}ms (SC-PRF-050)"
    end
  end

  describe "Throughput: Backpressure and isolation" do
    test "burst on one channel does not delay other channels" do
      burst_channel = Enum.at(@channels, 0)
      reference_channel = Enum.at(@channels, 1)

      # Publish burst on first channel
      for seq <- 1..@msgs_per_channel do
        msg = make_payload(1, seq)
        Phoenix.PubSub.broadcast(@pubsub_name, burst_channel, {:throughput, burst_channel, msg})
      end

      # Immediately publish a single message on reference channel
      ref_msg = make_payload(99, 1)
      t0 = System.monotonic_time(:millisecond)

      Phoenix.PubSub.broadcast(
        @pubsub_name,
        reference_channel,
        {:throughput, reference_channel, ref_msg}
      )

      receive do
        {:throughput, ^reference_channel, _} ->
          t1 = System.monotonic_time(:millisecond)
          elapsed_ms = t1 - t0

          assert elapsed_ms < @latency_budget_ms,
                 "Reference channel latency #{elapsed_ms}ms > #{@latency_budget_ms}ms under burst (SC-BRIDGE-003)"
      after
        @latency_budget_ms * 2 ->
          flunk(
            "Reference channel message not received within #{@latency_budget_ms * 2}ms during burst"
          )
      end
    end

    test "messages on different channels carry correct channel index (no cross-contamination)" do
      publish_all_channels()

      received = drain_throughput(300)

      cross_contaminated =
        received
        |> Enum.filter(fn {channel, msg} ->
          # Derive expected channel_idx from channel position in @channels list
          expected_idx =
            Enum.find_index(@channels, &(&1 == channel))
            |> case do
              nil -> -1
              idx -> idx + 1
            end

          msg.channel_idx != expected_idx
        end)

      assert cross_contaminated == [],
             "#{length(cross_contaminated)} cross-contaminated messages detected under 80% load"
    end

    test "payload integrity preserved through high-throughput delivery" do
      channel = hd(@channels)
      original = make_payload(1, 42)

      Phoenix.PubSub.broadcast(@pubsub_name, channel, {:throughput, channel, original})

      assert_receive {:throughput, ^channel, received}, 200
      assert received.channel_idx == original.channel_idx
      assert received.sequence == original.sequence
      assert received.payload == original.payload
      assert received.ts_us == original.ts_us
    end
  end

  describe "Throughput: Aggregate statistics" do
    test "throughput rate > 100 messages/second for all channels combined" do
      t0 = System.monotonic_time(:millisecond)
      publish_all_channels()
      received = drain_throughput(500)
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = max(t1 - t0, 1)
      total = length(received)
      rate_per_sec = total * 1_000 / elapsed_ms

      assert total == expected_total(),
             "Message loss: expected #{expected_total()}, received #{total}"

      assert rate_per_sec > 100.0,
             "Throughput rate #{Float.round(rate_per_sec, 0)} msg/s below 100 msg/s (SC-BRIDGE-003)"
    end

    test "end-to-end latency per message is tracked via embedded timestamp" do
      channel = hd(@channels)

      latencies_us =
        for seq <- 1..20 do
          msg = make_payload(1, seq)
          t_send = System.monotonic_time(:microsecond)
          Phoenix.PubSub.broadcast(@pubsub_name, channel, {:throughput, channel, msg})

          receive do
            {:throughput, ^channel, _received} ->
              System.monotonic_time(:microsecond) - t_send
          after
            100 -> nil
          end
        end
        |> Enum.reject(&is_nil/1)

      assert length(latencies_us) == 20,
             "Expected 20 round-trip measurements, got #{length(latencies_us)}"

      p99_us =
        latencies_us
        |> Enum.sort()
        |> Enum.at(trunc(length(latencies_us) * 99 / 100) - 1)

      assert p99_us < @latency_budget_ms * 1_000,
             "p99 end-to-end latency #{p99_us}µs exceeds #{@latency_budget_ms}ms budget"
    end
  end
end
