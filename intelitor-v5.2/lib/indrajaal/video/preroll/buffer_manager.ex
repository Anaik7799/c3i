defmodule Indrajaal.Video.Preroll.BufferManager do
  @moduledoc """
  Per-camera ring buffer management for video pre-roll.

  Manages individual ring buffers for each active camera stream,
  allowing independent freeze operations when alarms trigger.

  ## STAMP Constraints

  - SC-PREROLL-003: One buffer per active stream

  ## Usage

      {:ok, manager} = BufferManager.start_link()

      # Create buffer for a camera
      :ok = BufferManager.create_buffer(manager, "camera-1", capacity: 900)

      # Push frames as they arrive
      BufferManager.push_frame(manager, "camera-1", %{
        data: frame_binary,
        timestamp: timestamp
      })

      # On alarm, freeze the buffer
      {:ok, frozen} = BufferManager.freeze_buffer(manager, "camera-1")

  """

  use GenServer
  require Logger

  alias Indrajaal.Video.Preroll.RingBuffer

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
  Creates a buffer for a camera.
  """
  @spec create_buffer(GenServer.server(), camera_id(), keyword()) ::
          :ok | {:error, :already_exists}
  def create_buffer(server \\ __MODULE__, camera_id, opts \\ []) do
    GenServer.call(server, {:create_buffer, camera_id, opts})
  end

  @doc """
  Checks if a buffer exists for a camera.
  """
  @spec buffer_exists?(GenServer.server(), camera_id()) :: boolean()
  def buffer_exists?(server \\ __MODULE__, camera_id) do
    GenServer.call(server, {:buffer_exists?, camera_id})
  end

  @doc """
  Pushes a frame to a camera's buffer.
  """
  @spec push_frame(GenServer.server(), camera_id(), map()) :: :ok | {:error, :not_found}
  def push_frame(server \\ __MODULE__, camera_id, frame) do
    GenServer.call(server, {:push_frame, camera_id, frame})
  end

  @doc """
  Freezes a camera's buffer, returning the snapshot.
  """
  @spec freeze_buffer(GenServer.server(), camera_id()) :: {:ok, map()} | {:error, :not_found}
  def freeze_buffer(server \\ __MODULE__, camera_id) do
    GenServer.call(server, {:freeze_buffer, camera_id})
  end

  @doc """
  Destroys a camera's buffer.
  """
  @spec destroy_buffer(GenServer.server(), camera_id()) :: :ok
  def destroy_buffer(server \\ __MODULE__, camera_id) do
    GenServer.call(server, {:destroy_buffer, camera_id})
  end

  @doc """
  Gets stats for a camera's buffer.
  """
  @spec get_stats(GenServer.server(), camera_id()) :: map() | nil
  def get_stats(server \\ __MODULE__, camera_id) do
    GenServer.call(server, {:get_stats, camera_id})
  end

  @doc """
  Lists all active cameras.
  """
  @spec list_cameras(GenServer.server()) :: [camera_id()]
  def list_cameras(server \\ __MODULE__) do
    GenServer.call(server, :list_cameras)
  end

  @doc """
  Returns aggregate metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server \\ __MODULE__) do
    GenServer.call(server, :metrics)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      buffers: %{},
      started_at: DateTime.utc_now()
    }

    Logger.info("[BufferManager] Started")

    {:ok, state}
  end

  @impl true
  def handle_call({:create_buffer, camera_id, opts}, _from, state) do
    if Map.has_key?(state.buffers, camera_id) do
      {:reply, {:error, :already_exists}, state}
    else
      buffer = RingBuffer.new(opts)
      new_buffers = Map.put(state.buffers, camera_id, buffer)
      {:reply, :ok, %{state | buffers: new_buffers}}
    end
  end

  @impl true
  def handle_call({:buffer_exists?, camera_id}, _from, state) do
    {:reply, Map.has_key?(state.buffers, camera_id), state}
  end

  @impl true
  def handle_call({:push_frame, camera_id, frame}, _from, state) do
    case Map.get(state.buffers, camera_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      buffer ->
        {:ok, new_buffer} = RingBuffer.push(buffer, frame)
        new_buffers = Map.put(state.buffers, camera_id, new_buffer)
        {:reply, :ok, %{state | buffers: new_buffers}}
    end
  end

  @impl true
  def handle_call({:freeze_buffer, camera_id}, _from, state) do
    case Map.get(state.buffers, camera_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      buffer ->
        frozen = RingBuffer.freeze(buffer)
        {:reply, {:ok, frozen}, state}
    end
  end

  @impl true
  def handle_call({:destroy_buffer, camera_id}, _from, state) do
    new_buffers = Map.delete(state.buffers, camera_id)
    {:reply, :ok, %{state | buffers: new_buffers}}
  end

  @impl true
  def handle_call({:get_stats, camera_id}, _from, state) do
    result =
      case Map.get(state.buffers, camera_id) do
        nil -> nil
        buffer -> RingBuffer.stats(buffer)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_cameras, _from, state) do
    {:reply, Map.keys(state.buffers), state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    total_frames =
      state.buffers
      |> Map.values()
      |> Enum.map(& &1.size)
      |> Enum.sum()

    metrics = %{
      active_buffers: map_size(state.buffers),
      total_frames: total_frames,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics, state}
  end
end
