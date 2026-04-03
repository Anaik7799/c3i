# Observer/Observed Separation Patterns for Safe Evolution

**Version**: 21.3.0-SIL6 | **Date**: 2026-01-10 | **Author**: Claude Opus 4.5
**Status**: ACTIVE | **Compliance**: IEC 61508 SIL-6 (Biomorphic Extended)
**Pass**: 4 of 8 (Specification, Architecture, Implementation, Usage)
**Prerequisite**: FRACTAL_8LAYER_CHANGE_MANAGEMENT_COMPLETE.md

---

## Document Control

| Field | Value |
|-------|-------|
| Document ID | OBS-21.3.0-001 |
| Classification | INTERNAL |
| Review Cycle | Quarterly |
| Owner | Architecture Team |
| STAMP Coverage | SC-OBS-*, SC-TEL-*, SC-TWIN-*, SC-EVO-* |
| Parent Document | FRACTAL_8LAYER_CHANGE_MANAGEMENT_COMPLETE.md |

---

## Table of Contents

1. Fundamental Separation Principle
2. Observer Safety During Evolution
3. Telemetry Architecture
4. Digital Twin Pattern
5. Evolution Observation Protocol
6. STAMP Constraints Reference
7. AOR Rules Reference
8. Implementation Examples
9. Verification Procedures

---

# 1. FUNDAMENTAL SEPARATION PRINCIPLE

## 1.1 The Four-Domain Architecture

The observer/observed separation is founded on strict domain boundaries that prevent observation from affecting the system under observation. This is critical during evolution cycles when the system is in flux.

```
+================================================================================+
|                    OBSERVER/OBSERVED SEPARATION ARCHITECTURE                    |
+================================================================================+
|                                                                                 |
|  +-------------------------------------------------------------------------+   |
|  |                     OBSERVED DOMAIN (Elixir Core)                        |   |
|  |                                                                          |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |  |    GenServers     |  |   Ash Resources   |  |   Holon State     |     |   |
|  |  |                   |  |                   |  |                   |     |   |
|  |  | - FastOODA        |  | - Access Domain   |  | - SQLite (WAL)    |     |   |
|  |  | - Guardian        |  | - Alarms Domain   |  | - DuckDB (Append) |     |   |
|  |  | - Sentinel        |  | - Device Domain   |  | - Register Chain  |     |   |
|  |  | - UnifiedBus      |  | - Safety Domain   |  | - Version Vector  |     |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |                              |                                           |   |
|  |                              | EVOLVING                                  |   |
|  |                              v                                           |   |
|  +-------------------------------------------------------------------------+   |
|                                 |                                               |
|                                 | :telemetry.execute()                          |
|                                 | Phoenix.PubSub.broadcast()                    |
|                                 v                                               |
|  +-------------------------------------------------------------------------+   |
|  |                     TELEMETRY DOMAIN (Event Stream)                      |   |
|  |                                                                          |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |  |    Zenoh Mesh     |  | Phoenix.PubSub    |  |   :telemetry      |     |   |
|  |  |                   |  |                   |  |                   |     |   |
|  |  | indrajaal/**      |  | prajna:*          |  | [:ooda, :*]       |     |   |
|  |  | zenoh:*           |  | zenoh:*           |  | [:guardian, :*]   |     |   |
|  |  | <50ms latency     |  | local broadcast   |  | [:sentinel, :*]   |     |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |                              |                                           |   |
|  |                              | IMMUTABLE EVENT STREAM                    |   |
|  |                              v                                           |   |
|  +-------------------------------------------------------------------------+   |
|                                 |                                               |
|  =============================  |  =============================================|
|  SEPARATION BOUNDARY           |   NO WRITE ACCESS FROM OBSERVER               |
|  =============================  |  =============================================|
|                                 |                                               |
|                                 v                                               |
|  +-------------------------------------------------------------------------+   |
|  |                     OBSERVER DOMAIN (F# Cortex)                          |   |
|  |                                                                          |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |  |   DigitalTwin     |  |   Intelligence    |  |   Dashboard       |     |   |
|  |  |                   |  |                   |  |                   |     |   |
|  |  | - State Mirror    |  | - EvolutionPlan   |  | - TUI Display     |     |   |
|  |  | - 30s Sync        |  | - ImpactAnalysis  |  | - Metrics View    |     |   |
|  |  | - READ-ONLY       |  | - Constitutional  |  | - Alert Viewer    |     |   |
|  |  +-------------------+  +-------------------+  +-------------------+     |   |
|  |                              |                                           |   |
|  |                              | READ-ONLY                                 |   |
|  |                              v                                           |   |
|  +-------------------------------------------------------------------------+   |
|                                 |                                               |
|                                 | Proposals ONLY                                |
|                                 v                                               |
|  +-------------------------------------------------------------------------+   |
|  |                     BRIDGE DOMAIN (Guardian Gate)                        |   |
|  |                                                                          |   |
|  |  +-------------------------------------------------------------------+   |   |
|  |  |                 SINGLE CONTROLLED WRITE PATH                      |   |   |
|  |  |                                                                   |   |   |
|  |  |  1. Receive proposal from F# Cortex via Zenoh                     |   |   |
|  |  |  2. Validate against constitutional invariants (Psi-0 to Psi-5)   |   |   |
|  |  |  3. Run shadow testing in isolation                               |   |   |
|  |  |  4. Calculate approval score (threshold >= 0.85)                  |   |   |
|  |  |  5. Log to Immutable Register BEFORE execution                    |   |   |
|  |  |  6. Execute in Elixir runtime                                     |   |   |
|  |  |  7. Emit completion telemetry for observer                        |   |   |
|  |  |                                                                   |   |   |
|  |  +-------------------------------------------------------------------+   |   |
|  |                                                                          |   |
|  +-------------------------------------------------------------------------+   |
|                                                                                 |
+================================================================================+
```

## 1.2 Domain Responsibilities

### 1.2.1 OBSERVED Domain (Elixir Core)

The OBSERVED domain is the living system that executes business logic, manages state, and undergoes evolution. It is the **only** domain that may modify system state.

| Component | Responsibility | State Type | Evolution Status |
|-----------|---------------|------------|------------------|
| GenServers | Process state, behavior | Transient | EVOLVING |
| Ash Resources | Domain models, CRUD | Persistent | EVOLVING |
| Holon State | SQLite/DuckDB | Authoritative | EVOLVING |
| OODA Loops | Decision cycles | Computational | EVOLVING |

**Key Constraint (SC-OBS-010)**: OBSERVED domain components emit telemetry but NEVER receive commands directly from the OBSERVER domain.

### 1.2.2 TELEMETRY Domain (Event Stream)

The TELEMETRY domain is an immutable, append-only event stream that captures system state and events for observation.

| Channel | Purpose | Latency Budget | Retention |
|---------|---------|---------------|-----------|
| Zenoh Mesh | Distributed pub/sub | <50ms | 24h hot, 30d cold |
| Phoenix.PubSub | Local broadcast | <5ms | Session only |
| :telemetry | Metric emission | <1ms | Aggregated to Prometheus |

**Key Constraint (SC-OBS-011)**: Telemetry events are IMMUTABLE. Once emitted, they cannot be modified or recalled.

### 1.2.3 OBSERVER Domain (F# Cortex)

The OBSERVER domain receives telemetry, analyzes patterns, and generates proposals but CANNOT directly modify the OBSERVED domain.

| Component | Function | Access Mode | Update Frequency |
|-----------|----------|-------------|------------------|
| DigitalTwin | State mirror | READ-ONLY | 30s sync |
| EvolutionPlanner | Proposal generation | ANALYSIS | On demand |
| ConstitutionalOracle | Invariant verification | ANALYSIS | Per proposal |
| Dashboard TUI | Visualization | DISPLAY | 30s refresh |

**Key Constraint (SC-OBS-012)**: OBSERVER domain has ZERO write access to OBSERVED domain state.

### 1.2.4 BRIDGE Domain (Guardian Gate)

The BRIDGE domain is the single controlled point where observer-generated proposals can affect the observed system.

| Function | Input | Output | Authorization |
|----------|-------|--------|---------------|
| Proposal Reception | F# proposal via Zenoh | Acknowledgment | Automatic |
| Constitutional Check | Proposal content | Pass/Fail | Rule-based |
| Shadow Testing | Proposal content | Test results | Isolated |
| Approval Decision | All validations | Approved/Rejected | Score >= 0.85 |
| Execution | Approved proposal | State mutation | Guardian only |

