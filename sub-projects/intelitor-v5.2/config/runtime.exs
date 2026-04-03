# ═════════════════════════════════════════════════════════════════════════════
# SOPv5.1 ENHANCED ENVIRONMENT CONFIGURATION - runtime.exs
# ═════════════════════════════════════════════════════════════════════════════
#
# Enhanced: 2025-08-02 17:30:00 CEST
# Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Patient Mode + Container-Only
# Category: development_configs
# Agent: Environment Variable Enhancement System with Cybernetic Integration
# Status: Complete SOPv5.1 framework environment integration applied
#
# 🏆 SOPv5.1 Framework Environment Integration
#
# This environment configuration has been enhanced with comprehensive SOPv5.1
# cybernetic execution framework integration, providing enterprise-grade
# systematic excellence across all environment variables and configurations.
#
# Framework Components Integrated:
# - SOPv5.1: Cybernetic Goal-Oriented Execution with 6-phase systematic executi
# - TPS: Toyota Production System with 5-Level Root Cause Analysis methodology
# - STAMP: Safety Constraint Validation with real-time monitoring and compliance
# - TDG: Test-Driven Generation methodology with comprehensive quality assurance
# - GDE: Goal-Directed Execution with adaptive strategy selection and optimizat
# - Patient Mode: NO_TIMEOUT policy with infinite patience execution across all
# - Container-Only: Mandatory NixOS container execution with PHICS integration
# - 11-Agent Architecture: Multi-agent coordination with dynamic load balancing
#
# ═════════════════════════════════════════════════════════════════════════════

import Config

# Store the current environment for runtime retrieval in application.ex
config :indrajaal, env: config_env()

# ═════════════════════════════════════════════════════════════════════════════
# MANDATORY: Dual Logging Configuration (Console + SigNoz)
# ═════════════════════════════════════════════════════════════════════════════
#
# CRITICAL: Both console and structured JSON logging MUST be active at all time
# This provides immediate developer feedback via console while maintaining
# comprehensive observability through SigNoz.
#
# ═════════════════════════════════════════════════════════════════════════════

# Console logging for immediate visibility
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: :all,
  level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

# Logger level configuration
# NOTE: :backends key is deprecated in Elixir 1.19+. LoggerJSON is added via
# LoggerBackends.add(LoggerJSON) in Indrajaal.Application.start/2
config :logger,
  level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

config :logger_json, :backend,
  formatter: LoggerJSON.Formatters.DatadogLogger,
  metadata: :all

# ═════════════════════════════════════════════════════════════════════════════
# OpenTelemetry Configuration for SigNoz Integration
# ═════════════════════════════════════════════════════════════════════════════
#
# This configuration enables distributed tracing across the entire application
# and ensures proper integration with SigNoz observability platform.
#
# ═════════════════════════════════════════════════════════════════════════════

# Helper function to parse OTLP headers (moved before usage to fix forward reference)
parse_otlp_headers = fn
  "" ->
    []

  headers_string ->
    headers_string
    |> String.split(",")
    |> Enum.map(fn header ->
      [key, value] = String.split(header, "=", parts: 2)
      {String.trim(key), String.trim(value)}
    end)
end

# OTLP Exporter endpoint configuration
# Default: http://localhost:4317 (standard OTLP gRPC port)
otlp_endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

config :opentelemetry_exporter,
  otlp: [
    endpoint: otlp_endpoint,
    compression: :gzip,
    headers: parse_otlp_headers.(System.get_env("OTEL_EXPORTER_OTLP_HEADERS", ""))
  ]

# Configure trace sampling based on environment
# Production: Use probability sampling to reduce overhead
# Development/Test: Sample everything for complete visibility
sampler =
  case System.get_env("OTEL_TRACES_SAMPLER") do
    "always_off" ->
      {:always_off, []}

    "probability" ->
      ratio = String.to_float(System.get_env("OTEL_TRACES_SAMPLER_ARG", "1.0"))
      {:probability, probability: ratio}

    _ ->
      # Default to always_on for development
      {:always_on, []}
  end

config :opentelemetry,
  sampler: sampler,
  # W3C Trace Context propagation — ensures traceparent headers flow across
  # Elixir↔F#↔Rust runtime boundaries via Zenoh messages and HTTP calls
  text_map_propagators: [:trace_context, :baggage],
  resource: [
    service: [
      name: System.get_env("OTEL_SERVICE_NAME", "indrajaal"),
      version: System.get_env("OTEL_SERVICE_VERSION", "21.3.0"),
      namespace: System.get_env("OTEL_SERVICE_NAMESPACE", "indrajaal")
    ],
    deployment: [
      environment: System.get_env("OTEL_DEPLOYMENT_ENVIRONMENT", Atom.to_string(config_env()))
    ]
  ]

