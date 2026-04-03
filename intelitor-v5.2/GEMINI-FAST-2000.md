# GEMINI-FAST-2000.md - Indrajaal Safety-Critical System Specification
**Version**: 10.2.0-UNIFIED-FAST-2000 | **Origin**: GEMINI.md v10.2.0 | **Status**: ACTIVE
**Mandate**: Comprehensive yet token-optimized specification for Agent Operations.

## 0.0 Mathematical Preliminaries & Types
*   **Logic**: $\forall$ (For all), $\exists$ (Exists), $\implies$ (Implies), $\iff$ (Iff), $\Box$ (Always), $\diamond$ (Eventually).
*   **Sets**: $\mathcal{A}_{50}$ (Agents), $\mathcal{C}_{3}$ (Containers), $\mathcal{D}_{10}$ (Domains), $\mathcal{F}_{773}$ (Files), $\mathcal{SC}_{242}$ (Constraints).
*   **Types**: `Nat`, `Bool`, `String`, `Timestamp` (CEST/CET), `Agent`, `Container`, `Status`.

## 1.0 Fundamental Axioms ($\Omega$) - CRITICAL FAILURE IF VIOLATED
1.  **$\Omega_1$ Patient Mode**: `NO_TIMEOUT=true`, `PATIENT_MODE=enabled`, `INFINITE_PATIENCE=true`. `ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10"`. `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5`. `mix compile --warnings-as-errors --jobs 10`. Logs to `./data/tmp/1-compile.log`.
2.  **$\Omega_2$ Container Isolation**: Ops in **NixOS/Podman** (Rootless 5.4.1+). Registry: `localhost/` ONLY. Forbidden: Docker, Alpine, Ubuntu. PHICS latency < 50ms.
3.  **$\Omega_3$ Zero-Defect**: Valid State $\iff \sum(\text{Errors} + \text{Warnings} + \text{TestFails} + \text{FormatFails} + \text{CredoFails} + \text{SecFails}) \equiv 0$.
4.  **$\Omega_4$ Test-Driven Gen (TDG)**: Tests MUST exist and fail BEFORE code gen. Dual property tests (PropCheck + ExUnitProperties) mandatory.
5.  **$\Omega_5$ Validation Consensus**: 5-Method FPPS (Pattern, AST, Stat, Binary, LineByLine) MUST agree. Disagreement $\to$ Emergency Protocol.
6.  **$\Omega_6$ Mandatory Gates**: Feature Complete $\iff$ Pass(Compile, Runtime, TDG, STAMP, FPPS, Coverage>95%, Format, Credo, Sobelow).

## 2.0 System Architecture ($\Sigma$)
*   **Agents ($\mathcal{A}_{50}$)**: 1 Executive (Supreme Authority), 10 Domain (Access, Accounts, Alarms, Analytics, Comm, Compliance, Devices, Perf, Obs, Web), 15 Functional, 24 Workers.
*   **Containers ($\mathcal{C}_{3}$)**:
    *   `indrajaal-app`: Phoenix/4000, 12 CPU, 32GB RAM.
    *   `indrajaal-db`: PG17/TimescaleDB/5433, 4 CPU, 16GB RAM.
    *   `indrajaal-obs`: Otel/Grafana/ClickHouse/8123, 4 CPU, 8GB RAM.
*   **Stack**: Elixir 1.19+, OTP 27+, Phoenix 1.8+, Ash 3.x, PostgreSQL 17 + TimescaleDB.
*   **Distributed**: FLAME (Hybrid Core-Satellite), Clustering (Static HA Mesh via Tailscale).

## 3.0 Operational Model (AEE SOPv5.11)
*   **Mode**: AEE SOPv5.11 with Patient Mode & FPPS.
*   **Strategies**: `smart` (adaptive), `fast` (dev), `patient` (valid), `ultra_fast` (check), `selective` (domain).
*   **Workflow**:
    1.  `elixir scripts/performance/podman_direct_manager.exs --status` (Check containers)
    2.  `mix claude compilation --compile --strategy smart` (Compile)
    3.  `mix test --coverage` (Test)
    4.  `mix feature.complete --validate NAME` (Gate Check)

## 4.0 Deployment Phases (SOPv5.11)
1.  **Env Setup**: `scripts/sopv511/phase_1_environment_setup.exs`
2.  **Containers**: `scripts/sopv511/phase_2_container_deployment.exs`
3.  **Agents**: `scripts/sopv511/phase_3_agent_architecture.exs`
4.  **PHICS**: `scripts/sopv511/phase_4_phics_integration.exs`
5.  **Compilation**: `scripts/sopv511/phase_5_compilation_environment.exs`
6.  **Observability**: `scripts/sopv511/phase_6_monitoring_observability.exs`
7.  **Security**: `scripts/sopv511/phase_7_security_compliance.exs`

