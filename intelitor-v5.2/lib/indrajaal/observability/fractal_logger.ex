defmodule Indrajaal.Observability.FractalLogger do
  @moduledoc """
  Fractal Logger - 5-Level Hierarchical Logging System

  WHAT: Implements the Fractal Logging architecture with 5 levels:
        Spine → Thorax → Segment → Fiber → Gossamer

  WHY: Provides structured logging that maps to the PRAJNA Cockpit's
       fractal display system, enabling intelligent log visualization
       at any detail level (L0-L4).

  DESIGN PRINCIPLES:
    1. Self-similarity - same structure at all levels
    2. Retention policies - decreasing duration by level
    3. Display mapping - direct correlation to L0-L4 views
    4. OTEL integration - spans and traces at each level

  STAMP Compliance:
    - SC-LOG-001: Fractal hierarchy enforcement
    - SC-LOG-002: Retention policy compliance
    - SC-LOG-003: Audit trail immutability (Spine level)
    - SC-LOG-004: OTEL trace correlation

  Level Mapping:
    - Spine (L0)    : Critical    - Forever retention
    - Thorax (L1)   : Warning     - 30 days retention
    - Segment (L2)  : Info        - 7 days retention
    - Fiber (L3)    : Debug       - 24 hours retention
    - Gossamer (L4) : Trace       - 1 hour retention

  Usage:
    FractalLogger.spine("Guardian", "System failure detected", %{node: "app-01"})
    FractalLogger.thorax("Alarms", "High CPU alert", %{cpu: 92.5})
    FractalLogger.segment("Commands", "Restart initiated", %{target: "db"})
    FractalLogger.fiber("OODA", "Cycle complete", %{duration_ms: 763})
    FractalLogger.gossamer("Telemetry", "Metric received", %{value: 42.0})
  """

  use GenServer
  require Logger

  # Log level atoms for fractal hierarchy
  @levels [:spine, :thorax, :segment, :fiber, :gossamer]

  # Retention periods in hours
  @retention %{
    # Forever
    spine: :infinity,
    # 30 days
    thorax: 720,
    # 7 days
    segment: 168,
    # 24 hours
    fiber: 24,
    # 1 hour
    gossamer: 1
  }

  # Max entries per level (memory safety)
  @max_entries %{
    spine: 10_000,
    thorax: 50_000,
    segment: 100_000,
    fiber: 50_000,
    gossamer: 10_000
  }

  # ANSI colors for terminal display
  @colors %{
    # Red
    spine: "\e[31m",
    # Yellow/Amber
    thorax: "\e[33m",
    # Cyan
    segment: "\e[36m",
    # Gray
    fiber: "\e[90m",
    # Dim gray
    gossamer: "\e[90m",
    reset: "\e[0m"
  }

  # Level indicators
  @indicators %{
    spine: "⬤",
    thorax: "◉",
    segment: "◎",
    fiber: "○",
    gossamer: "·"
  }

  # ═══════════════════════════════════════════════════════════════════════════
  # CLIENT API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Start the fractal logger"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Log at Spine level (Critical - Forever retention)"
  def spine(source, message, context \\ %{}) do
    log(:spine, source, message, context)
  end

  @doc "Log at Thorax level (Warning - 30 days retention)"
  def thorax(source, message, context \\ %{}) do
    log(:thorax, source, message, context)
  end

  @doc "Log at Segment level (Info - 7 days retention)"
  def segment(source, message, context \\ %{}) do
    log(:segment, source, message, context)
  end

  @doc "Log at Fiber level (Debug - 24 hours retention)"
  def fiber(source, message, context \\ %{}) do
    log(:fiber, source, message, context)
  end

  @doc "Log at Gossamer level (Trace - 1 hour retention)"
  def gossamer(source, message, context \\ %{}) do
    log(:gossamer, source, message, context)
  end

  @doc "Log at specified level"
  def log(level, source, message, context \\ %{}) when level in @levels do
    GenServer.cast(__MODULE__, {:log, level, source, message, context})
  end

  @doc "Get entries at a specific level"
  def get_entries(level, limit \\ 100) when level in @levels do
    GenServer.call(__MODULE__, {:get_entries, level, limit})
  end

  @doc "Get entries filtered by source"
  def get_entries_by_source(source, limit \\ 100) do
    GenServer.call(__MODULE__, {:get_entries_by_source, source, limit})
  end

  @doc "Get entry counts by level"
  def get_counts do
    GenServer.call(__MODULE__, :get_counts)
  end

  @doc "Get statistics"
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc "Prune old entries based on retention"
  def prune do
    GenServer.cast(__MODULE__, :prune)
  end

  @doc "Clear all entries at a specific level"
  def clear(level) when level in @levels do
    GenServer.cast(__MODULE__, {:clear, level})
  end

  @doc "Export entries to JSON"
  def export(level, path) when level in @levels do
    GenServer.call(__MODULE__, {:export, level, path})
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GENSERVER CALLBACKS
  # ═══════════════════════════════════════════════════════════════════════════

  @impl true
  def init(_opts) do
    state = %{
      entries: %{
        spine: [],
        thorax: [],
        segment: [],
        fiber: [],
        gossamer: []
      },
      counts: %{
        spine: 0,
        thorax: 0,
        segment: 0,
        fiber: 0,
        gossamer: 0
      },
      total_logged: 0,
      started_at: DateTime.utc_now()
    }

    # Schedule periodic pruning
    Process.send_after(self(), :auto_prune, 60_000)

    Logger.info("[FractalLogger] Started with 5-level hierarchy")

    {:ok, state}
  end

  @impl true
  def handle_cast({:log, level, source, message, context}, state) do
    entry = create_entry(level, source, message, context)

    # Add to appropriate level
    entries =
      Map.update!(state.entries, level, fn list ->
        [entry | list] |> Enum.take(@max_entries[level])
      end)

    counts = Map.update!(state.counts, level, &(&1 + 1))

    # Also emit to standard Logger at appropriate level
    emit_to_logger(level, source, message, context)

    # Emit telemetry event
    emit_telemetry(level, source, message, context)

    {:noreply, %{state | entries: entries, counts: counts, total_logged: state.total_logged + 1}}
  end

  @impl true
  def handle_cast(:prune, state) do
    now = DateTime.utc_now()
    entries = prune_entries_by_retention(@levels, state.entries, now)
    {:noreply, %{state | entries: entries}}
  end

  @impl true
  def handle_cast({:clear, level}, state) do
    entries = Map.put(state.entries, level, [])
    {:noreply, %{state | entries: entries}}
  end

  defp prune_entries_by_retention(levels, entries, now) do
    Enum.reduce(levels, entries, fn level, acc ->
      prune_level_entries(acc, level, now)
    end)
  end

  defp prune_level_entries(entries, level, now) do
    case @retention[level] do
      :infinity ->
        entries

      hours ->
        threshold = DateTime.add(now, -hours * 3600, :second)
        filter_entries_by_threshold(entries, level, threshold)
    end
  end

  defp filter_entries_by_threshold(entries, level, threshold) do
    Map.update!(entries, level, fn list ->
      Enum.filter(list, fn entry ->
        DateTime.compare(entry.timestamp, threshold) == :gt
      end)
    end)
  end

  @impl true
  def handle_call({:get_entries, level, limit}, _from, state) do
    entries =
      state.entries
      |> Map.get(level, [])
      |> Enum.take(limit)

    {:reply, entries, state}
  end

  @impl true
  def handle_call({:get_entries_by_source, source, limit}, _from, state) do
    entries =
      @levels
      |> Enum.flat_map(fn level -> Map.get(state.entries, level, []) end)
      |> Enum.filter(fn entry -> entry.source == source end)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> Enum.take(limit)

    {:reply, entries, state}
  end

  @impl true
  def handle_call(:get_counts, _from, state) do
    {:reply, state.counts, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    entry_counts =
      Map.new(state.entries, fn {level, entries} ->
        {level, length(entries)}
      end)

    stats = %{
      counts: state.counts,
      total_logged: state.total_logged,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at, :second),
      entry_counts: entry_counts
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:export, level, path}, _from, state) do
    entries = Map.get(state.entries, level, [])

    json =
      Jason.encode!(
        %{
          level: level,
          exported_at: DateTime.utc_now(),
          count: length(entries),
          entries: entries
        },
        pretty: true
      )

    result = File.write(path, json)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:auto_prune, state) do
    send(self(), {:prune})
    Process.send_after(self(), :auto_prune, 60_000)
    {:noreply, state}
  end

  @impl true
  def handle_info({:prune}, state) do
    {:noreply, state} = handle_cast(:prune, state)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[FractalLogger] Unhandled: #{inspect(msg)}")
    {:noreply, state}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  defp create_entry(level, source, message, context) do
    %{
      id: generate_id(),
      timestamp: DateTime.utc_now(),
      level: level,
      source: source,
      message: message,
      context: context,
      correlation_id: Map.get(context, :correlation_id),
      trace_id: get_trace_id(),
      span_id: get_span_id()
    }
  end

  defp generate_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp get_trace_id do
    case Process.get(:otel_trace_id) do
      nil -> nil
      id -> id
    end
  end

  defp get_span_id do
    case Process.get(:otel_span_id) do
      nil -> nil
      id -> id
    end
  end

  defp emit_to_logger(level, source, message, context) do
    indicator = @indicators[level]
    color = @colors[level]
    reset = @colors.reset

    formatted = "#{color}#{indicator} [#{source}] #{message}#{reset}"

    context_str =
      if map_size(context) > 0 do
        " " <> inspect(context)
      else
        ""
      end

    case level do
      :spine -> Logger.error(formatted <> context_str)
      :thorax -> Logger.warning(formatted <> context_str)
      :segment -> Logger.info(formatted <> context_str)
      :fiber -> Logger.debug(formatted <> context_str)
      :gossamer -> Logger.debug(formatted <> context_str)
    end
  end

  defp emit_telemetry(level, source, message, context) do
    :telemetry.execute(
      [:indrajaal, :fractal_log, level],
      %{count: 1},
      %{
        source: source,
        message: message,
        context: context
      }
    )
  rescue
    # Telemetry may not be available
    _ -> :ok
  end
end
