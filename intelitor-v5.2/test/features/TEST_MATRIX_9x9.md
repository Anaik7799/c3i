# 9x9 Test Matrix - SMRITI & CRM Work Streams

## Overview

This document defines a comprehensive 9x9 test matrix covering all features added in work streams WS1-WS8.

**Matrix Dimensions**:
- **Rows (9 Test Types)**: Unit, Property, Integration, Contract, E2E, Performance, Security, Chaos, BDD
- **Columns (9 Feature Domains)**: Semantic, Bridge, Client, API, Lead/Account, Sales, Automation, Analytics, Cross-Domain

## Test Matrix

| Test Type | WS1 Semantic | WS2 Bridge | WS3 Client | WS4 API | WS5 Core CRM | WS6 Sales | WS7 Automation | WS8 Analytics | Cross-Domain |
|-----------|--------------|------------|------------|---------|--------------|-----------|----------------|---------------|--------------|
| **L1 Unit** | TripleStore | HealthSync | Model/Msg | Handlers | Resources | Quote/Order | Rules | Pipeline | E2E Flow |
| **L2 Property** | RDF Types | Serialization | State | JSON | CRUD | Pricing | Criteria | Metrics | Data Flow |
| **L3 Integration** | Query+Infer | F#↔Elixir | MVU Cycle | REST | Domain | Workflow | Triggers | Reports | System |
| **L4 Contract** | SPARQL | Proto | Routes | OpenAPI | Ash Actions | Line Items | Actions | Endpoints | Federation |
| **L5 E2E** | Full Pipeline | Roundtrip | UI Flow | Endpoints | Lifecycle | Quote→Order | Auto-Assign | Dashboard | Journey |
| **L6 Performance** | 1K Triples | Latency | Render | RPS | Bulk Ops | Calculations | Rule Eval | Aggregation | Load |
| **L7 Security** | Injection | Auth | XSS | OWASP | RBAC | Pricing | Escalation | Data Access | Compliance |
| **L8 Chaos** | Corruption | Disconnect | Offline | Timeout | Constraint | Conflict | Race | Stale | Partition |
| **L9 BDD** | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios | 9 Scenarios |

**Total Tests**: 81 test categories × multiple test cases each = 400+ individual tests

## STAMP Constraints

| ID | Constraint | Coverage |
|----|------------|----------|
| SC-COV-001 | Static coverage 100% | All L1 Unit tests |
| SC-COV-002 | Runtime coverage >= 95% | L3-L5 tests |
| SC-COV-003 | Mathematical proofs for core | L2 Property tests |
| SC-COV-004 | BDD specs for user journeys | L9 BDD tests |
| SC-COV-005 | FMEA for critical paths | L7-L8 tests |
| SC-TDG-001 | TDG compliance mandatory | All tests |

## Test File Locations

```
test/
├── features/                      # BDD Feature Files
│   ├── smriti/
│   │   ├── semantic_layer.feature
│   │   ├── elixir_bridge.feature
│   │   ├── elmish_client.feature
│   │   └── api_routes.feature
│   ├── crm/
│   │   ├── core_domain.feature
│   │   ├── sales_process.feature
│   │   ├── automation.feature
│   │   └── analytics.feature
│   └── cross_domain.feature
├── smriti/                          # SMRITI Unit/Integration Tests
│   ├── semantic_layer_test.exs
│   ├── bridge_test.exs
│   └── api_test.exs
├── crm/                           # CRM Tests
│   ├── lead_test.exs
│   ├── account_test.exs
│   ├── opportunity_test.exs
│   ├── quote_test.exs
│   ├── automation_test.exs
│   └── analytics_test.exs
└── property/                      # Property Tests
    ├── crm_properties_test.exs
    └── smriti_properties_test.exs
```

## Execution Order

1. **L1 Unit Tests**: `mix test test/smriti test/crm --only unit`
2. **L2 Property Tests**: `mix test test/property`
3. **L3 Integration Tests**: `mix test --only integration`
4. **L4-L5 E2E Tests**: `mix test --only e2e`
5. **L6 Performance**: `mix test --only performance`
6. **L7-L8 Security/Chaos**: `mix test --only security,chaos`
7. **L9 BDD**: `mix test --only bdd`

## Version

| Field | Value |
|-------|-------|
| Version | 21.3.0 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-COV-001 to SC-COV-006 |
