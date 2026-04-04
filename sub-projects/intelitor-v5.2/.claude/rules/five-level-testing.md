---
paths: test/**/*.exs, test/**/*.feature, docs/testing/**/*.md
---

# Five-Level Test Coverage Rules

## Overview
All features require 5 levels of test coverage before release.

## STAMP Constraints (Coverage)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-COV-001 | Static coverage >= 100% for critical paths | CRITICAL |
| SC-COV-002 | Runtime coverage >= 95% overall | CRITICAL |
| SC-COV-003 | Mathematical proofs for core invariants | HIGH |
| SC-COV-004 | BDD specs for all user journeys | HIGH |
| SC-COV-005 | FMEA for RPN > 50 paths | HIGH |
| SC-COV-006 | TDG compliance mandatory | CRITICAL |
| SC-COV-007 | All 5 levels MUST pass before merge | CRITICAL |
| SC-COV-008 | Wallaby E2E browser tests for all LiveView pages | HIGH |

## The Five Levels

### Level 1: TDG (Test-Driven Generation)
- Tests MUST exist before implementation
- Dual property tests (PropCheck + ExUnitProperties)
- Required header:
```elixir
use PropCheck
import ExUnitProperties, except: [property: 2, property: 3, check: 2]
alias PropCheck.BasicTypes, as: PC
alias StreamData, as: SD
```

### Level 2: FMEA (Failure Mode Analysis)
- All critical paths analyzed
- RPN = Severity × Occurrence × Detection
- RPN > 100 requires documented mitigation
- Use `@tag :fmea` for FMEA tests

### Level 3: Formal Proofs
- AGDA for dependent type proofs
- Quint for temporal logic models
- Mathematica for symbolic verification
- Files in `docs/formal_specs/`

### Level 4: Graph-Based Path Analysis
- Control flow coverage
- Data flow coverage
- Call graph analysis
- FSM state coverage

### Level 5: BDD Integration
- Gherkin feature files for all user journeys
- Step definitions in `test/support/steps/`

### Level 6: E2E Browser Testing (Wallaby + Chrome via NixOS)
- **Wallaby** with Chrome/chromedriver via NixOS devenv (SC-COV-008)
- `IndrajaalWeb.FeatureCase` template with Ecto Sandbox metadata passthrough
- Run: `WALLABY_ENABLED=true mix test --only wallaby` or `test-e2e` devenv command
- Page objects in `test/support/wallaby_page_objects.ex` (23+ page modules)
- Tests use `@moduletag :wallaby` and `async: false`
- LiveView tab switching, flash messages, dynamic metric updates verified
- Screenshots on failure in `test/wallaby/screenshots/`
- Config: `config/wallaby.exs` (conditionally imported when WALLABY_ENABLED=true)
- **Gold Standard**: 8-category coverage (C1-C8) per SC-COV-009 to SC-COV-016
- **C8 Dual Verification**: Every action button tested for BOTH status change AND flash (SC-COV-016)
- **Two-Step Commit**: arm→confirm→cancel test sequences for SC-SAFETY-001 pages (SC-COV-019)
- **Coverage Entropy**: H ≥ 2.5 bits per file (balanced across 8 categories, AOR-COV-012)
- **See**: `.claude/rules/fractal-coverage-gold-standard.md` for full 8-category specification

## AOR Rules (Coverage)

| ID | Rule |
|----|------|
| AOR-COV-001 | All 5 levels MUST pass before release |
| AOR-COV-002 | New features require all 5 levels |
| AOR-COV-003 | Critical bugs require Level 2-5 regression |
| AOR-COV-004 | Formal proofs reviewed quarterly |
| AOR-COV-005 | BDD features for all user-facing changes |
| AOR-COV-006 | Wallaby E2E browser tests for all LiveView pages |
| AOR-COV-007 | FMEA update on architecture changes |

## File Locations

```
test/
├── indrajaal/           # Level 1: Unit + Property tests
├── features/            # Level 5: BDD feature files
│   ├── prajna/          # Prajna cockpit features
│   ├── ga_release/      # GA release features
│   └── *.feature        # Other features
├── fmea/               # Level 2: FMEA tests
├── formal/             # Level 3: Formal proof tests
├── graph/              # Level 4: Graph coverage tests
├── support/
│   ├── feature_case.ex  # Level 6: Wallaby FeatureCase template
│   └── wallaby_page_objects.ex  # Level 6: Page objects (23+ modules)
└── wallaby/
    └── screenshots/     # Level 6: Wallaby failure screenshots

docs/
├── formal_specs/       # AGDA, Quint, Mathematica
│   ├── *.agda
│   ├── *.qnt
│   └── *.m
└── testing/
    └── FIVE_LEVEL_TEST_COVERAGE_FRAMEWORK.md
```

## Running Tests

```bash
# Level 1: TDG
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test --cover

# Level 2: FMEA
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test --only fmea

# Level 3: Formal
agda --safe docs/formal_specs/*.agda
quint run docs/formal_specs/*.qnt

# Level 4: Graph
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix coveralls.detail

# Level 5: BDD
SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test.features

# Level 6: E2E Browser (Wallaby + Chrome via NixOS)
WALLABY_ENABLED=true SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" MIX_ENV=test mix test --only wallaby
# Or use devenv command:
test-e2e

# All Levels
./scripts/testing/run_five_level_tests.sh
```

## Validation Before Commit

```bash
# Quick validation (Levels 1, 2, 5)
mix test.quick

# Full validation (All 5 levels)
mix test.five_levels

# Coverage report
mix coveralls.html
```
