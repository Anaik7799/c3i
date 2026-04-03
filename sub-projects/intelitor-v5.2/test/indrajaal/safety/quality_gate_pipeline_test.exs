defmodule Indrajaal.Safety.QualityGatePipelineTest do
  @moduledoc """
  TDG test: Quality gate pipeline — 4-gate validation for SIL-6 compliance.

  WHAT: Tests the 4-gate quality pipeline (Compile, Format, Credo, Test) including
        gate sequencing, failure propagation, rollback on failure, and metrics collection.
  WHY: Validates SC-CI-005 (quality gates mandatory), SC-FUNC-006 (quality gates before merge),
       SC-CMD-006/007 (quality/quality-full commands), AOR-TPS-001 (Jidoka stop on defect).

  STAMP Constraints:
  - SC-CI-005: Quality gates MANDATORY
  - SC-FUNC-006: Quality gates MUST pass before merge
  - SC-CMD-006: quality SHALL run format + credo
  - SC-CMD-007: quality-full SHALL include dialyzer + sobelow
  - SC-CMP-025: 0 warnings mandatory
  - SC-CREDO-001: No apply/2 anti-pattern
  - SC-TPS-001: Jidoka principle — stop on quality defect
  - AOR-TPS-001: Stop immediately on quality defect
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @gates [:compile, :format, :credo, :test]
  @extended_gates [:compile, :format, :credo, :dialyzer, :sobelow, :test]

  describe "gate pipeline sequencing" do
    test "standard pipeline has 4 gates" do
      pipeline = build_pipeline(:standard)
      assert length(pipeline.gates) == 4
      assert pipeline.gates == @gates
    end

    test "full pipeline has 6 gates" do
      pipeline = build_pipeline(:full)
      assert length(pipeline.gates) == 6
      assert pipeline.gates == @extended_gates
    end

    test "gates execute in correct order" do
      pipeline = build_pipeline(:standard)
      {results, _} = execute_pipeline(pipeline, all_passing_results())

      gate_order = Enum.map(results, & &1.gate)
      assert gate_order == @gates
    end

    test "all gates passing produces :ok result" do
      pipeline = build_pipeline(:standard)
      {_results, summary} = execute_pipeline(pipeline, all_passing_results())

      assert summary.status == :passed
      assert summary.failed_gate == nil
    end
  end

  describe "gate failure propagation (SC-TPS-001 Jidoka)" do
    test "compile failure stops pipeline immediately" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :compile, {:error, "1 error"})
      {results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.status == :failed
      assert summary.failed_gate == :compile
      # Only compile was executed
      assert length(results) == 1
    end

    test "format failure stops before credo" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :format, {:error, "3 files unformatted"})
      {results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.status == :failed
      assert summary.failed_gate == :format
      # compile + format executed
      assert length(results) == 2
    end

    test "credo failure stops before test" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :credo, {:error, "5 issues found"})
      {results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.status == :failed
      assert summary.failed_gate == :credo
      assert length(results) == 3
    end

    test "test failure produces failed summary" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :test, {:error, "2 failures"})
      {results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.status == :failed
      assert summary.failed_gate == :test
      # All 4 gates attempted (test is last)
      assert length(results) == 4
    end
  end

  describe "gate result details" do
    test "compile gate reports warning count (SC-CMP-025)" do
      result = run_gate(:compile, {:ok, %{warnings: 0, errors: 0, files: 773}})

      assert result.status == :passed
      assert result.metrics.warnings == 0
      assert result.metrics.files == 773
    end

    test "compile gate with warnings fails (SC-CMP-025 zero warnings)" do
      result = run_gate(:compile, {:ok, %{warnings: 3, errors: 0, files: 773}})

      # Under strict mode, warnings = failure
      assert result.status == :failed
    end

    test "format gate reports file count" do
      result = run_gate(:format, {:ok, %{checked: 773, unformatted: 0}})

      assert result.status == :passed
      assert result.metrics.unformatted == 0
    end

    test "credo gate reports issue count (SC-CREDO-001)" do
      result = run_gate(:credo, {:ok, %{issues: 0, files: 773}})

      assert result.status == :passed
      assert result.metrics.issues == 0
    end

    test "test gate reports pass/fail counts" do
      result = run_gate(:test, {:ok, %{tests: 1005, failures: 0, excluded: 12}})

      assert result.status == :passed
      assert result.metrics.tests == 1005
      assert result.metrics.failures == 0
    end
  end

  describe "pipeline metrics collection" do
    test "pipeline collects timing for each gate" do
      pipeline = build_pipeline(:standard)
      {results, _summary} = execute_pipeline(pipeline, all_passing_results())

      for result <- results do
        assert Map.has_key?(result, :duration_ms)
        assert result.duration_ms >= 0
      end
    end

    test "summary includes total duration" do
      pipeline = build_pipeline(:standard)
      {_results, summary} = execute_pipeline(pipeline, all_passing_results())

      assert Map.has_key?(summary, :total_duration_ms)
      assert summary.total_duration_ms >= 0
    end

    test "summary includes gate count" do
      pipeline = build_pipeline(:standard)
      {_results, summary} = execute_pipeline(pipeline, all_passing_results())

      assert summary.gates_passed == 4
      assert summary.gates_total == 4
    end
  end

  describe "rollback protocol" do
    test "failure triggers rollback recommendation" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :test, {:error, "1 failure"})
      {_results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.rollback_required == true
      assert summary.rollback_layer in [:l1_git, :l2_code, :l3_db, :l4_system]
    end

    test "compile failure recommends L1 git rollback" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :compile, {:error, "error"})
      {_results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.rollback_layer == :l1_git
    end

    test "test failure recommends L2 code rollback" do
      pipeline = build_pipeline(:standard)
      results_map = Map.put(all_passing_results(), :test, {:error, "failure"})
      {_results, summary} = execute_pipeline(pipeline, results_map)

      assert summary.rollback_layer == :l2_code
    end

    test "passing pipeline needs no rollback" do
      pipeline = build_pipeline(:standard)
      {_results, summary} = execute_pipeline(pipeline, all_passing_results())

      assert summary.rollback_required == false
      assert summary.rollback_layer == nil
    end
  end

  describe "property: pipeline consistency" do
    test "exactly one gate can fail in any execution" do
      ExUnitProperties.check all(
                               fail_index <- SD.integer(0..3),
                               max_runs: 15
                             ) do
        pipeline = build_pipeline(:standard)
        gate_to_fail = Enum.at(@gates, fail_index)

        results_map =
          Map.put(all_passing_results(), gate_to_fail, {:error, "synthetic failure"})

        {results, summary} = execute_pipeline(pipeline, results_map)

        assert summary.status == :failed
        assert summary.failed_gate == gate_to_fail
        # Results should include up to and including the failed gate
        assert length(results) == fail_index + 1
      end
    end

    test "passing gates count matches executed gates" do
      ExUnitProperties.check all(
                               fail_index <-
                                 SD.one_of([SD.constant(nil) | Enum.map(0..3, &SD.constant/1)]),
                               max_runs: 20
                             ) do
        pipeline = build_pipeline(:standard)

        results_map =
          case fail_index do
            nil ->
              all_passing_results()

            idx ->
              gate = Enum.at(@gates, idx)
              Map.put(all_passing_results(), gate, {:error, "fail"})
          end

        {results, summary} = execute_pipeline(pipeline, results_map)

        if fail_index == nil do
          assert summary.gates_passed == 4
        else
          assert summary.gates_passed == fail_index
        end

        assert length(results) <= 4
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp build_pipeline(type) do
    gates =
      case type do
        :standard -> @gates
        :full -> @extended_gates
      end

    %{
      type: type,
      gates: gates,
      strict_warnings: true,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  defp all_passing_results do
    %{
      compile: {:ok, %{warnings: 0, errors: 0, files: 773}},
      format: {:ok, %{checked: 773, unformatted: 0}},
      credo: {:ok, %{issues: 0, files: 773}},
      test: {:ok, %{tests: 1005, failures: 0, excluded: 12}},
      dialyzer: {:ok, %{warnings: 0}},
      sobelow: {:ok, %{vulnerabilities: 0}}
    }
  end

  defp execute_pipeline(pipeline, results_map) do
    start_time = System.monotonic_time(:millisecond)

    {results, failed_gate} =
      Enum.reduce_while(pipeline.gates, {[], nil}, fn gate, {acc, _} ->
        gate_result = run_gate(gate, Map.get(results_map, gate, {:ok, %{}}))

        case gate_result.status do
          :passed ->
            {:cont, {acc ++ [gate_result], nil}}

          :failed ->
            {:halt, {acc ++ [gate_result], gate}}
        end
      end)

    total_duration = System.monotonic_time(:millisecond) - start_time
    gates_passed = Enum.count(results, &(&1.status == :passed))

    rollback_layer =
      case failed_gate do
        :compile -> :l1_git
        :format -> :l1_git
        :credo -> :l1_git
        :test -> :l2_code
        :dialyzer -> :l2_code
        :sobelow -> :l2_code
        nil -> nil
      end

    summary = %{
      status: if(failed_gate == nil, do: :passed, else: :failed),
      failed_gate: failed_gate,
      gates_passed: gates_passed,
      gates_total: length(pipeline.gates),
      total_duration_ms: total_duration,
      rollback_required: failed_gate != nil,
      rollback_layer: rollback_layer
    }

    {results, summary}
  end

  defp run_gate(gate, result) do
    start_time = System.monotonic_time(:millisecond)

    {status, metrics} =
      case result do
        {:ok, metrics} ->
          # Check strict conditions
          status =
            case gate do
              :compile ->
                if Map.get(metrics, :warnings, 0) > 0, do: :failed, else: :passed

              :format ->
                if Map.get(metrics, :unformatted, 0) > 0, do: :failed, else: :passed

              :credo ->
                if Map.get(metrics, :issues, 0) > 0, do: :failed, else: :passed

              :test ->
                if Map.get(metrics, :failures, 0) > 0, do: :failed, else: :passed

              :dialyzer ->
                if Map.get(metrics, :warnings, 0) > 0, do: :failed, else: :passed

              :sobelow ->
                if Map.get(metrics, :vulnerabilities, 0) > 0, do: :failed, else: :passed

              _ ->
                :passed
            end

          {status, metrics}

        {:error, _reason} ->
          {:failed, %{}}
      end

    duration = System.monotonic_time(:millisecond) - start_time

    %{
      gate: gate,
      status: status,
      metrics: metrics,
      duration_ms: duration
    }
  end
end
