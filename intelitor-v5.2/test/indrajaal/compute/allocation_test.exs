defmodule Indrajaal.Compute.AllocationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.Allocation

  test "module exists" do
    assert Code.ensure_loaded?(Allocation)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Allocation, :start_link, 1)
  end

  test "request/1 is exported" do
    assert function_exported?(Allocation, :request, 1)
  end

  test "release/1 is exported" do
    assert function_exported?(Allocation, :release, 1)
  end

  test "available/1 is exported" do
    assert function_exported?(Allocation, :available, 1)
  end
end
