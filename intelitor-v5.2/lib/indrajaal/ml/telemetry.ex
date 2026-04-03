defmodule Indrajaal.ML.Telemetry do
  @moduledoc """
  Telemetry handler for ML inference metrics.

  Tracks:
  - Inference latency by model
  - Batch sizes and throughput
  - Model accuracy metrics
  - Resource utilization

  STAMP Compliance:
  - SC-OBS-069: ML inference observability
  - SC-ML-005: Model performance monitoring
  """

  use GenServer

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  @ml_events [
    # Threat Classifier
    [:indrajaal, :ml, :threat_classifier, :classify],
    [:indrajaal, :ml, :threat_classifier, :classify_batch],

    # Anomaly Detector
    [:indrajaal, :ml, :anomaly_detector, :detect],
    [:indrajaal, :ml, :anomaly_detector, :detect_batch],

    # Alarm Correlator
    [:indrajaal, :ml, :alarm_correlator, :correlate],
    [:indrajaal, :ml, :alarm_correlator, :cluster],

    # Model Registry
    [:indrajaal, :ml, :model_registry, :activate],
    [:indrajaal, :ml, :model_registry, :rollback]
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Attach all ML telemetry handlers.
  """
  def attach do
    :telemetry.attach_many(
      "indrajaal-ml-telemetry",
      @ml_events,
      &handle_event/4,
      nil
    )
  end

  @doc """
  Detach ML telemetry handlers.
  """
  def detach do
    :telemetry.detach("indrajaal-ml-telemetry")
  end

  @doc """
  Get aggregated ML metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("📊 ML.Telemetry: Initializing ML telemetry handlers")

    # Attach handlers
    attach()

    state = %{
      metrics: %{
        threat_classifier: %{
          total_inferences: 0,
          total_latency_us: 0,
          by_level: %{critical: 0, high: 0, medium: 0, low: 0, benign: 0}
        },
        anomaly_detector: %{
          total_detections: 0,
          total_latency_us: 0,
          anomalies_found: 0,
          data_points_analyzed: 0
        },
        alarm_correlator: %{
          total_correlations: 0,
          total_latency_us: 0,
          clusters_created: 0
        }
      },
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    uptime_seconds = DateTime.diff(DateTime.utc_now(), state.started_at, :second)

    metrics_with_rates =
      state.metrics
      |> Enum.map(fn {model, stats} ->
        {model, add_rates(stats, uptime_seconds)}
      end)
      |> Enum.into(%{})

    {:reply, %{metrics: metrics_with_rates, uptime_seconds: uptime_seconds}, state}
  end

  @impl true
  def handle_info({:telemetry_event, event, measurements, metadata}, state) do
    new_metrics = update_metrics(state.metrics, event, measurements, metadata)
    {:noreply, %{state | metrics: new_metrics}}
  end

  ## Telemetry Event Handlers

  def handle_event(
        [:indrajaal, :ml, :threat_classifier, operation],
        measurements,
        metadata,
        _config
      ) do
    latency_us = Map.get(measurements, :latency_us, 0)
    threat_level = Map.get(metadata, :metadata, :unknown)

    Logger.debug(
      "🎯 ThreatClassifier.#{operation}: #{div(latency_us, 1000)}ms, level: #{inspect(threat_level)}"
    )

    Tracer.with_span "ml.threat_classifier.#{operation}", kind: :internal do
      Tracer.set_attributes([
        {"ml.model", "threat_classifier"},
        {"ml.operation", to_string(operation)},
        {"ml.latency_us", latency_us}
      ])
    end

    # Forward to GenServer for aggregation
    send(__MODULE__, {:telemetry_event, [:threat_classifier, operation], measurements, metadata})

    :telemetry.execute(
      [:indrajaal, :ml, :inference, :complete],
      %{latency_us: latency_us},
      %{model: :threat_classifier, operation: operation}
    )
  end

  def handle_event(
        [:indrajaal, :ml, :anomaly_detector, operation],
        measurements,
        metadata,
        _config
      ) do
    latency_us = Map.get(measurements, :latency_us, 0)
    data_points = Map.get(measurements, :data_points, 0)
    anomalies = Map.get(measurements, :anomalies_found, 0)

    Logger.debug(
      "🔍 AnomalyDetector.#{operation}: #{div(latency_us, 1000)}ms, points: #{data_points}, anomalies: #{anomalies}"
    )

    Tracer.with_span "ml.anomaly_detector.#{operation}", kind: :internal do
      Tracer.set_attributes([
        {"ml.model", "anomaly_detector"},
        {"ml.operation", to_string(operation)},
        {"ml.latency_us", latency_us},
        {"ml.data_points", data_points},
        {"ml.anomalies_found", anomalies}
      ])
    end

    send(__MODULE__, {:telemetry_event, [:anomaly_detector, operation], measurements, metadata})

    :telemetry.execute(
      [:indrajaal, :ml, :inference, :complete],
      %{latency_us: latency_us},
      %{model: :anomaly_detector, operation: operation}
    )
  end

  def handle_event(
        [:indrajaal, :ml, :alarm_correlator, operation],
        measurements,
        metadata,
        _config
      ) do
    latency_us = Map.get(measurements, :latency_us, 0)
    result_count = Map.get(measurements, :result_count, 0)

    Logger.debug(
      "🔗 AlarmCorrelator.#{operation}: #{div(latency_us, 1000)}ms, results: #{result_count}"
    )

    Tracer.with_span "ml.alarm_correlator.#{operation}", kind: :internal do
      Tracer.set_attributes([
        {"ml.model", "alarm_correlator"},
        {"ml.operation", to_string(operation)},
        {"ml.latency_us", latency_us},
        {"ml.result_count", result_count}
      ])
    end

    send(__MODULE__, {:telemetry_event, [:alarm_correlator, operation], measurements, metadata})

    :telemetry.execute(
      [:indrajaal, :ml, :inference, :complete],
      %{latency_us: latency_us},
      %{model: :alarm_correlator, operation: operation}
    )
  end

  def handle_event(
        [:indrajaal, :ml, :model_registry, operation],
        _measurements,
        metadata,
        _config
      ) do
    model = Map.get(metadata, :model, "unknown")
    version = Map.get(metadata, :version, "unknown")

    Logger.info("📦 ModelRegistry.#{operation}: #{model} v#{version}")

    Tracer.with_span "ml.model_registry.#{operation}", kind: :internal do
      Tracer.set_attributes([
        {"ml.registry.operation", to_string(operation)},
        {"ml.model", model},
        {"ml.version", version}
      ])
    end
  end

  # Catch-all for unhandled events
  def handle_event(event, measurements, _metadata, _config) do
    Logger.debug("ML Telemetry event: #{inspect(event)}, measurements: #{inspect(measurements)}")
    :ok
  end

  ## Private Functions

  defp update_metrics(metrics, [:threat_classifier, _operation], measurements, metadata) do
    latency_us = Map.get(measurements, :latency_us, 0)
    threat_level = Map.get(metadata, :metadata, :unknown)

    tc_metrics = Map.get(metrics, :threat_classifier, %{})

    updated_tc =
      tc_metrics
      |> Map.update(:total_inferences, 1, &(&1 + 1))
      |> Map.update(:total_latency_us, latency_us, &(&1 + latency_us))
      |> update_in([:by_level, threat_level], fn
        nil -> 1
        count -> count + 1
      end)

    Map.put(metrics, :threat_classifier, updated_tc)
  end

  defp update_metrics(metrics, [:anomaly_detector, _operation], measurements, _metadata) do
    latency_us = Map.get(measurements, :latency_us, 0)
    data_points = Map.get(measurements, :data_points, 0)
    anomalies = Map.get(measurements, :anomalies_found, 0)

    ad_metrics = Map.get(metrics, :anomaly_detector, %{})

    updated_ad =
      ad_metrics
      |> Map.update(:total_detections, 1, &(&1 + 1))
      |> Map.update(:total_latency_us, latency_us, &(&1 + latency_us))
      |> Map.update(:data_points_analyzed, data_points, &(&1 + data_points))
      |> Map.update(:anomalies_found, anomalies, &(&1 + anomalies))

    Map.put(metrics, :anomaly_detector, updated_ad)
  end

  defp update_metrics(metrics, [:alarm_correlator, operation], measurements, _metadata) do
    latency_us = Map.get(measurements, :latency_us, 0)
    result_count = Map.get(measurements, :result_count, 0)

    ac_metrics = Map.get(metrics, :alarm_correlator, %{})

    updated_ac =
      ac_metrics
      |> Map.update(:total_correlations, 1, &(&1 + 1))
      |> Map.update(:total_latency_us, latency_us, &(&1 + latency_us))
      |> then(fn m ->
        if operation == :cluster do
          Map.update(m, :clusters_created, result_count, &(&1 + result_count))
        else
          m
        end
      end)

    Map.put(metrics, :alarm_correlator, updated_ac)
  end

  defp update_metrics(metrics, _event, _measurements, _metadata) do
    metrics
  end

  defp add_rates(stats, uptime_seconds) when uptime_seconds > 0 do
    total =
      Map.get(stats, :total_inferences, 0) +
        Map.get(stats, :total_detections, 0) +
        Map.get(stats, :total_correlations, 0)

    total_latency = Map.get(stats, :total_latency_us, 0)

    Map.merge(stats, %{
      inferences_per_second: Float.round(total / uptime_seconds, 2),
      avg_latency_ms: if(total > 0, do: Float.round(total_latency / total / 1000, 2), else: 0.0)
    })
  end

  defp add_rates(stats, _), do: stats
end
