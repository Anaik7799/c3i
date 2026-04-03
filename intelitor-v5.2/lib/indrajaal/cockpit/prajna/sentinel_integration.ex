defmodule Indrajaal.Cockpit.Prajna.SentinelIntegration do
  @moduledoc """
  Sentinel and Immune System Integration for Prajna Cockpit.

  Provides real-time visibility into cluster quorum, threat severity,
  chaos agent (Mara) metrics, and quarantine status.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-IMMUNE-INTEG-001: Real-time threat tracking
  - SC-CLU-INTEG-001: Real-time quorum monitoring
  """

  use GenServer
  require Logger

  alias Indrajaal.Cluster.Sentinel
  alias Indrajaal.Cockpit.Prajna.Immune.Mara
  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :cluster_status,
    :mara_stats,
    :active_threats,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current sentinel integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      cluster_status: %{status: :unknown, has_quorum: false},
      mara_stats: %{total_attacks: 0},
      active_threats: [],
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
    # 1. Fetch cluster status
    cluster_status = Sentinel.get_status()

    # 2. Fetch Mara stats
    mara_stats = Mara.stats()

    # 3. Publish to Zenoh (split across two topics for clarity)
    ZenohCoordinator.publish("indrajaal/control/cluster", %{
      cluster: cluster_status,
      timestamp: DateTime.utc_now()
    })

    ZenohCoordinator.publish("indrajaal/control/immune", %{
      mara: mara_stats,
      timestamp: DateTime.utc_now()
    })

    # 4. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :sentinel, :sync],
      %{active_nodes: cluster_status.active_count},
      %{quorum_healthy: cluster_status.has_quorum}
    )

    new_state = %{
      state
      | cluster_status: cluster_status,
        mara_stats: mara_stats,
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
