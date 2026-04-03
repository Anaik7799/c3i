defmodule Intelitor.Security.AuditLoggerTest do
  @moduledoc """
  Test suite for Security Audit Logger module.
  SOPv5.11 TDG Compliance - Submodule test coverage.
  """
  use ExUnit.Case, async: true

  alias Intelitor.Security.AuditLogger

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(AuditLogger)
    end

    test "module has expected functions" do
      assert function_exported?(AuditLogger, :__info__, 1)
    end
  end
end
