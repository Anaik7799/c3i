defmodule IndrajaalWeb.Api.Mobile.Config.BaseMobileControllerTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Config.BaseMobileController.

  WHAT: Verifies base mobile controller authentication and validation functions.
  WHY: Ensures shared mobile controller logic is correctly defined.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use IndrajaalWeb.ConnCase, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Config.BaseMobileController

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Config.BaseMobileController)
    end
  end

  describe "public functions" do
    test "authenticate_mobile_request/2 function exists" do
      assert function_exported?(BaseMobileController, :authenticate_mobile_request, 2)
    end

    test "validate_mobile_request/2 function exists" do
      assert function_exported?(BaseMobileController, :validate_mobile_request, 2)
    end

    test "handle_mobile_error/2 function exists" do
      assert function_exported?(BaseMobileController, :handle_mobile_error, 2)
    end

    test "format_mobile_response/3 function exists" do
      assert function_exported?(BaseMobileController, :format_mobile_response, 3)
    end

    test "contains_xss?/1 function exists" do
      assert function_exported?(BaseMobileController, :contains_xss?, 1)
    end
  end

  describe "contains_xss?/1" do
    test "detects basic XSS pattern" do
      assert BaseMobileController.contains_xss?("<script>alert('xss')</script>")
    end

    test "returns false for clean input" do
      refute BaseMobileController.contains_xss?("clean input text")
    end
  end
end
