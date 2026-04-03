import Config

# Ultra-fast development configuration for compilation testing
config :indrajaal, Indrajaal.Repo,
  pool_size: 1,
  timeout: 15_000

# Minimal logging
config :logger, level: :error

# Disable live reload
config :indrajaal, IndrajaalWeb.Endpoint, live_reload: [patterns: []]

# Phoenix optimizations
config :phoenix, :plug_init_mode, :runtime
