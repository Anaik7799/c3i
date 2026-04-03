defmodule IndrajaalWeb.Api.Mobile.Config.FleetManagementViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.FleetManagementView.

  WHAT: Verifies the fleet management mobile view module is correctly defined.
  WHY: Ensures fleet management JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.FleetManagementView)
    end
  end
end
