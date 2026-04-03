# ═════════════════════════════════════════════════════════════════════════════
# SOPv5.1 ENHANCED ENVIRONMENT CONFIGURATION - config.exs
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

config :indrajaal,
  ecto_repos: [Indrajaal.Repo],
  generators: [timestamp_type: :utc_datetime],
  # Fractal Logging: :l1=debug, :l2=trace, :l3=info, :l4=warn, :l5=critical
  fractal_default_level: :l4

# Phoenix configuration
config :indrajaal, IndrajaalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IndrajaalWeb.ErrorHTML, json: IndrajaalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Indrajaal.PubSub

# live_view signing_salt is configured in runtime.exs using environment variables

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  indrajaal: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.4.0",
  indrajaal: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Ash configuration with compilation performance optimizations
config :ash,
  include_embedded_source_by_default?: false,
  default_page_type: :keyset,
  policies: [
    no_filter_static_forbidden_reads?: false,
    default: :strict
  ],
  # COMPILATION PERFORMANCE OPTIMIZATIONS
  validate_domain_resource_inclusion?: false,
  validate_domain_config_inclusion?: false,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ],
  disable_async?: false,
  # Reduce compilation overhead
  default_timeout: 30_000,
  # Optimize DSL processing
  optimize_attribute_compilation?: true

# Ash domains
config :indrajaal,
  ash_domains: [
    Indrajaal.Core,
    Indrajaal.Accounts,
    Indrajaal.Policy,
    Indrajaal.Sites,
    Indrajaal.AccessControlDomain,
    Indrajaal.Analytics,
    Indrajaal.GuardTour,
    Indrajaal.CommunicationDomain,
    Indrajaal.AssetManagement,
    Indrajaal.RiskManagement,
    Indrajaal.VisitorManagement,
    Indrajaal.Devices,
    Indrajaal.Alarms,
    Indrajaal.Video,
    Indrajaal.Dispatch,
    Indrajaal.Maintenance,
    Indrajaal.ComplianceDomain,
    Indrajaal.Billing,
    Indrajaal.Integrations
  ]

# Guardian configuration
# Note: Actual configuration is in runtime.exs for security
config :indrajaal, Indrajaal.Guardian, issuer: "indrajaal"
# secret_key is configured in runtime.exs using environment variables

# Oban configuration
config :indrajaal, Oban,
  repo: Indrajaal.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, events: 50, video: 5]

# OpenTelemetry configuration with enhanced SigNoz integration
# STAMP: Comprehensive safety constraint validation for observability
# TDG: All telemetry modules tested before implementation
# GDE: Goal-directed metrics collection for business impact
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  # STAMP: Prevent trace data loss (SC1)
  shutdown_timeout: 30_000

config :opentelemetry, :resource,
  service: [
    name: "indrajaal",
    version: "21.3.0",
    namespace: "production",
    instance_id: "#{node()}"
  ],
  attributes: [
    {"deployment.environment", "production"},
    {"service.framework", "elixir-phoenix-ash"},
    {"service.capabilities", "security-monitoring"},
    {"signoz.integration", "enabled"}
  ]

# OpenTelemetry instrumentation libraries
config :opentelemetry_phoenix,
  endpoint_prefix: [:indrajaal, :endpoint],
  # STAMP: Include all request metadata for security analysis
  record_headers: true

config :opentelemetry_ecto,
  db_statement: :enabled,
  # TDG: Track all database operations for performance
  time_unit: :microsecond

config :opentelemetry_oban,
  # GDE: Monitor job execution for SLA compliance
  trace_all_jobs: true,
  record_job_args: true

# Custom Ash OpenTelemetry integration (until official package available)
config :indrajaal, :ash_telemetry,
  enabled: true,
  # STAMP: Track all resource operations for audit
  trace_all_actions: true,
  include_metadata: true,
  # TDG: Performance thresholds validated by tests
  slow_query_threshold: 100

# Logging Control Configuration (Logging Optimization)
config :indrajaal, :logging_control,
  global_level: :info,
  subsystems: %{
    cortex_ooda: %{
      level: :info,
      sampling_rate: 1000
    },
    flame_runner: %{
      sampling_rate: 10
    },
    # Fractal Logging Extension
    business_event: %{
      level: :info,
      # Default: Log all business events
      sampling_rate: 1
    },
    security_event: %{
      level: :info,
      # CRITICAL: SC-LOG-004 Log all security events by default
      sampling_rate: 1
    },
    performance_metric: %{
      level: :info,
      # Sample high-volume performance metrics
      sampling_rate: 100
    },
    phoenix_request: %{
      sampling_rate: 10
    },
    ecto_query: %{
      sampling_rate: 50
    },
    oban_job: %{
      sampling_rate: 1
    }
  }

