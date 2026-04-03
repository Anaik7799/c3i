# Revolutionary Maximum Parallelization Infrastructure Configuration
# This configuration file contains settings for the advanced parallelization system

import Config

# Ultra-High Concurrency Engine Configuration
config :indrajaal, Indrajaal.Parallelization.UltraConcurrencyEngine,
  max_agents: 10_000,
  coordination_timeout_ms: 1,
  queue_capacity: 1_000_000,
  # 1GB
  memory_pool_size: 1024 * 1024 * 1024,
  performance_monitoring: true,
  optimization_enabled: true

# Advanced Parallel Processing Configuration
# DEPRECATED 2025-10-04: ParallelProcessor module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/parallel_processor.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.ParallelProcessor,
#   gpu_acceleration_threshold: 1000,
#   distributed_threshold: 100_000,
#   max_concurrent_jobs: 10_000,
#   ml_strategy_selection: true,
#   hybrid_processing: true

# Performance Optimizer Configuration
# DEPRECATED 2025-10-04: PerformanceOptimizer module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/performance_optimizer.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.PerformanceOptimizer,
#   optimization_interval_ms: 5_000,
#   thermal_threshold_celsius: 80,
#   power_efficiency_target: 0.85,
#   cache_hit_ratio_target: 0.90,
#   numa_optimization: true,
#   frequency_scaling: true

# Resource Manager Configuration
config :indrajaal, Indrajaal.Parallelization.ResourceManager,
  cpu_cores: System.schedulers_online(),
  total_memory_gb: 64,
  gpu_devices: 4,
  network_bandwidth_gbps: 10,
  storage_iops_limit: 100_000,
  dynamic_scaling: true

# Monitoring Dashboard Configuration
# DEPRECATED 2025-10-04: MonitoringDashboard module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/monitoring_dashboard.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.MonitoringDashboard,
#   metrics_collection_interval_ms: 1_000,
#   dashboard_refresh_interval_ms: 5_000,
#   anomaly_detection_interval_ms: 30_000,
#   data_retention_days: 90,
#   real_time_analytics: true,
#   ml_anomaly_detection: true

# Enterprise Integration Configuration
# DEPRECATED 2025-10-04: EnterpriseIntegrator module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/enterprise_integrator.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.EnterpriseIntegrator,
#   kubernetes_enabled: true,
#   docker_swarm_enabled: true,
#   multi_cloud_enabled: true,
#   ci_cd_integration: true,
#   security_rbac: true,
#   service_mesh: :istio,
#   observability_stack: [:prometheus, :grafana, :jaeger]

# Agent Pool Configuration
config :indrajaal, Indrajaal.Parallelization.AgentPool,
  max_capacity: 10_000,
  cpu_affinity_optimization: true,
  numa_aware_scheduling: true,
  load_balancing_strategy: :round_robin,
  performance_tracking: true

# Task Queue Configuration
config :indrajaal, Indrajaal.Parallelization.TaskQueue,
  max_capacity: 1_000_000,
  priority_levels: [:critical, :high, :normal, :low, :background],
  rate_limiting: true,
  backpressure_handling: true,
  dependency_tracking: true

# GPU Accelerator Configuration
# DEPRECATED 2025-10-04: GPUAccelerator module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/gpu_accelerator.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.GPUAccelerator,
#   gpu_devices: System.get_env("GPU_DEVICES") || "0",
#   compute_kernels: [:matrix_multiply, :vector_add, :convolution],
#   memory_management: true,
#   fallback_cpu: true

# Distributed Processor Configuration
# DEPRECATED 2025-10-04: DistributedProcessor module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/distributed_processor.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.DistributedProcessor,
#   nodes: System.get_env("DISTRIBUTED_NODES") || "localhost",
#   load_balancer: :consistent_hash,
#   fault_tolerance: %{retries: 3, timeout_ms: 30_000},
#   node_discovery: :static

# Stream Processor Configuration
# DEPRECATED 2025-10-04: StreamProcessor module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/stream_processor.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.StreamProcessor,
#   buffer_size: 10_000,
#   backpressure_strategy: :drop_oldest,
#   fault_tolerance: %{restart_strategy: :one_for_one, max_restarts: 5},
#   parallel_stages: true

