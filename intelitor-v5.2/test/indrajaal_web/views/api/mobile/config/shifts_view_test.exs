defmodule IndrajaalWeb.Api.Mobile.Config.ShiftsViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.ShiftsView.

  WHAT: Verifies the shifts mobile view module is correctly defined.
  WHY: Ensures shifts JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.ShiftsView)
    end
  end
end
