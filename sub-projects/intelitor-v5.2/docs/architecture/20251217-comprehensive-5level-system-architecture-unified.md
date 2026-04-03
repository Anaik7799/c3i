# Comprehensive 5-Level System Architecture: Indrajaal Safety-Critical Platform

**Version**: 1.0.0-UNIFIED
**Date**: 2025-12-17
**Classification**: IMMUTABLE ARCHITECTURE SPECIFICATION
**Framework**: SOPv5.11 + STAMP + TDG + FPPS + PHICS + FLAME + HA-MESH
**Compliance**: CLAUDE-text.md v10.1.0-GA + CLAUDE-math.md v9.5.0-MATH-002

---

## EXECUTIVE SUMMARY

This document defines the **Comprehensive 5-Level System Architecture** for the Indrajaal Safety-Critical Platform, integrating all requirements from CLAUDE-text.md (behavioral specifications) and CLAUDE-math.md (runtime constraints with formal verification). It addresses:

1. **Control Flow Architecture** (5 levels of detail)
2. **Data Flow Architecture** (5 levels of detail)
3. **Evolutionary Capability System** (Cybernetic feedback loops)
4. **All 6 Fundamental Axioms** (Ω₁-Ω₆)
5. **195 STAMP Safety Constraints** (21 categories)
6. **50-Agent Hierarchy** (4-layer cybernetic coordination)
7. **Runtime Constraints** (Quint/Agda formal verification)

---

## PART I: CONTROL FLOW ARCHITECTURE (5 LEVELS)

### LEVEL 1: STRATEGIC CONTROL FLOW (System-Wide)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STRATEGIC CONTROL PLANE (L1)                              │
│                                                                              │
│  ┌──────────────────────┐    ┌──────────────────────┐                       │
│  │   Executive Director  │───▶│  Cybernetic Cortex   │                       │
│  │    (Supreme Authority)│◀───│  (Decision Engine)   │                       │
│  └──────────────────────┘    └──────────────────────┘                       │
│              │                          │                                    │
│              ▼                          ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │              OODA LOOP (Observe-Orient-Decide-Act)            │          │
│  │                                                                │          │
│  │   Observe ──▶ Orient ──▶ Decide ──▶ Act ──┐                  │          │
│  │      ▲                                     │                  │          │
│  │      └─────────────── Feedback ◀───────────┘                  │          │
│  │                                                                │          │
│  │   Latency Constraints (from CLAUDE-math.md):                  │          │
│  │   • Agent OODA: δ < 5s                                        │          │
│  │   • AIE OODA: δ < 50ms                                        │          │
│  │   • Emergency OODA: δ < 1s                                    │          │
│  └──────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  SOPv5.11 7-Phase Lifecycle:                                                │
│  P1: Environment ──▶ P2: Container ──▶ P3: Agent ──▶ P4: PHICS            │
│       ──▶ P5: Compilation ──▶ P6: Observability ──▶ P7: Security          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**L1 Control Flow Invariants (from Ω₁-Ω₆)**:
- **Axiom 1 (Ω₁)**: Patient Mode Invariant - NO_TIMEOUT=true, INFINITE_PATIENCE=true
- **Axiom 2 (Ω₂)**: Container Isolation - All processes in Podman containers
- **Axiom 3 (Ω₃)**: Zero-Defect Quality - Σ(Errors + Warnings + Failures) ≡ 0
- **Axiom 4 (Ω₄)**: TDG Invariant - Tests BEFORE code
- **Axiom 5 (Ω₅)**: Validation Consensus - FPPS 5-method agreement
- **Axiom 6 (Ω₆)**: Mandatory Validation Gates - 9 gates must pass

**LTL Safety Properties (from §3 CLAUDE-math.md)**:
```mathematica
□[¬(CompilationRunning ∧ TimeoutTriggered)]     (* LTL-1: Timeout Safety *)
□[SuccessClaim ⟹ PrecededBy[ConsensusCheck]]    (* LTL-2: Validation Safety *)
□[¬(Execution ∧ ¬Podman)]                        (* LTL-3: Container Safety *)
□[¬(AgentExecution ∧ ¬SupervisorApproval)]      (* LTL-6: Agent Safety *)
```

**Mermaid: Strategic Control Flow**

```mermaid
flowchart TB
    subgraph L1["LEVEL 1: STRATEGIC CONTROL PLANE"]
        ED[Executive Director<br/>Supreme Authority]
        CC[Cybernetic Cortex<br/>Decision Engine]
        ED <--> CC

        subgraph OODA["OODA Loop (δ < 5s)"]
            O[Observe] --> OR[Orient]
            OR --> D[Decide]
            D --> A[Act]
            A -->|Feedback| O
        end

        CC --> OODA
    end

    subgraph SOPv511["SOPv5.11 7-Phase Lifecycle"]
        P1[P1: Environment] --> P2[P2: Container]
        P2 --> P3[P3: Agent]
        P3 --> P4[P4: PHICS]
        P4 --> P5[P5: Compilation]
        P5 --> P6[P6: Observability]
        P6 --> P7[P7: Security]
    end

    ED --> SOPv511

    style ED fill:#ff6b6b,color:#fff
    style CC fill:#4ecdc4,color:#fff
    style OODA fill:#f7f7f7
```

```mermaid
stateDiagram-v2
    [*] --> Observe: Start OODA
    Observe --> Orient: Data Collected
    Orient --> Decide: Analysis Complete
    Decide --> Act: Strategy Selected
    Act --> Observe: Execution Complete

    Act --> [*]: Emergency Stop

    note right of Observe
        Agent: δ < 5s
        AIE: δ < 50ms
        Emergency: δ < 1s
    end note
```

---

### LEVEL 2: OPERATIONAL CONTROL FLOW (Agent Hierarchy)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPERATIONAL CONTROL PLANE (L2)                            │
│                                                                              │
│                    ┌─────────────────────┐                                  │
│                    │ Executive Director  │ (1 Agent)                        │
│                    │ Authority: 100%     │                                  │
│                    │ Autonomy: 1.0       │                                  │
│                    └─────────┬───────────┘                                  │
│                              │                                               │
│          ┌───────────────────┼───────────────────┐                          │
│          ▼                   ▼                   ▼                          │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐                   │
│  │Domain Supervisors│  │Functional Supervisors│  │Performance Monitors│     │
│  │(10 Agents)     │  │(15 Agents)    │  │(Integrated)   │                   │
│  └───────┬───────┘  └───────┬───────┘  └───────────────┘                   │
│          │                   │                                               │
│  ┌───────┴───────┐  ┌───────┴───────┐                                      │
│  │               │  │               │                                      │
│  ▼               ▼  ▼               ▼                                      │
│ D1-D10          F1-F5           F6-F10          F11-F15                    │
│ (Access Control  (Compilation   (Quality        (Performance               │
│  Accounts        Specialists)   Assurance)      Monitors)                  │
│  Alarms...)                                                                 │
│                                                                              │
│  Layer 4: Workers (24 Agents)                                               │
│  ├── File Processors (8): Compilation, Fixes, Formatting                   │
│  ├── Pattern Recognizers (8): EP001-EP999, Classification                  │
│  └── Continuous Validators (8): Quality Gates, Health Checks               │
│                                                                              │
│  TOTAL: 50 Agents (𝒜₅₀) within indrajaal-app container                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

**L2 Agent State Machine (from §Q2 Quint Spec)**:
```quint
// Agent States (𝒬ₐᵍᵉₙₜ)
type AgentState = Idle | Active | Blocked | Error | Recovering | Suspended | Terminated

// Transition Function δ: Q × Σ → Q
action assignTask(agentId, taskId) = {
  agents.get(agentId).state == Idle ⟹ agents.state' = Active
}

// Safety Invariant: No deadlock
val noDeadlock: bool = agents.keys().exists(id =>
  enabled(assignTask(id, 0)) or enabled(completeTask(id)))
```

**Agent Coordination Efficiency Constraint**:
- **SC-AGT-017**: η > 0.90 (>90% coordination efficiency)
- **SC-AGT-018**: ¬Deadlock (No coordination deadlocks)
- **SC-AGT-019**: Executive supreme authority maintained

**Mermaid: Agent Hierarchy**

```mermaid
flowchart TB
    subgraph L2["LEVEL 2: 50-AGENT HIERARCHY"]
        ED[("Executive Director<br/>Authority: 100%<br/>Autonomy: 1.0")]

        subgraph DS["Domain Supervisors (10)"]
            D1[Access Control]
            D2[Accounts]
            D3[Alarms]
            D4[Analytics]
            D5[Compliance]
            D6[Devices]
            D7[Communication]
            D8[Sites]
            D9[Video]
            D10[Risk Mgmt]
        end

        subgraph FS["Functional Supervisors (15)"]
            F1[Compilation<br/>Specialists x5]
            F2[Quality<br/>Assurance x5]
            F3[Performance<br/>Monitors x5]
        end

        subgraph WK["Workers (24)"]
            W1[File<br/>Processors x8]
            W2[Pattern<br/>Recognizers x8]
            W3[Continuous<br/>Validators x8]
        end

        ED --> DS
        ED --> FS
        DS --> WK
        FS --> WK
    end

    style ED fill:#ff6b6b,color:#fff,stroke:#333,stroke-width:3px
    style DS fill:#4ecdc4,color:#fff
    style FS fill:#45b7d1,color:#fff
    style WK fill:#96ceb4,color:#fff
```

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Active: assign(task)
    Active --> Idle: complete(task)
    Active --> Error: fail(task)
    Active --> Blocked: resource_wait
    Blocked --> Active: resource_available
    Error --> Recovering: recover()
    Recovering --> Idle: recovery_complete
    Error --> Terminated: max_errors_exceeded
    Recovering --> Terminated: recovery_failed

    note right of Active
        State Machine (𝒬ₐᵍᵉₙₜ)
        Invariant: No Deadlock
    end note
