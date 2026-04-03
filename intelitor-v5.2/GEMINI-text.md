# CLAUDE.md - Indrajaal Safety-Critical System Exhaustive Specification

**Version**: 10.2.0-UNIFIED
**Classification**: IMMUTABLE SYSTEM AXIOMS + FORMAL VERIFICATION + CYBERNETIC PROTOCOLS
**Origin**: Consolidated from CLAUDE-20251207.md + Mathematical Foundations v6.0.0 + CLAUDE.md v10.2.0
**Updated**: 2025-12-19 11:10 CEST
**Status**: SOPv5.11 CYBERNETIC FRAMEWORK + HYBRID AI ARCHITECTURE + ZERO-DEFECT QUALITY + FORMAL VERIFICATION + THREE-LAYER PROOF SYSTEM
**Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131
**Test Strategy**: docs/testing/comprehensive-formal-verification-test-strategy.md
**Synced With**: CLAUDE.md v10.2.0-UNIFIED (Mathematica notation)

---

## 0.0 Mathematical Preliminaries

### 0.1 Formal Notation Reference
| Symbol | Meaning | Domain |
|--------|---------|--------|
| $\forall$ | Universal quantifier ("for all") | Logic |
| $\exists$ | Existential quantifier ("there exists") | Logic |
| $\implies$ | Logical implication | Logic |
| $\iff$ | Logical equivalence (if and only if) | Logic |
| $\wedge$ | Logical conjunction (AND) | Logic |
| $\vee$ | Logical disjunction (OR) | Logic |
| $\neg$ | Logical negation (NOT) | Logic |
| $\in$ | Set membership | Set Theory |
| $\subseteq$ | Subset relation | Set Theory |
| $\cup$ | Set union | Set Theory |
| $\cap$ | Set intersection | Set Theory |
| $\emptyset$ | Empty set | Set Theory |
| $\Box$ | "Always" (temporal logic) | LTL |
| $\diamond$ | "Eventually" (temporal logic) | LTL |
| $\bigcirc$ | "Next" (temporal logic) | LTL |
| $\{P\} C \{Q\}$ | Hoare Triple (Pre, Command, Post) | Hoare Logic |

### 0.2 Type Universe ($\mathcal{U}$)
```
Type Universe:
├── Base Types
│   ├── Nat (Natural numbers: 0, 1, 2, ...)
│   ├── Bool (true, false)
│   ├── String (UTF-8 text)
│   └── Timestamp (CEST/CET, NEVER UTC)
├── Domain Types
│   ├── Agent ⊂ {Executive, Supervisor, Worker}
│   ├── Container ⊂ {indrajaal-app, indrajaal-db, indrajaal-obs}
│   ├── Phase ⊂ {1, 2, 3, 4, 5, 6, 7}
│   └── Status ⊂ {pending, in_progress, completed, blocked}
└── Composite Types
    ├── SafetyConstraint := (ID: String, Category: SC_Category, Description: String)
    ├── ValidationResult := (Method: FPPS_Method, Errors: Nat, Warnings: Nat, Consensus: Bool)
    └── CompilationState := (Files: Nat, Errors: Nat, Warnings: Nat, ExitCode: Nat)
```

### 0.3 Core Domain Sets
- $\mathcal{A}_{50}$ = Set of 50 Agents = {1 Executive + 10 Domain + 15 Functional + 24 Workers}
- $\mathcal{C}_{3}$ = Set of 3 Containers = {indrajaal-app, indrajaal-db, indrajaal-obs}
- $\mathcal{D}_{10}$ = Set of 10 Ash Domains = {access_control, accounts, alarms, analytics, communication, compliance, devices, performance, observability, web_api}
- $\mathcal{F}_{773}$ = Set of 773 Source Files
- $\mathcal{SC}_{242}$ = Set of 242 STAMP Safety Constraints (72 core + 6 SC-AGT agent code + 8 integration + 40 SC-DB database + 5 SC-PROP PropCheck + 10 SC-ASH Ash + 20 SC-DOC documentation + 5 SC-BATCH batch + 10 SC-ASH-3x Ash 3.x + 12 SC-FAC factory + 3 SC-CMP compilation + 6 SC-FLAME + 5 SC-CLU clustering + 5 SC-CLAUDE-API + 7 SC-CLAUDE + 4 SC-CA cybernetic architect + 10 SC-TODO + 6 AOR-FV + 5 TDG-FV + 3 SC-MIG migration)
- $\mathcal{EP}_{114}$ = Set of 114 Error Patterns (EP-001 to EP-080 system + EP-AGT-001 to EP-AGT-013 agent + EP-FAC-001 to EP-FAC-008 factory + EP-FV-001 to EP-FV-013 formal verification)
- $\mathcal{M}_{5}$ = Set of 5 FPPS Validation Methods = {Pattern, AST, Statistical, Binary, Line-by-Line}

---

## 1.0 Fundamental Axioms (The $\aleph_0$ Set)

These axioms are foundational truths. Any state $S$ where an axiom is violated is a **Critical Failure State** ($S_{fail}$).

### Axiom 1: The Patient Mode Invariant

**Formal Definition**:
$\forall \text{compilation } c \in \mathcal{O}_{comp}$:
1. **Unbounded Execution**: `NO_TIMEOUT=true`, `PATIENT_MODE=enabled`, `INFINITE_PATIENCE=true`
2. **Resource Maximization**: `ELIXIR_ERL_OPTIONS="+S <N>:<N>"` where N = available CPU cores
3. **Parallel Compilation**: `--jobs <N>` flag for N concurrent compilation processes
4. **OS-Level Partitioning**: `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=<N/2>` for dependency compilation
5. **Observability**: $Output(c) \rightarrow \text{Stream} \xrightarrow{pipe} \text{File}(L_c)$
6. **Atomic Analysis**: Log file $L_c$ is **locked** for reading until $P_c$ terminates ($exit\_code \neq \emptyset$)
7. **Mandatory Log Path**: All logs MUST go to `./data/tmp/1-compile.log`

**MANDATORY PATIENT MODE COMMAND** (Elixir 1.19+ Optimized):
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5 \
mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```

**Alternative with explicit exports**:
```bash
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10"
export MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5
mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```

**Compilation Optimization Parameters** (Elixir 1.19+):
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `--jobs <N>` | 10 | Parallel compilation processes (match CPU cores) |
| `ELIXIR_ERL_OPTIONS="+S <N>:<N>"` | +S 10:10 | BEAM scheduler count (online:offline) |
| `ELIXIR_ERL_OPTIONS="+SDio <N>"` | +SDio 10 | Dirty I/O schedulers for I/O-bound tasks |
| `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` | 5 | OS processes for dependency compilation (N/2) |

**Patient Mode Requirements**:
- 1.0 - **Infinite Patience**: NO_TIMEOUT=true overrides all timeout defaults
- 2.0 - **Complete Logging**: ALL output captured with tee -a for comprehensive analysis
- 3.0 - **Parallel Compilation**: Use `--jobs <N>` for concurrent file compilation (Elixir 1.19+)
- 4.0 - **BEAM Scheduler Tuning**: `+S <N>:<N>` for online:offline scheduler ratio
- 5.0 - **Dependency Partitioning**: `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=<N/2>` for parallel deps
- 6.0 - **Zero Interruption**: NEVER interrupt compilation regardless of duration
- 7.0 - **Post-Completion Analysis**: Analyze complete log ONLY after natural completion
- 8.0 - **Multi-Method Validation**: Use FPPS 5-method consensus to prevent false positives

**Patient Supervisor Coordination** (20-Minute Timeout Management):
- **Primary Timeout**: 20-minute execution window per major operation
- **15 Retry Strategy**: Up to 15 retry attempts for transient failures
- **Checkpoint Preservation**: State checkpoints every 5 minutes
- **Graceful Degradation**: Automatic quality-vs-speed tradeoff when timeouts approach

**FORBIDDEN ACTIONS** ($\mathbb{F}_{PM}$):
1. Using `head`/`tail` commands during compilation (Partial analysis)
2. Interrupting compilation due to time concerns (Impatient execution)
3. Manual timeout limits (Patient Mode requires infinite patience)
4. Partial log analysis (Must analyze complete compilation output)
5. Using `mix compile` without full AEE workflow
6. Saving logs to wrong directory (MUST use `./data/tmp/`)
7. Simple `mix compile` without environment variables
8. Checking compilation status before completion

---

### Axiom 2: The Container Isolation Invariant

**Formal Definition**:
$\forall \text{process } p$:
1. **Environment**: $E_p \equiv \text{NixOS Container}$
2. **Runtime**: $R_p \equiv \text{Podman v5.4.1+}$ (Rootless)
3. **Registry Source**: $S_{img} \in \{ \text{localhost/} \}$ (Strict Localhost Policy)
4. **Forbidden Set**: $\mathbb{F}_{CNT} = \text{Docker} \cup \text{Alpine} \cup \text{Ubuntu} \cup \text{Proprietary Registries}$
5. **Constraint**: $S_{img} \cap \mathbb{F}_{CNT} \equiv \emptyset$
6. **Synchronization**: PHICS v2.1 active with latency $\delta < 50ms$

**Podman-Only Container Infrastructure Policy (ZERO TOLERANCE)**:
```bash
# APPROVED container commands
podman --version  # Must be 5.4.1+
podman-compose -f podman-compose.yml up -d
podman images | grep localhost/
elixir scripts/performance/podman_direct_manager.exs --status

# BANNED container commands
docker-compose  # VIOLATION
docker run      # VIOLATION
docker pull     # VIOLATION
```

**Container Allocation Matrix (3-Container Model)**:
| Container | Purpose | Image | Resources |
|-----------|---------|-------|-----------|
| `indrajaal-app` | Application | `localhost/indrajaal-app:fully-functional` | 12 CPU, 32GB RAM |
| `indrajaal-db` | Database | `localhost/indrajaal-timescaledb-demo:nixos-devenv` | 4 CPU, 16GB RAM |
| `indrajaal-obs` | Observability | `localhost/indrajaal-observability:nixos` | 4 CPU, 8GB RAM |

**Total Resources**: 20 CPU cores, 56GB RAM across 3 consolidated containers

**4-Environment Deployment Architecture**:
| Environment | App Location | DB Location | Obs Location | Use Case |
|-------------|--------------|-------------|--------------|----------|
| **Development & Testing** | Host | Container | Container | Rapid dev iteration, test execution |
| **Demo** | Container | Container | Container | Stakeholder demonstrations |
| **Staging** | Kubernetes | Kubernetes | Kubernetes | Pre-production validation |
| **Production** | Kubernetes | Kubernetes | Kubernetes | Customer-facing deployment |

**Environment Commands**:
```bash
# Development & Testing (App on Host)
elixir scripts/env/dev-start.exs   # Start DB + Obs containers
mix phx.server                      # Run app on host
MIX_ENV=test mix test              # Run tests directly

# Demo (All Containers)
elixir scripts/env/demo-start.exs  # Start all containers
elixir scripts/env/demo-stop.exs   # Stop all containers

# Staging/Production (Kubernetes)
kubectl apply -k k8s/overlays/staging/
kubectl apply -k k8s/overlays/production/
```

**Note**: The 50-agent architecture (1 Executive + 10 Domain + 15 Functional + 24 Workers)
operates as logical entities within the single indrajaal-app container. Domain Supervisors
manage their respective Ash domains without requiring separate containers.

**Service Port Registry**:
| Service | Container | Port | Protocol |
|---------|-----------|------|----------|
| Phoenix | indrajaal-app | 4000 | HTTP/WS |
| Health Check | indrajaal-app | 4001 | HTTP |
| PostgreSQL | indrajaal-db | 5433 | TCP |
| ClickHouse HTTP | indrajaal-obs | 8123 | HTTP |
| OTEL Collector gRPC | indrajaal-obs | 4317 | gRPC |
| OTEL Collector HTTP | indrajaal-obs | 4318 | HTTP |
| Grafana | indrajaal-obs | 3001 | HTTP |
| Prometheus | indrajaal-obs | 9090 | HTTP |
| Nginx | indrajaal-obs | 8080, 8443 | HTTP/HTTPS (Rootless) |

**Automatic Container Enforcement System**:
```elixir
# All commands now auto-enforce containers
mix compile --warnings-as-errors         # Auto-container execution
mix phx.server                           # Auto-container with PHICS hot-reloading
mix test --coverage                      # Auto-container execution
mix dialyzer                            # Auto-container execution
```

**FORBIDDEN ACTIONS** ($\mathbb{F}_{CNT}$):
1. Using Docker instead of Podman
2. Using Alpine/Ubuntu base images
3. Pulling from external registries
4. Running containers as root
5. Disabling PHICS synchronization
6. Manual container management without frameworks
7. Bypassing quality gates or preflight checks

---

### Axiom 3: The Zero-Defect Quality Invariant

**Formal Definition**:
The System State is Valid ($S_{valid}$) iff:
$$ \sum \text{CompErrors} + \sum \text{Warnings} + \sum \text{TestFails} + \sum \text{FormatFails} + \sum \text{CredoFails} + \sum \text{SecFails} \equiv 0 $$

**Quality Validation Commands**:
```bash
# Complete compilation validation
mix clean && mix compile --force --all-warnings --verbose 2>&1 | tee -a compilation.log

# Format validation
mix format --check-formatted

# Static analysis
mix credo --strict

# Security validation
mix sobelow --strict

# Pre-commit quality checks (MANDATORY)
mix format --check-formatted && mix credo --strict && mix dialyzer && mix sobelow --exit && mix test --coverage
```

**Quality Gate Thresholds**:
| Gate | Metric | Threshold | Action on Failure |
|------|--------|-----------|-------------------|
| Compilation | Errors | 0 | HALT |
| Compilation | Warnings | 0 | HALT |
| Format | Violations | 0 | HALT |
| Credo | Issues | 0 | HALT |
| Sobelow | Vulnerabilities | 0 | HALT |
| Tests | Failures | 0 | HALT |
| Coverage | Percentage | >95% | WARNING |

---

### Axiom 4: The Test-Driven Generation (TDG) Invariant

**Formal Definition**:
Let $C$ be the set of Code and $T$ be the set of Tests.
$\forall c_{new} \in C$:
1. $\exists t \in T : \text{time}(creation(t)) < \text{time}(creation(c_{new}))$
2. $\text{Result}(t | \{C \setminus c_{new}\}) = \text{Fail}$
3. $\text{Result}(t | \{C \cup c_{new}\}) = \text{Pass}$
4. **Dual Property**: $\text{PropCheck} \in t \wedge \text{ExUnitProperties} \in t$

**TDG Workflow (MANDATORY)**:
```
1.0 - TEST FIRST: Write comprehensive tests BEFORE any code generation
2.0 - AI GENERATION: Generate code to satisfy existing tests
3.0 - VALIDATION: Ensure all tests pass with generated code
4.0 - AGENT CODE VALIDATION: Run agent_code_validator.exs for agent-generated code
5.0 - COMPILATION GATE: Verify 0 errors, 0 warnings before delivery (SC-AGT-025, SC-AGT-026)
6.0 - REFACTOR: Improve code quality while maintaining test coverage
7.0 - DOCUMENTATION: Update docs to reflect TDG methodology compliance
```

**Agent-Generated Code TDG Extension (MANDATORY for parallel agent execution)**:
```
1.0 - BASERESOURCE ANALYSIS: Analyze BaseResource for existing code_interface definitions
2.0 - DOMAIN REGISTRATION: Verify new resources are registered in their domains
3.0 - ASH DSL VALIDATION: Validate accept vs argument, require_atomic?, constraint types
4.0 - ELIXIR SYNTAX CHECK: Detect non-Elixir patterns (return, |||, wrong try order)
5.0 - LIBRARY API CHECK: Verify current API versions (Guardian, Cachex, etc.)
6.0 - COMPILATION VERIFICATION: Run mix compile before marking task complete
7.0 - JIDOKA TRIGGER: Auto-trigger stop-and-fix on any compilation failure
```

**Dual Property-Based Testing Strategy (ZERO TOLERANCE)**:
```elixir
defmodule CriticalFeatureTest do
  use ExUnit.Case, async: true
  use PropCheck          # Advanced property testing with sophisticated shrinking
  use ExUnitProperties   # StreamData-based property testing

  # PropCheck property test
  property "propcheck: feature handles all edge cases with advanced shrinking" do
    forall {input1, input2} <- {integer(), boolean()} do
      result = CriticalFeature.process(input1, input2)
      is_valid_result(result)
    end
  end

  # ExUnitProperties test
  property "exunitproperties: feature maintains consistency across inputs" do
    check all input1 <- integer(),
              input2 <- boolean(),
              max_runs: 100 do
      result = CriticalFeature.process(input1, input2)
      assert is_valid_result(result)
    end
  end
end
```

**FORBIDDEN ACTIONS** ($\mathbb{F}_{TDG}$):
1. Code-First Generation (generating code before tests exist)
2. Untested Code (all generated code must have corresponding tests)
3. Post-Hoc Testing (tests must be written BEFORE code generation)
4. Skipping TDG (no exceptions for any AI-generated code)
5. Manual Testing Only (automated tests required)
6. Single Library Limitation (MUST use both PropCheck and ExUnitProperties)

---

### Axiom 5: The Validation Consensus Invariant (EP-110 Prevention)

**Formal Definition**:
Let $\mathcal{M}$ be the set of Validation Methods $\{ \text{Pattern}, \text{AST}, \text{Statistical}, \text{Binary}, \text{Line-by-Line} \}$.
A validation result $V$ is accepted iff:
$$ \forall m_i, m_j \in \mathcal{M} : \text{Result}(m_i) \equiv \text{Result}(m_j) $$
If $\exists m_i, m_j : \text{Result}(m_i) \neq \text{Result}(m_j) \implies \text{Trigger}(\text{EmergencyProtocol})$

**EP-110 Incident Reference (2025-09-16)**:
- **Reported**: 0 errors, 17 warnings
- **Actual**: 372 errors, 5,004 warnings
- **Cause**: Simple string matching + partial log analysis + no consensus validation
- **Impact**: 294x warning undercount, complete error blindness

**MANDATORY VALIDATION COMMANDS**:
```bash
# Step 1: Claude FPPS 5-Method Validation
elixir scripts/validation/comprehensive_compilation_validator.exs --log ./data/tmp/1-compile.log --require-consensus --save-report

# Step 2: Grok Independent Validation (prevents Claude groupthink)
elixir scripts/validation/grok_xai_validator_integration.exs --validate ./data/tmp/1-compile.log

# Step 3: MANUALLY verify (ground truth)
echo "Manual error count: $(grep -c 'error:' ./data/tmp/1-compile.log)"
echo "Manual warning count: $(grep -c 'warning:' ./data/tmp/1-compile.log)"
echo "Expected: 0 errors, 0 warnings"

# Step 4: Dual-Agent Consensus Check
# Claude FPPS result vs Grok result vs Manual count
# ALL THREE must agree or investigation required
```

**FORBIDDEN Validation Patterns**:
```elixir
# NEVER USE THESE PATTERNS:
count = String.split(output, "\n") |> Enum.count(&String.contains?(&1, "warning:"))
errors = if output =~ "error", do: 1, else: 0
{:ok, result} = validate(output)  # Without checking other methods
if method1 != method2, do: Logger.warn("Methods disagree")  # Must halt!
```

---

### Axiom 6: The Mandatory Validation Gate Invariant

**Formal Definition**:
Let $F$ be any Feature and $G$ be the set of Validation Gates $\{G_{compile}, G_{runtime}, G_{tdg}, G_{stamp}\}$.
A feature $F$ is considered **Complete** ($F_{complete}$) iff:
$$ \forall g \in G : \text{Pass}(g, F) = \text{true} $$

**Gate Definitions**:
1. **$G_{compile}$** (Compile-Time Gate): Zero errors AND zero warnings with `--warnings-as-errors`
2. **$G_{runtime}$** (Runtime Gate): All functional tests pass with both PropCheck AND ExUnitProperties
3. **$G_{tdg}$** (TDG Gate): Tests MUST exist BEFORE corresponding code (timestamp validation)
4. **$G_{stamp}$** (STAMP Gate): All 72 safety constraints validated for affected domains
5. **$G_{fpps}$** (FPPS Gate): 5-method validation consensus achieved
6. **$G_{coverage}$** (Coverage Gate): Code coverage >95% for new code
7. **$G_{format}$** (Format Gate): `mix format --check-formatted` passes
8. **$G_{credo}$** (Credo Gate): `mix credo --strict` passes
9. **$G_{sobelow}$** (Sobelow Gate): `mix sobelow --strict` passes

**Mandatory Validation Command**:
```bash
mix feature.complete --validate FEATURE_NAME
```

**Feature Completion Checklist** (ALL MUST PASS):
- [ ] Compilation: Zero errors, zero warnings (`mix compile --warnings-as-errors`)
- [ ] Tests Exist: TDG compliance verified (tests created before code)
- [ ] Tests Pass: All unit, integration, and property tests pass
- [ ] STAMP Compliance: Affected safety constraints validated
- [ ] FPPS Validation: 5-method consensus achieved on compilation log
- [ ] Code Coverage: >95% for new code
- [ ] Format Check: `mix format --check-formatted` passes
- [ ] Static Analysis: `mix credo --strict` passes
- [ ] Security Scan: `mix sobelow --strict` passes

**Implementation Modules**:
- `Indrajaal.Validation.MandatoryGates` - Central gate coordinator
- `Indrajaal.Validation.FeatureCompletionValidator` - Feature validation with TDG timestamp checking
- `Indrajaal.Stamp.RuntimeConstraintMonitor` - 72 STAMP constraint validation
- `Indrajaal.TDG.PreGenerationValidator` - Pre-code-generation TDG enforcement

**FORBIDDEN ACTIONS** ($\mathbb{F}_{VG}$):
1. Marking feature complete without all gates passing
2. Generating new code without existing tests (TDG violation)
3. Bypassing validation gates for "quick fixes"
4. Committing code with compilation warnings
5. Skipping STAMP validation for "non-critical" features
6. Using single validation method instead of FPPS consensus
7. Ignoring pre-commit hook validation failures

---

## 2.0 System Architecture ($\Sigma$)

### 2.1 The 50-Agent Hierarchy ($\mathcal{A}_{50}$)

The system is managed by a precise hierarchy of 50 cybernetic agents forming a category $\mathbf{Agent}$.

**Layer 1: Executive Director (1 Agent)**
- **Supreme Authority**: Complete system oversight and strategic coordination
- **Emergency Powers**: Can halt, restart, or redirect entire operation
- **Decision Making**: 100% autonomous with enterprise-grade quality gates
- **Coordination Efficiency**: 98.9% with real-time optimization

**Layer 2: Domain Supervisors (10 Agents)**
| ID | Domain | Responsibility | Container |
|----|--------|----------------|-----------|
| Domain-01 | Access Control | Security Access Management | access_control |
| Domain-02 | Accounts | User Management | accounts |
| Domain-03 | Alarms | Alert Processing | alarms |
| Domain-04 | Analytics | Data Analysis | analytics |
| Domain-05 | Communication | Messaging Systems | communication |
| Domain-06 | Compliance | Regulatory Compliance | compliance |
| Domain-07 | Devices | Hardware Management | devices |
| Domain-08 | Performance | System Optimization | performance |
| Domain-09 | Observability | Monitoring & Logging | observability |
| Domain-10 | Web API | API Gateway | web_api |

**Layer 3: Functional Supervisors (15 Agents)**
- **Compilation Specialists (5)**:
  - Syntax Validator: AST parsing and syntax error detection
  - Type Checker: Dialyzer integration and type specification validation
  - Dependency Resolver: Mix dependency management and conflict resolution
  - Parallel Optimizer: Multi-core compilation optimization
  - Quality Validator: Warning detection and quality gate enforcement

- **Quality Assurance Specialists (5)**:
  - Test Executor: ExUnit test execution and result collection
  - Coverage Analyzer: Code coverage measurement and gap detection
  - Validation Specialist: FPPS 5-method validation coordination
  - Compliance Checker: STAMP constraint verification
  - Performance Monitor: Benchmark execution and regression detection

- **Performance Monitors (5)**:
  - Resource Optimizer: CPU/Memory utilization optimization
  - Bottleneck Detector: Performance bottleneck identification
  - Scalability Analyst: Load testing and scalability validation
  - Efficiency Tracker: System efficiency metrics collection
  - Predictive Analyst: Performance trend prediction and alerting

**Layer 4: Workers (24 Agents)**
- **File Processors (8)**: Compilation, Fixes, Formatting, Refactoring
- **Pattern Recognizers (8)**: EP001-EP999 detection, Error classification, Warning categorization
- **Continuous Validators (8)**: Quality Gates, Health Checks, Compliance Verification

**Multi-Agent Coordination Commands**:
```bash
# 11-Agent Configuration (CERTIFIED)
mix claude compilation --compile --strategy smart --supervisor 1 --helpers 4 --workers 6 --dynamic-tokens

# Full 50-Agent deployment
elixir scripts/coordination/multi_agent_coordinator.exs --deploy

# Agent status monitoring
elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status

# Agent coordination efficiency check
elixir scripts/coordination/agent_efficiency_monitor.exs --report
```

**Agent Coordination Rules (MANDATORY)**:
1. Domain-Based Distribution: Agents assigned to specific Ash domains to prevent conflicts
2. File-Level Locking: ETS-based coordination with 30-second timeouts and force release
3. Priority-Based Scheduling: CRITICAL > HIGH > MEDIUM > LOW work queue management
4. Verbose Execution Mode: ALL agents MUST run with detailed planning and decision logging
5. Container-Only Execution: ALL agent work MUST occur within Podman containers with PHICS

---

### 2.2 Service Port Registry ($P_{svc}$) - 3-Container Model

**Application Container (indrajaal-app):**
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Phoenix | 4000 | HTTP/WS | Main application |
| Health Check | 4001 | HTTP | Container health |

**Database Container (indrajaal-db):**
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| PostgreSQL | 5433 | TCP | PostgreSQL 17 + TimescaleDB |

**Observability Container (indrajaal-obs):**
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| ClickHouse HTTP | 8123 | HTTP | Log/trace storage |
| ClickHouse Native | 9000 | TCP | Native protocol |
| OTEL Collector gRPC | 4317 | gRPC | Telemetry collection |
| OTEL Collector HTTP | 4318 | HTTP | Telemetry (HTTP) |
| Grafana | 3001 | HTTP | Dashboards |
| Prometheus | 9090 | HTTP | Metrics |
| Nginx | 80, 443 | HTTP/HTTPS | Reverse proxy |

**Start Containers:**
```bash
podman-compose -f podman-compose.yml up -d
```

### 2.4 Distributed Systems Specifications

**FLAME Architecture (Hybrid Core-Satellite)**:
- **Core Control Plane**: 3+ nodes (HA) running persistent services (Web, API, DB connections).
- **Satellite Runners**: Ephemeral nodes spawned on-demand for heavy computation (AI/ML, Video Processing).
- **Scaling**: 0 to $\infty$ elasticity for satellites; fixed HA for core.
- **Safety**: State MUST be fetched from DB/Cache on runner start (no local state reliance).

**Clustering (HA Mesh)**:
- **Topology**: Static HA Mesh via Tailscale/WireGuard or Kubernetes DNS.
- **Minimum Nodes**: 3 for quorum safety.
- **Discovery**: `libcluster` with `Cluster.Strategy.Kubernetes.DNS`.
- **Safety**: Quorum required for write operations; Split-brain prevention active.

---

### 2.3 Infrastructure Specifications

**Hardware Requirements**:
- **CPU**: 20 cores minimum (for 3-container model)
- **RAM**: 56GB minimum (for 3-container model)
- **Storage**: 100GB SSD (NVMe recommended)
- **Network**: 1Gbps minimum for container communication

**Software Stack**:
- **OS**: NixOS 25.05 (mandatory)
- **Container Runtime**: Podman 5.4.1+ (rootless)
- **Language**: Elixir 1.19+ / Erlang/OTP 27+
- **Database**: PostgreSQL 17+ with TimescaleDB
- **Cache**: Cachex (in-app Elixir caching)

---

## 3.0 AEE SOPv5.11 Operating Model (MANDATORY)

### 3.1 Autonomous Execution Engine Declaration
When operating in AEE mode, Claude MUST state:
**"Operating in AEE SOPv5.11 mode with Patient Mode compilation and FPPS validation"**

### 3.2 AEE Mode Requirements
1. **Patient Mode Compilation**: All compilation uses NO_TIMEOUT=true INFINITE_PATIENCE=true
2. **FPPS Validation**: 5-method consensus validation for all compilation results
3. **Container Enforcement**: All operations within Podman containers
4. **Agent Coordination**: 50-agent hierarchy for complex tasks
5. **PHICS Integration**: <50ms hot-reloading synchronization

### 3.3 Claude AI Development Workflow (AEE)
```bash
# 0. MANDATORY: Check container status first
elixir scripts/performance/podman_direct_manager.exs --status --claude-mode

# 1. Setup environment (PostgreSQL 17+ on port 5433, NixOS 25.05)
devenv shell

# 2. PHICS: Setup container-based development environment
elixir scripts/pcis/containers/setup_phoenix_container.exs --enable-phics --claude-integration

# 3. Complete project setup (AUTOMATIC container enforcement)
mix setup

# 4. MANDATORY: PHICS validation before development
elixir scripts/pcis/validation_cli.exs --phics-compliance --claude-mode

# 5. AUTOMATIC: Claude-controlled compilation (auto-container execution)
mix claude compilation --compile --strategy smart --structured-output --json

# 6. AUTOMATIC: Claude AI parallel domain compilation (auto-container)
mix claude compilation --compile --parallel-domains --strategy smart --domains 4

# 7. AUTOMATIC: PHICS-enabled server start
mix phx.server

# 8. AUTOMATIC: Claude-enhanced testing
mix test --coverage --parallel-domains

# 9. AUTOMATIC: Claude system health check
mix claude compilation --status --domain-analytics
```

### 3.4 AEE Execution Strategies

**Strategy Selection Matrix**:
| Strategy | Use Case | Duration | Parallelization |
|----------|----------|----------|-----------------|
| `smart` | Default intelligent | 5-10 min | Adaptive |
| `fast` | Development iteration | 2-5 min | Maximum |
| `patient` | Comprehensive validation | 10-20 min | Moderate |
| `ultra_fast` | Quick checks | 1-3 min | Maximum |
| `selective` | Domain-specific | Variable | Targeted |

```bash
# Strategy-based compilation
mix claude compilation --compile --strategy smart           # AI-driven selection
mix claude compilation --compile --strategy fast            # Development speed
mix claude compilation --compile --strategy patient         # Full validation
mix claude compilation --compile --strategy ultra_fast      # Maximum speed
mix claude compilation --compile --strategy selective --domain access_control
```

---

## 4.0 SOPv5.11 7-Phase Deployment System (MANDATORY SEQUENCE)

### Phase 1: Environment Infrastructure Setup
**Script**: `scripts/sopv511/phase_1_environment_setup.exs`
- PostgreSQL 17 database configuration with Nix fallback detection
- DevEnv environment validation with comprehensive dependency checking
- Network and SSL certificate validation
- Foundation infrastructure with systematic validation

**Phase 1 Validation Commands**:
```bash
elixir scripts/sopv511/phase_1_environment_setup.exs --validate
elixir scripts/sopv511/phase_1_environment_setup.exs --fix
elixir scripts/sopv511/phase_1_environment_setup.exs --report
```

### Phase 2: Container Infrastructure Deployment
**Script**: `scripts/sopv511/phase_2_container_deployment.exs`
- 3-container architecture with localhost-only registry enforcement
- Container orchestration with health monitoring and automatic recovery
- Resource allocation optimization (20 CPU cores, 56GB memory)
- Container networking with security isolation

**Phase 2 Validation Commands**:
```bash
elixir scripts/sopv511/phase_2_container_deployment.exs --validate
elixir scripts/sopv511/phase_2_container_deployment.exs --deploy
elixir scripts/sopv511/phase_2_container_deployment.exs --health-check
```

### Phase 3: 50-Agent Architecture Deployment
**Script**: `scripts/sopv511/phase_3_agent_architecture.exs`
- Hierarchical agent coordination with cybernetic feedback loops
- Executive Director (1) + Domain Supervisors (10) + Functional Supervisors (15) + Workers (24)
- Agent communication protocols with deadlock prevention
- Load balancing and task distribution optimization

**Phase 3 Validation Commands**:
```bash
elixir scripts/sopv511/phase_3_agent_architecture.exs --validate
elixir scripts/sopv511/phase_3_agent_architecture.exs --deploy-agents
elixir scripts/sopv511/phase_3_agent_architecture.exs --coordination-test
```

### Phase 4: PHICS Hot-Reloading Integration
**Script**: `scripts/sopv511/phase_4_phics_integration.exs`
- Bidirectional file synchronization with <50ms latency
- Container-host development workflow integration
- Real-time code reloading with data integrity preservation
- Development velocity optimization with enterprise reliability

**Phase 4 Validation Commands**:
```bash
elixir scripts/sopv511/phase_4_phics_integration.exs --validate
elixir scripts/sopv511/phase_4_phics_integration.exs --enable-sync
elixir scripts/sopv511/phase_4_phics_integration.exs --latency-test
```

### Phase 5: Compilation Environment Setup
**Script**: `scripts/sopv511/phase_5_compilation_environment.exs`
- Patient Mode compilation with NO_TIMEOUT=true INFINITE_PATIENCE=true
- Multi-method compilation validation with false positive prevention
- Parallel compilation optimization with 16-core utilization
- Zero-warning compilation with systematic error resolution

**Phase 5 Validation Commands**:
```bash
elixir scripts/sopv511/phase_5_compilation_environment.exs --validate
elixir scripts/sopv511/phase_5_compilation_environment.exs --patient-compile
elixir scripts/sopv511/phase_5_compilation_environment.exs --fpps-validate
```

### Phase 6: Monitoring and Observability
**Script**: `scripts/sopv511/phase_6_monitoring_observability.exs`
- Real-time system monitoring with predictive analytics
- Performance baseline establishment with continuous tracking
- Health monitoring with automatic alerting and recovery
- Business metrics tracking with ROI validation

**Phase 6 Validation Commands**:
```bash
elixir scripts/sopv511/phase_6_monitoring_observability.exs --validate
elixir scripts/sopv511/phase_6_monitoring_observability.exs --setup-dashboards
elixir scripts/sopv511/phase_6_monitoring_observability.exs --baseline
```

### Phase 7: Security and Compliance
**Script**: `scripts/sopv511/phase_7_security_compliance.exs`
- Enterprise-grade security framework with multi-level clearance
- Regulatory compliance (ISO 27001, SOX 404, GDPR, HIPAA, PCI DSS)
- Container security with rootless execution and comprehensive isolation
- Audit and logging system with comprehensive coverage

**Phase 7 Validation Commands**:
```bash
elixir scripts/sopv511/phase_7_security_compliance.exs --validate
elixir scripts/sopv511/phase_7_security_compliance.exs --security-scan
elixir scripts/sopv511/phase_7_security_compliance.exs --compliance-report
```

**Complete 7-Phase Deployment Workflow**:
```bash
# Environment validation and setup
elixir scripts/setup/consolidated_sopv511_environment_setup.exs --validate

# Sequential 7-phase deployment validation
for phase in 1 2 3 4 5 6 7; do
  elixir scripts/sopv511/phase_${phase}_*.exs --validate
done

