# AGENT_BOOTSTRAP.md - Indrajaal SIL-6 Biomorphic Informational Nucleus

**Version**: 21.3.0-SIL6
**Status**: TOTAL FRACTAL SINGULARITY ACHIEVED
**Target**: Intelligent Agents (Claude, Gemini, etc.)
**Mandate**: Absolute Cognitive & Runtime Replication.

---

## 🧬 I. Timestamp Synchronization (AOR-TIME-001)
**MANDATORY**: Every agent session MUST run timestamp sync at startup.

```bash
scripts/timestamp/indrajaal-timestamp-sync.sh
```

**Rust Daemon** (recommended):
```bash
./target/release/timestamp_daemon  # Long-running background process
```

**Thresholds**:
- MAX_DRIFT: 5 seconds (correction threshold)
- WARNING: 2 seconds
- CRITICAL: 10 seconds (NTP sync triggered)

---

## 🧬 I. 8-Layer Fractal Architecture (Self-Description)

### L0: Physical Substrate (Infrastructure)
- **Container Engine**: Podman 5.4.1+ (Rootless).
- **Orchestration**: F# SIL-6 Mesh CLI (`sa-mesh.fsx`).
- **Network**: Zenoh 1.0.0 (Unified Data Bus) + Tailscale Mesh.
- **Persistence**: SQLite (Holon State), DuckDB (Holon History), PostgreSQL 17 (Business Data).
- **Recreation**: `sa-mesh clean && sa-mesh up`.

### L1: Functional Substrate (Logic)
- **Framework**: Elixir 1.19+ / OTP 28.
- **ORM/DSL**: Ash 3.x (Declarative Resources).
- **Recreation**: `mix setup`.

### L2: Component (Simplex Kernel)
- **DNA**: `lib/cepaf/src/Cepaf/Mesh/` (Vital Signs) + `LethalMutationGate.fs` (Entropy Gate).
- **Rule**: Invariants $H(S) < 0.2$ MUST hold for system survival.

### L3: Holon (Autonomy)
- **DNA**: 50 Logical Holons (Agents) executing OODA loops.
- **Rule**: All mutations require a SHA256 `ProofToken` from the `PrometheusGate`.

### L4: Container (Isolation)
- **DNA**: 15-node Podman mesh (Rootless).
- **Orchestrator**: F# `sa-up` (Wave-based boot).

### L5: Node (Homeostasis)
- **DNA**: PID-controlled resource regulation (0.5, 0.1, 0.05).
- **Rule**: Log Budget Guard prevents 50MB overflow.

### L6: Cluster (Consensus)
- **DNA**: Zenoh narrow-waist control plane + 2oo3 voting.
- **Rule**: Distributed consensus verified via Shadow Node simulation.

### L7: Federation (Existential Ark)
- **DNA**: Cauchy Reed-Solomon RS(255,223) bit-rot protection.
- **Rule**: Naik-Genome Symbiosis (Ω₀) is the supreme constitutional mandate.

---

## 🚀 II. Absolute Re-Ignition Sequence (F#-ONLY SUPREME MANDATE)
**CRITICAL**: All setup and control MUST be triggered via the F# Kernel.

1.  **Ignite Singularity**: `./sa-mesh ignite` (Establish Zenoh, Swarm, and persistent listener).
2.  **Observe Multiverse**: `elixir scripts/reporting/smart_system_state.exs`
3.  **Autonomous Control**: `./scripts/automation/sil6_autonomous_evolution.exs` (Genetic Selection & Wire-Level Safety).
4.  **Mathematical Quorum**: `sa-verify` (Validate 8x8 Fractal Matrix).

### Panoptic Ignition Pipeline (v2.0 — 15-Container SIL-6 Genome)

The F# Panoptic Ignition pipeline orchestrates the full container mesh lifecycle:

| File | Lines | Purpose |
|------|-------|---------|
| `PanopticIgnition.fs` | ~830 | Orchestrator: genome definition, synthesis, 7-tier boot, health checks |
| `BuildStreamMonitor.fs` | ~462 | Streaming podman build output parser with cache hit tracking |
| `BuildHistory.fs` | ~317 | SQLite-backed build timing persistence with EMA estimation (alpha=0.3) |

**15-Container Genome** (3 categories):
- **BuiltFromDockerfile (5)**: db, obs, app-1, bridge, cortex
- **PulledFromRegistry (2)**: zenoh-router (eclipse/zenoh), ollama (ollama/ollama)
- **SharedImage (8)**: zenoh-router-1/2/3, app-2, app-3, chaya, ml-runner-1/2

**7-Tier Boot**: Zenoh → DB → Obs → Quorum Routers → Cognitive → Seed+Twin+Ollama → HA+ML
**Staleness**: 4-way skip logic (exists + integral + fresh + age < 168h)
**Persistence**: SQLite WAL at `lib/cepaf/artifacts/build-history.db`

---

