# 🌐 INTELITOR CONSOLIDATED TAILSCALE-FIRST IMPLEMENTATION PLAN

**Version**: 2.1.0-DETAILED-5-LEVEL
**Status**: 🟢 **READY**
**Date**: 2025-12-18
**Strategy**: Tailscale Foundation → Autonomic Evolution → Deep-Dive Implementation
**Sources**: 
- `docs/plans/20251218-deep-dive-implementation-plan.md`
- `docs/plans/20251218-autonomic-5level-plan.md`

## 22.0 - Tailscale-First Autonomic System Rollout (P1)
**Status**: pending | **Priority**: P1
**Description**: Consolidated master plan enforcing Tailscale networking as the absolute prerequisite foundation, followed by the complete autonomic system evolution.

### 22.1 - Phase 1: Tailscale Substrate Foundation (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.0
**Source**: `21.1` (Deep-Dive) Promoted
**Goal**: Establish the secure mesh network before any distributed components.

#### 22.1.1 - Container Infrastructure Physics (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.1
**Goal**: Physics layer - Enable WireGuard networking at OS/Container level.

##### 22.1.1.1 - Tailscale Binary Integration
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1

###### 22.1.1.1.1 - Add Tailscale to Dockerfile
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.1
**Action**: COPY tailscaled and tailscale binaries from official image.

###### 22.1.1.1.2 - Verify Binary Permissions
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.1
**Action**: Ensure binaries are executable in the container.

##### 22.1.1.2 - Boot Script Orchestration
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1

###### 22.1.1.2.1 - Create start_ha.sh
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.2
**Action**: Write script to launch tailscaled and authenticate.

###### 22.1.1.2.2 - Configure Tun Device
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.2
**Action**: Add --tun=userspace-networking flag.

##### 22.1.1.3 - Runtime Environment Configuration
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1

###### 22.1.1.3.1 - Update env.sh.eex
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.3
**Action**: Set RELEASE_NODE using tailscale ip.

###### 22.1.1.3.2 - Set Release Distribution
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.1.3
**Action**: Export RELEASE_DISTRIBUTION=name.

#### 22.1.2 - Cluster Discovery Strategy (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.1
**Goal**: Network layer - Configure `libcluster` for MagicDNS discovery.

##### 22.1.2.1 - Topology Configuration
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2

###### 22.1.2.1.1 - Update runtime.exs
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2.1
**Action**: Define libcluster topology using DNS strategy.

###### 22.1.2.1.2 - Define MagicDNS Hosts
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2.1
**Action**: List app-1, app-2, app-3 in host list.

##### 22.1.2.2 - EPMD Binding Security
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2

###### 22.1.2.2.1 - Configure vm.args
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2.2
**Action**: Add -kernel inet_dist_use_interface.

###### 22.1.2.2.2 - Verify Tailscale Interface
**Status**: pending | **Priority**: P1 | **Parent**: 22.1.2.2
**Action**: Ensure binding targets tailscale0 IP.

### 22.2 - Phase 2: Autonomic Core (Sprint 1) (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.0
**Source**: `20.1` (Autonomic Sprint 1)
**Prerequisite**: 22.1 Complete

#### 22.2.1 - OODA Loop Core Implementation (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.2
**Layer**: 5 (Cortex)

##### 22.2.1.1 - OODA Core Components
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1

###### 22.2.1.1.1 - Implement Loop GenServer
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1.1
**Action**: Create `lib/indrajaal/cybernetic/ooda/loop.ex`.

###### 22.2.1.1.2 - Implement Telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1.1
**Action**: Create `lib/indrajaal/cybernetic/ooda/telemetry.ex`.

##### 22.2.1.2 - Observer & Orientator Phases
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1

###### 22.2.1.2.1 - Implement Observer
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1.2
**Action**: Create `lib/indrajaal/cybernetic/ooda/observer.ex`.

###### 22.2.1.2.2 - Implement Orientator
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.1.2
**Action**: Create `lib/indrajaal/cybernetic/ooda/orientator.ex`.

#### 22.2.2 - Sentinel Safety Kernel (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.2
**Source**: `21.2` (Deep-Dive)

##### 22.2.2.1 - Sentinel Implementation
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2

###### 22.2.2.1.1 - Create Sentinel GenServer
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2.1
**Action**: `lib/indrajaal/cluster/sentinel.ex`.

###### 22.2.2.1.2 - Implement Node Logic
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2.1
**Action**: Monitor nodeup/nodedown events.

##### 22.2.2.2 - Apoptosis Protocol
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2

###### 22.2.2.2.1 - Implement Apoptosis
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2.2
**Action**: Create `initiate_apoptosis` function.

###### 22.2.2.2.2 - Implement Logging
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.2.2
**Action**: Log CRITICAL alert on partition.

#### 22.2.3 - FPPS 5-Method Validation (P1)
**Status**: pending | **Priority**: P1 | **Parent**: 22.2

##### 22.2.3.1 - FPPS Core & Consensus
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3

###### 22.2.3.1.1 - Implement Orchestrator
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3.1
**Action**: `lib/indrajaal/validation/fpps.ex`.