**Key Constraint (SC-OBS-013)**: ALL mutations to OBSERVED domain MUST pass through Guardian Gate.

## 1.3 Separation Invariants

The following invariants MUST be preserved at all times:

```
INV-SEP-001: Observer CANNOT directly call GenServer functions in Observed
INV-SEP-002: Observer CANNOT directly query SQLite/DuckDB in Observed
INV-SEP-003: Observer CANNOT send messages to Observed processes
INV-SEP-004: All Observer -> Observed communication goes through Guardian Gate
INV-SEP-005: Telemetry stream is append-only and immutable
INV-SEP-006: DigitalTwin sync is event-driven, not direct query
INV-SEP-007: Guardian Gate logs ALL mutations to Immutable Register
```

---

# 2. OBSERVER SAFETY DURING EVOLUTION

## 2.1 Evolution Isolation Principle

When the OBSERVED domain is undergoing evolution (GDE cycle), the OBSERVER domain MUST remain stable and unaffected. This ensures continuous monitoring even during system changes.

```
+=========================================================================+
|              EVOLUTION ISOLATION TIMELINE                                |
+=========================================================================+
|                                                                          |
|  Time    OBSERVED (Elixir)           OBSERVER (F#)                       |
|  -----   -------------------         ---------------                      |
|                                                                          |
|  T0      [STABLE STATE]              [MONITORING]                        |
|          |                           |                                   |
|          | Evolution triggered       | Receives telemetry                |
|          v                           v                                   |
|  T1      [SHADOW FORK CREATED]       [CONTINUES MONITORING]              |
|          |                           |                                   |
|          | Apply changes to shadow   | No interruption                   |
|          v                           v                                   |
|  T2      [SHADOW TESTING]            [RECORDS SHADOW METRICS]            |
|          |                           |                                   |
|          | Tests pass                | Analyzes shadow telemetry          |
|          v                           v                                   |
|  T3      [GUARDIAN APPROVAL]         [OBSERVES APPROVAL EVENT]           |
|          |                           |                                   |
|          | Activate changes          | Updates DigitalTwin               |
|          v                           v                                   |
|  T4      [NEW STABLE STATE]          [MONITORING NEW STATE]              |
|          |                           |                                   |
|                                                                          |
+=========================================================================+
```

## 2.2 F# Observation Without Affecting Running System

The F# Cortex observes the Elixir Core exclusively through the telemetry stream. This ensures:

1. **No Direct Coupling**: F# modules do not import or reference Elixir modules
2. **No Blocking Calls**: All observation is asynchronous via pub/sub
3. **No State Sharing**: DigitalTwin maintains its own copy, not a reference
4. **No Process Links**: F# processes are not linked to Elixir supervisors

### 2.2.1 F# Observation Implementation

```fsharp
// lib/cepaf/src/Observability/TelemetryReceiver.fs
namespace Indrajaal.Observability

open System
open System.Collections.Concurrent

/// Telemetry Receiver - OBSERVER ONLY
/// Receives events from Zenoh, NEVER sends commands to Elixir
module TelemetryReceiver =

    /// Event types from Elixir telemetry
    type TelemetryEvent =
        | OodaCycle of layer: string * cycleTimeUs: int64 * phases: Map<string, int64>
        | StateChange of module_name: string * oldState: obj * newState: obj
        | EvolutionProposal of id: string * layer: string * impactScore: int
        | GuardianDecision of proposalId: string * approved: bool * score: float
        | SentinelAlert of level: string * message: string * timestamp: DateTime

    /// Event buffer (FIFO, thread-safe)
    let private eventBuffer = ConcurrentQueue<TelemetryEvent>()

    /// Maximum buffer size before oldest events are dropped
    let private maxBufferSize = 10_000

    /// Subscribe to Zenoh topics - READ-ONLY
    /// SC-OBS-001: Observer MUST NOT directly modify observed state
    let subscribe (zenohClient: ZenohClient) =
        // Subscribe to all indrajaal telemetry topics
        zenohClient.Subscribe "indrajaal/*/telemetry/**" (fun topic payload ->
            let event = deserializeEvent topic payload

            // Enforce buffer limit
            while eventBuffer.Count >= maxBufferSize do
                eventBuffer.TryDequeue() |> ignore

            eventBuffer.Enqueue event

            // Log for audit trail (SC-OBS-003)
            Logger.debug $"Received telemetry: {topic}"
        )

    /// Get events for processing - does NOT affect source
    /// AOR-OBS-004: DigitalTwin SHALL sync via event stream, not direct queries
    let drainEvents () : TelemetryEvent list =
        let events = ResizeArray<TelemetryEvent>()
        let mutable event = Unchecked.defaultof<TelemetryEvent>

        while eventBuffer.TryDequeue(&event) do
            events.Add event

        events |> Seq.toList

    /// PROHIBITED: This function must NEVER exist
    /// SC-OBS-001 violation if implemented
    // let sendCommandToElixir (cmd: string) = ... // FORBIDDEN
```

## 2.3 Shadow Testing Before Activation

Before any evolution proposal is activated in production, it MUST pass shadow testing in an isolated environment that does not affect the running system.

### 2.3.1 Shadow Environment Architecture

```
+=========================================================================+
|                    SHADOW TESTING ARCHITECTURE                           |
+=========================================================================+
|                                                                          |
|  PRODUCTION ENVIRONMENT                 SHADOW ENVIRONMENT               |
|  ----------------------                 -------------------              |
|                                                                          |
|  +-------------------+                  +-------------------+            |
|  | indrajaal-app     |                  | shadow-app        |            |
|  | (Port 4000)       |    FORK ------>  | (Port 4100)       |            |
|  | LIVE TRAFFIC      |                  | NO LIVE TRAFFIC   |            |
|  +-------------------+                  +-------------------+            |
|           |                                      |                       |
|           v                                      v                       |
|  +-------------------+                  +-------------------+            |
|  | indrajaal-db      |    SNAPSHOT -->  | shadow-db         |            |
|  | (Port 5433)       |                  | (Port 5533)       |            |
|  | PRODUCTION DATA   |                  | SNAPSHOT DATA     |            |
|  +-------------------+                  +-------------------+            |
|           |                                      |                       |
|           v                                      v                       |
|  +-------------------+                  +-------------------+            |
|  | Production State  |                  | Shadow State      |            |
|  | (AUTHORITATIVE)   |                  | (EXPENDABLE)      |            |
|  +-------------------+                  +-------------------+            |
|                                                  |                       |
|                                                  v                       |
|                                         +-------------------+            |
|                                         | Shadow Telemetry  |            |
|                                         | (OBSERVER reads)  |            |
|                                         +-------------------+            |
|                                                                          |
+=========================================================================+
```

### 2.3.2 Shadow Testing Elixir Implementation

```elixir
defmodule Indrajaal.Evolution.ShadowTester do
  @moduledoc """
  Shadow testing environment for evolution proposals.

  ## STAMP Constraints
  - SC-OBS-014: Shadow environment MUST be isolated from production
  - SC-OBS-015: Shadow tests MUST complete within 5 minutes
  - SC-GDE-002: Shadow testing mandatory before activation

  ## Observer/Observed Pattern
  - This module runs in the OBSERVED domain
  - Emits telemetry for F# Cortex to observe
  - Does NOT receive commands from F# (only Guardian)
  """

  require Logger

  @shadow_timeout_ms 300_000  # 5 minutes
  @shadow_port_offset 100

  @type test_result :: :passed | :failed | {:error, term()}

  @spec run_shadow_test(proposal :: map()) :: {:ok, test_result()} | {:error, term()}
  def run_shadow_test(proposal) do
    Logger.info("Starting shadow test for proposal: #{proposal.id}")

    # Emit telemetry for observer (SC-OBS-003)
    :telemetry.execute([:shadow, :test, :start], %{
      proposal_id: proposal.id,
      layer: proposal.layer,
      timestamp: DateTime.utc_now()
    }, %{})

    with {:ok, shadow_env} <- create_shadow_environment(proposal),
         {:ok, applied} <- apply_proposal_to_shadow(shadow_env, proposal),
         {:ok, results} <- run_test_suite_in_shadow(shadow_env) do

      # Cleanup shadow environment
      cleanup_shadow(shadow_env)

      # Emit completion telemetry
      :telemetry.execute([:shadow, :test, :complete], %{
        proposal_id: proposal.id,
        result: results.status,
        test_count: results.total_tests,
        pass_count: results.passed_tests,
        duration_ms: results.duration_ms
      }, %{})

      {:ok, results.status}
    else
      {:error, reason} = error ->
        :telemetry.execute([:shadow, :test, :failed], %{
          proposal_id: proposal.id,
          reason: reason
        }, %{})
        error
    end
  end

  defp create_shadow_environment(proposal) do
    # Create isolated shadow containers
    shadow_config = %{
      app_port: 4000 + @shadow_port_offset,
      db_port: 5433 + @shadow_port_offset,
      network: "shadow-#{proposal.id}",
      volumes: create_snapshot_volumes()
    }

    case start_shadow_containers(shadow_config) do
      :ok -> {:ok, shadow_config}
      error -> error
    end
  end

  defp apply_proposal_to_shadow(shadow_env, proposal) do
    # Apply code changes to shadow environment ONLY
    # This does NOT affect production
    case proposal.type do
      :code_change ->
        apply_code_to_shadow(shadow_env, proposal.changes)

      :migration ->
        apply_migration_to_shadow(shadow_env, proposal.migration)

      :config_change ->
        apply_config_to_shadow(shadow_env, proposal.config)
    end
  end

  defp run_test_suite_in_shadow(shadow_env) do
    # Run tests with timeout
    Task.async(fn ->
      System.cmd("mix", ["test", "--trace"],
        env: [
          {"MIX_ENV", "test"},
          {"DATABASE_URL", shadow_env.db_url},
          {"PHX_PORT", to_string(shadow_env.app_port)}
        ],
        cd: shadow_env.code_path
      )
    end)
    |> Task.await(@shadow_timeout_ms)
    |> parse_test_results()
  end
end
```

