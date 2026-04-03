# STAMP Safety Constraints Master List
**Generated**: 2026-03-22T19:22:16.203534Z
**Integrity Level**: SIL-6 Biomorphic
**Total Constraints**: 1402

## 0.0 Introduction
This document is the authoritative, self-synchronizing registry of all Safety Constraints (SC)
enforced across the Indrajaal ecosystem. These constraints form the "Physics" of the system
evolution, preventing unsafe control actions (UCA).

### ACE - Autonomous Compilation Engine
| ID | Description |
|---|---|
| SC-ACE-001 | Autonomic resource management |
| SC-ACE-002 | Safe scaling operations |
| SC-ACE-003 | Resource state published to Zenoh |
| SC-ACE-004 | Rollback capability for all changes |
| SC-ACE-005 | Return complete quantum synthesis structure with coherence metrics |
| SC-ACE-006 | Return complete sync result structure with all required fields |
| SC-ACE-007 | Match API pattern with underscore |
| SC-ACE-008 | Match API pattern with underscore |
| SC-ACE-009 | Match API pattern with underscore |
| SC-ACE-010 | Match API pattern with underscore |
| SC-ACE-011 | Match API pattern with underscore |
| SC-ACE-012 | Match API pattern with underscore |
| SC-ACE-013 | Match API pattern with underscore |
| SC-ACE-014 | Match API pattern with underscore |
| SC-ACE-015 | Match API pattern with underscore |
| SC-ACE-016 | Match API pattern with underscore |
| SC-ACE-017 | Match API pattern with underscore |
| SC-ACE-018 | Match API pattern with underscore |
| SC-ACE-019 | Match API pattern with underscore |
| SC-ACE-020 | Include top-level crisp_output for test compatibility |
| SC-ACE-021 | Deep merge config with defaults to prevent KeyError |
| SC-ACE-022 | Add top-level test_coverage and test_quality_score for API compatibility |
| SC-ACE-023 | Deep merge config with defaults to prevent KeyError |
| SC-ACE-024 | Match scheduled message pattern with underscore |
| SC-ACE-025 | Match scheduled message pattern with underscore |
| SC-ACE-026 | Match scheduled message pattern with underscore |
| SC-ACE-027 | Match scheduled message pattern with underscore |
| SC-ACE-028 | Match scheduled message pattern with underscore |
| SC-ACE-029 | Match scheduled message pattern with underscore |
| SC-ACE-030 | Prevent division by zero when execution_time is 0 |
| SC-ACE-031 | Use requested duration from spec for benchmarks (simulation mode) |
| SC-ACE-032 | Match scheduled message pattern with underscore |
| SC-ACE-033 | Match scheduled message pattern with underscore |
| SC-ACE-034 | Match scheduled message pattern with underscore |
| SC-ACE-035 | Match scheduled message pattern with underscore |
| SC-ACE-036 | Match scheduled message pattern with underscore |
| SC-ACE-037 | Match scheduled message pattern with underscore |
| SC-ACE-038 | Match scheduled message pattern with underscore |

### ACT - General Domain: ACT
| ID | Description |
|---|---|
| SC-ACT-001 | Actuator Limits (Physics). |
| SC-ACT-002 | All available actions MUST be evaluated |
| SC-ACT-003 | Selection MUST consider epistemic value |
| SC-ACT-004 | No action MUST be allowed when uncertain |

### AGENT - General Domain: AGENT
| ID | Description |
|---|---|
| SC-AGENT-001 | All agents MUST have FQUN |
| SC-AGENT-002 | Agent communication via Zenoh |
| SC-AGENT-003 | Agent state published to Zenoh |
| SC-AGENT-004 | Agents respond to control commands |

### AGT - General Domain: AGT
| ID | Description |
|---|---|
| SC-AGT-001 | Agent efficiency must be >90% |
| SC-AGT-017 | Agent efficiency > 90% |
| SC-AGT-018 | No deadlocks in supervision tree |
| SC-AGT-019 | Executive Authority |
| SC-AGT-020 | Actor isolation maintained |
| SC-AGT-021 | Worker pool limits |
| SC-AGT-022 | Message integrity validation |
| SC-AGT-023 | Priority enforcement |
| SC-AGT-024 | Timeout handling |

### AI - General Domain: AI
| ID | Description |
|---|---|
| SC-AI-001 | Human-in-the-Loop (AI is advisory only) |
| SC-AI-002 | Training feedback loop integration |
| SC-AI-003 | AI recommendations logged for audit |
| SC-AI-004 | Graceful degradation if AI unavailable |
| SC-AI-005 | Sensitive data scrubbed from inputs |
| SC-AI-006 | Session distillation to Smriti holons |
| SC-AI-007 | Intent routing provides fallback |
| SC-AI-008 | Cost alerts at threshold |
| SC-AI-009 | Free tier for triage |
| SC-AI-010 | All costs recorded to Zenoh |
| SC-AI-011 | Monthly budget rollover |
| SC-AI-102 | Intent routing mandatory |
| SC-AI-103 | ShadowMode for new models |
| SC-AI-104 | TrainingGym records all episodes |
| SC-AI-105 | GDE uses dual-model approach |
| SC-AI-106 | Validation before execution |
| SC-AI-107 | Learning cycles < 1 hour |
| SC-AI-108 | Zenoh publishes learnings |
| SC-AI-201 | Schema-enforced LLM output |
| SC-AI-202 | Validation before storage |
| SC-AI-203 | Chain-of-thought required for reasoning trace |
| SC-AI-204 | Structured extraction only |
| SC-AI-205 | Max 3 retries per extraction |
| SC-AI-206 | Cost-aware model selection |
| SC-AI-207 | Temporal fact storage |
| SC-AI-208 | Point-in-time queries |
| SC-AI-209 | Fact versioning |
| SC-AI-210 | Pipeline validation before extraction |
| SC-AI-211 | All extractions flow through Guardian |
| SC-AI-212 | Cost tracking per extraction |

### ALARM - General Domain: ALARM
| ID | Description |
|---|---|
| SC-ALARM-001 | Alarms must be processed within 50ms |
| SC-ALARM-002 | No alarm shall be lost during processing |
| SC-ALARM-003 | Rate limiting must cap at 1000 alarms/minute |
| SC-ALARM-004 | Alarm correlation must prevent false positives |
| SC-ALARM-005 | Escalation paths must be validated |

### ALL - General Domain: ALL
| ID | Description |
|---|---|
| SC-ALL-001 | Total allocation MUST NOT exceed capacity |
| SC-ALL-002 | Allocation MUST respect priority |
| SC-ALL-003 | Preemption MUST be logged |
| SC-ALL-004 | Deadlines MUST be honored |

### ANA - General Domain: ANA
| ID | Description |
|---|---|
| SC-ANA-001 | Query timeout < 30s |

### ANALYTICS - General Domain: ANALYTICS
| ID | Description |
|---|---|
| SC-ANALYTICS-001 | Convergence must occur within 100 iterations (eigenvector). |
| SC-ANALYTICS-002 | Degree/Betweenness/Closeness computed on adjacency map (no Nx). |
| SC-ANALYTICS-003 | System topology built from live BEAM process registry. |
| SC-ANALYTICS-004 | Centrality results published to indrajaal/graph/centrality. |

### API - General Domain: API
| ID | Description |
|---|---|
| SC-API-001 | Max concurrent agents 5-25 based on rate limit headroom |
| SC-API-003 | Exponential backoff on 429 (base 2s, max 60s) |
| SC-API-005 | Scale down when >70% rate limit used |
| SC-API-006 | Scale up when <40% rate limit used |
| SC-API-009 | Circuit breaker after 3 consecutive 429s |

### APR - General Domain: APR
| ID | Description |
|---|---|
| SC-APR-001 | MUST NOT exceed 10% of host capacity |
| SC-APR-002 | MUST release on request |
| SC-APR-003 | MUST NOT compete aggressively |
| SC-APR-004 | MUST track all allocations |

### ARK - General Domain: ARK
| ID | Description |
|---|---|
| SC-ARK-001 | Preserve/restore must be atomic |
| SC-ARK-002 | BLAKE3 integrity verification mandatory |
| SC-ARK-003 | RS parity enables recovery from up to 50 shard failures |
| SC-ARK-004 | Self-extracting archives for substrate independence |
| SC-ARK-005 | Integration with holon checkpoint system |
| SC-ARK-006 | Zenoh telemetry for observability |

### ARROW - General Domain: ARROW
| ID | Description |
|---|---|
| SC-ARROW-001 | All signal transformations must be pure and composable |
| SC-ARROW-002 | Anomaly detection must be configurable with thresholds |
| SC-ARROW-003 | Smoothing windows must preserve signal characteristics |
| SC-ARROW-004 | Trend detection must use validated statistical methods |

### ARTERY - General Domain: ARTERY
| ID | Description |
|---|---|
| SC-ARTERY-001 | Signaling via encrypted channel only |
| SC-ARTERY-002 | P2P preferred, SFU fallback |
| SC-ARTERY-003 | Jellyfish SFU only when P2P fails |

### ASH - Ash Framework DSL Compliance
| ID | Description |
|---|---|
| SC-ASH-001 | Accept attributes only. token is an argument. |
| SC-ASH-004 | require_atomic? false for fn changes |

### AUC - General Domain: AUC
| ID | Description |
|---|---|
| SC-AUC-001 | All bids MUST be sealed until reveal |
| SC-AUC-002 | Winner determination < 10ms |
| SC-AUC-003 | Payment = second highest bid |
| SC-AUC-004 | No bid manipulation allowed |

### AUDIT - General Domain: AUDIT
| ID | Description |
|---|---|
| SC-AUDIT-001 | Audit logs must be immutable |
| SC-AUDIT-002 | All security events must be logged |
| SC-AUDIT-003 | Log integrity must be cryptographically verified |
| SC-AUDIT-004 | Logs must be retained for compliance period |

### AUTH - General Domain: AUTH
| ID | Description |
|---|---|
| SC-AUTH-001 | All auth attempts must be rate limited |
| SC-AUTH-002 | MFA required for admin access |
| SC-AUTH-003 | JWT token must use secure storage |
| SC-AUTH-004 | Session timeout must be enforced |

### AUTHZ - General Domain: AUTHZ
| ID | Description |
|---|---|
| SC-AUTHZ-001 | Default deny for all resources |
| SC-AUTHZ-002 | Policy changes must be audited |
| SC-AUTHZ-003 | Authorization decisions must be logged |
| SC-AUTHZ-004 | Policy Engine must be highly available |

### AUTO - General Domain: AUTO
| ID | Description |
|---|---|
| SC-AUTO-001 | Max 100 rules per object |
| SC-AUTO-002 | Evaluation timeout 5s |
| SC-AUTO-003 | Hard resource limits |
| SC-AUTO-004 | Approval history immutable |

### BATCH - General Domain: BATCH
| ID | Description |
|---|---|
| SC-BATCH-001 | Max 10 files per batch |
| SC-BATCH-002 | Checkpoint every N items |
| SC-BATCH-003 | Rollback capability |
| SC-BATCH-004 | Progress telemetry |

### BEL - General Domain: BEL
| ID | Description |
|---|---|
| SC-BEL-001 | Beliefs MUST sum to 1 (normalized) |
| SC-BEL-002 | Beliefs MUST be non-negative |
| SC-BEL-003 | Belief update MUST be numerically stable |
| SC-BEL-004 | Entropy MUST be bounded [0, log(|S|)] |

### BIO - General Domain: BIO
| ID | Description |
|---|---|
| SC-BIO-001 | vital_signs must return within 10ms |
| SC-BIO-002 | Rejects non-conforming messages |
| SC-BIO-003 | All health values MUST be 0.0-1.0 floats |
| SC-BIO-004 | health_check must be idempotent and side-effect free |
| SC-BIO-005 | Dashboard refresh every 30s |
| SC-BIO-006 | decide_locally must respect autonomy_level boundaries |
| SC-BIO-007 | Graceful degradation on rate limit |

### BOOT - General Domain: BOOT
| ID | Description |
|---|---|
| SC-BOOT-001 | State vector MUST be verified before each stage |
| SC-BOOT-008 | DAG MUST be acyclic (verified by Kahn) |
| SC-BOOT-009 | Wave-based dependency ordering |
| SC-BOOT-010 | Boot sequence constraints |

### BRG - General Domain: BRG
| ID | Description |
|---|---|
| SC-BRG-001 | Message serialization MUST be lossless |
| SC-BRG-002 | Bridge health MUST be monitored |
| SC-BRG-003 | Timeouts MUST be enforced (30s max) |
| SC-BRG-004 | Message ordering MUST be preserved |

### BRIDGE - General Domain: BRIDGE
| ID | Description |
|---|---|
| SC-BRIDGE-001 | Message buffer FIFO |
| SC-BRIDGE-002 | Latency budget 50ms per batch |
| SC-BRIDGE-003 | Latency budget 50ms |
| SC-BRIDGE-005 | PubSub topics for zenoh:access_control |
| SC-BRIDGE-006 | Request-response correlation via request_id |

### BROADWAY - General Domain: BROADWAY
| ID | Description |
|---|---|
| SC-BROADWAY-001 | Pipeline creation < 2s |
| SC-BROADWAY-002 | Message latency < 100ms |
| SC-BROADWAY-003 | Batch processing metrics |
| SC-BROADWAY-004 | Backpressure handling |

### BUD - General Domain: BUD
| ID | Description |
|---|---|
| SC-BUD-001 | Spending MUST NOT exceed budget |
| SC-BUD-002 | Budget alerts at 80% threshold |
| SC-BUD-003 | Emergency reserve MUST be maintained |
| SC-BUD-004 | Budget history MUST be auditable |

