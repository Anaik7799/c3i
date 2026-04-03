# Test & Demo Integration Matrix for BEP v1.0.0
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Compliance**: IEC 61508 SIL-6 (Biomorphic Extended), SC-SIL6-*, SC-SIL6-*, SC-TDG-*, AOR-MESH-*

---

## 1.0 Overview

This document defines the integration matrix for all test and demo scripts with the Panopticon SIL-6 Biomorphic Fractal Mesh architecture. It provides:
- Complete inventory of 170+ test/demo scripts
- BEP integration mapping
- FPPS validation requirements
- Execution orchestration via SIL-6 Biomorphic Mesh CLI

### 1.1 Script Inventory Summary

| Category | Count | Location | Integration Level |
|----------|-------|----------|-------------------|
| Elixir Testing Scripts | 100+ | `scripts/testing/` | L3-L5 |
| Elixir Demo Scripts | 56 | `scripts/demo/` | L2-L4 |
| F# Runtime Scripts | 14 | `lib/cepaf/scripts/` | L4-L5 |
| **Total** | **170+** | | Full BEP Coverage |

---

## 2.0 Elixir Testing Scripts (100+)

### 2.1 TDG Validation Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `tdg_validator.exs` | Core TDG methodology validation | `sa-test` execution | SC-TDG-001 |
| `tdg_mix_alias_validator.exs` | Mix alias TDG compliance | Quality gate | SC-TDG-002 |
| `tdg_observability_validator.exs` | Observability TDG tests | OTEL integration | SC-TDG-003 |
| `tdg_container_dialyzer_validation.exs` | Container dialyzer TDG | Build validation | SC-TDG-004 |
| `container_conversion_tdg_validator.exs` | Container migration TDG | Migration tests | SC-TDG-005 |
| `analytics_tdg_validation.exs` | Analytics domain TDG | Domain tests | SC-TDG-006 |
| `systematic_tdg_compliance_generator.exs` | Auto-generate TDG tests | CI/CD pipeline | SC-TDG-007 |

### 2.2 Container Health Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `container_health_validator.exs` | Container health checks | `sa-health` | SC-SIL6-005 |
| `simple_container_health_validator.exs` | Quick health check | Preflight stage | SC-SIL6-001 |
| `container_phics_runtime_validator.exs` | PHICS runtime validation | Convergence stage | SC-PRF-050 |
| `container_phics_test_validator.exs` | PHICS test validation | Test execution | SC-PRF-050 |
| `container_execution_validator.exs` | Container execution checks | Ignition stage | SC-CNT-009 |
| `container_demo_scenario_tester.exs` | Demo scenario in containers | Demo validation | SC-SIL6-005 |
| `container_native_stamp_test_runner.exs` | Native STAMP tests | Safety validation | SC-VAL-003 |
| `comprehensive_containerized_test_executor.exs` | Full container test suite | `sa-test` | SC-SIL6-018 |

### 2.3 STAMP/GDE Validation Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `stamp_gde_validation_framework.exs` | Core STAMP+GDE validation | Guardian approval | SC-GDE-001 |
| `stamp_tdg_gde_methodology_validator.exs` | Combined methodology | Quality gate | SC-VAL-003 |
| `stamp_tdg_gde_exhaustive_demo_validator.exs` | Exhaustive validation | Full pipeline | SC-VAL-003 |

### 2.4 Coverage & Quality Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `test_coverage_analysis.exs` | Coverage metrics | `test-cover` | SC-COV-001 |
| `test_coverage_summary.exs` | Coverage report | CI/CD gate | SC-COV-002 |
| `current_test_coverage_analysis.exs` | Current state analysis | Dashboard | SC-COV-001 |
| `comprehensive_coverage_parser.exs` | Parse coverage data | Telemetry | SC-COV-001 |
| `execute_100_percent_coverage.exs` | 100% coverage target | Release gate | SC-COV-001 |
| `quality_assurance_integration.exs` | QA integration | Quality pipeline | SC-CREDO-001 |

