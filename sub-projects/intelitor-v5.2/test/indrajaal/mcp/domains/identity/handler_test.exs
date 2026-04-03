defmodule Indrajaal.MCP.Domains.Identity.HandlerTest do
  @moduledoc """
  TDG test suite for MCP Identity Handler.

  Tests 10 tools for user profile management, credential operations,
  and MFA configuration.

  ## STAMP Safety Integration
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-SEC-044: Security operations MUST be audited
  - SC-SEC-047: Credential operations MUST be encrypted

  ## TPS 5-Level RCA Context
  - L1 Symptom: Identity tool returns unexpected error
  - L5 Root Cause: Missing user_id or invalid credential method
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Indrajaal.MCP.Domains.Identity.Handler
  alias StreamData, as: SD

  @moduletag :mcp_identity
  @context %{client_id: "test-client", timestamp: ~U[2026-01-01 00:00:00Z]}

  # ── list_tools/0 ───────────────────────────────────────────────

  describe "list_tools/0" do
    test "returns 10 tools" do
      tools = Handler.list_tools()
      assert length(tools) == 10
    end

    test "profile update requires guardian" do
      tools = Handler.list_tools()
      update = Enum.find(tools, &(&1.name == "indrajaal.identity.profile.update"))
      assert update.requires_guardian == true
    end

    test "credential reset requires guardian and proof token" do
      tools = Handler.list_tools()
      reset = Enum.find(tools, &(&1.name == "indrajaal.identity.credentials.reset"))
      assert reset.requires_guardian == true
      assert reset.requires_proof_token == true
    end

    test "session revoke requires guardian" do
      tools = Handler.list_tools()
      revoke = Enum.find(tools, &(&1.name == "indrajaal.identity.sessions.revoke"))
      assert revoke.requires_guardian == true
    end

    test "profile get does NOT require guardian" do
      tools = Handler.list_tools()
      get = Enum.find(tools, &(&1.name == "indrajaal.identity.profile.get"))
      assert get.requires_guardian == false
    end
  end

  # ── handle :profile ────────────────────────────────────────────

  describe "handle/3 - :profile" do
    test "get profile by user_id" do
      assert {:ok, data} =
               Handler.handle(:profile, %{"user_id" => "user-001"}, @context)

      assert data.id == "user-001"
      assert data.status == "active"
      assert is_list(data.roles)
    end

    test "update profile with fields" do
      args = %{
        "user_id" => "user-001",
        "display_name" => "Jane Doe",
        "email" => "jane@example.com"
      }

      assert {:ok, data} = Handler.handle(:profile, args, @context)
      assert data.id == "user-001"
      assert data.updated == true
      assert "display_name" in data.updated_fields
      assert "email" in data.updated_fields
    end

    test "search profiles returns empty" do
      assert {:ok, data} = Handler.handle(:profile, %{}, @context)
      assert data.profiles == []
    end
  end

  # ── handle :credentials ────────────────────────────────────────

  describe "handle/3 - :credentials" do
    test "get credential status" do
      assert {:ok, data} =
               Handler.handle(:credentials, %{"user_id" => "user-001"}, @context)

      assert data.user_id == "user-001"
      assert is_boolean(data.password_set)
      assert is_boolean(data.locked)
    end

    test "reset credentials" do
      args = %{"user_id" => "user-001", "method" => "email"}

      assert {:ok, data} = Handler.handle(:credentials, args, @context)
      assert data.reset_initiated == true
      assert data.method == "email"
      assert data.expires_in_minutes == 30
    end

    test "lock credentials" do
      args = %{"user_id" => "user-001", "reason" => "Suspicious activity"}

      assert {:ok, data} = Handler.handle(:credentials, args, @context)
      assert data.locked == true
      assert data.reason == "Suspicious activity"
    end

    test "lock with duration" do
      args = %{
        "user_id" => "user-001",
        "reason" => "Temporary lock",
        "duration_hours" => 24
      }

      assert {:ok, data} = Handler.handle(:credentials, args, @context)
      assert data.duration_hours == 24
    end
  end

  # ── handle :mfa ────────────────────────────────────────────────

  describe "handle/3 - :mfa" do
    test "get MFA status" do
      assert {:ok, data} =
               Handler.handle(:mfa, %{"user_id" => "user-001"}, @context)

      assert data.user_id == "user-001"
      assert data.mfa_enabled == false
    end

    test "enable MFA with TOTP" do
      args = %{"user_id" => "user-001", "method" => "totp"}

      assert {:ok, data} = Handler.handle(:mfa, args, @context)
      assert data.enabled == true
      assert data.method == "totp"
      assert data.setup_required == true
    end
  end

  # ── handle :sessions ───────────────────────────────────────────

  describe "handle/3 - :sessions" do
    test "list sessions" do
      assert {:ok, data} =
               Handler.handle(:sessions, %{"user_id" => "user-001"}, @context)

      assert data.sessions == []
      assert data.total == 0
    end

    test "revoke specific session" do
      args = %{
        "user_id" => "user-001",
        "session_id" => "sess-123",
        "reason" => "Compromised"
      }

      assert {:ok, data} = Handler.handle(:sessions, args, @context)
      assert data.revoked == true
      assert data.scope == "single"
      assert data.session_id == "sess-123"
    end

    test "revoke all sessions" do
      args = %{"user_id" => "user-001", "reason" => "Password changed"}

      assert {:ok, data} = Handler.handle(:sessions, args, @context)
      assert data.revoked == true
      assert data.scope == "all"
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
    test "property: profile get returns matching user_id" do
      check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)) do
        {:ok, data} = Handler.handle(:profile, %{"user_id" => id}, @context)
        assert data.id == id
      end
    end

    test "property: MFA methods all enable successfully" do
      check all(method <- SD.member_of(["totp", "sms", "email", "hardware_key"])) do
        {:ok, data} =
          Handler.handle(:mfa, %{"user_id" => "u1", "method" => method}, @context)

        assert data.enabled == true
        assert data.method == method
      end
    end

    test "property: credential reset methods all accepted" do
      check all(method <- SD.member_of(["email", "sms", "admin_override"])) do
        {:ok, data} =
          Handler.handle(
            :credentials,
            %{"user_id" => "u1", "method" => method},
            @context
          )

        assert data.reset_initiated == true
      end
    end
  end
end
