defmodule Indrajaal.Control.UnifiedBus do
  @moduledoc """
  Unified Control Bus - Couples all cybernetic control loops.

  ## WHAT
  A high-performance, non-blocking event bus that enables communication between
  control loops (OODA, FastOODA, ACE, Homeostasis, GDE) and system components.
  Provides circuit breaker protection and guaranteed event ordering.

  ## WHY
  SC-BUS-001 requires async messaging only for control loop coordination.
  SC-BUS-002 prohibits blocking operations in the event delivery path.
  SC-BUS-003 mandates circuit breaker protection for system stability.
  SC-BUS-004 ensures event ordering is preserved for causal consistency.

  Control loops operate independently but need to share events and
  coordinate decisions. Without a unified bus, loops cannot react
  to each other's outputs, leading to suboptimal system behavior.

  ## CONSTRAINTS
  - SC-BUS-001: Async messaging only (no blocking calls)
  - SC-BUS-002: No blocking operations in event path
  - SC-BUS-003: Circuit breaker activates at >1000 events/sec
  - SC-BUS-004: Events delivered in FIFO order per topic
  - SC-BUS-005: Graceful degradation on overload
  - SC-PRF-050: Response latency <50ms

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                      UnifiedBus                              │
  │                (Central Message Hub)                         │
  ├─────────────────────────────────────────────────────────────┤
  │  ┌─────────┐  ┌──────────┐  ┌─────┐  ┌────────────┐  ┌─────┐│
  │  │  OODA   │  │ FastOODA │  │ ACE │  │ Homeostasis│  │ GDE ││
  │  └────┬────┘  └────┬─────┘  └──┬──┘  └─────┬──────┘  └──┬──┘│
  │       │            │           │           │            │   │
  │       └────────────┴───────────┴───────────┴────────────┘   │
  │                         │                                    │
  │              ┌──────────┴──────────┐                        │
  │              │   Event Router      │                        │
  │              │ (with circuit       │                        │
  │              │  breaker)           │                        │
  │              └─────────────────────┘                        │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Message Types

  1. **Control Events** - Broadcast to all loops
     {:control_event, %{type: :metric, source: :beam_sensor, data: %{...}}}

  2. **Decisions** - Executed by relevant handlers
     {:execute_decision, %{action: :scale_up, priority: :high, ...}}

  3. **Loop Status** - Internal coordination
     {:loop_status, loop_id, :active | :paused | :overloaded}

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-29 |
  | Updated | 2025-12-29 |
  | Author | Agent 5 (C2-HIGH), Agent 6 (C2-HIGH) |
  | STAMP | SC-BUS-001 to SC-BUS-005 |
  """

  use GenServer

  require Logger

  # ============================================================
  # TYPES
  # ============================================================

  @type loop_id :: :ooda | :fast_ooda | :ace | :homeostasis | :gde
  @type circuit_state :: :closed | :open | :half_open

  @type event :: %{
          topic: atom(),
          payload: term(),
          timestamp: DateTime.t(),
          source: atom() | pid(),
          priority: :low | :normal | :high | :critical
        }

  @type decision :: %{
          required(:action) => atom(),
          required(:confidence) => non_neg_integer(),
          required(:priority) => atom(),
          optional(:target) => term(),
          optional(:parameters) => map()
        }

  @type bus_state :: %{
          subscribers: :ets.tid(),
          loops: :ets.tid(),
          loop_registry: %{loop_id() => pid()},
          queue: list(event()),
          circuit: %{
            state: circuit_state(),
            failure_count: non_neg_integer(),
            last_failure: DateTime.t() | nil,
            cooldown_until: DateTime.t() | nil
          },
          metrics: %{
            events_received: non_neg_integer(),
            events_delivered: non_neg_integer(),
            events_dropped: non_neg_integer(),
            circuit_trips: non_neg_integer(),
            loop_broadcasts: non_neg_integer(),
            decisions_executed: non_neg_integer()
          },
          config: map()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  # Known control loops (SC-BUS-005)
  @loops [:ooda, :fast_ooda, :ace, :homeostasis, :gde]

  # Loop module mappings for auto-discovery
  @loop_modules %{
    ooda: Indrajaal.Distributed.Agents.OODAAgent,
    fast_ooda: Indrajaal.Cortex.FastOODA,
    ace: Indrajaal.Distributed.Agents.ACEAgent,
    homeostasis: Indrajaal.Cortex.Homeostasis,
    gde: Indrajaal.Cortex.GDE.AIIntegration
  }

  # Circuit breaker threshold (events per second) - SC-BUS-003
  @circuit_threshold 1000
  # Circuit breaker cooldown (ms)
  @cooldown_ms 5_000
  # Half-open test count
  @half_open_test_count 10
  # Event window size for rate calculation
  @event_window_size 100

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the UnifiedBus GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # ------------------------------------------------------------
  # LOOP REGISTRATION (Primary API for Control Loops)
  # ------------------------------------------------------------

  @doc """
  Register a control loop with the bus.
  Loops must register to receive broadcast events.

  SC-BUS-005: Only known loops can register.

  ## Examples

      iex> UnifiedBus.register(:fast_ooda, self())
      :ok

      iex> UnifiedBus.register(:unknown, self())
      {:error, {:unknown_loop, :unknown}}
  """
  @spec register(loop_id(), pid()) :: :ok | {:error, term()}
  def register(loop_id, pid) when loop_id in @loops and is_pid(pid) do
    GenServer.call(__MODULE__, {:register, loop_id, pid})
  end

  def register(loop_id, _pid), do: {:error, {:unknown_loop, loop_id}}

  @doc """
  Unregister a control loop from the bus.
  """
  @spec unregister(loop_id()) :: :ok
  def unregister(loop_id) when loop_id in @loops do
    GenServer.call(__MODULE__, {:unregister, loop_id})
  end

  def unregister(_loop_id), do: :ok

  @doc """
  Get list of known loop identifiers.
  """
  @spec known_loops() :: [loop_id()]
  def known_loops, do: @loops

  # ------------------------------------------------------------
  # TOPIC-BASED SUBSCRIPTION (Secondary API)
  # ------------------------------------------------------------

  @doc """
  Subscribe a process to a topic.
  SC-BUS-001: Async subscription.
  """
  @spec subscribe(atom(), pid() | nil) :: :ok
  def subscribe(topic, pid \\ nil) do
    subscriber = pid || self()
    GenServer.cast(__MODULE__, {:subscribe, topic, subscriber})
  end

  @doc """
  Unsubscribe a process from a topic.
  """
  @spec unsubscribe(atom(), pid() | nil) :: :ok
  def unsubscribe(topic, pid \\ nil) do
    subscriber = pid || self()
    GenServer.cast(__MODULE__, {:unsubscribe, topic, subscriber})
  end

  # ------------------------------------------------------------
  # BROADCASTING
  # ------------------------------------------------------------

  @doc """
  Broadcast an event to all registered control loops.
  SC-BUS-001: Async broadcast - returns immediately.
  SC-BUS-002: No blocking operations.

  This is the primary broadcast API for control loop coordination.
  All registered loops receive {:control_event, event} messages.

  ## Examples

      iex> UnifiedBus.broadcast(%{type: :stress_alert, level: 0.85})
      :ok
  """
  @spec broadcast(map()) :: :ok
  def broadcast(event) when is_map(event) do
    GenServer.cast(__MODULE__, {:broadcast_to_loops, event})
  end

  @doc """
  Broadcast an event to all subscribers of a specific topic.
  SC-BUS-001: Async broadcast - returns immediately.
  SC-BUS-002: No blocking operations.

  This is the topic-based pub/sub API for general event distribution.
  """
  @spec broadcast(atom(), term(), keyword()) :: :ok | {:error, :circuit_open}
  def broadcast(topic, payload, opts \\ []) do
    event = %{
      topic: topic,
      payload: payload,
      timestamp: DateTime.utc_now(),
      source: Keyword.get(opts, :source, self()),
      priority: Keyword.get(opts, :priority, :normal)
    }

    GenServer.cast(__MODULE__, {:broadcast, event})
  end

  @doc """
  Execute a decision from a control loop (FastOODA, OODA, etc.).
  SC-BUS-001: Async operation.

  Decisions are routed to appropriate handlers based on action type:
  - Scaling decisions -> ACE, Homeostasis
  - Config changes -> OODA, GDE
  - Alerts -> All loops

  ## Examples

      iex> UnifiedBus.execute(%{action: :scale_up, confidence: 95, priority: :high})
      :ok
  """
  @spec execute(decision()) :: :ok
  def execute(decision) when is_map(decision) do
    GenServer.cast(__MODULE__, {:execute, decision})
  end

  # ------------------------------------------------------------
  # STATUS AND METRICS
  # ------------------------------------------------------------

  @doc """
  Get current bus status and metrics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get current bus state (alias for status).
  """
  @spec get_state() :: bus_state()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Get circuit breaker status.
  """
  @spec circuit_status() :: circuit_state()
  def circuit_status do
    GenServer.call(__MODULE__, :circuit_status)
  end

  @doc """
  Get circuit breaker state (alias for circuit_status).
  """
  @spec circuit_state() :: circuit_state()
  def circuit_state do
    circuit_status()
  end

  @doc """
  Get bus metrics.
  """
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  @doc """
  List all registered control loops.
  """
  @spec registered_loops() :: [loop_id()]
  def registered_loops do
    GenServer.call(__MODULE__, :registered_loops)
  end

  @doc """
  Register a control loop with the bus (legacy API).
  Prefer using register/2 for type safety.
  """
  @spec register_loop(atom(), pid()) :: :ok
  def register_loop(loop_name, pid) do
    GenServer.cast(__MODULE__, {:register_loop, loop_name, pid})
  end

  @doc """
  Reset the circuit breaker (for testing/recovery).
  """
  @spec reset_circuit() :: :ok
  def reset_circuit do
    GenServer.call(__MODULE__, :reset_circuit)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[UnifiedBus] Initializing control loop coupling (SC-BUS-001 to SC-BUS-005)")

    # Create ETS table for topic subscribers
    subscribers_table =
      :ets.new(:unified_bus_subscribers, [:set, :public, read_concurrency: true])

    # Create ETS table for registered loops (legacy)
    loops_table = :ets.new(:unified_bus_loops, [:set, :public, read_concurrency: true])

    state = %{
      subscribers: subscribers_table,
      loops: loops_table,
      # Primary loop registry (loop_id -> pid)
      loop_registry: %{},
      # Event window for rate limiting
      event_window: [],
      # Decision queue for circuit breaker recovery
      decision_queue: [],
      queue: [],
      circuit: %{
        state: :closed,
        failure_count: 0,
        last_failure: nil,
        cooldown_until: nil,
        events_this_second: 0,
        second_start: System.monotonic_time(:second)
      },
      metrics: %{
        events_received: 0,
        events_delivered: 0,
        events_dropped: 0,
        circuit_trips: 0,
        loop_broadcasts: 0,
        decisions_executed: 0,
        avg_broadcast_latency_us: 0.0
      },
      config: Keyword.get(opts, :config, %{}),
      started_at: DateTime.utc_now()
    }

    # Schedule rate limit reset
    schedule_rate_reset()

    # Schedule auto-discovery of control loops
    schedule_autodiscover()

    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, topic, pid}, state) do
    current = get_subscribers(state.subscribers, topic)
    new_subscribers = Enum.uniq([pid | current])
    :ets.insert(state.subscribers, {topic, new_subscribers})

    # Monitor subscriber for cleanup on crash
    Process.monitor(pid)

    emit_telemetry(:subscribe, %{topic: topic, subscriber_count: length(new_subscribers)})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:unsubscribe, topic, pid}, state) do
    current = get_subscribers(state.subscribers, topic)
    new_subscribers = List.delete(current, pid)
    :ets.insert(state.subscribers, {topic, new_subscribers})

    emit_telemetry(:unsubscribe, %{topic: topic, subscriber_count: length(new_subscribers)})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    new_state = handle_broadcast(event, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:register_loop, loop_name, pid}, state) do
    :ets.insert(state.loops, {loop_name, pid})
    Process.monitor(pid)

    Logger.debug("[UnifiedBus] Registered loop #{loop_name} (legacy)")
    emit_telemetry(:register_loop, %{loop_name: loop_name})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast_to_loops, event}, state) do
    # SC-BUS-003: Check circuit breaker
    case state.circuit.state do
      :open ->
        # Circuit open, drop event
        new_metrics = Map.update!(state.metrics, :events_dropped, &(&1 + 1))
        {:noreply, %{state | metrics: new_metrics}}

      _ ->
        # Broadcast to all registered loops
        new_state = broadcast_to_all_loops(event, state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast({:execute, decision}, state) do
    # SC-BUS-003: Check circuit breaker for decisions
    case state.circuit.state do
      :open ->
        # Queue decision for later
        new_queue = [decision | state.decision_queue] |> Enum.take(100)
        {:noreply, %{state | decision_queue: new_queue}}

      _ ->
        new_state = execute_decision(decision, state)
        {:noreply, new_state}
    end
  end

  # ------------------------------------------------------------
  # handle_call
  # ------------------------------------------------------------

  @impl true
  def handle_call({:register, loop_id, pid}, _from, state) do
    Logger.debug("[UnifiedBus] Registering loop: #{loop_id} (pid: #{inspect(pid)})")

    # Monitor the loop process
    Process.monitor(pid)

    # Also add to legacy ETS table for compatibility
    :ets.insert(state.loops, {loop_id, pid})

    new_registry = Map.put(state.loop_registry, loop_id, pid)
    emit_telemetry(:register, %{loop_id: loop_id})
    {:reply, :ok, %{state | loop_registry: new_registry}}
  end

  @impl true
  def handle_call({:unregister, loop_id}, _from, state) do
    Logger.debug("[UnifiedBus] Unregistering loop: #{loop_id}")

    # Remove from legacy ETS table
    :ets.delete(state.loops, loop_id)

    new_registry = Map.delete(state.loop_registry, loop_id)
    {:reply, :ok, %{state | loop_registry: new_registry}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      event_count: state.metrics.events_received,
      circuit_state: state.circuit.state,
      registered_loops: Map.keys(state.loop_registry),
      registered_count: map_size(state.loop_registry),
      metrics: state.metrics,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at, :second),
      current_rate: calculate_current_rate(state.event_window),
      decision_queue_size: length(state.decision_queue)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:reset_circuit, _from, state) do
    Logger.info("[UnifiedBus] Circuit breaker manually reset")

    new_circuit = %{
      state.circuit
      | state: :closed,
        failure_count: 0,
        events_this_second: 0
    }

    # Process any queued decisions
    Enum.each(state.decision_queue, fn decision ->
      GenServer.cast(self(), {:execute, decision})
    end)

    {:reply, :ok, %{state | circuit: new_circuit, decision_queue: []}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    response = %{
      circuit_state: state.circuit.state,
      queue_size: length(state.queue),
      metrics: state.metrics,
      subscriber_count: :ets.info(state.subscribers, :size),
      loop_count: :ets.info(state.loops, :size)
    }

    {:reply, response, state}
  end

  @impl true
  def handle_call(:circuit_status, _from, state) do
    {:reply, state.circuit.state, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:registered_loops, _from, state) do
    ets_list = :ets.tab2list(state.loops)
    loops = ets_list |> Enum.map(fn {name, _pid} -> name end)
    {:reply, loops, state}
  end

  @impl true
  def handle_info(:rate_reset, state) do
    new_circuit = %{
      state.circuit
      | events_this_second: 0,
        second_start: System.monotonic_time(:second)
    }

    # Check if we can transition from open to half_open
    new_circuit =
      case new_circuit.state do
        :open ->
          if DateTime.compare(
               DateTime.utc_now(),
               new_circuit.cooldown_until || DateTime.utc_now()
             ) == :gt do
            Logger.info("UnifiedBus: Circuit breaker transitioning to half-open")
            %{new_circuit | state: :half_open}
          else
            new_circuit
          end

        _ ->
          new_circuit
      end

    schedule_rate_reset()
    {:noreply, %{state | circuit: new_circuit}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up subscribers when process dies
    cleanup_subscriber(state.subscribers, pid)
    cleanup_loop(state.loops, pid)

    # Clean up loop_registry
    new_registry =
      state.loop_registry
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()

    if map_size(new_registry) != map_size(state.loop_registry) do
      Logger.warning("[UnifiedBus] Loop process down, removed from registry")
    end

    {:noreply, %{state | loop_registry: new_registry}}
  end

  @impl true
  def handle_info(:autodiscover, state) do
    new_state = autodiscover_loops(state)
    schedule_autodiscover()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # BROADCAST LOGIC
  # ============================================================

  defp handle_broadcast(event, state) do
    # Update metrics
    new_metrics = Map.update!(state.metrics, :events_received, &(&1 + 1))

    # Check circuit breaker (SC-BUS-003)
    case check_circuit_breaker(state) do
      {:ok, updated_circuit} ->
        # Deliver event to subscribers
        subscribers = get_subscribers(state.subscribers, event.topic)
        delivered_count = deliver_to_subscribers(event, subscribers)

        # Update metrics
        final_metrics =
          Map.update!(new_metrics, :events_delivered, &(&1 + delivered_count))

        emit_telemetry(:broadcast, %{
          topic: event.topic,
          delivered: delivered_count,
          priority: event.priority
        })

        %{state | metrics: final_metrics, circuit: updated_circuit}

      {:error, :circuit_open} ->
        # Drop event, circuit is open
        final_metrics = Map.update!(new_metrics, :events_dropped, &(&1 + 1))

        emit_telemetry(:dropped, %{topic: event.topic, reason: :circuit_open})

        %{state | metrics: final_metrics}
    end
  end

  defp check_circuit_breaker(state) do
    circuit = state.circuit

    case circuit.state do
      :open ->
        {:error, :circuit_open}

      :half_open ->
        # Allow limited events through for testing
        if circuit.events_this_second < @half_open_test_count do
          {:ok, %{circuit | events_this_second: circuit.events_this_second + 1}}
        else
          # Reset to closed if test events succeeded
          Logger.info("UnifiedBus: Circuit breaker closing (half-open test passed)")
          {:ok, %{circuit | state: :closed, failure_count: 0, events_this_second: 0}}
        end

      :closed ->
        # Check rate limit (SC-BUS-003)
        if circuit.events_this_second >= @circuit_threshold do
          # Trip circuit breaker
          Logger.warning("UnifiedBus: Circuit breaker OPEN (threshold exceeded)")

          new_circuit = %{
            circuit
            | state: :open,
              failure_count: circuit.failure_count + 1,
              last_failure: DateTime.utc_now(),
              cooldown_until: DateTime.add(DateTime.utc_now(), @cooldown_ms, :millisecond)
          }

          emit_telemetry(:circuit_trip, %{failure_count: new_circuit.failure_count})
          {:error, :circuit_open}
        else
          {:ok, %{circuit | events_this_second: circuit.events_this_second + 1}}
        end
    end
  end

  defp deliver_to_subscribers(event, subscribers) do
    # SC-BUS-002: Non-blocking delivery
    # SC-BUS-004: FIFO ordering preserved (single sender)
    Enum.reduce(subscribers, 0, fn pid, count ->
      if Process.alive?(pid) do
        # Async send - non-blocking
        send(pid, {:unified_bus_event, event})
        count + 1
      else
        count
      end
    end)
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp get_subscribers(table, topic) do
    case :ets.lookup(table, topic) do
      [{^topic, subscribers}] -> subscribers
      [] -> []
    end
  end

  defp cleanup_subscriber(table, pid) do
    # Remove pid from all topic subscriber lists
    :ets.foldl(
      fn {topic, subscribers}, _acc ->
        new_subscribers = List.delete(subscribers, pid)
        :ets.insert(table, {topic, new_subscribers})
        :ok
      end,
      :ok,
      table
    )
  end

  defp cleanup_loop(table, pid) do
    # Remove loop entry for this pid
    :ets.match_delete(table, {:_, pid})
  end

  defp schedule_rate_reset do
    Process.send_after(self(), :rate_reset, 1_000)
  end

  defp emit_telemetry(event, measurements) do
    :telemetry.execute(
      [:indrajaal, :unified_bus, event],
      measurements,
      %{timestamp: DateTime.utc_now()}
    )
  end

  # ============================================================
  # AUTO-DISCOVERY
  # ============================================================

  # Auto-discover and register control loops
  defp autodiscover_loops(state) do
    new_registry =
      Enum.reduce(@loop_modules, state.loop_registry, fn {loop_id, module}, registry ->
        update_loop_registration(loop_id, module, registry, state)
      end)

    %{state | loop_registry: new_registry}
  end

  defp update_loop_registration(loop_id, module, registry, state) do
    case Map.get(registry, loop_id) do
      nil ->
        discover_new_loop(loop_id, module, registry, state)

      pid ->
        update_existing_loop(loop_id, pid, module, registry, state)
    end
  end

  defp discover_new_loop(loop_id, module, registry, state) do
    case find_loop_process(module, loop_id) do
      {:ok, pid} ->
        Logger.debug("[UnifiedBus] Auto-discovered loop: #{loop_id}")
        Process.monitor(pid)
        :ets.insert(state.loops, {loop_id, pid})
        Map.put(registry, loop_id, pid)

      :not_found ->
        registry
    end
  end

  defp update_existing_loop(loop_id, pid, module, registry, state) do
    if Process.alive?(pid) do
      registry
    else
      rediscover_loop(loop_id, module, registry, state)
    end
  end

  defp rediscover_loop(loop_id, module, registry, state) do
    case find_loop_process(module, loop_id) do
      {:ok, new_pid} ->
        Logger.debug("[UnifiedBus] Re-discovered loop: #{loop_id}")
        Process.monitor(new_pid)
        :ets.insert(state.loops, {loop_id, new_pid})
        Map.put(registry, loop_id, new_pid)

      :not_found ->
        Map.delete(registry, loop_id)
    end
  end

  # Find a loop process by module or name
  defp find_loop_process(module, loop_id) do
    cond do
      # Try module name first
      pid = GenServer.whereis(module) ->
        {:ok, pid}

      # Try atom name
      pid = GenServer.whereis(loop_id) ->
        {:ok, pid}

      # Try global name
      pid = GenServer.whereis({:global, loop_id}) ->
        {:ok, pid}

      true ->
        :not_found
    end
  end

  # Schedule next autodiscovery (every 30 seconds)
  defp schedule_autodiscover do
    Process.send_after(self(), :autodiscover, 30_000)
  end

  # ============================================================
  # RATE LIMITING
  # ============================================================

  # Calculate current event rate from sliding window
  defp calculate_current_rate(event_window) when is_list(event_window) do
    now = System.monotonic_time(:millisecond)
    window_ms = 1000

    count =
      Enum.count(event_window, fn
        {ts, _} -> now - ts < window_ms
        _ -> false
      end)

    # Events per second
    count * 1.0
  end

  defp calculate_current_rate(_), do: 0.0

  # ============================================================
  # DECISION EXECUTION
  # ============================================================

  # Execute a decision through the appropriate subsystem
  defp execute_decision(decision, state) do
    Logger.debug("[UnifiedBus] Executing decision: #{inspect(Map.get(decision, :action))}")

    # Enrich decision with metadata
    enriched_decision = %{
      type: :execute_decision,
      timestamp: DateTime.utc_now(),
      sequence: state.metrics.decisions_executed + 1,
      decision: decision
    }

    # Route decision based on action type
    route_decision(enriched_decision, state)

    # Update metrics
    new_metrics = Map.update!(state.metrics, :decisions_executed, &(&1 + 1))

    emit_telemetry(:execute, %{
      action: Map.get(decision, :action),
      confidence: Map.get(decision, :confidence, 0)
    })

    %{state | metrics: new_metrics}
  end

  # Route decision to appropriate handlers based on action type
  defp route_decision(enriched_decision, state) do
    decision = enriched_decision.decision
    action = Map.get(decision, :action)

    case action do
      action when action in [:scale_up, :scale_down, :emergency_scale_up] ->
        # ACE handles scaling decisions
        if pid = Map.get(state.loop_registry, :ace) do
          send_to_loop(pid, :ace, enriched_decision)
        end

        # Also notify Homeostasis for awareness
        if pid = Map.get(state.loop_registry, :homeostasis) do
          send_to_loop(pid, :homeostasis, enriched_decision)
        end

      :alert ->
        # Broadcast alerts to all loops
        Enum.each(state.loop_registry, fn {loop_id, pid} ->
          send_to_loop(pid, loop_id, enriched_decision)
        end)

      :config_change ->
        # Notify OODA and GDE
        for loop_id <- [:ooda, :gde] do
          if pid = Map.get(state.loop_registry, loop_id) do
            send_to_loop(pid, loop_id, enriched_decision)
          end
        end

      :maintain ->
        # No action needed for maintain decisions
        :ok

      _ ->
        # Default: broadcast to all
        Enum.each(state.loop_registry, fn {loop_id, pid} ->
          send_to_loop(pid, loop_id, enriched_decision)
        end)
    end
  end

  # ============================================================
  # LOOP BROADCASTING
  # ============================================================

  # Broadcast event to all registered control loops
  defp broadcast_to_all_loops(event, state) do
    start_time = System.monotonic_time(:microsecond)
    now = System.monotonic_time(:millisecond)

    # Enrich event with metadata
    enriched_event = %{
      type: :control_event,
      timestamp: DateTime.utc_now(),
      sequence: state.metrics.loop_broadcasts + 1,
      payload: event
    }

    # SC-BUS-002: Send async to all registered loops
    delivered =
      Enum.reduce(state.loop_registry, 0, fn {loop_id, pid}, count ->
        case send_to_loop(pid, loop_id, enriched_event) do
          :ok -> count + 1
          :error -> count
        end
      end)

    # Update metrics
    latency = System.monotonic_time(:microsecond) - start_time
    new_metrics = update_broadcast_metrics(state.metrics, latency, delivered)

    # Update event window for rate limiting
    new_window = [{now, event} | state.event_window] |> Enum.take(@event_window_size)

    emit_telemetry(:loop_broadcast, %{
      delivered: delivered,
      latency_us: latency
    })

    %{state | event_window: new_window, metrics: new_metrics}
  end

  # Send event to a specific loop (non-blocking)
  defp send_to_loop(pid, loop_id, event) do
    if Process.alive?(pid) do
      # SC-BUS-002: Use send for non-blocking delivery
      # Send as {:control_event, event} for compatibility with FastOODA
      send(pid, {:control_event, event})
      :ok
    else
      Logger.warning("[UnifiedBus] Loop #{loop_id} not alive")
      :error
    end
  rescue
    error ->
      Logger.warning("[UnifiedBus] Failed to send to #{loop_id}: #{inspect(error)}")
      :error
  end

  # Update broadcast metrics with new latency
  defp update_broadcast_metrics(metrics, latency, delivered) do
    count = metrics.loop_broadcasts + 1
    current_avg = Map.get(metrics, :avg_broadcast_latency_us, 0.0)

    # Running average
    new_avg = (current_avg * (count - 1) + latency) / count

    metrics
    |> Map.put(:loop_broadcasts, count)
    |> Map.put(:avg_broadcast_latency_us, new_avg)
    |> Map.update!(:events_delivered, &(&1 + delivered))
  end
end
