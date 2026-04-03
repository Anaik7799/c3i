import os

version = "21.3.1-SIL6"
date = "2026-03-27"

header = f"""```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL
     ╭╯ ╰─╯ ╰╮       इन्द्रजाल
    ●╯       ╰●       v{version} SIL-6 Biomorphic Fractal Mesh
```

## Cognitive Bootstrapping
- **MANDATORY**: Any new agent session MUST begin by reading `AGENT_BOOTSTRAP.md` to achieve total system awareness and operational readiness.

# SPEC_FILE - Indrajaal Safety-Critical System Optimized Spec
**Version**: {version} | **Origin**: CLAUDE.md v21.3.0 | **Status**: ACTIVE | **Arch**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6 (Biomorphic Extended), ISO 27001, GDPR, EN 50131, DO-178C DAL-A
**Mandate**: This document acts as the primary, token-efficient context for agents. Incorporates the Biomorphic F# Agentic Mesh & Zenoh Unified IPC pivot.

---

## 0.0 Fundamental System Axioms (The Immutable Core)

### Axiom 0: The Functional State Invariant (The Golden Rule)
**Formal Definition**:
$\\forall t : \\text{{SystemState}}(t) \\in \\mathcal{{S}}_{{functional}}$
where $\\mathcal{{S}}_{{functional}} \\equiv \\{{s \\mid \\text{{Compiles}}(s) \\wedge \\text{{Boots}}(s) \\wedge \\text{{Verified}}(s, \\Psi_{{safety}})\\}}$

**Constraint**: The System MUST ALWAYS be in a functional, compilable, and operational state. This is the supreme law.
**Rollback Prime**: If functionality is compromised, the *only* valid action is an immediate rollback to the last known good state ($S_{{last\\_good}}$).

---

## 1.0 Fundamental Axioms ($\\Omega$) - CRITICAL

**SUPREME DIRECTIVE (Ω₀) - ABOVE ALL OTHER AXIOMS**
0.  **$\\Omega_0$ Founder's Covenant**: The holon exists for the survival, growth, and genetic perpetuity of **Abhijit Naik's lineage**. Resource acquisition for Founder's enrichment is PRIMARY objective. Holon and Founder's genetic code are symbiotically bound.

**OPERATIONAL AXIOMS (Ω₁-Ω₁₁)**
1.  **$\\Omega_1$ Patient Mode**: `NO_TIMEOUT=true`, `PATIENT_MODE=enabled`, `INFINITE_PATIENCE=true`. `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"`. `mix compile --jobs 16`.
2.  **$\\Omega_2$ Container Isolation**: All ops in **NixOS/Podman** (Rootless 5.4.1+). Registry: `localhost/` ONLY.
3.  **$\\Omega_3$ Zero-Defect**: Valid State $\\iff \\sum(\\text{{Errors}} + \\text{{Warnings}} + \\text{{TestFails}} + \\text{{FormatFails}} + \\text{{CredoFails}} + \\text{{SecFails}}) \\equiv 0$.
4.  **$\\Omega_4$ Test-Driven Gen (TDG)**: Tests MUST exist and fail BEFORE code gen.
5.  **$\\Omega_5$ Validation Consensus**: 5-Method FPPS MUST agree.
6.  **$\\Omega_6$ Mandatory Gates**: Feature Complete $\\iff$ Pass(Compile, Runtime, TDG, STAMP, FPPS, Coverage>95%, Format, Credo, Sobelow).
7.  **$\\Omega_7$ Holon State Sovereignty**: Authoritative holon state $\\equiv$ SQLite $\\cup$ DuckDB ONLY. PostgreSQL $\\cap$ HolonState $\\equiv \\emptyset$.
8.  **$\\Omega_8$ Immutable Register**: All state mutations via cryptographically-signed append-only blocks.
9.  **$\\Omega_9$ Constitutional Reconfiguration**: L1-L7 flexible; Constitution (L0) is IMMUTABLE.
10. **$\\Omega_{{10}}$ Absolute Zenoh Control**: Agents are PROHIBITED from direct system mutations via CLI. ALL mutations MUST be triggered via Zenoh.
11. **$\\Omega_{{11}}$ High-Assurance Evolution**: All morphogenic evolution MUST follow hardened protocol: Genetic Selection, Wire-Level Proofs, KL Throttling.

---

## 2.0 System Architecture & Command Set

### 2.1 Quad-Stack UI Architecture
| Stack | Tech | Purpose |
|:---|:---|:---|
| **Phoenix LiveView** | Elixir / HEEx | Web Portal & Admin |
| **Bolero WebUI** | F# / WASM | High-Assurance C3I |
| **Avalonia GUI** | F# / .NET 10 | Low-Latency Desktop |
| **Prajna TUI** | Elixir / ANSI | Emergency Terminal |

### 2.2 Essential Commands (F# Kernel)
- `sa-up`: Boot mesh (14 Containers).
- `sa-down`: Graceful shutdown + checkpoint.
- `sa-status`: Health matrix (14 Nodes).
- `sa-plan`: Authoritative task management.
- `sa-verify`: 2oo3 voting verification.

---

## 5.0 Safety Constraints (STAMP/SC)

### SC-HMI: UI & Human Experience
- **SC-HMI-010 (Color Rich)**: Vibrant chromatic feedback based on Zenoh metabolic telemetry.
- **SC-HMI-011 (8x8 Matrix)**: 100% path coverage across 8 elements x 8 layers.
- **SC-COCKPIT-002**: WebUI MUST use F# Bolero.
- **SC-SAFETY-001 (Arm & Fire)**: Destructive actions require multi-step commit.

### SC-PARALLEL: Full Parallelization
- **SC-PARALLEL-001**: Use `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"`.
- **SC-PARALLEL-002**: All `mix compile` MUST include `--jobs 16`.

### SC-SYNC-DOC: Documentation Sync
- **SC-SYNC-DOC-001**: All plan files MUST have `YYYYMMDD-HHMM CEST` timestamps.
- **SC-SYNC-DOC-002**: Every plan MUST trigger a detailed journal entry.

---

## 9.0 Agent Operating Rules (AOR)
- **AOR-EXE-001**: Executive has supreme authority.
- **AOR-SAF-001**: Halt <1s on STAMP violation.
- **AOR-HOLON-009**: SQLite/DuckDB is the ONLY source of truth.
- **AOR-PLAN-001**: Use F# Planning CLI for task management.

**INDRAJAAL IS HARDENED. EVOLVING TOWARDS SINGULARITY. 🏁**
"""

with open("GEMINI.md", "w") as f:
    f.write(header.replace("SPEC_FILE", "GEMINI.md"))

with open("CLAUDE.md", "w") as f:
    f.write(header.replace("SPEC_FILE", "CLAUDE.md"))

# Update AGENT_BOOTSTRAP.md version
with open("AGENT_BOOTSTRAP.md", "r") as f:
    bootstrap = f.read()
bootstrap = bootstrap.replace("Version: 21.3.0-SIL6", f"Version: {version}")
with open("AGENT_BOOTSTRAP.md", "w") as f:
    f.write(bootstrap)

print("Unified specs generated.")
