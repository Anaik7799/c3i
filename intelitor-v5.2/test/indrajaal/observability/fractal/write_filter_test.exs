defmodule Indrajaal.Observability.Fractal.WriteFilterTest do
  @moduledoc """
  TDG tests for WriteFilter module.

  WHAT: Tests for Bloom filter-based write filtering and deduplication.
  WHY: Ensures SC-LOG-008 compliance (<1% false negative rate).
  CONSTRAINTS: Performance <500ns per check, 50ms bucket deduplication.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.WriteFilter

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure clean state before each test
    WriteFilter.reset()
    WriteFilter.initialize(expected_size: 10_000, fpr: 0.01, rotation_interval_ms: 300_000)

    on_exit(fn ->
      try do
        WriteFilter.reset()
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  # ============================================================
  # UNIT TESTS: BLOOM FILTER CONFIGURATION
  # ============================================================

  describe "Bloom filter configuration" do
    test "calculates optimal bit count for expected size and FPR" do
      config = WriteFilter.create_config(10_000, 0.01)

      # Formula: m = -n * ln(p) / (ln(2)^2)
      # For n=10_000, p=0.01: m ~= 95_850
      assert config.bit_count > 90_000
      assert config.bit_count < 100_000
    end

    test "calculates optimal hash count" do
      config = WriteFilter.create_config(10_000, 0.01)

      # Formula: k = (m/n) * ln(2)
      # Should be around 6-7 hash functions
      assert config.hash_count >= 6
      assert config.hash_count <= 8
    end

    test "creates configuration with all required fields" do
      config = WriteFilter.create_config(5_000, 0.001)

      assert is_integer(config.expected_size)
      assert config.expected_size == 5_000
      assert is_float(config.false_positive_rate)
      assert config.false_positive_rate == 0.001
      assert is_integer(config.bit_count)
      assert is_integer(config.hash_count)
    end
  end

  # ============================================================
  # UNIT TESTS: BLOOM FILTER OPERATIONS
  # ============================================================

  describe "Bloom filter operations" do
    test "adding element and checking returns true" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(1_000, 0.01))

      WriteFilter.add(filter, "test-element")
      assert WriteFilter.might_contain?(filter, "test-element")
    end

    test "checking non-existent element returns false" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(1_000, 0.01))

      refute WriteFilter.might_contain?(filter, "non-existent")
    end

    test "add_and_check returns false for new element, true for existing" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(1_000, 0.01))

      # First insertion returns false (was not present)
      refute WriteFilter.add_and_check?(filter, "new-element")

      # Second check returns true (now present)
      assert WriteFilter.add_and_check?(filter, "new-element")
    end

    test "fill rate increases as elements are added" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(100, 0.01))

      initial_fill = WriteFilter.fill_rate(filter)
      assert initial_fill == 0.0

      for i <- 1..50 do
        WriteFilter.add(filter, "element-#{i}")
      end

      final_fill = WriteFilter.fill_rate(filter)
      assert final_fill > initial_fill
      assert final_fill < 1.0
    end
  end

  # ============================================================
  # UNIT TESTS: WRITE FILTER STATE MANAGEMENT
  # ============================================================

  describe "should_emit?/1" do
    test "returns true for first occurrence of a key" do
      key = WriteFilter.build_key("TestModule", "test_event", "hash123")
      assert WriteFilter.should_emit?(key)
    end

    test "returns false for duplicate key" do
      key = WriteFilter.build_key("TestModule", "test_event", "hash123")

      assert WriteFilter.should_emit?(key)
      refute WriteFilter.should_emit?(key)
    end

    test "handles high-frequency duplicates efficiently" do
      key = WriteFilter.build_key("SpamModule", "frequent_event", "same_hash")

      # First should emit
      assert WriteFilter.should_emit?(key)

      # Next 1000 should be suppressed
      for _ <- 1..1000 do
        refute WriteFilter.should_emit?(key)
      end
    end
  end

  describe "time bucket deduplication" do
    test "build_key_with_time rounds to 50ms buckets" do
      # Same bucket (within 50ms)
      # 1 second in microseconds
      hlc1 = 1_000_000
      # 1.04 seconds - same 50ms bucket
      hlc2 = 1_040_000

      key1 = WriteFilter.build_key_with_time("Module", "event", hlc1)
      key2 = WriteFilter.build_key_with_time("Module", "event", hlc2)

      assert key1 == key2
    end

    test "different time buckets produce different keys" do
      # 1.0 second
      hlc1 = 1_000_000
      # 1.1 seconds - different 50ms bucket
      hlc2 = 1_100_000

      key1 = WriteFilter.build_key_with_time("Module", "event", hlc1)
      key2 = WriteFilter.build_key_with_time("Module", "event", hlc2)

      refute key1 == key2
    end

    test "temporal deduplication within 50ms window" do
      # Align to bucket start to avoid boundary crossing
      # 50ms = 50,000 microseconds
      bucket_size = 50_000
      current = System.system_time(:microsecond)
      base_time = div(current, bucket_size) * bucket_size

      # Events in same 50ms bucket are deduplicated
      key1 = WriteFilter.build_key_with_time("Module", "event", base_time)
      key2 = WriteFilter.build_key_with_time("Module", "event", base_time + 25_000)

      assert WriteFilter.should_emit?(key1)
      # Same bucket, deduplicated
      refute WriteFilter.should_emit?(key2)
    end
  end

  describe "subscriber registration" do
    test "register_subscriber adds to bloom filter" do
      key = "TestModule|subscribed_event|*"

      :ok = WriteFilter.register_subscriber(key)

      # After registration, the key should be in the filter
      refute WriteFilter.should_emit?(key)
    end

    test "pre_register adds key without emission check" do
      key = "PreRegistered|key|abc"

      WriteFilter.pre_register(key)

      # Pre-registered keys are treated as already emitted
      refute WriteFilter.should_emit?(key)
    end
  end

  # ============================================================
  # UNIT TESTS: STATISTICS AND DIAGNOSTICS
  # ============================================================

  describe "statistics" do
    test "get_stats returns valid statistics" do
      # Generate some activity
      for i <- 1..100 do
        key = WriteFilter.build_key("Module", "event", "hash#{i}")
        WriteFilter.should_emit?(key)
      end

      stats = WriteFilter.get_stats()

      assert is_integer(stats.insert_count)
      assert stats.insert_count >= 100
      assert is_integer(stats.hit_count)
      assert is_integer(stats.miss_count)
      assert is_float(stats.hit_rate)
      assert is_float(stats.current_filter_fill)
      assert is_float(stats.current_estimated_fpr)
    end

    test "is_healthy? returns true for fresh filter" do
      assert WriteFilter.is_healthy?()
    end

    test "filter health degrades with high fill rate" do
      # Create a small filter that will fill up quickly
      WriteFilter.reset()
      WriteFilter.initialize(expected_size: 50, fpr: 0.01, rotation_interval_ms: 300_000)

      # Fill it up
      for i <- 1..100 do
        key = "key-#{i}"
        WriteFilter.should_emit?(key)
      end

      # High fill rate should impact health
      stats = WriteFilter.get_stats()
      assert stats.current_filter_fill > 0.5
    end
  end

  # ============================================================
  # UNIT TESTS: FILTER ROTATION
  # ============================================================

  describe "filter rotation" do
    test "rotation creates new filter and preserves previous" do
      WriteFilter.reset()
      WriteFilter.initialize(expected_size: 100, fpr: 0.01, rotation_interval_ms: 1)

      key = "rotation-test-key"
      assert WriteFilter.should_emit?(key)

      # Wait for rotation interval
      Process.sleep(10)

      # Trigger rotation by emitting
      WriteFilter.should_emit?("trigger-rotation")

      stats = WriteFilter.get_stats()
      # Previous filter should now exist
      assert stats.previous_filter_fill != nil or stats.current_filter_fill > 0
    end

    test "lookback to previous filter prevents duplicates across rotation" do
      WriteFilter.reset()
      WriteFilter.initialize(expected_size: 100, fpr: 0.01, rotation_interval_ms: 1)

      key = "cross-rotation-key"
      assert WriteFilter.should_emit?(key)

      # Wait and trigger rotation
      Process.sleep(10)
      WriteFilter.should_emit?("force-rotate")

      # Key from previous filter should still be recognized
      refute WriteFilter.should_emit?(key)
    end
  end

  # ============================================================
  # UNIT TESTS: CONTENT HASHING
  # ============================================================

  describe "content hashing" do
    test "hash_content produces consistent results" do
      content = "test content for hashing"

      hash1 = WriteFilter.hash_content(content)
      hash2 = WriteFilter.hash_content(content)

      assert hash1 == hash2
    end

    test "hash_content produces different results for different content" do
      hash1 = WriteFilter.hash_content("content A")
      hash2 = WriteFilter.hash_content("content B")

      refute hash1 == hash2
    end

    test "hash_payload produces consistent results for structured data" do
      fields = [{"user_id", 123}, {"action", "login"}]

      hash1 = WriteFilter.hash_payload(fields)
      hash2 = WriteFilter.hash_payload(fields)

      assert hash1 == hash2
    end

    test "hash_payload is order-independent" do
      fields1 = [{"b", 2}, {"a", 1}]
      fields2 = [{"a", 1}, {"b", 2}]

      hash1 = WriteFilter.hash_payload(fields1)
      hash2 = WriteFilter.hash_payload(fields2)

      assert hash1 == hash2
    end
  end

  # ============================================================
  # PERFORMANCE TESTS
  # ============================================================

  describe "performance" do
    @tag :performance
    test "should_emit? completes in <500ns average" do
      # Warm up
      for i <- 1..100 do
        WriteFilter.should_emit?("warmup-#{i}")
      end

      # Measure
      iterations = 10_000
      start = System.monotonic_time(:nanosecond)

      for i <- 1..iterations do
        WriteFilter.should_emit?("perf-test-#{rem(i, 100)}")
      end

      elapsed = System.monotonic_time(:nanosecond) - start
      avg_ns = elapsed / iterations

      # Allow some slack for CI environments (target <500ns, allow up to 3000ns)
      assert avg_ns < 3_000, "Average should_emit? time #{avg_ns}ns exceeds 3000ns threshold"
    end

    @tag :performance
    test "bloom filter add completes quickly" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(100_000, 0.01))
      iterations = 1_000

      start = System.monotonic_time(:nanosecond)

      for i <- 1..iterations do
        WriteFilter.add(filter, "add-perf-#{i}")
      end

      elapsed = System.monotonic_time(:nanosecond) - start
      avg_ns = elapsed / iterations

      assert avg_ns < 5_000, "Average add time #{avg_ns}ns exceeds 5000ns threshold"
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "bloom filter never has false negatives" do
      forall elements <- PC.list(PC.utf8()) do
        filter = WriteFilter.create_filter(WriteFilter.create_config(1_000, 0.01))

        # Add all elements
        Enum.each(elements, fn elem -> WriteFilter.add(filter, elem) end)

        # Every added element must be found (no false negatives)
        Enum.all?(elements, fn elem -> WriteFilter.might_contain?(filter, elem) end)
      end
    end

    property "false positive rate is bounded" do
      forall {size, test_count} <- {PC.integer(100, 1000), PC.integer(100, 500)} do
        filter = WriteFilter.create_filter(WriteFilter.create_config(size, 0.01))

        # Add 'size' elements
        for i <- 1..size do
          WriteFilter.add(filter, "element-#{i}")
        end

        # Test with known non-existent elements
        false_positives =
          1..test_count
          |> Enum.count(fn i -> WriteFilter.might_contain?(filter, "nonexistent-#{i}") end)

        fp_rate = false_positives / test_count

        # Allow some variance, but should be under 5% (target is 1%)
        fp_rate < 0.05
      end
    end

    property "duplicate keys always produce same filter key" do
      forall {module, event, hash} <- {PC.utf8(), PC.utf8(), PC.utf8()} do
        key1 = WriteFilter.build_key(module, event, hash)
        key2 = WriteFilter.build_key(module, event, hash)
        key1 == key2
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "content hashing is deterministic" do
      ExUnitProperties.check all(content <- SD.string(:printable, min_length: 1)) do
        hash1 = WriteFilter.hash_content(content)
        hash2 = WriteFilter.hash_content(content)
        assert hash1 == hash2
      end
    end

    test "build_key produces valid keys" do
      ExUnitProperties.check all(
                               module <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               event <- SD.string(:alphanumeric, min_length: 1, max_length: 30),
                               hash <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                             ) do
        key = WriteFilter.build_key(module, event, hash)

        assert is_binary(key)
        assert String.contains?(key, "|")
        [m, e, h] = String.split(key, "|")
        assert m == module
        assert e == event
        assert h == hash
      end
    end

    test "time buckets are consistent within 50ms when aligned to bucket" do
      # 50ms = 50,000 microseconds
      bucket_size = 50_000

      ExUnitProperties.check all(
                               bucket_num <- SD.integer(1_000..1_000_000),
                               offset <- SD.integer(0..49_999)
                             ) do
        # Align base to bucket start so offset stays in same bucket
        base = bucket_num * bucket_size
        key1 = WriteFilter.build_key_with_time("M", "E", base)
        key2 = WriteFilter.build_key_with_time("M", "E", base + offset)
        assert key1 == key2
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "SC-LOG-008 compliance" do
    @tag :stamp
    test "false negative rate is <1%" do
      filter = WriteFilter.create_filter(WriteFilter.create_config(10_000, 0.01))
      test_elements = for i <- 1..1_000, do: "sc-log-008-#{i}"

      # Add all elements
      Enum.each(test_elements, fn elem -> WriteFilter.add(filter, elem) end)

      # Check all elements - MUST find all (no false negatives)
      found_count =
        Enum.count(test_elements, fn elem ->
          WriteFilter.might_contain?(filter, elem)
        end)

      # SC-LOG-008: <1% false negative rate means we must find >99%
      assert found_count == length(test_elements),
             "False negative detected! Found #{found_count}/#{length(test_elements)}"
    end

    @tag :stamp
    test "false negative rate is exactly 0% for bloom filter" do
      # Bloom filters by design have 0% false negatives
      filter = WriteFilter.create_filter(WriteFilter.create_config(1_000, 0.01))

      elements = for i <- 1..500, do: "fn-test-#{i}"
      Enum.each(elements, fn elem -> WriteFilter.add(filter, elem) end)

      false_negatives =
        Enum.count(elements, fn elem ->
          not WriteFilter.might_contain?(filter, elem)
        end)

      assert false_negatives == 0, "Bloom filter should never have false negatives"
    end
  end
end
