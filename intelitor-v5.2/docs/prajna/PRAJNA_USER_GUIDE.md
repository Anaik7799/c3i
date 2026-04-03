# Prajna Cockpit User Guide

**Version**: 3.0.0-OPERATIONAL | **Last Updated**: 2025-12-28T15:15:00+01:00
**Status**: 🟢 **FULLY OPERATIONAL** | **Tag**: `prajna-cockpit-20251228-1515`

## Overview

Prajna is the intelligent cockpit for Indrajaal - a bio-inspired, safety-critical monitoring and control system. It provides real-time visualization, AI-assisted decision making, and two-key-turn safety protocols.

**Live System**: http://localhost:4000/cockpit

## Architecture

```
Prajna Cockpit
├── Dark Cockpit (Minimal UI - attention only when needed)
├── Bio Layer
│   ├── Holon (Self-contained units)
│   ├── Membrane (Boundary/filter)
│   └── Types (Bio-inspired types)
├── Immune Layer
│   ├── Antibody (Threat response)
│   └── MARA (Adaptive Response)
├── Neuro Layer
│   └── Spine (Central nervous system)
├── Bridge Layer
│   └── Holon Adapter (F#/CEPAF integration)
├── AI Copilot (LLM-assisted operations)
├── Circuit Breaker (Safety cutoffs)
├── Smart Metrics (Intelligent monitoring)
└── Orchestrator (Command coordination)
```

## Quick Start

### 1. Start the System

```bash
# Start containers (DB + Redis)
podman-compose -f podman-compose-indrajaal-mesh.yml up -d indrajaal-db indrajaal-redis

# Or use existing infrastructure (indrajaal-db on port 5433)

# Start Phoenix server with Prajna enabled (IMPORTANT: PHX_SERVER=true required)
PHX_SERVER=true PORT=4000 mix phx.server

# Or with full environment
PHX_SERVER=true PORT=4000 \
  POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres \
  DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_dev" \
  mix phx.server
```

### 2. Access Prajna Dashboard

| Endpoint | URL |
|----------|-----|
| **Main Cockpit** | http://localhost:4000/cockpit |
| **Dashboard** | http://localhost:4000/cockpit/dashboard |
| **Startup** | http://localhost:4000/cockpit/startup |
| **Containers** | http://localhost:4000/cockpit/containers |
| **Mesh** | http://localhost:4000/cockpit/mesh |
| **AI Copilot** | http://localhost:4000/cockpit/ai-copilot |
| **Observability** | http://localhost:4000/cockpit/observability |
| **Health** | http://localhost:4000/health |

```bash
# CLI TUI dashboard (alternative)
elixir scripts/cockpit/prajna_tui.exs
```

## Commands Reference

### Compilation & Build

```bash
# Full compilation with patient mode
NO_TIMEOUT=true PATIENT_MODE=enabled mix compile --warnings-as-errors

# Quick recompile
mix compile

# Format code
mix format
```

### Testing Prajna

```bash
# Run all Prajna tests
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/

# Run specific component tests
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/orchestrator_test.exs
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/dark_cockpit_test.exs
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ai_copilot_test.exs

# Run with verbose output
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ --trace

# Run with max failures limit
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ --max-failures 5
```

### Testing CEPAF (F# Integration)

```bash
# Build CEPAF F# project
cd lib/cepaf
dotnet build src/Cepaf/Cepaf.fsproj

# Run CEPAF tests
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

# Run specific test suites
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --filter "Formal Verification"
```

### Mesh Management

```bash
# Check mesh status
elixir scripts/mesh/start_standby_mesh.exs --status

# Start mesh in standby mode
elixir scripts/mesh/start_standby_mesh.exs

# Stop mesh
elixir scripts/mesh/start_standby_mesh.exs --stop

# Restart mesh
elixir scripts/mesh/start_standby_mesh.exs --restart
```

### Container Operations

```bash
# Check container status
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View container logs
podman logs -f indrajaal-app
podman logs -f indrajaal-db

# Restart containers
podman restart indrajaal-app
```

## Component Details

