# Fractal Test Framework Master Plan
**Version**: 21.1.0-FOUNDERS-COVENANT | **Date**: 2026-01-03
**STAMP**: SC-COV-001 to SC-COV-008 | **Status**: ACTIVE

## 1.0 Executive Summary

This document defines the comprehensive 5-level fractal test coverage framework for the Indrajaal Security Platform, covering:
- **780+ Elixir modules** across 30 domains
- **90+ CEPAF F# modules** with Category Theory foundations
- **38 LiveView pages** with Puppeteer automation
- **250+ REST API endpoints** with OpenAPI validation
- **55+ demo scripts** mapped to test plans
- **100+ testing scripts** synchronized with coverage

## 2.0 The 5-Level Coverage Hierarchy

```
Level 5: BDD Integration (Cucumber + SpecFlow + Puppeteer)
    ├── Feature files → Step definitions → UI automation
    │
Level 4: Graph-Based Path Analysis
    ├── Control flow → Data flow → Call graph → FSM coverage
    │
Level 3: Formal Proofs (AGDA + Quint + Mathematica)
    ├── Dependent types → Temporal logic → Symbolic verification
    │
Level 2: FMEA (Failure Mode Effects Analysis)
    ├── RPN scores → Mitigations → Safety constraints
    │
Level 1: TDG (Test-Driven Generation)
    └── PropCheck + ExUnitProperties → Dual property testing
```

## 3.0 1st-5th Order Effects Model

Every test covers effects at 5 orders of cascade:

| Order | Time Scale | Question | Telemetry Event |
|-------|------------|----------|-----------------|
| **1st** | Immediate (0-100ms) | What direct action occurs? | `[:cmd, :start]` |
| **2nd** | Seconds (100ms-10s) | What adjacent systems react? | `[:cascade, :adjacent]` |
| **3rd** | Seconds-Minutes (10s-60s) | What integration effects? | `[:cascade, :integration]` |
| **4th** | Minutes (1-5min) | What capabilities unlock? | `[:cascade, :capability]` |
| **5th** | Minutes-Hours (5min+) | What ecosystem effects? | `[:cascade, :ecosystem]` |

### 3.1 Effect Chain Examples

```
DOMAIN: :alarms
ACTION: :process_alarm

Order 1 (Immediate):
  - Alarm received and parsed
  - Initial classification applied
  - Telemetry: [:alarms, :received]

Order 2 (Seconds):
  - Correlation engine triggered
  - Zone mapping applied
  - Sentinel notified
  - Telemetry: [:alarms, :correlated]

Order 3 (Seconds-Minutes):
  - Workflow triggered
  - Notification sent
  - Dashboard updated
  - Telemetry: [:alarms, :notified]

Order 4 (Minutes):
  - Dispatch recommended
  - Response tracked
  - SLA timer started
  - Telemetry: [:alarms, :dispatched]

Order 5 (Minutes-Hours):
  - Compliance logged
  - Analytics updated
  - Pattern learned
  - Telemetry: [:alarms, :completed]
```

## 4.0 Domain-to-Test Mapping (30 Domains)

### 4.1 P0 Critical Domains (Safety-Critical)

| Domain | Modules | Demo Script | Test Script | BDD Feature |
|--------|---------|-------------|-------------|-------------|
| `alarms` | 45 | `alarms_enterprise_demo.exs` | `alarm_processing_integration.exs` | `alarms.feature` |
| `access_control` | 32 | `access_control_enterprise_demo.exs` | `rbac_state_machine_test.exs` | `access_control.feature` |
| `authentication` | 18 | `accounts_enterprise_demo.exs` | `auth_security_test.exs` | `authentication.feature` |
| `safety` | 25 | N/A | `fmea_hazard_analysis_test.exs` | `safety.feature` |
| `guardian` | 12 | N/A | `guardian_integration_test.exs` | `guardian_approval.feature` |
| `sentinel` | 15 | N/A | `sentinel_bridge_test.exs` | `sentinel.feature` |

