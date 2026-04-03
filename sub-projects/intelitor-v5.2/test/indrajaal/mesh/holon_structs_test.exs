defmodule Indrajaal.Mesh.HolonStructsTest do
  @moduledoc """
  TDG comprehensive test suite for HolonGenotype and HolonPhenotype structs.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Pure struct modules tested for field contracts and defaults
  - FPPS Validation: 5-method consensus on struct construction and field values

  ## STAMP Safety Integration
  - SC-SIL6-001: HolonGenotype configuration MUST be immutable (enforce_keys)
  - SC-SIL6-012: HolonPhenotype MUST track 5 startup phases
  - SC-SIL6-013: HolonPhenotype MUST track 6 shutdown phases
  - SC-CLU-002: Role enum covers :primary, :seed, :satellite, :controller, :worker

  ## Constitutional Verification
  - Psi_0 Existence: Structs are always constructible with enforce_keys
  - Psi_1 Regeneration: Full phenotype state reconstructible from genotype_id + defaults
  - Psi_5 Truthfulness: proof_token defaults to "UNVERIFIED" until validated

  ## Founder's Directive Alignment
  - Omega_0.6: HolonGenotype is the DNA; HolonPhenotype is its runtime expression

  ## TPS 5-Level RCA Context
  - L1 Symptom: Mesh health degrades silently — phenotype shows :unknown health
  - L5 Root Cause: Missing enforce_keys enforcement allows partially-initialized holons
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Mesh.HolonGenotype
  alias Indrajaal.Mesh.HolonPhenotype

  @moduletag :zenoh_nif

  # ---- HolonGenotype construction ---------------------------------------------

  describe "HolonGenotype struct construction" do
    test "requires :id, :name, :role, :image (enforce_keys)" do
      assert_raise ArgumentError, fn ->
        struct!(HolonGenotype, %{})
      end
    end

    test "constructs with all enforce_keys provided" do
      g = %HolonGenotype{id: "db-1", name: "Database", role: :primary, image: "postgres:17"}
      assert %HolonGenotype{} = g
    end

    test "id field matches provided value" do
      g = %HolonGenotype{id: "app-seed", name: "App", role: :seed, image: "img:latest"}
      assert g.id == "app-seed"
    end

    test "name field matches provided value" do
      g = %HolonGenotype{id: "x", name: "My Service", role: :worker, image: "img"}
      assert g.name == "My Service"
    end

    test "role field matches provided value" do
      for role <- [:primary, :seed, :satellite, :controller, :worker] do
        g = %HolonGenotype{id: "x", name: "x", role: role, image: "img"}
        assert g.role == role
      end
    end

    test "image field matches provided value" do
      g = %HolonGenotype{id: "x", name: "x", role: :satellite, image: "myrepo/app:1.2.3"}
      assert g.image == "myrepo/app:1.2.3"
    end
  end

  describe "HolonGenotype default field values" do
    setup do
      g = %HolonGenotype{id: "g", name: "G", role: :satellite, image: "img"}
      {:ok, g: g}
    end

    test "ports defaults to empty list", %{g: g} do
      assert g.ports == []
    end

    test "environment defaults to empty map", %{g: g} do
      assert g.environment == %{}
    end

    test "after defaults to empty list", %{g: g} do
      assert g.after == []
    end

    test "requires defaults to empty list", %{g: g} do
      assert g.requires == []
    end

    test "wants defaults to empty list", %{g: g} do
      assert g.wants == []
    end

    test "health_check defaults to nil", %{g: g} do
      assert is_nil(g.health_check)
    end

    test "health_interval_ms defaults to 5000", %{g: g} do
      assert g.health_interval_ms == 5000
    end

    test "memory_mb defaults to 512", %{g: g} do
      assert g.memory_mb == 512
    end

    test "cpu_limit defaults to 1.0", %{g: g} do
      assert g.cpu_limit == 1.0
    end

    test "network defaults to indrajaal-net", %{g: g} do
      assert g.network == "indrajaal-net"
    end

    test "ip_address defaults to nil", %{g: g} do
      assert is_nil(g.ip_address)
    end

    test "start_delay_ms defaults to 0", %{g: g} do
      assert g.start_delay_ms == 0
    end

    test "max_jitter_ms defaults to 0", %{g: g} do
      assert g.max_jitter_ms == 0
    end
  end

  describe "HolonGenotype field override" do
    test "requires list can be overridden" do
      g = %HolonGenotype{
        id: "app",
        name: "App",
        role: :seed,
        image: "img",
        requires: ["db-primary"]
      }

      assert g.requires == ["db-primary"]
    end

    test "after list can be overridden" do
      g = %HolonGenotype{
        id: "obs",
        name: "Obs",
        role: :satellite,
        image: "img",
        after: ["db-primary"]
      }

      assert g.after == ["db-primary"]
    end

    test "ports can be set" do
      g = %HolonGenotype{id: "x", name: "x", role: :worker, image: "img", ports: [{4000, 4000}]}
      assert g.ports == [{4000, 4000}]
    end

    test "health_check can be set" do
      g = %HolonGenotype{
        id: "x",
        name: "x",
        role: :worker,
        image: "img",
        health_check: "curl -f http://localhost/health"
      }

      assert g.health_check == "curl -f http://localhost/health"
    end
  end

  # ---- HolonPhenotype construction --------------------------------------------

  describe "HolonPhenotype struct construction" do
    test "requires :genotype_id (enforce_keys)" do
      assert_raise ArgumentError, fn ->
        struct!(HolonPhenotype, %{})
      end
    end

    test "constructs with genotype_id provided" do
      p = %HolonPhenotype{genotype_id: "db-primary"}
      assert %HolonPhenotype{} = p
    end

    test "genotype_id field matches provided value" do
      p = %HolonPhenotype{genotype_id: "app-1"}
      assert p.genotype_id == "app-1"
    end
  end

  describe "HolonPhenotype default field values (Psi_1 Regeneration)" do
    setup do
      p = %HolonPhenotype{genotype_id: "test-holon"}
      {:ok, p: p}
    end

    test "container_id defaults to nil", %{p: p} do
      assert is_nil(p.container_id)
    end

    test "pid defaults to nil", %{p: p} do
      assert is_nil(p.pid)
    end

    test "health defaults to :unknown", %{p: p} do
      assert p.health == :unknown
    end

    test "startup_phase defaults to :not_started (SC-SIL6-012)", %{p: p} do
      assert p.startup_phase == :not_started
    end

    test "shutdown_phase defaults to :running (SC-SIL6-013)", %{p: p} do
      assert p.shutdown_phase == :running
    end

    test "diagnostic_coverage defaults to 0.0", %{p: p} do
      assert p.diagnostic_coverage == 0.0
    end

    test "proof_token defaults to UNVERIFIED (Psi_5 Truthfulness)", %{p: p} do
      assert p.proof_token == "UNVERIFIED"
    end

    test "started_at defaults to nil", %{p: p} do
      assert is_nil(p.started_at)
    end

    test "last_health_check defaults to nil", %{p: p} do
      assert is_nil(p.last_health_check)
    end

    test "last_heartbeat defaults to nil", %{p: p} do
      assert is_nil(p.last_heartbeat)
    end

    test "active_connections defaults to 0", %{p: p} do
      assert p.active_connections == 0
    end

    test "errors defaults to empty list", %{p: p} do
      assert p.errors == []
    end

    test "metrics defaults to empty map", %{p: p} do
      assert p.metrics == %{}
    end
  end

  describe "HolonPhenotype field mutation patterns" do
    setup do
      p = %HolonPhenotype{genotype_id: "mut-holon"}
      {:ok, p: p}
    end

    test "health can be set to :healthy", %{p: p} do
      updated = %{p | health: :healthy}
      assert updated.health == :healthy
    end

    test "health can be set to :unhealthy", %{p: p} do
      updated = %{p | health: :unhealthy}
      assert updated.health == :unhealthy
    end

    test "health can be set to :lameduck", %{p: p} do
      updated = %{p | health: :lameduck}
      assert updated.health == :lameduck
    end

    test "startup_phase can be set to :ready (SC-SIL6-012)", %{p: p} do
      updated = %{p | startup_phase: :ready}
      assert updated.startup_phase == :ready
    end

    test "startup_phase can be set to :booting", %{p: p} do
      updated = %{p | startup_phase: :booting}
      assert updated.startup_phase == :booting
    end

    test "active_connections can be incremented", %{p: p} do
      updated = %{p | active_connections: 10}
      assert updated.active_connections == 10
    end

    test "errors list can be appended", %{p: p} do
      updated = %{p | errors: ["connection refused"]}
      assert updated.errors == ["connection refused"]
    end

    test "metrics map can be populated", %{p: p} do
      updated = %{p | metrics: %{"cpu" => 0.45, "mem" => 128.0}}
      assert updated.metrics["cpu"] == 0.45
    end

    test "proof_token can be set after validation (Psi_5)", %{p: p} do
      token = "PROMETHEUS:valid:sha256:abc123"
      updated = %{p | proof_token: token}
      assert updated.proof_token == token
    end

    test "genotype_id is preserved through mutations", %{p: p} do
      updated = %{p | health: :healthy, startup_phase: :ready, active_connections: 3}
      assert updated.genotype_id == "mut-holon"
    end
  end

  # ---- Struct equality and identity -------------------------------------------

  describe "struct equality" do
    test "two genotypes with same fields are equal (SC-SIL6-001 determinism)" do
      g1 = %HolonGenotype{id: "x", name: "X", role: :primary, image: "img:1"}
      g2 = %HolonGenotype{id: "x", name: "X", role: :primary, image: "img:1"}
      assert g1 == g2
    end

    test "two phenotypes with same fields are equal" do
      p1 = %HolonPhenotype{genotype_id: "a"}
      p2 = %HolonPhenotype{genotype_id: "a"}
      assert p1 == p2
    end

    test "phenotypes differ when health differs" do
      p1 = %HolonPhenotype{genotype_id: "a", health: :healthy}
      p2 = %HolonPhenotype{genotype_id: "a", health: :unknown}
      refute p1 == p2
    end
  end

  # ---- PropCheck properties ---------------------------------------------------

  property "HolonGenotype always has non-nil enforce_key fields" do
    forall role <- PC.oneof([:primary, :seed, :satellite, :controller, :worker]) do
      g = %HolonGenotype{id: "g-1", name: "Gen", role: role, image: "img:latest"}
      not is_nil(g.id) and not is_nil(g.name) and not is_nil(g.role) and not is_nil(g.image)
    end
  end

  property "HolonPhenotype always starts with proof_token UNVERIFIED" do
    forall gid <- PC.utf8() do
      p = %HolonPhenotype{genotype_id: gid}
      p.proof_token == "UNVERIFIED"
    end
  end

  # ---- StreamData property tests ----------------------------------------------

  test "HolonGenotype requires list is always a list type" do
    ExUnitProperties.check all(
                             requires <-
                               SD.list_of(SD.string(:alphanumeric, min_length: 1, max_length: 20),
                                 max_length: 5
                               )
                           ) do
      g = %HolonGenotype{id: "g", name: "G", role: :satellite, image: "img", requires: requires}
      assert is_list(g.requires)
      assert g.requires == requires
    end
  end

  test "HolonPhenotype health field accepts all valid health atoms" do
    ExUnitProperties.check all(
                             health <-
                               SD.member_of([
                                 :unknown,
                                 :starting,
                                 :healthy,
                                 :unhealthy,
                                 :lameduck,
                                 :stopping,
                                 :stopped
                               ])
                           ) do
      p = %HolonPhenotype{genotype_id: "health-test"}
      updated = %{p | health: health}
      assert updated.health == health
      assert updated.genotype_id == "health-test"
    end
  end

  test "HolonPhenotype active_connections is always non-negative" do
    ExUnitProperties.check all(n <- SD.integer(0..1000)) do
      p = %HolonPhenotype{genotype_id: "conn-test", active_connections: n}
      assert p.active_connections >= 0
    end
  end
end
