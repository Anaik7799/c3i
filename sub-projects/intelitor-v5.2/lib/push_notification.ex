defmodule PushNotification do
  @moduledoc """
  Push Notification stub.

  This module provides push notification management functionality.
  Created as a stub to resolve UNDEFINED_MODULE warnings during Phase 1.

  Functions to be implemented in Phase 2:
  - send_notification/1
  - send_notification/2
  - schedule_notification/2
  - cancel_notification/1
  """

  @doc """
  Send a push notification.

  ## Parameters
  - notification: The notification to send

  ## Returns
  - {:ok, notification_id} on success
  - {:error, reason} on failure
  """
  @spec send_notification(map()) :: {:ok, String.t()} | {:error, String.t()}
  def send_notification(_notification) do
    {:error, "PushNotification.send_notification/1 not yet implemented - stub only"}
  end

  @doc """
  Send a push notification with options.

  ## Parameters
  - notification: The notification to send
  - options: Sending options (priority, ttl, etc.)

  ## Returns
  - {:ok, notification_id} on success
  - {:error, reason} on failure
  """
  @spec send_notification(map(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def send_notification(_notification, _options) do
    {:error, "PushNotification.send_notification/2 not yet implemented - stub only"}
  end

  @doc """
  Schedule a push notification for later delivery.

  ## Parameters
  - notification: The notification to schedule
  - scheduled_time: When to send the notification

  ## Returns
  - {:ok, schedule_id} on success
  - {:error, reason} on failure
  """
  @spec schedule_notification(map(), DateTime.t()) :: {:ok, String.t()} | {:error, String.t()}
  def schedule_notification(_notification, _scheduled_time) do
    {:error, "PushNotification.schedule_notification/2 not yet implemented - stub only"}
  end

  @doc """
  Cancel a scheduled push notification.

  ## Parameters
  - notification_id: The notification identifier

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec cancel_notification(String.t()) :: :ok | {:error, String.t()}
  def cancel_notification(_notification_id) do
    {:error, "PushNotification.cancel_notification/1 not yet implemented - stub only"}
  end

  # Placeholder for __schema__ calls - this might need to be an Ecto schema in Phase 2
  @doc false
  def __schema__(_), do: nil
end
