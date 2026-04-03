# PRAJNA: UNIFIED SUBSTRATE SPECIFICATION
# The "Brain in a Box" Architecture (Thread-Based F# Agents)

**Document ID**: SPEC-20260115-UNIFIED-SUBSTRATE-V2
**Classification**: ARCHITECTURAL STANDARD (SIL-6 Biomorphic)
**Status**: APPROVED FOR EXECUTION
**Parent**: PLAN-20260115-PRAJNA-MIGRATION
**Context**: Migration from Elixir/F# Hybrid (Container-based) to Pure F# (Thread-based).

---

## 1.0 Executive Summary

This specification defines the **Unified Substrate** architecture for the Prajna Cockpit. We are shifting from a distributed microservices model (where latency is measured in milliseconds) to a **Co-located Agent Model** (where latency is measured in nanoseconds).

**The Core Concept**: Prajna becomes a single, highly concurrent F# process acting as a "Biomorphic Brain". Inside this brain, thousands of lightweight Agents (Neurons) communicate via direct memory passing, supervised by a rigid, self-healing hierarchy (The Nervous System).

---

## 2.0 Mathematical Analysis: The Physics of the New Substrate

We formally define why Threads beats Containers for this specific use case (High-Frequency Cognitive Control).

### 2.1 Latency Model ($L$)

Let $L$ be the message passing latency.
*   **Container IPC (Network)**: $L_{net} \approx 500\mu s$ (Optimized Localhost).
*   **Thread IPC (Memory)**: $L_{mem} \approx 50ns$ (Pointer copy).

$$ \text{Speedup Factor} (\eta) = \frac{L_{net}}{L_{mem}} = \frac{500,000}{50} = \mathbf{10,000\times} $$

**Implication**: The OODA loop (Observe-Orient-Decide-Act) can run at **10kHz** internally, allowing for "Continuous Verification" rather than "Sampled Verification".

### 2.2 Density Model ($\rho$)

Let $\rho$ be the density of cognitive units (Agents/Actors) per GB of RAM.
*   **Container Overhead**: ~40MB (Runtime + OS Shim).
*   **Agent Overhead**: ~2KB (Mailbox + State closure).

$$ \rho_{container} \approx \frac{1024}{40} = 25 \text{ Agents/GB} $$
$$ \rho_{thread} \approx \frac{1024}{0.002} = 512,000 \text{ Agents/GB} $$

**Implication**: We can spawn a dedicated "Watchdog Agent" for *every single metric stream* without resource exhaustion.

### 2.3 Recovery Model ($R$)

Let $R$ be the Mean Time To Recovery (MTTR) after a fault.
*   **Container Restart**: $R_{cont} \approx 2000ms$ (Process boot + JIT).
*   **Agent Restart**: $R_{agent} \approx 0.01ms$ (Exception catch + Function recursion).

**Implication**: The system becomes **Antifragile**. Internal faults are corrected faster than the external environment can perceive them.

---

## 3.0 STAMP Safety Constraints (The Physics of the System)

We introduce specific constraints to manage the risks of shared-memory concurrency.

| ID | Constraint | Rationale | Enforcement |
| :--- | :--- | :--- | :--- |
| **SC-THR-001** | **Immutability Mandate** | All inter-agent messages MUST be immutable types (Records, DUs, Maps). No mutable arrays or classes allowed in messages. | FSharpLint + Code Review |
| **SC-THR-002** | **Isolation of Panic** | No Agent may crash the Process. All Agents MUST run within a `Supervisor` wrapper that catches `Exception` and implements a restart policy. | `Agent.fs` Wrapper Class |
| **SC-THR-003** | **Bounded Mailboxes** | Every Agent MUST enforce a `max_queue` size. If exceeded, it MUST either drop (Telemetry) or backpressure (IO). | Metric: `agent_mailbox_depth` |
| **SC-THR-004** | **Deadlock Prevention** | Synchronous `PostAndReply` is FORBIDDEN in cyclic graphs. Use `Post` (Async) for all non-leaf interactions. | Static Analysis |
| **SC-THR-005** | **The 10ms Rule** | No single message handler may block an OS thread for $>10ms$. IO must be `async`. | Profiler / Warning Log |
| **SC-THR-006** | **Poison Pill Protocol** | Every Agent MUST handle a `Shutdown` message to cleanly dispose of resources (FileHandles, Sockets) before stopping. | Interface `IAgent` |

---

## 4.0 Agent Operating Rules (AOR)

| ID | Rule | Description |
| :--- | :--- | :--- |
| **AOR-THR-001** | **Share by Communicating** | Do not access shared static variables. Pass state via messages. |
| **AOR-THR-002** | **Let It Crash (Locally)** | Do not write defensive `try/catch` inside business logic. Let the Supervisor handle the failure. |
| **AOR-THR-003** | **Structured Logging** | Every Agent MUST include its `AgentID` and `CorrelationID` in all log entries. |
| **AOR-THR-004** | **State Externalization** | Critical state MUST be persisted to SQLite/DuckDB immediately upon mutation (Write-Through). Memory is volatile. |

