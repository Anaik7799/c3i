# 2026-03-21 21:10 — Claude Skills Comprehensive Reference

## Context
- Branch: main
- Version: v21.3.0-SIL6
- Total Skills: 19 (14 custom + 5 built-in)

---

## 1. CUSTOM PROJECT SKILLS (14)

### 1.1 `/compile` — Patient Mode Compilation
**File**: `.claude/commands/compile.md`
**Tools**: Bash(mix:*), Read

**What it does**: Runs Elixir compilation with full Patient Mode environment — 16 schedulers, infinite timeout, parallel dependency compilation. Logs output to `./data/tmp/1-compile.log`.

**Features**:
- SC-METRICS-003 compliant: 16 schedulers MANDATORY (`+S 16:16 +SDio 16`)
- Patient Mode: `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true`
- Parallel deps: `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8`
- Post-compile: Reports warnings/errors, categorizes by type, verifies parallelization
- Additional modes: `compile-profile` (per-file timing), `compile-xref` (dependency graph)

**When to use**:
- Before any commit (SC-FUNC-001: system MUST compile at all times)
- After modifying multiple modules
- When investigating slow compilation (use profile mode)
- When hunting circular dependencies (use xref mode)

**Effective usage**:
```
/compile                    # Standard Patient Mode compilation
/compile --warnings-as-errors  # Strict mode for CI gates
```

---

### 1.2 `/test` — Test Runner with NIF & Parallelization
**File**: `.claude/commands/test.md`
**Tools**: Bash(mix:*), Read, Grep

**What it does**: Runs ExUnit tests with Zenoh NIF active, 16 schedulers, Patient Mode, and proper database configuration.

**Features**:
- SC-TEST-NIF-001: `SKIP_ZENOH_NIF=0` — NIF active by default
- SC-METRICS-003: 16 schedulers for parallel test execution
- Database: Auto-configures `DATABASE_URL` for test env (port 5433)
- Post-run: Summarizes pass/fail, extracts failure details with file:line references
- Error pattern detection: Checks for EP-GEN-014 (PropCheck/StreamData conflicts)
- PropCheck/StreamData alias verification

**When to use**:
- After any code change before committing
- For targeted test runs: `/test test/indrajaal/safety/`
- For specific tests: `/test test/indrajaal/safety/sentinel_test.exs:42`
- With trace: `/test --trace` for detailed output

**Effective usage**:
```
/test                           # Run all tests
/test test/sil6/                # Run SIL-6 test suite
/test --seed 12345              # Reproduce a specific run
/test test/indrajaal/safety/ --trace  # Detailed safety tests
```

---

### 1.3 `/quality` — Full Quality Gate Pipeline
**File**: `.claude/commands/quality.md`
**Tools**: Bash(mix:*)

**What it does**: Runs the complete 4-stage quality pipeline: format check, Credo static analysis, Dialyzer type checking, and Sobelow security scan.

**Features**:
- Stage 1: `mix format --check-formatted` — code formatting
- Stage 2: `mix credo --strict` — 0 issues required
- Stage 3: `mix dialyzer` — type correctness (Erlang success typing)
- Stage 4: `mix sobelow --exit` — OWASP security vulnerabilities
- Reports gate status (PASS/FAIL) for each stage
- Calculates overall quality score (0-100%)
- References relevant SC-* constraints on failure

**When to use**:
- Before any PR or merge (SC-FUNC-006: quality gates MUST pass)
- After refactoring sessions
- For pre-release verification (GA gate)

**Effective usage**:
```
/quality              # Run all 4 gates
# For faster iteration, run individual gates:
# mix format --check-formatted (fastest)
# mix credo --strict (seconds)
# mix dialyzer (minutes — cached PLTs)
# mix sobelow --exit (seconds)
```

---

### 1.4 `/stamp` — STAMP Safety Constraint Validator
**File**: `.claude/commands/stamp.md`
**Tools**: Read, Grep, Glob

**What it does**: Validates a file or module against 641+ STAMP safety constraints (SC-*) and Agent Operating Rules (AOR-*).

