defmodule Indrajaal.LoggingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Logging

  test "module exists" do
    assert Code.ensure_loaded?(Logging)
  end

  test "has logging functions exported" do
    assert function_exported?(Logging, :log_event, 2) or
             function_exported?(Logging, :log_info, 1) or
             function_exported?(Logging, :log_error, 2)
  end
end
