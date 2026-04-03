defmodule Indrajaal.Observability.Fractal.FractalControlTest do
  @moduledoc """
  TDG Tests for FractalControl GenServer.

  WHAT: Comprehensive property-based and unit tests for the Fractal Logging
        System's central state manager.

  WHY: Ensure STAMP compliance (SC-LOG-001, SC-LOG-002, SC-LOG-005) and
       verify O(1) ETS lookup performance for hot-path log decisions.

  CONSTRAINTS:
  - TDG: Tests written BEFORE implementation modifications
  - Dual property testing: PropCheck + ExUnitProperties (EP-GEN-014 compliant)
  - STAMP validation: All safety constraints verified

  ## Test Categories

  1. Decision Engine Tests - should_log?/3, get_effective_level/2
  2. Boost Management Tests - focus/4, remove_boost/1, TTL validation
  3. Load Shedding Tests - SC-LOG-002 compliance
  4. Subscription Tests - Zenoh-style pub/sub
  5. ETS Optimization Tests - O(1) lookup verification
  6. Property-Based Tests - Edge case discovery
  """

  use ExUnit.Case, async: false
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]

  # EP-GEN-014: Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC

  # Import ExUnitProperties but exclude conflicting functions
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Observability.Fractal.FractalControl

  @moduletag :fractal_control

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Get or start FractalControl
    pid =
      case Process.whereis(FractalControl) do
        nil ->
          # Start fresh if not running
          {:ok, p} = FractalControl.start_link(default_policy: :l4)
          p

        existing_pid ->
          # Reuse existing but reset all state
          FractalControl.reset()
          existing_pid
      end

    on_exit(fn ->
      # Reset state after each test (handle dead processes gracefully)
      try do
        case Process.whereis(FractalControl) do
          nil -> :ok
          _pid -> FractalControl.reset()
        end
      catch
        :exit, _ -> :ok
      end
    end)

    %{pid: pid}
  end

  # ============================================================
  # DECISION ENGINE TESTS
  # ============================================================

  describe "should_log?/3" do
    test "returns true for level >= default policy" do
      # Default policy is :l4
      assert FractalControl.should_log?("Indrajaal/Alarms/create", :l4, %{})
      assert FractalControl.should_log?("Indrajaal/Alarms/create", :l5, %{})
    end

    test "returns false for level < default policy" do
      # L1, L2, L3 are below default L4
      refute FractalControl.should_log?("Indrajaal/Debug/trace", :l1, %{})
      refute FractalControl.should_log?("Indrajaal/Debug/trace", :l2, %{})
      refute FractalControl.should_log?("Indrajaal/Debug/trace", :l3, %{})
    end

    test "respects active boost to lower threshold" do
      # Create boost to enable L2 logging
      {:ok, _boost_id} = FractalControl.focus("Indrajaal/Debug/**", :l2, 60_000, "test")

      # Now L2 should be enabled for boosted key
      assert FractalControl.should_log?("Indrajaal/Debug/trace", :l2, %{})
      assert FractalControl.should_log?("Indrajaal/Debug/trace", :l3, %{})
    end

    test "handles empty baggage context" do
      assert is_boolean(FractalControl.should_log?("Indrajaal/Test", :l4, %{}))
    end

    test "handles baggage with filter matching" do
      # Create boost with filter
      :ok = FractalControl.set_policy("Indrajaal/Users/**", :l4)

      # Boost for specific user
      {:ok, _} = FractalControl.focus("Indrajaal/Users/**", :l1, 60_000, "test")

      # Should match with any baggage since filter is empty
      assert FractalControl.should_log?("Indrajaal/Users/login", :l1, %{user_id: "123"})
    end
  end

  describe "get_effective_level/2" do
    test "returns default policy when no boosts or policies" do
      assert FractalControl.get_effective_level("Unknown/Module", %{}) == :l4
    end

    test "returns module-specific policy when set" do
      :ok = FractalControl.set_policy("Indrajaal/Security", :l3)

      assert FractalControl.get_effective_level("Indrajaal/Security/audit", %{}) == :l3
    end

    test "returns boost level when more verbose than policy" do
      :ok = FractalControl.set_policy("Indrajaal/Alarms", :l4)
      {:ok, _} = FractalControl.focus("Indrajaal/Alarms/**", :l2, 60_000, "debug")

      # Boost should take precedence (L2 < L4)
      assert FractalControl.get_effective_level("Indrajaal/Alarms/create", %{}) == :l2
    end

    test "longest prefix match wins for policies" do
      :ok = FractalControl.set_policy("Indrajaal", :l4)
      :ok = FractalControl.set_policy("Indrajaal/Alarms", :l3)
      :ok = FractalControl.set_policy("Indrajaal/Alarms/Critical", :l2)

      assert FractalControl.get_effective_level("Indrajaal/Alarms/Critical/fire", %{}) == :l2
      assert FractalControl.get_effective_level("Indrajaal/Alarms/minor", %{}) == :l3
      assert FractalControl.get_effective_level("Indrajaal/Other", %{}) == :l4
    end
  end

  # ============================================================
  # BOOST MANAGEMENT TESTS (SC-LOG-005)
  # ============================================================

  describe "focus/4 - SC-LOG-005 Boost TTL" do
    test "creates boost with valid parameters" do
      {:ok, boost_id} = FractalControl.focus("Indrajaal/**", :l2, 60_000, "test_user")

      assert is_binary(boost_id)
      assert String.length(boost_id) == 8
    end

    test "rejects TTL exceeding maximum (1 hour)" do
      max_plus_one = 3_600_001

      assert {:error, :ttl_exceeds_maximum} =
               FractalControl.focus("Indrajaal/**", :l2, max_plus_one, "test")
    end

    test "rejects zero or negative TTL" do
      assert {:error, :invalid_ttl} = FractalControl.focus("Indrajaal/**", :l2, 0, "test")
      assert {:error, :invalid_ttl} = FractalControl.focus("Indrajaal/**", :l2, -1000, "test")
    end

    test "rejects invalid key expression" do
      assert {:error, :invalid_key_expr} = FractalControl.focus("", :l2, 60_000, "test")
      assert {:error, :invalid_key_expr} = FractalControl.focus("   ", :l2, 60_000, "test")
    end

    test "rejects invalid depth level" do
      assert {:error, :invalid_depth} =
               FractalControl.focus("Indrajaal/**", :invalid, 60_000, "t")

      assert {:error, :invalid_depth} = FractalControl.focus("Indrajaal/**", 3, 60_000, "test")
    end

    test "boost expires after TTL" do
      # Create boost with very short TTL
      {:ok, boost_id} = FractalControl.focus("Indrajaal/Test/**", :l1, 100, "test")

      # Verify boost is active
      boosts = FractalControl.get_active_boosts()
      assert Enum.any?(boosts, fn b -> b.id == boost_id end)

      # Wait for expiration
      Process.sleep(150)

      # Trigger expiration check
      send(Process.whereis(FractalControl), :expire_boosts)
      Process.sleep(50)

      # Verify boost is expired
      boosts = FractalControl.get_active_boosts()
      refute Enum.any?(boosts, fn b -> b.id == boost_id end)
    end
  end

  describe "remove_boost/1" do
    test "removes existing boost" do
      {:ok, boost_id} = FractalControl.focus("Indrajaal/**", :l2, 60_000, "test")

      assert :ok = FractalControl.remove_boost(boost_id)

      boosts = FractalControl.get_active_boosts()
      refute Enum.any?(boosts, fn b -> b.id == boost_id end)
    end

    test "returns error for non-existent boost" do
      assert {:error, :not_found} = FractalControl.remove_boost("nonexistent")
    end
  end

  # ============================================================
  # LOAD SHEDDING TESTS (SC-LOG-002)
  # ============================================================

  describe "load_shedding?/0 - SC-LOG-002" do
    test "returns false when not shedding" do
      refute FractalControl.load_shedding?()
    end

    test "activates when CPU exceeds threshold" do
      # Simulate high CPU
      FractalControl.update_resource_metrics(95.0, 50.0)
      Process.sleep(50)

      assert FractalControl.load_shedding?()
    end

    test "activates when memory exceeds threshold" do
      # Simulate high memory
      FractalControl.update_resource_metrics(50.0, 90.0)
      Process.sleep(50)

      assert FractalControl.load_shedding?()
    end

    test "deactivates with hysteresis when resources recover" do
      # Activate shedding
      FractalControl.update_resource_metrics(95.0, 50.0)
      Process.sleep(50)
      assert FractalControl.load_shedding?()

      # Resources recover below hysteresis margin
      FractalControl.update_resource_metrics(75.0, 70.0)
      Process.sleep(50)

      refute FractalControl.load_shedding?()
    end

    test "only allows L4/L5 during shedding" do
      # Activate shedding
      FractalControl.update_resource_metrics(95.0, 50.0)
      Process.sleep(50)

      # L1-L3 should be blocked
      refute FractalControl.should_log?("Any/Key", :l1, %{})
      refute FractalControl.should_log?("Any/Key", :l2, %{})
      refute FractalControl.should_log?("Any/Key", :l3, %{})

      # L4-L5 should still work
      assert FractalControl.should_log?("Any/Key", :l4, %{})
      assert FractalControl.should_log?("Any/Key", :l5, %{})
    end
  end

  # ============================================================
  # SUBSCRIPTION TESTS
  # ============================================================

  describe "subscribe/3 and unsubscribe/1" do
    test "creates subscription and returns ID" do
      callback = fn _entry -> :ok end
      sub_id = FractalControl.subscribe("Indrajaal/**", :l4, callback)

      assert is_binary(sub_id)
      assert String.length(sub_id) == 8
    end

    test "unsubscribes successfully" do
      callback = fn _entry -> :ok end
      sub_id = FractalControl.subscribe("Indrajaal/**", :l4, callback)

      assert :ok = FractalControl.unsubscribe(sub_id)
    end

    test "returns error for non-existent subscription" do
      assert {:error, :not_found} = FractalControl.unsubscribe("nonexistent")
    end
  end

  describe "notify/1 - SC-LOG-001 Async Dispatch" do
    test "dispatches to matching subscribers asynchronously" do
      test_pid = self()

      callback = fn entry ->
        send(test_pid, {:received, entry})
      end

      _sub_id = FractalControl.subscribe("Indrajaal/Test/**", :l4, callback)

      # Send notification
      entry = %{key: "Indrajaal/Test/event", level: :l4, message: "test"}
      :ok = FractalControl.notify(entry)

      # Should receive asynchronously
      assert_receive {:received, ^entry}, 1000
    end

    test "filters by level" do
      test_pid = self()

      callback = fn entry ->
        send(test_pid, {:received, entry})
      end

      _sub_id = FractalControl.subscribe("Indrajaal/**", :l4, callback)

      # Send L3 entry (below subscription level)
      entry = %{key: "Indrajaal/Test", level: :l3, message: "should not receive"}
      :ok = FractalControl.notify(entry)

      refute_receive {:received, _}, 200
    end

    test "does not block on slow callback" do
      slow_callback = fn _entry ->
        Process.sleep(5000)
      end

      _sub_id = FractalControl.subscribe("Indrajaal/**", :l4, slow_callback)

      entry = %{key: "Indrajaal/Test", level: :l4, message: "test"}

      # Should return immediately (SC-LOG-001)
      start = System.monotonic_time(:millisecond)
      :ok = FractalControl.notify(entry)
      elapsed = System.monotonic_time(:millisecond) - start

      # Should take < 100ms (async dispatch)
      assert elapsed < 100
    end
  end

  # ============================================================
  # ETS OPTIMIZATION TESTS
  # ============================================================

  describe "ETS optimization" do
    test "config table exists with correct options" do
      assert :ets.whereis(:fractal_config) != :undefined

      info = :ets.info(:fractal_config)
      assert info[:type] == :ordered_set
      assert info[:read_concurrency] == true
    end

    test "boosts table exists with correct options" do
      assert :ets.whereis(:fractal_boosts) != :undefined

      info = :ets.info(:fractal_boosts)
      assert info[:type] == :set
      assert info[:write_concurrency] == true
    end

    test "warmup_ets syncs state to ETS" do
      :ok = FractalControl.set_default_policy(:l3)
      :ok = FractalControl.warmup_ets()

      [{:default_policy, level}] = :ets.lookup(:fractal_config, :default_policy)
      assert level == :l3
    end
  end

  # ============================================================
  # STATUS AND METRICS TESTS
  # ============================================================

  describe "get_status/0" do
    test "returns comprehensive status" do
      status = FractalControl.get_status()

      assert Map.has_key?(status, :default_policy)
      assert Map.has_key?(status, :policy_count)
      assert Map.has_key?(status, :active_boosts)
      assert Map.has_key?(status, :subscribers)
      assert Map.has_key?(status, :shedding)
      assert Map.has_key?(status, :node_id)
      assert Map.has_key?(status, :metrics)
    end

    test "tracks boost count" do
      {:ok, _} = FractalControl.focus("Test1/**", :l2, 60_000, "test")
      {:ok, _} = FractalControl.focus("Test2/**", :l2, 60_000, "test")

      status = FractalControl.get_status()
      assert status.active_boosts == 2
    end

    test "tracks subscriber count" do
      callback = fn _ -> :ok end
      FractalControl.subscribe("Test1/**", :l4, callback)
      FractalControl.subscribe("Test2/**", :l4, callback)

      status = FractalControl.get_status()
      assert status.subscribers == 2
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================

  describe "PropCheck property tests" do
    property "should_log? always returns boolean" do
      forall {key, level_int} <- {PC.binary(), PC.integer(1, 5)} do
        level = FractalControl.int_to_level(level_int)
        result = FractalControl.should_log?(key, level, %{})
        is_boolean(result)
      end
    end

    property "boost TTL validation is strict" do
      forall ttl <- PC.integer() do
        result = FractalControl.focus("Test/**", :l2, ttl, "prop_test")

        cond do
          ttl <= 0 -> result == {:error, :invalid_ttl}
          ttl > 3_600_000 -> result == {:error, :ttl_exceeds_maximum}
          true -> match?({:ok, _}, result)
        end
      end
    end

    property "policy levels are ordered correctly" do
      forall {level1_int, level2_int} <- {PC.integer(1, 5), PC.integer(1, 5)} do
        level1 = FractalControl.int_to_level(level1_int)
        level2 = FractalControl.int_to_level(level2_int)

        # If level1_int >= level2_int, then level1 should be enabled when level2 is the policy
        :ok = FractalControl.set_default_policy(level2)
        result = FractalControl.should_log?("Test/Key", level1, %{})

        if level1_int >= level2_int do
          result == true
        else
          result == false
        end
      end
    end
  end

  # ============================================================
  # PROPERTY-BASED TESTS (ExUnitProperties)
  # ============================================================

  describe "ExUnitProperties property tests" do
    test "key expressions always produce deterministic results" do
      ExUnitProperties.check all(
                               key <-
                                 StreamData.string(:alphanumeric, min_length: 1, max_length: 50),
                               level_int <- StreamData.integer(1..5),
                               max_runs: 50
                             ) do
        level = FractalControl.int_to_level(level_int)

        result1 = FractalControl.should_log?(key, level, %{})
        result2 = FractalControl.should_log?(key, level, %{})

        assert result1 == result2, "should_log? must be deterministic"
      end
    end

    test "get_effective_level returns valid fractal levels" do
      valid_levels = [:l1, :l2, :l3, :l4, :l5]

      ExUnitProperties.check all(
                               key <-
                                 StreamData.string(:alphanumeric, min_length: 1, max_length: 50),
                               max_runs: 50
                             ) do
        level = FractalControl.get_effective_level(key, %{})
        assert level in valid_levels
      end
    end

    test "boost creation with valid TTL always succeeds" do
      ExUnitProperties.check all(
                               key <-
                                 StreamData.string(:alphanumeric, min_length: 1, max_length: 30),
                               level_int <- StreamData.integer(1..5),
                               ttl <- StreamData.integer(1..3_600_000),
                               max_runs: 25
                             ) do
        # Ensure key is not empty
        key_value = if key == "", do: "test", else: key
        key_expr = "#{key_value}/**"
        level = FractalControl.int_to_level(level_int)

        result = FractalControl.focus(key_expr, level, ttl, "property_test")
        assert match?({:ok, _}, result), "Valid boost should succeed: #{inspect(result)}"
      end
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles wildcard key expressions" do
      {:ok, _} = FractalControl.focus("**", :l1, 60_000, "test")

      # Should match any key
      assert FractalControl.should_log?("Any/Path/Here", :l1, %{})
      assert FractalControl.should_log?("Another/Deep/Nested/Path", :l1, %{})
    end

    test "handles single wildcard key expressions" do
      {:ok, _} = FractalControl.focus("Indrajaal/*/create", :l2, 60_000, "test")

      assert FractalControl.should_log?("Indrajaal/Alarms/create", :l2, %{})
    end

    test "handles concurrent boost operations" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            FractalControl.focus("Concurrent/#{i}/**", :l2, 60_000, "concurrent_test")
          end)
        end

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)

      # All boosts should be active
      boosts = FractalControl.get_active_boosts()
      assert length(boosts) == 10
    end

    test "handles rapid policy changes" do
      for level <- [:l1, :l2, :l3, :l4, :l5, :l4, :l3, :l2, :l1] do
        :ok = FractalControl.set_default_policy(level)
      end

      # Should end up at :l1
      status = FractalControl.get_status()
      assert status.default_policy == :l1
    end

    test "handles unicode key expressions" do
      {:ok, boost_id} = FractalControl.focus("Indrajaal/Alarmas/**", :l2, 60_000, "test")

      assert is_binary(boost_id)
      assert FractalControl.should_log?("Indrajaal/Alarmas/fuego", :l2, %{})
    end

    test "subscriber callback error does not crash GenServer" do
      crashing_callback = fn _entry ->
        raise "Intentional crash"
      end

      _sub_id = FractalControl.subscribe("Test/**", :l4, crashing_callback)

      entry = %{key: "Test/crash", level: :l4, message: "trigger crash"}

      # Should not crash
      :ok = FractalControl.notify(entry)
      Process.sleep(100)

      # GenServer should still be alive
      status = FractalControl.get_status()
      assert is_map(status)
    end
  end

  # ============================================================
  # STAMP COMPLIANCE VERIFICATION TESTS
  # ============================================================

  describe "STAMP compliance verification" do
    @tag :stamp
    test "SC-LOG-001: notify is non-blocking" do
      # Create many subscribers
      for _ <- 1..100 do
        FractalControl.subscribe("Benchmark/**", :l4, fn _ ->
          Process.sleep(100)
        end)
      end

      entry = %{key: "Benchmark/test", level: :l4, message: "benchmark"}

      # Measure notify time
      {time, :ok} = :timer.tc(fn -> FractalControl.notify(entry) end)

      # Should be < 1ms (1000 microseconds)
      assert time < 1000, "notify took #{time}us, should be < 1000us"
    end

    @tag :stamp
    test "SC-LOG-002: load shedding activates at threshold" do
      # Verify thresholds
      status = FractalControl.get_status()
      refute status.shedding

      # Simulate crossing CPU threshold
      FractalControl.update_resource_metrics(91.0, 50.0)
      Process.sleep(50)

      status = FractalControl.get_status()
      assert status.shedding
    end

    @tag :stamp
    test "SC-LOG-005: boost TTL is mandatory and enforced" do
      # Default TTL should be 5 minutes
      {:ok, boost_id} = FractalControl.focus("TTL/Test/**", :l2, 300_000, "test")

      boosts = FractalControl.get_active_boosts()
      boost = Enum.find(boosts, fn b -> b.id == boost_id end)

      # Verify expires_at is set correctly
      expected_expiry = DateTime.add(boost.created_at, 300_000, :millisecond)

      # Allow 1 second tolerance for timing
      diff = DateTime.diff(boost.expires_at, expected_expiry, :second)
      assert abs(diff) <= 1
    end
  end
end