# Logger configuration with TRIPLE logging (Console + SigNoz + TimescaleDB)
# MANDATORY: All three logging backends must be active for complete observability
# TDG: Configuration validated by tests before implementation
config :logger,
  backends: [:console, LoggerJSON],
  # STAMP: Prevent log overflow
  truncate: 8192,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

# Console backend configuration for development visibility
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: :all

# LoggerJSON backend configuration for structured logging to SigNoz
# MANDATORY: Required for dual logging compliance and SigNoz integration
config :logger_json, :backend,
  formatter: LoggerJSON.Formatters.Datadog,
  metadata: :all

# TimescaleDB logger backend configuration
# Part of triple logging strategy (Console + SigNoz + TimescaleDB)
config :indrajaal, Indrajaal.Timescale.LoggerBackend,
  level: :info,
  # Log events to TimescaleDB for long-term storage and analysis
  enabled: true,
  # Batch configuration for performance
  batch_size: 100,
  batch_timeout: 1_000

# OpenTelemetry Exporter configuration
# MANDATORY: Required for trace export to SigNoz
config :opentelemetry_exporter,
  otlp: [
    # Endpoint will be configured via environment variable in runtime.exs
    compression: :gzip,
    # Headers can be configured for authentication if needed
    headers: []
  ]

# Trace context propagation configuration
# STAMP: Ensure trace context is preserved across service boundaries (SC3)
config :opentelemetry,
  propagators: [:tracecontext, :baggage],
  # Default sampler - can be overridden via environment variables
  sampler: {:always_on, []}

# ═══════════════════════════════════════════════════════════════════════════════
# ZENOH CONFIGURATION (SC-ZENOH-INT-001)
# Native pub/sub messaging for fractal logging and bidirectional telemetry
# Enables real-time connectivity between Indrajaal and CEPAF F# cockpit
# ═══════════════════════════════════════════════════════════════════════════════
config :indrajaal, Indrajaal.Observability.ZenohSession,
  # Connection to Zenoh router - configured via environment in runtime.exs
  connect: ["tcp/zenoh:7447"],
  mode: :client,
  # Reconnection settings (SC-ZENOH-SES-002)
  reconnect_delay_ms: 1_000,
  max_reconnect_attempts: 5,
  # Health monitoring (SC-ZENOH-SES-001)
  health_check_interval_ms: 10_000

config :indrajaal, Indrajaal.Observability.ZenohFractalPublisher,
  enabled: true,
  # Batching for efficiency
  batch_size: 100,
  flush_interval_ms: 100,
  # Key expression prefix for all fractal logs
  key_prefix: "indrajaal/fractal",
  # Route all levels to Zenoh (L1-L5)
  levels: [:l1, :l2, :l3, :l4, :l5]

config :indrajaal, Indrajaal.Observability.ZenohTelemetryPublisher,
  enabled: true,
  key_prefix: "indrajaal/telemetry/elixir",
  # Metrics aggregation interval (ms)
  aggregation_interval_ms: 1_000

config :indrajaal, Indrajaal.Observability.ZenohKpiPublisher,
  enabled: true,
  key_prefix: "indrajaal/kpi",
  # KPI publishing interval (ms)
  publish_interval_ms: 5_000

config :indrajaal, Indrajaal.Observability.ZenohControlSubscriber,
  enabled: true,
  # Subscribe to control commands from F# cockpit
  key_expr: "indrajaal/control/**"

# ═══════════════════════════════════════════════════════════════════════════════
# CAE (CYBERNETIC AUTONOMIC ENGINE) CONFIGURATION
# STAMP: SC-CAE-001 through SC-CAE-010
# Enables autonomous system operation with safety constraints
# ═══════════════════════════════════════════════════════════════════════════════

# CAE Master Switch (SC-CAE-001)
# Controls global enablement of the Cybernetic Autonomic Engine
config :indrajaal, :cae,
  enabled: true,
  # Mode: :disabled | :monitor_only | :semi_autonomous | :fully_autonomous
  mode: :semi_autonomous,
  # Target readiness score (0.0 - 10.0)
  target_readiness: 9.5,
  # Safety interlocks (SC-CAE-002)
  safety_interlocks: true,
  # Maximum autonomous actions per cycle
  max_autonomous_actions: 5

# FastOODA Configuration (SC-CAE-003)
# High-frequency observe-orient-decide-act loop for real-time response
config :indrajaal, Indrajaal.Cortex.FastOODA,
  enabled: true,
  # OODA cycle interval in milliseconds (SC-PRF-050: Response <50ms)
  interval_ms: 50,
  # Maximum events per batch
  batch_size: 100,
  # Minimum quality threshold for decisions (0-100)
  min_quality: 80,
  # Minimum confidence threshold for actions (0-100)
  min_confidence: 70,
  # Emergency bypass threshold (immediate action)
  emergency_threshold: 95,
  # Metrics collection
  metrics_enabled: true