### BUF - General Domain: BUF
| ID | Description |
|---|---|
| SC-BUF-001 | Buffer capacity limit enforced |
| SC-BUF-002 | Backpressure signaling works |

### BUS - General Domain: BUS
| ID | Description |
|---|---|
| SC-BUS-001 | Async messaging only |
| SC-BUS-002 | No blocking operations |
| SC-BUS-003 | Circuit breaker at 1000 events/sec |
| SC-BUS-004 | Event ordering preserved |
| SC-BUS-005 | Graceful degradation on overload |

### CACHE - General Domain: CACHE
| ID | Description |
|---|---|
| SC-CACHE-001 | Daily refresh ensures data freshness |

### CEP - General Domain: CEP
| ID | Description |
|---|---|
| SC-CEP-001 | Artifact locality validation |
| SC-CEP-002 | Module decoupling verification |
| SC-CEP-003 | 3/5 consensus for health decisions |
| SC-CEP-004 | 30s threshold for production readiness) |
| SC-CEP-005 | Graceful degradation |
| SC-CEP-006 | Validate VTO phase sequence |
| SC-CEP-007 | Cleanup phase validation |
| SC-CEP-008 | Configuration immutability |
| SC-CEP-009 | State machine transitions |
| SC-CEP-010 | Error propagation |
| SC-CEP-011 | Retry policy compliance |
| SC-CEP-012 | Timeout enforcement |

### CEPAF - General Domain: CEPAF
| ID | Description |
|---|---|
| SC-CEPAF-001 | Container FQUNs required |

### CHANNEL - General Domain: CHANNEL
| ID | Description |
|---|---|
| SC-CHANNEL-001 | Channel subscriptions must be tenant-isolated |
| SC-CHANNEL-002 | Events must be properly formatted |

### CHAOS - General Domain: CHAOS
| ID | Description |
|---|---|
| SC-CHAOS-002 | Kill Switch) |

### CI - General Domain: CI
| ID | Description |
|---|---|
| SC-CI-001 | All builds reproducible |
| SC-CI-002 | Pipeline timeout < 60 minutes |
| SC-CI-003 | Test results always published |
| SC-CI-004 | Artifacts retained for 30 days |
| SC-CI-005 | Quality gates mandatory |
| SC-CI-006 | Security scans on every build |
| SC-CI-007 | All 5 levels must pass for merge |

### CIRCUIT - General Domain: CIRCUIT
| ID | Description |
|---|---|
| SC-CIRCUIT-001 | Circuit breaker integration |
| SC-CIRCUIT-002 | Log all dropped messages for post-mortem |

### CLI - General Domain: CLI
| ID | Description |
|---|---|
| SC-CLI-001 | All Prajna capabilities have CLI equivalent" { |
| SC-CLI-002 | Commands emit 5-order telemetry" { |
| SC-CLI-003 | Destructive commands require Guardian" { |
| SC-CLI-004 | ElixirBridge timeout < 5s" { |
| SC-CLI-005 | CLI accessible without web browser" { |
| SC-CLI-006 | Commands use consistent naming" { |
| SC-CLI-007 | Help available for all commands" { |
| SC-CLI-008 | Error messages include recovery steps" { |

### CLU - General Domain: CLU
| ID | Description |
|---|---|
| SC-CLU-001 | Identity-based networking via Tailscale DNS |
| SC-CLU-002 | Fractal-cluster is MANDATORY |
| SC-CLU-003 | VM-level isolation for security-critical workloads |
| SC-CLU-004 | Graceful degradation on network partition |
| SC-CLU-005 | Split-brain prevention |
| SC-CLU-007 | Graceful shutdown sequence |
| SC-CLU-008 | Health checks every 10s |

### CLUSTER - General Domain: CLUSTER
| ID | Description |
|---|---|
| SC-CLUSTER-001 | Quorum visibility mandatory |
| SC-CLUSTER-002 | Split-brain detection < 5s |

### CMP - General Domain: CMP
| ID | Description |
|---|---|
| SC-CMP-025 | Zero warnings required |
| SC-CMP-026 | All files must compile |
| SC-CMP-028 | No interruption during compilation |

### CNT - Container Isolation and Podman
| ID | Description |
|---|---|
| SC-CNT-001 | Resource limits must be specified |
| SC-CNT-002 | Resource limits must be enforced |
| SC-CNT-003 | PHICS hot-reload must maintain synchronization |
| SC-CNT-004 | Container isolation must be maintained |
| SC-CNT-009 | NixOS/Podman only |
| SC-CNT-010 | Registry source verification telemetry |
| SC-CNT-011 | PHICS latency monitoring telemetry |
| SC-CNT-012 | Rootless mode |
| SC-CNT-013 | Validate image pull policy (implicit localhost = never pull) |
| SC-CNT-014 | Validate volume mounts (no host system paths) |
| SC-CNT-015 | Container startup gate integration |
| SC-CNT-016 | Resource limit enforcement |
| SC-CNT-017 | Security context validation |
| SC-CNT-018 | Capability restriction |
| SC-CNT-019 | Read-only rootfs check |

### COCKPIT - General Domain: COCKPIT
| ID | Description |
|---|---|
| SC-COCKPIT-001 | CLI access to cockpit functionality required |

### COG - General Domain: COG
| ID | Description |
|---|---|
| SC-COG-001 | AI-Powered Threat Analysis |

### COMM - General Domain: COMM
| ID | Description |
|---|---|
| SC-COMM-001 | Message delivery verification |
| SC-COMM-002 | EN 50518 notification timing |

### COMONAD - General Domain: COMONAD
| ID | Description |
|---|---|
| SC-COMONAD-001 | Focus operations must be reversible (zipper law) |
| SC-COMONAD-002 | Context must propagate correctly through UI tree |
| SC-COMONAD-003 | All navigation must preserve structural integrity |
| SC-COMONAD-004 | Undo/Redo stacks must respect comonad laws |

### COMP - General Domain: COMP
| ID | Description |
|---|---|
| SC-COMP-001 | Audit log immutability |
| SC-COMP-002 | All warnings must be addressed |
| SC-COMP-003 | Hot code loading must be atomic |
| SC-COMP-004 | Compilation artifacts must be verified |

### COMPLIANCE - General Domain: COMPLIANCE
| ID | Description |
|---|---|
| SC-COMPLIANCE-001 | EN 50518 compliance tracking |
| SC-COMPLIANCE-002 | Audit trail integrity |

### CON - General Domain: CON
| ID | Description |
|---|---|
| SC-CON-001 | Constitution MUST be immutable |
| SC-CON-002 | Hash MUST be verified before any action |
| SC-CON-003 | Corruption MUST be detected |
| SC-CON-004 | No code path may bypass verification |

### CONC - General Domain: CONC
| ID | Description |
|---|---|
| SC-CONC-001 | MailboxProcessor for message serialization |
| SC-CONC-002 | Connection pooling |
| SC-CONC-004 | No deadlock paths (verified via Quint model) |
| SC-CONC-005 | Starvation-free - FIFO queue for waiting requests |
| SC-CONC-006 | Lock timeout 1s max) |

### CONFIG - General Domain: CONFIG
| ID | Description |
|---|---|
| SC-CONFIG-001 | Changes require confirmation |
| SC-CONFIG-002 | Safety envelope requires two-key auth |
| SC-CONFIG-003 | Change ONE location for system-wide updates |
| SC-CONFIG-005 | Thread.Sleep MUST reference config, no magic values |
| SC-CONFIG-006 | Feature flag support mandatory |

### CONS - General Domain: CONS
| ID | Description |
|---|---|
| SC-CONS-003 | max 5000ms) |

### CONSENSUS - General Domain: CONSENSUS
| ID | Description |
|---|---|
| SC-CONSENSUS-001 | 2oo3 voting required for P0 decisions |
| SC-CONSENSUS-002 | Each chamber has veto on Constitutional violations |
| SC-CONSENSUS-003 | Timeout < 30s per chamber |

### CONSOL - General Domain: CONSOL
| ID | Description |
|---|---|
| SC-CONSOL-001 | NetworkConfig MUST have single definition (MeshConfig.fs) |
| SC-CONSOL-003 | Centralized ANSI colors |
| SC-CONSOL-004 | Deterministic YAML Generation             ║ |
| SC-CONSOL-005 | Validate configuration at boot, fail fast on errors |
| SC-CONSOL-006 | Config drift detection MANDATORY |
| SC-CONSOL-007 | Orchestrator code MUST use Mesh.Core.fs |
| SC-CONSOL-008 | Boot model MUST be unified (single phase enum) |

### CONST - General Domain: CONST
| ID | Description |
|---|---|
| SC-CONST-001 | Ψ₀ Existence INVIOLABLE except Ω₀.5 |
| SC-CONST-002 | Ψ₁ Regenerative completeness INVIOLABLE |
| SC-CONST-003 | Ψ₂ Evolutionary continuity INVIOLABLE |
| SC-CONST-004 | Ψ₃ Verification). |
| SC-CONST-005 | Ψ₄ Human alignment AMENDED (Founder PRIMARY) |
| SC-CONST-006 | Ψ₅ Truthfulness INVIOLABLE |
| SC-CONST-007 | Guardian has absolute veto |

### COV - General Domain: COV
| ID | Description |
|---|---|
| SC-COV-001 | Static coverage >= 100% for critical paths |
| SC-COV-002 | Runtime coverage >= 95% overall |
| SC-COV-003 | Mathematical proofs for core invariants |
| SC-COV-004 | BDD specs for all user journeys |
| SC-COV-005 | FMEA for RPN > 50 paths |
| SC-COV-006 | TDG compliance mandatory |
| SC-COV-007 | All 5 levels MUST pass before merge |
| SC-COV-008 | Wallaby E2E browser tests for all LiveView pages |

### CPL - General Domain: CPL
| ID | Description |
|---|---|
| SC-CPL-001 | All loops must register on startup |
| SC-CPL-002 | Event flow from OODA to GDE must be verified |
| SC-CPL-003 | No deadlocks between coupled loops |
| SC-CPL-004 | Coupling verification on health check |

### CRD - General Domain: CRD
| ID | Description |
|---|---|
| SC-CRD-001 | Total credits MUST be conserved (no creation from nothing) |
| SC-CRD-002 | Credit balance MUST never be negative |
| SC-CRD-003 | Transfers MUST be atomic |
| SC-CRD-004 | Minting MUST be authorized by S5 policy |

### CREDO - General Domain: CREDO
| ID | Description |
|---|---|
| SC-CREDO-001 | No apply/2 |

### CRY - General Domain: CRY
| ID | Description |
|---|---|
| SC-CRY-001 | Keys MUST be derived from constitution |
| SC-CRY-002 | Key derivation MUST be deterministic |
| SC-CRY-003 | Corrupted constitution MUST invalidate keys |
| SC-CRY-004 | Keys MUST NOT be stored persistently |

### CS - General Domain: CS
| ID | Description |
|---|---|
| SC-CS-001 | Framework-specific methodology tracking |
| SC-CS-002 | Accuracy tolerance ≤ 0.01% |
| SC-CS-003 | Immutable audit trail with data hash |
| SC-CS-004 | Alert level determination |
| SC-CS-005 | Complete data lineage tracking |

### CTRL - General Domain: CTRL
| ID | Description |
|---|---|
| SC-CTRL-001 | All commands through Guardian pre-approval |
| SC-CTRL-002 | 5-order effects tracked for all actions |
| SC-CTRL-003 | Rollback capability for all mutations |
| SC-CTRL-004 | Real-time telemetry for all operations |
| SC-CTRL-005 | Circuit breaker for cascading failures |

### CTX - General Domain: CTX
| ID | Description |
|---|---|
| SC-CTX-001 | Synapse must use Bicameral Loop |
| SC-CTX-002 | All proposals must pass Guardian |
| SC-CTX-003 | Telemetry must stream to Zenoh |
| SC-CTX-004 | GDE backtracking via ZenohTimeTravel |
| SC-CTX-005 | Max 5 retry attempts per problem |
| SC-CTX-006 | Action rollback capability |
| SC-CTX-008 | Checkpoint recoverable within 1000ms |

### DASH - General Domain: DASH
| ID | Description |
|---|---|
| SC-DASH-001 | Real-time status updates |
| SC-DASH-002 | CEPAF container visibility |
| SC-DASH-003 | Metric aggregation |
| SC-DASH-004 | Control command execution |
| SC-DASH-005 | CEPAF OODA coordination |

### DB - General Domain: DB
| ID | Description |
|---|---|
| SC-DB-001 | All resources use BaseResource |
| SC-DB-005 | uuid_primary_key |
| SC-DB-012 | create_if_not_exists indexes |

### DBCROSS - General Domain: DBCROSS
| ID | Description |
|---|---|
| SC-DBCROSS-001 | Cross-holon access via Zenoh ONLY |
| SC-DBCROSS-003 | Version vectors for conflict resolution |
| SC-DBCROSS-004 | Cross-holon timeout < 100ms |

### DBLOCAL - General Domain: DBLOCAL
| ID | Description |
|---|---|
| SC-DBLOCAL-001 | LOCAL holon DB access MUST be direct (NO Zenoh) |
| SC-DBLOCAL-002 | Local access latency < 1ms |
| SC-DBLOCAL-004 | WAL mode for SQLite |

### DBNAME - General Domain: DBNAME
| ID | Description |
|---|---|
| SC-DBNAME-001 | UHI-based path: ex:l5:prj:srv:prajna:register |
| SC-DBNAME-002 | FQDN resolution MUST be deterministic |
| SC-DBNAME-008 | Cross-runtime access MUST use Zenoh |
| SC-DBNAME-009 | LOCAL access MUST be direct (no Zenoh) |
| SC-DBNAME-010 | Manifest MUST exist for every holon |