## 2.4 Rollback Triggers from Observation

The OBSERVER domain can trigger rollbacks by emitting proposals to the Guardian Gate. It CANNOT directly execute rollbacks.

### 2.4.1 Rollback Trigger Conditions

| Condition | Detection Method | Observer Action | Severity |
|-----------|-----------------|-----------------|----------|
| Constitutional violation | ConstitutionalOracle | Emit rollback proposal | CRITICAL |
| Shadow test failure | TelemetryReceiver | Emit rejection signal | HIGH |
| Health degradation | DigitalTwin.GetHealth() | Emit alert + proposal | HIGH |
| Error budget exceeded | Metrics analysis | Emit scale-down proposal | MEDIUM |
| OODA cycle timeout | Cycle time monitoring | Emit alert | MEDIUM |

### 2.4.2 F# Rollback Proposal Implementation

```fsharp
// lib/cepaf/src/Intelligence/RollbackProposer.fs
namespace Indrajaal.Intelligence

open System
open Indrajaal.Observability

/// Rollback Proposer - OBSERVER ONLY
/// Generates rollback proposals based on observed telemetry
/// SC-OBS-001: CANNOT directly execute rollback, MUST go through Guardian
module RollbackProposer =

    /// Rollback proposal sent to Guardian via Zenoh
    type RollbackProposal = {
        Id: string
        Trigger: string
        TargetLayer: string
        RollbackTo: string  // Checkpoint ID or git commit
        Urgency: string     // IMMEDIATE | HIGH | NORMAL
        Evidence: TelemetryEvent list
        Timestamp: DateTime
    }

    /// Analyze observed state and determine if rollback needed
    /// AOR-OBS-003: Proposals SHALL be sent to Guardian for validation
    let analyzeForRollback (twin: DigitalTwin) (recentEvents: TelemetryEvent list) =
        let issues = detectIssues recentEvents

        match issues with
        | [] ->
            None  // No rollback needed

        | issues when hasConstitutionalViolation issues ->
            // CRITICAL: Constitutional violation detected
            Some {
                Id = generateProposalId()
                Trigger = "Constitutional violation"
                TargetLayer = "L3"
                RollbackTo = twin.LastKnownGoodCheckpoint
                Urgency = "IMMEDIATE"
                Evidence = issues |> List.map extractEvent
                Timestamp = DateTime.UtcNow
            }

        | issues when hasCriticalHealthDegradation issues twin ->
            // HIGH: Health below threshold
            Some {
                Id = generateProposalId()
                Trigger = "Health degradation"
                TargetLayer = "L2"
                RollbackTo = findLastHealthyCommit twin
                Urgency = "HIGH"
                Evidence = issues |> List.map extractEvent
                Timestamp = DateTime.UtcNow
            }

        | _ -> None

    /// Submit rollback proposal to Guardian via Zenoh
    /// SC-OBS-013: ALL mutations MUST pass through Guardian Gate
    let submitRollbackProposal (zenohClient: ZenohClient) (proposal: RollbackProposal) =
        let topic = "indrajaal/guardian/proposals/rollback"
        let payload = serializeProposal proposal

        // Publish proposal - Guardian will receive and process
        zenohClient.Publish topic payload

        // Log for audit trail
        Logger.info $"Submitted rollback proposal {proposal.Id} via Guardian Gate"

    /// PROHIBITED: Direct rollback execution
    /// SC-OBS-001 violation if implemented
    // let executeRollbackDirectly (checkpoint: string) = ... // FORBIDDEN
```

## 2.5 State Consistency Guarantees

State consistency between OBSERVED and OBSERVER domains is maintained through:

1. **Event Sourcing**: All state changes emit telemetry events
2. **Version Vectors**: DigitalTwin tracks versions to detect divergence
3. **Consistency Checkpoints**: Periodic full-state snapshots
4. **Divergence Detection**: Automated comparison of expected vs observed state

### 2.5.1 Consistency Verification

```elixir
defmodule Indrajaal.Holon.ConsistencyVerifier do
  @moduledoc """
  Verifies consistency between Elixir state and DigitalTwin expectations.

  ## STAMP Constraints
  - SC-OBS-016: Consistency check MUST run every 5 minutes
  - SC-OBS-017: Divergence > 1% triggers alert
  """

  @check_interval_ms 300_000  # 5 minutes
  @divergence_threshold 0.01  # 1%

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    schedule_check()
    {:ok, %{last_check: nil, divergence_count: 0}}
  end

  def handle_info(:check_consistency, state) do
    # Get current state hash from SQLite
    {:ok, local_hash} = compute_state_hash()

    # Get expected hash from last DigitalTwin sync event
    {:ok, expected_hash} = get_expected_hash_from_telemetry()

    divergence = calculate_divergence(local_hash, expected_hash)

    # Emit telemetry for observer
    :telemetry.execute([:consistency, :check], %{
      local_hash: local_hash,
      expected_hash: expected_hash,
      divergence: divergence,
      threshold: @divergence_threshold
    }, %{})

    new_state =
      if divergence > @divergence_threshold do
        Logger.warn("State divergence detected: #{divergence * 100}%")

        # Emit alert telemetry
        :telemetry.execute([:consistency, :divergence, :alert], %{
          divergence: divergence,
          local_hash: local_hash,
          expected_hash: expected_hash
        }, %{})

        %{state | divergence_count: state.divergence_count + 1}
      else
        %{state | divergence_count: 0}
      end

    schedule_check()
    {:noreply, %{new_state | last_check: DateTime.utc_now()}}
  end

  defp schedule_check do
    Process.send_after(self(), :check_consistency, @check_interval_ms)
  end
end
```

---

# 3. TELEMETRY ARCHITECTURE

## 3.1 Event Types

The telemetry system defines four primary event types that flow from OBSERVED to OBSERVER domain.

### 3.1.1 Event Type Definitions

| Event Type | Source | Purpose | Frequency |
|------------|--------|---------|-----------|
| `:ooda_cycle` | FastOODA, StrategyOODA | Cycle timing metrics | Every cycle |
| `:state_change` | GenServers, Ash Resources | State mutation notifications | On change |
| `:evolution_proposal` | GDE Controller | New evolution candidates | On proposal |
| `:guardian_decision` | Guardian | Approval/rejection results | On decision |

### 3.1.2 Event Schema Definitions