### 4.2 P1 High Priority Domains

| Domain | Modules | Demo Script | Test Script | BDD Feature |
|--------|---------|-------------|-------------|-------------|
| `devices` | 38 | `devices_enterprise_demo.exs` | `device_failsafe_test.exs` | `devices.feature` |
| `video` | 42 | `video_analytics_enterprise_demo.exs` | `video_stream_test.exs` | `video.feature` |
| `dispatch` | 28 | `guard_tours_enterprise_demo.exs` | `dispatch_workflow_test.exs` | `dispatch.feature` |
| `analytics` | 35 | `analytics_enterprise_demo.exs` | `analytics_engine_test.exs` | `analytics.feature` |
| `compliance` | 22 | `compliance_enterprise_demo.exs` | `sil_compliance_test.exs` | `compliance.feature` |
| `communication` | 30 | `communication_enterprise_demo.exs` | `safety_critical_comm_test.exs` | `communication.feature` |

### 4.3 P2 Standard Domains

| Domain | Modules | Demo Script | Test Script | BDD Feature |
|--------|---------|-------------|-------------|-------------|
| `accounts` | 25 | `accounts_enterprise_demo.exs` | `accounts_factory_test.exs` | `accounts.feature` |
| `sites` | 20 | `sites_enterprise_demo.exs` | `sites_hierarchy_test.exs` | `sites.feature` |
| `maintenance` | 18 | `work_orders_enterprise_demo.exs` | `maintenance_schedule_test.exs` | `maintenance.feature` |
| `integration` | 22 | `integration_enterprise_demo.exs` | `integration_flow_test.exs` | `integration.feature` |
| `automation` | 15 | `automation_enterprise_demo.exs` | `automation_rule_test.exs` | `automation.feature` |
| `mobile` | 12 | `mobile_enterprise_demo.exs` | `mobile_socket_test.exs` | `mobile.feature` |

### 4.4 Infrastructure Domains

| Domain | Modules | Demo Script | Test Script | BDD Feature |
|--------|---------|-------------|-------------|-------------|
| `cluster` | 18 | `system_enterprise_demo.exs` | `cluster_topology_test.exs` | `cluster.feature` |
| `mesh` | 15 | N/A | `zenoh_mesh_test.exs` | `mesh.feature` |
| `observability` | 35 | `performance_monitoring_demo_executor.exs` | `otel_signoz_integration_test.exs` | `observability.feature` |
| `cockpit` | 28 | N/A | `prajna_cockpit_test.exs` | `prajna_cockpit.feature` |
| `cortex` | 22 | N/A | `container_health_sensor_test.exs` | `cortex.feature` |
| `distributed` | 20 | N/A | `distributed_kpi_test.exs` | `distributed.feature` |

## 5.0 LiveView Pages (38 Pages)

### 5.1 Prajna Cockpit Pages (22)

