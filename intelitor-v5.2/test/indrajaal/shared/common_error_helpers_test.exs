defmodule Indrajaal.Shared.CommonErrorHelpersTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.CommonErrorHelpers

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CommonErrorHelpers)
    end
  end

  describe "log_structured_error/3" do
    test "function is exported" do
      assert function_exported?(CommonErrorHelpers, :log_structured_error, 3)
    end

    test "logs an error tuple without raising" do
      result = CommonErrorHelpers.log_structured_error({:error, :not_found}, %{}, %{})
      assert result == :ok or is_nil(result) or is_map(result)
    end

    test "logs a string error without raising" do
      result = CommonErrorHelpers.log_structured_error("something went wrong", %{}, %{})
      assert result == :ok or is_nil(result) or is_map(result)
    end

    test "accepts metadata map" do
      result =
        CommonErrorHelpers.log_structured_error(
          {:error, :timeout},
          %{module: "TestModule", function: "test/0"},
          %{request_id: "req-123"}
        )

      assert result == :ok or is_nil(result) or is_map(result)
    end
  end

  describe "format_error_response/2" do
    test "function is exported" do
      assert function_exported?(CommonErrorHelpers, :format_error_response, 2)
    end

    test "returns a formatted error map for :not_found" do
      result = CommonErrorHelpers.format_error_response(:not_found, %{})
      assert is_map(result)
    end

    test "returns formatted error for error tuple" do
      result = CommonErrorHelpers.format_error_response({:error, :unauthorized}, %{})
      assert is_map(result)
    end

    test "formatted response contains error information" do
      result = CommonErrorHelpers.format_error_response(:invalid_input, %{})
      assert is_map(result)
      # Should have at least one key
      assert map_size(result) > 0
    end
  end
end
