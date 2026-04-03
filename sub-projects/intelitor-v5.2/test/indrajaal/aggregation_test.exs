defmodule Indrajaal.AggregationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Aggregation

  test "module exists" do
    assert Code.ensure_loaded?(Aggregation)
  end

  test "create_system_status_components/2 is exported" do
    assert function_exported?(Aggregation, :create_system_status_components, 2)
  end
end