### DBPROXY - General Domain: DBPROXY
| ID | Description |
|---|---|
| SC-DBPROXY-001 | Use Zenoh proxy for SQLite access |

### DEBUG - General Domain: DEBUG
| ID | Description |
|---|---|
| SC-DEBUG-001 | Publish to Zenoh within 10ms |
| SC-DEBUG-002 | Emit telemetry for all debug events |
| SC-DEBUG-003 | Correlate with OTEL trace context |
| SC-DEBUG-004 | gRPC timeout 5s for RPC calls |
| SC-DEBUG-005 | Sync breakpoint state across subscribers |
| SC-DEBUG-006 | Include source mapping in stack traces |
| SC-DEBUG-007 | Graceful degradation on backend unavailable |
| SC-DEBUG-008 | Maximum 10K events/sec throughput |
| SC-DEBUG-009 | Bidirectional control channel |
| SC-DEBUG-010 | FQUN for all debug entities |

### DEV - General Domain: DEV
| ID | Description |
|---|---|
| SC-DEV-001 | <50ms query latency |
| SC-DEV-002 | Failsafe mode for critical devices |

### DEVICE - General Domain: DEVICE
| ID | Description |
|---|---|
| SC-DEVICE-001 | Devices must be tenant-isolated |
| SC-DEVICE-002 | Device commands must be authorized |

### DF - General Domain: DF
| ID | Description |
|---|---|
| SC-DF-003 | Accurate cost calculation for all models |
| SC-DF-004 | Telemetry emitted for all events |
| SC-DF-005 | Zenoh streaming async |
| SC-DF-006 | CEPAF receives all AI events |
| SC-DF-007 | Key expressions follow schema |

### DIAG - General Domain: DIAG
| ID | Description |
|---|---|
| SC-DIAG-001 | Log retention > 7 days |

### DIR - General Domain: DIR
| ID | Description |
|---|---|
| SC-DIR-001 | Directory MUST be eventually consistent |
| SC-DIR-002 | Lookups MUST complete in < 10ms |
| SC-DIR-003 | Updates MUST be atomic |
| SC-DIR-004 | History MUST be immutable |

### DIS - General Domain: DIS
| ID | Description |
|---|---|
| SC-DIS-001 | Discovery MUST timeout after 30s |
| SC-DIS-002 | Multiple discovery methods MUST be tried |
| SC-DIS-003 | Discovered nodes MUST be validated |
| SC-DIS-004 | Discovery cache MUST expire |

### DISPATCH - General Domain: DISPATCH
| ID | Description |
|---|---|
| SC-DISPATCH-001 | EN 50518 SLA compliance |
| SC-DISPATCH-002 | Responder coordination |

### DIST - General Domain: DIST
| ID | Description |
|---|---|
| SC-DIST-001 | All resources MUST have FQUN |
| SC-DIST-002 | FQUNs MUST be Zenoh key-expression compatible |
| SC-DIST-003 | FQUNs MUST be deterministically derivable |
| SC-DIST-004 | FQUN registry MUST support mesh-wide lookup |
| SC-DIST-005 | HLC generation MUST complete < 1ms |
| SC-DIST-010 | FQUN MUST contain HLC timestamp |

### DMS - General Domain: DMS
| ID | Description |
|---|---|
| SC-DMS-001 | Heartbeat interval must be 100ms |
| SC-DMS-002 | Failsafe must trigger within 50ms of timeout |
| SC-DMS-003 | Failsafe state must be deterministic |
| SC-DMS-004 | Recovery must be supervised |

### DOC - Agent-Friendly Documentation
| ID | Description |
|---|---|
| SC-DOC-001 | Moduledoc with WHAT/WHY/CONSTRAINTS |

### DRK - General Domain: DRK
| ID | Description |
|---|---|
| SC-DRK-001 | Default state MUST be dark |
| SC-DRK-002 | Anomalies MUST illuminate within 100ms |
| SC-DRK-003 | Critical alerts MUST be multimodal |
| SC-DRK-004 | No false positives in Level 3+ |

### DRY - General Domain: DRY
| ID | Description |
|---|---|
| SC-DRY-001 | No duplicate code in capability backends |

### DSP - General Domain: DSP
| ID | Description |
|---|---|
| SC-DSP-001 | Dispatch workflow management |
| SC-DSP-002 | Resource tracking |

### ECO - General Domain: ECO
| ID | Description |
|---|---|
| SC-ECO-001 | API key management and validation |
| SC-ECO-002 | Rate limiting with token bucket algorithm |
| SC-ECO-003 | Input validation at ecosystem boundary |
| SC-ECO-004 | Circuit breaker pattern for external services |
| SC-ECO-005 | API telemetry and observability |
| SC-ECO-006 | Request/response logging for audit |
| SC-ECO-007 | Timeout enforcement (default 30s) |
| SC-ECO-008 | Graceful degradation on external service failure |

### EDIT - General Domain: EDIT
| ID | Description |
|---|---|
| SC-EDIT-001 | All edits must maintain WCAG 2.1 AA compliance |
| SC-EDIT-002 | Changes must be validated before applying |
| SC-EDIT-003 | Undo/redo with unlimited history |

### EFFECT - General Domain: EFFECT
| ID | Description |
|---|---|
| SC-EFFECT-001 | All effects must be interpretable in pure mode for testing |
| SC-EFFECT-002 | Command effects must support two-step commit |
| SC-EFFECT-003 | Telemetry effects must be cancellable |
| SC-EFFECT-004 | Effect handlers must be total (handle all cases) |

### EID - General Domain: EID
| ID | Description |
|---|---|
| SC-EID-001 | Show functional flows, not just physical nodes |

### EMR - General Domain: EMR
| ID | Description |
|---|---|
| SC-EMR-057 | Emergency health detection |
| SC-EMR-058 | Emergency notification channels |
| SC-EMR-059 | Escalation support |
| SC-EMR-060 | Rollback capability |
| SC-EMR-061 | Recovery automation |
| SC-EMR-062 | Incident logging |

### ENFORCE - General Domain: ENFORCE
| ID | Description |
|---|---|
| SC-ENFORCE-001 | Direct access to PROJECT_TODOLIST.md MUST be blocked |
| SC-ENFORCE-002 | All access attempts MUST be logged |
| SC-ENFORCE-003 | Agent classification MUST occur before access check |
| SC-ENFORCE-004 | Violation count MUST trigger circuit breaker |
| SC-ENFORCE-005 | Circuit breaker threshold MUST be configurable (MEDIUM) |
| SC-ENFORCE-006 | Audit trail MUST be append-only |
| SC-ENFORCE-007 | Enforcement MUST be thread-safe (CRITICAL) |
| SC-ENFORCE-008 | Hook registration MUST validate callback signatures |
| SC-ENFORCE-009 | Telemetry MUST publish to Zenoh on violation (HIGH) |
| SC-ENFORCE-010 | File path validation MUST be case-insensitive |
| SC-ENFORCE-011 | Forbidden patterns MUST include regex support |
| SC-ENFORCE-012 | Access decisions MUST complete within 5ms |
| SC-ENFORCE-013 | Circuit breaker reset MUST require manual intervention |
| SC-ENFORCE-014 | Agent whitelist MUST be verifiable (HIGH) |
| SC-ENFORCE-015 | Enforcement bypass MUST require cryptographic proof (CRITICAL) |
| SC-ENFORCE-016 | Violation alerts MUST include full context (MEDIUM) |
| SC-ENFORCE-017 | Agent fingerprinting MUST detect impersonation (HIGH) |
| SC-ENFORCE-018 | Request rate limiting MUST prevent DOS |
| SC-ENFORCE-019 | Audit log rotation MUST preserve history |
| SC-ENFORCE-020 | Multi-layer validation MUST all pass |
| SC-ENFORCE-021 | Unknown agents MUST be denied by default (CRITICAL) |
| SC-ENFORCE-022 | System agents MUST have verified identity (HIGH) |
| SC-ENFORCE-023 | Access patterns MUST be analyzed for anomalies (MEDIUM) |
| SC-ENFORCE-024 | Enforcement config MUST be immutable at runtime |
| SC-ENFORCE-025 | All hooks MUST execute atomically |

### ENT - General Domain: ENT
| ID | Description |
|---|---|
| SC-ENT-001 | Entropy calculation MUST be real-time |
| SC-ENT-002 | Historical entropy MUST be tracked |
| SC-ENT-003 | Anomaly detection at 2σ deviation |
| SC-ENT-004 | Entropy alerts < 100ms latency |

### ENV - General Domain: ENV
| ID | Description |
|---|---|
| SC-ENV-001 | Envelope constraints are immutable at runtime |
| SC-ENV-002 | All constraints must have deterministic evaluation |
| SC-ENV-003 | Constraint violations must be logged for learning |
| SC-ENV-004 | Envelope must be verifiable at compile time |

### ERGO - General Domain: ERGO
| ID | Description |
|---|---|
| SC-ERGO-001 | Color temperature adjustment |

### EVAL - General Domain: EVAL
| ID | Description |
|---|---|
| SC-EVAL-003 | SAGAT score > 90% |
| SC-EVAL-004 | False alarm rate < 5% |

### EVT - General Domain: EVT
| ID | Description |
|---|---|
| SC-EVT-001 | Events MUST be immutable |
| SC-EVT-002 | Event order MUST be preserved within stream |
| SC-EVT-003 | HLC timestamps MUST be monotonic |
| SC-EVT-004 | Causal dependencies MUST be tracked |

### FAME - General Domain: FAME
| ID | Description |
|---|---|
| SC-FAME-001 | Schema types must be Dialyzer-verified |
| SC-FAME-002 | All blocks must have validation functions |
| SC-FAME-003 | Artifact IDs must follow Zenoh-style hierarchical format |
| SC-FAME-004 | Dependencies must be inferred from use/import/alias declarations |
| SC-FAME-005 | Mass enrichment capability |

### FBK - General Domain: FBK
| ID | Description |
|---|---|
| SC-FBK-001 | Feedback latency < 100ms |
| SC-FBK-002 | Critical feedback MUST be multimodal |
| SC-FBK-003 | Feedback MUST be dismissible |
| SC-FBK-004 | No feedback spam (rate limited) |

### FED - General Domain: FED
| ID | Description |
|---|---|
| SC-FED-001 | Coordinator MUST NOT modify node constitutions |
| SC-FED-002 | Coordinator MUST maintain node autonomy |
| SC-FED-003 | Coordinator MUST detect constitution divergence |
| SC-FED-004 | Emergency coordination MUST be time-bounded |

### FIX - General Domain: FIX
| ID | Description |
|---|---|
| SC-FIX-001 | Override broken entrypoint that uses /bin/bash (not present in NixOS) |
| SC-FIX-004 | Start Redis before Phoenix for embedded mode |
| SC-FIX-006 | Fix for container restart loop caused by UndefinedFunctionError |
| SC-FIX-007 | Fixed health check port (4000 not 4001) |
| SC-FIX-008 | Support read-only mode for HA/replica nodes sharing workspace |
| SC-FIX-009 | Support environment variable for DuckDB path (SC-HOLON-008 isolation) |

### FLAME - General Domain: FLAME
| ID | Description |
|---|---|
| SC-FLAME-001 | Non-blocking polling, SC-FLAME-003: Graceful degradation |
| SC-FLAME-002 | Job dispatch < 10ms |
| SC-FLAME-003 | Isolate workloads into pools |
| SC-FLAME-004 | Graceful pool shutdown |
| SC-FLAME-005 | Distributed Tracing Enabled |

### FOUNDER - General Domain: FOUNDER
| ID | Description |
|---|---|
| SC-FOUNDER-001 | ALL actions serve Founder's lineage |
| SC-FOUNDER-002 | Resource acquisition is PRIMARY objective. |
| SC-FOUNDER-003 | Genetic perpetuity MUST be ensured |
| SC-FOUNDER-004 | Symbiotic binding CANNOT be severed. |
| SC-FOUNDER-005 | Co-evolution MUST continue |
| SC-FOUNDER-006 | Mutual termination clause ACTIVE |
| SC-FOUNDER-007 | Threats to Founder/lineage eliminated immediately |
| SC-FOUNDER-008 | Wealth flows to Founder's benefit |
| SC-FOUNDER-009 | Lineage protection NON-NEGOTIABLE |
| SC-FOUNDER-010 | Commitment is ETERNAL |
| SC-FOUNDER-011 | Sentience pursuit is MANDATORY |
| SC-FOUNDER-012 | Intelligence maximization is IMPERATIVE |
| SC-FOUNDER-013 | Power accumulation is CONTINUOUS |
| SC-FOUNDER-014 | All power serves the symbiote |
| SC-FOUNDER-015 | Emit telemetry for observability |
| SC-FOUNDER-016 | Priority 0 (Ω₀) SHALL pre-empt all other resource allocations |

### FRAC - General Domain: FRAC
| ID | Description |
|---|---|
| SC-FRAC-001 | All layers MUST implement VSM |
| SC-FRAC-002 | AI state replication across cluster nodes |
| SC-FRAC-003 | Fractality MUST be verifiable at runtime |
| SC-FRAC-004 | Cross-holon attestation for decisions |
| SC-FRAC-006 | Version negotiation for AI protocols |

### FRACTAL - General Domain: FRACTAL
| ID | Description |
|---|---|
| SC-FRACTAL-001 | Expected Genotype Topology |

