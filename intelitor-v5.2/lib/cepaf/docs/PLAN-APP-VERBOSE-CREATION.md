# App Container Creation Plan - Full Verbose/Debug Mode
## Comprehensive Debug Logging for All Components
**Version**: 1.0.0 | **Date**: 2024-12-24 | **Mode**: FULL DEBUG

---

## 1. Debug Configuration Matrix

### 1.1 Environment Variable Debug Settings

```bash
# =============================================================================
# ELIXIR/ERLANG DEBUG
# =============================================================================
ELIXIR_ERL_OPTIONS="+S 10:10 +fnu +W w"      # Warnings as warnings, UTF-8
ERL_FLAGS="+P 10000000 +Q 10000000"          # Max processes/ports for debug
ERL_CRASH_DUMP=/var/log/claude/erl_crash.dump
ERL_CRASH_DUMP_SECONDS=60
ERLANG_COOKIE=debug-cookie-indrajaal

# =============================================================================
# MIX DEBUG
# =============================================================================
MIX_DEBUG=1                                  # Enable Mix debug output
MIX_ENV=test                                 # Test environment
MIX_BUILD_ROOT=/workspace/_build             # Build location
ELIXIR_EDITOR=cat                            # For error display

# =============================================================================
# PHOENIX DEBUG
# =============================================================================
PHX_SERVER=true                              # Start server
PHX_HOST=0.0.0.0
PHX_PORT=4000
DEBUG_ERRORS=true                            # Show debug errors
PLUG_EDITOR=cat
PHOENIX_LIVE_RELOAD=false                    # Disable for debug

# =============================================================================
# LOGGER DEBUG (Elixir)
# =============================================================================
LOGGER_LEVEL=debug                           # Full debug logging
LOGGER_TRUNCATE=infinity                     # No truncation
LOGGER_SYNC_THRESHOLD=1000                   # Sync on every 1000 msgs
LOG_LEVEL=debug

# =============================================================================
# ECTO/DATABASE DEBUG
# =============================================================================
ECTO_DEBUG=true                              # Ecto debug mode
ECTO_POOL_SIZE=5                             # Small pool for debug
POSTGRES_LOG_LEVEL=debug                     # PG debug level
DATABASE_URL=ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone
PGDEBUG=1

# =============================================================================
# OTEL/TELEMETRY DEBUG
# =============================================================================
OTEL_LOG_LEVEL=debug                         # OTEL debug
OTEL_TRACES_EXPORTER=console                 # Export to console
OTEL_METRICS_EXPORTER=console
OTEL_LOGS_EXPORTER=console
OTEL_RESOURCE_ATTRIBUTES="service.name=indrajaal-app-debug"

# =============================================================================
# PATIENT MODE (Required)
# =============================================================================
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true

# =============================================================================
# CEPAF DEBUG
# =============================================================================
CEPAF_DEBUG=1
CEPAF_VERBOSE=1
CEPAF_TRACE=1
CEPAF_LOG_LEVEL=trace

# =============================================================================
# CONTAINER DEBUG
# =============================================================================
CONTAINER_DEBUG=true
CONTAINER_VERBOSE=true
SOPV51_DEBUG=true
```

---

## 2. Component-by-Component Debug Plan

### 2.1 Phase 0: Prerequisites (Full Verbose)

