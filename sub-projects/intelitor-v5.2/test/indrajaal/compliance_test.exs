defmodule Indrajaal.ComplianceTest do
  @moduledoc """
  Tests for Indrajaal.Compliance context module.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(Indrajaal.Compliance)
    end

    test "list_compliance/1 is exported" do
      assert function_exported?(Compliance, :list_compliance, 1)
    end

    test "create_policy/2 is exported" do
      assert function_exported?(Compliance, :create_policy, 2)
    end

    test "create_assessment/1 is exported" do
      assert function_exported?(Compliance, :create_assessment, 1)
    end

    test "create_audit_report/1 is exported" do
      assert function_exported?(Compliance, :create_audit_report, 1)
    end

    test "create_document/1 is exported" do
      assert function_exported?(Compliance, :create_document, 1)
    end

    test "create_framework/1 is exported" do
      assert function_exported?(Compliance, :create_framework, 1)
    end

    test "create_requirement/1 is exported" do
      assert function_exported?(Compliance, :create_requirement, 1)
    end
  end

  describe "list_compliance/1" do
    @tag :sil4
    test "returns :ok tuple or :error tuple" do
      result = Compliance.list_compliance([])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    @tag :sil4
    test "returns {:ok, list} when no actor" do
      # Stub mode: no valid actor -> returns {:ok, []}
      result = Compliance.list_compliance([])
      assert {:ok, items} = result
      assert is_list(items)
    end
  end
end
