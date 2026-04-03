# GEMINI-FAST-20k.md - Indrajaal Safety-Critical System Specification
**Version**: 10.2.0-UNIFIED-FAST-20k | **Origin**: GEMINI.md v10.2.0 | **Status**: ACTIVE
**Mandate**: Primary Operational Context. Optimized for 20k token window while retaining full constraint fidelity.

---

## 0.0 Mathematical Preliminaries
**Logic**: $\forall$ (For all), $\exists$ (Exists), $\implies$ (Implies), $\iff$ (Iff), $\Box$ (Always), $\diamond$ (Eventually).
**Sets**: $\mathcal{A}_{50}$ (50 Agents), $\mathcal{C}_{3}$ (3 Containers), $\mathcal{D}_{10}$ (10 Domains), $\mathcal{F}_{773}$ (773 Files), $\mathcal{SC}_{242}$ (242 Constraints).

## 1.0 Fundamental Axioms ($\Omega$) - CRITICAL FAILURE IF VIOLATED

### Axiom 1: The Patient Mode Invariant ($\Omega_1$)
**Mandate**: Compilation must NEVER be interrupted and must yield ZERO warnings.
**Command**:
```bash
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 10:10 +SDio 10" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=5 \
mix compile --warnings-as-errors --jobs 10 2>&1 | tee -a ./data/tmp/1-compile.log
```
**Requirements**:
1.  **Infinite Patience**: `NO_TIMEOUT=true`.
2.  **Resource Max**: `+S 10:10` (Scheduler tuning).
3.  **Observability**: Output MUST be piped to `tee`.
4.  **Atomic Analysis**: Analyze log ONLY after exit code 0.

### Axiom 2: The Container Isolation Invariant ($\Omega_2$)
**Mandate**: All operations MUST run in **NixOS/Podman** (Rootless 5.4.1+).
**Registry**: `localhost/` ONLY.
**Forbidden**: Docker, Alpine, Ubuntu, Proprietary Registries.
**PHICS**: Latency < 50ms required.
**Topology**: 3-Container Model (`indrajaal-app`, `indrajaal-db`, `indrajaal-obs`).

### Axiom 3: The Zero-Defect Quality Invariant ($\Omega_3$)
**Valid State** $\iff \sum(\text{Errors} + \text{Warnings} + \text{TestFails} + \text{FormatFails} + \text{CredoFails} + \text{SecFails}) \equiv 0$.
**Gate**: `mix format --check-formatted && mix credo --strict && mix dialyzer && mix sobelow --exit && mix test --coverage`.

### Axiom 4: Test-Driven Generation (TDG) ($\Omega_4$)
**Mandate**: Tests MUST exist and FAIL before code generation.
**Property Tests**: Dual requirement: `PropCheck` AND `ExUnitProperties`.
**Workflow**: Test First $\to$ AI Gen $\to$ Validate $\to$ Refactor.

### Axiom 5: Validation Consensus ($\Omega_5$)
**Mandate**: 5-Method FPPS (Pattern, AST, Statistical, Binary, LineByLine) MUST agree.
**Trigger**: Disagreement $\implies$ **Emergency Protocol**.

### Axiom 6: Mandatory Validation Gates ($\Omega_6$)
**Feature Complete** $\iff$ Pass(Compile, Runtime, TDG, STAMP, FPPS, Coverage>95%, Format, Credo, Sobelow).

---

## 2.0 System Architecture ($\Sigma$)

### 2.1 Agent Hierarchy ($\mathcal{A}_{50}$)
1.  **Executive (1)**: Supreme Authority.
2.  **Domain Supervisors (10)**: Access, Accounts, Alarms, Analytics, Comm, Compliance, Devices, Perf, Obs, Web.
3.  **Functional (15)**: Compilation, QA, Performance specialists.
4.  **Workers (24)**: File processors, Pattern recognizers.

### 2.2 Container Infrastructure ($\mathcal{C}_{3}$)
| Container | Port | Service | Resources | 
|-----------|------|---------|-----------|
| `indrajaal-app` | 4000 | Phoenix | 12 CPU, 32GB RAM |
| `indrajaal-db` | 5433 | PG17/Timescale | 4 CPU, 16GB RAM |
| `indrajaal-obs` | 8123 | ClickHouse/Otel | 4 CPU, 8GB RAM |

