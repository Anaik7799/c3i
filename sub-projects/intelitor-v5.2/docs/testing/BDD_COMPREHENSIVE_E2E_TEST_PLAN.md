# BDD Comprehensive End-to-End Test Plan

**Version**: 1.0.0
**Date**: 2026-01-10
**Status**: ACTIVE
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR, EN 50131, EN 50518

---

## Executive Summary

This document defines the comprehensive BDD (Behavior-Driven Development) test plan for the Indrajaal SIL-6 Biomorphic Fractal Mesh system. It covers 100% end-to-end testing of:

- **F# TUI GUI and Cockpit** (447 F# modules)
- **Web UI Cockpit** (22 Prajna LiveView pages)
- **Prajna C3I Command Center** (Full operational coverage)
- **Elixir WebUI** (1,161 modules across 30 domains)
- **Full Demo Use Cases** (20 comprehensive E2E scenarios)

---

## 1. Test Architecture Overview

### 1.1 BDD Framework Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Feature Files | Gherkin | Human-readable specifications |
| Step Definitions | Elixir/F# | Executable test logic |
| Browser Automation | Wallaby + Chrome (NixOS) | LiveView E2E interaction |
| API Testing | HTTPoison | REST endpoint validation |
| Terminal Testing | ExPect | TUI interaction |
| Load Testing | k6/Locust | Performance validation |

### 1.2 Test Categories

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BDD TEST HIERARCHY                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Level 5: E2E DEMO SCENARIOS (20 scenarios)                                 │
│    └── Complete user journeys across all systems                            │
│                                                                              │
│  Level 4: OPERATIONAL SCENARIOS (50 scenarios)                              │
│    └── Day-to-day operations, maintenance, troubleshooting                  │
│                                                                              │
│  Level 3: INTEGRATION TESTS (100 scenarios)                                 │
│    └── Cross-component interactions, data flows                             │
│                                                                              │
│  Level 2: PAGE/MODULE TESTS (300 scenarios)                                 │
│    └── Individual UI pages and domain modules                               │
│                                                                              │
│  Level 1: UNIT BDD TESTS (500 scenarios)                                    │
│    └── Component-level behavior validation                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. F# TUI GUI and Cockpit Test Plan

### 2.1 Module Coverage Matrix

| F# Module Category | Modules | Feature File | Scenarios |
|-------------------|---------|--------------|-----------|
| Panopticon TUI | 15 | cepaf/panopticon_tui.feature | 45 |
| Dark Cockpit UI | 12 | cepaf/dark_cockpit_ui.feature | 38 |
| SIL6 Mesh CLI | 18 | cepaf/mesh_cli.feature | 52 |
| Health Coordinator | 8 | cepaf/health_coordinator.feature | 24 |
| Apoptosis Protocol | 6 | cepaf/apoptosis.feature | 18 |
| Digital Twin | 10 | cepaf/digital_twin.feature | 30 |
| Federation Protocol | 14 | cepaf/federation.feature | 42 |
| CEPAF Bridge | 20 | cepaf/bridge.feature | 60 |
| Cortex AI | 25 | cepaf/cortex.feature | 75 |
| **Total** | **128** | **9 files** | **384** |

### 2.2 TUI Interaction Test Matrix

| Test Category | Test Type | Count | Priority |
|--------------|-----------|-------|----------|
| Keyboard Navigation | Functional | 25 | P0 |
| Screen Rendering | Visual | 40 | P0 |
| Color/ANSI Codes | Visual | 30 | P1 |
| Data Display | Functional | 50 | P0 |
| Real-time Updates | Performance | 20 | P0 |
| Error Handling | Resilience | 35 | P1 |
| Terminal Compatibility | Compatibility | 15 | P2 |
| **Total** | | **215** | |

### 2.3 Panopticon Directed Telescope Scenarios

