defmodule Indrajaal.Claude.MandatoryLoggingEnforcerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Claude.MandatoryLoggingEnforcer

  test "module exists" do
    assert Code.ensure_loaded?(MandatoryLoggingEnforcer)
  end

  test "start_link/1 is exported" do
    assert function_exported?(MandatoryLoggingEnforcer, :start_link, 1)
  end
end