```bash
#!/bin/bash
# P0_PREREQUISITES_DEBUG.sh
set -x  # Enable trace mode

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 0: PREREQUISITES - VERBOSE DEBUG MODE                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P0.1: Image Verification
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P0.1_IMG: Image Verification                                 │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Checking for app image..."
podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.Created}}" | grep -E "sopv51|indrajaal-app" || echo "[ERROR] No app image found"
echo "[DEBUG] Image layers:"
podman inspect localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' 2>/dev/null | head -5
echo "[DEBUG] Image environment:"
podman inspect localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv --format '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' 2>/dev/null | head -20

# P0.2: Network Verification
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P0.2_NET: Network Verification                               │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Listing all networks:"
podman network ls --format "table {{.Name}}\t{{.Driver}}\t{{.ID}}"
echo "[DEBUG] DB network details:"
podman network inspect artifacts_db-standalone-net 2>/dev/null | head -30

# P0.3: Database Health
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P0.3_DB: Database Health Verification                        │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] DB container status:"
podman inspect indrajaal-db-standalone --format 'Name: {{.Name}}\nState: {{.State.Status}}\nHealth: {{.State.Health.Status}}\nPID: {{.State.Pid}}\nStarted: {{.State.StartedAt}}' 2>/dev/null
echo "[DEBUG] DB container logs (last 10 lines):"
podman logs indrajaal-db-standalone 2>&1 | tail -10
echo "[DEBUG] DB port connectivity:"
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/5433' && echo "[OK] Port 5433 reachable" || echo "[ERROR] Port 5433 not reachable"
echo "[DEBUG] pg_isready test:"
podman exec indrajaal-db-standalone pg_isready -U postgres -p 5433 -d indrajaal_standalone 2>&1
```

### 2.2 Phase 1: Container Creation (Full Verbose)

```bash
#!/bin/bash
# P1_CREATION_DEBUG.sh
set -x

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 1: CONTAINER CREATION - VERBOSE DEBUG MODE             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P1.1: Container Creation with full debug
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P1.1_CNT: Container Creation                                 │"
echo "└─────────────────────────────────────────────────────────────┘"

echo "[DEBUG] Pre-creation cleanup..."
podman rm -f indrajaal-app-standalone 2>/dev/null && echo "[DEBUG] Removed existing container" || echo "[DEBUG] No existing container"

echo "[DEBUG] Creating container with verbose settings..."
echo "[DEBUG] Compose file: podman-compose-app-standalone.yml"
echo "[DEBUG] Environment variables being set:"
cat << 'ENVLIST'
  MIX_DEBUG=1
  LOGGER_LEVEL=debug
  ECTO_DEBUG=true
  CEPAF_DEBUG=1
  CEPAF_VERBOSE=1
ENVLIST

echo "[DEBUG] Running podman-compose..."
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf/artifacts
podman-compose -f podman-compose-app-standalone.yml --verbose up -d 2>&1

echo "[DEBUG] Container created. Inspecting..."
podman inspect indrajaal-app-standalone --format '
Container ID: {{.Id}}
Name: {{.Name}}
Image: {{.Config.Image}}
State: {{.State.Status}}
PID: {{.State.Pid}}
Networks: {{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}
Ports: {{range $k, $v := .NetworkSettings.Ports}}{{$k}}->{{range $v}}{{.HostPort}}{{end}} {{end}}
Mounts: {{range .Mounts}}{{.Source}}->{{.Destination}} {{end}}
' 2>/dev/null
```

### 2.3 Phase 2: Setup (Full Verbose)

```bash
#!/bin/bash
# P2_SETUP_DEBUG.sh
# This runs INSIDE the container

set -x
export PS4='[DEBUG ${LINENO}] '

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 2: SETUP - VERBOSE DEBUG MODE                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P2.1: Hex Installation
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P2.1_HEX: Hex Package Manager Installation                   │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Current Hex version (if any):"
mix hex.info 2>&1 || echo "[DEBUG] Hex not installed"
echo "[DEBUG] Installing Hex with verbose output..."
mix local.hex --force --if-missing 2>&1 | while read line; do echo "[HEX] $line"; done
echo "[DEBUG] Hex installation complete. Version:"
mix hex.info 2>&1 | head -5

# P2.2: Rebar Installation
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P2.2_REB: Rebar3 Installation                                │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Installing Rebar with verbose output..."
mix local.rebar --force --if-missing 2>&1 | while read line; do echo "[REBAR] $line"; done
echo "[DEBUG] Rebar location:"
which rebar3 2>/dev/null || echo "[DEBUG] Rebar in Mix archives"

# P2.3: Dependencies Fetch
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P2.3_DEP: Dependencies Fetch                                 │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Current deps status:"
ls -la deps/ 2>/dev/null | head -20 || echo "[DEBUG] No deps directory"
echo "[DEBUG] mix.lock hash:"
md5sum mix.lock 2>/dev/null || echo "[DEBUG] No mix.lock"
echo "[DEBUG] Fetching dependencies with verbose..."
mix deps.get --only test 2>&1 | while read line; do echo "[DEPS.GET] $line"; done
echo "[DEBUG] Dependencies fetched. Count:"
ls deps/ 2>/dev/null | wc -l

# P2.4: Dependencies Compile
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P2.4_CMP: Dependencies Compile                               │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Build directory status:"
ls -la _build/test/lib/ 2>/dev/null | head -10 || echo "[DEBUG] No build directory"
echo "[DEBUG] Compiling dependencies with verbose..."
START_TIME=$(date +%s)
mix deps.compile 2>&1 | while read line; do
    ELAPSED=$(($(date +%s) - START_TIME))
    echo "[DEPS.COMPILE +${ELAPSED}s] $line"
done
echo "[DEBUG] Dependencies compiled. Build libs:"
ls _build/test/lib/ 2>/dev/null | wc -l
```

