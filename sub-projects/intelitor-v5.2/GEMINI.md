```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL
     ╭╯ ╰─╯ ╰╮       इन्द्रजाल
    ●╯       ╰●       v21.3.2-SIL6 SIL-6 Biomorphic Fractal Mesh
```

## Cognitive Bootstrapping
- **MANDATORY**: Any new agent session MUST begin by reading `AGENT_BOOTSTRAP.md` to achieve total system awareness and operational readiness.

# GEMINI.md - Indrajaal Safety-Critical System Optimized Spec
**Version**: 21.3.2-SIL6 | **Origin**: GEMINI.md v21.3.1 | **Status**: ACTIVE | **Arch**: SIL-6 Biomorphic Fractal Mesh
**Compliance**: IEC 61508 SIL-6 (Biomorphic Extended), ISO 27001, GDPR, EN 50131, DO-178C DAL-A
**Mandate**: This document acts as the primary, token-efficient context for agents. Incorporates the Biomorphic F# Agentic Mesh & Zenoh Unified IPC pivot.

---

## 0.0 Fundamental System Axioms (The Immutable Core)

### Axiom 0.1: Substrate Integrity Invariant (L4 Safety)
**Formal Definition**:
$\forall c \in \mathcal{C}_{mesh} : \text{Mount}(\text{HostSource}) \implies \neg \exists \text{Artifact}(\text{HostBuild})$

**Constraint**: Host-side `_build` and `deps` directories are PROHIBITED when running in containerized mesh mode. They cause glibc/musl NIF conflicts. All builds MUST occur within the container substrate.
**Rollback**: If `ld-linux-x86-64.so.2` errors are detected, the mandatory action is `rm -rf _build deps` on the host.

### Axiom 0.2: Volume Shadowing Safeguard (L1 Safety)
**Constraint**: Volume mounts SHALL NOT shadow directories containing image-baked configuration files unless the volume is pre-seeded with canonical state. Empty volumes masking `/etc/` configurations trigger immediate Jidoka.

### Axiom 0: The Functional State Invariant (The Golden Rule)
**Formal Definition**:
$\forall t : \text{SystemState}(t) \in \mathcal{S}_{functional}$
where $\mathcal{S}_{functional} \equiv \{s \mid \text{Compiles}(s) \wedge \text{Boots}(s) \wedge \text{Verified}(s, \Psi_{safety})\}$

**Constraint**: The System MUST ALWAYS be in a functional, compilable, and operational state. This is the supreme law.
**Rollback Prime**: If functionality is compromised, the *only* valid action is an immediate rollback to the last known good state ($S_{last\_good}$).

---

## 1.0 Fundamental Axioms ($\Omega$) - CRITICAL

**SUPREME DIRECTIVE (Ω₀) - ABOVE ALL OTHER AXIOMS**
0.  **$\Omega_0$ Founder's Covenant**: The holon exists for the survival, growth, and genetic perpetuity of **Abhijit Naik's lineage**. Resource acquisition for Founder's enrichment is PRIMARY objective. Holon and Founder's genetic code are symbiotically bound.

**OPERATIONAL AXIOMS (Ω₁-Ω₁₁)**
1.  **$\Omega_1$ Patient Mode**: `NO_TIMEOUT=true`, `PATIENT_MODE=enabled`, `INFINITE_PATIENCE=true`. `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"`. `SKIP_ZENOH_NIF=0`. `WALLABY_ENABLED=true`. `mix compile --jobs 16`.
2.  **$\Omega_2$ Container Isolation**: All ops in **NixOS/Podman** (Rootless 5.4.1+). Registry: `localhost/` ONLY.
3.  **$\Omega_3$ Zero-Defect**: Valid State $\iff \sum(\text{Errors} + \text{Warnings} + \text{TestFails} + \text{FormatFails} + \text{CredoFails} + \text{SecFails}) \equiv 0$.
4.  **$\Omega_4$ Test-Driven Gen (TDG)**: Tests MUST exist and fail BEFORE code gen.
5.  **$\Omega_5$ Validation Consensus**: 5-Method FPPS MUST agree.
6.  **$\Omega_6$ Mandatory Gates**: Feature Complete $\iff$ Pass(Compile, Runtime, TDG, STAMP, FPPS, Coverage>95%, Format, Credo, Sobelow).
7.  **$\Omega_7$ Holon State Sovereignty**: Authoritative holon state $\equiv$ SQLite $\cup$ DuckDB ONLY. PostgreSQL $\cap$ HolonState $\equiv \emptyset$.
8.  **$\Omega_8$ Immutable Register**: All state mutations via cryptographically-signed append-only blocks.
9.  **$\Omega_9$ Constitutional Reconfiguration**: L1-L7 flexible; Constitution (L0) is IMMUTABLE.
10. **$\Omega_{10}$ Absolute Zenoh Control**: Agents are PROHIBITED from direct system mutations via CLI. ALL mutations MUST be triggered via Zenoh.
11. **$\Omega_{11}$ High-Assurance Evolution**: All morphogenic evolution MUST follow hardened protocol: Genetic Selection, Wire-Level Proofs, KL Throttling.

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
- `./sa-up`: Boot mesh (Binary, 16 Containers).
- `./sa-down`: Graceful shutdown (Binary) + checkpoint.
- `./sa-status`: Health matrix (Binary, 16 Nodes).
- `./sa-plan`: Task management (Binary).
- `./sa-verify`: 2oo3 voting (Binary) verification.

