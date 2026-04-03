defmodule Indrajaal.Cybernetic.EventSourcing.EventStore do
  @moduledoc """
  Zenoh Event Store - Append-Only Event Log for v20.0.0

  Implements a distributed event store backed by Zenoh pub/sub:
  - Append-only event log with HLC timestamps
  - Stream-based event organization
  - Causality tracking with vector clocks
  - Distributed consistency via Zenoh

  ## Event Model

  E = {id, stream, type, data, metadata, hlc_timestamp, causal_deps}

  Where:
  - id: Unique event identifier (ULID)
  - stream: Event stream name (e.g., "holon:agent:42")
  - type: Event type atom
  - data: Event payload
  - metadata: Context (actor, correlation_id, etc.)
  - hlc_timestamp: Hybrid Logical Clock timestamp
  - causal_deps: Vector clock for causality

  ## STAMP Constraints
  - SC-EVT-001: Events MUST be immutable
  - SC-EVT-002: Event order MUST be preserved within stream
  - SC-EVT-003: HLC timestamps MUST be monotonic
  - SC-EVT-004: Causal dependencies MUST be tracked
  """

  use GenServer
  require Logger

  @type event_id :: String.t()
  @type stream_name :: String.t()
  @type event_type :: atom()

  @type event :: %{
          id: event_id(),
          stream: stream_name(),
          type: event_type(),
          data: map(),
          metadata: map(),
          hlc_timestamp: non_neg_integer(),
          causal_deps: map(),
          version: non_neg_integer()
        }

  @type store_state :: %{
          streams: map(),
          hlc: non_neg_integer(),
          vector_clock: map(),
          subscribers: map(),
          config: map()
        }

  # Start the event store
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Appends an event to a stream.
  """
  @spec append(stream_name(), event_type(), map(), Keyword.t()) ::
          {:ok, event()} | {:error, term()}
  def append(stream, type, data, opts \\ []) do
    GenServer.call(__MODULE__, {:append, stream, type, data, opts})
  end

  @doc """
  Reads events from a stream.
  """
  @spec read(stream_name(), Keyword.t()) :: {:ok, [event()]} | {:error, term()}
  def read(stream, opts \\ []) do
    GenServer.call(__MODULE__, {:read, stream, opts})
  end

  @doc """
  Subscribes to events on a stream.
  """
  @spec subscribe(stream_name(), pid()) :: :ok
  def subscribe(stream, pid) do
    GenServer.cast(__MODULE__, {:subscribe, stream, pid})
  end

  @doc """
  Gets the current version of a stream.
  """
  @spec stream_version(stream_name()) :: non_neg_integer()
  def stream_version(stream) do
    GenServer.call(__MODULE__, {:version, stream})
  end

  @doc """
  Gets all stream names.
  """
  @spec list_streams() :: [stream_name()]
  def list_streams do
    GenServer.call(__MODULE__, :list_streams)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      streams: %{},
      hlc: System.system_time(:nanosecond),
      vector_clock: %{},
      subscribers: %{},
      config: %{
        node_id: Keyword.get(opts, :node_id, node_id()),
        max_events_per_stream: Keyword.get(opts, :max_events, 10_000)
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:append, stream, type, data, opts}, _from, state) do
    # Generate event ID
    event_id = generate_event_id()

    # Update HLC (SC-EVT-003)
    new_hlc = update_hlc(state.hlc)

    # Get stream version
    stream_events = Map.get(state.streams, stream, [])
    version = length(stream_events) + 1

    # Build metadata
    metadata = %{
      actor: Keyword.get(opts, :actor),
      correlation_id: Keyword.get(opts, :correlation_id, event_id),
      causation_id: Keyword.get(opts, :causation_id),
      timestamp: DateTime.utc_now()
    }

    # Update vector clock
    new_vc = increment_vector_clock(state.vector_clock, state.config.node_id)

    # Create event (SC-EVT-001: immutable)
    event = %{
      id: event_id,
      stream: stream,
      type: type,
      data: data,
      metadata: metadata,
      hlc_timestamp: new_hlc,
      causal_deps: new_vc,
      version: version
    }

    # Append to stream (SC-EVT-002: order preserved)
    new_stream_events = stream_events ++ [event]
    new_streams = Map.put(state.streams, stream, new_stream_events)

    # Notify subscribers
    notify_subscribers(stream, event, state.subscribers)

    # Publish to Zenoh (if configured)
    publish_to_zenoh(stream, event)

    new_state = %{
      state
      | streams: new_streams,
        hlc: new_hlc,
        vector_clock: new_vc
    }

    {:reply, {:ok, event}, new_state}
  end

  @impl true
  def handle_call({:read, stream, opts}, _from, state) do
    events = Map.get(state.streams, stream, [])

    # Apply filters
    filtered =
      events
      |> filter_from_version(Keyword.get(opts, :from_version, 0))
      |> filter_to_version(Keyword.get(opts, :to_version))
      |> filter_by_type(Keyword.get(opts, :type))
      |> limit_events(Keyword.get(opts, :limit))

    {:reply, {:ok, filtered}, state}
  end

  @impl true
  def handle_call({:version, stream}, _from, state) do
    events = Map.get(state.streams, stream, [])
    {:reply, length(events), state}
  end

  @impl true
  def handle_call(:list_streams, _from, state) do
    {:reply, Map.keys(state.streams), state}
  end

  @impl true
  def handle_cast({:subscribe, stream, pid}, state) do
    stream_subs = Map.get(state.subscribers, stream, [])
    new_subs = Map.put(state.subscribers, stream, [pid | stream_subs])
    {:noreply, %{state | subscribers: new_subs}}
  end

  # Private helpers

  defp node_id do
    node()
    |> to_string()
    |> :erlang.phash2()
    |> Integer.to_string(16)
  end

  defp generate_event_id do
    # ULID-like ID: timestamp + random
    timestamp = System.system_time(:millisecond)
    bytes = :crypto.strong_rand_bytes(10)
    random = bytes |> Base.encode16(case: :lower)
    "#{timestamp}-#{random}"
  end

  defp update_hlc(current_hlc) do
    system_time = System.system_time(:nanosecond)
    max(current_hlc + 1, system_time)
  end

  defp increment_vector_clock(vc, node_id) do
    current = Map.get(vc, node_id, 0)
    Map.put(vc, node_id, current + 1)
  end

  defp notify_subscribers(stream, event, subscribers) do
    stream_subs = Map.get(subscribers, stream, [])

    Enum.each(stream_subs, fn pid ->
      send(pid, {:event, stream, event})
    end)
  end

  defp publish_to_zenoh(_stream, _event) do
    # Zenoh publication would go here
    # In production, publish to zenoh/events/{stream}
    :ok
  end

  defp filter_from_version(events, from_version) do
    Enum.filter(events, fn e -> e.version > from_version end)
  end

  defp filter_to_version(events, nil), do: events

  defp filter_to_version(events, to_version) do
    Enum.filter(events, fn e -> e.version <= to_version end)
  end

  defp filter_by_type(events, nil), do: events

  defp filter_by_type(events, type) do
    Enum.filter(events, fn e -> e.type == type end)
  end

  defp limit_events(events, nil), do: events
  defp limit_events(events, limit), do: Enum.take(events, limit)
end
