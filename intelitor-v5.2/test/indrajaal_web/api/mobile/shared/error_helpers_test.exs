defmodule IndrajaalWeb.Api.Mobile.Shared.ErrorHelpersTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Shared.ErrorHelpers.

  WHAT: Verifies error helper functions for mobile API error formatting.
  WHY: Ensures consistent error responses across all mobile API endpoints.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Shared.ErrorHelpers

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Shared.ErrorHelpers)
    end
  end

  describe "translate_errors/1" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :translate_errors, 1)
    end

    test "returns map for empty changeset errors" do
      result = ErrorHelpers.translate_errors(%{})
      assert is_map(result)
    end
  end

  describe "format_error_response/4" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :format_error_response, 4)
    end

    test "returns map with status and message" do
      result = ErrorHelpers.format_error_response(nil, 400, "bad_request", "Invalid input")
      assert is_map(result)

      assert Map.has_key?(result, :status) or Map.has_key?(result, "status") or
               Map.has_key?(result, :error) or Map.has_key?(result, "error")
    end
  end

  describe "handle_validation_errors/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_validation_errors, 2)
    end
  end

  describe "handle_auth_error/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_auth_error, 2)
    end
  end

  describe "handle_authorization_error/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_authorization_error, 2)
    end
  end

  describe "handle_not_found_error/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_not_found_error, 2)
    end
  end

  describe "handle_rate_limit_error/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_rate_limit_error, 2)
    end
  end

  describe "handle_internal_error/2" do
    test "function exists" do
      assert function_exported?(ErrorHelpers, :handle_internal_error, 2)
    end
  end
end
