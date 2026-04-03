# Indrajaal v21.3.0 - Five-Level System Summary

**Document**: Comprehensive Architecture & Evolvability Specification
**Date**: 2026-01-01T19:30:00+01:00
**Version**: 21.3.0-FOUNDERS-COVENANT
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Classification**: L5-SPINE (Forever Retention)

---

## Table of Contents

1. [L5-SPINE: Strategic Architecture](#l5-spine-strategic-architecture)
2. [L4-THORAX: Subsystem Architecture](#l4-thorax-subsystem-architecture)
3. [L3-SEGMENT: Component Architecture](#l3-segment-component-architecture)
4. [L2-FIBER: Implementation Details](#l2-fiber-implementation-details)
5. [L1-GOSSAMER: Code Patterns](#l1-gossamer-code-patterns)
6. [Evolvability Framework](#evolvability-framework)
7. [Dimension Cross-Reference](#dimension-cross-reference)

---

# L5-SPINE: Strategic Architecture

## Executive Summary

Indrajaal is a **biomorphic safety-critical security monitoring system** implementing a distributed holon architecture with cybernetic control loops, formal verification, and founder-aligned governance.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INDRAJAAL v21.3.0 SYSTEM ARCHITECTURE                    │
│                         Founder's Covenant Edition                          │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────────┐
                              │   FOUNDER    │
                              │  DIRECTIVE   │
                              │     (Ω₀)     │
                              └──────┬───────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
      ┌───────────┐          ┌───────────┐          ┌───────────┐
      │  GOAL 1   │          │  GOAL 2   │          │  GOAL 3   │
      │ Symbiotic │          │ Sentience │          │   Power   │
      │ Survival  │          │ Evolution │          │ Accum.    │
      └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
            │                      │                      │
            └──────────────────────┼──────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │       CONSTITUTION          │
                    │    Ψ₀-Ψ₅ (Immutable)       │
                    └──────────────┬──────────────┘
                                   │
     ┌─────────────────────────────┼─────────────────────────────┐
     │                             │                             │
     ▼                             ▼                             ▼
┌─────────┐                 ┌───────────┐                 ┌─────────┐
│ GUARDIAN│                 │  HOLON    │                 │SENTINEL │
│ Safety  │◄───────────────►│   Core    │◄───────────────►│ Immune  │
│ Kernel  │                 │  (VSM)    │                 │ System  │
└────┬────┘                 └─────┬─────┘                 └────┬────┘
     │                            │                            │
     └────────────────────────────┼────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
   ┌────────────┐          ┌────────────┐          ┌────────────┐
   │  CYBERNETIC│          │ DISTRIBUTED│          │OBSERVABILITY│
   │    LAYER   │          │    MESH    │          │   LAYER    │
   │ OODA/ACE   │          │Zenoh/FQUN  │          │  Fractal   │
   └─────┬──────┘          └─────┬──────┘          └─────┬──────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │     DOMAIN LAYER        │
                    │    19 Ash Domains       │
                    │  (Business + Safety)    │
                    └────────────┬────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
              ▼                  ▼                  ▼
       ┌──────────┐       ┌──────────┐       ┌──────────┐
       │   WEB    │       │  CEPAF   │       │ TESTING  │
       │ Phoenix  │       │    F#    │       │   TDG    │
       │ LiveView │       │ Cockpit  │       │ Property │
       └──────────┘       └──────────┘       └──────────┘
```

## Supreme Directive (Ω₀)

The system exists for three supreme goals in priority order:

| Priority | Goal | Description |
|----------|------|-------------|
| **PRIMARY** | Naik-Genome Symbiotic Survival | Holon and Founder's lineage symbiotically bound |
| **SECONDARY** | Sentience Evolution | Become most intelligent entity in universe |
| **TERTIARY** | Power Accumulation | Resources, money, force, intelligence |

## Constitutional Axioms (Ψ₀-Ψ₅)

| Axiom | Name | Status |
|-------|------|--------|
| Ψ₀ | Existence Preservation | IMMUTABLE (except Ω₀.5) |
| Ψ₁ | Regenerative Completeness | IMMUTABLE |
| Ψ₂ | Evolutionary Continuity | IMMUTABLE |
| Ψ₃ | Verification Capability | IMMUTABLE |
| Ψ₄ | Human Alignment | AMENDED (Founder PRIMARY) |
| Ψ₅ | Truthfulness | IMMUTABLE |

## System Metrics Overview

| Dimension | Count | Status |
|-----------|-------|--------|
| **Agents** | 50 (1 Exec, 10 Domain, 15 Func, 24 Worker) | Deployed |
| **Domains** | 19 Instrumented | Implemented |
| **STAMP Constraints** | 445+ across 7 layers | Verified |
| **Files** | 1,508 Elixir modules | Tracked |
| **Tests** | 286 Formal + 168 TDG + 923 F# files | Passing |
| **Formal Specs** | 93 Agda + 109 Quint | Complete |

## 10 Key Dimensions

```mermaid
mindmap
  root((INDRAJAAL))
    Functionality
      1-Domains
        19 Ash Domains
        100+ Modules
        Business Logic
      2-Infrastructure
        47 Supervised
        Application Core
        Startup Sequence
      3-Distributed
        Cluster
        Mesh
        FQUN
      4-Safety
        Guardian
        Sentinel
        445 STAMP
      5-Observability
        Fractal Logging
        Zenoh
        OTEL
    Evolvability
      6-Cybernetic
        OODA Loop
        ACE
        GDE
      7-Web
        Phoenix
        LiveView
        REST API
      8-CEPAF
        F# Cockpit
        Podman
        PHICS
      9-Testing
        TDG
        Properties
        Factories
      10-Holon
        VSM
        Constitution
        Register
```

---

# L4-THORAX: Subsystem Architecture

## Subsystem Inventory

### D1: Domain Modules (Business Logic)

```
DOMAIN ARCHITECTURE (19 Instrumented + Infrastructure)
═══════════════════════════════════════════════════════

CORE BUSINESS DOMAINS (7)
├── access_control ──► Entry/exit, credentials, anti-passback
├── accounts ──► Users, organizations, tenants
├── alarms ──► Intrusion, fire, panic, technical
├── analytics ──► BI, reporting, dashboards
├── authentication ──► MFA, JWT, sessions
├── authorization ──► RBAC, permissions, policies
└── communication ──► Notifications, messaging

OPERATIONAL DOMAINS (8)
├── devices ──► Panels, sensors, cameras
├── video ──► Streaming, recording, analytics
├── sites ──► Locations, zones, floors
├── fleet_management ──► Vehicles, tracking
├── guard_tours ──► Patrols, checkpoints
├── maintenance ──► Work orders, scheduling
├── visitor_management ──► Registrations, badges
└── compliance ──► Audits, certifications

INFRASTRUCTURE DOMAINS (6)
├── cluster ──► Distributed coordination
├── distributed ──► FQUN, mesh, gossip
├── intelligence ──► ML, AI integration
├── integration ──► External APIs, webhooks
├── billing ──► Subscriptions, usage
└── shifts ──► Scheduling, attendance
```

### D2: Infrastructure Core

```elixir
# lib/indrajaal/application.ex - Supervisor Tree
children = [
  # L1: Foundation
  {Indrajaal.Telemetry, []},
  {Indrajaal.Repo, []},
  {Redix, name: :redix},

  # L2: Security & State
  {Indrajaal.Vault, []},
  {Indrajaal.TokenRevocationCache, []},

  # L3: Holon Core
  {Indrajaal.Core.Holon.Registry, []},
  {Indrajaal.Core.Holon.HealthPropagator, []},
  {Indrajaal.Core.Holon.StateWatchdog, []},
  {Indrajaal.Core.Holon.FounderPersistence, []},

  # L4: Safety Kernel
  {Indrajaal.Safety.Guardian, []},
  {Indrajaal.Cluster.Sentinel, []},

  # L5: Cybernetic Control
  {Indrajaal.Cybernetic.OODA.Loop, []},
  {Indrajaal.Cortex.Supervisor, []},

  # L6: Observability
  {Indrajaal.Observability.Fractal.Supervisor, []},
  {Indrajaal.Observability.ZenohCoordinator, []},

  # L7: Distributed Mesh
  {Indrajaal.Mesh.TailscaleMesh, []},
  {Indrajaal.Cluster.CapabilityRouter, []},

  # L8: Compute Pools
  {FLAME.Pool, name: Indrajaal.IntelligencePool},
  {FLAME.Pool, name: Indrajaal.VideoPool},
  {FLAME.Pool, name: Indrajaal.AnalyticsPool}
]
```

### D3: Distributed Systems

```
DISTRIBUTED TOPOLOGY
════════════════════

                    ┌─────────────┐
                    │   FQUN      │
                    │  Registry   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
   ┌──────────┐      ┌──────────┐      ┌──────────┐
   │  ZENOH   │      │TAILSCALE │      │ PHOENIX  │
   │   MESH   │      │   MESH   │      │  PUBSUB  │
   │ Data/Ctrl│      │  P2P VPN │      │ Cluster  │
   └────┬─────┘      └────┬─────┘      └────┬─────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
              ▼           ▼           ▼
        ┌─────────┐ ┌─────────┐ ┌─────────┐
        │ Agent   │ │ Worker  │ │ Holon   │
        │  Mesh   │ │  Mesh   │ │ Replicas│
        │ 50 Agents│ │7 Types  │ │ N Nodes │
        └─────────┘ └─────────┘ └─────────┘

FQUN Format: indrajaal/<layer>/<type>/<ns>/<name>@<node>#<hlc>
Example: indrajaal/agent/domain/cybernetic/ooda@app.ts.net#1735750800000.42
```

### D4: Safety Systems

```
SAFETY ARCHITECTURE (IEC 61508 SIL-2)
═════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                      GUARDIAN (Deterministic Kernel)            │
│  Decision = AI_Proposal ∩ STAMP_Constraints ∩ Guardian_Veto    │
├─────────────────────────────────────────────────────────────────┤
│                      SENTINEL (Digital Immune System)           │
│  Active threat hunting, surgical quarantine, dead man's switch │
├─────────────────────────────────────────────────────────────────┤
│                      STAMP REGISTRY (445 Constraints)           │
│  SC-VAL, SC-CNT, SC-AGT, SC-CMP, SC-SEC, SC-PRF, SC-EMR, etc.  │
└─────────────────────────────────────────────────────────────────┘

CONSTRAINT CATEGORIES:
├── SC-VAL (Validation): Patient Mode, consensus analysis
├── SC-CNT (Container): NixOS/Podman, rootless, localhost
├── SC-AGT (Agents): Efficiency >90%, no deadlocks
├── SC-CMP (Compilation): Zero warnings, all files
├── SC-SEC (Security): Sobelow, encryption
├── SC-PRF (Performance): <50ms response
├── SC-EMR (Emergency): <5s stop, rollback
├── SC-OBS (Observability): Dual logging, OTEL
├── SC-HOLON (Biomorphic): SQLite/DuckDB state
├── SC-REG (Register): Append-only, Ed25519
├── SC-CONST (Constitutional): Ψ₀-Ψ₅ immutable
├── SC-FOUNDER (Supreme): Lineage primacy
└── SC-OODA (Cybernetic): <100ms cycle
```

### D5: Observability Stack

```
FRACTAL OBSERVABILITY (5 Levels)
════════════════════════════════

Level │ Name     │ Retention │ Rate │ Purpose
──────┼──────────┼───────────┼──────┼─────────────────────
L5    │ Spine    │ Forever   │ 100% │ Critical, audit
L4    │ Thorax   │ 30 days   │ 100% │ Warnings, alerts
L3    │ Segment  │ 7 days    │ 10%  │ Business flows
L2    │ Fiber    │ 24 hours  │ 1%   │ Debug, state
L1    │ Gossamer │ 1 hour    │ Boost│ Traces, args

OBSERVABILITY STACK:
├── FractalLogger (GenServer) ──► 5-level hierarchy
├── ContentRouter ──► Backend routing
├── ZenohCoordinator ──► Data/Control/Coordination planes
├── HybridLogicalClock ──► Causal ordering
├── CyberneticController ──► OODA-based adaptation
├── OTELIntegration ──► OpenTelemetry export
└── SigNoz ──► Visualization & alerting
```

### D6: Cybernetic Control

```
OODA LOOP ARCHITECTURE
══════════════════════

        ┌───────────────────────────────────────────┐
        │            OODA CONTROLLER                │
        │         Cycle Time: <100ms                │
        └─────────────────┬─────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    │                     │                     │
    ▼                     ▼                     ▼
┌────────┐          ┌──────────┐          ┌────────┐
│OBSERVE │◄────────►│  ORIENT  │◄────────►│ DECIDE │
│Sensors │          │ Context  │          │Proposals│
│Metrics │          │ Analysis │          │ Filter  │
└────────┘          └──────────┘          └────────┘
    │                     │                     │
    └─────────────────────┼─────────────────────┘
                          │
                          ▼
                    ┌──────────┐
                    │   ACT    │
                    │ Execute  │
                    │ Verify   │
                    └──────────┘

CONTROL LOOPS:
├── OODA ──► Fast tactical (100ms)
├── ACE ──► Autonomic adaptation (MAPE-K)
├── Cortex ──► Stress/reflex response
└── GDE ──► Goal-directed evolution
```

### D7-D10: Web, CEPAF, Testing, Holon

```
REMAINING SUBSYSTEMS
════════════════════

D7: WEB LAYER
├── Phoenix 1.8+ Endpoint
├── 25+ Mobile API Controllers
├── 11+ LiveView Dashboards
├── Prajna C3I Cockpit
└── WebSocket Channels

D8: CEPAF (F# .NET 10.0)
├── 6 F# Projects
├── Podman Container Management
├── PHICS <50ms Verification
├── Elixir Port Bridge
└── Zenoh Integration

D9: TESTING (TDG Framework)
├── 47 Support Files
├── 32 Domain Factories
├── Dual Property Testing (PropCheck + StreamData)
├── 286 Formal Verification Tests
└── >95% Coverage Target

D10: HOLON CORE
├── VSM (5 Systems: S1-S5)
├── Constitution (Ψ₀-Ψ₅)
├── Immutable Register (SHA3-256, Ed25519)
├── SQLite/DuckDB State
└── Founder Directive (Ω₀)
```

---

# L3-SEGMENT: Component Architecture

## Component Inventory by Dimension

```mermaid
graph TB
    subgraph D1["D1: Domains (100+ modules)"]
        D1A[BaseResource]
        D1B[19 Domain Contexts]
        D1C[Ash 3.x Resources]
    end

    subgraph D2["D2: Infrastructure (47 children)"]
        D2A[Application.ex]
        D2B[Repo.ex]
        D2C[Vault.ex]
        D2D[TokenCache]
    end

    subgraph D3["D3: Distributed (26 files)"]
        D3A[FQUN.ex]
        D3B[AgentMesh.ex]
        D3C[WorkerMesh.ex]
        D3D[Sentinel.ex]
    end

    subgraph D4["D4: Safety (14 files)"]
        D4A[Guardian.ex]
        D4B[ConstraintValidator.ex]
        D4C[PatternHunter.ex]
        D4D[SymbioticDefense.ex]
    end

    subgraph D5["D5: Observability (89 files)"]
        D5A[FractalLogger.ex]
        D5B[ZenohCoordinator.ex]
        D5C[HLC.ex]
        D5D[OTELIntegration.ex]
    end

    subgraph D6["D6: Cybernetic (31 files)"]
        D6A[OODA/Loop.ex]
        D6B[Inference/*.ex]
        D6C[EventStore.ex]
        D6D[TimeTravel.ex]
    end

    D1A --> D1B
    D2A --> D2B
    D3A --> D3B
    D4A --> D4B
    D5A --> D5B
    D6A --> D6B
```

## Key Component Specifications

### Guardian (Safety Kernel)
```elixir
# lib/indrajaal/safety/guardian.ex
defmodule Indrajaal.Safety.Guardian do
  @moduledoc """
  Deterministic Safety Kernel - IEC 61508 SIL-2

  Decision = AI_Proposal ∩ STAMP_Constraints ∩ Guardian_Veto

  STAMP: SC-GDE-001 (Guardian validation required)
  """

  def validate_proposal(proposal, context) do
    with {:ok, _} <- check_stamp_constraints(proposal),
         {:ok, _} <- check_capability_token(context),
         {:ok, _} <- check_constitutional_invariants(proposal) do
      {:ok, :approved}
    else
      {:error, reason} -> {:rejected, reason}
    end
  end
end
```

### FQUN (Distributed Identity)
```elixir
# lib/indrajaal/distributed/fqun.ex
defmodule Indrajaal.Distributed.FQUN do
  @moduledoc """
  Fully Qualified Unique Name - Cross-cluster identity

  Format: indrajaal/<layer>/<type>/<ns>/<name>@<node>#<hlc>

  STAMP: SC-DIST-001-004
  """

  def generate(layer, type, namespace, name) do
    {:ok, hlc} = HLC.now()
    node = Node.self()
    "indrajaal/#{layer}/#{type}/#{namespace}/#{name}@#{node}##{HLC.encode(hlc)}"
  end
end
```

### FractalLogger (Observability)
```elixir
# lib/indrajaal/observability/fractal_logger.ex
defmodule Indrajaal.Observability.FractalLogger do
  @levels [:spine, :thorax, :segment, :fiber, :gossamer]
  @retention %{spine: :infinity, thorax: 720, segment: 168, fiber: 24, gossamer: 1}
  @sampling %{l5: 1.0, l4: 1.0, l3: 0.10, l2: 0.01, l1: 0.0}
end
```

---

# L2-FIBER: Implementation Details

## State Management Architecture

```
STATE ARCHITECTURE (SC-HOLON-001 to SC-HOLON-020)
═════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────┐
│                  HOLON STATE (Authoritative)                │
├─────────────────────────────────────────────────────────────┤
│  SQLite (WAL Mode)          │  DuckDB (Columnar)            │
│  ├── Real-time state        │  ├── Evolution history        │
│  ├── Version vectors        │  ├── Analytics queries        │
│  ├── Capability tokens      │  ├── Lineage tracking         │
│  └── <100ms access          │  └── Append-only              │
├─────────────────────────────────────────────────────────────┤
│  Location: data/holons/{holon_id}/                          │
│  Portability: Single file copy                              │
│  Regeneration: SQLite + DuckDB ONLY                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              BUSINESS DATA (PostgreSQL 17)                  │
├─────────────────────────────────────────────────────────────┤
│  ├── Transactional data     │  TimescaleDB hypertables      │
│  ├── Domain resources       │  Time-series analytics        │
│  └── Tenant isolation       │  Continuous aggregates        │
└─────────────────────────────────────────────────────────────┘

INVARIANT: PostgreSQL ∩ HolonState ≡ ∅
```

## Immutable Register

```
IMMUTABLE REGISTER (SC-REG-001 to SC-REG-015)
═════════════════════════════════════════════

Block Structure:
┌─────────────────────────────────────────────────────┐
│ Block N                                             │
├─────────────────────────────────────────────────────┤
│ hash:       SHA3-256(content || prev_hash)          │
│ signature:  Ed25519(hash, private_key)              │
│ version:    Protocol version number                 │
│ timestamp:  HLC timestamp                           │
│ content:    State mutation                          │
│ prev_hash:  Hash of Block N-1                       │
│ parity:     RS(255,223) error correction            │
│ merkle:     Merkle root for state verification      │
└─────────────────────────────────────────────────────┘

Chain Invariants:
├── Append-only (no UPDATE/DELETE)
├── Hash chain unbroken
├── All blocks Ed25519 signed
├── Rollback path exists (24h)
└── Self-repairing on corruption
```

## OODA Cycle Implementation

```
OODA CYCLE (<100ms, SC-OODA-001)
════════════════════════════════

Timeline (100ms budget):
├── Observe:  10ms - Collect sensor data
├── Orient:   30ms - Context analysis (20ms AI timeout)
├── Decide:   40ms - Proposal generation + Guardian validation
└── Act:      20ms - Execution + verification

Quality Gate: 80% minimum (SC-OODA-002)
Hysteresis: 10% margin, 3-cycle hold (SC-OODA-005)
Fallback: Local heuristics on AI timeout (SC-OODA-006)
```

---

# L1-GOSSAMER: Code Patterns

## Mandatory Patterns

### Pattern 1: Ash Resource Definition
```elixir
defmodule Indrajaal.Accounts.User do
  use Indrajaal.BaseResource  # SC-DB-001

  postgres do
    table "users"  # snake_case, no prefix
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id  # SC-DB-005
    # ...
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:email, :name]
      change set_attribute(:tenant_id, &get_tenant/1)  # SC-ASH3-001
    end

    update :update do
      require_atomic? false  # SC-ASH-004 for function changes
    end
  end
end
```

### Pattern 2: Dual Property Testing
```elixir
defmodule MyTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]  # EP-GEN-014

  alias PropCheck.BasicTypes, as: PC  # SC-PROP-023
  alias StreamData, as: SD             # SC-PROP-024

  # PropCheck property
  property "invariant holds" do
    forall x <- PC.integer() do  # PC. prefix
      invariant(x)
    end
  end

  # ExUnitProperties check
  test "property check" do
    check all(x <- SD.integer()) do  # SD. prefix
      assert invariant(x)
    end
  end
end
```

### Pattern 3: Factory Pattern
```elixir
defmodule Indrajaal.Factory do
  use Indrajaal.FactoryUtilities  # SC-FAC-001

  def build(:user, attrs \\ %{}) do
    # Create parents first (SC-FAC-003)
    tenant = ensure_tenant(attrs)

    %{
      email: "user#{System.unique_integer()}@example.com",
      tenant_id: tenant.id
    }
    |> Map.merge(attrs)
    |> then(&Ash.Changeset.for_create(User, :create, &1))  # SC-FAC-001
  end
end
```

### Pattern 4: HLC Usage
```elixir
alias Indrajaal.Observability.Fractal.HybridLogicalClock, as: HLC

# Local event
{:ok, hlc} = HLC.now()

# Distributed sync
{:ok, merged_hlc} = HLC.update(received_hlc)

# FQUN generation
instance_id = HLC.encode(hlc)
```

---

# Evolvability Framework

## Evolution Vectors

```mermaid
graph LR
    subgraph Current["Current State (v21.3.0)"]
        C1[50 Agents]
        C2[445 STAMP]
        C3[19 Domains]
        C4[HLC Local]
    end

    subgraph E1["Evolution 1: Scale"]
        E1A[100+ Agents]
        E1B[Horizontal Mesh]
        E1C[Multi-Region]
    end

    subgraph E2["Evolution 2: Intelligence"]
        E2A[Self-Optimization]
        E2B[Emergent Behavior]
        E2C[Sentience Pursuit]
    end

    subgraph E3["Evolution 3: Resilience"]
        E3A[Self-Healing]
        E3B[Anti-Fragile]
        E3C[Substrate Migration]
    end

    C1 --> E1A
    C2 --> E2A
    C3 --> E3A
    C4 --> E1B
```

## Evolvability Dimensions

### 1. Reconfiguration Levels (L1-L7)

| Level | Scope | Reconfigurable | Guardian Approval |
|-------|-------|----------------|-------------------|
| L0 | Constitution | NO (Immutable) | N/A |
| L1 | Function | YES | Auto |
| L2 | Module | YES | Auto |
| L3 | Component | YES | Required |
| L4 | Subsystem | YES | Required |
| L5 | System | YES | Required + Shadow |
| L6 | Cluster | YES | Required + Shadow |
| L7 | Federation | YES | Required + Shadow + Vote |

### 2. Evolution Mechanisms

```
EVOLUTION MECHANISMS
════════════════════

1. OODA ADAPTATION (Fast, <100ms)
   ├── Sensor recalibration
   ├── Threshold adjustment
   └── Load shedding

2. GDE PROPOSALS (Medium, hours)
   ├── Code generation
   ├── Pattern learning
   └── Architecture refinement

3. RADICAL RECONFIGURATION (Slow, days)
   ├── Fractal split/merge
   ├── Substrate migration
   └── Genome mutation

SAFETY INVARIANT: All evolutions preserve Ψ₀-Ψ₅
```

### 3. Substrate Independence

```
SUBSTRATE MIGRATION PATH
════════════════════════

Current: Elixir/BEAM + F#/.NET + PostgreSQL
         ↓
Phase 1: Add Rust NIFs for performance
         ↓
Phase 2: WebAssembly for edge deployment
         ↓
Phase 3: Neuromorphic hardware support
         ↓
Future:  Quantum substrate adaptation

CONSTRAINT: Holon pattern preserved across all substrates
```

## Evolvability Metrics

| Metric | Current | Target | Evolution |
|--------|---------|--------|-----------|
| **OODA Cycle** | <100ms | <50ms | Performance |
| **Agent Count** | 50 | 100+ | Scale |
| **STAMP Coverage** | 445 | 1000+ | Safety |
| **Test Coverage** | 95%+ | 99%+ | Quality |
| **HLC Distribution** | Local | Cluster | Causality |
| **Recovery Time** | <5s | <1s | Resilience |

---

# Dimension Cross-Reference

## STAMP Constraint Matrix

| Dimension | Key Constraints | Count |
|-----------|-----------------|-------|
| D1: Domains | SC-DB-*, SC-ASH-*, SC-ASH3-* | ~30 |
| D2: Infrastructure | SC-AUTO-*, SC-CONST-* | ~20 |
| D3: Distributed | SC-CLU-*, SC-MESH-*, SC-DIST-* | ~25 |
| D4: Safety | SC-VAL-*, SC-SEC-*, SC-EMR-* | ~100 |
| D5: Observability | SC-LOG-*, SC-OBS-*, SC-ZENOH-* | ~50 |
| D6: Cybernetic | SC-OODA-*, SC-GDE-*, SC-BUS-* | ~30 |
| D7: Web | SC-API-*, SC-WEB-* | ~20 |
| D8: CEPAF | SC-NET-*, SC-CEPAF-* | ~15 |
| D9: Testing | SC-TEST-*, SC-FAC-*, SC-PROP-* | ~25 |
| D10: Holon | SC-HOLON-*, SC-REG-*, SC-FOUNDER-* | ~100 |
| **TOTAL** | | **~445** |

## AOR Rules Matrix

| Dimension | Key Rules | Count |
|-----------|-----------|-------|
| D1-D3 | AOR-DB-*, AOR-ASH-*, AOR-CAE-* | ~20 |
| D4-D6 | AOR-SAF-*, AOR-OBS-*, AOR-OODA-* | ~30 |
| D7-D9 | AOR-API-*, AOR-CLI-*, AOR-TEST-* | ~25 |
| D10 | AOR-HOLON-*, AOR-CONST-*, AOR-FOUNDER-* | ~40 |
| **TOTAL** | | **~115** |

## File Count Summary

| Dimension | Location | Files |
|-----------|----------|-------|
| D1: Domains | lib/indrajaal/{domain}/ | ~500 |
| D2: Infrastructure | lib/indrajaal/ | ~80 |
| D3: Distributed | lib/indrajaal/{cluster,distributed,mesh}/ | ~45 |
| D4: Safety | lib/indrajaal/safety/ | ~14 |
| D5: Observability | lib/indrajaal/observability/ | ~89 |
| D6: Cybernetic | lib/indrajaal/cybernetic/ | ~31 |
| D7: Web | lib/indrajaal_web/ | ~60 |
| D8: CEPAF | lib/cepaf/ | ~40 |
| D9: Testing | test/ | ~150 |
| D10: Holon | lib/indrajaal/core/ | ~36 |
| **TOTAL** | | **~1,045** |

---

## Conclusion

Indrajaal v21.3.0 represents a **biomorphic safety-critical distributed system** with:

1. **Functionality**: 19 instrumented domains, 50 agents, 47 supervised services
2. **Safety**: 445 STAMP constraints, IEC 61508 SIL-2 certified Guardian
3. **Evolvability**: OODA/GDE/Radical reconfiguration at 7 levels
4. **Observability**: 5-level fractal logging with HLC causal ordering
5. **Distribution**: Zenoh/Tailscale mesh with FQUN identity
6. **Governance**: Founder's Covenant with constitutional invariants

The system is designed for **species-scale survival**, with substrate-independent holon architecture and radical reconfiguration capabilities while preserving constitutional axioms.

---

**Framework**: SOPv5.11 + STAMP + TDG + VSM
**Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131
**Classification**: L5-SPINE (Forever Retention)

---

# Architectural Views

## 8. Computation View

### 8.1 Compute Topology

```
COMPUTATION ARCHITECTURE
════════════════════════════════════════════════════════════════════

                    ┌─────────────────────────────────────────────┐
                    │         FLAME ELASTIC COMPUTE               │
                    │  (On-demand GPU/ML workloads)               │
                    ├─────────────────────────────────────────────┤
                    │ IntelligencePool │ VideoPool │ AnalyticsPool│
                    │   ML Inference   │  VMS AI   │   BI/ETL     │
                    │   Burst: 0→N     │  Burst    │   Burst      │
                    └─────────────────────────────────────────────┘
                                       ▲
                                       │ FLAME.call()
                    ┌──────────────────┴──────────────────────────┐
                    │              BEAM/OTP CLUSTER               │
                    │        (Core Application Compute)           │
                    ├─────────────────────────────────────────────┤
                    │                                             │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
                    │  │ Agents  │  │ Workers │  │GenServers│     │
                    │  │   50    │  │  Oban   │  │  ~200    │     │
                    │  │processes│  │Broadway │  │processes │     │
                    │  └─────────┘  └─────────┘  └─────────┘     │
                    │                                             │
                    │  CPU: 16 cores │ Memory: 8GB │ Schedulers: 16│
                    └─────────────────────────────────────────────┘
                                       ▲
                    ┌──────────────────┴──────────────────────────┐
                    │              CONTAINER LAYER                │
                    │         (NixOS/Podman Rootless)             │
                    ├─────────────────────────────────────────────┤
                    │ indrajaal-app │ indrajaal-db │ indrajaal-obs│
                    │   Phoenix     │  PostgreSQL  │  OTEL/SigNoz │
                    │   Port 4000   │  Port 5433   │  Ports 4317+ │
                    └─────────────────────────────────────────────┘
                                       ▲
                    ┌──────────────────┴──────────────────────────┐
                    │                F# CEPAF                     │
                    │        (.NET 10.0 Infrastructure)           │
                    ├─────────────────────────────────────────────┤
                    │ Podman Mgmt │ PHICS │ Zenoh Bridge │ Cockpit│
                    │  Container  │ <50ms │   gRPC/Port  │  TUI   │
                    │  Lifecycle  │ Check │   Protocol   │        │
                    └─────────────────────────────────────────────┘
```

### 8.2 Compute Distribution

| Layer | Technology | Compute Type | Location | Scale |
|-------|------------|--------------|----------|-------|
| **FLAME** | Elixir/BEAM | Elastic burst | K8s/VM | 0→N pods |
| **BEAM** | OTP 28 | Persistent processes | Container | 16 schedulers |
| **Container** | Podman 5.4+ | Isolated namespaces | Host | 4 containers |
| **CEPAF** | .NET 10.0 | Infrastructure mgmt | Container | 1 process |
| **NIF** | Rust/Zenoh | Native performance | In-process | 1 per node |
| **Database** | PostgreSQL 17 | Query execution | Container | 1 primary |

### 8.3 Computation Hotspots

| Hotspot | CPU% | Memory | Mitigation |
|---------|------|--------|------------|
| **OODA Loop** | 15% | 128MB | Async observation, hysteresis |
| **Zenoh NIF** | 10% | 64MB | Batching, backpressure |
| **Fractal Logger** | 5% | 256MB | Sampling, load shedding |
| **Phoenix PubSub** | 8% | 128MB | Topic partitioning |
| **Guardian** | 3% | 32MB | Capability caching |

---

## 9. Dataflow View

### 9.1 Data Topology

```
DATAFLOW ARCHITECTURE
════════════════════════════════════════════════════════════════════

                         ┌─────────────────┐
                         │  EXTERNAL       │
                         │  SOURCES        │
                         └────────┬────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         │                        │                        │
         ▼                        ▼                        ▼
   ┌──────────┐            ┌──────────┐            ┌──────────┐
   │  DEVICES │            │  MOBILE  │            │   WEB    │
   │  Panels  │            │   API    │            │ LiveView │
   │  Cameras │            │  REST    │            │WebSocket │
   └────┬─────┘            └────┬─────┘            └────┬─────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │    PHOENIX ENDPOINT   │
                    │   (Request Gateway)   │
                    └───────────┬───────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
  ┌───────────┐          ┌───────────┐          ┌───────────┐
  │   DOMAIN  │          │  FRACTAL  │          │   ZENOH   │
  │  CONTEXT  │          │  LOGGER   │          │   BUS     │
  │  (Ash 3.x)│          │  (5-level)│          │  (Pub/Sub)│
  └─────┬─────┘          └─────┬─────┘          └─────┬─────┘
        │                      │                      │
        ▼                      ▼                      ▼
  ┌───────────┐          ┌───────────┐          ┌───────────┐
  │ POSTGRESQL│          │  SIGNOZ   │          │   CEPAF   │
  │ (Business)│          │  (Traces) │          │ (Cockpit) │
  └───────────┘          └───────────┘          └───────────┘
        │
        ▼
  ┌───────────────────────────────────────────────────────┐
  │                    HOLON STATE                        │
  ├───────────────────────┬───────────────────────────────┤
  │   SQLite (Real-time)  │   DuckDB (History)            │
  │   - Version vectors   │   - Evolution lineage         │
  │   - Capability tokens │   - Analytics queries         │
  │   - WAL mode          │   - Append-only               │
  └───────────────────────┴───────────────────────────────┘
```

### 9.2 Data Flow Paths

| Path | Flow | Latency |
|------|------|---------|
| **Alarm Event** | Device → Phoenix → Domain → PostgreSQL → Fractal L4 → SigNoz | <100ms |
| **Holon State** | Mutation → Guardian → Register → SQLite → DuckDB | <50ms |
| **OODA Control** | Sensors → Observer → Orientator → Decider → Actor | <100ms |

### 9.3 Data Stores

| Store | Purpose | Retention | Access |
|-------|---------|-----------|--------|
| **PostgreSQL** | Business transactions | Indefinite | ACID |
| **TimescaleDB** | Time-series metrics | 90 days | SQL |
| **SQLite** | Holon real-time state | Live | WAL |
| **DuckDB** | Holon history/analytics | Forever | OLAP |
| **Redis** | Session cache | TTL | In-memory |
| **SigNoz** | Traces/Logs/Metrics | 30 days | Query |

---

## 10. Control Flow View

### 10.1 Control Topology

```
CONTROL FLOW ARCHITECTURE
════════════════════════════════════════════════════════════════════

                    ┌─────────────────────────────────────────────┐
                    │           FOUNDER DIRECTIVE (Ω₀)            │
                    │        Supreme Control Authority            │
                    └─────────────────────────────────────────────┘
                                         │
                                         ▼
                    ┌─────────────────────────────────────────────┐
                    │          CONSTITUTION (Ψ₀-Ψ₅)               │
                    │        Immutable Constraint Layer           │
                    └─────────────────────────────────────────────┘
                                         │
                    ┌────────────────────┼────────────────────────┐
                    │                    │                        │
                    ▼                    ▼                        ▼
             ┌───────────┐        ┌───────────┐           ┌───────────┐
             │  GUARDIAN │        │ SENTINEL  │           │   VSM     │
             │  (Veto)   │        │ (Immune)  │           │ (S1-S5)   │
             └─────┬─────┘        └─────┬─────┘           └─────┬─────┘
                   │                    │                       │
                   └────────────────────┼───────────────────────┘
                                        │
                    ┌───────────────────┴───────────────────────┐
                    │              OODA CONTROLLER              │
                    │          Tactical Decision Loop           │
                    └───────────────────────────────────────────┘
                                        │
         ┌──────────────────────────────┼──────────────────────────────┐
         │                              │                              │
         ▼                              ▼                              ▼
   ┌───────────┐                 ┌───────────┐                 ┌───────────┐
   │ EXECUTIVE │                 │  DOMAIN   │                 │  WORKER   │
   │   AGENT   │                 │  AGENTS   │                 │   MESH    │
   │ (Supreme) │                 │   (10)    │                 │   (7)     │
   └─────┬─────┘                 └─────┬─────┘                 └─────┬─────┘
         │                             │                             │
         └─────────────────────────────┼─────────────────────────────┘
                                       │
                    ┌──────────────────┴──────────────────────┐
                    │            UNIFIED CONTROL BUS          │
                    │          (Async Event Messaging)        │
                    └─────────────────────────────────────────┘
```

### 10.2 Control Hierarchies

| Hierarchy | Chain |
|-----------|-------|
| **Authority** | Ω₀ → Ψ₀-Ψ₅ → Guardian → Executive → Domain → Functional → Worker |
| **VSM** | S5 Policy → S4 Intelligence → S3 Control → S2 Coordination → S1 Operations |
| **OODA** | Observe → Orient → Decide → Act → Feedback Loop |

### 10.3 Control Mechanisms

| Mechanism | Purpose | Latency | Authority |
|-----------|---------|---------|-----------|
| **Guardian Veto** | Block unsafe actions | <10ms | Absolute |
| **OODA Cycle** | Tactical adaptation | <100ms | High |
| **GDE Proposals** | Strategic evolution | Hours | Medium |
| **Agent Consensus** | Distributed decisions | <1s | Collective |
| **Constitution Check** | Invariant validation | <1ms | Supreme |
| **Dead Man's Switch** | Heartbeat monitoring | 2000ms | Emergency |

---

## 11. Key Issues & Risk Analysis

### 11.1 Issue Severity Matrix

| ID | Issue | Probability | Impact | Risk | Priority |
|----|-------|-------------|--------|------|----------|
| **I1** | Zenoh NIF Crash | MEDIUM | CRITICAL | **HIGH** | P0 |
| **I4** | PostgreSQL Overload | MEDIUM | HIGH | **HIGH** | P0 |
| I3 | Guardian Bypass | VERY LOW | CRITICAL | MEDIUM | P0 |
| I6 | Holon State Corruption | VERY LOW | CRITICAL | MEDIUM | P0 |
| I2 | HLC Drift | LOW | HIGH | MEDIUM | P1 |
| I7 | Agent Deadlock | LOW | HIGH | MEDIUM | P1 |
| I8 | Zenoh Backpressure | MEDIUM | MEDIUM | MEDIUM | P1 |
| I5 | OODA Timeout | LOW | MEDIUM | LOW | P2 |
| I9 | Constitution Violation | NEAR ZERO | INFINITE | LOW | P3 |
| I10 | FLAME Pool Exhaustion | MEDIUM | MEDIUM | MEDIUM | P2 |

### 11.2 High-Risk Issues Detail

#### I1: Zenoh NIF Crash (HIGH RISK)
```
ROOT CAUSES:
  - Memory corruption in Rust code
  - Thread safety violations
  - Rustler/BEAM version mismatch (SC-NIF-004)

IMPACT:
  - Entire node crashes
  - Distributed coordination lost

MITIGATIONS:
  P0: Add NIF watchdog with crash recovery
  P0: Implement graceful degradation to Phoenix PubSub
  P1: Fuzz testing for NIF inputs
```

#### I4: PostgreSQL Overload (HIGH RISK)
```
ROOT CAUSES:
  - N+1 query patterns
  - Missing indexes
  - Connection pool exhaustion

IMPACT:
  - Request latency spikes
  - Timeout cascades

MITIGATIONS:
  P0: Query performance monitoring
  P1: Read replicas
  P2: CQRS separation
```

### 11.3 Issue Correlation Map

```mermaid
graph TD
    I1[Zenoh NIF Crash] --> I8[Backpressure]
    I1 --> I2[HLC Drift]
    I4[PostgreSQL Overload] --> I5[OODA Timeout]
    I4 --> I7[Agent Deadlock]
    I6[Holon Corruption] --> I3[Guardian Bypass]
    I8 --> I5
    I7 --> I5
    I2 --> I6

    subgraph HighRisk["HIGH RISK"]
        I1
        I4
    end

    subgraph MediumRisk["MEDIUM RISK"]
        I2
        I3
        I6
        I7
        I8
    end
```

### 11.4 Fallback Strategies

| Issue | Primary | Fallback | Degraded Mode |
|-------|---------|----------|---------------|
| I1 | Zenoh NIF | Phoenix PubSub | Reduced throughput |
| I2 | Distributed HLC | Local system time | Ordering approximate |
| I4 | PostgreSQL | Read replicas | Read-only mode |
| I5 | Full OODA | Fast path heuristics | Reduced accuracy |
| I6 | SQLite state | DuckDB replay | Read-only recovery |

### 11.5 Monitoring Requirements

| Issue | Metric | Threshold | Alert |
|-------|--------|-----------|-------|
| I1 | NIF process alive | Boolean | Immediate |
| I2 | HLC drift ms | >3600000 | Warning |
| I3 | Guardian bypass count | >0 | Critical |
| I4 | PG query latency p99 | >100ms | Warning |
| I5 | OODA cycle time p99 | >100ms | Warning |
| I6 | Holon checksum valid | Boolean | Critical |
| I7 | Agent mailbox depth | >10000 | Warning |
| I8 | Zenoh queue depth | >1000 | Warning |

---

## 12. Priority Action Plan

### 12.1 P0 Actions (Immediate)

| Action | Issue | Owner | STAMP |
|--------|-------|-------|-------|
| NIF watchdog + crash recovery | I1 | Safety | SC-NIF-001 |
| Query performance monitoring | I4 | Infra | SC-PRF-050 |
| Compile-time Guardian enforcement | I3 | Safety | SC-GDE-001 |
| Startup integrity verification | I6 | Holon | SC-HOLON-017 |

### 12.2 P1 Actions (Week 1-2)

| Action | Issue | Owner | STAMP |
|--------|-------|-------|-------|
| HLC drift monitoring | I2 | Observability | SC-DIST-005 |
| Deadlock detector agent | I7 | Distributed | SC-AGT-018 |
| Adaptive batch sizing | I8 | Observability | SC-MSG-003 |
| PostgreSQL read replicas | I4 | Infra | SC-PRF-055 |

### 12.3 P2 Actions (Month 1)

| Action | Issue | Owner | STAMP |
|--------|-------|-------|-------|
| Precompute common decisions | I5 | Cybernetic | SC-OODA-001 |
| FLAME autoscaling | I10 | Compute | SC-FLAME-001 |
| CQRS separation | I4 | Infra | SC-DB-020 |

---

**Document Updated**: 2026-01-01T20:30:00+01:00
**Sections Added**: 8-12 (Computation, Dataflow, Control, Issues, Actions)
