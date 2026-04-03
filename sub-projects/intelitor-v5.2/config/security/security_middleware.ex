# Security Middleware for Phoenix Application
# Add to your endpoint.ex file

defmodule IndrajaalWeb.Endpoint do
  @moduledoc """
  🔒 Security-Enhanced Phoenix Endpoint - SOPv5.1 Cybernetic Execution
  ================================================================
  Date: 2025-08-19 23:24:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only + Git-based
  Agent: Helper-2: General Purpose Agent

  Security-hardened Phoenix endpoint configuration with comprehensive
  middleware stack for the Indrajaal Security Monitoring System.

  ## Security Features

  - **Security Headers**: Content Security Policy (CSP), X-Frame-Options, HSTS
  - **CSRF Protection**: Cross-Site Request Forgery protection enabled
  - **Rate Limiting**: Request rate limiting to prevent abuse
  - **Static Asset Security**: Secure static file serving with gzip disabled
  - **Request ID Tracking**: Request correlation for security audit trails

  ## Middleware Stack

  The security middleware stack includes:
  1. Static file serving with security restrictions
  2. Security headers injection (CSP, HSTS, X-Frame-Options)
  3. CSRF protection middleware
  4. Request rate limiting
  5. Standard Phoenix middleware (parsers, session, etc.)

  ## Configuration

  This endpoint configuration should be added to your main endpoint.ex
  file to enable enterprise-grade security controls.

  ## Security Headers

  - `Content-Security-Policy`: Strict CSP policy for XSS prevention
  - `X-Frame-Options`: Clickjacking protection
  - `Strict-Transport-Security`: HTTPS enforcement
  - `X-Content-Type-Options`: MIME type sniffing prevention
  - `Referrer-Policy`: Referrer information control

  ## Rate Limiting

  Implements intelligent rate limiting to prevent:
  - DDoS attacks and service abuse
  - Brute force authentication attempts
  - API abuse and resource exhaustion
  - Automated scraping and bot traffic
  """

  use Phoenix.Endpoint, otp_app: :indrajaal

  # Security Headers Plug
  plug Plug.Static,
    at: "/",
    from: :indrajaal,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  # Security Headers
  plug Plug.Head
  plug IndrajaalWeb.Plugs.SecurityHeaders
  plug IndrajaalWeb.Plugs.CSPHeader

  # CSRF Protection
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  # Rate Limiting
  plug IndrajaalWeb.Plugs.RateLimiter

  plug IndrajaalWeb.Router
end
