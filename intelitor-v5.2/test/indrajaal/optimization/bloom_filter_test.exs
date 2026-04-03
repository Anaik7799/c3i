defmodule Indrajaal.Optimization.BloomFilterTest do
  @moduledoc """
  TDG test suite for Indrajaal.Optimization.BloomFilter.

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: @moduletag :zenoh_nif required

  ## TPS 5-Level RCA Context
  - L1 Symptom: False negatives in membership queries
  - L5 Root Cause: Incorrect bloom filter sizing or hash functions
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Optimization.BloomFilter

  describe "new/2" do
    test "creates a bloom filter with capacity and error rate" do
      filter = BloomFilter.new(1000, 0.01)
      assert filter != nil
    end

    test "accepts integer capacity and float error rate" do
      assert BloomFilter.new(100, 0.05) != nil
    end

    test "creates distinct filter instances" do
      f1 = BloomFilter.new(100, 0.01)
      f2 = BloomFilter.new(200, 0.01)
      assert f1 != f2
    end
  end

  describe "add/2" do
    test "adds an element to the filter" do
      filter = BloomFilter.new(100, 0.01)
      updated = BloomFilter.add(filter, "test_element")
      assert updated != nil
    end

    test "returns updated filter after add" do
      filter = BloomFilter.new(100, 0.01)
      result = BloomFilter.add(filter, "element")
      assert is_struct(result) or is_map(result) or is_tuple(result)
    end

    test "can add multiple elements" do
      filter = BloomFilter.new(100, 0.01)
      filter = BloomFilter.add(filter, "a")
      filter = BloomFilter.add(filter, "b")
      filter = BloomFilter.add(filter, "c")
      assert filter != nil
    end
  end

  describe "member?/2" do
    test "returns false for empty filter" do
      filter = BloomFilter.new(100, 0.01)
      assert BloomFilter.member?(filter, "anything") == false
    end

    test "returns true for added element (no false negatives)" do
      filter = BloomFilter.new(1000, 0.01)
      filter = BloomFilter.add(filter, "known_element")
      assert BloomFilter.member?(filter, "known_element") == true
    end

    test "returns boolean" do
      filter = BloomFilter.new(100, 0.01)
      result = BloomFilter.member?(filter, "test")
      assert is_boolean(result)
    end

    test "added elements are always members" do
      filter = BloomFilter.new(1000, 0.01)
      elements = ["apple", "banana", "cherry", "date"]

      filter =
        Enum.reduce(elements, filter, fn el, f -> BloomFilter.add(f, el) end)

      for el <- elements do
        assert BloomFilter.member?(filter, el) == true
      end
    end
  end
end
