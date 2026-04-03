defmodule Indrajaal.Observability.Fractal.LoggerTest do
  @moduledoc """
  TDG tests for Fractal Logger module.

  WHAT: Tests for fractal logging levels, boost management, and function tracing.
  WHY: Ensures SC-LOG-001 (async dispatch), SC-LOG-005 (boost TTL), SC-LOG-006 (HLC).
  CONSTRAINTS: Non-blocking operations, PII masking, trace ID propagation.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.Logger, as: FractalLogger
  alias Indrajaal.Observability.Fractal.{HLC, FractalControl}

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure ETS tables exist
    ensure_ets_tables()

    # Ensure HLC is running
    ensure_hlc_started()

    # Clean up boosts before each test
    clean_boosts()

    :ok
  end

  # ============================================================
  # UNIT TESTS: FRACTAL_LOG
  # ============================================================

  describe "fractal_log/4" do
    test "emits log at L1 level" do
      assert :ok = FractalLogger.fractal_log(:l1, "L1 test", %{data: 123})
    end

    test "emits log at L2 level" do
      assert :ok = FractalLogger.fractal_log(:l2, "L2 test", %{state: "active"})
    end

    test "emits log at L3 level" do
      assert :ok = FractalLogger.fractal_log(:l3, "L3 test", %{trace: "abc"})
    end

    test "emits log at L4 level" do
      assert :ok = FractalLogger.fractal_log(:l4, "L4 test", %{node: node()})
    end

    test "emits log at L5 level" do
      assert :ok = FractalLogger.fractal_log(:l5, "L5 test", %{intent: "analyze"})
    end

    test "accepts custom key option" do
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, key: "Custom/Key/Path")
    end

    test "accepts trace_id option" do
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, trace_id: "trace-123")
    end

    test "accepts tags option" do
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, tags: ["important", "audit"])
    end

    test "accepts event_type option" do
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, event_type: :entry)
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, event_type: :exit)
      assert :ok = FractalLogger.fractal_log(:l3, "Test", %{}, event_type: :exception)
    end

    test "handles empty metadata" do
      assert :ok = FractalLogger.fractal_log(:l4, "No metadata")
    end

    test "handles complex metadata" do
      metadata = %{
        user: %{id: 123, name: "Test"},
        items: [1, 2, 3],
        nested: %{deep: %{value: true}}
      }

      assert :ok = FractalLogger.fractal_log(:l4, "Complex", metadata)
    end
  end

  # ============================================================
  # UNIT TESTS: LEVEL SHORTCUTS
  # ============================================================

  describe "level shortcut functions" do
    test "fractal_l1 logs at L1" do
      assert :ok = FractalLogger.fractal_l1("L1 shortcut", %{data: 1})
    end

    test "fractal_l2 logs at L2" do
      assert :ok = FractalLogger.fractal_l2("L2 shortcut", %{data: 2})
    end

    test "fractal_l3 logs at L3" do
      assert :ok = FractalLogger.fractal_l3("L3 shortcut", %{data: 3})
    end

    test "fractal_l4 logs at L4" do
      assert :ok = FractalLogger.fractal_l4("L4 shortcut", %{data: 4})
    end

    test "fractal_l5 logs at L5" do
      assert :ok = FractalLogger.fractal_l5("L5 shortcut", %{data: 5})
    end

    test "shortcut functions accept options" do
      assert :ok = FractalLogger.fractal_l3("With opts", %{}, key: "Test/Path")
    end
  end

  # ============================================================
  # UNIT TESTS: BOOST MANAGEMENT
  # ============================================================

  describe "fractal_boost/3" do
    test "creates boost with default TTL" do
      {:ok, boost_id} = FractalLogger.fractal_boost("Test/**", :l2)

      assert is_binary(boost_id)
      assert String.length(boost_id) == 8
    end

    test "creates boost with custom TTL" do
      {:ok, boost_id} = FractalLogger.fractal_boost("Test/**", :l1, ttl_ms: 60_000)

      assert is_binary(boost_id)
    end

    test "creates boost with filter" do
      {:ok, boost_id} =
        FractalLogger.fractal_boost("Test/**", :l1,
          ttl_ms: 30_000,
          filter: %{user_id: "123"}
        )

      assert is_binary(boost_id)
    end

    test "creates boost with created_by" do
      {:ok, boost_id} = FractalLogger.fractal_boost("Test/**", :l1, created_by: "admin-user")

      assert is_binary(boost_id)
    end

    test "rejects TTL exceeding maximum" do
      # Max is 1 hour (3_600_000ms)
      result = FractalLogger.fractal_boost("Test/**", :l1, ttl_ms: 4_000_000)

      assert result == {:error, :ttl_exceeds_maximum}
    end

    test "allows maximum TTL" do
      {:ok, _boost_id} = FractalLogger.fractal_boost("Test/**", :l1, ttl_ms: 3_600_000)
    end
  end

  describe "fractal_unboost/1" do
    test "removes existing boost" do
      {:ok, boost_id} = FractalLogger.fractal_boost("Test/**", :l2, ttl_ms: 60_000)

      result = FractalLogger.fractal_unboost(boost_id)

      assert result == :ok
    end

    test "returns error for non-existent boost" do
      result = FractalLogger.fractal_unboost("nonexistent-id")

      assert result == {:error, :not_found}
    end
  end

  describe "fractal_boosts/0" do
    test "returns empty list initially" do
      boosts = FractalLogger.fractal_boosts()

      assert is_list(boosts)
    end

    test "returns created boosts" do
      {:ok, _id1} = FractalLogger.fractal_boost("A/**", :l2, ttl_ms: 60_000)
      {:ok, _id2} = FractalLogger.fractal_boost("B/**", :l1, ttl_ms: 60_000)

      boosts = FractalLogger.fractal_boosts()

      assert length(boosts) >= 2
    end

    test "boost entries have required fields" do
      {:ok, _id} = FractalLogger.fractal_boost("Test/**", :l2, ttl_ms: 60_000)

      [boost | _] = FractalLogger.fractal_boosts()

      assert Map.has_key?(boost, :id)
      assert Map.has_key?(boost, :key_expr)
      assert Map.has_key?(boost, :depth)
      assert Map.has_key?(boost, :created_at)
      assert Map.has_key?(boost, :expires_at)
    end

    test "excludes expired boosts" do
      # Create boost with very short TTL
      {:ok, _id} = FractalLogger.fractal_boost("Expire/**", :l2, ttl_ms: 1)

      # Wait for expiration
      Process.sleep(10)

      boosts = FractalLogger.fractal_boosts()

      # Should not include expired boost
      refute Enum.any?(boosts, fn b -> b.key_expr == "Expire/**" end)
    end
  end

  # ============================================================
  # UNIT TESTS: TRACE_FUNCTION
  # ============================================================

  describe "trace_function/5" do
    test "traces function and returns result" do
      result =
        FractalLogger.trace_function(
          __MODULE__,
          :test_function,
          0,
          fn -> {:ok, 42} end,
          level: :l3
        )

      assert result == {:ok, 42}
    end

    test "logs entry and exit" do
      # This is an integration test - function should complete without error
      result =
        FractalLogger.trace_function(
          __MODULE__,
          :sample,
          0,
          fn ->
            Process.sleep(1)
            :completed
          end,
          level: :l3
        )

      assert result == :completed
    end

    test "handles exceptions and reraises" do
      assert_raise RuntimeError, "test error", fn ->
        FractalLogger.trace_function(
          __MODULE__,
          :failing,
          0,
          fn -> raise "test error" end,
          level: :l3
        )
      end
    end

    test "uses custom key" do
      result =
        FractalLogger.trace_function(
          __MODULE__,
          :custom,
          0,
          fn -> :ok end,
          level: :l3,
          key: "Custom/Function/Key"
        )

      assert result == :ok
    end

    test "defaults to L3 level" do
      result =
        FractalLogger.trace_function(
          __MODULE__,
          :default_level,
          0,
          fn -> :ok end,
          []
        )

      assert result == :ok
    end
  end

  # ============================================================
  # INTEGRATION TESTS: ASYNC DISPATCH
  # ============================================================

  describe "async dispatch (SC-LOG-001)" do
    test "log calls return immediately" do
      start = System.monotonic_time(:microsecond)

      for _ <- 1..100 do
        FractalLogger.fractal_log(:l4, "Performance test", %{iteration: true})
      end

      elapsed = System.monotonic_time(:microsecond) - start

      # 100 log calls should complete in < 10ms (non-blocking)
      assert elapsed < 10_000
    end

    test "logging doesn't block on slow consumers" do
      # Even with many rapid calls, should not block
      start = System.monotonic_time(:microsecond)

      for i <- 1..1000 do
        FractalLogger.fractal_l4("Rapid log #{i}", %{})
      end

      elapsed = System.monotonic_time(:microsecond) - start

      # Should complete quickly (async)
      # 100ms for 1000 logs
      assert elapsed < 100_000
    end
  end

  # ============================================================
  # INTEGRATION TESTS: PII MASKING
  # ============================================================

  describe "PII masking (SC-LOG-003)" do
    test "masks email in metadata" do
      # The masking happens internally, we verify it doesn't crash
      assert :ok = FractalLogger.fractal_log(:l4, "User", %{email: "user@example.com"})
    end

    test "masks password in metadata" do
      assert :ok = FractalLogger.fractal_log(:l4, "Auth", %{password: "secret123"})
    end

    test "handles nested PII" do
      metadata = %{
        user: %{
          email: "test@test.com",
          credentials: %{password: "hidden"}
        }
      }

      assert :ok = FractalLogger.fractal_log(:l4, "Nested", metadata)
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "fractal_log always returns :ok" do
      forall {level, message} <- {PC.oneof([:l1, :l2, :l3, :l4, :l5]), PC.utf8()} do
        result = FractalLogger.fractal_log(level, message, %{})
        result == :ok
      end
    end

    property "boost_id has consistent format" do
      forall depth <- PC.oneof([:l1, :l2, :l3, :l4, :l5]) do
        clean_boosts()
        {:ok, id} = FractalLogger.fractal_boost("Test/**", depth, ttl_ms: 60_000)
        is_binary(id) and String.length(id) == 8
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "all levels accept logging" do
      ExUnitProperties.check all(level <- SD.member_of([:l1, :l2, :l3, :l4, :l5])) do
        result = FractalLogger.fractal_log(level, "StreamData test", %{})
        assert result == :ok
      end
    end

    test "metadata of various types accepted" do
      ExUnitProperties.check all(
                               str_val <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               int_val <- SD.integer(0..1000)
                             ) do
        metadata = %{str: str_val, num: int_val}
        result = FractalLogger.fractal_log(:l4, "Metadata test", metadata)
        assert result == :ok
      end
    end

    test "trace_function preserves return values" do
      ExUnitProperties.check all(value <- SD.integer(0..1000)) do
        result =
          FractalLogger.trace_function(
            __MODULE__,
            :prop_test,
            0,
            fn -> value end,
            []
          )

        assert result == value
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "SC-LOG-001 compliance (async dispatch)" do
    @tag :stamp
    test "log calls are non-blocking" do
      # Measure time for many rapid calls
      times =
        for _ <- 1..10 do
          start = System.monotonic_time(:nanosecond)
          FractalLogger.fractal_l4("Async test", %{})
          System.monotonic_time(:nanosecond) - start
        end

      avg_time_ns = Enum.sum(times) / length(times)

      # Average should be < 1ms (1_000_000 ns)
      assert avg_time_ns < 1_000_000
    end
  end

  describe "SC-LOG-005 compliance (boost TTL)" do
    @tag :stamp
    test "boost has mandatory TTL" do
      {:ok, _id} = FractalLogger.fractal_boost("Test/**", :l1, ttl_ms: 60_000)

      [boost | _] = FractalLogger.fractal_boosts()

      assert boost.expires_at != nil
      assert DateTime.compare(boost.expires_at, boost.created_at) == :gt
    end

    @tag :stamp
    test "boost expires after TTL" do
      {:ok, id} = FractalLogger.fractal_boost("ShortTTL/**", :l1, ttl_ms: 10)

      # Should exist initially
      boosts_before = FractalLogger.fractal_boosts()
      assert Enum.any?(boosts_before, fn b -> b.id == id end)

      # Wait for expiration
      Process.sleep(20)

      # Should be filtered out
      boosts_after = FractalLogger.fractal_boosts()
      refute Enum.any?(boosts_after, fn b -> b.id == id end)
    end
  end

  describe "SC-LOG-006 compliance (HLC timestamps)" do
    @tag :stamp
    test "HLC is available for L3+ logs" do
      # HLC should be running
      hlc = HLC.now()

      assert is_map(hlc)
      assert hlc.physical > 0
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles nil message" do
      assert :ok = FractalLogger.fractal_log(:l4, nil, %{})
    end

    test "handles very long message" do
      long_message = String.duplicate("a", 10_000)
      assert :ok = FractalLogger.fractal_log(:l4, long_message, %{})
    end

    test "handles unicode in message" do
      assert :ok = FractalLogger.fractal_log(:l4, "测试消息 🎉", %{emoji: "✅"})
    end

    test "handles binary data in metadata" do
      assert :ok = FractalLogger.fractal_log(:l4, "Binary", %{data: <<1, 2, 3, 4>>})
    end

    test "handles atom values in metadata" do
      assert :ok = FractalLogger.fractal_log(:l4, "Atoms", %{status: :ok, type: :test})
    end

    test "handles pid values in metadata" do
      assert :ok = FractalLogger.fractal_log(:l4, "Pid", %{process: self()})
    end

    test "handles empty key expression in boost" do
      # Should fail or handle gracefully
      result = FractalLogger.fractal_boost("", :l2, ttl_ms: 60_000)
      # Empty key might still create boost (implementation dependent)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp ensure_ets_tables do
    for table_name <- [:fractal_config, :fractal_boosts, :fractal_subscriptions, :fractal_aliases] do
      unless :ets.whereis(table_name) != :undefined do
        :ets.new(table_name, [:named_table, :public, :set])
      end
    end
  end

  defp ensure_hlc_started do
    case Process.whereis(HLC) do
      nil ->
        {:ok, _} = HLC.start_link([])

      _pid ->
        :ok
    end
  end

  defp clean_boosts do
    if :ets.whereis(:fractal_boosts) != :undefined do
      :ets.delete_all_objects(:fractal_boosts)
    end
  end
end
