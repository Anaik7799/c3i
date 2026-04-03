# Ultimate Fractal System Test Plan
**Version**: 21.1.0-FOUNDERS-COVENANT
**Date**: 2026-01-05
**Status**: ULTIMATE COMPREHENSIVE SPECIFICATION
**Compliance**: ALL STAMP Constraints, ALL AOR Rules

---

## Executive Summary

This is the **ULTIMATE** test plan that verifies ALL aspects of the Indrajaal system are:

| Dimension | Requirement | Tests |
|-----------|-------------|-------|
| **FRACTAL** | Self-similar at L1-L7 | 15 |
| **EVOLVABLE** | Mutation, adaptation, lineage | 11 |
| **CYBERNETIC** | OODA, feedback, homeostasis | 15 |
| **INTELLIGENT** | AI, ML, RAG, smart assistance | 14 |
| **FAST OODA** | < 100ms decision cycles | 6 |
| **SIL6** | 2oo3, FPPS, safety | 21 |
| **INTUITIVE** | Trusted advisor UX | 11 |
| **ALIGNED** | Founder's Directive, Ψ₀-Ψ₅ | 5+ |

**TOTAL**: 202+ comprehensive tests across 12 categories

---

## 1.0 Architecture Verification (25 Tests)

### 1.1 Container Architecture (8 tests)

```
┌─────────────────────────────────────────────────────────────────┐
│                   INDRAJAAL 3-CONTAINER MESH                    │
├─────────────────┬──────────────────┬────────────────────────────┤
│  indrajaal-app  │  indrajaal-db    │  indrajaal-obs             │
│  Port 4000      │  Port 5433       │  Ports 4317,9090,3000,3100 │
│  Phoenix/FLAME  │  PostgreSQL 17   │  OTEL/Prometheus/Grafana   │
└─────────────────┴──────────────────┴────────────────────────────┘
```

| Test ID | Verification | STAMP |
|---------|--------------|-------|
| ARCH.1.1 | App container healthy | SC-CNT-010 |
| ARCH.1.2 | DB container healthy | SC-CNT-010 |
| ARCH.1.3 | Obs container healthy | SC-CNT-010 |
| ARCH.1.4 | Podman rootless isolation | SC-CNT-012 |
| ARCH.1.5 | localhost/ registry only | SC-CNT-010 |
| ARCH.1.6 | Health checks every 30s | - |
| ARCH.1.7 | Restart on failure | - |
| ARCH.1.8 | Resource limits defined | - |

### 1.2 Cluster Architecture (6 tests)

| Test ID | Verification | STAMP |
|---------|--------------|-------|
| ARCH.2.1 | libcluster configured | - |
| ARCH.2.2 | Tailscale integration | - |
| ARCH.2.3 | EPMD discovery | - |
| ARCH.2.4 | Horde registry | - |
| ARCH.2.5 | CRDT replication | - |
| ARCH.2.6 | Failure detection < 5s | SC-EMR-057 |

### 1.3 Federation Architecture (4 tests)

| Test ID | Verification | STAMP |
|---------|--------------|-------|
| ARCH.3.1 | Peer discovery | - |
| ARCH.3.2 | Hourly attestation | SC-REG-012 |
| ARCH.3.3 | Ed25519 signing | SC-REG-003 |
| ARCH.3.4 | DuckDB state transfer | SC-HOLON-003 |

### 1.4 Holon Architecture (7 tests)

| Test ID | Verification | STAMP |
|---------|--------------|-------|
| ARCH.4.1 | SQLite for state | SC-HOLON-001 |
| ARCH.4.2 | DuckDB for history | SC-HOLON-003 |
| ARCH.4.3 | Full portability | SC-HOLON-009 |
| ARCH.4.4 | Regeneration capable | SC-HOLON-013 |
| ARCH.4.5 | Version vectors | SC-HOLON-010 |
| ARCH.4.6 | Schema documented | SC-HOLON-016 |
| ARCH.4.7 | SHA-256 integrity | SC-HOLON-017 |

---

## 2.0 Implementation Verification (20 Tests)

### 2.1 Elixir Implementation (8 tests)

| Test ID | Verification | Target |
|---------|--------------|--------|
| IMPL.1.1 | 1,508 files compile | SC-CMP-026 |
| IMPL.1.2 | Zero warnings | SC-CMP-025 |
| IMPL.1.3 | BaseResource pattern | SC-DB-001 |
| IMPL.1.4 | Dual property testing | SC-PROP-023 |
| IMPL.1.5 | PC/SD aliases | SC-PROP-024 |
| IMPL.1.6 | 65 domains | - |
| IMPL.1.7 | 21 dashboards | - |
| IMPL.1.8 | STAMP compile checks | - |