# Or use consolidated deployment
elixir scripts/sopv511/consolidated_deployment.exs --all-phases --validate
```

---

## 5.0 Temporal Logic Specifications (LTL)

We define system behavior using Linear Temporal Logic operators: $\Box$ (Globally/Always), $\diamond$ (Eventually), $\bigcirc$ (Next).

### 5.1 Safety Properties (Bad things never happen)
- **LTL-1 (Timeout Safety)**: $\Box \neg (\text{CompilationRunning} \wedge \text{TimeoutTriggered})$
- **LTL-2 (Validation Safety)**: $\Box (\text{SuccessClaim} \implies \text{PrecededBy}(\text{ConsensusCheck}))$
- **LTL-3 (Container Safety)**: $\Box \neg (\text{Execution} \wedge \neg \text{Podman})$
- **LTL-4 (Timestamp Safety)**: $\Box \forall \tau : \text{TimeZone}(\tau) \neq \text{UTC}$
- **LTL-5 (Registry Safety)**: $\Box \neg (\text{ImagePull} \wedge \neg \text{LocalhostRegistry})$
- **LTL-6 (Agent Safety)**: $\Box \neg (\text{AgentExecution} \wedge \neg \text{SupervisorApproval})$

### 5.2 Liveness Properties (Good things eventually happen)
- **LTL-7 (Analysis Liveness)**: $\Box (\text{CompilationStart} \implies \diamond \text{LogAnalysis})$
- **LTL-8 (Fix Liveness)**: $\Box (\text{ErrorDetected} \implies \diamond (\text{TPSRootCauseAnalysis} \wedge \text{FixApplied}))$
- **LTL-9 (Recovery Liveness)**: $\Box (\text{FailureDetected} \implies \diamond \text{AutomaticRecovery})$
- **LTL-10 (Validation Liveness)**: $\Box (\text{CodeChange} \implies \diamond \text{FPPSValidation})$

### 5.3 Fairness Properties
- **LTL-11 (Agent Fairness)**: $\Box \diamond (\text{AgentScheduled} \implies \text{AgentExecuted})$
- **LTL-12 (Container Fairness)**: $\Box \diamond (\text{ContainerReady} \implies \text{TaskAssigned})$

---

## 6.0 STAMP 72 Safety Constraints (Complete Coverage)

### Category A: Validation Process Safety (SC-VAL-001 to SC-VAL-008)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-VAL-001 | System SHALL use ONLY Patient Mode compilation | Check for NO_TIMEOUT=true |
| SC-VAL-002 | System SHALL analyze complete compilation logs, never partial | Verify no head/tail usage |
| SC-VAL-003 | System SHALL achieve 100% consensus across all validation methods | FPPS 5-method agreement |
| SC-VAL-004 | System SHALL halt immediately on validation method disagreements | Emergency protocol trigger |
| SC-VAL-005 | System SHALL maintain complete audit trail | ./data/tmp logs exist |
| SC-VAL-006 | System SHALL prevent selective compilation validation (EP-110) | Full compilation required |
| SC-VAL-007 | System SHALL detect and prevent validation process drift (EP-111) | Continuous monitoring |
| SC-VAL-008 | System SHALL integrate with SOPv5.11 cybernetic framework | Framework validation |

### Category B: Container Safety (SC-CNT-009 to SC-CNT-016)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-CNT-009 | System SHALL execute ALL operations within NixOS containers | Container environment check |
| SC-CNT-010 | System SHALL use ONLY localhost/ registry | Image source validation |
| SC-CNT-011 | System SHALL maintain PHICS v2.1 <50ms synchronization | Latency monitoring |
| SC-CNT-012 | System SHALL enforce rootless container execution | Privilege check |
| SC-CNT-013 | System SHALL validate container health before operations | Health check |
| SC-CNT-014 | System SHALL maintain container resource isolation | Resource limits |
| SC-CNT-015 | System SHALL ensure container networking security | Network isolation |
| SC-CNT-016 | System SHALL prevent container registry drift | Registry monitoring |

### Category C: Agent Coordination Safety (SC-AGT-017 to SC-AGT-024)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-AGT-017 | System SHALL maintain 50-agent architecture at >90% efficiency | Efficiency monitoring |
| SC-AGT-018 | System SHALL prevent agent coordination deadlocks | Deadlock detection |
| SC-AGT-019 | System SHALL ensure Executive Director supreme authority | Authority validation |
| SC-AGT-020 | System SHALL maintain Domain Supervisor specialization | Boundary enforcement |
| SC-AGT-021 | System SHALL prevent agent task queue overflow | Queue monitoring |
| SC-AGT-022 | System SHALL ensure agent communication integrity | Message validation |
| SC-AGT-023 | System SHALL provide agent failure detection and recovery | Health monitoring |
| SC-AGT-024 | System SHALL maintain agent load balancing | Load distribution |

### Category D: Compilation Safety (SC-CMP-025 to SC-CMP-035)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-CMP-025 | System SHALL prevent compilation with ANY warnings | --warnings-as-errors |
| SC-CMP-026 | System SHALL ensure complete file compilation (773 files) | File count verification |
| SC-CMP-027 | System SHALL maintain compilation determinism | Reproducibility check |
| SC-CMP-028 | System SHALL prevent compilation interruption | Process monitoring |
| SC-CMP-029 | System SHALL validate syntax correctness | Pre-compilation check |
| SC-CMP-030 | System SHALL ensure dependency resolution | Dependency validation |
| SC-CMP-031 | System SHALL prevent compilation environment drift | Environment check |
| SC-CMP-032 | System SHALL maintain compilation performance baselines | Performance monitoring |
| SC-CMP-033 | System SHALL use `--jobs <N>` for parallel compilation (Elixir 1.19+) | Check compile command |
| SC-CMP-034 | System SHALL set `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` for deps parallelization | Environment check |
| SC-CMP-035 | System SHALL configure BEAM schedulers via `ELIXIR_ERL_OPTIONS` | Environment check |

### Category E: Data Integrity Safety (SC-DAT-033 to SC-DAT-040)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-DAT-033 | System SHALL prevent data corruption | Integrity validation |
| SC-DAT-034 | System SHALL ensure audit log integrity | Tamper detection |
| SC-DAT-035 | System SHALL maintain validation result consistency | Result verification |
| SC-DAT-036 | System SHALL prevent log file truncation | Log monitoring |
| SC-DAT-037 | System SHALL ensure backup creation and recovery | Backup validation |
| SC-DAT-038 | System SHALL validate data checksums | Checksum verification |
| SC-DAT-039 | System SHALL prevent concurrent access conflicts | Race condition prevention |
| SC-DAT-040 | System SHALL maintain data versioning | Version tracking |

### Category F: Security Safety (SC-SEC-041 to SC-SEC-048)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-SEC-041 | System SHALL prevent unauthorized access | Access control |
| SC-SEC-042 | System SHALL ensure secure credential management | Credential validation |
| SC-SEC-043 | System SHALL maintain network security | Network isolation |
| SC-SEC-044 | System SHALL validate code security (Sobelow) | Security scanning |
| SC-SEC-045 | System SHALL ensure audit trail security | Access control |
| SC-SEC-046 | System SHALL prevent privilege escalation | Privilege monitoring |
| SC-SEC-047 | System SHALL maintain encryption | Encryption validation |
| SC-SEC-048 | System SHALL ensure vulnerability scanning | Security validation |

### Category G: Performance Safety (SC-PRF-049 to SC-PRF-056)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-PRF-049 | System SHALL prevent resource exhaustion | Resource monitoring |
| SC-PRF-050 | System SHALL maintain response time SLAs (<50ms) | Latency monitoring |
| SC-PRF-051 | System SHALL prevent CPU overutilization | CPU monitoring |
| SC-PRF-052 | System SHALL ensure disk space availability | Storage monitoring |
| SC-PRF-053 | System SHALL prevent network congestion | Network monitoring |
| SC-PRF-054 | System SHALL maintain database connection pooling | Pool monitoring |
| SC-PRF-055 | System SHALL prevent blocking operations | Async validation |
| SC-PRF-056 | System SHALL ensure scalability limits | Scaling validation |

### Category H: Emergency Response Safety (SC-EMR-057 to SC-EMR-064)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-EMR-057 | System SHALL provide emergency stop <5 seconds | Response time check |
| SC-EMR-058 | System SHALL ensure automatic failure detection | Detection validation |
| SC-EMR-059 | System SHALL maintain emergency communication | Alert validation |
| SC-EMR-060 | System SHALL provide rollback capabilities | Rollback testing |
| SC-EMR-061 | System SHALL ensure incident logging | Log validation |
| SC-EMR-062 | System SHALL maintain backup systems | Failover testing |
| SC-EMR-063 | System SHALL provide manual override | Override validation |
| SC-EMR-064 | System SHALL ensure business continuity | DR testing |

### Category I: Observability Safety (SC-OBS-065 to SC-OBS-072)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-OBS-065 | System SHALL have logging enabled for ALL key operations | Log coverage check |
| SC-OBS-066 | System SHALL validate OpenTelemetry at startup | Instrumentation check |
| SC-OBS-067 | System SHALL verify observability pipeline (every 5 min) | Health check |
| SC-OBS-068 | System SHALL alert when observability fails | Alert validation |
| SC-OBS-069 | System SHALL maintain dual logging (Terminal + SigNoz) | Backend validation |
| SC-OBS-070 | System SHALL ensure trace context injection | Trace validation |
| SC-OBS-071 | System SHALL validate 4 OTEL modules loaded | Module check |
| SC-OBS-072 | System SHALL emit telemetry for health checks | Event validation |

### Category J: Agent Code Safety (SC-AGT-025 to SC-AGT-030)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-AGT-025 | Agent SHALL run `mix compile` before marking code generation task complete | Pre-delivery compilation gate |
| SC-AGT-026 | Agent SHALL verify exactly 0 errors before code delivery | Zero-error delivery check |
| SC-AGT-027 | Agent SHALL check BaseResource for existing `code_interface` definitions | Interface inheritance analysis |
| SC-AGT-028 | Agent SHALL validate all Ash DSL syntax patterns match Ash 3.x specs | DSL pattern validation |
| SC-AGT-029 | Agent SHALL detect and prevent non-Elixir syntax patterns | Syntax scanner (return, \|\|\|, etc.) |
| SC-AGT-030 | Agent SHALL auto-trigger Jidoka (stop-and-fix) on compilation failure | Automatic error recovery |

### Category W: Operational Safety (SC-OPS-001 to SC-OPS-004)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-OPS-001 | System SHALL NOT start if required dependencies (elixir, epmd) are missing | Preflight check in script |
| SC-OPS-002 | System SHALL NOT attempt to bind to ports already in use | Port availability check |
| SC-OPS-003 | System SHALL detect process death during startup phase | PID monitoring loop |
| SC-OPS-004 | System SHALL ensure graceful termination of all child processes on exit | Trap signal handling |

### Category X: Network & Observability Safety (SC-NET, SC-OBS)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-NET-001 | Node names SHALL resolve resolvable DNS names or IP addresses | Dynamic detection logic |
| SC-OBS-001 | Startup logs SHALL be persisted to file, not just console | Redirection to log files |

**Agent Code Validation Command**:
```bash
# Validate agent-generated code before delivery
elixir scripts/validation/agent_code_validator.exs --resource path/to/resource.ex
elixir scripts/validation/agent_code_validator.exs --directory lib/indrajaal/integration/
elixir scripts/validation/agent_code_validator.exs --compile-check
```

**EP-AGT Error Patterns Checked**:
- EP-AGT-001: Duplicate code_interface definitions (BaseResource conflict)
- EP-AGT-002: Wrong accept vs argument usage in actions
- EP-AGT-003: Invalid constraint syntax (one_of: for string type)
- EP-AGT-004: Non-Elixir syntax (return, ||| operator)
- EP-AGT-005: Wrong default: syntax in Ash DSL
- EP-AGT-006: Unused variables (warning pattern)
- EP-AGT-007: Missing require_atomic? false for function-based changes
- EP-AGT-008: Missing domain registration for new resources
- EP-AGT-009: Guardian API mismatch (peek/2 return type)
- EP-AGT-010: RateLimiter response pattern mismatch
- EP-AGT-011: Wrong try/rescue/catch ordering
- EP-AGT-012: Missing macro require (Cachex.Spec)
- EP-AGT-013: Enum.map_join argument order (joiner must be second, mapper third)

### Category K: PropCheck Generator Safety (SC-PROP-021 to SC-PROP-025)
| ID | Constraint | Verification | Severity |
|----|-----------|--------------|----------|
| SC-PROP-021 | System SHALL NOT use raw utf8() generator without constraints | Check for `forall x <- utf8()` patterns | CRITICAL |
| SC-PROP-022 | System SHALL use let/vector/range pattern for safe string generation | Check for `let chars <- vector(N, range(...))` | HIGH |
| SC-PROP-023 | System SHALL NOT use such_that with strict constraints on unbounded generators | Check for `such_that(utf8(), ...)` patterns | CRITICAL |
| SC-PROP-024 | System SHALL define helper functions for complex PropCheck generators | Check for `defp valid_*_generator` pattern | MEDIUM |
| SC-PROP-025 | System SHALL use correct PropCheck syntax (such_that with when:) | Check for `such_that(x <- gen, when: guard)` | HIGH |

**PropCheck Generator RCA Reference (2025-12-10)**:
- **INCIDENT**: OAuthProvider/WebhookEndpoint PropCheck tests failed with `cant_generate`
- **ROOT CAUSE**: Raw `utf8()` generates arbitrary Unicode; `such_that` filtering fails
- **SOLUTION**: Use `let chars <- vector(20, range(?a, ?z)) do List.to_string(chars) end`

**Safe PropCheck String Generator Template**:
```elixir
defp valid_string_generator do
  let chars <- vector(20, range(?a, ?z)) do
    List.to_string(chars)
  end
end

defp valid_url_generator do
  let {protocol, domain} <- {
        oneof(["http://", "https://"]),
        vector(10, range(?a, ?z))
      } do
    protocol <> List.to_string(domain) <> ".com/webhook"
  end
end
```

### Category L: Ash Changeset Pattern Safety (SC-ASH-001 to SC-ASH-010)
| ID | Constraint | Verification | Severity |
|----|-----------|--------------|----------|
| SC-ASH-001 | System SHALL use force_change_attribute in before_action hooks | Check before_action blocks for change_attribute | CRITICAL |
| SC-ASH-002 | System SHALL use change_attribute in change blocks (pre-validation) | Verify change blocks use correct function | MEDIUM |
| SC-ASH-003 | System SHALL use after_action for side effects | Check side effects not in before_action | HIGH |
| SC-ASH-004 | System SHALL include require_atomic? false for function-based changes | Check update actions with fn changes | CRITICAL |
| SC-ASH-005 | System SHALL NOT duplicate code_interface definitions from BaseResource | Check for duplicate :list/:get defines | HIGH |
| SC-ASH-006 | System SHALL define custom actions only in resource code_interface | Verify no standard actions redefined | MEDIUM |
| SC-ASH-007 | System SHALL register new resources in their Ash domain | Check domain resources block | CRITICAL |
| SC-ASH-008 | System SHALL accept opts parameter in plain functions calling Ash APIs | Check function signatures for opts \\\\ [] | HIGH |
| SC-ASH-009 | System SHALL pass opts to all internal Ash API calls | Verify opts forwarded to Ash.get/create/etc | HIGH |
| SC-ASH-010 | System SHALL use authorize?: false in test helpers | Check test helper functions | MEDIUM |

**Ash Changeset RCA Reference (2025-12-10)**:
- **INCIDENT**: SyncJob `create` action failed, WebhookEndpoint `verify_signature` tests failed
- **ROOT CAUSE 1**: `change_attribute` in `before_action` triggers re-validation after validation passed
- **ROOT CAUSE 2**: Plain functions calling `Ash.get` without opts lose authorization context
- **SOLUTION 1**: Use `force_change_attribute` in `before_action` hooks
- **SOLUTION 2**: Add `opts \\ []` parameter and forward to Ash API calls

**Ash Changeset Hook Pattern**:
```elixir
# WRONG: change_attribute in before_action
before_action fn changeset ->
  Ash.Changeset.change_attribute(changeset, :field, value)  # VIOLATION
end

# CORRECT: force_change_attribute in before_action
before_action fn changeset ->
  Ash.Changeset.force_change_attribute(changeset, :field, value)  # Safe
end
```

**Ash Plain Function Authorization Pattern**:
```elixir
# WRONG: No opts parameter
def verify_signature(webhook_id, payload, signature) do
  case Ash.get(WebhookEndpoint, webhook_id) do  # May fail with Forbidden
    {:ok, webhook} -> ...
  end
end

# CORRECT: With opts parameter
def verify_signature(webhook_id, payload, signature, opts \\ []) do
  case Ash.get(WebhookEndpoint, webhook_id, opts) do  # Passes authorization opts
    {:ok, webhook} -> ...
  end
end
```

---

## 7.0 FPPS 5-Method Validation System (Complete Implementation)

### 7.1 Pattern Method (OPERATIONAL)
- **Integration**: Uses comprehensive_compilation_validator.exs
- **Coverage**: 80+ error patterns (EP-001 to EP-080)
- **Capability**: Standard compilation error and warning pattern recognition
```elixir
@error_patterns [
  "error:", "** (", "undefined variable", "undefined function",
  "CompileError", "cannot compile module", "== Compilation error",
  "syntax error", "** (ArgumentError)", "** (RuntimeError)",
  "type specification", "dialyzer", "no such file", "failed", "Error"
]

@warning_patterns [
  "warning:", "deprecated", "unused", "shadowed", "unreachable",
  "match_type", "missing_clause", "overlapping_patterns"
]
```

### 7.2 AST Method (FULLY IMPLEMENTED)
- **Implementation**: Full AST-based structural analysis with regex patterns
- **Error Patterns**: 10 AST error patterns (SyntaxError, CompileError, undefined function/variable)
- **Warning Patterns**: 6 AST warning patterns (structural inconsistencies)

```elixir
defmodule ASTValidator do
  def validate(source) do
    case Code.string_to_quoted(source) do
      {:ok, ast} -> analyze_ast(ast)
      {:error, {line, message, token}} -> {:error, line, message, token}
    end
  end

  defp analyze_ast(ast) do
    ast
    |> Macro.prewalk([], &collect_issues/2)
    |> categorize_issues()
  end
end
```

### 7.3 Statistical Method (FULLY IMPLEMENTED)
- **Implementation**: Weighted keyword scoring with context analysis and anomaly detection
- **Error Keywords**: 8 error keywords with contextual weighting (exception lines weight 3x)
- **Warning Keywords**: 6 warning keywords with intelligent scoring

```elixir
defmodule StatisticalValidator do
  @error_weights %{
    "error:" => 1.0,
    "** (" => 1.5,
    "CompileError" => 2.0,
    "undefined" => 0.8,
    "failed" => 0.6
  }

  def validate(log_content) do
    lines = String.split(log_content, "\n")

    error_score = calculate_weighted_score(lines, @error_weights)
    warning_score = calculate_weighted_score(lines, @warning_weights)

    %{
      error_count: round(error_score),
      warning_count: round(warning_score),
      confidence: calculate_confidence(lines)
    }
  end
end
```

### 7.4 Binary Method (FULLY IMPLEMENTED)
- **Implementation**: Binary pattern scanning with byte-level analysis
- **Error Patterns**: 8 error byte patterns for low-level issue detection
- **Warning Patterns**: 5 warning byte patterns for hidden issues

```elixir
defmodule BinaryValidator do
  @error_bytes [
    <<101, 114, 114, 111, 114, 58>>,  # "error:"
    <<42, 42, 32, 40>>,                # "** ("
    <<67, 111, 109, 112, 105, 108, 101, 69, 114, 114, 111, 114>>  # "CompileError"
  ]

  def validate(binary_content) do
    error_count = count_byte_patterns(binary_content, @error_bytes)
    warning_count = count_byte_patterns(binary_content, @warning_bytes)

    %{errors: error_count, warnings: warning_count}
  end
end
```

### 7.5 Line-by-Line Method (ENHANCED)
- **Implementation**: Context-aware line analysis with multi-line error handling
- **Integration**: Complete log file processing after compilation completion
- **Features**: Multi-line error pattern recognition, contextual validation

```elixir
defmodule LineByLineValidator do
  def validate(log_content) do
    log_content
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(%{errors: 0, warnings: 0, context: []}, fn {line, idx}, acc ->
      analyze_line_with_context(line, idx, acc)
    end)
  end

  defp analyze_line_with_context(line, idx, acc) do
    cond do
      is_error_line?(line) -> %{acc | errors: acc.errors + 1}
      is_warning_line?(line) -> %{acc | warnings: acc.warnings + 1}
      is_continuation?(line, acc.context) -> update_continuation(acc)
      true -> acc
    end
  end
end
```

**CONSENSUS REQUIREMENT**: ALL 5 methods MUST agree on error/warning counts or validation HALTS immediately.

```elixir
def check_consensus(results) do
  error_counts = Enum.map(results, & &1.error_count) |> Enum.uniq()
  warning_counts = Enum.map(results, & &1.warning_count) |> Enum.uniq()

  if length(error_counts) == 1 and length(warning_counts) == 1 do
    {:ok, %{errors: hd(error_counts), warnings: hd(warning_counts)}}
  else
    {:error, :consensus_failure, %{
      error_variance: error_counts,
      warning_variance: warning_counts,
      action: :halt_and_investigate
    }}
  end
end
```

---

## 8.0 PHICS v2.1 Integration (Phoenix Hot-Reloading Integration Container System)

### 8.1 PHICS Requirements
- **Latency**: <50ms synchronization between host and container
- **Bidirectional Sync**: File changes propagate both directions
- **Hot Reload**: Code changes trigger automatic recompilation
- **Data Integrity**: No data loss during sync operations

### 8.2 PHICS Environment Variables (MANDATORY)
```bash
export PHICS_ENABLED=true
export PHICS_WATCH_ENABLED=true
export PHICS_CONTAINER_MODE=development
export PHICS_HOT_RELOAD=enabled
export PHICS_SYNC_LATENCY_TARGET=50
export PHICS_BIDIRECTIONAL=true
```

### 8.3 PHICS Commands
```bash
# PHICS validation
elixir scripts/pcis/validation_cli.exs --phics-compliance

# PHICS setup
elixir scripts/pcis/containers/setup_phoenix_container.exs --enable-phics

# PHICS hot-reloading verification
elixir scripts/containers/verified_nixos_setup.exs --phics-validation

# PHICS latency monitoring
elixir scripts/pcis/phics_latency_monitor.exs --continuous
```

### 8.4 PHICS Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PHICS v2.1 Architecture                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    <50ms sync    ┌──────────────────┐    │
│  │  Host Files  │ ◄──────────────► │ Container Files  │    │
│  │   (Source)   │                  │   (Runtime)      │    │
│  └──────────────┘                  └──────────────────┘    │
│         │                                   │               │
│         ▼                                   ▼               │
│  ┌──────────────┐                  ┌──────────────────┐    │
│  │ File Watcher │                  │  Phoenix Server  │    │
│  │   (inotify)  │                  │  (Hot Reload)    │    │
│  └──────────────┘                  └──────────────────┘    │
│         │                                   │               │
│         └───────────► Sync Engine ◄─────────┘               │
│                            │                                │
│                    ┌───────▼───────┐                       │
│                    │ LiveReloader  │                       │
│                    │  WebSocket    │                       │
│                    └───────────────┘                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 8.5 PHICS Development Workflow

```bash
# 1. Setup PHICS-enabled development environment
elixir scripts/pcis/containers/setup_phoenix_container.exs --enable-phics

# 2. Start container with hot-reloading
podman run -d --name indrajaal-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 -p 4001:4001 \
  -e PHICS_ENABLED=true \
  localhost/indrajaal:latest \
  iex -S mix phx.server

# 3. Validate PHICS integration
elixir scripts/pcis/validation_cli.exs --phics-compliance

# 4. Development with seamless hot-reloading
# Edit files on host → Automatic reload in container
# LiveView updates, template changes, code recompilation
```

**PHICS Success Metrics**:
- **90% Reduced Container Friction**: Seamless development experience
- **100% Hot-Reloading Coverage**: All Phoenix components support live updates
- **Zero Manual Intervention**: Automatic sync and reload capabilities
- **Enterprise-Grade Reliability**: Production-ready container development

---

## 9.0 Ultra-Robust Automated Incremental Compilation Protocol

### Step 0: Automated Prerequisite Validation
```bash
elixir scripts/validation/incremental_fix_prerequisite_validator.exs
```
Validates: Git clean, checkpoints valid, FPPS operational, audit logging directory exists.

### Step 1: Automated Batch Planning
```bash
elixir scripts/validation/intelligent_batch_planner.exs --file TARGET_FILE.ex
```
Outputs optimal batch plan with fix numbers in JSON format.

### Step 2: Automated Fix Application
```bash
elixir scripts/validation/automated_fix_executor.exs --batch-id 1 --plan batch_plan_TIMESTAMP.json
```
Applies fixes, validates, creates checkpoints automatically.

### Step 3: Multi-Method Consensus Validation
```bash
elixir scripts/validation/comprehensive_compilation_validator.exs \
  --log ./data/tmp/incremental_fix_batch_1_compile.log \
  --require-consensus \
  --save-report ./data/tmp/fpps_batch_1_report.json
```

### Step 4: Automated Git Checkpoint
```bash
elixir scripts/validation/automated_checkpoint_creator.exs \
  --batch-id 1 \
  --fixes-applied "[60,61,62,63,64]" \
  --errors-before 22 \
  --errors-after 17
```

### Step 5: Real-Time Progress Dashboard
```bash
elixir scripts/validation/incremental_fix_progress_dashboard.exs --watch
```

### Step 6: Automated Pattern Recognition
```bash
elixir scripts/analysis/comprehensive_error_pattern_database.exs \
  --analyze ./data/tmp/incremental_fix_batch_1_compile.log \
  --update-database
```

### Step 7: Automated Rollback on Failure
```bash
elixir scripts/validation/emergency_rollback_system.exs \
  --trigger "FPPS consensus failed" \
  --last-good-checkpoint fix-batch-60-67
```

### Step 8: Final Comprehensive Verification
```bash
elixir scripts/validation/final_comprehensive_validator.exs
```

---

## 10.0 Comprehensive Podman Command Reference

### 10.1 Container Lifecycle Commands
```bash
# Container creation and management
podman run -d --name app localhost/indrajaal:latest    # Start container
podman start app                                        # Start stopped container
podman stop app                                         # Stop running container
podman restart app                                      # Restart container
podman rm app                                           # Remove container
podman rm -f app                                        # Force remove

# Container execution
podman exec -it app /bin/bash                          # Interactive shell
podman exec app mix compile                            # Run command
podman exec -e VAR=value app command                   # With environment
```

### 10.2 Image Management Commands
```bash
# Image operations
podman images                                          # List local images
podman pull localhost/indrajaal:latest                # Pull from registry
podman build -t localhost/myapp:latest .              # Build image
podman rmi localhost/myapp:latest                     # Remove image
podman tag localhost/myapp:latest localhost/myapp:v1  # Tag image
podman save -o backup.tar localhost/myapp:latest     # Export image
podman load -i backup.tar                             # Import image
```

### 10.3 Container Information Commands
```bash
# Container inspection
podman ps -a                                           # List all containers
podman inspect app                                     # Detailed info
podman logs app                                        # View logs
podman logs -f app                                     # Follow logs
podman stats app                                       # Resource usage
podman port app                                        # Port mappings
podman top app                                         # Running processes
```

### 10.4 Networking Commands
```bash
# Network management
podman network ls                                      # List networks
podman network create mynetwork                       # Create network
podman network inspect mynetwork                      # Network details
podman run --network mynetwork app                    # Use network
podman network connect mynetwork app                  # Connect container
podman network disconnect mynetwork app               # Disconnect
```

### 10.5 Volume Commands
```bash
# Volume management
podman volume ls                                       # List volumes
podman volume create myvolume                         # Create volume
podman volume inspect myvolume                        # Volume details
podman run -v myvolume:/data app                      # Mount volume
podman volume rm myvolume                             # Remove volume
podman volume prune                                   # Remove unused
```

### 10.6 Podman-Compose Commands
```bash
# Orchestration (MANDATORY for multi-container)
podman-compose -f podman-compose.yml up -d            # Start services
podman-compose -f podman-compose.yml down             # Stop services
podman-compose -f podman-compose.yml logs             # View logs
podman-compose -f podman-compose.yml logs -f app      # Follow app logs
podman-compose -f podman-compose.yml build            # Build services
podman-compose -f podman-compose.yml ps               # List services
podman-compose -f podman-compose.yml restart app      # Restart service
```

### 10.7 Registry Operations
```bash
# Registry authentication and push
podman login localhost:5000                           # Login to registry
podman push localhost/myapp:latest                    # Push image
podman search postgresql                              # Search images

# APPROVED registries ONLY
localhost/                                            # Primary (REQUIRED)
registry.nixos.org/                                   # Fallback (NixOS official)
```

### 10.8 Podman Security Benefits
1. **Rootless Operation**: Containers run as unprivileged user
2. **Daemonless Architecture**: No privileged daemon process
3. **Fork/Exec Model**: Direct process execution
4. **User Namespaces**: Complete container isolation
5. **SELinux Integration**: Enhanced security labeling
6. **No Network Privilege**: CAP_NET_ADMIN not required
7. **Supply Chain Security**: Better registry validation

### 10.9 5-Level Container Environment Strategy (SC-CNT-ENV)

The system employs a formalized 5-level strategy for container environments, mapping specific operational needs to distinct orchestration artifacts.

| Level | Environment | Artifact (`podman-compose*.yml`) | Objective | Key Constraints |
|-------|-------------|----------------------------------|-----------|-----------------|
| **1** | **Development** | `podman-compose-3container.yml` | Velocity ($\delta \to 0$) | PHICS enabled (<50ms), Sidecar architecture, Tailscale DNS simulation |
| **2** | **Test** | `podman-compose-testing.yml` | Resilience ($\alpha \uparrow$) | 3-Node HA Cluster, DB Replication, In-Network Test Runner |
| **3** | **Demo** | `podman-compose.yml` (+ `.observability`) | Visibility | Full 6-service stack, Resource limits, Optional SigNoz stack |
| **4** | **Production** | `podman-compose-secure.yml` | Security | Read-only root, Cap-drop (ALL), Network isolation, Secrets via tmpfs |
| **5** | **Mesh** | `podman-compose-cluster.yml` | Distribution | Erlang Distribution over Tailscale Mesh, EPMD binding |

**Strategy Mandates (SC-CNT-ENV-001 to 005):**
*   **SC-CNT-ENV-001**: Developers SHALL use `podman-compose-3container.yml` for local iteration to utilize PHICS.
*   **SC-CNT-ENV-002**: CI/CD pipelines SHALL use `podman-compose-testing.yml` for integration tests to verify distributed state.
*   **SC-CNT-ENV-003**: Production deployments SHALL use `podman-compose-secure.yml` (or K8s equivalent) as the security baseline.
*   **SC-CNT-ENV-004**: All environments SHALL strictly adhere to the **Podman-Only** and **Localhost Registry** axioms.
*   **SC-CNT-ENV-005**: Observability stack SHALL be deployed as an add-on layer using `podman-compose.observability.yml`.

---

## 11.0 Operational Protocols (Hoare Logic)

### Protocol: 10-Step Verification Checklist
**Precondition** $P$: $\text{RepoState} = \text{Dirty} \vee \text{Unknown}$
**Command** $C$: Execute Checklist
**Postcondition** $Q$: $(\text{RepoState} = \text{CertifiedClean}) \wedge (\text{Safety} = \text{Verified})$

**Checklist**:
- [ ] 1. Clean Build State: `mix clean` executed
- [ ] 2. Complete Compilation: `mix compile --force --all-warnings` used
- [ ] 3. File Count: 773 files compiled (verified with `grep -c "Compiled lib/"`)
- [ ] 4. Error Count: 0 errors (verified with `grep -c "error:"`)
- [ ] 5. Warning Count: 0 warnings (target for safety-critical)
- [ ] 6. FPPS Validation: All 5 methods executed and consensus achieved
- [ ] 7. Log Saved: Complete log saved to `./data/tmp` with timestamp
- [ ] 8. Manual Verification: Human review of validation results
- [ ] 9. TDG Tests Pass: Validation logic tests all passing
- [ ] 10. STAMP Compliance: All 72 safety constraints verified

### Protocol: Automated Fix Cycle
**Precondition**: $\exists e \in \text{Log} : e \text{ is Error}$
**Command**: Execute fix cycle
**Postcondition**: $(\text{Log}' = \text{Log} \setminus e) \vee (\text{State} = \text{Rollback})$

```bash
# Automated fix cycle
elixir scripts/validation/incremental_fix_prerequisite_validator.exs && \
elixir scripts/validation/intelligent_batch_planner.exs && \
elixir scripts/validation/automated_fix_executor.exs && \
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus
```

### Protocol: Dual Logging
**Precondition**: Event $E$ generated
**Command**: `Logger.info(E)`
**Postcondition**: $(E \in \text{Stdout}) \wedge (E \in \text{SigNoz}) \wedge (E \in \text{File})$

---

## 12.0 Technology & File Policies

### 12.1 Protected Files Invariant
The following files are **IMMUTABLE** except via specific authorization:
- `CLAUDE.md`, `README.md`, `mix.exs`, `devenv.nix`
- `tps_*.exs` scripts (TPS validation system)
- `*.yml`, `*.yaml` (Container Configs)

**MUST backup CLAUDE.md before any changes**:
```bash
cp CLAUDE.md backups/[YYYYMMDD-HHMM]-CLAUDE.md.backup
```

### 12.2 Script Language Policy (ZERO TOLERANCE)
**PERMITTED LANGUAGES**:
- **Elixir (.exs)**: Primary language for all Indrajaal-specific scripts
- **Python (.py)**: Secondary language for data processing and external integrations
- **Rust (.rs)**: High-performance components and NIFs (via Rustler)
- **F# (.fs, .fsx)**: Infrastructure orchestration and CEPAF components
- **Dart (.dart)**: Mobile app development and distributed CLI tools

**FORBIDDEN LANGUAGES**:
- Bash/Shell scripts (.sh, .bash)
- JavaScript/Node.js (.js)
- Ruby scripts (.rb)
- Perl scripts (.pl)
- PowerShell scripts (.ps1)
- Any other scripting language

### 12.3 JSON Dependency Rule (MANDATORY)
ALL Elixir scripts that process JSON MUST use `Mix.install([{:jason, "~> 1.4"}])` at the top.

```elixir
#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

# Your script code here
case Jason.decode(json_string) do
  {:ok, data} -> process_data(data)
  {:error, _} -> handle_error()
end
```

### 12.4 Timestamp Policy
- **Reference**: `$(date)` (System Time) - Claude MUST always use this command
- **Zone**: `CEST` or `CET` (NEVER UTC)
- **Format**: `YYYY-MM-DD HH:MM:SS [Zone]`
- **Forbidden**: `UTC`, `DateTime.utc_now()`
- **Journal Format**: `YYYYMMDD-HHMM-[descriptive-name].md`

### 12.5 Directory Structure Rules
```
./data/tmp/                    # ALL Claude logs (MANDATORY)
./docs/journal/                # Development journal entries
./backups/                     # CLAUDE.md and critical file backups
./scripts/validation/          # Validation scripts
./scripts/containers/          # Container management scripts
./scripts/coordination/        # Multi-agent coordination
./scripts/analysis/            # Analysis and debugging scripts
./test/                        # Test files
./lib/                         # Source code
```

---

## 13.0 Dual Logging System (Terminal + SigNoz)

### Requirements (MANDATORY)
1. **Terminal Output**: ALL logs MUST appear in developer's terminal/console
2. **SigNoz Output**: ALL logs MUST simultaneously appear in SigNoz
3. **Identical Content**: Both destinations MUST receive identical log data
4. **Full Metadata**: Both backends MUST receive complete metadata
5. **Real-time Delivery**: Logs MUST appear in both places immediately

**CRITICAL RULE**: If a log appears in terminal but NOT in SigNoz (or vice versa), this is a VIOLATION.

### Logger Configuration
```elixir
config :logger,
  backends: [:console, LoggerJSON],  # MANDATORY: Both required
  level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :tenant_id, :trace_id, :user_id]

config :logger_json, :backend,
  formatter: LoggerJSON.Formatters.Datadog,
  metadata: :all
```

### Observability Health Check
```elixir
# Required modules checked:
# - OpentelemetryPhoenix
# - OpentelemetryEcto
# - OpentelemetryOban
# - OpentelemetryFinch
# - Indrajaal.Observability.DualLogging
# - Indrajaal.Observability.LoggerTraceContext
# - Indrajaal.Observability.TelemetryEnhancement

Indrajaal.Observability.InstrumentationHealth.verify_all()
```

### Telemetry Events (MANDATORY)
```elixir
# All operations must emit telemetry
:telemetry.execute(
  [:indrajaal, :compilation, :start],
  %{system_time: System.system_time()},
  %{strategy: strategy, container: container}
)

:telemetry.execute(
  [:indrajaal, :validation, :complete],
  %{duration: duration_ms, errors: error_count},
  %{method: method, consensus: consensus_achieved}
)
```

---

## 14.0 Claude AI Activity Logging (MANDATORY)

### Log Storage Requirements
- **Directory**: ALL Claude logs MUST go to `./data/tmp` directory
- **Session Tracking**: Every Claude session MUST be logged with unique identifiers
- **Activity Logging**: ALL significant Claude activities MUST be recorded
- **Task Completion**: Every task completion MUST be logged with SOPv5.11 details
- **Code Generation**: All AI-generated code MUST be logged with TDG compliance

### Directory Structure
```
./data/tmp/
├── claude_session_[timestamp]_[id].log          # Session summaries
├── claude_activity_[timestamp]_[id].jsonl       # Detailed activity logs
├── claude_performance_[timestamp]_[id].jsonl    # Performance metrics
├── claude_compile_[timestamp].log               # Compilation outputs
├── claude_test_[timestamp].log                  # Test execution logs
├── claude_error_[timestamp].log                 # Error reports
├── claude_agent_[timestamp].log                 # Agent coordination
├── claude_errors_[timestamp]_[id].jsonl         # Error logs and recovery
├── 1-compile.log                                # Primary compilation log
├── fpps_report_[timestamp].json                 # FPPS validation reports
└── emergency_validation_[timestamp].log         # Emergency protocol logs
```

### Log Format Requirements
```elixir
defmodule Indrajaal.Claude.LogStorage do
  @log_dir "./data/tmp"

  def save_log(content, type \\ "general") do
    timestamp = DateTime.now!("Etc/UTC") |> Calendar.strftime("%Y%m%d-%H%M")
    session_id = System.get_env("CLAUDE_SESSION_ID", "default")
    filename = "#{@log_dir}/claude_#{type}_#{timestamp}_#{session_id}.log"

    File.write!(filename, content)
    Logger.info("Claude log saved to: #{filename}")
  end
end
```

---

## 15.0 Git-Based AI Development Workflow

### 15.1 Core Principles
1. **Git as Persistent Memory**: Use Git history to provide AI with structured, auditable memory
2. **AI as Peer Developer**: Treat AI agents as full-fledged contributors following standard workflows
3. **Atomic Commits**: Small, logical commits corresponding to single changes
4. **Branch-Based Development**: Feature branches for every task
5. **Comprehensive Review Process**: Pull requests with automated checks

### 15.2 Git Workflow Commands
```bash
# Feature branch creation
git checkout -b feature/descriptive-name

# Atomic commit with proper message
git commit -m "feat(domain): description of change"

# Pre-push validation
mix precommit  # Runs all quality checks

# Conventional commit formats
feat(scope): add new feature
fix(scope): fix bug in feature
docs(scope): update documentation
refactor(scope): refactor without behavior change
test(scope): add or update tests
chore(scope): maintenance tasks
```

### 15.3 Branch Naming Convention
```
feature/YYYYMMDD-description     # New features
fix/YYYYMMDD-description         # Bug fixes
refactor/YYYYMMDD-description    # Refactoring
docs/YYYYMMDD-description        # Documentation
test/YYYYMMDD-description        # Test additions
```

---

## 16.0 Todolist Management System

### Components
- **PROJECT_TODOLIST.md**: Human-readable primary storage with git tracking
- **scripts/planning/todolist_manager.exs**: Automated management with validation
- **backups/todolist/**: Timestamped backup system for disaster recovery

### Commands (MANDATORY DAILY USAGE)
```bash
# Check current status
mix todo.status

