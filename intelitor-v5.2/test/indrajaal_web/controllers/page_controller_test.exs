defmodule IndrajaalWeb.PageControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.PageController.

  WHAT: Verifies the page controller home action is correctly defined.
  WHY: Ensures the application home page endpoint loads correctly.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.PageController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.PageController)
    end
  end

  describe "home/2" do
    test "function exists" do
      assert function_exported?(PageController, :home, 2)
    end
  end
end