**Env Strategy (SC-CNT-ENV)**:
*   **Dev**: `podman-compose-3container.yml` (PHICS enabled).
*   **Test**: `podman-compose-testing.yml` (HA Cluster).
*   **Prod**: `podman-compose-secure.yml` (Read-only root).

---

## 3.0 Operational Model (AEE SOPv5.11)

**Execution Strategy**:
*   `smart`: Default adaptive.
*   `patient`: Full validation (Slow).
*   `ultra_fast`: Check only.

**Standard Workflow**:
1.  **Status**: `elixir scripts/performance/podman_direct_manager.exs --status`
2.  **Env**: `devenv shell`
3.  **Compile**: `mix claude compilation --compile --strategy smart`
4.  **Test**: `mix test --coverage`
5.  **Gate**: `mix feature.complete --validate NAME`

---

## 4.0 STAMP Safety Constraints (Complete)

### Category A: Validation Process (SC-VAL)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-VAL-001 | Use ONLY Patient Mode compilation | Check NO_TIMEOUT=true |
| SC-VAL-002 | Analyze COMPLETE logs (no partial) | Verify no head/tail |
| SC-VAL-003 | Achieve 100% FPPS consensus | 5-method agreement |
| SC-VAL-004 | Halt on disagreement | Emergency trigger |
| SC-VAL-005 | Maintain complete audit trail | Logs exist |
| SC-VAL-006 | Prevent selective validation (EP-110) | Full compile |
| SC-VAL-007 | Detect process drift (EP-111) | Monitor |
| SC-VAL-008 | Integrate SOPv5.11 framework | Framework check |

### Category B: Container Safety (SC-CNT)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-CNT-009 | NixOS/Podman ONLY | Env check |
| SC-CNT-010 | Localhost registry ONLY | Image source |
| SC-CNT-011 | PHICS latency < 50ms | Latency monitor |
| SC-CNT-012 | Rootless execution | User check |
| SC-CNT-013 | Validate health before ops | Health check |
| SC-CNT-014 | Resource isolation | Limits check |
| SC-CNT-015 | Network security | Network check |
| SC-CNT-016 | Prevent registry drift | Registry check |

### Category C: Agent Coordination (SC-AGT)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-AGT-017 | Architecture efficiency > 90% | Efficiency monitor |
| SC-AGT-018 | Prevent deadlocks | Deadlock detector |
| SC-AGT-019 | Executive Director supreme authority | Auth check |
| SC-AGT-020 | Enforce domain boundaries | Boundary check |
| SC-AGT-021 | Prevent queue overflow | Queue monitor |
| SC-AGT-022 | Validate message integrity | Checksum |
| SC-AGT-023 | Detect agent failures | Health monitor |
| SC-AGT-024 | Maintain load balancing | Load monitor |

### Category D: Compilation (SC-CMP)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-CMP-025 | Zero warnings mandatory | --warnings-as-errors |
| SC-CMP-026 | Complete file compilation (773) | File count |
| SC-CMP-027 | Deterministic compilation | Reproducibility |
| SC-CMP-028 | No interruption | Process monitor |
| SC-CMP-033 | Use `--jobs <N>` | Args check |
| SC-CMP-034 | `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` | Env check |

### Category E: Data Integrity (SC-DAT)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-DAT-033 | Prevent corruption | Integrity check |
| SC-DAT-034 | Audit log integrity | Tamper check |
| SC-DAT-039 | Prevent race conditions | Lock check |
| SC-DAT-040 | Maintain data versioning | Version check |

### Category F: Security (SC-SEC)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-SEC-041 | Prevent unauthorized access | Access control |
| SC-SEC-044 | Sobelow check (0 issues) | Security scan |
| SC-SEC-047 | Maintain encryption | Encryption check |

### Category G: Performance (SC-PRF)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-PRF-050 | Response time < 50ms | Latency check |
| SC-PRF-055 | Prevent blocking ops | Async check |

### Category H: Emergency (SC-EMR)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-EMR-057 | Emergency stop < 5s | Timing check |
| SC-EMR-060 | Rollback capabilities | Rollback test |

### Category I: Observability (SC-OBS)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-OBS-065 | Logging enabled for all ops | Log check |
| SC-OBS-069 | Dual logging (Term+SigNoz) | Backend check |
| SC-OBS-071 | 4 OTEL modules loaded | Module check |

