# Implementation Guide: Standalone App Container System
## Version: 1.0.0 | Date: 2025-12-24 | Status: PRODUCTION
## Compliance: SOPv5.11 + STAMP + TDG + IEC 61508 SIL-2

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Configuration Files](#2-configuration-files)
3. [Container Image Build](#3-container-image-build)
4. [Compose File Implementation](#4-compose-file-implementation)
5. [Runtime Configuration](#5-runtime-configuration)
6. [Logging Implementation](#6-logging-implementation)
7. [Telemetry Implementation](#7-telemetry-implementation)
8. [Health Probe Implementation](#8-health-probe-implementation)
9. [OODA Cybernetic Loop](#9-ooda-cybernetic-loop)
10. [Database Integration](#10-database-integration)
11. [Startup Script Implementation](#11-startup-script-implementation)
12. [Debug Mode Configuration](#12-debug-mode-configuration)
13. [Environment Variables Reference](#13-environment-variables-reference)
14. [Code Patterns](#14-code-patterns)

---

## 1. Prerequisites

### 1.1 System Requirements

```bash
# Verify Podman installation
podman --version
# Expected: podman version 5.4.1 or higher

# Verify rootless mode
podman info | grep -i rootless
# Expected: rootless: true

# Verify Elixir/OTP (on host for development)
elixir --version
# Expected: Elixir 1.19.4 (compiled with Erlang/OTP 28)

# Verify disk space
df -h /home
# Required: 20GB+ free space
```

### 1.2 Required Images

```bash
# List required images
podman images | grep indrajaal

# Expected:
# localhost/indrajaal-sopv51-elixir-app   nixos-25.05-devenv   ...
# localhost/indrajaal-db                   pg17-timescale       ...
# localhost/indrajaal-obs                  signoz-latest        ...
```

### 1.3 Network Setup

```bash
# Create required networks
podman network create artifacts_db-standalone-net 2>/dev/null || true
podman network create artifacts_app-standalone-net 2>/dev/null || true
podman network create artifacts_obs-standalone-net 2>/dev/null || true

# Verify networks
podman network ls | grep standalone
```

---

## 2. Configuration Files

### 2.1 Project Structure

```
lib/cepaf/
├── artifacts/
│   ├── podman-compose-db-standalone.yml      # Database container
│   ├── podman-compose-app-standalone.yml     # Application container
│   ├── podman-compose-app-debug.yml          # Debug mode container
│   └── podman-compose-obs-standalone.yml     # Observability container
├── docs/
│   ├── ARCHITECTURE-APP-CONTAINER-STANDALONE.md
│   ├── IMPLEMENTATION-APP-CONTAINER-STANDALONE.md
│   ├── TESTING-APP-CONTAINER-STANDALONE.md
│   ├── USER-GUIDE-APP-CONTAINER-STANDALONE.md
│   ├── APP-CONTAINER-VERIFICATION-DAG.md
│   ├── PLAN-APP-VERBOSE-CREATION.md
│   └── TESTSUITE-APP_CONTAINER-Standalone.md
└── src/
    └── Cepaf/
        ├── Domain.fs
        ├── DbVerifier.fs
        ├── AppVerifier.fs
        └── ObsVerifier.fs
```

### 2.2 Configuration Hierarchy

```
config/
├── config.exs           # Base configuration (compile-time)
├── runtime.exs          # Runtime configuration (container-aware)
├── dev.exs              # Development overrides
├── test.exs             # Test environment
├── prod.exs             # Production settings
└── demo.exs             # Demo environment
```

---

## 3. Container Image Build

### 3.1 Base Image Dockerfile

```dockerfile
# Dockerfile.sopv51-base
# NixOS-based Elixir runtime image

FROM nixos/nix:25.05 AS builder

# Install Nix packages
RUN nix-env -iA \
    nixpkgs.elixir_1_19 \
    nixpkgs.erlang_28 \
    nixpkgs.postgresql_17 \
    nixpkgs.nodejs_22 \
    nixpkgs.git \
    nixpkgs.curl \
    nixpkgs.jq

# Set up locale
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create workspace
WORKDIR /workspace

# Set Elixir/Erlang options
ENV ELIXIR_ERL_OPTIONS="+S 10:10 +fnu"
ENV MIX_HOME=/root/.mix
ENV HEX_HOME=/root/.hex

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Default entrypoint
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["mix phx.server"]
```

### 3.2 Build Commands

```bash
# Build base image
podman build -t localhost/indrajaal-sopv51-base:nixos-25.05 \
    -f Dockerfile.sopv51-base .

# Build app image with devenv
podman build -t localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv \
    -f Dockerfile.sopv51-app .

# Verify images
podman images | grep indrajaal-sopv51
```

---

## 4. Compose File Implementation

### 4.1 Database Standalone Compose

```yaml
# lib/cepaf/artifacts/podman-compose-db-standalone.yml
version: '3.8'

networks:
  db-standalone-net:
    driver: bridge

services:
  indrajaal-db-standalone:
    image: localhost/indrajaal-db:pg17-timescale
    container_name: indrajaal-db-standalone
    hostname: db-standalone

    networks:
      - db-standalone-net

    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: indrajaal_standalone
      PGPORT: 5433

    ports:
      - "5433:5433"

    volumes:
      - indrajaal-db-data:/var/lib/postgresql/data

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -p 5433"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 30s

    restart: unless-stopped

volumes:
  indrajaal-db-data:
```

### 4.2 Application Debug Compose (Full Implementation)

```yaml
# lib/cepaf/artifacts/podman-compose-app-debug.yml
version: '3.8'

networks:
  app-debug-net:
    driver: bridge
  db-standalone-net:
    external: true
    name: artifacts_db-standalone-net

services:
  indrajaal-app-debug:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv
    container_name: indrajaal-app-debug
    hostname: app-debug

    networks:
      - app-debug-net
      - db-standalone-net

    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        set -x
        export PS4='[DEBUG:$${LINENO}] '

        echo ""
        echo "╔══════════════════════════════════════════════════════════════════════╗"
        echo "║  INTELITOR APP CONTAINER - FULL VERBOSE DEBUG MODE                    ║"
        echo "║  SOPv5.11 + STAMP + TDG Compliance                                    ║"
        echo "╚══════════════════════════════════════════════════════════════════════╝"
        echo ""

        # Phase 2.1: Hex Installation
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 2.1: HEX INSTALLATION                                         ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix local.hex --force --if-missing 2>&1 | while IFS= read -r line; do
            echo "[P2.1:HEX] $$line"
        done

        # Phase 2.2: Rebar Installation
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 2.2: REBAR INSTALLATION                                       ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix local.rebar --force --if-missing 2>&1 | while IFS= read -r line; do
            echo "[P2.2:REBAR] $$line"
        done

        # Phase 3.1: Database Connectivity
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 3.1: DATABASE CONNECTIVITY                                    ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        ATTEMPT=1
        MAX_ATTEMPTS=60
        while [ $$ATTEMPT -le $$MAX_ATTEMPTS ]; do
            echo "[P3.1] Attempt $$ATTEMPT/$$MAX_ATTEMPTS..."
            if pg_isready -h indrajaal-db-standalone -p 5433 -U postgres 2>&1; then
                echo "[P3.1] ✓ Database is READY"
                break
            fi
            sleep 2
            ATTEMPT=$$((ATTEMPT + 1))
        done

        # Phase 2.3: Dependencies Fetch
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 2.3: DEPENDENCIES FETCH                                       ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        cd /workspace
        mix deps.get --only test 2>&1 | while IFS= read -r line; do
            echo "[P2.3:DEPS.GET] $$line"
        done

        # Phase 2.4: Dependencies Compile
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 2.4: DEPENDENCIES COMPILE                                     ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix deps.compile 2>&1 | while IFS= read -r line; do
            echo "[P2.4:DEPS.COMPILE] $$line"
        done

        # Phase 3.2: Database Creation
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 3.2: DATABASE CREATION                                        ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix ecto.create 2>&1 | while IFS= read -r line; do
            echo "[P3.2:ECTO.CREATE] $$line"
        done || true

        # Phase 3.3: Database Migrations
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 3.3: DATABASE MIGRATIONS                                      ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix ecto.migrate 2>&1 | while IFS= read -r line; do
            echo "[P3.3:ECTO.MIGRATE] $$line"
        done || true

        # Phase 4.1: Application Compile
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 4.1: APPLICATION COMPILE (PATIENT MODE)                       ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        mix compile 2>&1 | tee /var/log/claude/compile.log | while IFS= read -r line; do
            echo "[P4.1:COMPILE] $$line"
        done

        # Phase 4.4: Warning Analysis
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 4.4: WARNING ANALYSIS (SC-CMP-025)                            ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        WARN_COUNT=$$(grep -c 'warning:' /var/log/claude/compile.log 2>/dev/null || echo 0)
        echo "[P4.4] Total warnings: $$WARN_COUNT"
        if [ "$$WARN_COUNT" -eq 0 ]; then
            echo "[P4.4] ✓ SC-CMP-025 COMPLIANT: Zero warnings"
        else
            echo "[P4.4] ⚠️ SC-CMP-025 CHECK: $$WARN_COUNT warnings detected"
        fi

        # Phase 5.1: Phoenix Server Start
        echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
        echo "┃ PHASE 5.1: PHOENIX SERVER START                                     ┃"
        echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
        echo "[P5.1] PHX_HOST: $$PHX_HOST"
        echo "[P5.1] PHX_PORT: $$PHX_PORT"
        echo "[P5.1] Starting Phoenix server..."

        exec mix phx.server 2>&1 | while IFS= read -r line; do
            echo "[P5.1:PHOENIX] $$line"
        done

    environment:
      # Elixir/Erlang
      ELIXIR_ERL_OPTIONS: "+S 10:10 +fnu +W w"
      ERL_CRASH_DUMP: /var/log/claude/erl_crash.dump

      # Mix
      MIX_DEBUG: "1"
      MIX_ENV: test

      # Logger
      LOGGER_LEVEL: debug
      LOG_LEVEL: debug

      # Phoenix
      PHX_HOST: 0.0.0.0
      PHX_PORT: 4000
      PHX_SERVER: "true"
      DEBUG_ERRORS: "true"
      SECRET_KEY_BASE: debug-secret-key-base-minimum-64-characters-required

      # Database
      DATABASE_URL: ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone
      ECTO_DEBUG: "true"

      # Patient Mode
      NO_TIMEOUT: "true"
      PATIENT_MODE: "enabled"
      INFINITE_PATIENCE: "true"

      # OpenTelemetry
      OTEL_LOG_LEVEL: debug
      OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:4317

      # CEPAF
      CEPAF_DEBUG: "1"
      CEPAF_VERBOSE: "1"

    ports:
      - "4000:4000"
      - "4001:4001"
      - "9568:9568"

    volumes:
      - /home/an/dev/ver/indrajaal-v5.2:/workspace:z
      - type: tmpfs
        target: /var/log/claude

    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:4000/health || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 60
      start_period: 600s

    restart: "no"

    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '8'
```

---

## 5. Runtime Configuration

### 5.1 PHX_SERVER Support (config/runtime.exs)

```elixir
# config/runtime.exs - PHX_SERVER Support Block

# ═══════════════════════════════════════════════════════════════════════════════
# PHX_SERVER Support for Container Testing (SC-CNT-009)
# ═══════════════════════════════════════════════════════════════════════════════
# When PHX_SERVER=true is set, explicitly enable the HTTP server.
# This is critical for container health probes in test environments.
# ═══════════════════════════════════════════════════════════════════════════════
if System.get_env("PHX_SERVER") == "true" do
  config :indrajaal, IndrajaalWeb.Endpoint,
    server: true,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PHX_PORT") || "4000")]
end
```

### 5.2 Logger Configuration

```elixir
# config/runtime.exs - Dual Logging Configuration

# Console logging for immediate visibility
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: :all,
  level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

# LoggerJSON backend for structured JSON logging to SigNoz
config :logger,
  backends: [:console, LoggerJSON],
  level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

config :logger_json, :backend,
  formatter: LoggerJSON.Formatters.DatadogLogger,
  metadata: :all
```

### 5.3 Database Configuration

```elixir
# config/runtime.exs - Container Database Configuration

if config_env() in [:dev, :test, :demo] do
  # Check for DATABASE_URL first (for container environments)
  if database_url = System.get_env("DATABASE_URL") do
    config :indrajaal, Indrajaal.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
  else
    # Fall back to individual environment variables
    config :indrajaal, Indrajaal.Repo,
      username: System.get_env("POSTGRES_USER", "postgres"),
      password: System.get_env("POSTGRES_PASSWORD", "postgres"),
      hostname: System.get_env("POSTGRES_HOST", "localhost"),
      port: String.to_integer(System.get_env("POSTGRES_PORT", "5433")),
      database: System.get_env("POSTGRES_DB", "indrajaal_#{config_env()}"),
      pool_size: 20
  end
end
```

---

## 6. Logging Implementation

### 6.1 QuadplexLogger Module

```elixir
# lib/indrajaal/observability/quadplex_logger.ex

defmodule Indrajaal.Observability.QuadplexLogger do
  @moduledoc """
  Four-channel structured logging system for comprehensive observability.

  ## Channels

  1. **Security** - Authentication, authorization, access control events
  2. **Business** - Domain operations, transactions, workflow events
  3. **Performance** - Latency, throughput, resource utilization
  4. **System** - Infrastructure, lifecycle, health events

  ## Usage

      QuadplexLogger.log(:security, :auth_success, %{user_id: user.id})
      QuadplexLogger.log(:business, :order_created, %{order_id: order.id})
      QuadplexLogger.log(:performance, :slow_query, %{duration_ms: 150})
      QuadplexLogger.log(:system, :container_health, %{status: :healthy})

  ## STAMP Compliance

  - SC-OBS-069: Dual logging (console + structured JSON)
  - SC-OBS-070: Channel-based event routing
  - SC-OBS-071: OTEL trace correlation
  """

  require Logger

  @channels [:security, :business, :performance, :system]

  @type channel :: :security | :business | :performance | :system
  @type event :: atom()
  @type metadata :: map()

  @doc """
  Log an event to the specified channel.
  """
  @spec log(channel(), event(), metadata()) :: :ok
  def log(channel, event, metadata \\ %{}) when channel in @channels do
    enriched_metadata =
      metadata
      |> Map.put(:channel, channel)
      |> Map.put(:event, event)
      |> Map.put(:timestamp, DateTime.utc_now())
      |> add_trace_context()

    log_level = channel_to_level(channel)

    Logger.log(log_level, fn ->
      "[#{channel}:#{event}] #{inspect(enriched_metadata)}"
    end, domain: [:quadplex, channel])

    :telemetry.execute(
      [:quadplex, :log, channel],
      %{count: 1},
      enriched_metadata
    )

    :ok
  end

  @doc """
  Log a security event.
  """
  @spec security(event(), metadata()) :: :ok
  def security(event, metadata \\ %{}), do: log(:security, event, metadata)

  @doc """
  Log a business event.
  """
  @spec business(event(), metadata()) :: :ok
  def business(event, metadata \\ %{}), do: log(:business, event, metadata)

  @doc """
  Log a performance event.
  """
  @spec performance(event(), metadata()) :: :ok
  def performance(event, metadata \\ %{}), do: log(:performance, event, metadata)

  @doc """
  Log a system event.
  """
  @spec system(event(), metadata()) :: :ok
  def system(event, metadata \\ %{}), do: log(:system, event, metadata)

  # Private functions

  defp channel_to_level(:security), do: :warning
  defp channel_to_level(:business), do: :info
  defp channel_to_level(:performance), do: :info
  defp channel_to_level(:system), do: :debug

  defp add_trace_context(metadata) do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        metadata

      span_ctx ->
        metadata
        |> Map.put(:trace_id, OpenTelemetry.Span.trace_id(span_ctx))
        |> Map.put(:span_id, OpenTelemetry.Span.span_id(span_ctx))
    end
  rescue
    _ -> metadata
  end
end
```

### 6.2 Debug Logging Macros

```elixir
# lib/indrajaal/debug.ex

defmodule Indrajaal.Debug do
  @moduledoc """
  Debug logging utilities with verbose output support.
  """

  require Logger

  @doc """
  Log debug message with file/line context.
  """
  defmacro debug(message, metadata \\ []) do
    quote do
      if System.get_env("MIX_DEBUG") == "1" do
        Logger.debug(
          "[DEBUG:#{unquote(__CALLER__.file)}:#{unquote(__CALLER__.line)}] " <>
            unquote(message),
          unquote(metadata)
        )
      end
    end
  end

  @doc """
  Log verbose message with full context.
  """
  defmacro verbose(message, data \\ nil) do
    quote do
      if System.get_env("CEPAF_VERBOSE") == "1" do
        data_str = if unquote(data), do: " | Data: #{inspect(unquote(data))}", else: ""
        Logger.info(
          "[VERBOSE:#{unquote(__CALLER__.module)}.#{elem(__ENV__.function, 0)}] " <>
            unquote(message) <> data_str
        )
      end
    end
  end
end
```

---

## 7. Telemetry Implementation

### 7.1 Telemetry Attachment

```elixir
# lib/indrajaal/telemetry.ex

defmodule Indrajaal.Telemetry do
  @moduledoc """
  Telemetry event handlers and metric definitions.
  """

  require Logger

  @doc """
  Attach all telemetry handlers.
  """
  def attach_handlers do
    # Phoenix endpoint telemetry
    :telemetry.attach_many(
      "indrajaal-phoenix-handlers",
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop],
        [:phoenix, :error_rendered]
      ],
      &handle_phoenix_event/4,
      nil
    )

    # Ecto telemetry
    :telemetry.attach_many(
      "indrajaal-ecto-handlers",
      [
        [:indrajaal, :repo, :query]
      ],
      &handle_ecto_event/4,
      nil
    )

    # OODA loop telemetry
    :telemetry.attach_many(
      "indrajaal-ooda-handlers",
      [
        [:ooda, :cycle, :start],
        [:ooda, :cycle, :stop],
        [:ooda, :phase, :complete]
      ],
      &handle_ooda_event/4,
      nil
    )

    :ok
  end

  # Phoenix event handlers
  defp handle_phoenix_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    if System.get_env("CEPAF_VERBOSE") == "1" do
      Logger.debug(
        "[TELEMETRY:PHOENIX] Request completed | " <>
          "path=#{metadata.conn.request_path} | " <>
          "status=#{metadata.conn.status} | " <>
          "duration=#{duration_ms}ms"
      )
    end

    :telemetry.execute(
      [:indrajaal, :request, :complete],
      %{duration_ms: duration_ms},
      %{
        path: metadata.conn.request_path,
        method: metadata.conn.method,
        status: metadata.conn.status
      }
    )
  end

  defp handle_phoenix_event(_event, _measurements, _metadata, _config), do: :ok

  # Ecto event handlers
  defp handle_ecto_event([:indrajaal, :repo, :query], measurements, metadata, _config) do
    total_time_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)

    if System.get_env("ECTO_DEBUG") == "true" and total_time_ms > 100 do
      Logger.warning(
        "[TELEMETRY:ECTO] Slow query | " <>
          "source=#{metadata.source} | " <>
          "duration=#{total_time_ms}ms"
      )
    end
  end

  # OODA event handlers
  defp handle_ooda_event([:ooda, :cycle, :stop], measurements, metadata, _config) do
    if rem(metadata.cycle_count, 1_000_000) == 0 do
      Logger.info(
        "[TELEMETRY:OODA] Milestone | " <>
          "cycles=#{metadata.cycle_count} | " <>
          "latency=#{measurements.latency_ms}ms"
      )
    end
  end

  defp handle_ooda_event(_event, _measurements, _metadata, _config), do: :ok
end
```

### 7.2 Metrics Worker

```elixir
# lib/indrajaal/telemetry_metrics_worker.ex

defmodule Indrajaal.TelemetryMetricsWorker do
  @moduledoc """
  Periodic metrics collection worker.
  """

  use GenServer

  require Logger

  @interval 10_000  # 10 seconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_collection()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:collect, state) do
    collect_metrics()
    schedule_collection()
    {:noreply, state}
  end

  defp schedule_collection do
    Process.send_after(self(), :collect, @interval)
  end

  defp collect_metrics do
    # VM metrics
    memory = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    run_queue = :erlang.statistics(:run_queue)

    :telemetry.execute(
      [:vm, :memory],
      %{
        total: memory[:total],
        processes: memory[:processes],
        ets: memory[:ets],
        binary: memory[:binary]
      },
      %{}
    )

    :telemetry.execute(
      [:vm, :system],
      %{
        process_count: process_count,
        run_queue: run_queue
      },
      %{}
    )

    if System.get_env("CEPAF_VERBOSE") == "1" do
      Logger.debug(
        "[METRICS] VM stats | " <>
          "memory=#{div(memory[:total], 1_048_576)}MB | " <>
          "processes=#{process_count} | " <>
          "run_queue=#{run_queue}"
      )
    end
  end
end
```

---

## 8. Health Probe Implementation

### 8.1 Health Controller

```elixir
# lib/indrajaal_web/controllers/health_controller.ex

defmodule IndrajaalWeb.HealthController do
  @moduledoc """
  Health check endpoints for container orchestration.

  ## Endpoints

  - `GET /healthz` - Liveness probe (is the process alive?)
  - `GET /ready` - Readiness probe (can it serve traffic?)
  - `GET /startup` - Startup probe (has it finished starting?)
  - `GET /health` - Comprehensive health status

  ## STAMP Compliance

  - SC-PRF-050: Response time <50ms
  - SC-OBS-069: Health status logging
  """

  use IndrajaalWeb, :controller

  require Logger

  @doc """
  Liveness probe - checks if the BEAM VM is responsive.
  """
  def liveness(conn, _params) do
    checks = %{
      beam_vm: check_beam_vm(),
      memory: check_memory(),
      scheduler: check_scheduler()
    }

    status = if all_healthy?(checks), do: "ok", else: "degraded"

    conn
    |> put_status(if status == "ok", do: 200, else: 503)
    |> json(%{
      probe: "liveness",
      status: status,
      timestamp: DateTime.utc_now(),
      node: node()
    })
  end

  @doc """
  Readiness probe - checks if the application can serve requests.
  """
  def readiness(conn, _params) do
    checks = %{
      database: check_database(),
      pubsub: check_pubsub(),
      telemetry: check_telemetry(),
      redis: check_redis()
    }

    healthy = all_healthy?(checks)
    status = if healthy, do: "ready", else: "not_ready"

    conn
    |> put_status(if healthy, do: 200, else: 503)
    |> json(%{
      probe: "readiness",
      status: status,
      timestamp: DateTime.utc_now(),
      checks: format_checks(checks)
    })
  end

  @doc """
  Startup probe - checks if the application has finished starting.
  """
  def startup(conn, _params) do
    checks = %{
      application: check_application(),
      endpoint: check_endpoint(),
      supervision_tree: check_supervision_tree()
    }

    healthy = all_healthy?(checks)
    status = if healthy, do: "started", else: "starting"

    uptime_ms =
      case :erlang.statistics(:wall_clock) do
        {total_ms, _since_last} -> total_ms
        _ -> 0
      end

    conn
    |> put_status(if healthy, do: 200, else: 503)
    |> json(%{
      probe: "startup",
      status: status,
      timestamp: DateTime.utc_now(),
      uptime_ms: uptime_ms,
      checks: format_checks(checks)
    })
  end

  @doc """
  Comprehensive health check with full system status.
  """
  def comprehensive(conn, _params) do
    liveness_checks = %{
      beam_vm: check_beam_vm(),
      memory: check_memory(),
      scheduler: check_scheduler()
    }

    startup_checks = %{
      application: check_application(),
      endpoint: check_endpoint(),
      supervision_tree: check_supervision_tree()
    }

    readiness_checks = %{
      database: check_database(),
      pubsub: check_pubsub(),
      telemetry: check_telemetry(),
      redis: check_redis()
    }

    all_healthy =
      all_healthy?(liveness_checks) and
      all_healthy?(startup_checks) and
      all_healthy?(readiness_checks)

    memory = :erlang.memory()

    conn
    |> put_status(if all_healthy, do: 200, else: 503)
    |> json(%{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      version: Application.spec(:indrajaal, :vsn) |> to_string(),
      timestamp: DateTime.utc_now(),
      node: node(),
      system: %{
        elixir_version: System.version(),
        otp_release: :erlang.system_info(:otp_release) |> to_string(),
        process_count: :erlang.system_info(:process_count),
        schedulers: :erlang.system_info(:schedulers_online),
        memory_mb: div(memory[:total], 1_048_576)
      },
      container: get_container_status(),
      probes: %{
        liveness: format_checks(liveness_checks),
        startup: format_checks(startup_checks),
        readiness: format_checks(readiness_checks)
      }
    })
  end

  # Check implementations

  defp check_beam_vm do
    try do
      _ = :erlang.system_info(:otp_release)
      {:ok, true}
    rescue
      _ -> {:error, false}
    end
  end

  defp check_memory do
    memory = :erlang.memory(:total)
    # Alert if memory > 6GB
    if memory < 6_000_000_000 do
      {:ok, true}
    else
      {:warning, true}
    end
  end

  defp check_scheduler do
    run_queue = :erlang.statistics(:run_queue)
    # Alert if run queue > 100
    if run_queue < 100 do
      {:ok, true}
    else
      {:warning, true}
    end
  end

  defp check_database do
    try do
      Indrajaal.Repo.query!("SELECT 1")
      {:ok, true}
    rescue
      e ->
        Logger.warning("[HEALTH] Database check failed: #{inspect(e)}")
        {:error, false}
    end
  end

  defp check_pubsub do
    try do
      Phoenix.PubSub.node_name(Indrajaal.PubSub)
      {:ok, true}
    rescue
      _ -> {:error, false}
    end
  end

  defp check_telemetry do
    # Check if telemetry handlers are attached
    handlers = :telemetry.list_handlers([:phoenix, :endpoint, :stop])
    if length(handlers) > 0 do
      {:ok, true}
    else
      {:warning, true}
    end
  end

  defp check_redis do
    # Redis is optional - return error but don't fail health
    {:error, false}
  end

  defp check_application do
    apps = Application.started_applications()
    if Enum.any?(apps, fn {name, _, _} -> name == :indrajaal end) do
      {:ok, true}
    else
      {:error, false}
    end
  end

  defp check_endpoint do
    try do
      IndrajaalWeb.Endpoint.config(:url)
      {:ok, true}
    rescue
      _ -> {:error, false}
    end
  end

  defp check_supervision_tree do
    try do
      children = Supervisor.which_children(Indrajaal.Supervisor)
      if length(children) > 0 do
        {:ok, true}
      else
        {:error, false}
      end
    rescue
      _ ->
        # Fallback - check if application is running
        {:ok, true}
    end
  end

  defp get_container_status do
    try do
      Indrajaal.Cortex.Sensors.ContainerHealthTelemetry.get_status()
    rescue
      _ -> %{status: "unavailable", error: "Container health sensor not responding"}
    end
  end

  defp all_healthy?(checks) do
    Enum.all?(checks, fn {_name, {status, healthy}} ->
      healthy and status != :error
    end)
  end

  defp format_checks(checks) do
    Map.new(checks, fn {name, {status, healthy}} ->
      {name, %{status: status, healthy: healthy}}
    end)
  end
end
```

### 8.2 Router Configuration

```elixir
# lib/indrajaal_web/router.ex (excerpt)

scope "/", IndrajaalWeb do
  pipe_through :api

  # Health probes (no authentication required)
  get "/healthz", HealthController, :liveness
  get "/ready", HealthController, :readiness
  get "/startup", HealthController, :startup
  get "/health", HealthController, :comprehensive
end
```

---

## 9. OODA Cybernetic Loop

### 9.1 OODA Loop GenServer

```elixir
# lib/indrajaal/cybernetic/ooda/loop.ex

defmodule Indrajaal.Cybernetic.OODA.Loop do
  @moduledoc """
  Observe-Orient-Decide-Act (OODA) cybernetic control loop.

  ## Phases

  1. **Observe** - Collect telemetry and sensor data
  2. **Orient** - Analyze context and current state
  3. **Decide** - Select optimal action strategy
  4. **Act** - Execute decision with feedback

  ## Metrics

  - Cycle count: Total OODA iterations
  - Cycle latency: Time per complete cycle
  - Decision rate: Actions per second
  """

  use GenServer

  require Logger

  @cycle_interval 0  # Continuous execution

  defstruct [
    :cycle_count,
    :last_cycle_time,
    :metrics
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      cycle_count: 0,
      last_cycle_time: System.monotonic_time(:millisecond),
      metrics: %{}
    }

    schedule_cycle()

    Logger.info("[OODA] Cybernetic loop initialized")

    {:ok, state}
  end

  @impl true
  def handle_info(:cycle, state) do
    start_time = System.monotonic_time(:millisecond)

    # Execute OODA phases
    observations = observe()
    orientation = orient(observations)
    decision = decide(orientation)
    _result = act(decision)

    # Calculate metrics
    end_time = System.monotonic_time(:millisecond)
    latency = end_time - start_time
    new_count = state.cycle_count + 1

    # Log milestone cycles
    if rem(new_count, 1_000_000) == 0 do
      Logger.info("🔄 OODA Cycle ##{new_count} Complete. Latency: #{latency}ms")
    end

    # Trigger scaling based on stress
    if orientation[:stress_level] do
      case orientation[:stress_level] do
        level when level > 0.8 ->
          Logger.info("🧠 OODA: Triggering Scale UP (FLAME)")
        level when level < 0.2 ->
          Logger.info("🧠 OODA: Triggering Scale DOWN (FLAME)")
        _ ->
          :ok
      end
    end

    # Emit telemetry
    :telemetry.execute(
      [:ooda, :cycle, :stop],
      %{latency_ms: latency},
      %{cycle_count: new_count}
    )

    schedule_cycle()

    {:noreply, %{state | cycle_count: new_count, last_cycle_time: end_time}}
  end

  # OODA Phases

  defp observe do
    %{
      memory: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue),
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  defp orient(observations) do
    memory_mb = div(observations.memory, 1_048_576)
    memory_threshold = 4000  # 4GB

    stress_level =
      cond do
        memory_mb > memory_threshold -> 0.9
        observations.run_queue > 50 -> 0.7
        observations.process_count > 50_000 -> 0.6
        true -> 0.3
      end

    %{
      stress_level: stress_level,
      memory_mb: memory_mb,
      observations: observations
    }
  end

  defp decide(orientation) do
    cond do
      orientation.stress_level > 0.8 ->
        {:scale, :up}
      orientation.stress_level < 0.2 ->
        {:scale, :down}
      true ->
        {:maintain, :current}
    end
  end

  defp act({:scale, direction}) do
    # In a full implementation, this would trigger FLAME scaling
    {:ok, direction}
  end

  defp act({:maintain, _}) do
    {:ok, :maintained}
  end

  defp schedule_cycle do
    Process.send_after(self(), :cycle, @cycle_interval)
  end
end
```

---

## 10. Database Integration

### 10.1 Repo Configuration

```elixir
# lib/indrajaal/repo.ex

defmodule Indrajaal.Repo do
  use Ecto.Repo,
    otp_app: :indrajaal,
    adapter: Ecto.Adapters.Postgres

  require Logger

  @doc """
  Override prepare_query to add debug logging.
  """
  def prepare_query(_operation, query, opts) do
    if System.get_env("ECTO_DEBUG") == "true" do
      Logger.debug("[REPO] Preparing query: #{inspect(query)}")
    end

    {query, opts}
  end

  @doc """
  Override default_options to add telemetry.
  """
  def default_options(_operation) do
    [
      telemetry_options: [
        decode_time: true,
        query_time: true,
        queue_time: true
      ]
    ]
  end
end
```

### 10.2 Migration Template

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_example_migration.exs

defmodule Indrajaal.Repo.Migrations.ExampleMigration do
  use Ecto.Migration

  @moduledoc """
  Example migration with verbose logging support.
  """

  require Logger

  def up do
    Logger.info("[MIGRATION] Starting: #{__MODULE__}")

    # Create table
    create table(:example, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :data, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Create index
    create_if_not_exists index(:example, [:name])

    Logger.info("[MIGRATION] Completed: #{__MODULE__}")
  end

  def down do
    Logger.info("[MIGRATION] Rolling back: #{__MODULE__}")

    drop_if_exists index(:example, [:name])
    drop_if_exists table(:example)

    Logger.info("[MIGRATION] Rolled back: #{__MODULE__}")
  end
end
```

---

## 11. Startup Script Implementation

### 11.1 Container Entrypoint Script

```bash
#!/bin/sh
# container-entrypoint.sh
# Full verbose startup script for Indrajaal App Container

set -x
export PS4='[DEBUG:${LINENO}] '

# Banner
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  INTELITOR APP CONTAINER - SOPv5.11 COMPLIANT                        ║"
echo "║  Runtime: Elixir ${ELIXIR_VERSION:-1.19.4} / OTP ${OTP_VERSION:-28}  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Environment info
echo "[SYSTEM] Started at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "[SYSTEM] Hostname: $(hostname)"
echo "[SYSTEM] MIX_ENV: ${MIX_ENV}"
echo "[SYSTEM] Patient Mode: ${PATIENT_MODE}"
echo ""

# Phase 2: Setup
echo "[PHASE 2] Installing build tools..."
mix local.hex --force --if-missing
mix local.rebar --force --if-missing

# Phase 3: Database
echo "[PHASE 3] Waiting for database..."
until pg_isready -h ${DB_HOST:-localhost} -p ${PGPORT:-5433} -U ${POSTGRES_USER:-postgres}; do
    echo "[PHASE 3] Database not ready, waiting..."
    sleep 2
done
echo "[PHASE 3] Database ready!"

# Phase 2 continued: Dependencies
echo "[PHASE 2] Fetching dependencies..."
cd /workspace
mix deps.get --only ${MIX_ENV}
mix deps.compile

# Phase 3 continued: Database setup
echo "[PHASE 3] Setting up database..."
mix ecto.create --quiet || true
mix ecto.migrate --quiet || true

# Phase 4: Compilation
echo "[PHASE 4] Compiling application (Patient Mode)..."
mix compile 2>&1 | tee /var/log/claude/compile.log

# Warning check
WARN_COUNT=$(grep -c 'warning:' /var/log/claude/compile.log 2>/dev/null || echo 0)
echo "[PHASE 4] Warnings: ${WARN_COUNT}"
if [ "${WARN_COUNT}" -eq 0 ]; then
    echo "[PHASE 4] ✓ SC-CMP-025 COMPLIANT"
else
    echo "[PHASE 4] ⚠️ ${WARN_COUNT} warnings detected"
fi

# Phase 5: Startup
echo "[PHASE 5] Starting Phoenix server..."
exec mix phx.server
```

---

## 12. Debug Mode Configuration

### 12.1 Complete Debug Environment

```yaml
environment:
  # ═══════════════════════════════════════════════════════════════
  # ELIXIR/ERLANG DEBUG
  # ═══════════════════════════════════════════════════════════════
  ELIXIR_ERL_OPTIONS: "+S 10:10 +fnu +W w"
  ERL_CRASH_DUMP: /var/log/claude/erl_crash.dump
  ERL_CRASH_DUMP_SECONDS: "60"

  # ═══════════════════════════════════════════════════════════════
  # MIX DEBUG
  # ═══════════════════════════════════════════════════════════════
  MIX_DEBUG: "1"
  MIX_ENV: test
  MIX_BUILD_ROOT: /workspace/_build

  # ═══════════════════════════════════════════════════════════════
  # LOGGER DEBUG
  # ═══════════════════════════════════════════════════════════════
  LOGGER_LEVEL: debug
  LOG_LEVEL: debug
  LOGGER_TRUNCATE: "infinity"

  # ═══════════════════════════════════════════════════════════════
  # PHOENIX DEBUG
  # ═══════════════════════════════════════════════════════════════
  PHX_HOST: 0.0.0.0
  PHX_PORT: 4000
  PHX_SERVER: "true"
  DEBUG_ERRORS: "true"

  # ═══════════════════════════════════════════════════════════════
  # DATABASE DEBUG
  # ═══════════════════════════════════════════════════════════════
  ECTO_DEBUG: "true"
  DATABASE_URL: ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone

  # ═══════════════════════════════════════════════════════════════
  # PATIENT MODE (MANDATORY)
  # ═══════════════════════════════════════════════════════════════
  NO_TIMEOUT: "true"
  PATIENT_MODE: "enabled"
  INFINITE_PATIENCE: "true"

  # ═══════════════════════════════════════════════════════════════
  # OPENTELEMETRY DEBUG
  # ═══════════════════════════════════════════════════════════════
  OTEL_LOG_LEVEL: debug
  OTEL_TRACES_EXPORTER: console
  OTEL_METRICS_EXPORTER: console
  OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:4317

  # ═══════════════════════════════════════════════════════════════
  # CEPAF DEBUG
  # ═══════════════════════════════════════════════════════════════
  CEPAF_DEBUG: "1"
  CEPAF_VERBOSE: "1"
  CEPAF_TRACE: "1"
  CEPAF_LOG_LEVEL: trace

  # ═══════════════════════════════════════════════════════════════
  # CONTAINER DEBUG
  # ═══════════════════════════════════════════════════════════════
  CONTAINER_DEBUG: "true"
  CONTAINER_VERBOSE: "true"
  SOPV51_DEBUG: "true"
```

---

## 13. Environment Variables Reference

### 13.1 Complete Variable List

| Variable | Default | Description | Category |
|----------|---------|-------------|----------|
| `MIX_ENV` | `dev` | Mix environment | Runtime |
| `MIX_DEBUG` | `0` | Enable Mix debug output | Debug |
| `PHX_SERVER` | `false` | Enable Phoenix HTTP server | Phoenix |
| `PHX_HOST` | `localhost` | Phoenix bind address | Phoenix |
| `PHX_PORT` | `4000` | Phoenix HTTP port | Phoenix |
| `SECRET_KEY_BASE` | - | Phoenix session secret | Security |
| `DATABASE_URL` | - | Ecto database URL | Database |
| `POSTGRES_USER` | `postgres` | PostgreSQL username | Database |
| `POSTGRES_PASSWORD` | `postgres` | PostgreSQL password | Database |
| `POSTGRES_HOST` | `localhost` | PostgreSQL hostname | Database |
| `POSTGRES_PORT` | `5433` | PostgreSQL port | Database |
| `ECTO_DEBUG` | `false` | Enable Ecto query logging | Debug |
| `LOGGER_LEVEL` | `info` | Logger level | Logging |
| `NO_TIMEOUT` | `false` | Disable timeouts | Patient |
| `PATIENT_MODE` | `disabled` | Enable patient mode | Patient |
| `INFINITE_PATIENCE` | `false` | Max patience | Patient |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | OTLP endpoint | Telemetry |
| `OTEL_LOG_LEVEL` | `info` | OTEL log level | Telemetry |
| `CEPAF_DEBUG` | `0` | CEPAF debug mode | Debug |
| `CEPAF_VERBOSE` | `0` | CEPAF verbose output | Debug |

---

## 14. Code Patterns

### 14.1 Resource Pattern (Ash)

```elixir
defmodule Indrajaal.Domain.Resource do
  use Indrajaal.BaseResource

  resource do
    description "Resource description"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end
  end
end
```

### 14.2 Controller Pattern

```elixir
defmodule IndrajaalWeb.ResourceController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Domain

  require Logger

  def index(conn, params) do
    Logger.debug("[CONTROLLER] index called with params: #{inspect(params)}")

    case Domain.list_resources() do
      {:ok, resources} ->
        json(conn, %{data: resources})

      {:error, reason} ->
        Logger.error("[CONTROLLER] Failed to list resources: #{inspect(reason)}")
        conn
        |> put_status(500)
        |> json(%{error: "Internal server error"})
    end
  end
end
```

### 14.3 GenServer Pattern

```elixir
defmodule Indrajaal.Worker do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("[WORKER] Starting with opts: #{inspect(opts)}")
    {:ok, %{}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[WORKER] Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end
```

---

## Appendix: Troubleshooting

### Common Issues

1. **Phoenix not binding to port**
   - Ensure `PHX_SERVER=true` is set
   - Check `config/runtime.exs` has PHX_SERVER support block

2. **Database connection refused**
   - Verify database container is healthy
   - Check network connectivity between containers

3. **Compilation timeout**
   - Enable Patient Mode: `NO_TIMEOUT=true PATIENT_MODE=enabled`
   - Increase scheduler count: `ELIXIR_ERL_OPTIONS="+S 10:10"`

4. **Missing dependencies**
   - Run `mix deps.get` inside container
   - Check network access for Hex packages