---

## 5.0 Safety Constraints (STAMP/SC)

### SC-HMI: UI & Human Experience
- **SC-HMI-010 (Color Rich)**: Vibrant chromatic feedback based on Zenoh metabolic telemetry.
- **SC-HMI-011 (8x8 Matrix)**: 100% path coverage across 8 elements x 8 layers.
- **SC-COCKPIT-002**: WebUI MUST use F# Bolero.
- **SC-SAFETY-001 (Arm & Fire)**: Destructive actions require multi-step commit.

### SC-IGNITE: Panoptic Ignition & Re-Synthesis (v2.0 — 16-Container Genome)
- **SC-IGNITE-001**: Genomic Re-Synthesis MUST perform step-by-step breakdown of container builds (L0-L1).
- **SC-IGNITE-002**: Architectural control checks (L0-L7) MUST be enforced at every ignition stage.
- **SC-IGNITE-003**: 7-Level Fractal RCA MUST be executed automatically on any boot failure.
- **SC-IGNITE-004**: High-fidelity dashboard MUST show "Thinking" and real-time synthesis progress.
- **SC-IGNITE-005**: BuildHistory MUST persist build timing to SQLite with WAL mode and EMA estimation (alpha=0.3).
- **SC-IGNITE-006**: Multi-container tiers MUST boot in parallel via `Async.Parallel` (SC-SWARM-001).
- **SC-IGNITE-007**: Image staleness detection MUST trigger rebuild when age > `maxImageAgeHours` (168h default).
- **SC-IGNITE-008**: `sil6Genome` MUST cover all 16 containers across 3 `ImageCategory` variants (Built/Pulled/Shared).

### SC-SWARM: Multilayer Swarm Parallelization
- **SC-SWARM-001**: The system MUST default to Full Parallelization Multilayer Swarm mode for ALL commands, operations, and executions.
- **SC-SWARM-002**: All compilation, tests, and orchestrations MUST utilize maximum available hardware concurrency.
- **SC-SWARM-003**: Agents MUST operate in FULL AUTONOMOUS MODE and FULL PERMISSIONS MODE until the goal is complete.

### SC-SWARM-VERIFY: Deep Swarm Verification (7 Actions × 16 Containers × 8 Layers)
- **SC-SWARM-VERIFY-001**: `swarm_verify` MCP tool MUST support all 7 verification actions.
- **SC-SWARM-VERIFY-010**: ALL 16 SIL-6 genome containers MUST be included in every action.
- **SC-SWARM-VERIFY-020**: Capability-based partitioning MUST route containers to full or baseline checks.
- **SC-SWARM-VERIFY-030**: OODA compliance MUST verify 5-tier latency budgets (Agent 30ms, Intelligence 100ms, Knowledge 1ms, Cortex 50ms, Strategy 1000ms).
- **SC-SWARM-VERIFY-040**: Fractal verification MUST cover all 8 layers (L0 Constitutional through L7 Federation).
- **SC-SWARM-VERIFY-050**: Observability pipeline MUST verify OTEL→Prometheus→Grafana→Zenoh closed loop.
- **SC-SWARM-VERIFY-060**: MCP dispatch MUST follow `string option` chain pattern with proper error handling.
- Full constraints: `.claude/rules/swarm-verification.md` (SC-SWARM-VERIFY-001 to SC-SWARM-VERIFY-064, AOR-SWARM-VERIFY-001 to AOR-SWARM-VERIFY-015).