---

## 5.0 Architecture & Implementation Approach

### 5.1 The Cortex Supervisor (Root)

The entry point is a `.NET Generic Host` running `CortexSupervisor`.

```fsharp
type CortexSupervisor(logger: ILogger, metrics: IMetrics) = 
    let agents = new ConcurrentDictionary<string, IAgent>()
    
    member this.Spawn(name, logic) = 
        let agent = new SupervisedAgent(name, logic, logger)
        agents.TryAdd(name, agent)
        agent.Start()
```

### 5.2 The Supervised Agent (Wrapper)

This wrapper implements the **STAMP SC-THR-002** (Isolation of Panic).

```fsharp
type SupervisedAgent<'State, 'Msg>(name, reducer, initialState) = 
    let inbox = MailboxProcessor.Start(fun inbox ->
        let rec loop state = async {
            try
                let! msg = inbox.Receive()
                let! newState = reducer state msg
                return! loop newState
            with ex ->
                Logger.Error(ex, "Agent {Name} crashed. Restarting...", name)
                // Strategy: One-For-One Restart with Initial State
                return! loop initialState 
        }
        loop initialState
    )
```

### 5.3 Component Map

1.  **SmartMetrics**: Ingests Zenoh data, updates in-memory map, calculates vectors.
2.  **Guardian**: Stateless agent. Receives `Proposal`, returns `Verdict`.
3.  **Orchestrator**: Stateful FSM. Coordinates the OODA loop.
4.  **Knowledge**: Interface to Vector DB (DuckDB).

---

## 6.0 The 7-Level Fractal Detail

| Level | Component | Specification Details |
| :--- | :--- | :--- |
| **L1** | **Type** | F# `Record` (Immutable). Example: `type Metric = { Key: string; Value: float }`. |
| **L2** | **Function** | Pure Functions. `let calculateTrend history current = ...`. Unit Testable. |
| **L3** | **Agent** | `MailboxProcessor`. Wraps L2 functions. Holds ephemeral state. |
| **L4** | **Supervisor** | `SupervisedAgent` class. Handles lifecycle, restarts, and error logging. |
| **L5** | **Service** | `IHostedService`. Wires Supervisors to the .NET Host. |
| **L6** | **Process** | `cepaf-core` binary. Configured via `appsettings.json`. |
| **L7** | **Mesh** | Zenoh Session. Exposes the Process to the distributed system. |

---

## 7.0 Comprehensive BDD Scenarios (End-to-End & Graph Verified)

This section defines the behavior of the unified F# system using Gherkin syntax.
Crucially, **every scenario maps to a specific Graph DAG Path and a Formal Proof**.

### 7.1 Scenario: The High-Velocity OODA Loop (Reflex Arc)
**Context**: Normal Operation (Homeostasis).
**Goal**: Verify latency constraints (<30ms) and Graph Acyclicity.
**Graph Path**: `Sensor -> SmartMetrics -> Orchestrator -> Guardian -> Actuator`.
**Formal Proof**: `agda/AcyclicityProofs.agda` (Theorem: `OODA_Is_Acyclic`).

```gherkin
Feature: Biomorphic Reflexes (OODA Loop)
  Background:
    Given the Prajna Cortex is running (L6 Process)
    And the SmartMetrics agent is active (L3 Agent)
    And the Guardian agent is active (L3 Agent)
    And the Graph Verification Framework certifies the "OODA_Path" is acyclic (SC-GVF-003)

  Scenario: Rapid Response to CPU Spike
    When a "CPU_USAGE" telemetry packet with value 95.0 arrives via Zenoh (L7 Mesh)
    And the current time is T0
    Then SmartMetrics accepts the packet (L2 Function: Ingest)
    And SmartMetrics calculates Trend="RisingFast" (L2 Function: CalculateTrend)
    And SmartMetrics emits "AnomalyDetected" to Orchestrator (L3 Message)
    And Orchestrator sends "Proposal:ScaleUp" to Guardian (L3 Message)
    And Guardian validates constraints (SC-FLAME-001) using "Simplex_Kernel" logic
    And Guardian returns "Verdict:Approved" (L1 Type: Verdict)
    And Orchestrator publishes "CMD:ScaleUp" to Zenoh (L7 Mesh)
    And the current time is T1
    And (T1 - T0) is less than 30ms (Performance Constraint)
```

### 7.2 Scenario: The Safety Veto (The "Brain Reflex")
**Context**: Operator Error / Malicious AI.
**Goal**: Verify STAMP enforcement and Deterministic Fallback.
**Graph Path**: `AICopilot -> Orchestrator -> Guardian -> (Block) -> AuditLog`.
**Formal Proof**: `prajna_guardian.qnt` (Invariant: `Safety_Veto_Always_Holds`).