```elixir
defmodule Indrajaal.Telemetry.EventSchemas do
  @moduledoc """
  Schema definitions for telemetry events.

  ## STAMP Constraints
  - SC-TEL-001: All events MUST conform to defined schemas
  - SC-TEL-002: Schema violations logged but not blocking
  """

  @type ooda_cycle_event :: %{
    required(:layer) => :L1_L2 | :L3_L4 | :L5_L7,
    required(:cycle_time_us) => non_neg_integer(),
    required(:observe_us) => non_neg_integer(),
    required(:orient_us) => non_neg_integer(),
    required(:decide_us) => non_neg_integer(),
    required(:act_us) => non_neg_integer(),
    required(:cycle_number) => non_neg_integer(),
    optional(:decision_type) => atom()
  }

  @type state_change_event :: %{
    required(:module) => module(),
    required(:change_type) => :create | :update | :delete,
    required(:entity_id) => String.t(),
    required(:old_state_hash) => String.t() | nil,
    required(:new_state_hash) => String.t(),
    required(:timestamp) => DateTime.t()
  }

  @type evolution_proposal_event :: %{
    required(:proposal_id) => String.t(),
    required(:layer) => atom(),
    required(:type) => :code_change | :migration | :config_change,
    required(:impact_score) => non_neg_integer(),
    required(:fitness_score) => float(),
    required(:files_affected) => list(String.t()),
    required(:constitutional_check) => :pending | :passed | :failed,
    required(:timestamp) => DateTime.t()
  }

  @type guardian_decision_event :: %{
    required(:proposal_id) => String.t(),
    required(:approved) => boolean(),
    required(:score) => float(),
    required(:validation_results) => list({atom(), :ok | {:error, term()}}),
    required(:shadow_test_result) => :passed | :failed | :skipped,
    required(:execution_status) => :pending | :executed | :rolled_back,
    required(:timestamp) => DateTime.t()
  }
end
```

## 3.2 Zenoh Key Expressions

Zenoh is the primary transport for distributed telemetry. Key expressions follow a hierarchical namespace.

### 3.2.1 Key Expression Hierarchy

```
indrajaal/                              # Root namespace
  +-- {holon_id}/                       # Holon identifier
  |     +-- telemetry/                  # Telemetry subtree
  |     |     +-- ooda/                 # OODA cycle metrics
  |     |     |     +-- fast/           # L1-L2 cycles
  |     |     |     +-- distributed/    # L3-L4 cycles
  |     |     |     +-- strategy/       # L5-L7 cycles
  |     |     +-- state/                # State change events
  |     |     |     +-- {domain}/       # Domain-specific
  |     |     +-- health/               # Health metrics
  |     |           +-- sentinel/       # Sentinel reports
  |     |           +-- fpps/           # FPPS validation
  |     +-- evolution/                  # Evolution events
  |     |     +-- proposals/            # New proposals
  |     |     +-- decisions/            # Guardian decisions
  |     |     +-- activations/          # Activated changes
  |     +-- guardian/                   # Guardian channel
  |           +-- proposals/            # Incoming proposals
  |           +-- decisions/            # Decision broadcasts
  |           +-- rollbacks/            # Rollback requests
  +-- federation/                       # Cross-holon
        +-- attestations/               # Peer attestations
        +-- negotiations/               # Protocol negotiations
```

### 3.2.2 Zenoh Subscription Patterns

```elixir
defmodule Indrajaal.Mesh.ZenohSubscriber do
  @moduledoc """
  Zenoh subscription manager for telemetry.

  ## STAMP Constraints
  - SC-TEL-003: Subscriptions MUST use appropriate key expressions
  - SC-TEL-004: Latency budget: <50ms per message
  """

  @zenoh_key_expressions %{
    # Observer subscriptions (F# Cortex receives these)
    telemetry_all: "indrajaal/*/telemetry/**",
    ooda_cycles: "indrajaal/*/telemetry/ooda/**",
    state_changes: "indrajaal/*/telemetry/state/**",
    health_reports: "indrajaal/*/telemetry/health/**",
    evolution_events: "indrajaal/*/evolution/**",

    # Guardian channel (bidirectional)
    guardian_proposals: "indrajaal/*/guardian/proposals/**",
    guardian_decisions: "indrajaal/*/guardian/decisions/**"
  }

  @spec subscribe(atom()) :: {:ok, subscription_id()} | {:error, term()}
  def subscribe(key_type) when is_map_key(@zenoh_key_expressions, key_type) do
    key_expr = Map.fetch!(@zenoh_key_expressions, key_type)

    Zenoh.subscribe(key_expr, fn topic, payload ->
      # Enforce latency budget (SC-TEL-004)
      start = System.monotonic_time(:microsecond)

      handle_message(key_type, topic, payload)

      elapsed = System.monotonic_time(:microsecond) - start
      if elapsed > 50_000 do  # 50ms in microseconds
        Logger.warn("Zenoh message processing exceeded latency budget: #{elapsed}us")
      end
    end)
  end
end
```

## 3.3 Phoenix.PubSub Topics

For local (same-node) telemetry, Phoenix.PubSub provides lower-latency broadcast.

### 3.3.1 Topic Definitions

| Topic Pattern | Purpose | Subscribers |
|---------------|---------|-------------|
| `prajna:kpi` | Key performance indicators | Dashboard, Sentinel |
| `prajna:alerts` | Alert broadcasts | Dashboard, NotifyEngine |
| `prajna:evolution` | Evolution status | Dashboard |
| `zenoh:kpi` | Zenoh KPIs (bridge) | ZenohLiveViewBridge |
| `zenoh:metrics` | Zenoh metrics (bridge) | ZenohLiveViewBridge |
| `zenoh:agents` | Agent status (bridge) | ZenohLiveViewBridge |
| `zenoh:health` | Health status (bridge) | ZenohLiveViewBridge |
| `zenoh:safety` | Safety alerts (bridge) | ZenohLiveViewBridge |

### 3.3.2 PubSub Broadcasting

```elixir
defmodule Indrajaal.Telemetry.LocalBroadcaster do
  @moduledoc """
  Local PubSub broadcaster for telemetry events.

  ## STAMP Constraints
  - SC-BRIDGE-001: Message buffer uses FIFO ordering
  - SC-BRIDGE-002: Buffer flush interval 100ms maximum
  - SC-BRIDGE-003: Latency budget 50ms per batch
  """

  @pubsub Indrajaal.PubSub
  @topics %{
    kpi: "prajna:kpi",
    alerts: "prajna:alerts",
    evolution: "prajna:evolution"
  }

  @spec broadcast_kpi(map()) :: :ok
  def broadcast_kpi(metrics) do
    Phoenix.PubSub.broadcast(@pubsub, @topics.kpi, {:kpi_update, metrics})
  end

  @spec broadcast_alert(map()) :: :ok
  def broadcast_alert(alert) do
    Phoenix.PubSub.broadcast(@pubsub, @topics.alerts, {:alert, alert})
  end

  @spec broadcast_evolution_status(map()) :: :ok
  def broadcast_evolution_status(status) do
    Phoenix.PubSub.broadcast(@pubsub, @topics.evolution, {:evolution, status})
  end
end
```

## 3.4 Latency Budgets per Layer

| Layer | Event Type | Latency Budget | Transport |
|-------|------------|---------------|-----------|
| L1-L2 | OODA cycle | <5ms | :telemetry + PubSub |
| L3 | State change | <20ms | Zenoh local |
| L4 | Container health | <100ms | Zenoh mesh |
| L5-L7 | Strategy OODA | <500ms | Zenoh mesh |
| Cross-holon | Federation | <1000ms | Zenoh federation |

---

# 4. DIGITAL TWIN PATTERN

## 4.1 Read-Only Mirror Architecture

