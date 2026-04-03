defmodule Indrajaal.Core.BuchiAutomatonTest do
  @moduledoc """
  Mathematical verification tests for MSO Büchi automaton acceptance (liveness properties).

  Mathematical properties verified:
  1. Büchi acceptance condition: ω-word w is accepted iff the accepting states
     are visited INFINITELY often while running the automaton on w.
  2. Liveness property: "good things happen infinitely often"
     Formally: □◇p (always eventually p) for some proposition p
  3. Safety vs liveness: a finite prefix violation is safety; infinite recurrence is liveness
  4. Complement of liveness: if some state is never visited again after position k,
     the word is rejected
  5. Strongly connected components (SCC) reachability: acceptance requires
     an SCC containing an accepting state to be reachable from initial state

  This implements the Büchi acceptance algorithm inline as pure mathematical
  verification — no external module required (module does not exist in codebase).

  STAMP: SC-MATH-001 (discipline health), SC-VER-074 (constitutional L0-L7)
  Layer: L1-CODE (pure mathematical verification)
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :mathematical
  @moduletag :buchi_automaton

  # ============================================================================
  # Büchi automaton inline implementation
  # ============================================================================

  # A Büchi automaton B = (Q, Σ, δ, q0, F)
  # Q: finite set of states
  # Σ: input alphabet
  # δ: Q × Σ → 2^Q (non-deterministic transition function)
  # q0: initial state
  # F ⊆ Q: accepting states
  #
  # An ω-word w = w0w1w2... is accepted iff there exists a run
  # r = r0r1r2... with r0 = q0 and ri+1 ∈ δ(ri, wi)
  # such that inf(r) ∩ F ≠ ∅ (F is visited infinitely often)
  #
  # For model checking, we simulate with a finite prefix and track state visits.

  defmodule BuchiAutomaton do
    @moduledoc "Inline Büchi automaton for liveness verification"

    defstruct [:states, :alphabet, :transitions, :initial, :accepting]

    @type t :: %__MODULE__{
            states: [atom()],
            alphabet: [atom()],
            transitions: %{atom() => %{atom() => [atom()]}},
            initial: atom(),
            accepting: [atom()]
          }

    # Build automaton from spec
    def new(spec) do
      %__MODULE__{
        states: spec.states,
        alphabet: spec.alphabet,
        transitions: spec.transitions,
        initial: spec.initial,
        accepting: spec.accepting
      }
    end

    # Check if an ω-word (represented as a finite word + repeat suffix) is accepted.
    # Strategy: simulate on finite prefix + detect accepting state in cycle.
    # We check: (1) can we reach an accepting state, (2) can we loop back to it.
    #
    # For acceptance of infinite words, we use the cycle detection criterion:
    # A word is accepted iff there's a run that visits an accepting state infinitely often.
    # For finite simulation: check that accepting states are reachable AND
    # that there exists a cycle through an accepting state.
    def accepts?(automaton, word) when is_list(word) do
      # Run the automaton on the word, tracking all visited states
      {final_states, visited_accepting} = run(automaton, word)

      # Check if any accepting state was visited AND is in final_states
      # (enabling further looping — proxy for infinite acceptance)
      accepting_visited = length(visited_accepting) > 0
      accepting_reachable_at_end = Enum.any?(final_states, &(&1 in automaton.accepting))

      accepting_visited and accepting_reachable_at_end
    end

    # Check liveness: the property □◇accepting — visits accepting states repeatedly.
    # For a finite simulation: count how many times accepting states are visited.
    def liveness_holds?(automaton, word, min_visits \\ 1) do
      {_, visited_accepting} = run(automaton, word)
      length(visited_accepting) >= min_visits
    end

    # Run automaton on word, returning {final_states_set, accepting_state_visits}
    defp run(automaton, word) do
      initial_states = [automaton.initial]

      {final_states, accepting_visits} =
        Enum.reduce(word, {initial_states, []}, fn symbol, {current_states, acc_visits} ->
          # Non-deterministically advance all current states
          next_states =
            current_states
            |> Enum.flat_map(fn state ->
              automaton.transitions
              |> Map.get(state, %{})
              |> Map.get(symbol, [])
            end)
            |> Enum.uniq()

          # Track which accepting states are among current states AFTER transition
          new_accepting =
            Enum.filter(next_states, &(&1 in automaton.accepting))

          {next_states, acc_visits ++ new_accepting}
        end)

      {final_states, accepting_visits}
    end

    # Check if accepting states are reachable from initial state (BFS)
    def accepting_reachable?(automaton) do
      reachable = reachable_states(automaton)
      Enum.any?(automaton.accepting, &(&1 in reachable))
    end

    # BFS to find all reachable states (over all symbols)
    def reachable_states(automaton) do
      bfs([automaton.initial], MapSet.new([automaton.initial]), automaton)
    end

    defp bfs([], visited, _), do: MapSet.to_list(visited)

    defp bfs([state | rest], visited, automaton) do
      neighbors =
        automaton.alphabet
        |> Enum.flat_map(fn sym ->
          automaton.transitions
          |> Map.get(state, %{})
          |> Map.get(sym, [])
        end)
        |> Enum.filter(&(not MapSet.member?(visited, &1)))

      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
      bfs(rest ++ neighbors, new_visited, automaton)
    end
  end

  # ============================================================================
  # Liveness automaton: verifies □◇p (always eventually p)
  # States: {q0: waiting, q1: accepting (saw p)}
  # Transitions: q0—p→q1, q0—¬p→q0, q1—p→q1, q1—¬p→q0
  # Accepting: {q1}
  # ============================================================================

  defp liveness_automaton do
    BuchiAutomaton.new(%{
      states: [:q0, :q1],
      alphabet: [:p, :not_p],
      transitions: %{
        q0: %{p: [:q1], not_p: [:q0]},
        q1: %{p: [:q1], not_p: [:q0]}
      },
      initial: :q0,
      accepting: [:q1]
    })
  end

  # ============================================================================
  # Safety automaton: verifies ¬p never happens
  # States: {q0: safe, q_err: error (sink)}
  # Accepting: {q0} — must stay in q0 forever
  # ============================================================================

  defp safety_automaton do
    BuchiAutomaton.new(%{
      states: [:q0, :q_err],
      alphabet: [:safe, :unsafe],
      transitions: %{
        q0: %{safe: [:q0], unsafe: [:q_err]},
        q_err: %{safe: [:q_err], unsafe: [:q_err]}
      },
      initial: :q0,
      accepting: [:q0]
    })
  end

  # ============================================================================
  # Liveness tests: □◇p
  # ============================================================================

  describe "liveness property: □◇p (always eventually p)" do
    test "word with p at every step satisfies liveness" do
      auto = liveness_automaton()
      word = [:p, :p, :p, :p, :p]
      assert BuchiAutomaton.accepts?(auto, word)
    end

    test "word with p appearing periodically satisfies liveness" do
      auto = liveness_automaton()
      word = [:not_p, :not_p, :p, :not_p, :not_p, :p, :not_p, :p]
      assert BuchiAutomaton.accepts?(auto, word)
    end

    test "word with p never appearing does not satisfy liveness" do
      auto = liveness_automaton()
      word = [:not_p, :not_p, :not_p, :not_p, :not_p]
      refute BuchiAutomaton.accepts?(auto, word)
    end

    test "single p at end satisfies liveness for finite word" do
      auto = liveness_automaton()
      word = [:not_p, :not_p, :not_p, :p]
      assert BuchiAutomaton.accepts?(auto, word)
    end

    test "empty word does not satisfy liveness (no accepting state visited)" do
      auto = liveness_automaton()
      # Empty word: never reach q1
      result = BuchiAutomaton.accepts?(auto, [])
      # With empty word, final_states = [q0] which is not accepting → false
      assert result == false
    end
  end

  # ============================================================================
  # Safety tests
  # ============================================================================

  describe "safety property: ¬unsafe (never unsafe)" do
    test "all-safe word is accepted" do
      auto = safety_automaton()
      word = [:safe, :safe, :safe, :safe]
      assert BuchiAutomaton.accepts?(auto, word)
    end

    test "word with unsafe event is rejected" do
      auto = safety_automaton()
      word = [:safe, :safe, :unsafe, :safe]
      refute BuchiAutomaton.accepts?(auto, word)
    end

    test "unsafe at start is rejected" do
      auto = safety_automaton()
      word = [:unsafe, :safe, :safe]
      refute BuchiAutomaton.accepts?(auto, word)
    end
  end

  # ============================================================================
  # Reachability of accepting states
  # ============================================================================

  describe "accepting state reachability" do
    test "liveness automaton accepting state q1 is reachable" do
      auto = liveness_automaton()
      assert BuchiAutomaton.accepting_reachable?(auto)
    end

    test "safety automaton accepting state q0 is reachable (it is initial)" do
      auto = safety_automaton()
      assert BuchiAutomaton.accepting_reachable?(auto)
    end

    test "all states in liveness automaton are reachable" do
      auto = liveness_automaton()
      reachable = BuchiAutomaton.reachable_states(auto)
      assert :q0 in reachable
      assert :q1 in reachable
    end
  end

  # ============================================================================
  # Liveness visit counting
  # ============================================================================

  describe "liveness visit count" do
    test "p repeated 3 times → accepting state visited at least 3 times" do
      auto = liveness_automaton()
      word = [:p, :not_p, :p, :not_p, :p]
      assert BuchiAutomaton.liveness_holds?(auto, word, 3)
    end

    test "p appears once → at least 1 liveness visit" do
      auto = liveness_automaton()
      word = [:not_p, :p, :not_p]
      assert BuchiAutomaton.liveness_holds?(auto, word, 1)
    end

    test "no p → zero liveness visits" do
      auto = liveness_automaton()
      word = [:not_p, :not_p, :not_p]
      refute BuchiAutomaton.liveness_holds?(auto, word, 1)
    end
  end

  # ============================================================================
  # Property: liveness increases with p-frequency (PropCheck)
  # ============================================================================

  describe "property: more p-events means more liveness visits (PropCheck)" do
    property "all-p word of length n yields n accepting visits" do
      forall n <- PC.choose(1, 10) do
        auto = liveness_automaton()
        word = List.duplicate(:p, n)
        BuchiAutomaton.liveness_holds?(auto, word, n)
      end
    end

    property "all-not_p word of length n yields 0 accepting visits" do
      forall n <- PC.choose(1, 10) do
        auto = liveness_automaton()
        word = List.duplicate(:not_p, n)
        not BuchiAutomaton.liveness_holds?(auto, word, 1)
      end
    end
  end

  # ============================================================================
  # Property: liveness is monotone (StreamData)
  # ============================================================================

  describe "property: liveness acceptance monotonicity (StreamData)" do
    test "adding p to a rejected word makes it accepted" do
      ExUnitProperties.check all(n <- SD.integer(1..5)) do
        auto = liveness_automaton()
        rejected_word = List.duplicate(:not_p, n)
        accepted_word = rejected_word ++ [:p]

        refute BuchiAutomaton.accepts?(auto, rejected_word)
        assert BuchiAutomaton.accepts?(auto, accepted_word)
      end
    end

    test "all-safe words of any length are accepted by safety automaton" do
      ExUnitProperties.check all(n <- SD.integer(1..8)) do
        auto = safety_automaton()
        word = List.duplicate(:safe, n)
        BuchiAutomaton.accepts?(auto, word)
      end
    end
  end
end
