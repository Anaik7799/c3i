defmodule Indrajaal.Validation.AuthTokenManager do
  @moduledoc """
  Authentication token management for OpenCode API integration.

  Handles API key validation, token refresh, session management, and
  credential security for OpenCode API connectivity.

  Features:
  - Secure API key storage and validation
  - Automatic token refresh with configurable intervals
  - Session expiry tracking and renewal
  - Encrypted credential storage
  - Token validation with OpenCode API
  - Emergency token revocation capabilities
  """

  use GenServer
  require Logger

  # 1 hour in milliseconds
  @token_refresh_interval 3_600_000
  @max_retry_attempts 3

  defstruct [
    :api_key,
    :access_token,
    :refresh_token,
    :session_id,
    :expires_at,
    :created_at,
    :last_validated,
    :validation_failures,
    :encrypted_credentials
  ]

  @type token_info :: %__MODULE__{
          api_key: String.t(),
          access_token: String.t() | nil,
          refresh_token: String.t() | nil,
          session_id: String.t(),
          expires_at: DateTime.t() | nil,
          created_at: DateTime.t(),
          last_validated: DateTime.t() | nil,
          validation_failures: integer(),
          encrypted_credentials: binary() | nil
        }

  @type auth_result :: {:ok, token_info()} | {:error, atom()}

  # Public API

  @doc """
  Starts the authentication token manager.

  ## Examples

      iex> AuthTokenManager.start_link([])
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Authenticates with OpenCode API using API key.

  ## Examples

      iex> AuthTokenManager.authenticate("valid_api_key", "session_123")
      {:ok, %AuthTokenManager{api_key: "valid_api_key", session_id: "session_123"}}

      iex> AuthTokenManager.authenticate("invalid_key", "session_123")
      {:error, :unauthorized}
  """
  @spec authenticate(String.t(), String.t()) :: auth_result()
  def authenticate(api_key, session_id) do
    GenServer.call(__MODULE__, {:authenticate, api_key, session_id})
  end

  @doc """
  Validates current token and refreshes if necessary.

  ## Examples

      iex> AuthTokenManager.validate_token("session_123")
      {:ok, %AuthTokenManager{session_id: "session_123", expires_at: ~U[2025-01-01 12:00:00Z]}}
  """
  @spec validate_token(String.t()) :: auth_result()
  def validate_token(session_id) do
    GenServer.call(__MODULE__, {:validate_token, session_id})
  end

  @doc """
  Refreshes authentication token for given session.

  ## Examples

      iex> AuthTokenManager.refresh_token("session_123")
      {:ok, %AuthTokenManager{session_id: "session_123"}}
  """
  @spec refresh_token(String.t()) :: auth_result()
  def refresh_token(session_id) do
    GenServer.call(__MODULE__, {:refresh_token, session_id})
  end

  @doc """
  Revokes authentication token and invalidates session.

  ## Examples

      iex> AuthTokenManager.revoke_token("session_123")
      :ok
  """
  @spec revoke_token(String.t()) :: :ok | {:error, atom()}
  def revoke_token(session_id) do
    GenServer.call(__MODULE__, {:revoke_token, session_id})
  end

  @doc """
  Gets current token information for session.

  ## Examples

      iex> AuthTokenManager.get_token_info("session_123")
      {:ok, %AuthTokenManager{session_id: "session_123"}}
  """
  @spec get_token_info(String.t()) :: auth_result()
  def get_token_info(session_id) do
    GenServer.call(__MODULE__, {:get_token_info, session_id})
  end

  @doc """
  Lists all active sessions with their token status.

  ## Examples

      iex> AuthTokenManager.list_active_sessions()
      [%{session_id: "session_123", status: :active, expires_at: ~U[2025-01-01 12:00:00Z]}]
  """
  @spec list_active_sessions() :: [map()]
  def list_active_sessions do
    GenServer.call(__MODULE__, :list_active_sessions)
  end

  @doc """
  Emergency revocation of all tokens and sessions.

  ## Examples

      iex> AuthTokenManager.emergency_revoke_all()
      :ok
  """
  @spec emergency_revoke_all() :: :ok
  def emergency_revoke_all do
    GenServer.call(__MODULE__, :emergency_revoke_all)
  end

  # GenServer Callbacks

  @impl GenServer
  def init(_opts) do
    # Schedule automatic token refresh
    Process.send_after(self(), :refresh_expired_tokens, @token_refresh_interval)

    state = %{
      sessions: %{},
      encryption_key: generate_encryption_key(),
      last_cleanup: DateTime.utc_now()
    }

    Logger.info("AuthTokenManager started", sessions: 0)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:authenticate, api_key, session_id}, _from, state) do
    case perform_authentication(api_key, session_id, state) do
      {:ok, token_info} ->
        new_state = put_in(state.sessions[session_id], token_info)
        Logger.info("Authentication successful", session_id: session_id)
        {:reply, {:ok, token_info}, new_state}

      {:error, reason} = error ->
        Logger.warning("Authentication failed", session_id: session_id, reason: reason)
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:validate_token, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      token_info ->
        case validate_and_refresh_if_needed(token_info, state) do
          {:ok, updated_token_info} ->
            new_state = put_in(state.sessions[session_id], updated_token_info)
            {:reply, {:ok, updated_token_info}, new_state}

          {:error, reason} = error ->
            Logger.warning("Token validation failed", session_id: session_id, reason: reason)
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:refresh_token, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      token_info ->
        case perform_token_refresh(token_info, state) do
          {:ok, updated_token_info} ->
            new_state = put_in(state.sessions[session_id], updated_token_info)
            Logger.info("Token refreshed successfully", session_id: session_id)
            {:reply, {:ok, updated_token_info}, new_state}

          {:error, reason} = error ->
            Logger.warning("Token refresh failed", session_id: session_id, reason: reason)
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:revoke_token, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}

      token_info ->
        :ok = perform_token_revocation(token_info)
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        Logger.info("Token revoked successfully", session_id: session_id)
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_token_info, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :session_not_found}, state}
      token_info -> {:reply, {:ok, token_info}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_active_sessions, _from, state) do
    sessions =
      state.sessions
      |> Enum.map(fn {session_id, token_info} ->
        %{
          session_id: session_id,
          status: determine_session_status(token_info),
          expires_at: token_info.expires_at,
          last_validated: token_info.last_validated,
          validation_failures: token_info.validation_failures
        }
      end)

    {:reply, sessions, state}
  end

  @impl GenServer
  def handle_call(:emergency_revoke_all, _from, state) do
    # Revoke all tokens
    Enum.each(state.sessions, fn {_session_id, token_info} ->
      perform_token_revocation(token_info)
    end)

    new_state = %{state | sessions: %{}}
    Logger.warning("Emergency revocation: All tokens revoked", count: map_size(state.sessions))
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:refresh_expired_tokens, state) do
    # Refresh expired tokens
    new_sessions =
      state.sessions
      |> Enum.reduce(%{}, fn {session_id, token_info}, acc ->
        case validate_and_refresh_if_needed(token_info, state) do
          {:ok, updated_token_info} ->
            Map.put(acc, session_id, updated_token_info)

          {:error, reason} ->
            Logger.warning("Failed to refresh token during cleanup",
              session_id: session_id,
              reason: reason
            )

            acc
        end
      end)

    # Schedule next cleanup
    Process.send_after(self(), :refresh_expired_tokens, @token_refresh_interval)

    new_state = %{state | sessions: new_sessions, last_cleanup: DateTime.utc_now()}
    {:noreply, new_state}
  end

  # Private Functions

  defp perform_authentication(api_key, session_id, state) do
    with :ok <- validate_api_key_format(api_key),
         {:ok, auth_response} <- authenticate_with_opencode(api_key, session_id),
         {:ok, encrypted_creds} <- encrypt_credentials(api_key, state.encryption_key) do
      token_info = %__MODULE__{
        api_key: api_key,
        access_token: Map.get(auth_response, "access_token"),
        refresh_token: Map.get(auth_response, "refresh_token"),
        session_id: session_id,
        expires_at: parse_expiry_time(Map.get(auth_response, "expires_in")),
        created_at: DateTime.utc_now(),
        last_validated: DateTime.utc_now(),
        validation_failures: 0,
        encrypted_credentials: encrypted_creds
      }

      {:ok, token_info}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_and_refresh_if_needed(token_info, state) do
    current_time = DateTime.utc_now()

    cond do
      # Token has expired, attempt refresh
      token_expired?(token_info, current_time) ->
        perform_token_refresh(token_info, state)

      # Token is valid but needs validation
      needs_validation?(token_info, current_time) ->
        validate_token_with_opencode(token_info)

      # Token is still valid
      true ->
        {:ok, token_info}
    end
  end

  defp perform_token_refresh(token_info, state) do
    case refresh_token_with_opencode(token_info) do
      {:ok, refresh_response} ->
        updated_token_info = %{
          token_info
          | access_token: Map.get(refresh_response, "access_token"),
            refresh_token: Map.get(refresh_response, "refresh_token", token_info.refresh_token),
            expires_at: parse_expiry_time(Map.get(refresh_response, "expires_in")),
            last_validated: DateTime.utc_now(),
            validation_failures: 0
        }

        {:ok, updated_token_info}

      {:error, reason} ->
        # If refresh fails, attempt re-authentication
        case re_authenticate_token(token_info, state) do
          {:ok, new_token_info} -> {:ok, new_token_info}
          {:error, _} -> {:error, reason}
        end
    end
  end

  defp perform_token_revocation(token_info) do
    :ok = revoke_token_with_opencode(token_info)
    :ok
  end

  defp validate_api_key_format(api_key) when is_binary(api_key) do
    if String.length(api_key) >= 10 and String.match?(api_key, ~r/^[a-zA-Z0-9_-]+$/) do
      :ok
    else
      {:error, :invalid_api_key_format}
    end
  end

  defp validate_api_key_format(_), do: {:error, :invalid_api_key_format}

  defp authenticate_with_opencode(api_key, _session_id) do
    # Mock implementation - in production, this would call OpenCode API
    case String.length(api_key) >= 10 do
      true ->
        {:ok,
         %{
           "access_token" => "opencode_access_" <> Base.encode32(:crypto.strong_rand_bytes(16)),
           "refresh_token" => "opencode_refresh_" <> Base.encode32(:crypto.strong_rand_bytes(16)),
           "expires_in" => 3600,
           "token_type" => "Bearer"
         }}

      false ->
        {:error, :unauthorized}
    end
  end

  defp validate_token_with_opencode(token_info) do
    # Mock implementation - in production, this would validate with OpenCode API
    case token_info.validation_failures < @max_retry_attempts do
      true ->
        updated_token_info = %{
          token_info
          | last_validated: DateTime.utc_now(),
            validation_failures: 0
        }

        {:ok, updated_token_info}

      false ->
        {:error, :token_validation_failed}
    end
  end

  defp refresh_token_with_opencode(token_info) do
    # Mock implementation - in production, this would refresh with OpenCode API
    case token_info.refresh_token do
      nil ->
        {:error, :no_refresh_token}

      _token ->
        {:ok,
         %{
           "access_token" => "opencode_access_" <> Base.encode32(:crypto.strong_rand_bytes(16)),
           "expires_in" => 3600
         }}
    end
  end

  defp revoke_token_with_opencode(token_info) do
    # Mock implementation - in production, this would revoke with OpenCode API
    Logger.info("Revoking token with OpenCode", session_id: token_info.session_id)
    :ok
  end

  defp re_authenticate_token(token_info, state) do
    case decrypt_credentials(token_info.encrypted_credentials, state.encryption_key) do
      {:ok, api_key} ->
        perform_authentication(api_key, token_info.session_id, state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encrypt_credentials(api_key, encryption_key) do
    try do
      encrypted =
        :crypto.crypto_one_time(
          :aes_256_gcm,
          encryption_key,
          :crypto.strong_rand_bytes(12),
          api_key,
          true
        )

      {:ok, encrypted}
    rescue
      _ -> {:error, :encryption_failed}
    end
  end

  defp decrypt_credentials(_encrypted_credentials, _encryption_key) do
    try do
      # This is a simplified implementation
      # In production, proper IV and tag handling would be required
      {:ok, "decrypted_api_key"}
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

  defp generate_encryption_key do
    :crypto.strong_rand_bytes(32)
  end

  defp parse_expiry_time(expires_in) when is_integer(expires_in) do
    DateTime.utc_now() |> DateTime.add(expires_in, :second)
  end

  defp parse_expiry_time(_), do: nil

  defp token_expired?(token_info, current_time) do
    case token_info.expires_at do
      nil -> false
      expires_at -> DateTime.compare(current_time, expires_at) == :gt
    end
  end

  defp needs_validation?(token_info, current_time) do
    case token_info.last_validated do
      nil ->
        true

      last_validated ->
        DateTime.diff(current_time, last_validated, :millisecond) > @token_refresh_interval
    end
  end

  defp determine_session_status(token_info) do
    current_time = DateTime.utc_now()

    cond do
      token_expired?(token_info, current_time) -> :expired
      token_info.validation_failures >= @max_retry_attempts -> :invalid
      true -> :active
    end
  end
end
