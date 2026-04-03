defmodule EnterpriseTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(Enterprise)
  end

  test "get_analytics/0 is exported" do
    assert function_exported?(Enterprise, :get_analytics, 0)
  end

  test "generate_report/1 is exported" do
    assert function_exported?(Enterprise, :generate_report, 1)
  end

  test "get_analytics/0 returns a map" do
    result = Enterprise.get_analytics()
    assert is_map(result)
  end
end
