# PRAJNA C3I MESH COCKPIT - MASTER SPECIFICATION INDEX

**Version**: 3.0.0-OPERATIONAL
**Status**: 🟢 **FULLY OPERATIONAL**
**Tag**: `prajna-cockpit-20251228-1515`
**Architecture**: Bio-Inspired Fractal Cybernetic System
**Live Endpoint**: http://localhost:4000/cockpit

---

## 🚀 Quick Start

```bash
# Start the system
PHX_SERVER=true PORT=4000 mix phx.server

# Access Prajna Cockpit
open http://localhost:4000/cockpit
```

---

## 🏗️ Architecture & Components

### Elixir Components (Operational)
| Component | Status | Implementation |
|-----------|--------|----------------|
| **Bio Layer - Holon** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/bio/holon.ex` |
| **Bio Layer - Membrane** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/bio/membrane.ex` |
| **Immune Layer - Antibody** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/immune/antibody.ex` |
| **Immune Layer - MARA** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/immune/mara.ex` |
| **Neuro Layer - Spine** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/neuro/spine.ex` |
| **Dark Cockpit** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/dark_cockpit.ex` |
| **Circuit Breaker** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/circuit_breaker.ex` |
| **Smart Metrics** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/smart_metrics.ex` |
| **Orchestrator** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/orchestrator.ex` |
| **AI Copilot** | 🟢 Operational | `lib/indrajaal/cockpit/prajna/ai_copilot.ex` |

### F# CEPAF Components (475 Tests Passing)
| Component | Status | Implementation |
|-----------|--------|----------------|
| **Bio Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **Immune Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **Neuro Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **DarkCockpit Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **CircuitBreaker Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **SmartMetrics Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **Orchestrator Module** | 🟢 Operational | `lib/cepaf/src/Cepaf/Cockpit/Prajna.fs` |
| **Simplex Kernel** | 🟢 Operational | `lib/cepaf/src/Cepaf/Safety/SimplexKernel.fs` |
| **Holon Renderer** | 🟢 Operational | `lib/cepaf/src/Cepaf/UI/HolonRenderer.fs` |

---

## 📚 Documentation Suite

| ID | Document | Description | Status |
|----|----------|-------------|--------|
| **0** | **[README.md](./README.md)** | This index | 🟢 Current |
| **1** | **[PRAJNA_CEPAF_USER_GUIDE.md](./PRAJNA_CEPAF_USER_GUIDE.md)** | F# API Reference | 🟢 Current |
| **2** | **[PRAJNA_USER_GUIDE.md](./PRAJNA_USER_GUIDE.md)** | Elixir User Guide | 🟢 Current |
| **3** | **[PRAJNA_COMMANDS.md](./PRAJNA_COMMANDS.md)** | Quick Command Reference | 🟢 Current |
| 4 | [PRAJNA_5LEVEL_SPECIFICATION.md](./PRAJNA_5LEVEL_SPECIFICATION.md) | Framework & Data Flow | 🟡 Review |
| 5 | [PRAJNA_TUI_COMPONENT_SYSTEM.md](./PRAJNA_TUI_COMPONENT_SYSTEM.md) | Fractal UI Specs | 🟡 Review |
| 6 | [PRAJNA_DARK_UI_COMPONENTS.md](./PRAJNA_DARK_UI_COMPONENTS.md) | 77+ TUI Components | 🟢 Current |
| 7 | [PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md](./PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md) | STAMP Constraints | 🟢 Current |
| 8 | [PRAJNA_BIOMORPHIC_BLUEPRINT.md](./PRAJNA_BIOMORPHIC_BLUEPRINT.md) | Bio Architecture | 🟢 Current |

---

## 🌐 Live Endpoints

| Endpoint | URL | Description |
|----------|-----|-------------|
| **Main Cockpit** | http://localhost:4000/cockpit | Prajna Dashboard |
| **Dashboard** | http://localhost:4000/cockpit/dashboard | Real-time metrics |
| **Startup** | http://localhost:4000/cockpit/startup | Boot sequence |
| **Containers** | http://localhost:4000/cockpit/containers | Container status |
| **Mesh** | http://localhost:4000/cockpit/mesh | 7-Agent mesh |
| **AI Copilot** | http://localhost:4000/cockpit/ai-copilot | AI assistant |
| **Observability** | http://localhost:4000/cockpit/observability | Telemetry |
| **Health** | http://localhost:4000/health | System health |

---

## 🔒 STAMP Safety Constraints

The system is governed by the STAMP framework. See [PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md](./PRAJNA_SAFETY_CRITICAL_IMPLEMENTATION.md).

| Constraint | Description | Status |
|------------|-------------|--------|
| **SC-PRAJNA-001** | Dark Cockpit default mode | 🟢 Verified |
| **SC-PRAJNA-002** | Two-key-turn for critical ops | 🟢 Verified |
| **SC-PRAJNA-003** | Audit trail required | 🟢 Verified |
| **SC-PRAJNA-005** | Graceful degradation (Circuit Breaker) | 🟢 Verified |
| **SC-PRAJNA-006** | Anomaly detection (z-score) | 🟢 Verified |
| **SC-PRAJNA-007** | Message routing with TTL | 🟢 Verified |
| **SC-BIO-001** | Holons must pulse within 10ms | 🟢 Verified |
| **SC-NEURO-001** | Spinal layer cannot delete data | 🟢 Verified |
| **SC-SIMPLEX-001** | Kernel vetoes unsafe commands | 🟢 Verified |

---

## 🧪 Test Coverage

### F# CEPAF Tests
```bash
cd lib/cepaf
dotnet run --project test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary
# Result: 475 tests, 473 pass (Prajna: 90+ tests, 100% pass)
```

### Elixir Tests
```bash
MIX_ENV=test mix test test/indrajaal/cockpit/prajna/
# Result: 192 tests, 188 pass (97.9%)
```

---

## 🏛️ Architecture Overview

```
PRAJNA COCKPIT ARCHITECTURE (v3.0.0)
════════════════════════════════════════════════════════════════════════════════

    ┌─────────────────────────────────────────────────────────────────────────┐
    │                      DARK COCKPIT UI (LiveView)                         │
    │              (Minimal by default - attention only when needed)          │
    │  Routes: /cockpit, /cockpit/dashboard, /cockpit/mesh, /cockpit/ai-*    │
    └─────────────────────────────────────────────────────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
    ┌─────────▼─────────┐  ┌─────────▼─────────┐  ┌─────────▼─────────┐
    │     BIO LAYER     │  │   IMMUNE LAYER    │  │   NEURO LAYER     │
    ├───────────────────┤  ├───────────────────┤  ├───────────────────┤
    │ • Holon           │  │ • Antibody        │  │ • Spine           │
    │ • Membrane        │  │ • MARA            │  │ • Priority        │
    │ • VitalSigns      │  │ • ThreatLevel     │  │ • Routing         │
    │ • Permeability    │  │ • ThreatType      │  │ • TTL             │
    └───────────────────┘  └───────────────────┘  └───────────────────┘
              │                      │                      │
              └──────────────────────┼──────────────────────┘
                                     │
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                        SUPPORT SYSTEMS                                   │
    ├─────────────────────────────────────────────────────────────────────────┤
    │  Circuit Breaker  │  Smart Metrics  │  Orchestrator  │  AI Copilot     │
    └─────────────────────────────────────────────────────────────────────────┘
                                     │
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                      CEPAF F# BRIDGE                                     │
    │              lib/cepaf/src/Cepaf/Cockpit/Prajna.fs                      │
    └─────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Current System State

```
Indrajaal v1.0.3 - Prajna Cockpit Operational
══════════════════════════════════════════════
✅ Phoenix Server: Running on port 4000
✅ Database: PostgreSQL 5433 (26+ hours uptime)
✅ Redis: Healthy (2+ hours uptime)
✅ OODA Loop: Active (cycles completing < 1ms)
✅ Zenoh: KPI Publisher + Control Subscriber active
✅ CEPAF Bridge: Initialized
✅ All probes: Healthy (liveness, readiness, startup)
```

---

## 🔧 Environment Variables

```bash
# Required
export PHX_SERVER=true
export PORT=4000
export DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_dev"

# Optional - OODA Loop Tuning
export PRAJNA_OODA_TARGET_MS=100
export PRAJNA_ALARM_LATENCY_MS=50
export PRAJNA_CACHE_HIT_TARGET=0.95

# Optional - Neuro-Symbolic Features
export PRAJNA_SPINE_ENABLED=true
export PRAJNA_CORTEX_PROVIDER=openrouter
export PRAJNA_IMMUNE_SYSTEM=active
```

---

**Last Updated**: 2025-12-28T15:15:00+01:00
**Tag**: `prajna-cockpit-20251228-1515`
