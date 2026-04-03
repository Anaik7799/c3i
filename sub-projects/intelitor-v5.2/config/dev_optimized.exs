import Config

# Import base dev config
import_config "dev.exs"

# Optimizations
config :ash,
  validate_domain_resource_inclusion?: false,
  validate_domain_config_inclusion?: false,
  compile_time_purge_level: :info

config :spark,
  formatter: [],
  disable_warnings?: true

config :logger, level: :warning
