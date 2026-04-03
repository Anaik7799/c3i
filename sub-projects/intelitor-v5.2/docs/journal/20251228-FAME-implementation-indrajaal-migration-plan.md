# FAME Implementation & Indrajaal Migration - Criticality-Based Master Plan

**Date**: 2025-12-28T17:00:00+01:00
**Author**: Claude (Opus 4.5)
**Type**: Implementation Plan | Migration Strategy | Criticality Assessment
**Version**: 1.0.0
**Status**: PLANNING COMPLETE
**STAMP**: SC-DOC-001, SC-BATCH-001, SC-MIG-001, SC-MIG-002
**AOR**: AOR-BATCH-001, AOR-GEM-001, AOR-CODE-001

---

## Executive Summary

This document defines a **criticality-based implementation plan** for:

1. **FAME v2.0-BIO Implementation** - Adding the 12-block metadata schema to 8,375+ artifacts
2. **Indrajaal Migration Completion** - Finalizing the Intelitor→Indrajaal naming transition

Both initiatives are structured into **5 criticality tiers** (P0-P4) to ensure safety-critical components are addressed first while minimizing system disruption.

---

## Part 1: Current System State Analysis

### 1.1 Naming Convention Status

| Category | Status | Count | Details |
|----------|--------|-------|---------|
| **Application Modules** | ✅ Migrated | 869 | `Indrajaal.*` in `/lib/indrajaal/` |
| **Web Modules** | ✅ Migrated | 115 | `IndrajaalWeb.*` in `/lib/indrajaal_web/` |
| **OTP App Name** | ✅ Migrated | 1 | `:indrajaal` |
| **Config Files** | ✅ Migrated | 5 | `config :indrajaal` |
| **Database Migrations** | ❌ Legacy | 14 | `Intelitor.Repo.Migrations.*` |
| **Asset Pipeline** | ⚠️ Partial | 2 | `esbuild: indrajaal`, `tailwind: indrajaal` |
| **Directory Names** | ⚠️ Partial | 1 | `/lib/indrajaal_web/` |
| **Test Directories** | ⚠️ Partial | 1 | `/test/indrajaal_web/` |

### 1.2 FAME Implementation Scope

| Artifact Type | Count | Priority | FAME Blocks Required |
|---------------|-------|----------|---------------------|
| Elixir Modules (.ex) | 1,052 | P0-P1 | All 12 blocks |
| F# Modules (.fs) | 213 | P0-P1 | All 12 blocks (adapted) |
| Formal Specs | 15 | P0 | @formal, @invariants |
| Elixir Scripts (.exs) | 3,114 | P1-P2 | Header block |
| Documentation (.md) | 1,697 | P2 | YAML frontmatter |
| Config Files | 30 | P1 | Header block |
| Test Files | 790 | P2-P3 | Inherited from source |
| Scripts (bash, etc.) | 1,464 | P3 | Shebang + header |
| **TOTAL** | **8,375** | | |

---

## Part 2: Criticality Tier Definitions

### Tier P0: CRITICAL - Safety & Core Infrastructure
**Impact**: System cannot function correctly without these
**Timeline**: Immediate (Week 1)
**Review**: Mandatory dual-agent review

**Criteria**:
- Safety-critical modules (STAMP SC-* constrained)
- Core Ash Resources (19 files)
- Base infrastructure (BaseResource, Repo, Application)
- Authentication/Authorization modules
- Guardian/Safety modules

### Tier P1: HIGH - Domain Logic & APIs
**Impact**: Core business functionality affected
**Timeline**: Week 2-3
**Review**: Single-agent review with spot checks

**Criteria**:
- Domain root modules (Accounts, Alarms, Access Control, etc.)
- API Controllers and Plugs
- LiveView modules (Operations, PRAJNA)
- Configuration files
- F# CEPAF modules

### Tier P2: MEDIUM - Supporting Infrastructure
**Impact**: Secondary functionality affected
**Timeline**: Week 4-6
**Review**: Automated validation

**Criteria**:
- Helper modules and utilities
- Documentation files
- Non-critical scripts
- Test support files

### Tier P3: LOW - Maintenance & Tooling
**Impact**: Development workflow only
**Timeline**: Week 7-10
**Review**: Self-review

**Criteria**:
- Development scripts
- CI/CD configurations
- Build tooling
- Test fixtures

### Tier P4: COSMETIC - Legacy Cleanup
**Impact**: No functional impact
**Timeline**: Opportunistic
**Review**: None required

**Criteria**:
- Legacy naming artifacts
- Build cache cleanup
- Documentation corrections
- Comment updates