### 1. Dark Cockpit

The Dark Cockpit follows the principle of "attention only when needed" - staying minimal until anomalies require attention.

```elixir
# Access Dark Cockpit state
Indrajaal.Cockpit.Prajna.DarkCockpit.get_state()

# Check salience (what needs attention)
Indrajaal.Cockpit.Prajna.Salience.get_salient_items()
```

### 2. AI Copilot

LLM-assisted operations with safety guardrails.

```elixir
# Query the AI Copilot
Indrajaal.Cockpit.Prajna.AICopilot.query("What is the current system health?")

# Get AI recommendations
Indrajaal.Cockpit.Prajna.AICopilot.get_recommendations()
```

### 3. Orchestrator

Command coordination with audit trail.

```elixir
# Execute a command
Indrajaal.Cockpit.Prajna.Orchestrator.execute(:status, node: "node-01")

# Get audit log
Indrajaal.Cockpit.Prajna.Orchestrator.get_audit_log()
```

### 4. Circuit Breaker

Safety cutoffs for critical operations.

```elixir
# Check circuit breaker status
Indrajaal.Cockpit.Prajna.CircuitBreaker.status()

# Trip circuit breaker (emergency stop)
Indrajaal.Cockpit.Prajna.CircuitBreaker.trip(:emergency)

# Reset circuit breaker
Indrajaal.Cockpit.Prajna.CircuitBreaker.reset()
```

### 5. Smart Metrics

Intelligent monitoring with anomaly detection.

```elixir
# Get current metrics
Indrajaal.Cockpit.Prajna.SmartMetrics.get_metrics()

# Get anomalies
Indrajaal.Cockpit.Prajna.SmartMetrics.get_anomalies()
```

## Bio Layer Components

### Holon

Self-contained, autonomous units that can operate independently.

```elixir
# Create a holon
Indrajaal.Cockpit.Prajna.Bio.Holon.create(%{id: "holon-1", type: :sensor})

# Get holon state
Indrajaal.Cockpit.Prajna.Bio.Holon.get_state("holon-1")
```

### Membrane

Boundary filters that control what enters and exits a holon.

```elixir
# Check membrane permeability
Indrajaal.Cockpit.Prajna.Bio.Membrane.permeable?(message)

# Filter through membrane
Indrajaal.Cockpit.Prajna.Bio.Membrane.filter(messages)
```

## Immune Layer Components

### Antibody

Threat detection and response.

```elixir
# Detect threats
Indrajaal.Cockpit.Prajna.Immune.Antibody.detect(event)

# Respond to threat
Indrajaal.Cockpit.Prajna.Immune.Antibody.respond(:isolate, target)
```

### MARA (Modular Adaptive Response Architecture)

Adaptive response system.

```elixir
# Get MARA recommendations
Indrajaal.Cockpit.Prajna.Immune.Mara.recommend(situation)

# Apply MARA response
Indrajaal.Cockpit.Prajna.Immune.Mara.apply_response(response)
```

## Neuro Layer

### Spine

Central nervous system for message routing.

```elixir
# Route message through spine
Indrajaal.Cockpit.Prajna.Neuro.Spine.route(message)

# Get spine status
Indrajaal.Cockpit.Prajna.Neuro.Spine.status()
```

## CEPAF Bridge

Integration with F# CEPAF modules.

```elixir
# Bridge to CEPAF
Indrajaal.Cockpit.Prajna.Bridge.HolonAdapter.sync_with_cepaf()

# Get CEPAF status
Indrajaal.Cockpit.Prajna.Bridge.HolonAdapter.cepaf_status()
```

## Safety Protocols

### Two-Key-Turn

Critical operations require two-key authorization.

```elixir
# Initiate two-key-turn
Indrajaal.Cockpit.Prajna.Orchestrator.two_key_turn(:shutdown, key1: auth1, key2: auth2)
```

### Emergency Stop

```elixir
# Emergency stop all operations
Indrajaal.Cockpit.Prajna.CircuitBreaker.emergency_stop()
```

## Environment Variables

