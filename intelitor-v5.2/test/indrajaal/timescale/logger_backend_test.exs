defmodule Indrajaal.Timescale.LoggerBackendTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Timescale.LoggerBackend

  test "module exists" do
    assert Code.ensure_loaded?(LoggerBackend)
  end

  test "init/1 is exported (gen_event callback)" do
    assert function_exported?(LoggerBackend, :init, 1)
  end

  test "handle_event/2 is exported (gen_event callback)" do
    assert function_exported?(LoggerBackend, :handle_event, 2)
  end

  test "handle_call/2 is exported (gen_event callback)" do
    assert function_exported?(LoggerBackend, :handle_call, 2)
  end
end
