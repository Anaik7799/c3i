# CockpitF CLI Fractal Test Plan
**Version**: 1.0.0
**Date**: 2026-01-05
**Compliance**: SC-CLI-001 through SC-CLI-008, SC-AI-001 through SC-AI-004
**Status**: COMPREHENSIVE TEST SPECIFICATION

---

## Executive Summary

This test plan ensures cockpitf CLI meets **ALL criteria** for:
- **UI (User Interface)** - Visual quality, formatting, color schemes
- **UX (User Experience)** - Intuitive commands, discoverability, help
- **CX (Customer Experience)** - Reliability, speed, satisfaction
- **DX (Developer Experience)** - Scriptability, extensibility, debugging
- **AI Intelligence** - OpenRouter integration for smart responses

**Total Tests**: 101 tests across 7 fractal levels and 4 quality dimensions

---

## 1.0 Fractal Level Architecture

### 1.1 The 7 Levels

```
┌─────────────────────────────────────────────────────────────────────┐
│  L1: ECOSYSTEM        - CLI in overall system context               │
│      └─ Tests: System boot, container connectivity, telemetry       │
├─────────────────────────────────────────────────────────────────────┤
│  L2: FEDERATION       - Multi-holon CLI coordination               │
│      └─ Tests: Peer discovery, state sync, announcements           │
├─────────────────────────────────────────────────────────────────────┤
│  L3: CLUSTER          - Distributed Elixir CLI operations          │
│      └─ Tests: Node management, quorum, distributed state          │
├─────────────────────────────────────────────────────────────────────┤
│  L4: DOMAIN           - 30 domain command coverage                  │
│      └─ Tests: Each domain has list/status/metrics/circuit         │
├─────────────────────────────────────────────────────────────────────┤
│  L5: MODULE           - Individual command testing                  │
│      └─ Tests: 69 commands across 11 categories                    │
├─────────────────────────────────────────────────────────────────────┤
│  L6: FUNCTION         - Command argument handling                   │
│      └─ Tests: Positional args, flags, defaults, validation        │
├─────────────────────────────────────────────────────────────────────┤
│  L7: CODE             - Implementation details, edge cases          │
│      └─ Tests: Timeouts, retries, Unicode, pagination              │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Level Test Distribution

| Level | Name | Tests | Focus |
|-------|------|-------|-------|
| L1 | Ecosystem | 5 | System-wide availability |
| L2 | Federation | 5 | Cross-holon operations |
| L3 | Cluster | 5 | Distributed BEAM nodes |
| L4 | Domain | 36 | 30 domains + coverage tests |
| L5 | Command | 5 | 69 commands verification |
| L6 | Function | 6 | Argument parsing |
| L7 | Code | 7 | Implementation edge cases |
| **Total** | | **69** | Fractal coverage |

---

## 2.0 Quality Dimension Tests

### 2.1 UI (User Interface) Criteria - 8 Tests

| Test ID | Criterion | Description |
|---------|-----------|-------------|
| UI.1 | Color Scheme | Consistent semantic colors (success=green, error=red) |
| UI.2 | Table Alignment | Column headers and data properly aligned |
| UI.3 | Progress Indicators | Spinners for operations > 2s |
| UI.4 | Error Visibility | Errors visually distinct with red formatting |
| UI.5 | Status Icons | Intuitive icons (✓, ✗, ●, ○, ◐) |
| UI.6 | Terminal Width | Output respects terminal size |
| UI.7 | Color Disable | --no-color flag for accessibility |
| UI.8 | Dark Cockpit | Minimal visual noise, only relevant info |

### 2.2 UX (User Experience) Criteria - 10 Tests

| Test ID | Criterion | Description |
|---------|-----------|-------------|
| UX.1 | Discoverability | `help` lists all command categories |
| UX.2 | Self-Documenting | Command names indicate purpose |
| UX.3 | Error Suggestions | "Did you mean?" for typos |
| UX.4 | Tab Completion | Shell completion scripts |
| UX.5 | Consistent Structure | All commands follow same patterns |
| UX.6 | Reasonable Defaults | Works without optional args |
| UX.7 | Interactive Mode | Prompts for complex operations |
| UX.8 | Quick Feedback | < 200ms for simple commands |
| UX.9 | Undo/Rollback | Reversible destructive actions |
| UX.10 | Progressive Disclosure | --verbose for more details |

### 2.3 CX (Customer Experience) Criteria - 8 Tests

| Test ID | Criterion | Description |
|---------|-----------|-------------|
| CX.1 | Reliability | 99.9% uptime target |
| CX.2 | Consistency | Deterministic behavior |
| CX.3 | Graceful Degradation | Works with partial failures |
| CX.4 | Error Recovery | Clear steps to fix problems |
| CX.5 | Frictionless Security | Streamlined Guardian approval |
| CX.6 | Performance | < 5s for all commands |
| CX.7 | Audit Trail | Every operation logged |
| CX.8 | Data Integrity | No data loss on crash |

### 2.4 DX (Developer Experience) Criteria - 10 Tests

| Test ID | Criterion | Description |
|---------|-----------|-------------|
| DX.1 | Composability | Pipe-friendly output |
| DX.2 | JSON Output | --json flag for parsing |
| DX.3 | Exit Codes | 0=success, 1=error, 2=warning |
| DX.4 | Verbose Mode | --verbose shows internals |
| DX.5 | Dry-Run Mode | --dry-run for testing |
| DX.6 | Version Info | --version available |
| DX.7 | Config File | ~/.cockpitf.yaml support |
| DX.8 | Plugin Architecture | Custom command extensions |
| DX.9 | SDK Access | Cepaf.Cockpit.Cli module |
| DX.10 | API Versioning | Breaking changes documented |

---

## 3.0 AI Intelligence Tests (OpenRouter)

### 3.1 AI Integration Requirements

| Test ID | Requirement | STAMP |
|---------|-------------|-------|
| AI.1 | Natural Language Queries | copilot-query accepts free text |
| AI.2 | Human in the Loop | AI is ADVISORY only (SC-AI-001) |
| AI.3 | Confidence Scores | Display confidence % (SC-AI-002) |
| AI.4 | Audit Trail | Log all AI interactions (SC-AI-003) |
| AI.5 | Graceful Fallback | Works without AI (SC-AI-004) |
| AI.6 | Domain Analysis | copilot-analyze for insights |
| AI.7 | Recommendations | copilot-recommend for actions |
| AI.8 | RAG Search | knowledge-search queries docs |
| AI.9 | Timeout Limit | 10s max for AI responses |
| AI.10 | Free Models | Prefer free OpenRouter tier |
| AI.11 | Error Explanation | AI explains errors plainly |
| AI.12 | Context Awareness | AI knows system state |

### 3.2 OpenRouter Configuration

```fsharp
type AiConfig = {
    Enabled: bool
    ApiEndpoint: "https://openrouter.ai/api/v1/chat/completions"
    Model: "meta-llama/llama-3.3-70b-instruct:free"
    MaxTokens: 500
    Temperature: 0.3
    TimeoutMs: 10000
}
```

---

## 4.0 STAMP Constraint Compliance

| ID | Constraint | Severity | Test |
|----|------------|----------|------|
| SC-CLI-001 | All Prajna capabilities have CLI | CRITICAL | 69 commands ≥ 21 dashboards |
| SC-CLI-002 | 5-order telemetry | HIGH | All commands emit effects |
| SC-CLI-003 | Guardian for destructive ops | CRITICAL | domain-disable, mara-inject |
| SC-CLI-004 | Bridge timeout < 5s | HIGH | HTTP timeout enforced |
| SC-CLI-005 | No browser required | CRITICAL | Pure terminal |
| SC-CLI-006 | Consistent naming | MEDIUM | category-action pattern |
| SC-CLI-007 | Help for all commands | MEDIUM | --help everywhere |
| SC-CLI-008 | Recovery in errors | HIGH | Actionable error messages |

---

## 5.0 Command Coverage Matrix

### 5.1 All 69 Commands by Category

| Category | Count | Commands |
|----------|-------|----------|
| **Mesh Lifecycle** | 12 | sa-up, sa-down, sa-status, sa-health, sa-clean, sa-scour, sa-emergency, sa-verify, sa-logs, sa-test, sa-dashboard, sa-supervisor |
| **Domain Control** | 6 | domain-list, domain-status, domain-metrics, domain-circuit, domain-enable, domain-disable |
| **Safety/Guardian** | 8 | guardian-status, guardian-propose, guardian-pending, guardian-approve, guardian-reject, sentinel-health, sentinel-threats, sentinel-patterns |
| **Constitutional** | 5 | constitution-verify, constitution-status, holon-state, holon-tree, holon-history |
| **Observability** | 9 | metrics-all, metrics-domain, metrics-containers, traces-list, traces-show, logs-query, zenoh-topics, zenoh-publish, zenoh-subscribe |
| **AI/Copilot** | 5 | copilot-query (NL implemented [Updated Sprint 51]), copilot-analyze, copilot-recommend, knowledge-search, knowledge-ingest |
| **Cluster/Federation** | 6 | cluster-nodes (real DistributedMesh + Node.list [Updated Sprint 51]), cluster-health, cluster-quorum, federation-peers (implemented [Updated Sprint 51]), federation-sync, federation-announce |
| **Alarms/Dispatch** | 4 | alarms-list (real implementation [Updated Sprint 51]), alarms-stats, alarms-acknowledge, dispatch-status |
| **Devices/Sites** | 5 | devices-list, devices-health, devices-offline, sites-list, sites-health |
| **Compliance/Audit** | 4 | compliance-status, compliance-gaps, audit-trail, audit-export |
| **Chaos/Testing** | 5 | mara-inject, mara-status, antibody-deploy, test-property, test-coverage |
| **Total** | **69** | |

### 5.2 Domain Coverage (30 Domains)

All 30 domains must support: `domain-status <domain>`, `domain-metrics <domain>`, `domain-circuit <domain>`

```
access_control, accounts, alarms, analytics, authentication,
authorization, billing, cluster, cockpit, communication,
compliance, coordination, cortex, cybernetic, devices,
dispatch, distributed, flame, identity, integration,
knowledge, maintenance, mesh, observability, policy,
safety, security, sites, validation, video
```

---

## 6.0 Test Implementation

### 6.1 F# Test File Location

```
lib/cepaf/test/Cepaf.Tests/CockpitFCliTestPlan.fs
```

### 6.2 Running Tests

```bash
# Run all cockpitf CLI tests
dotnet test --filter "CockpitF CLI"

