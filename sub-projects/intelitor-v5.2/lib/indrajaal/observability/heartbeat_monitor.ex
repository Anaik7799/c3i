defmodule Indrajaal.Observability.HeartbeatMonitor do
  @moduledoc """
  ## METABOLIC MONITOR (SYMPATHETIC NERVOUS SYSTEM)
  Passively observes the metabolic pulses of the system planes.
  Detects arrhythmias (missed heartbeats) and broadcasts health status.

  **Thresholds**:
  - **Arrhythmia**: > 35s (Warning)
  - **Asystole**: > 90s (Critical/Defibrillate)

  **Compliance**: SC-SIL6-005 (Symbiotic Binding)
  """
  use GenServer
  require Logger

  # --- CONFIGURATION ---
  # Check every 5s
  @check_interval 5_000
  @arrhythmia_threshold 35_000
  @asystole_threshold 90_000

  # --- CLIENT API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_pulse(plane) do
    GenServer.cast(__MODULE__, {:record_pulse, plane})
  end

  # --- SERVER CALLBACKS ---

  @impl true
  def init(_opts) do
    Logger.info("🩺 [OBS-PLANE] Heartbeat Monitor Active.")
    schedule_check()
    # Initialize with "now" to give grace period on startup
    {:ok,
     %{
       # {last_seen, history}
       data_plane: {DateTime.utc_now(), []},
       state_plane: {DateTime.utc_now(), []},
       log_plane: {DateTime.utc_now(), []}
     }}
  end

  @impl true
  def handle_cast({:record_pulse, plane}, state) do
    now = DateTime.utc_now()
    {last_seen, history} = Map.get(state, plane, {now, []})

    # Calculate interval
    interval = DateTime.diff(now, last_seen, :millisecond)
    # Keep last 5
    new_history = [interval | Enum.take(history, 4)]

    # Predictive Analysis
    avg_interval =
      if length(new_history) > 0, do: Enum.sum(new_history) / length(new_history), else: 0

    if avg_interval > 25_000 do
      Logger.warning(
        "🔮 [OBS-PLANE] PREDICTION: Arrhythmia Imminent on #{plane} (Avg: #{avg_interval}ms)"
      )
    end

    {:noreply, Map.put(state, plane, {now, new_history})}
  end

  @impl true
  def handle_info(:check_vitals, state) do
    now = DateTime.utc_now()

    state
    |> Stream.each(fn {plane, {last_seen, _}} ->
      diff = DateTime.diff(now, last_seen, :millisecond)

      cond do
        diff > @asystole_threshold ->
          Logger.error(
            "💔 [OBS-PLANE] ASYSTOLE DETECTED on #{plane}: #{diff}ms silence! INITIATING DEFIBRILLATION PROTOCOLS."
          )

          # Autonomic Healing: Trigger Restart
          Indrajaal.Integration.CepafClient.restart_container(plane)

        diff > @arrhythmia_threshold ->
          Logger.warning("⚠️ [OBS-PLANE] Arrhythmia detected on #{plane}: #{diff}ms latency.")

        true ->
          :ok
      end
    end)
    # Force evaluation
    |> Stream.run()

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_vitals, @check_interval)
  end
end
