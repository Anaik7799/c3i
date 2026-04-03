defmodule Indrajaal.Compute.BudgetTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Budget

  test "module exists" do
    assert Code.ensure_loaded?(Budget)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Budget, :start_link, 1)
  end

  test "allocate/3 is exported" do
    assert function_exported?(Budget, :allocate, 3)
  end

  test "get/1 is exported" do
    assert function_exported?(Budget, :get, 1)
  end

  test "remaining/1 is exported" do
    assert function_exported?(Budget, :remaining, 1)
  end
end
