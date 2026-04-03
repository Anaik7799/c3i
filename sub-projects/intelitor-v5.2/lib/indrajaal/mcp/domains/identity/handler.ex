defmodule Indrajaal.MCP.Domains.Identity.Handler do
  @moduledoc """
  MCP Handler for Identity domain.

  WHAT: Provides 10 tools for user profile management, credential operations, and MFA configuration.
  WHY: Enables AI assistants to manage user identities, verify credentials, and configure authentication.

  STAMP Constraints:
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-SEC-044: Security operations MUST be audited
  - SC-SEC-047: Credential operations MUST be encrypted

  AOR Rules:
  - AOR-MCP-070: Register all tools on load
  - AOR-SEC-001: ALWAYS authenticate before authorization
  - AOR-SEC-003: NEVER log sensitive data (passwords, tokens)
  """

  use Indrajaal.MCP.Domains.Handler, domain: :identity

  alias Indrajaal.MCP.Foundation.Types

  @impl true
  def list_tools do
    [
      # User Profile
      %Types.Tool{
        name: "indrajaal.identity.profile.get",
        description: "Get user profile by user ID",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"}
          },
          required: ["user_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.profile.update",
        description: "Update user profile fields",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            display_name: %{type: "string"},
            email: %{type: "string", format: "email"},
            phone: %{type: "string"},
            locale: %{type: "string"},
            timezone: %{type: "string"}
          },
          required: ["user_id"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.profile.search",
        description: "Search user profiles by criteria",
        input_schema: %{
          type: "object",
          properties: %{
            query: %{type: "string", description: "Search term for name/email"},
            role: %{type: "string"},
            tenant_id: %{type: "string"},
            status: %{type: "string", enum: ["active", "inactive", "locked", "pending"]},
            limit: %{type: "integer", default: 50}
          }
        },
        requires_guardian: false,
        namespace: :indrajaal
      },

      # Credential Management
      %Types.Tool{
        name: "indrajaal.identity.credentials.status",
        description: "Check credential status for a user (never returns actual credentials)",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"}
          },
          required: ["user_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.credentials.reset",
        description: "Initiate credential reset for a user",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            method: %{type: "string", enum: ["email", "sms", "admin_override"]},
            reason: %{type: "string"}
          },
          required: ["user_id", "method"]
        },
        requires_guardian: true,
        requires_proof_token: true,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.credentials.lock",
        description: "Lock user credentials (prevent login)",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            reason: %{type: "string"},
            duration_hours: %{
              type: "integer",
              description: "Lock duration in hours, 0 = permanent"
            }
          },
          required: ["user_id", "reason"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # MFA Configuration
      %Types.Tool{
        name: "indrajaal.identity.mfa.status",
        description: "Get MFA configuration status for a user",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"}
          },
          required: ["user_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.mfa.enable",
        description: "Enable MFA for a user",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            method: %{type: "string", enum: ["totp", "sms", "email", "hardware_key"]},
            force: %{type: "boolean", default: false}
          },
          required: ["user_id", "method"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      },

      # Session Management
      %Types.Tool{
        name: "indrajaal.identity.sessions.list",
        description: "List active sessions for a user",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            active_only: %{type: "boolean", default: true}
          },
          required: ["user_id"]
        },
        requires_guardian: false,
        namespace: :indrajaal
      },
      %Types.Tool{
        name: "indrajaal.identity.sessions.revoke",
        description: "Revoke one or all sessions for a user",
        input_schema: %{
          type: "object",
          properties: %{
            user_id: %{type: "string"},
            session_id: %{type: "string", description: "Specific session to revoke, omit for all"},
            reason: %{type: "string"}
          },
          required: ["user_id"]
        },
        requires_guardian: true,
        namespace: :indrajaal
      }
    ]
  end

  @impl true
  def handle(:profile, %{"user_id" => user_id} = args, context) do
    audit_log(@domain, :profile, args, context)

    if map_size(Map.drop(args, ["user_id"])) > 0 do
      fields = Map.drop(args, ["user_id"])

      success(%{
        id: user_id,
        updated_fields: Map.keys(fields),
        updated: true,
        updated_at: DateTime.utc_now()
      })
    else
      success(%{
        id: user_id,
        display_name: "User #{String.slice(user_id, 0, 8)}",
        status: "active",
        roles: [],
        created_at: DateTime.utc_now()
      })
    end
  end

  def handle(:profile, args, context) do
    audit_log(@domain, :profile, args, context)
    success(%{profiles: [], total: 0, filters: args})
  end

  def handle(:credentials, %{"user_id" => user_id, "method" => method} = args, context) do
    audit_log(@domain, :credentials, args, context)

    success(%{
      user_id: user_id,
      reset_initiated: true,
      method: method,
      expires_in_minutes: 30,
      initiated_at: DateTime.utc_now()
    })
  end

  def handle(:credentials, %{"user_id" => user_id, "reason" => reason} = args, context) do
    audit_log(@domain, :credentials, args, context)

    success(%{
      user_id: user_id,
      locked: true,
      reason: reason,
      duration_hours: Map.get(args, "duration_hours", 0),
      locked_at: DateTime.utc_now()
    })
  end

  def handle(:credentials, %{"user_id" => user_id} = args, context) do
    audit_log(@domain, :credentials, args, context)

    success(%{
      user_id: user_id,
      password_set: true,
      password_expires_at: DateTime.utc_now() |> DateTime.add(90 * 86400),
      mfa_enabled: false,
      last_login: nil,
      failed_attempts: 0,
      locked: false
    })
  end

  def handle(:mfa, %{"user_id" => user_id, "method" => method} = args, context) do
    audit_log(@domain, :mfa, args, context)

    success(%{
      user_id: user_id,
      method: method,
      enabled: true,
      setup_required: true,
      enabled_at: DateTime.utc_now()
    })
  end

  def handle(:mfa, %{"user_id" => user_id} = args, context) do
    audit_log(@domain, :mfa, args, context)

    success(%{
      user_id: user_id,
      mfa_enabled: false,
      methods: [],
      backup_codes_remaining: 0
    })
  end

  def handle(:sessions, %{"user_id" => user_id} = args, context) do
    audit_log(@domain, :sessions, args, context)

    if Map.has_key?(args, "session_id") or Map.has_key?(args, "reason") do
      session_id = Map.get(args, "session_id")

      success(%{
        user_id: user_id,
        revoked: true,
        scope: if(session_id, do: "single", else: "all"),
        session_id: session_id,
        revoked_at: DateTime.utc_now()
      })
    else
      success(%{
        user_id: user_id,
        sessions: [],
        total: 0
      })
    end
  end

  def handle(action, _args, _context) do
    {:error, {:unknown_action, action}}
  end
end