### 2.5 Performance & Scalability Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `comprehensive_performance_regression.exs` | Performance regression | CI/CD | SC-PRF-050 |
| `comprehensive_scalability_regression.exs` | Scalability tests | Load testing | SC-PRF-055 |
| `performance_reliability_testing.exs` | Reliability tests | Soak testing | SC-PRF-050 |
| `performance_module_test_generator.exs` | Auto-generate perf tests | TDG | SC-PRF-050 |
| `12_hour_soak_test_monitor.exs` | Long-running soak test | Production validation | SC-PRF-050 |
| `compilation_profiler.exs` | Compile time profiling | Patient Mode | SC-CMP-028 |

### 2.6 Enterprise & Integration Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `enterprise_testing_compliance_report.exs` | Compliance reporting | Audit | SC-DOC-001 |
| `enterprise_reporting_system.exs` | Report generation | Analytics | SC-OBS-069 |
| `enterprise_monitoring_integration_testing.exs` | Monitoring tests | OTEL | SC-OBS-071 |
| `functional_correctness_validator.exs` | Functional tests | Core validation | SC-VAL-003 |
| `behavioral_verification_system.exs` | Behavior verification | BDD | SC-BDD-001 |

### 2.7 Disaster Recovery Category

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `disaster_recovery_rollback_testing.exs` | DR rollback tests | Apoptosis protocol | SC-EMR-060 |
| `production_deployment_simulation.exs` | Deployment simulation | Release validation | SC-GA-007 |
| `comprehensive_release_pipeline.exs` | Release pipeline | CI/CD | SC-GA-001 |

---

## 3.0 Elixir Demo Scripts (56)

### 3.1 Domain Enterprise Demos

| Script | Domain | BEP Integration | FPPS Method |
|--------|--------|-----------------|-------------|
| `alarms_enterprise_demo.exs` | Alarms | `sa-test` workflow | Pattern |
| `accounts_enterprise_demo.exs` | Accounts | Tenant management | AST |
| `access_control_enterprise_demo.exs` | Access Control | RBAC validation | Statistical |
| `analytics_enterprise_demo.exs` | Analytics | Dashboard demos | LineByLine |
| `automation_enterprise_demo.exs` | Automation | Rule engine | Pattern |
| `backup_enterprise_demo.exs` | Backup | State checkpoint | Binary |
| `communication_enterprise_demo.exs` | Communication | Message delivery | Pattern |
| `compliance_enterprise_demo.exs` | Compliance | Audit trail | LineByLine |
| `devices_enterprise_demo.exs` | Devices | Device lifecycle | AST |
| `guard_tours_enterprise_demo.exs` | Guard Tours | Patrol routes | Statistical |
| `integration_enterprise_demo.exs` | Integration | API demos | Pattern |
| `mobile_enterprise_demo.exs` | Mobile | App simulation | AST |
| `reports_enterprise_demo.exs` | Reports | PDF generation | Binary |
| `risk_management_enterprise_demo.exs` | Risk | Assessment flow | Statistical |
| `sites_enterprise_demo.exs` | Sites | Site hierarchy | AST |
| `system_enterprise_demo.exs` | System | Core system | LineByLine |
| `video_analytics_enterprise_demo.exs` | Video | Stream analysis | Statistical |
| `visitor_management_enterprise_demo.exs` | Visitors | Check-in flow | Pattern |
| `work_orders_enterprise_demo.exs` | Work Orders | Maintenance | AST |

### 3.2 Alarm Processing Demos

| Script | Purpose | BEP Integration |
|--------|---------|-----------------|
| `alarm_processing_demo.exs` | Core alarm flow | `sa-test` |
| `alarm_processing_demo_detailed.exs` | Detailed alarm trace | OTEL spans |
| `alarm_processing_demo_simple.exs` | Minimal alarm demo | Quick validation |
| `alarm_processing_demo_standalone.exs` | No-DB alarm demo | Unit testing |
| `alarm_ash_integration_demo.exs` | Ash resource demo | Ash 3.x validation |
| `alarm_integration_summary.exs` | Integration summary | Documentation |
| `test_alarm_processing_integration.exs` | Integration tests | CI/CD |
| `test_alarm_processing_with_db.exs` | DB-backed tests | Full stack |
| `test_alarm_functionality.exs` | Functional tests | Core validation |

### 3.3 Container Demo Scripts

