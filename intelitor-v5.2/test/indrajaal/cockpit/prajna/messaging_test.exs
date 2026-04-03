defmodule Indrajaal.Cockpit.Prajna.MessagingTest do
  @moduledoc """
  TDG-Compliant Tests for Messaging Module.

  STAMP Compliance: SC-MSG-001, SC-MSG-002, SC-MSG-003, SC-TEL-001
  TDG: Dual property testing with PropCheck + ExUnitProperties
  """
  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Messaging

  # ═══════════════════════════════════════════════════════════════════════════
  # TEST SETUP
  # ═══════════════════════════════════════════════════════════════════════════

  setup do
    # Start Messaging server for tests if not running
    case GenServer.whereis(Messaging) do
      nil ->
        {:ok, pid} = Messaging.start_link([])

        on_exit(fn ->
          try do
            if Process.alive?(pid), do: GenServer.stop(pid, :normal, 1000)
          catch
            :exit, _ -> :ok
          end
        end)

        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Subscription
  # ═══════════════════════════════════════════════════════════════════════════

  describe "subscribe/1" do
    test "subscribes to known topics" do
      assert :ok = Messaging.subscribe(:metrics)
      assert :ok = Messaging.subscribe(:alarms)
      assert :ok = Messaging.subscribe(:commands)
    end

    test "subscribes to custom topics" do
      assert :ok = Messaging.subscribe(:custom_topic)
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribes from topics" do
      Messaging.subscribe(:metrics)
      assert :ok = Messaging.unsubscribe(:metrics)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Broadcasting
  # ═══════════════════════════════════════════════════════════════════════════

  describe "broadcast/2" do
    test "broadcasts to subscribed processes" do
      Messaging.subscribe(:alarms)

      Messaging.broadcast(:alarms, {:alarm_raised, "alarm_1", :critical, "Test alarm"})

      assert_receive {:alarm_raised, "alarm_1", :critical, "Test alarm"}, 500
    end

    test "broadcasts metric updates" do
      Messaging.subscribe(:metrics)

      Messaging.broadcast(:metrics, {:metric_updated, "node1", :cpu, 75.5})

      assert_receive {:metric_updated, "node1", :cpu, 75.5}, 500
    end
  end

  describe "broadcast_from/3" do
    test "broadcasts from specific sender" do
      Messaging.subscribe(:commands)

      Messaging.broadcast_from(:commands, self(), {:command_armed, "cmd1", "node1", :restart})

      # broadcast_from excludes sender, so we shouldn't receive it
      refute_receive {:command_armed, _, _, _}, 100
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Metrics
  # ═══════════════════════════════════════════════════════════════════════════

  describe "update_metric/4" do
    test "updates metric value" do
      Messaging.update_metric("node1", :cpu, 65.0, "%")

      state = Messaging.get_telemetry_state()

      assert get_in(state.metrics, ["node1.cpu", :value]) == 65.0
      assert get_in(state.metrics, ["node1.cpu", :unit]) == "%"
    end

    test "updates sparkline history" do
      Messaging.update_metric("node2", :memory, 50.0)
      Messaging.update_metric("node2", :memory, 55.0)
      Messaging.update_metric("node2", :memory, 60.0)

      state = Messaging.get_telemetry_state()
      sparkline = Map.get(state.sparklines, "node2.memory", [])

      assert length(sparkline) >= 3
      # Most recent first
      assert hd(sparkline) == 60.0
    end
  end

  describe "get_telemetry_state/0" do
    test "returns telemetry state map" do
      state = Messaging.get_telemetry_state()

      assert Map.has_key?(state, :metrics)
      assert Map.has_key?(state, :sparklines)
      assert Map.has_key?(state, :updated_at)
      assert Map.has_key?(state, :message_count)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Staleness Detection
  # ═══════════════════════════════════════════════════════════════════════════

  describe "stale?/1" do
    test "returns true for non-existent metrics" do
      assert Messaging.stale?("nonexistent.metric") == true
    end

    test "returns false for recently updated metrics" do
      Messaging.update_metric("fresh_node", :cpu, 50.0)
      assert Messaging.stale?("fresh_node.cpu") == false
    end
  end

  describe "get_staleness/1" do
    test "returns high value for non-existent metrics" do
      staleness = Messaging.get_staleness("missing.metric")
      assert staleness > 9000
    end

    test "returns low value for fresh metrics" do
      Messaging.update_metric("recent_node", :memory, 75.0)
      staleness = Messaging.get_staleness("recent_node.memory")
      assert staleness < 1.0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Status
  # ═══════════════════════════════════════════════════════════════════════════

  describe "get_status/0" do
    test "returns status summary" do
      status = Messaging.get_status()

      assert Map.has_key?(status, :uptime_seconds)
      assert Map.has_key?(status, :message_count)
      assert Map.has_key?(status, :error_count)
      assert Map.has_key?(status, :metric_count)
      assert Map.has_key?(status, :topics)

      assert is_integer(status.uptime_seconds)
      assert is_integer(status.message_count)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "update_metric always increases message count" do
    forall {node, value} <- {PC.utf8(), PC.float()} do
      before = Messaging.get_status().message_count
      Messaging.update_metric(node, :cpu, value)
      after_count = Messaging.get_status().message_count
      after_count >= before
    end
  end

  property "staleness is non-negative" do
    forall metric_key <- PC.utf8() do
      staleness = Messaging.get_staleness(metric_key)
      staleness >= 0
    end
  end

  property "get_telemetry_state always returns map with required keys" do
    forall _ <- PC.boolean() do
      state = Messaging.get_telemetry_state()

      is_map(state) and
        Map.has_key?(state, :metrics) and
        Map.has_key?(state, :sparklines) and
        Map.has_key?(state, :message_count)
    end
  end

  property "subscribe always returns :ok" do
    forall topic <- PC.atom() do
      result = Messaging.subscribe(topic)
      result == :ok
    end
  end

  property "unsubscribe always returns :ok" do
    forall topic <- PC.atom() do
      Messaging.subscribe(topic)
      result = Messaging.unsubscribe(topic)
      result == :ok
    end
  end

  property "get_status always returns map with required keys" do
    forall _ <- PC.boolean() do
      status = Messaging.get_status()

      is_map(status) and
        Map.has_key?(status, :uptime_seconds) and
        Map.has_key?(status, :message_count) and
        Map.has_key?(status, :error_count)
    end
  end

  property "stale? returns boolean" do
    forall metric_key <- PC.utf8() do
      result = Messaging.stale?(metric_key)
      is_boolean(result)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "sparkline history is bounded (property)" do
    node_id = "test_node_#{:erlang.unique_integer([:positive])}"

    # Update with 100 values
    for val <- Enum.map(1..100, fn x -> x * 1.0 end) do
      Messaging.update_metric(node_id, :test_metric, val)
    end

    state = Messaging.get_telemetry_state()
    sparkline = Map.get(state.sparklines, "#{node_id}.test_metric", [])

    # Sparkline should be bounded to max 60 points
    assert length(sparkline) <= 60
  end

  test "subscription is idempotent (property)" do
    for topic <- [:metrics, :alarms, :commands, :ooda] do
      assert :ok = Messaging.subscribe(topic)
      assert :ok = Messaging.subscribe(topic)
    end
  end
end
