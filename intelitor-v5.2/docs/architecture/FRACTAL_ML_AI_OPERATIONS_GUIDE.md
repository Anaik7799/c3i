# Fractal ML/AI Operations Guide

## 8-Level System Architecture with Machine Learning Integration

**Version**: 21.3.0-SIL6
**Status**: SPECIFICATION
**Classification**: Architecture Documentation
**STAMP Compliance**: SC-ML-001 through SC-ML-012

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [8-Level Fractal Architecture Overview](#2-8-level-fractal-architecture-overview)
3. [Elixir ML/AI Library Ecosystem](#3-elixir-mlai-library-ecosystem)
4. [Level-by-Level Specifications](#4-level-by-level-specifications)
5. [8-Level Interaction Matrix](#5-8-level-interaction-matrix)
6. [Criticality Classification](#6-criticality-classification)
7. [Resource Requirements](#7-resource-requirements)
8. [Cost Analysis](#8-cost-analysis)
9. [Implementation Roadmap](#9-implementation-roadmap)
10. [Testing Strategy](#10-testing-strategy)
11. [Usage Guide](#11-usage-guide)
12. [STAMP Constraints](#12-stamp-constraints)
13. [AOR Rules](#13-aor-rules)

---

## 1. Executive Summary

This document specifies the integration of Elixir-based data ingestion, processing, and ML/AI capabilities across the 8-level fractal architecture of the Indrajaal system. The design follows biomorphic principles, ensuring self-healing, adaptive intelligence, and constitutional compliance at every level.

### Key Objectives

| Objective | Description | Priority |
|-----------|-------------|----------|
| **Adaptive Intelligence** | ML-driven decision making at all fractal levels | CRITICAL |
| **Real-time Processing** | Sub-100ms inference for operational decisions | HIGH |
| **Biomorphic Integration** | Self-healing, pattern recognition, threat detection | CRITICAL |
| **Constitutional Compliance** | Ψ₀-Ψ₅ invariant verification via formal methods | CRITICAL |
| **Resource Efficiency** | Optimal GPU/CPU utilization across levels | HIGH |
| **Observability** | Full telemetry for ML model performance | MEDIUM |

### Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────────┐
│  ELIXIR ML/AI TECHNOLOGY STACK                                  │
├─────────────────────────────────────────────────────────────────┤
│  Data Ingestion:  Broadway, GenStage, Flow                      │
│  Data Processing: Explorer (Polars), NimbleCSV                  │
│  Tensors:         Nx (Numerical Elixir)                         │
│  Neural Networks: Axon (Deep Learning)                          │
│  Pre-trained:     Bumblebee (HuggingFace), Ortex (ONNX)        │
│  Classical ML:    Scholar (scikit-learn equivalent)             │
│  Acceleration:    EXLA (XLA/GPU), Torchx (PyTorch backend)     │
│  Interactive:     Livebook (Notebooks)                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 8-Level Fractal Architecture Overview

### Level Definitions

| Level | Name | Scope | VSM System | Primary ML Use Case |
|-------|------|-------|------------|---------------------|
| **L0** | Runtime | NIFs, BEAM schedulers | - | Tensor operations, GPU acceleration |
| **L1** | Function | I/O contracts, pure functions | S1 (Operations) | Input validation, feature extraction |
| **L2** | Component | Modules, GenServers | S2 (Coordination) | State prediction, anomaly detection |
| **L3** | Holon | Agent state, SQLite/DuckDB | S3 (Control) | Decision optimization, learning |
| **L4** | Container | Podman isolation, resources | S3 (Control) | Resource prediction, scaling |
| **L5** | Node | Runtime environment, clustering | S4 (Intelligence) | Cluster optimization, load balancing |
| **L6** | Cluster | Consensus, distributed state | S4 (Intelligence) | Consensus acceleration, partition prediction |
| **L7** | Federation | Cross-holon, global invariants | S5 (Policy) | Federation policy, trust scoring |
| **L8** | Constitutional | Ψ₀-Ψ₅ invariants, safety | S5 (Policy) | Formal verification assistance |

### Fractal Self-Similarity

Each level exhibits the same OODA (Observe-Orient-Decide-Act) pattern:

```
L8: Constitutional OODA (Policy verification, safety constraints)
 │
L7: Federation OODA (Cross-holon coordination, global optimization)
 │
L6: Cluster OODA (Distributed consensus, partition healing)
 │
L5: Node OODA (Resource management, load distribution)
 │
L4: Container OODA (Isolation management, health monitoring)
 │
L3: Holon OODA (Agent decision making, state evolution)
 │
L2: Component OODA (Module coordination, message routing)
 │
L1: Function OODA (Input validation, output transformation)
 │
L0: Runtime OODA (Scheduler optimization, memory management)
```

---

## 3. Elixir ML/AI Library Ecosystem

### 3.1 Data Ingestion Libraries

#### Broadway
- **Purpose**: Multi-source data ingestion with backpressure
- **Use Cases**: Alarm streams, telemetry ingestion, event processing
- **Criticality**: HIGH
- **Resource Profile**: CPU: Medium, Memory: Medium, GPU: None

```elixir
defmodule Indrajaal.AlarmIngestion do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayKafka.Producer, [
          hosts: [localhost: 9092],
          group_id: "alarm_consumers",
          topics: ["alarms"]
        ]},
        concurrency: 10
      ],
      processors: [
        default: [concurrency: 50]
      ],
      batchers: [
        ml_inference: [concurrency: 5, batch_size: 100]
      ]
    )
  end

  def handle_message(_, message, _) do
    # L1: Function-level feature extraction
    features = extract_features(message.data)
    message
    |> Message.put_batcher(:ml_inference)
    |> Message.put_data(features)
  end

  def handle_batch(:ml_inference, messages, _, _) do
    # L2: Component-level batch inference
    batch = Enum.map(messages, & &1.data)
    predictions = Indrajaal.ML.AnomalyDetector.predict_batch(batch)
    # Route to L3 Holon for decision
    Enum.zip(messages, predictions)
    |> Enum.each(fn {msg, pred} -> route_to_holon(msg, pred) end)
    messages
  end
end
```

#### GenStage
- **Purpose**: Demand-driven data processing pipelines
- **Use Cases**: Backpressure management, rate limiting, flow control
- **Criticality**: HIGH
- **Resource Profile**: CPU: Low, Memory: Low, GPU: None

#### Flow
- **Purpose**: Parallel data processing with MapReduce patterns
- **Use Cases**: Batch analytics, distributed aggregation, ETL
- **Criticality**: MEDIUM
- **Resource Profile**: CPU: High, Memory: Medium, GPU: None

### 3.2 Data Processing Libraries

#### Explorer (Polars Backend)
- **Purpose**: DataFrames for structured data manipulation
- **Use Cases**: Feature engineering, data cleaning, analytics
- **Criticality**: HIGH
- **Resource Profile**: CPU: High, Memory: High, GPU: None (Polars is CPU-optimized)

```elixir
defmodule Indrajaal.ML.FeatureEngineering do
  require Explorer.DataFrame, as: DF

  @doc """
  L2: Component-level feature engineering for alarm data.
  Creates time-series features for anomaly detection.
  """
  def create_alarm_features(alarm_df) do
    alarm_df
    |> DF.mutate(
      hour: Explorer.Series.hour(timestamp),
      day_of_week: Explorer.Series.day_of_week(timestamp),
      severity_encoded: Explorer.Series.cast(severity, :integer),
      time_since_last: Explorer.Series.diff(timestamp) |> Explorer.Series.cast(:integer)
    )
    |> DF.select([:hour, :day_of_week, :severity_encoded, :time_since_last, :zone_id])
    |> DF.to_rows()
    |> Enum.map(&Nx.tensor/1)
    |> Nx.stack()
  end
end
```

### 3.3 Tensor and Neural Network Libraries

#### Nx (Numerical Elixir)
- **Purpose**: Multi-dimensional tensors, numerical computing
- **Use Cases**: Feature representation, mathematical operations
- **Criticality**: CRITICAL
- **Resource Profile**: CPU: Variable, Memory: Variable, GPU: Via backends

```elixir
defmodule Indrajaal.ML.TensorOps do
  import Nx.Defn

  @doc """
  L0: Runtime-level optimized tensor operations.
  JIT-compiled for GPU acceleration via EXLA.
  """
  defn normalize_features(tensor) do
    mean = Nx.mean(tensor, axes: [0])
    std = Nx.standard_deviation(tensor, axes: [0])
    (tensor - mean) / (std + 1.0e-8)
  end

  defn cosine_similarity(a, b) do
    dot = Nx.dot(a, b)
    norm_a = Nx.sqrt(Nx.sum(a * a))
    norm_b = Nx.sqrt(Nx.sum(b * b))
    dot / (norm_a * norm_b + 1.0e-8)
  end
end
```

#### Axon (Deep Learning)
- **Purpose**: Neural network definition, training, inference
- **Use Cases**: Anomaly detection, classification, sequence prediction
- **Criticality**: HIGH
- **Resource Profile**: CPU: High, Memory: High, GPU: Recommended

```elixir
defmodule Indrajaal.ML.AnomalyDetector do
  @doc """
  L3: Holon-level anomaly detection model.
  Autoencoder architecture for unsupervised anomaly detection.
  """
  def build_model(input_size) do
    Axon.input("features", shape: {nil, input_size})
    |> Axon.dense(64, activation: :relu)
    |> Axon.dropout(rate: 0.2)
    |> Axon.dense(32, activation: :relu)
    |> Axon.dense(16, activation: :relu)  # Latent space
    |> Axon.dense(32, activation: :relu)
    |> Axon.dense(64, activation: :relu)
    |> Axon.dense(input_size, activation: :linear)
  end

  def train(model, train_data, epochs \\ 100) do
    model
    |> Axon.Loop.trainer(:mean_squared_error, Polaris.Optimizers.adam(learning_rate: 0.001))
    |> Axon.Loop.metric(:mean_absolute_error)
    |> Axon.Loop.run(train_data, %{}, epochs: epochs)
  end

  def predict_anomaly(model_state, model, features) do
    reconstructed = Axon.predict(model, model_state, features)
    reconstruction_error = Nx.mean(Nx.abs(features - reconstructed), axes: [1])
    threshold = 0.1  # Configurable threshold
    Nx.greater(reconstruction_error, threshold)
  end
end
```

#### Bumblebee (HuggingFace Integration)
- **Purpose**: Pre-trained transformer models (LLMs, embeddings, classification)
- **Use Cases**: NLP, semantic analysis, AI copilot, threat classification
- **Criticality**: HIGH
- **Resource Profile**: CPU: Very High, Memory: Very High, GPU: Required for large models

```elixir
defmodule Indrajaal.ML.SemanticAnalyzer do
  @doc """
  L5: Node-level semantic analysis using pre-trained models.
  Used by AI Copilot for natural language understanding.
  """
  def load_model do
    {:ok, model_info} = Bumblebee.load_model({:hf, "sentence-transformers/all-MiniLM-L6-v2"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "sentence-transformers/all-MiniLM-L6-v2"})

    Bumblebee.Text.TextEmbedding.text_embedding(model_info, tokenizer,
      compile: [batch_size: 32],
      defn_options: [compiler: EXLA]
    )
  end

  def embed_text(serving, text) when is_binary(text) do
    Nx.Serving.run(serving, text)
  end

  def semantic_similarity(serving, text_a, text_b) do
    emb_a = embed_text(serving, text_a)
    emb_b = embed_text(serving, text_b)
    Indrajaal.ML.TensorOps.cosine_similarity(emb_a.embedding, emb_b.embedding)
    |> Nx.to_number()
  end
end
```

#### Scholar (Classical ML)
- **Purpose**: Traditional ML algorithms (clustering, classification, regression)
- **Use Cases**: Quick prototyping, interpretable models, baseline comparisons
- **Criticality**: MEDIUM
- **Resource Profile**: CPU: Medium, Memory: Medium, GPU: None

```elixir
defmodule Indrajaal.ML.ThreatClassifier do
  alias Scholar.Cluster.KMeans
  alias Scholar.Neighbors.KNearestNeighbors

  @doc """
  L4: Container-level threat clustering for pattern detection.
  Groups similar threats for automated response selection.
  """
  def cluster_threats(threat_features, num_clusters \\ 5) do
    model = KMeans.fit(threat_features, num_clusters: num_clusters)
    labels = KMeans.predict(model, threat_features)
    {model, labels}
  end

  @doc """
  L3: Holon-level threat classification using k-NN.
  Classifies new threats based on historical patterns.
  """
  def classify_threat(model, new_threat_features) do
    KNearestNeighbors.predict(model, new_threat_features)
  end
end
```

### 3.4 Acceleration Backends

#### EXLA (XLA Compiler)
- **Purpose**: GPU/TPU acceleration via Google's XLA
- **Use Cases**: Training acceleration, batch inference
- **Criticality**: HIGH for production
- **Resource Profile**: GPU: Required, Memory: High

```elixir
# Configuration in config/runtime.exs
config :nx, :default_backend, EXLA.Backend
config :nx, :default_defn_options, [compiler: EXLA]

# GPU memory configuration
config :exla, :clients,
  cuda: [
    platform: :cuda,
    memory_fraction: 0.8,
    preallocate: false
  ]
```

#### Ortex (ONNX Runtime)
- **Purpose**: Run ONNX models from Python/other frameworks
- **Use Cases**: Model portability, production deployment, pre-trained models
- **Criticality**: MEDIUM
- **Resource Profile**: CPU/GPU: Variable

```elixir
defmodule Indrajaal.ML.OnnxInference do
  @doc """
  L4: Container-level ONNX model serving.
  Enables deployment of models trained in Python.
  """
  def load_model(model_path) do
    Ortex.load(model_path)
  end

  def predict(model, input_tensor) do
    Ortex.run(model, input_tensor)
  end
end
```

---

## 4. Level-by-Level Specifications

### 4.1 L0: Runtime Level

**Scope**: BEAM VM, NIFs, Schedulers, Memory Management

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Tensor Backend | EXLA/Torchx | GPU-accelerated tensor operations | CRITICAL |
| JIT Compilation | Nx.Defn | Optimized numerical functions | HIGH |
| Memory Management | NIF integration | Zero-copy tensor transfers | HIGH |

#### Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│  L0: RUNTIME LAYER                                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ BEAM VM     │  │ Rustler NIF │  │ EXLA Backend│              │
│  │ Schedulers  │  │ Zenoh NIF   │  │ GPU Driver  │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│         └────────────────┼────────────────┘                      │
│                          ▼                                       │
│              ┌───────────────────────┐                          │
│              │ Nx Tensor Runtime     │                          │
│              │ - Memory allocation   │                          │
│              │ - Backend selection   │                          │
│              │ - JIT compilation     │                          │
│              └───────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L0-001 | NIF tensor ops MUST NOT block BEAM schedulers | CRITICAL |
| SC-ML-L0-002 | GPU memory allocation MUST have timeout | HIGH |
| SC-ML-L0-003 | Tensor backend MUST support graceful fallback to CPU | HIGH |

### 4.2 L1: Function Level

**Scope**: Pure Functions, I/O Contracts, Feature Extraction

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Input Validation | Scholar | Anomaly detection on inputs | HIGH |
| Feature Extraction | Explorer | Transform raw data to features | HIGH |
| Preprocessing | Nx | Normalization, encoding | HIGH |

#### Architecture
```elixir
defmodule Indrajaal.ML.L1.Functions do
  @moduledoc """
  L1: Function-level ML operations.
  All functions are pure, deterministic, and composable.
  """

  @doc "Validate input against learned distribution"
  @spec validate_input(map()) :: {:ok, map()} | {:anomaly, float()}
  def validate_input(input) do
    features = extract_features(input)
    score = anomaly_score(features)
    if score < @threshold, do: {:ok, input}, else: {:anomaly, score}
  end

  @doc "Extract ML features from raw input"
  @spec extract_features(map()) :: Nx.Tensor.t()
  def extract_features(input) do
    input
    |> Map.take(@feature_keys)
    |> encode_categorical()
    |> normalize()
    |> Nx.tensor()
  end

  @doc "Transform output for downstream consumption"
  @spec transform_output(Nx.Tensor.t()) :: map()
  def transform_output(tensor) do
    tensor
    |> Nx.to_list()
    |> decode_predictions()
    |> format_response()
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L1-001 | Feature extraction MUST be deterministic | CRITICAL |
| SC-ML-L1-002 | Input validation MUST complete < 10ms | HIGH |
| SC-ML-L1-003 | Functions MUST NOT hold state | HIGH |

### 4.3 L2: Component Level

**Scope**: Modules, GenServers, Message Passing

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Batch Inference | Axon | Process message batches | HIGH |
| State Prediction | Axon/Scholar | Predict next state | MEDIUM |
| Anomaly Detection | Scholar | Detect component anomalies | HIGH |

#### Architecture
```elixir
defmodule Indrajaal.ML.L2.InferenceServer do
  use GenServer

  @moduledoc """
  L2: Component-level ML inference server.
  Manages model lifecycle and batch inference.
  """

  defstruct [:model, :model_state, :batch_queue, :batch_timer]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    model = Indrajaal.ML.AnomalyDetector.build_model(opts[:input_size])
    model_state = load_or_train_model(model, opts[:training_data])

    state = %__MODULE__{
      model: model,
      model_state: model_state,
      batch_queue: [],
      batch_timer: nil
    }

    {:ok, state}
  end

  def handle_cast({:infer, features, reply_to}, state) do
    new_queue = [{features, reply_to} | state.batch_queue]

    if length(new_queue) >= @batch_size do
      {new_state, _} = process_batch(%{state | batch_queue: new_queue})
      {:noreply, new_state}
    else
      timer = state.batch_timer || schedule_batch_timeout()
      {:noreply, %{state | batch_queue: new_queue, batch_timer: timer}}
    end
  end

  defp process_batch(state) do
    {features_list, reply_tos} = Enum.unzip(state.batch_queue)
    batch_tensor = Nx.stack(features_list)

    predictions = Axon.predict(state.model, state.model_state, batch_tensor)

    predictions
    |> Nx.to_list()
    |> Enum.zip(reply_tos)
    |> Enum.each(fn {pred, reply_to} -> send(reply_to, {:prediction, pred}) end)

    {%{state | batch_queue: [], batch_timer: nil}, predictions}
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L2-001 | Batch inference MUST complete < 100ms | HIGH |
| SC-ML-L2-002 | Model state MUST be checkpointable | HIGH |
| SC-ML-L2-003 | GenServer MUST NOT crash on inference error | CRITICAL |

### 4.4 L3: Holon Level

**Scope**: Agent State, SQLite/DuckDB, Decision Making

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Decision Optimization | Axon (RL) | Optimize agent decisions | CRITICAL |
| Pattern Learning | Scholar | Learn from history | HIGH |
| State Evolution | Nx | Track state trajectories | HIGH |

#### Architecture
```elixir
defmodule Indrajaal.ML.L3.HolonLearner do
  @moduledoc """
  L3: Holon-level learning and decision optimization.
  Integrates with SQLite/DuckDB for state persistence.
  """

  alias Indrajaal.Holon.StateStore

  @doc """
  Learn optimal decision policy from historical state transitions.
  Uses Q-learning with function approximation.
  """
  def learn_policy(holon_id, opts \\ []) do
    # Load historical transitions from DuckDB
    transitions = StateStore.get_transitions(holon_id, opts[:lookback] || 1000)

    # Build experience replay buffer
    buffer = build_replay_buffer(transitions)

    # Train Q-network
    q_network = build_q_network(opts[:state_dim], opts[:action_dim])
    trained_state = train_q_network(q_network, buffer, opts[:epochs] || 100)

    # Persist learned policy
    StateStore.save_policy(holon_id, trained_state)

    {:ok, trained_state}
  end

  @doc """
  Select action using learned policy with epsilon-greedy exploration.
  """
  def select_action(holon_id, current_state, opts \\ []) do
    policy = StateStore.load_policy(holon_id)
    epsilon = opts[:epsilon] || 0.1

    if :rand.uniform() < epsilon do
      # Explore: random action
      random_action(opts[:action_dim])
    else
      # Exploit: best action from Q-network
      q_values = Axon.predict(policy.model, policy.state, current_state)
      Nx.argmax(q_values) |> Nx.to_number()
    end
  end

  defp build_q_network(state_dim, action_dim) do
    Axon.input("state", shape: {nil, state_dim})
    |> Axon.dense(128, activation: :relu)
    |> Axon.dense(64, activation: :relu)
    |> Axon.dense(action_dim, activation: :linear)
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L3-001 | Holon learning MUST preserve state sovereignty (SQLite/DuckDB) | CRITICAL |
| SC-ML-L3-002 | Decision latency MUST be < 50ms | HIGH |
| SC-ML-L3-003 | Policy updates MUST be logged to Immutable Register | CRITICAL |

### 4.5 L4: Container Level

**Scope**: Podman Isolation, Resource Management

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Resource Prediction | Axon | Predict container resource needs | HIGH |
| Health Scoring | Scholar | Compute container health score | HIGH |
| Scaling Decision | Nx | Determine scaling actions | MEDIUM |

#### Architecture
```elixir
defmodule Indrajaal.ML.L4.ContainerPredictor do
  @moduledoc """
  L4: Container-level resource prediction and health scoring.
  Enables proactive scaling and anomaly detection.
  """

  @doc """
  Predict container resource usage for next time window.
  Uses LSTM for time-series prediction.
  """
  def predict_resources(container_id, horizon \\ 5) do
    # Get historical metrics
    metrics = get_container_metrics(container_id, lookback: 60)

    # Build feature tensor [cpu, memory, network, disk]
    features = metrics_to_tensor(metrics)

    # Predict future usage
    model = load_resource_model()
    predictions = predict_sequence(model, features, horizon)

    %{
      cpu: Nx.slice(predictions, [0, 0], [horizon, 1]) |> Nx.to_list(),
      memory: Nx.slice(predictions, [0, 1], [horizon, 1]) |> Nx.to_list(),
      network: Nx.slice(predictions, [0, 2], [horizon, 1]) |> Nx.to_list(),
      disk: Nx.slice(predictions, [0, 3], [horizon, 1]) |> Nx.to_list()
    }
  end

  @doc """
  Compute container health score using ensemble of metrics.
  Returns score 0.0-1.0 where 1.0 is fully healthy.
  """
  def health_score(container_id) do
    metrics = get_current_metrics(container_id)

    # Multi-factor health scoring
    cpu_health = 1.0 - min(metrics.cpu_usage / 100.0, 1.0)
    memory_health = 1.0 - min(metrics.memory_usage / metrics.memory_limit, 1.0)
    restart_health = max(1.0 - metrics.restart_count * 0.2, 0.0)
    latency_health = max(1.0 - metrics.avg_latency / 1000.0, 0.0)

    # Weighted average
    weights = [0.3, 0.3, 0.2, 0.2]
    scores = [cpu_health, memory_health, restart_health, latency_health]

    Enum.zip(weights, scores)
    |> Enum.map(fn {w, s} -> w * s end)
    |> Enum.sum()
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L4-001 | Resource predictions MUST have 90% accuracy | HIGH |
| SC-ML-L4-002 | Health scoring MUST complete < 50ms | HIGH |
| SC-ML-L4-003 | Scaling decisions MUST respect resource limits | CRITICAL |

### 4.6 L5: Node Level

**Scope**: Runtime Environment, Clustering, Load Balancing

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Cluster Optimization | Axon | Optimize node placement | HIGH |
| Load Prediction | Axon (LSTM) | Predict load patterns | HIGH |
| Failure Prediction | Scholar | Predict node failures | CRITICAL |

#### Architecture
```elixir
defmodule Indrajaal.ML.L5.ClusterOptimizer do
  @moduledoc """
  L5: Node-level cluster optimization and load balancing.
  Uses ML to predict load and optimize resource allocation.
  """

  @doc """
  Optimize workload distribution across cluster nodes.
  Uses constraint satisfaction with learned preferences.
  """
  def optimize_distribution(workloads, nodes) do
    # Get node capabilities and current load
    node_features = Enum.map(nodes, &extract_node_features/1)
    workload_features = Enum.map(workloads, &extract_workload_features/1)

    # Build assignment matrix using learned preferences
    assignment_scores = compute_assignment_scores(workload_features, node_features)

    # Solve assignment problem (Hungarian algorithm with ML-enhanced scores)
    optimal_assignment = solve_assignment(assignment_scores)

    # Return distribution plan
    Enum.zip(workloads, optimal_assignment)
    |> Enum.map(fn {workload, node_idx} -> {workload.id, Enum.at(nodes, node_idx).id} end)
    |> Map.new()
  end

  @doc """
  Predict node failure probability using gradient boosting.
  """
  def predict_failure(node_id, horizon_hours \\ 24) do
    # Historical failure patterns
    features = get_failure_features(node_id)

    # Use trained gradient boosting model
    model = load_failure_model()
    probability = Scholar.predict(model, features)

    %{
      node_id: node_id,
      failure_probability: Nx.to_number(probability),
      horizon_hours: horizon_hours,
      recommendation: if(Nx.to_number(probability) > 0.7, do: :migrate_workloads, else: :monitor)
    }
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L5-001 | Load prediction accuracy MUST be > 85% | HIGH |
| SC-ML-L5-002 | Failure prediction MUST have < 5% false negative rate | CRITICAL |
| SC-ML-L5-003 | Optimization MUST complete < 5s for 100 nodes | MEDIUM |

### 4.7 L6: Cluster Level

**Scope**: Distributed Consensus, Partition Handling

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Consensus Acceleration | Nx | Speed up consensus rounds | MEDIUM |
| Partition Prediction | Axon | Predict network partitions | HIGH |
| Conflict Resolution | Scholar | Resolve state conflicts | HIGH |

#### Architecture
```elixir
defmodule Indrajaal.ML.L6.ConsensusAccelerator do
  @moduledoc """
  L6: Cluster-level consensus acceleration and partition prediction.
  Uses ML to predict voting outcomes and detect partitions early.
  """

  @doc """
  Predict consensus outcome based on partial votes.
  Enables early termination of consensus rounds.
  """
  def predict_consensus(partial_votes, quorum_size) do
    # Encode vote patterns
    vote_features = encode_votes(partial_votes)

    # Predict final outcome
    model = load_consensus_model()
    prediction = Axon.predict(model, load_consensus_state(), vote_features)

    confidence = Nx.to_number(Nx.max(prediction))
    predicted_outcome = Nx.to_number(Nx.argmax(prediction))

    if confidence > 0.95 and length(partial_votes) > quorum_size * 0.6 do
      {:early_termination, predicted_outcome, confidence}
    else
      {:continue_voting, predicted_outcome, confidence}
    end
  end

  @doc """
  Predict network partition probability based on network metrics.
  """
  def predict_partition(network_metrics) do
    features = encode_network_features(network_metrics)

    model = load_partition_model()
    probability = Axon.predict(model, load_partition_state(), features)

    risk_level = cond do
      Nx.to_number(probability) > 0.8 -> :critical
      Nx.to_number(probability) > 0.5 -> :high
      Nx.to_number(probability) > 0.2 -> :medium
      true -> :low
    end

    %{
      partition_probability: Nx.to_number(probability),
      risk_level: risk_level,
      recommended_action: partition_action(risk_level)
    }
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L6-001 | Consensus prediction MUST NOT compromise safety | CRITICAL |
| SC-ML-L6-002 | Partition prediction latency < 100ms | HIGH |
| SC-ML-L6-003 | Early termination REQUIRES 95% confidence | CRITICAL |

### 4.8 L7: Federation Level

**Scope**: Cross-Holon Communication, Global Policies

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Trust Scoring | Axon | Score federation peer trust | CRITICAL |
| Policy Learning | Axon (RL) | Learn optimal federation policies | HIGH |
| Anomaly Detection | Scholar | Detect federation anomalies | HIGH |

#### Architecture
```elixir
defmodule Indrajaal.ML.L7.FederationIntelligence do
  @moduledoc """
  L7: Federation-level trust scoring and policy learning.
  Manages cross-holon intelligence and coordination.
  """

  @doc """
  Compute trust score for federation peer.
  Based on historical behavior, attestations, and network position.
  """
  def compute_trust_score(peer_holon_id) do
    # Historical interaction data
    interactions = get_peer_interactions(peer_holon_id)
    attestations = get_peer_attestations(peer_holon_id)

    # Build feature vector
    features = %{
      successful_interactions: count_successful(interactions),
      failed_interactions: count_failed(interactions),
      attestation_validity: average_attestation_validity(attestations),
      uptime_ratio: get_uptime_ratio(peer_holon_id),
      response_latency: average_response_latency(interactions),
      protocol_compliance: check_protocol_compliance(interactions)
    }
    |> encode_features()

    # Predict trust score
    model = load_trust_model()
    trust_score = Axon.predict(model, load_trust_state(), features)

    %{
      peer_holon_id: peer_holon_id,
      trust_score: Nx.to_number(trust_score),
      trust_level: trust_level(Nx.to_number(trust_score)),
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Learn optimal federation routing policy.
  Uses multi-agent reinforcement learning.
  """
  def learn_routing_policy(federation_state) do
    # Multi-agent environment
    env = build_federation_env(federation_state)

    # Train routing agents
    policy = train_multi_agent_rl(env, epochs: 1000)

    # Validate policy against constitutional constraints
    if validate_policy(policy) do
      {:ok, policy}
    else
      {:error, :constitutional_violation}
    end
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L7-001 | Trust scoring MUST consider attestation chain | CRITICAL |
| SC-ML-L7-002 | Routing policy MUST respect Ψ₄ (human alignment) | CRITICAL |
| SC-ML-L7-003 | Federation decisions MUST be auditable | HIGH |

### 4.9 L8: Constitutional Level

**Scope**: Ψ₀-Ψ₅ Invariants, Safety Verification

#### ML Capabilities
| Capability | Library | Purpose | Criticality |
|------------|---------|---------|-------------|
| Formal Verification Aid | Nx | Guide proof search | HIGH |
| Invariant Monitoring | Axon | Continuous invariant checking | CRITICAL |
| Safety Prediction | Scholar | Predict safety violations | CRITICAL |

#### Architecture
```elixir
defmodule Indrajaal.ML.L8.ConstitutionalGuard do
  @moduledoc """
  L8: Constitutional-level safety verification and monitoring.
  Ensures Ψ₀-Ψ₅ invariants are never violated.
  """

  @constitutional_invariants [
    {:psi_0, "Existence preservation"},
    {:psi_1, "Regenerative completeness"},
    {:psi_2, "Evolutionary continuity"},
    {:psi_3, "Verification capability"},
    {:psi_4, "Human alignment"},
    {:psi_5, "Truthfulness"}
  ]

  @doc """
  Verify proposed action against constitutional invariants.
  Uses ML to accelerate verification, but formal proof required.
  """
  def verify_action(action, current_state) do
    # ML-based quick check (acceleration)
    quick_result = ml_quick_verify(action, current_state)

    case quick_result do
      {:likely_safe, confidence} when confidence > 0.99 ->
        # High confidence: run lightweight formal check
        lightweight_formal_verify(action, current_state)

      {:likely_unsafe, confidence, violated_invariant} ->
        # Predict violation: immediate rejection
        {:rejected, violated_invariant, confidence}

      {:uncertain, _} ->
        # Uncertain: full formal verification required
        full_formal_verify(action, current_state)
    end
  end

  @doc """
  Continuous monitoring of constitutional invariants.
  Publishes alerts via Zenoh on potential violations.
  """
  def monitor_invariants(system_state) do
    Enum.map(@constitutional_invariants, fn {invariant, description} ->
      score = check_invariant(invariant, system_state)

      if score < 0.95 do
        alert = %{
          invariant: invariant,
          description: description,
          score: score,
          severity: if(score < 0.8, do: :critical, else: :warning),
          timestamp: DateTime.utc_now()
        }

        publish_alert(alert)
        alert
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp ml_quick_verify(action, state) do
    features = encode_action_state(action, state)
    model = load_constitutional_model()

    prediction = Axon.predict(model, load_constitutional_state(), features)

    # Output: [p_safe, p_psi0_violation, p_psi1_violation, ...]
    probabilities = Nx.to_list(prediction)
    [p_safe | violation_probs] = probabilities

    max_violation_idx = Enum.find_index(violation_probs, &(&1 == Enum.max(violation_probs)))
    max_violation_prob = Enum.max(violation_probs)

    cond do
      p_safe > 0.99 -> {:likely_safe, p_safe}
      max_violation_prob > 0.8 -> {:likely_unsafe, max_violation_prob, Enum.at(@constitutional_invariants, max_violation_idx)}
      true -> {:uncertain, p_safe}
    end
  end
end
```

#### STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-L8-001 | ML verification MUST NOT replace formal proofs | INFINITE |
| SC-ML-L8-002 | Constitutional monitoring MUST be continuous | CRITICAL |
| SC-ML-L8-003 | Safety predictions MUST have <0.1% false negative | CRITICAL |

---

## 5. 8-Level Interaction Matrix

### 5.1 Interaction Types

| Interaction | Description | ML Role |
|-------------|-------------|---------|
| **Vertical** | Between adjacent levels (L(n) ↔ L(n+1)) | State propagation, constraint enforcement |
| **Horizontal** | Within same level (peer-to-peer) | Load balancing, consensus |
| **Skip-Level** | Between non-adjacent levels | Emergency escalation, policy override |
| **Cross-Holon** | Between different holons | Federation, trust verification |

### 5.2 Interaction Matrix

```
       │ L0  │ L1  │ L2  │ L3  │ L4  │ L5  │ L6  │ L7  │ L8  │
───────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤
  L0   │ H:T │ V:F │     │     │     │     │     │     │ S:C │
  L1   │ V:F │ H:V │ V:P │     │     │     │     │     │ S:C │
  L2   │     │ V:P │ H:M │ V:S │     │     │     │     │ S:C │
  L3   │     │     │ V:S │ H:A │ V:R │     │     │ X:F │ S:C │
  L4   │     │     │     │ V:R │ H:I │ V:L │     │     │ S:C │
  L5   │     │     │     │     │ V:L │ H:C │ V:D │     │ S:C │
  L6   │     │     │     │     │     │ V:D │ H:Q │ V:G │ S:C │
  L7   │     │ X:F │     │ X:F │     │     │ V:G │ H:P │ V:C │
  L8   │ S:C │ S:C │ S:C │ S:C │ S:C │ S:C │ S:C │ V:C │ H:Ψ │

Legend:
  H = Horizontal    V = Vertical    S = Skip-level    X = Cross-holon
  T = Tensor ops    F = Features    P = Prediction    S = State
  M = Messages      A = Actions     R = Resources     I = Isolation
  L = Load          C = Cluster     D = Distributed   Q = Quorum
  G = Global        Ψ = Constitutional
```

### 5.3 ML-Enhanced Interaction Protocols

#### L1 ↔ L2: Feature-to-Prediction Pipeline
```elixir
defmodule Indrajaal.ML.Interaction.L1L2 do
  @moduledoc "Feature extraction (L1) to batch inference (L2)"

  def feature_to_prediction(raw_input) do
    # L1: Pure function feature extraction
    features = L1.Functions.extract_features(raw_input)

    # L2: Component batch inference
    {:ok, prediction} = L2.InferenceServer.infer(features)

    # Return with provenance
    %{
      input: raw_input,
      features: features,
      prediction: prediction,
      provenance: %{l1: :feature_extraction, l2: :batch_inference}
    }
  end
end
```

#### L3 ↔ L4: Holon-Container Resource Negotiation
```elixir
defmodule Indrajaal.ML.Interaction.L3L4 do
  @moduledoc "Holon decision (L3) to container scaling (L4)"

  def holon_requests_resources(holon_id, resource_needs) do
    # L3: Holon predicts resource needs
    predicted_needs = L3.HolonLearner.predict_resource_needs(holon_id)

    # Merge with explicit requests
    total_needs = merge_resource_needs(resource_needs, predicted_needs)

    # L4: Container evaluates and provisions
    case L4.ContainerPredictor.can_provision?(total_needs) do
      {:ok, allocation} ->
        L4.ContainerPredictor.provision(allocation)
        {:ok, allocation}

      {:constrained, available} ->
        # Negotiate with holon
        L3.HolonLearner.adapt_to_constraints(holon_id, available)
    end
  end
end
```

#### L6 ↔ L7: Cluster-Federation Consensus
```elixir
defmodule Indrajaal.ML.Interaction.L6L7 do
  @moduledoc "Cluster consensus (L6) to federation policy (L7)"

  def federated_consensus(proposal) do
    # L6: Local cluster consensus
    local_result = L6.ConsensusAccelerator.local_consensus(proposal)

    # L7: Federation-wide verification
    trust_scores = L7.FederationIntelligence.get_peer_trust_scores()

    # Weighted federation consensus
    L7.FederationIntelligence.federated_vote(proposal, local_result, trust_scores)
  end
end
```

#### L7 ↔ L8: Federation-Constitutional Verification
```elixir
defmodule Indrajaal.ML.Interaction.L7L8 do
  @moduledoc "Federation policy (L7) to constitutional verification (L8)"

  def verify_federation_action(action) do
    # L8: Constitutional pre-check
    case L8.ConstitutionalGuard.verify_action(action, get_system_state()) do
      {:approved, proof_token} ->
        # L7: Execute with proof
        L7.FederationIntelligence.execute_with_proof(action, proof_token)

      {:rejected, violated_invariant, confidence} ->
        # Log and reject
        log_constitutional_rejection(action, violated_invariant, confidence)
        {:error, :constitutional_violation, violated_invariant}
    end
  end
end
```

---

## 6. Criticality Classification

### 6.1 Criticality Levels

| Level | Definition | Response Time | Failure Impact |
|-------|------------|---------------|----------------|
| **INFINITE** | Cannot be violated under any circumstances | N/A | System termination |
| **CRITICAL** | Operational continuity depends on this | < 100ms | Service outage |
| **HIGH** | Major functionality affected | < 1s | Degraded service |
| **MEDIUM** | Minor functionality affected | < 10s | Reduced quality |
| **LOW** | Minimal impact | Best effort | Minor inconvenience |

### 6.2 ML Component Criticality Matrix

| Component | Level | Criticality | Justification |
|-----------|-------|-------------|---------------|
| Constitutional Verification | L8 | INFINITE | Ψ₀-Ψ₅ must never be violated |
| Federation Trust Scoring | L7 | CRITICAL | Security boundary |
| Consensus Acceleration | L6 | HIGH | Affects distributed consistency |
| Failure Prediction | L5 | CRITICAL | Prevents data loss |
| Resource Prediction | L4 | HIGH | Affects availability |
| Decision Optimization | L3 | CRITICAL | Core agent behavior |
| Anomaly Detection | L2 | HIGH | Security and reliability |
| Feature Extraction | L1 | HIGH | Foundation for all ML |
| Tensor Backend | L0 | CRITICAL | All computation depends on this |

### 6.3 Failure Mode Analysis (FMEA)

| Component | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|-----------|--------------|----------|------------|-----------|-----|------------|
| Tensor Backend | GPU OOM | 8 | 4 | 6 | 192 | Memory limits, fallback to CPU |
| Anomaly Detection | False negative | 9 | 3 | 5 | 135 | Ensemble models, threshold tuning |
| Decision Optimization | Suboptimal policy | 6 | 5 | 4 | 120 | Continuous learning, bounds |
| Trust Scoring | Trust manipulation | 9 | 2 | 6 | 108 | Attestation chains, formal verification |
| Consensus Acceleration | Wrong prediction | 7 | 3 | 5 | 105 | Confidence threshold, fallback |
| Constitutional ML | False safe | 10 | 1 | 9 | 90 | Formal proof required |

---

## 7. Resource Requirements

### 7.1 Hardware Requirements by Level

| Level | CPU Cores | RAM (GB) | GPU | Storage | Network |
|-------|-----------|----------|-----|---------|---------|
| L0 | 4+ | 8+ | Required (CUDA) | SSD 100GB | 1Gbps |
| L1 | 2 | 4 | Optional | SSD 10GB | 100Mbps |
| L2 | 4 | 8 | Recommended | SSD 50GB | 1Gbps |
| L3 | 4 | 16 | Recommended | SSD 100GB | 1Gbps |
| L4 | 2 | 4 | Optional | SSD 20GB | 100Mbps |
| L5 | 8 | 32 | Recommended | SSD 200GB | 10Gbps |
| L6 | 4 | 16 | Optional | SSD 100GB | 10Gbps |
| L7 | 8 | 32 | Required | SSD 500GB | 10Gbps |
| L8 | 4 | 16 | Optional | SSD 50GB | 1Gbps |

### 7.2 GPU Specifications

| Model Type | Min GPU Memory | Recommended GPU | Use Case |
|------------|----------------|-----------------|----------|
| Small (Anomaly Detection) | 4GB | RTX 3060 | L2, L4 inference |
| Medium (Decision/Trust) | 8GB | RTX 4070 | L3, L5 training |
| Large (LLM/Embedding) | 16GB+ | RTX 4090 / A10 | L7 Bumblebee |
| Production | 40GB+ | A100 / H100 | Full stack |

### 7.3 Memory Budget per Level

```
Total System Memory: 128GB recommended

L0 Runtime:     8GB  (Tensor buffers, GPU transfer)
L1 Functions:   2GB  (Feature extraction scratch)
L2 Components: 16GB  (Model states, batch buffers)
L3 Holons:     32GB  (All holon states, learning)
L4 Containers:  4GB  (Per-container monitoring)
L5 Nodes:      16GB  (Cluster optimization)
L6 Cluster:     8GB  (Consensus state)
L7 Federation: 32GB  (LLM models, embeddings)
L8 Constitutional: 8GB (Verification cache)
Reserved:       2GB  (Safety buffer)
```

---

## 8. Cost Analysis

### 8.1 Implementation Costs

| Phase | Duration | Effort (Person-Days) | Cost Estimate |
|-------|----------|---------------------|---------------|
| **Phase 1: Foundation** | 4 weeks | 80 | $40,000 |
| - L0 Tensor Backend | 1 week | 20 | $10,000 |
| - L1 Feature Functions | 1 week | 20 | $10,000 |
| - L2 Inference Server | 2 weeks | 40 | $20,000 |
| **Phase 2: Core** | 6 weeks | 120 | $60,000 |
| - L3 Holon Learning | 3 weeks | 60 | $30,000 |
| - L4 Container ML | 2 weeks | 40 | $20,000 |
| - L5 Cluster Optimization | 1 week | 20 | $10,000 |
| **Phase 3: Advanced** | 8 weeks | 160 | $80,000 |
| - L6 Consensus ML | 2 weeks | 40 | $20,000 |
| - L7 Federation Intelligence | 4 weeks | 80 | $40,000 |
| - L8 Constitutional Guard | 2 weeks | 40 | $20,000 |
| **Phase 4: Integration** | 4 weeks | 80 | $40,000 |
| - Cross-level interactions | 2 weeks | 40 | $20,000 |
| - Testing and validation | 2 weeks | 40 | $20,000 |
| **TOTAL** | **22 weeks** | **440** | **$220,000** |

### 8.2 Operational Costs (Monthly)

| Resource | Specification | Monthly Cost |
|----------|---------------|--------------|
| GPU Compute | 2x A100 (cloud) | $8,000 |
| CPU Compute | 32 cores | $1,500 |
| Storage | 2TB NVMe | $400 |
| Network | 10Gbps | $500 |
| Model Training | 100 GPU-hours/month | $2,000 |
| Monitoring | Observability stack | $500 |
| **TOTAL** | | **$12,900/month** |

### 8.3 Cost Optimization Strategies

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Use EXLA CPU fallback | 50% GPU costs | Slower inference |
| Scholar for simple models | 30% training costs | Less accuracy |
| Batch inference | 40% compute | Higher latency |
| Model quantization | 25% memory | Slight accuracy loss |
| Spot instances | 60% cloud costs | Availability risk |

---

## 9. Implementation Roadmap

### 9.1 Phase 1: Foundation (Weeks 1-4)

```
Week 1: L0 Tensor Backend
├── Configure EXLA/Torchx backends
├── Implement GPU memory management
├── Create NIF integration for Zenoh tensors
└── Verify tensor operations performance

Week 2: L1 Feature Functions
├── Implement feature extraction library
├── Create preprocessing functions
├── Define input validation contracts
└── Property tests for determinism

Week 3-4: L2 Inference Server
├── Build batch inference GenServer
├── Implement model lifecycle management
├── Create telemetry integration
└── Load testing and optimization
```

### 9.2 Phase 2: Core (Weeks 5-10)

```
Week 5-7: L3 Holon Learning
├── Implement Q-learning framework
├── Integrate with SQLite/DuckDB state
├── Create policy persistence
├── Build training pipelines

Week 8-9: L4 Container ML
├── Resource prediction models
├── Health scoring system
├── Scaling decision logic
├── Integration with Podman

Week 10: L5 Cluster Optimization
├── Load balancing ML
├── Failure prediction
├── Workload distribution
└── Node health scoring
```

### 9.3 Phase 3: Advanced (Weeks 11-18)

```
Week 11-12: L6 Consensus ML
├── Consensus prediction model
├── Partition detection
├── Early termination logic
└── Safety constraints

Week 13-16: L7 Federation Intelligence
├── Trust scoring system
├── Bumblebee LLM integration
├── Semantic analysis for AI Copilot
├── Multi-agent RL for routing

Week 17-18: L8 Constitutional Guard
├── Constitutional ML models
├── Invariant monitoring
├── Formal verification bridge
└── Safety prediction
```

### 9.4 Phase 4: Integration (Weeks 19-22)

```
Week 19-20: Cross-Level Integration
├── L1↔L2 pipelines
├── L3↔L4 negotiation
├── L6↔L7 consensus
└── L7↔L8 verification

Week 21-22: Testing and Validation
├── End-to-end testing
├── Performance benchmarks
├── STAMP constraint validation
├── Documentation completion
```

---

## 10. Testing Strategy

### 10.1 Testing by Level

| Level | Unit Tests | Property Tests | Integration | E2E |
|-------|------------|----------------|-------------|-----|
| L0 | Tensor ops | Numerical stability | Backend switching | Full pipeline |
| L1 | Functions | Determinism | Feature pipelines | Input-to-output |
| L2 | GenServer | Batch invariants | Component composition | Service chains |
| L3 | Learning | Policy convergence | State persistence | Agent scenarios |
| L4 | Predictions | Resource bounds | Container lifecycle | Scaling scenarios |
| L5 | Optimization | Load distribution | Cluster operations | Multi-node |
| L6 | Consensus | Safety properties | Distributed ops | Partition scenarios |
| L7 | Trust scoring | Federation invariants | Cross-holon | Full federation |
| L8 | Verification | Constitutional safety | Guardian integration | System-wide |

### 10.2 Property Testing Requirements

Per SC-PROP-023 and SC-PROP-024:

```elixir
defmodule Indrajaal.ML.Test.Properties do
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # L1: Feature extraction determinism
  property "feature extraction is deterministic" do
    forall input <- PC.map(PC.atom(), PC.term()) do
      features1 = L1.Functions.extract_features(input)
      features2 = L1.Functions.extract_features(input)
      Nx.equal(features1, features2) |> Nx.all() |> Nx.to_number() == 1
    end
  end

  # L2: Batch inference preserves order
  property "batch inference preserves input order" do
    forall tensors <- PC.list(tensor_generator()) do
      results = L2.InferenceServer.batch_infer(tensors)
      length(results) == length(tensors)
    end
  end

  # L3: Policy learning converges
  property "policy learning improves over episodes" do
    forall episodes <- PC.pos_integer() do
      rewards = L3.HolonLearner.train_episodes(episodes)
      # Trend should be positive
      first_half = Enum.take(rewards, div(episodes, 2))
      second_half = Enum.drop(rewards, div(episodes, 2))
      Enum.sum(second_half) >= Enum.sum(first_half)
    end
  end
end
```

### 10.3 Constitutional Testing

```elixir
defmodule Indrajaal.ML.Test.Constitutional do
  use ExUnit.Case

  @tag :constitutional
  test "ML decisions never violate Ψ₀ (existence)" do
    # Generate adversarial inputs
    inputs = generate_adversarial_inputs(1000)

    for input <- inputs do
      decision = L3.HolonLearner.make_decision(input)
      assert L8.ConstitutionalGuard.preserves_existence?(decision)
    end
  end

  @tag :constitutional
  test "Trust scoring is truthful (Ψ₅)" do
    # Verify trust scores are based on actual behavior
    peer = create_test_peer()
    perform_interactions(peer, good: 90, bad: 10)

    score = L7.FederationIntelligence.compute_trust_score(peer.id)

    assert score.trust_score > 0.8  # Reflects mostly good behavior
    assert score.trust_score < 0.95  # Reflects some bad behavior
  end
end
```

---

## 11. Usage Guide

### 11.1 Quick Start

```elixir
# 1. Configure backends (config/runtime.exs)
config :nx, :default_backend, EXLA.Backend
config :nx, :default_defn_options, [compiler: EXLA]

# 2. Start ML supervision tree
Indrajaal.ML.Supervisor.start_link([])

# 3. Basic inference
features = Indrajaal.ML.L1.Functions.extract_features(input)
{:ok, prediction} = Indrajaal.ML.L2.InferenceServer.infer(features)

# 4. Holon decision making
action = Indrajaal.ML.L3.HolonLearner.select_action(holon_id, state)
```

### 11.2 Training Models

```elixir
# Load training data
train_data = Indrajaal.ML.Data.load_training_set("anomaly_detection")

# Build and train model
model = Indrajaal.ML.AnomalyDetector.build_model(input_size: 10)
trained_state = Indrajaal.ML.AnomalyDetector.train(model, train_data, epochs: 100)

# Save model
Indrajaal.ML.ModelStore.save(trained_state, "anomaly_detector_v1")
```

### 11.3 Livebook Integration

```elixir
# In Livebook:
Mix.install([
  {:indrajaal, path: "/home/an/dev/ver/intelitor-v5.2"},
  {:kino, "~> 0.12"},
  {:kino_vega_lite, "~> 0.1"}
])

# Interactive model exploration
alias Indrajaal.ML.L3.HolonLearner

# Visualize learning progress
Kino.VegaLite.new()
|> Kino.VegaLite.push(rewards: learning_rewards)
|> Kino.render()
```

### 11.4 Monitoring and Debugging

```elixir
# Get ML metrics
metrics = Indrajaal.ML.Telemetry.get_metrics()
# => %{
#   inference_latency_p99: 45.2,
#   batch_size_avg: 32,
#   gpu_memory_usage: 0.65,
#   model_accuracy: 0.94
# }

# Debug specific prediction
Indrajaal.ML.Debug.trace_prediction(features)
# => [
#   {:l1_extraction, %{duration: 2.1}},
#   {:l2_batch_queue, %{position: 15}},
#   {:l2_inference, %{duration: 12.3}},
#   {:l3_decision, %{action: 3, confidence: 0.89}}
# ]
```

### 11.5 DevEnv Commands

```bash
# Enter development environment
devenv shell

# Train models
mix ml.train --model anomaly_detector --epochs 100

# Evaluate model performance
mix ml.evaluate --model anomaly_detector --dataset test

# Run ML benchmarks
mix ml.benchmark

# Generate ML documentation
mix ml.docs
```

---

## 12. STAMP Constraints

### 12.1 ML-Specific STAMP Constraints

| ID | Constraint | Severity | Level |
|----|------------|----------|-------|
| SC-ML-001 | Model inference MUST complete < 100ms | CRITICAL | All |
| SC-ML-002 | Training MUST NOT block BEAM schedulers | CRITICAL | L0 |
| SC-ML-003 | Model state MUST be checkpointable | HIGH | L2-L7 |
| SC-ML-004 | Predictions MUST include confidence scores | HIGH | L2-L7 |
| SC-ML-005 | ML decisions MUST be auditable | CRITICAL | L3-L8 |
| SC-ML-006 | Constitutional ML MUST NOT replace formal proofs | INFINITE | L8 |
| SC-ML-007 | Feature extraction MUST be deterministic | CRITICAL | L1 |
| SC-ML-008 | Trust scoring MUST verify attestation chains | CRITICAL | L7 |
| SC-ML-009 | Consensus acceleration requires 95% confidence | CRITICAL | L6 |
| SC-ML-010 | Failure prediction must have <5% false negative | CRITICAL | L5 |
| SC-ML-011 | Resource predictions must have 90% accuracy | HIGH | L4 |
| SC-ML-012 | Holon learning must preserve state sovereignty | CRITICAL | L3 |

### 12.2 Cross-Level Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ML-X-001 | L8 verification MUST be called for L7 decisions | CRITICAL |
| SC-ML-X-002 | L1 features MUST be validated before L2 inference | HIGH |
| SC-ML-X-003 | L3 decisions MUST log to Immutable Register | CRITICAL |
| SC-ML-X-004 | L5 predictions MUST inform L4 scaling | HIGH |
| SC-ML-X-005 | L6 consensus MUST respect L7 federation policy | CRITICAL |

---

## 13. AOR Rules

### 13.1 ML-Specific AOR Rules

| ID | Rule |
|----|------|
| AOR-ML-001 | ALWAYS use EXLA backend in production |
| AOR-ML-002 | NEVER run training in request path |
| AOR-ML-003 | CHECKPOINT models before deployment |
| AOR-ML-004 | VALIDATE model outputs against bounds |
| AOR-ML-005 | LOG all predictions for audit trail |
| AOR-ML-006 | USE batch inference for throughput |
| AOR-ML-007 | FALLBACK to CPU on GPU failure |
| AOR-ML-008 | RETRAIN models on distribution shift |
| AOR-ML-009 | VERIFY constitutional compliance for L7-L8 |
| AOR-ML-010 | DOCUMENT model lineage and training data |

### 13.2 Development AOR Rules

| ID | Rule |
|----|------|
| AOR-ML-DEV-001 | Use Livebook for model prototyping |
| AOR-ML-DEV-002 | Property test all numerical functions |
| AOR-ML-DEV-003 | Benchmark before and after optimization |
| AOR-ML-DEV-004 | Use Explorer for data exploration |
| AOR-ML-DEV-005 | Document tensor shapes in typespecs |

---

## Appendices

### A. Library Version Requirements

```elixir
# mix.exs
defp deps do
  [
    # Data Processing
    {:broadway, "~> 1.0"},
    {:gen_stage, "~> 1.2"},
    {:flow, "~> 1.2"},
    {:explorer, "~> 0.8"},

    # ML Core
    {:nx, "~> 0.7"},
    {:axon, "~> 0.6"},
    {:bumblebee, "~> 0.5"},
    {:scholar, "~> 0.3"},

    # Backends
    {:exla, "~> 0.7"},
    {:torchx, "~> 0.7"},
    {:ortex, "~> 0.1"},

    # Optimization
    {:polaris, "~> 0.1"}
  ]
end
```

### B. GPU Configuration

```bash
# NixOS configuration for CUDA
environment.systemPackages = with pkgs; [
  cudaPackages.cudatoolkit
  cudaPackages.cudnn
];

# Container GPU access
podman run --device nvidia.com/gpu=all ...
```

### C. Telemetry Events

```elixir
# ML telemetry events
[:indrajaal, :ml, :inference, :start]
[:indrajaal, :ml, :inference, :stop]
[:indrajaal, :ml, :training, :epoch]
[:indrajaal, :ml, :model, :loaded]
[:indrajaal, :ml, :prediction, :anomaly]
[:indrajaal, :ml, :constitutional, :check]
```

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP Compliance | SC-ML-001 through SC-ML-012 |
| Review Status | Draft |

---

*This document is part of the Indrajaal SIL-6 Biomorphic Fractal Mesh documentation suite.*