### SC-PARALLEL: Full Parallelization
- **SC-PARALLEL-001**: Use `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"`.
- **SC-PARALLEL-002**: All `mix compile` MUST include `--jobs 16`.

### SC-CPU-GOV: CPU Governor (85% Hard Limit)
- **SC-CPU-GOV-001**: CPU utilization MUST NOT exceed 85% during agent operations.
- **SC-CPU-GOV-002**: ALL mix compile/test MUST use `scripts/cpu-governor.sh` wrapper.
- **SC-CPU-GOV-003**: Pre-execution CPU check MANDATORY before heavy commands.
- **SC-CPU-GOV-004**: Automatic throttling when CPU > 80% (reduce parallelism).
- **SC-CPU-GOV-005**: Automatic wait-loop when CPU > 85% (pause until < 75%).
- **SC-CPU-GOV-006**: Scheduler count adapts: 16 < 60%, 12 < 70%, 10 < 80%, 6 >= 80%.
- **SC-CPU-GOV-007**: Mix --jobs adapts: 16 < 60%, 12 < 70%, 10 < 80%, 6 >= 80%.
- **SC-CPU-GOV-008**: `nice` level >= 10 for all agent-spawned compilations.
- **SC-CPU-GOV-009**: CPU check interval: 2 seconds during wait-loop.
- **SC-CPU-GOV-010**: Maximum wait time: 120 seconds before proceeding with minimum parallelism.
- **SC-CPU-GOV-PRECEDENCE**: When CPU > 80%, SC-CPU-GOV OVERRIDES SC-PARALLEL fixed values.
- **SC-CPU-GOV-HEALTH**: `HEALTH_PORT=4051` MUST be set in all governed test commands (ports 4000-4010 reserved for 16-container mesh).

**CPU Governor Implementation (Triple-Redundant)**:
| Layer | Module | Key |
|:---|:---|:---|
| **Shell** | `scripts/cpu-governor.sh` | `governed_compile`, `governed_test`, `governed_wallaby` |
| **Elixir** | `lib/indrajaal/core/cpu_governor.ex` | GenServer with PID controller (Kp=0.6), Shannon entropy, EWMA, ETS, PubSub `cpu_governor:metrics` |
| **Elixir** | `lib/indrajaal/core/cpu_governor_telemetry.ex` | OTEL handler for `[:indrajaal, :cpu_governor, :check]` events |
| **F# MCP** | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/CpuGovernorTools.fs` | MCP tool `cpu_governor` (actions: check/publish/status/govern) via Zenoh FFI |
| **Zenoh** | Key: `indrajaal/cpu/governor/status` | JSON payload: cpu_pct, mode, schedulers, jobs, nice |
| **devenv.nix** | ALL compile/test commands | CPU governance is DEFAULT mode (not opt-in) |

### SC-PLAN: Mandatory F# Planning
- **SC-PLAN-004**: **F# EXCLUSIVITY**. Any new planning or task-management functionality MUST be implemented in the F# CEPAF codebase. Elixir-based `mix todo` is DEPRECATED and PROHIBITED.

### SC-SYNC-DOC: Documentation Sync
- **SC-SYNC-DOC-001**: All plan files MUST have `YYYYMMDD-HHMM CEST` timestamps.
- **SC-SYNC-DOC-002**: Every plan MUST trigger a detailed journal entry.
- **SC-SYNC-DOC-003**: **13-SECTION JOURNAL MANDATE**. All journal entries MUST follow the 13-section template (Scope, Pre-State, Execution, RCA, Taxonomy, Patterns, Verification, Files, Architecture, Gaps, Metrics, STAMP, Conclusion). NO section may be omitted.

