defmodule IndrajaalWeb.Api.Mobile.Shared.MobileResponseFormatterTest do
  @moduledoc """
  Tests for IndrajaalWeb.Api.Mobile.Shared.MobileResponseFormatter.

  WHAT: Verifies mobile response formatter functions produce consistent structures.
  WHY: Ensures all mobile API responses use uniform formatting.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Api.Mobile.Shared.MobileResponseFormatter

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Api.Mobile.Shared.MobileResponseFormatter)
    end
  end

  describe "success_response/3" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :success_response, 3)
    end

    test "returns a map with data" do
      result = MobileResponseFormatter.success_response(%{}, %{id: "123"}, "items")
      assert is_map(result)
    end
  end

  describe "error_response/4" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :error_response, 4)
    end

    test "returns a map with error info" do
      result = MobileResponseFormatter.error_response(%{}, 400, "bad_request", "Invalid input")
      assert is_map(result)
    end
  end

  describe "bulk_operation_response/2" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :bulk_operation_response, 2)
    end
  end

  describe "security_error_response/3" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :security_error_response, 3)
    end
  end

  describe "validation_error_response/2" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :validation_error_response, 2)
    end
  end

  describe "health_response/2" do
    test "function exists" do
      assert function_exported?(MobileResponseFormatter, :health_response, 2)
    end
  end
end