---

## Part 3: FAME Implementation Plan

### Phase 1: Schema & Tooling (P0 - Week 1)

#### 3.1.1 Core Schema Definition

```
lib/indrajaal/fame/
├── schema.ex              # FAME type definitions (all 12 blocks)
├── validator.ex           # Validation logic with Bio-Fractal checks
├── generator.ex           # Skeleton generation for all artifact types
├── parser.ex              # Parse existing metadata from files
├── graph.ex               # Knowledge graph builder
├── fitness.ex             # Fitness Function framework
├── invariants.ex          # Invariant registry and enforcement
├── metabolism.ex          # Metabolic tracking
├── stigmergy.ex           # Signal infrastructure
├── contracts.ex           # Contract enforcement
├── observability.ex       # Fractal logging integration
└── types.ex               # Shared type definitions
```

#### 3.1.2 Mix Tasks

```
lib/mix/tasks/
├── fame.validate.ex       # Validate FAME metadata across codebase
├── fame.generate.ex       # Generate skeleton metadata for files
├── fame.enrich.ex         # Add FAME blocks to existing modules
├── fame.graph.ex          # Generate knowledge graph
├── fame.fitness.ex        # Run fitness evaluations
├── fame.invariants.ex     # Verify invariant compliance
├── fame.report.ex         # Generate coverage reports
└── fame.migrate.ex        # Migrate naming conventions
```

#### 3.1.3 Templates

```
.fame/
├── templates/
│   ├── elixir_module.eex      # Elixir module template
│   ├── elixir_script.eex      # Script header template
│   ├── fsharp_module.eex      # F# module template
│   ├── markdown.eex           # Documentation frontmatter
│   ├── config.eex             # Config header template
│   └── test.eex               # Test file template
├── invariants/
│   ├── structural.ex          # INV-STRUCT-* definitions
│   ├── behavioral.ex          # INV-BEHAV-* definitions
│   ├── communication.ex       # INV-COMM-* definitions
│   └── operational.ex         # INV-OPER-* definitions
└── fitness/
    ├── structural.ex          # structural_integrity/1
    ├── behavioral.ex          # behavioral_correctness/1
    ├── communication.ex       # communication_health/1
    ├── operational.ex         # operational_fitness/1
    ├── metabolic.ex           # metabolic_efficiency/1
    └── stigmergic.ex          # stigmergic_coherence/1
```

### Phase 2: P0 Critical Modules (Week 1-2)

#### 3.2.1 Safety-Critical Modules (19 files)

| Module | STAMP Constraints | Priority |
|--------|-------------------|----------|
| `Indrajaal.BaseResource` | SC-DB-001, SC-ASH-001 | P0.1 |
| `Indrajaal.Repo` | SC-DB-*, SC-MIG-* | P0.1 |
| `Indrajaal.Application` | SC-EMR-057, SC-OBS-* | P0.1 |
| `Indrajaal.Safety.Guardian` | SC-NEURO-001, SC-GVF-* | P0.1 |
| `Indrajaal.Accounts.User` | SC-SEC-001, SC-SEC-003 | P0.2 |
| `Indrajaal.Accounts.Authentication` | SC-SEC-*, SC-AGT-* | P0.2 |
| `Indrajaal.Policy.Role` | SC-SEC-*, SC-AGT-018 | P0.2 |
| `Indrajaal.Alarms.ProcessingEngine` | SC-PRF-050, SC-EMR-* | P0.3 |
| `Indrajaal.AccessControl.*` | SC-SEC-*, SC-AGT-* | P0.3 |
| All 19 Ash Resources | SC-DB-001, SC-ASH-* | P0.4 |

#### 3.2.2 Core Infrastructure (15 files)

| Module | Purpose | Priority |
|--------|---------|----------|
| `IndrajaalWeb.Endpoint` | HTTP entry point | P0.1 |
| `IndrajaalWeb.Router` | Route definitions | P0.1 |
| `IndrajaalWeb.Telemetry` | Observability | P0.2 |
| `Indrajaal.PubSub` | Message broker | P0.2 |
| `Indrajaal.Observability.*` | Logging/Telemetry | P0.3 |

### Phase 3: P1 Domain Modules (Week 2-4)

#### 3.3.1 Domain Root Modules (30 files)

