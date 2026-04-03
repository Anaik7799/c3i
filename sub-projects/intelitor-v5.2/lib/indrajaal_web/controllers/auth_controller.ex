# {import_line}

defmodule IndrajaalWeb.AuthController do
  @moduledoc """
  Authentication controller for local authentication.
  Handles login, logout, registration, and token refresh.
  """

  use IndrajaalWeb, :controller

  alias Indrajaal.Accounts.Authentication

  action_fallback IndrajaalWeb.FallbackController

  @spec login(any(), any()) :: any()
  def login(conn, %{"email" => email, "password" => password} = params) do
    opts = [
      ip_address: get_ip_address(conn),
      __user_agent: get_user_agent(conn),
      mfa_token: params["mfa_token"]
    ]

    case Authentication.authenticate(email, password, opts) do
      {:ok, %{user: user, tokens: _tokens, __requires_mfa: true}} ->
        conn
        |> put_status(:ok)
        |> json(%{
          __requires_mfa: true,
          user_id: user.id,
          message: "MFA token __required"
        })

      {:ok, %{user: user, tokens: tokens}} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(user),
          tokens: tokens
        })

      {:error, reason} ->
        conn |> put_status(:unauthorized) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec register(any(), any()) :: any()
  def register(conn, params) do
    attrs = %{
      email: params["email"],
      __username: params["__username"],
      password: params["password"],
      first_name: params["first_name"],
      last_name: params["last_name"],
      tenant_id: params["tenant_id"] || get_default_tenant_id()
    }

    case Authentication.register(attrs) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{
          user: serialize_user(user),
          message: "Registration successful. Please check your email for
            confirmation."
        })

      {:error, errors} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})
    end
  end

  @spec refresh(any(), any()) :: any()
  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Authentication.refresh_tokens(refresh_token) do
      {:ok, tokens} ->
        conn |> put_status(:ok) |> json(%{tokens: tokens})

      {:error, reason} ->
        conn |> put_status(:unauthorized) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec logout(any(), any()) :: any()
  def logout(conn, _params) do
    user = conn.assigns[:current_user]

    if user do
      # Revoke all sessions for the user
      Authentication.revoke_all_sessions(user.id)
    end

    conn |> put_status(:ok) |> json(%{message: "Logged out successfully"})
  end

  @spec forgot_password(any(), any()) :: any()
  def forgot_password(conn, %{"email" => email}) do
    case Authentication.__request_password_reset(email) do
      {:ok, _} ->
        conn |> put_status(:ok) |> json(%{message: "If the email exists,
          password reset instructions have been sent"})

      {:error, _} ->
        # Don't reveal whether email exists
        conn |> put_status(:ok) |> json(%{message: "If the email exists,
          password reset instructions have been sent"})
    end
  end

  @spec reset_password(any(), any()) :: any()
  def reset_password(conn, %{"token" => token, "password" => password}) do
    case Authentication.reset_password(token, password) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "Password reset successful",
          user: serialize_user(user)
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec confirm_email(any(), any()) :: any()
  def confirm_email(conn, %{"token" => token}) do
    case Authentication.confirm_email(token) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "Email confirmed successfully",
          user: serialize_user(user)
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec enable_mfa(any(), any()) :: any()
  def enable_mfa(conn, _params) do
    user = conn.assigns[:current_user]

    case Authentication.enable_mfa(user.id) do
      {:ok, mfa_data} ->
        conn
        |> put_status(:ok)
        |> json(%{
          secret: mfa_data.secret,
          qr_code: mfa_data.qr_code,
          recovery_codes: mfa_data.recovery_codes,
          message: "Scan the QR code with your authenticator app"
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec disable_mfa(any(), any()) :: any()
  def disable_mfa(conn, %{"password" => password}) do
    user = conn.assigns[:current_user]

    case Authentication.disable_mfa(user.id, password) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "MFA disabled successfully",
          user: serialize_user(user)
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec change_password(any(), any()) :: any()
  def change_password(
        conn,
        %{"current_password" => current, "new_password" => new}
      ) do
    user = conn.assigns[:current_user]

    case Authentication.change_password(user.id, current, new) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "Password changed successfully",
          user: serialize_user(user)
        })

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_auth_error(reason)})
    end
  end

  @spec sessions(any(), any()) :: any()
  def sessions(conn, _params) do
    user = conn.assigns[:current_user]
    sessions = Authentication.get_user_sessions(user.id)

    conn
    |> put_status(:ok)
    |> json(%{
      sessions: Enum.map(sessions, &serialize_session/1)
    })
  end

  @spec revoke_session(any(), any()) :: any()
  def revoke_session(conn, %{"id" => session_id}) do
    user = conn.assigns[:current_user]

    :ok = Authentication.revoke_session(session_id, user.id)

    conn |> put_status(:ok) |> json(%{message: "Session revoked successfully"})
  end

  # Private functions

  @spec serialize_user(term()) :: term()
  defp serialize_user(user) do
    %{
      id: user.id,
      email: user.email,
      __username: user.__username,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      tenant_id: user.tenant_id,
      mfa_enabled: user.mfa_enabled,
      confirmed_at: user.confirmed_at,
      created_at: user.created_at
    }
  end

  @spec serialize_session(term()) :: term()
  defp serialize_session(session) do
    %{
      id: session.id,
      ip_address: session.ip_address,
      __user_agent: session.__user_agent,
      last_activity_at: session.last_activity_at,
      created_at: session.created_at,
      is_current: session.is_current
    }
  end

  @spec format_auth_error(term()) :: term()
  defp format_auth_error(:invalid_credentials), do: "Invalid email or password"

  defp format_auth_error(:account_locked),
    do: "Account is locked due to multiple failed attempts"

  defp format_auth_error(:email_not_confirmed),
    do: "Please confirm your email address"

  defp format_auth_error(:account_inactive), do: "Account is inactive"
  defp format_auth_error(:token_expired), do: "Token has expired"
  defp format_auth_error(:invalid_token), do: "Invalid token"

  defp format_auth_error(:mfa_not_enabled),
    do: "MFA is not enabled for this account"

  defp format_auth_error(:invalid_mfa_token), do: "Invalid MFA token"

  defp format_auth_error({:password_policy, errors}),
    do: "Password __requirements: #{Enum.join(errors, ", ")}"

  defp format_auth_error(_), do: "Authentication failed"

  defp get_ip_address(conn) do
    forwarded_for = get_req_header(conn, "x-forwarded-for")

    case forwarded_for do
      [ips | _] ->
        ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  @spec get_user_agent(term()) :: term()
  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      [] -> "Unknown"
    end
  end

  @spec get_default_tenant_id() :: any()
  defp get_default_tenant_id do
    # In production, this would query the default tenant
    # For now, return a placeholder
    Ecto.UUID.generate()
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
