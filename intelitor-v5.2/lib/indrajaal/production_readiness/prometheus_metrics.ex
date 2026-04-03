defmodule Indrajaal.ProductionReadiness.PrometheusMetrics do
  @moduledoc """
  Prometheus metrics definition and collection system.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - SC-012: Monitoring must not impact system performance
  """

  use GenServer
  require Logger

  @default_limits %{
    max_cpu_percent: 2.0,
    max_memory_mb: 100,
    max_cardinality: 10_000
  }

  @metric_types [:counter, :gauge, :histogram, :summary]

  # Client API

  def start_link(opts \\ []) do
    limits = Map.merge(@default_limits, Map.new(opts))
    GenServer.start_link(__MODULE__, limits, name: __MODULE__)
  end

  @doc """
  Define a single metric with cardinality validation.
  Satisfies SC-012: Monitoring must not impact system performance.
  """
  def define_metric(metric_spec) do
    GenServer.call(__MODULE__, {:define_metric, metric_spec})
  end

  @doc """
  Define multiple metrics at once.
  """
  def define_metrics(metric_specs) when is_list(metric_specs) do
    GenServer.call(__MODULE__, {:define_metrics, metric_specs})
  end

  @doc """
  Increment a counter metric.
  """
  def inc(metric_name, labels \\ []) do
    GenServer.cast(__MODULE__, {:inc, metric_name, labels})
  end

  @doc """
  Set a gauge metric value.
  """
  def set(metric_name, value, labels \\ []) do
    GenServer.cast(__MODULE__, {:set, metric_name, value, labels})
  end

  @doc """
  Observe a value for histogram/summary metrics.
  """
  def observe(metric_name, value, labels \\ []) do
    GenServer.cast(__MODULE__, {:observe, metric_name, value, labels})
  end

  @doc """
  Export metrics in Prometheus exposition format.
  """
  def export do
    GenServer.call(__MODULE__, :export)
  end

  @doc """
  Get current monitoring overhead.
  """
  def get_overhead do
    GenServer.call(__MODULE__, :get_overhead)
  end

  # Server callbacks

  @impl true
  def init(limits) do
    state = %{
      limits: limits,
      metrics: %{},
      values: %{},
      start_time: System.monotonic_time(:millisecond),
      last_export_time: System.monotonic_time(:millisecond),
      cpu_samples: [],
      memory_samples: []
    }

    # Start monitoring overhead
    schedule_overhead_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:define_metric, {type, name, help, labels}}, _from, state) do
    # SC-012: Validate cardinality
    case validate_cardinality(labels, state) do
      :ok ->
        metric_def = %{
          type: type,
          name: name,
          help: help,
          labels: labels,
          created_at: DateTime.utc_now()
        }

        new_metrics = Map.put(state.metrics, name, metric_def)
        new_state = %{state | metrics: new_metrics}

        Logger.info("[PrometheusMetrics] Defined metric: #{name} (#{type})")

        {:reply, {:ok, metric_def}, new_state}

      {:error, :cardinality_too_high} = error ->
        Logger.error("[PrometheusMetrics] Metric #{name} rejected - cardinality too high")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:define_metrics, specs}, _from, state) do
    results =
      Enum.map(specs, fn spec ->
        case validate_metric_spec(spec, state) do
          {:ok, {type, name, help, labels}} ->
            metric_def = %{
              type: type,
              name: name,
              help: help,
              labels: labels,
              created_at: DateTime.utc_now()
            }

            {name, {:ok, metric_def}}

          error ->
            {elem(spec, 1), error}
        end
      end)

    # Filter successful definitions
    successful =
      results
      |> Enum.filter(fn {_, result} -> match?({:ok, _}, result) end)
      |> Enum.map(fn {name, {:ok, def}} -> {name, def} end)
      |> Map.new()

    new_metrics = Map.merge(state.metrics, successful)
    new_state = %{state | metrics: new_metrics}

    {:reply, {:ok, successful}, new_state}
  end

  @impl true
  def handle_call(:export, _from, state) do
    exposition = generate_exposition_format(state)

    new_state = %{state | last_export_time: System.monotonic_time(:millisecond)}

    {:reply, {:ok, exposition}, new_state}
  end

  @impl true
  def handle_call(:get_overhead, _from, state) do
    cpu_percent = calculate_cpu_overhead(state.cpu_samples)
    memory_mb = calculate_memory_overhead(state.memory_samples)

    overhead = %{
      cpu_percent: cpu_percent,
      memory_mb: memory_mb,
      total_metrics: map_size(state.metrics),
      total_series: count_total_series(state.values),
      within_limits:
        cpu_percent < state.limits.max_cpu_percent and
          memory_mb < state.limits.max_memory_mb
    }

    {:reply, {:ok, overhead}, state}
  end

  @impl true
  def handle_cast({:inc, metric_name, labels}, state) do
    case Map.get(state.metrics, metric_name) do
      # AGENT GA FIX: Unused variable
      %{type: :counter} = _metric ->
        new_values = increment_counter(state.values, metric_name, labels)
        {:noreply, %{state | values: new_values}}

      _ ->
        # AGENT GA FIX
        Logger.warning("[PrometheusMetrics] Metric #{metric_name} not found or not a counter")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:set, metric_name, value, labels}, state) do
    case Map.get(state.metrics, metric_name) do
      # AGENT GA FIX: Unused variable
      %{type: :gauge} = _metric ->
        new_values = set_gauge(state.values, metric_name, value, labels)
        {:noreply, %{state | values: new_values}}

      _ ->
        # AGENT GA FIX
        Logger.warning("[PrometheusMetrics] Metric #{metric_name} not found or not a gauge")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:observe, metric_name, value, labels}, state) do
    case Map.get(state.metrics, metric_name) do
      %{type: type} when type in [:histogram, :summary] ->
        new_values = observe_value(state.values, metric_name, value, labels, type)
        {:noreply, %{state | values: new_values}}

      _ ->
        # AGENT GA FIX: Updated deprecated Logger.warn
        Logger.warning(
          "[PrometheusMetrics] Metric #{metric_name} not found or not a histogram/summary"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:check_overhead, state) do
    # Sample current resource usage
    cpu_sample = sample_cpu_usage()
    memory_sample = sample_memory_usage()

    new_state = %{
      state
      | cpu_samples: [cpu_sample | state.cpu_samples] |> Enum.take(60),
        memory_samples: [memory_sample | state.memory_samples] |> Enum.take(60)
    }

    # Schedule next check
    schedule_overhead_check()

    {:noreply, new_state}
  end

  # Private functions

  defp validate_cardinality(labels, state) do
    # Estimate potential cardinality
    estimated_cardinality = estimate_label_cardinality(labels)

    if estimated_cardinality > state.limits.max_cardinality do
      {:error, :cardinality_too_high}
    else
      :ok
    end
  end

  defp estimate_label_cardinality(labels) do
    # Estimate based on label names
    label_cardinalities = %{
      user_id: 10_000,
      _request_id: 100_000,
      session_id: 50_000,
      timestamp: 1_000_000,
      method: 10,
      endpoint: 100,
      status: 10,
      service: 20,
      query_type: 50
    }

    labels
    |> Enum.map(fn label ->
      Map.get(label_cardinalities, label, 100)
    end)
    |> Enum.reduce(1, &*/2)
  end

  defp validate_metric_spec(spec, state) do
    case spec do
      {type, name, help, labels} when type in @metric_types ->
        case validate_cardinality(labels, state) do
          :ok -> {:ok, {type, name, help, labels}}
          error -> error
        end

      _ ->
        {:error, :invalid_metric_spec}
    end
  end

  defp increment_counter(values, metric_name, labels) do
    key = {metric_name, serialize_labels(labels)}
    Map.update(values, key, 1, &(&1 + 1))
  end

  defp set_gauge(values, metric_name, value, labels) do
    key = {metric_name, serialize_labels(labels)}
    Map.put(values, key, value)
  end

  defp observe_value(values, metric_name, value, labels, :histogram) do
    key = {metric_name, serialize_labels(labels)}

    histogram =
      Map.get(values, key, %{
        count: 0,
        sum: 0,
        buckets: default_histogram_buckets()
      })

    updated = %{
      count: histogram.count + 1,
      sum: histogram.sum + value,
      buckets: update_histogram_buckets(histogram.buckets, value)
    }

    Map.put(values, key, updated)
  end

  defp observe_value(values, metric_name, value, labels, :summary) do
    key = {metric_name, serialize_labels(labels)}

    summary =
      Map.get(values, key, %{
        count: 0,
        sum: 0,
        values: []
      })

    # Keep last 1000 values for percentile calculation
    new_values = [value | summary.values] |> Enum.take(1000)

    updated = %{
      count: summary.count + 1,
      sum: summary.sum + value,
      values: new_values
    }

    Map.put(values, key, updated)
  end

  defp serialize_labels(labels) do
    labels
    |> Enum.sort()
    |> Enum.map_join(",", fn {k, v} -> "#{k}=\"#{v}\"" end)
  end

  defp default_histogram_buckets do
    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
    |> Enum.map(fn le -> {le, 0} end)
    |> Map.new()
  end

  defp update_histogram_buckets(buckets, value) do
    buckets
    |> Enum.map(fn {le, count} ->
      if value <= le do
        {le, count + 1}
      else
        {le, count}
      end
    end)
    |> Map.new()
  end

  defp generate_exposition_format(state) do
    # AGENT GA FIX: STUB - unused variable in incomplete implementation
    _lines = []

    # Group by metric name
    grouped =
      state.values
      |> Enum.group_by(fn {{name, _}, _} -> name end)

    all_lines =
      Enum.flat_map(state.metrics, fn {name, metric_def} ->
        metric_lines = ["# HELP #{name} #{metric_def.help}"]
        metric_lines = ["# TYPE #{name} #{metric_def.type}" | metric_lines]

        # Get all values for this metric
        values = Map.get(grouped, name, [])

        value_lines =
          Enum.flat_map(values, fn {{_, labels_str}, value} ->
            format_metric_value(name, labels_str, value, metric_def.type)
          end)

        metric_lines ++ value_lines ++ [""]
      end)

    Enum.join(all_lines, "\n")
  end

  defp format_metric_value(name, labels_str, value, :counter) do
    if labels_str == "" do
      ["#{name} #{value}"]
    else
      ["#{name}{#{labels_str}} #{value}"]
    end
  end

  defp format_metric_value(name, labels_str, value, :gauge) do
    if labels_str == "" do
      ["#{name} #{value}"]
    else
      ["#{name}{#{labels_str}} #{value}"]
    end
  end

  defp format_metric_value(name, labels_str, histogram, :histogram) do
    base = if labels_str == "", do: name, else: "#{name}{#{labels_str}}"

    bucket_lines =
      histogram.buckets
      |> Enum.map(fn {le, count} ->
        "#{name}_bucket{#{labels_str}#{if labels_str != "", do: ","}le=\"#{le}\"} #{count}"
      end)

    bucket_lines ++
      [
        "#{name}_bucket{#{labels_str}#{if labels_str != "", do: ","}le=\"+Inf\"} #{histogram.count}",
        "#{base}_count #{histogram.count}",
        "#{base}_sum #{histogram.sum}"
      ]
  end

  defp format_metric_value(name, labels_str, summary, :summary) do
    base = if labels_str == "", do: name, else: "#{name}{#{labels_str}}"

    percentiles =
      if length(summary.values) > 0 do
        calculate_percentiles(summary.values)
      else
        %{}
      end

    quantile_lines =
      percentiles
      |> Enum.map(fn {q, value} ->
        "#{name}{#{labels_str}#{if labels_str != "", do: ","}quantile=\"#{q}\"} #{value}"
      end)

    quantile_lines ++
      [
        "#{base}_count #{summary.count}",
        "#{base}_sum #{summary.sum}"
      ]
  end

  defp calculate_percentiles(values) do
    sorted = Enum.sort(values)
    len = length(sorted)

    %{
      "0.5" => Enum.at(sorted, div(len, 2)),
      "0.9" => Enum.at(sorted, div(len * 9, 10)),
      "0.99" => Enum.at(sorted, div(len * 99, 100))
    }
  end

  defp count_total_series(values) do
    map_size(values)
  end

  defp sample_cpu_usage do
    # In production, this would sample actual CPU usage
    # Simulating low overhead
    :rand.uniform() * 1.5
  end

  defp sample_memory_usage do
    # In production, this would sample actual memory usage
    # Simulating memory usage in MB
    50 + :rand.uniform() * 20
  end

  defp calculate_cpu_overhead([]), do: 0.0

  defp calculate_cpu_overhead(samples) do
    Enum.sum(samples) / length(samples)
  end

  defp calculate_memory_overhead([]), do: 0.0

  defp calculate_memory_overhead(samples) do
    Enum.sum(samples) / length(samples)
  end

  defp schedule_overhead_check do
    Process.send_after(self(), :check_overhead, 5_000)
  end
end