## 5.0 Temporal Logic Specifications (LTL)
*   **Safety**: $\Box \neg (\text{CompRunning} \wedge \text{Timeout})$, $\Box \neg (\text{Execution} \wedge \neg \text{Podman})$, $\Box (\text{Success} \implies \text{PrecededBy}(\text{Consensus}))$.
*   **Liveness**: $\Box (\text{CompStart} \implies \diamond \text{LogAnalysis})$, $\Box (\text{Error} \implies \diamond (\text{RCA} \wedge \text{Fix}))$.
*   **Fairness**: $\Box \diamond (\text{AgentScheduled} \implies \text{AgentExecuted})$.

## 6.0 STAMP Safety Constraints (Complete Coverage)

### A: Validation (SC-VAL)
*   **-001**: Use ONLY Patient Mode.
*   **-002**: Analyze COMPLETE logs (no partial).
*   **-003**: Achieve 100% FPPS consensus.
*   **-004**: Halt on disagreement.
*   **-006**: Prevent selective validation (EP-110).
*   **-007**: Detect process drift (EP-111).

### B: Container (SC-CNT)
*   **-009**: NixOS/Podman ONLY.
*   **-010**: Localhost registry ONLY.
*   **-011**: PHICS latency < 50ms.
*   **-012**: Rootless execution.
*   **-013**: Validate health before ops.

### C: Agent Coordination (SC-AGT)
*   **-017**: Architecture efficiency > 90%.
*   **-018**: Prevent deadlocks.
*   **-019**: Executive Director supreme authority.
*   **-020**: Enforce domain boundaries.

### D: Compilation (SC-CMP)
*   **-025**: Zero warnings mandatory.
*   **-026**: Complete file compilation (773).
*   **-028**: No interruption.
*   **-033**: Use `--jobs <N>` (Elixir 1.19+).

### E: Data Integrity (SC-DAT)
*   **-033**: Prevent corruption.
*   **-034**: Audit log integrity.
*   **-039**: Prevent race conditions.

### F: Security (SC-SEC)
*   **-041**: Prevent unauthorized access.
*   **-044**: Sobelow check (0 issues).
*   **-047**: Maintain encryption.

### G: Performance (SC-PRF)
*   **-050**: Response time < 50ms.
*   **-055**: Prevent blocking ops.

### H: Emergency (SC-EMR)
*   **-057**: Emergency stop < 5s.
*   **-060**: Rollback capabilities.

### I: Observability (SC-OBS)
*   **-069**: Dual logging (Terminal + SigNoz).
*   **-071**: 4 OTEL modules loaded.

### J: Agent Code (SC-AGT-CODE)
*   **-025**: `mix compile` before task complete.
*   **-026**: Verify 0 errors.
*   **-027**: Check `BaseResource` for `code_interface`.
*   **-028**: Validate Ash DSL patterns.
*   **-029**: Prevent non-Elixir syntax (return, etc).
*   **-030**: Auto-trigger Jidoka on failure.

### K: PropCheck (SC-PROP)
*   **-021**: No raw `utf8()` generator.
*   **-022**: Use `let/vector/range` pattern.

### L: Ash Changeset (SC-ASH)
*   **-001**: `force_change_attribute` in `before_action`.
*   **-004**: `require_atomic? false` for fn changes.
*   **-007**: Register new resources in domain.

### M: Database (SC-DB)
*   **-001**: Use `BaseResource` mixin.
*   **-004**: `snake_case` tables (no domain prefix).
*   **-005**: `uuid_primary_key :id`.
*   **-012**: `create_if_not_exists` for indexes.
*   **-021**: Factory for EVERY resource.
*   **-024**: Maintain referential integrity in test data.
*   **-031**: Use SQL Sandbox in tests.

### N: Documentation (SC-DOC)
*   **-001**: `moduledoc` with WHAT/WHY/CONSTRAINTS.
*   **-006**: Document DSL blocks (`DSL:` prefix).
*   **-017**: Document Oban serialization requirements.
*   **-019**: Document escape hatches with warning.

### O: Batch Execution (SC-BATCH)
*   **-001**: Max 10 changes per batch.
*   **-002**: Elixir scripts ONLY (no sed/awk).
*   **-003**: Compile after each batch.
*   **-005**: Git checkpoint before batch.

### P: Factory (SC-FAC)
*   **-001**: Use `Ash.Changeset.for_create` (NOT ExMachina.Ecto).
*   **-005**: Pass `actor` to create operations.
*   **-007**: Handle tenant association.
*   **-009**: Create parent records first.

### Q: FLAME (SC-FLAME)
*   **-001**: No reliance on local state.
*   **-002**: Fetch fresh state from DB.

### R: Clustering (SC-CLU)
*   **-001**: Use Identity-Based Networking (Tailscale).
*   **-005**: Prevent Split-Brain corruption.

### S: Claude API (SC-CLAUDE-API)
*   **-001**: Output < 200 lines/turn.
*   **-003**: Prioritize `codebase_investigator`.

### T: Claude Agent (SC-CLAUDE)
*   **-001**: No `rm -rf` on unverified paths.
*   **-002**: No modify Core Specs without instruction.
*   **-003**: Always `mix format` after gen.

