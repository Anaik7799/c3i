# Standalone Configuration for CEPAF and Cockpit Testing
# Usage: MIX_ENV=standalone mix phx.server
#
# WHAT: Minimal configuration for standalone testing
# WHY: Enable isolated testing of CEPAF and Prajna Cockpit
# CONSTRAINTS: Requires PostgreSQL on port 5433

import Config

# ============================================================
# STANDALONE MODE CONFIGURATION
# ============================================================

config :indrajaal,
  standalone_mode: true,
  prajna_cockpit_enabled: true,
  env: :standalone

# ============================================================
# DATABASE CONFIGURATION
# ============================================================

config :indrajaal, Indrajaal.Repo,
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  database: System.get_env("DB_NAME", "indrajaal_standalone"),
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true

# ============================================================
# WEB ENDPOINT CONFIGURATION
# ============================================================

config :indrajaal_web, IndrajaalWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PHX_PORT", "4001")),
    transport_options: [socket_opts: [:inet6]]
  ],
  server: true,
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: [],
  live_view: [signing_salt: "standalone_test_#{:crypto.strong_rand_bytes(8) |> Base.encode64()}"]

config :indrajaal_web, IndrajaalWeb.Endpoint,
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "standalone_test_secret_#{:crypto.strong_rand_bytes(32) |> Base.encode64()}"
    )

# ============================================================
# PRAJNA COCKPIT CONFIGURATION
# ============================================================

config :indrajaal, Indrajaal.Cockpit.Prajna,
  enabled: true,
  dark_cockpit_mode: true,
  ai_copilot_enabled: true,
  openrouter_model: "anthropic/claude-3.5-sonnet"

# ============================================================
# CORTEX CONFIGURATION (Disabled for Standalone)
# ============================================================

config :indrajaal, Indrajaal.Cortex,
  enabled: false,
  fast_ooda_enabled: false,
  synapse_enabled: false

# ============================================================
# OBSERVABILITY (Minimal)
# ============================================================

config :indrajaal, Indrajaal.Observability,
  fractal_logging_enabled: true,
  zenoh_enabled: false,
  otel_enabled: false

# ============================================================
# LOGGER CONFIGURATION
# ============================================================

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module],
  level: :info
