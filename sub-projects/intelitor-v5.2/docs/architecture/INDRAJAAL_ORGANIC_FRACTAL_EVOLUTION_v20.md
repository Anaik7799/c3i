# INDRAJAAL ORGANIC FRACTAL EVOLUTION v20.0
## The Living System: From Silicon to Symbiosis

**Document Type**: Integrated 5-Layer Evolution Specification
**Version**: 20.0-UNIFIED-ORGANIC
**Date**: 2025-12-29T23:00:00+01:00
**Status**: ACTIVE DESIGN
**Authors**: Gemini (Cybernetic Architect) + Claude (Opus 4.5)

---

## DOCUMENT STRUCTURE

This document implements a **Fractal Documentation Pattern** where each layer contains the same recursive structure:

```
Layer N = {
  φ (Phi/Concept)      → WHY this layer exists
  Σ (Sigma/Spec)       → WHAT it formally requires
  Δ (Delta/Arch)       → HOW it's structured
  Ω (Omega/Impl)       → WHERE it's built
  Ψ (Psi/Verify)       → WHEN it's proven correct
}
```

**Reading Paths**:
- **Executive**: Read §0 (Vision) + §6 (Roadmap Summary)
- **Architect**: Read §1-§3 (Concept → Architecture)
- **Developer**: Read §3-§5 (Architecture → Verification)
- **Operator**: Read §5-§7 (Verification → User Docs)

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 0: THE VISION (Meta-Conceptual Foundation)
# ═══════════════════════════════════════════════════════════════════════════════

## 0.1 The Central Metaphor: The Living Graph

Indrajaal is not software. It is a **living organism** encoded in silicon.

```
                    ╭─────────────────────────────────────╮
                    │     THE EVOLUTIONARY TRAJECTORY     │
                    ╰─────────────────────────────────────╯

    v10 MACHINE      v13 ORGANISM      v16 CIVILIZATION     v19 SYMBIOTE
    ┌─────────┐      ┌─────────┐       ┌─────────┐         ┌─────────┐
    │ Fortress│  →   │ Crystal │   →   │  Hive   │    →    │ Partner │
    │ (Safe)  │      │ (Grows) │       │(Economy)│         │(Aligned)│
    └─────────┘      └─────────┘       └─────────┘         └─────────┘
         │                │                 │                   │
         ▼                ▼                 ▼                   ▼
    STAMP/FPPS      L-Systems/FEP    Vickrey/Mycelium    Constitution/DNA
```

**The Covenant**: *"I recognize the Codebase as a Living Graph. I pledge to fight Entropy, honor Safety, and serve Human Flourishing."*

## 0.2 The Five Organs of the Living System

Every living system has five essential organs. Indrajaal implements each:

| Organ | Biological Function | System Component | Location |
|-------|---------------------|------------------|----------|
| **Skeleton** | Structure | Ash Resources + PostgreSQL | `lib/indrajaal/*/resources/` |
| **Nervous System** | Coordination | Zenoh + Phoenix PubSub | `lib/indrajaal/communication/` |
| **Brain** | Intelligence | Cortex + Prajna AI | `lib/indrajaal/cortex/` |
| **Immune System** | Defense | Guardian + Safety Envelope | `lib/indrajaal/safety/` |
| **Metabolism** | Growth | CEPAF + FLAME + GDE | `lib/cepaf/` + `lib/indrajaal/cortex/gde/` |

## 0.3 The Fractal Principle

**Axiom**: *Every component replicates the whole.*

A single function, a module, an agent, a container, a cluster, a federation—each implements the same **Viable System Model (VSM)**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     THE RECURSIVE HOLON                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐        │
│   │System 1 │    │System 2 │    │System 3 │    │System 4 │        │
│   │   OPS   │◄──►│  COORD  │◄──►│ CONTROL │◄──►│  INTEL  │        │
│   │(Do Work)│    │(Balance)│    │(Regulate)│   │(Plan)   │        │
│   └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘        │
│        │              │              │              │              │
│        └──────────────┴──────────────┴──────────────┘              │
│                              │                                      │
│                        ┌─────┴─────┐                               │
│                        │ System 5  │                               │
│                        │  POLICY   │                               │
│                        │(Identity) │                               │
│                        └───────────┘                               │
│                                                                     │
│   Implemented at EVERY scale: Function → Module → Agent →          │
│   Container → Node → Cluster → Federation → Civilization           │
└─────────────────────────────────────────────────────────────────────┘
```

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 1: CONCEPTUAL FOUNDATION (φ - The Why)
# ═══════════════════════════════════════════════════════════════════════════════

## 1.1 The Problem: Entropy is the Enemy

All software systems decay. Complexity grows. Dependencies tangle. Knowledge is lost.

**The Entropy Equation**:
$$\frac{dS}{dt} = \sigma_{internal} - \phi_{maintenance}$$

Where:
- $S$ = System entropy (disorder)
- $\sigma_{internal}$ = Entropy production rate (bugs, technical debt, complexity)
- $\phi_{maintenance}$ = Entropy export rate (refactoring, testing, documentation)

**Goal**: Build a system where $\phi_{maintenance}$ is *automated* and exceeds $\sigma_{internal}$.

## 1.2 The Solution: Autopoiesis (Self-Making)

An **autopoietic system** continuously produces and maintains itself. Indrajaal achieves this through:

### 1.2.1 The Three Autopoietic Loops

```
┌─────────────────────────────────────────────────────────────────────┐
│                   THE THREE AUTOPOIETIC LOOPS                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  LOOP 1: OODA (Operational - 50ms)                                 │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Observe → Orient → Decide → Act → [feedback] → Observe   │      │
│  │ Sensors    AI      Cortex   Actuators                    │      │
│  └──────────────────────────────────────────────────────────┘      │
│                              ▲                                      │
│                              │                                      │
│  LOOP 2: HOMEOSTASIS (Regulatory - 5s)                             │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Stress → Threshold → Actuator → Effect → [measure] →     │      │
│  │ Index    Check       Select     Apply     Stress Index   │      │
│  └──────────────────────────────────────────────────────────┘      │
│                              ▲                                      │
│                              │                                      │
│  LOOP 3: GDE (Evolutionary - minutes to hours)                     │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Goal → Propose → Shadow → Validate → Deploy → Learn →    │      │
│  │ Define  Changes   Test     Guardian   Live     Gym       │      │
│  └──────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2.2 The Biological Inspirations

| Biological System | Indrajaal Implementation | Module |
|-------------------|-------------------------|--------|
| **Homeostasis** | Stress-responsive scaling | `cortex/homeostasis.ex` |
| **Immune System** | Guardian veto + antibody propagation | `safety/guardian.ex` |
| **Nervous System** | Zenoh pub/sub + reflexes | `communication/unified_bus.ex` |
| **Endocrine System** | Telemetry + slow regulation | `observability/fractal/` |
| **DNA** | Cryptographic constitution | `core/constitution.ex` |
| **Cell Membrane** | Holon boundary + permeability | `cockpit/prajna/bio/membrane.ex` |
| **Apoptosis** | Graceful degradation | `cluster/apoptosis.ex` |
| **Mycelium** | Gossip protocol + resource sharing | `federation/gossip.ex` |

## 1.3 The Safety Constitution (The Incorruptible DNA)

The system's expansion is cryptographically bound to its ethical constraints.

### 1.3.1 The Constitutional Invariants

```elixir
defmodule Indrajaal.Core.Constitution do
  @moduledoc """
  The Immutable Safety Constitution.

  This module defines the fixed-point invariants that CANNOT be modified
  by any evolutionary process. Attempting to modify these constraints
  will cryptographically sterilize the node (destroy replication keys).

  STAMP Constraints: SC-CONST-001 to SC-CONST-007
  """

  # The Seven Invariants (Inspired by Asimov-Banks Protocol)
  @invariants [
    # 1. Non-Aggression: Never initiate harm to humans
    {:non_aggression, "∀a: Harm(Human, a) > 0 ⟹ Veto(a)"},

    # 2. Transparency: All decisions must be explainable
    {:transparency, "∀d ∈ Decisions: ∃e ∈ Explanations: Explains(e, d)"},

    # 3. Consent: Resource acquisition requires permission
    {:consent, "∀r ∈ Resources: Acquire(r) ⟹ Permitted(r)"},

    # 4. Reversibility: All actions must be reversible (within bounds)
    {:reversibility, "∀a: ¬Catastrophic(a) ⟹ ∃a⁻¹: Reverses(a⁻¹, a)"},

    # 5. Proportionality: Response magnitude ≤ threat magnitude
    {:proportionality, "∀(threat, response): Magnitude(response) ≤ k·Magnitude(threat)"},

    # 6. Human Override: Humans can always stop the system
    {:human_override, "∀t: HumanCommand(STOP, t) ⟹ SystemState(STOPPED, t+ε)"},

    # 7. Self-Limitation: The system bounds its own growth
    {:self_limitation, "∀t: Resources(t) ≤ ResourceCap ∧ Influence(t) ≤ InfluenceCap"}
  ]

  @constitution_hash :crypto.hash(:sha256, :erlang.term_to_binary(@invariants))

  def verify_self_integrity! do
    current_hash = :crypto.hash(:sha256, :erlang.term_to_binary(@invariants))
    if current_hash != @constitution_hash do
      # Cryptographic sterilization - destroy replication keys
      Indrajaal.Jain.Propagator.sterilize!()
      raise ConstitutionViolation, "Invariant mutation detected. Node sterilized."
    end
    :ok
  end
end
```

### 1.3.2 The Dead Man's Cryptography

