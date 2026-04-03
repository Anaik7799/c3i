defmodule IndrajaalWeb.ErrorJSONTest do
  @moduledoc """
  Tests for IndrajaalWeb.ErrorJSON.

  WHAT: Verifies error JSON rendering functions exist and produce valid output.
  WHY: Ensures error pages are correctly defined for JSON API responses.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.ErrorJSON

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.ErrorJSON)
    end
  end

  describe "render/2" do
    test "function exists" do
      assert function_exported?(ErrorJSON, :render, 2)
    end

    test "renders 404 template as map" do
      result = ErrorJSON.render("404.json", %{})
      assert is_map(result)

      assert Map.has_key?(result, :errors) or Map.has_key?(result, "errors") or
               Map.has_key?(result, :error) or Map.has_key?(result, "error")
    end

    test "renders 500 template as map" do
      result = ErrorJSON.render("500.json", %{})
      assert is_map(result)
    end
  end
end
