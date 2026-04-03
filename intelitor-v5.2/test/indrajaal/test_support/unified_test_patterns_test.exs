defmodule Indrajaal.TestSupport.UnifiedTestPatternsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TestSupport.UnifiedTestPatterns

  test "module exists" do
    assert Code.ensure_loaded?(UnifiedTestPatterns)
  end

  test "run/3 is exported" do
    assert function_exported?(UnifiedTestPatterns, :run, 3)
  end

  test "mock_external_service/2 is exported" do
    assert function_exported?(UnifiedTestPatterns, :mock_external_service, 2)
  end

  test "get_mock_response/1 is exported" do
    assert function_exported?(UnifiedTestPatterns, :get_mock_response, 1)
  end

  test "mock_external_service/2 stores mock and returns :ok" do
    result = UnifiedTestPatterns.mock_external_service(:test_service, %{status: :ok})
    assert result == :ok
  end

  test "get_mock_response/1 retrieves stored mock" do
    UnifiedTestPatterns.mock_external_service(:my_svc, %{data: "value"})
    response = UnifiedTestPatterns.get_mock_response(:my_svc)
    assert response == %{data: "value"}
  end
end
