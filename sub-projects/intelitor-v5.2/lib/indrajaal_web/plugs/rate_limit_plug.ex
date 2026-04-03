defmodule IndrajaalWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Rate Limiting Plug for Phoenix Integration

  Provides automatic rate limiting enforcement with:
  - Configurable per-endpoint limits
  - Role-based rate limiting
  - Custom error responses
  - Comprehensive headers
  - Bypass for health checks and monitoring
  """

  import Plug.Conn
  require Logger

  alias Indrajaal.Security.RateLimiter
  # alias IndrajaalWeb.ErrorJSON

  @behaviour Plug

  @default_opts %{
    enabled: true,
    bypass_paths: ["/health", "/metrics", "/ping"],
    error_status: 429,
    error_message: "Rate limit exceeded. Please try again later.",
    include_headers: true,
    log_violations: true
  }

  @spec init(any()) :: any()
  def init(opts) do
    Map.merge(@default_opts, Enum.into(opts, %{}))
  end

  @spec call(any(), any()) :: any()
  def call(conn, opts) do
    if opts.enabled and not bypass_path?(conn.request_path, opts.bypass_paths) do
      enforce_rate_limit(conn, opts)
    else
      conn
    end
  end

  @spec enforce_rate_limit(term(), term()) :: term()
  defp enforce_rate_limit(conn, opts) do
    with {:ok, user_id} <- extract_user_id(conn),
         {:ok, role} <- extract_user_role(conn) do
      endpoint = conn.request_path

      case RateLimiter.check_rate(user_id, endpoint, role) do
        {:ok, rate_info} ->
          conn
          |> maybe_add_rate_limit_headers(rate_info, opts)
          |> log_rate_limit_success(user_id, endpoint, rate_info, opts)

        {:error, rate_info} ->
          conn
          |> maybe_add_rate_limit_headers(rate_info, opts)
          |> log_rate_limit_violation(user_id, endpoint, rate_info, opts)
          |> send_rate_limit_error(rate_info, opts)
          |> halt()
      end
    else
      {:error, :missing_auth} ->
        # Apply anonymous user limits
        apply_anonymous_rate_limit(conn, opts)

      {:error, reason} ->
        Logger.warning("Rate limit check failed", reason: reason, path: conn.request_path)
        # Continue request on rate limit system failure
        conn
    end
  end

  @spec extract_user_id(term()) :: term()
  defp extract_user_id(conn) do
    case get_session(conn, :user_id) || get_req_header(conn, "x-user-id") do
      nil -> {:error, :missing_auth}
      [] -> {:error, :missing_auth}
      [user_id] when is_binary(user_id) -> {:ok, user_id}
      user_id when is_binary(user_id) -> {:ok, user_id}
      _ -> {:error, :invalid_user_id}
    end
  end

  @spec extract_user_role(term()) :: term()
  defp extract_user_role(conn) do
    case get_session(conn, :user_role) || get_req_header(conn, "x-user-role") do
      # Default role
      nil -> {:ok, "viewer"}
      # Default role
      [] -> {:ok, "viewer"}
      [role] when is_binary(role) -> {:ok, role}
      role when is_binary(role) -> {:ok, role}
      _ -> {:error, :invalid_role}
    end
  end

  @spec apply_anonymous_rate_limit(term(), term()) :: term()
  defp apply_anonymous_rate_limit(conn, opts) do
    # Use IP address for anonymous rate limiting
    client_ip = get_client_ip(conn)
    endpoint = conn.request_path

    case RateLimiter.check_rate("anonymous:#{client_ip}", endpoint, "anonymous") do
      {:ok, rate_info} ->
        conn
        |> maybe_add_rate_limit_headers(rate_info, opts)

      {:error, rate_info} ->
        conn
        |> maybe_add_rate_limit_headers(rate_info, opts)
        |> log_anonymous_rate_limit_violation(client_ip, endpoint, rate_info, opts)
        |> send_rate_limit_error(rate_info, opts)
        |> halt()
    end
  end

  @spec get_client_ip(term()) :: term()
  defp get_client_ip(conn) do
    # Extract real client IP, considering proxies
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [real_ip] ->
            String.trim(real_ip)

          [] ->
            conn.remote_ip
            |> :inet.ntoa()
            |> to_string()
        end
    end
  end

  @spec maybe_add_rate_limit_headers(Plug.Conn.t(), map(), map()) :: Plug.Conn.t()
  defp maybe_add_rate_limit_headers(conn, rate_info, opts) do
    if opts.include_headers do
      conn
      |> put_resp_header("x-ratelimit-limit", to_string(rate_info.limit))
      |> put_resp_header("x-ratelimit-remaining", to_string(rate_info.remaining))
      |> put_resp_header("x-ratelimit-reset", to_string(rate_info.reset_time))
      |> maybe_add_retry_after_header(rate_info)
    else
      conn
    end
  end

  @spec maybe_add_retry_after_header(term(), map()) :: term()
  defp maybe_add_retry_after_header(conn, %{retryafter: retry_after}) do
    put_resp_header(conn, "retry-after", to_string(retry_after))
  end

  defp maybe_add_retry_after_header(conn, _), do: conn

  @spec send_rate_limit_error(Plug.Conn.t(), map(), map()) :: Plug.Conn.t()
  defp send_rate_limit_error(conn, rate_info, opts) do
    error_response = %{
      error: %{
        code: "RATE_LIMIT_EXCEEDED",
        message: opts.error_message,
        details: %{
          limit: rate_info.limit,
          window_seconds: rate_info.retry_after || 60,
          reset_time: rate_info.reset_time
        }
      }
    }

    conn
    |> put_status(opts.error_status)
    |> put_resp_content_type("application/json")
    |> send_resp(opts.error_status, Jason.encode!(error_response))
  end

  @spec log_rate_limit_success(Plug.Conn.t(), String.t(), String.t(), map(), map()) ::
          Plug.Conn.t()
  defp log_rate_limit_success(conn, user_id, endpoint, rate_info, opts) do
    if opts.log_violations do
      Logger.debug("Rate limit check passed",
        user_id: user_id,
        endpoint: endpoint,
        count: rate_info.count,
        limit: rate_info.limit,
        remaining: rate_info.remaining
      )
    end

    :telemetry.execute(
      [:indrajaal_web, :rate_limit, :success],
      %{count: rate_info.count, remaining: rate_info.remaining},
      %{user_id: user_id, endpoint: endpoint}
    )

    conn
  end

  @spec log_rate_limit_violation(Plug.Conn.t(), String.t(), String.t(), map(), map()) ::
          Plug.Conn.t()
  defp log_rate_limit_violation(conn, user_id, endpoint, rate_info, opts) do
    if opts.log_violations do
      Logger.warning("Rate limit exceeded",
        user_id: user_id,
        endpoint: endpoint,
        count: rate_info.count,
        limit: rate_info.limit,
        client_ip: get_client_ip(conn)
      )
    end

    :telemetry.execute(
      [:indrajaal_web, :rate_limit, :violation],
      %{count: rate_info.count, limit: rate_info.limit},
      %{user_id: user_id, endpoint: endpoint}
    )

    conn
  end

  @spec log_anonymous_rate_limit_violation(Plug.Conn.t(), String.t(), String.t(), map(), map()) ::
          Plug.Conn.t()
  defp log_anonymous_rate_limit_violation(conn, client_ip, endpoint, rate_info, opts) do
    if opts.log_violations do
      Logger.warning("Anonymous rate limit exceeded",
        client_ip: client_ip,
        endpoint: endpoint,
        count: rate_info.count,
        limit: rate_info.limit
      )
    end

    :telemetry.execute(
      [:indrajaal_web, :rate_limit, :anonymous_violation],
      %{count: rate_info.count, limit: rate_info.limit},
      %{client_ip: client_ip, endpoint: endpoint}
    )

    conn
  end

  @spec bypass_path?(term(), term()) :: term()
  defp bypass_path?(request_path, bypass_paths) do
    Enum.any?(bypass_paths, fn bypass_path ->
      String.starts_with?(request_path, bypass_path)
    end)
  end

  @doc """
  Convenience function to add rate limiting to a specific route
  """
  @spec rate_limit(any(), any()) :: any()
  def rate_limit(conn, opts) do
    call(conn, init(opts))
  end

  @doc """
  Add custom rate limiting configuration for specific controller actions
  """
  @spec custom_rate_limit(Plug.Conn.t(), integer(), integer(), list()) :: Plug.Conn.t()
  def custom_rate_limit(conn, limit, window, opts \\ []) do
    merged_opts =
      opts
      |> Map.new()
      |> Map.merge(%{limit: limit, window: window})
      |> Map.merge(@default_opts)

    call(conn, merged_opts)
  end
end