# Configure SigNoz-specific settings
config :indrajaal, :signoz,
  enabled: System.get_env("SIGNOZ_ENABLED", "true") == "true",
  service_name: System.get_env("SIGNOZ_SERVICE_NAME", "indrajaal"),
  environment: System.get_env("SIGNOZ_ENVIRONMENT", Atom.to_string(config_env()))

# ═════════════════════════════════════════════════════════════════════════════
# Tailscale DNS Configuration (Centralized)
# ═════════════════════════════════════════════════════════════════════════════
#
# Host-Aligned Naming Convention: {service}-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}
#
# All containers inherit the host machine's Tailscale identity, ensuring proper
# MagicDNS resolution and identity-based access control.
#
# Environment Variables (from tailscale.env):
# - TAILSCALE_DNS_SUFFIX: Tailnet DNS suffix (e.g., tailnet-abc123.ts.net)
# - TS_HOSTNAME: Host's Tailscale hostname (e.g., devbox)
# - TS_IP_ADDRESS: Tailscale IPv4 address for EPMD binding
# - CLUSTER_NODE_1/2/3: Individual cluster node hostnames
#
# STAMP Compliance:
# - SC-CLU-001: Identity-based networking via Tailscale MagicDNS
# - SC-CLU-002: Minimum 3 nodes for HA (configured below)
# - SC-CLU-003: Kubernetes DNS in production
# - SC-CLU-004: EPMD binds to Tailscale IP only
# - SC-CLU-005: Split-brain prevention with consistent naming
#
# ═════════════════════════════════════════════════════════════════════════════

# Tailscale DNS Configuration (SC-CLU-001: Identity-based networking)
tailnet_suffix = System.get_env("TAILSCALE_DNS_SUFFIX", "tailnet.ts.net")
ts_hostname = System.get_env("TS_HOSTNAME", "localhost")
ts_ip_address = System.get_env("TS_IP_ADDRESS", "127.0.0.1")

# Cluster node hostnames (host-aligned naming)
cluster_node_1 = System.get_env("CLUSTER_NODE_1", ts_hostname)
cluster_node_2 = System.get_env("CLUSTER_NODE_2", "node2")
cluster_node_3 = System.get_env("CLUSTER_NODE_3", "node3")

# Generate cluster node names
# SC-CLU-002: Minimum 3 nodes for HA
# SC-NAME-001: Container mode uses simple hostnames, Tailscale mode uses FQDN
tailscale_enabled = System.get_env("TAILSCALE_ENABLED", "true") == "true"

cluster_nodes =
  [cluster_node_1, cluster_node_2, cluster_node_3]
  |> Enum.map(fn node_hostname ->
    if tailscale_enabled do
      # Tailscale mode: indrajaal@indrajaal-{hostname}.{tailnet_suffix}
      String.to_atom("indrajaal@indrajaal-#{node_hostname}.#{tailnet_suffix}")
    else
      # Container mode: indrajaal@{hostname} (hostname already contains container name)
      String.to_atom("indrajaal@#{node_hostname}")
    end
  end)

# Container FQDN configuration (host-aligned)
container_fqdns = %{
  app: "indrajaal-#{ts_hostname}.#{tailnet_suffix}",
  timescaledb: "timescaledb-#{ts_hostname}.#{tailnet_suffix}",
  redis: "redis-#{ts_hostname}.#{tailnet_suffix}",
  prometheus: "prometheus-#{ts_hostname}.#{tailnet_suffix}",
  grafana: "grafana-#{ts_hostname}.#{tailnet_suffix}",
  nginx: "nginx-#{ts_hostname}.#{tailnet_suffix}",
  signoz: "signoz-#{ts_hostname}.#{tailnet_suffix}",
  otel: "otel-#{ts_hostname}.#{tailnet_suffix}",
  clickhouse: "clickhouse-#{ts_hostname}.#{tailnet_suffix}"
}

# Export Tailscale DNS configuration to application config
config :indrajaal, :tailscale,
  dns_suffix: tailnet_suffix,
  hostname: ts_hostname,
  ip_address: ts_ip_address,
  container_fqdns: container_fqdns

