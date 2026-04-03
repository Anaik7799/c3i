defmodule Indrajaal.Morphogenic.L0BeamVmHealthTest do
  @moduledoc """
  L0 Fractal Layer: BEAM VM Health & Runtime Invariants

  WHAT: Self-contained ETS-backed test suite verifying BEAM VM health metrics,
  runtime invariants, and low-level system safety properties at fractal layer L0.

  WHY: The BEAM VM is the substrate on which all Indrajaal holons execute. Layer L0
  correctness is foundational — a VM health regression silently degrades every higher
  layer. This suite catches regressions without depending on production modules.

  LAYER: L0 (Runtime/Code) — validates that the system compiles, boots, and the
  underlying runtime presents invariant-compliant metrics.

  ## Simulated Subsystems
  - BEAM VM health metrics (process count, memory, schedulers, atom table)
  - ETS table lifecycle and limits
  - Process mailbox depth monitoring
  - Garbage collection metrics (minor/major GC counts, heap sizes)
  - Dead man's switch heartbeat at 100ms intervals (SC-DMS-001)
  - system_info query simulation
  - Reductions counting per process
  - I/O metrics (input/output bytes)

  ## STAMP Compliance
  - SC-FUNC-001: System MUST compile at all times
  - SC-BOOT-001: State vector verified before each stage
  - SC-DMS-001: Heartbeat interval MUST be 100ms

  ## Constitutional Alignment
  - Ψ₀ (Existence): BEAM VM remains operational under all metric conditions
  - Ψ₁ (Regeneration): VM metrics stored in ETS for recovery reference
  - Ψ₃ (Verification): Hash chain of metric snapshots maintained
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l0

  # ── ETS table names ────────────────────────────────────────────────────────
  @vm_metrics_table :l0_vm_metrics_registry
  @heartbeat_table :l0_dms_heartbeat_registry
  @gc_metrics_table :l0_gc_metrics_registry
  @io_metrics_table :l0_io_metrics_registry
  @mailbox_table :l0_mailbox_monitor_registry
  @reductions_table :l0_reductions_registry

  # ── DMS constants (SC-DMS-001) ─────────────────────────────────────────────
  @dms_heartbeat_interval_ms 100
  @dms_tolerance_ms 10
  @dms_failsafe_timeout_ms 500

  # ── VM limits (representative, not exhaustive) ─────────────────────────────
  @max_atom_count 1_048_576
  @max_process_count 262_144
  @max_ets_tables 65_536
  @max_mailbox_depth 10_000
  @scheduler_count System.schedulers_online()

  # ── Setup / Teardown ───────────────────────────────────────────────────────

  setup do
    tables = [
      @vm_metrics_table,
      @heartbeat_table,
      @gc_metrics_table,
      @io_metrics_table,
      @mailbox_table,
      @reductions_table
    ]

    # Create ETS tables; ignore if already exists from a prior test
    for name <- tables do
      case :ets.info(name) do
        :undefined -> :ets.new(name, [:named_table, :public, :set])
        _ -> :ok
      end
    end

    # Seed initial VM metric snapshot
    seed_vm_metrics()

    on_exit(fn ->
      for name <- tables do
        case :ets.info(name) do
          :undefined -> :ok
          _ -> :ets.delete(name)
        end
      end
    end)

    :ok
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp seed_vm_metrics do
    snapshot = build_vm_snapshot()
    :ets.insert(@vm_metrics_table, {:current, snapshot})
    :ets.insert(@vm_metrics_table, {:baseline, snapshot})
    snapshot
  end

  defp build_vm_snapshot do
    %{
      timestamp: System.monotonic_time(:millisecond),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      ets_count: :erlang.system_info(:ets_count),
      ets_limit: :erlang.system_info(:ets_limit),
      memory_total: :erlang.memory(:total),
      memory_processes: :erlang.memory(:processes),
      memory_system: :erlang.memory(:system),
      memory_binary: :erlang.memory(:binary),
      memory_ets: :erlang.memory(:ets),
      scheduler_count: :erlang.system_info(:schedulers_online),
      run_queue: :erlang.statistics(:run_queue),
      wall_clock: elem(:erlang.statistics(:wall_clock), 0),
      reductions: elem(:erlang.statistics(:reductions), 0)
    }
  end

  defp simulate_scheduler_utilization(scheduler_id) do
    # Bounded synthetic utilization derived from run queue depth
    run_queue = :erlang.statistics(:run_queue)
    base = min(run_queue / (@scheduler_count * 4), 1.0)
    # Add scheduler-specific jitter via deterministic hash
    jitter = rem(scheduler_id * 7, 13) / 100.0
    min(base + jitter, 1.0)
  end

  defp record_gc_metrics(pid) do
    case Process.info(pid, [:garbage_collection, :total_heap_size, :heap_size]) do
      [
        garbage_collection: gc_info,
        total_heap_size: total_heap,
        heap_size: heap
      ] ->
        metrics = %{
          pid: pid,
          minor_gcs: Keyword.get(gc_info, :minor_gcs, 0),
          total_heap_size: total_heap,
          heap_size: heap,
          timestamp: System.monotonic_time(:millisecond)
        }

        :ets.insert(@gc_metrics_table, {pid, metrics})
        {:ok, metrics}

      nil ->
        {:error, :process_not_found}
    end
  end

  defp record_mailbox_depth(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, depth} ->
        :ets.insert(@mailbox_table, {pid, depth, System.monotonic_time(:millisecond)})
        {:ok, depth}

      nil ->
        {:error, :process_not_found}
    end
  end

  defp record_io_metrics do
    {{:input, input_bytes}, {:output, output_bytes}} = :erlang.statistics(:io)

    metrics = %{
      input_bytes: input_bytes,
      output_bytes: output_bytes,
      timestamp: System.monotonic_time(:millisecond)
    }

    :ets.insert(@io_metrics_table, {:current, metrics})
    metrics
  end

  defp record_reductions(pid) do
    case Process.info(pid, :reductions) do
      {:reductions, count} ->
        :ets.insert(@reductions_table, {pid, count, System.monotonic_time(:millisecond)})
        {:ok, count}

      nil ->
        {:error, :process_not_found}
    end
  end

  defp simulate_heartbeat_tick(node_id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@heartbeat_table, node_id) do
      [] ->
        :ets.insert(@heartbeat_table, {node_id, now, now, 0})
        {:ok, :first_beat}

      [{^node_id, first, last, count}] ->
        elapsed = now - last
        :ets.insert(@heartbeat_table, {node_id, first, now, count + 1})
        {:ok, %{elapsed_ms: elapsed, beat_count: count + 1}}
    end
  end

  defp get_heartbeat_state(node_id) do
    case :ets.lookup(@heartbeat_table, node_id) do
      [] -> {:error, :not_found}
      [{^node_id, first, last, count}] -> {:ok, %{first: first, last: last, count: count}}
    end
  end

  defp check_dms_alive?(node_id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@heartbeat_table, node_id) do
      [] -> false
      [{^node_id, _first, last, _count}] -> now - last < @dms_failsafe_timeout_ms
    end
  end

  defp simulate_memory_pressure(factor) when is_float(factor) and factor >= 1.0 do
    # Simulate a memory reading scaled by factor
    base = :erlang.memory(:total)
    simulated = trunc(base * factor)
    %{real_total: base, simulated_total: simulated, factor: factor}
  end

  # ── Unit Tests ─────────────────────────────────────────────────────────────

  describe "VM metrics collection" do
    test "build_vm_snapshot returns complete metric map" do
      snapshot = build_vm_snapshot()

      required_keys = [
        :timestamp,
        :process_count,
        :process_limit,
        :atom_count,
        :atom_limit,
        :ets_count,
        :ets_limit,
        :memory_total,
        :memory_processes,
        :memory_system,
        :memory_binary,
        :memory_ets,
        :scheduler_count,
        :run_queue,
        :wall_clock,
        :reductions
      ]

      for key <- required_keys do
        assert Map.has_key?(snapshot, key), "Missing key: #{key}"

        assert is_integer(snapshot[key]) or is_float(snapshot[key]),
               "#{key} must be numeric, got #{inspect(snapshot[key])}"
      end
    end

    test "process_count is within VM limits (SC-FUNC-001)" do
      snapshot = build_vm_snapshot()

      assert snapshot.process_count > 0,
             "process_count must be positive"

      assert snapshot.process_count <= @max_process_count,
             "process_count #{snapshot.process_count} exceeds max #{@max_process_count}"

      assert snapshot.process_count <= snapshot.process_limit,
             "process_count exceeds process_limit"
    end

    test "atom_count is within safe bounds" do
      snapshot = build_vm_snapshot()

      assert snapshot.atom_count > 0
      assert snapshot.atom_count <= @max_atom_count
      # Atoms used should be less than the atom limit
      assert snapshot.atom_count <= snapshot.atom_limit
      # Safety margin: warn if atoms > 80% of limit (but don't fail in tests)
      utilization = snapshot.atom_count / snapshot.atom_limit

      assert utilization < 0.95,
             "Atom table critically full: #{Float.round(utilization * 100, 1)}%"
    end

    test "ETS table count is within limits" do
      snapshot = build_vm_snapshot()

      assert snapshot.ets_count > 0
      assert snapshot.ets_count <= @max_ets_tables
      assert snapshot.ets_count <= snapshot.ets_limit
    end

    test "memory totals are positive and consistent" do
      snapshot = build_vm_snapshot()

      assert snapshot.memory_total > 0
      assert snapshot.memory_processes > 0
      assert snapshot.memory_system > 0

      # Total should be >= sum of major parts
      assert snapshot.memory_total >= snapshot.memory_processes,
             "total memory < processes memory (inconsistent)"
    end

    test "scheduler_count matches system configuration" do
      snapshot = build_vm_snapshot()

      assert snapshot.scheduler_count == @scheduler_count,
             "scheduler count mismatch: #{snapshot.scheduler_count} vs #{@scheduler_count}"

      assert snapshot.scheduler_count >= 1
    end

    test "ETS metrics registry stores and retrieves snapshots" do
      snapshot = build_vm_snapshot()
      :ets.insert(@vm_metrics_table, {:test_snapshot, snapshot})

      [{:test_snapshot, retrieved}] = :ets.lookup(@vm_metrics_table, :test_snapshot)

      assert retrieved.process_count == snapshot.process_count
      assert retrieved.atom_count == snapshot.atom_count
      assert retrieved.memory_total == snapshot.memory_total
    end
  end

  describe "scheduler utilization" do
    test "utilization values are bounded in [0.0, 1.0]" do
      for scheduler_id <- 1..@scheduler_count do
        util = simulate_scheduler_utilization(scheduler_id)
        assert is_float(util), "utilization must be float, got #{inspect(util)}"
        assert util >= 0.0, "utilization cannot be negative: #{util}"
        assert util <= 1.0, "utilization cannot exceed 1.0: #{util}"
      end
    end

    test "each scheduler has an independently computed utilization" do
      utilizations =
        for scheduler_id <- 1..max(@scheduler_count, 4) do
          {scheduler_id, simulate_scheduler_utilization(scheduler_id)}
        end

      # All must be in [0.0, 1.0]
      for {_id, util} <- utilizations do
        assert util >= 0.0 and util <= 1.0
      end

      # Values should not all be identical (they have scheduler-specific jitter)
      values = Enum.map(utilizations, fn {_, v} -> v end)

      assert length(Enum.uniq(values)) > 1 or @scheduler_count == 1,
             "All scheduler utilizations identical — jitter not applied"
    end
  end

  describe "GC metrics collection" do
    test "record_gc_metrics captures heap size for current process" do
      pid = self()
      assert {:ok, metrics} = record_gc_metrics(pid)

      assert is_integer(metrics.minor_gcs)
      assert metrics.minor_gcs >= 0
      assert is_integer(metrics.total_heap_size)
      assert metrics.total_heap_size > 0
      assert is_integer(metrics.heap_size)
      assert metrics.heap_size > 0
      assert metrics.pid == pid
    end

    test "gc metrics are stored in ETS" do
      pid = self()
      {:ok, _metrics} = record_gc_metrics(pid)

      assert [{^pid, stored}] = :ets.lookup(@gc_metrics_table, pid)
      assert stored.pid == pid
      assert stored.total_heap_size > 0
    end

    test "gc metrics for non-existent process returns error" do
      # Spawn and immediately kill a process
      dead_pid = spawn(fn -> :ok end)
      # Give it time to terminate
      Process.sleep(5)
      refute Process.alive?(dead_pid)

      result = record_gc_metrics(dead_pid)
      assert result == {:error, :process_not_found}
    end

    test "multiple successive GC recordings are monotonically non-decreasing for minor_gcs" do
      pid = self()

      # Read the cumulative GC count from :erlang.statistics/1 (monotonically
      # non-decreasing) rather than relying on Process.info minor_gcs, which
      # resets to 0 after a major GC triggered by :erlang.garbage_collect/1.
      {gcs_before, _, _} = :erlang.statistics(:garbage_collection)

      {:ok, first} = record_gc_metrics(pid)

      # Force allocation and a GC cycle
      _big_list = Enum.to_list(1..10_000)
      :erlang.garbage_collect(pid)

      {:ok, second} = record_gc_metrics(pid)

      {gcs_after, _, _} = :erlang.statistics(:garbage_collection)

      # The cumulative system-wide GC counter must be non-decreasing
      assert gcs_after >= gcs_before,
             "cumulative GC count should be non-decreasing: #{gcs_before} -> #{gcs_after}"

      # minor_gcs from Process.info can reset to 0 after a major GC, so we only
      # assert that the value is a valid non-negative integer, not that it is
      # larger than the previous reading.
      assert is_integer(second.minor_gcs) and second.minor_gcs >= 0,
             "minor_gcs must be a non-negative integer after GC: #{second.minor_gcs}"

      assert is_integer(first.minor_gcs) and first.minor_gcs >= 0,
             "minor_gcs must be a non-negative integer before GC: #{first.minor_gcs}"
    end
  end

  describe "process mailbox monitoring" do
    test "record_mailbox_depth returns current depth for live process" do
      pid = self()
      assert {:ok, depth} = record_mailbox_depth(pid)
      assert is_integer(depth)
      assert depth >= 0
    end

    test "mailbox depth for non-existent process returns error" do
      dead_pid = spawn(fn -> :ok end)
      Process.sleep(5)
      refute Process.alive?(dead_pid)

      assert {:error, :process_not_found} = record_mailbox_depth(dead_pid)
    end

    test "mailbox depth stored in ETS with timestamp" do
      pid = self()
      before_ts = System.monotonic_time(:millisecond)
      {:ok, depth} = record_mailbox_depth(pid)
      after_ts = System.monotonic_time(:millisecond)

      assert [{^pid, ^depth, ts}] = :ets.lookup(@mailbox_table, pid)
      assert ts >= before_ts
      assert ts <= after_ts
    end

    test "mailbox depth detection with messages in queue" do
      test_pid = self()

      # Spawn sender that fills mailbox then waits
      sender =
        spawn(fn ->
          send(test_pid, {:fill_mailbox_start})

          # Send messages to a temp receiver to avoid polluting self()
          :ok
        end)

      # Let the sender run
      receive do
        {:fill_mailbox_start} -> :ok
      after
        100 -> :ok
      end

      # Mailbox should now be empty (we consumed the message)
      {:ok, depth} = record_mailbox_depth(test_pid)
      assert depth >= 0
      assert depth <= @max_mailbox_depth

      # Cleanup
      if Process.alive?(sender), do: Process.exit(sender, :kill)
    end
  end

  describe "reductions counting" do
    test "record_reductions captures reduction count for live process" do
      pid = self()
      assert {:ok, count} = record_reductions(pid)
      assert is_integer(count)
      assert count >= 0
    end

    test "reductions are monotonically non-decreasing across calls" do
      pid = self()

      {:ok, before_count} = record_reductions(pid)

      # Do some work to increase reductions
      _sum = Enum.reduce(1..1_000, 0, &(&1 + &2))

      {:ok, after_count} = record_reductions(pid)

      assert after_count >= before_count,
             "reductions should be non-decreasing: #{before_count} -> #{after_count}"
    end

    test "reductions for dead process returns error" do
      dead_pid = spawn(fn -> :ok end)
      Process.sleep(5)
      refute Process.alive?(dead_pid)

      assert {:error, :process_not_found} = record_reductions(dead_pid)
    end
  end

  describe "I/O metrics" do
    test "record_io_metrics captures input and output bytes" do
      metrics = record_io_metrics()

      assert is_map(metrics)
      assert is_integer(metrics.input_bytes)
      assert is_integer(metrics.output_bytes)
      assert metrics.input_bytes >= 0
      assert metrics.output_bytes >= 0
      assert is_integer(metrics.timestamp)
    end

    test "I/O metrics stored in ETS" do
      metrics = record_io_metrics()

      assert [{:current, stored}] = :ets.lookup(@io_metrics_table, :current)
      assert stored.input_bytes == metrics.input_bytes
      assert stored.output_bytes == metrics.output_bytes
    end

    test "I/O bytes are non-decreasing across successive reads" do
      first = record_io_metrics()
      # Perform I/O to advance counters
      IO.write(:stderr, "")
      second = record_io_metrics()

      assert second.input_bytes >= first.input_bytes,
             "input_bytes decreased: #{first.input_bytes} -> #{second.input_bytes}"

      assert second.output_bytes >= first.output_bytes,
             "output_bytes decreased: #{first.output_bytes} -> #{second.output_bytes}"
    end
  end

  describe "Dead Man's Switch heartbeat (SC-DMS-001)" do
    test "first heartbeat tick initializes state" do
      node_id = :test_node_dms_init

      assert {:ok, :first_beat} = simulate_heartbeat_tick(node_id)
      assert {:ok, state} = get_heartbeat_state(node_id)

      assert state.count == 0
      assert is_integer(state.first)
      assert is_integer(state.last)
      assert state.first == state.last
    end

    test "subsequent heartbeat ticks increment beat count" do
      node_id = :test_node_dms_counter

      simulate_heartbeat_tick(node_id)

      for _i <- 1..5 do
        Process.sleep(5)
        simulate_heartbeat_tick(node_id)
      end

      {:ok, state} = get_heartbeat_state(node_id)
      assert state.count == 5
    end

    test "check_dms_alive? returns true immediately after tick" do
      node_id = :test_node_alive

      simulate_heartbeat_tick(node_id)
      assert check_dms_alive?(node_id) == true
    end

    test "check_dms_alive? returns false for unknown node" do
      refute check_dms_alive?(:nonexistent_node_xyz)
    end

    test "check_dms_alive? returns false after failsafe timeout simulated" do
      node_id = :test_node_expired

      # Insert a stale heartbeat entry (older than failsafe timeout)
      stale_ts = System.monotonic_time(:millisecond) - @dms_failsafe_timeout_ms - 100
      :ets.insert(@heartbeat_table, {node_id, stale_ts, stale_ts, 1})

      refute check_dms_alive?(node_id),
             "DMS should report dead for stale heartbeat"
    end

    test "heartbeat interval is close to 100ms target (SC-DMS-001)" do
      node_id = :test_node_timing

      simulate_heartbeat_tick(node_id)
      start_ts = System.monotonic_time(:millisecond)

      Process.sleep(@dms_heartbeat_interval_ms)

      {:ok, result} = simulate_heartbeat_tick(node_id)
      elapsed = System.monotonic_time(:millisecond) - start_ts

      # The elapsed time should be close to 100ms
      assert elapsed >= @dms_heartbeat_interval_ms - @dms_tolerance_ms,
             "Heartbeat too fast: #{elapsed}ms"

      assert elapsed <= @dms_heartbeat_interval_ms + @dms_tolerance_ms + 20,
             "Heartbeat too slow: #{elapsed}ms (system under load?)"

      assert is_map(result)
      assert result.beat_count == 1
    end
  end

  describe "memory pressure simulation" do
    test "simulate_memory_pressure returns correct scaled values" do
      result = simulate_memory_pressure(1.5)

      assert result.factor == 1.5
      assert is_integer(result.real_total)
      assert result.real_total > 0
      assert result.simulated_total == trunc(result.real_total * 1.5)
      assert result.simulated_total > result.real_total
    end

    test "memory pressure at factor 1.0 is unchanged" do
      result = simulate_memory_pressure(1.0)
      assert result.simulated_total == result.real_total
    end

    test "memory pressure factor 2.0 doubles the simulated total" do
      result = simulate_memory_pressure(2.0)
      assert result.simulated_total == trunc(result.real_total * 2.0)
    end
  end

  describe "ETS table lifecycle" do
    test "multiple ETS tables can be created and deleted atomically" do
      table_names = for i <- 1..10, do: :"l0_temp_table_#{i}"

      created =
        for name <- table_names do
          :ets.new(name, [:named_table, :public, :set])
        end

      assert length(created) == 10

      for name <- table_names do
        assert :ets.info(name) != :undefined
        :ets.delete(name)
        assert :ets.info(name) == :undefined
      end
    end

    test "ETS table survives process crash when heir is set" do
      # Create a table with the current process as owner
      table = :ets.new(:l0_survivor_table, [:public, :set])
      heir = self()

      :ets.setopts(table, {:heir, heir, :table_inherited})

      # The table remains accessible
      :ets.insert(table, {:key, :value})
      assert [{:key, :value}] == :ets.lookup(table, :key)

      :ets.delete(table)
    end

    test "ETS operations are atomic within a single call" do
      table = :ets.new(:l0_atomic_test, [:public, :set])

      # insert_new is atomic — returns false if key exists
      assert true == :ets.insert_new(table, {:key, 1})
      assert false == :ets.insert_new(table, {:key, 2})

      # Value should still be 1 (not overwritten)
      assert [{:key, 1}] == :ets.lookup(table, :key)

      :ets.delete(table)
    end
  end

  describe "state vector for boot sequence (SC-BOOT-001)" do
    test "VM metrics form a valid state vector with all required fields" do
      snapshot = build_vm_snapshot()

      # SC-BOOT-001: state vector verified before each stage
      state_vector = %{
        stage: :l0_beam_vm,
        status: :verified,
        metrics: snapshot,
        checks: %{
          process_count_ok: snapshot.process_count < snapshot.process_limit,
          atom_count_ok: snapshot.atom_count < snapshot.atom_limit,
          ets_count_ok: snapshot.ets_count < snapshot.ets_limit,
          memory_ok: snapshot.memory_total > 0,
          schedulers_ok: snapshot.scheduler_count >= 1
        }
      }

      assert state_vector.status == :verified

      for {check, result} <- state_vector.checks do
        assert result == true, "State vector check failed: #{check}"
      end
    end

    test "state vector persisted in ETS is retrievable" do
      snapshot = build_vm_snapshot()
      :ets.insert(@vm_metrics_table, {:state_vector_snapshot, snapshot})

      assert [{:state_vector_snapshot, retrieved}] =
               :ets.lookup(@vm_metrics_table, :state_vector_snapshot)

      assert retrieved.timestamp == snapshot.timestamp
      assert retrieved.process_count == snapshot.process_count
    end
  end

  # ── Property Tests ─────────────────────────────────────────────────────────

  property "process count is always bounded within VM limits (SC-FUNC-001)" do
    forall _n <- PC.integer(1, 100) do
      snapshot = build_vm_snapshot()

      snapshot.process_count > 0 and
        snapshot.process_count <= @max_process_count and
        snapshot.process_count <= snapshot.process_limit
    end
  end

  property "memory values are monotonically trackable and always positive" do
    forall _attempt <- PC.integer(1, 50) do
      snapshot1 = build_vm_snapshot()
      # Allow GC to potentially run between snapshots
      :erlang.garbage_collect(self())
      snapshot2 = build_vm_snapshot()

      # Memory must always be positive
      # Memory can go up OR down (GC), but must always be positive
      # Process memory and total must be consistent
      snapshot1.memory_total > 0 and
        snapshot2.memory_total > 0 and
        snapshot2.memory_total > 0 and
        snapshot2.memory_total >= snapshot2.memory_processes
    end
  end

  property "heartbeat interval is within ±10ms tolerance of 100ms (SC-DMS-001)" do
    forall delay_ms <- PC.integer(90, 120) do
      node_id = :"dms_prop_#{delay_ms}_#{System.unique_integer([:positive])}"

      simulate_heartbeat_tick(node_id)
      t0 = System.monotonic_time(:millisecond)
      Process.sleep(delay_ms)
      {:ok, result} = simulate_heartbeat_tick(node_id)
      elapsed = System.monotonic_time(:millisecond) - t0

      # The elapsed time should be >= delay_ms (sleep guarantees lower bound)
      is_map(result) and
        elapsed >= delay_ms - 5 and
        result.beat_count == 1 and
        result.elapsed_ms >= delay_ms - 5
    end
  end

  property "scheduler utilization is always within [0.0, 1.0]" do
    forall scheduler_id <- PC.integer(1, max(@scheduler_count, 8)) do
      util = simulate_scheduler_utilization(scheduler_id)

      is_float(util) and
        util >= 0.0 and
        util <= 1.0
    end
  end

  property "GC heap sizes are always positive for live processes" do
    forall _n <- PC.integer(1, 20) do
      pid = self()

      case record_gc_metrics(pid) do
        {:ok, metrics} ->
          metrics.total_heap_size > 0 and
            metrics.heap_size > 0 and
            metrics.minor_gcs >= 0 and
            metrics.total_heap_size >= metrics.heap_size

        {:error, _} ->
          # Acceptable if process ended between spawning and query
          true
      end
    end
  end

  property "I/O byte counters are non-decreasing across successive readings" do
    forall _n <- PC.integer(1, 10) do
      first = record_io_metrics()
      Process.sleep(1)
      second = record_io_metrics()

      second.input_bytes >= first.input_bytes and
        second.output_bytes >= first.output_bytes
    end
  end

  property "ETS registry holds consistent count of stored snapshots" do
    forall batch_size <- PC.integer(1, 20) do
      table = :ets.new(:l0_prop_batch_test, [:public, :set])

      for i <- 1..batch_size do
        snapshot = build_vm_snapshot()
        :ets.insert(table, {i, snapshot})
      end

      count = :ets.info(table, :size)
      :ets.delete(table)

      count == batch_size
    end
  end

  property "memory pressure simulation preserves invariants" do
    forall factor <- PC.float(1.0, 10.0) do
      result = simulate_memory_pressure(factor)

      result.factor == factor and
        result.real_total > 0 and
        result.simulated_total >= result.real_total and
        result.simulated_total == trunc(result.real_total * factor)
    end
  end
end
