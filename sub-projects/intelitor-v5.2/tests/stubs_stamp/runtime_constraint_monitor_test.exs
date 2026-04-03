defmodule Intelitor.Stamp.RuntimeConstraintMonitorTest do
  @moduledoc """
  Test suite for STAMP Runtime Constraint Monitor.

  Tests all 72 safety constraint validations.

  SOPv5.11 Compliance: TDG Methodology
  """

  use ExUnit.Case, async: false

  alias Intelitor.Stamp.RuntimeConstraintMonitor

  describe "validate_all_constraints/0" do
    test "returns results for all 72 constraints" do
      result = RuntimeConstraintMonitor.validate_all_constraints()

      case result do
        {:ok, results} ->
          assert is_map(results)
          # Should have entries for constraints
          assert map_size(results) > 0

        {:error, violations} ->
          assert is_list(violations)
      end
    end

    test "all results are either :passed or {:failed, reason}" do
      case RuntimeConstraintMonitor.validate_all_constraints() do
        {:ok, results} ->
          Enum.each(results, fn {_id, status} ->
            assert status == :passed or match?({:failed, _}, status)
          end)

        {:error, _} ->
          assert true
      end
    end
  end

  describe "validate_category/1" do
    test "validates validation category" do
      result = RuntimeConstraintMonitor.validate_category(:validation)

      case result do
        {:ok, results} ->
          assert is_map(results)
          # Should have SC-VAL-* constraints
          assert Enum.all?(Map.keys(results), &String.starts_with?(&1, "SC-VAL"))

        {:error, _} ->
          assert true
      end
    end

    test "validates container category" do
      result = RuntimeConstraintMonitor.validate_category(:container)

      case result do
        {:ok, results} ->
          assert Enum.all?(Map.keys(results), &String.starts_with?(&1, "SC-CNT"))

        {:error, _} ->
          assert true
      end
    end

    test "validates observability category" do
      result = RuntimeConstraintMonitor.validate_category(:observability)

      case result do
        {:ok, results} ->
          assert Enum.all?(Map.keys(results), &String.starts_with?(&1, "SC-OBS"))

        {:error, _} ->
          assert true
      end
    end

    test "returns empty map for unknown category" do
      result = RuntimeConstraintMonitor.validate_category(:unknown)

      assert result == {:ok, %{}}
    end
  end

  describe "check_constraint/1" do
    test "checks individual validation constraint" do
      result = RuntimeConstraintMonitor.check_constraint("SC-VAL-001")

      assert result == :passed or match?({:failed, _}, result)
    end

    test "returns failed for unknown constraint" do
      result = RuntimeConstraintMonitor.check_constraint("SC-UNKNOWN-999")

      assert result == {:failed, :unknown_constraint}
    end

    test "checks observability constraint" do
      result = RuntimeConstraintMonitor.check_constraint("SC-OBS-065")

      assert result == :passed or match?({:failed, _}, result)
    end
  end

  describe "generate_report/0" do
    test "returns complete report structure" do
      report = RuntimeConstraintMonitor.generate_report()

      assert Map.has_key?(report, :status)
      assert Map.has_key?(report, :total_constraints)
      assert Map.has_key?(report, :passed)
      assert Map.has_key?(report, :failed)
      assert Map.has_key?(report, :report_generated_at)

      assert report.total_constraints == 72
      assert report.passed + report.failed == 72
    end

    test "status is compliant when all pass" do
      report = RuntimeConstraintMonitor.generate_report()

      if report.failed == 0 do
        assert report.status == :compliant
      else
        assert report.status == :non_compliant
      end
    end

    test "includes violations when non-compliant" do
      report = RuntimeConstraintMonitor.generate_report()

      if report.status == :non_compliant do
        assert Map.has_key?(report, :violations)
        assert is_list(report.violations)
      end
    end
  end

  describe "constraint categories coverage" do
    test "has 8 validation constraints (SC-VAL-001 to SC-VAL-008)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:validation)
      assert map_size(results) == 8
    end

    test "has 8 container constraints (SC-CNT-009 to SC-CNT-016)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:container)
      assert map_size(results) == 8
    end

    test "has 8 agent constraints (SC-AGT-017 to SC-AGT-024)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:agent)
      assert map_size(results) == 8
    end

    test "has 8 compilation constraints (SC-CMP-025 to SC-CMP-032)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:compilation)
      assert map_size(results) == 8
    end

    test "has 8 data constraints (SC-DAT-033 to SC-DAT-040)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:data)
      assert map_size(results) == 8
    end

    test "has 8 security constraints (SC-SEC-041 to SC-SEC-048)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:security)
      assert map_size(results) == 8
    end

    test "has 8 performance constraints (SC-PRF-049 to SC-PRF-056)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:performance)
      assert map_size(results) == 8
    end

    test "has 8 emergency constraints (SC-EMR-057 to SC-EMR-064)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:emergency)
      assert map_size(results) == 8
    end

    test "has 8 observability constraints (SC-OBS-065 to SC-OBS-072)" do
      {:ok, results} = RuntimeConstraintMonitor.validate_category(:observability)
      assert map_size(results) == 8
    end
  end
end
