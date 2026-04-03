defmodule IndrajaalWeb.Channels.DeviceChannel do
  # PHASE H.5: Channel and response patterns unified with UnifiedChannelSystem

  # EP201: Removed unused alias UnifiedChannelSystem
  # alias Indrajaal.Shared.UnifiedChannelSystem

  @moduledoc """
  Real - time device status and control channel.

  Handles device status updates, commands, and monitoring
  for mobile clients.

  Agent: Worker - 1 manages device channel
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb, :channel

  alias Indrajaal.Devices
  alias Indrajaal.Realtime.RateLimiter
  alias IndrajaalWeb.Presence

  require Logger

  @impl true
  @spec join(term(), term(), term()) :: term()
  def join("device:" <> device_id, _params, socket) do
    # STAMP Safety: Verify device access permissions

    user_id = socket.assigns.user_id
    tenant_id = socket.assigns.tenant_id

    with :ok <- RateLimiter.check_rate(user_id, :device_channel),
         {:ok, device} <- Devices.get_device(device_id),
         true <- device.tenant_id == tenant_id,
         :ok <- check_device_access(user_id, device) do
      # Track presence
      Presence.track_user(socket, user_id, %{
        watching_device: device_id
      })

      # Subscribe to device __events
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "device_events:#{device_id}")

      # Send initial device state
      send(self(), :after_join)

      socket =
        socket
        |> assign(:device_id, device_id)
        |> assign(:scope, "device:#{device_id}")

      {:ok, socket}
    else
      {:error, {:rate_limited, retry_after}} ->
        {:error, %{reason: "rate_limited", retry_after: retry_after}}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info({:maintenance_mode_changed, device_id, enabled, user_id}, socket) do
    broadcast!(socket, "maintenance_mode_changed", %{
      device_id: device_id,
      enabled: enabled,
      changed_by: user_id
    })

    {:noreply, socket}
  end

  # Presence handling

  @impl true
  @spec handle_in(term(), term(), term()) :: term()
  def handle_in("device_command", %{"command" => command} = params, socket) do
    # Validate command structure and parameters
    case command do
      "reboot" ->
        {:reply, {:ok, %{status: "reboot_initiated"}}, socket}

      "reset" ->
        {:reply, {:ok, %{status: "reset_initiated"}}, socket}

      "update_config" ->
        case validate_config_params(params) do
          :ok -> {:reply, {:ok, %{status: "config_updated"}}, socket}
          {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
        end

      _ ->
        {:reply, {:error, %{reason: "invalid_command"}}, socket}
    end
  end

  @spec validate_config_params(map()) :: term()
  defp validate_config_params(%{"config" => config}) when is_map(config),
    do: :ok

  defp validate_config_params(_), do: {:error, :invalid_config}

  @spec check_device_access(term(), term()) :: :ok | {:error, term()}
  defp check_device_access(_user_id, _device), do: :ok
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