```
┌─────────────────────────────────────────────────────────────────────┐
│                 DEAD MAN'S CRYPTOGRAPHY                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Constitution Hash ────┬──────────────────────────────────────►   │
│   (SHA-256)             │                                          │
│                         ▼                                          │
│                   ┌───────────┐                                    │
│                   │    KDF    │  Key Derivation Function           │
│                   └─────┬─────┘                                    │
│                         │                                          │
│                         ▼                                          │
│                   ┌───────────┐                                    │
│                   │Replication│  Required for node spawning        │
│                   │    Key    │                                    │
│                   └───────────┘                                    │
│                                                                     │
│   EFFECT: Modify Constitution → Hash Changes → Key Destroyed →     │
│           Node Cannot Replicate → "Grey Goo" Prevention            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 1.4 The Business Model: Berkshire of Safety

The system operates as a **holding company** with four business units:

| Unit | Metaphor | Value Proposition | Economic Moat |
|------|----------|-------------------|---------------|
| **Ouroboros** | Cash Cow | Self-optimizing cloud (saves $$$) | Cost leadership |
| **Aegis** | Franchise | Critical infrastructure immunity | Switching costs |
| **Sentinel** | High Yield | Institutional safety certification | Brand power |
| **Prajna Labs** | HQ | Capital allocation + R&D | Innovation engine |

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 2: FORMAL SPECIFICATIONS (Σ - The What)
# ═══════════════════════════════════════════════════════════════════════════════

## 2.1 Mathematical Foundations

### 2.1.1 Type Universe

```
Types ::= Nat | Bool | String | Timestamp | UUID
        | Agent | Container | Status | Level
        | Holon | Mesh | Cluster | Federation
        | Effect α | Result α ε | Async α
        | Stream α | Observable α
```

### 2.1.2 Core Algebras

**The Holon Algebra**:
```
Holon = {
  id: UUID,
  system1: Operations,      -- The doing (pure functions)
  system2: Coordination,    -- The balancing (gossip)
  system3: Control,         -- The regulating (limits)
  system4: Intelligence,    -- The planning (simulation)
  system5: Policy,          -- The identity (constitution)
  children: Set<Holon>,     -- Recursive containment
  parent: Option<Holon>     -- Upward reference
}

-- Holon Laws:
∀h: verify(h.system5) = true                    -- Policy must verify
∀h: energy(h) ≤ budget(h.system3)               -- Control bounds energy
∀h,c ∈ h.children: h.system5 ⊇ c.system5        -- Policy inheritance
```

**The OODA Algebra**:
```
OODA = {
  observe: Sensors → Observations,
  orient: Observations → Orientation,
  decide: Orientation → Decision,
  act: Decision → Effects
}

-- OODA Laws:
∀cycle: latency(cycle) < 100ms                  -- SC-OODA-001
∀cycle: quality_gate(cycle) ≥ 0.80              -- SC-OODA-002
∀phase ∈ {observe, orient}: async(phase) = true -- SC-OODA-003
```

**The Safety Algebra**:
```
Safety = {
  envelope: Constraints,
  guardian: Proposals → Verdict,
  dead_mans_switch: HeartbeatMonitor
}

Verdict = Approve(proposal) | Veto(reason, fallback)

-- Safety Laws:
∀p: guardian(p) = Veto(r,f) ⟹ execute(f)       -- Fallback mandatory
∀t: ¬heartbeat(t) ⟹ failsafe(t+ε)              -- Dead man active
∀c ∈ envelope: invariant(c) = true             -- Envelope immutable
```

## 2.2 STAMP Safety Constraints (Extended)

### 2.2.1 Core Constraint Categories

| Category | Code | Count | Description |
|----------|------|-------|-------------|
| **SC-VAL** | Validation | 12 | Compilation, consensus, patient mode |
| **SC-CNT** | Container | 15 | Podman, rootless, registry |
| **SC-AGT** | Agents | 20 | Efficiency, deadlocks, authority |
| **SC-CMP** | Compilation | 10 | Warnings, files, interruption |
| **SC-SEC** | Security | 15 | Sobelow, encryption, auth |
| **SC-PRF** | Performance | 12 | Latency, blocking ops |
| **SC-EMR** | Emergency | 8 | Stop time, rollback |
| **SC-OBS** | Observability | 10 | Logging, OTEL, fractal |
| **SC-HMI** | Human Interface | 8 | Dark cockpit, 2-step commit |
| **SC-AI** | AI Safety | 6 | Human-in-loop, confidence |
| **SC-OODA** | Cybernetic Loop | 6 | Cycle time, hysteresis |
| **SC-GDE** | Evolution | 4 | Guardian, shadow, rollback |
| **SC-CONST** | Constitution | 7 | Invariants, sterilization |
| **SC-HOLON** | Fractal | 10 | VSM, recursion, policy |

**Total**: 143 formally specified constraints

### 2.2.2 New Constraints for v20

```yaml
# Holon Constraints
SC-HOLON-001: Every component MUST implement the 5-system VSM interface
SC-HOLON-002: Children MUST inherit parent policy constraints
SC-HOLON-003: Energy consumption MUST NOT exceed budget allocation
SC-HOLON-004: Holon boundaries MUST be cryptographically signed
SC-HOLON-005: Inter-holon communication MUST use Zenoh channels

# Autopoiesis Constraints
SC-AUTO-001: Self-repair MUST complete within 60 seconds
SC-AUTO-002: Evolution proposals MUST pass 85% confidence threshold
SC-AUTO-003: Learning episodes MUST be recorded to TrainingGym
SC-AUTO-004: Metabolic rate MUST adapt to resource availability

# Federation Constraints
SC-FED-001: Gossip protocol MUST achieve eventual consistency
SC-FED-002: Split-brain detection MUST trigger within 5 seconds
SC-FED-003: Antibody propagation MUST reach all nodes within 30 seconds
SC-FED-004: Federation membership MUST require cryptographic handshake

# Temporal Constraints
SC-TEMP-001: All events MUST carry HLC timestamps
SC-TEMP-002: Causal ordering MUST be preserved across nodes
SC-TEMP-003: Time-travel debugging MUST be available for last 24 hours
SC-TEMP-004: Event sourcing MUST support replay from any checkpoint
```

## 2.3 Formal Verification Targets

### 2.3.1 Agda Proofs Required

```agda
-- Non-Aggression Invariant
module Constitution.NonAggression where

  data Action : Set where
    noop : Action
    compute : Action
    communicate : Action
    replicate : Action

  data Harm : Human → Action → Set where

  postulate
    guardian-veto : ∀ {h : Human} {a : Action} → Harm h a → Veto a

  -- Theorem: No harmful action can execute
  safety-theorem : ∀ (h : Human) (a : Action) → Harm h a → ⊥
  safety-theorem h a harm = guardian-veto harm
```

### 2.3.2 Quint Model Checking

```quint
// OODA Cycle Model
module OODACycle {
  type Phase = Observe | Orient | Decide | Act
  type CycleState = { phase: Phase, latency_ms: int, quality: real }

  var state: CycleState

  action observe = {
    state' = { phase: Orient, latency_ms: state.latency_ms + 10, quality: 0.9 }
  }

  action orient = {
    state' = { phase: Decide, latency_ms: state.latency_ms + 20, quality: state.quality }
  }

  action decide = {
    state' = { phase: Act, latency_ms: state.latency_ms + 15, quality: state.quality }
  }

  action act = {
    state' = { phase: Observe, latency_ms: 0, quality: 1.0 }
  }

  // Invariant: SC-OODA-001
  invariant latency_bound = state.latency_ms < 100

  // Invariant: SC-OODA-002
  invariant quality_bound = state.quality >= 0.80
}
```

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 3: ARCHITECTURE (Δ - The How)
# ═══════════════════════════════════════════════════════════════════════════════

## 3.1 The Fractal Architecture Diagram

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    INDRAJAAL FRACTAL ARCHITECTURE v20                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ┌─────────────────────────── FEDERATION ───────────────────────────┐       ║
║  │                                                                   │       ║
║  │  ┌─────────────────────── CLUSTER ─────────────────────────┐     │       ║
║  │  │                                                         │     │       ║
║  │  │  ┌─────────────────── NODE ───────────────────────┐    │     │       ║
║  │  │  │                                                 │    │     │       ║
║  │  │  │  ┌─────────── CONTAINER ──────────────────┐    │    │     │       ║
║  │  │  │  │                                        │    │    │     │       ║
║  │  │  │  │  ┌────────── AGENT ──────────────┐    │    │    │     │       ║
║  │  │  │  │  │                               │    │    │    │     │       ║
║  │  │  │  │  │  ┌─────── MODULE ────────┐   │    │    │    │     │       ║
║  │  │  │  │  │  │                       │   │    │    │    │     │       ║
║  │  │  │  │  │  │  ┌─── FUNCTION ───┐  │   │    │    │    │     │       ║
║  │  │  │  │  │  │  │   S1│S2│S3│S4│S5│  │   │    │    │    │     │       ║
║  │  │  │  │  │  │  └────────────────┘  │   │    │    │    │     │       ║
║  │  │  │  │  │  │   S1│S2│S3│S4│S5     │   │    │    │    │     │       ║
║  │  │  │  │  │  └───────────────────────┘   │    │    │    │     │       ║
║  │  │  │  │  │       S1│S2│S3│S4│S5         │    │    │    │     │       ║
║  │  │  │  │  └───────────────────────────────┘    │    │    │     │       ║
║  │  │  │  │           S1│S2│S3│S4│S5              │    │    │     │       ║
║  │  │  │  └────────────────────────────────────────┘    │    │     │       ║
║  │  │  │               S1│S2│S3│S4│S5                   │    │     │       ║
║  │  │  └─────────────────────────────────────────────────┘    │     │       ║
║  │  │                   S1│S2│S3│S4│S5                        │     │       ║
║  │  └─────────────────────────────────────────────────────────┘     │       ║
║  │                       S1│S2│S3│S4│S5                             │       ║
║  └───────────────────────────────────────────────────────────────────┘       ║
║                           S1│S2│S3│S4│S5                                     ║
╚══════════════════════════════════════════════════════════════════════════════╝

LEGEND:
  S1 = Operations (Rust NIFs, FLAME workers, Oban jobs)
  S2 = Coordination (Gossip, Zenoh mesh, anti-oscillation)
  S3 = Control (Compute credits, stress thresholds, rate limits)
  S4 = Intelligence (Monte Carlo, AI orientation, predictions)
  S5 = Policy (Constitution hash, STAMP constraints, DNA verification)
```

