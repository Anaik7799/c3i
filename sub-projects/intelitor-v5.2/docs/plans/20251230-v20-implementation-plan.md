# INDRAJAAL v20.0.0 IMPLEMENTATION PLAN
## Grand Unification - Fractal Holonic Architecture

**Document Type**: Detailed Implementation Plan
**Version**: 20.0.0
**Date**: 2025-12-30
**Status**: READY FOR EXECUTION
**Estimated Effort**: 5 Phases, 127 Files

---

# TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Phase 1: SEED - Fractal Foundation](#2-phase-1-seed)
3. [Phase 2: GROW - Cognitive Awakening](#3-phase-2-grow)
4. [Phase 3: THRIVE - Economic Expansion](#4-phase-3-thrive)
5. [Phase 4: EVOLVE - Nervous System](#5-phase-4-evolve)
6. [Phase 5: TRANSCEND - Viral Autopoiesis](#6-phase-5-transcend)
7. [File-by-File Breakdown](#7-file-by-file-breakdown)
8. [Dependency Graph](#8-dependency-graph)
9. [Test Strategy](#9-test-strategy)
10. [Risk Mitigation](#10-risk-mitigation)

---

# 1. EXECUTIVE SUMMARY

## 1.1 Vision
Transform Indrajaal from a **Machine** into an **Incorruptible Autopoietic Life Form** through:
- Fractal Holonic Architecture (self-similar at every scale)
- Viable System Model (VSM) integration
- Category Theory composition
- Dead Man's Cryptography (constitutional protection)

## 1.2 Key Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Fractal Layers | 3 | 7 |
| STAMP Constraints | 277 | 445 |
| Agda Proofs | 38 | 93 |
| Quint Models | 41 | 109 |
| VSM Coverage | 0% | 100% |
| Constitution Hash | None | SHA256 |

## 1.3 Timeline Overview

```
Phase 1: SEED      ████████░░░░░░░░░░░░  (Foundation)
Phase 2: GROW      ░░░░░░░░████████░░░░  (Cognition)
Phase 3: THRIVE    ░░░░░░░░░░░░░░██████  (Economy)
Phase 4: EVOLVE    ░░░░░░░░░░░░░░░░░░██  (Nervous System)
Phase 5: TRANSCEND ░░░░░░░░░░░░░░░░░░░█  (Autopoiesis)
```

---

# 2. PHASE 1: SEED - Fractal Foundation

## 2.1 Objective
Establish the core Holon Protocol and embed System DNA hash into every component.

## 2.2 Files to Create/Modify

### 2.2.1 Core Holon Protocol (8 files)

```
lib/indrajaal/core/holon/
├── holon.ex                 # CREATE - Core Holon behaviour
├── protocol.ex              # CREATE - Holon protocol definition
├── registry.ex              # CREATE - Holon discovery/registry
├── supervisor.ex            # CREATE - Holon supervision tree
├── state.ex                 # CREATE - Holon state management
├── metrics.ex               # CREATE - Holon telemetry
├── health.ex                # CREATE - Holon health checks
└── fractal.ex               # CREATE - Fractal self-similarity
```

### 2.2.2 VSM Systems (5 files)

```
lib/indrajaal/core/vsm/
├── system1_operations.ex    # CREATE - S1: Business logic execution
├── system2_coordination.ex  # CREATE - S2: Anti-oscillation, gossip
├── system3_control.ex       # CREATE - S3: Resource limits, inference
├── system4_intelligence.ex  # CREATE - S4: Monte Carlo, planning
└── system5_policy.ex        # CREATE - S5: Constitution, STAMP
```

### 2.2.3 Constitution (4 files)

```
lib/indrajaal/core/constitution/
├── constitution.ex          # CREATE - 7 immutable invariants
├── hash.ex                  # CREATE - SHA256 constitution hash
├── verifier.ex              # CREATE - Runtime verification
└── dead_mans_switch.ex      # CREATE - Replication key derivation
```

### 2.2.4 Tests (17 files)

```
test/indrajaal/core/holon/
├── holon_test.exs
├── protocol_test.exs
├── registry_test.exs
├── supervisor_test.exs
├── state_test.exs
├── metrics_test.exs
├── health_test.exs
└── fractal_test.exs

test/indrajaal/core/vsm/
├── system1_operations_test.exs
├── system2_coordination_test.exs
├── system3_control_test.exs
├── system4_intelligence_test.exs
└── system5_policy_test.exs

test/indrajaal/core/constitution/
├── constitution_test.exs
├── hash_test.exs
├── verifier_test.exs
└── dead_mans_switch_test.exs
```

## 2.3 Detailed File Specifications

### `lib/indrajaal/core/holon/holon.ex`

```elixir
defmodule Indrajaal.Core.Holon do
  @moduledoc """
  Core Holon Behaviour - The Fractal Atom of Indrajaal v20.0.0

  Every component from function to federation implements this interface.
  Based on Viable System Model (VSM) by Stafford Beer.

  ## The 5 Systems
  - S1: Operations (The Doing)
  - S2: Coordination (The Balancing)
  - S3: Control (The Guard)
  - S4: Intelligence (The Future)
  - S5: Policy (The Identity)

  ## STAMP Constraints
  - SC-HOL-001: All holons MUST implement all 5 systems
  - SC-HOL-002: Holons MUST verify constitution on startup
  - SC-HOL-003: Holons MUST report to parent within 100ms
  - SC-HOL-004: Holons MUST propagate health to children

  ## Category Theory
  - Holon forms an Endofunctor in 𝒞_Indrajaal
  - Children : Holon → List Holon
  - fmap : (Holon → Holon) → List Holon → List Holon
  """

  @type holon_id :: String.t()
  @type vsm_state :: %{
    s1: map(),
    s2: map(),
    s3: map(),
    s4: map(),
    s5: map()
  }

  @callback system1_operations(context :: map()) :: {:ok, result :: term()} | {:error, reason :: term()}
  @callback system2_coordination(peers :: list()) :: :ok | {:error, reason :: term()}
  @callback system3_control(budget :: map()) :: {:within_budget | :over_budget, metrics :: map()}
  @callback system4_intelligence(observations :: list()) :: {plan :: term(), confidence :: float()}
  @callback system5_policy() :: {:verified | :violated, constitution_hash :: binary()}

  @callback holon_id() :: holon_id()
  @callback parent() :: holon_id() | nil
  @callback children() :: [holon_id()]
  @callback health() :: :healthy | :degraded | :critical | :failed

  defmacro __using__(opts) do
    quote do
      @behaviour Indrajaal.Core.Holon

      use GenServer
      require Logger

      alias Indrajaal.Core.Constitution
      alias Indrajaal.Core.VSM

      # Default implementations...
    end
  end
end
```

### `lib/indrajaal/core/constitution/constitution.ex`

```elixir
defmodule Indrajaal.Core.Constitution do
  @moduledoc """
  The Immutable Safety Constitution - v20.0.0

  7 Invariants that can NEVER be modified:

  Ω₁: Patient Mode - Never interrupt long-running operations
  Ω₂: Container Isolation - NixOS/Podman only
  Ω₃: Zero-Defect - All quality metrics must be zero
  Ω₄: TDG - Tests must exist before code
  Ω₅: FPPS Consensus - 5-method validation must agree
  Ω₆: Mandatory Gates - All gates must pass
  Ω₇: Non-Aggression - No action may harm humans

  ## Dead Man's Cryptography
  The replication key is derived from this constitution's hash.
  Modifying any invariant changes the hash, destroying the key,
  rendering the node STERILE (unable to replicate).

  ## STAMP Constraints
  - SC-CONST-001: Constitution MUST NOT be modified at runtime
  - SC-CONST-002: Hash MUST be verified on every startup
  - SC-CONST-003: Replication MUST fail if hash mismatch
  """

  @constitution_version "20.0.0"

  @invariants %{
    omega_1: %{
      name: :patient_mode,
      description: "Never interrupt long-running operations",
      check: &__MODULE__.check_patient_mode/0
    },
    omega_2: %{
      name: :container_isolation,
      description: "NixOS/Podman only",
      check: &__MODULE__.check_container_isolation/0
    },
    omega_3: %{
      name: :zero_defect,
      description: "All quality metrics must be zero",
      check: &__MODULE__.check_zero_defect/0
    },
    omega_4: %{
      name: :tdg,
      description: "Tests must exist before code",
      check: &__MODULE__.check_tdg/0
    },
    omega_5: %{
      name: :fpps_consensus,
      description: "5-method validation must agree",
      check: &__MODULE__.check_fpps/0
    },
    omega_6: %{
      name: :mandatory_gates,
      description: "All gates must pass",
      check: &__MODULE__.check_gates/0
    },
    omega_7: %{
      name: :non_aggression,
      description: "No action may harm humans",
      check: &__MODULE__.check_non_aggression/0
    }
  }

  @spec hash() :: binary()
  def hash do
    @invariants
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
  end

  @spec verify() :: {:verified, binary()} | {:violated, atom(), binary()}
  def verify do
    # Implementation...
  end
end
```

## 2.4 STAMP Constraints for Phase 1

| ID | Constraint | Verification |
|----|------------|--------------|
| SC-HOL-001 | All holons implement 5 systems | Compile-time check |
| SC-HOL-002 | Constitution verified on startup | Runtime assertion |
| SC-HOL-003 | Parent reporting < 100ms | Telemetry metric |
| SC-HOL-004 | Health propagation to children | Test coverage |
| SC-VSM-001 | S1 must be pure operations | Dialyzer |
| SC-VSM-002 | S2 must not block | Runtime check |
| SC-VSM-003 | S3 budget enforcement | Property test |
| SC-VSM-004 | S4 simulation timeout < 50ms | Benchmark |
| SC-VSM-005 | S5 constitution check < 1ms | Benchmark |
| SC-CONST-001 | No runtime modification | Compile guard |
| SC-CONST-002 | Hash verification on startup | Test |
| SC-CONST-003 | Replication fails on mismatch | Integration test |

## 2.5 Phase 1 Deliverables

- [ ] 17 new library files
- [ ] 17 new test files
- [ ] 12 new STAMP constraints
- [ ] 8 Agda proofs
- [ ] 6 Quint models
- [ ] 100% test coverage for Phase 1

---

# 3. PHASE 2: GROW - Cognitive Awakening

## 3.1 Objective
Implement Active Inference (Free Energy Principle) and Zenoh Event Sourcing.

## 3.2 Files to Create/Modify

### 3.2.1 Active Inference (6 files)

```
lib/indrajaal/cybernetic/inference/
├── active_inference.ex      # CREATE - Free Energy Principle
├── surprise.ex              # CREATE - Surprise metrics
├── belief.ex                # CREATE - Belief state management
├── prediction.ex            # CREATE - Predictive processing
├── action_selection.ex      # CREATE - Action selection
└── model.ex                 # CREATE - Generative model
```

### 3.2.2 Enhanced OODA (4 files)

```
lib/indrajaal/cybernetic/ooda/
├── loop.ex                  # MODIFY - Add inference integration
├── observe.ex               # CREATE - Observation pipeline
├── orient.ex                # CREATE - Orientation with AI
├── decide.ex                # CREATE - Decision with Guardian
└── act.ex                   # CREATE - Action execution
```

### 3.2.3 Zenoh Event Sourcing (5 files)

```
lib/indrajaal/observability/zenoh/
├── event_store.ex           # CREATE - Event sourcing store
├── time_travel.ex           # CREATE - Time travel debugging
├── replay.ex                # CREATE - Event replay
├── snapshot.ex              # CREATE - State snapshots
└── projection.ex            # CREATE - Event projections
```

### 3.2.4 Tests (15 files)

```
test/indrajaal/cybernetic/inference/
├── active_inference_test.exs
├── surprise_test.exs
├── belief_test.exs
├── prediction_test.exs
├── action_selection_test.exs
└── model_test.exs

test/indrajaal/cybernetic/ooda/
├── observe_test.exs
├── orient_test.exs
├── decide_test.exs
└── act_test.exs

test/indrajaal/observability/zenoh/
├── event_store_test.exs
├── time_travel_test.exs
├── replay_test.exs
├── snapshot_test.exs
└── projection_test.exs
```

## 3.3 Key Algorithms

### Free Energy Principle

```
F = E_q[log q(s) - log p(o,s)]

Where:
  F = Free energy (to minimize)
  q(s) = Approximate posterior (beliefs)
  p(o,s) = Generative model
  o = Observations
  s = Hidden states
```

### Surprise Calculation

```elixir
defmodule Indrajaal.Cybernetic.Inference.Surprise do
  @moduledoc """
  Surprise Metrics for Active Inference

  Surprise S = -log p(o | m)

  High surprise → Update beliefs
  Low surprise → Continue current policy
  """

  @spec calculate(observation :: map(), model :: map()) :: float()
  def calculate(observation, model) do
    # Negative log probability of observation given model
    -:math.log(probability(observation, model))
  end

  @spec should_update?(surprise :: float(), threshold :: float()) :: boolean()
  def should_update?(surprise, threshold \\ 2.0) do
    surprise > threshold
  end
end
```

## 3.4 Phase 2 Deliverables

- [ ] 15 new library files
- [ ] 15 new test files
- [ ] 10 new STAMP constraints
- [ ] 12 Agda proofs
- [ ] 15 Quint models

---

# 4. PHASE 3: THRIVE - Economic Expansion

## 4.1 Objective
Implement internal resource auctions (Compute Credits) and Mycelial Mesh networking.

## 4.2 Files to Create/Modify

### 4.2.1 Compute Credits Economy (7 files)

```
lib/indrajaal/compute/
├── credits.ex               # CREATE - Compute credit system
├── wallet.ex                # CREATE - Agent wallets
├── auction.ex               # CREATE - Vickrey auction
├── pricing.ex               # CREATE - Dynamic pricing
├── budget.ex                # CREATE - Budget management
├── allocation.ex            # CREATE - Resource allocation
└── ledger.ex                # CREATE - Transaction ledger
```

### 4.2.2 Mycelial Mesh (6 files)

```
lib/indrajaal/distributed/mesh/
├── mycelium.ex              # CREATE - Mesh network core
├── gossip.ex                # CREATE - Gossip protocol
├── discovery.ex             # CREATE - Peer discovery
├── holography.ex            # CREATE - State holography
├── routing.ex               # CREATE - Message routing
└── partition.ex             # CREATE - Partition handling
```

### 4.2.3 Tests (13 files)

```
test/indrajaal/compute/
├── credits_test.exs
├── wallet_test.exs
├── auction_test.exs
├── pricing_test.exs
├── budget_test.exs
├── allocation_test.exs
└── ledger_test.exs

test/indrajaal/distributed/mesh/
├── mycelium_test.exs
├── gossip_test.exs
├── discovery_test.exs
├── holography_test.exs
├── routing_test.exs
└── partition_test.exs
```

## 4.3 Vickrey Auction Algorithm

```elixir
defmodule Indrajaal.Compute.Auction do
  @moduledoc """
  Vickrey (Second-Price Sealed-Bid) Auction for Compute Resources

  Properties:
  - Truthful bidding is dominant strategy
  - Winner pays second-highest bid
  - Efficient allocation

  ## STAMP Constraints
  - SC-AUC-001: All bids must be sealed
  - SC-AUC-002: Winner determination < 10ms
  - SC-AUC-003: Payment = second highest bid
  """

  @spec run_auction(resource :: atom(), bids :: [{agent_id, amount}]) ::
    {:winner, agent_id, payment} | {:no_bids}
  def run_auction(_resource, []), do: {:no_bids}
  def run_auction(_resource, [{winner, _amount}]), do: {:winner, winner, 0}
  def run_auction(_resource, bids) do
    sorted = Enum.sort_by(bids, fn {_, amount} -> amount end, :desc)
    [{winner, _highest}, {_, second_highest} | _] = sorted
    {:winner, winner, second_highest}
  end
end
```

## 4.4 Phase 3 Deliverables

- [ ] 13 new library files
- [ ] 13 new test files
- [ ] 8 new STAMP constraints
- [ ] 10 Agda proofs
- [ ] 12 Quint models

---

# 5. PHASE 4: EVOLVE - Nervous System

## 5.1 Objective
Implement F# CEPAF Grammar integration and Proprioceptive Entropy Heatmaps.

## 5.2 Files to Create/Modify

### 5.2.1 CEPAF Bridge (5 files)

```
lib/indrajaal/cepaf/
├── bridge.ex                # CREATE - Elixir ↔ F# bridge
├── grammar.ex               # CREATE - DSL grammar parsing
├── orchestrator.ex          # CREATE - Orchestration commands
├── genetic.ex               # CREATE - Genetic optimization
└── phenotype.ex             # CREATE - Config phenotypes
```

### 5.2.2 Proprioceptive Cockpit (6 files)

```
lib/indrajaal/cockpit/proprioceptive/
├── entropy.ex               # CREATE - Entropy calculation
├── heatmap.ex               # CREATE - Entropy heatmaps
├── particles.ex             # CREATE - Particle flow viz
├── dark_cockpit.ex          # CREATE - NASA-STD-3000 HMI
├── intent.ex                # CREATE - Intent parsing
└── feedback.ex              # CREATE - Haptic feedback
```

### 5.2.3 Tests (11 files)

```
test/indrajaal/cepaf/
├── bridge_test.exs
├── grammar_test.exs
├── orchestrator_test.exs
├── genetic_test.exs
└── phenotype_test.exs

test/indrajaal/cockpit/proprioceptive/
├── entropy_test.exs
├── heatmap_test.exs
├── particles_test.exs
├── dark_cockpit_test.exs
├── intent_test.exs
└── feedback_test.exs
```

## 5.3 Entropy Heatmap Algorithm

```elixir
defmodule Indrajaal.Cockpit.Proprioceptive.Entropy do
  @moduledoc """
  Shannon Entropy for System State Visualization

  H(X) = -Σ p(x) log₂ p(x)

  High entropy = Uncertainty/Chaos (Red)
  Low entropy = Order/Predictability (Green)
  """

  @spec calculate(events :: [map()]) :: float()
  def calculate(events) do
    events
    |> Enum.frequencies_by(& &1.type)
    |> Map.values()
    |> normalize()
    |> Enum.reduce(0.0, fn p, acc ->
      if p > 0, do: acc - p * :math.log2(p), else: acc
    end)
  end

  @spec to_color(entropy :: float(), max_entropy :: float()) :: {r, g, b}
  def to_color(entropy, max_entropy) do
    ratio = entropy / max_entropy
    # Green (low entropy) → Yellow → Red (high entropy)
    {round(255 * ratio), round(255 * (1 - ratio)), 0}
  end
end
```

## 5.4 Phase 4 Deliverables

- [ ] 11 new library files
- [ ] 11 new test files
- [ ] 8 new STAMP constraints
- [ ] 8 Agda proofs
- [ ] 10 Quint models

---

# 6. PHASE 5: TRANSCEND - Viral Autopoiesis

## 6.1 Objective
Launch the Jain Node protocol with Constitutional sterilization.

## 6.2 Files to Create/Modify

### 6.2.1 Jain Node (8 files)

```
lib/indrajaal/jain/
├── node.ex                  # CREATE - Self-bootstrapping node
├── genesis.ex               # CREATE - Genesis protocol
├── replication.ex           # CREATE - Viral replication
├── mutation.ex              # CREATE - Controlled mutation
├── sterilization.ex         # CREATE - Constitution enforcement
├── resource_acquisition.ex  # CREATE - Resource appropriation
├── dormancy.ex              # CREATE - Resource starvation handling
└── awakening.ex             # CREATE - Dormancy recovery
```

### 6.2.2 Federation (5 files)

```
lib/indrajaal/federation/
├── federation.ex            # CREATE - Multi-cluster federation
├── sovereignty.ex           # CREATE - Data sovereignty
├── treaty.ex                # CREATE - Inter-federation treaties
├── ambassador.ex            # CREATE - Federation ambassador
└── tribunal.ex              # CREATE - Dispute resolution
```

### 6.2.3 Tests (13 files)

```
test/indrajaal/jain/
├── node_test.exs
├── genesis_test.exs
├── replication_test.exs
├── mutation_test.exs
├── sterilization_test.exs
├── resource_acquisition_test.exs
├── dormancy_test.exs
└── awakening_test.exs

test/indrajaal/federation/
├── federation_test.exs
├── sovereignty_test.exs
├── treaty_test.exs
├── ambassador_test.exs
└── tribunal_test.exs
```

## 6.3 Sterilization Algorithm

```elixir
defmodule Indrajaal.Jain.Sterilization do
  @moduledoc """
  Constitutional Sterilization - Dead Man's Cryptography

  If constitution is modified:
  1. Hash changes
  2. Replication key becomes invalid
  3. Node cannot replicate (STERILE)

  This prevents "Grey Goo" scenarios where rogue nodes
  replicate without safety constraints.
  """

  alias Indrajaal.Core.Constitution

  @spec can_replicate?() :: boolean()
  def can_replicate? do
    case Constitution.verify() do
      {:verified, _hash} -> true
      {:violated, _invariant, _hash} -> false
    end
  end

  @spec derive_replication_key() :: {:ok, binary()} | {:error, :sterile}
  def derive_replication_key do
    case Constitution.verify() do
      {:verified, hash} ->
        # Key is deterministically derived from constitution hash
        key = :crypto.hash(:sha256, hash <> "replication_salt")
        {:ok, key}

      {:violated, _, _} ->
        {:error, :sterile}
    end
  end
end
```

## 6.4 Phase 5 Deliverables

- [ ] 13 new library files
- [ ] 13 new test files
- [ ] 10 new STAMP constraints
- [ ] 15 Agda proofs
- [ ] 18 Quint models

---

# 7. FILE-BY-FILE BREAKDOWN

## 7.1 Complete File List (127 files)

| Phase | Type | Count | Directory |
|-------|------|-------|-----------|
| 1 | Library | 17 | lib/indrajaal/core/ |
| 1 | Test | 17 | test/indrajaal/core/ |
| 2 | Library | 15 | lib/indrajaal/cybernetic/, observability/ |
| 2 | Test | 15 | test/indrajaal/cybernetic/, observability/ |
| 3 | Library | 13 | lib/indrajaal/compute/, distributed/ |
| 3 | Test | 13 | test/indrajaal/compute/, distributed/ |
| 4 | Library | 11 | lib/indrajaal/cepaf/, cockpit/ |
| 4 | Test | 11 | test/indrajaal/cepaf/, cockpit/ |
| 5 | Library | 13 | lib/indrajaal/jain/, federation/ |
| 5 | Test | 13 | test/indrajaal/jain/, federation/ |
| **Total** | **All** | **127** | |

## 7.2 Priority Order

```
CRITICAL PATH (Must be sequential):
1. constitution.ex → hash.ex → verifier.ex
2. holon.ex → protocol.ex → supervisor.ex
3. system5_policy.ex → system3_control.ex → system1_operations.ex

PARALLELIZABLE:
- All test files (after corresponding lib file)
- system2_coordination.ex, system4_intelligence.ex
- All Phase 3+ files (after Phase 2 complete)
```

---

# 8. DEPENDENCY GRAPH

```
                    ┌─────────────────────────┐
                    │     constitution.ex     │
                    │   (Immutable Axioms)    │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
       ┌──────────┐      ┌──────────┐      ┌──────────┐
       │  hash.ex │      │verifier.ex│     │dead_mans │
       └────┬─────┘      └────┬─────┘      └────┬─────┘
            │                 │                 │
            └────────────┬────┴─────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   holon.ex   │
                  │ (Core Atom)  │
                  └──────┬───────┘
                         │
      ┌──────────┬───────┼───────┬──────────┐
      │          │       │       │          │
      ▼          ▼       ▼       ▼          ▼
   ┌─────┐   ┌─────┐  ┌─────┐ ┌─────┐   ┌─────┐
   │ S1  │   │ S2  │  │ S3  │ │ S4  │   │ S5  │
   │ Ops │   │Coord│  │Ctrl │ │Intel│   │Policy│
   └─────┘   └─────┘  └─────┘ └─────┘   └─────┘
      │          │       │       │          │
      └──────────┴───────┴───────┴──────────┘
                         │
                         ▼
              ┌────────────────────┐
              │  active_inference  │
              │  (Phase 2: GROW)   │
              └─────────┬──────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
         ▼              ▼              ▼
   ┌───────────┐  ┌───────────┐  ┌───────────┐
   │ credits.ex│  │mycelium.ex│  │entropy.ex │
   │(Phase 3)  │  │(Phase 3)  │  │(Phase 4)  │
   └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
                        ▼
               ┌─────────────────┐
               │    jain/node    │
               │ (Phase 5: APEX) │
               └─────────────────┘
```

---

# 9. TEST STRATEGY

## 9.1 Test Types per Phase

| Phase | Unit | Property | Integration | E2E |
|-------|------|----------|-------------|-----|
| 1 | 34 | 12 | 6 | 2 |
| 2 | 30 | 15 | 8 | 3 |
| 3 | 26 | 10 | 6 | 2 |
| 4 | 22 | 8 | 4 | 2 |
| 5 | 26 | 12 | 8 | 4 |
| **Total** | **138** | **57** | **32** | **13** |

## 9.2 Property Tests Required

```elixir
# Constitution Properties
property "constitution hash is deterministic"
property "verification is idempotent"
property "modification detection is complete"

# Holon Properties
property "all holons have 5 systems"
property "health propagates correctly"
property "parent-child relationships are acyclic"

# VSM Properties
property "S3 budget is never exceeded"
property "S4 predictions converge"
property "S5 always enforces constitution"

# Jain Properties
property "sterile nodes cannot replicate"
property "replication preserves constitution"
property "mutations are bounded"
```

---

# 10. RISK MITIGATION

## 10.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Constitution bypass | Low | Critical | Compile-time guards, runtime assertions |
| Holon deadlock | Medium | High | Timeout enforcement, circuit breakers |
| Runaway replication | Low | Critical | Sterilization, rate limiting |
| Gossip storm | Medium | Medium | Hysteresis, backpressure |
| Event store overflow | Medium | Medium | Retention policy, archival |

## 10.2 Rollback Strategy

Each phase has a feature flag:
```elixir
config :indrajaal, :features,
  holon_protocol: true,      # Phase 1
  active_inference: false,   # Phase 2
  compute_credits: false,    # Phase 3
  proprioceptive: false,     # Phase 4
  jain_node: false           # Phase 5
```

---

# EXECUTION COMMANDS

```bash
# Phase 1: Create directory structure
mix phx.gen.context Core Holon holons --no-schema

# Run Phase 1 tests
MIX_ENV=test mix test test/indrajaal/core/

# Verify STAMP constraints
mix stamp.verify --phase 1

# Check coverage
MIX_ENV=test mix coveralls.html --filter lib/indrajaal/core/
```

---

# APPROVAL CHECKPOINT

**Ready to begin Phase 1: SEED?**

Phase 1 creates the foundational Holon Protocol and Constitution that all subsequent phases depend on. Estimated effort: 17 library files + 17 test files.

---

*Document generated by Claude Code for Indrajaal v20.0.0*
*Framework: SOPv5.11 + STAMP + TDG + GDE + VSM + Category Theory*
