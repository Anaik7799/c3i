defmodule Indrajaal.ComplianceDomainTest do
  @moduledoc """
  Tests for Indrajaal.ComplianceDomain Ash domain.
  STAMP: SC-GDE-001, SC-DB-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ComplianceDomain

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(ComplianceDomain)
    end

    test "spark_is/0 is exported (Ash domain marker)" do
      assert function_exported?(ComplianceDomain, :spark_is, 0)
    end
  end

  describe "domain resources" do
    test "domain includes AuditReport resource" do
      resources = Ash.Domain.Info.resources(ComplianceDomain)
      assert Enum.any?(resources, fn r -> to_string(r) =~ "AuditReport" end)
    end

    test "domain includes Document resource" do
      resources = Ash.Domain.Info.resources(ComplianceDomain)
      assert Enum.any?(resources, fn r -> to_string(r) =~ "Document" end)
    end

    test "domain includes Report resource" do
      resources = Ash.Domain.Info.resources(ComplianceDomain)
      assert Enum.any?(resources, fn r -> to_string(r) =~ "Report" end)
    end

    test "domain includes Requirement resource" do
      resources = Ash.Domain.Info.resources(ComplianceDomain)
      assert Enum.any?(resources, fn r -> to_string(r) =~ "Requirement" end)
    end

    test "domain has at least one resource" do
      resources = Ash.Domain.Info.resources(ComplianceDomain)
      assert length(resources) > 0
    end
  end
end
