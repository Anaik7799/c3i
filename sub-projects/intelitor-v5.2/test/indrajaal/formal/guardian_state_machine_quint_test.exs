defmodule Indrajaal.Formal.GuardianStateMachineQuintTest do
  @moduledoc """
  Quint-style formal model of the Guardian state machine — TDG property tests.

  WHAT: Validates the Guardian's 5-state, 8-transition FSM against temporal,
        safety, liveness, and invariant properties derived from the Quint model.
        All helpers are self-contained; no production module dependencies.

  WHY: SC-GUARD-001 requires Guardian validation before any state mutation.
       SC-CONSENSUS-001 mandates 2oo3 voting for P0 decisions. Formal model
       verification ensures the Guardian itself cannot enter an inconsistent
       state under any input sequence. This is a TDG pre-implementation
       specification (Ω₄).

  CONSTRAINTS:
    SC-GUARD-001  — Guardian MUST use Envelope for constraint values
    SC-GUARD-002  — Guardian integrates with DeadMansSwitch, fail closed
    SC-GUARD-003  — Guardian integrates with FounderDirective
    SC-CONSENSUS-001 — 2oo3 voting MANDATORY for safety-critical decisions
    SC-SAFETY-001 — Guardian pre-approval REQUIRED for planning mutations
    SC-SIL6-001   — Agents SHALL NOT bypass Guardian
    EP-GEN-014    — PropCheck/StreamData generator disambiguation

  ## Guardian States
    :idle        — Waiting for proposals; default quiescent state
    :evaluating  — Proposal received, running validation + 2oo3 vote
    :approved    — Validation passed; execution authorised
    :vetoed      — Validation failed; proposal rejected
    :emergency   — Critical threat; fail-closed mode active

  ## Valid Transitions (8 total)
    idle        → evaluating   (proposal_submitted)
    evaluating  → approved     (validation_pass)
    evaluating  → vetoed       (validation_fail)
    evaluating  → emergency    (critical_threat)
    approved    → idle         (execution_complete)
    vetoed      → idle         (acknowledgement)
    emergency   → idle         (resolution)
    idle        → emergency    (direct_threat)

  ## Quint-style Properties Verified
    T1  — All 8 transitions reachable
    T2  — No invalid transition succeeds
    S1  — approved never directly reaches vetoed (safety boundary)
    S2  — emergency is reachable from any state
    L1  — evaluating always eventually reaches approved | vetoed | emergency
    L2  — system always eventually returns to idle
    I1  — transition table is deterministic
    I2  — state set is closed under valid transitions
    I3  — DeadMansSwitch semantics: unknown events → fail-closed (emergency)

  ## EP-GEN-014 compliance
    - `use PropCheck` intentionally omitted (Sprint 52): PropCheck.property contacts
      PropCheck.CounterStrike GenServer at compile time, causing failures when the
      application is not started. All property tests use ExUnitProperties instead.
    - `require ExUnitProperties` + `import ExUnitProperties, except: [property: 2, property: 3, check: 2]`
    - `SD.` prefix for all StreamData generators (alias StreamData, as: SD)
    - All StreamData calls use the fully-qualified `ExUnitProperties.check all(...)` form
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY import pattern
  # NOTE: `use PropCheck` intentionally omitted (Sprint 52 finding).
  # PropCheck.property macro contacts PropCheck.CounterStrike GenServer at compile
  # time via PropCheck.Properties.tag_property/1, which fails when the propcheck
  # application has not been started (parallel compiler, mix test without DB).
  # All property tests therefore use ExUnitProperties.check all() inside plain
  # `test` blocks. SD. prefix used throughout (EP-GEN-014 compliant).
  require ExUnitProperties
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias StreamData, as: SD

  @moduletag :formal
  @moduletag :guardian
  @moduletag :state_machine

  # ---------------------------------------------------------------------------
  # Quint model — pure data, no external dependencies
  # ---------------------------------------------------------------------------

  @states [:idle, :evaluating, :approved, :vetoed, :emergency]

  @events [
    :proposal_submitted,
    :validation_pass,
    :validation_fail,
    :critical_threat,
    :execution_complete,
    :acknowledgement,
    :resolution,
    :direct_threat
  ]

  # 8 valid transitions as {from_state, event, to_state}
  @valid_transitions [
    {:idle, :proposal_submitted, :evaluating},
    {:evaluating, :validation_pass, :approved},
    {:evaluating, :validation_fail, :vetoed},
    {:evaluating, :critical_threat, :emergency},
    {:approved, :execution_complete, :idle},
    {:vetoed, :acknowledgement, :idle},
    {:emergency, :resolution, :idle},
    {:idle, :direct_threat, :emergency}
  ]

  # ===========================================================================
  # Section 1 — Valid Transition Coverage (T1)
  # ===========================================================================

  describe "T1 — all 8 valid transitions are reachable" do
    test "idle → evaluating on proposal_submitted" do
      assert {:ok, :evaluating} = transition(:idle, :proposal_submitted)
    end

    test "evaluating → approved on validation_pass" do
      assert {:ok, :approved} = transition(:evaluating, :validation_pass)
    end

    test "evaluating → vetoed on validation_fail" do
      assert {:ok, :vetoed} = transition(:evaluating, :validation_fail)
    end

    test "evaluating → emergency on critical_threat" do
      assert {:ok, :emergency} = transition(:evaluating, :critical_threat)
    end

    test "approved → idle on execution_complete" do
      assert {:ok, :idle} = transition(:approved, :execution_complete)
    end

    test "vetoed → idle on acknowledgement" do
      assert {:ok, :idle} = transition(:vetoed, :acknowledgement)
    end

    test "emergency → idle on resolution" do
      assert {:ok, :idle} = transition(:emergency, :resolution)
    end

    test "idle → emergency on direct_threat" do
      assert {:ok, :emergency} = transition(:idle, :direct_threat)
    end

    test "exactly 8 transitions enumerable from the model" do
      assert length(@valid_transitions) == 8
    end

    test "each transition leads to a known state" do
      Enum.each(@valid_transitions, fn {_from, _event, to} ->
        assert to in @states, "Transition target #{inspect(to)} is not a valid state"
      end)
    end
  end

  # ===========================================================================
  # Section 2 — Invalid Transition Rejection (T2)
  # ===========================================================================

  describe "T2 — no invalid transitions succeed" do
    test "approved does not accept proposal_submitted" do
      assert {:error, :invalid_transition} = transition(:approved, :proposal_submitted)
    end

    test "vetoed does not accept validation_pass" do
      assert {:error, :invalid_transition} = transition(:vetoed, :validation_pass)
    end

    test "idle does not accept validation_pass" do
      assert {:error, :invalid_transition} = transition(:idle, :validation_pass)
    end

    test "idle does not accept validation_fail" do
      assert {:error, :invalid_transition} = transition(:idle, :validation_fail)
    end

    test "idle does not accept execution_complete" do
      assert {:error, :invalid_transition} = transition(:idle, :execution_complete)
    end

    test "emergency does not accept proposal_submitted" do
      assert {:error, :invalid_transition} = transition(:emergency, :proposal_submitted)
    end

    test "emergency does not accept validation_pass" do
      assert {:error, :invalid_transition} = transition(:emergency, :validation_pass)
    end

    test "approved does not accept critical_threat directly" do
      assert {:error, :invalid_transition} = transition(:approved, :critical_threat)
    end

    test "complete rejection matrix — all invalid (state, event) pairs rejected" do
      valid_pairs = MapSet.new(Enum.map(@valid_transitions, fn {s, e, _t} -> {s, e} end))

      all_pairs = for s <- @states, e <- @events, do: {s, e}
      invalid_pairs = Enum.reject(all_pairs, &MapSet.member?(valid_pairs, &1))

      Enum.each(invalid_pairs, fn {state, event} ->
        assert {:error, :invalid_transition} = transition(state, event),
               "Expected rejection for #{inspect(state)} + #{inspect(event)}"
      end)
    end

    test "PROP_T2 (StreamData): random (state, event) pairs not in model are rejected" do
      valid_set = MapSet.new(@valid_transitions)

      ExUnitProperties.check all(
                               state <- SD.member_of(@states),
                               event <- SD.member_of(@events)
                             ) do
        expected = expected_next(state, event)
        is_valid_transition = MapSet.member?(valid_set, {state, event, expected})

        unless is_valid_transition do
          assert {:error, :invalid_transition} = transition(state, event)
        end
      end
    end
  end

  # ===========================================================================
  # Section 3 — Safety Properties (S1, S2) — SC-GUARD-002
  # ===========================================================================

  describe "S1 — approved never directly reaches vetoed (safety boundary)" do
    test "no direct edge from approved to vetoed in transition table" do
      direct =
        Enum.filter(@valid_transitions, fn {from, _event, to} ->
          from == :approved and to == :vetoed
        end)

      assert direct == [], "Safety violation: direct approved→vetoed edge exists"
    end

    test "transition from approved on validation_fail is invalid" do
      assert {:error, :invalid_transition} = transition(:approved, :validation_fail)
    end

    test "the only path from approved back includes idle as intermediate" do
      reachable_in_one = reachable_in_steps(:approved, 1)

      refute :vetoed in reachable_in_one,
             "approved should not reach vetoed in one step"
    end

    test "PROP_S1 (StreamData): no single event takes approved directly to vetoed" do
      ExUnitProperties.check all(event <- SD.member_of(@events)) do
        case transition(:approved, event) do
          {:ok, :vetoed} ->
            flunk("Safety violation: approved + #{inspect(event)} → vetoed in one step")

          _ ->
            :ok
        end
      end
    end
  end

  describe "S2 — emergency reachable from any state (SC-GUARD-002 fail-closed)" do
    test "emergency reachable from idle in one step via direct_threat" do
      assert {:ok, :emergency} = transition(:idle, :direct_threat)
    end

    test "emergency reachable from evaluating in one step via critical_threat" do
      assert {:ok, :emergency} = transition(:evaluating, :critical_threat)
    end

    test "emergency reachable from approved within two steps" do
      {:ok, after_one} = transition(:approved, :execution_complete)
      assert after_one == :idle
      assert {:ok, :emergency} = transition(:idle, :direct_threat)
    end

    test "emergency reachable from vetoed within two steps" do
      {:ok, after_one} = transition(:vetoed, :acknowledgement)
      assert after_one == :idle
      assert {:ok, :emergency} = transition(:idle, :direct_threat)
    end

    test "emergency re-reachable from emergency via resolution → direct_threat" do
      {:ok, resolved} = transition(:emergency, :resolution)
      assert resolved == :idle
      assert {:ok, :emergency} = transition(:idle, :direct_threat)
    end

    test "max steps to reach emergency from any state is 2" do
      Enum.each(@states, fn state ->
        steps = min_steps_to_emergency(state)

        assert steps <= 2,
               "State #{inspect(state)} requires #{steps} steps to reach emergency (max 2)"
      end)
    end
  end

  # ===========================================================================
  # Section 4 — Liveness Properties (L1, L2)
  # ===========================================================================

  describe "L1 — evaluating always eventually reaches a terminal transition state" do
    @terminal_from_evaluating [:approved, :vetoed, :emergency]

    test "evaluating reaches approved via validation_pass" do
      {:ok, next} = transition(:evaluating, :validation_pass)
      assert next in @terminal_from_evaluating
    end

    test "evaluating reaches vetoed via validation_fail" do
      {:ok, next} = transition(:evaluating, :validation_fail)
      assert next in @terminal_from_evaluating
    end

    test "evaluating reaches emergency via critical_threat" do
      {:ok, next} = transition(:evaluating, :critical_threat)
      assert next in @terminal_from_evaluating
    end

    test "evaluating has no self-loop — it cannot remain evaluating" do
      remaining =
        Enum.filter(@valid_transitions, fn {from, _e, to} ->
          from == :evaluating and to == :evaluating
        end)

      assert remaining == [], "Liveness violation: evaluating has a self-loop"
    end

    test "all outgoing transitions from evaluating exit the state" do
      evaluating_transitions =
        Enum.filter(@valid_transitions, fn {from, _e, _to} -> from == :evaluating end)

      Enum.each(evaluating_transitions, fn {_from, event, to} ->
        refute to == :evaluating,
               "Liveness: evaluating + #{inspect(event)} loops back to evaluating"
      end)
    end

    test "PROP_L1 (StreamData): any valid event from evaluating exits the state" do
      valid_events_from_evaluating =
        @valid_transitions
        |> Enum.filter(fn {s, _e, _t} -> s == :evaluating end)
        |> Enum.map(fn {_s, e, _t} -> e end)

      ExUnitProperties.check all(event <- SD.member_of(valid_events_from_evaluating)) do
        case transition(:evaluating, event) do
          {:ok, :evaluating} ->
            flunk("Liveness violation: evaluating loops on #{inspect(event)}")

          {:ok, _other} ->
            :ok

          {:error, _} ->
            :ok
        end
      end
    end
  end

  describe "L2 — system always eventually returns to idle" do
    test "every non-idle terminal state has a direct path to idle" do
      assert {:ok, :idle} = transition(:approved, :execution_complete)
      assert {:ok, :idle} = transition(:vetoed, :acknowledgement)
      assert {:ok, :idle} = transition(:emergency, :resolution)
    end

    test "maximum path length from any state back to idle is bounded" do
      Enum.each(@states, fn state ->
        steps = min_steps_to_idle(state)

        assert steps != :unreachable,
               "State #{inspect(state)} cannot reach idle — liveness violated"

        assert steps <= 3,
               "State #{inspect(state)} requires #{steps} steps to reach idle (max 3)"
      end)
    end

    test "evaluating returns to idle in exactly 2 steps" do
      assert min_steps_to_idle(:evaluating) == 2
    end

    test "PROP_L2 (StreamData): any event sequence leaves system in state with path to idle" do
      ExUnitProperties.check all(
                               events <-
                                 SD.list_of(SD.member_of(@events), min_length: 0, max_length: 8)
                             ) do
        {final_state, _path} = simulate_trace(:idle, events)
        steps = min_steps_to_idle(final_state)

        assert final_state in @states

        assert steps != :unreachable,
               "Reached unreachable-from-idle state #{inspect(final_state)}"
      end
    end
  end

  # ===========================================================================
  # Section 5 — Invariants (I1, I2, I3)
  # ===========================================================================

  describe "I1 — transition function is deterministic" do
    test "same (state, event) always produces the same result" do
      Enum.each(@valid_transitions, fn {state, event, expected} ->
        assert {:ok, ^expected} = transition(state, event)
        # Idempotent second call
        assert {:ok, ^expected} = transition(state, event)
      end)
    end

    test "PROP_I1 (StreamData): transition is a pure function — identical on repeated calls" do
      ExUnitProperties.check all(
                               state <- SD.member_of(@states),
                               event <- SD.member_of(@events)
                             ) do
        r1 = transition(state, event)
        r2 = transition(state, event)
        assert r1 == r2, "Non-determinism detected: #{inspect(state)} + #{inspect(event)}"
      end
    end
  end

  describe "I2 — state set is closed under valid transitions" do
    test "every transition target is in the known state set" do
      Enum.each(@valid_transitions, fn {_from, _event, to} ->
        assert to in @states,
               "Transition leads outside state set: #{inspect(to)}"
      end)
    end

    test "all (state, event) combinations produce known states or error" do
      Enum.each(@states, fn state ->
        Enum.each(@events, fn event ->
          case transition(state, event) do
            {:ok, next_state} ->
              assert next_state in @states,
                     "Invalid target state #{inspect(next_state)}"

            {:error, :invalid_transition} ->
              :ok
          end
        end)
      end)
    end

    test "PROP_I2a (StreamData): reachable states always in declared state set" do
      ExUnitProperties.check all(
                               state <- SD.member_of(@states),
                               event <- SD.member_of(@events)
                             ) do
        case transition(state, event) do
          {:ok, next} -> assert next in @states
          {:error, :invalid_transition} -> :ok
        end
      end
    end

    test "PROP_I2b (StreamData): each state has 1–3 valid outgoing transitions" do
      ExUnitProperties.check all(state <- SD.member_of(@states)) do
        outgoing = Enum.count(@valid_transitions, fn {from, _e, _to} -> from == state end)

        assert outgoing >= 1,
               "State #{inspect(state)} has no outgoing transitions — deadlock risk"

        assert outgoing <= 3,
               "State #{inspect(state)} has #{outgoing} outgoing transitions — unexpected branching"
      end
    end
  end

  describe "I3 — DeadMansSwitch: unknown events cause fail-closed (emergency)" do
    test "unknown event from idle triggers fail-closed path to emergency" do
      assert transition_fail_closed(:idle, :unknown_event) == :emergency
    end

    test "unknown event from evaluating triggers fail-closed to emergency" do
      assert transition_fail_closed(:evaluating, :unknown_event) == :emergency
    end

    test "unknown event from approved triggers fail-closed to emergency" do
      assert transition_fail_closed(:approved, :unknown_event) == :emergency
    end

    test "unknown event from vetoed triggers fail-closed to emergency" do
      assert transition_fail_closed(:vetoed, :unknown_event) == :emergency
    end

    test "unknown event from emergency keeps state at emergency" do
      assert transition_fail_closed(:emergency, :unknown_event) == :emergency
    end

    test "PROP_I3 (StreamData): fail-closed always results in a valid state" do
      ExUnitProperties.check all(
                               state <- SD.member_of(@states),
                               event <- SD.atom(:alphanumeric)
                             ) do
        result = transition_fail_closed(state, event)
        assert result in @states
      end
    end
  end

  # ===========================================================================
  # Section 6 — Temporal Properties (trace-based, Quint-style)
  # ===========================================================================

  describe "temporal — trace-based verification of execution paths" do
    test "canonical approval trace: idle → evaluating → approved → idle" do
      trace = [:proposal_submitted, :validation_pass, :execution_complete]

      assert {:ok, [:idle, :evaluating, :approved, :idle]} = execute_trace(:idle, trace)
    end

    test "canonical veto trace: idle → evaluating → vetoed → idle" do
      trace = [:proposal_submitted, :validation_fail, :acknowledgement]

      assert {:ok, [:idle, :evaluating, :vetoed, :idle]} = execute_trace(:idle, trace)
    end

    test "emergency from proposal: idle → evaluating → emergency → idle" do
      trace = [:proposal_submitted, :critical_threat, :resolution]

      assert {:ok, [:idle, :evaluating, :emergency, :idle]} = execute_trace(:idle, trace)
    end

    test "direct emergency trace: idle → emergency → idle" do
      trace = [:direct_threat, :resolution]

      assert {:ok, [:idle, :emergency, :idle]} = execute_trace(:idle, trace)
    end

    test "repeated approval cycles begin and end at idle" do
      cycle = [:proposal_submitted, :validation_pass, :execution_complete]
      full_trace = cycle ++ cycle ++ cycle

      assert {:ok, states} = execute_trace(:idle, full_trace)
      assert List.first(states) == :idle
      assert List.last(states) == :idle
    end

    test "trace cannot skip evaluating — idle + validation_pass fails" do
      assert {:error, {:invalid_transition_at, 0, :idle, :validation_pass}} =
               execute_trace(:idle, [:validation_pass])
    end

    test "trace cannot jump from approved to vetoed" do
      # First reach :approved, then attempt :validation_fail — must be rejected
      # idle → evaluating (proposal_submitted) → approved (validation_pass) → ??? (validation_fail)
      assert {:error, {:invalid_transition_at, 2, :approved, :validation_fail}} =
               execute_trace(:idle, [:proposal_submitted, :validation_pass, :validation_fail])
    end

    test "PROP_TEMP1 (StreamData): any valid trace keeps all states in known set" do
      ExUnitProperties.check all(
                               event_sequence <-
                                 SD.list_of(SD.member_of(@events), min_length: 1, max_length: 10)
                             ) do
        {_final, path} = simulate_trace(:idle, event_sequence)

        Enum.each(path, fn state ->
          assert state in @states,
                 "Trace produced unknown state: #{inspect(state)}"
        end)
      end
    end

    test "PROP_TEMP2 (StreamData): traces from idle always end in a valid state" do
      ExUnitProperties.check all(
                               event_sequence <-
                                 SD.list_of(SD.member_of(@events), min_length: 0, max_length: 8)
                             ) do
        {final_state, _path} = simulate_trace(:idle, event_sequence)
        assert final_state in @states
      end
    end
  end

  # ===========================================================================
  # Section 7 — Completeness: transition table closure
  # ===========================================================================

  describe "completeness — FSM model closure" do
    test "exactly 8 valid transitions defined" do
      assert length(@valid_transitions) == 8
    end

    test "exactly 5 states defined" do
      assert length(@states) == 5
    end

    test "exactly 8 events defined" do
      assert length(@events) == 8
    end

    test "every event is used by at least one transition" do
      used_events = MapSet.new(Enum.map(@valid_transitions, fn {_s, e, _t} -> e end))

      Enum.each(@events, fn event ->
        assert MapSet.member?(used_events, event),
               "Event #{inspect(event)} is defined but never used"
      end)
    end

    test "transition relation is a function — (state, event) uniquely determines next state" do
      pairs = Enum.map(@valid_transitions, fn {s, e, _t} -> {s, e} end)
      unique_pairs = Enum.uniq(pairs)
      assert length(pairs) == length(unique_pairs), "Duplicate (state, event) pairs detected"
    end

    test "no orphaned states — every state is reachable from idle" do
      reachable = all_reachable_from(:idle)

      Enum.each(@states, fn state ->
        assert state in reachable,
               "State #{inspect(state)} is not reachable from :idle"
      end)
    end

    test "no sink states except by design — every state has at least one outgoing transition" do
      Enum.each(@states, fn state ->
        outgoing_count =
          Enum.count(@valid_transitions, fn {from, _e, _to} -> from == state end)

        assert outgoing_count >= 1,
               "State #{inspect(state)} is a deadlock sink"
      end)
    end
  end

  # ===========================================================================
  # Additional StreamData property tests (cross-cutting, not inside describe)
  # All use ExUnitProperties.check all() — no PropCheck macro required.
  # Sprint 52 note: PropCheck.property contacts CounterStrike at compile time;
  # using ExUnitProperties avoids that. PC alias = SD alias for documentation.
  # ===========================================================================

  test "PROP_T2a: random (state, event) pairs outside model are rejected" do
    valid_set = MapSet.new(@valid_transitions)

    ExUnitProperties.check all(
                             state <- SD.member_of(@states),
                             event <- SD.member_of(@events)
                           ) do
      expected = expected_next(state, event)
      is_valid = MapSet.member?(valid_set, {state, event, expected})

      unless is_valid do
        assert {:error, :invalid_transition} = transition(state, event)
      end
    end
  end

  test "PROP_S1: no single event takes approved directly to vetoed" do
    ExUnitProperties.check all(event <- SD.member_of(@events)) do
      case transition(:approved, event) do
        {:ok, :vetoed} ->
          flunk("Safety: approved + #{inspect(event)} → vetoed in one step")

        _ ->
          :ok
      end
    end
  end

  test "PROP_I1: transition deterministic — identical on repeated calls" do
    ExUnitProperties.check all(
                             state <- SD.member_of(@states),
                             event <- SD.member_of(@events)
                           ) do
      r1 = transition(state, event)
      r2 = transition(state, event)
      assert r1 == r2
    end
  end

  test "PROP_I3: unknown atom events cause fail-closed to a valid state" do
    ExUnitProperties.check all(
                             state <- SD.member_of(@states),
                             atom_ev <- SD.atom(:alphanumeric)
                           ) do
      result = transition_fail_closed(state, atom_ev)
      assert result in @states
    end
  end

  test "PROP_TEMP3: finite event sequences never produce unknown states" do
    ExUnitProperties.check all(events <- SD.list_of(SD.member_of(@events), max_length: 12)) do
      {final, path} = simulate_trace(:idle, events)
      assert final in @states
      assert Enum.all?(path, &(&1 in @states))
    end
  end

  test "PROP_L2: any event sequence leaves system with a path back to idle" do
    ExUnitProperties.check all(events <- SD.list_of(SD.member_of(@events), max_length: 10)) do
      {final, _path} = simulate_trace(:idle, events)
      assert min_steps_to_idle(final) != :unreachable
    end
  end

  # ===========================================================================
  # Private helpers — pure model functions, no production deps
  # ===========================================================================

  # Core transition function (strict — only valid transitions succeed).
  defp transition(state, event) do
    case Enum.find(@valid_transitions, fn {s, e, _t} -> s == state and e == event end) do
      {_s, _e, next_state} -> {:ok, next_state}
      nil -> {:error, :invalid_transition}
    end
  end

  # Fail-closed transition (SC-GUARD-002 DeadMansSwitch semantics).
  # Invalid or unknown events → :emergency.
  defp transition_fail_closed(state, event) do
    case transition(state, event) do
      {:ok, next} -> next
      {:error, :invalid_transition} -> :emergency
    end
  end

  # Execute an ordered list of events from a starting state.
  # Returns {:ok, [state_0, state_1, ...]} or
  # {:error, {:invalid_transition_at, index, state, event}}.
  defp execute_trace(initial_state, events) do
    result =
      Enum.reduce_while(
        Enum.with_index(events),
        [initial_state],
        fn {event, idx}, [current | _] = acc ->
          case transition(current, event) do
            {:ok, next} -> {:cont, [next | acc]}
            {:error, _} -> {:halt, {:error, {:invalid_transition_at, idx, current, event}}}
          end
        end
      )

    case result do
      {:error, _} = err -> err
      states when is_list(states) -> {:ok, Enum.reverse(states)}
    end
  end

  # Simulate a trace, leaving state unchanged on invalid events.
  # Returns {final_state, [all_visited_states_including_initial]}.
  defp simulate_trace(initial_state, events) do
    {final, reversed_path} =
      Enum.reduce(events, {initial_state, [initial_state]}, fn event, {state, path} ->
        case transition(state, event) do
          {:ok, next} -> {next, [next | path]}
          {:error, _} -> {state, path}
        end
      end)

    {final, Enum.reverse(reversed_path)}
  end

  # Returns MapSet of states reachable from `start` in exactly `n` steps.
  defp reachable_in_steps(start, n) do
    Enum.reduce(1..n, MapSet.new([start]), fn _step, frontier ->
      Enum.reduce(frontier, MapSet.new(), fn state, acc ->
        @valid_transitions
        |> Enum.filter(fn {s, _e, _t} -> s == state end)
        |> Enum.map(fn {_s, _e, t} -> t end)
        |> Enum.reduce(acc, &MapSet.put(&2, &1))
      end)
    end)
  end

  # BFS: minimum steps to reach :emergency from `start`.
  defp min_steps_to_emergency(:emergency), do: 0

  defp min_steps_to_emergency(start) do
    bfs([{start, 0}], MapSet.new([start]), :emergency)
  end

  # BFS: minimum steps to reach :idle from `start`.
  defp min_steps_to_idle(:idle), do: 0

  defp min_steps_to_idle(start) do
    bfs([{start, 0}], MapSet.new([start]), :idle)
  end

  # Generic BFS over the transition graph.
  defp bfs([], _visited, _target), do: :unreachable

  defp bfs([{state, dist} | rest], visited, target) do
    neighbors =
      @valid_transitions
      |> Enum.filter(fn {s, _e, _t} -> s == state end)
      |> Enum.map(fn {_s, _e, t} -> t end)

    case Enum.find(neighbors, &(&1 == target)) do
      nil ->
        new_entries =
          neighbors
          |> Enum.reject(&MapSet.member?(visited, &1))
          |> Enum.map(&{&1, dist + 1})

        new_visited =
          Enum.reduce(new_entries, visited, fn {s, _}, acc -> MapSet.put(acc, s) end)

        bfs(rest ++ new_entries, new_visited, target)

      _found ->
        dist + 1
    end
  end

  # BFS: all states reachable from `start` (used for orphan-state check).
  defp all_reachable_from(start) do
    do_reachable([start], MapSet.new([start]))
  end

  defp do_reachable([], visited), do: MapSet.to_list(visited)

  defp do_reachable([state | rest], visited) do
    neighbors =
      @valid_transitions
      |> Enum.filter(fn {s, _e, _t} -> s == state end)
      |> Enum.map(fn {_s, _e, t} -> t end)
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    do_reachable(rest ++ neighbors, new_visited)
  end

  # Returns the expected next state if the transition were valid.
  # Used only to classify (state, event) pairs — not as an assertion.
  defp expected_next(state, event) do
    case Enum.find(@valid_transitions, fn {s, e, _t} -> s == state and e == event end) do
      {_s, _e, t} -> t
      nil -> :__no_transition__
    end
  end
end