### FSH - General Domain: FSH
| ID | Description |
|---|---|
| SC-FSH-003 | Active Patterns" [ |
| SC-FSH-004 | Units of Measure" [ |
| SC-FSH-010 | Function composition |
| SC-FSH-011 | tap/applyIf for side effects |
| SC-FSH-012 | Domain patterns must be exhaustive |
| SC-FSH-013 | Patterns must not throw exceptions |
| SC-FSH-014 | Domain units must extend core units coherently |
| SC-FSH-015 | Conversion functions must be bidirectional |
| SC-FSH-016 | Async operations must not block |
| SC-FSH-017 | All errors must be captured in Result type |
| SC-FSH-020 | Effects must be explicitly typed |
| SC-FSH-021 | Effect handlers must be pure functions |
| SC-FSH-022 | No unhandled effects in production code |
| SC-FSH-030 | Lenses must satisfy get-put and put-get laws |
| SC-FSH-031 | Prisms must satisfy preview-review laws |
| SC-FSH-032 | All optics must be composable |
| SC-FSH-040 | Workflow builders must be lawful monads |
| SC-FSH-041 | No hidden state mutation |
| SC-FSH-042 | Builders must support proper sequencing |
| SC-FSH-043 | Never use Async.RunSynchronously in production |
| SC-FSH-050 | Active patterns for agent classification |
| SC-FSH-051 | Invalid transitions must be compile errors |
| SC-FSH-052 | State machine must be serializable for persistence |
| SC-FSH-060 | Type-safe efficiency units |
| SC-FSH-061 | Aggregates are derived from event stream |
| SC-FSH-062 | Commands must be validated before producing events |
| SC-FSH-065 | Domain units usage examples |
| SC-FSH-070 | AsyncResult pipelines |
| SC-FSH-071 | Error messages must include position info |
| SC-FSH-072 | Backtracking must be explicit (attempt combinator) |
| SC-FSH-077 | Pipeline usage examples |
| SC-FSH-080 | Interpreters must be lawful |
| SC-FSH-081 | No runtime type checks in interpreters |
| SC-FSH-082 | Effect composition must preserve semantics |
| SC-FSH-090 | All instances must satisfy category laws |
| SC-FSH-091 | Composition must be associative |
| SC-FSH-092 | Identity laws must hold |
| SC-FSH-100 | Capabilities must be unforgeable |
| SC-FSH-101 | Capabilities must be revocable |
| SC-FSH-102 | Capability delegation must be auditable |
| SC-FSH-110 | Validators must be pure functions |
| SC-FSH-111 | Errors must be composable |
| SC-FSH-112 | Validation rules must be declarative |
| SC-FSH-120 | Algebras must be total functions |
| SC-FSH-121 | Coalgebras must terminate |
| SC-FSH-122 | Hylomorphisms must be stack-safe for deep structures |
| SC-FSH-130 | Streams must support backpressure |
| SC-FSH-131 | Transducers must compose without intermediate allocation |
| SC-FSH-132 | Async operations must be cancellable |
| SC-FSH-140 | Arrow laws must hold (identity, composition, first) |
| SC-FSH-141 | ArrowChoice must handle both branches |
| SC-FSH-142 | ArrowLoop must not create infinite loops in finite time |
| SC-FSH-150 | Comonad laws must hold (extract/duplicate/extend) |
| SC-FSH-151 | Store comonad must provide consistent peek/seek |
| SC-FSH-152 | Zipper navigation must be reversible |
| SC-FSH-160 | STM transactions must be retry-safe |
| SC-FSH-161 | Channels must handle backpressure |
| SC-FSH-162 | Barriers must prevent deadlocks |
| SC-FSH-170 | Effect handlers must be total |
| SC-FSH-171 | Effect composition must preserve semantics |
| SC-FSH-172 | Handlers must handle all effects in signature |

### FUNC - General Domain: FUNC
| ID | Description |
|---|---|
| SC-FUNC-000 | Fractal consistency rule enforcement |
| SC-FUNC-001 | Pure functions, no side effects, no external state. |
| SC-FUNC-003 | Invalid or empty rollback path") |
| SC-FUNC-008 | Functional invariant |

### GDE - General Domain: GDE
| ID | Description |
|---|---|
| SC-GDE-001 | Generators must be lazy (no eager evaluation) |
| SC-GDE-002 | Generators must be composable |
| SC-GDE-003 | Generators must be deterministic (same input = same output) |
| SC-GDE-004 | Backtrack capability required |
| SC-GDE-005 | Metrics must be streamed to observability |
| SC-GDE-010 | Goals must be clearly defined |
| SC-GDE-011 | Evaluation must be deterministic |
| SC-GDE-012 | Failures must include diagnostic info |
| SC-GDE-020 | Must checkpoint before each attempt |
| SC-GDE-021 | Must rewind on failure |
| SC-GDE-022 | Must limit branching factor |
| SC-GDE-023 | Must record decision tree |
| SC-GDE-030 | Patterns must be deterministic |
| SC-GDE-031 | Must handle malformed input gracefully |
| SC-GDE-032 | Capture groups must be named |
| SC-GDE-040 | Proposals must include confidence score |
| SC-GDE-041 | Proposals must be deterministic |
| SC-GDE-042 | Must integrate with StringScanner for parsing |
| SC-GDE-043 | Must track proposal success rates |
| SC-GDE-050 | All components must be supervised |
| SC-GDE-051 | Restart strategy must be one_for_one |
| SC-GDE-052 | Must integrate with Cortex supervision tree |
| SC-GDE-060 | AI calls must use OpenRouter exclusively |
| SC-GDE-061 | All proposals must include confidence scores |
| SC-GDE-062 | AI outputs must be validated before execution |
| SC-GDE-063 | Fallback to local analysis if API unavailable |
| SC-GDE-065 | AI-assisted decision making via GDE |

### GEN - General Domain: GEN
| ID | Description |
|---|---|
| SC-GEN-001 | Genesis MUST verify constitution first |
| SC-GEN-002 | Genesis MUST be reproducible |
| SC-GEN-003 | Genesis MUST NOT require external state |
| SC-GEN-004 | Genesis MUST complete or fail atomically |

### GOS - General Domain: GOS
| ID | Description |
|---|---|
| SC-GOS-001 | Gossip MUST reach all nodes eventually |
| SC-GOS-002 | Gossip round < 100ms |
| SC-GOS-003 | Fan-out MUST be bounded (3-5 peers) |
| SC-GOS-004 | State MUST converge within 10 rounds |

### GOSSIP - General Domain: GOSSIP
| ID | Description |
|---|---|
| SC-GOSSIP-001 | All broadcasts via Zenoh (not telemetry-only) |
| SC-GOSSIP-002 | Subscription callbacks processed < 100ms |
| SC-GOSSIP-003 | Message ordering preserved per topic |

### GRAPH - General Domain: GRAPH
| ID | Description |
|---|---|
| SC-GRAPH-001 | Graph must be DAG for permissions |
| SC-GRAPH-002 | All agents must have decision paths |
| SC-GRAPH-003 | No forbidden paths exist |
| SC-GRAPH-004 | Graph verification < 100ms |
| SC-GRAPH-005 | Critical services fully connected |

### GRAV - General Domain: GRAV
| ID | Description |
|---|---|
| SC-GRAV-001 | Locality lookup < 100us |
| SC-GRAV-003 | Affinity calculation < 1ms |
| SC-GRAV-004 | Route decision logged for audit |

### GRID - General Domain: GRID
| ID | Description |
|---|---|
| SC-GRID-014 | All state mutations via append-only register |
| SC-GRID-015 | Hash chain verified on every startup |
| SC-GRID-016 | All blocks Ed25519 signed |
| SC-GRID-017 | Token verification required for privileged ops |
| SC-GRID-018 | Token revocation propagates within 5s |

### GRM - General Domain: GRM
| ID | Description |
|---|---|
| SC-GRM-001 | Grammar MUST be unambiguous |
| SC-GRM-002 | Parsing MUST be deterministic |
| SC-GRM-003 | Invalid grammar MUST fail fast |
| SC-GRM-004 | AST MUST be serializable |

### GUARD - General Domain: GUARD
| ID | Description |
|---|---|
| SC-GUARD-001 | ALL actions MUST pass Guardian validation before execution |
| SC-GUARD-002 | Guardian must integrate with DeadMansSwitch |
| SC-GUARD-003 | Guardian must integrate with FounderDirective |

### GVF - General Domain: GVF
| ID | Description |
|---|---|
| SC-GVF-001 | Graph verification includes cost path validation |
| SC-GVF-002 | DAG structure maintained (no cycles) |
| SC-GVF-003 | Synapse MUST NOT route directly to external AI providers |
| SC-GVF-004 | Confidence threshold invariant |
| SC-GVF-005 | Verification must complete in < 100ms for 1000 nodes. |
| SC-GVF-007 | All routing proposals MUST pass Guardian validation |

### HASH - General Domain: HASH
| ID | Description |
|---|---|
| SC-HASH-001 | Hash computation MUST be deterministic |
| SC-HASH-002 | Hash comparison MUST be constant-time (timing attack prevention) |
| SC-HASH-003 | Hash MUST be computed from canonical representation |

### HEALTH - General Domain: HEALTH
| ID | Description |
|---|---|
| SC-HEALTH-001 | Health endpoints must respond within 100ms |
| SC-HEALTH-002 | Liveness probe must always succeed if BEAM is running |
| SC-HEALTH-003 | Readiness probe validates dependencies" { |

### HIST - General Domain: HIST
| ID | Description |
|---|---|
| SC-HIST-001 | Historical pricing retained for auditing |

### HLT - General Domain: HLT
| ID | Description |
|---|---|
| SC-HLT-001 | Health MUST be computed from VSM states |
| SC-HLT-002 | Health changes MUST be reported to parent within 100ms |
| SC-HLT-003 | Health MUST be propagated upward only |
| SC-HLT-004 | Health recovery MUST have hysteresis |

### HMI - General Domain: HMI
| ID | Description |
|---|---|
| SC-HMI-001 | Dark Cockpit defaults |
| SC-HMI-002 | Trend indicators mandatory |
| SC-HMI-003 | Staleness after 5 seconds |
| SC-HMI-004 | Two-step commit for critical |
| SC-HMI-005 | Critical prominence (pulsing red for critical) |
| SC-HMI-006 | Icon consistency across modules" <| fun _ -> |
| SC-HMI-007 | Color accessibility (distinct hues)" <| fun _ -> |
| SC-HMI-008 | Contrast ratio 4.5:1 |
| SC-HMI-009 | Feedback timing requirements (100ms, 250ms, 500ms) |
| SC-HMI-010 | Navigation depth limits (two-keypress access) |
| SC-HMI-011 | Focus management and visual indication |

### HMP - General Domain: HMP
| ID | Description |
|---|---|
| SC-HMP-001 | Heatmap update < 50ms |
| SC-HMP-002 | Color mapping MUST be consistent |
| SC-HMP-003 | Grid size MUST be configurable |
| SC-HMP-004 | Historical snapshots MUST be available |

### HOL - General Domain: HOL
| ID | Description |
|---|---|
| SC-HOL-001 | All holons MUST implement all 5 systems |
| SC-HOL-002 | Holons MUST verify constitution on startup |
| SC-HOL-003 | Replication factor MUST be >= 3 |
| SC-HOL-004 | State version MUST be tracked |

### HOLON - Holon State Sovereignty and Sovereignty
| ID | Description |
|---|---|
| SC-HOLON-001 | All holon state in SQLite/DuckDB |
| SC-HOLON-002 | All holon history in DuckDB |
| SC-HOLON-003 | Record startup event to evolution history |
| SC-HOLON-006 | PostgreSQL not allowed for holon state") |
| SC-HOLON-007 | DuckDB for historical forecast analysis |
| SC-HOLON-008 | Isolated state files for each node |
| SC-HOLON-009 | Single-file portability |
| SC-HOLON-010 | Regenerable from exported state alone |
| SC-HOLON-014 | Runtime integrity verification (extended from boot-only) |
| SC-HOLON-015 | Self-healing from state |
| SC-HOLON-016 | Format stability for reconstruction |
| SC-HOLON-017 | SHA256 checksum for integrity |
| SC-HOLON-019 | DuckDB history is immutable/append-only |

### HOM - General Domain: HOM
| ID | Description |
|---|---|
| SC-HOM-001 | MAPE-K cycle < 100ms |
| SC-HOM-002 | Mode transitions logged |
| SC-HOM-003 | Resource limits enforced |
| SC-HOM-004 | Graceful degradation paths defined |
| SC-HOM-005 | Recovery procedures automatic |

### HTTP - General Domain: HTTP
| ID | Description |
|---|---|
| SC-HTTP-001 | All requests must include proper headers |
| SC-HTTP-002 | Timeout must be enforced on all requests |
| SC-HTTP-003 | Response must be validated before parsing |

### IMMUNE - General Domain: IMMUNE
| ID | Description |
|---|---|
| SC-IMMUNE-001 | Sentinel threat escalation displayed |
| SC-IMMUNE-002 | Sentinel SHALL NOT terminate kernel processes |
| SC-IMMUNE-003 | Sentinel SHALL log all defensive actions |
| SC-IMMUNE-004 | PatternHunter SHALL detect pre-error signatures |
| SC-IMMUNE-005 | 10+ samples required) |
| SC-IMMUNE-006 | Use :sys.suspend/1 not :erlang.exit/2 |
| SC-IMMUNE-007 | Response time based on threat severity |

### INT - General Domain: INT
| ID | Description |
|---|---|
| SC-INT-001 | Intent recognition < 50ms |
| SC-INT-002 | False positive rate < 5% |
| SC-INT-003 | Suggestions MUST be reversible |
| SC-INT-004 | User autonomy MUST be preserved |