```gherkin
# Comprehensive Panopticon Coverage

Feature: Panopticon Directed Telescope - Complete Coverage

  # L5 EVOLUTIONARY LAYER (8 scenarios)
  Scenario: L5 displays SRS compliance status
  Scenario: L5 shows fitness metrics
  Scenario: L5 tracks evolutionary lineage
  Scenario: L5 displays mutation history
  Scenario: L5 shows adaptation rate
  Scenario: L5 monitors genome health
  Scenario: L5 validates constitutional compliance
  Scenario: L5 tracks Founder's Directive alignment

  # L4 COGNITIVE LAYER (8 scenarios)
  Scenario: L4 displays STPA hazard analysis
  Scenario: L4 shows feedback loop status
  Scenario: L4 monitors control actions
  Scenario: L4 tracks unsafe control actions
  Scenario: L4 displays loss scenarios
  Scenario: L4 shows control structure
  Scenario: L4 monitors feedback delays
  Scenario: L4 validates safety constraints

  # L3 ORGAN LAYER (8 scenarios)
  Scenario: L3 displays Istio mirroring status
  Scenario: L3 shows payload comparison results
  Scenario: L3 monitors service mesh health
  Scenario: L3 tracks traffic distribution
  Scenario: L3 displays canary deployment status
  Scenario: L3 shows A/B test results
  Scenario: L3 monitors circuit breakers
  Scenario: L3 validates data consistency

  # L2 TISSUE LAYER (8 scenarios)
  Scenario: L2 displays Podman isolation status
  Scenario: L2 shows container health
  Scenario: L2 monitors resource limits
  Scenario: L2 tracks namespace isolation
  Scenario: L2 displays network policies
  Scenario: L2 shows volume mounts
  Scenario: L2 monitors security contexts
  Scenario: L2 validates cgroup constraints

  # L1 CELLULAR LAYER (8 scenarios)
  Scenario: L1 displays BEAM process status
  Scenario: L1 shows memory proof results
  Scenario: L1 monitors scheduler utilization
  Scenario: L1 tracks message queue depths
  Scenario: L1 displays process count
  Scenario: L1 shows atom table usage
  Scenario: L1 monitors binary memory
  Scenario: L1 validates process isolation
```

### 2.4 2oo3 Voting System Test Matrix

| Test Scenario | Input | Expected Output | Priority |
|--------------|-------|-----------------|----------|
| All nodes agree | P=A, S=A, M=A | CONSENSUS: MATCH | P0 |
| Primary disagrees | P=B, S=A, M=A | CONSENSUS: A (2oo3) | P0 |
| Shadow disagrees | P=A, S=B, M=A | CONSENSUS: A (2oo3) | P0 |
| Model disagrees | P=A, S=A, M=B | CONSENSUS: A (2oo3) | P0 |
| Two nodes disagree | P=B, S=B, M=A | NO CONSENSUS | P0 |
| All disagree | P=A, S=B, M=C | BYZANTINE FAULT | P0 |
| Primary offline | P=-, S=A, M=A | CONSENSUS: A (fail-safe) | P0 |
| Shadow offline | P=A, S=-, M=A | CONSENSUS: A (fail-safe) | P0 |
| Model offline | P=A, S=A, M=- | CONSENSUS: A (degraded) | P0 |
| Latency variance | P(2ms), S(50ms), M(3ms) | WARN: Shadow slow | P1 |

---

## 3. Web UI Cockpit Test Plan

### 3.1 Page Coverage Matrix

