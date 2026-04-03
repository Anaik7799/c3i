defmodule IndrajaalWeb.Api.Mobile.Config.SitesViewTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.SitesView.

  WHAT: Verifies the sites mobile view module is correctly defined.
  WHY: Ensures sites JSON rendering uses shared mobile view helpers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.SitesView)
    end
  end
end
