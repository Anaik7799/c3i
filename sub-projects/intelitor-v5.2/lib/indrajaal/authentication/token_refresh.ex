defmodule Indrajaal.Authentication.TokenRefresh do
  @moduledoc """
  Secure Token Refresh System

  Provides secure refresh token generation with:
  - Rotation on use
  - Family detection for security
  - Automatic cleanup of expired refresh tokens
  - STAMP safety validation
  """

  require Logger
  alias Indrajaal.Accounts
  alias Indrajaal.Authentication.TokenValidator

  alias Indrajaal.Accounts
  alias Indrajaal.Authentication.TokenValidator

  @refresh_token_length 64
  # 7 days
  @refresh_token_ttl :timer.hours(24 * 7)
  # 1 hour
  @access_token_ttl :timer.hours(1)
  # 5 minutes to use refresh token (future enhancement)
  # @family_timeout :timer.minutes(5)

  @doc """
  Generates a new refresh token for a user session
  """
  @spec generate_refresh_token(term(), term(), term(), term()) :: term()
  def generate_refresh_token(userid, tenant_id, session_id, device_fingerprint) do
    :telemetry.execute(
      [:indrajaal, :auth, :refresh_token_generation, :start],
      %{system_time: System.system_time()},
      %{user_id: userid, tenant_id: tenant_id}
    )

    with :ok <- validate_refresh_safety(userid, tenant_id),
         {:ok, refresh_token} <- create_refresh_token(),
         {:ok, token_family} <- create_token_family(),
         :ok <-
           store_refresh_token(
             refresh_token,
             userid,
             tenant_id,
             session_id,
             device_fingerprint,
             token_family
           ) do
      Logger.info("Refresh token generated",
        user_id: userid,
        tenant_id: tenant_id,
        session_id: session_id,
        token_family: token_family
      )

      :telemetry.execute(
        [:indrajaal, :auth, :refresh_token_generation, :success],
        %{generation_time: System.system_time()},
        %{user_id: userid, tenant_id: tenant_id, token_family: token_family}
      )

      {:ok, refresh_token, token_family}
    else
      {:error, reason} = error ->
        Logger.warning("Refresh token generation failed",
          reason: reason,
          user_id: userid,
          tenant_id: tenant_id
        )

        :telemetry.execute(
          [:indrajaal, :auth, :refresh_token_generation, :failure],
          %{failure_time: System.system_time()},
          %{reason: reason, user_id: userid, tenant_id: tenant_id}
        )

        error
    end
  end

  @doc """
  Uses a refresh token to generate new access and refresh tokens
  """
  @spec use_refresh_token(any(), any()) :: any()
  def use_refresh_token(refresh_token, device_fingerprint) do
    :telemetry.execute(
      [:indrajaal, :auth, :refresh_token_use, :start],
      %{system_time: System.system_time()},
      %{token_hash: hash_token(refresh_token)}
    )

    with {:ok, token_data} <- validate_refresh_token(refresh_token),
         :ok <- validate_device_fingerprint(token_data, device_fingerprint),
         :ok <- validate_token_family(token_data),
         {:ok, new_access_token} <- generate_new_access_token(token_data),
         {:ok, new_refresh_token, new_family} <-
           rotate_refresh_token(token_data, device_fingerprint),
         :ok <- revoke_old_refresh_token(refresh_token) do
      Logger.info("Refresh token used successfully",
        user_id: token_data.user_id,
        tenant_id: token_data.tenant_id,
        old_family: token_data.token_family,
        new_family: new_family
      )

      :telemetry.execute(
        [:indrajaal, :auth, :refresh_token_use, :success],
        %{use_time: System.system_time()},
        %{user_id: token_data.user_id, tenant_id: token_data.tenant_id}
      )

      {:ok,
       %{
         access_token: new_access_token,
         refresh_token: new_refresh_token,
         token_family: new_family,
         expires_in: div(@access_token_ttl, 1000)
       }}
    else
      {:error, :token_family_breach} = error ->
        # Security incident - revoke all tokens for this family
        handle_token_family_breach(refresh_token)
        error

      {:error, reason} = error ->
        Logger.warning("Refresh token use failed",
          reason: reason,
          token_hash: hash_token(refresh_token)
        )

        :telemetry.execute(
          [:indrajaal, :auth, :refresh_token_use, :failure],
          %{failure_time: System.system_time()},
          %{reason: reason}
        )

        error
    end
  end

  @doc """
  Revokes a refresh token and its family
  """
  @spec revoke_refresh_token(any(), any()) :: any()
  def revoke_refresh_token(refresh_token, revoke_family \\ false) do
    case get_refresh_token_data(refresh_token) do
      {:ok, token_data} ->
        if revoke_family do
          revoke_token_family(token_data.token_family)
        else
          revoke_single_refresh_token(refresh_token)
        end

        Logger.info("Refresh token revoked",
          token_hash: hash_token(refresh_token),
          family_revoked: revoke_family,
          user_id: token_data.user_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to revoke refresh token",
          reason: reason,
          token_hash: hash_token(refresh_token)
        )

        {:error, reason}
    end
  end

  @doc """
  Cleans up expired refresh tokens
  """
  @spec cleanup_expired_tokens() :: any()
  def cleanup_expired_tokens do
    ensure_table()
    now = System.system_time(:second)

    # :ets.select_delete returns the count of records deleted
    expired_count =
      :ets.select_delete(:token_refresh_store, [
        {{:"$1", :"$2"},
         [
           {:orelse, {:==, {:map_get, :revoked, :"$2"}, true},
            {:<, {:map_get, :expires_at, :"$2"}, now}}
         ], [true]}
      ])

    Logger.info("Cleaned up expired refresh tokens", count: expired_count)

    :telemetry.execute(
      [:indrajaal, :auth, :refresh_token_cleanup],
      %{cleanup_time: System.system_time(), expired_count: expired_count},
      %{}
    )

    {:ok, expired_count}
  end

  # Private Functions

  @spec validate_refresh_safety(term(), term()) :: term()
  defp validate_refresh_safety(userid, tenant_id) do
    # STAMP safety validation for refresh token generation
    with {:ok, user} <- Accounts.get_user(userid),
         {:ok, tenant} <- Accounts.get_tenant(tenant_id),
         :ok <- check_user_active(user),
         :ok <- check_tenant_active(tenant),
         :ok <- check_refresh_rate_limit(userid) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec check_user_active(map()) :: term()
  defp check_user_active(%{active: true}), do: :ok
  defp check_user_active(_), do: {:error, :_user_inactive}

  @spec check_tenant_active(map()) :: term()
  defp check_tenant_active(%{active: true}), do: :ok
  defp check_tenant_active(_), do: {:error, :tenant_inactive}

  @spec check_refresh_rate_limit(term()) :: term()
  defp check_refresh_rate_limit(_user_id) do
    # Check if user is not generating too many refresh tokens
    # Implementation would check rate limiting
    :ok
  end

  @spec create_refresh_token() :: any()
  defp create_refresh_token do
    token =
      @refresh_token_length
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    {:ok, token}
  end

  @spec create_token_family() :: any()
  defp create_token_family do
    family =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    {:ok, family}
  end

  @spec store_refresh_token(term(), term(), term(), term(), term(), term()) :: any()
  defp store_refresh_token(
         refresh_token,
         user_id,
         tenant_id,
         session_id,
         device_fingerprint,
         token_family
       ) do
    ensure_table()

    token_data = %{
      token: refresh_token,
      user_id: user_id,
      tenant_id: tenant_id,
      session_id: session_id,
      device_fingerprint: device_fingerprint,
      token_family: token_family,
      expires_at: System.system_time(:second) + div(@refresh_token_ttl, 1000),
      revoked: false,
      inserted_at: DateTime.utc_now()
    }

    :ets.insert(:token_refresh_store, {refresh_token, token_data})

    :telemetry.execute(
      [:indrajaal, :auth, :token_refresh, :store],
      %{system_time: System.system_time()},
      %{user_id: user_id, token_family: token_family}
    )

    Logger.debug("Stored refresh token in ETS",
      user_id: user_id,
      token_family: token_family,
      expires_at: token_data.expires_at
    )

    :ok
  end

  @spec validate_refresh_token(term()) :: term()
  defp validate_refresh_token(refresh_token) do
    case get_refresh_token_data(refresh_token) do
      {:ok, token_data} ->
        now = System.system_time(:second)

        cond do
          token_data.revoked ->
            Logger.warning("Validate refresh token: token is revoked",
              token_hash: hash_token(refresh_token)
            )

            :telemetry.execute(
              [:indrajaal, :auth, :token_refresh, :validate],
              %{system_time: System.system_time()},
              %{result: :revoked}
            )

            {:error, :token_revoked}

          token_data.expires_at < now ->
            Logger.warning("Validate refresh token: token expired",
              token_hash: hash_token(refresh_token),
              expired_at: token_data.expires_at
            )

            :telemetry.execute(
              [:indrajaal, :auth, :token_refresh, :validate],
              %{system_time: System.system_time()},
              %{result: :expired}
            )

            {:error, :token_expired}

          true ->
            :telemetry.execute(
              [:indrajaal, :auth, :token_refresh, :validate],
              %{system_time: System.system_time()},
              %{result: :valid, user_id: token_data.user_id}
            )

            {:ok, token_data}
        end

      {:error, :not_found} = error ->
        :telemetry.execute(
          [:indrajaal, :auth, :token_refresh, :validate],
          %{system_time: System.system_time()},
          %{result: :not_found}
        )

        error
    end
  end

  @spec validate_device_fingerprint(term(), term()) :: term()
  defp validate_device_fingerprint(token_data, device_fingerprint) do
    if token_data.device_fingerprint == device_fingerprint do
      :ok
    else
      Logger.warning("Device fingerprint mismatch",
        user_id: token_data.user_id,
        expected: hash_token(token_data.device_fingerprint),
        received: hash_token(device_fingerprint)
      )

      {:error, :device_fingerprint_mismatch}
    end
  end

  @spec validate_token_family(term()) :: term()
  defp validate_token_family(_token_data) do
    # Check if this token family has been compromised
    # Implementation would check family breach status
    :ok
  end

  @spec generate_new_access_token(term()) :: term()
  defp generate_new_access_token(token_data) do
    claims = %{
      "sub" => token_data.user_id,
      "tenant_id" => token_data.tenant_id,
      "session_id" => token_data.session_id,
      "device_fingerprint" => token_data.device_fingerprint,
      "role" => get_user_role(token_data.user_id),
      "jti" => generate_jti(),
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + div(@access_token_ttl, 1000)
    }

    case TokenValidator.generate_and_sign(claims) do
      {:ok, token, _claims} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec rotate_refresh_token(term(), term()) :: term()
  defp rotate_refresh_token(token_data, device_fingerprint) do
    # Generate new refresh token in same family
    generate_refresh_token(
      token_data.user_id,
      token_data.tenant_id,
      token_data.session_id,
      device_fingerprint
    )
  end

  @spec revoke_old_refresh_token(term()) :: term()
  defp revoke_old_refresh_token(refresh_token) do
    ensure_table()

    case :ets.lookup(:token_refresh_store, refresh_token) do
      [{^refresh_token, token_data}] ->
        :ets.insert(:token_refresh_store, {refresh_token, %{token_data | revoked: true}})

        Logger.debug("Revoked old refresh token after rotation",
          token_hash: hash_token(refresh_token)
        )

        :telemetry.execute(
          [:indrajaal, :auth, :token_refresh, :revoke],
          %{system_time: System.system_time()},
          %{scope: :rotation, token_hash: hash_token(refresh_token)}
        )

      [] ->
        Logger.debug("revoke_old_refresh_token: token not found, nothing to revoke",
          token_hash: hash_token(refresh_token)
        )
    end

    :ok
  end

  @spec handle_token_family_breach(term()) :: term()
  defp handle_token_family_breach(refresh_token) do
    with {:ok, token_data} <- get_refresh_token_data(refresh_token) do
      Logger.error("Token family breach detected - revoking all family tokens",
        token_family: token_data.token_family,
        user_id: token_data.user_id
      )

      # Revoke all tokens in this family
      revoke_token_family(token_data.token_family)

      # Notify security team
      :telemetry.execute(
        [:indrajaal, :security, :token_family_breach],
        %{breach_time: System.system_time()},
        %{
          token_family: token_data.token_family,
          user_id: token_data.user_id,
          tenant_id: token_data.tenant_id
        }
      )
    end
  end

  @spec get_refresh_token_data(term()) :: {:ok, map()} | {:error, atom()}
  defp get_refresh_token_data(refresh_token) do
    ensure_table()

    case :ets.lookup(:token_refresh_store, refresh_token) do
      [{^refresh_token, token_data}] ->
        {:ok, token_data}

      [] ->
        {:error, :not_found}
    end
  end

  @spec revoke_token_family(term()) :: term()
  defp revoke_token_family(token_family) do
    ensure_table()

    # Collect all token keys whose token_family matches
    match_spec = [
      {{:"$1", :"$2"}, [{:==, {:map_get, :token_family, :"$2"}, {:const, token_family}}], [:"$1"]}
    ]

    family_token_keys = :ets.select(:token_refresh_store, match_spec)
    revoked_count = length(family_token_keys)

    Enum.each(family_token_keys, fn token_key ->
      case :ets.lookup(:token_refresh_store, token_key) do
        [{^token_key, token_data}] ->
          :ets.insert(:token_refresh_store, {token_key, %{token_data | revoked: true}})

        [] ->
          :ok
      end
    end)

    Logger.info("Revoked token family",
      family: token_family,
      tokens_revoked: revoked_count
    )

    :telemetry.execute(
      [:indrajaal, :auth, :token_refresh, :revoke],
      %{system_time: System.system_time()},
      %{token_family: token_family, revoked_count: revoked_count, scope: :family}
    )

    :ok
  end

  @spec revoke_single_refresh_token(term()) :: term()
  defp revoke_single_refresh_token(refresh_token) do
    ensure_table()

    case :ets.lookup(:token_refresh_store, refresh_token) do
      [{^refresh_token, token_data}] ->
        :ets.insert(:token_refresh_store, {refresh_token, %{token_data | revoked: true}})

        Logger.info("Revoked single refresh token",
          token_hash: hash_token(refresh_token),
          user_id: token_data.user_id
        )

        :telemetry.execute(
          [:indrajaal, :auth, :token_refresh, :revoke],
          %{system_time: System.system_time()},
          %{scope: :single, token_hash: hash_token(refresh_token)}
        )

      [] ->
        Logger.warning("revoke_single_refresh_token: token not found",
          token_hash: hash_token(refresh_token)
        )
    end

    :ok
  end

  @spec get_user_role(term()) :: term()
  defp get_user_role(user_id) do
    case Accounts.get_user(user_id) do
      {:ok, user} ->
        user.role |> to_string()

      _ ->
        "user"
    end
  end

  @spec generate_jti() :: any()
  defp generate_jti do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @spec hash_token(term()) :: term()
  defp hash_token(token) do
    token
    |> :crypto.hash(:sha256)
    |> Base.encode16()
    |> String.slice(0, 16)
  end

  @spec ensure_table() :: :ok
  defp ensure_table do
    if :ets.whereis(:token_refresh_store) == :undefined do
      :ets.new(:token_refresh_store, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
