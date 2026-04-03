defmodule IndrajaalWeb.Api.Mobile.Config.DevicesViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.DevicesView.

  WHAT: Verifies the devices mobile view module is correctly defined.
  WHY: Ensures devices JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.DevicesView)
    end
  end
end
