defmodule Indrajaal.TPS.DesignReviewerTest do
  @moduledoc """
  Tests for Indrajaal.TPS.DesignReviewer - TPS Level 5 architectural review.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TPS.DesignReviewer

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(DesignReviewer)
    end

    test "review_fundamental_design/2 is exported" do
      assert function_exported?(DesignReviewer, :review_fundamental_design, 2)
    end
  end

  describe "review_fundamental_design/2" do
    test "returns a map with design analysis fields" do
      level4_results = %{
        configuration_gaps: ["timeout_missing"],
        recommended_changes: ["add_timeout"]
      }

      result = DesignReviewer.review_fundamental_design(level4_results)
      assert is_map(result)
    end

    test "result contains information_flow_design key" do
      result = DesignReviewer.review_fundamental_design(%{})
      assert Map.has_key?(result, :information_flow_design)
    end

    test "result contains accountability_structures key" do
      result = DesignReviewer.review_fundamental_design(%{})
      assert Map.has_key?(result, :accountability_structures)
    end

    test "result contains learning_mechanisms key" do
      result = DesignReviewer.review_fundamental_design(%{})
      assert Map.has_key?(result, :learning_mechanisms)
    end

    test "result contains design_recommendations key" do
      result = DesignReviewer.review_fundamental_design(%{})
      assert Map.has_key?(result, :design_recommendations)
    end

    test "accepts optional context as second argument" do
      level4 = %{gaps: []}
      context = %{design_paradigms: ["microservices"]}
      result = DesignReviewer.review_fundamental_design(level4, context)
      assert is_map(result)
    end

    test "design_recommendations contains expected sub-keys" do
      result = DesignReviewer.review_fundamental_design(%{})
      recs = result.design_recommendations
      assert is_map(recs)
      assert Map.has_key?(recs, :architectural_redesign)
    end
  end
end