| Page | Path | Elements | Interactions | Scenarios |
|------|------|----------|--------------|-----------|
| Dashboard | /prajna | 15 | 8 | 25 |
| Alarms | /prajna/alarms | 12 | 15 | 35 |
| Devices | /prajna/devices | 10 | 12 | 28 |
| Access Control | /prajna/access_control | 8 | 10 | 22 |
| Video | /prajna/video | 14 | 8 | 30 |
| Analytics | /prajna/analytics | 11 | 12 | 28 |
| Compliance | /prajna/compliance | 9 | 8 | 22 |
| Cluster | /prajna/cluster | 8 | 6 | 18 |
| AI Copilot | /prajna/copilot | 7 | 10 | 25 |
| Containers | /prajna/containers | 12 | 10 | 28 |
| Guardian | /prajna/guardian | 10 | 12 | 30 |
| Sentinel | /prajna/sentinel | 11 | 8 | 25 |
| Register | /prajna/register | 8 | 6 | 18 |
| Commands | /prajna/commands | 15 | 20 | 40 |
| Diagnostics | /prajna/diagnostics | 12 | 5 | 20 |
| Observability | /prajna/observability | 10 | 8 | 22 |
| Mesh | /prajna/mesh | 9 | 6 | 18 |
| Settings | /prajna/settings | 14 | 15 | 35 |
| Startup | /prajna/startup | 6 | 4 | 12 |
| Shutdown | /prajna/shutdown | 5 | 6 | 15 |
| Knowledge Dev | /prajna/knowledge/developer | 8 | 5 | 15 |
| Knowledge SRE | /prajna/knowledge/sre | 8 | 5 | 15 |
| **TOTAL** | **22 pages** | **212** | **199** | **546** |

### 3.2 LiveView Real-time Test Matrix

| Test Category | Scenarios | Priority | Coverage |
|--------------|-----------|----------|----------|
| WebSocket Connection | 15 | P0 | 100% |
| Server Push Updates | 25 | P0 | 100% |
| Client Events | 30 | P0 | 100% |
| Form Validation | 40 | P0 | 100% |
| Flash Messages | 10 | P1 | 100% |
| Navigation | 20 | P0 | 100% |
| Modal Dialogs | 25 | P1 | 100% |
| Error Recovery | 20 | P0 | 100% |
| **Total** | **185** | | |

### 3.3 Puppeteer Screenshot Matrix

| Screenshot | Trigger | Resolution | Format |
|------------|---------|------------|--------|
| prajna_dashboard.png | Page load | 1920x1080 | PNG |
| prajna_dashboard_mobile.png | Page load | 375x667 | PNG |
| prajna_alarms_list.png | Alarm list | 1920x1080 | PNG |
| prajna_alarm_storm.png | Storm detected | 1920x1080 | PNG |
| prajna_alarm_detail.png | Modal open | 1920x1080 | PNG |
| prajna_devices_grid.png | Grid view | 1920x1080 | PNG |
| prajna_device_health.png | Health matrix | 1920x1080 | PNG |
| prajna_video_grid.png | Video wall | 1920x1080 | PNG |
| prajna_video_detection.png | AI detection | 1920x1080 | PNG |
| prajna_copilot_chat.png | Chat active | 1920x1080 | PNG |
| prajna_guardian_proposal.png | Proposal view | 1920x1080 | PNG |
| prajna_sentinel_threats.png | Threat list | 1920x1080 | PNG |
| prajna_register_chain.png | Blockchain | 1920x1080 | PNG |
| prajna_containers_status.png | Container grid | 1920x1080 | PNG |
| prajna_cluster_topology.png | Topology graph | 1920x1080 | PNG |
| prajna_shutdown_confirm.png | Confirmation | 1920x1080 | PNG |
| prajna_error_500.png | Error page | 1920x1080 | PNG |
| prajna_disconnected.png | WebSocket lost | 1920x1080 | PNG |

---

## 4. Prajna C3I Command Center Test Plan

### 4.1 Command Categories

| Category | Commands | Scenarios | Priority |
|----------|----------|-----------|----------|
| Monitoring | 15 | 45 | P0 |
| Control | 25 | 75 | P0 |
| Safety | 12 | 36 | P0 |
| Diagnostics | 18 | 54 | P1 |
| Configuration | 20 | 60 | P1 |
| Reporting | 10 | 30 | P2 |
| **Total** | **100** | **300** | |

### 4.2 Guardian Integration Test Matrix