###### 22.2.3.1.2 - Implement Consensus
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3.1
**Action**: `lib/indrajaal/validation/consensus.ex`.

##### 22.2.3.2 - Validation Methods
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3

###### 22.2.3.2.1 - Implement Pattern Method
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3.2
**Action**: Regex-based validation.

###### 22.2.3.2.2 - Implement AST Method
**Status**: pending | **Priority**: P1 | **Parent**: 22.2.3.2
**Action**: Structural analysis validation.

### 22.3 - Phase 3: Elastic Infrastructure (Sprint 2) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.0
**Source**: `20.1.3` + `21.3` (FLAME)
**Prerequisite**: 22.2 Complete

#### 22.3.1 - FLAME Pools Supervisor (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.3

##### 22.3.1.1 - Supervisor Implementation
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1

###### 22.3.1.1.1 - Create Pools Supervisor
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1.1
**Action**: `lib/indrajaal/flame/pools.ex`.

###### 22.3.1.1.2 - Create Backend Config
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1.1
**Action**: `lib/indrajaal/flame/backend_config.ex`.

##### 22.3.1.2 - Domain Pools Definition
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1

###### 22.3.1.2.1 - Define Intelligence Pool
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1.2
**Action**: Max 10 runners.

###### 22.3.1.2.2 - Define Video Pool
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.1.2
**Action**: Max 20 runners.

#### 22.3.2 - Domain Integration ("Flame Pattern") (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.3

##### 22.3.2.1 - Intelligence Wrapper
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2

###### 22.3.2.1.1 - Create Wrapper
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2.1
**Action**: `lib/indrajaal/intelligence/entry.ex`.

###### 22.3.2.1.2 - Implement Call
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2.1
**Action**: Use FLAME.call.

##### 22.3.2.2 - State Safety Check
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2

###### 22.3.2.2.1 - Verify Local State
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2.2
**Action**: Ensure no Process.get usage.

###### 22.3.2.2.2 - Verify DB Access
**Status**: pending | **Priority**: P2 | **Parent**: 22.3.2.2
**Action**: Ensure runners fetch fresh data.

### 22.4 - Phase 4: Cognitive Integration (Sprint 3) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.0
**Source**: `20.2` (Integration)

#### 22.4.1 - Cortex Sensory System (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.4

##### 22.4.1.1 - Core Sensors
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1

###### 22.4.1.1.1 - Implement Base Sensor
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1.1
**Action**: `lib/indrajaal/cortex/sensor.ex`.

###### 22.4.1.1.2 - Implement Beam Sensor
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1.1
**Action**: Monitor VM metrics.

##### 22.4.1.2 - Stress Analysis
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1

###### 22.4.1.2.1 - Implement Analyzer
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1.2
**Action**: Calculate stress score.

###### 22.4.1.2.2 - Define Thresholds
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.1.2
**Action**: Set high/low water marks.

#### 22.4.2 - Reflex Systems (Circuit Breakers) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.4

##### 22.4.2.1 - Circuit Breaker Module
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2

###### 22.4.2.1.1 - Implement Breaker
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2.1
**Action**: Use :fuse library.

###### 22.4.2.1.2 - Configure Strategy
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2.1
**Action**: 5 failures in 60s.

##### 22.4.2.2 - External API Guard
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2

###### 22.4.2.2.1 - Identify APIs
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2.2
**Action**: List 3rd party calls.

###### 22.4.2.2.2 - Apply Guard
**Status**: pending | **Priority**: P2 | **Parent**: 22.4.2.2
**Action**: Wrap in breaker.

### 22.5 - Phase 5: Autonomic Completion (Sprint 4) (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.0
**Source**: `20.4` (Completion)

#### 22.5.1 - Cortex Homeostasis (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.5

##### 22.5.1.1 - Homeostasis Engine
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.1

###### 22.5.1.1.1 - Implement Controller
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.1.1
**Action**: Feedback loop logic.

###### 22.5.1.1.2 - Connect Actuators
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.1.1
**Action**: Link to FLAME/DB pools.

#### 22.5.2 - AI Interface (P2)
**Status**: pending | **Priority**: P2 | **Parent**: 22.5

##### 22.5.2.1 - Context Generator
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.2

###### 22.5.2.1.1 - Implement Interface
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.2.1
**Action**: Generate AI context prompt.

###### 22.5.2.1.2 - Format Proposals
**Status**: pending | **Priority**: P2 | **Parent**: 22.5.2.1
**Action**: JSON format for LLM.

#### 22.5.3 - Formal Verification (P3)
**Status**: pending | **Priority**: P3 | **Parent**: 22.5

##### 22.5.3.1 - Quint Specs
**Status**: pending | **Priority**: P3 | **Parent**: 22.5.3

###### 22.5.3.1.1 - Verify OODA
**Status**: pending | **Priority**: P3 | **Parent**: 22.5.3.1
**Action**: Model check OODA loop.

###### 22.5.3.1.2 - Verify Invariants
**Status**: pending | **Priority**: P3 | **Parent**: 22.5.3.1
**Action**: Check cybernetic invariants.