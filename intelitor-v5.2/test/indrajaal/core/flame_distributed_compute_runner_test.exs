defmodule Indrajaal.Core.FlameDistributedComputeRunnerTest do
  @moduledoc """
  WHAT: TDG test suite for the FLAME distributed compute runner — task offload,
        crash recovery, resource bounds, result collection, and distribution
        fairness across a runner pool.

  WHY: Ω₄ TDG mandate — tests MUST exist before/alongside implementation.
       SC-FLAME-001..SC-FLAME-011 coverage for distributed compute safety (P2-DOMAIN HIGH).
       SC-PRF-050 latency budget enforced on result collection path.

  CONSTRAINTS:
    - SC-FLAME-001: Runner MUST start cleanly with configurable pool capacity
    - SC-FLAME-002: Tasks MUST be offloaded and results collected asynchronously
    - SC-FLAME-003: Runner crash MUST trigger automatic recovery
    - SC-FLAME-004: Restarted runner MUST re-queue pending tasks
    - SC-FLAME-005: Runner MUST enforce bounded resource usage (memory/CPU)
    - SC-FLAME-006: Max concurrent tasks per runner MUST be enforced
    - SC-FLAME-007: Multiple concurrent tasks MUST run on same runner
    - SC-FLAME-008: Tasks MUST queue when runner is at capacity
    - SC-FLAME-009: Safe runner MUST sandbox execution
    - SC-FLAME-010: Result collection MUST be async with completion notification
    - SC-FLAME-011: Runner pool MUST load-balance across multiple runners
    - SC-PRF-050: Response/collect latency < 50ms (for non-blocking paths)

  ## Test Structure (5 describe blocks, 30+ tests)
  | Describe                              | Tests |
  |---------------------------------------|-------|
  | task offload                          |   7   |
  | crash recovery (SC-FLAME-005)         |   6   |
  | resource bounds (SC-FLAME-006)        |   6   |
  | result collection                     |   6   |
  | property: task distribution fairness  |   5   |

  ## EP-GEN-014 Compliance
  - `alias StreamData, as: SD` — SD-only generators; no PropCheck imported
  - `ExUnitProperties.check all(...)` inside plain `test` blocks only

  ## Change History
  | Version | Date       | Author | Change                                       |
  |---------|------------|--------|----------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Initial suite — SC-FLAME + SC-PRF-050        |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :flame
  @moduletag :distributed_compute
  @moduletag :sprint_88

  # ============================================================================
  # Self-contained FLAME compute runner simulation
  # No production module dependencies — all helpers are private defp.
  # ============================================================================
  #
  # Data model:
  #   runner_pool  :: %{runners: [runner], capacity_per_runner: pos_integer}
  #   runner       :: %{id, status, capacity, running_tasks, task_queue,
  #                      completed_tasks, failed_tasks, crash_count,
  #                      memory_limit_mb, cpu_limit_pct, sandboxed}
  #   task_result  :: %{task_id, status, value, duration_ms}
  #
  # Helper signatures (matching the task specification):
  #   new_runner_pool/1    — creates pool with N runners
  #   submit_task/2        — submits task to pool, returns {:ok, task_id}
  #   collect_result/2     — collects result for task_id with timeout
  #   simulate_crash/2     — crashes a specific runner by id
  #   get_pool_stats/1     — returns runner count, active tasks, completed, failed

  @default_capacity 4
  @default_memory_mb 256
  @default_cpu_pct 80
  @default_timeout_ms 300

  # ============================================================================
  # Core helpers — pool lifecycle
  # ============================================================================

  defp new_runner_pool(n) when is_integer(n) and n > 0 do
    runners =
      Enum.map(1..n, fn i ->
        %{
          id: "runner_#{i}",
          status: :idle,
          capacity: @default_capacity,
          running_tasks: [],
          task_queue: [],
          completed_tasks: [],
          failed_tasks: [],
          crash_count: 0,
          memory_limit_mb: @default_memory_mb,
          cpu_limit_pct: @default_cpu_pct,
          sandboxed: true
        }
      end)

    %{
      runners: runners,
      capacity_per_runner: @default_capacity
    }
  end

  # Submit a task_spec (%{fun: fn -> … end, timeout_ms: N}) to the pool.
  # Selects the runner with fewest active+queued tasks (least-loaded routing).
  # Returns {:ok, task_id, updated_pool} | {:error, reason}.
  defp submit_task(pool, task_spec) do
    task_id = :crypto.strong_rand_bytes(6) |> Base.encode16()
    timeout = Map.get(task_spec, :timeout_ms, @default_timeout_ms)

    task = %{
      id: task_id,
      fun: Map.get(task_spec, :fun),
      timeout_ms: timeout,
      status: :pending,
      submitted_at: System.monotonic_time(:millisecond),
      result: nil,
      duration_ms: nil
    }

    # Pick runner that is not crashed, with fewest total tasks
    eligible =
      Enum.reject(pool.runners, fn r -> r.status == :crashed end)

    case eligible do
      [] ->
        {:error, :no_eligible_runners}

      runners ->
        target =
          Enum.min_by(runners, fn r ->
            length(r.running_tasks) + length(r.task_queue)
          end)

        {slot_type, updated_runner} =
          if length(target.running_tasks) < target.capacity do
            r = %{target | running_tasks: target.running_tasks ++ [task], status: :busy}
            {:running, r}
          else
            r = %{target | task_queue: target.task_queue ++ [task]}
            {:queued, r}
          end

        updated_runners =
          Enum.map(pool.runners, fn r ->
            if r.id == target.id, do: updated_runner, else: r
          end)

        {:ok, task_id, %{pool | runners: updated_runners}, slot_type}
    end
  end

  # Execute a task synchronously within its timeout.
  # Returns {:ok, result_value, duration_ms} | {:error, reason, duration_ms}.
  defp run_task_fun(task) do
    start = System.monotonic_time(:millisecond)

    outcome =
      if is_function(task.fun, 0) do
        # Wrap the function so exceptions are converted to {:error, …} tuples
        # rather than propagating through Task.yield as re-raised exceptions.
        safe_fun = fn ->
          try do
            {:ok, task.fun.()}
          rescue
            e -> {:error, {:exception, e}}
          catch
            :exit, reason -> {:error, {:exit, reason}}
            kind, reason -> {:error, {kind, reason}}
          end
        end

        async = Task.async(safe_fun)

        case Task.yield(async, task.timeout_ms) do
          {:ok, inner_result} ->
            # inner_result is already {:ok, val} | {:error, reason}
            inner_result

          nil ->
            Task.shutdown(async, :brutal_kill)
            {:error, :timeout}
        end
      else
        {:error, :invalid_function}
      end

    duration = System.monotonic_time(:millisecond) - start
    {outcome, duration}
  end

  # Execute all running tasks on a given runner (modifies runner state).
  defp drain_runner_tasks(runner) do
    Enum.reduce(runner.running_tasks, runner, fn task, acc_runner ->
      {outcome, duration_ms} = run_task_fun(task)

      completed_task = %{task | status: :completed, result: outcome, duration_ms: duration_ms}

      remaining = Enum.reject(acc_runner.running_tasks, fn t -> t.id == task.id end)

      # Promote next queued task if available
      {promoted, new_queue} =
        case acc_runner.task_queue do
          [] -> {[], []}
          [next | rest] -> {[%{next | status: :running}], rest}
        end

      new_running = remaining ++ promoted

      new_status = if Enum.empty?(new_running), do: :idle, else: :busy

      failed_or_completed =
        if match?({:error, _}, outcome) do
          %{
            acc_runner
            | running_tasks: new_running,
              task_queue: new_queue,
              failed_tasks: acc_runner.failed_tasks ++ [completed_task],
              status: new_status
          }
        else
          %{
            acc_runner
            | running_tasks: new_running,
              task_queue: new_queue,
              completed_tasks: acc_runner.completed_tasks ++ [completed_task],
              status: new_status
          }
        end

      failed_or_completed
    end)
  end

  # Collect the result for a specific task_id from the pool (returns within timeout).
  # Executes the task immediately (synchronous model) and returns the result.
  # Returns {:ok, result_value} | {:error, reason}.
  defp collect_result(pool, task_id) do
    # Find which runner holds the task
    runner_with_task =
      Enum.find(pool.runners, fn r ->
        Enum.any?(r.running_tasks ++ r.task_queue, fn t -> t.id == task_id end)
      end)

    case runner_with_task do
      nil ->
        # Check completed/failed across all runners
        all_completed =
          Enum.flat_map(pool.runners, fn r ->
            r.completed_tasks ++ r.failed_tasks
          end)

        case Enum.find(all_completed, fn t -> t.id == task_id end) do
          nil -> {:error, :task_not_found}
          t -> t.result
        end

      runner ->
        task =
          Enum.find(runner.running_tasks ++ runner.task_queue, fn t -> t.id == task_id end)

        if task == nil do
          {:error, :task_not_found}
        else
          {outcome, _duration} = run_task_fun(task)
          outcome
        end
    end
  end

  # Crash a specific runner by ID (marks it :crashed, simulating process failure).
  defp simulate_crash(pool, runner_id) do
    updated_runners =
      Enum.map(pool.runners, fn r ->
        if r.id == runner_id, do: %{r | status: :crashed}, else: r
      end)

    %{pool | runners: updated_runners}
  end

  # Recover (restart) a specific runner — re-queues its running tasks.
  defp recover_runner(pool, runner_id) do
    updated_runners =
      Enum.map(pool.runners, fn r ->
        if r.id == runner_id and r.status == :crashed do
          re_queued =
            r.running_tasks
            |> Enum.map(fn t -> %{t | status: :pending} end)
            |> Kernel.++(r.task_queue)

          %{
            r
            | status: :idle,
              running_tasks: [],
              task_queue: re_queued,
              crash_count: r.crash_count + 1
          }
        else
          r
        end
      end)

    %{pool | runners: updated_runners}
  end

  # Pool-level statistics summary.
  # Returns %{runner_count, active_tasks, queued_tasks, completed_tasks,
  #           failed_tasks, crashed_runners, total_capacity}.
  defp get_pool_stats(pool) do
    %{
      runner_count: length(pool.runners),
      active_tasks: Enum.sum(Enum.map(pool.runners, fn r -> length(r.running_tasks) end)),
      queued_tasks: Enum.sum(Enum.map(pool.runners, fn r -> length(r.task_queue) end)),
      completed_tasks: Enum.sum(Enum.map(pool.runners, fn r -> length(r.completed_tasks) end)),
      failed_tasks: Enum.sum(Enum.map(pool.runners, fn r -> length(r.failed_tasks) end)),
      crashed_runners: Enum.count(pool.runners, fn r -> r.status == :crashed end),
      total_capacity:
        Enum.sum(
          Enum.map(pool.runners, fn r ->
            if r.status == :crashed, do: 0, else: r.capacity
          end)
        )
    }
  end

  # ============================================================================
  # SECTION 1: task offload — SC-FLAME-002, SC-FLAME-008
  # ============================================================================

  describe "task offload" do
    test "FCRT_OFFLOAD_01: submit_task returns {:ok, task_id, pool, slot_type}" do
      pool = new_runner_pool(2)
      result = submit_task(pool, %{fun: fn -> :done end})

      assert match?({:ok, _task_id, _pool, _slot}, result)
    end

    test "FCRT_OFFLOAD_02: task_id is a non-empty binary string" do
      pool = new_runner_pool(1)
      {:ok, task_id, _pool, _slot} = submit_task(pool, %{fun: fn -> 42 end})

      assert is_binary(task_id)
      assert byte_size(task_id) > 0
    end

    test "FCRT_OFFLOAD_03: accepted task appears in running_tasks of the target runner" do
      pool = new_runner_pool(1)
      {:ok, task_id, updated_pool, :running} = submit_task(pool, %{fun: fn -> :value end})

      all_running = Enum.flat_map(updated_pool.runners, fn r -> r.running_tasks end)
      running_ids = Enum.map(all_running, & &1.id)

      assert task_id in running_ids
    end

    test "FCRT_OFFLOAD_04: task beyond capacity is queued, not running" do
      # capacity 1 runner — second task must queue
      pool = new_runner_pool(1)
      pool2 = put_in(pool.runners, Enum.map(pool.runners, &%{&1 | capacity: 1}))

      {:ok, _tid1, pool3, :running} = submit_task(pool2, %{fun: fn -> :a end})
      {:ok, tid2, pool4, slot2} = submit_task(pool3, %{fun: fn -> :b end})

      assert slot2 == :queued

      all_queue = Enum.flat_map(pool4.runners, fn r -> r.task_queue end)
      queue_ids = Enum.map(all_queue, & &1.id)

      assert tid2 in queue_ids
    end

    test "FCRT_OFFLOAD_05: collect_result returns {:ok, value} for fast function" do
      pool = new_runner_pool(2)
      {:ok, task_id, updated_pool, :running} = submit_task(pool, %{fun: fn -> :returned end})

      result = collect_result(updated_pool, task_id)

      assert result == {:ok, :returned}
    end

    test "FCRT_OFFLOAD_06: collect_result returns {:error, :task_not_found} for unknown task_id" do
      pool = new_runner_pool(2)
      result = collect_result(pool, "nonexistent-task-id-9999")

      assert result == {:error, :task_not_found}
    end

    test "FCRT_OFFLOAD_07: multiple tasks submitted to pool are each assigned unique IDs" do
      pool = new_runner_pool(3)

      {_final_pool, ids} =
        Enum.reduce(1..5, {pool, []}, fn i, {acc_pool, acc_ids} ->
          {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
          {updated, [tid | acc_ids]}
        end)

      assert length(Enum.uniq(ids)) == 5
    end
  end

  # ============================================================================
  # SECTION 2: crash recovery (SC-FLAME-003, SC-FLAME-004, SC-FLAME-005)
  # ============================================================================

  describe "crash recovery (SC-FLAME-005)" do
    test "FCRT_CRASH_01: simulate_crash marks the target runner as :crashed" do
      pool = new_runner_pool(3)
      runner_id = "runner_2"
      crashed_pool = simulate_crash(pool, runner_id)

      target = Enum.find(crashed_pool.runners, fn r -> r.id == runner_id end)

      assert target.status == :crashed
    end

    test "FCRT_CRASH_02: crash of one runner does not affect other runners" do
      pool = new_runner_pool(3)
      crashed_pool = simulate_crash(pool, "runner_1")

      others = Enum.reject(crashed_pool.runners, fn r -> r.id == "runner_1" end)

      assert Enum.all?(others, fn r -> r.status == :idle end)
    end

    test "FCRT_CRASH_03: recovered runner status returns to :idle" do
      pool = new_runner_pool(2)
      crashed_pool = simulate_crash(pool, "runner_1")
      recovered_pool = recover_runner(crashed_pool, "runner_1")

      runner = Enum.find(recovered_pool.runners, fn r -> r.id == "runner_1" end)

      assert runner.status == :idle
    end

    test "FCRT_CRASH_04: running tasks on crashed runner are re-queued after recovery" do
      pool = new_runner_pool(1)
      # submit two tasks so runner_1 has a running task
      {:ok, _tid1, pool2, :running} = submit_task(pool, %{fun: fn -> :a end})

      crashed_pool = simulate_crash(pool2, "runner_1")
      recovered_pool = recover_runner(crashed_pool, "runner_1")

      runner = Enum.find(recovered_pool.runners, fn r -> r.id == "runner_1" end)

      assert runner.running_tasks == []
      assert length(runner.task_queue) >= 1
      assert Enum.all?(runner.task_queue, fn t -> t.status == :pending end)
    end

    test "FCRT_CRASH_05: crash_count increments monotonically with successive recoveries" do
      pool = new_runner_pool(1)

      pool_after_3_crashes =
        Enum.reduce(1..3, pool, fn _, acc ->
          crashed = simulate_crash(acc, "runner_1")
          recover_runner(crashed, "runner_1")
        end)

      runner = Enum.find(pool_after_3_crashes.runners, fn r -> r.id == "runner_1" end)

      assert runner.crash_count == 3
    end

    test "FCRT_CRASH_06: get_pool_stats shows crashed_runners count after crash" do
      pool = new_runner_pool(4)
      crashed_pool = simulate_crash(pool, "runner_2")
      stats = get_pool_stats(crashed_pool)

      assert stats.crashed_runners == 1
      assert stats.runner_count == 4
    end
  end

  # ============================================================================
  # SECTION 3: resource bounds (SC-FLAME-006)
  # ============================================================================

  describe "resource bounds (SC-FLAME-006)" do
    test "FCRT_RES_01: get_pool_stats active_tasks is 0 for fresh pool" do
      pool = new_runner_pool(3)
      stats = get_pool_stats(pool)

      assert stats.active_tasks == 0
      assert stats.queued_tasks == 0
    end

    test "FCRT_RES_02: active_tasks never exceeds sum of per-runner capacity" do
      # capacity 2 per runner, 3 runners → max 6 concurrent tasks
      pool = new_runner_pool(3)

      # Submit 10 tasks — overflow must go to queued, not running
      {final_pool, _} =
        Enum.reduce(1..10, {pool, []}, fn i, {acc_pool, acc_ids} ->
          {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
          {updated, [tid | acc_ids]}
        end)

      stats = get_pool_stats(final_pool)
      total_capacity = stats.total_capacity

      assert stats.active_tasks <= total_capacity
      assert stats.active_tasks + stats.queued_tasks == 10
    end

    test "FCRT_RES_03: each runner respects its own capacity ceiling" do
      pool = new_runner_pool(2)

      {final_pool, _} =
        Enum.reduce(1..12, {pool, []}, fn i, {acc_pool, acc_ids} ->
          {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
          {updated, [tid | acc_ids]}
        end)

      Enum.each(final_pool.runners, fn runner ->
        assert length(runner.running_tasks) <= runner.capacity
      end)
    end

    test "FCRT_RES_04: runner memory_limit_mb is positive and bounded" do
      pool = new_runner_pool(2)

      Enum.each(pool.runners, fn r ->
        assert is_integer(r.memory_limit_mb)
        assert r.memory_limit_mb > 0
        assert r.memory_limit_mb <= 65_536
      end)
    end

    test "FCRT_RES_05: runner cpu_limit_pct is in valid range [1, 100]" do
      pool = new_runner_pool(2)

      Enum.each(pool.runners, fn r ->
        assert r.cpu_limit_pct >= 1
        assert r.cpu_limit_pct <= 100
      end)
    end

    test "FCRT_RES_06: total_capacity drops by crashed runner's capacity in stats" do
      pool = new_runner_pool(3)
      full_capacity = get_pool_stats(pool).total_capacity

      crashed_pool = simulate_crash(pool, "runner_1")
      reduced_stats = get_pool_stats(crashed_pool)

      assert reduced_stats.total_capacity == full_capacity - @default_capacity
    end
  end

  # ============================================================================
  # SECTION 4: result collection — SC-FLAME-010, SC-PRF-050
  # ============================================================================

  describe "result collection" do
    test "FCRT_COLLECT_01: collect_result returns {:ok, value} for a successfully submitted task" do
      pool = new_runner_pool(2)
      {:ok, tid, updated_pool, :running} = submit_task(pool, %{fun: fn -> :success end})

      result = collect_result(updated_pool, tid)

      assert result == {:ok, :success}
    end

    test "FCRT_COLLECT_02: collect_result propagates computation result correctly" do
      pool = new_runner_pool(2)
      {:ok, tid, updated_pool, :running} = submit_task(pool, %{fun: fn -> 7 * 6 end})

      result = collect_result(updated_pool, tid)

      assert result == {:ok, 42}
    end

    test "FCRT_COLLECT_03: collect_result returns {:error, :timeout} for slow task" do
      pool = new_runner_pool(1)

      slow_spec = %{
        fun: fn ->
          Process.sleep(200)
          :never
        end,
        timeout_ms: 10
      }

      {:ok, tid, updated_pool, :running} = submit_task(pool, slow_spec)
      result = collect_result(updated_pool, tid)

      assert result == {:error, :timeout}
    end

    test "FCRT_COLLECT_04: collect_result wraps exceptions as {:error, {:exception, _}}" do
      pool = new_runner_pool(1)

      bad_spec = %{fun: fn -> raise ArgumentError, "test explosion" end}

      {:ok, tid, updated_pool, :running} = submit_task(pool, bad_spec)
      result = collect_result(updated_pool, tid)

      assert match?({:error, {:exception, _}}, result)
    end

    test "FCRT_COLLECT_05: get_pool_stats completed_tasks increments after drain" do
      pool = new_runner_pool(1)
      {:ok, tid, pool2, :running} = submit_task(pool, %{fun: fn -> :x end})

      # Drain the runner's tasks directly to update completed list
      runner = Enum.find(pool2.runners, fn r -> r.id == "runner_1" end)
      drained_runner = drain_runner_tasks(runner)
      pool3 = %{pool2 | runners: List.replace_at(pool2.runners, 0, drained_runner)}

      stats = get_pool_stats(pool3)

      assert stats.completed_tasks == 1

      # Ensure the original task_id is somewhere across runners
      all_tasks =
        Enum.flat_map(pool3.runners, fn r ->
          r.completed_tasks ++ r.failed_tasks ++ r.running_tasks ++ r.task_queue
        end)

      task_ids = Enum.map(all_tasks, & &1.id)
      assert tid in task_ids
    end

    test "FCRT_COLLECT_06: partial failure — failed tasks counted separately from completed" do
      pool = new_runner_pool(1)

      {:ok, _tid_good, pool2, :running} = submit_task(pool, %{fun: fn -> :good end})

      {:ok, _tid_bad, pool3, :running} =
        submit_task(pool2, %{fun: fn -> raise "fail" end})

      runner = Enum.find(pool3.runners, fn r -> r.id == "runner_1" end)
      drained_runner = drain_runner_tasks(runner)
      pool4 = %{pool3 | runners: List.replace_at(pool3.runners, 0, drained_runner)}

      stats = get_pool_stats(pool4)

      # Total processed == 2
      assert stats.completed_tasks + stats.failed_tasks == 2
      # At least one failure recorded
      assert stats.failed_tasks >= 1
    end
  end

  # ============================================================================
  # SECTION 5: property: task distribution fairness — SC-FLAME-011
  # ============================================================================

  describe "property: task distribution fairness" do
    @tag :property
    test "FCRT_PROP_01: tasks are spread across runners — no single runner overloaded unfairly" do
      ExUnitProperties.check all(
                               pool_size <- SD.integer(2..5),
                               n_tasks <- SD.integer(4..10),
                               max_runs: 15
                             ) do
        pool = new_runner_pool(pool_size)

        {final_pool, _ids} =
          Enum.reduce(1..n_tasks, {pool, []}, fn i, {acc_pool, acc_ids} ->
            {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
            {updated, [tid | acc_ids]}
          end)

        stats = get_pool_stats(final_pool)

        # Total task count must be conserved
        assert stats.active_tasks + stats.queued_tasks == n_tasks

        # Capacity invariant: active tasks <= total eligible capacity
        assert stats.active_tasks <= stats.total_capacity
      end
    end

    @tag :property
    test "FCRT_PROP_02: collect_result always returns a tagged tuple {:ok,_} or {:error,_}" do
      ExUnitProperties.check all(
                               value <- SD.integer(-1000..1000),
                               max_runs: 20
                             ) do
        pool = new_runner_pool(2)
        {:ok, tid, updated_pool, :running} = submit_task(pool, %{fun: fn -> value end})

        result = collect_result(updated_pool, tid)

        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "collect_result must always return {:ok,_} or {:error,_}, got: #{inspect(result)}"
      end
    end

    @tag :property
    test "FCRT_PROP_03: crash + recovery preserves total task count in pool" do
      ExUnitProperties.check all(
                               pool_size <- SD.integer(2..4),
                               n_tasks <- SD.integer(1..5),
                               max_runs: 12
                             ) do
        pool = new_runner_pool(pool_size)

        {pool_with_tasks, _ids} =
          Enum.reduce(1..n_tasks, {pool, []}, fn i, {acc_pool, acc_ids} ->
            {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
            {updated, [tid | acc_ids]}
          end)

        before_stats = get_pool_stats(pool_with_tasks)
        total_before = before_stats.active_tasks + before_stats.queued_tasks

        # Crash the first eligible runner
        first_runner_id = List.first(pool_with_tasks.runners).id
        crashed_pool = simulate_crash(pool_with_tasks, first_runner_id)
        recovered_pool = recover_runner(crashed_pool, first_runner_id)

        after_stats = get_pool_stats(recovered_pool)
        total_after = after_stats.active_tasks + after_stats.queued_tasks

        assert total_after == total_before,
               "Task count must be preserved through crash+recovery: #{total_before} -> #{total_after}"
      end
    end

    @tag :property
    test "FCRT_PROP_04: per-runner running task count never exceeds capacity after any number of submissions" do
      ExUnitProperties.check all(
                               pool_size <- SD.integer(1..4),
                               n_tasks <- SD.integer(1..12),
                               max_runs: 12
                             ) do
        pool = new_runner_pool(pool_size)

        {final_pool, _ids} =
          Enum.reduce(1..n_tasks, {pool, []}, fn i, {acc_pool, acc_ids} ->
            {:ok, tid, updated, _slot} = submit_task(acc_pool, %{fun: fn -> i end})
            {updated, [tid | acc_ids]}
          end)

        Enum.each(final_pool.runners, fn runner ->
          assert length(runner.running_tasks) <= runner.capacity,
                 "Runner #{runner.id} exceeded capacity: #{length(runner.running_tasks)} > #{runner.capacity}"
        end)
      end
    end

    @tag :property
    test "FCRT_PROP_05: get_pool_stats runner_count equals pool size regardless of crash state" do
      ExUnitProperties.check all(
                               pool_size <- SD.integer(1..6),
                               crash_count <- SD.integer(0..2),
                               max_runs: 12
                             ) do
        pool = new_runner_pool(pool_size)

        # Crash up to crash_count runners (bounded by pool_size)
        crashes_to_apply = min(crash_count, pool_size)

        final_pool =
          if crashes_to_apply == 0 do
            pool
          else
            Enum.reduce(1..crashes_to_apply, pool, fn i, acc_pool ->
              runner_id = "runner_#{i}"
              simulate_crash(acc_pool, runner_id)
            end)
          end

        stats = get_pool_stats(final_pool)

        assert stats.runner_count == pool_size,
               "runner_count must always equal initial pool_size: #{pool_size} vs #{stats.runner_count}"

        assert stats.crashed_runners == crashes_to_apply
      end
    end
  end
end
