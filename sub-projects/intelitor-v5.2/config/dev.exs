import Config

# Enable dev routes (LiveDashboard, Swoosh mailbox)
config :indrajaal, dev_routes: true

# ═══════════════════════════════════════════════════════════════════════════════
# Endpoint Configuration for Development
# SC-DEV-001: Development endpoint with required secrets
# ═══════════════════════════════════════════════════════════════════════════════
config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "QYxE3n7x8vR2K5m9J4tP1a6S8dF0gH2kL3nM5oP7qR9sT1uV3wX5yZ7bA9cD1eF3",
  live_view: [signing_salt: System.get_env("LV_SIGNING_SALT") || "dev_prajna_signing_salt"]

# Oban Configuration for Background Jobs
config :indrajaal, Oban,
  repo: Indrajaal.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

# ═══════════════════════════════════════════════════════════════════════════════
# CAE (CYBERNETIC AUTONOMIC ENGINE) - DEVELOPMENT OVERRIDES
# SC-CAE-DEV-001: Development-specific CAE configuration
# Enables verbose logging and relaxed thresholds for development
# ═══════════════════════════════════════════════════════════════════════════════

# CAE Master Switch - Development Mode
config :indrajaal, :cae,
  enabled: true,
  # Monitor-only mode for development (safer)
  mode: :monitor_only,
  target_readiness: 8.0,
  safety_interlocks: true,
  max_autonomous_actions: 3

# FastOODA - Relaxed for Development
config :indrajaal, Indrajaal.Cortex.FastOODA,
  enabled: true,
  # Slower cycle for development visibility
  interval_ms: 100,
  batch_size: 50,
  min_quality: 60,
  min_confidence: 50,
  emergency_threshold: 90,
  metrics_enabled: true

# Unified Control Bus - Development
config :indrajaal, Indrajaal.Control.UnifiedBus,
  enabled: true,
  loops: [:ooda, :fast_ooda, :ace, :homeostasis, :gde],
  # Lower threshold for dev
  circuit_threshold: 500,
  circuit_recovery_ms: 3000,
  priority_queue: true,
  max_queue_depth: 5_000

# GDE - Development Mode (No Auto-Apply)
config :indrajaal, Indrajaal.Cortex.Evolution.GDE,
  enabled: true,
  auto_apply: false,
  proposal_threshold: 0.70,
  max_proposals_per_cycle: 10,
  categories: [:performance, :reliability, :security, :efficiency],
  require_human_approval: [:security, :reliability],
  # Faster cycle for development
  cycle_interval_ms: 30_000

# Container Sensor Bridge - Development
config :indrajaal, Indrajaal.Cortex.Sensors.ContainerSensorBridge,
  enabled: true,
  # Slower polling for dev
  poll_interval_ms: 100,
  metrics: [:cpu, :memory, :io, :network, :health],
  containers: [],
  # Relaxed thresholds for dev
  thresholds: %{
    cpu_percent: 90,
    memory_percent: 95,
    io_wait_ms: 200,
    network_latency_ms: 100
  }

# ACE - Development (Self-healing only)
config :indrajaal, Indrajaal.Cortex.ACE,
  enabled: true,
  self_healing: true,
  self_optimization: false,
  self_protection: true,
  self_configuration: false,
  healing_strategies: [:restart, :degrade],
  max_healing_attempts: 5

# Homeostasis - Development (Wider ranges)
config :indrajaal, Indrajaal.Cortex.Homeostasis,
  enabled: true,
  targets: %{
    response_time_ms: {10, 200},
    error_rate_percent: {0, 5},
    throughput_rps: {10, 5_000},
    memory_percent: {10, 90},
    cpu_percent: {5, 85}
  },
  sensitivity: 0.3,
  interval_ms: 2000

# Cortex State Machine - Development
config :indrajaal, Indrajaal.Cortex.StateMachine,
  enabled: true,
  initial_state: :observing,
  states: [:initializing, :observing, :orienting, :deciding, :acting, :recovering, :degraded],
  transition_timeout_ms: 10_000,
  watchdog_enabled: true,
  watchdog_interval_ms: 30_000

# CAE Telemetry - Development (All events)
config :indrajaal, :cae_telemetry,
  enabled: true,
  prefix: [:indrajaal, :cae],
  events: [
    [:indrajaal, :cae, :ooda, :cycle],
    [:indrajaal, :cae, :gde, :proposal],
    [:indrajaal, :cae, :ace, :healing],
    [:indrajaal, :cae, :homeostasis, :adjustment],
    [:indrajaal, :cae, :control_bus, :event],
    # Additional dev events
    [:indrajaal, :cae, :state_machine, :transition],
    [:indrajaal, :cae, :sensor, :reading]
  ]