config :indrajaal, :tailscale_dns_suffix, tailnet_suffix
config :indrajaal, :cluster_nodes, cluster_nodes

# Local DNS Suffix for fallback (SC-CLU-004: Graceful degradation)
local_dns_suffix = System.get_env("LOCAL_DNS_SUFFIX", "local.indrajaal")
config :indrajaal, :local_dns_suffix, local_dns_suffix

# ═════════════════════════════════════════════════════════════════════════════
# DISTRIBUTED MODE CONFIGURATION (SC-CLU-001: Default Distributed)
# ═════════════════════════════════════════════════════════════════════════════
#
# Default: "standalone" (Tailscale mDNS mesh)
# This enables full clustering services using Tailscale identity-based networking.
#
# Available strategies:
# - "standalone" (default): Single-node or Mesh with Tailscale mDNS (NO DNS Dependency)
# - "distributed": Legacy multi-strategy (deprecated for local dev)
# - "epmd": Static EPMD with Tailscale DNS
# - "k8s": Kubernetes DNS strategy for K8s production
#
# ═════════════════════════════════════════════════════════════════════════════

# Distributed mode flag (enables all clustering services)
distributed_mode = System.get_env("DISTRIBUTED_MODE", "true") == "true"
config :indrajaal, :distributed_mode, distributed_mode

# Force Tailscale Mode for local/standalone execution without external DNS
# This enforces SC-CLU-001 Identity-Based Networking via Tailscale mDNS
System.put_env("FORCE_TAILSCALE_MODE", "true")

# Cluster strategy selection (default to "standalone" for local dev)
cluster_strategy = System.get_env("CLUSTER_STRATEGY", "standalone")

# Skip libcluster in test environment (SC-CLU-001 test mode)
if config_env() != :test do
  topologies =
    case cluster_strategy do
      strategy when strategy in ["standalone", "distributed", nil] ->
        # Standalone/Default Strategy: Strictly uses Tailscale mDNS
        # SC-CLU-001: Identity-based networking enabled by default
        # SC-CLU-004: No reliance on external DNS, use Tailscale mesh
        [
          standalone: [
            strategy: Indrajaal.Cluster.Strategies.Standalone,
            config: [
              hosts: [cluster_node_1, cluster_node_2, cluster_node_3],
              polling_interval: 5_000,
              prefer_tailscale: true,
              connection_timeout: 10_000
            ]
          ]
        ]

      "epmd" ->
        # EPMD Strategy: Static hosts with Tailscale DNS (SC-CLU-001)
        [
          tailscale_mesh: [
            strategy: Cluster.Strategy.Epmd,
            config: [
              hosts: cluster_nodes
            ]
          ]
        ]

      "k8s" ->
        # Kubernetes Strategy: For K8s production environments (SC-CLU-003)
        [
          k8s_cluster: [
            strategy: Cluster.Strategy.Kubernetes.DNS,
            config: [
              service: "indrajaal-headless",
              application_name: :indrajaal,
              polling_interval: 5_000,
              epmd_bind_address: ts_ip_address
            ]
          ]
        ]

      "multi" ->
        # Multi-Strategy: All topologies active for hybrid environments
        [
          standalone: [
            strategy: Indrajaal.Cluster.Strategies.Standalone,
            config: [
              hosts: [cluster_node_1, cluster_node_2, cluster_node_3],
              polling_interval: 5_000,
              prefer_tailscale: true,
              connection_timeout: 10_000
            ]
          ],
          tailscale_mesh: [
            strategy: Cluster.Strategy.Epmd,
            config: [
              hosts: cluster_nodes
            ]
          ],
          k8s_cluster: [
            strategy: Cluster.Strategy.Kubernetes.DNS,
            config: [
              service: "indrajaal-headless",
              application_name: :indrajaal,
              polling_interval: 5_000,
              epmd_bind_address: ts_ip_address
            ]
          ]
        ]

      _ ->
        # Fallback to standalone mode
        [
          standalone: [
            strategy: Indrajaal.Cluster.Strategies.Standalone,
            config: [
              hosts: [cluster_node_1, cluster_node_2, cluster_node_3],
              polling_interval: 5_000,
              prefer_tailscale: true,
              connection_timeout: 10_000
            ]
          ]
        ]
    end

  config :libcluster, topologies: topologies
end

