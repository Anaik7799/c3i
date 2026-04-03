# Next-Generation Features Roadmap

**Date**: 2025-12-29T15:00:00+01:00
**Status**: ACTIVE DEVELOPMENT
**Framework**: SOPv5.11 + STAMP + Biomorphic Architecture

---

## Executive Summary

Transform Intelitor (monitoring tool) into Indrajaal (Cybernetic Organism) - a living, breathing Fractal Mesh where every component ("Holon") possesses local autonomy, health awareness ("Vital Signs"), and connection to the whole ("Indra's Net").

---

## Tier 1: Biomorphic Architecture (High Priority)

| Feature | Description | Status | STAMP |
|---------|-------------|--------|-------|
| **Holon System** | Autonomous units with self-healing, local decision-making | Design Complete | SC-BIO-001 |
| **Membrane Wrapping** | Protection boundaries around domain APIs | In Progress | SC-BIO-002 |
| **Vital Signs** | Real-time health metrics (not boolean) for all components | 70% | SC-BIO-003 |
| **Fractal Mesh** | Self-similar patterns at System→Cluster→Node→Process levels | F# Complete | SC-FRAC-001 |

### Key Files
- `lib/indrajaal/cockpit/prajna/bio/holon.ex`
- `lib/indrajaal/cockpit/prajna/bio/membrane.ex`
- `lib/cepaf/src/Cepaf/Cockpit/FractalIntegration.fs`

---

## Tier 2: Cognitive Cortex (Active Development)

| Feature | Description | Status | STAMP |
|---------|-------------|--------|-------|
| **OODA Loops** | <100ms decision cycles with AI-assisted orientation | Active | SC-OODA-001 |
| **Synapse** | Neural communication between components | Implemented | SC-CORTEX-001 |
| **Homeostasis Controller** | CEA-based stability management | F# Complete | SC-CEA-001 |
| **GDE (Goal-Directed Evolution)** | Self-evolving code with Guardian validation | Design Phase | SC-GDE-001 |

### Key Files
- `lib/indrajaal/cortex/controller.ex`
- `lib/indrajaal/cortex/fast_ooda.ex`
- `lib/indrajaal/cortex/synapse.ex`
- `lib/indrajaal/cortex/homeostasis/controller.ex`
- `lib/cepaf/src/Cepaf/Cockpit/FractalIntegration.fs` (CeaController)

### OODA Cycle Architecture
```
┌─────────────────────────────────────────────────┐
│                  OODA LOOP (<100ms)             │
├─────────────────────────────────────────────────┤
│  OBSERVE → ORIENT → DECIDE → ACT → OBSERVE...  │
│     ↓         ↓         ↓        ↓              │
│  Sensors   Context   Rules    Effectors         │
│  (Telemetry) (SA)    (AI)    (Actions)          │
└─────────────────────────────────────────────────┘
```

---

## Tier 3: Prajna Cockpit (C3I Console)

| Feature | Description | Status | STAMP |
|---------|-------------|--------|-------|
| **Dark Cockpit Mode** | Exception-based UI (only show anomalies) | Implemented | SC-PRAJNA-001 |
| **AI Copilot** | OpenRouter-powered intelligent assistant | Implemented | SC-PRAJNA-002 |
| **Situational Awareness** | SA-1/2/3 level perception/comprehension/projection | F# Complete | SC-SA-001 |
| **Neuro Spine** | Reflex system for automated responses | Implemented | SC-NEURO-001 |

### Key Files
- `lib/indrajaal/cockpit/prajna/dark_cockpit.ex`
- `lib/indrajaal/cockpit/prajna/ai_copilot.ex`
- `lib/indrajaal/cockpit/prajna/neuro/spine.ex`
- `lib/indrajaal_web/live/prajna_live.ex`
- `lib/cepaf/src/Cepaf/Cockpit/SituationalAwareness.fs`

### Situational Awareness Levels
```
SA-3: PROJECTION    ─── Predict future states
  ↑
SA-2: COMPREHENSION ─── Understand current meaning
  ↑
SA-1: PERCEPTION    ─── Observe raw data
```

---

## Tier 4: Distributed Mesh (Planned)

