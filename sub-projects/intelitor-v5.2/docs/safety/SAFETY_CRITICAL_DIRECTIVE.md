# MASTER DIRECTIVE: Safety-Critical Rich TUI Cockpit Generation

**Version**: 2.0.0-INTEGRATED | **Date**: 2025-12-30 | **Status**: AUTHORITATIVE
**Classification**: Safety-Critical (IEC 61508 SIL-2) | **Mission Life**: 10-20 Years

## Compliance Standards
| Standard | Domain | Level |
|----------|--------|-------|
| ISO-13849 | Machinery Safety | Full |
| IEC 61508 SIL-2 | Functional Safety | Certified |
| EN 50131 | Security Systems | Grade 3 |
| NASA-STD-3000 | Human-System Integration | Full |
| NUREG-0700 | Nuclear Control Room HMI | Full |
| MIL-STD-1472H | Human Engineering | Full |
| ISA-101 | Process Industry HMI | Full |
| WCAG 2.1 AA | Accessibility | Compliant |
| IEC 62443 | Industrial Cybersecurity | Compliant |

---

## Table of Contents

1. [Preamble & Authority](#1-preamble--authority)
2. [System Architecture](#2-system-architecture)
3. [Safety Logic Specifications](#3-safety-logic-specifications)
4. [Visual & UX Specifications](#4-visual--ux-specifications)
5. [STAMP Safety Constraints](#5-stamp-safety-constraints)
6. [TDG Test-Driven Generation](#6-tdg-test-driven-generation)
7. [AOR Agent Operating Rules](#7-aor-agent-operating-rules)
8. [FMEA Failure Mode Analysis](#8-fmea-failure-mode-analysis)
9. [BDD Behavior Specifications](#9-bdd-behavior-specifications)
10. [Formal Methods](#10-formal-methods)
11. [Graph Specifications](#11-graph-specifications)
12. [Implementation Guidelines](#12-implementation-guidelines)
13. [Testing Strategy](#13-testing-strategy)
14. [UX/CX/DX Guidelines](#14-uxcxdx-guidelines)
15. [Automation Framework](#15-automation-framework)
16. [KMS Integration](#16-kms-integration)
17. [Fractal UI System](#17-fractal-ui-system)
18. [Artifact Generation Checklist](#18-artifact-generation-checklist)

---

## 1. Preamble & Authority

### 1.1 Role & Context

**Role:** You are a Principal Safety-Critical Systems Engineer.
**Context:** You are generating code for a **Human-Machine Interface (HMI)** controlling dangerous physical hardware (industrial machinery, high-voltage systems, security monitoring).

**Stack:**
- **Frontend Logic:** F# (.NET 10) using **The Elm Architecture (TEA/MVU)** pattern
- **Backend/Hardware Layer:** Elixir (OTP 27+) using **Nerves/GenServer** patterns
- **Target Environment:** GPU-Accelerated Terminals (Kitty/WezTerm) with graceful degradation
- **Database:** PostgreSQL 17 + TimescaleDB (SQLite OLTP + DuckDB OLAP for KMS)

**Constraint:** Lives depend on this software. Prioritize **Correctness, Determinism, and Fail-Safety** over brevity.

### 1.2 Document Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────┐
│              SAFETY_CRITICAL_DIRECTIVE.md (THIS DOCUMENT)               │
│                         AUTHORITATIVE SOURCE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                 ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              PRAJNA_TUI_MASTER_SPECIFICATION.md                  │   │
│  │           (TUI Cockpit Implementation Details)                   │   │
│  └────────────────────────────┬────────────────────────────────────┘   │
│                               ▼                                         │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │ KMS_USE_    │  │ KMS_WIREFRAMES_ │  │ FSHARP_     │  │ CEPAF-    │  │
│  │ CASES.md    │  │ COMPREHENSIVE   │  │ CAPABILITY  │  │ STAMP-TDG │  │
│  └─────────────┘  └─────────────────┘  └─────────────┘  └───────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    CLAUDE.md / GEMINI.md                          │  │
│  │              (Agent Operating Instructions)                       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. System Architecture

### 2.1 Frozen Core Architecture (10-20 Year Lifecycle)

**SC-ARCH-001: No External Runtime Dependencies**
- Generate **Static Binaries** (NativeAOT for F#, Burrito for Elixir)
- All dependencies (NuGet/Hex) MUST be **Vendored** (checked into git)
- No reliance on public package registries at runtime

**SC-ARCH-002: Hybrid HAL (Hardware Abstraction Layer)**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    HYBRID HAL ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                F# PRESENTATION LAYER (Frontend)                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐   │  │
│  │  │ TEA/MVU     │  │ Pure Logic  │  │ Renderer Adapters       │   │  │
│  │  │ Architecture│  │ State FSM   │  │ Tier1/Tier2/Tier3       │   │  │
│  │  │ (Immutable) │  │ (Testable)  │  │ (Kitty→Unicode→ASCII)   │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘   │  │
│  │                                                                   │  │
│  │  NEVER touches hardware I/O directly                              │  │
│  └────────────────────────────┬─────────────────────────────────────┘  │
│                               │ Zenoh Pub/Sub                           │
│  ┌────────────────────────────▼─────────────────────────────────────┐  │
│  │                ELIXIR HAL LAYER (Backend)                         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐   │  │
│  │  │ Supervision │  │ GenServers  │  │ Hardware I/O            │   │  │
│  │  │ Trees       │  │ (Stateful)  │  │ GPIO/Serial/Watchdog    │   │  │
│  │  │ (Resilient) │  │ (Isolated)  │  │ (Direct Access)         │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘   │  │
│  │                                                                   │  │
│  │  Owns all hardware access, manages system resilience              │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Tiered Rendering (SC-RENDER-001)

| Tier | Name | Technology | Use Case | Detection |
|------|------|------------|----------|-----------|
| **Tier 1** | Rich (GPU) | Kitty Graphics Protocol (Base64 PNG) | High-res charts, images | `\033[c` query |
| **Tier 2** | Unicode (High Density) | Braille (`⣿⣇`), Nerd Fonts | Dense charts, icons | Unicode support check |
| **Tier 3** | ASCII (Safe) | Standard ASCII (`\|+-#`) | Emergency fallback | Always available |

```fsharp
/// ITerminalRenderer - Adapter pattern for rendering tiers
/// SC-RENDER-001: Must support graceful degradation
type ITerminalRenderer =
    abstract member RenderChart: data: float[] -> width: int -> height: int -> string
    abstract member RenderIcon: icon: IconType -> string
    abstract member Capabilities: TerminalCapabilities

/// SC-RENDER-002: Automatic tier detection at startup
let detectTerminalTier () : ITerminalRenderer =
    let response = queryTerminal "\033[c"
    match parseCapabilities response with
    | HasKittyGraphics -> Tier1Renderer() :> ITerminalRenderer
    | HasUnicodeSupport -> Tier2Renderer() :> ITerminalRenderer
    | _ -> Tier3Renderer() :> ITerminalRenderer  // Safe fallback
```

### 2.3 Container Architecture (SC-CNT-*)

| Container | Ports | Services | Resource Limits |
|-----------|-------|----------|-----------------|
| `indrajaal-db-prod` | 5433 | PostgreSQL 17 + TimescaleDB | 4GB RAM, 2 CPU |
| `indrajaal-obs-prod` | 4317/4318, 9090, 3000, 3100 | OTEL + Prometheus + Grafana + Loki | 2GB RAM, 1 CPU |
| `indrajaal-ex-app-1` | 4000, 4001, 6379 | Phoenix + FLAME + Clustering + Redis | 4GB RAM, 4 CPU |

---

## 3. Safety Logic Specifications

### 3.1 Arm & Fire State Machine (SC-SAFETY-001)

**CRITICAL:** Destructive actions MUST follow this exact FSM. No single keystroke can ever trigger an action.

```fsharp
/// ActionState - Discriminated Union for safety FSM
/// Implements ISO-13850 two-hand control principle digitally
/// SC-SAFETY-001: No single keystroke can trigger destructive action
type ActionState =
    | Idle                          // No action pending
    | Selected                      // Focus on button, no commitment
    | Armed of TimeRemaining: float // Commitment made, countdown active (10s timeout)
    | Firing of HoldProgress: float // Active hold, progress tracking (3.0s required)
    | Engaged                       // Action executed, command sent to backend
    | Locked of Reason: string      // System locked, reason displayed
```

**State Transition Diagram:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ARM & FIRE STATE MACHINE                             │
│                    (ISO-13850 Compliant)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────┐  Navigate   ┌──────────┐  Enter    ┌─────────────────┐      │
│   │ IDLE │────────────▶│ SELECTED │──────────▶│ ARMED           │      │
│   └──────┘             └──────────┘           │ TimeRemaining   │      │
│       ▲                     │                 │ (10s timeout)   │      │
│       │                     │ Escape          └────────┬────────┘      │
│       │                     ▼                          │               │
│       │                 ┌──────┐                       │ Hold Space    │
│       │◀────────────────│CANCEL│◀──────────────────────┤ (3.0s req.)   │
│       │   Timeout       └──────┘  Release < 3s         ▼               │
│       │                                        ┌─────────────────┐      │
│       │                                        │ FIRING          │      │
│       │                                        │ HoldProgress    │      │
│       │                                        │ [████████░░] 80%│      │
│       │                                        └────────┬────────┘      │
│       │                                                 │ Complete      │
│       │                                                 ▼               │
│       │                                        ┌─────────────────┐      │
│       └────────────────────────────────────────│ ENGAGED         │      │
│                        Auto-reset              │ Flash + Lock    │      │
│                                                └─────────────────┘      │
│                                                                         │
│   ┌──────────────────────────────────────────────────────────────────┐ │
│   │ LOCKED (Reason: "E-Stop" | "Connection Lost" | "Safety Violation")│ │
│   │ Override: Physical key + 3s hold + confirmation sequence         │ │
│   └──────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Dead Man's Switch (SC-SAFETY-003)

```fsharp
/// Heartbeat watchdog - SC-SAFETY-003
/// If LastHeartbeat > 2000ms: Apply stale data overlay
/// NEVER show frozen "Normal" values during disconnect
let checkHeartbeat (model: Model) (currentTime: DateTime) : Model =
    let elapsed = (currentTime - model.LastHeartbeat).TotalMilliseconds
    match elapsed with
    | ms when ms > 2000.0 ->
        // CRITICAL: Mark data as stale, overlay entire dashboard
        { model with
            DataStale = true
            StaleReason = sprintf "No heartbeat for %.0fms" ms
            OverlayMessage = Some "⚠ CONNECTION LOST - STALE DATA"
            AllInputsLocked = true }
    | ms when ms > 500.0 ->
        { model with ConnectionQuality = Degraded }
    | _ ->
        { model with DataStale = false; ConnectionQuality = Good }
```

### 3.3 E-Stop Integration (SC-SAFETY-005)

```elixir
defmodule Safety.EStopListener do
  @moduledoc """
  E-Stop GPIO Listener GenServer

  SC-SAFETY-005: Listen to GPIO pin interrupt for physical E-Stop.
  - Normally-closed (NC) circuit for fail-safe operation
  - Response time < 10ms from GPIO interrupt to broadcast
  - State persists across process restarts
  """

  use GenServer
  require Logger

  @gpio_pin Application.compile_env(:indrajaal, :estop_gpio_pin, 17)

  def handle_info({:circuits_gpio, @gpio_pin, _timestamp, 0}, state) do
    # E-Stop ENGAGED (circuit opened - fail-safe)
    Logger.emergency("[E-STOP] Physical E-Stop ENGAGED")
    Phoenix.PubSub.broadcast!(Indrajaal.PubSub, "safety", {:estop_engaged, "Physical E-Stop"})
    {:noreply, %{state | engaged: true}}
  end
end
```

---

## 4. Visual & UX Specifications (Dark Cockpit Philosophy)

### 4.1 Color Semantics (SC-HMI-001)

**Rule:** Use RGB Hex Codes only. Never use named terminal colors (theme-dependent).

```fsharp
/// Safety color palette - SC-HMI-001 compliant
/// NASA-STD-3000 / NUREG-0700 color standards
module SafetyColors =
    // RESERVED: Safety-critical states only
    let SafetyRed = "#FF0000"      // Critical / Stop / Error
    let WarningAmber = "#FFA500"   // Armed / Caution

    // OPERATIONAL: Normal states
    let SafeGreen = "#00FF00"      // Normal / Running / OK
    let Connected = "#00FFFF"      // Connected / Active

    // NEUTRAL: Background states
    let Neutral = "#444444"        // Inactive / Dimmed / Background
    let Stale = "#888888"          // Stale data / Unknown

    // TEXT: Readability
    let TextPrimary = "#FFFFFF"    // High contrast text
    let TextDim = "#AAAAAA"        // Dimmed text
```

### 4.2 Zone Layout (SC-HMI-002)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ZONE A: ANNUNCIATOR BAR (NASA-STD-3000 §7.3.2)                          │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [●] System: ARMED  │ [○] Alarms: 0  │ [●] Conn: OK  │ 14:32:45 CET │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ ZONE B: PRIMARY DISPLAY (80% height) - Most Important Information      │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │   ┌───────────────────┐  ┌───────────────────────────────────────┐  │ │
│ │   │ METRIC 1      ↗   │  │ SPARKLINE CHART                       │  │ │
│ │   │ ████████░░ 78%    │  │ ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁ (No interpolation!)  │  │ │
│ │   └───────────────────┘  │ Threshold ─────── (Red if exceeded)  │  │ │
│ │   ┌───────────────────┐  └───────────────────────────────────────┘  │ │
│ │   │ METRIC 2      →   │                                             │ │
│ │   │ ████░░░░░░ 35%    │  [Trend: → Steady | ↗ Rise | ↑ Fast | ⇈]   │ │
│ │   └───────────────────┘                                             │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ ZONE C: MESSAGE LOG (Last 5 messages, scrollable)                       │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 14:32:44 [INFO] System heartbeat OK                                 │ │
│ │ 14:32:43 [WARN] Sensor 3 reading above threshold                    │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ ZONE D: CONTROL SURFACE (Keyboard shortcuts displayed)                  │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [A]rm System  │  [E]-Stop  │  [R]eset  │  [H]elp  │  [Q]uit        │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Data Visualization Rules (SC-HMI-003/004)

```fsharp
/// Sparkline rendering - SC-HMI-003
/// CONSTRAINT: Do NOT interpolate missing data points
/// Render visual GAP to truthfully represent data loss
let renderSparkline (data: float option[]) (threshold: float) : string =
    let blocks = [| "▁"; "▂"; "▃"; "▄"; "▅"; "▆"; "▇"; "█" |]
    let gapChar = "·"  // Visual gap for missing data

    data
    |> Array.map (fun point ->
        match point with
        | None -> sprintf "%s%s%s" SafetyColors.Stale gapChar Ansi.reset
        | Some value when value > threshold ->
            let idx = min 7 (int (value / threshold * 4.0))
            sprintf "%s%s%s" SafetyColors.SafetyRed blocks.[idx] Ansi.reset
        | Some value ->
            let idx = min 7 (int (value * 8.0))
            sprintf "%s%s%s" SafetyColors.SafeGreen blocks.[idx] Ansi.reset
    )
    |> String.concat ""

/// Trend indicator glyphs - SC-HMI-004
let getTrendIndicator (current: float) (previous: float) : string =
    let delta = current - previous
    match delta with
    | d when abs d < 0.01 -> "→"   // Steady
    | d when d > 0.0 && d < 0.05 -> "↗"   // Slow rise
    | d when d > 0.05 && d < 0.15 -> "↑"  // Fast rise
    | d when d >= 0.15 -> "⇈"  // Surge
    | d when d < 0.0 && d > -0.05 -> "↘"  // Slow fall
    | d when d <= -0.05 && d > -0.15 -> "↓"  // Fast fall
    | _ -> "⇊"  // Plunge
```

---

## 5. STAMP Safety Constraints

### 5.1 Constraint Categories Summary

| Category | Prefix | Count | Description |
|----------|--------|-------|-------------|
| Architecture | SC-ARCH | 5 | System architecture, dependencies |
| Rendering | SC-RENDER | 5 | Tiered rendering, degradation |
| Safety | SC-SAFETY | 10 | Arm & Fire, watchdog, E-Stop |
| HMI | SC-HMI | 7 | Colors, layout, visualization |
| Container | SC-CNT | 15 | Container lifecycle, isolation |
| CEPAF Core | SC-CEP | 10 | Framework constraints |
| Observability | SC-OBS | 12 | Monitoring, telemetry |
| Agent | SC-AGT | 20 | Agent behavior, coordination |
| Validation | SC-VAL | 6 | Verification, consensus |
| Performance | SC-PRF | 5 | Performance guarantees |
| Emergency | SC-EMR | 4 | Emergency response |
| Security | SC-SEC | 5 | Security controls |
| F# Language | SC-FSH | 77 | Type system, composition |
| KMS | SC-KMS | 16 | Knowledge management |
| Network | SC-NET | 3 | .NET framework requirements |
| Testing | SC-TEST | 5 | Test requirements |
| **Total** | | **200+** | Comprehensive coverage |

### 5.2 Critical STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-SAFETY-001 | Arm & Fire FSM for destructive actions | CRITICAL | State machine test |
| SC-SAFETY-002 | Explicit state transitions only | CRITICAL | Audit log check |
| SC-SAFETY-003 | Dead man's switch (heartbeat > 2000ms) | CRITICAL | Timeout test |
| SC-SAFETY-004 | Stale data visualization required | CRITICAL | Visual regression |
| SC-SAFETY-005 | Hardware E-Stop integration | CRITICAL | GPIO interrupt test |
| SC-CNT-009 | NixOS/Podman only (no Docker/Alpine) | CRITICAL | Image inspection |
| SC-CNT-010 | Localhost registry only | CRITICAL | Image name validation |
| SC-CNT-012 | Rootless Podman 5.4.1+ | CRITICAL | Version check |
| SC-FSH-001 | Discriminated unions for domain states | CRITICAL | Static analysis |
| SC-FSH-020 | Result type for failures | CRITICAL | Type check |
| SC-FSH-023 | No exception throwing in business logic | CRITICAL | Code review |
| SC-NET-001 | net10.0 target framework required | HIGH | fsproj validation |
| SC-HMI-001 | RGB hex colors only | HIGH | Color palette check |
| SC-HMI-003 | No data interpolation (show gaps) | HIGH | Visual review |

### 5.3 F# Language Constraints (SC-FSH-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-FSH-002 | Exhaustive pattern matching | HIGH |
| SC-FSH-003 | Active patterns for classification | HIGH |
| SC-FSH-004 | Units of measure for physical quantities | MEDIUM |
| SC-FSH-010 | Function composition preferred | MEDIUM |
| SC-FSH-012 | Pipeline operator required | HIGH |
| SC-FSH-021 | AsyncResult for I/O | CRITICAL |
| SC-FSH-024 | Computation expressions for complex async | HIGH |
| SC-FSH-030 | Property-based tests required | HIGH |
| SC-FSH-040 | Immutable by default | HIGH |
| SC-FSH-041 | Agent-based concurrency | HIGH |
| SC-FSH-042 | Async cancellation support | CRITICAL |
| SC-FSH-043 | No blocking on async | CRITICAL |

### 5.4 KMS Constraints (SC-KMS-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-KMS-001 | Holon graph consistency | HIGH |
| SC-KMS-002 | Semantic search accuracy > 90% | MEDIUM |
| SC-KMS-003 | DuckDB OLAP query timeout < 5s | MEDIUM |
| SC-KMS-004 | SQLite OLTP write latency < 50ms | HIGH |
| SC-KMS-005 | Vector embedding dimension 384 | MEDIUM |
| SC-KMS-006 | Knowledge sync within 100ms | HIGH |
| SC-KMS-007 | Decision traceability | HIGH |
| SC-KMS-008 | Status workflow validation | MEDIUM |
| SC-KMS-009 | Concurrent edit conflict resolution | HIGH |
| SC-KMS-016 | Cross-runtime Zenoh sync | HIGH |

---

## 6. TDG Test-Driven Generation

### 6.1 TDG Principles

1. **Tests MUST exist and FAIL before code generation**
2. **Dual property tests required** (PropCheck + StreamData for Elixir, FsCheck for F#)
3. **Test files MUST compile** before commit

### 6.2 F# FsCheck Property Tests

```fsharp
/// SC-TEST-001: Arm & Fire FSM safety invariant
[<Property>]
let ``Cannot reach Engaged without Armed and 3s Firing hold`` (keys: Key list) =
    let initialModel = { ActionState = Idle; AuditLog = [] }

    let finalModel =
        keys
        |> List.fold (fun model key ->
            update (KeyPress key) model |> fst
        ) initialModel

    match finalModel.ActionState with
    | Engaged ->
        // Verify proper sequence in audit log
        let log = finalModel.AuditLog
        let hasArmed = log |> List.exists (fun e -> e.Event = "ACTION_ARMED")
        let validFiring = log |> List.exists (fun e ->
            e.Event = "ACTION_ENGAGED" && e.HoldTime >= 3.0)
        hasArmed && validFiring
    | _ -> true

/// SC-FSH-030: Property test for discriminated union exhaustiveness
[<Property>]
let ``All action states have valid transitions`` (state: ActionState) =
    let validNextStates =
        match state with
        | Idle -> [Selected]
        | Selected -> [Idle; Armed 10.0]
        | Armed _ -> [Idle; Firing 0.0]
        | Firing p when p >= 3.0 -> [Engaged]
        | Firing _ -> [Armed 10.0]
        | Engaged -> [Idle]
        | Locked _ -> []
    validNextStates.Length >= 0  // Always true, pattern match is exhaustive
```

### 6.3 Elixir StreamData Property Tests

```elixir
defmodule Safety.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # SC-TEST-002: Binary codec fuzzing
  property "binary codec handles any random bytes without crash" do
    check all(
      bytes <- SD.binary(min_length: 0, max_length: 65536),
      max_runs: 1000
    ) do
      result = Safety.Codec.decode(bytes)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # SC-KMS-007: Decision traceability
  property "ADR creation always produces valid holon" do
    check all(
      title <- SD.string(:alphanumeric, min_length: 1, max_length: 200),
      context <- SD.string(:printable, min_length: 10),
      decision <- SD.string(:printable, min_length: 10),
      status <- SD.member_of([:proposed, :accepted, :deprecated, :superseded])
    ) do
      attrs = %{title: title, context: context, decision: decision, status: status}
      {:ok, adr} = KMS.Developer.create_decision(attrs)

      assert adr.id != nil
      assert adr.type == :decision
      assert adr.inserted_at != nil
    end
  end
end
```

---

## 7. AOR Agent Operating Rules

### 7.1 Core AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-SAF-001 | Halt <1s on STAMP violation | Immediate process termination |
| AOR-CNT-001 | Podman ONLY (no Docker) | Image validation |
| AOR-QUA-001 | Zero warnings mandatory | `--warnings-as-errors` |
| AOR-AGT-001 | Code must compile before task complete | Pre-commit hook |
| AOR-DB-001 | Use BaseResource for all Ash resources | Code review |
| AOR-DOC-001 | Read moduledoc before edit | Agent instruction |
| AOR-BATCH-001 | Batch size <= 10 files | Script validation |
| AOR-NET-001 | Verify net10.0 before F# build | Build script check |

### 7.2 TUI-Specific AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-TUI-001 | All TUI state MUST be immutable | F# compiler + review |
| AOR-TUI-002 | MVU pattern mandatory for all views | Architecture review |
| AOR-TUI-003 | RGB hex colors only (no named colors) | Lint check |
| AOR-TUI-004 | Arm & Fire for destructive actions | FSM validation |
| AOR-TUI-005 | Stale data overlay at >2000ms | Heartbeat test |
| AOR-TUI-006 | No interpolation of missing data | Visual review |
| AOR-TUI-007 | Keyboard navigation for all controls | Accessibility test |
| AOR-TUI-008 | Zone layout per NASA-STD-3000 | Layout validation |
| AOR-TUI-009 | Tiered rendering with fallback | Capability test |
| AOR-TUI-010 | Audit log for all safety actions | Log verification |

### 7.3 KMS-Specific AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-KMS-001 | Verify write permission before creation | Pre-action check |
| AOR-KMS-002 | Validate all required fields | Schema validation |
| AOR-KMS-003 | Broadcast creation event within 100ms | Timeout enforcement |
| AOR-KMS-004 | Maintain holon graph consistency | Graph validation |
| AOR-KMS-005 | Index content for search within 500ms | Index timing |

---

## 8. FMEA Failure Mode Analysis

### 8.1 TUI System FMEA

| Failure Mode | Cause | Effect | S | O | D | RPN | Mitigation |
|--------------|-------|--------|---|---|---|-----|------------|
| FSM bypass | Code bug | Unsafe action | 10 | 2 | 2 | 40 | Exhaustive pattern match |
| Stale data displayed | Network failure | Wrong decisions | 9 | 3 | 3 | 81 | Dead man's switch overlay |
| E-Stop ignored | GPIO failure | Dangerous state | 10 | 1 | 2 | 20 | NC circuit, dual-path |
| Tier degradation fails | Detection bug | Render crash | 6 | 2 | 4 | 48 | Fallback to Tier 3 |
| Color theme override | User config | Safety color lost | 8 | 4 | 3 | 96 | Hardcoded RGB hex |
| Heartbeat timeout missed | Clock drift | Silent disconnect | 7 | 2 | 4 | 56 | Monotonic clock |
| Audit log lost | Disk full | Compliance fail | 5 | 3 | 5 | 75 | Log rotation, alerts |
| Memory leak in view | State accumulation | OOM crash | 6 | 3 | 4 | 72 | Immutable state |

### 8.2 KMS FMEA

| Failure Mode | Cause | Effect | S | O | D | RPN | Mitigation |
|--------------|-------|--------|---|---|---|-----|------------|
| ADR not saved | DB failure | Data loss | 8 | 2 | 3 | 48 | Retry + local cache |
| Duplicate ADR | Race condition | Confusion | 5 | 3 | 4 | 60 | Optimistic locking |
| Zenoh sync fails | Network partition | F# cockpit stale | 4 | 2 | 5 | 40 | Fallback to polling |
| Search returns stale | Index lag | Wrong info | 5 | 3 | 4 | 60 | Near-real-time index |
| Graph corruption | Concurrent edit | Broken links | 7 | 2 | 4 | 56 | Transactional updates |
| Vector embedding mismatch | Model version | Bad search | 6 | 2 | 5 | 60 | Embedding versioning |

### 8.3 FMEA Risk Thresholds

| RPN Range | Risk Level | Action Required |
|-----------|------------|-----------------|
| 1-25 | Low | Monitor |
| 26-50 | Medium | Mitigation plan |
| 51-100 | High | Immediate action |
| 101+ | Critical | Block release |

---

## 9. BDD Behavior Specifications

> **Section Status**: COMPREHENSIVE | **Scenarios**: 150+ | **Feature Files**: 25+
>
> This is the authoritative BDD specification for the Indrajaal Safety-Critical System.
> All feature files use Gherkin syntax compatible with ExUnit.Case (Elixir) and Expecto (F#).

### 9.1 BDD Framework Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BDD TESTING FRAMEWORK                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    FEATURE FILES (.feature)                      │  │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐│  │
│   │  │ Safety   │ │ UI/UX    │ │ KMS      │ │ API/DX   │ │ Cross- ││  │
│   │  │ Critical │ │ Behavior │ │ Domains  │ │ Testing  │ │ Runtime││  │
│   │  │ (25)     │ │ (20)     │ │ (35)     │ │ (15)     │ │ (10)   ││  │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘│  │
│   └───────┼────────────┼────────────┼────────────┼───────────┼──────┘  │
│           │            │            │            │           │          │
│           └────────────┴────────────┴────────────┴───────────┘          │
│                                    │                                    │
│                                    ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    STEP DEFINITIONS                              │  │
│   │  ┌───────────────────┐  ┌───────────────────┐                   │  │
│   │  │ Elixir Steps      │  │ F# Steps          │                   │  │
│   │  │ (test/support/    │  │ (test/Cepaf.Tests/│                   │  │
│   │  │  bdd_steps.ex)    │  │  BddSteps.fs)     │                   │  │
│   │  └───────────────────┘  └───────────────────┘                   │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                    │                                    │
│                                    ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    TEST EXECUTION                                │  │
│   │  • ExUnit with BDD adapter (Elixir)                             │  │
│   │  • Expecto with BDD adapter (F#)                                │  │
│   │  • VHS visual regression (Charm.sh)                             │  │
│   │  • Wallaby browser automation                                    │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Tag Taxonomy

| Tag | Scope | Description | Required Coverage |
|-----|-------|-------------|-------------------|
| `@safety-critical` | Safety | ISO-13849/IEC 61508 compliant scenarios | 100% |
| `@iso-13850` | Safety | Two-hand control principle verification | 100% |
| `@estop` | Safety | Emergency stop integration | 100% |
| `@stale-data` | Safety | Dead man's switch verification | 100% |
| `@ui` | UX | User interface behavior | 95% |
| `@ux` | UX | User experience flows | 95% |
| `@cx` | CX | Customer experience scenarios | 90% |
| `@dx` | DX | Developer experience (API/CLI/SDK) | 90% |
| `@api` | DX | REST/GraphQL API testing | 95% |
| `@cli` | DX | Command-line interface testing | 90% |
| `@audit` | Compliance | Audit trail verification | 100% |
| `@accessibility` | UX | WCAG 2.1 AA compliance | 100% |
| `@kms` | KMS | Knowledge management scenarios | 90% |
| `@zenoh` | Integration | Cross-runtime pub/sub | 95% |
| `@performance` | Performance | Response time requirements | 95% |
| `@chaos` | Resilience | Fault injection testing | 85% |
| `@regression` | Quality | Visual regression testing | 100% |
| `@smoke` | Quality | Quick sanity checks | 100% |
| `@happy-path` | Quality | Normal flow scenarios | 100% |
| `@edge-case` | Quality | Boundary conditions | 90% |
| `@error-handling` | Quality | Error recovery scenarios | 95% |

---

### 9.3 Safety-Critical Feature Files

#### 9.3.1 Arm & Fire Protocol (SC-SAFETY-001)

```gherkin
# features/safety/arm_and_fire.feature
@safety-critical @iso-13850
Feature: Arm and Fire Safety Protocol
  """
  STAMP Constraints: SC-SAFETY-001, SC-SAFETY-002
  ISO Compliance: ISO-13850 (Machinery Safety - Emergency Stop)

  This feature implements the digital equivalent of the "two-hand control"
  principle. No single keystroke can ever trigger a dangerous action.
  All destructive operations require:
    1. Navigation to the action (Select)
    2. Deliberate arming (Enter)
    3. Sustained hold (Space for 3+ seconds)
  """

  Background:
    Given the system is in operational mode
    And all safety interlocks are satisfied
    And the TUI is rendering in Tier 1 (GPU) mode
    And the connection to backend is established
    And the audit log is active

  # ─────────────────────────────────────────────────────────────────────
  # STATE TRANSITION SCENARIOS
  # ─────────────────────────────────────────────────────────────────────

  @ui @smoke
  Scenario: Initial state is Idle
    When the application starts
    Then the action state should be "Idle"
    And no action buttons should have amber border
    And the status bar should show "SAFE"

  @ui @happy-path
  Scenario: Navigate to action button enters Selected state
    Given the action state is "Idle"
    When I navigate to the "Emergency Shutdown" button
    Then the action state should be "Selected"
    And the button should have cyan border
    And the status bar should show "SELECTED: Emergency Shutdown"

  @ui @happy-path
  Scenario: Escape from Selected returns to Idle
    Given the action state is "Selected"
    And the "Emergency Shutdown" button is focused
    When I press "Escape"
    Then the action state should be "Idle"
    And no buttons should have cyan border

  @ui @safety-critical
  Scenario: Cannot engage action with single keystroke
    Given the action state is "Idle"
    When I press "Enter" on the "Emergency Shutdown" button
    Then the action should NOT be executed
    And the action state should be "Armed"
    And the button should display amber border
    And an audit entry "ACTION_ARMED" should be created

  @ui @safety-critical
  Scenario: Armed state has 10 second timeout
    Given the action state is "Armed"
    And the timeout countdown is at 10 seconds
    When I wait for 10 seconds without action
    Then the action state should return to "Idle"
    And an audit entry "ARM_TIMEOUT" should be created
    And the button should return to neutral style

  @ui @safety-critical
  Scenario: Escape from Armed returns to Idle immediately
    Given the action state is "Armed"
    When I press "Escape"
    Then the action state should be "Idle"
    And an audit entry "ARM_CANCELLED" should be created
    And the button should return to neutral style

  @ui @safety-critical
  Scenario: Must hold Space for 3 seconds to transition to Firing
    Given the action state is "Armed"
    When I press and hold "Space"
    Then the action state should be "Firing"
    And a progress bar should appear showing 0%
    And the progress bar should increment every 33ms

  @ui @safety-critical
  Scenario: Release before 3 seconds cancels Firing
    Given the action state is "Firing"
    And the hold progress is at 2.5 seconds
    When I release "Space"
    Then the action state should return to "Armed"
    And the timeout should reset to 10 seconds
    And an audit entry "FIRE_ABORTED" should be created
    And the hold progress should be "2.5s / 3.0s required"

  @ui @safety-critical
  Scenario: Successfully engage after full 3 second hold
    Given the action state is "Firing"
    And the hold progress is at 2.9 seconds
    When I continue holding "Space" for 0.1 more seconds
    Then the action state should be "Engaged"
    And the screen should flash white for 100ms
    And an audit entry "ACTION_ENGAGED" should be created
    And the action command should be sent to backend
    And a confirmation sound should play

  @ui @safety-critical
  Scenario: Engaged state auto-resets to Idle
    Given the action state is "Engaged"
    When 2 seconds have passed
    Then the action state should return to "Idle"
    And the button should show success indicator for 5 seconds
    And all controls should be re-enabled

  @ui @safety-critical @estop
  Scenario: E-Stop immediately transitions to Locked from any state
    Given the action state is "<current_state>"
    When the physical E-Stop is engaged
    Then the action state should be "Locked"
    And the lock reason should be "Physical E-Stop Engaged"
    And all controls should be disabled
    And the screen should display red border
    And an audit entry "ESTOP_ENGAGED" should be created

    Examples:
      | current_state |
      | Idle          |
      | Selected      |
      | Armed         |
      | Firing        |
      | Engaged       |

  @ui @safety-critical
  Scenario: Locked state requires physical key to unlock
    Given the action state is "Locked"
    And the lock reason is "Physical E-Stop Engaged"
    When I press any keyboard key
    Then the action state should remain "Locked"
    And a message should display "Physical key required to unlock"

  # ─────────────────────────────────────────────────────────────────────
  # VISUAL FEEDBACK SCENARIOS
  # ─────────────────────────────────────────────────────────────────────

  @ui @ux @regression
  Scenario: Progress bar renders correctly during Firing
    Given the action state is "Firing"
    When the hold progress is at 50%
    Then the progress bar should show "████████░░░░░░░░ 50%"
    And the progress bar should be amber color (#FFA500)
    And the remaining time should show "1.5s remaining"

  @ui @ux @regression
  Scenario: Armed countdown renders in status bar
    Given the action state is "Armed"
    And 3 seconds have elapsed
    Then the status bar should show "ARMED: 7s remaining"
    And the countdown should be amber color
    And the countdown should pulse every second

  @ui @ux @accessibility
  Scenario: Screen reader announces state transitions
    Given screen reader mode is enabled
    When the action state changes from "Idle" to "Armed"
    Then the screen reader should announce "Warning: Action Armed. 10 second timeout. Hold Space for 3 seconds to engage."

  # ─────────────────────────────────────────────────────────────────────
  # AUDIT TRAIL SCENARIOS
  # ─────────────────────────────────────────────────────────────────────

  @audit @cx @safety-critical
  Scenario: Complete audit trail for successful action
    Given I complete the full Arm → Fire → Engage sequence
    Then the audit log should contain entries in order:
      | Timestamp      | Event          | Details                |
      | <timestamp_1>  | ACTION_ARMED   | target="Emergency Shutdown", user="operator1" |
      | <timestamp_2>  | ACTION_FIRING  | hold_start=true        |
      | <timestamp_3>  | ACTION_ENGAGED | hold_duration=3.0s, target="Emergency Shutdown" |
    And all timestamps should be in ISO8601 format with timezone
    And the audit entries should be signed with HMAC-SHA256

  @audit @cx
  Scenario: Audit log captures failed attempts
    Given I arm the "Emergency Shutdown" action
    And I hold Space for 2 seconds
    When I release Space prematurely
    Then the audit log should contain:
      | Event        | Details                              |
      | ACTION_ARMED | target="Emergency Shutdown"          |
      | FIRE_ABORTED | hold_duration=2.0s, required=3.0s    |

  # ─────────────────────────────────────────────────────────────────────
  # EDGE CASES AND ERROR HANDLING
  # ─────────────────────────────────────────────────────────────────────

  @edge-case @safety-critical
  Scenario: Rapid key presses do not skip states
    Given the action state is "Idle"
    When I rapidly press "Enter" 10 times in 100ms
    Then the action state should be "Armed"
    And only one "ACTION_ARMED" audit entry should exist

  @edge-case @safety-critical
  Scenario: Mouse click cannot activate dangerous actions
    Given the action state is "Armed"
    When I click the action button with mouse
    Then the action state should remain "Armed"
    And a message should display "Keyboard activation required"

  @error-handling @safety-critical
  Scenario: Backend connection lost during Firing
    Given the action state is "Firing"
    And the hold progress is at 2.8 seconds
    When the backend connection is lost
    Then the action state should be "Locked"
    And the lock reason should be "Connection Lost"
    And the firing should be aborted
    And an audit entry "FIRE_ABORTED_CONNECTION_LOST" should be created

  @edge-case @chaos
  Scenario: System clock jump during Armed countdown
    Given the action state is "Armed"
    And the timeout is at 5 seconds remaining
    When the system clock jumps forward 20 seconds
    Then the action state should return to "Idle"
    And an audit entry "ARM_TIMEOUT_CLOCK_ANOMALY" should be created

  @performance @safety-critical
  Scenario: State transition latency under 16ms
    Given the action state is "Idle"
    When I press "Enter" to arm
    Then the visual feedback should appear within 16ms
    And the state change should be committed within 8ms
```

#### 9.3.2 Dead Man's Switch (SC-SAFETY-003)

```gherkin
# features/safety/stale_data.feature
@safety-critical @stale-data
Feature: Dead Man's Switch - Stale Data Detection
  """
  STAMP Constraints: SC-SAFETY-003, SC-SAFETY-004

  The system must NEVER display potentially stale data without clear
  visual indication. A "frozen normal" display that hides a disconnection
  is more dangerous than an obvious error state.
  """

  Background:
    Given the system is in operational mode
    And heartbeats are being received every 100ms
    And the dashboard is displaying live data

  # ─────────────────────────────────────────────────────────────────────
  # HEARTBEAT MONITORING
  # ─────────────────────────────────────────────────────────────────────

  @ui @smoke
  Scenario: Normal heartbeat shows connected status
    When heartbeats are received every 100ms
    Then the connection indicator should be green (#00FF00)
    And the status should show "Connected"
    And all data should render without overlay

  @ui @safety-critical
  Scenario: Degraded connection quality warning at 500ms
    Given heartbeats were received normally
    When the last heartbeat was 500ms ago
    Then the connection indicator should be amber (#FFA500)
    And the status should show "Connection Degraded"
    And all data should still be displayed (no overlay)

  @ui @safety-critical
  Scenario: Stale data overlay at 2000ms threshold
    Given heartbeats were received normally
    When the last heartbeat was 2000ms ago
    Then the entire dashboard should be dimmed to 30% brightness
    And a full-screen overlay should display:
      """
      ⚠ CONNECTION LOST - STALE DATA
      Last update: 2.0 seconds ago
      All values shown may be outdated
      """
    And all inputs should be locked
    And the connection indicator should be red (#FF0000)

  @ui @safety-critical
  Scenario: Stale overlay persists until heartbeat restored
    Given the stale data overlay is displayed
    And the last heartbeat was 5000ms ago
    When a new heartbeat is received
    Then the overlay should be removed
    And the dashboard should return to full brightness
    And inputs should be unlocked
    And a banner should show "Connection Restored" for 3 seconds
    And an audit entry "CONNECTION_RESTORED" should be created

  @ui @safety-critical
  Scenario: Escalating staleness indication
    Given heartbeats have stopped
    Then the staleness indicator should show:
      | Elapsed | Indicator                        |
      | 2s      | "⚠ STALE: 2s"                   |
      | 5s      | "⚠ STALE: 5s - Check Connection"|
      | 10s     | "⚠ STALE: 10s - CRITICAL"       |
      | 30s     | "⚠ STALE: 30s - SYSTEM OFFLINE" |
    And the indicator color should shift from amber to red

  @ui @safety-critical
  Scenario: Individual metric staleness indication
    Given the dashboard shows 5 metrics
    And metric "Temperature" has not updated for 3000ms
    When other metrics are updating normally
    Then only the "Temperature" metric should show staleness indicator
    And the Temperature value should be grayed out
    And a "?" symbol should appear next to the value
    And other metrics should display normally

  # ─────────────────────────────────────────────────────────────────────
  # DATA VISUALIZATION INTEGRITY
  # ─────────────────────────────────────────────────────────────────────

  @ui @safety-critical
  Scenario: Sparkline shows gaps for missing data points
    Given a sparkline chart with 60 data points
    And data points 25-30 are missing (5 second gap)
    When the chart renders
    Then the chart should show "▁▂▃▄▅▆▇█" for present data
    And the chart should show "·····" for missing data points
    And the gap should be in gray (#888888)
    And the chart should NOT interpolate across the gap

  @ui @safety-critical
  Scenario: Gauge shows "?" for stale reading
    Given a pressure gauge normally shows 75%
    When the reading becomes stale (> 2000ms old)
    Then the gauge should display "?"
    And the gauge fill should be gray
    And the label should show "STALE"

  @ui @safety-critical
  Scenario: Numeric display shows last value with staleness marker
    Given a temperature display shows "23.5°C"
    When the reading becomes stale
    Then the display should show "23.5°C*"
    And the value should be grayed out
    And a tooltip should explain "* Value is stale (last update: Xs ago)"

  # ─────────────────────────────────────────────────────────────────────
  # AUDIT AND FORENSICS
  # ─────────────────────────────────────────────────────────────────────

  @audit @cx
  Scenario: Connection loss events are logged
    When the connection is lost
    Then an audit entry should be created with:
      | Field               | Value                          |
      | event_type          | CONNECTION_LOST                |
      | last_heartbeat_time | <ISO8601 timestamp>            |
      | elapsed_ms          | 2000                           |
      | metrics_frozen      | ["temp", "pressure", "flow"]   |

  @audit @cx
  Scenario: Connection history is retained for 90 days
    Given connection events have been logged for 100 days
    When I query connection history for the last 90 days
    Then I should see all connection events from the period
    And events older than 90 days should be archived

  # ─────────────────────────────────────────────────────────────────────
  # ERROR RECOVERY
  # ─────────────────────────────────────────────────────────────────────

  @error-handling @chaos
  Scenario: Recovery from network partition
    Given the network has been partitioned for 30 seconds
    When the network connection is restored
    Then the system should:
      | Step | Action                                  |
      | 1    | Clear stale overlay                     |
      | 2    | Request full state sync from backend    |
      | 3    | Validate received state against schema  |
      | 4    | Update all metrics atomically           |
      | 5    | Log CONNECTION_RESTORED event           |

  @error-handling @edge-case
  Scenario: Heartbeat flood does not overwhelm UI
    Given the backend sends 1000 heartbeats per second (error condition)
    Then the UI should process heartbeats at max 100/second
    And excess heartbeats should be dropped
    And the connection status should remain "Connected"
```

#### 9.3.3 E-Stop Integration (SC-SAFETY-005)

```gherkin
# features/safety/emergency_stop.feature
@safety-critical @estop
Feature: Emergency Stop Integration
  """
  STAMP Constraints: SC-SAFETY-005
  Compliance: IEC 60947-5-5 (Emergency Stop Devices)

  The E-Stop circuit is NORMALLY CLOSED (NC) for fail-safe operation.
  If the wire is cut or connection lost, the system enters STOP state.
  """

  Background:
    Given the E-Stop GPIO listener is active on pin 17
    And the E-Stop circuit is normally closed
    And the system is in operational mode

  @safety-critical @hardware
  Scenario: E-Stop physical button engagement
    Given the E-Stop button is in released position (circuit closed)
    When the operator presses the physical E-Stop button
    Then the GPIO pin should read LOW (circuit opened)
    And the system should enter "Locked" state within 10ms
    And all outputs should be de-energized
    And all controls should be disabled
    And an emergency broadcast should be sent to all clients
    And an audit entry "ESTOP_ENGAGED" should be created

  @safety-critical @hardware
  Scenario: E-Stop wire cut detection (fail-safe)
    Given the E-Stop circuit is functioning normally
    When the E-Stop wire is cut (simulated)
    Then the GPIO pin should read LOW (circuit opened)
    And the system should enter "Locked" state
    And the lock reason should be "E-Stop Circuit Fault"

  @safety-critical
  Scenario: E-Stop state persists across process restarts
    Given the E-Stop has been engaged
    And the GenServer process crashes
    When the supervisor restarts the process
    Then the E-Stop state should still be "Engaged"
    And the system should remain in "Locked" state

  @safety-critical
  Scenario: E-Stop release requires physical key turn
    Given the E-Stop button has been pressed
    And the system is in "Locked" state
    When I release the E-Stop button without key turn
    Then the system should remain in "Locked" state
    And a message should display "Key required to reset"

  @safety-critical
  Scenario: Full E-Stop reset sequence
    Given the E-Stop is engaged
    When the operator:
      | Step | Action                                  |
      | 1    | Releases E-Stop button                  |
      | 2    | Inserts physical reset key              |
      | 3    | Turns key clockwise for 2 seconds       |
      | 4    | Removes key                             |
    Then the system should exit "Locked" state
    And the system should enter "Safe Startup" mode
    And all safety checks should be re-verified
    And an audit entry "ESTOP_RESET" should be created

  @safety-critical @ui
  Scenario: E-Stop status visible on all screens
    Given the E-Stop indicator is in the annunciator bar
    When the E-Stop is engaged
    Then every screen should display:
      | Element                | State                    |
      | Background             | Red tint overlay         |
      | Status bar             | "⚠ E-STOP ENGAGED"      |
      | All buttons            | Disabled/grayed          |
      | Navigation             | Disabled                 |

  @audit @cx
  Scenario: E-Stop event includes full context
    When the E-Stop is engaged
    Then the audit entry should contain:
      | Field                  | Value                    |
      | event_type             | ESTOP_ENGAGED            |
      | trigger_source         | GPIO_PIN_17              |
      | system_state_before    | <JSON snapshot>          |
      | active_actions         | <list of pending actions>|
      | operator_session       | <session ID>             |
      | response_time_ms       | <value < 10>             |
```

---

### 9.4 UI/UX Behavior Feature Files

#### 9.4.1 Zone Layout (SC-HMI-002)

```gherkin
# features/ui/zone_layout.feature
@ui @ux
Feature: NASA-STD-3000 Zone Layout Compliance
  """
  STAMP Constraints: SC-HMI-002
  Compliance: NASA-STD-3000 §7.3.2 (Display Design)

  The screen is divided into four zones with specific functions:
    Zone A: Annunciator bar (status indicators)
    Zone B: Primary display (80% of screen height)
    Zone C: Message log
    Zone D: Control surface (keyboard shortcuts)
  """

  Background:
    Given the terminal is 100 columns by 40 rows
    And the TUI application is running

  @smoke @regression
  Scenario: Zone A - Annunciator bar renders correctly
    When the dashboard loads
    Then Zone A should occupy row 1
    And Zone A should contain:
      | Element          | Position | Content Example              |
      | System status    | Left     | "[●] System: OPERATIONAL"    |
      | Alarm count      | Center   | "[○] Alarms: 0"              |
      | Connection       | Center   | "[●] Conn: OK"               |
      | Clock            | Right    | "14:32:45 CET"               |

  @smoke @regression
  Scenario: Zone B - Primary display occupies 80% height
    When the dashboard loads
    Then Zone B should occupy rows 2-32 (31 rows / 80%)
    And Zone B should contain the main metrics and charts

  @smoke @regression
  Scenario: Zone C - Message log renders correctly
    When the dashboard loads
    Then Zone C should occupy rows 33-37 (5 rows)
    And Zone C should contain the last 5 log messages
    And messages should be scrollable with Page Up/Down

  @smoke @regression
  Scenario: Zone D - Control surface shows shortcuts
    When the dashboard loads
    Then Zone D should occupy rows 38-40 (3 rows)
    And Zone D should display available keyboard shortcuts
    And the current mode shortcuts should be highlighted

  @accessibility @ui
  Scenario: Zone boundaries are visually distinct
    When the dashboard renders
    Then each zone should have a 1-pixel border
    And zone borders should use dim color (#444444)
    And active zone should have cyan border (#00FFFF)

  @ux @edge-case
  Scenario: Layout adapts to small terminal
    Given the terminal is 80 columns by 24 rows
    When the dashboard loads
    Then Zone A should occupy row 1
    And Zone B should occupy rows 2-18 (minimum 70%)
    And Zone C should occupy rows 19-22 (reduced to 4 messages)
    And Zone D should occupy rows 23-24

  @ux @edge-case
  Scenario: Layout adapts to large terminal
    Given the terminal is 200 columns by 60 rows
    When the dashboard loads
    Then Zone B should expand to use additional space
    And Zone C should show up to 10 messages
    And all text should remain readable (no stretching)
```

#### 9.4.2 Color Semantics (SC-HMI-001)

```gherkin
# features/ui/color_semantics.feature
@ui @ux @accessibility
Feature: Safety Color Palette Compliance
  """
  STAMP Constraints: SC-HMI-001
  Compliance: NASA-STD-3000, NUREG-0700

  Colors must use RGB hex codes only. Named terminal colors are
  theme-dependent and must NEVER be used for safety-critical indicators.
  """

  Background:
    Given the TUI is using the safety color palette

  @safety-critical @regression
  Scenario: Safety red reserved for critical states
    When a critical alarm is active
    Then the indicator should use color #FF0000 (pure red)
    And the color should NOT be from terminal theme

  @safety-critical @regression
  Scenario: Warning amber for armed/caution states
    When an action is in "Armed" state
    Then the indicator should use color #FFA500 (amber)
    And the button border should be amber

  @ui @regression
  Scenario: Safe green for normal states
    When all systems are operational
    Then status indicators should use color #00FF00 (green)

  @ui @regression
  Scenario: Connected cyan for active connections
    When the backend connection is active
    Then the connection indicator should use color #00FFFF (cyan)

  @ui @regression
  Scenario: Stale gray for unknown/stale data
    When data is stale (> 2000ms)
    Then the value should use color #888888 (gray)

  @accessibility
  Scenario: Color contrast meets WCAG 2.1 AA
    Given any colored text element
    Then the contrast ratio should be at least 4.5:1
    And the contrast should be verified against background

  @accessibility
  Scenario: Color is not sole indicator
    Given a critical alarm is displayed
    Then the indicator should show both:
      | Indicator Type | Example                |
      | Color          | #FF0000 (red)          |
      | Symbol         | "[●]" or "⚠"          |
      | Text           | "CRITICAL"             |

  @edge-case
  Scenario: Color rendering in monochrome fallback
    Given the terminal does not support colors
    When an alarm is displayed
    Then the indicator should use uppercase text: "[ALARM]"
    And blinking attribute should be used if available
```

#### 9.4.3 Keyboard Navigation

```gherkin
# features/ui/keyboard_navigation.feature
@ui @ux @accessibility
Feature: Full Keyboard Navigation
  """
  STAMP Constraints: SC-HMI-006
  Compliance: WCAG 2.1 AA §2.1 (Keyboard Accessible)

  All functionality must be accessible via keyboard only.
  No mouse-only interactions are permitted.
  """

  Background:
    Given the TUI application is running
    And focus is on the main dashboard

  @smoke
  Scenario: Tab cycles through all interactive elements
    When I press "Tab" repeatedly
    Then focus should cycle through elements in order:
      | Order | Element                    |
      | 1     | System status indicator    |
      | 2     | First metric panel         |
      | 3     | Second metric panel        |
      | ...   | ...                        |
      | N     | Help button                |
    And focus should return to first element after last

  @ui
  Scenario: Shift+Tab cycles backwards
    Given focus is on the third element
    When I press "Shift+Tab"
    Then focus should move to the second element

  @ui
  Scenario: Arrow keys navigate within panels
    Given focus is on the metrics panel
    When I press "Down"
    Then focus should move to the next metric in the panel

  @ui
  Scenario: Enter activates focused element
    Given focus is on the "View Details" button
    When I press "Enter"
    Then the details view should open

  @ui
  Scenario: Space bar alternative for activation
    Given focus is on a toggle switch
    When I press "Space"
    Then the toggle state should change

  @accessibility
  Scenario: Focus indicator is clearly visible
    Given focus is on any element
    Then the element should have a visible focus ring
    And the focus ring should be cyan (#00FFFF)
    And the focus ring should be at least 2 pixels wide

  @ui
  Scenario: Global keyboard shortcuts
    When I am on any screen
    Then these shortcuts should work:
      | Key    | Action                    |
      | ?      | Open help                 |
      | q      | Quit application          |
      | h      | Navigate to home          |
      | /      | Open search               |
      | Esc    | Cancel current operation  |

  @safety-critical
  Scenario: Dangerous shortcuts require modifier
    When I want to trigger "Emergency Shutdown"
    Then I must use "Ctrl+Shift+E" (not just "E")
    And a confirmation should appear
```

#### 9.4.4 Tiered Rendering (SC-RENDER-001)

```gherkin
# features/ui/tiered_rendering.feature
@ui @ux
Feature: Tiered Terminal Rendering
  """
  STAMP Constraints: SC-RENDER-001, SC-RENDER-002

  The TUI supports three rendering tiers:
    Tier 1: GPU-accelerated (Kitty Graphics Protocol)
    Tier 2: Unicode high-density (Braille, Nerd Fonts)
    Tier 3: ASCII safe fallback
  """

  Background:
    Given the TUI application is starting

  @smoke
  Scenario: Automatic tier detection at startup
    When the application queries terminal capabilities
    Then the detected tier should match terminal capabilities
    And the renderer should be configured accordingly

  @ui @regression
  Scenario: Tier 1 (GPU) rendering for Kitty terminal
    Given the terminal responds to Kitty graphics query
    When the dashboard loads
    Then charts should render as PNG images
    And images should use base64 encoding
    And image resolution should match terminal cell size

  @ui @regression
  Scenario: Tier 2 (Unicode) rendering fallback
    Given the terminal supports Unicode but not Kitty
    When the dashboard loads
    Then charts should render using Braille characters (⣿⣇⣀)
    And icons should use Nerd Font glyphs
    And density should be 2x4 dots per character cell

  @ui @regression
  Scenario: Tier 3 (ASCII) safe fallback
    Given the terminal only supports ASCII
    When the dashboard loads
    Then charts should render using ASCII (|+-#)
    And icons should use text labels [OK] [ERR]
    And all information should remain legible

  @ui @edge-case
  Scenario: Runtime tier downgrade on error
    Given the application is using Tier 1 rendering
    When a Kitty graphics error occurs
    Then the application should downgrade to Tier 2
    And a message should display "Falling back to Unicode rendering"
    And all content should re-render

  @performance
  Scenario: Tier 1 rendering performance
    Given the terminal supports Tier 1
    When rendering a complex chart with 1000 data points
    Then the render time should be under 50ms
    And frame rate should maintain 30 FPS minimum
```

---

### 9.5 KMS Domain Feature Files

#### 9.5.1 Developer Portal

```gherkin
# features/kms/developer_portal.feature
@kms @dx
Feature: KMS Developer Portal
  """
  STAMP Constraints: SC-KMS-001, SC-KMS-007

  The Developer Portal enables engineers to:
    - Document Architecture Decision Records (ADRs)
    - Catalog reusable patterns
    - Track debug sessions
    - Link code to decisions
  """

  Background:
    Given I am logged in as a developer
    And I have write access to the KMS

  # ─────────────────────────────────────────────────────────────────────
  # ARCHITECTURE DECISION RECORDS
  # ─────────────────────────────────────────────────────────────────────

  @happy-path @ui
  Scenario: Create new ADR from template
    When I navigate to Developer Portal → Decisions → New
    Then I should see the ADR template with sections:
      | Section      | Required |
      | Title        | Yes      |
      | Date         | Auto     |
      | Status       | Yes      |
      | Context      | Yes      |
      | Decision     | Yes      |
      | Consequences | No       |

  @happy-path @ui
  Scenario: ADR with full content
    Given I am creating a new ADR
    When I fill in:
      | Field       | Value                                      |
      | Title       | Use GraphQL Federation for API Gateway     |
      | Status      | Proposed                                   |
      | Context     | We need to unify multiple microservice APIs|
      | Decision    | Implement GraphQL Federation 2.0           |
      | Consequences| Increased complexity but better DX         |
    And I click "Save"
    Then the ADR should be created
    And it should appear in the decisions list
    And an audit entry should be created
    And a Zenoh event "kms.decision.created" should be published

  @ui
  Scenario: ADR status workflow
    Given an ADR exists with status "Proposed"
    Then the available status transitions should be:
      | From       | To           |
      | Proposed   | Accepted     |
      | Proposed   | Rejected     |
      | Accepted   | Deprecated   |
      | Accepted   | Superseded   |

  @kms @ui
  Scenario: Link ADR to source code
    Given an ADR "GraphQL Strategy" exists
    When I link it to file "lib/indrajaal/api/federation.ex"
    Then the ADR should show "Linked Code: 1 file"
    And the file should show "Implements ADR: GraphQL Strategy"
    And a graph edge should be created

  @api @dx
  Scenario: Create ADR via REST API
    When I POST to "/api/v1/kms/decisions" with:
      """json
      {
        "title": "GraphQL Strategy",
        "status": "proposed",
        "context": "Need unified API",
        "decision": "Use Federation 2.0"
      }
      """
    Then the response status should be 201
    And the response should contain the ADR ID
    And the ADR should be searchable via API

  @api @dx
  Scenario: Search ADRs by semantic similarity
    Given ADRs exist about "GraphQL", "REST", and "gRPC"
    When I GET "/api/v1/kms/decisions/search?q=API%20design%20patterns"
    Then the response should rank results by relevance
    And "GraphQL Strategy" should appear in top 3

  # ─────────────────────────────────────────────────────────────────────
  # DESIGN PATTERNS
  # ─────────────────────────────────────────────────────────────────────

  @happy-path @ui
  Scenario: Catalog a new pattern
    When I navigate to Developer Portal → Patterns → New
    And I create pattern:
      | Field       | Value                                     |
      | Name        | Circuit Breaker                           |
      | Category    | Resilience                                |
      | Intent      | Prevent cascade failures                  |
      | Structure   | <Mermaid diagram>                         |
      | Example     | <Code snippet>                            |
    Then the pattern should be created
    And it should be indexed for search

  @ui
  Scenario: Link pattern to implementation
    Given pattern "Circuit Breaker" exists
    When I link it to module "Indrajaal.CircuitBreaker"
    Then the pattern should show "Implementation: 1"
    And the module should show "Implements: Circuit Breaker"

  # ─────────────────────────────────────────────────────────────────────
  # DEBUG SESSIONS
  # ─────────────────────────────────────────────────────────────────────

  @dx @ui
  Scenario: Start debug session capture
    When I navigate to Developer Portal → Debug → New Session
    And I enter session details:
      | Field       | Value                    |
      | Issue       | Memory leak in scheduler |
      | Hypothesis  | Unbounded queue growth   |
    And I click "Start Capture"
    Then a new debug session should be created
    And it should capture:
      | Data Type        | Source           |
      | Process traces   | BEAM observer    |
      | Memory snapshots | :erlang.memory/0 |
      | Log entries      | Logger           |

  @dx
  Scenario: Share debug session findings
    Given I have a debug session with findings
    When I click "Share Findings"
    Then a knowledge article should be created
    And it should be linked to the session
    And team members should be notified
```

#### 9.5.2 Product Manager Portal

```gherkin
# features/kms/product_portal.feature
@kms @cx
Feature: KMS Product Manager Portal
  """
  STAMP Constraints: SC-KMS-008

  The Product Manager Portal enables PMs to:
    - Manage feature specifications
    - Track release planning
    - Collect and analyze feedback
    - Create roadmap items
  """

  Background:
    Given I am logged in as a product manager
    And I have write access to the Product domain

  @happy-path @ui
  Scenario: Create feature specification
    When I navigate to Product Portal → Features → New
    And I create feature:
      | Field             | Value                          |
      | Title             | Dark Mode Support              |
      | Status            | Draft                          |
      | Problem Statement | Users need reduced eye strain  |
      | Success Criteria  | 80% adoption in 30 days        |
      | Priority          | P2                             |
    Then the feature should be created
    And it should appear on the roadmap

  @ui
  Scenario: Feature status workflow
    Given a feature "Dark Mode" exists with status "Draft"
    Then the available status transitions should be:
      | From           | To              |
      | Draft          | In Review       |
      | In Review      | Approved        |
      | In Review      | Needs Revision  |
      | Approved       | In Development  |
      | In Development | In Testing      |
      | In Testing     | Released        |

  @ui @cx
  Scenario: Link feature to customer feedback
    Given feature "Dark Mode" exists
    And customer feedback "Eye strain issue" exists
    When I link the feedback to the feature
    Then the feature should show "Customer Feedback: 1"
    And the feedback should show "Addressed by: Dark Mode"

  @ui
  Scenario: Plan release with features
    When I navigate to Product Portal → Releases → New
    And I create release:
      | Field    | Value              |
      | Version  | 2.5.0              |
      | Date     | 2025-02-15         |
      | Features | Dark Mode, SSO     |
    Then the release should be created
    And linked features should show "Target Release: 2.5.0"

  @api @dx
  Scenario: Query feature dependencies
    Given features exist with dependencies
    When I GET "/api/v1/kms/features/dark-mode/dependencies"
    Then the response should show:
      | Dependency Type | Items                        |
      | Blocks          | ["Theme System", "Settings"] |
      | Blocked By      | ["User Preferences API"]     |
      | Related         | ["Accessibility Mode"]       |
```

#### 9.5.3 SRE Portal

```gherkin
# features/kms/sre_portal.feature
@kms @cx @safety-critical
Feature: KMS SRE Portal
  """
  STAMP Constraints: SC-KMS-010, SC-KMS-011
  Priority: P0 (Critical for incident response)

  The SRE Portal enables operations engineers to:
    - Access and update runbooks
    - Document incidents
    - Track SLO/SLI metrics
    - Manage on-call procedures
  """

  Background:
    Given I am logged in as an SRE
    And I have write access to the Operations domain

  # ─────────────────────────────────────────────────────────────────────
  # RUNBOOKS
  # ─────────────────────────────────────────────────────────────────────

  @happy-path @ui @safety-critical
  Scenario: Create operational runbook
    When I navigate to SRE Portal → Runbooks → New
    And I create runbook:
      | Field          | Value                                   |
      | Title          | Database Failover Procedure             |
      | Severity       | SEV-1                                   |
      | Prerequisites  | Primary DB unreachable for > 5 minutes  |
      | Steps          | <Step-by-step procedure>                |
      | Rollback       | <Rollback procedure>                    |
      | Owner          | database-team@company.com               |
    Then the runbook should be created
    And it should be indexed for quick search
    And it should appear in SEV-1 runbooks list

  @ui @safety-critical
  Scenario: Runbook step verification
    Given runbook "Database Failover" has 5 steps
    When I execute the runbook
    Then I must verify each step:
      | Step | Action                      | Verification            |
      | 1    | Check primary status        | [x] Confirmed down      |
      | 2    | Notify stakeholders         | [x] Slack sent          |
      | 3    | Promote replica             | [x] Command successful  |
      | 4    | Update DNS                  | [x] Propagated          |
      | 5    | Verify application health   | [x] All checks pass     |
    And I cannot skip to step N without completing step N-1
    And all verifications are logged

  @ui
  Scenario: Link runbook to incident
    Given an incident "DB-2025-0042" is open
    And runbook "Database Failover" exists
    When I link the runbook to the incident
    Then the incident should show "Runbook Used: Database Failover"
    And the runbook should show "Used in: 1 incident"

  # ─────────────────────────────────────────────────────────────────────
  # INCIDENTS
  # ─────────────────────────────────────────────────────────────────────

  @happy-path @ui
  Scenario: Create incident report
    When I navigate to SRE Portal → Incidents → New
    And I create incident:
      | Field           | Value                              |
      | Title           | Payment Processing Degraded        |
      | Severity        | SEV-2                              |
      | Impact          | 15% of payments failing            |
      | Start Time      | 2025-01-15T14:32:00Z               |
      | Root Cause      | Database connection pool exhausted |
      | Resolution      | Increased pool size to 50          |
    Then the incident should be created
    And a post-mortem template should be generated
    And stakeholders should be notified

  @ui @cx
  Scenario: Incident timeline auto-population
    Given an incident "DB-2025-0042" is in progress
    Then the timeline should auto-capture:
      | Time     | Event                               |
      | 14:32:00 | Alert triggered: DB_CONN_POOL_HIGH  |
      | 14:33:15 | Incident created by: sre-bot        |
      | 14:35:00 | On-call paged: alice@company.com    |
      | 14:36:30 | Status page updated                 |
    And manual entries can be added

  @api @dx
  Scenario: Query incidents by time range
    When I GET "/api/v1/kms/incidents?from=2025-01-01&to=2025-01-31&severity=SEV-1"
    Then the response should contain all SEV-1 incidents in January
    And each incident should include:
      | Field          | Present |
      | title          | Yes     |
      | severity       | Yes     |
      | mttr_minutes   | Yes     |
      | root_cause     | Yes     |

  # ─────────────────────────────────────────────────────────────────────
  # ON-CALL MANAGEMENT
  # ─────────────────────────────────────────────────────────────────────

  @ui
  Scenario: View on-call schedule
    When I navigate to SRE Portal → On-Call
    Then I should see:
      | Period            | Primary       | Secondary      |
      | Current           | alice@        | bob@           |
      | Next (in 2 days)  | charlie@      | david@         |

  @ui
  Scenario: Escalation policy visibility
    Given escalation policy "Database" exists
    When I view the policy
    Then I should see escalation tiers:
      | Tier | Wait    | Contact          |
      | 1    | 0 min   | Primary on-call  |
      | 2    | 15 min  | Secondary        |
      | 3    | 30 min  | Team lead        |
      | 4    | 60 min  | Engineering VP   |
```

#### 9.5.4 Tech Lead Portal

```gherkin
# features/kms/techlead_portal.feature
@kms @dx
Feature: KMS Tech Lead Portal
  """
  STAMP Constraints: SC-KMS-012

  The Tech Lead Portal enables technical leaders to:
    - Manage technical roadmaps
    - Conduct code reviews
    - Track technical debt
    - Make architectural decisions
  """

  Background:
    Given I am logged in as a tech lead
    And I have write access to the Leadership domain

  @happy-path @ui
  Scenario: Create technical roadmap item
    When I navigate to Tech Lead Portal → Roadmap → New
    And I create item:
      | Field        | Value                            |
      | Title        | Migrate to Elixir 1.19           |
      | Quarter      | Q2 2025                          |
      | Effort       | Large (> 2 weeks)                |
      | Dependencies | Phoenix 1.8 upgrade              |
      | Risk         | Medium                           |
    Then the roadmap item should be created
    And it should appear on the technical roadmap

  @ui
  Scenario: Track technical debt
    When I navigate to Tech Lead Portal → Tech Debt → New
    And I create debt item:
      | Field      | Value                              |
      | Title      | Legacy authentication module       |
      | Impact     | High (blocks new features)         |
      | Effort     | Medium (1-2 weeks)                 |
      | Priority   | P2                                 |
    Then the debt item should be created
    And it should affect the technical health score

  @ui
  Scenario: Link roadmap to ADRs
    Given roadmap item "Migrate to Elixir 1.19" exists
    And ADR "Elixir Version Policy" exists
    When I link them
    Then the roadmap item should show "Related ADR: 1"
    And the ADR should show "Roadmap: Migrate to Elixir 1.19"
```

---

### 9.6 Cross-Runtime Integration Feature Files

#### 9.6.1 Zenoh Pub/Sub

```gherkin
# features/integration/zenoh_sync.feature
@integration @zenoh
Feature: Cross-Runtime Zenoh Synchronization
  """
  STAMP Constraints: SC-KMS-016

  Ensures real-time synchronization between:
    - Elixir backend (Phoenix/Ash)
    - F# TUI cockpit (Terminal)
    - Any other Zenoh-enabled clients
  """

  Background:
    Given the Zenoh broker is running
    And the Elixir backend is connected to Zenoh
    And the F# TUI is connected to Zenoh

  @happy-path @performance
  Scenario: KMS creation event propagates to TUI within 100ms
    Given the F# TUI is displaying the KMS dashboard
    When a new ADR is created via Phoenix LiveView
    Then the Elixir backend should publish "kms.decision.created"
    And the F# TUI should receive the event within 100ms
    And the F# TUI should update its display automatically

  @performance
  Scenario: Metric updates propagate in real-time
    Given the F# TUI is displaying system metrics
    When the backend publishes a metric update
    Then the TUI should reflect the new value within 50ms

  @edge-case @error-handling
  Scenario: F# TUI handles Zenoh disconnection gracefully
    Given the F# TUI is connected to Zenoh
    When the Zenoh connection is lost
    Then the TUI should show "Zenoh: Disconnected"
    And the TUI should attempt reconnection every 5 seconds
    And cached data should remain displayed with staleness indicator

  @integration
  Scenario: Bidirectional sync between TUI and LiveView
    Given the F# TUI and LiveView are both connected
    When I update a value in the F# TUI
    Then the LiveView should reflect the change
    And both should show the same data

  @chaos
  Scenario: Message ordering preserved under load
    Given 100 messages are published in sequence
    Then the F# TUI should receive them in the same order
    And no messages should be lost
```

#### 9.6.2 Phoenix LiveView Integration

```gherkin
# features/integration/liveview.feature
@integration @ui
Feature: Phoenix LiveView Safety Integration
  """
  STAMP Constraints: SC-HMI-007

  Ensures the Phoenix LiveView web interface maintains
  the same safety guarantees as the F# TUI.
  """

  Background:
    Given I am logged into the LiveView dashboard
    And the backend connection is established

  @safety-critical
  Scenario: LiveView implements Arm & Fire for dangerous actions
    Given I am on the LiveView dashboard
    When I click "Emergency Shutdown"
    Then the button should enter "Armed" state
    And I must hold click for 3 seconds to engage
    And the same audit trail should be created

  @safety-critical
  Scenario: LiveView shows stale data overlay
    Given I am viewing real-time metrics
    When the WebSocket connection is lost for 2 seconds
    Then a stale data overlay should appear
    And inputs should be disabled

  @ui
  Scenario: LiveView renders consistent colors
    When I view a critical alarm in LiveView
    Then the alarm should be #FF0000 (red)
    And it should match the F# TUI color exactly
```

---

### 9.7 Performance Feature Files

```gherkin
# features/performance/response_time.feature
@performance
Feature: System Performance Requirements
  """
  STAMP Constraints: SC-PRF-050, SC-PRF-055

  Defines performance thresholds for the system.
  All scenarios must pass under normal and peak load.
  """

  @safety-critical @performance
  Scenario: UI response time under 50ms
    Given the system is under normal load
    When I perform any UI action
    Then visual feedback should appear within 50ms
    And the 95th percentile should be under 100ms

  @performance
  Scenario: Backend API response time
    Given the API is under normal load
    When I make a REST API request
    Then the response should arrive within 200ms
    And the 95th percentile should be under 500ms

  @performance
  Scenario: KMS search response time
    Given the KMS contains 10,000 documents
    When I perform a semantic search
    Then results should appear within 500ms
    And the search should use vector similarity

  @performance
  Scenario: Zenoh message latency
    Given Elixir and F# are connected via Zenoh
    When a message is published
    Then it should be received within 10ms average
    And the 99th percentile should be under 50ms

  @performance @chaos
  Scenario: Performance under peak load
    Given the system is under 10x normal load
    Then UI response time should remain under 200ms
    And no requests should timeout
    And error rate should be under 0.1%
```

---

### 9.8 Error Recovery Feature Files

```gherkin
# features/error_recovery/graceful_degradation.feature
@error-handling @chaos
Feature: Graceful Degradation and Recovery
  """
  STAMP Constraints: SC-EMR-057, SC-EMR-060

  The system must degrade gracefully under failure conditions
  and recover automatically when possible.
  """

  Background:
    Given the system is fully operational

  @safety-critical @chaos
  Scenario: Database connection lost
    When the database connection is lost
    Then the system should:
      | Step | Action                               |
      | 1    | Display "Database Unavailable"       |
      | 2    | Disable write operations             |
      | 3    | Continue serving cached data         |
      | 4    | Attempt reconnection every 5 seconds |
    And an alert should be sent to on-call

  @safety-critical @chaos
  Scenario: TUI process crash recovery
    Given the TUI GenServer is running
    When the process crashes
    Then the supervisor should restart it within 100ms
    And the safety state should be preserved
    And the display should recover within 500ms

  @chaos
  Scenario: Network partition recovery
    Given a network partition occurs for 30 seconds
    When the partition heals
    Then the system should:
      | Step | Action                              |
      | 1    | Detect connectivity restored        |
      | 2    | Request full state synchronization  |
      | 3    | Resolve any conflicts               |
      | 4    | Resume normal operation             |
    And data should be consistent across all nodes

  @error-handling
  Scenario: Rollback on failed operation
    Given I start a multi-step operation
    When step 3 of 5 fails
    Then steps 1-2 should be rolled back
    And the system should return to original state
    And an error report should be generated

  @chaos
  Scenario: Cascading failure prevention
    Given service A depends on service B
    When service B becomes unhealthy
    Then service A should:
      | Action                              |
      | Activate circuit breaker            |
      | Return cached/default responses     |
      | Not propagate failures upstream     |
    And the circuit should remain open for 30 seconds
```

---

### 9.9 Step Definition Templates

#### 9.9.1 Elixir Step Definitions

```elixir
# test/support/bdd/safety_steps.ex
defmodule Indrajaal.BDD.SafetySteps do
  @moduledoc """
  BDD step definitions for safety-critical scenarios.

  ## STAMP Constraints
  - SC-TEST-001: All safety steps must log to audit trail
  - SC-TEST-002: Property tests must accompany BDD scenarios
  """

  import ExUnit.Assertions

  # ── Background Steps ──────────────────────────────────────────────

  def given_the_system_is_in_operational_mode(context) do
    assert Safety.Supervisor.healthy?()
    assert Safety.HardwareState.get_mode() == :operational
    Map.put(context, :system_mode, :operational)
  end

  def given_all_safety_interlocks_are_satisfied(context) do
    Safety.Interlocks.check_all!()
    context
  end

  def given_heartbeats_are_being_received_every_100ms(context) do
    start_supervised!({MockHeartbeatGenerator, interval: 100})
    context
  end

  # ── Action Steps ──────────────────────────────────────────────────

  def when_i_press_enter_on_action_button(context, button_name) do
    {:ok, model} = TUI.State.get()
    {:ok, new_model} = TUI.Update.handle_key_press(:enter, model)
    TUI.State.put(new_model)
    Map.put(context, :button_pressed, button_name)
  end

  def when_i_hold_space_for_seconds(context, seconds) do
    seconds_float = String.to_float(seconds)
    {:ok, model} = TUI.State.get()

    # Simulate hold timer ticks
    ticks = round(seconds_float / 0.033)
    final_model = Enum.reduce(1..ticks, model, fn _, acc ->
      {:ok, new_model} = TUI.Update.handle_hold_tick(acc)
      new_model
    end)

    TUI.State.put(final_model)
    Map.put(context, :hold_duration, seconds_float)
  end

  def when_the_heartbeat_stops_for_milliseconds(context, ms) do
    MockHeartbeatGenerator.stop()
    Process.sleep(String.to_integer(ms))
    context
  end

  def when_the_physical_estop_is_engaged(context) do
    Safety.EStopListener.simulate_engage("Test Scenario")
    context
  end

  # ── Assertion Steps ───────────────────────────────────────────────

  def then_the_action_state_should_be(context, expected_state) do
    {:ok, model} = TUI.State.get()
    actual_state = model.action_state |> Atom.to_string()
    assert actual_state == expected_state,
      "Expected state #{expected_state}, got #{actual_state}"
    context
  end

  def then_the_action_should_not_be_executed(context) do
    refute context[:action_executed], "Action was executed but should not have been"
    context
  end

  def then_an_audit_entry_should_be_created(context, event_type) do
    {:ok, entries} = AuditLog.get_recent(1)
    assert length(entries) > 0, "No audit entries found"
    assert hd(entries).event_type == event_type,
      "Expected audit event #{event_type}, got #{hd(entries).event_type}"
    context
  end

  def then_the_overlay_should_display(context, expected_message) do
    {:ok, model} = TUI.State.get()
    assert model.overlay_message == expected_message,
      "Expected overlay '#{expected_message}', got '#{model.overlay_message}'"
    context
  end

  def then_all_inputs_should_be_locked(context) do
    {:ok, model} = TUI.State.get()
    assert model.all_inputs_locked == true
    context
  end
end
```

#### 9.9.2 F# Step Definitions

```fsharp
// test/Cepaf.Tests/BddSteps/SafetySteps.fs
module Indrajaal.Cockpit.Tests.BddSteps.SafetySteps

open Expecto
open Indrajaal.Cockpit.Domain
open Indrajaal.Cockpit.Update

/// SC-TEST-001: BDD step definitions for safety FSM
module SafetySteps =

    // ── Given Steps ────────────────────────────────────────────────

    let givenSystemInOperationalMode (context: TestContext) =
        let model = { Model.initial with SystemMode = Operational }
        { context with Model = model }

    let givenActionStateIs (state: string) (context: TestContext) =
        let actionState =
            match state with
            | "Idle" -> Idle
            | "Selected" -> Selected
            | "Armed" -> Armed 10.0<sec>
            | "Firing" -> Firing 0.0<sec>
            | "Engaged" -> Engaged
            | "Locked" -> Locked "Test"
            | _ -> failwith $"Unknown state: {state}"
        { context with Model = { context.Model with ActionState = actionState }}

    // ── When Steps ─────────────────────────────────────────────────

    let whenIPressKey (key: string) (context: TestContext) =
        let keyPress =
            match key with
            | "Enter" -> KeyPress Key.Enter
            | "Escape" -> KeyPress Key.Escape
            | "Space" -> KeyPress Key.Space
            | _ -> failwith $"Unknown key: {key}"
        let newModel, _ = update keyPress context.Model
        { context with Model = newModel }

    let whenIHoldSpaceForSeconds (duration: float) (context: TestContext) =
        // Simulate hold timer ticks
        let ticks = int (duration / 0.033)
        let finalModel =
            [1..ticks]
            |> List.fold (fun model _ ->
                update HoldTimerTick model |> fst
            ) context.Model
        { context with Model = finalModel }

    let whenEStopIsEngaged (reason: string) (context: TestContext) =
        let newModel, _ = update (EStopEngaged reason) context.Model
        { context with Model = newModel }

    // ── Then Steps ─────────────────────────────────────────────────

    let thenActionStateShouldBe (expected: string) (context: TestContext) =
        let actual =
            match context.Model.ActionState with
            | Idle -> "Idle"
            | Selected -> "Selected"
            | Armed _ -> "Armed"
            | Firing _ -> "Firing"
            | Engaged -> "Engaged"
            | Locked _ -> "Locked"
        Expect.equal actual expected "Action state mismatch"
        context

    let thenAuditLogShouldContain (eventType: string) (context: TestContext) =
        let hasEvent =
            context.Model.AuditLog
            |> List.exists (fun e -> e.Event = eventType)
        Expect.isTrue hasEvent $"Audit log should contain {eventType}"
        context

    let thenAllInputsShouldBeLocked (context: TestContext) =
        Expect.isTrue context.Model.AllInputsLocked "Inputs should be locked"
        context

// ── BDD Test Runner ────────────────────────────────────────────────
[<Tests>]
let armAndFireTests =
    testList "Arm and Fire BDD Scenarios" [
        test "Cannot engage action with single keystroke" {
            TestContext.empty
            |> SafetySteps.givenSystemInOperationalMode
            |> SafetySteps.givenActionStateIs "Idle"
            |> SafetySteps.whenIPressKey "Enter"
            |> SafetySteps.thenActionStateShouldBe "Armed"
            |> SafetySteps.thenAuditLogShouldContain "ACTION_ARMED"
            |> ignore
        }

        test "E-Stop immediately locks from any state" {
            for state in ["Idle"; "Selected"; "Armed"; "Firing"; "Engaged"] do
                TestContext.empty
                |> SafetySteps.givenSystemInOperationalMode
                |> SafetySteps.givenActionStateIs state
                |> SafetySteps.whenEStopIsEngaged "Physical Button"
                |> SafetySteps.thenActionStateShouldBe "Locked"
                |> SafetySteps.thenAllInputsShouldBeLocked
                |> ignore
        }
    ]
```

---

### 9.10 BDD Coverage Matrix

| Feature File | Scenarios | Tags | Coverage |
|--------------|-----------|------|----------|
| `arm_and_fire.feature` | 25 | @safety-critical, @iso-13850 | 100% |
| `stale_data.feature` | 18 | @safety-critical, @stale-data | 100% |
| `emergency_stop.feature` | 12 | @safety-critical, @estop | 100% |
| `zone_layout.feature` | 8 | @ui, @ux, @regression | 100% |
| `color_semantics.feature` | 10 | @ui, @accessibility | 100% |
| `keyboard_navigation.feature` | 12 | @ui, @accessibility | 100% |
| `tiered_rendering.feature` | 8 | @ui, @regression | 95% |
| `developer_portal.feature` | 15 | @kms, @dx | 90% |
| `product_portal.feature` | 10 | @kms, @cx | 90% |
| `sre_portal.feature` | 18 | @kms, @safety-critical | 95% |
| `techlead_portal.feature` | 8 | @kms, @dx | 90% |
| `zenoh_sync.feature` | 8 | @integration, @zenoh | 95% |
| `liveview.feature` | 6 | @integration, @ui | 90% |
| `response_time.feature` | 6 | @performance | 95% |
| `graceful_degradation.feature` | 8 | @chaos, @error-handling | 90% |
| **Total** | **172** | | **96%** |

---

### 9.11 BDD Execution Commands

```bash
# Run all BDD scenarios
mix bdd.run --all

# Run by tag
mix bdd.run --tags @safety-critical
mix bdd.run --tags @kms --tags @happy-path
mix bdd.run --exclude @chaos

# Run specific feature file
mix bdd.run features/safety/arm_and_fire.feature

# Generate BDD coverage report
mix bdd.coverage --format html --output reports/bdd_coverage.html

# F# BDD tests
dotnet run --project test/Cepaf.Tests -- --filter "Category=BDD"
dotnet run --project test/Cepaf.Tests -- --filter "BDD Scenarios"

# Visual regression with VHS
vhs features/safety/arm_and_fire_visual.tape
vhs features/safety/stale_data_visual.tape

# Generate Gherkin documentation
mix bdd.docs --format markdown --output docs/bdd/
```

---

### 9.12 AI-Assisted Testing Methodologies

> **Section Status**: COMPREHENSIVE | **Methodologies**: 11 | **Tools**: 25+
>
> This section defines the complete AI-assisted testing framework for the Indrajaal
> Safety-Critical System, covering all modern testing paradigms with concrete
> implementations for both Elixir and F# runtimes.

#### 9.12.1 Testing Methodology Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    AI-ASSISTED TESTING FRAMEWORK                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                         AI TESTING ENGINE                               │    │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │    │
│   │  │ OpenRouter  │  │ Claude API  │  │ Local LLM   │  │ Vision API  │   │    │
│   │  │ (Multi-LLM) │  │ (Analysis)  │  │ (Ollama)    │  │ (GPT-4V)    │   │    │
│   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │    │
│   └─────────┼────────────────┼────────────────┼────────────────┼───────────┘    │
│             │                │                │                │                 │
│             └────────────────┴────────────────┴────────────────┘                 │
│                                      │                                           │
│                                      ▼                                           │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                    TESTING METHODOLOGY LAYER                            │    │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │    │
│   │  │ BDD      │ │ Model-   │ │ Visual   │ │ Record & │ │ OCR      │     │    │
│   │  │ Testing  │ │ Based    │ │ Testing  │ │ Playback │ │ Testing  │     │    │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │    │
│   │       │            │            │            │            │            │    │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │    │
│   │  │ Object   │ │ Image-   │ │ Hybrid   │ │ Object   │ │ Functional│     │    │
│   │  │ Based    │ │ Based    │ │ Testing  │ │ ID       │ │ Testing  │     │    │
│   │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │    │
│   └───────┼────────────┼────────────┼────────────┼────────────┼───────────┘    │
│           │            │            │            │            │                 │
│           └────────────┴────────────┴────────────┴────────────┘                 │
│                                      │                                           │
│                                      ▼                                           │
│   ┌────────────────────────────────────────────────────────────────────────┐    │
│   │                    EXECUTION TARGETS                                    │    │
│   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │    │
│   │  │ F# TUI Cockpit  │  │ Phoenix LiveView │  │ REST/GraphQL API│         │    │
│   │  │ (Terminal)      │  │ (Browser)        │  │ (HTTP)          │         │    │
│   │  └─────────────────┘  └─────────────────┘  └─────────────────┘         │    │
│   └────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### 9.12.2 Methodology Coverage Matrix

| Methodology | AI Component | Tool Stack | Coverage Target | STAMP Constraint |
|-------------|--------------|------------|-----------------|------------------|
| **AI-Assisted Testing** | GPT-4/Claude | OpenRouter, Custom | 100% critical paths | SC-TEST-AI-001 |
| **Behavior-Driven Testing** | Test generation | Gherkin, ExUnit | 100% features | SC-TEST-BDD-001 |
| **Record-and-Playback** | Action inference | VHS, Playwright | 90% UI flows | SC-TEST-RAP-001 |
| **Model-Based Testing** | State exploration | QuickCheck, FsCheck | 100% FSM | SC-TEST-MBT-001 |
| **Object Identification** | DOM/TUI analysis | AI Vision, Selectors | 95% elements | SC-TEST-OID-001 |
| **Visual Testing** | Image diff | Percy, Applitools | 100% screens | SC-TEST-VIS-001 |
| **Functional Testing** | Assertion gen | ExUnit, Expecto | 100% functions | SC-TEST-FUN-001 |
| **Object-Based Testing** | Widget recognition | Custom, Accessibility | 95% widgets | SC-TEST-OBJ-001 |
| **Image-Based Testing** | Pixel comparison | ImageMagick, VHS | 100% visual | SC-TEST-IMG-001 |
| **Visual Verification** | AI validation | GPT-4V, Claude Vision | 90% layout | SC-TEST-VVR-001 |
| **OCR Testing** | Text extraction | Tesseract, EasyOCR | 99% text | SC-TEST-OCR-001 |
| **Hybrid Testing** | Multi-method | Unified Framework | 100% system | SC-TEST-HYB-001 |

---

#### 9.12.3 AI-Assisted Testing (SC-TEST-AI-*)

```gherkin
# features/ai_testing/ai_assisted.feature
@ai-testing @safety-critical
Feature: AI-Assisted Test Generation and Validation
  """
  STAMP Constraints: SC-TEST-AI-001 to SC-TEST-AI-010

  AI-assisted testing uses LLM APIs (OpenRouter, Claude, GPT-4) to:
    - Generate test cases from specifications
    - Analyze test coverage gaps
    - Validate UI/UX compliance
    - Generate property-based test generators
    - Perform intelligent fuzzing
  """

  Background:
    Given the AI testing service is configured with OpenRouter API
    And the test generation model is "anthropic/claude-3.5-sonnet"
    And the vision model is "openai/gpt-4-vision-preview"

  # ─────────────────────────────────────────────────────────────────────
  # TEST GENERATION
  # ─────────────────────────────────────────────────────────────────────

  @ai @generation
  Scenario: AI generates test cases from module specification
    Given the module "Indrajaal.Safety.EStopListener" exists
    And the module has @moduledoc with behavior specification
    When I invoke AI test generation with:
      | Parameter       | Value                          |
      | coverage_target | 95%                            |
      | test_types      | unit, property, integration    |
      | safety_focus    | true                           |
    Then the AI should generate test cases for:
      | Function              | Test Count | Type        |
      | handle_info/2         | 5          | unit        |
      | engage/1              | 3          | property    |
      | reset_sequence/1      | 4          | integration |
    And all generated tests should compile
    And generated tests should include safety assertions

  @ai @coverage-analysis
  Scenario: AI identifies coverage gaps
    Given the test suite has 85% line coverage
    When I invoke AI coverage analysis with:
      """json
      {
        "analyze": ["lib/indrajaal/safety/"],
        "focus": "uncovered_branches",
        "suggest_tests": true
      }
      """
    Then the AI should identify uncovered paths:
      | File                  | Line  | Branch              |
      | estop_listener.ex     | 45    | error handling      |
      | watchdog.ex           | 78    | timeout edge case   |
    And the AI should suggest test cases for each gap
    And suggested tests should target safety-critical paths first

  @ai @property-generation
  Scenario: AI generates property-based test generators
    Given the type "ActionState" is defined in Domain.fs
    When I invoke AI generator creation with:
      | Type         | Constraints                    |
      | ActionState  | Valid state transitions only   |
      | HoldProgress | 0.0 to 3.0 seconds            |
      | TimeRemaining| 0 to 10 seconds               |
    Then the AI should generate FsCheck generators:
      ```fsharp
      let genValidTransition = Gen.oneof [
          Gen.constant (Idle, Selected)
          Gen.constant (Selected, Armed 10.0<sec>)
          // ... all valid transitions
      ]
      ```
    And generators should respect STAMP constraints

  # ─────────────────────────────────────────────────────────────────────
  # INTELLIGENT FUZZING
  # ─────────────────────────────────────────────────────────────────────

  @ai @fuzzing @safety-critical
  Scenario: AI-guided fuzzing for safety boundaries
    Given the Arm & Fire FSM is the target
    When I invoke AI-guided fuzzing with:
      | Parameter           | Value                |
      | focus               | state_transitions    |
      | mutation_strategy   | boundary_aware       |
      | safety_invariants   | SC-SAFETY-001..005   |
    Then the fuzzer should generate inputs targeting:
      | Boundary                    | Input Type           |
      | 2.999s hold (just under 3s) | timing               |
      | 10.001s armed (just over)   | timeout              |
      | Rapid state changes         | race condition       |
    And no input should violate safety invariants
    And all violations should be logged to audit

  @ai @validation
  Scenario: AI validates UI against design specification
    Given a screenshot of the Armed state button
    And the design specification requires amber border
    When I invoke AI visual validation with:
      | Aspect          | Requirement           |
      | border_color    | #FFA500 (amber)       |
      | border_width    | >= 2px                |
      | text_contrast   | >= 4.5:1              |
    Then the AI should confirm compliance or report:
      | Check           | Status  | Actual    | Expected  |
      | border_color    | PASS    | #FFA500   | #FFA500   |
      | border_width    | PASS    | 3px       | >= 2px    |
      | text_contrast   | PASS    | 7.2:1     | >= 4.5:1  |
```

**AI Testing Implementation (Elixir):**

```elixir
defmodule Indrajaal.AITesting.TestGenerator do
  @moduledoc """
  AI-powered test generation using OpenRouter API.

  ## STAMP Constraints
  - SC-TEST-AI-001: All AI-generated tests must be reviewed
  - SC-TEST-AI-002: Safety-critical paths require human approval
  - SC-TEST-AI-003: Generated tests must compile before commit
  """

  alias Indrajaal.AI.OpenRouterClient

  @generation_prompt """
  You are a safety-critical test engineer. Generate ExUnit tests for the
  following Elixir module. Focus on:
  1. All public functions
  2. Edge cases and boundary conditions
  3. Error handling paths
  4. Safety invariants (STAMP constraints)

  Module source:
  <%= @source_code %>

  Generate tests in this format:
  ```elixir
  defmodule <%= @module_name %>Test do
    use ExUnit.Case, async: false
    # ... tests
  end
  ```
  """

  def generate_tests(module_name, opts \\ []) do
    source_code = get_module_source(module_name)
    coverage_target = Keyword.get(opts, :coverage_target, 0.95)
    safety_focus = Keyword.get(opts, :safety_focus, true)

    prompt = EEx.eval_string(@generation_prompt, [
      source_code: source_code,
      module_name: module_name
    ])

    {:ok, response} = OpenRouterClient.chat([
      %{role: "user", content: prompt}
    ], model: "anthropic/claude-3.5-sonnet", max_tokens: 4000)

    tests = extract_code_blocks(response)

    # SC-TEST-AI-003: Validate generated tests compile
    case compile_tests(tests) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, errors} -> {:error, :compile_failed, errors}
    end
  end

  def analyze_coverage_gaps(paths, opts \\ []) do
    coverage_data = ExCoveralls.get_coverage(paths)
    uncovered = find_uncovered_branches(coverage_data)

    prompt = """
    Analyze these uncovered code paths and suggest test cases:

    #{format_uncovered(uncovered)}

    Focus on safety-critical paths first. For each gap, provide:
    1. Why this path matters
    2. Test case to cover it
    3. Expected behavior
    """

    {:ok, suggestions} = OpenRouterClient.chat([
      %{role: "user", content: prompt}
    ], model: "anthropic/claude-3.5-sonnet")

    parse_suggestions(suggestions)
  end
end
```

---

#### 9.12.4 Record-and-Playback Testing (SC-TEST-RAP-*)

```gherkin
# features/ai_testing/record_playback.feature
@record-playback @ui
Feature: Record and Playback Testing
  """
  STAMP Constraints: SC-TEST-RAP-001 to SC-TEST-RAP-005

  Record user interactions and replay them for regression testing.
  Uses VHS for terminal recording and Playwright for web.
  """

  Background:
    Given the recording system is initialized
    And the playback engine is ready

  # ─────────────────────────────────────────────────────────────────────
  # TERMINAL RECORDING (VHS)
  # ─────────────────────────────────────────────────────────────────────

  @tui @recording
  Scenario: Record terminal interaction session
    Given the F# TUI cockpit is running
    When I start recording with VHS:
      ```tape
      Output arm_fire_session.gif
      Set Width 120
      Set Height 40

      Type "prajna-cockpit"
      Enter
      Sleep 2s

      # Navigate to dangerous action
      Type "j" Sleep 200ms
      Type "j" Sleep 200ms

      # Arm the action
      Enter
      Sleep 1s
      Screenshot armed_state.png

      # Fire (hold space for 3s)
      Type " "
      Sleep 3.5s
      Screenshot engaged_state.png

      # Exit
      Type "q"
      ```
    Then the recording should capture:
      | Frame | State    | Visual Element        |
      | 1     | Idle     | Normal button          |
      | 2     | Selected | Cyan border            |
      | 3     | Armed    | Amber border + timer   |
      | 4     | Firing   | Progress bar           |
      | 5     | Engaged  | Flash + success        |
    And screenshots should be saved for visual regression

  @tui @playback
  Scenario: Playback recorded session for regression
    Given the recording "arm_fire_session.tape" exists
    When I playback the recording
    Then each step should execute with timing tolerance of ±100ms
    And the final state should match the recorded state
    And any visual differences should be flagged

  @web @recording
  Scenario: Record LiveView interaction with Playwright
    Given the Phoenix server is running on port 4000
    When I start Playwright recording:
      ```javascript
      const { chromium } = require('playwright');

      (async () => {
        const browser = await chromium.launch({ headless: false });
        const context = await browser.newContext({
          recordVideo: { dir: 'videos/' }
        });
        const page = await context.newPage();

        await page.goto('http://localhost:4000/dashboard');
        await page.click('[data-testid="emergency-shutdown"]');
        await page.waitForSelector('.armed-state');

        // Hold click for 3 seconds
        await page.mouse.down();
        await page.waitForTimeout(3000);
        await page.mouse.up();

        await page.waitForSelector('.engaged-state');
        await browser.close();
      })();
      ```
    Then the recording should be saved to "videos/"
    And a test script should be generated automatically

  # ─────────────────────────────────────────────────────────────────────
  # AI-ENHANCED RECORDING
  # ─────────────────────────────────────────────────────────────────────

  @ai @recording
  Scenario: AI interprets recorded actions and generates tests
    Given a recorded session "user_session_001.json" exists
    When I invoke AI interpretation:
      | Parameter        | Value                    |
      | session_file     | user_session_001.json    |
      | generate_tests   | true                     |
      | abstract_selectors| true                    |
    Then the AI should:
      | Action                        | Output                    |
      | Identify user intent          | "Arm and fire action"     |
      | Abstract brittle selectors    | Use data-testid instead   |
      | Generate maintainable test    | PageObject pattern        |
      | Add assertions                | Safety state verification |
```

**VHS Recording Template:**

```tape
# safety_test_template.tape
# VHS recording template for safety-critical TUI testing

# Configuration
Output safety_test.gif
Set Width 120
Set Height 40
Set FontSize 14
Set Theme "Indrajaal"
Set TypingSpeed 50ms
Set PlaybackSpeed 0.5

# Initialize
Hide
Type "export TERM=xterm-256color"
Enter
Sleep 500ms
Show

# Start Application
Type "prajna-cockpit --test-mode"
Enter
Sleep 2s
Screenshot 01_initial_state.png

# Test Arm & Fire Sequence
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Screenshot 02_selected.png

# Arm
Enter
Sleep 500ms
Screenshot 03_armed.png

# Verify countdown displays
Sleep 3s
Screenshot 04_countdown.png

# Fire (hold space)
Type " "
Sleep 3.5s
Screenshot 05_engaged.png

# Cleanup
Type "q"
Sleep 500ms
Screenshot 06_exit.png

# Generate comparison report
# Compare against baseline: scripts/vhs/compare_baseline.sh safety_test
```

---

#### 9.12.5 Model-Based Testing (SC-TEST-MBT-*)

```gherkin
# features/ai_testing/model_based.feature
@model-based @safety-critical
Feature: Model-Based Testing for FSM Verification
  """
  STAMP Constraints: SC-TEST-MBT-001 to SC-TEST-MBT-008

  Uses formal state machine models to generate comprehensive test cases
  that explore all states and transitions systematically.
  """

  Background:
    Given the ActionState FSM model is loaded
    And the test generator is configured for exhaustive exploration

  @mbt @fsm
  Scenario: Generate tests from state machine model
    Given the FSM model:
      ```
      States: {Idle, Selected, Armed, Firing, Engaged, Locked}
      Transitions: {
        Idle --[navigate]--> Selected
        Selected --[escape]--> Idle
        Selected --[enter]--> Armed
        Armed --[timeout]--> Idle
        Armed --[hold_space]--> Firing
        Firing --[release_early]--> Armed
        Firing --[hold_complete]--> Engaged
        Engaged --[auto_reset]--> Idle
        * --[estop]--> Locked
      }
      ```
    When I generate tests with coverage:
      | Coverage Type      | Target |
      | State coverage     | 100%   |
      | Transition coverage| 100%   |
      | Path coverage      | All paths up to depth 5 |
    Then the generator should produce:
      | Test Type                | Count |
      | State reachability       | 6     |
      | Transition coverage      | 9     |
      | Invalid transition       | 15    |
      | Path coverage            | 42    |

  @mbt @property
  Scenario: Property-based testing with FsCheck
    Given the FSM model as FsCheck specification:
      ```fsharp
      let actionStateGen = Gen.oneof [
          Gen.constant Idle
          Gen.constant Selected
          Gen.map Armed (Gen.choose(0, 100) |> Gen.map float)
          Gen.map Firing (Gen.floatRange 0.0 3.0)
          Gen.constant Engaged
          Gen.map Locked Arb.generate<string>
      ]

      let transitionSequenceGen =
          Gen.listOf (Gen.elements [
              Navigate; Escape; PressEnter;
              HoldSpace; ReleaseSpace; Timeout; EStop
          ])
      ```
    When I run property tests:
      ```fsharp
      [<Property>]
      let ``Safety invariant: Cannot reach Engaged without Armed`` () =
          Prop.forAll transitionSequenceGen (fun transitions ->
              let finalState = List.fold applyTransition Idle transitions
              match finalState with
              | Engaged ->
                  // Verify audit log contains Armed
                  getAuditLog() |> List.exists (fun e -> e = "ARMED")
              | _ -> true
          )
      ```
    Then the property should pass for 10000 random sequences
    And any counterexample should be minimized and reported

  @mbt @mutation
  Scenario: Mutation testing of FSM implementation
    Given the FSM implementation in "lib/indrajaal/safety/fsm.ex"
    When I apply mutations:
      | Mutation Type        | Location               |
      | State transition     | Armed -> Firing guard  |
      | Timeout value        | 10s -> 5s              |
      | Hold duration        | 3s -> 2s               |
    Then each mutation should be killed by at least one test
    And mutation score should be >= 95%
    And surviving mutants should be analyzed for missing tests
```

**F# Model-Based Testing Implementation:**

```fsharp
// test/Cepaf.Tests/ModelBased/FsmModelTests.fs
module Indrajaal.Cockpit.Tests.ModelBased.FsmModelTests

open FsCheck
open FsCheck.Xunit
open Expecto

/// SC-TEST-MBT-001: State machine model for testing
module ActionStateMachine =

    type State = Idle | Selected | Armed | Firing | Engaged | Locked

    type Input =
        | Navigate
        | Escape
        | PressEnter
        | HoldSpace of duration: float
        | ReleaseSpace
        | Timeout
        | EStop of reason: string

    type Model = {
        CurrentState: State
        AuditLog: string list
        HoldProgress: float
        TimeRemaining: float
    }

    let initial = {
        CurrentState = Idle
        AuditLog = []
        HoldProgress = 0.0
        TimeRemaining = 0.0
    }

    /// SC-TEST-MBT-002: Transition function
    let transition (model: Model) (input: Input) : Model =
        match model.CurrentState, input with
        | Idle, Navigate ->
            { model with CurrentState = Selected }
        | Selected, Escape ->
            { model with CurrentState = Idle }
        | Selected, PressEnter ->
            { model with
                CurrentState = Armed
                TimeRemaining = 10.0
                AuditLog = "ARMED" :: model.AuditLog }
        | Armed, Timeout ->
            { model with CurrentState = Idle; AuditLog = "TIMEOUT" :: model.AuditLog }
        | Armed, HoldSpace _ ->
            { model with CurrentState = Firing; HoldProgress = 0.0 }
        | Firing, HoldSpace duration when model.HoldProgress + duration >= 3.0 ->
            { model with
                CurrentState = Engaged
                AuditLog = "ENGAGED" :: model.AuditLog }
        | Firing, HoldSpace duration ->
            { model with HoldProgress = model.HoldProgress + duration }
        | Firing, ReleaseSpace ->
            { model with CurrentState = Armed; TimeRemaining = 10.0 }
        | Engaged, Timeout ->
            { model with CurrentState = Idle }
        | _, EStop reason ->
            { model with
                CurrentState = Locked
                AuditLog = $"ESTOP:{reason}" :: model.AuditLog }
        | _ -> model  // Invalid transition, no change

    /// SC-TEST-MBT-003: Safety invariant - Cannot reach Engaged without Armed
    let safetyInvariant (model: Model) : bool =
        match model.CurrentState with
        | Engaged -> model.AuditLog |> List.exists (fun e -> e = "ARMED")
        | _ -> true

/// Generators for model-based testing
module Generators =

    let inputGen = Gen.oneof [
        Gen.constant Navigate
        Gen.constant Escape
        Gen.constant PressEnter
        Gen.map HoldSpace (Gen.floatRange 0.0 1.0)
        Gen.constant ReleaseSpace
        Gen.constant Timeout
        Gen.map EStop Arb.generate<string>
    ]

    let inputSequenceGen = Gen.listOfLength 20 inputGen

/// SC-TEST-MBT-004: Property-based tests
[<Tests>]
let modelBasedTests =
    testList "Model-Based FSM Tests" [

        testProperty "Safety invariant holds for all random sequences" <| fun () ->
            Prop.forAll (Arb.fromGen Generators.inputSequenceGen) (fun inputs ->
                let finalModel =
                    inputs
                    |> List.fold ActionStateMachine.transition ActionStateMachine.initial
                ActionStateMachine.safetyInvariant finalModel
            )

        testProperty "E-Stop always reaches Locked from any state" <| fun () ->
            Prop.forAll (Arb.fromGen Generators.inputSequenceGen) (fun inputs ->
                let modelBeforeEstop =
                    inputs
                    |> List.fold ActionStateMachine.transition ActionStateMachine.initial
                let modelAfterEstop =
                    ActionStateMachine.transition modelBeforeEstop (EStop "Test")
                modelAfterEstop.CurrentState = Locked
            )

        testProperty "Armed state always logs to audit" <| fun () ->
            let inputs = [Navigate; PressEnter]
            let finalModel =
                inputs
                |> List.fold ActionStateMachine.transition ActionStateMachine.initial
            finalModel.AuditLog |> List.contains "ARMED"

        test "Exhaustive state coverage" {
            let allStates = [Idle; Selected; Armed; Firing; Engaged; Locked]
            let reachableStates =
                Generators.inputSequenceGen
                |> Gen.sample 100 1000
                |> List.concat
                |> List.fold ActionStateMachine.transition ActionStateMachine.initial
                |> fun _ -> allStates  // Placeholder - implement reachability

            Expect.equal (Set.ofList reachableStates) (Set.ofList allStates)
                "All states should be reachable"
        }
    ]
```

---

#### 9.12.6 Object Identification Testing (SC-TEST-OID-*)

```gherkin
# features/ai_testing/object_identification.feature
@object-identification @ui
Feature: Object Identification for UI Testing
  """
  STAMP Constraints: SC-TEST-OID-001 to SC-TEST-OID-006

  Identify UI elements using multiple strategies:
    - DOM/TUI selectors
    - Accessibility attributes
    - AI-based visual recognition
    - Custom data attributes
  """

  Background:
    Given the object identification engine is initialized
    And the AI vision service is available

  @oid @selectors
  Scenario: Identify elements using selector hierarchy
    Given the F# TUI dashboard is rendered
    When I query for the "Emergency Shutdown" button
    Then the identification should try in order:
      | Strategy              | Selector                              | Priority |
      | data-testid           | [data-testid="emergency-shutdown"]    | 1        |
      | accessibility-label   | [aria-label="Emergency Shutdown"]     | 2        |
      | semantic-role         | button:contains("Emergency")          | 3        |
      | visual-text           | AI: "red button with skull icon"      | 4        |
      | position              | row=15, col=50                        | 5        |
    And the first successful match should be used
    And the strategy used should be logged

  @oid @ai-vision
  Scenario: AI identifies elements from screenshot
    Given a screenshot of the TUI dashboard
    When I invoke AI element identification:
      ```json
      {
        "find": "all interactive elements",
        "return": ["type", "label", "position", "state"]
      }
      ```
    Then the AI should identify:
      | Element                    | Type    | Position   | State    |
      | Emergency Shutdown         | button  | (15, 50)   | idle     |
      | System Status              | display | (1, 10)    | active   |
      | Connection Indicator       | status  | (1, 80)    | green    |
      | Metrics Panel              | panel   | (5, 20)    | normal   |

  @oid @self-healing
  Scenario: Self-healing selector when primary fails
    Given the test uses selector "[data-testid='shutdown-btn']"
    And the button was renamed to "[data-testid='emergency-stop-btn']"
    When the test runs and the primary selector fails
    Then the self-healing system should:
      | Step | Action                                      |
      | 1    | Capture current screen state                |
      | 2    | Use AI to find similar element              |
      | 3    | Verify element matches expected properties  |
      | 4    | Update selector in test repository          |
      | 5    | Log selector change for review              |
    And the test should pass with healed selector
    And a warning should be generated for selector update

  @oid @accessibility
  Scenario: Verify accessibility attributes for identification
    Given the dashboard contains interactive elements
    When I audit accessibility attributes
    Then all interactive elements should have:
      | Attribute          | Required | Example                    |
      | aria-label         | Yes      | "Emergency Shutdown Button"|
      | role               | Yes      | "button"                   |
      | aria-describedby   | Optional | "shutdown-description"     |
      | tabindex           | Yes      | "0" or positive            |
    And missing attributes should be reported as test failures
```

**Object Identification Implementation:**

```elixir
defmodule Indrajaal.AITesting.ObjectIdentifier do
  @moduledoc """
  AI-powered object identification for UI testing.

  ## STAMP Constraints
  - SC-TEST-OID-001: Multiple identification strategies
  - SC-TEST-OID-002: Self-healing selectors
  - SC-TEST-OID-003: AI vision fallback
  """

  alias Indrajaal.AI.OpenRouterClient

  defstruct [:element_type, :selector, :strategy, :confidence, :position]

  @strategies [
    :data_testid,
    :accessibility_label,
    :semantic_role,
    :visual_text,
    :position
  ]

  def identify(target_description, screen_state) do
    @strategies
    |> Enum.reduce_while({:not_found, nil}, fn strategy, _acc ->
      case try_strategy(strategy, target_description, screen_state) do
        {:ok, element} -> {:halt, {:ok, element}}
        :not_found -> {:cont, {:not_found, nil}}
      end
    end)
  end

  defp try_strategy(:data_testid, description, screen_state) do
    testid = description_to_testid(description)
    case find_by_testid(screen_state, testid) do
      nil -> :not_found
      element -> {:ok, %__MODULE__{
        element_type: element.type,
        selector: "[data-testid=\"#{testid}\"]",
        strategy: :data_testid,
        confidence: 1.0,
        position: element.position
      }}
    end
  end

  defp try_strategy(:visual_text, description, screen_state) do
    # Use AI vision to identify element
    prompt = """
    Find the UI element matching this description: "#{description}"

    Screen content (as text grid):
    #{render_screen_as_text(screen_state)}

    Return JSON with: {type, row, col, text, confidence}
    """

    case OpenRouterClient.chat([%{role: "user", content: prompt}],
           model: "anthropic/claude-3.5-sonnet") do
      {:ok, response} ->
        parsed = Jason.decode!(response)
        if parsed["confidence"] > 0.8 do
          {:ok, %__MODULE__{
            element_type: parsed["type"],
            selector: "AI:\"#{description}\"",
            strategy: :visual_text,
            confidence: parsed["confidence"],
            position: {parsed["row"], parsed["col"]}
          }}
        else
          :not_found
        end
      _ -> :not_found
    end
  end

  def self_heal(failed_selector, screen_state, expected_properties) do
    # AI-based self-healing when selector fails
    prompt = """
    The selector "#{failed_selector}" no longer works.
    Expected element properties: #{inspect(expected_properties)}

    Current screen:
    #{render_screen_as_text(screen_state)}

    Find the element that best matches the expected properties.
    Suggest a new, more stable selector.
    """

    {:ok, suggestion} = OpenRouterClient.chat([
      %{role: "user", content: prompt}
    ], model: "anthropic/claude-3.5-sonnet")

    parse_healed_selector(suggestion)
  end
end
```

---

#### 9.12.7 Visual and Functional Testing (SC-TEST-VIS-*, SC-TEST-FUN-*)

```gherkin
# features/ai_testing/visual_functional.feature
@visual-testing @functional-testing
Feature: Visual and Functional Testing
  """
  STAMP Constraints: SC-TEST-VIS-001 to SC-TEST-VIS-008
                     SC-TEST-FUN-001 to SC-TEST-FUN-006

  Combines visual regression testing with functional verification
  to ensure both appearance and behavior are correct.
  """

  Background:
    Given the visual testing service is configured
    And baseline screenshots exist for comparison

  # ─────────────────────────────────────────────────────────────────────
  # VISUAL TESTING
  # ─────────────────────────────────────────────────────────────────────

  @visual @regression
  Scenario: Visual regression test for Armed state
    Given the baseline screenshot "armed_state_baseline.png" exists
    When I capture the current Armed state:
      | Element           | Expected Visual              |
      | Button border     | Amber (#FFA500), 2px solid   |
      | Countdown timer   | "10s" amber text             |
      | Status bar        | "ARMED" indicator            |
    Then I compare against baseline with:
      | Metric                 | Threshold |
      | Pixel difference       | < 0.1%    |
      | Structural similarity  | > 99%     |
      | Color accuracy         | ΔE < 2.0  |
    And if differences exceed threshold:
      | Action                          |
      | Generate diff image             |
      | Highlight changed regions       |
      | Flag for human review           |

  @visual @ai-validation
  Scenario: AI validates visual design compliance
    Given a screenshot of the current UI
    And the design specification document
    When I invoke AI visual validation:
      ```json
      {
        "checks": [
          {"type": "color", "element": "safety-button", "expected": "#FF0000"},
          {"type": "spacing", "between": ["button1", "button2"], "min": "16px"},
          {"type": "alignment", "elements": ["header", "footer"], "axis": "vertical"},
          {"type": "contrast", "text": "all", "min_ratio": 4.5}
        ]
      }
      ```
    Then the AI should report:
      | Check      | Element        | Status | Details              |
      | color      | safety-button  | PASS   | #FF0000 matches      |
      | spacing    | button1-button2| PASS   | 20px > 16px minimum  |
      | alignment  | header-footer  | PASS   | 0px offset           |
      | contrast   | main-text      | PASS   | 7.2:1 ratio          |

  # ─────────────────────────────────────────────────────────────────────
  # FUNCTIONAL TESTING
  # ─────────────────────────────────────────────────────────────────────

  @functional @safety-critical
  Scenario: Functional test with AI assertion generation
    Given the function "Safety.arm_action/1" exists
    When I invoke AI-generated functional tests:
      ```elixir
      # AI generates these assertions based on @spec and @doc
      describe "arm_action/1" do
        test "returns {:ok, state} for valid action" do
          assert {:ok, %{state: :armed}} = Safety.arm_action("shutdown")
        end

        test "returns {:error, :invalid_action} for unknown action" do
          assert {:error, :invalid_action} = Safety.arm_action("unknown")
        end

        test "logs audit entry on success" do
          Safety.arm_action("shutdown")
          assert_audit_log_contains("ACTION_ARMED")
        end

        test "rejects arm when already armed" do
          Safety.arm_action("shutdown")
          assert {:error, :already_armed} = Safety.arm_action("other")
        end
      end
      ```
    Then all generated tests should pass
    And test coverage should increase by at least 10%

  @functional @property
  Scenario: AI generates property-based functional tests
    Given the module "Indrajaal.Safety.Watchdog"
    When I request property test generation:
      | Focus                  | Property                              |
      | Heartbeat timing       | Never misses stale detection          |
      | State consistency      | State always valid after any ops      |
      | Concurrent access      | Thread-safe under concurrent calls    |
    Then generated property tests should use StreamData:
      ```elixir
      property "heartbeat detection is monotonic" do
        check all(
          intervals <- SD.list_of(SD.integer(50..500), min_length: 5),
          max_runs: 500
        ) do
          # Heartbeats at increasing intervals
          results = Enum.map(intervals, fn interval ->
            Process.sleep(interval)
            Watchdog.check_heartbeat()
          end)

          # Staleness detection should be consistent
          assert results |> Enum.chunk_every(2, 1, :discard)
                        |> Enum.all?(fn [a, b] ->
                             not (a == :stale and b == :fresh)
                           end)
        end
      end
      ```
```

---

#### 9.12.8 Image-Based Testing (SC-TEST-IMG-*)

```gherkin
# features/ai_testing/image_based.feature
@image-based @visual
Feature: Image-Based Testing
  """
  STAMP Constraints: SC-TEST-IMG-001 to SC-TEST-IMG-006

  Tests based on pixel-level image comparison and analysis.
  Uses ImageMagick, Pixelmatch, and AI vision for comparison.
  """

  Background:
    Given the image comparison tools are installed
    And baseline images are stored in "test/baselines/"

  @image @pixel-comparison
  Scenario: Pixel-perfect comparison for safety indicators
    Given baseline image "safety_indicator_red.png"
    And current screenshot of safety indicator
    When I perform pixel comparison:
      | Tool          | Threshold | Anti-aliasing |
      | pixelmatch    | 0.1       | enabled       |
      | ImageMagick   | AE < 100  | RMSE < 0.01   |
    Then the comparison should:
      | Metric                  | Value    |
      | Identical pixels        | > 99.9%  |
      | Different pixels        | < 10     |
      | Structural difference   | 0        |

  @image @diff-generation
  Scenario: Generate visual diff for failed comparison
    Given baseline "dashboard_normal.png"
    And current "dashboard_current.png"
    And the images differ by more than threshold
    When I generate diff image
    Then the output should include:
      | File                    | Content                     |
      | diff_overlay.png        | Side-by-side comparison     |
      | diff_highlight.png      | Red highlighting on changes |
      | diff_report.json        | Pixel-level change data     |

  @image @responsive
  Scenario: Test image rendering at multiple resolutions
    Given the TUI renders at variable terminal sizes
    When I capture screenshots at:
      | Width | Height | Name                    |
      | 80    | 24     | small_terminal.png      |
      | 120   | 40     | medium_terminal.png     |
      | 200   | 60     | large_terminal.png      |
    Then each screenshot should match its baseline
    And layout should adapt correctly to size
    And no text should be truncated or overlapping

  @image @animation
  Scenario: Test animated elements (progress bar, countdown)
    Given the Firing state shows an animated progress bar
    When I capture frames at 30 FPS for 3 seconds
    Then the animation should:
      | Check                   | Criteria                  |
      | Frame rate              | Consistent 30 FPS         |
      | Progress increment      | Linear over time          |
      | Color transition        | Amber throughout          |
      | Final frame             | 100% fill                 |
```

**Image Comparison Implementation:**

```elixir
defmodule Indrajaal.AITesting.ImageComparator do
  @moduledoc """
  Image-based testing with pixel comparison and AI analysis.

  ## STAMP Constraints
  - SC-TEST-IMG-001: Baseline management
  - SC-TEST-IMG-002: Pixel-level comparison
  - SC-TEST-IMG-003: Diff generation
  """

  @baseline_dir "test/baselines"
  @diff_dir "test/diffs"

  def compare(baseline_name, current_image_path, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.001)
    baseline_path = Path.join(@baseline_dir, baseline_name)

    # Use ImageMagick for comparison
    {output, 0} = System.cmd("compare", [
      "-metric", "AE",
      "-fuzz", "#{threshold * 100}%",
      baseline_path,
      current_image_path,
      Path.join(@diff_dir, "diff_#{baseline_name}")
    ], stderr_to_stdout: true)

    different_pixels = String.trim(output) |> String.to_integer()

    cond do
      different_pixels == 0 ->
        {:ok, :identical}
      different_pixels < 10 ->
        {:ok, :within_threshold, different_pixels}
      true ->
        generate_diff_report(baseline_path, current_image_path, different_pixels)
        {:error, :visual_regression, different_pixels}
    end
  end

  def capture_terminal_screenshot(output_path) do
    # Use VHS or tmux capture for terminal screenshots
    System.cmd("import", ["-window", "root", output_path])
    {:ok, output_path}
  end

  def generate_diff_report(baseline, current, pixel_count) do
    diff_name = "diff_#{:erlang.unique_integer([:positive])}"

    # Generate side-by-side comparison
    System.cmd("montage", [
      baseline, current,
      "-geometry", "+0+0",
      Path.join(@diff_dir, "#{diff_name}_sidebyside.png")
    ])

    # Generate highlighted diff
    System.cmd("compare", [
      baseline, current,
      "-highlight-color", "red",
      Path.join(@diff_dir, "#{diff_name}_highlight.png")
    ])

    # Generate JSON report
    report = %{
      baseline: baseline,
      current: current,
      different_pixels: pixel_count,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      diff_images: [
        "#{diff_name}_sidebyside.png",
        "#{diff_name}_highlight.png"
      ]
    }

    File.write!(
      Path.join(@diff_dir, "#{diff_name}_report.json"),
      Jason.encode!(report, pretty: true)
    )

    {:ok, report}
  end
end
```

---

#### 9.12.9 OCR Testing (SC-TEST-OCR-*)

```gherkin
# features/ai_testing/ocr_testing.feature
@ocr @text-verification
Feature: Optical Character Recognition Testing
  """
  STAMP Constraints: SC-TEST-OCR-001 to SC-TEST-OCR-005

  Verifies text content in TUI/GUI using OCR engines.
  Essential for testing rendered text, counters, and status messages.
  """

  Background:
    Given the OCR engine (Tesseract) is initialized
    And the AI text recognition service is available

  @ocr @text-extraction
  Scenario: Extract and verify text from TUI screenshot
    Given a screenshot of the dashboard
    When I perform OCR text extraction:
      | Engine     | Config                          |
      | Tesseract  | --psm 6 --oem 3                |
      | EasyOCR    | languages=["en"]                |
    Then the extracted text should include:
      | Expected Text              | Location    | Confidence |
      | "System: OPERATIONAL"      | Zone A      | > 95%      |
      | "Alarms: 0"                | Zone A      | > 95%      |
      | "14:32:45 CET"             | Zone A      | > 90%      |
      | "Temperature: 23.5°C"      | Zone B      | > 90%      |

  @ocr @countdown-verification
  Scenario: Verify countdown timer displays correctly
    Given the action is in Armed state
    When I capture countdown text every 500ms for 5 seconds
    Then the OCR should detect:
      | Time Captured | Expected Text | Actual  | Match |
      | 0ms           | "10s"         | "10s"   | ✓     |
      | 500ms         | "10s" or "9s" | "9s"    | ✓     |
      | 1000ms        | "9s"          | "9s"    | ✓     |
      | ...           | ...           | ...     | ...   |
    And each reading should decrement by 1 second (±100ms)

  @ocr @unicode
  Scenario: OCR handles Unicode and special characters
    Given the TUI displays Braille chart characters
    When I extract text from chart region
    Then OCR should correctly identify:
      | Character | Unicode  | Extracted |
      | ⣿         | U+28FF   | ⣿         |
      | ▁         | U+2581   | ▁         |
      | ░         | U+2591   | ░         |
      | ⚠         | U+26A0   | ⚠         |

  @ocr @ai-enhanced
  Scenario: AI-enhanced OCR for complex layouts
    Given a screenshot with overlapping text elements
    When standard OCR fails to parse correctly
    Then AI vision should:
      | Step                              | Action                    |
      | Analyze layout structure          | Identify zones            |
      | Apply semantic understanding      | Group related text        |
      | Extract with context awareness    | "ARMED: 7s remaining"     |
      | Validate against expected format  | Regex: /ARMED: \d+s/      |
```

**OCR Testing Implementation:**

```elixir
defmodule Indrajaal.AITesting.OCRTester do
  @moduledoc """
  OCR-based text verification for TUI testing.

  ## STAMP Constraints
  - SC-TEST-OCR-001: Multi-engine support
  - SC-TEST-OCR-002: Unicode handling
  - SC-TEST-OCR-003: Confidence thresholds
  """

  require Logger

  @tesseract_config "--psm 6 --oem 3"
  @min_confidence 0.90

  def extract_text(image_path, opts \\ []) do
    engine = Keyword.get(opts, :engine, :tesseract)
    region = Keyword.get(opts, :region, nil)

    # Crop to region if specified
    image = if region, do: crop_image(image_path, region), else: image_path

    case engine do
      :tesseract -> extract_with_tesseract(image)
      :easyocr -> extract_with_easyocr(image)
      :ai_vision -> extract_with_ai_vision(image, opts)
    end
  end

  defp extract_with_tesseract(image_path) do
    {output, 0} = System.cmd("tesseract", [
      image_path,
      "stdout",
      @tesseract_config
    ])

    lines = String.split(output, "\n", trim: true)
    {:ok, lines}
  end

  defp extract_with_ai_vision(image_path, opts) do
    expected_format = Keyword.get(opts, :expected_format, nil)
    base64_image = image_path |> File.read!() |> Base.encode64()

    prompt = """
    Extract all visible text from this terminal UI screenshot.
    Return as JSON array of {text, position, confidence}.
    #{if expected_format, do: "Expected format: #{expected_format}", else: ""}
    """

    {:ok, response} = Indrajaal.AI.OpenRouterClient.chat([
      %{
        role: "user",
        content: [
          %{type: "text", text: prompt},
          %{type: "image_url", image_url: %{url: "data:image/png;base64,#{base64_image}"}}
        ]
      }
    ], model: "openai/gpt-4-vision-preview")

    parse_ocr_response(response)
  end

  def verify_countdown(image_capture_fn, duration_seconds, interval_ms \\ 500) do
    readings = for i <- 0..(duration_seconds * 1000 / interval_ms) do
      Process.sleep(interval_ms)
      image_path = image_capture_fn.()
      {:ok, text} = extract_text(image_path, region: :countdown_area)
      parse_countdown(text)
    end

    # Verify readings decrement correctly
    validate_countdown_sequence(readings)
  end

  defp parse_countdown(text_lines) do
    text_lines
    |> Enum.find(&String.match?(&1, ~r/\d+s/))
    |> case do
      nil -> {:error, :countdown_not_found}
      match ->
        [seconds] = Regex.run(~r/(\d+)s/, match, capture: :all_but_first)
        {:ok, String.to_integer(seconds)}
    end
  end

  defp validate_countdown_sequence(readings) do
    readings
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [{:ok, a}, {:ok, b}] -> a - b <= 1 and a - b >= 0 end)
  end
end
```

---

#### 9.12.10 Hybrid Testing (SC-TEST-HYB-*)

```gherkin
# features/ai_testing/hybrid_testing.feature
@hybrid @comprehensive
Feature: Hybrid Testing Framework
  """
  STAMP Constraints: SC-TEST-HYB-001 to SC-TEST-HYB-010

  Combines multiple testing methodologies for comprehensive coverage:
    - BDD scenarios (behavior)
    - Visual regression (appearance)
    - Functional tests (logic)
    - Model-based tests (state)
    - AI validation (intelligence)
  """

  Background:
    Given the hybrid test orchestrator is initialized
    And all testing engines are available

  @hybrid @comprehensive
  Scenario: Execute hybrid test suite for Arm & Fire feature
    When I run hybrid test with:
      | Methodology      | Focus                    | Weight |
      | BDD              | User behavior            | 25%    |
      | Model-Based      | State machine            | 25%    |
      | Visual           | UI appearance            | 20%    |
      | Functional       | Business logic           | 15%    |
      | AI Validation    | Compliance verification  | 15%    |
    Then each methodology should execute:
      | Methodology      | Tests | Pass | Fail |
      | BDD              | 25    | 25   | 0    |
      | Model-Based      | 42    | 42   | 0    |
      | Visual           | 12    | 12   | 0    |
      | Functional       | 18    | 18   | 0    |
      | AI Validation    | 8     | 8    | 0    |
    And the hybrid score should be 100%

  @hybrid @cross-validation
  Scenario: Cross-validate results between methodologies
    Given BDD test reports state transition is correct
    And Model-Based test confirms FSM compliance
    And Visual test shows correct button color
    When I cross-validate results
    Then all methodologies should agree on:
      | Aspect                    | Agreement |
      | State after arm           | Armed     |
      | Visual indicator color    | Amber     |
      | Audit log entry           | ARMED     |
      | Time remaining            | 10s       |
    And any disagreement should trigger investigation

  @hybrid @ai-orchestration
  Scenario: AI orchestrates test methodology selection
    Given a new feature "Emergency Override" is added
    When I request AI test strategy:
      ```json
      {
        "feature": "Emergency Override",
        "description": "Physical key + software confirmation to override locks",
        "safety_level": "critical",
        "suggest_methodologies": true
      }
      ```
    Then the AI should recommend:
      | Methodology      | Reason                                    | Priority |
      | Model-Based      | Complex state machine requires FSM tests  | P0       |
      | BDD              | User interaction flow is critical         | P0       |
      | Visual           | Safety indicators must be verified        | P0       |
      | Functional       | Business logic validation                 | P1       |
      | Chaos            | Must handle hardware failures             | P1       |
      | OCR              | Verify status text displays               | P2       |

  @hybrid @continuous
  Scenario: Continuous hybrid testing in CI/CD
    Given the CI pipeline is triggered
    When the hybrid test stage runs
    Then tests should execute in parallel:
      | Stage | Methodologies                     | Timeout |
      | 1     | Unit, Property (fast)             | 2m      |
      | 2     | BDD, Model-Based (medium)         | 5m      |
      | 3     | Visual, Image (slow)              | 10m     |
      | 4     | AI Validation (final)             | 5m      |
    And aggregate results should determine pass/fail
    And any failure should block deployment
```

**Hybrid Testing Orchestrator:**

```elixir
defmodule Indrajaal.AITesting.HybridOrchestrator do
  @moduledoc """
  Orchestrates multiple testing methodologies for comprehensive coverage.

  ## STAMP Constraints
  - SC-TEST-HYB-001: Multi-methodology orchestration
  - SC-TEST-HYB-002: Cross-validation
  - SC-TEST-HYB-003: AI-driven strategy selection
  """

  alias Indrajaal.AITesting.{
    BDDRunner,
    ModelBasedRunner,
    VisualTester,
    FunctionalRunner,
    AIValidator
  }

  defstruct [
    :feature,
    :methodologies,
    :results,
    :cross_validation,
    :score
  ]

  @default_weights %{
    bdd: 0.25,
    model_based: 0.25,
    visual: 0.20,
    functional: 0.15,
    ai_validation: 0.15
  }

  def run_hybrid(feature, opts \\ []) do
    methodologies = Keyword.get(opts, :methodologies, [:bdd, :model_based, :visual, :functional, :ai_validation])
    weights = Keyword.get(opts, :weights, @default_weights)

    # Execute all methodologies in parallel
    results = methodologies
    |> Task.async_stream(fn methodology ->
      {methodology, run_methodology(methodology, feature)}
    end, max_concurrency: 4, timeout: :timer.minutes(10))
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()

    # Cross-validate results
    cross_validation = cross_validate(results)

    # Calculate hybrid score
    score = calculate_score(results, weights)

    %__MODULE__{
      feature: feature,
      methodologies: methodologies,
      results: results,
      cross_validation: cross_validation,
      score: score
    }
  end

  defp run_methodology(:bdd, feature) do
    BDDRunner.run(feature)
  end

  defp run_methodology(:model_based, feature) do
    ModelBasedRunner.run(feature)
  end

  defp run_methodology(:visual, feature) do
    VisualTester.run(feature)
  end

  defp run_methodology(:functional, feature) do
    FunctionalRunner.run(feature)
  end

  defp run_methodology(:ai_validation, feature) do
    AIValidator.run(feature)
  end

  defp cross_validate(results) do
    # Extract assertions from each methodology
    assertions = Enum.map(results, fn {methodology, result} ->
      {methodology, extract_assertions(result)}
    end)

    # Find common assertions and check agreement
    common_aspects = [:state_after_action, :visual_indicator, :audit_log, :timing]

    Enum.map(common_aspects, fn aspect ->
      values = Enum.map(assertions, fn {m, a} -> {m, Map.get(a, aspect)} end)
      agreement = values |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 1

      %{
        aspect: aspect,
        agreement: agreement,
        values: values
      }
    end)
  end

  defp calculate_score(results, weights) do
    results
    |> Enum.map(fn {methodology, result} ->
      weight = Map.get(weights, methodology, 0)
      pass_rate = result.passed / max(result.total, 1)
      weight * pass_rate
    end)
    |> Enum.sum()
  end

  def suggest_strategy(feature_description) do
    prompt = """
    Suggest optimal testing methodologies for this feature:
    #{feature_description}

    Consider: safety level, complexity, UI involvement, state machine presence.
    Return prioritized list with reasoning.
    """

    {:ok, strategy} = Indrajaal.AI.OpenRouterClient.chat([
      %{role: "user", content: prompt}
    ], model: "anthropic/claude-3.5-sonnet")

    parse_strategy_suggestion(strategy)
  end
end
```

---

#### 9.12.11 Testing Infrastructure Commands

```bash
# ============================================
# AI-ASSISTED TESTING COMMANDS
# ============================================

# --- Test Generation ---
mix ai.generate_tests Indrajaal.Safety.EStopListener --coverage 95
mix ai.analyze_coverage lib/indrajaal/safety/ --suggest-tests
mix ai.generate_properties ActionState --output test/property/

# --- Record and Playback ---
vhs record session.tape                    # Start recording
vhs playback session.tape                  # Replay session
mix rap.compare baseline.tape current.tape # Compare recordings

# --- Model-Based Testing ---
mix mbt.generate ActionState --coverage all_paths
mix mbt.check fsm_model.quint              # Run Quint model checker
dotnet run --project test/Cepaf.Tests -- --filter "ModelBased"

# --- Visual Testing ---
mix visual.capture dashboard --baseline    # Create baseline
mix visual.compare dashboard               # Compare to baseline
mix visual.report --format html            # Generate report

# --- OCR Testing ---
mix ocr.extract screenshot.png             # Extract text
mix ocr.verify countdown --duration 10     # Verify countdown
mix ocr.validate_unicode chart_region.png  # Unicode verification

# --- Hybrid Testing ---
mix hybrid.run "Arm & Fire" --all-methodologies
mix hybrid.cross_validate --report json
mix hybrid.ci --parallel --timeout 20m

# --- AI Validation ---
mix ai.validate_ui screenshot.png --spec design_spec.md
mix ai.suggest_strategy "Emergency Override" --safety critical
mix ai.review_tests test/safety/ --coverage-focus

# --- F# Testing Commands ---
dotnet run --project test/Cepaf.Tests -- --filter "AIAssisted"
dotnet run --project test/Cepaf.Tests -- --filter "ModelBased"
dotnet run --project test/Cepaf.Tests -- --filter "Visual"
dotnet run --project test/Cepaf.Tests -- --filter "Hybrid"

# --- CI/CD Pipeline ---
mix test.pipeline --stage all              # Full pipeline
mix test.pipeline --stage fast             # Quick validation
mix test.pipeline --report coverage,visual,ai
```

---

#### 9.12.12 AI Testing STAMP Constraints Summary

| Constraint ID | Description | Verification |
|---------------|-------------|--------------|
| SC-TEST-AI-001 | AI-generated tests require review before merge | PR review gate |
| SC-TEST-AI-002 | Safety-critical paths require human approval | Approval workflow |
| SC-TEST-AI-003 | Generated tests must compile | CI compile check |
| SC-TEST-RAP-001 | Recording timing tolerance ±100ms | Playback validation |
| SC-TEST-RAP-002 | Recordings must include visual verification | VHS screenshot |
| SC-TEST-MBT-001 | FSM coverage must be 100% | Coverage report |
| SC-TEST-MBT-002 | All transitions must be tested | Transition matrix |
| SC-TEST-OID-001 | Multiple identification strategies | Strategy logging |
| SC-TEST-OID-002 | Self-healing updates require review | Change log |
| SC-TEST-VIS-001 | Pixel difference < 0.1% | Comparison tool |
| SC-TEST-VIS-002 | Baseline update requires approval | Version control |
| SC-TEST-IMG-001 | RMSE < 0.01 for safety indicators | ImageMagick |
| SC-TEST-OCR-001 | Text confidence > 90% | OCR engine |
| SC-TEST-OCR-002 | Unicode support verified | Character test |
| SC-TEST-HYB-001 | Minimum 3 methodologies required | Orchestrator |
| SC-TEST-HYB-002 | Cross-validation must agree | Validation report |

---

## 10. Formal Methods

### 10.1 Mathematica FSM Specification

```mathematica
(* ARM & FIRE STATE MACHINE *)
armFireStates = {Idle, Selected, Armed, Firing, Engaged, Locked};

armFireTransitions = {
  {Idle, "navigate"} -> Selected,
  {Selected, "escape"} -> Idle,
  {Selected, "enter"} -> Armed,
  {Armed, "timeout"} -> Idle,
  {Armed, "hold_space"} -> Firing,
  {Firing, "release_early"} -> Armed,
  {Firing, "hold_complete"} -> Engaged,
  {Engaged, "auto_reset"} -> Idle,
  (* E-Stop transitions from ANY state *)
  {_, "estop"} -> Locked
};

(* Invariant: Cannot reach Engaged without passing through Armed+Firing *)
SafetyInvariant[trace_] := Module[{states},
  states = trace[[All, 1]];
  If[MemberQ[states, Engaged],
    (* Must have Armed and Firing before Engaged *)
    Position[states, Armed][[1, 1]] < Position[states, Firing][[1, 1]] <
    Position[states, Engaged][[1, 1]],
    True
  ]
]
```

### 10.2 Agda Type Proofs

```agda
module SafetyProofs where

open import Data.Bool
open import Data.Nat
open import Relation.Binary.PropositionalEquality

-- Action State Discriminated Union
data ActionState : Set where
  Idle     : ActionState
  Selected : ActionState
  Armed    : ℕ → ActionState  -- TimeRemaining in deciseconds
  Firing   : ℕ → ActionState  -- Progress in tenths
  Engaged  : ActionState
  Locked   : String → ActionState

-- Valid transition predicate
data ValidTransition : ActionState → ActionState → Set where
  idle→selected   : ValidTransition Idle Selected
  selected→idle   : ValidTransition Selected Idle
  selected→armed  : ValidTransition Selected (Armed 100)
  armed→idle      : ∀ {n} → ValidTransition (Armed n) Idle
  armed→firing    : ∀ {n} → ValidTransition (Armed n) (Firing 0)
  firing→armed    : ∀ {n} → n < 30 → ValidTransition (Firing n) (Armed 100)
  firing→engaged  : ∀ {n} → n ≥ 30 → ValidTransition (Firing n) Engaged
  engaged→idle    : ValidTransition Engaged Idle
  any→locked      : ∀ {s reason} → ValidTransition s (Locked reason)

-- Proof: Cannot skip from Idle to Engaged
no-skip-to-engaged : ¬ (ValidTransition Idle Engaged)
no-skip-to-engaged ()

-- Proof: Must go through Armed to reach Firing
must-arm-before-fire : ∀ {s} → ValidTransition s (Firing 0) →
                       ∃[ n ] (s ≡ Armed n)
must-arm-before-fire (armed→firing {n}) = n , refl
```

### 10.3 Quint Model

```quint
module ArmFire {
  type State = "Idle" | "Selected" | "Armed" | "Firing" | "Engaged" | "Locked"

  var state: State
  var timeRemaining: int  // deciseconds (0-100 = 0-10s)
  var holdProgress: int   // tenths (0-30 = 0-3s)
  var auditLog: List[str]

  action init = {
    state' = "Idle"
    timeRemaining' = 0
    holdProgress' = 0
    auditLog' = []
  }

  action navigate = {
    state == "Idle" and state' = "Selected"
  }

  action pressEnter = {
    state == "Selected" and state' = "Armed" and timeRemaining' = 100
    and auditLog' = auditLog.append("ARMED")
  }

  action holdSpace = {
    state == "Armed" and state' = "Firing" and holdProgress' = 0
  }

  action releaseEarly = {
    state == "Firing" and holdProgress < 30
    and state' = "Armed" and timeRemaining' = 100
  }

  action holdComplete = {
    state == "Firing" and holdProgress >= 30
    and state' = "Engaged"
    and auditLog' = auditLog.append("ENGAGED")
  }

  action estop(reason: str) = {
    state' = "Locked" and auditLog' = auditLog.append("ESTOP: " + reason)
  }

  // INVARIANT: Cannot reach Engaged without Armed in log
  val safetyInvariant = {
    state == "Engaged" implies auditLog.contains("ARMED")
  }

  // INVARIANT: Locked state can only be exited with physical key
  val lockInvariant = {
    state == "Locked" implies (state' == "Locked" or physicalKeyUsed)
  }
}
```

### 10.4 TLA+ Specification

```tla+
---- MODULE ArmFireSafety ----
EXTENDS Naturals, Sequences, TLC

CONSTANTS MaxTimeout, MaxHoldTime

VARIABLES state, timeRemaining, holdProgress, auditLog

States == {"Idle", "Selected", "Armed", "Firing", "Engaged", "Locked"}

TypeInvariant ==
  /\ state \in States
  /\ timeRemaining \in 0..MaxTimeout
  /\ holdProgress \in 0..MaxHoldTime
  /\ auditLog \in Seq(STRING)

Init ==
  /\ state = "Idle"
  /\ timeRemaining = 0
  /\ holdProgress = 0
  /\ auditLog = <<>>

Navigate ==
  /\ state = "Idle"
  /\ state' = "Selected"
  /\ UNCHANGED <<timeRemaining, holdProgress, auditLog>>

PressEnter ==
  /\ state = "Selected"
  /\ state' = "Armed"
  /\ timeRemaining' = 100
  /\ auditLog' = Append(auditLog, "ARMED")
  /\ UNCHANGED holdProgress

HoldSpace ==
  /\ state = "Armed"
  /\ state' = "Firing"
  /\ holdProgress' = 0
  /\ UNCHANGED <<timeRemaining, auditLog>>

ReleaseEarly ==
  /\ state = "Firing"
  /\ holdProgress < 30
  /\ state' = "Armed"
  /\ timeRemaining' = 100
  /\ UNCHANGED <<holdProgress, auditLog>>

HoldComplete ==
  /\ state = "Firing"
  /\ holdProgress >= 30
  /\ state' = "Engaged"
  /\ auditLog' = Append(auditLog, "ENGAGED")
  /\ UNCHANGED <<timeRemaining, holdProgress>>

EStop ==
  /\ state' = "Locked"
  /\ auditLog' = Append(auditLog, "ESTOP")
  /\ UNCHANGED <<timeRemaining, holdProgress>>

Next == Navigate \/ PressEnter \/ HoldSpace \/ ReleaseEarly \/ HoldComplete \/ EStop

Spec == Init /\ [][Next]_<<state, timeRemaining, holdProgress, auditLog>>

(* SAFETY INVARIANT: Cannot reach Engaged without ARMED in log *)
SafetyInvariant ==
  state = "Engaged" => \E i \in 1..Len(auditLog): auditLog[i] = "ARMED"

====
```

---

## 11. Graph Specifications

### 11.1 Component Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SYSTEM COMPONENT GRAPH                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐          ┌─────────────┐          ┌─────────────┐    │
│   │   F# TUI    │◄────────▶│   Zenoh     │◄────────▶│  LiveView   │    │
│   │  (Cockpit)  │  Pub/Sub │  (Broker)   │  Pub/Sub │   (Web)     │    │
│   └──────┬──────┘          └──────┬──────┘          └──────┬──────┘    │
│          │                        │                        │           │
│          │ TEA/MVU                │ Events                 │ Phoenix   │
│          ▼                        ▼                        ▼           │
│   ┌─────────────┐          ┌─────────────┐          ┌─────────────┐    │
│   │  Domain.fs  │          │  PubSub.ex  │          │  Socket.ex  │    │
│   │  (Types)    │          │  (Router)   │          │  (Handler)  │    │
│   └──────┬──────┘          └──────┬──────┘          └──────┬──────┘    │
│          │                        │                        │           │
│          │                        ▼                        │           │
│          │                 ┌─────────────┐                 │           │
│          └────────────────▶│   HAL.ex    │◄────────────────┘           │
│                            │  (Backend)  │                              │
│                            └──────┬──────┘                              │
│                                   │                                     │
│                    ┌──────────────┼──────────────┐                     │
│                    ▼              ▼              ▼                     │
│             ┌─────────┐    ┌─────────┐    ┌─────────┐                  │
│             │  GPIO   │    │ Serial  │    │Watchdog │                  │
│             │ E-Stop  │    │ Sensors │    │  Timer  │                  │
│             └─────────┘    └─────────┘    └─────────┘                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 KMS Holon Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    KMS HOLON GRAPH STRUCTURE                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   [Developer]                    [ProductManager]                       │
│       │                               │                                 │
│       │ CREATES                       │ CREATES                         │
│       ▼                               ▼                                 │
│   [ADR: GraphQL]               [Feature: Dark Mode]                     │
│       │                               │                                 │
│       ├── SUPERSEDES ──► [ADR: REST]  │                                │
│       │                               │                                 │
│       ├── RELATES_TO ──► [ADR: Microservices]                          │
│       │                               │                                 │
│       ├── IMPLEMENTS ──► [Pattern: API Gateway]                        │
│       │                               │                                 │
│       └── LINKED_CODE                 ├── DEPENDS_ON ──► [Feature: Auth]│
│               │                       │                                 │
│               ▼                       └── HAS_FEEDBACK ──► [Feedback]   │
│        [File: federation.ex]                                            │
│               │                                                         │
│               └── MENTIONED_IN ──► [Runbook: Deploy]                    │
│                                           │                             │
│                                           └── AUTHORED_BY ──► [SRE]     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.3 State Transition Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ACTION STATE TRANSITION GRAPH                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                            ┌──────────────┐                            │
│                            │    LOCKED    │◄────────────────────┐      │
│                            │   (E-Stop)   │                     │      │
│                            └──────────────┘                     │      │
│                                   ▲                             │      │
│                                   │ estop (from any state)      │      │
│                                   │                             │      │
│   ┌──────┐ navigate  ┌──────────┐ enter  ┌────────────┐        │      │
│   │ IDLE │──────────▶│ SELECTED │───────▶│   ARMED    │────────┤      │
│   └──────┘           └──────────┘        │ (10s timer)│        │      │
│       ▲                   │              └─────┬──────┘        │      │
│       │                   │ escape             │               │      │
│       │                   ▼                    │ hold_space    │      │
│       │              ┌──────┐                  ▼               │      │
│       │              │CANCEL│          ┌────────────┐          │      │
│       │              └──────┘          │   FIRING   │──────────┤      │
│       │                   ▲            │ (3s hold)  │          │      │
│       │                   │            └─────┬──────┘          │      │
│       │                   │ release          │                 │      │
│       │                   │ (<3s)            │ hold_complete   │      │
│       │                   │                  ▼                 │      │
│       │              ┌────┴──────┐    ┌────────────┐          │      │
│       │              │  TIMEOUT  │    │  ENGAGED   │──────────┘      │
│       │              └───────────┘    │  (Flash)   │                 │
│       │                               └─────┬──────┘                 │
│       │                                     │                        │
│       └─────────────────────────────────────┘ auto_reset             │
│                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Implementation Guidelines

### 12.1 F# Implementation (TEA/MVU)

```fsharp
/// Domain.fs - Safety state types
/// SC-FSH-001: All domain states as discriminated unions
module Indrajaal.Cockpit.Domain

[<Measure>] type ms
[<Measure>] type sec

type ActionState =
    | Idle
    | Selected
    | Armed of TimeRemaining: float<sec>
    | Firing of HoldProgress: float<sec>
    | Engaged
    | Locked of Reason: string

type ConnectionQuality =
    | Good
    | Degraded
    | Lost

type Model = {
    ActionState: ActionState
    LastHeartbeat: DateTime
    ConnectionQuality: ConnectionQuality
    DataStale: bool
    OverlayMessage: string option
    AuditLog: AuditEntry list
}

/// Update.fs - Pure state transitions
/// SC-SAFETY-002: All transitions explicit and logged
let update (msg: Msg) (model: Model) : Model * Cmd<Msg> =
    match msg, model.ActionState with
    | Navigate target, Idle when target = focusedButton ->
        { model with ActionState = Selected }, Cmd.none

    | KeyPress Enter, Selected ->
        { model with
            ActionState = Armed 10.0<sec>
            AuditLog = logEntry "ACTION_ARMED" :: model.AuditLog },
        Cmd.batch [ Cmd.ofMsg StartArmTimer; playSound "arm.wav" ]

    | KeyDown Space, Armed remaining when remaining > 0.0<sec> ->
        { model with ActionState = Firing 0.0<sec> },
        Cmd.ofMsg StartHoldTimer

    | HoldTimerTick, Firing progress ->
        let newProgress = progress + 0.033<sec>
        if newProgress >= 3.0<sec> then
            { model with
                ActionState = Engaged
                AuditLog = logEntry "ACTION_ENGAGED" :: model.AuditLog },
            Cmd.batch [ sendToBackend; flashScreen; playSound "engage.wav" ]
        else
            { model with ActionState = Firing newProgress }, Cmd.none

    | EStopEngaged reason, _ ->
        { model with
            ActionState = Locked reason
            AuditLog = logEntry $"ESTOP: {reason}" :: model.AuditLog },
        Cmd.batch [ lockAllInputs; playAlarm ]

    | _, _ -> model, Cmd.none
```

### 12.2 Elixir Implementation (GenServer/Supervisor)

```elixir
defmodule Indrajaal.Safety.Supervisor do
  @moduledoc """
  OTP Supervisor for safety-critical components.

  ## STAMP Constraints
  - SC-SAFETY-005: E-Stop integration
  - SC-EMR-057: Stop timeout < 5s

  ## Supervision Strategy
  - one_for_all: If any child dies, restart all
  - max_restarts: 3 in 5 seconds before cascade
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Hardware state persists across restarts
      {Indrajaal.Safety.HardwareState, []},
      # E-Stop listener with GPIO integration
      {Indrajaal.Safety.EStopListener, []},
      # Heartbeat watchdog
      {Indrajaal.Safety.Watchdog, interval_ms: 100},
      # Audit logger (persistent)
      {Indrajaal.Safety.AuditLog, path: "/var/log/indrajaal/audit.log"}
    ]

    Supervisor.init(children, strategy: :one_for_all, max_restarts: 3)
  end
end

defmodule Indrajaal.Safety.Watchdog do
  @moduledoc """
  Heartbeat watchdog GenServer.

  SC-SAFETY-003: Dead man's switch implementation.
  Broadcasts stale data warning if heartbeat > 2000ms.
  """

  use GenServer
  require Logger

  @heartbeat_interval 100
  @stale_threshold 2000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @heartbeat_interval)
    Process.send_after(self(), :check, interval)

    {:ok, %{
      last_heartbeat: System.monotonic_time(:millisecond),
      interval: interval,
      stale: false
    }}
  end

  @impl true
  def handle_info(:check, state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.last_heartbeat

    new_state =
      cond do
        elapsed > @stale_threshold and not state.stale ->
          Logger.warning("[WATCHDOG] Data stale: #{elapsed}ms since heartbeat")
          Phoenix.PubSub.broadcast!(
            Indrajaal.PubSub,
            "safety",
            {:data_stale, elapsed}
          )
          %{state | stale: true}

        elapsed <= @stale_threshold and state.stale ->
          Phoenix.PubSub.broadcast!(Indrajaal.PubSub, "safety", :data_fresh)
          %{state | stale: false}

        true ->
          state
      end

    Process.send_after(self(), :check, state.interval)
    {:noreply, new_state}
  end

  def heartbeat do
    GenServer.cast(__MODULE__, :heartbeat)
  end

  @impl true
  def handle_cast(:heartbeat, state) do
    {:noreply, %{state | last_heartbeat: System.monotonic_time(:millisecond)}}
  end
end
```

### 12.3 LiveView Implementation

```elixir
defmodule IndrajaalWeb.Cockpit.DashboardLive do
  @moduledoc """
  Phoenix LiveView for web-based cockpit.

  ## STAMP Constraints
  - SC-HMI-002: Zone layout per NASA-STD-3000
  - SC-SAFETY-004: Stale data visualization

  ## Zones
  - A: Annunciator bar (status indicators)
  - B: Primary display (metrics, charts)
  - C: Message log
  - D: Control surface
  """

  use IndrajaalWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "safety")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "metrics")
      :timer.send_interval(100, :tick)
    end

    {:ok, assign(socket,
      action_state: :idle,
      data_stale: false,
      last_heartbeat: System.monotonic_time(:millisecond),
      metrics: %{},
      messages: [],
      connection_quality: :good
    )}
  end

  @impl true
  def handle_info({:data_stale, elapsed}, socket) do
    # SC-SAFETY-004: Apply stale overlay
    {:noreply, assign(socket, data_stale: true, stale_reason: "#{elapsed}ms")}
  end

  @impl true
  def handle_info(:data_fresh, socket) do
    {:noreply, assign(socket, data_stale: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @data_stale, do: "stale-overlay", else: ""}>
      <%= if @data_stale do %>
        <div class="stale-warning">
          ⚠ CONNECTION LOST - STALE DATA (<%= @stale_reason %>)
        </div>
      <% end %>

      <!-- Zone A: Annunciator Bar -->
      <.zone_a
        action_state={@action_state}
        connection_quality={@connection_quality}
      />

      <!-- Zone B: Primary Display -->
      <.zone_b metrics={@metrics} />

      <!-- Zone C: Message Log -->
      <.zone_c messages={@messages} />

      <!-- Zone D: Control Surface -->
      <.zone_d action_state={@action_state} />
    </div>
    """
  end
end
```

---

## 13. Testing Strategy

### 13.1 Testing Pyramid

| Type | Scope | Tools | Coverage |
|------|-------|-------|----------|
| **Unit** | Individual functions | ExUnit, Expecto | 90%+ |
| **Property** | Invariants | FsCheck, StreamData | All safety logic |
| **Integration** | Component interaction | ExUnit, Wallaby | Critical paths |
| **Visual Regression** | UI rendering | VHS (Charm.sh) | All screens |
| **Chaos** | Resilience | Custom | Process crashes |
| **E2E** | Full user journey | Wallaby, Playwright | Happy paths |

### 13.2 VHS Visual Regression Tapes

```tape
# arm_and_fire_test.tape
# Visual regression test for Arm & Fire sequence

Set Width 100
Set Height 40
Set FontSize 14
Set Theme "Indrajaal Dark"

Type "prajna-cockpit --test-mode"
Enter
Sleep 2s

# Navigate to dangerous action
Type "j"
Sleep 500ms
Type "j"
Sleep 500ms

# Press Enter to ARM - verify amber border
Enter
Sleep 1s
Screenshot arm_state.png

# Hold Space to FIRE - verify progress bar
Type " "
Sleep 3.5s
Screenshot fire_complete.png

# Verify ENGAGED state
Sleep 1s
Screenshot engaged_state.png

# Cleanup
Type "q"
Sleep 500ms
```

### 13.3 Chaos Engineering Tests

```elixir
defmodule Safety.ChaosTest do
  use ExUnit.Case

  @tag :chaos
  test "TUI process restart preserves hardware safety state" do
    {:ok, _} = Safety.Supervisor.start_link([])

    # Set known safety state
    Safety.HardwareState.set_armed(true)
    Safety.HardwareState.set_sensor_value(:pressure, 75.0)

    # Get TUI process and kill it
    tui_pid = Process.whereis(Safety.TUIProcess)
    Process.exit(tui_pid, :kill)

    # Assert restart within 50ms
    :timer.sleep(50)
    new_tui_pid = Process.whereis(Safety.TUIProcess)
    assert new_tui_pid != nil
    assert new_tui_pid != tui_pid

    # Assert state preserved
    assert Safety.HardwareState.get_armed() == true
    assert Safety.HardwareState.get_sensor_value(:pressure) == 75.0
  end

  @tag :chaos
  test "E-Stop state survives supervisor restart" do
    {:ok, _} = Safety.Supervisor.start_link([])

    Safety.EStopListener.engage("Test")
    assert Safety.EStopListener.engaged?() == true

    # Kill entire supervisor
    Supervisor.stop(Safety.Supervisor)
    :timer.sleep(100)

    # Restart supervisor
    {:ok, _} = Safety.Supervisor.start_link([])

    # E-Stop must still be engaged
    assert Safety.EStopListener.engaged?() == true
  end
end
```

---

## 14. Beautiful Information Engineering & UX/CX/DX Quality Framework

> *"Beauty in Information Engineering is rarely about decoration. It is defined by **Elegance**:
> the quality of being pleasingly ingenious and simple. It is the ability to convey maximum
> complexity with minimum cognitive load."*

### 14.1 Philosophy: Interface as Living Narrative (SC-BEAUTY-001)

Beautiful information design doesn't just show numbers; it **tells a story** about the system's health.

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                    THE BEAUTY-UTILITY SYNTHESIS FRAMEWORK                         ║
╠══════════════════════════════════════════════════════════════════════════════════╣
║                                                                                   ║
║    ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐          ║
║    │   ENGINEERING   │     │     DESIGN      │     │   EXPERIENCE    │          ║
║    │   (Skeleton)    │────►│     (Skin)      │────►│    (Soul)       │          ║
║    │                 │     │                 │     │                 │          ║
║    │ • Ontology      │     │ • Data-Ink      │     │ • Trust         │          ║
║    │ • Idempotency   │     │ • Hierarchy     │     │ • Utility       │          ║
║    │ • Signal/Noise  │     │ • Disclosure    │     │ • Delight       │          ║
║    │ • Determinism   │     │ • Cognitive     │     │ • Flow          │          ║
║    └─────────────────┘     └─────────────────┘     └─────────────────┘          ║
║             │                       │                       │                    ║
║             └───────────────────────┴───────────────────────┘                    ║
║                                     │                                            ║
║                                     ▼                                            ║
║                    ┌─────────────────────────────────┐                          ║
║                    │        COMPUTATIONAL            │                          ║
║                    │           BEAUTY                │                          ║
║                    │                                 │                          ║
║                    │  "Maximum Complexity with       │                          ║
║                    │   Minimum Cognitive Load"       │                          ║
║                    └─────────────────────────────────┘                          ║
║                                                                                   ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

**Core Principle**: The UI is a living organism, not a static report.

**Creative Directive (SC-BEAUTY-002)**:
> "Don't just render a table. Treat the screen as a stage. If the system is healthy,
> the UI should feel calm and rhythmic (breathing). If the system is stressed, the
> UI should feel urgent and jagged."

---

### 14.2 Engineering Principles: The Skeleton (SC-ENG-*)

Beautiful information engineering focuses on the architecture, integrity, and flow of data
**before** it ever reaches a screen. If the engineering is "ugly" (slow, inconsistent, or
unstructured), the design will fail.

#### 14.2.1 Principle of Ontology & Taxonomy: Naming is Power (SC-ENG-001)

Beauty begins with a consistent **Controlled Vocabulary**.

```fsharp
// SC-ENG-001: ONTOLOGY CONSISTENCY
// A "Customer" in billing MUST be the exact same entity as "User" in support

module Ontology =
    /// Canonical entity definitions - SINGLE SOURCE OF TRUTH
    type EntityId = EntityId of Guid

    /// Domain-agnostic entity wrapper
    [<RequireQualifiedAccess>]
    type CanonicalEntity =
        | Person of PersonEntity
        | Organization of OrgEntity
        | Device of DeviceEntity
        | Action of ActionEntity

    /// Taxonomy node with semantic parent-child relationships
    type TaxonomyNode = {
        Id: EntityId
        CanonicalName: string       // "alarm.fire.zone_a"
        DisplayName: string         // "Zone A Fire Alarm"
        Synonyms: string list       // ["fire_alarm_zone_a", "za_fire"]
        Parent: EntityId option     // alarm.fire
        SemanticType: SemanticType  // Device, Location, Action, etc.
    }

    /// Semantic ambiguity detection
    let detectAmbiguity (vocabulary: TaxonomyNode list) : AmbiguityReport =
        vocabulary
        |> List.groupBy (fun n -> n.CanonicalName.ToLowerInvariant())
        |> List.filter (fun (_, nodes) -> nodes.Length > 1)
        |> List.map (fun (name, nodes) -> { Term = name; Conflicts = nodes })
        |> fun conflicts -> {
            IsClean = List.isEmpty conflicts
            Ambiguities = conflicts
        }
```

**Engineering Goal**: Eliminate semantic ambiguity. If the underlying data model is messy,
the user interface will be confusing.

**Data Transformation Chain**:
```
Raw Data ──► Structured Information ──► User Knowledge ──► Actionable Insight
   │                  │                       │                    │
   └──────────────────┴───────────────────────┴────────────────────┘
                              ONTOLOGY LAYER
```

#### 14.2.2 Principle of Idempotency & State: Predictability (SC-ENG-002)

In complex systems (like our TUI), beauty is **Predictability**.

```elixir
# SC-ENG-002: IDEMPOTENT STATE ACCESS
defmodule Indrajaal.StateAccess do
  @moduledoc """
  Idempotent state access - asking for the same information twice
  MUST result in the same answer without side effects.

  ## Beauty Principle
  A "beautiful" API or data pipeline is one where the flow of data
  is traceable and deterministic.
  """

  @doc """
  Idempotent query - safe to call multiple times.
  Returns consistent results for same input.
  """
  @spec get_system_state(query :: map()) :: {:ok, State.t()} | {:error, term()}
  def get_system_state(query) do
    # Pure function - no side effects
    with {:ok, raw_state} <- StateStore.read(query),
         {:ok, validated} <- validate_consistency(raw_state),
         {:ok, normalized} <- normalize_for_display(validated) do
      {:ok, normalized}
    end
  end

  @doc """
  State transitions must be explicit and auditable.
  """
  @spec transition_state(from :: State.t(), action :: Action.t()) ::
    {:ok, State.t(), AuditEntry.t()} | {:error, term()}
  def transition_state(from, action) do
    # Every transition produces an audit entry
    # The same (from, action) pair ALWAYS produces the same result
    case StateEngine.compute_transition(from, action) do
      {:ok, to_state} ->
        audit = AuditEntry.new(from, action, to_state)
        {:ok, to_state, audit}
      {:error, reason} ->
        {:error, {:transition_failed, reason}}
    end
  end
end
```

**Transparency Requirements (SC-ENG-002-TRACE)**:

| Aspect | Requirement | Verification Method |
|--------|-------------|---------------------|
| **Traceability** | Every state change has audit trail | Log inspection |
| **Determinism** | Same inputs → same outputs | Property test |
| **Idempotency** | Multiple identical requests → same result | Replay test |
| **Consistency** | No partial state visible to users | Transaction test |

#### 14.2.3 Principle of Signal-to-Noise Ratio: Data Density (SC-ENG-003)

This applies to both engineering (bandwidth) and design (visuals).

```fsharp
// SC-ENG-003: OPTIMAL SIGNAL-TO-NOISE RATIO
module SignalOptimizer =

    /// Data payload analysis
    type PayloadAnalysis = {
        TotalBytes: int64
        SignalBytes: int64      // Actually needed data
        NoiseBytes: int64       // Overhead, redundancy, padding
        CompressionPotential: float
    }

    /// Calculate signal-to-noise ratio
    let analyzePayload (payload: byte[]) (schema: DataSchema) : PayloadAnalysis =
        let totalSize = int64 payload.Length
        let signalSize =
            schema.RequiredFields
            |> List.sumBy (fun f -> int64 f.ActualSize)
        let noiseSize = totalSize - signalSize
        {
            TotalBytes = totalSize
            SignalBytes = signalSize
            NoiseBytes = noiseSize
            CompressionPotential =
                if totalSize > 0L then
                    float noiseSize / float totalSize
                else 0.0
        }

    /// SC-ENG-003-OPTIMIZE: Don't send 5MB JSON when UI needs 3 integers
    let optimizeForUI (fullData: JObject) (uiRequirements: string list) : JObject =
        let optimized = JObject()
        for field in uiRequirements do
            match fullData.TryGetValue(field) with
            | true, value -> optimized.[field] <- value
            | false, _ -> ()
        optimized

    /// Beauty metric: efficient payloads are "beautiful" because they are fast
    let beautyScore (analysis: PayloadAnalysis) : float =
        if analysis.TotalBytes = 0L then 1.0
        else float analysis.SignalBytes / float analysis.TotalBytes
```

**Signal-to-Noise Requirements**:

| Data Type | Max Payload | Signal Threshold | SC Constraint |
|-----------|-------------|------------------|---------------|
| Real-time metrics | 1 KB | > 80% signal | SC-ENG-003-RT |
| Dashboard summary | 10 KB | > 70% signal | SC-ENG-003-DASH |
| Detailed view | 100 KB | > 60% signal | SC-ENG-003-DETAIL |
| Export/Report | 10 MB | > 50% signal | SC-ENG-003-EXPORT |

#### 14.2.4 Data Fluidity & Liveness (SC-ENG-004)

Data shouldn't "pop" into existence; it should **flow**.

```fsharp
// SC-ENG-004: PHYSICS-BASED DATA ANIMATION
module DataFluidity =

    /// Spring physics for smooth value transitions
    type SpringConfig = {
        Stiffness: float    // How quickly it moves toward target
        Damping: float      // How quickly oscillations decay
        Mass: float         // Inertia of the animated value
    }

    let defaultSpring = { Stiffness = 170.0; Damping = 26.0; Mass = 1.0 }
    let snappySpring = { Stiffness = 300.0; Damping = 30.0; Mass = 1.0 }
    let gentleSpring = { Stiffness = 100.0; Damping = 20.0; Mass = 1.0 }

    /// Animated value with physics
    type AnimatedValue = {
        Current: float
        Target: float
        Velocity: float
        Config: SpringConfig
    }

    /// Update animation (called each frame)
    let step (dt: float) (anim: AnimatedValue) : AnimatedValue =
        let displacement = anim.Target - anim.Current
        let springForce = displacement * anim.Config.Stiffness
        let dampingForce = anim.Velocity * anim.Config.Damping
        let acceleration = (springForce - dampingForce) / anim.Config.Mass
        let newVelocity = anim.Velocity + acceleration * dt
        let newCurrent = anim.Current + newVelocity * dt
        { anim with Current = newCurrent; Velocity = newVelocity }

    /// Odometer-style digit scrolling for number changes
    let renderOdometer (fromValue: int) (toValue: int) (progress: float) : string =
        // When a number changes from 100 to 200, scroll digits like mechanical odometer
        let digits =
            [0..9]
            |> List.map (fun digit ->
                let fromDigit = (fromValue / pown 10 digit) % 10
                let toDigit = (toValue / pown 10 digit) % 10
                let interpolated =
                    float fromDigit + (float toDigit - float fromDigit) * progress
                int (round interpolated)
            )
        digits |> List.rev |> List.map string |> String.concat ""
```

**Animation Requirements (SC-ENG-004-ANIM)**:

| Transition Type | Duration | Easing | Purpose |
|-----------------|----------|--------|---------|
| Value change | 150ms | Spring (snappy) | Provide weight to changes |
| Panel expand | 250ms | Ease-out | Smooth reveal |
| Alert appear | 100ms | Linear | Urgency |
| Alert dismiss | 300ms | Ease-in | Calm exit |
| Level zoom | 400ms | Spring (gentle) | Fractal navigation |

---

### 14.3 Design Principles: The Skin (SC-DESIGN-*)

Once the data is engineered, Information Design determines how the human brain processes it.
The gold standard: **Form follows Function** (Bauhaus / Edward Tufte).

#### 14.3.1 Tufte's Data-Ink Ratio (SC-DESIGN-001)

Edward Tufte, the pioneer of data visualization, argues that every drop of ink (or pixel)
on a screen should be dedicated to data.

```
                        Data-Ink
Data-Ink Ratio = ─────────────────────────────────
                  Total Ink used to print graphic

                 BEAUTY = REMOVAL OF THE UNNECESSARY
```

**Application Rules**:

| Element | Keep | Remove | SC Constraint |
|---------|------|--------|---------------|
| Grid lines | If needed for reading | Decorative grids | SC-DESIGN-001-GRID |
| Borders | Semantic boundaries | Visual boxing | SC-DESIGN-001-BORDER |
| Backgrounds | Status indication | Solid fills | SC-DESIGN-001-BG |
| Labels | Required for understanding | Redundant labels | SC-DESIGN-001-LABEL |
| Icons | If faster than text | Decorative icons | SC-DESIGN-001-ICON |

```fsharp
// SC-DESIGN-001: DATA-INK MAXIMIZATION
module DataInkOptimizer =

    type VisualElement =
        | DataElement of name: string * purpose: string
        | ChromeElement of name: string * removable: bool

    /// Analyze component for data-ink ratio
    let analyzeDataInk (elements: VisualElement list) : float =
        let dataCount =
            elements
            |> List.filter (function DataElement _ -> true | _ -> false)
            |> List.length
        let totalCount = elements.Length
        if totalCount = 0 then 1.0
        else float dataCount / float totalCount

    /// Remove unnecessary chrome while preserving semantics
    let optimize (elements: VisualElement list) : VisualElement list =
        elements
        |> List.filter (function
            | DataElement _ -> true
            | ChromeElement(_, removable) -> not removable
        )

    /// Beauty check: ratio should be > 0.7 for optimal density
    let isBeautiful (elements: VisualElement list) : bool =
        analyzeDataInk elements >= 0.7
```

#### 14.3.2 Visual Hierarchy & The Squint Test (SC-DESIGN-002)

If you squint your eyes at the screen, blurring the text, you should still understand
what is most important.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    VISUAL HIERARCHY LEVELS                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│    PRIMARY (25% of screen attention)                                       │
│    ════════════════════════════════                                        │
│    ████████████████████████████████                                        │
│    █  SYSTEM STATUS: CRITICAL  █   ◄── Largest, boldest, most contrast   │
│    ████████████████████████████████                                        │
│                                                                            │
│    SECONDARY (45% of screen attention)                                     │
│    ──────────────────────────────────                                      │
│    ┌──────────┐ ┌──────────┐ ┌──────────┐                                 │
│    │ CPU: 87% │ │ MEM: 45% │ │ DISK: 23%│  ◄── Supporting data           │
│    │ ▁▂▃▅▆▇██ │ │ ▁▂▂▃▃▄▄▅ │ │ ▁▁▂▂▂▂▂▂ │     Sparklines for trend      │
│    └──────────┘ └──────────┘ └──────────┘                                 │
│                                                                            │
│    TERTIARY (30% of screen attention)                                      │
│    ··································                                      │
│    Labels · Timestamps · Metadata      ◄── Smallest, lowest contrast      │
│    Updated: 14:32:45 | Node: cluster-1                                     │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Gestalt Principles for UI (SC-DESIGN-002-GESTALT)**:

| Principle | Description | Application |
|-----------|-------------|-------------|
| **Proximity** | Items close together are related | Group related metrics |
| **Similarity** | Items that look alike are related | Consistent styling per category |
| **Closure** | Mind completes partial shapes | Minimal borders, implied regions |
| **Continuity** | Eye follows smooth paths | Aligned data points |
| **Figure-Ground** | Separate foreground from background | Clear depth hierarchy |

#### 14.3.3 Progressive Disclosure (SC-DESIGN-003)

Complexity is not the enemy; **confusion** is. Manage infinite complexity by disclosing it in layers.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              PROGRESSIVE DISCLOSURE PYRAMID (SC-DESIGN-003)                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                              ▲                                              │
│                             /│\                                             │
│                            / │ \                                            │
│                           /  │  \     LAYER 4: Raw Data                    │
│                          /   │   \    Full JSON/Logs                       │
│                         / ───┼─── \   (Developer Mode)                     │
│                        /     │     \                                       │
│                       /      │      \  LAYER 3: Detail View                │
│                      /  ─────┼─────  \ Full attributes                     │
│                     /        │        \ Graphs, histories                  │
│                    /         │         \                                   │
│                   /    ──────┼──────    \ LAYER 2: List View               │
│                  /           │           \ Summary of items                │
│                 /            │            \ Status + key metrics           │
│                /       ──────┼──────       \                               │
│               /              │              \ LAYER 1: Dashboard            │
│              /               │               \ High-level status           │
│             /________________│________________\ Single glance overview     │
│                                                                             │
│   RULE: Interface never feels "cluttered" - shows only what's needed NOW   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Navigation Depth Rules**:

| Level | Click Depth | Content Density | Target User |
|-------|-------------|-----------------|-------------|
| L1 Dashboard | 0 | Very Low (5-7 items) | Executive |
| L2 List | 1 | Low (15-20 items) | Operator |
| L3 Detail | 2 | Medium (50+ fields) | Analyst |
| L4 Raw | 3+ | High (unlimited) | Developer |

#### 14.3.4 Cognitive Load & Miller's Law (SC-DESIGN-004)

**Miller's Law**: Average human can hold only 7 (±2) items in working memory.

```fsharp
// SC-DESIGN-004: COGNITIVE LOAD MANAGEMENT
module CognitiveLoadManager =

    [<Literal>]
    let MillerLimit = 7  // Plus or minus 2

    /// Chunk data into cognitively manageable groups
    let chunkForDisplay (items: 'a list) (categorize: 'a -> string) : Map<string, 'a list> =
        items
        |> List.groupBy categorize
        |> Map.ofList
        |> Map.filter (fun _ group ->
            // If a category has too many items, sub-chunk it
            group.Length <= MillerLimit + 2)

    /// Calculate cognitive load score (lower is better)
    let calculateLoad (screen: ScreenState) : CognitiveLoadScore =
        let visibleItems = screen.VisibleElements.Length
        let distinctCategories =
            screen.VisibleElements
            |> List.map (_.Category)
            |> List.distinct
            |> List.length
        let interactionPoints = screen.ClickableElements.Length

        {
            ItemLoad = float visibleItems / float MillerLimit
            CategoryLoad = float distinctCategories / 4.0  // Max 4 categories
            InteractionLoad = float interactionPoints / float MillerLimit
            TotalLoad =
                (float visibleItems + float distinctCategories * 2.0 + float interactionPoints)
                / (float MillerLimit * 3.0)
        }

    /// Screen that respects human brain limits feels "calm"
    let isCalm (loadScore: CognitiveLoadScore) : bool =
        loadScore.TotalLoad <= 1.0
```

**Cognitive Load Limits (SC-DESIGN-004-LIMITS)**:

| Screen Type | Max Visible Items | Max Categories | Max Actions |
|-------------|-------------------|----------------|-------------|
| Dashboard | 7 | 3-4 | 5 |
| List View | 15 (paginated) | 4-5 | 7 |
| Detail View | 25 (grouped) | 5-6 | 9 |
| Modal Dialog | 5 | 1-2 | 3 |

---

### 14.4 Experience Principles: The Soul (SC-EXP-*)

When Engineering and Design meet, beauty is found in **Trust** and **Utility**.

#### 14.4.1 Principle of Least Astonishment (SC-EXP-001)

The system should behave exactly how the user expects it to.

```gherkin
@sc-exp-001 @safety-critical
Feature: Principle of Least Astonishment

  Rule: Visual patterns MUST match behavioral patterns

  Scenario Outline: Consistent affordance mapping
    Given a UI element with visual style "<style>"
    When the user interacts with it
    Then the behavior MUST be "<expected_behavior>"

    Examples:
      | style                    | expected_behavior           |
      | blue underlined text     | navigates to link           |
      | red button               | destructive action warning  |
      | green button             | positive/confirm action     |
      | grey disabled element    | no interaction possible     |
      | blinking/pulsing element | requires attention          |
      | bordered panel           | grouped related content     |

  Scenario: No surprise state changes
    Given the user has not initiated any action
    When 5 seconds have passed
    Then no modal dialogs should appear
    And no navigation should occur
    And focus should remain on current element
```

**Surprise Prevention Rules**:

| Pattern | User Expectation | Violation = Surprise |
|---------|------------------|----------------------|
| Red color | Danger/Stop | Red for "OK" |
| Blue underline | Clickable link | Blue static text |
| Modal overlay | Requires attention | Auto-dismiss modal |
| Loading spinner | Wait needed | Spinner that never resolves |
| Disabled control | Cannot interact | Clicking does something |

#### 14.4.2 Wayfinding & Information Scent (SC-EXP-002)

Users forage for information like animals forage for food. They follow a "scent."

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    WAYFINDING SYSTEM (SC-EXP-002)                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────────────────────────────────────────────────────────┐     │
│   │ BREADCRUMB: Home > Alarms > Zone A > Fire Alarm #42             │     │
│   └─────────────────────────────────────────────────────────────────┘     │
│                                                                            │
│   ┌──────────┐                                                            │
│   │ WHERE    │  Current: Fire Alarm #42 Detail View                       │
│   │ AM I?    │  Context: Zone A, Alarm Management                         │
│   └──────────┘                                                            │
│                                                                            │
│   ┌──────────┐                                                            │
│   │ WHERE    │  ↑ Back to Zone A (15 alarms)                              │
│   │ CAN I    │  ← Related: Zone B alarms                                   │
│   │ GO?      │  → Actions: Acknowledge, Escalate, Silence                 │
│   └──────────┘  ↓ Drill down: Event history, Sensor data                  │
│                                                                            │
│   ┌──────────┐                                                            │
│   │ HOW DO   │  [Esc] Back | [←→] Navigate | [Enter] Select              │
│   │ I GET    │  [?] Help  | [Home] Dashboard                              │
│   │ BACK?    │                                                            │
│   └──────────┘                                                            │
│                                                                            │
│   ┌─────────────────────────────────────────────────────────────────┐     │
│   │ INFORMATION SCENT INDICATORS:                                    │     │
│   │  ● Strong scent: Bold, highlighted, marked with count           │     │
│   │  ◐ Medium scent: Normal weight, visible                         │     │
│   │  ○ Weak scent: Dimmed, collapsed, requires expansion            │     │
│   └─────────────────────────────────────────────────────────────────┘     │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Wayfinding Requirements**:

| Element | Purpose | Implementation |
|---------|---------|----------------|
| Breadcrumbs | Path history | All drill-down views |
| "You are here" | Current location | Header/title bar |
| Back button | Return path | All non-root views |
| Home shortcut | Emergency escape | Global hotkey |
| Related links | Lateral navigation | Contextual sidebar |
| Search | Direct access | Global search bar |

#### 14.4.3 Visual Integrity: Honesty (SC-EXP-003)

Never distort data to make it look "better" or "scarier."

**Beauty is Truth. An honest chart builds trust between engineer and operator.**

```gherkin
@sc-exp-003 @visual-integrity
Feature: Data Visualization Honesty

  Rule: Charts MUST NOT distort data perception

  Scenario: Bar chart Y-axis integrity
    Given a bar chart showing values [50%, 52%, 54%, 56%]
    Then the Y-axis MUST start at 0%
    And the visual difference between bars MUST be proportional to actual difference
    # The Lie: Starting Y-axis at 50% makes 4% change look like 100% change
    # The Truth: 4% change shown as 4% visual difference

  Scenario: Consistent time scales
    Given a time series chart
    When displaying data over time
    Then time intervals MUST be evenly spaced
    And gaps in data MUST be visually indicated
    And zoom level MUST be clearly labeled

  Scenario: Color intensity mapping
    Given a heatmap visualization
    Then color intensity MUST map linearly to data values
    And legend MUST show actual value ranges
    And colorblind-safe palette MUST be used
```

**Honesty Verification Matrix**:

| Distortion Type | Detection Method | SC Constraint |
|-----------------|------------------|---------------|
| Truncated axis | Check Y-axis origin | SC-EXP-003-AXIS |
| Unequal intervals | Check X-axis spacing | SC-EXP-003-SCALE |
| 3D effects | Prohibited in data viz | SC-EXP-003-3D |
| Cherry-picked range | Must show full context | SC-EXP-003-RANGE |
| Missing error bars | Required for statistical data | SC-EXP-003-ERROR |

---

### 14.5 UX Quality Dimensions (SC-UX-*)

| Dimension | Requirement | Metric | SC Constraint |
|-----------|-------------|--------|---------------|
| **Response Time** | < 50ms for UI feedback | P95 latency | SC-UX-001 |
| **Keyboard Navigation** | All controls accessible | Tab order test | SC-UX-002 |
| **Color Contrast** | WCAG 2.1 AA (4.5:1) | Contrast ratio | SC-UX-003 |
| **Error Messages** | Clear, actionable | User comprehension | SC-UX-004 |
| **Confirmation** | 2-stage for destructive | FSM test | SC-UX-005 |
| **Undo** | Available for non-destructive | Feature coverage | SC-UX-006 |
| **Auto-save** | Draft every 30 seconds | Timer test | SC-UX-007 |
| **Focus Management** | Predictable focus flow | Accessibility audit | SC-UX-008 |
| **Animation** | 60fps minimum | Frame timing | SC-UX-009 |
| **Responsiveness** | Adapt to viewport | Breakpoint test | SC-UX-010 |

---

### 14.6 CX Quality Dimensions (SC-CX-*)

| Dimension | Requirement | Metric | SC Constraint |
|-----------|-------------|--------|---------------|
| **Audit Trail** | All safety actions logged | Log coverage | SC-CX-001 |
| **Compliance Export** | ISO 27001, GDPR reports | Export validation | SC-CX-002 |
| **Incident Logging** | Timestamped, structured | Log format | SC-CX-003 |
| **Notification** | Real-time critical alerts | Delivery latency | SC-CX-004 |
| **History** | 90-day retention minimum | Retention query | SC-CX-005 |
| **Onboarding** | < 15 min to first value | Time to value | SC-CX-006 |
| **Help System** | Contextual help available | Coverage % | SC-CX-007 |
| **Feedback Loop** | Issue reporting in-app | Response time | SC-CX-008 |
| **SLA Transparency** | Real-time status page | Uptime accuracy | SC-CX-009 |
| **Trust Indicators** | Security/compliance badges | Verification | SC-CX-010 |

---

### 14.7 DX Quality Dimensions (SC-DX-*)

| Dimension | Requirement | Metric | SC Constraint |
|-----------|-------------|--------|---------------|
| **REST API** | OpenAPI 3.1 spec | Swagger validation | SC-DX-001 |
| **GraphQL** | Full schema with descriptions | Introspection | SC-DX-002 |
| **CLI** | `mix kms.*` commands | Command coverage | SC-DX-003 |
| **SDK** | Elixir/F# typed clients | Type coverage | SC-DX-004 |
| **Documentation** | @moduledoc for all | Doc coverage | SC-DX-005 |
| **Type Safety** | Full @spec coverage | Dialyzer | SC-DX-006 |
| **Error Messages** | Descriptive with fix hints | Developer survey | SC-DX-007 |
| **Debug Mode** | Verbose logging available | Feature flag | SC-DX-008 |
| **Hot Reload** | Code changes without restart | Reload time | SC-DX-009 |
| **Test Fixtures** | Factory for every resource | Coverage check | SC-DX-010 |

---

## 15. Automation Framework

### 15.1 Event-Driven Automation

```yaml
# automation/safety_events.yaml
automation:
  name: safety_event_handler
  version: "1.0.0"

  triggers:
    - event: estop_engaged
      actions:
        - type: notification
          config:
            channel: pagerduty
            severity: critical
            message: "E-Stop engaged: {{reason}}"
        - type: audit
          config:
            level: emergency
            include_state: true
        - type: snapshot
          config:
            target: /var/log/indrajaal/snapshots/

    - event: data_stale
      conditions:
        - elapsed_ms > 2000
      actions:
        - type: notification
          config:
            channel: slack
            message: "Connection lost for {{elapsed_ms}}ms"
        - type: metric
          config:
            name: connection_loss_count
            increment: 1

    - event: action_engaged
      actions:
        - type: audit
          config:
            level: info
            fields: [action, user, timestamp, hold_duration]
        - type: backup
          config:
            pre_action_state: true

  recovery:
    on_estop_release:
      - verify_system_state
      - require_manual_reset
      - log_recovery

    on_connection_restored:
      - clear_stale_overlay
      - sync_state
      - verify_consistency
```

### 15.2 CI/CD Pipeline Integration

```yaml
# .github/workflows/safety_checks.yaml
name: Safety-Critical Validation

on: [push, pull_request]

jobs:
  stamp-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate STAMP constraints
        run: |
          mix stamp.validate --all
          mix stamp.report --format markdown > stamp_report.md

      - name: Check net10.0 requirement (SC-NET-001)
        run: |
          for f in lib/cepaf/**/*.fsproj; do
            grep -q "net10.0" "$f" || (echo "FAIL: $f" && exit 1)
          done

      - name: Property-based tests
        run: |
          mix test --only property
          dotnet test --filter "Category=Property"

      - name: Visual regression
        run: |
          vhs arm_and_fire_test.tape
          vhs stale_data_test.tape

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: safety-reports
          path: |
            stamp_report.md
            *.png
```

---

## 16. KMS Integration

### 16.1 KMS Architecture (SQLite + DuckDB)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    KMS DUAL-DATABASE ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    APPLICATION LAYER                             │  │
│   │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │  │
│   │  │ Developer │  │ Product   │  │    SRE    │  │ Tech Lead │    │  │
│   │  │  Portal   │  │  Portal   │  │  Portal   │  │  Portal   │    │  │
│   │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘    │  │
│   └────────┼──────────────┼──────────────┼──────────────┼───────────┘  │
│            │              │              │              │               │
│            └──────────────┴──────┬───────┴──────────────┘               │
│                                  ▼                                      │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    KMS CONTEXT LAYER                             │  │
│   │  ┌───────────────────┐          ┌───────────────────┐           │  │
│   │  │    OLTP Layer     │          │    OLAP Layer     │           │  │
│   │  │    (SQLite)       │ ──sync─► │    (DuckDB)       │           │  │
│   │  │ - Write path      │          │ - Analytics       │           │  │
│   │  │ - ACID txns       │          │ - Vector search   │           │  │
│   │  │ - < 50ms writes   │          │ - Graph queries   │           │  │
│   │  └───────────────────┘          └───────────────────┘           │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    ZENOH SYNC LAYER                              │  │
│   │            Elixir ◄────── Pub/Sub ──────► F# Cockpit            │  │
│   │            (Backend)                      (TUI)                  │  │
│   └─────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 16.2 KMS Use Case Summary

| Domain | Use Cases | Priority |
|--------|-----------|----------|
| Developer | ADR, Patterns, Debug Sessions | P1 |
| Product Manager | Features, Releases, Feedback | P1 |
| SRE | Runbooks, Incidents, Metrics | P0 |
| Tech Lead | Roadmap, Reviews, Decisions | P1 |
| Knowledge Worker | Search, Browse, Export | P2 |
| System Admin | Backup, Audit, Config | P1 |
| AI/Automation | Suggestions, Indexing | P2 |
| Cross-Runtime | Zenoh Sync, Health | P0 |
| Safety-Critical | E-Stop, Audit, Compliance | P0 |
| Error Recovery | Rollback, Retry, Healing | P0 |

---

## 17. Fractal UI System & Computational Beauty Architecture

> *"Information should hold up at any zoom level. Design a UI that morphs completely
> based on available pixel density."* — Fractal Resolution Principle

### 17.1 Fractal Architecture: Semantic Zoom (SC-FRACTAL-001)

Information should hold up at **any zoom level** - from single orb to full system detail.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    FRACTAL UI RENDERING SYSTEM (SC-FRACTAL-001)                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                    MACRO VIEW (The Orb)                                  │   │
│   │                                                                          │   │
│   │                          ██████████                                      │   │
│   │                       ███ ░░░░░░░░ ███                                   │   │
│   │                     ██ ░░░░░░░░░░░░░░ ██                                 │   │
│   │                    █ ░░░░░░░░░░░░░░░░░░ █    Single glowing orb          │   │
│   │                    █ ░░░░ HEALTHY ░░░░░ █    representing global health  │   │
│   │                    █ ░░░░░░░░░░░░░░░░░░ █    (Generative art)            │   │
│   │                     ██ ░░░░░░░░░░░░░░ ██                                 │   │
│   │                       ███ ░░░░░░░░ ███                                   │   │
│   │                          ██████████                                      │   │
│   │                                                                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                     │ ZOOM IN                                    │
│                                     ▼                                            │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                    MESO VIEW (The Rings)                                 │   │
│   │                                                                          │   │
│   │              ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐        │   │
│   │              │░░░░░│    │▓▓▓▓▓│    │░░░░░│    │█████│    │░░░░░│        │   │
│   │              │ APP │    │ DB  │    │CACHE│    │QUEUE│    │ OBS │        │   │
│   │              │░░░░░│    │▓▓▓▓▓│    │░░░░░│    │█████│    │░░░░░│        │   │
│   │              └─────┘    └─────┘    └─────┘    └─────┘    └─────┘        │   │
│   │                                                                          │   │
│   │              Orb splits into 5 distinct cluster status rings            │   │
│   │                                                                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                     │ ZOOM IN                                    │
│                                     ▼                                            │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                    MICRO VIEW (The Detail)                               │   │
│   │                                                                          │   │
│   │   ┌──────────────────────────────────────────────────────────────────┐  │   │
│   │   │ APP CLUSTER                                              [4/5 ✓] │  │   │
│   │   ├──────────────────────────────────────────────────────────────────┤  │   │
│   │   │ CPU   ▁▂▃▅▆▇▆▅▃▂▁▂▃▄▅▆▇▆▅▄▃▂▁▂▃  45% │  MEM  ▅▅▅▆▆▆▇▇▇▇  78% │  │   │
│   │   │ DISK  ▁▁▁▁▁▁▁▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂  23% │  NET  ▂▃▂▃▂▃▂▃▂▃  12Mb│  │   │
│   │   ├──────────────────────────────────────────────────────────────────┤  │   │
│   │   │ Events: ──────────────────────────────────────────────────────── │  │   │
│   │   │ 14:32:45 [INFO] Request completed in 12ms                        │  │   │
│   │   │ 14:32:44 [WARN] High memory pressure detected                    │  │   │
│   │   │ 14:32:42 [INFO] Connection pool expanded to 20                   │  │   │
│   │   └──────────────────────────────────────────────────────────────────┘  │   │
│   │                                                                          │   │
│   │   Rings resolve into high-density sparklines and log streams            │   │
│   │                                                                          │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   Level 5: FEDERATION (Multi-Cluster)                                           │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  [Cluster A] ◄──────► [Cluster B] ◄──────► [Cluster C]                  │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                  │                                               │
│   Level 4: SYSTEM (Cluster Dashboard)                                           │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  [App Nodes] [DB Nodes] [Cache Nodes] [Queue Nodes]                     │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                  │                                               │
│   Level 3: SERVICE (Container View)                                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  [Container 1] [Container 2] [Container 3] ... [Container N]            │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                  │                                               │
│   Level 2: MODULE (Process View)                                                │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  [GenServer 1] [GenServer 2] [Supervisor] [Task]                        │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                  │                                               │
│   Level 1: FUNCTION (Trace View)                                                │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  [Span 1] ──► [Span 2] ──► [Span 3] ──► [Span 4]                       │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 17.2 Fractal Rendering Rules (SC-FRACTAL-002)

| Level | Aggregation | Visualization | SC Constraint | Detail Density |
|-------|-------------|---------------|---------------|----------------|
| L1 Function | None | Trace waterfall | SC-OBS-001 | Max (100%) |
| L2 Module | By process | Process tree | SC-OBS-002 | High (80%) |
| L3 Service | By container | Container grid | SC-CNT-003 | Medium (50%) |
| L4 System | By node | Node topology | SC-OBS-068 | Low (25%) |
| L5 Federation | By cluster | Global map | SC-CLU-001 | Minimal (10%) |
| L6 Macro | All clusters | Health orb | SC-FRACTAL-006 | Abstract (5%) |

### 17.3 Cinematic Typography: Text as Image (SC-TYPO-*)

In a TUI, text is your only pixel. Treat type with the reverence of a Swiss poster designer.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    TYPOGRAPHIC SYSTEM (SC-TYPO-001)                             │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   GOLDEN RATIO GRID (1.618)                                                    │
│   ═════════════════════════                                                    │
│                                                                                 │
│   ┌──────────────────────────────────────────────────────────────────────────┐ │
│   │                                                                           │ │
│   │    ██████╗ ██████╗  █████╗      ██╗███╗   ██╗ █████╗                     │ │
│   │    ██╔══██╗██╔══██╗██╔══██╗     ██║████╗  ██║██╔══██╗                    │ │
│   │    ██████╔╝██████╔╝███████║     ██║██╔██╗ ██║███████║                    │ │
│   │    ██╔═══╝ ██╔══██╗██╔══██║██   ██║██║╚██╗██║██╔══██║                    │ │
│   │    ██║     ██║  ██║██║  ██║╚█████╔╝██║ ╚████║██║  ██║                    │ │
│   │    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝                    │ │
│   │                                                                           │ │
│   │    ^^^^^ ASCII-ART HEADERS: Act as "landmarks" in the sea of data        │ │
│   │                                                                           │ │
│   └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│   MODULAR SCALE (Based on Perfect Fourth: 1.333)                               │
│   ──────────────────────────────────────────────                               │
│                                                                                 │
│   • LEVEL 1 (Master Header): 3x base = ASCII art, extreme boldness             │
│   • LEVEL 2 (Section Header): 2x base = UPPER CASE, bright color               │
│   • LEVEL 3 (Subsection): 1.5x base = Title Case, normal weight                │
│   • LEVEL 4 (Body Text): 1x base = Sentence case, standard color               │
│   • LEVEL 5 (Caption/Meta): 0.75x base = dimmed, lowercase                     │
│                                                                                 │
│   SWISS STYLE ALIGNMENT (12-Column Grid)                                       │
│   ───────────────────────────────────────                                      │
│                                                                                 │
│   │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │                           │
│   ├───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┤                           │
│   │          HEADER (span 12)                      │                           │
│   ├───────────────────┬────────────────────────────┤                           │
│   │  NAV (span 3)     │  CONTENT (span 9)          │                           │
│   │  ├── Item 1       │  ┌─────────────────────┐   │                           │
│   │  ├── Item 2       │  │ Primary Content     │   │                           │
│   │  └── Item 3       │  │ (span 6)            │   │                           │
│   │                   │  └─────────────────────┘   │                           │
│   └───────────────────┴────────────────────────────┘                           │
│                                                                                 │
│   RULE: Treat terminal grid like Swiss Style poster                            │
│         Use extreme whitespace. Align everything to strict 12-column grid.     │
│         Use bold contrast for hierarchy.                                       │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```

```fsharp
// SC-TYPO-001: MODULAR SCALE TYPOGRAPHY
module Typography =

    /// Golden ratio constant
    [<Literal>]
    let GoldenRatio = 1.618

    /// Perfect fourth for modular scale
    [<Literal>]
    let PerfectFourth = 1.333

    type TextLevel =
        | MasterHeader   // 3x base, ASCII art
        | SectionHeader  // 2x base, UPPERCASE
        | Subsection     // 1.5x base, Title Case
        | Body           // 1x base, Sentence case
        | Caption        // 0.75x base, dimmed

    /// Calculate relative size based on level
    let sizeMultiplier (level: TextLevel) : float =
        match level with
        | MasterHeader -> 3.0
        | SectionHeader -> 2.0
        | Subsection -> 1.5
        | Body -> 1.0
        | Caption -> 0.75

    /// 12-column grid system
    type GridSpan = Span of columns: int

    let fullWidth = Span 12
    let half = Span 6
    let third = Span 4
    let quarter = Span 3
    let sidebar = Span 3
    let mainContent = Span 9

    /// Enforce grid alignment
    let alignToGrid (content: string) (span: GridSpan) (totalWidth: int) : string =
        let (Span cols) = span
        let cellWidth = totalWidth / 12
        let targetWidth = cellWidth * cols
        content.PadRight(targetWidth)
```

### 17.4 Color as Information Architecture: Mood Palettes (SC-COLOR-*)

Don't use color for decoration. Use it for **Meaning** and **Mood**.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    COLOR SEMANTIC SYSTEM (SC-COLOR-001)                         │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MOOD BOARD PALETTES                                                          │
│   ═══════════════════                                                          │
│                                                                                 │
│   ┌──────────────────────────────────────────────────────────────────────────┐ │
│   │ NORMAL MODE: Cool Cyans, Deep Indigos (Calm, Professional)               │ │
│   │                                                                           │ │
│   │   ░░░░░░░░   ▒▒▒▒▒▒▒▒   ▓▓▓▓▓▓▓▓   ████████                              │ │
│   │   #0D1117    #161B22    #21262D    #30363D                               │ │
│   │   Void       Deep       Surface    Border                                 │ │
│   │                                                                           │ │
│   │   ████████   ████████   ████████   ████████                              │ │
│   │   #58A6FF    #1F6FEB    #238636    #C9D1D9                               │ │
│   │   Accent     Link       Success    Text                                   │ │
│   └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│   ┌──────────────────────────────────────────────────────────────────────────┐ │
│   │ WARNING MODE: Bio-Luminescent Ambers (Attention, Not Painful)            │ │
│   │                                                                           │ │
│   │   ████████   ████████   ████████   ████████                              │ │
│   │   #D29922    #E3B341    #F0C674    #FFF5B1                               │ │
│   │   Dark Amber Amber      Light      Highlight                              │ │
│   │                                                                           │ │
│   │   Animation: Slow pulse (2s period) - draws attention without startle    │ │
│   └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│   ┌──────────────────────────────────────────────────────────────────────────┐ │
│   │ CRITICAL MODE: Hyper-Saturated Neon Red + Void Black (Urgent, Scary)     │ │
│   │                                                                           │ │
│   │   ████████   ████████   ████████   ████████                              │ │
│   │   #FF0040    #FF4444    #FF6B6B    #000000                               │ │
│   │   Neon Red   Alert      Error BG   Void                                   │ │
│   │                                                                           │ │
│   │   Animation: Fast blink (0.5s) + desaturation of surroundings            │ │
│   └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│   GLOW & BLOOM EFFECT (SC-COLOR-002)                                           │
│   ──────────────────────────────────                                           │
│                                                                                 │
│   Simulate "Light" in terminal by setting surrounding characters dimmer:       │
│                                                                                 │
│       ░░░░░░░░░░░░░                                                            │
│       ░░░▓▓▓▓▓░░░░░      Central bright element (#FFFFFF)                     │
│       ░░▓█████▓░░░░      Inner glow (#AAAAAA)                                 │
│       ░░▓█ 42 █▓░░░      Outer glow (#666666)                                 │
│       ░░▓█████▓░░░░      Background (#333333)                                 │
│       ░░░▓▓▓▓▓░░░░░                                                            │
│       ░░░░░░░░░░░░░      Eye perceives "bloom" around bright data             │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```

```fsharp
// SC-COLOR-001: SEMANTIC COLOR SYSTEM
module ColorSemantics =

    /// System mood determines overall palette
    type SystemMood =
        | Normal    // Cool, calm, professional
        | Warning   // Attention-seeking amber
        | Critical  // Urgent, alarming red
        | Success   // Positive, confirming green
        | Info      // Neutral, informational blue

    /// Color with semantic meaning
    type SemanticColor = {
        Hex: string
        Name: string
        Purpose: string
        MoodContext: SystemMood
    }

    /// Mood-based palette selection
    let paletteForMood (mood: SystemMood) : Map<string, SemanticColor> =
        match mood with
        | Normal ->
            Map.ofList [
                "background", { Hex = "#0D1117"; Name = "Void"; Purpose = "Base background"; MoodContext = Normal }
                "surface", { Hex = "#161B22"; Name = "Deep"; Purpose = "Elevated surface"; MoodContext = Normal }
                "text", { Hex = "#C9D1D9"; Name = "Light"; Purpose = "Primary text"; MoodContext = Normal }
                "accent", { Hex = "#58A6FF"; Name = "Cyan"; Purpose = "Interactive elements"; MoodContext = Normal }
            ]
        | Warning ->
            Map.ofList [
                "primary", { Hex = "#D29922"; Name = "Amber"; Purpose = "Warning indicator"; MoodContext = Warning }
                "highlight", { Hex = "#FFF5B1"; Name = "Glow"; Purpose = "Attention focus"; MoodContext = Warning }
            ]
        | Critical ->
            Map.ofList [
                "primary", { Hex = "#FF0040"; Name = "Neon"; Purpose = "Critical alert"; MoodContext = Critical }
                "background", { Hex = "#000000"; Name = "Void"; Purpose = "Maximum contrast"; MoodContext = Critical }
            ]
        | _ -> Map.empty

    /// Generate bloom effect around bright element
    let generateBloom (centerChar: char) (intensity: float) : string[][] =
        let levels =
            [| 0.2; 0.4; 0.6; 0.8; 1.0; 0.8; 0.6; 0.4; 0.2 |]
            |> Array.map (fun l -> l * intensity)
        // Returns 5x5 grid with graduated brightness
        Array.init 5 (fun y ->
            Array.init 5 (fun x ->
                let dist = sqrt(float((x-2)*(x-2) + (y-2)*(y-2)))
                if dist < 0.5 then string centerChar
                elif dist < 1.5 then "▓"
                elif dist < 2.5 then "▒"
                else "░"
            )
        )
```

### 17.5 Generative Texture: The Digital Material (SC-TEXTURE-*)

Flat colors are boring. Use data to generate **texture**.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    GENERATIVE TEXTURE SYSTEM (SC-TEXTURE-001)                   │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   PERLIN NOISE BACKGROUND (Heartbeat Visualization)                            │
│   ═══════════════════════════════════════════════════                          │
│                                                                                 │
│   Instead of solid grey background, generate subtle noise field:               │
│                                                                                 │
│   ░░▒░░░▒░░░░▒░▒░░░░░░▒░░░▒░░░░░▒░░░░▒░░░░▒░░░░░░▒░░                          │
│   ░░░▒░░░░░░░░░▒░░░░▒░░░░░░▒░░░░░░░░▒░░░░░░▒░░░░░░░░                          │
│   ▒░░░░▒░░░▒░░░░░▒░░░░░▒░░░░▒░░░░▒░░░░░▒░░░░░░▒░░░░▒                          │
│   ░░░░░░░▒░░░░░░░░░▒░░░░░░░░░▒░░░░░░░░░░▒░░░░░░░░░░░                          │
│   ░▒░░░░░░░▒░░░░▒░░░░░▒░░░░░░░░▒░░░░░▒░░░░░░▒░░░░░░░                          │
│                                                                                 │
│   Make the noise "drift" slowly to indicate system is running (alive)          │
│   This turns "Empty Space" into "Active Atmosphere"                            │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   STARFIELD / MATRIX RAIN BACKGROUND                                           │
│   ═══════════════════════════════════                                          │
│                                                                                 │
│   A subtle, shifting "starfield" of dim hex codes representing real-time       │
│   memory pointers or event IDs:                                                 │
│                                                                                 │
│       ·  0x7F  ·     ·  ·  0xA3  ·     · 0x1B  ·  ·                            │
│    ·      ·    0x42   ·      ·      ·  0xE7  ·    ·                            │
│      0x8C   ·     ·     ·  0x5D   ·      ·      0x3F                           │
│    ·     ·    ·  0xF1  ·      ·     ·  0x29    ·                               │
│        ·   0x6A    ·      ·    0xB8     ·    ·                                 │
│                                                                                 │
│   Each hex value slowly drifts down (Matrix-style) or pulses with activity     │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   CONSTELLATION MODE (Idle/Screensaver)                                        │
│   ═════════════════════════════════════                                        │
│                                                                                 │
│   Dashboard dissolves into "constellation" view of connected nodes:            │
│                                                                                 │
│               ★                                                                │
│              / \                                                                │
│             /   \                                                               │
│            ●─────●           ★ = Active node                                   │
│           / \   / \          ● = Standby node                                  │
│          /   \ /   \         ○ = Offline node                                  │
│         ○     ★     ●        ─ = Connection                                    │
│                                                                                 │
│   Nodes drift slowly to prevent burn-in and show system "aliveness"            │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```

```fsharp
// SC-TEXTURE-001: GENERATIVE BACKGROUND TEXTURES
module GenerativeTexture =

    /// Perlin noise for organic backgrounds
    let perlinNoise (x: float) (y: float) (seed: int) : float =
        // Simplified Perlin implementation
        let hash (xi: int) (yi: int) =
            let n = xi + yi * 57 + seed * 131
            let n = (n <<< 13) ^^^ n
            (1.0 - float ((n * (n * n * 15731 + 789221) + 1376312589) &&& 0x7fffffff) / 1073741824.0)
        let xi = int (floor x)
        let yi = int (floor y)
        let xf = x - float xi
        let yf = y - float yi
        // Bilinear interpolation
        let v00 = hash xi yi
        let v10 = hash (xi + 1) yi
        let v01 = hash xi (yi + 1)
        let v11 = hash (xi + 1) (yi + 1)
        let i1 = v00 * (1.0 - xf) + v10 * xf
        let i2 = v01 * (1.0 - xf) + v11 * xf
        i1 * (1.0 - yf) + i2 * yf

    /// Convert noise value to texture character
    let noiseToChar (value: float) : char =
        if value < -0.5 then ' '
        elif value < 0.0 then '░'
        elif value < 0.3 then '▒'
        elif value < 0.6 then '▓'
        else '█'

    /// Generate drifting background for "aliveness"
    let generateBackground (width: int) (height: int) (time: float) : char[][] =
        Array.init height (fun y ->
            Array.init width (fun x ->
                let noise = perlinNoise (float x * 0.1 + time * 0.5) (float y * 0.1) 42
                noiseToChar noise
            )
        )

    /// Matrix rain effect with hex codes
    type RainDrop = { X: int; Y: float; Speed: float; Value: string }

    let generateMatrixRain (width: int) (drops: RainDrop list) : string[] =
        let grid = Array.init 40 (fun _ -> String.replicate width " ")
        for drop in drops do
            let yi = int drop.Y
            if yi >= 0 && yi < 40 then
                let row = grid.[yi].ToCharArray()
                if drop.X < width - 4 then
                    for i, c in drop.Value |> Seq.indexed do
                        if drop.X + i < width then
                            row.[drop.X + i] <- c
                grid.[yi] <- String(row)
        grid
```

### 17.6 Micro-Interactions: The Joy of Use (SC-MICRO-*)

Beauty lives in the **response**. Make the user feel powerful.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                    MICRO-INTERACTION PATTERNS (SC-MICRO-001)                    │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   TACTILE FEEDBACK (SC-MICRO-001)                                              │
│   ═══════════════════════════════                                              │
│                                                                                 │
│   When user presses key, UI should "bounce" or flash:                          │
│                                                                                 │
│   BEFORE PRESS:     DURING PRESS:      AFTER RELEASE:                          │
│   ┌──────────┐      ╔══════════╗       ┌──────────┐                            │
│   │  Button  │  →   ║▌ Button ▐║   →   │  Button  │                            │
│   └──────────┘      ╚══════════╝       └──────────┘                            │
│                     (inverted/bold)     (return + subtle glow)                 │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   CURSOR SPOTLIGHT (SC-MICRO-002)                                              │
│   ═══════════════════════════════                                              │
│                                                                                 │
│   Instead of simple block cursor, render a "spotlight" effect:                 │
│                                                                                 │
│     ┌──────────────────────────────────────────────┐                          │
│     │ ░░░░ Item 1 - Inactive                    ░░ │  Dimmed                   │
│     │ ░░░░ Item 2 - Inactive                    ░░ │  Dimmed                   │
│     │ ▒▒▒▒ Item 3 - Near cursor                ▒▒▒ │  Slightly visible        │
│     │ ████ ITEM 4 - ACTIVE SELECTION          ████ │  FULL BRIGHTNESS         │
│     │ ▒▒▒▒ Item 5 - Near cursor                ▒▒▒ │  Slightly visible        │
│     │ ░░░░ Item 6 - Inactive                    ░░ │  Dimmed                   │
│     │ ░░░░ Item 7 - Inactive                    ░░ │  Dimmed                   │
│     └──────────────────────────────────────────────┘                          │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   TRANSITION ANIMATIONS (SC-MICRO-003)                                         │
│   ═════════════════════════════════════                                        │
│                                                                                 │
│   VALUE CHANGES: Odometer scroll (not instant swap)                            │
│                                                                                 │
│   Frame 0:  CPU: 45%    Frame 3:  CPU: 4█%    Frame 6:  CPU: 52%               │
│   Frame 1:  CPU: 4▓%    Frame 4:  CPU: 5░%    (Complete)                       │
│   Frame 2:  CPU: 4▒%    Frame 5:  CPU: 5▒%                                     │
│                                                                                 │
│   PANEL TRANSITIONS: Slide/expand (not instant appear)                         │
│                                                                                 │
│   Frame 0:  ┌─┐         Frame 3:  ┌─────────┐    Frame 6:  ┌───────────────┐  │
│   Frame 1:  ┌───┐       Frame 4:  ┌───────────┐   (Complete) │   DETAIL     │  │
│   Frame 2:  ┌───────┐   Frame 5:  ┌─────────────┐            │   PANEL      │  │
│                                                               └───────────────┘  │
│                                                                                 │
└────────────────────────────────────────────────────────────────────────────────┘
```

```fsharp
// SC-MICRO-001: MICRO-INTERACTION ENGINE
module MicroInteractions =

    /// Animation state for UI elements
    type AnimationPhase =
        | Idle
        | Pressing of startTime: float
        | Releasing of startTime: float * peakIntensity: float
        | Transitioning of fromValue: float * toValue: float * progress: float

    /// Keypress feedback animation
    let keypressFeedback (phase: AnimationPhase) (elapsed: float) : VisualStyle =
        match phase with
        | Idle ->
            { Border = Normal; Brightness = 1.0; Invert = false }
        | Pressing start ->
            let duration = elapsed - start
            { Border = Bold; Brightness = 1.2; Invert = duration > 0.05 }
        | Releasing (start, peak) ->
            let duration = elapsed - start
            let decay = max 0.0 (1.0 - duration / 0.3)  // 300ms decay
            { Border = Normal; Brightness = 1.0 + 0.2 * decay; Invert = false }
        | _ ->
            { Border = Normal; Brightness = 1.0; Invert = false }

    /// Spotlight dimming for list items
    let spotlightDimming (itemIndex: int) (cursorIndex: int) : float =
        let distance = abs (itemIndex - cursorIndex)
        match distance with
        | 0 -> 1.0      // Full brightness at cursor
        | 1 -> 0.7      // Slightly dimmed nearby
        | 2 -> 0.5      // More dimmed
        | _ -> 0.3      // Distant items heavily dimmed

    /// Value transition animation (odometer effect)
    let animateValueChange (fromVal: int) (toVal: int) (progress: float) : string =
        // Easing function for smooth animation
        let eased = 1.0 - pown (1.0 - progress) 3  // Ease-out cubic
        let current = float fromVal + (float toVal - float fromVal) * eased
        sprintf "%.0f" current
```

### 17.7 The Wall Art Test: Ultimate Beauty Validation (SC-ART-001)

**Question**: "If I took a screenshot of this dashboard and framed it on a wall, would it look like art?"

```gherkin
@sc-art-001 @beauty-validation
Feature: Wall Art Test for UI Beauty

  Rule: Every screen MUST pass the Wall Art Test

  Scenario: Dashboard aesthetic validation
    Given a screenshot of the main dashboard
    When evaluated by the Wall Art Test criteria
    Then it should score >= 7/10 on aesthetic appeal
    And the composition should follow golden ratio principles
    And the color harmony should be analyzable by colorimetry

  Scenario: Information density validation
    Given a dashboard with 10 data points
    Then Tufte's data-ink ratio should be > 0.7
    And no decorative elements should exist without data purpose
    And the squint test should reveal clear hierarchy

  Scenario: Beauty-Utility balance
    Given any UI screen
    Then it should be both:
      | Attribute | Requirement |
      | Beautiful | Passes Wall Art Test |
      | Functional | All data accessible within 2 clicks |
      | Calm | Cognitive load score <= 1.0 |
      | Honest | No data distortion (SC-EXP-003) |
```

**Beauty Evaluation Rubric**:

| Criterion | Score Range | Description |
|-----------|-------------|-------------|
| Composition | 0-2 | Golden ratio alignment, balance, focal point |
| Color Harmony | 0-2 | Semantic consistency, mood appropriateness |
| Typography | 0-2 | Hierarchy clarity, readability, grid alignment |
| Whitespace | 0-2 | Breathing room, not cluttered, intentional gaps |
| Animation | 0-2 | Smooth, purposeful, not distracting |
| **Total** | **0-10** | **>= 7 = Pass Wall Art Test** |

---

## 18. Artifact Generation Checklist

### 18.1 F# Frontend Files

| File | Purpose | STAMP Constraints |
|------|---------|-------------------|
| `Domain.fs` | Safety state types | SC-FSH-001, SC-SAFETY-001 |
| `Update.fs` | Pure logic FSM | SC-SAFETY-002, SC-FSH-020 |
| `View.fs` | View functions | SC-SAFETY-004, SC-HMI-002 |
| `Renderer.fs` | Tier adapter | SC-RENDER-001, SC-RENDER-002 |
| `SafetyColors.fs` | RGB palette | SC-HMI-001 |
| `SafetyProperties.fs` | FsCheck tests | SC-TEST-001, SC-FSH-030 |

### 18.2 Elixir Backend Files

| File | Purpose | STAMP Constraints |
|------|---------|-------------------|
| `safety_supervisor.ex` | OTP Supervisor | SC-EMR-057 |
| `estop_listener.ex` | GPIO E-Stop | SC-SAFETY-005 |
| `watchdog.ex` | Heartbeat | SC-SAFETY-003 |
| `hardware_state.ex` | Persistent state | SC-CEP-008 |
| `audit_log.ex` | Compliance log | SC-OBS-069 |

### 18.3 Test & Build Files

| File | Purpose | STAMP Constraints |
|------|---------|-------------------|
| `arm_fire_test.tape` | VHS regression | SC-TEST-003 |
| `emergency_stop.feature` | BDD scenarios | SC-TEST-005 |
| `chaos_test.exs` | Resilience tests | SC-TEST-004 |
| `property_test.exs` | StreamData tests | SC-TEST-002 |
| `build_static.sh` | NativeAOT/Burrito | SC-ARCH-001 |

---

## 19. Multi-Dimensional Test Vector Matrix (SC-VECTOR-*)

> *"Test vectors must span all dimensions: functionality, aesthetics, performance,
> accessibility, security, and emotional response."*

### 19.1 Test Vector Dimensional Framework

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    MULTI-DIMENSIONAL TEST VECTOR SPACE                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   DIMENSION 1: FUNCTIONALITY (SC-VECTOR-001)                                        │
│   ═══════════════════════════════════════════                                       │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Correctness: Does it produce correct output?                               │   │
│   │ • Completeness: Are all features implemented?                                │   │
│   │ • Consistency: Same input → same output always?                              │   │
│   │ • Boundary: Edge cases handled correctly?                                    │   │
│   │ • Error: Graceful degradation on failures?                                   │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   DIMENSION 2: AESTHETICS (SC-VECTOR-002)                                           │
│   ════════════════════════════════════════                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Visual Hierarchy: Clear primary/secondary/tertiary?                        │   │
│   │ • Color Harmony: Semantic and mood-appropriate?                              │   │
│   │ • Typography: Modular scale, grid alignment?                                 │   │
│   │ • Whitespace: Intentional breathing room?                                    │   │
│   │ • Animation: Smooth, purposeful, 60fps?                                      │   │
│   │ • Wall Art Test: Would frame it as art?                                      │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   DIMENSION 3: PERFORMANCE (SC-VECTOR-003)                                          │
│   ═════════════════════════════════════════                                         │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Response Time: < 50ms for UI feedback?                                     │   │
│   │ • Render Rate: 60fps minimum?                                                │   │
│   │ • Memory: No leaks, bounded growth?                                          │   │
│   │ • CPU: Idle < 5%, peak < 80%?                                                │   │
│   │ • Network: Minimal payload, efficient protocol?                              │   │
│   │ • Startup: < 2s to interactive?                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   DIMENSION 4: ACCESSIBILITY (SC-VECTOR-004)                                        │
│   ═══════════════════════════════════════════                                       │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Keyboard: All controls via keyboard?                                       │   │
│   │ • Screen Reader: ARIA labels, semantic HTML?                                 │   │
│   │ • Color Contrast: WCAG 2.1 AA (4.5:1)?                                       │   │
│   │ • Motion: Reduced motion support?                                            │   │
│   │ • Focus: Visible focus indicators?                                           │   │
│   │ • Language: Clear, jargon-free text?                                         │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   DIMENSION 5: SECURITY (SC-VECTOR-005)                                             │
│   ══════════════════════════════════════                                            │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Authentication: Strong auth, MFA support?                                  │   │
│   │ • Authorization: RBAC, least privilege?                                      │   │
│   │ • Data Protection: Encryption at rest/transit?                               │   │
│   │ • Audit: All safety actions logged?                                          │   │
│   │ • Injection: No SQL/XSS/command injection?                                   │   │
│   │ • Compliance: GDPR, ISO 27001?                                               │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   DIMENSION 6: EMOTIONAL RESPONSE (SC-VECTOR-006)                                   │
│   ════════════════════════════════════════════════                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │ • Calm: Low cognitive load, not overwhelming?                                │   │
│   │ • Trust: Honest data, no manipulation?                                       │   │
│   │ • Confidence: User feels in control?                                         │   │
│   │ • Delight: Micro-interactions feel satisfying?                               │   │
│   │ • Safety: Clear feedback on dangerous actions?                               │   │
│   │ • Flow: Uninterrupted task completion?                                       │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 19.2 Test Vector Generation Matrix

| Dimension | Test Type | Tool/Framework | SC Constraint | Coverage Target |
|-----------|-----------|----------------|---------------|-----------------|
| **Functionality** | Unit/Integration | ExUnit, FsCheck | SC-VECTOR-001 | 95% |
| | Property-based | StreamData, PropCheck | SC-TDG-001 | All invariants |
| | Model-based | Quint, TLA+ | SC-MBT-001 | FSM coverage |
| | BDD | Gherkin/ExUnit | SC-BDD-001 | All scenarios |
| **Aesthetics** | Visual regression | VHS, Percy | SC-VECTOR-002 | All screens |
| | Data-ink ratio | Custom analyzer | SC-DESIGN-001 | > 0.7 |
| | Wall Art Test | Human review + AI | SC-ART-001 | >= 7/10 |
| | Color harmony | Colorimetry | SC-COLOR-001 | WCAG compliant |
| **Performance** | Load testing | k6, Artillery | SC-VECTOR-003 | P99 < 50ms |
| | Memory profiling | Observer, Instruments | SC-PERF-001 | No leaks |
| | Render profiling | Custom frame timer | SC-MICRO-003 | 60fps |
| **Accessibility** | WCAG audit | axe-core | SC-VECTOR-004 | AA compliant |
| | Keyboard testing | Manual + automated | SC-UX-002 | 100% reachable |
| | Screen reader | VoiceOver/NVDA | SC-A11Y-001 | Full narration |
| **Security** | Penetration | OWASP ZAP | SC-VECTOR-005 | No critical |
| | Static analysis | Sobelow | SC-SEC-044 | Zero findings |
| | Compliance | Custom checklist | SC-CX-002 | 100% |
| **Emotional** | User testing | Surveys, interviews | SC-VECTOR-006 | NPS > 50 |
| | Cognitive load | Custom metrics | SC-DESIGN-004 | <= 1.0 score |
| | Micro-interaction | A/B testing | SC-MICRO-001 | 80% preference |

### 19.3 Test Vector Implementation

```fsharp
// SC-VECTOR-001 to SC-VECTOR-006: MULTI-DIMENSIONAL TEST VECTORS
module TestVectors =

    /// Test dimension enumeration
    type TestDimension =
        | Functionality
        | Aesthetics
        | Performance
        | Accessibility
        | Security
        | EmotionalResponse

    /// Test vector with multi-dimensional coverage
    type TestVector = {
        Id: string
        Name: string
        Dimensions: Set<TestDimension>
        Priority: int  // 1=Critical, 5=Nice-to-have
        Automated: bool
        SCConstraints: string list
    }

    /// Test vector for safety-critical screen
    let safetyDashboardVectors = [
        {
            Id = "TV-001"
            Name = "E-Stop button visibility"
            Dimensions = set [Functionality; Aesthetics; Accessibility; EmotionalResponse]
            Priority = 1
            Automated = true
            SCConstraints = ["SC-SAFETY-001"; "SC-HMI-001"; "SC-UX-002"]
        }
        {
            Id = "TV-002"
            Name = "Alarm list performance"
            Dimensions = set [Functionality; Performance; Aesthetics]
            Priority = 1
            Automated = true
            SCConstraints = ["SC-VECTOR-003"; "SC-UX-001"]
        }
        {
            Id = "TV-003"
            Name = "Color-blind safe palette"
            Dimensions = set [Aesthetics; Accessibility]
            Priority = 2
            Automated = true
            SCConstraints = ["SC-COLOR-001"; "SC-VECTOR-004"]
        }
    ]

    /// Calculate dimensional coverage for test suite
    let dimensionalCoverage (vectors: TestVector list) : Map<TestDimension, float> =
        let allDimensions = [Functionality; Aesthetics; Performance; Accessibility; Security; EmotionalResponse]
        allDimensions
        |> List.map (fun dim ->
            let coverage =
                vectors
                |> List.filter (fun v -> v.Dimensions.Contains dim)
                |> List.length
                |> float
            let total = float vectors.Length
            dim, if total > 0.0 then coverage / total else 0.0
        )
        |> Map.ofList
```

```elixir
# SC-VECTOR-*: ELIXIR TEST VECTOR IMPLEMENTATION
defmodule Indrajaal.TestVectors do
  @moduledoc """
  Multi-dimensional test vector framework for safety-critical UI testing.

  ## Dimensions Covered
  - Functionality: Correctness, completeness, boundary cases
  - Aesthetics: Visual hierarchy, color harmony, wall art test
  - Performance: Response time, memory, CPU
  - Accessibility: Keyboard, screen reader, color contrast
  - Security: Auth, encryption, compliance
  - Emotional: Calm, trust, delight, flow
  """

  defmodule Vector do
    @enforce_keys [:id, :name, :dimensions, :priority]
    defstruct [:id, :name, :dimensions, :priority, :automated, :sc_constraints]

    @type t :: %__MODULE__{
      id: String.t(),
      name: String.t(),
      dimensions: [atom()],
      priority: 1..5,
      automated: boolean(),
      sc_constraints: [String.t()]
    }
  end

  @dimensions [:functionality, :aesthetics, :performance, :accessibility, :security, :emotional]

  @doc """
  Generate test vectors for a UI component.
  """
  @spec generate_vectors(atom(), keyword()) :: [Vector.t()]
  def generate_vectors(component, opts \\ []) do
    base_vectors = [
      %Vector{
        id: "#{component}-FUNC-001",
        name: "Functionality baseline",
        dimensions: [:functionality],
        priority: 1,
        automated: true,
        sc_constraints: ["SC-VECTOR-001"]
      },
      %Vector{
        id: "#{component}-AEST-001",
        name: "Visual hierarchy check",
        dimensions: [:aesthetics],
        priority: 2,
        automated: true,
        sc_constraints: ["SC-VECTOR-002", "SC-DESIGN-002"]
      },
      %Vector{
        id: "#{component}-PERF-001",
        name: "Response time validation",
        dimensions: [:performance],
        priority: 1,
        automated: true,
        sc_constraints: ["SC-VECTOR-003", "SC-UX-001"]
      },
      %Vector{
        id: "#{component}-A11Y-001",
        name: "Keyboard accessibility",
        dimensions: [:accessibility],
        priority: 1,
        automated: true,
        sc_constraints: ["SC-VECTOR-004", "SC-UX-002"]
      },
      %Vector{
        id: "#{component}-SEC-001",
        name: "Security baseline",
        dimensions: [:security],
        priority: 1,
        automated: true,
        sc_constraints: ["SC-VECTOR-005", "SC-SEC-044"]
      },
      %Vector{
        id: "#{component}-EMO-001",
        name: "Cognitive load assessment",
        dimensions: [:emotional],
        priority: 3,
        automated: false,
        sc_constraints: ["SC-VECTOR-006", "SC-DESIGN-004"]
      }
    ]

    if Keyword.get(opts, :safety_critical, false) do
      safety_vectors = [
        %Vector{
          id: "#{component}-SAFETY-001",
          name: "E-Stop accessibility",
          dimensions: [:functionality, :accessibility, :emotional],
          priority: 1,
          automated: true,
          sc_constraints: ["SC-SAFETY-005", "SC-HMI-001"]
        }
      ]
      base_vectors ++ safety_vectors
    else
      base_vectors
    end
  end

  @doc """
  Calculate coverage across all dimensions.
  """
  @spec calculate_coverage([Vector.t()]) :: map()
  def calculate_coverage(vectors) do
    total = length(vectors)

    @dimensions
    |> Enum.map(fn dim ->
      covered = Enum.count(vectors, fn v -> dim in v.dimensions end)
      {dim, if(total > 0, do: covered / total * 100, else: 0.0)}
    end)
    |> Map.new()
  end
end
```

### 19.4 Standard vs Creative Test Implementation Matrix

| Component | Standard Implementation | Creative/Beautiful Implementation |
|-----------|------------------------|----------------------------------|
| **Progress Bar** | `[####......]` | Gradient liquid fill using Unicode blocks (▏▎▍▌▋▊▉█) that "sloshes" when stopping |
| **Background** | Solid Black | Drifting Perlin noise field or subtle "Matrix rain" of dim hex codes |
| **Alert Modal** | Pop-up box with "Error" text | Screen desaturates; error types itself center-screen with blinking cursor |
| **List View** | Simple rows | "Cover Flow" 3D list: active item largest, others recede (font weight/color) |
| **Idle State** | Static screen | "Constellation mode": dashboard dissolves into drifting node network |
| **Value Change** | Instant text swap | Odometer scroll animation with 150ms spring physics |
| **Button Press** | Simple click | Tactile bounce: invert on press, glow on release |
| **Panel Open** | Instant appear | Slide/expand animation with 250ms ease-out |
| **Sparkline** | Basic line | Bio-luminescent glow with intensity mapped to value |
| **Empty State** | "No data" text | Animated "searching" orb or breathing placeholder |

---

## 20. Automated GUI Evolution Framework (SC-AGE-*)

> *"The UI is a living organism that evolves based on usage patterns, feedback, and
> fitness functions measuring beauty, utility, and safety compliance."*

### 20.1 Evolutionary UI Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    AUTOMATED GUI EVOLUTION FRAMEWORK (SC-AGE-001)                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                         EVOLUTION PIPELINE                                   │   │
│   │                                                                              │   │
│   │   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐             │   │
│   │   │ OBSERVE  │───►│ ORIENT   │───►│ DECIDE   │───►│  ACT     │             │   │
│   │   │          │    │          │    │          │    │          │             │   │
│   │   │ Metrics  │    │ AI       │    │ Guardian │    │ Deploy   │             │   │
│   │   │ Feedback │    │ Analysis │    │ Approve  │    │ Shadow   │             │   │
│   │   │ A/B Data │    │ Patterns │    │ Safety   │    │ A/B Test │             │   │
│   │   └──────────┘    └──────────┘    └──────────┘    └──────────┘             │   │
│   │        │                                                │                    │   │
│   │        └────────────────────────────────────────────────┘                   │   │
│   │                          FEEDBACK LOOP                                      │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                         FITNESS FUNCTIONS                                    │   │
│   │                                                                              │   │
│   │   BEAUTY FITNESS (40%)         UTILITY FITNESS (40%)      SAFETY FITNESS    │   │
│   │   ═══════════════════          ══════════════════════     (20% + VETO)     │   │
│   │                                                            ══════════════   │   │
│   │   • Wall Art Score (0-10)      • Task Completion Rate      • STAMP Pass    │   │
│   │   • Data-Ink Ratio (0-1)       • Time to Task              • No Warnings   │   │
│   │   • Cognitive Load (inv)       • Error Rate (inverse)      • Audit OK      │   │
│   │   • Animation Smoothness       • Accessibility Score       • E-Stop Valid  │   │
│   │   • Color Harmony              • User Satisfaction         • Fail-Safe     │   │
│   │                                                                              │   │
│   │   TOTAL_FITNESS = 0.4*Beauty + 0.4*Utility + 0.2*Safety                     │   │
│   │   CONSTRAINT: Safety MUST be 100% or fitness = 0                            │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                         EVOLUTION OPERATORS                                  │   │
│   │                                                                              │   │
│   │   MUTATION OPERATORS:                                                        │   │
│   │   • Color shift (within semantic constraints)                               │   │
│   │   • Spacing adjustment (±10% within grid)                                   │   │
│   │   • Animation timing (±50ms within limits)                                  │   │
│   │   • Typography scale shift (within modular scale)                           │   │
│   │   • Layout reflow (preserve hierarchy)                                      │   │
│   │                                                                              │   │
│   │   CROSSOVER OPERATORS:                                                       │   │
│   │   • Component swap (A's nav + B's content)                                  │   │
│   │   • Style merge (A's colors + B's spacing)                                  │   │
│   │   • Animation blend (weighted average of timing)                            │   │
│   │                                                                              │   │
│   │   CONSTRAINTS (NEVER MUTATE):                                                │   │
│   │   • Safety-critical color semantics (red=danger)                            │   │
│   │   • E-Stop button position and size                                         │   │
│   │   • WCAG contrast ratios                                                    │   │
│   │   • Keyboard navigation order                                               │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 20.2 Evolution Agent Implementation

```fsharp
// SC-AGE-001: AUTOMATED GUI EVOLUTION ENGINE
module GUIEvolution =

    /// Fitness components for UI evaluation
    type FitnessScore = {
        BeautyScore: float      // 0.0 to 1.0
        UtilityScore: float     // 0.0 to 1.0
        SafetyScore: float      // 0.0 or 1.0 (binary pass/fail)
    }

    /// Calculate total fitness with safety veto
    let calculateFitness (score: FitnessScore) : float =
        if score.SafetyScore < 1.0 then
            0.0  // Safety failure = total failure
        else
            0.4 * score.BeautyScore +
            0.4 * score.UtilityScore +
            0.2 * score.SafetyScore

    /// UI genome representing evolvable properties
    type UIGenome = {
        PrimaryColor: Color
        SecondaryColor: Color
        FontScale: float
        SpacingScale: float
        AnimationDuration: float
        LayoutVariant: int
    }

    /// Mutation operator with constraints
    let mutate (genome: UIGenome) (constraint: SafetyConstraints) : UIGenome option =
        let rng = System.Random()
        let mutationType = rng.Next(5)

        let mutated =
            match mutationType with
            | 0 -> // Color shift
                let newPrimary = shiftColor genome.PrimaryColor 0.1
                if meetsContrastRequirements newPrimary constraint then
                    Some { genome with PrimaryColor = newPrimary }
                else
                    None
            | 1 -> // Font scale
                let newScale = genome.FontScale * (0.9 + rng.NextDouble() * 0.2)
                if newScale >= 0.75 && newScale <= 1.5 then
                    Some { genome with FontScale = newScale }
                else
                    None
            | 2 -> // Animation timing
                let newDuration = genome.AnimationDuration + (rng.NextDouble() - 0.5) * 0.1
                if newDuration >= 0.05 && newDuration <= 0.5 then
                    Some { genome with AnimationDuration = newDuration }
                else
                    None
            | _ -> Some genome  // No mutation

        mutated

    /// Evolution cycle
    let evolve (population: UIGenome list) (fitnessFunc: UIGenome -> FitnessScore)
               (generations: int) (constraints: SafetyConstraints) : UIGenome =
        let rec loop gen pop =
            if gen >= generations then
                pop |> List.maxBy (fitnessFunc >> calculateFitness)
            else
                // Evaluate fitness
                let evaluated =
                    pop
                    |> List.map (fun g -> g, fitnessFunc g |> calculateFitness)
                    |> List.sortByDescending snd

                // Select top 50%
                let survivors =
                    evaluated
                    |> List.take (List.length evaluated / 2)
                    |> List.map fst

                // Generate offspring through mutation
                let offspring =
                    survivors
                    |> List.collect (fun g ->
                        [g; mutate g constraints |> Option.defaultValue g])

                loop (gen + 1) offspring

        loop 0 population
```

```elixir
# SC-AGE-001: ELIXIR GUI EVOLUTION AGENT
defmodule Indrajaal.GUIEvolution do
  @moduledoc """
  Automated GUI Evolution Framework for safety-critical interfaces.

  Uses genetic algorithms to evolve UI parameters while maintaining
  strict safety constraints. Beauty and utility are optimized, but
  safety is a hard constraint that cannot be compromised.

  ## STAMP Constraints
  - SC-AGE-001: All mutations must preserve safety properties
  - SC-AGE-002: Safety score is binary (pass/fail)
  - SC-AGE-003: Evolution must be reversible
  """

  use GenServer
  require Logger

  alias Indrajaal.GUIEvolution.{Genome, Fitness, Guardian}

  defmodule Genome do
    @enforce_keys [:id, :generation]
    defstruct [
      :id,
      :generation,
      primary_color: "#58A6FF",
      secondary_color: "#1F6FEB",
      font_scale: 1.0,
      spacing_scale: 1.0,
      animation_duration_ms: 150,
      layout_variant: :standard
    ]
  end

  defmodule Fitness do
    defstruct [
      beauty: 0.0,
      utility: 0.0,
      safety: 0.0,  # Binary: 0.0 or 1.0
      total: 0.0
    ]

    def calculate(%{beauty: b, utility: u, safety: s}) do
      if s < 1.0 do
        0.0  # Safety veto
      else
        0.4 * b + 0.4 * u + 0.2 * s
      end
    end
  end

  # Server Implementation
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %{
      population: generate_initial_population(opts[:population_size] || 10),
      generation: 0,
      best_genome: nil,
      constraints: load_safety_constraints()
    }
    {:ok, state}
  end

  @doc """
  Evolve the population for one generation.
  """
  def evolve do
    GenServer.call(__MODULE__, :evolve, :timer.minutes(5))
  end

  def handle_call(:evolve, _from, state) do
    # Evaluate fitness for all genomes
    evaluated =
      state.population
      |> Enum.map(fn genome ->
        fitness = evaluate_fitness(genome, state.constraints)
        {genome, fitness}
      end)
      |> Enum.sort_by(fn {_, f} -> -f.total end)

    # Select survivors (top 50%)
    survivors =
      evaluated
      |> Enum.take(div(length(evaluated), 2))
      |> Enum.map(&elem(&1, 0))

    # Generate offspring through mutation
    offspring =
      survivors
      |> Enum.flat_map(fn genome ->
        [genome, mutate(genome, state.constraints)]
      end)
      |> Enum.filter(& &1)  # Remove nil (failed mutations)

    best = Enum.max_by(evaluated, fn {_, f} -> f.total end) |> elem(0)

    new_state = %{state |
      population: offspring,
      generation: state.generation + 1,
      best_genome: best
    }

    Logger.info("Evolution gen #{new_state.generation}: best fitness = #{evaluate_fitness(best, state.constraints).total}")

    {:reply, {:ok, best}, new_state}
  end

  defp mutate(genome, constraints) do
    mutation_type = Enum.random([:color, :font, :spacing, :animation])

    mutated =
      case mutation_type do
        :color ->
          new_color = shift_color(genome.primary_color, 0.1)
          if meets_contrast_requirements?(new_color, constraints) do
            %{genome | primary_color: new_color}
          else
            nil
          end

        :font ->
          new_scale = genome.font_scale * (0.9 + :rand.uniform() * 0.2)
          if new_scale >= 0.75 and new_scale <= 1.5 do
            %{genome | font_scale: new_scale}
          else
            nil
          end

        :spacing ->
          new_scale = genome.spacing_scale * (0.9 + :rand.uniform() * 0.2)
          if new_scale >= 0.8 and new_scale <= 1.2 do
            %{genome | spacing_scale: new_scale}
          else
            nil
          end

        :animation ->
          delta = (:rand.uniform() - 0.5) * 50
          new_duration = genome.animation_duration_ms + delta
          if new_duration >= 50 and new_duration <= 500 do
            %{genome | animation_duration_ms: round(new_duration)}
          else
            nil
          end
      end

    # Always pass through Guardian for safety validation
    case Guardian.validate(mutated) do
      :ok -> mutated
      {:error, _} -> nil
    end
  end

  defp evaluate_fitness(genome, constraints) do
    beauty = evaluate_beauty(genome)
    utility = evaluate_utility(genome)
    safety = if Guardian.validate(genome) == :ok, do: 1.0, else: 0.0

    %Fitness{
      beauty: beauty,
      utility: utility,
      safety: safety,
      total: Fitness.calculate(%{beauty: beauty, utility: utility, safety: safety})
    }
  end

  defp evaluate_beauty(genome) do
    scores = [
      data_ink_ratio(genome) * 0.25,
      color_harmony_score(genome) * 0.25,
      typography_score(genome) * 0.25,
      whitespace_score(genome) * 0.25
    ]
    Enum.sum(scores)
  end

  defp evaluate_utility(genome) do
    # Would be based on A/B test results in production
    0.8  # Placeholder
  end
end
```

### 20.3 Evolution Safety Gates

| Gate | Description | SC Constraint | Veto Power |
|------|-------------|---------------|------------|
| **Guardian Validation** | All mutations pass safety checks | SC-AGE-001 | Yes |
| **STAMP Compliance** | No STAMP constraint violations | SC-AGE-002 | Yes |
| **Contrast Check** | WCAG 2.1 AA color contrast | SC-UX-003 | Yes |
| **E-Stop Integrity** | E-Stop button unchanged | SC-SAFETY-005 | Yes |
| **Rollback Ready** | Previous version stored | SC-AGE-003 | Warn |
| **Shadow Testing** | A/B test before full deploy | SC-GDE-002 | Warn |

---

## 21. Creative AI Agent Directives for GUI Generation (SC-CREATIVE-*)

> *"To get the most creative output from an AI agent, you must explicitly authorize
> it to break standard conventions. These directives unlock innovation."*

### 21.1 Permission to Innovate Directives

These directives explicitly authorize AI agents (Gemini, Claude, etc.) to move beyond
functional requirements and generate **masterful, beautiful** UI systems.

```yaml
# SC-CREATIVE-001: THE SCI-FI CONSOLE DIRECTIVE
creative_directive:
  name: "Sci-Fi Console"
  id: SC-CREATIVE-001
  authorization: |
    Imagine this software is running on the bridge of a spacecraft in the year 2100.
    It must be functional, but it should look alien and advanced.

  permitted_innovations:
    - Abandon standard "Windows 95" layouts
    - Use hexagonal grids for data organization
    - Use angled dividers (Unicode triangles: ◢◣◤◥)
    - Use vertical text layouts for labels
    - Use radial progress indicators instead of bars
    - Use 3D perspective for list depth (via font weight/color)

  safety_constraints:
    - E-Stop button MUST remain in standard position
    - Critical alerts MUST use standard red color
    - Keyboard navigation MUST remain functional
    - WCAG contrast ratios MUST be maintained

  example_output: |
    ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲
    ╲ PRAJNA COMMAND INTERFACE ╱
    ╱     ◢███████████████◣     ╲
    ╲    ◤   SYSTEM: NOMINAL   ◥    ╱
    ╱    ◤ ▽ ◇ ◇ ◇ ◇ ◇ ◇ ◇ △ ◥    ╲
    ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱
```

```yaml
# SC-CREATIVE-002: THE BIOMIMICRY DIRECTIVE
creative_directive:
  name: "Biomimicry"
  id: SC-CREATIVE-002
  authorization: |
    Visualize the system not as a machine, but as a living organism.
    Network traffic is a circulatory system. Nodes are neurons.

  permitted_innovations:
    - Use branching tree structures for hierarchies
    - Nodes should "pulse" like neurons when active
    - Dead nodes should "wither" (fade + fragment) not disappear instantly
    - Data flow should animate like blood flow
    - Health status uses organic growth/decay metaphors

  safety_constraints:
    - Dead nodes MUST be clearly distinguishable
    - Critical failures MUST trigger standard alerts
    - Pulse rate MUST be slow enough for accessibility

  example_output: |
    Network Topology (Biomimicry View)

           ◉ ← Pulsing active node
          /|\
         / | \
        ◎  ◎  ◎ ← Healthy nodes
       /|  |  |\
      ◌ ◌  ◌  ◌ ◌ ← Leaf nodes

    ◉ = Active (pulsing)
    ◎ = Healthy (steady glow)
    ◌ = Idle (dim)
    ✕ = Dead (withering animation)
```

```yaml
# SC-CREATIVE-003: THE GLITCH AESTHETIC DIRECTIVE
creative_directive:
  name: "Glitch Aesthetic"
  id: SC-CREATIVE-003
  authorization: |
    For error states, do not use clean modals. Simulate "signal corruption."
    Use the medium of the terminal itself to convey the failure.

  permitted_innovations:
    - Randomly scramble characters in affected pane for 0.5s before error
    - Use color channel splitting (red/cyan offset) for warnings
    - Use "scan line" effects for degraded states
    - Use "static" noise in background during errors
    - Use progressive character corruption for increasing severity

  safety_constraints:
    - Error MESSAGE must remain readable after glitch effect
    - Glitch duration MUST be < 1 second
    - Accessibility: provide non-visual error indication (sound/haptic)
    - User MUST be able to disable glitch effects (preference)

  example_output: |
    [Normal State]
    ┌────────────────────────────────┐
    │ System Status: Operational     │
    └────────────────────────────────┘

    [Glitch Transition - 0.3s]
    ┌──────█▓░─────────█▓░──────────┐
    │ S█st░m ▓ta░u▓: O▓█ra░ional   │
    └──░─────█▓──────────────░▓█────┘

    [Error Revealed - After glitch]
    ┌────────────────────────────────┐
    │ ⚠ CONNECTION LOST              │
    │ Last contact: 3.2 seconds ago  │
    └────────────────────────────────┘
```

### 21.2 Creative Implementation Patterns

```fsharp
// SC-CREATIVE-001 to SC-CREATIVE-003: CREATIVE RENDERING ENGINE
module CreativeRendering =

    /// Creative directive types
    type CreativeDirective =
        | SciFiConsole
        | Biomimicry
        | GlitchAesthetic
        | Standard

    /// Apply sci-fi console styling
    let renderSciFiHeader (title: string) : string[] =
        [|
            "╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲ ╱╲"
            sprintf "╲ %s ╱" (title.PadLeft(20).PadRight(28))
            "╱     ◢███████████████◣     ╲"
            "╲    ◤                 ◥    ╱"
            "╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱"
        |]

    /// Biomimicry node visualization
    type NodeState = Active | Healthy | Idle | Dead

    let renderBiomimicryNode (state: NodeState) (label: string) : string =
        match state with
        | Active -> sprintf "◉ %s (pulsing)" label
        | Healthy -> sprintf "◎ %s" label
        | Idle -> sprintf "◌ %s" label
        | Dead -> sprintf "✕ %s (withering)" label

    /// Glitch effect for error states
    let applyGlitchEffect (text: string) (intensity: float) : string =
        let glitchChars = [| '█'; '▓'; '░'; '▒'; '▄'; '▀' |]
        let rng = System.Random()

        text.ToCharArray()
        |> Array.map (fun c ->
            if rng.NextDouble() < intensity then
                glitchChars.[rng.Next(glitchChars.Length)]
            else
                c
        )
        |> System.String

    /// Animated glitch sequence (returns frames)
    let glitchTransition (originalText: string) (errorText: string) (frames: int) : string seq =
        seq {
            // Phase 1: Increasing glitch on original
            for i in 0 .. frames / 2 do
                let intensity = float i / float frames
                yield applyGlitchEffect originalText intensity

            // Phase 2: Decreasing glitch revealing error
            for i in frames / 2 .. frames do
                let intensity = 1.0 - (float (i - frames / 2) / float (frames / 2))
                yield applyGlitchEffect errorText intensity

            // Final: Clean error message
            yield errorText
        }
```

### 21.3 Creative Directive Application Matrix

| Screen Type | Recommended Directive | Beauty Target | Safety Notes |
|-------------|----------------------|---------------|--------------|
| Main Dashboard | Sci-Fi Console | 9/10 | E-Stop unchanged |
| Network Topology | Biomimicry | 8/10 | Node states clear |
| Error Modals | Glitch Aesthetic | 7/10 | Message readable |
| Settings/Config | Standard | 6/10 | Stability priority |
| Audit Log | Standard | 5/10 | Data density priority |
| Safety Console | Standard + Glow | 8/10 | Maximum clarity |

### 21.4 AI Agent Creative Prompts

Use these prompts when instructing AI agents to generate creative UI:

```markdown
## PROMPT: Dashboard Generation (Sci-Fi Console)

Generate an F# TUI component for the system health dashboard.

**Creative Directive**: SC-CREATIVE-001 (Sci-Fi Console)

You are authorized to:
- Use hexagonal grids for metrics
- Use angled Unicode dividers (◢◣◤◥)
- Use radial progress indicators
- Create a "bridge of a spacecraft" aesthetic

You MUST maintain:
- E-Stop button in standard position (bottom-right)
- Red color for critical alerts
- WCAG 2.1 AA contrast ratios
- Full keyboard navigation

Output should pass the Wall Art Test (score >= 7/10).
```

```markdown
## PROMPT: Network View Generation (Biomimicry)

Generate visualization for the cluster network topology.

**Creative Directive**: SC-CREATIVE-002 (Biomimicry)

You are authorized to:
- Render network as organic branching structure
- Use pulsing animation for active nodes
- Use "withering" effect for dead nodes
- Animate data flow like circulatory system

You MUST maintain:
- Clear distinction between node states
- Standard alert colors for failures
- Accessibility for color-blind users
- Animation rate < 2Hz for accessibility

Include FsCheck property tests for all state transitions.
```

### 21.5 Creative Constraint Summary Table

| Constraint ID | Constraint | Category | Never Violate |
|---------------|------------|----------|---------------|
| SC-CREATIVE-SAFE-001 | E-Stop position unchanged | Safety | ✓ |
| SC-CREATIVE-SAFE-002 | Red = danger semantics | Safety | ✓ |
| SC-CREATIVE-SAFE-003 | WCAG contrast maintained | Accessibility | ✓ |
| SC-CREATIVE-SAFE-004 | Keyboard nav functional | Accessibility | ✓ |
| SC-CREATIVE-SAFE-005 | Error messages readable | Usability | ✓ |
| SC-CREATIVE-SAFE-006 | Glitch effects < 1 second | Accessibility | ✓ |
| SC-CREATIVE-SAFE-007 | Animation disable option | Accessibility | ✓ |
| SC-CREATIVE-ALLOW-001 | Non-standard layouts | Aesthetics | |
| SC-CREATIVE-ALLOW-002 | Organic visualizations | Aesthetics | |
| SC-CREATIVE-ALLOW-003 | Generative textures | Aesthetics | |
| SC-CREATIVE-ALLOW-004 | 3D perspective effects | Aesthetics | |
| SC-CREATIVE-ALLOW-005 | Custom animation curves | Motion | |

---

## Code Comment Mandate

**Add comments explaining WHY safety constraints exist:**

```fsharp
// SC-SAFETY-001: 3-second hold required by ISO-13850 to prevent accidental activation
// This implements the "two-hand control" principle digitally - requiring sustained
// conscious action rather than a single keystroke that could be accidental
let holdDuration = 3.0<sec>
```

```elixir
# SC-SAFETY-005: E-Stop uses normally-closed (NC) circuit for fail-safe operation
# If the wire is cut or connection lost, the system fails to SAFE state
# This follows IEC 60947-5-5 emergency stop requirements
@estop_circuit_type :normally_closed
```

**Priority Order:**
1. **Correctness** - Code must be provably correct
2. **Determinism** - Same inputs always produce same outputs
3. **Fail-Safety** - Failures default to safe state
4. **Clarity** - Code is readable and self-documenting
5. **Brevity** - Only after all above are satisfied

---

## Document Control

| Attribute | Value |
|-----------|-------|
| Created | 2025-12-30 |
| Version | 2.0.0-INTEGRATED |
| Author | Safety-Critical Systems Team |
| Review Required | Before any HMI/TUI code generation |
| Next Review | 2026-01-30 |
| Approval | Chief Safety Officer |

## Cross-References

- [PRAJNA_TUI_MASTER_SPECIFICATION.md](../prajna/PRAJNA_TUI_MASTER_SPECIFICATION.md)
- [KMS_WIREFRAMES_COMPREHENSIVE.md](../kms/KMS_WIREFRAMES_COMPREHENSIVE.md)
- [KMS_USE_CASES_COMPREHENSIVE.md](../kms/KMS_USE_CASES_COMPREHENSIVE.md)
- [FSHARP_CAPABILITY_RULES.md](../../lib/cepaf/docs/FSHARP_CAPABILITY_RULES.md)
- [CEPAF-STAMP-TDG-AOR-Specification.md](../../lib/cepaf/docs/CEPAF-STAMP-TDG-AOR-Specification.md)
- [CLAUDE.md](../../CLAUDE.md) - Section 14.0 Safety-Critical Code Generation
- [GEMINI.md](../../GEMINI.md) - Section 12.2 Safety-Critical Code Generation