### Category J: Agent Code (SC-AGT-CODE)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-AGT-025 | `mix compile` before task complete | Gate check |
| SC-AGT-026 | Verify 0 errors | Error check |
| SC-AGT-027 | Check `BaseResource` definitions | Interface check |
| SC-AGT-028 | Validate Ash DSL patterns | DSL check |
| SC-AGT-029 | Prevent non-Elixir syntax | Syntax check |
| SC-AGT-030 | Auto-trigger Jidoka on failure | Recovery check |

### Category K: PropCheck (SC-PROP)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-PROP-021 | No raw `utf8()` generator | Pattern check |
| SC-PROP-022 | Use `let/vector/range` pattern | Pattern check |

### Category L: Ash Changeset (SC-ASH)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-ASH-001 | `force_change_attribute` in `before_action` | Pattern check |
| SC-ASH-004 | `require_atomic? false` for fn changes | Directive check |
| SC-ASH-007 | Register new resources in domain | Domain check |
| SC-ASH-008 | Accept `opts` in plain functions | Signature check |

### Category M: Database (SC-DB)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-DB-001 | Use `BaseResource` mixin | Mixin check |
| SC-DB-004 | `snake_case` tables (no prefix) | Schema check |
| SC-DB-005 | `uuid_primary_key :id` | Attr check |
| SC-DB-012 | `create_if_not_exists` for indexes | Mig check |
| SC-DB-021 | Factory for EVERY resource | Factory check |
| SC-DB-024 | Maintain referential integrity | FK check |
| SC-DB-031 | Use SQL Sandbox in tests | Test setup check |

### Category N: Documentation (SC-DOC)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-DOC-001 | `moduledoc` with WHAT/WHY/CONSTRAINTS | Doc check |
| SC-DOC-006 | Document DSL blocks (`DSL:` prefix) | Comment check |
| SC-DOC-017 | Document Oban serialization | Doc check |
| SC-DOC-019 | Document escape hatches with warning | Hatch check |

### Category O: Batch Execution (SC-BATCH)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-BATCH-001 | Max 10 changes per batch | Count check |
| SC-BATCH-002 | Elixir scripts ONLY (no sed/awk) | Ext check |
| SC-BATCH-003 | Compile after each batch | Compile check |
| SC-BATCH-005 | Git checkpoint before batch | Stash check |

### Category P: Factory (SC-FAC)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-FAC-001 | Use `Ash.Changeset.for_create` | Pattern check |
| SC-FAC-005 | Pass `actor` to create operations | Arg check |
| SC-FAC-007 | Handle tenant association | Util check |
| SC-FAC-009 | Create parent records first | Order check |

### Category Q: Ash 3.x API (SC-ASH3)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-ASH-001 | Access tenant via `query.tenant` | Query check |
| SC-ASH-004 | Pass actor to `for_update` options | Opts check |
| SC-ASH-009 | Pagination returns struct (use `.results`) | Access check |

### Category V: Todo Management (SC-TODO)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-TODO-001 | No direct edit of `PROJECT_TODOLIST.md` | Audit |
| SC-TODO-002 | Use `mix todo` commands | History |
| SC-TODO-004 | Sync session start | Log check |

### Category X: Migration Preflight (SC-MIG)
| ID | Constraint | Verification |
|----|------------|--------------|
| SC-MIG-001 | DB tests MUST declare migrations | Macro check |
| SC-MIG-002 | Preflight verification before test | Hook check |

---

## 5.0 Agent Operating Rules (AOR)

*   **AOR-EXE-001**: Executive has supreme authority.
*   **AOR-SAF-001**: Halt <1s on STAMP violation.
*   **AOR-CNT-001**: Podman ONLY.
*   **AOR-QUA-001**: Zero warnings mandatory.
*   **AOR-AGT-001**: Code must compile before task complete.
*   **AOR-AGT-003**: New resources must be registered in Domain.
*   **AOR-AGT-004**: `require_atomic? false` for function-based updates.
*   **AOR-DB-001**: Use `BaseResource`.
*   **AOR-DOC-001**: Read `moduledoc` before edit.
*   **AOR-ASH-001**: Use `query.tenant` (not context).
*   **AOR-FAC-001**: Use Ash.Changeset pattern for factories.
*   **AOR-GEM-001**: Plan $\implies$ Verify.
*   **AOR-GEM-003**: No Hallucinated APIs.

