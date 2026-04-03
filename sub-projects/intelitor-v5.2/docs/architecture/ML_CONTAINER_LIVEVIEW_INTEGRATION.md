# ML/AI Container and LiveView Integration Specification

## SIL-6 FLAME-Ready Elastic ML Swarm Architecture

**Version**: 21.3.0-SIL6
**Status**: SPECIFICATION
**Classification**: Container Architecture
**STAMP Compliance**: SC-ML-CNT-001 through SC-ML-CNT-025

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Container Architecture](#2-container-architecture)
3. [FLAME Elastic Scaling](#3-flame-elastic-scaling)
4. [LiveView Integration](#4-liveview-integration)
5. [Zenoh Mesh Integration](#5-zenoh-mesh-integration)
6. [Observability Stack](#6-observability-stack)
7. [Lightweight Image Design](#7-lightweight-image-design)
8. [Build Pipeline](#8-build-pipeline)
9. [Deployment Configuration](#9-deployment-configuration)
10. [Testing Strategy](#10-testing-strategy)
11. [STAMP Constraints](#11-stamp-constraints)
12. [AOR Rules](#12-aor-rules)

---

## 1. Executive Summary

This document specifies the dedicated **indrajaal-ml-prod** container for all AI/ML processing within the Indrajaal system. The container is designed for:

- **SIL-6 Compliance**: Meets biomorphic extended safety level requirements
- **FLAME Ready**: Elastic horizontal scaling for burst ML workloads
- **Lightweight**: Minimal image (~500MB) for fast boot (<10s cold start)
- **Zenoh Native**: First-class mesh network integration for real-time telemetry
- **Full Observability**: OpenTelemetry, Prometheus, and custom ML metrics
- **LiveView Integration**: Real-time ML dashboards and interactive model exploration

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  INDRAJAAL 4-CONTAINER ARCHITECTURE (SIL-6)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │indrajaal-db-prod│  │indrajaal-obs-prod│  │indrajaal-ex-app-1│            │
│  │   PostgreSQL    │  │  OTEL/Grafana   │  │  Phoenix/Web    │              │
│  │   TimescaleDB   │  │  Prometheus     │  │  LiveView       │              │
│  │   Port: 5433    │  │  Port: 4317     │  │  Port: 4000     │              │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘              │
│           │                    │                    │                       │
│           └────────────────────┼────────────────────┘                       │
│                                │                                            │
│                    ┌───────────┴───────────┐                                │
│                    │     Zenoh Mesh        │                                │
│                    │  indrajaal/ml/**      │                                │
│                    └───────────┬───────────┘                                │
│                                │                                            │
│           ┌────────────────────┼────────────────────┐                       │
│           │                    │                    │                       │
│  ┌────────┴────────┐  ┌────────┴────────┐  ┌────────┴────────┐              │
│  │indrajaal-ml-prod│  │ indrajaal-ml-1  │  │ indrajaal-ml-N  │              │
│  │   ML Primary    │  │  FLAME Worker   │  │  FLAME Worker   │              │
│  │  Nx/Axon/EXLA   │◄─┤   (Elastic)     │◄─┤   (Elastic)     │              │
│  │   Port: 4100    │  │  Auto-spawned   │  │  Auto-spawned   │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
│                                                                             │
│  FLAME Pool: 0-50 workers (auto-scaled based on inference queue depth)      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Container Architecture

### 2.1 Container Specifications

| Attribute | Value | Justification |
|-----------|-------|---------------|
| **Name** | indrajaal-ml-prod | Dedicated ML processing |
| **Base Image** | elixir:1.19-erlang-28-alpine | Minimal footprint |
| **Size Target** | < 500MB | Fast pull/boot |
| **Memory Limit** | 8GB default, 32GB max | GPU tensor operations |
| **CPU Limit** | 4 cores default, 16 max | Parallel inference |
| **GPU Access** | nvidia.com/gpu=all | CUDA acceleration |
| **Ports** | 4100 (HTTP), 4101 (gRPC), 7447 (Zenoh) | Multi-protocol |
| **Boot Time** | < 10s cold, < 2s warm | FLAME requirement |

### 2.2 Container Responsibilities

```
┌─────────────────────────────────────────────────────────────────┐
│  indrajaal-ml-prod RESPONSIBILITIES                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INFERENCE ENGINE                                               │
│  ├── Real-time anomaly detection (L2)                          │
│  ├── Batch prediction processing (L2)                          │
│  ├── Holon decision optimization (L3)                          │
│  ├── Container resource prediction (L4)                        │
│  └── Semantic analysis (L7)                                    │
│                                                                 │
│  TRAINING ENGINE                                                │
│  ├── Model training (async, background)                        │
│  ├── Transfer learning                                         │
│  ├── Reinforcement learning (L3)                               │
│  └── Model fine-tuning                                         │
│                                                                 │
│  MODEL SERVING                                                  │
│  ├── Model registry (versioned)                                │
│  ├── A/B testing                                               │
│  ├── Shadow deployment                                         │
│  └── Rollback capability                                       │
│                                                                 │
│  DATA PROCESSING                                                │
│  ├── Feature extraction pipelines                              │
│  ├── Data transformation                                       │
│  ├── Batch aggregation                                         │
│  └── Stream processing (Broadway)                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Internal Architecture

```elixir
defmodule Indrajaal.ML.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Core Services
      {Indrajaal.ML.TensorBackend, []},
      {Indrajaal.ML.ModelRegistry, []},

      # Inference Engine
      {Indrajaal.ML.InferenceEngine, []},
      {Indrajaal.ML.BatchProcessor, []},

      # Training Engine
      {Indrajaal.ML.TrainingCoordinator, []},

      # Networking
      {Indrajaal.ML.ZenohBridge, []},
      {Indrajaal.ML.GrpcServer, port: 4101},

      # FLAME Pool
      {FLAME.Pool, name: Indrajaal.ML.FlamePool, min: 0, max: 50, idle_shutdown_after: :timer.minutes(5)},

      # Telemetry
      {Indrajaal.ML.TelemetryReporter, []},

      # HTTP API
      {Bandit, plug: Indrajaal.ML.Router, scheme: :http, port: 4100}
    ]

    opts = [strategy: :one_for_one, name: Indrajaal.ML.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## 3. FLAME Elastic Scaling

### 3.1 FLAME Configuration

```elixir
# config/runtime.exs
config :flame,
  backend: FLAME.PodmanBackend,
  min: 0,
  max: 50,
  max_concurrency: 10,
  idle_shutdown_after: :timer.minutes(5),
  boot_timeout: :timer.seconds(30),
  shutdown_timeout: :timer.seconds(60)

config :flame, FLAME.PodmanBackend,
  image: "localhost/indrajaal-ml-prod:latest",
  cpus: "4",
  memory: "8g",
  gpus: "all",
  network: "indrajaal-mesh",
  env: [
    {"EXLA_TARGET", "cuda"},
    {"MIX_ENV", "prod"},
    {"PHX_SERVER", "false"},
    {"FLAME_WORKER", "true"}
  ]
```

### 3.2 FLAME Pool Implementation

```elixir
defmodule Indrajaal.ML.FlamePool do
  @moduledoc """
  FLAME pool for elastic ML worker scaling.
  Workers are spawned on-demand and released after idle timeout.
  """

  use FLAME.Pool,
    name: __MODULE__,
    min: 0,
    max: 50,
    max_concurrency: 10,
    idle_shutdown_after: :timer.minutes(5)

  @doc """
  Execute ML inference in FLAME worker.
  Automatically scales based on queue depth.
  """
  def infer(model_id, features) do
    FLAME.call(__MODULE__, fn ->
      model = Indrajaal.ML.ModelRegistry.get(model_id)
      Axon.predict(model.module, model.state, features)
    end)
  end

  @doc """
  Execute batch inference with automatic chunking.
  """
  def batch_infer(model_id, features_list, chunk_size \\ 100) do
    features_list
    |> Enum.chunk_every(chunk_size)
    |> FLAME.map(__MODULE__, fn chunk ->
      model = Indrajaal.ML.ModelRegistry.get(model_id)
      batch = Nx.stack(chunk)
      Axon.predict(model.module, model.state, batch)
    end)
    |> Enum.flat_map(&Nx.to_list/1)
  end

  @doc """
  Execute training job in dedicated FLAME worker.
  """
  def train(model_config, training_data, opts \\ []) do
    FLAME.call(__MODULE__, fn ->
      model = build_model(model_config)
      train_model(model, training_data, opts)
    end, timeout: :timer.hours(24))
  end
end
```

### 3.3 Auto-Scaling Logic

```elixir
defmodule Indrajaal.ML.AutoScaler do
  use GenServer

  @check_interval :timer.seconds(10)
  @scale_up_threshold 0.7    # Queue depth > 70% capacity
  @scale_down_threshold 0.3  # Queue depth < 30% capacity

  def init(_) do
    schedule_check()
    {:ok, %{current_workers: 0, target_workers: 0}}
  end

  def handle_info(:check_scale, state) do
    metrics = get_scaling_metrics()

    target = calculate_target_workers(metrics)
    new_state = %{state | target_workers: target}

    if target > state.current_workers do
      scale_up(target - state.current_workers)
    else if target < state.current_workers do
      # Let idle shutdown handle scale down
      :ok
    end

    schedule_check()
    {:noreply, new_state}
  end

  defp get_scaling_metrics do
    %{
      queue_depth: InferenceEngine.queue_depth(),
      avg_latency: TelemetryReporter.avg_inference_latency(),
      active_workers: FLAME.Pool.info(__MODULE__).active,
      gpu_utilization: get_gpu_utilization()
    }
  end

  defp calculate_target_workers(metrics) do
    base = div(metrics.queue_depth, 100)  # 100 items per worker
    latency_factor = if metrics.avg_latency > 100, do: 1.5, else: 1.0
    gpu_factor = if metrics.gpu_utilization > 0.9, do: 1.2, else: 1.0

    min(50, trunc(base * latency_factor * gpu_factor))
  end
end
```

---

## 4. LiveView Integration

### 4.1 Real-Time ML Dashboard

```elixir
defmodule IndrajaalWeb.ML.DashboardLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to ML telemetry
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "ml:metrics")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "ml:predictions")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "ml:health")

      # Poll every 5 seconds
      :timer.send_interval(5000, self(), :update_metrics)
    end

    {:ok, assign(socket,
      metrics: initial_metrics(),
      predictions: [],
      health: %{},
      flame_workers: 0,
      model_versions: %{}
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ml-dashboard">
      <!-- Header with Real-Time Status -->
      <.ml_header
        workers={@flame_workers}
        health={@health}
        queue_depth={@metrics.queue_depth}
      />

      <!-- Main Grid -->
      <div class="grid grid-cols-3 gap-4 mt-4">
        <!-- Inference Metrics -->
        <.card title="Inference Performance">
          <.live_chart
            id="inference-latency"
            type="line"
            data={@metrics.latency_history}
            ylabel="Latency (ms)"
          />
          <div class="mt-2 grid grid-cols-2 gap-2">
            <.metric_box label="P50" value={@metrics.p50_latency} unit="ms" />
            <.metric_box label="P99" value={@metrics.p99_latency} unit="ms" />
            <.metric_box label="Throughput" value={@metrics.throughput} unit="req/s" />
            <.metric_box label="Queue" value={@metrics.queue_depth} unit="items" />
          </div>
        </.card>

        <!-- Model Health -->
        <.card title="Model Health">
          <div class="space-y-2">
            <%= for {model_id, status} <- @model_versions do %>
              <.model_status_row
                model_id={model_id}
                status={status}
                accuracy={status.accuracy}
                drift={status.drift_score}
              />
            <% end %>
          </div>
        </.card>

        <!-- FLAME Workers -->
        <.card title="FLAME Pool">
          <.live_chart
            id="flame-workers"
            type="area"
            data={@metrics.worker_history}
            ylabel="Workers"
          />
          <div class="mt-2 flex justify-between">
            <span>Active: {@flame_workers}</span>
            <span>Max: 50</span>
          </div>
          <.progress_bar value={@flame_workers} max={50} />
        </.card>
      </div>

      <!-- Recent Predictions Stream -->
      <.card title="Recent Predictions" class="mt-4">
        <.live_table
          id="predictions-table"
          rows={@predictions}
          row_click="show_prediction_detail"
        >
          <:col :let={pred} label="Time">{format_time(pred.timestamp)}</:col>
          <:col :let={pred} label="Model">{pred.model_id}</:col>
          <:col :let={pred} label="Input">{truncate(pred.input, 50)}</:col>
          <:col :let={pred} label="Output">{format_prediction(pred.output)}</:col>
          <:col :let={pred} label="Confidence">{format_confidence(pred.confidence)}</:col>
          <:col :let={pred} label="Latency">{pred.latency_ms}ms</:col>
        </.live_table>
      </.card>

      <!-- GPU Utilization -->
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.card title="GPU Utilization">
          <.gpu_metrics metrics={@metrics.gpu} />
        </.card>

        <.card title="Memory Usage">
          <.memory_breakdown
            tensor_memory={@metrics.tensor_memory}
            model_memory={@metrics.model_memory}
            cache_memory={@metrics.cache_memory}
          />
        </.card>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    metrics = Indrajaal.ML.TelemetryReporter.get_dashboard_metrics()
    flame_info = FLAME.Pool.info(Indrajaal.ML.FlamePool)

    {:noreply, assign(socket,
      metrics: metrics,
      flame_workers: flame_info.active
    )}
  end

  @impl true
  def handle_info({:ml_prediction, prediction}, socket) do
    predictions = [prediction | Enum.take(socket.assigns.predictions, 99)]
    {:noreply, assign(socket, predictions: predictions)}
  end
end
```

### 4.2 Interactive Model Explorer

```elixir
defmodule IndrajaalWeb.ML.ModelExplorerLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(%{"model_id" => model_id}, _session, socket) do
    model = Indrajaal.ML.ModelRegistry.get(model_id)

    {:ok, assign(socket,
      model: model,
      input_form: %{},
      prediction_result: nil,
      explanation: nil,
      history: []
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="model-explorer">
      <h1 class="text-2xl font-bold">{@model.name}</h1>
      <p class="text-gray-600">{@model.description}</p>

      <!-- Model Architecture Visualization -->
      <.card title="Model Architecture" class="mt-4">
        <.axon_graph model={@model.module} />
      </.card>

      <!-- Interactive Prediction -->
      <.card title="Try Prediction" class="mt-4">
        <.form for={@input_form} phx-submit="predict" phx-change="validate_input">
          <div class="grid grid-cols-2 gap-4">
            <%= for field <- @model.input_schema do %>
              <.input
                field={field.name}
                type={field.type}
                label={field.label}
                placeholder={field.placeholder}
              />
            <% end %>
          </div>
          <.button type="submit" class="mt-4">Run Prediction</.button>
        </.form>

        <%= if @prediction_result do %>
          <div class="mt-4 p-4 bg-blue-50 rounded">
            <h3 class="font-bold">Result</h3>
            <.prediction_visualization result={@prediction_result} />

            <%= if @explanation do %>
              <h4 class="font-bold mt-4">Explanation (SHAP)</h4>
              <.feature_importance explanation={@explanation} />
            <% end %>
          </div>
        <% end %>
      </.card>

      <!-- Prediction History -->
      <.card title="Your Predictions" class="mt-4">
        <.live_table rows={@history}>
          <:col :let={h} label="Input">{inspect(h.input)}</:col>
          <:col :let={h} label="Output">{inspect(h.output)}</:col>
          <:col :let={h} label="Time">{h.timestamp}</:col>
        </.live_table>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_event("predict", %{"input" => input}, socket) do
    features = encode_input(input, socket.assigns.model.input_schema)

    # Run prediction via FLAME
    result = Indrajaal.ML.FlamePool.infer(socket.assigns.model.id, features)

    # Generate explanation
    explanation = Indrajaal.ML.Explainer.shap(
      socket.assigns.model,
      features,
      result
    )

    history_entry = %{
      input: input,
      output: result,
      timestamp: DateTime.utc_now()
    }

    {:noreply, assign(socket,
      prediction_result: result,
      explanation: explanation,
      history: [history_entry | socket.assigns.history]
    )}
  end
end
```

### 4.3 Training Monitor LiveView

```elixir
defmodule IndrajaalWeb.ML.TrainingMonitorLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(%{"job_id" => job_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "training:#{job_id}")
    end

    job = Indrajaal.ML.TrainingCoordinator.get_job(job_id)

    {:ok, assign(socket,
      job: job,
      metrics: [],
      current_epoch: 0,
      loss_history: [],
      accuracy_history: []
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="training-monitor">
      <.header>
        Training: {@job.model_name}
        <:actions>
          <.button phx-click="pause" disabled={@job.status != :running}>Pause</.button>
          <.button phx-click="stop" variant="danger">Stop</.button>
        </:actions>
      </.header>

      <!-- Progress -->
      <.card class="mt-4">
        <div class="flex justify-between mb-2">
          <span>Epoch {@current_epoch} / {@job.total_epochs}</span>
          <span>{trunc(@current_epoch / @job.total_epochs * 100)}%</span>
        </div>
        <.progress_bar value={@current_epoch} max={@job.total_epochs} />
      </.card>

      <!-- Live Metrics Charts -->
      <div class="grid grid-cols-2 gap-4 mt-4">
        <.card title="Loss">
          <.live_chart
            id="loss-chart"
            type="line"
            data={@loss_history}
            ylabel="Loss"
            xlabel="Epoch"
          />
        </.card>

        <.card title="Accuracy">
          <.live_chart
            id="accuracy-chart"
            type="line"
            data={@accuracy_history}
            ylabel="Accuracy"
            xlabel="Epoch"
          />
        </.card>
      </div>

      <!-- GPU Stats -->
      <.card title="Resource Usage" class="mt-4">
        <div class="grid grid-cols-4 gap-4">
          <.metric_box label="GPU Memory" value={@job.gpu_memory_gb} unit="GB" />
          <.metric_box label="GPU Util" value={@job.gpu_utilization} unit="%" />
          <.metric_box label="Batch/sec" value={@job.batches_per_second} unit="" />
          <.metric_box label="ETA" value={format_eta(@job.eta_seconds)} unit="" />
        </div>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_info({:training_update, update}, socket) do
    {:noreply, assign(socket,
      current_epoch: update.epoch,
      loss_history: socket.assigns.loss_history ++ [{update.epoch, update.loss}],
      accuracy_history: socket.assigns.accuracy_history ++ [{update.epoch, update.accuracy}],
      job: Map.merge(socket.assigns.job, update.job_stats)
    )}
  end
end
```

### 4.4 Anomaly Detection Dashboard

```elixir
defmodule IndrajaalWeb.ML.AnomalyDashboardLive do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "ml:anomalies")
      :timer.send_interval(5000, self(), :update_stats)
    end

    {:ok, assign(socket,
      anomalies: [],
      stats: initial_stats(),
      filters: %{severity: :all, timeframe: :hour}
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="anomaly-dashboard">
      <.header>
        Anomaly Detection
        <:actions>
          <.filter_dropdown
            name="severity"
            options={[:all, :critical, :high, :medium, :low]}
            selected={@filters.severity}
          />
          <.filter_dropdown
            name="timeframe"
            options={[:hour, :day, :week]}
            selected={@filters.timeframe}
          />
        </:actions>
      </.header>

      <!-- Stats Overview -->
      <div class="grid grid-cols-4 gap-4 mt-4">
        <.stat_card
          title="Total Anomalies"
          value={@stats.total}
          trend={@stats.total_trend}
          icon="exclamation-triangle"
        />
        <.stat_card
          title="Critical"
          value={@stats.critical}
          variant="danger"
          icon="fire"
        />
        <.stat_card
          title="Detection Rate"
          value={"#{@stats.detection_rate}%"}
          icon="chart-line"
        />
        <.stat_card
          title="Avg Response"
          value={"#{@stats.avg_response_ms}ms"}
          icon="clock"
        />
      </div>

      <!-- Anomaly Timeline -->
      <.card title="Anomaly Timeline" class="mt-4">
        <.live_chart
          id="anomaly-timeline"
          type="scatter"
          data={@anomalies}
          x="timestamp"
          y="score"
          color="severity"
        />
      </.card>

      <!-- Live Anomaly Feed -->
      <.card title="Live Feed" class="mt-4">
        <div class="space-y-2 max-h-96 overflow-y-auto">
          <%= for anomaly <- @anomalies do %>
            <.anomaly_card
              anomaly={anomaly}
              phx-click="show_detail"
              phx-value-id={anomaly.id}
            />
          <% end %>
        </div>
      </.card>
    </div>
    """
  end

  @impl true
  def handle_info({:anomaly_detected, anomaly}, socket) do
    anomalies = [anomaly | Enum.take(socket.assigns.anomalies, 199)]
    {:noreply, assign(socket, anomalies: anomalies)}
  end
end
```

---

## 5. Zenoh Mesh Integration

### 5.1 ML Topics

```yaml
# Zenoh key expressions for ML
indrajaal/ml/:
  inference/:
    request: "indrajaal/ml/inference/request/{model_id}"
    response: "indrajaal/ml/inference/response/{request_id}"
    batch: "indrajaal/ml/inference/batch/{batch_id}"

  training/:
    start: "indrajaal/ml/training/start/{job_id}"
    progress: "indrajaal/ml/training/progress/{job_id}"
    complete: "indrajaal/ml/training/complete/{job_id}"

  metrics/:
    latency: "indrajaal/ml/metrics/latency"
    throughput: "indrajaal/ml/metrics/throughput"
    gpu: "indrajaal/ml/metrics/gpu"
    memory: "indrajaal/ml/metrics/memory"

  models/:
    deployed: "indrajaal/ml/models/deployed"
    health: "indrajaal/ml/models/health/{model_id}"

  anomalies/:
    detected: "indrajaal/ml/anomalies/detected"
    classified: "indrajaal/ml/anomalies/classified/{severity}"

  flame/:
    workers: "indrajaal/ml/flame/workers"
    scaling: "indrajaal/ml/flame/scaling"
```

### 5.2 Zenoh Bridge Implementation

```elixir
defmodule Indrajaal.ML.ZenohBridge do
  use GenServer
  require Logger

  @publish_interval 1000  # 1 second

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Connect to Zenoh router
    {:ok, session} = Zenoh.open(connect: ["tcp/localhost:7447"])

    # Subscribe to inference requests
    {:ok, _sub} = Zenoh.subscribe(session, "indrajaal/ml/inference/request/**")

    # Start metrics publisher
    schedule_publish()

    {:ok, %{session: session}}
  end

  # Publish ML metrics
  def handle_info(:publish_metrics, %{session: session} = state) do
    metrics = collect_metrics()

    Zenoh.put(session, "indrajaal/ml/metrics/latency", encode_metric(metrics.latency))
    Zenoh.put(session, "indrajaal/ml/metrics/throughput", encode_metric(metrics.throughput))
    Zenoh.put(session, "indrajaal/ml/metrics/gpu", encode_metric(metrics.gpu))

    schedule_publish()
    {:noreply, state}
  end

  # Handle inference request from mesh
  def handle_info({:zenoh, "indrajaal/ml/inference/request/" <> model_id, payload}, state) do
    request = decode_request(payload)

    # Execute inference in FLAME pool
    Task.start(fn ->
      result = Indrajaal.ML.FlamePool.infer(model_id, request.features)

      # Publish response back to mesh
      response_key = "indrajaal/ml/inference/response/#{request.id}"
      Zenoh.put(state.session, response_key, encode_response(result))
    end)

    {:noreply, state}
  end

  # Publish anomaly detection
  def publish_anomaly(anomaly) do
    GenServer.cast(__MODULE__, {:publish_anomaly, anomaly})
  end

  def handle_cast({:publish_anomaly, anomaly}, %{session: session} = state) do
    Zenoh.put(session, "indrajaal/ml/anomalies/detected", encode_anomaly(anomaly))
    Zenoh.put(session, "indrajaal/ml/anomalies/classified/#{anomaly.severity}", encode_anomaly(anomaly))
    {:noreply, state}
  end

  defp collect_metrics do
    %{
      latency: Indrajaal.ML.TelemetryReporter.get_latency_stats(),
      throughput: Indrajaal.ML.TelemetryReporter.get_throughput(),
      gpu: get_gpu_metrics(),
      flame: FLAME.Pool.info(Indrajaal.ML.FlamePool)
    }
  end
end
```

---

## 6. Observability Stack

### 6.1 OpenTelemetry Integration

```elixir
defmodule Indrajaal.ML.TelemetrySetup do
  def setup do
    # Attach telemetry handlers
    :telemetry.attach_many(
      "ml-metrics",
      [
        [:indrajaal, :ml, :inference, :start],
        [:indrajaal, :ml, :inference, :stop],
        [:indrajaal, :ml, :training, :epoch],
        [:indrajaal, :ml, :model, :loaded],
        [:indrajaal, :ml, :flame, :worker_spawned],
        [:indrajaal, :ml, :flame, :worker_terminated]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:indrajaal, :ml, :inference, :stop], measurements, metadata, _config) do
    # Record to OpenTelemetry
    :otel_counter.add(:ml_inference_total, 1, metadata)
    :otel_histogram.record(:ml_inference_duration_ms, measurements.duration / 1_000_000, metadata)

    # Record to Prometheus
    :prometheus_counter.inc(:ml_inference_total, [metadata.model_id])
    :prometheus_histogram.observe(:ml_inference_duration_ms, [metadata.model_id], measurements.duration / 1_000_000)

    # Publish to LiveView
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "ml:metrics", {:inference_complete, measurements, metadata})
  end

  def handle_event([:indrajaal, :ml, :flame, :worker_spawned], _measurements, metadata, _config) do
    :otel_counter.add(:ml_flame_workers_spawned, 1, metadata)

    # Publish to LiveView
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "ml:flame", {:worker_spawned, metadata})
  end
end
```

### 6.2 Prometheus Metrics

```elixir
defmodule Indrajaal.ML.PrometheusMetrics do
  use Prometheus.Metric

  def setup do
    # Counters
    Counter.declare(
      name: :ml_inference_total,
      labels: [:model_id],
      help: "Total number of ML inferences"
    )

    Counter.declare(
      name: :ml_training_epochs_total,
      labels: [:job_id, :model_id],
      help: "Total training epochs completed"
    )

    # Histograms
    Histogram.declare(
      name: :ml_inference_duration_ms,
      labels: [:model_id],
      buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000],
      help: "Inference duration in milliseconds"
    )

    # Gauges
    Gauge.declare(
      name: :ml_flame_active_workers,
      help: "Current number of active FLAME workers"
    )

    Gauge.declare(
      name: :ml_gpu_memory_usage_bytes,
      help: "GPU memory usage in bytes"
    )

    Gauge.declare(
      name: :ml_inference_queue_depth,
      help: "Current inference queue depth"
    )

    Gauge.declare(
      name: :ml_model_accuracy,
      labels: [:model_id],
      help: "Current model accuracy"
    )
  end
end
```

### 6.3 Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Indrajaal ML Operations",
    "panels": [
      {
        "title": "Inference Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, rate(ml_inference_duration_ms_bucket[5m]))",
            "legendFormat": "p99"
          },
          {
            "expr": "histogram_quantile(0.50, rate(ml_inference_duration_ms_bucket[5m]))",
            "legendFormat": "p50"
          }
        ]
      },
      {
        "title": "FLAME Workers",
        "type": "graph",
        "targets": [
          {
            "expr": "ml_flame_active_workers",
            "legendFormat": "Active Workers"
          }
        ]
      },
      {
        "title": "GPU Utilization",
        "type": "gauge",
        "targets": [
          {
            "expr": "ml_gpu_utilization_percent",
            "legendFormat": "GPU %"
          }
        ]
      },
      {
        "title": "Model Accuracy",
        "type": "stat",
        "targets": [
          {
            "expr": "ml_model_accuracy",
            "legendFormat": "{{model_id}}"
          }
        ]
      }
    ]
  }
}
```

---

## 7. Lightweight Image Design

### 7.1 Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build
FROM elixir:1.19-erlang-28-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    npm \
    python3

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy mix files first for dependency caching
COPY mix.exs mix.lock ./
COPY apps/indrajaal_ml/mix.exs apps/indrajaal_ml/

ENV MIX_ENV=prod

# Install dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY apps/indrajaal_ml apps/indrajaal_ml
COPY config config

# Compile application
RUN mix compile

# Build release
RUN mix release indrajaal_ml

# Stage 2: Runtime (Minimal)
FROM alpine:3.19 AS runtime

# Install minimal runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    libgcc

# Create non-root user
RUN addgroup -g 1000 indrajaal && \
    adduser -u 1000 -G indrajaal -s /bin/sh -D indrajaal

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/indrajaal_ml ./

# Copy entrypoint
COPY docker/ml/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set ownership
RUN chown -R indrajaal:indrajaal /app

USER indrajaal

# Expose ports
EXPOSE 4100 4101 7447

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
  CMD wget -q -O /dev/null http://localhost:4100/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
```

### 7.2 GPU-Enabled Image

```dockerfile
# Stage 1: Build (same as above)
FROM elixir:1.19-erlang-28-alpine AS builder
# ... (same build steps)

# Stage 2: Runtime with CUDA
FROM nvidia/cuda:12.3-runtime-ubuntu22.04 AS runtime-gpu

# Install minimal runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libncurses6 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Erlang runtime only (no dev tools)
RUN wget -q https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
    dpkg -i erlang-solutions_2.0_all.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends esl-erlang && \
    rm -rf /var/lib/apt/lists/* erlang-solutions_2.0_all.deb

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/indrajaal_ml ./

# NVIDIA runtime configuration
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV EXLA_TARGET=cuda

EXPOSE 4100 4101 7447

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
  CMD wget -q -O /dev/null http://localhost:4100/health || exit 1

CMD ["bin/indrajaal_ml", "start"]
```

### 7.3 Image Size Optimization

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| Base image | 1.2GB | 180MB | 85% |
| Erlang/OTP | 500MB | 80MB | 84% |
| Dependencies | 300MB | 150MB | 50% |
| Application | 100MB | 80MB | 20% |
| **Total** | **2.1GB** | **490MB** | **77%** |

### 7.4 Boot Time Optimization

```elixir
# rel/env.sh.eex
#!/bin/sh

# Pre-warm BEAM
export ELIXIR_ERL_OPTIONS="+S 4:4 +sbwt very_short +swt very_low"

# Disable unnecessary features
export ERL_CRASH_DUMP_BYTES=0

# Fast startup
export ERL_DIST_PORT_MIN=9000
export ERL_DIST_PORT_MAX=9005

# Nx/EXLA optimization
export XLA_FLAGS="--xla_gpu_cuda_data_dir=/usr/local/cuda"
export EXLA_CACHE_DIR=/app/data/exla_cache
```

---

## 8. Build Pipeline

### 8.1 CI/CD Configuration

```yaml
# .github/workflows/ml-container.yml
name: ML Container Build

on:
  push:
    paths:
      - 'apps/indrajaal_ml/**'
      - 'docker/ml/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and test
        run: |
          docker buildx build \
            --target builder \
            --cache-from type=gha \
            --cache-to type=gha,mode=max \
            -f docker/ml/Dockerfile \
            -t indrajaal-ml-test .

          # Run tests in container
          docker run --rm indrajaal-ml-test mix test

      - name: Build release image
        run: |
          docker buildx build \
            --target runtime \
            --cache-from type=gha \
            -f docker/ml/Dockerfile \
            -t localhost/indrajaal-ml-prod:${{ github.sha }} \
            -t localhost/indrajaal-ml-prod:latest \
            --push .

      - name: Verify image size
        run: |
          SIZE=$(docker image inspect localhost/indrajaal-ml-prod:latest --format='{{.Size}}')
          MAX_SIZE=524288000  # 500MB
          if [ "$SIZE" -gt "$MAX_SIZE" ]; then
            echo "Image too large: $SIZE bytes"
            exit 1
          fi

      - name: Test boot time
        run: |
          START=$(date +%s%3N)
          docker run -d --name ml-test localhost/indrajaal-ml-prod:latest
          while ! docker exec ml-test wget -q -O /dev/null http://localhost:4100/health 2>/dev/null; do
            sleep 0.1
          done
          END=$(date +%s%3N)
          BOOT_TIME=$((END - START))
          echo "Boot time: ${BOOT_TIME}ms"
          if [ "$BOOT_TIME" -gt 10000 ]; then
            echo "Boot time too slow"
            exit 1
          fi
          docker rm -f ml-test
```

### 8.2 Local Build Script

```bash
#!/bin/bash
# scripts/build-ml-container.sh

set -e

IMAGE_NAME="localhost/indrajaal-ml-prod"
VERSION="${1:-latest}"

echo "Building ML container v${VERSION}..."

# Build with buildah/podman for rootless
podman build \
  --target runtime \
  -f docker/ml/Dockerfile \
  -t "${IMAGE_NAME}:${VERSION}" \
  -t "${IMAGE_NAME}:latest" \
  .

# Verify size
SIZE=$(podman image inspect "${IMAGE_NAME}:latest" --format='{{.Size}}')
echo "Image size: $((SIZE / 1024 / 1024))MB"

# Verify boot time
echo "Testing boot time..."
podman run -d --name ml-test "${IMAGE_NAME}:latest"
START=$(date +%s%3N)
while ! podman exec ml-test wget -q -O /dev/null http://localhost:4100/health 2>/dev/null; do
  sleep 0.1
done
END=$(date +%s%3N)
BOOT_TIME=$((END - START))
echo "Boot time: ${BOOT_TIME}ms"
podman rm -f ml-test

echo "Build complete!"
```

---

## 9. Deployment Configuration

### 9.1 Podman Compose

```yaml
# lib/cepaf/artifacts/podman-compose-ml-standalone.yml
version: "3.8"

services:
  indrajaal-ml-prod:
    image: localhost/indrajaal-ml-prod:latest
    container_name: indrajaal-ml-prod
    hostname: ml-primary
    ports:
      - "4100:4100"   # HTTP API
      - "4101:4101"   # gRPC
      - "7447:7447"   # Zenoh
    environment:
      - MIX_ENV=prod
      - EXLA_TARGET=cuda
      - FLAME_BACKEND=podman
      - FLAME_PARENT=indrajaal-ml-prod
      - ZENOH_ROUTER=tcp/zenoh-router:7447
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs-prod:4317
      - DATABASE_URL=postgresql://indrajaal:indrajaal@indrajaal-db-prod:5432/indrajaal_ml
    volumes:
      - ml-models:/app/data/models
      - ml-cache:/app/data/exla_cache
      - /run/podman/podman.sock:/run/podman/podman.sock:ro  # For FLAME
    deploy:
      resources:
        limits:
          cpus: "8"
          memory: 16G
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    networks:
      - indrajaal-mesh
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://localhost:4100/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      - indrajaal-db-prod
      - indrajaal-obs-prod
      - zenoh-router

  zenoh-router:
    image: eclipse/zenoh:latest
    container_name: zenoh-router
    ports:
      - "7447:7447"
    networks:
      - indrajaal-mesh

volumes:
  ml-models:
  ml-cache:

networks:
  indrajaal-mesh:
    driver: bridge
```

### 9.2 Kubernetes/K3s Deployment

```yaml
# k8s/ml-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: indrajaal-ml
  labels:
    app: indrajaal-ml
    tier: ml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: indrajaal-ml
  template:
    metadata:
      labels:
        app: indrajaal-ml
    spec:
      containers:
        - name: ml
          image: localhost/indrajaal-ml-prod:latest
          ports:
            - containerPort: 4100
            - containerPort: 4101
            - containerPort: 7447
          resources:
            limits:
              cpu: "8"
              memory: 16Gi
              nvidia.com/gpu: "1"
            requests:
              cpu: "4"
              memory: 8Gi
          env:
            - name: EXLA_TARGET
              value: "cuda"
            - name: FLAME_BACKEND
              value: "kubernetes"
          volumeMounts:
            - name: models
              mountPath: /app/data/models
            - name: cache
              mountPath: /app/data/exla_cache
          livenessProbe:
            httpGet:
              path: /health
              port: 4100
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 4100
            initialDelaySeconds: 5
            periodSeconds: 5
      volumes:
        - name: models
          persistentVolumeClaim:
            claimName: ml-models-pvc
        - name: cache
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: indrajaal-ml
spec:
  selector:
    app: indrajaal-ml
  ports:
    - name: http
      port: 4100
      targetPort: 4100
    - name: grpc
      port: 4101
      targetPort: 4101
    - name: zenoh
      port: 7447
      targetPort: 7447
```

---

## 10. Testing Strategy

### 10.1 Container Tests

```elixir
defmodule Indrajaal.ML.ContainerTest do
  use ExUnit.Case

  @tag :container
  test "container boots within 10 seconds" do
    {output, 0} = System.cmd("podman", [
      "run", "-d", "--name", "ml-boot-test",
      "localhost/indrajaal-ml-prod:latest"
    ])

    container_id = String.trim(output)

    # Wait for health
    assert_boot_time(container_id, max_ms: 10_000)

    # Cleanup
    System.cmd("podman", ["rm", "-f", container_id])
  end

  @tag :container
  test "FLAME workers can be spawned" do
    # Start primary container
    start_ml_container()

    # Trigger FLAME worker spawn
    features = generate_test_features(1000)
    results = Indrajaal.ML.FlamePool.batch_infer("test_model", features)

    assert length(results) == 1000

    # Verify worker was spawned
    flame_info = FLAME.Pool.info(Indrajaal.ML.FlamePool)
    assert flame_info.total_spawned > 0
  end

  @tag :container
  test "Zenoh mesh connectivity" do
    start_ml_container()

    # Verify Zenoh connection
    {:ok, session} = Zenoh.open(connect: ["tcp/localhost:7447"])
    {:ok, _} = Zenoh.put(session, "test/ping", "pong")

    # Verify response
    {:ok, sub} = Zenoh.subscribe(session, "indrajaal/ml/metrics/**")
    assert_receive {:zenoh, _, _}, 5000

    Zenoh.close(session)
  end
end
```

### 10.2 LiveView Tests

```elixir
defmodule IndrajaalWeb.ML.DashboardLiveTest do
  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  test "dashboard renders and receives updates", %{conn: conn} do
    {:ok, view, html} = live(conn, "/prajna/ml")

    assert html =~ "ML Dashboard"
    assert html =~ "Inference Performance"

    # Trigger a prediction
    Indrajaal.ML.InferenceEngine.infer("test_model", test_features())

    # Verify dashboard updates
    assert_receive {:update, _}
    html = render(view)
    assert html =~ "test_model"
  end

  test "model explorer allows predictions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/prajna/ml/models/anomaly_detector")

    # Submit prediction form
    view
    |> form("#prediction-form", input: %{feature_1: 0.5, feature_2: 0.8})
    |> render_submit()

    # Verify result displayed
    html = render(view)
    assert html =~ "Result"
    assert html =~ "Confidence"
  end
end
```

---

## 11. STAMP Constraints

### 11.1 Container-Specific Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-CNT-001 | Container boot time MUST be < 10s cold | CRITICAL |
| SC-ML-CNT-002 | Container image size MUST be < 500MB | HIGH |
| SC-ML-CNT-003 | FLAME workers MUST spawn within 30s | CRITICAL |
| SC-ML-CNT-004 | GPU memory MUST be capped at 80% | HIGH |
| SC-ML-CNT-005 | Zenoh MUST connect within 5s | HIGH |
| SC-ML-CNT-006 | Health endpoint MUST respond < 100ms | CRITICAL |
| SC-ML-CNT-007 | Container MUST be rootless | HIGH |
| SC-ML-CNT-008 | FLAME pool max MUST be 50 workers | HIGH |
| SC-ML-CNT-009 | Idle workers MUST terminate after 5min | MEDIUM |
| SC-ML-CNT-010 | All inference MUST complete < 100ms | CRITICAL |

### 11.2 LiveView Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-LV-001 | Dashboard refresh MUST be < 5s | HIGH |
| SC-ML-LV-002 | LiveView socket MUST reconnect on disconnect | HIGH |
| SC-ML-LV-003 | Prediction results MUST display < 200ms | HIGH |
| SC-ML-LV-004 | Chart updates MUST be smooth (60fps) | MEDIUM |
| SC-ML-LV-005 | Memory usage per socket < 50MB | HIGH |

---

## 12. AOR Rules

### 12.1 Container Rules

| ID | Rule |
|----|------|
| AOR-ML-CNT-001 | ALWAYS use multi-stage builds |
| AOR-ML-CNT-002 | NEVER include dev dependencies in runtime |
| AOR-ML-CNT-003 | ALWAYS test boot time before release |
| AOR-ML-CNT-004 | USE podman for rootless containers |
| AOR-ML-CNT-005 | VERIFY GPU access in health check |
| AOR-ML-CNT-006 | LOG all FLAME worker lifecycle events |

### 12.2 LiveView Rules

| ID | Rule |
|----|------|
| AOR-ML-LV-001 | USE temporary assigns for large data |
| AOR-ML-LV-002 | THROTTLE high-frequency updates |
| AOR-ML-LV-003 | HANDLE disconnection gracefully |
| AOR-ML-LV-004 | AVOID blocking in handle_event |
| AOR-ML-LV-005 | USE streams for large lists |

---

## Appendix A: Quick Reference

### DevEnv Commands

```bash
# Build ML container
devenv shell
ml-build          # Build container image
ml-test           # Run container tests
ml-deploy         # Deploy to local stack

# Start ML stack
sa-ml-up          # Start ML container with FLAME
sa-ml-down        # Stop ML container
sa-ml-logs        # View ML container logs
sa-ml-status      # Check ML container health
```

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/ready` | GET | Readiness check |
| `/api/infer` | POST | Single inference |
| `/api/batch` | POST | Batch inference |
| `/api/models` | GET | List models |
| `/api/metrics` | GET | ML metrics |

### LiveView Routes

| Route | Component | Description |
|-------|-----------|-------------|
| `/prajna/ml` | DashboardLive | Main ML dashboard |
| `/prajna/ml/models/:id` | ModelExplorerLive | Interactive model |
| `/prajna/ml/training/:id` | TrainingMonitorLive | Training jobs |
| `/prajna/ml/anomalies` | AnomalyDashboardLive | Anomaly detection |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP Compliance | SC-ML-CNT-001 through SC-ML-CNT-010 |
| Review Status | Draft |

---

*This document is part of the Indrajaal SIL-6 Biomorphic Fractal Mesh documentation suite.*
