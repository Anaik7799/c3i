# PRAJNA MIGRATION: DEEP TECHNICAL SPECIFICATION & GAP ANALYSIS
# Iteration 3: Operational Excellence & Data Continuity

**Document ID**: SPEC-20260115-PRAJNA-FSHARP-DEEP
**Parent**: PLAN-20260115-PRAJNA-MIGRATION
**Status**: APPROVED
**Scope**: Level 1 (Code) to Level 4 (Container) + Level 5 (Node) & Level 6 (Mesh) Detail

---

## 1.0 The Observer/Observed Solution: Unified Substrate

**The Core Problem**: In the current Dual-Stack architecture, Elixir "Observes" and F# "Acts". There is a temporal gap ($\Delta t$) and a semantic gap ($\Delta S$) between Observation and Action.
*   $\Delta t$: Serialization overhead (JSON/Zenoh).
*   $\Delta S$: Type mismatch (Elixir dynamic vs F# static).

**The Solution**: By moving Prajna to F#, we collapse the stack.
*   **Zero-Copy Logic**: The "Brain" (Prajna) shares memory space with the "Hand" (CEPAF).
*   **Type Unification**: The Domain Model *is* the API Contract. No DTO translation layer needed internally.

---

## 2.0 Architectural Isomorphism (Elixir $\to$ F# Mapping)

We must preserve the **Resilience** of Erlang/OTP while gaining the **Performance** of .NET.

### 2.1 The Process Model (GenServer $\to$ MailboxProcessor)

Elixir relies on `GenServer` for state isolation. F# uses `MailboxProcessor` (Actors).

| Elixir Concept | F# Implementation Pattern | Critical Difference / Mitigation |
| :--- | :--- | :--- |
| `GenServer.state` | `MailboxProcessor.scan` / Recursive Loop | F# Agents loop over an immutable state parameter. |
| `handle_call` | `AsyncReplyChannel<'T>` | F# requires explicit type definition for messages. **Benefit**: Compile-time protocol enforcement. |
| `handle_cast` | `agent.Post` | Fire-and-forget. |
| `handle_info` | `agent.Post` (Internal types) | F# DUs typically handle both internal and external messages. |
| **"Let it Crash"** | **Supervisor Pattern w/ Restart** | .NET threads don't restart automatically. **Mitigation**: Wrap Agents in a `Supervisor` class that catches Exceptions and restarts the loop. |

**Spec Implementation**:
```fsharp
type AgentMsg = 
    | UpdateMetric of Metric * AsyncReplyChannel<Result<unit, string>> 
    | GetStatus of AsyncReplyChannel<SystemStatus>
    | Crash // For testing

type AgentState = { Metrics: Map<string, Metric>; LastUpdate: DateTime }

// The "GenServer" Equivalent
let agent = MailboxProcessor.Start(fun inbox ->
    let rec loop state = async {
        try
            let! msg = inbox.Receive()
            match msg with 
            | UpdateMetric(m, reply) ->
                let newState = { state with Metrics = state.Metrics.Add(m.Id, m) }
                reply.Reply(Ok())
                return! loop newState
            // ...
        with ex ->
            // OTP-like resilience: Log and Restart (Recurse with clean/last-known state)
            Logger.Error(ex, "Agent crashed, restarting...")
            return! loop state // Or initial state
    }
    loop initialState
)
```

### 2.2 The Persistence Layer (Ecto $\to$ Dapper/DuckDB)

Elixir uses Ecto (Repo). F# will use a hybrid approach matching the "Biomorphic" data needs.

| Data Type | Elixir (Current) | F# (Target) | Rationale |
| :--- | :--- | :--- | :--- |
| **Holon State** | `Indrajaal.Repo` (Postgres) | **Dapper** (Postgres) | High-performance, explicit SQL control. |
| **Analytics** | `DuckDBEx` (NIF) | **DuckDB.NET** (Native) | Native binding is more stable than NIF. |
| **Vectors** | `ExFaiss` / `Nx` | **Microsoft.ML** / **TensorPrimitives** | SIMD-optimized vector math in .NET is superior. |
| **Cache** | `Cachex` (ETS) | `System.Runtime.Caching.MemoryCache` | Standard .NET caching; thread-safe. |

### 2.3 The Supervisor Tree (Supervisor $\to$ IHostedService)

Elixir Supervisors manage process lifecycles. .NET uses `Generic Host` and `BackgroundService`.

*   **Mapping**: `Indrajaal.Application` $\to$ `Cepaf.Program` (Main Host Builder).
*   **Mapping**: `Prajna.Supervisor` $\to$ `PrajnaWorker : BackgroundService`.
*   **Constraint**: .NET's `BackgroundService` is not as granular as OTP Supervisors.
*   **Action**: Implement a custom `ActorSupervisor` class in F# to manage the lifecycle of `MailboxProcessors` independently of the main thread.

---

## 3.0 Critical Risk: The "Let it Crash" Gap (FMEA Refined)

The biggest risk in this migration is losing the robust fault tolerance of the BEAM VM.

**Failure Mode**: An unhandled exception in an F# thread kills the entire process/container.
**Severity**: 10 (System Outage).
**Detection**: Immediate (Health Check).
**RPN**: **High (Requires Mitigation)**.

**Mitigation Strategy (The "Bulletproof Wrapper")**:
1.  **Top-Level Try/Catch**: Every `BackgroundService` must interpret specific exceptions.
2.  **Isolated AppDomains** (Deprecated) -> **Isolated Contexts**: Use distinct `Task` schedulers.
3.  **Container Restart**: Rely on Podman/Kubernetes restart policies (Process = Crash Unit).
    *   *Shift*: In Elixir, a *Process* crashes. In .NET, the *Container* crashes.
    *   *Acceptance*: Given modern container orchestration, "Let the Container Crash" is an acceptable equivalent to "Let the Process Crash" for major faults, provided startup time is < 2s.

---

## 4.0 The "Bicameral Run" Validation Protocol (Verification)

To solve the Observer verification problem, we run both systems simultaneously in **Phase 4**.

**Configuration**:
*   **Elixir**: `PRAJNA_MODE=SHADOW` (Read-only, logs decisions but doesn't execute).
*   **F#**: `PRAJNA_MODE=MASTER` (Read/Write, executes decisions).

**Verification Logic (The Comparator)**:
1.  Both systems subscribe to the same Zenoh telemetry.
2.  Both systems run their OODA loops.
3.  **Comparator Agent** (New Tool): Subscribes to `indrajaal/decision/elixir` and `indrajaal/decision/fsharp`.
4.  **Metric**: $\text{Divergence} = \text{Count}(\text{Diff}(\text{Decision}_E, \text{Decision}_F))$.
5.  **Pass Criteria**: Divergence < 0.1% over 24 hours.

---

## 5.0 Implementation Checklist (Code Level)

### 5.1 Domain Types (`Cepaf.Cockpit.Domain`)
- [ ] Port `Indrajaal.Cockpit.Prajna.Domain.SmartMetric` $\to$ F# Record.
- [ ] Define `Trend` as DU (`Rising | Falling | Stable`).
- [ ] Define `AlarmLevel` as DU (`Normal | Warning | Critical`).

### 5.2 Core Logic (`Cepaf.Cockpit.Core`)
- [ ] Port `TrendCalculator.calculate` (Simple moving average logic).
- [ ] Port `StalenessDetector` (Time difference logic).
- [ ] Port `Guardian.validate_proposal` (STAMP constraint checker).

### 5.3 Interface (`Cepaf.Cockpit.UI`)
- [ ] **TUI**: Enhance `DarkCockpitUI.fs` to render the new types.
- [ ] **Web**: Create Giraffe routes `/api/prajna/status`.
- [ ] **HTMX**: Create template `dashboard.html` with hx-ws support for real-time updates.

---

## 6.0 Operational Excellence & Data Continuity

### 6.1 Garbage Collection (GC) Strategy
Moving from BEAM (per-process GC) to CLR (global GC) changes the latency profile.
*   **Risk**: Gen2 GC pauses > 100ms.
*   **Mitigation**:
    1.  **Structs (ValueTypes)**: Use `struct` records for high-frequency telemetry messages to avoid heap allocation.
    2.  **ArrayPool**: Use `System.Buffers.ArrayPool<T>` for any buffer handling (e.g., Zenoh serialization).
    3.  **Metrics**: Monitor `GC.TimeInGC` via `dotnet-counters`.

### 6.2 Data Schema Evolution
We must not lose existing data in `indrajaal_dev`.
*   **Strategy**: **DbUp** (Evolutionary Database Migration).
*   **Action**: Create a `Cepaf.DbUp` console app that reads the existing Postgres schema.
*   **Constraint**: The F# migration must be **Additive**. Do not drop Ecto tables. Create new views or tables if the F# model diverges significantly.

### 6.3 Real-Time Web Interface (Replacing LiveView)
To match LiveView's "Push" capability without the complexity:
*   **Technology**: **Server-Sent Events (SSE)**.
*   **Rationale**: Simpler than WebSockets, unidirectional (Server -> Client), perfect for dashboard metrics.
*   **Implementation**: Giraffe `stream` handler pushing HTML fragments (HTMX style) or JSON updates.

### 6.4 Serialization Contract (Bicameral Interop)
During the transition, F# must understand Elixir's Zenoh messages.
*   **Elixir Format**: JSON (typically).
*   **F# Requirement**: `System.Text.Json` with `JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower }` to match Elixir's atom-style keys (e.g., `user_id` vs `UserId`).

---

**Sign-off**: This specification provides the necessary technical depth to execute the migration while maintaining safety properties defined in the STAMP analysis.