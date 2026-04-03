# Indrajaal Fractal System Analysis & Test Plan

**Version**: 1.0.0 | **Date**: 2025-12-29T12:00:00+01:00 | **Status**: ACTIVE
**Goal**: Robust, Resilient, Evolvable, Adaptive, Scalable System
**Plan Reference**: `/home/an/.claude/plans/golden-strolling-tulip.md`

---

## Executive Summary

Comprehensive 5-level fractal analysis mapping all feature dimensions and capability vectors across self-similar architectural patterns. Identifies core/critical functionality at each layer with test strategy ensuring the system remains always functional.

---

## Part I: System State Assessment

### 1.1 Current Metrics

| Dimension | Count | Status |
|-----------|-------|--------|
| Domains | 101 | Active |
| Ash Resources | 773 | Deployed |
| Test Files | 791 | Maintained |
| STAMP Constraints | 242 | Verified |
| Agents | 50 (6+4 distributed) | Operational |
| Containers | 5-level strategy | Configured |
| Observability Modules | 78 | Integrated |

### 1.2 Maturity Assessment (TMMi Model)

| Level | Name | Current | Target |
|-------|------|---------|--------|
| L2 | Managed | PASSED | - |
| L3 | Defined | 85% | 100% |
| L4 | Measured | 60% | 100% |
| L5 | Optimization | IN PROGRESS | Target |

---

## Part II: 5-Level Fractal Architecture

### Level 1: System Context (L1-SYS)

**Feature Dimensions**:
- F1.1: External API Surface (Mobile, REST, WebSocket, GraphQL)
- F1.2: Authentication Boundary (JWT, MFA, Biometric)
- F1.3: Multi-Tenancy Isolation
- F1.4: Compliance Interface (IEC 61508, ISO 27001, GDPR)

**Capability Vectors**:
- CV1.1: Throughput (>50,000 events/sec)
- CV1.2: Availability (99.99% uptime)
- CV1.3: Latency (<50ms P95)
- CV1.4: Security (Zero CVE)

**Core Functionality** (MUST ALWAYS WORK):
- Authentication/Authorization
- Alarm Processing Pipeline
- Emergency Response Path

**Test Strategy**:
```
L1-TEST-001: E2E API contract tests
L1-TEST-002: Load tests - 10k concurrent users
L1-TEST-003: Chaos engineering - container failure
L1-TEST-004: Security penetration testing
```

---

### Level 2: Container Architecture (L2-CNT)

**Container Hierarchy**:
```
L2.1: Dev → L2.2: Testing → L2.3: Demo → L2.4: Production → L2.5: Mesh
```

**Feature Dimensions**:
- F2.1: Orchestration (Podman rootless)
- F2.2: Service Discovery (Tailscale mesh)
- F2.3: Load Balancing (Nginx)
- F2.4: Persistence (PostgreSQL 17 + TimescaleDB)
- F2.5: Observability (OTEL → SigNoz/Grafana)

**Capability Vectors**:
- CV2.1: Startup Time (<30s)
- CV2.2: Health Check (5s interval)
- CV2.3: Failover (<5s per SC-EMR-057)
- CV2.4: CPU Utilization (<70%)

**Core Containers**: indrajaal-app, indrajaal-db
**Critical Containers**: indrajaal-obs, indrajaal-redis

**Test Strategy**:
```
L2-TEST-001: Container health verification
L2-TEST-002: Startup/shutdown sequence
L2-TEST-003: Failover simulation (kill -9)
L2-TEST-004: Resource limit stress
L2-TEST-005: Network partition (Tailscale disconnect)
```

---

### Level 3: Domain Architecture (L3-DOM)

**5-Tier Domain Hierarchy**:

**Tier 1 - Foundation (MUST NEVER FAIL)**:
- Accounts, Authorization, Core

**Tier 2 - Processing (Core Business)**:
- Alarms, Devices, Sites, Video

