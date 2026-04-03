defmodule Indrajaal.Shared.UnifiedErrorSystemTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.UnifiedErrorSystem

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(UnifiedErrorSystem)
    end
  end

  describe "log_structured_error/2" do
    test "function is exported" do
      assert function_exported?(UnifiedErrorSystem, :log_structured_error, 2)
    end

    test "logs error and returns it" do
      error = {:error, :not_found}
      result = UnifiedErrorSystem.log_structured_error(error, %{})
      assert result == error
    end

    test "logs string error and returns it" do
      error = "something bad happened"
      result = UnifiedErrorSystem.log_structured_error(error, %{})
      assert result == error
    end

    test "accepts metadata map" do
      result =
        UnifiedErrorSystem.log_structured_error(:timeout, %{
          module: "TestModule",
          context: "test run"
        })

      assert result == :timeout
    end
  end

  describe "format_error/1" do
    test "function is exported" do
      assert function_exported?(UnifiedErrorSystem, :format_error, 1)
    end

    test "formats error tuple as string" do
      result = UnifiedErrorSystem.format_error({:error, :not_found})
      assert is_binary(result)
    end

    test "formats exception as string" do
      result = UnifiedErrorSystem.format_error(%RuntimeError{message: "oops"})
      assert is_binary(result)
      assert String.contains?(result, "oops")
    end

    test "formats atom as string" do
      result = UnifiedErrorSystem.format_error(:timeout)
      assert is_binary(result)
    end
  end

  describe "errorresponse/2" do
    test "function is exported" do
      assert function_exported?(UnifiedErrorSystem, :errorresponse, 2)
    end

    test "returns error response map" do
      result = UnifiedErrorSystem.errorresponse({:error, :not_found}, :not_found)
      assert is_map(result)
    end

    test "response has error: true" do
      result = UnifiedErrorSystem.errorresponse(:timeout, :internal_server_error)
      assert result.error == true
    end

    test "response has message field" do
      result = UnifiedErrorSystem.errorresponse({:error, :unauthorized}, :unauthorized)
      assert Map.has_key?(result, :message)
      assert is_binary(result.message)
    end

    test "response has timestamp field" do
      result = UnifiedErrorSystem.errorresponse(:bad_request, :bad_request)
      assert Map.has_key?(result, :timestamp)
    end

    test "uses default status when not provided" do
      result = UnifiedErrorSystem.errorresponse(:timeout)
      assert is_map(result)
    end
  end

  describe "handle_mobile_api_error/2" do
    test "function is exported" do
      assert function_exported?(UnifiedErrorSystem, :handle_mobile_api_error, 2)
    end

    test "returns formatted error response" do
      result = UnifiedErrorSystem.handle_mobile_api_error(%{}, {:error, :invalid_token})
      assert is_map(result)
      assert result.error == true
    end
  end

  describe "handle_result/1" do
    test "function is exported" do
      assert function_exported?(UnifiedErrorSystem, :handle_result, 1)
    end

    test "passes through ok tuple" do
      assert {:ok, 42} = UnifiedErrorSystem.handle_result({:ok, 42})
    end

    test "passes through error tuple" do
      assert match?({:error, _}, UnifiedErrorSystem.handle_result({:error, :not_found}))
    end

    test "wraps plain values in ok" do
      result = UnifiedErrorSystem.handle_result("plain_value")
      assert match?({:ok, _}, result)
    end
  end
end