The DigitalTwin is a read-only mirror of the OBSERVED system state, maintained in the OBSERVER domain (F# Cortex).

```
+==========================================================================+
|                        DIGITAL TWIN ARCHITECTURE                          |
+==========================================================================+
|                                                                           |
|  OBSERVED (Elixir)                     OBSERVER (F#)                      |
|  -----------------                     ---------------                     |
|                                                                           |
|  +-------------------+                 +-------------------+              |
|  | Production State  |                 | DigitalTwin       |              |
|  |                   |                 |                   |              |
|  | SQLite (WAL)      |  --- events --> | MirroredState     |              |
|  | DuckDB (Append)   |                 | (In-Memory)       |              |
|  | GenServer State   |                 |                   |              |
|  +-------------------+                 +-------------------+              |
|         |                                      |                          |
|         | AUTHORITATIVE                        | READ-ONLY COPY           |
|         |                                      |                          |
|         v                                      v                          |
|  +-------------------+                 +-------------------+              |
|  | State Hash        |  --- verify --> | Expected Hash     |              |
|  | (SHA-256)         |                 | (Computed)        |              |
|  +-------------------+                 +-------------------+              |
|                                                                           |
|  INVARIANT: DigitalTwin NEVER writes to Production State                 |
|                                                                           |
+==========================================================================+
```

## 4.2 Sync Interval and Mechanism

The DigitalTwin synchronizes with production state via the telemetry stream, with a target sync interval of 30 seconds.

### 4.2.1 F# DigitalTwin Implementation

```fsharp
// lib/cepaf/src/Observability/DigitalTwin.fs
namespace Indrajaal.Observability

open System
open System.Collections.Concurrent

/// Digital Twin - Authoritative READ-ONLY mirror of system state
/// SC-OBS-003: DigitalTwin MUST be read-only mirror
/// SC-TWIN-001: Sync interval = 30 seconds
module DigitalTwin =

    /// Mirrored state structure
    type MirroredState = {
        Containers: Map<string, ContainerState>
        Agents: Map<string, AgentState>
        OodaMetrics: OodaMetricsState
        EvolutionQueue: EvolutionProposal list
        LastSync: DateTime
        StateHash: string
        VersionVector: Map<string, int64>
    }

    /// Container state mirror
    and ContainerState = {
        Name: string
        Status: string  // healthy, unhealthy, created
        Ports: int list
        Uptime: TimeSpan option
        LastHealthCheck: DateTime
    }

    /// Agent state mirror
    and AgentState = {
        Id: string
        Layer: string
        Status: string  // active, idle, suspended
        LastCycleTime: int64 option
        TaskCount: int
    }

    /// OODA metrics mirror
    and OodaMetricsState = {
        FastCycleAvgUs: int64
        DistributedCycleAvgUs: int64
        StrategyCycleAvgMs: int64
        CycleCount: int64
    }

    /// Mutable twin state (thread-safe)
    let mutable private twinState: MirroredState option = None
    let private stateLock = obj()

    /// Sync interval (30 seconds)
    let private syncIntervalMs = 30_000

    /// Last sync timestamp
    let mutable private lastSyncTime = DateTime.MinValue

    /// Get current mirrored state (READ-ONLY)
    /// AOR-OBS-005: Dashboard TUI SHALL display cached state, not live queries
    let getState () : MirroredState option =
        lock stateLock (fun () -> twinState)

    /// Update twin from telemetry events (internal only)
    /// SC-OBS-004: Telemetry stream MUST be immutable
    let internal updateFromEvents (events: TelemetryEvent list) =
        lock stateLock (fun () ->
            let currentState =
                match twinState with
                | Some s -> s
                | None -> createInitialState()

            let updatedState =
                events
                |> List.fold applyEvent currentState

            twinState <- Some { updatedState with
                LastSync = DateTime.UtcNow
                StateHash = computeStateHash updatedState
            }

            lastSyncTime <- DateTime.UtcNow
        )

    /// Apply single event to state
    let private applyEvent (state: MirroredState) (event: TelemetryEvent) =
        match event with
        | OodaCycle (layer, cycleTime, phases) ->
            updateOodaMetrics state layer cycleTime phases

        | StateChange (moduleName, _, newStateHash) ->
            updateVersionVector state moduleName

        | EvolutionProposal (id, layer, score) ->
            addEvolutionToQueue state id layer score

        | GuardianDecision (proposalId, approved, score) ->
            updateEvolutionStatus state proposalId approved score

        | _ -> state

    /// Check if sync is stale (> 60s old)
    /// SC-PROM-003: Stale data > 60s triggers Alert
    let isSyncStale () =
        (DateTime.UtcNow - lastSyncTime).TotalSeconds > 60.0

    /// Get cluster health from mirrored state
    /// Used by StrategyOODA for observation
    let GetClusterHealth () : float =
        match getState() with
        | Some state ->
            let healthyContainers =
                state.Containers
                |> Map.filter (fun _ c -> c.Status = "healthy")
                |> Map.count
            let totalContainers = state.Containers |> Map.count
            if totalContainers = 0 then 1.0
            else float healthyContainers / float totalContainers
        | None -> 0.0

    /// Get pending evolutions from queue
    let GetPendingEvolutions () : EvolutionProposal list =
        match getState() with
        | Some state -> state.EvolutionQueue
        | None -> []

    /// Get last OODA metrics
    let GetLastOODAMetrics () : OodaMetricsState option =
        match getState() with
        | Some state -> Some state.OodaMetrics
        | None -> None

    /// PROHIBITED: Write operations to production
    /// SC-OBS-001, SC-OBS-012 violation if implemented
    // let writeToProduction (key: string) (value: obj) = ... // FORBIDDEN
    // let sendCommandToElixir (cmd: string) = ... // FORBIDDEN
```

## 4.3 Consistency Verification

The DigitalTwin maintains consistency with production through hash verification.

### 4.3.1 Hash Chain Verification

```fsharp
// lib/cepaf/src/Observability/ConsistencyVerifier.fs
namespace Indrajaal.Observability

open System
open System.Security.Cryptography

/// Consistency Verifier - Detects divergence between Twin and Production
/// SC-OBS-016: Consistency check MUST run every 5 minutes
/// SC-OBS-017: Divergence > 1% triggers alert
module ConsistencyVerifier =

    /// Verification result
    type VerificationResult =
        | Consistent of hash: string
        | Divergent of expected: string * actual: string * divergencePercent: float
        | Unknown of reason: string

    /// Compute hash of DigitalTwin state
    let computeTwinHash (twin: DigitalTwin.MirroredState) : string =
        use sha256 = SHA256.Create()

        let stateBytes =
            twin
            |> serializeState
            |> System.Text.Encoding.UTF8.GetBytes

        sha256.ComputeHash(stateBytes)
        |> Array.map (fun b -> b.ToString("x2"))
        |> String.concat ""

    /// Verify consistency with production
    /// Receives production hash via telemetry (does NOT query production)
    let verify (twin: DigitalTwin.MirroredState option) (productionHashEvent: TelemetryEvent option) =
        match twin, productionHashEvent with
        | Some t, Some (StateHash productionHash) ->
            let twinHash = computeTwinHash t

            if twinHash = productionHash then
                Consistent twinHash
            else
                let divergence = calculateDivergence twinHash productionHash
                Divergent (twinHash, productionHash, divergence)

        | None, _ ->
            Unknown "DigitalTwin not initialized"

        | _, None ->
            Unknown "No production hash received"

    /// Calculate divergence percentage
    let private calculateDivergence (hash1: string) (hash2: string) =
        let diffBits =
            Seq.zip hash1 hash2
            |> Seq.filter (fun (a, b) -> a <> b)
            |> Seq.length

        float diffBits / float hash1.Length
```

## 4.4 Divergence Detection and Response

When divergence is detected, the OBSERVER domain emits alerts but does NOT attempt to fix the divergence directly.

```fsharp
// lib/cepaf/src/Observability/DivergenceHandler.fs
namespace Indrajaal.Observability

/// Divergence Handler - Responds to consistency violations
/// SC-OBS-017: Divergence > 1% triggers alert
module DivergenceHandler =

    /// Handle divergence detection
    /// OBSERVER ONLY - emits alerts, does NOT fix directly
    let handleDivergence (result: ConsistencyVerifier.VerificationResult) (zenohClient: ZenohClient) =
        match result with
        | ConsistencyVerifier.Divergent (expected, actual, percent) when percent > 0.01 ->
            // Emit alert via Zenoh (OBSERVER action)
            let alert = {|
                AlertType = "CONSISTENCY_DIVERGENCE"
                Severity = if percent > 0.05 then "CRITICAL" else "HIGH"
                ExpectedHash = expected
                ActualHash = actual
                DivergencePercent = percent
                Timestamp = DateTime.UtcNow
            |}

            zenohClient.Publish "indrajaal/alerts/consistency" (serialize alert)

            // If critical, emit rollback proposal to Guardian
            if percent > 0.05 then
                let proposal = {|
                    Type = "CONSISTENCY_ROLLBACK"
                    Trigger = "Divergence > 5%"
                    TargetCheckpoint = "last_consistent"
                    Urgency = "HIGH"
                |}
                zenohClient.Publish "indrajaal/guardian/proposals/rollback" (serialize proposal)

        | ConsistencyVerifier.Consistent _ ->
            // Log success (no action needed)
            Logger.debug "Consistency verified"

        | _ -> ()
```

---

# 5. EVOLUTION OBSERVATION PROTOCOL

## 5.1 Pre-Evolution Snapshot

Before any evolution begins, the system captures a snapshot for potential rollback.

### 5.1.1 Snapshot Protocol

```
+=========================================================================+
|                    PRE-EVOLUTION SNAPSHOT PROTOCOL                       |
+=========================================================================+
|                                                                          |
|  Step 1: CHECKPOINT CREATION (Elixir - OBSERVED)                        |
|  ├─ SQLite snapshot to data/checkpoints/{timestamp}.sqlite              |
|  ├─ DuckDB checkpoint (append marker)                                   |
|  ├─ Git commit (code state)                                             |
|  ├─ Container image tag (if L4+)                                        |
|  └─ Emit :checkpoint_created telemetry                                  |
|                                                                          |
|  Step 2: SNAPSHOT VERIFICATION (F# - OBSERVER)                          |
|  ├─ DigitalTwin records checkpoint event                                |
|  ├─ Verify hash matches expected                                        |
|  ├─ Store checkpoint ID in evolution context                            |
|  └─ Update LastKnownGoodCheckpoint                                      |
|                                                                          |
|  Step 3: EVOLUTION CLEARANCE (Guardian - BRIDGE)                        |
|  ├─ Verify checkpoint exists                                            |
|  ├─ Verify rollback path tested                                         |
|  ├─ Set evolution_in_progress flag                                      |
|  └─ Emit :evolution_started telemetry                                   |
|                                                                          |
+=========================================================================+
```

### 5.1.2 Elixir Snapshot Implementation

```elixir
defmodule Indrajaal.Evolution.SnapshotManager do
  @moduledoc """
  Pre-evolution snapshot management.

  ## STAMP Constraints
  - SC-EVO-001: Snapshot MUST be created before evolution
  - SC-EVO-002: Snapshot MUST be verified before clearance
  - SC-UCR-001: 4-phase checkpoint architecture MANDATORY
  """

  require Logger

  @checkpoint_dir "data/checkpoints"

  @type snapshot_id :: String.t()

  @spec create_pre_evolution_snapshot(proposal_id :: String.t()) ::
    {:ok, snapshot_id()} | {:error, term()}
  def create_pre_evolution_snapshot(proposal_id) do
    snapshot_id = generate_snapshot_id(proposal_id)
    snapshot_path = Path.join(@checkpoint_dir, snapshot_id)

    Logger.info("Creating pre-evolution snapshot: #{snapshot_id}")

    with :ok <- File.mkdir_p(snapshot_path),
         {:ok, sqlite_path} <- snapshot_sqlite(snapshot_path),
         {:ok, duckdb_marker} <- snapshot_duckdb(snapshot_path),
         {:ok, git_sha} <- snapshot_git(),
         {:ok, manifest} <- create_manifest(snapshot_id, %{
           sqlite: sqlite_path,
           duckdb_marker: duckdb_marker,
           git_sha: git_sha,
           timestamp: DateTime.utc_now()
         }) do

      # Emit telemetry for observer
      :telemetry.execute([:evolution, :snapshot, :created], %{
        snapshot_id: snapshot_id,
        proposal_id: proposal_id,
        sqlite_path: sqlite_path,
        git_sha: git_sha
      }, %{})

      {:ok, snapshot_id}
    else
      {:error, reason} = error ->
        Logger.error("Snapshot creation failed: #{inspect(reason)}")

        :telemetry.execute([:evolution, :snapshot, :failed], %{
          proposal_id: proposal_id,
          reason: reason
        }, %{})

        error
    end
  end

  @spec verify_snapshot(snapshot_id()) :: :ok | {:error, term()}
  def verify_snapshot(snapshot_id) do
    snapshot_path = Path.join(@checkpoint_dir, snapshot_id)

    with {:ok, manifest} <- read_manifest(snapshot_path),
         :ok <- verify_sqlite_integrity(manifest.sqlite),
         :ok <- verify_duckdb_marker(manifest.duckdb_marker),
         :ok <- verify_git_sha_exists(manifest.git_sha) do

      :telemetry.execute([:evolution, :snapshot, :verified], %{
        snapshot_id: snapshot_id
      }, %{})

      :ok
    end
  end

  defp snapshot_sqlite(snapshot_path) do
    source = "data/holons/primary.sqlite"
    dest = Path.join(snapshot_path, "state.sqlite")

    # Use SQLite backup API for consistent snapshot
    {:ok, conn} = Exqlite.Sqlite3.open(source)
    result = Exqlite.Sqlite3.execute(conn, "VACUUM INTO '#{dest}'")
    Exqlite.Sqlite3.close(conn)

    case result do
      :ok -> {:ok, dest}
      error -> error
    end
  end
end
```

## 5.2 During-Evolution Monitoring

While evolution is in progress, the OBSERVER domain maintains heightened monitoring.

### 5.2.1 Evolution Monitoring Protocol

```fsharp
// lib/cepaf/src/Intelligence/EvolutionMonitor.fs
namespace Indrajaal.Intelligence

open System
open Indrajaal.Observability

/// Evolution Monitor - Observes system during evolution
/// SC-OBS-018: Monitoring frequency increases 10x during evolution
module EvolutionMonitor =

    /// Evolution monitoring state
    type MonitoringState = {
        EvolutionId: string
        StartTime: DateTime
        BaselineMetrics: Map<string, float>
        CurrentMetrics: Map<string, float>
        Alerts: string list
        Phase: string
    }

    /// Monitoring frequency (normal vs evolution)
    let private normalIntervalMs = 30_000    // 30 seconds
    let private evolutionIntervalMs = 3_000  // 3 seconds (10x faster)

    /// Start evolution monitoring session
    let startMonitoring (evolutionId: string) (twin: DigitalTwin.MirroredState option) =
        let baseline =
            match twin with
            | Some t -> extractMetrics t
            | None -> Map.empty

        {
            EvolutionId = evolutionId
            StartTime = DateTime.UtcNow
            BaselineMetrics = baseline
            CurrentMetrics = baseline
            Alerts = []
            Phase = "STARTED"
        }

    /// Update monitoring with new telemetry
    /// AOR-OBS-001: F# Cortex SHALL receive telemetry via Zenoh subscription only
    let updateMonitoring (state: MonitoringState) (events: TelemetryEvent list) =
        let currentMetrics = extractMetricsFromEvents events
        let alerts = detectAnomalies state.BaselineMetrics currentMetrics

        { state with
            CurrentMetrics = currentMetrics
            Alerts = state.Alerts @ alerts
            Phase = determinePhase events
        }

    /// Detect anomalies during evolution
    let private detectAnomalies (baseline: Map<string, float>) (current: Map<string, float>) =
        let anomalies = ResizeArray<string>()

        // Check OODA cycle degradation
        match Map.tryFind "ooda_fast_avg_us" baseline, Map.tryFind "ooda_fast_avg_us" current with
        | Some b, Some c when c > b * 2.0 ->
            anomalies.Add $"OODA fast cycle degraded: {b}us -> {c}us"
        | _ -> ()

        // Check error rate spike
        match Map.tryFind "error_rate" baseline, Map.tryFind "error_rate" current with
        | Some b, Some c when c > b + 0.05 ->
            anomalies.Add $"Error rate spike: {b*100.0}% -> {c*100.0}%"
        | _ -> ()

        // Check memory growth
        match Map.tryFind "memory_mb" baseline, Map.tryFind "memory_mb" current with
        | Some b, Some c when c > b * 1.5 ->
            anomalies.Add $"Memory growth: {b}MB -> {c}MB"
        | _ -> ()

        anomalies |> Seq.toList

    /// Determine if rollback should be recommended
    /// SC-OBS-019: Anomaly count > 3 triggers rollback recommendation
    let shouldRecommendRollback (state: MonitoringState) =
        state.Alerts.Length > 3 ||
        List.exists (fun a -> a.Contains "CRITICAL") state.Alerts
```

## 5.3 Post-Evolution Validation

After evolution completes, comprehensive validation ensures system stability.

### 5.3.1 Validation Checklist

| Check | Layer | Method | Threshold |
|-------|-------|--------|-----------|
| Compilation | L1 | `mix compile` | 0 errors |
| Tests | L1-L2 | `mix test` | 100% pass |
| OODA timing | L1-L3 | Telemetry | < baseline * 1.5 |
| Container health | L4 | Health check | All healthy |
| Consistency | L3 | Hash verify | < 1% divergence |
| Constitutional | All | Oracle check | All pass |

### 5.3.2 Post-Evolution Validation Implementation

```elixir
defmodule Indrajaal.Evolution.PostValidator do
  @moduledoc """
  Post-evolution validation suite.

  ## STAMP Constraints
  - SC-EVO-003: All validation checks MUST pass for evolution success
  - SC-EVO-004: Validation timeout = 5 minutes
  """

  require Logger

  @validation_timeout_ms 300_000

  @type validation_result :: %{
    passed: boolean(),
    checks: list({atom(), :ok | {:error, term()}}),
    duration_ms: non_neg_integer()
  }

  @spec validate_evolution(proposal_id :: String.t()) :: validation_result()
  def validate_evolution(proposal_id) do
    Logger.info("Starting post-evolution validation for: #{proposal_id}")
    start_time = System.monotonic_time(:millisecond)

    checks = [
      {:compilation, validate_compilation()},
      {:tests, validate_tests()},
      {:ooda_timing, validate_ooda_timing()},
      {:container_health, validate_containers()},
      {:consistency, validate_consistency()},
      {:constitutional, validate_constitutional()}
    ]

    duration = System.monotonic_time(:millisecond) - start_time
    all_passed = Enum.all?(checks, fn {_, result} -> result == :ok end)

    result = %{
      passed: all_passed,
      checks: checks,
      duration_ms: duration
    }

    # Emit telemetry for observer
    :telemetry.execute([:evolution, :validation, :complete], %{
      proposal_id: proposal_id,
      passed: all_passed,
      check_count: length(checks),
      passed_count: Enum.count(checks, fn {_, r} -> r == :ok end),
      duration_ms: duration
    }, %{})

    result
  end

  defp validate_compilation do
    case System.cmd("mix", ["compile", "--warnings-as-errors"],
           env: [{"MIX_ENV", "prod"}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, {:compilation_failed, output}}
    end
  end

  defp validate_tests do
    case System.cmd("mix", ["test", "--max-failures", "1"],
           env: [{"MIX_ENV", "test"}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, {:tests_failed, output}}
    end
  end

  defp validate_ooda_timing do
    # Get recent OODA metrics from telemetry
    case get_recent_ooda_metrics() do
      {:ok, metrics} when metrics.fast_avg_us < 100_000 -> :ok
      {:ok, metrics} -> {:error, {:ooda_slow, metrics.fast_avg_us}}
      error -> error
    end
  end

  defp validate_containers do
    # Check all containers are healthy
    case Indrajaal.Container.Manager.health_check_all() do
      :all_healthy -> :ok
      {:unhealthy, containers} -> {:error, {:unhealthy_containers, containers}}
    end
  end

  defp validate_consistency do
    # Trigger consistency check
    case Indrajaal.Holon.ConsistencyVerifier.check_now() do
      {:ok, divergence} when divergence < 0.01 -> :ok
      {:ok, divergence} -> {:error, {:divergence, divergence}}
      error -> error
    end
  end

  defp validate_constitutional do
    # Run constitutional oracle
    case Indrajaal.Agents.Guardian.constitutional_check() do
      {:ok, :all_passed} -> :ok
      {:failed, violations} -> {:error, {:constitutional_violations, violations}}
    end
  end
end
```

## 5.4 Rollback Trigger Conditions

Rollback is triggered when specific conditions are detected during or after evolution.

### 5.4.1 Automatic Rollback Triggers

| Trigger | Detection | Response Time | Severity |
|---------|-----------|---------------|----------|
| Constitutional violation | ConstitutionalOracle | <1s | CRITICAL |
| Compilation failure | `mix compile` exit code | <5s | CRITICAL |
| Test failure > 10% | Test result parsing | <30s | HIGH |
| OODA timeout | Cycle time > 2x baseline | <10s | HIGH |
| Container crash | Health check failure | <30s | HIGH |
| Memory exhaustion | OOM detection | <5s | CRITICAL |
| Divergence > 5% | Consistency check | <5min | HIGH |

### 5.4.2 Rollback Execution

```elixir
defmodule Indrajaal.Evolution.RollbackExecutor do
  @moduledoc """
  Rollback execution for failed evolutions.

  ## STAMP Constraints
  - SC-EVO-005: Rollback MUST complete within 5 minutes
  - SC-EMR-057: Emergency stop < 5 seconds
  - SC-EMR-060: Rollback capability MANDATORY
  """

  require Logger

  @rollback_timeout_ms 300_000

  @spec execute_rollback(snapshot_id :: String.t(), reason :: term()) ::
    {:ok, :rolled_back} | {:error, term()}
  def execute_rollback(snapshot_id, reason) do
    Logger.warn("Executing rollback to snapshot: #{snapshot_id}, reason: #{inspect(reason)}")

    # Log to Immutable Register BEFORE rollback
    Indrajaal.Holon.ImmutableRegister.append_block(%{
      type: :rollback_initiated,
      snapshot_id: snapshot_id,
      reason: reason,
      timestamp: DateTime.utc_now()
    })

    # Emit telemetry for observer
    :telemetry.execute([:evolution, :rollback, :start], %{
      snapshot_id: snapshot_id,
      reason: inspect(reason)
    }, %{})

    with {:ok, manifest} <- load_snapshot_manifest(snapshot_id),
         :ok <- restore_sqlite(manifest.sqlite),
         :ok <- restore_git(manifest.git_sha),
         :ok <- restart_containers(),
         :ok <- verify_restoration() do

      :telemetry.execute([:evolution, :rollback, :complete], %{
        snapshot_id: snapshot_id,
        success: true
      }, %{})

      {:ok, :rolled_back}
    else
      {:error, reason} = error ->
        Logger.error("Rollback failed: #{inspect(reason)}")

        :telemetry.execute([:evolution, :rollback, :failed], %{
          snapshot_id: snapshot_id,
          reason: inspect(reason)
        }, %{})

        # Emit critical alert
        :telemetry.execute([:alert, :critical], %{
          type: :rollback_failed,
          snapshot_id: snapshot_id,
          reason: reason
        }, %{})

        error
    end
  end
end
```

---

# 6. STAMP CONSTRAINTS REFERENCE

## 6.1 Observer Separation Constraints (SC-OBS-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-OBS-001 | Observer MUST NOT directly modify observed state | CRITICAL | Code review, static analysis |
| SC-OBS-002 | All mutations MUST go through Guardian gate | CRITICAL | Architecture enforcement |
| SC-OBS-003 | DigitalTwin MUST be read-only mirror | HIGH | Type system, F# immutability |
| SC-OBS-004 | Telemetry stream MUST be immutable | HIGH | Append-only design |
| SC-OBS-005 | Evolution proposals MUST be validated before execution | CRITICAL | Guardian workflow |
| SC-OBS-006 | Observer isolation MUST survive system evolution | CRITICAL | Domain separation |
| SC-OBS-010 | OBSERVED components emit only, never receive from OBSERVER | HIGH | Architecture |
| SC-OBS-011 | Telemetry events immutable after emission | HIGH | Design |
| SC-OBS-012 | OBSERVER domain has ZERO write access | CRITICAL | Code review |
| SC-OBS-013 | ALL mutations MUST pass through Guardian Gate | CRITICAL | Single entry point |
| SC-OBS-014 | Shadow environment MUST be isolated from production | CRITICAL | Container isolation |
| SC-OBS-015 | Shadow tests MUST complete within 5 minutes | HIGH | Timeout enforcement |
| SC-OBS-016 | Consistency check MUST run every 5 minutes | HIGH | Scheduled task |
| SC-OBS-017 | Divergence > 1% triggers alert | HIGH | Threshold check |
| SC-OBS-018 | Monitoring frequency increases 10x during evolution | HIGH | Dynamic interval |
| SC-OBS-019 | Anomaly count > 3 triggers rollback recommendation | HIGH | Alert aggregation |

## 6.2 Telemetry Constraints (SC-TEL-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-TEL-001 | All events MUST conform to defined schemas | HIGH | Schema validation |
| SC-TEL-002 | Schema violations logged but not blocking | MEDIUM | Graceful degradation |
| SC-TEL-003 | Subscriptions MUST use appropriate key expressions | HIGH | Key validation |
| SC-TEL-004 | Latency budget: <50ms per message | HIGH | Timeout enforcement |

## 6.3 Digital Twin Constraints (SC-TWIN-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-TWIN-001 | Sync interval = 30 seconds | MEDIUM | Timer configuration |
| SC-TWIN-002 | State hash MUST be verified on sync | HIGH | Hash computation |
| SC-TWIN-003 | Stale data > 60s triggers alert | HIGH | Watchdog |

## 6.4 Evolution Constraints (SC-EVO-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-EVO-001 | Snapshot MUST be created before evolution | CRITICAL | Workflow gate |
| SC-EVO-002 | Snapshot MUST be verified before clearance | CRITICAL | Verification step |
| SC-EVO-003 | All validation checks MUST pass for evolution success | CRITICAL | Gate enforcement |
| SC-EVO-004 | Validation timeout = 5 minutes | HIGH | Timeout |
| SC-EVO-005 | Rollback MUST complete within 5 minutes | CRITICAL | Timeout |

---

# 7. AOR RULES REFERENCE

## 7.1 Observer AOR Rules (AOR-OBS-*)

| ID | Rule | Domain |
|----|------|--------|
| AOR-OBS-001 | F# Cortex SHALL receive telemetry via Zenoh subscription only | OBSERVER |
| AOR-OBS-002 | F# Cortex SHALL NOT have direct access to Elixir GenServers | OBSERVER |
| AOR-OBS-003 | Evolution proposals SHALL be sent to Guardian for validation | OBSERVER |
| AOR-OBS-004 | DigitalTwin SHALL sync via event stream, not direct queries | OBSERVER |
| AOR-OBS-005 | Dashboard TUI SHALL display cached state, not live queries | OBSERVER |
| AOR-OBS-006 | Rollback proposals SHALL go through Guardian Gate | OBSERVER |
| AOR-OBS-007 | OBSERVER SHALL maintain heightened monitoring during evolution | OBSERVER |

## 7.2 Telemetry AOR Rules (AOR-TEL-*)

| ID | Rule | Domain |
|----|------|--------|
| AOR-TEL-001 | ALL state mutations SHALL emit telemetry events | OBSERVED |
| AOR-TEL-002 | Telemetry handlers SHALL NOT block emitting process | OBSERVED |
| AOR-TEL-003 | Zenoh publications SHALL include timestamp | TELEMETRY |
| AOR-TEL-004 | PubSub broadcasts SHALL use defined topic patterns | TELEMETRY |

## 7.3 Evolution AOR Rules (AOR-EVO-*)

| ID | Rule | Domain |
|----|------|--------|
| AOR-EVO-001 | Snapshot SHALL be created before any evolution | OBSERVED |
| AOR-EVO-002 | Shadow testing SHALL be completed before activation | BRIDGE |
| AOR-EVO-003 | Guardian SHALL validate all proposals >= 0.85 score | BRIDGE |
| AOR-EVO-004 | Rollback path SHALL be tested before clearance | BRIDGE |
| AOR-EVO-005 | Post-evolution validation SHALL complete all checks | OBSERVED |

---

# 8. IMPLEMENTATION EXAMPLES

## 8.1 Complete Telemetry Emission Example (Elixir)

```elixir
defmodule Indrajaal.Telemetry.Emitter do
  @moduledoc """
  Standard telemetry emission patterns.
  Demonstrates proper OBSERVED domain telemetry emission.
  """

  @doc """
  Emit OODA cycle telemetry.
  Called at the end of each OODA cycle in FastOODA or StrategyOODA.
  """
  def emit_ooda_cycle(layer, phases, total_time_us) do
    :telemetry.execute(
      [:ooda, layer, :cycle],
      %{
        cycle_time_us: total_time_us,
        observe_us: phases.observe,
        orient_us: phases.orient,
        decide_us: phases.decide,
        act_us: phases.act
      },
      %{
        layer: layer,
        timestamp: DateTime.utc_now()
      }
    )

    # Also publish to Zenoh for distributed observation
    topic = "indrajaal/primary/telemetry/ooda/#{layer}"
    payload = Jason.encode!(%{
      layer: layer,
      cycle_time_us: total_time_us,
      phases: phases,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    })

    Indrajaal.Mesh.Zenoh.publish(topic, payload)
  end

  @doc """
  Emit state change telemetry.
  Called whenever GenServer or Ash resource state changes.
  """
  def emit_state_change(module, change_type, entity_id, old_hash, new_hash) do
    :telemetry.execute(
      [:state, :change],
      %{
        old_state_hash: old_hash,
        new_state_hash: new_hash
      },
      %{
        module: module,
        change_type: change_type,
        entity_id: entity_id,
        timestamp: DateTime.utc_now()
      }
    )

    # Zenoh publication
    topic = "indrajaal/primary/telemetry/state/#{module}"
    Indrajaal.Mesh.Zenoh.publish(topic, Jason.encode!(%{
      module: module,
      change_type: change_type,
      entity_id: entity_id,
      new_hash: new_hash,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }))
  end
end
```

## 8.2 Complete F# Observer Example

```fsharp
// lib/cepaf/src/Observability/ObserverExample.fs
namespace Indrajaal.Observability

open System

/// Complete F# Observer implementation example
/// Demonstrates proper OBSERVER domain patterns
module ObserverExample =

    /// Main observer loop - READ-ONLY
    let runObserverLoop (zenohClient: ZenohClient) =
        // Subscribe to telemetry (SC-OBS-001 compliant)
        TelemetryReceiver.subscribe zenohClient

        // Main loop
        let rec loop () = async {
            // Drain events from buffer
            let events = TelemetryReceiver.drainEvents()

            // Update DigitalTwin from events (not direct query)
            DigitalTwin.updateFromEvents events

            // Check for issues requiring proposals
            match DigitalTwin.getState() with
            | Some twin ->
                // Analyze for rollback (OBSERVER action)
                match RollbackProposer.analyzeForRollback twin events with
                | Some proposal ->
                    // Submit to Guardian via Zenoh (SC-OBS-013)
                    RollbackProposer.submitRollbackProposal zenohClient proposal
                | None -> ()

                // Check consistency (OBSERVER action)
                let productionHash =
                    events
                    |> List.tryFind (function StateHash _ -> true | _ -> false)

                match ConsistencyVerifier.verify (Some twin) productionHash with
                | ConsistencyVerifier.Divergent _ as result ->
                    DivergenceHandler.handleDivergence result zenohClient
                | _ -> ()

            | None ->
                Logger.warn "DigitalTwin not initialized"

            // Wait for next cycle (30s normal, 3s during evolution)
            let interval =
                if isEvolutionInProgress() then 3000 else 30000

            do! Async.Sleep interval
            return! loop()
        }

        loop() |> Async.StartImmediate
```

---

# 9. VERIFICATION PROCEDURES

## 9.1 Observer Separation Verification

To verify observer/observed separation is properly maintained:

```bash
# 1. Static analysis - Check for direct imports
rg "GenServer\." lib/cepaf/src/ --type fsharp
# Expected: 0 matches (F# should not import Elixir GenServers)

# 2. Check for direct Ecto/SQLite access from F#
rg "Ecto\." lib/cepaf/src/ --type fsharp
rg "Exqlite\." lib/cepaf/src/ --type fsharp
# Expected: 0 matches

# 3. Verify all mutations go through Guardian
rg "def handle_cast.*proposal" lib/indrajaal/agents/guardian.ex
# Expected: All proposals handled here

# 4. Check telemetry emissions exist
rg ":telemetry.execute" lib/indrajaal/ --type elixir | wc -l
# Expected: > 50 emission points
```

## 9.2 Telemetry Flow Verification

```elixir
# In IEx, verify telemetry flow
:telemetry.attach_many(
  "test-observer",
  [
    [:ooda, :fast, :cycle],
    [:state, :change],
    [:evolution, :proposal],
    [:guardian, :decision]
  ],
  fn event, measurements, metadata, _ ->
    IO.puts("Event: #{inspect(event)}")
    IO.puts("Measurements: #{inspect(measurements)}")
    IO.puts("Metadata: #{inspect(metadata)}")
  end,
  nil
)
```

## 9.3 DigitalTwin Sync Verification

```fsharp
// Verify DigitalTwin sync status
let verifySyncStatus () =
    match DigitalTwin.getState() with
    | Some state ->
        printfn $"Last sync: {state.LastSync}"
        printfn $"State hash: {state.StateHash}"
        printfn $"Is stale: {DigitalTwin.isSyncStale()}"
        printfn $"Container count: {state.Containers |> Map.count}"
        printfn $"Agent count: {state.Agents |> Map.count}"
    | None ->
        printfn "DigitalTwin not initialized!"
```

---

## Document Summary

| Section | Coverage |
|---------|----------|
| Fundamental Separation | 4 domains defined |
| Observer Safety | 5 mechanisms |
| Telemetry Architecture | 4 event types, 2 transports |
| Digital Twin | Read-only mirror pattern |
| Evolution Protocol | 4 phases with validation |
| STAMP Constraints | 20+ SC-OBS/TEL/TWIN/EVO |
| AOR Rules | 14 AOR-OBS/TEL/EVO |
| Implementation Examples | Elixir + F# |

---

**Document End**

| Field | Value |
|-------|-------|
| Total Lines | 750+ |
| STAMP Coverage | 20+ constraints |
| AOR Coverage | 14 rules |
| Last Updated | 2026-01-10 |
| Next Review | 2026-04-10 |