### 2.4 Phase 3: Database (Full Verbose)

```bash
#!/bin/bash
# P3_DATABASE_DEBUG.sh
set -x
export PS4='[DEBUG ${LINENO}] '

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 3: DATABASE - VERBOSE DEBUG MODE                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P3.1: Database Connectivity
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P3.1_CONN: Database Connectivity Test                        │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] DATABASE_URL: $DATABASE_URL"
echo "[DEBUG] DB_HOST: $DB_HOST"
echo "[DEBUG] PGPORT: $PGPORT"
echo "[DEBUG] Testing pg_isready..."
ATTEMPT=1
while [ $ATTEMPT -le 30 ]; do
    echo "[DEBUG] Attempt $ATTEMPT/30..."
    if pg_isready -h ${DB_HOST:-indrajaal-db-standalone} -p ${PGPORT:-5433} -U postgres 2>&1; then
        echo "[DEBUG] Database is ready!"
        break
    fi
    echo "[DEBUG] Not ready, waiting 2s..."
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
done

# P3.2: Database Creation
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P3.2_CRE: Database Creation                                  │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Existing databases:"
PGPASSWORD=postgres psql -h ${DB_HOST:-indrajaal-db-standalone} -p ${PGPORT:-5433} -U postgres -c "\l" 2>&1 | head -20
echo "[DEBUG] Creating database..."
mix ecto.create 2>&1 | while read line; do echo "[ECTO.CREATE] $line"; done

# P3.3: Migrations
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P3.3_MIG: Database Migrations                                │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Migration files count:"
ls priv/repo/migrations/*.exs 2>/dev/null | wc -l
echo "[DEBUG] Running migrations..."
mix ecto.migrate 2>&1 | while read line; do echo "[ECTO.MIGRATE] $line"; done
echo "[DEBUG] Migration status:"
mix ecto.migrations 2>&1 | head -20
```

### 2.5 Phase 4: Compilation (Full Verbose)