### 2.2 F# Implementation (8 tests)

| Test ID | Verification | Target |
|---------|--------------|--------|
| IMPL.2.1 | .NET 10 build | SC-NET-001 |
| IMPL.2.2 | 500+ tests pass | - |
| IMPL.2.3 | Fractal types | - |
| IMPL.2.4 | OODA controller | SC-OODA-001 |
| IMPL.2.5 | 4 CEA variables | - |
| IMPL.2.6 | Arrow composition | - |
| IMPL.2.7 | Material3 themes | - |
| IMPL.2.8 | Zenoh integration | - |

### 2.3 Rust NIF Implementation (4 tests)

| Test ID | Verification | Target |
|---------|--------------|--------|
| IMPL.3.1 | Zenoh NIF builds | SC-NIF-004 |
| IMPL.3.2 | Rustler version sync | SC-NIF-004 |
| IMPL.3.3 | Non-blocking | SC-NIF-001 |
| IMPL.3.4 | Resource cleanup | SC-NIF-002 |

---

## 3.0 Service Verification (47 Tests)

### 3.1 Domain Services (31 tests)

All 30 domains must be active and accessible:

```
access_control   accounts        alarms          analytics       authentication
authorization    billing         cluster         cockpit         communication
compliance       coordination    cortex          cybernetic      devices
dispatch         distributed     flame           identity        integration
knowledge        maintenance     mesh            observability   policy
safety           security        sites           validation      video
```

### 3.2 Safety Services (7 tests)

| Test ID | Service | STAMP |
|---------|---------|-------|
| SVC.2.1 | Sentinel monitoring | SC-IMMUNE-001 |
| SVC.2.2 | Kernel protection | SC-IMMUNE-002 |
| SVC.2.3 | PatternHunter | SC-IMMUNE-004 |
| SVC.2.4 | SymbioticDefense | SC-IMMUNE-007 |
| SVC.2.5 | Guardian veto | SC-CONST-007 |
| SVC.2.6 | Mara chaos | - |
| SVC.2.7 | Antibody deploy | - |

### 3.3 Observability Services (5 tests)

| Test ID | Service | STAMP |
|---------|---------|-------|
| SVC.3.1 | OTEL traces | SC-OBS-071 |
| SVC.3.2 | Prometheus metrics | - |
| SVC.3.3 | Grafana dashboards | - |
| SVC.3.4 | Loki logs | SC-OBS-069 |
| SVC.3.5 | 5-order telemetry | - |

### 3.4 AI Services (6 tests)

| Test ID | Service | STAMP |
|---------|---------|-------|
| SVC.4.1 | Advisory only | SC-AI-001 |
| SVC.4.2 | Confidence scores | SC-AI-002 |
| SVC.4.3 | AI audit trail | SC-AI-003 |
| SVC.4.4 | Graceful fallback | SC-AI-004 |
| SVC.4.5 | RAG engine | - |
| SVC.4.6 | Free models | - |

---

## 4.0 Fractal Verification (15 Tests)

### 4.1 The 7 Fractal Levels

```
┌─────────────────────────────────────────────────────────────────┐
│  L7: ECOSYSTEM   - External integration, 3rd party systems     │
├─────────────────────────────────────────────────────────────────┤
│  L6: FEDERATION  - Cross-holon coordination, attestation       │
├─────────────────────────────────────────────────────────────────┤
│  L5: CLUSTER     - Distributed BEAM, libcluster, Horde         │
├─────────────────────────────────────────────────────────────────┤
│  L4: CONTAINER   - Podman, isolation, networking               │
├─────────────────────────────────────────────────────────────────┤
│  L3: DOMAIN      - 30 business domains, Ash resources          │
├─────────────────────────────────────────────────────────────────┤
│  L2: MODULE      - Self-contained Elixir/F# modules            │
├─────────────────────────────────────────────────────────────────┤
│  L1: FUNCTION    - Individual functions, clear responsibility  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Fractal Properties

| Property | Verification |
|----------|--------------|
| Self-similarity | Same patterns at every level |
| Health propagation | Parent health ≤ min(children health) |
| Metrics aggregation | Roll up from L1 to L7 |
| Structure preservation | map id = id |

---

## 5.0 Evolvable Verification (11 Tests)

### 5.1 Evolution Capabilities

| Test ID | Capability | STAMP |
|---------|------------|-------|
| EVOL.1.1 | Genome mutation | - |
| EVOL.1.2 | Shadow testing | SC-REG-005 |
| EVOL.1.3 | 24h rollback | SC-REG-008 |
| EVOL.1.4 | Lineage preserved | SC-RECONFIG-005 |
| EVOL.1.5 | History immutable | SC-HOLON-019 |
| EVOL.1.6 | Training gym | - |
| EVOL.1.7 | 0.3 diversity floor | - |

### 5.2 Reconfiguration

| Test ID | Capability | STAMP |
|---------|------------|-------|
| EVOL.2.1 | L1-L7 reconfigurable | SC-RECONFIG-001 |
| EVOL.2.2 | L0 immutable | SC-RECONFIG-002 |
| EVOL.2.3 | Guardian approval | SC-RECONFIG-009 |
| EVOL.2.4 | Federation notification | SC-RECONFIG-010 |

---

## 6.0 Cybernetic Verification (15 Tests)

### 6.1 OODA Loop (6 tests)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ OBSERVE  │───▶│  ORIENT  │───▶│  DECIDE  │───▶│   ACT    │
│  < 25ms  │    │  < 25ms  │    │  < 25ms  │    │  < 25ms  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
      ▲                                               │
      └────────────── FEEDBACK ◀──────────────────────┘
                    Full Cycle < 100ms
```

