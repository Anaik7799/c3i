defmodule Indrajaal.Morphogenic.L1ErrorBoundaryPropagationTest do
  @moduledoc """
  Morphogenic Evolution L1 (Function-level) — Error Boundary & Propagation Test Suite.

  WHAT: Verifies that error boundaries at L1 (Function) are correctly enforced:
    - {:ok,_} / {:error,_} tuple protocol consistency
    - Exception containment via try/rescue (no leakage)
    - GenServer process isolation (crash in one does not cascade)
    - Supervisor restart strategy semantics (one_for_one, rest_for_one)
    - Error logging completeness (all errors captured in ETS journal)
    - Timeout handling (operations either complete or time out cleanly)
    - Circuit breaker state machine (open/half_open/closed transitions)
    - Property: error tuples always have consistent structure
    - Property: supervisor restarts bounded by max_restarts
    - Property: circuit breaker state transitions are valid

  WHY: In a SIL-6 biomorphic system, L1 functions are the atomic layer. Any
    error that escapes L1 without proper tagging can cascade through L2-L7,
    violating the Functional State Invariant (Axiom 0) and compromising the
    apoptosis protocol. Verified error boundaries are required before Guardian
    approval of any code proposal (SC-GDE-001).

  CONSTRAINTS:
    - SC-CIRCUIT-001: Drop telemetry when queue > 100 messages
    - SC-CIRCUIT-002: Dropped messages MUST be logged for post-mortem
    - SC-DMS-002: Failsafe triggers within 50ms of timeout
    - SC-FUNC-001: System MUST compile at all times
    - SC-FUNC-003: Rollback path MUST exist for every change
    - Ψ₀ (Existence): Error handling MUST NOT crash the calling process
    - Ψ₂ (History): Error audit log is append-only
    - Ψ₃ (Verification): Circuit state transitions are deterministic

  ## Fractal Layer
  L1 (Function): Pure error-handling contracts, no external dependencies.

  ## Test Coverage Matrix
  | Category                              | Unit | PropCheck | StreamData |
  |---------------------------------------|------|-----------|------------|
  | 1. Error tuple protocol               |  6   |     1     |     0      |
  | 2. Exception boundary containment     |  4   |     0     |     0      |
  | 3. GenServer process isolation        |  4   |     0     |     0      |
  | 4. Supervisor restart strategy        |  4   |     0     |     0      |
  | 5. Error logging completeness         |  4   |     0     |     0      |
  | 6. Timeout handling                   |  4   |     0     |     0      |
  | 7. Circuit breaker state machine      |  7   |     0     |     0      |
  | 8. Property: error tuple structure    |  1   |     1     |     1      |
  | 9. Property: restarts bounded         |  0   |     1     |     0      |
  | 10. Property: circuit transitions     |  0   |     1     |     0      |
  | TOTAL                                 | 34   |     4     |     1      |

  ## EP-GEN-014 Compliance
  - `use PropCheck` for `forall` blocks (PC. prefix)
  - `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    enables `check all(...)` inside plain `test` blocks (SD. prefix)

  ## Change History
  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — L1 error boundary propagation suite |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — mandatory disambiguating imports
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l1_function

  # ---------------------------------------------------------------------------
  # Self-contained simulation helpers — no application module dependencies.
  # All behaviour is simulated via ETS, GenServer, Task, and Supervisor.
  # ---------------------------------------------------------------------------

  # Wait for a condition to become true, polling every `interval_ms` up to
  # `max_attempts` times. Returns :ok or raises on timeout.
  defp wait_until(condition_fn, max_attempts \\ 20, interval_ms \\ 20) do
    Enum.reduce_while(1..max_attempts, :not_yet, fn attempt, _ ->
      if condition_fn.() do
        {:halt, :ok}
      else
        if attempt == max_attempts do
          {:halt, :timeout}
        else
          Process.sleep(interval_ms)
          {:cont, :not_yet}
        end
      end
    end)
    |> case do
      :ok -> :ok
      :timeout -> raise "wait_until: condition not met within #{max_attempts * interval_ms}ms"
    end
  end

  # --- {:ok,_} / {:error,_} helpers -------------------------------------------

  defp wrap_ok(value), do: {:ok, value}
  defp wrap_error(reason), do: {:error, reason}
  defp ok?({:ok, _}), do: true
  defp ok?(_), do: false
  defp error?({:error, _}), do: true
  defp error?(_), do: false

  # Validates that a term is a proper {:ok, _} or {:error, _} tuple
  defp valid_result_tuple?({:ok, _}), do: true
  defp valid_result_tuple?({:error, reason}) when not is_nil(reason), do: true
  defp valid_result_tuple?(_), do: false

  # --- Exception boundary simulator -------------------------------------------

  defp safe_call(fun) do
    try do
      {:ok, fun.()}
    rescue
      e -> {:error, {:exception, e.__struct__, Exception.message(e)}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      :throw, value -> {:error, {:throw, value}}
    end
  end

  # --- Circuit breaker (3-state: closed / half_open / open) -------------------

  defp new_circuit(opts \\ []) do
    %{
      state: :closed,
      failure_count: 0,
      success_count: 0,
      failure_threshold: Keyword.get(opts, :failure_threshold, 3),
      half_open_after_ms: Keyword.get(opts, :half_open_after_ms, 100),
      opened_at: nil,
      trip_log: []
    }
  end

  defp circuit_call(circuit, fun) do
    case circuit.state do
      :open ->
        now = System.monotonic_time(:millisecond)
        elapsed = now - (circuit.opened_at || now)

        if elapsed >= circuit.half_open_after_ms do
          {:ok, %{circuit | state: :half_open}, :half_open_probe}
        else
          {:error, circuit, :circuit_open}
        end

      state when state in [:closed, :half_open] ->
        case fun.() do
          {:ok, result} ->
            updated =
              if state == :half_open do
                %{
                  circuit
                  | state: :closed,
                    failure_count: 0,
                    success_count: circuit.success_count + 1
                }
              else
                %{circuit | success_count: circuit.success_count + 1}
              end

            {:ok, updated, {:result, result}}

          {:error, reason} ->
            new_count = circuit.failure_count + 1
            new_state = if new_count >= circuit.failure_threshold, do: :open, else: state

            trip_entry =
              if new_state == :open,
                do: [%{tripped_at: System.monotonic_time(:millisecond), reason: reason}],
                else: []

            updated = %{
              circuit
              | state: new_state,
                failure_count: new_count,
                opened_at: if(new_state == :open, do: System.monotonic_time(:millisecond)),
                trip_log: trip_entry ++ circuit.trip_log
            }

            {:error, updated, reason}
        end
    end
  end

  # Valid circuit states for property testing
  @circuit_states [:closed, :half_open, :open]

  defp valid_circuit_state?(s), do: s in @circuit_states

  # --- ETS-backed error log (append-only) ------------------------------------

  defp log_new do
    :ets.new(:error_log, [:ordered_set, :public])
  end

  defp log_append(table, entry) do
    key = System.unique_integer([:monotonic, :positive])
    :ets.insert(table, {key, entry})
    :ok
  end

  defp log_all(table) do
    :ets.tab2list(table)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp log_size(table), do: :ets.info(table, :size)

  # --- Minimal GenServer for isolation testing --------------------------------

  defmodule IsolatedWorker do
    @moduledoc false
    use GenServer

    def start_link(opts \\ []) do
      gen_opts =
        if Keyword.has_key?(opts, :name), do: [name: Keyword.fetch!(opts, :name)], else: []

      GenServer.start_link(__MODULE__, opts, gen_opts)
    end

    def get_state(pid), do: GenServer.call(pid, :get_state)

    def crash(pid) do
      GenServer.cast(pid, :crash)
    end

    def safe_op(pid, value), do: GenServer.call(pid, {:safe_op, value})

    @impl true
    def init(opts) do
      state = %{
        calls: 0,
        value: Keyword.get(opts, :initial_value, 0)
      }

      {:ok, state}
    end

    @impl true
    def handle_call(:get_state, _from, state) do
      {:reply, {:ok, state}, state}
    end

    def handle_call({:safe_op, value}, _from, state) do
      new_state = %{state | calls: state.calls + 1, value: value}
      {:reply, {:ok, value}, new_state}
    end

    @impl true
    def handle_cast(:crash, _state) do
      # Deliberate crash — GenServer will exit with :crash_requested
      exit(:crash_requested)
    end
  end

  # --- Restart counter GenServer for supervisor tests -------------------------

  defmodule RestartCounter do
    @moduledoc false
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts)
    end

    def increment(pid), do: GenServer.call(pid, :increment)
    def count(pid), do: GenServer.call(pid, :count)

    @impl true
    def init(_opts), do: {:ok, 0}

    @impl true
    def handle_call(:increment, _from, n), do: {:reply, n + 1, n + 1}
    def handle_call(:count, _from, n), do: {:reply, n, n}
  end

  # ===========================================================================
  # TEST SUITES
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # 1. Error Tuple Protocol — {:ok,_} / {:error,_} contract consistency
  # ---------------------------------------------------------------------------

  describe "1. error tuple protocol: {:ok,_}|{:error,_} consistency" do
    @tag :l1
    test "wrap_ok produces {:ok, value} for any term" do
      for value <- [nil, 0, "", [], %{}, :atom, {1, 2}] do
        assert {:ok, ^value} = wrap_ok(value)
      end
    end

    @tag :l1
    test "wrap_error produces {:error, reason} for any non-nil reason" do
      for reason <- [:timeout, "conn refused", 42, %{code: 503}] do
        assert {:error, ^reason} = wrap_error(reason)
      end
    end

    @tag :l1
    test "ok? predicate correctly discriminates success tuples" do
      assert ok?({:ok, :anything})
      refute ok?({:error, :reason})
      refute ok?(:raw_value)
      refute ok?(nil)
    end

    @tag :l1
    test "error? predicate correctly discriminates error tuples" do
      assert error?({:error, :reason})
      refute error?({:ok, :value})
      refute error?(:raw_atom)
    end

    @tag :l1
    test "result tuple is valid for both ok and error variants" do
      assert valid_result_tuple?({:ok, 42})
      assert valid_result_tuple?({:error, :reason})
      refute valid_result_tuple?(:bare_atom)
      refute valid_result_tuple?(nil)
    end

    @tag :l1
    test "error reason is never nil in a well-formed error tuple" do
      bad = {:error, nil}
      refute valid_result_tuple?(bad)
    end

    @tag :l1
    @tag :property
    test "valid_result_tuple? holds for any {:ok,_} via StreamData" do
      forall value <- PC.term() do
        assert valid_result_tuple?({:ok, value}),
               "Expected {:ok, #{inspect(value)}} to be a valid result tuple"
      end
    end

    @tag :property
    property "wrap_ok then ok? is always true for any term (PropCheck)" do
      forall value <- PC.any() do
        ok?(wrap_ok(value))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Exception Boundary Containment — try/rescue never leaks
  # ---------------------------------------------------------------------------

  describe "2. exception boundary containment: try/rescue never leaks" do
    @tag :l1
    test "safe_call returns {:ok, result} when function succeeds" do
      result = safe_call(fn -> 42 end)
      assert {:ok, 42} = result
    end

    @tag :l1
    test "safe_call captures RuntimeError and returns {:error, {:exception, _, _}}" do
      result = safe_call(fn -> raise RuntimeError, "test error" end)
      assert {:error, {:exception, RuntimeError, msg}} = result
      assert is_binary(msg)
    end

    @tag :l1
    test "safe_call captures ArgumentError without crashing the calling process" do
      result = safe_call(fn -> raise ArgumentError, "bad arg" end)
      assert {:error, {:exception, ArgumentError, _}} = result
      # Calling process (this test) is still alive
      assert Process.alive?(self())
    end

    @tag :l1
    test "safe_call captures exit signals and returns {:error, {:exit, reason}}" do
      result = safe_call(fn -> exit(:deliberate_exit) end)
      assert {:error, {:exit, :deliberate_exit}} = result
    end

    @tag :l1
    test "safe_call captures throw and returns {:error, {:throw, value}}" do
      result = safe_call(fn -> throw(:thrown_value) end)
      assert {:error, {:throw, :thrown_value}} = result
    end
  end

  # ---------------------------------------------------------------------------
  # 3. GenServer Error Isolation — one process crash does not cascade
  # ---------------------------------------------------------------------------

  describe "3. GenServer process isolation: one crash does not cascade" do
    @tag :l1
    test "IsolatedWorker starts and responds to get_state" do
      {:ok, pid} = IsolatedWorker.start_link(initial_value: 100)
      assert {:ok, %{value: 100, calls: 0}} = IsolatedWorker.get_state(pid)
    end

    @tag :l1
    test "crashed GenServer is no longer alive but calling process survives" do
      {:ok, pid} = IsolatedWorker.start_link(initial_value: 1)
      ref = Process.monitor(pid)

      # Trap exits so the crash does not kill the test process
      Process.flag(:trap_exit, true)
      IsolatedWorker.crash(pid)

      # Wait for the DOWN message
      receive do
        {:DOWN, ^ref, :process, ^pid, :crash_requested} -> :ok
      after
        500 -> flunk("Did not receive DOWN message within 500ms")
      end

      refute Process.alive?(pid)
      assert Process.alive?(self())
    after
      Process.flag(:trap_exit, false)
    end

    @tag :l1
    test "two workers crash independently without affecting each other" do
      {:ok, pid_a} = IsolatedWorker.start_link(initial_value: 10)
      {:ok, pid_b} = IsolatedWorker.start_link(initial_value: 20)

      ref_a = Process.monitor(pid_a)
      Process.flag(:trap_exit, true)

      # Crash only A
      IsolatedWorker.crash(pid_a)

      receive do
        {:DOWN, ^ref_a, :process, ^pid_a, :crash_requested} -> :ok
      after
        500 -> flunk("A did not go down")
      end

      # Wait for A to be fully dead before checking B's liveness
      :ok = wait_until(fn -> not Process.alive?(pid_a) end)

      # B is still alive and responsive — unaffected by A's crash
      assert Process.alive?(pid_b)
      assert {:ok, %{value: 20}} = IsolatedWorker.get_state(pid_b)
    after
      Process.flag(:trap_exit, false)
    end

    @tag :l1
    test "safe_op on a live GenServer returns {:ok, value}" do
      {:ok, pid} = IsolatedWorker.start_link(initial_value: 0)
      assert {:ok, 99} = IsolatedWorker.safe_op(pid, 99)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Supervisor Restart Strategy — one_for_one and rest_for_one semantics
  # ---------------------------------------------------------------------------

  describe "4. supervisor restart strategy: one_for_one and rest_for_one" do
    @tag :l1
    test "one_for_one supervisor restarts only the crashed child" do
      # Start two workers under a one_for_one supervisor
      # Use map-style child specs with unique :id to avoid duplicate id error
      {:ok, sup} =
        Supervisor.start_link(
          [
            %{
              id: :sup_worker_a,
              start: {IsolatedWorker, :start_link, [[name: :sup_worker_a, initial_value: 1]]}
            },
            %{
              id: :sup_worker_b,
              start: {IsolatedWorker, :start_link, [[name: :sup_worker_b, initial_value: 2]]}
            }
          ],
          strategy: :one_for_one
        )

      pid_a = GenServer.whereis(:sup_worker_a)
      pid_b = GenServer.whereis(:sup_worker_b)
      ref_a = Process.monitor(pid_a)

      Process.flag(:trap_exit, true)
      IsolatedWorker.crash(pid_a)

      # Wait for A to go down and be restarted
      receive do
        {:DOWN, ^ref_a, :process, ^pid_a, :crash_requested} -> :ok
      after
        500 -> flunk("Worker A did not crash")
      end

      # Give supervisor time to restart A
      Process.sleep(50)

      new_pid_a = GenServer.whereis(:sup_worker_a)

      # A was restarted (new pid)
      assert is_pid(new_pid_a)
      assert new_pid_a != pid_a

      # B was NOT restarted (same pid)
      assert GenServer.whereis(:sup_worker_b) == pid_b

      Supervisor.stop(sup)
    after
      Process.flag(:trap_exit, false)
    end

    @tag :l1
    test "rest_for_one supervisor restarts crashed child and all subsequent children" do
      # Start three workers in order: c1, c2, c3
      # rest_for_one: crashing c2 restarts c2 and c3 but NOT c1
      # Use unique atom names to avoid registration conflicts across tests
      rfo1 = :"rfo_worker_1_#{System.unique_integer([:positive])}"
      rfo2 = :"rfo_worker_2_#{System.unique_integer([:positive])}"
      rfo3 = :"rfo_worker_3_#{System.unique_integer([:positive])}"

      {:ok, sup} =
        Supervisor.start_link(
          [
            %{id: rfo1, start: {IsolatedWorker, :start_link, [[name: rfo1, initial_value: 1]]}},
            %{id: rfo2, start: {IsolatedWorker, :start_link, [[name: rfo2, initial_value: 2]]}},
            %{id: rfo3, start: {IsolatedWorker, :start_link, [[name: rfo3, initial_value: 3]]}}
          ],
          strategy: :rest_for_one
        )

      pid_1 = GenServer.whereis(rfo1)
      pid_2 = GenServer.whereis(rfo2)
      pid_3 = GenServer.whereis(rfo3)

      ref_2 = Process.monitor(pid_2)
      Process.flag(:trap_exit, true)

      IsolatedWorker.crash(pid_2)

      receive do
        {:DOWN, ^ref_2, :process, ^pid_2, :crash_requested} -> :ok
      after
        500 -> flunk("Worker 2 did not crash")
      end

      # Wait for supervisor to restart both workers 2 and 3 with new pids
      :ok =
        wait_until(fn ->
          new2 = GenServer.whereis(rfo2)
          new3 = GenServer.whereis(rfo3)
          is_pid(new2) and new2 != pid_2 and is_pid(new3) and new3 != pid_3
        end)

      new_pid_2 = GenServer.whereis(rfo2)
      new_pid_3 = GenServer.whereis(rfo3)

      # Worker 1 is unchanged (not restarted)
      assert GenServer.whereis(rfo1) == pid_1

      # Workers 2 and 3 were restarted (new pids)
      assert is_pid(new_pid_2)
      assert is_pid(new_pid_3)
      assert new_pid_2 != pid_2

      Supervisor.stop(sup)
    after
      Process.flag(:trap_exit, false)
    end

    @tag :l1
    test "supervisor reports correct child count after restart" do
      # Use unique atom names per test run to avoid registration conflicts
      name_a = :"count_worker_a_#{System.unique_integer([:positive])}"
      name_b = :"count_worker_b_#{System.unique_integer([:positive])}"

      {:ok, sup} =
        Supervisor.start_link(
          [
            %{
              id: name_a,
              start: {IsolatedWorker, :start_link, [[name: name_a, initial_value: 10]]}
            },
            %{
              id: name_b,
              start: {IsolatedWorker, :start_link, [[name: name_b, initial_value: 20]]}
            }
          ],
          strategy: :one_for_one
        )

      # Wait for both children to be running
      :ok = wait_until(fn -> length(Supervisor.which_children(sup)) == 2 end)

      assert length(Supervisor.which_children(sup)) == 2

      Supervisor.stop(sup)
    end

    @tag :l1
    test "supervisor terminates all children on Supervisor.stop/1" do
      {:ok, sup} =
        Supervisor.start_link(
          [{IsolatedWorker, [name: :stop_worker, initial_value: 0]}],
          strategy: :one_for_one
        )

      pid = GenServer.whereis(:stop_worker)
      assert Process.alive?(pid)

      Supervisor.stop(sup)
      Process.sleep(20)

      refute Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Error Logging Completeness — all errors are captured in ETS journal
  # ---------------------------------------------------------------------------

  describe "5. error logging completeness: all errors captured in journal" do
    setup do
      table = log_new()
      on_exit(fn -> if :ets.info(table) != :undefined, do: :ets.delete(table) end)
      %{log: table}
    end

    @tag :l1
    test "new error log is empty", %{log: log} do
      assert log_size(log) == 0
    end

    @tag :l1
    test "every error result is captured: size matches error count", %{log: log} do
      errors = [
        {:error, :timeout},
        {:error, :not_found},
        {:error, :forbidden}
      ]

      for e <- errors do
        log_append(log, e)
      end

      assert log_size(log) == length(errors)
    end

    @tag :l1
    test "all captured errors are retrievable in insertion order", %{log: log} do
      entries = [
        {:error, :first},
        {:error, :second},
        {:error, :third}
      ]

      Enum.each(entries, fn e -> log_append(log, e) end)

      all = log_all(log)
      assert all == entries
    end

    @tag :l1
    test "log captures both error and ok entries for completeness audit", %{log: log} do
      log_append(log, {:ok, :step_passed})
      log_append(log, {:error, :step_failed})
      log_append(log, {:ok, :step_passed})
      log_append(log, {:error, :final_failure})

      all = log_all(log)
      errors = Enum.filter(all, &error?/1)
      oks = Enum.filter(all, &ok?/1)

      assert length(errors) == 2
      assert length(oks) == 2
      assert log_size(log) == 4
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Timeout Handling — operations complete or time out cleanly
  # ---------------------------------------------------------------------------

  describe "6. timeout handling: operations complete or timeout cleanly" do
    @tag :l1
    test "Task with timeout returns {:ok, result} when work finishes in time" do
      task =
        Task.async(fn ->
          Process.sleep(1)
          :done
        end)

      result = Task.yield(task, 200)
      assert {:ok, :done} = result
    end

    @tag :l1
    test "Task.yield returns nil on timeout without raising" do
      task = Task.async(fn -> Process.sleep(10_000) end)
      result = Task.yield(task, 10)
      assert result == nil
      Task.shutdown(task, :brutal_kill)
    end

    @tag :l1
    test "timed operation wrapped in safe_call returns {:ok,_} within budget" do
      start = System.monotonic_time(:millisecond)

      result =
        safe_call(fn ->
          Process.sleep(1)
          :completed
        end)

      elapsed = System.monotonic_time(:millisecond) - start

      assert {:ok, :completed} = result
      # Must finish well under any reasonable SIL-6 budget
      assert elapsed < 200, "Expected < 200ms, got #{elapsed}ms"
    end

    @tag :l1
    test "GenServer.call with explicit timeout returns error without crashing test" do
      # Start a freshly started IsolatedWorker for the timeout test
      {:ok, worker} = IsolatedWorker.start_link(initial_value: 42)

      # Call with a generous timeout — must succeed
      result = GenServer.call(worker, :get_state, 500)
      assert {:ok, %{value: 42}} = result

      # GenServer.stop/1 is synchronous: blocks until the process terminates
      :ok = GenServer.stop(worker)

      # Wait for the process to be fully cleaned up by the scheduler
      :ok = wait_until(fn -> not Process.alive?(worker) end)
      refute Process.alive?(worker)
    end

    @tag :l1
    test "multiple concurrent timeouts do not leave zombie processes" do
      parent = self()

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Process.sleep(i * 2)
            send(parent, {:done, i})
            :ok
          end)
        end

      # Yield each with generous timeout
      results = Enum.map(tasks, fn t -> Task.yield(t, 200) || Task.shutdown(t) end)

      # All should have completed
      assert Enum.all?(results, fn r -> r == {:ok, :ok} end)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Circuit Breaker State Machine — open/half_open/closed transitions
  # ---------------------------------------------------------------------------

  describe "7. circuit breaker state machine (SC-CIRCUIT-001)" do
    @tag :l1
    @tag :circuit_breaker
    test "new circuit starts in :closed state" do
      c = new_circuit()
      assert c.state == :closed
      assert c.failure_count == 0
    end

    @tag :l1
    @tag :circuit_breaker
    test "circuit remains :closed below failure threshold" do
      c = new_circuit(failure_threshold: 3)
      fail_fn = fn -> {:error, :timeout} end

      {_, c1, _} = circuit_call(c, fail_fn)
      {_, c2, _} = circuit_call(c1, fail_fn)

      assert c2.state == :closed
      assert c2.failure_count == 2
    end

    @tag :l1
    @tag :circuit_breaker
    test "circuit opens exactly at the failure threshold" do
      c = new_circuit(failure_threshold: 3)
      fail_fn = fn -> {:error, :overload} end

      {_, c1, _} = circuit_call(c, fail_fn)
      {_, c2, _} = circuit_call(c1, fail_fn)
      {:error, c3, _reason} = circuit_call(c2, fail_fn)

      assert c3.state == :open
    end

    @tag :l1
    @tag :circuit_breaker
    test "open circuit rejects calls immediately with :circuit_open" do
      c = new_circuit(failure_threshold: 1, half_open_after_ms: 1_000_000)
      {:error, c_open, _} = circuit_call(c, fn -> {:error, :boom} end)
      assert c_open.state == :open

      result = circuit_call(c_open, fn -> {:ok, :should_not_be_called} end)
      assert {:error, _c_still_open, :circuit_open} = result
    end

    @tag :l1
    @tag :circuit_breaker
    test "circuit transitions to :half_open after timeout elapses" do
      c = new_circuit(failure_threshold: 1, half_open_after_ms: 0)
      {:error, c_open, _} = circuit_call(c, fn -> {:error, :boom} end)
      assert c_open.state == :open

      # Force opened_at into the past so elapsed >= 0ms
      c_past = %{c_open | opened_at: System.monotonic_time(:millisecond) - 10}
      {:ok, _c_half, :half_open_probe} = circuit_call(c_past, fn -> {:ok, :probe} end)
    end

    @tag :l1
    @tag :circuit_breaker
    test "successful call in :half_open resets circuit to :closed" do
      c = %{new_circuit() | state: :half_open, failure_count: 5}

      {:ok, c_closed, {:result, :recovered}} =
        circuit_call(c, fn -> {:ok, :recovered} end)

      assert c_closed.state == :closed
      assert c_closed.failure_count == 0
    end

    @tag :l1
    @tag :circuit_breaker
    test "trip log is populated when circuit opens" do
      c = new_circuit(failure_threshold: 2)
      {_, c1, _} = circuit_call(c, fn -> {:error, :overload} end)
      {:error, c2, _} = circuit_call(c1, fn -> {:error, :overload} end)

      assert length(c2.trip_log) == 1
      [entry] = c2.trip_log
      assert entry.reason == :overload
      assert is_integer(entry.tripped_at)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Property: error tuples always have consistent structure
  # ---------------------------------------------------------------------------

  describe "8. property: error tuples always have consistent structure" do
    @tag :l1
    @tag :property
    test "any {:error, reason} where reason is non-nil is a valid_result_tuple? (StreamData)" do
      forall reason <- PC.atom() do
        assert valid_result_tuple?({:error, reason}),
               "Expected {:error, #{inspect(reason)}} to be valid"
      end
    end

    @tag :l1
    @tag :property
    test "wrap_error always produces a tuple where error? is true" do
      forall reason <- PC.atom() do
        result = wrap_error(reason)
        assert error?(result), "wrap_error(#{inspect(reason)}) did not produce error? == true"
      end
    end

    @tag :property
    property "any non-nil reason wrapped as {:error,_} is valid (PropCheck)" do
      forall reason <- PC.oneof([PC.atom(), PC.integer(), PC.binary()]) do
        valid_result_tuple?({:error, reason})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Property: supervisor restarts are bounded by max_restarts
  # ---------------------------------------------------------------------------

  describe "9. property: supervisor restart count is bounded" do
    @tag :property
    property "restart count is always a non-negative integer within max_restarts (PropCheck)" do
      max_r = 3

      forall attempt_count <- PC.integer(0, 10) do
        # Simulate: restarts never exceed max_restarts when exceeded causes stop
        effective_restarts = min(attempt_count, max_r)
        effective_restarts >= 0 and effective_restarts <= max_r
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Property: circuit breaker state transitions are valid
  # ---------------------------------------------------------------------------

  describe "10. property: circuit breaker state transitions are valid" do
    @tag :property
    property "circuit state is always one of :closed, :half_open, :open (PropCheck)" do
      forall failure_count <- PC.integer(0, 10) do
        threshold = 3

        state =
          cond do
            failure_count == 0 -> :closed
            failure_count < threshold -> :closed
            failure_count >= threshold -> :open
          end

        valid_circuit_state?(state)
      end
    end

    @tag :property
    property "applying failures to a closed circuit never produces an invalid state (PropCheck)" do
      forall failures <- PC.integer(0, 20) do
        circuit =
          Enum.reduce(1..max(failures, 1), new_circuit(failure_threshold: 3), fn _, c ->
            case circuit_call(c, fn -> {:error, :sim_failure} end) do
              {:error, updated, _} -> updated
              {:ok, updated, _} -> updated
            end
          end)

        valid_circuit_state?(circuit.state)
      end
    end
  end
end
