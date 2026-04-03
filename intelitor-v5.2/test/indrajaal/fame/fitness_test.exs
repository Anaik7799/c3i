defmodule Indrajaal.FAME.FitnessTest do
  @moduledoc """
  TDG test suite for FAME.Fitness.

  ## STAMP Safety Integration
  - SC-FAME-003: Fitness evaluation mandatory for P0 artifacts
  - SC-FAME-004: Threshold breaches MUST trigger alerts within 100ms
  - SC-FAME-005: Composite scores MUST weight categories per domain criticality

  ## TPS 5-Level RCA Context
  - L1 Symptom: evaluate returns error for valid fame_block
  - L5 Root Cause: validate_fame_block rejects empty invariants map
  """

  use ExUnit.Case, async: true

  alias Indrajaal.FAME.Fitness

  @empty_fame_block %{
    meta: %{artifact_id: "test.module", artifact_type: :module, purpose: "testing"},
    invariants: %{
      structural: [],
      behavioral: [],
      communication: [],
      operational: []
    }
  }

  @fame_block_with_invariants %{
    meta: %{
      artifact_id: "test.module.fitness",
      artifact_type: :module,
      purpose: "test fitness"
    },
    invariants: %{
      structural: [
        %{
          id: "INV-STRUCT-001",
          name: "Module exists",
          enforcement: :compile_time,
          description: "Module must exist",
          verification: nil
        }
      ],
      behavioral: [
        %{
          id: "INV-BEHAV-001",
          name: "Returns ok",
          enforcement: :test,
          description: "Returns {:ok, val}",
          verification: nil
        }
      ],
      communication: [],
      operational: []
    }
  }

  # ============================================================================
  # evaluate/2
  # ============================================================================

  describe "evaluate/2" do
    test "returns :ok tuple for valid fame block with empty invariants" do
      assert {:ok, _score} = Fitness.evaluate(@empty_fame_block)
    end

    test "score is 1.0 when all invariant lists are empty" do
      {:ok, score} = Fitness.evaluate(@empty_fame_block)
      assert score == 1.0
    end

    test "score is float in range [0.0, 1.0]" do
      {:ok, score} = Fitness.evaluate(@fame_block_with_invariants)
      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end

    test "accepts custom weights" do
      weights = %{structural: 0.4, behavioral: 0.3, communication: 0.2, operational: 0.1}
      assert {:ok, _score} = Fitness.evaluate(@empty_fame_block, weights: weights)
    end

    test "accepts threshold option" do
      assert {:ok, _score} = Fitness.evaluate(@empty_fame_block, threshold: 0.9)
    end

    test "fame block without invariants key uses defaults" do
      block = %{meta: %{artifact_id: "x.y", artifact_type: :module, purpose: "x"}}
      assert {:ok, score} = Fitness.evaluate(block)
      assert score == 1.0
    end

    test "compile_time invariants always pass" do
      block = %{
        meta: %{artifact_id: "a.b", artifact_type: :module, purpose: "t"},
        invariants: %{
          structural: [
            %{
              id: "S1",
              name: "N1",
              enforcement: :compile_time,
              description: "d",
              verification: nil
            }
          ],
          behavioral: [],
          communication: [],
          operational: []
        }
      }

      {:ok, score} = Fitness.evaluate(block)
      assert score == 1.0
    end

    test "manual invariants default to pass" do
      block = %{
        meta: %{artifact_id: "a.b", artifact_type: :module, purpose: "t"},
        invariants: %{
          structural: [
            %{id: "S1", name: "N1", enforcement: :manual, description: "d", verification: nil}
          ],
          behavioral: [],
          communication: [],
          operational: []
        }
      }

      {:ok, score} = Fitness.evaluate(block)
      assert score == 1.0
    end

    test "returns error for invalid weights that do not sum to ~1.0" do
      bad_weights = %{structural: 0.5, behavioral: 0.5, communication: 0.5, operational: 0.5}
      assert {:error, _} = Fitness.evaluate(@empty_fame_block, weights: bad_weights)
    end
  end

  # ============================================================================
  # evaluate_structural/1
  # ============================================================================

  describe "evaluate_structural/1" do
    test "returns :ok tuple" do
      assert {:ok, _score} = Fitness.evaluate_structural(@empty_fame_block)
    end

    test "returns 1.0 for empty structural invariants" do
      {:ok, score} = Fitness.evaluate_structural(@empty_fame_block)
      assert score == 1.0
    end

    test "returns score for fame block without structural key" do
      block = %{meta: %{artifact_id: "a.b", artifact_type: :module, purpose: "t"}}
      {:ok, score} = Fitness.evaluate_structural(block)
      assert score == 1.0
    end

    test "score is float" do
      {:ok, score} = Fitness.evaluate_structural(@fame_block_with_invariants)
      assert is_float(score)
    end
  end

  # ============================================================================
  # evaluate_behavioral/1
  # ============================================================================

  describe "evaluate_behavioral/1" do
    test "returns :ok tuple" do
      assert {:ok, _score} = Fitness.evaluate_behavioral(@empty_fame_block)
    end

    test "returns 1.0 for empty behavioral invariants" do
      {:ok, score} = Fitness.evaluate_behavioral(@empty_fame_block)
      assert score == 1.0
    end

    test "returns float score" do
      {:ok, score} = Fitness.evaluate_behavioral(@fame_block_with_invariants)
      assert is_float(score)
    end
  end

  # ============================================================================
  # evaluate_communication/1
  # ============================================================================

  describe "evaluate_communication/1" do
    test "returns :ok tuple" do
      assert {:ok, _score} = Fitness.evaluate_communication(@empty_fame_block)
    end

    test "returns 1.0 for empty communication invariants" do
      {:ok, score} = Fitness.evaluate_communication(@empty_fame_block)
      assert score == 1.0
    end
  end

  # ============================================================================
  # evaluate_operational/1
  # ============================================================================

  describe "evaluate_operational/1" do
    test "returns :ok tuple" do
      assert {:ok, _score} = Fitness.evaluate_operational(@empty_fame_block)
    end

    test "returns 1.0 for empty operational invariants" do
      {:ok, score} = Fitness.evaluate_operational(@empty_fame_block)
      assert score == 1.0
    end
  end

  # ============================================================================
  # composite_score/2
  # ============================================================================

  describe "composite_score/2" do
    test "returns :ok tuple" do
      scores = %{structural: 1.0, behavioral: 1.0, communication: 1.0, operational: 1.0}
      assert {:ok, _} = Fitness.composite_score(scores)
    end

    test "all 1.0 scores produce 1.0 composite" do
      scores = %{structural: 1.0, behavioral: 1.0, communication: 1.0, operational: 1.0}
      {:ok, composite} = Fitness.composite_score(scores)
      assert_in_delta composite, 1.0, 0.0001
    end

    test "all 0.0 scores produce 0.0 composite" do
      scores = %{structural: 0.0, behavioral: 0.0, communication: 0.0, operational: 0.0}
      {:ok, composite} = Fitness.composite_score(scores)
      assert_in_delta composite, 0.0, 0.0001
    end

    test "accepts custom weights" do
      scores = %{structural: 1.0, behavioral: 0.0, communication: 0.0, operational: 0.0}
      weights = %{structural: 1.0, behavioral: 0.0, communication: 0.0, operational: 0.0}
      {:ok, composite} = Fitness.composite_score(scores, weights)
      assert_in_delta composite, 1.0, 0.0001
    end

    test "uses default weights when nil passed" do
      scores = %{structural: 1.0, behavioral: 1.0, communication: 1.0, operational: 1.0}
      assert {:ok, _} = Fitness.composite_score(scores, nil)
    end

    test "returns error for invalid weights" do
      scores = %{structural: 0.5, behavioral: 0.5, communication: 0.5, operational: 0.5}
      bad_weights = %{structural: 0.5, behavioral: 0.5, communication: 0.5, operational: 0.5}
      assert {:error, _} = Fitness.composite_score(scores, bad_weights)
    end

    test "mixed scores produce weighted composite" do
      scores = %{structural: 1.0, behavioral: 0.0, communication: 1.0, operational: 1.0}
      {:ok, composite} = Fitness.composite_score(scores)
      # Default weights: structural=0.25, behavioral=0.30, communication=0.20, operational=0.25
      # = 0.25*1.0 + 0.30*0.0 + 0.20*1.0 + 0.25*1.0 = 0.70
      assert_in_delta composite, 0.70, 0.0001
    end
  end

  # ============================================================================
  # evaluate_with_report/2
  # ============================================================================

  describe "evaluate_with_report/2" do
    test "returns :ok tuple with report" do
      assert {:ok, _report} = Fitness.evaluate_with_report(@empty_fame_block)
    end

    test "report contains composite_score" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report, :composite_score)
    end

    test "report contains threshold" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report, :threshold)
    end

    test "report contains threshold_passed" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report, :threshold_passed)
    end

    test "report contains categories map" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report, :categories)
      assert Map.has_key?(report.categories, :structural)
      assert Map.has_key?(report.categories, :behavioral)
      assert Map.has_key?(report.categories, :communication)
      assert Map.has_key?(report.categories, :operational)
    end

    test "report contains evaluated_at DateTime" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert %DateTime{} = report.evaluated_at
    end

    test "report contains evaluation_duration_us" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert is_integer(report.evaluation_duration_us)
      assert report.evaluation_duration_us >= 0
    end

    test "threshold_passed is true for 1.0 score with default 0.80 threshold" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert report.threshold_passed == true
    end

    test "artifact_id is extracted from meta" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert report.artifact_id == "test.module"
    end

    test "category result contains score" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report.categories.structural, :score)
    end

    test "category result contains total_invariants" do
      {:ok, report} = Fitness.evaluate_with_report(@empty_fame_block)
      assert Map.has_key?(report.categories.structural, :total_invariants)
    end
  end

  # ============================================================================
  # check_threshold/2
  # ============================================================================

  describe "check_threshold/2" do
    test "returns {:ok, :passed} when score >= threshold" do
      assert {:ok, :passed} = Fitness.check_threshold(@empty_fame_block)
    end

    test "returns {:alert, report} when score < threshold" do
      # Force a failing score by setting threshold above maximum possible
      result = Fitness.check_threshold(@empty_fame_block, threshold: 1.1)
      assert {:alert, _report} = result
    end

    test "alert report has threshold_passed false" do
      {:alert, report} = Fitness.check_threshold(@empty_fame_block, threshold: 1.1)
      assert report.threshold_passed == false
    end

    test "calls callback on breach" do
      test_pid = self()

      callback = fn report ->
        send(test_pid, {:breach, report.composite_score})
        :ok
      end

      Fitness.check_threshold(@empty_fame_block, threshold: 1.1, callback: callback)
      assert_received {:breach, _score}
    end

    test "does not call callback when passing" do
      test_pid = self()

      callback = fn _report ->
        send(test_pid, :should_not_be_called)
        :ok
      end

      Fitness.check_threshold(@empty_fame_block, threshold: 0.5, callback: callback)
      refute_received :should_not_be_called
    end
  end

  # ============================================================================
  # check_thresholds_batch/2
  # ============================================================================

  describe "check_thresholds_batch/2" do
    test "returns :ok tuple" do
      assert {:ok, _summary} = Fitness.check_thresholds_batch([@empty_fame_block])
    end

    test "summary has passed count" do
      {:ok, summary} = Fitness.check_thresholds_batch([@empty_fame_block])
      assert Map.has_key?(summary, :passed)
    end

    test "summary has failed count" do
      {:ok, summary} = Fitness.check_thresholds_batch([@empty_fame_block])
      assert Map.has_key?(summary, :failed)
    end

    test "summary has alerts list" do
      {:ok, summary} = Fitness.check_thresholds_batch([@empty_fame_block])
      assert is_list(summary.alerts)
    end

    test "all pass with empty invariants and default threshold" do
      blocks = List.duplicate(@empty_fame_block, 3)
      {:ok, summary} = Fitness.check_thresholds_batch(blocks)
      assert summary.passed == 3
      assert summary.failed == 0
    end

    test "empty list returns zero counts" do
      {:ok, summary} = Fitness.check_thresholds_batch([])
      assert summary.passed == 0
      assert summary.failed == 0
      assert summary.alerts == []
    end
  end

  # ============================================================================
  # start_continuous_evaluation/2 and stop_continuous_evaluation/1
  # ============================================================================

  describe "start_continuous_evaluation/2" do
    test "returns :ok tuple with pid" do
      {:ok, pid} = Fitness.start_continuous_evaluation(@empty_fame_block, interval_ms: 60_000)
      assert is_pid(pid)
      Process.exit(pid, :shutdown)
    end

    test "spawned process is alive" do
      {:ok, pid} = Fitness.start_continuous_evaluation(@empty_fame_block, interval_ms: 60_000)
      assert Process.alive?(pid)
      Process.exit(pid, :shutdown)
    end

    test "accepts optional name" do
      name = :test_fitness_monitor_unique

      {:ok, pid} =
        Fitness.start_continuous_evaluation(@empty_fame_block, interval_ms: 60_000, name: name)

      assert Process.whereis(name) == pid
      Process.exit(pid, :shutdown)
    end
  end

  describe "stop_continuous_evaluation/1" do
    test "stops process by pid" do
      {:ok, pid} = Fitness.start_continuous_evaluation(@empty_fame_block, interval_ms: 60_000)
      assert :ok = Fitness.stop_continuous_evaluation(pid)
      Process.sleep(10)
      refute Process.alive?(pid)
    end

    test "stops process by atom name" do
      name = :test_stop_by_name_unique

      {:ok, pid} =
        Fitness.start_continuous_evaluation(@empty_fame_block, interval_ms: 60_000, name: name)

      assert :ok = Fitness.stop_continuous_evaluation(name)
      Process.sleep(10)
      refute Process.alive?(pid)
    end

    test "returns :ok when process not found by name" do
      assert :ok = Fitness.stop_continuous_evaluation(:nonexistent_monitor_xyz)
    end
  end
end
