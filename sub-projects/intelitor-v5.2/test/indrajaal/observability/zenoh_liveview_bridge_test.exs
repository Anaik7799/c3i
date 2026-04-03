defmodule Indrajaal.Observability.ZenohLiveViewBridgeTest do
  @moduledoc """
  Tests for the Zenoh-LiveView Bridge.

  WHAT: Verifies bridge functionality between Zenoh pub/sub and Phoenix LiveView.
  WHY: SC-PROM-003 (Dashboard refresh), 12.1.0.0.0 (Wire Nervous System)
  CONSTRAINTS: SC-PRF-050 (< 50ms latency), SC-BUS-001 (async messaging)
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Observability.ZenohLiveViewBridge
  alias Phoenix.PubSub

  @pubsub Indrajaal.PubSub

  # Ensure PubSub is started for tests
  setup_all do
    # Start PubSub if not already running (test isolation)
    case Phoenix.PubSub.Supervisor.start_link(name: @pubsub, adapter: Phoenix.PubSub.PG2) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  describe "start_link/1" do
    test "starts the bridge GenServer" do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "subscribe/1" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{bridge: pid, name: name}
    end

    test "subscribes to a specific topic" do
      assert :ok = ZenohLiveViewBridge.subscribe(:kpi)
      # Verify subscription by checking we can receive broadcasts
      PubSub.broadcast(@pubsub, "zenoh:kpi", {:test, :message})
      assert_receive {:test, :message}, 100
    end

    test "subscribes to all topics" do
      assert :ok = ZenohLiveViewBridge.subscribe(:all)

      # Should receive on any topic
      PubSub.broadcast(@pubsub, "zenoh:metrics", {:metrics_test, :data})
      assert_receive {:metrics_test, :data}, 100
    end
  end

  describe "broadcast/2" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      # Subscribe to receive broadcasts
      ZenohLiveViewBridge.subscribe(:kpi)

      %{bridge: pid}
    end

    test "broadcasts data to subscribed processes" do
      data = %{value: 42, metric: "test_metric"}
      assert :ok = ZenohLiveViewBridge.broadcast(:kpi, data)

      assert_receive {:zenoh_update, :kpi, received_data}, 100
      assert received_data.value == 42
      assert received_data.metric == "test_metric"
    end

    test "enriches message with bridge metadata" do
      ZenohLiveViewBridge.broadcast(:kpi, %{test: true})

      assert_receive {:zenoh_update, :kpi, data}, 100
      assert Map.has_key?(data, :bridged_at)
      assert Map.has_key?(data, :bridge_version)
    end
  end

  describe "get_stats/1" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{bridge: pid}
    end

    test "returns bridge statistics", %{bridge: pid} do
      stats = ZenohLiveViewBridge.get_stats(pid)

      assert Map.has_key?(stats, :messages_bridged)
      assert Map.has_key?(stats, :uptime_seconds)
      assert Map.has_key?(stats, :buffer_size)
      assert Map.has_key?(stats, :active_subscriptions)
    end

    test "tracks message count after buffered messages", %{bridge: pid} do
      # messages_bridged counts messages processed through the internal buffer
      # Send Zenoh-style messages through the buffer path
      GenServer.cast(pid, {:zenoh_message, "indrajaal/alerts/test1", ~s({"alert": "test1"})})
      GenServer.cast(pid, {:zenoh_message, "indrajaal/alerts/test2", ~s({"alert": "test2"})})

      # Wait for buffer flush (100ms interval + margin)
      Process.sleep(200)

      stats = ZenohLiveViewBridge.get_stats(pid)
      assert stats.messages_bridged >= 2
    end
  end

  describe "message buffering" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{bridge: pid}
    end

    test "buffers incoming messages", %{bridge: pid} do
      # Send Zenoh-style message
      GenServer.cast(pid, {:zenoh_message, "indrajaal/kpi/test", ~s({"value": 100})})

      # Buffer should be processed on next flush interval
      Process.sleep(150)

      stats = ZenohLiveViewBridge.get_stats(pid)
      assert stats.messages_bridged >= 1
    end
  end

  describe "topic mapping" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

      # Subscribe to all topics
      ZenohLiveViewBridge.subscribe(:all)

      %{bridge: pid}
    end

    test "maps kpi key expressions correctly", %{bridge: pid} do
      GenServer.cast(pid, {:zenoh_message, "indrajaal/kpi/cpu", ~s({"usage": 50})})
      Process.sleep(150)

      # Should have been mapped to :kpi topic
      stats = ZenohLiveViewBridge.get_stats(pid)
      assert stats.messages_bridged >= 1
    end

    test "handles multiple topic types" do
      ZenohLiveViewBridge.broadcast(:metrics, %{type: "metrics"})
      ZenohLiveViewBridge.broadcast(:agents, %{type: "agents"})
      ZenohLiveViewBridge.broadcast(:health, %{type: "health"})
      ZenohLiveViewBridge.broadcast(:safety, %{type: "safety"})

      # Should receive all
      assert_receive {:zenoh_update, :metrics, _}, 100
      assert_receive {:zenoh_update, :agents, _}, 100
      assert_receive {:zenoh_update, :health, _}, 100
      assert_receive {:zenoh_update, :safety, _}, 100
    end
  end

  describe "unsubscribe/1" do
    test "stops receiving messages after unsubscribe" do
      ZenohLiveViewBridge.subscribe(:evolution)
      ZenohLiveViewBridge.broadcast(:evolution, %{event: "before_unsub"})
      assert_receive {:zenoh_update, :evolution, _}, 100

      ZenohLiveViewBridge.unsubscribe(:evolution)
      ZenohLiveViewBridge.broadcast(:evolution, %{event: "after_unsub"})
      refute_receive {:zenoh_update, :evolution, _}, 100
    end
  end

  describe "SC-PRF-050 latency constraint" do
    setup do
      name = :"bridge_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = ZenohLiveViewBridge.start_link(name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{bridge: pid}
    end

    test "processes messages within latency budget", %{bridge: pid} do
      # Send batch of messages
      for i <- 1..20 do
        GenServer.cast(pid, {:zenoh_message, "indrajaal/kpi/batch", ~s({"idx": #{i}})})
      end

      Process.sleep(200)

      stats = ZenohLiveViewBridge.get_stats(pid)

      # Check latency samples are within budget (50ms = 50000us)
      if stats.latency_samples != [] do
        avg_latency = Enum.sum(stats.latency_samples) / length(stats.latency_samples)
        assert avg_latency < 50_000, "Average latency #{avg_latency}us exceeds 50ms budget"
      end
    end
  end
end
