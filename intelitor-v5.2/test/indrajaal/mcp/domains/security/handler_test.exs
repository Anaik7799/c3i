defmodule Indrajaal.MCP.Domains.Security.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Security Handler.

  Tests 12 tools across threat assessment, access audit,
  incident response, and vulnerability management.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-IMMUNE-001: Sentinel monitors system health
  - SC-IMMUNE-004: PatternHunter detects pre-error signatures

  ## TPS 5-Level RCA Context
  - L1 Symptom: Security tool returns unexpected error
  - L5 Root Cause: Missing action handler or malformed input schema
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Security.Handler
  alias StreamData, as: SD

  @moduletag :mcp_security
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns 12 tools" do
      tools = Handler.list_tools()
      assert length(tools) == 12
    end

    test "all tools have indrajaal.security namespace" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        assert String.starts_with?(tool.name, "indrajaal.security.")
      end)
    end

    test "all tools have input_schema" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        assert is_map(tool.input_schema)
        assert tool.input_schema.type == "object"
      end)
    end

    test "mitigation requires guardian" do
      tools = Handler.list_tools()
      mitigate = Enum.find(tools, &(&1.name == "indrajaal.security.threats.mitigate"))
      assert mitigate.requires_guardian == true
    end

    test "incident creation requires guardian" do
      tools = Handler.list_tools()
      create = Enum.find(tools, &(&1.name == "indrajaal.security.incidents.create"))
      assert create.requires_guardian == true
    end

    test "vuln scan requires guardian" do
      tools = Handler.list_tools()
      scan = Enum.find(tools, &(&1.name == "indrajaal.security.vulnerabilities.scan"))
      assert scan.requires_guardian == true
    end

    test "posture check does NOT require guardian" do
      tools = Handler.list_tools()
      posture = Enum.find(tools, &(&1.name == "indrajaal.security.posture"))
      assert posture.requires_guardian == false
    end
  end

  # ── handle :threats ────────────────────────────────────────────

  describe "handle/3 - :threats" do
    test "list threats returns empty list" do
      assert {:ok, data} = Handler.handle(:threats, %{}, @context)
      assert data.threats == []
      assert data.total == 0
    end

    test "assess threats with scope" do
      assert {:ok, data} =
               Handler.handle(:threats, %{"scope" => "full"}, @context)

      assert data.scope == "full"
      assert data.threat_level == "low"
      assert Map.has_key?(data, :assessment_id)
    end

    test "mitigate threat" do
      args = %{"threat_id" => "threat-123", "action" => "block"}

      assert {:ok, data} = Handler.handle(:threats, args, @context)
      assert data.threat_id == "threat-123"
      assert data.action == "block"
      assert data.mitigated == true
    end

    test "mitigate with notes" do
      args = %{
        "threat_id" => "threat-456",
        "action" => "quarantine",
        "notes" => "Suspicious traffic from IP range"
      }

      assert {:ok, data} = Handler.handle(:threats, args, @context)
      assert data.notes == "Suspicious traffic from IP range"
    end
  end

  # ── handle :audit ──────────────────────────────────────────────

  describe "handle/3 - :audit" do
    test "anomaly detection with period" do
      assert {:ok, data} =
               Handler.handle(:audit, %{"period_hours" => 48}, @context)

      assert data.period_hours == 48
      assert data.anomalies == []
    end

    test "access audit log" do
      assert {:ok, data} = Handler.handle(:audit, %{}, @context)
      assert data.audit_entries == []
    end
  end

  # ── handle :incidents ──────────────────────────────────────────

  describe "handle/3 - :incidents" do
    test "list incidents returns empty list" do
      assert {:ok, data} = Handler.handle(:incidents, %{}, @context)
      assert data.incidents == []
    end

    test "create incident" do
      args = %{"title" => "Brute force attempt", "severity" => "high"}

      assert {:ok, data} = Handler.handle(:incidents, args, @context)
      assert data.title == "Brute force attempt"
      assert data.severity == "high"
      assert data.status == "open"
      assert Map.has_key?(data, :incident_id)
    end

    test "create incident requires title and severity" do
      args = %{"title" => "Test"}
      result = Handler.handle(:incidents, args, @context)
      # validate_required should catch missing severity
      assert {:error, _} = result
    end

    test "update incident" do
      args = %{"incident_id" => "inc-123", "status" => "resolved"}

      assert {:ok, data} = Handler.handle(:incidents, args, @context)
      assert data.incident_id == "inc-123"
      assert data.updated == true
    end
  end

  # ── handle :vulnerabilities ────────────────────────────────────

  describe "handle/3 - :vulnerabilities" do
    test "scan vulnerabilities with scope" do
      assert {:ok, data} =
               Handler.handle(:vulnerabilities, %{"scope" => "dependencies"}, @context)

      assert data.scope == "dependencies"
      assert data.status == "initiated"
      assert Map.has_key?(data, :scan_id)
    end

    test "list vulnerabilities" do
      assert {:ok, data} = Handler.handle(:vulnerabilities, %{}, @context)
      assert data.vulnerabilities == []
    end
  end

  # ── handle :posture ────────────────────────────────────────────

  describe "handle/3 - :posture" do
    test "returns security posture score" do
      assert {:ok, data} = Handler.handle(:posture, %{}, @context)
      assert is_integer(data.overall_score)
      assert data.overall_score > 0
      assert is_binary(data.grade)
    end

    test "posture includes category scores" do
      {:ok, data} = Handler.handle(:posture, %{}, @context)
      assert is_map(data.categories)
      assert Map.has_key?(data.categories, :authentication)
      assert Map.has_key?(data.categories, :encryption)
    end
  end

  # ── handle :compliance ─────────────────────────────────────────

  describe "handle/3 - :compliance" do
    test "check compliance for all standards" do
      assert {:ok, data} = Handler.handle(:compliance, %{}, @context)
      assert data.compliant == true
      assert is_integer(data.score)
    end

    test "check compliance for specific standard" do
      assert {:ok, data} =
               Handler.handle(:compliance, %{"standard" => "iso27001"}, @context)

      assert data.standard == "iso27001"
    end
  end

  # ── Unknown action ─────────────────────────────────────────────

  describe "handle/3 - unknown action" do
    test "returns error for unknown action" do
      assert {:error, {:unknown_action, :nonexistent}} =
               Handler.handle(:nonexistent, %{}, @context)
    end
  end

  # ── Property Tests ─────────────────────────────────────────────

  describe "property tests" do
    test "property: list threats always returns {:ok, map}" do
      check all(_i <- SD.integer(1..5)) do
        assert {:ok, data} = Handler.handle(:threats, %{}, @context)
        assert is_map(data)
      end
    end

    test "property: posture score is between 0 and 100" do
      check all(_i <- SD.integer(1..5)) do
        {:ok, data} = Handler.handle(:posture, %{}, @context)
        assert data.overall_score >= 0 and data.overall_score <= 100
      end
    end

    test "property: compliance check always returns boolean compliant" do
      check all(
              standard <-
                SD.member_of(["iso27001", "en50131", "gdpr", "all"])
            ) do
        {:ok, data} =
          Handler.handle(:compliance, %{"standard" => standard}, @context)

        assert is_boolean(data.compliant)
      end
    end
  end
end
