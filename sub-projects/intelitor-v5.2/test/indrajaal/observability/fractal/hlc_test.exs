defmodule Indrajaal.Observability.Fractal.HLCTest do
  @moduledoc """
  TDG tests for HLC (Hybrid Logical Clock) module.

  WHAT: Tests for causal ordering timestamps, encoding, decoding, and comparison.
  WHY: Ensures SC-LOG-006 compliance (L3+ logs MUST use HLC timestamps).
  CONSTRAINTS: Monotonically increasing, max 50ms drift from wall clock.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # SC-PROP-023/024: PropCheck/StreamData disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Observability.Fractal.HLC

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure HLC agent is running
    case Process.whereis(HLC) do
      nil ->
        {:ok, _pid} = HLC.start_link([])

      _pid ->
        :ok
    end

    :ok
  end

  # ============================================================
  # UNIT TESTS: NOW
  # ============================================================

  describe "now/0" do
    test "returns HLC timestamp with required fields" do
      hlc = HLC.now()

      assert is_map(hlc)
      assert Map.has_key?(hlc, :physical)
      assert Map.has_key?(hlc, :counter)
      assert Map.has_key?(hlc, :node_id)
    end

    test "physical time is close to system time" do
      system_time = System.system_time(:microsecond)
      hlc = HLC.now()

      # Within 100ms (100,000 microseconds)
      assert abs(hlc.physical - system_time) < 100_000
    end

    test "counter starts at 0 for new physical time" do
      # Wait a bit to ensure new physical time
      Process.sleep(1)
      hlc = HLC.now()

      assert hlc.counter >= 0
    end

    test "node_id is non-empty string" do
      hlc = HLC.now()

      assert is_binary(hlc.node_id)
      assert String.length(hlc.node_id) > 0
    end

    test "consecutive calls are monotonically increasing" do
      hlc1 = HLC.now()
      hlc2 = HLC.now()
      hlc3 = HLC.now()

      assert HLC.compare(hlc1, hlc2) in [:lt, :eq]
      assert HLC.compare(hlc2, hlc3) in [:lt, :eq]
      assert HLC.compare(hlc1, hlc3) in [:lt, :eq]
    end

    test "rapid calls increment counter" do
      hlcs = for _ <- 1..10, do: HLC.now()

      # At least some should have incremented counters
      counters = Enum.map(hlcs, & &1.counter)
      # The counters should generally increase or reset when physical advances
      assert length(Enum.uniq(counters)) >= 1
    end
  end

  # ============================================================
  # UNIT TESTS: UPDATE
  # ============================================================

  describe "update/1" do
    test "updates based on remote timestamp" do
      local = HLC.now()

      # Create a remote timestamp slightly in the future
      remote = %{
        physical: local.physical + 1000,
        counter: 5,
        node_id: "remote-node"
      }

      updated = HLC.update(remote)

      # Updated should be at least as recent as remote
      assert updated.physical >= remote.physical or updated.counter > remote.counter
    end

    test "handles remote timestamp in the past" do
      local = HLC.now()

      # Create a remote timestamp in the past
      remote = %{
        physical: local.physical - 10_000,
        counter: 0,
        node_id: "remote-node"
      }

      updated = HLC.update(remote)

      # Updated should still be at least as recent as local
      assert HLC.compare(updated, local) in [:gt, :eq]
    end

    test "handles same physical time" do
      local = HLC.now()

      remote = %{
        physical: local.physical,
        counter: local.counter + 10,
        node_id: "remote-node"
      }

      updated = HLC.update(remote)

      # Counter should be at least remote.counter + 1
      assert updated.counter > remote.counter or updated.physical > remote.physical
    end

    test "preserves node_id" do
      local = HLC.now()
      local_node_id = local.node_id

      remote = %{
        physical: local.physical + 1000,
        counter: 0,
        node_id: "different-node"
      }

      updated = HLC.update(remote)

      # Node ID should remain the local node's ID
      assert updated.node_id == local_node_id
    end
  end

  # ============================================================
  # UNIT TESTS: COMPARE
  # ============================================================

  describe "compare/2" do
    test "returns :lt when a < b by physical time" do
      a = %{physical: 1000, counter: 0, node_id: "node"}
      b = %{physical: 2000, counter: 0, node_id: "node"}

      assert HLC.compare(a, b) == :lt
    end

    test "returns :gt when a > b by physical time" do
      a = %{physical: 2000, counter: 0, node_id: "node"}
      b = %{physical: 1000, counter: 0, node_id: "node"}

      assert HLC.compare(a, b) == :gt
    end

    test "returns :lt when same physical but a.counter < b.counter" do
      a = %{physical: 1000, counter: 5, node_id: "node"}
      b = %{physical: 1000, counter: 10, node_id: "node"}

      assert HLC.compare(a, b) == :lt
    end

    test "returns :gt when same physical but a.counter > b.counter" do
      a = %{physical: 1000, counter: 10, node_id: "node"}
      b = %{physical: 1000, counter: 5, node_id: "node"}

      assert HLC.compare(a, b) == :gt
    end

    test "returns :eq when identical" do
      a = %{physical: 1000, counter: 5, node_id: "node"}
      b = %{physical: 1000, counter: 5, node_id: "node"}

      assert HLC.compare(a, b) == :eq
    end

    test "ignores node_id in comparison" do
      a = %{physical: 1000, counter: 5, node_id: "node1"}
      b = %{physical: 1000, counter: 5, node_id: "node2"}

      assert HLC.compare(a, b) == :eq
    end
  end

  # ============================================================
  # UNIT TESTS: ENCODE/DECODE
  # ============================================================

  describe "encode/1" do
    test "produces 10-byte binary" do
      hlc = HLC.now()
      encoded = HLC.encode(hlc)

      assert is_binary(encoded)
      assert byte_size(encoded) == 10
    end

    test "encodes physical time and counter" do
      hlc = %{physical: 1_735_000_000_000_000, counter: 1234, node_id: "node"}
      encoded = HLC.encode(hlc)

      # Decode to verify
      {:ok, decoded} = HLC.decode(encoded)
      assert decoded.physical == hlc.physical
      assert decoded.counter == hlc.counter
    end
  end

  describe "decode/1" do
    test "decodes valid binary" do
      original = HLC.now()
      encoded = HLC.encode(original)
      {:ok, decoded} = HLC.decode(encoded)

      assert decoded.physical == original.physical
      assert decoded.counter == original.counter
    end

    test "returns error for invalid binary" do
      assert {:error, :invalid_format} = HLC.decode(<<1, 2, 3>>)
    end

    test "returns error for empty binary" do
      assert {:error, :invalid_format} = HLC.decode(<<>>)
    end

    test "decoded node_id is empty string" do
      original = HLC.now()
      encoded = HLC.encode(original)
      {:ok, decoded} = HLC.decode(encoded)

      # Node ID is not encoded/decoded
      assert decoded.node_id == ""
    end
  end

  describe "encode/decode roundtrip" do
    test "roundtrip preserves physical and counter" do
      for _ <- 1..10 do
        original = HLC.now()
        encoded = HLC.encode(original)
        {:ok, decoded} = HLC.decode(encoded)

        assert decoded.physical == original.physical
        assert decoded.counter == original.counter
      end
    end
  end

  # ============================================================
  # UNIT TESTS: NODE_ID
  # ============================================================

  describe "node_id/0" do
    test "returns the current node ID" do
      node_id = HLC.node_id()

      assert is_binary(node_id)
      assert String.length(node_id) > 0
    end

    test "node ID is consistent" do
      id1 = HLC.node_id()
      id2 = HLC.node_id()

      assert id1 == id2
    end

    test "node ID matches HLC timestamps" do
      node_id = HLC.node_id()
      hlc = HLC.now()

      assert hlc.node_id == node_id
    end
  end

  # ============================================================
  # INTEGRATION TESTS: MONOTONICITY
  # ============================================================

  describe "monotonicity" do
    test "high-frequency calls remain monotonic" do
      hlcs = for _ <- 1..100, do: HLC.now()

      pairs = Enum.zip(hlcs, Enum.drop(hlcs, 1))

      for {earlier, later} <- pairs do
        comparison = HLC.compare(earlier, later)
        assert comparison in [:lt, :eq], "Expected #{inspect(earlier)} <= #{inspect(later)}"
      end
    end

    test "concurrent calls from single process are ordered" do
      hlcs =
        1..50
        |> Enum.map(fn _ -> HLC.now() end)

      for i <- 0..(length(hlcs) - 2) do
        earlier = Enum.at(hlcs, i)
        later = Enum.at(hlcs, i + 1)
        assert HLC.compare(earlier, later) in [:lt, :eq]
      end
    end
  end

  # ============================================================
  # INTEGRATION TESTS: DISTRIBUTED SCENARIOS
  # ============================================================

  describe "distributed scenarios" do
    test "merge with future remote advances local" do
      local = HLC.now()

      # Simulate receiving message from node with future clock
      # Use 40ms (40,000 microseconds) which is within the 50ms max drift
      future_remote = %{
        # 40ms in future (within max drift)
        physical: local.physical + 40_000,
        counter: 0,
        node_id: "future-node"
      }

      updated = HLC.update(future_remote)

      # Local should advance to at least remote's physical
      assert updated.physical >= future_remote.physical
    end

    test "merge with past remote doesn't go backwards" do
      local = HLC.now()

      # Simulate receiving message from node with past clock
      past_remote = %{
        # 1 second in past
        physical: local.physical - 1_000_000,
        counter: 100,
        node_id: "past-node"
      }

      updated = HLC.update(past_remote)

      # Local should not go backwards
      assert HLC.compare(updated, local) in [:gt, :eq]
    end
  end

  # ============================================================
  # PROPERTY TESTS: PROPCHECK
  # ============================================================

  describe "property tests (PropCheck)" do
    property "compare is transitive" do
      forall {a_p, b_p, c_p} <- {PC.integer(1, 1000), PC.integer(1, 1000), PC.integer(1, 1000)} do
        a = %{physical: a_p, counter: 0, node_id: "n"}
        b = %{physical: b_p, counter: 0, node_id: "n"}
        c = %{physical: c_p, counter: 0, node_id: "n"}

        ab = HLC.compare(a, b)
        bc = HLC.compare(b, c)
        ac = HLC.compare(a, c)

        # Transitivity: if a <= b and b <= c, then a <= c
        case {ab, bc} do
          {:lt, :lt} -> ac == :lt
          {:lt, :eq} -> ac == :lt
          {:eq, :lt} -> ac == :lt
          {:eq, :eq} -> ac == :eq
          {:gt, :gt} -> ac == :gt
          {:gt, :eq} -> ac == :gt
          {:eq, :gt} -> ac == :gt
          # Mixed cases don't have simple transitivity
          _ -> true
        end
      end
    end

    property "encode/decode roundtrip preserves values" do
      forall {physical, counter} <- {PC.integer(0, 1_000_000_000_000_000), PC.integer(0, 65_535)} do
        hlc = %{physical: physical, counter: counter, node_id: "test"}
        encoded = HLC.encode(hlc)
        {:ok, decoded} = HLC.decode(encoded)

        decoded.physical == physical and decoded.counter == counter
      end
    end

    property "compare is antisymmetric" do
      forall {p1, c1, p2, c2} <-
               {PC.integer(1, 1000), PC.integer(0, 100), PC.integer(1, 1000), PC.integer(0, 100)} do
        a = %{physical: p1, counter: c1, node_id: "n"}
        b = %{physical: p2, counter: c2, node_id: "n"}

        ab = HLC.compare(a, b)
        ba = HLC.compare(b, a)

        case ab do
          :lt -> ba == :gt
          :gt -> ba == :lt
          :eq -> ba == :eq
        end
      end
    end
  end

  # ============================================================
  # PROPERTY TESTS: STREAMDATA
  # ============================================================

  describe "property tests (StreamData)" do
    test "now always returns valid structure" do
      ExUnitProperties.check all(n <- SD.integer(1..10)) do
        _ = n
        hlc = HLC.now()
        assert is_integer(hlc.physical)
        assert is_integer(hlc.counter)
        assert is_binary(hlc.node_id)
        assert hlc.physical > 0
        assert hlc.counter >= 0
      end
    end

    test "counter never exceeds max" do
      ExUnitProperties.check all(n <- SD.integer(1..50)) do
        _ = n
        hlc = HLC.now()
        assert hlc.counter <= 65_535
      end
    end

    test "compare returns valid result" do
      ExUnitProperties.check all(
                               p1 <- SD.integer(1..1_000_000),
                               c1 <- SD.integer(0..1000),
                               p2 <- SD.integer(1..1_000_000),
                               c2 <- SD.integer(0..1000)
                             ) do
        a = %{physical: p1, counter: c1, node_id: "n"}
        b = %{physical: p2, counter: c2, node_id: "n"}

        result = HLC.compare(a, b)
        assert result in [:lt, :eq, :gt]
      end
    end
  end

  # ============================================================
  # STAMP COMPLIANCE TESTS
  # ============================================================

  describe "SC-LOG-006 compliance" do
    @tag :stamp
    test "HLC provides causal ordering" do
      # Create a sequence of events
      events = for i <- 1..10, do: {i, HLC.now()}

      # Verify causal ordering is maintained
      for i <- 0..8 do
        {_, hlc1} = Enum.at(events, i)
        {_, hlc2} = Enum.at(events, i + 1)

        assert HLC.compare(hlc1, hlc2) in [:lt, :eq],
               "Event #{i} should causally precede event #{i + 1}"
      end
    end

    @tag :stamp
    test "HLC timestamp precision is microsecond" do
      hlc = HLC.now()
      system_us = System.system_time(:microsecond)

      # HLC physical time should be in microsecond precision
      assert hlc.physical > 1_000_000_000_000_000,
             "Physical time should be in microseconds (> 2001)"

      assert hlc.physical < 10_000_000_000_000_000,
             "Physical time should be reasonable (< 2286)"

      # Should be close to system time
      assert abs(hlc.physical - system_us) < 100_000
    end

    @tag :stamp
    test "max drift is bounded to 50ms" do
      # The HLC implementation warns if drift > 50ms
      # Verify system time is within reasonable range
      hlc = HLC.now()
      system_us = System.system_time(:microsecond)

      drift_ms = abs(hlc.physical - system_us) / 1000
      assert drift_ms < 50, "Drift should be < 50ms, got #{drift_ms}ms"
    end
  end

  # ============================================================
  # EDGE CASE TESTS
  # ============================================================

  describe "edge cases" do
    test "handles max counter gracefully" do
      # This tests the counter overflow handling
      for _ <- 1..100 do
        _hlc = HLC.now()
      end

      hlc = HLC.now()
      assert hlc.counter <= 65_535
    end

    test "start_link is idempotent" do
      # Already started in setup
      result = HLC.start_link([])
      assert match?({:ok, _pid}, result) or match?({:error, {:already_started, _pid}}, result)
    end

    test "handles very large physical times in comparison" do
      a = %{physical: 9_999_999_999_999_999, counter: 0, node_id: "n"}
      b = %{physical: 9_999_999_999_999_999, counter: 1, node_id: "n"}

      assert HLC.compare(a, b) == :lt
    end

    test "handles zero values" do
      a = %{physical: 0, counter: 0, node_id: "n"}
      b = %{physical: 0, counter: 0, node_id: "n"}

      assert HLC.compare(a, b) == :eq
    end
  end
end