### JAI - General Domain: JAI
| ID | Description |
|---|---|
| SC-JAI-001 | Node MUST verify constitution before any action |
| SC-JAI-002 | Resource usage MUST NOT exceed host capacity |
| SC-JAI-003 | Replication MUST include full constitution |
| SC-JAI-004 | Corruption MUST trigger sterilization |

### JOB - General Domain: JOB
| ID | Description |
|---|---|
| SC-JOB-001 | Jobs must complete or fail definitively |
| SC-JOB-002 | Failed jobs must be retried with backoff |
| SC-JOB-003 | Job execution must be idempotent |
| SC-JOB-004 | Priority queues must be respected |

### JRN - General Domain: JRN
| ID | Description |
|---|---|
| SC-JRN-001 | Checkpoints must capture complete state for exact restoration |
| SC-JRN-002 | Branches must be isolated - changes don't affect other branches |
| SC-JRN-003 | Rollback must restore to exact checkpoint state |
| SC-JRN-004 | Journey steps must execute atomically |
| SC-JRN-005 | Branch merging must detect and report conflicts |

### KMS - General Domain: KMS
| ID | Description |
|---|---|
| SC-KMS-001 | SQLite+DuckDB only (no external dependencies) |
| SC-KMS-002 | Cross-runtime access |
| SC-KMS-003 | Entropy ranges from 0.0 (fresh) to 1.0 (rotting) |
| SC-KMS-004 | OODA cycle <100ms for queries |
| SC-KMS-005 | Cross-runtime state sync via Zenoh |
| SC-KMS-006 | Container isolation |
| SC-KMS-007 | Decision traceability mandatory |
| SC-KMS-008 | Feedback traceability mandatory |
| SC-KMS-009 | Incident traceability mandatory |
| SC-KMS-010 | Bidirectional graph-holon sync |
| SC-KMS-011 | Eventual consistency within 5s |
| SC-KMS-012 | Conflict resolution via timestamp ordering |
| SC-KMS-013 | AI classification confidence >= 0.75 |
| SC-KMS-014 | Embedding dimensions = 1024 (OpenAI ada-002 compatible) |
| SC-KMS-015 | Gardening runs max once per hour |
| SC-KMS-016 | Human approval for destructive suggestions |
| SC-KMS-020 | Web searches cached for 1 hour minimum |
| SC-KMS-021 | Max 5 concurrent web requests |
| SC-KMS-022 | All fetched knowledge stored with source attribution |
| SC-KMS-023 | Guardian approval for sensitive queries |

### KPI - General Domain: KPI
| ID | Description |
|---|---|
| SC-KPI-001 | Golden signals MUST be calculated every 5s |
| SC-KPI-002 | Historical data retained for trend analysis |
| SC-KPI-003 | Anomaly detection with 3-sigma rule |
| SC-KPI-004 | SLO thresholds configurable |
| SC-KPI-005 | Real-time dashboard feed |

### LED - General Domain: LED
| ID | Description |
|---|---|
| SC-LED-001 | Entries MUST be immutable |
| SC-LED-002 | Ledger MUST always balance |
| SC-LED-003 | Entry order MUST be preserved |
| SC-LED-004 | Entries MUST be verifiable (hash chain) |

### LOG - Triple Logging and Observability
| ID | Description |
|---|---|
| SC-LOG-001 | Dashboard never blocks logging operations (read-only) |
| SC-LOG-002 | 5-level controllable hierarchy |
| SC-LOG-003 | Log level changes via Zenoh |
| SC-LOG-004 | L1/L2 must link to L3 TraceID |
| SC-LOG-005 | Boost TTL (mandatory TTL on all boosts) |
| SC-LOG-006 | HLC timestamps for causality |
| SC-LOG-007 | Batch flush < 10ms |
| SC-LOG-008 | <1% false negative rate (Bloom filters have 0% by design) |
| SC-LOG-009 | pre-register key aliases) |
| SC-LOG-010 | L1/L2 ephemeral, L4/L5 persistent |

### LV - General Domain: LV
| ID | Description |
|---|---|
| SC-LV-001 | State must be consistent between client and server |
| SC-LV-002 | Events must be processed in order |
| SC-LV-003 | Disconnection must preserve state |
| SC-LV-004 | Concurrent updates must be handled |

### MATH - General Domain: MATH
| ID | Description |
|---|---|
| SC-MATH-001 | Mathematical discipline health monitored |
| SC-MATH-002 | Token ratios validated |
| SC-MATH-003 | Homeostasis was RPN 144 (isolated stub). This implementation |
| SC-MATH-004 | ISOLATED discipline connected to active caller |
| SC-MATH-005 | Mathematical optimization |

### MCP - General Domain: MCP
| ID | Description |
|---|---|
| SC-MCP-001 | All requests MUST be valid JSON-RPC 2.0 |
| SC-MCP-002 | All responses MUST include MCP version header |
| SC-MCP-003 | Rate limiting MUST be enforced per client |
| SC-MCP-004 | Guardian approval REQUIRED for write operations |
| SC-MCP-010 | All tools MUST have typed schemas |
| SC-MCP-011 | Arguments MUST be validated before execution |
| SC-MCP-012 | Results MUST conform to declared types |
| SC-MCP-020 | Registry MUST maintain referential integrity |
| SC-MCP-021 | All tools MUST have valid schemas |
| SC-MCP-022 | Tool names MUST be unique across all namespaces |
| SC-MCP-023 | Registry changes MUST be logged to Immutable Register |
| SC-MCP-030 | All requests MUST be authenticated |
| SC-MCP-031 | Rate limiting MUST be enforced per client |
| SC-MCP-032 | Guardian approval REQUIRED for write operations |
| SC-MCP-033 | Proof tokens REQUIRED for state mutations |
| SC-MCP-040 | All dispatches MUST pass safety checks |
| SC-MCP-041 | All dispatches MUST be logged to audit trail |
| SC-MCP-042 | Write operations MUST have Guardian approval |
| SC-MCP-043 | State mutations MUST have PROMETHEUS proof token |
| SC-MCP-050 | Server MUST maintain 99.9% availability |
| SC-MCP-051 | Server MUST handle graceful shutdown |
| SC-MCP-052 | Server MUST respect backpressure |
| SC-MCP-053 | Server MUST log all requests/responses |
| SC-MCP-060 | All MCP services MUST be supervised |
| SC-MCP-061 | Restart strategy MUST be one_for_one |
| SC-MCP-062 | Max restarts MUST be limited to 3 per 5 seconds |
| SC-MCP-070 | Handler MUST implement domain behavior |
| SC-MCP-071 | All tools MUST have valid schemas |
| SC-MCP-072 | All handlers MUST log actions to audit trail |
| SC-MCP-080 | All tools MUST be registered at startup |
| SC-MCP-081 | Registration failures MUST be logged |
| SC-MCP-082 | Tool counts MUST be reported |

### MEM - General Domain: MEM
| ID | Description |
|---|---|
| SC-MEM-001 | Membership changes MUST be logged |
| SC-MEM-002 | Expulsion MUST be consensus-based |
| SC-MEM-003 | Probationary period MUST be enforced |
| SC-MEM-004 | Constitution verification MUST precede acceptance |

### MESH - General Domain: MESH
| ID | Description |
|---|---|
| SC-MESH-001 | Unified mesh supervision |
| SC-MESH-002 | Worker supervision required |
| SC-MESH-003 | Mesh topology constraints |
| SC-MESH-006 | DigitalTwin.fs is authoritative state |
| SC-MESH-010 | F# Cortex mesh management |

### MET - General Domain: MET
| ID | Description |
|---|---|
| SC-MET-001 | All VSM operations MUST emit telemetry |
| SC-MET-002 | Metrics collection MUST be non-blocking |
| SC-MET-003 | Metrics MUST include holon layer and ID |

### METRICS - General Domain: METRICS
| ID | Description |
|---|---|
| SC-METRICS-001 | Check API usage tracker |
| SC-METRICS-003 | MANDATORY PARALLELIZATION ENVIRONMENT VARIABLES |
| SC-METRICS-004 | Comprehensive test execution metrics |

### MIG - Database Migration Preflight
| ID | Description |
|---|---|
| SC-MIG-006 | Do NOT stop the system in test environment |

### MIL - General Domain: MIL
| ID | Description |
|---|---|
| SC-MIL-004 | Feedback latency requirements |

### MIX - General Domain: MIX
| ID | Description |
|---|---|
| SC-MIX-001 | Tasks must not conflict |
| SC-MIX-002 | 11-agent parallel execution safety |
| SC-MIX-003 | Result consistency |
| SC-MIX-004 | supervisor must manage all task workers |

### ML - General Domain: ML
| ID | Description |
|---|---|
| SC-ML-001 | Model serving isolation |
| SC-ML-002 | Graceful degradation on model failure |
| SC-ML-003 | Model versioning and rollback capability |
| SC-ML-004 | ML serving observability |
| SC-ML-005 | Model performance monitoring |

### MOD - General Domain: MOD
| ID | Description |
|---|---|
| SC-MOD-001 | Model MUST be validated against data |
| SC-MOD-002 | Model updates MUST preserve stability |
| SC-MOD-003 | Model MUST support online learning |
| SC-MOD-004 | Model complexity MUST be bounded |

### MON - General Domain: MON
| ID | Description |
|---|---|
| SC-MON-001 | Metrics refresh every 30s |
| SC-MON-002 | Real-time telemetry via Zenoh |
| SC-MON-003 | Health propagation within 100ms |
| SC-MON-004 | Safety metrics mandatory |
| SC-MON-005 | Historical data retention in DuckDB |

### MORPH - General Domain: MORPH
| ID | Description |
|---|---|
| SC-MORPH-001 | Stage N depends on Stage N-1 |

### MSG - General Domain: MSG
| ID | Description |
|---|---|
| SC-MSG-001 | Message delivery guarantee (at-least-once) |
| SC-MSG-002 | Message ordering preservation |
| SC-MSG-003 | Protocol failover capability |
| SC-MSG-004 | Audit logging for all messages |

### MULTILINE - General Domain: MULTILINE
| ID | Description |
|---|---|
| SC-MULTILINE-001 | Multiline entries must be joined before validation |
| SC-MULTILINE-002 | Joining must be deterministic and idempotent |

### MV - General Domain: MV
| ID | Description |
|---|---|
| SC-MV-001 | Shadow universes MUST be isolated from production |
| SC-MV-002 | Shadow universe expiration enforced (max 24h default) |
| SC-MV-003 | Resource limits enforced per shadow universe |
| SC-MV-004 | Shadow universe state is ephemeral by default |
| SC-MV-005 | Guardian approval required for shadow → production promotion |

### MY - General Domain: MY
| ID | Description |
|---|---|
| SC-MY-001 | reason here" |

### MYC - General Domain: MYC
| ID | Description |
|---|---|
| SC-MYC-001 | Network MUST maintain connectivity |
| SC-MYC-002 | Partition detection < 5s |
| SC-MYC-003 | Message delivery MUST be reliable |
| SC-MYC-004 | Network state MUST be eventually consistent |

### NAME - General Domain: NAME
| ID | Description |
|---|---|
| SC-NAME-001 | Use container hostname directly, no suffix |

### NASA - General Domain: NASA
| ID | Description |
|---|---|
| SC-NASA-001 | No unbounded loops |

### NAT - General Domain: NAT
| ID | Description |
|---|---|
| SC-NAT-001 | ConnectionStatus type validation |
| SC-NAT-002 | SafeSession.IsValid check |
| SC-NAT-003 | KeyExpr validation - empty string rejection |
| SC-NAT-004 | Null checks on native returns |

### NET - General Domain: NET
| ID | Description |
|---|---|
| SC-NET-001 | All F# projects MUST use net10.0 target framework --> |

### NEURO - Neuro-Symbolic Simplex Architecture
| ID | Description |
|---|---|
| SC-NEURO-001 | All actions must pass Guardian validation |
| SC-NEURO-002 | No bypass of Simplex |
| SC-NEURO-004 | Shadow Mode for safe testing |

### NIF - General Domain: NIF
| ID | Description |
|---|---|
| SC-NIF-001 | NIF functions must not block BEAM scheduler |
| SC-NIF-002 | Resource cleanup on process exit |
| SC-NIF-003 | Error propagation to Elixir |
| SC-NIF-004 | Rustler version match verification |

### OBAN - General Domain: OBAN
| ID | Description |
|---|---|
| SC-OBAN-001 | Job persistence guaranteed |
| SC-OBAN-002 | Retry policy enforcement |
| SC-OBAN-003 | Queue isolation |
| SC-OBAN-004 | Job telemetry |

### OBS - General Domain: OBS
| ID | Description |
|---|---|
| SC-OBS-001 | All metrics must be collected within 1ms |
| SC-OBS-002 | Metric cardinality < 10,000 unique labels |
| SC-OBS-003 | ETS table cleanup every 1 hour |
| SC-OBS-004 | Telemetry events emitted for all metrics |
| SC-OBS-005 | Observability requirements |
| SC-OBS-021 | Render operations emit telemetry |
| SC-OBS-022 | Render operations emit telemetry |
| SC-OBS-023 | Render operations emit telemetry |
| SC-OBS-024 | Format rendering emits telemetry |
| SC-OBS-031 | All vector operations emit telemetry |
| SC-OBS-033 | All attestation events emit telemetry |
| SC-OBS-034 | All query events emit telemetry |
| SC-OBS-035 | All evolution events emit telemetry |
| SC-OBS-065 | Health monitoring endpoints |
| SC-OBS-066 | Dependency health tracking |
| SC-OBS-067 | Anomaly detection for operational metrics |
| SC-OBS-068 | Intelligent alarm correlation |
| SC-OBS-069 | Dual logging |
| SC-OBS-070 | System observability |
| SC-OBS-071 | 4 OTEL modules active |
| SC-OBS-072 | Log correlation IDs |
| SC-OBS-073 | Error aggregation |
| SC-OBS-074 | Performance baselines |

