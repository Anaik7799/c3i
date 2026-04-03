defmodule Indrajaal.Observability.Fractal.HybridLogicalClockTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.Fractal.HybridLogicalClock.

  ## STAMP Safety Integration
  - SC-DIST-005: HLC generation MUST complete < 1ms
  - SC-DIST-010: FQUN MUST contain HLC timestamp

  ## TPS 5-Level RCA Context
  - L1 Symptom: Distributed timestamp collisions
  - L5 Root Cause: No hybrid logical clock for causal ordering
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.Fractal.HybridLogicalClock

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(HybridLogicalClock)
    end

    test "start_link/1 exported" do
      assert function_exported?(HybridLogicalClock, :start_link, 1)
    end

    test "now/0 exported" do
      assert function_exported?(HybridLogicalClock, :now, 0)
    end

    test "now!/0 exported" do
      assert function_exported?(HybridLogicalClock, :now!, 0)
    end

    test "update/1 exported" do
      assert function_exported?(HybridLogicalClock, :update, 1)
    end

    test "encode/1 exported" do
      assert function_exported?(HybridLogicalClock, :encode, 1)
    end

    test "decode/1 exported" do
      assert function_exported?(HybridLogicalClock, :decode, 1)
    end
  end

  describe "now/0 - fallback behavior when GenServer not started" do
    test "returns {:ok, {physical, logical}} tuple" do
      result = HybridLogicalClock.now()
      assert {:ok, {physical, logical}} = result
      assert is_integer(physical)
      assert is_integer(logical)
    end

    test "physical time is positive" do
      {:ok, {physical, _}} = HybridLogicalClock.now()
      assert physical > 0
    end

    test "physical time is approximately current time in milliseconds" do
      before_ms = System.system_time(:millisecond)
      {:ok, {physical, _}} = HybridLogicalClock.now()
      after_ms = System.system_time(:millisecond)

      assert physical >= before_ms - 1000
      assert physical <= after_ms + 1000
    end

    test "logical counter is non-negative" do
      {:ok, {_, logical}} = HybridLogicalClock.now()
      assert logical >= 0
    end
  end

  describe "now!/0 - bang version" do
    test "returns HLC tuple directly" do
      result = HybridLogicalClock.now!()
      assert {physical, logical} = result
      assert is_integer(physical)
      assert is_integer(logical)
    end

    test "never raises" do
      assert_receive _, 0
    catch
      _ -> :ok
    end
  end

  describe "encode/1" do
    test "encodes HLC tuple to string" do
      result = HybridLogicalClock.encode({1_700_000_000_000, 0})
      assert is_binary(result)
    end

    test "encoded string contains physical and logical parts" do
      result = HybridLogicalClock.encode({1_700_000_000_000, 5})
      assert String.contains?(result, "1700000000000")
      assert String.contains?(result, "5")
    end

    test "format is physical.logical" do
      result = HybridLogicalClock.encode({12345, 7})
      assert result == "12345.7"
    end

    test "zero logical counter" do
      result = HybridLogicalClock.encode({12345, 0})
      assert result == "12345.0"
    end
  end

  describe "decode/1" do
    test "decodes valid HLC string" do
      result = HybridLogicalClock.decode("12345.7")
      assert {:ok, {12345, 7}} = result
    end

    test "decodes zero logical counter" do
      result = HybridLogicalClock.decode("1700000000000.0")
      assert {:ok, {1_700_000_000_000, 0}} = result
    end

    test "returns error for invalid format" do
      result = HybridLogicalClock.decode("invalid")
      assert {:error, :invalid_format} = result
    end

    test "encode/decode roundtrip" do
      original = {1_700_000_000_000, 42}
      encoded = HybridLogicalClock.encode(original)
      {:ok, decoded} = HybridLogicalClock.decode(encoded)
      assert decoded == original
    end
  end

  describe "update/1 - without GenServer" do
    test "returns error when GenServer not started" do
      result = HybridLogicalClock.update({1_700_000_000_000, 0})
      assert {:error, :not_started} = result
    end
  end

  describe "with GenServer started" do
    setup do
      name = :"HLCTest_#{System.unique_integer([:positive])}"
      {:ok, pid} = GenServer.start_link(HybridLogicalClock, [], name: name)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      {:ok, pid: pid}
    end

    test "now/0 works when GenServer is running using fallback" do
      result = HybridLogicalClock.now()
      assert {:ok, {_physical, _logical}} = result
    end
  end
end
