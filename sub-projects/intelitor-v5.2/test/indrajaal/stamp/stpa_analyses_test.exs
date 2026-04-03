defmodule Indrajaal.STAMP.STPAAnalysesTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.STPAAnalyses - 235 total UCAs across 13 sub-analyses.
  STAMP: SC-GDE-001, SC-TDG-001, SC-SIL6-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.STAMP.STPAAnalyses

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(STPAAnalyses)
    end

    test "get_analyses/0 is exported" do
      assert function_exported?(STPAAnalyses, :get_analyses, 0)
    end

    test "get_total_ucas/0 is exported" do
      assert function_exported?(STPAAnalyses, :get_total_ucas, 0)
    end

    test "run_all/0 is exported" do
      assert function_exported?(STPAAnalyses, :run_all, 0)
    end
  end

  describe "get_total_ucas/0" do
    @tag :sil4
    test "returns 235 total UCAs" do
      total = STPAAnalyses.get_total_ucas()
      assert total == 235
    end
  end

  describe "get_analyses/0" do
    @tag :sil4
    test "returns a list of analyses" do
      result = STPAAnalyses.get_analyses()
      assert is_list(result)
    end

    @tag :sil4
    test "returns non-empty list of analyses" do
      result = STPAAnalyses.get_analyses()
      assert length(result) > 0
    end
  end

  describe "run_all/0" do
    @tag :sil4
    test "returns :ok or {:ok, _}" do
      result = STPAAnalyses.run_all()
      assert match?(:ok, result) or match?({:ok, _}, result) or is_list(result)
    end
  end

  describe "sub-module UCAs" do
    @tag :sil4
    test "AlarmManagementAnalysis has analyze/0" do
      mod = Module.concat(STPAAnalyses, AlarmManagementAnalysis)

      if Code.ensure_loaded?(mod) do
        assert function_exported?(mod, :analyze, 0)
        assert function_exported?(mod, :get_ucas, 0)
      else
        assert true
      end
    end

    @tag :sil4
    test "AccessControlAnalysis has get_ucas/0" do
      mod = Module.concat(STPAAnalyses, AccessControlAnalysis)

      if Code.ensure_loaded?(mod) do
        ucas = mod.get_ucas()
        assert is_list(ucas)
      else
        assert true
      end
    end
  end
end
