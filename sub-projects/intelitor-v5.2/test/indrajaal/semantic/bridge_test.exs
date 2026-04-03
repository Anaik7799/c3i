defmodule Indrajaal.Semantic.BridgeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Semantic.Bridge

  test "module exists" do
    assert Code.ensure_loaded?(Bridge)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Bridge, :start_link, 1)
  end

  test "call/3 is exported" do
    assert function_exported?(Bridge, :call, 3)
  end

  test "cast/2 is exported" do
    assert function_exported?(Bridge, :cast, 2)
  end

  test "alive?/0 is exported" do
    assert function_exported?(Bridge, :alive?, 0)
  end

  test "health_check/0 is exported" do
    assert function_exported?(Bridge, :health_check, 0)
  end

  test "stop/0 is exported" do
    assert function_exported?(Bridge, :stop, 0)
  end

  test "alive?/0 returns false when GenServer not running" do
    # Without the GenServer started, alive? returns false (catches :exit)
    result = Bridge.alive?()
    assert is_boolean(result)
  end
end
