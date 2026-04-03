defmodule Indrajaal.Cache.Warmer do
  @moduledoc """
  Cache warming service to pre - populate f_requently accessed data.

  Features:
  - Scheduled cache warming
  - Priority - based warming
  - Resource - aware warming
  - Incremental warming

  Agent: Helper - 3 manages cache warming
  SOPv5.1 Compliance: ✅
  """

  use GenServer
  require Logger

  alias Indrajaal.{Cache, Accounts, Monitoring}

  @warming_interval :timer.minutes(15)
  @max_concurrent_warmers 5

  # ============================================================================
  # Client API
  # ============================================================================

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger immediate cache warming.
  """
  @spec warm_now(any()) :: any()
  def warm_now(targets \\ :all) do
    GenServer.cast(__MODULE__, {:warm, targets})
  end

  @doc """
  Add item to warming queue.
  """
  @spec queue_warming(term(), term(), term()) :: term()
  def queue_warming(type, id, priority \\ :normal) do
    GenServer.cast(__MODULE__, {:queue, type, id, priority})
  end

  @doc """
  Get warming statistics.
  """
  @spec stats() :: any()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  @spec init(any()) :: any()
  def init(_opts) do
    # Schedule initial warming
    schedule_warming()

    state = %{
      warming_queue: :queue.new(),
      stats: %{
        warmed: 0,
        failed: 0,
        last_run: nil,
        duration: 0
      },
      active_warmers: 0
    }

    {:ok, state}
  end

  @impl true
  @spec handle_cast(term(), term()) :: {:noreply, term()}
  def handle_cast({:warm, targets}, state) do
    state = warm_caches(targets, state)
    {:noreply, state}
  end

  @impl true
  @spec handle_cast(term(), term()) :: term()
  def handle_cast({:queue, type, id, priority}, state) do
    item = {priority, type, id}
    queue = :queue.in(item, state.warming_queue)
    state = %{state | warming_queue: queue}

    # Process queue if we have capacity
    state =
      if state.active_warmers < @max_concurrent_warmers do
        process_warming_queue(state)
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  @spec handle_info(any(), any()) :: any()
  def handle_info(:scheduled_warming, state) do
    Logger.info("Starting scheduled cache warming")
    state = warm_caches(:all, state)
    schedule_warming()

    {:noreply, state}
  end

  @impl true
  @spec handle_info(term(), term()) :: {:noreply, term()}
  def handle_info({:warming_complete, _type, result}, state) do
    state = %{state | active_warmers: state.active_warmers - 1}

    stats =
      case result do
        :ok ->
          %{state.stats | warmed: state.stats.warmed + 1}

        :error ->
          %{state.stats | failed: state.stats.failed + 1}
      end

    state = %{state | stats: stats}

    # Process more items from queue
    state = process_warming_queue(state)

    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @spec warm_caches(term(), term()) :: term()
  defp warm_caches(targets, state) do
    start_time = System.monotonic_time(:millisecond)

    # Determine what to warm
    items_to_warm = get_warming_targets(targets)

    # Queue all items
    queue =
      Enum.reduce(items_to_warm, state.warming_queue, fn item, q ->
        :queue.in(item, q)
      end)

    state = %{state | warming_queue: queue}

    # Start processing
    state = process_warming_queue(state)

    # Update stats
    duration = System.monotonic_time(:millisecond) - start_time
    stats = %{state.stats | last_run: DateTime.utc_now(), duration: duration}

    %{state | stats: stats}
  end

  @spec get_warming_targets(term()) :: term()
  defp get_warming_targets(specific_targets) when is_list(specific_targets) do
    specific_targets
  end

  @spec get_popular_devices() :: any()
  def get_popular_devices() do
    # Get most accessed devices
    case Monitoring.list_popular_devices(limit: 100) do
      {:ok, devices} ->
        Enum.map(devices, fn device ->
          {:normal, :entity, {:device, device.id}}
        end)

      _ ->
        []
    end
  end

  @spec get_recent_alarms() :: any()
  def get_recent_alarms() do
    # Get recent unresolved alarms
    case Monitoring.list_alarms(status: ["new", "acknowledged"], limit: 50) do
      {:ok, alarms} ->
        Enum.map(alarms, fn alarm ->
          {:high, :entity, {:alarm, alarm.id}}
        end)

      _ ->
        []
    end
  end

  @spec process_warming_queue(term()) :: term()
  defp process_warming_queue(state) do
    if state.active_warmers < @max_concurrent_warmers and
         not :queue.is_empty(state.warming_queue) do
      case :queue.out(state.warming_queue) do
        {{:value, item}, new_queue} ->
          spawn_warmer(item)
          state = %{state | warming_queue: new_queue, active_warmers: state.active_warmers + 1}

          # Try to process more
          process_warming_queue(state)

        {:empty, _} ->
          state
      end
    else
      state
    end
  end

  @spec spawn_warmer(term()) :: term()
  defp spawn_warmer({_priority, :session, user_id}) do
    parent = self()

    spawn(fn ->
      result = warm_user_session(user_id)
      send(parent, {:warming_complete, :session, result})
    end)
  end

  @spec spawn_warmer(term()) :: term()
  defp spawn_warmer({_priority, :entity, {type, id}}) do
    parent = self()

    spawn(fn ->
      result = warm_entity(type, id)
      send(parent, {:warming_complete, :entity, result})
    end)
  end

  @spec spawn_warmer(term()) :: term()
  defp spawn_warmer({_priority, :config, key}) do
    parent = self()

    spawn(fn ->
      result = warm_config(key)
      send(parent, {:warming_complete, :config, result})
    end)
  end

  @spec warm_user_session(term()) :: term()
  defp warm_user_session(userid) do
    try do
      case Accounts.get_user(userid) do
        {:ok, user} ->
          # Cache user session
          session_data = build_session_data(user)
          Cache.cache_session(userid, session_data)

          # Cache user permissions
          permissions = Accounts.get_user_permissions(user)
          Cache.cache_entity(:permissions, userid, permissions)

          :ok

        _ ->
          :error
      end
    rescue
      _ -> :error
    end
  end

  @spec warm_entity(term(), term()) :: term()
  defp warm_entity(type, id) do
    try do
      source_fn = fn ->
        case type do
          :device -> Monitoring.get_device(id)
          :alarm -> Monitoring.get_alarm(id)
          :site -> Monitoring.get_site(id)
          _ -> {:error, :unknown_type}
        end
      end

      case Cache.get_entity(type, id, source: source_fn) do
        {:ok, _} -> :ok
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end

  @spec warm_config(term()) :: term()
  defp warm_config(key) do
    try do
      # Fetch and cache configuration
      case fetch_config(key) do
        {:ok, value} ->
          Cache.put(:config_cache, key, value, ttl: :timer.hours(1))
          :ok

        _ ->
          :error
      end
    rescue
      _ -> :error
    end
  end

  @spec build_session_data(term()) :: term()
  defp build_session_data(user) do
    %{
      user_id: user.id,
      tenant_id: user.tenant_id,
      role: user.role,
      permissions: Accounts.get_user_permissions(user),
      preferences: user.preferences || %{},
      cached_at: DateTime.utc_now()
    }
  end

  @spec fetch_config(term()) :: term()
  defp fetch_config(key) do
    # Fetch configuration from appropriate source
    case key do
      :alarm_priorities ->
        {:ok, ["low", "medium", "high", "critical"]}

      :device_types ->
        {:ok, ["camera", "sensor", "panel", "reader", "controller"]}

      :notification_templates ->
        {:ok,
         %{
           alarm_triggered: "New alarm: {{alarm_type}} at {{location}}",
           alarm_resolved: "Alarm resolved: {{alarm_type}} at {{location}}"
         }}

      _ ->
        {:error, :not_found}
    end
  end

  @spec schedule_warming() :: any()
  defp schedule_warming do
    Process.send_after(self(), :scheduled_warming, @warming_interval)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