| Page | Route | Puppeteer Test | BDD Scenario |
|------|-------|----------------|--------------|
| Dashboard | `/prajna` | `prajna_dashboard_test.js` | `prajna_cockpit.feature:12` |
| Alarms | `/prajna/alarms` | `prajna_alarms_test.js` | `prajna_cockpit.feature:45` |
| Devices | `/prajna/devices` | `prajna_devices_test.js` | `prajna_cockpit.feature:78` |
| Access Control | `/prajna/access` | `prajna_access_test.js` | `prajna_cockpit.feature:110` |
| Video | `/prajna/video` | `prajna_video_test.js` | `prajna_cockpit.feature:145` |
| Analytics | `/prajna/analytics` | `prajna_analytics_test.js` | `prajna_cockpit.feature:180` |
| Compliance | `/prajna/compliance` | `prajna_compliance_test.js` | `prajna_cockpit.feature:210` |
| Cluster | `/prajna/cluster` | `prajna_cluster_test.js` | `prajna_cockpit.feature:245` |
| Copilot | `/prajna/copilot` | `prajna_copilot_test.js` | `prajna_cockpit.feature:280` |
| Containers | `/prajna/containers` | `prajna_containers_test.js` | `prajna_cockpit.feature:310` |
| Guardian | `/prajna/guardian` | `prajna_guardian_test.js` | `prajna_cockpit.feature:345` |
| Sentinel | `/prajna/sentinel` | `prajna_sentinel_test.js` | `prajna_cockpit.feature:380` |
| Register | `/prajna/register` | `prajna_register_test.js` | `prajna_cockpit.feature:410` |
| Commands | `/prajna/commands` | `prajna_commands_test.js` | `prajna_cockpit.feature:445` |
| Diagnostics | `/prajna/diagnostics` | `prajna_diagnostics_test.js` | `prajna_cockpit.feature:480` |
| Observability | `/prajna/observability` | `prajna_observability_test.js` | `prajna_cockpit.feature:510` |
| Mesh | `/prajna/mesh` | `prajna_mesh_test.js` | `prajna_cockpit.feature:545` |
| Settings | `/prajna/settings` | `prajna_settings_test.js` | `prajna_cockpit.feature:580` |
| Startup | `/prajna/startup` | `prajna_startup_test.js` | `prajna_cockpit.feature:615` |
| Shutdown | `/prajna/shutdown` | `prajna_shutdown_test.js` | `prajna_cockpit.feature:645` |
| Knowledge | `/prajna/knowledge` | `prajna_knowledge_test.js` | `prajna_cockpit.feature:680` |
| AI | `/prajna/ai` | `prajna_ai_test.js` | `prajna_cockpit.feature:715` |

### 5.2 Operations Pages (5)

| Page | Route | Puppeteer Test | BDD Scenario |
|------|-------|----------------|--------------|
| Active Alarms | `/operations/alarms` | `ops_alarms_test.js` | `operations_dashboard.feature:24` |
| Investigation | `/operations/investigation/:id` | `ops_investigation_test.js` | `operations_dashboard.feature:104` |
| Video Wall | `/operations/video` | `ops_video_test.js` | `operations_dashboard.feature:149` |
| Access Dashboard | `/operations/access` | `ops_access_test.js` | `operations_dashboard.feature:211` |
| Dispatch Console | `/operations/dispatch` | `ops_dispatch_test.js` | `operations_dashboard.feature:279` |

### 5.3 Admin Pages (11)

| Page | Route | Puppeteer Test | BDD Scenario |
|------|-------|----------------|--------------|
| Users | `/admin/users` | `admin_users_test.js` | `admin.feature:10` |
| Roles | `/admin/roles` | `admin_roles_test.js` | `admin.feature:45` |
| Sites | `/admin/sites` | `admin_sites_test.js` | `admin.feature:80` |
| Devices | `/admin/devices` | `admin_devices_test.js` | `admin.feature:115` |
| Zones | `/admin/zones` | `admin_zones_test.js` | `admin.feature:150` |
| Subscribers | `/admin/subscribers` | `admin_subscribers_test.js` | `admin.feature:185` |
| Schedules | `/admin/schedules` | `admin_schedules_test.js` | `admin.feature:220` |
| Reports | `/admin/reports` | `admin_reports_test.js` | `admin.feature:255` |
| Settings | `/admin/settings` | `admin_settings_test.js` | `admin.feature:290` |
| Audit Log | `/admin/audit` | `admin_audit_test.js` | `admin.feature:325` |
| Integrations | `/admin/integrations` | `admin_integrations_test.js` | `admin.feature:360` |

## 6.0 CEPAF F# Module Coverage (90+ Modules)

### 6.1 Core Layer (Category Theory)