# ═════════════════════════════════════════════════════════════════════════════
# OpenRouter and Cloud AI Configuration (Bicameral Mind)
# ═════════════════════════════════════════════════════════════════════════════
#
# Configures access to Gemini and Claude via OpenRouter.
# Caching headers and tiering strategy are managed by Indrajaal.AI.OpenRouterClient.
#
# ═════════════════════════════════════════════════════════════════════════════

config :indrajaal, :ai,
  openrouter_key: System.get_env("OPENROUTER_API_KEY"),
  site_url: System.get_env("SITE_URL", "https://indrajaal.dev"),
  app_name: "Indrajaal Security Monitoring System",
  budget_limit_daily: String.to_float(System.get_env("AI_BUDGET_LIMIT_DAILY", "2.0"))

# ═════════════════════════════════════════════════════════════════════════════
# Database and Application Configuration
# ═════════════════════════════════════════════════════════════════════════════

# Database configuration with proper defaults for container environment
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :indrajaal, Indrajaal.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: System.get_env("DATABASE_SSL", "true") == "true",
    ssl_opts: [
      verify: :verify_none
    ]

  # Guardian secret key for production
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :indrajaal, IndrajaalWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    live_view: [signing_salt: System.get_env("LV_SIGNING_SALT") || "sil6_prajna_lv_salt"]

  config :indrajaal, Indrajaal.Guardian,
    secret_key: System.get_env("GUARDIAN_SECRET_KEY") || secret_key_base
end

# ═════════════════════════════════════════════════════════════════════════════
# PHX_SERVER Support for Container Testing (SC-CNT-009)
# SC-FIX-008: Tailscale Node Names for Network Accessibility
# ═════════════════════════════════════════════════════════════════════════════
# When PHX_SERVER=true is set, explicitly enable the HTTP server.
# This is critical for container health probes in test environments.
# Tailscale DNS names provide secure, routable access across networks.
# ═════════════════════════════════════════════════════════════════════════════
if System.get_env("PHX_SERVER") == "true" do
  # Get Tailscale hostname or fall back to PHX_HOST
  phx_host =
    System.get_env("PHX_HOST") ||
      System.get_env("TAILSCALE_HOSTNAME") ||
      "localhost"

  config :indrajaal, IndrajaalWeb.Endpoint,
    server: true,
    check_origin: false,
    url: [host: phx_host, port: String.to_integer(System.get_env("PHX_PORT") || "4000")],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PHX_PORT") || "4000")]
end

# ═════════════════════════════════════════════════════════════════════════════
# Tailscale Configuration (SC-FIX-008)
# ═════════════════════════════════════════════════════════════════════════════
if System.get_env("TAILSCALE_ENABLED") == "true" do
  config :indrajaal, :tailscale,
    enabled: true,
    hostname: System.get_env("TAILSCALE_HOSTNAME"),
    dns_suffix: System.get_env("TAILSCALE_DNS_SUFFIX", "ts.net"),
    magic_dns: true
end

# Development and test configuration
if config_env() in [:dev, :test, :demo] do
  # Check for DATABASE_URL first (for container environments)
  if database_url = System.get_env("DATABASE_URL") do
    config :indrajaal, Indrajaal.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
  else
    # Fall back to individual environment variables
    config :indrajaal, Indrajaal.Repo,
      username: System.get_env("POSTGRES_USER", "postgres"),
      password: System.get_env("POSTGRES_PASSWORD", "postgres"),
      hostname: System.get_env("POSTGRES_HOST", "localhost"),
      port: String.to_integer(System.get_env("POSTGRES_PORT", "5433")),
      database: System.get_env("POSTGRES_DB", "indrajaal_#{config_env()}"),
      pool_size: 20,
      queue_target: 5000,
      queue_interval: 5000
  end
end

# ═════════════════════════════════════════════════════════════════════════════
# FLAME Elastic Compute Configuration (Stream Eta)
# ═════════════════════════════════════════════════════════════════════════════
#
# Configures the backend strategy for FLAME runners.
# - Dev/Test: Local backend (runs as separate OS process or beam node)
# - Prod: Kubernetes backend (spawns Pods)
#
# ═════════════════════════════════════════════════════════════════════════════

flame_backend =
  if config_env() == :prod do
    {FLAME.K8sBackend,
     runner_pod_tpl: [
       env: [
         {"RELEASE_DISTRIBUTION", "name"},
         {"RELEASE_NODE", {:from_env, "RELEASE_NODE"}}
       ]
     ]}
  else
    # In Dev/Test, we use the Local backend which spawns a system process
    # This simulates a remote node without needing K8s
    FLAME.Backend.Local
  end

