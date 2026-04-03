defmodule Indrajaal.Observability.ZenohFractalPublisher do
  @moduledoc """
  Fractal Log → Zenoh Publisher bridge.

  ## WHAT
  Routes fractal log entries to Zenoh for real-time streaming
  to CEPAF F# cockpit and other subscribers.

  ## WHY
  - Enables real-time fractal log viewing in F# dashboard
  - Sub-millisecond latency for operational visibility
  - Decouples log generation from consumption

  ## CONSTRAINTS
  - SC-ZENOH-PUB-001: Non-blocking publication
  - SC-ZENOH-PUB-002: Latency <1ms target
  - SC-ZENOH-PUB-003: Batch support for efficiency
  - SC-LOG-001: Never block the caller

  ## Key Expression Schema
  ```
  indrajaal/fractal/{level}/{domain}/{event_type}
  Examples:
    indrajaal/fractal/l3/alarms/state_change
    indrajaal/fractal/l4/system/health_check
    indrajaal/fractal/l5/cortex/ai_decision
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession
  alias Indrajaal.Observability.Fractal.BatchEncoder

  # Configuration
  @default_batch_size 100
  @default_flush_interval_ms 100
  @key_prefix "indrajaal/fractal"

  defstruct [
    :enabled,
    :batch_size,
    :flush_interval_ms,
    :key_prefix,
    :levels,
    :buffer,
    :stats,
    :coordinator
  ]

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Start the ZenohFractalPublisher GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Publish a single fractal log entry to Zenoh.
  """
  @spec publish_entry(term(), map()) :: :ok
  def publish_entry(pid \\ __MODULE__, entry) when is_map(entry) do
    GenServer.cast(pid, {:publish, entry})
  end

  @doc """
  Publish multiple entries at once.
  """
  @spec publish_entries(term(), [map()]) :: :ok
  def publish_entries(pid \\ __MODULE__, entries) when is_list(entries) do
    GenServer.cast(pid, {:publish_batch, entries})
  end

  @doc """
  Force flush of buffered entries.
  """
  @spec flush(term()) :: :ok
  def flush(pid \\ __MODULE__), do: GenServer.call(pid, :flush)

  @doc """
  Get publisher statistics.
  """
  @spec get_stats(term()) :: map()
  def get_stats(pid \\ __MODULE__), do: GenServer.call(pid, :get_stats)

  @doc """
  Check if publisher is enabled.
  """
  @spec enabled?(term()) :: boolean()
  def enabled?(pid \\ __MODULE__), do: GenServer.call(pid, :enabled?)

  @doc """
  Enable or disable the publisher.
  """
  @spec set_enabled(term(), boolean()) :: :ok
  def set_enabled(pid \\ __MODULE__, enabled) do
    GenServer.call(pid, {:set_enabled, enabled})
  end

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    config = load_config(opts)
    coordinator = Keyword.get(opts, :coordinator)

    state = %__MODULE__{
      enabled: config.enabled,
      batch_size: config.batch_size,
      flush_interval_ms: config.flush_interval_ms,
      key_prefix: config.key_prefix,
      levels: config.levels,
      buffer: [],
      stats: initial_stats(),
      coordinator: coordinator
    }

    # Schedule periodic flush
    if state.enabled do
      schedule_flush(state.flush_interval_ms)
    end

    Logger.info("[ZenohFractalPublisher] Started - SC-ZENOH-PUB-001")
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, entry}, state) do
    if state.enabled and level_enabled?(entry.level, state.levels) do
      new_buffer = [entry | state.buffer]

      if length(new_buffer) >= state.batch_size do
        # Buffer full, flush immediately
        {flushed, remaining} = Enum.split(new_buffer, state.batch_size)
        do_flush(Enum.reverse(flushed), state)
        {:noreply, %{state | buffer: remaining}}
      else
        {:noreply, %{state | buffer: new_buffer}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:publish_batch, entries}, state) do
    if state.enabled do
      enabled_entries =
        Enum.filter(entries, fn e ->
          level_enabled?(e.level, state.levels)
        end)

      new_buffer = enabled_entries ++ state.buffer

      if length(new_buffer) >= state.batch_size do
        {flushed, remaining} = Enum.split(new_buffer, state.batch_size)
        do_flush(Enum.reverse(flushed), state)
        {:noreply, %{state | buffer: remaining}}
      else
        {:noreply, %{state | buffer: new_buffer}}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:flush, _from, state) do
    if length(state.buffer) > 0 do
      do_flush(Enum.reverse(state.buffer), state)
    end

    {:reply, :ok, %{state | buffer: []}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        buffer_size: length(state.buffer),
        enabled: state.enabled
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call({:set_enabled, enabled}, _from, state) do
    if enabled and not state.enabled do
      schedule_flush(state.flush_interval_ms)
    end

    {:reply, :ok, %{state | enabled: enabled}}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    if state.enabled do
      if length(state.buffer) > 0 do
        do_flush(Enum.reverse(state.buffer), state)
      end

      schedule_flush(state.flush_interval_ms)
      {:noreply, %{state | buffer: []}}
    else
      {:noreply, state}
    end
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp load_config(opts) do
    app_config = Application.get_env(:indrajaal, __MODULE__, [])

    %{
      enabled: Keyword.get(opts, :enabled, Keyword.get(app_config, :enabled, true)),
      batch_size:
        Keyword.get(opts, :batch_size, Keyword.get(app_config, :batch_size, @default_batch_size)),
      flush_interval_ms:
        Keyword.get(
          opts,
          :flush_interval_ms,
          Keyword.get(app_config, :flush_interval_ms, @default_flush_interval_ms)
        ),
      key_prefix:
        Keyword.get(opts, :key_prefix, Keyword.get(app_config, :key_prefix, @key_prefix)),
      levels:
        Keyword.get(opts, :levels, Keyword.get(app_config, :levels, [:l1, :l2, :l3, :l4, :l5]))
    }
  end

  defp level_enabled?(level, levels) do
    level in levels
  end

  # Runtime module reference to avoid compile-time warnings for test-only module
  defp zenoh_test_module, do: Module.concat([Indrajaal, Test, ZenohTestCoordinator])

  defp do_flush(entries, state) do
    start_time = System.monotonic_time(:microsecond)

    messages =
      Enum.map(entries, fn entry ->
        %{
          key: build_key(entry, state.key_prefix),
          payload: encode_entry(entry)
        }
      end)

    result =
      if state.coordinator do
        zenoh_test_module().publish_batch(state.coordinator, messages)
      else
        ZenohSession.publish_batch(messages)
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_time

    # Update stats
    count = length(entries)
    update_flush_stats(count, elapsed_us, result)

    # Emit telemetry
    :telemetry.execute(
      [:zenoh, :fractal, :flush],
      %{count: count, duration_us: elapsed_us},
      %{result: elem(result, 0)}
    )

    # Log if latency exceeds target
    if elapsed_us > 1000 do
      Logger.warning("[ZenohFractalPublisher] Flush latency #{elapsed_us}us exceeds 1ms target")
    end

    result
  end

  defp build_key(entry, prefix) do
    level = entry[:level] || :l3
    domain = entry[:domain] || "general"
    event_type = entry[:event_type] || "log"

    level_str = level |> Atom.to_string() |> String.downcase()
    domain_str = domain |> to_string() |> String.downcase() |> String.replace(" ", "_")
    event_str = event_type |> to_string() |> String.downcase() |> String.replace(" ", "_")

    "#{prefix}/#{level_str}/#{domain_str}/#{event_str}"
  end

  defp encode_entry(entry) do
    # Use BatchEncoder if available, fallback to JSON
    if Code.ensure_loaded?(BatchEncoder) do
      case BatchEncoder.encode(BatchEncoder.default_config(), [entry]) do
        {:ok, encoded} -> encoded
        _ -> Jason.encode!(entry)
      end
    else
      Jason.encode!(entry)
    end
  rescue
    _ -> Jason.encode!(entry)
  end

  defp update_flush_stats(count, elapsed_us, result) do
    # Update via persistent_term for lock-free access
    current = :persistent_term.get({__MODULE__, :stats}, initial_stats())

    updated = %{
      current
      | entries_published: current.entries_published + count,
        flushes: current.flushes + 1,
        total_latency_us: current.total_latency_us + elapsed_us,
        last_flush_at: DateTime.utc_now()
    }

    updated =
      case result do
        {:ok, _} -> updated
        {:error, _} -> %{updated | errors: current.errors + 1}
      end

    :persistent_term.put({__MODULE__, :stats}, updated)
  end

  defp initial_stats do
    %{
      entries_published: 0,
      flushes: 0,
      errors: 0,
      total_latency_us: 0,
      started_at: DateTime.utc_now(),
      last_flush_at: nil
    }
  end

  defp schedule_flush(interval_ms) do
    Process.send_after(self(), :flush_timer, interval_ms)
  end

  # ============================================================================
  # INCOMING EVENT HANDLER - SC-ZENOH-PUB-004
  # ============================================================================

  @doc """
  Handle incoming fractal event from ZenohMesh (F# → Elixir direction).

  Called by ZenohMesh when fractal log events are received from F# CEPAF.
  Routes the event to the fractal logging system for processing.
  """
  @spec handle_incoming_event(String.t(), map() | binary()) :: :ok
  def handle_incoming_event(key, payload) do
    Logger.debug("[ZenohFractalPublisher] Incoming event: #{key}")

    # Parse payload if binary
    parsed =
      case payload do
        binary when is_binary(binary) ->
          case Jason.decode(binary) do
            {:ok, map} -> map
            _ -> %{"raw" => binary}
          end

        map when is_map(map) ->
          map

        _ ->
          %{"raw" => inspect(payload)}
      end

    # Route to fractal decorator if available
    spawn(fn ->
      level = Map.get(parsed, "level", "l3")
      message = Map.get(parsed, "message", "")
      module_name = Map.get(parsed, "module_name", "cepaf")

      # Log via standard Logger with fractal metadata
      Logger.info("[Fractal:#{level}] #{module_name}: #{message}",
        fractal_level: level,
        source: :fsharp,
        module: module_name
      )

      # Broadcast to any subscribers via PubSub
      if Code.ensure_loaded?(Phoenix.PubSub) do
        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          "fractal:events",
          {:fractal_event, key, parsed}
        )
      end
    end)

    :ok
  end
end
