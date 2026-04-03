defmodule IndrajaalWeb.Channels.NotificationChannel do
  # PHASE H.5: Channel and response patterns unified with UnifiedChannelSystem

  # EP201: Removed unused alias UnifiedChannelSystem
  # alias Indrajaal.Shared.UnifiedChannelSystem

  @moduledoc """
  Real - time notification delivery channel.

  Handles in - app notifications, acknowledgments, and
  notification preference updates.

  Agent: Worker - 4 manages notification channel
  SOPv5.1 Compliance: ✅
  """

  use IndrajaalWeb, :channel

  # alias Indrajaal.Notifications.{Push, Preferences, History}  # EP004: Unused aliases converted to comment
  alias Indrajaal.Realtime.{RateLimiter, OfflineQueue}
  alias IndrajaalWeb.Presence

  require Logger

  @impl true
  @spec join(term(), term(), term()) :: term()
  def join("notification:" <> user_id, _params, socket) do
    # STAMP Safety: Verify user identity match

    socket_user_id = socket.assigns.user_id

    # Ensure user can only join their own notification channel
    if socket_user_id == user_id do
      with :ok <- RateLimiter.check_rate(user_id, :notification_channel) do
        # Track presence
        Presence.track_user(socket, user_id, %{
          notification_channel: true,
          joined_at: DateTime.utc_now()
        })

        # Subscribe to user notifications
        Phoenix.PubSub.subscribe(Indrajaal.PubSub, "notifications:#{user_id}")

        # Send initial state
        send(self(), :after_join)

        # Check for offline messages
        OfflineQueue.deliver_to_user(user_id, self())

        {:ok, socket}
      else
        {:error, {:rate_limited, retry_after}} ->
          {:error, %{reason: "rate_limited", retry_after: retry_after}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info({:after_join}, socket) do
    user_id = socket.assigns.user_id

    # Send initial notification state
    unread_count = get_unread_count(user_id)
    push(socket, "unread_count", %{count: unread_count})

    {:noreply, socket}
  end

  def handle_info({:notification, notification}, socket) do
    push(socket, "notification", serialize_notification(notification))
    {:noreply, socket}
  end

  @impl true
  @spec handle_in(term(), term(), term()) :: term()
  def handle_in("mark_read", %{"notification_id" => notification_id}, socket) do
    user_id = socket.assigns.user_id

    case mark_notification_read(user_id, notification_id) do
      {:ok, _} ->
        unread_count = get_unread_count(user_id)
        broadcast!(socket, "unread_count", %{count: unread_count})
        {:reply, :ok, socket}

        # Note: mark_notification_read currently always returns {:ok, _}
        # {:error, _reason} ->  # Unreachable - commented out
        #   {:reply, {:error, %{reason: "failed_to_mark_read"}}, socket}
    end
  end

  def handle_in("mark_all_read", _params, socket) do
    user_id = socket.assigns.user_id

    case mark_all_notifications_read(user_id) do
      {:ok, marked_count} ->
        broadcast!(socket, "unread_count", %{count: 0})
        {:reply, {:ok, %{marked: marked_count}}, socket}

        # Note: mark_all_notifications_read currently always returns {:ok, _}
        # {:error, _reason} ->  # Unreachable - commented out
        #   {:reply, {:error, %{reason: "failed_to_mark_all_read"}}, socket}
    end
  end

  def handle_in("update_preferences", %{"preferences" => preferences}, socket) do
    user_id = socket.assigns.user_id

    case update_notification_preferences(user_id, preferences) do
      {:ok, updated} ->
        broadcast!(socket, "preferences_updated", serialize_preferences(updated))
        {:reply, {:ok, serialize_preferences(updated)}, socket}

        # Note: update_notification_preferences currently always returns {:ok, _}
        # {:error, changeset} ->  # Unreachable - commented out
        #   {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  # @spec format_errors(term()) :: term()  # EP004: Unused function converted to comment
  # defp format_errors(changeset) do
  #   Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
  #     Enum.reduce(opts, msg, fn {key, value}, acc ->
  #       String.replace(acc, "%{#{key}}", to_string(value))
  #     end)
  #   end)
  # end

  # Helper functions for notification operations
  @spec get_unread_count(term()) :: non_neg_integer()
  defp get_unread_count(_user_id) do
    # Mock implementation - would count unread notifications
    0
  end

  @spec mark_notification_read(term(), term()) :: {:ok, term()} | {:error, term()}
  defp mark_notification_read(_user_id, _notification_id) do
    # Mock implementation - would mark notification as read
    {:ok, %{id: "notification_id", read: true}}
  end

  @spec mark_all_notifications_read(term()) :: {:ok, non_neg_integer()} | {:error, term()}
  defp mark_all_notifications_read(_user_id) do
    # Mock implementation - would mark all notifications as read
    {:ok, 5}
  end

  @spec update_notification_preferences(term(), term()) :: {:ok, term()} | {:error, term()}
  defp update_notification_preferences(_user_id, preferences) do
    # Mock implementation - would update notification preferences
    {:ok, preferences}
  end

  @spec serialize_notification(term()) :: map()
  defp serialize_notification(notification) do
    %{
      id: notification.id || "notification_id",
      title: notification.title || "Notification",
      message: notification.message || "Message",
      type: notification.type || "info",
      created_at: notification.created_at || DateTime.utc_now()
    }
  end

  @spec serialize_preferences(term()) :: map()
  defp serialize_preferences(preferences) do
    %{
      email_enabled: preferences[:email_enabled] || true,
      push_enabled: preferences[:push_enabled] || true,
      sms_enabled: preferences[:sms_enabled] || false
    }
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