| Script | Purpose | BEP Integration |
|--------|---------|-----------------|
| `container_demo_with_phoenix.exs` | Phoenix in container | `sa-app` |
| `container_aware_continuous_demo.exs` | Continuous container demo | `sa-up` + `sa-test` |
| `comprehensive_containerized_demo_executor.exs` | Full container demos | Complete workflow |
| `validate_demo_ready_containers.exs` | Pre-demo validation | Preflight stage |

### 3.4 SOPv5.11 Demo Scripts

| Script | Purpose | BEP Integration |
|--------|---------|-----------------|
| `sopv51_framework.exs` | SOPv5.11 framework | Methodology |
| `sopv51_demo_validation.exs` | Demo validation | Quality gate |
| `sop_v51_continuous_enterprise_demo.exs` | Continuous demos | Long-running |
| `continuous_enterprise_demo_executor.exs` | Demo orchestrator | `sa-orchestrate` |
| `bulk_update_enterprise_demos_sopv51.exs` | Batch update demos | Maintenance |
| `update_all_demo_scripts_sopv51.exs` | Full update | Migration |

### 3.5 Validation & Health Demos

| Script | Purpose | BEP Integration |
|--------|---------|-----------------|
| `demo_validator_fixed.exs` | Demo validation | Pre-check |
| `demo_readiness_validator.exs` | Readiness check | Preflight |
| `demo_health_validator.exs` | Health validation | `sa-health` |
| `simple_demo_validator.exs` | Quick validation | Fast feedback |
| `simple_demo_check.exs` | Minimal check | Smoke test |
| `validate_all_demo_paths.exs` | Path validation | Route check |

---

## 4.0 F# Runtime Scripts (14)

### 4.1 Core F# Scripts

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `RuntimeTestOrchestrator.fsx` | Test orchestration | `sa-orchestrate` | SC-SIL6-020 |
| `CockpitUXEvaluator.fsx` | UX/UI evaluation | `sa-ux` | SC-SIL6-019 |
| `SIL6Orchestrator.fsx` | SIL-6 Biomorphic compliance | `sa-verify` | SC-SIL6-006 |
| `ComprehensiveRuntimeTests.fsx` | Runtime test suite | `sa-test` | SC-SIL6-018 |
| `KmsSil4Verification.fsx` | KMS verification | State validation | SC-HOLON-017 |
| `CockpitOperations.fsx` | Cockpit lifecycle | `cockpitf` | SC-SYNC-001 |
| `ProductionDeploymentOrchestrator.fsx` | Deployment flow | Production | SC-GA-007 |

### 4.2 Fractal & TUI Scripts

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `FractalRuntimeValidator.fsx` | Fractal validation | L1-L7 coverage | SC-COV-003 |
| `FractalDocumentIngestion.fsx` | Document ingestion | Knowledge base | SC-HOLON-003 |
| `FractalIngestionCockpit.fsx` | Ingestion UI | Dashboard | SC-PRAJNA-003 |
| `fractal-tui.fsx` | Terminal UI | Interactive mode | SC-PROM-003 |
| `ThemeSimulatorRunner.fsx` | Theme simulation | UX testing | SC-SIL6-019 |

### 4.3 Integration Scripts

| Script | Purpose | BEP Integration | STAMP |
|--------|---------|-----------------|-------|
| `cockpit_test_integration.fsx` | Cockpit integration | Bridge testing | SC-SYNC-001 |
| `test-manager.fsx` | Test management | Test lifecycle | SC-TDG-001 |

---

## 5.0 BEP Integration Workflow

### 5.1 Standard Test Workflow

```bash
# 1. Start mesh (5-stage boot)
sa-up

# 2. Run F# runtime tests
sa-test --mode swarm

# 3. Run Elixir TDG validation
elixir scripts/testing/tdg_validator.exs

# 4. Run demo scenarios
elixir scripts/demo/continuous_enterprise_demo_executor.exs

# 5. Run UX evaluation
sa-ux

# 6. Generate coverage report
test-cover

# 7. Verify 2oo3 consensus
sa-verify

# 8. Graceful shutdown
sa-down
```

### 5.2 FPPS 5-Method Integration

