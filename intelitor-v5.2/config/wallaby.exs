# Wallaby E2E Testing Configuration for Indrajaal Security Platform
# Loaded conditionally when WALLABY_ENABLED=true or TEST_TYPE=e2e
# See config/test.exs for the conditional import

import Config

config :wallaby,
  driver: Wallaby.Chrome,
  chromedriver: [
    binary: System.get_env("WALLABY_CHROME_PATH", "google-chrome-unstable"),
    headless: System.get_env("WALLABY_HEADLESS", "true") == "true",

    # Chrome options for comprehensive testing
    args: [
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--disable-extensions",
      "--disable-web-security",
      "--window-size=1920,1080",
      "--user-agent=Wallaby/IndrajaalTest"
    ]
  ],

  # Base URL for the Phoenix test server (must match endpoint port below)
  base_url: "http://localhost:4050",

  # Screenshot configuration for failure analysis
  screenshot_on_failure: true,
  screenshot_dir: "test/wallaby/screenshots",

  # Performance and reliability settings
  default_max_wait_time: 30_000,
  js_errors: true,
  js_log_level: :severe,

  # Browser window configuration
  window_size: [width: 1920, height: 1080]

# Endpoint: server: true required for Wallaby browser to connect
config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4050],
  server: true,
  secret_key_base: "test_secret_key_base_for_wallaby_testing_only_not_for_production_use_ever",
  static_url: [host: "localhost", port: 4050],
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: false,
  check_origin: false

# Database configuration for Wallaby tests
config :indrajaal, Indrajaal.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  ownership_timeout: 600_000

# Disable Oban completely during E2E tests — Stager crashes without sandbox ownership
config :indrajaal, Oban,
  testing: :manual,
  crontab: false,
  queues: false,
  plugins: false

# Logger: reduce noise during E2E test runs
config :logger,
  level: :warning,
  backends: [:console]
