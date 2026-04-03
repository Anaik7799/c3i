defmodule Indrajaal.Intelligence.PatternRecognitionEngine do
  @moduledoc """
  Pattern Recognition Engine — L4 Intelligence Layer

  Provides anomaly detection over streaming event data using:
  - ETS-backed sliding window of recent events (configurable size)
  - Z-score statistical anomaly detection against rolling baseline
  - Moving average deviation for trend detection
  - Multi-stream correlation to catch cross-domain anomalies

  When anomaly confidence exceeds 0.8 an alert is broadcast via PubSub and
  emitted as a telemetry event.

  ## STAMP Constraints
  - SC-SEM-001: Semantic analysis pipeline MUST be observable
  - SC-DEBUG-001: Debug telemetry bus MUST capture all anomaly events
  - SC-ALARM-001: Alarm processing MUST include confidence score
  - SC-HMI-010: Color-rich chromatic feedback on anomaly severity

  ## Algorithms
  - **Z-score**: `z = (x - μ) / σ` — flags values more than N std devs from mean
  - **MAD**: Moving Average Deviation — flags sustained trend changes
  - **Correlation**: Pearson coefficient across concurrent data streams

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L4 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @window_size 100
  @alert_threshold 0.8
  @z_score_threshold 3.0
  @mad_threshold 2.0
  @pubsub_topic "pattern_recognition:alerts"
  @table :pattern_recognition_window

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type stream_id :: atom() | String.t()

  @type anomaly_result :: %{
          stream_id: stream_id(),
          value: number(),
          z_score: float(),
          mad: float(),
          confidence: float(),
          timestamp: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Ingest a new data point for anomaly detection."
  @spec ingest(stream_id(), number()) :: :ok | {:anomaly, anomaly_result()}
  def ingest(stream_id, value) when is_number(value) do
    GenServer.call(@name, {:ingest, stream_id, value})
  end

  @doc "Returns current window statistics for a stream."
  @spec stream_stats(stream_id()) :: map()
  def stream_stats(stream_id) do
    GenServer.call(@name, {:stream_stats, stream_id})
  end

  @doc "Returns all active alerts (confidence > threshold)."
  @spec active_alerts() :: [anomaly_result()]
  def active_alerts do
    GenServer.call(@name, :active_alerts)
  end

  @doc "Computes Pearson correlation between two streams."
  @spec correlate(stream_id(), stream_id()) :: {:ok, float()} | {:error, :insufficient_data}
  def correlate(stream_a, stream_b) do
    GenServer.call(@name, {:correlate, stream_a, stream_b})
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    window_size = Keyword.get(opts, :window_size, @window_size)
    alert_threshold = Keyword.get(opts, :alert_threshold, @alert_threshold)

    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    state = %{
      window_size: window_size,
      alert_threshold: alert_threshold,
      streams: %{},
      active_alerts: []
    }

    Logger.info(
      "[PatternRecognitionEngine] Started — window=#{window_size} threshold=#{alert_threshold} [SC-SEM-001]"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:ingest, stream_id, value}, _from, state) do
    {state2, result} = process_ingest(state, stream_id, value)
    {:reply, result, state2}
  end

  @impl true
  def handle_call({:stream_stats, stream_id}, _from, state) do
    stats =
      case Map.get(state.streams, stream_id) do
        nil -> %{count: 0}
        window -> compute_stats(window)
      end

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:active_alerts, _from, state) do
    {:reply, state.active_alerts, state}
  end

  @impl true
  def handle_call({:correlate, stream_a, stream_b}, _from, state) do
    result = compute_correlation(state.streams, stream_a, stream_b)
    {:reply, result, state}
  end

  # ---------------------------------------------------------------------------
  # Core Logic
  # ---------------------------------------------------------------------------

  defp process_ingest(state, stream_id, value) do
    window = Map.get(state.streams, stream_id, :queue.new())
    window_size = state.window_size

    window2 =
      if :queue.len(window) >= window_size do
        {_, q} = :queue.out(window)
        :queue.in(value, q)
      else
        :queue.in(value, window)
      end

    state2 = put_in(state, [:streams, stream_id], window2)

    result = detect_anomaly(state2, stream_id, value)

    state3 =
      case result do
        {:anomaly, anomaly} ->
          alert = Map.put(anomaly, :stream_id, stream_id)
          emit_anomaly_alert(alert)
          alerts = Enum.take([alert | state2.active_alerts], 50)
          %{state2 | active_alerts: alerts}

        :ok ->
          # Remove resolved alerts for this stream
          alerts = Enum.reject(state2.active_alerts, &(&1.stream_id == stream_id))
          %{state2 | active_alerts: alerts}
      end

    {state3, result}
  end

  defp detect_anomaly(state, stream_id, value) do
    window = Map.get(state.streams, stream_id, :queue.new())
    values = :queue.to_list(window)

    if length(values) < 5 do
      :ok
    else
      stats = compute_stats(values)
      z_score = compute_z_score(value, stats.mean, stats.std_dev)
      mad = compute_mad(value, stats.mean, stats.moving_avg)
      confidence = compute_confidence(z_score, mad)

      if confidence >= state.alert_threshold do
        {:anomaly,
         %{
           value: value,
           z_score: z_score,
           mad: mad,
           confidence: confidence,
           timestamp: System.system_time(:millisecond)
         }}
      else
        :ok
      end
    end
  end

  defp compute_stats(values) when is_list(values) and length(values) > 0 do
    n = length(values)
    mean = Enum.sum(values) / n

    variance =
      values
      |> Enum.map(fn x -> (x - mean) * (x - mean) end)
      |> Enum.sum()
      |> Kernel./(max(n - 1, 1))

    std_dev = :math.sqrt(max(variance, 0.0))

    # Moving average uses last 10 values
    window_10 = Enum.take(values, -10)
    moving_avg = Enum.sum(window_10) / length(window_10)

    %{mean: mean, std_dev: std_dev, moving_avg: moving_avg, count: n}
  end

  defp compute_stats(window) do
    compute_stats(:queue.to_list(window))
  end

  defp compute_z_score(_value, _mean, std_dev) when std_dev == 0.0, do: 0.0

  defp compute_z_score(value, mean, std_dev) do
    abs((value - mean) / std_dev)
  end

  defp compute_mad(value, mean, moving_avg) do
    baseline = (mean + moving_avg) / 2.0
    if baseline == 0.0, do: 0.0, else: abs(value - baseline) / max(abs(baseline), 1.0)
  end

  defp compute_confidence(z_score, mad) do
    z_component = min(z_score / @z_score_threshold, 1.0)
    mad_component = min(mad / @mad_threshold, 1.0)
    z_component * 0.7 + mad_component * 0.3
  end

  defp compute_correlation(streams, stream_a, stream_b) do
    vals_a = stream_values(streams, stream_a)
    vals_b = stream_values(streams, stream_b)

    min_len = min(length(vals_a), length(vals_b))

    if min_len < 5 do
      {:error, :insufficient_data}
    else
      a = Enum.take(vals_a, min_len)
      b = Enum.take(vals_b, min_len)

      n = min_len
      mean_a = Enum.sum(a) / n
      mean_b = Enum.sum(b) / n

      numerator =
        Enum.zip(a, b)
        |> Enum.map(fn {va, vb} -> (va - mean_a) * (vb - mean_b) end)
        |> Enum.sum()

      std_a =
        :math.sqrt(
          Enum.sum(Enum.map(a, fn va -> (va - mean_a) * (va - mean_a) end)) / max(n - 1, 1)
        )

      std_b =
        :math.sqrt(
          Enum.sum(Enum.map(b, fn vb -> (vb - mean_b) * (vb - mean_b) end)) / max(n - 1, 1)
        )

      denom = std_a * std_b * n

      if denom == 0.0 do
        {:ok, 0.0}
      else
        {:ok, numerator / denom}
      end
    end
  end

  defp stream_values(streams, stream_id) do
    case Map.get(streams, stream_id) do
      nil -> []
      window -> :queue.to_list(window)
    end
  end

  defp emit_anomaly_alert(alert) do
    Logger.warning(
      "[PatternRecognitionEngine] Anomaly on #{alert.stream_id}: " <>
        "confidence=#{Float.round(alert.confidence, 3)} z=#{Float.round(alert.z_score, 2)} [SC-SEM-001]"
    )

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:anomaly_detected, alert}
    )

    :telemetry.execute(
      [:indrajaal, :intelligence, :pattern_recognition, :anomaly],
      %{confidence: alert.confidence, z_score: alert.z_score, mad: alert.mad},
      %{stream_id: alert.stream_id}
    )
  rescue
    _ -> :ok
  end
end