**Tier 3 - Support (Business Ops)**:
- Dispatch, Communication, Compliance, Maintenance

**Tier 4 - Specialized (Value-Add)**:
- Analytics, Integration, Intelligence, Fleet

**Tier 5 - Infrastructure (Platform)**:
- Observability, Coordination, Cybernetic, Distributed

**Capability Vectors**:
- CV3.1: Action Latency (<10ms read, <50ms write)
- CV3.2: Policy Eval (<1ms)
- CV3.3: Tenant Isolation (zero leakage)

**Test Strategy**:
```
L3-TEST-001: Unit tests per resource action
L3-TEST-002: Policy authorization matrix
L3-TEST-003: Cross-domain integration
L3-TEST-004: Tenant isolation property tests
L3-TEST-005: Migration verification
```

---

### Level 4: Component Architecture (L4-CMP)

**Component Categories**:
- L4.1: Resources (Ash modules)
- L4.2: Contexts (business facades)
- L4.3: Services (stateless ops)
- L4.4: Workers (GenServers)
- L4.5: LiveViews (real-time UI)
- L4.6: Channels (WebSocket)
- L4.7: Plugs (middleware)

**Core Components** (Zero-defect):
- Authentication.Guardian
- Alarms.Processor
- Authorization.PolicyEngine

**Test Strategy**:
```
L4-TEST-001: Unit tests per function
L4-TEST-002: Property tests for invariants
L4-TEST-003: Integration tests for workflows
L4-TEST-004: Performance benchmarks
L4-TEST-005: Memory leak detection
```

---

### Level 5: Code Architecture (L5-COD)

**Code Categories**:
- L5.1: Pure Functions
- L5.2: Effectful Functions
- L5.3: Type Definitions
- L5.4: Protocols
- L5.5: Behaviours
- L5.6: Macros

**Quality Metrics**:
- LOC per function: <20
- Nesting depth: <4
- Parameters: <5
- Test coverage: >95%

**Test Strategy**:
```
L5-TEST-001: Doctest verification
L5-TEST-002: Dialyzer type specs
L5-TEST-003: Edge case unit tests
L5-TEST-004: Property-based invariants
L5-TEST-005: Mutation testing
```

---

## Part III: Cross-Cutting Dimensions

### 3.1 Observability (78 modules)
- L1: System dashboards → L5: Function telemetry

### 3.2 Security (28 constraints)
- L1: Perimeter (TLS) → L5: Code security

### 3.3 Resilience (Google Cloud Patterns)
- Chaos Engineering, Circuit Breakers, Bulkheads, Graceful Degradation

### 3.4 Evolvability
- API versioning, Schema migrations, Feature flags

---

## Part IV: STAMP Constraint Mapping (242 total)

| Category | Count | Levels |
|----------|-------|--------|
| SC-VAL | 15 | L4-L5 |
| SC-CNT | 18 | L2 |
| SC-AGT | 22 | L3-L4 |
| SC-SEC | 28 | L1-L5 |
| SC-PRF | 19 | L1-L4 |
| SC-EMR | 14 | L1-L3 |
| SC-OBS | 21 | L2-L4 |
| SC-DIST | 16 | L2-L3 |

---

## Part V: Test Execution Plan

### Test Pyramid
```
        /\  E2E (5%)
       /--\  Integration (15%)
      /----\  Component (25%)
     /------\  Unit + Property (55%)
```

### Execution Phases

**Phase 1: Fast Feedback (<5 min)**
- Compile, Format, Credo, Unit tests

**Phase 2: Verification (<30 min)**
- Property tests, Integration, Sobelow, Coverage

**Phase 3: Confidence (<2 hours)**
- E2E, Performance, Container, STAMP

**Phase 4: Resilience (Weekly)**
- Chaos, Failover, Load, Penetration

---

## Part VI: Quality Gates

