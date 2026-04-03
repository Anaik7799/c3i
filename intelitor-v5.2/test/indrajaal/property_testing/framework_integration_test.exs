defmodule Indrajaal.PropertyTesting.FrameworkIntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  # NOTE: Indrajaal.PropertyTesting.FrameworkIntegration is currently a disabled stub.
  # The entire module body is wrapped in `if false do ... end` in the source file,
  # meaning it is NOT compiled or loaded into the BEAM.

  @module_name Indrajaal.PropertyTesting.FrameworkIntegration

  test "module is a disabled stub (not loaded)" do
    refute Code.ensure_loaded?(@module_name),
           "Expected #{@module_name} to be a disabled stub (not loaded), but it is loaded."
  end

  test "stub source file exists at expected path" do
    path = "lib/indrajaal/property_testing/framework_integration.ex"
    assert File.exists?(path), "Stub source file not found at #{path}"
  end

  test "stub file contains if-false guard indicating disabled state" do
    path = "lib/indrajaal/property_testing/framework_integration.ex"
    {:ok, content} = File.read(path)
    assert String.contains?(content, "if false"), "Expected stub guard 'if false' in source file"
  end
end
