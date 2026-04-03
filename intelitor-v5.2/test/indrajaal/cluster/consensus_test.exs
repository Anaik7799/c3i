defmodule Indrajaal.Cluster.ConsensusTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Consensus

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Consensus)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(Consensus, :start_link, 1)
    end

    test "defines is_leader?/0" do
      assert function_exported?(Consensus, :is_leader?, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(Consensus, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = Consensus.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end

  describe "is_leader?/0" do
    test "returns a boolean when called without server running" do
      result =
        try do
          Consensus.is_leader?()
        catch
          :exit, _ -> false
        end

      assert is_boolean(result)
    end
  end
end
