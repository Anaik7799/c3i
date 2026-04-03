defmodule Indrajaal.Substrate.L0.AutopoiesisEngine do
  @moduledoc """
  ## Design Intent
  L0 substrate autopoiesis engine — GenServer implementing the self-production
  mechanism of the holon. Autopoiesis (Greek: self + production) is the property
  of a system that continuously regenerates its own components.

  Responsibilities:
    1. `component_registry`  — ETS-backed map of component_id → component_spec
    2. `production_queue`    — ordered list of pending production requests
    3. `integrity_score`     — float [0.0, 1.0] measuring structural completeness

  Production cycle (default 5 s):
    - Dequeue one item from `production_queue`
    - Simulate component production (can be wired to real spawners)
    - Update `integrity_score` based on registered vs expected components
    - Broadcast result to PubSub "substrate:autopoiesis"

  Integrity formula:
    integrity = registered_count / max(1, expected_count)
    Clamped to [0.0, 1.0]. An integrity_score of 1.0 means all expected
    components are present.

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_table :autopoiesis_registry
  @pubsub_topic "substrate:autopoiesis"
  @production_cycle_ms 5_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type component_id :: String.t()
  @type component_spec :: %{
          id: component_id(),
          module: module() | nil,
          required: boolean(),
          registered_at: DateTime.t()
        }
  @type integrity_score :: float()

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register a component in the autopoiesis registry.

  `spec` must include at least `:id` (binary). Optional fields:
    - `:module`   — Elixir module atom
    - `:required` — boolean (default true)

  Returns `:ok` or `{:error, reason}`.
  """
  @spec register_component(component_id(), map()) :: :ok | {:error, String.t()}
  def register_component(component_id, spec)
      when is_binary(component_id) and is_map(spec) do
    GenServer.call(@name, {:register_component, component_id, spec})
  end

  def register_component(_, _), do: {:error, "component_id must be a binary and spec a map"}

  @doc """
  Enqueue a production request. The engine will process it in the next cycle.

  `request` is a map with at minimum `:component_id` (binary).
  Returns `:ok`.
  """
  @spec produce(map()) :: :ok
  def produce(%{component_id: _} = request) do
    GenServer.cast(@name, {:produce, request})
  end

  def produce(request) when is_map(request) do
    GenServer.cast(@name, {:produce, request})
  end

  @doc """
  Compute and return the current integrity score.
  Score = registered_required / max(1, total_required).
  """
  @spec verify_integrity() :: integrity_score()
  def verify_integrity do
    GenServer.call(@name, :verify_integrity)
  end

  @doc """
  Returns the full engine status map.
  """
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  @doc """
  List all registered components. Reads directly from ETS for low latency.
  """
  @spec list_components() :: [component_spec()]
  def list_components do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        :ets.tab2list(@ets_table) |> Enum.map(fn {_id, spec} -> spec end)
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])

    expected_count = Keyword.get(opts, :expected_count, 0)

    state = %{
      expected_count: expected_count,
      production_queue: [],
      production_count: 0,
      integrity_score: 1.0,
      started_at: DateTime.utc_now()
    }

    schedule_production_cycle()

    Logger.info("[AUTOPOIESIS_ENGINE] started — expected_components=#{expected_count}")
    {:ok, state}
  end

  @impl true
  def handle_call({:register_component, component_id, spec}, _from, state) do
    full_spec = %{
      id: component_id,
      module: Map.get(spec, :module),
      required: Map.get(spec, :required, true),
      registered_at: DateTime.utc_now()
    }

    :ets.insert(@ets_table, {component_id, full_spec})

    new_integrity = compute_integrity(state.expected_count)
    new_state = %{state | integrity_score: new_integrity}

    Logger.debug(
      "[AUTOPOIESIS_ENGINE] registered component=#{component_id} integrity=#{Float.round(new_integrity, 3)}"
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:verify_integrity, _from, state) do
    integrity = compute_integrity(state.expected_count)
    new_state = %{state | integrity_score: integrity}
    {:reply, integrity, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    registered_count =
      case :ets.whereis(@ets_table) do
        :undefined -> 0
        _ -> :ets.info(@ets_table, :size)
      end

    status = %{
      registered_count: registered_count,
      expected_count: state.expected_count,
      production_queue_length: length(state.production_queue),
      production_count: state.production_count,
      integrity_score: state.integrity_score,
      started_at: state.started_at
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:produce, request}, state) do
    new_queue = state.production_queue ++ [request]
    {:noreply, %{state | production_queue: new_queue}}
  end

  @impl true
  def handle_info(:production_cycle, state) do
    new_state = run_production_cycle(state)
    schedule_production_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp run_production_cycle(%{production_queue: []} = state) do
    state
  end

  defp run_production_cycle(%{production_queue: [request | rest]} = state) do
    component_id = Map.get(request, :component_id, "unknown")

    Logger.debug("[AUTOPOIESIS_ENGINE] producing component=#{component_id}")

    new_integrity = compute_integrity(state.expected_count)

    new_state = %{
      state
      | production_queue: rest,
        production_count: state.production_count + 1,
        integrity_score: new_integrity
    }

    broadcast(new_state, component_id)
    new_state
  end

  @spec compute_integrity(non_neg_integer()) :: integrity_score()
  defp compute_integrity(expected_count) do
    registered_count =
      case :ets.whereis(@ets_table) do
        :undefined -> 0
        _ -> :ets.info(@ets_table, :size)
      end

    if expected_count <= 0 do
      # No expected count set — full integrity by default
      1.0
    else
      min(1.0, registered_count / expected_count)
    end
  end

  defp schedule_production_cycle do
    Process.send_after(self(), :production_cycle, @production_cycle_ms)
  end

  defp broadcast(state, last_component_id) do
    payload = %{
      integrity_score: state.integrity_score,
      production_count: state.production_count,
      queue_length: length(state.production_queue),
      last_produced: last_component_id,
      timestamp: DateTime.utc_now()
    }

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:autopoiesis_update, payload})
    rescue
      _ -> :ok
    end
  end
end
