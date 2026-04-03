# PRAJNA MIGRATION: 100% VERIFICATION STRATEGY (Static & Runtime)

**Document ID**: VERIFY-20260115-FSHARP-ANALYSIS
**Parent**: SPEC-20260115-UNIFIED-SUBSTRATE
**Status**: ACTIVE
**Scope**: Defining the toolchain and protocols to achieve 100% analysis coverage in the new F# architecture.

---

## 1.0 Executive Mandate: The "Glass Box" Principle

The migration to F# is not just a language port; it is an upgrade in observability. We enforce a **"Glass Box"** policy:
1.  **Static**: The compiler knows everything possible about the code structure.
2.  **Runtime**: The operator knows everything possible about the execution state.

---

## 2.0 100% Static Analysis (Compile-Time Rigor)

In Elixir, we relied on Credo and Dialyzer. In F#, we leverage the stronger type system and .NET ecosystem tools.

### 2.1 The Toolchain

| Category | Elixir Tool (Legacy) | F# Tool (Target) | Configuration / Rule |
| :--- | :--- | :--- | :--- |
| **Compiler** | `elixirc` | **F# Compiler (`fsc`)** | `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`<br>`<WarnOn>1182;3390</WarnOn>` (Unused vars, XML docs) |
| **Linting** | `Credo` | **FSharpLint** | Custom rule set forbidding mutable values outside specific scopes. |
| **Formatting** | `mix format` | **Fantomas** | Enforced in CI. Zero-tolerance for style drift. |
| **Type Checking** | `Dialyzer` | **Native Type System** | **Strict Mode**: No `null` allowed. Use `Option<'T>`. Use `Result<'T,'E>` for errors. |
| **Coverage** | `ExCoveralls` | **AltCover** | Target: **100% Branch Coverage** on Core Logic (Domain, Guardian). |
| **Security** | `Sobelow` | **NuGet Vulnerability Audit** | `dotnet list package --vulnerable` running in CI. |
| **Architecture** | `Xref` | **ArchUnitNET** | Unit tests that enforce layer boundaries (e.g., "Domain cannot reference UI"). |

### 2.2 Formal Constraints (Static)

1.  **No Cyclic Dependencies**: Enforced by F# file ordering.
2.  **Immutability**: All Domain types must be `[<CLIMutable>]` (if serialization needed) or pure Records.
3.  **Exhaustive Matching**: All `match` expressions must handle every case (Compiler Warning FS0025 treated as Error).

---

## 3.0 100% Runtime Analysis (Execution-Time Telemetry)

In Elixir, we used `:telemetry`. In F#, we use `System.Diagnostics` and `OpenTelemetry`.

### 3.1 The "Pulse" Protocol

Every Agent (Thread) MUST emit a standard "Pulse" (Heartbeat + Metrics) every cycle.

**Metric Schema (OpenTelemetry):**
*   `prajna.agent.heartbeat` (Counter)
*   `prajna.agent.mailbox_depth` (Gauge) - **Critical for Thread health**
*   `prajna.agent.processing_time` (Histogram) - **Critical for OODA Loop**
*   `prajna.agent.error_count` (Counter)

### 3.2 The "Black Box" Recorder (Tracing)

We implement **Distributed Tracing** *within* the single process. Every message passed between Agents carries a `TraceContext`.

| Trace Span | Description |
| :--- | :--- |
| `OODA_Cycle` | Top-level span covering Observe -> Act. |
| `Agent_Process` | Time spent inside a specific Agent's loop. |
| `Guardian_Verify` | Time spent validating safety constraints. |
| `Zenoh_Transmit` | Time spent sending command to infrastructure. |

### 3.3 Dynamic Analysis Tools

| Category | F# Implementation |
| :--- | :--- |
| **Profiling** | **dotnet-counters** & **dotnet-trace** sidecars attached to the running container. |
| **Dump Analysis** | **dotnet-dump** triggered automatically on Critical Circuit Breaker trip. |
| **Live View** | **Spectre.Console** TUI (sa-monitor) connecting via Zenoh to the live process. |

---

## 4.0 Verification Matrix (The Definition of Done)

To certify the migration as complete, the following matrix must be green:

| Analysis Layer | Metric | Target | Verification Method |
| :--- | :--- | :--- | :--- |
| **Static / Syntax** | Compiler Warnings | **0** | CI Build Log |
| **Static / Style** | Linter Errors | **0** | `dotnet tool run dotnet-fsharplint` |
| **Static / Logic** | Branch Coverage | **>95%** | AltCover Report |
| **Runtime / Perf** | OODA Latency | **<30ms** | OpenTelemetry Histogram (p99) |
| **Runtime / Stability**| Mailbox Overflow | **0** | Prometheus Alert (`depth > 100`) |
| **Runtime / Safety** | Unhandled Exceptions | **0** | Crash Dump Monitor |

---

## 5.0 Implementation Directives

### AOR-VERIFY-001: The "No Naked Threads" Rule
*   **Rule**: Never use `Task.Run` or `new Thread` directly.
*   **Correction**: Use the `Prajna.Concurrency.AgentSupervisor` wrapper which automatically wires up OpenTelemetry tracing and Try/Catch logging for that thread.

### AOR-VERIFY-002: The "Measurement Before Optimization" Rule
*   **Rule**: Do not optimize F# code until a `dotnet-trace` report proves a bottleneck.
*   **Correction**: Rely on the architectural speed advantage (10,000x) first. Optimize logic second.

### AOR-VERIFY-003: The "Null Option" Rule
*   **Rule**: The keyword `null` is forbidden in Domain Logic.
*   **Correction**: Use `Option.ofObj` at the "Dirty Boundary" (Interop with libraries) and strictly `Option<'T>` internally.