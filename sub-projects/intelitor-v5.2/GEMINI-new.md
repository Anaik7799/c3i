# GEMINI-new.md - Mathematically Complete Safety-Critical System Specification

**Version**: 3.0.0-Exhaustive-Canonical
**Origin**: Derived from GEMINI.md (v1.0.3-sopv511)
**Classification**: 🛡️ IMMUTABLE SYSTEM AXIOMS
**Objective**: To provide a mathematically complete, exhaustive, and non-negotiable set of rules for Autonomous Agents operating in the Indrajaal Safety-Critical Environment, utilizing Formal Logic and Set Theory.

---

## 1.0 Fundamental Axioms (The $\aleph_0$ Set) 

These axioms are the foundational truths of the system. Any state $S$ where an axiom is violated is by definition a **Critical Failure State** ($S_{fail}$). 

### Axiom 1: The Patient Mode Invariant
$\forall \text{compilation } c \in \mathcal{O}_{comp}$:
1.  **Unbounded Execution**: `NO_TIMEOUT=true`, `INFINITE_PATIENCE=true`.
2.  **Resource Maximization**: `ELIXIR_ERL_OPTIONS="+S 16"`.
3.  **Observability**: $Output(c) \rightarrow \text{Stream} \xrightarrow{pipe} \text{File}(L_c)$.
4.  **Atomic Analysis**: The log file $L_c$ is **locked** for reading until $P_c$ terminates ($exit\_code \neq \emptyset$). Partial analysis (head/tail) is strictly $\emptyset$.
5.  **Mandatory Syntax**:
    ```bash
    NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors 2>&1 | tee -a [LOG_FILE]
    ```

### Axiom 2: The Container Isolation Invariant
$\forall \text{process } p$:
1.  **Environment**: $E_p \equiv \text{NixOS Container}$.
2.  **Runtime**: $R_p \equiv \text{Podman v5.4.1+}$ (Rootless).
3.  **Registry Source**: $S_{img} \in \{ \text{localhost/}, \text{registry.nixos.org/} \}$.
4.  **Forbidden Set**: $\mathbb{F} = \text{Docker} \cup \text{Alpine} \cup \text{Ubuntu} \cup \text{Proprietary Registries}$.
5.  **Constraint**: $S_{img} \cap \mathbb{F} \equiv \emptyset$.
6.  **Synchronization**: PHICS v2.1 active with latency $\delta < 50ms$.

### Axiom 3: The Zero-Defect Quality Invariant
The System State is Valid ($S_{valid}$) iff:
$$ \sum \text{CompErrors} + \sum \text{Warnings} + \sum \text{TestFails} + \sum \text{FormatFails} + \sum \text{CredoFails} + \sum \text{SecFails} \equiv 0 $$

### Axiom 4: The Test-Driven Generation (TDG) Invariant
Let $C$ be the set of Code and $T$ be the set of Tests.
$\forall c_{new} \in C$:
1.  $\exists t \in T : \text{time}(creation(t)) < \text{time}(creation(c_{new}))$.
2.  $\text{Result}(t | \{C \setminus c_{new}\}) = \text{Fail}$.
3.  $\text{Result}(t | \{C \cup c_{new}\}) = \text{Pass}$.
4.  **Dual Property**: $\text{PropCheck} \in t \wedge \text{ExUnitProperties} \in t$.

### Axiom 6: The Session Synchronization Invariant (ASSP)
$\forall \text{Action } a \in \text{CodeModification}$:
1.  **State Existence**: An active session state $S_{json}$ MUST exist (`.active_task_state.json`).
2.  **Consistency**: $S_{json}.\text{taskId} \equiv S_{md}.\text{taskId}$ AND $S_{md}.\text{status} \equiv \text{in_progress}$.
3.  **Lifecycle**:
    *   Start: `mix todo --start ID`
    *   End: `mix todo --complete ID`
    *   Resume: `mix todo --resume` (MANDATORY on startup)

---

## 2.0 System Architecture ($\Sigma$)

### 2.1 The 50-Agent Hierarchy ($\mathcal{A}_{50}$)
The system is managed by a precise hierarchy of 50 cybernetic agents.

*   **Layer 1: Executive (1)**
    *   1 Executive Director (Strategic Oversight, Emergency Powers).