**Features**:
- Covers all constraint families: SC-VAL, SC-CNT, SC-AGT, SC-CMP, SC-SEC, SC-PROP, SC-ASH, SC-DB, SC-HOLON, SC-REG, SC-ZENOH, SC-SIL6, SC-BIO-EXT, etc.
- Extracts all constraint references from source code
- Cross-references against CLAUDE.md definitions
- Reports violations with severity levels (CRITICAL/HIGH/MEDIUM/LOW)
- Suggests remediation per constraint documentation

**When to use**:
- Before modifying safety-critical code (Guardian, Sentinel, Immutable Register)
- When adding new STAMP constraints
- For audit compliance verification
- After any change to the immune system or constitutional modules

**Effective usage**:
```
/stamp lib/indrajaal/safety/guardian.ex
/stamp lib/indrajaal/prometheus/verifier.ex
/stamp Indrajaal.Holon.ImmutableRegister
```

---

### 1.5 `/rca` — 5-Level Root Cause Analysis
**File**: `.claude/commands/rca.md`
**Tools**: Read, Grep, Glob, Bash(git:*)

**What it does**: Applies Toyota Production System (TPS) Jidoka 5-Why methodology to systematically identify root causes of errors.

**Features**:
- Level 1: Symptom — what error, where it manifests
- Level 2: Immediate Cause — what code caused it
- Level 3: Contributing Factors — missing validations/guards
- Level 4: Systemic Issues — patterns elsewhere, SC-* violations
- Level 5: Root Cause — fundamental issue, process change needed
- Outputs: RCA summary, affected files, recommended fixes, prevention measures
- Integrates with journal entries for documentation

**When to use**:
- Persistent test failures that resist simple fixes
- Production incidents
- Compilation errors after upgrades
- Any failure with RPN > 100

**Effective usage**:
```
/rca "Sentinel health check returns nil instead of numeric score"
/rca lib/indrajaal/safety/sentinel.ex:142
/rca "test timeout in zenoh_messaging_test.exs"
```

---

### 1.6 `/immune` — Digital Immune System Validator
**File**: `.claude/commands/immune.md`
**Tools**: Bash(mix:*), Read, Grep, Task

**What it does**: Validates the T-Cell immune architecture — Guardian, Sentinel, PatternHunter, and SymbioticDefense modules.

**Features**:
- **Guardian checks**: Absolute veto enforcement, shadow testing, constitutional protection
- **Sentinel checks**: Health scoring (0-100), error rate calculation, quarantine protocol, circuit breaker
- **PatternHunter checks**: Memory leak detection (>80%), CPU spike (>90%/60s), message queue growth, threat scoring
- **SymbioticDefense checks**: Recovery mechanism, threat escalation (green→black), Founder's Directive IMMEDIATE response
- Documents known P0 issues with fix status
- Reports module health: HEALTHY | DEGRADED | CRITICAL

**When to use**:
- Before any release (immune system is SIL-6 critical)
- After modifying safety/ directory modules
- When investigating system health degradation
- Regular periodic validation (weekly recommended)

**Effective usage**:
```
/immune check                    # Check all immune modules
/immune test                     # Run immune system tests
/immune status Sentinel          # Check specific module
```

---

### 1.7 `/fmea` — Failure Mode and Effects Analysis
**File**: `.claude/commands/fmea.md`
**Tools**: Read, Grep, Glob

**What it does**: Performs IEC 61508 / ISO 26262 compliant FMEA on any module — identifies failure modes, scores risk, recommends mitigations.

**Features**:
- **Scoring**: Severity (1-10), Occurrence (1-10), Detection (1-10)
- **RPN calculation**: S x O x D — prioritizes by risk
- **Risk thresholds**: >200 critical, >100 high, >50 medium
- **Failure categories**: Omission, Commission, Value, Timing, Stuck
- Lists all functions and state transitions
- Maps to STAMP constraints
- Generates Pareto chart of highest risks

**When to use**:
- When designing new safety-critical features
- Before deploying changes to production
- For audit documentation
- When RPN > 50 requires formal mitigation (AOR-GA-003)

**Effective usage**:
```
/fmea lib/indrajaal/safety/sentinel.ex
/fmea Indrajaal.Cockpit.Prajna.GuardianIntegration
/fmea "alarm storm handling"
```

