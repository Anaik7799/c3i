import Config

# Core Test Configuration - NO Wallaby Dependencies
# Created: 2025-08-02 15:24:30 CEST
# Purpose: Enable core test execution without browser dependencies

# Import shared test configuration
Code.require_file("shared_test_config.exs", __DIR__)

# Database configuration with optimizations for test execution
config :indrajaal,
       Indrajaal.Repo,
       SharedTestConfig.database_config() ++
         [
           # Extended timeouts to ensure test completion
           ownership_timeout: 600_000,
           timeout: 300_000,
           connect_timeout: 300_000,
           handshake_timeout: 300_000,
           idle_interval: 10_000,
           queue_target: 500,
           queue_interval: 1000
         ]

# Phoenix endpoint configuration
config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: """
  test_secret_key_base_64_chars_long_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\
  xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\
  """,
  # No server needed for core tests
  server: false

# Disable Oban in tests
config :indrajaal, Oban,
  testing: :manual,
  crontab: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime
config :phoenix, :plug_init_mode, :runtime

# Speed up bcrypt for tests
config :bcrypt_elixir, :log_rounds, 1

# Disable telemetry and monitoring for core tests
config :telemetry, :disable_default_metrics, true

# ExUnit configuration with optimizations for completion guarantee
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 500,
  refute_receive_timeout: 100,
  # Optimize for maximum parallelization
  max_cases: System.schedulers_online() * 2,
  # 5 minutes per test
  timeout: 300_000,
  # Enable detailed failure reporting
  trace: false,
  exclude: [
    :skip,
    :pending,
    :wallaby,
    :e2e,
    :browser,
    :integration_browser
  ]

# NO Wallaby configuration - completely excluded
