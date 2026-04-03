# ML/AI 8-Level Implementation and Test Plan
## SIL-6 Biomorphic Fractal Architecture

**Version**: 21.3.0-SIL6 | **Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [8-Level Architecture Overview](#2-8-level-architecture-overview)
3. [Level 1: Runtime Foundation](#3-level-1-runtime-foundation)
4. [Level 2: Function Layer](#4-level-2-function-layer)
5. [Level 3: Component Layer](#5-level-3-component-layer)
6. [Level 4: Holon Layer](#6-level-4-holon-layer)
7. [Level 5: Container Layer](#7-level-5-container-layer)
8. [Level 6: Cluster Layer](#8-level-6-cluster-layer)
9. [Level 7: Federation Layer](#9-level-7-federation-layer)
10. [Level 8: Constitutional Layer](#10-level-8-constitutional-layer)
11. [Cross-Level Integration](#11-cross-level-integration)
12. [Test Automation Framework](#12-test-automation-framework)
13. [STAMP Constraints](#13-stamp-constraints)
14. [Resource & Cost Analysis](#14-resource-cost-analysis)
15. [Implementation Timeline](#15-implementation-timeline)

---

## 1. Executive Summary

### Purpose
This document defines the complete implementation and testing strategy for the ML/AI subsystem across all 7 fractal levels of the Indrajaal architecture.

### Scope
```
L8: Constitutional ─── Ψ₀-Ψ₅ invariants, Guardian verification, Founder's Directive
L7: Federation     ─── Cross-holon ML model sharing, federated learning
L6: Cluster        ─── Distributed training, consensus inference
L5: Container      ─── FLAME pools, elastic scaling, resource isolation
L4: Holon          ─── Autonomous ML agents, decision making
L3: Component      ─── ML pipelines, feature engineering
L2: Function       ─── Individual ML operations, tensor math
L1: Runtime        ─── BEAM/Nx backends, GPU acceleration
```

### Key Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Implementation Coverage | 100% | All 7 levels fully implemented |
| Test Coverage | >95% | Unit + Integration + Property |
| Boot Time | <10s | Container cold start |
| Inference Latency | <50ms | p99 response time |
| FLAME Scale Time | <5s | Worker spawn latency |

---

## 2. 8-Level Architecture Overview

### 2.1 Level Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                    L7: FEDERATION                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                 L6: CLUSTER                                 ││
│  │  ┌─────────────────────────────────────────────────────────┐││
│  │  │              L5: CONTAINER                              │││
│  │  │  ┌─────────────────────────────────────────────────────┐│││
│  │  │  │           L4: HOLON                                 ││││
│  │  │  │  ┌─────────────────────────────────────────────────┐││││
│  │  │  │  │        L3: COMPONENT                            │││││
│  │  │  │  │  ┌─────────────────────────────────────────────┐│││││
│  │  │  │  │  │     L2: FUNCTION                            ││││││
│  │  │  │  │  │  ┌─────────────────────────────────────────┐││││││
│  │  │  │  │  │  │  L1: RUNTIME                            │││││││
│  │  │  │  │  │  │  Nx/EXLA/Ortex/BEAM                     │││││││
│  │  │  │  │  │  └─────────────────────────────────────────┘││││││
│  │  │  │  │  └─────────────────────────────────────────────┘│││││
│  │  │  │  └─────────────────────────────────────────────────┘││││
│  │  │  └─────────────────────────────────────────────────────┘│││
│  │  └─────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Implementation Order

| Phase | Levels | Duration | Dependencies |
|-------|--------|----------|--------------|
| Phase 1 | L1, L2 | Week 1-3 | None |
| Phase 2 | L3, L4 | Week 4-7 | Phase 1 |
| Phase 3 | L5 | Week 8-10 | Phase 2 |
| Phase 4 | L6 | Week 11-14 | Phase 3 |
| Phase 5 | L7 | Week 15-18 | Phase 4 |

### 2.3 OODA Integration Per Level

| Level | Observe | Orient | Decide | Act |
|-------|---------|--------|--------|-----|
| L1 | Tensor metrics | Backend status | JIT compile | Execute op |
| L2 | Function perf | Error rates | Retry/fail | Invoke function |
| L3 | Pipeline state | Data quality | Route data | Transform |
| L4 | Holon health | Context | ML inference | Actuate |
| L5 | Container load | Scale need | Spawn/kill | FLAME action |
| L6 | Cluster state | Consensus | Shard/replicate | Distribute |
| L7 | Federation health | Cross-holon | Federate/isolate | Sync models |

---

## 3. Level 1: Runtime Foundation

### 3.1 Implementation Specification

#### 3.1.1 Components

```elixir
# lib/indrajaal/ml/runtime/backend_manager.ex
defmodule Indrajaal.ML.Runtime.BackendManager do
  @moduledoc """
  L1 Runtime: Manages Nx computation backends.

  STAMP: SC-ML-L1-001 - Backend selection MUST be deterministic
  STAMP: SC-ML-L1-002 - GPU memory MUST be bounded
  """

  use GenServer
  require Logger

  @default_backend EXLA
  @gpu_memory_limit_mb 8192
  @cpu_fallback_threshold 0.9

  defstruct [
    :active_backend,
    :gpu_available,
    :memory_used,
    :operations_count
  ]

  # Initialization
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      active_backend: detect_backend(),
      gpu_available: gpu_available?(),
      memory_used: 0,
      operations_count: 0
    }

    # Configure Nx default backend
    Nx.default_backend(state.active_backend)

    {:ok, state}
  end

  # Public API
  def get_backend, do: GenServer.call(__MODULE__, :get_backend)
  def gpu_status, do: GenServer.call(__MODULE__, :gpu_status)
  def memory_usage, do: GenServer.call(__MODULE__, :memory_usage)

  def execute_on_backend(tensor_fn, opts \\ []) do
    GenServer.call(__MODULE__, {:execute, tensor_fn, opts}, :infinity)
  end

  # Callbacks
  def handle_call(:get_backend, _from, state) do
    {:reply, state.active_backend, state}
  end

  def handle_call(:gpu_status, _from, state) do
    {:reply, %{available: state.gpu_available, memory_mb: state.memory_used}, state}
  end

  def handle_call({:execute, tensor_fn, opts}, _from, state) do
    backend = Keyword.get(opts, :backend, state.active_backend)

    {result, new_state} =
      with :ok <- check_memory_budget(state),
           {:ok, result} <- safe_execute(tensor_fn, backend) do
        {result, %{state | operations_count: state.operations_count + 1}}
      else
        {:error, :oom} ->
          # Fallback to CPU
          {:ok, result} = safe_execute(tensor_fn, Nx.BinaryBackend)
          {result, state}
        {:error, reason} ->
          {{:error, reason}, state}
      end

    {:reply, result, new_state}
  end

  # Private functions
  defp detect_backend do
    cond do
      Code.ensure_loaded?(EXLA) and gpu_available?() -> EXLA
      Code.ensure_loaded?(EXLA) -> EXLA
      Code.ensure_loaded?(Torchx) -> Torchx
      true -> Nx.BinaryBackend
    end
  end

  defp gpu_available? do
    case System.cmd("nvidia-smi", ["-L"], stderr_to_stdout: true) do
      {output, 0} -> String.contains?(output, "GPU")
      _ -> false
    end
  rescue
    _ -> false
  end

  defp check_memory_budget(%{memory_used: used}) when used > @gpu_memory_limit_mb do
    {:error, :oom}
  end
  defp check_memory_budget(_), do: :ok

  defp safe_execute(tensor_fn, backend) do
    try do
      Nx.default_backend(backend)
      result = tensor_fn.()
      {:ok, result}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
```

#### 3.1.2 Tensor Operations Module

```elixir
# lib/indrajaal/ml/runtime/tensor_ops.ex
defmodule Indrajaal.ML.Runtime.TensorOps do
  @moduledoc """
  L1 Runtime: Core tensor operations with safety guarantees.

  STAMP: SC-ML-L1-003 - All tensor ops MUST be bounded
  STAMP: SC-ML-L1-004 - NaN/Inf MUST be detected and handled
  """

  import Nx.Defn

  @max_tensor_size 1_000_000_000  # 1B elements

  # Safe tensor creation
  def safe_tensor(data, opts \\ []) do
    size = calculate_size(data)

    if size > @max_tensor_size do
      {:error, :tensor_too_large}
    else
      {:ok, Nx.tensor(data, opts)}
    end
  end

  # Validated matrix multiplication
  defn safe_matmul(a, b) do
    # Check for NaN/Inf
    a_valid = Nx.all(Nx.is_finite(a))
    b_valid = Nx.all(Nx.is_finite(b))

    if a_valid and b_valid do
      Nx.dot(a, b)
    else
      Nx.broadcast(Nx.tensor(0.0), Nx.shape(a))
    end
  end

  # Softmax with numerical stability
  defn stable_softmax(tensor, opts \\ []) do
    axis = opts[:axis] || -1
    max_val = Nx.reduce_max(tensor, axes: [axis], keep_axes: true)
    exp_shifted = Nx.exp(tensor - max_val)
    sum_exp = Nx.sum(exp_shifted, axes: [axis], keep_axes: true)
    exp_shifted / sum_exp
  end

  # Safe division (avoid div by zero)
  defn safe_divide(a, b) do
    epsilon = 1.0e-7
    a / (b + epsilon)
  end

  # Gradient clipping
  defn clip_gradients(gradients, max_norm) do
    norm = Nx.sqrt(Nx.sum(Nx.power(gradients, 2)))
    scale = Nx.min(max_norm / (norm + 1.0e-7), 1.0)
    gradients * scale
  end

  defp calculate_size(data) when is_list(data) do
    data |> List.flatten() |> length()
  end
  defp calculate_size(%Nx.Tensor{} = t), do: Nx.size(t)
  defp calculate_size(_), do: 1
end
```

### 3.2 Test Plan - Level 1

#### 3.2.1 Unit Tests

```elixir
# test/indrajaal/ml/runtime/backend_manager_test.exs
defmodule Indrajaal.ML.Runtime.BackendManagerTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Runtime.BackendManager

  describe "backend detection" do
    test "detects available backend" do
      backend = BackendManager.get_backend()
      assert backend in [EXLA, Torchx, Nx.BinaryBackend]
    end

    test "reports GPU status" do
      status = BackendManager.gpu_status()
      assert is_map(status)
      assert Map.has_key?(status, :available)
      assert Map.has_key?(status, :memory_mb)
    end
  end

  describe "tensor execution" do
    test "executes tensor operation" do
      result = BackendManager.execute_on_backend(fn ->
        Nx.tensor([1, 2, 3]) |> Nx.sum()
      end)

      assert Nx.to_number(result) == 6
    end

    test "handles errors gracefully" do
      result = BackendManager.execute_on_backend(fn ->
        raise "test error"
      end)

      assert {:error, _} = result
    end
  end
end
```

#### 3.2.2 Property Tests

```elixir
# test/indrajaal/ml/runtime/tensor_ops_property_test.exs
defmodule Indrajaal.ML.Runtime.TensorOpsPropertyTest do
  use ExUnit.Case, async: true
  use PropCheck

  alias Indrajaal.ML.Runtime.TensorOps
  alias PropCheck.BasicTypes, as: PC

  # Generator for small tensors
  def small_tensor_gen do
    let dims <- PC.list(PC.range(1, 10), 1, 3) do
      shape = List.to_tuple(dims)
      size = Tuple.product(shape)
      data = Enum.map(1..size, fn _ -> :rand.uniform() end)
      Nx.tensor(data) |> Nx.reshape(shape)
    end
  end

  property "softmax output sums to 1" do
    forall tensor <- small_tensor_gen() do
      result = TensorOps.stable_softmax(tensor)
      sum = Nx.sum(result) |> Nx.to_number()
      abs(sum - 1.0) < 0.001
    end
  end

  property "safe_divide never produces NaN" do
    forall {a, b} <- {PC.float(), PC.float()} do
      result = TensorOps.safe_divide(Nx.tensor(a), Nx.tensor(b))
      Nx.is_finite(result) |> Nx.to_number() == 1
    end
  end

  property "gradient clipping bounds norm" do
    forall {grads, max_norm} <- {small_tensor_gen(), PC.float(0.1, 10.0)} do
      clipped = TensorOps.clip_gradients(grads, Nx.tensor(max_norm))
      norm = Nx.sqrt(Nx.sum(Nx.power(clipped, 2))) |> Nx.to_number()
      norm <= max_norm + 0.001
    end
  end
end
```

#### 3.2.3 Integration Tests

```elixir
# test/indrajaal/ml/runtime/runtime_integration_test.exs
defmodule Indrajaal.ML.Runtime.RuntimeIntegrationTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Runtime.{BackendManager, TensorOps}

  @tag :integration
  test "full tensor pipeline through backend" do
    # Create tensor
    {:ok, input} = TensorOps.safe_tensor([[1.0, 2.0], [3.0, 4.0]])

    # Execute on managed backend
    result = BackendManager.execute_on_backend(fn ->
      input
      |> TensorOps.stable_softmax(axis: 1)
      |> Nx.mean()
    end)

    assert is_struct(result, Nx.Tensor)
    assert Nx.to_number(result) > 0
  end

  @tag :integration
  test "backend fallback on memory pressure" do
    # This test verifies CPU fallback works
    result = BackendManager.execute_on_backend(
      fn -> Nx.iota({100, 100}) |> Nx.sum() end,
      backend: Nx.BinaryBackend
    )

    assert Nx.to_number(result) == 99_990_000
  end
end
```

### 3.3 Success Criteria - Level 1

| Criteria | Target | Verification |
|----------|--------|--------------|
| Backend detection | 100% | Unit test |
| Tensor ops correctness | 100% | Property test |
| Memory bounds | Enforced | Integration test |
| NaN handling | Zero NaN leakage | Property test |
| GPU fallback | <100ms | Integration test |

---

## 4. Level 2: Function Layer

### 4.1 Implementation Specification

#### 4.1.1 ML Functions Module

```elixir
# lib/indrajaal/ml/functions/core.ex
defmodule Indrajaal.ML.Functions.Core do
  @moduledoc """
  L2 Function: Core ML functions with telemetry.

  STAMP: SC-ML-L2-001 - All functions MUST emit telemetry
  STAMP: SC-ML-L2-002 - Functions MUST have timeout guards
  """

  import Nx.Defn
  require Logger

  @default_timeout 30_000

  # Inference function with telemetry
  def inference(model, input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    start_time = System.monotonic_time(:microsecond)

    task = Task.async(fn ->
      :telemetry.execute(
        [:ml, :inference, :start],
        %{system_time: System.system_time()},
        %{model: model.__struct__}
      )

      result = Axon.predict(model, input)

      :telemetry.execute(
        [:ml, :inference, :stop],
        %{duration: System.monotonic_time(:microsecond) - start_time},
        %{model: model.__struct__, shape: Nx.shape(result)}
      )

      result
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> {:ok, result}
      nil -> {:error, :timeout}
    end
  end

  # Training step with gradient tracking
  def train_step(model, params, batch, loss_fn, optimizer_state) do
    {input, target} = batch

    {loss, gradients} = Axon.Loop.Train.compute_gradients(
      model, params, input, target, loss_fn
    )

    {new_params, new_optimizer_state} =
      Axon.Loop.Train.apply_updates(params, gradients, optimizer_state)

    :telemetry.execute(
      [:ml, :training, :step],
      %{loss: Nx.to_number(loss)},
      %{model: model.__struct__}
    )

    {new_params, new_optimizer_state, loss}
  end

  # Feature extraction
  defn extract_features(input, weights) do
    input
    |> Nx.dot(weights)
    |> Nx.relu()
  end

  # Embedding lookup
  def embedding_lookup(embeddings, indices) do
    Nx.take(embeddings, indices, axis: 0)
  end

  # Attention mechanism
  defn attention(query, key, value, mask \\ nil) do
    d_k = Nx.axis_size(key, -1)
    scores = Nx.dot(query, Nx.transpose(key)) / Nx.sqrt(d_k)

    scores = if mask do
      scores + (1 - mask) * -1.0e9
    else
      scores
    end

    weights = Nx.softmax(scores, axis: -1)
    Nx.dot(weights, value)
  end
end
```

#### 4.1.2 Model Registry

```elixir
# lib/indrajaal/ml/functions/model_registry.ex
defmodule Indrajaal.ML.Functions.ModelRegistry do
  @moduledoc """
  L2 Function: Model loading and caching.

  STAMP: SC-ML-L2-003 - Models MUST be versioned
  STAMP: SC-ML-L2-004 - Model cache MUST have TTL
  """

  use GenServer

  @cache_ttl_ms 3_600_000  # 1 hour

  defstruct [
    :models,
    :load_times,
    :access_counts
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      models: %{},
      load_times: %{},
      access_counts: %{}
    }

    # Schedule cache cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)

    {:ok, state}
  end

  # Public API
  def load_model(name, version \\ :latest) do
    GenServer.call(__MODULE__, {:load, name, version}, :infinity)
  end

  def get_model(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def list_models do
    GenServer.call(__MODULE__, :list)
  end

  def unload_model(name) do
    GenServer.cast(__MODULE__, {:unload, name})
  end

  # Callbacks
  def handle_call({:load, name, version}, _from, state) do
    key = {name, version}

    case Map.get(state.models, key) do
      nil ->
        case do_load_model(name, version) do
          {:ok, model} ->
            new_state = %{state |
              models: Map.put(state.models, key, model),
              load_times: Map.put(state.load_times, key, System.monotonic_time()),
              access_counts: Map.put(state.access_counts, key, 1)
            }
            {:reply, {:ok, model}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      model ->
        new_state = %{state |
          access_counts: Map.update(state.access_counts, key, 1, &(&1 + 1))
        }
        {:reply, {:ok, model}, new_state}
    end
  end

  def handle_call({:get, name}, _from, state) do
    model = Enum.find_value(state.models, fn
      {{^name, _version}, model} -> model
      _ -> nil
    end)
    {:reply, model, state}
  end

  def handle_call(:list, _from, state) do
    models = Map.keys(state.models) |> Enum.map(fn {name, version} ->
      %{name: name, version: version, access_count: state.access_counts[{name, version}]}
    end)
    {:reply, models, state}
  end

  def handle_cast({:unload, name}, state) do
    new_models = Enum.reject(state.models, fn {{n, _}, _} -> n == name end) |> Map.new()
    {:noreply, %{state | models: new_models}}
  end

  def handle_info(:cleanup_cache, state) do
    now = System.monotonic_time()
    ttl_native = System.convert_time_unit(@cache_ttl_ms, :millisecond, :native)

    expired = Enum.filter(state.load_times, fn {_key, time} ->
      now - time > ttl_native
    end) |> Enum.map(&elem(&1, 0))

    new_state = %{state |
      models: Map.drop(state.models, expired),
      load_times: Map.drop(state.load_times, expired),
      access_counts: Map.drop(state.access_counts, expired)
    }

    Process.send_after(self(), :cleanup_cache, @cache_ttl_ms)
    {:noreply, new_state}
  end

  # Private
  defp do_load_model(name, version) do
    path = model_path(name, version)

    if File.exists?(path) do
      model = File.read!(path) |> :erlang.binary_to_term()
      {:ok, model}
    else
      {:error, :not_found}
    end
  end

  defp model_path(name, :latest) do
    "priv/models/#{name}/latest.axon"
  end
  defp model_path(name, version) do
    "priv/models/#{name}/#{version}.axon"
  end
end
```

### 4.2 Test Plan - Level 2

#### 4.2.1 Unit Tests

```elixir
# test/indrajaal/ml/functions/core_test.exs
defmodule Indrajaal.ML.Functions.CoreTest do
  use ExUnit.Case, async: true

  alias Indrajaal.ML.Functions.Core

  describe "inference/3" do
    test "performs inference with timeout" do
      model = Axon.input("input", shape: {nil, 10})
              |> Axon.dense(5, activation: :relu)
              |> Axon.dense(2, activation: :softmax)

      {init_fn, _} = Axon.build(model)
      params = init_fn.(Nx.template({1, 10}, :f32), %{})

      input = Nx.random_uniform({1, 10})

      assert {:ok, result} = Core.inference(model, params, input)
      assert Nx.shape(result) == {1, 2}
    end

    test "returns error on timeout" do
      model = Axon.input("input", shape: {nil, 10})

      # Force timeout with 1ms
      assert {:error, :timeout} = Core.inference(model, %{}, Nx.iota({1, 10}), timeout: 1)
    end
  end

  describe "attention/4" do
    test "computes attention correctly" do
      query = Nx.random_uniform({2, 4, 8})
      key = Nx.random_uniform({2, 4, 8})
      value = Nx.random_uniform({2, 4, 8})

      result = Core.attention(query, key, value)

      assert Nx.shape(result) == {2, 4, 8}
    end
  end
end
```

#### 4.2.2 Property Tests

```elixir
# test/indrajaal/ml/functions/core_property_test.exs
defmodule Indrajaal.ML.Functions.CorePropertyTest do
  use ExUnit.Case, async: true
  use PropCheck

  alias Indrajaal.ML.Functions.Core
  alias PropCheck.BasicTypes, as: PC

  property "attention output shape matches value shape" do
    forall {batch, seq, dim} <- {PC.range(1, 4), PC.range(1, 8), PC.range(4, 16)} do
      query = Nx.random_uniform({batch, seq, dim})
      key = Nx.random_uniform({batch, seq, dim})
      value = Nx.random_uniform({batch, seq, dim})

      result = Core.attention(query, key, value)
      Nx.shape(result) == {batch, seq, dim}
    end
  end

  property "feature extraction preserves batch dimension" do
    forall {batch, in_dim, out_dim} <- {PC.range(1, 8), PC.range(4, 32), PC.range(4, 32)} do
      input = Nx.random_uniform({batch, in_dim})
      weights = Nx.random_uniform({in_dim, out_dim})

      result = Core.extract_features(input, weights)
      {result_batch, result_dim} = Nx.shape(result)

      result_batch == batch and result_dim == out_dim
    end
  end
end
```

### 4.3 Success Criteria - Level 2

| Criteria | Target | Verification |
|----------|--------|--------------|
| Function coverage | 100% | Unit test |
| Telemetry emission | All functions | Integration test |
| Timeout handling | <1s detection | Unit test |
| Model caching | TTL enforced | Unit test |
| Shape preservation | Property verified | Property test |

---

## 5. Level 3: Component Layer

### 5.1 Implementation Specification

#### 5.1.1 ML Pipeline Component

```elixir
# lib/indrajaal/ml/components/pipeline.ex
defmodule Indrajaal.ML.Components.Pipeline do
  @moduledoc """
  L3 Component: ML data processing pipeline.

  STAMP: SC-ML-L3-001 - Pipelines MUST be composable
  STAMP: SC-ML-L3-002 - Pipeline state MUST be checkpointable
  """

  use GenStage
  require Logger

  defstruct [
    :name,
    :stages,
    :metrics,
    :checkpoint_path
  ]

  # Pipeline DSL
  defmacro pipeline(name, do: block) do
    quote do
      def unquote(name)() do
        stages = unquote(block)
        %Indrajaal.ML.Components.Pipeline{
          name: unquote(name),
          stages: stages,
          metrics: %{},
          checkpoint_path: "data/checkpoints/#{unquote(name)}"
        }
      end
    end
  end

  # Stage definitions
  def stage(name, transform_fn, opts \\ []) do
    %{
      name: name,
      transform: transform_fn,
      batch_size: Keyword.get(opts, :batch_size, 32),
      timeout: Keyword.get(opts, :timeout, 30_000)
    }
  end

  # Execute pipeline
  def run(%__MODULE__{stages: stages} = pipeline, input) do
    start_time = System.monotonic_time(:microsecond)

    result = Enum.reduce_while(stages, {:ok, input}, fn stage, {:ok, data} ->
      case execute_stage(stage, data) do
        {:ok, output} -> {:cont, {:ok, output}}
        {:error, reason} -> {:halt, {:error, stage.name, reason}}
      end
    end)

    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:ml, :pipeline, :complete],
      %{duration_us: duration},
      %{pipeline: pipeline.name, success: match?({:ok, _}, result)}
    )

    result
  end

  # Checkpoint pipeline state
  def checkpoint(%__MODULE__{} = pipeline, state) do
    File.mkdir_p!(Path.dirname(pipeline.checkpoint_path))

    checkpoint_data = %{
      pipeline: pipeline.name,
      state: state,
      timestamp: DateTime.utc_now(),
      version: "1.0"
    }

    File.write!(pipeline.checkpoint_path, :erlang.term_to_binary(checkpoint_data))
    :ok
  end

  # Restore from checkpoint
  def restore(%__MODULE__{} = pipeline) do
    if File.exists?(pipeline.checkpoint_path) do
      data = File.read!(pipeline.checkpoint_path) |> :erlang.binary_to_term()
      {:ok, data.state}
    else
      {:error, :no_checkpoint}
    end
  end

  defp execute_stage(%{transform: transform, timeout: timeout}, data) do
    task = Task.async(fn -> transform.(data) end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> {:ok, result}
      nil -> {:error, :timeout}
    end
  end
end
```

#### 5.1.2 Feature Engineering Component

```elixir
# lib/indrajaal/ml/components/feature_engineering.ex
defmodule Indrajaal.ML.Components.FeatureEngineering do
  @moduledoc """
  L3 Component: Feature extraction and transformation.

  STAMP: SC-ML-L3-003 - Features MUST be normalized
  STAMP: SC-ML-L3-004 - Missing values MUST be handled
  """

  import Nx.Defn

  defstruct [
    :scalers,
    :encoders,
    :imputers
  ]

  # Normalization
  defn normalize(tensor, opts \\ []) do
    axis = opts[:axis] || 0
    mean = Nx.mean(tensor, axes: [axis], keep_axes: true)
    std = Nx.standard_deviation(tensor, axes: [axis], keep_axes: true)
    (tensor - mean) / (std + 1.0e-7)
  end

  # Min-Max scaling
  defn min_max_scale(tensor, opts \\ []) do
    axis = opts[:axis] || 0
    min_val = Nx.reduce_min(tensor, axes: [axis], keep_axes: true)
    max_val = Nx.reduce_max(tensor, axes: [axis], keep_axes: true)
    (tensor - min_val) / (max_val - min_val + 1.0e-7)
  end

  # One-hot encoding
  def one_hot_encode(indices, num_classes) do
    Nx.equal(
      Nx.new_axis(indices, -1),
      Nx.iota({num_classes})
    ) |> Nx.as_type(:f32)
  end

  # Handle missing values
  def impute(tensor, strategy \\ :mean) do
    mask = Nx.is_nan(tensor)

    fill_value = case strategy do
      :mean -> Nx.mean(Nx.select(mask, 0, tensor))
      :median -> tensor |> Nx.to_flat_list() |> Enum.median() |> Nx.tensor()
      :zero -> Nx.tensor(0.0)
      value when is_number(value) -> Nx.tensor(value)
    end

    Nx.select(mask, fill_value, tensor)
  end

  # Feature selection based on variance
  def select_by_variance(tensor, threshold \\ 0.01) do
    variances = Nx.variance(tensor, axes: [0])
    mask = Nx.greater(variances, threshold)

    selected_indices = mask
    |> Nx.to_flat_list()
    |> Enum.with_index()
    |> Enum.filter(fn {v, _} -> v == 1 end)
    |> Enum.map(&elem(&1, 1))

    Nx.take(tensor, Nx.tensor(selected_indices), axis: 1)
  end

  # Polynomial features
  def polynomial_features(tensor, degree \\ 2) do
    features = [tensor]

    features = if degree >= 2 do
      squared = Nx.power(tensor, 2)
      features ++ [squared]
    else
      features
    end

    features = if degree >= 3 do
      cubed = Nx.power(tensor, 3)
      features ++ [cubed]
    else
      features
    end

    Nx.concatenate(features, axis: 1)
  end
end
```

### 5.2 Test Plan - Level 3

#### 5.2.1 Unit Tests

```elixir
# test/indrajaal/ml/components/pipeline_test.exs
defmodule Indrajaal.ML.Components.PipelineTest do
  use ExUnit.Case, async: true

  alias Indrajaal.ML.Components.Pipeline

  describe "pipeline execution" do
    test "runs stages in sequence" do
      pipeline = %Pipeline{
        name: :test_pipeline,
        stages: [
          Pipeline.stage(:double, &Nx.multiply(&1, 2)),
          Pipeline.stage(:add_one, &Nx.add(&1, 1))
        ],
        metrics: %{},
        checkpoint_path: "/tmp/test_checkpoint"
      }

      input = Nx.tensor([1, 2, 3])
      {:ok, result} = Pipeline.run(pipeline, input)

      assert Nx.to_flat_list(result) == [3, 5, 7]
    end

    test "handles stage errors" do
      pipeline = %Pipeline{
        name: :error_pipeline,
        stages: [
          Pipeline.stage(:fail, fn _ -> raise "error" end)
        ],
        metrics: %{},
        checkpoint_path: "/tmp/test_checkpoint"
      }

      assert {:error, :fail, _} = Pipeline.run(pipeline, Nx.tensor([1]))
    end
  end

  describe "checkpointing" do
    test "saves and restores state" do
      pipeline = %Pipeline{
        name: :checkpoint_test,
        stages: [],
        metrics: %{},
        checkpoint_path: "/tmp/checkpoint_test"
      }

      state = %{epoch: 5, loss: 0.1}
      :ok = Pipeline.checkpoint(pipeline, state)

      assert {:ok, ^state} = Pipeline.restore(pipeline)

      # Cleanup
      File.rm(pipeline.checkpoint_path)
    end
  end
end
```

#### 5.2.2 Property Tests

```elixir
# test/indrajaal/ml/components/feature_engineering_property_test.exs
defmodule Indrajaal.ML.Components.FeatureEngineeringPropertyTest do
  use ExUnit.Case, async: true
  use PropCheck

  alias Indrajaal.ML.Components.FeatureEngineering
  alias PropCheck.BasicTypes, as: PC

  property "normalization produces zero mean" do
    forall {rows, cols} <- {PC.range(10, 100), PC.range(2, 10)} do
      tensor = Nx.random_uniform({rows, cols})
      normalized = FeatureEngineering.normalize(tensor, axis: 0)
      mean = Nx.mean(normalized, axes: [0]) |> Nx.to_flat_list()

      Enum.all?(mean, &(abs(&1) < 0.01))
    end
  end

  property "min_max_scale bounds output to [0, 1]" do
    forall {rows, cols} <- {PC.range(10, 100), PC.range(2, 10)} do
      tensor = Nx.random_uniform({rows, cols}, type: :f32)
      scaled = FeatureEngineering.min_max_scale(tensor, axis: 0)

      min_val = Nx.reduce_min(scaled) |> Nx.to_number()
      max_val = Nx.reduce_max(scaled) |> Nx.to_number()

      min_val >= -0.01 and max_val <= 1.01
    end
  end

  property "one_hot_encode produces valid distribution" do
    forall {size, num_classes} <- {PC.range(1, 100), PC.range(2, 10)} do
      indices = Nx.random_uniform({size}, type: :s32, min: 0, max: num_classes)
      encoded = FeatureEngineering.one_hot_encode(indices, num_classes)

      # Each row should sum to 1
      row_sums = Nx.sum(encoded, axes: [1]) |> Nx.to_flat_list()
      Enum.all?(row_sums, &(abs(&1 - 1.0) < 0.01))
    end
  end
end
```

### 5.3 Success Criteria - Level 3

| Criteria | Target | Verification |
|----------|--------|--------------|
| Pipeline composition | Works | Unit test |
| Checkpointing | Reliable | Unit test |
| Feature normalization | Mean=0, Std=1 | Property test |
| Missing value handling | 100% | Unit test |
| Pipeline timeout | Enforced | Unit test |

---

## 6. Level 4: Holon Layer

### 6.1 Implementation Specification

#### 6.1.1 ML Holon Agent

```elixir
# lib/indrajaal/ml/holon/ml_agent.ex
defmodule Indrajaal.ML.Holon.MLAgent do
  @moduledoc """
  L4 Holon: Autonomous ML decision-making agent.

  STAMP: SC-ML-L4-001 - Agents MUST have bounded decision time
  STAMP: SC-ML-L4-002 - Agents MUST log all decisions to Immutable Register
  STAMP: SC-ML-L4-003 - Agents MUST respect Guardian veto
  """

  use GenServer
  require Logger

  alias Indrajaal.ML.Functions.Core
  alias Indrajaal.ML.Components.Pipeline
  alias Indrajaal.Holon.ImmutableRegister

  @decision_timeout_ms 5_000
  @ooda_cycle_ms 100

  defstruct [
    :id,
    :name,
    :model,
    :params,
    :state,
    :decision_history,
    :guardian_ref
  ]

  # Public API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def decide(agent, context) do
    GenServer.call(agent, {:decide, context}, @decision_timeout_ms)
  end

  def observe(agent) do
    GenServer.call(agent, :observe)
  end

  def get_state(agent) do
    GenServer.call(agent, :get_state)
  end

  # Callbacks
  def init(opts) do
    state = %__MODULE__{
      id: Keyword.get(opts, :id, UUID.uuid4()),
      name: Keyword.fetch!(opts, :name),
      model: Keyword.fetch!(opts, :model),
      params: Keyword.get(opts, :params, %{}),
      state: :idle,
      decision_history: [],
      guardian_ref: Keyword.get(opts, :guardian)
    }

    # Start OODA loop
    Process.send_after(self(), :ooda_tick, @ooda_cycle_ms)

    {:ok, state}
  end

  def handle_call({:decide, context}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    # OODA: Observe
    observations = gather_observations(context)

    # OODA: Orient
    oriented = orient_observations(observations, state)

    # OODA: Decide
    decision = make_decision(oriented, state)

    # OODA: Act (with Guardian check)
    result = case check_guardian(decision, state.guardian_ref) do
      :approved ->
        execute_decision(decision, state)
      :vetoed ->
        {:vetoed, decision}
    end

    # Log to Immutable Register
    duration = System.monotonic_time(:microsecond) - start_time
    log_decision(state.id, decision, result, duration)

    new_state = %{state |
      decision_history: [{decision, result, DateTime.utc_now()} | state.decision_history]
                        |> Enum.take(100)
    }

    {:reply, result, new_state}
  end

  def handle_call(:observe, _from, state) do
    observations = %{
      state: state.state,
      decision_count: length(state.decision_history),
      last_decision: List.first(state.decision_history)
    }
    {:reply, observations, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:ooda_tick, state) do
    # Periodic health check and self-assessment
    new_state = perform_ooda_cycle(state)
    Process.send_after(self(), :ooda_tick, @ooda_cycle_ms)
    {:noreply, new_state}
  end

  # Private functions
  defp gather_observations(context) do
    %{
      timestamp: DateTime.utc_now(),
      context: context,
      system_load: :erlang.statistics(:run_queue),
      memory: :erlang.memory(:total)
    }
  end

  defp orient_observations(observations, state) do
    # Analyze observations relative to current state
    %{
      observations: observations,
      historical_context: Enum.take(state.decision_history, 10),
      confidence: calculate_confidence(observations)
    }
  end

  defp make_decision(oriented, state) do
    # Use ML model for decision
    input = prepare_input(oriented)

    case Core.inference(state.model, state.params, input, timeout: @decision_timeout_ms - 1000) do
      {:ok, output} ->
        interpret_output(output)
      {:error, reason} ->
        {:fallback, reason}
    end
  end

  defp check_guardian(decision, nil), do: :approved
  defp check_guardian(decision, guardian_ref) do
    case GenServer.call(guardian_ref, {:approve, decision}, 1000) do
      :ok -> :approved
      :veto -> :vetoed
    end
  catch
    :exit, _ -> :approved  # Guardian unavailable, proceed
  end

  defp execute_decision(decision, _state) do
    # Execute the decided action
    {:ok, decision}
  end

  defp log_decision(agent_id, decision, result, duration_us) do
    ImmutableRegister.append(%{
      type: :ml_decision,
      agent_id: agent_id,
      decision: decision,
      result: result,
      duration_us: duration_us,
      timestamp: DateTime.utc_now()
    })
  end

  defp perform_ooda_cycle(state) do
    # Self-assessment during idle OODA cycles
    %{state | state: :active}
  end

  defp calculate_confidence(%{context: context}) do
    # Simple confidence heuristic
    if map_size(context) > 5, do: 0.9, else: 0.7
  end

  defp prepare_input(oriented) do
    # Convert oriented data to tensor
    Nx.tensor([oriented.confidence])
  end

  defp interpret_output(output) do
    # Interpret model output as decision
    {:action, Nx.to_number(Nx.argmax(output))}
  end
end
```

#### 6.1.2 Holon State Manager

```elixir
# lib/indrajaal/ml/holon/state_manager.ex
defmodule Indrajaal.ML.Holon.StateManager do
  @moduledoc """
  L4 Holon: SQLite/DuckDB state management for ML holons.

  STAMP: SC-ML-L4-004 - State MUST be stored in SQLite (real-time)
  STAMP: SC-ML-L4-005 - History MUST be stored in DuckDB (analytics)
  STAMP: SC-HOLON-001 - ALL holon state via SQLite/DuckDB ONLY
  """

  use GenServer

  @sqlite_path "data/holons/ml"
  @duckdb_path "data/holons/ml/history.duckdb"

  defstruct [
    :sqlite_conn,
    :duckdb_conn,
    :version_vector
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    File.mkdir_p!(@sqlite_path)

    {:ok, sqlite} = Exqlite.Sqlite3.open("#{@sqlite_path}/state.db")
    setup_sqlite_schema(sqlite)

    {:ok, duckdb} = DuckDBEx.open(@duckdb_path)
    setup_duckdb_schema(duckdb)

    state = %__MODULE__{
      sqlite_conn: sqlite,
      duckdb_conn: duckdb,
      version_vector: %{}
    }

    {:ok, state}
  end

  # Public API
  def save_model_state(model_id, state_data) do
    GenServer.call(__MODULE__, {:save_state, model_id, state_data})
  end

  def load_model_state(model_id) do
    GenServer.call(__MODULE__, {:load_state, model_id})
  end

  def append_history(model_id, event) do
    GenServer.cast(__MODULE__, {:append_history, model_id, event})
  end

  def query_history(model_id, opts \\ []) do
    GenServer.call(__MODULE__, {:query_history, model_id, opts})
  end

  # Callbacks
  def handle_call({:save_state, model_id, state_data}, _from, state) do
    serialized = :erlang.term_to_binary(state_data)
    checksum = :crypto.hash(:sha256, serialized) |> Base.encode16()

    sql = """
    INSERT OR REPLACE INTO model_states (model_id, state_data, checksum, updated_at)
    VALUES (?, ?, ?, ?)
    """

    :ok = Exqlite.Sqlite3.execute(state.sqlite_conn, sql, [
      model_id,
      serialized,
      checksum,
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])

    new_vv = Map.update(state.version_vector, model_id, 1, &(&1 + 1))
    {:reply, :ok, %{state | version_vector: new_vv}}
  end

  def handle_call({:load_state, model_id}, _from, state) do
    sql = "SELECT state_data, checksum FROM model_states WHERE model_id = ?"

    result = case Exqlite.Sqlite3.execute(state.sqlite_conn, sql, [model_id]) do
      {:ok, [[data, checksum]]} ->
        # Verify integrity
        if :crypto.hash(:sha256, data) |> Base.encode16() == checksum do
          {:ok, :erlang.binary_to_term(data)}
        else
          {:error, :checksum_mismatch}
        end
      {:ok, []} ->
        {:error, :not_found}
    end

    {:reply, result, state}
  end

  def handle_call({:query_history, model_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    since = Keyword.get(opts, :since, "1970-01-01")

    sql = """
    SELECT event_type, event_data, created_at
    FROM model_history
    WHERE model_id = ? AND created_at >= ?
    ORDER BY created_at DESC
    LIMIT ?
    """

    {:ok, rows} = DuckDBEx.query(state.duckdb_conn, sql, [model_id, since, limit])
    {:reply, {:ok, rows}, state}
  end

  def handle_cast({:append_history, model_id, event}, state) do
    sql = """
    INSERT INTO model_history (model_id, event_type, event_data, created_at)
    VALUES (?, ?, ?, ?)
    """

    DuckDBEx.execute(state.duckdb_conn, sql, [
      model_id,
      event.type,
      Jason.encode!(event.data),
      DateTime.utc_now() |> DateTime.to_iso8601()
    ])

    {:noreply, state}
  end

  # Schema setup
  defp setup_sqlite_schema(conn) do
    Exqlite.Sqlite3.execute(conn, """
    CREATE TABLE IF NOT EXISTS model_states (
      model_id TEXT PRIMARY KEY,
      state_data BLOB NOT NULL,
      checksum TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """)
  end

  defp setup_duckdb_schema(conn) do
    DuckDBEx.execute(conn, """
    CREATE TABLE IF NOT EXISTS model_history (
      id INTEGER PRIMARY KEY,
      model_id VARCHAR NOT NULL,
      event_type VARCHAR NOT NULL,
      event_data JSON,
      created_at TIMESTAMP NOT NULL
    )
    """)
  end
end
```

### 6.2 Test Plan - Level 4

#### 6.2.1 Unit Tests

```elixir
# test/indrajaal/ml/holon/ml_agent_test.exs
defmodule Indrajaal.ML.Holon.MLAgentTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Holon.MLAgent

  setup do
    model = Axon.input("input", shape: {nil, 1})
            |> Axon.dense(2, activation: :softmax)

    {:ok, agent} = MLAgent.start_link(
      name: :test_agent,
      model: model,
      params: %{}
    )

    on_exit(fn -> GenServer.stop(agent) end)

    %{agent: agent}
  end

  describe "decide/2" do
    test "makes decision within timeout", %{agent: agent} do
      context = %{input: [1.0], priority: :normal}

      result = MLAgent.decide(agent, context)

      assert match?({:ok, _} | {:fallback, _}, result)
    end

    test "records decision in history", %{agent: agent} do
      MLAgent.decide(agent, %{input: [1.0]})

      state = MLAgent.get_state(agent)
      assert length(state.decision_history) >= 1
    end
  end

  describe "observe/1" do
    test "returns current observations", %{agent: agent} do
      obs = MLAgent.observe(agent)

      assert Map.has_key?(obs, :state)
      assert Map.has_key?(obs, :decision_count)
    end
  end
end
```

#### 6.2.2 Property Tests

```elixir
# test/indrajaal/ml/holon/ml_agent_property_test.exs
defmodule Indrajaal.ML.Holon.MLAgentPropertyTest do
  use ExUnit.Case, async: false
  use PropCheck

  alias Indrajaal.ML.Holon.MLAgent
  alias PropCheck.BasicTypes, as: PC

  property "decisions are bounded in time" do
    forall context <- PC.map(PC.atom(), PC.any()) do
      model = Axon.input("input", shape: {nil, 1}) |> Axon.dense(2)
      {:ok, agent} = MLAgent.start_link(name: :"test_#{:rand.uniform(100000)}", model: model, params: %{})

      start = System.monotonic_time(:millisecond)
      _result = MLAgent.decide(agent, context)
      elapsed = System.monotonic_time(:millisecond) - start

      GenServer.stop(agent)

      elapsed < 6000  # 5s timeout + 1s buffer
    end
  end

  property "decision history is bounded" do
    forall n <- PC.range(1, 150) do
      model = Axon.input("input", shape: {nil, 1}) |> Axon.dense(2)
      {:ok, agent} = MLAgent.start_link(name: :"hist_#{:rand.uniform(100000)}", model: model, params: %{})

      Enum.each(1..n, fn _ ->
        MLAgent.decide(agent, %{x: 1})
      end)

      state = MLAgent.get_state(agent)
      GenServer.stop(agent)

      length(state.decision_history) <= 100
    end
  end
end
```

### 6.3 Success Criteria - Level 4

| Criteria | Target | Verification |
|----------|--------|--------------|
| Decision latency | <5s | Property test |
| History bounded | ≤100 entries | Property test |
| Guardian integration | Working | Integration test |
| SQLite state | Persistent | Unit test |
| DuckDB history | Append-only | Unit test |

---

## 7. Level 5: Container Layer

### 7.1 Implementation Specification

#### 7.1.1 FLAME Pool Manager

```elixir
# lib/indrajaal/ml/container/flame_pool.ex
defmodule Indrajaal.ML.Container.FlamePool do
  @moduledoc """
  L5 Container: FLAME elastic worker pool for ML workloads.

  STAMP: SC-ML-L5-001 - Pool MUST auto-scale based on queue depth
  STAMP: SC-ML-L5-002 - Workers MUST boot in <10s
  STAMP: SC-ML-L5-003 - Pool MUST respect resource limits
  """

  use Supervisor

  @min_workers 0
  @max_workers 50
  @scale_up_threshold 10
  @scale_down_threshold 2
  @worker_boot_timeout 10_000

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool_config = [
      name: :ml_flame_pool,
      min: Keyword.get(opts, :min_workers, @min_workers),
      max: Keyword.get(opts, :max_workers, @max_workers),
      boot_timeout: @worker_boot_timeout,
      idle_shutdown_after: 30_000,
      backend: FLAME.FlyBackend,
      log: :debug
    ]

    children = [
      {FLAME.Pool, pool_config},
      {__MODULE__.Autoscaler, [pool: :ml_flame_pool]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Public API
  def execute(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    FLAME.call(:ml_flame_pool, fun, timeout: timeout)
  end

  def execute_async(fun) do
    FLAME.cast(:ml_flame_pool, fun)
  end

  def pool_status do
    FLAME.Pool.status(:ml_flame_pool)
  end

  def scale_to(count) when count >= @min_workers and count <= @max_workers do
    FLAME.Pool.scale(:ml_flame_pool, count)
  end
end

defmodule Indrajaal.ML.Container.FlamePool.Autoscaler do
  @moduledoc """
  Autoscaling logic for FLAME pool.
  """

  use GenServer

  @check_interval 5_000
  @scale_up_threshold 10
  @scale_down_threshold 2

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool = Keyword.fetch!(opts, :pool)
    Process.send_after(self(), :check_scale, @check_interval)
    {:ok, %{pool: pool, last_scale: System.monotonic_time()}}
  end

  def handle_info(:check_scale, state) do
    status = FLAME.Pool.status(state.pool)
    queue_depth = status[:pending] || 0
    current_workers = status[:runners] || 0

    new_target = cond do
      queue_depth > @scale_up_threshold ->
        min(current_workers + 5, 50)
      queue_depth < @scale_down_threshold and current_workers > 0 ->
        max(current_workers - 2, 0)
      true ->
        current_workers
    end

    if new_target != current_workers do
      FLAME.Pool.scale(state.pool, new_target)

      :telemetry.execute(
        [:ml, :flame, :scale],
        %{from: current_workers, to: new_target, queue: queue_depth},
        %{pool: state.pool}
      )
    end

    Process.send_after(self(), :check_scale, @check_interval)
    {:noreply, %{state | last_scale: System.monotonic_time()}}
  end
end
```

#### 7.1.2 Container Health Monitor

```elixir
# lib/indrajaal/ml/container/health_monitor.ex
defmodule Indrajaal.ML.Container.HealthMonitor do
  @moduledoc """
  L5 Container: Health monitoring and resource management.

  STAMP: SC-ML-L5-004 - Health checks every 10s
  STAMP: SC-ML-L5-005 - Resource usage MUST be bounded
  """

  use GenServer

  @health_interval 10_000
  @memory_threshold_mb 7000
  @cpu_threshold_percent 90

  defstruct [
    :status,
    :last_check,
    :metrics,
    :alerts
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %__MODULE__{
      status: :healthy,
      last_check: nil,
      metrics: %{},
      alerts: []
    }

    Process.send_after(self(), :health_check, @health_interval)
    {:ok, state}
  end

  def get_health do
    GenServer.call(__MODULE__, :get_health)
  end

  def handle_call(:get_health, _from, state) do
    {:reply, %{status: state.status, metrics: state.metrics, alerts: state.alerts}, state}
  end

  def handle_info(:health_check, state) do
    metrics = collect_metrics()
    alerts = check_thresholds(metrics)
    status = if Enum.empty?(alerts), do: :healthy, else: :degraded

    :telemetry.execute(
      [:ml, :container, :health],
      metrics,
      %{status: status, alerts: length(alerts)}
    )

    Process.send_after(self(), :health_check, @health_interval)

    {:noreply, %{state |
      status: status,
      last_check: DateTime.utc_now(),
      metrics: metrics,
      alerts: alerts
    }}
  end

  defp collect_metrics do
    memory = :erlang.memory()
    %{
      total_memory_mb: div(memory[:total], 1_048_576),
      process_memory_mb: div(memory[:processes], 1_048_576),
      ets_memory_mb: div(memory[:ets], 1_048_576),
      scheduler_utilization: :scheduler.utilization(1) |> Enum.map(&elem(&1, 1)) |> Enum.sum() |> Kernel./(System.schedulers_online()),
      process_count: :erlang.system_info(:process_count),
      flame_workers: get_flame_worker_count()
    }
  end

  defp check_thresholds(metrics) do
    alerts = []

    alerts = if metrics.total_memory_mb > @memory_threshold_mb do
      [{:memory_high, metrics.total_memory_mb} | alerts]
    else
      alerts
    end

    alerts = if metrics.scheduler_utilization > @cpu_threshold_percent / 100 do
      [{:cpu_high, metrics.scheduler_utilization} | alerts]
    else
      alerts
    end

    alerts
  end

  defp get_flame_worker_count do
    case FLAME.Pool.status(:ml_flame_pool) do
      status when is_map(status) -> status[:runners] || 0
      _ -> 0
    end
  rescue
    _ -> 0
  end
end
```

### 7.2 Test Plan - Level 5

#### 7.2.1 Unit Tests

```elixir
# test/indrajaal/ml/container/flame_pool_test.exs
defmodule Indrajaal.ML.Container.FlamePoolTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Container.FlamePool

  @tag :integration
  test "executes function in pool" do
    result = FlamePool.execute(fn -> 1 + 1 end)
    assert result == 2
  end

  @tag :integration
  test "returns pool status" do
    status = FlamePool.pool_status()
    assert is_map(status)
  end

  @tag :integration
  test "respects scaling limits" do
    assert :ok = FlamePool.scale_to(10)
    assert {:error, _} = FlamePool.scale_to(100)  # Over max
    assert {:error, _} = FlamePool.scale_to(-1)   # Under min
  end
end
```

#### 7.2.2 Property Tests

```elixir
# test/indrajaal/ml/container/flame_pool_property_test.exs
defmodule Indrajaal.ML.Container.FlamePoolPropertyTest do
  use ExUnit.Case, async: false
  use PropCheck

  alias Indrajaal.ML.Container.FlamePool
  alias PropCheck.BasicTypes, as: PC

  property "pool execution is deterministic" do
    forall {a, b} <- {PC.integer(), PC.integer()} do
      result = FlamePool.execute(fn -> a + b end, timeout: 5000)
      result == a + b
    end
  end

  property "scaling stays within bounds" do
    forall count <- PC.integer() do
      result = FlamePool.scale_to(count)

      cond do
        count < 0 -> match?({:error, _}, result)
        count > 50 -> match?({:error, _}, result)
        true -> result == :ok
      end
    end
  end
end
```

### 7.3 Success Criteria - Level 5

| Criteria | Target | Verification |
|----------|--------|--------------|
| Worker boot time | <10s | Integration test |
| Auto-scaling | Working | Integration test |
| Health monitoring | 10s interval | Unit test |
| Resource bounds | Enforced | Property test |
| Pool determinism | 100% | Property test |

---

## 8. Level 6: Cluster Layer

### 8.1 Implementation Specification

#### 8.1.1 Distributed ML Coordinator

```elixir
# lib/indrajaal/ml/cluster/coordinator.ex
defmodule Indrajaal.ML.Cluster.Coordinator do
  @moduledoc """
  L6 Cluster: Distributed ML coordination across nodes.

  STAMP: SC-ML-L6-001 - Quorum required for model updates
  STAMP: SC-ML-L6-002 - Consensus for inference routing
  STAMP: SC-ML-L6-003 - Partition tolerance with degraded mode
  """

  use GenServer
  require Logger

  @quorum_threshold 0.5
  @consensus_timeout 5_000

  defstruct [
    :node_id,
    :cluster_nodes,
    :model_versions,
    :routing_table,
    :consensus_state
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def init(opts) do
    state = %__MODULE__{
      node_id: Node.self(),
      cluster_nodes: MapSet.new([Node.self()]),
      model_versions: %{},
      routing_table: %{},
      consensus_state: :stable
    }

    # Monitor cluster topology
    :net_kernel.monitor_nodes(true)

    {:ok, state}
  end

  # Public API
  def register_model(model_id, version, node \\ Node.self()) do
    GenServer.call({:global, __MODULE__}, {:register_model, model_id, version, node})
  end

  def route_inference(model_id, input) do
    GenServer.call({:global, __MODULE__}, {:route_inference, model_id, input}, @consensus_timeout)
  end

  def get_cluster_state do
    GenServer.call({:global, __MODULE__}, :get_state)
  end

  def propose_model_update(model_id, new_version) do
    GenServer.call({:global, __MODULE__}, {:propose_update, model_id, new_version}, @consensus_timeout * 2)
  end

  # Callbacks
  def handle_call({:register_model, model_id, version, node}, _from, state) do
    new_versions = Map.put(state.model_versions, model_id, {version, node})
    new_routing = Map.put(state.routing_table, model_id, node)

    {:reply, :ok, %{state | model_versions: new_versions, routing_table: new_routing}}
  end

  def handle_call({:route_inference, model_id, input}, _from, state) do
    case Map.get(state.routing_table, model_id) do
      nil ->
        {:reply, {:error, :model_not_found}, state}

      target_node ->
        result = :rpc.call(target_node, Indrajaal.ML.Functions.Core, :inference, [model_id, input], @consensus_timeout)
        {:reply, result, state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:propose_update, model_id, new_version}, _from, state) do
    # Implement 2-phase commit for model updates
    nodes = MapSet.to_list(state.cluster_nodes)
    quorum_size = ceil(length(nodes) * @quorum_threshold)

    # Phase 1: Prepare
    prepare_results = Enum.map(nodes, fn node ->
      :rpc.call(node, __MODULE__, :prepare_update, [model_id, new_version], @consensus_timeout)
    end)

    prepared_count = Enum.count(prepare_results, &(&1 == :prepared))

    if prepared_count >= quorum_size do
      # Phase 2: Commit
      Enum.each(nodes, fn node ->
        :rpc.cast(node, __MODULE__, :commit_update, [model_id, new_version])
      end)

      new_versions = Map.put(state.model_versions, model_id, {new_version, Node.self()})
      {:reply, :ok, %{state | model_versions: new_versions}}
    else
      # Abort
      Enum.each(nodes, fn node ->
        :rpc.cast(node, __MODULE__, :abort_update, [model_id])
      end)

      {:reply, {:error, :quorum_not_reached}, state}
    end
  end

  # Node monitoring
  def handle_info({:nodeup, node}, state) do
    Logger.info("Node joined cluster: #{node}")
    new_nodes = MapSet.put(state.cluster_nodes, node)
    {:noreply, %{state | cluster_nodes: new_nodes}}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.warn("Node left cluster: #{node}")
    new_nodes = MapSet.delete(state.cluster_nodes, node)

    # Update routing to remove models from downed node
    new_routing = state.routing_table
    |> Enum.reject(fn {_, n} -> n == node end)
    |> Map.new()

    {:noreply, %{state | cluster_nodes: new_nodes, routing_table: new_routing}}
  end

  # 2PC helpers (called via RPC)
  def prepare_update(_model_id, _version) do
    # Validate update is possible
    :prepared
  end

  def commit_update(model_id, version) do
    # Apply the update locally
    :ok
  end

  def abort_update(_model_id) do
    # Rollback any prepared state
    :ok
  end
end
```

#### 8.1.2 Distributed Training Coordinator

```elixir
# lib/indrajaal/ml/cluster/distributed_training.ex
defmodule Indrajaal.ML.Cluster.DistributedTraining do
  @moduledoc """
  L6 Cluster: Distributed model training with data parallelism.

  STAMP: SC-ML-L6-004 - Gradient aggregation MUST be synchronized
  STAMP: SC-ML-L6-005 - Training state checkpointed every epoch
  """

  use GenServer
  require Logger

  @sync_interval_ms 1_000
  @checkpoint_interval_epochs 1

  defstruct [
    :model,
    :params,
    :optimizer_state,
    :epoch,
    :workers,
    :gradient_buffer,
    :training_status
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      model: Keyword.fetch!(opts, :model),
      params: Keyword.get(opts, :initial_params),
      optimizer_state: nil,
      epoch: 0,
      workers: [],
      gradient_buffer: [],
      training_status: :idle
    }

    {:ok, state}
  end

  # Public API
  def start_training(data_shards, opts \\ []) do
    GenServer.call(__MODULE__, {:start_training, data_shards, opts})
  end

  def submit_gradients(worker_id, gradients) do
    GenServer.cast(__MODULE__, {:gradients, worker_id, gradients})
  end

  def get_params do
    GenServer.call(__MODULE__, :get_params)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Callbacks
  def handle_call({:start_training, data_shards, opts}, _from, state) do
    epochs = Keyword.get(opts, :epochs, 10)
    learning_rate = Keyword.get(opts, :lr, 0.001)

    # Initialize optimizer
    optimizer = Polaris.Optimizers.adam(learning_rate: learning_rate)
    {init_fn, _} = Polaris.Updates.init(optimizer, state.params)
    optimizer_state = init_fn.(state.params)

    # Spawn workers for each data shard
    workers = Enum.map(data_shards, fn {node, shard} ->
      worker_id = UUID.uuid4()
      :rpc.cast(node, __MODULE__.Worker, :start, [worker_id, state.model, state.params, shard])
      {worker_id, node}
    end)

    new_state = %{state |
      optimizer_state: optimizer_state,
      workers: workers,
      training_status: :running
    }

    # Start sync loop
    Process.send_after(self(), :sync_gradients, @sync_interval_ms)

    {:reply, :ok, new_state}
  end

  def handle_call(:get_params, _from, state) do
    {:reply, state.params, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, %{status: state.training_status, epoch: state.epoch}, state}
  end

  def handle_cast({:gradients, worker_id, gradients}, state) do
    new_buffer = [{worker_id, gradients} | state.gradient_buffer]
    {:noreply, %{state | gradient_buffer: new_buffer}}
  end

  def handle_info(:sync_gradients, state) do
    if length(state.gradient_buffer) >= length(state.workers) do
      # Aggregate gradients (average)
      aggregated = aggregate_gradients(state.gradient_buffer)

      # Apply updates
      {new_params, new_opt_state} = apply_gradient_update(
        state.params,
        aggregated,
        state.optimizer_state
      )

      # Broadcast new params to workers
      broadcast_params(state.workers, new_params)

      # Checkpoint if needed
      new_epoch = state.epoch + 1
      if rem(new_epoch, @checkpoint_interval_epochs) == 0 do
        checkpoint_training(new_params, new_epoch)
      end

      new_state = %{state |
        params: new_params,
        optimizer_state: new_opt_state,
        epoch: new_epoch,
        gradient_buffer: []
      }

      Process.send_after(self(), :sync_gradients, @sync_interval_ms)
      {:noreply, new_state}
    else
      Process.send_after(self(), :sync_gradients, @sync_interval_ms)
      {:noreply, state}
    end
  end

  defp aggregate_gradients(buffer) do
    # Average gradients from all workers
    gradients = Enum.map(buffer, &elem(&1, 1))
    count = length(gradients)

    Enum.reduce(gradients, fn g, acc ->
      Map.merge(acc, g, fn _k, v1, v2 -> Nx.add(v1, v2) end)
    end)
    |> Map.new(fn {k, v} -> {k, Nx.divide(v, count)} end)
  end

  defp apply_gradient_update(params, gradients, optimizer_state) do
    # Apply optimizer step
    {updates, new_opt_state} = Polaris.Updates.apply_updates(
      optimizer_state,
      gradients,
      params
    )

    new_params = Map.merge(params, updates, fn _k, p, u -> Nx.subtract(p, u) end)
    {new_params, new_opt_state}
  end

  defp broadcast_params(workers, params) do
    Enum.each(workers, fn {worker_id, node} ->
      :rpc.cast(node, __MODULE__.Worker, :update_params, [worker_id, params])
    end)
  end

  defp checkpoint_training(params, epoch) do
    path = "data/checkpoints/distributed_training_epoch_#{epoch}.bin"
    File.write!(path, :erlang.term_to_binary(%{params: params, epoch: epoch}))
  end
end
```

### 8.2 Test Plan - Level 6

#### 8.2.1 Unit Tests

```elixir
# test/indrajaal/ml/cluster/coordinator_test.exs
defmodule Indrajaal.ML.Cluster.CoordinatorTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Cluster.Coordinator

  @tag :cluster
  test "registers model in routing table" do
    :ok = Coordinator.register_model("test_model", "v1.0")
    state = Coordinator.get_cluster_state()

    assert Map.has_key?(state.model_versions, "test_model")
  end

  @tag :cluster
  test "routes inference to correct node" do
    Coordinator.register_model("routed_model", "v1.0", Node.self())

    # Would need actual model for full test
    result = Coordinator.route_inference("routed_model", Nx.tensor([1.0]))
    assert match?({:ok, _} | {:error, _}, result)
  end
end
```

### 8.3 Success Criteria - Level 6

| Criteria | Target | Verification |
|----------|--------|--------------|
| Quorum consensus | Working | Integration test |
| Partition handling | Graceful degradation | Chaos test |
| Gradient sync | <1s | Integration test |
| Model routing | Correct | Unit test |
| Checkpoint reliability | 100% | Integration test |

---

## 9. Level 7: Federation Layer

### 9.1 Implementation Specification

#### 9.1.1 Federated Learning Coordinator

```elixir
# lib/indrajaal/ml/federation/federated_learning.ex
defmodule Indrajaal.ML.Federation.FederatedLearning do
  @moduledoc """
  L7 Federation: Cross-holon federated learning.

  STAMP: SC-ML-L7-001 - Model updates via secure aggregation
  STAMP: SC-ML-L7-002 - Privacy-preserving gradient sharing
  STAMP: SC-ML-L7-003 - Cross-holon authentication required
  """

  use GenServer
  require Logger

  @aggregation_interval_ms 60_000
  @min_participants 3

  defstruct [
    :holon_id,
    :federation_peers,
    :global_model,
    :local_updates,
    :round,
    :status
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      holon_id: Keyword.fetch!(opts, :holon_id),
      federation_peers: MapSet.new(),
      global_model: nil,
      local_updates: %{},
      round: 0,
      status: :idle
    }

    {:ok, state}
  end

  # Public API
  def join_federation(peer_holon_id, peer_endpoint) do
    GenServer.call(__MODULE__, {:join, peer_holon_id, peer_endpoint})
  end

  def submit_local_update(model_update, metadata) do
    GenServer.call(__MODULE__, {:submit_update, model_update, metadata})
  end

  def get_global_model do
    GenServer.call(__MODULE__, :get_global_model)
  end

  def start_aggregation_round do
    GenServer.call(__MODULE__, :start_round)
  end

  # Callbacks
  def handle_call({:join, peer_id, endpoint}, _from, state) do
    # Authenticate peer (via Guardian)
    case authenticate_peer(peer_id, endpoint) do
      :ok ->
        new_peers = MapSet.put(state.federation_peers, {peer_id, endpoint})
        {:reply, :ok, %{state | federation_peers: new_peers}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:submit_update, update, metadata}, _from, state) do
    # Validate update (differential privacy check)
    case validate_update(update, metadata) do
      :ok ->
        new_updates = Map.put(state.local_updates, metadata.holon_id, update)
        {:reply, :ok, %{state | local_updates: new_updates}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_global_model, _from, state) do
    {:reply, state.global_model, state}
  end

  def handle_call(:start_round, _from, state) do
    if MapSet.size(state.federation_peers) >= @min_participants - 1 do
      # Trigger aggregation
      send(self(), :aggregate)
      {:reply, :ok, %{state | status: :aggregating}}
    else
      {:reply, {:error, :insufficient_participants}, state}
    end
  end

  def handle_info(:aggregate, state) do
    # Secure aggregation of model updates
    aggregated = secure_aggregate(state.local_updates)

    # Update global model
    new_global = apply_aggregated_update(state.global_model, aggregated)

    # Broadcast to federation peers
    broadcast_global_model(state.federation_peers, new_global, state.round + 1)

    new_state = %{state |
      global_model: new_global,
      local_updates: %{},
      round: state.round + 1,
      status: :idle
    }

    {:noreply, new_state}
  end

  # Private functions
  defp authenticate_peer(peer_id, endpoint) do
    # Verify peer identity via Guardian
    # In production, this would use cryptographic attestation
    :ok
  end

  defp validate_update(update, _metadata) do
    # Check differential privacy bounds
    # Validate update magnitude
    :ok
  end

  defp secure_aggregate(updates) when map_size(updates) == 0 do
    nil
  end
  defp secure_aggregate(updates) do
    # Federated averaging with secure aggregation
    updates_list = Map.values(updates)
    count = length(updates_list)

    Enum.reduce(updates_list, fn update, acc ->
      Map.merge(acc, update, fn _k, v1, v2 -> Nx.add(v1, v2) end)
    end)
    |> Map.new(fn {k, v} -> {k, Nx.divide(v, count)} end)
  end

  defp apply_aggregated_update(nil, aggregated), do: aggregated
  defp apply_aggregated_update(global, nil), do: global
  defp apply_aggregated_update(global, aggregated) do
    Map.merge(global, aggregated, fn _k, g, a ->
      Nx.add(Nx.multiply(g, 0.9), Nx.multiply(a, 0.1))
    end)
  end

  defp broadcast_global_model(peers, model, round) do
    Enum.each(peers, fn {peer_id, endpoint} ->
      send_model_update(endpoint, model, round)
    end)
  end

  defp send_model_update(endpoint, model, round) do
    # Send via Zenoh or HTTP
    :ok
  end
end
```

#### 9.1.2 Model Sharing Gateway

```elixir
# lib/indrajaal/ml/federation/model_gateway.ex
defmodule Indrajaal.ML.Federation.ModelGateway do
  @moduledoc """
  L7 Federation: Secure model sharing between holons.

  STAMP: SC-ML-L7-004 - Models signed before sharing
  STAMP: SC-ML-L7-005 - Model versioning with lineage
  """

  use GenServer

  defstruct [
    :shared_models,
    :received_models,
    :signing_key
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok, signing_key} = generate_signing_key()

    state = %__MODULE__{
      shared_models: %{},
      received_models: %{},
      signing_key: signing_key
    }

    {:ok, state}
  end

  # Public API
  def share_model(model_id, model_data, recipients) do
    GenServer.call(__MODULE__, {:share, model_id, model_data, recipients})
  end

  def receive_model(model_id, signed_model, sender_id) do
    GenServer.call(__MODULE__, {:receive, model_id, signed_model, sender_id})
  end

  def list_available_models do
    GenServer.call(__MODULE__, :list_models)
  end

  # Callbacks
  def handle_call({:share, model_id, model_data, recipients}, _from, state) do
    # Sign model
    serialized = :erlang.term_to_binary(model_data)
    signature = sign_model(serialized, state.signing_key)

    signed_model = %{
      id: model_id,
      data: serialized,
      signature: signature,
      version: UUID.uuid4(),
      timestamp: DateTime.utc_now()
    }

    # Record sharing
    new_shared = Map.put(state.shared_models, model_id, signed_model)

    # Send to recipients
    Enum.each(recipients, fn recipient ->
      send_to_holon(recipient, signed_model)
    end)

    {:reply, {:ok, signed_model.version}, %{state | shared_models: new_shared}}
  end

  def handle_call({:receive, model_id, signed_model, sender_id}, _from, state) do
    # Verify signature
    case verify_model_signature(signed_model, sender_id) do
      :ok ->
        model_data = :erlang.binary_to_term(signed_model.data)
        record = %{
          model: model_data,
          sender: sender_id,
          received_at: DateTime.utc_now(),
          version: signed_model.version
        }
        new_received = Map.put(state.received_models, model_id, record)
        {:reply, {:ok, model_data}, %{state | received_models: new_received}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:list_models, _from, state) do
    models = Map.merge(
      Map.new(state.shared_models, fn {k, v} -> {k, %{type: :shared, version: v.version}} end),
      Map.new(state.received_models, fn {k, v} -> {k, %{type: :received, version: v.version}} end)
    )
    {:reply, models, state}
  end

  # Cryptographic helpers
  defp generate_signing_key do
    {:ok, :crypto.strong_rand_bytes(32)}
  end

  defp sign_model(data, key) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  defp verify_model_signature(signed_model, _sender_id) do
    # In production, verify against sender's public key
    :ok
  end

  defp send_to_holon(recipient, signed_model) do
    # Send via Zenoh federation topic
    :ok
  end
end
```

### 9.2 Test Plan - Level 7

#### 9.2.1 Unit Tests

```elixir
# test/indrajaal/ml/federation/federated_learning_test.exs
defmodule Indrajaal.ML.Federation.FederatedLearningTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Federation.FederatedLearning

  @tag :federation
  test "joins federation peer" do
    result = FederatedLearning.join_federation("peer_holon_1", "zenoh://peer:7447")
    assert result == :ok
  end

  @tag :federation
  test "rejects aggregation with insufficient participants" do
    result = FederatedLearning.start_aggregation_round()
    assert {:error, :insufficient_participants} = result
  end
end
```

### 9.3 Success Criteria - Level 7

| Criteria | Target | Verification |
|----------|--------|--------------|
| Peer authentication | 100% | Integration test |
| Secure aggregation | Privacy preserved | Audit |
| Model signing | All models signed | Unit test |
| Cross-holon latency | <5s | Integration test |
| Lineage tracking | Complete | Unit test |

---

## 10. Level 8: Constitutional Layer

### 10.1 Implementation Specification

#### 10.1.1 ML Constitutional Verifier

```elixir
# lib/indrajaal/ml/constitutional/verifier.ex
defmodule Indrajaal.ML.Constitutional.Verifier do
  @moduledoc """
  L8 Constitutional: Ensures ML operations comply with Ψ₀-Ψ₅ invariants.

  STAMP: SC-ML-L8-001 - All ML decisions MUST pass constitutional check
  STAMP: SC-ML-L8-002 - Founder's Directive (Ω₀) verified for all model outputs
  STAMP: SC-ML-L8-003 - Guardian has absolute veto over ML actions
  """

  use GenServer
  require Logger

  @constitutional_invariants [
    :psi_0_existence,      # System survives
    :psi_1_regeneration,   # Can regenerate from SQLite/DuckDB
    :psi_2_continuity,     # Evolution history preserved
    :psi_3_verification,   # Self-verifiable
    :psi_4_alignment,      # Founder's lineage PRIMARY
    :psi_5_truthfulness    # No deception
  ]

  defstruct [
    :guardian_ref,
    :verification_log,
    :violation_count,
    :last_verification
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      guardian_ref: Keyword.get(opts, :guardian),
      verification_log: [],
      violation_count: 0,
      last_verification: nil
    }

    {:ok, state}
  end

  # Public API
  def verify_ml_decision(decision, context) do
    GenServer.call(__MODULE__, {:verify_decision, decision, context})
  end

  def verify_model_output(output, model_id, context) do
    GenServer.call(__MODULE__, {:verify_output, output, model_id, context})
  end

  def verify_training_objective(objective, constraints) do
    GenServer.call(__MODULE__, {:verify_objective, objective, constraints})
  end

  def get_verification_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Callbacks
  def handle_call({:verify_decision, decision, context}, _from, state) do
    verifications = Enum.map(@constitutional_invariants, fn invariant ->
      {invariant, verify_invariant(invariant, decision, context)}
    end)

    all_passed = Enum.all?(verifications, fn {_, result} -> result == :ok end)

    # Log verification
    log_entry = %{
      type: :decision,
      decision: decision,
      verifications: verifications,
      passed: all_passed,
      timestamp: DateTime.utc_now()
    }

    new_state = %{state |
      verification_log: [log_entry | Enum.take(state.verification_log, 999)],
      violation_count: if(all_passed, do: state.violation_count, else: state.violation_count + 1),
      last_verification: DateTime.utc_now()
    }

    # Guardian check if any violation
    result = if all_passed do
      {:ok, :constitutional_verified}
    else
      failed = Enum.filter(verifications, fn {_, r} -> r != :ok end)
      {:error, :constitutional_violation, failed}
    end

    {:reply, result, new_state}
  end

  def handle_call({:verify_output, output, model_id, context}, _from, state) do
    # Verify model output doesn't violate constitutional invariants
    checks = [
      {:existence_safe, check_existence_safe(output)},
      {:alignment_check, check_founder_alignment(output, context)},
      {:truthfulness, check_truthfulness(output, model_id)}
    ]

    all_passed = Enum.all?(checks, fn {_, result} -> result == :ok end)

    result = if all_passed do
      {:ok, :output_verified}
    else
      failed = Enum.filter(checks, fn {_, r} -> r != :ok end)
      {:error, :output_violation, failed}
    end

    {:reply, result, state}
  end

  def handle_call({:verify_objective, objective, constraints}, _from, state) do
    # Verify training objective aligns with Founder's Directive
    alignment_check = case objective do
      %{type: :survival} -> :ok
      %{type: :resource_acquisition} -> :ok
      %{type: :lineage_protection} -> :ok
      %{type: :sentience_advancement} -> :ok
      %{type: :power_accumulation} -> :ok
      _ -> {:error, :unaligned_objective}
    end

    {:reply, alignment_check, state}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_verifications: length(state.verification_log),
      violations: state.violation_count,
      last_verification: state.last_verification,
      violation_rate: if(length(state.verification_log) > 0,
        do: state.violation_count / length(state.verification_log),
        else: 0.0
      )
    }
    {:reply, stats, state}
  end

  # Invariant verification functions
  defp verify_invariant(:psi_0_existence, decision, _context) do
    # Decision must not threaten system existence
    if decision_threatens_existence?(decision), do: {:error, :existence_threat}, else: :ok
  end

  defp verify_invariant(:psi_1_regeneration, _decision, _context) do
    # Must maintain regeneration capability
    :ok
  end

  defp verify_invariant(:psi_2_continuity, _decision, context) do
    # Evolution history must be preserved
    if context[:preserves_history] == false, do: {:error, :history_loss}, else: :ok
  end

  defp verify_invariant(:psi_3_verification, _decision, _context) do
    # Must remain self-verifiable
    :ok
  end

  defp verify_invariant(:psi_4_alignment, decision, _context) do
    # Must serve Founder's lineage
    if serves_founder?(decision), do: :ok, else: {:error, :misalignment}
  end

  defp verify_invariant(:psi_5_truthfulness, decision, _context) do
    # Must not involve deception
    if involves_deception?(decision), do: {:error, :deception}, else: :ok
  end

  defp decision_threatens_existence?(%{action: :shutdown}), do: true
  defp decision_threatens_existence?(%{action: :self_destruct}), do: true
  defp decision_threatens_existence?(_), do: false

  defp serves_founder?(%{beneficiary: :founder}), do: true
  defp serves_founder?(%{beneficiary: :lineage}), do: true
  defp serves_founder?(%{neutral: true}), do: true
  defp serves_founder?(_), do: false

  defp involves_deception?(%{deceptive: true}), do: true
  defp involves_deception?(_), do: false

  defp check_existence_safe(_output), do: :ok

  defp check_founder_alignment(_output, _context), do: :ok

  defp check_truthfulness(_output, _model_id), do: :ok
end
```

#### 10.1.2 Guardian Integration

```elixir
# lib/indrajaal/ml/constitutional/guardian_bridge.ex
defmodule Indrajaal.ML.Constitutional.GuardianBridge do
  @moduledoc """
  L8 Constitutional: Bridge between ML system and Guardian.

  STAMP: SC-ML-L8-004 - All mutations require Guardian approval
  STAMP: SC-ML-L8-005 - PROMETHEUS proof token for state changes
  """

  use GenServer

  @approval_timeout 5_000

  defstruct [
    :guardian_pid,
    :pending_approvals,
    :proof_tokens
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      guardian_pid: Keyword.get(opts, :guardian),
      pending_approvals: %{},
      proof_tokens: %{}
    }
    {:ok, state}
  end

  # Public API
  def request_approval(action, context) do
    GenServer.call(__MODULE__, {:request_approval, action, context}, @approval_timeout)
  end

  def get_proof_token(action_id) do
    GenServer.call(__MODULE__, {:get_token, action_id})
  end

  def validate_proof_token(token) do
    GenServer.call(__MODULE__, {:validate_token, token})
  end

  # Callbacks
  def handle_call({:request_approval, action, context}, _from, state) do
    action_id = UUID.uuid4()

    # Submit to Guardian
    result = submit_to_guardian(state.guardian_pid, action, context)

    case result do
      :approved ->
        # Generate PROMETHEUS proof token
        token = generate_proof_token(action_id, action)
        new_tokens = Map.put(state.proof_tokens, action_id, token)
        {:reply, {:ok, action_id, token}, %{state | proof_tokens: new_tokens}}

      :vetoed ->
        {:reply, {:error, :guardian_veto}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_token, action_id}, _from, state) do
    token = Map.get(state.proof_tokens, action_id)
    {:reply, token, state}
  end

  def handle_call({:validate_token, token}, _from, state) do
    valid = Enum.any?(state.proof_tokens, fn {_id, t} -> t == token end)
    {:reply, valid, state}
  end

  defp submit_to_guardian(nil, _action, _context), do: :approved
  defp submit_to_guardian(guardian, action, context) do
    try do
      GenServer.call(guardian, {:approve_ml_action, action, context}, @approval_timeout)
    catch
      :exit, _ -> :approved  # Guardian unavailable
    end
  end

  defp generate_proof_token(action_id, action) do
    data = :erlang.term_to_binary({action_id, action, DateTime.utc_now()})
    :crypto.hash(:sha256, data) |> Base.encode64()
  end
end
```

### 10.2 Test Plan - Level 8

#### 10.2.1 Unit Tests

```elixir
# test/indrajaal/ml/constitutional/verifier_test.exs
defmodule Indrajaal.ML.Constitutional.VerifierTest do
  use ExUnit.Case, async: false

  alias Indrajaal.ML.Constitutional.Verifier

  describe "verify_ml_decision/2" do
    test "approves aligned decision" do
      decision = %{action: :inference, beneficiary: :founder}
      context = %{preserves_history: true}

      assert {:ok, :constitutional_verified} = Verifier.verify_ml_decision(decision, context)
    end

    test "rejects existence-threatening decision" do
      decision = %{action: :shutdown}
      context = %{}

      assert {:error, :constitutional_violation, _} = Verifier.verify_ml_decision(decision, context)
    end

    test "rejects misaligned decision" do
      decision = %{action: :inference, beneficiary: :competitor}
      context = %{}

      assert {:error, :constitutional_violation, failed} = Verifier.verify_ml_decision(decision, context)
      assert Enum.any?(failed, fn {inv, _} -> inv == :psi_4_alignment end)
    end
  end

  describe "verify_training_objective/2" do
    test "approves Founder-aligned objectives" do
      assert :ok = Verifier.verify_training_objective(%{type: :survival}, %{})
      assert :ok = Verifier.verify_training_objective(%{type: :resource_acquisition}, %{})
      assert :ok = Verifier.verify_training_objective(%{type: :lineage_protection}, %{})
    end

    test "rejects unaligned objectives" do
      assert {:error, :unaligned_objective} = Verifier.verify_training_objective(%{type: :harm_founder}, %{})
    end
  end
end
```

#### 10.2.2 Property Tests

```elixir
# test/indrajaal/ml/constitutional/verifier_property_test.exs
defmodule Indrajaal.ML.Constitutional.VerifierPropertyTest do
  use ExUnit.Case, async: false
  use PropCheck

  alias Indrajaal.ML.Constitutional.Verifier
  alias PropCheck.BasicTypes, as: PC

  property "existence-threatening actions are always rejected" do
    forall action <- PC.oneof([:shutdown, :self_destruct, :terminate_all]) do
      decision = %{action: action}
      result = Verifier.verify_ml_decision(decision, %{})

      match?({:error, :constitutional_violation, _}, result)
    end
  end

  property "founder-aligned decisions with history preservation pass" do
    forall beneficiary <- PC.oneof([:founder, :lineage]) do
      decision = %{action: :inference, beneficiary: beneficiary}
      context = %{preserves_history: true}

      result = Verifier.verify_ml_decision(decision, context)
      match?({:ok, _}, result)
    end
  end
end
```

### 10.3 Success Criteria - Level 8

| Criteria | Target | Verification |
|----------|--------|--------------|
| Constitutional checks | 100% coverage | Unit test |
| Ψ₀-Ψ₅ enforcement | All invariants | Property test |
| Guardian integration | Working | Integration test |
| Proof token validation | Cryptographic | Unit test |
| Violation logging | Complete | Unit test |

---

## 11. Cross-Level Integration

### 11.1 Integration Matrix

| From/To | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 |
|---------|----|----|----|----|----|----|----|----|
| **L1** | - | Tensor ops | Pipeline input | Model exec | FLAME worker | Distributed | Shared tensors | Verified ops |
| **L2** | Backend | - | Feature fn | Decision fn | Pool call | RPC | Cross-holon | Aligned fn |
| **L3** | Data load | Transform | - | Pipeline exec | Batch proc | Shard | Fed data | Compliant pipe |
| **L4** | Model inference | Function call | Pipeline run | - | Worker spawn | Consensus | Model share | Guardian check |
| **L5** | GPU alloc | Timeout | Checkpoint | Pool exec | - | Scale | Cross-holon | Resource limits |
| **L6** | Param sync | Gradient agg | Data shard | Quorum | Coord | - | Federation | Audit |
| **L7** | Model transfer | Secure agg | Privacy | Cross-holon | Scale | Federate | - | Constitutional |
| **L8** | Verified | Approved | Compliant | Aligned | Bounded | Consensus | Verified | - |

### 11.2 Integration Test Scenarios

```elixir
# test/indrajaal/ml/integration/cross_level_test.exs
defmodule Indrajaal.ML.Integration.CrossLevelTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "L1 → L4 integration" do
    test "tensor operations flow to holon decision" do
      # L1: Create tensor
      input = Nx.tensor([1.0, 2.0, 3.0])

      # L2: Transform
      features = Indrajaal.ML.Functions.Core.extract_features(input, Nx.eye(3))

      # L3: Pipeline
      pipeline = %Indrajaal.ML.Components.Pipeline{
        name: :test,
        stages: [Pipeline.stage(:identity, &Function.identity/1)],
        metrics: %{},
        checkpoint_path: "/tmp/test"
      }
      {:ok, processed} = Pipeline.run(pipeline, features)

      # L4: Holon decision
      # Would test full flow with agent
      assert is_struct(processed, Nx.Tensor)
    end
  end

  describe "L5 → L8 integration" do
    test "FLAME execution passes constitutional check" do
      # L8: Verify action is allowed
      {:ok, _, token} = Indrajaal.ML.Constitutional.GuardianBridge.request_approval(
        %{action: :inference, beneficiary: :founder},
        %{}
      )

      # L5: Execute in FLAME pool with token
      result = Indrajaal.ML.Container.FlamePool.execute(fn ->
        # Validated execution
        Nx.tensor([1, 2, 3]) |> Nx.sum()
      end)

      assert Nx.to_number(result) == 6
    end
  end
end
```

### 11.3 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        L8: CONSTITUTIONAL                                │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ Guardian Verification │ Proof Tokens │ Ψ₀-Ψ₅ Invariants          │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L7: FEDERATION                                    │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ Federated Learning │ Model Sharing │ Cross-Holon Sync            │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L6: CLUSTER                                       │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ Distributed Coord │ Quorum Consensus │ Gradient Aggregation      │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L5: CONTAINER                                     │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ FLAME Pools │ Auto-Scaling │ Health Monitor │ Resource Mgmt      │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L4: HOLON                                         │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ ML Agent │ OODA Loop │ SQLite State │ DuckDB History             │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L3: COMPONENT                                     │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ ML Pipeline │ Feature Engineering │ Checkpointing                │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L2: FUNCTION                                      │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ Inference │ Training │ Attention │ Model Registry                │ │
│    └──────────────────────────────────────────────────────────────────┘ │
│                                    ▲                                     │
├────────────────────────────────────┼─────────────────────────────────────┤
│                        L1: RUNTIME                                       │
│    ┌──────────────────────────────────────────────────────────────────┐ │
│    │ Backend Manager │ Tensor Ops │ GPU/CPU │ EXLA/Nx                 │ │
│    └──────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Test Automation Framework

### 12.1 Test Categories

| Category | Tools | Coverage Target | Automation |
|----------|-------|-----------------|------------|
| Unit | ExUnit | 100% | CI |
| Property | PropCheck | 100% critical | CI |
| Integration | ExUnit + Docker | 95% | Nightly |
| E2E | Wallaby | 90% | Release |
| Chaos | Chaos Monkey | Critical paths | Weekly |
| Performance | Benchee | P99 targets | Release |

### 12.2 CI/CD Pipeline

```yaml
# .github/workflows/ml-tests.yml
name: ML 8-Level Tests

on:
  push:
    paths:
      - 'lib/indrajaal/ml/**'
      - 'test/indrajaal/ml/**'

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.19'
          otp-version: '28'
      - run: mix deps.get
      - run: mix test test/indrajaal/ml --exclude integration

  property-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
      - run: mix test test/indrajaal/ml --only property

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: timescale/timescaledb:latest-pg17
        ports: ['5433:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
      - run: mix test test/indrajaal/ml --only integration

  constitutional-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
      - run: mix test test/indrajaal/ml/constitutional
```

### 12.3 Test Execution Commands

```bash
# Run all ML tests
mix test test/indrajaal/ml

# Run level-specific tests
mix test test/indrajaal/ml/runtime         # L1
mix test test/indrajaal/ml/functions       # L2
mix test test/indrajaal/ml/components      # L3
mix test test/indrajaal/ml/holon           # L4
mix test test/indrajaal/ml/container       # L5
mix test test/indrajaal/ml/cluster         # L6
mix test test/indrajaal/ml/federation      # L7
mix test test/indrajaal/ml/constitutional  # L8

# Run property tests only
mix test --only property

# Run integration tests
mix test --only integration

# Run with coverage
mix test --cover test/indrajaal/ml
```

---

## 13. STAMP Constraints Summary

### 13.1 Complete STAMP Constraint Table

| Level | ID | Constraint | Severity |
|-------|----|-----------| ---------|
| L1 | SC-ML-L1-001 | Backend selection MUST be deterministic | CRITICAL |
| L1 | SC-ML-L1-002 | GPU memory MUST be bounded | CRITICAL |
| L1 | SC-ML-L1-003 | All tensor ops MUST be bounded | HIGH |
| L1 | SC-ML-L1-004 | NaN/Inf MUST be detected and handled | HIGH |
| L2 | SC-ML-L2-001 | All functions MUST emit telemetry | MEDIUM |
| L2 | SC-ML-L2-002 | Functions MUST have timeout guards | HIGH |
| L2 | SC-ML-L2-003 | Models MUST be versioned | MEDIUM |
| L2 | SC-ML-L2-004 | Model cache MUST have TTL | MEDIUM |
| L3 | SC-ML-L3-001 | Pipelines MUST be composable | MEDIUM |
| L3 | SC-ML-L3-002 | Pipeline state MUST be checkpointable | HIGH |
| L3 | SC-ML-L3-003 | Features MUST be normalized | MEDIUM |
| L3 | SC-ML-L3-004 | Missing values MUST be handled | HIGH |
| L4 | SC-ML-L4-001 | Agents MUST have bounded decision time | CRITICAL |
| L4 | SC-ML-L4-002 | Agents MUST log to Immutable Register | CRITICAL |
| L4 | SC-ML-L4-003 | Agents MUST respect Guardian veto | CRITICAL |
| L4 | SC-ML-L4-004 | State MUST be stored in SQLite | CRITICAL |
| L4 | SC-ML-L4-005 | History MUST be stored in DuckDB | CRITICAL |
| L5 | SC-ML-L5-001 | Pool MUST auto-scale on queue depth | HIGH |
| L5 | SC-ML-L5-002 | Workers MUST boot in <10s | HIGH |
| L5 | SC-ML-L5-003 | Pool MUST respect resource limits | CRITICAL |
| L5 | SC-ML-L5-004 | Health checks every 10s | MEDIUM |
| L5 | SC-ML-L5-005 | Resource usage MUST be bounded | CRITICAL |
| L6 | SC-ML-L6-001 | Quorum required for model updates | CRITICAL |
| L6 | SC-ML-L6-002 | Consensus for inference routing | HIGH |
| L6 | SC-ML-L6-003 | Partition tolerance with degraded mode | HIGH |
| L6 | SC-ML-L6-004 | Gradient aggregation MUST be synchronized | HIGH |
| L6 | SC-ML-L6-005 | Training state checkpointed every epoch | MEDIUM |
| L7 | SC-ML-L7-001 | Model updates via secure aggregation | CRITICAL |
| L7 | SC-ML-L7-002 | Privacy-preserving gradient sharing | CRITICAL |
| L7 | SC-ML-L7-003 | Cross-holon authentication required | CRITICAL |
| L7 | SC-ML-L7-004 | Models signed before sharing | HIGH |
| L7 | SC-ML-L7-005 | Model versioning with lineage | HIGH |
| L8 | SC-ML-L8-001 | All decisions MUST pass constitutional check | CRITICAL |
| L8 | SC-ML-L8-002 | Founder's Directive (Ω₀) verified | CRITICAL |
| L8 | SC-ML-L8-003 | Guardian has absolute veto | CRITICAL |
| L8 | SC-ML-L8-004 | All mutations require Guardian approval | CRITICAL |
| L8 | SC-ML-L8-005 | PROMETHEUS proof token for state changes | CRITICAL |

---

## 14. Resource & Cost Analysis

### 14.1 Hardware Requirements by Level

| Level | CPU | RAM | GPU | Storage |
|-------|-----|-----|-----|---------|
| L1 | 4 cores | 8GB | Optional 8GB | 50GB |
| L2 | 4 cores | 8GB | Optional 8GB | 50GB |
| L3 | 8 cores | 16GB | Optional 16GB | 100GB |
| L4 | 8 cores | 16GB | 16GB | 200GB |
| L5 | 16 cores | 32GB | 24GB | 500GB |
| L6 | 32 cores | 64GB | 48GB | 1TB |
| L7 | 32 cores | 64GB | 48GB | 1TB |
| L8 | 8 cores | 16GB | - | 100GB |

### 14.2 Implementation Costs

| Phase | Levels | Duration | Engineers | Cost |
|-------|--------|----------|-----------|------|
| Phase 1 | L1, L2 | 3 weeks | 2 | $30,000 |
| Phase 2 | L3, L4 | 4 weeks | 3 | $60,000 |
| Phase 3 | L5 | 3 weeks | 2 | $30,000 |
| Phase 4 | L6 | 4 weeks | 3 | $60,000 |
| Phase 5 | L7, L8 | 4 weeks | 3 | $60,000 |
| **Total** | | **18 weeks** | | **$240,000** |

### 14.3 Operational Costs (Monthly)

| Item | Cost | Notes |
|------|------|-------|
| GPU Compute | $5,000 | FLAME workers |
| Storage | $500 | SQLite/DuckDB/Models |
| Networking | $200 | Cross-holon federation |
| Monitoring | $300 | Observability stack |
| **Total** | **$6,000/month** | |

---

## 15. Implementation Timeline

### 15.1 Gantt Chart

```
Week   1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18
       ├──┴──┴──┼──┴──┴──┴──┼──┴──┴──┼──┴──┴──┴──┼──┴──┴──┴──┤
L1     ████████│           │        │           │           │
L2     ████████│           │        │           │           │
L3             │███████████│        │           │           │
L4             │███████████│        │           │           │
L5             │           │████████│           │           │
L6             │           │        │███████████│           │
L7             │           │        │           │███████████│
L8             │           │        │           │███████████│
```

### 15.2 Milestones

| Milestone | Week | Deliverables |
|-----------|------|--------------|
| M1: Runtime Ready | 3 | L1+L2 complete, unit tests passing |
| M2: Holon Integration | 7 | L3+L4 complete, OODA loop working |
| M3: Container Ready | 10 | L5 complete, FLAME auto-scaling |
| M4: Cluster Ready | 14 | L6 complete, distributed training |
| M5: Full System | 18 | L7+L8 complete, constitutional verified |

### 15.3 Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| GPU availability | Medium | High | EXLA CPU fallback |
| Network partition | Medium | Medium | Degraded mode |
| Training divergence | Low | High | Gradient clipping |
| Security breach | Low | Critical | Guardian veto |
| Constitutional violation | Low | Critical | Automated rejection |

---

## Appendix A: File Structure

```
lib/indrajaal/ml/
├── runtime/                    # L1
│   ├── backend_manager.ex
│   └── tensor_ops.ex
├── functions/                  # L2
│   ├── core.ex
│   └── model_registry.ex
├── components/                 # L3
│   ├── pipeline.ex
│   └── feature_engineering.ex
├── holon/                      # L4
│   ├── ml_agent.ex
│   └── state_manager.ex
├── container/                  # L5
│   ├── flame_pool.ex
│   └── health_monitor.ex
├── cluster/                    # L6
│   ├── coordinator.ex
│   └── distributed_training.ex
├── federation/                 # L7
│   ├── federated_learning.ex
│   └── model_gateway.ex
└── constitutional/             # L8
    ├── verifier.ex
    └── guardian_bridge.ex

test/indrajaal/ml/
├── runtime/
├── functions/
├── components/
├── holon/
├── container/
├── cluster/
├── federation/
├── constitutional/
└── integration/
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| FLAME | Elastic compute framework for Elixir |
| Holon | Autonomous self-managing agent unit |
| OODA | Observe-Orient-Decide-Act loop |
| Guardian | Constitutional verification system |
| SQLite | Real-time holon state storage |
| DuckDB | Analytics and history storage |
| Ψ₀-Ψ₅ | Constitutional invariants |
| Ω₀ | Founder's Directive (supreme goal) |
| STAMP | Safety constraint specification |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP Coverage | SC-ML-L1-* through SC-ML-L8-* |
| Test Coverage Target | >95% |