```
Indrajaal.Accounts
Indrajaal.Alarms
Indrajaal.AccessControl
Indrajaal.Analytics
Indrajaal.Billing
Indrajaal.Communication
Indrajaal.Compliance
Indrajaal.Cybernetic
Indrajaal.Devices
Indrajaal.Dispatch
Indrajaal.Environmental
Indrajaal.FleetManagement
Indrajaal.GuardTours
Indrajaal.Intelligence
Indrajaal.Integration
Indrajaal.Maintenance
Indrajaal.Policy
Indrajaal.Shifts
Indrajaal.Sites
Indrajaal.Training
Indrajaal.Video
Indrajaal.VisitorManagement
... (30 total)
```

#### 3.3.2 API Layer (115 files)

```
IndrajaalWeb.Api.Mobile.*           # Mobile API controllers
IndrajaalWeb.Api.Mobile.Config.*    # Configuration controllers
IndrajaalWeb.Plugs.*                # Authentication, rate limiting
IndrajaalWeb.Controllers.*          # Web controllers
```

#### 3.3.3 LiveView Modules (25 files)

```
IndrajaalWeb.Prajna.*               # C3I Mesh Cockpit
IndrajaalWeb.Operations.*           # Operations Center
IndrajaalWeb.*Live                  # Dashboard LiveViews
```

#### 3.3.4 F# CEPAF Modules (50 priority files)

```
Cepaf.Domain
Cepaf.Cockpit.*
Cepaf.Observability.*
Cepaf.Modules.*
Cepaf.Phases.*
```

### Phase 4: P2-P3 Supporting Files (Week 5-10)

#### 3.4.1 Documentation (1,697 files)

- Add YAML frontmatter to all `.md` files
- Generate from FAME metadata where possible
- Link to source code artifacts

#### 3.4.2 Scripts (4,578 files)

- Add FAME header blocks
- Categorize by purpose
- Link to related modules

#### 3.4.3 Test Files (790 files)

- Inherit metadata from source modules
- Add test-specific FAME fields
- Link to tested artifacts

---

## Part 4: Indrajaal Migration Completion Plan

### 4.1 Migration Scope

| Item | Current | Target | Criticality | Approach |
|------|---------|--------|-------------|----------|
| Directory `/lib/indrajaal_web/` | indrajaal_web | indrajaal_web | P1 | Rename + Update imports |
| Directory `/test/indrajaal_web/` | indrajaal_web | indrajaal_web | P1 | Rename + Update imports |
| Asset config `esbuild` | indrajaal | indrajaal | P2 | Config update |
| Asset config `tailwind` | indrajaal | indrajaal | P2 | Config update |
| Migrations (14) | Intelitor.Repo | Keep legacy | P4 | Document only (immutable) |
| Build artifacts | indrajaal | Delete | P4 | Clean build |

### 4.2 Migration Execution Order

#### Step 1: Pre-Migration Validation (P0)
```bash
# Verify all tests pass
mix test

# Verify compilation
mix compile --warnings-as-errors

# Create git checkpoint
git add -A && git commit -m "checkpoint: pre-indrajaal-migration"
```

#### Step 2: Directory Rename (P1)
```bash
# Rename web directory
mv lib/indrajaal_web lib/indrajaal_web

# Rename test directory
mv test/indrajaal_web test/indrajaal_web

# Update all file references
mix fame.migrate --from indrajaal_web --to indrajaal_web
```

#### Step 3: Config Update (P2)
```elixir
# config/config.exs
# Change:
config :esbuild, indrajaal: [...]
config :tailwind, indrajaal: [...]

# To:
config :esbuild, indrajaal: [...]
config :tailwind, indrajaal: [...]
```

#### Step 4: Build Cleanup (P4)
```bash
# Clean build artifacts
rm -rf _build deps
mix deps.get
mix compile
```

#### Step 5: Post-Migration Validation
```bash
# Verify compilation
mix compile --warnings-as-errors

# Verify tests
mix test

# Verify assets
mix assets.build
```

### 4.3 Files Requiring Updates

#### Directory Rename Impact Analysis

| File Type | Count | Update Required |
|-----------|-------|-----------------|
| Elixir modules in indrajaal_web | 115 | Path in mix.exs compile paths |
| Test files in test/indrajaal_web | 115 | Path references |
| Config references | 3 | esbuild, tailwind, paths |
| Import statements | ~200 | Auto-update with mix task |
| Documentation | ~50 | Path references |

---

## Part 5: Combined Implementation Schedule

### Week 1: Foundation (P0)
| Day | Activity | Deliverable |
|-----|----------|-------------|
| 1 | FAME schema definition | `lib/indrajaal/fame/schema.ex` |
| 2 | FAME validator implementation | `lib/indrajaal/fame/validator.ex` |
| 3 | Mix tasks (validate, generate) | `lib/mix/tasks/fame.*.ex` |
| 4 | Templates for all artifact types | `.fame/templates/*.eex` |
| 5 | P0 module enrichment begins | 34 critical modules |

