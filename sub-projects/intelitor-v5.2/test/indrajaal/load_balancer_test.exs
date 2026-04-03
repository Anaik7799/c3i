defmodule LoadBalancerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(LoadBalancer)
  end

  test "select_backend/1 is exported" do
    assert function_exported?(LoadBalancer, :select_backend, 1)
  end

  test "select_backend/1 returns error tuple (stub)" do
    assert {:error, _} = LoadBalancer.select_backend("http")
  end
end
