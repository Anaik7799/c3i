import Config

# Enable demo routes for comprehensive demonstration
config :indrajaal, demo_routes: true

# Demo Database configuration - Isolated demo database
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "indrajaal_demo",
  port: 5433,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 15,
  # Demo-specific optimizations
  queue_target: 5000,
  queue_interval: 5000,
  timeout: 30_000,
  ownership_timeout: 60_000

# Phoenix endpoint configuration for demo
config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: """
  demo_secret_key_base_64_chars_long_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\
  xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\
  """,
  # Demo-specific watchers disabled for performance
  watchers: []

# Demo logging configuration with enhanced metadata
config :logger, :console,
  format: "[DEMO][$level] $message\n",
  metadata: [
    :request_id,
    :tenant_id,
    :trace_id,
    :span_id,
    :user_id,
    :actor_id,
    :demo_scenario,
    :demo_category,
    :demo_execution_id,
    :performance_metrics
  ]

# Demo-specific configurations
config :indrajaal,
  demo_mode: true,
  demo_data_enabled: true,
  demo_tenants: ["enterprise_demo", "security_demo", "mobile_demo"],
  demo_users: 100,
  demo_devices: 500,
  demo_alarms: 1000

# Enable OpenTelemetry tracing for demo (observability and monitoring)
config :opentelemetry,
  span_processor: :simple,
  traces_exporter: :console

# OpenTelemetry service identification for demo
config :opentelemetry, :resource,
  service: [
    name: "indrajaal-demo",
    version: "21.3.0"
  ]

# Import SSL configuration for container deployment
if System.get_env("CONTAINER_ENFORCEMENT") == "true" do
  import_config "ssl_container.exs"
end

# Demo cache configuration
config :indrajaal, :demo_cache,
  # 5 minutes
  ttl: 300_000,
  size_limit: 10_000

# Demo performance configurations
config :phoenix, :plug_init_mode, :runtime

# Demo-specific Swoosh configuration
config :swoosh, :api_client, false

# Demo session configuration
config :indrajaal,
       IndrajaalWeb.Endpoint,
       live_view: [signing_salt: "demo_signing_salt"]

# Demo asset configuration (optimized for demo scenarios)
config :esbuild,
  version: "0.21.5",
  indrajaal: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

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