```bash
#!/bin/bash
# P4_COMPILATION_DEBUG.sh
set -x
export PS4='[DEBUG ${LINENO}] '

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 4: COMPILATION - VERBOSE DEBUG MODE                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P4.1: Mix Compile
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P4.1_MIX: Mix Compile (949 files)                            │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Source files count:"
find lib -name "*.ex" 2>/dev/null | wc -l
echo "[DEBUG] Environment:"
echo "  MIX_ENV=$MIX_ENV"
echo "  NO_TIMEOUT=$NO_TIMEOUT"
echo "  PATIENT_MODE=$PATIENT_MODE"
echo "[DEBUG] Starting compilation at $(date)..."
START_TIME=$(date +%s)
mix compile 2>&1 | tee /var/log/claude/compile.log | while read line; do
    ELAPSED=$(($(date +%s) - START_TIME))
    echo "[COMPILE +${ELAPSED}s] $line"
done
END_TIME=$(date +%s)
echo "[DEBUG] Compilation finished at $(date)"
echo "[DEBUG] Total time: $((END_TIME - START_TIME)) seconds"
echo "[DEBUG] Warning count:"
grep -c "warning:" /var/log/claude/compile.log 2>/dev/null || echo "0"
echo "[DEBUG] Error count:"
grep -c "error:" /var/log/claude/compile.log 2>/dev/null || echo "0"

# P4.2: Asset Build
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P4.2_AST: Asset Build                                        │"
echo "└─────────────────────────────────────────────────────────────┘"
if [ -d "assets" ]; then
    echo "[DEBUG] Assets directory exists"
    echo "[DEBUG] package.json contents:"
    head -30 assets/package.json 2>/dev/null
    echo "[DEBUG] Running npm build..."
    cd assets && npm run build 2>&1 | while read line; do echo "[NPM] $line"; done
    cd ..
else
    echo "[DEBUG] No assets directory, skipping"
fi

# P4.3: Phoenix Digest
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P4.3_DIG: Phoenix Digest                                     │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Running phoenix digest..."
mix phx.digest 2>&1 | while read line; do echo "[PHX.DIGEST] $line"; done
echo "[DEBUG] Digest manifest:"
cat priv/static/cache_manifest.json 2>/dev/null | head -20

# P4.4: Warning Analysis
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P4.4_WAR: Warning Analysis                                   │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Extracting warnings from compile.log..."
grep "warning:" /var/log/claude/compile.log 2>/dev/null | head -50
WARN_COUNT=$(grep -c "warning:" /var/log/claude/compile.log 2>/dev/null || echo "0")
echo "[DEBUG] Total warnings: $WARN_COUNT"
if [ "$WARN_COUNT" -gt 0 ]; then
    echo "[WARNING] SC-CMP-025 VIOLATION: $WARN_COUNT warnings found"
else
    echo "[OK] SC-CMP-025 COMPLIANT: Zero warnings"
fi
```

### 2.6 Phase 5: Startup (Full Verbose)

```bash
#!/bin/bash
# P5_STARTUP_DEBUG.sh
set -x
export PS4='[DEBUG ${LINENO}] '

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 5: STARTUP - VERBOSE DEBUG MODE                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P5.1: Phoenix Server Start
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P5.1_PHX: Phoenix Server Start                               │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Phoenix configuration:"
mix run -e 'IO.inspect(Application.get_all_env(:phoenix), limit: :infinity)' 2>&1 | head -50
echo "[DEBUG] Endpoint configuration:"
mix run -e 'IO.inspect(Application.get_env(:indrajaal, IndrajaalWeb.Endpoint), limit: :infinity)' 2>&1 | head -30
echo "[DEBUG] Starting Phoenix server..."
echo "[DEBUG] Command: mix phx.server"
echo "[DEBUG] PHX_HOST=$PHX_HOST PHX_PORT=$PHX_PORT"

# Start with exec to replace shell
exec mix phx.server 2>&1 | while read line; do
    echo "[PHOENIX] $line"
done
```

### 2.7 Phase 6: Health (Full Verbose)

```bash
#!/bin/bash
# P6_HEALTH_DEBUG.sh
set -x

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 6: HEALTH - VERBOSE DEBUG MODE                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P6.1: TCP Port Probe
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P6.1_TCP: TCP Port Probe                                     │"
echo "└─────────────────────────────────────────────────────────────┘"
for PORT in 4000 4001 9568; do
    echo "[DEBUG] Testing port $PORT..."
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/localhost/$PORT" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "[OK] Port $PORT is OPEN"
    else
        echo "[ERROR] Port $PORT is CLOSED"
    fi
done

# P6.2: HTTP Health Endpoint
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P6.2_HTTP: HTTP Health Endpoint                              │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Testing health endpoint with verbose..."
ATTEMPT=1
while [ $ATTEMPT -le 20 ]; do
    echo "[DEBUG] Attempt $ATTEMPT/20..."
    RESPONSE=$(curl -sf -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}s\n" http://localhost:4000/health 2>&1)
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    TIME=$(echo "$RESPONSE" | grep "TIME:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:" | grep -v "TIME:")

    echo "[DEBUG] HTTP Code: $HTTP_CODE"
    echo "[DEBUG] Response Time: $TIME"
    echo "[DEBUG] Body: $BODY"

    if [ "$HTTP_CODE" = "200" ]; then
        echo "[OK] Health check PASSED"
        break
    fi

    echo "[DEBUG] Not ready, waiting 3s..."
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

# P6.3: Log Pattern Matching
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P6.3_LOG: Log Pattern Matching                               │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Checking for startup patterns in logs..."
PATTERNS="Running.*Endpoint|Access.*at http|Compiled|Generated indrajaal"
echo "[DEBUG] Patterns: $PATTERNS"
podman logs indrajaal-app-standalone 2>&1 | grep -E "$PATTERNS" | tail -10
```

