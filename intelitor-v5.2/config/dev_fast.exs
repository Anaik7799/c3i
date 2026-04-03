import Config

# Fast development configuration for quicker compilation
config :indrajaal, Indrajaal.Repo,
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5433")),
  database: System.get_env("DB_NAME", "indrajaal_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "jZH5h5KVxF1yFjR4HmXs4xPf7H7PPTqmaKUBqMGUEMTmLUGQa6M9SJkLBKL6SiEB",
  watchers: []

# Disable compile-time validations for much faster compilation
config :ash,
  validate_domain_resource_inclusion?: false,
  validate_domain_config_inclusion?: false,
  disable_async?: false,
  compile_time_purge_level: :info

# Use minimal configuration to speed up compilation
config :indrajaal,
  skip_compile_time_checks: true,
  minimal_compilation: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :tenant_id,
    :trace_id,
    :span_id,
    :user_id,
    :actor_id,
    :span_name,
    :error_type,
    :error_message,
    :attributes,
    :operation,
    :success,
    :resource,
    :action,
    :result_id,
    :event,
    :alarm_id,
    :incident_type,
    :severity,
    :measurements,
    :metadata,
    :camera_id,
    :device_id,
    :device_type,
    :error,
    :source,
    :query,
    :kind,
    :reason,
    :duration_ms,
    :method,
    :path_info,
    :remote_ip,
    :job_id,
    :worker,
    :queue,
    :attempt,
    :status,
    :context,
    :importance,
    :resource_id,
    :impact,
    :timestamp,
    :filter_count,
    :sort_count,
    :error_fields,
    :business_context,
    :error_class,
    :error_details,
    :actor_type,
    :changes,
    :old_values,
    :new_values,
    :component,
    :event_type,
    :metric_value,
    :threshold,
    :framework,
    :requirement_id,
    :result,
    :location_id,
    :reader_id,
    :stream_type,
    :resolution,
    :codec,
    :node,
    :memory_usage,
    :cpu_usage,
    :disk_usage,
    :ip_address,
    :user_agent,
    :session_id
  ]

config :logger, level: :info

# Disable Ash warnings during compilation
config :spark,
  formatter: [],
  disable_warnings?: true

# LiveView configuration
config :indrajaal,
       IndrajaalWeb.Endpoint,
       live_view: [signing_salt: "dev_only_salt"]

# Session configuration
config :indrajaal, :session_signing_salt, "dev_only_session_salt"

# Guardian configuration for dev
config :indrajaal, Indrajaal.Guardian,
  issuer: "indrajaal",
  secret_key: "dev_only_secret_key_change_in_production"

# Phoenix LiveDashboard
config :phoenix_live_dashboard,
  metrics_history: [buffer_size: 50]
