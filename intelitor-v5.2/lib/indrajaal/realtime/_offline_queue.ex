defmodule Indrajaal.Realtime.OfflineQueue do
  @moduledoc """
  Offline message queue management for real-time notifications.

  Handles delivery of messages that were queued while users were offline.
  Generated stub by AEE SOPv5.11 - Phase 4.5 Batch 2.
  """

  require Logger

  @ets_table :offline_message_queue

  @doc """
  Ensures the ETS table for offline messages exists.
  """
  def ensure_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:bag, :public, :named_table])
    end

    :ok
  end

  @doc """
  Queues a message for an offline user.
  """
  @spec queue_message(String.t() | integer(), map()) :: :ok
  def queue_message(user_id, message) when is_map(message) do
    ensure_table()
    timestamped = Map.put(message, :queued_at, DateTime.utc_now())
    :ets.insert(@ets_table, {user_id, timestamped})
    Logger.debug("[OfflineQueue] Queued message for user #{inspect(user_id)}")
    :ok
  end

  @spec deliver_to_user(String.t() | integer(), pid()) :: :ok
  def deliver_to_user(user_id, channel_pid) when is_pid(channel_pid) do
    ensure_table()

    messages =
      @ets_table
      |> :ets.lookup(user_id)
      |> Enum.map(fn {_uid, msg} -> msg end)
      |> Enum.sort_by(& &1[:queued_at], DateTime)

    case messages do
      [] ->
        Logger.debug("[OfflineQueue] No queued messages for user #{inspect(user_id)}")

      msgs ->
        Enum.each(msgs, fn msg ->
          send(channel_pid, {:offline_message, msg})
        end)

        :ets.delete(@ets_table, user_id)

        Logger.info(
          "[OfflineQueue] Delivered #{length(msgs)} messages to user #{inspect(user_id)}"
        )
    end

    :ok
  end

  @doc """
  Returns count of queued messages for a user.
  """
  @spec pending_count(String.t() | integer()) :: non_neg_integer()
  def pending_count(user_id) do
    ensure_table()

    @ets_table
    |> :ets.lookup(user_id)
    |> length()
  end
end
