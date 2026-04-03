# Script-to-Test-Level Mapping
**Version**: 21.1.0 Founder's Covenant
**Date**: 2026-01-03
**Framework**: 5-Level Fractal Test Infrastructure

---

## Overview

This document maps the 1,485 existing scripts to the 5-level fractal test framework:

| Level | Name | Framework | Script Count |
|-------|------|-----------|--------------|
| 1 | TDG | PropCheck + ExUnitProperties | 40+ |
| 2 | FMEA | Failure Mode Analysis | 25+ |
| 3 | Formal | Agda + Quint + Mathematica + Dialyzer | 35+ |
| 4 | Graph | Coverage + Dependency Analysis | 15+ |
| 5 | BDD | Cucumber + SpecFlow + Playwright | 20+ |

---

## Level 1: TDG (Test-Driven Generation)

### Core TDG Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| analytics_tdg_validation.exs | scripts/testing/ | Analytics TDG compliance | SC-COV-006 |
| systematic_tdg_compliance_generator.exs | scripts/testing/ | Generate TDG tests | SC-COV-006 |
| comprehensive_tdg_framework.exs | scripts/validation/ | TDG implementation | SC-COV-006 |
| stamp_tdg_gde_methodology_validator.exs | scripts/testing/ | STAMP+TDG+GDE validation | SC-COV-006 |
| container_conversion_tdg_validator.exs | scripts/testing/ | Container TDG | SC-COV-006 |
| tdg_pre_generation_validator.exs | scripts/validation/ | Pre-gen validation | SC-COV-006 |
| tdg_post_generation_validator.exs | scripts/validation/ | Post-gen validation | SC-COV-006 |

