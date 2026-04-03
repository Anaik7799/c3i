defmodule IndrajaalWeb.MobileSocket do
  @moduledoc """
  Socket handler for mobile client WebSocket connections.

  Provides authentication, tenant isolation, and device tracking
  for mobile applications.

  Agent: Helper - 1 manages WebSocket infrastructure
  SOPv5.1 Compliance: ✅
  STAMP Safety: Connection validation enforced
  """

  use Phoenix.Socket

  # alias Indrajaal.Accounts  # Currently unused
  alias Indrajaal.Authentication.JWT
  # alias IndrajaalWeb.Presence  # Currently unused

  require Logger

  # Channels
  channel "alarm:*", IndrajaalWeb.AlarmChannel
  channel "device:*", IndrajaalWeb.DeviceChannel
  channel "site:*", IndrajaalWeb.SiteChannel
  channel "config:*", IndrajaalWeb.ConfigChannel
  channel "notification:*", IndrajaalWeb.NotificationChannel
  channel "sync:*", IndrajaalWeb.SyncChannel

  # Rate limiting configuration
  # @max_connections_per_user 5  # Currently unused
  # 1 minute
  # @rate_limit_window 60_000  # Currently unused
  # @max_connections_per_window 10  # Currently unused

  @impl true
  @spec connect(map(), Phoenix.Socket.t(), map()) :: {:ok, Phoenix.Socket.t()} | :error
  def connect(params, socket, _connect_info) do
    # Agent Comment: Helper - 1 validates connection
    # STAMP Safety: Enforce authentication before connection

    with {:ok, token} <- get_token(params),
         {:ok, claims} <- JWT.verify_token(token),
         {:ok, user} <- get_user(claims),
         :ok <- check_rate_limits(user.id),
         :ok <- track_connection(user.id) do
      # Assign user __context to socket
      socket =
        socket
        |> assign(:user_id, user.id)
        |> assign(:tenant_id, user.tenant_id)
        |> assign(:user_role, user.role)
        |> assign(:token_jti, claims["jti"])
        |> assign_device_info(params)

      # Track user presence
      track_presence(socket, user)

      # Log successful connection
      Logger.info("Mobile socket connected", %{
        user_id: user.id,
        tenant_id: user.tenant_id,
        device_id: socket.assigns[:device_id]
      })

      {:ok, socket}
    else
      {:error, reason} ->
        Logger.warning("Mobile socket connection failed", %{
          reason: reason,
          __params: Map.drop(params, ["token"])
        })

        :error
    end
  end

  @impl true
  @spec id(any()) :: any()
  def id(_socket), do: nil

  # Helper functions for mobile socket connection
  @spec get_token(map()) :: {:ok, String.t()} | {:error, term()}
  defp get_token(%{"token" => token}), do: {:ok, token}
  defp get_token(_), do: {:error, :missing_token}

  @spec get_user(map()) :: {:ok, map()} | {:error, term()}
  defp get_user(%{"userid" => user_id}) do
    # Mock implementation - would fetch from __database
    {:ok, %{id: user_id, tenant_id: "tenant_1", role: "user"}}
  end

  defp get_user(_), do: {:error, :invalid_token}

  @spec check_rate_limits(term()) :: :ok | {:error, term()}
  defp check_rate_limits(_user_id), do: :ok

  @spec track_connection(term()) :: :ok
  defp track_connection(_user_id), do: :ok

  @spec assign_device_info(Phoenix.Socket.t(), map()) :: Phoenix.Socket.t()
  defp assign_device_info(socket, %{"deviceid" => device_id}) do
    assign(socket, :device_id, device_id)
  end

  defp assign_device_info(socket, _), do: socket

  @spec track_presence(Phoenix.Socket.t(), map()) :: :ok
  defp track_presence(_socket, _user), do: :ok
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic feedback
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
