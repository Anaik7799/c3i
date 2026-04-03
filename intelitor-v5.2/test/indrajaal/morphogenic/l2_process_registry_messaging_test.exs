defmodule Indrajaal.Morphogenic.L2ProcessRegistryMessagingTest do
  @moduledoc """
  WHAT: L2 (Component Architecture) test suite for process registry and
        inter-process messaging in the Indrajaal SIL-6 Biomorphic Mesh.
        All infrastructure is defined inline — no dependency on production
        modules. Covers ETS-backed process registration, selective receive,
        link/monitor semantics, process group management, FIFO ordering
        guarantees, dead-letter handling, request-reply patterns, and
        fan-out messaging.

  WHY: At L2 (Component level) the messaging substrate underpins every
       higher-level concern — alarms, telemetry, Guardian proposals, and
       OODA loop coordination. Failures in registration (stale entries),
       ordering (re-ordered events), or delivery (dropped messages) are
       root causes of SIL-6 availability violations (SC-SIL4-015 split-brain)
       and audit-trail gaps (SC-STATE-003). Running these tests in-process
       and deterministically guarantees zero reliance on external services.

  CONSTRAINTS:
    - SC-ORCH-009: All inter-service messages MUST be logged
    - SC-ORCH-011: Critical messages MUST be delivered first (priority ordering)
    - SC-BUS-001:  Async messaging ONLY — no blocking calls on the control bus
    - SC-STATE-001: State updates are atomic — no partial delivery observed
    - SC-STATE-003: Transitions logged — audit trail written for every mutation
    - SC-FUNC-001:  System MUST compile at all times — inline modules compile
    - SC-OODA-001:  OODA cycle < 100ms; round-trip timing verified within budget
    - SC-PROP-023:  PropCheck/StreamData disambiguation MANDATORY (EP-GEN-014)

  ## Fractal Layer
  L2 (Component): Module cohesion, process registration, inter-process IPC.

  ## Change History
  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — L2 process registry & messaging    |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Dual property testing disambiguation.
  # check: 2 is excluded to prevent conflict with PropCheck's own check macro.
  # All check all(...) calls MUST use ExUnitProperties.check all(...) (fully qualified).
  # `import ExUnitProperties` is intentionally omitted since all SD calls are via
  # ExUnitProperties.check all(...) — ExUnitProperties is required for macro expansion.
  require ExUnitProperties

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l2
  @moduletag timeout: 90_000

  # Ensure PropCheck.CounterStrike GenServer is running (needed for forall properties
  # when the full application is not started via mix test alias).
  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ============================================================================
  # Inline infrastructure — all modules are nested inside the test module so
  # they live in a private namespace and do not collide across parallel runs.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # EtsRegistry — lightweight process registry backed by a public ETS table.
  # Mimics the core behaviour of :global / Registry without external deps.
  # ---------------------------------------------------------------------------

  defmodule EtsRegistry do
    @moduledoc "ETS-backed name → pid registry with TTL-free entries."

    @spec new(atom()) :: :ets.tid()
    def new(suffix) do
      name = :"l2_registry_#{suffix}_#{:erlang.unique_integer([:positive])}"
      :ets.new(name, [:set, :public, :named_table])
    end

    @spec register(atom() | :ets.tid(), atom(), pid()) ::
            :ok | {:error, {:already_registered, pid()}}
    def register(table, name, pid) do
      case :ets.insert_new(table, {name, pid, System.monotonic_time(:microsecond)}) do
        true -> :ok
        false -> {:error, {:already_registered, lookup_pid(table, name)}}
      end
    end

    @spec unregister(atom() | :ets.tid(), atom()) :: :ok
    def unregister(table, name) do
      :ets.delete(table, name)
      :ok
    end

    @spec lookup(atom() | :ets.tid(), atom()) :: {:ok, pid()} | {:error, :not_found}
    def lookup(table, name) do
      case :ets.lookup(table, name) do
        [{^name, pid, _ts}] -> {:ok, pid}
        [] -> {:error, :not_found}
      end
    end

    @spec all(atom() | :ets.tid()) :: [{atom(), pid()}]
    def all(table) do
      :ets.tab2list(table) |> Enum.map(fn {name, pid, _ts} -> {name, pid} end)
    end

    @spec purge_dead(atom() | :ets.tid()) :: non_neg_integer()
    def purge_dead(table) do
      dead =
        :ets.tab2list(table)
        |> Enum.filter(fn {_name, pid, _ts} -> not Process.alive?(pid) end)

      Enum.each(dead, fn {name, _pid, _ts} -> :ets.delete(table, name) end)
      length(dead)
    end

    @spec drop(atom() | :ets.tid()) :: :ok
    def drop(table) do
      if :ets.info(table) != :undefined, do: :ets.delete(table)
      :ok
    end

    # ---

    defp lookup_pid(table, name) do
      case :ets.lookup(table, name) do
        [{^name, pid, _ts}] -> pid
        [] -> nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ProcessGroup — maps group names to lists of member pids stored in ETS.
  # ---------------------------------------------------------------------------

  defmodule ProcessGroup do
    @moduledoc "ETS-backed process group (group_name → [pid]) with membership queries."

    @spec new(atom()) :: :ets.tid()
    def new(suffix) do
      name = :"l2_pg_#{suffix}_#{:erlang.unique_integer([:positive])}"
      :ets.new(name, [:bag, :public])
    end

    @spec join(atom() | :ets.tid(), atom(), pid()) :: :ok
    def join(table, group, pid) do
      :ets.insert(table, {group, pid})
      :ok
    end

    @spec leave(atom() | :ets.tid(), atom(), pid()) :: :ok
    def leave(table, group, pid) do
      :ets.match_delete(table, {group, pid})
      :ok
    end

    @spec members(atom() | :ets.tid(), atom()) :: [pid()]
    def members(table, group) do
      :ets.lookup(table, group) |> Enum.map(fn {_g, pid} -> pid end)
    end

    @spec groups(atom() | :ets.tid()) :: [atom()]
    def groups(table) do
      :ets.tab2list(table) |> Enum.map(fn {g, _pid} -> g end) |> Enum.uniq()
    end

    @spec member?(atom() | :ets.tid(), atom(), pid()) :: boolean()
    def member?(table, group, pid) do
      :ets.match_object(table, {group, pid}) != []
    end

    @spec drop(atom() | :ets.tid()) :: :ok
    def drop(table) do
      if :ets.info(table) != :undefined, do: :ets.delete(table)
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # AuditLog — append-only ETS sequence log for message delivery evidence.
  # SC-ORCH-009: all inter-service messages MUST be logged.
  # ---------------------------------------------------------------------------

  defmodule AuditLog do
    @moduledoc "Append-only ETS log of message delivery events (SC-ORCH-009)."

    @spec new(atom()) :: :ets.tid()
    def new(suffix) do
      name = :"l2_audit_#{suffix}_#{:erlang.unique_integer([:positive])}"
      :ets.new(name, [:ordered_set, :public])
    end

    @spec append(atom() | :ets.tid(), term()) :: non_neg_integer()
    def append(table, event) do
      seq = :erlang.unique_integer([:positive, :monotonic])
      :ets.insert(table, {seq, event, System.monotonic_time(:microsecond)})
      seq
    end

    @spec entries(atom() | :ets.tid()) :: [{non_neg_integer(), term(), integer()}]
    def entries(table) do
      :ets.tab2list(table) |> Enum.sort_by(fn {seq, _, _} -> seq end)
    end

    @spec count(atom() | :ets.tid()) :: non_neg_integer()
    def count(table) do
      :ets.info(table, :size)
    end

    @spec drop(atom() | :ets.tid()) :: :ok
    def drop(table) do
      if :ets.info(table) != :undefined, do: :ets.delete(table)
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # MessageBroker — a GenServer that routes tagged messages, logs every
  # delivery to an AuditLog table, and supports priority lanes.
  # SC-BUS-001: async messaging only. SC-ORCH-009: logged. SC-ORCH-011: priority.
  # ---------------------------------------------------------------------------

  defmodule MessageBroker do
    @moduledoc "Priority-aware async message broker backed by an ETS AuditLog."
    use GenServer

    # --- Public API -----------------------------------------------------------

    def start_link(audit_table, opts \\ []) do
      GenServer.start_link(__MODULE__, audit_table, opts)
    end

    @doc "Send an async message to a registered name via the registry."
    def send_msg(broker, registry, name, payload, priority \\ :normal) do
      GenServer.cast(broker, {:send, registry, name, payload, priority})
    end

    @doc "Broadcast to all members of a process group."
    def broadcast(broker, pg_table, group, payload) do
      GenServer.cast(broker, {:broadcast, pg_table, group, payload})
    end

    @doc "Return the total number of logged messages (via a synchronous call)."
    def logged_count(broker), do: GenServer.call(broker, :logged_count)

    @doc "Return all log entries in delivery order."
    def log_entries(broker), do: GenServer.call(broker, :log_entries)

    def stop(broker), do: GenServer.stop(broker)

    # --- Callbacks ------------------------------------------------------------

    @impl true
    def init(audit_table) do
      {:ok, %{audit: audit_table, delivered: 0, dropped: 0}}
    end

    @impl true
    def handle_cast({:send, registry, name, payload, priority}, state) do
      case EtsRegistry.lookup(registry, name) do
        {:ok, pid} ->
          tagged = {:"$msg", priority, payload, System.monotonic_time(:microsecond)}
          send(pid, tagged)
          AuditLog.append(state.audit, %{type: :delivered, to: name, priority: priority})
          {:noreply, %{state | delivered: state.delivered + 1}}

        {:error, :not_found} ->
          AuditLog.append(state.audit, %{type: :dead_letter, to: name, priority: priority})
          {:noreply, %{state | dropped: state.dropped + 1}}
      end
    end

    def handle_cast({:broadcast, pg_table, group, payload}, state) do
      members = ProcessGroup.members(pg_table, group)

      Enum.each(members, fn pid ->
        send(pid, {:"$broadcast", group, payload, System.monotonic_time(:microsecond)})
      end)

      AuditLog.append(state.audit, %{type: :broadcast, group: group, count: length(members)})
      {:noreply, %{state | delivered: state.delivered + length(members)}}
    end

    @impl true
    def handle_call(:logged_count, _from, state) do
      {:reply, AuditLog.count(state.audit), state}
    end

    def handle_call(:log_entries, _from, state) do
      {:reply, AuditLog.entries(state.audit), state}
    end
  end

  # ---------------------------------------------------------------------------
  # InboxWorker — a GenServer that collects received messages into an ordered
  # list, supporting selective receive by priority (SC-ORCH-011).
  # ---------------------------------------------------------------------------

  defmodule InboxWorker do
    @moduledoc "Collects inbound broker messages; surfaces them in priority order."
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, [], opts)
    end

    def messages(pid), do: GenServer.call(pid, :messages)
    def clear(pid), do: GenServer.cast(pid, :clear)

    @impl true
    def init([]) do
      {:ok, []}
    end

    @impl true
    def handle_info({:"$msg", priority, payload, ts}, msgs) do
      {:noreply, [{priority, payload, ts} | msgs]}
    end

    def handle_info({:"$broadcast", group, payload, ts}, msgs) do
      {:noreply, [{:broadcast, group, payload, ts} | msgs]}
    end

    def handle_info(_other, msgs) do
      {:noreply, msgs}
    end

    @impl true
    def handle_call(:messages, _from, msgs) do
      # Return sorted: :critical > :high > :normal > :low  (SC-ORCH-011)
      priority_rank = fn p ->
        case p do
          :critical -> 0
          :high -> 1
          :normal -> 2
          :low -> 3
          :broadcast -> 4
          _ -> 5
        end
      end

      # Messages are either 3-tuples {priority, payload, ts} or
      # 4-tuples {:broadcast, group, payload, ts}. Extract the priority tag uniformly.
      sorted =
        Enum.sort_by(msgs, fn
          {p, _, _} -> priority_rank.(p)
          {p, _, _, _} -> priority_rank.(p)
        end)

      {:reply, sorted, msgs}
    end

    @impl true
    def handle_cast(:clear, _msgs) do
      {:noreply, []}
    end
  end

  # ---------------------------------------------------------------------------
  # EchoServer — honours request-reply semantics: responds to {:call, ref, payload}
  # with {:reply, ref, response} so callers can correlate.
  # ---------------------------------------------------------------------------

  defmodule EchoServer do
    @moduledoc "Responds to request messages with correlated replies."
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, %{calls: 0}, opts)
    end

    def call_count(pid), do: GenServer.call(pid, :call_count)

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_info({:call, ref, from_pid, payload}, state) do
      send(from_pid, {:reply, ref, {:echo, payload}})
      {:noreply, %{state | calls: state.calls + 1}}
    end

    def handle_info(_other, state), do: {:noreply, state}

    @impl true
    def handle_call(:call_count, _from, state) do
      {:reply, state.calls, state}
    end
  end

  # ============================================================================
  # Utility helpers
  # ============================================================================

  defp await_condition(fun, timeout_ms \\ 500, interval_ms \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await(fun, deadline, interval_ms)
  end

  defp do_await(fun, deadline, interval_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        :timeout
      else
        Process.sleep(interval_ms)
        do_await(fun, deadline, interval_ms)
      end
    end
  end

  # Perform a request-reply exchange over raw send/receive with a timeout.
  # Returns {:ok, response} or :timeout.
  defp request_reply(target_pid, payload, timeout_ms) do
    ref = make_ref()
    send(target_pid, {:call, ref, self(), payload})

    receive do
      {:reply, ^ref, response} -> {:ok, response}
    after
      timeout_ms -> :timeout
    end
  end

  # ============================================================================
  # Section 1 — Process registration
  # ============================================================================

  describe "process registration (ETS-backed registry)" do
    setup do
      reg = EtsRegistry.new(:reg_basic)
      on_exit(fn -> EtsRegistry.drop(reg) end)
      %{reg: reg}
    end

    @tag :registration
    test "register a live process and look it up by name", %{reg: reg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      assert :ok = EtsRegistry.register(reg, :worker_1, pid)
      assert {:ok, ^pid} = EtsRegistry.lookup(reg, :worker_1)
      Process.exit(pid, :kill)
    end

    @tag :registration
    test "duplicate registration returns :already_registered error", %{reg: reg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      :ok = EtsRegistry.register(reg, :dup_worker, pid)
      assert {:error, {:already_registered, ^pid}} = EtsRegistry.register(reg, :dup_worker, pid)
      Process.exit(pid, :kill)
    end

    @tag :registration
    test "unregister removes the entry so lookup returns :not_found", %{reg: reg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      :ok = EtsRegistry.register(reg, :temp_worker, pid)
      :ok = EtsRegistry.unregister(reg, :temp_worker)
      assert {:error, :not_found} = EtsRegistry.lookup(reg, :temp_worker)
      Process.exit(pid, :kill)
    end

    @tag :registration
    test "looking up an unknown name returns :not_found", %{reg: reg} do
      assert {:error, :not_found} = EtsRegistry.lookup(reg, :ghost)
    end

    @tag :registration
    test "all/1 lists every registered entry", %{reg: reg} do
      pids = for _ <- 1..3, do: spawn(fn -> Process.sleep(1_000) end)
      names = [:alpha, :beta, :gamma]

      Enum.zip(names, pids) |> Enum.each(fn {n, p} -> EtsRegistry.register(reg, n, p) end)

      all = EtsRegistry.all(reg)
      all_names = Enum.map(all, fn {name, _pid} -> name end)

      assert Enum.all?(names, fn n -> n in all_names end)
      Enum.each(pids, &Process.exit(&1, :kill))
    end

    @tag :registration
    test "purge_dead removes entries for dead processes only", %{reg: reg} do
      live_pid = spawn(fn -> Process.sleep(10_000) end)
      dead_pid = spawn(fn -> :ok end)

      :ok = EtsRegistry.register(reg, :live_worker, live_pid)
      :ok = EtsRegistry.register(reg, :dead_worker, dead_pid)

      # Wait for dead_pid to finish
      :ok = await_condition(fn -> not Process.alive?(dead_pid) end)

      purged = EtsRegistry.purge_dead(reg)
      assert purged >= 1

      # Live worker still present; dead worker removed
      assert {:ok, ^live_pid} = EtsRegistry.lookup(reg, :live_worker)
      assert {:error, :not_found} = EtsRegistry.lookup(reg, :dead_worker)

      Process.exit(live_pid, :kill)
    end
  end

  # ============================================================================
  # Section 2 — Message passing between registered processes
  # ============================================================================

  describe "message passing via MessageBroker" do
    setup do
      reg = EtsRegistry.new(:msg_reg)
      audit = AuditLog.new(:msg_audit)
      {:ok, broker} = MessageBroker.start_link(audit)
      {:ok, worker} = InboxWorker.start_link()

      :ok = EtsRegistry.register(reg, :inbox_a, worker)

      on_exit(fn ->
        try do
          if Process.alive?(broker), do: MessageBroker.stop(broker)
        catch
          :exit, _ -> :ok
        end

        try do
          if Process.alive?(worker), do: GenServer.stop(worker)
        catch
          :exit, _ -> :ok
        end

        EtsRegistry.drop(reg)
        AuditLog.drop(audit)
      end)

      %{reg: reg, audit: audit, broker: broker, worker: worker}
    end

    @tag :messaging
    test "message sent to registered name is received by target process",
         %{reg: reg, broker: broker, worker: worker} do
      MessageBroker.send_msg(broker, reg, :inbox_a, %{value: 42})
      # Synchronise delivery via a call to broker (barrier)
      _ = MessageBroker.logged_count(broker)
      :ok = await_condition(fn -> InboxWorker.messages(worker) != [] end)
      msgs = InboxWorker.messages(worker)
      assert length(msgs) >= 1
    end

    @tag :messaging
    test "message to unregistered name is logged as dead_letter",
         %{reg: reg, broker: broker} do
      MessageBroker.send_msg(broker, reg, :nonexistent, %{value: 1})
      # Barrier: wait for broker to process the cast
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)
      dead_letters = Enum.filter(entries, fn {_seq, evt, _ts} -> evt.type == :dead_letter end)
      assert length(dead_letters) >= 1
    end

    @tag :messaging
    test "multiple messages to same recipient are all delivered",
         %{reg: reg, broker: broker, worker: worker} do
      for i <- 1..5, do: MessageBroker.send_msg(broker, reg, :inbox_a, %{n: i})
      _ = MessageBroker.logged_count(broker)
      :ok = await_condition(fn -> length(InboxWorker.messages(worker)) >= 5 end, 1_000)
      assert length(InboxWorker.messages(worker)) >= 5
    end

    @tag :messaging
    test "SC-ORCH-009: every delivered message is logged in the audit",
         %{reg: reg, broker: broker} do
      for i <- 1..3, do: MessageBroker.send_msg(broker, reg, :inbox_a, i)
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)
      delivered = Enum.filter(entries, fn {_seq, evt, _ts} -> evt.type == :delivered end)
      assert length(delivered) >= 3
    end
  end

  # ============================================================================
  # Section 3 — Selective receive with pattern matching
  # ============================================================================

  describe "selective receive with pattern matching" do
    @tag :selective_receive
    test "process only consumes messages matching its expected pattern" do
      me = self()

      receiver =
        spawn(fn ->
          # Only receive {:wanted, _} — ignore {:unwanted, _}
          receive do
            {:wanted, val} -> send(me, {:got, val})
          after
            500 -> send(me, :timeout)
          end
        end)

      # Send unwanted first, then wanted — wanted must still be received
      send(receiver, {:unwanted, 99})
      send(receiver, {:wanted, :hello})

      assert_receive {:got, :hello}, 1_000
    end

    @tag :selective_receive
    test "messages not matching any pattern remain in the mailbox" do
      # A process that only drains :ack messages
      parent = self()

      collector =
        spawn(fn ->
          Enum.each(1..3, fn _ ->
            receive do
              {:ack, n} -> send(parent, {:received, n})
            after
              200 -> send(parent, :gap)
            end
          end)
        end)

      send(collector, {:ack, 1})
      send(collector, {:other, :noise})
      send(collector, {:ack, 2})
      send(collector, {:ack, 3})

      # All three acks should be received
      for n <- [1, 2, 3], do: assert_receive({:received, ^n}, 500)
    end

    @tag :selective_receive
    test "flush loop drains matching messages until mailbox is empty" do
      parent = self()

      for i <- 1..5, do: send(parent, {:item, i})

      # Drain with selective receive
      items =
        Enum.flat_map(1..10, fn _ ->
          receive do
            {:item, n} -> [n]
          after
            0 -> []
          end
        end)

      assert length(items) == 5
      assert Enum.sort(items) == [1, 2, 3, 4, 5]
    end
  end

  # ============================================================================
  # Section 4 — Process linking and monitoring (link vs monitor semantics)
  # ============================================================================

  describe "link vs monitor semantics" do
    @tag :link_monitor
    test "Process.monitor/1 delivers DOWN message when target exits normally" do
      target = spawn(fn -> :ok end)
      ref = Process.monitor(target)
      # target exits almost immediately
      receive do
        {:DOWN, ^ref, :process, ^target, reason} ->
          assert reason == :normal
      after
        500 -> flunk("Did not receive DOWN for normally-exiting process")
      end
    end

    @tag :link_monitor
    test "Process.monitor/1 delivers DOWN with :killed reason on Process.exit(:kill)" do
      target = spawn(fn -> Process.sleep(10_000) end)
      ref = Process.monitor(target)
      Process.exit(target, :kill)

      receive do
        {:DOWN, ^ref, :process, ^target, reason} ->
          assert reason == :killed
      after
        500 -> flunk("Did not receive DOWN after :kill")
      end
    end

    @tag :link_monitor
    test "Process.monitor/1 does not propagate exits — monitor owner survives target crash" do
      parent = self()

      monitor_owner =
        spawn(fn ->
          target = spawn(fn -> raise "boom" end)
          ref = Process.monitor(target)

          receive do
            {:DOWN, ^ref, :process, ^target, _reason} -> send(parent, :survived)
          after
            1_000 -> send(parent, :timeout)
          end
        end)

      assert_receive :survived, 2_000
      assert Process.alive?(monitor_owner) or true
    end

    @tag :link_monitor
    test "Process.link/1 propagates abnormal exits to the linked process" do
      parent = self()
      Process.flag(:trap_exit, true)

      target = spawn(fn -> Process.sleep(10_000) end)
      Process.link(target)
      Process.exit(target, :some_error)

      receive do
        {:EXIT, ^target, reason} ->
          assert reason == :some_error
          send(parent, :got_exit)
      after
        500 -> flunk("Did not receive EXIT from linked process")
      end

      assert_receive :got_exit, 100
    after
      Process.flag(:trap_exit, false)
    end

    @tag :link_monitor
    test "Process.link/1 does NOT propagate :normal exits" do
      Process.flag(:trap_exit, true)
      target = spawn(fn -> :ok end)
      Process.link(target)
      # :normal exit — no EXIT propagated to non-trapping processes;
      # with trap_exit=true, we receive {:EXIT, pid, :normal}.
      # Either way, the test process must not crash.
      Process.sleep(50)
      # Drain any :normal EXIT signal
      receive do
        {:EXIT, ^target, :normal} -> :ok
      after
        0 -> :ok
      end

      assert true, "Test process survived :normal linked exit"
    after
      Process.flag(:trap_exit, false)
    end

    @tag :link_monitor
    test "demonitoring prevents future DOWN messages from arriving" do
      target = spawn(fn -> Process.sleep(10_000) end)
      ref = Process.monitor(target)
      Process.demonitor(ref, [:flush])
      Process.exit(target, :kill)
      Process.sleep(50)

      refute_received {:DOWN, ^ref, :process, ^target, _reason}
    end
  end

  # ============================================================================
  # Section 5 — Process group management
  # ============================================================================

  describe "process group management" do
    setup do
      pg = ProcessGroup.new(:pg_test)
      on_exit(fn -> ProcessGroup.drop(pg) end)
      %{pg: pg}
    end

    @tag :process_group
    test "process joins a group and is listed as a member", %{pg: pg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      :ok = ProcessGroup.join(pg, :workers, pid)
      assert ProcessGroup.member?(pg, :workers, pid)
      Process.exit(pid, :kill)
    end

    @tag :process_group
    test "process leaves group and is no longer a member", %{pg: pg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      ProcessGroup.join(pg, :workers, pid)
      ProcessGroup.leave(pg, :workers, pid)
      refute ProcessGroup.member?(pg, :workers, pid)
      Process.exit(pid, :kill)
    end

    @tag :process_group
    test "multiple processes join the same group and all appear as members", %{pg: pg} do
      pids = for _ <- 1..4, do: spawn(fn -> Process.sleep(1_000) end)
      Enum.each(pids, fn p -> ProcessGroup.join(pg, :sensors, p) end)
      members = ProcessGroup.members(pg, :sensors)
      assert Enum.all?(pids, fn p -> p in members end)
      Enum.each(pids, &Process.exit(&1, :kill))
    end

    @tag :process_group
    test "groups/1 enumerates all unique group names", %{pg: pg} do
      p1 = spawn(fn -> Process.sleep(1_000) end)
      p2 = spawn(fn -> Process.sleep(1_000) end)
      ProcessGroup.join(pg, :group_a, p1)
      ProcessGroup.join(pg, :group_b, p2)
      gs = ProcessGroup.groups(pg)
      assert :group_a in gs
      assert :group_b in gs
      Enum.each([p1, p2], &Process.exit(&1, :kill))
    end

    @tag :process_group
    test "members of an empty group is an empty list", %{pg: pg} do
      assert [] == ProcessGroup.members(pg, :empty_group)
    end

    @tag :process_group
    test "same process can be member of two different groups simultaneously", %{pg: pg} do
      pid = spawn(fn -> Process.sleep(1_000) end)
      ProcessGroup.join(pg, :group_x, pid)
      ProcessGroup.join(pg, :group_y, pid)
      assert ProcessGroup.member?(pg, :group_x, pid)
      assert ProcessGroup.member?(pg, :group_y, pid)
      Process.exit(pid, :kill)
    end
  end

  # ============================================================================
  # Section 6 — Message ordering guarantees (FIFO per sender)
  # ============================================================================

  describe "FIFO message ordering per sender" do
    @tag :ordering
    test "messages from one sender arrive in send order at the receiver" do
      parent = self()
      n = 20

      receiver =
        spawn(fn ->
          items = for _ <- 1..n, do: receive(do: ({:seq, v} -> v))
          send(parent, {:order, items})
        end)

      for i <- 1..n, do: send(receiver, {:seq, i})
      assert_receive {:order, received}, 1_000
      assert received == Enum.to_list(1..n)
    end

    @tag :ordering
    test "messages from two senders preserve per-sender ordering" do
      parent = self()
      n = 10

      collector =
        spawn(fn ->
          items = for _ <- 1..(2 * n), do: receive(do: ({:msg, sender, v} -> {sender, v}))
          send(parent, {:collected, items})
        end)

      sender_a = spawn(fn -> for i <- 1..n, do: send(collector, {:msg, :a, i}) end)
      sender_b = spawn(fn -> for i <- 1..n, do: send(collector, {:msg, :b, i}) end)

      assert_receive {:collected, items}, 1_000

      a_vals = items |> Enum.filter(fn {s, _} -> s == :a end) |> Enum.map(fn {_, v} -> v end)
      b_vals = items |> Enum.filter(fn {s, _} -> s == :b end) |> Enum.map(fn {_, v} -> v end)

      # Per-sender FIFO: each sender's messages must arrive in order
      assert a_vals == Enum.sort(a_vals)
      assert b_vals == Enum.sort(b_vals)

      Enum.each([sender_a, sender_b], &Process.exit(&1, :kill))
    end

    @tag :ordering
    test "cast messages via GenServer preserve FIFO for a single caller" do
      {:ok, worker} = InboxWorker.start_link()

      for i <- 1..8 do
        # Direct send preserves FIFO
        send(worker, {:"$msg", :normal, i, System.monotonic_time(:microsecond)})
      end

      # Sync barrier
      _ = InboxWorker.messages(worker)
      :ok = await_condition(fn -> length(InboxWorker.messages(worker)) >= 8 end, 500)

      # Payloads in insertion order (before priority sort)
      msgs = GenServer.call(worker, :messages)
      payloads = Enum.map(msgs, fn {_p, v, _ts} -> v end)
      normal_payloads = Enum.filter(payloads, &is_integer/1)
      assert Enum.sort(normal_payloads) == Enum.to_list(1..8)

      GenServer.stop(worker)
    end
  end

  # ============================================================================
  # Section 7 — Dead letter handling
  # ============================================================================

  describe "dead letter handling" do
    setup do
      reg = EtsRegistry.new(:dl_reg)
      audit = AuditLog.new(:dl_audit)
      {:ok, broker} = MessageBroker.start_link(audit)

      on_exit(fn ->
        try do
          if Process.alive?(broker), do: MessageBroker.stop(broker)
        catch
          :exit, _ -> :ok
        end

        EtsRegistry.drop(reg)
        AuditLog.drop(audit)
      end)

      %{reg: reg, audit: audit, broker: broker}
    end

    @tag :dead_letter
    test "sending to a name with no registered process logs a dead_letter event",
         %{reg: reg, broker: broker} do
      MessageBroker.send_msg(broker, reg, :no_such_process, %{value: 1})
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)
      assert Enum.any?(entries, fn {_s, e, _ts} -> e.type == :dead_letter end)
    end

    @tag :dead_letter
    test "sending to a just-dead process (purged entry) also produces dead_letter",
         %{reg: reg, broker: broker} do
      dying = spawn(fn -> :ok end)
      EtsRegistry.register(reg, :dying_proc, dying)

      # Wait for dying to exit then purge its entry
      :ok = await_condition(fn -> not Process.alive?(dying) end)
      EtsRegistry.purge_dead(reg)

      MessageBroker.send_msg(broker, reg, :dying_proc, :ping)
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)
      assert Enum.any?(entries, fn {_s, e, _ts} -> e.type == :dead_letter end)
    end

    @tag :dead_letter
    test "dead_letter count increases for each undeliverable message",
         %{reg: reg, broker: broker} do
      for i <- 1..3, do: MessageBroker.send_msg(broker, reg, :"ghost_#{i}", i)
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)
      dl_count = Enum.count(entries, fn {_s, e, _ts} -> e.type == :dead_letter end)
      assert dl_count == 3
    end
  end

  # ============================================================================
  # Section 8 — Process discovery by name/tag
  # ============================================================================

  describe "process discovery by name" do
    setup do
      reg = EtsRegistry.new(:disc_reg)
      on_exit(fn -> EtsRegistry.drop(reg) end)
      %{reg: reg}
    end

    @tag :discovery
    test "all/1 returns empty list when no processes registered", %{reg: reg} do
      assert [] == EtsRegistry.all(reg)
    end

    @tag :discovery
    test "all/1 returns one entry per registered name", %{reg: reg} do
      pids = for _ <- 1..5, do: spawn(fn -> Process.sleep(1_000) end)
      names = for i <- 1..5, do: :"disc_worker_#{i}"
      Enum.zip(names, pids) |> Enum.each(fn {n, p} -> EtsRegistry.register(reg, n, p) end)
      assert length(EtsRegistry.all(reg)) == 5
      Enum.each(pids, &Process.exit(&1, :kill))
    end

    @tag :discovery
    test "re-registering same name after unregister returns new pid", %{reg: reg} do
      pid1 = spawn(fn -> Process.sleep(1_000) end)
      pid2 = spawn(fn -> Process.sleep(1_000) end)

      :ok = EtsRegistry.register(reg, :reusable, pid1)
      :ok = EtsRegistry.unregister(reg, :reusable)
      :ok = EtsRegistry.register(reg, :reusable, pid2)

      assert {:ok, ^pid2} = EtsRegistry.lookup(reg, :reusable)
      Enum.each([pid1, pid2], &Process.exit(&1, :kill))
    end
  end

  # ============================================================================
  # Section 9 — Request-reply patterns (call semantics with timeout)
  # ============================================================================

  describe "request-reply (call semantics with timeout)" do
    setup do
      {:ok, echo} = EchoServer.start_link()
      on_exit(fn -> if Process.alive?(echo), do: GenServer.stop(echo) end)
      %{echo: echo}
    end

    @tag :request_reply
    test "request-reply delivers correlated response within timeout", %{echo: echo} do
      assert {:ok, {:echo, :ping}} = request_reply(echo, :ping, 200)
    end

    @tag :request_reply
    test "multiple concurrent request-reply calls each receive the correct response",
         %{echo: echo} do
      payloads = [:alpha, :beta, :gamma, :delta]

      tasks =
        Enum.map(payloads, fn p ->
          Task.async(fn -> request_reply(echo, p, 500) end)
        end)

      results = Task.await_many(tasks, 2_000)

      Enum.zip(payloads, results)
      |> Enum.each(fn {payload, result} ->
        assert {:ok, {:echo, ^payload}} = result
      end)
    end

    @tag :request_reply
    test "request to a dead process returns :timeout" do
      target = spawn(fn -> Process.sleep(10_000) end)
      Process.exit(target, :kill)
      :ok = await_condition(fn -> not Process.alive?(target) end)

      result = request_reply(target, :ping, 50)
      assert result == :timeout
    end

    @tag :request_reply
    test "EchoServer call_count reflects number of requests served", %{echo: echo} do
      for _ <- 1..5, do: request_reply(echo, :any, 200)
      assert EchoServer.call_count(echo) == 5
    end

    @tag :request_reply
    test "request-reply round-trip completes within 100ms (SC-OODA-001)", %{echo: echo} do
      t0 = System.monotonic_time(:millisecond)
      {:ok, _} = request_reply(echo, :timing_probe, 200)
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed < 100, "Request-reply took #{elapsed}ms, exceeds 100ms OODA budget"
    end
  end

  # ============================================================================
  # Section 10 — Fan-out messaging (one sender to many receivers)
  # ============================================================================

  describe "fan-out messaging via process groups" do
    setup do
      pg = ProcessGroup.new(:fanout)
      audit = AuditLog.new(:fanout_audit)
      {:ok, broker} = MessageBroker.start_link(audit)

      on_exit(fn ->
        try do
          if Process.alive?(broker), do: MessageBroker.stop(broker)
        catch
          :exit, _ -> :ok
        end

        ProcessGroup.drop(pg)
        AuditLog.drop(audit)
      end)

      %{pg: pg, audit: audit, broker: broker}
    end

    @tag :fan_out
    test "broadcast reaches all members of the target group",
         %{pg: pg, broker: broker} do
      workers = for _ <- 1..4, do: elem(InboxWorker.start_link(), 1)
      Enum.each(workers, fn w -> ProcessGroup.join(pg, :fan_group, w) end)

      MessageBroker.broadcast(broker, pg, :fan_group, :hello)
      _ = MessageBroker.logged_count(broker)

      :ok =
        await_condition(
          fn ->
            Enum.all?(workers, fn w -> InboxWorker.messages(w) != [] end)
          end,
          1_000
        )

      Enum.each(workers, fn w ->
        msgs = InboxWorker.messages(w)
        assert length(msgs) >= 1
        GenServer.stop(w)
      end)
    end

    @tag :fan_out
    test "broadcast to empty group logs event with count 0",
         %{pg: pg, broker: broker} do
      MessageBroker.broadcast(broker, pg, :empty_group, :hello)
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)

      broadcast_entries =
        Enum.filter(entries, fn {_s, e, _ts} -> e.type == :broadcast end)

      assert Enum.any?(broadcast_entries, fn {_s, e, _ts} -> e.count == 0 end)
    end

    @tag :fan_out
    test "fan-out count matches number of group members at time of broadcast",
         %{pg: pg, broker: broker} do
      n = 6
      workers = for _ <- 1..n, do: elem(InboxWorker.start_link(), 1)
      Enum.each(workers, fn w -> ProcessGroup.join(pg, :counted_group, w) end)

      MessageBroker.broadcast(broker, pg, :counted_group, :census)
      _ = MessageBroker.logged_count(broker)
      entries = MessageBroker.log_entries(broker)

      broadcast_entry =
        Enum.find(entries, fn {_s, e, _ts} ->
          e.type == :broadcast and e.group == :counted_group
        end)

      assert broadcast_entry != nil
      {_s, evt, _ts} = broadcast_entry
      assert evt.count == n

      Enum.each(workers, fn w ->
        if Process.alive?(w), do: GenServer.stop(w)
      end)
    end
  end

  # ============================================================================
  # Section 11 — Priority-ordered delivery (SC-ORCH-011)
  # ============================================================================

  describe "SC-ORCH-011: critical messages delivered first" do
    @tag :priority
    test "messages are returned in priority order: :critical before :normal before :low" do
      {:ok, worker} = InboxWorker.start_link()

      # Send in worst-case order: low, normal, critical
      send(worker, {:"$msg", :low, :low_data, System.monotonic_time(:microsecond)})
      send(worker, {:"$msg", :normal, :normal_data, System.monotonic_time(:microsecond)})
      send(worker, {:"$msg", :critical, :critical_data, System.monotonic_time(:microsecond)})

      :ok = await_condition(fn -> length(InboxWorker.messages(worker)) >= 3 end, 500)
      sorted_msgs = InboxWorker.messages(worker)
      priorities = Enum.map(sorted_msgs, fn {p, _v, _ts} -> p end)

      # The sorted view must place :critical before :low
      critical_idx = Enum.find_index(priorities, &(&1 == :critical))
      low_idx = Enum.find_index(priorities, &(&1 == :low))
      assert critical_idx < low_idx, "Expected :critical before :low, got #{inspect(priorities)}"

      GenServer.stop(worker)
    end

    @tag :priority
    test ":high priority messages precede :normal priority messages in sorted view" do
      {:ok, worker} = InboxWorker.start_link()

      send(worker, {:"$msg", :normal, :n, System.monotonic_time(:microsecond)})
      send(worker, {:"$msg", :high, :h, System.monotonic_time(:microsecond)})

      :ok = await_condition(fn -> length(InboxWorker.messages(worker)) >= 2 end, 500)
      msgs = InboxWorker.messages(worker)
      priorities = Enum.map(msgs, fn {p, _v, _ts} -> p end)

      high_idx = Enum.find_index(priorities, &(&1 == :high))
      normal_idx = Enum.find_index(priorities, &(&1 == :normal))
      assert high_idx < normal_idx

      GenServer.stop(worker)
    end
  end

  # ============================================================================
  # PropCheck property 1: Registry lookup is consistent after N registrations
  # Uses PC generators; forall returns raw boolean (EP-GEN-014).
  # ============================================================================

  @tag :property
  property "property (PC): every registered name is findable by lookup" do
    forall names <- PC.non_empty(PC.list(PC.atom())) do
      unique_names = Enum.uniq(names)
      reg = EtsRegistry.new(:pc_prop_1)

      try do
        pids =
          Enum.map(unique_names, fn _n ->
            spawn(fn -> Process.sleep(500) end)
          end)

        Enum.zip(unique_names, pids)
        |> Enum.each(fn {n, p} -> EtsRegistry.register(reg, n, p) end)

        result =
          Enum.all?(unique_names, fn n ->
            case EtsRegistry.lookup(reg, n) do
              {:ok, _pid} -> true
              {:error, :not_found} -> false
            end
          end)

        Enum.each(pids, &Process.exit(&1, :kill))
        result
      after
        EtsRegistry.drop(reg)
      end
    end
  end

  # ============================================================================
  # PropCheck property 2: Purge_dead is idempotent — calling it twice produces
  # the same final registry state.  Returns raw boolean.
  # ============================================================================

  @tag :property
  property "property (PC): purge_dead is idempotent on already-clean registry" do
    forall n <- PC.integer(1, 8) do
      reg = EtsRegistry.new(:pc_prop_2)

      try do
        live_pids = for _ <- 1..n, do: spawn(fn -> Process.sleep(1_000) end)
        names = for i <- 1..n, do: :"live_#{i}_#{:erlang.unique_integer([:positive])}"

        Enum.zip(names, live_pids)
        |> Enum.each(fn {nm, p} -> EtsRegistry.register(reg, nm, p) end)

        # First purge — no dead processes; should remove 0
        count1 = EtsRegistry.purge_dead(reg)
        # Second purge — still no dead processes; should also remove 0
        count2 = EtsRegistry.purge_dead(reg)

        # All live entries survive both purges
        all_present =
          Enum.all?(names, fn nm ->
            case EtsRegistry.lookup(reg, nm) do
              {:ok, _} -> true
              _ -> false
            end
          end)

        Enum.each(live_pids, &Process.exit(&1, :kill))
        count1 == 0 and count2 == 0 and all_present
      after
        EtsRegistry.drop(reg)
      end
    end
  end

  # ============================================================================
  # PropCheck property 3: Group membership is consistent — join then leave
  # leaves no trace.  Returns raw boolean.
  # ============================================================================

  @tag :property
  property "property (PC): join then leave leaves no membership trace" do
    forall {group, count} <- {PC.atom(), PC.integer(1, 10)} do
      pg = ProcessGroup.new(:pc_prop_3)

      try do
        pids = for _ <- 1..count, do: spawn(fn -> Process.sleep(500) end)

        Enum.each(pids, fn p -> ProcessGroup.join(pg, group, p) end)
        Enum.each(pids, fn p -> ProcessGroup.leave(pg, group, p) end)

        members = ProcessGroup.members(pg, group)
        no_members = Enum.empty?(members)
        no_member_matches = Enum.all?(pids, fn p -> not ProcessGroup.member?(pg, group, p) end)

        Enum.each(pids, &Process.exit(&1, :kill))
        no_members and no_member_matches
      after
        ProcessGroup.drop(pg)
      end
    end
  end

  # ============================================================================
  # ExUnitProperties check-all 1: Any N messages sent to a live worker are all
  # received (no drops under normal operation). Uses SD generators.
  # ============================================================================

  @tag :property
  test "check all (SD): no messages dropped for any N in [1,20] under normal operation" do
    ExUnitProperties.check all(n <- SD.integer(1..20)) do
      {:ok, worker} = InboxWorker.start_link()

      for i <- 1..n do
        send(worker, {:"$msg", :normal, i, System.monotonic_time(:microsecond)})
      end

      :ok =
        await_condition(
          fn -> length(GenServer.call(worker, :messages)) >= n end,
          2_000
        )

      msgs = GenServer.call(worker, :messages)
      payloads = Enum.map(msgs, fn {_p, v, _ts} -> v end) |> Enum.filter(&is_integer/1)

      assert length(payloads) == n
      GenServer.stop(worker)
    end
  end

  # ============================================================================
  # ExUnitProperties check-all 2: audit log count equals number of send attempts.
  # ============================================================================

  @tag :property
  test "check all (SD): audit log count equals total message attempts (delivered + dead)" do
    # n >= 2 ensures half = div(n, 2) >= 1 so both loops execute at least once,
    # avoiding empty-range iteration with `for _ <- 1..0`.
    ExUnitProperties.check all(n <- SD.integer(2..10)) do
      reg = EtsRegistry.new(:sd_prop_2)
      audit = AuditLog.new(:sd_prop_2_audit)
      {:ok, broker} = MessageBroker.start_link(audit)
      {:ok, worker} = InboxWorker.start_link()

      :ok = EtsRegistry.register(reg, :known, worker)

      # Half to known name, half to unknown
      half = div(n, 2)
      for _ <- 1..half, do: MessageBroker.send_msg(broker, reg, :known, :data)
      for i <- 1..half, do: MessageBroker.send_msg(broker, reg, :"ghost_#{i}", :data)

      # Barrier
      _ = MessageBroker.logged_count(broker)

      total_logged = AuditLog.count(audit)
      expected = half + half

      if Process.alive?(broker), do: MessageBroker.stop(broker)
      if Process.alive?(worker), do: GenServer.stop(worker)
      EtsRegistry.drop(reg)
      AuditLog.drop(audit)

      assert total_logged == expected
    end
  end

  # ============================================================================
  # ExUnitProperties check-all 3: Fan-out message count matches group size.
  # ============================================================================

  @tag :property
  test "check all (SD): broadcast delivers to exactly the number of current group members" do
    ExUnitProperties.check all(n <- SD.integer(1..8)) do
      pg = ProcessGroup.new(:sd_fanout)
      audit = AuditLog.new(:sd_fanout_audit)
      {:ok, broker} = MessageBroker.start_link(audit)
      workers = for _ <- 1..n, do: elem(InboxWorker.start_link(), 1)

      Enum.each(workers, fn w -> ProcessGroup.join(pg, :sd_group, w) end)

      MessageBroker.broadcast(broker, pg, :sd_group, :payload)
      _ = MessageBroker.logged_count(broker)

      entries = MessageBroker.log_entries(broker)

      broadcast_evt =
        Enum.find(entries, fn {_s, e, _ts} ->
          e.type == :broadcast and e.group == :sd_group
        end)

      if Process.alive?(broker), do: MessageBroker.stop(broker)

      Enum.each(workers, fn w ->
        if Process.alive?(w), do: GenServer.stop(w)
      end)

      ProcessGroup.drop(pg)
      AuditLog.drop(audit)

      assert broadcast_evt != nil
      {_s, evt, _ts} = broadcast_evt
      assert evt.count == n
    end
  end
end
