defmodule Indrajaal.Video.Preroll.EventTrigger do
  @moduledoc """
  Alarm-triggered buffer freeze functionality.

  Connects alarm events to the pre-roll buffer system, freezing
  camera buffers when alarms trigger and managing the frozen
  snapshots until they're processed.

  ## STAMP Constraints

  - SC-PREROLL-001: Non-blocking operations

  ## Usage

      {:ok, trigger} = EventTrigger.start_link(buffer_manager: buffer_manager_pid)

      # Subscribe to freeze events
      EventTrigger.subscribe(trigger, self())

      # Trigger freeze on alarm
      {:ok, result} = EventTrigger.trigger_freeze(trigger, "alarm-123", "camera-1")

      # Result includes the frozen buffer data
      save_preroll_video(result.frozen.frames)

      # Clear after processing
      EventTrigger.clear_frozen(trigger, "alarm-123")

  """

  use GenServer
  require Logger

  alias Indrajaal.Video.Preroll.BufferManager

  @type alarm_id :: String.t()
  @type camera_id :: String.t()

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Triggers a buffer freeze for a camera due to an alarm.
  """
  @spec trigger_freeze(GenServer.server(), alarm_id(), camera_id()) ::
          {:ok, map()} | {:error, atom()}
  def trigger_freeze(server \\ __MODULE__, alarm_id, camera_id) do
    GenServer.call(server, {:trigger_freeze, alarm_id, camera_id})
  end

  @doc """
  Gets list of all frozen buffers waiting to be processed.
  """
  @spec get_frozen_buffers(GenServer.server()) :: [map()]
  def get_frozen_buffers(server \\ __MODULE__) do
    GenServer.call(server, :get_frozen_buffers)
  end

  @doc """
  Clears a frozen buffer after it's been processed.
  """
  @spec clear_frozen(GenServer.server(), alarm_id()) :: :ok
  def clear_frozen(server \\ __MODULE__, alarm_id) do
    GenServer.call(server, {:clear_frozen, alarm_id})
  end

  @doc """
  Subscribes to buffer freeze events.

  Subscriber receives `{:buffer_frozen, %{alarm_id: _, camera_id: _, frozen: _}}`
  """
  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server \\ __MODULE__, pid) do
    GenServer.call(server, {:subscribe, pid})
  end

  @doc """
  Returns trigger metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server \\ __MODULE__) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    buffer_manager = Keyword.fetch!(opts, :buffer_manager)

    state = %{
      buffer_manager: buffer_manager,
      frozen_buffers: %{},
      subscribers: [],
      metrics: %{
        total_freezes: 0
      },
      started_at: DateTime.utc_now()
    }

    Logger.info("[EventTrigger] Started with buffer_manager: #{inspect(buffer_manager)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:trigger_freeze, alarm_id, camera_id}, _from, state) do
    case BufferManager.freeze_buffer(state.buffer_manager, camera_id) do
      {:ok, frozen} ->
        result = %{
          alarm_id: alarm_id,
          camera_id: camera_id,
          frozen: frozen,
          triggered_at: DateTime.utc_now()
        }

        # Store frozen buffer
        new_frozen = Map.put(state.frozen_buffers, alarm_id, result)

        # Notify subscribers
        notify_subscribers(state.subscribers, {:buffer_frozen, result})

        # Update metrics
        new_metrics = %{state.metrics | total_freezes: state.metrics.total_freezes + 1}

        new_state = %{state | frozen_buffers: new_frozen, metrics: new_metrics}

        Logger.info("[EventTrigger] Froze buffer for alarm: #{alarm_id}, camera: #{camera_id}")

        {:reply, {:ok, result}, new_state}

      {:error, :not_found} ->
        {:reply, {:error, :camera_not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_frozen_buffers, _from, state) do
    {:reply, Map.values(state.frozen_buffers), state}
  end

  @impl true
  def handle_call({:clear_frozen, alarm_id}, _from, state) do
    new_frozen = Map.delete(state.frozen_buffers, alarm_id)
    {:reply, :ok, %{state | frozen_buffers: new_frozen}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      total_freezes: state.metrics.total_freezes,
      pending_frozen: map_size(state.frozen_buffers),
      subscriber_count: length(state.subscribers),
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_subscribers = Enum.reject(state.subscribers, &(&1 == pid))
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, message)
    end)
  end
end
