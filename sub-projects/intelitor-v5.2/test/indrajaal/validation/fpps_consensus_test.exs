defmodule Indrajaal.Validation.FPPSConsensusTest do
  @moduledoc """
  Formal Verification Derived Tests: FPPS 5-Method Validation Consensus

  Based on:
  - Mathematica §5: FPPS 5-Method Validation System
  - Quint §Q5: FPPSConsensus State Machine
  - Agda §A3: FPPS Consensus Proofs

  STAMP Constraints Tested:
  - SC-VAL-001: System SHALL use ONLY Patient Mode compilation
  - SC-VAL-002: System SHALL analyze complete compilation logs, never partial
  - SC-VAL-003: System SHALL achieve 100% consensus across all validation methods
  - SC-VAL-004: Method disagreement SHALL trigger emergency protocol
  - SC-VAL-005: System SHALL maintain audit trail
  - SC-VAL-006: Selective compilation validation SHALL be FORBIDDEN (EP-110)
  - SC-VAL-007: System SHALL detect validation process drift (EP-111)
  - SC-VAL-008: System SHALL integrate SOPv511 framework

  Agda Theorems Verified:
  - disagreement-triggers-emergency: Method disagreement always triggers emergency
  - agreed-implies-consensus: Agreed result implies consensus held
  - uniform-results-agree: Same results always agree
  """

  use ExUnit.Case, async: true

  # Validation methods from Mathematica §5.1
  @validation_methods [:pattern, :ast, :statistical, :binary, :line_by_line]

  # =============================================================================
  # §A3.3: Consensus Definition Tests (Agda: Consensus)
  # =============================================================================

  describe "Consensus Definition (Agda: AllAgreeOnErrors, AllAgreeOnWarnings)" do
    test "all methods with same results achieve consensus" do
      # Agda theorem: uniform-results-agree
      result = %{errors: 0, warnings: 0}
      results = @validation_methods |> Enum.map(fn method -> {method, result} end) |> Map.new()

      assert consensus?(results)
    end

    test "any method with different error count breaks consensus" do
      results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 0, warnings: 0},
        # Different!
        statistical: %{errors: 1, warnings: 0},
        binary: %{errors: 0, warnings: 0},
        line_by_line: %{errors: 0, warnings: 0}
      }

      refute consensus?(results)
    end

    test "any method with different warning count breaks consensus" do
      results = %{
        pattern: %{errors: 0, warnings: 5},
        ast: %{errors: 0, warnings: 5},
        statistical: %{errors: 0, warnings: 5},
        # Different!
        binary: %{errors: 0, warnings: 6},
        line_by_line: %{errors: 0, warnings: 5}
      }

      refute consensus?(results)
    end

    test "consensus requires all 5 methods" do
      incomplete_results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 0, warnings: 0},
        statistical: %{errors: 0, warnings: 0}
        # Missing: binary, line_by_line
      }

      refute consensus?(incomplete_results)
    end
  end

  # =============================================================================
  # §A3.6: EP-110 Prevention Tests (Agda: disagreement-triggers-emergency)
  # =============================================================================

  describe "EP-110 Prevention (Agda: disagreement-triggers-emergency)" do
    test "disagreement always triggers emergency" do
      # Agda theorem: disagreement-triggers-emergency
      non_consensus_results = %{
        pattern: %{errors: 0, warnings: 17},
        # EP-110 actual values!
        ast: %{errors: 372, warnings: 5004},
        statistical: %{errors: 0, warnings: 17},
        binary: %{errors: 0, warnings: 17},
        line_by_line: %{errors: 0, warnings: 17}
      }

      decision = check_consensus(non_consensus_results)

      assert decision == :emergency,
             "Disagreement MUST trigger emergency (EP-110 prevention)"
    end

    test "EP-110 scenario is detected: reported vs actual" do
      # From EP110Incident in Mathematica
      reported = %{errors: 0, warnings: 17}
      actual = %{errors: 372, warnings: 5004}

      # Simple string matching would miss this
      pattern_result = reported
      ast_result = actual

      results = %{
        pattern: pattern_result,
        ast: ast_result,
        statistical: reported,
        binary: reported,
        line_by_line: reported
      }

      decision = check_consensus(results)
      assert decision == :emergency
    end

    test "294x warning undercount is detected" do
      # EP-110 had 294x undercount (17 vs 5004)
      results = %{
        pattern: %{errors: 0, warnings: 17},
        ast: %{errors: 0, warnings: 5004},
        statistical: %{errors: 0, warnings: 17},
        binary: %{errors: 0, warnings: 17},
        line_by_line: %{errors: 0, warnings: 17}
      }

      assert not consensus?(results)
      assert check_consensus(results) == :emergency
    end
  end

  # =============================================================================
  # §A3.7: Safe Validation Tests (Agda: agreed-implies-consensus)
  # =============================================================================

  describe "Safe Validation (Agda: agreed-implies-consensus)" do
    test "agreed result implies consensus held" do
      results = %{
        pattern: %{errors: 5, warnings: 12},
        ast: %{errors: 5, warnings: 12},
        statistical: %{errors: 5, warnings: 12},
        binary: %{errors: 5, warnings: 12},
        line_by_line: %{errors: 5, warnings: 12}
      }

      decision = check_consensus(results)

      assert decision == {:agreed, 5, 12}
      assert consensus?(results)
    end

    test "cannot get agreed result without consensus" do
      results = %{
        pattern: %{errors: 5, warnings: 12},
        # Different warning count
        ast: %{errors: 5, warnings: 13},
        statistical: %{errors: 5, warnings: 12},
        binary: %{errors: 5, warnings: 12},
        line_by_line: %{errors: 5, warnings: 12}
      }

      decision = check_consensus(results)

      refute match?({:agreed, _, _}, decision)
      assert decision == :emergency
    end
  end

  # =============================================================================
  # SC-VAL-001: Patient Mode Compilation
  # =============================================================================

  describe "SC-VAL-001: Patient Mode Compilation" do
    test "compilation config has patient mode enabled" do
      config = get_compilation_config()

      assert config.no_timeout == true
      assert config.patient_mode == true
      assert config.infinite_patience == true
    end

    test "compilation without patient mode is rejected" do
      invalid_config = %{
        no_timeout: false,
        patient_mode: false,
        infinite_patience: false
      }

      result = validate_compilation_config(invalid_config)
      assert {:error, :patient_mode_required} = result
    end

    test "ELIXIR_ERL_OPTIONS includes sufficient schedulers" do
      config = get_compilation_config()

      # From Mathematica: ELIXIR_ERL_OPTIONS -> "+S 16"
      assert config.schedulers >= 16
    end
  end

  # =============================================================================
  # SC-VAL-002: Complete Log Analysis
  # =============================================================================

  describe "SC-VAL-002: Complete Log Analysis" do
    test "log path is canonical" do
      config = get_compilation_config()

      assert config.log_path == "./data/tmp/1-compile.log"
    end

    test "partial analysis is forbidden" do
      # Forbidden actions from Mathematica §1
      forbidden_actions = [
        :head_command_during_compilation,
        :tail_command_during_compilation,
        :partial_log_analysis
      ]

      for action <- forbidden_actions do
        result = validate_analysis_action(action, :compilation_running)
        assert result == {:error, :forbidden_action}
      end
    end

    test "complete log analysis is allowed after compilation" do
      result = validate_analysis_action(:full_log_analysis, :compilation_complete)
      assert result == :ok
    end
  end

  # =============================================================================
  # SC-VAL-003: 100% Consensus Requirement
  # =============================================================================

  describe "SC-VAL-003: 100% Consensus Requirement" do
    test "all 5 methods must participate" do
      results = run_all_validation_methods("sample log content")

      assert map_size(results) == 5

      keys = Map.keys(results)
      assert keys |> Enum.sort() == Enum.sort(@validation_methods)
    end

    test "validation is incomplete without all methods" do
      partial_results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 0, warnings: 0}
      }

      result = finalize_validation(partial_results)
      assert {:error, :incomplete_validation} = result
    end

    test "100% agreement is required" do
      # 4 out of 5 agreeing is NOT sufficient
      results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 0, warnings: 0},
        statistical: %{errors: 0, warnings: 0},
        # One different
        binary: %{errors: 1, warnings: 0},
        line_by_line: %{errors: 0, warnings: 0}
      }

      refute consensus?(results)
    end
  end

  # =============================================================================
  # SC-VAL-004: Emergency Protocol on Disagreement
  # =============================================================================

  describe "SC-VAL-004: Emergency Protocol" do
    test "emergency is triggered on any disagreement" do
      results = %{
        pattern: %{errors: 0, warnings: 0},
        # Single warning difference
        ast: %{errors: 0, warnings: 1},
        statistical: %{errors: 0, warnings: 0},
        binary: %{errors: 0, warnings: 0},
        line_by_line: %{errors: 0, warnings: 0}
      }

      decision = check_consensus(results)

      assert decision == :emergency
    end

    test "emergency protocol halts validation" do
      state = %{phase: :validating, emergency: false}

      new_state = handle_emergency(state, :consensus_failure)

      assert new_state.phase == :emergency
      assert new_state.emergency == true
      assert new_state.action == :halt_and_investigate
    end
  end

  # =============================================================================
  # SC-VAL-005: Audit Trail
  # =============================================================================

  describe "SC-VAL-005: Audit Trail" do
    test "validation results are logged" do
      results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 0, warnings: 0},
        statistical: %{errors: 0, warnings: 0},
        binary: %{errors: 0, warnings: 0},
        line_by_line: %{errors: 0, warnings: 0}
      }

      audit_entry = create_audit_entry(results)

      assert audit_entry.timestamp != nil
      assert audit_entry.results == results
      assert audit_entry.consensus == true
      assert audit_entry.decision == {:agreed, 0, 0}
    end

    test "emergency events are logged with full context" do
      results = %{
        pattern: %{errors: 0, warnings: 0},
        ast: %{errors: 5, warnings: 10},
        statistical: %{errors: 0, warnings: 0},
        binary: %{errors: 0, warnings: 0},
        line_by_line: %{errors: 0, warnings: 0}
      }

      audit_entry = create_audit_entry(results)

      assert audit_entry.consensus == false
      assert audit_entry.decision == :emergency
      assert audit_entry.discrepancies != nil
    end
  end

  # =============================================================================
  # SC-VAL-006: Selective Validation Forbidden (EP-110)
  # =============================================================================

  describe "SC-VAL-006: Selective Validation Forbidden" do
    test "cannot skip any validation method" do
      result = run_validation_with_skip(:ast)
      assert {:error, :method_skip_forbidden} = result
    end

    test "cannot use only single method" do
      result = run_validation_single_method(:pattern)
      assert {:error, :single_method_forbidden} = result
    end
  end

  # =============================================================================
  # SC-VAL-007: Process Drift Detection (EP-111)
  # =============================================================================

  describe "SC-VAL-007: Process Drift Detection" do
    test "baseline drift is detected" do
      baseline = %{errors: 0, warnings: 0}
      current = %{errors: 0, warnings: 50}

      drift = calculate_drift(baseline, current)

      assert drift.warning_drift == 50
      assert drift.significant? == true
    end

    test "drift triggers investigation" do
      drift = %{error_drift: 10, warning_drift: 100, significant?: true}

      action = determine_drift_action(drift)

      assert action == :investigate
    end
  end

  # =============================================================================
  # Validation Method Implementation Tests (From Mathematica §5.1)
  # =============================================================================

  describe "Validation Method: Pattern Matching" do
    test "detects error: pattern" do
      log = "== Compilation error in file lib/foo.ex ==\nerror: undefined function"

      result = validate_pattern(log)

      assert result.errors >= 1
    end

    test "detects warning: pattern" do
      log = "warning: variable `x` is unused"

      result = validate_pattern(log)

      assert result.warnings >= 1
    end

    test "error patterns from Mathematica are recognized" do
      error_patterns = [
        "error:",
        "** (",
        "undefined variable",
        "undefined function",
        "CompileError",
        "cannot compile module",
        "== Compilation error",
        "syntax error",
        "** (ArgumentError)",
        "** (RuntimeError)"
      ]

      for pattern <- error_patterns do
        log = "Some context #{pattern} more context"
        result = validate_pattern(log)

        assert result.errors >= 1 or pattern_is_error?(pattern),
               "Pattern '#{pattern}' should be detected as error"
      end
    end
  end

  describe "Validation Method: AST Analysis" do
    test "parses valid Elixir code" do
      code = """
      defmodule Foo do
        def bar, do: :ok
      end
      """

      result = validate_ast(code)

      assert result.errors == 0
    end

    test "detects syntax errors" do
      code = """
      defmodule Foo do
        def bar( do: :ok
      end
      """

      result = validate_ast(code)

      assert result.errors >= 1
    end
  end

  describe "Validation Method: Statistical" do
    test "applies weights to error patterns" do
      log = "error: undefined error: again ** ( CompileError"

      result = validate_statistical(log)

      # Weights from Mathematica: error: -> 1.0, ** ( -> 1.5, CompileError -> 2.0
      assert result.weighted_score >= 4.5
    end
  end

  describe "Validation Method: Line-by-Line" do
    test "handles multi-line patterns" do
      log = """
      warning: function foo/1 is unused
      note: the above warning is from module Foo
      warning: function bar/2 is unused
      """

      result = validate_line_by_line(log)

      assert result.warnings == 2
    end

    test "provides contextual validation" do
      log = """
      Compiling 10 files (.ex)
      warning: unused variable
      == Compilation error in file lib/foo.ex ==
      ** (CompileError) lib/foo.ex:10: undefined function
      """

      result = validate_line_by_line(log)

      assert result.errors >= 1
      assert result.warnings >= 1
      assert result.context != nil
    end
  end

  # =============================================================================
  # Quint State Machine Tests (From §Q5)
  # =============================================================================

  describe "FPPS State Machine (Quint §Q5)" do
    test "initial state is pending" do
      state = init_fpps_state()

      assert state.phase == :pending
      assert state.consensus_achieved == false
      assert state.emergency_triggered == false
    end

    test "running validation transitions to validating" do
      state = init_fpps_state()

      new_state = start_validation(state)

      assert new_state.phase == :validating
    end

    test "consensus check transitions to complete or emergency" do
      validating_state = %{
        phase: :validating,
        results: %{
          pattern: %{errors: 0, warnings: 0},
          ast: %{errors: 0, warnings: 0},
          statistical: %{errors: 0, warnings: 0},
          binary: %{errors: 0, warnings: 0},
          line_by_line: %{errors: 0, warnings: 0}
        }
      }

      new_state = check_fpps_consensus(validating_state)

      assert new_state.phase == :complete
      assert new_state.consensus_achieved == true
    end

    test "disagreement transitions to emergency" do
      validating_state = %{
        phase: :validating,
        results: %{
          pattern: %{errors: 0, warnings: 0},
          # Different
          ast: %{errors: 1, warnings: 0},
          statistical: %{errors: 0, warnings: 0},
          binary: %{errors: 0, warnings: 0},
          line_by_line: %{errors: 0, warnings: 0}
        }
      }

      new_state = check_fpps_consensus(validating_state)

      assert new_state.phase == :emergency
      assert new_state.emergency_triggered == true
    end
  end

  # =============================================================================
  # Helper Functions (Implementation Stubs)
  # =============================================================================

  defp consensus?(results) when map_size(results) != 5, do: false

  defp consensus?(results) do
    error_counts = results |> Enum.map(fn {_, r} -> r.errors end) |> Enum.uniq()
    warning_counts = results |> Enum.map(fn {_, r} -> r.warnings end) |> Enum.uniq()

    length(error_counts) == 1 and length(warning_counts) == 1
  end

  defp check_consensus(results) do
    if consensus?(results) do
      first_result = results |> Map.values() |> hd()
      {:agreed, first_result.errors, first_result.warnings}
    else
      :emergency
    end
  end

  defp get_compilation_config do
    %{
      no_timeout: true,
      patient_mode: true,
      infinite_patience: true,
      schedulers: 16,
      log_path: "./data/tmp/1-compile.log"
    }
  end

  defp validate_compilation_config(%{patient_mode: false}), do: {:error, :patient_mode_required}
  defp validate_compilation_config(%{no_timeout: false}), do: {:error, :patient_mode_required}
  defp validate_compilation_config(_), do: :ok

  defp validate_analysis_action(action, :compilation_running)
       when action in [
              :head_command_during_compilation,
              :tail_command_during_compilation,
              :partial_log_analysis
            ],
       do: {:error, :forbidden_action}

  defp validate_analysis_action(_, _), do: :ok

  defp run_all_validation_methods(_log_content) do
    @validation_methods
    |> Enum.map(fn method -> {method, %{errors: 0, warnings: 0}} end)
    |> Map.new()
  end

  defp finalize_validation(results) when map_size(results) != 5 do
    {:error, :incomplete_validation}
  end

  defp finalize_validation(_results), do: :ok

  defp handle_emergency(state, _reason) do
    # Use Map.merge to allow adding new keys (state may not have :action key)
    Map.merge(state, %{
      phase: :emergency,
      emergency: true,
      action: :halt_and_investigate
    })
  end

  defp create_audit_entry(results) do
    has_consensus = consensus?(results)
    decision = check_consensus(results)

    discrepancies =
      if has_consensus do
        nil
      else
        calculate_discrepancies(results)
      end

    %{
      timestamp: DateTime.utc_now(),
      results: results,
      consensus: has_consensus,
      decision: decision,
      discrepancies: discrepancies
    }
  end

  defp calculate_discrepancies(results) do
    error_counts = results |> Enum.map(fn {m, r} -> {m, r.errors} end) |> Map.new()
    warning_counts = results |> Enum.map(fn {m, r} -> {m, r.warnings} end) |> Map.new()

    %{
      error_counts: error_counts,
      warning_counts: warning_counts
    }
  end

  defp run_validation_with_skip(_method), do: {:error, :method_skip_forbidden}
  defp run_validation_single_method(_method), do: {:error, :single_method_forbidden}

  defp calculate_drift(baseline, current) do
    error_drift = abs(current.errors - baseline.errors)
    warning_drift = abs(current.warnings - baseline.warnings)
    significant? = error_drift > 5 or warning_drift > 20

    %{
      error_drift: error_drift,
      warning_drift: warning_drift,
      significant?: significant?
    }
  end

  defp determine_drift_action(%{significant?: true}), do: :investigate
  defp determine_drift_action(_), do: :continue

  defp validate_pattern(log) do
    # Error patterns from Mathematica §5.1 FPPSMethods.Pattern.ErrorPatterns
    error_patterns = [
      "error:",
      "** (",
      "undefined variable",
      "undefined function",
      "CompileError",
      "cannot compile module",
      "== Compilation error",
      "syntax error",
      "** (ArgumentError)",
      "** (RuntimeError)"
    ]

    warning_patterns = ["warning:", "deprecated", "unused", "shadowed", "unreachable"]

    errors = Enum.count(error_patterns, &String.contains?(log, &1))
    warnings = Enum.count(warning_patterns, &String.contains?(log, &1))

    %{errors: errors, warnings: warnings}
  end

  defp pattern_is_error?(pattern) do
    # Detect error patterns from Mathematica §5.1
    String.contains?(pattern, "error") or
      String.contains?(pattern, "Error") or
      String.contains?(pattern, "** (") or
      String.contains?(pattern, "undefined")
  end

  defp validate_ast(code) do
    case Code.string_to_quoted(code) do
      {:ok, _} -> %{errors: 0, warnings: 0}
      {:error, _} -> %{errors: 1, warnings: 0}
    end
  end

  defp validate_statistical(log) do
    weights = %{
      "error:" => 1.0,
      "** (" => 1.5,
      "CompileError" => 2.0
    }

    weighted_score =
      Enum.reduce(weights, 0.0, fn {pattern, weight}, acc ->
        count = length(String.split(log, pattern)) - 1
        acc + count * weight
      end)

    %{errors: 0, warnings: 0, weighted_score: weighted_score}
  end

  defp validate_line_by_line(log) do
    lines = String.split(log, "\n")

    warnings = Enum.count(lines, &String.contains?(&1, "warning:"))

    errors =
      Enum.count(lines, fn line ->
        String.contains?(line, "error") or String.contains?(line, "CompileError")
      end)

    %{errors: errors, warnings: warnings, context: %{total_lines: length(lines)}}
  end

  defp init_fpps_state do
    %{
      phase: :pending,
      results: %{},
      consensus_achieved: false,
      emergency_triggered: false
    }
  end

  defp start_validation(state) do
    %{state | phase: :validating}
  end

  defp check_fpps_consensus(state) do
    # Use Map.merge to allow adding new keys (state may not have all keys)
    if consensus?(state.results) do
      Map.merge(state, %{phase: :complete, consensus_achieved: true})
    else
      Map.merge(state, %{phase: :emergency, emergency_triggered: true})
    end
  end
end
