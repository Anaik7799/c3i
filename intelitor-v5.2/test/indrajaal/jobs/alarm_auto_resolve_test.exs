defmodule Indrajaal.Jobs.AlarmAutoResolveTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Jobs.AlarmAutoResolve

  test "module exists" do
    assert Code.ensure_loaded?(AlarmAutoResolve)
  end

  test "perform/1 is exported" do
    assert function_exported?(AlarmAutoResolve, :perform, 1)
  end

  test "schedule_if_eligible/1 is exported" do
    assert function_exported?(AlarmAutoResolve, :schedule_if_eligible, 1)
  end
end
