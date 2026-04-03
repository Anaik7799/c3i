defmodule IndrajaalWeb.Api.Mobile.Config.BaseConfigController do
  @moduledoc """
  Base controller for mobile configuration endpoints

  Consolidates common patterns across mobile config controllers:
  - Authentication and authorization
  - Error handling and validation
  - Tenant access control
  - Standardized response formats
  - Enterprise audit logging

  SOPv5.1 Compliance: TDG + TPS + STAMP + Enterprise Standards
  """

  defmacro __using__(_opts) do
    quote do
      use IndrajaalWeb, :controller

      alias IndrajaalWeb.Api.Mobile.Shared.MobileSecurityValidator

      import Plug.Conn
      import Phoenix.Controller

      require Logger

      alias IndrajaalWeb.Api.Mobile.Shared.ErrorHelpers
      alias Indrajaal.Accounts
      alias Indrajaal.Accounts.User

      # Common plugs for mobile config endpoints
      plug IndrajaalWeb.Plugs.AuthenticateAPI
      plug :validate_tenant_access
      plug :audit_config_access

      # Common helper functions available to all mobile config controllers
      defp handle_error(conn, {:error, :not_found}) do
        conn
        |> put_status(:not_found)
        |> json(%{error: "Resource not found"})
      end

      defp handle_error(conn, {:error, :unauthorized}) do
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized access"})
      end

      defp handle_error(conn, {:error, changeset}) when is_map(changeset) do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: ErrorHelpers.translate_errors(changeset)})
      end

      defp handle_error(conn, {:error, reason}) do
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error", details: inspect(reason)})
      end

      defp handle_not_found(conn, _params) do
        handle_error(conn, {:error, :not_found})
      end

      defp handle_unauthorized(conn, _params) do
        handle_error(conn, {:error, :unauthorized})
      end

      defp validate_params(params, required_keys) when is_list(required_keys) do
        missing_keys = required_keys -- Map.keys(params)

        case missing_keys do
          [] -> {:ok, params}
          keys -> {:error, "Missing required parameters: #{Enum.join(keys, ", ")}"}
        end
      end

      defp validate_tenant_access(conn, _opts) do
        current_user = conn.assigns[:current_user]
        tenant_id = conn.params["tenant_id"] || conn.assigns[:current_tenant_id]

        if current_user && tenant_id && user_has_tenant_access?(current_user, tenant_id) do
          assign(conn, :validated_tenant_id, tenant_id)
        else
          conn
          |> handle_unauthorized(nil)
          |> halt()
        end
      end

      # Helper function to check tenant access
      defp user_has_tenant_access?(%{tenant_id: user_tenant_id}, tenant_id) do
        user_tenant_id == tenant_id
      end

      defp user_has_tenant_access?(_, _), do: false

      defp audit_config_access(conn, _opts) do
        # Log configuration access for security audit
        Logger.info("Mobile config access",
          user_id: if(conn.assigns[:current_user], do: conn.assigns[:current_user].id, else: nil),
          tenant_id: conn.assigns[:validated_tenant_id],
          endpoint: conn.request_path,
          action: conn.method
        )

        conn
      end

      # Standard response helpers
      defp render_success(conn, data, status \\ :ok) do
        conn
        |> put_status(status)
        |> json(%{success: true, data: data})
      end

      defp render_config_list(conn, configs, meta \\ %{}) do
        response = %{
          success: true,
          configs: configs,
          meta: Map.merge(%{count: length(configs)}, meta)
        }

        json(conn, response)
      end

      # TDG - compliant test helpers (available in test environment)
      if Mix.env() == :test do
        defp setup_test_tenant(_req) do
          Indrajaal.Factory.insert(:tenant)
        end

        defp setup_test_user(tenant_id, _req) do
          Indrajaal.Factory.insert(:user, tenant_id: tenant_id)
        end

        defp authenticate_test_request(conn, user, _req) do
          token = IndrajaalWeb.Guardian.encode_and_sign(user)
          put_req_header(conn, "authorization", "Bearer #{token}")
        end
      end
    end
  end
end

# Agent: Supervisor - 1 (Strategic Oversight Agent)
# SOPv5.1 Compliance: ✅ Strategic oversight and coordination with cybernetic framework
# Domain: Mobile API Configuration
# Responsibilities: Base controller consolidation, duplicate elimination, enterprise patterns
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
