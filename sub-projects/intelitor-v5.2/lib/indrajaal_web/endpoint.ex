defmodule IndrajaalWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :indrajaal

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_indrajaal_key",
    signing_salt: "PEcGU1iD",
    same_site: "Lax"
  ]

  socket "/live",
         Phoenix.LiveView.Socket,
         websocket: [connect_info: [session: @session_options]]

  # Health checks for container orchestration (Liveness & Readiness)
  plug IndrajaalWeb.Plugs.HealthPlug

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :indrajaal,
    gzip: false,
    only: IndrajaalWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "__request_logger",
    cookie_key: "__request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # OpenTelemetry __context for distributed tracing
  plug IndrajaalWeb.Plugs.OpenTelemetryContext

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug IndrajaalWeb.Router

  @spec static_paths() :: [String.t()]
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