# Apply backend to all pools by default
config :flame, :backend, flame_backend

# Specific Pool Configurations (if needed overrides)
config :indrajaal, Indrajaal.FLAME.IntelligencePool, backend: flame_backend

config :indrajaal, Indrajaal.FLAME.VideoPool, backend: flame_backend

config :indrajaal, Indrajaal.FLAME.AnalyticsPool, backend: flame_backend

# ═════════════════════════════════════════════════════════════════════════════
# CYBERNETIC SUPPORT INFRASTRUCTURE CONFIGURATION
# ═════════════════════════════════════════════════════════════════════════════

# Oban Configuration for Background Jobs
config :indrajaal, Oban,
  repo: Indrajaal.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10],
  notifier: Oban.Notifiers.Postgres

# Resource Monitoring Parameters
config :indrajaal, Indrajaal.System.ResourceMonitor,
  interval: String.to_integer(System.get_env("RESOURCE_MONITOR_INTERVAL", "5000")),
  thresholds: [
    cpu: String.to_integer(System.get_env("RESOURCE_THRESHOLD_CPU", "80")),
    memory: String.to_integer(System.get_env("RESOURCE_THRESHOLD_MEM", "85"))
  ]

# Elastic Compute Scaling (OODA "Act" phase tuning)
config :indrajaal, :elastic_compute,
  min_nodes: String.to_integer(System.get_env("FLAME_MIN_NODES", "0")),
  max_nodes: String.to_integer(System.get_env("FLAME_MAX_NODES", "10")),
  idle_timeout: String.to_integer(System.get_env("FLAME_IDLE_TIMEOUT", "30000"))

# ═══════════════════════════════════════════════════════════════════════════════
# CAE (CYBERNETIC AUTONOMIC ENGINE) - RUNTIME CONFIGURATION
# SC-CAE-RUN-001: Runtime environment variable overrides for CAE
# Enables dynamic CAE configuration without recompilation
# ═══════════════════════════════════════════════════════════════════════════════

# Helper function to parse CAE mode
parse_cae_mode = fn mode_string ->
  case mode_string do
    "disabled" -> :disabled
    "monitor_only" -> :monitor_only
    "semi_autonomous" -> :semi_autonomous
    "fully_autonomous" -> :fully_autonomous
    _ -> :semi_autonomous
  end
end

# CAE Master Switch - Runtime Override
cae_enabled = System.get_env("CAE_ENABLED", "true") == "true"
cae_mode = parse_cae_mode.(System.get_env("CAE_MODE", "fully_autonomous"))

config :indrajaal, :cae,
  enabled: cae_enabled,
  mode: cae_mode,
  target_readiness: String.to_float(System.get_env("CAE_TARGET_READINESS", "9.5")),
  safety_interlocks: System.get_env("CAE_SAFETY_INTERLOCKS", "true") == "true",
  max_autonomous_actions: String.to_integer(System.get_env("CAE_MAX_AUTONOMOUS_ACTIONS", "10"))

# FastOODA - Runtime Override
config :indrajaal, Indrajaal.Cortex.FastOODA,
  enabled: System.get_env("CAE_FAST_OODA_ENABLED", "true") == "true",
  interval_ms: String.to_integer(System.get_env("CAE_FAST_OODA_INTERVAL_MS", "30")),
  batch_size: String.to_integer(System.get_env("CAE_FAST_OODA_BATCH_SIZE", "200")),
  min_quality: String.to_integer(System.get_env("CAE_FAST_OODA_MIN_QUALITY", "90")),
  min_confidence: String.to_integer(System.get_env("CAE_FAST_OODA_MIN_CONFIDENCE", "80")),
  emergency_threshold:
    String.to_integer(System.get_env("CAE_FAST_OODA_EMERGENCY_THRESHOLD", "98")),
  metrics_enabled: System.get_env("CAE_FAST_OODA_METRICS", "true") == "true"

