defmodule IndrajaalWeb.PageHTMLTest do
  @moduledoc """
  Tests for IndrajaalWeb.PageHTML.

  WHAT: Verifies the PageHTML template module is correctly defined.
  WHY: Ensures page HTML templates are embedded and accessible.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.PageHTML)
    end
  end
end
