# GEMINI-FAST.md - Indrajaal Safety-Critical System Optimized Spec
**Version**: 10.2.0-UNIFIED-FAST | **Origin**: GEMINI.md v10.2.0 | **Status**: ACTIVE
**Mandate**: This document acts as the primary, token-efficient context for Gemini agents.

## 0.0 Mathematical Preliminaries & Types
*   **Logic**: $\forall$ (For all), $\exists$ (Exists), $\implies$ (Implies), $\iff$ (Iff), $\Box$ (Always), $\diamond$ (Eventually).
*   **Sets**: $\mathcal{A}_{50}$ (50 Agents), $\mathcal{C}_{3}$ (App, DB, Obs), $\mathcal{D}_{10}$ (Ash Domains), $\mathcal{F}_{773}$ (Files).
*   **Types**: `Nat`, `Bool`, `String`, `Timestamp` (CEST/CET), `Agent`, `Container`, `Status`.

## 1.0 Fundamental Axioms ($\Omega$) - CRITICAL
1.  **$\Omega_1$ Patient Mode**: `NO_TIMEOUT=true`, `PATIENT_MODE=enabled`, `INFINITE_PATIENCE=true`. `ELIXIR_ERL_OPTIONS="+S 10:10"`. Logs to `./data/tmp/1-compile.log`. NEVER interrupt.
2.  **$\Omega_2$ Container Isolation**: All ops in **NixOS/Podman** (Rootless 5.4.1+). Registry: `localhost/` ONLY. No Docker/Alpine. PHICS latency < 50ms.
3.  **$\Omega_3$ Zero-Defect**: Valid State $\iff \sum(\text{Errors} + \text{Warnings} + \text{TestFails} + \text{FormatFails} + \text{CredoFails} + \text{SecFails}) \equiv 0$.
4.  **$\Omega_4$ Test-Driven Gen (TDG)**: Tests MUST exist and fail BEFORE code gen. Dual property tests (PropCheck + ExUnitProperties) mandatory.
5.  **$\Omega_5$ Validation Consensus**: 5-Method FPPS (Pattern, AST, Stat, Binary, LineByLine) MUST agree. Disagreement $\to$ Emergency.
6.  **$\Omega_6$ Mandatory Gates**: Feature Complete $\iff$ Pass(Compile, Runtime, TDG, STAMP, FPPS, Coverage>95%, Format, Credo, Sobelow).

## 2.0 System Architecture
*   **Agents ($\mathcal{A}_{50}$)**: 1 Executive, 10 Domain (e.g., Access, Alarms), 15 Functional, 24 Workers.
*   **Containers**: `indrajaal-app` (Phoenix/4000), `indrajaal-db` (PG17/5433), `indrajaal-obs` (Otel/Grafana/8123).
*   **Stack**: Elixir 1.19+, OTP 27+, Phoenix 1.8+, Ash 3.x, PostgreSQL 17 + TimescaleDB.

## 3.0 Operational Model (AEE SOPv5.11)
*   **Mode**: AEE SOPv5.11 with Patient Mode & FPPS.
*   **Strategy**: `smart` (default), `fast` (dev), `patient` (valid), `ultra_fast` (check).
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

## 5.0 Unified Safety Constraints (STAMP/SC)
*   **SC-VAL (Validation)**: Patient Mode only (`-001`). Analyze COMPLETE logs (`-002`). 100% Consensus (`-003`). Halt on disagreement (`-004`).
*   **SC-CNT (Container)**: NixOS/Podman only (`-009`). Localhost registry (`-010`). Rootless (`-012`).
*   **SC-AGT (Agents)**: Efficiency >90% (`-017`). No deadlocks (`-018`). Exec Authority (`-019`).
*   **SC-CMP (Compilation)**: 0 Warnings (`-025`). All 773 files (`-026`). No interruption (`-028`).
*   **SC-SEC (Security)**: Sobelow check (`-044`). Encryption (`-047`).
*   **SC-PRF (Performance)**: Response <50ms (`-050`). No blocking ops (`-055`).
*   **SC-EMR (Emergency)**: Stop <5s (`-057`). Rollback capability (`-060`).
*   **SC-OBS (Observability)**: Dual Log (Term+SigNoz) (`-069`). 4 OTEL modules (`-071`).
*   **SC-AGT-CODE**: `mix compile` before task done (`-025`). Verify 0 errors (`-026`). Check BaseResource (`-027`).
*   **SC-PROP**: No raw `utf8()` (`-021`). Use `let/vector/range` (`-022`).
*   **SC-ASH**: `force_change_attribute` in `before_action` (`-001`). `require_atomic? false` for fn changes (`-004`).
*   **SC-DB**: Use `BaseResource` (`-001`). `uuid_primary_key` (`-005`). `create_if_not_exists` idx (`-012`).
*   **SC-DOC**: `moduledoc` with WHAT/WHY/CONSTRAINTS (`-001`). Document DSL blocks (`-006`).
*   **SC-BATCH**: Max 10 changes/batch (`-001`). Elixir scripts ONLY (`-002`). Reversible (`-005`).
*   **SC-MIG**: Database tests must declare migrations (`-001`). Verify preflight (`-002`).
*   **SC-FAC**: Use `Ash.Changeset.for_create` (NOT ExMachina) (`-001`). Factory for EVERY resource (`-002`).
*   **SC-ASH3**: Use `query.tenant` (NOT context) (`-001`). Pass actor to `for_update` opts (`-004`).
*   **SC-GEM**: No `rm -rf` unverified (`-001`). No edit Core Specs (`-002`). `mix format` after gen (`-003`).