# Unified Control Bus - Runtime Override
config :indrajaal, Indrajaal.Control.UnifiedBus,
  enabled: System.get_env("CAE_CONTROL_BUS_ENABLED", "true") == "true",
  loops: [:ooda, :fast_ooda, :ace, :homeostasis, :gde],
  circuit_threshold:
    String.to_integer(System.get_env("CAE_CONTROL_BUS_CIRCUIT_THRESHOLD", "5000")),
  circuit_recovery_ms:
    String.to_integer(System.get_env("CAE_CONTROL_BUS_CIRCUIT_RECOVERY_MS", "2000")),
  priority_queue: System.get_env("CAE_CONTROL_BUS_PRIORITY_QUEUE", "true") == "true",
  max_queue_depth: String.to_integer(System.get_env("CAE_CONTROL_BUS_MAX_QUEUE_DEPTH", "50000"))

# GDE (Goal-Directed Evolution) - Runtime Override
config :indrajaal, Indrajaal.Cortex.Evolution.GDE,
  enabled: System.get_env("CAE_GDE_ENABLED", "true") == "true",
  auto_apply: System.get_env("CAE_GDE_AUTO_APPLY", "true") == "true",
  proposal_threshold: String.to_float(System.get_env("CAE_GDE_PROPOSAL_THRESHOLD", "0.90")),
  max_proposals_per_cycle:
    String.to_integer(System.get_env("CAE_GDE_MAX_PROPOSALS_PER_CYCLE", "5")),
  categories: [:performance, :reliability, :security, :efficiency],
  require_human_approval: [:security],
  cycle_interval_ms: String.to_integer(System.get_env("CAE_GDE_CYCLE_INTERVAL_MS", "60000"))

# Container Sensor Bridge - Runtime Override
config :indrajaal, Indrajaal.Cortex.Sensors.ContainerSensorBridge,
  enabled: System.get_env("CAE_SENSOR_BRIDGE_ENABLED", "true") == "true",
  poll_interval_ms: String.to_integer(System.get_env("CAE_SENSOR_BRIDGE_POLL_INTERVAL_MS", "50")),
  metrics: [:cpu, :memory, :io, :network, :health],
  containers: [],
  thresholds: %{
    cpu_percent: String.to_integer(System.get_env("CAE_SENSOR_THRESHOLD_CPU", "80")),
    memory_percent: String.to_integer(System.get_env("CAE_SENSOR_THRESHOLD_MEMORY", "85")),
    io_wait_ms: String.to_integer(System.get_env("CAE_SENSOR_THRESHOLD_IO_WAIT", "100")),
    network_latency_ms:
      String.to_integer(System.get_env("CAE_SENSOR_THRESHOLD_NETWORK_LATENCY", "50"))
  }

# ACE (Autonomic Computing Engine) - Runtime Override
config :indrajaal, Indrajaal.Cortex.ACE,
  enabled: System.get_env("CAE_ACE_ENABLED", "true") == "true",
  self_healing: System.get_env("CAE_ACE_SELF_HEALING", "true") == "true",
  self_optimization: System.get_env("CAE_ACE_SELF_OPTIMIZATION", "true") == "true",
  self_protection: System.get_env("CAE_ACE_SELF_PROTECTION", "true") == "true",
  self_configuration: System.get_env("CAE_ACE_SELF_CONFIGURATION", "false") == "true",
  healing_strategies: [:restart, :failover, :degrade],
  max_healing_attempts: String.to_integer(System.get_env("CAE_ACE_MAX_HEALING_ATTEMPTS", "3"))

# Homeostasis - Runtime Override
config :indrajaal, Indrajaal.Cortex.Homeostasis,
  enabled: System.get_env("CAE_HOMEOSTASIS_ENABLED", "true") == "true",
  targets: %{
    response_time_ms: {10, 50},
    error_rate_percent: {0, 1},
    throughput_rps: {100, 10_000},
    memory_percent: {20, 80},
    cpu_percent: {10, 70}
  },
  sensitivity: String.to_float(System.get_env("CAE_HOMEOSTASIS_SENSITIVITY", "0.5")),
  interval_ms: String.to_integer(System.get_env("CAE_HOMEOSTASIS_INTERVAL_MS", "1000"))

# Cortex State Machine - Runtime Override
config :indrajaal, Indrajaal.Cortex.StateMachine,
  enabled: System.get_env("CAE_STATE_MACHINE_ENABLED", "true") == "true",
  initial_state: :initializing,
  states: [:initializing, :observing, :orienting, :deciding, :acting, :recovering, :degraded],
  transition_timeout_ms:
    String.to_integer(System.get_env("CAE_STATE_MACHINE_TRANSITION_TIMEOUT_MS", "5000")),
  watchdog_enabled: System.get_env("CAE_STATE_MACHINE_WATCHDOG", "true") == "true",
  watchdog_interval_ms:
    String.to_integer(System.get_env("CAE_STATE_MACHINE_WATCHDOG_INTERVAL_MS", "10000"))