| Method | Test Scripts | Demo Scripts | F# Scripts |
|--------|--------------|--------------|------------|
| **Pattern** | `tdg_validator.exs` | Domain demos | `RuntimeTestOrchestrator.fsx` |
| **AST** | `behavioral_verification_system.exs` | Ash demos | `FractalRuntimeValidator.fsx` |
| **Statistical** | `test_coverage_analysis.exs` | Performance demos | `CockpitUXEvaluator.fsx` |
| **Binary** | `container_health_validator.exs` | Backup demos | `KmsSil4Verification.fsx` |
| **LineByLine** | `stamp_gde_validation_framework.exs` | Compliance demos | `SIL6Orchestrator.fsx` |

### 5.3 5-Order Effects Matrix

| Order | Testing Phase | Demo Phase | F# Phase |
|-------|--------------|------------|----------|
| 1st | Tests spawn | Demos initialize | Scripts load |
| 2nd | DB sandboxed | Ash resources created | Containers accessed |
| 3rd | Assertions run | Workflows execute | FPPS consensus |
| 4th | Coverage collected | Reports generated | Dashboard updated |
| 5th | CI gate decision | GA validation | Release ready |

---

## 6.0 STAMP Constraints

| ID | Constraint | Integration |
|----|------------|-------------|
| SC-TDG-001 | TDG validation MUST precede code gen | `tdg_validator.exs` |
| SC-TDG-002 | Dual property tests MANDATORY | PropCheck + StreamData |
| SC-TDG-003 | FPPS 5-method consensus REQUIRED | `sa-verify` |
| SC-SIL6-018 | Runtime tests via `sa-test` | F# orchestrator |
| SC-SIL6-019 | UX evaluation via `sa-ux` | `CockpitUXEvaluator.fsx` |
| SC-SIL6-020 | Test orchestration via F# | `RuntimeTestOrchestrator.fsx` |

---

## 7.0 AOR Rules

| ID | Rule |
|----|------|
| AOR-TEST-001 | Run TDG validation before any code changes |
| AOR-TEST-002 | Use `sa-test` for runtime test execution |
| AOR-TEST-003 | Demo scripts validate business workflows |
| AOR-TEST-004 | F# scripts orchestrate multi-stage tests |
| AOR-TEST-005 | FPPS consensus REQUIRED for critical paths |
| AOR-TEST-006 | Coverage gate >= 95% for release |

---

## 8.0 Quick Reference Commands

```bash
# TDG Validation
elixir scripts/testing/tdg_validator.exs

# Container Health
elixir scripts/testing/container_health_validator.exs

# STAMP/GDE Validation
elixir scripts/testing/stamp_gde_validation_framework.exs

# Domain Demo (example: Alarms)
elixir scripts/demo/alarms_enterprise_demo.exs

# Continuous Demo
elixir scripts/demo/continuous_enterprise_demo_executor.exs

# F# Runtime Tests
dotnet fsi lib/cepaf/scripts/RuntimeTestOrchestrator.fsx

# F# UX Evaluation
dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx

# Full BEP Workflow (SC-TEST-005 compliant)
SKIP_ZENOH_NIF=0 sa-up && SKIP_ZENOH_NIF=0 sa-test && sa-ux && sa-verify && sa-down
```

---

## 9.0 Related Documents

- [AGENT_BOOTSTRAP.md](../../AGENT_BOOTSTRAP.md) - Agent onboarding
- [CLAUDE.md](../../CLAUDE.md) / [GEMINI.md](../../GEMINI.md) - System specifications
- [USER_OPERATIONS_GUIDE.md](../../USER_OPERATIONS_GUIDE.md) - User operations and command reference
- [SIL6_MESH_CLI_USER_GUIDE.md](../SIL6_MESH_CLI_USER_GUIDE.md) - CLI operations
- [testing.md](./testing.md) - Testing guidelines and patterns
- [comprehensive-testing-rules.md](./comprehensive-testing-rules.md) - Comprehensive testing standards
- [CHAOS_TESTS_QUICK_REFERENCE.md](./CHAOS_TESTS_QUICK_REFERENCE.md) - Chaos testing reference
- [docs/plans/BEP_V1_DOCUMENTATION_PLAN.md](../plans/BEP_V1_DOCUMENTATION_PLAN.md) - BEP plan