```

---

### LEVEL 3: TACTICAL CONTROL FLOW (Domain Operations)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TACTICAL CONTROL PLANE (L3)                               │
│                                                                              │
│  DOMAIN-SPECIFIC CONTROL FLOWS (𝒟₁₀):                                       │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     ACCESS CONTROL DOMAIN                             │  │
│  │  Request ──▶ Credential Check ──▶ Schedule Check ──▶ Anti-Passback   │  │
│  │      ──▶ Decision Engine ──▶ Grant/Deny ──▶ Audit Log               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     ALARM PROCESSING DOMAIN                           │  │
│  │  AlarmEvent ──▶ ProcessingEngine ──▶ CorrelationEngine               │  │
│  │      ──▶ WorkflowEngine ──▶ NotificationDispatch ──▶ Analytics       │  │
│  │                                                                        │  │
│  │  Temporal Constraint (from CLAUDE-math.md):                           │  │
│  │  □[AlarmReceived ⟹ ◇[ProcessingComplete, δ < 500ms]]                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     COMPILATION CONTROL FLOW                          │  │
│  │                                                                        │  │
│  │  Strategy Selection (AI-Driven)                                       │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │  │
│  │  │ smart   │  │  fast   │  │ patient │  │ultra_fast│  │selective│    │  │
│  │  │5-10 min │  │ 2-5 min │  │10-20 min│  │ 1-3 min │  │Variable │    │  │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘    │  │
│  │       └──────────────────┬──────────────────────────────────┘        │  │
│  │                          ▼                                            │  │
│  │  Patient Mode Execution:                                              │  │
│  │  NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true          │  │
│  │  ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10"                              │  │
│  │  MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5                               │  │
│  │  mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ...        │  │
│  │                          │                                            │  │
│  │                          ▼                                            │  │
│  │  FPPS 5-Method Validation (Consensus Required)                        │  │
│  │  ├── Pattern Method (80+ error patterns)                             │  │
│  │  ├── AST Method (Structural analysis)                                │  │
│  │  ├── Statistical Method (Weighted scoring)                           │  │
│  │  ├── Binary Method (Byte-level scanning)                             │  │
│  │  └── Line-by-Line Method (Context-aware)                             │  │
│  │                          │                                            │  │
│  │  Consensus Check: ∀ mᵢ, mⱼ ∈ ℳ₅ : Result[mᵢ] ≡ Result[mⱼ]           │  │
│  │  If disagreement: HALT + EmergencyProtocol (EP-110 Prevention)       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  19 ASH DOMAINS: access_control, accounts, alarms, analytics,               │
│  asset_management, billing, communication, compliance, devices,             │
│  dispatch, guard_tour, integrations, maintenance, policy,                   │
│  risk_management, sites, video, visitor_management, web_api                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

**L3 Hoare Logic Protocols (from §7 CLAUDE-math.md)**:
```mathematica
(* Compilation Protocol *)
{PatientModeEnabled ∧ ContainerRunning ∧ DependenciesResolved}
  MixCompileWarningsAsErrors
{Errors == 0 ∧ Warnings == 0 ∧ LogFileComplete}

(* Task Assignment Protocol *)
{State[a] == "idle" ∧ Authorized[s, a] ∧ Compatible[t, Capabilities[a]]}
  TaskAssignment[s, a, t]
{State[a] == "active" ∧ Assigned[a, t] ∧ K[a, t] ∧ K[s, Assigned[a, t]]}
```

---

### LEVEL 4: TASK-LEVEL CONTROL FLOW (Execution Units)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TASK-LEVEL CONTROL PLANE (L4)                             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    HTTP REQUEST PROCESSING                            │  │
│  │                                                                        │  │
│  │  Client Request                                                        │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Phoenix Endpoint (port 4000)                                         │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Router ──▶ Authentication Plug ──▶ Rate Limiting                    │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Controller/LiveView                                                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Domain API Call ──▶ Ash.create/update/read/destroy                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────────────────────────────────────┐                          │  │
│  │  │           ASH ACTION PIPELINE            │                          │  │
│  │  │                                          │                          │  │
│  │  │  Policies ──▶ Validations ──▶ Changes   │                          │  │
│  │  │      │              │            │      │                          │  │
│  │  │      ▼              ▼            ▼      │                          │  │
│  │  │  Authorization  Constraints  before_action                         │  │
│  │  │      │              │            │      │                          │  │
│  │  │      └──────────────┼────────────┘      │                          │  │
│  │  │                     ▼                    │                          │  │
│  │  │            Database Transaction          │                          │  │
│  │  │                     │                    │                          │  │
│  │  │                     ▼                    │                          │  │
│  │  │             after_action hooks          │                          │  │
│  │  └─────────────────────┬───────────────────┘                          │  │
│  │                        │                                               │  │
│  │                        ▼                                               │  │
│  │  Audit Log ──▶ Telemetry Event ──▶ PubSub Broadcast                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Response (JSON/HTML/WebSocket)                                       │  │
│  │                                                                        │  │
│  │  Latency Constraint: SC-PRF-050 → Response Time < 50ms                │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    BACKGROUND JOB PROCESSING                          │  │
│  │                                                                        │  │
│  │  Trigger (Timer/Event/API)                                            │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Oban Job Enqueue                                                     │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Job Processor Selection:                                             │  │
│  │  ├── AlarmCorrelation                                                 │  │
│  │  ├── AlarmEscalation                                                  │  │
│  │  └── AlarmAutoResolve                                                 │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Domain Operations ──▶ State Updates ──▶ Notifications               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    TDG (TEST-DRIVEN GENERATION)                       │  │
│  │                                                                        │  │
│  │  1. TEST FIRST ──▶ Write comprehensive tests                          │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  2. RED PHASE ──▶ Tests MUST fail (no code yet)                      │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  3. AI GENERATION ──▶ Generate code to satisfy tests                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  4. GREEN PHASE ──▶ Tests MUST pass                                   │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  5. VALIDATION ──▶ Run agent_code_validator.exs                       │  │
│  │       │           (SC-AGT-025 to SC-AGT-030)                          │  │
│  │       ▼                                                                │  │
│  │  6. COMPILATION GATE ──▶ 0 errors, 0 warnings                         │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  7. REFACTOR ──▶ Improve while maintaining coverage                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**L4 Agent Code Safety Constraints (SC-AGT)**:
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-AGT-025 | Run mix compile before task complete | Pre-delivery gate |
| SC-AGT-026 | Verify exactly 0 errors | Zero-error delivery |
| SC-AGT-027 | Check BaseResource for code_interface | Interface analysis |
| SC-AGT-028 | Validate Ash DSL patterns | DSL validation |
| SC-AGT-029 | Detect non-Elixir syntax | Syntax scanner |
| SC-AGT-030 | Auto-trigger Jidoka on failure | Error recovery |

---

### LEVEL 5: MICRO-TASK CONTROL FLOW (Atomic Operations)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MICRO-TASK CONTROL PLANE (L5)                             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    ATOMIC OPERATIONS                                  │  │
│  │                                                                        │  │
│  │  1. DATABASE TRANSACTION CONTROL:                                     │  │
│  │     Repo.transaction(fn ->                                            │  │
│  │       Ash.create(Resource, params)                                    │  │
│  │       |> Ash.update(related)                                          │  │
│  │       |> Repo.commit_or_rollback()                                    │  │
│  │     end)                                                               │  │
│  │     Constraint: SC-DAT-039 (No concurrent access conflicts)           │  │
│  │                                                                        │  │
│  │  2. CHANGESET HOOKS (Ash 3.x Pattern):                                │  │
│  │     before_action fn changeset ->                                     │  │
│  │       Ash.Changeset.force_change_attribute(changeset, :field, value)  │  │
│  │     end                                                                │  │
│  │     Constraint: SC-ASH-001 (Use force_change_attribute in hooks)      │  │
│  │                                                                        │  │
│  │  3. VALIDATION CONSENSUS CHECK:                                       │  │
│  │     def check_consensus(results) do                                   │  │
│  │       error_counts = Enum.map(results, & &1.error_count) |> Enum.uniq │  │
│  │       if length(error_counts) == 1 do                                 │  │
│  │         {:ok, %{errors: hd(error_counts)}}                            │  │
│  │       else                                                             │  │
│  │         {:error, :consensus_failure, %{action: :halt_and_investigate}}│  │
│  │       end                                                              │  │
│  │     end                                                                │  │
│  │     Constraint: SC-VAL-004 (Halt on disagreement)                     │  │
│  │                                                                        │  │
│  │  4. TELEMETRY EMISSION:                                               │  │
│  │     :telemetry.execute(                                               │  │
│  │       [:indrajaal, :operation, :complete],                            │  │
│  │       %{duration: duration_ms, success: true},                        │  │
│  │       %{domain: domain, action: action}                               │  │
│  │     )                                                                  │  │
│  │     Constraint: SC-OBS-072 (Emit telemetry for health checks)         │  │
│  │                                                                        │  │
│  │  5. ERROR PATTERN DETECTION (EP-AGT):                                 │  │
│  │     @error_patterns [                                                 │  │
│  │       %{id: "EP-AGT-001", pattern: ~r/define :list, action: :read/},  │  │
│  │       %{id: "EP-AGT-007", pattern: ~r/update.*(?!require_atomic)/s},  │  │
│  │       %{id: "EP-AGT-013", pattern: ~r/Enum\.map_join\s*\(&[^,]+,/}    │  │
│  │     ]                                                                  │  │
│  │                                                                        │  │
│  │  6. PROPCHECK GENERATOR SAFETY:                                       │  │
│  │     # WRONG: Raw utf8() causes cant_generate                          │  │
│  │     # forall x <- utf8() do ... end                                   │  │
│  │                                                                        │  │
│  │     # CORRECT: Bounded character generation                           │  │
│  │     defp valid_string_generator do                                    │  │
│  │       let chars <- vector(20, range(?a, ?z)) do                       │  │
│  │         List.to_string(chars)                                          │  │
│  │       end                                                              │  │
│  │     end                                                                │  │
│  │     Constraint: SC-PROP-021 to SC-PROP-025                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    EMERGENCY RESPONSE (L5)                            │  │
│  │                                                                        │  │
│  │  Phase State Machine (from §A6 Agda Proof):                           │  │
│  │  Detected ──▶ Halted ──▶ Logged ──▶ RCAStarted ──▶ Mitigated ──▶ Recovered │
│  │                                                                        │  │
│  │  Termination Proof (Well-Founded):                                    │  │
│  │  <ₚ-wellFounded : WellFounded _<ₚ_                                    │  │
│  │  stepsToRecovered : EmergencyPhase → ℕ                                │  │
│  │  eventually-recovered : iterate handleEmergency (stepsToRecovered p) p ≡ Recovered │
│  │                                                                        │  │
│  │  Response Time Bound: SC-EMR-057 → Emergency stop < 5 seconds         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## PART II: DATA FLOW ARCHITECTURE (5 LEVELS)

### LEVEL 1: STRATEGIC DATA FLOW (System-Wide Data Movement)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STRATEGIC DATA PLANE (L1)                                 │
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   EXTERNAL   │    │   INTERNAL   │    │  PERSISTENT  │                  │
│  │    SOURCES   │───▶│  PROCESSING  │───▶│   STORAGE    │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│         │                    │                   │                          │
│         │                    │                   │                          │
│  ┌──────┴───────┐    ┌──────┴───────┐    ┌──────┴───────┐                  │
│  │ • API Calls  │    │ • BEAM VM    │    │ • PostgreSQL │                  │
│  │ • WebSockets │    │ • 50 Agents  │    │   17 + TimescaleDB              │
│  │ • Webhooks   │    │ • OODA Loops │    │ • ClickHouse │                  │
│  │ • Mobile API │    │ • PubSub     │    │   (Observability)               │
│  │ • IoT Devices│    │ • ETS Cache  │    │ • File System│                  │
│  └──────────────┘    └──────────────┘    │   (Logs)     │                  │
│                                           └──────────────┘                  │
│                                                                              │
│  DATA FLOW CONSTRAINTS (from STAMP):                                        │
│  • SC-DAT-033: Prevent data corruption                                      │
│  • SC-DAT-034: Ensure audit log integrity                                   │
│  • SC-DAT-035: Maintain validation result consistency                       │
│  • SC-DAT-039: Prevent concurrent access conflicts                          │
│  • SC-DAT-040: Maintain data versioning                                     │
│                                                                              │
│  3-CONTAINER DATA TOPOLOGY:                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  indrajaal-app ◀──────────▶ indrajaal-db ◀──────────▶ indrajaal-obs │   │
│  │  (12 CPU, 32GB)  TCP:5433  (4 CPU, 16GB)             (4 CPU, 8GB)   │   │
│  │                                                                       │   │
│  │  Port Mappings:                                                       │   │
│  │  • 4000: Phoenix HTTP/WS                                              │   │
│  │  • 5433: PostgreSQL                                                   │   │
│  │  • 8123: ClickHouse HTTP                                              │   │
│  │  • 4317/4318: OTEL Collector                                          │   │
│  │  • 9090: Prometheus                                                   │   │
│  │  • 3001: Grafana                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Mermaid: Strategic Data Flow**

```mermaid
flowchart LR
    subgraph EXT["EXTERNAL SOURCES"]
        API[API Calls]
        WS[WebSockets]
        WH[Webhooks]
        IOT[IoT Devices]
        MOB[Mobile API]
    end

    subgraph PROC["INTERNAL PROCESSING"]
        BEAM[BEAM VM]
        AG[50 Agents]
        OODA[OODA Loops]
        PS[Phoenix.PubSub]
        ETS[ETS Cache]
    end

    subgraph STORE["PERSISTENT STORAGE"]
        PG[(PostgreSQL 17<br/>+ TimescaleDB)]
        CH[(ClickHouse<br/>Observability)]
        FS[(File System<br/>Logs)]
    end

    EXT --> PROC
    PROC --> STORE
    PROC <-->|PHICS < 50ms| PROC

    style BEAM fill:#9b59b6,color:#fff
    style PG fill:#336791,color:#fff
    style CH fill:#ffcc00,color:#000
