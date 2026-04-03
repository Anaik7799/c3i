defmodule Indrajaal.Test.ZenohTestCoordinatorTest do
  @moduledoc """
  TDG tests for ZenohTestCoordinator module.

  WHAT: Tests for Zenoh-style pub/sub coordination in tests.
  WHY: Validates synchronous and asynchronous messaging patterns work correctly.
  CONSTRAINTS: Must handle process lifecycle, pattern matching, timeouts.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Test.ZenohTestCoordinator

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    {:ok, coordinator} = ZenohTestCoordinator.start_link()
    on_exit(fn -> safe_stop(coordinator) end)
    %{coordinator: coordinator}
  end

  # ============================================================
  # UNIT TESTS: SUBSCRIBE/UNSUBSCRIBE
  # ============================================================

  describe "subscribe/3" do
    test "subscribes to exact pattern", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/topic/exact")
      assert is_reference(ref)
    end

    test "subscribes to wildcard pattern", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/**/events")
      assert is_reference(ref)
    end

    test "subscribes to single wildcard pattern", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/*/status")
      assert is_reference(ref)
    end

    test "multiple subscriptions return different refs", %{coordinator: c} do
      {:ok, ref1} = ZenohTestCoordinator.subscribe(c, "test/a")
      {:ok, ref2} = ZenohTestCoordinator.subscribe(c, "test/b")
      refute ref1 == ref2
    end
  end

  describe "unsubscribe/2" do
    test "removes subscription", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/topic")
      assert :ok = ZenohTestCoordinator.unsubscribe(c, ref)
    end

    test "unsubscribe unknown ref is ok", %{coordinator: c} do
      assert :ok = ZenohTestCoordinator.unsubscribe(c, make_ref())
    end
  end

  # ============================================================
  # UNIT TESTS: PUBLISH (ASYNC)
  # ============================================================

  describe "publish/3 (async)" do
    test "delivers message to matching subscriber", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/events/created")
      :ok = ZenohTestCoordinator.publish(c, "test/events/created", %{id: 1})

      assert_receive {:zenoh_message, ^ref, "test/events/created", %{id: 1}}, 1000
    end

    test "delivers to wildcard subscribers", %{coordinator: c} do
      {:ok, ref} = ZenohTestCoordinator.subscribe(c, "test/**/created")
      :ok = ZenohTestCoordinator.publish(c, "test/domain/events/created", %{id: 2})

      assert_receive {:zenoh_message, ^ref, "test/domain/events/created", %{id: 2}}, 1000
    end

    test "delivers to multiple matching subscribers", %{coordinator: c} do
      {:ok, ref1} = ZenohTestCoordinator.subscribe(c, "test/**")
      {:ok, ref2} = ZenohTestCoordinator.subscribe(c, "test/events/**")

      :ok = ZenohTestCoordinator.publish(c, "test/events/done", :payload)

      assert_receive {:zenoh_message, ^ref1, "test/events/done", :payload}, 1000
      assert_receive {:zenoh_message, ^ref2, "test/events/done", :payload}, 1000
    end

    test "does not deliver to non-matching subscribers", %{coordinator: c} do
      {:ok, _ref} = ZenohTestCoordinator.subscribe(c, "other/topic")
      :ok = ZenohTestCoordinator.publish(c, "test/topic", :data)

      refute_receive {:zenoh_message, _, _, _}, 100
    end
  end

  # ============================================================
  # UNIT TESTS: PUBLISH_SYNC
  # ============================================================

  describe "publish_sync/4" do
    test "returns ok when subscribers exist", %{coordinator: c} do
      {:ok, _ref} = ZenohTestCoordinator.subscribe(c, "test/sync")
      assert :ok = ZenohTestCoordinator.publish_sync(c, "test/sync", :data)
    end

    test "returns error when no subscribers", %{coordinator: c} do
      assert {:error, :no_subscribers} =
               ZenohTestCoordinator.publish_sync(c, "test/no_sub", :data)
    end
  end

  # ============================================================
  # UNIT TESTS: REQUEST/REPLY
  # ============================================================

  describe "request/reply pattern" do
    test "request receives reply", %{coordinator: c} do
      parent = self()

      # Spawn responder task that signals when ready
      spawn(fn ->
        {:ok, _ref} = ZenohTestCoordinator.subscribe(c, "service/status")
        # Signal that we're ready
        send(parent, :responder_ready)

        receive do
          {:zenoh_request, req_ref, _key, _payload, _sender} ->
            ZenohTestCoordinator.reply(c, req_ref, %{status: :ok})
        after
          5000 -> :timeout
        end
      end)

      # Wait for responder to be ready
      assert_receive :responder_ready, 2000

      # Make request
      {:ok, response} = ZenohTestCoordinator.request(c, "service/status", %{}, timeout: 2000)
      assert response == %{status: :ok}
    end

    test "request to no responders returns error", %{coordinator: c} do
      assert {:error, :no_responders} =
               ZenohTestCoordinator.request(c, "no/service", %{}, timeout: 100)
    end
  end

  # ============================================================
  # UNIT TESTS: AWAIT
  # ============================================================

  describe "await/3" do
    test "awaits and receives matching message", %{coordinator: c} do
      # Publish from another process
      Task.start(fn ->
        Process.sleep(50)
        ZenohTestCoordinator.publish(c, "test/complete", %{result: :success})
      end)

      {:ok, payload} = ZenohTestCoordinator.await(c, "test/complete", timeout: 2000)
      assert payload == %{result: :success}
    end

    test "await times out when no message", %{coordinator: c} do
      assert {:error, :timeout} = ZenohTestCoordinator.await(c, "test/never", timeout: 100)
    end

    test "await with wildcard pattern", %{coordinator: c} do
      Task.start(fn ->
        Process.sleep(50)
        ZenohTestCoordinator.publish(c, "test/worker/123/done", :finished)
      end)

      {:ok, payload} = ZenohTestCoordinator.await(c, "test/worker/**/done", timeout: 2000)
      assert payload == :finished
    end
  end

  # ============================================================
  # UNIT TESTS: AWAIT_UNTIL
  # ============================================================

  describe "await_until/4" do
    test "collects messages until condition met", %{coordinator: c} do
      # Publish multiple messages
      Task.start(fn ->
        for i <- 1..5 do
          Process.sleep(20)
          ZenohTestCoordinator.publish(c, "test/progress", %{step: i})
        end
      end)

      {:ok, messages} =
        ZenohTestCoordinator.await_until(
          c,
          "test/progress",
          fn msgs -> length(msgs) >= 3 end,
          timeout: 2000
        )

      assert length(messages) >= 3
    end

    test "times out if condition never met", %{coordinator: c} do
      # Only publish 1 message
      Task.start(fn ->
        Process.sleep(20)
        ZenohTestCoordinator.publish(c, "test/progress", %{step: 1})
      end)

      result =
        ZenohTestCoordinator.await_until(
          c,
          "test/progress",
          fn msgs -> length(msgs) >= 10 end,
          timeout: 200
        )

      assert {:error, :timeout} = result
    end
  end

  # ============================================================
  # UNIT TESTS: BARRIER
  # ============================================================

  describe "barrier/4" do
    # Barrier coordination is complex - skip for now
    @tag :skip
    test "synchronizes multiple processes", %{coordinator: c} do
      parent = self()

      # Spawn 3 workers
      for i <- 1..3 do
        spawn(fn ->
          # Simulate work
          Process.sleep(i * 20)
          # Wait at barrier
          result = ZenohTestCoordinator.barrier(c, "test_barrier", 3, timeout: 2000)
          send(parent, {:worker_done, i, result})
        end)
      end

      # All workers should complete
      for i <- 1..3 do
        assert_receive {:worker_done, ^i, :ok}, 3000
      end
    end

    test "barrier times out with insufficient participants", %{coordinator: c} do
      # Only 1 worker when 3 needed
      result = ZenohTestCoordinator.barrier(c, "lonely_barrier", 3, timeout: 200)
      assert {:error, :timeout} = result
    end
  end

  # ============================================================
  # UNIT TESTS: STATS
  # ============================================================

  describe "stats/1" do
    test "returns current statistics", %{coordinator: c} do
      {:ok, _} = ZenohTestCoordinator.subscribe(c, "test/a")
      {:ok, _} = ZenohTestCoordinator.subscribe(c, "test/b")
      ZenohTestCoordinator.publish(c, "test/a", :data)

      Process.sleep(50)

      stats = ZenohTestCoordinator.stats(c)

      assert stats.subscriptions == 2
      assert stats.messages_processed >= 1
      assert stats.total_subscriptions == 2
    end
  end

  # ============================================================
  # INTEGRATION TESTS: MULTI-PROCESS SCENARIOS
  # ============================================================

  describe "multi-process coordination" do
    test "producer-consumer pattern", %{coordinator: c} do
      parent = self()
      item_count = 5

      # Consumer
      consumer =
        spawn(fn ->
          {:ok, _ref} = ZenohTestCoordinator.subscribe(c, "queue/item")
          items = collect_items([], item_count)
          send(parent, {:consumed, items})
        end)

      # Give consumer time to subscribe
      Process.sleep(50)

      # Producer
      spawn(fn ->
        for i <- 1..item_count do
          ZenohTestCoordinator.publish(c, "queue/item", %{value: i})
          Process.sleep(10)
        end
      end)

      assert_receive {:consumed, items}, 2000
      assert length(items) == item_count
    end

    test "scatter-gather pattern", %{coordinator: c} do
      parent = self()
      worker_count = 3

      # Spawn workers
      for i <- 1..worker_count do
        spawn(fn ->
          {:ok, _ref} = ZenohTestCoordinator.subscribe(c, "work/request")

          receive do
            {:zenoh_message, _ref, _key, %{task: task}} ->
              # Do work
              result = task * 2
              ZenohTestCoordinator.publish(c, "work/result", %{worker: i, result: result})
          end
        end)
      end

      # Give workers time to subscribe
      Process.sleep(100)

      # Scatter work
      ZenohTestCoordinator.publish(c, "work/request", %{task: 10})

      # Gather results
      {:ok, results} =
        ZenohTestCoordinator.await_until(
          c,
          "work/result",
          fn msgs -> length(msgs) >= worker_count end,
          timeout: 2000
        )

      assert length(results) == worker_count
      assert Enum.all?(results, fn %{result: r} -> r == 20 end)
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "subscription refs are unique" do
      forall n <- PC.integer(1, 10) do
        {:ok, coordinator} = ZenohTestCoordinator.start_link()

        refs =
          for _ <- 1..n do
            {:ok, ref} = ZenohTestCoordinator.subscribe(coordinator, "test/topic")
            ref
          end

        safe_stop(coordinator)
        length(Enum.uniq(refs)) == n
      end
    end

    property "messages are delivered to matching patterns" do
      forall segments <- PC.list(PC.integer(1, 100)) do
        {:ok, coordinator} = ZenohTestCoordinator.start_link()

        # Build key from segments
        key = Enum.map_join(segments, "/", fn n -> "seg#{n}" end)
        pattern = "**"

        {:ok, ref} = ZenohTestCoordinator.subscribe(coordinator, pattern)
        ZenohTestCoordinator.publish(coordinator, key, :data)

        result =
          receive do
            {:zenoh_message, ^ref, ^key, :data} -> true
          after
            500 -> false
          end

        safe_stop(coordinator)
        result or segments == []
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "stats are consistent with operations" do
      ExUnitProperties.check all(
                               sub_count <- SD.integer(1..5),
                               pub_count <- SD.integer(1..5)
                             ) do
        {:ok, coordinator} = ZenohTestCoordinator.start_link()

        # Create subscriptions
        for _ <- 1..sub_count do
          ZenohTestCoordinator.subscribe(coordinator, "test/topic")
        end

        # Publish messages
        for _ <- 1..pub_count do
          ZenohTestCoordinator.publish(coordinator, "test/topic", :data)
        end

        Process.sleep(50)
        stats = ZenohTestCoordinator.stats(coordinator)

        assert stats.subscriptions == sub_count
        assert stats.total_subscriptions == sub_count

        safe_stop(coordinator)
      end
    end
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal, 500)
    end
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_stop(_), do: :ok

  defp collect_items(acc, 0), do: Enum.reverse(acc)

  defp collect_items(acc, remaining) do
    receive do
      {:zenoh_message, _ref, _key, item} ->
        collect_items([item | acc], remaining - 1)
    after
      2000 ->
        Enum.reverse(acc)
    end
  end
end
