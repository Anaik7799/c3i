defmodule Indrajaal.Deployment.TopologyValidatorTest do
  @moduledoc """
  TDG comprehensive test suite for TopologyValidator.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-SIL6-010: DAG validation before boot
  - SC-SIL6-005: Start order DB -> OBS -> APP
  - SC-CLU-001: Seed node MUST start before satellites
  - SC-CLU-002: Fractal-cluster is MANDATORY

  ## Constitutional Verification
  - Psi0 Existence: Validator survives invalid graph inputs
  - Psi1 Regeneration: Topology can be recomputed deterministically

  ## Founder's Directive Alignment
  - Omega0.1: Reliable boot topology maximizes system uptime/resource

  ## TPS 5-Level RCA Context
  - L1 Symptom: Boot failures due to wrong startup order
  - L5 Root Cause: Missing DAG cycle detection before deployment
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Deployment.TopologyValidator
  alias Indrajaal.Deployment.StartupWave

  @moduletag :zenoh_nif

  # ==========================================================================
  # default_graph/0
  # ==========================================================================

  describe "default_graph/0" do
    test "returns fractal cluster dependency map" do
      graph = TopologyValidator.default_graph()
      assert is_map(graph)
      assert Map.has_key?(graph, "db-primary")
      assert Map.has_key?(graph, "indrajaal-obs")
      assert Map.has_key?(graph, "indrajaal-ex-app-1")
    end

    test "db-primary has no dependencies (SC-SIL6-005)" do
      graph = TopologyValidator.default_graph()
      assert graph["db-primary"] == []
    end

    test "obs depends on db-primary" do
      graph = TopologyValidator.default_graph()
      assert "db-primary" in graph["indrajaal-obs"]
    end

    test "app-1 depends on both db and obs" do
      graph = TopologyValidator.default_graph()
      deps = graph["indrajaal-ex-app-1"]
      assert "db-primary" in deps
      assert "indrajaal-obs" in deps
    end
  end

  # ==========================================================================
  # topological_sort/1
  # ==========================================================================

  describe "topological_sort/1" do
    test "sorts a simple linear chain" do
      graph = %{"a" => [], "b" => ["a"], "c" => ["b"]}
      assert {:ok, [["a"], ["b"], ["c"]]} = TopologyValidator.topological_sort(graph)
    end

    test "parallelizes independent nodes in same wave" do
      graph = %{"a" => [], "b" => [], "c" => ["a", "b"]}
      {:ok, layers} = TopologyValidator.topological_sort(graph)
      [first_layer | _] = layers
      assert Enum.sort(first_layer) == ["a", "b"]
    end

    test "detects cycle and returns error" do
      graph = %{"a" => ["b"], "b" => ["a"]}
      assert {:error, :cycle_detected} = TopologyValidator.topological_sort(graph)
    end

    test "handles single node graph" do
      graph = %{"alone" => []}
      assert {:ok, [["alone"]]} = TopologyValidator.topological_sort(graph)
    end

    test "handles empty graph" do
      assert {:ok, []} = TopologyValidator.topological_sort(%{})
    end

    test "returns correct wave count for fractal cluster (SC-CLU-002)" do
      graph = TopologyValidator.default_graph()
      {:ok, layers} = TopologyValidator.topological_sort(graph)
      # db-primary, obs, app-1, app-2 + app-3
      assert length(layers) == 4
    end

    test "diamond dependency resolves correctly" do
      graph = %{
        "a" => [],
        "b" => ["a"],
        "c" => ["a"],
        "d" => ["b", "c"]
      }

      {:ok, layers} = TopologyValidator.topological_sort(graph)
      # a first, b and c parallel, d last
      assert List.first(layers) == ["a"]
      assert "d" in List.last(layers)
    end
  end

  # ==========================================================================
  # validate_acyclic/1
  # ==========================================================================

  describe "validate_acyclic/1" do
    test "valid DAG returns :ok" do
      graph = %{"a" => [], "b" => ["a"]}
      assert :ok = TopologyValidator.validate_acyclic(graph)
    end

    test "self-dependency is a cycle" do
      graph = %{"a" => ["a"]}
      assert {:error, :cycle_detected} = TopologyValidator.validate_acyclic(graph)
    end

    test "three-node cycle detected" do
      graph = %{"a" => ["c"], "b" => ["a"], "c" => ["b"]}
      assert {:error, :cycle_detected} = TopologyValidator.validate_acyclic(graph)
    end

    test "complex acyclic graph passes" do
      graph = %{
        "a" => [],
        "b" => [],
        "c" => ["a"],
        "d" => ["b"],
        "e" => ["c", "d"]
      }

      assert :ok = TopologyValidator.validate_acyclic(graph)
    end

    test "empty graph is acyclic" do
      assert :ok = TopologyValidator.validate_acyclic(%{})
    end
  end

  # ==========================================================================
  # validate/1
  # ==========================================================================

  describe "validate/1" do
    test "valid graph with all deps present returns :ok" do
      graph = %{"a" => [], "b" => ["a"]}
      assert :ok = TopologyValidator.validate(graph)
    end

    test "missing dependency node returns error" do
      graph = %{"a" => ["nonexistent"]}
      assert {:error, reason} = TopologyValidator.validate(graph)
      assert String.contains?(reason, "nonexistent")
    end

    test "self-dependency returns cycle error" do
      graph = %{"a" => ["a"]}
      assert {:error, _} = TopologyValidator.validate(graph)
    end

    test "fractal cluster default graph is valid" do
      graph = TopologyValidator.default_graph()
      assert :ok = TopologyValidator.validate(graph)
    end
  end

  # ==========================================================================
  # validate_fractal_cluster/0
  # ==========================================================================

  describe "validate_fractal_cluster/0" do
    test "default fractal cluster topology is valid (SC-CLU-002)" do
      assert :ok = TopologyValidator.validate_fractal_cluster()
    end
  end

  # ==========================================================================
  # config_hash/1
  # ==========================================================================

  describe "config_hash/1" do
    test "returns 16-character hex string" do
      graph = TopologyValidator.default_graph()
      hash = TopologyValidator.config_hash(graph)
      assert is_binary(hash)
      assert String.length(hash) == 16
      assert String.match?(hash, ~r/^[0-9a-f]+$/)
    end

    test "same graph produces same hash (deterministic)" do
      graph = TopologyValidator.default_graph()
      hash1 = TopologyValidator.config_hash(graph)
      hash2 = TopologyValidator.config_hash(graph)
      assert hash1 == hash2
    end

    test "different graphs produce different hashes" do
      graph1 = %{"a" => []}
      graph2 = %{"b" => []}
      refute TopologyValidator.config_hash(graph1) == TopologyValidator.config_hash(graph2)
    end
  end

  # ==========================================================================
  # fractal_cluster_waves/0
  # ==========================================================================

  describe "fractal_cluster_waves/0" do
    test "returns ok tuple with list of startup waves" do
      assert {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      assert is_list(waves)
    end

    test "all elements are StartupWave structs" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()

      Enum.each(waves, fn wave ->
        assert %StartupWave{} = wave
      end)
    end

    test "wave orders are sequential starting at 1" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      orders = Enum.map(waves, & &1.order)
      assert orders == Enum.to_list(1..length(waves))
    end

    test "db-primary is in wave 1 (SC-SIL6-005)" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      wave1 = Enum.find(waves, &(&1.order == 1))
      assert "db-primary" in wave1.containers
    end

    test "observability is in wave 2" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      wave2 = Enum.find(waves, &(&1.order == 2))
      assert "indrajaal-obs" in wave2.containers
    end

    test "seed app node is in wave 3 (SC-CLU-001)" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      wave3 = Enum.find(waves, &(&1.order == 3))
      assert "indrajaal-ex-app-1" in wave3.containers
    end

    test "satellite app nodes are in wave 4 with jitter" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      wave4 = Enum.find(waves, &(&1.order == 4))
      assert wave4.jitter_enabled == true
      assert "indrajaal-ex-app-2" in wave4.containers
      assert "indrajaal-ex-app-3" in wave4.containers
    end

    test "wave 1 has no jitter (thundering herd prevention)" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()
      wave1 = Enum.find(waves, &(&1.order == 1))
      assert wave1.jitter_enabled == false
    end

    test "all waves have 30s timeout (SC-SIL6-002)" do
      {:ok, waves} = TopologyValidator.fractal_cluster_waves()

      Enum.each(waves, fn wave ->
        assert wave.timeout_ms == 30_000
      end)
    end
  end

  # ==========================================================================
  # compute_shutdown_waves/1
  # ==========================================================================

  describe "compute_shutdown_waves/1" do
    test "shutdown waves are reverse of startup waves" do
      graph = %{"a" => [], "b" => ["a"], "c" => ["b"]}
      {:ok, startup} = TopologyValidator.topological_sort(graph)
      {:ok, shutdown} = TopologyValidator.compute_shutdown_waves(graph)
      assert shutdown == Enum.reverse(startup)
    end

    test "returns error for cyclic graph" do
      graph = %{"a" => ["b"], "b" => ["a"]}
      assert {:error, :cycle_detected} = TopologyValidator.compute_shutdown_waves(graph)
    end

    test "fractal cluster shutdown starts from app nodes" do
      graph = TopologyValidator.default_graph()
      {:ok, shutdown_waves} = TopologyValidator.compute_shutdown_waves(graph)
      # App nodes (highest dependency) shut down first
      first_shutdown = List.first(shutdown_waves)
      assert "db-primary" not in first_shutdown
    end
  end

  # ==========================================================================
  # Property Tests
  # ==========================================================================

  property "topological sort layer count never exceeds node count" do
    forall graph <- PC.list(PC.atom()) do
      unique_nodes = Enum.uniq(graph)
      simple_graph = Map.new(unique_nodes, fn node -> {to_string(node), []} end)

      case TopologyValidator.topological_sort(simple_graph) do
        {:ok, layers} -> length(layers) <= map_size(simple_graph)
        {:error, _} -> true
      end
    end
  end

  test "config_hash returns consistent hex strings" do
    ExUnitProperties.check all(
                             key <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                             _count <- SD.integer(0..5)
                           ) do
      graph = %{key => []}
      hash = TopologyValidator.config_hash(graph)
      assert byte_size(hash) == 16
      assert String.match?(hash, ~r/^[0-9a-f]+$/)
    end
  end
end