```gherkin
Feature: Guardian Safety Veto
  Scenario: Blocking Unsafe Network Isolation
    Given the system state is "Production" (L5 Node Config)
    And the Quorum count is 2 (Below threshold 3)
    And the Formal Spec "prajna_guardian.qnt" requires Quorum >= 3 for Isolation
    When the AI Copilot proposes "Isolate_Network_Segment" (L3 Message)
    Then the Orchestrator routes proposal to Guardian (L3 Agent)
    And Guardian checks constraint SC-NET-001 (Quorum Required)
    And Guardian returns "Verdict:Vetoed" with reason "Quorum Loss" (L1 Type)
    And Orchestrator logs the Veto to the Immutable Register (L5 Persistence)
    And NO command is sent to the Infrastructure Layer (Safety Property)
```

### 7.3 Scenario: Agent Resurrection (Self-Healing)
**Context**: Code Bug / Memory Fault in a specific Agent.
**Goal**: Verify Fault Tolerance (SC-THR-002) and Supervision Graph.
**Graph Path**: `Supervisor -> (Spawn) -> Agent -> (Crash) -> Supervisor -> (Restart) -> Agent`.
**Formal Proof**: `agda/SupervisionProofs.agda` (Theorem: `Supervisor_Detects_Crash`).

```gherkin
Feature: Self-Healing Agents
  Scenario: Recovery from Unhandled Exception
    Given the "TrafficAnalyzer" agent is processing stream (L3 Agent)
    And the "CortexSupervisor" is monitoring it (L4 Supervisor)
    When a malformed message causes a "DivideByZero" exception
    Then the specific "TrafficAnalyzer" loop terminates
    And the Supervisor catches the exception (SC-THR-002)
    And the Supervisor increments the "CrashCount" metric
    And the Supervisor restarts "TrafficAnalyzer" with a clean state
    And the "TrafficAnalyzer" processes the next valid message successfully
    And the total system downtime is less than 1ms
```

### 7.4 Scenario: Mailbox Backpressure (Stability)
**Context**: DDoS / Data Spike.
**Goal**: Verify Stability (SC-THR-003) and Bounded Queues.
**Graph Path**: `Ingress -> AgentMailbox`.
**Formal Proof**: `quint/IndrajaalCore.qnt` (Invariant: `Mailbox_Never_Overflows`).

```gherkin
Feature: System Stability under Load
  Scenario: Shedding Load during Spike
    Given the "LogIngestor" mailbox limit is 1000 (L3 Agent Config)
    And the current depth is 999
    When 5000 log messages arrive within 10ms
    Then the first 1 message is accepted
    And the remaining 4999 are dropped immediately (Fast Fail)
    And a "MailboxOverflow" alert is emitted to Telemetry
    And the Agent continues processing at max speed without OOM crashing
```

### 7.5 Scenario: AI Hallucination Check (Type Safety)
**Context**: AI generates invalid command.
**Goal**: Verify Type Safety boundaries and Serialization.
**Graph Path**: `OpenRouter -> Serializer -> DomainType`.
**Formal Proof**: F# Compiler (Type System).

```gherkin
Feature: Semantic Boundary Enforcement
  Scenario: AI generates non-existent command
    Given the Command Type is a Discriminated Union (Start | Stop | Reboot) (L1 Type)
    When the AI Copilot outputs "Hyperspace_Jump"
    Then the JSON Deserializer fails to map to the Domain Type
    And the result is "Error: InvalidCommand"
    And the message never enters the logic processing loop (Security Property)
```

---

## 8.0 Graph Verification Integration (SC-GVF)

We explicitly link the runtime architecture to the formal verification models defined in `GEMINI.md` Section 88.0.

### 8.1 The Correspondence Link
*   **F# Code**: `Cepaf.Core.Graph`
*   **Formal Model**: `docs/formal_specs/agda/GraphProperties.agda`

The F# implementation MUST enforce the graph properties proven in Agda.

### 8.2 Runtime Verification
On startup (`sa-up`), the `CortexSupervisor` (L4) performs a **Graph Integrity Check**:
1.  **Acyclicity**: Verifies the Supervision Tree contains no cycles.
2.  **Connectivity**: Verifies all critical Agents are reachable from the Root.
3.  **Isolation**: Verifies "Unsafe" agents (e.g., Python runners) are leaf nodes with no write access to Core State.

**Failure to verify results in an immediate `Panic` shutdown (Fail Secure).**

---

## 9.0 Usage Guidelines

### 9.1 Developer Workflow
1.  **Define Domain**: Update `Domain.fs` with new Types.
2.  **Implement Logic**: Write pure functions in `Logic.fs`.
3.  **Wrap Agent**: Add message types and loop in `Agents.fs`.
4.  **Register**: Add to `Program.fs` DI container.

### 9.2 Debugging
*   **Logs**: Check `data/logs/cepaf-core.log` (Serilog structured logs).
*   **Live Metrics**: Run `sa-monitor` to see Agent Health.
*   **Deadlock**: If an Agent hangs, the Watchdog (running on a separate thread) will log a "Heartbeat Missed" alert after 5s.

---

**Approval**:
*   *System Architect*: ___________________
*   *Safety Officer*: ___________________
*   *Date*: 2026-01-15