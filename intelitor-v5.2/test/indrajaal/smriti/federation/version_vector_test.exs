defmodule Indrajaal.SMRITI.Federation.VersionVectorTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Federation.VersionVector

  describe "Version Vector" do
    test "initializes empty" do
      vv = VersionVector.new()
      assert vv.clock == %{}
    end

    test "increments node counter" do
      vv = VersionVector.new() |> VersionVector.increment("node_a")
      assert vv.clock["node_a"] == 1

      vv = VersionVector.increment(vv, "node_a")
      assert vv.clock["node_a"] == 2
    end

    test "merges two vectors" do
      vv1 = VersionVector.new() |> VersionVector.increment("node_a")

      vv2 =
        VersionVector.new()
        |> VersionVector.increment("node_b")
        |> VersionVector.increment("node_a")
        |> VersionVector.increment("node_a")

      merged = VersionVector.merge(vv1, vv2)
      assert merged.clock["node_a"] == 2
      assert merged.clock["node_b"] == 1
    end

    test "detects concurrency" do
      vv1 = VersionVector.new() |> VersionVector.increment("node_a")
      vv2 = VersionVector.new() |> VersionVector.increment("node_b")

      assert VersionVector.compare(vv1, vv2) == :concurrent
    end

    test "detects dominance" do
      vv1 = VersionVector.new() |> VersionVector.increment("node_a")

      vv2 =
        VersionVector.new()
        |> VersionVector.increment("node_a")
        |> VersionVector.increment("node_a")

      assert VersionVector.compare(vv1, vv2) == :lt
      assert VersionVector.compare(vv2, vv1) == :gt
    end
  end
end