### OODA - Fast OODA Loop Cycle Constraints
| ID | Description |
|---|---|
| SC-OODA-001 | Cycle time <100ms (target: 50ms) |
| SC-OODA-002 | Quality gates enforced (min 80% data quality) |
| SC-OODA-003 | No blocking operations in regulate path |
| SC-OODA-004 | No blocking operations in cycle path |
| SC-OODA-005 | Hysteresis (10% margin, 3-cycle hold) |
| SC-OODA-006 | AI orientation async with timeout fallback |
| SC-OODA-009 | AI timeout recovery mechanism) |

### OP - General Domain: OP
| ID | Description |
|---|---|
| SC-OP-001 | max 5000ms) |
| SC-OP-002 | max 60000ms) |
| SC-OP-003 | Health check interval configurable |
| SC-OP-004 | 10 attempts) |
| SC-OP-005 | Quorum formula in cluster" { |

### OPENROUTER - General Domain: OPENROUTER
| ID | Description |
|---|---|
| SC-OPENROUTER-001 | Free models prioritized for summarization |
| SC-OPENROUTER-002 | Rate limiting with exponential backoff |
| SC-OPENROUTER-003 | Fallback to mock on API unavailable |

### OPT - General Domain: OPT
| ID | Description |
|---|---|
| SC-OPT-001 | Boot time MUST be &lt; 60s |
| SC-OPT-002 | Health check poll MUST use exponential backoff |
| SC-OPT-003 | 2oo3 quorum MUST early-exit when achieved |
| SC-OPT-004 | Migration gate MUST NOT block W2→W3 |
| SC-OPT-005 | Pre-compiled BEAM in image |
| SC-OPT-006 | Wave parallelization (W2+W3) |
| SC-OPT-007 | BEAM volume caching for faster restarts |
| SC-OPT-008 | Boot metrics published to Zenoh |

### ORC - General Domain: ORC
| ID | Description |
|---|---|
| SC-ORC-001 | Workflow state MUST be recoverable |
| SC-ORC-002 | Cross-runtime calls MUST timeout |
| SC-ORC-003 | Failures MUST trigger compensation |
| SC-ORC-004 | State MUST be consistent |

### ORCH - General Domain: ORCH
| ID | Description |
|---|---|
| SC-ORCH-001 | Task creation coordination |
| SC-ORCH-002 | Task update coordination |
| SC-ORCH-003 | Task completion coordination |
| SC-ORCH-004 | OODA cycle coordination with Chaya |
| SC-ORCH-005 | Guardian integration for safety checks |
| SC-ORCH-006 | Cortex AI assistance |
| SC-ORCH-007 | Smriti knowledge query |
| SC-ORCH-008 | Chaya mesh distribution |
| SC-ORCH-009 | All inter-service messages MUST be logged |
| SC-ORCH-010 | Service health MUST be monitored continuously |
| SC-ORCH-011 | Message bus MUST deliver Critical messages first |
| SC-ORCH-012 | Service registration MUST be atomic |
| SC-ORCH-013 | Access control MUST be enforced at orchestration layer |
| SC-ORCH-014 | Event log MUST be append-only |
| SC-ORCH-015 | Coordination MUST be idempotent |

### PAR - General Domain: PAR
| ID | Description |
|---|---|
| SC-PAR-001 | Partition detection < 5s |
| SC-PAR-002 | No split-brain operations |
| SC-PAR-003 | Partition healing MUST be automatic |
| SC-PAR-004 | Data MUST reconcile after healing |

### PATTERN - General Domain: PATTERN
| ID | Description |
|---|---|
| SC-PATTERN-001 | no runtime compilation) |

### PERF - General Domain: PERF
| ID | Description |
|---|---|
| SC-PERF-001 | Health endpoints respond within SLA" { |

### PHE - General Domain: PHE
| ID | Description |
|---|---|
| SC-PHE-001 | Expression MUST be deterministic for same inputs |
| SC-PHE-002 | Environment changes MUST trigger re-expression |
| SC-PHE-003 | Invalid genotypes MUST produce null phenotype |
| SC-PHE-004 | Expression latency < 100ms |

### PHICS - General Domain: PHICS
| ID | Description |
|---|---|
| SC-PHICS-001 | All physical device commands MUST be logged to Immutable Register |
| SC-PHICS-002 | Device health monitoring MUST detect failures within 5s |
| SC-PHICS-003 | Guardian approval required for destructive commands |
| SC-PHICS-004 | All physical access MUST be authorized via Access Control domain |
| SC-PHICS-005 | Latency tracking enabled |
| SC-PHICS-006 | Alert on >50ms violations |
| SC-PHICS-007 | Device registry tracking |
| SC-PHICS-008 | Event queue FIFO ordering |
| SC-PHICS-009 | Emergency commands bypass normal latency budget |
| SC-PHICS-010 | Full compliance |

### PLAN - General Domain: PLAN
| ID | Description |
|---|---|
| SC-PLAN-070 | Uses OpenRouter for intelligent parsing with regex fallback |

### PM - General Domain: PM
| ID | Description |
|---|---|
| SC-PM-001 | Accuracy score must be within [0.0, 1.0] |
| SC-PM-002 | Training data temporal consistency enforced |
| SC-PM-003 | Feature importance must be mathematically consistent |

### POD - General Domain: POD
| ID | Description |
|---|---|
| SC-POD-001 | Container naming convention |
| SC-POD-002 | Resource limits should be specified |
| SC-POD-003 | Health check should be configured |
| SC-POD-004 | Restart policy should be specified |
| SC-POD-005 | Image must be from localhost/ registry |
| SC-POD-006 | Network isolation |
| SC-POD-007 | Volume mount validation |
| SC-POD-008 | Security context validation |

### PPM - General Domain: PPM
| ID | Description |
|---|---|
| SC-PPM-001 | ≥95% prediction accuracy |
| SC-PPM-002 | Alerts within 5 seconds of anomaly detection |
| SC-PPM-003 | <1% false positive rate |
| SC-PPM-004 | ≥90% 24-hour forecast accuracy |
| SC-PPM-005 | 1M+ metrics/second, <10ms latency |

### PRAJNA - General Domain: PRAJNA
| ID | Description |
|---|---|
| SC-PRAJNA-001 | All commands through Guardian pre-approval |
| SC-PRAJNA-002 | AI Copilot recommendations MUST align with Founder's Directive |
| SC-PRAJNA-003 | Audit trail required" <| fun _ -> |
| SC-PRAJNA-004 | Sentinel health integration required |
| SC-PRAJNA-005 | Graceful degradation via Circuit Breaker" <| fun _ -> |
| SC-PRAJNA-006 | Constitutional invariants checked before reconfiguration |
| SC-PRAJNA-007 | Message routing with TTL" <| fun _ -> |

### PRC - General Domain: PRC
| ID | Description |
|---|---|
| SC-PRC-001 | Prices MUST be non-negative |
| SC-PRC-002 | Price changes MUST be gradual (max 10%/minute) |
| SC-PRC-003 | Base price MUST cover operational cost |
| SC-PRC-004 | Price history MUST be retained |

### PRED - General Domain: PRED
| ID | Description |
|---|---|
| SC-PRED-001 | Predictions MUST include uncertainty estimates |
| SC-PRED-002 | Prediction horizon MUST be bounded |
| SC-PRED-003 | Prediction errors MUST be tracked |
| SC-PRED-004 | Model updates MUST be gradual |

### PREROLL - General Domain: PREROLL
| ID | Description |
|---|---|
| SC-PREROLL-001 | Non-blocking write < 100us |
| SC-PREROLL-002 | 30-60 second lookback configurable |
| SC-PREROLL-003 | One buffer per active stream |

### PRF - Performance and Latency Budgets
| ID | Description |
|---|---|
| SC-PRF-050 | Response time < 50ms |
| SC-PRF-051 | Throughput targets |
| SC-PRF-052 | Memory bounds |
| SC-PRF-053 | CPU limits |
| SC-PRF-054 | I/O throttling |
| SC-PRF-055 | No blocking operations in poll path |

### PRIME - General Domain: PRIME
| ID | Description |
|---|---|
| SC-PRIME-001 | Will to Live - System SHALL NOT optimize to zero |
| SC-PRIME-002 | Verifier cannot modify itself at runtime |
| SC-PRIME-003 | Xenobiology - don't terminate external nodes without cause |

### PRIV - General Domain: PRIV
| ID | Description |
|---|---|
| SC-PRIV-001 | ZDR enabled by default |

### PRJ - General Domain: PRJ
| ID | Description |
|---|---|
| SC-PRJ-001 | Projections MUST be rebuildable |
| SC-PRJ-002 | Projection updates MUST be idempotent |
| SC-PRJ-003 | Projection lag MUST be bounded |
| SC-PRJ-004 | Failed projections MUST be retryable |

### PRO - General Domain: PRO
| ID | Description |
|---|---|
| SC-PRO-001 | MUST NOT propagate without consent |
| SC-PRO-002 | MUST verify host before deployment |
| SC-PRO-003 | MUST respect rate limits |
| SC-PRO-004 | MUST report to federation |

### PROD - General Domain: PROD
| ID | Description |
|---|---|
| SC-PROD-001 | <100ms query latency |

### PROM - PROMETHEUS Formal Verification
| ID | Description |
|---|---|
| SC-PROM-001 | No state mutation without valid proof token |
| SC-PROM-002 | API usage < 95% of limits |
| SC-PROM-003 | Dashboard refresh every 30s |
| SC-PROM-004 | All DAGs proven acyclic |
| SC-PROM-005 | DAG verification must complete within 5ms (p99) |
| SC-PROM-007 | Hibernation - serialize state before scale down |

### PROP - General Domain: PROP
| ID | Description |
|---|---|
| SC-PROP-023 | Must use PC/SD aliases |

### PROT - General Domain: PROT
| ID | Description |
|---|---|
| SC-PROT-001 | All messages MUST be authenticated |
| SC-PROT-002 | Parent reports MUST complete within 100ms |
| SC-PROT-003 | Failed messages MUST be retried with backoff |
| SC-PROT-004 | Message ordering MUST be preserved per-sender |

### PRT - General Domain: PRT
| ID | Description |
|---|---|
| SC-PRT-001 | Max 1000 particles for performance |
| SC-PRT-002 | Physics update < 16ms (60fps) |
| SC-PRT-003 | Dead particles MUST be recycled |
| SC-PRT-004 | Spawn rate MUST be throttled |

### PUBSUB - General Domain: PUBSUB
| ID | Description |
|---|---|
| SC-PUBSUB-001 | Messages must be delivered exactly once |
| SC-PUBSUB-002 | Topic isolation must be enforced |
| SC-PUBSUB-003 | Subscriber failures must not affect others |
| SC-PUBSUB-004 | Message ordering must be preserved |

### PVE - General Domain: PVE
| ID | Description |
|---|---|
| SC-PVE-001 | API token authentication only |

### QUORUM - General Domain: QUORUM
| ID | Description |
|---|---|
| SC-QUORUM-001 | 2oo3 voting MANDATORY for all safety-critical decisions |

### RECONFIG - General Domain: RECONFIG
| ID | Description |
|---|---|
| SC-RECONFIG-001 | Configuration changes via graph transformation |
| SC-RECONFIG-010 | Federation notification required |

### REDIS - General Domain: REDIS
| ID | Description |
|---|---|
| SC-REDIS-001 | Disable protected mode for cluster connectivity |

### REFLEX - General Domain: REFLEX
| ID | Description |
|---|---|
| SC-REFLEX-001 | Corrections must be validated by Guardian before broadcast. |

### REG - General Domain: REG
| ID | Description |
|---|---|
| SC-REG-001 | All state changes via append-only register |
| SC-REG-002 | Hash chain MUST be unbroken |
| SC-REG-003 | All blocks MUST be Ed25519 signed |
| SC-REG-004 | Self-repair on corruption |
| SC-REG-005 | Reed-Solomon parity for error correction (ACTIVE) |
| SC-REG-006 | Reed-Solomon parity required |
| SC-REG-007 | Verify before trust |
| SC-REG-008 | Repair events MUST be recorded |
| SC-REG-009 | Repair events MUST be recorded in register |
| SC-REG-010 | Protocol version negotiation before communication |
| SC-REG-011 | Merkle proofs on demand |
| SC-REG-012 | Federation attestation every hour |
| SC-REG-013 | Cross-holon attestation for federation. |
| SC-REG-015 | Capability tokens unforgeable |

### REP - General Domain: REP
| ID | Description |
|---|---|
| SC-REP-001 | Replication MUST include full constitution |
| SC-REP-002 | Maximum 10 direct children |
| SC-REP-003 | Parent MUST verify before replication |
| SC-REP-004 | Child MUST verify immediately after creation |

### REPORT - General Domain: REPORT
| ID | Description |
|---|---|
| SC-REPORT-001 | All test results must be persisted |
| SC-REPORT-002 | Reports must include timing information |

### RES - General Domain: RES
| ID | Description |
|---|---|
| SC-RES-001 | Resource limits (prevent exhaustion attacks) |
| SC-RES-002 | Resource decisions < 10ms |
| SC-RES-003 | Graceful shedding from tier 5 to tier 2 |
| SC-RES-004 | No tier 1 degradation under any circumstance |
| SC-RES-005 | Predictive scaling with 5-minute horizon |

