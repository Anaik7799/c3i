# P0-SAFETY Reconciled Constraints (2026-03-22)

## SC-ENFORCE (Planning Enforcer Access Control)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ENFORCE-001 | Direct PROJECT_TODOLIST.md access MUST be blocked | CRITICAL |
| SC-ENFORCE-002 | All access attempts MUST be logged to immutable audit trail | CRITICAL |
| SC-ENFORCE-003 | Agent classification MUST occur before access check | CRITICAL |
| SC-ENFORCE-004 | Violation count MUST trigger circuit breaker at threshold | HIGH |
| SC-ENFORCE-005 | Circuit breaker threshold MUST be configurable | MEDIUM |
| SC-ENFORCE-006 | Audit trail MUST be append-only | CRITICAL |
| SC-ENFORCE-007 | Enforcement MUST be thread-safe | CRITICAL |
| SC-ENFORCE-008 | Hook registration MUST validate callback signatures | HIGH |
| SC-ENFORCE-009 | Telemetry MUST publish to Zenoh on violation | HIGH |
| SC-ENFORCE-010 | File path validation MUST be case-insensitive | HIGH |
| SC-ENFORCE-011 | Forbidden patterns MUST include regex support | MEDIUM |
| SC-ENFORCE-012 | Access decisions MUST complete within 5ms | HIGH |
| SC-ENFORCE-013 | Circuit breaker reset MUST require manual intervention | HIGH |
| SC-ENFORCE-014 | Agent whitelist MUST be verifiable | HIGH |
| SC-ENFORCE-015 | Enforcement bypass MUST require cryptographic proof | CRITICAL |
| SC-ENFORCE-016 | Violation alerts MUST include full context | MEDIUM |
| SC-ENFORCE-017 | Agent fingerprinting MUST detect impersonation | HIGH |
| SC-ENFORCE-018 | Request rate limiting MUST prevent DOS | HIGH |
| SC-ENFORCE-019 | Audit log rotation MUST preserve history | MEDIUM |
| SC-ENFORCE-020 | Multi-layer validation MUST all pass | CRITICAL |
| SC-ENFORCE-021 | Unknown agents MUST be denied by default | CRITICAL |
| SC-ENFORCE-022 | System agents MUST have verified identity | HIGH |
| SC-ENFORCE-023 | Access patterns MUST be analyzed for anomalies | MEDIUM |
| SC-ENFORCE-024 | Enforcement config MUST be immutable at runtime | HIGH |
| SC-ENFORCE-025 | All hooks MUST execute atomically | HIGH |

## SC-SIL4 (IEC 61508 SIL-4 Safety Functions)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL4-001 | Safety functions MUST fail to safe state | CRITICAL |
| SC-SIL4-002 | Type boundary checks mandatory (fail-closed) | CRITICAL |
| SC-SIL4-003 | Image verification mandatory before upgrade | CRITICAL |
| SC-SIL4-004 | Handle Guardian timeout — fail-closed | CRITICAL |
| SC-SIL4-005 | Container start order: DB → OBS → APP | CRITICAL |
| SC-SIL4-006 | 2oo3 voting MANDATORY for production actuations | CRITICAL |
| SC-SIL4-007 | Dying gasp checkpoint MANDATORY before shutdown | CRITICAL |
| SC-SIL4-008 | Connection drain timeout 30 seconds | HIGH |
| SC-SIL4-009 | Seed nodes updated before satellites | HIGH |
| SC-SIL4-010 | DAG validation before boot | CRITICAL |
| SC-SIL4-011 | Quorum ⌊N/2⌋+1 maintained throughout upgrades | CRITICAL |
| SC-SIL4-012 | 5 startup phases MANDATORY | CRITICAL |
| SC-SIL4-013 | 6 shutdown phases MANDATORY | CRITICAL |
| SC-SIL4-014 | Gossip protocol cookie REQUIRED | HIGH |
| SC-SIL4-015 | Split-brain detection triggers apoptosis | CRITICAL |
| SC-SIL4-016 | Node failure logging MANDATORY | HIGH |
| SC-SIL4-023 | FPPS 3/5 consensus for health and snapshot validation | CRITICAL |
| SC-SIL4-024 | Ed25519 image signature verification REQUIRED | CRITICAL |
| SC-SIL4-026 | Rollback path with 24-hour window | CRITICAL |
| SC-SIL4-027 | State snapshot before any upgrade | HIGH |
| SC-SIL4-029 | Immutable register integrity verification | HIGH |

