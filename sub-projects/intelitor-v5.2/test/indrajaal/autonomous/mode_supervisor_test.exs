defmodule Indrajaal.Autonomous.ModeSupervisorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Autonomous.ModeSupervisor

  test "module exists" do
    assert Code.ensure_loaded?(ModeSupervisor)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ModeSupervisor, :start_link, 1)
  end

  test "execute_mission/1 is exported" do
    assert function_exported?(ModeSupervisor, :execute_mission, 1)
  end

  test "get_status/0 is exported" do
    assert function_exported?(ModeSupervisor, :get_status, 0)
  end
end
