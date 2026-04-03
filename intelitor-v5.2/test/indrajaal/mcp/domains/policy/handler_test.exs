defmodule Indrajaal.MCP.Domains.Policy.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Policy Handler.

  Tests 10 tools for policy rule evaluation, enforcement management,
  and compliance checking.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-073: Handler dispatch MUST use atom-based multi-clause pattern matching
  - SC-SAFETY-005: Access control enforced

  ## TPS 5-Level RCA Context
  - L1 Symptom: Policy evaluation returns unexpected decision
  - L5 Root Cause: Missing rule conditions or malformed request
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Policy.Handler
  alias StreamData, as: SD

  @moduletag :mcp_policy
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns 10 tools" do
      tools = Handler.list_tools()
      assert length(tools) == 10
    end

    test "rule creation requires guardian" do
      tools = Handler.list_tools()
      create = Enum.find(tools, &(&1.name == "indrajaal.policy.rules.create"))
      assert create.requires_guardian == true
    end

    test "rule update requires guardian" do
      tools = Handler.list_tools()
      update = Enum.find(tools, &(&1.name == "indrajaal.policy.rules.update"))
      assert update.requires_guardian == true
    end

    test "evaluation does NOT require guardian" do
      tools = Handler.list_tools()
      eval = Enum.find(tools, &(&1.name == "indrajaal.policy.evaluate"))
      assert eval.requires_guardian == false
    end

    test "simulate does NOT require guardian" do
      tools = Handler.list_tools()
      sim = Enum.find(tools, &(&1.name == "indrajaal.policy.simulate"))
      assert sim.requires_guardian == false
    end
  end

  # ── handle :rules ──────────────────────────────────────────────

  describe "handle/3 - :rules" do
    test "list rules returns empty list" do
      assert {:ok, data} = Handler.handle(:rules, %{}, @context)
      assert data.rules == []
    end

    test "get rule by ID" do
      assert {:ok, data} =
               Handler.handle(:rules, %{"rule_id" => "rule-001"}, @context)

      assert data.id == "rule-001"
      assert data.category == "access"
      assert data.status == "active"
    end

    test "create rule" do
      args = %{"name" => "Block after hours", "category" => "security"}

      assert {:ok, data} = Handler.handle(:rules, args, @context)
      assert data.name == "Block after hours"
      assert data.category == "security"
      assert data.status == "draft"
      assert data.created == true
    end

    test "create rule requires name and category" do
      args = %{"name" => "Test rule"}
      result = Handler.handle(:rules, args, @context)
      assert {:error, _} = result
    end

    test "update rule with rule_id" do
      args = %{"rule_id" => "rule-001", "name" => "Updated rule"}

      assert {:ok, data} = Handler.handle(:rules, args, @context)
      assert data.id == "rule-001"
      assert data.updated == true
    end
  end

  # ── handle :evaluate ───────────────────────────────────────────

  describe "handle/3 - :evaluate" do
    test "evaluate request" do
      args = %{
        "subject" => "user-001",
        "action" => "read",
        "resource" => "document-123"
      }

      assert {:ok, data} = Handler.handle(:evaluate, args, @context)
      assert data.decision in ["allow", "deny"]
      assert is_list(data.matching_rules)
    end

    test "evaluate requires subject, action, resource" do
      args = %{"subject" => "user-001", "action" => "read"}
      result = Handler.handle(:evaluate, args, @context)
      assert {:error, _} = result
    end
  end

  # ── handle :simulate ───────────────────────────────────────────

  describe "handle/3 - :simulate" do
    test "simulate batch evaluation" do
      requests = [
        %{"subject" => "user-1", "action" => "read", "resource" => "doc-1"},
        %{"subject" => "user-2", "action" => "write", "resource" => "doc-2"}
      ]

      assert {:ok, data} =
               Handler.handle(:simulate, %{"requests" => requests}, @context)

      assert data.simulated == true
      assert length(data.results) == 2
    end

    test "simulate empty requests" do
      assert {:ok, data} =
               Handler.handle(:simulate, %{"requests" => []}, @context)

      assert data.results == []
      assert data.total == 0
    end
  end

  # ── handle :enforcement ────────────────────────────────────────

  describe "handle/3 - :enforcement" do
    test "enforcement status" do
      assert {:ok, data} = Handler.handle(:enforcement, %{}, @context)
      assert data.enforcing == true
    end

    test "enforcement violations" do
      assert {:ok, data} =
               Handler.handle(:enforcement, %{"severity" => "high"}, @context)

      assert data.violations == []
    end
  end

  # ── handle :sets ───────────────────────────────────────────────

  describe "handle/3 - :sets" do
    test "list policy sets" do
      assert {:ok, data} = Handler.handle(:sets, %{}, @context)
      assert data.policy_sets == []
    end
  end

  # ── handle :audit ──────────────────────────────────────────────

  describe "handle/3 - :audit" do
    test "get policy audit log" do
      assert {:ok, data} = Handler.handle(:audit, %{}, @context)
      assert data.audit_entries == []
    end
  end

  # ── Unknown action ─────────────────────────────────────────────

  describe "handle/3 - unknown action" do
    test "returns error for unknown action" do
      assert {:error, {:unknown_action, :unknown}} =
               Handler.handle(:unknown, %{}, @context)
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: simulate result count matches request count" do
      check all(
              count <- SD.integer(0..10),
              requests =
                Enum.map(1..max(count, 1), fn i ->
                  %{
                    "subject" => "user-#{i}",
                    "action" => "read",
                    "resource" => "doc-#{i}"
                  }
                end)
            ) do
        if count > 0 do
          {:ok, data} =
            Handler.handle(:simulate, %{"requests" => requests}, @context)

          assert length(data.results) == length(requests)
        end
      end
    end

    test "property: rule get always returns matching ID" do
      check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)) do
        {:ok, data} = Handler.handle(:rules, %{"rule_id" => id}, @context)
        assert data.id == id
      end
    end

    test "property: enforcement status always shows enforcing" do
      check all(scope <- SD.member_of(["global", "tenant", "site", "device"])) do
        {:ok, data} =
          Handler.handle(:enforcement, %{"scope" => scope}, @context)

        assert data.enforcing == true
      end
    end
  end
end
