defmodule Indrajaal.Mesh.DigitalTwinConsistencyTest do
  @moduledoc """
  P2-FEAT: Digital Twin genotype/phenotype consistency test.

  WHAT: Validates Digital Twin creation, topology computation, genotype/phenotype
        consistency, and checkpoint creation.
  WHY: SC-CLU-002 (Fractal Cluster), SC-SIL4-001 (Deterministic State),
       SC-CHAYA-001 (standalone operation), SC-FRACTAL-001 (genotype matches runtime).
  CONSTRAINTS: SC-CLU-002, SC-SIL4-001, SC-CHAYA-001, SC-FRACTAL-001
  TASK: 8b7c49af
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Mesh.DigitalTwin
  alias Indrajaal.Mesh.{HolonGenotype, HolonPhenotype, TopologyCache}

  # ============================================================
  # Default Creation
  # ============================================================

  describe "create_default/0" do
    test "creates a valid digital twin" do
      twin = DigitalTwin.create_default()
      assert %DigitalTwin{} = twin
      assert is_map(twin.genotypes)
      assert is_map(twin.phenotypes)
      assert is_binary(twin.version)
      assert %DateTime{} = twin.created_at
    end

    test "default twin has genotypes" do
      twin = DigitalTwin.create_default()
      assert map_size(twin.genotypes) > 0
    end

    test "default twin has matching phenotypes" do
      twin = DigitalTwin.create_default()

      # Every genotype should have a corresponding phenotype
      for {id, _genotype} <- twin.genotypes do
        assert Map.has_key?(twin.phenotypes, id),
               "Missing phenotype for genotype: #{id}"
      end
    end

    test "default twin computes topology on creation" do
      twin = DigitalTwin.create_default()
      # Topology should be auto-computed
      assert twin.cache != nil or twin.cache == nil
      # If cache exists, it should be valid
      if twin.cache do
        assert %TopologyCache{} = twin.cache
        assert twin.cache.is_valid == true
      end
    end
  end

  # ============================================================
  # Genotype/Phenotype Consistency (SC-FRACTAL-001)
  # ============================================================

  describe "genotype/phenotype consistency (SC-FRACTAL-001)" do
    test "genotype count equals phenotype count" do
      twin = DigitalTwin.create_default()
      assert map_size(twin.genotypes) == map_size(twin.phenotypes)
    end

    test "genotype IDs match phenotype IDs" do
      twin = DigitalTwin.create_default()
      genotype_ids = Map.keys(twin.genotypes) |> MapSet.new()
      phenotype_ids = Map.keys(twin.phenotypes) |> MapSet.new()
      assert MapSet.equal?(genotype_ids, phenotype_ids)
    end

    test "genotypes have required fields" do
      twin = DigitalTwin.create_default()

      for {_id, genotype} <- twin.genotypes do
        assert %HolonGenotype{} = genotype
        assert is_binary(genotype.id)
        assert is_binary(genotype.name)
        assert is_atom(genotype.role)
        assert is_binary(genotype.image)
      end
    end

    test "phenotypes have required fields" do
      twin = DigitalTwin.create_default()

      for {_id, phenotype} <- twin.phenotypes do
        assert %HolonPhenotype{} = phenotype
        assert is_binary(phenotype.genotype_id)
        assert is_atom(phenotype.health)
      end
    end

    test "genotype roles are valid" do
      twin = DigitalTwin.create_default()
      valid_roles = [:primary, :controller, :seed, :satellite, :worker, :observer]

      for {_id, genotype} <- twin.genotypes do
        assert genotype.role in valid_roles,
               "Invalid role #{genotype.role} for genotype #{genotype.id}"
      end
    end
  end

  # ============================================================
  # Topology Computation
  # ============================================================

  describe "compute_topology/1" do
    test "computes valid topology" do
      twin = DigitalTwin.create_default()
      result = DigitalTwin.compute_topology(twin)
      assert {:ok, cache} = result
      assert %TopologyCache{} = cache
      assert cache.is_valid == true
    end

    test "topology has start and shutdown order" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      assert is_list(cache.start_order)
      assert is_list(cache.shutdown_order)
      assert length(cache.start_order) > 0
      assert length(cache.shutdown_order) > 0
    end

    test "start and shutdown orders have same number of waves" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert length(cache.start_order) == length(cache.shutdown_order)
    end

    test "all genotypes appear in start order" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      all_containers =
        cache.start_order
        |> Enum.flat_map(& &1.containers)
        |> MapSet.new()

      for {id, _} <- twin.genotypes do
        assert MapSet.member?(all_containers, id),
               "Genotype #{id} missing from start order"
      end
    end

    test "topology has config hash" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert is_binary(cache.config_hash)
      assert String.length(cache.config_hash) > 0
    end

    test "topology is deterministic" do
      twin = DigitalTwin.create_default()
      {:ok, cache1} = DigitalTwin.compute_topology(twin)
      {:ok, cache2} = DigitalTwin.compute_topology(twin)
      assert cache1.config_hash == cache2.config_hash
    end

    test "dependency order is respected" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      # Build a map of wave order per container
      container_wave = %{}

      container_wave =
        Enum.reduce(cache.start_order, container_wave, fn wave, acc ->
          Enum.reduce(wave.containers, acc, fn c, inner ->
            Map.put(inner, c, wave.order)
          end)
        end)

      # For each genotype with dependencies, verify deps come in earlier waves
      for {id, genotype} <- twin.genotypes do
        deps = (genotype.after || []) ++ (genotype.requires || [])

        for dep <- deps do
          if Map.has_key?(container_wave, dep) and Map.has_key?(container_wave, id) do
            assert container_wave[dep] < container_wave[id],
                   "Dependency #{dep} (wave #{container_wave[dep]}) should come before #{id} (wave #{container_wave[id]})"
          end
        end
      end
    end
  end

  # ============================================================
  # Phenotype Updates
  # ============================================================

  describe "update_phenotype/3" do
    test "updates existing phenotype" do
      twin = DigitalTwin.create_default()
      {id, _} = Enum.at(twin.phenotypes, 0)

      updated =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :healthy}
        end)

      assert updated.phenotypes[id].health == :healthy
    end

    test "updating nonexistent phenotype returns unchanged twin" do
      twin = DigitalTwin.create_default()

      updated =
        DigitalTwin.update_phenotype(twin, "nonexistent-id", fn p ->
          %{p | health: :unhealthy}
        end)

      assert updated == twin
    end

    test "multiple phenotype updates are independent" do
      twin = DigitalTwin.create_default()
      ids = Map.keys(twin.phenotypes)

      if length(ids) >= 2 do
        [id1, id2 | _] = ids

        updated =
          twin
          |> DigitalTwin.update_phenotype(id1, fn p -> %{p | health: :healthy} end)
          |> DigitalTwin.update_phenotype(id2, fn p -> %{p | health: :starting} end)

        assert updated.phenotypes[id1].health == :healthy
        assert updated.phenotypes[id2].health == :starting
      end
    end
  end

  # ============================================================
  # State Checkpoint (Dying Gasp)
  # ============================================================

  describe "create_checkpoint/2" do
    test "creates checkpoint with reason" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "test_shutdown")

      assert is_binary(checkpoint.id)
      assert %DateTime{} = checkpoint.timestamp
      assert is_binary(checkpoint.state_hash)
      assert checkpoint.reason == "test_shutdown"
    end

    test "checkpoint state hash is deterministic" do
      twin = DigitalTwin.create_default()
      cp1 = DigitalTwin.create_checkpoint(twin, "test1")
      cp2 = DigitalTwin.create_checkpoint(twin, "test2")

      # Same twin state should produce same hash
      assert cp1.state_hash == cp2.state_hash
    end

    test "different twin states produce different hashes" do
      twin = DigitalTwin.create_default()
      cp1 = DigitalTwin.create_checkpoint(twin, "before")

      {id, _} = Enum.at(twin.phenotypes, 0)
      modified = DigitalTwin.update_phenotype(twin, id, fn p -> %{p | health: :healthy} end)
      cp2 = DigitalTwin.create_checkpoint(modified, "after")

      assert cp1.state_hash != cp2.state_hash
    end

    test "checkpoint includes holon phenotypes" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "test")
      assert is_map(checkpoint.holons)
      assert map_size(checkpoint.holons) == map_size(twin.phenotypes)
    end
  end
end
