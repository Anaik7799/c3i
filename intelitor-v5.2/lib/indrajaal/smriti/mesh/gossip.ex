defmodule Indrajaal.SMRITI.Mesh.Gossip do
  @moduledoc """
  L6: SMRITI Gossip Protocol.

  ## WHAT
  Handles the propagation of "New Sense Data" and "Holon Rot" across the mesh
  using Zenoh pub/sub for real-time distributed communication.

  ## WHY
  - Enables distributed knowledge propagation (SC-FRAC-005)
  - Supports cluster-level AI coordination (SC-FRAC-001)
  - Provides real-time holon lifecycle events

  ## CONSTRAINTS
  - SC-GOSSIP-001: All broadcasts via Zenoh (not telemetry-only)
  - SC-GOSSIP-002: Subscription callbacks processed < 100ms
  - SC-GOSSIP-003: Message ordering preserved per topic
  - SC-ZENOH-001: Zenoh NIF must be active

  ## Topic Structure
  - `smriti/senses/new` - New sensory ingestion events
  - `smriti/senses/{holon_id}` - Specific holon senses
  - `smriti/holon/rot` - Apoptosis candidates (entropy > threshold)
  - `smriti/holon/rot/{holon_id}` - Specific holon rot events
  - `smriti/consensus/**` - Consensus coordination messages

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-16 | Claude | Wired to real Zenoh pub/sub (Task 42.2) |
  | 21.2.0 | 2026-01-10 | - | Initial stub implementation |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession

  # Topic definitions
  @topic_senses "smriti/senses/new"
  @topic_rot "smriti/holon/rot"
  @topic_consensus "smriti/consensus"
  @topic_heartbeat "smriti/mesh/heartbeat"

  # Subscription patterns
  @subscribe_patterns [
    "smriti/senses/**",
    "smriti/holon/**",
    "smriti/consensus/**"
  ]

  # Heartbeat interval (ms)
  @heartbeat_interval_ms 30_000

  # State structure
  defstruct [
    :node_id,
    :subscriptions,
    :callbacks,
    :stats,
    :last_heartbeat
  ]

  @type callback :: (map() -> :ok | {:error, term()})
  @type t :: %__MODULE__{
          node_id: String.t(),
          subscriptions: map(),
          callbacks: map(),
          stats: map(),
          last_heartbeat: DateTime.t() | nil
        }

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Start the SMRITI Gossip GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Broadcasts a new sensory ingestion event to the mesh.

  ## Parameters
  - `holon_id` - The holon ID that ingested new data
  - `metadata` - Map containing sense metadata (type, size, source, etc.)

  ## Returns
  - `:ok` - Broadcast successful
  - `{:error, reason}` - Broadcast failed

  ## Example
      Gossip.broadcast_sense("holon-123", %{
        type: :document,
        size: 1024,
        source: "api_ingest",
        summary: "New document processed"
      })
  """
  @spec broadcast_sense(String.t(), map()) :: :ok | {:error, term()}
  def broadcast_sense(holon_id, metadata) do
    GenServer.call(__MODULE__, {:broadcast_sense, holon_id, metadata})
  end

  @doc """
  Broadcasts a Holon Rot event (Apoptosis candidates).

  When a holon's entropy score exceeds the threshold, it becomes a
  candidate for apoptosis (controlled death/cleanup).

  ## Parameters
  - `holon_id` - The holon ID showing entropy
  - `entropy_score` - Float 0.0-1.0, higher = more entropy

  ## Returns
  - `:ok` - Broadcast successful
  - `{:error, reason}` - Broadcast failed
  """
  @spec broadcast_rot(String.t(), float()) :: :ok | {:error, term()}
  def broadcast_rot(holon_id, entropy_score) do
    GenServer.call(__MODULE__, {:broadcast_rot, holon_id, entropy_score})
  end

  @doc """
  Broadcasts a consensus request to the mesh.

  Used by the Tri-Cameral consensus engine to coordinate voting.

  ## Parameters
  - `request_id` - Unique identifier for this consensus request
  - `content` - The content being voted on
  - `options` - Additional options (timeout, required_votes, etc.)
  """
  @spec broadcast_consensus(String.t(), map(), keyword()) :: :ok | {:error, term()}
  def broadcast_consensus(request_id, content, opts \\ []) do
    GenServer.call(__MODULE__, {:broadcast_consensus, request_id, content, opts})
  end

  @doc """
  Registers a callback for gossip events.

  ## Parameters
  - `event_type` - One of :sense, :rot, :consensus, :all
  - `callback` - Function that receives the message map

  ## Returns
  - `{:ok, ref}` - Registration successful
  """
  @spec register_callback(atom(), callback()) :: {:ok, reference()}
  def register_callback(event_type, callback) when is_function(callback, 1) do
    GenServer.call(__MODULE__, {:register_callback, event_type, callback})
  end

  @doc """
  Unregisters a callback.
  """
  @spec unregister_callback(reference()) :: :ok
  def unregister_callback(ref) do
    GenServer.call(__MODULE__, {:unregister_callback, ref})
  end

  @doc """
  Gets gossip statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Gets mesh status including connected nodes.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_node_id())

    state = %__MODULE__{
      node_id: node_id,
      subscriptions: %{},
      callbacks: %{},
      stats: initial_stats(),
      last_heartbeat: nil
    }

    # Schedule subscription setup (after ZenohSession is ready)
    Process.send_after(self(), :setup_subscriptions, 1_000)

    # Schedule heartbeat
    Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)

    Logger.info("[SMRITI.Gossip] Started with node_id=#{node_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:broadcast_sense, holon_id, metadata}, _from, state) do
    message = %{
      type: :sense,
      id: holon_id,
      meta: metadata,
      node_id: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    result = do_publish(@topic_senses, message)

    # Also publish to specific holon topic
    _specific_result = do_publish("smriti/senses/#{holon_id}", message)

    case result do
      :ok ->
        Logger.debug("[SMRITI.Gossip] 🗣️ Broadcast sense: #{holon_id}")
        new_stats = update_stats(state.stats, :sense_broadcast)
        {:reply, :ok, %{state | stats: new_stats}}

      {:error, _reason} = error ->
        new_stats = update_stats(state.stats, :broadcast_error)
        {:reply, error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:broadcast_rot, holon_id, entropy_score}, _from, state) do
    message = %{
      type: :rot,
      id: holon_id,
      entropy: entropy_score,
      node_id: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    result = do_publish(@topic_rot, message)

    # Also publish to specific holon topic
    _specific_result = do_publish("smriti/holon/rot/#{holon_id}", message)

    case result do
      :ok ->
        Logger.info("[SMRITI.Gossip] 🥀 Broadcast rot: #{holon_id} (E=#{entropy_score})")
        new_stats = update_stats(state.stats, :rot_broadcast)
        {:reply, :ok, %{state | stats: new_stats}}

      {:error, _reason} = error ->
        new_stats = update_stats(state.stats, :broadcast_error)
        {:reply, error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:broadcast_consensus, request_id, content, opts}, _from, state) do
    message = %{
      type: :consensus_request,
      request_id: request_id,
      content: content,
      options: Map.new(opts),
      node_id: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    topic = "#{@topic_consensus}/#{request_id}"
    result = do_publish(topic, message)

    case result do
      :ok ->
        Logger.debug("[SMRITI.Gossip] ⚖️ Broadcast consensus: #{request_id}")
        new_stats = update_stats(state.stats, :consensus_broadcast)
        {:reply, :ok, %{state | stats: new_stats}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:register_callback, event_type, callback}, _from, state) do
    ref = make_ref()
    new_callbacks = Map.put(state.callbacks, ref, {event_type, callback})
    {:reply, {:ok, ref}, %{state | callbacks: new_callbacks}}
  end

  @impl true
  def handle_call({:unregister_callback, ref}, _from, state) do
    new_callbacks = Map.delete(state.callbacks, ref)
    {:reply, :ok, %{state | callbacks: new_callbacks}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      node_id: state.node_id,
      subscriptions: map_size(state.subscriptions),
      callbacks: map_size(state.callbacks),
      last_heartbeat: state.last_heartbeat,
      zenoh_connected: zenoh_connected?()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:setup_subscriptions, state) do
    new_subscriptions =
      Enum.reduce(@subscribe_patterns, state.subscriptions, fn pattern, acc ->
        case ZenohSession.subscribe(pattern, self()) do
          {:ok, ref} ->
            Logger.info("[SMRITI.Gossip] Subscribed to #{pattern}")
            Map.put(acc, ref, pattern)

          {:error, reason} ->
            Logger.warning(
              "[SMRITI.Gossip] Failed to subscribe to #{pattern}: #{inspect(reason)}"
            )

            acc
        end
      end)

    {:noreply, %{state | subscriptions: new_subscriptions}}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    # Publish heartbeat to mesh
    message = %{
      type: :heartbeat,
      node_id: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      stats: %{
        senses: state.stats.sense_broadcasts,
        rot: state.stats.rot_broadcasts,
        uptime_s: DateTime.diff(DateTime.utc_now(), state.stats.started_at)
      }
    }

    do_publish(@topic_heartbeat, message)

    # Schedule next heartbeat
    Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)

    {:noreply, %{state | last_heartbeat: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:zenoh_message, key, payload}, state) do
    # Process incoming Zenoh message
    case Jason.decode(payload) do
      {:ok, message} ->
        # Don't process our own messages
        if Map.get(message, "node_id") != state.node_id do
          dispatch_message(key, message, state.callbacks)
          new_stats = update_stats(state.stats, :message_received)
          {:noreply, %{state | stats: new_stats}}
        else
          {:noreply, state}
        end

      {:error, _reason} ->
        Logger.warning("[SMRITI.Gossip] Failed to decode message from #{key}")
        {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("[SMRITI.Gossip] Terminating: #{inspect(reason)}")

    # Unsubscribe from all topics
    Enum.each(state.subscriptions, fn {ref, _pattern} ->
      ZenohSession.unsubscribe(ref)
    end)

    :ok
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp do_publish(topic, message) do
    payload = Jason.encode!(message)

    # Emit telemetry regardless of Zenoh status
    :telemetry.execute(
      [:smriti, :mesh, :gossip],
      %{bytes: byte_size(payload)},
      %{topic: topic, type: message.type}
    )

    # Publish via Zenoh
    ZenohSession.publish(topic, payload)
  end

  defp dispatch_message(key, message, callbacks) do
    event_type = detect_event_type(key, message)

    Enum.each(callbacks, fn {_ref, {cb_type, callback}} ->
      if cb_type == :all or cb_type == event_type do
        try do
          callback.(%{key: key, message: message, event_type: event_type})
        rescue
          e ->
            Logger.error("[SMRITI.Gossip] Callback error: #{inspect(e)}")
        end
      end
    end)
  end

  defp detect_event_type(key, message) do
    cond do
      String.contains?(key, "senses") -> :sense
      String.contains?(key, "rot") -> :rot
      String.contains?(key, "consensus") -> :consensus
      Map.get(message, "type") == "heartbeat" -> :heartbeat
      true -> :unknown
    end
  end

  defp generate_node_id do
    "gossip-#{:erlang.phash2({node(), self()}, 0xFFFFFF) |> Integer.to_string(16)}"
  end

  defp zenoh_connected? do
    try do
      ZenohSession.connected?()
    rescue
      _ -> false
    catch
      :exit, _ -> false
    end
  end

  defp initial_stats do
    %{
      started_at: DateTime.utc_now(),
      sense_broadcasts: 0,
      rot_broadcasts: 0,
      consensus_broadcasts: 0,
      messages_received: 0,
      broadcast_errors: 0
    }
  end

  defp update_stats(stats, type) do
    case type do
      :sense_broadcast -> %{stats | sense_broadcasts: stats.sense_broadcasts + 1}
      :rot_broadcast -> %{stats | rot_broadcasts: stats.rot_broadcasts + 1}
      :consensus_broadcast -> %{stats | consensus_broadcasts: stats.consensus_broadcasts + 1}
      :message_received -> %{stats | messages_received: stats.messages_received + 1}
      :broadcast_error -> %{stats | broadcast_errors: stats.broadcast_errors + 1}
    end
  end
end