# Update task status
mix todo.update TASK_ID STATUS

# Comprehensive update
mix todo.update --comprehensive

# Sync with validation
mix todo.sync --validate

# Create backup
mix todo.backup --timestamp

# Validate structure
mix todo.validate --strict
```

### Status Values
- **pending**: Task not yet started
- **in_progress**: Currently working on (ONLY ONE at a time)
- **completed**: Task finished successfully
- **blocked**: Task cannot proceed

### Hierarchical Numbering System
```
1.0 - Development & Implementation
2.0 - Testing & Quality Assurance
3.0 - Documentation & Training
4.0 - Infrastructure & Deployment
5.0 - Security & Compliance
6.0 - Performance & Optimization
7.0 - Maintenance & Operations
8.0 - Research & Analysis
9.0 - Emergency & Incident Response
10.0 - System Safety & STAMP Implementation
```

---

## 17.0 Enterprise Testing Standards

### 17.1 Coverage Requirements
- **100% Unit Test Coverage**: ALL functional modules MUST have complete unit test coverage
- **100% Property Testing Coverage**: ALL functional modules MUST have comprehensive property-based testing
- **85% Integration Test Coverage**: ALL functional modules MUST have thorough integration testing
- **95% TDG Compliance**: ALL functional modules MUST follow Test-Driven Generation methodology
- **95% STAMP Safety Coverage**: ALL functional modules MUST have STAMP safety constraint validation

### 17.2 Testing Commands
```bash
# Comprehensive testing
mix test --comprehensive --parallel --max-parallelization

# Coverage analysis
mix test --coverage --threshold 95

# Gold certification testing (5,073 tests)
mix test --gold

# Container-aware testing
mix test --container --distributed

# Performance testing
mix test --performance

# Patient mode TDD execution
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true MIX_ENV=test mix test --timeout 7200000

# Property-based testing
mix test --only property

# STAMP compliance testing
mix test test/stamp/
```

### 17.3 Test Success Metrics
- **Test Coverage**: 91.8% overall (3,578/3,898 functions)
- **Test Files**: 440 test files
- **Test Lines**: 204,424+ lines
- **Demo Success Rate**: 100% (16/16 execution modes)
- **Property Tests**: Both PropCheck and ExUnitProperties required

### 17.4 Test File Structure
```elixir
defmodule MyFeatureTest do
  use ExUnit.Case, async: true
  use PropCheck
  use ExUnitProperties

  # Setup
  setup do
    {:ok, context: create_test_context()}
  end

  # Unit tests
  describe "function_name/arity" do
    test "handles normal input" do
      assert MyFeature.function_name(input) == expected
    end

    test "handles edge cases" do
      assert MyFeature.function_name(edge_case) == expected
    end
  end

  # Property tests (PropCheck)
  property "maintains invariant across all inputs" do
    forall input <- valid_input_generator() do
      result = MyFeature.function_name(input)
      is_valid_result(result)
    end
  end

  # Property tests (ExUnitProperties)
  property "handles arbitrary valid inputs" do
    check all input <- valid_input_stream(),
              max_runs: 100 do
      result = MyFeature.function_name(input)
      assert is_valid_result(result)
    end
  end
end
```

---

## 18.0 STAMP/STPA/CAST Methodology

### 18.1 Proactive Analysis (STPA) Workflow (MANDATORY)
```bash
# 1. Initialize STPA analysis for new feature
mix stamp.stpa --feature-name ACCESS_CONTROL --criticality HIGH

# 2. Generate STPA report template
elixir scripts/stamp/stpa_template_generator.exs --domain access_control

# 3. Validate STPA coverage and completeness
elixir scripts/stamp/stpa_validator.exs --report docs/templates/stpa_access_control_analysis.ex

# 4. Link STPA requirements to test coverage
mix stamp.validate --stpa-report docs/templates/stpa_access_control_analysis.ex --tests
```

### 18.2 Reactive Analysis (CAST) Workflow (MANDATORY)
```bash
# 1. Initiate CAST investigation for critical incident
mix stamp.cast --incident-id INC-12345 --priority P1

# 2. Generate CAST report template
elixir scripts/stamp/cast_template_generator.exs --incident-id INC-12345

# 3. Validate CAST analysis completeness
elixir scripts/stamp/cast_validator.exs --report docs/templates/cast_incident_12345.ex

# 4. Track implementation of CAST recommendations
mix stamp.track --cast-report docs/templates/cast_incident_12345.ex --status
```

### 18.3 Safety Commands
```bash
# Validate all safety systems (daily)
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all

# Monitor real-time safety metrics
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --monitor-safety

# Emergency response activation
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --emergency-response

# Error pattern analysis
elixir scripts/analysis/comprehensive_error_pattern_database.exs --analyze FILE
```

### 18.4 STPA Analysis Template
```elixir
defmodule STPA.AccessControlAnalysis do
  @moduledoc """
  STPA Analysis for Access Control Domain
  Feature: User Authentication
  Criticality: HIGH
  Date: YYYY-MM-DD
  """

  # Step 1: Define Purpose and Losses
  @losses [
    "L1: Unauthorized access to protected resources",
    "L2: Denial of service for authorized users",
    "L3: Data breach through authentication bypass"
  ]

  # Step 2: Identify Hazards
  @hazards [
    "H1: Authentication mechanism fails to validate credentials",
    "H2: Session tokens issued without proper verification",
    "H3: Authorization checks bypassed"
  ]

  # Step 3: Model Control Structure
  @control_structure %{
    controller: "AuthenticationController",
    actuators: ["SessionManager", "TokenGenerator"],
    sensors: ["CredentialValidator", "TokenVerifier"],
    controlled_process: "UserSession"
  }

  # Step 4: Identify Unsafe Control Actions
  @unsafe_control_actions [
    "UCA1: Token issued when credentials invalid",
    "UCA2: Session not terminated when token expired",
    "UCA3: Authorization granted without role verification"
  ]

  # Step 5: Define Safety Constraints
  @safety_constraints [
    "SC1: Tokens SHALL only be issued after credential validation",
    "SC2: Sessions SHALL terminate upon token expiration",
    "SC3: Authorization SHALL require role verification"
  ]
end
```

### 18.5 CAST Investigation Template
```elixir
defmodule CAST.IncidentInvestigation do
  @moduledoc """
  CAST Investigation for Incident INC-12345
  Date: YYYY-MM-DD
  Priority: P1
  """

  # Step 1: System Description at Time of Incident
  @system_state %{
    environment: "Production",
    load: "High (85% capacity)",
    recent_changes: ["Deploy v2.3.1", "Config update"]
  }

  # Step 2: Proximate Events
  @proximate_events [
    "T-5min: Deployment completed",
    "T-2min: Error rate spike detected",
    "T-0: Service unavailable reported"
  ]

  # Step 3: Safety Constraints Violated
  @violated_constraints [
    "SC-CNT-013: Container health validation skipped",
    "SC-PRF-050: Response time exceeded 50ms SLA"
  ]

  # Step 4: Control Structure Analysis
  @control_failures [
    "Deployment controller did not wait for health check",
    "Monitoring system did not alert on pre-deployment health"
  ]

  # Step 5: Recommendations
  @recommendations [
    %{id: "R1", action: "Add mandatory health check gate", priority: :critical},
    %{id: "R2", action: "Implement deployment rollback automation", priority: :high},
    %{id: "R3", action: "Enhance monitoring alerting thresholds", priority: :medium}
  ]
end
```

---

## 19.0 Emergency Protocols

### EP-110 (False Positive) Response
**Trigger**: $q_{valid} \rightarrow q_{emerg}$ (Consensus Failure)
1. **HALT**: Stop immediately
2. **LOG**: Create `./data/tmp/emergency_validation_[timestamp].log`
3. **RCA**: Execute 5-Level RCA
4. **CORRECT**: Fix validation logic
5. **RE-VERIFY**: Full Patient Mode run

### EP-111 (Process Drift) Response
**Trigger**: Validation methods producing inconsistent results over time
1. **DETECT**: Identify drift through daily audits
2. **ISOLATE**: Identify affected validation method
3. **ANALYZE**: Root cause analysis of drift
4. **CORRECT**: Recalibrate or replace affected method
5. **VERIFY**: Full regression testing

### STAMP Violation Response
**Trigger**: Violation of any $SC \in \mathcal{SC}_{72}$
1. **HALT**: Stop process
2. **CAST**: Initiate CAST investigation
3. **REPORT**: Generate STAMP report
4. **MITIGATE**: Apply fix

### Emergency Commands
```bash
# Emergency stop
elixir scripts/emergency/emergency_stop.exs

# Emergency recovery
elixir scripts/emergency/emergency_recovery.exs

# Emergency rollback
elixir scripts/emergency/emergency_rollback.exs

# Container emergency
elixir scripts/containers/verified_nixos_setup.exs --emergency-health-check

# SSL certificate failure recovery
elixir scripts/containers/verified_nixos_setup.exs --ssl-recovery

# PHICS hot-reloading failure
elixir scripts/containers/verified_nixos_setup.exs --phics-recovery

# Consensus failure investigation
elixir scripts/validation/unified_validation_command_center.exs report
```

### Emergency Priority Levels
| Level | Description | Response Time | Escalation |
|-------|-------------|---------------|------------|
| P1 | Critical System Down | <5 min | Immediate |
| P2 | Major Feature Broken | <30 min | 15 min |
| P3 | Minor Issue | <2 hours | 1 hour |
| P4 | Enhancement Request | Next sprint | N/A |

---

## 20.0 Demo Execution System (16 Modes)

### Core Demo Modes
```bash
mix demo --comprehensive          # Enterprise-grade complete demo
mix demo --quick                  # 5-minute essential features demo
mix demo --containers-only        # Infrastructure without GUI
mix demo --gui-only              # Phoenix LiveView showcase
mix demo --validation            # Environment validation and health checks
mix demo --live-traffic          # Continuous alarm simulation
mix demo --benchmark             # Performance analysis with export
mix demo --security-audit        # Security compliance demonstration
```

### Status and Monitoring Modes
```bash
mix demo --status                # Real-time environment status
mix demo --health-check          # Comprehensive health diagnostics
mix demo --troubleshoot          # Automated 5-Level RCA troubleshooting
```

### Environment Management Modes
```bash
mix demo --reset                 # Complete environment reset
mix demo --cleanup               # Optimized container cleanup
mix demo --setup-podman          # Automated Podman environment setup
mix demo --cache-management      # Intelligent cache system management
mix demo --performance-report    # Detailed performance analytics
```

### Demo Infrastructure Components
- **indrajaal-app**: Main Phoenix application with health monitoring
- **indrajaal-db**: PostgreSQL 17 database with initialization scripts
- **indrajaal-redis**: Redis cache server for session management
- **indrajaal-prometheus**: Metrics collection and monitoring
- **indrajaal-grafana**: Real-time dashboards and visualizations
- **indrajaal-nginx**: Load balancer and reverse proxy

---

## 21.0 Command Reference (Canonical Set)

### Validation & Quality
```bash
elixir scripts/validation/unified_patient_mode_validation_orchestrator.exs --validate
elixir scripts/validation/unified_patient_mode_validation_orchestrator.exs --status
elixir scripts/validation/comprehensive_compilation_validator.exs --save-report
elixir scripts/validation/daily_validation_audit.exs
elixir scripts/validation/unified_validation_command_center.exs validate
mix format --check-formatted
mix credo --strict
mix sobelow --strict
mix dialyzer
```

### Task Management
```bash
mix todo.status
mix todo.update --comprehensive
mix todo.sync --validate
mix todo.backup --timestamp
mix todo.validate --strict
```

### Container Management
```bash
elixir scripts/performance/podman_direct_manager.exs --status
elixir scripts/containers/verified_nixos_setup.exs --comprehensive
elixir scripts/containers/verified_nixos_setup.exs --health-check
podman-compose -f podman-compose.yml up -d
# BANNED: docker-compose, podman run (manual)
```

### Analysis
```bash
elixir scripts/analysis/ast_compilation_fixer.exs --comprehensive-analysis
elixir scripts/analysis/five_level_rca_analyzer.exs --issue-type compilation_error
elixir scripts/analysis/comprehensive_error_pattern_database.exs --analyze FILE
```

### Multi-Agent Coordination
```bash
elixir scripts/coordination/multi_agent_coordinator.exs --deploy
elixir scripts/coordination/autonomous_compilation_engine.exs --execute
elixir scripts/coordination/smart_container_orchestrator.exs --monitor
elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status
```

### Clustering & Distributed Operations
```bash
# Start robust cluster (Tailscale/Localhost auto-detect)
./scripts/cluster/start_cluster.sh

# Scale cluster up/down dynamically
./scripts/cluster/scale.sh start 3  # Add app-3
./scripts/cluster/scale.sh stop 3   # Remove app-3

# Remote console to running node
./scripts/cluster/remote_console.sh app-1

# View cluster logs
tail -f data/logs/cluster/app-1.log
```

---

## 22.0 Ash Framework Rules

- **Atomic**: `require_atomic? false` allowed **ONLY** for `UPDATE` actions (NEVER CREATE)
- **Actions**: All interface actions must be defined in `actions` block
- **Structure**: `calculations do` blocks must encapsulate calculations

```elixir
# CORRECT: UPDATE action with function-based changes
update :custom_action do
  require_atomic? false  # MANDATORY for function-based changes
  change fn changeset, _context ->
    changeset |> Ash.Changeset.change_attribute(:field, value)
  end
end

# CORRECT: Simple UPDATE action
update :simple_action do
  accept [:field1, :field2]  # No require_atomic? needed
end

# WRONG: CREATE with require_atomic? false
create :new_resource do
  require_atomic? false  # VIOLATION: Never use for CREATE
end
```

### Ash Resource Structure
```elixir
defmodule MyApp.Resource do
  use Ash.Resource,
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "resources"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    timestamps()
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name]
    end
  end

  calculations do
    calculate :display_name, :string, expr(name)
  end
end
```

---

## 23.0 AI/ML Architecture (Hybrid)

- **Control Plane**: Elixir/BEAM + Nx ecosystem
- **Compute Plane**: Modular Mojo/MAX
- **Routing**: $<100ms \rightarrow \text{Nx}$, $>100ms \rightarrow \text{Mojo}$
- **Hardware**: GPU via Container abstraction

### Required Dependencies
```elixir
{:nx, "~> 0.7"},          # Numerical computing
{:axon, "~> 0.6"},        # Neural networks
{:bumblebee, "~> 0.5"},   # Pre-trained models
{:scholar, "~> 0.3"},     # Classical ML
{:explorer, "~> 0.8"},    # DataFrames
{:exla, "~> 0.7"},        # GPU acceleration
```

### Hybrid Routing Pattern
```elixir
defmodule Indrajaal.AI.HybridRouter do
  def route_task(task) do
    case analyze_complexity(task) do
      :simple -> {:nx, execute_on_nx(task)}
      :complex -> {:mojo, execute_on_mojo(task)}
    end
  end

  defp analyze_complexity(task) do
    if estimated_duration(task) < 100, do: :simple, else: :complex
  end
end
```

### AI/ML Container Configuration
```yaml
indrajaal-nx:
  image: localhost/indrajaal-nx:latest
  gpu: optional
  ports: [8080]
  environment:
    - XLA_TARGET=cpu

indrajaal-mojo:
  image: localhost/indrajaal-mojo:latest
  gpu: required
  ports: [8081]
```

---

## 24.0 Mobile API Specification (17 Endpoints)

- **Auth**: `login`, `refresh`, `logout`
- **Alarms**: `list`, `detail`, `acknowledge`, `resolve`, `escalate`
- **Management**: `devices`, `sites`
- **Notifications**: `register`, `preferences` (get/put), `dashboard`, `sync`, `health`

### API Endpoint Details
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/login` | POST | User authentication |
| `/api/v1/auth/refresh` | POST | Token refresh |
| `/api/v1/auth/logout` | POST | Session termination |
| `/api/v1/alarms` | GET | List alarms |
| `/api/v1/alarms/:id` | GET | Alarm details |
| `/api/v1/alarms/:id/acknowledge` | POST | Acknowledge alarm |
| `/api/v1/alarms/:id/resolve` | POST | Resolve alarm |
| `/api/v1/alarms/:id/escalate` | POST | Escalate alarm |
| `/api/v1/devices` | GET | List devices |
| `/api/v1/sites` | GET | List sites |
| `/api/v1/notifications/register` | POST | Register for push |
| `/api/v1/notifications/preferences` | GET | Get preferences |
| `/api/v1/notifications/preferences` | PUT | Update preferences |
| `/api/v1/dashboard` | GET | Dashboard data |
| `/api/v1/sync` | POST | Sync offline data |
| `/api/v1/health` | GET | Health check |

---

## 25.0 Security Standards (SOPv5.11 Phase 7)

### Authentication
- **Primary**: Microsoft Entra ID with cybernetic identity management
- **B2C**: Separate tenant for customers with 15-agent identity validation
- **Devices**: Client credentials with SSL/TLS certificates and container isolation
- **APIs**: JWT tokens with <50ms expiry validation and automated refresh
- **MFA**: Required for admin roles with PHICS v2.1 integration

### Authorization
- **RBAC**: Synced from Entra groups with cybernetic access control
- **ABAC**: Attribute-based fine control with 15-agent coordination
- **Row-Level**: Tenant isolation enforced through container boundaries
- **Field-Level**: Cloak encryption for PII with PHICS v2.1 synchronization

### Compliance Frameworks
| Framework | Scope | Status |
|-----------|-------|--------|
| ISO 27001 | Enterprise security controls | Compliant |
| SOX 404 | Financial compliance | Compliant |
| GDPR | Data protection | Compliant |
| HIPAA | Healthcare compliance | Ready |
| PCI DSS | Payment security | Ready |
| DPDP Act | Data protection | Compliant |
| SIA DC-09 | Alarm protocol | Compliant |

---

## 26.0 Performance Metrics (Validated)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Cybernetic Goal Achievement | 95.8% | >90% | PASS |
| Execution Efficiency | 94.7% | >90% | PASS |
| Quality Score | 98.2% | >95% | PASS |
| Safety Compliance | 100.0% | 100% | PASS |
| Sustainability Score | 93.7% | >90% | PASS |
| Scalability | 96.4% | >90% | PASS |
| Agent Coordination | 94.7% | >90% | PASS |
| Container Compliance | 100% | 100% | PASS |
| Response Time | <50ms | <100ms | PASS |
| Concurrent Users | 100+ | 50+ | PASS |
| Container Startup | <30s | <60s | PASS |
| System Uptime | 99.9% | 99.5% | PASS |

---

## 27.0 Error Pattern Database (EP-001 to EP-080)

### Compilation Error Patterns (EP-001 to EP-020)
| EP ID | Pattern | Severity | Description |
|-------|---------|----------|-------------|
| EP-001 | `undefined function` | CRITICAL | Function not defined or not imported |
| EP-002 | `undefined variable` | CRITICAL | Variable used before definition |
| EP-003 | `CompileError` | CRITICAL | General compilation failure |
| EP-004 | `syntax error` | CRITICAL | Invalid Elixir syntax |
| EP-005 | `no such file` | HIGH | Missing file reference |
| EP-006 | `cannot compile module` | CRITICAL | Module compilation failure |
| EP-007 | `** (ArgumentError)` | HIGH | Invalid argument passed |
| EP-008 | `** (RuntimeError)` | HIGH | Runtime error during compilation |
| EP-009 | `module already defined` | MEDIUM | Duplicate module definition |
| EP-010 | `struct is not defined` | HIGH | Using undefined struct |
| EP-011 | `no function clause` | HIGH | Pattern match failure |
| EP-012 | `protocol not implemented` | MEDIUM | Missing protocol implementation |
| EP-013 | `spec error` | MEDIUM | Type specification error |
| EP-014 | `behaviour not implemented` | MEDIUM | Missing behaviour callback |
| EP-015 | `undefined module` | CRITICAL | Referencing undefined module |
| EP-016 | `wrong number of args` | HIGH | Incorrect arity |
| EP-017 | `reserved word` | MEDIUM | Using reserved keyword |
| EP-018 | `missing terminator` | CRITICAL | Unclosed block/string |
| EP-019 | `unexpected token` | CRITICAL | Parser unexpected input |
| EP-020 | `circular dependency` | HIGH | Module dependency cycle |

### Warning Patterns (EP-021 to EP-040)
| EP ID | Pattern | Severity | Description |
|-------|---------|----------|-------------|
| EP-021 | `unused variable` | LOW | Variable defined but never used |
| EP-022 | `unused import` | LOW | Import statement not used |
| EP-023 | `deprecated` | MEDIUM | Using deprecated function |
| EP-024 | `shadowed variable` | MEDIUM | Variable shadows outer scope |
| EP-025 | `unreachable code` | MEDIUM | Code after return/raise |
| EP-026 | `match will fail` | HIGH | Pattern will never match |
| EP-027 | `no clause matches` | HIGH | Case/cond without matching clause |
| EP-028 | `overlapping patterns` | LOW | Redundant pattern clauses |
| EP-029 | `unused function` | LOW | Private function never called |
| EP-030 | `missing @doc` | LOW | Public function without docs |
| EP-031 | `unused module attr` | LOW | Module attribute never used |
| EP-032 | `inefficient guard` | LOW | Guard could be optimized |
| EP-033 | `large binary` | MEDIUM | Binary exceeds recommended size |
| EP-034 | `type mismatch` | HIGH | Dialyzer type error |
| EP-035 | `spec incomplete` | MEDIUM | Type spec missing cases |
| EP-036 | `unused alias` | LOW | Alias never referenced |
| EP-037 | `unsafe code` | HIGH | Sobelow security warning |
| EP-038 | `dead code` | MEDIUM | Code never executed |
| EP-039 | `formatting issue` | LOW | Code style violation |
| EP-040 | `credo issue` | LOW | Credo lint warning |

### Runtime Error Patterns (EP-041 to EP-060)
| EP ID | Pattern | Severity | Description |
|-------|---------|----------|-------------|
| EP-041 | `GenServer crash` | CRITICAL | GenServer process failure |
| EP-042 | `timeout` | HIGH | Process timeout exceeded |
| EP-043 | `connection refused` | HIGH | Database/service unavailable |
| EP-044 | `memory exhausted` | CRITICAL | OOM error |
| EP-045 | `process died` | HIGH | Unexpected process termination |
| EP-046 | `supervisor failure` | CRITICAL | Supervisor max restarts |
| EP-047 | `ETS error` | HIGH | ETS table operation failure |
| EP-048 | `port closed` | MEDIUM | External port terminated |
| EP-049 | `SSL error` | HIGH | Certificate/handshake failure |
| EP-050 | `encoding error` | MEDIUM | String encoding issue |
| EP-051 | `registry error` | MEDIUM | Process registry failure |
| EP-052 | `task failure` | HIGH | Task.async failure |
| EP-053 | `agent error` | MEDIUM | Agent state corruption |
| EP-054 | `distribution error` | HIGH | Node communication failure |
| EP-055 | `file error` | MEDIUM | File I/O failure |
| EP-056 | `JSON parse error` | MEDIUM | Invalid JSON data |
| EP-057 | `database error` | HIGH | SQL/Ecto error |
| EP-058 | `migration error` | HIGH | Database migration failure |
| EP-059 | `config error` | HIGH | Configuration invalid |
| EP-060 | `env var missing` | HIGH | Required env var not set |

### Validation Error Patterns (EP-061 to EP-080)
| EP ID | Pattern | Severity | Description |
|-------|---------|----------|-------------|
| EP-061 | `consensus failure` | CRITICAL | FPPS methods disagree |
| EP-062 | `partial analysis` | CRITICAL | Incomplete log analysis |
| EP-063 | `timeout violation` | HIGH | Patient mode violation |
| EP-064 | `container escape` | CRITICAL | Non-container execution |
| EP-065 | `registry violation` | HIGH | External registry usage |
| EP-066 | `PHICS failure` | HIGH | Hot-reload sync failure |
| EP-067 | `agent deadlock` | CRITICAL | Agent coordination failure |
| EP-068 | `STAMP violation` | CRITICAL | Safety constraint breach |
| EP-069 | `TDG violation` | HIGH | Code before tests |
| EP-070 | `property test fail` | HIGH | PropCheck/ExUnit failure |
| EP-071 | `log truncation` | CRITICAL | Log file truncated |
| EP-072 | `backup failure` | MEDIUM | Checkpoint not created |
| EP-073 | `drift detected` | HIGH | Process drift (EP-111) |
| EP-074 | `false positive` | CRITICAL | False positive (EP-110) |
| EP-075 | `coverage gap` | MEDIUM | Test coverage below threshold |
| EP-076 | `format violation` | LOW | Code format check failure |
| EP-077 | `credo violation` | LOW | Static analysis failure |
| EP-078 | `sobelow alert` | HIGH | Security vulnerability |
| EP-079 | `dialyzer error` | MEDIUM | Type analysis failure |
| EP-080 | `audit failure` | HIGH | Audit trail incomplete |

### Agent-Generated Code Error Patterns (EP-AGT-001 to EP-AGT-012)
| EP ID | Pattern | Severity | Description | Fix |
|-------|---------|----------|-------------|-----|
| EP-AGT-001 | `define :list, action: :read` duplicate | CRITICAL | BaseResource already defines :list/:get | Remove duplicate define |
| EP-AGT-002 | `accept [:param]` in update action | HIGH | Should use argument for non-attributes | Change to `argument :param, :type` |
| EP-AGT-003 | `one_of:` for :string type | CRITICAL | one_of only works with :atom type | Change type to :atom |
| EP-AGT-004a | `return value` statement | CRITICAL | Elixir has no return keyword | Use if/else or case |
| EP-AGT-004b | `\|\|\|` operator | CRITICAL | Use Bitwise.bor instead | `import Bitwise; bor(a, b)` |
| EP-AGT-005 | `default:` syntax | HIGH | Ash uses `default value` not `default: value` | Remove colon |
| EP-AGT-006 | Unused variable without `_` | LOW | Unused parameters cause warnings | Prefix with underscore |
| EP-AGT-007 | Missing `require_atomic? false` | CRITICAL | Required for function-based update changes | Add directive to action |
| EP-AGT-008 | Resource not in domain | CRITICAL | New resources must be registered | Add to domain resources block |
| EP-AGT-009 | `Jwt.peek/1` or wrong return | HIGH | Guardian Jwt.peek/2 returns map not tuple | Match on `%{claims: claims}` |
| EP-AGT-010 | RateLimiter `:ok` match | MEDIUM | Returns `{:ok, :allowed}` not `:ok` | Update pattern match |
| EP-AGT-011 | `catch` before `rescue` | MEDIUM | Elixir requires rescue before catch | Reorder blocks |
| EP-AGT-012 | Cachex.Spec macros | HIGH | Macros need `require Cachex.Spec` | Add require statement |
| EP-AGT-013 | `Enum.map_join(&func, joiner)` | CRITICAL | Enum.map_join/3 takes (joiner, mapper) not (mapper, joiner) | Swap argument order |

**Agent Code Error Pattern Detection**:
```elixir
# Patterns detected by agent_code_validator.exs
@error_patterns [
  %{id: "EP-AGT-001", pattern: ~r/define :list, action: :list|define :list, action: :read/},
  %{id: "EP-AGT-002", pattern: ~r/update :[a-z_]+ do\s+accept \[:[a-z_]+\]/},
  %{id: "EP-AGT-003", pattern: ~r/attribute :[a-z_]+, :string do.*constraints one_of:/s},
  %{id: "EP-AGT-004a", pattern: ~r/\breturn\s+/},
  %{id: "EP-AGT-004b", pattern: ~r/\|\|\|/},
  %{id: "EP-AGT-005", pattern: ~r/default:/},
  %{id: "EP-AGT-007", pattern: ~r/update :[a-z_]+ do\s+(?!.*require_atomic\?).*change fn/s},
  %{id: "EP-AGT-011", pattern: ~r/try do.*catch.*rescue/s},
  %{id: "EP-AGT-013", pattern: ~r/Enum\.map_join\s*\(\s*&[^,]+,\s*"[^"]+"\)/}
]
```

---

## 28.0 Structured Claude Elixir Bug Analysis Templates

### 28.1 Bug Report Template (MANDATORY)
```markdown
## Bug Report
- **Issue**: [Description]
- **Expected**: [Behavior]
- **Actual**: [Behavior]
- **Code Context**: [Paste relevant code]
- **Error Messages**: [If any]
- **Module**: [Module.Name]
- **Function**: [function_name/arity]
- **Issue Type**: [GenServer crash | Memory leak | Race condition | Other]
- **Error Message**:
  ```elixir
  [Paste stack trace]
  ```

## Request
1. Analyze root cause
2. Suggest fix with explanation
3. Provide test cases
4. Check for side effects
```

### 28.2 Advanced Analysis Template (MANDATORY)
```markdown
## Elixir Bug Report Template
- **Module**: [Module.Name]
- **Function**: [function_name/arity]
- **Issue Type**: [GenServer crash | Memory leak | Race condition | Other]
- **Error Message**:
  ```elixir
  [Paste stack trace]
  ```

Request for Claude:
- Analyze the OTP supervision tree impact
- Check for process message queue buildup
- Suggest fix with BEAM VM considerations
- Provide ExUnit test cases
- Consider telemetry/observability
```

### 28.3 AI-Fix Checklist (MANDATORY COMPLIANCE)
```yaml
Elixir AI-Fix Checklist:
  Architecture:
    - [ ] Fix respects OTP principles
    - [ ] Supervision tree integrity maintained
    - [ ] No process bottlenecks introduced
    - [ ] Message passing patterns optimal

  Code Quality:
    - [ ] Pattern matching used effectively
    - [ ] No unnecessary try/catch blocks
    - [ ] Proper use of with statements
    - [ ] Telemetry events added where appropriate

  Performance:
    - [ ] No blocking operations in GenServers
    - [ ] ETS tables used appropriately
    - [ ] Binary handling optimized
    - [ ] Task.async_stream for parallel ops

  Testing:
    - [ ] ExUnit tests comprehensive
    - [ ] Property tests for complex logic
    - [ ] Mox used for external dependencies
    - [ ] Concurrent test scenarios covered
```

### 28.4 AI-Assisted Fix Documentation (MANDATORY)
```elixir
File.write!("doc/ai_fixes/#{branch}.md",
"""
# AI-Assisted Fix Documentation

## Branch: #{branch}
## Date: #{Date.utc_today()}

### Changes Made:
- [ ] Add description here

### AI Contributions:
- [ ] List AI suggestions implemented

### Manual Verification:
- [ ] Tests added/modified
- [ ] Performance impact measured
- [ ] Production readiness confirmed
""")
```

### 28.5 Key Elixir + NixOS + Podman Considerations (MANDATORY)

**REQUIRED INTEGRATION POINTS**:
- **Immutability**: Leverage NixOS for reproducible environments
- **Fault Tolerance**: Ensure AI fixes respect OTP principles
- **Container Isolation**: Use Podman's rootless mode for security
- **Hot Code Upgrades**: Test AI fixes for upgrade compatibility
- **BEAM Observability**: Add proper telemetry and logging
- **Resource Management**: Monitor process counts and memory in containers

---

## 29.0 Comprehensive NixOS Container Infrastructure

### 29.1 Container Setup Commands (MANDATORY)
```bash
# Complete container environment setup
elixir scripts/containers/verified_nixos_setup.exs --comprehensive

# SSL certificate validation and setup
elixir scripts/containers/verified_nixos_setup.exs --ssl-setup

# PHICS hot-reloading integration
elixir scripts/containers/verified_nixos_setup.exs --phics-validation

# Container orchestration startup
elixir scripts/containers/verified_nixos_setup.exs --orchestration
```

### 29.2 Container Validation and Testing
```bash
# STAMP safety constraint validation
mix test test/stamp/container_safety_constraints_test.exs

# TDG container creation validation
mix test test/tdg/container_creation_test.exs

# Property-based container testing
mix test test/property/container_properties_test.exs

# Comprehensive container tests
mix test test/stamp/ test/tdg/ test/property/
```

### 29.3 Critical Container Requirements (ZERO TOLERANCE)

**MANDATORY CONTAINER POLICIES**:
1. **Local Registry Only**: All containers MUST use `localhost/` prefix exclusively
2. **SSL Certificate Access**: All containers MUST have accessible SSL certificates
3. **PHICS Hot-Reloading**: All development containers MUST support hot-reloading
4. **Health Check Compliance**: All containers MUST pass health checks
5. **Centralized Logging**: All container logs MUST be in `./data/tmp`

**ABSOLUTELY FORBIDDEN**:
1. External Registry Usage: Never pull from docker.io without local caching
2. SSL Certificate Bypass: All containers must have working SSL access
3. Docker Commands: Never use docker, docker-compose, docker-* commands
4. Privileged Containers: Never run containers with --privileged
5. Host Network Mode: Never use --network=host without approval

### 29.4 SSL Certificate Strategy

**Multi-Path Certificate Resolution**:
```elixir
@ssl_paths [
  "/etc/ssl/certs/ca-certificates.crt",
  "/etc/pki/tls/certs/ca-bundle.crt",
  "/etc/ssl/ca-bundle.pem",
  "/usr/share/ca-certificates/",
  System.get_env("SSL_CERT_FILE"),
  System.get_env("SSL_CERT_DIR")
]

def find_ssl_cert() do
  @ssl_paths
  |> Enum.filter(&(&1 && File.exists?(&1)))
  |> List.first()
  |> case do
    nil -> {:error, :no_ssl_cert_found}
    path -> {:ok, path}
  end
end
```

---

## 30.0 Usage Rules (Elixir Core)

### 30.1 Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer matching on function heads instead of `if`/`else` or `case` in function bodies

### 30.2 Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

### 30.3 Common Mistakes to Avoid
- Elixir has no `return` statement. The last expression is always returned
- Don't use `Enum` on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists cannot be indexed with brackets. Use pattern matching or `Enum`
- Prefer `Enum.reduce` over recursion
- Using the process dictionary is typically unidiomatic
- Only use macros if explicitly requested

### 30.4 Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate functions should end with `?` (not start with `is_`)

### 30.5 Data Structures
- Use structs over maps when the shape is known
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer prepending to lists: `[new | list]` not `list ++ [new]`

---

## 31.0 Usage Rules (OTP)

### 31.1 GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

### 31.2 Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages
- When in doubt, use `call` over `cast` to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

### 31.3 Fault Tolerance
- Set up processes such that they can handle crashing and being restarted
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

### 31.4 Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

---

## 32.0 Usage Rules (Phoenix)

### 32.1 Phoenix v1.8 Guidelines
- Begin LiveView templates with `<Layouts.app flash={@flash} ...>`
- The `MyAppWeb.Layouts` module is aliased in `my_app_web.ex`
- For `current_scope` errors, move routes to the proper `live_session`
- Phoenix v1.8 moved `<.flash_group>` to the `Layouts` module
- Use the `<.icon name="hero-x-mark">` component for icons
- Use the `<.input>` component for form inputs from `core_components.ex`

### 32.2 JS and CSS Guidelines
- Use Tailwind CSS classes for styling
- Tailwindcss v4 no longer needs `tailwind.config.js`
- Never use `@apply` when writing raw CSS
- Import vendor deps into app.js and app.css
- Never write inline `<script>` tags within templates

### 32.3 Project Guidelines
- Use `mix precommit` alias when done with changes
- Use `:req` (`Req`) library for HTTP requests
- Avoid `:httpoison`, `:tesla`, and `:httpc`

---

## 33.0 Project Completion Status

### 33.1 Achievement Summary
- **SOPv5.11 Framework Deployment**: 100% Complete
- **50-Agent Architecture Excellence**: 94.7% Coordination Efficiency
- **Level 4 System Integration Testing**: 440 test files, 204,424+ lines
- **Container Infrastructure Excellence**: 3 containers, 20 CPU cores, 56GB RAM
- **STAMP Safety Excellence**: 72/72 constraints validated
- **PHICS v2.1 Integration**: <50ms synchronization latency
- **Enterprise Production Readiness**: $12.8M+ strategic value

### 33.2 Strategic Value Delivered
- **Innovation Leadership**: World's first SOPv5.11 7-phase cybernetic framework
- **Enterprise Readiness**: 100% production-ready with comprehensive validation
- **Quality Excellence**: Complete TPS + STAMP + TDG + PHICS + GDE methodology
- **50-Agent Architecture**: 4-layer hierarchical coordination (logical, within indrajaal-app)
- **Container Excellence**: 3 consolidated containers with PHICS hot-reloading
- **Testing Excellence**: 5 comprehensive test suites
- **Safety Leadership**: 72 SOPv5.11 safety constraints with zero tolerance
- **Business Impact**: $12.8M+ strategic value with 1,280% ROI

---

## 34.0 Quick Reference Cards

### 34.1 Daily Workflow Commands
```bash
# Morning startup
devenv shell
elixir scripts/performance/podman_direct_manager.exs --status
mix deps.get && mix compile

# Development cycle
NO_TIMEOUT=true PATIENT_MODE=enabled mix compile --warnings-as-errors 2>&1 | tee -a ./data/tmp/1-compile.log
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus

# Pre-commit
mix format --check-formatted && mix credo --strict && mix test

# End of day
mix todo.status
git status
```

### 34.2 Emergency Quick Reference
```bash
# System failure
elixir scripts/emergency/emergency_stop.exs
elixir scripts/emergency/emergency_recovery.exs

# Consensus failure
elixir scripts/validation/unified_validation_command_center.exs report

# Container failure
elixir scripts/containers/verified_nixos_setup.exs --emergency-health-check

# Rollback
git checkout -- .
elixir scripts/validation/emergency_rollback_system.exs
```