---

## 6.0 Essential Code Patterns

### 6.1 Ash Resource Template
```elixir
defmodule Indrajaal.Domain.Resource do
  @moduledoc """
  ## WHAT: ... ## WHY: ... ## CONSTRAINTS: ...
  """
  use Indrajaal.BaseResource
  postgres do
    table "snake_case_table" # SC-DB-004
    repo Indrajaal.Repo
  end
  attributes do
    uuid_primary_key :id # SC-DB-005
    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
    end
  end
  actions do
    defaults [:read]
    create :create do
      accept [:name]
    end
    update :update do
      require_atomic? false # SC-ASH-004
      change fn changeset, _ -> changeset end
    end
  end
end
```

### 6.2 Factory Template (SC-FAC)
```elixir
defmodule Indrajaal.DomainFactory do
  import Indrajaal.Shared.FactoryUtilities
  defmacro __using__(_) do
    quote do
      def resource_factory(attrs \\ %{}) do
        attrs = normalize_attrs(attrs)
        {tenant, attrs} = handle_tenant_association(attrs, __MODULE__) # SC-FAC-007
        admin = Indrajaal.ActorHelpers.admin_actor(tenant.id)
        
        {:ok, resource} = Indrajaal.Domain.Resource
        |> Ash.Changeset.for_create(:create, attrs, actor: admin) # SC-FAC-001
        |> Ash.create(actor: admin)
        
        resource
      end
    end
  end
end
```

### 6.3 Test Template (TDG)
```elixir
defmodule Indrajaal.Domain.ResourceTest do
  use Indrajaal.DataCase
  use PropCheck
  use ExUnitProperties
  use Indrajaal.Test.MigrationAware, tables: [:resources] # SC-MIG-001

  property "propcheck: valid generation" do
    forall attrs <- valid_attrs_gen() do
      assert {:ok, _} = Resource.create(attrs, actor: admin())
    end
  end
end
```

### 6.4 Batch Script Template (SC-BATCH)
```elixir
# batch_fix.exs
# SC-BATCH-001: Max 10 changes
# SC-BATCH-005: Reversible via git
defmodule BatchFix do
  def run do
    create_checkpoint()
    apply_changes()
    verify_compilation!() # SC-BATCH-003
    verify_tests!()
  end
end
```

---

## 7.0 Error Pattern Database (Selected)

| ID | Pattern | Fix |
|----|---------|-----|
| **EP-110** | 0 errors, X warnings | Use FPPS Consensus |
| **EP-ASH-001** | `query.context[:tenant]` | Use `query.tenant` |
| **EP-ASH-002** | Actor only in `update!` | Pass to `for_update` |
| **EP-ASH-004** | `length()` on pagination | Access `.results` |
| **EP-FAC-001** | `Ash.NotLoaded` schema | Use Ash.Changeset |
| **EP-MIG-001** | `column "X" does not exist` | Check Migrations |
| **EP-AGT-001** | Duplicate `code_interface` | Check BaseResource |
| **EP-AGT-004** | `return` statement | Use case/if |

---

## 8.0 Directory & Tool Safety (SC-ENV)

**Excluded Directories** (Do NOT search/glob):
`data/` (Permissions), `.git/`, `_build/`, `deps/`, `node_modules/`, `.elixir_ls/`, `.lexical/`, `priv/static/`.

**Safe Search Commands**:
*   `rg "pattern" . --glob '!data/*'` --glob '!_build/*'` ...
*   `grep -r "pattern" . --exclude-dir=data --exclude-dir=_build ...`

---

## 9.0 Essential Commands

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

**Formal Verification**
```bash
quint verify --invariant=masterInvariant --max-steps=100 docs/formal_specs/quint_specifications.qnt
agda --safe docs/formal_specs/agda_proofs.agda
```

---

## 10.0 Project Status (2025-12-22)
*   **Compliance**: IEC 61508 SIL-2, ISO 27001.
*   **Metrics**: 50 Agents, 242 Constraints, 122 AORs, 773 Files.
*   **Active Framework**: SOPv5.11 + TPS + STAMP.
*   **Verification**: 286 Formal Verification Tests.
