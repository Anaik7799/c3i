defmodule Indrajaal.Cortex.GDE.BacktrackerTest do
  @moduledoc """
  TDG Tests for GDE Backtracker module.

  Tests retry logic with state checkpoint/rewind.

  STAMP Constraints:
  - SC-GDE-020: Must checkpoint before each attempt
  - SC-GDE-021: Must rewind on failure
  - SC-GDE-022: Must limit branching factor
  - SC-GDE-023: Must record decision tree
  """

  use ExUnit.Case, async: false
  use PropCheck

  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cortex.GDE.Backtracker
  alias Indrajaal.Cortex.GDE.Generator
  alias Indrajaal.Cortex.GDE.GoalEvaluator

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start Backtracker and dependencies
    case GenServer.whereis(Backtracker) do
      nil ->
        # Start GoalEvaluator first if needed
        unless GenServer.whereis(GoalEvaluator) do
          {:ok, _} = GoalEvaluator.start_link([])
        end

        {:ok, pid} = Backtracker.start_link([])
        on_exit(fn -> GenServer.stop(pid) end)
        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # WITH_RETRY TESTS
  # ============================================================

  describe "with_retry/3" do
    test "succeeds on first try" do
      result = Backtracker.with_retry(fn -> {:ok, "success"} end)

      assert {:ok, "success"} = result
    end

    test "succeeds after retries" do
      # Track attempt count
      counter = :counters.new(1, [:atomics])

      result =
        Backtracker.with_retry(fn ->
          count = :counters.get(counter, 1)
          :counters.add(counter, 1, 1)

          if count >= 2 do
            {:ok, "success after retries"}
          else
            {:error, :not_yet}
          end
        end)

      assert {:ok, "success after retries"} = result
    end

    test "exhausts retries" do
      result =
        Backtracker.with_retry(
          fn -> {:error, :always_fail} end,
          3,
          0
        )

      assert {:error, :exhausted} = result
    end

    test "respects delay between retries" do
      start = System.monotonic_time(:millisecond)

      Backtracker.with_retry(
        fn -> {:error, :fail} end,
        2,
        50
      )

      elapsed = System.monotonic_time(:millisecond) - start

      # Should have at least 1 delay (50ms) between 2 retries
      assert elapsed >= 40
    end
  end

  # ============================================================
  # WITH_BACKTRACK TESTS
  # ============================================================

  describe "with_backtrack/4" do
    test "returns first successful result" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn x ->
            if x == 2, do: {:ok, "found #{x}"}, else: {:error, :not_two}
          end,
          nil
        )

      assert {:ok, backtrack_result} = result
      assert backtrack_result.success == true
      assert backtrack_result.result == "found 2"
      assert backtrack_result.attempts == 2
    end

    test "returns error when exhausted" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn _x -> {:error, :never} end,
          nil
        )

      assert {:error, backtrack_result} = result
      assert backtrack_result.success == false
      assert backtrack_result.attempts == 3
    end

    test "records decision tree" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn x ->
            if x == 3, do: {:ok, x}, else: {:error, :not_three}
          end,
          nil,
          record_decisions: true
        )

      assert {:ok, backtrack_result} = result
      decisions = backtrack_result.decisions

      assert length(decisions) == 3
      # First two should be failures
      assert Enum.at(decisions, 0).result == :failure
      assert Enum.at(decisions, 1).result == :failure
      # Last should be success
      assert Enum.at(decisions, 2).result == :success
    end

    test "respects max_attempts option" do
      generator = Generator.alternatives([1, 2, 3, 4, 5])

      result =
        Backtracker.with_backtrack(
          generator,
          fn _x -> {:error, :fail} end,
          nil,
          max_attempts: 2
        )

      assert {:error, backtrack_result} = result
      assert backtrack_result.attempts == 2
    end

    test "respects timeout option" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn _x ->
            Process.sleep(100)
            {:error, :slow}
          end,
          nil,
          timeout_ms: 50
        )

      assert {:error, backtrack_result} = result
      # Should timeout before all attempts
      assert backtrack_result.attempts < 3
    end

    test "on_failure :stop halts backtracking" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn x ->
            if x == 2, do: {:error, :fatal}, else: {:error, :minor}
          end,
          nil,
          on_failure: fn reason ->
            if reason == :fatal, do: :stop, else: :retry
          end
        )

      assert {:error, backtrack_result} = result
      # Should stop at attempt 2
      assert backtrack_result.attempts == 2
    end

    test "handles exceptions in func" do
      generator = Generator.alternatives([1, 2, 3])

      result =
        Backtracker.with_backtrack(
          generator,
          fn x ->
            if x == 1, do: raise("test error"), else: {:ok, x}
          end,
          nil
        )

      assert {:ok, backtrack_result} = result
      # Should recover and succeed on attempt 2
      assert backtrack_result.result == 2
    end

    test "measures duration" do
      generator = Generator.alternatives([1])

      result =
        Backtracker.with_backtrack(
          generator,
          fn x ->
            Process.sleep(10)
            {:ok, x}
          end,
          nil
        )

      assert {:ok, backtrack_result} = result
      assert backtrack_result.duration_ms >= 10
    end
  end

  # ============================================================
  # CURRENT_DECISIONS TESTS
  # ============================================================

  describe "current_decisions/0" do
    test "returns decisions from last backtrack" do
      generator = Generator.alternatives([1, 2])

      Backtracker.with_backtrack(
        generator,
        fn x ->
          if x == 2, do: {:ok, x}, else: {:error, :not_two}
        end,
        nil
      )

      decisions = Backtracker.current_decisions()

      assert length(decisions) == 2
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns backtracker statistics" do
      generator = Generator.alternatives([1, 2])

      # Run successful backtrack
      Backtracker.with_backtrack(
        generator,
        fn x -> {:ok, x} end,
        nil
      )

      # Run failed backtrack
      Backtracker.with_backtrack(
        generator,
        fn _x -> {:error, :fail} end,
        nil
      )

      stats = Backtracker.stats()

      assert stats.total_backtracks >= 2
      assert stats.successful_backtracks >= 1
      assert stats.failed_backtracks >= 1
      assert stats.success_rate >= 0.0
      assert stats.uptime_seconds >= 0
    end
  end

  # ============================================================
  # INTEGRATION WITH GOAL EVALUATOR
  # ============================================================

  describe "integration with GoalEvaluator" do
    test "evaluates goal after successful func" do
      generator = Generator.alternatives([1, 2, 3])

      # This should fail goal evaluation for x < 3
      result =
        Backtracker.with_backtrack(
          generator,
          fn x -> {:ok, "result #{x}"} end,
          nil
        )

      # Without a specific goal, it should succeed immediately
      assert {:ok, backtrack_result} = result
      assert backtrack_result.result == "result 1"
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "backtrack finds first success if exists" do
      forall {success_idx, list_size} <- {PC.range(0, 9), PC.range(1, 10)} do
        list = Enum.to_list(0..(list_size - 1))
        generator = Generator.alternatives(list)

        # Make success_idx valid
        target = rem(success_idx, list_size)

        result =
          Backtracker.with_backtrack(
            generator,
            fn x ->
              if x == target, do: {:ok, x}, else: {:error, :not_target}
            end,
            nil
          )

        case result do
          {:ok, br} ->
            br.result == target and br.attempts == target + 1

          {:error, _} ->
            # This shouldn't happen if target is in list
            false
        end
      end
    end

    property "backtrack always terminates" do
      forall list <- PC.non_empty(PC.list(PC.integer())) do
        bounded_list = Enum.take(list, 10)
        generator = Generator.alternatives(bounded_list)

        result =
          Backtracker.with_backtrack(
            generator,
            fn _x -> {:error, :fail} end,
            nil,
            max_attempts: 5,
            timeout_ms: 1000
          )

        # Should always return, never hang
        match?({:error, _}, result)
      end
    end

    property "decision count matches attempts" do
      forall list <- PC.non_empty(PC.list(PC.integer())) do
        bounded_list = Enum.take(list, 5)
        generator = Generator.alternatives(bounded_list)

        result =
          Backtracker.with_backtrack(
            generator,
            fn _x -> {:error, :fail} end,
            nil,
            record_decisions: true
          )

        case result do
          {:error, br} ->
            length(br.decisions) == br.attempts

          {:ok, br} ->
            length(br.decisions) == br.attempts
        end
      end
    end
  end
end