# Unified Control Bus Configuration (SC-CAE-004)
# Coordinates all control loops in the system
config :indrajaal, Indrajaal.Control.UnifiedBus,
  enabled: true,
  # Active control loops
  loops: [:ooda, :fast_ooda, :ace, :homeostasis, :gde],
  # Circuit breaker threshold (events/second)
  circuit_threshold: 1000,
  # Circuit breaker recovery time (ms)
  circuit_recovery_ms: 5000,
  # Priority queue enabled
  priority_queue: true,
  # Maximum queue depth before backpressure
  max_queue_depth: 10_000

# GDE (Goal-Directed Evolution) Activation (SC-CAE-005)
# Enables autonomous system improvement proposals
config :indrajaal, Indrajaal.Cortex.Evolution.GDE,
  enabled: true,
  # Auto-apply approved proposals (requires semi_autonomous or fully_autonomous mode)
  auto_apply: false,
  # Minimum proposal confidence threshold (0.0-1.0)
  proposal_threshold: 0.85,
  # Maximum proposals per evolution cycle
  max_proposals_per_cycle: 5,
  # Proposal categories
  categories: [:performance, :reliability, :security, :efficiency],
  # Human approval required for these categories
  require_human_approval: [:security],
  # Evolution cycle interval (ms)
  cycle_interval_ms: 60_000

# Container Sensor Bridge Configuration (SC-CAE-006)
# Bridges container metrics to the autonomic system
config :indrajaal, Indrajaal.Cortex.Sensors.ContainerSensorBridge,
  enabled: true,
  # Polling interval (SC-PRF-050: aligned with FastOODA)
  poll_interval_ms: 50,
  # Metrics to collect
  metrics: [:cpu, :memory, :io, :network, :health],
  # Container targets (auto-discovered if empty)
  containers: [],
  # Alert thresholds
  thresholds: %{
    cpu_percent: 80,
    memory_percent: 85,
    io_wait_ms: 100,
    network_latency_ms: 50
  }

# ACE (Autonomic Computing Engine) Configuration (SC-CAE-007)
# Self-management capabilities for the system
config :indrajaal, Indrajaal.Cortex.ACE,
  enabled: true,
  # Self-healing enabled
  self_healing: true,
  # Self-optimization enabled
  self_optimization: true,
  # Self-protection enabled
  self_protection: true,
  # Self-configuration enabled
  self_configuration: false,
  # Healing strategies
  healing_strategies: [:restart, :failover, :degrade],
  # Maximum healing attempts before escalation
  max_healing_attempts: 3

# Homeostasis Configuration (SC-CAE-008)
# Maintains system equilibrium
config :indrajaal, Indrajaal.Cortex.Homeostasis,
  enabled: true,
  # Target equilibrium ranges
  targets: %{
    response_time_ms: {10, 50},
    error_rate_percent: {0, 1},
    throughput_rps: {100, 10_000},
    memory_percent: {20, 80},
    cpu_percent: {10, 70}
  },
  # Adjustment sensitivity (0.0-1.0)
  sensitivity: 0.5,
  # Adjustment interval (ms)
  interval_ms: 1000

# Cortex State Machine Configuration (SC-CAE-009)
# Central coordinator for autonomic behaviors
config :indrajaal, Indrajaal.Cortex.StateMachine,
  enabled: true,
  # Initial state
  initial_state: :initializing,
  # Valid states
  states: [:initializing, :observing, :orienting, :deciding, :acting, :recovering, :degraded],
  # State transition timeout (ms)
  transition_timeout_ms: 5000,
  # Watchdog enabled
  watchdog_enabled: true,
  # Watchdog interval (ms)
  watchdog_interval_ms: 10_000

# Telemetry Integration for CAE (SC-CAE-010)
# Ensures observability of autonomic operations
config :indrajaal, :cae_telemetry,
  enabled: true,
  # Metrics prefix
  prefix: [:indrajaal, :cae],
  # Events to track
  events: [
    [:indrajaal, :cae, :ooda, :cycle],
    [:indrajaal, :cae, :gde, :proposal],
    [:indrajaal, :cae, :ace, :healing],
    [:indrajaal, :cae, :homeostasis, :adjustment],
    [:indrajaal, :cae, :control_bus, :event]
  ]

# TPS 5-Level RCA Fix (2025-11-29): Added missing import_config statement
# Root Cause: dev.exs was never being loaded because import_config was missing
# This line MUST be at the end of config.exs to load environment-specific configs
import_config "#{config_env()}.exs"