*   **Layer 2: Domain Supervisors (10)**
    *   Domain-01: Access Control
    *   Domain-02: Accounts
    *   Domain-03: Alarms
    *   Domain-04: Analytics
    *   Domain-05: Communication
    *   Domain-06: Compliance
    *   Domain-07: Devices
    *   Domain-08: Performance
    *   Domain-09: Observability
    *   Domain-10: Web API
*   **Layer 3: Functional Supervisors (15)**
    *   5 Compilation Specialists (Syntax, Deps, Parallel)
    *   5 Quality Assurance Specialists (Code, Test, Security)
    *   5 Performance Monitors (Resource, Bottleneck, Scaling)
*   **Layer 4: Workers (24)**
    *   8 File Processors (Compilation, Fixes)
    *   8 Pattern Recognizers (EP001-EP999 detection)
    *   8 Continuous Validators (Quality Gates)

### 2.2 Infrastructure Specification ($\mathcal{I}$)
**Total Resources**: 10 CPU Cores, 48GB RAM.
**Container Allocation Matrix**:
| Container | Purpose | Specs | Complexity |
|-----------|---------|-------|------------|
| `access_control` | Security | 4.2 cores, 8GB | High |
| `accounts` | User Mgmt | 3.0 cores, 5GB | Medium |
| `alarms` | Alerting | 4.2 cores, 8GB | High |
| `analytics` | Data | 4.2 cores, 8GB | High |
| `communication` | Messaging | 3.0 cores, 5GB | Medium |
| `compliance` | Regulatory | 2.8 cores, 4GB | Medium |
| `devices` | Hardware | 2.0 cores, 3GB | Low |
| `performance` | Optimiz. | 4.2 cores, 8GB | High |
| `observability` | Monitor | 4.5 cores, 9GB | Very High |
| `web_api` | Gateway | 4.0 cores, 7GB | High |

### 2.3 Service Port Registry ($P_{svc}$)
| Service | Port | Protocol |
|---------|------|----------|
| Phoenix | 4000 | HTTP/WS |
| PostgreSQL | 5433 | TCP |
| MinIO | 9000 | HTTP |
| Jellyfish | 5002 | WebRTC |
| Prometheus | 9568 | HTTP |
| SIA DC-09 | 3061 | UDP/TCP |

---

## 3.0 Temporal Logic Specifications (LTL)

We define the system behavior using Linear Temporal Logic operators: $\Box$ (Globally/Always), $\diamond$ (Eventually), $\bigcirc$ (Next).

### 3.1 Safety Properties (Bad things never happen)
*   **LTL-1 (Timeout Safety)**: $\Box \neg (\text{CompilationRunning} \wedge \text{TimeoutTriggered})$.
*   **LTL-2 (Validation Safety)**: $\Box (\text{SuccessClaim} \implies \text{PrecededBy}(\text{ConsensusCheck}))$.
*   **LTL-3 (Container Safety)**: $\Box \neg (\text{Execution} \wedge \neg \text{Podman})$.
*   **LTL-4 (Timestamp Safety)**: $\Box \forall \tau : \text{TimeZone}(\tau) \neq \text{UTC}$.

### 3.2 Liveness Properties (Good things eventually happen)
*   **LTL-5 (Analysis Liveness)**: $\Box (\text{CompilationStart} \implies \diamond \text{LogAnalysis})$.
*   **LTL-6 (Fix Liveness)**: $\Box (\text{ErrorDetected} \implies \diamond (\text{TPSRootCauseAnalysis} \wedge \text{FixApplied}))$.

---

## 4.0 Operational Protocols (Hoare Logic)

We define operations as Hoare Triples $\{P\} C \{Q\}$, where $P$ is the Precondition, $C$ is the Command, and $Q$ is the Postcondition.

### 4.1 Protocol: The 10-Step Verification Checklist
*   $P$: $\text{RepoState} = \text{Dirty} \vee \text{Unknown}$.
*   $C$: Execute Checklist (Clean, Compile, FileCount=773, Error=0, Warning=0, Consensus, Log, Review, TDG, STAMP).
*   $Q$: $(\text{RepoState} = \text{CertifiedClean}) \wedge (\text{Safety} = \text{Verified})$.

