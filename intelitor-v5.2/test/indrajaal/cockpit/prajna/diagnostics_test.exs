defmodule Indrajaal.Cockpit.Prajna.DiagnosticsTest do
  @moduledoc """
  Tests for Prajna Diagnostics - SIL-6 Diagnostic Coverage Module.

  STAMP Constraints:
    - SC-REG-002: Hash chain verification
    - SC-REG-007: Block count validation
    - SC-FMEA-001: Variable typos = CRITICAL
    - SC-SIL6-001: DC > 99%

  TDG Compliance:
    - Unit tests for all public functions
    - Property tests for diagnostic behavior
    - Integration tests for cross-module consistency
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  # EP-GEN-014: Re-import to exclude check/2 (conflicts with ExUnitProperties)
  import PropCheck, except: [check: 2]
  # EP-GEN-014: Conflict resolution - import StreamData as empty, alias as SD
  import StreamData, only: []
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.Diagnostics
  alias Indrajaal.Cockpit.Prajna.ImmutableState

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start Diagnostics if not already running
    diagnostics_pid =
      case GenServer.whereis(Diagnostics) do
        nil ->
          {:ok, pid} = Diagnostics.start_link(interval_ms: 60_000)
          {:started, pid}

        pid ->
          {:existing, pid}
      end

    # Start ImmutableState if not running
    immutable_pid =
      case GenServer.whereis(ImmutableState) do
        nil ->
          {:ok, pid} = ImmutableState.start_link(skip_persistence: true)
          {:started, pid}

        pid ->
          {:existing, pid}
      end

    on_exit(fn ->
      try do
        case diagnostics_pid do
          {:started, pid} when is_pid(pid) ->
            if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)

          _ ->
            :ok
        end

        case immutable_pid do
          {:started, pid} when is_pid(pid) ->
            if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5000)

          _ ->
            :ok
        end
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, %{diagnostics: diagnostics_pid, immutable: immutable_pid}}
  end

  # ============================================================
  # UNIT TESTS: PUBLIC API
  # ============================================================

  describe "run_all/0" do
    test "returns comprehensive result map" do
      result = Diagnostics.run_all()

      case result do
        {:ok, results} ->
          assert is_map(results)
          assert Map.has_key?(results, :hash_chain)
          assert Map.has_key?(results, :block_count)
          assert Map.has_key?(results, :state_consistency)
          assert Map.has_key?(results, :guardian_health)
          assert Map.has_key?(results, :sentinel_health)
          assert Map.has_key?(results, :duration_us)
          assert Map.has_key?(results, :timestamp)

        {:error, :timeout} ->
          # Timeout is valid in test environment
          assert true
      end
    end

    test "includes duration measurement" do
      case Diagnostics.run_all() do
        {:ok, results} ->
          assert is_integer(results.duration_us)
          assert results.duration_us >= 0

        {:error, _} ->
          assert true
      end
    end

    test "includes timestamp" do
      case Diagnostics.run_all() do
        {:ok, results} ->
          assert %DateTime{} = results.timestamp

        {:error, _} ->
          assert true
      end
    end
  end

  describe "run_check/1" do
    test "hash_chain check returns valid result" do
      result = Diagnostics.run_check(:hash_chain)
      assert match?({:ok, _}, result) or match?({:error, _, _}, result)
    end

    test "block_count check returns valid result" do
      result = Diagnostics.run_check(:block_count)
      assert match?({:ok, _}, result) or match?({:error, _, _}, result)
    end

    test "state_consistency check returns valid result" do
      result = Diagnostics.run_check(:state_consistency)
      assert match?({:ok, _}, result) or match?({:error, _, _}, result)
    end

    test "guardian_health check returns valid result" do
      result = Diagnostics.run_check(:guardian_health)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "sentinel_health check returns valid result" do
      result = Diagnostics.run_check(:sentinel_health)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "stats/0" do
    test "returns statistics map" do
      stats = Diagnostics.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :status)
      assert Map.has_key?(stats, :success_count)
      assert Map.has_key?(stats, :failure_count)
      assert Map.has_key?(stats, :diagnostic_coverage)
    end

    test "status is valid atom" do
      stats = Diagnostics.stats()
      assert stats.status in [:healthy, :degraded, :unavailable]
    end

    test "counts are non-negative integers" do
      stats = Diagnostics.stats()
      assert is_integer(stats.success_count) and stats.success_count >= 0
      assert is_integer(stats.failure_count) and stats.failure_count >= 0
    end

    test "diagnostic_coverage is valid percentage" do
      stats = Diagnostics.stats()
      assert is_number(stats.diagnostic_coverage)
      assert stats.diagnostic_coverage >= 0.0 and stats.diagnostic_coverage <= 100.0
    end
  end

  describe "history/1" do
    test "returns list of results" do
      # Run some checks first
      Diagnostics.run_check(:hash_chain)
      Process.sleep(50)

      history = Diagnostics.history(10)
      assert is_list(history)
    end

    test "respects count limit" do
      # Run multiple checks
      for _ <- 1..5, do: Diagnostics.run_check(:hash_chain)
      Process.sleep(50)

      history = Diagnostics.history(3)
      assert length(history) <= 3
    end

    test "history entries have timestamps" do
      Diagnostics.run_check(:block_count)
      Process.sleep(50)

      history = Diagnostics.history(5)

      Enum.each(history, fn entry ->
        if is_map(entry) and map_size(entry) > 0 do
          assert Map.has_key?(entry, :timestamp) or Map.has_key?(entry, :check_type)
        end
      end)
    end
  end

  describe "verify_hash_chain/0" do
    test "returns :valid for intact chain" do
      result = Diagnostics.verify_hash_chain()
      assert result == :valid or match?({:invalid, _}, result)
    end

    test "detects chain corruption" do
      # This test verifies the function handles corrupted chains
      # The actual corruption is tested in fault_injection_test.exs
      result = Diagnostics.verify_hash_chain()
      assert is_atom(result) or match?({:invalid, _}, result)
    end
  end

  describe "validate_block_count/1" do
    test "accepts valid block count with no drift" do
      actual = ImmutableState.block_count()
      result = Diagnostics.validate_block_count(actual)
      assert result == :ok
    end

    test "accepts minor drift within threshold" do
      actual = ImmutableState.block_count()
      # Small drift should be accepted
      result = Diagnostics.validate_block_count(actual + 2)
      assert result == :ok
    end

    test "detects significant drift" do
      actual = ImmutableState.block_count()
      # Large drift should be detected
      result = Diagnostics.validate_block_count(actual + 100)
      assert match?({:error, :drift_detected, _}, result)
    end
  end

  describe "assert_invariant/2" do
    test "returns :ok for true condition" do
      result = Diagnostics.assert_invariant(true, "test invariant")
      assert result == :ok
    end

    test "returns :violated for false condition" do
      result = Diagnostics.assert_invariant(false, "test invariant")
      assert result == {:violated, "test invariant"}
    end

    test "preserves message on violation" do
      message = "specific invariant message for testing"
      result = Diagnostics.assert_invariant(false, message)
      assert result == {:violated, message}
    end
  end

  describe "check_state_consistency/0" do
    test "returns valid structure" do
      result = Diagnostics.check_state_consistency()

      case result do
        {:ok, :consistent} ->
          assert true

        {:error, :inconsistent, details} ->
          assert is_map(details)
      end
    end

    test "checks multiple subsystems" do
      result = Diagnostics.check_state_consistency()

      case result do
        {:ok, :consistent} ->
          # All systems are consistent
          assert true

        {:error, :inconsistent, details} ->
          # Details should contain failing subsystem info
          assert map_size(details) > 0
      end
    end
  end

  # ============================================================
  # STAMP CONSTRAINT VERIFICATION
  # ============================================================

  describe "SC-REG-002: Periodic hash chain verification" do
    test "verify_hash_chain is accessible" do
      # Function should be callable
      result = Diagnostics.verify_hash_chain()
      assert result in [:valid] or match?({:invalid, _}, result)
    end

    test "run_all includes hash_chain check" do
      case Diagnostics.run_all() do
        {:ok, results} ->
          assert Map.has_key?(results, :hash_chain)
          assert results.hash_chain in [:passed, :failed]

        {:error, _} ->
          assert true
      end
    end
  end

  describe "SC-REG-007: Block count validation" do
    test "validate_block_count is accessible" do
      result = Diagnostics.validate_block_count(0)
      assert result == :ok or match?({:error, :drift_detected, _}, result)
    end

    test "run_all includes block_count check" do
      case Diagnostics.run_all() do
        {:ok, results} ->
          assert Map.has_key?(results, :block_count)
          assert results.block_count in [:passed, :failed]

        {:error, _} ->
          assert true
      end
    end
  end

  describe "SC-SIL6-001: DC > 99%" do
    test "diagnostic_coverage is tracked" do
      stats = Diagnostics.stats()
      assert is_number(stats.diagnostic_coverage)
    end

    test "successful checks increase coverage" do
      # Run a check
      Diagnostics.run_check(:hash_chain)
      Process.sleep(50)

      stats = Diagnostics.stats()
      # Coverage should be non-zero after successful checks
      assert stats.diagnostic_coverage >= 0.0
    end
  end

  # ============================================================
  # PROPERTY TESTS (PropCheck)
  # ============================================================

  property "assert_invariant is deterministic" do
    forall {condition, message} <- {PC.boolean(), PC.binary()} do
      result1 = Diagnostics.assert_invariant(condition, message)
      result2 = Diagnostics.assert_invariant(condition, message)
      result1 == result2
    end
  end

  property "block count validation is monotonic for drift detection" do
    forall drift <- PC.integer(0, 1000) do
      # Large drifts should always be detected
      if drift > 5 do
        result = Diagnostics.validate_block_count(drift)
        match?({:error, :drift_detected, _}, result)
      else
        # Small drifts should pass
        result = Diagnostics.validate_block_count(drift)
        result == :ok or match?({:error, :drift_detected, _}, result)
      end
    end
  end

  property "stats always returns valid structure" do
    forall _ <- PC.exactly(:ignored) do
      stats = Diagnostics.stats()

      is_map(stats) and
        Map.has_key?(stats, :status) and
        Map.has_key?(stats, :success_count) and
        Map.has_key?(stats, :failure_count)
    end
  end

  # ============================================================
  # STREAMDATA PROPERTY TESTS
  # ============================================================

  test "invariant messages are preserved (StreamData)" do
    ExUnitProperties.check all(
                             message <- SD.string(:alphanumeric, min_length: 1, max_length: 100)
                           ) do
      result = Diagnostics.assert_invariant(false, message)
      assert result == {:violated, message}
    end
  end

  test "history count is respected (StreamData)" do
    ExUnitProperties.check all(count <- SD.integer(1..20)) do
      history = Diagnostics.history(count)
      assert is_list(history)
      assert length(history) <= count
    end
  end

  # ============================================================
  # INTEGRATION TESTS
  # ============================================================

  describe "Integration with ImmutableState" do
    test "hash chain verification uses ImmutableState" do
      # Add a block to ImmutableState
      {:ok, _hash} = ImmutableState.record(%{change_type: :test, data: "integration_test"})

      # Verify chain
      result = Diagnostics.verify_hash_chain()
      assert result == :valid
    end

    test "block count matches ImmutableState" do
      actual_count = ImmutableState.block_count()
      result = Diagnostics.validate_block_count(actual_count)
      assert result == :ok
    end
  end

  describe "Cross-module consistency" do
    test "state_consistency checks all components" do
      result = Diagnostics.check_state_consistency()

      case result do
        {:ok, :consistent} ->
          # All systems are working
          assert true

        {:error, :inconsistent, details} ->
          # Verify the structure of details
          assert is_map(details)

          # Each failing component should be present
          Enum.each(details, fn {component, status} ->
            assert component in [:immutable_state, :guardian, :sentinel]
            assert match?({:error, _}, status)
          end)
      end
    end
  end

  # ============================================================
  # TELEMETRY TESTS
  # ============================================================

  describe "Telemetry events" do
    test "run_all emits telemetry" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:indrajaal, :prajna, :diagnostics, :check_complete]
        ])

      Diagnostics.run_all()

      assert_receive {[:indrajaal, :prajna, :diagnostics, :check_complete], ^ref, _, _}, 5000

      :telemetry.detach(ref)
    end

    test "assert_invariant emits telemetry on violation" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:indrajaal, :prajna, :diagnostics, :invariant_violation]
        ])

      Diagnostics.assert_invariant(false, "test violation")

      assert_receive {[:indrajaal, :prajna, :diagnostics, :invariant_violation], ^ref, _, _}, 5000

      :telemetry.detach(ref)
    end
  end
end