| Module | Tests | STAMP | Effects Coverage |
|--------|-------|-------|------------------|
| `CategoryTheory.fs` | `CategoryTheoryTests.fs` | SC-FSH-001 | 1-3 orders |
| `Comonads.fs` | `ComonadsTests.fs` | SC-FSH-002 | 1-4 orders |
| `Arrows.fs` | `ArrowsTests.fs` | SC-FSH-003 | 1-3 orders |
| `Effects.fs` | `EffectsTests.fs` | SC-FSH-004 | 1-5 orders |
| `FreeEffects.fs` | `FreeEffectsTests.fs` | SC-FSH-005 | 1-4 orders |
| `TaglessFinal.fs` | `TaglessFinalTests.fs` | SC-FSH-006 | 1-3 orders |
| `RecursionSchemes.fs` | `RecursionSchemesTests.fs` | SC-FSH-007 | 1-4 orders |
| `Optics.fs` | `OpticsTests.fs` | SC-FSH-008 | 1-3 orders |
| `Validation.fs` | `ValidationTests.fs` | SC-FSH-009 | 1-4 orders |
| `Capabilities.fs` | `CapabilitiesTests.fs` | SC-FSH-010 | 1-5 orders |

### 6.2 Cockpit Layer (Prajna TUI)

| Module | Tests | STAMP | Effects Coverage |
|--------|-------|-------|------------------|
| `Prajna.fs` | `PrajnaTests.fs` | SC-PRAJNA-001-007 | 1-5 orders |
| `AiCopilot.fs` | `AiCopilotTests.fs` | SC-AI-001 | 1-4 orders |
| `SentinelBridge.fs` | `SentinelBridgeTests.fs` | SC-SYNC-001-010 | 1-5 orders |
| `Material3.fs` | `Material3Tests.fs` | SC-UI-001 | 1-2 orders |
| `ThemeSystem.fs` | `ThemeSystemTests.fs` | SC-UI-002 | 1-2 orders |
| `ConcurrentCockpit.fs` | `ConcurrentCockpitTests.fs` | SC-BIO-001-007 | 1-5 orders |
| `DarkCockpitUI.fs` | `DarkCockpitUITests.fs` | SC-UI-003 | 1-2 orders |
| `C3IMultiAgent.fs` | `C3IMultiAgentTests.fs` | SC-AGT-001 | 1-5 orders |

### 6.3 Bio Layer (Holon/VSM)

| Module | Tests | STAMP | Effects Coverage |
|--------|-------|-------|------------------|
| `Holon.fs` | `HolonTests.fs` | SC-HOLON-001-020 | 1-5 orders |
| `HolonTree.fs` | `HolonTreeTests.fs` | SC-HOLON-001 | 1-4 orders |
| `HealthPropagation.fs` | `HealthPropagationTests.fs` | SC-BIO-001 | 1-5 orders |
| `Bio.Membrane` | `MembraneTests.fs` | SC-BIO-002 | 1-3 orders |
| `Bio.VitalSigns` | `VitalSignsTests.fs` | SC-BIO-003 | 1-4 orders |

### 6.4 Immune Layer (Safety)

| Module | Tests | STAMP | Effects Coverage |
|--------|-------|-------|------------------|
| `Immune.Threat` | `ThreatTests.fs` | SC-IMMUNE-001-008 | 1-5 orders |
| `Immune.Antibody` | `AntibodyTests.fs` | SC-IMMUNE-004 | 1-4 orders |
| `SimplexKernel.fs` | `SimplexKernelTests.fs` | SC-SAFE-001 | 1-5 orders |
| `SafetyConstraints.fs` | `SafetyConstraintsTests.fs` | SC-STAMP-001 | 1-3 orders |

## 7.0 External Interface Coverage

### 7.1 REST API Endpoints (250+)

Covered by: `test/indrajaal_web/controllers/api/**/*_test.exs`

| Domain | Endpoints | OpenAPI Spec | Integration Test |
|--------|-----------|--------------|------------------|
| Alarms | 35 | `priv/openapi/alarms.yaml` | `alarms_api_test.exs` |
| Devices | 40 | `priv/openapi/devices.yaml` | `devices_api_test.exs` |
| Access | 30 | `priv/openapi/access.yaml` | `access_api_test.exs` |
| Video | 25 | `priv/openapi/video.yaml` | `video_api_test.exs` |
| Analytics | 20 | `priv/openapi/analytics.yaml` | `analytics_api_test.exs` |
| Users | 18 | `priv/openapi/users.yaml` | `users_api_test.exs` |
| Sites | 15 | `priv/openapi/sites.yaml` | `sites_api_test.exs` |
| Webhooks | 12 | `priv/openapi/webhooks.yaml` | `webhooks_api_test.exs` |
| Health | 8 | `priv/openapi/health.yaml` | `health_api_test.exs` |

