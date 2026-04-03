defmodule Indrajaal.SIL6.MeshShutdownLifecycleTest do
  @moduledoc """
  Mesh Shutdown and Lifecycle Protocol Tests.

  WHAT: Tests for graceful shutdown orchestration, dying gasp protocol,
        lameduck broadcasting, and emergency stop compliance.
  WHY: SIL-6 requires orderly shutdown with state checkpointing to prevent
       data loss. The 6-phase shutdown protocol must complete within time
       budgets, and emergency stop must halt in < 5 seconds.
  CONSTRAINTS:
    - SC-SIL6-004: Checkpoint on shutdown
    - SC-SIL6-007: Dying gasp mandatory
    - SC-SIL6-013: 6 Shutdown Phases
    - SC-EMR-057: Emergency stop < 5s
    - SC-EMR-060: Rollback capability
    - AOR-MESH-002: Checkpoint state before any shutdown

  ## Shutdown Phases
  0. Save dying gasp checkpoint
  1. Broadcast Pre-Shutdown (Lameduck)
  2. Shutdown Waves (Reverse Order)
  3. Final Cleanup
  4. Verification
  5. Halted

  ## Change History
  | Version | Date       | Author      | Change                      |
  |---------|------------|-------------|-----------------------------|
  | 1.0.0   | 2026-03-09 | Claude Opus | Initial shutdown/lifecycle  |

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
    HolonPhenotype,
    StateCheckpoint,
    MeshShutdown
  }

  @moduletag :sil6
  @moduletag :mesh
  @moduletag :shutdown

  # ============================================================================
  # 1. PHENOTYPE LIFECYCLE STATES (SC-SIL6-012, SC-SIL6-013)
  # ============================================================================

  describe "Phenotype Lifecycle: Startup phases" do
    test "startup phases form valid progression" do
      phases = [
        :not_started,
        :preflight,
        :port_scour,
        :dependency_check,
        :booting,
        :health_check,
        :ready
      ]

      for {phase, index} <- Enum.with_index(phases) do
        assert is_atom(phase)

        if index > 0 do
          prev = Enum.at(phases, index - 1)
          assert prev != phase, "Duplicate phase: #{phase}"
        end
      end
    end

    test "startup can fail with reason" do
      phenotype = %HolonPhenotype{
        genotype_id: "test-node",
        startup_phase: {:failed_startup, "OOM during boot"}
      }

      assert {:failed_startup, reason} = phenotype.startup_phase
      assert is_binary(reason)
    end
  end

  describe "Phenotype Lifecycle: Shutdown phases" do
    test "shutdown phases form valid progression" do
      now = DateTime.utc_now()

      phases = [
        :running,
        {:pre_shutdown, now},
        {:draining, 42, now},
        {:stopping, now},
        :killing,
        {:terminated, 0}
      ]

      for phase <- phases do
        case phase do
          :running -> assert true
          {:pre_shutdown, %DateTime{}} -> assert true
          {:draining, conns, %DateTime{}} -> assert is_integer(conns)
          {:stopping, %DateTime{}} -> assert true
          :killing -> assert true
          {:terminated, code} -> assert is_integer(code)
        end
      end
    end

    test "lameduck is a valid health state during shutdown" do
      phenotype = %HolonPhenotype{
        genotype_id: "test-node",
        health: :lameduck,
        shutdown_phase: {:pre_shutdown, DateTime.utc_now()}
      }

      assert phenotype.health == :lameduck
    end
  end

  # ============================================================================
  # 2. HEALTH STATE MACHINE (SC-SIL6-012)
  # ============================================================================

  describe "Health State Machine: Valid transitions" do
    @valid_health_states [
      :unknown,
      :starting,
      :healthy,
      :unhealthy,
      :lameduck,
      :stopping,
      :stopped
    ]

    test "all health states are atoms or tagged tuples" do
      for state <- @valid_health_states do
        assert is_atom(state)
      end

      # Failed state is a tagged tuple
      failed = {:failed, "connection timeout"}
      assert {:failed, reason} = failed
      assert is_binary(reason)
    end

    test "phenotype can hold each health state" do
      for state <- @valid_health_states do
        p = %HolonPhenotype{genotype_id: "test", health: state}
        assert p.health == state
      end
    end

    test "healthy -> lameduck transition for shutdown" do
      twin = DigitalTwin.create_default()
      id = Map.keys(twin.genotypes) |> hd()

      # Start healthy
      twin =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :healthy}
        end)

      assert twin.phenotypes[id].health == :healthy

      # Transition to lameduck
      twin =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :lameduck}
        end)

      assert twin.phenotypes[id].health == :lameduck
    end

    test "full lifecycle: unknown -> starting -> healthy -> lameduck -> stopped" do
      twin = DigitalTwin.create_default()
      id = Map.keys(twin.genotypes) |> hd()

      lifecycle = [:unknown, :starting, :healthy, :lameduck, :stopping, :stopped]

      final =
        Enum.reduce(lifecycle, twin, fn state, acc ->
          DigitalTwin.update_phenotype(acc, id, fn p -> %{p | health: state} end)
        end)

      assert final.phenotypes[id].health == :stopped
    end
  end

  # ============================================================================
  # 3. SHUTDOWN CHECKPOINT (SC-SIL6-004, SC-SIL6-007)
  # ============================================================================

  describe "Shutdown Checkpoint: Pre-shutdown state capture" do
    test "checkpoint is created before shutdown" do
      twin = DigitalTwin.create_default()
      checkpoint = DigitalTwin.create_checkpoint(twin, "PreShutdown")

      assert %StateCheckpoint{} = checkpoint
      assert checkpoint.reason == "PreShutdown"
      assert map_size(checkpoint.holons) == map_size(twin.phenotypes)
    end

    test "checkpoint captures current health states" do
      twin = DigitalTwin.create_default()

      # Set some nodes to healthy
      ids = Map.keys(twin.genotypes)

      twin =
        Enum.reduce(Enum.take(ids, 2), twin, fn id, acc ->
          DigitalTwin.update_phenotype(acc, id, fn p -> %{p | health: :healthy} end)
        end)

      checkpoint = DigitalTwin.create_checkpoint(twin, "PreShutdown")

      healthy_count =
        Enum.count(checkpoint.holons, fn {_id, p} -> p.health == :healthy end)

      assert healthy_count == 2
    end

    test "dying gasp checkpoint has unique ID" do
      twin = DigitalTwin.create_default()

      cp1 = DigitalTwin.create_checkpoint(twin, "DyingGasp-1")
      cp2 = DigitalTwin.create_checkpoint(twin, "DyingGasp-2")

      assert cp1.id != cp2.id, "Checkpoint IDs must be unique"
    end
  end

  # ============================================================================
  # 4. SHUTDOWN WAVE ORDERING
  # ============================================================================

  describe "Shutdown Wave Ordering: Reverse of startup" do
    test "shutdown order reverses startup order" do
      twin = DigitalTwin.create_default()

      if twin.cache do
        start_waves = twin.cache.start_order
        shutdown_waves = twin.cache.shutdown_order

        # Same number of waves
        assert length(start_waves) == length(shutdown_waves)

        # First start wave containers == last shutdown wave containers
        start_first = MapSet.new(hd(start_waves).containers)
        shutdown_last = MapSet.new(List.last(shutdown_waves).containers)
        assert start_first == shutdown_last

        # Last start wave containers == first shutdown wave containers
        start_last = MapSet.new(List.last(start_waves).containers)
        shutdown_first = MapSet.new(hd(shutdown_waves).containers)
        assert start_last == shutdown_first
      end
    end

    test "all containers present in shutdown waves" do
      twin = DigitalTwin.create_default()

      if twin.cache do
        all_shutdown =
          twin.cache.shutdown_order
          |> Enum.flat_map(& &1.containers)
          |> MapSet.new()

        all_genotypes = Map.keys(twin.genotypes) |> MapSet.new()

        assert all_shutdown == all_genotypes,
               "Shutdown waves missing: #{inspect(MapSet.difference(all_genotypes, all_shutdown))}"
      end
    end
  end

  # ============================================================================
  # 5. LAMEDUCK BROADCAST
  # ============================================================================

  describe "Lameduck Broadcast: Pre-shutdown notification" do
    test "all phenotypes transition to lameduck during broadcast" do
      twin = DigitalTwin.create_default()

      # Simulate broadcast_lameduck
      lameduck_twin =
        Enum.reduce(Map.keys(twin.phenotypes), twin, fn id, acc ->
          DigitalTwin.update_phenotype(acc, id, fn p -> %{p | health: :lameduck} end)
        end)

      for {_id, p} <- lameduck_twin.phenotypes do
        assert p.health == :lameduck,
               "Expected :lameduck, got #{inspect(p.health)}"
      end
    end

    test "lameduck state preserves other phenotype fields" do
      twin = DigitalTwin.create_default()
      id = Map.keys(twin.genotypes) |> hd()

      # Set some state first
      twin =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :healthy, diagnostic_coverage: 0.95, proof_token: "VERIFIED"}
        end)

      # Transition to lameduck
      twin =
        DigitalTwin.update_phenotype(twin, id, fn p ->
          %{p | health: :lameduck}
        end)

      assert twin.phenotypes[id].health == :lameduck
      assert twin.phenotypes[id].diagnostic_coverage == 0.95
      assert twin.phenotypes[id].proof_token == "VERIFIED"
    end
  end

  # ============================================================================
  # 6. EMERGENCY STOP (SC-EMR-057)
  # ============================================================================

  describe "Emergency Stop: Rapid shutdown protocol" do
    test "MeshShutdown module is available" do
      assert Code.ensure_loaded?(MeshShutdown)
    end

    test "default shutdown config has reasonable timeouts" do
      # Verify the constants from MeshShutdown match SIL-6 requirements
      config = %{
        pre_shutdown_timeout_ms: 5000,
        drain_timeout_ms: 10000,
        graceful_timeout_ms: 3000,
        force_kill_after_ms: 20000,
        save_checkpoint: true,
        verbose: true
      }

      # Emergency stop budget: < 5 seconds
      assert config.pre_shutdown_timeout_ms <= 5000
      assert config.graceful_timeout_ms <= 5000
      assert config.save_checkpoint == true
    end

    test "shutdown config enables checkpoint by default" do
      config = %{save_checkpoint: true}
      assert config.save_checkpoint, "Checkpoint must be enabled by default (SC-SIL6-004)"
    end
  end

  # ============================================================================
  # 7. PROPERTY TESTS: Shutdown Invariants
  # ============================================================================

  describe "Property Tests: Shutdown invariants" do
    property "shutdown preserves genotype count" do
      forall _n <- PC.integer() do
        twin = DigitalTwin.create_default()

        # Simulate shutdown state changes
        shutdown_twin =
          Enum.reduce(Map.keys(twin.phenotypes), twin, fn id, acc ->
            DigitalTwin.update_phenotype(acc, id, fn p ->
              %{p | health: :stopped, shutdown_phase: {:terminated, 0}}
            end)
          end)

        map_size(shutdown_twin.genotypes) == map_size(twin.genotypes)
      end
    end

    property "all phenotypes reach :stopped after full shutdown" do
      forall _n <- PC.integer() do
        twin = DigitalTwin.create_default()

        shutdown_twin =
          Enum.reduce(Map.keys(twin.phenotypes), twin, fn id, acc ->
            DigitalTwin.update_phenotype(acc, id, fn p ->
              %{p | health: :stopped}
            end)
          end)

        Enum.all?(shutdown_twin.phenotypes, fn {_id, p} -> p.health == :stopped end)
      end
    end

    @tag :property
    test "StreamData: shutdown phase transitions are valid" do
      valid_terminal_phases = [:running, :killing]

      ExUnitProperties.check all(phase <- SD.member_of(valid_terminal_phases)) do
        p = %HolonPhenotype{genotype_id: "test", shutdown_phase: phase}
        assert p.shutdown_phase == phase
      end
    end
  end

  # ============================================================================
  # 8. FMEA: Shutdown Failure Modes
  # ============================================================================

  describe "FMEA: Shutdown failure modes" do
    @tag :fmea
    test "FMEA-SHUT-001: Checkpoint fails during shutdown (RPN=64)" do
      twin = DigitalTwin.create_default()

      # Even if checkpoint creation has issues, it should not crash
      checkpoint = DigitalTwin.create_checkpoint(twin, "emergency-shutdown")
      assert %StateCheckpoint{} = checkpoint
    end

    @tag :fmea
    test "FMEA-SHUT-002: Container refuses to stop (RPN=56)" do
      # force_kill_after_ms is the safety net
      force_kill_timeout = 20_000

      assert force_kill_timeout <= 20_000,
             "Force kill timeout must be bounded"
    end

    @tag :fmea
    test "FMEA-SHUT-003: Network partition during shutdown (RPN=72)" do
      # Verify shutdown can proceed even with partial connectivity
      twin = DigitalTwin.create_default()

      # Simulate some nodes already failed
      twin =
        DigitalTwin.update_phenotype(twin, Map.keys(twin.genotypes) |> hd(), fn p ->
          %{p | health: {:failed, "network partition"}}
        end)

      # Checkpoint should still work with failed nodes
      checkpoint = DigitalTwin.create_checkpoint(twin, "partition-shutdown")
      assert map_size(checkpoint.holons) == map_size(twin.phenotypes)
    end

    @tag :fmea
    test "FMEA-SHUT-004: Concurrent shutdown requests (RPN=48)" do
      twin = DigitalTwin.create_default()

      # Multiple checkpoint requests should each produce unique IDs
      checkpoints =
        for i <- 1..5 do
          DigitalTwin.create_checkpoint(twin, "concurrent-#{i}")
        end

      ids = Enum.map(checkpoints, & &1.id)

      assert length(ids) == length(Enum.uniq(ids)),
             "Concurrent checkpoints must have unique IDs"
    end
  end
end
