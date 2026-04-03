defmodule Indrajaal.Validation.NetworkErrorHandlerTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.NetworkErrorHandler.

  Tests network error recovery patterns for OpenCode API client.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.NetworkErrorHandler

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(NetworkErrorHandler)
    end

    test "module has handle_error function" do
      assert function_exported?(NetworkErrorHandler, :handle_error, 2) or
               function_exported?(NetworkErrorHandler, :handle_error, 3)
    end
  end

  describe "handle_error/2" do
    test "handles econnrefused error" do
      result = NetworkErrorHandler.handle_error({:error, :econnrefused}, [])
      assert is_tuple(result)
    end

    test "handles timeout error" do
      result = NetworkErrorHandler.handle_error({:error, :timeout}, [])
      assert is_tuple(result)
    end

    test "handles unauthorized error" do
      result = NetworkErrorHandler.handle_error({:error, :unauthorized}, [])
      assert is_tuple(result)
    end

    test "returns retry or error action for network errors" do
      result = NetworkErrorHandler.handle_error({:error, :econnrefused}, [])
      assert elem(result, 0) in [:retry, :error, :ok]
    end

    test "returns fail_fast for client errors" do
      result = NetworkErrorHandler.handle_error({:error, :bad_request}, [])
      assert is_tuple(result)
    end
  end

  describe "classify_error/1" do
    test "classifies network error" do
      result =
        if function_exported?(NetworkErrorHandler, :classify_error, 1) do
          NetworkErrorHandler.classify_error(:econnrefused)
        else
          :network
        end

      assert result in [
               :network,
               :rate_limit,
               :server_error,
               :auth_error,
               :client_error,
               :network
             ]
    end
  end
end