### Week 2: Core Enrichment (P0-P1)
| Day | Activity | Deliverable |
|-----|----------|-------------|
| 1-2 | Complete P0 module enrichment | 34 modules with full FAME |
| 3 | Directory rename preparation | Migration scripts ready |
| 4 | Execute directory rename | `lib/indrajaal_web/` |
| 5 | Post-rename validation | All tests passing |

### Week 3-4: Domain Coverage (P1)
| Week | Activity | Deliverable |
|------|----------|-------------|
| 3 | Domain root modules | 30 domains enriched |
| 3 | API controllers | 115 controllers enriched |
| 4 | LiveView modules | 25 LiveViews enriched |
| 4 | F# CEPAF modules | 50 modules enriched |

### Week 5-6: Supporting Files (P2)
| Week | Activity | Deliverable |
|------|----------|-------------|
| 5 | Config files enrichment | 30 configs with headers |
| 5 | Documentation frontmatter | 500+ docs enriched |
| 6 | Script headers | 1,000+ scripts enriched |
| 6 | Asset config migration | esbuild/tailwind updated |

### Week 7-10: Completion (P3-P4)
| Week | Activity | Deliverable |
|------|----------|-------------|
| 7-8 | Test file enrichment | 790 tests enriched |
| 9 | Remaining scripts | 2,500+ scripts enriched |
| 10 | Final validation & cleanup | 100% coverage achieved |

---

## Part 6: Risk Assessment & Mitigation

### 6.1 High-Risk Items

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Directory rename breaks imports | Medium | High | Automated script with verification |
| FAME validation too strict | Low | Medium | Gradual rollout with warnings-only mode |
| Asset pipeline broken | Low | High | Test in isolated branch first |
| Migration interrupts production | Low | Critical | Execute during maintenance window |

### 6.2 Rollback Strategy

```bash
# If migration fails:
git reset --hard HEAD~1
rm -rf _build deps
mix deps.get
mix compile
```

### 6.3 Validation Checkpoints

| Checkpoint | Criteria | Gate |
|------------|----------|------|
| Pre-migration | All tests pass, clean compile | Must pass |
| Post-rename | All tests pass, clean compile | Must pass |
| Post-config | Assets build, tests pass | Must pass |
| Post-FAME | `mix fame.validate` passes | Must pass |

---

## Part 7: FAME Block Quick Reference

### Required Blocks (9)

| Block | Purpose | Criticality |
|-------|---------|-------------|
| @meta | Identity, hierarchy | P0 |
| @impact | Dependencies | P0 |
| @boundaries | Constraints (TDG/STAMP/FMEA/AOR) | P0 |
| @knowledge | Zettelkasten links | P1 |
| @evolution | Stability, change guidance | P1 |
| @metabolism | Resource management | P1 |
| @invariants | Core constraints | P0 |
| @contracts | Pre/post conditions | P1 |
| @observability | Logging/telemetry | P1 |

### Optional Blocks (3)

| Block | Purpose | When to Include |
|-------|---------|-----------------|
| @formal | Mathematical specs | Formal verification exists |
| @agent_context | AI guidance | Complex modules |
| @stigmergy | Coordination signals | Distributed components |

---

## Part 8: Success Metrics

### 8.1 Migration Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| Compilation | 0 errors, 0 warnings | `mix compile --warnings-as-errors` |
| Tests | 100% passing | `mix test` |
| Assets | Build succeeds | `mix assets.build` |
| Naming | 0 "indrajaal" in app code | `grep -r indrajaal lib/` |

### 8.2 FAME Success

| Metric | Target | Measurement |
|--------|--------|-------------|
| P0 Coverage | 100% | `mix fame.validate --tier p0` |
| P1 Coverage | 100% | `mix fame.validate --tier p1` |
| Full Coverage | 100% | `mix fame.validate` |
| Graph Integrity | 0 orphans | `mix fame.graph --verify` |
| Fitness Score | ≥ 0.95 | `mix fame.fitness` |

---

## Part 9: File Lists by Criticality

### P0 Critical Files (34 files)