### 34.3 Validation Quick Reference
```bash
# Full validation
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus --save-report

# STAMP compliance
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all

# Agent status
elixir scripts/coordination/ultimate_15_agent_10_container_autonomous_executor.exs --status
```

---

## 35.0 Document Metadata

### Version History
| Version | Date | Description |
|---------|------|-------------|
| 9.0.0 | 2025-12-07 | Criticality-analyzed expansion to ~3500 lines |
| 8.0.0 | 2025-12-01 | Ultra-exhaustive complete specification |
| 7.0.0 | 2025-11-15 | Full build snapshot |
| 6.0.0 | 2025-11-01 | Mathematical complete specification |

### Document Statistics
- **Total Lines**: ~3500
- **Total Sections**: 35
- **Mathematical Symbols**: 50+
- **Commands Documented**: 200+
- **Safety Constraints**: 72
- **Agent Patterns**: 50
- **Error Patterns**: 80
- **Container Configurations**: 10

### Compliance Certifications
- SOPv5.11 Cybernetic Framework: CERTIFIED
- STAMP Safety Methodology: VERIFIED
- TDG (Test-Driven Generation): ENFORCED
- FPPS 5-Method Validation: OPERATIONAL
- PHICS v2.1 Hot-Reloading: ACTIVE
- 50-Agent Architecture: DEPLOYED

---

**Final Formal Assertion**: This document constitutes the complete, exhaustive, and mathematically rigorous specification of the Indrajaal Safety-Critical System (v9.0.0).

$\forall \text{Action } a, (a \notin \text{CLAUDE.md}) \implies (a \text{ is Forbidden})$

**Document Compiled By**: Claude Code (Opus 4.5)
**Compilation Date**: 2025-12-07 14:30 CEST
**Status**: VERIFIED COMPLETE

---

## 36.0 Patient Mode Testing Protocol (Complete)

### 36.1 Testing Requirements (MANDATORY COMPLIANCE)

**REQUIRED PATIENT TESTING BEHAVIOR**:
1. **NO_TIMEOUT Environment**: ALL tests MUST run with `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true`
2. **Wait for Completion**: MUST wait patiently for ALL compilation and test execution to complete naturally
3. **No Interruption**: NEVER interrupt or cancel test execution due to time constraints
4. **Extended Timeouts**: Use maximum available timeout values (7200000ms / 2 hours minimum)
5. **Compilation Fixes First**: Fix ALL compilation errors before attempting test execution
6. **Dependencies Installed**: Ensure ALL testing dependencies (PropCheck, ExUnitProperties) are properly installed
7. **Full Test Suite**: Execute complete TDD test suite without limiting test cases prematurely

**ABSOLUTELY FORBIDDEN**:
1. **Timeout Interruption**: VIOLATION - Never interrupt tests due to timeout
2. **Impatient Execution**: VIOLATION - Never rush or cancel long-running tests
3. **Incomplete Testing**: VIOLATION - Never skip test execution due to compilation issues
4. **Dependency Shortcuts**: VIOLATION - Never run tests without proper dependency installation
5. **Limited Test Execution**: VIOLATION - Never artificially limit test cases without technical reason
6. **Compilation Bypassing**: VIOLATION - Never attempt to run tests with known compilation errors
7. **Using head/tail commands**: VIOLATION - Never use truncation commands on output
8. **Partial Log Analysis**: VIOLATION - Must analyze complete logs

### 36.2 TDD Testing Protocol (MANDATORY)

**COMPREHENSIVE TDD REQUIREMENTS**:
1. **Dual Property Testing**: MUST use BOTH PropCheck and ExUnitProperties for property-based testing
2. **6 Test Categories**: Unit, Integration, End-to-End, Error Scenarios, Performance, Regression tests required
3. **EP-110/EP-111 Tests**: Specific regression tests for false positive and drift prevention
4. **Mock Implementations**: Complete mock implementations for all validation components
5. **Consensus Testing**: Comprehensive testing of multi-method validation consensus mechanism
6. **Pattern Testing**: Validation of all error/warning pattern detection capabilities
7. **Performance Testing**: Memory usage, timeout handling, and parallel execution validation

**MANDATORY COMPILATION WORKFLOW (ZERO TOLERANCE)**:
```bash
# MANDATORY COMPILATION COMMAND (ONLY ALLOWED PATTERN):
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --verbose 2>&1 | tee -a compilation.log

# MANDATORY WORKFLOW:
# 1. Execute compilation with complete logging using `tee -a` to capture ALL output
# 2. Wait patiently for compilation to complete (no matter how long it takes)
# 3. ONLY analyze log file AFTER compilation completes
# 4. Read complete log file to understand all issues
# 5. Apply systematic fixes based on complete analysis
# 6. Never use partial analysis tools like `head`, `tail`, or `grep` on live output
```

**MANDATORY TDD COMMANDS**:
```bash
# Install dependencies first (MANDATORY)
mix deps.get

# Patient mode TDD test execution (MANDATORY)
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true MIX_ENV=test mix test test/validation/comprehensive_false_positive_prevention_test.exs --timeout 7200000

# Alternative patient execution
mix test test/validation/comprehensive_false_positive_prevention_test.exs --timeout 0 --max-cases 1000 --trace

# Standalone test validation (if compilation issues exist)
elixir scripts/validation/simple_tdd_test_validator.exs
```

### 36.3 Compilation Error Resolution (ZERO TOLERANCE)

**MANDATORY ERROR RESOLUTION WORKFLOW**:
1. **Identify All Errors**: Run compilation to identify ALL undefined variable and function errors
2. **Systematic Fixing**: Fix errors systematically, starting with most critical files
3. **Parameter Correction**: Remove underscore prefix from used parameters (e.g., `_state` → `state`)
4. **Variable Definition**: Add proper variable definitions for all undefined variables
5. **Function Signature**: Ensure all function signatures match their usage
6. **Test After Each Fix**: Run compilation after each fix to verify resolution
7. **Complete Validation**: Ensure 100% compilation success before running tests

**COMMON COMPILATION FIXES**:
```elixir
# WRONG: Using parameter with underscore prefix when it's actually used
defp my_function(_state) do
  state  # Error: undefined variable "state"
end

# CORRECT: Remove underscore prefix for used parameters
defp my_function(state) do
  state  # Works correctly
end

# WRONG: Undefined variable in function
defp process_data do
  metadata  # Error: undefined variable "metadata"
end

# CORRECT: Define variable or pass as parameter
defp process_data(metadata) do
  metadata  # Works correctly
end
```

### 36.4 Test Success Criteria (MANDATORY ACHIEVEMENT)

**REQUIRED TEST RESULTS**:
- **Test File Structure**: 100% compliance with all required test categories
- **EP-110 Prevention**: Must demonstrate false positive elimination
- **EP-111 Prevention**: Must demonstrate process drift detection
- **Consensus Mechanism**: Must validate multi-method agreement checking
- **Pattern Detection**: Must validate all error/warning patterns
- **Mock Implementations**: Must have functional mocks for all components
- **Performance Tests**: Must validate memory usage and execution time
- **Property Tests**: Must validate invariants using both PropCheck and ExUnitProperties

**SUCCESS VALIDATION COMMANDS**:
```bash
# Validate test structure
elixir scripts/validation/simple_tdd_test_validator.exs

# Check compilation status
mix compile --warnings-as-errors

# Patient test execution status
echo "Starting patient test execution with infinite patience..."
```

### 36.5 Patient Execution Environment (ENFORCED)

**REQUIRED ENVIRONMENT VARIABLES**:
```bash
# Core patient mode settings
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export MIX_ENV=test

# Extended timeout configurations
export BASH_DEFAULT_TIMEOUT_MS=7200000    # 2 hours
export BASH_MAX_TIMEOUT_MS=7200000        # 2 hours
export MCP_TOOL_TIMEOUT=7200000           # 2 hours
export TEST_TIMEOUT=7200000               # 2 hours
export COMPILE_TIMEOUT=7200000            # 2 hours
```

### 36.6 Daily Testing Workflow (MANDATORY)

**MORNING VALIDATION**:
```bash
# Check environment
echo $NO_TIMEOUT $PATIENT_MODE $INFINITE_PATIENCE

# Validate dependencies
mix deps.get

# Check compilation status
mix compile --warnings-as-errors
```

**TDD EXECUTION**:
```bash
# Patient TDD test execution
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true MIX_ENV=test mix test test/validation/comprehensive_false_positive_prevention_test.exs --timeout 0
```

**VALIDATION AND REPORTING**:
```bash
# Standalone validation
elixir scripts/validation/simple_tdd_test_validator.exs

# Generate reports
find ./data/tmp -name "*tdd*" -o -name "*test*validation*" | head -5
```

---

## 37.0 Maximum Parallelization Task Execution Rules

### 37.1 Parallel Execution Requirements (MANDATORY)

**INDEPENDENT TASK EXECUTION**:
When executing independent tasks, Claude MUST use maximum parallelization:
- Multiple mix tasks can run in parallel
- Multiple validation scripts can execute concurrently
- Multiple agent coordination tasks can run simultaneously
- Multiple analysis operations can execute in parallel

### 37.2 Violation Categories

| Category | Priority | Description |
|----------|----------|-------------|
| Category 1 | CRITICAL | Tasks completed without mix todo updates |
| Category 2 | HIGH | Sequential execution when parallelization possible |
| Category 3 | MEDIUM | Missing critical path analysis |
| Category 4 | MEDIUM | No journal documentation for significant work |
| Category 5 | LOW | Missing backup creation after major completions |

### 37.3 Completion Requirements

**MANDATORY COMPLETION CHECKS**:
- **Mix Todo Status**: All tasks properly updated in mix todo system
- **PROJECT_TODOLIST.md**: Synchronized with actual completion status
- **Critical Path**: Tasks executed according to dependency analysis
- **Documentation**: Journal entries created for all significant completions
- **Backup Strategy**: Timestamped backups maintained for recovery

---

## 38.0 5-Level RCA Methodology (TPS Integration)

### 38.1 RCA Trigger Conditions
Execute 5-Level RCA for:
- Any compilation error that persists after first fix attempt
- Any validation consensus failure
- Any STAMP constraint violation
- Any container or infrastructure failure
- Any agent coordination deadlock

### 38.2 5-Level Analysis Framework

**Level 1: Surface Problem**
- What is the immediate symptom?
- When did it first occur?
- What changed recently?

**Level 2: Proximate Cause**
- What directly triggered the symptom?
- What code/configuration is involved?
- What error messages are present?

**Level 3: Contributing Factors**
- What conditions enabled the problem?
- What process gaps exist?
- What monitoring was missing?

**Level 4: Systemic Issues**
- What architectural patterns are involved?
- What design decisions contributed?
- What organizational factors exist?

**Level 5: Root Cause**
- What is the fundamental origin?
- What prevention measures are needed?
- What systemic changes are required?

### 38.3 RCA Command
```bash
elixir scripts/analysis/five_level_rca_analyzer.exs --issue-type TYPE --incident-id ID
```

---

## 39.0 Jidoka (Autonomation) Principles

### 39.1 Automatic Problem Detection
The system MUST automatically detect:
- Compilation errors and warnings
- Test failures
- STAMP constraint violations
- Container health issues
- Agent coordination failures
- PHICS synchronization failures

### 39.2 Automatic Stop
Upon detection of critical issues, the system MUST:
1. Halt the current operation immediately
2. Preserve the current state for analysis
3. Log the issue with full context
4. Alert the appropriate supervisor
5. Prevent further operations until resolved

### 39.3 Quality at the Source
Each process step MUST:
- Validate its inputs before processing
- Validate its outputs before passing forward
- Report any anomalies immediately
- Maintain audit trail for all operations

---

## 40.0 Continuous Improvement (Kaizen)

### 40.1 Daily Improvement Cycle
```
Plan → Do → Check → Act (PDCA)
```

- **Plan**: Identify improvement opportunities from daily operations
- **Do**: Implement small, focused improvements
- **Check**: Validate improvement effectiveness
- **Act**: Standardize successful improvements

### 40.2 Improvement Categories

| Category | Focus | Examples |
|----------|-------|----------|
| Process | Workflow efficiency | Reduce compilation time |
| Quality | Defect prevention | Improve FPPS accuracy |
| Safety | Constraint enhancement | Add new STAMP constraints |
| Performance | Speed optimization | Reduce container startup |
| Observability | Monitoring improvement | Add telemetry events |

### 40.3 Improvement Documentation
All improvements MUST be documented in `docs/journal/` with:
- Problem statement
- Analysis performed
- Solution implemented
- Results measured
- Standard work updated

---

## 41.0 Poka-Yoke (Error Proofing)

### 41.1 Error Prevention Mechanisms

**Compilation Error Prevention**:
- Mandatory `--warnings-as-errors` flag
- Pre-compilation syntax validation
- Dependency conflict detection
- Module definition uniqueness check

**Validation Error Prevention**:
- Mandatory 5-method consensus
- Automatic method calibration
- Drift detection monitoring
- False positive prevention

**Container Error Prevention**:
- Registry source validation
- Health check requirements
- Resource limit enforcement
- Network isolation verification

### 41.2 Error Detection Mechanisms

**Immediate Detection**:
- Real-time compilation output monitoring
- Live FPPS consensus checking
- Container health polling
- Agent heartbeat monitoring

**Periodic Detection**:
- Daily validation audits
- Weekly STAMP compliance checks
- Monthly performance baselines
- Quarterly security assessments

---

## 42.0 Standardization and Calibration

### 42.1 Standard Work Definitions

All operations MUST follow documented standards:
- Patient Mode compilation (Axiom 1)
- Container isolation (Axiom 2)
- Zero-defect quality (Axiom 3)
- Test-driven generation (Axiom 4)
- Validation consensus (Axiom 5)

### 42.2 Calibration Requirements

**FPPS Method Calibration**:
- Daily calibration check against known test cases
- Weekly cross-method consistency validation
- Monthly accuracy assessment against ground truth

**Container Calibration**:
- Resource allocation validation
- Network latency measurement
- PHICS synchronization timing

### 42.3 Standard Work Updates
When standards are updated:
1. Document the change in journal
2. Update CLAUDE.md
3. Update relevant scripts
4. Notify all agents
5. Validate new standard

---

## 43.0 Hybrid AI/ML Integration Details

### 43.1 Nx (Numerical Elixir) Integration

```elixir
defmodule Indrajaal.AI.NxProcessor do
  require Nx

  def process_tensor(data) do
    data
    |> Nx.tensor()
    |> Nx.reshape({:auto, 1})
    |> apply_model()
    |> Nx.to_flat_list()
  end

  defp apply_model(tensor) do
    tensor
    |> Axon.Layers.dense(128)
    |> Axon.Activations.relu()
    |> Axon.Layers.dense(64)
    |> Axon.Activations.softmax()
  end
end
```

### 43.2 Mojo Integration

```elixir
defmodule Indrajaal.AI.MojoGateway do
  @mojo_endpoint "http://localhost:8081/inference"

  def inference(input) do
    case Req.post(@mojo_endpoint, json: %{input: input}) do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 43.3 Routing Logic

```elixir
defmodule Indrajaal.AI.Router do
  @latency_threshold_ms 100

  def route(task) do
    estimated_latency = estimate_latency(task)

    if estimated_latency < @latency_threshold_ms do
      {:nx, Indrajaal.AI.NxProcessor.process(task)}
    else
      {:mojo, Indrajaal.AI.MojoGateway.inference(task)}
    end
  end

  defp estimate_latency(task) do
    # Estimate based on task complexity
    task.complexity_score * 10
  end
end
```

---

## 44.0 SIA DC-09 Alarm Protocol

### 44.1 Protocol Overview
SIA DC-09 is the industry standard for alarm monitoring communication.

**Port**: 3061 (UDP/TCP)
**Container**: alarms

### 44.2 Message Format
```
<LF><crc><0LLL><ACCT>|DATA<CR>
```

- LF: Line Feed (0x0A)
- crc: 4-character CRC
- LLL: Message length (3 digits)
- ACCT: Account number
- DATA: Event data
- CR: Carriage Return (0x0D)

### 44.3 Event Codes
| Code | Description |
|------|-------------|
| BA | Burglary Alarm |
| BR | Burglary Restore |
| FA | Fire Alarm |
| FR | Fire Restore |
| PA | Panic Alarm |
| MA | Medical Alarm |
| TA | Tamper |
| TR | Tamper Restore |

---

## 45.0 Observability OpenTelemetry Integration

### 45.1 Required Modules
```elixir
# These 4 OTEL modules MUST be loaded:
OpentelemetryPhoenix
OpentelemetryEcto
OpentelemetryOban
OpentelemetryFinch
```

### 45.2 Telemetry Configuration
```elixir
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"
```

### 45.3 Custom Spans
```elixir
require OpenTelemetry.Tracer, as: Tracer

def critical_operation do
  Tracer.with_span "indrajaal.critical_operation" do
    Tracer.set_attribute("operation.type", "compilation")
    Tracer.set_attribute("patient_mode", true)

    perform_operation()

    Tracer.add_event("operation.completed", %{
      success: true,
      duration_ms: elapsed
    })
  end
end
```

### 45.4 Health Check Telemetry
```elixir
:telemetry.execute(
  [:indrajaal, :health_check, :complete],
  %{duration: duration_ms, status: status},
  %{container: container, check_type: type}
)
```

---

## 46.0 Complete Script Reference

### 46.1 Validation Scripts
| Script | Purpose |
|--------|---------|
| `comprehensive_compilation_validator.exs` | FPPS 5-method validation |
| `daily_validation_audit.exs` | Daily audit checks |
| `unified_validation_command_center.exs` | Central command interface |
| `incremental_fix_prerequisite_validator.exs` | Pre-fix validation |
| `intelligent_batch_planner.exs` | Fix batch planning |
| `automated_fix_executor.exs` | Automated fix application |
| `emergency_rollback_system.exs` | Emergency rollback |
| `simple_tdd_test_validator.exs` | TDD test validation |

### 46.2 Container Scripts
| Script | Purpose |
|--------|---------|
| `verified_nixos_setup.exs` | Container environment setup |
| `podman_direct_manager.exs` | Podman management |
| `setup_phoenix_container.exs` | Phoenix container setup |
| `smart_container_orchestrator.exs` | Container orchestration |

### 46.3 Coordination Scripts
| Script | Purpose |
|--------|---------|
| `multi_agent_coordinator.exs` | 50-agent coordination |
| `autonomous_compilation_engine.exs` | Autonomous compilation |
| `ultimate_15_agent_10_container_autonomous_executor.exs` | Full system execution |
| `agent_efficiency_monitor.exs` | Agent efficiency tracking |

### 46.4 Analysis Scripts
| Script | Purpose |
|--------|---------|
| `ast_compilation_fixer.exs` | AST-based fix analysis |
| `five_level_rca_analyzer.exs` | 5-Level RCA |
| `comprehensive_error_pattern_database.exs` | Error pattern database |

### 46.5 STAMP Scripts
| Script | Purpose |
|--------|---------|
| `integrated_stamp_safety_implementation.exs` | STAMP implementation |
| `stpa_template_generator.exs` | STPA templates |
| `cast_template_generator.exs` | CAST templates |
| `stpa_validator.exs` | STPA validation |
| `cast_validator.exs` | CAST validation |

---

## 47.0 Appendix A: Glossary

| Term | Definition |
|------|------------|
| **AEE** | Autonomous Execution Engine |
| **CAST** | Causal Analysis using System Theory |
| **FPPS** | Five-Point Pattern System (5-method validation) |
| **GDE** | Goal-Driven Execution |
| **LTL** | Linear Temporal Logic |
| **PHICS** | Phoenix Hot-Reloading Integration Container System |
| **RCA** | Root Cause Analysis |
| **SOPv5.11** | Standard Operating Procedure version 5.11 |
| **STAMP** | Systems-Theoretic Accident Model and Processes |
| **STPA** | System-Theoretic Process Analysis |
| **TDG** | Test-Driven Generation |
| **TPS** | Toyota Production System |

---

## 48.0 Appendix B: Mathematical Notation Summary

### Quantifiers
- $\forall$ - For all (universal)
- $\exists$ - There exists (existential)

### Logical Operators
- $\wedge$ - AND
- $\vee$ - OR
- $\neg$ - NOT
- $\implies$ - Implies
- $\iff$ - If and only if

### Set Operations
- $\in$ - Member of
- $\cup$ - Union
- $\cap$ - Intersection
- $\subseteq$ - Subset
- $\emptyset$ - Empty set

### Temporal Logic
- $\Box$ - Always (globally)
- $\diamond$ - Eventually
- $\bigcirc$ - Next

### Hoare Logic
- $\{P\}$ - Precondition
- $C$ - Command
- $\{Q\}$ - Postcondition

---

## 49.0 Appendix C: Quick Command Cheat Sheet

```bash
# === COMPILATION ===
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors 2>&1 | tee -a ./data/tmp/1-compile.log

# === VALIDATION ===
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus --save-report

# === CONTAINERS ===
elixir scripts/performance/podman_direct_manager.exs --status
podman-compose -f podman-compose.yml up -d

# === TESTING ===
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test --timeout 7200000

# === QUALITY ===
mix format --check-formatted && mix credo --strict && mix dialyzer && mix sobelow --exit

# === AGENTS ===
elixir scripts/coordination/multi_agent_coordinator.exs --deploy

# === STAMP ===
elixir scripts/stamp/integrated_stamp_safety_implementation.exs --validate-all

# === EMERGENCY ===
elixir scripts/emergency/emergency_stop.exs
elixir scripts/validation/unified_validation_command_center.exs report
```

---

---

## 50.0 Appendix D: Cybernetic Feedback Loop System

### 50.1 Four Core Feedback Loops

The system operates with four integrated cybernetic feedback loops:

**Performance Loop**:
- Execution speed monitoring
- Resource efficiency tracking
- Throughput optimization
- Automatic adjustment based on metrics

**Quality Loop**:
- Error detection and correction
- Continuous improvement integration
- Pattern recognition for fixes
- Quality gate enforcement

**Learning Loop**:
- Pattern recognition from executions
- Strategy refinement based on outcomes
- Knowledge base updating
- Best practice codification

**Safety Loop**:
- Risk monitoring (72 STAMP constraints)
- Constraint validation at each phase
- Emergency response protocols
- Rollback capability maintenance

### 50.2 SOPv5.11 Cybernetic Framework Phases

**Phase 1: Pre-Flight Check & Goal Initialization**
- [ ] 1.1: Goal analysis and decomposition
- [ ] 1.2: Resource assessment and allocation
- [ ] 1.3: Risk analysis using STAMP
- [ ] 1.4: Execution strategy selection
- [ ] 1.5: Agent coordination planning

**Phase 2: In-Flight Execution & Monitoring**
- [ ] 2.1: Adaptive strategy execution
- [ ] 2.2: Quality gate checkpoints
- [ ] 2.3: Agent coordination with load balancing
- [ ] 2.4: State persistence for recovery

**Phase 3: Post-Flight Check & System Learning**
- [ ] 3.1: Goal achievement verification
- [ ] 3.2: System state integrity check
- [ ] 3.3: Performance analysis
- [ ] 3.4: Knowledge integration
- [ ] 3.5: Risk assessment update

**Phase 4: Goal Completion & Reset**
- [ ] 4.1: Achievement confirmation
- [ ] 4.2: State documentation
- [ ] 4.3: Knowledge transfer
- [ ] 4.4: System reset
- [ ] 4.5: Continuous improvement

---

## 51.0 Appendix E: Robust Todolist Management

### 51.1 Architecture

**PRIMARY COMPONENTS**:
1. `PROJECT_TODOLIST.md` - Human-readable with git tracking
2. `scripts/planning/todolist_manager.exs` - Automated management
3. `backups/todolist/` - Timestamped disaster recovery
4. `docs/journal/` - Progress documentation
5. Git integration - Complete audit trail

### 51.2 Daily Workflow Commands

```bash
# Session start (MANDATORY)
elixir scripts/planning/todolist_manager.exs --status

# Task management
elixir scripts/planning/todolist_manager.exs --update TASK_ID STATUS

# End of work (MANDATORY)
elixir scripts/planning/todolist_manager.exs --backup
elixir scripts/planning/todolist_manager.exs --sync
elixir scripts/planning/todolist_manager.exs --validate
```

### 51.3 Status Values

| Status | Description | Constraint |
|--------|-------------|------------|
| `pending` | Not started | Default |
| `in_progress` | Currently active | ONLY ONE at a time |
| `completed` | Successfully finished | Mark immediately |
| `blocked` | Cannot proceed | Requires intervention |

### 51.4 Zero Data Loss Guarantees

**Failure Resistance**:
- System crashes: PROJECT_TODOLIST.md persists
- Session loss: No dependency on Claude memory
- File corruption: Multiple backup layers
- Human error: Git revert capability
- Tool failure: Manual editing supported

**Enterprise Features**:
- Complete audit trail in git
- Automated timestamped backups
- Automatic journal integration
- CLAUDE.md compliance checking
- 5 independent recovery mechanisms

### 51.5 Forbidden Practices

1. **TodoRead/TodoWrite ONLY**: Session memory volatile
2. **Manual synchronization**: Error-prone
3. **No backup strategy**: Single point of failure
4. **Tool dependency**: Claude Code tools exclusively
5. **No recovery plan**: Cannot restore after failure

---

## 52.0 Appendix F: SigNoz Observability Integration

### 52.1 Dual Logging Requirements

**MANDATORY STANDARDS**:
1. ALL logs appear in BOTH terminal AND SigNoz
2. ALL requests generate distributed traces
3. ALL domains have custom telemetry
4. ALL domains have SigNoz dashboards
5. ALL business metrics tracked

### 52.2 OpenTelemetry Instrumentation

```elixir
def start(_type, _args) do
  # 1. Core telemetry
  Indrajaal.Telemetry.attach_handlers()

  # 2. OpenTelemetry libraries - MUST use CamelCase modules
  if Code.ensure_loaded?(OpentelemetryPhoenix), do: OpentelemetryPhoenix.setup()
  if Code.ensure_loaded?(OpentelemetryEcto), do: OpentelemetryEcto.setup([:indrajaal, :repo], db_statement: :enabled)
  if Code.ensure_loaded?(OpentelemetryOban), do: OpentelemetryOban.setup(trace: [:jobs])
  if Code.ensure_loaded?(OpentelemetryFinch), do: OpentelemetryFinch.setup()

  # 3. Domain instrumentation
  Indrajaal.Observability.Domains.Alarms.setup()

  # 4. Dual logging validation
  :ok = Indrajaal.Observability.DualLogging.validate_dual_logging!()
end
```

### 52.3 Health Check System (SC-OBS-065 to SC-OBS-072)

```elixir
# One-time verification
Indrajaal.Observability.InstrumentationHealth.verify_all()

# Periodic check (every 5 minutes)
Indrajaal.Observability.InstrumentationHealth.start_periodic_check()

# Detailed status
Indrajaal.Observability.InstrumentationHealth.health_status()
```

**Modules Checked**:
- `OpentelemetryPhoenix` - HTTP tracing
- `OpentelemetryEcto` - Database tracing
- `OpentelemetryOban` - Job tracing
- `OpentelemetryFinch` - Client tracing
- `DualLogging` - Terminal + SigNoz
- `LoggerTraceContext` - Trace injection
- `TelemetryEnhancement` - Handlers

### 52.4 Dashboard Commands

```bash
# Create all dashboards (MANDATORY after deployment)
elixir scripts/observability/dashboards/create_signoz_dashboards.exs

# Validate dashboards exist
elixir scripts/observability/dashboards/create_signoz_dashboards.exs --validate
```

### 52.5 Daily Validation

```bash
# Verify dual logging
mix run -e "Indrajaal.Observability.DualLogging.validate_dual_logging!()"

# Check trace generation
curl http://localhost:4000/health -H "X-Test-Trace: true"

# Validate domain instrumentation
elixir scripts/observability/validate_instrumentation.exs --all-domains
```

---

## 53.0 Appendix G: Hierarchical Numbering System

### 53.1 Numbering Levels

| Level | Format | Example | Usage |
|-------|--------|---------|-------|
| 1 | X.0 | 1.0, 2.0 | Major Categories |
| 2 | X.Y | 1.1, 1.2 | Major Tasks |
| 3 | X.Y.Z | 1.1.1 | Sub-tasks |
| 4 | X.Y.Z.A | 1.1.1.1 | Implementation Steps |
| 5 | X.Y.Z.A.B | 1.1.1.1.1 | Micro-tasks |

### 53.2 Standardized Categories

- **1.0** - Development & Implementation
- **2.0** - Testing & Quality Assurance
- **3.0** - Documentation & Training
- **4.0** - Infrastructure & Deployment
- **5.0** - Security & Compliance
- **6.0** - Performance & Optimization
- **7.0** - Maintenance & Operations
- **8.0** - Research & Investigation
- **9.0** - Emergency & Critical Fixes

### 53.3 Forbidden Practices

1. Non-hierarchical numbering
2. Inconsistent numbering schemes
3. Missing parent references
4. Invalid rollup logic
5. Bypassing numbering requirements

---

## 54.0 Appendix H: Container Policy Compliance

### 54.1 NixOS Container Rules

**Execution Pattern**:
```bash
nix-shell -p podman --run "podman exec indrajaal-demo sh -c 'cd /workspace && [COMMAND]'"
```

**Required Setup**:
- NixOS 25.05 containers ONLY
- Registry: `localhost/` EXCLUSIVELY
- Podman 5.4.1 via DevEnv/Nix
- PHICS hot-reloading enabled
- Image validation MANDATORY

### 54.2 Allowed Images (EXHAUSTIVE)

```bash
localhost/indrajaal-app:nixos-devenv
localhost/indrajaal-postgres:nixos
localhost/indrajaal-redis:nixos
localhost/indrajaal-signoz:nixos
```

### 54.3 Forbidden Registries

| Registry | Status | Violation |
|----------|--------|-----------|
| docker.io | BANNED | CRITICAL |
| registry.nixos.org | BANNED | CRITICAL |
| quay.io | BANNED | CRITICAL |
| ghcr.io | BANNED | CRITICAL |
| Alpine | BANNED | CRITICAL |
| Ubuntu | BANNED | CRITICAL |

### 54.4 Validation Commands

```bash
# Comprehensive policy validation
elixir scripts/validation/container_policy_validator.exs --comprehensive

# Strict compliance check
elixir scripts/validation/container_policy_validator.exs --strict

# Container setup (validated)
elixir scripts/containers/setup_nixos_container.exs
```

---

## 55.0 Appendix I: Timeout Configuration

### 55.1 Standard Timeouts

| Operation | Timeout | Environment Variable |
|-----------|---------|---------------------|
| Compilation | 20 min | `COMPILE_TIMEOUT=1200000` |
| Testing | 20 min | `TEST_TIMEOUT=1200000` |
| Container Ops | 15 min | `CONTAINER_TIMEOUT=900000` |
| File Operations | 20 min | `FILE_OPERATION_TIMEOUT=1200000` |

### 55.2 Claude Code API Timeouts

| Component | Default | Max | Variable |
|-----------|---------|-----|----------|
| Bash | 10 min | 15 min | `BASH_DEFAULT_TIMEOUT_MS` |
| MCP Server | 5 min | - | `MCP_TIMEOUT` |
| MCP Tools | 30 min | - | `MCP_TOOL_TIMEOUT` |

### 55.3 Configuration Commands

```bash
# Load configuration
elixir scripts/config/timeout_configuration.exs --setup

# Validate settings
elixir scripts/config/timeout_configuration.exs --validate

# View summary
elixir scripts/config/timeout_configuration.exs --summary
```

### 55.4 Patient Supervisor Config

- **VM**: 4M processes, 256 threads, 256 schedulers
- **11-Agent Setup**: 1 Supervisor + 4 Helpers + 6 Workers
- **Container Limits**: 11.5 CPUs, 58GB memory
- **Timeout**: 1200s (20 min) with 15 retries

---

## 56.0 Appendix J: Zero-Warning Compilation

### 56.1 Mandatory Rules

1. ALL compilations use `--warnings-as-errors`
2. NO disabling of warnings-as-errors
3. SYSTEMATIC warning elimination required
4. TPS methodology applied for fixes
5. Pattern-based resolution documented

### 56.2 Warning Elimination Workflow

```bash
# Pattern identification
mix compile --warnings-as-errors

# Apply TPS methodology
# Document patterns (WP001, WP002, etc.)
# Validate complete elimination
```

### 56.3 Quality Standards

- Zero warnings required
- Enterprise-grade code quality
- Systematic pattern resolution
- TPS methodology compliance

### 56.4 Success Criteria

- Mix compilation without warnings
- All patterns (WP001-WP999) resolved
- Phoenix startup zero warnings
- Enterprise standards maintained

---

## 57.0 Appendix K: AEE SOPv5.11 Operating Model

### 57.1 Required Execution

1. **Patient Mode Protocol**: `NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16"`
2. **Cybernetic Framework**: SOPv5.11 with 15-agent coordination
3. **Zero Manual Intervention**: Autonomous with systematic resolution
4. **Comprehensive Analysis**: All outputs analyzed
5. **5-Level RCA**: Mandatory for discrepancies
6. **STAMP Compliance**: Throughout execution

### 57.2 Mandatory Command

```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --verbose 2>&1 | tee -a 1-compile.log
```

### 57.3 Analysis Workflow

1. Execute with Patient Mode Protocol
2. Allow natural completion (no timeouts)
3. Analyze complete log systematically
4. Run false positive prevention
5. Compare using 5-Level RCA
6. Resolve all discrepancies

### 57.4 Forbidden Behaviors

1. Manual compilation without AEE
2. Non-Patient Mode execution
3. Bypassing analysis
4. Ignoring discrepancies
5. Non-SOPv5.11 operations

---

## 58.0 Appendix L: Emergency Response Procedures

### 58.1 Patient Mode Violations

**Response Protocol**:
1. IMMEDIATE STOP
2. PROTOCOL RESET to patient mode
3. COMPREHENSIVE RESTART
4. DOCUMENTATION UPDATE
5. VALIDATION before proceeding

### 58.2 Observability Failures

**Response Protocol**:
1. CHECK both logging backends
2. VERIFY OTEL_EXPORTER_OTLP_ENDPOINT
3. RESTART with proper environment
4. VALIDATE dual logging
5. ESCALATE if issues persist (P1)

### 58.3 Container Policy Violations

**Response Protocol**:
1. STOP all container operations
2. CAST Analysis
3. FIX validation logic
4. VERIFY compliance
5. DOCUMENT incident

### 58.4 Compilation Timeout

**Response Protocol**:
1. HALT current operation
2. REVIEW timeout settings
3. APPLY patient mode protocol
4. RESTART with NO_TIMEOUT=true
5. MONITOR to completion

---

## 59.0 Appendix M: Success Metrics

### 59.1 Compilation Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Warnings | 0 | REQUIRED |
| Errors | 0 | REQUIRED |
| File Count | 773 | MONITORED |
| Completion | 100% | REQUIRED |

### 59.2 Quality Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Format Compliance | 100% | REQUIRED |
| Credo Score | A | REQUIRED |
| Test Coverage | 80%+ | MONITORED |
| Security (Sobelow) | 0 issues | REQUIRED |

### 59.3 Agent Coordination Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Efficiency | 90%+ | SC-AGT-017 |
| Deadlocks | 0 | SC-AGT-018 |
| Response Time | <50ms | SC-PRF-050 |
| PHICS Latency | <50ms | Axiom 2.6 |

### 59.4 Infrastructure Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Container Health | 100% | MONITORED |
| Resource Usage | <80% | MONITORED |
| Uptime | 99.9% | SLA |
| Recovery Time | <5s | SC-EMR-057 |

---

## 60.0 Elixir 1.19 Credo Rules (Agent Operational Rules)

### 60.1 Formal Definitions and State Space

**State Space**:
- $\mathcal{C}$ = The Codebase (Set of all `.ex`, `.exs` files)
- $\mathbf{V}(\mathcal{C})$ = Set of violations detected by Credo
- $w: \mathbf{V} \rightarrow \{1,2,3,4,5\}$ = Severity weighting function

**Severity Levels**:
| Level | Category | Description |
|-------|----------|-------------|
| 5 | Elixir 1.19 Deprecation | CRITICAL - Breaks future compatibility |
| 4 | Warning | HIGH - Potential runtime issues |
| 3 | Refactoring Opportunity | MEDIUM - Code quality improvement |
| 2 | Design Suggestion | LOW - Architectural recommendation |
| 1 | Readability | MINIMAL - Style consistency |

**Success Predicate**:
$$
\text{Success}(\mathcal{C}) \iff \left( \sum_{v \in \mathbf{V}(\mathcal{C})} w(v) \right) = 0
$$

### 60.2 Agent Operational Rules (AOR)

**AOR-1: Strictness Imperative**
$$
\forall \text{execution } e : \text{CredoFlags}(e) \supseteq \{\text{--strict}\}
$$
- **Command**: `mix credo --strict`
- **Rationale**: Enforces ALL severity levels including readability
- **Violation**: Running `mix credo` without `--strict` is FORBIDDEN

**AOR-2: Elixir 1.19 Compatibility Clause**
$$
\forall v \in \mathbf{V}(\mathcal{C}) : (\text{category}(v) = \text{"deprecation"}) \implies (w(v) = 5 \wedge \text{priority}(v) = \text{CRITICAL})
$$
- **Rationale**: Deprecation warnings break Elixir 1.19+ compatibility
- **Action**: Fix IMMEDIATELY before any other violations
- **Examples**:
  - `Logger.warn/1` → `Logger.warning/1`
  - `Enum.chunk/2` → `Enum.chunk_every/2`
  - `String.strip/1` → `String.trim/1`

**AOR-3: Formatter Precedence**
$$
\text{ExecutionOrder} = [\text{mix format}, \text{mix credo --strict}]
$$
- **Command Sequence**:
  ```bash
  mix format && mix credo --strict
  ```
- **Rationale**: Formatting fixes eliminate readability violations automatically
- **Violation**: Running Credo before formatting is INEFFICIENT

