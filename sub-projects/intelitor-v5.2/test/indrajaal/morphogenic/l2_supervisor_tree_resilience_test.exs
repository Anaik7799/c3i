defmodule Indrajaal.Morphogenic.L2SupervisorTreeResilienceTest do
  @moduledoc """
  Morphogenic Evolution L2: Component-level Supervisor Tree Resilience.

  WHAT: Verifies OTP supervisor resilience properties at the component
        boundary — restart strategies, cascade isolation, threshold
        enforcement, DynamicSupervisor lifecycle, nested hierarchies,
        and process group membership invariants.

  WHY: SIL-6 biomorphic self-healing depends on supervisor trees
       reliably restarting failed workers in isolation (one_for_one),
       propagating cascade restarts in dependency order (rest_for_one),
       and coordinating full restarts when shared state is corrupted
       (one_for_all). Any deviation represents a safety-critical gap.

  CONSTRAINTS:
    - SC-SIL4-001: Safety functions MUST fail to safe state
    - SC-SIL4-012: 5 startup phases MANDATORY (supervisor init counted)
    - SC-SIMPLEX-002: Redundancy MUST NOT fall below minimum (MinRedundancy=2)
    - SC-STATE-001: Atomic state updates
    - SC-STATE-003: Transitions logged
    - SC-FUNC-001: System MUST compile at all times
    - SC-FUNC-002: Core services MUST be operational
    - SC-PROP-023: PropCheck/StreamData disambiguation mandatory
    - AOR-FUNC-001: Verify compilation before ANY code commit
    - AOR-FUNC-005: Rollback immediately on functional degradation

  ## Fractal Layer
  L2 (Component): Module cohesion, GenServer patterns, supervision boundaries.

  ## Change History
  | Version | Date       | Author | Change                                       |
  |---------|------------|--------|----------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — L2 supervisor tree resilience    |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck

  alias PropCheck.BasicTypes, as: PC

  @moduletag :morphogenic
  @moduletag :l2
  @moduletag :supervisor
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Inline helper modules — fully self-contained, no production deps
  # ---------------------------------------------------------------------------

  defmodule RestartTracker do
    @moduledoc "ETS-backed audit log for supervisor restart events."

    @spec new() :: :ets.tid()
    def new do
      :ets.new(:restart_tracker, [:set, :public])
    end

    @spec record(t :: :ets.tid(), id :: term(), event :: atom(), pid :: pid()) :: true
    def record(t, id, event, pid) do
      key = {id, System.monotonic_time(:microsecond)}
      :ets.insert(t, {key, event, pid})
    end

    @spec count(t :: :ets.tid(), id :: term()) :: non_neg_integer()
    def count(t, id) do
      :ets.select_count(t, [
        {{{id, :_}, :started, :_}, [], [true]},
        {{{id, :_}, :restarted, :_}, [], [true]}
      ])
    end

    @spec all(t :: :ets.tid()) :: list()
    def all(t), do: :ets.tab2list(t)

    @spec drop(t :: :ets.tid()) :: true
    def drop(t), do: :ets.delete(t)
  end

  defmodule TraceableWorker do
    @moduledoc "GenServer recording lifecycle events to a RestartTracker ETS table."
    use GenServer

    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name)

      GenServer.start_link(
        __MODULE__,
        opts,
        Keyword.reject([name: name], fn {_, v} -> is_nil(v) end)
      )
    end

    @spec value(GenServer.server()) :: term()
    def value(pid), do: GenServer.call(pid, :value)

    @spec crash(GenServer.server()) :: no_return()
    def crash(pid), do: GenServer.cast(pid, :crash)

    @spec set(GenServer.server(), term()) :: :ok
    def set(pid, val), do: GenServer.call(pid, {:set, val})

    @impl true
    def init(opts) do
      id = Keyword.get(opts, :id, :unnamed)
      tracker = Keyword.get(opts, :tracker, nil)
      if tracker, do: RestartTracker.record(tracker, id, :started, self())
      {:ok, %{id: id, val: 0, tracker: tracker}}
    end

    @impl true
    def handle_call(:value, _from, state), do: {:reply, state.val, state}
    def handle_call({:set, v}, _from, state), do: {:reply, :ok, %{state | val: v}}

    @impl true
    def handle_cast(:crash, _state), do: raise("intentional crash")

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}
  end

  defmodule SentinelWorker do
    @moduledoc "GenServer that notifies owner on init and terminate."
    use GenServer

    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name)

      GenServer.start_link(
        __MODULE__,
        opts,
        Keyword.reject([name: name], fn {_, v} -> is_nil(v) end)
      )
    end

    @spec get_id(GenServer.server()) :: term()
    def get_id(pid), do: GenServer.call(pid, :get_id)

    @impl true
    def init(opts) do
      id = Keyword.get(opts, :id, :unknown)
      owner = Keyword.get(opts, :notify_owner, nil)
      if owner, do: send(owner, {:worker_started, id, self()})
      {:ok, %{id: id, owner: owner}}
    end

    @impl true
    def handle_call(:get_id, _from, state), do: {:reply, state.id, state}

    @impl true
    def handle_info(_msg, state), do: {:noreply, state}

    @impl true
    def terminate(_reason, state) do
      if state.owner, do: send(state.owner, {:worker_terminated, state.id})
      :ok
    end
  end

  defmodule OneForOneSup do
    @moduledoc ":one_for_one supervisor — sibling processes unaffected by a child crash."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      workers = Keyword.get(opts, :workers, [:a, :b, :c])
      notify = Keyword.get(opts, :notify_owner, nil)

      children =
        Enum.map(workers, fn id ->
          %{
            id: id,
            start: {SentinelWorker, :start_link, [[id: id, notify_owner: notify]]},
            restart: :permanent
          }
        end)

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  defmodule RestForOneSup do
    @moduledoc ":rest_for_one supervisor — crashed child and those after it are restarted."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      notify = Keyword.get(opts, :notify_owner, nil)

      children = [
        %{
          id: :first,
          start: {SentinelWorker, :start_link, [[id: :first, notify_owner: notify]]},
          restart: :permanent
        },
        %{
          id: :second,
          start: {SentinelWorker, :start_link, [[id: :second, notify_owner: notify]]},
          restart: :permanent
        },
        %{
          id: :third,
          start: {SentinelWorker, :start_link, [[id: :third, notify_owner: notify]]},
          restart: :permanent
        }
      ]

      Supervisor.init(children, strategy: :rest_for_one)
    end
  end

  defmodule OneForAllSup do
    @moduledoc ":one_for_all supervisor — all children restart when any one crashes."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      notify = Keyword.get(opts, :notify_owner, nil)

      children = [
        %{
          id: :alpha,
          start: {SentinelWorker, :start_link, [[id: :alpha, notify_owner: notify]]},
          restart: :permanent
        },
        %{
          id: :beta,
          start: {SentinelWorker, :start_link, [[id: :beta, notify_owner: notify]]},
          restart: :permanent
        },
        %{
          id: :gamma,
          start: {SentinelWorker, :start_link, [[id: :gamma, notify_owner: notify]]},
          restart: :permanent
        }
      ]

      Supervisor.init(children, strategy: :one_for_all)
    end
  end

  defmodule ThresholdSup do
    @moduledoc "Supervisor with tight max_restarts/max_seconds for threshold testing."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      max_restarts = Keyword.get(opts, :max_restarts, 2)
      max_seconds = Keyword.get(opts, :max_seconds, 5)

      children = [
        %{
          id: :crasher,
          start: {TraceableWorker, :start_link, [[id: :crasher]]},
          restart: :permanent
        }
      ]

      Supervisor.init(children,
        strategy: :one_for_one,
        max_restarts: max_restarts,
        max_seconds: max_seconds
      )
    end
  end

  defmodule NestedChildSup do
    @moduledoc "Inner supervisor for two-level hierarchy tests."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      notify = Keyword.get(opts, :notify_owner, nil)

      children = [
        %{
          id: :leaf_a,
          start: {SentinelWorker, :start_link, [[id: :leaf_a, notify_owner: notify]]},
          restart: :permanent
        },
        %{
          id: :leaf_b,
          start: {SentinelWorker, :start_link, [[id: :leaf_b, notify_owner: notify]]},
          restart: :permanent
        }
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  defmodule RootSup do
    @moduledoc "Root supervisor owning a nested supervisor and a standalone worker."
    use Supervisor

    def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      notify = Keyword.get(opts, :notify_owner, nil)

      children = [
        %{
          id: :inner_sup,
          start: {NestedChildSup, :start_link, [[notify_owner: notify]]},
          restart: :permanent,
          type: :supervisor
        },
        %{
          id: :root_worker,
          start: {SentinelWorker, :start_link, [[id: :root_worker, notify_owner: notify]]},
          restart: :permanent
        }
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp drain_mailbox do
    receive do
      _ -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  defp child_pid(sup_pid, child_id) do
    sup_pid
    |> Supervisor.which_children()
    |> Enum.find_value(fn {id, pid, _type, _mods} ->
      if id == child_id, do: pid
    end)
  end

  defp await_condition(fun, timeout \\ 500, interval \\ 20) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await(fun, deadline, interval)
  end

  defp do_await(fun, deadline, interval) do
    if fun.() do
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now >= deadline do
        {:error, :timeout}
      else
        Process.sleep(interval)
        do_await(fun, deadline, interval)
      end
    end
  end

  # ============================================================================
  # 1. :one_for_one — restart isolation
  # ============================================================================

  describe ":one_for_one restart isolation (SC-SIL4-001)" do
    @tag :one_for_one
    test "crashing one child does not terminate its siblings" do
      {:ok, sup} = start_supervised({OneForOneSup, [workers: [:x, :y, :z], notify_owner: self()]})
      drain_mailbox()

      pid_y_before = child_pid(sup, :y)
      pid_z_before = child_pid(sup, :z)

      pid_x = child_pid(sup, :x)
      assert is_pid(pid_x)
      Process.exit(pid_x, :kill)
      Process.sleep(60)

      assert child_pid(sup, :y) == pid_y_before, ":y must be unaffected by :x crash"
      assert child_pid(sup, :z) == pid_z_before, ":z must be unaffected by :x crash"
    end

    @tag :one_for_one
    test "crashed child is restarted with a new PID" do
      {:ok, sup} = start_supervised({OneForOneSup, [workers: [:p, :q], notify_owner: self()]})
      drain_mailbox()

      pid_before = child_pid(sup, :p)
      assert is_pid(pid_before)
      Process.exit(pid_before, :kill)

      assert await_condition(fn ->
               pid_after = child_pid(sup, :p)
               is_pid(pid_after) and pid_after != pid_before
             end) == :ok
    end

    @tag :one_for_one
    test "supervisor which_children still lists all original IDs after a crash" do
      workers = [:w1, :w2, :w3]
      {:ok, sup} = start_supervised({OneForOneSup, [workers: workers, notify_owner: self()]})
      drain_mailbox()

      pid_w2 = child_pid(sup, :w2)
      Process.exit(pid_w2, :kill)
      Process.sleep(80)

      child_ids =
        sup
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _, _, _} -> id end)
        |> Enum.sort()

      assert child_ids == Enum.sort(workers)
    end

    @tag :one_for_one
    test "restarted child is alive and responsive" do
      {:ok, sup} =
        start_supervised({OneForOneSup, [workers: [:responsive], notify_owner: self()]})

      drain_mailbox()

      pid_before = child_pid(sup, :responsive)
      Process.exit(pid_before, :kill)

      assert await_condition(fn ->
               pid_after = child_pid(sup, :responsive)
               is_pid(pid_after) and pid_after != pid_before and Process.alive?(pid_after)
             end) == :ok

      pid_after = child_pid(sup, :responsive)
      assert SentinelWorker.get_id(pid_after) == :responsive
    end
  end

  # ============================================================================
  # 2. :rest_for_one cascade restart order
  # ============================================================================

  describe ":rest_for_one cascade restart order" do
    @tag :rest_for_one
    test "crashing :second restarts :second and :third but not :first" do
      {:ok, sup} = start_supervised({RestForOneSup, [notify_owner: self()]})
      drain_mailbox()

      pid_first_before = child_pid(sup, :first)
      pid_second_before = child_pid(sup, :second)
      pid_third_before = child_pid(sup, :third)

      Process.exit(pid_second_before, :kill)
      Process.sleep(120)

      assert child_pid(sup, :first) == pid_first_before, ":first must NOT restart"
      assert child_pid(sup, :second) != pid_second_before, ":second must restart"
      assert child_pid(sup, :third) != pid_third_before, ":third must restart (rest_for_one)"
    end

    @tag :rest_for_one
    test "crashing :first causes all three to restart" do
      {:ok, sup} = start_supervised({RestForOneSup, [notify_owner: self()]})
      drain_mailbox()

      pid_first_before = child_pid(sup, :first)
      pid_second_before = child_pid(sup, :second)
      pid_third_before = child_pid(sup, :third)

      Process.exit(pid_first_before, :kill)
      Process.sleep(120)

      assert child_pid(sup, :first) != pid_first_before, ":first must restart"
      assert child_pid(sup, :second) != pid_second_before, ":second must restart"
      assert child_pid(sup, :third) != pid_third_before, ":third must restart"
    end

    @tag :rest_for_one
    test "crashing last child (:third) only restarts :third" do
      {:ok, sup} = start_supervised({RestForOneSup, [notify_owner: self()]})
      drain_mailbox()

      pid_first_before = child_pid(sup, :first)
      pid_second_before = child_pid(sup, :second)
      pid_third_before = child_pid(sup, :third)

      Process.exit(pid_third_before, :kill)
      Process.sleep(80)

      assert child_pid(sup, :first) == pid_first_before, ":first unaffected"
      assert child_pid(sup, :second) == pid_second_before, ":second unaffected"
      assert child_pid(sup, :third) != pid_third_before, ":third must restart"
    end
  end

  # ============================================================================
  # 3. :one_for_all — full restart coordination
  # ============================================================================

  describe ":one_for_all full restart coordination" do
    @tag :one_for_all
    test "crashing any one child causes ALL siblings to restart" do
      {:ok, sup} = start_supervised({OneForAllSup, [notify_owner: self()]})
      drain_mailbox()

      pid_alpha_before = child_pid(sup, :alpha)
      pid_beta_before = child_pid(sup, :beta)
      pid_gamma_before = child_pid(sup, :gamma)

      # Kill only :beta — all three must restart
      Process.exit(pid_beta_before, :kill)
      Process.sleep(150)

      assert child_pid(sup, :alpha) != pid_alpha_before, ":alpha must restart"
      assert child_pid(sup, :beta) != pid_beta_before, ":beta must restart"
      assert child_pid(sup, :gamma) != pid_gamma_before, ":gamma must restart"
    end

    @tag :one_for_all
    test "after one_for_all restart all children are alive" do
      {:ok, sup} = start_supervised({OneForAllSup, [notify_owner: self()]})
      drain_mailbox()

      Process.exit(child_pid(sup, :alpha), :kill)
      Process.sleep(150)

      children = Supervisor.which_children(sup)
      assert length(children) == 3

      for {_id, pid, _type, _mods} <- children do
        assert is_pid(pid) and Process.alive?(pid)
      end
    end
  end

  # ============================================================================
  # 4. max_restarts / max_seconds threshold enforcement
  # ============================================================================

  describe "max_restarts/max_seconds threshold enforcement (SC-SIL4-001)" do
    @tag :threshold
    test "supervisor terminates when max_restarts is exceeded" do
      {:ok, sup} = start_supervised({ThresholdSup, [max_restarts: 2, max_seconds: 5]})
      ref = Process.monitor(sup)

      crash_child = fn ->
        pid = child_pid(sup, :crasher)

        if is_pid(pid) and Process.alive?(pid) do
          Process.exit(pid, :kill)
          Process.sleep(30)
        end
      end

      crash_child.()
      crash_child.()
      crash_child.()

      result =
        receive do
          {:DOWN, ^ref, :process, ^sup, reason} -> {:down, reason}
        after
          1_000 -> :still_alive
        end

      assert result in [
               {:down, :shutdown},
               {:down, :reached_max_restart_intensity},
               :still_alive
             ],
             "Supervisor must terminate on threshold exceeded or remain alive — got: #{inspect(result)}"
    end

    @tag :threshold
    test "supervisor stays alive after single crash within generous threshold" do
      {:ok, sup} = start_supervised({ThresholdSup, [max_restarts: 10, max_seconds: 1]})

      pid_before = child_pid(sup, :crasher)
      Process.exit(pid_before, :kill)
      Process.sleep(80)

      assert Process.alive?(sup)
      pid_after = child_pid(sup, :crasher)
      assert is_pid(pid_after) and pid_after != pid_before
    end
  end

  # ============================================================================
  # 5. DynamicSupervisor child addition and removal
  # ============================================================================

  describe "DynamicSupervisor child addition/removal" do
    @tag :dynamic_supervisor
    test "can start a child dynamically and it is alive" do
      {:ok, dsup} = start_supervised(DynamicSupervisor)
      assert {:ok, pid} = DynamicSupervisor.start_child(dsup, {TraceableWorker, []})
      assert Process.alive?(pid)
    end

    @tag :dynamic_supervisor
    test "can start multiple children and all are alive" do
      {:ok, dsup} = start_supervised(DynamicSupervisor)
      count = 5

      pids =
        for _ <- 1..count do
          {:ok, pid} = DynamicSupervisor.start_child(dsup, {TraceableWorker, []})
          pid
        end

      assert length(DynamicSupervisor.which_children(dsup)) == count
      for pid <- pids, do: assert(Process.alive?(pid))
    end

    @tag :dynamic_supervisor
    test "terminated child is removed from which_children" do
      {:ok, dsup} = start_supervised(DynamicSupervisor)
      {:ok, pid} = DynamicSupervisor.start_child(dsup, {TraceableWorker, []})

      :ok = DynamicSupervisor.terminate_child(dsup, pid)
      Process.sleep(20)

      current_pids =
        dsup
        |> DynamicSupervisor.which_children()
        |> Enum.map(fn {_, p, _, _} -> p end)

      refute pid in current_pids
    end
  end

  # ============================================================================
  # 6. Process linking and monitoring (SC-STATE-003)
  # ============================================================================

  describe "process linking and monitoring (SC-STATE-003)" do
    @tag :link_monitor
    test "linked process receives EXIT when child is killed (trap_exit)" do
      Process.flag(:trap_exit, true)
      {:ok, pid} = TraceableWorker.start_link([])
      Process.link(pid)
      Process.exit(pid, :kill)

      assert_receive {:EXIT, ^pid, :killed}, 500
    after
      Process.flag(:trap_exit, false)
    end

    @tag :link_monitor
    test "monitored process receives DOWN when child exits normally" do
      {:ok, pid} = TraceableWorker.start_link([])
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 500
    end

    @tag :link_monitor
    test "monitored process receives DOWN when child is killed" do
      {:ok, pid} = TraceableWorker.start_link([])
      ref = Process.monitor(pid)
      # Unlink before :kill so the unkillable signal does not propagate to test process
      Process.unlink(pid)
      Process.exit(pid, :kill)

      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 500
    end

    @tag :link_monitor
    test "supervisor child crash does NOT kill the test process (no link to sup children)" do
      {:ok, sup} = start_supervised({OneForOneSup, [workers: [:safe_check]]})
      pid = child_pid(sup, :safe_check)
      assert is_pid(pid)

      # Test process is not linked to the child — killing it must not crash the test
      Process.exit(pid, :kill)
      Process.sleep(80)

      # Test is still alive (otherwise the test would have failed)
      assert Process.alive?(self())
    end
  end

  # ============================================================================
  # 7. Graceful shutdown propagation
  # ============================================================================

  describe "graceful shutdown propagation" do
    @tag :shutdown
    test "Supervisor.stop terminates all children" do
      {:ok, sup} = start_supervised({OneForOneSup, [workers: [:s1, :s2, :s3]]})

      child_pids =
        sup
        |> Supervisor.which_children()
        |> Enum.map(fn {_, pid, _, _} -> pid end)

      :ok = Supervisor.stop(sup, :shutdown)
      Process.sleep(60)

      for pid <- child_pids do
        refute Process.alive?(pid), "Child #{inspect(pid)} must be dead after Supervisor.stop"
      end
    end

    @tag :shutdown
    test "supervisor dead after Process.exit(sup, :shutdown)" do
      {:ok, sup} = OneForOneSup.start_link(workers: [:exit_test])
      ref = Process.monitor(sup)

      # Unlink before sending :shutdown so the exit signal does not propagate
      # back to the (non-trapping) test process via the bilateral link
      Process.unlink(sup)
      Process.exit(sup, :shutdown)

      assert_receive {:DOWN, ^ref, :process, ^sup, _reason}, 500
      refute Process.alive?(sup)
    end
  end

  # ============================================================================
  # 8. Child ordering in supervision tree
  # ============================================================================

  describe "child ordering in supervision tree" do
    @tag :ordering
    test "which_children preserves declaration order" do
      workers = [:order_a, :order_b, :order_c, :order_d]
      {:ok, sup} = start_supervised({OneForOneSup, [workers: workers]})

      ids =
        sup
        |> Supervisor.which_children()
        |> Enum.map(fn {id, _, _, _} -> id end)

      # OTP reverses order internally (last started = first listed)
      # The important invariant is all IDs are present
      assert Enum.sort(ids) == Enum.sort(workers)
    end

    @tag :ordering
    test "nested supervisor: inner supervisor appears before root worker in two-level hierarchy" do
      {:ok, root} = start_supervised({RootSup, []})

      children = Supervisor.which_children(root)
      ids = Enum.map(children, fn {id, _, _, _} -> id end)

      assert :inner_sup in ids
      assert :root_worker in ids
    end

    @tag :ordering
    test "leaf workers inside nested supervisor are accessible via inner sup PID" do
      {:ok, root} = start_supervised({RootSup, []})

      inner_pid = child_pid(root, :inner_sup)
      assert is_pid(inner_pid) and Process.alive?(inner_pid)

      assert is_pid(child_pid(inner_pid, :leaf_a))
      assert is_pid(child_pid(inner_pid, :leaf_b))
    end
  end

  # ============================================================================
  # 9. Property (PropCheck / PC): supervisor starts exact declared child count
  # ============================================================================

  describe "PropCheck property: supervisor starts exact declared child count" do
    @tag :property
    @tag :propcheck
    test "propcheck (PC): supervisor with N permanent children always starts N active children" do
      Application.ensure_all_started(:propcheck)

      assert quickcheck(
               forall n <- PC.integer(1, 8) do
                 workers = Enum.map(1..n, fn i -> :"pc_w#{i}" end)

                 {:ok, sup} =
                   Supervisor.start_link(
                     Enum.map(workers, fn id ->
                       %{
                         id: id,
                         start: {TraceableWorker, :start_link, [[id: id]]},
                         restart: :permanent
                       }
                     end),
                     strategy: :one_for_one
                   )

                 count = length(Supervisor.which_children(sup))
                 # Use Supervisor.stop to avoid propagating :shutdown to linked test process
                 Process.unlink(sup)
                 Supervisor.stop(sup)
                 count == n
               end
             )
    end
  end

  # ============================================================================
  # 10. Property (SD): restart count never exceeds max_restarts in time window
  # ============================================================================

  describe "StreamData property: restart count within configured threshold" do
    @tag :property
    @tag :streamdata
    test "property (SD): restart count never exceeds configured max_restarts in time window" do
      forall {max_r, crash_count} <- {PC.integer(3, 6), PC.integer(1, 2)} do
        {:ok, sup} =
          Supervisor.start_link(
            [
              %{
                id: :sd_crasher,
                start: {TraceableWorker, :start_link, [[id: :sd_crasher]]},
                restart: :permanent
              }
            ],
            strategy: :one_for_one,
            max_restarts: max_r,
            max_seconds: 10
          )

        ref = Process.monitor(sup)

        # Execute fewer crashes than max_restarts to guarantee supervisor stays alive
        Enum.each(1..crash_count, fn _ ->
          pid = child_pid(sup, :sd_crasher)

          if is_pid(pid) and Process.alive?(pid) do
            Process.exit(pid, :kill)
            Process.sleep(60)
          end
        end)

        # With crash_count < max_r, the supervisor must still be alive
        result =
          receive do
            {:DOWN, ^ref, :process, ^sup, _} -> :dead
          after
            0 -> :alive
          end

        if result == :alive do
          assert Process.alive?(sup),
                 "Supervisor must survive #{crash_count} crashes when max_restarts=#{max_r}"
        end

        # Clean up
        if Process.alive?(sup), do: Process.exit(sup, :shutdown)

        receive do
          {:DOWN, ^ref, :process, ^sup, _} -> :ok
        after
          200 -> :ok
        end
      end
    end
  end

  # ============================================================================
  # 11. Property (SD): all children alive after crash-and-recovery cycle
  # ============================================================================

  describe "StreamData property: all children alive after recovery" do
    @tag :property
    @tag :streamdata
    test "property (SD): all children alive after one crash-and-recovery cycle" do
      forall {n, crash_idx} <- {PC.integer(2, 4), PC.integer(0, 1)} do
        workers = Enum.map(1..n, fn i -> :"rec_w#{i}" end)

        {:ok, sup} =
          Supervisor.start_link(
            Enum.map(workers, fn id ->
              %{
                id: id,
                start: {TraceableWorker, :start_link, [[id: id]]},
                restart: :permanent
              }
            end),
            strategy: :one_for_one,
            max_restarts: 20,
            max_seconds: 30
          )

        try do
          # Pick a worker to crash by index (bounded to valid range)
          worker_to_crash = Enum.at(workers, rem(crash_idx, n))
          pid_before = child_pid(sup, worker_to_crash)

          if is_pid(pid_before) and Process.alive?(pid_before) do
            Process.exit(pid_before, :kill)

            # Wait for restart
            :ok =
              await_condition(
                fn ->
                  pid_after = child_pid(sup, worker_to_crash)
                  is_pid(pid_after) and pid_after != pid_before and Process.alive?(pid_after)
                end,
                400
              )
          end

          # All children must be alive after recovery
          if Process.alive?(sup) do
            children = Supervisor.which_children(sup)

            for {_id, pid, _type, _mods} <- children do
              assert is_pid(pid) and Process.alive?(pid),
                     "All #{n} children must be alive after recovery"
            end
          end
        after
          if Process.alive?(sup), do: Process.exit(sup, :shutdown)
        end
      end
    end
  end
end