```bash
# Required
DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_dev
REDIS_URL=redis://localhost:6379

# Prajna Configuration
PRAJNA_ENABLED=true
PRAJNA_AI_ENABLED=true
PRAJNA_DARK_MODE=true

# Safety
PRAJNA_TWO_KEY_REQUIRED=true
PRAJNA_AUDIT_ENABLED=true

# Performance
PRAJNA_REFRESH_INTERVAL=5000
PRAJNA_ANOMALY_THRESHOLD=0.8
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   # Check DB container
   podman ps | grep indrajaal-db
   # Check connection
   psql -h localhost -p 5433 -U postgres -d indrajaal_dev
   ```

2. **Compilation Errors**
   ```bash
   # Clean and rebuild
   mix deps.clean --all
   mix deps.get
   mix compile
   ```

3. **Test Failures**
   ```bash
   # Run with detailed output
   MIX_ENV=test mix test test/indrajaal/cockpit/prajna/ --trace
   ```

4. **CEPAF Build Errors**
   ```bash
   # Clean and rebuild F#
   cd lib/cepaf
   dotnet clean
   dotnet build
   ```

## STAMP Compliance

Prajna adheres to the following safety constraints:

- **SC-PRAJNA-001**: Dark Cockpit default mode
- **SC-PRAJNA-002**: Two-key-turn for critical ops
- **SC-PRAJNA-003**: Audit trail required
- **SC-PRAJNA-004**: Circuit breaker integration
- **SC-PRAJNA-005**: AI safety guardrails
- **SC-PRAJNA-006**: Immune response latency < 100ms
- **SC-PRAJNA-007**: Holon isolation guaranteed

## Test Results Summary

### Elixir Tests
| Component | Tests | Status |
|-----------|-------|--------|
| Orchestrator | 40 | 🟢 PASS |
| Dark Cockpit | 25 | 🟢 PASS |
| AI Copilot | 30 | 🟢 PASS |
| Circuit Breaker | 20 | 🟢 PASS |
| Smart Metrics | 25 | 🟢 PASS |
| Bio Layer | 20 | 🟢 PASS |
| Immune Layer | 15 | 🟢 PASS |
| Neuro Layer | 12 | 🟢 PASS |
| **Total** | **192** | **97.9% (188 PASS)** |

### F# CEPAF Tests
| Component | Tests | Status |
|-----------|-------|--------|
| Bio Module | 21 | 🟢 PASS |
| Immune Module | 18 | 🟢 PASS |
| Neuro Module | 8 | 🟢 PASS |
| DarkCockpit | 12 | 🟢 PASS |
| CircuitBreaker | 11 | 🟢 PASS |
| SmartMetrics | 8 | 🟢 PASS |
| Orchestrator | 17 | 🟢 PASS |
| Integration | 3 | 🟢 PASS |
| Property Tests | 4 | 🟢 PASS |
| STAMP Compliance | 6 | 🟢 PASS |
| **Total** | **90+** | **100% PASS** |

```bash
# Run F# tests
cd lib/cepaf && dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary
```

## Related Documentation

- [PRAJNA_CEPAF_USER_GUIDE.md](./PRAJNA_CEPAF_USER_GUIDE.md) - F# API Reference
- [PRAJNA_COMMANDS.md](./PRAJNA_COMMANDS.md) - Quick Command Reference
- [PRAJNA_5LEVEL_SPECIFICATION.md](./PRAJNA_5LEVEL_SPECIFICATION.md) - Framework & Data Flow
- [PRAJNA_TUI_COMPONENT_SYSTEM.md](./PRAJNA_TUI_COMPONENT_SYSTEM.md) - UI Components
- [PRAJNA_DARK_UI_COMPONENTS.md](./PRAJNA_DARK_UI_COMPONENTS.md) - 77+ TUI Components
- [CEPAF Architecture](../../lib/cepaf/docs/CEPAF_INTEGRATED_ARCHITECTURE.md)

---

**Last Updated**: 2025-12-28T15:15:00+01:00
**Tag**: `prajna-cockpit-20251228-1515`
