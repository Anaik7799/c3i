defmodule Indrajaal.ClaudeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Claude

  test "module exists" do
    assert Code.ensure_loaded?(Claude)
  end

  test "start_session/1 is exported" do
    assert function_exported?(Claude, :start_session, 1)
  end

  test "task_completed/2 is exported" do
    assert function_exported?(Claude, :task_completed, 2)
  end
end
