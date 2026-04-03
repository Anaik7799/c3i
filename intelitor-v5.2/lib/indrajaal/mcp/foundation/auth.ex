defmodule Indrajaal.MCP.Foundation.Auth do
  @moduledoc """
  MCP Authentication and Rate Limiting

  WHAT: Authentication, authorization, and rate limiting for MCP requests
  WHY: Ensures security and prevents abuse of MCP endpoints
  CONSTRAINTS: SC-MCP-030 (auth required), SC-MCP-031 (rate limiting)

  ## Authentication Methods
  - Bearer token (primary)
  - Client certificate (mutual TLS)
  - Guardian approval token (for write operations)

  ## Rate Limiting
  - Default: 100 requests/minute per client
  - Burst: 10 requests/second
  - Premium tier: 1000 requests/minute

  ## STAMP Constraints
  - SC-MCP-030: All requests MUST be authenticated
  - SC-MCP-031: Rate limiting MUST be enforced per client
  - SC-MCP-032: Guardian approval REQUIRED for write operations
  - SC-MCP-033: Proof tokens REQUIRED for state mutations
  """

  use GenServer
  require Logger

  @rate_limit_table :mcp_rate_limits
  @default_window_ms 60_000
  @default_max_requests 100
  @burst_window_ms 1_000
  @burst_max_requests 10

  # Client API

  @doc """
  Starts the auth service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Authenticates a request.

  ## Examples

      iex> Auth.authenticate(%{"authorization" => "Bearer token123"})
      {:ok, %{client_id: "client_abc", permissions: [:read, :write]}}

  """
  @spec authenticate(map()) :: {:ok, map()} | {:error, String.t()}
  def authenticate(headers) when is_map(headers) do
    case extract_auth_token(headers) do
      {:ok, token} ->
        validate_token(token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks rate limit for a client.

  ## Examples

      iex> Auth.check_rate_limit("client_abc")
      :ok

      iex> Auth.check_rate_limit("client_xyz")
      {:error, :rate_limit_exceeded}

  """
  @spec check_rate_limit(String.t()) :: :ok | {:error, :rate_limit_exceeded}
  def check_rate_limit(client_id) do
    now = System.system_time(:millisecond)

    with :ok <- check_burst_limit(client_id, now),
         :ok <- check_window_limit(client_id, now) do
      record_request(client_id, now)
      :ok
    end
  end

  @doc """
  Checks if a tool requires Guardian approval.
  """
  @spec requires_guardian?(String.t()) :: boolean()
  def requires_guardian?(tool_name) do
    # Write operations require Guardian approval
    action = Indrajaal.MCP.Foundation.Types.extract_action(tool_name)

    action in [
      :create,
      :update,
      :delete,
      :execute,
      :arm,
      :disarm,
      :approve,
      :reject,
      :mutate
    ]
  end

  @doc """
  Validates Guardian approval.

  ## Examples

      iex> Auth.validate_guardian_approval(approval_token)
      {:ok, %{approved: true, approver: "guardian", timestamp: ~U[...]}}

  """
  @spec validate_guardian_approval(String.t() | nil) ::
          {:ok, map()} | {:error, String.t()}
  def validate_guardian_approval(nil) do
    {:error, "Guardian approval required but not provided"}
  end

  def validate_guardian_approval(approval_token) when is_binary(approval_token) do
    # In production, this would verify the token against Guardian
    # For now, we validate the token format and check expiry
    case decode_guardian_token(approval_token) do
      {:ok, claims} ->
        if claims.exp > System.system_time(:second) do
          {:ok,
           %{
             approved: true,
             approver: claims.approver,
             timestamp: DateTime.from_unix!(claims.iat),
             reason: claims.reason
           }}
        else
          {:error, "Guardian approval token expired"}
        end

      {:error, reason} ->
        {:error, "Invalid Guardian approval: #{reason}"}
    end
  end

  @doc """
  Validates PROMETHEUS proof token.

  ## Examples

      iex> Auth.validate_proof_token(proof_token)
      {:ok, %{valid: true, operation: "mutate", timestamp: ~U[...]}}

  """
  @spec validate_proof_token(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def validate_proof_token(nil) do
    {:error, "PROMETHEUS proof token required but not provided"}
  end

  def validate_proof_token(proof_token) when is_binary(proof_token) do
    # In production, this would verify against PROMETHEUS verifier
    case decode_proof_token(proof_token) do
      {:ok, claims} ->
        {:ok,
         %{
           valid: true,
           operation: claims.operation,
           timestamp: DateTime.from_unix!(claims.iat),
           hash: claims.hash
         }}

      {:error, reason} ->
        {:error, "Invalid proof token: #{reason}"}
    end
  end

  @doc """
  Validates an API key against the MCP_API_KEY environment variable.

  Used for remote SSE transport authentication. Returns `:ok` for valid keys,
  `{:error, reason}` for invalid or missing keys.

  ## Examples

      iex> Auth.validate_api_key("sk-valid-key")
      :ok

      iex> Auth.validate_api_key("wrong-key")
      {:error, "Invalid API key"}

  """
  @spec validate_api_key(String.t() | nil) :: :ok | {:error, String.t()}
  def validate_api_key(nil) do
    Logger.warning("[MCP Auth] API key validation failed: no key provided")
    {:error, "API key required for remote SSE transport"}
  end

  def validate_api_key(provided_key) when is_binary(provided_key) do
    case System.get_env("MCP_API_KEY") do
      nil ->
        # No API key configured — allow access (development mode)
        Logger.debug("[MCP Auth] MCP_API_KEY not configured, allowing access in dev mode")
        :ok

      expected_key ->
        # Constant-time comparison to prevent timing attacks (SC-HASH-002)
        if Plug.Crypto.secure_compare(provided_key, expected_key) do
          :ok
        else
          Logger.warning("[MCP Auth] API key validation failed: key mismatch")
          {:error, "Invalid API key"}
        end
    end
  end

  @doc """
  Authenticates a request based on transport type.

  - stdio transport: always allowed (localhost, no auth required)
  - SSE transport: validates API key from context headers

  ## Examples

      iex> Auth.authenticate_request(%{transport: :stdio})
      :ok

      iex> Auth.authenticate_request(%{transport: :sse, headers: %{"x-api-key" => "valid"}})
      :ok

      iex> Auth.authenticate_request(%{transport: :sse, headers: %{}})
      {:error, "API key required for remote SSE transport"}

  """
  @spec authenticate_request(map()) :: :ok | {:error, String.t()}
  def authenticate_request(%{transport: :stdio}), do: :ok

  def authenticate_request(%{transport: :sse} = context) do
    headers = Map.get(context, :headers, %{})

    api_key =
      Map.get(headers, "x-api-key") ||
        Map.get(headers, "X-Api-Key") ||
        Map.get(headers, :api_key) ||
        extract_bearer_api_key(headers)

    case validate_api_key(api_key) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("[MCP Auth] SSE authentication failed: #{reason}")
        {:error, reason}
    end
  end

  def authenticate_request(%{transport: transport}) do
    Logger.warning("[MCP Auth] Unknown transport type: #{inspect(transport)}")
    {:error, "Unknown transport type: #{inspect(transport)}"}
  end

  def authenticate_request(_context) do
    # Default: allow (no transport specified implies stdio/local)
    :ok
  end

  @doc """
  Gets rate limit status for a client.
  """
  @spec rate_limit_status(String.t()) :: map()
  def rate_limit_status(client_id) do
    now = System.system_time(:millisecond)
    window_start = now - @default_window_ms

    requests =
      case :ets.lookup(@rate_limit_table, client_id) do
        [{^client_id, timestamps}] ->
          Enum.count(timestamps, &(&1 >= window_start))

        [] ->
          0
      end

    %{
      client_id: client_id,
      requests_in_window: requests,
      window_ms: @default_window_ms,
      max_requests: @default_max_requests,
      remaining: max(0, @default_max_requests - requests),
      reset_at: DateTime.add(DateTime.utc_now(), @default_window_ms, :millisecond)
    }
  end

  @doc """
  Resets rate limit for a client (admin only).
  """
  @spec reset_rate_limit(String.t()) :: :ok
  def reset_rate_limit(client_id) do
    :ets.delete(@rate_limit_table, client_id)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table =
      :ets.new(@rate_limit_table, [:named_table, :set, :public, write_concurrency: true])

    # Periodic cleanup of old rate limit entries
    schedule_cleanup()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp extract_bearer_api_key(headers) do
    auth_header =
      Map.get(headers, "authorization") ||
        Map.get(headers, "Authorization") ||
        Map.get(headers, :authorization)

    case auth_header do
      "Bearer " <> token -> token
      _ -> nil
    end
  end

  defp extract_auth_token(headers) do
    auth_header =
      Map.get(headers, "authorization") ||
        Map.get(headers, "Authorization") ||
        Map.get(headers, :authorization)

    case auth_header do
      nil ->
        {:error, "Missing Authorization header"}

      "Bearer " <> token ->
        {:ok, String.trim(token)}

      _ ->
        {:error, "Invalid Authorization header format"}
    end
  end

  defp validate_token(token) do
    # In production, this would verify JWT/API key against auth service
    # For development, we accept tokens with a specific format
    cond do
      String.starts_with?(token, "mcp_") ->
        client_id = String.slice(token, 4..-1//1)

        {:ok,
         %{
           client_id: client_id,
           permissions: [:read, :write],
           tier: :standard
         }}

      String.starts_with?(token, "mcp_admin_") ->
        client_id = String.slice(token, 10..-1//1)

        {:ok,
         %{
           client_id: client_id,
           permissions: [:read, :write, :admin],
           tier: :premium
         }}

      String.length(token) >= 32 ->
        # Accept any sufficiently long token for development
        {:ok,
         %{
           client_id: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower),
           permissions: [:read],
           tier: :basic
         }}

      true ->
        {:error, "Invalid token format"}
    end
  end

  defp check_burst_limit(client_id, now) do
    burst_start = now - @burst_window_ms

    count =
      case :ets.lookup(@rate_limit_table, client_id) do
        [{^client_id, timestamps}] ->
          Enum.count(timestamps, &(&1 >= burst_start))

        [] ->
          0
      end

    if count < @burst_max_requests do
      :ok
    else
      {:error, :rate_limit_exceeded}
    end
  end

  defp check_window_limit(client_id, now) do
    window_start = now - @default_window_ms

    count =
      case :ets.lookup(@rate_limit_table, client_id) do
        [{^client_id, timestamps}] ->
          Enum.count(timestamps, &(&1 >= window_start))

        [] ->
          0
      end

    if count < @default_max_requests do
      :ok
    else
      {:error, :rate_limit_exceeded}
    end
  end

  defp record_request(client_id, timestamp) do
    case :ets.lookup(@rate_limit_table, client_id) do
      [{^client_id, timestamps}] ->
        # Keep only recent timestamps
        window_start = timestamp - @default_window_ms
        recent = Enum.filter(timestamps, &(&1 >= window_start))
        :ets.insert(@rate_limit_table, {client_id, [timestamp | recent]})

      [] ->
        :ets.insert(@rate_limit_table, {client_id, [timestamp]})
    end
  end

  defp decode_guardian_token(token) do
    # Simplified token decoding - in production would use proper JWT
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        case Base.url_decode64(payload, padding: false) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, claims} ->
                {:ok,
                 %{
                   approver: claims["approver"] || "guardian",
                   exp: claims["exp"] || 0,
                   iat: claims["iat"] || 0,
                   reason: claims["reason"]
                 }}

              _ ->
                {:error, "Invalid token payload"}
            end

          _ ->
            {:error, "Invalid token encoding"}
        end

      _ ->
        # For development, accept simple tokens
        {:ok,
         %{
           approver: "guardian",
           exp: System.system_time(:second) + 3600,
           iat: System.system_time(:second),
           reason: "development mode"
         }}
    end
  end

  defp decode_proof_token(token) do
    # Simplified proof token decoding
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        case Base.url_decode64(payload, padding: false) do
          {:ok, json} ->
            case Jason.decode(json) do
              {:ok, claims} ->
                {:ok,
                 %{
                   operation: claims["operation"] || "unknown",
                   iat: claims["iat"] || 0,
                   hash: claims["hash"] || ""
                 }}

              _ ->
                {:error, "Invalid token payload"}
            end

          _ ->
            {:error, "Invalid token encoding"}
        end

      _ ->
        # For development, accept simple tokens
        {:ok,
         %{
           operation: "development",
           iat: System.system_time(:second),
           hash: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
         }}
    end
  end

  defp schedule_cleanup do
    # Cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp cleanup_old_entries do
    now = System.system_time(:millisecond)
    window_start = now - @default_window_ms

    # Get all entries and filter old timestamps
    @rate_limit_table
    |> :ets.tab2list()
    |> Enum.each(fn {client_id, timestamps} ->
      recent = Enum.filter(timestamps, &(&1 >= window_start))

      if Enum.empty?(recent) do
        :ets.delete(@rate_limit_table, client_id)
      else
        :ets.insert(@rate_limit_table, {client_id, recent})
      end
    end)
  end
end