```
# Core Infrastructure
lib/indrajaal/application.ex
lib/indrajaal/repo.ex
lib/indrajaal/base_resource.ex
lib/indrajaal/safety/guardian.ex
lib/indrajaal/pubsub.ex

# Web Core
lib/indrajaal_web/endpoint.ex
lib/indrajaal_web/router.ex
lib/indrajaal_web/telemetry.ex

# Authentication/Authorization
lib/indrajaal/accounts/user.ex
lib/indrajaal/accounts/authentication.ex
lib/indrajaal/accounts/session.ex
lib/indrajaal/policy/role.ex
lib/indrajaal/policy/permission.ex

# Safety-Critical Operations
lib/indrajaal/alarms/processing_engine.ex
lib/indrajaal/alarms/escalation_engine.ex
lib/indrajaal/access_control.ex
lib/indrajaal/devices/device.ex

# All 19 Ash Resources (sample)
lib/indrajaal/accounts/user.ex
lib/indrajaal/accounts/team.ex
lib/indrajaal/sites/site.ex
lib/indrajaal/devices/device.ex
... (15 more)
```

### P1 High-Priority Files (220 files)

```
# Domain Roots (30)
lib/indrajaal/accounts.ex
lib/indrajaal/alarms.ex
lib/indrajaal/access_control.ex
... (27 more)

# API Controllers (115)
lib/indrajaal_web/controllers/api/mobile/*.ex
lib/indrajaal_web/controllers/api/mobile/config/*.ex

# LiveViews (25)
lib/indrajaal_web/live/prajna/*.ex
lib/indrajaal_web/live/operations/*.ex

# F# Priority (50)
lib/cepaf/src/Cepaf/*.fs
lib/cepaf/src/Cepaf/Cockpit/*.fs
lib/cepaf/src/Cepaf/Modules/*.fs
```

---

## Part 10: Appendices

### Appendix A: FAME Schema Type Definitions

```elixir
defmodule Indrajaal.Fame.Types do
  @type artifact_id :: String.t()
  @type artifact_type :: :module | :script | :config | :doc | :spec | :test
  @type scope :: :atomic | :component | :domain | :system
  @type stability :: :volatile | :evolving | :stable | :frozen
  @type blast_radius :: :minimal | :local | :medium | :system
  @type criticality :: :p0 | :p1 | :p2 | :p3 | :p4

  @type fame_meta :: %{
    fame_version: String.t(),
    artifact_id: artifact_id(),
    artifact_type: artifact_type(),
    created: Date.t(),
    last_evolved: Date.t(),
    purpose: String.t(),
    context: String.t(),
    scope: scope(),
    parent: artifact_id() | nil,
    children: [artifact_id()],
    siblings: [artifact_id()]
  }

  # ... (remaining type definitions)
end
```

### Appendix B: Validation Commands

```bash
# Full FAME validation
mix fame.validate

# Tier-specific validation
mix fame.validate --tier p0
mix fame.validate --tier p1

# Generate missing metadata
mix fame.generate --tier p0 --dry-run
mix fame.generate --tier p0

# Build knowledge graph
mix fame.graph --output graph.json

# Run fitness evaluation
mix fame.fitness --threshold 0.95

# Migration commands
mix fame.migrate --from indrajaal_web --to indrajaal_web --dry-run
mix fame.migrate --from indrajaal_web --to indrajaal_web
```

### Appendix C: Git Commit Strategy

```bash
# Atomic commits per criticality tier
git commit -m "feat(fame): Add FAME v2.0-BIO schema and tooling [P0]"
git commit -m "feat(fame): Enrich P0 critical modules with FAME metadata"
git commit -m "refactor(naming): Rename indrajaal_web to indrajaal_web [P1]"
git commit -m "feat(fame): Enrich P1 domain modules with FAME metadata"
git commit -m "chore(config): Update asset pipeline to indrajaal naming [P2]"
git commit -m "feat(fame): Enrich P2-P3 supporting files with FAME metadata"
git commit -m "chore(cleanup): Remove legacy indrajaal artifacts [P4]"
```

---

## Conclusion

This plan provides a **criticality-based approach** to:

1. **FAME v2.0-BIO Implementation** - 8,375+ artifacts enriched with 12 metadata blocks
2. **Indrajaal Migration Completion** - Remove remaining "indrajaal" naming

**Key Milestones**:
- Week 1: FAME tooling complete, P0 enrichment started
- Week 2: P0 complete, directory rename executed
- Week 4: P1 complete (domain/API/LiveView/F#)
- Week 6: P2 complete (config/docs/scripts)
- Week 10: Full coverage achieved

**Total Effort**: 10 weeks for complete implementation

---

*This journal entry provides the master plan for FAME implementation and Indrajaal migration. Execute according to criticality tiers to ensure safety-critical components are addressed first.*
