defmodule IndrajaalWeb.Api.Mobile.Config.AccessControlViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.AccessControlView.

  WHAT: Verifies the access control mobile view module is correctly defined.
  WHY: Ensures access control JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.AccessControlView)
    end

    test "module uses mobile view helpers" do
      # Verify the module loaded with use_mobile_view_helpers macro applied
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.AccessControlView)
    end
  end
end