# Run specific level
dotnet test --filter "L1-Ecosystem"

# Run UI criteria only
dotnet test --filter "UI-Interface"

# Run AI tests
dotnet test --filter "AI-Embedded"
```

### 6.3 Test Structure

```fsharp
[<Tests>]
let cockpitfCliTests =
    testList "CockpitF CLI Fractal Test Plan" [
        // 7 Fractal Levels
        Level1_Ecosystem.ecosystemTests          // 5 tests
        Level2_Federation.federationTests        // 5 tests
        Level3_Cluster.clusterTests             // 5 tests
        Level4_Domain.domainTests               // 36 tests
        Level5_Command.commandTests             // 5 tests
        Level6_Arguments.argumentTests          // 6 tests
        Level7_Implementation.implementationTests// 7 tests

        // Quality Criteria
        UiCriteriaTests.uiTests                 // 8 tests
        UxCriteriaTests.uxTests                 // 10 tests
        CxCriteriaTests.cxTests                 // 8 tests
        DxCriteriaTests.dxTests                 // 10 tests

        // AI & Compliance
        AiIntelligenceTests.aiTests             // 12 tests
        StampConstraintTests.stampTests         // 8 tests
        PropertyBasedTests.propertyTests        // 4 tests
        IntegrationTests.integrationTests       // 5 tests
    ]
