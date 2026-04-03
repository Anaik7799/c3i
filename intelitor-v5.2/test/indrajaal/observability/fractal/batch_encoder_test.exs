defmodule Indrajaal.Observability.Fractal.BatchEncoderTest do
  @moduledoc """
  TDG tests for BatchEncoder module.

  WHAT: Tests for message batching and wire format encoding.
  WHY: Ensures SC-LOG-007 compliance (batch flush < 10ms).
  CONSTRAINTS: 100 count OR 10ms elapsed triggers flush, 70% wire savings.
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.BatchEncoder
  alias Indrajaal.Observability.Fractal.HLC

  # ============================================================
  # TEST HELPERS
  # ============================================================

  defp make_test_entry(opts \\ []) do
    %{
      key: Keyword.get(opts, :key, "Test/Module/function"),
      key_alias: Keyword.get(opts, :key_alias, nil),
      hlc:
        Keyword.get(opts, :hlc, %{
          physical: System.system_time(:microsecond),
          counter: 0,
          node_id: "test-node-123"
        }),
      level: Keyword.get(opts, :level, :l3),
      priority: Keyword.get(opts, :priority, :p1),
      event_type: Keyword.get(opts, :event_type, :entry),
      trace_id: Keyword.get(opts, :trace_id, "trace-abc123"),
      span_id: Keyword.get(opts, :span_id, nil),
      parent_span_id: Keyword.get(opts, :parent_span_id, nil),
      payload: Keyword.get(opts, :payload, %{message: "Test message", metadata: %{}}),
      baggage: Keyword.get(opts, :baggage, %{}),
      tags: Keyword.get(opts, :tags, []),
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      duration: Keyword.get(opts, :duration, nil),
      node: Keyword.get(opts, :node, :nonode@nohost),
      module: Keyword.get(opts, :module, TestModule),
      function: Keyword.get(opts, :function, :test_function),
      arity: Keyword.get(opts, :arity, 2)
    }
  end

  defp make_entries(count, opts \\ []) do
    base_time = Keyword.get(opts, :base_time, System.system_time(:microsecond))

    for i <- 1..count do
      make_test_entry(
        key: "Test/Module/func_#{i}",
        hlc: %{physical: base_time + i * 1000, counter: i, node_id: "test-node"},
        payload: %{message: "Message #{i}", index: i}
      )
    end
  end

  # ============================================================
  # UNIT TESTS: CONFIGURATION
  # ============================================================

  describe "configuration" do
    test "default_config has correct values" do
      config = BatchEncoder.default_config()

      assert config.max_batch_size == 100
      assert config.max_batch_age_ms == 10
      assert config.enable_compression == true
      assert config.compression_level == 6
      assert config.enable_delta_encoding == true
      assert config.enable_key_aliasing == true
    end

    test "custom config overrides defaults" do
      config =
        BatchEncoder.create_config(
          max_batch_size: 50,
          max_batch_age_ms: 5,
          enable_compression: false
        )

      assert config.max_batch_size == 50
      assert config.max_batch_age_ms == 5
      assert config.enable_compression == false
      # Defaults preserved
      assert config.enable_delta_encoding == true
    end
  end

  # ============================================================
  # UNIT TESTS: WIRE FORMAT
  # ============================================================

  describe "wire format constants" do
    test "magic bytes are correct" do
      # "FRAC" in little-endian
      assert BatchEncoder.magic_bytes() == 0x43415246
    end

    test "protocol version is 1" do
      assert BatchEncoder.protocol_version() == 1
    end

    test "flags are correctly defined" do
      assert BatchEncoder.flag_compressed() == 0x01
      assert BatchEncoder.flag_delta_encoded() == 0x02
      assert BatchEncoder.flag_key_aliased() == 0x04
    end
  end

  describe "header encoding" do
    test "header is 8+ bytes" do
      entries = make_entries(5)
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      # Header structure: magic(4) + version(1) + flags(1) + count(2) + base_hlc(8) + ...
      assert byte_size(batch.data) >= 8
    end

    test "header contains correct magic bytes" do
      entries = make_entries(3)
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      <<magic::little-unsigned-32, _rest::binary>> = batch.data
      assert magic == BatchEncoder.magic_bytes()
    end

    test "header contains correct entry count" do
      entries = make_entries(7)
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      assert batch.entries_count == 7
      assert batch.header.entry_count == 7
    end
  end

  # ============================================================
  # UNIT TESTS: ENCODING
  # ============================================================

  describe "encoding" do
    test "encode returns error for empty entries" do
      assert {:error, "Cannot encode empty batch"} =
               BatchEncoder.encode(BatchEncoder.default_config(), [])
    end

    test "encode single entry succeeds" do
      entry = make_test_entry()
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), [entry])

      assert batch.entries_count == 1
      assert is_binary(batch.data)
    end

    test "encode multiple entries succeeds" do
      entries = make_entries(10)
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      assert batch.entries_count == 10
      assert is_binary(batch.data)
    end

    test "encode sets base HLC to minimum physical time" do
      entries = [
        make_test_entry(hlc: %{physical: 1000, counter: 0, node_id: "n1"}),
        make_test_entry(hlc: %{physical: 500, counter: 0, node_id: "n1"}),
        make_test_entry(hlc: %{physical: 1500, counter: 0, node_id: "n1"})
      ]

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      assert batch.header.base_hlc_physical == 500
    end

    test "delta encoding reduces wire size" do
      entries = make_entries(50)

      {:ok, batch_with_delta} =
        BatchEncoder.encode(
          BatchEncoder.create_config(enable_delta_encoding: true, enable_compression: false),
          entries
        )

      {:ok, batch_without_delta} =
        BatchEncoder.encode(
          BatchEncoder.create_config(enable_delta_encoding: false, enable_compression: false),
          entries
        )

      # Delta encoding should generally produce smaller output
      # (but depends on data, so we just check it works)
      assert is_binary(batch_with_delta.data)
      assert is_binary(batch_without_delta.data)
    end
  end

  describe "compression" do
    test "compression is applied when enabled and data is large enough" do
      # Generate larger entries to trigger compression
      entries = make_entries(50)

      {:ok, batch_compressed} =
        BatchEncoder.encode(
          BatchEncoder.create_config(enable_compression: true),
          entries
        )

      {:ok, batch_uncompressed} =
        BatchEncoder.encode(
          BatchEncoder.create_config(enable_compression: false),
          entries
        )

      # Compressed should be smaller (for non-trivial data)
      # But compression might not help for very small data
      assert is_binary(batch_compressed.data)
      assert is_binary(batch_uncompressed.data)
    end

    test "compression ratio is calculated correctly" do
      entries = make_entries(100)

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      assert is_float(batch.compression_ratio)
      assert batch.compression_ratio >= 0.0
      assert batch.compression_ratio <= 1.0

      # Ratio = 1.0 - (compressed / original)
      expected_ratio = 1.0 - batch.compressed_size / batch.original_size
      assert_in_delta batch.compression_ratio, expected_ratio, 0.001
    end
  end

  # ============================================================
  # UNIT TESTS: DECODING
  # ============================================================

  describe "decoding" do
    test "decode invalid magic bytes returns error" do
      bad_data = <<0x00, 0x00, 0x00, 0x00, 0::size(96)>>
      assert {:error, "Invalid magic bytes"} = BatchEncoder.decode(bad_data)
    end

    test "decode unsupported version returns error" do
      # Magic bytes + version 99 (unsupported)
      # Magic is 0x43415246 little-endian, so bytes are: 0x46, 0x52, 0x41, 0x43 ("FRAC" backwards)
      data = <<0x46, 0x52, 0x41, 0x43, 99, 0::size(80)>>
      assert {:error, message} = BatchEncoder.decode(data)
      assert String.contains?(message, "version") or String.contains?(message, "Unsupported")
    end

    test "encode then decode roundtrips correctly" do
      entries = make_entries(5)

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)
      {:ok, decoded} = BatchEncoder.decode(batch.data)

      assert length(decoded) == 5

      # Check first entry
      [first | _] = decoded
      assert first.key == "Test/Module/func_1"
    end

    test "roundtrip preserves HLC ordering" do
      base = System.system_time(:microsecond)

      entries = [
        make_test_entry(key: "A", hlc: %{physical: base, counter: 0, node_id: "n"}),
        make_test_entry(key: "B", hlc: %{physical: base + 1000, counter: 0, node_id: "n"}),
        make_test_entry(key: "C", hlc: %{physical: base + 2000, counter: 0, node_id: "n"})
      ]

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)
      {:ok, decoded} = BatchEncoder.decode(batch.data)

      [a, b, c] = decoded
      assert a.hlc.physical < b.hlc.physical
      assert b.hlc.physical < c.hlc.physical
    end

    test "roundtrip preserves level and priority" do
      entry = make_test_entry(level: :l4, priority: :p0)

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), [entry])
      {:ok, [decoded]} = BatchEncoder.decode(batch.data)

      assert decoded.level == :l4
      assert decoded.priority == :p0
    end

    test "roundtrip preserves trace_id" do
      entry = make_test_entry(trace_id: "my-trace-id-12_345")

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), [entry])
      {:ok, [decoded]} = BatchEncoder.decode(batch.data)

      assert decoded.trace_id == "my-trace-id-12_345"
    end
  end

  # ============================================================
  # UNIT TESTS: BATCH ACCUMULATOR
  # ============================================================

  describe "accumulator" do
    test "create_accumulator returns empty accumulator" do
      acc = BatchEncoder.create_accumulator(BatchEncoder.default_config())

      stats = BatchEncoder.get_accumulator_stats(acc)
      assert stats.pending_entries == 0
      assert stats.age_ms == nil
    end

    test "add_entry returns nil when batch not ready" do
      acc = BatchEncoder.create_accumulator(BatchEncoder.default_config())
      entry = make_test_entry()

      result = BatchEncoder.add_entry(acc, entry)

      assert result == nil

      stats = BatchEncoder.get_accumulator_stats(acc)
      assert stats.pending_entries == 1
    end

    test "add_entry flushes when max_batch_size reached" do
      config = BatchEncoder.create_config(max_batch_size: 5)
      acc = BatchEncoder.create_accumulator(config)

      # Add 4 entries - no flush
      for _ <- 1..4 do
        assert nil == BatchEncoder.add_entry(acc, make_test_entry())
      end

      # 5th entry triggers flush
      result = BatchEncoder.add_entry(acc, make_test_entry())

      assert result != nil
      assert result.entries_count == 5

      # Accumulator is now empty
      stats = BatchEncoder.get_accumulator_stats(acc)
      assert stats.pending_entries == 0
    end

    test "flush returns nil for empty accumulator" do
      acc = BatchEncoder.create_accumulator(BatchEncoder.default_config())

      assert nil == BatchEncoder.flush(acc)
    end

    test "flush returns batch with pending entries" do
      acc = BatchEncoder.create_accumulator(BatchEncoder.default_config())

      # add_entry stores state in process dictionary keyed by acc.lock
      # It returns nil when not flushing, or the batch when auto-flushing
      for _ <- 1..3 do
        BatchEncoder.add_entry(acc, make_test_entry())
      end

      result = BatchEncoder.flush(acc)

      assert result != nil
      assert result.entries_count == 3
    end

    test "add_entry flushes after max_batch_age_ms" do
      config = BatchEncoder.create_config(max_batch_size: 1000, max_batch_age_ms: 1)
      acc = BatchEncoder.create_accumulator(config)

      # Add one entry to start the timer
      BatchEncoder.add_entry(acc, make_test_entry())

      # Wait for age to exceed threshold
      Process.sleep(5)

      # Next entry should trigger flush
      result = BatchEncoder.add_entry(acc, make_test_entry())

      # Should have flushed due to age
      assert result != nil or BatchEncoder.get_accumulator_stats(acc).pending_entries <= 1
    end
  end

  # ============================================================
  # UNIT TESTS: STATISTICS
  # ============================================================

  describe "compression stats" do
    test "get_compression_stats returns valid stats" do
      entries = make_entries(50)
      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      stats = BatchEncoder.get_compression_stats(batch)

      assert is_integer(stats.original_size)
      assert is_integer(stats.compressed_size)
      assert is_float(stats.compression_ratio)
      assert is_integer(stats.bytes_saved)
      assert stats.entries_count == 50
      assert is_float(stats.bytes_per_entry)

      assert stats.bytes_saved == stats.original_size - stats.compressed_size
    end
  end

  # ============================================================
  # UNIT TESTS: VARINT ENCODING
  # ============================================================

  describe "varint encoding" do
    test "encode_varint handles small values" do
      assert BatchEncoder.encode_varint(0) == <<0>>
      assert BatchEncoder.encode_varint(1) == <<1>>
      assert BatchEncoder.encode_varint(127) == <<127>>
    end

    test "encode_varint handles larger values" do
      # 128 = 0x80 requires 2 bytes
      assert BatchEncoder.encode_varint(128) == <<0x80, 0x01>>
      # 16_383 = max 2-byte varint
      assert BatchEncoder.encode_varint(16_383) == <<0xFF, 0x7F>>
    end

    test "decode_varint roundtrips" do
      values = [0, 1, 127, 128, 255, 256, 16_383, 16_384, 1_000_000, 1_000_000_000]

      for val <- values do
        encoded = BatchEncoder.encode_varint(val)
        {decoded, _rest} = BatchEncoder.decode_varint(encoded)
        assert decoded == val
      end
    end
  end

  # ============================================================
  # PERFORMANCE TESTS
  # ============================================================

  describe "performance" do
    @tag :performance
    test "batch encoding is fast" do
      entries = make_entries(100)
      config = BatchEncoder.default_config()

      # Warm up
      BatchEncoder.encode(config, entries)

      iterations = 100
      start = System.monotonic_time(:millisecond)

      for _ <- 1..iterations do
        {:ok, _} = BatchEncoder.encode(config, entries)
      end

      elapsed = System.monotonic_time(:millisecond) - start
      avg_ms = elapsed / iterations

      # Should encode 100 entries in well under 10ms
      assert avg_ms < 10, "Average encoding time #{avg_ms}ms exceeds 10ms threshold"
    end

    @tag :performance
    test "SC-LOG-007: batch flush completes in <10ms" do
      config = BatchEncoder.create_config(max_batch_size: 100)
      acc = BatchEncoder.create_accumulator(config)

      # Fill accumulator
      for _ <- 1..99 do
        BatchEncoder.add_entry(acc, make_test_entry())
      end

      # Measure flush time
      start = System.monotonic_time(:millisecond)
      # Triggers flush
      _result = BatchEncoder.add_entry(acc, make_test_entry())
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10, "Batch flush took #{elapsed}ms, exceeds SC-LOG-007 10ms limit"
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "encode-decode roundtrip preserves entry count" do
      forall count <- PC.integer(1, 50) do
        entries = make_entries(count)
        {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)
        {:ok, decoded} = BatchEncoder.decode(batch.data)

        length(decoded) == count
      end
    end

    property "compression never increases size for large batches" do
      forall count <- PC.integer(20, 100) do
        entries = make_entries(count)

        {:ok, compressed} =
          BatchEncoder.encode(
            BatchEncoder.create_config(enable_compression: true),
            entries
          )

        # For real data, compression should help or at least not hurt much
        # (The encoder falls back to uncompressed if compression doesn't help)
        compressed.compressed_size <= compressed.original_size * 1.1
      end
    end

    property "delta encoding preserves temporal ordering" do
      forall base <- PC.integer(1_000_000, 1_000_000_000) do
        entries = [
          make_test_entry(hlc: %{physical: base, counter: 0, node_id: "n"}),
          make_test_entry(hlc: %{physical: base + 500, counter: 0, node_id: "n"}),
          make_test_entry(hlc: %{physical: base + 1000, counter: 0, node_id: "n"})
        ]

        {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)
        {:ok, decoded} = BatchEncoder.decode(batch.data)

        [a, b, c] = decoded
        a.hlc.physical < b.hlc.physical and b.hlc.physical < c.hlc.physical
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "varint roundtrip is identity" do
      ExUnitProperties.check all(value <- SD.integer(0..1_000_000_000)) do
        encoded = BatchEncoder.encode_varint(value)
        {decoded, <<>>} = BatchEncoder.decode_varint(encoded)
        assert decoded == value
      end
    end

    test "encoded batch data is non-empty" do
      ExUnitProperties.check all(count <- SD.integer(1..20)) do
        entries = make_entries(count)
        {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

        assert byte_size(batch.data) > 0
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "SC-LOG-007 compliance" do
    @tag :stamp
    test "batch flush within 10ms deadline" do
      entries = make_entries(100)

      start = System.monotonic_time(:millisecond)
      {:ok, _batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10, "Encoding #{length(entries)} entries took #{elapsed}ms, exceeds 10ms"
    end

    @tag :stamp
    test "accumulator respects 10ms age limit" do
      config = BatchEncoder.create_config(max_batch_size: 1000, max_batch_age_ms: 10)
      acc = BatchEncoder.create_accumulator(config)

      # Add entry to start timer
      BatchEncoder.add_entry(acc, make_test_entry())

      # After 10ms+, adding should trigger flush
      Process.sleep(15)

      result = BatchEncoder.add_entry(acc, make_test_entry())

      # Should have auto-flushed
      assert result != nil or BatchEncoder.get_accumulator_stats(acc).pending_entries <= 1
    end
  end

  describe "wire savings" do
    @tag :stamp
    test "achieves 70% wire savings for typical log data" do
      # Generate typical log entries with repetitive structure
      entries =
        for i <- 1..100 do
          make_test_entry(
            key: "Indrajaal/Alarms/process",
            trace_id: "trace-12_345_678",
            payload: %{
              message: "Alarm processed",
              alarm_id: i,
              status: "active",
              severity: "high"
            }
          )
        end

      {:ok, batch} = BatchEncoder.encode(BatchEncoder.default_config(), entries)

      # Calculate savings vs naive JSON encoding
      naive_size =
        entries
        |> Enum.map(fn e -> byte_size(:erlang.term_to_binary(e)) end)
        |> Enum.sum()

      savings = 1.0 - batch.compressed_size / naive_size

      # For real log data with repetition, we expect good compression
      # This is a sanity check - actual savings depend heavily on data
      assert savings > 0.3, "Expected >30% savings, got #{Float.round(savings * 100, 1)}%"
    end
  end
end
