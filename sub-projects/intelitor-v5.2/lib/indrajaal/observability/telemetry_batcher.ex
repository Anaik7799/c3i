defmodule Indrajaal.Observability.TelemetryBatcher do
  @moduledoc """
  Batches high-frequency telemetry events for Zenoh publication.

  ## WHAT
  Aggregates telemetry events over a configurable window (default 1s)
  and publishes a single batch message to Zenoh, preventing mailbox
  overflow on HOT paths (>100 events/sec).

  ## WHY
  - SmartMetrics generates ~200 ETS writes/sec — publishing each one
    individually would overwhelm ZenohSession (RC-ZUIP-001, FM-ZUIP-001)
  - Batching reduces Zenoh publish rate from 200/sec to 1/sec
  - Preserves all data while preventing backpressure

  ## CONSTRAINTS
  - SC-ZTEST-008: Log fallback before Zenoh publish
  - SC-ZENOH-004: Publish latency < 100ms
  - FM-ZUIP-001: Prevents mailbox overflow (RPN 140)

  ## Usage

      # Register a batcher for a topic
      TelemetryBatcher.start_link(
        topic: "indrajaal/metrics/smart",
        flush_interval_ms: 1000,
        max_batch_size: 500
      )

      # Add events (non-blocking)
      TelemetryBatcher.add("indrajaal/metrics/smart", %{cpu: 45.2, memory: 72.1})
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession

  @default_flush_interval_ms 1_000
  @default_max_batch_size 500

  defstruct [
    :topic,
    :flush_interval_ms,
    :max_batch_size,
    :timer_ref,
    buffer: [],
    buffer_size: 0,
    stats: %{batches_sent: 0, events_batched: 0, events_dropped: 0}
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  def start_link(opts) do
    topic = Keyword.fetch!(opts, :topic)
    name = Keyword.get(opts, :name, via_name(topic))
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Add an event to the batch buffer (non-blocking).
  """
  @spec add(String.t(), map()) :: :ok
  def add(topic, event) do
    case GenServer.whereis(via_name(topic)) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:add, event})
    end
  end

  @doc """
  Force flush the current buffer immediately.
  """
  @spec flush(String.t()) :: :ok
  def flush(topic) do
    case GenServer.whereis(via_name(topic)) do
      nil -> :ok
      pid -> GenServer.cast(pid, :flush)
    end
  end

  @doc """
  Get batcher statistics.
  """
  @spec stats(String.t()) :: map()
  def stats(topic) do
    case GenServer.whereis(via_name(topic)) do
      nil -> %{}
      pid -> GenServer.call(pid, :stats)
    end
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)
    flush_interval = Keyword.get(opts, :flush_interval_ms, @default_flush_interval_ms)
    max_batch = Keyword.get(opts, :max_batch_size, @default_max_batch_size)

    state = %__MODULE__{
      topic: topic,
      flush_interval_ms: flush_interval,
      max_batch_size: max_batch
    }

    # Schedule first flush
    timer_ref = Process.send_after(self(), :flush_timer, flush_interval)

    Logger.info("[TelemetryBatcher] Started for topic=#{topic} interval=#{flush_interval}ms")
    {:ok, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_cast({:add, event}, state) do
    if state.buffer_size >= state.max_batch_size do
      # Buffer full — flush immediately, then add
      new_state = do_flush(state)

      {:noreply,
       %{
         new_state
         | buffer: [event],
           buffer_size: 1
       }}
    else
      {:noreply,
       %{
         state
         | buffer: [event | state.buffer],
           buffer_size: state.buffer_size + 1
       }}
    end
  end

  @impl true
  def handle_cast(:flush, state) do
    {:noreply, do_flush(state)}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    new_state = do_flush(state)

    # Reschedule
    timer_ref = Process.send_after(self(), :flush_timer, state.flush_interval_ms)
    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl true
  def terminate(_reason, state) do
    # Flush remaining on shutdown
    do_flush(state)
    :ok
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  defp do_flush(%{buffer: [], buffer_size: 0} = state), do: state

  defp do_flush(state) do
    events = Enum.reverse(state.buffer)
    count = state.buffer_size

    # Build batch payload
    payload =
      Jason.encode!(%{
        topic: state.topic,
        batch_size: count,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        events: events
      })

    # SC-ZTEST-008: Dual-write — log fallback first
    Logger.debug("[ZTEST-CHECKPOINT] topic=#{state.topic} type=batch batch_size=#{count}")

    # Async publish to Zenoh (fire-and-forget)
    ZenohSession.publish_async(state.topic, payload, :normal)

    # Update stats
    new_stats = %{
      state.stats
      | batches_sent: state.stats.batches_sent + 1,
        events_batched: state.stats.events_batched + count
    }

    %{state | buffer: [], buffer_size: 0, stats: new_stats}
  end

  defp via_name(topic) do
    # Use a deterministic atom name for each topic batcher
    # Safe because topics are a small, fixed set defined at compile-time
    String.to_atom("telemetry_batcher_" <> topic)
  end
end
