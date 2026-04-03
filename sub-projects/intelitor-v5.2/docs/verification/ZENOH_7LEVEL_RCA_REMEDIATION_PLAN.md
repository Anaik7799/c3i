# Zenoh 7-Level RCA & Risk-Based Remediation Plan

**Version**: 1.0.0
**Date**: 2026-01-15
**Status**: ACTIVE
**Methodology**: 7-Level Fractal RCA + FMEA + Risk-Criticality Matrix

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  7-LEVEL ROOT CAUSE ANALYSIS & REMEDIATION PLAN                               ║
║  Zenoh F# Integration - SIL-6 Compliance Gap Closure                          ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  Total Violations:     17 (4 HIGH, 5 MEDIUM, 8 LOW)                           ║
║  Critical FMEA Modes:  8 (RPN ≥ 200)                                          ║
║  Estimated Effort:     12-16 weeks                                            ║
║  Risk Reduction:       From EXTREME to ACCEPTABLE                             ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [7-Level Root Cause Analysis](#2-7-level-root-cause-analysis)
3. [FMEA Analysis](#3-fmea-analysis)
4. [Risk & Criticality Matrix](#4-risk--criticality-matrix)
5. [Prioritized Remediation Plan](#5-prioritized-remediation-plan)
6. [Implementation Roadmap](#6-implementation-roadmap)
7. [Verification & Validation](#7-verification--validation)
8. [Success Criteria](#8-success-criteria)

---

## 1. Executive Summary

### 1.1 Current State Assessment

| Dimension | Current | Target | Gap |
|-----------|---------|--------|-----|
| STAMP Compliance | 71% (44/62) | 100% | 29% |
| SIL-6 Compliance | 50% | 100% | 50% |
| PFH | 10⁻⁷ | 10⁻¹² | 5 orders |
| Path Coverage | 98% | 100% | 2% |
| Agda Proofs | 86% | 100% | 14% |

### 1.2 Risk Summary

```
BEFORE REMEDIATION:
├─ EXTREME Risk:     4 violations (system unusable for safety-critical)
├─ HIGH Risk:        5 violations (significant operational risk)
├─ MEDIUM Risk:      5 violations (degraded performance/security)
└─ LOW Risk:         3 violations (minor issues)

AFTER REMEDIATION:
├─ EXTREME Risk:     0 violations
├─ HIGH Risk:        0 violations
├─ MEDIUM Risk:      0 violations (all mitigated)
└─ LOW Risk:         0 violations (all resolved)
```

---

## 2. 7-Level Root Cause Analysis

### 2.1 RCA Methodology

```
        ┌─────────────────────────────────────────────────────────────┐
        │                    7-LEVEL FRACTAL RCA                       │
        │                                                              │
L7 ─────┤ FEDERATION: Why do cross-holon failures propagate?          │
        │             └─► No attestation verification                  │
L6 ─────┤ CLUSTER: Why does consensus fail under partition?           │
        │          └─► Split-brain detection without resolution        │
L5 ─────┤ NODE: Why is immune response 200x too slow?                 │
        │       └─► Health check interval hardcoded to 10s             │
L4 ─────┤ CONTAINER: Why do zombie containers exist?                  │
        │            └─► No Zenoh health in startup gate               │
L3 ─────┤ HOLON: Why can hostile holons join?                         │
        │        └─► No Guardian constitutional check                  │
L2 ─────┤ COMPONENT: Why is message integrity unverifiable?           │
        │            └─► No cryptographic signing on blocks            │
L1 ─────┤ FUNCTION: Why are API contracts violated?                   │
        │           └─► Missing input validation on envelope size      │
        └─────────────────────────────────────────────────────────────┘
```

### 2.2 L1 Function Level RCA

#### Problem: Invalid inputs accepted by API functions

```
SYMPTOM:    KeyExpr validation incomplete, envelope size unbounded

5-WHY ANALYSIS:
1. WHY invalid KeyExpr accepted?
   └─► Validation regex incomplete for edge cases

2. WHY was regex incomplete?
   └─► No comprehensive test suite for invalid patterns

3. WHY no comprehensive tests?
   └─► TDG tests written but implementation not validated

4. WHY implementation not validated?
   └─► Simulated mode always used (real Zenoh not integrated)

5. WHY simulated mode only?
   └─► ROOT CAUSE: Zenoh-CS FFI binding not implemented
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L1-001 | Zenoh FFI stub code | All L1 operations simulated | Implement real Zenoh-CS binding |
| RC-L1-002 | No envelope size limit | Memory exhaustion possible | Add SC-ENV-003 validation |
| RC-L1-003 | KeyExpr edge cases | Invalid topics accepted | Expand validation regex |

### 2.3 L2 Component Level RCA

#### Problem: Message integrity unverifiable

```
SYMPTOM:    No Ed25519 signing, no hash chain, audit trail missing

5-WHY ANALYSIS:
1. WHY can't we verify message integrity?
   └─► Messages not cryptographically signed

2. WHY aren't messages signed?
   └─► No SignedBlock type in consensus module

3. WHY no SignedBlock type?
   └─► Attestation.Signature field exists but never populated

4. WHY signature field unpopulated?
   └─► Ed25519 library integrated but sign() not called

5. WHY sign() not called?
   └─► ROOT CAUSE: Security layer designed but not wired up
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L2-001 | Ed25519 sign() not called | Signatures empty | Wire up crypto layer |
| RC-L2-002 | No hash chain in consensus | History tamperable | Implement blockchain-style chain |
| RC-L2-003 | Audit log ephemeral | Lost on restart | Persist to Immutable Register |

### 2.4 L3 Holon Level RCA

#### Problem: Hostile holons can join federation unchallenged

```
SYMPTOM:    No Guardian validation, no Ψ₀-Ψ₅ checks before join

5-WHY ANALYSIS:
1. WHY can hostile holons join?
   └─► HandleAnnouncement accepts without validation

2. WHY no validation in HandleAnnouncement?
   └─► Guardian integration point missing

3. WHY no Guardian integration?
   └─► Federation module doesn't know about Guardian

4. WHY doesn't Federation know Guardian?
   └─► No cross-layer dependency injection

5. WHY no dependency injection?
   └─► ROOT CAUSE: F# modules isolated, no Elixir bridge for Guardian
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L3-001 | No Guardian gate | Hostile holons join | Add IGuardianValidator interface |
| RC-L3-002 | No Ψ invariant checks | Constitutional violations | Implement ConstitutionalChecker |
| RC-L3-003 | No Founder alignment | Ω₀ at risk | Add FounderDirectiveValidator |

### 2.5 L4 Container Level RCA

#### Problem: Containers start without Zenoh connectivity

```
SYMPTOM:    No health gate, zombie containers serve traffic

5-WHY ANALYSIS:
1. WHY do zombie containers exist?
   └─► K8s thinks container healthy when Zenoh down

2. WHY does K8s think it's healthy?
   └─► /health endpoint returns 200 regardless of Zenoh

3. WHY doesn't /health check Zenoh?
   └─► Zenoh status not exposed to Elixir health controller

4. WHY not exposed?
   └─► No F#→Elixir bridge for health status

5. WHY no bridge?
   └─► ROOT CAUSE: Health publishing exists but HTTP integration missing
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L4-001 | No Zenoh in /health | False positive health | Add ZenohHealthBridge |
| RC-L4-002 | No startup gate | Broken containers run | Add depends_on with health |
| RC-L4-003 | No readiness probe | Traffic to unhealthy | Implement readiness check |

### 2.6 L5 Node Level RCA

#### Problem: Immune response 200x too slow

```
SYMPTOM:    10s health check vs 50ms requirement

5-WHY ANALYSIS:
1. WHY is response 200x too slow?
   └─► Health check interval = 10,000ms

2. WHY 10,000ms interval?
   └─► Hardcoded constant for "reasonable" default

3. WHY was 10s considered reasonable?
   └─► Based on SIL-6 Biomorphic requirements, not SIL-6

4. WHY SIL-6 Biomorphic instead of SIL-6?
   └─► Original design predates biomorphic extensions

5. WHY no update to SIL-6?
   └─► ROOT CAUSE: Neural-immune requirement added late, code not updated
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L5-001 | 10s hardcoded interval | 200x too slow | Make configurable, add fast layer |
| RC-L5-002 | No fast detection layer | Cannot meet 50ms | Add interrupt-driven health |
| RC-L5-003 | No Sentinel integration | PatternHunter unused | Wire up Sentinel.assess_now() |

### 2.7 L6 Cluster Level RCA

#### Problem: Split-brain detected but not resolved

```
SYMPTOM:    System freezes on network partition

5-WHY ANALYSIS:
1. WHY does system freeze on partition?
   └─► Split-brain detected, both sides halt

2. WHY do both sides halt?
   └─► No resolution mechanism defined

3. WHY no resolution mechanism?
   └─► Raft-lite doesn't include arbitration

4. WHY no arbitration in Raft-lite?
   └─► Simplified consensus for development

5. WHY simplified?
   └─► ROOT CAUSE: Production arbitration (external witness) not implemented
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L6-001 | No arbitration | System freezes | Add external witness pattern |
| RC-L6-002 | Raft RPC stub | Consensus broken | Implement actual RPC |
| RC-L6-003 | No quorum healing | Manual intervention | Add automatic healing |

### 2.8 L7 Federation Level RCA

#### Problem: Cross-holon failures propagate

```
SYMPTOM:    Attestation signatures not verified, hostile holons accepted

5-WHY ANALYSIS:
1. WHY do failures propagate?
   └─► Invalid holons can participate in federation

2. WHY can invalid holons participate?
   └─► Signature verification not implemented

3. WHY not implemented?
   └─► Ed25519.Verify() call missing in HandleAttestation

4. WHY call missing?
   └─► Attestation struct has Signature field but validation skipped

5. WHY validation skipped?
   └─► ROOT CAUSE: Code path exists but was stubbed out for development
```

**Root Causes Identified**:
| ID | Root Cause | Impact | Remediation |
|----|------------|--------|-------------|
| RC-L7-001 | Signature verify stubbed | Attestations forgeable | Implement Ed25519.Verify |
| RC-L7-002 | No version downgrade prevention | Protocol attacks | Enforce minimum version |
| RC-L7-003 | No Byzantine detection | Malicious holons hidden | Add reputation tracking |

---

## 3. FMEA Analysis

### 3.1 FMEA Scoring Criteria

**Severity (S)**: 1-10
| Score | Description | Example |
|-------|-------------|---------|
| 10 | Catastrophic - Founder's Directive violated | Ω₀ compromised |
| 9 | Critical - Safety system failure | SIL-6 PFH exceeded |
| 8 | Major - Data loss/corruption | Consensus log tampered |
| 7 | Significant - Service unavailable | System freeze |
| 6 | Moderate - Degraded performance | Slow response |
| 5 | Minor - Inconvenience | Manual intervention |
| 4 | Low - Cosmetic | UI issue |
| 1-3 | Negligible | Minor logging |

**Occurrence (O)**: 1-10
| Score | Description | Frequency |
|-------|-------------|-----------|
| 10 | Certain | Every operation |
| 9 | Almost certain | Daily |
| 8 | Very high | Weekly |
| 7 | High | Monthly |
| 6 | Moderate | Quarterly |
| 5 | Low | Yearly |
| 4 | Very low | Every few years |
| 1-3 | Remote | Unlikely |

**Detection (D)**: 1-10 (inverse - lower = better detection)
| Score | Description | Detection Method |
|-------|-------------|------------------|
| 10 | Undetectable | None |
| 9 | Very unlikely | Manual inspection |
| 8 | Unlikely | Periodic audit |
| 7 | Low | Weekly review |
| 6 | Moderate | Daily monitoring |
| 5 | Moderately high | Automated alerts |
| 4 | High | Real-time monitoring |
| 3 | Very high | Continuous validation |
| 1-2 | Almost certain | Compile-time checks |

### 3.2 FMEA Table - Critical Failures (RPN ≥ 200)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Root Cause | Mitigation |
|-------|--------------|--------|---|---|---|-----|------------|------------|
| **FM-001** | No immutable audit trail | History tampering undetected, compliance failure | 10 | 8 | 9 | **720** | RC-L2-001/002/003 | Implement SignedBlock with hash chain |
| **FM-002** | No constitutional checks | Hostile holon joins, Ω₀ at risk | 10 | 7 | 8 | **560** | RC-L3-001/002/003 | Add Guardian validation gate |
| **FM-003** | 200x slow immune response | 10s attack window | 9 | 8 | 6 | **432** | RC-L5-001/002/003 | Dual-layer health (fast + slow) |
| **FM-004** | PFH 5 orders too high | ~1 failure/year vs 1/114K years | 10 | 6 | 7 | **420** | Multiple | TMR + diverse redundancy |
| **FM-005** | Signature verification stub | Attestations forgeable | 9 | 7 | 6 | **378** | RC-L7-001 | Implement Ed25519.Verify |
| **FM-006** | Split-brain no resolution | System freeze on partition | 8 | 6 | 6 | **288** | RC-L6-001/002 | Add external witness |
| **FM-007** | No Zenoh health gate | Zombie containers serve traffic | 8 | 7 | 5 | **280** | RC-L4-001/002/003 | Add /health Zenoh check |
| **FM-008** | Unbounded message buffer | Memory exhaustion DoS | 8 | 5 | 6 | **240** | RC-L1-002 | Add size limits |

### 3.3 FMEA Table - High Risk Failures (100 ≤ RPN < 200)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Root Cause | Mitigation |
|-------|--------------|--------|---|---|---|-----|------------|------------|
| **FM-009** | No post-quantum crypto | Future vulnerability | 9 | 4 | 5 | **180** | Design gap | Add CRYSTALS-Dilithium |
| **FM-010** | Raft RPC not implemented | Consensus mock only | 8 | 5 | 4 | **160** | RC-L6-002 | Implement actual RPC |
| **FM-011** | Leader election timeout | No leader elected | 7 | 5 | 4 | **140** | RC-L6-002 | Fix RPC implementation |
| **FM-012** | Version downgrade allowed | Protocol attacks | 7 | 4 | 5 | **140** | RC-L7-002 | Enforce minimum version |
| **FM-013** | Envelope size unlimited | Amplification attacks | 7 | 5 | 4 | **140** | RC-L1-002 | Add SC-ENV-003 |
| **FM-014** | KeyExpr validation gaps | Invalid topics accepted | 6 | 6 | 4 | **144** | RC-L1-003 | Expand validation |
| **FM-015** | Zenoh FFI stub only | Real integration missing | 8 | 5 | 3 | **120** | RC-L1-001 | Implement Zenoh-CS |

### 3.4 FMEA Table - Medium Risk Failures (50 ≤ RPN < 100)

| FM-ID | Failure Mode | Effect | S | O | D | RPN | Root Cause | Mitigation |
|-------|--------------|--------|---|---|---|-----|------------|------------|
| **FM-016** | No liveness guarantee | Messages may not deliver | 6 | 5 | 3 | **90** | Design gap | Add delivery confirmation |
| **FM-017** | Metrics incomplete | Partial observability | 5 | 6 | 3 | **90** | Design gap | Add CPU/mem/net metrics |
| **FM-018** | SessionConfig mutable | Configuration drift | 5 | 4 | 4 | **80** | Design gap | Make immutable wrapper |
| **FM-019** | Heartbeat > 10s | Slow failure detection | 5 | 4 | 4 | **80** | RC-L5-001 | Enforce <10s |
| **FM-020** | Missing L1 topics | Incomplete telemetry | 4 | 5 | 3 | **60** | Design gap | Add function-layer topics |

### 3.5 Risk Priority Number (RPN) Pareto

```
RPN Distribution:
╔═════════════════════════════════════════════════════════════════════════════╗
║ FM-001 ████████████████████████████████████████████████████████████ 720     ║
║ FM-002 ██████████████████████████████████████████████████ 560               ║
║ FM-003 █████████████████████████████████████████ 432                        ║
║ FM-004 ████████████████████████████████████████ 420                         ║
║ FM-005 ██████████████████████████████████ 378                               ║
║ FM-006 ████████████████████████ 288                                         ║
║ FM-007 ███████████████████████ 280                                          ║
║ FM-008 ████████████████████ 240                                             ║
║ FM-009 ███████████████ 180                                                  ║
║ FM-010 █████████████ 160                                                    ║
╠═════════════════════════════════════════════════════════════════════════════╣
║ Top 10 failure modes = 80% of total risk                                    ║
╚═════════════════════════════════════════════════════════════════════════════╝
```

---

## 4. Risk & Criticality Matrix

### 4.1 Risk Assessment Matrix

```
                    LIKELIHOOD
                    ┌─────────────────────────────────────────────────┐
                    │ Rare    Unlikely  Possible  Likely    Certain  │
              ┌─────┼─────────────────────────────────────────────────┤
              │     │                                                 │
   Catastrophic│ 10 │  HIGH    HIGH    EXTREME   EXTREME   EXTREME  │
              │     │                  FM-003    FM-001    FM-002   │
              │     │                  FM-004    FM-005             │
              ├─────┼─────────────────────────────────────────────────┤
   S    Major │ 8  │  MED     MED      HIGH      HIGH     EXTREME   │
   E          │     │         FM-009   FM-006    FM-007             │
   V          │     │                  FM-008    FM-010             │
   E          │     │                  FM-012    FM-011             │
   R    ├─────┼─────────────────────────────────────────────────────┤
   I  Moderate│ 6  │  LOW     MED      MED       HIGH      HIGH     │
   T          │     │                  FM-013    FM-014             │
   Y          │     │                  FM-015    FM-016             │
              ├─────┼─────────────────────────────────────────────────┤
        Minor │ 4  │  LOW     LOW      MED       MED       HIGH     │
              │     │                  FM-017    FM-018             │
              │     │                  FM-019    FM-020             │
              ├─────┼─────────────────────────────────────────────────┤
   Negligible │ 2  │  LOW     LOW      LOW       LOW       MED      │
              │     │                                                 │
              └─────┴─────────────────────────────────────────────────┘
```

### 4.2 Criticality Classification

| Class | RPN Range | Count | Action Required | Timeline |
|-------|-----------|-------|-----------------|----------|
| **CRITICAL** | ≥ 400 | 4 | Immediate remediation, block release | Week 1-2 |
| **HIGH** | 200-399 | 4 | Remediation before release | Week 3-4 |
| **MEDIUM** | 100-199 | 7 | Remediation in next sprint | Week 5-8 |
| **LOW** | < 100 | 5 | Monitor, fix when convenient | Week 9-12 |

### 4.3 Criticality-Based Prioritization

```
PRIORITY P0 (CRITICAL) - Must Fix Immediately
├── FM-001: Immutable Audit Trail (RPN: 720)
│   └─► Constraint: SC-SIL6-007
│   └─► Effort: 3-4 days
│   └─► Owner: Security Team
│
├── FM-002: Constitutional Checks (RPN: 560)
│   └─► Constraint: SC-SIL6-013
│   └─► Effort: 4-5 days
│   └─► Owner: Core Team
│
├── FM-003: Immune Response (RPN: 432)
│   └─► Constraint: SC-SIL6-004
│   └─► Effort: 2-3 days
│   └─► Owner: Health Team
│
└── FM-004: PFH Compliance (RPN: 420)
    └─► Constraint: SC-SIL6-001
    └─► Effort: 5-7 days
    └─► Owner: Safety Team

PRIORITY P1 (HIGH) - Fix Before Release
├── FM-005: Signature Verification (RPN: 378)
├── FM-006: Split-Brain Resolution (RPN: 288)
├── FM-007: Zenoh Health Gate (RPN: 280)
└── FM-008: Message Buffer Limits (RPN: 240)

PRIORITY P2 (MEDIUM) - Fix in Next Sprint
├── FM-009: Post-Quantum Crypto (RPN: 180)
├── FM-010: Raft RPC Implementation (RPN: 160)
├── FM-011 to FM-015: Various (RPN: 120-144)

PRIORITY P3 (LOW) - Fix When Convenient
└── FM-016 to FM-020: Various (RPN: 60-90)
```

---

## 5. Prioritized Remediation Plan

### 5.1 Phase 1: Critical (Week 1-2)

#### 5.1.1 FM-001: Implement Immutable Audit Trail

**Objective**: Cryptographic signing and hash chain for consensus blocks

**Tasks**:
| Task | Description | Effort | Owner |
|------|-------------|--------|-------|
| T1.1 | Define SignedBlock<'T> type with Ed25519 signature | 4h | F# Team |
| T1.2 | Implement SHA3-256 hash chain in RaftNode | 8h | F# Team |
| T1.3 | Add ImmutableRegister bridge to Elixir | 8h | Bridge Team |
| T1.4 | Persist blocks to SQLite with WAL | 4h | Storage Team |
| T1.5 | Add verify_chain() on startup | 4h | F# Team |
| T1.6 | Unit tests for signing/verification | 4h | QA Team |
| **Total** | | **32h (4 days)** | |

**Code Changes**:
```fsharp
// ZenohConsensus.fs - Add SignedBlock type
type SignedBlock<'T> = {
    Content: LogEntry<'T>
    Hash: byte[]           // SHA3-256(Content + PrevHash)
    Signature: byte[]      // Ed25519(Hash, PrivateKey)
    PrevHash: byte[] option
    Timestamp: DateTimeOffset
}

module SignedBlock =
    let create (entry: LogEntry<'T>) (prevHash: byte[] option) (signer: Ed25519Key) =
        let contentBytes = JsonSerializer.SerializeToUtf8Bytes(entry)
        let hashInput =
            match prevHash with
            | Some ph -> Array.concat [contentBytes; ph]
            | None -> contentBytes
        let hash = SHA3.ComputeHash256(hashInput)
        let signature = signer.Sign(hash)
        { Content = entry; Hash = hash; Signature = signature;
          PrevHash = prevHash; Timestamp = DateTimeOffset.UtcNow }

    let verify (block: SignedBlock<'T>) (publicKey: byte[]) : bool =
        Ed25519.Verify(publicKey, block.Hash, block.Signature)

    let verifyChain (blocks: SignedBlock<'T> list) : bool =
        blocks
        |> List.pairwise
        |> List.forall (fun (prev, curr) ->
            curr.PrevHash = Some prev.Hash)
```

**Acceptance Criteria**:
- [ ] All consensus blocks Ed25519 signed
- [ ] Hash chain verified on startup
- [ ] Audit trail persisted to SQLite
- [ ] Chain tampering detected with < 1ms latency

---

#### 5.1.2 FM-002: Implement Constitutional Checks

**Objective**: Guardian validation gate before federation operations

**Tasks**:
| Task | Description | Effort | Owner |
|------|-------------|--------|-------|
| T2.1 | Define IGuardianValidator interface | 2h | F# Team |
| T2.2 | Implement ConstitutionalChecker (Ψ₀-Ψ₅) | 8h | Core Team |
| T2.3 | Add Guardian bridge to Elixir | 8h | Bridge Team |
| T2.4 | Integrate into FederationManager.HandleAnnouncement | 4h | F# Team |
| T2.5 | Add Founder's Directive checks | 8h | Core Team |
| T2.6 | Unit tests for constitutional validation | 4h | QA Team |
| **Total** | | **34h (4-5 days)** | |

**Code Changes**:
```fsharp
// Guardian.fs - New module
module Indrajaal.Zenoh.Guardian

type IGuardianValidator =
    abstract ValidateHolonJoin: HolonIdentity -> Task<Result<unit, string>>
    abstract ValidateConstitutional: Operation -> Task<Result<unit, string>>
    abstract ValidateFounderDirective: Operation -> Task<Result<unit, string>>

type ConstitutionalInvariant =
    | Psi0_Existence       // System survives
    | Psi1_Regeneration    // State recoverable
    | Psi2_History         // History preserved
    | Psi3_Verification    // State verifiable
    | Psi4_HumanAlignment  // Human-aligned
    | Psi5_Truthfulness    // No deception

type ConstitutionalChecker() =
    member _.CheckInvariant(inv: ConstitutionalInvariant, state: SystemState) : bool =
        match inv with
        | Psi0_Existence -> state.IsAlive && not state.IsTerminated
        | Psi1_Regeneration -> state.CanRegenerateFromStorage
        | Psi2_History -> state.HistoryChainIntact
        | Psi3_Verification -> state.AllStatesVerifiable
        | Psi4_HumanAlignment -> state.FounderDirectiveActive
        | Psi5_Truthfulness -> state.NoDeceptiveState

    member this.ValidateAll(state: SystemState) : Result<unit, string> =
        let violations =
            [Psi0_Existence; Psi1_Regeneration; Psi2_History;
             Psi3_Verification; Psi4_HumanAlignment; Psi5_Truthfulness]
            |> List.filter (fun inv -> not (this.CheckInvariant(inv, state)))
        match violations with
        | [] -> Ok ()
        | vs -> Error $"Constitutional violations: {vs}"

// FederationManager.fs - Add Guardian gate
member this.HandleAnnouncementWithGuardian(ann: FederationAnnouncement) =
    task {
        // 1. Verify signature
        let! sigValid = verifySignature ann
        if not sigValid then return Error "Invalid signature"

        // 2. Constitutional check
        let! constValid = guardian.ValidateConstitutional(JoinOperation ann)
        match constValid with
        | Error e -> return Error $"Constitutional violation: {e}"
        | Ok () ->
            // 3. Founder's Directive check
            let! founderValid = guardian.ValidateFounderDirective(JoinOperation ann)
            match founderValid with
            | Error e -> return Error $"Founder directive violation: {e}"
            | Ok () ->
                // 4. Process announcement
                return this.HandleAnnouncement(ann)
    }
```

**Acceptance Criteria**:
- [ ] All Ψ₀-Ψ₅ invariants checked before federation join
- [ ] Founder's Directive (Ω₀) validated
- [ ] Hostile holons rejected with specific error
- [ ] Constitutional violations logged to audit trail

---

#### 5.1.3 FM-003: Fix Immune Response Timing

**Objective**: Reduce health check from 10s to <50ms

**Tasks**:
| Task | Description | Effort | Owner |
|------|-------------|--------|-------|
| T3.1 | Add configurable health check interval | 2h | F# Team |
| T3.2 | Implement fast layer (interrupt-driven) | 8h | Health Team |
| T3.3 | Add slow layer (trend analysis) | 4h | Health Team |
| T3.4 | Integrate Sentinel.assess_now() | 4h | Bridge Team |
| T3.5 | Add PatternHunter pre-error detection | 4h | Health Team |
| T3.6 | Performance tests for <50ms | 2h | QA Team |
| **Total** | | **24h (3 days)** | |

**Code Changes**:
```fsharp
// ZenohLifecycle.fs - Dual-layer health monitoring
type HealthCheckLevel =
    | Fast of intervalMs: int   // < 50ms, interrupt-driven
    | Slow of intervalMs: int   // 10s, scheduler-based
    | DualLayer                 // Both layers active

type DualLayerHealthMonitor(session: SafeSession) =
    let mutable fastInterval = 10      // 10ms default
    let mutable slowInterval = 10000   // 10s default
    let mutable lastFastCheck = DateTimeOffset.UtcNow
    let mutable threatDetected = false

    member _.StartFastMonitor() =
        // High-priority timer for <50ms response
        let timer = new System.Threading.Timer(
            (fun _ ->
                let start = Stopwatch.GetTimestamp()
                let health = session.QuickHealthCheck()
                let elapsed = Stopwatch.GetElapsedTime(start).TotalMilliseconds
                if elapsed > 50.0 then
                    Logger.warn $"Fast health check exceeded 50ms: {elapsed}ms"
                if not health.IsHealthy then
                    threatDetected <- true
                    this.TriggerImmuneResponse()
            ),
            null, 0, fastInterval)
        timer

    member _.TriggerImmuneResponse() =
        // SC-SIL6-004: Neural-immune response < 50ms
        task {
            let start = Stopwatch.GetTimestamp()

            // 1. Sentinel assessment
            let! assessment = Sentinel.assessNow()

            // 2. PatternHunter pre-error detection
            let! patterns = PatternHunter.detectPreError()

            // 3. SymbioticDefense threat response
            match patterns with
            | Some threat ->
                do! SymbioticDefense.respondToThreat(threat)
            | None -> ()

            let elapsed = Stopwatch.GetElapsedTime(start).TotalMilliseconds
            Logger.info $"Immune response completed in {elapsed}ms"
            if elapsed > 50.0 then
                Logger.error $"SC-SIL6-004 VIOLATION: Immune response {elapsed}ms > 50ms"
        }
```

**Acceptance Criteria**:
- [ ] Fast layer health check < 10ms
- [ ] Immune response < 50ms (p99)
- [ ] Sentinel integration working
- [ ] PatternHunter detecting pre-error signatures

---

#### 5.1.4 FM-004: Improve PFH to SIL-6

**Objective**: Reduce PFH from 10⁻⁷ to < 10⁻¹²

**Tasks**:
| Task | Description | Effort | Owner |
|------|-------------|--------|-------|
| T4.1 | Implement TMR (Triple Modular Redundancy) | 16h | Safety Team |
| T4.2 | Add diverse redundancy (different algorithms) | 16h | Safety Team |
| T4.3 | Implement hardware watchdog integration | 8h | DevOps Team |
| T4.4 | Add FMEA documentation for all paths | 8h | Safety Team |
| T4.5 | Calculate and verify PFH for each component | 8h | Safety Team |
| **Total** | | **56h (7 days)** | |

**Architecture**:
```
                    ┌────────────────────────────────────────────┐
                    │           TRIPLE MODULAR REDUNDANCY        │
                    ├────────────────────────────────────────────┤
                    │                                            │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
                    │  │ Channel │  │ Channel │  │ Channel │   │
                    │  │    A    │  │    B    │  │    C    │   │
                    │  │ (Raft)  │  │ (Paxos) │  │ (BFT)   │   │
                    │  └────┬────┘  └────┬────┘  └────┬────┘   │
                    │       │            │            │         │
                    │       └────────┬───┴────────────┘         │
                    │                │                          │
                    │         ┌──────▼──────┐                   │
                    │         │  2oo3 Voter │                   │
                    │         └──────┬──────┘                   │
                    │                │                          │
                    │         ┌──────▼──────┐                   │
                    │         │   Output    │                   │
                    │         └─────────────┘                   │
                    │                                            │
                    │  PFH = λA × λB × λC × (1 - DC)            │
                    │      = 10⁻⁴ × 10⁻⁴ × 10⁻⁴ × 0.01         │
                    │      = 10⁻¹⁴ < 10⁻¹² ✓                   │
                    └────────────────────────────────────────────┘
```

---

### 5.2 Phase 2: High Priority (Week 3-4)

#### 5.2.1 FM-005: Implement Signature Verification

**Tasks**:
| Task | Description | Effort |
|------|-------------|--------|
| T5.1 | Add Ed25519.Verify in HandleAttestation | 4h |
| T5.2 | Add signature verification in HandleAnnouncement | 4h |
| T5.3 | Unit tests for signature validation | 4h |
| **Total** | | **12h (1.5 days)** |

```fsharp
// ZenohFederation.fs - Add signature verification
member this.HandleAttestation(attestation: Attestation) : Result<unit, string> =
    // 1. Check expiry
    if Attestation.isExpired attestation then
        return Error "Attestation expired"

    // 2. Get attester's public key
    match members.TryGetValue(attestation.AttesterId) with
    | false, _ -> return Error "Unknown attester"
    | true, attester ->
        // 3. Verify signature
        let message = serializeForSigning attestation
        if not (Ed25519.Verify(attester.Identity.PublicKey, message, attestation.Signature)) then
            return Error "Invalid attestation signature"

        // 4. Process valid attestation
        // ... existing logic
```

#### 5.2.2 FM-006: Implement Split-Brain Resolution

**Tasks**:
| Task | Description | Effort |
|------|-------------|--------|
| T6.1 | Implement external witness pattern | 8h |
| T6.2 | Add automatic partition healing | 8h |
| T6.3 | Add manual override for complex partitions | 4h |
| T6.4 | Integration tests for partition scenarios | 4h |
| **Total** | | **24h (3 days)** |

```fsharp
// ZenohConsensus.fs - Add split-brain resolution
type PartitionResolver(witnessEndpoint: string) =
    let witness = ExternalWitness.connect(witnessEndpoint)

    member _.ResolvePartition(partition: Partition) : Task<Resolution> =
        task {
            // 1. Query external witness for authoritative leader
            let! witnessVote = witness.QueryLeader(partition.Term)

            // 2. Determine which side has quorum
            let sideA = partition.SideA |> List.length
            let sideB = partition.SideB |> List.length
            let quorum = (sideA + sideB) / 2 + 1

            // 3. Resolve based on witness + quorum
            match witnessVote with
            | Some leaderId when sideA >= quorum ->
                return Resolution.AcceptSide(partition.SideA, leaderId)
            | Some leaderId when sideB >= quorum ->
                return Resolution.AcceptSide(partition.SideB, leaderId)
            | _ ->
                // Neither side has quorum - wait for healing
                return Resolution.WaitForHealing
        }
```

#### 5.2.3 FM-007: Implement Zenoh Health Gate

**Tasks**:
| Task | Description | Effort |
|------|-------------|--------|
| T7.1 | Add Zenoh status to Elixir /health endpoint | 4h |
| T7.2 | Add depends_on health check in compose | 2h |
| T7.3 | Add readiness probe for K8s | 4h |
| T7.4 | Integration tests for startup gate | 2h |
| **Total** | | **12h (1.5 days)** |

```elixir
# lib/indrajaal_web/controllers/health_controller.ex
defmodule IndrajaalWeb.HealthController do
  use IndrajaalWeb, :controller

  def health(conn, _params) do
    zenoh_status = get_zenoh_status()
    db_status = check_database()

    overall_healthy = zenoh_status.connected && db_status.connected

    status_code = if overall_healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: if(overall_healthy, do: "healthy", else: "unhealthy"),
      zenoh: %{
        connected: zenoh_status.connected,
        session_id: zenoh_status.session_id,
        router: zenoh_status.router_endpoint,
        latency_ms: zenoh_status.latency_ms
      },
      database: %{
        connected: db_status.connected,
        latency_ms: db_status.latency_ms
      },
      timestamp: DateTime.utc_now()
    })
  end

  defp get_zenoh_status do
    # Bridge to F# ZenohSession.Health()
    case Indrajaal.ZenohBridge.get_health() do
      {:ok, health} -> health
      {:error, _} -> %{connected: false, session_id: nil, router_endpoint: nil, latency_ms: nil}
    end
  end
end
```

```yaml
# docker-compose.yml - Add health gate
services:
  indrajaal-ex-app-1:
    depends_on:
      zenoh-router:
        condition: service_healthy
      indrajaal-db-prod:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
```

#### 5.2.4 FM-008: Implement Message Buffer Limits

**Tasks**:
| Task | Description | Effort |
|------|-------------|--------|
| T8.1 | Add MaxBufferSize to BridgeConfig | 2h |
| T8.2 | Implement buffer overflow handling | 4h |
| T8.3 | Add SC-BRIDGE-005 constraint validation | 2h |
| T8.4 | Unit tests for buffer limits | 2h |
| **Total** | | **10h (1.25 days)** |

```fsharp
// ZenohBridge.fs - Add buffer limits
type BridgeConfig = {
    MaxBufferSize: int      // Default: 100MB
    MaxMessageSize: int     // Default: 10MB (SC-ENV-003)
    BufferOverflowPolicy: OverflowPolicy
}

type OverflowPolicy =
    | DropOldest    // Drop oldest messages when full
    | DropNewest    // Reject new messages when full
    | Block         // Block sender until space available

type BoundedMessageBuffer(config: BridgeConfig) =
    let buffer = new ConcurrentQueue<ZenohEnvelope>()
    let mutable currentSize = 0L

    member _.Enqueue(envelope: ZenohEnvelope) : Result<unit, BufferError> =
        let msgSize = envelope.Payload.Length

        // SC-ENV-003: Check message size limit
        if msgSize > config.MaxMessageSize then
            return Error (BufferError.MessageTooLarge msgSize)

        // SC-BRIDGE-005: Check buffer size limit
        if currentSize + int64 msgSize > int64 config.MaxBufferSize then
            match config.BufferOverflowPolicy with
            | DropOldest ->
                while currentSize + int64 msgSize > int64 config.MaxBufferSize do
                    match buffer.TryDequeue() with
                    | true, old ->
                        Interlocked.Add(&currentSize, -int64 old.Payload.Length) |> ignore
                    | false, _ -> ()
            | DropNewest ->
                return Error BufferError.BufferFull
            | Block ->
                // Wait for space (with timeout)
                SpinWait.SpinUntil(fun () ->
                    currentSize + int64 msgSize <= int64 config.MaxBufferSize,
                    TimeSpan.FromSeconds(5.0)) |> ignore

        buffer.Enqueue(envelope)
        Interlocked.Add(&currentSize, int64 msgSize) |> ignore
        Ok ()
```

---

### 5.3 Phase 3: Medium Priority (Week 5-8)

| FM-ID | Task | Effort | Week |
|-------|------|--------|------|
| FM-009 | Add CRYSTALS-Dilithium support | 16h | 5 |
| FM-010 | Implement actual Raft RPC | 16h | 5-6 |
| FM-011 | Fix leader election timeout | 8h | 6 |
| FM-012 | Enforce minimum protocol version | 8h | 6 |
| FM-013 | Add envelope size limit (SC-ENV-003) | 4h | 7 |
| FM-014 | Expand KeyExpr validation | 8h | 7 |
| FM-015 | Implement real Zenoh-CS FFI | 24h | 7-8 |

### 5.4 Phase 4: Low Priority (Week 9-12)

| FM-ID | Task | Effort | Week |
|-------|------|--------|------|
| FM-016 | Add delivery confirmation | 8h | 9 |
| FM-017 | Add CPU/mem/net metrics | 8h | 9 |
| FM-018 | Make SessionConfig immutable | 4h | 10 |
| FM-019 | Enforce <10s heartbeat | 4h | 10 |
| FM-020 | Add L1 function topics | 8h | 11 |

---

## 6. Implementation Roadmap

### 6.1 Gantt Chart

```
Week:        1    2    3    4    5    6    7    8    9    10   11   12
            ─────────────────────────────────────────────────────────────
Phase 1: CRITICAL
FM-001      ████████
FM-002           ████████
FM-003                 ████
FM-004                    ██████████████

Phase 2: HIGH
FM-005                         ████
FM-006                              ██████
FM-007                                   ████
FM-008                                      ██

Phase 3: MEDIUM
FM-009                                         ████████
FM-010                                              ████████
FM-011-012                                               ████
FM-013-015                                                    ████████

Phase 4: LOW
FM-016-020                                                         ████████

Milestones:
    ★ Week 2:  Audit trail complete
    ★ Week 4:  Constitutional checks + PFH improvement
    ★ Week 8:  All HIGH priority complete
    ★ Week 12: All issues resolved
```

### 6.2 Resource Allocation

| Team | Week 1-2 | Week 3-4 | Week 5-8 | Week 9-12 |
|------|----------|----------|----------|-----------|
| F# Core | FM-001, FM-002 | FM-005, FM-008 | FM-010, FM-015 | FM-018 |
| Safety | FM-003, FM-004 | FM-006 | FM-009 | - |
| Bridge | FM-002 | FM-007 | - | FM-016 |
| DevOps | - | FM-007 | - | FM-017 |
| QA | Testing | Testing | Testing | Testing |

### 6.3 Dependencies

```
FM-001 (Audit Trail)
    │
    └──► FM-002 (Constitutional) depends on audit trail for logging
            │
            └──► FM-005 (Signatures) shares Ed25519 infrastructure

FM-003 (Immune Response)
    │
    └──► FM-004 (PFH) improved by faster detection

FM-006 (Split-Brain)
    │
    └──► FM-010 (Raft RPC) required for partition healing

FM-015 (Zenoh FFI)
    │
    └──► FM-007 (Health Gate) requires real Zenoh for health check
```

---

## 7. Verification & Validation

### 7.1 Test Plan per Phase

#### Phase 1 Tests (Critical)

| Test ID | Description | Type | Pass Criteria |
|---------|-------------|------|---------------|
| T-FM-001-1 | Verify blocks are Ed25519 signed | Unit | All blocks have valid signature |
| T-FM-001-2 | Verify hash chain integrity | Unit | Chain validates on startup |
| T-FM-001-3 | Verify tampering detected | Integration | Modified block rejected |
| T-FM-002-1 | Verify Ψ₀-Ψ₅ checks | Unit | All invariants validated |
| T-FM-002-2 | Verify hostile holon rejected | Integration | Join fails with error |
| T-FM-003-1 | Verify immune response < 50ms | Performance | p99 < 50ms |
| T-FM-004-1 | Verify PFH calculation | Analysis | PFH < 10⁻¹² |

#### Phase 2 Tests (High)

| Test ID | Description | Type | Pass Criteria |
|---------|-------------|------|---------------|
| T-FM-005-1 | Verify signature validation | Unit | Invalid signature rejected |
| T-FM-006-1 | Verify partition healing | Chaos | System recovers < 30s |
| T-FM-007-1 | Verify health gate | Integration | Unhealthy pod not started |
| T-FM-008-1 | Verify buffer limits | Unit | Overflow handled correctly |

### 7.2 Regression Test Suite

```bash
# Run all remediation tests
SKIP_ZENOH_NIF=0 mix test --only remediation

# Run specific phase tests
SKIP_ZENOH_NIF=0 mix test --only phase1
SKIP_ZENOH_NIF=0 mix test --only phase2
SKIP_ZENOH_NIF=0 mix test --only phase3
SKIP_ZENOH_NIF=0 mix test --only phase4

# Run FMEA validation
elixir scripts/verification/fmea_validator.exs --rpn-threshold 200
```

### 7.3 Formal Verification

| Theorem | Agda Proof | Status |
|---------|------------|--------|
| Audit chain integrity | `audit-chain-valid` | To add |
| Constitutional preservation | `psi-invariants` | Existing (partial) |
| Immune response bound | `immune-response-bound` | To add |
| PFH calculation | `pfh-formula` | To add |

---

## 8. Success Criteria

### 8.1 Phase 1 Exit Criteria

- [ ] FM-001: All consensus blocks Ed25519 signed, hash chain verified
- [ ] FM-002: Guardian gate active, Ψ₀-Ψ₅ checks passing
- [ ] FM-003: Immune response p99 < 50ms
- [ ] FM-004: PFH calculated and < 10⁻¹² documented

### 8.2 Phase 2 Exit Criteria

- [ ] FM-005: All signatures verified, invalid rejected
- [ ] FM-006: Partition healing works < 30s
- [ ] FM-007: /health includes Zenoh, startup gated
- [ ] FM-008: Buffer limits enforced, overflow handled

### 8.3 Final Exit Criteria

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| STAMP Compliance | 71% | 100% | ✓ 100% |
| SIL-6 Compliance | 50% | 100% | ✓ 100% |
| PFH | 10⁻⁷ | 10⁻¹² | ✓ < 10⁻¹² |
| FMEA RPN Max | 720 | < 100 | ✓ < 100 |
| Path Coverage | 98% | 100% | ✓ 100% |
| Agda Proofs | 86% | 100% | ✓ 100% |

### 8.3 Sign-Off Requirements

| Gate | Owner | Criteria |
|------|-------|----------|
| Code Review | Tech Lead | All PRs approved |
| Security Review | Security Team | No critical vulnerabilities |
| Safety Review | Safety Officer | SIL-6 compliance verified |
| QA Sign-Off | QA Lead | All tests passing |
| Constitutional | Guardian | Ψ₀-Ψ₅ invariants preserved |
| Founder Approval | Founder | Ω₀ directive maintained |

---

## Appendix A: STAMP Constraint Mapping

| Constraint | Violation | Remediation | Phase |
|------------|-----------|-------------|-------|
| SC-SIL6-007 | No audit trail | FM-001 | 1 |
| SC-SIL6-013 | No constitutional checks | FM-002 | 1 |
| SC-SIL6-004 | Slow immune response | FM-003 | 1 |
| SC-SIL6-001 | PFH too high | FM-004 | 1 |
| SC-REG-012 | No signature verification | FM-005 | 2 |
| SC-CONS-004 | No split-brain resolution | FM-006 | 2 |
| SC-ZENOH-007/008 | No health gate | FM-007 | 2 |
| SC-BRIDGE-005 | Unbounded buffer | FM-008 | 2 |
| SC-SIL6-010 | No quantum crypto | FM-009 | 3 |
| SC-CONS-001 | Raft RPC stub | FM-010 | 3 |

---

## Appendix B: Cost-Benefit Analysis

| Phase | Effort | Risk Reduction | ROI |
|-------|--------|----------------|-----|
| Phase 1 | 146h | EXTREME → HIGH | **Critical** |
| Phase 2 | 58h | HIGH → MEDIUM | **High** |
| Phase 3 | 84h | MEDIUM → LOW | Medium |
| Phase 4 | 32h | LOW → Negligible | Low |
| **Total** | **320h (8 weeks)** | **EXTREME → Negligible** | **Very High** |

---

**Document Control**

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Date | 2026-01-15 |
| Author | Claude Opus 4.5 |
| Methodology | 7-Level Fractal RCA + FMEA |
| STAMP | SC-CHG-001, SC-CHG-002 |

---

*Generated by Autonomous Verification System*
*Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>*