---

### 1.8 `/impact` — 1st-5th Order Impact Analysis
**File**: `.claude/commands/impact.md`
**Tools**: Read, Grep, Glob, WebSearch

**What it does**: Performs multi-order cascade analysis showing how a change ripples through the system across 7 fractal layers (L0-L6).

**Features**:
- **1st Order**: Direct callers, immediate effects
- **2nd Order**: Caller cascade within domain
- **3rd Order**: Cross-domain effects (10 Ash domains)
- **4th Order**: System-wide (50 agents, 3 containers)
- **5th Order**: Ecosystem/hyperscaler effects
- **Scale levels**: Function → Module → Domain → System → Cluster → Federation → Hyperscalar
- Maps STAMP constraints affected
- Generates caller cascade tree and domain impact matrix

**When to use**:
- Before modifying shared infrastructure (Zenoh, Guardian, supervision trees)
- For architecture reviews (impact score > 20 requires senior review per SC-CHG-009)
- When planning refactors that cross domain boundaries
- Before any L3+ layer change (AOR-CHG-010)

**Effective usage**:
```
/impact lib/indrajaal/cockpit/prajna/guardian_integration.ex
/impact Indrajaal.Safety.Sentinel
/impact "database connection pooling"
```

---

### 1.9 `/sa` — Standalone Environment Management
**File**: `.claude/commands/sa.md`
**Tools**: Bash(podman-compose:*), Bash(podman:*)

**What it does**: Manages the container stack lifecycle — start, stop, status, logs, cleanup.

**Features**:
- **up**: Start all containers (prod-standalone: 4 containers)
- **down**: Stop containers gracefully
- **status**: Show container health status
- **logs**: Stream container logs (optionally filtered by service name)
- **clean**: Stop and remove volumes
- Uses `podman-compose-prod-standalone.yml`
- Container architecture: DB (5433), Obs (4317/9090/3000/3100), App (4000/4001/6379)

**When to use**:
- Starting development environment
- Before running integration tests that need containers
- Debugging container health issues
- Cleaning up after test sessions

**Effective usage**:
```
/sa up                    # Start all containers
/sa status                # Check health
/sa logs indrajaal-ex-app-1  # Stream app logs
/sa down                  # Stop gracefully
/sa clean                 # Remove everything including volumes
```

---

### 1.10 `/sil4` — IEC 61508 SIL-4 Compliance Validator
**File**: `.claude/commands/sil4.md`
**Tools**: Read, Grep, Glob, WebSearch

**What it does**: Validates Safety Integrity Level 4 compliance per IEC 61508 standard.

**Features**:
- **PFH check**: Probability of Failure/Hour < 10^-8
- **Diagnostic Coverage**: > 99%
- **Safe Failure Fraction**: > 99%
- **Hardware Fault Tolerance**: >= 2 (Triple Modular Redundancy)
- Checks dual-channel verification patterns
- Verifies TMR voting logic (2oo3)
- Assesses watchdog coverage (< 2s timeout)
- Safe state achievability within 100ms
- Generates compliance matrix (PASS/FAIL per requirement)

**When to use**:
- During safety certification preparation
- When modifying Guardian, Sentinel, or voting logic
- For pre-release safety audit
- When adding new safety functions

**Effective usage**:
```
/sil4 lib/indrajaal/safety/guardian.ex
/sil4 Indrajaal.Safety.Sentinel
/sil4 "immutable register"
```

---

### 1.11 `/robustness` — System Robustness Analyzer
**File**: `.claude/commands/robustness.md`
**Tools**: Read, Grep, Glob

**What it does**: Analyzes fault tolerance, configurability, and resilience patterns across 4 dimensions.

**Features**:
- **Fault Tolerance**: Graceful degradation, fail-fast, self-healing
- **Configurability**: Environment-based, runtime adjustable, validated
- **Resilience Patterns**: Circuit breaker, bulkhead, retry, timeout
- **Observability**: Health checks, metrics, tracing, logging
- Configuration profiles: Development, Test, Production, SIL-4
- Robustness score (1-100)
- Hardening recommendations with priority

