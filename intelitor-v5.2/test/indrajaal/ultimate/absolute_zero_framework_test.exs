defmodule Indrajaal.Ultimate.AbsoluteZeroFrameworkTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.AbsoluteZeroFramework

  test "module is loaded" do
    assert Code.ensure_loaded?(AbsoluteZeroFramework)
  end

  test "consolidate_pattern/2 is defined" do
    assert function_exported?(AbsoluteZeroFramework, :consolidate_pattern, 2)
  end

  test "consolidate_pattern/2 handles :query_building pattern passthrough" do
    data = %{key: "value"}
    result = AbsoluteZeroFramework.consolidate_pattern(data, :query_building)
    assert result == data
  end

  test "consolidate_pattern/2 handles unknown pattern passthrough" do
    data = "some_data"
    result = AbsoluteZeroFramework.consolidate_pattern(data, :unknown_pattern)
    assert result == data
  end
end
