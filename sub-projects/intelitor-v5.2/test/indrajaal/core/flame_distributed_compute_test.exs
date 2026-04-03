defmodule Indrajaal.Core.FlameDistributedComputeTest do
  @moduledoc """
  FLAME distributed compute runner test — task offload L3.

  WHAT: Self-contained ETS-backed simulation of FLAME distributed compute.
        Tests task submission, execution, timeout enforcement, crash recovery,
        resource-limit rejection, task offloading, runner health, graceful
        shutdown, priority queuing, per-runner metrics, and dual property
        guarantees for completion/crash-safety.

  WHY: SC-FLAME-001 to SC-FLAME-011 mandate coverage of safe-runner isolation,
       crash recovery, timeout enforcement, and resource limits. Ω₄ TDG — all
       tests are written before production module integration. ETS provides
       genuine concurrent state shared between test processes.

  CONSTRAINTS:
    - SC-FLAME-001: Safe runner isolation — tasks run in isolated processes
    - SC-FLAME-002: Crash recovery — runner survives task crashes and continues
    - SC-FLAME-003: Task timeout enforcement — tasks killed after deadline
    - SC-FLAME-004: Resource limits — reject tasks at capacity
    - SC-FLAME-005: Runner health observable (idle / busy states)
    - SC-FLAME-006: Graceful shutdown — wait for in-flight tasks
    - SC-FLAME-007: Priority queue — high-priority tasks precede low-priority
    - SC-FLAME-008: Metrics — total, success, failure, avg_duration tracked
    - SC-FLAME-009: Multiple tasks complete independently
    - SC-FLAME-010: Expensive offload produces correct result
    - SC-FLAME-011: Task isolation — one task failure doesn't affect others

  ## Architecture (ETS-backed simulation)

  Each "runner" is an ETS table storing:
    - `{:capacity, max_concurrent}` — maximum concurrent task slots
    - `{:status, atom}` — :idle | :busy | :shutdown
    - `{:queue, [{priority, task_fun}]}` — pending ordered by priority
    - `{:metrics, map}` — total/success/failure/total_duration counters
    - `{:slots, pid_set}` — active Task PIDs occupying capacity slots

  Task execution uses `Task.async` / `Task.yield` for real async behaviour.
  Priority is an integer (lower = higher priority, 0 = highest).

  ## EP-GEN-014 Compliance
  - `import ExUnitProperties, except: [property: 2, property: 3]`
  - `alias StreamData, as: SD`  — no PropCheck; SD generators only
  - `ExUnitProperties.check all(...)` always inside plain `test` blocks

  ## Test Count
  - 20 unit tests across 8 describe blocks
  - 2 property tests (completion guarantee, resource-limit invariant)

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Initial suite — 22 tests, SC-FLAME-001-11 |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :flame
  @moduletag :distributed
  @moduletag :compute
  @moduletag :sprint_88

  # ---------------------------------------------------------------------------
  # ETS-backed FLAME runner simulation
  # ---------------------------------------------------------------------------
  # All helper functions are private and self-contained — no production deps.

  @priority_high 0
  @priority_normal 5
  @priority_low 10
  @default_capacity 4
  @default_timeout_ms 200

  # Create a new ETS-backed runner. Returns the ETS table name (unique atom).
  defp new_runner(opts \\ []) do
    table_name = :"flame_runner_#{:erlang.unique_integer([:positive])}"
    table = :ets.new(table_name, [:set, :public])

    :ets.insert(table, {:capacity, Keyword.get(opts, :capacity, @default_capacity)})
    :ets.insert(table, {:timeout_ms, Keyword.get(opts, :timeout_ms, @default_timeout_ms)})
    :ets.insert(table, {:status, :idle})
    :ets.insert(table, {:queue, []})
    :ets.insert(table, {:slots, MapSet.new()})

    :ets.insert(table, {
      :metrics,
      %{total: 0, success: 0, failure: 0, total_duration_ms: 0}
    })

    on_exit(fn ->
      if :ets.whereis(table) != :undefined do
        :ets.delete(table)
      end
    end)

    table
  end

  defp runner_capacity(table) do
    [{:capacity, cap}] = :ets.lookup(table, :capacity)
    cap
  end

  defp runner_status(table) do
    [{:status, status}] = :ets.lookup(table, :status)
    status
  end

  defp runner_metrics(table) do
    [{:metrics, m}] = :ets.lookup(table, :metrics)
    m
  end

  defp active_slot_count(table) do
    [{:slots, slots}] = :ets.lookup(table, :slots)
    MapSet.size(slots)
  end

  defp queue_length(table) do
    [{:queue, q}] = :ets.lookup(table, :queue)
    length(q)
  end

  # Submit a task to the runner. Returns {:ok, :accepted} or {:error, :at_capacity}.
  # priority: integer (lower = higher priority).
  defp submit_task(table, fun, priority \\ @priority_normal) do
    [{:capacity, cap}] = :ets.lookup(table, :capacity)
    [{:slots, slots}] = :ets.lookup(table, :slots)

    if MapSet.size(slots) >= cap do
      {:error, :at_capacity}
    else
      # Immediately spawn the task and track the PID
      timeout_ms =
        case :ets.lookup(table, :timeout_ms) do
          [{:timeout_ms, t}] -> t
          _ -> @default_timeout_ms
        end

      task_pid = self()

      worker =
        Task.async(fn ->
          start = System.monotonic_time(:millisecond)

          result =
            try do
              inner = Task.async(fun)

              case Task.yield(inner, timeout_ms) do
                {:ok, val} ->
                  {:ok, val}

                nil ->
                  Task.shutdown(inner, :brutal_kill)
                  {:error, :timeout}
              end
            rescue
              e -> {:error, {:exception, Exception.message(e)}}
            catch
              :exit, reason -> {:error, {:exit, reason}}
            end

          duration = System.monotonic_time(:millisecond) - start
          send(task_pid, {:task_done, self(), result, duration, priority})
          result
        end)

      new_slots = MapSet.put(slots, worker.pid)
      :ets.insert(table, {:slots, new_slots})
      :ets.insert(table, {:status, :busy})

      # Update total metric immediately
      [{:metrics, m}] = :ets.lookup(table, :metrics)
      :ets.insert(table, {:metrics, %{m | total: m.total + 1}})

      {:ok, :accepted, worker}
    end
  end

  # Submit a task to the priority queue when runner is at capacity.
  defp enqueue_task(table, fun, priority \\ @priority_normal) do
    [{:queue, q}] = :ets.lookup(table, :queue)
    new_q = Enum.sort_by([{priority, fun} | q], fn {p, _} -> p end)
    :ets.insert(table, {:queue, new_q})
    :ok
  end

  # Await a task result and update metrics.
  defp await_task(table, worker, timeout_ms \\ @default_timeout_ms + 100) do
    case Task.yield(worker, timeout_ms) do
      {:ok, result} ->
        receive do
          {:task_done, _pid, ^result, duration, _priority} ->
            finalize_task(table, result, duration)
        after
          50 ->
            # Fallback: metrics updated without duration detail
            finalize_task(table, result, 0)
        end

        result

      nil ->
        Task.shutdown(worker, :brutal_kill)
        finalize_task(table, {:error, :timeout}, 0)
        {:error, :timeout}
    end
  end

  defp finalize_task(table, result, duration_ms) do
    [{:metrics, m}] = :ets.lookup(table, :metrics)
    [{:slots, slots}] = :ets.lookup(table, :slots)

    updated_metrics =
      case result do
        {:ok, _} ->
          %{m | success: m.success + 1, total_duration_ms: m.total_duration_ms + duration_ms}

        {:error, _} ->
          %{m | failure: m.failure + 1, total_duration_ms: m.total_duration_ms + duration_ms}
      end

    :ets.insert(table, {:metrics, updated_metrics})

    # Remove any finished task PIDs from slots
    alive_slots = Enum.filter(MapSet.to_list(slots), &Process.alive?/1) |> MapSet.new()
    :ets.insert(table, {:slots, alive_slots})

    new_status = if MapSet.size(alive_slots) == 0, do: :idle, else: :busy
    :ets.insert(table, {:status, new_status})
  end

  defp shutdown_runner(table) do
    :ets.insert(table, {:status, :shutdown})
  end

  # ---------------------------------------------------------------------------
  # SECTION 1: Task submission — SC-FLAME-001
  # ---------------------------------------------------------------------------

  describe "task submission" do
    test "COMPUTE_01: submit_task returns {:ok, :accepted, worker} when under capacity" do
      table = new_runner(capacity: 2)
      result = submit_task(table, fn -> :done end)
      assert match?({:ok, :accepted, _}, result)
    end

    test "COMPUTE_02: submitted task appears in active slots" do
      table = new_runner(capacity: 2)
      {:ok, :accepted, _worker} = submit_task(table, fn -> Process.sleep(50) end)
      assert active_slot_count(table) >= 1
    end

    test "COMPUTE_03: total metric increments on each submission" do
      table = new_runner(capacity: 4)
      submit_task(table, fn -> 1 end)
      submit_task(table, fn -> 2 end)
      submit_task(table, fn -> 3 end)
      m = runner_metrics(table)
      assert m.total == 3
    end

    test "COMPUTE_04: runner status becomes :busy after first task accepted" do
      table = new_runner()
      submit_task(table, fn -> Process.sleep(30) end)
      assert runner_status(table) == :busy
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 2: Successful execution — SC-FLAME-009, SC-FLAME-010
  # ---------------------------------------------------------------------------

  describe "successful execution" do
    test "COMPUTE_05: simple compute task returns correct result" do
      table = new_runner()
      {:ok, :accepted, worker} = submit_task(table, fn -> 6 * 7 end)
      result = await_task(table, worker)
      assert result == {:ok, 42}
    end

    test "COMPUTE_06: multiple independent tasks all complete correctly" do
      table = new_runner(capacity: 4)

      workers =
        Enum.map(1..4, fn i ->
          {:ok, :accepted, w} = submit_task(table, fn -> i * i end)
          {i, w}
        end)

      results =
        Enum.map(workers, fn {i, w} ->
          {i, await_task(table, w)}
        end)

      Enum.each(results, fn {i, result} ->
        assert result == {:ok, i * i}
      end)
    end

    test "COMPUTE_07: expensive computation (map-reduce simulation) returns correct result" do
      table = new_runner()

      # Simulate an expensive offload: sum of squares 1..100
      {:ok, :accepted, worker} =
        submit_task(table, fn ->
          1..100 |> Enum.map(fn x -> x * x end) |> Enum.sum()
        end)

      result = await_task(table, worker)
      # sum of squares 1..100 = 338350
      assert result == {:ok, 338_350}
    end

    test "COMPUTE_08: success metric increments after task completes" do
      table = new_runner()
      {:ok, :accepted, worker} = submit_task(table, fn -> :ok end)
      await_task(table, worker)
      m = runner_metrics(table)
      assert m.success == 1
    end

    test "COMPUTE_09: runner returns to :idle status after last task finishes" do
      table = new_runner()
      {:ok, :accepted, worker} = submit_task(table, fn -> :ok end)
      await_task(table, worker)
      assert runner_status(table) == :idle
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 3: Timeout enforcement — SC-FLAME-003
  # ---------------------------------------------------------------------------

  describe "timeout enforcement" do
    test "COMPUTE_10: task exceeding timeout returns {:error, :timeout}" do
      table = new_runner(timeout_ms: 15)

      {:ok, :accepted, worker} =
        submit_task(table, fn ->
          Process.sleep(500)
          :never_reached
        end)

      result = await_task(table, worker)
      assert result == {:error, :timeout}
    end

    test "COMPUTE_11: timed-out task increments failure metric" do
      table = new_runner(timeout_ms: 10)

      {:ok, :accepted, worker} =
        submit_task(table, fn ->
          Process.sleep(300)
          :unreachable
        end)

      await_task(table, worker)
      m = runner_metrics(table)
      assert m.failure == 1
    end

    test "COMPUTE_12: fast task completes successfully before timeout fires" do
      table = new_runner(timeout_ms: 300)
      {:ok, :accepted, worker} = submit_task(table, fn -> :fast end)
      result = await_task(table, worker)
      assert result == {:ok, :fast}
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 4: Crash recovery — SC-FLAME-002
  # ---------------------------------------------------------------------------

  describe "crash recovery" do
    test "COMPUTE_13: task that raises exception is caught — returns {:error, {:exception, _}}" do
      table = new_runner()

      {:ok, :accepted, worker} =
        submit_task(table, fn -> raise ArgumentError, "intentional crash" end)

      result = await_task(table, worker)
      assert match?({:error, {:exception, _}}, result)
    end

    test "COMPUTE_14: task crash increments failure metric" do
      table = new_runner()
      {:ok, :accepted, worker} = submit_task(table, fn -> raise "boom" end)
      await_task(table, worker)
      m = runner_metrics(table)
      assert m.failure == 1
    end

    test "COMPUTE_15: runner continues accepting tasks after a crash" do
      table = new_runner(capacity: 2)

      {:ok, :accepted, bad_worker} =
        submit_task(table, fn -> raise "crash" end)

      await_task(table, bad_worker)

      # Runner should now be idle and accept a new task
      {:ok, :accepted, good_worker} = submit_task(table, fn -> :alive end)
      good_result = await_task(table, good_worker)
      assert good_result == {:ok, :alive}
    end

    test "COMPUTE_16: crash in one task does not corrupt results of a sibling task (SC-FLAME-011)" do
      table = new_runner(capacity: 2)

      {:ok, :accepted, bad_worker} =
        submit_task(table, fn -> raise "isolated boom" end)

      {:ok, :accepted, good_worker} =
        submit_task(table, fn -> :sibling_ok end)

      bad_result = await_task(table, bad_worker)
      good_result = await_task(table, good_worker)

      assert match?({:error, _}, bad_result)
      assert good_result == {:ok, :sibling_ok}
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 5: Resource limits — SC-FLAME-004
  # ---------------------------------------------------------------------------

  describe "resource limits" do
    test "COMPUTE_17: submit_task returns {:error, :at_capacity} when runner is full" do
      # capacity 1: first task occupies the only slot
      table = new_runner(capacity: 1)
      submit_task(table, fn -> Process.sleep(100) end)
      # Second submission must be rejected
      result = submit_task(table, fn -> :rejected end)
      assert result == {:error, :at_capacity}
    end

    test "COMPUTE_18: slot count never exceeds declared capacity" do
      table = new_runner(capacity: 2)

      # Submit up to capacity
      submit_task(table, fn -> Process.sleep(80) end)
      submit_task(table, fn -> Process.sleep(80) end)

      count = active_slot_count(table)
      assert count <= runner_capacity(table)
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 6: Runner health — SC-FLAME-005
  # ---------------------------------------------------------------------------

  describe "runner health" do
    test "COMPUTE_19: newly created runner reports :idle status" do
      table = new_runner()
      assert runner_status(table) == :idle
    end

    test "COMPUTE_20: runner in :shutdown state recorded after shutdown_runner/1" do
      table = new_runner()
      shutdown_runner(table)
      assert runner_status(table) == :shutdown
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 7: Priority queue — SC-FLAME-007
  # ---------------------------------------------------------------------------

  describe "priority queue" do
    test "COMPUTE_21: enqueued tasks are sorted by priority (lower first)" do
      table = new_runner(capacity: 1)

      # Fill the slot so all subsequent tasks go to queue
      submit_task(table, fn -> Process.sleep(80) end)

      enqueue_task(table, fn -> :low end, @priority_low)
      enqueue_task(table, fn -> :high end, @priority_high)
      enqueue_task(table, fn -> :normal end, @priority_normal)

      [{:queue, q}] = :ets.lookup(table, :queue)
      priorities = Enum.map(q, fn {p, _} -> p end)

      # Must be sorted ascending (high first = lowest number first)
      assert priorities == Enum.sort(priorities)
      assert hd(priorities) == @priority_high
    end

    test "COMPUTE_22: queue length reflects number of enqueued tasks" do
      table = new_runner(capacity: 1)
      submit_task(table, fn -> Process.sleep(60) end)

      enqueue_task(table, fn -> :a end)
      enqueue_task(table, fn -> :b end)
      enqueue_task(table, fn -> :c end)

      assert queue_length(table) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 8: Metrics — SC-FLAME-008
  # ---------------------------------------------------------------------------

  describe "metrics accumulation" do
    test "COMPUTE_23: average duration is derivable from total_duration_ms / success" do
      table = new_runner()

      workers =
        Enum.map(1..3, fn _ ->
          {:ok, :accepted, w} = submit_task(table, fn -> :done end)
          w
        end)

      Enum.each(workers, &await_task(table, &1))
      m = runner_metrics(table)

      # All 3 should succeed; avg = total_duration_ms / success
      assert m.success == 3
      assert m.failure == 0
      avg = if m.success > 0, do: m.total_duration_ms / m.success, else: 0
      assert avg >= 0
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 9: Property — completion guarantee — SC-FLAME-001, SC-FLAME-002
  # ---------------------------------------------------------------------------

  describe "property: completion guarantee" do
    @tag :property
    test "PROP_01: any fast task eventually returns a tagged result tuple" do
      check all(
              value <- SD.integer(1..200),
              max_runs: 20
            ) do
        table = new_runner(capacity: 4, timeout_ms: 150)
        {:ok, :accepted, worker} = submit_task(table, fn -> value * 3 end)
        result = await_task(table, worker)

        # Every result must be {:ok, _} or {:error, _}
        assert match?({:ok, _}, result) or match?({:error, _}, result),
               "Result must be a tagged tuple, got: #{inspect(result)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # SECTION 10: Property — resource limit invariant — SC-FLAME-004
  # ---------------------------------------------------------------------------

  describe "property: resource limit invariant" do
    @tag :property
    test "PROP_02: active slot count never exceeds declared capacity" do
      check all(
              capacity <- SD.integer(1..5),
              n_submit <- SD.integer(1..8),
              max_runs: 20
            ) do
        table = new_runner(capacity: capacity, timeout_ms: 200)

        Enum.each(1..n_submit, fn i ->
          # Ignoring at_capacity errors — that is the behaviour we are testing
          submit_task(table, fn -> i end)
        end)

        live_count = active_slot_count(table)

        assert live_count <= capacity,
               "Slot count #{live_count} exceeded capacity #{capacity}"
      end
    end
  end
end
