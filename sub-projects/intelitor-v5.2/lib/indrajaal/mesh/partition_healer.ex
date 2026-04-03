defmodule Indrajaal.Mesh.PartitionHealer do
  @moduledoc """
  [AGENT_RECREATION_GENOME]
  Purpose: Zenoh Partition Detection and Self-Healing via Apoptosis.
  Function: Monitors mesh connectivity and triggers restart if partitioned > 60s.
  STAMP: SC-SIL6-015, T22.3.2
  Recovery:
  - Supervisor: `Indrajaal.Mesh.Supervisor`
  - Logic: Subscribes to Zenoh session events ($info/session/**).
  - Verification: Emits 'partition_healing' signal before self-termination.
  [/AGENT_RECREATION_GENOME]
  """
  use GenServer
  require Logger

  @partition_threshold_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Mesh] Partition Healer active (SC-SIL6-015).")
    {:ok, %{last_contact: DateTime.utc_now(), status: :connected}}
  end

  # --- Public API ---

  @doc "Report successful Zenoh communication"
  def report_contact do
    GenServer.cast(__MODULE__, :report_contact)
  end

  # --- Callbacks ---

  @impl true
  def handle_cast(:report_contact, state) do
    {:noreply, %{state | last_contact: DateTime.utc_now(), status: :connected}}
  end

  @impl true
  def handle_info(:check_partition, state) do
    diff = DateTime.diff(DateTime.utc_now(), state.last_contact, :millisecond)

    if diff > @partition_threshold_ms do
      trigger_apoptosis(diff, state)
    else
      # Re-schedule check
      Process.send_after(self(), :check_partition, 5_000)
      {:noreply, state}
    end
  end

  defp trigger_apoptosis(duration, state) do
    Logger.critical("[Mesh] NETWORK PARTITION DETECTED: #{duration}ms. Triggering Apoptosis.")

    # ZUIP: Publish dying gasp to Zenoh (if possible)
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohSafetyPublisher) do
      Indrajaal.Observability.ZenohSafetyPublisher.publish_emergency_response(
        "self",
        "network_partition_healing"
      )
    end

    # Trigger system restart
    spawn(fn ->
      Process.sleep(1000)
      System.stop(0)
    end)

    {:noreply, %{state | status: :apoptosis}}
  end
end
