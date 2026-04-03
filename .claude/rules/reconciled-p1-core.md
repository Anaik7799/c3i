# P1-CORE Reconciled Constraints (2026-03-22)

## SC-FSH (F# Language Safety)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FSH-003 | Active Patterns for domain type classification | HIGH |
| SC-FSH-004 | Units of Measure for all physical quantities | HIGH |
| SC-FSH-005 | Physical unit conversions via Units module only | HIGH |
| SC-FSH-010 | Kleisli composition for Result pipeline chaining | HIGH |
| SC-FSH-011 | tap/applyIf for side effects in pipelines | MEDIUM |
| SC-FSH-012 | Domain patterns MUST be exhaustive | HIGH |
| SC-FSH-013 | Active Patterns MUST NOT throw exceptions | CRITICAL |
| SC-FSH-016 | Async operations MUST NOT block | CRITICAL |
| SC-FSH-017 | All errors in Result type | HIGH |
| SC-FSH-030 | Property-based tests REQUIRED for F# modules | HIGH |
| SC-FSH-033 | Expecto MUST be F# test framework | HIGH |
| SC-FSH-040 | Workflow builders MUST be lawful monads | HIGH |
| SC-FSH-041 | Workflow builders no hidden state mutation | HIGH |
| SC-FSH-042 | Builders MUST support proper sequencing | HIGH |
| SC-FSH-050 | Active patterns for agent/severity classification | MEDIUM |
| SC-FSH-060 | Type-safe F# units of measure (not raw float) | HIGH |
| SC-FSH-061 | Aggregates from event stream only | HIGH |
| SC-FSH-062 | Commands validated before producing events | HIGH |
| SC-FSH-070 | Parsers pure and composable | HIGH |
| SC-FSH-071 | Parser errors include position info | MEDIUM |
| SC-FSH-072 | Backtracking MUST be explicit (attempt combinator) | MEDIUM |
| SC-FSH-120 | Recursion algebra functions MUST be total | HIGH |
| SC-FSH-121 | Recursion coalgebras MUST terminate | HIGH |
| SC-FSH-122 | Hylomorphisms stack-safe for deep structures | HIGH |

## SC-SMRITI (Knowledge Management System)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SMRITI-023 | Telemetry handler compliance | HIGH |
| SC-SMRITI-031 | Autonomous knowledge agent lifecycle | HIGH |
| SC-SMRITI-032 | Continuous health monitoring active | HIGH |
| SC-SMRITI-050 | Bootstrap sequence constraints | MEDIUM |
| SC-SMRITI-062 | Version vector tracking for federation | HIGH |
| SC-SMRITI-063 | Federation protocol for cross-holon sync | HIGH |
| SC-SMRITI-071 | Self-documenting reconstruction guide on export | MEDIUM |
| SC-SMRITI-072 | Multi-format export JSON/Markdown/SQLite | HIGH |
| SC-SMRITI-074 | Immortality protocol atomic and complete | CRITICAL |
| SC-SMRITI-078 | Markdown export valid CommonMark | MEDIUM |
| SC-SMRITI-082 | Obsidian vault includes .obsidian config | MEDIUM |
| SC-SMRITI-083 | Obsidian notes use YAML frontmatter | MEDIUM |
| SC-SMRITI-100 | Federation authenticated channels | HIGH |
| SC-SMRITI-110 | Version vectors in SQLite; attestation expires 1hr | CRITICAL |
| SC-SMRITI-111 | Concurrent updates detected; hourly attestation | HIGH |
| SC-SMRITI-113 | Causality preserved via version vectors | HIGH |
| SC-SMRITI-120 | Replication engine for federation | HIGH |
| SC-SMRITI-130 | Query results include integrity proofs | HIGH |
| SC-SMRITI-131 | Full-text search uses FTS5 | MEDIUM |
| SC-SMRITI-132 | Semantic search uses vector embeddings | MEDIUM |
| SC-SMRITI-133 | Query timeout < 500ms | HIGH |
| SC-SMRITI-140 | All evolution events recorded | CRITICAL |
| SC-SMRITI-141 | Lineage chain unbroken | CRITICAL |
| SC-SMRITI-142 | Evolution history in DuckDB append-only | CRITICAL |