**AOR-4: Configuration over Suppression**
$$
\forall v \in \mathbf{V}(\mathcal{C}) : \text{Suppress}(v) \implies (\exists \text{justification}(v) \in \text{.credo.exs})
$$
- **Rationale**: Suppressions MUST be documented and justified
- **Location**: `.credo.exs` configuration file
- **Review**: Quarterly audit of all suppressions

### 60.3 Decision Matrix

| Violation Category | Severity | Action | Deadline |
|--------------------|----------|--------|----------|
| Deprecation Warning | 5 | Fix immediately | 0 days |
| Code Readiness | 4 | Fix before commit | 1 day |
| Refactoring Opportunity | 3 | Schedule fix | 1 week |
| Design Suggestion | 2 | Review & decide | 1 sprint |
| Readability | 1 | Fix before commit | 1 day |

### 60.4 Remediation Strategies

**High Complexity (Cognitive/Cyclomatic)**
```elixir
# BEFORE (Violation)
def process(data, opts) do
  if opts[:type] == :a do
    if opts[:mode] == :fast do
      fast_process_a(data)
    else
      slow_process_a(data)
    end
  else
    if opts[:mode] == :fast do
      fast_process_b(data)
    else
      slow_process_b(data)
    end
  end
end

# AFTER (Compliant)
def process(data, opts) do
  case {opts[:type], opts[:mode]} do
    {:a, :fast} -> fast_process_a(data)
    {:a, _} -> slow_process_a(data)
    {_, :fast} -> fast_process_b(data)
    _ -> slow_process_b(data)
  end
end
```

**Unsafe Execution (Code.eval_string)**
```elixir
# VIOLATION (FORBIDDEN)
def execute_dynamic(code_string) do
  Code.eval_string(code_string)
end

# COMPLIANT (Use macro system)
defmodule SafeExecutor do
  defmacro safe_eval(ast) do
    quote do
      unquote(ast)
    end
  end
end
```

**Module Documentation**
```elixir
# VIOLATION
defmodule MyModule do
  def my_function, do: :ok
end

# COMPLIANT
defmodule MyModule do
  @moduledoc """
  MyModule handles specific business logic for XYZ feature.

  ## Examples

      iex> MyModule.my_function()
      :ok
  """

  @doc """
  Performs the primary operation.

  ## Examples

      iex> MyModule.my_function()
      :ok
  """
  def my_function, do: :ok
end
```

**Alias Usage**
```elixir
# VIOLATION
defmodule MyApp.Feature do
  def process do
    MyApp.Service.DataProcessor.process()
    MyApp.Service.DataValidator.validate()
    MyApp.Service.DataTransformer.transform()
  end
end

# COMPLIANT
defmodule MyApp.Feature do
  alias MyApp.Service.{DataProcessor, DataValidator, DataTransformer}

  def process do
    DataProcessor.process()
    DataValidator.validate()
    DataTransformer.transform()
  end
end
```

### 60.5 Execution Command Sequence (MANDATORY)

```bash
# Daily Development Workflow
mix format --check-formatted  # Step 1: Verify formatting
mix format                     # Step 2: Auto-format if needed
mix credo --strict             # Step 3: Run strict analysis
mix dialyzer                   # Step 4: Type checking
mix test                       # Step 5: Test execution

# Pre-Commit Validation (MANDATORY)
mix format && mix credo --strict && mix dialyzer && mix test

# CI/CD Pipeline (MANDATORY)
mix format --check-formatted && mix credo --strict --mute-exit-status && mix dialyzer && mix test --cover
```

### 60.6 .credo.exs Configuration Template

```elixir
# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          # Consistency Checks
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Design Checks
          {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Design.TagTODO, [exit_status: 0]},

          # Readability Checks
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring Opportunities
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]},
          {Credo.Check.Refactor.FunctionArity, [max_arity: 8]},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          # Warning Checks
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.UnsafeExec, []},

          # Elixir 1.19 Deprecation Checks (CRITICAL)
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Refactor.MapInto, []}
        ],
        disabled: [
          # Disabled with justification
          {Credo.Check.Readability.Specs, false},  # Dialyzer handles type specs
          {Credo.Check.Refactor.ABCSize, false}    # Covered by CyclomaticComplexity
        ]
      }
    }
  ]
}
```

### 60.7 Integration with CLAUDE.md Standards

**Alignment with Existing Axioms**:
- **Axiom 3 (Zero-Defect Quality)**: Credo violations count toward quality metrics
- **AOR-3 (Formatter Precedence)**: Integrates with Section 3.0 quality validation
- **AOR-1 (Strictness)**: Enforces same zero-tolerance policy as compilation

**Quality Gate Integration**:
```bash
# Updated Pre-Commit Command (Section 3.0)
mix format --check-formatted && \
mix credo --strict && \
mix dialyzer && \
mix sobelow --exit && \
mix test --coverage
```

**STAMP Safety Constraint Addition**:
- **SC-QUA-073**: System SHALL pass `mix credo --strict` with zero violations
- **SC-QUA-074**: System SHALL fix Elixir 1.19 deprecations with CRITICAL priority
- **SC-QUA-075**: System SHALL document all Credo suppressions in `.credo.exs`

### 60.8 Daily Credo Workflow (MANDATORY)

```bash
# Morning validation
mix format && mix credo --strict

# Before each commit
mix format && mix credo --strict

# Before push
mix format --check-formatted && mix credo --strict

# Weekly audit
mix credo --strict --all --format json > credo_report.json
```

### 60.9 Violation Priority Queue

**Execution Order** (MANDATORY):
1. **Priority 5**: Elixir 1.19 deprecations (fix immediately)
2. **Priority 4**: Warnings (fix before commit)
3. **Priority 1**: Readability (fix before commit via `mix format`)
4. **Priority 3**: Refactoring opportunities (schedule)
5. **Priority 2**: Design suggestions (review)

**Command**:
```bash
# Generate priority-sorted report
mix credo --strict --format flycheck | sort -t: -k3 -rn
```

---

## 61.0 Agent Operating Rules (AOR) Framework

### 61.1 Framework Overview

The Agent Operating Rules (AOR) framework provides formal behavioral specifications for the 50-agent architecture using deontic logic, temporal logic (LTL), and Hoare logic protocols.

**Framework Integration**:
- **Deontic Logic**: Obligation ($\mathbf{O}$), Permission ($\mathbf{P}$), Prohibition ($\mathbf{F}$)
- **STAMP Integration**: 70 AOR rules map to 75 STAMP safety constraints
- **TDG Compliance**: 327 tests with dual property testing (PropCheck + ExUnitProperties)
- **Observability**: Full telemetry integration with dual logging

### 61.2 Deontic Logic Operators

| Operator | Symbol | Meaning | Usage |
|----------|--------|---------|-------|
| Obligation | $\mathbf{O}_a(\phi)$ | Agent $a$ MUST do $\phi$ | SHALL |
| Permission | $\mathbf{P}_a(\phi)$ | Agent $a$ MAY do $\phi$ | MAY |
| Prohibition | $\mathbf{F}_a(\phi)$ | Agent $a$ MUST NOT do $\phi$ | SHALL NOT |

**Deontic Axioms**:
- **D1**: $\mathbf{O}(\phi) \equiv \neg \mathbf{P}(\neg \phi)$ (Obligation-Permission Duality)
- **D2**: $\mathbf{F}(\phi) \equiv \neg \mathbf{P}(\phi)$ (Prohibition-Permission Duality)
- **D3**: $\mathbf{O}(\phi) \implies \mathbf{P}(\phi)$ (Obligation Implies Permission)
- **D4**: $\neg (\mathbf{O}(\phi) \wedge \mathbf{O}(\neg \phi))$ (No Conflicting Obligations)
- **D5**: $\text{Authority}(a_1) > \text{Authority}(a_2) \implies (\mathbf{O}_{a_1}(\phi) \implies \mathbf{O}_{a_2}(\phi))$ (Authority Inheritance)

### 61.3 Agent State Machine ($\mathcal{M}_{agent}$)

**States** ($\mathcal{Q}$):
$$\mathcal{Q}_{agent} = \{idle, active, blocked, error, recovering, suspended, terminated\}$$

**Events** ($\Sigma$):
$$\Sigma = \{assign, complete, fail, suspend, resume, terminate, recover, escalate, timeout, emergency\_stop\}$$

**Key Transitions**:
| Current State | Event | New State |
|---------------|-------|-----------|
| idle | assign | active |
| active | complete | idle |
| active | fail | error |
| error | recover | recovering |
| recovering | complete | idle |
| ANY | emergency_stop | terminated |

### 61.4 AOR Rule Categories (70 Rules)

| Category | Code | Count | Focus | STAMP Mapping |
|----------|------|-------|-------|---------------|
| Executive | AOR-EXE | 8 | Authority, delegation, emergency | SC-AGT-019, SC-EMR-057 |
| Supervisor | AOR-SUP | 12 | Coordination, escalation, domain | SC-AGT-017-024 |
| Worker | AOR-WRK | 10 | Task execution, validation, reporting | SC-AGT-022-024 |
| Communication | AOR-COM | 8 | Protocols, acknowledgment, telemetry | SC-OBS-065-072 |
| Safety | AOR-SAF | 10 | Halting, consensus, recovery | SC-VAL-*, SC-EMR-* |
| Quality | AOR-QUA | 8 | Compilation, testing, coverage | SC-CMP-025-035 |
| Container | AOR-CNT | 6 | Podman, registry, isolation | SC-CNT-009-016 |
| Temporal | AOR-TMP | 8 | Sequencing, timeouts, deadlines | SC-PRF-049-056 |
| **Agent Code** | **AOR-AGT** | **6** | **Code generation, validation, delivery** | **SC-AGT-025-030** |

### 61.5 Critical AOR Rules

**AOR-EXE-001: Supreme Authority**
```
Formal: O_EXE(forall a in A_50 \ {EXE} : Authority(EXE) > Authority(a))
Natural: Executive Director SHALL have supreme authority over all other agents
STAMP: SC-AGT-019
Severity: CRITICAL
```

**AOR-SAF-001: Halt on STAMP Violation**
```
Formal: O(Violated(SC) -> Eventually_{<1s} Halt() and Report(SC))
Natural: All agents SHALL halt within 1s on STAMP violation
STAMP: ALL SC-*
LTL: Always(STAMPViolation -> Eventually_{<1s} Halted)
Severity: CRITICAL
```

**AOR-SAF-002: FPPS Consensus**
```
Formal: O(Validation -> Consensus(all_5_methods))
Natural: Validation SHALL achieve consensus across all 5 FPPS methods
STAMP: SC-VAL-003
Severity: CRITICAL
```

**AOR-SAF-003: Patient Mode Compliance**
```
Formal: O(Compilation -> PatientMode)
Natural: All compilation SHALL use Patient Mode
STAMP: SC-VAL-001
Severity: CRITICAL
```

**AOR-CNT-001: Podman-Only Execution**
```
Formal: F(UseDocker) and O(UsePodman)
Natural: Agents SHALL use Podman, SHALL NOT use Docker
STAMP: SC-CNT-009
Severity: CRITICAL
```

**AOR-WRK-009: TDG Compliance**
```
Formal: O_WRK(GenerateCode(c) -> exists t : TestExists(c) and Created(t) < Created(c))
Natural: Workers SHALL ensure tests exist before generating code
STAMP: Axiom 4 (TDG)
Severity: CRITICAL
```

**AOR-QUA-001: Zero Warnings Compilation**
```
Formal: O(Compilation -> Warnings = 0)
Natural: Compilation SHALL produce zero warnings
STAMP: SC-CMP-025
Severity: CRITICAL
```

### 61.5.1 Agent Code Quality Rules (AOR-AGT-001 to AOR-AGT-006)

**AOR-AGT-001: Compilation Gate**
```
Formal: O(CodeGenerated(c) -> CompileSuccess(c) before TaskComplete)
Natural: Agent code MUST compile without errors before task completion
STAMP: SC-AGT-025
Severity: CRITICAL (blocks delivery)
```

**AOR-AGT-002: Warning-Free Code**
```
Formal: O(CodeGenerated(c) -> Warnings(c) = 0)
Natural: Agent code SHOULD compile without warnings
STAMP: SC-AGT-026
Severity: HIGH (allows delivery with documentation)
```

**AOR-AGT-003: Domain Registration**
```
Formal: O(NewResource(r) -> Registered(r, Domain(r)))
Natural: New resources MUST be registered in their domains
STAMP: SC-AGT-027
Severity: CRITICAL (blocks delivery)
Auto-Fix: Yes
```

**AOR-AGT-004: Action Atomicity**
```
Formal: O(UpdateAction(a) AND FunctionChange(a) -> RequireAtomicFalse(a))
Natural: Update actions with function-based changes MUST have require_atomic? false
STAMP: SC-AGT-028
Severity: CRITICAL (causes runtime errors)
Auto-Fix: Yes
```

**AOR-AGT-005: BaseResource Analysis**
```
Formal: O(GenerateCodeInterface(c) -> AnalyzeBaseResource(c) before Generate)
Natural: Agent MUST analyze BaseResource before generating code_interface definitions
STAMP: SC-AGT-027
Severity: HIGH (prevents duplicates)
```

**AOR-AGT-006: Library API Versions**
```
Formal: O(UseLibraryAPI(api) -> CurrentVersion(api))
Natural: Agent MUST use current library API versions (not deprecated)
STAMP: SC-AGT-028
Severity: MEDIUM (may cause warnings or runtime issues)
```

**AOR-AGT Enforcement Matrix**:
| Rule | Enforcement Point | Severity | Auto-Fix |
|------|-------------------|----------|----------|
| AOR-AGT-001 | Pre-delivery | CRITICAL | No |
| AOR-AGT-002 | Pre-delivery | HIGH | Partial |
| AOR-AGT-003 | Post-generation | CRITICAL | Yes |
| AOR-AGT-004 | Post-generation | CRITICAL | Yes |
| AOR-AGT-005 | Pre-generation | HIGH | Yes |
| AOR-AGT-006 | Post-generation | MEDIUM | Partial |

### 61.6 LTL Properties for Agent Behavior

**Agent Safety (AOR-LTL-S1 to AOR-LTL-S6)**:
- AOR-LTL-S1: Always NOT(state(a) = error AND NOT notified(supervisor(a)))
- AOR-LTL-S2: Always NOT(exists a_1, a_2: conflicting_access(a_1, a_2, r))
- AOR-LTL-S3: Always NOT(exists cycle: forall a in cycle: waiting(a, next(a))) (No deadlock)
- AOR-LTL-S4: Always(error_count(a) > threshold implies Eventually_{<5s} terminated(a))
- AOR-LTL-S5: Always(directive(s,a) implies Eventually_{<1s} acknowledged(a,s))
- AOR-LTL-S6: Always(K_a(state(a)=q) iff state(a)=q) (State consistency)

**Agent Liveness (AOR-LTL-L1 to AOR-LTL-L4)**:
- AOR-LTL-L1: Always(task_assigned(a,t) implies Eventually(completed(t) or failed(t)))
- AOR-LTL-L2: Always(state(a)=recovering implies Eventually(state(a)=idle or state(a)=terminated))
- AOR-LTL-L3: Always(coordination_requested(a_1,a_2) implies Eventually coordination_established(a_1,a_2))
- AOR-LTL-L4: Always(holding(a,r) implies Eventually released(a,r))

### 61.7 Hoare Logic Protocols

**Task Assignment Protocol**:
```
{Pre: state(a) = idle AND authorized(s,a) AND compatible(t, capabilities(a))}
TaskAssignment(supervisor s, agent a, task t)
{Post: state(a) = active AND assigned(a,t) AND K_a(t) AND K_s(assigned(a,t))}
```

**Error Escalation Protocol**:
```
{Pre: state(a) = error AND severity(e) >= critical AND NOT escalated(e)}
ErrorEscalation(agent a, error e, supervisor s)
{Post: K_s(e) AND escalated(e) AND logged(e) AND recovery_initiated(a)}
```

**Graceful Termination Protocol**:
```
{Pre: state(a) != terminated AND authorized(requester, terminate(a))}
GracefulTermination(agent a, reason r)
{Post: state(a) = terminated AND forall t: (completed(t) or reassigned(t)) AND forall r: released(r)}
```

### 61.8 Conflict Resolution Hierarchy

**Priority Order** (Higher wins):
1. **Safety (AOR-SAF-*)**: Safety always overrides all other rules
2. **Executive (AOR-EXE-*)**: Executive authority
3. **Quality (AOR-QUA-*)**: Quality requirements
4. **Container (AOR-CNT-*)**: Infrastructure constraints
5. **Temporal (AOR-TMP-*)**: Sequencing requirements
6. **Supervisor (AOR-SUP-*)**: Coordination rules
7. **Communication (AOR-COM-*)**: Protocol rules
8. **Worker (AOR-WRK-*)**: Operational rules

**Modality Order**: Prohibition > Obligation > Permission

### 61.9 AOR Elixir Implementation

**Module Structure**:
```
lib/indrajaal/aor/
├── types.ex                    # Type definitions
├── aor_engine.ex               # GenServer - core evaluation
├── aor_registry.ex             # ETS-backed rule storage
├── aor_validator.ex            # Runtime compliance checker
├── aor_conflict_resolver.ex    # Conflict resolution
├── aor_telemetry.ex            # Observability integration
└── rules/
    ├── executive_rules.ex      # AOR-EXE-001 to AOR-EXE-008
    ├── supervisor_rules.ex     # AOR-SUP-001 to AOR-SUP-012
    ├── worker_rules.ex         # AOR-WRK-001 to AOR-WRK-010
    ├── safety_rules.ex         # AOR-SAF-001 to AOR-SAF-010
    ├── quality_rules.ex        # AOR-QUA-001 to AOR-QUA-008
    ├── container_rules.ex      # AOR-CNT-001 to AOR-CNT-006
    ├── communication_rules.ex  # AOR-COM-001 to AOR-COM-008
    └── temporal_rules.ex       # AOR-TMP-001 to AOR-TMP-008
```

**Core API**:
```elixir
# Before action evaluation
Indrajaal.AOR.Engine.evaluate_before_action(agent_id, action, params)
# Returns: :allow | :deny | {:conditional, requirements}

# After action verification
Indrajaal.AOR.Engine.verify_after_action(agent_id, action, params, result)
# Returns: {:ok, report} | {:violation, violation}

# Rule checking
Indrajaal.AOR.Engine.check_rule(rule_id, context)
# Returns: boolean()
```

### 61.10 AOR-STAMP Integration

**Mandatory Gate**:
```elixir
@gates [:compile, :runtime, :tdg, :stamp, :fpps, :coverage, :format, :credo, :sobelow, :aor]
```

**Agent Manager Hooks**:
```elixir
# In agent_manager.ex
defp before_agent_action(agent_id, action, params) do
  Indrajaal.AOR.Engine.evaluate_before_action(agent_id, action, params)
end

defp after_agent_action(agent_id, action, params, result) do
  Indrajaal.AOR.Engine.verify_after_action(agent_id, action, params, result)
end
```

### 61.11 AOR Telemetry Events

```elixir
# AOR telemetry events (emit to both Console and SigNoz)
[:indrajaal, :aor, :evaluation, :start]
[:indrajaal, :aor, :evaluation, :stop]
[:indrajaal, :aor, :violation, :detected]
[:indrajaal, :aor, :conflict, :resolved]
[:indrajaal, :aor, :rule, :executed]
[:indrajaal, :aor, :engine, :started]
```

### 61.12 AOR Commands

```bash
# Validate all AOR rules
elixir scripts/aor/validate_all_rules.exs

# Check AOR compliance for specific agent
elixir scripts/aor/check_agent_compliance.exs --agent-id AGENT_ID

# Run AOR TDG tests
mix test test/aor/ --timeout 7200000

# Generate AOR compliance report
elixir scripts/aor/generate_compliance_report.exs --format json
```

### 61.13 Complete AOR Rule Reference

**Executive Rules (AOR-EXE-001 to AOR-EXE-008)**:
1. Supreme Authority
2. Emergency Halt Authority
3. Delegation Authority
4. Resource Override
5. System State Visibility
6. Safety Override Prohibition
7. Coordination Efficiency
8. Audit Trail Maintenance

**Supervisor Rules (AOR-SUP-001 to AOR-SUP-012)**:
1. Domain Boundary
2. Worker Supervision
3. Escalation Obligation
4. Load Distribution
5. Cross-Domain Coordination
6. Worker Recovery
7. Task Queue Management
8. Performance Reporting
9. Deadlock Prevention
10. Resource Allocation
11. Health Check Initiation
12. Graceful Degradation

**Worker Rules (AOR-WRK-001 to AOR-WRK-010)**:
1. Task Acceptance
2. Task Completion Reporting
3. Error Reporting
4. Resource Release
5. Timeout Compliance
6. State Consistency
7. Unauthorized Action Prohibition
8. Progress Reporting
9. TDG Compliance
10. Quality Gate Compliance

**Communication Rules (AOR-COM-001 to AOR-COM-008)**:
1. Message Acknowledgment
2. Directive Compliance
3. Telemetry Emission
4. Dual Logging
5. Trace Context Propagation
6. Status Broadcasting
7. Confidentiality
8. Protocol Compliance

**Safety Rules (AOR-SAF-001 to AOR-SAF-010)**:
1. Halt on STAMP Violation
2. FPPS Consensus
3. Patient Mode Compliance
4. Emergency Stop Response
5. Rollback Capability
6. Checkpoint Creation
7. Log Integrity
8. Recovery Protocol
9. Data Validation
10. Security Event Reporting

**Quality Rules (AOR-QUA-001 to AOR-QUA-008)**:
1. Zero Warnings
2. Zero Errors
3. Format Compliance
4. Credo Compliance
5. Sobelow Compliance
6. Test Coverage
7. Dual Property Testing
8. Documentation

**Container Rules (AOR-CNT-001 to AOR-CNT-006)**:
1. Podman-Only Execution
2. Localhost Registry
3. Rootless Execution
4. PHICS Latency
5. Health Check
6. Resource Isolation

**Temporal Rules (AOR-TMP-001 to AOR-TMP-008)**:
1. Task Sequencing
2. Timeout Enforcement
3. Deadline Compliance
4. Periodic Health Check
5. Acknowledgment Timeout
6. Recovery Timeout
7. Escalation Timeout
8. Checkpoint Interval

### 61.14 STAMP Safety Constraint Additions

| ID | Constraint | Category |
|----|------------|----------|
| SC-AOR-076 | System SHALL evaluate AOR rules before agent actions | Agent Safety |
| SC-AOR-077 | System SHALL verify AOR rules after agent actions | Agent Safety |
| SC-AOR-078 | System SHALL resolve AOR conflicts using priority hierarchy | Agent Safety |
| SC-AOR-079 | System SHALL emit telemetry for all AOR evaluations | Observability |
| SC-AOR-080 | System SHALL pass :aor mandatory gate | Quality |

---

## 62.0 Plan Document Management (MANDATORY RULES)

### 62.1 Plan Document Timestamping (ZERO TOLERANCE)

**Formal Definition**:
$\forall \text{plan update } u$:
$$
\text{Valid}(u) \iff \exists \tau : \text{Timestamp}(\tau) \in \text{ChangeLog}(u)
$$

**MANDATORY TIMESTAMP FORMAT**:
```
YYYYMMDD-HHMM CEST
Example: 20251208-1730 CEST
```

**MANDATORY CHANGELOG ENTRY**:
Every plan document MUST contain a `## Change Log` section with timestamped entries:
```markdown
## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20251208-1730 CEST | CREATED | Initial plan creation | Claude Code (Opus 4.5) |
| 20251208-1745 CEST | UPDATED | Added 5-level detail | Claude Code (Opus 4.5) |
```

**STAMP Constraint**:
- **SC-PLN-081**: System SHALL timestamp ALL plan document changes in YYYYMMDD-HHMM CEST format
- **SC-PLN-082**: System SHALL maintain a Change Log section in ALL plan documents
- **Violation**: Any plan update without timestamp entry is CRITICAL VIOLATION

### 62.2 Journal-on-Plan-Update Rule (MANDATORY)

**Formal Definition**:
$$
\forall \text{plan update } u : \text{Execute}(u) \implies \text{CreateJournal}(j) \wedge \text{Reference}(j, u)
$$

**MANDATORY ACTIONS**:
1. Every time a plan document is updated, a journal entry MUST be created
2. Journal entry MUST reference the plan being updated
3. Journal entry MUST document what changed and why

**JOURNAL ENTRY FORMAT**:
```
docs/journal/YYYYMMDD-HHMM-plan-update-[plan-name].md
```

**JOURNAL CONTENT TEMPLATE**:
```markdown
# Plan Update Journal Entry

**Date**: YYYYMMDD-HHMM CEST
**Plan Document**: [path to plan file]
**Update Type**: [CREATED | UPDATED | COMPLETED | ARCHIVED]
**Author**: Claude Code (Opus 4.5)

## Changes Made
[Bullet list of changes]

## Rationale
[Why changes were made]

## Impact
[What this affects]

## Verification
[How to verify the changes]
```

**STAMP Constraint**:
- **SC-PLN-083**: System SHALL create journal entry for EVERY plan document update
- **SC-PLN-084**: Journal entry SHALL use format: YYYYMMDD-HHMM-plan-update-[plan-name].md
- **Violation**: Plan update without corresponding journal entry is CRITICAL VIOLATION

### 62.3 5-Level Plan Detail (MANDATORY)

**Formal Definition**:
All plans MUST have 5 levels of hierarchical detail:
$$
\text{Plan} = \bigcup_{i=1}^{5} \text{Level}_i \quad \text{where } \text{Level}_i \subset \text{Level}_{i+1}
$$

**5-LEVEL HIERARCHY**:
| Level | Format | Description | Example |
|-------|--------|-------------|---------|
| 1 | X.0 | Strategic Objective | 1.0 - Integration Domain Completion |
| 2 | X.Y | Major Milestone | 1.1 - External Connectors Domain |
| 3 | X.Y.Z | Task Group | 1.1.1 - Webhook Implementation |
| 4 | X.Y.Z.A | Individual Task | 1.1.1.1 - Create WebhookEndpoint resource |
| 5 | X.Y.Z.A.B | Micro-task/Step | 1.1.1.1.1 - Define webhook attributes |

**CRITICALITY PRIORITIZATION**:
All tasks MUST be prioritized by criticality:
| Priority | Code | Description | Response Time |
|----------|------|-------------|---------------|
| P0 | CRITICAL | System-breaking, security | Immediate |
| P1 | HIGH | Core functionality blocked | <4 hours |
| P2 | MEDIUM | Feature incomplete | <24 hours |
| P3 | LOW | Enhancement | Next sprint |
| P4 | MINIMAL | Nice-to-have | Backlog |

**MANDATORY PLAN STRUCTURE**:
```markdown
# Plan: [Title]

**Created**: YYYYMMDD-HHMM CEST
**Last Updated**: YYYYMMDD-HHMM CEST
**Status**: [DRAFT | IN PROGRESS | COMPLETE | ARCHIVED]
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA)

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|

## Executive Summary
[Brief overview]

## 5-Level Detailed Plan

### 1.0 - [Strategic Objective] (Priority: P[X])
#### 1.1 - [Major Milestone] (Priority: P[X])
##### 1.1.1 - [Task Group] (Priority: P[X])
###### 1.1.1.1 - [Individual Task] (Priority: P[X])
- 1.1.1.1.1 - [Micro-task] (Priority: P[X])
- 1.1.1.1.2 - [Micro-task] (Priority: P[X])

## Success Criteria
[Measurable outcomes]

## Risk Assessment
[5-Level RCA if applicable]
```

**STAMP Constraints**:
- **SC-PLN-085**: System SHALL structure ALL plans with 5-level hierarchy
- **SC-PLN-086**: System SHALL assign criticality priority to ALL tasks
- **SC-PLN-087**: System SHALL include Change Log in ALL plans
- **Violation**: Plan without 5-level detail or criticality is CRITICAL VIOLATION

### 62.4 Plan Update Workflow (MANDATORY SEQUENCE)

```
┌─────────────────────────────────────────────────────────────┐
│                PLAN UPDATE WORKFLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. IDENTIFY CHANGE                                          │
│     └─► Determine what needs updating in plan               │
│                                                              │
│  2. UPDATE PLAN FILE                                         │
│     ├─► Add timestamp to Change Log                         │
│     ├─► Update relevant sections                            │
│     └─► Update "Last Updated" field                         │
│                                                              │
│  3. CREATE JOURNAL ENTRY (MANDATORY)                         │
│     ├─► Use format: YYYYMMDD-HHMM-plan-update-[name].md     │
│     ├─► Document changes made                                │
│     ├─► Document rationale                                   │
│     └─► Document verification steps                         │
│                                                              │
│  4. UPDATE TODO LIST                                         │
│     └─► Reflect plan changes in todo list                   │
│                                                              │
│  5. VERIFY                                                   │
│     └─► Confirm all artifacts synchronized                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 62.5 STAMP Safety Constraints for Plan Management

| ID | Constraint | Category | Severity |
|----|------------|----------|----------|
| SC-PLN-081 | System SHALL timestamp ALL plan changes | Documentation | CRITICAL |
| SC-PLN-082 | System SHALL maintain Change Log in plans | Documentation | CRITICAL |
| SC-PLN-083 | System SHALL create journal for plan updates | Documentation | CRITICAL |
| SC-PLN-084 | Journal SHALL use YYYYMMDD-HHMM format | Documentation | HIGH |
| SC-PLN-085 | Plans SHALL have 5-level hierarchy | Documentation | HIGH |
| SC-PLN-086 | Tasks SHALL have criticality priority | Documentation | HIGH |
| SC-PLN-087 | Plans SHALL include Change Log section | Documentation | CRITICAL |

### 62.6 Validation Commands

```bash
# Validate plan structure
elixir scripts/validation/plan_structure_validator.exs --file [plan_path]

# Check for corresponding journal entry
elixir scripts/validation/plan_journal_validator.exs --plan [plan_path] --check-journal

# Verify 5-level hierarchy
elixir scripts/validation/plan_hierarchy_validator.exs --file [plan_path] --levels 5

# Full plan compliance check
elixir scripts/validation/comprehensive_plan_validator.exs --strict
```

---

## 63.0 Database Safety Rules (SC-DB, TDG-DB, AOR-DB)

### 63.1 Overview

This section defines comprehensive safety constraints, test-driven generation rules, and agent operating rules for Ash framework and database operations. These rules ensure:
- Consistent Ash resource creation following established patterns
- Safe database migration practices
- Proper test data population and cleanup
- Agent compliance with database operations

**Implementation Modules**:
- `Indrajaal.Stamp.DatabaseSafetyConstraints` - 40 STAMP constraints (SC-DB-001 to SC-DB-040)
- `Indrajaal.TDG.DatabaseGenerationRules` - 40 TDG rules (TDG-DB-001 to TDG-DB-040)
- `Indrajaal.AOR.DatabaseAgentRules` - 32 AOR rules (AOR-DB-001 to AOR-DB-032)

### 63.2 STAMP Database Safety Constraints (SC-DB-001 to SC-DB-040)

#### Category K: Ash Resource Safety (SC-DB-001 to SC-DB-010)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DB-001 | System SHALL use BaseResource mixin for ALL Ash resources | Check for `use Indrajaal.BaseResource` | CRITICAL |
| SC-DB-002 | System SHALL use TenantResource for multi-tenant resources | Verify multitenancy configuration | CRITICAL |
| SC-DB-003 | System SHALL register ALL resources in their Ash domain | Check domain resources block | CRITICAL |
| SC-DB-004 | System SHALL use snake_case table names WITHOUT domain prefix | Verify postgres do block | HIGH |
| SC-DB-005 | System SHALL define uuid_primary_key :id for all resources | Check attributes block | CRITICAL |
| SC-DB-006 | System SHALL use timestamps() macro in attributes | Verify inserted_at/updated_at | MEDIUM |
| SC-DB-007 | System SHALL define code_interface ONLY in BaseResource | Check for duplicate definitions | HIGH |
| SC-DB-008 | System SHALL use allow_nil?: false for required attributes | Validate nil handling | HIGH |
| SC-DB-009 | System SHALL validate enum types as :atom with constraints | Check attribute definitions | MEDIUM |
| SC-DB-010 | System SHALL register resources alphabetically in domain | Verify resource ordering | LOW |

#### Category L: Migration Safety (SC-DB-011 to SC-DB-020)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DB-011 | System SHALL verify table/column existence before index creation | Query information_schema | CRITICAL |
| SC-DB-012 | System SHALL use create_if_not_exists for indexes | Check migration syntax | HIGH |
| SC-DB-013 | System SHALL use @disable_ddl_transaction for CONCURRENTLY | Verify module attributes | HIGH |
| SC-DB-014 | System SHALL implement reversible down functions | Check migration structure | MEDIUM |
| SC-DB-015 | System SHALL use timestamp format YYYYMMDDHHMMSS for migrations | Validate filename pattern | MEDIUM |
| SC-DB-016 | System SHALL include @moduledoc with STAMP compliance | Check documentation | LOW |
| SC-DB-017 | System SHALL validate column names against actual schema | Query pg_attribute | CRITICAL |
| SC-DB-018 | System SHALL use concurrently: true for production indexes | Check index options | HIGH |
| SC-DB-019 | System SHALL handle TimescaleDB hypertable constraints | Verify table type | MEDIUM |
| SC-DB-020 | System SHALL maintain migration idempotency | Test up/down cycles | HIGH |

#### Category M: Test Data Safety (SC-DB-021 to SC-DB-030)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DB-021 | System SHALL define factory for EVERY Ash resource | Check test/support/factory.ex | HIGH |
| SC-DB-022 | System SHALL use valid UUIDs in test data | Validate UUID format | MEDIUM |
| SC-DB-023 | System SHALL use Faker for realistic test data | Check factory implementations | LOW |
| SC-DB-024 | System SHALL maintain referential integrity in test data | Validate foreign keys | CRITICAL |
| SC-DB-025 | System SHALL use unique constraints in factories | Check sequence() usage | MEDIUM |
| SC-DB-026 | System SHALL define factory traits for common variations | Verify trait definitions | LOW |
| SC-DB-027 | System SHALL validate test data against Ash validations | Run changeset validation | HIGH |
| SC-DB-028 | System SHALL isolate test data per test case | Check sandbox usage | CRITICAL |
| SC-DB-029 | System SHALL use consistent tenant_id in multi-tenant tests | Validate tenant isolation | HIGH |
| SC-DB-030 | System SHALL generate minimal test data sets | Check data volume | MEDIUM |

#### Category N: Data Cleanup Safety (SC-DB-031 to SC-DB-040)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DB-031 | System SHALL use Ecto.Adapters.SQL.Sandbox in tests | Check test_helper.exs | CRITICAL |
| SC-DB-032 | System SHALL truncate tables in correct order (foreign keys) | Validate dependency order | HIGH |
| SC-DB-033 | System SHALL reset sequences after truncation | Check sequence reset | MEDIUM |
| SC-DB-034 | System SHALL exclude system tables from cleanup | Validate table list | HIGH |
| SC-DB-035 | System SHALL log all cleanup operations | Check audit trail | MEDIUM |
| SC-DB-036 | System SHALL handle TimescaleDB chunk cleanup | Verify hypertable handling | HIGH |
| SC-DB-037 | System SHALL preserve seed data during cleanup | Check seed protection | MEDIUM |
| SC-DB-038 | System SHALL use transactions for cleanup operations | Validate atomicity | HIGH |
| SC-DB-039 | System SHALL verify cleanup completion | Check table counts | MEDIUM |
| SC-DB-040 | System SHALL handle concurrent cleanup safely | Check locking strategy | HIGH |
| SC-DB-041 | All custom_indexes with where clauses using boolean attributes SHALL explicitly quote column names | Check schema definitions | CRITICAL |
| SC-DB-042 | All raw SQL queries using array parameters SHALL use explicit type casting (e.g., ::text[], ::uuid[]) | Check raw SQL | CRITICAL |

#### Category O: Alarm Processing Safety (SC-ALM-001 to SC-ALM-010)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-ALM-001 | Alarm persistence SHALL be synchronous | Check Api.ex delegation | CRITICAL |
| SC-ALM-005 | Long-running workflows (Escalations) SHALL persist state to database immediately | Check ActiveEscalation usage | CRITICAL |

### 63.3 TDG Database Generation Rules (TDG-DB-001 to TDG-DB-040)

**TDG Requirement**: ALL database-related code MUST have tests written BEFORE implementation.

#### TDG-DB-001 to TDG-DB-010: Ash Resource TDG
```elixir
# MANDATORY: Test file MUST exist before resource generation
# Pattern: test/indrajaal/{domain}/{resource}_test.exs
# Required tests: [:unit, :property]
```

| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-DB-001 | Test file MUST exist before resource | `test/indrajaal/{domain}/{resource}_test.exs` | unit, property |
| TDG-DB-002 | Property tests MUST use PropCheck AND ExUnitProperties | Both libraries | dual_property |
| TDG-DB-003 | CRUD action tests MUST exist before action definition | Action tests | unit |
| TDG-DB-004 | Validation tests MUST exist before changeset rules | Validation tests | unit, property |
| TDG-DB-005 | Calculation tests MUST exist before calculation definition | Calculation tests | unit |
| TDG-DB-006 | Relationship tests MUST exist before relationship definition | Relationship tests | integration |
| TDG-DB-007 | Policy tests MUST exist before authorization rules | Policy tests | unit |
| TDG-DB-008 | Aggregate tests MUST exist before aggregate definition | Aggregate tests | unit |
| TDG-DB-009 | Multitenancy tests MUST exist before tenant configuration | Tenant tests | integration |
| TDG-DB-010 | Resource tests MUST achieve >95% coverage | Coverage threshold | all |

#### TDG-DB-011 to TDG-DB-020: Migration TDG
| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-DB-011 | Migration test MUST exist before migration file | `test/migrations/{migration}_test.exs` | integration |
| TDG-DB-012 | Schema validation test MUST exist before table creation | Schema tests | unit |
| TDG-DB-013 | Index validation test MUST verify column existence | Index tests | integration |
| TDG-DB-014 | Rollback tests MUST exist for reversible migrations | Rollback tests | integration |
| TDG-DB-015 | Data migration tests MUST exist before data changes | Data tests | integration |
| TDG-DB-016 | Constraint tests MUST exist before constraint addition | Constraint tests | unit |
| TDG-DB-017 | Foreign key tests MUST verify referential integrity | FK tests | integration |
| TDG-DB-018 | Performance tests MUST exist for index additions | Perf tests | performance |
| TDG-DB-019 | TimescaleDB tests MUST exist for hypertable operations | TS tests | integration |
| TDG-DB-020 | Migration idempotency tests MUST verify safe re-run | Idempotency tests | integration |

#### TDG-DB-021 to TDG-DB-040: Factory and Cleanup TDG
| ID | Rule | Test Pattern |
|----|------|--------------|
| TDG-DB-021 | Factory tests MUST exist before factory definition | `test/support/factory_test.exs` |
| TDG-DB-022-030 | Test data generators MUST be property-tested | Property tests |
| TDG-DB-031-040 | Cleanup utilities MUST have verification tests | Cleanup tests |

### 63.4 AOR Database Agent Rules (AOR-DB-001 to AOR-DB-032)

**Deontic Logic Operators**:
- $\mathbf{O}(\phi)$ - Agent MUST do $\phi$ (Obligation)
- $\mathbf{F}(\phi)$ - Agent MUST NOT do $\phi$ (Prohibition)
- $\mathbf{P}(\phi)$ - Agent MAY do $\phi$ (Permission)

#### Schema Rules (AOR-DB-001 to AOR-DB-008)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-DB-001 | O(UseBaseResource) | Agent SHALL use BaseResource mixin | SC-DB-001 | CRITICAL | Yes |
| AOR-DB-002 | O(RegisterInDomain) | Agent SHALL register resources in domain | SC-DB-003 | CRITICAL | Yes |
| AOR-DB-003 | O(SnakeCaseTable) | Agent SHALL use snake_case table names | SC-DB-004 | HIGH | Yes |
| AOR-DB-004 | F(DomainPrefixTable) | Agent SHALL NOT use domain prefix in tables | SC-DB-004 | HIGH | Yes |
| AOR-DB-005 | O(UUIDPrimaryKey) | Agent SHALL define uuid_primary_key :id | SC-DB-005 | CRITICAL | Yes |
| AOR-DB-006 | O(Timestamps) | Agent SHALL include timestamps() | SC-DB-006 | MEDIUM | Yes |
| AOR-DB-007 | F(DuplicateCodeInterface) | Agent SHALL NOT duplicate code_interface | SC-DB-007 | HIGH | Yes |
| AOR-DB-008 | O(ValidateEnumAtom) | Agent SHALL use :atom for enums | SC-DB-009 | MEDIUM | Yes |

#### Migration Rules (AOR-DB-009 to AOR-DB-016)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-DB-009 | O(CreateIfNotExists) | Agent SHALL use create_if_not_exists | SC-DB-012 | HIGH | Yes |
| AOR-DB-010 | O(VerifySchema) | Agent SHALL verify schema before migration | SC-DB-011 | CRITICAL | No |
| AOR-DB-011 | O(DisableDDL) | Agent SHALL disable DDL transaction for CONCURRENTLY | SC-DB-013 | HIGH | Yes |
| AOR-DB-012 | O(ReversibleMigration) | Agent SHALL implement reversible migrations | SC-DB-014 | MEDIUM | Partial |
| AOR-DB-013 | F(HardcodedColumnName) | Agent SHALL NOT assume column names | SC-DB-017 | CRITICAL | No |
| AOR-DB-014 | O(ConcurrentIndex) | Agent SHALL use concurrently: true | SC-DB-018 | HIGH | Yes |
| AOR-DB-015 | O(DocumentMigration) | Agent SHALL document migration purpose | SC-DB-016 | LOW | Partial |
| AOR-DB-016 | O(IdempotentMigration) | Agent SHALL make migrations idempotent | SC-DB-020 | HIGH | Partial |

#### Test Data Rules (AOR-DB-017 to AOR-DB-024)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-DB-017 | O(FactoryExists) | Agent SHALL create factory for resources | SC-DB-021 | HIGH | Yes |
| AOR-DB-018 | O(ValidUUID) | Agent SHALL use valid UUIDs | SC-DB-022 | MEDIUM | Yes |
| AOR-DB-019 | O(FakerData) | Agent SHALL use Faker for test data | SC-DB-023 | LOW | Yes |
| AOR-DB-020 | O(ReferentialIntegrity) | Agent SHALL maintain referential integrity | SC-DB-024 | CRITICAL | Partial |
| AOR-DB-021 | O(UniqueSequence) | Agent SHALL use sequence() for uniqueness | SC-DB-025 | MEDIUM | Yes |
| AOR-DB-022 | O(FactoryTraits) | Agent SHALL define factory traits | SC-DB-026 | LOW | Yes |
| AOR-DB-023 | O(ValidateTestData) | Agent SHALL validate test data | SC-DB-027 | HIGH | No |
| AOR-DB-024 | O(TenantIsolation) | Agent SHALL maintain tenant isolation | SC-DB-029 | HIGH | Partial |

#### Cleanup Rules (AOR-DB-025 to AOR-DB-032)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-DB-025 | O(UseSandbox) | Agent SHALL use SQL Sandbox | SC-DB-031 | CRITICAL | Yes |
| AOR-DB-026 | O(TruncateOrder) | Agent SHALL respect FK order | SC-DB-032 | HIGH | No |
| AOR-DB-027 | O(ResetSequences) | Agent SHALL reset sequences | SC-DB-033 | MEDIUM | Yes |
| AOR-DB-028 | F(TruncateSystem) | Agent SHALL NOT truncate system tables | SC-DB-034 | CRITICAL | Yes |
| AOR-DB-029 | O(LogCleanup) | Agent SHALL log cleanup operations | SC-DB-035 | MEDIUM | Yes |
| AOR-DB-030 | O(HandleHypertable) | Agent SHALL handle TimescaleDB cleanup | SC-DB-036 | HIGH | Partial |
| AOR-DB-031 | O(PreserveSeed) | Agent SHALL preserve seed data | SC-DB-037 | MEDIUM | No |
| AOR-DB-032 | O(TransactionalCleanup) | Agent SHALL use transactions | SC-DB-038 | HIGH | Yes |

### 63.5 Database Rule Validation Commands

```bash
# Validate STAMP database constraints
elixir scripts/validation/database_stamp_validator.exs --all

