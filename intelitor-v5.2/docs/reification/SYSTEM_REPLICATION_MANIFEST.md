# Fractal System Replication Manifest & User Guide
**Version**: 21.3.0-SIL6
**Status**: REIFIED
**Mandate**: Absolute System Continuity

---

## 🧬 I. Architectural Blueprint (Fractal Detail)

### Layer 0: The Substrate (Infrastructure)
- **Engine**: Podman v5.4.1+ (Rootless).
- **Control Plane**: Zenoh 1.0.0 Mesh (2oo3 Quorum).
- **Identity**: Tailscale Identity-Based Networking.
- **Persistence**: 
  - `sqlite`: Atomic holon state (WAL Mode).
  - `duckdb`: Evolutionary lineage (Columnar).
  - `postgres`: Transactional business data (v17 + TimescaleDB).

### Layer 1: The Morphogenesis (Functional)
- **Elixir/OTP**: 1.19+ / 28.
- **Ash Framework**: 3.x (Declarative Resource Graph).
- **Communication**: Unified Control Bus (Async).

### Layer 2: The Cognitive Plane (Intelligence)
- **Cortex**: F# Cognitive Plane Bridge.
- **Agents**: 50 logical holons executing OODA cycles.
- **Oracle**: OpenRouter bicameral integration.

---

## 🚀 II. Reconstruction Instructions (From Scratch)

### 1. Substrate Ignition
```bash
# 1. Enter environment
devenv shell

# 2. Rebuild F# Orchestrator
cepaf-build

# 3. Ignite 15-container SIL-6 Mesh
sa-up
```

### 2. Genetic Seeding
```bash
# 1. Initialize Database & Identities
mix setup

# 2. Verify Homeostasis
sa-status && sa-health
```

### 3. Verification & GA Readiness
```bash
# 1. Execute Command Verifier
elixir scripts/ga-release/runtime_command_verifier.exs
```

---

## 🔑 III. Identity Registry (Secure Metadata)

| Component | Port | User | Secret Path |
|---|---|---|---|
| **Phoenix** | 4000 | admin@indrajaal.ai | `data/secrets/identity_registry.json` |
| **PostgreSQL** | 5433 | postgres | `data/secrets/identity_registry.json` |
| **Grafana** | 3000 | admin | `data/secrets/identity_registry.json` |
| **Zenoh** | 7447 | N/A | `config/zenoh/` |

---

## 📊 IV. Operational User Guide

### 1. Task Management
- **View Tasks**: `sa-plan list`
- **Add Task**: `sa-plan add "Description" P1`
- **Update Task**: `sa-plan update <id> Completed`

### 2. Mesh Control
- **Restart Mesh**: `sa-up`
- **Stop Mesh**: `sa-down`
- **Clean Volumes**: `sa-mesh clean`
- **Emergency Stop**: `sa-emergency`

### 3. Quality Control
- **Build**: `compile-strict`
- **Test**: `test-cover`
- **Quality**: `quality-full`

---

## 🔄 V. Session State Persistence
To recreate this session state after a restart:
1. Read `AGENT_BOOTSTRAP.md`.
2. Load `data/secrets/identity_registry.json`.
3. Ingest `docs/journal/20260321-1135-fractal-system-reification.md`.
4. Run `sa-plan status`.

**SYSTEM REIFICATION COMPLETE. THRESHOLD ACHIEVED.**