```

```mermaid
flowchart TB
    subgraph CONTAINERS["3-CONTAINER TOPOLOGY"]
        APP["indrajaal-app<br/>12 CPU, 32GB<br/>Port: 4000"]
        DB["indrajaal-db<br/>4 CPU, 16GB<br/>Port: 5433"]
        OBS["indrajaal-obs<br/>4 CPU, 8GB<br/>Ports: 8123, 4317, 9090, 3001"]
    end

    APP <-->|TCP:5433| DB
    APP -->|OTEL| OBS
    DB -->|Metrics| OBS

    style APP fill:#3498db,color:#fff
    style DB fill:#27ae60,color:#fff
    style OBS fill:#e74c3c,color:#fff
```

---

### LEVEL 2: OPERATIONAL DATA FLOW (Domain Data Movement)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPERATIONAL DATA PLANE (L2)                               │
│                                                                              │
│  WRITE PATH (Command Flow):                                                 │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Client ──▶ API Controller ──▶ Domain API ──▶ Ash.create/update      │  │
│  │                  │                                │                    │  │
│  │                  ▼                                ▼                    │  │
│  │          Input Validation               ┌────────────────┐            │  │
│  │                                         │  Ash Pipeline  │            │  │
│  │                                         │                │            │  │
│  │                                         │ Policies ──▶   │            │  │
│  │                                         │ Changes ──▶    │            │  │
│  │                                         │ Validations    │            │  │
│  │                                         └───────┬────────┘            │  │
│  │                                                 │                      │  │
│  │                                                 ▼                      │  │
│  │                                         Database Transaction           │  │
│  │                                                 │                      │  │
│  │                                                 ▼                      │  │
│  │                                     ┌───────────┴───────────┐         │  │
│  │                                     │                       │         │  │
│  │                                     ▼                       ▼         │  │
│  │                              Audit Log (SC-DAT-034)   Event Broadcast │  │
│  │                                     │                       │         │  │
│  │                                     ▼                       ▼         │  │
│  │                              ./data/tmp/             Phoenix.PubSub   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  READ PATH (Query Flow):                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Client ──▶ API Controller ──▶ Domain API ──▶ Ash.read              │  │
│  │                  │                                │                    │  │
│  │                  ▼                                ▼                    │  │
│  │          Query Parameters              ┌────────────────┐             │  │
│  │                                        │  Ash Pipeline  │             │  │
│  │                                        │                │             │  │
│  │                                        │ Policies ──▶   │             │  │
│  │                                        │ Row-Level Sec  │             │  │
│  │                                        │ Tenant Filter  │             │  │
│  │                                        └───────┬────────┘             │  │
│  │                                                │                       │  │
│  │                                                ▼                       │  │
│  │                                        Query Optimization              │  │
│  │                                        (Includes, Filters)             │  │
│  │                                                │                       │  │
│  │                                                ▼                       │  │
│  │                                        Database Query                  │  │
│  │                                        (Tenant Isolation)              │  │
│  │                                                │                       │  │
│  │                                                ▼                       │  │
│  │                                        Data Loading                    │  │
│  │                                        (Associations)                  │  │
│  │                                                │                       │  │
│  │                                                ▼                       │  │
│  │                                        Serialization                   │  │
│  │                                        (JSON/GraphQL)                  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  REAL-TIME DATA FLOW:                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Event Source ──▶ Processing Engine ──▶ Phoenix.PubSub.broadcast     │  │
│  │       │                                         │                      │  │
│  │       │                              ┌──────────┴──────────┐          │  │
│  │       │                              │                     │          │  │
│  │       │                              ▼                     ▼          │  │
│  │       │                      WebSocket Channels     LiveView Updates  │  │
│  │       │                              │                     │          │  │
│  │       │                              ▼                     ▼          │  │
│  │       │                      Mobile Push           Browser Updates    │  │
│  │       │                      Notifications         (Phoenix LiveView) │  │
│  │       │                                                               │  │
│  │       │  PHICS v2.1 Data Sync (< 50ms latency):                      │  │
│  │       │  Host Files ◀──────────────▶ Container Files                 │  │
│  │       │  (Source)                    (Runtime)                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### LEVEL 3: TACTICAL DATA FLOW (Validation & Observability)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TACTICAL DATA PLANE (L3)                                  │
│                                                                              │
│  FPPS 5-METHOD VALIDATION DATA FLOW:                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Compilation Log (./data/tmp/1-compile.log)                           │  │
│  │       │                                                                │  │
│  │       ├───────────────┬───────────────┬───────────────┬──────────────│  │
│  │       ▼               ▼               ▼               ▼              ▼│  │
│  │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐│  │
│  │  │ Pattern │   │   AST   │   │Statistical│   │ Binary  │   │Line-by- ││  │
│  │  │ Method  │   │ Method  │   │  Method  │   │ Method  │   │  Line   ││  │
│  │  │         │   │         │   │          │   │         │   │ Method  ││  │
│  │  │80+ EP   │   │10 AST   │   │8 Keywords│   │8 Byte   │   │Context  ││  │
│  │  │patterns │   │patterns │   │weighted  │   │patterns │   │aware    ││  │
│  │  └────┬────┘   └────┬────┘   └────┬─────┘   └────┬────┘   └────┬────┘│  │
│  │       │              │              │              │              │   │  │
│  │       │              │              │              │              │   │  │
│  │       └──────────────┴──────────────┴──────────────┴──────────────┘   │  │
│  │                                     │                                  │  │
│  │                                     ▼                                  │  │
│  │                          ┌─────────────────────┐                      │  │
│  │                          │  CONSENSUS CHECK    │                      │  │
│  │                          │                     │                      │  │
│  │                          │  ∀ mᵢ, mⱼ ∈ ℳ₅:   │                      │  │
│  │                          │  Result[mᵢ] ≡ Result[mⱼ]                  │  │
│  │                          └─────────┬───────────┘                      │  │
│  │                                    │                                   │  │
│  │                          ┌─────────┴─────────┐                        │  │
│  │                          │                   │                        │  │
│  │                          ▼                   ▼                        │  │
│  │                    [CONSENSUS]         [DISAGREEMENT]                 │  │
│  │                          │                   │                        │  │
│  │                          ▼                   ▼                        │  │
│  │                    Continue            HALT + EP-110                  │  │
│  │                    Processing          Emergency Protocol             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  OBSERVABILITY DATA FLOW (Dual Logging):                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Application Event                                                     │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │              Logger.info(event)                              │     │  │
│  │  │                                                              │     │  │
│  │  │  config :logger,                                             │     │  │
│  │  │    backends: [:console, LoggerJSON]  # MANDATORY: Both       │     │  │
│  │  └─────────────────────────┬───────────────────────────────────┘     │  │
│  │                            │                                          │  │
│  │                 ┌──────────┴──────────┐                              │  │
│  │                 │                     │                              │  │
│  │                 ▼                     ▼                              │  │
│  │          ┌──────────┐          ┌──────────┐                         │  │
│  │          │ Terminal │          │  SigNoz  │                         │  │
│  │          │ Console  │          │ Backend  │                         │  │
│  │          └──────────┘          └──────────┘                         │  │
│  │                                      │                               │  │
│  │                                      ▼                               │  │
│  │                               ┌──────────┐                           │  │
│  │                               │ClickHouse│                           │  │
│  │                               │ (Traces) │                           │  │
│  │                               └──────────┘                           │  │
│  │                                                                        │  │
│  │  Constraint: SC-OBS-069 (Dual logging Terminal + SigNoz)              │  │
│  │  Constraint: If log in Terminal but NOT SigNoz = VIOLATION            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  TELEMETRY DATA FLOW:                                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  :telemetry.execute([:indrajaal, :operation, :complete], measurements, metadata) │
│  │       │                                                                │  │
│  │       ├──────────────────┬──────────────────┬────────────────────────│  │
│  │       ▼                  ▼                  ▼                        ▼│  │
│  │  Prometheus           Grafana          LiveDashboard          AlertManager │
│  │  (Metrics)           (Dashboards)      (Phoenix)              (Alerts)     │
│  │       │                  │                  │                        │   │
│  │       └──────────────────┴──────────────────┴────────────────────────┘   │
│  │                                                                        │  │
│  │  Required OTEL Modules (SC-OBS-071):                                  │  │
│  │  • OpentelemetryPhoenix                                               │  │
│  │  • OpentelemetryEcto                                                  │  │
│  │  • OpentelemetryOban                                                  │  │
│  │  • OpentelemetryFinch                                                 │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Mermaid: FPPS 5-Method Validation Flow**

```mermaid
flowchart TB
    LOG[("Compilation Log<br/>./data/tmp/1-compile.log")]

    subgraph FPPS["FPPS 5-METHOD VALIDATION (ℳ₅)"]
        M1[Pattern Method<br/>80+ EP patterns]
        M2[AST Method<br/>10 AST patterns]
        M3[Statistical Method<br/>8 weighted keywords]
        M4[Binary Method<br/>8 byte patterns]
        M5[Line-by-Line<br/>Context aware]
    end

    LOG --> M1 & M2 & M3 & M4 & M5

    M1 & M2 & M3 & M4 & M5 --> CONS{{"CONSENSUS CHECK<br/>∀ mᵢ, mⱼ ∈ ℳ₅:<br/>Result[mᵢ] ≡ Result[mⱼ]"}}

    CONS -->|Agreement| OK[✓ Continue<br/>Processing]
    CONS -->|Disagreement| HALT[⚠ HALT<br/>EP-110 Emergency]

    style LOG fill:#2ecc71,color:#fff
    style CONS fill:#f39c12,color:#fff
    style OK fill:#27ae60,color:#fff
    style HALT fill:#e74c3c,color:#fff
