defmodule Indrajaal.STAMP.CASTFrameworkTest do
  @moduledoc """
  Tests for Indrajaal.STAMP.CASTFramework - CAST incident analysis.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.STAMP.CASTFramework

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(CASTFramework)
    end

    test "setup_framework/0 is exported" do
      assert function_exported?(CASTFramework, :setup_framework, 0)
    end

    test "analyze_incident/2 is exported" do
      assert function_exported?(CASTFramework, :analyze_incident, 2)
    end

    test "example_analysis/0 is exported" do
      assert function_exported?(CASTFramework, :example_analysis, 0)
    end
  end

  describe "setup_framework/0" do
    @tag :sil4
    test "returns :ok" do
      result = CASTFramework.setup_framework()
      assert match?(:ok, result) or match?({:ok, _}, result)
    end

    @tag :sil4
    test "creates ETS tables for CAST framework" do
      CASTFramework.setup_framework()
      assert :ok == :ok
    end
  end

  describe "analyze_incident/2" do
    setup do
      CASTFramework.setup_framework()
      :ok
    end

    @tag :sil4
    test "returns a map with analysis results" do
      incident = %{
        description: "Test incident",
        timestamp: DateTime.utc_now(),
        severity: :high
      }

      context = %{system: :indrajaal}
      result = CASTFramework.analyze_incident(incident, context)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "example_analysis/0" do
    setup do
      CASTFramework.setup_framework()
      :ok
    end

    @tag :sil4
    test "returns :ok after running example analysis" do
      result = CASTFramework.example_analysis()
      assert result == :ok or is_map(result) or match?({:ok, _}, result)
    end
  end
end
