defmodule Indrajaal.SIL6.MeshDigitalTwinTest do
  @moduledoc """
  Digital Twin State Management Tests.

  WHAT: Tests for the mesh Digital Twin — the authoritative state model
        that mirrors all container genotypes (DNA) and phenotypes (runtime state).
  WHY: The Digital Twin is the single source of truth for mesh state.
       Topology computation, checkpoint creation, and phenotype updates
       must be deterministic and correct for SIL-6 compliance.
  CONSTRAINTS:
    - SC-SIL6-001: Deterministic state
    - SC-CLU-002: Fractal cluster topology
    - SC-SIL6-004: Checkpoint on shutdown
    - SC-SIL6-005: DAG validated on boot
    - AOR-MESH-008: DigitalTwin is authoritative mesh state

  ## Change History
  | Version | Date       | Author      | Change                    |
  |---------|------------|-------------|---------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial Digital Twin tests |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Mesh.{
    DigitalTwin,
    HolonGenotype,
    HolonPhenotype,
    TopologyCache,
    StateCheckpoint
  }

  @moduletag :sil6
  @moduletag :mesh
  @moduletag :digital_twin

  # ============================================================================
  # 1. DEFAULT CREATION (SC-SIL6-001)
  # ============================================================================

  describe "create_default/0: Default Digital Twin creation" do
    test "creates twin with required fields" do
      twin = DigitalTwin.create_default()

      assert %DigitalTwin{} = twin
      assert is_map(twin.genotypes)
      assert is_map(twin.phenotypes)
      assert is_binary(twin.version)
      assert %DateTime{} = twin.created_at
    end

    test "default twin includes production container genotypes" do
      twin = DigitalTwin.create_default()

      # Must have at least db, obs, zenoh, and app genotypes
      assert map_size(twin.genotypes) >= 4,
             "Expected >= 4 genotypes, got #{map_size(twin.genotypes)}"

      # Each genotype must have required fields
      for {_id, genotype} <- twin.genotypes do
        assert %HolonGenotype{} = genotype
        assert is_binary(genotype.id)
        assert is_binary(genotype.name)
        assert genotype.role in [:primary, :seed, :satellite, :controller, :worker]
        assert is_binary(genotype.image)
      end
    end

    test "creates matching phenotypes for all genotypes" do
      twin = DigitalTwin.create_default()

      genotype_ids = Map.keys(twin.genotypes) |> MapSet.new()
      phenotype_ids = Map.keys(twin.phenotypes) |> MapSet.new()

      assert genotype_ids == phenotype_ids,
             "Genotype/phenotype mismatch. Missing phenotypes: #{inspect(MapSet.difference(genotype_ids, phenotype_ids))}"
    end

    test "initial phenotypes have correct defaults" do
      twin = DigitalTwin.create_default()

      for {_id, phenotype} <- twin.phenotypes do
        assert %HolonPhenotype{} = phenotype
        assert phenotype.health == :unknown
        assert phenotype.startup_phase == :not_started
        assert phenotype.shutdown_phase == :running
        assert phenotype.proof_token == "UNVERIFIED"
        assert phenotype.diagnostic_coverage == 0.0
        assert phenotype.active_connections == 0
        assert phenotype.errors == []
      end
    end

    test "auto-computes topology cache on creation" do
      twin = DigitalTwin.create_default()

      assert %TopologyCache{} = twin.cache
      assert twin.cache.is_valid
      assert is_list(twin.cache.start_order)
      assert is_list(twin.cache.shutdown_order)
      assert length(twin.cache.start_order) > 0
    end
  end

  # ============================================================================
  # 2. TOPOLOGY COMPUTATION (SC-SIL6-005)
  # ============================================================================

  describe "compute_topology/1: DAG validation and wave grouping" do
    test "computes valid topology for default twin" do
      twin = DigitalTwin.create_default()
      assert {:ok, cache} = DigitalTwin.compute_topology(twin)

      assert %TopologyCache{} = cache
      assert cache.is_valid
      assert is_binary(cache.config_hash)
      assert String.length(cache.config_hash) == 64
    end

    test "start_order contains all containers" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      all_containers =
        cache.start_order
        |> Enum.flat_map(& &1.containers)
        |> MapSet.new()

      genotype_ids = Map.keys(twin.genotypes) |> MapSet.new()

      assert all_containers == genotype_ids,
             "Start order missing containers: #{inspect(MapSet.difference(genotype_ids, all_containers))}"
    end

    test "shutdown_order is reverse of start_order" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      start_containers =
        cache.start_order
        |> Enum.flat_map(& &1.containers)

      shutdown_containers =
        cache.shutdown_order
        |> Enum.flat_map(& &1.containers)

      # Shutdown is reverse wave order (containers within wave may differ in order)
      assert MapSet.new(start_containers) == MapSet.new(shutdown_containers)

      # First to start should be last to shutdown
      first_start_wave = hd(cache.start_order).containers
      last_shutdown_wave = List.last(cache.shutdown_order).containers
      assert MapSet.new(first_start_wave) == MapSet.new(last_shutdown_wave)
    end

    test "waves respect dependency ordering" do
      twin = DigitalTwin.create_default()
      {:ok, cache} = DigitalTwin.compute_topology(twin)

      # Build a "started before" set for each wave
      started_before = MapSet.new()

      for wave <- cache.start_order, reduce: started_before do
        started ->
          # Every container in this wave must have all deps in started_before
          for container_id <- wave.containers do
            genotype = twin.genotypes[container_id]
            deps = (genotype.after ++ genotype.requires) |> MapSet.new()

            # Filter out deps that are external (not in our genotypes)
            internal_deps = MapSet.intersection(deps, Map.keys(twin.genotypes) |> MapSet.new())

            assert MapSet.subset?(internal_deps, started),
                   "Container #{container_id} has unmet deps: #{inspect(MapSet.difference(internal_deps, started))}"
          end

          MapSet.union(started, MapSet.new(wave.containers))
      end
    end

    test "detects cyclic dependencies" do
      # Create a twin with circular deps
      g1 = %HolonGenotype{
        id: "a",
        name: "a",
        role: :primary,
        image: "test:latest",
        after: ["b"],
        requires: []
      }

      g2 = %HolonGenotype{
        id: "b",
        name: "b",
        role: :worker,
        image: "test:latest",
        after: ["a"],
        requires: []
      }

      twin = %DigitalTwin{
        genotypes: %{"a" => g1, "b" => g2},
        phenotypes: %{
          "a" => %HolonPhenotype{genotype_id: "a"},
          "b" => %HolonPhenotype{genotype_id: "b"}
        },
        cache: nil,
        last_checkpoint: nil,
        version: "test",
        created_at: DateTime.utc_now()
      }

      assert {:error, "Cycle detected in dependency graph"} =
               DigitalTwin.compute_topology(twin)
    end

    test "handles twin with no dependencies (all parallel)" do
      genotypes =
        for i <- 1..5, into: %{} do
          id = "node-#{i}"

          {id,
           %HolonGenotype{
             id: id,
             name: id,
             role: :worker,
             image: "test:latest",
             after: [],
             requires: []
           }}
        end

      phenotypes =
        for {id, _} <- genotypes, into: %{} do
          {id, %HolonPhenotype{genotype_id: id}}
        end

      twin = %DigitalTwin{
        genotypes: genotypes,
        phenotypes: phenotypes,
        cache: nil,
        last_checkpoint: nil,
        version: "test",
        created_at: DateTime.utc_now()
      }

      assert {:ok, cache} = DigitalTwin.compute_topology(twin)
      # With no deps, all can start in wave 0
      assert length(cache.start_order) == 1
      assert length(hd(cache.start_order).containers) == 5
    end

    test "topology hash is deterministic" do
      twin = DigitalTwin.create_default()
      {:ok, cache1} = DigitalTwin.compute_topology(twin)
      {:ok, cache2} = DigitalTwin.compute_topology(twin)

      assert cache1.config_hash == cache2.config_hash,
             "Topology hash is non-deterministic"
    end
  end

  # ============================================================================
  # 3. PHENOTYPE UPDATES (SC-SIL6-012)
  # ============================================================================

  describe "update_phenotype/3: Runtime state mutations" do
    test "updates existing phenotype" do
      twin = DigitalTwin.create_default()
      id = twin.genotypes |> Map.keys() |> hd()

      updated =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :healthy, startup_phase: :ready}
        end)

      assert updated.phenotypes[id].health == :healthy
      assert updated.phenotypes[id].startup_phase == :ready
    end

    test "returns unchanged twin for non-existent id" do
      twin = DigitalTwin.create_default()
      updated = DigitalTwin.update_phenotype(twin, "nonexistent", fn p -> p end)
      assert updated == twin
    end

    test "preserves other phenotypes during update" do
      twin = DigitalTwin.create_default()
      ids = Map.keys(twin.genotypes)
      target_id = hd(ids)
      other_ids = tl(ids)

      updated =
        DigitalTwin.update_phenotype(twin, target_id, fn p ->
          %{p | health: :healthy}
        end)

      for id <- other_ids do
        assert updated.phenotypes[id] == twin.phenotypes[id],
               "Phenotype #{id} was modified during update of #{target_id}"
      end
    end

    test "supports all health transitions" do
      twin = DigitalTwin.create_default()
      id = twin.genotypes |> Map.keys() |> hd()

      health_states = [:unknown, :starting, :healthy, :unhealthy, :lameduck, :stopping, :stopped]

      for health <- health_states do
        updated = DigitalTwin.update_phenotype(twin, id, fn p -> %{p | health: health} end)
        assert updated.phenotypes[id].health == health
      end
    end

    test "supports failed health with reason" do
      twin = DigitalTwin.create_default()
      id = twin.genotypes |> Map.keys() |> hd()

      updated =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: {:failed, "OOM killed"}}
        end)

      assert {:failed, "OOM killed"} = updated.phenotypes[id].health
    end
  end

  # ============================================================================
  # 4. STATE CHECKPOINTS (SC-SIL6-004)
  # ============================================================================

  describe "create_checkpoint/2: State snapshot creation" do
    test "creates checkpoint with valid structure" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "test-checkpoint")

      assert %StateCheckpoint{} = checkpoint
      assert is_binary(checkpoint.id)
      assert String.length(checkpoint.id) == 36
      assert %DateTime{} = checkpoint.timestamp
      assert is_binary(checkpoint.state_hash)
      assert String.length(checkpoint.state_hash) == 64
      assert checkpoint.reason == "test-checkpoint"
    end

    test "checkpoint captures all phenotypes" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "full-capture")

      assert map_size(checkpoint.holons) == map_size(twin.phenotypes)

      for {id, _phenotype} <- twin.phenotypes do
        assert Map.has_key?(checkpoint.holons, id),
               "Checkpoint missing phenotype for #{id}"
      end
    end

    test "checkpoint hash changes with phenotype mutations" do
      twin = DigitalTwin.create_default()
      cp1 = DigitalTwin.create_checkpoint(twin, "before")

      id = twin.genotypes |> Map.keys() |> hd()

      mutated =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :healthy, diagnostic_coverage: 1.0}
        end)

      cp2 = DigitalTwin.create_checkpoint(mutated, "after")

      assert cp1.state_hash != cp2.state_hash,
             "Checkpoint hash should change after mutation"
    end

    test "checkpoint hash is deterministic for same state" do
      twin = DigitalTwin.create_default()
      cp1 = DigitalTwin.create_checkpoint(twin, "first")
      cp2 = DigitalTwin.create_checkpoint(twin, "second")

      assert cp1.state_hash == cp2.state_hash,
             "Same state should produce same hash"
    end

    test "checkpoint initializes empty operations and writes" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "clean")

      assert checkpoint.active_operations == []
      assert checkpoint.pending_writes == []
    end
  end

  # ============================================================================
  # 5. PROPERTY TESTS: Mesh State Invariants
  # ============================================================================

  describe "Property Tests: Digital Twin invariants" do
    property "genotype/phenotype count always match after updates" do
      forall updates <- PC.list(PC.integer(1, 10)) do
        twin = DigitalTwin.create_default()
        ids = Map.keys(twin.genotypes)

        final =
          Enum.reduce(updates, twin, fn _, acc ->
            id = Enum.random(ids)

            DigitalTwin.update_phenotype(acc, id, fn p ->
              %{p | health: Enum.random([:healthy, :unhealthy, :starting])}
            end)
          end)

        map_size(final.genotypes) == map_size(final.phenotypes)
      end
    end

    property "topology wave count <= genotype count" do
      forall _seed <- PC.integer() do
        twin = DigitalTwin.create_default()
        {:ok, cache} = DigitalTwin.compute_topology(twin)
        length(cache.start_order) <= map_size(twin.genotypes)
      end
    end

    property "checkpoint id is always valid UUID" do
      forall reason <- PC.utf8() do
        twin = DigitalTwin.create_default()
        cp = DigitalTwin.create_checkpoint(twin, reason)
        String.match?(cp.id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      end
    end

    @tag :property
    test "StreamData: wave orders are monotonically increasing" do
      ExUnitProperties.check all(n <- SD.integer(1..3)) do
        twin = DigitalTwin.create_default()
        {:ok, cache} = DigitalTwin.compute_topology(twin)

        orders = Enum.map(cache.start_order, & &1.order)
        _ = n

        assert orders == Enum.sort(orders),
               "Wave orders not monotonically increasing: #{inspect(orders)}"
      end
    end
  end

  # ============================================================================
  # 6. FMEA: Digital Twin Failure Modes
  # ============================================================================

  describe "FMEA: Digital Twin failure modes" do
    @tag :fmea
    test "FMEA-DT-001: Empty genotypes handled gracefully (RPN=40)" do
      twin = %DigitalTwin{
        genotypes: %{},
        phenotypes: %{},
        cache: nil,
        last_checkpoint: nil,
        version: "test",
        created_at: DateTime.utc_now()
      }

      result = DigitalTwin.compute_topology(twin)
      assert {:ok, cache} = result
      assert cache.start_order == []
    end

    @tag :fmea
    test "FMEA-DT-002: Single node topology works (RPN=30)" do
      genotypes = %{
        "solo" => %HolonGenotype{
          id: "solo",
          name: "solo",
          role: :primary,
          image: "test:latest",
          after: [],
          requires: []
        }
      }

      twin = %DigitalTwin{
        genotypes: genotypes,
        phenotypes: %{"solo" => %HolonPhenotype{genotype_id: "solo"}},
        cache: nil,
        last_checkpoint: nil,
        version: "test",
        created_at: DateTime.utc_now()
      }

      assert {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert length(cache.start_order) == 1
      assert hd(cache.start_order).containers == ["solo"]
    end

    @tag :fmea
    test "FMEA-DT-003: Deep dependency chain (RPN=48)" do
      # Create a chain: a -> b -> c -> d -> e
      genotypes =
        for {id, dep} <- [{"e", []}, {"d", ["e"]}, {"c", ["d"]}, {"b", ["c"]}, {"a", ["b"]}],
            into: %{} do
          {id,
           %HolonGenotype{
             id: id,
             name: id,
             role: :worker,
             image: "test:latest",
             after: dep,
             requires: []
           }}
        end

      phenotypes = for {id, _} <- genotypes, into: %{}, do: {id, %HolonPhenotype{genotype_id: id}}

      twin = %DigitalTwin{
        genotypes: genotypes,
        phenotypes: phenotypes,
        cache: nil,
        last_checkpoint: nil,
        version: "test",
        created_at: DateTime.utc_now()
      }

      assert {:ok, cache} = DigitalTwin.compute_topology(twin)
      # 5 nodes in serial chain = 5 waves
      assert length(cache.start_order) == 5

      # First wave should be the leaf (no deps): "e"
      assert "e" in hd(cache.start_order).containers
    end
  end
end
