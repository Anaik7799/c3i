import Config

# Import everything from test.exs except Wallaby configuration
import_config "test.exs"

# Override to ensure Wallaby is not configured
config :wallaby, enabled: false
