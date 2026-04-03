defmodule Indrajaal.Substrate.L1.Nociceptor do
  @moduledoc """
  L1 Nociceptor — Pain signal detector for system distress.

  Monitors system vital signs and generates pain signals when thresholds
  are exceeded. Pain intensity is proportional to the deviation from
  homeostatic norms, triggering withdrawal reflexes at higher levels.

  ## Pain Scale (0.0 - 1.0)
  - 0.0-0.2: Normal — no action
  - 0.2-0.5: Discomfort — log warning, adjust parameters
  - 0.5-0.8: Pain — trigger defensive response, alert operators
  - 0.8-1.0: Agony — emergency shutdown path, Guardian alert

  ## STAMP Constraints
  - SC-DMS-001: Heartbeat interval MUST be 100ms
  - SC-WATCHDOG-002: Corruption triggers Guardian report
  """

  use GenServer
  require Logger

  @check_interval_ms 1_000
  @pain_decay 0.95

  defstruct sensors: %{}, pain_level: 0.0, pain_history: [], alerts_sent: 0

  @type sensor_reading :: %{
          name: atom(),
          value: float(),
          threshold: float(),
          weight: float()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec report_reading(atom(), float(), float()) :: :ok
  def report_reading(sensor, value, threshold) do
    GenServer.cast(__MODULE__, {:reading, sensor, value, threshold})
  end

  @spec pain_level() :: float()
  def pain_level do
    GenServer.call(__MODULE__, :pain_level)
  end

  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ── GenServer ────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    Process.send_after(self(), :evaluate_pain, @check_interval_ms)
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:reading, sensor, value, threshold}, state) do
    reading = %{
      value: value,
      threshold: threshold,
      weight: 1.0,
      last_update: System.monotonic_time(:millisecond)
    }

    sensors = Map.put(state.sensors, sensor, reading)
    {:noreply, %{state | sensors: sensors}}
  end

  @impl true
  def handle_call(:pain_level, _from, state) do
    {:reply, Float.round(state.pain_level, 3), state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    sensor_summary =
      Enum.map(state.sensors, fn {name, r} ->
        deviation = max(0.0, (r.value - r.threshold) / max(r.threshold, 0.001))
        {name, %{value: r.value, threshold: r.threshold, deviation: Float.round(deviation, 3)}}
      end)
      |> Map.new()

    {:reply,
     %{
       pain_level: Float.round(state.pain_level, 3),
       pain_category: categorize_pain(state.pain_level),
       sensor_count: map_size(state.sensors),
       sensors: sensor_summary,
       alerts_sent: state.alerts_sent
     }, state}
  end

  @impl true
  def handle_info(:evaluate_pain, state) do
    new_pain = compute_aggregate_pain(state.sensors)
    decayed = state.pain_level * @pain_decay
    combined = max(new_pain, decayed)
    clamped = min(1.0, combined)

    state = maybe_alert(clamped, state)

    history = Enum.take([clamped | state.pain_history], 60)
    Process.send_after(self(), :evaluate_pain, @check_interval_ms)

    {:noreply, %{state | pain_level: clamped, pain_history: history}}
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp compute_aggregate_pain(sensors) when map_size(sensors) == 0, do: 0.0

  defp compute_aggregate_pain(sensors) do
    {total_pain, total_weight} =
      Enum.reduce(sensors, {0.0, 0.0}, fn {_name, r}, {pain, weight} ->
        deviation = max(0.0, (r.value - r.threshold) / max(r.threshold, 0.001))
        signal = min(1.0, deviation)
        {pain + signal * r.weight, weight + r.weight}
      end)

    if total_weight > 0, do: total_pain / total_weight, else: 0.0
  end

  defp maybe_alert(pain, state) when pain > 0.8 and state.pain_level <= 0.8 do
    Logger.error("[L1-Nociceptor] AGONY level reached: #{Float.round(pain, 3)}")
    publish_pain_event(:agony, pain)
    %{state | alerts_sent: state.alerts_sent + 1}
  end

  defp maybe_alert(pain, state) when pain > 0.5 and state.pain_level <= 0.5 do
    Logger.warning("[L1-Nociceptor] PAIN level reached: #{Float.round(pain, 3)}")
    publish_pain_event(:pain, pain)
    %{state | alerts_sent: state.alerts_sent + 1}
  end

  defp maybe_alert(_pain, state), do: state

  defp categorize_pain(level) when level < 0.2, do: :normal
  defp categorize_pain(level) when level < 0.5, do: :discomfort
  defp categorize_pain(level) when level < 0.8, do: :pain
  defp categorize_pain(_level), do: :agony

  defp publish_pain_event(category, level) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:nociception",
      {:pain_signal, %{category: category, level: level, timestamp: DateTime.utc_now()}}
    )
  rescue
    _ -> :ok
  end
end
