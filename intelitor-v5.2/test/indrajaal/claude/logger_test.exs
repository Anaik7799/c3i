defmodule Indrajaal.Claude.LoggerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Claude.Logger, as: ClaudeLogger

  test "module exists" do
    assert Code.ensure_loaded?(ClaudeLogger)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ClaudeLogger, :start_link, 1)
  end
end
