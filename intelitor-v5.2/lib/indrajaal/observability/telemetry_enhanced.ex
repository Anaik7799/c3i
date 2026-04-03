defmodule Indrajaal.Observability.TelemetryEnhanced do
  @moduledoc """
  Enhanced telemetry module with advanced event handling and metric reporting.

  This module extends telemetry capabilities with:
  - Wildcard event pattern matching
  - Metric reporters with aggregation
  - Event metadata enrichment
  - Performance measurement utilities
  - Event batching and buffering
  - Automatic handler error recovery

  ## Usage

      # Attach a wildcard handler
      TelemetryEnhanced.attach_wildcard_handler(
        "my_wildcard",
        [:indrajaal, :*, :*],
        &handle_event/4,
        %{}
      )

      # Start a metric reporter
      TelemetryEnhanced.start_reporter(:my_reporter, %{
        metrics: [
          Telemetry.Metrics.counter("intelitor._request.count"),
          Telemetry.Metrics.distribution("intelitor._request.duration")
        ],
        interval: 5_000
      })
  """

  use GenServer
  require Logger

  @type event_name :: [atom()]
  @type measurements :: map()
  @type metadata :: map()
  @type handler_function :: (event_name(), measurements(), metadata(), any() -> any())

  defmodule Handler do
    @moduledoc false
    defstruct [:id, :event_pattern, :function, :config, :type, :attached_at]
  end

  defmodule Reporter do
    @moduledoc false
    defstruct [:name, :metrics, :interval, :pid, :status, :aggregated_data]
  end

  # State structure
  defstruct [
    :handlers,
    :reporters,
    :event_buffer,
    :metadata_enrichers,
    :global_metadata
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Emits a telemetry event with measurements and metadata.
  """
  def execute(event_name, measurements, metadata \\ %{}) when is_list(event_name) do
    # Enrich metadata
    enriched_metadata = enrich_metadata(metadata)

    # Execute standard telemetry
    :telemetry.execute(event_name, measurements, enriched_metadata)

    # Also send to our GenServer for wildcard handling
    GenServer.cast(__MODULE__, {:emit, event_name, measurements, enriched_metadata})

    :ok
  end

  @doc """
  Attaches an event handler.
  """
  def attach_handler(id, event_name, function, config) when is_function(function, 4) do
    # Use standard telemetry for exact matches
    :telemetry.attach(id, event_name, function, config)

    # Also register with our system
    GenServer.call(__MODULE__, {:register_handler, id, event_name, function, config, :exact})
  end

  @doc """
  Attaches a wildcard event handler.
  """
  def attach_wildcard_handler(id, event_pattern, function, config)
      when is_function(function, 4) do
    GenServer.call(
      __MODULE__,
      {:register_handler, id, event_pattern, function, config, :wildcard}
    )
  end

  @doc """
  Detaches an event handler.
  """
  def detach_handler(handler_ref) do
    # Try standard telemetry first
    try do
      :telemetry.detach(handler_ref)
    catch
      _, _ -> :ok
    end

    # Also remove from our registry
    GenServer.call(__MODULE__, {:detach_handler, handler_ref})
  end

  @doc """
  Lists handlers for an event.
  """
  def list_handlers(event_name) do
    GenServer.call(__MODULE__, {:list_handlers, event_name})
  end

  @doc """
  Starts a metric reporter.
  """
  def start_reporter(name, config) do
    GenServer.call(__MODULE__, {:start_reporter, name, config})
  end

  @doc """
  Stops a metric reporter.
  """
  def stop_reporter(name) do
    GenServer.call(__MODULE__, {:stop_reporter, name})
  end

  @doc """
  Gets the status of a reporter.
  """
  def get_reporter_status(name) do
    GenServer.call(__MODULE__, {:get_reporter_status, name})
  end

  @doc """
  Records a span of execution time.
  """
  def span(event_prefix, metadata \\ %{}, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time()
    start_metadata = Map.put(metadata, :start_time, start_time)

    # Emit start event
    execute(event_prefix ++ [:start], %{}, start_metadata)

    try do
      result = fun.()

      # Calculate duration
      end_time = System.monotonic_time()
      duration = end_time - start_time

      # Emit stop event
      execute(
        event_prefix ++ [:stop],
        %{duration: duration},
        Map.put(start_metadata, :end_time, end_time)
      )

      result
    rescue
      error ->
        # Emit exception event
        end_time = System.monotonic_time()
        duration = end_time - start_time

        execute(
          event_prefix ++ [:exception],
          %{duration: duration},
          Map.merge(start_metadata, %{
            error: error,
            stacktrace: __STACKTRACE__
          })
        )

        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Adds a metadata enricher function.
  """
  def add_metadata_enricher(name, enricher_fn) when is_function(enricher_fn, 1) do
    GenServer.call(__MODULE__, {:add_metadata_enricher, name, enricher_fn})
  end

  @doc """
  Sets global metadata that will be added to all events.
  """
  def set_global_metadata(metadata) when is_map(metadata) do
    GenServer.call(__MODULE__, {:set_global_metadata, metadata})
  end

  @doc """
  Gets aggregated metric data.
  """
  def get_metric_data(reporter_name, metric_name) do
    GenServer.call(__MODULE__, {:get_metric_data, reporter_name, metric_name})
  end

  @doc """
  Records measurements for a batch of events.
  """
  def batch_emit(events) when is_list(events) do
    Enum.each(events, fn {event_name, measurements, metadata} ->
      execute(event_name, measurements, metadata)
    end)
  end

  ## GenServer callbacks

  def init(_opts) do
    state = %__MODULE__{
      handlers: %{},
      reporters: %{},
      event_buffer: :queue.new(),
      metadata_enrichers: %{},
      global_metadata: %{}
    }

    {:ok, state}
  end

  def handle_call({:registerhandler, id, event_pattern, function, config, type}, _from, state) do
    handler = %Handler{
      id: id,
      event_pattern: event_pattern,
      function: function,
      config: config,
      type: type,
      attached_at: DateTime.utc_now()
    }

    updated_handlers = Map.put(state.handlers, id, handler)
    {:reply, {:ok, id}, %{state | handlers: updated_handlers}}
  end

  def handle_call({:detachhandler, handler_id}, _from, state) do
    updated_handlers = Map.delete(state.handlers, handler_id)
    {:reply, :ok, %{state | handlers: updated_handlers}}
  end

  def handle_call({:listhandlers, event_name}, _from, state) do
    matching_handlers =
      state.handlers
      |> Map.values()
      |> Enum.filter(fn handler ->
        matches_event_pattern?(handler.event_pattern, event_name, handler.type)
      end)
      |> Enum.map(fn handler ->
        %{
          id: handler.id,
          attached_at: handler.attached_at,
          type: handler.type
        }
      end)

    {:reply, matching_handlers, state}
  end

  def handle_call({:startreporter, name, config}, _from, state) do
    case start_reporter_process(name, config) do
      {:ok, pid} ->
        reporter = %Reporter{
          name: name,
          metrics: config.metrics,
          interval: config.interval,
          pid: pid,
          status: :running,
          aggregated_data: %{}
        }

        updated_reporters = Map.put(state.reporters, name, reporter)
        {:reply, {:ok, pid}, %{state | reporters: updated_reporters}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:stopreporter, name}, _from, state) do
    case Map.get(state.reporters, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      reporter ->
        if Process.alive?(reporter.pid) do
          Process.exit(reporter.pid, :shutdown)
        end

        updated_reporters = Map.delete(state.reporters, name)
        {:reply, :ok, %{state | reporters: updated_reporters}}
    end
  end

  def handle_call({:getreporterstatus, name}, _from, state) do
    case Map.get(state.reporters, name) do
      nil ->
        {:reply, :not_found, state}

      reporter ->
        status = if Process.alive?(reporter.pid), do: :running, else: :stopped
        {:reply, status, state}
    end
  end

  def handle_call({:addmetadataenricher, name, enricher_fn}, _from, state) do
    updated_enrichers = Map.put(state.metadata_enrichers, name, enricher_fn)
    {:reply, :ok, %{state | metadata_enrichers: updated_enrichers}}
  end

  def handle_call({:setglobalmetadata, metadata}, _from, state) do
    {:reply, :ok, %{state | global_metadata: metadata}}
  end

  def handle_call({:get_metric_data, reporter_name, metric_name}, _from, state) do
    case Map.get(state.reporters, reporter_name) do
      nil ->
        {:reply, {:error, :reporter_not_found}, state}

      reporter ->
        data = Map.get(reporter.aggregated_data, metric_name, %{})
        {:reply, {:ok, data}, state}
    end
  end

  def handle_call(:getstate, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:emit, event_name, measurements, metadata}, state) do
    # Handle wildcard handlers
    matching_handlers =
      state.handlers
      |> Map.values()
      |> Enum.filter(fn handler ->
        handler.type == :wildcard &&
          matches_event_pattern?(handler.event_pattern, event_name, :wildcard)
      end)

    # Execute each matching handler
    Enum.each(matching_handlers, fn handler ->
      try do
        handler.function.(event_name, measurements, metadata, handler.config)
      rescue
        error ->
          Logger.error("""
          Telemetry handler #{handler.id} failed and was detached.
          Event: #{inspect(event_name)}
          Error: #{Exception.message(error)}
          """)

          # Auto-detach failing handler
          GenServer.cast(self(), {:auto_detach, handler.id})
      end
    end)

    # Update reporters with new data
    state = update_reporters(state, event_name, measurements, metadata)

    {:noreply, state}
  end

  def handle_cast({:autodetach, handler_id}, state) do
    updated_handlers = Map.delete(state.handlers, handler_id)
    {:noreply, %{state | handlers: updated_handlers}}
  end

  def handle_cast({:reporterdata, reporter_name, metric_name, data}, state) do
    case Map.get(state.reporters, reporter_name) do
      nil ->
        {:noreply, state}

      reporter ->
        updated_data = Map.put(reporter.aggregated_data, metric_name, data)
        updated_reporter = %{reporter | aggregated_data: updated_data}
        updated_reporters = Map.put(state.reporters, reporter_name, updated_reporter)
        {:noreply, %{state | reporters: updated_reporters}}
    end
  end

  ## Private functions

  defp enrich_metadata(metadata) do
    state = GenServer.call(__MODULE__, :getstate)

    # Start with global metadata
    enriched = Map.merge(state.global_metadata, metadata)

    # Apply enrichers
    Enum.reduce(state.metadata_enrichers, enriched, fn {_name, enricher_fn}, acc ->
      Map.merge(acc, enricher_fn.(acc) || %{})
    end)
  end

  defp matches_event_pattern?(pattern, event_name, :exact) do
    pattern == event_name
  end

  defp matches_event_pattern?(pattern, event_name, :wildcard) do
    pattern_length = length(pattern)
    event_length = length(event_name)

    if pattern_length == event_length do
      zipped = Enum.zip(pattern, event_name)

      zipped
      |> Enum.all?(fn {p, e} ->
        p == :* || p == e
      end)
    else
      false
    end
  end

  defp start_reporter_process(name, config) do
    parent = self()

    {:ok,
     spawn_link(fn ->
       reporter_loop(name, config, parent)
     end)}
  end

  defp reporter_loop(name, config, parent) do
    # Initialize metric accumulators
    accumulators =
      config.metrics
      |> Enum.map(fn metric ->
        {metric_name(metric), initialize_accumulator(metric)}
      end)
      |> Map.new()

    # Set up telemetry handlers for metrics
    Enum.each(config.metrics, fn metric ->
      handler_id = "#{name}_#{metric_name(metric)}"
      event_name = metric_event_name(metric)

      :telemetry.attach(
        handler_id,
        event_name,
        fn _event_name, measurements, metadata, {acc_ref, metric_config} ->
          update_accumulator(acc_ref, measurements, metadata, metric_config)
        end,
        {accumulators[metric_name(metric)], metric}
      )
    end)

    # Start reporting loop
    Process.send_after(self(), :report, config.interval)

    reporter_loop_receive(name, config, parent, accumulators)
  end

  defp reporter_loop_receive(name, config, parent, accumulators) do
    receive do
      :report ->
        # Send aggregated data to parent
        Enum.each(accumulators, fn {metric_name, accumulator} ->
          data = read_accumulator(accumulator)
          GenServer.cast(parent, {:reporter_data, name, metric_name, data})
        end)

        # Schedule next report
        Process.send_after(self(), :report, config.interval)
        reporter_loop_receive(name, config, parent, accumulators)

      :shutdown ->
        # Cleanup handlers
        Enum.each(config.metrics, fn metric ->
          handler_id = "#{name}_#{metric_name(metric)}"
          :telemetry.detach(handler_id)
        end)

        :ok
    end
  end

  defp metric_name(%{name: name}), do: name
  defp metric_event_name(%{event_name: event_name}), do: event_name

  defp initialize_accumulator(%{type: :counter}), do: :atomics.new(1, [])
  defp initialize_accumulator(%{type: :sum}), do: :atomics.new(1, [])

  defp initialize_accumulator(%{type: :distribution}),
    do: :ets.new(:distribution, [:bag, :public])

  defp initialize_accumulator(%{type: :last_value}), do: :atomics.new(1, [])
  defp initialize_accumulator(_), do: :atomics.new(1, [])

  defp update_accumulator(acc, _measurements, _metadata, %{type: :counter}) do
    :atomics.add_get(acc, 1, 1)
  end

  defp update_accumulator(acc, measurements, _metadata, %{type: :sum, measurement: measurement}) do
    value = Map.get(measurements, measurement, 0)
    :atomics.add_get(acc, 1, value)
  end

  defp update_accumulator(acc, measurements, metadata, %{
         type: :distribution,
         measurement: measurement
       }) do
    value = Map.get(measurements, measurement, 0)
    :ets.insert(acc, {System.monotonic_time(), value, metadata})
  end

  defp update_accumulator(acc, measurements, _metadata, %{
         type: :last_value,
         measurement: measurement
       }) do
    value = Map.get(measurements, measurement, 0)
    :atomics.put(acc, 1, value)
  end

  defp read_accumulator(acc) when is_reference(acc) do
    # For atomics
    %{value: :atomics.get(acc, 1)}
  end

  defp read_accumulator(acc) do
    # For ETS (distribution)
    tab_list = :ets.tab2list(acc)
    values = tab_list |> Enum.map(fn {_, value, _} -> value end)

    if values == [] do
      %{count: 0, sum: 0, min: 0, max: 0}
    else
      %{
        count: length(values),
        sum: Enum.sum(values),
        min: Enum.min(values),
        max: Enum.max(values),
        avg: Enum.sum(values) / length(values)
      }
    end
  end

  defp update_reporters(state, _event_name, _measurements, _metadata) do
    # This is a placeholder - in a real implementation, you would update
    # reporters based on their configured metrics
    state
  end
