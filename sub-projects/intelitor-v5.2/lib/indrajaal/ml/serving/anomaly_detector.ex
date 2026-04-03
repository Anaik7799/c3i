defmodule Indrajaal.ML.Serving.AnomalyDetector do
  @moduledoc """
  Nx.Serving-based anomaly detection for time series and behavioral data.

  Implements multiple detection methods:
  - Statistical (Z-score, IQR)
  - Isolation Forest (simulated)
  - Sliding window baseline comparison

  STAMP Compliance:
  - SC-ML-001: Model serving isolation
  - SC-OBS-067: Anomaly detection for operational metrics

  Integration:
  - FLAME.AnalyticsPool for batch anomaly detection
  - Real-time streaming via Broadway (future)
  """

  use GenServer

  require Logger

  @default_batch_size 50
  @default_batch_timeout 50

  # Detection thresholds
  @zscore_threshold 2.5
  @iqr_multiplier 1.5
  @isolation_threshold 0.6

  ## Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Detect anomalies in a time series.

  ## Parameters
  - `data_points` - List of numeric values or `%{value: v, timestamp: t}` maps
  - `opts` - Options:
    - `:method` - `:zscore`, `:iqr`, `:isolation`, `:ensemble` (default)
    - `:threshold` - Custom threshold override

  ## Returns
  - `{:ok, %{anomalies: list, stats: map}}`
  """
  def detect(data_points, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    GenServer.call(__MODULE__, {:detect, data_points, opts}, timeout)
  end

  @doc """
  Detect anomalies using FLAME for large datasets.
  """
  def detect_via_flame(data_points, opts \\ []) do
    alias Indrajaal.FLAME.SafeRunner

    FLAME.call(Indrajaal.FLAME.AnalyticsPool, fn ->
      SafeRunner.guard_state()
      do_detect(data_points, opts)
    end)
  end

  @doc """
  Real-time anomaly check for a single value against a baseline.
  """
  def check_realtime(value, baseline_stats) do
    GenServer.call(__MODULE__, {:check_realtime, value, baseline_stats})
  end

  @doc """
  Get detection statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout, @default_batch_timeout)

    Logger.info("🔍 AnomalyDetector: Starting (batch_size: #{batch_size})")

    state = %{
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      model_version: "1.0.0",
      stats: %{
        total_analyzed: 0,
        anomalies_detected: 0,
        by_method: %{zscore: 0, iqr: 0, isolation: 0}
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:detect, data_points, opts}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result = do_detect(data_points, opts)

    latency_us = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:detect, latency_us, length(data_points), length(result.anomalies))

    # Update stats
    new_stats = %{
      state.stats
      | total_analyzed: state.stats.total_analyzed + length(data_points),
        anomalies_detected: state.stats.anomalies_detected + length(result.anomalies)
    }

    {:reply, {:ok, result}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:check_realtime, value, baseline_stats}, _from, state) do
    result = realtime_check(value, baseline_stats)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  ## Private Functions

  defp do_detect(data_points, opts) do
    method = Keyword.get(opts, :method, :ensemble)
    values = extract_values(data_points)

    # Compute baseline statistics
    stats = compute_statistics(values)

    # Detect anomalies based on method
    anomalies =
      case method do
        :zscore -> detect_zscore(data_points, values, stats, opts)
        :iqr -> detect_iqr(data_points, values, stats, opts)
        :isolation -> detect_isolation(data_points, values, opts)
        :ensemble -> detect_ensemble(data_points, values, stats, opts)
      end

    %{
      anomalies: anomalies,
      method: method,
      stats: stats,
      data_points_analyzed: length(values),
      detected_at: DateTime.utc_now()
    }
  end

  defp extract_values(data_points) do
    Enum.map(data_points, fn
      %{value: v} -> v
      v when is_number(v) -> v
    end)
  end

  defp compute_statistics(values) when length(values) < 2 do
    %{mean: 0.0, std: 0.0, median: 0.0, q1: 0.0, q3: 0.0, iqr: 0.0, min: 0.0, max: 0.0}
  end

  defp compute_statistics(values) do
    sorted = Enum.sort(values)
    n = length(values)

    mean = Enum.sum(values) / n

    variance =
      values
      |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(n)

    std = :math.sqrt(variance)

    median = percentile(sorted, 0.5)
    q1 = percentile(sorted, 0.25)
    q3 = percentile(sorted, 0.75)
    iqr = q3 - q1

    %{
      mean: Float.round(mean, 4),
      std: Float.round(std, 4),
      median: Float.round(median, 4),
      q1: Float.round(q1, 4),
      q3: Float.round(q3, 4),
      iqr: Float.round(iqr, 4),
      min: Enum.min(values),
      max: Enum.max(values),
      count: n
    }
  end

  defp percentile(sorted_values, p) do
    n = length(sorted_values)
    k = (n - 1) * p
    f = floor(k)
    c = ceil(k)

    if f == c do
      Enum.at(sorted_values, f)
    else
      v0 = Enum.at(sorted_values, f)
      v1 = Enum.at(sorted_values, c)
      v0 + (v1 - v0) * (k - f)
    end
  end

  # Z-score based detection
  defp detect_zscore(data_points, values, stats, opts) do
    threshold = Keyword.get(opts, :threshold, @zscore_threshold)

    if stats.std == 0 do
      []
    else
      data_points
      |> Enum.zip(values)
      |> Enum.with_index()
      |> Enum.filter(fn {{_dp, v}, _idx} ->
        zscore = abs(v - stats.mean) / stats.std
        zscore > threshold
      end)
      |> Enum.map(fn {{dp, v}, idx} ->
        zscore = Float.round(abs(v - stats.mean) / stats.std, 3)

        %{
          index: idx,
          value: v,
          data_point: dp,
          method: :zscore,
          score: zscore,
          threshold: threshold
        }
      end)
    end
  end

  # IQR-based detection (Tukey's fences)
  defp detect_iqr(data_points, values, stats, opts) do
    multiplier = Keyword.get(opts, :iqr_multiplier, @iqr_multiplier)

    lower_fence = stats.q1 - multiplier * stats.iqr
    upper_fence = stats.q3 + multiplier * stats.iqr

    data_points
    |> Enum.zip(values)
    |> Enum.with_index()
    |> Enum.filter(fn {{_dp, v}, _idx} ->
      v < lower_fence or v > upper_fence
    end)
    |> Enum.map(fn {{dp, v}, idx} ->
      distance =
        if v < lower_fence,
          do: lower_fence - v,
          else: v - upper_fence

      %{
        index: idx,
        value: v,
        data_point: dp,
        method: :iqr,
        score: Float.round(distance / stats.iqr, 3),
        lower_fence: Float.round(lower_fence, 4),
        upper_fence: Float.round(upper_fence, 4)
      }
    end)
  end

  # Simplified Isolation Forest (path length approximation)
  defp detect_isolation(data_points, values, opts) do
    threshold = Keyword.get(opts, :isolation_threshold, @isolation_threshold)

    # Compute isolation scores (simplified)
    scores = compute_isolation_scores(values)

    data_points
    |> Enum.zip(scores)
    |> Enum.with_index()
    |> Enum.filter(fn {{_dp, score}, _idx} -> score > threshold end)
    |> Enum.map(fn {{dp, score}, idx} ->
      %{
        index: idx,
        value: extract_value(dp),
        data_point: dp,
        method: :isolation,
        score: Float.round(score, 3),
        threshold: threshold
      }
    end)
  end

  defp compute_isolation_scores(values) do
    stats = compute_statistics(values)

    # Simplified isolation score based on distance from distribution
    Enum.map(values, fn v ->
      if stats.std == 0 do
        0.0
      else
        # Higher score = more isolated/anomalous
        zscore = abs(v - stats.mean) / stats.std

        # Convert zscore to 0-1 score (sigmoid-like)
        1 - 1 / (1 + :math.exp(zscore - 2))
      end
    end)
  end

  # Ensemble method: combines all detection methods
  defp detect_ensemble(data_points, values, stats, opts) do
    zscore_anomalies = detect_zscore(data_points, values, stats, opts)
    iqr_anomalies = detect_iqr(data_points, values, stats, opts)
    isolation_anomalies = detect_isolation(data_points, values, opts)

    # Combine and score by method agreement
    all_indices =
      (zscore_anomalies ++ iqr_anomalies ++ isolation_anomalies)
      |> Enum.group_by(& &1.index)

    all_indices
    |> Enum.filter(fn {_idx, detections} ->
      # Require at least 2 methods to agree
      length(Enum.uniq_by(detections, & &1.method)) >= 2
    end)
    |> Enum.map(fn {idx, detections} ->
      methods = detections |> Enum.map(& &1.method) |> Enum.uniq()
      scores = detections |> Enum.map(& &1.score)
      avg_score = Enum.sum(scores) / length(detections)

      first = hd(detections)

      %{
        index: idx,
        value: first.value,
        data_point: first.data_point,
        method: :ensemble,
        methods_agreed: methods,
        score: Float.round(avg_score, 3),
        confidence: length(methods) / 3
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp realtime_check(value, baseline_stats) do
    if baseline_stats.std == 0 do
      {:ok, %{is_anomaly: false, reason: "insufficient_baseline"}}
    else
      zscore = abs(value - baseline_stats.mean) / baseline_stats.std

      if zscore > @zscore_threshold do
        {:ok,
         %{
           is_anomaly: true,
           zscore: Float.round(zscore, 3),
           threshold: @zscore_threshold,
           deviation: Float.round((value - baseline_stats.mean) / baseline_stats.mean * 100, 2)
         }}
      else
        {:ok,
         %{
           is_anomaly: false,
           zscore: Float.round(zscore, 3),
           within_bounds: true
         }}
      end
    end
  end

  defp extract_value(%{value: v}), do: v
  defp extract_value(v) when is_number(v), do: v

  defp emit_telemetry(operation, latency_us, data_points, anomalies) do
    :telemetry.execute(
      [:indrajaal, :ml, :anomaly_detector, operation],
      %{latency_us: latency_us, data_points: data_points, anomalies_found: anomalies},
      %{model: "anomaly_detector", version: "1.0.0"}
    )
  end
end
