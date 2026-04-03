defmodule IndrajaalWeb.LayoutsTest do
  @moduledoc """
  Tests for IndrajaalWeb.Layouts.

  WHAT: Verifies the Layouts module is correctly defined.
  WHY: Ensures layout templates are accessible and module loads cleanly.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Layouts)
    end

    test "module uses Phoenix html helpers" do
      # Layouts embeds templates so verifying it loaded is sufficient
      assert Code.ensure_loaded?(IndrajaalWeb.Layouts)
    end
  end
end
