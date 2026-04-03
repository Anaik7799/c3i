defmodule Indrajaal.Cluster.ZenohMesh do
  @moduledoc """
  P2.2: Zenoh Router Integration for Cross-Node Pub/Sub.

  WHAT: Zenoh-based distributed messaging mesh for cross-node communication
        using FQUN (Fully Qualified Unique Name) key expressions.

  WHY: Provides high-performance pub/sub messaging that complements Erlang
       distribution for non-critical real-time data streaming.

  CONSTRAINTS: Must use FQUN key expressions per specification and integrate
               with existing Fractal Logging system.

  ## Architecture

  This module provides:
  1. **Key Expression Management**: FQUN-compliant key expression generation
  2. **Pub/Sub Channels**: Domain-specific messaging channels
  3. **Cross-Node Routing**: Automatic message routing across cluster nodes
  4. **Telemetry Integration**: OpenTelemetry span propagation

  ## FQUN Key Expression Format

      indrajaal/{domain}/{subdomain}/{resource_type}/{resource_id}@{node}\#{correlation_id}

  Examples:
  - `indrajaal/alarms/fire/events/evt_123@app-1#corr_456`
  - `indrajaal/devices/camera/streams/cam_789@app-2#corr_012`

  ## STAMP Compliance

  - SC-MSG-001: FQUN key expression format required
  - SC-OBS-069: Dual logging integration
  - SC-PRF-050: Response time < 50ms for pub/sub operations

  ## Mathematical Invariants

      ∀ key ∈ KeyExpressions: Matches(key, FQUN_REGEX) = true
      ∀ msg ∈ Messages: Latency(pub, sub) < 50ms
      ∀ node ∈ Cluster: Subscribed(node, "indrajaal/**") = true
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  # ============================================================================
  # TYPE DEFINITIONS
  # ============================================================================

  @type key_expression :: String.t()
  @type domain :: String.t()
  @type payload :: binary() | map()
  @type subscription :: reference()

  # ============================================================================
  # CONSTANTS
  # ============================================================================

  @fqun_prefix "indrajaal"
  @default_port 7447
  @heartbeat_interval 10_000
  @max_message_size 1_048_576

  # FQUN regex validation
  @fqun_regex ~r/^indrajaal\/[a-z_]+\/[a-z_]+\/[a-z_]+\/[a-zA-Z0-9_-]+@[a-zA-Z0-9_.-]+#[a-zA-Z0-9_-]+$/

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Start the Zenoh mesh coordinator.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate a FQUN-compliant key expression.

  ## Examples

      iex> ZenohMesh.fqun("alarms", "fire", "events", "evt_123")
      "indrajaal/alarms/fire/events/evt_123@app-1#corr_456"
  """
  @spec fqun(String.t(), String.t(), String.t(), String.t(), keyword()) :: key_expression()
  def fqun(domain, subdomain, resource_type, resource_id, opts \\ []) do
    node = Keyword.get(opts, :node, node_name())
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())

    "#{@fqun_prefix}/#{domain}/#{subdomain}/#{resource_type}/#{resource_id}@#{node}##{correlation_id}"
  end

  @doc """
  Validate that a key expression matches the FQUN format.
  """
  @spec valid_fqun?(key_expression()) :: boolean()
  def valid_fqun?(key_expr) do
    Regex.match?(@fqun_regex, key_expr)
  end

  @doc """
  Parse a FQUN key expression into its components.

  Returns `{:ok, map}` or `{:error, :invalid_fqun}`.
  """
  @spec parse_fqun(key_expression()) :: {:ok, map()} | {:error, :invalid_fqun}
  def parse_fqun(key_expr) do
    case Regex.named_captures(
           ~r/^(?<prefix>indrajaal)\/(?<domain>[a-z_]+)\/(?<subdomain>[a-z_]+)\/(?<resource_type>[a-z_]+)\/(?<resource_id>[a-zA-Z0-9_-]+)@(?<node>[a-zA-Z0-9_.-]+)#(?<correlation_id>[a-zA-Z0-9_-]+)$/,
           key_expr
         ) do
      nil -> {:error, :invalid_fqun}
      captures -> {:ok, captures}
    end
  end

  @doc """
  Publish a message to a key expression.

  ## Options
  - `:encoding` - Message encoding (`:json`, `:binary`, `:msgpack`)
  - `:priority` - Message priority (1-7, default 5)
  - `:congestion_control` - `:block` or `:drop` (default `:drop`)
  """
  @spec publish(key_expression(), payload(), keyword()) :: :ok | {:error, term()}
  def publish(key_expr, payload, opts \\ []) do
    GenServer.call(__MODULE__, {:publish, key_expr, payload, opts})
  end

  @doc """
  Subscribe to a key expression pattern.

  Returns a subscription reference that can be used to unsubscribe.

  ## Examples

      # Subscribe to all alarm events
      {:ok, ref} = ZenohMesh.subscribe("indrajaal/alarms/**", fn msg -> ... end)

      # Subscribe to specific camera
      {:ok, ref} = ZenohMesh.subscribe("indrajaal/devices/camera/streams/cam_001@*#*", fn msg -> ... end)
  """
  @spec subscribe(key_expression(), (map() -> any()), keyword()) ::
          {:ok, subscription()} | {:error, term()}
  def subscribe(key_pattern, callback, opts \\ []) when is_function(callback, 1) do
    GenServer.call(__MODULE__, {:subscribe, key_pattern, callback, opts})
  end

  @doc """
  Unsubscribe from a subscription.
  """
  @spec unsubscribe(subscription()) :: :ok
  def unsubscribe(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  Query data from a key expression (get operation).
  """
  @spec query(key_expression(), keyword()) :: {:ok, list()} | {:error, term()}
  def query(key_expr, opts \\ []) do
    GenServer.call(__MODULE__, {:query, key_expr, opts})
  end

  @doc """
  Put data to a key expression (storage operation).
  """
  @spec put(key_expression(), payload(), keyword()) :: :ok | {:error, term()}
  def put(key_expr, payload, opts \\ []) do
    GenServer.call(__MODULE__, {:put, key_expr, payload, opts})
  end

  @doc """
  Get mesh status and statistics.
  """
  @spec mesh_status() :: map()
  def mesh_status do
    GenServer.call(__MODULE__, :mesh_status)
  end

  @doc """
  List all active subscriptions.
  """
  @spec list_subscriptions() :: list()
  def list_subscriptions do
    GenServer.call(__MODULE__, :list_subscriptions)
  end

  # ============================================================================
  # DOMAIN-SPECIFIC CHANNELS
  # ============================================================================

  @doc """
  Get key expression for alarm events.
  """
  @spec alarm_key(String.t(), String.t(), keyword()) :: key_expression()
  def alarm_key(alarm_type, alarm_id, opts \\ []) do
    fqun("alarms", alarm_type, "events", alarm_id, opts)
  end

  @doc """
  Get key expression for device telemetry.
  """
  @spec device_key(String.t(), String.t(), keyword()) :: key_expression()
  def device_key(device_type, device_id, opts \\ []) do
    fqun("devices", device_type, "telemetry", device_id, opts)
  end

  @doc """
  Get key expression for cluster events.
  """
  @spec cluster_key(String.t(), String.t(), keyword()) :: key_expression()
  def cluster_key(event_type, event_id, opts \\ []) do
    fqun("cluster", "nodes", event_type, event_id, opts)
  end

  @doc """
  Get key expression for observability metrics.
  """
  @spec metrics_key(String.t(), String.t(), keyword()) :: key_expression()
  def metrics_key(metric_type, metric_id, opts \\ []) do
    fqun("observability", "metrics", metric_type, metric_id, opts)
  end

  @doc """
  Get key expression for fractal log events.
  """
  @spec fractal_log_key(String.t(), String.t(), keyword()) :: key_expression()
  def fractal_log_key(level, channel, opts \\ []) do
    log_id = Keyword.get(opts, :log_id, generate_log_id())
    fqun("observability", "fractal_logs", level, log_id, Keyword.put(opts, :subdomain, channel))
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl GenServer
  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)

    state = %{
      port: port,
      subscriptions: %{},
      subscription_counter: 0,
      published_count: 0,
      received_count: 0,
      started_at: DateTime.utc_now(),
      peers: [],
      connected: false,
      # Health propagation state - SC-HEALTH-PROP-001
      node_health_states: %{},
      last_health_update: nil,
      health_event_log: []
    }

    # Schedule heartbeat
    schedule_heartbeat()

    Logger.info("[ZenohMesh] Started on port #{port}")

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:publish, key_expr, payload, opts}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      if valid_fqun?(key_expr) or String.contains?(key_expr, "**") do
        # Encode payload
        encoded = encode_payload(payload, Keyword.get(opts, :encoding, :json))

        if byte_size(encoded) <= @max_message_size do
          # Dispatch to coordinator if available
          if Code.ensure_loaded?(ZenohCoordinator) do
            ZenohCoordinator.publish_coord(key_expr, encoded)
          else
            # Local-only fallback: dispatch to local subscribers
            dispatch_to_local_subscribers(key_expr, payload, state)
          end

          :ok
        else
          {:error, :message_too_large}
        end
      else
        {:error, :invalid_key_expression}
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_time

    new_state =
      if result == :ok do
        # Log latency for SC-PRF-050 compliance
        if elapsed_us > 50_000 do
          Logger.warning(
            "[ZenohMesh] Publish latency exceeded 50ms: #{elapsed_us}µs - SC-PRF-050 violation"
          )
        end

        %{state | published_count: state.published_count + 1}
      else
        state
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:subscribe, key_pattern, callback, _opts}, _from, state) do
    ref = make_ref()

    subscription = %{
      ref: ref,
      pattern: key_pattern,
      callback: callback,
      created_at: DateTime.utc_now(),
      received_count: 0
    }

    new_state = %{
      state
      | subscriptions: Map.put(state.subscriptions, ref, subscription),
        subscription_counter: state.subscription_counter + 1
    }

    Logger.debug("[ZenohMesh] New subscription: #{key_pattern}")

    {:reply, {:ok, ref}, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, ref}, _from, state) do
    new_state = %{state | subscriptions: Map.delete(state.subscriptions, ref)}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:query, _key_expr, _opts}, _from, state) do
    # Query operation - would delegate to Zenoh storage
    {:reply, {:ok, []}, state}
  end

  @impl GenServer
  def handle_call({:put, key_expr, payload, opts}, _from, state) do
    # Put operation - similar to publish but for storage
    result =
      if valid_fqun?(key_expr) do
        encoded = encode_payload(payload, Keyword.get(opts, :encoding, :json))

        if byte_size(encoded) <= @max_message_size do
          :ok
        else
          {:error, :message_too_large}
        end
      else
        {:error, :invalid_key_expression}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:mesh_status, _from, state) do
    status = %{
      port: state.port,
      connected: state.connected,
      peers: state.peers,
      subscription_count: map_size(state.subscriptions),
      published_count: state.published_count,
      received_count: state.received_count,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:list_subscriptions, _from, state) do
    subs =
      state.subscriptions
      |> Enum.map(fn {ref, sub} ->
        %{
          ref: ref,
          pattern: sub.pattern,
          created_at: sub.created_at,
          received_count: sub.received_count
        }
      end)

    {:reply, subs, state}
  end

  @impl GenServer
  def handle_call(:get_mesh_health_state, _from, state) do
    health_view = %{
      nodes: state.node_health_states,
      last_update: state.last_health_update,
      total_nodes: map_size(state.node_health_states),
      healthy_count: count_by_state(state.node_health_states, :healthy),
      degraded_count: count_by_state(state.node_health_states, :degraded),
      failed_count: count_by_state(state.node_health_states, :failed),
      peers: state.peers,
      recent_events: Enum.take(state.health_event_log, 10)
    }

    {:reply, health_view, state}
  end

  @impl GenServer
  def handle_cast({:update_peer, peer_node, payload}, state) do
    # Update peer tracking from heartbeat
    now = DateTime.utc_now()

    peer_info = %{
      node: peer_node,
      last_seen: now,
      subscriptions: Map.get(payload, "subscriptions", 0),
      status: Map.get(payload, "status", "alive")
    }

    updated_peers =
      state.peers
      |> Enum.reject(fn p -> Map.get(p, :node) == peer_node end)
      |> Kernel.++([peer_info])

    {:noreply, %{state | peers: updated_peers}}
  end

  @impl GenServer
  def handle_cast({:update_health_state, node_id, new_state, reason}, state) do
    # Track health state change for a node
    now = DateTime.utc_now()

    previous_state = Map.get(state.node_health_states, node_id, :absent)

    event = %{
      node_id: node_id,
      previous_state: previous_state,
      new_state: new_state,
      timestamp: now,
      reason: reason
    }

    new_health_states = Map.put(state.node_health_states, node_id, new_state)
    new_event_log = [event | Enum.take(state.health_event_log, 99)]

    {:noreply,
     %{
       state
       | node_health_states: new_health_states,
         last_health_update: now,
         health_event_log: new_event_log
     }}
  end

  @impl GenServer
  def handle_info(:heartbeat, state) do
    # Broadcast cluster heartbeat
    key = cluster_key("heartbeat", node_name())

    payload = %{
      node: Node.self(),
      timestamp: DateTime.utc_now(),
      subscriptions: map_size(state.subscriptions)
    }

    spawn(fn -> publish(key, payload) end)

    schedule_heartbeat()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:zenoh_message, key_expr, payload}, state) do
    # Dispatch incoming message to matching subscribers
    new_state = dispatch_to_local_subscribers(key_expr, payload, state)
    {:noreply, %{new_state | received_count: state.received_count + 1}}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp count_by_state(health_states, target_state) do
    health_states
    |> Enum.count(fn {_node_id, state} -> state == target_state end)
  end

  defp node_name do
    Node.self()
    |> Atom.to_string()
    |> String.split("@")
    |> List.first()
  end

  defp generate_correlation_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    encoded = Base.encode16(random_bytes, case: :lower)
    "corr_" <> encoded
  end

  defp generate_log_id do
    random_bytes = :crypto.strong_rand_bytes(6)
    encoded = Base.encode16(random_bytes, case: :lower)
    "log_" <> encoded
  end

  defp encode_payload(payload, :json) when is_map(payload) do
    Jason.encode!(payload)
  end

  defp encode_payload(payload, :json) when is_binary(payload) do
    payload
  end

  defp encode_payload(payload, :binary) when is_binary(payload) do
    payload
  end

  defp encode_payload(payload, :binary) do
    :erlang.term_to_binary(payload)
  end

  defp encode_payload(payload, _encoding) do
    Jason.encode!(payload)
  rescue
    _ -> inspect(payload)
  end

  defp dispatch_to_local_subscribers(key_expr, payload, state) do
    matching_subs =
      state.subscriptions
      |> Enum.filter(fn {_ref, sub} -> matches_pattern?(key_expr, sub.pattern) end)

    for {_ref, sub} <- matching_subs do
      message = %{
        key: key_expr,
        payload: payload,
        received_at: DateTime.utc_now()
      }

      # Execute callback in separate process
      spawn(fn ->
        try do
          sub.callback.(message)
        rescue
          e -> Logger.error("[ZenohMesh] Subscriber callback error: #{inspect(e)}")
        end
      end)
    end

    # Update received counts
    updated_subs =
      matching_subs
      |> Enum.reduce(state.subscriptions, fn {ref, sub}, acc ->
        Map.put(acc, ref, %{sub | received_count: sub.received_count + 1})
      end)

    %{state | subscriptions: updated_subs}
  end

  defp matches_pattern?(key_expr, pattern) do
    # Convert Zenoh pattern to regex
    regex_pattern =
      pattern
      |> String.replace("**", ".*")
      |> String.replace("*", "[^/]+")
      |> then(&"^#{&1}$")

    Regex.match?(~r/#{regex_pattern}/, key_expr)
  rescue
    _ -> false
  end

  # ============================================================================
  # F# ZENOH CHANNEL BRIDGE - SC-ZENOH-BRIDGE-001
  # ============================================================================
  # Bridges F# ZenohChannel (Cepaf.Zenoh.ZenohChannel) to Elixir GenServers
  # for bidirectional communication between CEPAF cockpit and Indrajaal mesh.
  # ============================================================================

  @doc """
  F# ZenohChannel bridge for CEPAF integration.

  Receives messages from F# ZenohChannel via the Zenoh pub/sub network
  and routes them to appropriate Elixir GenServers.

  ## STAMP Compliance
  - SC-ZENOH-BRIDGE-001: F# to Elixir message routing
  - SC-ZENOH-BRIDGE-002: Non-blocking dispatch (<10ms)
  - SC-ZENOH-BRIDGE-003: Telemetry key pattern matching

  ## Key Patterns
  - `indrajaal/telemetry/fsharp/**` - F# telemetry data
  - `indrajaal/control/**` - Control commands from cockpit
  - `indrajaal/fractal/**` - Fractal logging events
  """
  @spec subscribe_to_fsharp_channels() :: {:ok, list(subscription())} | {:error, term()}
  def subscribe_to_fsharp_channels do
    # Subscribe to all F# telemetry channels
    channels = [
      {"indrajaal/telemetry/fsharp/**", &handle_fsharp_telemetry/1},
      {"indrajaal/control/**", &handle_control_message/1},
      {"indrajaal/fractal/**", &handle_fractal_event/1},
      {"indrajaal/kpi/**", &handle_kpi_update/1},
      {"indrajaal/coord/**", &handle_coordination/1}
    ]

    results =
      channels
      |> Enum.map(fn {pattern, handler} ->
        case subscribe(pattern, handler) do
          {:ok, ref} -> {:ok, {pattern, ref}}
          error -> error
        end
      end)

    errors = results |> Enum.filter(&match?({:error, _}, &1))

    if Enum.empty?(errors) do
      refs = results |> Enum.map(fn {:ok, {_p, ref}} -> ref end)
      Logger.info("[ZenohMesh] Subscribed to #{length(refs)} F# channels")
      {:ok, refs}
    else
      {:error, {:partial_subscription, errors}}
    end
  end

  @doc """
  Publish message to F# ZenohChannel consumers.

  Routes messages from Elixir to F# components via Zenoh.
  Uses JSON encoding for cross-language compatibility.
  """
  @spec publish_to_fsharp(String.t(), map()) :: :ok | {:error, term()}
  def publish_to_fsharp(topic, payload) when is_map(payload) do
    # Ensure topic uses correct prefix for F# subscribers
    full_topic =
      if String.starts_with?(topic, "indrajaal/") do
        topic
      else
        "indrajaal/elixir/#{topic}"
      end

    # Add source metadata for F# side
    enriched_payload =
      Map.merge(payload, %{
        source: "elixir",
        node: node_name(),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    publish(full_topic, enriched_payload, encoding: :json)
  end

  # F# channel handlers
  defp handle_fsharp_telemetry(%{key: key, payload: payload}) do
    Logger.debug("[ZenohMesh] F# telemetry: #{key}")

    # Route to telemetry subscriber for processing
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohTelemetrySubscriber) do
      Indrajaal.Observability.ZenohTelemetrySubscriber.handle_fsharp_event(key, payload)
    end
  end

  defp handle_control_message(%{key: key, payload: payload}) do
    Logger.info("[ZenohMesh] Control command from F#: #{key}")

    # Parse command and route to appropriate handler
    command = extract_command_from_key(key)

    case command do
      "refresh" ->
        broadcast_mesh_refresh()

      "compile" ->
        trigger_compile_command(payload)

      "emergency" ->
        trigger_emergency_stop(payload)

      _ ->
        Logger.warning("[ZenohMesh] Unknown control command: #{command}")
    end
  end

  defp handle_fractal_event(%{key: key, payload: payload}) do
    # Route fractal events to the fractal logging system
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohFractalPublisher) do
      Indrajaal.Observability.ZenohFractalPublisher.handle_incoming_event(key, payload)
    end
  end

  defp handle_kpi_update(%{key: _key, payload: payload}) do
    # Update internal KPI state from external sources
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohKpiPublisher) do
      Indrajaal.Observability.ZenohKpiPublisher.merge_external_kpi(payload)
    end
  end

  defp handle_coordination(%{key: key, payload: payload}) do
    # Handle coordination messages (heartbeat, sync, barrier)
    case extract_command_from_key(key) do
      "heartbeat" -> handle_peer_heartbeat(payload)
      "sync" -> handle_sync_request(payload)
      "barrier" -> handle_barrier_signal(payload)
      _ -> :ok
    end
  end

  defp extract_command_from_key(key) do
    key
    |> String.split("/")
    |> List.last()
    |> String.downcase()
  end

  defp broadcast_mesh_refresh do
    # Notify all mesh components to refresh their state
    spawn(fn ->
      if Code.ensure_loaded?(Indrajaal.Distributed.DistributedMesh) do
        Indrajaal.Distributed.DistributedMesh.publish_status()
      end
    end)
  end

  defp trigger_compile_command(payload) do
    Logger.info("[ZenohMesh] Compile command received", payload: payload)
    # Could trigger compilation via existing mix tasks
    :ok
  end

  defp trigger_emergency_stop(payload) do
    Logger.warning("[ZenohMesh] Emergency stop requested", payload: payload)
    # Route to sentinel for emergency handling
    if Code.ensure_loaded?(Indrajaal.Cluster.Sentinel) do
      Indrajaal.Cluster.Sentinel.emergency_stop(payload)
    end
  end

  # ============================================================================
  # MESH TOPIC MANAGEMENT - SC-MESH-TOPIC-001
  # ============================================================================
  # Centralized topic registry for mesh communication.
  # Provides typed access to well-known mesh topics.
  # ============================================================================

  @doc """
  Get all registered mesh topics.

  Returns a map of topic categories to their key expressions.
  Used by mesh participants to discover available channels.
  """
  @spec mesh_topics() :: map()
  def mesh_topics do
    %{
      # Cluster coordination topics
      cluster: %{
        heartbeat: "indrajaal/cluster/nodes/heartbeat/**",
        status: "indrajaal/cluster/nodes/status/**",
        join: "indrajaal/cluster/nodes/join/**",
        leave: "indrajaal/cluster/nodes/leave/**",
        failover: "indrajaal/cluster/nodes/failover/**"
      },

      # Agent mesh topics
      agents: %{
        status: "indrajaal/agents/status/**",
        commands: "indrajaal/agents/commands/**",
        metrics: "indrajaal/agents/metrics/**",
        ooda: "indrajaal/agents/ooda/**"
      },

      # Worker mesh topics
      workers: %{
        jobs: "indrajaal/workers/jobs/**",
        results: "indrajaal/workers/results/**",
        load: "indrajaal/workers/load/**"
      },

      # Health propagation topics
      health: %{
        events: "indrajaal/health/events/**",
        consensus: "indrajaal/health/consensus/**",
        recovery: "indrajaal/health/recovery/**",
        emergency: "indrajaal/health/emergency/**"
      },

      # Observability topics
      observability: %{
        metrics: "indrajaal/observability/metrics/**",
        traces: "indrajaal/observability/traces/**",
        logs: "indrajaal/observability/fractal_logs/**",
        kpi: "indrajaal/observability/kpi/**"
      },

      # F# CEPAF integration topics
      cepaf: %{
        telemetry: "indrajaal/telemetry/fsharp/**",
        control: "indrajaal/control/**",
        fractal: "indrajaal/fractal/**",
        coordination: "indrajaal/coord/**"
      }
    }
  end

  @doc """
  Subscribe to a category of mesh topics.

  ## Examples

      # Subscribe to all health events
      {:ok, refs} = ZenohMesh.subscribe_category(:health, fn msg -> ... end)

      # Subscribe to all agent topics
      {:ok, refs} = ZenohMesh.subscribe_category(:agents, fn msg -> ... end)
  """
  @spec subscribe_category(atom(), (map() -> any())) ::
          {:ok, list(subscription())} | {:error, term()}
  def subscribe_category(category, callback)
      when is_atom(category) and is_function(callback, 1) do
    case Map.get(mesh_topics(), category) do
      nil ->
        {:error, {:unknown_category, category}}

      topics when is_map(topics) ->
        results =
          topics
          |> Enum.map(fn {_name, pattern} ->
            subscribe(pattern, callback)
          end)

        errors = results |> Enum.filter(&match?({:error, _}, &1))

        if Enum.empty?(errors) do
          refs = results |> Enum.map(fn {:ok, ref} -> ref end)
          {:ok, refs}
        else
          {:error, {:partial_subscription, errors}}
        end
    end
  end

  @doc """
  Publish to a specific mesh topic by category and name.

  ## Examples

      ZenohMesh.publish_to_topic(:health, :events, %{node: "app-1", status: "degraded"})
      ZenohMesh.publish_to_topic(:agents, :status, %{agent_id: "ooda", state: "running"})
  """
  @spec publish_to_topic(atom(), atom(), map(), keyword()) :: :ok | {:error, term()}
  def publish_to_topic(category, topic_name, payload, opts \\ []) do
    case get_in(mesh_topics(), [category, topic_name]) do
      nil ->
        {:error, {:unknown_topic, {category, topic_name}}}

      pattern when is_binary(pattern) ->
        # Replace wildcards with specific identifiers
        resource_id = Keyword.get(opts, :resource_id, generate_correlation_id())
        specific_key = String.replace(pattern, "**", resource_id)
        publish(specific_key, payload, opts)
    end
  end

  # ============================================================================
  # HEALTH PROPAGATION ACROSS NODES - SC-HEALTH-PROP-001
  # ============================================================================
  # Implements cross-node health propagation via Zenoh pub/sub.
  # Mirrors F# HealthPropagation module for Elixir side.
  # ============================================================================

  @type health_state :: :healthy | :degraded | :failed | :starting | :absent
  @type health_event :: %{
          node_id: String.t(),
          previous_state: health_state(),
          new_state: health_state(),
          timestamp: DateTime.t(),
          reason: String.t() | nil
        }

  @doc """
  Publish health state change to the mesh.

  Broadcasts health events to all subscribed nodes for
  distributed health awareness and coordinated recovery.

  ## STAMP Compliance
  - SC-HEALTH-PROP-001: Health event propagation
  - SC-PRF-050: Latency <50ms
  - SC-CEP-003: 3/5 consensus for health decisions

  ## Examples

      ZenohMesh.publish_health_event("app-1", :healthy, :degraded, "Memory pressure")
  """
  @spec publish_health_event(String.t(), health_state(), health_state(), String.t() | nil) ::
          :ok | {:error, term()}
  def publish_health_event(node_id, previous_state, new_state, reason \\ nil) do
    event = %{
      node_id: node_id,
      previous_state: Atom.to_string(previous_state),
      new_state: Atom.to_string(new_state),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      reason: reason,
      source_node: node_name(),
      sequence: System.monotonic_time(:nanosecond)
    }

    key = fqun("health", "events", "state_change", node_id)
    publish(key, event, priority: 7)
  end

  @doc """
  Subscribe to health events from all mesh nodes.

  Returns subscription references for cleanup.
  Callback receives parsed health events.
  """
  @spec subscribe_to_health_events((health_event() -> any())) ::
          {:ok, subscription()} | {:error, term()}
  def subscribe_to_health_events(callback) when is_function(callback, 1) do
    subscribe("indrajaal/health/events/**", fn msg ->
      event = parse_health_event(msg.payload)
      callback.(event)
    end)
  end

  @doc """
  Request health consensus for a node.

  Publishes a consensus request and collects responses.
  Returns aggregated health consensus result.

  ## STAMP Compliance
  - SC-CEP-003: 3/5 agreement required for consensus
  """
  @spec request_health_consensus(String.t(), timeout()) ::
          {:consensus, health_state(), non_neg_integer()} | {:no_consensus, map()}
  def request_health_consensus(node_id, timeout \\ 5_000) do
    request_id = generate_correlation_id()
    response_key = fqun("health", "consensus", "response", request_id)

    # Subscribe to responses
    responses = :ets.new(:health_responses, [:set, :public])

    {:ok, sub_ref} =
      subscribe(response_key, fn msg ->
        :ets.insert(responses, {msg.payload["voter"], msg.payload})
      end)

    # Publish consensus request
    request = %{
      request_id: request_id,
      node_id: node_id,
      requester: node_name(),
      response_key: response_key,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish(fqun("health", "consensus", "request", request_id), request)

    # Wait for responses
    Process.sleep(timeout)
    unsubscribe(sub_ref)

    # Aggregate responses
    response_list = :ets.tab2list(responses)
    all_responses = Enum.map(response_list, &elem(&1, 1))
    :ets.delete(responses)

    calculate_consensus(all_responses)
  end

  @doc """
  Respond to a health consensus request.

  Called when this node receives a consensus request.
  Performs local health check and publishes vote.
  """
  @spec vote_on_health_consensus(String.t(), String.t(), health_state()) ::
          :ok | {:error, term()}
  def vote_on_health_consensus(response_key, node_id, health_check_result) do
    vote = %{
      voter: node_name(),
      node_id: node_id,
      is_healthy: health_check_result == :healthy,
      health_state: Atom.to_string(health_check_result),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    publish(response_key, vote)
  end

  @doc """
  Broadcast emergency stop signal to all nodes.

  Triggers immediate coordinated shutdown of specified component.
  Must complete within 1 second (AOR-SAF-001).
  """
  @spec broadcast_emergency_stop(String.t(), String.t()) :: :ok | {:error, term()}
  def broadcast_emergency_stop(node_id, reason) do
    event = %{
      node_id: node_id,
      reason: reason,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      initiator: node_name(),
      sequence: System.monotonic_time(:nanosecond)
    }

    key = fqun("health", "emergency", "stop", node_id)
    # Use highest priority for emergency messages
    publish(key, event, priority: 1, congestion_control: :block)
  end

  @doc """
  Subscribe to emergency stop signals.

  Callback is invoked immediately on emergency stop broadcast.
  Handler must complete within 1 second.
  """
  @spec subscribe_to_emergency_stops((map() -> any())) ::
          {:ok, subscription()} | {:error, term()}
  def subscribe_to_emergency_stops(callback) when is_function(callback, 1) do
    subscribe("indrajaal/health/emergency/**", callback)
  end

  @doc """
  Publish health recovery notification.

  Notifies mesh that a node has recovered from degraded/failed state.
  """
  @spec publish_health_recovery(String.t(), health_state()) :: :ok | {:error, term()}
  def publish_health_recovery(node_id, new_state) do
    event = %{
      node_id: node_id,
      new_state: Atom.to_string(new_state),
      recovered_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      recovery_source: node_name()
    }

    key = fqun("health", "recovery", "completed", node_id)
    publish(key, event, priority: 3)
  end

  @doc """
  Get current health state of all known mesh nodes.

  Aggregates latest health events to build current mesh health view.
  """
  @spec get_mesh_health_state() :: map()
  def get_mesh_health_state do
    GenServer.call(__MODULE__, :get_mesh_health_state)
  end

  # Private health propagation helpers

  defp parse_health_event(payload) when is_map(payload) do
    %{
      node_id: Map.get(payload, "node_id"),
      previous_state: parse_health_state(Map.get(payload, "previous_state")),
      new_state: parse_health_state(Map.get(payload, "new_state")),
      timestamp: parse_timestamp(Map.get(payload, "timestamp")),
      reason: Map.get(payload, "reason")
    }
  end

  defp parse_health_event(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, map} ->
        parse_health_event(map)

      _ ->
        %{node_id: nil, previous_state: :absent, new_state: :absent, timestamp: nil, reason: nil}
    end
  end

  defp parse_health_state("healthy"), do: :healthy
  defp parse_health_state("degraded"), do: :degraded
  defp parse_health_state("failed"), do: :failed
  defp parse_health_state("starting"), do: :starting
  defp parse_health_state(_), do: :absent

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp calculate_consensus(responses) when length(responses) < 3 do
    # Not enough responses for consensus
    {:no_consensus, %{responses: length(responses), required: 3}}
  end

  defp calculate_consensus(responses) do
    healthy_count = responses |> Enum.count(& &1["is_healthy"])
    total = length(responses)
    threshold = div(total, 2) + 1

    if healthy_count >= threshold do
      {:consensus, :healthy, healthy_count}
    else
      unhealthy_count = total - healthy_count

      if unhealthy_count >= threshold do
        {:consensus, :unhealthy, unhealthy_count}
      else
        {:no_consensus, %{healthy: healthy_count, unhealthy: unhealthy_count, total: total}}
      end
    end
  end

  defp handle_peer_heartbeat(payload) do
    # Track peer health from heartbeat
    peer_node = Map.get(payload, "node") || Map.get(payload, :node)

    if peer_node do
      GenServer.cast(__MODULE__, {:update_peer, peer_node, payload})
    end
  end

  defp handle_sync_request(payload) do
    # Respond to sync request with current state
    request_id = Map.get(payload, "request_id")

    if request_id do
      spawn(fn ->
        status = mesh_status()
        publish_to_fsharp("coord/sync/response/#{request_id}", status)
      end)
    end
  end

  defp handle_barrier_signal(payload) do
    # Handle barrier synchronization
    barrier_id = Map.get(payload, "barrier_id")
    Logger.debug("[ZenohMesh] Barrier signal: #{barrier_id}")
    :ok
  end
end