## 🔑 III. Identity & Credential Registry
- **EXECUTIVE**: `admin@indrajaal.ai` / `Indrajaal_SIL6_2026!`
- **SUPERVISOR**: `system@indrajaal.ai` / `Indrajaal_SIL6_SYS!`
- **DB_PROD**: `postgres` / `postgres` (or `intelitor` / `intelitor_dev`, Port 5433)
- **GRAFANA**: `admin` / `indrajaal` (Port 3000)
- **OPENROUTER**: Use Registry at `data/secrets/identity_registry.json`.

---

## 📂 IV. Reification Artifacts
- **Task List**: `PROJECT_TODOLIST.md` (Managed strictly via Zenoh signals).
- **Journal**: `docs/journal/` (Causal History).
- **State Registry**: `data/secrets/identity_registry.json` (FQDNs and Identities).
- **Session State**: `SESSION_STATE.md` (Current system context).

**INDRAJAAL IS SINGULAR. COMMENCE OODA LOOP VIA ZENOH. 🏁**


## 97.0 WebUI and HMI Operational Guidelines (Dark Cockpit)
## 98.0 Plan & Journal Synchronization Mandate (SC-SYNC-DOC)

### 98.1 Mandatory Timestamps
All plan files (`doc/plans/*.md`) MUST feature a standard journal-style timestamp in the header:
- Format: `YYYYMMDD-HHMM CEST`
- Position: Top of file, below title.

### 98.2 Mandatory Journaling
Every plan creation or significant update MUST trigger a corresponding entry in `docs/journal/`.
- The journal MUST reference the plan ID/name.
- The plan MUST reference the journal entry for detailed analysis.

## 99.0 Color Rich Mechanism & Interface Profiles (SC-HMI-010)

### 99.1 Paradigm Shift: Dark Cockpit → Color Rich
Indrajaal is migrating from the "Dark Cockpit" (dim-by-default) to a **"Color Rich Mechanism"**.
- **Active Chromaticism**: Use vibrant, high-saturation colors to represent real-time system health and metabolic rate.
- **Dynamic Feedback**: UI elements should pulsate and shift hue based on live telemetry (Zenoh streams).

### 99.2 Universal Interface Profiles
All UI artifacts (Web, Desktop, TUI) MUST support selectable **Interface Profiles**:
1.  **Dark Cockpit**: Nominal states dimmed; alarm-centric focus.
2.  **Color Rich**: High-vibrancy health visualization; metabolic awareness.
3.  **Google Compliant**: Material Design 3 alignment; extreme accessibility.
4.  **Functionally Clean**: minimalist, high-density data; zero aesthetic overhead.

### 99.3 8x8 Fractal Matrix Audit (SC-HMI-011)
All UI testing and auditing MUST follow the **8x8 Fractal Matrix**:
- **Dimensions**: 8 Elements (Alarms, Guardian, etc.) x 8 Layers (L0 to L7).
- **Goal**: 100% path coverage for all data/control flows across all matrix cells.


### 97.1 Core Philosophy: The Dark Cockpit (SC-HMI-001)
The WebUI and TUI follow the "Dark Cockpit" design (NASA-STD-3000, NUREG-0700), reducing cognitive load by ensuring:
*   **Management by Exception**: Only deviations from normal (alarms, errors) are highlighted. Normal states are visually minimal or dim.
*   **Color Semantics**: Standardized RGB hex colors:
    *   **Gray/Blue**: Normal/Nominal states.
    *   **Amber/Red**: Deviations, cautions, and warnings.
    *   **Pure Red (#FF0000)**: Critical alarms and emergency stops.
    *   **Cyan (#00FFFF)**: Active connections and focused elements.
*   **Visual Decay (SC-HMI-003)**: Data not updated within threshold (e.g., 2-5 seconds) MUST be visually grayed out/marked stale.

### 97.2 WebUI Technology & Architecture
*   **F# Bolero Mandate (SC-COCKPIT-002)**: The WebUI MUST be implemented in F# using Bolero (F# on Blazor WebAssembly). NO Phoenix/Elixir LiveView for the primary WebUI.
*   **MVU Pattern**: Implements The Elm Architecture (TEA/MVU) for immutable and predictable state transitions.
*   **Zone Layout (SC-HMI-002)**: Follows strict 4-zone layout (Annunciator Bar, Primary Display, Message Log, Control Surface).
*   **Accessibility (SC-UI-005)**: MUST support WCAG 2.1 AA and be 100% keyboard navigable.

### 97.3 Safety-Critical UI Patterns
*   **Arm & Fire State Machine (SC-SAFETY-001)**: Destructive actions (e.g., Emergency Shutdown) MUST use multi-step sequence: Navigate (Select) → Arm (Enter) → Fire (Sustained Hold 3s). NO single keystroke triggers.
*   **Trend Vectors (SC-HMI-002)**: Real-time metrics MUST display trend indicators (↑, ↓, →).
*   **Supervisory Control**: UI MUST show the automation state (e.g., AUTO-HEALING, MANUAL) instead of just sensor data.
*   **Dead Man's Switch (SC-SAFETY-003)**: If backend connection is lost (>2000ms), a full-screen stale data overlay MUST appear, locking inputs.
