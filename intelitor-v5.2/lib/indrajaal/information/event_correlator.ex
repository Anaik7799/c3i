defmodule Indrajaal.Information.EventCorrelator do
  @moduledoc """
  Event Correlator — L2 Information Layer

  ## Design Intent
  GenServer that maintains a sliding time-window buffer of events and
  detects predefined sequences (patterns) across them. When a correlation
  pattern fires, an alert is broadcast via PubSub and emitted as a
  :telemetry event.

  The event buffer is backed by ETS so that read-heavy consumers (dashboards,
  analytic queries) can inspect raw events without going through the GenServer
  mailbox.

  ### Sliding Window Mechanics
  Events older than `window_seconds` are evicted on every periodic sweep
  (half the window size, minimum 5 s). ETS rows are keyed by `{ref, ts_ms}`
  tuples so multiple events with identical timestamps do not collide.

  ### Pattern Matching
  A pattern is a list of event type atoms. The correlator checks whether the
  current window contains all types in the pattern, in any order (set
  semantics). Ordered / temporal pattern matching is intentionally deferred
  to a future enhancement to keep the initial implementation simple.

  ## STAMP Constraints
  - SC-SEM-001: Semantic analysis of event streams
  - SC-ALARM-003: Alarm correlation — correlated events must propagate alerts

  ## Change History
  | Version | Date       | Author            | Change                    |
  |---------|------------|-------------------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @ets_table :event_correlator_buffer
  @pubsub_topic "events:correlated"
  @default_window_seconds 30
  @sweep_divider 2
  @min_sweep_ms 5_000
  @telemetry_event [:indrajaal, :information, :event_correlated]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type event_type :: atom()

  @type event :: %{
          type: event_type(),
          payload: map(),
          source: String.t(),
          ts_ms: non_neg_integer()
        }

  @type pattern :: %{
          id: atom(),
          required_types: [event_type()],
          description: String.t()
        }

  @type correlation_alert :: %{
          pattern_id: atom(),
          description: String.t(),
          matching_events: [event()],
          fired_at_ms: non_neg_integer()
        }

  @type state :: %{
          window_ms: non_neg_integer(),
          sweep_interval_ms: non_neg_integer(),
          patterns: [pattern()],
          fired: MapSet.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the EventCorrelator.

  Options:
  - `:window_seconds` — sliding window size in seconds (default: #{@default_window_seconds})
  - `:patterns` — initial list of `t:pattern/0` maps
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Ingests a new event into the correlator window."
  @spec ingest(event_type(), map(), String.t()) :: :ok
  def ingest(type, payload \\ %{}, source \\ "unknown")
      when is_atom(type) and is_map(payload) and is_binary(source) do
    GenServer.cast(@name, {:ingest, type, payload, source})
  end

  @doc "Registers a new correlation pattern at runtime."
  @spec register_pattern(pattern()) :: :ok
  def register_pattern(%{id: _, required_types: _, description: _} = pattern) do
    GenServer.cast(@name, {:register_pattern, pattern})
  end

  @doc "Returns all events currently in the sliding window (fast ETS read)."
  @spec current_window() :: [event()]
  def current_window do
    case :ets.whereis(@ets_table) do
      :undefined ->
        []

      _ ->
        now_ms = System.monotonic_time(:millisecond)

        :ets.tab2list(@ets_table)
        |> Enum.map(fn {_key, event} -> event end)
        |> Enum.sort_by(& &1.ts_ms)
        |> Enum.filter(fn e -> e.ts_ms >= now_ms end)
    end
  end

  @doc "Returns the list of registered patterns."
  @spec patterns() :: [pattern()]
  def patterns do
    GenServer.call(@name, :patterns)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:named_table, :public, read_concurrency: true])

    window_seconds = Keyword.get(opts, :window_seconds, @default_window_seconds)
    window_ms = window_seconds * 1_000

    sweep_interval_ms =
      max(@min_sweep_ms, div(window_ms, @sweep_divider))

    patterns = Keyword.get(opts, :patterns, [])

    schedule_sweep(sweep_interval_ms)

    Logger.info(
      "[EventCorrelator] L2 started — window=#{window_seconds}s, patterns=#{length(patterns)}"
    )

    state = %{
      window_ms: window_ms,
      sweep_interval_ms: sweep_interval_ms,
      patterns: patterns,
      fired: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:ingest, type, payload, source}, state) do
    ts_ms = System.monotonic_time(:millisecond)
    ref = make_ref()

    event = %{type: type, payload: payload, source: source, ts_ms: ts_ms}
    :ets.insert(@ets_table, {{ref, ts_ms}, event})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:register_pattern, pattern}, state) do
    {:noreply, %{state | patterns: [pattern | state.patterns]}}
  end

  @impl true
  def handle_call(:patterns, _from, state) do
    {:reply, state.patterns, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff_ms = System.monotonic_time(:millisecond) - state.window_ms

    # Evict expired entries
    expired_keys =
      :ets.tab2list(@ets_table)
      |> Enum.filter(fn {{_ref, ts_ms}, _event} -> ts_ms < cutoff_ms end)
      |> Enum.map(fn {key, _} -> key end)

    Enum.each(expired_keys, &:ets.delete(@ets_table, &1))

    # Collect events still in window
    window_events =
      :ets.tab2list(@ets_table)
      |> Enum.map(fn {_key, event} -> event end)

    # Evaluate patterns
    new_fired = evaluate_patterns(state.patterns, window_events, state.fired)

    schedule_sweep(state.sweep_interval_ms)

    {:noreply, %{state | fired: new_fired}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec evaluate_patterns([pattern()], [event()], MapSet.t()) :: MapSet.t()
  defp evaluate_patterns(patterns, window_events, fired) do
    event_types = MapSet.new(window_events, & &1.type)

    Enum.reduce(patterns, fired, fn pattern, acc ->
      required = MapSet.new(pattern.required_types)
      already_fired = MapSet.member?(acc, pattern.id)

      cond do
        already_fired ->
          # Reset if the required types are no longer all present
          if MapSet.subset?(required, event_types) do
            acc
          else
            MapSet.delete(acc, pattern.id)
          end

        MapSet.subset?(required, event_types) ->
          matching =
            Enum.filter(window_events, fn e ->
              e.type in pattern.required_types
            end)

          fire_correlation(pattern, matching)
          MapSet.put(acc, pattern.id)

        true ->
          acc
      end
    end)
  end

  @spec fire_correlation(pattern(), [event()]) :: :ok
  defp fire_correlation(pattern, matching_events) do
    now_ms = System.monotonic_time(:millisecond)

    alert = %{
      pattern_id: pattern.id,
      description: pattern.description,
      matching_events: matching_events,
      fired_at_ms: now_ms
    }

    Logger.warning(
      "[EventCorrelator] Pattern #{inspect(pattern.id)} fired — #{pattern.description} (#{length(matching_events)} events)"
    )

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:event_correlated, alert}
    )

    :telemetry.execute(
      @telemetry_event,
      %{event_count: length(matching_events)},
      %{pattern_id: pattern.id, description: pattern.description}
    )

    :ok
  end

  defp schedule_sweep(interval_ms) do
    Process.send_after(self(), :sweep, interval_ms)
  end
end
