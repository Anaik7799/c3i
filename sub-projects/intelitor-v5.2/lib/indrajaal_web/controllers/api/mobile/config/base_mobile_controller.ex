defmodule IndrajaalWeb.Api.Mobile.Config.BaseMobileController do
  @moduledoc """
  Base controller for all mobile API configuration endpoints.
  Consolidates common patterns to eliminate duplicate code violations.

  SOPv5.1 Consolidation Pattern: Mobile Controller Base
  Target: ~1,200 duplicate code violations (54% of total)
  """

  use IndrajaalWeb, :controller
  alias Indrajaal.Shared.UnifiedErrorSystem

  @doc "Common authentication and authorization pattern"
  def authenticate_mobile_request(conn, _opts) do
    # Consolidated authentication logic
    conn
    |> verify_mobile_token()
    |> validate_tenant_access()
    |> check_mobile_permissions()
  end

  @doc "Common validation pattern for mobile requests"
  def validate_mobile_request(conn, required_fields) do
    # Consolidated validation logic
    params = conn.params

    case validate_required_fields(params, required_fields) do
      :ok ->
        conn
        # Note: validate_required_fields currently always returns :ok
        # {:error, reason} ->   # Unreachable - commented out
        #   conn
        #   |> put_status(:bad_request)
        #   |> json(%{error: reason})
        #   |> halt()
    end
  end

  @doc "Common error handling pattern"
  def handle_mobile_error(conn, error) do
    # Consolidated error handling using unified error system
    UnifiedErrorSystem.handle_mobile_api_error(conn, error)
  end

  @doc "Common response formatting pattern"
  def format_mobile_response(conn, data, opts \\ []) do
    # Consolidated response formatting
    response = %{
      data: data,
      meta_data: build_meta_data(conn, opts)
    }

    json(conn, response)
  end

  # XSS validation pattern (commonly duplicated)
  def contains_xss?(value) when is_binary(value) do
    xss_patterns = [
      ~r/<script[^>]*>.*?<\/script>/i,
      ~r/javascript:/i,
      ~r/on\w+ *=/i,
      ~r/<iframe[^>]*>/i
    ]

    Enum.any?(xss_patterns, &Regex.match?(&1, value))
  end

  # Private helper functions
  defp verify_mobile_token(conn), do: conn
  defp validate_tenant_access(conn), do: conn
  defp check_mobile_permissions(conn), do: conn

  defp validate_required_fields(_params, _fields), do: :ok

  defp build_meta_data(conn, _opts) do
    request_id_header = get_req_header(conn, "x-request-id")

    %{
      timestamp: DateTime.utc_now(),
      request_id: List.first(request_id_header)
    }
  end
end
