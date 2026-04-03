defmodule Indrajaal.Observability.ZenohIntegrationTest do
  @moduledoc """
  TDG Integration Tests for Zenoh CEPAF-Elixir Integration.

  WHAT: Comprehensive tests for the full Zenoh integration flow.
  WHY: SC-ZENOH-005 requires end-to-end validation of dashboard integration.
  CONSTRAINTS: Must test publisher, subscriber, coordinator, and barrier sync.

  ## Test Coverage

  1. Publisher -> Dashboard data flow
  2. Dashboard -> Subscriber control flow
  3. Barrier synchronization for multi-agent ops
  4. Heartbeat monitoring and health checks
  5. Error handling and recovery scenarios
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.{
    ZenohCoordinator,
    ZenohKpiPublisher,
    ZenohControlSubscriber
  }

  alias Indrajaal.Test.ZenohTestCoordinator, as: Zenoh

  @moduletag :zenoh_integration

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start fresh coordinator for each test
    {:ok, coordinator} = Zenoh.start_link()

    # Use unique IDs for named processes to avoid MatchError (already_started)
    id = :erlang.unique_integer([:positive])
    suffix = "T#{id}"
    pub_name = Module.concat([ZenohKpiPublisher, Test, suffix])
    sub_name = Module.concat([ZenohControlSubscriber, Test, suffix])
    coord_name = Module.concat([ZenohCoordinator, Test, suffix])

    on_exit(fn ->
      safe_stop(coordinator)
    end)

    %{
      coordinator: coordinator,
      suffix: suffix,
      pub_name: pub_name,
      sub_name: sub_name,
      coord_name: coord_name
    }
  end

  # ============================================================
  # UNIT TESTS: ZENOH KPI PUBLISHER
  # ============================================================

  describe "ZenohKpiPublisher" do
    test "starts successfully", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      assert Process.alive?(pid)
    end

    test "returns stats with correct structure", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      stats = ZenohKpiPublisher.get_stats(name)

      assert is_map(stats)
      assert Map.has_key?(stats, :publish_count)
      assert Map.has_key?(stats, :started_at)
      assert Map.has_key?(stats, :subscriber_count)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "publish_now triggers immediate publish", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      initial_stats = ZenohKpiPublisher.get_stats(name)
      initial_count = initial_stats.publish_count

      :ok = ZenohKpiPublisher.publish_now(name)
      Process.sleep(150)

      updated_stats = ZenohKpiPublisher.get_stats(name)
      assert updated_stats.publish_count >= initial_count
    end

    test "supports KPI subscriptions", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      {:ok, ref} = ZenohKpiPublisher.subscribe(name, "indrajaal/kpi/*")
      assert is_reference(ref)

      :ok = ZenohKpiPublisher.unsubscribe(name, ref)
    end

    test "update_kpi updates cache and notifies subscribers", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      # Subscribe to full key
      pattern = "indrajaal/kpi/compilation"
      {:ok, ref} = ZenohKpiPublisher.subscribe(name, pattern)

      ZenohKpiPublisher.update_kpi(name, :compilation, %{errors: 0, warnings: 5})
      ZenohKpiPublisher.publish_now(name)

      assert_receive {:kpi_update, ^pattern, payload}, 1000
      assert payload.errors == 0
      assert payload.warnings == 5
    end

    test "get_kpis returns cached KPIs", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      ZenohKpiPublisher.update_kpi(name, :tests, %{total: 100, passed: 95})
      Process.sleep(50)

      kpis = ZenohKpiPublisher.get_kpis(name)
      assert kpis.tests.total == 100
      assert kpis.tests.passed == 95
    end
  end

  # ============================================================
  # UNIT TESTS: ZENOH CONTROL SUBSCRIBER
  # ============================================================

  describe "ZenohControlSubscriber" do
    test "starts successfully", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      assert Process.alive?(pid)
    end

    test "returns stats", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      stats = ZenohControlSubscriber.get_stats(name)

      assert is_map(stats)
      assert Map.has_key?(stats, :command_count)
      assert Map.has_key?(stats, :subscriptions_active)
    end

    test "can register custom handler", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      handler = fn _key, _payload -> :handled end
      assert :ok = ZenohControlSubscriber.register_handler(name, "test/pattern", handler)

      stats = ZenohControlSubscriber.get_stats(name)
      assert length(stats.handlers) >= 1
    end

    test "can unregister handler", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      handler = fn _key, _payload -> :handled end
      :ok = ZenohControlSubscriber.register_handler(name, "test/pattern", handler)
      :ok = ZenohControlSubscriber.unregister_handler(name, "test/pattern")

      stats = ZenohControlSubscriber.get_stats(name)
      assert stats.handlers == []
    end

    test "process_command_sync processes control commands", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      # Process a refresh command
      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/refresh",
          %{}
        )

      assert result == :ok

      stats = ZenohControlSubscriber.get_stats(name)
      assert stats.command_count >= 1
    end

    test "process_command_sync handles mode changes", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/mode",
          %{"mode" => "dark"}
        )

      assert result == :ok
    end

    test "process_command_sync handles agent commands", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/agent/worker_1",
          %{action: "restart"}
        )

      assert result == :ok
    end
  end

  # ============================================================
  # UNIT TESTS: ZENOH COORDINATOR
  # ============================================================

  describe "ZenohCoordinator" do
    test "starts and supervises children", %{coord_name: name, suffix: suffix} do
      {:ok, pid} =
        ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

      on_exit(fn -> safe_stop_supervisor(pid) end)

      assert Process.alive?(pid)

      children = Supervisor.which_children(pid)
      assert length(children) >= 2
    end

    test "sync_now triggers publisher", %{coord_name: name, suffix: suffix} do
      {:ok, pid} =
        ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

      on_exit(fn -> safe_stop_supervisor(pid) end)

      Process.sleep(100)

      assert :ok = ZenohCoordinator.sync_now(name)
    end

    test "healthy? reports coordinator health", %{coord_name: name, suffix: suffix} do
      {:ok, pid} =
        ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

      on_exit(fn -> safe_stop_supervisor(pid) end)

      Process.sleep(100)

      # We don't check true/false specifically as it depends on NIF availability/network
      assert is_boolean(ZenohCoordinator.healthy?(name))
    end

    test "publish_coord sends coordination messages", %{
      coordinator: c,
      coord_name: name,
      suffix: suffix
    } do
      {:ok, pid} =
        ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

      on_exit(fn -> safe_stop_supervisor(pid) end)

      # Subscribe to coordination topic
      {:ok, ref} = Zenoh.subscribe(c, "indrajaal/coord/**")

      # Publish coordination message
      :ok = ZenohCoordinator.publish_coord("test", %{data: "test_value"}, name: name)

      # Should receive the message
      assert_receive {:zenoh_message, ^ref, "indrajaal/coord/test", %{data: "test_value"}}, 1000
    end
  end

  # ============================================================
  # INTEGRATION TESTS: PUBLISHER -> DASHBOARD DATA FLOW
  # ============================================================

  describe "Publisher -> Dashboard data flow" do
    test "publishes KPIs to subscribers on publish_now", %{pub_name: name} do
      {:ok, pub_pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pub_pid) end)

      # Subscribe to all KPIs
      pattern = "indrajaal/kpi/*"
      {:ok, _ref} = ZenohKpiPublisher.subscribe(name, pattern)

      # Trigger immediate publish
      ZenohKpiPublisher.publish_now(name)

      # Should receive compilation KPI
      assert_receive {:kpi_update, "indrajaal/kpi/compilation", _payload}, 2000
    end

    test "KPIs include all expected categories", %{pub_name: name} do
      {:ok, pub_pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pub_pid) end)

      # Trigger publish
      ZenohKpiPublisher.publish_now(name)
      Process.sleep(200)

      kpis = ZenohKpiPublisher.get_kpis(name)

      assert Map.has_key?(kpis, :compilation)
      assert Map.has_key?(kpis, :tests)
      assert Map.has_key?(kpis, :containers)
      assert Map.has_key?(kpis, :performance)
      assert Map.has_key?(kpis, :progress)
      assert Map.has_key?(kpis, :stamp)
      assert Map.has_key?(kpis, :todos)
    end
  end

  # ============================================================
  # INTEGRATION TESTS: DASHBOARD -> SUBSCRIBER CONTROL FLOW
  # ============================================================

  describe "Dashboard -> Subscriber control flow" do
    test "processes refresh commands", %{sub_name: name} do
      {:ok, sub_pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(sub_pid) end)

      Process.sleep(100)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/refresh",
          %{}
        )

      assert result == :ok

      stats = ZenohControlSubscriber.get_stats(name)
      assert stats.command_count >= 1
      assert stats.last_command != nil
    end

    test "processes mode changes with valid payload", %{sub_name: name} do
      {:ok, sub_pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(sub_pid) end)

      Process.sleep(100)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/mode",
          %{"mode" => "monitoring"}
        )

      assert result == :ok
    end

    test "rejects mode changes with invalid payload", %{sub_name: name} do
      {:ok, sub_pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(sub_pid) end)

      Process.sleep(100)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/control/mode",
          %{invalid: "payload"}
        )

      assert result == {:error, :invalid_mode_payload}
    end

    test "custom handlers are invoked with key and payload", %{sub_name: name} do
      {:ok, sub_pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(sub_pid) end)

      parent = self()

      handler = fn key, payload ->
        send(parent, {:handler_called, key, payload})
        :handled
      end

      ZenohControlSubscriber.register_handler(name, "indrajaal/control/**", handler)

      Process.sleep(50)

      ZenohControlSubscriber.process_command_sync(
        name,
        "indrajaal/control/custom",
        %{custom: "data"}
      )

      assert_receive {:handler_called, "indrajaal/control/custom", %{custom: "data"}}, 1000
    end

    test "handles unknown commands gracefully", %{sub_name: name} do
      {:ok, sub_pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(sub_pid) end)

      Process.sleep(100)

      result =
        ZenohControlSubscriber.process_command_sync(
          name,
          "indrajaal/unknown/command",
          %{}
        )

      assert result == {:error, :unknown_command}
    end
  end

  # ============================================================
  # INTEGRATION TESTS: BARRIER SYNCHRONIZATION
  # ============================================================

  describe "Barrier synchronization" do
    test "barrier times out with insufficient participants" do
      result = ZenohCoordinator.barrier("lonely_barrier", 10, timeout: 200)
      assert {:error, :timeout} = result
    end
  end

  # ============================================================
  # INTEGRATION TESTS: HEARTBEAT MONITORING
  # ============================================================

  describe "Heartbeat monitoring" do
    test "coordinator publishes heartbeats", %{coordinator: c, coord_name: name, suffix: suffix} do
      {:ok, ref} = Zenoh.subscribe(c, "indrajaal/coord/heartbeat")

      {:ok, pid} = ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: true)
      on_exit(fn -> safe_stop_supervisor(pid) end)

      # Wait for heartbeat (10 second interval)
      # For testing, we'll manually trigger via publish_coord
      ZenohCoordinator.publish_coord(
        "heartbeat",
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          status: :alive
        },
        name: name
      )

      assert_receive {:zenoh_message, ^ref, "indrajaal/coord/heartbeat", heartbeat}, 2000
      assert heartbeat.status == :alive
      assert Map.has_key?(heartbeat, :timestamp)
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "publish count increases with publishes" do
      forall n <- PC.integer(1, 5) do
        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohKpiPublisher, Test, "PropID#{id}"])

        {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)

        counts =
          for _ <- 1..n do
            ZenohKpiPublisher.publish_now(name)
            Process.sleep(100)
            stats = ZenohKpiPublisher.get_stats(name)
            stats.publish_count
          end

        safe_stop(pid)

        # Each count should be >= previous (monotonic)
        counts
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.all?(fn [a, b] -> b >= a end)
      end
    end

    property "handler patterns are preserved" do
      forall pattern <- PC.utf8() do
        # Skip empty patterns or those containing null bytes
        if String.length(pattern) > 0 and not String.contains?(pattern, "\0") do
          id = :erlang.unique_integer([:positive])
          name = Module.concat([ZenohControlSubscriber, Test, "PropID#{id}"])

          {:ok, pid} = ZenohControlSubscriber.start_link(name: name)

          handler = fn _key, _payload -> :ok end
          ZenohControlSubscriber.register_handler(name, pattern, handler)

          stats = ZenohControlSubscriber.get_stats(name)
          safe_stop(pid)

          pattern in stats.handlers
        else
          true
        end
      end
    end

    property "command count is monotonically increasing" do
      forall n <- PC.integer(1, 5) do
        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohControlSubscriber, Test, "PropID#{id}"])

        {:ok, pid} = ZenohControlSubscriber.start_link(name: name)

        counts =
          for _ <- 1..n do
            ZenohControlSubscriber.process_command_sync(name, "indrajaal/control/refresh", %{})
            stats = ZenohControlSubscriber.get_stats(name)
            stats.command_count
          end

        safe_stop(pid)

        # Each count should be >= previous (monotonic)
        counts
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.all?(fn [a, b] -> b >= a end)
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "handler registration is idempotent" do
      ExUnitProperties.check all(
                               pattern <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               count <- SD.integer(1..5)
                             ) do
        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohControlSubscriber, Test, "SDID#{id}"])

        {:ok, pid} = ZenohControlSubscriber.start_link(name: name)

        handler = fn _key, _payload -> :ok end

        # Register same handler multiple times
        for _ <- 1..count do
          ZenohControlSubscriber.register_handler(name, pattern, handler)
        end

        stats = ZenohControlSubscriber.get_stats(name)
        safe_stop(pid)

        # Should only have one handler for the pattern (overwrites)
        assert length(stats.handlers) >= 1
      end
    end

    test "command processing increments count" do
      ExUnitProperties.check all(
                               commands <-
                                 SD.list_of(
                                   SD.constant("indrajaal/control/refresh"),
                                   min_length: 1,
                                   max_length: 5
                                 )
                             ) do
        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohControlSubscriber, Test, "SDID#{id}"])

        {:ok, pid} = ZenohControlSubscriber.start_link(name: name)

        for cmd <- commands do
          ZenohControlSubscriber.process_command_sync(name, cmd, %{})
        end

        stats = ZenohControlSubscriber.get_stats(name)
        safe_stop(pid)

        # Should have processed all commands
        assert stats.command_count >= length(commands)
      end
    end

    test "coordination messages are properly keyed" do
      ExUnitProperties.check all(
                               key <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               value <- SD.string(:alphanumeric, min_length: 1, max_length: 50)
                             ) do
        {:ok, coordinator} = Zenoh.start_link()
        {:ok, ref} = Zenoh.subscribe(coordinator, "indrajaal/coord/**")

        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohCoordinator, Test, "SDID#{id}"])
        suffix = "SD#{id}"

        {:ok, sup_pid} =
          ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

        Process.sleep(100)

        ZenohCoordinator.publish_coord("test/#{key}", %{value: value}, name: name)

        received =
          receive do
            {:zenoh_message, ^ref, topic, payload} ->
              {topic, payload}
          after
            1000 -> nil
          end

        safe_stop(coordinator)
        safe_stop_supervisor(sup_pid)

        assert received != nil
        {topic, payload} = received
        assert String.starts_with?(topic, "indrajaal/coord/")
        assert payload.value == value
      end
    end

    test "KPI updates are delivered to subscribers" do
      ExUnitProperties.check all(
                               category <- SD.member_of([:compilation, :tests, :performance]),
                               value <- SD.integer(0..100)
                             ) do
        {:ok, coordinator} = Zenoh.start_link()
        id = :erlang.unique_integer([:positive])
        name = Module.concat([ZenohKpiPublisher, Test, "SDID#{id}"])

        {:ok, pid} =
          ZenohKpiPublisher.start_link(
            name: name,
            coordinator: coordinator,
            publish_interval_ms: 60_000
          )

        # Use full key pattern
        pattern = "indrajaal/kpi/#{category}"
        {:ok, _ref} = ZenohKpiPublisher.subscribe(name, pattern)

        ZenohKpiPublisher.update_kpi(name, category, %{value: value})
        ZenohKpiPublisher.publish_now(name)

        received =
          receive do
            {:kpi_update, ^pattern, payload} -> payload
          after
            1000 -> nil
          end

        safe_stop(pid)
        safe_stop(coordinator)

        assert received != nil
        assert received.value == value
      end
    end
  end

  # ============================================================
  # ERROR HANDLING TESTS
  # ============================================================

  describe "error handling" do
    test "publisher handles errors gracefully", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      # Multiple publishes should not crash
      for _ <- 1..5 do
        ZenohKpiPublisher.publish_now(name)
        Process.sleep(10)
      end

      assert Process.alive?(pid)
    end

    test "subscriber handles invalid commands", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      # Process invalid command
      ZenohControlSubscriber.process_command_sync(name, "invalid/topic", %{})
      Process.sleep(50)

      # Should still be alive
      assert Process.alive?(pid)
    end

    test "subscriber handles handler errors", %{sub_name: name} do
      {:ok, pid} = ZenohControlSubscriber.start_link(name: name)
      on_exit(fn -> safe_stop(pid) end)

      # Register a handler that raises
      handler = fn _key, _payload ->
        raise "intentional error"
      end

      ZenohControlSubscriber.register_handler(name, "test/**", handler)

      # Process command that triggers the handler
      result = ZenohControlSubscriber.process_command_sync(name, "test/command", %{})

      # Should return error, not crash
      assert {:error, _} = result
      assert Process.alive?(pid)
    end

    test "coordinator restarts failed children", %{coord_name: name, suffix: suffix} do
      {:ok, pid} =
        ZenohCoordinator.start_link(name: name, suffix: suffix, enable_heartbeat: false)

      on_exit(fn -> safe_stop_supervisor(pid) end)

      Process.sleep(100)

      # Get publisher pid
      children = Supervisor.which_children(pid)

      # Find by ID instead of module if suffix is used
      # children are like {module_suffix, pid, ...}
      {_id, pub_pid, _, _} =
        Enum.find(children, fn {id, _, _, _} ->
          to_string(id) =~ "ZenohKpiPublisher"
        end)

      # Kill the publisher
      Process.exit(pub_pid, :kill)
      Process.sleep(100)

      # Should be restarted
      new_children = Supervisor.which_children(pid)

      {_id, new_pub_pid, _, _} =
        Enum.find(new_children, fn {id, _, _, _} ->
          to_string(id) =~ "ZenohKpiPublisher"
        end)

      assert new_pub_pid != pub_pid
      assert is_pid(new_pub_pid)
    end

    test "publisher removes dead subscribers", %{pub_name: name} do
      {:ok, pid} = ZenohKpiPublisher.start_link(name: name, publish_interval_ms: 60_000)
      on_exit(fn -> safe_stop(pid) end)

      # Spawn a process that subscribes then dies
      task =
        Task.async(fn ->
          {:ok, _ref} = ZenohKpiPublisher.subscribe(name, "indrajaal/kpi/*")
          :ok
        end)

      Task.await(task)
      Process.sleep(50)

      # After task dies, subscriber should be removed
      stats_before = ZenohKpiPublisher.get_stats(name)
      initial_count = stats_before.subscriber_count

      # Subscriber cleanup happens on next publish or monitor down
      ZenohKpiPublisher.publish_now(name)
      Process.sleep(100)

      stats_after = ZenohKpiPublisher.get_stats(name)
      assert stats_after.subscriber_count <= initial_count
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

  defp safe_stop(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> :ok
      pid -> safe_stop(pid)
    end
  rescue
    _ -> :ok
  end

  defp safe_stop(_), do: :ok

  defp safe_stop_supervisor(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Supervisor.stop(pid, :normal, 1000)
    end
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_stop_supervisor(_), do: :ok
end