# Batch Processor Configuration
# DEPRECATED 2025-10-04: BatchProcessor module archived - not integrated into application
# Module moved to lib/indrajaal/parallelization/_archive/batch_processor.ex.archived
# Configuration kept for reference but module is not started in supervision tree
# config :indrajaal, Indrajaal.Parallelization.BatchProcessor,
#   scheduler: :priority_based,
#   resource_allocator: :fair_share,
#   job_queue_size: 100_000,
#   parallel_execution: true

# Environment-specific configurations
case Mix.env() do
  :dev ->
    config :indrajaal, Indrajaal.Parallelization.UltraConcurrencyEngine,
      # Reduced for development
      max_agents: 1_000,
      # 256MB
      memory_pool_size: 256 * 1024 * 1024

  # DEPRECATED 2025-10-04: MonitoringDashboard archived
  # config :indrajaal, Indrajaal.Parallelization.MonitoringDashboard,
  #   # Less frequent in dev
  #   metrics_collection_interval_ms: 5_000,
  #   data_retention_days: 7

  :test ->
    config :indrajaal, Indrajaal.Parallelization.UltraConcurrencyEngine,
      # Minimal for testing
      max_agents: 100,
      # 64MB
      memory_pool_size: 64 * 1024 * 1024

  # DEPRECATED 2025-10-04: MonitoringDashboard archived
  # config :indrajaal, Indrajaal.Parallelization.MonitoringDashboard,
  #   # Even less frequent in test
  #   metrics_collection_interval_ms: 10_000,
  #   data_retention_days: 1

  :prod ->
    config :indrajaal, Indrajaal.Parallelization.UltraConcurrencyEngine,
      # Maximum for production
      max_agents: 50_000,
      # 4GB
      memory_pool_size: 4 * 1024 * 1024 * 1024

    # DEPRECATED 2025-10-04: PerformanceOptimizer archived
    # config :indrajaal, Indrajaal.Parallelization.PerformanceOptimizer,
    #   # More aggressive in production
    #   optimization_interval_ms: 1_000,
    #   ml_optimization: true

    # DEPRECATED 2025-10-04: MonitoringDashboard archived
    # config :indrajaal, Indrajaal.Parallelization.MonitoringDashboard,
    #   # High frequency in production
    #   metrics_collection_interval_ms: 500,
    #   data_retention_days: 365,
    #   alerting_enabled: true
end

# Telemetry Configuration for Parallelization Metrics
config(
  :telemetry_poller,
  :measurements,
  # System metrics
  {Indrajaal.Parallelization.UltraConcurrencyEngine, :get_performance_metrics, []},
  {Indrajaal.Parallelization.ResourceManager, :get_resource_stats, []},
  # DEPRECATED 2025-10-04: MonitoringDashboard archived
  # {Indrajaal.Parallelization.MonitoringDashboard, :get_performance_analytics, [:last_hour]},

  # Custom metrics
  {:process_info, [:message_queue_len]},
  {:process_info, [:memory]},
  {System, :schedulers_online, []}
)

# Logging Configuration
config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :parallelization_log}]

config :logger, :parallelization_log,
  path: "./logs/parallelization.log",
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :agent_id, :task_id, :deployment_id]

# Task Supervisor Configuration
config :indrajaal, Indrajaal.TaskSupervisor,
  max_children: 100_000,
  strategy: :one_for_one,
  max_restarts: 1000,
  max_seconds: 5

# Prometheus Metrics Configuration
if Code.ensure_loaded?(PromEx) do
  config :indrajaal, IndrajaalWeb.PromEx,
    disabled: false,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    grafana: [
      host: System.get_env("GRAFANA_HOST") || "http://localhost:3000",
      auth_token: System.get_env("GRAFANA_TOKEN"),
      upload_dashboards_on_start: true,
      folder_name: "Indrajaal Parallelization",
      annotate_app_lifecycle: true
    ],
    metrics: [
      # Built-in metrics
      :application,
      :beam,
      :phoenix,
      :ecto,
      :oban,

      # Custom parallelization metrics
      {Indrajaal.Parallelization.Metrics, []}
    ]
end