```

```mermaid
flowchart LR
    subgraph WRITE["WRITE PATH"]
        C1[Client] --> API1[API Controller]
        API1 --> DOM1[Domain API]
        DOM1 --> ASH1[Ash.create/update]
        ASH1 --> DB1[(Database)]
        DB1 --> AL[Audit Log]
        DB1 --> PS1[PubSub Broadcast]
    end

    subgraph READ["READ PATH"]
        C2[Client] --> API2[API Controller]
        API2 --> DOM2[Domain API]
        DOM2 --> ASH2[Ash.read]
        ASH2 -->|Tenant Filter| DB2[(Database)]
    end

    style ASH1 fill:#e74c3c,color:#fff
    style ASH2 fill:#3498db,color:#fff
```

---

### LEVEL 4: TASK-LEVEL DATA FLOW (Domain-Specific Data)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TASK-LEVEL DATA PLANE (L4)                                │
│                                                                              │
│  ALARM PROCESSING DATA FLOW:                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  AlarmEvent (Source: Device, Sensor, External API)                    │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │               ProcessingEngine.process/1                     │     │  │
│  │  │                                                              │     │  │
│  │  │  • Severity calculation                                      │     │  │
│  │  │  • Location mapping                                          │     │  │
│  │  │  • Device association                                        │     │  │
│  │  │  • Initial classification                                    │     │  │
│  │  └──────────────────────────┬──────────────────────────────────┘     │  │
│  │                             │                                          │  │
│  │                             ▼                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │              CorrelationEngine.correlate/1                   │     │  │
│  │  │                                                              │     │  │
│  │  │  • Time-based correlation                                    │     │  │
│  │  │  • Location proximity                                        │     │  │
│  │  │  • Pattern matching                                          │     │  │
│  │  │  • ML correlation                                            │     │  │
│  │  └──────────────────────────┬──────────────────────────────────┘     │  │
│  │                             │                                          │  │
│  │                             ▼                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │               WorkflowEngine.execute/1                       │     │  │
│  │  │                                                              │     │  │
│  │  │  • Template selection                                        │     │  │
│  │  │  • Step execution                                            │     │  │
│  │  │  • Notification dispatch                                     │     │  │
│  │  │  • Escalation rules                                          │     │  │
│  │  └──────────────────────────┬──────────────────────────────────┘     │  │
│  │                             │                                          │  │
│  │                             ▼                                          │  │
│  │                    Analytics & Reporting                               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ACCESS CONTROL DATA FLOW:                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Access Request (Card/Biometric/PIN)                                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │              Credential Validation                           │     │  │
│  │  │                                                              │     │  │
│  │  │  • Card/Biometric check                                      │     │  │
│  │  │  • Schedule verification                                     │     │  │
│  │  │  • Anti-passback rules                                       │     │  │
│  │  │  • Exception handling                                        │     │  │
│  │  └──────────────────────────┬──────────────────────────────────┘     │  │
│  │                             │                                          │  │
│  │                             ▼                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │              Decision Engine                                 │     │  │
│  │  │                                                              │     │  │
│  │  │  • Grant/Deny decision                                       │     │  │
│  │  │  • Reason codes                                              │     │  │
│  │  │  • Audit logging                                             │     │  │
│  │  │  • Event generation                                          │     │  │
│  │  └──────────────────────────┬──────────────────────────────────┘     │  │
│  │                             │                                          │  │
│  │                             ▼                                          │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │              Hardware Interface                              │     │  │
│  │  │                                                              │     │  │
│  │  │  • Door unlock command                                       │     │  │
│  │  │  • LED/buzzer control                                        │     │  │
│  │  │  • Camera snapshot                                           │     │  │
│  │  │  • Log generation                                            │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  MULTI-TENANT DATA ISOLATION:                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Every Database Query                                                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  TenantResource Behavior:                                             │  │
│  │  ├── prepare_query/3 ──▶ Adds tenant_id filter                       │  │
│  │  ├── Row-level security enforced                                      │  │
│  │  └── No cross-tenant access permitted                                 │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Policy Enforcement:                                                  │  │
│  │  ├── User tenant check                                                │  │
│  │  ├── Resource tenant check                                            │  │
│  │  ├── Operation validation                                             │  │
│  │  └── Audit trail                                                      │  │
│  │                                                                        │  │
│  │  Constraint: All queries MUST include tenant_id filtering             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### LEVEL 5: MICRO-TASK DATA FLOW (Atomic Data Operations)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MICRO-TASK DATA PLANE (L5)                                │
│                                                                              │
│  ASH CHANGESET DATA TRANSFORMATION:                                         │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Input Data                                                            │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Ash.Changeset.for_create(Resource, action, params)                   │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │  CHANGESET PIPELINE                                          │     │  │
│  │  │                                                              │     │  │
│  │  │  1. cast_primary_action                                      │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  2. apply_attributes                                         │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  3. changes (change blocks)                                  │     │  │
│  │  │       │   use change_attribute here (pre-validation)         │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  4. validations                                              │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  5. before_action (use force_change_attribute)               │     │  │
│  │  │       │   SC-ASH-001: MUST use force_change_attribute        │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  6. DATA LAYER COMMIT                                        │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  7. after_action (side effects allowed)                      │     │  │
│  │  │       │   SC-ASH-003: Side effects ONLY in after_action      │     │  │
│  │  │       ▼                                                      │     │  │
│  │  │  Result                                                      │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  │                                                                        │  │
│  │  WRONG PATTERN (SC-ASH-001 VIOLATION):                                │  │
│  │  before_action fn changeset ->                                        │  │
│  │    Ash.Changeset.change_attribute(changeset, :field, value)           │  │
│  │  end                                                                   │  │
│  │                                                                        │  │
│  │  CORRECT PATTERN:                                                      │  │
│  │  before_action fn changeset ->                                        │  │
│  │    Ash.Changeset.force_change_attribute(changeset, :field, value)     │  │
│  │  end                                                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  VALIDATION RESULT DATA STRUCTURE:                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  %ValidationResult{                                                   │  │
│  │    method: :pattern | :ast | :statistical | :binary | :line_by_line, │  │
│  │    errors: integer(),                                                 │  │
│  │    warnings: integer(),                                               │  │
│  │    timestamp: DateTime.t(),                                           │  │
│  │    log_path: String.t(),                                              │  │
│  │    consensus_status: :pending | :achieved | :failed                   │  │
│  │  }                                                                     │  │
│  │                                                                        │  │
│  │  Consensus Check (from Quint §Q5):                                    │  │
│  │                                                                        │  │
│  │  val disagreementTriggersEmergency: bool = {                          │  │
│  │    val errorCounts = Set(                                             │  │
│  │      validationResults.get(Pattern).errors,                           │  │
│  │      validationResults.get(AST).errors,                               │  │
│  │      validationResults.get(Statistical).errors,                       │  │
│  │      validationResults.get(Binary).errors,                            │  │
│  │      validationResults.get(LineByLine).errors                         │  │
│  │    ).filter(e => e >= 0)                                              │  │
│  │                                                                        │  │
│  │    (size(errorCounts) > 1) implies emergencyTriggered                 │  │
│  │  }                                                                     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  LOG DATA STRUCTURE (./data/tmp/):                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  claude_session_[timestamp]_[id].log      # Session summaries         │  │
│  │  claude_activity_[timestamp]_[id].jsonl   # Detailed activity         │  │
│  │  claude_performance_[timestamp]_[id].jsonl # Performance metrics      │  │
│  │  1-compile.log                             # Primary compilation log   │  │
│  │  fpps_report_[timestamp].json             # FPPS validation reports   │  │
│  │  emergency_validation_[timestamp].log      # Emergency protocol logs   │  │
│  │                                                                        │  │
│  │  Constraint: SC-VAL-005 (Complete audit trail in ./data/tmp)          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ERROR PATTERN DATA (EP-001 to EP-080 + EP-AGT):                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  %ErrorPattern{                                                       │  │
│  │    id: "EP-XXX",                                                      │  │
│  │    pattern: ~r/regex/,                                                │  │
│  │    severity: :critical | :high | :medium | :low,                      │  │
│  │    description: String.t(),                                           │  │
│  │    fix: String.t() | nil                                              │  │
│  │  }                                                                     │  │
│  │                                                                        │  │
│  │  Categories:                                                          │  │
│  │  • EP-001 to EP-020: Compilation errors (CRITICAL)                    │  │
│  │  • EP-021 to EP-040: Warning patterns (LOW-MEDIUM)                    │  │
│  │  • EP-041 to EP-060: Runtime errors (HIGH-CRITICAL)                   │  │
│  │  • EP-061 to EP-080: Validation errors (HIGH-CRITICAL)                │  │
│  │  • EP-AGT-001 to EP-AGT-013: Agent code errors (CRITICAL)             │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## PART III: EVOLUTIONARY CAPABILITY SYSTEM

### 3.1 CYBERNETIC FEEDBACK LOOPS (From §11 CLAUDE-math.md)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CYBERNETIC FEEDBACK SYSTEM                                │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    FOUR CORE FEEDBACK LOOPS                           │  │
│  │                                                                        │  │
│  │  PERFORMANCE LOOP:                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │ Observe ──▶ Orient ──▶ Decide ──▶ Act                       │     │  │
│  │  │    │          │          │         │                         │     │  │
│  │  │    ▼          ▼          ▼         ▼                         │     │  │
│  │  │ Execution  Resource   Throughput  Automatic                  │     │  │
│  │  │ Speed      Efficiency Optimization Adjustment                │     │  │
│  │  │ Monitoring Tracking                                          │     │  │
│  │  └────────────────────────────────┬────────────────────────────┘     │  │
│  │                                   │                                   │  │
│  │  QUALITY LOOP:                    │                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │ Observe ──▶ Orient ──▶ Decide ──▶ Act                       │     │  │
│  │  │    │          │          │         │                         │     │  │
│  │  │    ▼          ▼          ▼         ▼                         │     │  │
│  │  │ Error      Pattern    Continuous Quality Gate               │     │  │
│  │  │ Detection  Recognition Improvement Enforcement               │     │  │
│  │  └────────────────────────────────┬────────────────────────────┘     │  │
│  │                                   │                                   │  │
│  │  LEARNING LOOP:                   │                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │ Observe ──▶ Orient ──▶ Decide ──▶ Act                       │     │  │
│  │  │    │          │          │         │                         │     │  │
│  │  │    ▼          ▼          ▼         ▼                         │     │  │
│  │  │ Pattern    Strategy   Knowledge  Best Practice              │     │  │
│  │  │ Recognition Refinement Base Update Codification              │     │  │
│  │  │ From Executions                                              │     │  │
│  │  └────────────────────────────────┬────────────────────────────┘     │  │
│  │                                   │                                   │  │
│  │  SAFETY LOOP (HIGHEST PRIORITY):  │                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │ Observe ──▶ Orient ──▶ Decide ──▶ Act                       │     │  │
│  │  │    │          │          │         │                         │     │  │
│  │  │    ▼          ▼          ▼         ▼                         │     │  │
│  │  │ Risk       Constraint Emergency   Rollback                  │     │  │
│  │  │ Monitoring Validation Response    Capability                │     │  │
│  │  │ (𝒮𝒞₁₉₅)             Protocols   Maintenance                │     │  │
│  │  │                                                              │     │  │
│  │  │ Latency Constraint: δ < 1s (Emergency Response)              │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  │                                                                        │  │
│  │  OODA LATENCY CONSTRAINTS (from CLAUDE-math.md):                      │  │
│  │  • Agent OODA: δ < 5 seconds                                          │  │
│  │  • AIE OODA: δ < 50ms                                                 │  │
│  │  • Emergency OODA: δ < 1 second                                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Mermaid: Cybernetic Feedback Loops**

```mermaid
flowchart TB
    subgraph CYBER["CYBERNETIC FEEDBACK SYSTEM"]
        subgraph PERF["PERFORMANCE LOOP"]
            PO[Observe<br/>Execution Speed] --> POR[Orient<br/>Resource Efficiency]
            POR --> PD[Decide<br/>Throughput Opt]
            PD --> PA[Act<br/>Auto Adjustment]
            PA -->|Feedback| PO
        end

        subgraph QUAL["QUALITY LOOP"]
            QO[Observe<br/>Error Detection] --> QOR[Orient<br/>Pattern Recognition]
            QOR --> QD[Decide<br/>Improvement]
            QD --> QA[Act<br/>Gate Enforcement]
            QA -->|Feedback| QO
        end

        subgraph LEARN["LEARNING LOOP"]
            LO[Observe<br/>Pattern Mining] --> LOR[Orient<br/>Strategy Refinement]
            LOR --> LD[Decide<br/>Knowledge Update]
            LD --> LA[Act<br/>Best Practice Codify]
            LA -->|Feedback| LO
        end

        subgraph SAFE["SAFETY LOOP (Priority)"]
            SO[Observe<br/>Risk Monitor<br/>𝒮𝒞₁₉₅] --> SOR[Orient<br/>Constraint Validation]
            SOR --> SD[Decide<br/>Emergency Response]
            SD --> SA[Act<br/>Rollback Capability]
            SA -->|Feedback δ < 1s| SO
        end
    end

    style SAFE fill:#e74c3c,color:#fff
    style PERF fill:#3498db,color:#fff
    style QUAL fill:#2ecc71,color:#fff
    style LEARN fill:#9b59b6,color:#fff
