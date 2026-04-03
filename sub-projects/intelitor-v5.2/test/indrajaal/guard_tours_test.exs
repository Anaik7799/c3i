defmodule Indrajaal.GuardToursTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.GuardTours

  test "module exists" do
    assert Code.ensure_loaded?(GuardTours)
  end

  test "count_active_tours/1 is exported" do
    assert function_exported?(GuardTours, :count_active_tours, 1)
  end

  test "count_active_tours/1 returns an integer" do
    result = GuardTours.count_active_tours("tenant-123")
    assert is_integer(result)
  end
end