```

---

## 7.0 Integration Workflows

### 7.1 Lifecycle Workflow
```
sa-up → sa-status → sa-health → sa-down
```

### 7.2 Guardian Workflow
```
guardian-propose <action> → guardian-pending → guardian-approve <id>
```

### 7.3 AI Workflow
```
copilot-query "What needs attention?" → copilot-analyze alarms → copilot-recommend
```

### 7.4 Monitoring Workflow
```
metrics-all → traces-list → logs-query "ERROR"
```

### 7.5 Crisis Workflow
```
sentinel-threats → mara-inject <fault> → antibody-deploy <defense>
```

---

## 8.0 Success Criteria

### 8.1 Minimum Requirements

| Metric | Target | Actual |
|--------|--------|--------|
| Total Tests | 101 | 101 |
| L1-L7 Coverage | 100% | - |
| UI Criteria Pass | 8/8 | - |
| UX Criteria Pass | 10/10 | - |
| CX Criteria Pass | 8/8 | - |
| DX Criteria Pass | 10/10 | - |
| AI Tests Pass | 12/12 | - |
| STAMP Compliance | 8/8 | - |
| Integration Pass | 5/5 | - |

### 8.2 Quality Gates

1. **ALL 101 tests must pass** before release
2. **Latency < 5s** for all commands
3. **Exit codes** must be meaningful (0/1/2)
4. **Help available** for every command
5. **Guardian gate** enforced for destructive ops

---

## 9.0 Related Documents

| Document | Location |
|----------|----------|
| CLI Complete Reference | docs/guides/COCKPITF_CLI_COMPLETE_REFERENCE.md |
| Fractal Capability Sync | docs/plans/FRACTAL_CAPABILITY_SYNC_IMPLEMENTATION_PLAN.md |
| AI Copilot Module | lib/cepaf/src/Cepaf/Cockpit/AiCopilot.fs |
| F# Test Implementation | lib/cepaf/test/Cepaf.Tests/CockpitFCliTestPlan.fs |
| GEMINI.md | GEMINI.md (Section 4.0 TDG) |
| CLAUDE.md | CLAUDE.md (Section 6.0 Commands) |

---

## 10.0 Appendix: FMEA Risk Analysis

| Failure Mode | Effect | Severity | Detection | RPN | Mitigation |
|--------------|--------|----------|-----------|-----|------------|
| AI timeout | Slow response | 5 | 9 | 45 | 10s timeout + fallback |
| Bridge down | Commands fail | 8 | 8 | 64 | Circuit breaker + retry |
| Invalid args | User confusion | 4 | 3 | 12 | Validation + suggestions |
| No color | Reduced UX | 2 | 2 | 4 | --no-color as fallback |
| Pagination fail | Missing data | 6 | 5 | 30 | Auto-page + manual limit |
