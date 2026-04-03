defmodule Indrajaal.Compilation.ClaudeInterfaceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compilation.ClaudeInterface

  test "module exists" do
    assert Code.ensure_loaded?(ClaudeInterface)
  end

  test "start_link/2 is exported" do
    assert function_exported?(ClaudeInterface, :start_link, 2)
  end

  test "execute_action/3 is exported" do
    assert function_exported?(ClaudeInterface, :execute_action, 3)
  end
end
