defmodule Indrajaal.Compliance.AuditReportTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.AuditReport Ash resource.
  STAMP: SC-GDE-001, SC-DB-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.AuditReport

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(AuditReport)
    end

    test "is an Ash resource (has spark_is/0)" do
      assert function_exported?(AuditReport, :spark_is, 0)
    end
  end

  describe "code interface" do
    test "get/1 function is exported via code_interface" do
      assert function_exported?(AuditReport, :get, 1) or
               function_exported?(AuditReport, :get, 2)
    end

    test "list/0 function is exported via code_interface" do
      assert function_exported?(AuditReport, :list, 0) or
               function_exported?(AuditReport, :list, 1)
    end

    test "create/1 function is exported via code_interface" do
      assert function_exported?(AuditReport, :create, 1) or
               function_exported?(AuditReport, :create, 2)
    end
  end

  describe "resource schema" do
    test "spark_is returns the Ash.Resource marker" do
      # spark_is/0 identifies this as an Ash.Resource
      assert AuditReport.spark_is() == Ash.Resource
    end
  end
end
