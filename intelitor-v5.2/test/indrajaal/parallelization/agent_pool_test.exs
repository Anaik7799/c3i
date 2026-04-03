defmodule Indrajaal.Parallelization.AgentPoolTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Parallelization.AgentPool

  test "module exists" do
    assert Code.ensure_loaded?(AgentPool)
  end

  test "new/1 is exported" do
    assert function_exported?(AgentPool, :new, 1)
  end

  test "add_agent/2 is exported" do
    assert function_exported?(AgentPool, :add_agent, 2)
  end

  test "get_available_agent/1 is exported" do
    assert function_exported?(AgentPool, :get_available_agent, 1)
  end

  test "new/1 creates a pool struct" do
    pool = AgentPool.new(max_size: 10)
    assert is_struct(pool) or is_map(pool)
  end
end