**When to use**:
- Architecture reviews
- Before deploying to production
- When investigating reliability issues
- After adding external service integrations

**Effective usage**:
```
/robustness lib/indrajaal/cockpit/prajna/
/robustness Indrajaal.Safety.Sentinel
/robustness "supervisor tree"
```

---

### 1.12 `/hyperscaler` — Hyperscaler Pattern Comparison
**File**: `.claude/commands/hyperscaler.md`
**Tools**: Read, Grep, Glob, WebSearch

**What it does**: Compares Indrajaal architecture against Google, Meta, Netflix, and Microsoft reference implementations.

**Features**:
- **Google**: Monarch (metrics), Dapper (tracing), Borg (orchestration), Spanner (DB)
- **Meta**: Scuba (analytics), TAO (graph), Gorilla (TSDB)
- **Netflix**: Atlas (metrics), Edgar (tracing), Hystrix (resilience), Chaos Monkey
- **Microsoft**: Azure Monitor, Application Insights, Cosmos DB, Service Fabric
- Comparison categories: Metrics, tracing, logs, resilience, chaos, auto-scaling
- Feature coverage scoring (1-10 per category)
- Identifies unique Indrajaal advantages
- Generates adoption roadmap

**When to use**:
- Architecture planning and roadmap decisions
- Competitive positioning analysis
- Pattern adoption evaluation
- Investor/stakeholder presentations

**Effective usage**:
```
/hyperscaler observability        # Compare observability stack
/hyperscaler "distributed tracing"  # Specific capability
/hyperscaler all                  # Full comparison
```

---

### 1.13 `/datadog` — Datadog Observability Comparison
**File**: `.claude/commands/datadog.md`
**Tools**: Read, Grep, Glob, WebSearch

**What it does**: Compares Indrajaal observability stack against Datadog's 47-product suite across 11 categories.

**Features**:
- **11 categories**: Infrastructure, APM, Logs, Digital Experience, Security, AI/ML, Collaboration, Developers, Platform, Integrations, Service Management
- Feature matrix with coverage percentage
- Gap analysis (critical/high/medium)
- Unique advantages: Constitutional AI, Zenoh mesh, biomorphic self-healing
- Cost comparison (targets 85% TCO savings)
- Build vs buy recommendations

**When to use**:
- Product positioning vs commercial APM solutions
- Feature gap analysis for observability roadmap
- Build-vs-buy decisions for monitoring components
- Customer conversations about observability

**Effective usage**:
```
/datadog all                      # Full 47-product comparison
/datadog apm                      # APM-specific comparison
/datadog "log management"         # Log management comparison
/datadog lib/indrajaal/observability/  # Map existing code to Datadog
```

---

### 1.14 `/journal` — Development Journal Entry
**File**: `.claude/commands/journal.md`
**Tools**: Write, Bash(date:*), Bash(git:*)

**What it does**: Creates a timestamped development journal entry in `journal/YYYY-MM/` with git context, technical details, STAMP compliance, and KPIs.

**Features**:
- Auto-timestamps: `YYYYMMDD-HHMM-{topic-slug}.md`
- Git context: Current branch, recent commits
- Structured sections: Context, Summary, Technical Details, STAMP Compliance, Next Steps, KPIs
- KPI tracking: Files changed, lines added/removed, test results, warning count

**When to use**:
- After completing a sprint or significant task
- When documenting architectural decisions
- After resolving complex bugs (pair with /rca)
- For audit trail documentation

**Effective usage**:
```
/journal sprint-54-morphogenesis-complete
/journal zenoh-ffi-v2-instrumented
/journal auth-hardening-complete
```

---

## 2. BUILT-IN CLAUDE CODE SKILLS (5)

### 2.1 `/update-config`
**Purpose**: Configure Claude Code harness via settings.json
**Use for**: Permissions, env vars, hooks, automated behaviors
**Examples**:
```
/update-config allow all bash commands
/update-config add permission for mix commands
/update-config set DEBUG=true
```

### 2.2 `/keybindings-help`
**Purpose**: Customize keyboard shortcuts in `~/.claude/keybindings.json`
**Use for**: Rebinding keys, adding chord shortcuts
**Examples**:
```
/keybindings-help rebind ctrl+s
/keybindings-help add a chord shortcut
```

