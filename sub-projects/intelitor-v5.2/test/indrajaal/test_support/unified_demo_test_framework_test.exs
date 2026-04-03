defmodule Indrajaal.TestSupport.UnifiedDemoTestFrameworkTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.TestSupport.UnifiedDemoTestFramework

  test "module exists" do
    assert Code.ensure_loaded?(UnifiedDemoTestFramework)
  end

  test "run/1 is exported" do
    assert function_exported?(UnifiedDemoTestFramework, :run, 1)
  end

  test "validate_container_health/1 is exported" do
    assert function_exported?(UnifiedDemoTestFramework, :validate_container_health, 1)
  end

  test "run/1 returns a result for default args" do
    result = UnifiedDemoTestFramework.run(%{})
    assert not is_nil(result)
  end
end