| Feature | Description | Status | STAMP |
|---------|-------------|--------|-------|
| **Tailscale Mesh** | Multi-node distributed architecture | Planned | SC-MESH-001 |
| **Zenoh Integration** | Pub/sub data-centric networking | F# Complete | SC-ZENOH-001 |
| **FLAME Scaling** | Dynamic horizontal scaling with fly.io | Designed | SC-FLAME-001 |
| **Multi-Backend** | K8s, Proxmox, Podman capability routing | Prototype | SC-CAP-001 |

### Key Files
- `lib/indrajaal/cluster/zenoh_mesh.ex`
- `lib/indrajaal/cluster/tailscale_dns.ex`
- `lib/indrajaal/distributed/distributed_mesh.ex`
- `lib/cepaf/src/Cepaf/Zenoh/ZenohChannel.fs`

### Mesh Architecture
```
┌──────────────────────────────────────────────────────┐
│                    INDRAJAAL MESH                    │
├──────────────────────────────────────────────────────┤
│  ┌─────────┐     ┌─────────┐     ┌─────────┐        │
│  │ Node-1  │────│ Node-2  │────│ Node-3  │        │
│  │(Primary)│     │(Replica)│     │(Worker) │        │
│  └────┬────┘     └────┬────┘     └────┬────┘        │
│       │              │              │               │
│       └──────────────┼──────────────┘               │
│                      │                               │
│              ┌───────▼───────┐                      │
│              │  Zenoh Pub/Sub │                      │
│              │  (Data-Centric)│                      │
│              └───────────────┘                      │
└──────────────────────────────────────────────────────┘
```

---

## Tier 5: Formal Verification (Active)

| Feature | Description | Status | STAMP |
|---------|-------------|--------|-------|
| **Triple-Layer Pyramid** | Quint + Agda + ExUnit verification | In Progress | SC-FORMAL-001 |
| **STAMP Constraints** | 277 safety constraints enforced | Active | SC-*-* |
| **Property-Based Testing** | PropCheck + ExUnitProperties dual-mode | Implemented | SC-PROP-023 |
| **FMEA Hazard Analysis** | Failure mode classification | Added | SC-FMEA-001 |

### Verification Pyramid
```
        ▲
       /│\      Agda (Type Theory)
      / │ \     ─────────────────
     /  │  \    Mathematical proofs
    /   │   \
   /────┼────\  Quint (TLA+)
  /     │     \ ─────────────
 /      │      \ Model checking
/───────┼───────\
│       │       │ ExUnit + PropCheck
│    STAMP      │ ─────────────────
│   TDG/AOR     │ Property-based tests
└───────────────┘
```

---

## Immediate Next Steps (P0/P1)

### P0 - Critical (Today)
1. **Test Suite Stabilization** - Fix remaining variable typos, run full suite
2. **Compilation Verification** - Ensure zero warnings in test files

### P1 - High Priority (This Week)
3. **Holon Refactoring** - Wrap Accounts, Alarms, Access in Holon behaviour
4. **Cortex Activation** - Connect AI interfaces to OODA decision loops
5. **Zenoh Full Integration** - Bridge F# channels to Elixir GenServers

### P2 - Medium Priority (Next Week)
6. **Tailscale Mesh** - Multi-node deployment testing
7. **FLAME Integration** - Dynamic scaling proof-of-concept
8. **Dark Cockpit Polish** - UX refinements for exception-based UI

---

## Metrics & KPIs

| Metric | Current | Target | Delta |
|--------|---------|--------|-------|
| F# Cockpit Tests | 773 | 800+ | +27 |
| STAMP Constraints | 277 | 300 | +23 |
| OODA Cycle Time | ~100ms | <50ms | -50% |
| Holon Coverage | 0% | 100% | +100% |
| Mesh Nodes | 1 | 5+ | +4 |

---

## References

- `docs/plans/20251228-indrajaal-evolution-plan.md`
- `docs/architecture/PRAJNA_5_LEVEL_SPECIFICATION.md`
- `docs/architecture/UNIFIED_AI_PLATFORM_MASTER_SPECIFICATION.md`
- `journal/2025-12/20251229-1400-fractal-cockpit-enhancement-5level.md`
- `CLAUDE.md` (Section 5.0 - STAMP Constraints)
