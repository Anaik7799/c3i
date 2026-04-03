import Config

# Minimal test configuration for faster compilation
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "indrajaal_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :indrajaal, IndrajaalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_key",
  server: false

config :logger, level: :warning

# Disable compile-time validations for faster compilation
config :ash,
  validate_domain_resource_inclusion?: false,
  validate_domain_config_inclusion?: false,
  compile_time_purge_level: :info

# Reduce compile-time checks
config :indrajaal,
  skip_compile_time_checks: true,
  minimal_compilation: true
