defmodule IndrajaalWeb.Plugs.AuthenticateAPI do
  @moduledoc """
  Enhanced authentication plug for Mobile API endpoints.

  Implements zero-trust security model with JWT validation,
  session verification, and rate limiting.

  Agent: Helper-1 manages authentication
  SOPv5.1 Compliance: ✅
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Indrajaal.Authentication
  alias Indrajaal.Authentication.RateLimiter

  require Logger

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    # Agent: Helper-1 validates authentication
    # STAMP Safety: Zero-trust model - verify everything

    endpoint = conn.__request_path
    require_mfa = Keyword.get(opts, :require_mfa, false)

    with :ok <- check_rate_limit(conn),
         {:ok, user} <- authenticate_request(conn),
         :ok <- verify_mfa_if_required(user, conn, require_mfa),
         :ok <- log_successful_auth(user, endpoint) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_tenant_id, user.tenant_id)
      |> put_resp_header(
        "x-rate-limit-remaining",
        get_rate_limit_remaining(user)
      )
    else
      {:error, :rate_limited} = _error ->
        handle_rate_limit_error(conn)

      {:error, :mfa_required} = _error ->
        handle_mfa_required(conn)

      {:error, reason} = _error ->
        handle_auth_error(conn, reason)
    end
  end

  @spec check_rate_limit(Plug.Conn.t()) :: :ok | {:error, atom()}
  defp check_rate_limit(conn) do
    # Check IP-based rate limiting first (pre-auth)
    ip = get_client_ip(conn)
    RateLimiter.check_rate("ip:#{ip}", conn.__request_path, limit: 10)
  end

  @spec authenticate_request(Plug.Conn.t()) :: {:ok, map()} | {:error, atom()}
  defp authenticate_request(conn) do
    # Convert conn headers to map for Authentication module
    headers = Enum.into(conn.__req_headers, %{})

    Authentication.TokenValidator.validate_request(headers)
  end

  @spec verify_mfa_if_required(map(), Plug.Conn.t(), boolean()) :: :ok | {:error, atom()}
  defp verify_mfa_if_required(%{mfa_enabled: false}, _conn, _require_mfa), do: :ok
  defp verify_mfa_if_required(_user, _conn, false), do: :ok

  defp verify_mfa_if_required(user, conn, true) do
    case get_req_header(conn, "x-mfa-token") do
      [mfa_token] ->
        Indrajaal.Authentication.MFA.authorize_sensitive_operation(user, :api_access, mfa_token)

      _ ->
        {:error, :mfa_required}
    end
  end

  @spec handle_rate_limit_error(Plug.Conn.t()) :: Plug.Conn.t()
  defp handle_rate_limit_error(conn) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("retry-after", "60")
    |> json(%{
      status: "error",
      message: "Rate limit exceeded",
      code: "RATE_LIMITED"
    })
    |> halt()
  end

  @spec handle_mfa_required(Plug.Conn.t()) :: Plug.Conn.t()
  defp handle_mfa_required(conn) do
    conn
    |> put_status(:forbidden)
    |> put_resp_header("x-mfa-required", "true")
    |> json(%{
      status: "error",
      message: "Multi-factor authentication required",
      code: "MFA_REQUIRED"
    })
    |> halt()
  end

  @spec handle_auth_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
  defp handle_auth_error(conn, reason) do
    # TPS 5-Level RCA for auth failures
    perform_auth_failure_analysis(reason, conn)

    conn
    |> put_status(:unauthorized)
    |> json(%{
      status: "error",
      message: format_error(reason),
      code: error_code(reason)
    })
    |> halt()
  end

  @spec get_client_ip(Plug.Conn.t()) :: String.t()
  defp get_client_ip(conn) do
    # Check X-Forwarded-For header first
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        ip

      _ ->
        # Fall back to remote_ip
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          _ -> "unknown"
        end
    end
  end

  @spec get_rate_limit_remaining(map()) :: String.t()
  defp get_rate_limit_remaining(_user) do
    # TODO: Get actual remaining from rate limiter
    "99"
  end

  @spec log_successful_auth(map(), String.t()) :: :ok
  defp log_successful_auth(user, endpoint) do
    Logger.info("Successful authentication",
      user_id: user.id,
      tenant_id: user.tenant_id,
      endpoint: endpoint,
      timestamp: DateTime.utc_now()
    )

    :ok
  end

  @spec perform_auth_failure_analysis(atom(), Plug.Conn.t()) :: :ok
  defp perform_auth_failure_analysis(reason, conn) do
    Logger.warning("Authentication failure",
      reason: reason,
      endpoint: conn.__request_path,
      method: conn.method,
      ip: get_client_ip(conn),
      level_1: "Symptom: API request authentication failed",
      level_2: "Direct cause: #{inspect(reason)}",
      level_3: "System behavior: Request blocked at authentication layer",
      level_4: "Process gap: Client authentication credentials invalid or missing",
      level_5: "Root cause: User error, expired credentials, or security policy violation"
    )

    :ok
  end

  @spec format_error(atom()) :: String.t()
  defp format_error(:missing_token), do: "Missing authentication token"
  defp format_error(:invalid_token), do: "Invalid authentication token"
  defp format_error(:token_expired), do: "Authentication token expired"
  defp format_error(:invalid_signature), do: "Invalid token signature"
  defp format_error(:no_active_session), do: "No active session found"
  defp format_error(:session_expired), do: "Session has expired"
  defp format_error(:session_user_mismatch), do: "Session user mismatch"
  defp format_error(:user_inactive), do: "User account is inactive"
  defp format_error(:ip_mismatch), do: "Request IP does not match session"
  defp format_error(_), do: "Authentication failed"

  @spec error_code(atom()) :: String.t()
  defp error_code(:missing_token), do: "MISSING_TOKEN"
  defp error_code(:invalid_token), do: "INVALID_TOKEN"
  defp error_code(:token_expired), do: "TOKEN_EXPIRED"
  defp error_code(:invalid_signature), do: "INVALID_SIGNATURE"
  defp error_code(:no_active_session), do: "NO_SESSION"
  defp error_code(:session_expired), do: "SESSION_EXPIRED"
  defp error_code(:session_user_mismatch), do: "SESSION_MISMATCH"
  defp error_code(:user_inactive), do: "USER_INACTIVE"
  defp error_code(:ip_mismatch), do: "IP_MISMATCH"
  defp error_code(_), do: "AUTH_FAILED"
end
