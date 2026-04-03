defmodule Indrajaal.MCP.Domains.AccessControl.Handler do
  @moduledoc """
  MCP Handler for Access Control Domain

  WHAT: Handles RBAC access control, access logs, grants, and permission checks
  WHY: Provides AI access to physical access control for EN 50518 ARC operations
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-MCP-072

  ## Tools Provided
  - indrajaal.access_control.logs.list - List access log entries with filters
  - indrajaal.access_control.logs.security - List security events (forced/duress/tailgate)
  - indrajaal.access_control.grants.list - List active access grants
  - indrajaal.access_control.grants.check - Check access permission for credential
  - indrajaal.access_control.grants.revoke - Revoke an access grant (Guardian required)

  ## STAMP Constraints
  - SC-MCP-070: Handler MUST implement domain behavior
  - SC-MCP-071: All tools MUST have valid schemas
  - SC-IMMUNE-001: All access control mutations logged to audit trail
  """

  use Indrajaal.MCP.Domains.Handler, domain: :access_control

  alias Indrajaal.MCP.Foundation.Types
  alias Indrajaal.AccessControl.AccessLog
  alias Indrajaal.AccessControl.AccessGrant

  require Ash.Query

  @impl true
  def handle(:logs_list, args, context) do
    audit_log(@domain, :logs_list, args, context)

    limit = Map.get(args, "limit", 50)
    event_type = Map.get(args, "event_type")

    query =
      AccessLog
      |> Ash.Query.for_read(:read)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(timestamp: :desc)

    query =
      if event_type do
        Ash.Query.filter(query, __event_type == ^String.to_existing_atom(event_type))
      else
        query
      end

    case Ash.read(query) do
      {:ok, logs} ->
        formatted = Enum.map(logs, &format_log/1)

        success(%{
          logs: formatted,
          total: length(formatted),
          filters: %{event_type: event_type, limit: limit}
        })

      {:error, reason} ->
        error("Failed to list access logs: #{inspect(reason)}")
    end
  end

  @impl true
  def handle(:logs_security, args, context) do
    audit_log(@domain, :logs_security, args, context)

    limit = Map.get(args, "limit", 100)

    query =
      AccessLog
      |> Ash.Query.for_read(:list_security_events)
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(timestamp: :desc)

    case Ash.read(query) do
      {:ok, events} ->
        formatted = Enum.map(events, &format_log/1)

        success(%{
          security_events: formatted,
          total: length(formatted),
          event_types: ["forced", "duress", "tailgate"]
        })

      {:error, reason} ->
        error("Failed to list security events: #{inspect(reason)}")
    end
  end

  @impl true
  def handle(:grants_list, args, context) do
    audit_log(@domain, :grants_list, args, context)

    limit = Map.get(args, "limit", 50)
    status = Map.get(args, "status", "active")

    query =
      AccessGrant
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(status == ^String.to_existing_atom(status))
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(inserted_at: :desc)

    case Ash.read(query) do
      {:ok, grants} ->
        formatted = Enum.map(grants, &format_grant/1)

        success(%{
          grants: formatted,
          total: length(formatted),
          filters: %{status: status}
        })

      {:error, reason} ->
        error("Failed to list access grants: #{inspect(reason)}")
    end
  end

  @impl true
  def handle(:grants_check, args, context) do
    audit_log(@domain, :grants_check, args, context)

    with :ok <- validate_required(args, [:credential_id, :access_point_id]) do
      credential_id = Map.get(args, "credential_id") || Map.get(args, :credential_id)
      access_point_id = Map.get(args, "access_point_id") || Map.get(args, :access_point_id)

      query =
        AccessGrant
        |> Ash.Query.for_read(:check_access, %{
          credential_id: credential_id,
          access_point_id: access_point_id
        })

      case Ash.read(query) do
        {:ok, [grant | _]} ->
          success(%{
            access: :granted,
            grant_id: grant.id,
            grant_type: grant.grant_type,
            valid_until: grant.valid_until,
            escort_required: grant.escort_required,
            checked_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        {:ok, []} ->
          success(%{
            access: :denied,
            reason: "No active grant found for credential at this access point",
            checked_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        {:error, reason} ->
          error("Failed to check access: #{inspect(reason)}")
      end
    end
  end

  @impl true
  def handle(:grants_revoke, args, context) do
    audit_log(@domain, :grants_revoke, args, context)

    with :ok <- validate_required(args, [:grant_id]) do
      grant_id = Map.get(args, "grant_id") || Map.get(args, :grant_id)
      reason = Map.get(args, "reason", "Revoked via MCP")

      case Ash.get(AccessGrant, grant_id) do
        {:ok, grant} ->
          case Ash.update(grant, %{revocation_reason: reason}, action: :revoke) do
            {:ok, revoked} ->
              success(%{
                grant_id: revoked.id,
                status: "revoked",
                revoked_at: revoked.revoked_at |> DateTime.to_iso8601(),
                reason: reason
              })

            {:error, reason} ->
              error("Failed to revoke grant: #{inspect(reason)}")
          end

        {:error, %Ash.Error.Query.NotFound{}} ->
          not_found(:grant, grant_id)

        {:error, reason} ->
          error("Failed to find grant: #{inspect(reason)}")
      end
    end
  end

  @impl true
  def handle(action, args, context) do
    audit_log(@domain, action, args, context)
    not_implemented(action)
  end

  # Private helpers

  defp format_log(log) do
    %{
      id: log.id,
      event_type: log.event_type,
      timestamp: log.timestamp |> DateTime.to_iso8601(),
      access_point_id: log.access_point_id,
      direction: log.direction,
      denial_reason: Map.get(log, :denial_reason),
      tailgate_detected: log.tailgate_detected,
      duress_code_used: log.duress_code_used
    }
  end

  defp format_grant(grant) do
    %{
      id: grant.id,
      grant_type: grant.grant_type,
      status: grant.status,
      valid_from: grant.valid_from |> DateTime.to_iso8601(),
      valid_until: grant.valid_until && DateTime.to_iso8601(grant.valid_until),
      escort_required: grant.escort_required,
      use_count: grant.use_count,
      max_uses: grant.max_uses
    }
  end

  @doc """
  Returns tool schemas for registration.
  """
  @impl Indrajaal.MCP.Domains.Handler
  def list_tools do
    namespace = "indrajaal.access_control"

    [
      Types.new_tool_schema(
        "#{namespace}.logs.list",
        "List access log entries with optional event type filter",
        %{
          type: "object",
          properties: %{
            "event_type" => %{
              type: "string",
              description: "Filter by event type: granted/denied/tailgate/forced/emergency/duress"
            },
            "limit" => %{type: "integer", description: "Max results (default 50)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.logs.security",
        "List security events (forced entry, duress, tailgate)",
        %{
          type: "object",
          properties: %{
            "limit" => %{type: "integer", description: "Max results (default 100)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.grants.list",
        "List access grants filtered by status",
        %{
          type: "object",
          properties: %{
            "status" => %{
              type: "string",
              description: "Grant status: active/suspended/expired/revoked (default: active)"
            },
            "limit" => %{type: "integer", description: "Max results (default 50)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.grants.check",
        "Check if a credential has access to an access point",
        %{
          type: "object",
          properties: %{
            "credential_id" => %{type: "string", description: "Credential UUID"},
            "access_point_id" => %{type: "string", description: "Access point UUID"}
          },
          required: ["credential_id", "access_point_id"]
        }
      ),
      Types.new_tool_schema(
        "#{namespace}.grants.revoke",
        "Revoke an access grant (requires Guardian approval)",
        %{
          type: "object",
          properties: %{
            "grant_id" => %{type: "string", description: "Grant UUID to revoke"},
            "reason" => %{type: "string", description: "Revocation reason"}
          },
          required: ["grant_id"]
        },
        requires_guardian: true
      )
    ]
  end
end
