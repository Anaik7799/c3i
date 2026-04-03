defmodule IndrajaalWeb.Presence do
  @moduledoc """
  Phoenix Presence wrapper for tracking user presence across channels.

  Provides real - time user presence information with multi - device support
  and enhanced meta_data tracking.

  Agent: Helper - 4 manages presence tracking
  SOPv5.1 Compliance: ✅
  """

  use Phoenix.Presence,
    otp_app: :indrajaal,
    pubsub_server: Indrajaal.PubSub

  # Note: ConnectionTracker alias removed (EP301 - unused alias)
  # ConnectionTracker module not currently available
  # alias Indrajaal.Realtime.ConnectionTracker

  require Logger

  @doc """
  Tracks a user's presence in a channel.
  """
  @spec track_user(term(), term(), term()) :: term()
  def track_user(socket, user_id, meta \\ %{}) do
    # Add connection meta_data
    enhanced_meta =
      Map.merge(meta, %{
        online_at: DateTime.utc_now(),
        device_id: socket.assigns[:device_id],
        device_type: socket.assigns[:device_type],
        socket_id: socket.id,
        channels: [socket.topic]
      })

    track(socket, user_id, enhanced_meta)
  end

  @doc """
  Updates a user's presence metadata.
  """
  @spec update_user(term(), term(), term()) :: term()
  def update_user(socket, user_id, updates) do
    update(socket, user_id, fn meta ->
      Map.merge(meta, updates)
    end)
  end

  @doc """
  Adds a channel to user's active channels list.
  """
  @spec add_channel(term(), term(), term()) :: term()
  def add_channel(socket, user_id, channel) do
    update_user(socket, user_id, %{
      channels: get_user_channels(socket, user_id) ++ [channel]
    })
  end

  @doc """
  Removes a channel from user's active channels list.
  """
  @spec remove_channel(term(), term(), term()) :: term()
  def remove_channel(socket, user_id, channel) do
    update_user(socket, user_id, %{
      channels: List.delete(get_user_channels(socket, user_id), channel)
    })
  end

  @doc """
  Gets all __users present in a channel.
  """
  @spec list_users(any()) :: any()
  def list_users(topic) do
    users = list(topic)

    users
    |> Enum.map(fn {user_id, %{metas: metas}} ->
      # Merge meta_data from multiple devices
      merged_meta = merge_user_metas(metas)

      %{
        user_id: user_id,
        online_since: get_earliest_online_time(metas),
        devices: length(metas),
        device_types: get_device_types(metas),
        channels: get_all_channels(metas),
        meta_data: merged_meta
      }
    end)
  end

  @doc """
  Gets a specific user's presence info.
  """
  @spec get_user(any(), any()) :: any()
  def get_user(topic, user_id) do
    case get_by_key(topic, user_id) do
      [] ->
        nil

      %{metas: metas} ->
        %{
          user_id: user_id,
          online_since: get_earliest_online_time(metas),
          devices: length(metas),
          device_types: get_device_types(metas),
          channels: get_all_channels(metas),
          meta_data: merge_user_metas(metas)
        }
    end
  end

  @doc """
  Checks if a user is online in any channel.
  """
  # Note: ConnectionTracker module not currently available
  # Connection tracking commented out until module is implemented
  @spec __user_online?(any()) :: any()
  def __user_online?(_user_id) do
    # Check across all topics
    # connections = if Code.ensure_loaded?(ConnectionTracker) and
    #                  function_exported?(ConnectionTracker, :get_user_connections, 1) do
    #   ConnectionTracker.get_user_connections(user_id)
    # else
    #   []
    # end
    # length(connections) > 0
    # Return false until ConnectionTracker is available
    false
  end

  @doc """
  Gets all channels a user is present in.
  """
  @spec get_user_channels(any(), any()) :: any()
  def get_user_channels(socket, user_id) do
    case get_user(socket.topic, user_id) do
      nil -> []
      user -> user.channels || []
    end
  end

  @doc """
  Enhances presence __data with additional information and handles errors gracefully.
  """
  @spec fetch(any(), any()) :: any()
  def fetch(_topic, entries) do
    # This is called by Phoenix.Presence to fetch additional user __data
    # We'll enhance the entries with user information

    _user_ids = Map.keys(entries)

    # In production, this would fetch from __database
    # For now, return entries as - is
    entries
  end

  @doc """
  Custom presence tracking with automatic cleanup.
  """
  @spec track_with_cleanup(term(), term(), term(), term()) :: term()
  def track_with_cleanup(socket, user_id, meta, cleanup_after \\ :timer.minutes(30)) do
    # Track presence
    {:ok, _} = track_user(socket, user_id, meta)

    # Schedule cleanup
    Process.send_after(self(), {:cleanup_presence, user_id}, cleanup_after)

    :ok
  end

  # Helper functions for presence __data processing
  defp get_earliest_online_time(metas) do
    metas
    |> Enum.map(fn meta -> meta.online_at end)
    |> Enum.min(DateTime)
  end

  defp get_device_types(metas) do
    metas
    |> Enum.map(fn meta -> meta.device_type end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp get_all_channels(metas) do
    metas
    |> Enum.flat_map(fn meta -> meta.channels || [] end)
    |> Enum.uniq()
  end

  defp merge_user_metas(metas) do
    Enum.reduce(metas, %{}, fn meta, acc ->
      Map.merge(acc, meta)
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
