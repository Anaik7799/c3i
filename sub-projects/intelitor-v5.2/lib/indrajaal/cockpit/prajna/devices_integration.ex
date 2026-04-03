defmodule Indrajaal.Cockpit.Prajna.DevicesIntegration do
  @moduledoc """
  Devices Domain Integration for Prajna Cockpit.

  Provides real-time visibility into device health, sensor status,
  connectivity matrix, and battery levels.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-DEV-INTEG-001: Device health matrix synchronization
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :online_devices,
    :total_devices,
    :sensor_alerts,
    :battery_warnings,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current devices integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      online_devices: 0,
      total_devices: 0,
      sensor_alerts: 0,
      battery_warnings: 0,
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
      online_devices: 142,
      total_devices: 150,
      sensor_alerts: 3,
      battery_warnings: 8,
      power_faults: 1,
      connectivity_score: 94.5
    }

    # 2. Publish to Zenoh
    ZenohCoordinator.publish("indrajaal/control/devices", %{
      devices: metrics,
      timestamp: DateTime.utc_now()
    })

    # 3. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :devices, :sync],
      %{online_ratio: metrics.online_devices / metrics.total_devices},
      %{sensor_alerts: metrics.sensor_alerts}
    )

    new_state = %{
      state
      | online_devices: metrics.online_devices,
        total_devices: metrics.total_devices,
        sensor_alerts: metrics.sensor_alerts,
        battery_warnings: metrics.battery_warnings,
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
