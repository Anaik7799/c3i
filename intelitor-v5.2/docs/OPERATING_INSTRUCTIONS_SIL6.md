# Indrajaal SIL-6 Operating Instructions

**Version:** v21.3.1-SIL6
**Classification:** SAFETY-CRITICAL OPERATIONAL MANDATE
**Date:** March 24, 2026

## 1. Prerequisites
- **OS:** Linux (NixOS recommended)
- **Engine:** Podman 5.4.1+ (Rootless)
- **Environment:** `devenv shell` must be active
- **Resources:** 20 CPU Cores, 56GB RAM minimum for full 15-container mesh.

## 2. Complete System Setup (Cold Start)
Follow this exact sequence to achieve SIL-6 Homeostasis:

```bash
# Step 1: Clean previous substrate artifacts
sa-clean

# Step 2: Ignite the 15-container Panopticon Mesh
# This establishes the Data, Control, and Cognitive planes.
sa-up

# Step 3: Verify Substrate Handshake
# Ensure Quorum is reached and Zenoh routers are handshaking.
sa-status

# Step 4: Cognitive Bootstrapping
# Load system specs and axioms into the agent context.
# (Automatic for Gemini/Claude if AGENT_BOOTSTRAP.md is read)

# Step 5: Close Quality Gates
mix format
compile-strict
quality-full
```

## 3. Running Autonomous Evolution
To engage the high-assurance morphogenic evolution engine:

```bash
# Step 1: Initialize Task Backlog (Optional - script auto-generates if empty)
sa-plan add "Morphogenic Optimization" P1

# Step 2: Launch the AEE Orchestrator
# Operates Discovery -> Claim -> Fix -> Complete -> Merge loop.
./scripts/automation/sil6_autonomous_evolution.exs
```

## 4. Monitoring & Homeostasis
- **Prajna Cockpit (HMI):** `http://localhost:4000/prajna`
- **Observability (SigNoz):** `http://localhost:3000`
- **System Metrics:** `sa-status` (F#) or `smart_system_state.exs` (Elixir)
- **CPU Set Point:** Ensure metabolic saturation remains at **80%**.

## 5. Safety Protocols & Emergency
- **Emergency Stop:** `sa-emergency` (Halts all mutation and containers < 5s)
- **Veto:** Use the `Guardian` dashboard in Prajna to manually veto AI proposals.
- **Rollback:** `git checkout HEAD~10` (Reverts the last evolution batch).

## 6. Maintenance
- **Credentials:** Consult `docs/credentials_audit_report.md` for local access.
- **State Restoration:** If the session is lost, refer to `docs/STATE_RECREATION_INSTRUCTIONS.md`.

---
**AUTHORITY:** Gemini (Cybernetic Architect)
"Homeostasis is the prerequisite for Singularity."
