# Journal Entry: 20260404-0400 - Full Specification: Visual & Robust Swarm Orchestration

## 1. Metadata
- **Status**: AUTHORITATIVE / SIL-6
- **Task ID**: 8.0, TUI-001 to TUI-006
- **Compliance**: SC-HMI-010, SC-IGNITE-001, SC-BDD-001

## 2. TUI Dashboard Architecture & Diagram

The Rust Ignition TUI is organized into an 8-tab high-fidelity control plane.

### 2.1 Page 0: Swarm Dashboard (Lifecycle Hub)
```text
┌─────────────────────────────────────────────────────────────┐
│ Header: [C3I v21.3.2] | PHASE: Launching | Integrity: 85%   │
│ CoT Ticker: [W2] Launching obs-prod ➜ Success               │
├─────────────────────────────────────────────────────────────┤
│ [ Node 1 ] [ Node 2 ] [ Node 3 ] [ Node 4 ] [ Node 5 ] ...  │
│ (Matrix of health-colored boxes for immediate recognition)  │
├─────────────────────────────────────────────────────────────┤
│ Container | Status  | Boot Transition Graph | Resources     │
│ db-prod   | running | ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰ | CPU: 2% M: 1% │
│ obs-prod  | starting| ▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱ | CPU: 12% M: 5%│
├──────────────────────────────────────┬──────────────────────┤
│ Live Logs: [selected-node]           │ FMEA / Metadata      │
│ [INFO] Ecto migrations finished      │ Role: Database       │
│ [OK]   Listening on 5432             │ Criticality: SIL-6   │
└──────────────────────────────────────┴──────────────────────┘
```

### 2.2 Behavior Specification
| Element | Input | Action | Expected Output |
|:---|:---|:---|:---|
| **Health Matrix** | Telemetry | Periodic Poll | Box colors update (G/Y/R) every 2s. |
| **Transition Graph**| Lifecycle | State Change | 5-stage sparkline reflects `Wait->Pull->Run`. |
| **Selection** | ↑/↓ Keys | Row Select | Updates "Live Logs" and "Metadata" panes. |
| **CoT Ticker** | Trace Log | Event Push | Marquee scrolls latest Agent reasoning step. |

---

## 3. User Journey: "The Panoptic Ignition"

### 3.1 Step 1: Pre-Flight (The Gatekeeper)
- **User**: Runs `./sa-up`.
- **System**: Enters `Preflight` phase.
- **TUI**: Opens to `Checks` tab. Quorum Ring is Red.
- **Result**: 20 critical checks executed. Matrix fills with green checks. Ring turns Yellow as Podman socket responds.

### 3.2 Step 2: Wave-Based Launch (The Synthesis)
- **User**: Monitors `Swarm` tab.
- **System**: Enters `Launching` phase. 
- **TUI**: Sparklines for Wave 0 (Zenoh) begin filling.
- **Robustness**: System detects a stale `cortex` container. User sees "Ghost Purging" in CoT ticker. Row clears, and launch proceeds.

### 3.3 Step 3: Consensus (The Ready State)
- **User**: Switches to `Topology` tab.
- **System**: Nodes turn Green in the DAG as FPPS consensus is reached.
- **TUI**: Quorum Ring in `Checks` tab turns vibrant Green.
- **Completion**: Header flashes "✅ FULL IGNITION COMPLETE".

---

## 4. Detailed BDD (Behavior Driven Development)

### Feature: Robust Container Lifecycle
**Scenario: Automated Recovery of a Ghost Container**
- **Given** the host has a container named `indrajaal-db-prod` in `Stopping` state.
- **When** the Rust Ignition Daemon executes `launch_db()`.
- **Then** the daemon must verify existence via `podman ps --all`.
- **And** execute `podman rm -f indrajaal-db-prod` before the new `run` command.
- **And** the TUI CoT Ticker must display `[Purging] Stale indrajaal-db-prod detected`.

### Feature: Visual Telemetry
**Scenario: Real-Time Resource Monitoring**
- **Given** the swarm is in the `Running` phase.
- **When** the 2s auto-refresh trigger fires.
- **Then** `podman stats --json` must be parsed.
- **And** the `Resources` column in the Swarm table must update with `CPU: X% MEM: Y%`.
- **And** the `Substrate Heatmap` in the Governor tab must update its core matrix.

---

## 5. 100 Ideas Matrix (Ranked Summary)
Refer to:
- `docs/journal/20260404-0330-robust-swarm-analysis.md` (Swarm Robustness)
- `docs/journal/20260404-0330-100-ratatui-ideas.md` (Visual Intuition)

**Total Score Formula**: `Crit x FEMA x Util x Safe x Rob x Frac`

---
**Approval**: Gemini CLI Executive
**Audit**: SC-IGNITE-001 Compliant.