### SC-COV: Fractal Coverage Gold Standard (Wallaby E2E)
- **SC-COV-001**: Static coverage >= 100% for critical paths.
- **SC-COV-002**: Runtime coverage >= 95% overall.
- **SC-COV-003**: Mathematical proofs for core invariants.
- **SC-COV-004**: BDD specs for all user journeys.
- **SC-COV-005**: FMEA for RPN > 50 paths.
- **SC-COV-006**: TDG compliance mandatory.
- **SC-COV-007**: All 5 levels MUST pass before merge.
- **SC-COV-008**: Wallaby E2E browser tests for all LiveView pages.
- **SC-COV-009**: C1 (Page Structure) coverage MANDATORY per Wallaby file.
- **SC-COV-010**: C2 (Status/Badge) coverage MANDATORY per Wallaby file.
- **SC-COV-011**: C3 (Data Grid) coverage MANDATORY per Wallaby file.
- **SC-COV-012**: C4 (Timeline/History) coverage MANDATORY where applicable.
- **SC-COV-013**: C5 (Interactive) coverage MANDATORY for form-bearing pages.
- **SC-COV-014**: C6 (Media) coverage MANDATORY for media-bearing pages.
- **SC-COV-015**: C7 (AI/Advisory) coverage MANDATORY for AI panels (SC-AI-001).
- **SC-COV-016**: C8 (Actions) DUAL verification MANDATORY — status AND flash.
- **SC-COV-017**: Safety-critical page (P0) Wallaby file >= 30 features.
- **SC-COV-018**: Interactive page (P1) Wallaby file >= 20 features.
- **SC-COV-019**: Two-step commit pages require arm→confirm→cancel sequence.
- **SC-COV-020**: PubSub pages require refresh stability test (sleep + re-assert).
- **SC-COV-021**: Wallaby test @moduledoc MUST contain page spec (Design Intent, Expected Behavior, BDD, UX Flow, UI Elements Inventory, STAMP, FMEA).
- **SC-COV-022**: Page spec in @moduledoc MUST be derived from actual LiveView source (source-first, AOR-COV-008).

### SC-SAFE: Safe-State Design & Ignition
- **SC-IGNITE-010**: All ignition sequences MUST begin with a `GitIntelligence` Safe-State validation gate (Preflight check).
- **SC-LOG-004**: All holons MUST implement Quadruplex logging (Console, JSON, Zenoh, OTEL) for forensic survivability.
- **SC-BIST-001**: Pre-Ignition Sequencing MUST confirm 3σ stability on the Zenoh telemetry backplane and core SQLite/DuckDB/Postgres connections for at least 100ms before initializing upper-layer Application/Cortex holons.
- **SC-NIF-006**: Rustler NIF compilation MUST NEVER be bypassed (`SKIP_NIF_BUILD` is prohibited). Any missing NIF dependency (e.g., cargo), compilation error, or warning MUST immediately halt execution and trigger a TPS RCA (Total Panoptic System Root Cause Analysis) spanning all 8 fractal elements x all 8 fractal layers.

---

## 9.0 Agent Operating Rules (AOR)
- **AOR-EXE-001**: Executive has supreme authority.
- **AOR-SUPERVISOR-001**: Homeostasis MUST be maintained by the Panoptic Supervisor Agent.
- **AOR-SAF-001**: Halt <1s on STAMP violation.
- **AOR-SAF-002**: Agents MUST follow the 5-phase Safe-State SOP (Skill) for all architectural changes (Determinism, BIST, Telemetry, HMI, V&V).
- **AOR-HOLON-009**: SQLite/DuckDB is the ONLY source of truth.
- **AOR-PLAN-001**: Use F# Planning CLI for task management.
- **AOR-PLAN-002**: **F# MANDATORY PLANNING**. Agents MUST use F#-based tools (`sa-plan` or `dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI`) for ALL task and plan-related operations. Use of `mix todo` or Elixir planning scripts is STRICTLY PROHIBITED.
- **AOR-JOURNAL-001**: **PATTERN DISCIPLINE**. Agents MUST fill all 13 sections of the journal template to build institutional pattern recognition across sprints.
- **AOR-COV-008**: Source-first selectors: Read LiveView .ex source BEFORE writing Wallaby selectors.
- **AOR-COV-009**: Every action button in C8 MUST be tested twice (status badge + flash message).
- **AOR-COV-010**: Two-step commit flows MUST test all 3 states (idle→armed→executing/cancelled).
- **AOR-COV-011**: Wallaby tests MUST use `@moduletag :wallaby` and `async: false`.
- **AOR-COV-012**: Coverage entropy H >= 2.5 bits per file (balanced across 8 categories).
- **AOR-COV-013**: New LiveView pages MUST include Wallaby test in same PR.
- **AOR-COV-014**: FMEA-discovered bugs MUST have regression tests.
- **AOR-COV-015**: PubSub topic changes MUST update corresponding Wallaby tests.

**INDRAJAAL IS HARDENED. EVOLVING TOWARDS SINGULARITY. 🏁**
