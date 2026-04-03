defmodule Indrajaal.Validation.OpenCodeAPIClientTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.OpenCodeAPIClient

  test "module exists" do
    assert Code.ensure_loaded?(OpenCodeAPIClient)
  end

  test "health_check/0 is exported" do
    assert function_exported?(OpenCodeAPIClient, :health_check, 0)
  end

  test "validate_code/1 is exported" do
    assert function_exported?(OpenCodeAPIClient, :validate_code, 1)
  end

  test "get_validation_results/1 is exported" do
    assert function_exported?(OpenCodeAPIClient, :get_validation_results, 1)
  end

  test "health_check/0 returns not implemented error (stub)" do
    assert {:error, _reason} = OpenCodeAPIClient.health_check()
  end

  test "validate_code/1 returns not implemented error (stub)" do
    assert {:error, _reason} = OpenCodeAPIClient.validate_code("defmodule Test do end")
  end

  test "get_validation_results/1 returns not implemented error (stub)" do
    assert {:error, _reason} = OpenCodeAPIClient.get_validation_results("request-id-123")
  end
end
