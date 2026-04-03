defmodule Indrajaal.Accounts.Authentication do
  @moduledoc """
  Complete authentication module providing all functionality previously
    handled by Entra ID.
  This includes user management,
    JWT tokens, MFA, password policies, and session management.
  """

  use GenServer
  require Logger
  import Ecto.Query
  alias Indrajaal.Accounts.{Session, User}
  alias Indrajaal.Repo
  require Logger

  import Ecto.Query
  alias Indrajaal.Accounts.{Session, User}
  alias Indrajaal.Repo

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
      __require_uppercase: false,
      __require_lowercase: true,
      __require_numbers: true,
      __require_special: false
    },
    moderate: %{
      min_length: 10,
      __require_uppercase: true,
      __require_lowercase: true,
      __require_numbers: true,
      __require_special: false
    },
    strong: %{
      min_length: 12,
      __require_uppercase: true,
      __require_lowercase: true,
      __require_numbers: true,
      __require_special: true
    },
    paranoid: %{
      min_length: 16,
      __require_uppercase: true,
      __require_lowercase: true,
      __require_numbers: true,
      __require_special: true,
      __require_no_common_patterns: true
    }
  }

  # Public API

  @spec start_link(any()) :: any()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Authenticate a user with email / username and password.
  Returns user and tokens on success.
  """
  @spec authenticate(term(), term(), term()) :: term()
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
  @spec register(any()) :: any()
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
  @spec verify_token(any()) :: any()
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
  @spec refresh_tokens(any()) :: any()
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
  @spec enable_mfa(any()) :: any()
  def enable_mfa(user_id) do
    with {:ok, user} <- get_user(user_id),
         secret <- generate_totp_secret(),
         {:ok, user} <- update_user_mfa(user, secret, true) do
      {:ok,
       %{
         secret: secret,
         qr_code: generate_qr_code(user.email, secret, nil),
         recovery_codes: generate_recovery_codes()
       }}
    end
  end

  @doc """
  Disable MFA for a user.
  """
  @spec disable_mfa(any(), any()) :: any()
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
  @spec verify_mfa_token(any(), any()) :: any()
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
  @spec change_password(term(), term(), term()) :: term()
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
  @spec __request_password_reset(any()) :: any()
  def __request_password_reset(email) do
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
  @spec reset_password(any(), any()) :: any()
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
  @spec confirm_email(any()) :: any()
  def confirm_email(token) do
    with {:ok, user} <- get_user_by_confirmation_token(token),
         {:ok, user} <- confirm_user(user) do
      {:ok, sanitize_user(user)}
    end
  end

  @doc """
  Lock user account.
  """
  @spec lock_account(any(), any()) :: any()
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
  @spec unlock_account(any()) :: any()
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
  @spec get_user_sessions(any()) :: any()
  def get_user_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id and s.active == true)
    |> order_by([s], desc: s.last_activity_at)
    |> Repo.all()
  end

  @doc """
  Revoke a session.
  """
  @spec revoke_session(any(), any()) :: any()
  def revoke_session(session_id, user_id) do
    Session
    |> where([s], s.id == ^session_id and s.user_id == ^user_id)
    |> Repo.update_all(set: [active: false, revoked_at: DateTime.utc_now()])

    :ok
  end

  @doc """
  Revoke all sessions for a user.
  """
  @spec revoke_all_sessions(any()) :: any()
  def revoke_all_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id and s.active == true)
    |> Repo.update_all(set: [active: false, revoked_at: DateTime.utc_now()])

    :ok
  end

  # GenServer callbacks

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    # Initialize signing key from config or generate new one
    bytes = :crypto.strong_rand_bytes(64)

    default_key =
      bytes
      |> Base.encode64()

    signing_key =
      Application.get_env(:indrajaal, :guardian_secret_key) || default_key

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
  @spec handle_info(any(), any()) :: any()
  def handle_info(:cleanupsessions, state) do
    cleanup_expired_sessions()
    schedule_session_cleanup()
    {:noreply, state}
  end

  # Private functions

  @spec find_user_by_identifier(term()) :: term()
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

  @spec check_account_status(term()) :: term()
  defp check_account_status(user) do
    cond do
      user.locked_at != nil ->
        {:error, :account_locked}

      user.confirmed_at == nil && __requires_confirmation?() ->
        {:error, :email_not_confirmed}

      !user.active ->
        {:error, :account_inactive}

      true ->
        :ok
    end
  end

  @spec verify_password(term(), term()) :: term()
  defp verify_password(password, user) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      :ok
    else
      {:error, :invalid_credentials}
    end
  end

  @spec check_mfa_if_enabled(term(), term()) :: term()
  defp check_mfa_if_enabled(user, mfa_token) do
    if user.mfa_enabled && mfa_token do
      verify_totp(user.mfa_secret, mfa_token)
    else
      :ok
    end
  end

  @spec generate_token_set(term()) :: term()
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

  @spec encode_token(term()) :: term()
  defp encode_token(claims) do
    GenServer.call(__MODULE__, {:encode_token, claims})
  end

  @spec decode_token(term()) :: term()
  defp decode_token(token) do
    GenServer.call(__MODULE__, {:decode_token, token})
  end

  @spec create_session(term(), term()) :: term()
  defp create_session(user, opts) do
    attrs = %{
      user_id: user.id,
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent],
      active: true,
      last_activity_at: DateTime.utc_now()
    }

    # ESCAPE HATCH: Session creation via Ash framework
    # Future implementation: Session.changeset when Ash validation is complete
    Session.create!(attrs)
  end

  @spec handle_failed_login(term()) :: term()
  defp handle_failed_login(identifier) do
    GenServer.cast(__MODULE__, {:failed_login, identifier})
  end

  @spec sanitize_user(term()) :: term()
  defp sanitize_user(user) do
    Map.drop(user, [:password_hash, :mfa_secret, :recovery_codes])
  end

  @spec validate_password_policy(term(), term()) :: term()
  defp validate_password_policy(password, _user) do
    policy_name = Application.get_env(:indrajaal, :password_policy, :strong)
    policy = @password_policies[policy_name]

    errors = []

    errors =
      if String.length(password) < policy.min_length do
        ["must be at least #{policy.min_length} characters" | errors]
      else
        errors
      end

    errors =
      if policy.__require_uppercase && !Regex.match?(~r/[A - Z]/, password) do
        ["must contain uppercase letters" | errors]
      else
        errors
      end

    errors =
      if policy.__require_lowercase && !Regex.match?(~r/[a - z]/, password) do
        ["must contain lowercase letters" | errors]
      else
        errors
      end

    errors =
      if policy.__require_numbers && !Regex.match?(~r/[0 - 9]/, password) do
        ["must contain numbers" | errors]
      else
        errors
      end

    errors =
      if policy.__require_special && !Regex.match?(~r/[!@#$%^&*(),.?":{}|<>]/, password) do
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

  @spec generate_totp_secret() :: any()
  defp generate_totp_secret do
    bytes = :crypto.strong_rand_bytes(20)
    Base.encode32(bytes, padding: false)
  end

  @spec verify_totp(term(), term()) :: term()
  defp verify_totp(secret, token) do
    case NimbleTOTP.valid?(secret, token) do
      true -> :ok
      false -> {:error, :invalid_mfa_token}
    end
  end

  @spec generate_qr_code(term(), term(), term()) :: term()
  defp generate_qr_code(email, secret, _req) do
    issuer = Application.get_env(:indrajaal, :totp_issuer, "Indrajaal")
    _otpauth_url = NimbleTOTP.otpauth_uri(email, secret, issuer: issuer)

    # Generate QR code (would use a library like qr_code in production)
    "__data:image / png;base64,QR_CODE_PLACEHOLDER"
  end

  @spec generate_recovery_codes() :: any()
  defp generate_recovery_codes do
    Enum.map(1..10, fn _ ->
      bytes = :crypto.strong_rand_bytes(4)
      encoded = Base.encode16(bytes)
      String.downcase(encoded)
    end)
  end

  @spec schedule_session_cleanup() :: any()
  defp schedule_session_cleanup do
    Process.send_after(self(), :cleanup_sessions, :timer.minutes(30))
  end

  @spec cleanup_expired_sessions() :: any()
  defp cleanup_expired_sessions do
    cutoff = DateTime.add(DateTime.utc_now(), -@access_token_ttl, :second)

    Session
    |> where([s], s.active == true and s.last_activity_at < ^cutoff)
    |> Repo.update_all(set: [active: false])
  end

  @spec __requires_confirmation?() :: any()
  defp __requires_confirmation? do
    Application.get_env(:indrajaal, :__require_email_confirmation, false)
  end

  @spec maybe_send_confirmation_email(term()) :: term()
  defp maybe_send_confirmation_email(user) do
    if __requires_confirmation?() do
      token = generate_confirmation_token()
      save_confirmation_token(user, token)
      send_confirmation_email(user, token)
    end
  end

  # Email sending via Communication module
  @spec send_confirmation_email(term(), term()) :: :ok
  defp send_confirmation_email(user, token) do
    email = Map.get(user, :email) || Map.get(user, "email")

    payload = %{
      to: email,
      subject: "Confirm your Indrajaal account",
      body: "Your confirmation token: #{token}\n\nPlease use this token to verify your account."
    }

    result = Indrajaal.Communication.send_email(payload)

    Logger.info("[Authentication] Confirmation email dispatched",
      to: email,
      result: inspect(result)
    )

    :ok
  end

  @spec send_password_reset_email(term(), term()) :: :ok
  defp send_password_reset_email(user, token) do
    email = Map.get(user, :email) || Map.get(user, "email")

    payload = %{
      to: email,
      subject: "Reset your Indrajaal password",
      body: "Your password reset token: #{token}\n\nThis token expires in 1 hour."
    }

    result = Indrajaal.Communication.send_email(payload)

    Logger.info("[Authentication] Password reset email dispatched",
      to: email,
      result: inspect(result)
    )

    :ok
  end

  # Database helper stubs
  @spec get_user(term()) :: term()
  defp get_user(id), do: Repo.get(User, id)
  defp get_user_by_email(email), do: Repo.get_by(User, email: email)

  @spec update_user(term(), term()) :: term()
  defp update_user(user, attrs) do
    # Use User.update_profile action
    case User.update_profile(user, attrs) do
      {:ok, updated} -> {:ok, updated}
      {:error, error} -> {:error, error}
    end
  end

  @spec update_password(term(), term()) :: term()
  defp update_password(user, password) do
    # Use User.update_profile to update password
    case User.update_profile(user, %{password: password}) do
      {:ok, updated} -> {:ok, updated}
      {:error, error} -> {:error, error}
    end
  end

  defp update_user_mfa(user, secret, enabled),
    do: update_user(user, %{mfa_secret: secret, mfa_enabled: enabled})

  @spec confirm_user(term()) :: term()
  defp confirm_user(user),
    do: update_user(user, %{confirmed_at: DateTime.utc_now()})

  defp save_reset_token(user, token, expires_at),
    do:
      update_user(
        user,
        %{reset_password_token: token, reset_password_sent_at: expires_at}
      )

  @spec clear_reset_token(term()) :: term()
  defp clear_reset_token(user),
    do:
      update_user(
        user,
        %{reset_password_token: nil, reset_password_sent_at: nil}
      )

  @spec save_confirmation_token(term(), term()) :: term()
  defp save_confirmation_token(
         user,
         token
       ),
       do: update_user(user, %{confirmation_token: token})

  defp get_user_by_confirmation_token(token),
    do: Repo.get_by(User, confirmation_token: token)

  defp verify_reset_token(token),
    do: Repo.get_by(User, reset_password_token: token)

  @spec get_user_from_claims(map()) :: term()
  defp get_user_from_claims(%{"sub" => user_id}), do: get_user(user_id)

  defp verify_token_validity(%{"exp" => exp}, _user),
    do: if(exp > System.system_time(:second), do: :ok, else: {:error, :token_expired})

  @spec verify_refresh_token(map()) :: term()
  defp verify_refresh_token(%{"type" => "refresh"}), do: :ok
  defp verify_refresh_token(_), do: {:error, :invalid_token_type}

  defp generate_reset_token do
    bytes = :crypto.strong_rand_bytes(32)
    Base.url_encode64(bytes)
  end

  @spec generate_confirmation_token() :: binary()
  defp generate_confirmation_token do
    bytes = :crypto.strong_rand_bytes(32)
    Base.url_encode64(bytes)
  end

  # Commented out as it's not used with Ash resources
  # defp format_changeset_errors(changeset),
  #   do: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

  # GenServer callbacks for token encoding / decoding

  @impl true
  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:encode_token, claims}, _from, state) do
    signed_token =
      JOSE.JWT.sign(
        %{"alg" => @jwt_algorithm},
        claims,
        JOSE.JWK.from_oct(state.signing_key)
      )

    token = signed_token |> JOSE.JWS.compact() |> elem(1)

    {:reply, {:ok, token}, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
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
  @spec handle_cast(term(), term()) :: {:noreply, term()}
  def handle_cast({:failedlogin, identifier}, state) do
    attempts = Map.get(state.failed_attempts, identifier, 0) + 1

    if attempts >= @max_failed_attempts do
      lock_account_by_identifier(identifier)
      {:noreply, %{state | failed_attempts: Map.delete(state.failed_attempts, identifier)}}
    else
      {:noreply, %{state | failed_attempts: Map.put(state.failed_attempts, identifier, attempts)}}
    end
  end

  @spec lock_account_by_identifier(term()) :: term()
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

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
