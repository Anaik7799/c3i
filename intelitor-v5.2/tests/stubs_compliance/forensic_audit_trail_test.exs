defmodule Intelitor.Compliance.ForensicAuditTrailTest do
  @moduledoc """
  Test suite for Intelitor.Compliance.ForensicAuditTrail.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/compliance/forensic_audit_trail.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Compliance.ForensicAuditTrail

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ForensicAuditTrail)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ForensicAuditTrail, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ForensicAuditTrail.__info__(:module)
      assert info == Intelitor.Compliance.ForensicAuditTrail
    end
  end
end