### 7.2 Webhooks (Outbound)

| Webhook Type | Target | Test Script | 5-Order Effects |
|--------------|--------|-------------|-----------------|
| Alarm | External ARC | `webhook_alarm_test.exs` | Full (1-5) |
| Device Status | NOC | `webhook_device_test.exs` | 1-3 orders |
| Access Event | SIEM | `webhook_access_test.exs` | 1-4 orders |
| Video Alert | SOC | `webhook_video_test.exs` | 1-4 orders |
| Compliance | Audit System | `webhook_compliance_test.exs` | Full (1-5) |

### 7.3 Zenoh Pub/Sub Topics

| Key Expression | Publisher | Subscriber | Test |
|----------------|-----------|------------|------|
| `indrajaal/v1/metrics/**` | SmartMetrics | Prajna Dashboard | `zenoh_metrics_test.exs` |
| `indrajaal/v1/alarms/**` | AlarmProcessor | Sentinel | `zenoh_alarms_test.exs` |
| `indrajaal/v1/health/**` | HealthMonitor | HolonTree | `zenoh_health_test.exs` |
| `indrajaal/v1/commands/**` | Guardian | All Agents | `zenoh_commands_test.exs` |
| `indrajaal/v1/telemetry/**` | All Modules | OTEL Collector | `zenoh_telemetry_test.exs` |

## 8.0 Cucumber + SpecFlow Integration

### 8.1 Feature File Structure

```gherkin
# test/features/{domain}/{feature}.feature
@domain @stamp-constraint @priority
Feature: {Domain} - {Capability}
  As a {actor}
  I want {goal}
  So that {benefit}

  Background:
    Given the Indrajaal system is running
    And containers are healthy
    And I am authenticated as "{role}"

  @critical @1st-order
  Scenario: {Direct action}
    Given {precondition}
    When {action}
    Then {immediate effect}
    And telemetry emits "{event}"

  @high @2nd-order
  Scenario: {Adjacent system reaction}
    Given {1st order complete}
    When {cascade trigger}
    Then {adjacent systems} should respond
    And within {time bound}

  @high @3rd-order
  Scenario: {Integration effect}
    Given {2nd order complete}
    When {integration trigger}
    Then {workflow/notification} should execute
    And dashboard should update

  @medium @4th-order
  Scenario: {Capability unlock}
    Given {3rd order complete}
    When {capability used}
    Then {new capability} should be available
    And SLA timer should start

  @low @5th-order
  Scenario: {Ecosystem effect}
    Given {4th order complete}
    When {monitoring period} elapses
    Then compliance should be logged
    And analytics should update
    And patterns should be learned
```

### 8.2 Step Definition Pattern

```elixir
# test/support/steps/{domain}_steps.ex
defmodule IndrajaalTest.Steps.{Domain}Steps do
  use IndrajaalTest.StepDefinitions

  # 1st Order Steps
  defwhen ~r/^I process alarm "(?<alarm_id>.+)"$/, %{alarm_id: id}, state do
    result = Indrajaal.Alarms.process(id)
    {:ok, Map.put(state, :alarm_result, result)}
  end

  defthen ~r/^alarm should be classified as "(?<type>.+)"$/, %{type: type}, state do
    assert state.alarm_result.type == type
    {:ok, state}
  end

  # 2nd Order Steps
  defthen ~r/^Sentinel should be notified$/, _params, state do
    assert_receive {:sentinel, :notified, _}, 5_000
    {:ok, state}
  end

  # 3rd Order Steps
  defthen ~r/^dashboard should update within (?<ms>\d+)ms$/, %{ms: ms}, state do
    assert_receive {:dashboard, :updated, _}, String.to_integer(ms)
    {:ok, state}
  end
end
```

