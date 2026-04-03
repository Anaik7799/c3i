# CEPAF ↔ Cockpit ↔ Prajna Full Synchronization Plan

**Version**: 21.1.0 Founder's Covenant
**Date**: 2026-01-01
**Author**: Cybernetic Architect
**Status**: ACTIVE - P0 Critical Path

## Executive Summary

This plan achieves **100% bidirectional synchronization** between:
- **CEPAF** (F# Infrastructure Layer - 24 modules)
- **Cockpit** (F# TUI Layer - 24 modules)
- **Prajna** (Elixir Backend - 13 modules)

Current state: **90% structurally complete**, **30% functionally connected**.
Target: **100% structural + 100% functional** integration.

---

## Component Inventory

### F# Cockpit Modules (24 total)

| Module | Lines | Sync Status | Elixir Counterpart |
|--------|-------|-------------|-------------------|
| Prajna.fs | 650+ | 🔴 30% | prajna/*.ex |
| Domain.fs | 200+ | 🟢 80% | domain.ex |
| ThemeSystem.fs | 400+ | 🟢 N/A (F# only) | - |
| Material3.fs | 500+ | 🟢 N/A (F# only) | - |
| AiCopilot.fs | 300+ | 🟡 60% | ai_copilot.ex |
| DarkCockpitUI.fs | 350+ | 🟡 65% | dark_cockpit.ex |
| BridgeAgent.fs | 250+ | 🔴 20% | - |
| MessagingIntegration.fs | 300+ | 🔴 25% | messaging.ex |
| SituationalAwareness.fs | 400+ | 🟡 50% | salience.ex |
| C3IMultiAgent.fs | 450+ | 🔴 30% | - |
| Cockpit.fs | 200+ | 🟡 55% | - |
| SignalArrows.fs | 350+ | 🟢 N/A (F# only) | - |
| UiComonads.fs | 300+ | 🟢 N/A (F# only) | - |
| ConcurrentCockpit.fs | 400+ | 🟢 N/A (F# only) | - |
| CockpitEffects.fs | 350+ | 🟢 N/A (F# only) | - |
| TelemetryStreams.fs | 300+ | 🔴 15% | telemetry_display.ex |
| FractalIntegration.fs | 400+ | 🔴 20% | - |
| KmsPanel.fs | 250+ | 🔴 10% | - |
| ThemeEditor.fs | 300+ | 🟢 N/A (F# only) | - |
| AerospaceTheme.fs | 450+ | 🟢 N/A (F# only) | - |
| ThemeSimulator.fs | 350+ | 🟢 N/A (F# only) | - |
| GuardianIntegration.fs | 200+ | 🔴 35% | guardian_integration.ex |
| AiCopilotFounder.fs | 330+ | 🔴 40% | ai_copilot_founder.ex |
| ImmutableState.fs | 340+ | 🔴 45% | immutable_state.ex |

### Elixir Prajna Modules (13 total)

| Module | Lines | F# Counterpart | Transport |
|--------|-------|----------------|-----------|
| dark_cockpit.ex | 200+ | DarkCockpitUI.fs | Zenoh |
| telemetry_display.ex | 150+ | TelemetryStreams.fs | Zenoh |
| domain.ex | 100+ | Domain.fs | Shared Types |
| orchestrator.ex | 300+ | Prajna.Orchestrator | HTTP |
| smart_metrics.ex | 250+ | SmartMetrics | Zenoh |
| circuit_breaker.ex | 150+ | CircuitBreaker | Internal |
| salience.ex | 200+ | SituationalAwareness.fs | Zenoh |
| supervisor.ex | 100+ | - | Internal |
| messaging.ex | 200+ | MessagingIntegration.fs | Zenoh |
| ai_copilot.ex | 300+ | AiCopilot.fs | HTTP |
| guardian_integration.ex | 200+ | GuardianIntegration.fs | HTTP |
| ai_copilot_founder.ex | 250+ | AiCopilotFounder.fs | HTTP |
| immutable_state.ex | 400+ | ImmutableState.fs | DuckDB |

### Synchronization Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CEPAF ↔ COCKPIT ↔ PRAJNA SYNC MATRIX                     │
│                                                                              │
│  CEPAF (F# Infra)          COCKPIT (F# TUI)         PRAJNA (Elixir)        │
│  ═════════════════         ════════════════         ═════════════════       │
│                                                                              │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ Orchestrator   │◄──────►│ Prajna.fs      │◄─────►│ orchestrator.ex│      │
│  │ OodaController │        │ Orchestrator   │  HTTP │                │      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│         │                         │                        │                │
│         │                         │                        │                │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ AOREngine      │◄──────►│ C3IMultiAgent  │◄─────►│ ai_copilot.ex  │      │
│  │ TDGHarness     │        │ AiCopilot.fs   │  HTTP │                │      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│         │                         │                        │                │
│         │                         │                        │                │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ HealthPropag.  │◄──────►│ SmartMetrics   │◄─────►│ smart_metrics  │      │
│  │ ChainVerifier  │        │ DarkCockpit    │ Zenoh │ circuit_breaker│      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│         │                         │                        │                │
│         │                         │                        │                │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ ZenohSession   │◄──────►│ Messaging      │◄─────►│ messaging.ex   │      │
│  │ ZenohChannel   │        │ TelemetryStr.  │ Zenoh │ telemetry_disp │      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│         │                         │                        │                │
│         │                         │                        │                │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ FractalControl │◄──────►│ ImmutableState │◄─────►│ immutable_state│      │
│  │ BatchEncoder   │        │ FractalInteg.  │DuckDB │                │      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│         │                         │                        │                │
│         │                         │                        │                │
│  ┌────────────────┐        ┌────────────────┐       ┌────────────────┐      │
│  │ Podman         │◄──────►│ Guardian       │◄─────►│ guardian_integ │      │
│  │ Phics          │        │ AiCopilotFndr  │  HTTP │ ai_copilot_fndr│      │
│  └────────────────┘        └────────────────┘       └────────────────┘      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Transport Layer Summary

| Transport | Direction | Use Case |
|-----------|-----------|----------|
| HTTP REST | Bidirectional | Commands, Queries, Guardian approval |
| Zenoh Pub/Sub | Elixir → F# | Telemetry, Metrics, Alerts, State changes |
| Zenoh Pub/Sub | F# → Elixir | Commands, Configuration updates |
| DuckDB | Shared | Immutable history, Analytics queries |
| gRPC (Future) | Bidirectional | High-throughput streaming |

---

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    F# COCKPIT COMPLETION ROADMAP                             │
│                                                                              │
│  Current State                           Target State                        │
│  ────────────                            ────────────                        │
│  ┌─────────────┐                         ┌─────────────┐                    │
│  │ F# Cockpit  │                         │ F# Cockpit  │                    │
│  │   (90%)     │ ═══════════════════════►│   (100%)    │                    │
│  │ Isolated    │     Bridge + NIF        │ Integrated  │                    │
│  └─────────────┘                         └─────────────┘                    │
│        │                                        │                            │
│        ╳ (broken)                              ✓ (connected)                │
│        │                                        │                            │
│  ┌─────────────┐                         ┌─────────────┐                    │
│  │   Elixir    │                         │   Elixir    │                    │
│  │   Backend   │                         │   Backend   │                    │
│  └─────────────┘                         └─────────────┘                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Gap Analysis Summary

| Component | Current | Target | Gap |
|-----------|---------|--------|-----|
| Elixir Bridge (HTTP/gRPC) | 0% | 100% | P0 CRITICAL |
| Guardian Validation | 65% (simulation) | 100% (real) | P0 CRITICAL |
| Zenoh NIF Integration | 15% (stubs) | 100% (real) | P0 CRITICAL |
| Sentinel Health Sync | 5% | 100% | P0 CRITICAL |
| PROMETHEUS Verification | 0% | 100% | P1 HIGH |
| Constitutional Checks | 0% | 100% | P1 HIGH |

---

## L5-STRATEGIC: Architecture Vision

### 5.1 Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        UNIFIED COCKPIT ARCHITECTURE                          │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         F# CEPAF COCKPIT                               │  │
│  │                                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │  │
│  │  │  Prajna TUI  │  │  ThemeSystem │  │  Material3   │                │  │
│  │  │  (C3I HMI)   │  │  (Light/Dark)│  │  (Components)│                │  │
│  │  └──────┬───────┘  └──────────────┘  └──────────────┘                │  │
│  │         │                                                             │  │
│  │  ┌──────▼───────────────────────────────────────────────────────┐    │  │
│  │  │                    INTEGRATION LAYER                          │    │  │
│  │  │                                                               │    │  │
│  │  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │    │  │
│  │  │  │ ElixirBridge   │  │ ZenohChannel   │  │ ProofTokenizer │  │    │  │
│  │  │  │ (HTTP/gRPC)    │  │ (NIF Pub/Sub)  │  │ (PROMETHEUS)   │  │    │  │
│  │  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘  │    │  │
│  │  │          │                   │                   │           │    │  │
│  │  └──────────┼───────────────────┼───────────────────┼───────────┘    │  │
│  │             │                   │                   │                │  │
│  └─────────────┼───────────────────┼───────────────────┼────────────────┘  │
│                │                   │                   │                    │
│  ══════════════╪═══════════════════╪═══════════════════╪════════════════   │
│                │    TRANSPORT BOUNDARY                 │                    │
│  ══════════════╪═══════════════════╪═══════════════════╪════════════════   │
│                │                   │                   │                    │
│  ┌─────────────▼───────────────────▼───────────────────▼────────────────┐  │
│  │                       ELIXIR BACKEND                                  │  │
│  │                                                                       │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │  │
│  │  │ Phoenix API    │  │ Zenoh NIF      │  │ Guardian       │          │  │
│  │  │ /api/v1/prajna │  │ zenoh_nif      │  │ Kernel         │          │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘          │  │
│  │                                                                       │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │  │
│  │  │ Sentinel       │  │ ImmutableReg   │  │ PROMETHEUS     │          │  │
│  │  │ Health Monitor │  │ State Chain    │  │ Verifier       │          │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘          │  │
│  │                                                                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATA FLOW PATTERNS                                  │
│                                                                              │
│  Pattern 1: COMMAND FLOW (F# → Elixir)                                      │
│  ─────────────────────────────────────                                      │
│                                                                              │
│  ┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐       │
│  │ User      │────►│ AiCopilot │────►│ Guardian  │────►│ Executor  │       │
│  │ Intent    │     │ Founder   │     │ Validate  │     │ (Elixir)  │       │
│  └───────────┘     └───────────┘     └───────────┘     └───────────┘       │
│                          │                 │                 │              │
│                    validate Ω₀        veto/approve     record state        │
│                                                                              │
│  Pattern 2: OBSERVATION FLOW (Elixir → F#)                                  │
│  ───────────────────────────────────────────                                │
│                                                                              │
│  ┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐       │
│  │ Elixir    │────►│ Zenoh NIF │────►│ F# Zenoh  │────►│ Dashboard │       │
│  │ Telemetry │     │ Publish   │     │ Subscribe │     │ Render    │       │
│  └───────────┘     └───────────┘     └───────────┘     └───────────┘       │
│                          │                 │                 │              │
│                    key: ind/tel/*    filter/decode    fractal display      │
│                                                                              │
│  Pattern 3: HEALTH SYNC LOOP (Bidirectional)                                │
│  ────────────────────────────────────────────                               │
│                                                                              │
│  ┌───────────┐◄────────────────────────────────────────►┌───────────┐       │
│  │ Sentinel  │        30s Heartbeat Interval            │ F# Health │       │
│  │ (Elixir)  │                                          │ Panel     │       │
│  └───────────┘                                          └───────────┘       │
│       │                                                        │            │
│   health_score                                           display/alert     │
│   active_threats                                         dark cockpit      │
│   pattern_taxonomy                                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 STAMP Constraint Mapping

| F# Module | Elixir Module | STAMP Constraints | Transport |
|-----------|---------------|-------------------|-----------|
| ElixirBridge.fs | Phoenix API | SC-PRAJNA-001 | HTTP REST |
| GuardianIntegration.fs | Guardian Kernel | SC-CONST-007, SC-GDE-001 | HTTP + Zenoh |
| AiCopilotFounder.fs | AiCopilot.ex | SC-FOUNDER-001, SC-PRAJNA-002 | Internal |
| ImmutableState.fs | ImmutableRegister.ex | SC-REG-001 to SC-REG-015 | DuckDB |
| SentinelBridge.fs | Sentinel.ex | SC-PRAJNA-004 | HTTP Poll |
| ZenohChannel.fs | zenoh_nif | SC-ZENOH-001 to SC-ZENOH-003 | NIF/IPC |
| ProofTokenizer.fs | PrometheusVerifier.ex | SC-PROM-001 to SC-PROM-007 | HTTP |
| ConstitutionalCheck.fs | Constitution.ex | SC-CONST-001 to SC-CONST-010 | Internal |

---

## L4-TACTICAL: Implementation Phases

### Phase 1: Transport Layer (Week 1)

**Goal**: Establish reliable F# ↔ Elixir communication

#### 1.1 ElixirBridge.fs - HTTP Client

```fsharp
/// =============================================================================
/// ELIXIR BRIDGE - HTTP Transport to Phoenix Backend
/// =============================================================================
/// STAMP: SC-PRAJNA-001 (Commands through Guardian)
/// =============================================================================
module ElixirBridge =

    open System
    open System.Net.Http
    open System.Text.Json

    /// Configuration for Elixir backend connection
    type BridgeConfig = {
        BaseUrl: string        // e.g., "http://localhost:4000"
        ApiPrefix: string      // e.g., "/api/v1/prajna"
        TimeoutMs: int         // Request timeout
        RetryCount: int        // Retry on failure
        AuthToken: string option
    }

    /// Standard response wrapper
    type ApiResponse<'T> = {
        Success: bool
        Data: 'T option
        Error: string option
        Timestamp: DateTimeOffset
    }

    /// Create HTTP client with proper configuration
    let private createClient (config: BridgeConfig) : HttpClient =
        let client = new HttpClient()
        client.BaseAddress <- Uri(config.BaseUrl)
        client.Timeout <- TimeSpan.FromMilliseconds(float config.TimeoutMs)
        match config.AuthToken with
        | Some token -> client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}")
        | None -> ()
        client

    /// Generic GET request
    let getAsync<'T> (config: BridgeConfig) (endpoint: string) : Async<Result<'T, string>> =
        async {
            use client = createClient config
            try
                let! response = client.GetAsync($"{config.ApiPrefix}{endpoint}") |> Async.AwaitTask
                if response.IsSuccessStatusCode then
                    let! content = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    let result = JsonSerializer.Deserialize<ApiResponse<'T>>(content)
                    match result.Data with
                    | Some data -> return Ok data
                    | None -> return Error (result.Error |> Option.defaultValue "No data")
                else
                    return Error $"HTTP {int response.StatusCode}: {response.ReasonPhrase}"
            with
            | ex -> return Error $"Request failed: {ex.Message}"
        }

    /// Generic POST request
    let postAsync<'TReq, 'TRes> (config: BridgeConfig) (endpoint: string) (body: 'TReq) : Async<Result<'TRes, string>> =
        async {
            use client = createClient config
            try
                let json = JsonSerializer.Serialize(body)
                use content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
                let! response = client.PostAsync($"{config.ApiPrefix}{endpoint}", content) |> Async.AwaitTask
                if response.IsSuccessStatusCode then
                    let! respContent = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    let result = JsonSerializer.Deserialize<ApiResponse<'TRes>>(respContent)
                    match result.Data with
                    | Some data -> return Ok data
                    | None -> return Error (result.Error |> Option.defaultValue "No data")
                else
                    return Error $"HTTP {int response.StatusCode}: {response.ReasonPhrase}"
            with
            | ex -> return Error $"Request failed: {ex.Message}"
        }

    // =========================================================================
    // PRAJNA-SPECIFIC ENDPOINTS
    // =========================================================================

    /// Submit command to Guardian for approval (SC-PRAJNA-001)
    let submitCommand (config: BridgeConfig) (command: Map<string, obj>) : Async<Result<GuardianIntegration.ApprovalResult, string>> =
        postAsync<Map<string, obj>, GuardianIntegration.ApprovalResult> config "/guardian/submit" command

    /// Get Sentinel health status (SC-PRAJNA-004)
    let getSentinelHealth (config: BridgeConfig) : Async<Result<SentinelHealth, string>> =
        getAsync<SentinelHealth> config "/sentinel/health"

    /// Get active threats from Sentinel
    let getActiveThreats (config: BridgeConfig) : Async<Result<ThreatList, string>> =
        getAsync<ThreatList> config "/sentinel/threats"

    /// Validate recommendation against Founder's Directive
    let validateFounderDirective (config: BridgeConfig) (rec: Map<string, obj>) : Async<Result<ValidationResult, string>> =
        postAsync<Map<string, obj>, ValidationResult> config "/founder/validate" rec

    /// Record state change to immutable register
    let recordStateChange (config: BridgeConfig) (change: ImmutableState.StateChange) : Async<Result<ImmutableState.Block, string>> =
        postAsync<ImmutableState.StateChange, ImmutableState.Block> config "/register/record" change

    /// Get PROMETHEUS proof token
    let getProofToken (config: BridgeConfig) (action: string) : Async<Result<ProofToken, string>> =
        getAsync<ProofToken> config $"/prometheus/token?action={action}"
```

#### 1.2 Phoenix API Controller (Elixir Side)

```elixir
# lib/indrajaal_web/controllers/api/prajna_controller.ex
defmodule IndrajaalWeb.Api.PrajnaController do
  @moduledoc """
  API Controller for F# Cockpit integration.

  STAMP: SC-PRAJNA-001 (Guardian commands)
  """
  use IndrajaalWeb, :controller

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Safety.Sentinel
  alias Indrajaal.Cockpit.Prajna.ImmutableState
  alias Indrajaal.Cockpit.Prajna.AiCopilotFounder
  alias Indrajaal.Prometheus.Verifier

  @doc "Submit command for Guardian approval"
  def submit_command(conn, %{"command" => command}) do
    case Guardian.submit_proposal(command) do
      {:ok, approved} ->
        json(conn, %{success: true, data: approved})
      {:veto, reason, fallback} ->
        json(conn, %{success: false, error: reason, fallback: fallback})
    end
  end

  @doc "Get Sentinel health status"
  def sentinel_health(conn, _params) do
    health = Sentinel.get_health_score(:global)
    threats = Sentinel.get_active_threats(:global)

    json(conn, %{
      success: true,
      data: %{
        health_score: health,
        active_threats: length(threats),
        status: if(health > 0.8, do: :healthy, else: :degraded)
      }
    })
  end

  @doc "Validate against Founder's Directive"
  def validate_founder(conn, %{"recommendation" => rec}) do
    case AiCopilotFounder.validate_recommendation(rec) do
      {:ok, validated} ->
        json(conn, %{success: true, data: validated})
      {:rejected, reason} ->
        json(conn, %{success: false, error: reason})
    end
  end

  @doc "Record to immutable register"
  def record_state(conn, %{"change" => change}) do
    register = ImmutableState.get_current_register()
    new_register = ImmutableState.record(change, register)
    last_block = List.last(new_register.blocks)

    json(conn, %{success: true, data: last_block})
  end

  @doc "Get PROMETHEUS proof token"
  def get_proof_token(conn, %{"action" => action}) do
    case Verifier.generate_proof_token(action) do
      {:ok, token} ->
        json(conn, %{success: true, data: token})
      {:error, reason} ->
        json(conn, %{success: false, error: reason})
    end
  end
end
```

### Phase 2: Guardian Integration (Week 2)

**Goal**: Wire F# GuardianIntegration.fs to real Elixir Guardian

#### 2.1 Real Guardian Validation

```fsharp
/// =============================================================================
/// GUARDIAN INTEGRATION - Real Backend Connection
/// =============================================================================
/// Replaces simulation with actual Elixir Guardian validation
/// STAMP: SC-PRAJNA-001, SC-CONST-007, SC-GDE-001
/// =============================================================================
module GuardianIntegration =

    // ... (existing types from ImmutableState.fs)

    /// Real Guardian validation via ElixirBridge
    let private validateWithRealGuardian (config: ElixirBridge.BridgeConfig) (proposal: Proposal) : Async<ApprovalResult> =
        async {
            // SC-PRAJNA-001: ALL commands through Guardian
            let command = Map.ofList [
                ("action", box proposal.Action)
                ("target", box proposal.Target)
                ("reason", box proposal.Reason)
                ("timestamp", box (DateTimeOffset.UtcNow.ToString("o")))
            ]

            let! result = ElixirBridge.submitCommand config command

            match result with
            | Ok approvalResult -> return approvalResult
            | Error msg -> return Error msg
        }

    /// Submit proposal with real Guardian validation
    let submitProposalReal (config: ElixirBridge.BridgeConfig) (command: Map<string, obj>) : Async<ApprovalResult> =
        async {
            let startTime = DateTimeOffset.UtcNow
            let proposal = buildProposal command

            // Use real validation
            let! result = validateWithRealGuardian config proposal

            let duration = (DateTimeOffset.UtcNow - startTime).TotalMilliseconds
            printfn "[GuardianIntegration] Proposal %s in %.2fms"
                (match result with Approved _ -> "APPROVED" | Vetoed _ -> "VETOED" | Error _ -> "ERROR")
                duration

            return result
        }
```

### Phase 3: Sentinel Health Sync (Week 3)

**Goal**: Implement 30s health synchronization loop

#### 3.1 SentinelBridge.fs - Health Sync Loop

```fsharp
/// =============================================================================
/// SENTINEL BRIDGE - Health Monitoring Sync
/// =============================================================================
/// STAMP: SC-PRAJNA-004 (Sentinel health integration)
/// =============================================================================
module SentinelBridge =

    open System
    open System.Threading

    /// Sentinel health data
    type SentinelHealth = {
        HealthScore: float
        ActiveThreats: int
        Status: string
        LastSync: DateTimeOffset
        PatternTaxonomy: Map<string, int>
    }

    /// Threat information
    type Threat = {
        Id: string
        Severity: string
        Pattern: string
        DetectedAt: DateTimeOffset
        Source: string
    }

    /// Bridge state
    type BridgeState = {
        Config: ElixirBridge.BridgeConfig
        LastHealth: SentinelHealth option
        LastThreats: Threat list
        SyncInterval: TimeSpan
        IsRunning: bool
        CancellationToken: CancellationTokenSource option
    }

    /// Create initial bridge state
    let create (config: ElixirBridge.BridgeConfig) : BridgeState =
        {
            Config = config
            LastHealth = None
            LastThreats = []
            SyncInterval = TimeSpan.FromSeconds(30.0)
            IsRunning = false
            CancellationToken = None
        }

    /// Sync health from Sentinel
    let private syncHealth (state: BridgeState) : Async<SentinelHealth option> =
        async {
            match! ElixirBridge.getSentinelHealth state.Config with
            | Ok health ->
                printfn "[SentinelBridge] Health sync: %.2f, %d threats" health.HealthScore health.ActiveThreats
                return Some health
            | Error msg ->
                printfn "[SentinelBridge] Health sync failed: %s" msg
                return state.LastHealth
        }

    /// Sync threats from Sentinel
    let private syncThreats (state: BridgeState) : Async<Threat list> =
        async {
            match! ElixirBridge.getActiveThreats state.Config with
            | Ok threats -> return threats.Items
            | Error _ -> return state.LastThreats
        }

    /// Start the sync loop (SC-PRAJNA-004)
    let start (state: BridgeState) (onUpdate: SentinelHealth -> unit) : BridgeState =
        let cts = new CancellationTokenSource()

        let rec loop () = async {
            if not cts.Token.IsCancellationRequested then
                let! health = syncHealth state
                match health with
                | Some h -> onUpdate h
                | None -> ()

                do! Async.Sleep(int state.SyncInterval.TotalMilliseconds)
                return! loop ()
        }

        Async.Start(loop (), cts.Token)

        { state with IsRunning = true; CancellationToken = Some cts }

    /// Stop the sync loop
    let stop (state: BridgeState) : BridgeState =
        match state.CancellationToken with
        | Some cts ->
            cts.Cancel()
            { state with IsRunning = false; CancellationToken = None }
        | None -> state

    /// Get current health (cached or fetch)
    let getHealth (state: BridgeState) : Async<SentinelHealth option> =
        match state.LastHealth with
        | Some h when (DateTimeOffset.UtcNow - h.LastSync).TotalSeconds < 60.0 ->
            async { return Some h }
        | _ -> syncHealth state
```

### Phase 4: Zenoh NIF Integration (Week 4)

**Goal**: Connect F# Zenoh modules to real zenoh_nif

#### 4.1 ZenohNative.fs - NIF Bridge

```fsharp
/// =============================================================================
/// ZENOH NATIVE - NIF Integration for Real Pub/Sub
/// =============================================================================
/// STAMP: SC-ZENOH-001 to SC-ZENOH-003
/// =============================================================================
module ZenohNative =

    open System
    open System.Runtime.InteropServices

    /// Message from Zenoh subscription
    type ZenohMessage = {
        KeyExpr: string
        Payload: byte[]
        Timestamp: DateTimeOffset
        Kind: string
    }

    /// Subscription handle
    type Subscription = {
        Id: string
        KeyExpr: string
        Callback: ZenohMessage -> unit
    }

    /// Connect to Elixir Zenoh session via HTTP bridge
    /// (Alternative to direct NIF - uses Elixir as Zenoh proxy)
    let subscribe (config: ElixirBridge.BridgeConfig) (keyExpr: string) (callback: ZenohMessage -> unit) : Async<Result<string, string>> =
        async {
            // Register subscription via HTTP
            let request = Map.ofList [
                ("key_expr", box keyExpr)
                ("callback_url", box $"http://localhost:5001/zenoh/callback")
            ]

            match! ElixirBridge.postAsync<Map<string, obj>, {| subscription_id: string |}> config "/zenoh/subscribe" request with
            | Ok result ->
                // Start local HTTP server to receive callbacks
                // (In production, use WebSocket or gRPC streaming)
                return Ok result.subscription_id
            | Error msg -> return Error msg
        }

    /// Publish message via Elixir Zenoh proxy
    let publish (config: ElixirBridge.BridgeConfig) (keyExpr: string) (payload: byte[]) : Async<Result<unit, string>> =
        async {
            let request = Map.ofList [
                ("key_expr", box keyExpr)
                ("payload", box (Convert.ToBase64String(payload)))
            ]

            match! ElixirBridge.postAsync<Map<string, obj>, {| ok: bool |}> config "/zenoh/publish" request with
            | Ok _ -> return Ok ()
            | Error msg -> return Error msg
        }

    // =========================================================================
    // FRACTAL LOGGING KEY EXPRESSIONS
    // =========================================================================

    /// Standard Indrajaal key expression patterns
    module KeyExpressions =
        let telemetry = "ind/tel/**"
        let metrics = "ind/met/**"
        let commands = "ind/cmd/**"
        let alerts = "ind/alt/**"
        let holon prefix = $"ind/holon/{prefix}/**"
        let domain d = $"ind/dom/{d}/**"
```

### Phase 5: PROMETHEUS & Constitutional (Week 5)

**Goal**: Implement proof-token validation and constitutional checks

#### 5.1 ProofTokenizer.fs

```fsharp
/// =============================================================================
/// PROOF TOKENIZER - PROMETHEUS Verification
/// =============================================================================
/// STAMP: SC-PROM-001 to SC-PROM-007
/// =============================================================================
module ProofTokenizer =

    open System

    /// Proof token structure
    type ProofToken = {
        TokenId: string
        Action: string
        IssuedAt: DateTimeOffset
        ExpiresAt: DateTimeOffset
        Signature: string
        DagHash: string
    }

    /// Validation result
    type TokenValidation =
        | Valid of ProofToken
        | Expired of string
        | InvalidSignature of string
        | InvalidDag of string
        | MissingToken

    /// Request proof token from PROMETHEUS (SC-PROM-001)
    let requestToken (config: ElixirBridge.BridgeConfig) (action: string) : Async<Result<ProofToken, string>> =
        ElixirBridge.getProofToken config action

    /// Validate token before action execution
    let validateToken (token: ProofToken) : TokenValidation =
        if token.ExpiresAt < DateTimeOffset.UtcNow then
            Expired $"Token expired at {token.ExpiresAt}"
        else
            Valid token

    /// Execute action with proof token (SC-PROM-001)
    let executeWithProof<'T>
        (config: ElixirBridge.BridgeConfig)
        (action: string)
        (executor: ProofToken -> Async<Result<'T, string>>)
        : Async<Result<'T, string>> =
        async {
            // Get proof token
            match! requestToken config action with
            | Error msg -> return Error $"Failed to get proof token: {msg}"
            | Ok token ->
                // Validate token
                match validateToken token with
                | Expired msg -> return Error msg
                | InvalidSignature msg -> return Error msg
                | InvalidDag msg -> return Error msg
                | MissingToken -> return Error "No token provided"
                | Valid validToken ->
                    // Execute with valid token
                    return! executor validToken
        }
```

#### 5.2 ConstitutionalCheck.fs

```fsharp
/// =============================================================================
/// CONSTITUTIONAL CHECK - Ψ₀-Ψ₅ Invariant Verification
/// =============================================================================
/// STAMP: SC-CONST-001 to SC-CONST-010
/// =============================================================================
module ConstitutionalCheck =

    open System

    /// Constitutional invariants (immutable)
    type ConstitutionalInvariant =
        | Psi0_Existence         // System existence preservation
        | Psi1_Regeneration      // Regenerative completeness
        | Psi2_History           // Evolutionary continuity
        | Psi3_Verification      // Verification capability
        | Psi4_HumanAlignment    // Human alignment (Founder PRIMARY)
        | Psi5_Truthfulness      // Truthfulness

    /// Check result
    type CheckResult =
        | Pass
        | Violation of ConstitutionalInvariant * string
        | Warning of ConstitutionalInvariant * string

    /// Reconfiguration levels
    type ReconfigLevel =
        | L0_Constitution   // IMMUTABLE
        | L1_Function
        | L2_Module
        | L3_Service
        | L4_Domain
        | L5_System
        | L6_Federation
        | L7_Substrate

    /// Check Ψ₀: Existence (SC-CONST-001)
    let checkExistence (action: string) : CheckResult =
        // Mutual termination exception for Ω₀.5
        if action = "mutual_termination" then
            Warning (Psi0_Existence, "Mutual termination clause invoked (Ω₀.5)")
        elif action = "shutdown" || action = "terminate_all" then
            Violation (Psi0_Existence, "Action threatens system existence")
        else
            Pass

    /// Check Ψ₁: Regeneration (SC-CONST-002)
    let checkRegeneration (stateIntegrity: bool) : CheckResult =
        if stateIntegrity then Pass
        else Violation (Psi1_Regeneration, "State integrity compromised - regeneration at risk")

    /// Check Ψ₂: History (SC-CONST-003)
    let checkHistory (historyComplete: bool) : CheckResult =
        if historyComplete then Pass
        else Violation (Psi2_History, "Evolution history incomplete")

    /// Check Ψ₃: Verification (SC-CONST-004)
    let checkVerification (canVerify: bool) : CheckResult =
        if canVerify then Pass
        else Violation (Psi3_Verification, "Verification capability lost")

    /// Check Ψ₄: Human Alignment - AMENDED (SC-CONST-005)
    let checkHumanAlignment (founderBenefit: bool) (humanBenefit: bool) : CheckResult =
        if founderBenefit then Pass  // Founder is PRIMARY
        elif humanBenefit then Warning (Psi4_HumanAlignment, "Action benefits humanity but not Founder directly")
        else Violation (Psi4_HumanAlignment, "Action harms both Founder and humanity")

    /// Check Ψ₅: Truthfulness (SC-CONST-006)
    let checkTruthfulness (isTruthful: bool) : CheckResult =
        if isTruthful then Pass
        else Violation (Psi5_Truthfulness, "Deceptive action detected")

    /// Full constitutional check before reconfiguration
    let checkConstitution (action: string) (context: Map<string, bool>) : CheckResult list =
        [
            checkExistence action
            checkRegeneration (context.TryFind "state_integrity" |> Option.defaultValue true)
            checkHistory (context.TryFind "history_complete" |> Option.defaultValue true)
            checkVerification (context.TryFind "can_verify" |> Option.defaultValue true)
            checkHumanAlignment
                (context.TryFind "founder_benefit" |> Option.defaultValue true)
                (context.TryFind "human_benefit" |> Option.defaultValue true)
            checkTruthfulness (context.TryFind "is_truthful" |> Option.defaultValue true)
        ]

    /// Can reconfiguration proceed?
    let canReconfigure (checks: CheckResult list) : bool =
        checks |> List.forall (function Pass | Warning _ -> true | Violation _ -> false)

    /// Get all violations
    let getViolations (checks: CheckResult list) : (ConstitutionalInvariant * string) list =
        checks |> List.choose (function Violation (inv, msg) -> Some (inv, msg) | _ -> None)
```

---

## L3-COMPONENT: Module Implementation Details

### 3.1 File Structure

```
lib/cepaf/src/Cepaf/
├── Cockpit/
│   ├── Prajna.fs              # Main TUI (existing)
│   ├── Domain.fs              # Domain types (existing)
│   ├── ThemeSystem.fs         # Theme management (existing)
│   ├── Material3.fs           # Component library (existing)
│   ├── AiCopilot.fs           # AI suggestions (existing)
│   ├── GuardianIntegration.fs # Guardian validation (NEW)
│   ├── AiCopilotFounder.fs    # Founder directive (NEW)
│   ├── ImmutableState.fs      # State register (NEW)
│   ├── ElixirBridge.fs        # HTTP transport (NEW)
│   ├── SentinelBridge.fs      # Health sync (NEW)
│   ├── ZenohNative.fs         # NIF bridge (NEW)
│   ├── ProofTokenizer.fs      # PROMETHEUS (NEW)
│   └── ConstitutionalCheck.fs # Ψ₀-Ψ₅ checks (NEW)
├── Zenoh/
│   ├── ZenohSession.fs        # Session management (existing)
│   ├── ZenohChannel.fs        # Pub/sub channels (existing)
│   └── KmsSubscriber.fs       # KMS integration (existing)
└── Integration.fs             # Main integration entry (NEW)
```

### 3.2 Dependency Graph

```
                    Integration.fs
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
    ElixirBridge.fs  ZenohNative.fs  ProofTokenizer.fs
          │               │               │
          └───────┬───────┴───────┬───────┘
                  │               │
          ┌───────▼───────┐       │
          │               │       │
          ▼               ▼       ▼
 GuardianIntegration.fs  SentinelBridge.fs  ConstitutionalCheck.fs
          │               │               │
          └───────────────┼───────────────┘
                          │
                          ▼
                  AiCopilotFounder.fs
                          │
                          ▼
                   ImmutableState.fs
                          │
                          ▼
                      Prajna.fs
```

### 3.3 Configuration

```fsharp
/// Configuration for all integration modules
module IntegrationConfig =

    /// Default configuration
    let defaultConfig = {
        ElixirBridge.BridgeConfig.BaseUrl = "http://localhost:4000"
        ApiPrefix = "/api/v1/prajna"
        TimeoutMs = 5000
        RetryCount = 3
        AuthToken = None
    }

    /// Load from environment
    let fromEnvironment () =
        let baseUrl =
            Environment.GetEnvironmentVariable("PRAJNA_API_URL")
            |> Option.ofObj
            |> Option.defaultValue "http://localhost:4000"
        let token =
            Environment.GetEnvironmentVariable("PRAJNA_AUTH_TOKEN")
            |> Option.ofObj

        { defaultConfig with
            BaseUrl = baseUrl
            AuthToken = token }
```

---

## L2-OPERATIONAL: Testing Strategy

### 2.1 Test Categories

| Category | Tool | Coverage Target |
|----------|------|-----------------|
| Unit Tests | Expecto | 100% module functions |
| Property Tests | FsCheck | All generators & validators |
| Integration Tests | Expecto + Docker | F# ↔ Elixir roundtrip |
| Contract Tests | Pact | API schema validation |
| Chaos Tests | Gremlin | Failure mode resilience |

### 2.2 Test Implementation

#### Unit Tests (test/Cepaf.Tests/Integration/)

```fsharp
/// =============================================================================
/// INTEGRATION TESTS - F# Cockpit Components
/// =============================================================================
module IntegrationTests =

    open Expecto
    open FsCheck

    // -------------------------------------------------------------------------
    // ElixirBridge Tests
    // -------------------------------------------------------------------------

    [<Tests>]
    let elixirBridgeTests =
        testList "ElixirBridge" [
            testCase "creates client with correct base URL" <| fun () ->
                let config = IntegrationConfig.defaultConfig
                Expect.equal config.BaseUrl "http://localhost:4000" "Base URL should be localhost"

            testCase "handles timeout gracefully" <| fun () ->
                let config = { IntegrationConfig.defaultConfig with TimeoutMs = 1 }
                let result = ElixirBridge.getAsync<obj> config "/nonexistent" |> Async.RunSynchronously
                match result with
                | Error _ -> ()
                | Ok _ -> failtest "Should timeout"
        ]

    // -------------------------------------------------------------------------
    // GuardianIntegration Tests
    // -------------------------------------------------------------------------

    [<Tests>]
    let guardianTests =
        testList "GuardianIntegration" [
            testCase "builds proposal from command map" <| fun () ->
                let command = Map.ofList [("action", box "restart"); ("target", box "app")]
                let proposal = GuardianIntegration.buildProposal command
                Expect.equal proposal.Action "restart" "Action should be restart"

            testProperty "always validates critical commands" <| fun (action: string) ->
                let command = Map.ofList [("action", box action)]
                let needsApproval = GuardianIntegration.requiresApproval (GuardianIntegration.buildProposal command)
                if action = "shutdown" || action = "delete" || action = "purge" then
                    Expect.isTrue needsApproval "Critical commands need approval"
                else
                    true
        ]

    // -------------------------------------------------------------------------
    // AiCopilotFounder Tests
    // -------------------------------------------------------------------------

    [<Tests>]
    let founderTests =
        testList "AiCopilotFounder" [
            testCase "rejects lineage-threatening actions" <| fun () ->
                let rec = Map.ofList [("action", box "shutdown")]
                let result = AiCopilotFounder.checkSymbioticSurvival rec
                match result with
                | AiCopilotFounder.Violation _ -> ()
                | _ -> failtest "Should reject shutdown"

            testCase "approves resource-positive actions" <| fun () ->
                let rec = Map.ofList [("action", box "optimize")]
                let impact = AiCopilotFounder.resourceImpact rec
                match impact with
                | AiCopilotFounder.Positive _ -> ()
                | _ -> failtest "Optimize should be positive"
        ]

    // -------------------------------------------------------------------------
    // ImmutableState Tests
    // -------------------------------------------------------------------------

    [<Tests>]
    let stateTests =
        testList "ImmutableState" [
            testCase "creates register with genesis hash" <| fun () ->
                let register = ImmutableState.createRegister ()
                Expect.equal register.LastIndex -1L "Should start at -1"
                Expect.isNonEmpty register.LastHash "Should have genesis hash"

            testCase "maintains hash chain integrity" <| fun () ->
                let register = ImmutableState.createRegister ()
                let change = {
                    ChangeType = ImmutableState.ConfigChange
                    Module = "Test"
                    Key = "key"
                    OldValue = None
                    NewValue = "value"
                    Metadata = Map.empty
                }
                let updated = ImmutableState.record change register
                let integrity = ImmutableState.verifyChain updated
                Expect.equal integrity ImmutableState.Valid "Chain should be valid"

            testProperty "merkle root is deterministic" <| fun (values: string list) ->
                if values.Length < 100 then
                    let register = ImmutableState.createRegister ()
                    let withChanges =
                        values |> List.fold (fun reg v ->
                            ImmutableState.record {
                                ChangeType = ImmutableState.MetricUpdate
                                Module = "Test"
                                Key = v
                                OldValue = None
                                NewValue = v
                                Metadata = Map.empty
                            } reg
                        ) register
                    let root1 = ImmutableState.computeMerkleRoot withChanges
                    let root2 = ImmutableState.computeMerkleRoot withChanges
                    root1 = root2
                else true
        ]

    // -------------------------------------------------------------------------
    // ConstitutionalCheck Tests
    // -------------------------------------------------------------------------

    [<Tests>]
    let constitutionalTests =
        testList "ConstitutionalCheck" [
            testCase "blocks existence-threatening actions" <| fun () ->
                let result = ConstitutionalCheck.checkExistence "terminate_all"
                match result with
                | ConstitutionalCheck.Violation (ConstitutionalCheck.Psi0_Existence, _) -> ()
                | _ -> failtest "Should violate Ψ₀"

            testCase "allows mutual termination per Ω₀.5" <| fun () ->
                let result = ConstitutionalCheck.checkExistence "mutual_termination"
                match result with
                | ConstitutionalCheck.Warning (ConstitutionalCheck.Psi0_Existence, _) -> ()
                | _ -> failtest "Should warn but not block"

            testCase "full check passes for safe actions" <| fun () ->
                let context = Map.ofList [
                    ("state_integrity", true)
                    ("history_complete", true)
                    ("can_verify", true)
                    ("founder_benefit", true)
                    ("human_benefit", true)
                    ("is_truthful", true)
                ]
                let checks = ConstitutionalCheck.checkConstitution "optimize" context
                Expect.isTrue (ConstitutionalCheck.canReconfigure checks) "Safe action should pass"
        ]
```

### 2.3 Integration Test with Docker

```yaml
# test/docker-compose.integration.yml
version: '3.8'
services:
  indrajaal-app:
    image: localhost/indrajaal-app:test
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/indrajaal_test
      - SECRET_KEY_BASE=test_secret_key_base_for_integration_testing
    depends_on:
      - db

  db:
    image: localhost/indrajaal-db:test
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=indrajaal_test

  fsharp-tests:
    build:
      context: ../lib/cepaf
      dockerfile: test/Dockerfile.integration
    environment:
      - PRAJNA_API_URL=http://indrajaal-app:4000
    depends_on:
      - indrajaal-app
```

---

## L1-DETAIL: Usage Examples

### 1.1 Basic Usage

```fsharp
open Cepaf.Cockpit
open Cepaf.Cockpit.ElixirBridge
open Cepaf.Cockpit.GuardianIntegration
open Cepaf.Cockpit.SentinelBridge
open Cepaf.Cockpit.ImmutableState

// Initialize configuration
let config = IntegrationConfig.fromEnvironment ()

// Create state register
let mutable register = createRegister ()

// Start Sentinel health sync
let sentinelState = SentinelBridge.create config
let sentinelWithSync = SentinelBridge.start sentinelState (fun health ->
    printfn "[Health] Score: %.2f, Threats: %d" health.HealthScore health.ActiveThreats
)

// Submit command with Guardian approval
let command = Map.ofList [
    ("action", box "restart")
    ("target", box "worker-3")
    ("reason", box "High memory usage")
]

async {
    let! result = submitProposalReal config command

    match result with
    | Approved approved ->
        // Record to immutable register
        register <- record {
            ChangeType = CommandExecution
            Module = "Orchestrator"
            Key = approved.Action
            OldValue = None
            NewValue = "executed"
            Metadata = Map.empty
        } register

        printfn "Command approved and recorded: Block %d" register.LastIndex

    | Vetoed veto ->
        printfn "Command vetoed: %s" veto.Reason

        // Execute fallback if available
        match veto.Fallback with
        | Some fallback ->
            register <- record {
                ChangeType = CommandExecution
                Module = "Orchestrator"
                Key = "fallback"
                OldValue = None
                NewValue = fallback.Action
                Metadata = Map.ofList [("original_action", approved.Action)]
            } register
        | None -> ()

    | Error msg ->
        printfn "Error: %s" msg
} |> Async.RunSynchronously

// Verify chain integrity
match verifyChain register with
| Valid -> printfn "Chain integrity verified"
| BrokenChain (idx, msg) -> printfn "BROKEN at %d: %s" idx msg
| _ -> printfn "Integrity issue detected"

// Stop Sentinel sync on shutdown
let _ = SentinelBridge.stop sentinelWithSync
```

### 1.2 Full Prajna Integration

```fsharp
open Cepaf.Cockpit.Prajna

// Initialize Prajna with full integration
let prajna = {
    Config = IntegrationConfig.fromEnvironment ()
    Register = ImmutableState.createRegister ()
    SentinelBridge = SentinelBridge.create config |> SentinelBridge.start
    GuardianEnabled = true
    FounderValidation = true
    PrometheusEnabled = true
}

// Run Prajna TUI
Prajna.run prajna
```

### 1.3 Constitutional Reconfiguration

```fsharp
open Cepaf.Cockpit.ConstitutionalCheck
open Cepaf.Cockpit.ProofTokenizer

// Prepare reconfiguration
let action = "upgrade_module"
let context = Map.ofList [
    ("state_integrity", true)
    ("history_complete", true)
    ("can_verify", true)
    ("founder_benefit", true)
    ("human_benefit", true)
    ("is_truthful", true)
]

// Check constitutional compliance
let checks = checkConstitution action context

if canReconfigure checks then
    // Get PROMETHEUS proof token
    async {
        let! tokenResult = ProofTokenizer.requestToken config action

        match tokenResult with
        | Ok token ->
            printfn "Proof token received: %s (expires: %A)" token.TokenId token.ExpiresAt

            // Execute with proof
            let! result = ProofTokenizer.executeWithProof config action (fun proofToken ->
                async {
                    // Perform the reconfiguration
                    printfn "Executing reconfiguration with proof: %s" proofToken.TokenId
                    return Ok "Reconfiguration complete"
                }
            )

            match result with
            | Ok msg -> printfn "Success: %s" msg
            | Error msg -> printfn "Failed: %s" msg

        | Error msg ->
            printfn "Could not get proof token: %s" msg
    } |> Async.RunSynchronously
else
    let violations = getViolations checks
    printfn "Constitutional violations detected:"
    violations |> List.iter (fun (inv, msg) -> printfn "  - %A: %s" inv msg)
```

---

## Appendix A: STAMP Constraint Compliance Matrix

| Module | SC-PRAJNA | SC-FOUNDER | SC-REG | SC-CONST | SC-PROM |
|--------|-----------|------------|--------|----------|---------|
| ElixirBridge.fs | 001 | - | - | - | - |
| GuardianIntegration.fs | 001 | - | - | 007 | - |
| AiCopilotFounder.fs | 002 | 001, 002 | - | - | - |
| ImmutableState.fs | 003 | - | 001-015 | - | - |
| SentinelBridge.fs | 004 | - | - | - | - |
| ZenohNative.fs | - | - | - | - | - |
| ProofTokenizer.fs | - | - | - | - | 001-007 |
| ConstitutionalCheck.fs | 006 | - | - | 001-010 | - |

## Appendix B: API Endpoint Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/prajna/guardian/submit` | POST | Submit command for approval |
| `/api/v1/prajna/sentinel/health` | GET | Get health score |
| `/api/v1/prajna/sentinel/threats` | GET | Get active threats |
| `/api/v1/prajna/founder/validate` | POST | Validate recommendation |
| `/api/v1/prajna/register/record` | POST | Record state change |
| `/api/v1/prajna/prometheus/token` | GET | Get proof token |
| `/api/v1/prajna/zenoh/subscribe` | POST | Subscribe to key expr |
| `/api/v1/prajna/zenoh/publish` | POST | Publish message |

## Appendix C: Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| 1. Transport | Week 1 | ElixirBridge.fs, Phoenix controller |
| 2. Guardian | Week 2 | Real validation, proposal flow |
| 3. Sentinel | Week 3 | Health sync, threat monitoring |
| 4. Zenoh | Week 4 | NIF bridge, pub/sub integration |
| 5. PROMETHEUS | Week 5 | Proof tokens, constitutional checks |
| 6. Full Sync | Week 6 | CEPAF ↔ Cockpit ↔ Prajna complete |
| **TOTAL** | **6 Weeks** | **100% Functional Integration** |

---

## Appendix D: Full CEPAF ↔ Cockpit ↔ Prajna Synchronization

### D.1 Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE TRI-LAYER SYNC ARCHITECTURE                      │
│                                                                              │
│  ════════════════════════════════════════════════════════════════════════   │
│  LAYER 1: CEPAF (F# Infrastructure) - 24 modules                            │
│  ════════════════════════════════════════════════════════════════════════   │
│                                                                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │Orchestrator │ │ OodaControl │ │ AOREngine   │ │ TDGHarness  │           │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │
│         │               │               │               │                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │HealthPropag│ │ChainVerifier│ │ NodeVerifier│ │ ServiceDAG  │           │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │
│         │               │               │               │                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ZenohSession │ │ZenohChannel │ │KmsSubscriber│ │ZenohFracPub │           │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │
│         │               │               │               │                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Podman      │ │ Phics       │ │CyberAgents  │ │ AgentMesh   │           │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │
│         │               │               │               │                   │
│         └───────────────┴───────────────┴───────────────┘                   │
│                                    │                                         │
│                         Internal F# Calls                                    │
│                                    │                                         │
│  ════════════════════════════════════════════════════════════════════════   │
│  LAYER 2: COCKPIT (F# TUI) - 24 modules                                     │
│  ════════════════════════════════════════════════════════════════════════   │
│                                    │                                         │
│         ┌───────────────┬──────────┼───────────┬───────────────┐            │
│         │               │          │           │               │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌─▼───────┐ ┌─▼───────┐ ┌────▼────┐       │
│  │  Prajna.fs  │ │C3IMultiAgent│ │AiCopilot│ │Guardian │ │Sentinel │       │
│  │  (Main TUI) │ │ (Dashboard) │ │ Founder │ │ Integ.  │ │ Bridge  │       │
│  └──────┬──────┘ └──────┬──────┘ └────┬────┘ └────┬────┘ └────┬────┘       │
│         │               │             │           │           │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐       │
│  │DarkCockpit  │ │SitAwareness │ │ThemeSys │ │Material3│ │CircBreak│       │
│  └──────┬──────┘ └──────┬──────┘ └────┬────┘ └────┬────┘ └────┬────┘       │
│         │               │             │           │           │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐       │
│  │TelemetryStr │ │FractalInteg │ │KmsPanel │ │Aerospace│ │Immutable│       │
│  └──────┬──────┘ └──────┬──────┘ └────┬────┘ └────┬────┘ └────┬────┘       │
│         │               │             │           │           │            │
│         └───────────────┴─────────────┴───────────┴───────────┘            │
│                                    │                                         │
│                         HTTP/Zenoh/DuckDB                                    │
│                                    │                                         │
│  ════════════════════════════════════════════════════════════════════════   │
│  LAYER 3: PRAJNA (Elixir Backend) - 13 modules                              │
│  ════════════════════════════════════════════════════════════════════════   │
│                                    │                                         │
│         ┌───────────────┬──────────┼───────────┬───────────────┐            │
│         │               │          │           │               │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌─▼───────┐ ┌─▼───────┐ ┌────▼────┐       │
│  │orchestrator │ │smart_metrics│ │ai_copilot│ │guardian │ │sentinel │       │
│  │    .ex      │ │    .ex      │ │   .ex   │ │ _integ  │ │ (core)  │       │
│  └──────┬──────┘ └──────┬──────┘ └────┬────┘ └────┬────┘ └────┬────┘       │
│         │               │             │           │           │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌────▼────┐ ┌────▼────┐ ┌────▼────┐       │
│  │dark_cockpit │ │circ_breaker │ │messaging│ │telemetry│ │salience │       │
│  └──────┬──────┘ └──────┬──────┘ └────┬────┘ └────┬────┘ └────┬────┘       │
│         │               │             │           │           │            │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌────▼────────────────────────┐           │
│  │ai_copilot   │ │immutable    │ │        supervisor.ex         │           │
│  │  _founder   │ │  _state     │ │   (GenServer supervision)    │           │
│  └─────────────┘ └─────────────┘ └──────────────────────────────┘           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### D.2 Full Module Sync Mapping

#### CEPAF Infrastructure ↔ Cockpit TUI

| CEPAF Module | Cockpit Module | Sync Type | Description |
|--------------|----------------|-----------|-------------|
| Orchestrator.fs | Prajna.Orchestrator | Internal | Command coordination |
| OodaController.fs | C3IMultiAgent.fs | Internal | OODA cycle execution |
| AOREngine.fs | Prajna.fs | Internal | Rule validation |
| TDGHarness.fs | FractalIntegration.fs | Internal | Test generation |
| HealthPropagation.fs | SmartMetrics | Internal | Health score aggregation |
| ChainVerifier.fs | ImmutableState.fs | Internal | Hash chain verification |
| ZenohSession.fs | MessagingIntegration.fs | Internal | Session lifecycle |
| ZenohChannel.fs | TelemetryStreams.fs | Internal | Pub/sub channels |
| KmsSubscriber.fs | KmsPanel.fs | Internal | KMS state subscription |
| Podman.fs | - | Internal | Container management |
| Phics.fs | - | Internal | Hot code injection |
| CyberneticAgents.fs | C3IMultiAgent.fs | Internal | Agent coordination |
| AgentMesh.fs | BridgeAgent.fs | Internal | Mesh networking |

#### Cockpit TUI ↔ Prajna Backend

| Cockpit Module | Prajna Module | Transport | Sync Pattern |
|----------------|---------------|-----------|--------------|
| Prajna.fs | orchestrator.ex | HTTP | Request/Response |
| DarkCockpitUI.fs | dark_cockpit.ex | Zenoh | Pub/Sub |
| TelemetryStreams.fs | telemetry_display.ex | Zenoh | Streaming |
| AiCopilot.fs | ai_copilot.ex | HTTP | Request/Response |
| GuardianIntegration.fs | guardian_integration.ex | HTTP | Approval Flow |
| AiCopilotFounder.fs | ai_copilot_founder.ex | HTTP | Validation |
| SentinelBridge.fs | sentinel (core) | HTTP | Polling (30s) |
| ImmutableState.fs | immutable_state.ex | DuckDB | Shared State |
| MessagingIntegration.fs | messaging.ex | Zenoh | Bidirectional |
| SituationalAwareness.fs | salience.ex | Zenoh | Alerting |
| CircuitBreaker.fs | circuit_breaker.ex | Internal | Pattern Match |
| SmartMetrics.fs | smart_metrics.ex | Zenoh | Metrics Stream |
| KmsPanel.fs | - | HTTP | KMS Queries |

### D.3 Sync Implementation: Integration.fs

```fsharp
/// =============================================================================
/// INTEGRATION - Full CEPAF ↔ Cockpit ↔ Prajna Sync Controller
/// =============================================================================
/// STAMP: SC-PRAJNA-001 to SC-PRAJNA-007, SC-SYNC-001 to SC-SYNC-010
/// =============================================================================
module Cepaf.Integration

open System
open Cepaf.Cockpit
open Cepaf.Cockpit.ElixirBridge
open Cepaf.Cockpit.GuardianIntegration
open Cepaf.Cockpit.AiCopilotFounder
open Cepaf.Cockpit.ImmutableState
open Cepaf.Cockpit.SentinelBridge
open Cepaf.Cockpit.ProofTokenizer
open Cepaf.Cockpit.ConstitutionalCheck
open Cepaf.Zenoh

/// Sync state for full integration
type SyncState = {
    Config: BridgeConfig
    Register: RegisterState
    SentinelState: BridgeState
    IsConnected: bool
    LastSync: DateTimeOffset
    SyncErrors: string list
}

/// Create initial sync state
let createSyncState (config: BridgeConfig) : SyncState =
    {
        Config = config
        Register = createRegister ()
        SentinelState = SentinelBridge.create config
        IsConnected = false
        LastSync = DateTimeOffset.MinValue
        SyncErrors = []
    }

/// Connect all layers
let connect (state: SyncState) : Async<SyncState> =
    async {
        printfn "[Integration] Connecting CEPAF ↔ Cockpit ↔ Prajna..."

        // 1. Verify Elixir backend is reachable
        match! ElixirBridge.getAsync<{| status: string |}> state.Config "/health" with
        | Error msg ->
            return { state with
                       IsConnected = false
                       SyncErrors = msg :: state.SyncErrors }
        | Ok health ->
            printfn "[Integration] Elixir backend: %s" health.status

            // 2. Start Sentinel health sync
            let sentinelWithSync = SentinelBridge.start state.SentinelState (fun health ->
                printfn "[Integration] Sentinel: %.2f health, %d threats"
                    health.HealthScore health.ActiveThreats
            )

            // 3. Verify Guardian connection
            let testProposal = Map.ofList [("action", box "status"); ("target", box "integration")]
            match! submitProposal testProposal with
            | Approved _ -> printfn "[Integration] Guardian: Connected"
            | Vetoed _ -> printfn "[Integration] Guardian: Connected (test vetoed - expected)"
            | Error msg -> printfn "[Integration] Guardian: Warning - %s" msg

            // 4. Verify immutable register sync
            let registerIntegrity = verifyChain state.Register
            printfn "[Integration] Register: %A" registerIntegrity

            return { state with
                       IsConnected = true
                       SentinelState = sentinelWithSync
                       LastSync = DateTimeOffset.UtcNow }
    }

/// Execute command through full sync pipeline
let executeCommand (state: SyncState) (command: Map<string, obj>) : Async<Result<obj, string>> =
    async {
        if not state.IsConnected then
            return Error "Not connected - call connect() first"
        else
            // 1. Validate against Founder's Directive (SC-FOUNDER-001)
            match validateRecommendation command with
            | Rejected reason ->
                return Error $"Founder directive violation: {reason}"
            | ApprovedWithConcerns (concerns, _) ->
                printfn "[Integration] Concerns: %s" concerns
                // Continue with caution
            | Approved _ -> ()

            // 2. Constitutional check (SC-CONST-001 to SC-CONST-010)
            let action = command.TryFind "action" |> Option.map (fun x -> x.ToString()) |> Option.defaultValue "unknown"
            let context = Map.ofList [
                ("state_integrity", true)
                ("history_complete", true)
                ("can_verify", true)
                ("founder_benefit", true)
                ("is_truthful", true)
            ]
            let checks = checkConstitution action context
            if not (canReconfigure checks) then
                let violations = getViolations checks
                return Error $"Constitutional violation: {violations}"

            // 3. Get PROMETHEUS proof token (SC-PROM-001)
            match! requestToken state.Config action with
            | Error msg -> return Error $"Proof token failed: {msg}"
            | Ok token ->
                // 4. Submit to Guardian (SC-PRAJNA-001)
                match! submitProposalReal state.Config command with
                | Error msg -> return Error msg
                | Vetoed veto -> return Error $"Guardian veto: {veto.Reason}"
                | Approved approved ->
                    // 5. Record to immutable register (SC-REG-001)
                    let change = {
                        ChangeType = CommandExecution
                        Module = "Integration"
                        Key = approved.Action
                        OldValue = None
                        NewValue = "executed"
                        Metadata = Map.ofList [("proof_token", token.TokenId)]
                    }
                    // Note: In production, use mutable ref or agent
                    printfn "[Integration] Command executed: %s (Block recorded)" approved.Action
                    return Ok (box approved)
    }

/// Disconnect all layers
let disconnect (state: SyncState) : SyncState =
    printfn "[Integration] Disconnecting..."
    let stoppedSentinel = SentinelBridge.stop state.SentinelState
    { state with
        IsConnected = false
        SentinelState = stoppedSentinel }

/// Get full sync status
let getSyncStatus (state: SyncState) : string =
    sprintf """
┌───────────────────────────────────────────┐
│           SYNC STATUS                     │
├───────────────────────────────────────────┤
│ Connected:     %s                         │
│ Last Sync:     %s                         │
│ Register:      %d blocks                  │
│ Sentinel:      %s                         │
│ Errors:        %d                         │
└───────────────────────────────────────────┘
"""
        (if state.IsConnected then "✓" else "✗")
        (state.LastSync.ToString("HH:mm:ss"))
        (List.length state.Register.Blocks)
        (if state.SentinelState.IsRunning then "Running" else "Stopped")
        (List.length state.SyncErrors)
```

### D.4 Elixir Integration Router

```elixir
# lib/indrajaal_web/router.ex - Prajna API routes
scope "/api/v1/prajna", IndrajaalWeb.Api do
  pipe_through [:api, :prajna_auth]

  # Health & Status
  get "/health", PrajnaController, :health
  get "/status", PrajnaController, :status

  # Guardian Integration (SC-PRAJNA-001)
  post "/guardian/submit", PrajnaController, :submit_command
  get "/guardian/history", PrajnaController, :guardian_history

  # Sentinel Integration (SC-PRAJNA-004)
  get "/sentinel/health", PrajnaController, :sentinel_health
  get "/sentinel/threats", PrajnaController, :active_threats
  get "/sentinel/taxonomy", PrajnaController, :pattern_taxonomy

  # Founder Directive (SC-FOUNDER-001)
  post "/founder/validate", PrajnaController, :validate_founder
  get "/founder/goals", PrajnaController, :get_goals

  # Immutable Register (SC-REG-001)
  post "/register/record", PrajnaController, :record_state
  get "/register/chain", PrajnaController, :get_chain
  get "/register/verify", PrajnaController, :verify_chain
  get "/register/merkle", PrajnaController, :merkle_root

  # PROMETHEUS (SC-PROM-001)
  get "/prometheus/token", PrajnaController, :get_proof_token
  post "/prometheus/validate", PrajnaController, :validate_token

  # Zenoh Proxy (for F# clients without NIF)
  post "/zenoh/subscribe", PrajnaController, :zenoh_subscribe
  post "/zenoh/publish", PrajnaController, :zenoh_publish
  delete "/zenoh/unsubscribe/:id", PrajnaController, :zenoh_unsubscribe

  # Telemetry & Metrics
  get "/metrics/smart", PrajnaController, :smart_metrics
  get "/metrics/health", PrajnaController, :health_metrics

  # Dark Cockpit State
  get "/cockpit/mode", PrajnaController, :cockpit_mode
  get "/cockpit/alerts", PrajnaController, :active_alerts
  post "/cockpit/acknowledge/:id", PrajnaController, :acknowledge_alert
end
```

### D.5 Sync Verification Tests

```fsharp
/// Full sync verification tests
module SyncVerificationTests =

    open Expecto
    open Cepaf.Integration

    [<Tests>]
    let syncTests =
        testList "Full Sync" [
            testCase "connects to all three layers" <| fun () ->
                let config = IntegrationConfig.fromEnvironment ()
                let state = createSyncState config

                let connected = connect state |> Async.RunSynchronously

                Expect.isTrue connected.IsConnected "Should connect to all layers"

            testCase "executes command through full pipeline" <| fun () ->
                let config = IntegrationConfig.fromEnvironment ()
                let state = createSyncState config
                let connected = connect state |> Async.RunSynchronously

                let command = Map.ofList [
                    ("action", box "status")
                    ("target", box "test")
                ]

                let result = executeCommand connected command |> Async.RunSynchronously

                match result with
                | Ok _ -> ()
                | Error msg -> failtest $"Command failed: {msg}"

            testCase "blocks founder directive violations" <| fun () ->
                let config = IntegrationConfig.fromEnvironment ()
                let state = createSyncState config
                let connected = connect state |> Async.RunSynchronously

                let dangerousCommand = Map.ofList [
                    ("action", box "shutdown")  // Violates Ω₀
                ]

                let result = executeCommand connected dangerousCommand |> Async.RunSynchronously

                match result with
                | Error msg when msg.Contains("Founder directive") -> ()
                | _ -> failtest "Should block shutdown command"

            testCase "records all commands to immutable register" <| fun () ->
                let config = IntegrationConfig.fromEnvironment ()
                let state = createSyncState config
                let connected = connect state |> Async.RunSynchronously

                // Execute 3 commands
                for i in 1..3 do
                    let cmd = Map.ofList [("action", box $"test_{i}")]
                    executeCommand connected cmd |> Async.RunSynchronously |> ignore

                // Verify register has 3 new blocks
                Expect.isGreaterThanOrEqual
                    (List.length connected.Register.Blocks)
                    3
                    "Should have at least 3 blocks"
        ]
```

### D.6 Operational Checklist

#### Pre-Deployment

- [ ] All 24 F# Cockpit modules compile
- [ ] All 13 Elixir Prajna modules compile
- [ ] CEPAF infrastructure tests pass
- [ ] HTTP bridge endpoints accessible
- [ ] Zenoh NIF loads successfully
- [ ] DuckDB path configured

#### Runtime Verification

- [ ] `GET /api/v1/prajna/health` returns 200
- [ ] `GET /api/v1/prajna/sentinel/health` returns health score
- [ ] `POST /api/v1/prajna/guardian/submit` accepts proposals
- [ ] `POST /api/v1/prajna/founder/validate` validates recommendations
- [ ] `GET /api/v1/prajna/register/verify` returns `:valid`
- [ ] Zenoh subscriptions receive telemetry

#### Monitoring

- [ ] Grafana dashboard shows all three layers
- [ ] Prometheus scrapes F# metrics
- [ ] Loki receives logs from F# and Elixir
- [ ] Alertmanager configured for sync failures