| Gate | Metric | Target |
|------|--------|--------|
| Compilation | Errors + Warnings | 0 |
| Coverage | Line Coverage | >95% |
| Security | Sobelow Findings | 0 |
| Performance | P95 Latency | <50ms |
| Availability | Uptime | 99.99% |
| STAMP | Violations | 0 |

---

## Part VII: Implementation Roadmap

### Week 1-2: Foundation (L5)
- [ ] L5-TEST-001: Implement doctest verification
- [ ] L5-TEST-002: Add dialyzer type specs
- [ ] Achieve 95% coverage on Tier 1 domains

### Week 3-4: Component (L4)
- [ ] L4-TEST-001: Unit tests per function
- [ ] L4-TEST-002: Property tests for invariants
- [ ] L4-TEST-004: Performance benchmarks

### Week 5-6: Domain (L3)
- [ ] L3-TEST-001: Unit tests per resource
- [ ] L3-TEST-003: Cross-domain integration
- [ ] Verify all 242 STAMP constraints

### Week 7-8: Container (L2)
- [ ] L2-TEST-001: Container health verification
- [ ] L2-TEST-003: Failover simulation
- [ ] L2-TEST-005: Network partition tests

### Week 9-10: System (L1)
- [ ] L1-TEST-001: E2E API contract tests
- [ ] L1-TEST-002: Artillery load testing
- [ ] L1-TEST-004: Security penetration testing

---

## Part VIII: Exploration Summary

### Domain Architecture (Agent 1)
- 101 domains in 5-tier hierarchy
- 773 Ash resources
- RBAC + ABAC authorization

### Infrastructure (Agent 2)
- 5-level container strategy
- 78 observability modules
- 6 agents + 4 workers distributed

### Test Infrastructure (Agent 3)
- 791 test files
- 14 test categories
- 50 support modules

---

## Part IX: Research Sources

- **TMMi**: https://www.tmmi.org/
- **Google Cloud Resilience**: https://cloud.google.com/architecture/framework/reliability
- **IEC 61508 SIL-2**: Safety integrity level 2
- **ISO 27001**: Information security management
- **GDPR/DPDP**: Data protection compliance

---

## Part X: Critical File Paths

### Core Files (Zero-Defect)
```
lib/indrajaal/accounts/user.ex
lib/indrajaal/authorization/policy_engine.ex
lib/indrajaal/authentication/guardian.ex
lib/indrajaal/alarms/processor.ex
lib/indrajaal/core/base_resource.ex
```

### Test Support
```
test/support/data_case.ex
test/support/factory.ex
test/support/factories/*_factory.ex
```

---

## Part XI: Execution Commands

```bash
# Phase 1: Fast Feedback
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test --max-cases 16

# Phase 2: Verification
mix test --only property
mix test --only integration
mix sobelow --exit
mix coveralls.html

# Phase 3: Confidence
mix test --only e2e
mix test --only container
mix stamp.verify

# Phase 4: Resilience
elixir scripts/chaos/failure_injection.exs
artillery run scripts/performance/artillery-config.yml
```

---

## Part XII: Todo List Mapping

| Todo ID | Plan Section | Description |
|---------|--------------|-------------|
| T1 | VII.Week1-2 | L5 doctest verification |
| T2 | VII.Week1-2 | Dialyzer type specs |
| T3 | VII.Week1-2 | 95% Tier 1 coverage |
| T4 | VII.Week3-4 | L4 property tests |
| T5 | VII.Week3-4 | Performance benchmarks |
| T6 | VII.Week5-6 | L3 integration tests |
| T7 | VII.Week5-6 | STAMP verification |
| T8 | VII.Week7-8 | Failover tests |
| T9 | VII.Week7-8 | Network partition tests |
| T10 | VII.Week9-10 | E2E API tests |
| T11 | VII.Week9-10 | Artillery load tests |
| T12 | VII.Week9-10 | Security audit |

---

*Generated: 2025-12-29T12:00:00+01:00*
*Framework: SOPv5.11 + STAMP + TDG*
*Cybernetic Architect Session*