### 8.3 SpecFlow Integration (F#)

```fsharp
// lib/cepaf/test/Cepaf.Tests/Steps/{Domain}Steps.fs
namespace Cepaf.Tests.Steps

open TechTalk.SpecFlow
open Xunit

[<Binding>]
type AlarmSteps() =
    let mutable alarmResult = None

    [<When(@"I process alarm ""(.*)""")>]
    member _.WhenProcessAlarm(alarmId: string) =
        alarmResult <- Some (Alarms.process alarmId)

    [<Then(@"alarm should be classified as ""(.*)""")>]
    member _.ThenAlarmClassified(expectedType: string) =
        match alarmResult with
        | Some result -> Assert.Equal(expectedType, result.Type)
        | None -> failwith "No alarm result"

    [<Then(@"Sentinel should be notified within (\d+)ms")>]
    member _.ThenSentinelNotified(timeout: int) =
        Async.Sleep(timeout) |> Async.RunSynchronously
        Assert.True(Sentinel.wasNotified())
```

## 9.0 Demo Script Sync Matrix

### 9.1 Enterprise Demo Scripts (55)

| Demo Script | Test Plan | Feature File | Coverage Level |
|-------------|-----------|--------------|----------------|
| `alarms_enterprise_demo.exs` | `alarm_test_plan.md` | `alarms.feature` | L1-L5 |
| `access_control_enterprise_demo.exs` | `access_test_plan.md` | `access_control.feature` | L1-L5 |
| `accounts_enterprise_demo.exs` | `accounts_test_plan.md` | `accounts.feature` | L1-L4 |
| `analytics_enterprise_demo.exs` | `analytics_test_plan.md` | `analytics.feature` | L1-L4 |
| `automation_enterprise_demo.exs` | `automation_test_plan.md` | `automation.feature` | L1-L3 |
| `backup_enterprise_demo.exs` | `backup_test_plan.md` | `backup.feature` | L1-L5 |
| `communication_enterprise_demo.exs` | `comm_test_plan.md` | `communication.feature` | L1-L5 |
| `compliance_enterprise_demo.exs` | `compliance_test_plan.md` | `compliance.feature` | L1-L5 |
| `devices_enterprise_demo.exs` | `devices_test_plan.md` | `devices.feature` | L1-L5 |
| `guard_tours_enterprise_demo.exs` | `dispatch_test_plan.md` | `dispatch.feature` | L1-L4 |
| `integration_enterprise_demo.exs` | `integration_test_plan.md` | `integration.feature` | L1-L4 |
| `mobile_enterprise_demo.exs` | `mobile_test_plan.md` | `mobile.feature` | L1-L3 |
| `reports_enterprise_demo.exs` | `reports_test_plan.md` | `reports.feature` | L1-L3 |
| `risk_management_enterprise_demo.exs` | `risk_test_plan.md` | `risk.feature` | L1-L5 |
| `sites_enterprise_demo.exs` | `sites_test_plan.md` | `sites.feature` | L1-L3 |
| `system_enterprise_demo.exs` | `system_test_plan.md` | `system.feature` | L1-L5 |
| `video_analytics_enterprise_demo.exs` | `video_test_plan.md` | `video.feature` | L1-L5 |
| `visitor_management_enterprise_demo.exs` | `visitor_test_plan.md` | `visitor.feature` | L1-L3 |
| `work_orders_enterprise_demo.exs` | `maintenance_test_plan.md` | `maintenance.feature` | L1-L3 |

### 9.2 Testing Scripts Mapping (100+)