### 2.3 `/simplify`
**Purpose**: Review changed code for reuse, quality, and efficiency
**Use for**: Post-implementation code review, finding over-engineering
**Examples**:
```
/simplify    # Reviews recent changes and suggests simplifications
```

### 2.4 `/loop`
**Purpose**: Run a prompt or slash command on a recurring interval
**Use for**: Polling, monitoring, recurring tasks
**Examples**:
```
/loop 5m /sa status              # Check containers every 5 min
/loop 10m /compile               # Recompile every 10 min
/loop 30s "check deployment"     # Monitor deployment every 30s
```

### 2.5 `/claude-api`
**Purpose**: Help building apps with Claude API or Anthropic SDK
**Triggers when**: Code imports `anthropic`, `@anthropic-ai/sdk`, or `claude_agent_sdk`
**Use for**: API integration, tool use patterns, agent SDK usage

---

## 3. SKILL INTERACTION PATTERNS

### Safety Audit Flow
```
/stamp [module]     → Identify constraint violations
/fmea [module]      → Score failure modes (RPN)
/sil4 [module]      → Check SIL-4 compliance
/immune check       → Validate immune system
/rca [error]        → Root cause if issues found
/journal [slug]     → Document findings
```

### Development Flow
```
/compile            → Build with Patient Mode
/test [path]        → Run tests
/quality            → Format + Credo + Dialyzer + Sobelow
/impact [file]      → Assess change cascade
/journal [slug]     → Document the work
```

### Architecture Review Flow
```
/robustness [system]    → Fault tolerance analysis
/hyperscaler [area]     → Compare to industry leaders
/datadog [category]     → Observability gap analysis
/impact [module]        → Cascade effect mapping
```

### Incident Response Flow
```
/rca [error]        → 5-Why root cause analysis
/immune status      → Check immune system health
/stamp [module]     → Verify safety constraints
/fmea [module]      → Risk score the failure
/sa status          → Check container health
```

---

## 4. STAMP CONSTRAINTS COVERED BY SKILLS

| Skill | Primary SC-* | Count |
|-------|-------------|-------|
| `/compile` | SC-METRICS-001 to SC-METRICS-007, SC-CMP-025 to SC-CMP-028 | 12 |
| `/test` | SC-TEST-NIF-001, SC-METRICS-003, SC-PROP-021 to SC-PROP-025 | 10 |
| `/quality` | SC-CMP-025, SC-CREDO-001 to SC-CREDO-005, SC-SEC-044 | 8 |
| `/stamp` | All 641+ SC-* constraints | 641+ |
| `/rca` | SC-FUNC-001, SC-EMR-057, SC-JIDOKA-001 | 5 |
| `/immune` | SC-IMMUNE-001 to SC-IMMUNE-010, SC-CONST-007, SC-GDE-001 | 14 |
| `/fmea` | IEC 61508, ISO 26262 | N/A |
| `/impact` | SC-CHG-002, SC-CHG-009 | 4 |
| `/sa` | SC-CNT-009 to SC-CNT-012, SC-EMR-057 | 6 |
| `/sil4` | SC-SIL6-001 to SC-SIL6-015 | 15 |
| `/robustness` | SC-PRF-050, SC-EMR-057 to SC-EMR-060 | 8 |
| `/journal` | SC-CHG-001, SC-CHG-005, SC-CHG-006 | 3 |

---

## 5. TIPS FOR EFFECTIVE SKILL USAGE

1. **Chain skills**: Run `/stamp` before `/fmea` — constraint violations inform failure modes
2. **Use arguments**: All skills accept file paths, module names, or topic descriptions
3. **Pre-commit ritual**: `/compile` → `/test` → `/quality` (minimum before any commit)
4. **Safety ritual**: `/stamp` → `/fmea` → `/sil4` → `/immune` (before safety-critical changes)
5. **Document everything**: End every significant session with `/journal`
6. **Monitor continuously**: Use `/loop` to poll `/sa status` during deployment
7. **Know your blast radius**: Run `/impact` before touching shared modules
8. **Compare often**: `/hyperscaler` and `/datadog` keep architecture competitive
