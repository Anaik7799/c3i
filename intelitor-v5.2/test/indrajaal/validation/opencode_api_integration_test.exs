defmodule Indrajaal.Validation.OpenCodeApiIntegrationTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.OpenCodeApiIntegration.

  Tests the unified OpenCode API integration facade.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.OpenCodeApiIntegration

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(OpenCodeApiIntegration)
    end

    test "init/0 is exported" do
      assert function_exported?(OpenCodeApiIntegration, :init, 0)
    end

    test "validate_code/2 is exported" do
      assert function_exported?(OpenCodeApiIntegration, :validate_code, 2)
    end

    test "health_check/0 is exported" do
      assert function_exported?(OpenCodeApiIntegration, :health_check, 0)
    end

    test "get_validation_status/2 is exported" do
      assert function_exported?(OpenCodeApiIntegration, :get_validation_status, 2)
    end

    test "validate_batch/2 is exported" do
      assert function_exported?(OpenCodeApiIntegration, :validate_batch, 2)
    end
  end

  describe "health_check/0" do
    test "returns a map" do
      result = OpenCodeApiIntegration.health_check()
      assert is_map(result)
    end

    test "health map contains integration key" do
      result = OpenCodeApiIntegration.health_check()
      assert Map.has_key?(result, :integration)
    end

    test "integration status is :healthy" do
      result = OpenCodeApiIntegration.health_check()
      assert result.integration == :healthy
    end

    test "health map contains circuit_breaker key" do
      result = OpenCodeApiIntegration.health_check()
      assert Map.has_key?(result, :circuit_breaker)
    end

    test "health map contains rate_limiter key" do
      result = OpenCodeApiIntegration.health_check()
      assert Map.has_key?(result, :rate_limiter)
    end
  end
end