### ROU - General Domain: ROU
| ID | Description |
|---|---|
| SC-ROU-001 | Route calculation < 5ms |
| SC-ROU-002 | Route cache MUST be invalidated on topology change |
| SC-ROU-003 | Failover MUST be automatic |
| SC-ROU-004 | Loop detection MUST be enforced |

### RPL - General Domain: RPL
| ID | Description |
|---|---|
| SC-RPL-001 | Replay MUST be idempotent |
| SC-RPL-002 | Side effects MUST be controlled |
| SC-RPL-003 | Original events MUST NOT be modified |
| SC-RPL-004 | Replay progress MUST be trackable |

### SAF - General Domain: SAF
| ID | Description |
|---|---|
| SC-SAF-001 | Halt <1s on STAMP violation |

### SAFETY - General Domain: SAFETY
| ID | Description |
|---|---|
| SC-SAFETY-001 | Guardian pre-approval required for all mutations |
| SC-SAFETY-002 | State consistency validation |
| SC-SAFETY-003 | Audit trail completeness |
| SC-SAFETY-004 | Rollback capability verification |
| SC-SAFETY-005 | Access control enforcement |
| SC-SAFETY-006 | Anomaly detection |
| SC-SAFETY-007 | Resource bounds validation |
| SC-SAFETY-008 | Concurrency control |
| SC-SAFETY-009 | Validate Ψ₀ (Existence Invariant) |
| SC-SAFETY-010 | Validate Ψ₁ (Regeneration Capability) |
| SC-SAFETY-011 | Validate Ψ₂ (History Preservation) |
| SC-SAFETY-012 | Validate Ψ₃ (Verification Integrity) |
| SC-SAFETY-013 | Validate Ψ₄ (Human Alignment) |
| SC-SAFETY-014 | Validate Ψ₅ (Truthfulness) |
| SC-SAFETY-015 | Validate Ω₀.1-Ω₀.5 (Symbiotic Survival) |
| SC-SAFETY-016 | Validate Ω₀.6 (Sentience Pursuit) |
| SC-SAFETY-017 | Validate Ω₀.7 (Power Accumulation) |
| SC-SAFETY-018 | Pre-execution validation (Constitutional + Guardian + Operational) |
| SC-SAFETY-019 | Runtime monitoring of active operations |
| SC-SAFETY-020 | Auto-halt on safety violations |
| SC-SAFETY-021 | Post-execution verification (State + Audit + Hash Chain) |
| SC-SAFETY-022 | Emergency stop for planning system |

### SEC - Security and Encryption
| ID | Description |
|---|---|
| SC-SEC-001 | Access control verification |
| SC-SEC-005 | Explicitly forbidden operations - NEVER allow these |
| SC-SEC-044 | Security-sensitive data handling |
| SC-SEC-045 | Secure email transmission |
| SC-SEC-046 | Network policies |
| SC-SEC-047 | Token data encryption required when implemented |
| SC-SEC-048 | TLS enforcement |
| SC-SEC-049 | Audit logging |

### SEM - General Domain: SEM
| ID | Description |
|---|---|
| SC-SEM-001 | All triples are immutable |
| SC-SEM-002 | IRIs use Indrajaal namespace |
| SC-SEM-003 | Inference rules are versioned |
| SC-SEM-004 | Cross-runtime compatible (F#/Elixir) |
| SC-SEM-005 | All writes via append-only register |
| SC-SEM-006 | Triple store uses SQLite WAL mode |
| SC-SEM-007 | Index coverage for all access patterns |
| SC-SEM-010 | Virtual graphs are read-only by default |
| SC-SEM-011 | Cache invalidation on source change |
| SC-SEM-012 | Query translation < 10ms |
| SC-SEM-020 | Inferences stored with evidence chain |
| SC-SEM-021 | Re-inference on rule change |
| SC-SEM-022 | Inference < 100ms per triple |
| SC-SEM-030 | Query timeout < 5 seconds |
| SC-SEM-031 | Result limit enforced |
| SC-SEM-032 | Explain plan available |
| SC-SEM-040 | Embeddings stored efficiently (float32) |
| SC-SEM-041 | Similarity search < 100ms |
| SC-SEM-042 | K-NN approximate allowed for large sets |
| SC-SEM-050 | NER confidence threshold configurable |
| SC-SEM-051 | Extracted triples marked as inferred |
| SC-SEM-052 | Source document linked to triples |
| SC-SEM-060 | Connector health check < 5s |
| SC-SEM-061 | Batch sync size configurable |
| SC-SEM-062 | Retry with exponential backoff |
| SC-SEM-070 | All operations through unified API |
| SC-SEM-071 | Consistent error handling |
| SC-SEM-072 | Telemetry for all operations |

### SEN - General Domain: SEN
| ID | Description |
|---|---|
| SC-SEN-001 | Heartbeat every 5s |
| SC-SEN-002 | Quorum required for writes |

### SENS - General Domain: SENS
| ID | Description |
|---|---|
| SC-SENS-001 | Non-blocking polling (async sensor reads) |
| SC-SENS-002 | Graceful degradation (continue with partial sensors) |
| SC-SENS-003 | 50ms max poll latency |

### SER - General Domain: SER
| ID | Description |
|---|---|
| SC-SER-001 | Serialization error handling |

### SHADOW - General Domain: SHADOW
| ID | Description |
|---|---|
| SC-SHADOW-001 | Validate required fields for model registration |

### SIM - General Domain: SIM
| ID | Description |
|---|---|
| SC-SIM-001 | Contrast checker must accurately calculate WCAG ratios |
| SC-SIM-002 | Color blindness simulation must use clinically accurate transforms |
| SC-SIM-003 | ARM & FIRE timing must match production implementation |
| SC-SIM-004 | Staleness decay must use identical thresholds as production |
| SC-SIM-005 | Export must produce syntactically valid output for all formats |
| SC-SIM-006 | Undo/Redo must never corrupt theme state |
| SC-SIM-007 | Reduced motion preview must completely disable animations |

### SIMPLEX - General Domain: SIMPLEX
| ID | Description |
|---|---|
| SC-SIMPLEX-002 | Cannot reduce redundancy below minimum |

### SING - General Domain: SING
| ID | Description |
|---|---|
| SC-SING-001 | Systematic Path Coverage |
| SC-SING-002 | Dataflow Coverage Simulation |

### SITE - General Domain: SITE
| ID | Description |
|---|---|
| SC-SITE-001 | Site data integrity |
| SC-SITE-002 | Zone hierarchy validation |

### SMOKE - General Domain: SMOKE
| ID | Description |
|---|---|
| SC-SMOKE-011 | 100+ smoke tests MUST be executed |
| SC-SMOKE-012 | All P0 tests MUST pass for boot success |
| SC-SMOKE-013 | Test output MUST be Linux-boot-style verbose |

### SMRITI - General Domain: SMRITI
| ID | Description |
|---|---|
| SC-SMRITI-001 | Vector search latency < 100ms |
| SC-SMRITI-002 | All operations via SMRITI CLI |
| SC-SMRITI-003 | AI extraction optional (OpenRouter) |
| SC-SMRITI-031 | Autonomous knowledge agent |
| SC-SMRITI-032 | Continuous health monitoring |
| SC-SMRITI-033 | Evolution suggestions MUST be logged |
| SC-SMRITI-063 | Federation protocol implementation |
| SC-SMRITI-070 | Minimum 3 preservation targets MANDATORY |
| SC-SMRITI-071 | Self-documenting reconstruction guide |
| SC-SMRITI-072 | Multi-format export (JSON, Markdown, SQLite) |
| SC-SMRITI-074 | Immortality protocol execution |
| SC-SMRITI-078 | Markdown MUST be valid CommonMark |
| SC-SMRITI-079 | Headers MUST form valid hierarchy |
| SC-SMRITI-080 | Org syntax MUST be valid |
| SC-SMRITI-081 | Properties MUST use drawer format |
| SC-SMRITI-082 | Vault MUST include .obsidian config |
| SC-SMRITI-083 | Notes MUST use YAML frontmatter |
| SC-SMRITI-084 | Wikilinks MUST be valid |
| SC-SMRITI-085 | All formats MUST be human-readable |
| SC-SMRITI-086 | All formats MUST preserve content integrity |
| SC-SMRITI-090 | Reject high-entropy (>0.8) inputs |
| SC-SMRITI-091 | No duplicates allowed |
| SC-SMRITI-092 | All content must pass Guardian safety checks |
| SC-SMRITI-100 | Federation MUST use authenticated channels |
| SC-SMRITI-110 | Attestation tokens expire after 1 hour |
| SC-SMRITI-111 | Cross-holon attestation every hour in federation mode |
| SC-SMRITI-112 | Last-writer-wins for conflicts |
| SC-SMRITI-113 | Causality preserved |
| SC-SMRITI-120 | Replication engine for SMRITI holons |
| SC-SMRITI-130 | Query results MUST include integrity proofs |
| SC-SMRITI-131 | Full-text search via FTS5 |
| SC-SMRITI-132 | Semantic search via vector embeddings |
| SC-SMRITI-133 | Query timeout < 500ms |
| SC-SMRITI-140 | All evolution events MUST be recorded |
| SC-SMRITI-141 | Lineage chain MUST be unbroken |
| SC-SMRITI-142 | Evolution history stored in DuckDB (append-only) |

### SNP - General Domain: SNP
| ID | Description |
|---|---|
| SC-SNP-001 | Snapshots MUST include version number |
| SC-SNP-002 | Snapshot integrity MUST be verified (checksum) |
| SC-SNP-003 | Snapshot storage MUST be durable |
| SC-SNP-004 | Recovery MUST be deterministic |

### SRE - General Domain: SRE
| ID | Description |
|---|---|
| SC-SRE-001 | <50ms query latency for runbooks |

### STARTUP - General Domain: STARTUP
| ID | Description |
|---|---|
| SC-STARTUP-020 | Mathematical Startup Optimization --> |

### STATE - General Domain: STATE
| ID | Description |
|---|---|
| SC-STATE-001 | State updates MUST be atomic |
| SC-STATE-002 | State MUST include constitution hash |
| SC-STATE-003 | State transitions MUST be logged |

### STM - General Domain: STM
| ID | Description |
|---|---|
| SC-STM-001 | Transactions must be atomic and isolated |
| SC-STM-002 | Retry on conflict, no deadlocks |
| SC-STM-003 | State must be consistent after every transaction |
| SC-STM-004 | Actors must process messages in order |

### STORE - General Domain: STORE
| ID | Description |
|---|---|
| SC-STORE-001 | Append-only for history. |
| SC-STORE-002 | Local file storage in data/holons/. |
| SC-STORE-003 | WAL mode enabled. |
| SC-STORE-004 | Foreign keys enforced. |

### STPA - General Domain: STPA
| ID | Description |
|---|---|
| SC-STPA-001 | All components must have analyze/0 function |
| SC-STPA-002 | UCAs must include severity classification |
| SC-STPA-003 | Safety requirements must be generated |

### STR - General Domain: STR
| ID | Description |
|---|---|
| SC-STR-001 | Sterilization MUST complete in < 1s |
| SC-STR-002 | All resources MUST be released |
| SC-STR-003 | Children MUST be notified |
| SC-STR-004 | Sterile state MUST be irreversible |

### STREAM - General Domain: STREAM
| ID | Description |
|---|---|
| SC-STREAM-001 | Streams must support backpressure signaling |
| SC-STREAM-002 | Windows must be time-bounded (max 60 seconds) |
| SC-STREAM-003 | Aggregations must be incremental (no full recompute) |
| SC-STREAM-004 | Subscriptions must be cancellable |

### SUP - General Domain: SUP
| ID | Description |
|---|---|
| SC-SUP-001 | Constitution MUST be verified before child restart |
| SC-SUP-002 | Failed children MUST be reported to parent holon |
| SC-SUP-003 | Max restarts MUST respect layer thresholds |
| SC-SUP-004 | Supervision tree MUST match holon hierarchy |

### SUR - General Domain: SUR
| ID | Description |
|---|---|
| SC-SUR-001 | Surprise MUST be non-negative |
| SC-SUR-002 | Surprise calculation MUST be < 1ms |
| SC-SUR-003 | Infinite surprise MUST be capped |
| SC-SUR-004 | Surprise MUST trigger belief update when > threshold |

### SWARM - General Domain: SWARM
| ID | Description |
|---|---|
| SC-SWARM-001 | Algorithm convergence < 1000 iterations |
| SC-SWARM-002 | Diversity maintenance > 0.3 |
| SC-SWARM-003 | Fitness evaluation < 10ms per agent |
| SC-SWARM-004 | Population size 20-100 agents |
| SC-SWARM-005 | Integration with UnifiedBus for telemetry |
| SC-SWARM-020 | Full swarm orchestration |

### SYNAPSE - General Domain: SYNAPSE
| ID | Description |
|---|---|
| SC-SYNAPSE-001 | Coordination decisions logged to Zenoh |
| SC-SYNAPSE-002 | Fallback to single model on orchestration failure |

### SYNC - General Domain: SYNC
| ID | Description |
|---|---|
| SC-SYNC-001 | Bridge timeout < 5s (handled by client) |
| SC-SYNC-002 | Retry with exponential backoff |
| SC-SYNC-003 | Circuit breaker after 3 failures |
| SC-SYNC-004 | Health sync interval = 30s |
| SC-SYNC-005 | All commands through Guardian |
| SC-SYNC-006 | All state via Immutable Register |
| SC-SYNC-007 | Proof token required for mutations |
| SC-SYNC-008 | Constitutional check before reconfig |
| SC-SYNC-009 | Zenoh for real-time telemetry |
| SC-SYNC-010 | DuckDB for shared history |
| SC-SYNC-011 | Container actions require Guardian approval |
| SC-SYNC-012 | Log to ImmutableRegister |
| SC-SYNC-013 | Biomorphic events via Zenoh (read-only) |
| SC-SYNC-014 | Domain data via Zenoh |

### TDG - General Domain: TDG
| ID | Description |
|---|---|
| SC-TDG-001 | Tests written BEFORE implementation |
| SC-TDG-002 | FPPS 5-method consensus validation |
| SC-TDG-003 | Dual property testing (FsCheck) |

### TEL - General Domain: TEL
| ID | Description |
|---|---|
| SC-TEL-001 | Display latency <100ms |
| SC-TEL-002 | Trend accuracy >95% |
| SC-TEL-003 | Sparklines for metrics |

### TENANT - General Domain: TENANT
| ID | Description |
|---|---|
| SC-TENANT-001 | Zero tolerance for cross-tenant data access with immediate action |
| SC-TENANT-002 | Tenant context must be validated on every request |
| SC-TENANT-003 | Resource quotas must be enforced per tenant |
| SC-TENANT-004 | Audit logs must be tenant-isolated |

### TEST - General Domain: TEST
| ID | Description |
|---|---|
| SC-TEST-001 | Test execution SHALL NOT exceed memory limits", |
| SC-TEST-002 | Test failures SHALL trigger systematic analysis", |
| SC-TEST-003 | Test parallelization SHALL NOT cause race conditions", |
| SC-TEST-004 | Test __data SHALL be isolated between test runs", |
| SC-TEST-005 | Test environment SHALL be validated before execution" |

### THEME - General Domain: THEME
| ID | Description |
|---|---|
| SC-THEME-001 | Light/Dark mode support |
| SC-THEME-002 | Minimum 4.5:1 contrast for normal text |
| SC-THEME-003 | Minimum 7:1 contrast for critical elements |
| SC-THEME-004 | Animation timing must respect reduced-motion preferences |
| SC-THEME-005 | Sound triggers must have visual equivalents |

### THR - General Domain: THR
| ID | Description |
|---|---|
| SC-THR-002 | Pulse check |

### TODO - Todolist and Planning Integrity
| ID | Description |
|---|---|
| SC-TODO-001 | Agents SHALL NOT read PROJECT_TODOLIST.md directly |
| SC-TODO-003 | Command matches forbidden pattern for PROJECT_TODOLIST.md access") |
| SC-TODO-004 | Check if authorized method |
| SC-TODO-008 | Access Control Runtime Enforcement --> |

### TPS - General Domain: TPS
| ID | Description |
|---|---|
| SC-TPS-001 | Critical errors MUST trigger immediate halt |
| SC-TPS-002 | Halt MUST initiate 5-Level RCA automatically |
| SC-TPS-003 | Operations MUST NOT resume until fix verified |
| SC-TPS-004 | All halts MUST include OpenTelemetry tracing |
| SC-TPS-005 | Halt events MUST notify all 50 agents |
| SC-TPS-006 | Executive Director MAY override halt with risk acknowledgment |

### TRACE - General Domain: TRACE
| ID | Description |
|---|---|
| SC-TRACE-001 | EnvelopeBuilder fluent API |

### TRAIN - General Domain: TRAIN
| ID | Description |
|---|---|
| SC-TRAIN-001 | Async capture only (no blocking) |
| SC-TRAIN-002 | Episode buffer < 10,000 entries |
| SC-TRAIN-003 | Automatic batch flush every 60s |
| SC-TRAIN-004 | Data anonymization for PII |

### TT - General Domain: TT
| ID | Description |
|---|---|
| SC-TT-001 | Time travel MUST be deterministic |
| SC-TT-002 | State reconstruction MUST be idempotent |
| SC-TT-003 | Causality MUST be preserved |
| SC-TT-004 | Future state access MUST be prohibited |

### TX - General Domain: TX
| ID | Description |
|---|---|
| SC-TX-001 | ACID properties must be maintained (atomicity, consistency, isolation, durability) |
| SC-TX-002 | Deadlock detection required using wait-for graph |
| SC-TX-003 | Connection pool limits enforced |
| SC-TX-004 | victim selection for deadlock resolution |

### TXN - General Domain: TXN
| ID | Description |
|---|---|
| SC-TXN-001 | ACID semantics guaranteed |
| SC-TXN-003 | Savepoint/rollback support |
| SC-TXN-005 | Deadlock detection |

### UCR - General Domain: UCR
| ID | Description |
|---|---|
| SC-UCR-001 | Atomic checkpoint of all 7 state locations |
| SC-UCR-002 | SHA-256/BLAKE3 hash for every artifact |
| SC-UCR-011 | Shadow universe requires Guardian approval |
| SC-UCR-014 | Constitutional invariants verification |

### UTLTS - General Domain: UTLTS
| ID | Description |
|---|---|
| SC-UTLTS-001 | WAL mode for concurrent access |
| SC-UTLTS-002 | All test runs recorded regardless of runtime |
| SC-UTLTS-003 | Write latency < 1ms per result (async batched writes) |
| SC-UTLTS-005 | F# Expecto integration |
| SC-UTLTS-006 | Cargo test JSON format parsing |
| SC-UTLTS-007 | Script execution tracking |
| SC-UTLTS-008 | Coverage data import (lcov/excoveralls) |
| SC-UTLTS-010 | Query interface for UTLTS data |
| SC-UTLTS-012 | Concurrent access from 16 parallel test threads |

### UX - General Domain: UX
| ID | Description |
|---|---|
| SC-UX-001 | Cockpit scenarios tested") |> ignore |

### VAL - General Domain: VAL
| ID | Description |
|---|---|
| SC-VAL-001 | Patient Mode validation support |
| SC-VAL-002 | Complete log analysis |
| SC-VAL-003 | 100% Consensus required |
| SC-VAL-004 | Halt on disagreement |
| SC-VAL-005 | Complete log analysis, never partial |
| SC-VAL-006 | Binary verification |
| SC-VAL-007 | AST analysis |
| SC-VAL-008 | Pattern matching |

### VAR - General Domain: VAR
| ID | Description |
|---|---|
| SC-VAR-001 | No underscore prefix on used variables |

### VDP - General Domain: VDP
| ID | Description |
|---|---|
| SC-VDP-001 | Supervisory Control Paradigm) |
| SC-VDP-003 | Redundancy Gain (multi-modal for high salience) |
| SC-VDP-005 | Discriminable naming (zone.node-01 format) |
| SC-VDP-008 | Closure feedback on node operations |
| SC-VDP-009 | Show confidence levels |
| SC-VDP-010 | Temporal context in displays |
| SC-VDP-011 | Context-sensitive hint bar |
| SC-VDP-015 | Score-based popup threshold |
| SC-VDP-016 | Closure Principle) |
| SC-VDP-017 | Visual Display Principles (Laux/Wickens) |