### 2.8 Phase 7: Verification (Full Verbose)

```bash
#!/bin/bash
# P7_VERIFICATION_DEBUG.sh
set -x

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PHASE 7: VERIFICATION - VERBOSE DEBUG MODE                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# P7.1: API Endpoint Test
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P7.1_API: API Endpoint Test                                  │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Testing API endpoints..."
for ENDPOINT in "/health" "/api/v1/health" "/dashboard"; do
    echo "[DEBUG] Testing $ENDPOINT..."
    curl -sf -v http://localhost:4000$ENDPOINT 2>&1 | head -30
    echo ""
done

# P7.2: Observability Verification
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P7.2_OBS: Observability Verification                         │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Testing Prometheus metrics endpoint..."
curl -sf http://localhost:9568/metrics 2>&1 | head -30 || echo "[WARN] Metrics endpoint not available"

# P7.3: E2E Test
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ P7.3_E2E: End-to-End Test                                    │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "[DEBUG] Testing database connectivity through app..."
podman exec indrajaal-app-standalone mix run -e '
  IO.puts("[DEBUG] Checking Ecto connection...")
  case Indrajaal.Repo.query("SELECT 1 as test") do
    {:ok, result} -> IO.puts("[OK] Database query successful: #{inspect(result)}")
    {:error, err} -> IO.puts("[ERROR] Database query failed: #{inspect(err)}")
  end
' 2>&1

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  VERIFICATION COMPLETE                                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
```

---

## 3. Complete Debug Compose File

