defmodule Intelitor.Accounts.Authentication do
  @moduledoc """
  Complete authentication module providing all functionality previously handled by Entra ID.
  This includes user management, JWT tokens, MFA, password policies, and session management.
  """

  use GenServer
  require Logger

  import Ecto.Query
  alias Intelitor.Repo
  alias Intelitor.Accounts.{User, Session}

  # Configuration
  @jwt_algorithm "HS512"
  # 15 minutes
  @access_token_ttl 900
  # 30 days
  @refresh_token_ttl 2_592_000
  @max_failed_attempts 5

  # Password policies
  @password_policies %{
    basic: %{
      min_length: 8,
      require_uppercase: false,
      require_lowercase: true,
      require_numbers: true,
      require_special: false
    },
    moderate: %{
      min_length: 10,
      require_uppercase: true,
      require_lowercase: true,
      require_numbers: true,
      require_special: false
    },
    strong: %{
      min_length: 12,
      require_uppercase: true,
      require_lowercase: true,
      require_numbers: true,
      require_special: true
    },
    paranoid: %{
      min_length: 16,
      require_uppercase: true,
      require_lowercase: true,
      require_numbers: true,
      require_special: true,
      require_no_common_patterns: true
    }
  }

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Authenticate a user with email/username and password.
  Returns user and tokens on success.
  """
  def authenticate(identifier, password, opts \\ []) do
    with {:ok, user} <- validate_user_credentials(identifier, password, opts),
         {:ok, tokens} <- generate_token_set(user),
         {:ok, _session} <- create_session(user, opts) do
      {:ok, build_auth_response(user, tokens, opts)}
    else
      {:error, :invalid_credentials} = error ->
        handle_failed_login(identifier)
        error

      error ->
        error
    end
  end

  @doc """
  Register a new user with local authentication.
  """
  def register(attrs) do
    # Use the register action defined in User resource
    case User.register(attrs) do
      {:ok, user} ->
        maybe_send_confirmation_email(user)
        {:ok, sanitize_user(user)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Verify and decode a JWT token.
  """
  def verify_token(token) do
    with {:ok, claims} <- decode_token(token),
         {:ok, user} <- get_user_from_claims(claims),
         :ok <- verify_token_validity(claims, user) do
      {:ok, user}
    end
  end

  @doc """
  Refresh tokens using a refresh token.
  """
  def refresh_tokens(refresh_token) do
    with {:ok, claims} <- decode_token(refresh_token),
         :ok <- verify_refresh_token(claims),
         {:ok, user} <- get_user_from_claims(claims) do
      generate_token_set(user)
    end
  end

  @doc """
  Enable MFA for a user.
  """
  def enable_mfa(user_id) do
    with {:ok, user} <- get_user(user_id),
         secret <- generate_totp_secret(),
         {:ok, user} <- update_user_mfa(user, secret, true) do
      {:ok,
       %{
         secret: secret,
         qr_code: generate_qr_code(user.email, secret),
         recovery_codes: generate_recovery_codes()
       }}
    end
  end

  @doc """
  Disable MFA for a user.
  """
  def disable_mfa(user_id, password) do
    with {:ok, user} <- get_user(user_id),
         :ok <- verify_password(password, user),
         {:ok, user} <- update_user_mfa(user, nil, false) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Verify MFA token.
  """
  def verify_mfa_token(user_id, token) do
    with {:ok, user} <- get_user(user_id),
         true <- user.mfa_enabled,
         :ok <- verify_totp(user.mfa_secret, token) do
      :ok
    else
      false -> {:error, :mfa_not_enabled}
      error -> error
    end
  end

  @doc """
  Change user password.
  """
  def change_password(user_id, current_password, new_password) do
    with {:ok, user} <- get_user(user_id),
         :ok <- verify_password(current_password, user),
         :ok <- validate_password_policy(new_password, user),
         {:ok, user} <- update_password(user, new_password) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Request password reset.
  """
  def request_password_reset(email) do
    case get_user_by_email(email) do
      {:ok, user} ->
        token = generate_reset_token()
        expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

        with {:ok, _} <- save_reset_token(user, token, expires_at) do
          send_password_reset_email(user, token)
          {:ok, :email_sent}
        end

      _ ->
        # Don't reveal whether email exists
        {:ok, :email_sent}
    end
  end

  @doc """
  Reset password with token.
  """
  def reset_password(token, new_password) do
    with {:ok, user} <- verify_reset_token(token),
         :ok <- validate_password_policy(new_password, user),
         {:ok, user} <- update_password(user, new_password),
         :ok <- clear_reset_token(user) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Confirm email with token.
  """
  def confirm_email(token) do
    with {:ok, user} <- get_user_by_confirmation_token(token),
         {:ok, user} <- confirm_user(user) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Lock user account.
  """
  def lock_account(user_id, reason \\ "Manual lock") do
    with {:ok, user} <- get_user(user_id),
         {:ok, user} <-
           update_user(user, %{
             locked_at: DateTime.utc_now(),
             lock_reason: reason
           }) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Unlock user account.
  """
  def unlock_account(user_id) do
    with {:ok, user} <- get_user(user_id),
         {:ok, user} <-
           update_user(user, %{
             locked_at: nil,
             lock_reason: nil,
             failed_login_attempts: 0
           }) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Get active sessions for a user.
  """
  def get_user_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id and s.active == true)
    |> order_by([s], desc: s.last_activity_at)
    |> Repo.all()
  end

  @doc """
  Revoke a session.
  """
  def revoke_session(session_id, user_id) do
    Session
    |> where([s], s.id == ^session_id and s.user_id == ^user_id)
    |> Repo.update_all(set: [active: false, revoked_at: DateTime.utc_now()])

    :ok
  end

  @doc """
  Revoke all sessions for a user.
  """
  def revoke_all_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id and s.active == true)
    |> Repo.update_all(set: [active: false, revoked_at: DateTime.utc_now()])

    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Initialize signing key from config or generate new one
    signing_key =
      Application.get_env(:intelitor, :guardian_secret_key) ||
        :crypto.strong_rand_bytes(64) |> Base.encode64()

    state = %{
      signing_key: signing_key,
      failed_attempts: %{},
      active_sessions: %{}
    }

    # Schedule cleanup of expired sessions
    schedule_session_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup_sessions, state) do
    cleanup_expired_sessions()
    schedule_session_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp find_user_by_identifier(identifier) do
    query =
      from u in User,
        where: u.email == ^identifier or u.username == ^identifier,
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :invalid_credentials}
      user -> {:ok, user}
    end
  end

  defp check_account_status(user) do
    cond do
      user.locked_at != nil ->
        {:error, :account_locked}

      user.confirmed_at == nil && requires_confirmation?() ->
        {:error, :email_not_confirmed}

      !user.active ->
        {:error, :account_inactive}

      true ->
        :ok
    end
  end

  defp verify_password(password, user) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      :ok
    else
      {:error, :invalid_credentials}
    end
  end

  defp check_mfa_if_enabled(user, mfa_token) do
    if user.mfa_enabled && mfa_token do
      verify_totp(user.mfa_secret, mfa_token)
    else
      :ok
    end
  end

  defp generate_token_set(user) do
    now = System.system_time(:second)

    access_claims = %{
      "sub" => user.id,
      "email" => user.email,
      "username" => user.username,
      "tenant_id" => user.tenant_id,
      "role" => user.role,
      "type" => "access",
      "iat" => now,
      "exp" => now + @access_token_ttl
    }

    refresh_claims = %{
      "sub" => user.id,
      "jti" => Ecto.UUID.generate(),
      "type" => "refresh",
      "iat" => now,
      "exp" => now + @refresh_token_ttl
    }

    with {:ok, access_token} <- encode_token(access_claims),
         {:ok, refresh_token} <- encode_token(refresh_claims) do
      {:ok,
       %{
         access_token: access_token,
         refresh_token: refresh_token,
         token_type: "Bearer",
         expires_in: @access_token_ttl
       }}
    end
  end

  defp encode_token(claims) do
    GenServer.call(__MODULE__, {:encode_token, claims})
  end

  defp decode_token(token) do
    GenServer.call(__MODULE__, {:decode_token, token})
  end

  defp create_session(user, opts) do
    attrs = %{
      user_id: user.id,
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent],
      active: true,
      last_activity_at: DateTime.utc_now()
    }

    # TODO: Implement Session.changeset
    # For now, create session directly via Ash
    Session.create!(attrs)
  end

  defp handle_failed_login(identifier) do
    GenServer.cast(__MODULE__, {:failed_login, identifier})
  end

  defp sanitize_user(user) do
    Map.drop(user, [:password_hash, :mfa_secret, :recovery_codes])
  end

  defp validate_password_policy(password, _user) do
    policy_name = Application.get_env(:intelitor, :password_policy, :strong)
    policy = @password_policies[policy_name]

    errors = []

    errors =
      if String.length(password) < policy.min_length do
        ["must be at least #{policy.min_length} characters" | errors]
      else
        errors
      end

    errors =
      if policy.require_uppercase && !Regex.match?(~r/[A-Z]/, password) do
        ["must contain uppercase letters" | errors]
      else
        errors
      end

    errors =
      if policy.require_lowercase && !Regex.match?(~r/[a-z]/, password) do
        ["must contain lowercase letters" | errors]
      else
        errors
      end

    errors =
      if policy.require_numbers && !Regex.match?(~r/[0-9]/, password) do
        ["must contain numbers" | errors]
      else
        errors
      end

    errors =
      if policy.require_special && !Regex.match?(~r/[!@#$%^&*(),.?":{}|<>]/, password) do
        ["must contain special characters" | errors]
      else
        errors
      end

    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:password_policy, errors}}
    end
  end

  defp generate_totp_secret do
    :crypto.strong_rand_bytes(20) |> Base.encode32(padding: false)
  end

  defp verify_totp(secret, token) do
    case NimbleTOTP.valid?(secret, token) do
      true -> :ok
      false -> {:error, :invalid_mfa_token}
    end
  end

  defp generate_qr_code(email, secret) do
    issuer = Application.get_env(:intelitor, :totp_issuer, "Intelitor")
    _otpauth_url = NimbleTOTP.otpauth_uri(email, secret, issuer: issuer)

    # Generate QR code (would use a library like qr_code in production)
    "data:image/png;base64,QR_CODE_PLACEHOLDER"
  end

  defp generate_recovery_codes do
    Enum.map(1..10, fn _ ->
      :crypto.strong_rand_bytes(4) |> Base.encode16() |> String.downcase()
    end)
  end

  defp schedule_session_cleanup do
    Process.send_after(self(), :cleanup_sessions, :timer.minutes(30))
  end

  defp cleanup_expired_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -@access_token_ttl, :second)

    Session
    |> where([s], s.active == true and s.last_activity_at < ^cutoff)
    |> Repo.update_all(set: [active: false])
  end

  defp requires_confirmation? do
    Application.get_env(:intelitor, :require_email_confirmation, false)
  end

  defp maybe_send_confirmation_email(user) do
    if requires_confirmation?() do
      token = generate_confirmation_token()
      save_confirmation_token(user, token)
      send_confirmation_email(user, token)
    end
  end

  # Stub functions for email sending
  defp send_confirmation_email(_user, _token), do: :ok
  defp send_password_reset_email(_user, _token), do: :ok

  # Database helper stubs
  defp get_user(id), do: Repo.get(User, id)
  defp get_user_by_email(email), do: Repo.get_by(User, email: email)

  defp update_user(user, attrs) do
    # Use User.update_profile action
    case User.update_profile(user, attrs) do
      {:ok, updated} -> {:ok, updated}
      {:error, error} -> {:error, error}
    end
  end

  defp update_password(user, password) do
    # Use User.update_profile to update password
    case User.update_profile(user, %{password: password}) do
      {:ok, updated} -> {:ok, updated}
      {:error, error} -> {:error, error}
    end
  end

  defp update_user_mfa(user, secret, enabled),
    do: update_user(user, %{mfa_secret: secret, mfa_enabled: enabled})

  defp confirm_user(user), do: update_user(user, %{confirmed_at: DateTime.utc_now()})

  defp save_reset_token(user, token, expires_at),
    do: update_user(user, %{reset_password_token: token, reset_password_sent_at: expires_at})

  defp clear_reset_token(user),
    do: update_user(user, %{reset_password_token: nil, reset_password_sent_at: nil})

  defp save_confirmation_token(user, token), do: update_user(user, %{confirmation_token: token})
  defp get_user_by_confirmation_token(token), do: Repo.get_by(User, confirmation_token: token)
  defp verify_reset_token(token), do: Repo.get_by(User, reset_password_token: token)
  defp get_user_from_claims(%{"sub" => user_id}), do: get_user(user_id)

  defp verify_token_validity(%{"exp" => exp}, _user),
    do: if(exp > System.system_time(:second), do: :ok, else: {:error, :token_expired})

  defp verify_refresh_token(%{"type" => "refresh"}), do: :ok
  defp verify_refresh_token(_), do: {:error, :invalid_token_type}
  defp generate_reset_token, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  defp generate_confirmation_token, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64()

  # Commented out as it's not used with Ash resources
  # defp format_changeset_errors(changeset),
  #   do: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

  # GenServer callbacks for token encoding/decoding

  @impl true
  def handle_call({:encode_token, claims}, _from, state) do
    token =
      JOSE.JWT.sign(
        %{"alg" => @jwt_algorithm},
        claims,
        JOSE.JWK.from_oct(state.signing_key)
      )
      |> JOSE.JWS.compact()
      |> elem(1)

    {:reply, {:ok, token}, state}
  end

  @impl true
  def handle_call({:decode_token, token}, _from, state) do
    result =
      case JOSE.JWT.verify_strict(
             JOSE.JWK.from_oct(state.signing_key),
             [@jwt_algorithm],
             token
           ) do
        {true, jwt, _} -> {:ok, jwt.fields}
        {false, _, _} -> {:error, :invalid_signature}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:failed_login, identifier}, state) do
    attempts = Map.get(state.failed_attempts, identifier, 0) + 1

    if attempts >= @max_failed_attempts do
      lock_account_by_identifier(identifier)
      {:noreply, Map.delete(state.failed_attempts, identifier)}
    else
      {:noreply, Map.put(state.failed_attempts, identifier, attempts)}
    end
  end

  defp lock_account_by_identifier(identifier) do
    case find_user_by_identifier(identifier) do
      {:ok, user} -> lock_account(user.id, "Too many failed login attempts")
      _ -> :ok
    end
  end

  defp validate_user_credentials(identifier, password, opts) do
    with {:ok, user} <- find_user_by_identifier(identifier),
         :ok <- check_account_status(user),
         :ok <- verify_password(password, user),
         :ok <- check_mfa_if_enabled(user, opts[:mfa_token]) do
      {:ok, user}
    end
  end

  defp build_auth_response(user, tokens, opts) do
    %{
      user: sanitize_user(user),
      tokens: tokens,
      requires_mfa: user.mfa_enabled && !opts[:mfa_token]
    }
  end
end
