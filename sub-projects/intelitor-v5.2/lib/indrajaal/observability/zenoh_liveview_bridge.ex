defmodule Indrajaal.Observability.ZenohLiveViewBridge do
  @moduledoc """
  Zenoh-LiveView Bridge for real-time UI updates.

  WHAT: Bridges Zenoh pub/sub messages to Phoenix LiveView via Phoenix.PubSub.
        Enables real-time nervous system data to flow to the UI.

  WHY:
    - SC-PROM-003: Dashboard MUST refresh every 30s (we do better - real-time)
    - 12.1.0.0.0: Wire Nervous System (Zenoh to UI)
    - AOR-PROM-001: Agents MUST report thinking state to Dashboard bus

  CONSTRAINTS:
    - SC-PRF-050: Updates < 50ms latency
    - SC-BUS-001: Async messaging only
    - SC-BUS-002: No blocking operations

  ## Architecture

  ```
  Zenoh Network          Bridge              Phoenix LiveView
  ┌──────────────┐      ┌─────────────┐      ┌──────────────┐
  │ KPI Publisher│─────▶│ ZenohLive   │─────▶│ Dashboard    │
  │ Control Sub  │─────▶│ ViewBridge  │─────▶│ Components   │
  │ Telemetry    │─────▶│             │─────▶│              │
  └──────────────┘      └─────────────┘      └──────────────┘
                              │
                              ▼
                        Phoenix.PubSub
                        "zenoh:*" topics
  ```

  ## Topics Bridged
  - `zenoh:kpi` - Key Performance Indicators
  - `zenoh:metrics` - System metrics
  - `zenoh:agents` - Agent status updates
  - `zenoh:alerts` - Alert notifications
  - `zenoh:health` - Health status
  - `zenoh:evolution` - Evolution events
  - `zenoh:tests` - ExUnit test events (SC-ZTEST-001)
  - `zenoh:boot` - Boot phase transitions (SC-ZTEST-009)
  - `zenoh:smoke` - F# smoke test results (SC-ZTEST-001)
  - `zenoh:orchestrator` - Aggregated test orchestration

  ## Usage

  In LiveView:
  ```elixir
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ZenohLiveViewBridge.subscribe(:kpi)
      ZenohLiveViewBridge.subscribe(:agents)
    end
    {:ok, socket}
  end

  def handle_info({:zenoh_update, :kpi, data}, socket) do
    {:noreply, assign(socket, :kpi_data, data)}
  end
  ```
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub

  @pubsub Indrajaal.PubSub
  @bridge_interval_ms 100
  @max_batch_size 50

  # Zenoh key expression to topic mapping
  @key_mappings %{
    "indrajaal/kpi/**" => :kpi,
    "indrajaal/metrics/**" => :metrics,
    "indrajaal/agents/**" => :agents,
    "indrajaal/alerts/**" => :alerts,
    "indrajaal/health/**" => :health,
    "indrajaal/evolution/**" => :evolution,
    "indrajaal/fractal/**" => :fractal,
    "indrajaal/safety/**" => :safety,
    "indrajaal/git/**" => :git,
    # SC-ZTEST-001: Real-time test feedback topics
    "indrajaal/test/**" => :tests,
    "indrajaal/boot/**" => :boot,
    "indrajaal/smoke/**" => :smoke,
    "indrajaal/orchestrator/**" => :orchestrator
  }

  # ══════════════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ══════════════════════════════════════════════════════════════════════════════

  @doc """
  Start the bridge GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribe a LiveView process to a Zenoh topic.

  ## Examples

      ZenohLiveViewBridge.subscribe(:kpi)
      ZenohLiveViewBridge.subscribe(:agents)
      ZenohLiveViewBridge.subscribe(:all)  # Subscribe to all topics
  """
  @spec subscribe(atom()) :: :ok | {:error, term()}
  def subscribe(:all) do
    Enum.each(
      [
        :kpi,
        :metrics,
        :agents,
        :alerts,
        :health,
        :evolution,
        :fractal,
        :safety,
        :git,
        :tests,
        :boot,
        :smoke,
        :orchestrator
      ],
      &subscribe/1
    )
  end

  def subscribe(topic) when is_atom(topic) do
    PubSub.subscribe(@pubsub, "zenoh:#{topic}")
  end

  @doc """
  Unsubscribe from a Zenoh topic.
  """
  @spec unsubscribe(atom()) :: :ok | {:error, term()}
  def unsubscribe(topic) when is_atom(topic) do
    PubSub.unsubscribe(@pubsub, "zenoh:#{topic}")
  end

  @doc """
  Publish a message to LiveView subscribers (used by Zenoh subscribers).
  """
  @spec broadcast(atom(), map()) :: :ok | {:error, term()}
  def broadcast(topic, data) when is_atom(topic) and is_map(data) do
    message = {:zenoh_update, topic, enrich_message(data)}
    PubSub.broadcast(@pubsub, "zenoh:#{topic}", message)
  end

  @doc """
  Get bridge statistics.
  """
  @spec get_stats(GenServer.server()) :: map()
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats)
  end

  @doc """
  Get current subscriptions.
  """
  @spec get_subscriptions(GenServer.server()) :: list()
  def get_subscriptions(server \\ __MODULE__) do
    GenServer.call(server, :get_subscriptions)
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ══════════════════════════════════════════════════════════════════════════════

  @impl true
  def init(opts) do
    Logger.info("[ZenohLiveViewBridge] Starting bridge - SC-PROM-003")

    state = %{
      subscriptions: [],
      stats: %{
        messages_bridged: 0,
        last_message_at: nil,
        messages_per_topic: %{},
        latency_samples: []
      },
      buffer: [],
      started_at: DateTime.utc_now()
    }

    # Schedule periodic flush
    Process.send_after(self(), :flush_buffer, @bridge_interval_ms)

    # Subscribe to Zenoh telemetry events
    setup_zenoh_subscriptions(opts)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
        buffer_size: length(state.buffer),
        active_subscriptions: length(state.subscriptions)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_subscriptions, _from, state) do
    {:reply, state.subscriptions, state}
  end

  @impl true
  def handle_cast({:zenoh_message, key_expr, payload}, state) do
    # Buffer incoming messages for batch processing (SC-BUS-001)
    message = %{
      key_expr: key_expr,
      payload: payload,
      received_at: System.monotonic_time(:microsecond)
    }

    new_buffer = [message | state.buffer]

    # Flush immediately if buffer is full
    if length(new_buffer) >= @max_batch_size do
      {:noreply, flush_buffer(%{state | buffer: new_buffer})}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  @impl true
  def handle_info(:flush_buffer, state) do
    # Schedule next flush
    Process.send_after(self(), :flush_buffer, @bridge_interval_ms)

    {:noreply, flush_buffer(state)}
  end

  @impl true
  def handle_info({:zenoh_telemetry, event_name, measurements, metadata}, state) do
    # Handle telemetry events from Zenoh modules
    topic = event_to_topic(event_name)

    data = %{
      event: event_name,
      measurements: measurements,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    broadcast(topic, data)
    {:noreply, update_stats(state, topic)}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # PRIVATE FUNCTIONS
  # ══════════════════════════════════════════════════════════════════════════════

  defp setup_zenoh_subscriptions(_opts) do
    # Attach to telemetry events from Zenoh modules
    events = [
      [:indrajaal, :zenoh, :kpi, :publish],
      [:indrajaal, :zenoh, :control, :receive],
      [:indrajaal, :zenoh, :evolution, :publish],
      [:indrajaal, :zenoh, :fractal, :publish],
      [:indrajaal, :zenoh, :health, :update],
      [:indrajaal, :prometheus, :metabolism, :update],
      [:indrajaal, :prometheus, :dashboard, :refresh],
      [:indrajaal, :safety, :sentinel, :alert],
      [:indrajaal, :safety, :defense, :escalation],
      [:indrajaal, :zenoh, :git, :publish],
      [:indrajaal, :git, :commit, :published],
      [:indrajaal, :git, :health, :published],
      [:indrajaal, :git, :suggest, :published],
      # SC-ZTEST-001 to SC-ZTEST-008: Real-time test feedback events
      [:indrajaal, :test, :suite, :started],
      [:indrajaal, :test, :suite, :finished],
      [:indrajaal, :test, :module, :started],
      [:indrajaal, :test, :module, :finished],
      [:indrajaal, :test, :case, :started],
      [:indrajaal, :test, :case, :passed],
      [:indrajaal, :test, :case, :failed],
      [:indrajaal, :test, :case, :skipped],
      # Boot phase events (SC-ZTEST-009 to SC-ZTEST-011)
      [:indrajaal, :boot, :phase, :started],
      [:indrajaal, :boot, :phase, :finished],
      [:indrajaal, :boot, :container, :health],
      [:indrajaal, :boot, :quorum, :update],
      [:indrajaal, :boot, :state_vector, :update],
      # Smoke test events
      [:indrajaal, :smoke, :result, :published],
      [:indrajaal, :smoke, :batch, :started],
      [:indrajaal, :smoke, :batch, :finished],
      # Orchestrator aggregate events
      [:indrajaal, :orchestrator, :aggregate, :update],
      [:indrajaal, :orchestrator, :alert, :raised]
    ]

    :telemetry.attach_many(
      "zenoh-liveview-bridge",
      events,
      &handle_telemetry_event/4,
      %{bridge_pid: self()}
    )

    Logger.debug("[ZenohLiveViewBridge] Attached to #{length(events)} telemetry events")
  end

  defp handle_telemetry_event(event_name, measurements, metadata, %{bridge_pid: pid}) do
    send(pid, {:zenoh_telemetry, event_name, measurements, metadata})
  end

  defp flush_buffer(%{buffer: []} = state), do: state

  defp flush_buffer(%{buffer: buffer} = state) do
    # Process buffered messages (SC-PRF-050: < 50ms)
    # SC-BUS-004: Preserve event ordering - reverse LIFO buffer to FIFO
    start_time = System.monotonic_time(:microsecond)

    buffer
    |> Enum.reverse()
    |> Enum.each(fn %{key_expr: key_expr, payload: payload} ->
      topic = key_expr_to_topic(key_expr)
      broadcast(topic, decode_payload(payload))
    end)

    elapsed_us = System.monotonic_time(:microsecond) - start_time

    if elapsed_us > 50_000 do
      Logger.warning(
        "[ZenohLiveViewBridge] Buffer flush exceeded 50ms: #{elapsed_us}us - SC-PRF-050 violation"
      )
    end

    new_stats = %{
      state.stats
      | messages_bridged: state.stats.messages_bridged + length(buffer),
        last_message_at: DateTime.utc_now(),
        latency_samples: Enum.take([elapsed_us | state.stats.latency_samples], 100)
    }

    %{state | buffer: [], stats: new_stats}
  end

  defp key_expr_to_topic(key_expr) do
    # Match key expression to topic
    Enum.find_value(@key_mappings, :unknown, fn {pattern, topic} ->
      if matches_pattern?(key_expr, pattern), do: topic
    end)
  end

  defp matches_pattern?(key_expr, pattern) do
    # Simple wildcard matching for Zenoh key expressions
    regex_pattern =
      pattern
      |> String.replace("**", ".*")
      |> String.replace("*", "[^/]*")

    Regex.match?(~r/^#{regex_pattern}$/, key_expr)
  end

  defp event_to_topic(event_name) do
    case event_name do
      [:indrajaal, :zenoh, :kpi | _] -> :kpi
      [:indrajaal, :zenoh, :control | _] -> :agents
      [:indrajaal, :zenoh, :evolution | _] -> :evolution
      [:indrajaal, :zenoh, :fractal | _] -> :fractal
      [:indrajaal, :zenoh, :health | _] -> :health
      [:indrajaal, :prometheus | _] -> :metrics
      [:indrajaal, :safety, :sentinel | _] -> :safety
      [:indrajaal, :safety, :defense | _] -> :safety
      [:indrajaal, :zenoh, :git | _] -> :git
      [:indrajaal, :git | _] -> :git
      # SC-ZTEST-001: Real-time test feedback routing
      [:indrajaal, :test | _] -> :tests
      [:indrajaal, :boot | _] -> :boot
      [:indrajaal, :smoke | _] -> :smoke
      [:indrajaal, :orchestrator | _] -> :orchestrator
      _ -> :unknown
    end
  end

  defp decode_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{raw: payload}
    end
  end

  defp decode_payload(payload) when is_map(payload), do: payload
  defp decode_payload(payload), do: %{value: payload}

  defp enrich_message(data) do
    Map.merge(data, %{
      bridged_at: DateTime.utc_now(),
      bridge_version: "1.0.0"
    })
  end

  defp update_stats(state, topic) do
    topic_count = Map.get(state.stats.messages_per_topic, topic, 0)
    new_topic_counts = Map.put(state.stats.messages_per_topic, topic, topic_count + 1)

    %{
      state
      | stats: %{
          state.stats
          | messages_bridged: state.stats.messages_bridged + 1,
            last_message_at: DateTime.utc_now(),
            messages_per_topic: new_topic_counts
        }
    }
  end
end
