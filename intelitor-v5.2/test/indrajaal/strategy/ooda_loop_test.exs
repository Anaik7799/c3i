defmodule Indrajaal.Strategy.OODALoopTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Strategy.OODALoop

  test "module exists" do
    assert Code.ensure_loaded?(OODALoop)
  end

  test "start_link/1 is exported" do
    assert function_exported?(OODALoop, :start_link, 1)
  end
end