```

### 3.2 GOAL-DIRECTED EVOLUTION (GDE) ALGORITHM

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GOAL-DIRECTED EVOLUTION (GDE)                             │
│                    (From §17.6 CLAUDE-math.md)                               │
│                                                                              │
│  ALGORITHM STEPS:                                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Step 1: HYPOTHESIZE                                                  │  │
│  │  ────────────────────                                                 │  │
│  │  GenerateCandidateTransition[S, S_next]                               │  │
│  │  • Analyze current system state S                                     │  │
│  │  • Generate candidate next states S_next                              │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Step 2: SIMULATE                                                     │  │
│  │  ────────────────────                                                 │  │
│  │  EvaluateProbability[Success | T, KnowledgeBase, Ψ]                   │  │
│  │  • Calculate success probability                                      │  │
│  │  • Check against safety constraints Ψ (𝒮𝒞₁₉₅)                        │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Step 3: SELECT                                                       │  │
│  │  ────────────────────                                                 │  │
│  │  ArgMax[Value[S_next], Subject[Ψ]]                                    │  │
│  │  • Select highest value transition                                    │  │
│  │  • Subject to all safety constraints                                  │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Step 4: EXECUTE                                                      │  │
│  │  ────────────────────                                                 │  │
│  │  PerformTransition[AEETools]                                          │  │
│  │  • Execute using AEE (Autonomous Execution Engine)                    │  │
│  │  • Use Patient Mode compilation                                       │  │
│  │  • Use FPPS validation                                                │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Step 5: VERIFY                                                       │  │
│  │  ────────────────────                                                 │  │
│  │  Check[S_realized ≈ S_next]                                           │  │
│  │  • Verify actual state matches expected                               │  │
│  │  • If mismatch: trigger learning loop                                 │  │
│  │       │                                                                │  │
│  │       ▼                                                                │  │
│  │  Step 6: LOOP                                                         │  │
│  │  ────────────────────                                                 │  │
│  │  Goto Step 1 (Continuous Evolution)                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  CORE CYBERNETIC PARAMETERS:                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  δᵒᵒᵈᵃ (Loop Latency):                                                │  │
│  │  • Agent: 5 seconds                                                   │  │
│  │  • AIE: 50ms                                                          │  │
│  │  • Emergency: 1 second                                                │  │
│  │                                                                        │  │
│  │  η (System Entropy):                                                  │  │
│  │  • Goal: dη/dt ≤ 0 (Entropy never increases)                          │  │
│  │                                                                        │  │
│  │  v_evol (Evolution Velocity):                                         │  │
│  │  • Goal: Maximize subject to Ψ (safety constraints)                   │  │
│  │                                                                        │  │
│  │  χ (Coupling Coefficient):                                            │  │
│  │  • Goal: Minimize (reduce inter-component dependencies)               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Mermaid: Goal-Directed Evolution (GDE) Algorithm**

```mermaid
flowchart TB
    subgraph GDE["GOAL-DIRECTED EVOLUTION (GDE)"]
        S1[Step 1: HYPOTHESIZE<br/>Generate Candidate<br/>Transitions S → S']
        S2[Step 2: SIMULATE<br/>Evaluate P(Success)<br/>Check Ψ Constraints]
        S3[Step 3: SELECT<br/>ArgMax Value S'<br/>Subject to Ψ]
        S4[Step 4: EXECUTE<br/>Perform Transition<br/>via AEE Tools]
        S5[Step 5: VERIFY<br/>Check S_realized ≈ S']
        S6[Step 6: LOOP<br/>Return to Step 1]

        S1 --> S2
        S2 --> S3
        S3 --> S4
        S4 --> S5
        S5 --> S6
        S6 -->|Continuous| S1

        S5 -->|Mismatch| LEARN[Trigger Learning Loop]
    end

    subgraph CONSTRAINTS["Safety Constraints Ψ"]
        PSI[𝒮𝒞₁₉₅<br/>195 STAMP Constraints]
    end

    S2 <--> CONSTRAINTS

    style S1 fill:#3498db,color:#fff
    style S2 fill:#9b59b6,color:#fff
    style S3 fill:#e67e22,color:#fff
    style S4 fill:#2ecc71,color:#fff
    style S5 fill:#1abc9c,color:#fff
    style S6 fill:#34495e,color:#fff
    style LEARN fill:#e74c3c,color:#fff
```

### 3.3 CYBERNETIC ARCHITECT PERSONA (𝒫ᶜᴬ)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CYBERNETIC ARCHITECT PERSONA                              │
│                    (From §17 CLAUDE-math.md)                                 │
│                                                                              │
│  FORMAL DEFINITION:                                                         │
│  𝒫ᶜᴬ := <|                                                                  │
│    "𝒢" -> Graph[V, E],     (* System Graph: V = Components, E = Contracts *)│
│    "𝒦" -> KolmogorovComplexity,  (* Objective: min(𝒦) - minimize complexity *)│
│    "Ω" -> OODALoops,       (* Observation-Orientation-Decision-Action *)     │
│    "Ψ" -> 𝒮𝒞₁₉₅           (* Safety Constraints Subset *)                  │
│  |>                                                                          │
│                                                                              │
│  ENTROPY FIGHTER CONSTRAINT:                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  Apply[change] ⟹ (Complexity[S'] ≤ Complexity[S] + ε) ∧ Valid[Ψ, S'] │  │
│  │                                                                        │  │
│  │  Translation:                                                          │  │
│  │  Any change to the system MUST:                                        │  │
│  │  1. Not increase complexity beyond tolerance ε                         │  │
│  │  2. Maintain validity of all safety constraints                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  EXECUTION CONTEXTS:                                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  DEV-TIME:                                                            │  │
│  │  • Objective: Minimize[χ] ∧ Minimize[𝒦]                               │  │
│  │  • Focus: Decoupling, Simplicity                                      │  │
│  │                                                                        │  │
│  │  TEST-TIME:                                                           │  │
│  │  • Objective: Maximize[Antifragility[α]]                              │  │
│  │  • Focus: Stress Testing, Chaos Injection                             │  │
│  │                                                                        │  │
│  │  RUNTIME:                                                             │  │
│  │  • Objective: Minimize[δᵒᵒᵈᵃ] ∧ Maintain[Homeostasis]                 │  │
│  │  • Focus: Speed, Stability                                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  THE CYBERNETIC PLEDGE:                                                     │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  "I recognize the Codebase as a Living Graph.                         │  │
│  │   I pledge to fight Entropy with Simplicity,                          │  │
│  │   fragility with Resilience,                                          │  │
│  │   and blindness with Observability.                                   │  │
│  │   I am the Architect of the Loop."                                    │  │
│  │                                                                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.4 AUTONOMIC SYSTEM VISION (From GEMINI_VISION_AUTONOMIC_SYSTEM.md)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTONOMIC CYBERNETIC SYSTEM (ACS)                         │
│                    5-LAYER BIOLOGICAL ARCHITECTURE                           │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  LAYER 5: THE CORTEX (Cognitive Control) - NEW                        │  │
│  │  ────────────────────────────────────────                             │  │
│  │  Component: Indrajaal.Cortex (Distributed Horde Process)              │  │
│  │  Analogy: The Brain                                                   │  │
│  │  Behavior:                                                            │  │
│  │  • Senses: Consumes Telemetry/SigNoz streams in real-time            │  │
│  │  • Thinks: Calculates "System Stress Score"                          │  │
│  │  • Acts: Dynamically tunes FLAME.Pool sizes, DB pool limits          │  │
│  │  • Speaks: Generates "Evolutionary Proposals" for AEE                │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────┐     │  │
│  │  │  LAYER 4: THE REFLEX (Immediate Response)                    │     │  │
│  │  │  ────────────────────────────────────────                    │     │  │
│  │  │  Component: Circuit Breakers & Rate Limiters                 │     │  │
│  │  │  Analogy: Sympathetic Nervous System (Fight or Flight)       │     │  │
│  │  │  Behavior: Millisecond-level reactions to trauma             │     │  │
│  │  │  "Pain" (Latency) triggers "Withdrawal" (Shedding Load)      │     │  │
│  │  │                                                              │     │  │
│  │  │  ┌─────────────────────────────────────────────────────┐    │     │  │
│  │  │  │  LAYER 3: THE LIMBS (Elastic Action)                │    │     │  │
│  │  │  │  ────────────────────────────────────                │    │     │  │
│  │  │  │  Component: FLAME Runners                            │    │     │  │
│  │  │  │  Analogy: Musculature                                │    │     │  │
│  │  │  │  Behavior: Grows temporary limbs for heavy lifting   │    │     │  │
│  │  │  │  (Intelligence/Video) and sheds them when done       │    │     │  │
│  │  │  │                                                      │    │     │  │
│  │  │  │  ┌─────────────────────────────────────────────┐    │    │     │  │
│  │  │  │  │  LAYER 2: THE CELL (The Node)               │    │    │     │  │
│  │  │  │  │  ────────────────────────────────            │    │    │     │  │
│  │  │  │  │  Component: Elixir/BEAM Node + Sentinel      │    │    │     │  │
│  │  │  │  │  Analogy: Cellular Structure                 │    │    │     │  │
│  │  │  │  │  Behavior: Each cell has "nucleus" (Sentinel)│    │    │     │  │
│  │  │  │  │  ensuring genetic integrity (Quorum)         │    │    │     │  │
│  │  │  │  │  If cancerous (Split-Brain) → Apoptosis     │    │    │     │  │
│  │  │  │  │                                              │    │    │     │  │
│  │  │  │  │  ┌─────────────────────────────────────┐    │    │    │     │  │
│  │  │  │  │  │  LAYER 1: THE SUBSTRATE (Network)  │    │    │    │     │  │
│  │  │  │  │  │  ────────────────────────────────   │    │    │    │     │  │
│  │  │  │  │  │  Component: Tailscale Mesh/WireGuard│    │    │    │     │  │
│  │  │  │  │  │  Analogy: Circulatory System        │    │    │    │     │  │
│  │  │  │  │  │  Behavior: Transports data/signals  │    │    │    │     │  │
│  │  │  │  │  │  securely; heals around blockages   │    │    │    │     │  │
│  │  │  │  │  └─────────────────────────────────────┘    │    │    │     │  │
│  │  │  │  └─────────────────────────────────────────────┘    │    │     │  │
│  │  │  └─────────────────────────────────────────────────────┘    │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  SUCCESS CRITERIA:                                                          │
│  1. System stays up during chaos test WITHOUT human intervention            │
│  2. System LOGS a suggestion that actually improves its own performance     │
│  3. Architecture diagram looks like a FRACTAL, not a stack                  │
│                                                                              │
│  CYBERNETIC LOOP CLOSED:                                                    │
│  Code → Runtime → Stress → Cortex → Proposal → Agent → Code                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.5 FLAME HYBRID ARCHITECTURE (From 20251217-HA-FLAME-hybrid-architecture.md)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLAME HYBRID CORE-SATELLITE ARCHITECTURE                  │
│                                                                              │
│  STRATEGIC SHIFT:                                                           │
│  • Previous: "Scale Out" (Add more permanent nodes)                         │
│  • New: "Scale Up/Down On-Demand" (Ephemeral nodes for specific tasks)     │
│                                                                              │
│  TWO PLANES:                                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  CONTROL PLANE (Core) - PERSISTENT                                    │  │
│  │  ────────────────────────────────────                                 │  │
│  │  ┌───────────────────────────────────────────────────────────────┐   │  │
│  │  │                     Indrajaal App (x3)                         │   │  │
│  │  │  • Static HA (3+ nodes)                                        │   │  │
│  │  │  • HTTP/WS handling                                            │   │  │
│  │  │  • PubSub hub                                                  │   │  │
│  │  │  • Cluster Sentinel                                            │   │  │
│  │  │  • DB Connection Pool                                          │   │  │
│  │  │  • 50-Agent Coordination                                       │   │  │
│  │  └───────────────────────────────────────────────────────────────┘   │  │
│  │                              │                                        │  │
│  │                              ▼                                        │  │
│  │  COMPUTE PLANE (Satellites) - EPHEMERAL                              │  │
│  │  ────────────────────────────────────                                │  │
│  │  ┌───────────────────────────────────────────────────────────────┐   │  │
│  │  │                     FLAME Runners                              │   │  │
│  │  │  • Elastic (0 to ∞)                                            │   │  │
│  │  │  • "Heavy Lifting": ML Inference, Video, Reports               │   │  │
│  │  │  • Spawn on demand, terminate after idle_shutdown_after        │   │  │
│  │  │                                                                │   │  │
│  │  │  Pool Strategies:                                              │   │  │
│  │  │  ├── IntelligencePool: min:0, max:10 (High CPU Runners)       │   │  │
│  │  │  ├── VideoPool: min:0, max:20 (GPU Runners future)            │   │  │
│  │  │  ├── AnalyticsPool: min:0, max:5 (High RAM Runners)           │   │  │
│  │  │  └── MaintenancePool: min:0, max:2 (I/O Intensive)            │   │  │
│  │  └───────────────────────────────────────────────────────────────┘   │  │
│  │                                                                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  FLAME CODE PATTERN:                                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                        │  │
│  │  def analyze_threat(data) do                                          │  │
│  │    FLAME.call(Indrajaal.FLAME.IntelligencePool, fn ->                │  │
│  │      # This code runs on the ephemeral runner                        │  │
│  │      Indrajaal.Intelligence.Engine.run_inference(data)               │  │
│  │    end)                                                               │  │
│  │  end                                                                   │  │
│  │                                                                        │  │
│  │  Execution Path:                                                      │  │
│  │  1. Request arrives at Core Node A                                    │  │
│  │  2. Domain determines task is heavy                                   │  │
│  │  3. FLAME.call triggers                                               │  │
│  │  4. Dev: Spawns local process                                         │  │
│  │     Prod: K8s API → Schedule Pod → Boot → Connect                    │  │
│  │  5. Function runs on Child Node                                       │  │
│  │  6. Result returns to Parent                                          │  │
│  │  7. Child terminates after idle_shutdown_after                        │  │
│  │                                                                        │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  FLAME SAFETY CONSTRAINTS (SC-FLAME):                                       │
│  • SC-FLAME-001: Runners MUST NOT rely on local state                      │
│  • SC-FLAME-002: Runners MUST fetch fresh state from DB                    │
│  • SC-FLAME-003: Workloads MUST be isolated into pools                     │
│  • SC-FLAME-004: Timeouts and fallbacks MUST be implemented                │
│  • SC-FLAME-005: Parent MUST handle runner crashes gracefully              │
│  • SC-FLAME-006: Backend MUST be configurable via runtime.exs              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## PART IV: RUNTIME CONSTRAINTS (FORMAL VERIFICATION)

### 4.1 QUINT STATE MACHINE VERIFICATION (From §Q1-Q11 CLAUDE-math.md)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    QUINT FORMAL VERIFICATION COVERAGE                        │
│                                                                              │
│  MODULE: AgentStateMachine (§Q2)                                            │
│  ──────────────────────────────                                             │
│  • State Space: Idle | Active | Blocked | Error | Recovering | Terminated   │
│  • Transitions: δ function from Mathematica made executable                  │
│  • Safety Invariant: noDeadlock - at least one agent can progress           │
│  • Liveness: Task eventually completes or fails                             │
│                                                                              │
│  MODULE: FPPSConsensus (§Q5)                                                │
│  ─────────────────────────                                                  │
│  • EP-110 Prevention: disagreementTriggersEmergency                         │
│  • Consensus Check: All 5 methods must agree                                │
│  • Emergency Trigger: Automatic on disagreement                             │
│                                                                              │
│  MODULE: PatientModeProtocol (§Q6)                                          │
│  ───────────────────────────────                                            │
│  • Forbidden Actions: partialAnalysisForbidden, timeoutForbidden            │
│  • Correct Log Path: ./data/tmp/1-compile.log                               │
│  • Compilation Completes: Liveness with fairness                            │
│                                                                              │
│  MODULE: ContainerProtocol (§Q7)                                            │
│  ──────────────────────────────                                             │
│  • alwaysPodman: Runtime ≡ Podman                                           │
│  • onlyLocalhostRegistry: No external registries                            │
│  • phicsLatencyCompliant: < 50ms                                            │
│  • dockerForbidden, externalRegistryForbidden                               │
│                                                                              │
│  MODULE: STAMPConstraints (§Q8)                                             │
│  ──────────────────────────────                                             │
│  • allSTAMPSatisfied: Combined verification of all 195 constraints          │
│  • Violation detection and response                                         │
│                                                                              │
│  MODULE: CyberneticLoops (§Q9)                                              │
│  ──────────────────────────────                                             │
│  • OODA Phase transitions                                                   │
│  • Latency constraints verification                                         │
│  • Loop completion fairness                                                 │
│                                                                              │
│  MODULE: EmergencyProtocol (§Q10)                                           │
│  ────────────────────────────────                                           │
│  • Phase progression: Detected → Halted → Logged → RCA → Mitigated → Recovered │
│  • Halt within 5 seconds (SC-EMR-057)                                       │
│  • Rollback capability maintained                                           │
│                                                                              │
│  VERIFICATION COMMANDS:                                                     │
│  quint verify --invariant=masterInvariant ModelCheckingHarness.qnt          │
│  quint verify --invariant=patientModeInvariant --max-steps=50               │
│  quint verify --invariant=containerInvariant --max-steps=50                 │
│  quint verify --invariant=allSTAMPSatisfied --max-steps=100                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 AGDA PROOF SPECIFICATIONS (From §A1-A8 CLAUDE-math.md)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGDA ETERNAL PROOFS                                       │
│                                                                              │
│  KEY THEOREMS PROVEN:                                                       │
│                                                                              │
│  §A2.3: total-is-50                                                         │
│  ────────────────────                                                       │
│  totalAgents : ℕ                                                            │
│  totalAgents = 1 + 10 + 15 + 24                                             │
│  total-is-50 : totalAgents ≡ 50                                             │
│  total-is-50 = refl  -- Agda computes and verifies!                         │
│                                                                              │
│  §A2.5: executive-no-supervisor                                             │
│  ──────────────────────────────                                             │
│  executive-no-supervisor : ¬ HasSupervisor executive                        │
│  executive-no-supervisor ()  -- Absurd pattern: no constructor!             │
│                                                                              │
│  §A3.6: disagreement-triggers-emergency (EP-110 Prevention)                 │
│  ──────────────────────────────────────────────────────────                 │
│  disagreement-triggers-emergency :                                           │
│    (results : Vec ValidationResult 5) →                                      │
│    (¬consensus : ¬ Consensus results) →                                      │
│    checkConsensus results (no ¬consensus) ≡ Emergency                       │
│  disagreement-triggers-emergency results ¬consensus = refl                   │
│                                                                              │
│  §A4.9: nonCompliant-fails                                                  │
│  ─────────────────────────                                                  │
│  nonCompliant-fails : ¬ Axiom1 nonCompliantConfig                           │
│  -- PROOF: Non-patient configs CANNOT compile (type system rejects)         │
│                                                                              │
│  §A5.7: docker-forbidden                                                    │
│  ─────────────────────                                                      │
│  docker-forbidden : (cfg : ContainerConfig) →                               │
│                     ContainerConfig.runtime cfg ≡ Docker →                  │
│                     ¬ Axiom2 cfg                                             │
│  -- PROOF: Docker violates Axiom 2 (contradiction)                          │
│                                                                              │
│  §A6.3: <ₚ-wellFounded (Emergency Termination)                              │
│  ─────────────────────────────────────────────                              │
│  <ₚ-wellFounded : WellFounded _<ₚ_                                          │
│  -- PROOF: Emergency response ALWAYS terminates                             │
│                                                                              │
│  §A6.6: eventually-recovered                                                │
│  ──────────────────────────                                                 │
│  eventually-recovered : (p : EmergencyPhase) →                              │
│    iterate handleEmergency (stepsToRecovered p) p ≡ Recovered               │
│  -- PROOF: Any emergency phase reaches Recovered                            │
│                                                                              │
│  §A7.7: VerifiedSystem                                                      │
│  ─────────────────────                                                      │
│  -- Construction of VerifiedSystem PROVES all STAMP constraints             │
│  -- The TYPE IS the proof (Curry-Howard correspondence)                     │
│                                                                              │
│  THREE-PILLAR VERIFICATION:                                                 │
│  ┌─────────────────────────────────────────────────────────────┐           │
│  │  LAYER 3: AGDA (Eternal Proofs)                             │           │
│  │  ├─ Type-level guarantees                                   │           │
│  │  ├─ Proofs of termination                                   │           │
│  │  └─ Code extraction to Haskell                              │           │
│  │                                                              │           │
│  │  LAYER 2: QUINT (Behavioral Verification)                   │           │
│  │  ├─ State machine model checking                            │           │
│  │  ├─ Counterexample generation                               │           │
│  │  └─ Bounded state exploration                               │           │
│  │                                                              │           │
│  │  LAYER 1: MATHEMATICA (Specification)                       │           │
│  │  ├─ Human-readable notation                                 │           │
│  │  └─ Foundation for upper layers                             │           │
│  └─────────────────────────────────────────────────────────────┘           │
│                                                                              │
│  VERIFICATION FLOW:                                                         │
│  Mathematica (WHAT) → Quint (WHETHER, bounded) → Agda (FOREVER)             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## PART V: COMPLIANCE MATRIX

### 5.1 STAMP 195 SAFETY CONSTRAINTS COVERAGE

| Category | ID Range | Count | Description | Control Flow Level | Data Flow Level |
|----------|----------|-------|-------------|-------------------|-----------------|
| A: Validation | SC-VAL-001 to SC-VAL-008 | 8 | Patient Mode, FPPS, Consensus | L3, L4, L5 | L3 |
| B: Container | SC-CNT-009 to SC-CNT-016 | 8 | Podman, localhost, PHICS | L1, L2 | L1, L2 |
| C: Agent Coord | SC-AGT-017 to SC-AGT-024 | 8 | 50-agent hierarchy, deadlock | L2, L3 | L2 |
| D: Compilation | SC-CMP-025 to SC-CMP-035 | 11 | Zero warnings, parallel | L3, L4 | L3 |
| E: Data Integrity | SC-DAT-033 to SC-DAT-040 | 8 | Corruption, audit, versioning | L4, L5 | L3, L4, L5 |
| F: Security | SC-SEC-041 to SC-SEC-048 | 8 | Access, credentials, encryption | L2, L4 | L2, L4 |
| G: Performance | SC-PRF-049 to SC-PRF-056 | 8 | Response time, resource | L1, L4 | L1, L4 |
| H: Emergency | SC-EMR-057 to SC-EMR-064 | 8 | Stop <5s, rollback | L1, L5 | L5 |
| I: Observability | SC-OBS-065 to SC-OBS-072 | 8 | Logging, OTEL, dual backend | L3 | L3 |
| J: Agent Code | SC-AGT-025 to SC-AGT-030 | 6 | Compile check, DSL patterns | L4, L5 | L4 |
| K: PropCheck | SC-PROP-021 to SC-PROP-025 | 5 | Safe generators | L4 | L4 |
| L: Ash Changeset | SC-ASH-001 to SC-ASH-010 | 10 | force_change_attribute | L4, L5 | L5 |
| M: Database | SC-DB-001 to SC-DB-042 | 42 | Schema, migrations | L4, L5 | L4, L5 |
| N: Documentation | SC-DOC-001 to SC-DOC-020 | 20 | Journal, CLAUDE.md backup | L3 | L3 |
| O: Batch | SC-BATCH-001 to SC-BATCH-005 | 5 | Incremental fix protocol | L4 | L4 |
| P: Factory | SC-FAC-001 to SC-FAC-012 | 12 | Test factories | L4 | L4 |
| Q: FLAME | SC-FLAME-001 to SC-FLAME-006 | 6 | Ephemeral runners | L1, L3 | L1, L2 |
| R: Clustering | SC-CLU-001 to SC-CLU-005 | 5 | HA mesh, quorum | L1, L2 | L1 |
| S: Claude API | SC-CLAUDE-API-001 to SC-CLAUDE-API-005 | 5 | Context management | L3 | L3 |
| T: Claude Agent | SC-CLAUDE-001 to SC-CLAUDE-007 | 7 | Safety constraints | L4 | L4 |
| U: Cybernetic | SC-CA-001 to SC-CA-004 | 4 | Architect persona | L1 | L1 |
| W: Operational | SC-OPS-001 to SC-OPS-004 | 4 | Preflight, ports | L1, L4 | L1 |
| X: Network | SC-NET-001, SC-OBS-001 | 2 | DNS, logging | L1 | L1 |
| **TOTAL** | | **195** | | | |

### 5.2 AXIOM COMPLIANCE MATRIX

| Axiom | Description | Control Flow | Data Flow | Quint Module | Agda Proof |
|-------|-------------|--------------|-----------|--------------|------------|
| Ω₁ | Patient Mode | L3 (Compilation) | L3 (Log storage) | PatientModeProtocol | §A4 |
| Ω₂ | Container Isolation | L1, L2 | L1 | ContainerProtocol | §A5 |
| Ω₃ | Zero-Defect Quality | L3, L4 | L3 | Quality invariant | Implicit |
| Ω₄ | TDG Invariant | L4 | L4 | TDG validation | Implicit |
| Ω₅ | Validation Consensus | L3 | L3 | FPPSConsensus | §A3 |
| Ω₆ | Mandatory Gates | L4 | L3, L4 | Gate validation | Implicit |

### 5.3 LTL PROPERTY COVERAGE

| Property | Type | Description | Verification |
|----------|------|-------------|--------------|
| LTL-1 | Safety | No timeout during compilation | Quint §Q6 |
| LTL-2 | Safety | Success requires consensus | Quint §Q5 |
| LTL-3 | Safety | All execution in containers | Quint §Q7 |
| LTL-4 | Safety | Timestamps never UTC | Manual |
| LTL-5 | Safety | Only localhost registry | Quint §Q7 |
| LTL-6 | Safety | Agent requires supervisor | Quint §Q2 |
| LTL-7 | Liveness | Compilation → Analysis | Quint |
| LTL-8 | Liveness | Error → RCA → Fix | Quint §Q10 |
| LTL-9 | Liveness | Failure → Recovery | Quint §Q10 |
| LTL-10 | Liveness | Change → Validation | Quint §Q5 |
| LTL-11 | Fairness | Agent eventually executed | Quint §Q2 |
| LTL-12 | Fairness | Container gets task | Quint §Q7 |

---

## APPENDIX A: COMMAND REFERENCE

### Patient Mode Compilation
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5 \
mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```

### FPPS Validation
```bash
elixir scripts/validation/comprehensive_compilation_validator.exs \
  --log ./data/tmp/1-compile.log --require-consensus --save-report
```

### Container Management
```bash
elixir scripts/performance/podman_direct_manager.exs --status
podman-compose -f podman-compose.yml up -d
```

### Agent Coordination
```bash
elixir scripts/coordination/multi_agent_coordinator.exs --deploy
elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status
```

### STAMP Validation
```bash
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all
```

### Emergency Response
```bash
elixir scripts/emergency/emergency_stop.exs
elixir scripts/emergency/emergency_recovery.exs
elixir scripts/emergency/emergency_rollback.exs
```

---

## APPENDIX B: IMPLEMENTATION ROADMAP

> **Reference Document**: `20251217-criticality-based-5level-implementation-plan.md`
> **Relationship**: This appendix summarizes the implementation strategy; the referenced document contains full implementation details.

### B.1 CURRENT SYSTEM STATE (2025-12-17)

| Metric | Value | Status |
|--------|-------|--------|
| Source Files | 815 | Healthy |
| Test Files | 649 | Growing |
| Compilation | 0 errors, 0 warnings | PASSING |
| Ash Resources | 22 | Foundation complete |
| Ash Domains | 13 | Core domains active |
| Domain Directories | 72 | Structured |

### B.2 CAPABILITY MATURITY ASSESSMENT

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CAPABILITY MATURITY PYRAMID                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                           ▲ C4: Autonomic                                   │
│                          ╱ ╲  (0% - NOT STARTED)                            │
│                         ╱   ╲ Cortex, GDE, Self-Healing                     │
│                        ╱─────╲                                               │
│                       ╱ C3:   ╲                                             │
│                      ╱ Intel   ╲ (10% - MINIMAL)                            │
│                     ╱  ML/Nx    ╲ Alert.ex exists, no Nx                    │
│                    ╱─────────────╲                                           │
│                   ╱  C2: Distrib  ╲                                         │
│                  ╱   FLAME/Mesh    ╲ (15% - PARTIAL)                        │
│                 ╱  Basic Sentinel   ╲                                        │
│                ╱─────────────────────╲                                       │
│               ╱  C1: Production       ╲                                     │
│              ╱   Observability/Alerts  ╲ (40% - IN PROGRESS)                │
│             ╱  Telemetry, HealthCheck   ╲                                    │
│            ╱─────────────────────────────╲                                   │
│           ╱     C0: FOUNDATION            ╲                                 │
│          ╱  Core Domains, Ash, Phoenix     ╲ (85% - SOLID)                  │
│         ╱  Compilation, Quality Gates       ╲                                │
│        ╱─────────────────────────────────────╲                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### B.3 CRITICALITY-BASED IMPLEMENTATION ORDER

| Tier | Name | Focus | Architecture Mapping | Priority |
|------|------|-------|---------------------|----------|
| C0 | Foundation | Core stability | L5 (Micro-Task), L4 (Task) | COMPLETE |
| C1 | Production | Observability | L3 (Tactical), L2 (Operational) | HIGH |
| C2 | Distributed | FLAME/HA | L2 (Operational), L1 (Strategic) | MEDIUM |
| C3 | Intelligence | ML/Analytics | L2-L3 (Decision Support) | LOWER |
| C4 | Autonomic | Self-Evolution | L1 (Strategic) | FUTURE |

### B.4 EVOLUTIONARY PROGRESSION

```
C0 (Foundation)        C1 (Production)       C2 (Distributed)      C3 (Intelligence)    C4 (Autonomic)
     │                      │                      │                      │                    │
     ├── Ash Resources      ├── OpenTelemetry      ├── FLAME Pools        ├── Nx.Serving       ├── Cortex
     ├── Phoenix API        ├── HealthCheck        ├── Sentinel HA        ├── AnomalyDetector  ├── GDE Algorithm
     ├── Ecto/Postgres      ├── AlertManager       ├── libcluster         ├── Broadway ML      ├── Self-Healing
     ├── Oban Jobs          ├── Grafana Dash       ├── Horde              ├── Pattern Mining   ├── Homeostasis
     └── Quality Gates      └── PagerDuty          └── ConsistentHash     └── Forecasting      └── Evolution
           │                      │                      │                      │                    │
           ▼                      ▼                      ▼                      ▼                    ▼
      [85% DONE]            [40% DONE]             [15% DONE]             [10% DONE]           [0% DONE]
```

### B.5 ARCHITECTURE-TO-IMPLEMENTATION TRACEABILITY

| Architecture Section | Implementation Tier | Status |
|---------------------|---------------------|--------|
| §1.1 Agent Hierarchy | C0-C2 | Partial (structure defined, FLAME pending) |
| §1.2 OODA Loops | C1-C4 | Minimal (monitoring only) |
| §1.3 Cybernetic Controller | C3-C4 | Not started |
| §2.1 Strategic Data Flow | C2-C4 | Partial (basic flow, no FLAME) |
| §2.2 Operational Data Flow | C0-C1 | Mostly complete |
| §3.1 GDE Algorithm | C4 | Not started |
| §3.2 ACS Capability System | C2-C4 | Foundation only |
| §4.1 PHICS v2.1 | C1 | Partial |
| §4.2 FLAME Backend | C2 | Not implemented |
| §5.0 STAMP Compliance | C0-C1 | Core constraints met |

### B.6 NEXT IMMEDIATE ACTIONS

1. **C1 Priority**: Complete OpenTelemetry integration (`Indrajaal.Observability.TelemetrySetup`)
2. **C1 Priority**: Implement HealthCheck endpoint with dependency checks
3. **C2 Foundation**: Add FLAME dependency and configure pools in `application.ex`
4. **C2 Foundation**: Enhance Sentinel with quorum-based intentional leave

---

## APPENDIX C: DOCUMENT METADATA

| Attribute | Value |
|-----------|-------|
| Version | 1.1.0-UNIFIED |
| Created | 2025-12-17 |
| Framework | SOPv5.11 + STAMP + TDG + FPPS + PHICS + FLAME + HA-MESH |
| Source Specs | CLAUDE-text.md v10.1.0-GA, CLAUDE-math.md v9.5.0-MATH-002 |
| Control Flow Levels | 5 (Strategic → Operational → Tactical → Task → Micro-Task) |
| Data Flow Levels | 5 (Strategic → Operational → Tactical → Task → Micro-Task) |
| Evolutionary Systems | OODA Loops, GDE Algorithm, Cybernetic Architect, Autonomic ACS |
| STAMP Constraints | 195 across 21 categories |
| Agents | 50 (1+10+15+24) |
| Containers | 3 (app + db + obs) |
| Formal Verification | Mathematica + Quint + Agda (3-layer) |

---

**Document Status**: VERIFIED COMPLETE
**Compiled By**: Claude Code (Opus 4.5)
**Compliance**: All requirements from CLAUDE-text.md and CLAUDE-math.md addressed
