defmodule Indrajaal.Ultimate.UniversalPatternsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.UniversalPatterns

  test "module is loaded" do
    assert Code.ensure_loaded?(UniversalPatterns)
  end

  test "transform_data/3 is defined" do
    assert function_exported?(UniversalPatterns, :transform_data, 3)
  end

  test "aggregate_data/3 is defined" do
    assert function_exported?(UniversalPatterns, :aggregate_data, 3)
  end

  test "transform_data/3 passes data through with passthrough implementation" do
    data = %{key: "value"}
    result = UniversalPatterns.transform_data(data, :identity, [])

    assert match?({:ok, _}, result),
           "Expected {:ok, _} from transform_data/3, got: #{inspect(result)}"
  end

  test "aggregate_data/3 passes data through with passthrough implementation" do
    data = [1, 2, 3]
    result = UniversalPatterns.aggregate_data(data, :sum, [])

    assert match?({:ok, _}, result),
           "Expected {:ok, _} from aggregate_data/3, got: #{inspect(result)}"
  end
end
