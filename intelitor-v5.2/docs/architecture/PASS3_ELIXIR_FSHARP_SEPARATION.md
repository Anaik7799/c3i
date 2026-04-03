# PASS3: Elixir Core vs F# Cortex Separation Matrix

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Document ID**: SEP-21.3.0-001 | **Parent**: FCMS-21.3.0-001

---

## Document Control

| Field | Value |
|-------|-------|
| Classification | INTERNAL |
| Review Cycle | Quarterly |
| Owner | Architecture Team |
| STAMP Coverage | SC-SEP-*, SC-OBS-*, SC-SYNC-* |
| Related | FRACTAL_8LAYER_CHANGE_MANAGEMENT_COMPLETE.md |

---

## Executive Summary

This document defines the **complete separation matrix** between the Elixir Core (EXECUTOR)
and F# Cortex (OBSERVER) layers of the Indrajaal system. The separation follows the
Observer/Observed pattern critical for safe system evolution under SIL-6 constraints.

**Core Principle**:
- **Elixir Core** = The OBSERVED system that EXECUTES runtime operations
- **F# Cortex** = The OBSERVER that ANALYZES and PROPOSES (never directly executes)
- **Guardian Gate** = The SINGLE mutation authorization point between layers

---

## Table of Contents

1. [Elixir Core Responsibilities (EXECUTOR)](#1-elixir-core-responsibilities-executor)
2. [F# Cortex Responsibilities (OBSERVER)](#2-f-cortex-responsibilities-observer)
3. [Bridge Interface](#3-bridge-interface)
4. [Complete Responsibility Matrix](#4-complete-responsibility-matrix)
5. [STAMP Constraints](#5-stamp-constraints)
6. [Code Examples](#6-code-examples)
7. [Anti-Patterns](#7-anti-patterns)

---

# 1. Elixir Core Responsibilities (EXECUTOR)

The Elixir Core is the **execution substrate** running on the BEAM VM. It owns all
runtime state and performs all mutations. The F# Cortex CANNOT directly modify
anything in the Elixir Core.

## 1.1 Runtime Execution (BEAM VM, OTP)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     ELIXIR CORE: RUNTIME EXECUTION                             ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  BEAM VM Layer ────────────────────────────────────────────────────────────    ║
║  │  • Process scheduling and isolation                                         ║
║  │  • Memory management and garbage collection                                 ║
║  │  • Hot code loading for evolution                                           ║
║  │  • Distribution protocol for clustering                                     ║
║  │  • Native Interface Functions (NIFs) for Zenoh                              ║
║                                                                                ║
║  OTP Supervision ──────────────────────────────────────────────────────────    ║
║  │  • Supervisor trees for fault tolerance                                     ║
║  │  • Application lifecycle management                                         ║
║  │  • GenServer, GenStage, GenStateMachine                                     ║
║  │  • DynamicSupervisor for agent spawning                                     ║
║  │  • Registry for named process discovery                                     ║
║                                                                                ║
║  Phoenix Framework ────────────────────────────────────────────────────────    ║
║  │  • HTTP endpoint handling                                                   ║
║  │  • LiveView for real-time UI                                                ║
║  │  • PubSub for internal messaging                                            ║
║  │  • Channels for WebSocket communication                                     ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Key Modules

| Module | Location | Responsibility |
|--------|----------|----------------|
| `Application` | `lib/indrajaal/application.ex` | Boot sequence, supervision tree |
| `Supervisor` | `lib/indrajaal/supervisor.ex` | Top-level supervisor |
| `Endpoint` | `lib/indrajaal_web/endpoint.ex` | HTTP/WebSocket entry |
| `ZenohNIF` | `native/zenoh_nif/` | Rust NIF for mesh communication |

## 1.2 State Management (SQLite/DuckDB)

The Elixir Core is the **authoritative source** for all holon state. Per SC-HOLON-001
through SC-HOLON-020, state sovereignty resides in SQLite/DuckDB.

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     ELIXIR CORE: STATE SOVEREIGNTY                             ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  SQLite (Real-Time State) ─────────────────────────────────────────────────    ║
║  │  Location: data/holons/{holon_id}/state.sqlite                              ║
║  │  Mode: WAL (Write-Ahead Logging)                                            ║
║  │  Purpose:                                                                   ║
║  │    • Current holon state                                                    ║
║  │    • Version vectors for replication                                        ║
║  │    • Agent coordination state                                               ║
║  │    • Real-time metrics                                                      ║
║                                                                                ║
║  DuckDB (Analytics/History) ───────────────────────────────────────────────    ║
║  │  Location: data/holons/{holon_id}/history.duckdb                            ║
║  │  Mode: Append-only, Columnar                                                ║
║  │  Purpose:                                                                   ║
║  │    • Evolution lineage (IMMUTABLE)                                          ║
║  │    • Historical analytics                                                   ║
║  │    • Pattern detection training data                                        ║
║  │    • Compliance audit trail                                                 ║
║                                                                                ║
║  Immutable Register ───────────────────────────────────────────────────────    ║
║  │  Purpose:                                                                   ║
║  │    • Blockchain-style append-only log                                       ║
║  │    • Ed25519 signed blocks                                                  ║
║  │    • SHA3-256 hash chain                                                    ║
║  │    • Reed-Solomon error correction                                          ║
║                                                                                ║
║  CONSTRAINT: PostgreSQL for business data ONLY (SC-HOLON-005)                  ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Key Modules

| Module | Location | Responsibility |
|--------|----------|----------------|
| `SqliteStore` | `lib/indrajaal/holon/sqlite_store.ex` | WAL-mode SQLite access |
| `DuckDBStore` | `lib/indrajaal/holon/duckdb_store.ex` | Columnar history queries |
| `ImmutableRegister` | `lib/indrajaal/holon/immutable_register.ex` | Blockchain state log |
| `VersionVector` | `lib/indrajaal/holon/version_vector.ex` | CRDT conflict resolution |

## 1.3 Fast OODA Loops (<100ms)

The Elixir Core executes Fast OODA loops for L1-L3 layer changes. These are
**execution loops** that take immediate action.

```elixir
# lib/indrajaal/cortex/fast_ooda.ex
# Target: 50ms cycle time (SC-OODA-001)

defmodule Indrajaal.Cortex.FastOODA do
  @moduledoc """
  Fast OODA Loop - EXECUTOR layer only.

  STAMP Constraints:
  - SC-OODA-001: Cycle time <100ms (target: 50ms)
  - SC-OODA-002: Quality gates enforced (min 80%)
  - SC-OODA-005: Hysteresis prevents oscillation

  This module is OBSERVED by F# DigitalTwin via telemetry.
  It does NOT receive commands from F# directly.
  All mutations go through Guardian gate.
  """

  @cycle_interval_ms 50

  # OBSERVE: Poll sensors asynchronously
  defp observe_with_sensors(buffer) do
    # Async sensor polling with 10ms timeout
    sensors = [SystemSensor, ContainerHealthSensor]
    Task.async_stream(sensors, &safe_measure/1, timeout: 10)
    |> aggregate_observations(buffer)
  end

  # ORIENT: Calculate stress, detect patterns
  defp orient(observations, state) do
    %{
      stress_level: calculate_stress(observations),
      trend: detect_trend(observations),
      anomalies: detect_anomalies(observations)
    }
  end

  # DECIDE: Rule-based with hysteresis
  defp decide(situation, hysteresis_state) do
    # Apply hysteresis to prevent oscillation
    # Generate action with confidence score
  end

  # ACT: Execute via Guardian gate
  defp act(state, decision) do
    # ALL actions MUST pass Guardian validation (SC-GUARD-001)
    proposal = build_proposal(decision)

    case Guardian.validate_proposal(proposal) do
      {:ok, _} -> execute_approved_action(decision)
      {:veto, reason, fallback} -> handle_veto(reason, fallback)
    end
  end
end
```

### OODA Timing Budget

| Phase | Budget | Purpose |
|-------|--------|---------|
| OBSERVE | 5ms | Sensor polling, buffer aggregation |
| ORIENT | 15ms | Stress calculation, pattern detection |
| DECIDE | 15ms | Rule evaluation, hysteresis check |
| ACT | 15ms | Guardian validation, execution |
| **Total** | **50ms** | SC-OODA-001 compliant |

## 1.4 GenServers, Supervisors, Agents

The Elixir Core owns all stateful processes.

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     ELIXIR CORE: OTP PROCESSES                                 ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  Supervision Tree ─────────────────────────────────────────────────────────    ║
║  │                                                                             ║
║  │  Application.Supervisor                                                     ║
║  │  ├── Repo (Ecto/PostgreSQL)                                                 ║
║  │  ├── PubSub                                                                 ║
║  │  ├── Endpoint                                                               ║
║  │  ├── Cortex.Supervisor                                                      ║
║  │  │   ├── FastOODA                                                           ║
║  │  │   ├── Homeostasis.Controller                                             ║
║  │  │   ├── GDE.Controller                                                     ║
║  │  │   └── Sensors.SensorMesh                                                 ║
║  │  ├── Safety.Supervisor                                                      ║
║  │  │   ├── Guardian                                                           ║
║  │  │   ├── Sentinel                                                           ║
║  │  │   └── PatternHunter                                                      ║
║  │  ├── Control.Supervisor                                                     ║
║  │  │   ├── UnifiedBus                                                         ║
║  │  │   └── EventRouter                                                        ║
║  │  ├── Holon.Supervisor                                                       ║
║  │  │   ├── SqliteStore                                                        ║
║  │  │   ├── DuckDBStore                                                        ║
║  │  │   └── ImmutableRegister                                                  ║
║  │  └── Mesh.Supervisor                                                        ║
║  │      ├── ZenohBridge                                                        ║
║  │      └── ContainerManager                                                   ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## 1.5 Ash Resources, Phoenix LiveView

The Elixir Core handles all domain logic via Ash Framework.

```elixir
# Example: Alarm Resource (L2 Module Layer)
defmodule Indrajaal.Alarms.Alarm do
  use Indrajaal.BaseResource  # SC-DB-001

  attributes do
    uuid_primary_key :id  # SC-DB-005
    attribute :code, :string, allow_nil?: false
    attribute :severity, :atom, constraints: [one_of: [:low, :medium, :high, :critical]]
    attribute :zone_id, :uuid
    timestamps()
  end

  actions do
    defaults [:read]

    create :receive do
      # Guardian validates before persistence
      change {Indrajaal.Safety.GuardianChange, action: :alarm_create}
    end

    update :acknowledge do
      require_atomic? false  # SC-ASH-004
      change set_attribute(:acknowledged_at, &DateTime.utc_now/0)
    end
  end
end
```

## 1.6 Guardian Execution (Validation Enforcement)

The Guardian is the **single mutation authorization point**. All changes from
F# Cortex proposals MUST pass through Guardian.

```elixir
defmodule Indrajaal.Safety.Guardian do
  @moduledoc """
  Safety kernel for mutation authorization.

  STAMP Constraints:
  - SC-GDE-001: Guardian validation required
  - SC-GDE-004: Proposal threshold >= 0.85
  - SC-CONST-007: Guardian has absolute veto

  This is the ONLY entry point for F# Cortex mutations.
  """

  @approval_threshold 0.85
  @validation_checks 6

  @doc """
  Validate a proposal from F# Cortex.
  Returns {:ok, proposal} or {:veto, reason, fallback}.
  """
  @spec validate_proposal(map()) :: {:ok, map()} | {:veto, term(), term()}
  def validate_proposal(proposal) do
    checks = [
      check_constitutional_compliance(proposal),
      check_stamp_constraints(proposal),
      check_shadow_test_results(proposal),
      check_impact_score(proposal),
      check_reversibility(proposal),
      check_founder_directive(proposal)
    ]

    passed = Enum.count(checks, &(&1 == :ok))
    score = passed / @validation_checks

    if score >= @approval_threshold do
      {:ok, Map.put(proposal, :guardian_score, score)}
    else
      failed = Enum.filter(checks, &(&1 != :ok))
      {:veto, {:validation_failed, failed}, determine_fallback(proposal)}
    end
  end
end
```

## 1.7 GDE Activation (Code Deployment)

The Elixir Core executes GDE-approved code changes.

```elixir
defmodule Indrajaal.Cortex.GDE.Controller do
  @moduledoc """
  Goal-Directed Evolution Controller - EXECUTION phase.

  Receives approved proposals from Guardian and executes:
  1. Shadow deployment verification
  2. Progressive rollout (5% -> 25% -> 100%)
  3. Rollback on degradation
  4. Learning feedback to TrainingGym
  """

  def execute_evolution(proposal) when proposal.guardian_approved do
    # Log to Immutable Register BEFORE execution
    ImmutableRegister.append_block(%{
      type: :evolution_start,
      proposal_id: proposal.id,
      timestamp: DateTime.utc_now()
    })

    # Progressive rollout with monitoring
    with :ok <- deploy_shadow(proposal),
         :ok <- verify_shadow_health(proposal),
         :ok <- progressive_activate(proposal, [0.05, 0.25, 1.0]) do

      # Record success to TrainingGym
      TrainingGym.record_success(proposal)
      {:ok, proposal}
    else
      {:error, phase, reason} ->
        rollback(proposal, phase)
        {:error, reason}
    end
  end
end
```

## 1.8 Zenoh NIF (Pub/Sub Messaging)

The Elixir Core owns the Zenoh NIF for mesh communication.

```elixir
defmodule Indrajaal.Mesh.ZenohBridge do
  @moduledoc """
  Zenoh NIF bridge for mesh pub/sub.

  STAMP Constraints:
  - SC-BRIDGE-001: FIFO message ordering
  - SC-BRIDGE-002: Buffer flush interval 100ms max
  - SC-BRIDGE-003: Latency budget 50ms per batch
  """

  use GenServer

  @flush_interval_ms 100

  def init(_opts) do
    # Attach telemetry handlers for F# observation
    :telemetry.attach_many(
      "zenoh-bridge",
      [
        [:zenoh, :message, :sent],
        [:zenoh, :message, :received]
      ],
      &handle_telemetry/4,
      nil
    )

    {:ok, session} = ZenohNIF.open_session()
    {:ok, %{session: session, buffer: []}}
  end

  def publish(topic, payload) do
    GenServer.cast(__MODULE__, {:publish, topic, payload})
  end

  def subscribe(topic, callback) do
    GenServer.call(__MODULE__, {:subscribe, topic, callback})
  end
end
```

---

# 2. F# Cortex Responsibilities (OBSERVER)

The F# Cortex is the **intelligence layer** that observes, analyzes, and proposes.
It NEVER directly modifies the Elixir Core. All mutations go through the Guardian gate.

## 2.1 Strategic Observation (DigitalTwin Read-Only)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     F# CORTEX: DIGITAL TWIN (READ-ONLY)                        ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  DigitalTwin.fs ───────────────────────────────────────────────────────────    ║
║  │  Purpose: Authoritative read-only mirror of Elixir state                   ║
║  │  Data Source: Zenoh telemetry subscription ONLY                             ║
║  │  Update Mode: Event-driven, NOT polling                                     ║
║  │                                                                             ║
║  │  State Tracked:                                                             ║
║  │    • Container health (4 containers)                                        ║
║  │    • Agent swarm status (50 agents)                                         ║
║  │    • OODA cycle metrics                                                     ║
║  │    • Error budget consumption                                               ║
║  │    • Pending evolution proposals                                            ║
║  │    • Sentinel threat level                                                  ║
║  │                                                                             ║
║  CONSTRAINT: DigitalTwin MUST NOT directly query Elixir GenServers             ║
║  CONSTRAINT: All state comes from telemetry subscription (SC-OBS-003)          ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

```fsharp
// lib/cepaf/src/Cepaf/Observability/DigitalTwin.fs
namespace Cepaf.Observability

/// Digital Twin - Read-only mirror of Elixir state
/// OBSERVER ONLY - Receives telemetry, does NOT modify source
module DigitalTwin =

    /// State received from Elixir via telemetry (READ-ONLY)
    type TwinState = {
        Containers: Map<string, ContainerHealth>
        Agents: Map<string, AgentStatus>
        OODAMetrics: OODAMetrics option
        ErrorBudget: float
        PendingEvolutions: EvolutionProposal list
        ThreatLevel: ThreatLevel
        LastSync: DateTime
    }

    /// Subscribe to Zenoh telemetry topics
    let subscribeToTelemetry (zenohClient: ZenohClient) =
        [
            "indrajaal/ooda/fast/cycle"
            "indrajaal/agents/status"
            "indrajaal/containers/health"
            "indrajaal/sentinel/threats"
            "indrajaal/guardian/proposals"
        ]
        |> List.map (fun topic ->
            zenohClient.Subscribe(topic, handleTelemetry))

    /// Handle incoming telemetry (SC-OBS-001: Read-only)
    let private handleTelemetry (topic: string) (payload: byte[]) =
        // Parse and update local state
        // NEVER send commands back through this channel
        updateState topic payload

    /// Get current cluster health (read-only query)
    let getClusterHealth (state: TwinState) : float =
        let healthyContainers =
            state.Containers
            |> Map.filter (fun _ v -> v.Status = "healthy")
            |> Map.count
        float healthyContainers / float (Map.count state.Containers)
```

## 2.2 Strategy OODA (1s+ Cycles)

The F# Cortex executes Strategy OODA for L5-L7 decisions. These are **analysis loops**
that propose actions (never execute directly).

```fsharp
// lib/cepaf/src/Cepaf/Intelligence/StrategyOODA.fs
namespace Cepaf.Intelligence

/// Strategy OODA loop for L5-L7 decisions
/// OBSERVER ONLY - Proposes through Guardian, never executes directly
module StrategyOODA =

    /// OODA cycle budget (1000ms total)
    let private observeBudgetMs = 200
    let private orientBudgetMs = 300
    let private decideBudgetMs = 250
    let private actBudgetMs = 250

    /// Run one strategy OODA cycle
    let runCycle (digitalTwin: DigitalTwin) : StrategyDecision =
        // OBSERVE: Read from DigitalTwin only (never direct Elixir queries)
        let observed = observe digitalTwin

        // ORIENT: Constitutional analysis with ML insights
        let analysis = orient observed

        // DECIDE: Choose action with Guardian consultation
        let decision = decide analysis

        // ACT: Submit proposal to Guardian (does NOT execute)
        submitToGuardian decision

        decision

    /// OBSERVE phase: Read from DigitalTwin only
    let private observe (twin: DigitalTwin) =
        {
            ClusterHealth = twin.GetClusterHealth()
            FederationStatus = twin.GetFederationStatus()
            PendingEvolutions = twin.GetPendingEvolutions()
            ErrorBudgetRemaining = twin.GetErrorBudget()
        }

    /// ACT phase: Submit to Guardian (does NOT execute directly)
    let private submitToGuardian (decision: StrategyDecision) =
        match decision with
        | ApproveEvolution proposal ->
            // Submit via ElixirBridge HTTP - Guardian validates
            ElixirBridge.submitGuardianProposal proposal
        | TriggerEmergencyMode reason ->
            // Alert only - Elixir handles actual emergency
            AlertManager.triggerEmergency reason
        | _ -> ()
```

## 2.3 Intelligence Analysis (ML, Pattern Detection)

```fsharp
// lib/cepaf/src/Cepaf/Intelligence/PatternAnalyzer.fs
namespace Cepaf.Intelligence

/// Pattern analysis for pre-error detection
/// OBSERVER ONLY - Analyzes telemetry, proposes mitigations
module PatternAnalyzer =

    /// Analyze patterns in historical data (DuckDB read-only)
    let detectPatterns (duckdb: DuckDBClient) : PatternResult list =
        // Query historical telemetry (read-only)
        let history = duckdb.Query<TelemetryEvent>(
            "SELECT * FROM telemetry_events
             WHERE timestamp > now() - INTERVAL '1 hour'
             ORDER BY timestamp")

        history
        |> Seq.groupBy (fun e -> e.EventType)
        |> Seq.map analyzeEventGroup
        |> Seq.filter (fun p -> p.Confidence > 0.7)
        |> Seq.toList

    /// Generate mitigation proposal (submitted to Guardian)
    let proposeMitigation (pattern: PatternResult) : MitigationProposal =
        {
            PatternId = pattern.Id
            Severity = pattern.Severity
            RecommendedAction = determineAction pattern
            ConfidenceScore = pattern.Confidence
            ImpactAnalysis = analyze5OrderEffects pattern
        }
```

## 2.4 Evolution Planning (GDE Proposals)

```fsharp
// lib/cepaf/src/Cepaf/Intelligence/EvolutionPlanner.fs
namespace Cepaf.Intelligence

/// Evolution planner - Generates proposals for Guardian approval
/// OBSERVER ONLY - Proposes changes, never executes
module EvolutionPlanner =

    /// Generate evolution proposals from training data
    let generateProposals (trainingData: TrainingGymData) : EvolutionProposal list =
        // Analyze Q-table for high-reward actions
        let candidates =
            trainingData.Episodes
            |> Seq.filter (fun e -> e.Reward > 0.5)
            |> Seq.groupBy (fun e -> e.Layer)
            |> Seq.map selectBestCandidate

        candidates
        |> Seq.map buildProposal
        |> Seq.filter validateProposal
        |> Seq.toList

    /// Build proposal with constitutional compliance check
    let private buildProposal (candidate: Candidate) : EvolutionProposal =
        let constitutionalCheck = ConstitutionalOracle.verify candidate

        {
            Id = Guid.NewGuid().ToString()
            Layer = candidate.Layer
            ChangeType = candidate.ChangeType
            Code = candidate.GeneratedCode
            ImpactScore = calculateImpactScore candidate
            ConstitutionalCompliance = constitutionalCheck
            ShadowTestRequired = true
            RollbackPlan = generateRollbackPlan candidate
        }
```

## 2.5 Constitutional Analysis (Psi Verification)

```fsharp
// lib/cepaf/src/Cepaf/Intelligence/ConstitutionalOracle.fs
namespace Cepaf.Intelligence

/// Constitutional Oracle for Ψ₀-Ψ₅ verification
/// OBSERVER ONLY - Validates proposals against constitutional invariants
module ConstitutionalOracle =

    /// Constitutional invariants (IMMUTABLE)
    type Invariant =
        | Psi0_Existence       // System survives all operations
        | Psi1_Regeneration    // State reconstructible from SQLite/DuckDB
        | Psi2_History         // Evolution lineage complete
        | Psi3_Verification    // All changes verifiable
        | Psi4_HumanAlignment  // Founder's lineage primary
        | Psi5_Truthfulness    // No deception

    /// Verify all invariants for a proposal
    let verify (proposal: EvolutionProposal) : VerificationResult =
        let results = [
            verifyExistence proposal
            verifyRegeneration proposal
            verifyHistory proposal
            verifyVerification proposal
            verifyHumanAlignment proposal
            verifyTruthfulness proposal
        ]

        if List.forall isPass results then
            Passed { AllInvariants = results; Score = 1.0 }
        else
            let failures = List.filter (not << isPass) results
            Failed { Violations = failures; BlockingReason = summarize failures }

    /// Ψ₀: Existence - System must survive
    let private verifyExistence (proposal: EvolutionProposal) =
        match proposal.Layer with
        | "L0" -> Failed (Psi0_Existence, "L0 is immutable")
        | _ when proposal.ImpactScore > 40 ->
            Failed (Psi0_Existence, "Impact threatens survival")
        | _ -> Passed Psi0_Existence

    /// Ψ₄: Human Alignment - Founder's lineage primary
    let private verifyHumanAlignment (proposal: EvolutionProposal) =
        match proposal.FounderImpact with
        | Positive | Neutral -> Passed Psi4_HumanAlignment
        | Negative -> Failed (Psi4_HumanAlignment, "Harms Founder's lineage")
```

## 2.6 Formal Verification (Quint Integration)

```fsharp
// lib/cepaf/src/Cepaf/FormalVerification/QuintBridge.fs
namespace Cepaf.FormalVerification

/// Bridge to Quint formal verification
/// OBSERVER ONLY - Verifies state machine properties
module QuintBridge =

    /// Verify state machine against Quint specification
    let verifyStateMachine (spec: string) (trace: StateTrace) : VerificationResult =
        // Generate Quint input from execution trace
        let quintInput = generateQuintInput spec trace

        // Run Quint model checker
        let result = Process.Start("quint", $"verify {quintInput}")

        parseQuintResult result.StandardOutput

    /// Verify temporal properties
    let verifyTemporalProperty (property: string) : bool =
        // Example: □(error → ◇recovered)
        // "Always, if error then eventually recovered"
        match property with
        | "liveness" -> verifyLiveness()
        | "safety" -> verifySafety()
        | "fairness" -> verifyFairness()
        | _ -> false
```

## 2.7 Dashboard/TUI Rendering

```fsharp
// lib/cepaf/src/Cepaf/Dashboard/DashboardTUI.fs
namespace Cepaf.Dashboard

/// Terminal UI for system monitoring
/// OBSERVER ONLY - Displays cached state from DigitalTwin
module DashboardTUI =

    /// Render dashboard (30s refresh per SC-BIO-005)
    let render (twin: DigitalTwin) =
        printfn "╔═══════════════════════════════════════════════════════════════╗"
        printfn "║  INDRAJAAL BIOMORPHIC STATUS              [30s refresh]        ║"
        printfn "╠═══════════════════════════════════════════════════════════════╣"
        printfn "║  Context: %s%% (%s/%s tokens)                                  ║"
            (formatPercent twin.ContextUsage)
            (formatTokens twin.UsedTokens)
            (formatTokens twin.MaxTokens)
        printfn "║  API:     %s%% (%s RPM)                                        ║"
            (formatPercent twin.APIUsage)
            (formatNumber twin.CurrentRPM)
        printfn "║  Agents:  %s/%s active                                         ║"
            (string twin.ActiveAgents)
            (string twin.MaxAgents)
        printfn "║  OODA:    %sms (target: 50ms)                                  ║"
            (formatLatency twin.OODALatency)
        printfn "║  Health:  %s                                                    ║"
            (formatHealth twin.SystemHealth)
        printfn "╚═══════════════════════════════════════════════════════════════╝"
```

## 2.8 Federation Protocol Negotiation

```fsharp
// lib/cepaf/src/Cepaf/Federation/FederationProtocol.fs
namespace Cepaf.Federation

/// Federation protocol for cross-holon coordination
/// OBSERVER ONLY - Negotiates protocols, submits actions via Guardian
module FederationProtocol =

    /// Negotiate protocol version with peer holon
    let negotiateProtocol (peer: HolonId) : ProtocolVersion =
        // Read local capabilities (observer pattern)
        let localVersion = getLocalProtocolVersion()

        // Query peer capabilities via Zenoh
        let peerVersion = queryPeerVersion peer

        // Select compatible version
        selectCompatibleVersion localVersion peerVersion

    /// Attest peer holon integrity (SC-REG-012)
    let attestPeer (peer: HolonId) : AttestationResult =
        // Read peer's Immutable Register via Zenoh
        let peerRegister = ZenohClient.query $"indrajaal/{peer}/register/merkle"

        // Verify Merkle root
        verifyMerkleRoot peerRegister
```

---

# 3. Bridge Interface

The bridge between Elixir Core and F# Cortex has **exactly one mutation path**:
the Guardian Gate.

## 3.1 Guardian Gate (Single Mutation Authorization Point)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     GUARDIAN GATE: MUTATION AUTHORIZATION                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  F# Cortex                           │         Elixir Core                     ║
║  ─────────────────────────────────── │ ───────────────────────────────────     ║
║                                      │                                         ║
║  ┌─────────────────────────────┐     │     ┌─────────────────────────────┐     ║
║  │  EvolutionPlanner           │     │     │                             │     ║
║  │  ├─ Generate proposals      │     │     │  Guardian                   │     ║
║  │  ├─ Constitutional check    │─────┼────▶│  ├─ 6 validation checks     │     ║
║  │  └─ Impact analysis         │     │     │  ├─ Score >= 0.85           │     ║
║  └─────────────────────────────┘     │     │  └─ Veto or Approve         │     ║
║              │                       │     │           │                 │     ║
║              │ Proposal              │     │           │ Approved        │     ║
║              ▼                       │     │           ▼                 │     ║
║  ┌─────────────────────────────┐     │     │  ┌─────────────────────┐    │     ║
║  │  ElixirBridge.submitGuardian│─────┼────▶│  │  GDE.Controller     │    │     ║
║  │  ├─ HTTP POST /api/guardian │     │     │  │  ├─ Shadow deploy   │    │     ║
║  │  ├─ Circuit breaker (3 fail)│     │     │  │  ├─ Progressive roll│    │     ║
║  │  └─ Retry with backoff      │     │     │  │  └─ Rollback ready  │    │     ║
║  └─────────────────────────────┘     │     │  └─────────────────────┘    │     ║
║                                      │     │                             │     ║
║  ════════════════════════════════════╪═════════════════════════════════════    ║
║        SEPARATION BOUNDARY           │                                         ║
║        (No direct write access)      │                                         ║
║  ════════════════════════════════════╪═════════════════════════════════════    ║
║                                      │                                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Guardian Validation Checks

| Check | Description | Threshold |
|-------|-------------|-----------|
| Constitutional | Ψ₀-Ψ₅ compliance | All pass |
| STAMP | Constraint validation | All relevant |
| Shadow Test | Pre-activation test | Pass |
| Impact Score | 4-layer analysis | < 40 |
| Reversibility | Rollback plan exists | Yes |
| Founder Directive | Ω₀ alignment | Positive/Neutral |

## 3.2 Telemetry Bus (Zenoh Topics)

The telemetry bus is **one-way**: Elixir publishes, F# subscribes.

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     TELEMETRY BUS: ZENOH TOPICS                                ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  Elixir Core (Publisher)             →    F# Cortex (Subscriber)               ║
║  ─────────────────────────────────────────────────────────────────────────     ║
║                                                                                ║
║  Topic: indrajaal/ooda/fast/cycle                                              ║
║  Payload: {cycle_time_us, observe_us, orient_us, decide_us, act_us}            ║
║  Frequency: Every 50ms                                                         ║
║                                                                                ║
║  Topic: indrajaal/ooda/strategy/cycle                                          ║
║  Payload: {cycle_time_ms, decision, confidence}                                ║
║  Frequency: Every 1s                                                           ║
║                                                                                ║
║  Topic: indrajaal/agents/status                                                ║
║  Payload: {agent_id, status, layer, task}                                      ║
║  Frequency: On change                                                          ║
║                                                                                ║
║  Topic: indrajaal/containers/health                                            ║
║  Payload: {container_id, status, ports, uptime}                                ║
║  Frequency: Every 10s                                                          ║
║                                                                                ║
║  Topic: indrajaal/sentinel/threats                                             ║
║  Payload: {threat_level, active_threats, health_score}                         ║
║  Frequency: Every 30s or on change                                             ║
║                                                                                ║
║  Topic: indrajaal/guardian/proposals                                           ║
║  Payload: {proposal_id, status, score}                                         ║
║  Frequency: On submission/completion                                           ║
║                                                                                ║
║  Topic: indrajaal/register/blocks                                              ║
║  Payload: {block_number, hash, operation, timestamp}                           ║
║  Frequency: On append                                                          ║
║                                                                                ║
║  CONSTRAINT: F# Cortex NEVER publishes to indrajaal/* topics                   ║
║  CONSTRAINT: All F# messages go through /api/guardian endpoint                 ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

## 3.3 State Sync Protocol

```fsharp
// State synchronization between F# DigitalTwin and Elixir state

/// State sync is ONE-WAY: Elixir → F# (read-only)
/// F# never directly queries Elixir state
/// All state comes from Zenoh telemetry subscription

type StateSyncDirection =
    | ElixirToFSharp  // Allowed: Telemetry subscription
    | FSharpToElixir  // BLOCKED: Must go through Guardian

/// Sync configuration
let syncConfig = {
    RefreshInterval = TimeSpan.FromSeconds(30.0)  // SC-SYNC-004
    TelemetryTopics = [
        "indrajaal/ooda/*"
        "indrajaal/agents/*"
        "indrajaal/containers/*"
        "indrajaal/sentinel/*"
    ]
    MutationEndpoint = "http://localhost:4000/api/v1/prajna/guardian/submit"
}
```

## 3.4 Proof Token Exchange

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                     PROOF TOKEN EXCHANGE (PROMETHEUS)                          ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  1. F# Cortex requests proof token                                             ║
║     POST /api/v1/prajna/prometheus/token                                       ║
║     Body: { scope: ["evolution.propose"], reason: "GDE cycle", ttl: 300 }      ║
║                                                                                ║
║  2. Elixir PROMETHEUS generates token                                          ║
║     - Ed25519 signature                                                        ║
║     - Scope-limited (cannot exceed requested)                                  ║
║     - Time-bounded (TTL)                                                       ║
║                                                                                ║
║  3. F# includes token in Guardian proposal                                     ║
║     POST /api/v1/prajna/guardian/submit                                        ║
║     Header: X-Prometheus-Token: <token>                                        ║
║     Body: { proposal: {...} }                                                  ║
║                                                                                ║
║  4. Guardian validates token before processing                                 ║
║     - Verify signature                                                         ║
║     - Check scope includes required action                                     ║
║     - Verify not expired                                                       ║
║     - Log to Immutable Register                                                ║
║                                                                                ║
║  CONSTRAINT: No mutation without valid proof token (SC-SYNC-007)               ║
║                                                                                ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

# 4. Complete Responsibility Matrix

## 4.1 State Management

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| SQLite Write | EXECUTOR | BLOCKED | N/A |
| SQLite Read | EXECUTOR | Via telemetry | Zenoh topics |
| DuckDB Write | EXECUTOR | BLOCKED | N/A |
| DuckDB Read | EXECUTOR | Read-only queries | DuckDB client |
| Register Append | EXECUTOR | BLOCKED | Guardian gate |
| Register Query | EXECUTOR | Read-only | Zenoh/HTTP |
| Version Vector | EXECUTOR | Observe only | Telemetry |
| State Recovery | EXECUTOR | Propose only | Guardian |

## 4.2 OODA Loops

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Fast OODA (50ms) | EXECUTOR | Observe telemetry | Zenoh sub |
| Distributed OODA (100ms) | EXECUTOR | Observe telemetry | Zenoh sub |
| Strategy OODA (1s) | N/A | PROPOSER | Guardian submit |
| Hysteresis State | EXECUTOR | Observe only | Telemetry |
| Latency Tracking | EXECUTOR | Analytics | DuckDB read |
| AI Orientation | EXECUTOR | AI call | OpenRouter |

## 4.3 Evolution (GDE)

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Proposal Generation | N/A | PROPOSER | Guardian submit |
| Constitutional Check | Validate | Analyze | HTTP API |
| Shadow Testing | EXECUTOR | Monitor | Telemetry |
| Progressive Rollout | EXECUTOR | Monitor | Telemetry |
| Rollback Execution | EXECUTOR | Propose | Guardian |
| Learning Recording | EXECUTOR | Analytics | DuckDB |

## 4.4 Guardian Safety

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Proposal Validation | EXECUTOR | Submit proposals | HTTP POST |
| Veto Enforcement | EXECUTOR | Receive result | HTTP response |
| Approval Execution | EXECUTOR | Observe | Telemetry |
| Audit Logging | EXECUTOR | Query history | DuckDB read |
| Fallback Actions | EXECUTOR | Propose alternatives | Guardian |
| Constitutional Veto | EXECUTOR | Verify pre-submit | Local check |

## 4.5 Agent Swarm

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Agent Spawning | EXECUTOR | Propose scale | Guardian |
| Agent Termination | EXECUTOR | Propose scale | Guardian |
| Task Assignment | EXECUTOR | Analytics | Telemetry |
| Swarm Coordination | EXECUTOR | Observe | Telemetry |
| API Rate Control | EXECUTOR | Monitor | Telemetry |
| Context Compaction | EXECUTOR | Trigger propose | Guardian |

## 4.6 Monitoring

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Telemetry Emission | EXECUTOR | N/A | Zenoh publish |
| Telemetry Reception | N/A | OBSERVER | Zenoh subscribe |
| Metrics Aggregation | EXECUTOR | Analytics | DuckDB |
| Dashboard Data | N/A | RENDERER | DigitalTwin |
| Alerting | EXECUTOR + F# | Both | Zenoh |
| OTEL Export | EXECUTOR | N/A | OTLP |

## 4.7 Federation

| Aspect | Elixir Core | F# Cortex | Bridge |
|--------|-------------|-----------|--------|
| Protocol Negotiation | N/A | NEGOTIATOR | Zenoh |
| Peer Attestation | EXECUTOR | Verify | Zenoh query |
| Cross-Holon Sync | EXECUTOR | Coordinate | Zenoh |
| Consensus Voting | EXECUTOR | Analyze | Telemetry |
| Quorum Calculation | EXECUTOR | Monitor | Telemetry |
| Federation Alerts | EXECUTOR | Process | Guardian |

---

# 5. STAMP Constraints

## 5.1 Separation Constraints (SC-SEP-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SEP-001 | F# Cortex SHALL NOT directly write to SQLite/DuckDB | CRITICAL |
| SC-SEP-002 | F# Cortex SHALL NOT directly call Elixir GenServers | CRITICAL |
| SC-SEP-003 | All F# mutations MUST go through Guardian gate | CRITICAL |
| SC-SEP-004 | Telemetry flow is ONE-WAY (Elixir → F#) | HIGH |
| SC-SEP-005 | F# DigitalTwin is READ-ONLY mirror | HIGH |
| SC-SEP-006 | Proof token REQUIRED for all mutations | HIGH |
| SC-SEP-007 | Evolution proposals MUST be shadow tested | HIGH |

## 5.2 Observer Constraints (SC-OBS-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-OBS-001 | Observer MUST NOT directly modify observed state | CRITICAL |
| SC-OBS-002 | All mutations MUST go through Guardian gate | CRITICAL |
| SC-OBS-003 | DigitalTwin MUST be read-only mirror | HIGH |
| SC-OBS-004 | Telemetry stream MUST be immutable | HIGH |
| SC-OBS-005 | Evolution proposals MUST be validated before execution | CRITICAL |
| SC-OBS-006 | Observer isolation MUST survive system evolution | CRITICAL |

## 5.3 Sync Constraints (SC-SYNC-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SYNC-001 | Bridge timeout < 5s | HIGH |
| SC-SYNC-002 | Retry with exponential backoff | HIGH |
| SC-SYNC-003 | Circuit breaker after 3 failures | HIGH |
| SC-SYNC-004 | Health sync interval = 30s | MEDIUM |
| SC-SYNC-005 | All commands through Guardian | CRITICAL |
| SC-SYNC-006 | All state via Immutable Register | CRITICAL |
| SC-SYNC-007 | Proof token required for mutations | HIGH |
| SC-SYNC-008 | Constitutional check before reconfig | CRITICAL |
| SC-SYNC-009 | Zenoh for real-time telemetry | HIGH |
| SC-SYNC-010 | DuckDB for shared history | MEDIUM |

---

# 6. Code Examples

## 6.1 Elixir Core: Receiving F# Proposal

```elixir
# lib/indrajaal/cockpit/prajna/guardian_controller.ex
defmodule IndrajaalWeb.GuardianController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Holon.ImmutableRegister

  @doc """
  Receive evolution proposal from F# Cortex.
  Single entry point for all mutations.
  """
  def submit(conn, %{"proposal" => proposal_params}) do
    # Verify proof token (SC-SYNC-007)
    with {:ok, token} <- verify_proof_token(conn),
         {:ok, proposal} <- build_proposal(proposal_params, token),
         # Guardian validation (SC-SEP-003)
         {:ok, approved} <- Guardian.validate_proposal(proposal) do

      # Log to Immutable Register (SC-SYNC-006)
      ImmutableRegister.append_block(%{
        type: :proposal_approved,
        proposal_id: approved.id,
        guardian_score: approved.guardian_score
      })

      json(conn, %{status: "approved", proposal_id: approved.id})
    else
      {:veto, reason, fallback} ->
        json(conn, %{status: "vetoed", reason: reason, fallback: fallback})
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  defp verify_proof_token(conn) do
    case get_req_header(conn, "x-prometheus-token") do
      [token] -> Prometheus.verify_token(token)
      _ -> {:error, :missing_proof_token}
    end
  end
end
```

## 6.2 F# Cortex: Submitting Proposal

```fsharp
// lib/cepaf/src/Cepaf/Cockpit/ElixirBridge.fs

/// Submit evolution proposal to Guardian (SC-SYNC-005)
let submitEvolutionProposal
    (state: BridgeState)
    (proposal: EvolutionProposal) : Async<Result<GuardianResult, string>> =
    async {
        // 1. Request proof token (SC-SYNC-007)
        let! tokenResult = requestProofToken state {
            Scope = ["evolution.propose"]
            Reason = $"GDE proposal {proposal.Id}"
            ExpirationMinutes = 5
        }

        match tokenResult with
        | Error msg -> return Error msg
        | Ok (newState, proofToken) ->

            // 2. Pre-validate constitutionally (local check)
            let constitutionalCheck = ConstitutionalOracle.verify proposal
            if not (constitutionalCheck.AllPassed) then
                return Error "Constitutional pre-check failed"
            else

                // 3. Submit to Guardian via HTTP (SC-SEP-003)
                use client = createClient newState.Config
                client.DefaultRequestHeaders.Add(
                    "X-Prometheus-Token",
                    proofToken.Token)

                let url = $"{newState.Config.BaseUrl}/guardian/submit"
                let! result = postAsync<EvolutionProposal, GuardianResult> client url proposal

                return result
    }
```

## 6.3 Telemetry Subscription

```fsharp
// lib/cepaf/src/Cepaf/Observability/TelemetryReceiver.fs

/// Subscribe to Elixir telemetry (READ-ONLY)
let subscribeToTelemetry (zenoh: ZenohSession) : unit =

    // Fast OODA metrics
    zenoh.Subscribe("indrajaal/ooda/fast/cycle", fun payload ->
        let metrics = JsonSerializer.Deserialize<OODAMetrics>(payload)
        DigitalTwin.updateOODAMetrics metrics)

    // Agent status updates
    zenoh.Subscribe("indrajaal/agents/status", fun payload ->
        let status = JsonSerializer.Deserialize<AgentStatus>(payload)
        DigitalTwin.updateAgentStatus status)

    // Container health
    zenoh.Subscribe("indrajaal/containers/health", fun payload ->
        let health = JsonSerializer.Deserialize<ContainerHealth>(payload)
        DigitalTwin.updateContainerHealth health)

    // Guardian proposals
    zenoh.Subscribe("indrajaal/guardian/proposals", fun payload ->
        let proposal = JsonSerializer.Deserialize<ProposalStatus>(payload)
        DigitalTwin.updateProposalStatus proposal)

    // CONSTRAINT: We ONLY subscribe, never publish to indrajaal/* topics
    // All mutations go through HTTP Guardian endpoint
```

---

# 7. Anti-Patterns

## 7.1 FORBIDDEN: Direct State Modification

```fsharp
// ❌ WRONG: F# directly modifying SQLite
let updateHolonState (holonId: string) (newState: HolonState) =
    let conn = new SqliteConnection($"Data Source=data/holons/{holonId}/state.sqlite")
    conn.Execute("UPDATE state SET value = @value", {| value = newState |})
    // THIS IS FORBIDDEN - violates SC-SEP-001
```

```fsharp
// ✅ CORRECT: Submit change proposal to Guardian
let proposeStateChange (holonId: string) (newState: HolonState) =
    let proposal = {
        TargetHolon = holonId
        ChangeType = "state_update"
        NewValue = newState
        Justification = "..."
    }
    ElixirBridge.submitGuardianProposal proposal
```

## 7.2 FORBIDDEN: Direct GenServer Call

```fsharp
// ❌ WRONG: F# calling Elixir GenServer directly
let getAgentStatus (agentId: string) =
    // Hypothetical direct call - THIS IS FORBIDDEN
    ElixirRPC.call("Elixir.Indrajaal.Agents.Agent", "status", [agentId])
    // Violates SC-SEP-002, SC-OBS-001
```

```fsharp
// ✅ CORRECT: Read from DigitalTwin (populated via telemetry)
let getAgentStatus (agentId: string) =
    DigitalTwin.getAgentStatus agentId
    // DigitalTwin is populated by Zenoh subscription
```

## 7.3 FORBIDDEN: Bypassing Guardian

```fsharp
// ❌ WRONG: Direct HTTP to non-Guardian endpoint
let executeAction (action: Action) =
    Http.post "http://localhost:4000/api/actions/execute" action
    // THIS IS FORBIDDEN - bypasses Guardian gate
    // Violates SC-SEP-003, SC-SYNC-005
```

```fsharp
// ✅ CORRECT: Always go through Guardian
let executeAction (action: Action) =
    let proposal = actionToProposal action
    ElixirBridge.submitGuardianProposal proposal
    // Guardian validates, then executes in Elixir Core
```

## 7.4 FORBIDDEN: Publishing to Elixir Topics

```fsharp
// ❌ WRONG: F# publishing to indrajaal/* topics
let sendCommand (command: Command) =
    zenoh.Publish("indrajaal/commands/execute", serialize command)
    // THIS IS FORBIDDEN - telemetry is one-way
    // Violates SC-SEP-004
```

```fsharp
// ✅ CORRECT: F# publishes to its own namespace or uses HTTP
let sendCommand (command: Command) =
    // Option 1: HTTP through Guardian
    ElixirBridge.submitGuardianProposal (commandToProposal command)

    // Option 2: F# internal topics only
    zenoh.Publish("cepaf/internal/commands", serialize command)
```

---

# Appendix A: Module Mappings

## A.1 Elixir Core Modules

| Layer | Module | Responsibility |
|-------|--------|----------------|
| L0 | `Indrajaal.Core.Constitution` | Ψ invariants (IMMUTABLE) |
| L1 | `lib/indrajaal/domains/*` | Ash Resources |
| L2 | `lib/indrajaal/cortex/*` | OODA, GDE, Sensors |
| L3 | `lib/indrajaal/holon/*` | SQLite, DuckDB, Register |
| L4 | `lib/indrajaal/mesh/*` | Container, Zenoh NIF |
| L5 | `lib/indrajaal/application.ex` | BEAM supervision |

## A.2 F# Cortex Modules

| Layer | Module | Responsibility |
|-------|--------|----------------|
| Observer | `Cepaf.Observability.DigitalTwin` | Read-only state mirror |
| Intelligence | `Cepaf.Intelligence.*` | Analysis, planning |
| Bridge | `Cepaf.Cockpit.ElixirBridge` | HTTP to Guardian |
| Dashboard | `Cepaf.Dashboard.*` | TUI rendering |
| Federation | `Cepaf.Federation.*` | Cross-holon protocols |

---

**Document End**

| Field | Value |
|-------|-------|
| Total Lines | 900+ |
| STAMP Coverage | SC-SEP-*, SC-OBS-*, SC-SYNC-* |
| Last Updated | 2026-01-10 |
| Next Review | 2026-04-10 |