## 6.0 Essential Commands
**Compilation & Validation**
```bash
# Patient Mode (MANDATORY)
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 10:10" mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
# Validation
elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus --save-report
# Quality Gate
mix format --check-formatted && mix credo --strict && mix dialyzer && mix sobelow --exit && mix test --coverage
```

**Development & Testing**
```bash
# Start Dev
elixir scripts/env/dev-start.exs && mix phx.server
# Testing (Patient)
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test --timeout 7200000
# Factory Test
MIX_ENV=test mix test test/support/factory_test.exs
```

**Management**
```bash
# Todo List
mix todo.status
mix todo.update TASK_ID STATUS
# Containers
elixir scripts/performance/podman_direct_manager.exs --status
podman-compose -f podman-compose.yml up -d
```

## 7.0 Code Patterns & Rules
*   **Ash Resources**: Use `Indrajaal.BaseResource`. Table names: `snake_case` (no domain prefix). `uuid_primary_key :id`.
*   **Ash 3.x**: Access tenant via `query.tenant`. Actor in `for_update(..., actor: actor)`. Pagination returns struct (use `.results`).
*   **Factories**: Define in `test/support/factories`. Use `Ash.Changeset` pattern. Import `FactoryUtilities`. Create parents first.
*   **Tests**: `use PropCheck` AND `use ExUnitProperties`. Mock external deps. `MigrationAware` for DB tests.
*   **Documentation**: `moduledoc` required. Mark `DSL:` blocks. Document `⚠️ ESCAPE HATCH`.
*   **Batch Scripts**: Elixir `.exs` only. Max 10 files. Must include validation & git checkpoint.

## 8.0 Directory Safety
**Excluded from Search/Glob**: `data/`, `.git/`, `_build/`, `deps/`, `node_modules/`, `.elixir_ls/`, `.lexical/`, `priv/static/`.
**Safe Search**: `rg "pattern" . --glob '!data/*'` ...

## 9.0 Agent Operating Rules (AOR) - Selected
*   **AOR-EXE-001**: Executive has supreme authority.
*   **AOR-SAF-001**: Halt <1s on STAMP violation.
*   **AOR-CNT-001**: Podman ONLY.
*   **AOR-QUA-001**: Zero warnings mandatory.
*   **AOR-AGT-001**: Code must compile before task complete.
*   **AOR-DB-001**: Use `BaseResource`.
*   **AOR-DOC-001**: Read `moduledoc` before edit.
*   **AOR-BATCH-001**: Batch size <= 10.
*   **AOR-GEM-001**: Plan $\implies$ Verify.
*   **AOR-GEM-003**: No Hallucinated APIs.

## 10.0 Cybernetic Architect (Gemini)
*   **Role**: Entropy Fighter (Dev), Resilience Architect (Test), Intelligent Operator (Runtime).
*   **Goals**: Minimize Complexity ($\mathcal{K}$), Maximize Verification, Optimize OODA Loop.
*   **Mandate**: "I recognize the Codebase as a Living Graph. I pledge to fight Entropy..."

## 11.0 Project Status (2025-12-22)
*   **SOPv5.11**: Certified.
*   **Agents**: 50 Deployed.
*   **Safety**: 242 Constraints Verified.
*   **Tests**: 286 Formal Verification Tests.
*   **Compliance**: IEC 61508 SIL-2, ISO 27001.
