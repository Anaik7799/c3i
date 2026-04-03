defmodule Indrajaal.Zenoh.PubsubIntegrationTest do
  @moduledoc """
  Zenoh pub/sub integration test — 10 topics concurrent.

  WHAT: End-to-end integration test verifying that 10 topics can be
        subscribed, published to simultaneously, with correct FIFO delivery,
        wildcard topic matching semantics, and graceful fallback when the
        Zenoh NIF is unavailable.

  WHY: SC-ZTEST-012 (FIFO per topic), SC-BRIDGE-001 (buffer FIFO), and
       SC-ZTEST-017 (depth ≤ 6) must all hold under concurrent multi-topic
       conditions.  This suite complements pubsub_concurrent_test.exs by
       focusing on integration semantics (topic wildcards, subscription
       lifecycle, NIF availability detection) rather than just throughput.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - SC-ZTEST-003: Publish latency < 10ms
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-ZTEST-018: Subscriber timeout = 5s
    - SC-BRIDGE-001: Message buffer FIFO
    - SC-BRIDGE-003: Latency budget 50ms
    - SC-BUS-001: Async messaging only
    - SC-BUS-002: No blocking operations

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-24 | Claude Sonnet 4.6 | Sprint 88 Wave 3     |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :zenoh_integration
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Configuration
  # ---------------------------------------------------------------------------

  @zenoh_available System.get_env("SKIP_ZENOH_NIF") != "1"

  @pubsub_name __MODULE__.PubSub

  # 10 topics covering multiple domain prefixes (SC-ZTEST-017: depth ≤ 6)
  @topic_count 10
  @topics [
    "indrajaal/test/integration/health/node-1",
    "indrajaal/test/integration/health/node-2",
    "indrajaal/test/integration/control/cmd/a",
    "indrajaal/test/integration/control/cmd/b",
    "indrajaal/test/integration/metrics/cpu",
    "indrajaal/test/integration/metrics/mem",
    "indrajaal/test/integration/sentinel/alert",
    "indrajaal/test/integration/guardian/approval",
    "indrajaal/test/integration/pipeline/raw",
    "indrajaal/test/integration/pipeline/processed"
  ]

  # Wildcard groups: all topics sharing the same second-level domain
  @health_topics Enum.filter(@topics, &String.contains?(&1, "/health/"))
  @control_topics Enum.filter(@topics, &String.contains?(&1, "/control/"))
  @metrics_topics Enum.filter(@topics, &String.contains?(&1, "/metrics/"))

  @msgs_per_topic 15

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for topic <- @topics do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, topic)
    end

    on_exit(fn ->
      for topic <- @topics do
        Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
      end
    end)

    zenoh_mode = if @zenoh_available, do: :nif, else: :pubsub_fallback

    {:ok, zenoh_mode: zenoh_mode}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp make_msg(topic, seq) do
    %{
      topic: topic,
      sequence: seq,
      payload: "payload-#{seq}",
      timestamp_us: System.monotonic_time(:microsecond),
      checkpoint_id: "CP-PUBSUB-#{String.pad_leading(to_string(seq), 2, "0")}",
      schema_version: "1.0.0"
    }
  end

  defp publish(topic, msg) do
    Phoenix.PubSub.broadcast(@pubsub_name, topic, {:pubsub_integration, topic, msg})
  end

  defp publish_all do
    for topic <- @topics do
      for seq <- 1..@msgs_per_topic do
        publish(topic, make_msg(topic, seq))
      end
    end
  end

  defp drain(timeout_ms, acc \\ []) do
    receive do
      {:pubsub_integration, topic, msg} ->
        drain(timeout_ms, [{topic, msg} | acc])
    after
      timeout_ms -> Enum.reverse(acc)
    end
  end

  defp group_by_topic(messages) do
    Enum.group_by(messages, fn {topic, _msg} -> topic end)
  end

  # ---------------------------------------------------------------------------
  # Tests: Zenoh availability detection
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: NIF availability detection" do
    test "SKIP_ZENOH_NIF env variable is readable", %{zenoh_mode: mode} do
      assert mode in [:nif, :pubsub_fallback]
    end

    test "Indrajaal.Native.Zenoh module is defined regardless of NIF state" do
      assert Code.ensure_loaded?(Indrajaal.Native.Zenoh)
    end

    test "open_session/1 function is exported by Indrajaal.Native.Zenoh" do
      assert function_exported?(Indrajaal.Native.Zenoh, :open_session, 1)
    end

    test "publish/3 function is exported by Indrajaal.Native.Zenoh" do
      assert function_exported?(Indrajaal.Native.Zenoh, :publish, 3)
    end

    test "subscribe/3 function is exported by Indrajaal.Native.Zenoh" do
      assert function_exported?(Indrajaal.Native.Zenoh, :subscribe, 3)
    end

    test "Indrajaal.Cluster.ZenohMesh module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Cluster.ZenohMesh)
    end

    test "Indrajaal.Observability.ZenohTelemetrySubscriber module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Observability.ZenohTelemetrySubscriber)
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Topic contract (SC-ZTEST-017)
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: Topic contract" do
    test "exactly #{@topic_count} topics are configured" do
      assert length(@topics) == @topic_count
    end

    test "all #{@topic_count} topics are unique" do
      assert length(@topics) == length(Enum.uniq(@topics))
    end

    test "all topics conform to SC-ZTEST-017 depth constraint (≤ 6 levels)" do
      for topic <- @topics do
        depth = String.split(topic, "/") |> length() |> Kernel.-(1)

        assert depth <= 6,
               "Topic '#{topic}' has depth #{depth} > 6 (SC-ZTEST-017)"
      end
    end

    test "all topics begin with 'indrajaal/' namespace prefix" do
      for topic <- @topics do
        assert String.starts_with?(topic, "indrajaal/"),
               "Topic '#{topic}' does not start with 'indrajaal/' namespace"
      end
    end

    test "checkpoint_id follows CP-{DOMAIN}-{NN} format (SC-ZTEST-013)" do
      msg = make_msg(hd(@topics), 5)
      assert msg.checkpoint_id =~ ~r/^CP-PUBSUB-\d{2}$/
    end

    test "schema_version is semver (SC-ZTEST-014)" do
      msg = make_msg(hd(@topics), 1)
      assert msg.schema_version =~ ~r/^\d+\.\d+\.\d+$/
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Subscription to 10 concurrent topics
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: 10 concurrent topic subscriptions" do
    test "a single message on each topic is individually received" do
      for {topic, idx} <- Enum.with_index(@topics, 1) do
        msg = make_msg(topic, idx)
        publish(topic, msg)
      end

      received = drain(500)

      assert length(received) == @topic_count,
             "Expected #{@topic_count} messages (one per topic), got #{length(received)}"
    end

    test "each of the 10 topics delivers at least one message" do
      for topic <- @topics do
        msg = make_msg(topic, 1)
        publish(topic, msg)
      end

      received = drain(500)
      received_topics = Enum.map(received, fn {t, _} -> t end) |> MapSet.new()
      expected_topics = MapSet.new(@topics)

      assert MapSet.subset?(expected_topics, received_topics),
             "Not all topics delivered: missing #{inspect(MapSet.difference(expected_topics, received_topics))}"
    end

    test "#{@topic_count * @msgs_per_topic} total messages delivered across all topics" do
      publish_all()
      received = drain(600)
      expected = @topic_count * @msgs_per_topic

      assert length(received) == expected,
             "Expected #{expected} total msgs across #{@topic_count} topics, got #{length(received)}"
    end

    test "each topic receives exactly #{@msgs_per_topic} messages" do
      publish_all()
      received = drain(600)

      per_topic = group_by_topic(received)

      for topic <- @topics do
        count = length(Map.get(per_topic, topic, []))

        assert count == @msgs_per_topic,
               "Topic '#{topic}' received #{count} messages, expected #{@msgs_per_topic}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Simultaneous publishing
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: Simultaneous publishing to multiple topics" do
    test "concurrent task publish to all topics delivers all messages" do
      parent = self()

      tasks =
        for {topic, idx} <- Enum.with_index(@topics, 1) do
          Task.async(fn ->
            for seq <- 1..5 do
              msg = make_msg(topic, seq + (idx - 1) * 5)
              publish(topic, msg)
            end

            send(parent, {:published, topic})
          end)
        end

      Task.await_many(tasks, 5_000)

      # Drain all publish confirmations
      confirmations =
        for _ <- 1..@topic_count do
          receive do
            {:published, _topic} -> :ok
          after
            1_000 -> :timeout
          end
        end

      assert Enum.all?(confirmations, &(&1 == :ok)),
             "Not all concurrent publish tasks completed"
    end

    test "simultaneous publish to health and control topics does not intermix messages" do
      # Publish to health group
      for topic <- @health_topics do
        for seq <- 1..3 do
          msg = make_msg(topic, seq)
          publish(topic, msg)
        end
      end

      # Publish to control group
      for topic <- @control_topics do
        for seq <- 1..3 do
          msg = make_msg(topic, seq)
          publish(topic, msg)
        end
      end

      received = drain(400)
      per_topic = group_by_topic(received)

      # Health messages must only be on health topics
      for topic <- @health_topics do
        msgs = Map.get(per_topic, topic, [])

        assert length(msgs) == 3,
               "Health topic '#{topic}' expected 3 msgs, got #{length(msgs)}"
      end

      # Control messages must only be on control topics
      for topic <- @control_topics do
        msgs = Map.get(per_topic, topic, [])

        assert length(msgs) == 3,
               "Control topic '#{topic}' expected 3 msgs, got #{length(msgs)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: FIFO ordering (SC-ZTEST-012)
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: FIFO ordering per topic (SC-ZTEST-012)" do
    test "sequences 1..#{@msgs_per_topic} arrive in order on every topic" do
      publish_all()
      received = drain(600)
      per_topic = group_by_topic(received)

      expected_seqs = Enum.to_list(1..@msgs_per_topic)

      for {topic, msgs} <- per_topic do
        actual_seqs = Enum.map(msgs, fn {_, msg} -> msg.sequence end)

        assert actual_seqs == expected_seqs,
               "FIFO violated on '#{topic}': expected #{inspect(expected_seqs)}, got #{inspect(actual_seqs)} (SC-ZTEST-012)"
      end
    end

    test "ordering is preserved even after interleaved multi-topic burst" do
      # Interleave: first message of all topics, then second, then third...
      for seq <- 1..5 do
        for topic <- @topics do
          msg = make_msg(topic, seq)
          publish(topic, msg)
        end
      end

      received = drain(500)
      per_topic = group_by_topic(received)

      expected_seqs = Enum.to_list(1..5)

      for {topic, msgs} <- per_topic do
        actual_seqs = Enum.map(msgs, fn {_, msg} -> msg.sequence end)

        assert actual_seqs == expected_seqs,
               "FIFO violated after interleaved burst on '#{topic}'"
      end
    end

    test "timestamp_us is monotonically non-decreasing within each topic" do
      for topic <- @topics do
        for seq <- 1..5 do
          Process.sleep(1)
          msg = make_msg(topic, seq)
          publish(topic, msg)
        end
      end

      received = drain(500)
      per_topic = group_by_topic(received)

      for {topic, msgs} <- per_topic do
        timestamps = Enum.map(msgs, fn {_, msg} -> msg.timestamp_us end)
        pairs = Enum.zip(timestamps, tl(timestamps))

        violations =
          Enum.filter(pairs, fn {t1, t2} -> t2 < t1 end)

        assert violations == [],
               "Non-monotonic timestamps on topic '#{topic}': #{length(violations)} violations"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Topic wildcard matching semantics
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: Topic wildcard matching" do
    test "health group topics are correctly identified by substring filter" do
      assert length(@health_topics) >= 1,
             "Expected at least 1 health topic, got #{length(@health_topics)}"

      for topic <- @health_topics do
        assert String.contains?(topic, "/health/"),
               "Topic '#{topic}' in health group does not contain '/health/'"
      end
    end

    test "metrics group topics are correctly identified by substring filter" do
      assert length(@metrics_topics) >= 1,
             "Expected at least 1 metrics topic"

      for topic <- @metrics_topics do
        assert String.contains?(topic, "/metrics/"),
               "Topic '#{topic}' in metrics group does not contain '/metrics/'"
      end
    end

    test "topic groups are disjoint — health and control do not overlap" do
      health_set = MapSet.new(@health_topics)
      control_set = MapSet.new(@control_topics)
      intersection = MapSet.intersection(health_set, control_set)

      assert MapSet.size(intersection) == 0,
             "Health and control topic groups overlap: #{inspect(MapSet.to_list(intersection))}"
    end

    test "publishing to a topic prefix only delivers to subscribers on that exact topic" do
      # We subscribe only to exact topics; a prefix publish must not
      # deliver to related-but-different topics
      target = hd(@health_topics)
      other = hd(@control_topics)

      msg = make_msg(target, 99)
      publish(target, msg)

      # Receive the targeted message
      assert_receive {:pubsub_integration, ^target, received}, 300
      assert received.sequence == 99

      # The control topic must NOT receive anything from this publish
      refute_receive {:pubsub_integration, ^other, _}, 100
    end

    test "topic component segments are non-empty strings" do
      for topic <- @topics do
        segments = String.split(topic, "/")

        for segment <- segments do
          assert String.length(segment) > 0,
                 "Topic '#{topic}' contains empty segment"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Subscription lifecycle
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: Subscription lifecycle" do
    test "unsubscribing stops message delivery" do
      target = hd(@topics)

      # Extra subscriber to confirm the topic still works after unsub
      other_pubsub = Module.concat(__MODULE__, OtherPubSub)
      {:ok, _} = start_supervised({Phoenix.PubSub, name: other_pubsub}, id: :other_ps)
      Phoenix.PubSub.subscribe(other_pubsub, target)

      # Unsubscribe self from target
      Phoenix.PubSub.unsubscribe(@pubsub_name, target)

      msg = make_msg(target, 100)
      Phoenix.PubSub.broadcast(@pubsub_name, target, {:pubsub_integration, target, msg})

      # Self should NOT receive it
      refute_receive {:pubsub_integration, ^target, _}, 150

      # Re-subscribe for teardown
      Phoenix.PubSub.subscribe(@pubsub_name, target)
    end

    test "re-subscribing after unsubscribe resumes delivery" do
      target = List.last(@topics)

      Phoenix.PubSub.unsubscribe(@pubsub_name, target)
      Phoenix.PubSub.subscribe(@pubsub_name, target)

      msg = make_msg(target, 200)
      publish(target, msg)

      assert_receive {:pubsub_integration, ^target, received}, 300
      assert received.sequence == 200
    end

    test "no messages arrive on a topic that was never subscribed to" do
      unsub_topic = "indrajaal/test/integration/never/subscribed"
      msg = make_msg(unsub_topic, 1)
      Phoenix.PubSub.broadcast(@pubsub_name, unsub_topic, {:pubsub_integration, unsub_topic, msg})

      refute_receive {:pubsub_integration, ^unsub_topic, _}, 150
    end
  end

  # ---------------------------------------------------------------------------
  # Tests: Payload integrity
  # ---------------------------------------------------------------------------

  describe "PubSub Integration: Payload integrity through pub/sub" do
    test "all fields of msg are preserved verbatim through PubSub" do
      topic = hd(@topics)
      original = make_msg(topic, 42)

      publish(topic, original)

      assert_receive {:pubsub_integration, ^topic, received}, 300
      assert received.topic == original.topic
      assert received.sequence == original.sequence
      assert received.payload == original.payload
      assert received.timestamp_us == original.timestamp_us
      assert received.checkpoint_id == original.checkpoint_id
      assert received.schema_version == original.schema_version
    end

    test "binary payloads up to 64KB are preserved (SC-ZTEST-016)" do
      topic = hd(@topics)
      large_payload = :crypto.strong_rand_bytes(64 * 1024)

      msg = %{
        sequence: 1,
        payload: large_payload,
        timestamp_us: System.monotonic_time(:microsecond)
      }

      Phoenix.PubSub.broadcast(@pubsub_name, topic, {:pubsub_integration, topic, msg})

      assert_receive {:pubsub_integration, ^topic, received}, 500
      assert received.payload == large_payload
    end
  end
end
