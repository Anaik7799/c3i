defmodule Intelitor.ComplianceDomainTest do
  @moduledoc """
  Test suite for Intelitor.ComplianceDomain.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/compliance_domain.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.ComplianceDomain

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ComplianceDomain)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ComplianceDomain, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ComplianceDomain.__info__(:module)
      assert info == Intelitor.ComplianceDomain
    end
  end
end
