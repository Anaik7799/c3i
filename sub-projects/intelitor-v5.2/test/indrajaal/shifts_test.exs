defmodule Indrajaal.ShiftsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shifts

  test "module exists" do
    assert Code.ensure_loaded?(Shifts)
  end

  test "list_shifts/1 is exported" do
    assert function_exported?(Shifts, :list_shifts, 1)
  end

  test "get_shift/2 is exported" do
    assert function_exported?(Shifts, :get_shift, 2)
  end

  test "create_shift/2 is exported" do
    assert function_exported?(Shifts, :create_shift, 2)
  end

  test "update_shift/3 is exported" do
    assert function_exported?(Shifts, :update_shift, 3)
  end

  test "delete_shift/2 is exported" do
    assert function_exported?(Shifts, :delete_shift, 2)
  end
end