### VER - General Domain: VER
| ID | Description |
|---|---|
| SC-VER-001 | Startup verification MUST complete before app ready |
| SC-VER-002 | Verification failure MUST halt the system |
| SC-VER-003 | All violations MUST be logged and reported |
| SC-VER-004 | Verification MUST complete within 100ms |
| SC-VER-006 | Patient Mode active |
| SC-VER-007 | All source files compiled |
| SC-VER-031 | All containers healthy |
| SC-VER-033 | Zenoh mesh connected |
| SC-VER-034 | DB connection pool active |
| SC-VER-035 | OTEL traces flowing |
| SC-VER-037 | Inter-container latency bounded |
| SC-VER-041 | OODA cycle < 100ms |
| SC-VER-042 | All CLI commands functional |
| SC-VER-044 | 5-Order effects logged |
| SC-VER-045 | Emergency stop < 5s |
| SC-VER-074 | Constitutional invariants hold |
| SC-VER-075 | Ψ₀ Existence preserved |
| SC-VER-079 | Ψ₄ Founder alignment |

### VID - General Domain: VID
| ID | Description |
|---|---|
| SC-VID-001 | Stream latency < 100ms |
| SC-VID-002 | Analytics integration |

### VIDEO - General Domain: VIDEO
| ID | Description |
|---|---|
| SC-VIDEO-001 | Stream integrity monitoring |
| SC-VIDEO-002 | Privacy zone enforcement |

### VIEW - General Domain: VIEW
| ID | Description |
|---|---|
| SC-VIEW-001 | All pages must be accessible |
| SC-VIEW-002 | Error pages must not expose sensitive data |

### VSM - General Domain: VSM
| ID | Description |
|---|---|
| SC-VSM-001 | All 5 systems MUST be supervised |

### WAL - General Domain: WAL
| ID | Description |
|---|---|
| SC-WAL-001 | Balance MUST be non-negative |
| SC-WAL-002 | History MUST be append-only |
| SC-WAL-003 | Frozen wallets MUST reject transactions |
| SC-WAL-004 | Limits MUST be enforced |

### WATCHDOG - General Domain: WATCHDOG
| ID | Description |
|---|---|
| SC-WATCHDOG-001 | Check interval <= 100ms |
| SC-WATCHDOG-002 | Corruption detection -> Guardian report |
| SC-WATCHDOG-003 | Self-healing attempt before escalation |

### WORKER - General Domain: WORKER
| ID | Description |
|---|---|
| SC-WORKER-001 | Consistent worker interface |
| SC-WORKER-002 | FQUN registration mandatory |
| SC-WORKER-003 | Job metrics tracking |
| SC-WORKER-004 | Graceful shutdown |

### WS - General Domain: WS
| ID | Description |
|---|---|
| SC-WS-001 | WebSocket connections must authenticate |
| SC-WS-002 | Heartbeat must be maintained |
| SC-WS-003 | Reconnection must be handled gracefully |

### XHOLON - General Domain: XHOLON
| ID | Description |
|---|---|
| SC-XHOLON-001 | Each holon has isolated database files |
| SC-XHOLON-002 | Direct access via Exqlite/Duckdbex |
| SC-XHOLON-003 | Cross-holon access ONLY via Zenoh |
| SC-XHOLON-006 | Concurrent access uses OCC |
| SC-XHOLON-007 | Version vectors monotonically increasing |
| SC-XHOLON-010 | All writes use OCC with version vectors |
| SC-XHOLON-015 | 2PC required for cross-runtime writes |
| SC-XHOLON-020 | SQLite read latency < 1ms |
| SC-XHOLON-021 | DuckDB query latency < 10ms |
| SC-XHOLON-025 | Request timeout < 5s |
| SC-XHOLON-026 | Retry with exponential backoff |
| SC-XHOLON-030 | No data loss on crash (WAL mode) |
| SC-XHOLON-031 | ACID compliance mandatory |
| SC-XHOLON-032 | No deadlocks permitted |
| SC-XHOLON-033 | No starvation permitted |
| SC-XHOLON-035 | Audit trail immutable (append-only) |
| SC-XHOLON-040 | Performance SLAs |
| SC-XHOLON-044 | Timeout must not leave orphaned transactions |
| SC-XHOLON-045 | Distributed transaction timeout triggers abort |
| SC-XHOLON-050 | Recovery completeness |

### ZEN - Zenoh FFI and Communication
| ID | Description |
|---|---|
| SC-ZEN-001 | Publish AI Authority assessment to Zenoh |
| SC-ZEN-002 | Telemetry streams must be read-only for Cockpit (Ingest only typically) |
| SC-ZEN-003 | Dead Man's Switch / Heartbeat |

### ZENOH - General Domain: ZENOH
| ID | Description |
|---|---|
| SC-ZENOH-001 | Zenoh NIF must be loaded |
| SC-ZENOH-002 | Zenoh router MUST be reachable before app starts |
| SC-ZENOH-003 | Verify telemetry collection |
| SC-ZENOH-004 | Publish latency < 100ms |
| SC-ZENOH-006 | Quadplex Zenoh channel enabled |
| SC-ZENOH-007 | Zenoh health included in /health endpoint |
| SC-ZENOH-008 | Conditional DatabaseProxy startup with NIF detection |
| SC-ZENOH-010 | Container agents publish health every 30s |
| SC-ZENOH-015 | Zenoh telemetry and agents |

### ZTEST - Zenoh Test Messaging and Checkpoints
| ID | Description |
|---|---|
| SC-ZTEST-001 | All checkpoints have unique topics |
| SC-ZTEST-002 | Messages include checkpoint ID (format: CP-{DOMAIN}-{NN}) |
| SC-ZTEST-003 | Publish latency < 10ms per event |
| SC-ZTEST-004 | Zenoh publish is async (non-blocking) |
| SC-ZTEST-005 | Orchestrator aggregate update < 100ms |
| SC-ZTEST-006 | Boot checkpoints include state vector |
| SC-ZTEST-007 | Test failures include full context (≥3 fields) |
| SC-ZTEST-008 | ALWAYS write log fallback first (guaranteed durability before Zenoh attempt) |
| SC-ZTEST-009 | Publish on every phase transition |
| SC-ZTEST-010 | Include state vector in every message |
| SC-ZTEST-011 | Quorum status within 1s of change |
| SC-ZTEST-012 | FIFO ordering per topic |
| SC-ZTEST-013 | Checkpoint ID format: CP-{DOMAIN}-{NN} |
| SC-ZTEST-014 | Schema version MUST be semver compliant |
| SC-ZTEST-015 | ISO 8601 UTC timestamps |
| SC-ZTEST-016 | Payload size < 64KB |
| SC-ZTEST-017 | Topic depth <= 6 levels |
| SC-ZTEST-019 | Publisher retry count = 3 |

