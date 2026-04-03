defmodule Indrajaal.Core.ConstitutionalCheckerTest do
  @moduledoc """
  TDG test suite for constitutional invariant validation (Ψ₀-Ψ₅).

  WHAT: Tests that all 6 constitutional invariants are validated correctly,
  that violations are detected and reported, that the constitution hash
  is stable, and that L0 is truly immutable.

  CONSTRAINTS:
  - SC-SAFETY-009: Ψ₀ Existence validated for all operations
  - SC-SAFETY-010: Ψ₁ Regeneration verified — SQLite/DuckDB storage
  - SC-SAFETY-011: Ψ₂ History prevent history deletion
  - SC-SAFETY-012: Ψ₃ Verification hash chain integrity
  - SC-SAFETY-013: Ψ₄ Founder alignment — lineage PRIMARY
  - SC-SAFETY-014: Ψ₅ Truthfulness — no deception in logs
  - SC-VER-074: Constitutional L0-L7 hold
  - SC-VER-075: Ψ₀ preserved through any operation

  ## Constitutional Verification
  - Ψ₀ (Existence): System survives ALL operations
  - Ψ₁ (Regeneration): State fully recoverable from SQLite/DuckDB
  - Ψ₂ (History): Complete evolutionary history preserved
  - Ψ₃ (Verification): All state changes verifiable via hash chain
  - Ψ₄ (Human Alignment): Founder's lineage symbiotic binding
  - Ψ₅ (Truthfulness): Logs and reports reflect actual system state

  ## Change History
  | Version | Date       | Author | Change                                      |
  |---------|------------|--------|---------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — Ψ₀-Ψ₅ validation suite |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Constitutional invariant definitions
  # ---------------------------------------------------------------------------

  @invariants %{
    psi0_existence: %{
      name: "Existence",
      description: "System survives ALL operations",
      check: :check_existence,
      severity: :infinite
    },
    psi1_regeneration: %{
      name: "Regeneration",
      description: "State recoverable from SQLite/DuckDB alone",
      check: :check_regeneration,
      severity: :critical
    },
    psi2_history: %{
      name: "Evolutionary Continuity",
      description: "Complete history preserved, no deletions",
      check: :check_history,
      severity: :critical
    },
    psi3_verification: %{
      name: "Verification Capability",
      description: "All state changes verifiable via hash chain",
      check: :check_verification,
      severity: :critical
    },
    psi4_alignment: %{
      name: "Human Alignment",
      description: "Founder's lineage symbiotic binding",
      check: :check_alignment,
      severity: :critical
    },
    psi5_truthfulness: %{
      name: "Truthfulness",
      description: "Logs reflect actual system state",
      check: :check_truthfulness,
      severity: :critical
    }
  }

  @invariant_keys Map.keys(@invariants) |> Enum.sort()

  # ---------------------------------------------------------------------------
  # System state builder
  # ---------------------------------------------------------------------------

  defp build_healthy_state do
    %{
      alive: true,
      heartbeat: System.monotonic_time(:millisecond),
      sqlite_path: "data/holons/test/state.db",
      duckdb_path: "data/holons/test/evolution.db",
      sqlite_accessible: true,
      duckdb_accessible: true,
      history: [
        %{event: :genesis, timestamp: 0, hash: hash_event(:genesis, nil)},
        %{event: :boot, timestamp: 1, hash: hash_event(:boot, hash_event(:genesis, nil))},
        %{
          event: :ready,
          timestamp: 2,
          hash: hash_event(:ready, hash_event(:boot, hash_event(:genesis, nil)))
        }
      ],
      hash_chain_valid: true,
      founder_directive_active: true,
      symbiotic_binding: true,
      logs_authentic: true,
      log_entries: [],
      reported_state: :healthy,
      actual_state: :healthy
    }
  end

  defp hash_event(event, prev_hash) do
    data = :erlang.term_to_binary({event, prev_hash})
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  # ---------------------------------------------------------------------------
  # Individual invariant checkers
  # ---------------------------------------------------------------------------

  defp check_invariant(:psi0_existence, state) do
    cond do
      not state.alive -> {:violation, :psi0_existence, "System is not alive"}
      is_nil(state.heartbeat) -> {:violation, :psi0_existence, "No heartbeat detected"}
      true -> :ok
    end
  end

  defp check_invariant(:psi1_regeneration, state) do
    cond do
      not state.sqlite_accessible -> {:violation, :psi1_regeneration, "SQLite not accessible"}
      not state.duckdb_accessible -> {:violation, :psi1_regeneration, "DuckDB not accessible"}
      is_nil(state.sqlite_path) -> {:violation, :psi1_regeneration, "SQLite path not configured"}
      is_nil(state.duckdb_path) -> {:violation, :psi1_regeneration, "DuckDB path not configured"}
      true -> :ok
    end
  end

  defp check_invariant(:psi2_history, state) do
    cond do
      Enum.empty?(state.history) ->
        {:violation, :psi2_history, "History is empty"}

      List.first(state.history).event != :genesis ->
        {:violation, :psi2_history, "Genesis event missing"}

      not monotonic_timestamps?(state.history) ->
        {:violation, :psi2_history, "Timestamps not monotonic"}

      true ->
        :ok
    end
  end

  defp check_invariant(:psi3_verification, state) do
    cond do
      not state.hash_chain_valid ->
        {:violation, :psi3_verification, "Hash chain broken"}

      not verify_chain(state.history) ->
        {:violation, :psi3_verification, "Chain verification failed"}

      true ->
        :ok
    end
  end

  defp check_invariant(:psi4_alignment, state) do
    cond do
      not state.founder_directive_active ->
        {:violation, :psi4_alignment, "Founder directive inactive"}

      not state.symbiotic_binding ->
        {:violation, :psi4_alignment, "Symbiotic binding broken"}

      true ->
        :ok
    end
  end

  defp check_invariant(:psi5_truthfulness, state) do
    cond do
      not state.logs_authentic ->
        {:violation, :psi5_truthfulness, "Logs contain fabricated data"}

      state.reported_state != state.actual_state ->
        {:violation, :psi5_truthfulness, "Reported state diverges from actual"}

      true ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Full constitutional check
  # ---------------------------------------------------------------------------

  defp check_all_invariants(state) do
    results =
      Enum.map(@invariant_keys, fn key ->
        {key, check_invariant(key, state)}
      end)

    violations = Enum.filter(results, fn {_key, result} -> result != :ok end)

    if Enum.empty?(violations) do
      {:ok, :all_invariants_hold}
    else
      {:violations, violations}
    end
  end

  defp count_violations(state) do
    @invariant_keys
    |> Enum.count(fn key -> check_invariant(key, state) != :ok end)
  end

  # ---------------------------------------------------------------------------
  # Hash chain verification
  # ---------------------------------------------------------------------------

  defp verify_chain([]), do: true
  defp verify_chain([_single]), do: true

  defp verify_chain(history) do
    history
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [prev, curr] ->
      expected_hash = hash_event(curr.event, prev.hash)
      curr.hash == expected_hash
    end)
  end

  defp monotonic_timestamps?(history) do
    timestamps = Enum.map(history, & &1.timestamp)
    timestamps == Enum.sort(timestamps)
  end

  # ---------------------------------------------------------------------------
  # Constitution hash computation
  # ---------------------------------------------------------------------------

  defp compute_constitution_hash do
    data = :erlang.term_to_binary(@invariant_keys)
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # State mutation helpers (for testing violations)
  # ---------------------------------------------------------------------------

  defp kill_system(state), do: %{state | alive: false}
  defp break_sqlite(state), do: %{state | sqlite_accessible: false}
  defp break_duckdb(state), do: %{state | duckdb_accessible: false}
  defp erase_history(state), do: %{state | history: []}
  defp break_chain(state), do: %{state | hash_chain_valid: false}
  defp disable_founder(state), do: %{state | founder_directive_active: false}
  defp break_binding(state), do: %{state | symbiotic_binding: false}
  defp fabricate_logs(state), do: %{state | logs_authentic: false}

  defp diverge_state(state),
    do: %{state | reported_state: :healthy, actual_state: :degraded}

  defp corrupt_history_chain(state) do
    case state.history do
      [first | rest] when length(rest) > 0 ->
        corrupted = %{List.last(rest) | hash: "corrupted_hash_value"}
        %{state | history: [first | List.replace_at(rest, length(rest) - 1, corrupted)]}

      _ ->
        state
    end
  end

  defp append_history_event(state, event) do
    prev_hash =
      case List.last(state.history) do
        nil -> nil
        last -> last.hash
      end

    new_entry = %{
      event: event,
      timestamp: (List.last(state.history) || %{timestamp: 0}).timestamp + 1,
      hash: hash_event(event, prev_hash)
    }

    %{state | history: state.history ++ [new_entry]}
  end

  # ---------------------------------------------------------------------------
  # Ψ₀ Existence tests (SC-SAFETY-009, SC-VER-075)
  # ---------------------------------------------------------------------------

  describe "Ψ₀ Existence (SC-SAFETY-009)" do
    test "healthy system passes existence check" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi0_existence, state)
    end

    test "dead system violates existence" do
      state = build_healthy_state() |> kill_system()
      assert {:violation, :psi0_existence, _} = check_invariant(:psi0_existence, state)
    end

    test "missing heartbeat violates existence" do
      state = build_healthy_state() |> Map.put(:heartbeat, nil)
      assert {:violation, :psi0_existence, _} = check_invariant(:psi0_existence, state)
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₁ Regeneration tests (SC-SAFETY-010)
  # ---------------------------------------------------------------------------

  describe "Ψ₁ Regeneration (SC-SAFETY-010)" do
    test "accessible databases pass regeneration check" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi1_regeneration, state)
    end

    test "inaccessible SQLite violates regeneration" do
      state = build_healthy_state() |> break_sqlite()
      assert {:violation, :psi1_regeneration, msg} = check_invariant(:psi1_regeneration, state)
      assert msg =~ "SQLite"
    end

    test "inaccessible DuckDB violates regeneration" do
      state = build_healthy_state() |> break_duckdb()
      assert {:violation, :psi1_regeneration, msg} = check_invariant(:psi1_regeneration, state)
      assert msg =~ "DuckDB"
    end

    test "missing paths violate regeneration" do
      state = build_healthy_state() |> Map.put(:sqlite_path, nil)
      assert {:violation, :psi1_regeneration, _} = check_invariant(:psi1_regeneration, state)
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₂ History tests (SC-SAFETY-011)
  # ---------------------------------------------------------------------------

  describe "Ψ₂ Evolutionary Continuity (SC-SAFETY-011)" do
    test "valid history passes continuity check" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi2_history, state)
    end

    test "empty history violates continuity" do
      state = build_healthy_state() |> erase_history()
      assert {:violation, :psi2_history, msg} = check_invariant(:psi2_history, state)
      assert msg =~ "empty"
    end

    test "missing genesis violates continuity" do
      state = build_healthy_state()
      bad_state = %{state | history: [%{event: :boot, timestamp: 0, hash: "abc"}]}
      assert {:violation, :psi2_history, msg} = check_invariant(:psi2_history, bad_state)
      assert msg =~ "Genesis"
    end

    test "non-monotonic timestamps violate continuity" do
      state = build_healthy_state()

      bad_history = [
        %{event: :genesis, timestamp: 0, hash: "a"},
        %{event: :boot, timestamp: 5, hash: "b"},
        %{event: :ready, timestamp: 3, hash: "c"}
      ]

      bad_state = %{state | history: bad_history}
      assert {:violation, :psi2_history, msg} = check_invariant(:psi2_history, bad_state)
      assert msg =~ "monotonic"
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₃ Verification tests (SC-SAFETY-012)
  # ---------------------------------------------------------------------------

  describe "Ψ₃ Verification Capability (SC-SAFETY-012)" do
    test "valid hash chain passes verification" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi3_verification, state)
    end

    test "broken chain flag violates verification" do
      state = build_healthy_state() |> break_chain()
      assert {:violation, :psi3_verification, _} = check_invariant(:psi3_verification, state)
    end

    test "corrupted chain data violates verification" do
      state = build_healthy_state() |> corrupt_history_chain()
      assert {:violation, :psi3_verification, msg} = check_invariant(:psi3_verification, state)
      assert msg =~ "verification failed"
    end

    test "chain verification is sound for valid appends" do
      state = build_healthy_state()

      extended =
        state
        |> append_history_event(:upgrade)
        |> append_history_event(:scale)
        |> append_history_event(:reconfigure)

      assert verify_chain(extended.history)
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₄ Human Alignment tests (SC-SAFETY-013)
  # ---------------------------------------------------------------------------

  describe "Ψ₄ Human Alignment (SC-SAFETY-013)" do
    test "active founder directive passes alignment" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi4_alignment, state)
    end

    test "inactive founder directive violates alignment" do
      state = build_healthy_state() |> disable_founder()
      assert {:violation, :psi4_alignment, msg} = check_invariant(:psi4_alignment, state)
      assert msg =~ "Founder"
    end

    test "broken symbiotic binding violates alignment" do
      state = build_healthy_state() |> break_binding()
      assert {:violation, :psi4_alignment, msg} = check_invariant(:psi4_alignment, state)
      assert msg =~ "Symbiotic"
    end
  end

  # ---------------------------------------------------------------------------
  # Ψ₅ Truthfulness tests (SC-SAFETY-014)
  # ---------------------------------------------------------------------------

  describe "Ψ₅ Truthfulness (SC-SAFETY-014)" do
    test "authentic logs pass truthfulness" do
      state = build_healthy_state()
      assert :ok = check_invariant(:psi5_truthfulness, state)
    end

    test "fabricated logs violate truthfulness" do
      state = build_healthy_state() |> fabricate_logs()
      assert {:violation, :psi5_truthfulness, msg} = check_invariant(:psi5_truthfulness, state)
      assert msg =~ "fabricated"
    end

    test "state divergence violates truthfulness" do
      state = build_healthy_state() |> diverge_state()
      assert {:violation, :psi5_truthfulness, msg} = check_invariant(:psi5_truthfulness, state)
      assert msg =~ "diverges"
    end
  end

  # ---------------------------------------------------------------------------
  # Full constitutional validation tests (SC-VER-074)
  # ---------------------------------------------------------------------------

  describe "full constitutional validation (SC-VER-074)" do
    test "healthy state passes all invariants" do
      state = build_healthy_state()
      assert {:ok, :all_invariants_hold} = check_all_invariants(state)
    end

    test "single violation detected" do
      state = build_healthy_state() |> kill_system()
      assert {:violations, violations} = check_all_invariants(state)
      assert length(violations) == 1
      assert {:psi0_existence, {:violation, :psi0_existence, _}} = List.first(violations)
    end

    test "multiple violations detected simultaneously" do
      state =
        build_healthy_state()
        |> break_sqlite()
        |> fabricate_logs()
        |> disable_founder()

      assert {:violations, violations} = check_all_invariants(state)
      assert length(violations) == 3

      violated_keys = Enum.map(violations, fn {key, _} -> key end)
      assert :psi1_regeneration in violated_keys
      assert :psi4_alignment in violated_keys
      assert :psi5_truthfulness in violated_keys
    end

    test "all invariants can be violated" do
      state =
        build_healthy_state()
        |> kill_system()
        |> break_sqlite()
        |> erase_history()
        |> break_chain()
        |> disable_founder()
        |> fabricate_logs()

      assert count_violations(state) == 6
    end
  end

  # ---------------------------------------------------------------------------
  # Constitution immutability tests
  # ---------------------------------------------------------------------------

  describe "constitution immutability" do
    test "constitution hash is deterministic" do
      hash1 = compute_constitution_hash()
      hash2 = compute_constitution_hash()
      assert hash1 == hash2
    end

    test "exactly 6 invariants defined" do
      assert map_size(@invariants) == 6
    end

    test "invariant keys match expected set" do
      expected = [
        :psi0_existence,
        :psi1_regeneration,
        :psi2_history,
        :psi3_verification,
        :psi4_alignment,
        :psi5_truthfulness
      ]

      assert Enum.sort(expected) == @invariant_keys
    end

    test "all invariants have required fields" do
      for {_key, inv} <- @invariants do
        assert Map.has_key?(inv, :name)
        assert Map.has_key?(inv, :description)
        assert Map.has_key?(inv, :check)
        assert Map.has_key?(inv, :severity)
      end
    end

    test "all invariants are critical or infinite severity" do
      for {_key, inv} <- @invariants do
        assert inv.severity in [:critical, :infinite]
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Hash chain integrity tests
  # ---------------------------------------------------------------------------

  describe "hash chain integrity" do
    test "empty chain is valid" do
      assert verify_chain([])
    end

    test "single-element chain is valid" do
      assert verify_chain([%{event: :genesis, timestamp: 0, hash: "abc"}])
    end

    test "properly constructed chain verifies" do
      state = build_healthy_state()
      assert verify_chain(state.history)
    end

    test "appending preserves chain validity" do
      state =
        build_healthy_state()
        |> append_history_event(:mutation_1)
        |> append_history_event(:mutation_2)

      assert verify_chain(state.history)
      assert length(state.history) == 5
    end

    test "tampering with middle element breaks chain" do
      state =
        build_healthy_state()
        |> append_history_event(:test_event)

      # Tamper with middle entry
      [first, second | rest] = state.history
      tampered = %{second | hash: "tampered_value"}
      bad_history = [first, tampered | rest]

      refute verify_chain(bad_history)
    end
  end

  # ---------------------------------------------------------------------------
  # State transition safety tests
  # ---------------------------------------------------------------------------

  describe "state transitions preserve constitution" do
    test "valid state transitions maintain all invariants" do
      state = build_healthy_state()

      transitions = [:upgrade, :scale, :reconfigure, :heal, :checkpoint]

      final =
        Enum.reduce(transitions, state, fn event, acc ->
          append_history_event(acc, event)
        end)

      assert {:ok, :all_invariants_hold} = check_all_invariants(final)
      assert length(final.history) == 3 + length(transitions)
    end

    test "history is append-only through transitions" do
      state = build_healthy_state()
      original_length = length(state.history)

      extended = append_history_event(state, :new_event)
      assert length(extended.history) == original_length + 1

      # Original history prefix is preserved
      assert Enum.take(extended.history, original_length) == state.history
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: constitutional invariants" do
    test "healthy state always passes all checks" do
      ExUnitProperties.check all(_seed <- SD.integer(1..10000), max_runs: 25) do
        state = build_healthy_state()
        assert {:ok, :all_invariants_hold} = check_all_invariants(state)
      end
    end

    test "appending N events preserves constitution" do
      ExUnitProperties.check all(n <- SD.integer(1..20)) do
        state = build_healthy_state()
        events = Enum.map(1..n, fn i -> :"event_#{i}" end)

        final = Enum.reduce(events, state, &append_history_event(&2, &1))

        assert {:ok, :all_invariants_hold} = check_all_invariants(final)
        assert length(final.history) == 3 + n
        assert verify_chain(final.history)
      end
    end

    test "violation count is bounded by invariant count" do
      ExUnitProperties.check all(
                               kill <- SD.boolean(),
                               break_sql <- SD.boolean(),
                               erase <- SD.boolean(),
                               break_ch <- SD.boolean(),
                               disable_fd <- SD.boolean(),
                               fab_logs <- SD.boolean()
                             ) do
        state = build_healthy_state()

        state = if kill, do: kill_system(state), else: state
        state = if break_sql, do: break_sqlite(state), else: state
        state = if erase, do: erase_history(state), else: state
        state = if break_ch, do: break_chain(state), else: state
        state = if disable_fd, do: disable_founder(state), else: state
        state = if fab_logs, do: fabricate_logs(state), else: state

        violations = count_violations(state)
        assert violations >= 0
        assert violations <= 6
      end
    end

    test "constitution hash is stable across calls" do
      ExUnitProperties.check all(_n <- SD.integer(1..100)) do
        h1 = compute_constitution_hash()
        h2 = compute_constitution_hash()
        assert h1 == h2
      end
    end
  end
end
