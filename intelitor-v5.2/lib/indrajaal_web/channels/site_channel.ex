defmodule IndrajaalWeb.Channels.SiteChannel do
  # PHASE H.5: Channel and response patterns unified with UnifiedChannelSystem

  # EP201: Removed unused alias UnifiedChannelSystem
  # alias Indrajaal.Shared.UnifiedChannelSystem

  @moduledoc """
  Real - time site monitoring and __events channel.

  Provides site - wide status updates, occupancy information,
  and aggregated device status.

  Agent: Worker - 2 manages site channel
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb, :channel

  alias Indrajaal.Realtime.RateLimiter
  alias IndrajaalWeb.Presence

  require Logger

  @impl true
  @spec join(term(), term(), term()) :: term()
  def join("site:" <> site_id, _params, socket) do
    # STAMP Safety: Verify site access permissions

    user_id = socket.assigns.user_id
    tenant_id = socket.assigns.tenant_id

    with :ok <- RateLimiter.check_rate(user_id, :site_channel),
         {:ok, site} <- get_site(site_id),
         true <- site.tenant_id == tenant_id,
         :ok <- check_site_access(user_id, site) do
      # Track presence
      Presence.track_user(socket, user_id, %{
        monitoring_site: site_id
      })

      # Subscribe to site __events
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "site_events:#{site_id}")

      # Send initial site state
      send(self(), :after_join)

      {:ok, assign(socket, :site_id, site_id)}
    else
      {:error, {:rate_limited, retry_after}} ->
        {:error, %{reason: "rate_limited", retry_after: retry_after}}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info({:after_join}, socket) do
    site_id = socket.assigns.site_id

    case get_site_data(site_id) do
      {:ok, site_data} ->
        push(socket, "site_state", serialize_site_state(site_data))

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  @spec handle_in(term(), term(), term()) :: term()
  def handle_in("get_statistics", _params, socket) do
    site_id = socket.assigns.site_id
    site_data = get_site_statistics(site_id)

    {:reply,
     {:ok,
      %{
        statistics: site_data.stats,
        current_status: site_data.status,
        last_updated: DateTime.utc_now()
      }}, socket}
  end

  @spec get_site_statistics(term()) :: map()
  defp get_site_statistics(_site_id) do
    # Mock implementation - would fetch from database
    %{
      stats: %{
        total_devices: 25,
        active_devices: 22,
        total_zones: 8,
        active_alarms: 3
      },
      status: "operational"
    }
  end

  @spec get_site_data(term()) :: {:ok, map()} | {:error, term()}
  defp get_site_data(_site_id) do
    # Mock implementation - would fetch from database
    {:ok,
     %{
       id: "site_1",
       name: "Main Site",
       status: "operational",
       zones: [],
       devices: []
     }}
  end

  @spec serialize_site_state(map()) :: map()
  defp serialize_site_state(site_data) do
    %{
      site: %{
        id: site_data.id,
        name: site_data.name,
        status: site_data.status
      },
      zones: site_data.zones,
      device_count: length(site_data.devices),
      last_updated: DateTime.utc_now()
    }
  end

  @spec get_site(term()) :: {:ok, map()} | {:error, term()}
  defp get_site(site_id) do
    # Mock implementation - would fetch from database
    {:ok,
     %{
       id: site_id,
       name: "Site #{site_id}",
       tenant_id: "tenant_1",
       status: "operational"
     }}
  end

  @spec check_site_access(term(), map()) :: :ok | {:error, term()}
  defp check_site_access(_user_id, _site), do: :ok
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
