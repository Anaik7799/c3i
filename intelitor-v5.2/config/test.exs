import Config

# We don't want ExUnit to try to manage the database schema
# as the database is running in a separate container.
config :indrajaal, ecto_repos: [Indrajaal.Repo]
config :ex_unit, manage_ecto_schema: false

# Endpoint configuration for testing (required for LiveView tests)
config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test_secret_key_base_that_is_at_least_64_characters_long_for_testing_purposes_only",
  server: false,
  force_ssl: false,
  live_view: [signing_salt: "test_prajna_liveview_signing_salt"]

# Database configuration for test environment
# Uses the containerized PostgreSQL on port 5433
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "indrajaal_test",
  port: 5433,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Oban Configuration for Background Jobs - disabled for testing
config :indrajaal, Oban,
  testing: :inline,
  repo: Indrajaal.Repo,
  queues: false,
  plugins: false

# libcluster Configuration for Testing
# SC-CLU-TEST-001: Test-specific cluster topology
config :libcluster,
  topologies: [
    k8s_cluster: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: "indrajaal-headless",
        application_name: "indrajaal",
        polling_interval: 5_000
      ]
    ]
  ]

# ═══════════════════════════════════════════════════════════════════════════════
# CAE (CYBERNETIC AUTONOMIC ENGINE) - TEST CONFIGURATION
# SC-CAE-TEST-001: Test-specific CAE configuration
# Disables autonomous behavior for deterministic testing
# ═══════════════════════════════════════════════════════════════════════════════

# CAE Master Switch - Disabled for Testing
# SC-CAE-TEST-002: Autonomous features must be disabled in test mode
config :indrajaal, :cae,
  enabled: false,
  mode: :disabled,
  target_readiness: 0.0,
  safety_interlocks: true,
  max_autonomous_actions: 0

# FastOODA - Disabled for Testing
config :indrajaal, Indrajaal.Cortex.FastOODA,
  enabled: false,
  interval_ms: 1000,
  batch_size: 10,
  min_quality: 100,
  min_confidence: 100,
  emergency_threshold: 100,
  metrics_enabled: false

# Unified Control Bus - Disabled for Testing
config :indrajaal, Indrajaal.Control.UnifiedBus,
  enabled: false,
  loops: [],
  circuit_threshold: 100,
  circuit_recovery_ms: 1000,
  priority_queue: false,
  max_queue_depth: 100

# GDE - Disabled for Testing
config :indrajaal, Indrajaal.Cortex.Evolution.GDE,
  enabled: false,
  auto_apply: false,
  proposal_threshold: 1.0,
  max_proposals_per_cycle: 0,
  categories: [],
  require_human_approval: [:security, :reliability, :performance, :efficiency],
  cycle_interval_ms: 3_600_000

# Container Sensor Bridge - Disabled for Testing
config :indrajaal, Indrajaal.Cortex.Sensors.ContainerSensorBridge,
  enabled: false,
  poll_interval_ms: 10_000,
  metrics: [],
  containers: [],
  thresholds: %{
    cpu_percent: 100,
    memory_percent: 100,
    io_wait_ms: 10_000,
    network_latency_ms: 10_000
  }

# ACE - Disabled for Testing
config :indrajaal, Indrajaal.Cortex.ACE,
  enabled: false,
  self_healing: false,
  self_optimization: false,
  self_protection: false,
  self_configuration: false,
  healing_strategies: [],
  max_healing_attempts: 0

# Homeostasis - Disabled for Testing
config :indrajaal, Indrajaal.Cortex.Homeostasis,
  enabled: false,
  targets: %{
    response_time_ms: {0, 10_000},
    error_rate_percent: {0, 100},
    throughput_rps: {0, 100_000},
    memory_percent: {0, 100},
    cpu_percent: {0, 100}
  },
  sensitivity: 0.0,
  interval_ms: 60_000

