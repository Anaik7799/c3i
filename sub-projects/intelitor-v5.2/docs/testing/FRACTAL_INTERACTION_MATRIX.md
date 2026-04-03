# FRACTAL INTERACTION MATRIX (9x9)
**Classification**: LEVEL 3 VERIFICATION
**Status**: ACTIVE
**Version**: 1.0.0
**Date**: 2026-01-15

---

## 1.0 MATRIX DEFINITION
This matrix maps the 9 Fractal Levels of the Indrajaal system against the 4 core pillars of the Prajna migration (Prajna, Chaya, Smriti, Indrajaal).

| Level | Prajna (Interface) | Chaya (Twin) | Smriti (Memory) | Indrajaal (Body) | Verification Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **L1: Atomic** | CLI Flags (`--verify`) | `Observation` Types | `Holon` Structs | `mix test` | Unit Tests (Expecto) |
| **L2: Component** | `Spectre.Console` | `SynapseAgent` | `SmritiSubscriber` | `GenServer` | Integration Tests |
| **L3: Holon** | Dashboard Panel | OODA State Machine | Knowledge Node | Supervisor | State Machine Tests |
| **L4: Container** | `cepaf` Binary | `indrajaal-chaya` | `indrajaal-db` | `indrajaal-app` | Health Checks |
| **L5: Node** | User Session | Resource Monitor | SQLite WAL | BEAM VM | Resource Limits |
| **L6: Mesh** | Remote Console | Distributed Trace | Zenoh Topic | Cluster | Connectivity Test |
| **L7: Federation**| Multi-User Auth | Global Policy | Knowledge Graph | Shard | Consistency Check |
| **L8: Ecosystem** | Browser Ext | OpenRouter AI | Vector Search | Webhooks | API Contracts |
| **L9: Universe** | The Archive (Ark) | Evolution History | Deep Time Log | Entropy | Ark Verification |

---

## 2.0 INTERACTION FLOWS

### 2.1 The "Cognitive Loop" (L8 -> L2 -> L6)
1.  **Prajna** (L8) requests insight via CLI.
2.  **Chaya** (L2) `Synapse` formulates prompt.
3.  **Indrajaal** (L8) routes to OpenRouter.
4.  **Chaya** (L2) `Guardian` validates response.
5.  **Smriti** (L6) logs interaction to Zenoh.

### 2.2 The "Healing Reflex" (L4 -> L3 -> L5)
1.  **Indrajaal** (L4) container fails health check.
2.  **Chaya** (L3) OODA loop detects anomaly.
3.  **Prajna** (L3) alerts user via TUI.
4.  **Chaya** (L5) issues restart command.
5.  **Smriti** (L5) records restart event.

### 2.3 The "Knowledge Sync" (L6 -> L7 -> L1)
1.  **Indrajaal** (L6) emits new telemetry.
2.  **Smriti** (L6) `SmritiSubscriber` receives payload.
3.  **Smriti** (L7) updates Knowledge Graph.
4.  **Prajna** (L1) updates status bar.

---

## 3.0 RISK ANALYSIS (FMEA)

| Interaction | Failure Mode | Severity | Detection | Mitigation |
| :--- | :--- | :--- | :--- | :--- |
| **L6 Mesh** | Zenoh Split-Brain | CRITICAL | Heartbeat | Quorum Voting (2oo3) |
| **L8 AI** | Hallucination | HIGH | Guardian | Simplex Architecture |
| **L5 State** | SQLite Lock | MEDIUM | Timeout | WAL Mode / Retry |
| **L1 CLI** | Argument Error | LOW | Parser | Help Text / Defaults |

---

## 4.0 COVERAGE STATUS
*   **L1-L3**: 100% (Verified via `FullSystemVerification.fs`)
*   **L4-L6**: 90% (Mocked Zenoh in CI, Real in Prod)
*   **L7-L9**: 80% (Ark/AI Integration validated, Ecosystem pending)