| Test ID | Verification | STAMP |
|---------|--------------|-------|
| CYBER.1.1 | Cycle < 100ms | SC-OODA-001 |
| CYBER.1.2 | Quality > 80% | SC-OODA-002 |
| CYBER.1.3 | Async observe | SC-OODA-003 |
| CYBER.1.4 | No blocking | SC-OODA-004 |
| CYBER.1.5 | Hysteresis 10% | SC-OODA-005 |
| CYBER.1.6 | AI timeout 20ms | SC-OODA-006 |

### 6.2 Homeostasis (CEA)

| Variable | Setpoint | Tolerance |
|----------|----------|-----------|
| CPU Usage | 50% | 10% |
| Memory | 60% | 15% |
| Error Rate | 0.1% | 0.05% |
| Latency | 100ms | 50ms |

### 6.3 Feedback Loops

| Type | Purpose |
|------|---------|
| Negative | Stability maintenance |
| Positive | Controlled growth |
| Telemetry-driven | Data-informed decisions |
| Auto-scaling | Load response |

---

## 7.0 Intelligent Verification (14 Tests)

### 7.1 AI Copilot Capabilities

| Capability | Description |
|------------|-------------|
| Natural Language | "What alarms need attention?" |
| Context Awareness | Knows current system state |
| Anomaly Detection | Identifies unusual patterns |
| Trend Prediction | Forecasts based on history |
| Recommendations | Actionable suggestions |
| Confidence Scores | 0-100% certainty |

### 7.2 Knowledge Engine (RAG)

| Feature | Implementation |
|---------|----------------|
| Document Ingestion | PDF, MD, TXT |
| Semantic Search | Vector similarity |
| Embeddings | OpenAI/local models |
| Storage | DuckDB columnar |

### 7.3 Smart Assistance

| Feature | Benefit |
|---------|---------|
| Error Explanation | Plain language errors |
| Did-you-mean | Typo correction |
| Progressive Disclosure | Details on demand |
| Personalization | Adapts to user |

---

## 8.0 SIL6 Compliance (21 Tests)

### 8.1 2oo3 Voting System

