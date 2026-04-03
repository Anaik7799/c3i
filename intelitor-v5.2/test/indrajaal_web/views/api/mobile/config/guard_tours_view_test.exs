defmodule IndrajaalWeb.Api.Mobile.Config.GuardToursViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.GuardToursView.

  WHAT: Verifies the guard tours mobile view module is correctly defined.
  WHY: Ensures guard tours JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.GuardToursView)
    end
  end
end