| Test Scenario | Command Type | Expected Behavior | Scenarios |
|--------------|--------------|-------------------|-----------|
| Approve safe command | Read-only | Immediate approval | 20 |
| Review moderate command | Write | Guardian review | 25 |
| Block dangerous command | Destructive | Guardian veto | 15 |
| Two-step commit | Critical | Token confirmation | 20 |
| Emergency override | Emergency | Audit log + execute | 10 |
| Founder directive check | Strategic | Alignment validation | 15 |
| Constitutional check | Core change | Invariant verification | 12 |
| **Total** | | | **117** |

### 4.3 Sentinel Integration Scenarios

| Test Category | Scenarios | Description |
|--------------|-----------|-------------|
| Health Monitoring | 15 | Continuous health assessment |
| Threat Detection | 20 | Pattern-based threat identification |
| Quarantine | 12 | Component isolation |
| Auto-healing | 18 | Self-repair mechanisms |
| Chaos Engineering | 10 | Mara fault injection |
| Antibody Generation | 8 | Novel threat response |
| **Total** | **83** | |

---

## 5. Elixir WebUI Test Plan (30 Domains)

### 5.1 Domain Coverage Matrix

| Domain | Modules | Resources | Actions | Scenarios |
|--------|---------|-----------|---------|-----------|
| access_control | 15 | 5 | 12 | 35 |
| accounts | 12 | 4 | 10 | 28 |
| alarms | 45 | 8 | 25 | 78 |
| analytics | 22 | 6 | 15 | 43 |
| authentication | 18 | 3 | 8 | 29 |
| authorization | 14 | 4 | 10 | 28 |
| billing | 25 | 7 | 18 | 50 |
| cluster | 30 | 5 | 12 | 47 |
| cockpit | 38 | 10 | 30 | 78 |
| communication | 20 | 6 | 14 | 40 |
| compliance | 28 | 8 | 20 | 56 |
| coordination | 16 | 4 | 10 | 30 |
| cortex | 35 | 8 | 22 | 65 |
| cybernetic | 42 | 10 | 25 | 77 |
| devices | 50 | 12 | 30 | 92 |
| dispatch | 32 | 8 | 20 | 60 |
| distributed | 24 | 5 | 12 | 41 |
| flame | 8 | 2 | 5 | 15 |
| identity | 20 | 5 | 12 | 37 |
| integration | 55 | 15 | 35 | 105 |
| knowledge | 15 | 4 | 10 | 29 |
| maintenance | 18 | 5 | 12 | 35 |
| mesh | 25 | 6 | 15 | 46 |
| observability | 30 | 8 | 20 | 58 |
| policy | 22 | 6 | 14 | 42 |
| safety | 40 | 10 | 25 | 75 |
| security | 35 | 8 | 20 | 63 |
| sites | 28 | 7 | 18 | 53 |
| validation | 25 | 6 | 15 | 46 |
| video | 38 | 10 | 25 | 73 |
| **TOTAL** | **1161** | **201** | **519** | **1,694** |

### 5.2 Ash Resource Test Matrix

| Test Category | Scenarios | Priority |
|--------------|-----------|----------|
| CRUD Operations | 200 | P0 |
| Validations | 150 | P0 |
| Calculations | 80 | P1 |
| Aggregates | 60 | P1 |
| Relationships | 120 | P0 |
| Policies | 100 | P0 |
| Actions | 180 | P0 |
| **Total** | **890** | |

---

## 6. Full Demo Use Case Test Plan

### 6.1 E2E Demo Scenario Matrix

