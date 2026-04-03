defmodule Indrajaal.TPS.SurfaceCauseDetectorTest do
  @moduledoc """
  Tests for Indrajaal.TPS.SurfaceCauseDetector - TPS Level 2 RCA.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TPS.SurfaceCauseDetector

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SurfaceCauseDetector)
    end

    test "detect_surface_causes/2 is exported" do
      assert function_exported?(SurfaceCauseDetector, :detect_surface_causes, 2)
    end
  end

  describe "detect_surface_causes/2" do
    test "returns a map" do
      level1_results = %{symptoms: ["slow_response"], severity: :medium}
      result = SurfaceCauseDetector.detect_surface_causes(level1_results)
      assert is_map(result)
    end

    test "result contains information_flow key" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result, :information_flow)
    end

    test "result contains communication_channels key" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result, :communication_channels)
    end

    test "result contains message_clarity key" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result, :message_clarity)
    end

    test "result contains feedback_loops key" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result, :feedback_loops)
    end

    test "result contains escalation_paths key" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result, :escalation_paths)
    end

    test "accepts context as second argument" do
      level1 = %{symptoms: []}
      context = %{environment: :production}
      result = SurfaceCauseDetector.detect_surface_causes(level1, context)
      assert is_map(result)
    end

    test "information_flow has flow_quality field" do
      result = SurfaceCauseDetector.detect_surface_causes(%{})
      assert Map.has_key?(result.information_flow, :flow_quality)
    end
  end
end
