defmodule Indrajaal.MCP.Domains.Handler do
  @moduledoc """
  Base Handler Behavior for Indrajaal Domain MCP Tools

  WHAT: Defines the behavior contract for all domain handlers
  WHY: Ensures consistent interface across all 15 Indrajaal domains
  CONSTRAINTS: SC-MCP-070 (handler contract), SC-MCP-071 (error handling)

  ## Domains
  1. Accounts - User/tenant management
  2. Alarms - Alarm processing and history
  3. Access Control - RBAC permissions
  4. Authentication - Login/session management
  5. Authorization - Permission verification
  6. Communication - Notifications/messaging
  7. Compliance - Audit/regulatory
  8. Devices - Device management
  9. Dispatch - Responder dispatch
  10. Maintenance - Maintenance scheduling
  11. Observability - Metrics/logging
  12. Policies - Policy management
  13. Safety - Safety systems
  14. Sites - Site management
  15. Video - Video/streaming

  ## STAMP Constraints
  - SC-MCP-070: All handlers MUST implement handle/3 callback
  - SC-MCP-071: All errors MUST be wrapped in {:error, reason}
  - SC-MCP-072: All handlers MUST log actions to audit trail
  """

  alias Indrajaal.MCP.Foundation.Types

  @callback namespace() :: atom()
  @callback domain() :: atom()

  @callback handle(action :: atom(), args :: map(), context :: Types.execution_context()) ::
              {:ok, term()} | {:error, term()}

  @callback list_tools() :: list(Types.tool_schema())

  @doc """
  Helper to create a standard success response.
  """
  @spec success(term()) :: {:ok, term()}
  def success(result), do: {:ok, result}

  @doc """
  Helper to create a standard error response.
  """
  @spec error(String.t()) :: {:error, String.t()}
  def error(reason) when is_binary(reason), do: {:error, reason}

  @doc """
  Helper to create a not implemented error.
  """
  @spec not_implemented(atom()) :: {:error, String.t()}
  def not_implemented(action), do: {:error, "Action not implemented: #{action}"}

  @doc """
  Helper to create a not found error.
  """
  @spec not_found(String.t(), term()) :: {:error, String.t()}
  def not_found(resource_type, id), do: {:error, "#{resource_type} not found: #{id}"}

  @doc """
  Helper to validate required fields.
  """
  @spec validate_required(map(), list(atom() | String.t())) :: :ok | {:error, String.t()}
  def validate_required(args, required_fields) do
    missing =
      required_fields
      |> Enum.filter(fn field ->
        value = Map.get(args, field) || Map.get(args, to_string(field))
        is_nil(value)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  @doc """
  Helper to log handler action to audit trail.
  """
  @spec audit_log(atom(), atom(), map(), Types.execution_context()) :: :ok
  def audit_log(domain, action, args, context) do
    :telemetry.execute(
      [:mcp, :domain, :action],
      %{count: 1},
      %{
        domain: domain,
        action: action,
        args: args,
        client_id: context.client_id,
        timestamp: context.timestamp
      }
    )

    :ok
  end

  @doc """
  Macro to use this behavior in domain handlers.
  """
  defmacro __using__(opts) do
    domain = Keyword.fetch!(opts, :domain)
    namespace = Keyword.get(opts, :namespace, :indrajaal)

    quote do
      @behaviour Indrajaal.MCP.Domains.Handler

      import Indrajaal.MCP.Domains.Handler,
        only: [
          success: 1,
          error: 1,
          not_implemented: 1,
          not_found: 2,
          validate_required: 2,
          audit_log: 4
        ]

      @domain unquote(domain)
      @namespace unquote(namespace)

      @impl true
      def namespace, do: @namespace

      @impl true
      def domain, do: @domain

      # Default handle implementation for unknown actions
      @impl true
      def handle(action, _args, _context) do
        not_implemented(action)
      end

      defoverridable handle: 3, namespace: 0, domain: 0
    end
  end
end