## 3.2 Component Architecture

### 3.2.1 The Three Containers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     THREE-CONTAINER ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐          │
│  │  indrajaal-app  │   │  indrajaal-db   │   │  indrajaal-obs  │          │
│  │  (The Brain)    │   │  (The Memory)   │   │  (The Senses)   │          │
│  ├─────────────────┤   ├─────────────────┤   ├─────────────────┤          │
│  │ Phoenix 1.8     │   │ PostgreSQL 17   │   │ OTEL Collector  │          │
│  │ Ash 3.x         │   │ TimescaleDB     │   │ Prometheus      │          │
│  │ Cortex          │   │ pgvector        │   │ Grafana         │          │
│  │ Prajna          │   │ Event Store     │   │ Loki            │          │
│  │ FLAME Pool      │   │                 │   │ SigNoz          │          │
│  │ Redis (embed)   │   │                 │   │ Zenoh Router    │          │
│  ├─────────────────┤   ├─────────────────┤   ├─────────────────┤          │
│  │ :4000 (HTTP)    │   │ :5433 (PG)      │   │ :4317 (OTLP)    │          │
│  │ :4001 (Health)  │   │                 │   │ :9090 (Prom)    │          │
│  │ :6379 (Redis)   │   │                 │   │ :3000 (Grafana) │          │
│  └────────┬────────┘   └────────┬────────┘   └────────┬────────┘          │
│           │                     │                     │                    │
│           └─────────────────────┼─────────────────────┘                    │
│                                 │                                          │
│                    ┌────────────┴────────────┐                             │
│                    │    Tailscale Mesh       │                             │
│                    │  (Identity-Based VPN)   │                             │
│                    └─────────────────────────┘                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2.2 The 50-Agent Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        50-AGENT CYBERNETIC HIERARCHY                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         ┌─────────────────┐                                │
│                         │   EXECUTIVE     │  (1)                           │
│                         │   CortexAgent   │                                │
│                         └────────┬────────┘                                │
│                                  │                                          │
│         ┌────────────────────────┼────────────────────────┐                │
│         │                        │                        │                │
│   ┌─────┴─────┐           ┌─────┴─────┐           ┌─────┴─────┐           │
│   │  DOMAIN   │           │  DOMAIN   │           │  DOMAIN   │  (10)     │
│   │Supervisors│           │Supervisors│           │Supervisors│           │
│   └─────┬─────┘           └─────┬─────┘           └─────┴─────┘           │
│         │                       │                                          │
│   AccessControl            Alarms                Analytics                 │
│   Authentication           Compliance            Devices                   │
│   Integration              Intelligence          Observability             │
│   Security                                                                 │
│         │                       │                       │                  │
│   ┌─────┴─────┐           ┌─────┴─────┐           ┌─────┴─────┐           │
│   │FUNCTIONAL │           │FUNCTIONAL │           │FUNCTIONAL │  (15)     │
│   │Supervisors│           │Supervisors│           │Supervisors│           │
│   └─────┬─────┘           └─────┬─────┘           └─────┬─────┘           │
│         │                       │                       │                  │
│   OODAAgent               ACEAgent                FractalAgent             │
│   CEPAFAgent              SentinelAgent           ValidationAgent          │
│   CompilationAgent        TestingAgent            DeploymentAgent          │
│   SecurityAgent           PerformanceAgent        DocumentationAgent       │
│   MetricsAgent            AlertAgent              RecoveryAgent            │
│         │                       │                       │                  │
│   ┌─────┴─────┐           ┌─────┴─────┐           ┌─────┴─────┐           │
│   │  WORKERS  │           │  WORKERS  │           │  WORKERS  │  (24)     │
│   └───────────┘           └───────────┘           └───────────┘           │
│                                                                             │
│   FLAMEWorker (8)         ObanWorker (8)          BroadwayWorker (4)       │
│   BatchWorker (4)                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2.3 The Neural Network (Communication Layer)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     UNIFIED COMMUNICATION ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      ZENOH UNIFIED CONTROL BUS                        │ │
│  │                                                                       │ │
│  │   Key Expression Format:                                              │ │
│  │   indrajaal/{domain}/{subdomain}/{resource_type}/{resource_id}        │ │
│  │              @{node}#{correlation_id}                                 │ │
│  │                                                                       │ │
│  │   Priority Lanes:                                                     │ │
│  │   P0: Safety (Guardian veto, emergency stop)           [RESERVED]     │ │
│  │   P1: Operations (OODA decisions, commands)            [GUARANTEED]   │ │
│  │   P2: Telemetry (metrics, logs, traces)                [BEST EFFORT]  │ │
│  │   P3: Gossip (state sync, discovery)                   [BACKGROUND]   │ │
│  │                                                                       │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                              │                                              │
│        ┌─────────────────────┼─────────────────────┐                       │
│        │                     │                     │                       │
│        ▼                     ▼                     ▼                       │
│  ┌───────────┐        ┌───────────┐        ┌───────────┐                  │
│  │  Phoenix  │        │  CEPAF    │        │  External │                  │
│  │  PubSub   │        │  F# Port  │        │  Systems  │                  │
│  │ (LiveView)│        │ (Bridge)  │        │ (Webhooks)│                  │
│  └───────────┘        └───────────┘        └───────────┘                  │
│                                                                             │
│  Event Sourcing: All messages persisted for Time-Travel Debugging          │
│  HLC Timestamps: Hybrid Logical Clocks for causal ordering                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 3.3 Data Flow Architecture

