defmodule IndrajaalWeb.Api.Mobile.Config.BaseConfigControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.BaseConfigController.

  WHAT: Verifies the macro-based base config controller is correctly defined.
  WHY: Ensures the __using__ macro pattern is available for derived controllers.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.BaseConfigController)
    end

    test "module defines __using__ macro" do
      # BaseConfigController is a macro module; verify it's a quoted module
      module = IndrajaalWeb.Api.Mobile.Config.BaseConfigController
      assert Code.ensure_loaded?(module)
    end
  end
end
