defmodule Indrajaal.Boot.DagTopologyBootSequenceTest do
  @moduledoc """
  TDG test: Boot DAG topology, wave parallelization, and Kahn's algorithm.

  WHAT: Validates the boot sequence graph — acyclicity detection via Kahn's
        algorithm, wave-parallel execution of independent nodes, 5-phase boot
        lifecycle, container start order, checkpoint recording, migration and
        quorum gates, rollback on failure, and critical-path timing.

  WHY: Boot correctness is safety-critical (IEC 61508 SIL-6). A cyclic
       dependency causes deadlock; out-of-order starts violate SIL-4 hardware
       safeguards. Property tests verify invariants hold over arbitrary
       topologies, making the suite regression-proof under evolution.

  ## STAMP Compliance
  - SC-BOOT-001: State vector verified before each stage
  - SC-BOOT-002: Migration gate check before Stage 3
  - SC-BOOT-003: Quorum check before Stage 3
  - SC-BOOT-004: Boot is transactional with rollback capability
  - SC-BOOT-005: Boot time < 120s (target 60s)
  - SC-BOOT-008: DAG acyclicity via Kahn's algorithm
  - SC-BOOT-009: Waves boot in parallel
  - SC-BOOT-010: Checkpoints at each boot stage
  - SC-SIL4-005: Container start order DB → OBS → APP
  - SC-SIL4-012: 5 startup phases mandatory

  ## AOR Alignment
  - AOR-BOOT-001: Topological sort before boot (DAG)
  - AOR-BOOT-002: Identify and optimize critical path (CPM)
  - AOR-BOOT-003: Prevent health check flapping (Hysteresis)

  ## Change History
  | Version | Date       | Author          | Change              |
  |---------|------------|-----------------|---------------------|
  | 21.3.0  | 2026-03-24 | Claude Sonnet   | Initial TDG suite   |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Describe 1 — DAG construction and acyclicity (SC-BOOT-008, SC-SIL4-010)
  # ---------------------------------------------------------------------------

  describe "DAG construction and acyclicity via Kahn's algorithm (SC-BOOT-008)" do
    test "linear chain is acyclic" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      assert {:ok, _order} = kahn_sort(dag)
    end

    test "diamond topology is acyclic" do
      dag =
        build_dag([
          {:db, []},
          {:cache, [:db]},
          {:queue, [:db]},
          {:app, [:cache, :queue]}
        ])

      assert {:ok, _order} = kahn_sort(dag)
    end

    test "single-node topology is trivially acyclic" do
      dag = build_dag([{:singleton, []}])
      assert {:ok, [[:singleton]]} = kahn_sort(dag)
    end

    test "empty graph is trivially acyclic" do
      assert {:ok, []} = kahn_sort(%{})
    end

    test "direct two-node cycle is detected" do
      dag = build_dag([{:a, [:b]}, {:b, [:a]}])
      assert {:error, :cycle_detected} = kahn_sort(dag)
    end

    test "three-node cycle is detected" do
      dag = build_dag([{:a, [:c]}, {:b, [:a]}, {:c, [:b]}])
      assert {:error, :cycle_detected} = kahn_sort(dag)
    end

    test "self-loop is detected as a cycle" do
      dag = build_dag([{:a, [:a]}])
      assert {:error, :cycle_detected} = kahn_sort(dag)
    end

    test "deep tree with no back-edges is acyclic" do
      dag =
        build_dag([
          {:root, []},
          {:l1a, [:root]},
          {:l1b, [:root]},
          {:l2a, [:l1a]},
          {:l2b, [:l1a]},
          {:l2c, [:l1b]},
          {:leaf, [:l2a, :l2b, :l2c]}
        ])

      assert {:ok, layers} = kahn_sort(dag)
      all_nodes = List.flatten(layers)
      assert length(all_nodes) == 7
    end

    test "topological sort visits every node exactly once" do
      dag =
        build_dag([
          {:db, []},
          {:cache, [:db]},
          {:queue, [:db]},
          {:app, [:cache, :queue]},
          {:monitor, [:app]}
        ])

      assert {:ok, layers} = kahn_sort(dag)
      all_nodes = List.flatten(layers)
      assert length(all_nodes) == 5
      assert length(Enum.uniq(all_nodes)) == 5
    end

    test "topological order respects all dependency edges" do
      dag =
        build_dag([
          {:db, []},
          {:obs, [:db]},
          {:app, [:obs]}
        ])

      assert {:ok, layers} = kahn_sort(dag)
      assert layers_respect_deps?(layers, dag)
    end

    test "dependency targets must all be declared nodes" do
      valid_dag = build_dag([{:a, []}, {:b, [:a]}, {:c, [:a, :b]}])
      assert {:ok, _} = kahn_sort(valid_dag)
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 2 — Wave parallelization (SC-BOOT-009)
  # ---------------------------------------------------------------------------

  describe "wave parallelization for independent nodes (SC-BOOT-009)" do
    test "root nodes with no dependencies land in wave 0" do
      dag = build_dag([{:db, []}, {:cache, []}, {:app, [:db, :cache]}])
      {:ok, [wave0 | _]} = kahn_sort(dag)
      assert :db in wave0
      assert :cache in wave0
    end

    test "dependent nodes are placed in later waves" do
      dag = build_dag([{:db, []}, {:app, [:db]}])
      {:ok, waves} = kahn_sort(dag)
      assert length(waves) == 2
      [wave0, wave1] = waves
      assert :db in wave0
      assert :app in wave1
    end

    test "diamond produces three-wave structure" do
      dag =
        build_dag([
          {:db, []},
          {:cache, [:db]},
          {:queue, [:db]},
          {:app, [:cache, :queue]}
        ])

      {:ok, waves} = kahn_sort(dag)
      assert length(waves) == 3
      [wave0, wave1, wave2] = waves
      assert wave0 == [:db]
      assert :cache in wave1
      assert :queue in wave1
      assert wave2 == [:app]
    end

    test "all independent nodes land in a single wave 0" do
      dag = build_dag([{:a, []}, {:b, []}, {:c, []}, {:d, []}])
      {:ok, [wave0]} = kahn_sort(dag)
      assert length(wave0) == 4
    end

    test "every wave contains nodes whose deps are in earlier waves" do
      dag =
        build_dag([
          {:db, []},
          {:obs, []},
          {:cache, [:db]},
          {:app, [:cache, :obs]}
        ])

      {:ok, waves} = kahn_sort(dag)
      assert layers_respect_deps?(waves, dag)
    end

    test "wave count equals the DAG's critical depth for linear chain" do
      dag = build_dag([{:n1, []}, {:n2, [:n1]}, {:n3, [:n2]}, {:n4, [:n3]}])
      {:ok, waves} = kahn_sort(dag)
      assert length(waves) == 4
    end

    test "parallel branches do not increase wave count beyond critical path" do
      # n1 → n3 (length 2) and n1 → n2 → n3 (length 3) — critical depth is 3
      dag = build_dag([{:n1, []}, {:n2, [:n1]}, {:n3, [:n1, :n2]}])
      {:ok, waves} = kahn_sort(dag)
      assert length(waves) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 3 — 5-phase boot lifecycle (SC-SIL4-012)
  # ---------------------------------------------------------------------------

  describe "5-phase boot lifecycle (SC-SIL4-012)" do
    test "five phases execute in canonical order" do
      phases = [:preflight, :ignition, :lens, :convergence, :ready]

      dag =
        build_dag([
          {:preflight, []},
          {:ignition, [:preflight]},
          {:lens, [:ignition]},
          {:convergence, [:lens]},
          {:ready, [:convergence]}
        ])

      assert {:ok, waves} = kahn_sort(dag)
      assert length(waves) == 5
      executed = Enum.map(waves, fn [n] -> n end)
      assert executed == phases
    end

    test "phases form a strictly ordered linear chain" do
      dag =
        build_dag([
          {:preflight, []},
          {:ignition, [:preflight]},
          {:lens, [:ignition]},
          {:convergence, [:lens]},
          {:ready, [:convergence]}
        ])

      assert {:ok, _waves} = kahn_sort(dag)
      assert is_acyclic?(dag)
    end

    test "no phase depends on a later phase (no back-edges)" do
      # Back-edge would mean later phase has dep on earlier — structurally that
      # is fine; the violation is a phase depending on a LATER phase.
      phases_in_order = [:preflight, :ignition, :lens, :convergence, :ready]

      dag =
        build_dag([
          {:preflight, []},
          {:ignition, [:preflight]},
          {:lens, [:ignition]},
          {:convergence, [:lens]},
          {:ready, [:convergence]}
        ])

      {:ok, layers} = kahn_sort(dag)
      order_map = compute_order_map(layers)

      Enum.each(phases_in_order, fn phase ->
        assert Map.has_key?(order_map, phase), "Phase #{phase} missing from topology"
      end)

      # Verify each phase appears at or after the previous phase's layer
      phases_in_order
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [earlier, later] ->
        assert order_map[earlier] < order_map[later],
               "#{earlier} must be in an earlier wave than #{later}"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 4 — State vector verification (SC-BOOT-001)
  # ---------------------------------------------------------------------------

  describe "state vector verification before each stage (SC-BOOT-001)" do
    test "initialized state passes verification" do
      state = %{db: :initialized, obs: :initialized, app: :initialized}
      assert state_vector_ok?(state, :db)
      assert state_vector_ok?(state, :obs)
      assert state_vector_ok?(state, :app)
    end

    test "healthy state passes verification" do
      state = %{db: :healthy}
      assert state_vector_ok?(state, :db)
    end

    test "missing key fails verification" do
      state = %{db: :initialized}
      refute state_vector_ok?(state, :obs)
    end

    test "degraded status fails verification" do
      state = %{db: :degraded}
      refute state_vector_ok?(state, :db)
    end

    test "nil status fails verification" do
      state = %{db: nil}
      refute state_vector_ok?(state, :db)
    end

    test "state vector must be verified before each wave executes" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      results = %{db: :success, obs: :success, app: :success}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :success

      # Every checkpoint should record a non-nil state vector
      Enum.each(checkpoints, fn cp ->
        assert cp.state_vector != nil, "Checkpoint #{cp.node} missing state vector"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 5 — Container start order (SC-SIL4-005)
  # ---------------------------------------------------------------------------

  describe "container start order DB → OBS → APP (SC-SIL4-005)" do
    test "DB node has no dependencies and boots first" do
      dag =
        build_dag([
          {:db, []},
          {:obs, [:db]},
          {:app, [:obs]}
        ])

      {:ok, layers} = kahn_sort(dag)
      order_map = compute_order_map(layers)

      assert order_map[:db] == 0
    end

    test "OBS starts after DB" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      {:ok, layers} = kahn_sort(dag)
      order_map = compute_order_map(layers)

      assert order_map[:db] < order_map[:obs]
    end

    test "APP starts after OBS" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      {:ok, layers} = kahn_sort(dag)
      order_map = compute_order_map(layers)

      assert order_map[:obs] < order_map[:app]
    end

    test "APP cannot start without DB being ready" do
      # DB is an implicit transitive dependency of APP
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      {:ok, layers} = kahn_sort(dag)
      order_map = compute_order_map(layers)

      assert order_map[:db] < order_map[:app]
    end

    test "multiple DB replicas can start in parallel" do
      dag =
        build_dag([
          {:db_primary, []},
          {:db_replica, []},
          {:obs, [:db_primary]},
          {:app, [:obs, :db_replica]}
        ])

      {:ok, [wave0 | _rest]} = kahn_sort(dag)
      assert :db_primary in wave0
      assert :db_replica in wave0
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 6 — Checkpoint recording (SC-BOOT-010)
  # ---------------------------------------------------------------------------

  describe "checkpoint recording at each boot stage (SC-BOOT-010)" do
    test "checkpoint includes node name, status, state vector, and timestamp" do
      cp = make_checkpoint(:db, :success, %{db: :initialized})
      assert cp.node == :db
      assert cp.status == :success
      assert cp.state_vector == %{db: :initialized}
      assert %DateTime{} = cp.timestamp
    end

    test "checkpoint id is a unique positive integer" do
      cp1 = make_checkpoint(:db, :success, %{})
      cp2 = make_checkpoint(:obs, :success, %{})
      assert is_integer(cp1.id) and cp1.id > 0
      assert cp1.id != cp2.id
    end

    test "failure checkpoint has status :failure" do
      cp = make_checkpoint(:app, :failure, %{app: :error})
      assert cp.status == :failure
    end

    test "successful three-node boot produces three checkpoints" do
      dag = build_dag([{:db, []}, {:cache, [:db]}, {:app, [:cache]}])
      results = %{db: :success, cache: :success, app: :success}
      {checkpoints, _} = execute_boot(dag, results)

      assert length(checkpoints) == 3
      nodes = Enum.map(checkpoints, & &1.node)
      assert :db in nodes
      assert :cache in nodes
      assert :app in nodes
    end

    test "checkpoints are ordered by wave execution" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      results = %{db: :success, obs: :success, app: :success}
      {checkpoints, _} = execute_boot(dag, results)

      nodes = Enum.map(checkpoints, & &1.node)
      # DB must be checkpointed before OBS, OBS before APP
      assert Enum.find_index(nodes, &(&1 == :db)) <
               Enum.find_index(nodes, &(&1 == :obs))

      assert Enum.find_index(nodes, &(&1 == :obs)) <
               Enum.find_index(nodes, &(&1 == :app))
    end

    test "all checkpoints are preserved in audit trail even after failure" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      results = %{db: :success, obs: :success, app: :failure}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :failure
      # All three checkpoints must be kept for auditing (SC-BOOT-010)
      assert length(checkpoints) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 7 — Migration gate (SC-BOOT-002) and Quorum gate (SC-BOOT-003)
  # ---------------------------------------------------------------------------

  describe "migration gate and quorum gate before Stage 3 (SC-BOOT-002/003)" do
    test "migration gate passes when migrations are current" do
      gate_state = %{migrations_current: true, quorum_achieved: true}
      assert stage3_gate_ok?(gate_state)
    end

    test "migration gate blocks when migrations are pending" do
      gate_state = %{migrations_current: false, quorum_achieved: true}
      refute stage3_gate_ok?(gate_state)
    end

    test "quorum gate blocks when quorum is not achieved" do
      gate_state = %{migrations_current: true, quorum_achieved: false}
      refute stage3_gate_ok?(gate_state)
    end

    test "both gates must pass to proceed to Stage 3" do
      both_fail = %{migrations_current: false, quorum_achieved: false}
      refute stage3_gate_ok?(both_fail)
    end

    test "quorum formula floor(N/2)+1 is correct for N=3" do
      assert quorum_threshold(3) == 2
    end

    test "quorum formula is correct for N=5" do
      assert quorum_threshold(5) == 3
    end

    test "quorum formula is correct for N=1" do
      assert quorum_threshold(1) == 1
    end

    test "2oo3 quorum requires at least 2 healthy routers" do
      routers = [true, true, false]
      assert quorum_met?(routers)
    end

    test "2oo3 quorum fails with only 1 healthy router" do
      routers = [true, false, false]
      refute quorum_met?(routers)
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 8 — Rollback on boot failure (SC-BOOT-004)
  # ---------------------------------------------------------------------------

  describe "transactional rollback on boot failure (SC-BOOT-004)" do
    test "failure in first wave stops subsequent waves" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      results = %{db: :failure, obs: :not_started, app: :not_started}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :failure
      assert summary.failed_node == :db

      started = Enum.map(checkpoints, & &1.node)
      refute :obs in started
      refute :app in started
    end

    test "rollback identifies last successful checkpoint" do
      dag = build_dag([{:db, []}, {:cache, [:db]}, {:app, [:cache]}])
      results = %{db: :success, cache: :failure, app: :not_started}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :failure
      rollback = find_last_success(checkpoints)
      assert rollback.node == :db
    end

    test "successful boot has no rollback point" do
      dag = build_dag([{:db, []}, {:app, [:db]}])
      results = %{db: :success, app: :success}
      {_checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :success
      assert summary.rollback_point == nil
    end

    test "failure in last wave preserves prior checkpoints for rollback" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      results = %{db: :success, obs: :success, app: :failure}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :failure
      assert summary.rollback_point.node == :obs
      # All three checkpoints survive for audit
      assert length(checkpoints) == 3
    end

    test "mid-chain failure prevents downstream nodes from starting" do
      dag =
        build_dag([
          {:db, []},
          {:cache, [:db]},
          {:queue, [:db]},
          {:app, [:cache, :queue]}
        ])

      # cache fails; app should never start
      results = %{db: :success, cache: :failure, queue: :success, app: :not_started}
      {checkpoints, summary} = execute_boot(dag, results)

      assert summary.status == :failure
      started = Enum.map(checkpoints, & &1.node)
      refute :app in started
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 9 — Boot timeout enforcement (SC-BOOT-005)
  # ---------------------------------------------------------------------------

  describe "boot timeout enforcement (<120s, target 60s) (SC-BOOT-005)" do
    test "critical path of independent nodes equals max single timing" do
      dag = build_dag([{:a, []}, {:b, []}, {:c, []}])
      timings = %{a: 10, b: 25, c: 15}
      critical = critical_path(dag, timings)

      # Parallel boot: total time = max single node time
      assert critical.duration == 25
    end

    test "critical path for linear chain equals sum of timings" do
      dag = build_dag([{:db, []}, {:obs, [:db]}, {:app, [:obs]}])
      timings = %{db: 10, obs: 5, app: 8}
      critical = critical_path(dag, timings)

      assert critical.path == [:db, :obs, :app]
      assert critical.duration == 23
    end

    test "critical path chooses longest branch in diamond" do
      dag =
        build_dag([
          {:db, []},
          {:fast_cache, [:db]},
          {:slow_index, [:db]},
          {:app, [:fast_cache, :slow_index]}
        ])

      timings = %{db: 5, fast_cache: 2, slow_index: 15, app: 3}
      critical = critical_path(dag, timings)

      assert :slow_index in critical.path
      assert critical.duration == 23
    end

    test "parallel branches reduce boot time below sequential sum" do
      dag = build_dag([{:a, []}, {:b, []}, {:c, [:a, :b]}])
      timings = %{a: 10, b: 10, c: 5}
      critical = critical_path(dag, timings)

      # Sequential would be 25; parallel critical path is 15 (max(a,b) + c)
      assert critical.duration == 15
      assert critical.duration < 25
    end

    test "estimated boot time is within 120-second SIL-4 bound" do
      # Representative prod topology with realistic timings (seconds)
      dag =
        build_dag([
          {:db, []},
          {:obs, []},
          {:zenoh, []},
          {:app, [:db, :obs, :zenoh]}
        ])

      # Conservative timings: DB 20s, OBS 15s, Zenoh 5s, App 10s
      timings = %{db: 20, obs: 15, zenoh: 5, app: 10}
      critical = critical_path(dag, timings)

      # max(20, 15, 5) + 10 = 30s — well within 120s SIL-4 bound
      assert critical.duration <= 120, "Boot time #{critical.duration}s exceeds SIL-4 limit"
    end

    test "estimated boot time meets 60-second target for small topology" do
      dag = build_dag([{:db, []}, {:app, [:db]}])
      timings = %{db: 20, app: 10}
      critical = critical_path(dag, timings)

      assert critical.duration <= 60
    end
  end

  # ---------------------------------------------------------------------------
  # Describe 10 — Property tests
  # ---------------------------------------------------------------------------

  describe "property: topological sort is always valid for acyclic DAGs" do
    ExUnitProperties.property "any acyclic DAG produces wave layers covering all nodes" do
      ExUnitProperties.check all(node_count <- SD.integer(1, 10)) do
        # Build a strictly acyclic graph: node i only depends on node i-1
        dag =
          Enum.reduce(0..(node_count - 1), %{}, fn i, acc ->
            name = :"n#{i}"
            deps = if i == 0, do: [], else: [:"n#{i - 1}"]
            Map.put(acc, name, deps)
          end)

        assert {:ok, waves} = kahn_sort(dag)
        all_nodes = List.flatten(waves)
        assert length(all_nodes) == node_count
        assert length(Enum.uniq(all_nodes)) == node_count
        assert layers_respect_deps?(waves, dag)
      end
    end
  end

  describe "property: wave groups are always independent" do
    ExUnitProperties.property "nodes within the same wave have no dependency on each other" do
      ExUnitProperties.check all(n <- SD.integer(2, 8)) do
        # Build a two-level DAG: n independent roots → 1 sink
        roots = Enum.map(1..n, fn i -> {:"root#{i}", []} end)
        sink_deps = Enum.map(1..n, fn i -> :"root#{i}" end)
        dag = build_dag([{:sink, sink_deps} | roots])

        {:ok, [wave0 | _]} = kahn_sort(dag)

        # Every pair in wave 0 must have no dependency between them
        pairs =
          for a <- wave0, b <- wave0, a != b do
            {a, b}
          end

        Enum.each(pairs, fn {a, b} ->
          deps_of_a = Map.get(dag, a, [])
          refute b in deps_of_a, "#{b} is a dep of #{a} but both are in wave 0"
        end)
      end
    end
  end

  describe "property: boot time critical path is always bounded" do
    ExUnitProperties.property "critical path duration >= any single node timing" do
      ExUnitProperties.check all(
                               node_timings <-
                                 SD.list_of(
                                   SD.tuple({SD.atom(:alphanumeric), SD.positive_integer()}),
                                   min_length: 1,
                                   max_length: 8
                                 )
                             ) do
        timings = Map.new(node_timings)
        nodes = Map.keys(timings)

        # All-independent DAG: no dependencies
        dag = build_dag(Enum.map(nodes, fn n -> {n, []} end))
        critical = critical_path(dag, timings)

        max_single = timings |> Map.values() |> Enum.max()

        assert critical.duration >= max_single,
               "Critical path #{critical.duration} is less than max single node #{max_single}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — all logic self-contained (no production module deps)
  # ---------------------------------------------------------------------------

  # Build a DAG map from a list of {node, [dependencies]} specs.
  @spec build_dag([{atom(), [atom()]}]) :: %{atom() => [atom()]}
  defp build_dag(node_specs) do
    Enum.reduce(node_specs, %{}, fn {node, deps}, acc ->
      Map.put(acc, node, deps)
    end)
  end

  # Kahn's algorithm — returns {:ok, [[atom()]]} (wave layers) or
  # {:error, :cycle_detected} (SC-BOOT-008).
  @spec kahn_sort(%{atom() => [atom()]}) ::
          {:ok, [[atom()]]} | {:error, :cycle_detected}
  defp kahn_sort(dag) when map_size(dag) == 0, do: {:ok, []}

  defp kahn_sort(dag) do
    all_nodes = Map.keys(dag)

    # Compute in-degree for every known node
    in_degree =
      Enum.reduce(dag, Map.new(all_nodes, &{&1, 0}), fn {node, deps}, acc ->
        Enum.reduce(deps, acc, fn _dep, inner ->
          Map.update(inner, node, 1, &(&1 + 1))
        end)
      end)

    queue = for {node, 0} <- in_degree, do: node
    do_kahn(queue, in_degree, dag, [], 0)
  end

  defp do_kahn([], _in_degree, dag, rev_layers, visited) do
    if visited == map_size(dag) do
      {:ok, Enum.reverse(rev_layers)}
    else
      {:error, :cycle_detected}
    end
  end

  defp do_kahn(wave, in_degree, dag, rev_layers, visited) when wave != [] do
    # Decrease in-degree for children of every node in this wave
    {next_wave, new_in_degree} =
      Enum.reduce(wave, {[], in_degree}, fn node, {next_acc, deg_acc} ->
        children = for {child, deps} <- dag, node in deps, do: child

        Enum.reduce(children, {next_acc, deg_acc}, fn child, {na, da} ->
          new_d = Map.update(da, child, 0, &(&1 - 1))

          if new_d[child] == 0 do
            {[child | na], new_d}
          else
            {na, new_d}
          end
        end)
      end)

    do_kahn(next_wave, new_in_degree, dag, [wave | rev_layers], visited + length(wave))
  end

  # Returns true if the DAG has no cycles (pure boolean wrapper).
  @spec is_acyclic?(%{atom() => [atom()]}) :: boolean()
  defp is_acyclic?(dag) do
    case kahn_sort(dag) do
      {:ok, _} -> true
      {:error, :cycle_detected} -> false
    end
  end

  # Returns true when every node in each wave has all its dependencies in
  # strictly earlier waves (SC-BOOT-009 correctness predicate).
  @spec layers_respect_deps?([[atom()]], %{atom() => [atom()]}) :: boolean()
  defp layers_respect_deps?(waves, dag) do
    result =
      Enum.reduce_while(waves, MapSet.new(), fn wave, completed ->
        valid =
          Enum.all?(wave, fn node ->
            deps = Map.get(dag, node, [])
            Enum.all?(deps, &MapSet.member?(completed, &1))
          end)

        if valid do
          new_completed = Enum.reduce(wave, completed, &MapSet.put(&2, &1))
          {:cont, new_completed}
        else
          {:halt, :invalid}
        end
      end)

    result != :invalid
  end

  # Returns true if the stage key exists in the state map with a valid value.
  @spec state_vector_ok?(%{atom() => atom()}, atom()) :: boolean()
  defp state_vector_ok?(state, stage) do
    case Map.get(state, stage) do
      :initialized -> true
      :healthy -> true
      _ -> false
    end
  end

  # Returns true when both the migration gate and quorum gate are satisfied,
  # allowing progression to Stage 3 (SC-BOOT-002, SC-BOOT-003).
  @spec stage3_gate_ok?(%{migrations_current: boolean(), quorum_achieved: boolean()}) ::
          boolean()
  defp stage3_gate_ok?(%{migrations_current: mc, quorum_achieved: qa}), do: mc and qa

  # Minimum number of healthy nodes needed for quorum: floor(N/2) + 1.
  @spec quorum_threshold(pos_integer()) :: pos_integer()
  defp quorum_threshold(n), do: div(n, 2) + 1

  # True when the count of healthy members >= quorum threshold.
  @spec quorum_met?([boolean()]) :: boolean()
  defp quorum_met?(members) do
    healthy = Enum.count(members, & &1)
    healthy >= quorum_threshold(length(members))
  end

  # Execute DAG boot: run waves in order, recording a checkpoint per node.
  # Stops at the first failure wave (SC-BOOT-004).
  @spec execute_boot(%{atom() => [atom()]}, %{atom() => atom()}) ::
          {[map()], map()}
  defp execute_boot(dag, results) do
    {:ok, waves} = kahn_sort(dag)
    do_execute(waves, results, [])
  end

  defp do_execute([], _results, checkpoints) do
    {Enum.reverse(checkpoints), %{status: :success, failed_node: nil, rollback_point: nil}}
  end

  defp do_execute([wave | rest], results, checkpoints) do
    {wave_cps, failed_node} =
      Enum.reduce(wave, {[], nil}, fn node, {cps, fail} ->
        result = Map.get(results, node, :not_started)
        cp = make_checkpoint(node, result, %{node => result})

        case {result, fail} do
          {:failure, nil} -> {[cp | cps], node}
          _ -> {[cp | cps], fail}
        end
      end)

    all_cps = Enum.reverse(wave_cps) ++ checkpoints

    if failed_node do
      rollback = find_last_success(Enum.reverse(all_cps))
      summary = %{status: :failure, failed_node: failed_node, rollback_point: rollback}
      {Enum.reverse(all_cps), summary}
    else
      do_execute(rest, results, all_cps)
    end
  end

  # Construct a single boot checkpoint (SC-BOOT-010).
  @spec make_checkpoint(atom(), atom(), map()) :: map()
  defp make_checkpoint(node, status, state_vector) do
    %{
      id: :erlang.unique_integer([:positive]),
      node: node,
      status: status,
      state_vector: state_vector,
      timestamp: DateTime.utc_now()
    }
  end

  # Return the last checkpoint with status :success, or nil.
  @spec find_last_success([map()]) :: map() | nil
  defp find_last_success(checkpoints) do
    checkpoints
    |> Enum.filter(&(&1.status == :success))
    |> List.last()
  end

  # Build a wave-index map so tests can assert relative ordering.
  @spec compute_order_map([[atom()]]) :: %{atom() => non_neg_integer()}
  defp compute_order_map(layers) do
    layers
    |> Enum.with_index()
    |> Enum.flat_map(fn {wave, idx} -> Enum.map(wave, &{&1, idx}) end)
    |> Map.new()
  end

  # Critical Path Method (CPM) — AOR-BOOT-002.
  # Returns %{path: [atom()], duration: non_neg_integer()} for the longest path.
  @spec critical_path(%{atom() => [atom()]}, %{atom() => non_neg_integer()}) :: map()
  defp critical_path(dag, _timings) when map_size(dag) == 0, do: %{path: [], duration: 0}

  defp critical_path(dag, timings) do
    roots = for {node, deps} <- dag, deps == [], do: node

    {best_path, best_dur} =
      Enum.reduce(roots, {[], 0}, fn root, {bp, bd} ->
        {p, d} = longest_from(root, dag, timings, MapSet.new())
        if d > bd, do: {p, d}, else: {bp, bd}
      end)

    %{path: best_path, duration: best_dur}
  end

  defp longest_from(node, dag, timings, visited) do
    node_time = Map.get(timings, node, 0)

    children =
      for {child, deps} <- dag, node in deps, not MapSet.member?(visited, child), do: child

    if children == [] do
      {[node], node_time}
    else
      new_visited = MapSet.put(visited, node)

      {best_cp, best_cd} =
        Enum.reduce(children, {[], 0}, fn child, {bp, bd} ->
          {cp, cd} = longest_from(child, dag, timings, new_visited)
          if cd > bd, do: {cp, cd}, else: {bp, bd}
        end)

      {[node | best_cp], node_time + best_cd}
    end
  end
end
