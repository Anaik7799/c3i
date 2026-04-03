defmodule Indrajaal.Parallelization.ResourceManagerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Parallelization.ResourceManager

  test "module exists" do
    assert Code.ensure_loaded?(ResourceManager)
  end

  test "new/0 is exported" do
    assert function_exported?(ResourceManager, :new, 0)
  end

  test "allocate_resources/2 is exported" do
    assert function_exported?(ResourceManager, :allocate_resources, 2)
  end

  test "new/0 creates a manager struct" do
    manager = ResourceManager.new()
    assert is_struct(manager) or is_map(manager)
  end
end
