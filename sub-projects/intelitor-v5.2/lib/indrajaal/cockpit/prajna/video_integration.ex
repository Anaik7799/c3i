defmodule Indrajaal.Cockpit.Prajna.VideoIntegration do
  @moduledoc """
  Video Domain Integration for Prajna Cockpit.

  Provides real-time visibility into stream health, processing latency,
  and detection accuracy.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-VID-INTEG-001: Stream status synchronization
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :active_streams,
    :avg_latency_ms,
    :avg_confidence,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current video integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      active_streams: 0,
      avg_latency_ms: 0,
      avg_confidence: 0.0,
      last_sync: nil
    }

    # Schedule periodic sync
    schedule_sync()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_info(:sync_metrics, state) do
    # 1. Fetch metrics (mocked for now)
    metrics = %{
      active_streams: 12,
      avg_latency_ms: 45,
      avg_confidence: 0.88,
      peak_processing_load: 72
    }

    # 2. Publish to Zenoh
    ZenohCoordinator.publish("indrajaal/control/video", %{
      video: metrics,
      timestamp: DateTime.utc_now()
    })

    # 3. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :video, :sync],
      %{active_streams: metrics.active_streams},
      %{avg_latency: metrics.avg_latency_ms}
    )

    new_state = %{
      state
      | active_streams: metrics.active_streams,
        avg_latency_ms: metrics.avg_latency_ms,
        avg_confidence: metrics.avg_confidence,
        last_sync: DateTime.utc_now()
    }

    schedule_sync()

    {:noreply, new_state}
  end

  # Private Functions

  defp schedule_sync do
    Process.send_after(self(), :sync_metrics, @sync_interval_ms)
  end
end
