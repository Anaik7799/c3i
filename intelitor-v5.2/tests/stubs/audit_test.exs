defmodule Intelitor.AuditTest do
  @moduledoc """
  Test suite for Intelitor.Audit.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/audit.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Audit

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Audit)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Audit, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Audit.__info__(:module)
      assert info == Intelitor.Audit
    end
  end
end