| Demo # | Name | Duration | Components | Priority |
|--------|------|----------|------------|----------|
| 1 | Complete Alarm Lifecycle | 10 min | Alarms, Dispatch, Sites | P0 |
| 2 | HA Failover Zero Downtime | 5 min | HAProxy, Apps, Zenoh | P0 |
| 3 | Zenoh Mesh Resilience | 5 min | Zenoh routers x3 | P0 |
| 4 | Prajna C3I Cockpit Tour | 15 min | All 22 pages | P0 |
| 5 | F# Cockpit CLI Operations | 5 min | CEPAF CLI | P0 |
| 6 | Panopticon TUI Demo | 5 min | F# TUI | P0 |
| 7 | Guardian Approval Workflow | 5 min | Guardian, Register | P0 |
| 8 | Immutable Register Demo | 5 min | Blockchain, Signing | P0 |
| 9 | Holon State Sovereignty | 5 min | SQLite, DuckDB | P0 |
| 10 | Unified Checkpoint Registry | 10 min | 4-phase checkpoint | P0 |
| 11 | Digital Immune System | 10 min | Sentinel, Mara | P0 |
| 12 | Full OODA Cycle | 5 min | CAE system | P0 |
| 13 | Founder's Directive Alignment | 5 min | Ω₀ validation | P0 |
| 14 | Apoptosis Shutdown | 5 min | 6-phase protocol | P0 |
| 15 | Performance Load Test | 10 min | 1000 RPS | P1 |
| 16 | Security Compliance | 10 min | OWASP, ISO 27001 | P1 |
| 17 | Disaster Recovery | 15 min | Full restore | P1 |
| 18 | API Endpoint Tour | 10 min | All REST APIs | P1 |
| 19 | Observability Integration | 10 min | OTEL, Grafana | P1 |
| 20 | GA Readiness Verification | 30 min | All gates | P0 |

### 6.2 Demo Scenario Detail: Complete Alarm Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEMO 1: COMPLETE ALARM LIFECYCLE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1: SETUP (30 seconds)                                                 │
│  ├─ Configure test site "DEMO-SITE-001"                                      │
│  ├─ Set keyholders (3)                                                       │
│  ├─ Configure zones (10)                                                     │
│  └─ Set response SLA (60 seconds)                                           │
│                                                                              │
│  PHASE 2: ALARM RECEPTION (5 seconds)                                        │
│  ├─ SIA DC-09 message received                         │ T+0ms             │
│  ├─ Message parsed and validated                       │ T+50ms            │
│  ├─ Alarm classified (INTRUSION, HIGH)                 │ T+100ms           │
│  ├─ Record created in database                         │ T+150ms           │
│  ├─ Published to Zenoh mesh                            │ T+200ms           │
│  └─ Dashboard updated                                  │ T+1000ms          │
│                                                                              │
│  PHASE 3: OPERATOR ACKNOWLEDGMENT (30 seconds)                               │
│  ├─ Alarm appears in operator queue                                          │
│  ├─ Operator clicks "Acknowledge"                                            │
│  ├─ Guardian approval requested                                              │
│  ├─ Guardian approves                                                        │
│  ├─ Status changes to ACKNOWLEDGED                                           │
│  └─ Audit record created                                                     │
│                                                                              │
│  PHASE 4: DISPATCH (60 seconds)                                              │
│  ├─ Operator initiates dispatch                                              │
│  ├─ Available patrol units queried                                           │
│  ├─ Nearest unit selected (PATROL-01)                                        │
│  ├─ Dispatch record created                                                  │
│  ├─ Unit notified via mobile app                                             │
│  └─ Tracking begins                                                          │
│                                                                              │
│  PHASE 5: RESPONSE (5-10 minutes)                                            │
│  ├─ Unit acknowledges dispatch                                               │
│  ├─ En route status                                                          │
│  ├─ GPS tracking updates                                                     │
│  ├─ Arrival logged                                                           │
│  ├─ Investigation begins                                                     │
│  └─ Evidence collection                                                      │
│                                                                              │
│  PHASE 6: RESOLUTION (30 seconds)                                            │
│  ├─ Unit submits resolution                                                  │
│  ├─ Resolution code: FA-01 (False Alarm)                                     │
│  ├─ Alarm marked RESOLVED                                                    │
│  ├─ Timeline completed                                                       │
│  ├─ SLA compliance calculated (MET)                                          │
│  └─ Billing record generated                                                 │
│                                                                              │
│  VERIFICATION CHECKPOINTS                                                    │
│  ├─ [ ] Alarm visible in dashboard within 1 second                           │
│  ├─ [ ] Guardian audit trail complete                                        │
│  ├─ [ ] Immutable Register records all state changes                         │
│  ├─ [ ] Zenoh mesh distributed notifications                                 │
│  ├─ [ ] Compliance evidence collected                                        │
│  └─ [ ] Full timeline accessible in analytics                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Operational Scenarios Test Plan