# CAE Telemetry - Runtime Override
config :indrajaal, :cae_telemetry,
  enabled: System.get_env("CAE_TELEMETRY_ENABLED", "true") == "true",
  prefix: [:indrajaal, :cae],
  events: [
    [:indrajaal, :cae, :ooda, :cycle],
    [:indrajaal, :cae, :gde, :proposal],
    [:indrajaal, :cae, :ace, :healing],
    [:indrajaal, :cae, :homeostasis, :adjustment],
    [:indrajaal, :cae, :control_bus, :event]
  ]

# ═══════════════════════════════════════════════════════════════════════════════
# ZENOH TELEMETRY - SC-ZENOH-001 to SC-ZENOH-008 (MANDATORY)
# Zenoh-based telemetry MUST be running on ALL nodes at ALL times
# ═══════════════════════════════════════════════════════════════════════════════
zenoh_enabled = System.get_env("ZENOH_ENABLED", "true") == "true"
zenoh_router_endpoint = System.get_env("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router:7447")
zenoh_mode = String.to_atom(System.get_env("ZENOH_MODE", "client"))

config :indrajaal, Indrajaal.Observability.ZenohSession,
  # SC-ZENOH-002: Zenoh router MUST be reachable from ALL app nodes
  connect: [zenoh_router_endpoint],
  mode: zenoh_mode,
  # Reconnection settings (SC-ZENOH-005)
  reconnect_delay_ms: String.to_integer(System.get_env("ZENOH_RECONNECT_DELAY_MS", "1000")),
  max_reconnect_attempts: String.to_integer(System.get_env("ZENOH_MAX_RECONNECT_ATTEMPTS", "10")),
  # SC-ZENOH-004: Telemetry publishing latency < 100ms
  publish_timeout_ms: 100,
  # Health monitoring (SC-ZENOH-007)
  health_check_interval_ms: 10_000,
  enabled: zenoh_enabled

# Zenoh Telemetry Subscriber - Runtime Override
config :indrajaal, Indrajaal.Observability.ZenohTelemetrySubscriber,
  enabled: zenoh_enabled,
  topics: [
    "indrajaal/health/**",
    "indrajaal/metrics/**",
    "indrajaal/logs/**",
    "indrajaal/cluster/**",
    "indrajaal/sentinel/**",
    "indrajaal/prajna/**"
  ]

# Quadplex Zenoh Channel - Runtime Override
config :indrajaal, :quadplex_zenoh,
  enabled: System.get_env("QUADPLEX_ZENOH", "true") == "true",
  topic: System.get_env("QUADPLEX_ZENOH_TOPIC", "indrajaal/logs/cluster/node-1"),
  # SC-IMMUNE-001: Enforce absolute control plane via biomorphic bus
  control_only: System.get_env("ZENOH_CONTROL_ONLY", "true") == "true"

# ═══════════════════════════════════════════════════════════════════════════════
# MCP (MODEL CONTEXT PROTOCOL) - SC-MCP-050 (MANDATORY)
# Primary control plane for intelligent agents (Claude, Gemini)
# ═══════════════════════════════════════════════════════════════════════════════
config :indrajaal, Indrajaal.MCP.Foundation.Server,
  transport: String.to_atom(System.get_env("MCP_TRANSPORT", "stdio")),
  port: String.to_integer(System.get_env("MCP_PORT", "9999")),
  enabled: System.get_env("MCP_ENABLED", "true") == "true"

# ═══════════════════════════════════════════════════════════════════════════════
# VISION HOLON (YOLO) - L1 Reflex Node
# ═══════════════════════════════════════════════════════════════════════════════
config :indrajaal, Indrajaal.Bio.Holon.Vision,
  # YOLO is disabled by default for CI/CD speed. To enable, set ENABLE_YOLO=true.
  enabled: System.get_env("ENABLE_YOLO", "false") == "true",
  model_path: System.get_env("YOLO_MODEL_PATH", "models/yolov8-weapons.onnx"),
  confidence_threshold: 0.85,
  # Accelerators: "cuda", "cpu", "tensorrt"
  accelerator: System.get_env("YOLO_ACCELERATOR", "cpu")
