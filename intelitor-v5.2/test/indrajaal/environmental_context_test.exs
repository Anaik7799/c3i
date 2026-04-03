defmodule Indrajaal.EnvironmentalContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.EnvironmentalContext

  test "module exists" do
    assert Code.ensure_loaded?(EnvironmentalContext)
  end

  test "list_environmental/1 is exported" do
    assert function_exported?(EnvironmentalContext, :list_environmental, 1)
  end

  test "create_environmental/2 is exported" do
    assert function_exported?(EnvironmentalContext, :create_environmental, 2)
  end
end