### 7.1 Day-to-Day Operations

| Category | Scenarios | Description |
|----------|-----------|-------------|
| Shift Handover | 8 | Operator shift changes |
| System Health Check | 12 | Morning health verification |
| Alarm Management | 25 | Routine alarm handling |
| Device Maintenance | 15 | Device operations |
| Report Generation | 10 | Daily/weekly reports |
| User Management | 12 | Account operations |
| **Total** | **82** | |

### 7.2 Maintenance Operations

| Category | Scenarios | Description |
|----------|-----------|-------------|
| Scheduled Maintenance | 10 | Planned downtime |
| Rolling Updates | 8 | Zero-downtime deployments |
| Database Maintenance | 12 | Backup, vacuum, reindex |
| Certificate Renewal | 6 | TLS certificate rotation |
| Log Rotation | 5 | Log management |
| Performance Tuning | 10 | Optimization tasks |
| **Total** | **51** | |

### 7.3 Troubleshooting Operations

| Category | Scenarios | Description |
|----------|-----------|-------------|
| Connection Issues | 15 | Network troubleshooting |
| Performance Issues | 12 | Slowdown investigation |
| Error Investigation | 18 | Error root cause |
| Device Issues | 10 | Device troubleshooting |
| Integration Issues | 15 | Third-party problems |
| Data Issues | 8 | Data integrity problems |
| **Total** | **78** | |

### 7.4 Emergency Operations

| Category | Scenarios | Description |
|----------|-----------|-------------|
| System Outage | 10 | Complete outage response |
| Security Incident | 12 | Breach response |
| Data Loss | 8 | Recovery procedures |
| Performance Crisis | 6 | Emergency scaling |
| Communication Failure | 5 | Backup communication |
| **Total** | **41** | |

---

## 8. Coverage Summary

### 8.1 Total Scenario Count

| Component | Scenarios | Lines | Priority |
|-----------|-----------|-------|----------|
| F# TUI/Cockpit | 384 | 3,500 | P0-P2 |
| Web UI Cockpit | 546 | 5,000 | P0-P2 |
| Prajna C3I | 500 | 4,500 | P0-P2 |
| Elixir WebUI (30 domains) | 1,694 | 15,000 | P0-P2 |
| Demo Scenarios | 200 | 2,000 | P0-P1 |
| Operational Scenarios | 252 | 2,500 | P0-P2 |
| **TOTAL** | **3,576** | **32,500** | |

### 8.2 Coverage by Priority

| Priority | Scenarios | Percentage |
|----------|-----------|------------|
| P0 (Critical) | 1,856 | 52% |
| P1 (High) | 1,145 | 32% |
| P2 (Medium) | 575 | 16% |
| **Total** | **3,576** | **100%** |

### 8.3 Feature File Inventory

| Directory | Files | Scenarios |
|-----------|-------|-----------|
| test/features/cepaf/ | 10 | 384 |
| test/features/prajna/ | 8 | 420 |
| test/features/web/ | 6 | 320 |
| test/features/elixir/ | 30 | 900 |
| test/features/demo/ | 5 | 200 |
| test/features/operations/ | 8 | 252 |
| test/features/ha_mesh/ | 6 | 180 |
| test/features/integration/ | 10 | 450 |
| test/features/security/ | 5 | 150 |
| test/features/performance/ | 4 | 120 |
| test/features/compliance/ | 4 | 200 |
| **TOTAL** | **96** | **3,576** |

---

