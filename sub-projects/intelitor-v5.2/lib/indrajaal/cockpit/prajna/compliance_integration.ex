defmodule Indrajaal.Cockpit.Prajna.ComplianceIntegration do
  @moduledoc """
  Compliance Domain Integration for Prajna Cockpit.

  Provides real-time visibility into forensic investigations, audit trail
  integrity, and evidence collection status.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-COM-INTEG-001: Forensic status synchronization
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :active_investigations,
    :evidence_count,
    :integrity_score,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current compliance integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      active_investigations: 0,
      evidence_count: 0,
      integrity_score: 100.0,
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
      active_investigations: 2,
      evidence_count: 1250,
      integrity_score: 99.98,
      audit_log_completeness: 100.0,
      forensic_timeline_events: 45
    }

    # 2. Publish to Zenoh
    ZenohCoordinator.publish("indrajaal/control/compliance", %{
      compliance: metrics,
      timestamp: DateTime.utc_now()
    })

    # 3. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :compliance, :sync],
      %{active_investigations: metrics.active_investigations},
      %{integrity_score: metrics.integrity_score}
    )

    new_state = %{
      state
      | active_investigations: metrics.active_investigations,
        evidence_count: metrics.evidence_count,
        integrity_score: metrics.integrity_score,
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