end

# Define metric types that the enhanced telemetry will use
defmodule Indrajaal.Observability.TelemetryMetrics do
  @moduledoc """
  Custom metric type definitions for Indrajaal enhanced telemetry.
  Renamed to avoid conflict with standard Telemetry.Metrics module.
  """

  def counter(opts \\ []) do
    name = opts[:name] || "telemetry_metrics"

    %{
      type: :counter,
      name: name,
      event_name: parse_event_name(name),
      measurement: :count,
      tags: opts[:tags] || [],
      unit: opts[:unit]
    }
  end

  def sum(opts \\ []) do
    name = opts[:name] || "telemetry_metrics"

    %{
      type: :sum,
      name: name,
      event_name: parse_event_name(name),
      measurement: opts[:measurement] || :value,
      tags: opts[:tags] || [],
      unit: opts[:unit]
    }
  end

  def distribution(opts \\ []) do
    name = opts[:name] || "telemetry_metrics"

    %{
      type: :distribution,
      name: name,
      event_name: parse_event_name(name),
      measurement: opts[:measurement] || :value,
      tags: opts[:tags] || [],
      unit: opts[:unit],
      buckets: opts[:buckets]
    }
  end

  def last_value(opts \\ []) do
    name = opts[:name] || "telemetry_metrics"

    %{
      type: :last_value,
      name: name,
      event_name: parse_event_name(name),
      measurement: opts[:measurement] || :value,
      tags: opts[:tags] || [],
      unit: opts[:unit]
    }
  end

  defp parse_event_name(name) when is_binary(name) do
    name
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end
end
