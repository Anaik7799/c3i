defmodule IndrajaalWeb.ErrorHTMLTest do
  @moduledoc """
  Tests for IndrajaalWeb.ErrorHTML.

  WHAT: Verifies error HTML rendering functions exist.
  WHY: Ensures error pages are correctly defined for HTML responses.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.ErrorHTML

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.ErrorHTML)
    end
  end

  describe "render/2" do
    test "function exists" do
      assert function_exported?(ErrorHTML, :render, 2)
    end

    test "renders 404 template" do
      result = ErrorHTML.render("404.html", %{})

      assert is_binary(result) or is_struct(result, Phoenix.LiveView.Rendered) or
               match?({:safe, _}, result) or is_map(result)
    end

    test "renders 500 template" do
      result = ErrorHTML.render("500.html", %{})

      assert is_binary(result) or is_struct(result, Phoenix.LiveView.Rendered) or
               match?({:safe, _}, result) or is_map(result)
    end
  end
end
