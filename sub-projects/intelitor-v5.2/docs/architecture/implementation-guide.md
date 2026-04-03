# Indrajaal Implementation Guide

**Version**: 1.1.0
**Framework**: SOPv5.11 + TPS + STAMP + TDG + GDE
**Last Updated**: 2026-03-19
**Compliance**: IEC 61508 SIL-6 (Biomorphic Extended), ISO 27001, GDPR, EN 50131

> **Sprint 51 Implementation Status** (2026-03-19):
> - **Route module** (`lib/indrajaal/route.ex`): Full pattern-based route matching with static/dynamic/wildcard segments and parameter extraction -- real implementation, not a stub.
> - **ConfigManagement auth**: `SecurityPolicy.authenticate/authorize/validate_access` wired to real credential validation and RBAC checks.
> - **Accounts**: `Accounts.get_user_by_email` wired to Ash read action with proper domain queries.

---

## Table of Contents

1. [Development Environment Setup](#1-development-environment-setup)
2. [Container Infrastructure](#2-container-infrastructure)
3. [Database Setup](#3-database-setup)
4. [Application Configuration](#4-application-configuration)
5. [Running the Application](#5-running-the-application)
6. [Development Workflow](#6-development-workflow)
7. [Testing Procedures](#7-testing-procedures)
8. [Adding New Features](#8-adding-new-features)
9. [Deployment](#9-deployment)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Development Environment Setup

### 1.1 Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| NixOS/Nix | 2.18+ | Development environment |
| Elixir | 1.19.2 | Application runtime |
| Erlang OTP | 28.0.0 | BEAM runtime |
| Podman | 5.4.1+ | Container runtime |
| PostgreSQL | 17 | Database server |
| TimescaleDB | 2.17 | Time-series extension |
| Node.js | 20+ | Asset compilation |

### 1.2 Initial Setup with devenv

```bash
# Clone the repository
git clone https://github.com/indrajaal/indrajaal.git
cd indrajaal

# Enter the development environment
devenv shell

# The devenv.nix automatically configures:
# - Patient Mode compilation settings
# - 50-Agent Architecture environment
# - PHICS hot-reloading
# - Container compliance settings
```

### 1.3 Environment Variables

The `devenv.nix` configures all required environment variables:

```bash
# Core SOPv5.11 Settings
SOPV511_FRAMEWORK_ENABLED=true
SOPV511_PHASE_EXECUTION=true
SOPV511_AGENT_COORDINATION=true

# Patient Mode (MANDATORY)
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8

# 50-Agent Architecture
EXECUTIVE_DIRECTOR_AGENTS=1
DOMAIN_SUPERVISOR_AGENTS=10
FUNCTIONAL_SUPERVISOR_AGENTS=15
WORKER_AGENTS=24
TOTAL_AGENTS=50

# Container Settings
PODMAN_ROOTLESS=true
NIXOS_CONTAINER_ONLY=true
CONTAINER_REGISTRY=localhost

# PHICS Hot-Reloading
PHICS_ENABLED=true
PHICS_HOT_RELOAD=enabled
PHICS_SYNC_LATENCY_TARGET=50
```

### 1.4 Installing Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Compile the application (Patient Mode)
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile 2>&1 | tee -a ./data/tmp/1-compile.log

# Install Node.js dependencies for assets
cd assets && npm install && cd ..
```

---

## 2. Container Infrastructure

### 2.1 Container Architecture

The system uses a 3-container primary architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Container Architecture                     │
├───────────────────┬───────────────────┬─────────────────────┤
│  indrajaal-app    │  indrajaal-db     │  indrajaal-obs      │
│  (Application)    │  (Database)       │  (Observability)    │
│  CPU: 12 cores    │  CPU: 4 cores     │  CPU: 4 cores       │
│  RAM: 32 GB       │  RAM: 16 GB       │  RAM: 8 GB          │
└───────────────────┴───────────────────┴─────────────────────┘
```

### 2.2 Starting Containers

```bash
# Start all containers
podman-compose -f podman-compose.yml up -d

# Verify container health
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check container logs
podman logs indrajaal-timescaledb-demo
podman logs indrajaal-app-demo
```

### 2.3 Container Registry (STAMP SC-CNT-010)

All containers MUST use localhost registry:

```yaml
# Correct (STAMP Compliant)
image: localhost/indrajaal-app:nixos-devenv

# FORBIDDEN - External registries
image: docker.io/library/postgres:17  # VIOLATION
```

### 2.4 Building Container Images

```bash
# Build the TimescaleDB image
podman build -t localhost/indrajaal-timescaledb-demo:nixos-devenv \
  -f containers/timescaledb/Dockerfile .

# Build the application image
podman build -t localhost/indrajaal-app:nixos-devenv \
  -f containers/app/Dockerfile .
```

### 2.5 PHICS Hot-Reloading

The container setup supports PHICS (Phoenix In-Container Hot-reload System):

```yaml
# Volume mounts for hot-reloading
volumes:
  - ./lib:/app/lib:ro
  - ./config:/app/config:ro
  - ./priv:/app/priv:rw

# Latency requirement: < 50ms (SC-CNT-011)
```

---

## 3. Database Setup

### 3.1 PostgreSQL + TimescaleDB Configuration

```bash
# Database runs on port 5433 (not default 5432)
PGPORT=5433
POSTGRES_DB=indrajaal_demo
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
```

### 3.2 Creating the Database

```bash
# Create development database
mix ecto.create

# Run migrations
mix ecto.migrate

# Seed with demo data (optional)
mix run priv/repo/seeds.exs
```

### 3.3 Test Database Setup

```bash
# Create test database
MIX_ENV=test mix ecto.create

# Run test migrations
MIX_ENV=test mix ecto.migrate

# Reset database (drop, create, migrate)
MIX_ENV=test mix ecto.reset
```

### 3.4 TimescaleDB Hypertables

Time-series data uses TimescaleDB hypertables:

```elixir
# Example migration for time-series data
defmodule Indrajaal.Repo.Migrations.CreateAlarmEvents do
  use Ecto.Migration

  def up do
    create table(:alarm_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :alarm_id, references(:alarms, type: :uuid)
      add :event_type, :string
      add :occurred_at, :utc_datetime_usec, null: false
      timestamps()
    end

    # Convert to TimescaleDB hypertable
    execute "SELECT create_hypertable('alarm_events', 'occurred_at')"
  end
end
```

---

## 4. Application Configuration

### 4.1 Configuration Files

```
config/
├── config.exs      # Shared configuration
├── dev.exs         # Development settings
├── test.exs        # Test settings
├── prod.exs        # Production settings
└── runtime.exs     # Runtime configuration
```

### 4.2 Key Configuration Sections

**Ecto Repository:**
```elixir
config :indrajaal,
  ecto_repos: [Indrajaal.Repo],
  generators: [timestamp_type: :utc_datetime]
```

**Phoenix Endpoint:**
```elixir
config :indrajaal, IndrajaalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IndrajaalWeb.ErrorHTML, json: IndrajaalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Indrajaal.PubSub
```

**Ash Framework:**
```elixir
config :ash,
  include_embedded_source_by_default?: false,
  default_page_type: :keyset,
  policies: [
    no_filter_static_forbidden_reads?: false,
    default: :strict
  ]
```

### 4.3 Environment-Specific Settings

**Development:**
```elixir
# config/dev.exs
config :indrajaal, Indrajaal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "indrajaal_dev",
  port: 5433,
  pool_size: 10
```

**Test:**
```elixir
# config/test.exs
config :indrajaal, Indrajaal.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 600_000,
  timeout: 300_000
```

---

## 5. Running the Application

### 5.1 Development Server

```bash
# Start Phoenix server with hot-reloading
mix phx.server

# Or start in interactive mode
iex -S mix phx.server

# Application available at:
# - Web: http://localhost:4000
# - LiveDashboard: http://localhost:4000/dev/dashboard
```

### 5.2 Interactive Console

```bash
# Start IEx with the application
iex -S mix

# Example commands in IEx:
iex> Indrajaal.Accounts.list_users()
iex> Indrajaal.Alarms.list_active_alarms()
```

### 5.3 Background Jobs (Oban)

```elixir
# Start Oban jobs manually in IEx
iex> Oban.drain_queue(queue: :default)

# Check job status
iex> Oban.Job |> Indrajaal.Repo.all()
```

---

## 6. Development Workflow

### 6.1 TDG (Test-Driven Generation) Methodology

**MANDATORY**: All new code must follow TDG:

```
┌─────────────────────────────────────────────────────────────┐
│                    TDG Workflow (Ω₄)                        │
├─────────────────────────────────────────────────────────────┤
│  1. TEST FIRST: Write tests BEFORE code                     │
│  2. RED PHASE: Tests must fail initially                    │
│  3. GREEN PHASE: Write minimum code to pass                 │
│  4. REFACTOR: Improve while maintaining coverage            │
│  5. COMPILE GATE: 0 errors, 0 warnings                      │
│  6. VALIDATE: Run agent_code_validator.exs                  │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Creating a New Feature

**Step 1: Write Tests First**
```elixir
# test/indrajaal/alarms/alarm_test.exs
defmodule Indrajaal.Alarms.AlarmTest do
  use Indrajaal.DataCase, async: true

  describe "create_alarm/1" do
    test "creates alarm with valid attributes" do
      attrs = %{name: "Test Alarm", severity: :high}
      assert {:ok, alarm} = Indrajaal.Alarms.create_alarm(attrs)
      assert alarm.name == "Test Alarm"
    end

    test "fails with invalid attributes" do
      assert {:error, _changeset} = Indrajaal.Alarms.create_alarm(%{})
    end
  end
end
```

**Step 2: Run Tests (Should Fail)**
```bash
mix test test/indrajaal/alarms/alarm_test.exs
# Expected: Failures (RED phase)
```

**Step 3: Implement Code**
```elixir
# lib/indrajaal/alarms.ex
defmodule Indrajaal.Alarms do
  def create_alarm(attrs) do
    # Implementation
  end
end
```

**Step 4: Verify Tests Pass**
```bash
mix test test/indrajaal/alarms/alarm_test.exs
# Expected: All tests pass (GREEN phase)
```

**Step 5: Compile Gate**
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled mix compile --warnings-as-errors
# Expected: 0 errors, 0 warnings
```

### 6.3 Code Quality Checks

```bash
# Format code
mix format

# Run Credo static analysis
mix credo --strict

# Run Dialyzer type checking
mix dialyzer

# Run security scan
mix sobelow --exit

# All gates must pass before commit
mix format --check-formatted && \
mix credo --strict && \
mix dialyzer && \
mix sobelow --exit
```

---

## 7. Testing Procedures

### 7.1 Test Categories

| Category | Criticality | Timeout | Example |
|----------|-------------|---------|---------|
| C1-CRITICAL | Formal verification | 5 min | sil_compliance_test.exs |
| C2-HIGH | Core security | 3 min | auth_security_test.exs |
| C3-MEDIUM | Integration | 2 min | api_test.exs |
| C4-LOW | Demo/Performance | 1 min | demo_test.exs |
| C5-OPTIONAL | General | 30 sec | utility_test.exs |

### 7.2 Running Tests

```bash
# Run all tests (Patient Mode)
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
INFINITE_PATIENCE=true \
MIX_ENV=test mix test

# Run specific test file
MIX_ENV=test mix test test/indrajaal/alarms/alarm_test.exs

# Run with coverage
MIX_ENV=test mix test --cover

# Run CAFE framework execution
MIX_ENV=test mix cafe.execute --parallel --agents=15
```

### 7.3 Property-Based Testing

```elixir
# test/indrajaal/accounts/user_property_test.exs
defmodule Indrajaal.Accounts.UserPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "email normalization is idempotent" do
    check all email <- email_generator() do
      normalized = Indrajaal.Accounts.normalize_email(email)
      assert normalized == Indrajaal.Accounts.normalize_email(normalized)
    end
  end
end
```

### 7.4 Database Sandbox

```elixir
# test/support/data_case.ex
defmodule Indrajaal.DataCase do
  use ExUnit.CaseTemplate

  setup tags do
    Indrajaal.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(
      Indrajaal.Repo,
      shared: not tags[:async]
    )
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
```

---

## 8. Adding New Features

### 8.1 Adding a New Ash Resource

**Step 1: Create the Resource**
```elixir
# lib/indrajaal/alarms/alarm.ex
defmodule Indrajaal.Alarms.Alarm do
  use Ash.Resource,
    domain: Indrajaal.Alarms,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "alarms"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :severity, :atom, constraints: [one_of: [:low, :medium, :high, :critical]]
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :severity]
    end

    update :update do
      accept [:name, :severity]
      require_atomic? false  # Required for function changes
    end
  end
end
```

**Step 2: Register in Domain**
```elixir
# lib/indrajaal/alarms.ex
defmodule Indrajaal.Alarms do
  use Ash.Domain

  resources do
    resource Indrajaal.Alarms.Alarm
  end
end
```

**Step 3: Generate Migration**
```bash
mix ash_postgres.generate_migrations --name create_alarms
mix ecto.migrate
```

### 8.2 Adding an API Endpoint

```elixir
# lib/indrajaal_web/controllers/alarm_controller.ex
defmodule IndrajaalWeb.AlarmController do
  use IndrajaalWeb, :controller

  def index(conn, _params) do
    alarms = Indrajaal.Alarms.list_alarms!()
    json(conn, %{data: alarms})
  end

  def create(conn, %{"alarm" => alarm_params}) do
    case Indrajaal.Alarms.create_alarm(alarm_params) do
      {:ok, alarm} ->
        conn
        |> put_status(:created)
        |> json(%{data: alarm})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: error})
    end
  end
end

# lib/indrajaal_web/router.ex
scope "/api", IndrajaalWeb do
  pipe_through :api
  resources "/alarms", AlarmController, only: [:index, :create]
end
```

### 8.3 Adding a LiveView Component

```elixir
# lib/indrajaal_web/live/alarm_live/index.ex
defmodule IndrajaalWeb.AlarmLive.Index do
  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    alarms = Indrajaal.Alarms.list_alarms!()
    {:ok, assign(socket, :alarms, alarms)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container">
      <h1>Alarms</h1>
      <ul>
        <%= for alarm <- @alarms do %>
          <li><%= alarm.name %> - <%= alarm.severity %></li>
        <% end %>
      </ul>
    </div>
    """
  end
end
```

---

## 9. Deployment

### 9.1 Building a Release

```bash
# Build production release
MIX_ENV=prod mix release

# The release is created at:
# _build/prod/rel/indrajaal/
```

### 9.2 Docker/Podman Production Build

```dockerfile
# Dockerfile.prod
FROM localhost/elixir-base:1.19.2-otp28 AS builder

WORKDIR /app
ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY . .
RUN mix compile
RUN mix assets.deploy
RUN mix release

# Runtime stage
FROM localhost/runtime-base:nixos

COPY --from=builder /app/_build/prod/rel/indrajaal ./
CMD ["bin/indrajaal", "start"]
```

### 9.3 Environment Variables for Production

```bash
# Required production environment variables
DATABASE_URL="ecto://user:pass@host:5433/indrajaal_prod"
SECRET_KEY_BASE="<64+ character secret>"
PHX_HOST="your-domain.com"
PHX_PORT="4000"
POOL_SIZE="20"

# SOPv5.11 Framework Settings
SOPV511_FRAMEWORK_ENABLED=true
STAMP_SAFETY_ENABLED=true
```

### 9.4 Running Migrations in Production

```bash
# Run migrations
./bin/indrajaal eval "Indrajaal.Release.migrate()"

# Or using the release command
./bin/indrajaal rpc "Indrajaal.Release.migrate()"
```

---

## 10. Troubleshooting

### 10.1 Common Compilation Errors

**Error: Undefined function**
```elixir
# EP-AGT-001: Check for missing imports
import Indrajaal.SomeModule

# Or use full module path
Indrajaal.SomeModule.function()
```

**Error: Missing require_atomic? directive**
```elixir
# EP-AGT-007: Add to update actions
update :update do
  accept [:field]
  require_atomic? false  # Required for function-based changes
end
```

### 10.2 Database Connection Issues

```bash
# Check PostgreSQL is running
podman ps | grep postgres

# Verify connection settings
psql -h localhost -p 5433 -U postgres -d indrajaal_dev

# Reset database
mix ecto.drop && mix ecto.create && mix ecto.migrate
```

### 10.3 Container Issues

```bash
# View container logs
podman logs indrajaal-app-demo --tail 100

# Restart containers
podman-compose down && podman-compose up -d

# Check container health
podman inspect indrajaal-app-demo | jq '.[0].State.Health'
```

### 10.4 Test Failures

```bash
# Run with verbose output
MIX_ENV=test mix test --trace

# Run specific test with debugging
MIX_ENV=test mix test test/indrajaal/alarms_test.exs:42 --trace

# Clear test build
rm -rf _build/test && MIX_ENV=test mix compile
```

### 10.5 STAMP Constraint Violations

| Constraint | Violation | Resolution |
|------------|-----------|------------|
| SC-VAL-001 | Timeout during compilation | Use Patient Mode flags |
| SC-CNT-010 | External registry | Use localhost/ prefix |
| SC-AGT-018 | Deadlock detected | Check resource ordering |
| SC-VAL-003 | Consensus failure | Verify all 5 methods agree |

### 10.6 Patient Mode Compilation

```bash
# Always use full Patient Mode for compilation
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --warnings-as-errors 2>&1 | tee -a ./data/tmp/1-compile.log

# FORBIDDEN: Simple compilation without Patient Mode
mix compile  # VIOLATION of SC-VAL-001
```

---

## Appendix A: Quick Reference Commands

```bash
# Development
mix phx.server              # Start dev server
iex -S mix phx.server       # Start with IEx
mix deps.get                # Install dependencies

# Database
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Reset database
mix ecto.gen.migration NAME # Generate migration

# Testing
mix test                    # Run all tests
mix test --cover            # Run with coverage
mix cafe.execute            # Run CAFE framework

# Code Quality
mix format                  # Format code
mix credo --strict          # Static analysis
mix dialyzer                # Type checking
mix sobelow                 # Security scan

# Containers
podman-compose up -d        # Start containers
podman-compose down         # Stop containers
podman logs CONTAINER       # View logs

# Release
MIX_ENV=prod mix release    # Build release
./bin/indrajaal start       # Start release
```

---

## Appendix B: Directory Structure

```
indrajaal/
├── lib/
│   ├── indrajaal/           # Business logic
│   │   ├── accounts/        # User accounts domain
│   │   ├── alarms/          # Alarm management
│   │   ├── analytics/       # Analytics engine
│   │   ├── cortex/          # Autonomic system
│   │   ├── cybernetic/      # OODA/GDE framework
│   │   └── coordination/    # Agent coordination
│   └── indrajaal_web/       # Web layer
│       ├── controllers/     # HTTP controllers
│       ├── live/            # LiveView modules
│       └── router.ex        # Route definitions
├── test/
│   ├── indrajaal/           # Unit tests
│   ├── integration/         # Integration tests
│   └── support/             # Test helpers
├── config/                  # Configuration
├── priv/
│   ├── repo/               # Database files
│   │   └── migrations/     # Ecto migrations
│   └── static/             # Static assets
├── docs/                   # Documentation
├── scripts/                # Utility scripts
├── containers/             # Container definitions
├── mix.exs                 # Project definition
├── devenv.nix              # Development environment
└── podman-compose.yml      # Container orchestration
```

---

**Document Version**: 1.0.0
**Framework Compliance**: SOPv5.11 + TPS + STAMP + TDG + GDE
**Generated By**: Claude Code (Opus 4.5)