## 9. STAMP Constraints Coverage

### 9.1 Constraint to Scenario Mapping

| Constraint ID | Description | Scenarios |
|--------------|-------------|-----------|
| SC-PRAJNA-001 | Guardian pre-approval | 117 |
| SC-PRAJNA-002 | Founder's Directive validation | 45 |
| SC-PRAJNA-003 | Immutable Register logging | 80 |
| SC-PRAJNA-004 | Sentinel health integration | 83 |
| SC-PRAJNA-005 | PROMETHEUS proof-token | 25 |
| SC-PRAJNA-006 | Constitutional invariants | 30 |
| SC-PRAJNA-007 | Two-step commit | 40 |
| SC-SIL6-001 | PFH < 10⁻¹² | 15 |
| SC-SIL6-004 | Neural-immune response | 50 |
| SC-HMI-001 | Dark Cockpit | 38 |
| SC-HMI-002 | Trend vectors | 25 |
| SC-HMI-003 | Staleness decay | 20 |
| SC-HMI-004 | Two-step commit UI | 35 |
| SC-BIO-001 | OODA < 100ms | 40 |
| SC-BIO-005 | Dashboard refresh 30s | 30 |
| SC-BIO-007 | Graceful degradation | 45 |
| SC-HOLON-001 | SQLite/DuckDB sovereignty | 60 |
| SC-REG-001 | Append-only register | 50 |
| SC-REG-002 | Unbroken hash chain | 30 |
| SC-GA-001 | All commands documented | 100 |

---

## 10. Execution Plan

### 10.1 Test Execution Phases

| Phase | Duration | Scenarios | Focus |
|-------|----------|-----------|-------|
| 1. Smoke | 15 min | 50 | Critical paths |
| 2. Sanity | 1 hour | 200 | Core functionality |
| 3. Regression | 4 hours | 1,000 | Full regression |
| 4. E2E | 2 hours | 200 | Demo scenarios |
| 5. Performance | 2 hours | 120 | Load testing |
| 6. Security | 1 hour | 150 | Security validation |
| **Total** | **10.5 hours** | **1,720** | |

### 10.2 Automation Schedule

| Time | Trigger | Suite | Duration |
|------|---------|-------|----------|
| On commit | Git push | Smoke | 15 min |
| On PR | PR creation | Sanity | 1 hour |
| Nightly | 2:00 AM | Full regression | 4 hours |
| Weekly | Sunday 1:00 AM | E2E + Security | 3 hours |
| On release | Tag creation | Complete | 10 hours |

---

## 11. Appendix

### 11.1 Feature File Template

```gherkin
# Feature: [Feature Name]
# STAMP: [Constraint IDs]
# AOR: [Rule IDs]
# Author: [Author Name]
# Date: [Date]
# Purpose: [Brief description]

@tag1 @tag2 @priority
Feature: [Feature Name]
  As a [role]
  I want [goal]
  So that [benefit]

  Background:
    Given [common preconditions]

  @P0 @smoke
  Scenario: [Scenario name]
    Given [precondition]
    When [action]
    Then [expected result]
    And [additional verification]

  @P1 @regression
  Scenario Outline: [Parameterized scenario]
    Given <precondition>
    When <action>
    Then <result>

    Examples:
      | precondition | action | result |
      | value1       | value2 | value3 |
```

### 11.2 Step Definition Pattern

```elixir
defmodule Indrajaal.Test.Steps.[DomainName]Steps do
  @moduledoc """
  Step definitions for [Domain] BDD tests
  """

  use ExUnit.Case
  import Wallaby.Browser

  # Given steps
  def given_precondition(context, param) do
    {:ok, context}
  end

  # When steps
  def when_action(context, param) do
    {:ok, context}
  end

  # Then steps
  def then_verification(context, expected) do
    {:ok, context}
  end
end
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-10 | Cybernetic Architect | Initial version |

---

**Approved By**: _________________________
**Date**: _________________________
**Signature**: _________________________