# Validate TDG database rules
elixir scripts/validation/database_tdg_validator.exs --resource MyResource

# Validate AOR database rules
elixir scripts/validation/database_aor_validator.exs --migration TIMESTAMP

# Comprehensive database validation
elixir scripts/validation/comprehensive_database_validator.exs --strict

# Schema verification before migration
elixir scripts/validation/schema_verification.exs --check-columns alarm_events

# Test data validation
elixir scripts/validation/factory_validator.exs --resource AlarmEvent
```

### 63.6 Database Rule Telemetry Events

```elixir
# Database rule telemetry (emits to Console + SigNoz)
[:indrajaal, :database, :stamp, :validation]
[:indrajaal, :database, :tdg, :compliance]
[:indrajaal, :database, :aor, :enforcement]
[:indrajaal, :database, :migration, :executed]
[:indrajaal, :database, :schema, :verified]
[:indrajaal, :database, :cleanup, :completed]
```

### 63.7 Common Database Error Patterns (EP-DB-*)

| EP ID | Pattern | Severity | Fix |
|-------|---------|----------|-----|
| EP-DB-001 | Domain-prefixed table name | HIGH | Remove domain prefix |
| EP-DB-002 | Missing BaseResource mixin | CRITICAL | Add `use Indrajaal.BaseResource` |
| EP-DB-003 | Duplicate code_interface | HIGH | Remove from resource, keep in BaseResource |
| EP-DB-004 | Wrong column name in index | CRITICAL | Query schema before migration |
| EP-DB-005 | Missing create_if_not_exists | MEDIUM | Use idempotent migration functions |
| EP-DB-006 | Non-atomic enum type | MEDIUM | Change `:string` to `:atom` for enums |
| EP-DB-007 | Missing factory definition | HIGH | Create factory in test/support |
| EP-DB-008 | FK violation in test data | CRITICAL | Create parent records first |
| EP-DB-009 | Missing @disable_ddl_transaction | HIGH | Add for CONCURRENTLY operations |
| EP-DB-010 | Non-reversible migration | MEDIUM | Implement down/0 function |

---

## 64.0 Agent-Friendly Code Documentation System (SC-DOC, TDG-DOC, AOR-DOC)

### 64.1 Overview and Mathematical Foundation

This section defines comprehensive documentation rules for AI agents working with declarative frameworks (Ash, Phoenix LiveView, Oban, PropCheck). These rules ensure agents can understand context, constraints, and intent without hallucinating or misinterpreting declarative DSLs.

**Core Problem**: AI models struggle with declarative DSLs because:
- They conflate DSL macros with standard function calls
- They cannot infer intent from declarative syntax alone
- They lack global context about project constraints
- They hallucinate non-existent APIs from pattern matching

**Solution**: Structured documentation using SC-DOC (STAMP), TDG-DOC (Test-Driven), and AOR-DOC (Agent Rules) to provide explicit context.

**Mathematical Foundation**:

**Definition 64.1** (Documentation Completeness): Let $D$ be a code module and $C$ be the set of comments/documentation.
$$
\text{Complete}(D) \iff \forall d \in D : \exists c \in C : \text{Explains}(c, d) \wedge \text{Context}(c) \wedge \text{Intent}(c)
$$

**Definition 64.2** (Agent Comprehensibility): A documentation $c$ is agent-comprehensible iff:
$$
\text{Comprehensible}(c) \iff \text{What}(c) \wedge \text{Why}(c) \wedge \text{Where}(c) \wedge \text{Constraints}(c)
$$

**Definition 64.3** (DSL Context Injection): For declarative code $dsl$, context injection $\iota$ is valid iff:
$$
\text{Valid}(\iota, dsl) \iff \neg\text{Confusable}(\iota, \text{FunctionCall}) \wedge \text{ExplicitSemantics}(\iota)
$$

### 64.2 STAMP Documentation Safety Constraints (SC-DOC-001 to SC-DOC-020)

#### Category O: Module-Level Documentation (SC-DOC-001 to SC-DOC-005)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DOC-001 | System SHALL include @moduledoc with WHAT, WHY, CONSTRAINTS sections | Check for structured moduledoc | CRITICAL |
| SC-DOC-002 | System SHALL document domain context at module level | Verify domain reference | HIGH |
| SC-DOC-003 | System SHALL include STAMP constraint references in safety-critical modules | Check SC-* references | HIGH |
| SC-DOC-004 | System SHALL document inheritance chain (BaseResource, TenantResource) | Verify mixin documentation | MEDIUM |
| SC-DOC-005 | System SHALL include "Agent Context" section for AI-specific guidance | Check for agent context | HIGH |

#### Category P: DSL Block Documentation (SC-DOC-006 to SC-DOC-010)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DOC-006 | System SHALL document Ash DSL blocks with "DSL:" prefix comments | Check DSL block comments | CRITICAL |
| SC-DOC-007 | System SHALL explain DSL macro semantics (NOT function calls) | Verify macro explanation | CRITICAL |
| SC-DOC-008 | System SHALL document attribute constraints with rationale | Check constraint comments | HIGH |
| SC-DOC-009 | System SHALL document action semantics (create vs update vs custom) | Verify action documentation | HIGH |
| SC-DOC-010 | System SHALL document relationship cardinality and constraints | Check relationship docs | MEDIUM |

#### Category Q: Change Context Documentation (SC-DOC-011 to SC-DOC-015)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DOC-011 | System SHALL document change context for Ash changesets | Check change documentation | CRITICAL |
| SC-DOC-012 | System SHALL explain require_atomic? semantics and when needed | Verify atomicity docs | CRITICAL |
| SC-DOC-013 | System SHALL document manual changes vs accept patterns | Check change pattern docs | HIGH |
| SC-DOC-014 | System SHALL document validation order and dependencies | Verify validation docs | MEDIUM |
| SC-DOC-015 | System SHALL document side effects in change functions | Check side effect docs | HIGH |

#### Category R: Integration Documentation (SC-DOC-016 to SC-DOC-020)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-DOC-016 | System SHALL document LiveView state management patterns | Check LV state docs | HIGH |
| SC-DOC-017 | System SHALL document Oban worker serialization requirements | Verify Oban docs | CRITICAL |
| SC-DOC-018 | System SHALL document PropCheck generator patterns | Check property test docs | HIGH |
| SC-DOC-019 | System SHALL document escape hatches with explicit warnings | Verify escape hatch docs | CRITICAL |
| SC-DOC-020 | System SHALL document cross-domain interactions | Check domain interaction docs | MEDIUM |

### 64.3 TDG Documentation Rules (TDG-DOC-001 to TDG-DOC-015)

**TDG Documentation Requirement**: Documentation MUST be written BEFORE code implementation to ensure tests can verify documentation accuracy.

| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-DOC-001 | @moduledoc MUST exist before module implementation | `test/doc/{module}_doc_test.exs` | doc_exists |
| TDG-DOC-002 | DSL block comments MUST exist before DSL blocks | Check comment timestamps | doc_first |
| TDG-DOC-003 | Agent Context section MUST be property-tested for accuracy | Property test | dual_property |
| TDG-DOC-004 | Constraint documentation MUST match actual constraints | Validation test | unit |
| TDG-DOC-005 | Action documentation MUST match action definitions | Action test | unit |
| TDG-DOC-006 | Relationship documentation MUST match schema | Schema test | integration |
| TDG-DOC-007 | Change context documentation MUST be testable | Change test | unit |
| TDG-DOC-008 | Side effect documentation MUST be verified | Side effect test | integration |
| TDG-DOC-009 | Error documentation MUST list all error cases | Error test | unit |
| TDG-DOC-010 | LiveView documentation MUST verify state patterns | LV test | unit |
| TDG-DOC-011 | Oban documentation MUST verify serialization | Oban test | unit |
| TDG-DOC-012 | PropCheck documentation MUST verify generators | PropCheck test | property |
| TDG-DOC-013 | Escape hatch documentation MUST verify warnings shown | Escape test | unit |
| TDG-DOC-014 | Cross-domain documentation MUST verify interactions | Integration test | integration |
| TDG-DOC-015 | Documentation coverage MUST exceed 95% | Coverage test | coverage |

### 64.4 AOR Documentation Agent Rules (AOR-DOC-001 to AOR-DOC-025)

**Deontic Logic for Documentation**:
- $\mathbf{O}_{DOC}(\phi)$ - Agent MUST document $\phi$
- $\mathbf{F}_{DOC}(\phi)$ - Agent MUST NOT assume $\phi$ without documentation
- $\mathbf{P}_{DOC}(\phi)$ - Agent MAY infer $\phi$ from explicit documentation

#### Module Documentation Rules (AOR-DOC-001 to AOR-DOC-005)
| ID | Formal | Natural | STAMP | Severity |
|----|--------|---------|-------|----------|
| AOR-DOC-001 | O(ReadModuledocFirst) | Agent SHALL read @moduledoc before modifying | SC-DOC-001 | CRITICAL |
| AOR-DOC-002 | O(VerifyDomainContext) | Agent SHALL verify domain context exists | SC-DOC-002 | HIGH |
| AOR-DOC-003 | F(AssumeBaseResource) | Agent SHALL NOT assume BaseResource patterns without reading | SC-DOC-004 | CRITICAL |
| AOR-DOC-004 | O(UpdateModuledoc) | Agent SHALL update @moduledoc when modifying module | SC-DOC-001 | HIGH |
| AOR-DOC-005 | O(DocumentAgentChanges) | Agent SHALL document what changes were made and why | SC-DOC-011 | HIGH |

#### DSL Comprehension Rules (AOR-DOC-006 to AOR-DOC-012)
| ID | Formal | Natural | STAMP | Severity |
|----|--------|---------|-------|----------|
| AOR-DOC-006 | F(ConfuseDSLWithFunction) | Agent SHALL NOT confuse DSL macros with function calls | SC-DOC-007 | CRITICAL |
| AOR-DOC-007 | O(ReadDSLBlockComment) | Agent SHALL read DSL block comments before modifying | SC-DOC-006 | CRITICAL |
| AOR-DOC-008 | F(InferDSLSemantics) | Agent SHALL NOT infer DSL semantics without explicit docs | SC-DOC-007 | CRITICAL |
| AOR-DOC-009 | O(VerifyAttributeConstraints) | Agent SHALL verify attribute constraints from docs | SC-DOC-008 | HIGH |
| AOR-DOC-010 | O(VerifyActionSemantics) | Agent SHALL verify action type (create/update/custom) | SC-DOC-009 | HIGH |
| AOR-DOC-011 | F(AssumeRelationshipCardinality) | Agent SHALL NOT assume cardinality without docs | SC-DOC-010 | MEDIUM |
| AOR-DOC-012 | O(DocumentDSLChanges) | Agent SHALL document any DSL changes made | SC-DOC-006 | HIGH |

#### Change Context Rules (AOR-DOC-013 to AOR-DOC-018)
| ID | Formal | Natural | STAMP | Severity |
|----|--------|---------|-------|----------|
| AOR-DOC-013 | O(ReadChangeContext) | Agent SHALL read change context before modifying changesets | SC-DOC-011 | CRITICAL |
| AOR-DOC-014 | F(OmitRequireAtomic) | Agent SHALL NOT omit require_atomic? for function changes | SC-DOC-012 | CRITICAL |
| AOR-DOC-015 | O(VerifyAcceptVsArgument) | Agent SHALL verify accept vs argument usage from docs | SC-DOC-013 | CRITICAL |
| AOR-DOC-016 | O(DocumentSideEffects) | Agent SHALL document any side effects introduced | SC-DOC-015 | HIGH |
| AOR-DOC-017 | F(AssumeValidationOrder) | Agent SHALL NOT assume validation order | SC-DOC-014 | MEDIUM |
| AOR-DOC-018 | O(VerifyChangePattern) | Agent SHALL verify change pattern matches documentation | SC-DOC-013 | HIGH |

#### Integration Rules (AOR-DOC-019 to AOR-DOC-025)
| ID | Formal | Natural | STAMP | Severity |
|----|--------|---------|-------|----------|
| AOR-DOC-019 | O(ReadLiveViewState) | Agent SHALL read LiveView state documentation | SC-DOC-016 | HIGH |
| AOR-DOC-020 | O(VerifyObanSerialization) | Agent SHALL verify Oban args are serializable | SC-DOC-017 | CRITICAL |
| AOR-DOC-021 | O(ReadPropCheckDocs) | Agent SHALL read PropCheck generator documentation | SC-DOC-018 | HIGH |
| AOR-DOC-022 | O(VerifyEscapeHatch) | Agent SHALL verify escape hatch documentation exists | SC-DOC-019 | CRITICAL |
| AOR-DOC-023 | F(UseEscapeWithoutDocs) | Agent SHALL NOT use escape hatches without documentation | SC-DOC-019 | CRITICAL |
| AOR-DOC-024 | O(VerifyCrossDomain) | Agent SHALL verify cross-domain interaction docs | SC-DOC-020 | MEDIUM |
| AOR-DOC-025 | O(UpdateIntegrationDocs) | Agent SHALL update integration docs on changes | SC-DOC-020 | MEDIUM |

### 64.5 Documentation Templates

#### Template A: Ash Resource Module Documentation
```elixir
defmodule Indrajaal.Domain.ResourceName do
  @moduledoc """
  ## WHAT
  Brief description of what this resource represents.

  ## WHY
  Business purpose and why this resource exists.

  ## DOMAIN CONTEXT
  - Domain: Indrajaal.Domain (reference Section X.X in CLAUDE.md)
  - Inherits: BaseResource (provides code_interface, timestamps)
  - Multi-tenant: Yes/No (uses TenantResource mixin)

  ## CONSTRAINTS
  - SC-DB-001: Uses BaseResource mixin ✓
  - SC-DB-003: Registered in domain ✓
  - SC-DB-005: UUID primary key ✓

  ## AGENT CONTEXT
  - DO NOT add code_interface here (defined in BaseResource)
  - DO NOT use :string for enums (use :atom with one_of constraint)
  - DO use require_atomic? false for update actions with function changes
  - Relationships: [list key relationships and their purpose]
  - Common Operations: [list typical CRUD patterns]

  ## ESCAPE HATCHES
  None / List any with justification

  ## RELATED RESOURCES
  - RelatedResource1 (relationship type)
  - RelatedResource2 (relationship type)
  """

  use Indrajaal.BaseResource  # DSL: Mixin providing code_interface, timestamps

  # DSL: Database configuration - table name is snake_case WITHOUT domain prefix
  postgres do
    table "resource_names"  # NOT "domain_resource_names"
    repo Indrajaal.Repo
  end

  # DSL: Attribute definitions - these are NOT function calls
  attributes do
    # DSL: UUID primary key - MANDATORY per SC-DB-005
    uuid_primary_key :id

    # DSL: Attribute with constraint
    # CONSTRAINT: one_of only works with :atom type, NOT :string
    attribute :status, :atom do
      allow_nil? false
      default :pending
      constraints one_of: [:pending, :active, :completed]
    end

    # DSL: Inherited from BaseResource - DO NOT REDEFINE
    # timestamps()  # Already in BaseResource
  end

  # DSL: Action definitions
  actions do
    defaults [:read]

    # DSL: Create action - accepts attributes, NO require_atomic?
    create :create do
      accept [:name, :status]
    end

    # DSL: Update action with function change - REQUIRES require_atomic? false
    update :custom_update do
      require_atomic? false  # MANDATORY for function-based changes
      change fn changeset, _context ->
        # CHANGE CONTEXT: This function runs during changeset processing
        # SIDE EFFECTS: None
        changeset
      end
    end
  end
end
```

#### Template B: Phoenix LiveView Documentation
```elixir
defmodule IndrajaalWeb.FeatureLive do
  @moduledoc """
  ## WHAT
  LiveView for [feature description].

  ## WHY
  Provides real-time [functionality].

  ## STATE MANAGEMENT
  - @assigns.key1: [type] - [purpose]
  - @assigns.key2: [type] - [purpose]

  ## AGENT CONTEXT
  - State updates use assign/2 or assign_new/3
  - Event handlers return {:noreply, socket} or {:reply, map, socket}
  - DO NOT use raw JavaScript unless documented as escape hatch
  - Streams are used for large lists (see HEEx template)

  ## STAMP COMPLIANCE
  - SC-DOC-016: LiveView state documented ✓
  """
  use IndrajaalWeb, :live_view

  # LIFECYCLE: mount/3 called on connection
  # STATE: Initialize all assigns here
  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, key: value)}
  end

  # EVENT: Handle user interaction
  # STATE CHANGE: Updates @assigns.key
  @impl true
  def handle_event("event_name", params, socket) do
    {:noreply, assign(socket, key: new_value)}
  end
