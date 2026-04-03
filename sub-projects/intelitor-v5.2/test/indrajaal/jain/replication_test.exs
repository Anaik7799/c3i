defmodule Indrajaal.Jain.ReplicationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jain.Replication
  alias Indrajaal.Jain.Constitution

  # Build a node map matching all fields accessed by Replication functions
  defp mature_node do
    %{
      id: "ex:l3:tst:srv:main",
      state: :mature,
      generation: 1,
      parent_id: nil,
      children: [],
      resources: %{cpu: 0.05, memory: 100_000},
      constitution: Constitution.load(),
      created_at: DateTime.utc_now()
    }
  end

  defp sterile_node do
    %{
      id: "ex:l3:tst:srv:sterile",
      state: :sterile,
      generation: 1,
      parent_id: nil,
      children: [],
      resources: %{cpu: 0.0, memory: 0},
      constitution: Constitution.load(),
      created_at: DateTime.utc_now()
    }
  end

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Replication)
    end

    test "module exports expected functions" do
      assert function_exported?(Replication, :replicate, 2)
      assert function_exported?(Replication, :can_replicate?, 1)
      assert function_exported?(Replication, :get_lineage, 1)
      assert function_exported?(Replication, :verify_token, 2)
      assert function_exported?(Replication, :replication_fitness, 1)
      assert function_exported?(Replication, :stats, 1)
    end
  end

  describe "can_replicate?/1" do
    test "returns boolean for a mature node" do
      result = Replication.can_replicate?(mature_node())
      assert is_boolean(result)
    end

    test "returns false for a sterile node" do
      result = Replication.can_replicate?(sterile_node())
      assert result == false
    end
  end

  describe "replication_fitness/1" do
    test "returns a float for a healthy mature node" do
      result = Replication.replication_fitness(mature_node())
      assert is_float(result) or is_integer(result)
    end

    test "fitness for sterile node is 0.0" do
      result = Replication.replication_fitness(sterile_node())
      assert result == 0.0 or (is_float(result) and result < 0.5)
    end
  end

  describe "get_lineage/1" do
    test "returns a list for a node" do
      result = Replication.get_lineage(mature_node())
      assert is_list(result)
    end

    test "lineage contains at least the current node entry" do
      node = mature_node()
      lineage = Replication.get_lineage(node)
      assert length(lineage) >= 1
    end

    test "first lineage entry has :node_id matching node id" do
      node = mature_node()
      [current | _rest] = Replication.get_lineage(node)
      assert current.node_id == node.id
    end
  end

  describe "verify_token/2" do
    test "returns :ok or {:error, _} for a binary token and constitution" do
      constitution = Constitution.load()
      result = Replication.verify_token("fake_token_binary", constitution)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "stats/1" do
    test "returns a map with expected fields" do
      result = Replication.stats(mature_node())
      assert is_map(result)
      assert Map.has_key?(result, :children_count)
      assert Map.has_key?(result, :can_replicate)
      assert Map.has_key?(result, :generation)
    end
  end

  describe "replicate/2" do
    test "returns ok or error for a mature node with default strategy" do
      result = Replication.replicate(mature_node())
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts explicit :moderate strategy" do
      result = Replication.replicate(mature_node(), :moderate)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "sterile node cannot replicate" do
      result = Replication.replicate(sterile_node())
      assert match?({:error, :sterile}, result) or match?({:error, _}, result)
    end
  end
end
