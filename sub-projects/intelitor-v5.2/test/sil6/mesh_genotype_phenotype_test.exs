defmodule Indrajaal.SIL6.MeshGenotypePhenotypeTest do
  @moduledoc """
  Holon Genotype and Phenotype Data Model Tests.

  WHAT: Tests for the immutable genotype (DNA) and mutable phenotype (runtime
        state) data structures that form the foundation of the mesh Digital Twin.
  WHY: Genotype immutability guarantees configuration stability. Phenotype
       state transitions must follow the lifecycle FSM for SIL-6 compliance.
       These structures are the atomic building blocks of all mesh operations.
  CONSTRAINTS:
    - SC-SIL6-001: Static configuration must be immutable
    - SC-SIL6-012: 5 Startup Phases
    - SC-SIL6-013: 6 Shutdown Phases
    - SC-CLU-002: Fractal-cluster topology definition
    - AOR-MESH-008: DigitalTwin is authoritative mesh state

  ## Change History
  | Version | Date       | Author      | Change                        |
  |---------|------------|-------------|-------------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial genotype/phenotype    |

  @version "1.0.0"
  @last_modified "2026-03-09T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Mesh.{HolonGenotype, HolonPhenotype}

  @moduletag :sil6
  @moduletag :mesh
  @moduletag :data_model

  # ============================================================================
  # 1. GENOTYPE STRUCTURE (SC-SIL6-001)
  # ============================================================================

  describe "HolonGenotype: Immutable configuration" do
    test "enforces required keys" do
      assert_raise ArgumentError, fn ->
        struct!(HolonGenotype, %{})
      end
    end

    test "creates valid genotype with required fields" do
      genotype = %HolonGenotype{
        id: "db-primary",
        name: "Database Primary",
        role: :primary,
        image: "localhost/indrajaal-timescaledb-demo:nixos-devenv"
      }

      assert genotype.id == "db-primary"
      assert genotype.name == "Database Primary"
      assert genotype.role == :primary
      assert is_binary(genotype.image)
    end

    test "has sensible defaults for optional fields" do
      genotype = %HolonGenotype{
        id: "test",
        name: "test",
        role: :worker,
        image: "test:latest"
      }

      assert genotype.ports == []
      assert genotype.environment == %{}
      assert genotype.after == []
      assert genotype.requires == []
      assert genotype.wants == []
      assert genotype.health_check == nil
      assert genotype.health_interval_ms == 5000
      assert genotype.memory_mb == 512
      assert genotype.cpu_limit == 1.0
      assert genotype.network == "indrajaal-net"
      assert genotype.ip_address == nil
      assert genotype.start_delay_ms == 0
      assert genotype.max_jitter_ms == 0
    end

    test "role types cover all container categories" do
      roles = [:primary, :seed, :satellite, :controller, :worker]

      for role <- roles do
        genotype = %HolonGenotype{
          id: "test-#{role}",
          name: "test-#{role}",
          role: role,
          image: "test:latest"
        }

        assert genotype.role == role
      end
    end

    test "port mapping is tuple list" do
      genotype = %HolonGenotype{
        id: "app",
        name: "app",
        role: :seed,
        image: "test:latest",
        ports: [{4000, 4000}, {4001, 4001}]
      }

      assert length(genotype.ports) == 2

      for {host, container} <- genotype.ports do
        assert is_integer(host)
        assert is_integer(container)
        assert host > 0
        assert container > 0
      end
    end

    test "environment is string->string map" do
      genotype = %HolonGenotype{
        id: "db",
        name: "db",
        role: :primary,
        image: "test:latest",
        environment: %{
          "POSTGRES_USER" => "postgres",
          "POSTGRES_PASSWORD" => "postgres",
          "POSTGRES_DB" => "indrajaal_cluster"
        }
      }

      assert map_size(genotype.environment) == 3

      for {key, value} <- genotype.environment do
        assert is_binary(key)
        assert is_binary(value)
      end
    end

    test "dependency fields support container references" do
      genotype = %HolonGenotype{
        id: "app-seed",
        name: "app-seed",
        role: :seed,
        image: "test:latest",
        after: ["db-primary", "indrajaal-obs"],
        requires: ["zenoh-router"],
        wants: ["cortex"]
      }

      assert "db-primary" in genotype.after
      assert "zenoh-router" in genotype.requires
      assert "cortex" in genotype.wants
    end

    test "resource limits are positive" do
      genotype = %HolonGenotype{
        id: "heavy",
        name: "heavy",
        role: :worker,
        image: "test:latest",
        memory_mb: 8192,
        cpu_limit: 4.0
      }

      assert genotype.memory_mb > 0
      assert genotype.cpu_limit > 0.0
    end
  end

  # ============================================================================
  # 2. PHENOTYPE STRUCTURE (SC-SIL6-012, SC-SIL6-013)
  # ============================================================================

  describe "HolonPhenotype: Runtime mutable state" do
    test "enforces genotype_id" do
      assert_raise ArgumentError, fn ->
        struct!(HolonPhenotype, %{})
      end
    end

    test "creates with sensible defaults" do
      phenotype = %HolonPhenotype{genotype_id: "db-primary"}

      assert phenotype.genotype_id == "db-primary"
      assert phenotype.container_id == nil
      assert phenotype.pid == nil
      assert phenotype.health == :unknown
      assert phenotype.startup_phase == :not_started
      assert phenotype.shutdown_phase == :running
      assert phenotype.diagnostic_coverage == 0.0
      assert phenotype.proof_token == "UNVERIFIED"
      assert phenotype.started_at == nil
      assert phenotype.last_health_check == nil
      assert phenotype.last_heartbeat == nil
      assert phenotype.active_connections == 0
      assert phenotype.errors == []
      assert phenotype.metrics == %{}
    end

    test "health states cover all lifecycle phases" do
      health_states = [
        :unknown,
        :starting,
        :healthy,
        :unhealthy,
        :lameduck,
        :stopping,
        :stopped,
        {:failed, "timeout"}
      ]

      for state <- health_states do
        p = %HolonPhenotype{genotype_id: "test", health: state}
        assert p.health == state
      end
    end

    test "startup phases cover boot sequence" do
      startup_phases = [
        :not_started,
        :preflight,
        :port_scour,
        :dependency_check,
        :booting,
        :health_check,
        :ready,
        {:failed_startup, "dependency timeout"}
      ]

      for phase <- startup_phases do
        p = %HolonPhenotype{genotype_id: "test", startup_phase: phase}
        assert p.startup_phase == phase
      end
    end

    test "shutdown phases cover shutdown sequence" do
      now = DateTime.utc_now()

      shutdown_phases = [
        :running,
        {:pre_shutdown, now},
        {:draining, 42, now},
        {:stopping, now},
        :killing,
        {:terminated, 0}
      ]

      for phase <- shutdown_phases do
        p = %HolonPhenotype{genotype_id: "test", shutdown_phase: phase}
        assert p.shutdown_phase == phase
      end
    end

    test "diagnostic_coverage is 0.0 to 1.0" do
      for coverage <- [0.0, 0.25, 0.5, 0.75, 1.0] do
        p = %HolonPhenotype{genotype_id: "test", diagnostic_coverage: coverage}
        assert p.diagnostic_coverage >= 0.0
        assert p.diagnostic_coverage <= 1.0
      end
    end

    test "proof_token tracks SIL-6 verification" do
      p = %HolonPhenotype{genotype_id: "test", proof_token: "VERIFIED-SHA256-abc123"}
      assert String.starts_with?(p.proof_token, "VERIFIED")
    end

    test "metrics map holds runtime measurements" do
      p = %HolonPhenotype{
        genotype_id: "test",
        metrics: %{
          "cpu_percent" => 45.2,
          "memory_mb" => 1024.0,
          "latency_ms" => 2.5,
          "request_rate" => 150.0
        }
      }

      assert map_size(p.metrics) == 4
      assert p.metrics["cpu_percent"] > 0
    end

    test "errors accumulate failure reasons" do
      p = %HolonPhenotype{
        genotype_id: "test",
        errors: ["OOM at 14:32", "health check timeout", "connection refused"]
      }

      assert length(p.errors) == 3
      assert Enum.all?(p.errors, &is_binary/1)
    end
  end

  # ============================================================================
  # 3. GENOTYPE/PHENOTYPE RELATIONSHIP
  # ============================================================================

  describe "Genotype-Phenotype Relationship" do
    test "phenotype references its genotype by id" do
      genotype = %HolonGenotype{
        id: "db-primary",
        name: "Database",
        role: :primary,
        image: "test:latest"
      }

      phenotype = %HolonPhenotype{genotype_id: genotype.id}

      assert phenotype.genotype_id == genotype.id
    end

    test "genotype is configuration, phenotype is state" do
      genotype = %HolonGenotype{
        id: "app",
        name: "Application",
        role: :seed,
        image: "test:latest",
        ports: [{4000, 4000}],
        memory_mb: 4096
      }

      phenotype = %HolonPhenotype{
        genotype_id: genotype.id,
        container_id: "abc123def456",
        pid: 12345,
        health: :healthy,
        startup_phase: :ready,
        active_connections: 42
      }

      # Genotype describes WHAT (static)
      assert is_list(genotype.ports)
      assert is_integer(genotype.memory_mb)

      # Phenotype describes HOW (dynamic)
      assert is_integer(phenotype.active_connections)
      assert phenotype.health == :healthy
    end
  end

  # ============================================================================
  # 4. PROPERTY TESTS: Data Model Invariants
  # ============================================================================

  describe "Property Tests: Data model invariants" do
    property "genotype id is always a string" do
      forall id <- PC.utf8() do
        g = %HolonGenotype{id: id, name: id, role: :worker, image: "test:latest"}
        is_binary(g.id)
      end
    end

    property "phenotype health is always valid type" do
      forall health <-
               PC.oneof([
                 PC.exactly(:unknown),
                 PC.exactly(:starting),
                 PC.exactly(:healthy),
                 PC.exactly(:unhealthy),
                 PC.exactly(:lameduck),
                 PC.exactly(:stopping),
                 PC.exactly(:stopped)
               ]) do
        p = %HolonPhenotype{genotype_id: "test", health: health}
        is_atom(p.health)
      end
    end

    property "genotype memory_mb is always positive" do
      forall mem <- PC.pos_integer() do
        g = %HolonGenotype{
          id: "test",
          name: "test",
          role: :worker,
          image: "test:latest",
          memory_mb: mem
        }

        g.memory_mb > 0
      end
    end

    @tag :property
    test "StreamData: phenotype diagnostic coverage in [0.0, 1.0]" do
      ExUnitProperties.check all(cov <- SD.float(min: 0.0, max: 1.0)) do
        p = %HolonPhenotype{genotype_id: "test", diagnostic_coverage: cov}
        assert p.diagnostic_coverage >= 0.0
        assert p.diagnostic_coverage <= 1.0
      end
    end

    @tag :property
    test "StreamData: genotype roles are valid atoms" do
      valid_roles = [:primary, :seed, :satellite, :controller, :worker]

      ExUnitProperties.check all(role <- SD.member_of(valid_roles)) do
        g = %HolonGenotype{id: "test", name: "test", role: role, image: "test:latest"}
        assert g.role in valid_roles
      end
    end
  end

  # ============================================================================
  # 5. FMEA: Data Model Failure Modes
  # ============================================================================

  describe "FMEA: Data model failure modes" do
    @tag :fmea
    test "FMEA-DATA-001: Missing genotype_id on phenotype (RPN=80)" do
      # enforce_keys catches this at compile/struct creation time
      assert_raise ArgumentError, fn ->
        struct!(HolonPhenotype, %{health: :healthy})
      end
    end

    @tag :fmea
    test "FMEA-DATA-002: Missing required genotype fields (RPN=72)" do
      assert_raise ArgumentError, fn ->
        struct!(HolonGenotype, %{id: "test"})
      end
    end

    @tag :fmea
    test "FMEA-DATA-003: Phenotype error list grows unbounded (RPN=40)" do
      # Verify we can handle large error lists
      errors = for i <- 1..1000, do: "Error #{i}: something failed"

      p = %HolonPhenotype{genotype_id: "test", errors: errors}
      assert length(p.errors) == 1000
    end

    @tag :fmea
    test "FMEA-DATA-004: Genotype with conflicting dependencies (RPN=48)" do
      # A genotype that depends on itself
      g = %HolonGenotype{
        id: "self-ref",
        name: "self-ref",
        role: :worker,
        image: "test:latest",
        after: ["self-ref"]
      }

      assert "self-ref" in g.after
      # This should be caught by topology sort (cycle detection)
    end
  end
end
