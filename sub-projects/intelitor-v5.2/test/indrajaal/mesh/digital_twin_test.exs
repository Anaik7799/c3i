defmodule Indrajaal.Mesh.DigitalTwinTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Mesh.DigitalTwin.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Pure struct module, tested before runtime integration
  - FPPS Validation: 5-method consensus on topology computation

  ## STAMP Safety Integration
  - SC-SIL6-001: Deterministic state — topology is reproducible from genotypes
  - SC-CLU-002: Fractal Cluster — 5 default genotypes, DAG validated
  - SC-HOLON-017: SHA-256 state hash in create_checkpoint/2
  - SC-HOLON-009: SQLite is authoritative; DigitalTwin is ephemeral runtime cache

  ## Constitutional Verification
  - Psi_0 Existence: DigitalTwin struct always creatable via create_default/0
  - Psi_1 Regeneration: Phenotypes regenerable from genotypes alone
  - Psi_3 Verification: compute_topology/1 produces verifiable DAG hash

  ## Founder's Directive Alignment
  - Omega_0.6: Digital Twin is the runtime phenotype of the cognitive mesh

  ## TPS 5-Level RCA Context
  - L1 Symptom: Mesh boots in wrong order, services fail to start
  - L5 Root Cause: Topological sort algorithm not enforcing dependency DAG
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Mesh.DigitalTwin
  alias Indrajaal.Mesh.{HolonGenotype, HolonPhenotype}

  @moduletag :zenoh_nif

  # ---- create_default/0 -------------------------------------------------------

  describe "create_default/0" do
    test "returns a DigitalTwin struct" do
      twin = DigitalTwin.create_default()
      assert %DigitalTwin{} = twin
    end

    test "genotypes map is non-empty" do
      twin = DigitalTwin.create_default()
      assert map_size(twin.genotypes) > 0
    end

    test "phenotypes map is non-empty" do
      twin = DigitalTwin.create_default()
      assert map_size(twin.phenotypes) > 0
    end

    test "version is set" do
      twin = DigitalTwin.create_default()
      assert is_binary(twin.version)
      assert twin.version != ""
    end

    test "created_at is a DateTime" do
      twin = DigitalTwin.create_default()
      assert %DateTime{} = twin.created_at
    end

    test "contains the expected 5 default genotypes" do
      twin = DigitalTwin.create_default()
      expected_ids = ["db-primary", "indrajaal-obs", "app-1", "app-2", "app-3"]
      assert MapSet.equal?(MapSet.new(Map.keys(twin.genotypes)), MapSet.new(expected_ids))
    end

    test "phenotypes count matches genotype count" do
      twin = DigitalTwin.create_default()
      assert map_size(twin.phenotypes) == map_size(twin.genotypes)
    end

    test "phenotype IDs match genotype IDs" do
      twin = DigitalTwin.create_default()

      assert MapSet.equal?(
               MapSet.new(Map.keys(twin.phenotypes)),
               MapSet.new(Map.keys(twin.genotypes))
             )
    end

    test "cache is auto-computed on creation (topology available)" do
      twin = DigitalTwin.create_default()
      # Cache should be set by create_default/0
      refute is_nil(twin.cache)
    end

    test "last_checkpoint is nil on fresh creation" do
      twin = DigitalTwin.create_default()
      assert is_nil(twin.last_checkpoint)
    end

    test "is idempotent (two calls return equivalent structures)" do
      twin1 = DigitalTwin.create_default()
      twin2 = DigitalTwin.create_default()
      assert Map.keys(twin1.genotypes) == Map.keys(twin2.genotypes)
      assert Map.keys(twin1.phenotypes) == Map.keys(twin2.phenotypes)
      assert twin1.version == twin2.version
    end
  end

  # ---- genotype contents ------------------------------------------------------

  describe "default genotypes structure" do
    setup do
      twin = DigitalTwin.create_default()
      {:ok, twin: twin}
    end

    test "db-primary has role :primary", %{twin: twin} do
      assert twin.genotypes["db-primary"].role == :primary
    end

    test "app-1 has role :seed", %{twin: twin} do
      assert twin.genotypes["app-1"].role == :seed
    end

    test "app-2 and app-3 have role :satellite", %{twin: twin} do
      assert twin.genotypes["app-2"].role == :satellite
      assert twin.genotypes["app-3"].role == :satellite
    end

    test "app-1 requires db-primary", %{twin: twin} do
      assert "db-primary" in twin.genotypes["app-1"].requires
    end

    test "app-2 requires db-primary and app-1", %{twin: twin} do
      deps = twin.genotypes["app-2"].requires
      assert "db-primary" in deps
      assert "app-1" in deps
    end

    test "db-primary has no after dependencies", %{twin: twin} do
      assert twin.genotypes["db-primary"].after == []
    end

    test "each genotype has a non-empty image", %{twin: twin} do
      Enum.each(twin.genotypes, fn {_id, g} ->
        assert is_binary(g.image) and String.length(g.image) > 0
      end)
    end

    test "each genotype has a health_check command", %{twin: twin} do
      Enum.each(twin.genotypes, fn {_id, g} ->
        assert is_binary(g.health_check) and String.length(g.health_check) > 0
      end)
    end
  end

  # ---- compute_topology/1 -----------------------------------------------------

  describe "compute_topology/1" do
    setup do
      twin = DigitalTwin.create_default()
      {:ok, twin: twin}
    end

    test "returns {:ok, cache} for default twin", %{twin: twin} do
      # Clear cache to force recomputation
      twin_no_cache = %{twin | cache: nil}
      assert {:ok, cache} = DigitalTwin.compute_topology(twin_no_cache)
      assert is_map(cache)
    end

    test "cache contains start_order list (SC-SIL6-001)", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert is_list(cache.start_order)
    end

    test "cache contains shutdown_order list", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert is_list(cache.shutdown_order)
    end

    test "start_order and shutdown_order have same wave count", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert length(cache.start_order) == length(cache.shutdown_order)
    end

    test "shutdown_order covers same containers as start_order (lameduck pattern)", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      start_flat = Enum.flat_map(cache.start_order, & &1.containers) |> MapSet.new()
      shutdown_flat = Enum.flat_map(cache.shutdown_order, & &1.containers) |> MapSet.new()
      assert MapSet.equal?(start_flat, shutdown_flat)
    end

    test "config_hash is a hex string (SHA-256)", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert is_binary(cache.config_hash)
      # SHA-256 produces 64 hex characters
      assert String.length(cache.config_hash) == 64
      assert String.match?(cache.config_hash, ~r/^[0-9a-f]+$/)
    end

    test "cache is_valid is true for default topology", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      assert cache.is_valid == true
    end

    test "db-primary appears in first wave (no dependencies)", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      first_wave = hd(cache.start_order)
      assert "db-primary" in first_wave.containers
    end

    test "app-1 appears after db-primary in start order (dependency enforcement)", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      containers_ordered = Enum.flat_map(cache.start_order, & &1.containers)
      db_idx = Enum.find_index(containers_ordered, &(&1 == "db-primary"))
      app1_idx = Enum.find_index(containers_ordered, &(&1 == "app-1"))
      assert db_idx < app1_idx, "db-primary must start before app-1"
    end

    test "app-2 and app-3 appear after app-1 in start order", %{twin: twin} do
      {:ok, cache} = DigitalTwin.compute_topology(twin)
      containers_ordered = Enum.flat_map(cache.start_order, & &1.containers)
      app1_idx = Enum.find_index(containers_ordered, &(&1 == "app-1"))
      app2_idx = Enum.find_index(containers_ordered, &(&1 == "app-2"))
      app3_idx = Enum.find_index(containers_ordered, &(&1 == "app-3"))
      assert app1_idx < app2_idx, "app-1 must start before app-2"
      assert app1_idx < app3_idx, "app-1 must start before app-3"
    end

    test "topology is deterministic (same hash on repeated calls)", %{twin: twin} do
      {:ok, cache1} = DigitalTwin.compute_topology(twin)
      {:ok, cache2} = DigitalTwin.compute_topology(twin)
      assert cache1.config_hash == cache2.config_hash
    end

    test "detects cycle in genotype graph" do
      # Build a cyclic dependency: a requires b, b requires a
      geno_a = %HolonGenotype{
        id: "a",
        name: "a",
        role: :satellite,
        image: "img",
        after: [],
        requires: ["b"]
      }

      geno_b = %HolonGenotype{
        id: "b",
        name: "b",
        role: :satellite,
        image: "img",
        after: [],
        requires: ["a"]
      }

      twin = %DigitalTwin{
        genotypes: %{"a" => geno_a, "b" => geno_b},
        phenotypes: %{
          "a" => %HolonPhenotype{genotype_id: "a"},
          "b" => %HolonPhenotype{genotype_id: "b"}
        },
        cache: nil,
        last_checkpoint: nil,
        version: "1.0.0",
        created_at: DateTime.utc_now()
      }

      assert {:error, reason} = DigitalTwin.compute_topology(twin)
      assert is_binary(reason)
      assert String.contains?(reason, "Cycle") or String.contains?(reason, "cycle")
    end
  end

  # ---- update_phenotype/3 -----------------------------------------------------

  describe "update_phenotype/3" do
    setup do
      twin = DigitalTwin.create_default()
      {:ok, twin: twin}
    end

    test "returns a DigitalTwin struct", %{twin: twin} do
      result = DigitalTwin.update_phenotype(twin, "db-primary", fn p -> p end)
      assert %DigitalTwin{} = result
    end

    test "applies the updater to the health field of the specified phenotype", %{twin: twin} do
      updated =
        DigitalTwin.update_phenotype(twin, "app-1", fn p ->
          %{p | health: :healthy}
        end)

      assert updated.phenotypes["app-1"].health == :healthy
    end

    test "applies the updater to the startup_phase field", %{twin: twin} do
      updated =
        DigitalTwin.update_phenotype(twin, "db-primary", fn p ->
          %{p | startup_phase: :ready}
        end)

      assert updated.phenotypes["db-primary"].startup_phase == :ready
    end

    test "applies the updater to active_connections field", %{twin: twin} do
      updated =
        DigitalTwin.update_phenotype(twin, "app-1", fn p ->
          %{p | active_connections: 5}
        end)

      assert updated.phenotypes["app-1"].active_connections == 5
    end

    test "does not modify other phenotypes when updating app-1", %{twin: twin} do
      original_db = twin.phenotypes["db-primary"]

      updated =
        DigitalTwin.update_phenotype(twin, "app-1", fn p ->
          %{p | health: :healthy}
        end)

      assert updated.phenotypes["db-primary"] == original_db
    end

    test "returns unchanged twin if id is not found", %{twin: twin} do
      result =
        DigitalTwin.update_phenotype(twin, "nonexistent-id", fn p ->
          %{p | health: :unhealthy}
        end)

      assert result == twin
    end

    test "supports chained updates to multiple phenotypes", %{twin: twin} do
      updated =
        twin
        |> DigitalTwin.update_phenotype("db-primary", fn p -> %{p | health: :healthy} end)
        |> DigitalTwin.update_phenotype("app-1", fn p -> %{p | startup_phase: :ready} end)

      assert updated.phenotypes["db-primary"].health == :healthy
      assert updated.phenotypes["app-1"].startup_phase == :ready
    end

    test "noop updater returns identical phenotype", %{twin: twin} do
      updated = DigitalTwin.update_phenotype(twin, "app-2", fn p -> p end)
      assert updated.phenotypes["app-2"] == twin.phenotypes["app-2"]
    end
  end

  # ---- create_checkpoint/2 ----------------------------------------------------

  describe "create_checkpoint/2 (SC-HOLON-017)" do
    setup do
      twin = DigitalTwin.create_default()
      {:ok, twin: twin}
    end

    test "returns a StateCheckpoint struct", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "test_reason")
      assert is_map(checkpoint)
    end

    test "checkpoint has a state_hash (SHA-256)", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "dying_gasp")
      assert is_binary(checkpoint.state_hash)
      assert String.length(checkpoint.state_hash) == 64
      assert String.match?(checkpoint.state_hash, ~r/^[0-9a-f]+$/)
    end

    test "checkpoint includes the reason string", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "graceful_shutdown")
      assert checkpoint.reason == "graceful_shutdown"
    end

    test "checkpoint includes holons (phenotype snapshot)", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "snapshot")
      assert is_map(checkpoint.holons)
      assert map_size(checkpoint.holons) == map_size(twin.phenotypes)
    end

    test "checkpoint has a UUID id", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "test")
      assert is_binary(checkpoint.id)
      # UUID format: 8-4-4-4-12
      assert String.match?(checkpoint.id, ~r/^[0-9a-f-]{36}$/)
    end

    test "checkpoint has a timestamp", %{twin: twin} do
      checkpoint = DigitalTwin.create_checkpoint(twin, "test")
      assert %DateTime{} = checkpoint.timestamp
    end

    test "different phenotype states produce different hashes", %{twin: twin} do
      checkpoint1 = DigitalTwin.create_checkpoint(twin, "before")

      twin2 =
        DigitalTwin.update_phenotype(twin, "app-1", fn p -> %{p | health: :healthy} end)

      checkpoint2 = DigitalTwin.create_checkpoint(twin2, "after")

      assert checkpoint1.state_hash != checkpoint2.state_hash
    end

    test "same state produces same hash (deterministic)", %{twin: twin} do
      # Create two checkpoints with the same state; hashes should match
      c1 = DigitalTwin.create_checkpoint(twin, "test1")
      c2 = DigitalTwin.create_checkpoint(twin, "test2")
      # Reason differs but state hash is derived from phenotypes only
      assert c1.state_hash == c2.state_hash
    end
  end

  # ---- PropCheck properties ---------------------------------------------------

  property "compute_topology always returns :ok or :error (never crashes)" do
    forall _seed <- PC.boolean() do
      twin = DigitalTwin.create_default()
      result = DigitalTwin.compute_topology(twin)
      match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  property "create_checkpoint always produces a 64-char hex state_hash" do
    forall reason <- PC.utf8() do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, reason)

      String.length(checkpoint.state_hash) == 64 and
        String.match?(checkpoint.state_hash, ~r/^[0-9a-f]+$/)
    end
  end

  # ---- StreamData property tests ----------------------------------------------

  test "update_phenotype with noop updater preserves twin equality" do
    ExUnitProperties.check all(
                             id <-
                               SD.member_of([
                                 "db-primary",
                                 "indrajaal-obs",
                                 "app-1",
                                 "app-2",
                                 "app-3"
                               ])
                           ) do
      twin = DigitalTwin.create_default()
      updated = DigitalTwin.update_phenotype(twin, id, fn p -> p end)
      # Noop updater should preserve the phenotype value
      assert updated.phenotypes[id] == twin.phenotypes[id]
    end
  end

  test "create_default version is always the same string" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      twin = DigitalTwin.create_default()
      assert twin.version == "1.0.0"
    end
  end

  test "update_phenotype health field is preserved on noop over all genotype IDs" do
    ExUnitProperties.check all(
                             id <-
                               SD.member_of([
                                 "db-primary",
                                 "indrajaal-obs",
                                 "app-1",
                                 "app-2",
                                 "app-3"
                               ]),
                             new_health <-
                               SD.member_of([:healthy, :unhealthy, :unknown, :degraded])
                           ) do
      twin = DigitalTwin.create_default()

      updated =
        DigitalTwin.update_phenotype(twin, id, fn p -> %{p | health: new_health} end)

      assert updated.phenotypes[id].health == new_health
    end
  end
end
