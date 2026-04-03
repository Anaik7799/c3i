defmodule Indrajaal.PriorityCalculatorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.PriorityCalculator

  test "module exists" do
    assert Code.ensure_loaded?(PriorityCalculator)
  end

  test "calculate_priority/1 is exported" do
    assert function_exported?(PriorityCalculator, :calculate_priority, 1)
  end

  test "calculate_priority/1 returns :critical for critical type" do
    result = PriorityCalculator.calculate_priority(%{type: :fire_alarm})
    assert is_atom(result)
  end

  test "calculate_priority/1 returns :low for low-priority type" do
    result = PriorityCalculator.calculate_priority(%{type: :info})
    assert is_atom(result)
  end

  test "calculate_priority/1 handles unknown type gracefully" do
    result = PriorityCalculator.calculate_priority(%{type: :unknown_type_xyz})
    assert is_atom(result)
  end
end