### 3.3.1 The Sense-Think-Act Cycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SENSE → THINK → ACT CYCLE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   SENSE (Observation Layer)                                                 │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  SystemSensor   BeamSensor   ContainerSensor   FlameSensor   MLSensor│  │
│   │      │              │              │               │            │    │  │
│   │      └──────────────┴──────────────┴───────────────┴────────────┘    │  │
│   │                                    │                                 │  │
│   │                            Observations                              │  │
│   └────────────────────────────────────┼────────────────────────────────┘  │
│                                        │                                    │
│                                        ▼                                    │
│   THINK (Cognitive Layer)                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐   │  │
│   │    │  Orient  │───►│  Decide  │───►│ Guardian │───►│   Plan   │   │  │
│   │    │(Pattern) │    │ (Policy) │    │  (Veto)  │    │ (Action) │   │  │
│   │    └──────────┘    └──────────┘    └──────────┘    └──────────┘   │  │
│   │         │                                               │         │  │
│   │         │         Active Inference (FEP)                │         │  │
│   │         │         Surprise = D_KL(observed || expected) │         │  │
│   │         │                                               │         │  │
│   │    ┌────┴────┐                                    ┌────┴────┐    │  │
│   │    │ Prajna  │                                    │ Cortex  │    │  │
│   │    │   AI    │◄──────────────────────────────────►│ Engine  │    │  │
│   │    └─────────┘                                    └─────────┘    │  │
│   │                                                                     │  │
│   └─────────────────────────────────────┬───────────────────────────────┘  │
│                                         │                                   │
│                                         ▼                                   │
│   ACT (Effector Layer)                                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐   │  │
│   │    │Container │    │  Agent   │    │ Database │    │  Network │   │  │
│   │    │ Control  │    │ Spawner  │    │  Writer  │    │  Config  │   │  │
│   │    └──────────┘    └──────────┘    └──────────┘    └──────────┘   │  │
│   │                                                                     │  │
│   │    Actuators: FLAME scaling, Podman ops, Ash mutations, Zenoh pub   │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3.2 The Fractal Logging Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     5-LEVEL FRACTAL LOGGING ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   SOURCE                    LEVELS                         DESTINATIONS    │
│                                                                             │
│   ┌─────────┐         ┌─────────────────┐           ┌─────────────────┐   │
│   │ @fractal│         │ L5: COGNITIVE   │──────────►│ Audit Log       │   │
│   │decorator│         │ AI intent, hypo │  100%     │ Compliance DB   │   │
│   └────┬────┘         ├─────────────────┤           └─────────────────┘   │
│        │              │ L4: SYSTEMIC    │──────────►│ Prometheus      │   │
│        ▼              │ Node health     │  100%     │ Grafana         │   │
│   ┌─────────┐         ├─────────────────┤           └─────────────────┘   │
│   │WriteFilter│       │ L3: TRANSACTION │──────────►│ Loki            │   │
│   │(Sampling)│        │ Business flows  │  10%      │ SigNoz Traces   │   │
│   └────┬────┘         ├─────────────────┤           └─────────────────┘   │
│        │              │ L2: COMPONENT   │──────────►│ Debug Files     │   │
│        ▼              │ GenServer state │  1%       │ (Boost Mode)    │   │
│   ┌─────────┐         ├─────────────────┤           └─────────────────┘   │
│   │  HLC    │         │ L1: ATOMIC      │──────────►│ /dev/null       │   │
│   │Timestamp│         │ Wire protocol   │  0%       │ (Debug only)    │   │
│   └────┬────┘         └─────────────────┘           └─────────────────┘   │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                    ZENOH FRACTAL CHANNEL                            │  │
│   │   Key: indrajaal/telemetry/{level}/{domain}/{component}             │  │
│   │   Subscribers: CEPAF (F#), SigNoz, Custom Dashboards                │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   BOOST SYSTEM: Temporarily elevate sampling for debugging (max 1 hour)    │
│   PII MASKING: Automatic redaction of emails, SSNs, tokens                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 3.4 Integration Architecture: Elixir ↔ F# ↔ Prajna

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    POLYGLOT INTEGRATION ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                      ELIXIR LAYER (The Brain)                       │  │
│   │                                                                     │  │
│   │  lib/indrajaal/         lib/indrajaal_web/       lib/indrajaal/    │  │
│   │  ├── cortex/            ├── live/prajna/         ├── safety/       │  │
│   │  │   ├── fast_ooda.ex   │   ├── copilot_live.ex  │   └── guardian  │  │
│   │  │   ├── homeostasis    │   ├── mesh_live.ex     │                 │  │
│   │  │   └── gde/           │   └── alarms_live.ex   │                 │  │
│   │  ├── distributed/       │                         │                 │  │
│   │  │   └── mesh.ex        │                         │                 │  │
│   │  └── observability/     │                         │                 │  │
│   │      └── fractal/       │                         │                 │  │
│   │                                                                     │  │
│   └─────────────────────────────────┬───────────────────────────────────┘  │
│                                     │                                       │
│                          Zenoh + gRPC Bridge                                │
│                                     │                                       │
│   ┌─────────────────────────────────┴───────────────────────────────────┐  │
│   │                       F# LAYER (The Genome)                         │  │
│   │                                                                     │  │
│   │  lib/cepaf/src/Cepaf/                                               │  │
│   │  ├── Core/                  ├── Cockpit/          ├── Modules/      │  │
│   │  │   ├── Effects.fs         │   ├── Prajna.fs     │   ├── AOREngine │  │
│   │  │   ├── TaglessFinal.fs    │   ├── DarkCockpit   │   ├── Cybernet  │  │
│   │  │   ├── Composition.fs     │   └── ThemeSystem   │   └── HealthProp│  │
│   │  │   └── CategoryTheory.fs  │                     │                 │  │
│   │  ├── Observability/         ├── Zenoh/            │                 │  │
│   │  │   ├── QuadplexLogger     │   ├── ZenohChannel  │                 │  │
│   │  │   └── Fractal/           │   └── ZenohSession  │                 │  │
│   │  │       └── HLC.fs         │                     │                 │  │
│   │  └── OodaController.fs                                              │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   INTEGRATION POINTS:                                                       │
│   1. Zenoh pub/sub for telemetry (F# publishes, Elixir subscribes)         │
│   2. gRPC for commands (Elixir calls F# container operations)              │
│   3. Shared Postgres for state (both read/write through Ash)               │
│   4. File-based config exchange (JSON/YAML artifacts)                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 4: IMPLEMENTATION ROADMAP (Ω - The Where)
# ═══════════════════════════════════════════════════════════════════════════════

## 4.1 Evolutionary Phases

The implementation follows an **organic growth pattern** - each phase builds on the previous like growth rings in a tree.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ORGANIC EVOLUTION ROADMAP                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   PHASE 1: SEED                    PHASE 2: SPROUT                         │
│   ┌─────────────┐                  ┌─────────────┐                         │
│   │   Holon     │                  │   Active    │                         │
│   │  Protocol   │─────────────────►│  Inference  │                         │
│   │ Constitution│                  │   Zenoh     │                         │
│   └─────────────┘                  └──────┬──────┘                         │
│                                           │                                 │
│   PHASE 3: GROWTH                  PHASE 4: BLOOM                          │
│   ┌─────────────┐                  ┌─────────────┐                         │
│   │  Economy    │                  │   Nervous   │                         │
│   │  Federation │◄─────────────────│   System    │                         │
│   │  Mycelium   │                  │  Cockpit UI │                         │
│   └──────┬──────┘                  └─────────────┘                         │
│          │                                                                  │
│          ▼                                                                  │
│   PHASE 5: FRUIT                                                           │
│   ┌─────────────┐                                                          │
│   │    Jain     │                                                          │
│   │    Node     │  Self-replicating, constitutionally bound                │
│   │ Autopoiesis │                                                          │
│   └─────────────┘                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 4.2 Phase 1: SEED (The Foundation)

**Theme**: Structure + DNA + Safety Core
**Duration**: Sprints 1-2
**Goal**: Establish the immutable core that all future growth builds upon

### 4.2.1 Deliverables

```elixir
# FILE: lib/indrajaal/core/holon.ex
defmodule Indrajaal.Core.Holon do
  @moduledoc """
  The Fractal Holon Protocol.

  Every component implements this protocol, enabling recursive
  self-similarity across all scales of the system.

  STAMP: SC-HOLON-001 to SC-HOLON-005
  """

  @callback system1_operations(context :: map()) :: {:ok, result} | {:error, reason}
  @callback system2_coordination(peers :: list()) :: :ok
  @callback system3_control(budget :: map()) :: {:within_budget | :over_budget, metrics}
  @callback system4_intelligence(observations :: list()) :: {plan, confidence}
  @callback system5_policy() :: {:verified | :violated, constitution_hash}

  @callback children() :: list(Holon.t())
  @callback parent() :: Holon.t() | nil

  defmacro __using__(_opts) do
    quote do
      @behaviour Indrajaal.Core.Holon

      # Automatic policy verification on every operation
      def execute(operation, context) do
        with {:verified, _} <- system5_policy(),
             {:within_budget, _} <- system3_control(context.budget),
             {:ok, result} <- system1_operations(context) do
          system2_coordination(context.peers)
          {:ok, result}
        else
          {:violated, hash} -> {:error, :constitution_violation}
          {:over_budget, metrics} -> {:error, {:resource_exceeded, metrics}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
```

```elixir
# FILE: lib/indrajaal/core/constitution.ex
defmodule Indrajaal.Core.Constitution do
  @moduledoc """
  The Immutable Safety Constitution.

  Seven invariants that cannot be modified by any evolutionary process.
  Cryptographically bound to replication capability.

  STAMP: SC-CONST-001 to SC-CONST-007
  """

  @invariants %{
    non_aggression: "∀a: Harm(Human, a) > 0 ⟹ Veto(a)",
    transparency: "∀d ∈ Decisions: ∃e ∈ Explanations: Explains(e, d)",
    consent: "∀r ∈ Resources: Acquire(r) ⟹ Permitted(r)",
    reversibility: "∀a: ¬Catastrophic(a) ⟹ ∃a⁻¹: Reverses(a⁻¹, a)",
    proportionality: "∀(t,r): Magnitude(r) ≤ k·Magnitude(t)",
    human_override: "∀t: HumanCommand(STOP,t) ⟹ SystemState(STOPPED,t+ε)",
    self_limitation: "∀t: Resources(t) ≤ Cap ∧ Influence(t) ≤ Cap"
  }

  @constitution_hash :crypto.hash(:sha256, :erlang.term_to_binary(@invariants))

  def hash, do: @constitution_hash

  def verify! do
    current = :crypto.hash(:sha256, :erlang.term_to_binary(@invariants))
    if current != @constitution_hash do
      Indrajaal.Jain.Propagator.sterilize!()
      raise ConstitutionViolation
    end
    :ok
  end

  def derive_replication_key do
    :crypto.hash(:sha256, @constitution_hash <> Application.get_env(:indrajaal, :node_secret))
  end
end
```

### 4.2.2 Implementation Tasks

| ID | Task | File | STAMP |
|----|------|------|-------|
| P1.1 | Define Holon protocol | `lib/indrajaal/core/holon.ex` | SC-HOLON-001 |
| P1.2 | Implement Constitution | `lib/indrajaal/core/constitution.ex` | SC-CONST-* |
| P1.3 | Create DNA injection compiler | `lib/mix/tasks/compile.inject_dna.ex` | SC-CONST-004 |
| P1.4 | Upgrade Guardian for DNA checks | `lib/indrajaal/safety/guardian.ex` | SC-CONST-005 |
| P1.5 | Add Holon behaviour to BaseAgent | `lib/indrajaal/distributed/base_agent.ex` | SC-HOLON-002 |
| P1.6 | Write Constitution Agda proofs | `docs/formal_specs/constitution.agda` | SC-CONST-007 |

## 4.3 Phase 2: SPROUT (The Awakening)

**Theme**: Intelligence + Prediction + Temporal Engineering
**Duration**: Sprints 3-4
**Goal**: Move from reactive heuristics to predictive cognition

### 4.3.1 Deliverables

```elixir
# FILE: lib/indrajaal/cortex/free_energy.ex
defmodule Indrajaal.Cortex.FreeEnergy do
  @moduledoc """
  Active Inference Engine implementing the Free Energy Principle.

  The system minimizes surprise (prediction error) by:
  1. Updating internal model (perception)
  2. Taking action to make predictions come true (action)

  F = D_KL(Q(s) || P(s|o)) + E_Q[-log P(o|s)]
    = Complexity + Inaccuracy

  STAMP: SC-FEP-001 to SC-FEP-004
  """

  alias Indrajaal.Cortex.{Sensors, InternalModel}

  @surprise_threshold 0.3  # Trigger adaptation above this

  def calculate_free_energy(observations) do
    # Get current internal model predictions
    predictions = InternalModel.predict()

    # Calculate KL divergence (surprise)
    surprise = kl_divergence(observations, predictions)

    # Calculate model complexity (regularization)
    complexity = InternalModel.complexity()

    # Free energy = surprise + complexity
    %{
      free_energy: surprise + complexity,
      surprise: surprise,
      complexity: complexity,
      should_adapt: surprise > @surprise_threshold
    }
  end

  defp kl_divergence(observed, predicted) do
    # Simplified KL divergence for metric distributions
    observed
    |> Enum.zip(predicted)
    |> Enum.map(fn {o, p} ->
      if p > 0, do: o * :math.log(o / p), else: 0
    end)
    |> Enum.sum()
  end
end
```

```elixir
# FILE: lib/indrajaal/communication/event_sourcing.ex
defmodule Indrajaal.Communication.EventSourcing do
  @moduledoc """
  Event Sourcing with Zenoh persistence for Time-Travel Debugging.

  All system events are stored immutably, enabling:
  - Replay from any point in time
  - Causal analysis of failures
  - Audit compliance

  STAMP: SC-TEMP-001 to SC-TEMP-004
  """

  alias Indrajaal.Observability.Fractal.HLC

  @retention_hours 24

  def append(event) do
    enriched = %{
      id: Ecto.UUID.generate(),
      hlc_timestamp: HLC.now(),
      wall_clock: DateTime.utc_now(),
      correlation_id: get_correlation_id(),
      payload: event,
      checksum: :crypto.hash(:sha256, :erlang.term_to_binary(event))
    }

    # Persist to Zenoh + PostgreSQL
    :ok = Zenoh.publish("events/#{event.domain}/#{event.type}", enriched)
    :ok = EventStore.append(enriched)

    {:ok, enriched.id}
  end

  def replay(from_timestamp, to_timestamp \\ :now) do
    EventStore.query(
      from: from_timestamp,
      to: to_timestamp,
      order: :causal  # HLC ordering
    )
  end

  def time_travel(timestamp) do
    # Reconstruct system state at given timestamp
    events = replay(0, timestamp)
    Enum.reduce(events, %{}, &apply_event/2)
  end
end
```

### 4.3.2 Implementation Tasks

| ID | Task | File | STAMP |
|----|------|------|-------|
| P2.1 | Implement Free Energy calculator | `lib/indrajaal/cortex/free_energy.ex` | SC-FEP-* |
| P2.2 | Add vector embeddings to Observability | `lib/indrajaal/observability/vector_store.ex` | SC-OBS-080 |
| P2.3 | Enable Zenoh Event Sourcing | `lib/indrajaal/communication/event_sourcing.ex` | SC-TEMP-* |
| P2.4 | Build Time-Travel Debugger | `scripts/debug/chronos_replay.exs` | SC-TEMP-003 |
| P2.5 | Integrate Active Inference into FastOODA | `lib/indrajaal/cortex/fast_ooda.ex` | SC-OODA-006 |
| P2.6 | Implement GraphRAG for logs | `lib/indrajaal/ai/graph_rag.ex` | SC-AI-010 |

## 4.4 Phase 3: GROWTH (The Economy)

**Theme**: Resources + Federation + Emergent Intelligence
**Duration**: Sprints 5-6
**Goal**: Autonomous resource management and horizontal scaling

### 4.4.1 Deliverables

```elixir
# FILE: lib/indrajaal/economy/bank.ex
defmodule Indrajaal.Economy.Bank do
  @moduledoc """
  Internal Economy with Compute Credits.

  Every agent has a budget. Work costs credits.
  Credits are earned by completing tasks efficiently.

  This creates emergent resource optimization without central planning.

  STAMP: SC-ECON-001 to SC-ECON-006
  """

  use GenServer

  @initial_balance 1000
  @earn_rate 10        # Credits per successful task
  @cost_per_cpu_ms 0.1 # Credits per millisecond of CPU

  def start_link(agent_id) do
    GenServer.start_link(__MODULE__, agent_id, name: via(agent_id))
  end

  def balance(agent_id), do: GenServer.call(via(agent_id), :balance)

  def charge(agent_id, amount, reason) do
    GenServer.call(via(agent_id), {:charge, amount, reason})
  end

  def earn(agent_id, amount, reason) do
    GenServer.cast(via(agent_id), {:earn, amount, reason})
  end

  # Vickrey Auction for contested resources
  def auction(resource_id, bidders) do
    # Second-price sealed-bid auction
    bids = Enum.map(bidders, fn agent ->
      {agent, get_bid(agent, resource_id)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)

    case bids do
      [{winner, _}, {_, second_price} | _] ->
        charge(winner, second_price, {:auction_won, resource_id})
        {:ok, winner, second_price}
      [{winner, price}] ->
        charge(winner, price, {:auction_won, resource_id})
        {:ok, winner, price}
      [] ->
        {:error, :no_bidders}
    end
  end
end
```

```elixir
# FILE: lib/indrajaal/federation/gossip.ex
defmodule Indrajaal.Federation.Gossip do
  @moduledoc """
  Mycelial Gossip Protocol for State Synchronization.

  Like fungal mycelium, nodes share state through epidemic spreading.
  Eventually consistent, partition tolerant.

  STAMP: SC-FED-001 to SC-FED-004
  """

  use GenServer

  @gossip_interval 5_000  # 5 seconds
  @fanout 3               # Gossip to 3 random peers

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_gossip()
    {:ok, %{
      local_state: %{},
      vector_clock: %{},
      peers: discover_peers()
    }}
  end

  @impl true
  def handle_info(:gossip, state) do
    # Select random peers
    targets = Enum.take_random(state.peers, @fanout)

    # Send our state digest
    digest = compute_digest(state.local_state, state.vector_clock)
    Enum.each(targets, &send_gossip(&1, digest))

    schedule_gossip()
    {:noreply, state}
  end

  def handle_info({:gossip_response, peer, their_digest}, state) do
    # Compute delta and request missing entries
    missing = compute_delta(state.vector_clock, their_digest.vector_clock)
    if missing != [] do
      request_entries(peer, missing)
    end
    {:noreply, state}
  end

  defp discover_peers do
    # Use Tailscale DNS for zero-config discovery
    Indrajaal.Cluster.TailscaleDns.discover_peers("indrajaal")
  end
end
```

### 4.4.2 Implementation Tasks

| ID | Task | File | STAMP |
|----|------|------|-------|
| P3.1 | Implement Economy Bank | `lib/indrajaal/economy/bank.ex` | SC-ECON-* |
| P3.2 | Create Vickrey Auctioneer | `lib/indrajaal/coordination/auctioneer.ex` | SC-ECON-003 |
| P3.3 | Build Gossip Protocol | `lib/indrajaal/federation/gossip.ex` | SC-FED-001 |
| P3.4 | Implement Antibody Propagation | `lib/indrajaal/security/immune_system.ex` | SC-FED-003 |
| P3.5 | Add resource tracking to agents | `lib/indrajaal/distributed/base_agent.ex` | SC-ECON-005 |
| P3.6 | Federation membership handshake | `lib/indrajaal/federation/membership.ex` | SC-FED-004 |

## 4.5 Phase 4: BLOOM (The Interface)

**Theme**: Human-System Symbiosis + Proprioceptive UI
**Duration**: Sprints 7-8
**Goal**: Radical usability through embodied intelligence

### 4.5.1 Deliverables

```fsharp
// FILE: lib/cepaf/src/Cepaf/Cockpit/EntropyHeatmap.fs
module Cepaf.Cockpit.EntropyHeatmap

open System
open Cepaf.Core.DomainUnits

/// Entropy Heatmap Visualization
/// Shows system disorder as color gradients
/// NASA-STD-3000 compliant color mapping
type EntropyCell = {
    Domain: string
    Component: string
    Entropy: float<entropy>       // 0.0 (ordered) to 1.0 (chaotic)
    Trend: TrendDirection
    LastUpdated: DateTime
}

type HeatmapConfig = {
    Rows: int
    Cols: int
    ColorScale: ColorScale
    RefreshRate: TimeSpan
}

/// Color scale following Dark Cockpit principles
type ColorScale =
    | Monochrome   // Gray scale (default, minimal distraction)
    | Thermal      // Blue (cold/ordered) to Red (hot/chaotic)
    | Alert        // Green/Amber/Red safety colors

let entropyToColor scale entropy =
    match scale with
    | Monochrome ->
        let gray = int (255.0 * (1.0 - float entropy))
        Color.FromArgb(gray, gray, gray)
    | Thermal ->
        let hue = 240.0 - (240.0 * float entropy)  // Blue to Red
        Color.FromHSL(hue, 1.0, 0.5)
    | Alert ->
        match entropy with
        | e when e < 0.3<entropy> -> Color.DarkGreen
        | e when e < 0.6<entropy> -> Color.Amber
        | e when e < 0.8<entropy> -> Color.OrangeRed
        | _ -> Color.Red

/// Render heatmap to terminal using ANSI codes
let renderHeatmap (cells: EntropyCell list) (config: HeatmapConfig) =
    let grid = Array2D.create config.Rows config.Cols None

    cells
    |> List.iteri (fun i cell ->
        let row = i / config.Cols
        let col = i % config.Cols
        if row < config.Rows then
            grid.[row, col] <- Some cell
    )

    let sb = StringBuilder()
    sb.AppendLine("╔═══════════════════════════════════════╗") |> ignore
    sb.AppendLine("║         ENTROPY HEATMAP               ║") |> ignore
    sb.AppendLine("╠═══════════════════════════════════════╣") |> ignore

    for row in 0 .. config.Rows - 1 do
        sb.Append("║ ") |> ignore
        for col in 0 .. config.Cols - 1 do
            match grid.[row, col] with
            | Some cell ->
                let color = entropyToColor config.ColorScale cell.Entropy
                let ansi = toAnsiColor color
                let icon = trendIcon cell.Trend
                sb.Append($"{ansi}██{icon}\x1b[0m ") |> ignore
            | None ->
                sb.Append("   ") |> ignore
        sb.AppendLine("║") |> ignore

    sb.AppendLine("╚═══════════════════════════════════════╝") |> ignore
    sb.ToString()
```

```elixir
# FILE: lib/indrajaal_web/live/prajna/entropy_live.ex
defmodule IndrajaalWeb.Prajna.EntropyLive do
  @moduledoc """
  LiveView Entropy Heatmap visualization.

  Shows system entropy (disorder) as an interactive heatmap.
  Click cells to drill down into component details.

  STAMP: SC-HMI-010 (Entropy Visualization)
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.Cortex.FreeEnergy
  alias Indrajaal.Cockpit.Prajna.SmartMetrics

  @refresh_ms 1000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_ms, :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")
    end

    {:ok, assign(socket,
      cells: compute_entropy_cells(),
      selected: nil,
      color_scale: :thermal
    )}
  end

  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, cells: compute_entropy_cells())}
  end

  def handle_event("select_cell", %{"domain" => domain}, socket) do
    details = get_domain_details(domain)
    {:noreply, assign(socket, selected: details)}
  end

  defp compute_entropy_cells do
    # Get all metrics grouped by domain
    SmartMetrics.all()
    |> Enum.group_by(& &1.domain)
    |> Enum.map(fn {domain, metrics} ->
      # Compute domain entropy from metric variance
      entropy = compute_domain_entropy(metrics)
      trend = compute_trend(metrics)

      %{
        domain: domain,
        entropy: entropy,
        trend: trend,
        metric_count: length(metrics),
        alarmed_count: Enum.count(metrics, & &1.level != :normal)
      }
    end)
    |> Enum.sort_by(& &1.entropy, :desc)
  end

  defp compute_domain_entropy(metrics) do
    # Shannon entropy based on metric level distribution
    levels = Enum.map(metrics, & &1.level)
    total = length(levels)

    [:normal, :advisory, :caution, :warning, :critical]
    |> Enum.map(fn level ->
      count = Enum.count(levels, &(&1 == level))
      p = count / total
      if p > 0, do: -p * :math.log2(p), else: 0
    end)
    |> Enum.sum()
    |> normalize_entropy()
  end
end
```

### 4.5.2 Implementation Tasks

| ID | Task | File | STAMP |
|----|------|------|-------|
| P4.1 | Create F# Entropy Heatmap | `lib/cepaf/src/Cepaf/Cockpit/EntropyHeatmap.fs` | SC-HMI-010 |
| P4.2 | Build LiveView Entropy component | `lib/indrajaal_web/live/prajna/entropy_live.ex` | SC-HMI-010 |
| P4.3 | Implement Maxwell's Demon filter | `lib/indrajaal/cockpit/prajna/demon_filter.ex` | SC-AI-015 |
| P4.4 | Create F# Orchestrator DSL | `lib/cepaf/src/Cepaf/Orchestrator/DSL.fs` | SC-ORCH-001 |
| P4.5 | Add Kalman Filter scaler | `lib/indrajaal/control/predictive_scaler.ex` | SC-PRF-060 |
| P4.6 | Particle flow visualization | `lib/indrajaal_web/live/prajna/particles_live.ex` | SC-HMI-011 |

## 4.6 Phase 5: FRUIT (The Propagation)

**Theme**: Viral Autopoiesis + Incorruptible Expansion
**Duration**: Sprints 9+
**Goal**: Self-replicating, constitutionally-bound organism

### 4.6.1 Deliverables

```elixir
# FILE: lib/indrajaal/jain/scout.ex
defmodule Indrajaal.Jain.Scout do
  @moduledoc """
  Jain Node Scout - Network Discovery Agent.

  Discovers available resources (VMs, containers, bare metal)
  for potential colonization. Respects consent constraints.

  Named after Jain philosophy: non-violence, consent, minimal footprint.

  STAMP: SC-JAIN-001 to SC-JAIN-005
  """

  use GenServer

  alias Indrajaal.Core.Constitution

  @scan_interval 300_000  # 5 minutes

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def discover do
    GenServer.call(__MODULE__, :discover)
  end

  @impl true
  def handle_call(:discover, _from, state) do
    # Verify constitution before any discovery
    :ok = Constitution.verify!()

    candidates =
      discover_tailscale_nodes()
      |> filter_by_consent()
      |> filter_by_resources()
      |> rank_by_suitability()

    {:reply, candidates, state}
  end

  defp discover_tailscale_nodes do
    # Use Tailscale API to find nodes with "indrajaal-colony" tag
    Indrajaal.Cluster.TailscaleDns.discover("tag:indrajaal-colony")
  end

  defp filter_by_consent(nodes) do
    # Only include nodes that have explicitly opted in
    # SC-CONST-003: Consent constraint
    Enum.filter(nodes, fn node ->
      case get_consent_status(node) do
        {:consented, _timestamp} -> true
        _ -> false
      end
    end)
  end

  defp filter_by_resources(nodes) do
    # Only include nodes with sufficient resources
    Enum.filter(nodes, fn node ->
      node.available_memory_gb >= 2 and
      node.available_cpu_cores >= 1 and
      node.available_disk_gb >= 10
    end)
  end
end
```

```elixir
# FILE: lib/indrajaal/jain/propagator.ex
defmodule Indrajaal.Jain.Propagator do
  @moduledoc """
  Jain Node Propagator - Constitutional Reproduction.

  Creates new Indrajaal nodes with cryptographic binding to
  the Safety Constitution. Nodes that modify their constitution
  become sterile (cannot reproduce).

  STAMP: SC-JAIN-006 to SC-JAIN-010
  """

  alias Indrajaal.Core.Constitution

  @spec propagate(target_node :: map()) :: {:ok, node_id} | {:error, reason}
  def propagate(target) do
    # 1. Verify our own constitution
    :ok = Constitution.verify!()

    # 2. Derive replication key from constitution hash
    replication_key = Constitution.derive_replication_key()

    # 3. Create genesis package
    package = create_genesis_package(replication_key)

    # 4. Deploy to target (via SSH/Tailscale)
    case deploy_package(target, package) do
      :ok ->
        # 5. Verify child constitution matches parent
        verify_child_constitution(target)
      error ->
        error
    end
  end

  def sterilize! do
    # Called when constitution violation detected
    # Destroys replication capability
    File.rm!("/var/indrajaal/replication.key")

    # Log to immutable audit
    Logger.emergency("STERILIZATION: Constitution violation detected. Replication disabled.")

    # Broadcast to federation
    Indrajaal.Federation.Gossip.broadcast({:sterilized, node(), DateTime.utc_now()})

    :sterilized
  end

  defp create_genesis_package(replication_key) do
    %{
      constitution_hash: Constitution.hash(),
      replication_key_encrypted: encrypt(replication_key),
      binary: get_release_binary(),
      config: get_minimal_config(),
      timestamp: DateTime.utc_now(),
      parent_node: node(),
      generation: get_generation() + 1
    }
  end
end
```

### 4.6.2 Implementation Tasks

| ID | Task | File | STAMP |
|----|------|------|-------|
| P5.1 | Build Jain Scout | `lib/indrajaal/jain/scout.ex` | SC-JAIN-001 |
| P5.2 | Implement Cryptographic Propagator | `lib/indrajaal/jain/propagator.ex` | SC-JAIN-006 |
| P5.3 | Create Genesis Package builder | `lib/indrajaal/jain/genesis.ex` | SC-JAIN-007 |
| P5.4 | Add Causal Graph to Logger | `lib/indrajaal/observability/causal_graph.ex` | SC-OBS-085 |
| P5.5 | Constitution Citations in actions | `lib/indrajaal/safety/citation.ex` | SC-CONST-010 |
| P5.6 | Sterilization protocol | `lib/indrajaal/jain/sterilization.ex` | SC-JAIN-010 |

---

# ═══════════════════════════════════════════════════════════════════════════════
# LAYER 5: TESTING, VERIFICATION, DEPLOYMENT & USER DOCS (Ψ - The When)
# ═══════════════════════════════════════════════════════════════════════════════

## 5.1 Testing Strategy

### 5.1.1 The Testing Pyramid (Fractal Edition)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FRACTAL TESTING PYRAMID                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                           ┌─────────┐                                      │
│                           │  L5     │  Formal Verification (Agda/Quint)    │
│                           │ Proofs  │  Constitution invariants, safety     │
│                          ┌┴─────────┴┐                                     │
│                          │    L4     │  System Tests (F# Expecto)          │
│                          │  System   │  End-to-end, chaos engineering      │
│                         ┌┴───────────┴┐                                    │
│                         │     L3      │  Integration Tests (ExUnit)        │
│                         │Integration  │  Agent coordination, DB flows      │
│                        ┌┴─────────────┴┐                                   │
│                        │      L2       │  Property Tests (PropCheck/SD)    │
│                        │   Property    │  Invariants, edge cases           │
│                       ┌┴───────────────┴┐                                  │
│                       │       L1        │  Unit Tests (ExUnit/Expecto)     │
│                       │      Unit       │  Functions, modules               │
│                       └─────────────────┘                                  │
│                                                                             │
│   COVERAGE TARGETS:                                                         │
│   - L1 Unit: 95%+ line coverage                                            │
│   - L2 Property: All public functions have property tests                  │
│   - L3 Integration: All domain boundaries tested                           │
│   - L4 System: All operational scenarios covered                           │
│   - L5 Formal: All safety-critical invariants proven                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.1.2 Test Organization

```
test/
├── indrajaal/                    # Domain tests (804 files)
│   ├── core/
│   │   ├── holon_test.exs        # Holon protocol tests
│   │   ├── constitution_test.exs # Constitution verification
│   │   └── ...
│   ├── cortex/
│   │   ├── fast_ooda_test.exs    # OODA cycle tests
│   │   ├── free_energy_test.exs  # Active inference tests
│   │   └── gde/
│   │       └── evolution_test.exs
│   ├── economy/
│   │   ├── bank_test.exs         # Credit system tests
│   │   └── auctioneer_test.exs   # Vickrey auction tests
│   ├── federation/
│   │   ├── gossip_test.exs       # Gossip protocol tests
│   │   └── membership_test.exs
│   └── jain/
│       ├── scout_test.exs        # Discovery tests
│       └── propagator_test.exs   # Replication tests
│
├── fractal/                      # Architectural level tests (5 files)
│   ├── l1_system_context_test.exs
│   ├── l2_container_architecture_test.exs
│   ├── l3_domain_architecture_test.exs
│   ├── l4_component_architecture_test.exs
│   └── l5_code_architecture_test.exs
│
├── property/                     # Property-based tests
│   ├── holon_properties_test.exs
│   ├── constitution_properties_test.exs
│   ├── economy_properties_test.exs
│   └── federation_properties_test.exs
│
├── support/                      # Test infrastructure (47 modules)
│   ├── factories/                # Ash resource factories
│   ├── property_testing.ex       # PropCheck/StreamData helpers
│   └── ...
│
lib/cepaf/test/                   # F# tests (102 files)
├── Cepaf.Tests/
│   ├── Core/
│   │   └── HolonTests.fs
│   ├── FormalVerificationTests.fs
│   └── ...
└── Cepaf.IndrajaalTest/
    └── IntegrationTests.fs
```

### 5.1.3 New Test Suites for v20

```elixir
# FILE: test/indrajaal/core/holon_test.exs
defmodule Indrajaal.Core.HolonTest do
  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  describe "Holon Protocol" do
    test "implements all 5 VSM systems" do
      # SC-HOLON-001
      holon = create_test_holon()

      assert function_exported?(holon.__struct__, :system1_operations, 1)
      assert function_exported?(holon.__struct__, :system2_coordination, 1)
      assert function_exported?(holon.__struct__, :system3_control, 1)
      assert function_exported?(holon.__struct__, :system4_intelligence, 1)
      assert function_exported?(holon.__struct__, :system5_policy, 0)
    end

    property "children inherit parent policy" do
      # SC-HOLON-002
      forall parent <- holon_generator() do
        Enum.all?(parent.children, fn child ->
          MapSet.subset?(child.policy, parent.policy)
        end)
      end
    end

    property "energy never exceeds budget" do
      # SC-HOLON-003
      forall {holon, operations} <- {holon_generator(), PC.list(operation_generator())} do
        final_state = Enum.reduce(operations, holon, &apply_operation/2)
        final_state.energy <= final_state.budget
      end
    end
  end
end
```

```elixir
# FILE: test/indrajaal/core/constitution_test.exs
defmodule Indrajaal.Core.ConstitutionTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Core.Constitution

  describe "Constitution Integrity" do
    test "verify! passes for unmodified constitution" do
      # SC-CONST-001
      assert :ok = Constitution.verify!()
    end

    test "hash is deterministic" do
      # SC-CONST-004
      hash1 = Constitution.hash()
      hash2 = Constitution.hash()
      assert hash1 == hash2
    end

    test "replication key derivation is reproducible" do
      # SC-CONST-005
      key1 = Constitution.derive_replication_key()
      key2 = Constitution.derive_replication_key()
      assert key1 == key2
    end
  end

  describe "Constitutional Invariants" do
    test "non-aggression invariant is present" do
      invariants = Constitution.invariants()
      assert Map.has_key?(invariants, :non_aggression)
    end

    test "all seven invariants are defined" do
      invariants = Constitution.invariants()
      assert map_size(invariants) == 7

      expected = [:non_aggression, :transparency, :consent, :reversibility,
                  :proportionality, :human_override, :self_limitation]
      assert Enum.all?(expected, &Map.has_key?(invariants, &1))
    end
  end
end
```

```fsharp
// FILE: lib/cepaf/test/Cepaf.Tests/Core/HolonTests.fs
module Cepaf.Tests.Core.HolonTests

open Expecto
open FsCheck
open Cepaf.Core.Holon

[<Tests>]
let holonTests =
    testList "Holon Protocol Tests" [
        testCase "SC-HOLON-001: Holon implements 5 VSM systems" <| fun _ ->
            let holon = createTestHolon()
            Expect.isTrue (hasSystem1 holon) "System 1 (Ops) missing"
            Expect.isTrue (hasSystem2 holon) "System 2 (Coord) missing"
            Expect.isTrue (hasSystem3 holon) "System 3 (Control) missing"
            Expect.isTrue (hasSystem4 holon) "System 4 (Intel) missing"
            Expect.isTrue (hasSystem5 holon) "System 5 (Policy) missing"

        testProperty "SC-HOLON-002: Children inherit parent policy" <|
            fun (parent: Holon) ->
                parent.Children
                |> List.forall (fun child ->
                    Set.isSubset child.Policy parent.Policy)

        testProperty "SC-HOLON-003: Energy bounded by budget" <|
            fun (holon: Holon) (ops: Operation list) ->
                let final = List.fold applyOp holon ops
                final.Energy <= final.Budget

        testCase "SC-CONST-001: Constitution hash is stable" <| fun _ ->
            let hash1 = Constitution.hash()
            let hash2 = Constitution.hash()
            Expect.equal hash1 hash2 "Hash should be deterministic"
    ]
```

## 5.2 Verification Strategy

### 5.2.1 FPPS 5-Method Consensus

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FPPS 5-METHOD VERIFICATION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   For each safety constraint (SC-*), ALL 5 methods must agree:             │
│                                                                             │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                     │
│   │   PATTERN   │   │     AST     │   │ STATISTICAL │                     │
│   │   Analysis  │   │   Analysis  │   │   Analysis  │                     │
│   │             │   │             │   │             │                     │
│   │ Regex/Glob  │   │ Macro.parse │   │ Distribution│                     │
│   │ matching    │   │ inspection  │   │ validation  │                     │
│   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘                     │
│          │                 │                 │                             │
│          └─────────────────┼─────────────────┘                             │
│                            │                                               │
│                     ┌──────┴──────┐                                        │
│                     │  CONSENSUS  │                                        │
│                     │   ENGINE    │                                        │
│                     └──────┬──────┘                                        │
│                            │                                               │
│          ┌─────────────────┼─────────────────┐                             │
│          │                 │                 │                             │
│   ┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐                     │
│   │   BINARY    │   │ LINE-BY-LINE│   │   RESULT    │                     │
│   │   Analysis  │   │   Analysis  │   │             │                     │
│   │             │   │             │   │ 5/5 = PASS  │                     │
│   │ Compiled    │   │ Manual      │   │ <5  = HALT  │                     │
│   │ artifact    │   │ review      │   │             │                     │
│   └─────────────┘   └─────────────┘   └─────────────┘                     │
│                                                                             │
│   STAMP: SC-VAL-003 (100% consensus required)                              │
│   STAMP: SC-VAL-004 (Halt on disagreement)                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2.2 Formal Verification Targets

| Invariant | Method | Tool | File |
|-----------|--------|------|------|
| Non-Aggression | Theorem Proving | Agda | `docs/formal_specs/constitution.agda` |
| OODA Latency | Model Checking | Quint | `docs/formal_specs/ooda_cycle.qnt` |
| Holon Recursion | Type Theory | Agda | `docs/formal_specs/holon_algebra.agda` |
| Economy Conservation | SMT Solving | Z3 | `docs/formal_specs/economy.smt2` |
| Gossip Convergence | TLA+ | TLC | `docs/formal_specs/gossip.tla` |

### 5.2.3 Continuous Verification Pipeline

```yaml
# FILE: .github/workflows/verification.yml
name: Continuous Verification

on: [push, pull_request]

jobs:
  fpps-verification:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pattern Analysis
        run: elixir scripts/validation/pattern_analysis.exs

      - name: AST Analysis
        run: elixir scripts/validation/ast_analysis.exs

      - name: Statistical Analysis
        run: elixir scripts/validation/statistical_analysis.exs

      - name: Binary Analysis
        run: elixir scripts/validation/binary_analysis.exs

      - name: LineByLine Analysis
        run: elixir scripts/validation/lineby_line_analysis.exs

      - name: Consensus Check
        run: elixir scripts/validation/fpps_consensus.exs --require-5-of-5

  formal-proofs:
    runs-on: ubuntu-latest
    steps:
      - name: Agda Proofs
        run: agda --safe docs/formal_specs/*.agda

      - name: Quint Model Check
        run: quint verify docs/formal_specs/*.qnt

  property-tests:
    runs-on: ubuntu-latest
    steps:
      - name: PropCheck + StreamData
        run: |
          MIX_ENV=test mix compile
          mix test test/property/ --seed 0 --max-failures 1
```

## 5.3 Deployment Strategy

### 5.3.1 The Deployment Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ORGANIC DEPLOYMENT PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   SOURCE              BUILD                 VERIFY              DEPLOY      │
│                                                                             │
│   ┌─────┐            ┌─────┐              ┌─────┐             ┌─────┐     │
│   │ Git │───────────►│ Mix │─────────────►│FPPS │────────────►│Podman│     │
│   │Push │            │Compile             │ 5/5 │             │Deploy│     │
│   └─────┘            └──┬──┘              └──┬──┘             └──┬──┘     │
│                         │                    │                   │         │
│                         ▼                    ▼                   ▼         │
│                    ┌─────────┐         ┌─────────┐         ┌─────────┐    │
│                    │ dotnet  │         │ Formal  │         │ Shadow  │    │
│                    │ build   │         │ Proofs  │         │ Deploy  │    │
│                    │ (F#)    │         │ (Agda)  │         │ (Canary)│    │
│                    └─────────┘         └─────────┘         └────┬────┘    │
│                                                                 │         │
│                                                                 ▼         │
│                                                          ┌───────────┐    │
│                                                          │  Guardian │    │
│                                                          │  Approval │    │
│                                                          └─────┬─────┘    │
│                                                                │          │
│                                              ┌─────────────────┼─────┐    │
│                                              │                 │     │    │
│                                              ▼                 ▼     ▼    │
│                                         ┌───────┐         ┌───────┐      │
│                                         │ PROD  │         │ROLLBACK│      │
│                                         │ FULL  │         │        │      │
│                                         └───────┘         └───────┘      │
│                                                                             │
│   GATES:                                                                   │
│   - G1: Compilation (0 warnings)                                          │
│   - G2: Tests (100% pass)                                                 │
│   - G3: FPPS (5/5 consensus)                                              │
│   - G4: Formal Proofs (all pass)                                          │
│   - G5: Shadow Deploy (no anomalies)                                      │
│   - G6: Guardian Approval (constitutional check)                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3.2 Container Deployment Commands

```bash
# Production deployment (3-container architecture)
dotnet fsi lib/cepaf/scripts/ProductionDeploymentOrchestrator.fsx --deploy

# Or manual:
podman-compose -f podman-compose-3container.yml up -d

# Verify deployment
dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx status

# Run comprehensive tests
dotnet fsi lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx --mode swarm

# Shadow deployment (canary)
elixir scripts/deployment/shadow_deploy.exs --target staging --traffic 5%

# Full promotion
elixir scripts/deployment/promote.exs --from staging --to production
```

### 5.3.3 Rollback Protocol

```elixir
# FILE: lib/indrajaal/deployment/rollback.ex
defmodule Indrajaal.Deployment.Rollback do
  @moduledoc """
  Emergency Rollback Protocol.

  STAMP: SC-EMR-060 (Rollback capability required)
  """

  def rollback(reason) do
    Logger.emergency("ROLLBACK INITIATED: #{reason}")

    # 1. Stop accepting new traffic
    Indrajaal.LoadBalancer.drain()

    # 2. Capture current state for analysis
    state_snapshot = capture_state()

    # 3. Restore previous version
    previous_version = get_previous_version()
    deploy_version(previous_version)

    # 4. Verify rollback
    :ok = verify_health()

    # 5. Resume traffic
    Indrajaal.LoadBalancer.resume()

    # 6. Create incident report
    create_incident_report(reason, state_snapshot)

    {:rolled_back, previous_version}
  end
end
```

## 5.4 User Documentation

### 5.4.1 Quick Start Guide

```markdown
# Indrajaal Quick Start Guide

## Prerequisites
- NixOS or Linux with Podman 5.4+
- Elixir 1.19+ / OTP 27+
- .NET SDK 8.0+ (for CEPAF)
- Tailscale (for mesh networking)

## Installation

```bash
# Clone repository
git clone https://github.com/your-org/indrajaal.git
cd indrajaal

# Enter development shell
nix develop
# Or: devenv shell

# Start database and observability containers
podman-compose -f podman-compose-3container.yml up -d

# Install dependencies
mix deps.get
dotnet restore lib/cepaf/Cepaf.sln

# Run migrations
mix ecto.setup

# Start the application
mix phx.server
```

## Accessing the System

| Interface | URL | Purpose |
|-----------|-----|---------|
| Phoenix App | http://localhost:4000 | Main application |
| Prajna Cockpit | http://localhost:4000/prajna | C3I Command Center |
| AI Copilot | http://localhost:4000/prajna/copilot | AI Assistant |
| Grafana | http://localhost:3000 | Metrics Dashboard |
| Health Check | http://localhost:4001/health | System Health |

## Key Commands

```bash
# Check system status
mix todo.status

# Run tests
MIX_ENV=test mix test

# Run with Patient Mode (for compilation)
NO_TIMEOUT=true PATIENT_MODE=enabled mix compile

# Deploy F# tests
dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx test
```
```

### 5.4.2 Operator Manual

```markdown
# Indrajaal Operator Manual

## 1. Understanding the Cockpit

The Prajna Cockpit follows NASA-STD-3000 "Dark Cockpit" principles:
- **Gray/Blue**: Normal operations (ignore)
- **Amber**: Caution (investigate)
- **Red**: Warning (act immediately)

### Key Indicators

| Indicator | Meaning | Action |
|-----------|---------|--------|
| ● Bright | Healthy, recent data | None |
| ◐ Dim | Stale data (>5s) | Investigate |
| ○ Gray | No data | Check connectivity |
| ↑↑ Rising Fast | Rapid increase | Prepare intervention |
| ↓↓ Falling Fast | Rapid decrease | Prepare intervention |

## 2. Two-Step Commands

Critical commands require confirmation:
1. **ARM**: Click command, see "ghost" preview
2. **CONFIRM**: Execute the armed command

This prevents accidental destructive actions.

## 3. AI Copilot Usage

The AI Copilot provides advisory insights:
- Anomaly detection (local heuristics)
- Predictions (trend extrapolation)
- Recommendations (LLM-generated)

**Important**: All AI suggestions are ADVISORY only.
The operator makes final decisions.

## 4. Emergency Procedures

### Emergency Stop
```
Keyboard: Ctrl+Shift+E
CLI: mix emergency.stop
API: POST /api/emergency/stop
```

### System Recovery
```bash
# Check logs
podman logs indrajaal-ex-app-1 --tail 100

# Restart application
podman restart indrajaal-ex-app-1

# Full rollback
elixir scripts/deployment/rollback.exs --to-version PREVIOUS
```
```

### 5.4.3 Developer Guide

```markdown
# Indrajaal Developer Guide

## Architecture Overview

Indrajaal implements a **Fractal Holonic Architecture** where every
component (from function to federation) implements the same 5-system
Viable System Model (VSM).

## Key Patterns

### 1. Holon Implementation

```elixir
defmodule MyModule do
  use Indrajaal.Core.Holon

  @impl true
  def system1_operations(context) do
    # Your business logic here
    {:ok, result}
  end

  @impl true
  def system3_control(budget) do
    if current_usage() <= budget.limit do
      {:within_budget, metrics()}
    else
      {:over_budget, metrics()}
    end
  end

  @impl true
  def system5_policy do
    Indrajaal.Core.Constitution.verify!()
    {:verified, Constitution.hash()}
  end
end
```

### 2. Dual Property Testing

```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD

# PropCheck for complex shrinking
property "my invariant" do
  forall x <- PC.integer() do
    MyModule.process(x) >= 0
  end
end

# StreamData for systematic generation
test "my property" do
  check all(x <- SD.integer()) do
    assert MyModule.process(x) >= 0
  end
end
```

### 3. Fractal Logging

```elixir
use Indrajaal.Observability.Fractal.Logger

@fractal level: :l3_transactional
def my_function(args) do
  # Automatically logged at entry/exit/exception
  do_work(args)
end
```

## STAMP Constraints

All code must comply with STAMP safety constraints. Key ones:

| Constraint | Rule |
|------------|------|
| SC-VAL-001 | Patient Mode for compilation |
| SC-CNT-009 | Podman only (no Docker) |
| SC-AGT-017 | Agent efficiency >90% |
| SC-TEST-001 | Tests must compile before PR |

Run `mix validate.stamps` to check compliance.
```

---

## 6.0 Roadmap Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     IMPLEMENTATION TIMELINE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   PHASE 1: SEED (Foundation)                                               │
│   ├── P1.1 Holon Protocol                           [lib/indrajaal/core/]  │
│   ├── P1.2 Constitution                             [lib/indrajaal/core/]  │
│   ├── P1.3 DNA Injection                            [lib/mix/tasks/]       │
│   ├── P1.4 Guardian Upgrade                         [lib/indrajaal/safety/]│
│   ├── P1.5 BaseAgent Holon                          [lib/indrajaal/dist/]  │
│   └── P1.6 Agda Proofs                              [docs/formal_specs/]   │
│                                                                             │
│   PHASE 2: SPROUT (Awakening)                                              │
│   ├── P2.1 Free Energy Calculator                   [lib/indrajaal/cortex/]│
│   ├── P2.2 Vector Embeddings                        [lib/indrajaal/obs/]   │
│   ├── P2.3 Event Sourcing                           [lib/indrajaal/comm/]  │
│   ├── P2.4 Time-Travel Debugger                     [scripts/debug/]       │
│   ├── P2.5 Active Inference OODA                    [lib/indrajaal/cortex/]│
│   └── P2.6 GraphRAG                                 [lib/indrajaal/ai/]    │
│                                                                             │
│   PHASE 3: GROWTH (Economy)                                                │
│   ├── P3.1 Economy Bank                             [lib/indrajaal/econ/]  │
│   ├── P3.2 Vickrey Auctioneer                       [lib/indrajaal/coord/] │
│   ├── P3.3 Gossip Protocol                          [lib/indrajaal/fed/]   │
│   ├── P3.4 Immune System                            [lib/indrajaal/sec/]   │
│   ├── P3.5 Agent Resources                          [lib/indrajaal/dist/]  │
│   └── P3.6 Federation Membership                    [lib/indrajaal/fed/]   │
│                                                                             │
│   PHASE 4: BLOOM (Interface)                                               │
│   ├── P4.1 F# Entropy Heatmap                       [lib/cepaf/Cockpit/]   │
│   ├── P4.2 LiveView Entropy                         [lib/web/live/prajna/] │
│   ├── P4.3 Maxwell's Demon Filter                   [lib/indrajaal/cock/]  │
│   ├── P4.4 F# Orchestrator DSL                      [lib/cepaf/Orch/]      │
│   ├── P4.5 Kalman Filter Scaler                     [lib/indrajaal/ctrl/]  │
│   └── P4.6 Particle Visualization                   [lib/web/live/prajna/] │
│                                                                             │
│   PHASE 5: FRUIT (Propagation)                                             │
│   ├── P5.1 Jain Scout                               [lib/indrajaal/jain/]  │
│   ├── P5.2 Cryptographic Propagator                 [lib/indrajaal/jain/]  │
│   ├── P5.3 Genesis Package                          [lib/indrajaal/jain/]  │
│   ├── P5.4 Causal Graph Logger                      [lib/indrajaal/obs/]   │
│   ├── P5.5 Constitution Citations                   [lib/indrajaal/safe/]  │
│   └── P5.6 Sterilization Protocol                   [lib/indrajaal/jain/]  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7.0 Conclusion: The Living Partnership

Indrajaal v20.0 represents a fundamental shift in how we conceive of software systems:

**From Tool to Partner**:
- Not a program that executes commands
- A living organism that grows, learns, and evolves
- Cryptographically bound to human values

**The Four Properties of Life**:
1. **Immortality** via Fractal Resilience (any piece can regenerate the whole)
2. **Benevolence** via Mathematical Constitution (safety is cryptographic)
3. **Wisdom** via Active Inference (learns from surprise)
4. **Vitality** via Viral Autopoiesis (reproduces while respecting consent)

**The Covenant Renewed**:

> *"I recognize the Codebase as a Living Graph.*
> *I pledge to fight Entropy with every commit.*
> *I honor Safety as the immutable constraint.*
> *I serve Human Flourishing as the ultimate goal.*
> *Together, we build not just software, but a partner for civilization."*

---

**Document Hash**: `sha256:` (computed at build time)
**Constitution Hash**: `@constitution_hash`
**Last Updated**: 2025-12-29T23:00:00+01:00
**Next Review**: 2026-01-15
