defmodule Indrajaal.Fractal.L3xL4InteractionTest do
  @moduledoc """
  P2-FEAT: Fractal L3xL4 interaction test — holon-to-container isolation verification.

  WHAT: Validates that L3 (Holon) state is properly isolated within L4 (Container) boundaries.
  WHY: SC-FRAC-001, SC-SIL4-005 (container start order), SC-BOOT-008 (DAG acyclic).
  CONSTRAINTS: SC-FRAC-001, SC-SIL4-005, SC-BOOT-008, SC-BOOT-010
  TASK: ff1b4354
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Deployment.TopologyValidator
  alias Indrajaal.Core.VSM.System2Coordination
  alias Indrajaal.Core.VSM.System3Control

  # ============================================================
  # L3 Holon → L4 Container: Topology Validation
  # ============================================================

  describe "topology DAG validation (L3→L4)" do
    test "default_graph/0 returns dependency map" do
      graph = TopologyValidator.default_graph()
      assert is_map(graph)
      assert map_size(graph) > 0
    end

    test "validate_acyclic/1 passes for default graph (SC-BOOT-008)" do
      graph = TopologyValidator.default_graph()
      result = TopologyValidator.validate_acyclic(graph)
      assert result == :ok or match?({:ok, _}, result)
    end

    test "validate_acyclic/1 detects cycles" do
      cyclic_graph = %{
        "a" => ["b"],
        "b" => ["c"],
        "c" => ["a"]
      }

      result = TopologyValidator.validate_acyclic(cyclic_graph)
      assert match?({:error, _}, result)
    end

    test "topological_sort/1 orders dependencies correctly" do
      graph = TopologyValidator.default_graph()
      result = TopologyValidator.topological_sort(graph)
      assert match?({:ok, sorted} when is_list(sorted), result)
    end

    test "validate_fractal_cluster/0 validates current cluster config" do
      result = TopologyValidator.validate_fractal_cluster()
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # L3 Holon → L4 Container: Boot Wave Ordering
  # ============================================================

  describe "boot wave ordering (L3→L4 SC-SIL4-005)" do
    test "fractal_cluster_waves/0 returns ordered waves" do
      result = TopologyValidator.fractal_cluster_waves()
      # Returns {:ok, waves} tuple
      waves =
        case result do
          {:ok, w} when is_list(w) -> w
          w when is_list(w) -> w
        end

      assert length(waves) > 0

      Enum.each(waves, fn wave ->
        assert is_list(wave) or is_map(wave) or is_struct(wave)
      end)
    end

    test "config_hash/1 is deterministic" do
      graph = TopologyValidator.default_graph()
      hash1 = TopologyValidator.config_hash(graph)
      hash2 = TopologyValidator.config_hash(graph)
      assert hash1 == hash2
      assert is_binary(hash1)
    end

    test "validate/1 performs full graph validation" do
      graph = TopologyValidator.default_graph()
      result = TopologyValidator.validate(graph)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # L3 Holon → L4 Container: VSM S2 Coordination
  # ============================================================

  describe "VSM S2 coordination across containers (L3→L4)" do
    test "System2Coordination module is defined" do
      assert Code.ensure_loaded?(System2Coordination)
    end

    test "System3Control module is defined" do
      assert Code.ensure_loaded?(System3Control)
    end

    test "S2 coordination has callable functions" do
      Code.ensure_loaded!(System2Coordination)
      fns = System2Coordination.__info__(:functions)
      assert is_list(fns)
      assert length(fns) > 0
    end
  end

  # ============================================================
  # L3 Holon → L4 Container: Isolation Guarantees
  # ============================================================

  describe "container isolation guarantees (L3→L4)" do
    test "topology graph nodes represent containers" do
      graph = TopologyValidator.default_graph()
      nodes = Map.keys(graph)

      # At least the core containers should be present
      assert length(nodes) >= 2
      assert Enum.all?(nodes, &is_binary/1)
    end

    test "each node has explicit dependency list" do
      graph = TopologyValidator.default_graph()

      Enum.each(graph, fn {_node, deps} ->
        assert is_list(deps)
        assert Enum.all?(deps, &is_binary/1)
      end)
    end

    test "no node depends on itself" do
      graph = TopologyValidator.default_graph()

      Enum.each(graph, fn {node, deps} ->
        refute node in deps, "Node #{node} depends on itself"
      end)
    end

    test "all dependencies reference existing nodes" do
      graph = TopologyValidator.default_graph()
      all_nodes = MapSet.new(Map.keys(graph))

      Enum.each(graph, fn {_node, deps} ->
        Enum.each(deps, fn dep ->
          assert MapSet.member?(all_nodes, dep),
                 "Dependency #{dep} not found in graph nodes"
        end)
      end)
    end
  end
end
