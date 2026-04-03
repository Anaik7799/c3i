defmodule Indrajaal.PropertyTesting.EdgeCaseAnalyzerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  # NOTE: Indrajaal.PropertyTesting.EdgeCaseAnalyzer is currently a disabled stub.
  # The entire module body is wrapped in `if false do ... end` in the source file,
  # meaning it is NOT compiled or loaded into the BEAM.
  # These tests document the current stub state and will be updated when the stub
  # is replaced with a real implementation (Sprint 54+).

  @module_name Indrajaal.PropertyTesting.EdgeCaseAnalyzer

  test "module is a disabled stub (not loaded)" do
    # The module source exists but is wrapped in `if false`, so it is not compiled.
    refute Code.ensure_loaded?(@module_name),
           "Expected #{@module_name} to be a disabled stub (not loaded), but it is loaded. " <>
             "Update this test when the stub is replaced with a real implementation."
  end

  test "stub source file exists at expected path" do
    path =
      "lib/indrajaal/property_testing/edge_case_analyzer.ex"

    assert File.exists?(path),
           "Stub source file not found at #{path}"
  end

  test "stub file contains if-false guard indicating disabled state" do
    path = "lib/indrajaal/property_testing/edge_case_analyzer.ex"
    {:ok, content} = File.read(path)

    assert String.contains?(content, "if false"),
           "Expected stub guard 'if false' in source file"
  end
end
