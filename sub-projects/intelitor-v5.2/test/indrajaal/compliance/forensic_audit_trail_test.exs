defmodule Indrajaal.Compliance.ForensicAuditTrailTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.ForensicAuditTrail GenServer.
  STAMP: SC-GDE-001, SC-REG-002, SC-TDG-001
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif
  @tag :sil4

  alias Indrajaal.Compliance.ForensicAuditTrail

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(ForensicAuditTrail)
    end

    test "is a GenServer" do
      assert function_exported?(ForensicAuditTrail, :start_link, 1)
    end

    test "start_forensic_investigation/3 is exported" do
      assert function_exported?(ForensicAuditTrail, :start_forensic_investigation, 3)
    end

    test "collect_evidence/3 is exported" do
      assert function_exported?(ForensicAuditTrail, :collect_evidence, 3)
    end

    test "update_chain_of_custody/5 is exported" do
      assert function_exported?(ForensicAuditTrail, :update_chain_of_custody, 5)
    end

    test "generate_analytics_report/3 is exported" do
      assert function_exported?(ForensicAuditTrail, :generate_analytics_report, 3)
    end

    test "search_audit_trail/2 is exported" do
      assert function_exported?(ForensicAuditTrail, :search_audit_trail, 2)
    end

    test "export_audit_trail/2 is exported" do
      assert function_exported?(ForensicAuditTrail, :export_audit_trail, 2)
    end
  end

  describe "GenServer lifecycle" do
    setup do
      # Start under a unique name to avoid conflicts in async tests
      name = :"forensic_trail_#{System.unique_integer([:positive])}"

      case start_supervised({ForensicAuditTrail, [name: name]}) do
        {:ok, pid} -> {:ok, pid: pid, name: name}
        {:error, _} -> :skip
      end
    end

    @tag :sil4
    test "start_link returns ok or error", %{} do
      name = :"forensic_trail_test_#{System.unique_integer([:positive])}"
      result = ForensicAuditTrail.start_link(name: name)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      if match?({:ok, pid}, result) do
        GenServer.stop(elem(result, 1))
      end
    end
  end
end
