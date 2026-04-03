defmodule Indrajaal.Cortex.GDE.GoalEvaluatorTest do
  @moduledoc """
  TDG Tests for GDE GoalEvaluator module.

  Tests goal evaluation for compilation, test, and format goals.

  STAMP Constraints:
  - SC-GDE-010: Goals must be clearly defined
  - SC-GDE-011: Evaluation must be deterministic
  - SC-GDE-012: Failures must include diagnostic info
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cortex.GDE.GoalEvaluator

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Start the GoalEvaluator for each test
    case GenServer.whereis(GoalEvaluator) do
      nil ->
        {:ok, pid} = GoalEvaluator.start_link([])
        on_exit(fn -> GenServer.stop(pid) end)
        {:ok, pid: pid}

      pid ->
        # Clear history for fresh state
        GoalEvaluator.clear_history()
        {:ok, pid: pid}
    end
  end

  # ============================================================
  # COMPILATION_SUCCESS TESTS
  # ============================================================

  describe "evaluate/2 - :compilation_success" do
    test "succeeds when no compile errors" do
      context = %{logs: "Compiled 10 files (.ex)", metadata: %{}}

      result = GoalEvaluator.evaluate(:compilation_success, context)

      assert {:success, details} = result
      assert details.message == "Compilation successful"
    end

    test "succeeds with empty logs" do
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(:compilation_success, context)

      assert {:success, _details} = result
    end

    test "fails on CompileError" do
      context = %{
        logs: "** (CompileError) lib/test.ex:10: undefined function foo/0",
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:compilation_success, context)

      assert {:failure, :compile_error, diagnostics} = result
      assert diagnostics.error_count == 1
    end

    test "fails on compilation error marker" do
      context = %{
        logs: "== Compilation error in file lib/test.ex ==",
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:compilation_success, context)

      assert {:failure, :compile_error, _diagnostics} = result
    end

    test "extracts multiple compile errors" do
      context = %{
        logs: """
        ** (CompileError) lib/a.ex:1: error one
        ** (CompileError) lib/b.ex:2: error two
        ** (CompileError) lib/c.ex:3: error three
        """,
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:compilation_success, context)

      assert {:failure, :compile_error, diagnostics} = result
      assert diagnostics.error_count == 3
    end
  end

  # ============================================================
  # TEST_PASS TESTS
  # ============================================================

  describe "evaluate/2 - :test_pass" do
    test "succeeds when all tests pass" do
      context = %{logs: "10 tests, 0 failures", metadata: %{}}

      result = GoalEvaluator.evaluate(:test_pass, context)

      assert {:success, details} = result
      assert details.message == "All tests passed"
    end

    test "fails when tests fail" do
      context = %{
        logs: """
        1) test something (MyTest)
           Assertion with == failed
        5 tests, 2 failures
        """,
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:test_pass, context)

      assert {:failure, :test_failure, diagnostics} = result
      assert diagnostics.total_tests == 5
      assert diagnostics.failures == 2
    end

    test "extracts failed test names" do
      context = %{
        logs: """
        1) test first test (TestModule)
           Expected true, got false
        2) test second test (TestModule)
           Assertion failed
        3 tests, 2 failures
        """,
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:test_pass, context)

      assert {:failure, :test_failure, diagnostics} = result
      assert length(diagnostics.failed_tests) == 2
    end
  end

  # ============================================================
  # FORMAT_CLEAN TESTS
  # ============================================================

  describe "evaluate/2 - :format_clean" do
    test "succeeds with clean format" do
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(:format_clean, context)

      assert {:success, _details} = result
    end

    test "fails on format errors" do
      context = %{logs: "mix format failed", metadata: %{}}

      result = GoalEvaluator.evaluate(:format_clean, context)

      assert {:failure, :format_error, _diagnostics} = result
    end

    test "fails on mix format error" do
      context = %{logs: "** (Mix) Could not format files", metadata: %{}}

      result = GoalEvaluator.evaluate(:format_clean, context)

      assert {:failure, :format_error, _diagnostics} = result
    end
  end

  # ============================================================
  # WARNING_FREE TESTS
  # ============================================================

  describe "evaluate/2 - :warning_free" do
    test "succeeds with no warnings" do
      context = %{logs: "Compiled successfully", metadata: %{}}

      result = GoalEvaluator.evaluate(:warning_free, context)

      assert {:success, details} = result
      assert details.message == "No warnings"
    end

    test "fails with warnings" do
      context = %{
        logs: """
        warning: variable x is unused
        warning: function foo/0 is unused
        """,
        metadata: %{}
      }

      result = GoalEvaluator.evaluate(:warning_free, context)

      assert {:failure, :warnings, diagnostics} = result
      assert diagnostics.warning_count == 2
    end
  end

  # ============================================================
  # CREDO_CLEAN TESTS
  # ============================================================

  describe "evaluate/2 - :credo_clean" do
    test "succeeds when no issues found" do
      context = %{logs: "found no issues", metadata: %{}}

      result = GoalEvaluator.evaluate(:credo_clean, context)

      assert {:success, _details} = result
    end

    test "fails when issues found" do
      context = %{logs: "5 issues found", metadata: %{}}

      result = GoalEvaluator.evaluate(:credo_clean, context)

      assert {:failure, :credo_issues, _diagnostics} = result
    end
  end

  # ============================================================
  # CUSTOM GOAL TESTS
  # ============================================================

  describe "evaluate/2 - :custom" do
    test "succeeds when custom function returns true" do
      goal = {:custom, fn _ctx -> true end}
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(goal, context)

      assert {:success, _details} = result
    end

    test "fails when custom function returns false" do
      goal = {:custom, fn _ctx -> false end}
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(goal, context)

      assert {:failure, :custom_failed, _diagnostics} = result
    end

    test "handles exceptions in custom function" do
      goal = {:custom, fn _ctx -> raise "test error" end}
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(goal, context)

      assert {:failure, :custom_error, diagnostics} = result
      assert String.contains?(diagnostics.error, "test error")
    end
  end

  # ============================================================
  # UNKNOWN GOAL TESTS
  # ============================================================

  describe "evaluate/2 - unknown goal" do
    test "fails for unknown goal type" do
      context = %{logs: "", metadata: %{}}

      result = GoalEvaluator.evaluate(:unknown_goal, context)

      assert {:failure, :unknown_goal, diagnostics} = result
      assert diagnostics.goal == :unknown_goal
    end
  end

  # ============================================================
  # MARK_SUCCESS/MARK_FAILURE TESTS
  # ============================================================

  describe "mark_success/2" do
    test "records successful goal" do
      path = [:step1, :step2]

      assert :ok = GoalEvaluator.mark_success(:compilation_success, path)
    end
  end

  describe "mark_failure/3" do
    test "records failed goal" do
      diagnostics = %{error: "something"}

      assert :ok = GoalEvaluator.mark_failure(:compilation_success, :compile_error, diagnostics)
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns evaluation statistics" do
      # Run some evaluations
      GoalEvaluator.evaluate(:compilation_success, %{logs: "Compiled", metadata: %{}})

      GoalEvaluator.evaluate(:compilation_success, %{
        logs: "** (CompileError) test:1: err",
        metadata: %{}
      })

      stats = GoalEvaluator.stats()

      assert stats.total_evaluations == 2
      assert stats.successes == 1
      assert stats.failures == 1
      assert stats.success_rate == 50.0
    end
  end

  # ============================================================
  # HISTORY TESTS
  # ============================================================

  describe "history/1" do
    test "returns recent evaluations" do
      # Run some evaluations
      GoalEvaluator.evaluate(:compilation_success, %{logs: "Compiled", metadata: %{}})
      GoalEvaluator.evaluate(:test_pass, %{logs: "5 tests, 0 failures", metadata: %{}})

      history = GoalEvaluator.history()

      assert length(history) == 2
      # Most recent first
      assert Enum.at(history, 0).goal == :test_pass
      assert Enum.at(history, 1).goal == :compilation_success
    end

    test "respects limit option" do
      # Run multiple evaluations
      for _ <- 1..5 do
        GoalEvaluator.evaluate(:compilation_success, %{logs: "Compiled", metadata: %{}})
      end

      history = GoalEvaluator.history(limit: 3)

      assert length(history) == 3
    end
  end

  describe "clear_history/0" do
    test "clears evaluation history" do
      GoalEvaluator.evaluate(:compilation_success, %{logs: "Compiled", metadata: %{}})
      assert length(GoalEvaluator.history()) > 0

      GoalEvaluator.clear_history()

      assert GoalEvaluator.history() == []
    end
  end

  # ============================================================
  # PROPERTY TESTS
  # ============================================================

  describe "property tests" do
    property "evaluation is deterministic" do
      forall logs <- PC.utf8() do
        context = %{logs: logs, metadata: %{}}
        result1 = GoalEvaluator.evaluate(:compilation_success, context)
        result2 = GoalEvaluator.evaluate(:compilation_success, context)

        # Results should be structurally equal (timestamps may differ)
        case {result1, result2} do
          {{:success, _}, {:success, _}} -> true
          {{:failure, r1, _}, {:failure, r2, _}} -> r1 == r2
          _ -> false
        end
      end
    end

    property "all goals return valid result types" do
      goals = [:compilation_success, :test_pass, :format_clean, :warning_free, :credo_clean]

      forall {goal, logs} <- {PC.elements(goals), PC.utf8()} do
        context = %{logs: logs, metadata: %{}}
        result = GoalEvaluator.evaluate(goal, context)

        match?({:success, _}, result) or match?({:failure, _, _}, result)
      end
    end
  end
end