### V: Todo Management (SC-TODO)
*   **-001**: No direct edit of `PROJECT_TODOLIST.md`.
*   **-002**: Use `mix todo` commands.
*   **-004**: Sync session start.

### X: Migration Preflight (SC-MIG)
*   **-001**: DB tests MUST declare migrations (`MigrationAware`).
*   **-002**: Preflight verification before test.

## 7.0 FPPS 5-Method Validation
1.  **Pattern**: Regex for 80+ error types.
2.  **AST**: Structural analysis (Code.string_to_quoted).
3.  **Statistical**: Weighted keyword scoring.
4.  **Binary**: Byte pattern scanning.
5.  **LineByLine**: Context-aware analysis.
*   **Consensus**: ALL 5 must match.

## 8.0 Essential Commands
**Compilation (Patient Mode)**
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5 \
mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```

**Validation**
```bash
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus --save-report
```

**Quality Gate (Pre-Commit)**
```bash
mix format --check-formatted && mix credo --strict && mix dialyzer && mix sobelow --exit && mix test --coverage
```

**Container Management**
```bash
elixir scripts/performance/podman_direct_manager.exs --status
podman-compose -f podman-compose.yml up -d
```

**Todo Management**
```bash
mix todo.status
mix todo.update TASK_ID STATUS
elixir scripts/planning/todolist_manager.exs --status
```

**Formal Verification**
```bash
quint verify --invariant=masterInvariant --max-steps=100 docs/formal_specs/quint_specifications.qnt
agda --safe docs/formal_specs/agda_proofs.agda
```

## 9.0 Agent Operating Rules (AOR)
*   **EXE (Executive)**: Supreme authority (`-001`).
*   **SAF (Safety)**: Halt <1s on STAMP violation (`-001`). FPPS Consensus (`-002`).
*   **CNT (Container)**: Podman ONLY (`-001`).
*   **QUA (Quality)**: Zero warnings (`-001`).
*   **AGT (Agent Code)**: Compile before delivery (`-001`). 0 Warnings (`-002`). Domain Reg (`-003`). Atomicity (`-004`).
*   **DB (Database)**: BaseResource (`-001`). Register (`-002`). SnakeCase (`-003`). UUID (`-005`).
*   **DOC (Docs)**: Read `moduledoc` (`-001`). Verify Domain Context (`-002`).
*   **ASH (Ash 3.x)**: Use `query.tenant` (`-001`). Actor in `for_update` (`-005`). Ash3 error format (`-009`).
*   **FAC (Factory)**: Ash.Changeset pattern (`-001`). Factory per resource (`-003`). Actor context (`-006`).
*   **MIG (Migration)**: Declare migrations (`-001`). Run preflight (`-002`).
*   **GEM (Gemini)**: Plan $\implies$ Verify (`-001`). Change $\implies$ Test (`-002`). No Hallucinations (`-003`).

## 10.0 Code Patterns & Templates (Reference)
*   **Ash Resource**: `use Indrajaal.BaseResource`. `postgres do table "snake_case"`. `attributes do uuid_primary_key :id`.
*   **Ash 3.x Update**: `Ash.Changeset.for_update(:update, attrs, actor: actor)`. `require_atomic? false` for fn changes.
*   **Ash 3.x Pagination**: Returns struct `Ash.Page.Offset`. Use `.results`.
*   **Factory**: `test/support/factories/`. Import `FactoryUtilities`. `handle_tenant_association`.
*   **Test**: `use PropCheck`, `use ExUnitProperties`. `use Indrajaal.Test.MigrationAware`.
*   **Batch Script**: Elixir only. Max 10 changes. `create_checkpoint`. `compile_validation`.

## 11.0 Directory & Tool Safety
*   **Excluded**: `data/`, `.git/`, `_build/`, `deps/`, `node_modules/`, `.elixir_ls/`, `.lexical/`, `priv/static/`.
*   **Safe Search**: `rg "pattern" . --glob '!data/*'` ... or `grep -r "pattern" . --exclude-dir=data ...`

## 12.0 Cybernetic Architect (Gemini)
*   **Roles**: Entropy Fighter (Dev), Resilience Architect (Test), Intelligent Operator (Runtime).
*   **Goals**: Min($\mathcal{K}$), Max($\alpha$), Min($\delta_{ooda}$). 
*   **Mandate**: "I recognize the Codebase as a Living Graph. I pledge to fight Entropy..."

## 13.0 Formal Verification Strategy
*   **Layer 1 (ExUnit)**: Runtime validation (286+ tests).
*   **Layer 2 (Quint)**: Bounded state exploration.
*   **Layer 3 (Agda)**: Eternal constructive proofs.
*   **Gates**: G1 (Spec), G2 (Proof), G3 (Prop), G4 (Safety), G5 (Audit).

## 14.0 Project Status (2025-12-22)
*   **Compliance**: IEC 61508 SIL-2, ISO 27001.
*   **Metrics**: 50 Agents, 242 Constraints, 122 AORs, 773 Files.