# Cortex State Machine - Minimal for Testing
config :indrajaal, Indrajaal.Cortex.StateMachine,
  enabled: false,
  initial_state: :disabled,
  states: [:disabled],
  transition_timeout_ms: 60_000,
  watchdog_enabled: false,
  watchdog_interval_ms: 3_600_000

# CAE Telemetry - Minimal for Testing
config :indrajaal, :cae_telemetry,
  enabled: false,
  prefix: [:indrajaal, :cae, :test],
  events: []

# STAMP / TDG / GDE Monitoring Configuration - for Testing
config :indrajaal, :stamp_tdg_gde_monitoring,
  alerts_enabled: true,
  dashboard_port: 4052,
  export_formats: [:json, :prometheus],
  retention_days: 30,
  sample_interval_ms: 1000

# ═══════════════════════════════════════════════════════════════════════════════
# DIRECTED TELESCOPE OBSERVABILITY - TEST CONFIGURATION
# SC-OBS-DT-007: Log noise < 1000 lines for unit test run
# SC-OBS-DT-008: Test output visibility > 90%
# ═══════════════════════════════════════════════════════════════════════════════

# Logger Configuration for Test Environment
# Reduces log noise to ensure test output visibility
config :logger,
  level: :warning,
  compile_time_purge_matching: [
    [level_lower_than: :warning]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Directed Telescope - Test Mode Profile
config :indrajaal, Indrajaal.Observability.DirectedTelescopeController,
  default_context: :unit_test,
  enable_auto_detection: true,
  critical_sources: [
    "Guardian",
    "Constitutional",
    "ImmutableRegister",
    "Sentinel",
    "FPPS",
    "FounderDirective"
  ]

# Degraded Mode Coordinator - Test Configuration
# Enters silent mode immediately for missing infrastructure
config :indrajaal, Indrajaal.Observability.DegradedModeCoordinator,
  initial_backoff_ms: 60_000,
  max_backoff_ms: 300_000,
  silence_threshold: 1,
  enable_health_checks: false

# Watchdog - Disabled for Testing
config :indrajaal, Indrajaal.Cockpit.Prajna.Watchdog,
  enabled: false,
  heartbeat_timeout_ms: :infinity,
  check_interval_ms: :infinity

# Mara Chaos Testing - Disabled for Unit Tests
config :indrajaal, Indrajaal.Safety.Mara, enabled: false

# libcluster - Disabled for Unit Tests (prevents nxdomain errors)
config :libcluster,
  topologies: []

# ═══════════════════════════════════════════════════════════════════════════════
# PRAJNA COCKPIT - TEST CONFIGURATION
# SC-TEST-PRAJNA-001: Use test-specific DuckDB paths to avoid lock conflicts
# SC-TEST-PRAJNA-002: Disable startup verification for faster test execution
# ═══════════════════════════════════════════════════════════════════════════════

config :indrajaal, Indrajaal.Cockpit.Prajna.Config,
  immutable_state_verify_on_startup: false,
  # Use /tmp for test isolation to avoid DuckDB lock conflicts with dev/prod
  # The path is fixed per environment, cleaned up by test runner
  immutable_state_duckdb_path: "/tmp/indrajaal_test_prajna_register.duckdb",
  fail_closed_mode: false,
  guardian_timeout_ms: 1_000,
  sentinel_sync_interval_ms: 5_000,
  smart_metrics_interval_ms: 200,
  ooda_cycle_ms: 10_000,
  dashboard_refresh_ms: 5_000

# ═══════════════════════════════════════════════════════════════════════════════
# WALLABY E2E — Conditional import (SC-COV-008)
# Only loaded when WALLABY_ENABLED=true or TEST_TYPE=e2e
# Overrides server: false → true and sets port 4002
# ═══════════════════════════════════════════════════════════════════════════════
if System.get_env("WALLABY_ENABLED") == "true" or
     System.get_env("TEST_TYPE") == "e2e" do
  import_config "wallaby.exs"
end
