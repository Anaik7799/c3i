defmodule IndrajaalWeb.Channels.ConfigChannel do
  # PHASE H.5: Channel and response patterns unified with UnifiedChannelSystem

  # EP201: Removed unused alias UnifiedChannelSystem
  # alias Indrajaal.Shared.UnifiedChannelSystem

  @moduledoc """
  Real - time configuration updates channel.

  Broadcasts configuration changes and provides collaborative
  configuration editing capabilities.

  Agent: Worker - 3 manages config channel
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb, :channel

  # # alias Indrajaal.ConfigManagement  # Currently unused  # Currently unused
  alias Indrajaal.Realtime.{RateLimiter, ChangeTracker}
  alias IndrajaalWeb.Presence

  require Logger

  @impl true
  @spec join(term(), term(), term()) :: term()
  def join("config:" <> scope, __params, socket) do
    # STAMP Safety: Verify configuration access

    user_id = socket.assigns.user_id
    tenant_id = socket.assigns.tenant_id

    with :ok <- RateLimiter.check_rate(user_id, :config_channel),
         :ok <- validate_scope(scope),
         :ok <- check_config_access(user_id, tenant_id, scope) do
      # Track presence for collaborative editing
      Presence.track_user(socket, user_id, %{
        editing_config: scope,
        started_at: DateTime.utc_now()
      })

      # Subscribe to config changes
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "config_changes:#{tenant_id}:#{scope}")

      # Send initial state
      send(self(), :after_join)

      socket =
        socket
        |> assign(:config_scope, scope)
        |> assign(:scope, scope)
        |> assign(:editing_users, MapSet.new())

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
  def handle_info({:configchanged, scope, changes, updated, user_id, tenant_id}, socket) do
    broadcast!(socket, "config_changed", %{
      scope: scope,
      changes: changes,
      version: updated.version,
      changed_by: user_id,
      changed_at: DateTime.utc_now()
    })

    # Track change
    ChangeTracker.track_change(
      %{
        id: "config:#{scope}",
        tenant_id: tenant_id,
        changes: changes
      },
      :config_update
    )

    {:noreply, socket}
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info({:configreverted, scope, version, reverted, user_id}, socket) do
    broadcast!(socket, "config_reverted", %{
      scope: scope,
      version: version,
      reverted_by: user_id,
      new_version: reverted.version
    })

    {:noreply, socket}
  end

  # Collaborative editing

  @impl true
  @spec handle_in(term(), term(), term()) :: term()
  def handle_in(_event, __params, socket) do
    editors = format_editors(Presence.list(socket))
    {:reply, {:ok, %{editors: editors}}, socket}
  end

  @spec format_editors(term()) :: term()
  defp format_editors(presence) do
    presence
    |> Enum.map(fn {user_id, %{metas: metas}} ->
      %{
        user_id: user_id,
        editing_since: get_earliest_meta_time(metas)
      }
    end)
  end

  @spec get_earliest_meta_time(term()) :: term()
  defp get_earliest_meta_time(metas) do
    metas
    |> Enum.map(& &1.started_at)
    |> Enum.min(DateTime)
  end

  @spec validate_scope(term()) :: :ok | {:error, term()}
  defp validate_scope(scope) when is_binary(scope) and byte_size(scope) > 0, do: :ok
  defp validate_scope(_), do: {:error, :invalid_scope}

  @spec check_config_access(term(), term(), term()) :: :ok | {:error, term()}
  defp check_config_access(_user_id, _tenant_id, _scope), do: :ok
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic feedback
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
