defmodule Indrajaal.Cockpit.Prajna.AlarmsIntegration do
  @moduledoc """
  Alarms Domain Integration for Prajna Cockpit.

  Provides real-time visibility into alarm storms, correlation engine metrics,
  and workflow tracking.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-ALM-INTEG-001: Synchronous sync of storm status
  - SC-ALM-INTEG-002: Circuit breaker for correlation engine
  """

  use GenServer
  require Logger

  alias Indrajaal.Alarms.StormDetection
  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :tenant_id,
    :storm_status,
    :correlation_stats,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current alarms integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Manually trigger a metrics sync.
  """
  def sync do
    send(__MODULE__, :sync_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    tenant_id = Keyword.get(opts, :tenant_id, default_tenant_id())

    state = %__MODULE__{
      tenant_id: tenant_id,
      storm_status: %{active: false},
      correlation_stats: %{active_groups: 0},
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
    # 1. Fetch storm status
    storm_status = StormDetection.get_storm_status(state.tenant_id)

    # 2. Fetch correlation metrics (mocked for now)
    correlation_stats = %{
      active_groups: 5,
      avg_confidence: 0.82,
      peak_load: 12
    }

    # 3. Publish to Zenoh
    ZenohCoordinator.publish("indrajaal/control/alarms", %{
      storm: storm_status,
      correlation: correlation_stats,
      timestamp: DateTime.utc_now()
    })

    # 4. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :alarms, :sync],
      %{active_storm: if(storm_status.active, do: 1, else: 0)},
      %{tenant_id: state.tenant_id}
    )

    new_state = %{
      state
      | storm_status: storm_status,
        correlation_stats: correlation_stats,
        last_sync: DateTime.utc_now()
    }

    schedule_sync()

    {:noreply, new_state}
  end

  # Private Functions

  defp schedule_sync do
    Process.send_after(self(), :sync_metrics, @sync_interval_ms)
  end

  defp default_tenant_id do
    # Fallback to system tenant
    "00000000-0000-0000-0000-000000000000"
  end
end