## SC-SAFETY (Planning Safety Kernel)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SAFETY-001 | Guardian pre-approval REQUIRED for planning mutations | CRITICAL |
| SC-SAFETY-002 | State consistency validated pre/post execution | CRITICAL |
| SC-SAFETY-003 | Complete audit trail to Immutable Register | CRITICAL |
| SC-SAFETY-004 | Rollback for all critical operations | CRITICAL |
| SC-SAFETY-005 | Access control enforced — quarantined agents blocked | CRITICAL |
| SC-SAFETY-006 | Anomaly detection for suspicious patterns | HIGH |
| SC-SAFETY-007 | Resource bounds validated | HIGH |
| SC-SAFETY-008 | Concurrency control prevents race conditions | HIGH |
| SC-SAFETY-009 | Ψ₀ (Existence) validated for all operations | CRITICAL |
| SC-SAFETY-010 | Ψ₁ (Regeneration) verified — SQLite/DuckDB storage | CRITICAL |
| SC-SAFETY-011 | Ψ₂ (History) prevent history deletion | CRITICAL |
| SC-SAFETY-012 | Ψ₃ (Verification) hash chain integrity | CRITICAL |
| SC-SAFETY-013 | Ψ₄ (Human Alignment) Founder's lineage PRIMARY | CRITICAL |
| SC-SAFETY-014 | Ψ₅ (Truthfulness) no deception in logs | CRITICAL |
| SC-SAFETY-015 | Ω₀ (Symbiotic Survival) validated | CRITICAL |
| SC-SAFETY-016 | Ω₀.6 (Sentience) learning MUST NOT be disabled | HIGH |
| SC-SAFETY-017 | Ω₀.7 (Power) resource reduction justified | MEDIUM |
| SC-SAFETY-018 | Pre-execution validation completes all checks | CRITICAL |
| SC-SAFETY-019 | Runtime monitoring tracks all active operations | HIGH |
| SC-SAFETY-020 | Auto-halt at threat threshold | CRITICAL |
| SC-SAFETY-021 | Post-execution verification validates state/audit/hash | CRITICAL |
| SC-SAFETY-022 | Emergency stop < 5 seconds | CRITICAL |

## SC-SIL (SIL Compliance)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL-001 | SIL-2 systematic capability (PFD, HFT, proof test) | CRITICAL |
| SC-SIL-002 | Safe failure fraction ≥ 90% | CRITICAL |
| SC-SIL-003 | Diagnostic coverage ≥ 90% | CRITICAL |
| SC-SIL-004 | Separation of concerns — safety functions independent | HIGH |
| SC-SIL-005 | Independent safety monitoring | HIGH |

## SC-DMS (Dead Man's Switch)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-DMS-001 | Heartbeat interval MUST be 100ms | CRITICAL |
| SC-DMS-002 | Failsafe triggers within 50ms of timeout | CRITICAL |
| SC-DMS-003 | Failsafe state MUST be deterministic | CRITICAL |
| SC-DMS-004 | Recovery MUST be supervised | HIGH |

## SC-GUARD (Guardian Integration)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-GUARD-001 | Guardian MUST use Envelope for constraint values | CRITICAL |
| SC-GUARD-002 | Guardian integrates with DeadMansSwitch, fail closed | CRITICAL |
| SC-GUARD-003 | Guardian integrates with FounderDirective | CRITICAL |

## SC-WATCHDOG (State Watchdog)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-WATCHDOG-001 | Check interval ≤ 100ms | CRITICAL |
| SC-WATCHDOG-002 | Corruption triggers Guardian report | CRITICAL |
| SC-WATCHDOG-003 | Self-healing attempted before escalation | HIGH |

## SC-SAFE (Safety Invariants)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SAFE-001 | Safety invariants verified for all proposed state changes | CRITICAL |

## SC-SIMPLEX (Simplex Kernel)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIMPLEX-002 | Redundancy MUST NOT be reduced below minimum (MinRedundancy=2) | CRITICAL |

## SC-SEC (Security Constraints — authentication, authorization, encryption, PII, 23 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-SEC-001 to SC-SEC-049 | CRITICAL | Security constraints — authentication, authorization, encryption, PII masking, rate limiting |

**Constraint IDs:**
SC-SEC-001 SC-SEC-002 SC-SEC-003 SC-SEC-004 SC-SEC-005 SC-SEC-006 SC-SEC-008 SC-SEC-009 SC-SEC-010
SC-SEC-011 SC-SEC-012 SC-SEC-013 SC-SEC-015 SC-SEC-016 SC-SEC-041 SC-SEC-042 SC-SEC-043 SC-SEC-044
SC-SEC-045 SC-SEC-046 SC-SEC-047 SC-SEC-048 SC-SEC-049

## SC-NEURO (Neural/Cognitive Substrate Safety — AI interface, synapse safety, cortex integration, 5 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-NEURO-001 to SC-NEURO-005 | HIGH | Neural/cognitive substrate safety — AI interface guards, synapse safety, cortex integration constraints |

**Constraint IDs:**
SC-NEURO-001 SC-NEURO-002 SC-NEURO-003 SC-NEURO-004 SC-NEURO-005