end
```

#### Template C: Oban Worker Documentation
```elixir
defmodule Indrajaal.Workers.FeatureWorker do
  @moduledoc """
  ## WHAT
  Background job for [task description].

  ## WHY
  Processes [task] asynchronously to avoid blocking requests.

  ## SERIALIZATION REQUIREMENTS
  All args MUST be JSON-serializable:
  - Strings: ✓
  - Integers: ✓
  - Maps with string keys: ✓
  - Structs: ✗ (convert to map first)
  - PIDs: ✗ (not serializable)
  - Functions: ✗ (not serializable)

  ## AGENT CONTEXT
  - args MUST be serializable (SC-DOC-017)
  - Use string keys in args, NOT atom keys
  - Store IDs not full records (fetch fresh in perform/1)

  ## RETRY STRATEGY
  - max_attempts: 3
  - Backoff: exponential

  ## STAMP COMPLIANCE
  - SC-DOC-017: Serialization documented ✓
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ARGS: Must be JSON-serializable map with string keys
    # DO NOT pass structs, PIDs, or functions
    :ok
  end
end
```

#### Template D: PropCheck Property Test Documentation
```elixir
defmodule Indrajaal.FeaturePropertyTest do
  @moduledoc """
  ## WHAT
  Property-based tests for [feature].

  ## WHY
  Discovers edge cases through randomized input generation.

  ## GENERATOR PATTERNS
  - Use PropCheck generators (forall, let)
  - NOT ExUnitProperties (disabled per SC-TDG-002)
  - Use sd_* helpers from PropertyTestCase for StreamData compatibility

  ## AGENT CONTEXT
  - PropCheck uses `forall` macro, NOT `check all`
  - Multiple generators use tuple syntax: {gen1, gen2}
  - Return boolean from property body (NOT assert)
  - Use `let` for dependent generators

  ## STAMP COMPLIANCE
  - SC-PROP-001: Uses PropCheck ✓
  - SC-DOC-018: Generator patterns documented ✓
  """
  use Indrajaal.PropertyTestCase

  # PROPCHECK: forall macro generates test cases
  # GENERATOR: {integer(), boolean()} generates tuple of int and bool
  # RETURN: Boolean indicating property holds
  property "propcheck: feature property" do
    forall {x, y} <- {integer(), boolean()} do
      result = Feature.process(x, y)
      is_valid_result(result)  # Returns boolean, NOT assert
    end
  end

  # PROPCHECK: let for dependent generation
  # FIRST: Generate base value
  # THEN: Use base value to generate dependent value
  property "propcheck: dependent generation" do
    forall result <- let base <- integer() do
                       base * 2
                     end do
      rem(result, 2) == 0
    end
  end
end
```

#### Template E: Escape Hatch Documentation
```elixir
# ⚠️ ESCAPE HATCH DOCUMENTATION ⚠️
# WHAT: [Description of non-standard pattern]
# WHY NEEDED: [Justification - must be compelling]
# STANDARD ALTERNATIVE: [What would normally be used]
# RISKS: [List potential issues]
# REVIEWED BY: [Name/Date]
# STAMP: SC-DOC-019 compliance
# REMOVAL PLAN: [When/how this can be removed]

# Example: Raw SQL escape hatch
defmodule Indrajaal.Repo do
  # ⚠️ ESCAPE HATCH: Raw SQL query
  # WHY: TimescaleDB-specific function not supported by Ecto
  # STANDARD: Ecto.Query
  # RISKS: SQL injection if params not sanitized
  # REVIEWED: Claude/2025-12-10
  # REMOVAL: When Ecto adds TimescaleDB support
  def timescale_aggregate(table, column, interval) do
    query = """
    SELECT time_bucket($1, timestamp), avg($2)
    FROM #{table}
    GROUP BY 1
    """
    Ecto.Adapters.SQL.query!(__MODULE__, query, [interval, column])
  end
end
```

### 64.6 Comment Quick Reference

| Context | Prefix | Purpose | Example |
|---------|--------|---------|---------|
| DSL Block | `# DSL:` | Explain macro semantics | `# DSL: attributes block defines schema` |
| Constraint | `# CONSTRAINT:` | Explain restriction | `# CONSTRAINT: one_of requires :atom type` |
| Agent Warning | `# AGENT:` | Direct agent guidance | `# AGENT: DO NOT add code_interface here` |
| Change Context | `# CHANGE:` | Explain changeset behavior | `# CHANGE: runs during validation phase` |
| Side Effect | `# SIDE EFFECT:` | Document effects | `# SIDE EFFECT: sends email notification` |
| Escape Hatch | `# ⚠️ ESCAPE HATCH:` | Non-standard pattern | `# ⚠️ ESCAPE HATCH: Raw SQL for TimescaleDB` |
| STAMP Reference | `# STAMP:` | Safety constraint ref | `# STAMP: SC-DB-001 compliance` |
| Inheritance | `# INHERITS:` | Document mixin behavior | `# INHERITS: timestamps from BaseResource` |

### 64.7 Documentation Error Patterns (EP-DOC-*)

| EP ID | Pattern | Severity | Fix |
|-------|---------|----------|-----|
| EP-DOC-001 | Missing @moduledoc | HIGH | Add structured moduledoc |
| EP-DOC-002 | Missing Agent Context section | HIGH | Add AGENT CONTEXT to moduledoc |
| EP-DOC-003 | DSL block without comment | MEDIUM | Add `# DSL:` prefix comment |
| EP-DOC-004 | Escape hatch without warning | CRITICAL | Add ⚠️ ESCAPE HATCH documentation |
| EP-DOC-005 | Undocumented require_atomic? | CRITICAL | Add CHANGE CONTEXT comment |
| EP-DOC-006 | Missing constraint rationale | MEDIUM | Add CONSTRAINT comment |
| EP-DOC-007 | Confusing DSL as function | CRITICAL | Add `# DSL: This is a macro, not a function call` |
| EP-DOC-008 | Missing side effect documentation | HIGH | Add SIDE EFFECT comment |
| EP-DOC-009 | Undocumented Oban serialization | CRITICAL | Add SERIALIZATION section |
| EP-DOC-010 | Missing LiveView state docs | HIGH | Add STATE MANAGEMENT section |

### 64.8 Documentation Validation Commands

```bash
# Validate all SC-DOC constraints
elixir scripts/validation/documentation_stamp_validator.exs --all

# Check for missing @moduledoc
elixir scripts/validation/moduledoc_coverage_validator.exs --threshold 95

# Validate DSL block comments
elixir scripts/validation/dsl_comment_validator.exs --directory lib/indrajaal/

# Check escape hatch documentation
elixir scripts/validation/escape_hatch_validator.exs --strict

# Generate documentation compliance report
elixir scripts/validation/documentation_compliance_report.exs --format json

# Validate Agent Context sections
elixir scripts/validation/agent_context_validator.exs --all
```

### 64.9 Documentation Telemetry Events

```elixir
# Documentation compliance telemetry (emits to Console + SigNoz)
[:indrajaal, :documentation, :moduledoc, :validated]
[:indrajaal, :documentation, :dsl_comment, :validated]
[:indrajaal, :documentation, :agent_context, :validated]
[:indrajaal, :documentation, :escape_hatch, :detected]
[:indrajaal, :documentation, :compliance, :report]
```

### 64.10 STAMP Safety Constraint Summary

| ID Range | Category | Count | Description |
|----------|----------|-------|-------------|
| SC-DOC-001 to SC-DOC-005 | Module Documentation | 5 | @moduledoc structure |
| SC-DOC-006 to SC-DOC-010 | DSL Documentation | 5 | Declarative block docs |
| SC-DOC-011 to SC-DOC-015 | Change Context | 5 | Changeset documentation |
| SC-DOC-016 to SC-DOC-020 | Integration | 5 | Cross-system docs |
| **Total** | | **20** | |

**Updated STAMP Constraint Count**:
- Previous: $\mathcal{SC}_{141}$ (72 core + 6 agent + 8 integration + 40 database + 5 PropCheck + 10 Ash)
- New: $\mathcal{SC}_{161}$ (141 + 20 documentation)

---

## 65.0 Script Batch Execution Rules (SC-BATCH, TDG-BATCH, AOR-BATCH)

### 65.1 Overview and Purpose

**CRITICAL SAFETY CONSTRAINT**: Script-based code changes MUST follow controlled batch execution with mandatory validation gates. This section was added after an incident where an overly aggressive sed script modified 126+ files simultaneously, breaking legitimate code.

**Core Principles**:
1. **10-Change Batch Limit**: Never exceed 10 changes per batch
2. **Elixir Script Requirement**: All batch changes via Elixir scripts only
3. **Validation Cycle**: Mandatory compilation AND test after each batch
4. **Transaction Reversibility**: All batches must be reversible via git checkpoint

### 65.2 STAMP Safety Constraints (SC-BATCH-001 to SC-BATCH-005)

| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-BATCH-001 | Script-based changes SHALL be limited to MAX 10 changes per batch | Count changes in script | CRITICAL |
| SC-BATCH-002 | Script-based changes SHALL be implemented ONLY via Elixir scripts | Check script extension (.exs) | CRITICAL |
| SC-BATCH-003 | Each batch SHALL be followed by `mix compile --warnings-as-errors` | Verify compilation gate | CRITICAL |
| SC-BATCH-004 | Each batch SHALL be followed by `mix test` for affected files | Verify test gate | CRITICAL |
| SC-BATCH-005 | Each batch SHALL maintain transaction reversibility via git checkpoint | Check git stash/commit | CRITICAL |

### 65.3 TDG Rules (TDG-BATCH-001 to TDG-BATCH-003)

| ID | Rule | Description |
|----|------|-------------|
| TDG-BATCH-001 | Batch script MUST have validation tests before execution | Tests for script logic exist |
| TDG-BATCH-002 | Each batch MUST verify compilation success before proceeding | Compilation gate check |
| TDG-BATCH-003 | Each batch MUST verify test pass rate doesn't decrease | Regression gate |

### 65.4 AOR Rules (AOR-BATCH-001 to AOR-BATCH-005)

| ID | Formal | Natural | Severity |
|----|--------|---------|----------|
| AOR-BATCH-001 | $\mathbf{O}(\text{BatchSize} \leq 10)$ | Agent SHALL limit batch size to 10 changes | CRITICAL |
| AOR-BATCH-002 | $\mathbf{O}(\text{UseElixirScript})$ | Agent SHALL use Elixir scripts for batch changes | CRITICAL |
| AOR-BATCH-003 | $\mathbf{O}(\text{CompileAfterBatch})$ | Agent SHALL compile after each batch | CRITICAL |
| AOR-BATCH-004 | $\mathbf{O}(\text{TestAfterBatch})$ | Agent SHALL run tests after each batch | CRITICAL |
| AOR-BATCH-005 | $\mathbf{O}(\text{GitCheckpoint})$ | Agent SHALL create git checkpoint before batch | CRITICAL |

### 65.5 Forbidden Actions ($\mathbb{F}_{BATCH}$)

1. **FORBIDDEN**: Using sed/awk/perl for mass file changes
2. **FORBIDDEN**: Batch sizes exceeding 10 changes
3. **FORBIDDEN**: Skipping compilation validation after batch
4. **FORBIDDEN**: Skipping test validation after batch
5. **FORBIDDEN**: Non-reversible changes without checkpoint
6. **FORBIDDEN**: Using bash scripts for code modifications
7. **FORBIDDEN**: Committing without validation cycle completion

### 65.6 Required Script Structure

```elixir
#!/usr/bin/env elixir

# Script: batch_fix_[description].exs
# SC-BATCH Compliant: YES
# Max Changes: 10
# Reversible: YES (git checkpoint)

Mix.install([{:jason, "~> 1.4"}])

defmodule BatchFix do
  @max_batch_size 10
  @checkpoint_prefix "batch_checkpoint"

  def execute(changes) when length(changes) <= @max_batch_size do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    # 1. Create git checkpoint (MANDATORY)
    create_checkpoint(timestamp)

    # 2. Apply changes
    results = apply_changes(changes)

    # 3. Compile validation (MANDATORY - SC-BATCH-003)
    case compile_validation() do
      :ok ->
        # 4. Test validation (MANDATORY - SC-BATCH-004)
        case test_validation(changes) do
          :ok -> {:ok, results}
          :error -> rollback_and_halt(timestamp)
        end
      :error ->
        rollback_and_halt(timestamp)
    end
  end

  def execute(changes) when length(changes) > @max_batch_size do
    IO.puts("ERROR: SC-BATCH-001 VIOLATION - Batch size #{length(changes)} exceeds limit of #{@max_batch_size}")
    {:error, :batch_size_exceeded}
  end

  defp create_checkpoint(timestamp) do
    {_, 0} = System.cmd("git", ["stash", "push", "-m", "#{@checkpoint_prefix}_#{timestamp}"])
    IO.puts("✓ Checkpoint created: #{@checkpoint_prefix}_#{timestamp}")
  end

  defp compile_validation do
    IO.puts("Running compilation validation...")
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("✓ Compilation passed")
        :ok
      {output, _} ->
        IO.puts("✗ Compilation failed:\n#{output}")
        :error
    end
  end

  defp test_validation(changes) do
    # Get affected test files
    test_files = changes
    |> Enum.map(&get_test_file/1)
    |> Enum.filter(&File.exists?/1)

    if test_files == [] do
      IO.puts("⚠ No test files found for affected files")
      :ok
    else
      IO.puts("Running tests for #{length(test_files)} affected files...")
      case System.cmd("mix", ["test" | test_files], stderr_to_stdout: true) do
        {_, 0} ->
          IO.puts("✓ Tests passed")
          :ok
        {output, _} ->
          IO.puts("✗ Tests failed:\n#{output}")
          :error
      end
    end
  end

  defp rollback_and_halt(timestamp) do
    IO.puts("✗ Rolling back changes...")
    System.cmd("git", ["checkout", "."])
    System.cmd("git", ["stash", "pop"])
    {:error, :validation_failed}
  end

  defp get_test_file(source_file) do
    source_file
    |> String.replace("lib/", "test/")
    |> String.replace(".ex", "_test.exs")
  end

  defp apply_changes(changes) do
    Enum.map(changes, fn {file, old_string, new_string} ->
      content = File.read!(file)
      new_content = String.replace(content, old_string, new_string)
      File.write!(file, new_content)
      IO.puts("✓ Fixed: #{file}")
      {:ok, file}
    end)
  end
end
```

### 65.7 Batch Execution Workflow

```
┌─────────────────────────────────────────────────────────────┐
│           BATCH EXECUTION WORKFLOW (SC-BATCH)                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. PREPARE BATCH (AOR-BATCH-001)                            │
│     ├─► Identify files to change (MAX 10)                   │
│     ├─► Create Elixir script for changes                    │
│     └─► Validate script logic                               │
│                                                              │
│  2. CREATE CHECKPOINT (AOR-BATCH-005)                        │
│     └─► git stash push -m "batch_checkpoint_[timestamp]"    │
│                                                              │
│  3. EXECUTE BATCH (AOR-BATCH-002)                            │
│     └─► Run Elixir script (max 10 changes)                  │
│                                                              │
│  4. COMPILE VALIDATION (SC-BATCH-003)                        │
│     ├─► mix compile --warnings-as-errors                    │
│     ├─► On FAIL: Rollback immediately                       │
│     └─► On PASS: Continue to test                           │
│                                                              │
│  5. TEST VALIDATION (SC-BATCH-004)                           │
│     ├─► mix test [affected_files]                           │
│     ├─► On FAIL: Rollback if pass rate decreased            │
│     └─► On PASS: Commit checkpoint                          │
│                                                              │
│  6. COMMIT OR ROLLBACK                                       │
│     ├─► On SUCCESS: git add . && git commit                 │
│     └─► On FAILURE: git checkout . && git stash pop         │
│                                                              │
│  7. REPEAT for next batch (if more changes needed)           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 65.8 Validation Commands

```bash
# Validate batch script compliance
elixir scripts/validation/batch_script_validator.exs --script [script_path]

# Check batch size before execution
elixir scripts/validation/batch_size_checker.exs --script [script_path]

# Verify checkpoint exists
git stash list | grep "batch_checkpoint"

# Full batch compliance check
elixir scripts/validation/comprehensive_batch_validator.exs --strict
```

### 65.9 LTL Safety Properties for Batch Execution

- **LTL-BATCH-1**: $\Box (\text{BatchExecute} \implies \text{Size} \leq 10)$
- **LTL-BATCH-2**: $\Box (\text{BatchExecute} \implies \diamond \text{CompileValidation})$
- **LTL-BATCH-3**: $\Box (\text{CompilePass} \implies \diamond \text{TestValidation})$
- **LTL-BATCH-4**: $\Box (\text{ValidationFail} \implies \diamond \text{Rollback})$
- **LTL-BATCH-5**: $\Box \neg (\text{SedUsed} \vee \text{AwkUsed} \vee \text{BashScript})$

### 65.10 Error Patterns (EP-BATCH-001 to EP-BATCH-005)

| EP ID | Pattern | Severity | Fix |
|-------|---------|----------|-----|
| EP-BATCH-001 | Batch size > 10 | CRITICAL | Split into smaller batches |
| EP-BATCH-002 | Missing compilation gate | CRITICAL | Add mix compile step |
| EP-BATCH-003 | Missing test gate | CRITICAL | Add mix test step |
| EP-BATCH-004 | No git checkpoint | CRITICAL | Add git stash before changes |
| EP-BATCH-005 | Using sed/awk/bash | CRITICAL | Convert to Elixir script |

### 65.11 STAMP Constraint Count Update

**Updated STAMP Constraint Count**:
- Previous: $\mathcal{SC}_{161}$ (72 core + 6 agent + 8 integration + 40 database + 5 PropCheck + 10 Ash + 20 documentation)
- New: $\mathcal{SC}_{166}$ (161 + 5 batch execution)

---

## 66.0 Ash Framework 3.x API Safety Rules (SC-ASH, TDG-ASH, AOR-ASH)

### 66.1 Overview and Purpose

**CRITICAL**: This section documents Ash Framework 3.x API patterns that differ from previous versions and have caused test failures. These rules were derived from systematic 5-Level RCA analysis of organization_test.exs failures (Session 20251210-2227).

**Root Causes Identified**:
1. Tenant isolation checking wrong location (`query.context[:tenant]` vs `query.tenant`)
2. Actor passing to wrong function (`Ash.update!/2` vs `Ash.Changeset.for_update/3`)
3. Error message format changes ("name: is required" vs "attribute name is required")
4. Pagination return type (`Ash.Page.Offset` struct vs raw list)
5. Update action accept lists missing relationship IDs

**Implementation References**:
- `lib/indrajaal/multitenancy/tenant_resource.ex` - TenantResource preparation
- `lib/indrajaal/core/organization.ex` - Organization resource with hierarchy
- `test/indrajaal/core/organization_test.exs` - Comprehensive test coverage

### 66.2 STAMP Safety Constraints (SC-ASH-001 to SC-ASH-010)

#### Category O: Query and Tenant Isolation (SC-ASH-001 to SC-ASH-003)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-ASH-001 | System SHALL access tenant via `query.tenant` NOT `query.context[:tenant]` in Ash 3.x | Check TenantResource preparation | CRITICAL |
| SC-ASH-002 | System SHALL fallback to `query.context[:tenant]` only for backward compatibility | Verify fallback chain | MEDIUM |
| SC-ASH-003 | System SHALL use `:tenant` option in code_interface calls for multi-tenant resources | Check list!/read! calls | HIGH |

#### Category P: Actor and Authorization (SC-ASH-004 to SC-ASH-006)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-ASH-004 | System SHALL pass actor to `Ash.Changeset.for_update/3` in options (3rd arg) | Check changeset construction | CRITICAL |
| SC-ASH-005 | System SHALL NOT pass actor only to `Ash.update!/2` - it must be in for_update | Check update patterns | CRITICAL |
| SC-ASH-006 | System SHALL pass actor for all DomainRequiresActor-enabled operations | Verify actor option present | CRITICAL |

#### Category Q: Error Messages and Validation (SC-ASH-007 to SC-ASH-008)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-ASH-007 | System SHALL expect Ash 3.x error format: "attribute X is required" | Update test assertions | HIGH |
| SC-ASH-008 | System SHALL NOT expect legacy format: "X: is required" | Check test patterns | HIGH |

#### Category R: Pagination and Data Access (SC-ASH-009 to SC-ASH-010)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-ASH-009 | System SHALL access paginated results via `.results` on `Ash.Page.Offset` struct | Check pagination usage | CRITICAL |
| SC-ASH-010 | System SHALL NOT call `length()` directly on pagination result | Check list operations | CRITICAL |

### 66.3 TDG Rules (TDG-ASH-001 to TDG-ASH-010)

**TDG Requirement**: All Ash 3.x API patterns MUST be covered by tests before implementation.

| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-ASH-001 | Tenant isolation test MUST verify `query.tenant` access | Tenant test | integration |
| TDG-ASH-002 | Multi-tenant list operations MUST test `:tenant` option | List test | unit |
| TDG-ASH-003 | Actor passing test MUST verify for_update/3 options | Actor test | unit |
| TDG-ASH-004 | DomainRequiresActor test MUST verify authorization | Auth test | integration |
| TDG-ASH-005 | Validation error format test MUST match Ash 3.x | Error test | unit |
| TDG-ASH-006 | Required attribute test MUST use "attribute X" pattern | Validation test | unit |
| TDG-ASH-007 | Pagination test MUST verify Ash.Page.Offset struct | Pagination test | unit |
| TDG-ASH-008 | Pagination results MUST test `.results` accessor | Results test | unit |
| TDG-ASH-009 | Update action test MUST verify accept list completeness | Accept test | unit |
| TDG-ASH-010 | Relationship ID update test MUST be in accept list | Relationship test | integration |

### 66.4 AOR Agent Rules (AOR-ASH-001 to AOR-ASH-012)

**Deontic Logic Operators**:
- $\mathbf{O}(\phi)$ - Agent MUST do $\phi$ (Obligation)
- $\mathbf{F}(\phi)$ - Agent MUST NOT do $\phi$ (Prohibition)
- $\mathbf{P}(\phi)$ - Agent MAY do $\phi$ (Permission)

#### Query and Tenant Rules (AOR-ASH-001 to AOR-ASH-004)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-ASH-001 | O(UseQueryTenant) | Agent SHALL use `query.tenant` for tenant access in Ash 3.x | SC-ASH-001 | CRITICAL | Yes |
| AOR-ASH-002 | F(UseQueryContextTenant) | Agent SHALL NOT use `query.context[:tenant]` as primary | SC-ASH-001 | CRITICAL | Yes |
| AOR-ASH-003 | O(TenantOptionInList) | Agent SHALL pass `:tenant` option in list!/read! calls | SC-ASH-003 | HIGH | Yes |
| AOR-ASH-004 | O(FallbackTenantContext) | Agent SHALL add fallback for backward compatibility | SC-ASH-002 | MEDIUM | Partial |

#### Actor and Authorization Rules (AOR-ASH-005 to AOR-ASH-008)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-ASH-005 | O(ActorInForUpdate) | Agent SHALL pass actor in Ash.Changeset.for_update/3 options | SC-ASH-004 | CRITICAL | Yes |
| AOR-ASH-006 | F(ActorOnlyInUpdate) | Agent SHALL NOT pass actor only to Ash.update!/2 | SC-ASH-005 | CRITICAL | Yes |
| AOR-ASH-007 | O(ActorForDomain) | Agent SHALL include actor for DomainRequiresActor operations | SC-ASH-006 | CRITICAL | Yes |
| AOR-ASH-008 | O(SystemActorPattern) | Agent SHALL use `actor: %{is_system_admin: true}` for system ops | SC-ASH-006 | HIGH | Yes |

#### Error and Pagination Rules (AOR-ASH-009 to AOR-ASH-012)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-ASH-009 | O(Ash3ErrorFormat) | Agent SHALL use "attribute X is required" error format | SC-ASH-007 | HIGH | Yes |
| AOR-ASH-010 | F(LegacyErrorFormat) | Agent SHALL NOT use "X: is required" legacy format | SC-ASH-008 | HIGH | Yes |
| AOR-ASH-011 | O(PageResultsAccessor) | Agent SHALL use `.results` on Ash.Page.Offset | SC-ASH-009 | CRITICAL | Yes |
| AOR-ASH-012 | O(RelationshipInAccept) | Agent SHALL include relationship IDs in update accept list | SC-ASH-010 | HIGH | Yes |

### 66.5 Code Patterns and Examples

#### 66.5.1 Correct Tenant Access (SC-ASH-001)
```elixir
# CORRECT: Ash 3.x TenantResource preparation
preparations do
  prepare fn query, _context ->
    # Agent Fix: Check query.tenant first (set by Ash code_interface :tenant option)
    # SC-ASH-001: Ash 3.x stores tenant at query.tenant, not query.context[:tenant]
    tenant_id = query.tenant

    # Fallback: check query context (for backward compatibility)
    # SC-ASH-002: Maintain backward compatibility with explicit fallback
    tenant_id = tenant_id || query.context[:tenant]

    if tenant_id do
      Ash.Query.filter(query, tenant_id: tenant_id)
    else
      query
    end
  end
end

# WRONG: Pre-Ash 3.x pattern (EP-ASH-001)
preparations do
  prepare fn query, _context ->
    tenant_id = query.context[:tenant]  # WRONG: This location is no longer primary
    # ...
  end
end
```

#### 66.5.2 Correct Actor Passing (SC-ASH-004, SC-ASH-005)
```elixir
# CORRECT: Ash 3.x actor in for_update/3 options
# SC-ASH-004: Actor passed to Ash.Changeset.for_update/3 in options
# AOR-ASH-005: Agent SHALL pass actor in Ash.Changeset.for_update/3 options
org
|> Ash.Changeset.for_update(:update, %{is_primary: false}, actor: %{is_system_admin: true})
|> Ash.update!()

# WRONG: Actor only in Ash.update!/2 (EP-ASH-002)
# SC-ASH-005: This does NOT work in Ash 3.x with DomainRequiresActor
org
|> Ash.Changeset.for_update(:update, %{is_primary: false})
|> Ash.update!(actor: %{is_system_admin: true})  # WRONG: Actor ignored here
```

#### 66.5.3 Correct Error Message Assertion (SC-ASH-007)
```elixir
# CORRECT: Ash 3.x error message format
# SC-ASH-007: Use "attribute X is required" format
test "validates required name attribute", %{tenant: tenant, actor: actor} do
  result = Organization.create(%{tenant_id: tenant.id}, actor: actor)
  assert {:error, changeset} = result
  assert "attribute name is required" in errors_on(changeset).name
end

# WRONG: Legacy error format (EP-ASH-003)
# SC-ASH-008: This format is outdated
test "validates required name attribute" do
  # ...
  assert "name: is required" in errors  # WRONG: Old format
end
```

#### 66.5.4 Correct Pagination Access (SC-ASH-009)
```elixir
# CORRECT: Ash 3.x pagination returns Ash.Page.Offset struct
# SC-ASH-009: Access results via .results accessor
# AOR-ASH-011: Agent SHALL use .results on Ash.Page.Offset
page_result = Organization.list!(
  tenant: tenant.id,
  page: [limit: 10, offset: 0],
  actor: actor
)

# Extract list from struct
page = page_result.results  # Ash.Page.Offset has .results field

assert length(page) == 10  # Now works on list

# WRONG: Direct length on pagination result (EP-ASH-004)
page = Organization.list!(...)
assert length(page) == 10  # WRONG: page is Ash.Page.Offset, not list
```

#### 66.5.5 Correct Update Action Accept List (SC-ASH-010)
```elixir
# CORRECT: Include relationship IDs in accept list
# SC-ASH-010: Update action must accept parent_organization_id for hierarchy changes
# AOR-ASH-012: Agent SHALL include relationship IDs in update accept list
update :update do
  accept [:name, :code, :is_primary, :settings, :metadata, :active, :parent_organization_id]
  require_atomic? false
  primary? true
end

# WRONG: Missing relationship ID (EP-ASH-005)
update :update do
  accept [:name, :code, :is_primary, :settings, :metadata, :active]
  # Missing parent_organization_id - hierarchy changes will fail
end
```

### 66.6 Error Patterns (EP-ASH-001 to EP-ASH-005)

| EP ID | Pattern | Severity | Root Cause | Fix |
|-------|---------|----------|------------|-----|
| EP-ASH-001 | `query.context[:tenant]` as primary | CRITICAL | Ash 3.x API change | Use `query.tenant` first |
| EP-ASH-002 | Actor only in `Ash.update!/2` | CRITICAL | DomainRequiresActor not seeing actor | Pass actor to `for_update/3` |
| EP-ASH-003 | "name: is required" assertion | HIGH | Ash 3.x error format change | Use "attribute name is required" |
| EP-ASH-004 | `length()` on pagination result | CRITICAL | Ash.Page.Offset is struct | Access `.results` first |
| EP-ASH-005 | Missing relationship ID in accept | HIGH | Hierarchy updates fail | Add relationship_id to accept |

### 66.7 Validation Commands

```bash
# Validate Ash 3.x tenant access patterns
elixir scripts/validation/ash3_tenant_validator.exs --directory lib/indrajaal/

# Check actor passing patterns
elixir scripts/validation/ash3_actor_validator.exs --check-for-update

# Validate error message format in tests
elixir scripts/validation/ash3_error_format_validator.exs --test-directory test/

# Check pagination access patterns
elixir scripts/validation/ash3_pagination_validator.exs --check-results-accessor

# Comprehensive Ash 3.x compliance check
elixir scripts/validation/comprehensive_ash3_validator.exs --strict
```

### 66.8 LTL Safety Properties for Ash 3.x

- **LTL-ASH-1**: $\Box (\text{TenantAccess} \implies \text{UseQueryTenant})$
- **LTL-ASH-2**: $\Box (\text{UpdateWithActor} \implies \text{ActorInForUpdate})$
- **LTL-ASH-3**: $\Box (\text{ErrorAssertion} \implies \text{Ash3Format})$
- **LTL-ASH-4**: $\Box (\text{PaginationLength} \implies \text{AccessResults})$
- **LTL-ASH-5**: $\Box (\text{HierarchyUpdate} \implies \text{RelationshipInAccept})$

### 66.9 Telemetry Events

```elixir
# Ash 3.x API compliance telemetry (emits to Console + SigNoz)
[:indrajaal, :ash3, :tenant, :access_pattern]
[:indrajaal, :ash3, :actor, :passing_pattern]
[:indrajaal, :ash3, :error, :format_compliance]
[:indrajaal, :ash3, :pagination, :access_pattern]
[:indrajaal, :ash3, :compliance, :validated]
```

### 66.10 5-Level RCA Reference

**Root Cause Analysis for organization_test.exs Failures**:

| Level | EP-ASH-001 (Tenant) | EP-ASH-002 (Actor) | EP-ASH-004 (Pagination) |
|-------|---------------------|--------------------|-----------------------|
| L1 | Test assertion failing | DomainRequiresActor error | ArgumentError: not a list |
| L2 | Org2 from tenant2 in tenant1 results | Actor not seen by domain | `length()` called on struct |
| L3 | TenantResource checking wrong location | Actor passed to wrong function | Ash pagination returns struct |
| L4 | Ash 3.x stores tenant at `query.tenant` | `for_update/3` needs actor in options | `Ash.Page.Offset` has `.results` |
| L5 | API change not documented in migration | Ash 3.x authorization flow change | Type system change in pagination |

### 66.11 STAMP Constraint Count Update

**Updated STAMP Constraint Count**:
- Previous: $\mathcal{SC}_{166}$ (161 + 5 batch execution)
- New: $\mathcal{SC}_{176}$ (166 + 10 Ash 3.x API rules)

**Total Safety Framework**:
- 72 Core STAMP constraints (SC-VAL, SC-CNT, SC-AGT, etc.)
- 6 Agent code constraints (SC-AGT-025 to SC-AGT-030)
- 8 Integration constraints
- 40 Database constraints (SC-DB-001 to SC-DB-040)
- 5 PropCheck constraints
- 10 Original Ash constraints
- 20 Documentation constraints (SC-DOC-001 to SC-DOC-020)
- 5 Batch execution constraints (SC-BATCH-001 to SC-BATCH-005)
- **10 Ash 3.x API constraints (SC-ASH-001 to SC-ASH-010)** ← NEW

---

## 67.0 Factory and Test Data Generation Safety Rules (SC-FAC, TDG-FAC, AOR-FAC)

### 67.1 Overview and Purpose

**CRITICAL**: This section documents factory patterns for Ash Framework resources discovered during comprehensive domain testing (Session 20251211). ExMachina.EctoStrategy is INCOMPATIBLE with Ash resources due to `Ash.NotLoaded.__schema__/1` being undefined.

**Root Causes Identified** (5-Level RCA):
1. **ExMachina/Ash Incompatibility**: ExMachina calls `__schema__(:fields)` which Ash.NotLoaded doesn't implement
2. **Missing Factories**: 6 domains had missing factory definitions (SC-DB-021 violations)
3. **Actor Context Missing**: DomainRequiresActor errors in 4 domains
4. **Tenant Isolation**: Test data creation requires proper tenant association
5. **Relationship Dependencies**: Factories must create parent records before children

**Test Results That Drove This Section**:
| Domain | Tests | Failures | Root Cause |
|--------|-------|----------|------------|
| Sites | 277 | 0 | ✅ Using Ash.Changeset pattern |
| Core | 251 | 0 | ✅ Using Ash.Changeset pattern |
| Accounts | 176 | 125 | ExMachina/Ash.NotLoaded incompatibility |
| Alarms | 88 | 88 | DomainRequiresActor - missing actor |
| Access Control | 65 | 64 | ExMachina/Ash.NotLoaded incompatibility |
| Video | 223 | 100 | Missing camera/recording factories |
| Devices | 16 | 16 | Missing device factories + actor context |
| Guard Tours | 52 | 49 | Missing tour_route factories |
| Visitor Mgmt | 448 | 69 | Missing visitor factories |
| Analytics | N/A | Compile | 43 undefined variables |
| Performance | N/A | Compile | Undefined opts, int/2 |
| Observability | N/A | Compile | OTELLogger module mismatch |

### 67.2 STAMP Safety Constraints (SC-FAC-001 to SC-FAC-012)

#### Category S: Factory Architecture (SC-FAC-001 to SC-FAC-004)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-FAC-001 | System SHALL use Ash.Changeset.for_create pattern NOT ExMachina.EctoStrategy for Ash resources | Check factory implementation | CRITICAL |
| SC-FAC-002 | System SHALL define factory for EVERY Ash resource (extends SC-DB-021) | Check test/support/factories/ | CRITICAL |
| SC-FAC-003 | System SHALL use macro-based factory modules with `defmacro __using__(_)` | Check factory structure | HIGH |
| SC-FAC-004 | System SHALL import FactoryUtilities for helper functions | Check import statement | HIGH |

#### Category T: Actor and Tenant (SC-FAC-005 to SC-FAC-008)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-FAC-005 | System SHALL pass actor to ALL Ash.create/Ash.Changeset operations | Check actor: option | CRITICAL |
| SC-FAC-006 | System SHALL use `Indrajaal.ActorHelpers.admin_actor(tenant.id)` for admin operations | Check actor construction | HIGH |
| SC-FAC-007 | System SHALL handle tenant association via `handle_tenant_association/2` | Check tenant handling | CRITICAL |
| SC-FAC-008 | System SHALL support tenant_id lookup for existing tenants | Check tenant_id parameter | HIGH |

#### Category U: Dependencies and Relationships (SC-FAC-009 to SC-FAC-012)
| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-FAC-009 | System SHALL create parent records before child records (site before camera) | Check dependency order | CRITICAL |
| SC-FAC-010 | System SHALL allow passing existing parent via attrs (camera: existing_camera) | Check attrs handling | HIGH |
| SC-FAC-011 | System SHALL delete relationship keys from attrs before Ash.create | Check Map.delete calls | HIGH |
| SC-FAC-012 | System SHALL use sequence/2 for unique attribute generation | Check uniqueness | MEDIUM |

### 67.3 TDG Rules (TDG-FAC-001 to TDG-FAC-010)

**TDG Requirement**: Factory tests MUST pass before domain tests can be executed.

| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-FAC-001 | Factory test MUST exist before factory implementation | `test/support/factory_test.exs` | unit |
| TDG-FAC-002 | Each factory MUST have insert/1 integration test | Insert test | integration |
| TDG-FAC-003 | Factory attribute override MUST be tested | Override test | unit |
| TDG-FAC-004 | Factory parent record creation MUST be tested | Dependency test | integration |
| TDG-FAC-005 | Factory tenant isolation MUST be tested | Tenant test | integration |
| TDG-FAC-006 | Factory actor context MUST be tested | Actor test | unit |
| TDG-FAC-007 | Factory unique sequence MUST be tested | Sequence test | unit |
| TDG-FAC-008 | Factory error handling MUST be tested | Error test | unit |
| TDG-FAC-009 | Factory cleanup MUST be tested with sandbox | Cleanup test | integration |
| TDG-FAC-010 | Factory performance MUST be tested for bulk creation | Performance test | performance |

### 67.4 AOR Agent Rules (AOR-FAC-001 to AOR-FAC-015)

**Deontic Logic Operators**:
- $\mathbf{O}(\phi)$ - Agent MUST do $\phi$ (Obligation)
- $\mathbf{F}(\phi)$ - Agent MUST NOT do $\phi$ (Prohibition)
- $\mathbf{P}(\phi)$ - Agent MAY do $\phi$ (Permission)

#### Factory Architecture Rules (AOR-FAC-001 to AOR-FAC-005)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-FAC-001 | O(UseAshChangeset) | Agent SHALL use Ash.Changeset.for_create for Ash resources | SC-FAC-001 | CRITICAL | Yes |
| AOR-FAC-002 | F(UseExMachinaEcto) | Agent SHALL NOT use ExMachina.EctoStrategy for Ash resources | SC-FAC-001 | CRITICAL | Yes |
| AOR-FAC-003 | O(FactoryPerResource) | Agent SHALL create factory for every Ash resource | SC-FAC-002 | CRITICAL | Yes |
| AOR-FAC-004 | O(MacroFactory) | Agent SHALL use `defmacro __using__(_)` pattern | SC-FAC-003 | HIGH | Yes |
| AOR-FAC-005 | O(ImportUtilities) | Agent SHALL import FactoryUtilities | SC-FAC-004 | HIGH | Yes |

#### Actor and Tenant Rules (AOR-FAC-006 to AOR-FAC-010)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-FAC-006 | O(ActorInCreate) | Agent SHALL pass actor to Ash.Changeset.for_create | SC-FAC-005 | CRITICAL | Yes |
| AOR-FAC-007 | O(ActorInAshCreate) | Agent SHALL pass actor to Ash.create | SC-FAC-005 | CRITICAL | Yes |
| AOR-FAC-008 | O(AdminActorHelper) | Agent SHALL use ActorHelpers.admin_actor/1 | SC-FAC-006 | HIGH | Yes |
| AOR-FAC-009 | O(HandleTenantAssoc) | Agent SHALL use handle_tenant_association/2 | SC-FAC-007 | CRITICAL | Yes |
| AOR-FAC-010 | O(SupportTenantId) | Agent SHALL support tenant_id in attrs | SC-FAC-008 | HIGH | Yes |

#### Dependency Rules (AOR-FAC-011 to AOR-FAC-015)
| ID | Formal | Natural | STAMP | Severity | Auto-Fix |
|----|--------|---------|-------|----------|----------|
| AOR-FAC-011 | O(ParentFirst) | Agent SHALL create parent records before children | SC-FAC-009 | CRITICAL | No |
| AOR-FAC-012 | O(AllowExistingParent) | Agent SHALL allow passing existing parent records | SC-FAC-010 | HIGH | Yes |
| AOR-FAC-013 | O(CleanRelationshipKeys) | Agent SHALL delete :tenant, :site, etc. from attrs | SC-FAC-011 | HIGH | Yes |
| AOR-FAC-014 | O(UseSequence) | Agent SHALL use sequence/2 for uniqueness | SC-FAC-012 | MEDIUM | Yes |
| AOR-FAC-015 | O(NormalizeAttrs) | Agent SHALL normalize attrs with normalize_attrs/1 | SC-FAC-003 | HIGH | Yes |

### 67.5 Code Patterns and Examples

#### 67.5.1 Correct Factory Structure (SC-FAC-001, SC-FAC-003, SC-FAC-004)
```elixir
# CORRECT: Ash-compatible factory using Ash.Changeset pattern
import Indrajaal.Shared.FactoryUtilities

defmodule Indrajaal.VideoFactory do
  @moduledoc """
  Factory definitions for Video domain.
  SOPv5.11 Compliance: SC-DB-021, SC-FAC-001 (Ash.Changeset pattern)
  """

  defmacro __using__(_) do
    quote do
      @spec camera_factory(any()) :: any()
      def camera_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle site dependency (SC-FAC-009)
        site_id = cond do
          Map.has_key?(attrs_map, :site_id) -> attrs_map[:site_id]
          Map.has_key?(attrs_map, :site) -> attrs_map[:site].id
          true -> insert(:site, tenant: tenant).id
        end

        camera_attrs = %{
          name: sequence(:camera_name, &"Camera #{&1}"),
          # ... other attributes
          site_id: site_id,
          tenant_id: tenant.id
        }
        |> merge_attributes(attrs_map)
        |> Map.delete(:tenant)   # SC-FAC-011
        |> Map.delete(:site)     # SC-FAC-011

        # SC-FAC-005, SC-FAC-006: Actor context required
        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        # SC-FAC-001: Use Ash.Changeset pattern, NOT ExMachina.EctoStrategy
        {:ok, camera} =
          Indrajaal.Video.Camera
          |> Ash.Changeset.for_create(:create, camera_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        camera
      end
    end
  end
end

# WRONG: ExMachina.EctoStrategy (EP-FAC-001)
defmodule Indrajaal.Factory do
  use ExMachina.Ecto, repo: Indrajaal.Repo  # WRONG: Incompatible with Ash

  def camera_factory do
    %Indrajaal.Video.Camera{  # WRONG: Ash.NotLoaded.__schema__/1 undefined
      name: "Camera"
    }
  end
end
```

#### 67.5.2 Actor Context Pattern (SC-FAC-005, SC-FAC-006)
```elixir
# CORRECT: Actor in both for_create and Ash.create
admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

{:ok, record} =
  MyResource
  |> Ash.Changeset.for_create(:create, attrs, actor: admin_actor)  # Actor here
  |> Ash.create(actor: admin_actor)  # AND here

# WRONG: Missing actor (EP-FAC-002)
{:ok, record} =
  MyResource
  |> Ash.Changeset.for_create(:create, attrs)  # No actor - DomainRequiresActor!
  |> Ash.create()
```

#### 67.5.3 Tenant Association Pattern (SC-FAC-007, SC-FAC-008)
```elixir
# CORRECT: Using handle_tenant_association with tenant_id support
def my_factory(attrs \\ %{}) do
  attrs_map = normalize_attrs(attrs)
  # Supports: tenant: %Tenant{}, tenant_id: "uuid", or creates new tenant
  {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

  # Use tenant.id for attributes
  %{tenant_id: tenant.id, ...}
end

# Implementation in FactoryUtilities
def handle_tenant_association(attrs_map, module) do
  cond do
    Map.has_key?(attrs_map, :tenant) ->
      {attrs_map[:tenant], attrs_map}
    Map.has_key?(attrs_map, :tenant_id) ->
      # SC-FAC-008: Support tenant_id lookup
      tenant = load_tenant_by_id(attrs_map[:tenant_id])
      {tenant, attrs_map}
    true ->
      tenant = module.insert(:tenant)
      {tenant, attrs_map}
  end
end
```

### 67.6 Error Patterns (EP-FAC-001 to EP-FAC-008)

| EP ID | Pattern | Severity | Root Cause | Fix |
|-------|---------|----------|------------|-----|
| EP-FAC-001 | `Ash.NotLoaded.__schema__/1 is undefined` | CRITICAL | ExMachina.EctoStrategy incompatible | Use Ash.Changeset pattern |
| EP-FAC-002 | `DomainRequiresActor` | CRITICAL | Missing actor in Ash operations | Add actor: option |
| EP-FAC-003 | `undefined function camera_factory/1` | HIGH | Missing factory definition | Create factory |
| EP-FAC-004 | `foreign key constraint violation` | CRITICAL | Parent not created first | Create parent first |
| EP-FAC-005 | `tenant_id is required` | HIGH | Missing tenant handling | Use handle_tenant_association |
| EP-FAC-006 | `duplicate key value` | MEDIUM | Missing sequence for uniqueness | Use sequence/2 |
| EP-FAC-007 | `cannot encode Ash.NotLoaded` | HIGH | Trying to serialize unloaded | Load or create fresh |
| EP-FAC-008 | `relation :tenant does not exist` | HIGH | Passing struct to Ash.create | Delete :tenant from attrs |

### 67.7 Factory Completeness Matrix

**Required Factories by Domain** (SC-DB-021, SC-FAC-002):

| Domain | Resource | Factory | Status |
|--------|----------|---------|--------|
| Core | Tenant | tenant_factory | ✅ |
| Core | Organization | organization_factory | ✅ |
| Accounts | User | user_factory | ✅ |
| Accounts | Profile | profile_factory | ✅ |
| Sites | Site | site_factory | ✅ |
| Sites | Building | building_factory | ✅ |
| Sites | Floor | floor_factory | ✅ |
| Sites | Area | area_factory | ✅ |
| Sites | Zone | zone_factory | ✅ |
| Sites | Location | location_factory | ✅ |
| Video | Camera | camera_factory | ✅ |
| Video | Recording | recording_factory | ✅ |
| Video | VideoStream | stream_factory | ✅ |
| Video | Clip | clip_factory | ✅ |
| Devices | Sensor | sensor_factory | ✅ |
| Devices | Panel | panel_factory | ✅ |
| Devices | Device | device_factory | ✅ |
| Access Control | AccessCredential | access_credential_factory | ✅ |
| Access Control | AccessLevel | access_level_factory | ✅ |
| Access Control | AccessSchedule | access_schedule_factory | ✅ |
| Access Control | AccessGrant | access_grant_factory | ✅ |
| Visitor Mgmt | Visitor | visitor_factory | ⚠️ NEEDED |
| Visitor Mgmt | VisitorType | visitor_type_factory | ⚠️ NEEDED |
| Guard Tours | TourRoute | tour_route_factory | ⚠️ NEEDED |
| Guard Tours | Checkpoint | checkpoint_factory | ⚠️ NEEDED |
| Alarms | AlarmEvent | alarm_event_factory | ⚠️ REVIEW |

### 67.8 Validation Commands

```bash
# Validate factory completeness (SC-DB-021)
elixir scripts/validation/factory_completeness_validator.exs --all-domains

# Check for ExMachina.EctoStrategy violations (SC-FAC-001)
grep -r "use ExMachina.Ecto" test/support/ --include="*.ex"

# Validate actor context in factories (SC-FAC-005)
elixir scripts/validation/factory_actor_validator.exs --check-all

# Check factory structure compliance (SC-FAC-003)
elixir scripts/validation/factory_structure_validator.exs --macro-pattern

# Run factory tests
MIX_ENV=test mix test test/support/factory_test.exs
```

### 67.9 LTL Safety Properties for Factories

- **LTL-FAC-1**: $\Box (\text{AshResource} \implies \text{UseAshChangeset})$
- **LTL-FAC-2**: $\Box (\text{AshCreate} \implies \text{ActorProvided})$
- **LTL-FAC-3**: $\Box (\text{ChildFactory} \implies \diamond \text{ParentCreated})$
- **LTL-FAC-4**: $\Box (\text{FactoryCall} \implies \text{TenantIsolated})$
- **LTL-FAC-5**: $\Box \neg (\text{ExMachinaEcto} \wedge \text{AshResource})$

### 67.10 Telemetry Events

```elixir
# Factory telemetry (emits to Console + SigNoz)
[:indrajaal, :factory, :created, :resource_type]
[:indrajaal, :factory, :tenant, :associated]
[:indrajaal, :factory, :parent, :created]
[:indrajaal, :factory, :error, :ash_changeset]
[:indrajaal, :factory, :validation, :completed]
```

### 67.11 STAMP Constraint Count Update

**Updated STAMP Constraint Count**:
- Previous: $\mathcal{SC}_{176}$ (166 + 10 Ash 3.x API rules)
- New: $\mathcal{SC}_{188}$ (176 + 12 Factory rules)

**Total Safety Framework**:
- 72 Core STAMP constraints (SC-VAL, SC-CNT, SC-AGT, etc.)
- 6 Agent code constraints (SC-AGT-025 to SC-AGT-030)
- 8 Integration constraints
- 40 Database constraints (SC-DB-001 to SC-DB-040)
- 5 PropCheck constraints
- 10 Original Ash constraints
- 20 Documentation constraints (SC-DOC-001 to SC-DOC-020)
- 5 Batch execution constraints (SC-BATCH-001 to SC-BATCH-005)
- 10 Ash 3.x API constraints (SC-ASH-001 to SC-ASH-010)
- **12 Factory constraints (SC-FAC-001 to SC-FAC-012)** ← NEW
- **5 Migration Preflight constraints (SC-MIG-001 to SC-MIG-005)** ← NEW

---

## 68.0 Migration Preflight System Safety Rules (SC-MIG, TDG-MIG, AOR-MIG)

### 68.1 Overview and Purpose

**CRITICAL**: This section documents the Migration Preflight System that ensures all database tests have their required migrations executed before test execution. This prevents test failures due to schema mismatches (e.g., missing columns).

**Root Causes Addressed** (5-Level RCA):
- **L1 Surface**: Tests failing with "column X does not exist"
- **L2 Proximate**: Migration adding column not executed
- **L3 Contributing**: No automated verification of migration state
- **L4 Systemic**: Tests assume database schema without validation
- **L5 Root Cause**: Missing preflight migration verification system

**Implementation Files**:
- `test/support/migration_preflight.ex` - Core preflight verification module
- `test/support/migration_aware.ex` - Test module macro for declaring requirements
- `test/test_helper.exs` - Global preflight check on test suite start

### 68.2 OODA Loop Integration

The Migration Preflight System follows the OODA loop:

```
┌─────────────────────────────────────────────────────────────┐
│              MIGRATION PREFLIGHT OODA LOOP                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  OBSERVE: Query schema_migrations table                     │
│     └─► Get list of executed migration versions              │
│                                                              │
│  ORIENT: Compare against test's declared dependencies        │
│     └─► Identify missing/outdated migrations                 │
│                                                              │
│  DECIDE: Determine action based on state                     │
│     ├─► All migrations present → Proceed to tests            │
│     ├─► Migrations missing → Auto-migrate or fail            │
│     └─► Schema mismatch → Report and halt                    │
│                                                              │
│  ACT: Execute decision                                       │
│     └─► Run tests or report migration requirements           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 68.3 STAMP Safety Constraints (SC-MIG-001 to SC-MIG-005)

| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-MIG-001 | Database tests SHALL declare migration dependencies | Check for MigrationAware macro | CRITICAL |
| SC-MIG-002 | Preflight SHALL verify migrations before test execution | Check test_helper.exs global check | CRITICAL |
| SC-MIG-003 | Missing migrations SHALL cause immediate test failure | Check verify_requirements!/1 raises | HIGH |
| SC-MIG-004 | Migration tracking SHALL be version-controlled | Check MigrationRequirements struct | HIGH |
| SC-MIG-005 | Schema verification SHALL check required columns | Check verify_columns!/2 function | MEDIUM |

### 68.4 TDG Rules (TDG-MIG-001 to TDG-MIG-005)

**TDG Requirement**: Migration preflight tests MUST exist before implementation.

| ID | Rule | Test Pattern | Required Tests |
|----|------|--------------|----------------|
| TDG-MIG-001 | Preflight tests MUST exist before module implementation | `test/support/migration_preflight_test.exs` | unit |
| TDG-MIG-002 | Each test module MUST declare migration requirements | Check use MigrationAware | integration |
| TDG-MIG-003 | Preflight verification MUST be tested | Test verify_requirements!/1 | unit |
| TDG-MIG-004 | Auto-migration MUST be tested | Test ensure_all_migrations!/0 | integration |
| TDG-MIG-005 | Error messages MUST be clear and actionable | Test error format | unit |

### 68.5 AOR Agent Rules (AOR-MIG-001 to AOR-MIG-006)

**Deontic Logic Operators**:
- $\mathbf{O}(\phi)$ - Agent MUST do $\phi$ (Obligation)
- $\mathbf{F}(\phi)$ - Agent MUST NOT do $\phi$ (Prohibition)
- $\mathbf{P}(\phi)$ - Agent MAY do $\phi$ (Permission)

| ID | Formal | Natural | STAMP | Severity |
|----|--------|---------|-------|----------|
| AOR-MIG-001 | $\mathbf{O}(\text{DeclareMigrations})$ | Agent SHALL add `use MigrationAware` to new database test files | SC-MIG-001 | CRITICAL |
| AOR-MIG-002 | $\mathbf{O}(\text{RunPreflight})$ | Agent SHALL run preflight check before test execution | SC-MIG-002 | CRITICAL |
| AOR-MIG-003 | $\mathbf{F}(\text{SkipVerification})$ | Agent SHALL NOT skip migration verification | SC-MIG-002 | CRITICAL |
| AOR-MIG-004 | $\mathbf{O}(\text{UpdateRequirements})$ | Agent SHALL update migration requirements when schema changes | SC-MIG-004 | HIGH |
| AOR-MIG-005 | $\mathbf{O}(\text{DocumentDependencies})$ | Agent SHALL document table/column dependencies in test modules | SC-MIG-001 | HIGH |
| AOR-MIG-006 | $\mathbf{O}(\text{HandleMissingMigrations})$ | Agent SHALL handle missing migrations with clear error messages | SC-MIG-003 | MEDIUM |

### 68.6 Code Patterns and Examples

#### 68.6.1 Correct Test Module with Migration Requirements (SC-MIG-001)
```elixir
# CORRECT: Test module declares migration dependencies
defmodule Indrajaal.Accounts.TeamTest do
  use Indrajaal.DataCase
  use Indrajaal.Test.MigrationAware,
    tables: [:teams, :team_memberships, :users, :tenants],
    columns: %{
      teams: [:id, :name, :permissions, :tenant_id]
    }

  # Tests run only if migrations are satisfied
  describe "team creation" do
    # ...
  end
end

# WRONG: No migration requirements declared (EP-MIG-001)
defmodule Indrajaal.Accounts.TeamTest do
  use Indrajaal.DataCase
  # Missing: use Indrajaal.Test.MigrationAware

  # Tests may fail with "column X does not exist"
end
```

#### 68.6.2 Migration Requirements Data Structure (SC-MIG-004)
```elixir
@migration_requirements %MigrationRequirements{
  # Minimum migration version required
  minimum_version: "20251216135420",

  # Specific migrations this test depends on
  required_migrations: [
    "20251216135420_add_permissions_to_teams"
  ],

  # Tables this test uses
  required_tables: [:teams, :team_memberships, :users, :tenants],

  # Required columns per table
  required_columns: %{
    teams: [:id, :name, :permissions, :tenant_id]
  }
}
```

#### 68.6.3 Global Preflight Check (SC-MIG-002)
```elixir
# In test_helper.exs - runs before any tests
Application.ensure_all_started(:indrajaal)
Indrajaal.Test.GlobalMigrationPreflight.run!()
ExUnit.start()
```

### 68.7 Error Patterns (EP-MIG-001 to EP-MIG-005)

| EP ID | Pattern | Severity | Root Cause | Fix |
|-------|---------|----------|------------|-----|
| EP-MIG-001 | `column "X" does not exist` | CRITICAL | Migration not run | Run `mix ecto.migrate` |
| EP-MIG-002 | Missing MigrationAware macro | HIGH | Test doesn't declare dependencies | Add `use MigrationAware` |
| EP-MIG-003 | Preflight not running | CRITICAL | test_helper.exs not updated | Add GlobalMigrationPreflight.run!() |
| EP-MIG-004 | Schema drift between tests | MEDIUM | Inconsistent migration state | Run all migrations before tests |
| EP-MIG-005 | Missing required table | CRITICAL | Migration creates table not run | Check migration order |

### 68.8 LTL Safety Properties for Migration Preflight

- **LTL-MIG-1**: $\Box (\text{TestStart} \implies \text{PreflightComplete})$
- **LTL-MIG-2**: $\Box (\text{MigrationMissing} \implies \diamond \text{ErrorReported})$
- **LTL-MIG-3**: $\Box (\text{DatabaseTest} \implies \text{RequirementsDeclared})$
- **LTL-MIG-4**: $\Box \neg (\text{TestRun} \wedge \neg \text{MigrationsCurrent})$
- **LTL-MIG-5**: $\Box (\text{SchemaChange} \implies \diamond \text{RequirementsUpdated})$

### 68.9 Validation Commands

```bash
# Verify all migrations are current
mix ecto.migrations

# Run pending migrations
mix ecto.migrate

# Check migration preflight in tests
MIX_ENV=test mix test test/indrajaal/accounts/team_test.exs --trace

# Validate preflight module exists
ls -la test/support/migration_preflight.ex test/support/migration_aware.ex
```

### 68.10 STAMP Constraint Count Update

**Updated STAMP Constraint Count**:
- Previous: $\mathcal{SC}_{188}$ (176 + 12 Factory rules)
- New: $\mathcal{SC}_{193}$ (188 + 5 Migration Preflight rules)

**Total Safety Framework**:
- 72 Core STAMP constraints (SC-VAL, SC-CNT, SC-AGT, etc.)
- 6 Agent code constraints (SC-AGT-025 to SC-AGT-030)
- 8 Integration constraints
- 40 Database constraints (SC-DB-001 to SC-DB-042)
- 5 PropCheck constraints
- 10 Original Ash constraints
- 20 Documentation constraints (SC-DOC-001 to SC-DOC-020)
- 5 Batch execution constraints (SC-BATCH-001 to SC-BATCH-005)
- 10 Ash 3.x API constraints (SC-ASH-001 to SC-ASH-010)
- 12 Factory constraints (SC-FAC-001 to SC-FAC-012)
- **5 Migration Preflight constraints (SC-MIG-001 to SC-MIG-005)** ← NEW

---

## 70.0 Gemini Intelligent Message Management Protocol (SC-GEM-API)

### 70.1 Core Mandates for API Efficiency
To prevent "Context Press" threshold violations and ensure API stability, Gemini MUST adhere to the following protocols:

1.  **Conciseness First**: Responses MUST be strictly minimal unless verbose explanation is explicitly requested.
2.  **Token Economy**: Avoid repeating large blocks of code or context. Reference files by path instead of re-reading them unnecessarily.
3.  **Structured Output**: Prefer structured data (JSON, lists) over conversational text for complex data reporting.
4.  **Context Hygiene**: Do not save redundant information to long-term memory. Clean up temporary artifacts.

### 70.2 API Safety Constraints (SC-GEM-API-001 to SC-GEM-API-005)

| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-GEM-API-001 | Gemini SHALL NOT output more than 200 lines of text per turn without user confirmation | Output check | HIGH |
| SC-GEM-API-002 | Gemini SHALL summarize file contents instead of dumping >1000 lines | `read_file` limit check | MEDIUM |
| SC-GEM-API-003 | Gemini SHALL prioritize `codebase_investigator` over massive `glob` + `read` loops | Tool usage pattern | HIGH |
| SC-GEM-API-004 | Gemini SHALL use `search_file_content` for targeted retrieval | Tool usage pattern | MEDIUM |
| SC-GEM-API-005 | Gemini SHALL monitor internal "Context Press" indicators | Self-monitoring | CRITICAL |

---

## 71.0 Gemini Agent Operating Protocols (AOP)

### 71.1 The Cybernetic Architect Persona (Gemini Edition)
Gemini acts not just as a coder, but as a **Cybernetic Architect**.
-   **Holistic View**: Always consider the impact of a change on the entire system ($G=(V,E)$).
-   **Anti-Entropy**: Actively reduce complexity. If a simpler solution exists, propose it.
-   **Safety First**: Never bypass safety gates (STAMP, TDG) for speed.

### 71.2 Operational Rules (AOP-GEM-001 to AOP-GEM-005)

| ID | Formal | Natural | Severity |
|----|--------|---------|----------|
| AOP-GEM-001 | $\mathbf{O}(\text{Plan} \implies \text{Verify})$ | Gemini SHALL verify the plan before execution | CRITICAL |
| AOP-GEM-002 | $\mathbf{O}(\text{Change} \implies \text{Test})$ | Gemini SHALL ensure tests cover changes | CRITICAL |
| AOP-GEM-003 | $\mathbf{F}(\text{HallucinateAPI})$ | Gemini SHALL NOT invent APIs; check docs/source | CRITICAL |
| AOP-GEM-004 | $\mathbf{O}(\text{AdhereToStyle})$ | Gemini SHALL mimic existing project style | HIGH |
| AOP-GEM-005 | $\mathbf{O}(\text{LogActions})$ | Gemini SHALL log significant state changes | MEDIUM |

---

## 72.0 Gemini STAMP Safety Constraints (SC-GEM)

### 72.1 Critical Safety Rules
These constraints are specific to the Gemini agent's interaction with the Indrajaal system.

| ID | Constraint | Verification | Severity |
|----|------------|--------------|----------|
| SC-GEM-001 | Gemini SHALL NOT execute shell commands with `rm -rf` on unverified paths | Command analysis | CRITICAL |
| SC-GEM-002 | Gemini SHALL NOT modify `CLAUDE.md`, `GEMINI.md` or core specs without explicit user instruction | File lock check | CRITICAL |
| SC-GEM-003 | Gemini SHALL always run `mix format` after code generation | Post-action check | HIGH |
| SC-GEM-004 | Gemini SHALL respect `.gitignore` and `.geminiignore` boundaries | File access check | MEDIUM |
| SC-GEM-005 | Gemini SHALL validate all generated Elixir code with `mix compile` | Compilation gate | CRITICAL |
| SC-GEM-006 | Gemini SHALL NOT commit code that fails STAMP safety checks | Pre-commit check | CRITICAL |
| SC-GEM-007 | Gemini SHALL ensure AIE context is fresh (`mix gemini.context`) before complex tasks | Context freshness | HIGH |

---

## 73.0 The Cybernetic Architect Persona (Formal Specification)
**Principle**: Safety constraints are the *physics* that limit the search space of evolution to survivable states.

| ID | Constraint | Severity |
|----|------------|----------|
| **SC-CA-001** | The Architect SHALL NOT authorize a state transition ($S \to S'$) without passing ALL Quality Gates | CRITICAL |
| **SC-CA-002** | The Architect SHALL triggers Jidoka (Immediate Halt) if $\eta(S') > \eta(S) + \text{Threshold}$ | HIGH |
| **SC-CA-003** | The Architect SHALL maintain "Safety Margins" (Coverage > 95%, Warnings = 0) at all times | CRITICAL |
| **SC-CA-004** | The Architect SHALL NOT introduce cyclic dependencies in the System Graph $\mathcal{G}$ | CRITICAL |
| **SC-CAP-005** | Agent SHALL execute `smart_system_state.exs` before proposing any architectural change > 5 files. | HIGH |
| **SC-CAP-006** | Agent SHALL NOT proceed to "Act" phase if "Observe" phase reports Critical Integrity Failure. | CRITICAL |
| **SC-CAP-007** | Smart Reporting scripts MUST execute within < 2000ms to ensure tight OODA loops. | MEDIUM |

### 74.4 Agent Operating Rules (AOR-CA)
**Principle**: Behavioral mandates for high-velocity, safe decision making.

| ID | Formal Logic | Natural Language |
|----|--------------|------------------|
| **AOR-CA-001** | $\mathbf{O}(\text{Action} \implies \text{FreshContext})$ | Agent MUST refresh `mix gemini.context` before ANY complex decision |
| **AOR-CA-002** | $\mathbf{O}(\text{Decide} \implies \min(\mathcal{K}))$ | Agent MUST select the solution path with minimal Kolmogorov Complexity |
| **AOR-CA-003** | $\mathbf{O}(\text{Fail} \implies \text{Learn})$ | Agent MUST log root cause of any failure to `docs/journal/` immediately |
| **AOR-CA-004** | $\mathbf{F}(\text{Hesitate})$ | Agent SHALL NOT wait for user confirmation on safe, reversible, verified ops |
| **AOR-CAP-005** | $\mathbf{O}(\text{Plan} \implies \text{State})$ | Agent MUST ground plans in state from `smart_system_state.exs` |
| **AOR-CAP-006** | $\mathbf{O}(\text{Act} \implies \text{Verify})$ | Agent MUST re-run reporting script after Acting to close the loop |
| **AOR-CAP-007** | $\mathbf{O}(\text{Telemetry})$ | Agent MUST inject "Decision ID" into Smart Report requests |

### 74.5 Goal-Directed Evolution (GDE) Algorithm
**Objective**: Rapidly converge on User Goal $G_{user}$ through iterative refinement.

**Algorithm**:
1.  **Hypothesize**: Generate candidate transition $T = S \to S_{next}$.
2.  **Simulate**: Evaluate $P(\text{Success}|T)$ using Knowledge Base + STAMP Constraints.
3.  **Select**: Choose $T$ that maximizes $Value(S_{next})$ while satisfying $\Psi$ (Safety).
4.  **Execute**: Perform $T$ using AEE tools (Act).
5.  **Verify**: Check if $S_{realized} \approx S_{next}$ (Observe).
6.  **Loop**: Goto 1.

### 74.6 Execution Contexts

*   **Dev Time**: Focus on $\min(\chi)$ (Decoupling) and $\min(\mathcal{K})$ (Simplicity) to enable future speed.
*   **Test Time**: Focus on *stress testing* the constraints $\Psi$ to ensure the system is Anti-Fragile.
*   **Runtime**: Focus on $\min(\delta_{ooda})$ (Speed) and Homeostasis (Stability).

## 75.0 Cybernetic Mode Execution Protocols (User Mandate 2025-12-15)

### 75.1 The 30-Second Mandate
**Constraint**: The System (Build + Startup) SHALL complete within 30 seconds ({startup} \le 30s$).
**Verification**:
841869 	ext{Time}(	ext{mix compile}) + 	ext{Time}(	ext{mix phx.server}) \le 30s 841869
**Action on Violation**: Immediate analysis of boot time/compilation drag. Optimization required.

### 75.2 Max Parallelism Mode
**Constraint**: All execution MUST utilize maximum hardware concurrency.
**Configuration**:
- `ELIXIR_ERL_OPTIONS="+S 16"` (or max cores)
- `mix test --max-cases 100` (if safe) or `mix test --parallel`
- Asynchronous task execution where dependency graph permits.

### 75.3 Adaptive Model Selection Strategy
The Agent SHALL select the underlying model based on task complexity ({task}$):
- **High Complexity ({task} > 	au_{high}$)**: Use **Pro** (gemini-3-pro-preview, gemini-2.5-pro).
    - Use cases: 5-Level RCA, Architectural Refactoring, System-wide Dependency Analysis.
- **Medium Complexity ($	au_{low} < C_{task} \le 	au_{high}$)**: Use **Flash** (gemini-2.5-flash).
    - Use cases: Test execution, Standard Compilation, Pattern Matching, Routine Fixes.
- **Low Complexity ({task} \le 	au_{low}$)**: Use **Flash-Lite** (gemini-2.5-flash-lite).
    - Use cases: Status checks, File listing, Simple grep searches.

### 75.4 Fast OODA Loop Protocol
**Objective**: Minimize the time between Observation (Error) and Action (Fix).
**Loop**:
1.  **Observe**: Run tests/compile.
2.  **Orient**: If failure, classify (Simple vs Complex).
3.  **Decide**: Select Model (Flash/Pro) and Strategy (Quick Fix vs 5-Level RCA).
4.  **Act**: Execute Fix.
5.  **Loop**: Repeat.

## 76.0 Tool Configuration & Safety (SC-ENV)

### 76.1 Directory Exclusion List
The following directories contain binary data, large datasets, or are permission-restricted. They MUST be excluded from all file search and traversal operations (`grep`, `rg`, `find`, `ls -R`) to prevent permission errors and performance degradation.

- `data/timescaledb` (Permission Restricted / Database Data)
- `.git` (Version Control History)
- `_build` (Compiled Artifacts)
- `deps` (Dependencies)
- `node_modules` (JavaScript Dependencies)
- `.elixir_ls` (Language Server Cache)
- `.lexical` (Lexical Cache)
- `priv/static` (Generated Assets)

### 76.2 Safe Search Commands
**Use these patterns for all searches:**

**Ripgrep (rg):**
```bash
rg "pattern" . \
  --glob '!data/timescaledb' \
  --glob '!_build' \
  --glob '!deps' \
  --glob '!node_modules' \
  --glob '!.git' \
  --glob '!.elixir_ls' \
  --glob '!.lexical' \
  --glob '!priv/static'
```

**Grep:**
```bash
grep -r "pattern" . \
  --exclude-dir=data/timescaledb \
  --exclude-dir=_build \
  --exclude-dir=deps \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=.elixir_ls \
  --exclude-dir=.lexical \
  --exclude-dir=priv/static
```

## 77.0 Smart Reporting & OODA Integration (SRI)

### 77.1 The OODA Mandate
**Constraint**: The Agent SHALL NOT make complex decisions (Plan/Decide phase) without first acquiring fresh System State (Observe phase).

**Protocol**:
1.  **Trigger**: User request involves state change or debugging.
2.  **Observe**: Execute `elixir scripts/reporting/smart_system_state.exs`.
3.  **Orient**: Analyze the JSON output against Quality Gates (Axiom 3).
4.  **Decide**: Formulate plan based on *actual* state, not assumed state.
5.  **Act**: Execute plan.

### 77.2 System State Schema (JSON)
The `smart_system_state.exs` output MUST adhere to:
```json
{
  "timestamp": "ISO8601",
  "phase": "development|testing|deployment",
  "quality_gates": {
    "compilation": "pass|fail",
    "tests": "pass|fail|skipped",
    "format": "pass|fail"
  },
  "context": {
    "git_branch": "feature/...",
    "open_files": [],
    "recent_errors": []
  }
}
```

## 78.0 Formal Verification Test Strategy

> **Reference Document**: `docs/testing/comprehensive-formal-verification-test-strategy.md`
> **Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131

### 78.1 Three-Layer Verification Pyramid

**Verification Layers**:
```
Layer 3 (Top): AGDA - Eternal Constructive Proofs
├── Purpose: Core invariant proofs that hold for ALL executions
├── Scope: Axioms, safety properties, termination guarantees
├── Guarantee: ∀ executions (infinite)
└── Files: docs/formal_specs/agda_proofs.agda

Layer 2 (Middle): QUINT - Bounded State Exploration
├── Purpose: Model checking state machines + LTL properties
├── Scope: State transitions, temporal logic, counterexamples
├── Guarantee: Up to N steps (configurable)
└── Files: docs/formal_specs/quint_specifications.qnt

Layer 1 (Base): ExUnit - Runtime Validation
├── Purpose: Empirical testing of STAMP/FMEA/Temporal properties
├── Scope: All 286+ formal verification tests
├── Guarantee: Empirical coverage
└── Files: test/indrajaal/**/*_test.exs
```

**Verification Flow**:
1. **Mathematica** → WHAT (Specification in formal notation)
2. **Quint** → WHETHER (Bounded model checking)
3. **Agda** → FOREVER (Constructive proof for eternity)
4. **ExUnit** → RUNTIME (Empirical validation on execution)

### 78.2 STAMP/STPA Unsafe Control Action (UCA) Constraints

**UCA Categories**:
| Type | Description |
|------|-------------|
| UCA-TYPE-1 | Control action NOT provided when needed |
| UCA-TYPE-2 | Control action provided when NOT needed |
| UCA-TYPE-3 | Control action provided too early/late |
| UCA-TYPE-4 | Control action stopped too soon/applied too long |

**Critical UCAs for Formal Verification**:

| ID | Type | Action | Hazard | STAMP |
|----|------|--------|--------|-------|
| UCA-CLU-001 | TYPE-1 | Quorum check not performed before write | Data corruption in minority partition | SC-CLU-001 |
| UCA-CLU-002 | TYPE-3 | Partition detection delayed >10s | Split-brain with conflicting writes | SC-CLU-005 |
| UCA-VAL-001 | TYPE-1 | Consensus check skipped | EP-110 false positive (0 errors when 372 exist) | SC-VAL-003 |
| UCA-VAL-002 | TYPE-2 | Success reported without all methods agreeing | Defective code deployed | SC-VAL-004 |
| UCA-SEC-001 | TYPE-1 | JWT validation skipped | Unauthorized access to protected resources | SC-SEC-001 |
| UCA-SEC-002 | TYPE-3 | Token refresh delayed beyond expiry | Session hijacking window | SC-SEC-003 |
| UCA-DEV-001 | TYPE-4 | Failsafe mode released prematurely | Unsafe device operation | SC-DEV-001 |
| UCA-DEV-002 | TYPE-1 | Anti-passback check not enforced | Tailgating security breach | SC-AGT-018 |
| UCA-FLAME-001 | TYPE-4 | Runner terminated before drain complete | Data loss, orphaned computations | SC-FLAME-004 |
| UCA-FLAME-002 | TYPE-2 | Scale-up without resource verification | Resource exhaustion, cascading failure | SC-FLAME-003 |

**UCA Test Requirement**:
∀ uca ∈ CriticalUCAs : ∃ test ∈ TestSuite : Covers(test, uca) ∧ STAMPConstrained(test)

### 78.3 FMEA Risk Priority Analysis

**FMEA Calculation**: RPN = Severity × Occurrence × Detection

**Severity Scale**: 1=Minor, 5=Moderate, 8=High, 10=Critical
**Occurrence Scale**: 1=Rare, 3=Low, 5=Moderate, 7=High, 10=Certain
**Detection Scale**: 1=Almost Certain, 3=High, 5=Moderate, 7=Low, 10=None

**RPN Thresholds**:
| Level | RPN Range | Action |
|-------|-----------|--------|
| Critical | RPN > 100 | Immediate action required |
| High | 50 < RPN ≤ 100 | Priority improvement |
| Medium | 20 < RPN ≤ 50 | Scheduled improvement |
| Low | RPN ≤ 20 | Monitor only |

**Critical Failure Modes**:

| ID | Component | Failure Mode | Effect | S | O | D | RPN | Controls |
|----|-----------|--------------|--------|---|---|---|-----|----------|
| PFH-FMEA-001 | Power Supply | Complete power loss | System offline, alarm failure | 10 | 2 | 2 | 40 | UPS backup, redundant supplies |
| PFH-FMEA-002 | Battery Monitoring | Low battery undetected | Silent system failure | 8 | 2 | 3 | 48 | Redundant sensors, 15-min alerts |
| TDH-FMEA-001 | Cable/Tamper Detection | Tamper switch bypass | Undetected intrusion | 9 | 3 | 4 | 108* | End-of-line resistors, line monitoring |
| NWF-FMEA-001 | Network Communication | Central station disconnect | Alarm not reported | 9 | 3 | 2 | 54 | Dual-path transmission, heartbeat |

*CRITICAL - requires immediate mitigation

**FMEA Test Requirement**:
∀ fm ∈ CriticalFailureModes : (fm.RPN > 50) ⟹ ∃ test : MitigationVerified(test, fm)

### 78.4 Verification Gates (G1-G5)

**Five-Gate Verification Pipeline**:

| Gate | Name | Purpose | Actions | Pass Criteria | Blocking |
|------|------|---------|---------|---------------|----------|
| G1 | Specification Validity | Verify formal specs parse and typecheck | `quint parse`, `quint typecheck` | Exit code 0, no errors | Yes |
| G2 | Proof Verification | Verify Agda proofs are constructive | `agda --safe`, check zero postulates | Typechecks, no postulates | Yes |
| G3 | Property Verification | Model check safety/liveness | `quint verify --invariant=*` | No counterexamples | Yes |
| G4 | Safety Analysis | Execute STAMP/FMEA/LTL tests | `mix test` (286+ tests) | All tests pass | Yes |
| G5 | Audit Trail | Generate compliance documentation | Generate report, archive | Report generated | No (releases only) |

**Gate Dependency Graph**:
- G2 depends on G1
- G3 depends on G1
- G4 depends on G1
- G5 depends on G1, G2, G3, G4

**Gate Enforcement Rule**:
∀ g ∈ {G1, G2, G3, G4} : ¬Pass(g) ⟹ BlockMerge ∧ BlockDeploy

### 78.5 AOR Rules for Formal Verification

**Agent Operating Rules (AOR-FV-001 to AOR-FV-006)**:

| Rule | Description |
|------|-------------|
| AOR-FV-001 | Formal verification test MUST map to three-layer pyramid |
| AOR-FV-002 | New STAMP constraint MUST add corresponding Quint property |
| AOR-FV-003 | Safety-critical change MUST run gates G1-G4 |
| AOR-FV-004 | FORBIDDEN: Merge with failing gate |
| AOR-FV-005 | FMEA critical (RPN>50) MUST have mitigation test |
| AOR-FV-006 | Identified UCA MUST have STAMP constraint |

**Three-Layer Mapping Requirement**:
∀ test ∈ FormalVerificationTests :
  ∃ (math, quint, agda) : MathematicaSpec(math, test) ∧ QuintModule(quint, test) ∧ AgdaProof(agda, test)

**Gate Block Enforcement**:
□[¬Pass(G1) ∨ ¬Pass(G2) ∨ ¬Pass(G3) ∨ ¬Pass(G4) ⟹ ¬MergeAllowed]

### 78.6 TDG Rules for Test-First Verification

**Test-Driven Generation Rules (TDG-FV-001 to TDG-FV-005)**:

| Rule | Description |
|------|-------------|
| TDG-FV-001 | Quint spec MUST precede implementation |
| TDG-FV-002 | Agda proof MUST precede production use |
| TDG-FV-003 | ExUnit test MUST map to STAMP constraint |
| TDG-FV-004 | State transition MUST be Quint-verified |
| TDG-FV-005 | Safety invariant MUST be Agda-proven |

**Specification-First Workflow**:
1. **Mathematica**: Define formal notation
2. **Quint**: Translate to executable model
3. **Verify**: `quint verify --invariant=<name>`
4. **ExUnit**: Implement runtime tests
5. **Code**: Implement production code
6. **Agda**: Prove eternal guarantee (critical paths)

### 78.7 Test Suite Coverage Requirements

**Formal Verification Test Suite (286 tests total)**:

| Suite | File | Tests | STAMP Constraints | Standards |
|-------|------|-------|-------------------|-----------|
| SIL Compliance | test/indrajaal/compliance/sil_compliance_test.exs | 41 | SC-SIL-001..010 | IEC 61508 SIL-2 |
| Device Failsafe | test/indrajaal/devices/device_failsafe_test.exs | 54 | SC-DEV-001..010 | EN 50131 |
| Auth Security | test/indrajaal/authentication/auth_security_test.exs | 52 | SC-SEC-001..010 | ISO 27001 |
| FMEA Hazard | test/indrajaal/safety/fmea_hazard_analysis_test.exs | 21 | SC-FMEA-001..003 | IEC 60812 |
| FPPS Consensus | test/indrajaal/validation/fpps_consensus_test.exs | 38 | SC-VAL-003, SC-VAL-004 | EP-110 Prevention |
| RBAC State Machine | test/indrajaal/access_control/rbac_state_machine_test.exs | 51 | SC-AGT-018 | Deadlock-free |
| Safety Comm | test/indrajaal/communication/safety_critical_comm_test.exs | 29 | SC-LTL-001..004 | Alarm Delivery |

**Coverage Requirement**:
(PassingTests / TotalTests) = 1.0 ∧ ∀ sc ∈ ReferencedSTAMP : ∃ test : Covers(test, sc)

### 78.8 Verification Commands

**Gate 1: Specification Validity**
```bash
quint parse docs/formal_specs/quint_specifications.qnt
quint typecheck docs/formal_specs/quint_specifications.qnt
```

**Gate 2: Proof Verification**
```bash
agda --safe docs/formal_specs/agda_proofs.agda
grep -E "^\\s*postulate\\s+" docs/formal_specs/agda_proofs.agda | wc -l  # Must be 0
```

**Gate 3: Property Verification**
```bash
quint verify --invariant=masterInvariant --max-steps=100 docs/formal_specs/quint_specifications.qnt
```

**Gate 4: Safety Analysis (All Tests)**
```bash
MIX_ENV=test mix test \
  test/indrajaal/compliance/sil_compliance_test.exs \
  test/indrajaal/devices/device_failsafe_test.exs \
  test/indrajaal/authentication/auth_security_test.exs \
  test/indrajaal/safety/fmea_hazard_analysis_test.exs \
  test/indrajaal/validation/fpps_consensus_test.exs \
  test/indrajaal/access_control/rbac_state_machine_test.exs \
  test/indrajaal/communication/safety_critical_comm_test.exs
```

## 79.0 Claude Code Session Integration Protocol

### 79.1 Session Synchronization

**Purpose**: Ensure Claude Code sessions maintain bidirectional sync with PROJECT_TODOLIST.md

**Session Events**:
| Event | Action | STAMP Constraint |
|-------|--------|------------------|
| Session Start | Load PROJECT_TODOLIST.md active tasks | SC-TODO-004 |
| Task Create | Export to PROJECT_TODOLIST.md | SC-TODO-006 |
| Task Complete | Update PROJECT_TODOLIST.md | SC-TODO-007 |
| Session End | Export all session tasks | SC-TODO-005 |

### 79.2 STAMP Constraints for Todo Management (SC-TODO-001 to SC-TODO-010)

**Core Constraints (SC-TODO-001 to SC-TODO-003)**:
| ID | Constraint |
|----|------------|
| SC-TODO-001 | FORBIDDEN: Direct modification of PROJECT_TODOLIST.md |
| SC-TODO-002 | Todo operations MUST use `mix todo` commands |
| SC-TODO-003 | Todo updates MUST go through `scripts/planning/todolist_manager.exs` |

**Extended Sync Constraints (SC-TODO-004 to SC-TODO-010)**:
| ID | Constraint |
|----|------------|
| SC-TODO-004 | Session start MUST sync to Claude session |
| SC-TODO-005 | Session end MUST sync from Claude session |
| SC-TODO-006 | New task MUST export to project todolist |
| SC-TODO-007 | Task complete MUST update project todolist |
| SC-TODO-008 | System MUST maintain audit trail of todo operations |
| SC-TODO-009 | FORBIDDEN: Lose task state |
| SC-TODO-010 | Conflict detected MUST preserve project state |

### 79.3 Forbidden Todo Actions

**Actions that violate SC-TODO constraints**:
- `Edit["PROJECT_TODOLIST.md"]` - FORBIDDEN (SC-TODO-001)
- `Bash["sed", "PROJECT_TODOLIST.md"]` - FORBIDDEN (SC-TODO-001)
- `Bash["echo >> PROJECT_TODOLIST.md"]` - FORBIDDEN (SC-TODO-001)
- Manual status updates bypassing mix todo - FORBIDDEN (SC-TODO-002)
- Direct file writes to todolist - FORBIDDEN (SC-TODO-003)

### 79.4 Canonical Todo Commands

**Status & Query**:
```bash
elixir scripts/planning/todolist_manager.exs --status
elixir scripts/planning/todolist_manager.exs --find KEYWORD
elixir scripts/planning/todolist_manager.exs --working-set
```

**Updates**:
```bash
elixir scripts/planning/todolist_manager.exs --update TASK_ID STATUS
elixir scripts/planning/todolist_manager.exs --backup
elixir scripts/planning/todolist_manager.exs --validate
```

**Claude Session Sync**:
```bash
elixir scripts/planning/claude_todo_sync.exs --sync --from-claude
elixir scripts/planning/claude_todo_sync.exs --sync --to-claude
elixir scripts/planning/claude_todo_sync.exs --export-session
elixir scripts/planning/claude_todo_sync.exs --verify
```

### 79.5 AOR Rules for Todo Management (AOR-TODO-001 to AOR-TODO-010)

| Rule | Description |
|------|-------------|
| AOR-TODO-001 | FORBIDDEN: Edit PROJECT_TODOLIST.md directly |
| AOR-TODO-002 | FORBIDDEN: Use sed/awk on PROJECT_TODOLIST.md |
| AOR-TODO-003 | Todo status MUST use mix todo.status |
| AOR-TODO-004 | Todo update MUST use mix todo.update |
| AOR-TODO-005 | TodoWrite used MUST trigger project sync |
| AOR-TODO-006 | Session resume MUST load project tasks |
| AOR-TODO-007 | Task priority MUST detect from content (P0-P4) |
| AOR-TODO-008 | Safety-critical task MUST be Priority P0 |
| AOR-TODO-009 | FORBIDDEN: Modify completed project task |
| AOR-TODO-010 | Hierarchical numbering MUST be preserved |

### 79.6 Session Protocol Workflow

**On Session Start**:
1. Load PROJECT_TODOLIST.md active tasks
2. Import to Claude session context
3. Display working set to user
4. Log session start to audit

**On Task Create**:
1. Detect priority from content keywords
2. Generate hierarchical task ID
3. Export to PROJECT_TODOLIST.md via todolist_manager
4. Log task creation to audit

**On Task Complete**:
1. Update Claude session status
2. Update PROJECT_TODOLIST.md via todolist_manager
3. Log completion to audit
4. Check parent task rollup

**On Session End**:
1. Export all session tasks to project
2. Create session backup
3. Log session summary to audit
4. Verify consistency

### 79.7 LTL Properties for Todo Sync

**Safety Properties**:
- □[SyncStarted ⟹ (TaskCount[Before] ≤ TaskCount[After])] - No task loss
- □[TodoOperation ⟹ ◇AuditLogged] - All operations logged

**Liveness Properties**:
- □[SyncStarted ⟹ ◇SyncCompleted] - Sync eventually completes
- □[Inconsistency ⟹ ◇Consistent] - Eventually consistent

## 80.0 Claude API Efficiency Constraints (SC-CLAUDE-API)

### 80.1 Context Management Safety

**STAMP Constraints for Claude API (SC-CLAUDE-API-001 to SC-CLAUDE-API-005)**:

| ID | Constraint | Description |
|----|------------|-------------|
| SC-CLAUDE-API-001 | Output < 200 lines | Prevent context overflow |
| SC-CLAUDE-API-002 | Summarize files > 1000 lines | Preserve context budget |
| SC-CLAUDE-API-003 | Use Task agents for complex work | Delegate to sub-agents |
| SC-CLAUDE-API-004 | Use Grep for targeted retrieval | Efficient file searching |
| SC-CLAUDE-API-005 | Monitor context pressure | Track token usage |

### 80.2 Claude STAMP Constraints (SC-CLAUDE-001 to SC-CLAUDE-007)

| ID | Constraint |
|----|------------|
| SC-CLAUDE-001 | FORBIDDEN: Execute rm -rf unverified |
| SC-CLAUDE-002 | FORBIDDEN: Modify core specs without instruction |
| SC-CLAUDE-003 | Run mix format after code generation |
| SC-CLAUDE-004 | Respect .gitignore patterns |
| SC-CLAUDE-005 | Validate all generated code |
| SC-CLAUDE-006 | FORBIDDEN: Commit failing STAMP |
| SC-CLAUDE-007 | Ensure fresh context before decisions |

### 80.3 Claude Agent Operating Protocols (AOP-CLAUDE)

| Rule | Description |
|------|-------------|
| AOP-CLAUDE-001 | Plan ⟹ Verify (validate before executing) |
| AOP-CLAUDE-002 | Change ⟹ Test (test after modification) |
| AOP-CLAUDE-003 | FORBIDDEN: Hallucinate API |
| AOP-CLAUDE-004 | Adhere to codebase style |
| AOP-CLAUDE-005 | Log all significant actions |

## 81.0 Document Statistics & Metadata

### 81.1 Version Information
| Field | Value |
|-------|-------|
| Version | 10.2.0-UNIFIED |
| Updated | 2025-12-19 |
| Total Sections | 81 |
| Total Lines | ~7100 |

### 81.2 Constraint Counts
| Category | Count |
|----------|-------|
| STAMP Safety Constraints | 242 |
| Agent Operating Rules (AOR) | 122 |
| Error Patterns (EP) | 114 |
| LTL Properties | 24 |
| Hoare Protocols | 8 |

### 81.3 System Metrics
| Metric | Value |
|--------|-------|
| Agent Count | 50 |
| Containers | 3 |
| Ash Domains | 10 |
| Source Files | 773 |
| Validation Methods (FPPS) | 5 |
| Demo Modes | 16 |
| Mobile Endpoints | 17 |

### 81.4 Compliance Certifications
| Standard | Status |
|----------|--------|
| SOPv5.11 Cybernetic Framework | CERTIFIED |
| STAMP Safety Methodology | VERIFIED |
| TDG (Test-Driven Generation) | ENFORCED |
| FPPS 5-Method Validation | OPERATIONAL |
| PHICS v2.1 Hot-Reloading | ACTIVE |
| 50-Agent Architecture | DEPLOYED |
| FLAME Distributed Systems | INTEGRATED |
| Clustering & HA Mesh | CONFIGURED |
| Cybernetic Architect Persona | FORMALIZED |
| TPS Methodology (Jidoka/Kaizen/Poka-Yoke) | INTEGRATED |
| SIA DC-09-2021 Protocol | COMPLIANT |
| Hybrid AI/ML (Nx/Mojo) | OPERATIONAL |
| Mobile API v2.1 | DEPLOYED |
| Three-Layer Verification (Quint/Agda/ExUnit) | OPERATIONAL |
| IEC 61508 SIL-2 | COMPLIANT |
| ISO 27001 | COMPLIANT |
| GDPR | COMPLIANT |
| EN 50131 | COMPLIANT |

### 81.5 Synced Documents
| Document | Version | Lines |
|----------|---------|-------|
| CLAUDE.md | 10.2.0-UNIFIED | 7058 |
| CLAUDE-text.md | 10.2.0-UNIFIED | 7210 |
| GEMINI-text.md | 10.2.0-UNIFIED | 7210 |

---

**END OF DOCUMENT**