## SC-XHOLON (Cross-Holon Database Operations)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-XHOLON-001 | Isolated database files per holon | CRITICAL |
| SC-XHOLON-002 | Direct native library access (Exqlite/Duckdbex) | HIGH |
| SC-XHOLON-003 | Cross-holon access via Zenoh ONLY | CRITICAL |
| SC-XHOLON-006 | OCC for concurrent access | HIGH |
| SC-XHOLON-007 | Monotonically increasing version vectors | HIGH |
| SC-XHOLON-010 | Writes OCC with version vectors; reads lock-free | HIGH |
| SC-XHOLON-020 | SQLite read latency < 1ms | HIGH |
| SC-XHOLON-021 | DuckDB query latency < 10ms | HIGH |
| SC-XHOLON-025 | Cross-holon request timeout < 5s | HIGH |
| SC-XHOLON-030 | No data loss on crash (WAL mandatory) | CRITICAL |
| SC-XHOLON-031 | ACID compliance for SQLite writes | CRITICAL |
| SC-XHOLON-032 | No deadlocks | CRITICAL |
| SC-XHOLON-033 | No starvation | HIGH |
| SC-XHOLON-035 | DuckDB audit trail immutable (append-only) | CRITICAL |
| SC-XHOLON-044 | Timeout MUST NOT leave orphaned transactions | HIGH |
| SC-XHOLON-045 | Distributed transaction timeout triggers abort | HIGH |
| SC-XHOLON-050 | Support 100+ concurrent holons | HIGH |
| SC-XHOLON-051 | Support 10+ concurrent clients per holon | HIGH |

## SC-VER (System Verification)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-VER-001 | Startup verification before app ready | CRITICAL |
| SC-VER-002 | Verification failure halts system | CRITICAL |
| SC-VER-003 | All violations logged and reported | HIGH |
| SC-VER-004 | Verification < 100ms | HIGH |
| SC-VER-006 | Patient Mode active during verification | HIGH |
| SC-VER-007 | All source files compiled | CRITICAL |
| SC-VER-031 | All containers healthy | CRITICAL |
| SC-VER-033 | Zenoh mesh connected | CRITICAL |
| SC-VER-034 | DB connection pool active | HIGH |
| SC-VER-035 | OTEL traces flowing | HIGH |
| SC-VER-037 | Inter-container latency bounded | HIGH |
| SC-VER-041 | OODA cycle < 100ms | HIGH |
| SC-VER-042 | All CLI commands functional | HIGH |
| SC-VER-044 | 5-Order effects logged | MEDIUM |
| SC-VER-045 | Emergency stop < 5s | CRITICAL |
| SC-VER-074 | Constitutional L0-L7 hold | CRITICAL |
| SC-VER-075 | Ψ₀ preserved through any operation | CRITICAL |
| SC-VER-079 | Ψ₄ Founder alignment verified | CRITICAL |

## SC-ORCH (Orchestration Coordination)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ORCH-001 | Task creation coordinates Prajna/Smriti/Chaya | CRITICAL |
| SC-ORCH-002 | Updates propagate to Smriti history | HIGH |
| SC-ORCH-003 | Completion in permanent storage | HIGH |
| SC-ORCH-004 | OODA cycle < 100ms | HIGH |
| SC-ORCH-005 | Critical actions need Guardian approval | CRITICAL |
| SC-ORCH-006 | AI assistance through Cortex | HIGH |
| SC-ORCH-007 | Knowledge queries via Smriti | HIGH |
| SC-ORCH-008 | Mesh distribution via Chaya | HIGH |
| SC-ORCH-009 | All inter-service messages logged | HIGH |
| SC-ORCH-010 | Service health monitored continuously | HIGH |
| SC-ORCH-011 | Critical messages delivered first | HIGH |
| SC-ORCH-012 | Service registration atomic | HIGH |
| SC-ORCH-013 | Access control at orchestration layer | HIGH |
| SC-ORCH-014 | Event log append-only | CRITICAL |
| SC-ORCH-015 | Coordination idempotent | HIGH |