### Property Testing Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| unified_property_testing_orchestrator.exs | scripts/property_testing/ | PropCheck + StreamData | SC-PROP-023 |
| propcheck_generators/* | scripts/property_testing/ | PropCheck generators | SC-PROP-021 |
| stream_data_generators/* | scripts/property_testing/ | StreamData generators | SC-PROP-022 |

### Integration with TestCockpit

```elixir
# Elixir: Run TDG tests via TestCockpit
Indrajaal.Cockpit.Prajna.TestCockpit.run_level(1)

# Invokes scripts:
# - scripts/testing/analytics_tdg_validation.exs
# - scripts/property_testing/unified_property_testing_orchestrator.exs
```

```fsharp
// F#: Run TDG tests via TestCockpit
TestCockpit.runTDGTests()

// Equivalent to:
// mix test --only property
// mix run scripts/property_testing/unified_property_testing_orchestrator.exs
```

---

## Level 2: FMEA (Failure Mode & Effects Analysis)

### Core FMEA Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| behavioral_verification_system.exs | scripts/testing/ | Behavioral snapshots | SC-COV-005 |
| comprehensive_warning_classification_engine.exs | scripts/validation/ | RPN severity | SC-FMEA-001 |
| performance_reliability_testing.exs | scripts/testing/ | Chaos testing | SC-COV-005 |
| comprehensive_stamp_safety_constraint_validator.exs | scripts/validation/ | STAMP validation | SC-VAL-003 |
| enhanced_stamp_tdg_compilation_validator.exs | scripts/validation/ | Enhanced validation | SC-COV-005 |

### FMEA Categories

| Category | RPN Threshold | Scripts |
|----------|---------------|---------|
| Variable Typos | CRITICAL (72+) | comprehensive_final_variable_eliminator.exs |
| apply/2 Pattern | HIGH (64) | fix_apply_pattern.exs |
| Duplicate Code | MEDIUM (48) | duplicate_code_validator.exs |
| Missing @spec | LOW (24) | spec_coverage_validator.exs |

### Integration with TestCockpit

```elixir
# Elixir: Run FMEA tests via TestCockpit
Indrajaal.Cockpit.Prajna.TestCockpit.run_level(2)

# Analyzes RPN > 50 failure modes
```

```fsharp
// F#: Run FMEA tests via TestCockpit
TestCockpit.runFMEATests()

// Generates FMEA report with RPN scores
```

---

## Level 3: Formal Verification

### Core Formal Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| master_safety_protocol.exs | scripts/verification/ | SIL-2 verification | SC-COV-003 |
| comprehensive_compilation_validator.exs | scripts/validation/ | 130+ error patterns | SC-COV-003 |
| ultimate_comprehensive_false_positive_prevention_engine.exs | scripts/validation/ | 5-method FPPS | SC-VAL-003 |
| comprehensive_dialyzer_container_setup.exs | scripts/performance/ | Type checking | SC-COV-003 |
| safety_critical_clean_build.exs | scripts/verification/ | Clean room build | SC-COV-003 |

### Formal Tools Integration

| Tool | Script | Purpose |
|------|--------|---------|
| Dialyzer | comprehensive_dialyzer_container_setup.exs | Static type analysis |
| FPPS | ultimate_comprehensive_false_positive_prevention_engine.exs | 5-method consensus |
| Credo | quality_assurance_integration.exs | Code quality |
| Sobelow | security_validation.exs | Security analysis |

### Integration with TestCockpit

```elixir
# Elixir: Run Formal verification via TestCockpit
Indrajaal.Cockpit.Prajna.TestCockpit.run_level(3)

# Runs: mix dialyzer && mix credo --strict && mix sobelow
```

```fsharp
// F#: Run Formal verification via TestCockpit
TestCockpit.runFormalVerification()

// Validates Agda proofs, Quint models, Mathematica specs
```

---

## Level 4: Graph Analysis (Coverage)

### Core Graph Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| 11_agent_coordination_test_framework.exs | scripts/testing/ | Agent DAGs | SC-COV-001 |
| advanced_mix_task_classifier.exs | scripts/testing/ | Dependency mapping | SC-COV-001 |
| comprehensive_coverage_parser.exs | scripts/testing/ | Coverage analysis | SC-COV-002 |
| test_coverage_analysis.exs | scripts/testing/ | Domain coverage | SC-COV-002 |
| comprehensive_test_coverage_framework.exs | scripts/testing/ | 100% coverage | SC-COV-001 |

### Coverage Targets

| Domain | Target | Script |
|--------|--------|--------|
| Core | 100% | comprehensive_test_coverage_framework.exs |
| Accounts | 95% | business_domain_assessment.exs |
| Alarms | 95% | business_domain_assessment.exs |
| Devices | 95% | business_domain_assessment.exs |
| Access Control | 95% | business_domain_assessment.exs |
| Video | 95% | business_domain_assessment.exs |

### Integration with TestCockpit

```elixir
# Elixir: Run Graph analysis via TestCockpit
Indrajaal.Cockpit.Prajna.TestCockpit.run_level(4)

# Generates coverage paths and dependency graphs
```

```fsharp
// F#: Run Graph analysis via TestCockpit
TestCockpit.runGraphAnalysis()

// Returns coverage_percentage, total_paths, critical_paths
```

---

## Level 5: BDD (Behavior-Driven Development)

### Core BDD Scripts

| Script | Path | Purpose | STAMP |
|--------|------|---------|-------|
| behavioral_verification_system.exs | scripts/testing/ | BDD verification | SC-COV-004 |
| container_demo_scenario_tester.exs | scripts/testing/ | Demo scenarios | SC-COV-004 |
| demo_command_validation_test_plan.exs | scripts/testing/ | Command validation | SC-COV-004 |
| demo_execution_validator.exs | scripts/testing/ | Demo execution | SC-COV-004 |
| stamp_tdg_gde_exhaustive_demo_validator.exs | scripts/testing/ | Exhaustive validation | SC-COV-004 |

### BDD Feature Coverage

| Feature | Script | Scenarios |
|---------|--------|-----------|
| Alarm Processing | container_demo_scenario_tester.exs | 15+ |
| Access Control | business_domain_assessment.exs | 12+ |
| Device Management | business_domain_assessment.exs | 10+ |
| Video Analytics | business_domain_assessment.exs | 8+ |
| Compliance | enterprise_testing_compliance_report.exs | 20+ |

### Integration with TestCockpit

```elixir
# Elixir: Run BDD tests via TestCockpit
Indrajaal.Cockpit.Prajna.TestCockpit.run_level(5)

# Runs Cucumber features + Playwright browser tests
```

```fsharp
// F#: Run BDD tests via TestCockpit
TestCockpit.runBDDTests()

// Runs SpecFlow features + Playwright integration
```

---

## 1-5 Order Effects Mapping

### Order 1 (0-100ms): Immediate

| Script Category | Effect | Example Script |
|-----------------|--------|----------------|
| Compilation | .beam files generated | fast_compile.exs |
| Syntax Check | Errors detected | check_syntax.exs |
| Format | Code formatted | mix format --check |

### Order 2 (100ms-10s): Adjacent

| Script Category | Effect | Example Script |
|-----------------|--------|----------------|
| NIF Compile | Rustler builds | nif_guard.exs |
| Ash DSL | Resources expand | ash_api_discovery.exs |
| Credo | Warnings reported | quality_assurance_integration.exs |

### Order 3 (10s-60s): Integration

| Script Category | Effect | Example Script |
|-----------------|--------|----------------|
| Phoenix Reload | Hot-reload active | phics_hot_reloading_integration.exs |
| Container Start | Services up | container_execution_validator.exs |
| DB Migration | Schema updated | comprehensive_migration_validator.exs |

### Order 4 (1-5min): Capability

| Script Category | Effect | Example Script |
|-----------------|--------|----------------|
| Test Suite | All tests pass | comprehensive_release_pipeline.exs |
| Coverage | 95%+ achieved | comprehensive_test_coverage_framework.exs |
| Dialyzer | Types verified | comprehensive_dialyzer_container_setup.exs |

### Order 5 (5min+): Ecosystem

| Script Category | Effect | Example Script |
|-----------------|--------|----------------|
| Container Build | Image created | create_service_images.exs |
| Deploy Ready | CI/CD passes | enterprise_testing_compliance_report.exs |
| GA Release | Version tagged | stamp_tdg_gde_production_readiness.exs |

---

## Jenkins Pipeline Integration

### Stage-to-Script Mapping

```groovy
// Jenkinsfile stage mapping
stages {
    stage('Level 1: TDG') {
        // scripts/testing/analytics_tdg_validation.exs
        // scripts/property_testing/unified_property_testing_orchestrator.exs
        sh 'mix test --only property'
    }

    stage('Level 2: FMEA') {
        // scripts/validation/comprehensive_warning_classification_engine.exs
        sh 'mix run scripts/testing/behavioral_verification_system.exs'
    }

    stage('Level 3: Formal') {
        // scripts/verification/master_safety_protocol.exs
        // scripts/performance/comprehensive_dialyzer_container_setup.exs
        sh 'mix dialyzer && mix credo --strict && mix sobelow'
    }

    stage('Level 4: Graph') {
        // scripts/testing/comprehensive_test_coverage_framework.exs
        sh 'mix test --cover'
    }

    stage('Level 5: BDD') {
        // scripts/testing/container_demo_scenario_tester.exs
        sh 'mix test --only integration --only e2e'
    }
}
```

---

## Script Statistics

| Category | Count | Lines of Code |
|----------|-------|---------------|
| Testing | 95+ | 71,192+ |
| Validation | 160+ | 50,000+ |
| Performance | 20 | 15,000+ |
| Coordination | 35+ | 25,000+ |
| Verification | 5 | 8,000+ |
| Property Testing | 5+ | 5,000+ |
| Root Level | 45+ | 20,000+ |
| **Total** | **1,485** | **195,000+** |

---

## Usage

### Run All Levels

```bash
# Via devenv
devenv shell
test  # Runs all 5 levels

# Via mix
mix test --cover

# Via TestCockpit
mix run -e "Indrajaal.Cockpit.Prajna.TestCockpit.run_all()"
```

### Run Specific Level

```bash
# Level 1: TDG
mix test --only property

# Level 2: FMEA
mix run scripts/testing/behavioral_verification_system.exs

# Level 3: Formal
mix dialyzer

# Level 4: Graph
mix test --cover

# Level 5: BDD
mix test --only integration
```

### Run Domain-Specific

```bash
# Alarms domain
mix run scripts/testing/business_domain_assessment.exs --domain alarms

# All domains
mix run scripts/testing/business_domain_assessment.exs --all
```

---

## STAMP Compliance

| Constraint | Implementation | Status |
|------------|----------------|--------|
| SC-COV-001 | 100% static coverage | Level 4 Graph |
| SC-COV-002 | 95%+ runtime coverage | Level 4 Graph |
| SC-COV-003 | Formal proofs | Level 3 Formal |
| SC-COV-004 | BDD specs | Level 5 BDD |
| SC-COV-005 | FMEA RPN > 50 | Level 2 FMEA |
| SC-COV-006 | TDG compliance | Level 1 TDG |
| SC-CI-001 | Reproducible builds | Jenkinsfile |
| SC-CI-007 | 5 levels pass | Jenkins pipeline |

---

**End of Document**