### 4.2 Protocol: The Automated Fix Cycle
*   $P$: $\exists e \in \text{Log} : e \text{ is Error}$.
*   $C$: `incremental_fix_prerequisite` $\rightarrow$ `intelligent_batch_planner` $\rightarrow$ `automated_fix_executor` $\rightarrow$ `consensus_validator`.
*   $Q$: $(\text{Log}' = \text{Log} \setminus e) \vee (\text{State} = \text{Rollback})$.

### 4.4 Protocol: Session Initialization (ASSP)
*   $P$: $\text{Session Start}$.
*   $C$: `elixir scripts/planning/todolist_manager.exs --resume`.
*   $Q$: $(\text{ActiveTaskLoaded}) \vee (\text{ReadyToDispatch})$.

---

## 5.0 Safety Constraints (The STAMP 72)

The system enforces 72 Safety Constraints across 9 Categories.

### A. Validation (SC-VAL)
*   **SC-VAL-001**: Patient Mode Mandatory.
*   **SC-VAL-003**: 5-Method Consensus.
*   **SC-VAL-006**: No Selective Validation (EP-110).

### B. Container (SC-CNT)
*   **SC-CNT-009**: NixOS Exclusive.
*   **SC-CNT-010**: Localhost Registry Only.
*   **SC-CNT-012**: Rootless Execution.

### C. Agent (SC-AGT)
*   **SC-AGT-017**: 90%+ Coordination Efficiency.
*   **SC-AGT-018**: Deadlock Prevention.

### D. Compilation (SC-CMP)
*   **SC-CMP-025**: Warnings as Errors.
*   **SC-CMP-026**: Complete File Compilation (773 files).

### E. Data Integrity (SC-DAT)
*   **SC-DAT-033**: No Corruption.
*   **SC-DAT-034**: Audit Log Integrity.

### F. Security (SC-SEC)
*   **SC-SEC-043**: Network Isolation.
*   **SC-SEC-044**: Code Security (Sobelow).

### G. Performance (SC-PRF)
*   **SC-PRF-050**: Response Time SLAs (<50ms).
*   **SC-PRF-056**: Scalability Limits.

### H. Emergency (SC-EMR)
*   **SC-EMR-057**: Stop < 5 seconds.
*   **SC-EMR-060**: Rollback Capability.

### I. Observability (SC-OBS)
*   **SC-OBS-065**: Logging Enabled.
*   **SC-OBS-069**: Dual Logging Enforcement.

### J. ASSP Safety (SC-ASSP)
*   **SC-ASSP-001**: Mandatory Session Resume on Startup.
*   **SC-ASSP-002**: No Code Modification without Active Task.
*   **SC-ASSP-003**: Atomic Start/Complete Transitions.
*   **SC-ASSP-004**: Git Persistence. `PROJECT_TODOLIST.md` SHALL be staged in git immediately after any state change to ensure continuity across branches.
*   **SC-ASSP-005**: Lock Integrity. Transient session files (`.active_sessions/`) and lock directories (`*.lock`) SHALL be excluded from version control.
*   **SC-ASSP-006**: Deadlock Prevention. Locking mechanisms SHALL employ timeout backoffs, random jitter, and stale lock expiration (>30s).
*   **SC-ASSP-007**: Corruption Prevention. All state file writes SHALL use atomic rename patterns (write-temp-move).

---

## 6.0 Technology & File Policies

### 6.1 Protected Files Invariant
The following files are **IMMUTABLE** except via specific authorization:
*   `CLAUDE.md`
*   `README.md`
*   `mix.exs`
*   `devenv.nix`
*   `tps_*.exs`
*   `*.yml`, `*.yaml` (Container Configs)

### 6.2 Technology Stack
*   **Permitted**: Elixir (`.exs`), Python (`.py`).
*   **Forbidden**: Bash (`.sh`), Node.js (`.js`), Ruby (`.rb`), Perl, PowerShell.
*   **JSON**: `Mix.install([{:jason, "~> 1.4"}])` mandatory.
*   **VCS**: Git-as-Memory. Commit messages must be atomic and descriptive.

### 6.3 Timestamp Policy
*   **Reference**: `$(date)` (System Time).
*   **Zone**: `CEST` or `CET`.
*   **Format**: `YYYY-MM-DD HH:MM:SS [Zone]`.
*   **Forbidden**: `UTC`, `DateTime.utc_now()`.

---

## 7.0 Domain-Specific Frameworks

### 7.1 Ash Framework Rules
*   **Atomic**: `require_atomic? false` allowed **ONLY** for `UPDATE` actions.
*   **Actions**: All interface actions must be defined in `actions` block.
*   **Structure**: `calculations do` blocks must encapsulate calculations.

### 7.2 AI/ML Architecture (Hybrid)
*   **Control Plane**: Elixir/BEAM + Nx.
*   **Compute Plane**: Modular Mojo/MAX.
*   **Routing**: $<100ms \rightarrow \text{Nx}$, $>100ms \rightarrow \text{Mojo}$.
*   **Hardware**: GPU via Container abstraction.

### 7.3 Mobile API Specification (17 Endpoints)
*   **Auth**: `login`, `refresh`, `logout`.
*   **Alarms**: `list`, `detail`, `acknowledge`, `resolve`, `escalate`.
*   **Mgmt**: `devices`, `sites`.
*   **Notify**: `register`, `preferences` (get/put), `dashboard`, `sync`, `health`.

---

## 8.0 Command Reference (Canonical Set)

### Validation & Quality
```bash
elixir scripts/validation/unified_patient_mode_validation_orchestrator.exs --validate
elixir scripts/validation/unified_patient_mode_validation_orchestrator.exs --status
mix format --check-formatted
mix credo --strict
```

### Task Management (Hierarchical)
```bash
mix todo.status
mix todo.update --comprehensive
mix todo.sync --validate
mix todo.backup --timestamp
# Numbering: 1.0, 1.1, 1.1.1 (Mandatory)
```

### Demo Execution (16 Modes)
```bash
mix demo --comprehensive
mix demo --quick
mix demo --containers-only
mix demo --security-audit
```

### Container Management
```bash
elixir scripts/performance/podman_direct_manager.exs --status
podman-compose -f podman-compose.yml up -d
# BANNED: docker-compose, podman run (manual)
```

### Analysis
```bash
elixir scripts/analysis/ast_compilation_fixer.exs --comprehensive-analysis
elixir scripts/analysis/five_level_rca_analyzer.exs --issue-type compilation_error
```

---

## 9.0 Emergency Protocols

### 9.1 EP-110 (False Positive) Response
**Trigger**: $q_{valid} \rightarrow q_{emerg}$ (Consensus Failure).
1.  **HALT**: Stop immediately.
2.  **LOG**: Create `./data/tmp/emergency_validation_[timestamp].log`.
3.  **RCA**: Execute 5-Level RCA.
4.  **CORRECT**: Fix validation logic.
5.  **RE-VERIFY**: Full Patient Mode run.

### 9.2 STAMP Violation Response
**Trigger**: Violation of any $SC \in \text{STAMP Set}$.
1.  **HALT**: Stop process.
2.  **CAST**: Initiate CAST investigation.
3.  **REPORT**: Generate STAMP report.
4.  **MITIGATE**: Apply fix.

---

## 10.0 Agent Operating Rules (AOR)

### 10.1 AOR-ASSP: Active State Synchronization
*   **AOR-ASSP-001**: Agent SHALL run `elixir scripts/planning/todolist_manager.exs --resume` immediately upon session instantiation.
*   **AOR-ASSP-002**: Agent SHALL NOT modify any source code unless a task is locked via `--start`.
*   **AOR-ASSP-003**: Agent SHALL synchronize `PROJECT_TODOLIST.md` to git staging (`git add`) immediately after any status update to preserve state across commits/checkouts.
*   **AOR-ASSP-004**: Agent SHALL respect existing locks in `.active_sessions/` and NOT attempt to force-unlock unless explicitly authorized for recovery.
*   **AOR-ASSP-005**: Agent SHALL use `--dispatch` to identify valid next tasks, respecting dependencies and priorities.

---

**Final Formal Assertion**: This document constitutes the complete, exhaustive, and mathematical specification of the Indrajaal system (v3.0.0). $\forall \text{Action } a, (a \notin \text{GEMINI-new.md}) \implies (a \text{ is Forbidden})$.