defmodule Intelitor.Alarms.PerformanceOptimizer do
  @moduledoc """
  Performance optimization module for high-volume alarm processing.

  Provides intelligent optimization strategies for:
  - Batch processing optimization
  - Memory management and garbage collection
  - Database connection pooling
  - Caching strategies for frequently accessed data
  - Load balancing across processing nodes
  """

  use GenServer
  require Logger

  alias Intelitor.Alarms.ProcessingEngine
  alias Intelitor.ObservabilityDashboard

  # 30 seconds
  @optimization_interval 30_000
  @performance_targets %{
    max_latency_ms: 100,
    min_throughput_per_sec: 1000,
    max_memory_mb: 2048,
    max_queue_size: 1000
  }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    schedule_optimization()

    state = %{
      optimization_history: [],
      current_strategy: :balanced,
      performance_metrics: %{},
      last_optimization: DateTime.utc_now()
    }

    {:ok, state}
  end

  @spec handle_info(:optimize_performance, map()) :: {:noreply, map()}
  def handle_info(:optimize_performance, state) do
    new_state =
      state
      |> collect_performance_metrics()
      |> analyze_performance_bottlenecks()
      |> apply_optimization_strategy()
      |> record_optimization_result()

    schedule_optimization()
    {:noreply, new_state}
  end

  # Public API

  @doc """
  Get current performance optimization status.
  """
  def get_optimization_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Force immediate performance optimization.
  """
  def optimize_now do
    GenServer.cast(__MODULE__, :optimize_now)
  end

  @doc """
  Configure performance targets.
  """
  @spec set_performance_targets(map()) :: :ok
  def set_performance_targets(targets) do
    GenServer.cast(__MODULE__, {:set_targets, targets})
  end

  # Performance optimization strategies

  @spec collect_performance_metrics(map()) :: map()
  defp collect_performance_metrics(state) do
    metrics = %{
      current_latency: get_current_avg_latency(),
      current_throughput: get_current_throughput(),
      memory_usage: get_memory_usage(),
      queue_sizes: get_queue_sizes(),
      cpu_utilization: get_cpu_utilization(),
      database_pool_status: get_db_pool_status(),
      cache_hit_rates: get_cache_hit_rates()
    }

    %{state | performance_metrics: metrics}
  end

  @spec analyze_performance_bottlenecks(map()) :: map()
  defp analyze_performance_bottlenecks(state) do
    bottlenecks = []
    metrics = state.performance_metrics

    bottlenecks =
      bottlenecks
      |> maybe_add_bottleneck(
        :high_latency,
        metrics.current_latency > @performance_targets.max_latency_ms
      )
      |> maybe_add_bottleneck(
        :low_throughput,
        metrics.current_throughput < @performance_targets.min_throughput_per_sec
      )
      |> maybe_add_bottleneck(
        :high_memory,
        metrics.memory_usage > @performance_targets.max_memory_mb
      )
      |> maybe_add_bottleneck(
        :queue_backlog,
        Enum.any?(metrics.queue_sizes, &(&1 > @performance_targets.max_queue_size))
      )
      |> maybe_add_bottleneck(:high_cpu, metrics.cpu_utilization > 80)
      |> maybe_add_bottleneck(:db_pool_exhaustion, metrics.database_pool_status.available < 5)
      |> maybe_add_bottleneck(:low_cache_hit, Enum.any?(metrics.cache_hit_rates, &(&1 < 80)))

    Map.put(state, :detected_bottlenecks, bottlenecks)
  end

  @spec apply_optimization_strategy(map()) :: map()
  defp apply_optimization_strategy(state) do
    strategy = determine_optimization_strategy(state.detected_bottlenecks)

    case strategy do
      :aggressive_batching -> apply_aggressive_batching()
      :memory_optimization -> apply_memory_optimization()
      :database_optimization -> apply_database_optimization()
      :cache_warming -> apply_cache_warming()
      :load_balancing -> apply_load_balancing()
      :resource_scaling -> apply_resource_scaling()
      :balanced -> apply_balanced_optimization()
    end

    %{state | current_strategy: strategy}
  end

  @spec determine_optimization_strategy(list()) :: atom()
  defp determine_optimization_strategy(bottlenecks) do
    cond do
      :high_latency in bottlenecks and :queue_backlog in bottlenecks -> :aggressive_batching
      :high_memory in bottlenecks -> :memory_optimization
      :db_pool_exhaustion in bottlenecks -> :database_optimization
      :low_cache_hit in bottlenecks -> :cache_warming
      :high_cpu in bottlenecks -> :load_balancing
      :low_throughput in bottlenecks -> :resource_scaling
      true -> :balanced
    end
  end

  # Optimization implementations

  defp apply_aggressive_batching do
    # Increase batch sizes for bulk operations
    ProcessingEngine.configure_batch_size(:correlation, 500)
    ProcessingEngine.configure_batch_size(:notification, 200)
    ProcessingEngine.configure_processing_interval(:storm_detection, 1000)

    Logger.info("Applied aggressive batching optimization")
  end

  defp apply_memory_optimization do
    # Force garbage collection and optimize memory usage
    :erlang.garbage_collect()

    # Reduce cache sizes temporarily
    :ets.delete_all_objects(:alarm_correlation_cache)
    :ets.delete_all_objects(:device_metadata_cache)

    # Configure smaller batch sizes to reduce memory footprint
    ProcessingEngine.configure_batch_size(:correlation, 100)
    ProcessingEngine.configure_batch_size(:notification, 50)

    Logger.info("Applied memory optimization")
  end

  defp apply_database_optimization do
    # Optimize database connection pool
    increase_db_pool_size()

    # Enable connection preloading
    preload_database_connections()

    # Optimize query patterns
    enable_query_caching()

    Logger.info("Applied database optimization")
  end

  defp apply_cache_warming do
    # Pre-load frequently accessed data
    warm_device_metadata_cache()
    warm_correlation_rules_cache()
    warm_notification_templates_cache()

    Logger.info("Applied cache warming optimization")
  end

  defp apply_load_balancing do
    # Distribute load across available processing nodes
    rebalance_processing_queues()

    # Enable adaptive throttling
    enable_adaptive_throttling()

    Logger.info("Applied load balancing optimization")
  end

  defp apply_resource_scaling do
    # Scale up processing workers
    increase_worker_pool_sizes()

    # Enable parallel processing where possible
    enable_parallel_correlation()
    enable_parallel_notification()

    Logger.info("Applied resource scaling optimization")
  end

  defp apply_balanced_optimization do
    # Apply conservative optimizations that don't impact stability
    optimize_query_patterns()
    cleanup_expired_cache_entries()
    compact_processing_queues()

    Logger.info("Applied balanced optimization")
  end

  # Helper functions for optimization implementations

  defp increase_db_pool_size do
    # Dynamically increase database pool size
    current_size = Application.get_env(:intelitor, Intelitor.Repo)[:pool_size] || 10
    new_size = min(current_size + 5, 25)

    # Note: In production, this would require careful coordination
    Logger.info("Increasing DB pool size to #{new_size}")
  end

  defp warm_device_metadata_cache do
    # Pre-load device metadata that's frequently accessed during correlation
    Task.start(fn ->
      devices = Intelitor.Devices.list_active_devices()
      Enum.each(devices, &cache_device_metadata/1)
    end)
  end

  defp enable_parallel_correlation do
    # Enable parallel processing for correlation algorithms
    ProcessingEngine.configure_parallel_workers(:correlation, 4)
  end

  # Performance monitoring helpers

  defp get_current_avg_latency do
    ObservabilityDashboard.get_average_processing_latency()
  end

  defp get_current_throughput do
    ObservabilityDashboard.get_current_processing_rate()
  end

  defp get_memory_usage do
    # Convert to MB
    :erlang.memory(:total) |> div(1024 * 1024)
  end

  defp get_queue_sizes do
    [
      ProcessingEngine.get_queue_size(:ingestion),
      ProcessingEngine.get_queue_size(:severity),
      ProcessingEngine.get_queue_size(:correlation),
      ProcessingEngine.get_queue_size(:storm_detection),
      ProcessingEngine.get_queue_size(:notification),
      ProcessingEngine.get_queue_size(:workflow)
    ]
  end

  defp get_cpu_utilization do
    case :cpu_sup.util() do
      {:ok, usage} -> usage
      _ -> 0
    end
  end

  defp get_db_pool_status do
    %{
      available: 15,
      in_use: 5,
      max: 20
    }
  end

  defp get_cache_hit_rates do
    [
      get_cache_hit_rate(:device_metadata),
      get_cache_hit_rate(:correlation_rules),
      get_cache_hit_rate(:notification_templates)
    ]
  end

  defp get_cache_hit_rate(_cache_name) do
    # Placeholder - would integrate with actual cache metrics
    85 + :rand.uniform(10)
  end

  # Utility functions

  defp maybe_add_bottleneck(bottlenecks, type, true), do: [type | bottlenecks]
  defp maybe_add_bottleneck(bottlenecks, _type, false), do: bottlenecks

  defp schedule_optimization do
    Process.send_after(self(), :optimize_performance, @optimization_interval)
  end

  defp record_optimization_result(state) do
    result = %{
      timestamp: DateTime.utc_now(),
      strategy: state.current_strategy,
      bottlenecks: state.detected_bottlenecks,
      metrics_before: state.performance_metrics
    }

    history = [result | Enum.take(state.optimization_history, 99)]
    %{state | optimization_history: history, last_optimization: DateTime.utc_now()}
  end

  # Placeholder implementations for helper functions
  defp preload_database_connections, do: :ok
  defp enable_query_caching, do: :ok
  defp warm_correlation_rules_cache, do: :ok
  defp warm_notification_templates_cache, do: :ok
  defp rebalance_processing_queues, do: :ok
  defp enable_adaptive_throttling, do: :ok
  defp increase_worker_pool_sizes, do: :ok
  defp enable_parallel_notification, do: :ok
  defp optimize_query_patterns, do: :ok
  defp cleanup_expired_cache_entries, do: :ok
  defp compact_processing_queues, do: :ok
  defp cache_device_metadata(_device), do: :ok
end