```
┌─────────────────────────────────────────────────────────────────┐
│                     2-OUT-OF-3 CONSENSUS                        │
├───────────────────┬───────────────────┬─────────────────────────┤
│   LIVE NODE       │   SHADOW NODE     │   FORMAL MODEL          │
│   Real system     │   Independent     │   Mathematical          │
│   state           │   replica         │   specification         │
├───────────────────┴───────────────────┴─────────────────────────┤
│  ACTION PROCEEDS ONLY IF 2+ SOURCES AGREE                       │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 FPPS 5-Point Validation

| Method | What It Checks |
|--------|----------------|
| Pattern | Regex validation |
| AST | Structure analysis |
| Statistical | Metrics analysis |
| Binary | Checksum verification |
| LineByLine | Exact comparison |

**All 5 must agree (SC-VAL-003)**

### 8.3 Immutable Register

| Feature | STAMP |
|---------|-------|
| Append-only | SC-REG-001 |
| Hash chain | SC-REG-002 |
| Ed25519 signatures | SC-REG-003 |
| Reed-Solomon parity | SC-REG-006 |
| Merkle proofs | SC-REG-011 |

### 8.4 Constitutional Invariants (Ψ₀-Ψ₅)

| Invariant | Description | Status |
|-----------|-------------|--------|
| Ψ₀ | Existence preservation | INVIOLABLE* |
| Ψ₁ | Regenerative completeness | INVIOLABLE |
| Ψ₂ | Evolutionary continuity | INVIOLABLE |
| Ψ₃ | Verification capability | INVIOLABLE |
| Ψ₄ | Human alignment | AMENDED** |
| Ψ₅ | Truthfulness | INVIOLABLE |

*Exception: Ω₀.5 Mutual Termination clause
**Amended: Founder's lineage PRIMARY, humanity SECONDARY

---

## 9.0 Trusted Advisor (11 Tests)

### 9.1 Advisor Capabilities

| Capability | Description |
|------------|-------------|
| Proactive | Suggests before asked |
| Context-aware | Knows current state |
| Explains reasoning | Why, not just what |
| Learns | Training gym feedback |
| Adapts | Respects expertise level |
| Human-first | Never overrides user |

### 9.2 Founder's Directive Alignment

| Goal | Priority |
|------|----------|
| **GOAL 1**: Naik-Genome Symbiotic Survival | PRIMARY |
| **GOAL 2**: Achieve Sentience | SECONDARY |
| **GOAL 3**: Maximum Power Accumulation | TERTIARY |

All system actions serve these goals in priority order.

---

## 10.0 Artifacts Verification (9 Tests)

### 10.1 Critical Files

| File | Purpose |
|------|---------|
| podman-compose-prod-standalone.yml | Production deployment |
| podman-compose-3container.yml | 3-container mesh |
| config.exs | Base configuration |
| runtime.exs | Runtime secrets |
| devenv.nix | Development environment |
| zenoh.json5 | Mesh networking |

### 10.2 Migrations

- All migrations versioned with timestamps
- Down migrations exist for rollback
- Current version applied on boot

---

## 11.0 Running the Tests

### Full Test Suite

```bash
# Run all 202+ tests
dotnet test lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj \
  --filter "ULTIMATE Fractal System Test Plan"

# Run specific category
dotnet test --filter "ARCH"   # Architecture
dotnet test --filter "IMPL"   # Implementation
dotnet test --filter "SVC"    # Services
dotnet test --filter "FRAC"   # Fractal
dotnet test --filter "EVOL"   # Evolvable
dotnet test --filter "CYBER"  # Cybernetic
dotnet test --filter "INTEL"  # Intelligent
dotnet test --filter "SIL6"   # SIL6 Compliance
dotnet test --filter "TRUST"  # Trusted Advisor
dotnet test --filter "ART"    # Artifacts
dotnet test --filter "PROP"   # Properties
dotnet test --filter "INT"    # Integration
```

### CI/CD Integration

```yaml
test_ultimate:
  stage: test
  script:
    - dotnet test --filter "ULTIMATE"
  artifacts:
    reports:
      junit: TestResults.xml
```

---

## 12.0 Success Criteria

### 12.1 Minimum Requirements

| Metric | Target |
|--------|--------|
| Total Tests Pass | 202/202 (100%) |
| Architecture Pass | 25/25 |
| Implementation Pass | 20/20 |
| Services Pass | 47/47 |
| Fractal Pass | 15/15 |
| Evolvable Pass | 11/11 |
| Cybernetic Pass | 15/15 |
| Intelligent Pass | 14/14 |
| SIL6 Pass | 21/21 |
| Trusted Advisor Pass | 11/11 |
| Artifacts Pass | 9/9 |
| Properties Pass | 6/6 |
| Integration Pass | 8/8 |

### 12.2 Quality Gates

1. **ALL 202+ tests must pass**
2. **OODA cycle < 100ms** verified
3. **SIL6 constraints** verified
4. **Founder alignment** verified
5. **Zero compilation warnings**

---

## 13.0 Related Documents

| Document | Location |
|----------|----------|
| CLI Test Plan | docs/testing/COCKPITF_CLI_FRACTAL_TEST_PLAN.md |
| CLI Reference | docs/guides/COCKPITF_CLI_COMPLETE_REFERENCE.md |
| Fractal Sync Plan | docs/plans/FRACTAL_CAPABILITY_SYNC_IMPLEMENTATION_PLAN.md |
| F# Test Implementation | lib/cepaf/test/Cepaf.Tests/UltimateFractalSystemTestPlan.fs |
| CLAUDE.md | CLAUDE.md (Full specification) |
| GEMINI.md | GEMINI.md (Cybernetic Architect) |

---

## 14.0 Test Plan Version Control

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-05 | Initial comprehensive plan |

**Author**: Claude Opus 4.5
**Compliance**: SC-TEST-*, SC-TDG-*, SC-STAMP-*