## SC-BOOT (Boot Sequence)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-BOOT-001 | State vector verified before each stage | CRITICAL |
| SC-BOOT-002 | Migration check before Stage 3 | HIGH |
| SC-BOOT-003 | Quorum before Stage 3 | CRITICAL |
| SC-BOOT-004 | Boot transactional with rollback | CRITICAL |
| SC-BOOT-005 | Boot time < 120s (target 60s) | HIGH |
| SC-BOOT-006 | All containers pass health check | CRITICAL |
| SC-BOOT-007 | Ports scoured before boot | HIGH |
| SC-BOOT-008 | DAG acyclic (Kahn's algorithm) | CRITICAL |
| SC-BOOT-009 | Waves boot in parallel | HIGH |
| SC-BOOT-010 | Checkpoints at each stage | HIGH |

## SC-PHICS (Physical Interface Control System)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-PHICS-001 | Commands logged to Immutable Register | CRITICAL |
| SC-PHICS-002 | Failure detection within 5s | HIGH |
| SC-PHICS-003 | Guardian approval for destructive commands | CRITICAL |
| SC-PHICS-004 | Authorized via Access Control | HIGH |
| SC-PHICS-005 | Latency tracking enabled | HIGH |
| SC-PHICS-006 | Alert on >50ms violations | HIGH |
| SC-PHICS-007 | Device registry tracks all devices | MEDIUM |
| SC-PHICS-008 | Event queue FIFO | HIGH |

## SC-CONSOL (Configuration Consolidation)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CONSOL-001 | NetworkConfig single definition in MeshConfig.fs | CRITICAL |
| SC-CONSOL-002 | Ports from MeshConfig.Ports | CRITICAL |
| SC-CONSOL-003 | ANSI colors from ConsoleChannel.AnsiColors | HIGH |
| SC-CONSOL-004 | Compose files generated from config | HIGH |
| SC-CONSOL-005 | Config validation at boot (fail fast) | CRITICAL |
| SC-CONSOL-006 | ConfigBridge syncs F#/Elixir configs | HIGH |
| SC-CONSOL-007 | Orchestrator uses Mesh.Core.fs | HIGH |
| SC-CONSOL-008 | Unified boot model (single phase enum) | HIGH |
| SC-CONSOL-009 | Health uses Mesh.Health.fs | HIGH |
| SC-CONSOL-010 | Telemetry uses Mesh.Telemetry.fs | MEDIUM |

## SC-LOG (Fractal Logger)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-LOG-001 | Async dispatch — never blocks caller | CRITICAL |
| SC-LOG-002 | Load shedding when queue full | HIGH |
| SC-LOG-003 | PII masking auto-applied | CRITICAL |
| SC-LOG-004 | TraceID auto-propagated | HIGH |
| SC-LOG-005 | Boost TTL mandatory (5min default, 1hr max) | HIGH |
| SC-LOG-006 | HLC timestamps for L3+ logs | HIGH |
| SC-LOG-009 | Key expression aliases pre-registered | MEDIUM |
| SC-LOG-010 | Admin space authenticated | HIGH |

## SC-OPT (Boot/Runtime Optimization)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-OPT-001 | Boot time < 60s | CRITICAL |
| SC-OPT-002 | Health check exponential backoff (100ms→3200ms) | HIGH |
| SC-OPT-003 | 2oo3 early-exit on quorum | HIGH |
| SC-OPT-004 | Migration gate no blocking wave transition | HIGH |
| SC-OPT-005 | Pre-compiled BEAM files in app container | CRITICAL |
| SC-OPT-006 | Wave parallelization for independent waves | HIGH |
| SC-OPT-007 | Timeout configurations tuned | MEDIUM |
| SC-OPT-008 | Boot metrics published to Zenoh | MEDIUM |

## SC-FED (Federation Governance)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FED-001 | No modification of node constitutions | CRITICAL |
| SC-FED-002 | Maintain node autonomy | CRITICAL |
| SC-FED-003 | Detect constitution divergence | HIGH |
| SC-FED-004 | Emergency coordination time-bounded | HIGH |
| SC-FED-005 | Membership management maintained | HIGH |
| SC-FED-006 | Attestation Ed25519-verified | CRITICAL |

## SC-UTLTS (Universal Test Lifecycle Tracking)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-UTLTS-001 | WAL mode for concurrent access | CRITICAL |
| SC-UTLTS-002 | ALL test runs recorded (Elixir, F#, Rust) | HIGH |
| SC-UTLTS-003 | Write latency < 1ms (async batched) | HIGH |
| SC-UTLTS-005 | F# Expecto integration publishes to UTLTS | HIGH |
| SC-UTLTS-006 | Cargo test JSON format parseable | MEDIUM |
| SC-UTLTS-008 | Coverage import lcov/excoveralls | MEDIUM |
| SC-UTLTS-012 | 16 parallel threads supported | HIGH |

## SC-HA (High Availability Mesh)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-HA-001 | SIL-6 availability requirements | CRITICAL |
| SC-HA-002 | Failover within SIL-6 time bounds | CRITICAL |
| SC-HA-003 | Zenoh 2oo3 quorum in HA configuration | CRITICAL |
| SC-HA-005 | SIL-6 constitutional requirements | CRITICAL |
| SC-HA-007 | Deterministic build cache ordering | HIGH |
| SC-HA-009 | Chaos recovery protocols | HIGH |
| SC-HA-011 | Chaos testing validates SIL-6 resilience | HIGH |

## SC-CI (CI/CD Pipeline)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CI-001 | All builds reproducible | CRITICAL |
| SC-CI-002 | Pipeline timeout < 60 minutes | HIGH |
| SC-CI-003 | Test results always published | HIGH |
| SC-CI-004 | Artifacts retained 30 days | MEDIUM |
| SC-CI-005 | Quality gates MANDATORY | CRITICAL |
| SC-CI-006 | Security scans every build | HIGH |
| SC-CI-007 | All 5 test levels pass for merge | CRITICAL |

## SC-MATH (Mathematical Disciplines)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-MATH-001 | Discipline health monitored | CRITICAL |
| SC-MATH-002 | Token ratios validated | HIGH |
| SC-MATH-003 | Homeostasis RPN remediated; Ziegler-Nichols PID | HIGH |
| SC-MATH-004 | Isolated disciplines connected to runtime callers | HIGH |

## SC-RECONFIG (Constitutional Reconfiguration)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-RECONFIG-001 | Graph transformation for changes | HIGH |
| SC-RECONFIG-005 | Lineage preserved through reconfiguration | CRITICAL |
| SC-RECONFIG-007 | Graceful degradation to older versions | HIGH |
| SC-RECONFIG-009 | Guardian approval REQUIRED | CRITICAL |
| SC-RECONFIG-010 | Federation peers notified | HIGH |

## SC-SWARM (Swarm Algorithms)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-001 | Convergence < 1000 iterations | HIGH |
| SC-SWARM-002 | Diversity maintenance > 0.3 | HIGH |
| SC-SWARM-003 | Fitness evaluation < 10ms per agent | HIGH |
| SC-SWARM-004 | Population 20-100 agents | MEDIUM |
| SC-SWARM-005 | UnifiedBus telemetry integration | HIGH |

## SC-AGENT (Distributed Agent Mesh)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-AGENT-001 | All agents MUST have FQUN | CRITICAL |
| SC-AGENT-002 | Communication via Zenoh | HIGH |
| SC-AGENT-003 | State published to Zenoh | HIGH |
| SC-AGENT-004 | Respond to control commands | HIGH |
| SC-AGENT-005 | Consistent interface and lifecycle | HIGH |

## SC-CONSENSUS (Tricameral Consensus)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CONSENSUS-001 | 2oo3 voting for P0 decisions | CRITICAL |
| SC-CONSENSUS-002 | Each chamber has Constitutional veto | CRITICAL |
| SC-CONSENSUS-003 | Timeout < 30s per chamber | HIGH |

## SC-HASH (Hash Computation)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-HASH-001 | Deterministic computation | CRITICAL |
| SC-HASH-002 | Constant-time comparison (timing attack prevention) | CRITICAL |
| SC-HASH-003 | Canonical representation | HIGH |

## SC-IKE (Knowledge Engine)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-IKE-001 | Document ingestion pipeline | HIGH |
| SC-IKE-002 | Entropy gating (blocked if > 0.2) | HIGH |
| SC-IKE-003 | Drift detection scoring | HIGH |

## SC-STATE (Holon State Transitions)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-STATE-001 | Atomic state updates | CRITICAL |
| SC-STATE-002 | State includes constitution hash | HIGH |
| SC-STATE-003 | Transitions logged | HIGH |

## SC-CIRCUIT (Prajna Circuit Breaker)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CIRCUIT-001 | Drop telemetry when queue > 100 messages | HIGH |
| SC-CIRCUIT-002 | Dropped messages logged for post-mortem | HIGH |

## SC-FRACTAL (Genotype Topology)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-FRACTAL-001 | Expected genotype MUST match runtime graph | CRITICAL |

## SC-QUORUM (2oo3 Voting Safety)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-QUORUM-001 | Two-out-of-three voting MANDATORY for safety-critical decisions | CRITICAL |

## SC-VALID (Validation Boundaries)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-VALID-001 | STAMP references for every validated action | HIGH |

## AOR-MATH (Mathematical Discipline Rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-MATH-001 | Monitor mathematical discipline health continuously | Mandatory |
| AOR-MATH-002 | Remediate RPN for degraded disciplines | Escalation |
| AOR-MATH-003 | Track token ratios for discipline interactions | Mandatory |
| AOR-MATH-004 | Connect isolated disciplines to runtime callers | Mandatory |
| AOR-MATH-005 | Log discipline state transitions | Mandatory |
| AOR-MATH-006 | Alert on discipline health regression | Escalation |
| AOR-MATH-007 | Validate Ziegler-Nichols PID parameters | Mandatory |
| AOR-MATH-008 | Ensure production maturity before release | Mandatory |
| AOR-MATH-009 | Run FMEA analysis on discipline gaps | Mandatory |
| AOR-MATH-010 | Publish discipline metrics to Zenoh | Mandatory |
| AOR-MATH-011 | Validate cross-discipline interaction strengths | Mandatory |
| AOR-MATH-012 | Verify startup optimization convergence | Mandatory |
| AOR-MATH-013 | Track RPN trend — increasing triggers P1 | Escalation |
| AOR-MATH-014 | Ensure discipline coverage ≥ 95% | Mandatory |
| AOR-MATH-015 | DFA state machine validation on boot | Mandatory |
| AOR-MATH-016 | RCPSP scheduling respects resource constraints | Mandatory |
| AOR-MATH-017 | Critical path method optimization verified | Mandatory |
| AOR-MATH-018 | SET theory validation for configuration | Mandatory |
| AOR-MATH-019 | Mathematical proofs type-checked | Mandatory |
| AOR-MATH-020 | Homeostasis PID tuning documented | Mandatory |

## AOR-VER (Verification Rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-001 | Run 7-level fractal verification on startup | Mandatory |
| AOR-VER-002 | Verification results published to Zenoh | Mandatory |
| AOR-VER-003 | Verification failure triggers system halt | Mandatory |
| AOR-VER-004 | All verification methods must agree | Mandatory |
| AOR-VER-005 | Verification latency < 100ms | Mandatory |
| AOR-VER-006 | Log all verification events | Mandatory |
| AOR-VER-007 | Constitutional L0-L7 checked on every boot | Mandatory |
| AOR-VER-008 | Ψ₀ existence verified continuously | Mandatory |
| AOR-VER-009 | Emergency stop < 5s verified | Mandatory |
| AOR-VER-010 | Verification coverage tracked | Mandatory |
| AOR-VER-011 | Fractal layer consistency verified | Mandatory |
| AOR-VER-012 | Graph verification on topology change | Mandatory |
| AOR-VER-013 | FPPS consensus required for health | Mandatory |
| AOR-VER-014 | Verification audit trail maintained | Mandatory |
| AOR-VER-015 | Hash chain integrity on startup | Mandatory |
| AOR-VER-016 | Container health verified | Mandatory |
| AOR-VER-017 | Zenoh connectivity verified | Mandatory |
| AOR-VER-018 | DB connection pool verified | Mandatory |
| AOR-VER-019 | OTEL traces flowing verified | Mandatory |
| AOR-VER-020 | CLI commands functional verified | Mandatory |
| AOR-VER-021 | Boot time < 120s verified | Mandatory |
| AOR-VER-022 | Quorum maintained verified | Mandatory |
| AOR-VER-023 | DAG acyclicity verified | Mandatory |
| AOR-VER-024 | Migration state verified | Mandatory |
| AOR-VER-025 | Wave parallelization verified | Mandatory |
| AOR-VER-026 | Checkpoint integrity verified | Mandatory |
| AOR-VER-027 | Configuration validated at boot | Mandatory |
| AOR-VER-028 | Ports scoured before boot | Mandatory |
| AOR-VER-029 | Health check consensus | Mandatory |
| AOR-VER-030 | Constitutional invariants hold | Mandatory |
| AOR-VER-031 | Founder alignment verified | Mandatory |
| AOR-VER-032 | Safety kernel active | Mandatory |
| AOR-VER-033 | Guardian available | Mandatory |
| AOR-VER-034 | Sentinel monitoring | Mandatory |
| AOR-VER-035 | PatternHunter calibrated | Mandatory |
| AOR-VER-036 | Digital twin synchronized | Mandatory |
| AOR-VER-037 | Immutable register integrity | Mandatory |
| AOR-VER-038 | Federation attestation current | Mandatory |
| AOR-VER-039 | Holon state verified | Mandatory |
| AOR-VER-040 | Evolution history unbroken | Mandatory |

## AOR-XHOLON (Cross-Holon Database Rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-XHOLON-001 | Use Zenoh for all cross-holon database access | Mandatory |
| AOR-XHOLON-002 | Include request_id in cross-holon queries | Mandatory |
| AOR-XHOLON-003 | Timeout < 5s for cross-holon operations | Mandatory |
| AOR-XHOLON-004 | Version vectors for conflict resolution | Mandatory |
| AOR-XHOLON-005 | Saga pattern for distributed transactions | Mandatory |
| AOR-XHOLON-006 | No deadlocks in cross-holon access | Mandatory |
| AOR-XHOLON-007 | OCC with version vectors for writes | Mandatory |
| AOR-XHOLON-008 | Lock-free reads | Mandatory |
| AOR-XHOLON-009 | Abort on timeout — no orphaned transactions | Mandatory |
| AOR-XHOLON-010 | Support 100+ concurrent holons | Mandatory |
| AOR-XHOLON-011 | WAL mode mandatory for SQLite | Mandatory |
| AOR-XHOLON-012 | ACID compliance for writes | Mandatory |
| AOR-XHOLON-013 | Immutable DuckDB audit trail | Mandatory |
| AOR-XHOLON-014 | SQLite read latency < 1ms | Mandatory |
| AOR-XHOLON-015 | DuckDB query latency < 10ms | Mandatory |
| AOR-XHOLON-016 | Isolated database files per holon | Mandatory |
| AOR-XHOLON-017 | Direct native library access | Mandatory |
| AOR-XHOLON-018 | Monotonic version vectors | Mandatory |
| AOR-XHOLON-019 | No data loss on crash | Mandatory |
| AOR-XHOLON-020 | Support 10+ concurrent clients per holon | Mandatory |
| AOR-XHOLON-021 | Connection pooling required | Mandatory |
| AOR-XHOLON-022 | Schema documentation for every holon | Mandatory |
| AOR-XHOLON-023 | SHA-256 checksum for DB files | Mandatory |
| AOR-XHOLON-024 | Lineage preservation across replication | Mandatory |
| AOR-XHOLON-025 | Substrate-independent holon definitions | Mandatory |
| AOR-XHOLON-026 | Minimal state (information-theoretic minimum) | Mandatory |
| AOR-XHOLON-027 | Holon regenerable from SQLite/DuckDB alone | Mandatory |
| AOR-XHOLON-028 | Backup priority: SQLite/DuckDB files primary | Mandatory |
| AOR-XHOLON-029 | State verification on startup | Mandatory |
| AOR-XHOLON-030 | Self-healing from SQLite/DuckDB | Mandatory |
| AOR-XHOLON-031 | Replication uses version vectors | Mandatory |
| AOR-XHOLON-032 | Distributed copies never authoritative | Mandatory |
| AOR-XHOLON-033 | Evolution completeness — no gaps | Mandatory |
| AOR-XHOLON-034 | Evolution history append-only | Mandatory |
| AOR-XHOLON-035 | Format stability documented | Mandatory |
| AOR-XHOLON-036 | Integrity verification on load | Mandatory |
| AOR-XHOLON-037 | Compress state aggressively | Mandatory |
| AOR-XHOLON-038 | Portable across runtimes | Mandatory |
| AOR-XHOLON-039 | Authoritative source is SQLite/DuckDB only | Mandatory |
| AOR-XHOLON-040 | No external state dependencies for recovery | Mandatory |

## SC-SYNC (State Synchronization — Elixir-F# bridge, cockpit sync, Zenoh publishing, 14 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-SYNC-001 to SC-SYNC-014 | HIGH | State synchronization — Elixir-F# bridge sync, cockpit state, Zenoh publishing |

**Constraint IDs:**
SC-SYNC-001 SC-SYNC-002 SC-SYNC-003 SC-SYNC-004 SC-SYNC-005 SC-SYNC-006 SC-SYNC-007
SC-SYNC-008 SC-SYNC-009 SC-SYNC-010 SC-SYNC-011 SC-SYNC-012 SC-SYNC-013 SC-SYNC-014

## SC-VAL (Validation Boundaries — FPPS consensus, compilation, pattern validation, 8 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-VAL-001 to SC-VAL-008 | HIGH | Validation boundaries — FPPS consensus validation, compilation checks, pattern validation |

**Constraint IDs:**
SC-VAL-001 SC-VAL-002 SC-VAL-003 SC-VAL-004 SC-VAL-005 SC-VAL-006 SC-VAL-007 SC-VAL-008

## SC-REGEN (Regeneration — container lifecycle, health coordinator, supervisor, 3 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-REGEN-002 to SC-REGEN-004 | HIGH | Regeneration — container lifecycle recovery, health coordinator, supervisor restart |

**Constraint IDs:**
SC-REGEN-002 SC-REGEN-003 SC-REGEN-004

## SC-ZEN (Zenoh Session — session lifecycle, connectivity, message routing, 4 constraints)
| ID Range | Severity | Description |
|----------|----------|-------------|
| SC-ZEN-001 to SC-ZEN-005 | HIGH | Zenoh session — session lifecycle management, connectivity monitoring, message routing |

**Constraint IDs:**
SC-ZEN-001 SC-ZEN-002 SC-ZEN-003 SC-ZEN-004 SC-ZEN-005

## AOR-ORCH (Orchestration Coordination Rules — 15 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-ORCH-001 to AOR-ORCH-015 | Orchestration coordination — task creation coordinates Prajna/Smriti/Chaya, updates propagate, Guardian approval for critical actions | Mandatory |

**Rule IDs:**
AOR-ORCH-001 AOR-ORCH-002 AOR-ORCH-003 AOR-ORCH-004 AOR-ORCH-005
AOR-ORCH-006 AOR-ORCH-007 AOR-ORCH-008 AOR-ORCH-009 AOR-ORCH-010
AOR-ORCH-011 AOR-ORCH-012 AOR-ORCH-013 AOR-ORCH-014 AOR-ORCH-015

## AOR-FSH (F# Language Rules — active patterns, pipelines, workflows, async, 12 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FSH-001 to AOR-FSH-055 | F# language rules — active patterns, Kleisli pipelines, workflow builders, async constraints | Mandatory |

**Rule IDs:**
AOR-FSH-001 AOR-FSH-003 AOR-FSH-004 AOR-FSH-010 AOR-FSH-016 AOR-FSH-030
AOR-FSH-040 AOR-FSH-050 AOR-FSH-051 AOR-FSH-052 AOR-FSH-053 AOR-FSH-055

## AOR-CONSOL (Config Consolidation Rules — 10 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CONSOL-001 to AOR-CONSOL-010 | Config consolidation — single definition, port registry, ANSI colors, boot validation | Mandatory |

**Rule IDs:**
AOR-CONSOL-001 AOR-CONSOL-002 AOR-CONSOL-003 AOR-CONSOL-004 AOR-CONSOL-005
AOR-CONSOL-006 AOR-CONSOL-007 AOR-CONSOL-008 AOR-CONSOL-009 AOR-CONSOL-010

## AOR-OPT (Boot Optimization Rules — 10 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-OPT-001 to AOR-OPT-010 | Boot optimization — startup sequencing, health check backoff, wave parallelization | Mandatory |

**Rule IDs:**
AOR-OPT-001 AOR-OPT-002 AOR-OPT-003 AOR-OPT-004 AOR-OPT-005
AOR-OPT-006 AOR-OPT-007 AOR-OPT-008 AOR-OPT-009 AOR-OPT-010

## AOR-PHICS (Physical Interface Control Rules — 10 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-PHICS-001 to AOR-PHICS-010 | Physical interface control — command logging, failure detection, Guardian approval, device registry | Mandatory |

**Rule IDs:**
AOR-PHICS-001 AOR-PHICS-002 AOR-PHICS-003 AOR-PHICS-004 AOR-PHICS-005
AOR-PHICS-006 AOR-PHICS-007 AOR-PHICS-008 AOR-PHICS-009 AOR-PHICS-010

## AOR-SYNC (Sync Operation Rules — 8 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-SYNC-001 to AOR-SYNC-008 | Sync operation — Elixir-F# bridge, cockpit state, Zenoh publishing, constraint census | Mandatory |

**Rule IDs:**
AOR-SYNC-001 AOR-SYNC-002 AOR-SYNC-003 AOR-SYNC-004
AOR-SYNC-005 AOR-SYNC-006 AOR-SYNC-007 AOR-SYNC-008

## AOR-LOG (Fractal Logger Rules — 6 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-LOG-001 to AOR-LOG-006 | Fractal logger — async dispatch, PII masking, TraceID propagation, boost TTL | Mandatory |

**Rule IDs:**
AOR-LOG-001 AOR-LOG-002 AOR-LOG-003 AOR-LOG-004 AOR-LOG-005 AOR-LOG-006

## AOR-CI (CI Pipeline Rules — 5 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CI-001 to AOR-CI-005 | CI pipeline — reproducible builds, timeout limits, test publishing, quality gates | Mandatory |

**Rule IDs:**
AOR-CI-001 AOR-CI-002 AOR-CI-003 AOR-CI-004 AOR-CI-005

## AOR-AGENT (Agent Mesh Rules — 4 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-AGENT-001 to AOR-AGENT-004 | Agent mesh — FQUN identity, Zenoh communication, state publishing, control commands | Mandatory |

**Rule IDs:**
AOR-AGENT-001 AOR-AGENT-002 AOR-AGENT-003 AOR-AGENT-004

## AOR-OBS (Observability Rules — 4 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-OBS-001 to AOR-OBS-004 | Observability — container health telemetry, OTEL integration, metric publishing | Mandatory |

**Rule IDs:**
AOR-OBS-001 AOR-OBS-002 AOR-OBS-003 AOR-OBS-004

## AOR-VAL (Validation Rules — 4 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VAL-001 to AOR-VAL-004 | Validation — FPPS line-by-line, pattern validation, compilation checks | Mandatory |

**Rule IDs:**
AOR-VAL-001 AOR-VAL-002 AOR-VAL-003 AOR-VAL-004

## AOR-BOOT (Boot Rules — 3 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BOOT-001 to AOR-BOOT-003 | Boot — state vector verification, migration check, quorum before stage 3 | Mandatory |

**Rule IDs:**
AOR-BOOT-001 AOR-BOOT-002 AOR-BOOT-003

## AOR-FFI (FFI Rules — 3 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FFI-001 to AOR-FFI-010 | FFI — Rust cdylib bridge safety, DllImport validation, LD_LIBRARY_PATH | Mandatory |

**Rule IDs:**
AOR-FFI-001 AOR-FFI-006 AOR-FFI-010

## AOR-FRAC (Fractal Verification Rules — 3 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FRAC-001 to AOR-FRAC-003 | Fractal verification — 8-level coverage, layer consistency, genotype topology | Mandatory |

**Rule IDs:**
AOR-FRAC-001 AOR-FRAC-002 AOR-FRAC-003

## AOR-RECONFIG (Reconfiguration Rules — 3 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-RECONFIG-003 to AOR-RECONFIG-007 | Reconfiguration — graph transformation, graceful degradation, Guardian approval | Mandatory |

**Rule IDs:**
AOR-RECONFIG-003 AOR-RECONFIG-004 AOR-RECONFIG-007

## AOR-GDE (GDE Rules — 2 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-GDE-001 to AOR-GDE-002 | GDE — shadow test framework, proposal validation pipeline | Mandatory |

**Rule IDs:**
AOR-GDE-001 AOR-GDE-002

## AOR-HLC (Hybrid Logical Clock Rules — 2 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-HLC-001 to AOR-HLC-002 | Hybrid logical clock — HLC timestamp ordering, trace correlation | Mandatory |

**Rule IDs:**
AOR-HLC-001 AOR-HLC-002

## AOR-IKE (IKE Rules — 2 rules)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-IKE-001 to AOR-IKE-003 | IKE — knowledge engine ingestion, entropy gating, drift detection | Mandatory |

**Rule IDs:**
AOR-IKE-001 AOR-IKE-003

## AOR-FED (Federation Rule — 1 rule)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FED-001 | Federation — Zenoh federation peer attestation | Mandatory |

**Rule IDs:**
AOR-FED-001

## AOR-LOGIC (Logic Rule — 1 rule)
| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-LOGIC-001 | Logic — ErrorPatterns validation logic consistency | Mandatory |

**Rule IDs:**
AOR-LOGIC-001
