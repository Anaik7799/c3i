defmodule Indrajaal.AuditTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Audit

  test "module exists" do
    assert Code.ensure_loaded?(Audit)
  end

  test "create_log/1 is exported" do
    assert function_exported?(Audit, :create_log, 1)
  end

  test "log_security_event/2 is exported" do
    assert function_exported?(Audit, :log_security_event, 2)
  end
end