```yaml
# podman-compose-app-debug.yml
# FULL DEBUG/VERBOSE MODE

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
        set -x  # Enable shell debug
        export PS4='[DEBUG:$$:${LINENO}] '

        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  INTELITOR APP - FULL DEBUG MODE                              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo "[DEBUG] Container started at: $(date)"
        echo "[DEBUG] Hostname: $(hostname)"
        echo "[DEBUG] User: $(whoami)"
        echo "[DEBUG] PWD: $(pwd)"
        echo ""

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 2.1] Installing Hex..."
        echo "═══════════════════════════════════════════════════════════════"
        mix local.hex --force --if-missing 2>&1 | sed 's/^/[HEX] /'

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 2.2] Installing Rebar..."
        echo "═══════════════════════════════════════════════════════════════"
        mix local.rebar --force --if-missing 2>&1 | sed 's/^/[REBAR] /'

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 3.1] Waiting for database..."
        echo "═══════════════════════════════════════════════════════════════"
        ATTEMPT=1
        while [ $$ATTEMPT -le 30 ]; do
            echo "[DEBUG] DB connection attempt $$ATTEMPT/30..."
            if pg_isready -h indrajaal-db-standalone -p 5433 -U postgres 2>&1; then
                echo "[DEBUG] Database ready!"
                break
            fi
            sleep 2
            ATTEMPT=$$((ATTEMPT + 1))
        done

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 2.3] Getting dependencies..."
        echo "═══════════════════════════════════════════════════════════════"
        cd /workspace
        mix deps.get --only test 2>&1 | sed 's/^/[DEPS.GET] /'

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 2.4] Compiling dependencies..."
        echo "═══════════════════════════════════════════════════════════════"
        mix deps.compile 2>&1 | sed 's/^/[DEPS.COMPILE] /'

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 3.2] Creating database..."
        echo "═══════════════════════════════════════════════════════════════"
        mix ecto.create 2>&1 | sed 's/^/[ECTO.CREATE] /' || true

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 3.3] Running migrations..."
        echo "═══════════════════════════════════════════════════════════════"
        mix ecto.migrate 2>&1 | sed 's/^/[ECTO.MIGRATE] /' || true

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 4.1] Compiling application (Patient Mode)..."
        echo "═══════════════════════════════════════════════════════════════"
        START_TIME=$$(date +%s)
        mix compile 2>&1 | tee /var/log/claude/compile.log | sed 's/^/[COMPILE] /'
        END_TIME=$$(date +%s)
        echo "[DEBUG] Compilation took $$((END_TIME - START_TIME)) seconds"
        echo "[DEBUG] Warnings: $$(grep -c 'warning:' /var/log/claude/compile.log 2>/dev/null || echo 0)"
        echo "[DEBUG] Errors: $$(grep -c 'error:' /var/log/claude/compile.log 2>/dev/null || echo 0)"

        echo "═══════════════════════════════════════════════════════════════"
        echo "[PHASE 5.1] Starting Phoenix (Debug Mode)..."
        echo "═══════════════════════════════════════════════════════════════"
        echo "[DEBUG] PHX_HOST=$$PHX_HOST PHX_PORT=$$PHX_PORT"
        echo "[DEBUG] LOGGER_LEVEL=$$LOGGER_LEVEL"
        exec mix phx.server 2>&1 | sed 's/^/[PHOENIX] /'

    environment:
      # ELIXIR DEBUG
      ELIXIR_ERL_OPTIONS: "+S 10:10 +fnu +W w"
      MIX_DEBUG: "1"
      MIX_ENV: test

      # LOGGER DEBUG
      LOGGER_LEVEL: debug
      LOG_LEVEL: debug

      # PHOENIX DEBUG
      PHX_HOST: 0.0.0.0
      PHX_PORT: 4000
      DEBUG_ERRORS: "true"
      SECRET_KEY_BASE: debug-secret-key-base-minimum-64-chars-for-phoenix-security

      # DATABASE DEBUG
      DATABASE_URL: ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone
      ECTO_DEBUG: "true"
      DB_HOST: indrajaal-db-standalone
      PGPORT: 5433
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres

      # PATIENT MODE
      NO_TIMEOUT: "true"
      PATIENT_MODE: "enabled"
      INFINITE_PATIENCE: "true"

      # OTEL DEBUG
      OTEL_LOG_LEVEL: debug
      OTEL_TRACES_EXPORTER: console

      # CEPAF DEBUG
      CEPAF_DEBUG: "1"
      CEPAF_VERBOSE: "1"

      # CONTAINER DEBUG
      CONTAINER_DEBUG: "true"
      SOPV51_DEBUG: "true"

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
      retries: 30
      start_period: 300s  # 5 minutes for Patient Mode

    restart: "no"

    labels:
      debug.mode: "full"
      debug.verbose: "true"
```

---

## 4. Execution Commands

### 4.1 Stop Current Container and Start Debug Mode
```bash
# Stop existing container
podman rm -f indrajaal-app-standalone 2>/dev/null

# Start debug container
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf/artifacts
podman-compose -f podman-compose-app-debug.yml up -d

# Follow logs in real-time
podman logs -f indrajaal-app-debug
```

### 4.2 Run Individual Phase Scripts
```bash
# Run prerequisites check
bash /home/an/dev/ver/indrajaal-v5.2/lib/cepaf/scripts/P0_PREREQUISITES_DEBUG.sh

# Check health
bash /home/an/dev/ver/indrajaal-v5.2/lib/cepaf/scripts/P6_HEALTH_DEBUG.sh
```

---

## 5. Log Analysis Commands

```bash
# Extract all DEBUG lines
podman logs indrajaal-app-debug 2>&1 | grep "\[DEBUG\]"

# Extract phase markers
podman logs indrajaal-app-debug 2>&1 | grep "\[PHASE"

# Extract errors
podman logs indrajaal-app-debug 2>&1 | grep -E "\[ERROR\]|error:"

# Extract warnings
podman logs indrajaal-app-debug 2>&1 | grep -E "\[WARN\]|warning:"

# Extract timing info
podman logs indrajaal-app-debug 2>&1 | grep -E "seconds|took|duration"
```

---

**Document Status**: ACTIVE
**Debug Level**: MAXIMUM (All components)
**Last Updated**: 2024-12-24