| Testing Script | Purpose | Coverage Level | Sync Status |
|----------------|---------|----------------|-------------|
| `stamp_tdg_gde_methodology_validator.exs` | STAMP/TDG/GDE validation | L1-L3 | SYNCED |
| `comprehensive_test_coverage_framework.exs` | 11-agent coverage | L1-L5 | SYNCED |
| `container_health_validator.exs` | Container validation | L1-L2 | SYNCED |
| `ace_verification_engine.exs` | ACE verification | L1-L4 | SYNCED |
| `tdg_compliance_framework.exs` | TDG compliance | L1 | SYNCED |
| `stamp_gde_validation_framework.exs` | STAMP/GDE | L1-L3 | SYNCED |
| `behavioral_verification_system.exs` | BDD integration | L5 | SYNCED |
| `functional_correctness_validator.exs` | Correctness | L1-L4 | SYNCED |
| `comprehensive_release_pipeline.exs` | Release | L1-L5 | SYNCED |
| `disaster_recovery_rollback_testing.exs` | DR testing | L1-L5 | SYNCED |

## 10.0 FMEA Test Mapping

### 10.1 Critical Path FMEA (RPN > 100)

| Component | Failure Mode | S | O | D | RPN | Test | Mitigation |
|-----------|--------------|---|---|---|-----|------|------------|
| Guardian | Bypass possible | 10 | 3 | 4 | 120 | `guardian_bypass_test.exs` | Multi-layer validation |
| Sentinel | False negative | 9 | 4 | 3 | 108 | `sentinel_detection_test.exs` | Dual detection paths |
| ImmutableState | Chain corruption | 10 | 2 | 5 | 100 | `chain_integrity_test.exs` | Reed-Solomon encoding |
| AlarmProcessor | Message loss | 9 | 3 | 4 | 108 | `alarm_durability_test.exs` | Ack-based delivery |
| Authentication | Credential leak | 10 | 2 | 5 | 100 | `auth_security_test.exs` | Vault integration |

### 10.2 High Risk FMEA (RPN 50-100)

| Component | Failure Mode | S | O | D | RPN | Test |
|-----------|--------------|---|---|---|-----|------|
| ZenohBridge | Message delay | 7 | 5 | 3 | 105 | `zenoh_latency_test.exs` |
| SmartMetrics | Stale data | 6 | 4 | 4 | 96 | `metrics_freshness_test.exs` |
| AiCopilot | Misalignment | 8 | 3 | 4 | 96 | `copilot_alignment_test.exs` |
| CircuitBreaker | Stuck open | 7 | 4 | 3 | 84 | `circuit_breaker_test.exs` |
| BackoffRetry | Infinite loop | 6 | 3 | 4 | 72 | `backoff_test.exs` |

## 11.0 Formal Verification Files

### 11.1 AGDA Proofs

```
docs/formal_specs/
├── guardian_invariants.agda       # Guardian bypass impossibility
├── register_chain.agda            # Hash chain integrity
├── holon_transitions.agda         # State machine correctness
├── capability_tokens.agda         # Unforgeable tokens
└── constitutional_invariants.agda # Ψ₀-Ψ₅ inviolability
```

### 11.2 Quint Temporal Models

```
docs/formal_specs/
├── alarm_lifecycle.qnt           # Alarm state machine
├── sentinel_detection.qnt        # Threat detection timing
├── ooda_cycle.qnt               # OODA timing guarantees
├── circuit_breaker.qnt          # CB state transitions
└── federation_consensus.qnt     # Cross-holon agreement
```

### 11.3 Mathematica Symbolic Verification

```
docs/formal_specs/
├── holon_health_propagation.nb   # Health score propagation
├── rpn_calculation.nb            # FMEA RPN formulas
├── resource_allocation.nb        # Agent scaling math
├── sla_compliance.nb             # SLA timing analysis
└── cascade_effects.nb            # 1-5 order effect modeling
```

## 12.0 Graph-Based Path Analysis

### 12.1 Control Flow Coverage

| Module | Paths | Covered | Coverage % | Test File |
|--------|-------|---------|------------|-----------|
| AlarmProcessor | 48 | 48 | 100% | `alarm_processor_path_test.exs` |
| GuardianIntegration | 24 | 24 | 100% | `guardian_path_test.exs` |
| SentinelBridge | 32 | 32 | 100% | `sentinel_path_test.exs` |
| ImmutableState | 18 | 18 | 100% | `immutable_state_path_test.exs` |
| SmartMetrics | 42 | 42 | 100% | `smart_metrics_path_test.exs` |

