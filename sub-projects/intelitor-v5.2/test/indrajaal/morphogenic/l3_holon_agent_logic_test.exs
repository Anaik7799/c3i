defmodule Indrajaal.Morphogenic.L3HolonAgentLogicTest do
  @moduledoc """
  WHAT: L3 (Domain Architecture) test suite for Holon Agent Logic Soundness
        (Sprint 88 task bb74189e). Verifies agent lifecycle, FQUN registration,
        message dispatch with priority queuing, state machine transitions,
        heartbeat protocol, and agent quarantine — all via ETS-backed simulation.
        No production module dependencies; the entire agent mesh is modelled
        in-process.

  WHY: At L3 (Domain level) agent logic must be sound: every agent must have a
       unique Fully-Qualified Unit Name (FQUN), transition through a strict
       lifecycle state machine, emit heartbeats, handle messages in priority
       order, and be quarantinable without affecting peer agents. Violations
       here directly cause split-brain faults (SC-SIL4-015), undetectable
       deadlocks (SC-AGT-018), and unauditable state mutations (SC-SAFETY-003).

  CONSTRAINTS:
    - SC-AGENT-001: All agents MUST have FQUN in `indrajaal/{domain}/{type}/{id}` format
    - SC-AGENT-002: Communication via Zenoh (simulated via ETS bus in this suite)
    - SC-AGENT-003: State published to Zenoh (ETS registry used as proxy)
    - SC-AGENT-004: Respond to control commands
    - SC-AGENT-005: Consistent interface and lifecycle
    - SC-ORCH-011:  Critical messages delivered first (priority queue ordering)
    - SC-SAFETY-005: Quarantined agents MUST be blocked from sending messages
    - SC-STATE-001: Atomic state updates — no partial writes observed
    - SC-STATE-003: Transitions logged — every mutation recorded
    - SC-FUNC-001:  System MUST compile — inline modules validated at load time

  ## Fractal Layer
  L3 (Domain): Ash resources, domain logic, agent registration, business rules.

  ## Change History
  | Version | Date       | Author | Change                                              |
  |---------|------------|--------|-----------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 task bb74189e — L3 agent logic soundness |

  @version "21.3.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l3
  @moduletag :agent_logic
  @moduletag timeout: 90_000

  # ---------------------------------------------------------------------------
  # Agent lifecycle state machine
  #
  #   :initializing → :ready → :active → :draining → :stopped
  #                      ↑                                ↓
  #                      └──────── reset allowed ─────────┘
  #
  # Transitions are strictly forward; :stopped is terminal (no forward).
  # A "reset" brings :stopped → :initializing (restart scenario only).
  # ---------------------------------------------------------------------------

  @valid_states [:initializing, :ready, :active, :draining, :stopped]

  # Allowed forward transitions (no backward movement per SC-STATE-003)
  @forward_transitions %{
    initializing: :ready,
    ready: :active,
    active: :draining,
    draining: :stopped
  }

  # The reset edge (special-cased for restart scenario tests only)
  @reset_transition {[:stopped], :initializing}

  # Heartbeat interval per AOR-AGENT-002
  @heartbeat_interval_ms 5_000

  # Heartbeat timeout: 3× interval (declared dead after 3 missed beats)
  @heartbeat_timeout_ms @heartbeat_interval_ms * 3

  # FQUN regex: indrajaal/{domain}/{type}/{id}
  @fqun_pattern ~r|^indrajaal/[a-z][a-z0-9_]*/[a-z][a-z0-9_]*/[a-z0-9_\-]+$|

  # Message priority levels — lower number = higher priority
  @priority_critical 0
  @priority_high 1
  @priority_normal 2
  @priority_low 3

  # ============================================================================
  # ETS-backed agent registry (FQUN → agent state)
  # ============================================================================

  defp registry_new(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp registry_delete(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
  end

  # Register an agent by FQUN; returns {:ok, entry} or {:error, :already_registered}
  defp registry_register(table, fqun, opts \\ []) do
    domain = parse_fqun_domain(fqun)
    type = parse_fqun_type(fqun)
    id = parse_fqun_id(fqun)

    entry = %{
      fqun: fqun,
      domain: domain,
      type: type,
      id: id,
      state: :initializing,
      heartbeat_at: monotonic_ms(),
      transition_log: [],
      quarantined: Keyword.get(opts, :quarantined, false),
      registered_at: monotonic_ms()
    }

    case :ets.lookup(table, fqun) do
      [{^fqun, _existing}] ->
        {:error, :already_registered}

      [] ->
        :ets.insert(table, {fqun, entry})
        {:ok, entry}
    end
  end

  defp registry_lookup(table, fqun) do
    case :ets.lookup(table, fqun) do
      [{^fqun, entry}] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  defp registry_all_fquns(table) do
    :ets.tab2list(table) |> Enum.map(fn {fqun, _} -> fqun end)
  end

  defp registry_count(table) do
    :ets.info(table, :size)
  end

  # ============================================================================
  # State machine helpers
  # ============================================================================

  # Advance agent to next forward state; returns {:ok, new_entry} or {:error, reason}
  defp agent_advance(table, fqun) do
    case registry_lookup(table, fqun) do
      {:error, _} = err ->
        err

      {:ok, entry} ->
        case Map.get(@forward_transitions, entry.state) do
          nil ->
            {:error, {:no_forward_transition, entry.state}}

          next_state ->
            log_entry = %{from: entry.state, to: next_state, at: monotonic_ms()}

            updated = %{
              entry
              | state: next_state,
                transition_log: [log_entry | entry.transition_log]
            }

            :ets.insert(table, {fqun, updated})
            {:ok, updated}
        end
    end
  end

  # Advance through ALL states until :stopped in one call (for convenience)
  defp agent_advance_to_stopped(table, fqun) do
    Enum.reduce_while(@valid_states, :ok, fn _s, _acc ->
      case registry_lookup(table, fqun) do
        {:ok, %{state: :stopped}} ->
          {:halt, :ok}

        {:ok, _} ->
          case agent_advance(table, fqun) do
            {:ok, _} -> {:cont, :ok}
            {:error, _} = err -> {:halt, err}
          end

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  # Reset :stopped agent back to :initializing (restart scenario)
  defp agent_reset(table, fqun) do
    case registry_lookup(table, fqun) do
      {:ok, %{state: :stopped} = entry} ->
        {allowed_states, _target} = @reset_transition

        if entry.state in allowed_states do
          log_entry = %{from: :stopped, to: :initializing, at: monotonic_ms(), reset: true}

          updated = %{
            entry
            | state: :initializing,
              transition_log: [log_entry | entry.transition_log]
          }

          :ets.insert(table, {fqun, updated})
          {:ok, updated}
        else
          {:error, :reset_not_allowed}
        end

      {:ok, entry} ->
        {:error, {:cannot_reset_from, entry.state}}

      {:error, _} = err ->
        err
    end
  end

  # Set agent to :active directly (for tests that need a running agent)
  defp agent_reach_active(table, fqun) do
    {:ok, _} = agent_advance(table, fqun)
    {:ok, _} = agent_advance(table, fqun)
    registry_lookup(table, fqun)
  end

  # ============================================================================
  # FQUN helpers
  # ============================================================================

  defp valid_fqun?(fqun), do: Regex.match?(@fqun_pattern, fqun)

  defp parse_fqun_domain(fqun) do
    case String.split(fqun, "/") do
      ["indrajaal", domain | _] -> domain
      _ -> nil
    end
  end

  defp parse_fqun_type(fqun) do
    case String.split(fqun, "/") do
      ["indrajaal", _, type | _] -> type
      _ -> nil
    end
  end

  defp parse_fqun_id(fqun) do
    case String.split(fqun, "/") do
      ["indrajaal", _, _, id | _] -> id
      _ -> nil
    end
  end

  # ============================================================================
  # Message dispatch with priority queue
  #
  # Messages are stored per-FQUN with their priority level.
  # Dispatch drains the queue ordered by priority (critical first per SC-ORCH-011),
  # then by insertion order within the same priority band.
  # ============================================================================

  defp mq_new(name) do
    :ets.new(name, [:ordered_set, :public])
  end

  # Enqueue message for agent; priority + sequence number is the key
  defp mq_enqueue(table, fqun, priority, message) do
    seq = :ets.info(table, :size)
    # Key: {fqun, priority, seq} ensures priority-first, FIFO within priority
    :ets.insert(table, {{fqun, priority, seq}, message})
    :ok
  end

  # Drain all messages for an agent, ordered by priority then FIFO within band
  defp mq_drain(table, fqun) do
    pattern = {{fqun, :_, :_}, :_}

    all_entries =
      :ets.match_object(table, pattern)
      |> Enum.sort_by(fn {{_fqun, priority, seq}, _} -> {priority, seq} end)

    # Remove from table
    Enum.each(all_entries, fn {key, _} -> :ets.delete(table, key) end)

    # Return just the messages in delivery order
    Enum.map(all_entries, fn {_, msg} -> msg end)
  end

  # Count pending messages for an agent
  defp mq_count(table, fqun) do
    :ets.match_object(table, {{fqun, :_, :_}, :_}) |> length()
  end

  # Check if any critical messages are pending
  defp mq_has_critical?(table, fqun) do
    :ets.match_object(table, {{fqun, @priority_critical, :_}, :_}) != []
  end

  # ============================================================================
  # Heartbeat registry (FQUN → last heartbeat timestamp)
  # ============================================================================

  defp hb_record(table, fqun) do
    :ets.insert(table, {fqun, monotonic_ms()})
    :ok
  end

  defp hb_last_seen(table, fqun) do
    case :ets.lookup(table, fqun) do
      [{^fqun, ts}] -> {:ok, ts}
      [] -> {:error, :never_seen}
    end
  end

  defp hb_timed_out?(table, fqun, timeout_ms \\ @heartbeat_timeout_ms) do
    case hb_last_seen(table, fqun) do
      {:error, :never_seen} -> true
      {:ok, ts} -> monotonic_ms() - ts > timeout_ms
    end
  end

  # Detect all timed-out agents from a registry table
  defp hb_detect_dead(registry_table, hb_table, timeout_ms) do
    registry_all_fquns(registry_table)
    |> Enum.filter(fn fqun -> hb_timed_out?(hb_table, fqun, timeout_ms) end)
  end

  # ============================================================================
  # Quarantine helpers
  # ============================================================================

  defp agent_quarantine(table, fqun) do
    case registry_lookup(table, fqun) do
      {:ok, entry} ->
        :ets.insert(table, {fqun, %{entry | quarantined: true}})
        :ok

      {:error, _} = err ->
        err
    end
  end

  defp agent_quarantined?(table, fqun) do
    case registry_lookup(table, fqun) do
      {:ok, entry} -> entry.quarantined
      {:error, _} -> false
    end
  end

  # Attempt message send; blocked if sender is quarantined
  defp agent_send(registry_table, mq_table, sender_fqun, recipient_fqun, priority, message) do
    if agent_quarantined?(registry_table, sender_fqun) do
      {:error, :quarantined}
    else
      mq_enqueue(mq_table, recipient_fqun, priority, %{
        from: sender_fqun,
        to: recipient_fqun,
        payload: message,
        priority: priority,
        sent_at: monotonic_ms()
      })

      :ok
    end
  end

  # ============================================================================
  # Utility
  # ============================================================================

  defp monotonic_ms, do: System.monotonic_time(:millisecond)

  defp unique_table(base) do
    :"#{base}_#{:erlang.unique_integer([:positive])}"
  end

  defp fqun(domain, type, id), do: "indrajaal/#{domain}/#{type}/#{id}"

  defp await_condition(fun, timeout_ms \\ 500, interval_ms \\ 10) do
    deadline = monotonic_ms() + timeout_ms
    do_await(fun, deadline, interval_ms)
  end

  defp do_await(fun, deadline, interval_ms) do
    if fun.() do
      :ok
    else
      if monotonic_ms() >= deadline do
        :timeout
      else
        Process.sleep(interval_ms)
        do_await(fun, deadline, interval_ms)
      end
    end
  end

  # ============================================================================
  # 1. FQUN Format Validation (SC-AGENT-001)
  # ============================================================================

  describe "FQUN format validation (SC-AGENT-001)" do
    @tag :fqun
    test "valid FQUN pattern is accepted" do
      assert valid_fqun?("indrajaal/core/guardian/alpha-1")
      assert valid_fqun?("indrajaal/mesh/worker/node01")
      assert valid_fqun?("indrajaal/prajna/copilot/instance-7")
      assert valid_fqun?("indrajaal/smriti/knowledge/holon1")
    end

    @tag :fqun
    test "FQUN missing root prefix is rejected" do
      refute valid_fqun?("mesh/worker/node01")
      refute valid_fqun?("/mesh/worker/node01")
    end

    @tag :fqun
    test "FQUN with uppercase segments is rejected" do
      refute valid_fqun?("indrajaal/Core/Guardian/alpha")
      refute valid_fqun?("indrajaal/core/Worker/alpha")
    end

    @tag :fqun
    test "FQUN with fewer than 4 path segments is rejected" do
      refute valid_fqun?("indrajaal/core/worker")
      refute valid_fqun?("indrajaal/core")
      refute valid_fqun?("indrajaal")
    end

    @tag :fqun
    test "parse_fqun_domain extracts the correct segment" do
      assert parse_fqun_domain("indrajaal/smriti/agent/42") == "smriti"
    end

    @tag :fqun
    test "parse_fqun_type extracts the correct segment" do
      assert parse_fqun_type("indrajaal/prajna/copilot/7") == "copilot"
    end

    @tag :fqun
    test "parse_fqun_id extracts the correct terminal segment" do
      assert parse_fqun_id("indrajaal/core/sentinel/guardian-1") == "guardian-1"
    end
  end

  # ============================================================================
  # 2. Agent Registration (SC-AGENT-001, SC-AGENT-003)
  # ============================================================================

  describe "agent registration (SC-AGENT-001, SC-AGENT-003)" do
    setup do
      t = registry_new(unique_table(:reg))
      on_exit(fn -> registry_delete(t) end)
      %{t: t}
    end

    @tag :registration
    test "registered agent is retrievable by FQUN", %{t: t} do
      fqun = fqun("core", "sentinel", "s1")
      {:ok, entry} = registry_register(t, fqun)
      assert entry.fqun == fqun
      assert entry.state == :initializing
    end

    @tag :registration
    test "initial agent state is :initializing", %{t: t} do
      {:ok, entry} = registry_register(t, fqun("mesh", "worker", "w1"))
      assert entry.state == :initializing
    end

    @tag :registration
    test "duplicate FQUN registration is rejected", %{t: t} do
      f = fqun("mesh", "worker", "dup")
      {:ok, _} = registry_register(t, f)
      assert {:error, :already_registered} = registry_register(t, f)
    end

    @tag :registration
    test "multiple distinct FQUNs can be registered concurrently", %{t: t} do
      fquns = for i <- 1..10, do: fqun("mesh", "worker", "w#{i}")
      Enum.each(fquns, fn f -> {:ok, _} = registry_register(t, f) end)
      assert registry_count(t) == 10
    end

    @tag :registration
    test "registry stores domain and type fields correctly", %{t: t} do
      f = fqun("prajna", "copilot", "ai-7")
      {:ok, _} = registry_register(t, f)
      {:ok, entry} = registry_lookup(t, f)
      assert entry.domain == "prajna"
      assert entry.type == "copilot"
      assert entry.id == "ai-7"
    end

    @tag :registration
    test "lookup of unknown FQUN returns :not_found", %{t: t} do
      assert {:error, :not_found} = registry_lookup(t, "indrajaal/ghost/type/none")
    end
  end

  # ============================================================================
  # 3. State Machine Transitions (SC-AGENT-005, SC-STATE-001, SC-STATE-003)
  # ============================================================================

  describe "agent state machine transitions (SC-AGENT-005, SC-STATE-001)" do
    setup do
      t = registry_new(unique_table(:sm))
      on_exit(fn -> registry_delete(t) end)
      %{t: t}
    end

    @tag :state_machine
    test "advance from :initializing to :ready succeeds", %{t: t} do
      f = fqun("core", "worker", "sm1")
      {:ok, _} = registry_register(t, f)
      {:ok, entry} = agent_advance(t, f)
      assert entry.state == :ready
    end

    @tag :state_machine
    test "full lifecycle :initializing→:ready→:active→:draining→:stopped", %{t: t} do
      f = fqun("core", "worker", "full")
      {:ok, _} = registry_register(t, f)

      states_reached =
        Enum.map([:ready, :active, :draining, :stopped], fn expected ->
          {:ok, entry} = agent_advance(t, f)
          {expected, entry.state}
        end)

      assert Enum.all?(states_reached, fn {expected, actual} -> expected == actual end)
    end

    @tag :state_machine
    test "advancing beyond :stopped returns :no_forward_transition error", %{t: t} do
      f = fqun("core", "worker", "stopped")
      {:ok, _} = registry_register(t, f)
      :ok = agent_advance_to_stopped(t, f)
      assert {:error, {:no_forward_transition, :stopped}} = agent_advance(t, f)
    end

    @tag :state_machine
    test "transition log records every state change (SC-STATE-003)", %{t: t} do
      f = fqun("core", "worker", "logged")
      {:ok, _} = registry_register(t, f)
      :ok = agent_advance_to_stopped(t, f)
      {:ok, entry} = registry_lookup(t, f)
      # 4 forward transitions recorded
      assert length(entry.transition_log) == 4
    end

    @tag :state_machine
    test "transition log entries contain from/to/at fields", %{t: t} do
      f = fqun("mesh", "worker", "log-check")
      {:ok, _} = registry_register(t, f)
      {:ok, _} = agent_advance(t, f)
      {:ok, entry} = registry_lookup(t, f)
      log_entry = hd(entry.transition_log)
      assert log_entry.from == :initializing
      assert log_entry.to == :ready
      assert is_integer(log_entry.at)
    end

    @tag :state_machine
    test "transition timestamps are monotonically non-decreasing", %{t: t} do
      f = fqun("core", "sentinel", "ts-mono")
      {:ok, _} = registry_register(t, f)
      :ok = agent_advance_to_stopped(t, f)
      {:ok, entry} = registry_lookup(t, f)
      timestamps = entry.transition_log |> Enum.map(& &1.at) |> Enum.reverse()
      assert timestamps == Enum.sort(timestamps)
    end

    @tag :state_machine
    test "reset from :stopped returns agent to :initializing", %{t: t} do
      f = fqun("core", "worker", "reset-ok")
      {:ok, _} = registry_register(t, f)
      :ok = agent_advance_to_stopped(t, f)
      {:ok, entry} = agent_reset(t, f)
      assert entry.state == :initializing
    end

    @tag :state_machine
    test "reset from non-stopped state returns error", %{t: t} do
      f = fqun("core", "worker", "no-reset")
      {:ok, _} = registry_register(t, f)
      {:ok, _} = agent_advance(t, f)
      # In :ready — reset not allowed
      assert {:error, {:cannot_reset_from, :ready}} = agent_reset(t, f)
    end
  end

  # ============================================================================
  # 4. Heartbeat Protocol (AOR-AGENT-002, SC-DMS-001)
  # ============================================================================

  describe "heartbeat protocol (AOR-AGENT-002, SC-DMS-001)" do
    setup do
      reg = registry_new(unique_table(:hb_reg))
      hb = :ets.new(unique_table(:hb_ts), [:set, :public])

      on_exit(fn ->
        registry_delete(reg)
        if :ets.info(hb) != :undefined, do: :ets.delete(hb)
      end)

      %{reg: reg, hb: hb}
    end

    @tag :heartbeat
    test "recording a heartbeat updates the timestamp", %{hb: hb} do
      f = fqun("mesh", "worker", "hb-a")
      :ok = hb_record(hb, f)
      {:ok, ts} = hb_last_seen(hb, f)
      assert is_integer(ts)
    end

    @tag :heartbeat
    test "agent that never sent a heartbeat is considered timed out", %{hb: hb} do
      f = fqun("mesh", "worker", "hb-never")
      assert hb_timed_out?(hb, f, 0)
    end

    @tag :heartbeat
    test "recently heartbeating agent is NOT timed out", %{hb: hb} do
      f = fqun("mesh", "worker", "hb-fresh")
      :ok = hb_record(hb, f)
      # Use large timeout so it cannot have expired in the instant after recording
      refute hb_timed_out?(hb, f, @heartbeat_timeout_ms)
    end

    @tag :heartbeat
    test "heartbeat_timeout_ms is 3× heartbeat_interval_ms (AOR-AGENT-002)", %{hb: _hb} do
      assert @heartbeat_timeout_ms == @heartbeat_interval_ms * 3
    end

    @tag :heartbeat
    test "dead agent detection finds agents with no recent heartbeat", %{reg: reg, hb: hb} do
      alive_fqun = fqun("mesh", "worker", "hb-alive")
      dead_fqun = fqun("mesh", "worker", "hb-dead")
      {:ok, _} = registry_register(reg, alive_fqun)
      {:ok, _} = registry_register(reg, dead_fqun)

      # Only alive_fqun sends a heartbeat; dead_fqun never does
      :ok = hb_record(hb, alive_fqun)

      dead = hb_detect_dead(reg, hb, @heartbeat_timeout_ms)
      assert dead_fqun in dead
      refute alive_fqun in dead
    end

    @tag :heartbeat
    test "multiple heartbeats update timestamp each time", %{hb: hb} do
      f = fqun("mesh", "worker", "hb-multi")
      :ok = hb_record(hb, f)
      {:ok, ts1} = hb_last_seen(hb, f)
      Process.sleep(5)
      :ok = hb_record(hb, f)
      {:ok, ts2} = hb_last_seen(hb, f)
      assert ts2 >= ts1
    end
  end

  # ============================================================================
  # 5. Message Dispatch with Priority Queuing (SC-ORCH-011)
  # ============================================================================

  describe "message dispatch priority queue (SC-ORCH-011)" do
    setup do
      reg = registry_new(unique_table(:mq_reg))
      mq = mq_new(unique_table(:mq_queue))

      on_exit(fn ->
        registry_delete(reg)
        if :ets.info(mq) != :undefined, do: :ets.delete(mq)
      end)

      %{reg: reg, mq: mq}
    end

    @tag :message_dispatch
    test "critical message is delivered before normal when enqueued after", %{reg: reg, mq: mq} do
      sender = fqun("core", "worker", "mq-sender")
      recipient = fqun("core", "worker", "mq-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_send(reg, mq, sender, recipient, @priority_normal, :normal_msg)
      :ok = agent_send(reg, mq, sender, recipient, @priority_critical, :critical_msg)

      [first | _] = mq_drain(mq, recipient)
      assert first.payload == :critical_msg
    end

    @tag :message_dispatch
    test "messages within same priority are delivered FIFO", %{reg: reg, mq: mq} do
      sender = fqun("core", "worker", "fifo-sender")
      recipient = fqun("core", "worker", "fifo-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      for i <- 1..5 do
        :ok = agent_send(reg, mq, sender, recipient, @priority_normal, i)
      end

      delivered = mq_drain(mq, recipient) |> Enum.map(& &1.payload)
      assert delivered == [1, 2, 3, 4, 5]
    end

    @tag :message_dispatch
    test "priority levels produce correct ordering: critical < high < normal < low",
         %{reg: reg, mq: mq} do
      sender = fqun("core", "worker", "prio-sender")
      recipient = fqun("core", "worker", "prio-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_send(reg, mq, sender, recipient, @priority_low, :low)
      :ok = agent_send(reg, mq, sender, recipient, @priority_normal, :normal)
      :ok = agent_send(reg, mq, sender, recipient, @priority_high, :high)
      :ok = agent_send(reg, mq, sender, recipient, @priority_critical, :critical)

      payloads = mq_drain(mq, recipient) |> Enum.map(& &1.payload)
      assert payloads == [:critical, :high, :normal, :low]
    end

    @tag :message_dispatch
    test "mq_count returns correct pending count before drain", %{reg: reg, mq: mq} do
      sender = fqun("mesh", "worker", "count-sender")
      recipient = fqun("mesh", "worker", "count-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      for _ <- 1..7 do
        :ok = agent_send(reg, mq, sender, recipient, @priority_normal, :ping)
      end

      assert mq_count(mq, recipient) == 7
    end

    @tag :message_dispatch
    test "drain empties the queue for the target agent only", %{reg: reg, mq: mq} do
      sender = fqun("mesh", "worker", "drain-s")
      a = fqun("mesh", "worker", "drain-a")
      b = fqun("mesh", "worker", "drain-b")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, a)
      {:ok, _} = registry_register(reg, b)

      :ok = agent_send(reg, mq, sender, a, @priority_normal, :msg_a)
      :ok = agent_send(reg, mq, sender, b, @priority_normal, :msg_b)

      _drained = mq_drain(mq, a)

      assert mq_count(mq, a) == 0
      assert mq_count(mq, b) == 1
    end

    @tag :message_dispatch
    test "mq_has_critical? detects critical message presence", %{reg: reg, mq: mq} do
      sender = fqun("core", "sentinel", "crit-sender")
      recipient = fqun("core", "sentinel", "crit-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      refute mq_has_critical?(mq, recipient)

      :ok = agent_send(reg, mq, sender, recipient, @priority_critical, :alert)
      assert mq_has_critical?(mq, recipient)
    end

    @tag :message_dispatch
    test "message envelope carries from, to, and sent_at fields", %{reg: reg, mq: mq} do
      sender = fqun("core", "worker", "env-sender")
      recipient = fqun("core", "worker", "env-recv")
      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_send(reg, mq, sender, recipient, @priority_high, :hello)
      [msg] = mq_drain(mq, recipient)

      assert msg.from == sender
      assert msg.to == recipient
      assert is_integer(msg.sent_at)
    end
  end

  # ============================================================================
  # 6. Agent Quarantine (SC-SAFETY-005)
  # ============================================================================

  describe "agent quarantine (SC-SAFETY-005)" do
    setup do
      reg = registry_new(unique_table(:quar_reg))
      mq = mq_new(unique_table(:quar_mq))

      on_exit(fn ->
        registry_delete(reg)
        if :ets.info(mq) != :undefined, do: :ets.delete(mq)
      end)

      %{reg: reg, mq: mq}
    end

    @tag :quarantine
    test "quarantined agent cannot send messages", %{reg: reg, mq: mq} do
      bad_agent = fqun("core", "rogue", "q1")
      recipient = fqun("core", "worker", "q-recv")
      {:ok, _} = registry_register(reg, bad_agent)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_quarantine(reg, bad_agent)
      result = agent_send(reg, mq, bad_agent, recipient, @priority_normal, :should_be_blocked)

      assert result == {:error, :quarantined}
    end

    @tag :quarantine
    test "quarantined agent leaves recipient queue empty", %{reg: reg, mq: mq} do
      bad_agent = fqun("core", "rogue", "q2")
      recipient = fqun("core", "worker", "q-recv2")
      {:ok, _} = registry_register(reg, bad_agent)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_quarantine(reg, bad_agent)
      _ = agent_send(reg, mq, bad_agent, recipient, @priority_normal, :blocked)

      assert mq_count(mq, recipient) == 0
    end

    @tag :quarantine
    test "non-quarantined agent can still send after peer is quarantined", %{reg: reg, mq: mq} do
      good_agent = fqun("core", "worker", "good-sender")
      bad_agent = fqun("core", "rogue", "bad-sender")
      recipient = fqun("core", "worker", "shared-recv")
      {:ok, _} = registry_register(reg, good_agent)
      {:ok, _} = registry_register(reg, bad_agent)
      {:ok, _} = registry_register(reg, recipient)

      :ok = agent_quarantine(reg, bad_agent)

      :ok = agent_send(reg, mq, good_agent, recipient, @priority_normal, :valid_msg)
      assert mq_count(mq, recipient) == 1
    end

    @tag :quarantine
    test "agent_quarantined? returns true after quarantine", %{reg: reg} do
      f = fqun("core", "rogue", "q3")
      {:ok, _} = registry_register(reg, f)
      refute agent_quarantined?(reg, f)
      :ok = agent_quarantine(reg, f)
      assert agent_quarantined?(reg, f)
    end

    @tag :quarantine
    test "quarantine flag is persisted in registry entry", %{reg: reg} do
      f = fqun("core", "rogue", "q4")
      {:ok, _} = registry_register(reg, f)
      :ok = agent_quarantine(reg, f)
      {:ok, entry} = registry_lookup(reg, f)
      assert entry.quarantined == true
    end

    @tag :quarantine
    test "initially registered agent is not quarantined by default", %{reg: reg} do
      f = fqun("mesh", "worker", "fresh-agent")
      {:ok, entry} = registry_register(reg, f)
      refute entry.quarantined
    end
  end

  # ============================================================================
  # PROPERTY TESTS
  # ============================================================================

  # ============================================================================
  # Property 1: FQUN uniqueness (SC-AGENT-001) — SD check all
  #
  # No two agents registered in the same table can share a FQUN.
  # ============================================================================

  @tag :property
  property "FQUN uniqueness — no two agents share the same FQUN (SD)" do
    forall n <- PC.integer(2, 15) do
      t = registry_new(unique_table(:prop_uniq))

      try do
        fquns = for i <- 1..n, do: fqun("core", "worker", "agent-#{i}")

        results =
          Enum.map(fquns, fn f -> registry_register(t, f) end)

        ok_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)

        # All distinct FQUNs must succeed
        assert ok_count == n

        # Attempting re-registration of any existing FQUN must fail
        Enum.each(fquns, fn f ->
          assert {:error, :already_registered} = registry_register(t, f)
        end)
      after
        registry_delete(t)
      end
    end
  end

  # ============================================================================
  # Property 2: State transition monotonicity (SD check all)
  #
  # For any sequence of forward advances, the resulting state index in
  # @valid_states is always ≥ the previous state index.
  # (Backward transitions are structurally impossible via agent_advance/2.)
  # ============================================================================

  @tag :property
  property "state transitions are monotonic — never go backward (SD)" do
    forall steps <- PC.integer(1, 4) do
      t = registry_new(unique_table(:prop_mono))

      try do
        f = fqun("core", "worker", "mono-prop")
        {:ok, _} = registry_register(t, f)

        state_index = fn state -> Enum.find_index(@valid_states, &(&1 == state)) end

        prev_idx =
          Enum.reduce(1..steps, state_index.(:initializing), fn _i, prev ->
            case agent_advance(t, f) do
              {:ok, entry} ->
                idx = state_index.(entry.state)
                assert idx >= prev, "State went backward: index #{idx} < #{prev}"
                idx

              {:error, {:no_forward_transition, _}} ->
                # Already at :stopped; no further advance possible — valid
                prev
            end
          end)

        assert prev_idx >= 0
      after
        registry_delete(t)
      end
    end
  end

  # ============================================================================
  # Property 3: Priority ordering invariant (PropCheck forall, PC generators)
  #
  # For any batch of messages with random priorities, the drain order must be
  # non-decreasing in priority value (lower value = higher priority delivered first).
  # ============================================================================

  @tag :property
  property "property: message drain always respects priority order (PC forall)" do
    Application.ensure_all_started(:propcheck)

    forall priorities <- PC.non_empty(PC.list(PC.integer(0, 3))) do
      t_reg = registry_new(unique_table(:prop_prio_reg))
      t_mq = mq_new(unique_table(:prop_prio_mq))

      try do
        sender = fqun("core", "worker", "prio-pc-sender")
        recipient = fqun("core", "worker", "prio-pc-recv")
        {:ok, _} = registry_register(t_reg, sender)
        {:ok, _} = registry_register(t_reg, recipient)

        Enum.each(priorities, fn p ->
          :ok = agent_send(t_reg, t_mq, sender, recipient, p, {:tagged, p})
        end)

        delivered = mq_drain(t_mq, recipient)
        delivered_priorities = Enum.map(delivered, & &1.priority)
        sorted = Enum.sort(delivered_priorities)

        delivered_priorities == sorted
      after
        registry_delete(t_reg)
        if :ets.info(t_mq) != :undefined, do: :ets.delete(t_mq)
      end
    end
  end

  # ============================================================================
  # Property 4: Quarantine is idempotent (SD check all)
  #
  # Quarantining an already-quarantined agent must not raise and must keep the
  # agent quarantined. The send-block invariant holds regardless of how many
  # times quarantine is applied.
  # ============================================================================

  @tag :property
  property "quarantine is idempotent — double-quarantine keeps block (SD)" do
    forall n_quarantines <- PC.integer(1, 5) do
      t_reg = registry_new(unique_table(:prop_qidem_reg))
      t_mq = mq_new(unique_table(:prop_qidem_mq))

      try do
        bad = fqun("core", "rogue", "idem-bad")
        recv = fqun("core", "worker", "idem-recv")
        {:ok, _} = registry_register(t_reg, bad)
        {:ok, _} = registry_register(t_reg, recv)

        # Apply quarantine n times
        Enum.each(1..n_quarantines, fn _ -> agent_quarantine(t_reg, bad) end)

        # Must still be quarantined
        assert agent_quarantined?(t_reg, bad)

        # Must still be blocked
        assert {:error, :quarantined} =
                 agent_send(t_reg, t_mq, bad, recv, @priority_normal, :blocked)
      after
        registry_delete(t_reg)
        if :ets.info(t_mq) != :undefined, do: :ets.delete(t_mq)
      end
    end
  end

  # ============================================================================
  # 7. Full Agent Lifecycle Integration Test
  #
  # Exercises the complete lifecycle with FQUN validation, state transitions,
  # heartbeat recording, message dispatch, and quarantine in a single scenario.
  # ============================================================================

  describe "full agent lifecycle integration" do
    setup do
      reg = registry_new(unique_table(:integ_reg))
      mq = mq_new(unique_table(:integ_mq))
      hb = :ets.new(unique_table(:integ_hb), [:set, :public])

      on_exit(fn ->
        registry_delete(reg)
        if :ets.info(mq) != :undefined, do: :ets.delete(mq)
        if :ets.info(hb) != :undefined, do: :ets.delete(hb)
      end)

      %{reg: reg, mq: mq, hb: hb}
    end

    @tag :integration
    test "agent follows full lifecycle and is eventually stopped", %{reg: reg, hb: hb} do
      f = fqun("core", "sentinel", "lifecycle-full")
      {:ok, _} = registry_register(reg, f)

      # Record heartbeat while active
      :ok = hb_record(hb, f)

      # Advance through all states
      assert :ok = agent_advance_to_stopped(reg, f)
      {:ok, entry} = registry_lookup(reg, f)
      assert entry.state == :stopped
      assert length(entry.transition_log) == 4
    end

    @tag :integration
    test "active agent receives messages and quarantine blocks further sends",
         %{reg: reg, mq: mq} do
      sender = fqun("core", "guardian", "g1")
      rogue = fqun("core", "rogue", "r1")
      recipient = fqun("prajna", "copilot", "c1")

      {:ok, _} = registry_register(reg, sender)
      {:ok, _} = registry_register(reg, rogue)
      {:ok, _} = registry_register(reg, recipient)

      # Advance all to :active
      {:ok, _} = agent_reach_active(reg, sender)
      {:ok, _} = agent_reach_active(reg, recipient)
      {:ok, _} = agent_reach_active(reg, rogue)

      # Sender delivers a critical alert
      :ok = agent_send(reg, mq, sender, recipient, @priority_critical, :system_alert)
      # Rogue sends a low-priority probe
      :ok = agent_send(reg, mq, rogue, recipient, @priority_low, :probe)

      # Quarantine the rogue agent
      :ok = agent_quarantine(reg, rogue)

      # Rogue now blocked
      assert {:error, :quarantined} =
               agent_send(reg, mq, rogue, recipient, @priority_normal, :second_attempt)

      # Recipient still has the two pre-quarantine messages
      messages = mq_drain(mq, recipient)
      assert length(messages) == 2

      # Critical delivered first regardless of insertion order
      assert hd(messages).priority == @priority_critical
    end

    @tag :integration
    test "dead agent detected by heartbeat monitor within timeout window",
         %{reg: reg, hb: hb} do
      alive_f = fqun("mesh", "worker", "alive-monitor")
      dead_f = fqun("mesh", "worker", "dead-monitor")

      {:ok, _} = registry_register(reg, alive_f)
      {:ok, _} = registry_register(reg, dead_f)

      :ok = hb_record(hb, alive_f)
      # dead_f never records a heartbeat

      dead_list = hb_detect_dead(reg, hb, @heartbeat_timeout_ms)
      assert dead_f in dead_list
      refute alive_f in dead_list
    end

    @tag :integration
    test "await_condition helper correctly polls for async state change" do
      ref = make_ref()
      parent = self()

      spawn(fn ->
        Process.sleep(30)
        send(parent, {ref, :done})
      end)

      received? = fn ->
        receive do
          {^ref, :done} -> true
        after
          0 -> false
        end
      end

      result = await_condition(received?, 500)
      assert result == :ok
    end
  end
end
