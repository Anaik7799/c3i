defmodule Indrajaal.Observability.ZenohControlSubscriberTest do
  @moduledoc """
  Tests for ZenohControlSubscriber CEPAF command processing.

  WHAT: Validates control command subscription, processing, and acknowledgment.
  WHY: SC-ZENOH-004 requires verified command handling patterns.
  CONSTRAINTS: Uses ZenohTestCoordinator for deterministic testing.
  """

  use ExUnit.Case, async: false
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.ZenohControlSubscriber
  alias Indrajaal.Test.ZenohTestCoordinator, as: Zenoh

  @control_prefix "indrajaal/control"

  describe "start_link/1" do
    test "starts successfully with default options" do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "initializes with zero command count" do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

      stats = GenServer.call(pid, :get_stats)
      assert stats.command_count == 0
      assert stats.last_command == nil
      assert stats.handlers == []

      GenServer.stop(pid)
    end
  end

  describe "register_handler/2" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "registers a handler for a pattern", %{pid: pid} do
      handler = fn _key, _payload -> :handled end

      assert :ok = GenServer.call(pid, {:register_handler, "test/pattern", handler})

      stats = GenServer.call(pid, :get_stats)
      assert "test/pattern" in stats.handlers
    end

    test "overwrites existing handler for same pattern", %{pid: pid} do
      handler1 = fn _key, _payload -> :first end
      handler2 = fn _key, _payload -> :second end

      GenServer.call(pid, {:register_handler, "test/pattern", handler1})
      GenServer.call(pid, {:register_handler, "test/pattern", handler2})

      stats = GenServer.call(pid, :get_stats)
      # Should only have one entry
      assert Enum.count(stats.handlers, &(&1 == "test/pattern")) == 1
    end

    test "supports multiple different patterns", %{pid: pid} do
      handler = fn _key, _payload -> :ok end

      GenServer.call(pid, {:register_handler, "pattern/one", handler})
      GenServer.call(pid, {:register_handler, "pattern/two", handler})
      GenServer.call(pid, {:register_handler, "pattern/three/**", handler})

      stats = GenServer.call(pid, :get_stats)
      assert length(stats.handlers) == 3
    end
  end

  describe "unregister_handler/1" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "removes a registered handler", %{pid: pid} do
      handler = fn _key, _payload -> :ok end

      GenServer.call(pid, {:register_handler, "test/pattern", handler})
      assert "test/pattern" in GenServer.call(pid, :get_stats).handlers

      GenServer.call(pid, {:unregister_handler, "test/pattern"})
      refute "test/pattern" in GenServer.call(pid, :get_stats).handlers
    end

    test "handles unregistering non-existent handler gracefully", %{pid: pid} do
      assert :ok = GenServer.call(pid, {:unregister_handler, "nonexistent/pattern"})
    end
  end

  describe "process_command_sync/2" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "uses registered handler for matching pattern", %{pid: pid} do
      handler = fn _key, payload -> {:custom, payload.value} end
      GenServer.call(pid, {:register_handler, "custom/**", handler})

      result = GenServer.call(pid, {:process_command_sync, "custom/test", %{value: 42}})
      assert result == {:custom, 42}
    end

    test "increments command count", %{pid: pid} do
      GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", %{}})
      GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", %{}})

      stats = GenServer.call(pid, :get_stats)
      assert stats.command_count == 2
    end

    test "records last command details", %{pid: pid} do
      payload = %{test: "data"}
      GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", payload})

      stats = GenServer.call(pid, :get_stats)
      assert stats.last_command.key == "#{@control_prefix}/refresh"
      assert stats.last_command.payload == payload
      assert stats.last_command.result == :ok
      assert %DateTime{} = stats.last_command.at
    end

    test "handles handler exceptions gracefully", %{pid: pid} do
      handler = fn _key, _payload -> raise "intentional error" end
      GenServer.call(pid, {:register_handler, "error/**", handler})

      result = GenServer.call(pid, {:process_command_sync, "error/test", %{}})
      assert {:error, "intentional error"} = result
    end
  end

  describe "default handlers" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "refresh command returns :ok", %{pid: pid} do
      result = GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", %{}})
      assert result == :ok
    end

    test "mode command with valid mode returns :ok", %{pid: pid} do
      result =
        GenServer.call(
          pid,
          {:process_command_sync, "#{@control_prefix}/mode", %{"mode" => "dark"}}
        )

      assert result == :ok
    end

    test "mode command with invalid payload returns error", %{pid: pid} do
      result =
        GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/mode", %{invalid: true}})

      assert result == {:error, :invalid_mode_payload}
    end

    test "agent commands return :ok", %{pid: pid} do
      result =
        GenServer.call(
          pid,
          {:process_command_sync, "#{@control_prefix}/agent/worker_1/restart", %{}}
        )

      assert result == :ok
    end

    test "unknown commands return error", %{pid: pid} do
      result = GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/unknown", %{}})
      assert result == {:error, :unknown_command}
    end
  end

  describe "pattern matching" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "single wildcard matches one segment", %{pid: pid} do
      handler = fn _key, _payload -> :matched end
      GenServer.call(pid, {:register_handler, "test/*/end", handler})

      # Should match
      assert :matched = GenServer.call(pid, {:process_command_sync, "test/middle/end", %{}})

      # Should not match (two segments)
      assert {:error, :unknown_command} =
               GenServer.call(pid, {:process_command_sync, "test/a/b/end", %{}})
    end

    test "double wildcard matches multiple segments", %{pid: pid} do
      handler = fn _key, _payload -> :matched end
      GenServer.call(pid, {:register_handler, "test/**/end", handler})

      # Should match various depths
      assert :matched = GenServer.call(pid, {:process_command_sync, "test/a/end", %{}})
      assert :matched = GenServer.call(pid, {:process_command_sync, "test/a/b/end", %{}})
      assert :matched = GenServer.call(pid, {:process_command_sync, "test/a/b/c/end", %{}})
    end

    test "exact pattern matches exactly", %{pid: pid} do
      handler = fn _key, _payload -> :exact end
      GenServer.call(pid, {:register_handler, "exact/match/only", handler})

      assert :exact = GenServer.call(pid, {:process_command_sync, "exact/match/only", %{}})

      assert {:error, :unknown_command} =
               GenServer.call(pid, {:process_command_sync, "exact/match", %{}})
    end
  end

  describe "zenoh message handling" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

      # Subscribe to ack messages
      {:ok, ack_ref} = Zenoh.subscribe(coordinator, "#{@control_prefix}/**/ack")

      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator, ack_ref: ack_ref}
    end

    test "processes zenoh_message and sends acknowledgment", %{
      pid: pid,
      coordinator: coordinator,
      ack_ref: ack_ref
    } do
      # Send a zenoh message directly to the subscriber
      ref = make_ref()
      send(pid, {:zenoh_message, ref, "#{@control_prefix}/refresh", %{}})

      # Wait for acknowledgment
      assert_receive {:zenoh_message, ^ack_ref, "#{@control_prefix}/refresh/ack", ack_payload},
                     1000

      assert ack_payload.status == :ok
      assert is_binary(ack_payload.timestamp)

      # Verify stats updated
      stats = GenServer.call(pid, :get_stats)
      assert stats.command_count == 1
    end

    test "processes zenoh_request and sends reply", %{pid: pid, coordinator: coordinator} do
      # Create a request reference
      req_ref = make_ref()

      # Subscribe to get the reply handling
      {:ok, _sub_ref} = Zenoh.subscribe(coordinator, "#{@control_prefix}/refresh")

      # Send request to subscriber
      send(pid, {:zenoh_request, req_ref, "#{@control_prefix}/refresh", %{}, self()})

      # Give time for processing
      Process.sleep(50)

      stats = GenServer.call(pid, :get_stats)
      assert stats.command_count == 1
    end

    test "handles unknown messages gracefully", %{pid: pid} do
      send(pid, {:unknown_message_type, "data"})

      # Should not crash
      assert Process.alive?(pid)
    end
  end

  describe "get_stats/0" do
    setup do
      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid, coordinator: coordinator}
    end

    test "returns complete statistics", %{pid: pid} do
      # Register some handlers
      GenServer.call(pid, {:register_handler, "pattern/one", fn _, _ -> :ok end})
      GenServer.call(pid, {:register_handler, "pattern/two", fn _, _ -> :ok end})

      # Process some commands
      GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", %{}})

      stats = GenServer.call(pid, :get_stats)

      assert is_integer(stats.command_count)
      assert stats.command_count == 1
      assert is_list(stats.handlers)
      assert length(stats.handlers) == 2
      assert is_integer(stats.subscriptions_active)
      assert stats.subscriptions_active >= 0
      assert is_map(stats.last_command)
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS - PropCheck
  # ============================================================

  describe "property tests (PropCheck)" do
    property "any valid key can be processed without crash" do
      forall key <- PC.utf8() do
        {:ok, coordinator} = Zenoh.start_link()
        {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

        try do
          # Should not crash regardless of key
          _result = GenServer.call(pid, {:process_command_sync, key, %{}})
          true
        after
          GenServer.stop(pid)
        end
      end
    end

    property "command count always increments monotonically" do
      forall commands <- PC.list(PC.tuple([PC.utf8(), PC.map(PC.atom(), PC.any())])) do
        {:ok, coordinator} = Zenoh.start_link()
        {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

        try do
          counts =
            Enum.map(commands, fn {key, payload} ->
              GenServer.call(pid, {:process_command_sync, key, payload})
              GenServer.call(pid, :get_stats).command_count
            end)

          # Verify monotonic increase
          counts == Enum.sort(counts) and
            (counts == [] or hd(counts) >= 1)
        after
          GenServer.stop(pid)
        end
      end
    end

    property "handlers can be registered and unregistered for any pattern" do
      forall pattern <- PC.utf8() do
        {:ok, coordinator} = Zenoh.start_link()
        {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

        try do
          handler = fn _, _ -> :ok end

          :ok = GenServer.call(pid, {:register_handler, pattern, handler})
          stats1 = GenServer.call(pid, :get_stats)

          :ok = GenServer.call(pid, {:unregister_handler, pattern})
          stats2 = GenServer.call(pid, :get_stats)

          pattern in stats1.handlers and pattern not in stats2.handlers
        after
          GenServer.stop(pid)
        end
      end
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS - StreamData
  # ============================================================

  describe "property tests (StreamData)" do
    # SC-PROP-023: Use ExUnitProperties.check_all for StreamData-based properties
    test "handler results are captured in last_command (property)" do
      Enum.each(1..10, fn _iteration ->
        result = Enum.random([:ok, {:error, :test}])
        key = 8 |> :crypto.strong_rand_bytes() |> Base.encode64(padding: false)

        {:ok, coordinator} = Zenoh.start_link()
        {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

        try do
          handler = fn _, _ -> result end
          GenServer.call(pid, {:register_handler, key, handler})
          GenServer.call(pid, {:process_command_sync, key, %{}})

          stats = GenServer.call(pid, :get_stats)
          assert stats.last_command.result == result
        after
          GenServer.stop(pid)
        end
      end)
    end

    # SC-PROP-024: Simplified property test using iteration
    test "multiple handlers don't interfere with each other (property)" do
      mapped_patterns = Enum.map(1..3, fn i -> "handler_#{i}_#{:rand.uniform(1000)}" end)

      patterns =
        mapped_patterns
        |> Enum.uniq()

      {:ok, coordinator} = Zenoh.start_link()
      {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

      try do
        # Register handlers with unique results
        Enum.each(patterns, fn pattern ->
          handler = fn _, _ -> {:result, pattern} end
          GenServer.call(pid, {:register_handler, pattern, handler})
        end)

        # Verify each handler works independently
        results =
          Enum.map(patterns, fn pattern ->
            GenServer.call(pid, {:process_command_sync, pattern, %{}})
          end)

        expected = Enum.map(patterns, fn p -> {:result, p} end)
        assert results == expected
      after
        GenServer.stop(pid)
      end
    end

    # SC-PROP-024: Simplified stats validation test
    test "stats always contain valid structure (property)" do
      Enum.each(0..5, fn num_commands ->
        {:ok, coordinator} = Zenoh.start_link()
        {:ok, pid} = ZenohControlSubscriber.start_link(coordinator: coordinator)

        try do
          # Execute random number of commands
          for _ <- 1..num_commands do
            GenServer.call(pid, {:process_command_sync, "#{@control_prefix}/refresh", %{}})
          end

          stats = GenServer.call(pid, :get_stats)

          assert is_integer(stats.command_count)
          assert stats.command_count == num_commands
          assert is_list(stats.handlers)
          assert is_integer(stats.subscriptions_active)

          if num_commands > 0 do
            assert is_map(stats.last_command)
            assert Map.has_key?(stats.last_command, :key)
            assert Map.has_key?(stats.last_command, :payload)
            assert Map.has_key?(stats.last_command, :result)
            assert Map.has_key?(stats.last_command, :at)
          end
        after
          GenServer.stop(pid)
        end
      end)
    end
  end
end