### 12.2 Data Flow Coverage

| Data Object | Source | Sinks | Flow Test |
|-------------|--------|-------|-----------|
| Alarm | API → Processor | Dashboard, DB, Webhook | `alarm_data_flow_test.exs` |
| HealthScore | Holon → Propagation | Prajna, Sentinel | `health_flow_test.exs` |
| Command | Prajna → Guardian | Agent, Register | `command_flow_test.exs` |
| Telemetry | All → Bus | OTEL, Zenoh | `telemetry_flow_test.exs` |

### 12.3 FSM State Coverage

| State Machine | States | Transitions | Coverage | Test |
|---------------|--------|-------------|----------|------|
| Holon Lifecycle | 6 | 12 | 100% | `holon_fsm_test.exs` |
| Alarm Lifecycle | 8 | 18 | 100% | `alarm_fsm_test.exs` |
| Circuit Breaker | 3 | 6 | 100% | `cb_fsm_test.exs` |
| Guardian Proposal | 5 | 10 | 100% | `guardian_fsm_test.exs` |
| Threat Response | 6 | 15 | 100% | `threat_fsm_test.exs` |

## 13.0 Telemetry Events Specification

### 13.1 Required Events per Order

```elixir
# 1st Order Events (Immediate)
:telemetry.execute([:indrajaal, :cmd, :start], %{}, %{cmd: cmd})
:telemetry.execute([:indrajaal, :cmd, :complete], %{duration_us: dur}, %{})

# 2nd Order Events (Adjacent)
:telemetry.execute([:indrajaal, :cascade, :adjacent], %{systems: []}, %{})

# 3rd Order Events (Integration)
:telemetry.execute([:indrajaal, :cascade, :integration], %{}, %{})

# 4th Order Events (Capability)
:telemetry.execute([:indrajaal, :cascade, :capability], %{}, %{})

# 5th Order Events (Ecosystem)
:telemetry.execute([:indrajaal, :cascade, :ecosystem], %{}, %{})
```

## 14.0 Execution Commands

### 14.1 Run All 5 Levels

```bash
# Level 1: TDG
SKIP_ZENOH_NIF=0 mix test --cover

# Level 2: FMEA
SKIP_ZENOH_NIF=0 mix test --only fmea

# Level 3: Formal
agda --safe docs/formal_specs/*.agda
quint run docs/formal_specs/*.qnt

# Level 4: Graph
mix coveralls.detail

# Level 5: BDD
SKIP_ZENOH_NIF=0 mix test.features

# All Levels
./scripts/testing/run_five_level_tests.sh
```

### 14.2 Puppeteer Tests

```bash
# Install dependencies
cd test/puppeteer && npm install

# Run all page tests
npm run test:all

# Run specific page
npm run test:prajna
npm run test:operations
npm run test:admin

# Generate screenshots
npm run screenshots
```

## 15.0 Compliance Matrix

| Requirement | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 |
|-------------|---------|---------|---------|---------|---------|
| SC-COV-001 (Static 100%) | TDG | - | - | Graph | - |
| SC-COV-002 (Runtime 95%) | TDG | FMEA | - | - | BDD |
| SC-COV-003 (Proofs) | - | - | AGDA/Quint | - | - |
| SC-COV-004 (BDD) | - | - | - | - | Cucumber |
| SC-COV-005 (FMEA RPN>50) | - | FMEA | - | - | - |
| SC-COV-006 (TDG) | TDG | - | - | - | - |
| SC-COV-007 (All Pass) | ALL | ALL | ALL | ALL | ALL |
| SC-COV-008 (Puppeteer) | - | - | - | - | Puppeteer |

---

**Document Control**
- **Author**: Cybernetic Architect
- **Review**: STAMP-TDG-GDE Validation Framework
- **Approval**: Guardian + Executive Agent
