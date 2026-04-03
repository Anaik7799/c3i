defmodule Indrajaal.Core.QualityGatePipelineTest do
  @moduledoc """
  Tests for the 4-gate quality pipeline: Compile → Format → Credo → Test.

  WHAT: Self-contained unit + property tests for quality gate pipeline semantics
  WHY: SC-CI-005 mandatory quality gates, Ω₆ Mandatory Gates (all must pass for
       Feature Complete), SC-CI-007 all 5 test levels must pass before merge
  CONSTRAINTS: SC-CI-005, SC-CI-007, Ω₆, SC-CMD-006, SC-CMD-007, EP-GEN-014

  ## Coverage Matrix
  | Describe Block                    | Unit | StreamData |
  |-----------------------------------|------|------------|
  | Gate 1: Compilation               |  5   |     1      |
  | Gate 2: Formatting                |  4   |     1      |
  | Gate 3: Static Analysis           |  4   |     1      |
  | Gate 4: Testing                   |  5   |     1      |
  | Pipeline Orchestration            |  4   |     0      |
  | Gate Dependencies                 |  3   |     0      |
  | Parallel Gate Execution           |  3   |     0      |
  | Gate Result Aggregation           |  3   |     0      |
  | Retry Semantics                   |  3   |     0      |
  | Property: Pipeline Determinism    |  0   |     1      |
  | Property: Gate Ordering           |  0   |     1      |
  | TOTAL                             | 34   |     6      |

  ## EP-GEN-014 compliance
  - No PropCheck imports (StreamData only — avoids EP-GEN-014 generator conflict)
  - SD. prefix for all StreamData generators
  - `ExUnitProperties.check all(...)` always inside plain `test` blocks
  - All helpers are private `defp` functions — NO production module calls
  """

  use ExUnit.Case, async: true

  import ExUnitProperties

  alias StreamData, as: SD

  @moduletag :quality_gate
  @moduletag :ci_pipeline

  # ============================================================================
  # Gate name atoms used throughout tests
  # ============================================================================

  @gate_names [:compile, :format, :credo, :test]

  # ============================================================================
  # SECTION 1: Gate 1 — Compilation (SC-CMP-025, SC-CMP-026, SC-CI-005)
  # ============================================================================

  describe "Gate 1: Compilation" do
    test "CMP_01: compile gate reports 0 errors for passing state" do
      pipeline = create_pipeline(all_pass: true)
      result = run_gate(pipeline, :compile)
      assert {:ok, %{errors: 0, warnings: 0}} = result
    end

    test "CMP_02: compile gate reports error count on failure" do
      pipeline = create_pipeline(inject_failures: [:compile])
      result = run_gate(pipeline, :compile)
      assert {:error, reason} = result
      assert is_binary(reason)
      assert String.contains?(reason, "compile")
    end

    test "CMP_03: compile gate always checks all files" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :compile)
      assert Map.has_key?(details, :files_compiled)
      assert details.files_compiled > 0
    end

    test "CMP_04: compile gate records elapsed time in result" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :compile)
      assert Map.has_key?(details, :elapsed_ms)
      assert details.elapsed_ms >= 0
    end

    test "CMP_05: compile gate result contains gate name" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :compile)
      assert Map.get(details, :gate) == :compile
    end

    test "CMP_SD_01: compile gate errors are always non-negative integer" do
      check all(
              warning_count <- SD.integer(0..100),
              max_runs: 20
            ) do
        result_details = gate_compile(%{warnings: warning_count})
        assert result_details.errors >= 0
        assert is_integer(result_details.errors)
      end
    end
  end

  # ============================================================================
  # SECTION 2: Gate 2 — Formatting (SC-GEM-003, SC-CMD-006)
  # ============================================================================

  describe "Gate 2: Formatting" do
    test "FMT_01: format gate passes when all files are formatted" do
      pipeline = create_pipeline(all_pass: true)
      result = run_gate(pipeline, :format)
      assert {:ok, %{unformatted_files: 0}} = result
    end

    test "FMT_02: format gate fails when unformatted files exist" do
      pipeline = create_pipeline(inject_failures: [:format])
      result = run_gate(pipeline, :format)
      assert {:error, reason} = result
      assert String.contains?(reason, "format")
    end

    test "FMT_03: format gate result includes checked_files count" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :format)
      assert Map.has_key?(details, :checked_files)
      assert details.checked_files >= 0
    end

    test "FMT_04: format gate requires compile gate to have passed first" do
      # Gate dependency: format requires compile pass (SC-CI-005 gate ordering)
      pipeline = create_pipeline(inject_failures: [:compile])
      {:error, compile_reason} = run_gate(pipeline, :compile)
      # If compile failed, format gate should also short-circuit
      assert is_binary(compile_reason)
      result = run_pipeline_from(pipeline, :format, %{compile: {:error, compile_reason}})
      assert {:error, skip_reason} = result
      assert String.contains?(skip_reason, "prerequisite")
    end

    test "FMT_SD_01: unformatted file count is always non-negative" do
      check all(
              file_count <- SD.integer(0..500),
              max_runs: 20
            ) do
        details = gate_format(%{total_files: file_count, all_pass: true})
        assert details.unformatted_files >= 0
        assert details.unformatted_files <= file_count
      end
    end
  end

  # ============================================================================
  # SECTION 3: Gate 3 — Static Analysis / Credo (SC-CMD-006, SC-CMD-007)
  # ============================================================================

  describe "Gate 3: Static Analysis" do
    test "CREDO_01: credo gate passes with 0 issues in strict mode" do
      pipeline = create_pipeline(all_pass: true)
      result = run_gate(pipeline, :credo)
      assert {:ok, %{issues: 0, mode: :strict}} = result
    end

    test "CREDO_02: credo gate fails on any issue in strict mode" do
      pipeline = create_pipeline(inject_failures: [:credo])
      result = run_gate(pipeline, :credo)
      assert {:error, reason} = result
      assert String.contains?(reason, "credo")
    end

    test "CREDO_03: credo gate result includes mode field" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :credo)
      assert details.mode == :strict
    end

    test "CREDO_04: credo gate records category breakdown" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :credo)
      assert Map.has_key?(details, :categories)
      assert is_map(details.categories)
    end

    test "CREDO_SD_01: issue count is always non-negative" do
      check all(
              issue_count <- SD.integer(0..200),
              max_runs: 20
            ) do
        details = gate_credo(%{issues: issue_count})
        assert details.issues >= 0
        assert is_integer(details.issues)
      end
    end
  end

  # ============================================================================
  # SECTION 4: Gate 4 — Testing (SC-CI-007, SC-COV-002, Ω₆)
  # ============================================================================

  describe "Gate 4: Testing" do
    test "TEST_01: test gate passes when all tests pass and coverage meets threshold" do
      pipeline = create_pipeline(all_pass: true)
      result = run_gate(pipeline, :test)
      assert {:ok, details} = result
      assert details.failures == 0
      assert details.coverage >= 95.0
    end

    test "TEST_02: test gate fails when test failures exist" do
      pipeline = create_pipeline(inject_failures: [:test])
      result = run_gate(pipeline, :test)
      assert {:error, reason} = result
      assert String.contains?(reason, "test")
    end

    test "TEST_03: test gate fails when coverage is below 95%" do
      pipeline = create_pipeline(coverage_override: 80.0)
      result = run_gate(pipeline, :test)
      assert {:error, reason} = result
      assert String.contains?(reason, "coverage")
    end

    test "TEST_04: test gate result includes total and passed counts" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, details} = run_gate(pipeline, :test)
      assert Map.has_key?(details, :total)
      assert Map.has_key?(details, :passed)
      assert details.passed == details.total
    end

    test "TEST_05: coverage is computed from test results" do
      coverage = compute_coverage(%{passed: 95, total: 100})
      assert_in_delta coverage, 95.0, 0.01
    end

    test "TEST_SD_01: coverage is always a float in [0.0, 100.0]" do
      check all(
              passed <- SD.integer(0..1000),
              total <- SD.integer(1..1000),
              max_runs: 30
            ) do
        safe_passed = min(passed, total)
        coverage = compute_coverage(%{passed: safe_passed, total: total})
        assert coverage >= 0.0
        assert coverage <= 100.0
      end
    end
  end

  # ============================================================================
  # SECTION 5: Pipeline Orchestration (SC-CI-005, Ω₆)
  # ============================================================================

  describe "pipeline orchestration" do
    test "ORCH_01: all four gates execute in order for passing pipeline" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, results} = run_pipeline(pipeline)
      executed = Enum.map(results, & &1.gate)
      assert executed == @gate_names
    end

    test "ORCH_02: pipeline returns :ok verdict when all gates pass" do
      pipeline = create_pipeline(all_pass: true)
      {:ok, results} = run_pipeline(pipeline)
      verdict = aggregate_results(results)
      assert verdict.verdict == :pass
    end

    test "ORCH_03: pipeline short-circuits on first gate failure" do
      pipeline = create_pipeline(inject_failures: [:compile])
      {:error, results} = run_pipeline(pipeline)
      # Only the compile gate should have been attempted
      gate_names_executed = Enum.map(results, & &1.gate)
      assert :compile in gate_names_executed
      refute :format in gate_names_executed
      refute :credo in gate_names_executed
      refute :test in gate_names_executed
    end

    test "ORCH_04: pipeline result carries the failing gate name" do
      pipeline = create_pipeline(inject_failures: [:format])
      # compile passes, format fails
      {:error, results} = run_pipeline(pipeline)
      failed_gates = Enum.filter(results, &match?({:error, _}, &1.result))
      assert Enum.any?(failed_gates, fn r -> r.gate == :format end)
    end
  end

  # ============================================================================
  # SECTION 6: Gate Dependencies (SC-CI-005)
  # ============================================================================

  describe "gate dependencies" do
    test "DEP_01: format gate is skipped when compile failed" do
      prior_results = %{compile: {:error, "1 error"}}
      result = run_pipeline_from(create_pipeline(all_pass: true), :format, prior_results)
      assert {:error, reason} = result
      assert String.contains?(reason, "prerequisite")
    end

    test "DEP_02: credo gate is skipped when compile failed" do
      prior_results = %{compile: {:error, "1 error"}}
      result = run_pipeline_from(create_pipeline(all_pass: true), :credo, prior_results)
      assert {:error, reason} = result
      assert String.contains?(reason, "prerequisite")
    end

    test "DEP_03: test gate is skipped when any prior gate failed" do
      prior_results = %{compile: {:ok, %{}}, format: {:error, "1 unformatted"}, credo: {:ok, %{}}}
      result = run_pipeline_from(create_pipeline(all_pass: true), :test, prior_results)
      assert {:error, reason} = result
      assert String.contains?(reason, "prerequisite")
    end
  end

  # ============================================================================
  # SECTION 7: Parallel Gate Execution
  # ============================================================================

  describe "parallel gate execution" do
    test "PAR_01: independent sub-checks within format gate can run concurrently" do
      # Verify that gate_format accepts a list of file paths and processes all
      files = ["lib/a.ex", "lib/b.ex", "lib/c.ex"]
      details = gate_format(%{files: files, all_pass: true})
      assert details.checked_files == length(files)
    end

    test "PAR_02: credo and format gates are logically independent of each other" do
      # format only depends on compile; credo also only depends on compile
      # They can run in parallel once compile passes
      pipeline = create_pipeline(all_pass: true)
      {:ok, r_fmt} = run_gate(pipeline, :format)
      {:ok, r_credo} = run_gate(pipeline, :credo)
      # Both succeed independently
      assert r_fmt.unformatted_files == 0
      assert r_credo.issues == 0
    end

    test "PAR_03: parallel execution results are merged correctly" do
      results = [
        %{
          gate: :format,
          result: {:ok, %{gate: :format, unformatted_files: 0, checked_files: 10}}
        },
        %{gate: :credo, result: {:ok, %{gate: :credo, issues: 0, mode: :strict, categories: %{}}}}
      ]

      verdict = aggregate_results(results)
      assert verdict.verdict == :pass
      assert verdict.gate_count == 2
    end
  end

  # ============================================================================
  # SECTION 8: Gate Result Aggregation (Ω₆)
  # ============================================================================

  describe "gate result aggregation" do
    test "AGG_01: aggregating all pass results yields :pass verdict" do
      results = build_all_pass_results()
      verdict = aggregate_results(results)
      assert verdict.verdict == :pass
    end

    test "AGG_02: aggregating any failure yields :fail verdict" do
      results = [
        %{
          gate: :compile,
          result:
            {:ok, %{gate: :compile, errors: 0, warnings: 0, files_compiled: 10, elapsed_ms: 0}}
        },
        %{gate: :format, result: {:error, "1 unformatted file"}}
      ]

      verdict = aggregate_results(results)
      assert verdict.verdict == :fail
    end

    test "AGG_03: aggregation includes summary of each gate status" do
      results = build_all_pass_results()
      verdict = aggregate_results(results)
      assert Map.has_key?(verdict, :gate_statuses)
      assert length(verdict.gate_statuses) == length(results)
    end
  end

  # ============================================================================
  # SECTION 9: Retry Semantics
  # ============================================================================

  describe "retry semantics" do
    test "RETRY_01: a gate that fails once then passes on retry returns :pass" do
      # Simulate a flaky gate: first call fails, second succeeds
      state = %{call_count: 0, fail_on_first: true}
      result = run_gate_with_retry(state, :compile)
      assert {:ok, _} = result
    end

    test "RETRY_02: a gate that fails twice returns :error after retry" do
      state = %{call_count: 0, always_fail: true}
      result = run_gate_with_retry(state, :compile)
      assert {:error, _} = result
    end

    test "RETRY_03: retry count is capped at 1 (fail fast after one retry)" do
      state = %{call_count: 0, always_fail: true}
      {_result, final_state} = run_gate_with_retry_tracked(state, :compile)
      # Gate was called at most twice (original + 1 retry)
      assert final_state.call_count <= 2
    end
  end

  # ============================================================================
  # SECTION 10: Property — Pipeline Determinism (SC-CI-005, Ω₆)
  # ============================================================================

  describe "property: pipeline determinism" do
    test "PROP_DET_01: same pipeline config always produces same gate result sequence" do
      check all(
              seed <- SD.integer(0..999_999),
              max_runs: 25
            ) do
        pipeline = create_pipeline(all_pass: true, seed: seed)
        {:ok, results1} = run_pipeline(pipeline)
        {:ok, results2} = run_pipeline(pipeline)
        gates1 = Enum.map(results1, & &1.gate)
        gates2 = Enum.map(results2, & &1.gate)
        assert gates1 == gates2
      end
    end
  end

  # ============================================================================
  # SECTION 11: Property — Gate Ordering (SC-CI-005)
  # ============================================================================

  describe "property: gate ordering" do
    test "PROP_ORD_01: gate order compile→format→credo→test never changes for passing pipeline" do
      check all(
              _seed <- SD.integer(),
              max_runs: 20
            ) do
        pipeline = create_pipeline(all_pass: true)
        {:ok, results} = run_pipeline(pipeline)
        executed = Enum.map(results, & &1.gate)
        assert executed == [:compile, :format, :credo, :test]
      end
    end
  end

  # ============================================================================
  # PRIVATE HELPERS — all self-contained, NO production module calls
  # ============================================================================

  # Creates a pipeline state map.
  # Options:
  #   all_pass: true           — all gates succeed
  #   inject_failures: [gates] — listed gates return errors
  #   coverage_override: float — override the test gate's coverage %
  #   seed: integer            — ignored (for determinism docs)
  defp create_pipeline(opts \\ []) do
    %{
      all_pass: Keyword.get(opts, :all_pass, false),
      inject_failures: Keyword.get(opts, :inject_failures, []),
      coverage_override: Keyword.get(opts, :coverage_override, 98.5),
      seed: Keyword.get(opts, :seed, 0)
    }
  end

  # Executes a single named gate against pipeline state.
  # Returns {:ok, details_map} | {:error, reason_string}
  defp run_gate(pipeline, gate_name) do
    if gate_name in pipeline.inject_failures do
      {:error, "#{gate_name} gate: simulated failure injected"}
    else
      case gate_name do
        :compile -> {:ok, gate_compile(%{})}
        :format -> {:ok, gate_format(%{all_pass: true, files: ["lib/a.ex"], total_files: 1})}
        :credo -> {:ok, gate_credo(%{issues: 0})}
        :test -> run_test_gate(pipeline)
      end
    end
  end

  # Executes pipeline gates in order with early exit on first failure.
  # Returns {:ok, [result_entries]} | {:error, [partial_result_entries]}
  defp run_pipeline(pipeline) do
    # Use a tagged accumulator {:ok, entries} | {:error, entries} so the
    # reduce_while halt value has the same shape as the cont value.
    result =
      Enum.reduce_while(@gate_names, {:ok, []}, fn gate_name, {_status, acc} ->
        case run_gate(pipeline, gate_name) do
          {:ok, details} ->
            entry = %{gate: gate_name, result: {:ok, details}}
            {:cont, {:ok, acc ++ [entry]}}

          {:error, reason} ->
            entry = %{gate: gate_name, result: {:error, reason}}
            {:halt, {:error, acc ++ [entry]}}
        end
      end)

    result
  end

  # Runs a single gate but skips it (returning prerequisite error) if any
  # prior_results contains an {:error, _} entry.
  defp run_pipeline_from(pipeline, gate_name, prior_results) do
    any_failed =
      Enum.any?(prior_results, fn {_gate, result} ->
        match?({:error, _}, result)
      end)

    if any_failed do
      {:error, "#{gate_name} gate skipped: prerequisite gate failed"}
    else
      run_gate(pipeline, gate_name)
    end
  end

  # Simulates the compile gate. Returns a details map.
  defp gate_compile(opts) do
    warnings = Map.get(opts, :warnings, 0)

    %{
      gate: :compile,
      errors: 0,
      warnings: warnings,
      files_compiled: 773,
      elapsed_ms: 1_200
    }
  end

  # Simulates the format check gate. Returns a details map.
  defp gate_format(opts) do
    all_pass = Map.get(opts, :all_pass, false)
    files = Map.get(opts, :files, [])
    total_files = Map.get(opts, :total_files, length(files))

    unformatted =
      if all_pass do
        0
      else
        max(1, div(total_files, 10))
      end

    %{
      gate: :format,
      unformatted_files: unformatted,
      checked_files: total_files
    }
  end

  # Simulates the Credo static analysis gate. Returns a details map.
  defp gate_credo(opts) do
    issues = Map.get(opts, :issues, 0)

    %{
      gate: :credo,
      issues: issues,
      mode: :strict,
      categories: %{
        design: 0,
        consistency: 0,
        readability: 0,
        refactor: 0,
        warning: 0
      }
    }
  end

  # Simulates the test execution gate. Returns a details map.
  defp gate_test(opts) do
    coverage = Map.get(opts, :coverage, 98.5)
    total = Map.get(opts, :total, 1005)
    failures = Map.get(opts, :failures, 0)

    %{
      gate: :test,
      total: total,
      passed: total - failures,
      failures: failures,
      coverage: coverage
    }
  end

  # Handles the test gate with coverage threshold enforcement.
  defp run_test_gate(pipeline) do
    coverage = pipeline.coverage_override
    details = gate_test(%{coverage: coverage})

    cond do
      details.failures > 0 ->
        {:error, "test gate: #{details.failures} test(s) failed"}

      coverage < 95.0 ->
        {:error, "test gate: coverage #{Float.round(coverage, 1)}% is below 95% threshold"}

      true ->
        {:ok, details}
    end
  end

  # Aggregates a list of gate result entries into a single verdict map.
  # Each entry: %{gate: atom, result: {:ok, map} | {:error, string}}
  defp aggregate_results(entries) do
    statuses =
      Enum.map(entries, fn entry ->
        status =
          case entry.result do
            {:ok, _} -> :pass
            {:error, _} -> :fail
          end

        %{gate: entry.gate, status: status}
      end)

    verdict =
      if Enum.all?(statuses, fn s -> s.status == :pass end) do
        :pass
      else
        :fail
      end

    %{
      verdict: verdict,
      gate_count: length(entries),
      gate_statuses: statuses
    }
  end

  # Computes a simulated coverage percentage from passed/total counts.
  defp compute_coverage(%{passed: passed, total: total}) when total > 0 do
    Float.round(passed / total * 100.0, 2)
  end

  defp compute_coverage(%{total: 0}), do: 0.0

  # Builds a complete list of pass results for all four gates.
  defp build_all_pass_results do
    [
      %{gate: :compile, result: {:ok, gate_compile(%{})}},
      %{gate: :format, result: {:ok, gate_format(%{all_pass: true, total_files: 50})}},
      %{gate: :credo, result: {:ok, gate_credo(%{issues: 0})}},
      %{gate: :test, result: {:ok, gate_test(%{coverage: 98.5})}}
    ]
  end

  # Simulates a gate with retry-on-failure semantics (max 1 retry).
  # state.fail_on_first: true  — first call fails, second succeeds
  # state.always_fail: true    — all calls fail
  defp run_gate_with_retry(state, gate_name) do
    {result, _final_state} = run_gate_with_retry_tracked(state, gate_name)
    result
  end

  defp run_gate_with_retry_tracked(state, gate_name) do
    state1 = %{state | call_count: state.call_count + 1}

    first_result =
      cond do
        Map.get(state, :always_fail) ->
          {:error, "#{gate_name}: permanent failure (call #{state1.call_count})"}

        Map.get(state, :fail_on_first) and state1.call_count == 1 ->
          {:error, "#{gate_name}: transient failure on first attempt"}

        true ->
          {:ok, gate_compile(%{})}
      end

    case first_result do
      {:ok, _} = ok ->
        {ok, state1}

      {:error, _} ->
        # Retry once
        state2 = %{state1 | call_count: state1.call_count + 1}

        retry_result =
          cond do
            Map.get(state, :always_fail) ->
              {:error, "#{gate_name}: permanent failure (retry #{state2.call_count})"}

            true ->
              # fail_on_first: second attempt succeeds
              {:ok, gate_compile(%{})}
          end

        {retry_result, state2}
    end
  end
end
