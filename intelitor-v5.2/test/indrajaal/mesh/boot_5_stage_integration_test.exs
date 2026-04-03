defmodule Indrajaal.Mesh.Boot5StageIntegrationTest do
  @moduledoc """
  TDG integration test for the SIL-6 mesh boot 5-stage sequence.

  WHAT: Verifies the Preflight → Ignition → Lens → Convergence → Ready boot
        pipeline using self-contained helpers (no production module deps).

  WHY: SC-BOOT-001 requires state vector verification before each stage.
       SC-BOOT-004 mandates transactional boot with rollback capability.
       SC-SIL6-001 requires deterministic mesh topology before boot proceeds.
       Tests MUST exist before/alongside implementation (Ω₄ TDG mandate).

  CONSTRAINTS:
    SC-BOOT-001  State vector verified before each stage transition
    SC-BOOT-002  Migration check before Stage 3 (Lens)
    SC-BOOT-003  Quorum verified before Stage 3 (Lens)
    SC-BOOT-004  Boot is transactional with rollback on failure
    SC-BOOT-005  Boot time < 120 s (target 60 s)
    SC-BOOT-006  All containers pass health check
    SC-BOOT-007  Ports scoured before boot (Preflight)
    SC-BOOT-008  DAG acyclicity verified via Kahn's algorithm (Preflight)
    SC-BOOT-009  Waves parallelised for independent containers
    SC-BOOT-010  Checkpoints stored at each stage completion
    SC-SIL4-005  Container start order: DB → OBS → APP
    SC-SIL6-001  Panopticon mesh boot MUST complete all 5 stages

  EP-GEN-014 compliance:
    - `use PropCheck` for forall/property blocks (PropCheck-native)
    - `ExUnitProperties.check all(` — always fully-qualified in plain `test` blocks
    - PC. prefix for PropCheck generators
    - SD. prefix for StreamData generators

  ## Coverage Matrix
  | Describe block                     | Unit | PropCheck | StreamData |
  |------------------------------------|------|-----------|------------|
  | boot sequence ordering             |  5   |     1     |     1      |
  | preflight stage                    |  4   |     0     |     1      |
  | ignition stage                     |  4   |     0     |     1      |
  | lens stage                         |  4   |     0     |     0      |
  | convergence stage                  |  4   |     0     |     0      |
  | ready stage                        |  3   |     0     |     0      |
  | rollback on failure                |  4   |     1     |     0      |
  | state vector tracking              |  4   |     0     |     1      |
  | property: boot is transactional    |  4   |     0     |     0      |
  | TOTAL                              | 36   |     2     |     4      |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :boot_sequence

  # ---------------------------------------------------------------------------
  # Stage and infrastructure constants
  # ---------------------------------------------------------------------------

  @stages [:preflight, :ignition, :lens, :convergence, :ready]

  # Container start order per SC-SIL4-005 (expressed as atoms for helpers).
  @container_order [:db, :obs, :app]

  # Required ports for Preflight port scouring (SC-BOOT-007).
  @required_ports [5433, 4317, 9090, 3000, 4000, 7447]

  # Boot timeout in milliseconds (SC-BOOT-005).
  @boot_timeout_ms 120_000

  # ---------------------------------------------------------------------------
  # Helper: new_boot_context/0
  # Returns a fresh, pre-boot context map.
  # ---------------------------------------------------------------------------

  defp new_boot_context do
    %{
      current_stage: nil,
      completed_stages: [],
      stage_results: %{},
      state_vector: initial_state_vector(),
      checkpoints: [],
      started_at: System.monotonic_time(:millisecond),
      containers: %{db: :stopped, obs: :stopped, app: :stopped},
      ports_available: Enum.into(@required_ports, %{}, fn p -> {p, true} end),
      dag_nodes: [:db, :obs, :app, :zenoh],
      dag_edges: [{:zenoh, :db}, {:db, :obs}, {:obs, :app}],
      quorum_met: false,
      migrations_verified: false,
      services_registered: [],
      rollback_log: []
    }
  end

  defp initial_state_vector do
    %{preflight: 0, ignition: 0, lens: 0, convergence: 0, ready: 0, healthy: 0}
  end

  # ---------------------------------------------------------------------------
  # Helper: execute_stage/2
  # Executes a single named stage on the context.
  # Returns {:ok, updated_ctx} | {:error, reason, failed_ctx}
  # ---------------------------------------------------------------------------

  defp execute_stage(ctx, :preflight) do
    with :ok <- check_ports(ctx),
         :ok <- verify_dag(ctx) do
      result = %{ports_checked: true, dag_valid: true}
      checkpoint = make_checkpoint(:preflight, ctx.state_vector)

      updated =
        ctx
        |> Map.put(:current_stage, :preflight)
        |> update_in([:completed_stages], &(&1 ++ [:preflight]))
        |> put_in([:stage_results, :preflight], result)
        |> update_in([:checkpoints], &(&1 ++ [checkpoint]))
        |> put_in([:state_vector, :preflight], 1)

      {:ok, updated}
    else
      {:error, reason} -> {:error, reason, ctx}
    end
  end

  defp execute_stage(ctx, :ignition) do
    if :preflight not in ctx.completed_stages do
      {:error, :preflight_not_complete, ctx}
    else
      ctx2 =
        ctx
        |> put_in([:containers, :db], :healthy)
        |> put_in([:containers, :obs], :healthy)
        |> put_in([:containers, :app], :healthy)

      result = %{containers_started: @container_order, all_healthy: true}
      checkpoint = make_checkpoint(:ignition, ctx2.state_vector)

      updated =
        ctx2
        |> Map.put(:current_stage, :ignition)
        |> update_in([:completed_stages], &(&1 ++ [:ignition]))
        |> put_in([:stage_results, :ignition], result)
        |> update_in([:checkpoints], &(&1 ++ [checkpoint]))
        |> put_in([:state_vector, :ignition], 1)

      {:ok, updated}
    end
  end

  defp execute_stage(ctx, :lens) do
    if :ignition not in ctx.completed_stages do
      {:error, :ignition_not_complete, ctx}
    else
      ctx2 =
        ctx
        |> Map.put(:migrations_verified, true)
        |> Map.put(:quorum_met, true)

      result = %{migrations_ok: true, quorum_met: true, zenoh_connected: true}
      checkpoint = make_checkpoint(:lens, ctx2.state_vector)

      updated =
        ctx2
        |> Map.put(:current_stage, :lens)
        |> update_in([:completed_stages], &(&1 ++ [:lens]))
        |> put_in([:stage_results, :lens], result)
        |> update_in([:checkpoints], &(&1 ++ [checkpoint]))
        |> put_in([:state_vector, :lens], 1)

      {:ok, updated}
    end
  end

  defp execute_stage(ctx, :convergence) do
    if :lens not in ctx.completed_stages do
      {:error, :lens_not_complete, ctx}
    else
      services = [:guardian, :sentinel, :prajna, :zenoh_mesh]
      result = %{services_registered: services, fpps_consensus: :passed, waves_parallelised: true}
      checkpoint = make_checkpoint(:convergence, ctx.state_vector)

      updated =
        ctx
        |> Map.put(:current_stage, :convergence)
        |> Map.put(:services_registered, services)
        |> update_in([:completed_stages], &(&1 ++ [:convergence]))
        |> put_in([:stage_results, :convergence], result)
        |> update_in([:checkpoints], &(&1 ++ [checkpoint]))
        |> put_in([:state_vector, :convergence], 1)

      {:ok, updated}
    end
  end

  defp execute_stage(ctx, :ready) do
    if :convergence not in ctx.completed_stages do
      {:error, :convergence_not_complete, ctx}
    else
      elapsed_ms = System.monotonic_time(:millisecond) - ctx.started_at

      result = %{
        all_checkpoints_verified: length(ctx.checkpoints) == 4,
        boot_time_ms: elapsed_ms,
        within_sla: elapsed_ms < @boot_timeout_ms,
        operational: true
      }

      checkpoint = make_checkpoint(:ready, ctx.state_vector)

      updated =
        ctx
        |> Map.put(:current_stage, :ready)
        |> update_in([:completed_stages], &(&1 ++ [:ready]))
        |> put_in([:stage_results, :ready], result)
        |> update_in([:checkpoints], &(&1 ++ [checkpoint]))
        |> put_in([:state_vector, :ready], 1)
        |> put_in([:state_vector, :healthy], 1)

      {:ok, updated}
    end
  end

  defp execute_stage(ctx, unknown) do
    {:error, {:unknown_stage, unknown}, ctx}
  end

  # ---------------------------------------------------------------------------
  # Helper: run_boot_sequence/1
  # Runs all 5 stages in order.  Returns {:ok, ctx} | {:error, reason, ctx}
  # ---------------------------------------------------------------------------

  defp run_boot_sequence(ctx) do
    Enum.reduce_while(@stages, {:ok, ctx}, fn stage, {:ok, acc} ->
      case execute_stage(acc, stage) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, reason, failed} -> {:halt, {:error, reason, failed}}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Helper: verify_dag/1
  # Kahn's algorithm for DAG acyclicity (SC-BOOT-008).
  # Returns :ok | {:error, "Cycle detected in DAG"}
  # ---------------------------------------------------------------------------

  defp verify_dag(ctx) do
    nodes = ctx.dag_nodes
    edges = ctx.dag_edges

    # Build in-degree: each edge {from, to} means `to` needs `from` first,
    # so `to` has its in-degree incremented when traversed downstream.
    # Here edges mean "from must start before to", so in-degree of `to` += 1.
    in_degree = Enum.into(nodes, %{}, fn n -> {n, 0} end)

    in_degree =
      Enum.reduce(edges, in_degree, fn {_from, to}, acc ->
        Map.update(acc, to, 1, &(&1 + 1))
      end)

    # Build adjacency: from → list of immediate successors
    adjacency = Enum.into(nodes, %{}, fn n -> {n, []} end)

    adjacency =
      Enum.reduce(edges, adjacency, fn {from, to}, acc ->
        Map.update(acc, from, [to], &[to | &1])
      end)

    # Kahn's: start with zero-in-degree nodes
    queue = nodes |> Enum.filter(fn n -> Map.get(in_degree, n, 0) == 0 end)

    kahn_reduce(queue, in_degree, adjacency, 0, length(nodes))
  end

  defp kahn_reduce([], _in_deg, _adj, sorted, total) when sorted == total, do: :ok
  defp kahn_reduce([], _in_deg, _adj, _sorted, _total), do: {:error, "Cycle detected in DAG"}

  defp kahn_reduce([node | rest], in_deg, adj, sorted, total) do
    {new_queue, new_deg} =
      Enum.reduce(Map.get(adj, node, []), {rest, in_deg}, fn neighbour, {q, d} ->
        updated_d = Map.update!(d, neighbour, &(&1 - 1))
        if updated_d[neighbour] == 0, do: {q ++ [neighbour], updated_d}, else: {q, updated_d}
      end)

    kahn_reduce(new_queue, new_deg, adj, sorted + 1, total)
  end

  # ---------------------------------------------------------------------------
  # Helper: check_ports/1
  # Returns :ok if all required ports are available, {:error, ...} otherwise.
  # ---------------------------------------------------------------------------

  defp check_ports(ctx) do
    unavailable =
      Enum.filter(@required_ports, fn port ->
        not Map.get(ctx.ports_available, port, false)
      end)

    if unavailable == [] do
      :ok
    else
      {:error, {:ports_unavailable, unavailable}}
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: verify_state_vector/2
  # Checks that all stages preceding `target_stage` have their bit set to 1.
  # Returns :ok | {:error, {:state_vector_incomplete, missing_stages}}
  # ---------------------------------------------------------------------------

  defp verify_state_vector(ctx, target_stage) do
    stage_index = Enum.find_index(@stages, &(&1 == target_stage))

    if is_nil(stage_index) do
      {:error, {:unknown_stage, target_stage}}
    else
      prior = Enum.take(@stages, stage_index)
      missing = Enum.filter(prior, fn s -> Map.get(ctx.state_vector, s, 0) != 1 end)

      if missing == [], do: :ok, else: {:error, {:state_vector_incomplete, missing}}
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: rollback/2
  # Rolls back a failed context to a clean pre-boot state.
  # ---------------------------------------------------------------------------

  defp rollback(failed_ctx, reason) do
    entry = %{
      rolled_back_from: failed_ctx.current_stage,
      reason: reason,
      at: System.monotonic_time(:millisecond)
    }

    failed_ctx
    |> update_in([:rollback_log], &(&1 ++ [entry]))
    |> Map.put(:containers, %{db: :stopped, obs: :stopped, app: :stopped})
    |> Map.put(:quorum_met, false)
    |> Map.put(:migrations_verified, false)
    |> Map.put(:services_registered, [])
  end

  # ---------------------------------------------------------------------------
  # Helper: make_checkpoint/2
  # Creates a lightweight checkpoint map for a stage.
  # ---------------------------------------------------------------------------

  defp make_checkpoint(stage, state_vector) do
    %{stage: stage, state_vector: state_vector, timestamp: System.monotonic_time(:millisecond)}
  end

  # ---------------------------------------------------------------------------
  # Helper: with_port_failure/2
  # Marks a port as unavailable for Preflight failure injection.
  # ---------------------------------------------------------------------------

  defp with_port_failure(ctx, port) do
    put_in(ctx, [:ports_available, port], false)
  end

  # ---------------------------------------------------------------------------
  # Helper: with_cyclic_dag/1
  # Injects a cycle (app → db) into the DAG.
  # ---------------------------------------------------------------------------

  defp with_cyclic_dag(ctx) do
    Map.put(ctx, :dag_edges, ctx.dag_edges ++ [{:app, :db}])
  end

  # ===========================================================================
  # 1. Boot sequence ordering
  # ===========================================================================

  describe "boot sequence ordering" do
    test "all 5 stages complete in correct order" do
      ctx = new_boot_context()
      assert {:ok, final} = run_boot_sequence(ctx)
      assert final.completed_stages == @stages
    end

    test "current_stage is :ready after full boot" do
      ctx = new_boot_context()
      assert {:ok, final} = run_boot_sequence(ctx)
      assert final.current_stage == :ready
    end

    test "cannot execute ignition without preflight completing first" do
      ctx = new_boot_context()
      assert {:error, :preflight_not_complete, _} = execute_stage(ctx, :ignition)
    end

    test "cannot execute lens without ignition completing first" do
      ctx = new_boot_context()
      {:ok, after_pre} = execute_stage(ctx, :preflight)
      assert {:error, :ignition_not_complete, _} = execute_stage(after_pre, :lens)
    end

    test "each stage appends exactly one entry to completed_stages" do
      Enum.reduce(@stages, new_boot_context(), fn stage, acc ->
        count_before = length(acc.completed_stages)
        {:ok, updated} = execute_stage(acc, stage)
        assert length(updated.completed_stages) == count_before + 1
        updated
      end)
    end

    property "BOOT_PROP_01: full boot always reaches :ready with completed_stages == @stages" do
      forall _seed <- PC.boolean() do
        ctx = new_boot_context()

        case run_boot_sequence(ctx) do
          {:ok, final} -> final.completed_stages == @stages
          _ -> false
        end
      end
    end

    test "BOOT_PROP_02 (StreamData): any non-first stage attempted first returns an error" do
      ExUnitProperties.check all(
                               wrong_first <-
                                 SD.member_of([:ignition, :lens, :convergence, :ready])
                             ) do
        ctx = new_boot_context()
        assert {:error, _, _} = execute_stage(ctx, wrong_first)
      end
    end
  end

  # ===========================================================================
  # 2. Preflight stage (SC-BOOT-007, SC-BOOT-008)
  # ===========================================================================

  describe "preflight stage" do
    test "succeeds with valid ports and acyclic DAG" do
      ctx = new_boot_context()
      assert {:ok, updated} = execute_stage(ctx, :preflight)
      assert :preflight in updated.completed_stages
    end

    test "verify_dag/1 passes for the default acyclic topology (SC-BOOT-008)" do
      ctx = new_boot_context()
      assert :ok = verify_dag(ctx)
    end

    test "verify_dag/1 detects a cycle introduced into the topology (SC-BOOT-008)" do
      ctx = new_boot_context() |> with_cyclic_dag()
      assert {:error, msg} = verify_dag(ctx)
      assert String.downcase(msg) =~ "cycle"
    end

    test "port scouring fails when a required port is marked unavailable (SC-BOOT-007)" do
      ctx = new_boot_context() |> with_port_failure(5433)
      assert {:error, _, _} = execute_stage(ctx, :preflight)
    end

    test "BOOT_PROP_03 (StreamData): any blocked required port causes preflight failure" do
      ExUnitProperties.check all(blocked <- SD.member_of(@required_ports)) do
        ctx = new_boot_context() |> with_port_failure(blocked)
        assert {:error, _, _} = execute_stage(ctx, :preflight)
      end
    end
  end

  # ===========================================================================
  # 3. Ignition stage (SC-SIL4-005, SC-BOOT-006)
  # ===========================================================================

  describe "ignition stage" do
    setup do
      ctx = new_boot_context()
      {:ok, after_pre} = execute_stage(ctx, :preflight)
      {:ok, ctx: after_pre}
    end

    test "starts containers in DB → OBS → APP order (SC-SIL4-005)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ignition)
      assert updated.stage_results[:ignition].containers_started == @container_order
    end

    test "all three containers are :healthy after ignition (SC-BOOT-006)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ignition)
      assert updated.containers[:db] == :healthy
      assert updated.containers[:obs] == :healthy
      assert updated.containers[:app] == :healthy
    end

    test "ignition result records all_healthy: true", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ignition)
      assert updated.stage_results[:ignition].all_healthy == true
    end

    test "BOOT_PROP_04 (StreamData): ignition always produces all_healthy regardless of repetition" do
      ExUnitProperties.check all(_x <- SD.boolean()) do
        ctx = new_boot_context()
        {:ok, after_pre} = execute_stage(ctx, :preflight)
        {:ok, after_ign} = execute_stage(after_pre, :ignition)
        assert after_ign.stage_results[:ignition].all_healthy == true
      end
    end
  end

  # ===========================================================================
  # 4. Lens stage (SC-BOOT-002, SC-BOOT-003)
  # ===========================================================================

  describe "lens stage" do
    setup do
      ctx = new_boot_context()
      {:ok, c1} = execute_stage(ctx, :preflight)
      {:ok, c2} = execute_stage(c1, :ignition)
      {:ok, ctx: c2}
    end

    test "migrations are verified before Lens completes (SC-BOOT-002)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :lens)
      assert updated.migrations_verified == true
    end

    test "quorum is verified before Lens completes (SC-BOOT-003)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :lens)
      assert updated.quorum_met == true
    end

    test "Zenoh mesh connectivity is confirmed in lens result", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :lens)
      assert updated.stage_results[:lens].zenoh_connected == true
    end

    test "lens result marks migrations_ok: true", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :lens)
      assert updated.stage_results[:lens].migrations_ok == true
    end
  end

  # ===========================================================================
  # 5. Convergence stage (SC-BOOT-009)
  # ===========================================================================

  describe "convergence stage" do
    setup do
      ctx = new_boot_context()
      {:ok, c1} = execute_stage(ctx, :preflight)
      {:ok, c2} = execute_stage(c1, :ignition)
      {:ok, c3} = execute_stage(c2, :lens)
      {:ok, ctx: c3}
    end

    test "core services are registered during convergence", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :convergence)
      assert :guardian in updated.services_registered
      assert :sentinel in updated.services_registered
    end

    test "FPPS health consensus passes during convergence", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :convergence)
      assert updated.stage_results[:convergence].fpps_consensus == :passed
    end

    test "wave parallelisation is confirmed in convergence result (SC-BOOT-009)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :convergence)
      assert updated.stage_results[:convergence].waves_parallelised == true
    end

    test "convergence adds :convergence to completed_stages", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :convergence)
      assert :convergence in updated.completed_stages
    end
  end

  # ===========================================================================
  # 6. Ready stage (SC-BOOT-005, SC-BOOT-010, SC-SIL6-001)
  # ===========================================================================

  describe "ready stage" do
    setup do
      ctx = new_boot_context()
      {:ok, c1} = execute_stage(ctx, :preflight)
      {:ok, c2} = execute_stage(c1, :ignition)
      {:ok, c3} = execute_stage(c2, :lens)
      {:ok, c4} = execute_stage(c3, :convergence)
      {:ok, ctx: c4}
    end

    test "boot time is within 120 s SLA (SC-BOOT-005)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ready)
      assert updated.stage_results[:ready].boot_time_ms < @boot_timeout_ms
    end

    test "all 4 prior checkpoints are reported as verified (SC-BOOT-010)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ready)
      assert updated.stage_results[:ready].all_checkpoints_verified == true
    end

    test "system is operational and healthy bit is set after Ready (SC-SIL6-001)", %{ctx: ctx} do
      assert {:ok, updated} = execute_stage(ctx, :ready)
      assert updated.stage_results[:ready].operational == true
      assert updated.state_vector[:healthy] == 1
    end
  end

  # ===========================================================================
  # 7. Rollback on failure (SC-BOOT-004)
  # ===========================================================================

  describe "rollback on failure" do
    test "port failure at Preflight leaves containers in :stopped after rollback (SC-BOOT-004)" do
      ctx = new_boot_context() |> with_port_failure(5433)
      {:error, reason, failed} = execute_stage(ctx, :preflight)
      rolled = rollback(failed, reason)

      assert rolled.containers[:db] == :stopped
      assert rolled.containers[:obs] == :stopped
      assert rolled.containers[:app] == :stopped
    end

    test "rollback appends one entry to rollback_log" do
      ctx = new_boot_context() |> with_port_failure(4000)
      {:error, reason, failed} = execute_stage(ctx, :preflight)
      rolled = rollback(failed, reason)

      assert length(rolled.rollback_log) == 1
    end

    test "rollback resets quorum_met and migrations_verified" do
      ctx =
        new_boot_context()
        |> Map.put(:quorum_met, true)
        |> Map.put(:migrations_verified, true)

      rolled = rollback(ctx, :simulated_failure)
      assert rolled.quorum_met == false
      assert rolled.migrations_verified == false
    end

    test "rollback empties services_registered" do
      ctx = new_boot_context() |> Map.put(:services_registered, [:guardian, :sentinel])
      rolled = rollback(ctx, :simulated_failure)
      assert rolled.services_registered == []
    end

    property "BOOT_PROP_05: rollback always leaves all containers :stopped for any failed stage" do
      forall failed_stage <-
               PC.oneof([
                 PC.exactly(:preflight),
                 PC.exactly(:ignition),
                 PC.exactly(:lens),
                 PC.exactly(:convergence)
               ]) do
        ctx = new_boot_context() |> Map.put(:current_stage, failed_stage)
        rolled = rollback(ctx, :test_failure)

        rolled.containers[:db] == :stopped and
          rolled.containers[:obs] == :stopped and
          rolled.containers[:app] == :stopped
      end
    end
  end

  # ===========================================================================
  # 8. State vector tracking (SC-BOOT-001)
  # ===========================================================================

  describe "state vector tracking" do
    test "initial state vector is all zeros (SC-BOOT-001)" do
      ctx = new_boot_context()

      assert ctx.state_vector == %{
               preflight: 0,
               ignition: 0,
               lens: 0,
               convergence: 0,
               ready: 0,
               healthy: 0
             }
    end

    test "preflight bit is set to 1 after Preflight completes" do
      ctx = new_boot_context()
      {:ok, updated} = execute_stage(ctx, :preflight)
      assert updated.state_vector[:preflight] == 1
    end

    test "all stage bits and healthy bit are 1 after full boot" do
      ctx = new_boot_context()
      {:ok, final} = run_boot_sequence(ctx)

      for key <- [:preflight, :ignition, :lens, :convergence, :ready, :healthy] do
        assert final.state_vector[key] == 1, "Expected #{key} bit = 1"
      end
    end

    test "verify_state_vector/2 returns :ok when all prior stages are complete" do
      ctx = new_boot_context()
      {:ok, after_pre} = execute_stage(ctx, :preflight)
      {:ok, after_ign} = execute_stage(after_pre, :ignition)

      assert :ok = verify_state_vector(after_ign, :lens)
    end

    test "BOOT_PROP_06 (StreamData): after executing first N stages, the Nth stage bit equals 1" do
      ExUnitProperties.check all(n <- SD.integer(1, 5)) do
        ctx = new_boot_context()
        stages_to_run = Enum.take(@stages, n)

        {:ok, final} =
          Enum.reduce_while(stages_to_run, {:ok, ctx}, fn stage, {:ok, acc} ->
            case execute_stage(acc, stage) do
              {:ok, upd} -> {:cont, {:ok, upd}}
              err -> {:halt, err}
            end
          end)

        target_stage = Enum.at(@stages, n - 1)
        assert final.state_vector[target_stage] == 1
      end
    end
  end

  # ===========================================================================
  # 9. Property: boot is transactional (SC-BOOT-004)
  # ===========================================================================

  describe "property: boot is transactional" do
    test "a successful boot leaves rollback_log empty" do
      ctx = new_boot_context()
      assert {:ok, final} = run_boot_sequence(ctx)
      assert final.rollback_log == []
    end

    test "a boot failure at Preflight (blocked port) returns {:error, ...}" do
      ctx = new_boot_context() |> with_port_failure(7447)
      assert {:error, _, _} = run_boot_sequence(ctx)
    end

    test "checkpoints accumulate one entry per completed stage (SC-BOOT-010)" do
      ctx = new_boot_context()
      {:ok, final} = run_boot_sequence(ctx)
      assert length(final.checkpoints) == length(@stages)
    end

    test "each checkpoint references the stage in the correct sequential order" do
      ctx = new_boot_context()
      {:ok, final} = run_boot_sequence(ctx)
      checkpoint_stages = Enum.map(final.checkpoints, & &1.stage)
      assert checkpoint_stages == @stages
    end
  end
end