## SC-NIF (NIF Layer Safety — Rust FFI, native interop, NIF stability, 6 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-NIF-001 to SC-NIF-006 | CRITICAL | NIF layer safety — Rust FFI boundary safety, native interop integrity, NIF crash isolation |

**Constraint IDs:**
SC-NIF-001 SC-NIF-002 SC-NIF-003 SC-NIF-004 SC-NIF-005 SC-NIF-006

## SC-PRIME (Prime Safety Invariants — constitutional prime axioms, symbiotic defense, 3 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-PRIME-001 to SC-PRIME-003 | CRITICAL | Prime safety invariants — constitutional prime axioms, symbiotic defense, system existence guarantees |

**Constraint IDs:**
SC-PRIME-001 SC-PRIME-002 SC-PRIME-003

## AOR-ENFORCE (Planning Enforcer Access Control Rules — 15 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-ENFORCE-001 to AOR-ENFORCE-015 | CRITICAL | Planning enforcer access control operation rules — enforcement hooks, audit, circuit breaker, fingerprinting |

**Rule IDs:**
AOR-ENFORCE-001 AOR-ENFORCE-002 AOR-ENFORCE-003 AOR-ENFORCE-004 AOR-ENFORCE-005
AOR-ENFORCE-006 AOR-ENFORCE-007 AOR-ENFORCE-008 AOR-ENFORCE-009 AOR-ENFORCE-010
AOR-ENFORCE-011 AOR-ENFORCE-012 AOR-ENFORCE-013 AOR-ENFORCE-014 AOR-ENFORCE-015

## AOR-SAFETY (Safety Operation Rules — planning safety kernel operations, 15 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-SAFETY-001 to AOR-SAFETY-015 | CRITICAL | Safety operation rules — pre/post execution validation, runtime monitoring, emergency halt, audit trail |

**Rule IDs:**
AOR-SAFETY-001 AOR-SAFETY-002 AOR-SAFETY-003 AOR-SAFETY-004 AOR-SAFETY-005
AOR-SAFETY-006 AOR-SAFETY-007 AOR-SAFETY-008 AOR-SAFETY-009 AOR-SAFETY-010
AOR-SAFETY-011 AOR-SAFETY-012 AOR-SAFETY-013 AOR-SAFETY-014 AOR-SAFETY-015

## AOR-SIL4 (SIL-4 Compliance Rules — container lifecycle, rolling update, mesh startup, 6 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-SIL4-001 to AOR-SIL4-006 | CRITICAL | SIL-4 compliance operation rules — container lifecycle management, rolling update procedures, mesh startup sequencing |

**Rule IDs:**
AOR-SIL4-001 AOR-SIL4-002 AOR-SIL4-003 AOR-SIL4-004 AOR-SIL4-005 AOR-SIL4-006

## AOR-SIL6 (SIL-6 Compliance Rules — mesh shutdown, quorum maintenance, 4 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-SIL6-001 to AOR-SIL6-006 | CRITICAL | SIL-6 compliance operation rules — graceful mesh shutdown phases, quorum maintenance during operations |

**Rule IDs:**
AOR-SIL6-001 AOR-SIL6-003 AOR-SIL6-004 AOR-SIL6-006

## AOR-SEC (Security Operation Rules — MCP security domain, bounded buffer, 3 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-SEC-001 to AOR-SEC-003 | HIGH | Security operation rules — MCP security domain handling, bounded buffer safety, identity verification |

**Rule IDs:**
AOR-SEC-001 AOR-SEC-002 AOR-SEC-003

## AOR-GUARD (Guardian Integration Rules — error pattern validation, 2 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-GUARD-001 to AOR-GUARD-002 | CRITICAL | Guardian integration operation rules — error pattern validation, Guardian approval enforcement |

**Rule IDs:**
AOR-GUARD-001 AOR-GUARD-002

## AOR-NEURO (Neural Operation Rules — synapse safety, cortex interface, 2 rules)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-NEURO-001 to AOR-NEURO-002 | HIGH | Neural operation rules — cortex synapse interface safety, AI proposal pipeline validation |

**Rule IDs:**
AOR-NEURO-001 AOR-NEURO-002

## AOR-NIF (NIF Safety Rule — FPPS binary NIF validation, 1 rule)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-NIF-001 | CRITICAL | NIF safety rule — FPPS binary NIF validation, Rust FFI boundary integrity check |

**Rule IDs:**
AOR-NIF-001

## AOR-PRIME (Prime Safety Rule — sentinel prime invariant, 1 rule)
| ID Range | Severity | Description |
|----------|----------|-------------|
| AOR-PRIME-001 | CRITICAL | Prime safety rule — sentinel prime invariant enforcement, constitutional prime axiom verification |

**Rule IDs:**
AOR-PRIME-001
