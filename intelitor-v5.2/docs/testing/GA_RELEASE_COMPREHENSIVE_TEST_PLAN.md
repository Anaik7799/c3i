# Indrajaal v21.3.0-SIL6 GA Release Comprehensive Test Plan
**Document ID**: TP-GA-21.3.0-001
**Version**: 2.1.0
**Date**: 2026-01-10 (Updated: 2026-03-19)
**Status**: DRAFT → REVIEW → APPROVED
**Classification**: Internal - Release Critical
**Compliance**: IEC 61508 SIL-6, ISO 29119, IEEE 829, ISO 27001, GDPR, EN 50131

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-10 | Claude Opus 4.5 | Initial comprehensive release |
| 2.0.0 | 2026-03-19 | Claude Opus 4.6 | Sprint 51 sync: updated module counts, container topology, F# status |
| 2.1.0 | 2026-03-19 | Claude Sonnet 4.6 | Sync to v21.3.0-SIL6: 1,508 Elixir files, 923 F# files, 1,005 test files, 549+ F# tests |

| Reviewer | Role | Date | Approval |
|----------|------|------|----------|
| TBD | Release Manager | | ☐ |
| TBD | QA Lead | | ☐ |
| TBD | Safety Engineer | | ☐ |
| TBD | Security Officer | | ☐ |
| TBD | System Architect | | ☐ |
| TBD | Product Owner | | ☐ |

---

## Executive Summary

This document defines the complete test strategy for the **Indrajaal v21.3.0-SIL6 GA Release**, covering:

- **1,508 Elixir modules** across 30+ domains
- **923 F# CEPAF modules** for cognitive plane
- **15 container SIL-6 mesh (4 prod-standalone)** with SIL-6 compliance
- **75+ API endpoints** with OpenAPI validation
- **15+ LiveView pages** including Prajna C3I Cockpit
- **Full observability stack** (OTEL, Prometheus, Grafana, Loki)
- **Security compliance** (OWASP, ISO 27001, GDPR)
- **Performance benchmarks** (SLA validation)

### Release Readiness Target

```
┌─────────────────────────────────────────────────────────────────────────┐
│  GA RELEASE READINESS SCORECARD TARGET                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Compilation         ████████████████████  100%  (0 errors, 0 warnings)│
│  Unit Tests          ████████████████████  100%  (0 failures)          │
│  Property Tests      ████████████████████  100%  (0 failures)          │
│  Integration Tests   ████████████████████   95%  (critical paths)      │
│  E2E Tests           ████████████████████   90%  (user journeys)       │
│  API Contract        ████████████████████  100%  (OpenAPI valid)       │
│  Security Scan       ████████████████████  100%  (0 critical/high)     │
│  Performance         ████████████████████   95%  (SLA met)             │
│  Documentation       ████████████████████   90%  (API docs complete)   │
│  Code Coverage       ████████████████████   95%+ (statement coverage)  │
│                                                                         │
│  OVERALL READINESS:  95%+ REQUIRED FOR GA                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Table of Contents

1. [Release Scope](#1-release-scope)
2. [Test Strategy](#2-test-strategy)
3. [Release Artifacts Inventory](#3-release-artifacts-inventory)
4. [Test Phases](#4-test-phases)
5. [Domain Test Specifications](#5-domain-test-specifications)
6. [CEPAF/F# Test Specifications](#6-cepaff-test-specifications)
7. [API Test Specifications](#7-api-test-specifications)
8. [Web UI Test Specifications](#8-web-ui-test-specifications)
9. [Container/Infrastructure Tests](#9-containerinfrastructure-tests)
10. [Security Test Specifications](#10-security-test-specifications)
11. [Performance Test Specifications](#11-performance-test-specifications)
12. [Compliance Test Specifications](#12-compliance-test-specifications)
13. [Data Migration Tests](#13-data-migration-tests)
14. [Observability Tests](#14-observability-tests)
15. [Chaos Engineering Tests](#15-chaos-engineering-tests)
16. [Regression Test Suite](#16-regression-test-suite)
17. [Release Verification Checklist](#17-release-verification-checklist)
18. [Test Environment Matrix](#18-test-environment-matrix)
19. [Defect Triage Process](#19-defect-triage-process)
20. [Sign-off Criteria](#20-sign-off-criteria)

---

## 1. Release Scope

### 1.1 Release Overview

| Attribute | Value |
|-----------|-------|
| Version | 21.3.0-SIL6 |
| Codename | Biomorphic Fractal Mesh |
| Release Type | General Availability (GA) |
| Previous Version | 21.3.0-SIL6 |
| Release Date | TBD |

### 1.2 Component Inventory

```
┌─────────────────────────────────────────────────────────────────────────┐
│  RELEASE COMPONENT MATRIX                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ELIXIR LAYER                          F# COGNITIVE LAYER              │
│  ════════════════                      ═══════════════════             │
│  Files:          1,508                 Files:           923            │
│  Domains:        30+                   Projects:        5              │
│  LiveViews:      15+                   Scripts:         68             │
│  Controllers:    10+                   Tests:           549+           │
│  GenServers:     50+                   Lines:           ~315K          │
│  Supervisors:    25+                                                   │
│                                                                         │
│  INFRASTRUCTURE                        OBSERVABILITY                   │
│  ══════════════                        ═════════════                   │
│  Containers:     4 (prod) / 14 (mesh)  OTEL Modules:    4              │
│  Networks:       1                     Dashboards:      10+            │
│  Volumes:        7                     Alerts:          50+            │
│  Ports:          20+                   Metrics:         200+           │
│                                                                         │
│  DATABASE                              SECURITY                        │
│  ════════                              ════════                        │
│  Tables:         100+                  Auth Methods:    3              │
│  Migrations:     50+                   Roles:           10+            │
│  Indexes:        150+                  Permissions:     100+           │
│  Ash Domains:    10                    Audit Events:    50+            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 New Features in v21.3.0-SIL6

| Feature ID | Feature | Priority | Test Coverage |
|------------|---------|----------|---------------|
| F-001 | SIL-6 Biomorphic Extensions | P0 | Full |
| F-002 | 3-Node HA Cluster | P0 | Full |
| F-003 | Zenoh 2oo3 Quorum | P0 | Full |
| F-004 | Per-Node Holon Isolation | P0 | Full |
| F-005 | Prajna C3I Cockpit v2 | P1 | Full |
| F-006 | AI Copilot (Founder's Directive) | P1 | Full |
| F-007 | Digital Immune System | P1 | Full |
| F-008 | Immutable Register | P0 | Full |
| F-009 | Constitutional Reconfiguration | P0 | Full |
| F-010 | Unified Checkpoint Registry | P1 | Full |

### 1.4 Breaking Changes

| Change ID | Description | Migration Required | Test Plan |
|-----------|-------------|-------------------|-----------|
| BC-001 | HOLON_DATA_PATH required for HA | Yes | TC-HA-004 |
| BC-002 | service_healthy dependency | Yes | TC-HA-005 |
| BC-003 | Zenoh 1.0.0 upgrade | Yes | TC-ZN-001 |
| BC-004 | .NET 10.0 requirement | Yes | TC-NET-001 |

---

## 2. Test Strategy

### 2.1 Test Pyramid

```
                              ┌─────────────────┐
                              │    MANUAL       │  ← Exploratory, UAT
                             ─┤     (5%)        ├─
                            ──┴─────────────────┴──
                          ┌─────────────────────────┐
                          │      E2E (10%)          │  ← Puppeteer, Wallaby
                        ──┴─────────────────────────┴──
                      ┌─────────────────────────────────┐
                      │    INTEGRATION (20%)            │  ← API, Container
                    ──┴─────────────────────────────────┴──
                  ┌─────────────────────────────────────────┐
                  │      COMPONENT (25%)                    │  ← GenServer, Domain
                ──┴─────────────────────────────────────────┴──
              ┌─────────────────────────────────────────────────┐
              │        UNIT + PROPERTY (40%)                    │  ← TDG, PropCheck
            ──┴─────────────────────────────────────────────────┴──

Total Tests: 3,000+ automated, 50+ manual scenarios
```

### 2.2 Test Types by Layer

| Layer | Test Type | Tools | Target Count |
|-------|-----------|-------|--------------|
| L0 Runtime | Unit, Memory | ExUnit, Dialyzer | 100 |
| L1 Function | Unit, Contract | ExUnit, TypeCheck | 500 |
| L2 Component | Component, Mock | ExUnit, Mox | 400 |
| L3 Holon | State Machine | ExUnit, PropCheck | 300 |
| L4 Container | Integration | ExUnit, Podman | 200 |
| L5 Node | Infrastructure | Bash, Ansible | 100 |
| L6 Cluster | Distributed | ExUnit, Chaos | 150 |
| L7 Federation | Cross-cluster | Future | 50 |

### 2.3 Quality Gates

```elixir
# GA Release Quality Gates
@quality_gates %{
  compilation: %{
    errors: 0,
    warnings: 0,
    dialyzer_warnings: 0
  },
  tests: %{
    unit_pass_rate: 100.0,
    property_pass_rate: 100.0,
    integration_pass_rate: 95.0,
    e2e_pass_rate: 90.0
  },
  coverage: %{
    line_coverage: 95.0,
    branch_coverage: 85.0,
    function_coverage: 95.0
  },
  security: %{
    critical_vulnerabilities: 0,
    high_vulnerabilities: 0,
    sobelow_issues: 0
  },
  performance: %{
    p50_latency_ms: 50,
    p99_latency_ms: 200,
    throughput_rps: 1000,
    error_rate_percent: 0.1
  }
}
```

---

## 3. Release Artifacts Inventory

### 3.1 Elixir Artifacts

| Category | Count | Location | Test File Pattern |
|----------|-------|----------|-------------------|
| Core Modules | 100 | lib/indrajaal/*.ex | test/indrajaal/*_test.exs |
| Domain Contexts | 30 | lib/indrajaal/{domain}/ | test/indrajaal/{domain}/ |
| Ash Resources | 80 | lib/indrajaal/{domain}/resources/ | test/indrajaal/{domain}/ |
| GenServers | 50 | lib/indrajaal/**/*_server.ex | test/**/*_server_test.exs |
| Supervisors | 25 | lib/indrajaal/**/*_supervisor.ex | test/**/*_supervisor_test.exs |
| LiveViews | 15 | lib/indrajaal_web/live/ | test/indrajaal_web/live/ |
| Controllers | 10 | lib/indrajaal_web/controllers/ | test/indrajaal_web/controllers/ |
| Channels | 5 | lib/indrajaal_web/channels/ | test/indrajaal_web/channels/ |
| Plugs | 15 | lib/indrajaal_web/plugs/ | test/indrajaal_web/plugs/ |

### 3.2 Elixir Domain Matrix

| Domain | Modules | Resources | Priority | Coverage Target |
|--------|---------|-----------|----------|-----------------|
| accounts | 25 | 5 | P0 | 100% |
| alarms | 40 | 8 | P0 | 100% |
| authentication | 30 | 4 | P0 | 100% |
| authorization | 35 | 6 | P0 | 100% |
| billing | 20 | 5 | P1 | 95% |
| cockpit/prajna | 50 | 10 | P0 | 100% |
| compliance | 25 | 5 | P1 | 95% |
| coordination | 15 | 3 | P1 | 95% |
| cortex | 60 | 12 | P0 | 100% |
| devices | 45 | 10 | P0 | 100% |
| environmental | 15 | 3 | P2 | 90% |
| flame | 20 | 4 | P1 | 95% |
| instrumentation | 30 | 6 | P1 | 95% |
| kms | 35 | 8 | P0 | 100% |
| logging | 20 | 4 | P1 | 95% |
| maintenance | 15 | 3 | P2 | 90% |
| metabolism | 25 | 5 | P1 | 95% |
| metrics | 30 | 6 | P1 | 95% |
| multitenancy | 20 | 4 | P0 | 100% |
| observability | 25 | 5 | P1 | 95% |
| property_testing | 30 | 0 | P1 | 95% |
| safety | 40 | 8 | P0 | 100% |
| scripting | 15 | 3 | P2 | 90% |
| security | 35 | 7 | P0 | 100% |
| sites | 30 | 6 | P0 | 100% |
| telecom | 20 | 4 | P1 | 95% |
| telemetry | 25 | 5 | P1 | 95% |
| upgrade | 10 | 2 | P1 | 95% |
| validation | 20 | 0 | P0 | 100% |
| video | 25 | 5 | P1 | 95% |

### 3.3 F# CEPAF Artifacts

| Project | Files | Scripts | Tests | Coverage Target |
|---------|-------|---------|-------|-----------------|
| Cepaf.Core | 80 | 10 | 150 | 95% |
| Cepaf.Bridge | 60 | 8 | 100 | 95% |
| Cepaf.Cockpit | 100 | 20 | 200 | 90% |
| Cepaf.Mesh | 120 | 15 | 200 | 95% |
| Cepaf.Tests | 87 | 15 | 549+ | N/A |
| **Total** | **~447** | **68** | **549+** | — |

Note: Total F# file count across all projects is 923 files, ~315K lines.

### 3.4 Container Artifacts

| Container | Image | Ports | Health Check | Priority |
|-----------|-------|-------|--------------|----------|
| indrajaal-haproxy | haproxy:2.9-alpine | 4000, 8404 | Config check | P0 |
| indrajaal-ex-app-1 | localhost/indrajaal-app-unified | 4000 | HTTP /health | P0 |
| indrajaal-ex-app-2 | localhost/indrajaal-app-unified | 4000 | HTTP /health | P0 |
| indrajaal-ex-app-3 | localhost/indrajaal-app-unified | 4000 | HTTP /health | P0 |
| indrajaal-db-ha | localhost/indrajaal-timescaledb-demo | 5433 | pg_isready | P0 |
| indrajaal-obs-ha | localhost/indrajaal-obs-unified | 4317, 9090, 3000 | HTTP /api/health | P1 |
| zenoh-ha-1 | eclipse/zenoh:1.0.0 | 7447, 8000 | nc port check | P0 |
| zenoh-ha-2 | eclipse/zenoh:1.0.0 | 7448, 8001 | nc port check | P0 |
| zenoh-ha-3 | eclipse/zenoh:1.0.0 | 7449, 8002 | nc port check | P0 |
| zenoh-ha-proxy | eclipse/zenoh:1.0.0 | - | nc port check | P0 |
| cepaf-bridge-ha | localhost/cepaf-bridge | 9876 | nc port check | P1 |
| indrajaal-cortex-ha | localhost/indrajaal-cortex | 9877 | process check | P1 |

### 3.5 Database Artifacts

| Category | Count | Location | Test Type |
|----------|-------|----------|-----------|
| Migrations | 50+ | priv/repo/migrations/ | Migration test |
| Seeds | 10+ | priv/repo/seeds/ | Seed validation |
| Ash Domains | 10 | lib/indrajaal/**/ | Domain test |
| TimescaleDB Hypertables | 5 | SQL migrations | Integration |
| Indexes | 150+ | Migrations | Performance |

### 3.6 API Artifacts

| Category | Endpoints | Spec Location | Test Type |
|----------|-----------|---------------|-----------|
| REST API | 40+ | priv/static/openapi/ | Contract |
| GraphQL | 20+ | lib/indrajaal_web/schema/ | Schema |
| WebSocket | 5+ | lib/indrajaal_web/channels/ | Connection |
| Zenoh Pub/Sub | 15+ | Config files | Message |

### 3.7 Documentation Artifacts

| Document | Location | Status | Test |
|----------|----------|--------|------|
| API Docs | docs/api/ | Required | Link check |
| Architecture | docs/architecture/ | Required | Review |
| User Guide | docs/guides/ | Required | Accuracy |
| Changelog | CHANGELOG.md | Required | Completeness |
| Release Notes | RELEASE_NOTES.md | Required | Accuracy |

---

## 4. Test Phases

### 4.1 Phase Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GA RELEASE TEST PHASES                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1          PHASE 2          PHASE 3          PHASE 4      PHASE 5   │
│  BUILD            VERIFY           VALIDATE         CERTIFY      RELEASE   │
│  ═══════          ══════           ════════         ═══════      ═══════   │
│                                                                             │
│  Compile          Unit Tests       Integration      Security     Smoke     │
│  Static           Property         E2E              Performance  Rollback  │
│  Lint             Domain           Chaos            Compliance   Sign-off  │
│  Format           Coverage         UAT              Audit                  │
│                                                                             │
│  ◄─── 2 days ───►◄─── 5 days ────►◄─── 5 days ───►◄── 3 days ─►◄─ 2 days ►│
│                                                                             │
│  Gate: 0 errors   Gate: 100%      Gate: 95%        Gate: 0      Gate: All │
│        0 warnings       pass            pass       critical     sign-offs │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Total Duration: 17 days (3.5 weeks)
```

### 4.2 Phase 1: Build Verification (2 days)

| Activity | Tool | Exit Criteria |
|----------|------|---------------|
| Elixir Compilation | mix compile | 0 errors, 0 warnings |
| F# Compilation | dotnet build | 0 errors |
| Static Analysis | Dialyzer | 0 warnings |
| Code Format | mix format | All files formatted |
| Lint | Credo --strict | 0 issues |
| Dependency Audit | mix deps.audit | No vulnerabilities |
| Container Build | podman build | All 4 prod-standalone images built (14 for full-mesh) |

**Phase 1 Checklist**:
```bash
# Build verification commands
devenv shell
compile-strict          # Must exit 0
quality-full           # Must exit 0
cepaf-build            # Must exit 0

# Container builds
podman build -t indrajaal-app-unified -f Containerfile.app .
podman build -t indrajaal-timescaledb-demo -f Containerfile.db .
podman build -t indrajaal-obs-unified -f Containerfile.obs .
podman build -t cepaf-bridge -f lib/cepaf/Containerfile .
```

### 4.3 Phase 2: Test Verification (5 days)

| Day | Activity | Tests | Target |
|-----|----------|-------|--------|
| 1 | Unit Tests | 500+ | 100% pass |
| 2 | Property Tests | 200+ | 100% pass |
| 3 | Domain Tests | 300+ | 100% pass |
| 4 | Component Tests | 200+ | 100% pass |
| 5 | Coverage Analysis | N/A | ≥95% |

**Phase 2 Checklist**:
```bash
# Test execution commands
test                    # All unit tests
test-cover             # With coverage

# Specific test suites
MIX_ENV=test mix test test/indrajaal/
MIX_ENV=test mix test test/indrajaal_web/
MIX_ENV=test mix test test/sil6/

# F# tests
dotnet test lib/cepaf/Cepaf.Tests/
```

### 4.4 Phase 3: Integration Validation (5 days)

| Day | Activity | Tests | Target |
|-----|----------|-------|--------|
| 1 | API Integration | 100+ | 95% pass |
| 2 | Container Integration | 50+ | 95% pass |
| 3 | E2E User Journeys | 50+ | 90% pass |
| 4 | Chaos Engineering | 30+ | All recover |
| 5 | UAT Scenarios | 20+ | All accepted |

**Phase 3 Checklist**:
```bash
# Start HA mesh
sa-up

# Integration tests
MIX_ENV=test mix test --only integration
MIX_ENV=test mix test test/sil6/ha_mesh_integration_test.exs

# E2E tests
npm run test:e2e

# Chaos tests
MIX_ENV=test mix test test/sil6/chaos/ --include chaos
```

### 4.5 Phase 4: Certification (3 days)

| Day | Activity | Tests | Target |
|-----|----------|-------|--------|
| 1 | Security Scan | Full | 0 critical/high |
| 2 | Performance Test | Load | SLA met |
| 3 | Compliance Audit | Checklist | All passed |

**Phase 4 Checklist**:
```bash
# Security scans
mix sobelow --exit
mix deps.audit
npm audit

# Performance tests
k6 run scripts/testing/load/ha_load_test.js

# Compliance checks
elixir scripts/compliance/gdpr_checker.exs
elixir scripts/compliance/iso27001_checker.exs
```

### 4.6 Phase 5: Release (2 days)

| Day | Activity | Tests | Target |
|-----|----------|-------|--------|
| 1 | Staging Deploy | Smoke | All pass |
| 1 | Rollback Test | Recovery | Successful |
| 2 | Production Deploy | Smoke | All pass |
| 2 | Sign-off | Approval | All signatures |

---

## 5. Domain Test Specifications

### 5.1 Core Domain Tests

#### 5.1.1 Accounts Domain

```elixir
# test/indrajaal/accounts/accounts_test.exs

defmodule Indrajaal.AccountsTest do
  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Accounts

  describe "User CRUD" do
    test "creates user with valid attributes" do
      attrs = %{email: "test@example.com", name: "Test User"}
      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.email == attrs.email
    end

    property "email validation rejects invalid formats" do
      forall email <- invalid_email_generator() do
        attrs = %{email: email, name: "Test"}
        {:error, _} = Accounts.create_user(attrs)
      end
    end
  end

  describe "Authentication" do
    test "authenticates user with correct credentials" do
      user = insert(:user, password: "ValidPass123!")
      assert {:ok, ^user} = Accounts.authenticate(user.email, "ValidPass123!")
    end

    test "rejects incorrect password" do
      user = insert(:user, password: "ValidPass123!")
      assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, "wrong")
    end
  end

  # Property generators
  defp invalid_email_generator do
    PC.oneof([
      PC.utf8(),                    # Random UTF-8
      "no-at-sign",                 # Missing @
      "@no-local.com",              # Missing local part
      "spaces in@email.com"         # Invalid spaces
    ])
  end
end
```

#### 5.1.2 Alarms Domain

```elixir
# test/indrajaal/alarms/alarms_test.exs

defmodule Indrajaal.AlarmsTest do
  use Indrajaal.DataCase, async: true
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Alarms

  @severities [:low, :medium, :high, :critical]

  describe "Alarm Processing" do
    test "creates alarm with valid SIA code" do
      site = insert(:site)
      attrs = %{
        site_id: site.id,
        sia_code: "BA",
        severity: :high,
        message: "Burglary alarm triggered"
      }
      assert {:ok, alarm} = Alarms.create_alarm(attrs)
      assert alarm.severity == :high
    end

    property "alarm severity is always valid" do
      forall severity <- PC.oneof(@severities) do
        alarm = build(:alarm, severity: severity)
        alarm.severity in @severities
      end
    end

    test "processes alarm storm correctly" do
      site = insert(:site)
      # Generate 100 alarms rapidly
      alarms = for _ <- 1..100 do
        insert(:alarm, site: site)
      end

      # Storm detection should trigger
      assert Alarms.detect_storm?(site.id)
    end
  end

  describe "Alarm Correlation" do
    test "correlates related alarms" do
      site = insert(:site)
      alarm1 = insert(:alarm, site: site, sia_code: "BA")
      alarm2 = insert(:alarm, site: site, sia_code: "BR", parent_alarm: alarm1)

      correlated = Alarms.get_correlated_alarms(alarm1.id)
      assert alarm2 in correlated
    end
  end
end
```

#### 5.1.3 Safety Domain (SIL-6 Critical)

```elixir
# test/indrajaal/safety/safety_test.exs

defmodule Indrajaal.SafetyTest do
  use Indrajaal.DataCase, async: true
  use PropCheck

  alias PropCheck.BasicTypes, as: PC
  alias Indrajaal.Safety
  alias Indrajaal.Safety.Guardian

  @moduletag :sil6
  @moduletag :safety_critical

  describe "Guardian Validation" do
    test "approves safe operations" do
      proposal = %{
        action: :read,
        resource: :alarm,
        actor: build(:user, role: :operator)
      }
      assert {:ok, :approved} = Guardian.validate(proposal)
    end

    test "vetoes unsafe operations" do
      proposal = %{
        action: :delete_all,
        resource: :alarms,
        actor: build(:user, role: :operator)  # Not admin
      }
      assert {:error, :vetoed, reason} = Guardian.validate(proposal)
      assert reason =~ "insufficient"
    end

    property "Guardian never approves unauthorized mutations" do
      forall {action, role} <- unauthorized_combinations() do
        proposal = %{action: action, resource: :critical, actor: build(:user, role: role)}
        case Guardian.validate(proposal) do
          {:ok, :approved} -> false  # Should never happen
          {:error, :vetoed, _} -> true
        end
      end
    end
  end

  describe "Constitutional Invariants" do
    test "Ψ₀ Existence is preserved" do
      # System cannot self-terminate
      assert {:error, :constitutional_violation} =
        Safety.execute(%{action: :system_shutdown, force: true})
    end

    test "Ψ₁ Regenerative completeness" do
      # State can be recovered
      state = Safety.capture_state()
      assert Safety.can_regenerate?(state)
    end
  end

  defp unauthorized_combinations do
    PC.let([
      action <- PC.oneof([:delete, :purge, :terminate]),
      role <- PC.oneof([:viewer, :operator])
    ]) do
      {action, role}
    end
  end
end
```

### 5.2 Domain Test Matrix

| Domain | Unit | Property | Integration | E2E | Total |
|--------|------|----------|-------------|-----|-------|
| accounts | 30 | 15 | 10 | 5 | 60 |
| alarms | 50 | 25 | 20 | 10 | 105 |
| authentication | 25 | 10 | 15 | 5 | 55 |
| authorization | 35 | 20 | 15 | 5 | 75 |
| cockpit/prajna | 60 | 30 | 25 | 15 | 130 |
| cortex | 80 | 40 | 30 | 10 | 160 |
| devices | 55 | 25 | 20 | 10 | 110 |
| safety | 45 | 30 | 20 | 5 | 100 |
| security | 40 | 25 | 20 | 10 | 95 |
| sites | 35 | 15 | 15 | 5 | 70 |
| **Other domains** | 200 | 80 | 60 | 20 | 360 |
| **TOTAL** | **655** | **315** | **250** | **100** | **1,320** |

---

## 6. CEPAF/F# Test Specifications

### 6.1 F# Test Framework

```fsharp
// lib/cepaf/Cepaf.Tests/MeshOrchestratorTests.fs

module Cepaf.Tests.MeshOrchestratorTests

open Xunit
open FsCheck
open FsCheck.Xunit
open Cepaf.Mesh.SIL6MeshOrchestrator

[<Fact>]
let ``Mesh boots through all 5 stages`` () =
    let stages = [| Preflight; Ignition; Lens; Convergence; Ready |]
    let result = bootMesh()
    Assert.Equal(Ready, result.currentStage)
    Assert.True(result.allStagesPassed)

[<Property>]
let ``Quorum calculation is correct for any node count`` (nodeCount: PositiveInt) =
    let n = nodeCount.Get
    let quorum = calculateQuorum n
    quorum = (n / 2) + 1

[<Fact>]
let ``Health coordinator uses FPPS consensus`` () =
    let health = assessHealth()
    Assert.Equal(5, health.methodsUsed)  // 5-method consensus
    Assert.True(health.consensusReached)

[<Fact>]
let ``Apoptosis follows 6-phase protocol`` () =
    let phases = [| Initiated; Notifying; Draining; Checkpointing; Terminating; Terminated |]
    let result = initiateApoptosis "test-node"
    Assert.Equal(6, result.phasesCompleted)

[<Property>]
let ``2oo3 voting requires majority`` (v1: bool) (v2: bool) (v3: bool) =
    let result = vote2oo3 v1 v2 v3
    let expected = (v1 && v2) || (v2 && v3) || (v1 && v3)
    result = expected
```

### 6.2 F# Test Coverage Matrix

| Module | Unit | Property | Integration | Coverage |
|--------|------|----------|-------------|----------|
| SIL6MeshOrchestrator | 25 | 15 | 10 | 95% |
| HealthCoordinator | 20 | 10 | 8 | 95% |
| Apoptosis | 15 | 8 | 5 | 95% |
| FederationProtocol | 20 | 12 | 8 | 90% |
| DigitalTwin | 30 | 15 | 12 | 95% |
| PanopticonOrchestrator | 25 | 12 | 10 | 95% |
| ZenohBridge | 20 | 10 | 15 | 90% |
| Integration | 40 | 20 | 30 | 85% |
| **TOTAL** | **195** | **102** | **98** | **92%** |

### 6.3 F# Test Commands

```bash
# Run all F# tests
dotnet test lib/cepaf/Cepaf.Tests/

# Run with coverage
dotnet test lib/cepaf/Cepaf.Tests/ --collect:"XPlat Code Coverage"

# Run specific test class
dotnet test lib/cepaf/Cepaf.Tests/ --filter "FullyQualifiedName~MeshOrchestrator"

# Run property tests only
dotnet test lib/cepaf/Cepaf.Tests/ --filter "Category=Property"
```

---

## 7. API Test Specifications

### 7.1 REST API Tests

| Endpoint | Method | Priority | Test Cases | Coverage |
|----------|--------|----------|------------|----------|
| /api/health | GET | P0 | 5 | 100% |
| /api/v1/alarms | GET, POST | P0 | 20 | 100% |
| /api/v1/alarms/:id | GET, PUT, DELETE | P0 | 15 | 100% |
| /api/v1/sites | CRUD | P0 | 20 | 100% |
| /api/v1/devices | CRUD | P0 | 20 | 100% |
| /api/v1/users | CRUD | P0 | 15 | 100% |
| /api/v1/auth/login | POST | P0 | 10 | 100% |
| /api/v1/auth/refresh | POST | P0 | 5 | 100% |
| /api/prajna/metrics | GET | P1 | 10 | 95% |
| /api/prajna/guardian/propose | POST | P0 | 15 | 100% |
| /api/prajna/sentinel/threats | GET | P1 | 10 | 95% |

### 7.2 API Contract Test Template

```elixir
# test/indrajaal_web/controllers/api/alarms_controller_test.exs

defmodule IndrajaalWeb.Api.AlarmsControllerTest do
  use IndrajaalWeb.ConnCase, async: true
  import OpenApiSpex.TestAssertions

  @schema IndrajaalWeb.ApiSpec.spec()

  describe "GET /api/v1/alarms" do
    setup [:create_user, :authenticate]

    test "returns list of alarms", %{conn: conn} do
      insert_list(5, :alarm)

      conn = get(conn, ~p"/api/v1/alarms")

      assert json_response(conn, 200)
      assert_schema(json_response(conn, 200), "AlarmListResponse", @schema)
    end

    test "filters by severity", %{conn: conn} do
      insert(:alarm, severity: :critical)
      insert(:alarm, severity: :low)

      conn = get(conn, ~p"/api/v1/alarms?severity=critical")

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert hd(response["data"])["severity"] == "critical"
    end

    test "returns 401 without authentication" do
      conn = build_conn()
      conn = get(conn, ~p"/api/v1/alarms")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/v1/alarms" do
    setup [:create_user, :authenticate]

    test "creates alarm with valid data", %{conn: conn} do
      site = insert(:site)
      attrs = %{
        site_id: site.id,
        sia_code: "BA",
        severity: "high",
        message: "Test alarm"
      }

      conn = post(conn, ~p"/api/v1/alarms", alarm: attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert_schema(json_response(conn, 201), "AlarmResponse", @schema)
    end

    test "returns 422 with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/alarms", alarm: %{})
      assert json_response(conn, 422)
    end
  end
end
```

### 7.3 API Test Summary

| Category | Endpoints | Test Cases | Automation |
|----------|-----------|------------|------------|
| Authentication | 5 | 30 | 100% |
| Alarms | 8 | 50 | 100% |
| Sites | 6 | 35 | 100% |
| Devices | 8 | 40 | 100% |
| Users | 6 | 30 | 100% |
| Prajna | 10 | 45 | 95% |
| WebSocket | 5 | 25 | 90% |
| **TOTAL** | **48** | **255** | **97%** |

---

## 8. Web UI Test Specifications

### 8.1 LiveView Pages

| Page | URL | Priority | Test Cases |
|------|-----|----------|------------|
| Prajna Cockpit | /prajna | P0 | 25 |
| AI Copilot | /prajna/copilot | P0 | 20 |
| Alarms Dashboard | /prajna/alarms | P0 | 20 |
| Access Control | /prajna/access_control | P1 | 15 |
| Analytics | /prajna/analytics | P1 | 15 |
| Compliance | /prajna/compliance | P1 | 15 |
| Devices | /prajna/devices | P1 | 15 |
| Video | /prajna/video | P2 | 10 |
| System Status | /system/status | P1 | 10 |
| Performance | /system/performance | P1 | 10 |

### 8.2 E2E Test Template (Puppeteer)

```javascript
// test/e2e/prajna_cockpit.spec.js

const puppeteer = require('puppeteer');

describe('Prajna C3I Cockpit', () => {
  let browser;
  let page;

  beforeAll(async () => {
    browser = await puppeteer.launch({ headless: 'new' });
    page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
  });

  afterAll(async () => {
    await browser.close();
  });

  describe('Dashboard Load', () => {
    test('loads within 3 seconds', async () => {
      const start = Date.now();
      await page.goto('http://localhost:4000/prajna');
      await page.waitForSelector('[data-testid="prajna-dashboard"]');
      const loadTime = Date.now() - start;
      expect(loadTime).toBeLessThan(3000);
    });

    test('displays health score', async () => {
      await page.goto('http://localhost:4000/prajna');
      const healthScore = await page.$eval(
        '[data-testid="health-score"]',
        el => el.textContent
      );
      expect(parseInt(healthScore)).toBeGreaterThan(0);
    });

    test('displays threat count', async () => {
      await page.goto('http://localhost:4000/prajna');
      const threatCount = await page.$('[data-testid="threat-count"]');
      expect(threatCount).not.toBeNull();
    });

    test('refreshes every 30 seconds', async () => {
      await page.goto('http://localhost:4000/prajna');
      const initialTime = await page.$eval(
        '[data-testid="last-updated"]',
        el => el.textContent
      );

      // Wait 35 seconds
      await new Promise(r => setTimeout(r, 35000));

      const updatedTime = await page.$eval(
        '[data-testid="last-updated"]',
        el => el.textContent
      );
      expect(updatedTime).not.toBe(initialTime);
    }, 40000);
  });

  describe('AI Copilot', () => {
    test('chat input is functional', async () => {
      await page.goto('http://localhost:4000/prajna/copilot');
      await page.type('[data-testid="copilot-input"]', 'What is the system status?');
      await page.click('[data-testid="copilot-send"]');
      await page.waitForSelector('[data-testid="copilot-response"]');
      const response = await page.$eval(
        '[data-testid="copilot-response"]',
        el => el.textContent
      );
      expect(response.length).toBeGreaterThan(0);
    });

    test('recommendations align with Founder Directive', async () => {
      await page.goto('http://localhost:4000/prajna/copilot');
      await page.type('[data-testid="copilot-input"]', 'Recommend action for critical alarm');
      await page.click('[data-testid="copilot-send"]');
      await page.waitForSelector('[data-testid="copilot-response"]');

      // Check for Founder's Directive compliance marker
      const compliance = await page.$('[data-testid="founder-directive-compliant"]');
      expect(compliance).not.toBeNull();
    });
  });
});
```

### 8.3 UI Test Coverage Matrix

| Page | Unit | Component | E2E | Visual | Total |
|------|------|-----------|-----|--------|-------|
| Prajna Cockpit | 20 | 15 | 25 | 5 | 65 |
| AI Copilot | 15 | 10 | 20 | 3 | 48 |
| Alarms | 20 | 15 | 20 | 5 | 60 |
| Other Pages | 50 | 30 | 30 | 10 | 120 |
| **TOTAL** | **105** | **70** | **95** | **23** | **293** |

---

## 9. Container/Infrastructure Tests

### 9.1 Container Test Matrix

| Container | Health | Startup | Network | Volume | Total |
|-----------|--------|---------|---------|--------|-------|
| haproxy | 5 | 3 | 5 | 2 | 15 |
| app-1,2,3 | 10 | 8 | 8 | 6 | 32 |
| db-ha | 5 | 5 | 3 | 5 | 18 |
| obs-ha | 5 | 5 | 5 | 3 | 18 |
| zenoh-1,2,3 | 10 | 8 | 10 | 3 | 31 |
| cepaf-bridge | 3 | 3 | 5 | 2 | 13 |
| cortex | 3 | 3 | 5 | 2 | 13 |
| **TOTAL** | **41** | **35** | **41** | **23** | **140** |

### 9.2 Infrastructure Test Checklist

```yaml
# Infrastructure Verification Checklist

containers:
  startup:
    - [ ] All 4 containers start successfully (prod-standalone); 14 for full-mesh
    - [ ] Startup order follows dependencies
    - [ ] Health checks pass within timeout
    - [ ] Restart policy works on failure

  networking:
    - [ ] All ports accessible
    - [ ] Inter-container communication works
    - [ ] HAProxy routing functional
    - [ ] Zenoh mesh connected

  volumes:
    - [ ] Data persistence verified
    - [ ] Build cache shared correctly
    - [ ] Holon isolation verified
    - [ ] Volume permissions correct

  resources:
    - [ ] Memory limits enforced
    - [ ] CPU limits enforced
    - [ ] Disk usage within bounds

database:
  - [ ] PostgreSQL accepts connections
  - [ ] Migrations applied successfully
  - [ ] TimescaleDB extensions loaded
  - [ ] Connection pooling works

observability:
  - [ ] OTEL collector receives traces
  - [ ] Prometheus scrapes metrics
  - [ ] Grafana dashboards load
  - [ ] Loki receives logs

zenoh:
  - [ ] 2oo3 quorum established
  - [ ] Messages delivered
  - [ ] Failover works
```

---

## 10. Security Test Specifications

### 10.1 Security Test Categories

| Category | Tool | Tests | Priority |
|----------|------|-------|----------|
| Static Analysis | Sobelow | 50+ | P0 |
| Dependency Audit | mix deps.audit | All deps | P0 |
| Authentication | Custom | 30 | P0 |
| Authorization | Custom | 40 | P0 |
| Input Validation | Property | 50 | P0 |
| SQL Injection | Custom + OWASP | 20 | P0 |
| XSS | Custom + OWASP | 20 | P0 |
| CSRF | Custom | 15 | P1 |
| Secret Management | Manual | 10 | P0 |
| TLS/Encryption | Manual | 10 | P1 |

### 10.2 OWASP Top 10 Coverage

| OWASP Category | Tests | Coverage |
|----------------|-------|----------|
| A01 Broken Access Control | 40 | 100% |
| A02 Cryptographic Failures | 15 | 100% |
| A03 Injection | 30 | 100% |
| A04 Insecure Design | 20 | 95% |
| A05 Security Misconfiguration | 15 | 95% |
| A06 Vulnerable Components | Audit | 100% |
| A07 Auth Failures | 25 | 100% |
| A08 Software Integrity | 10 | 95% |
| A09 Logging Failures | 15 | 95% |
| A10 SSRF | 10 | 100% |

### 10.3 Security Test Commands

```bash
# Static analysis
mix sobelow --exit --strict

# Dependency audit
mix deps.audit
mix hex.audit

# Secret scanning
gitleaks detect --source . --verbose

# Container security
podman scan indrajaal-app-unified

# OWASP ZAP scan (manual)
zap-cli quick-scan http://localhost:4000
```

---

## 11. Performance Test Specifications

### 11.1 Performance SLAs

| Metric | Target | Threshold | Critical |
|--------|--------|-----------|----------|
| p50 Latency | 30ms | 50ms | 100ms |
| p95 Latency | 100ms | 150ms | 300ms |
| p99 Latency | 150ms | 200ms | 500ms |
| Throughput | 1000 RPS | 800 RPS | 500 RPS |
| Error Rate | 0.01% | 0.1% | 1% |
| CPU Usage | 60% | 80% | 90% |
| Memory Usage | 70% | 85% | 95% |
| DB Connections | 50 | 80 | 100 |

### 11.2 Load Test Scenarios

| Scenario | Duration | Users | RPS | Purpose |
|----------|----------|-------|-----|---------|
| Smoke | 1m | 10 | 10 | Sanity check |
| Load | 10m | 100 | 100 | Normal load |
| Stress | 30m | 500 | 500 | Peak load |
| Spike | 5m | 1000 | 1000 | Burst handling |
| Soak | 4h | 200 | 200 | Memory leaks |
| Breakpoint | 1h | Ramp | Ramp | Find limits |

### 11.3 k6 Load Test Script

```javascript
// scripts/testing/load/ha_load_test.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const latency = new Trend('latency');

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up
    { duration: '5m', target: 100 },  // Stay at 100
    { duration: '2m', target: 200 },  // Ramp to 200
    { duration: '5m', target: 200 },  // Stay at 200
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],
    errors: ['rate<0.01'],
  },
};

export default function () {
  // Health check
  let healthRes = http.get('http://localhost:4000/api/health');
  check(healthRes, {
    'health status 200': (r) => r.status === 200,
  });

  // Alarms list
  let alarmsRes = http.get('http://localhost:4000/api/v1/alarms', {
    headers: { 'Authorization': `Bearer ${__ENV.TOKEN}` },
  });
  check(alarmsRes, {
    'alarms status 200': (r) => r.status === 200,
    'alarms latency < 200ms': (r) => r.timings.duration < 200,
  });

  errorRate.add(alarmsRes.status !== 200);
  latency.add(alarmsRes.timings.duration);

  // Prajna metrics
  let prajnaRes = http.get('http://localhost:4000/api/prajna/metrics');
  check(prajnaRes, {
    'prajna status 200': (r) => r.status === 200,
  });

  sleep(1);
}
```

---

## 12. Compliance Test Specifications

### 12.1 Compliance Framework Coverage

| Framework | Requirements | Tests | Coverage |
|-----------|--------------|-------|----------|
| IEC 61508 SIL-6 | 50 | 100 | 100% |
| ISO 27001 | 114 | 80 | 95% |
| GDPR | 40 | 60 | 100% |
| EN 50131 | 30 | 45 | 100% |
| SOC 2 Type II | 50 | 40 | 90% |

### 12.2 SIL-6 Compliance Checklist

```yaml
# SIL-6 Verification Checklist

safety_integrity:
  - [ ] PFH < 10^-12 verified
  - [ ] Diagnostic coverage > 99.99%
  - [ ] Safe failure fraction > 99.9%
  - [ ] TMR implemented for critical paths

biomorphic_extensions:
  - [ ] Self-healing validated
  - [ ] Symbiotic binding verified
  - [ ] Founder's Directive integration
  - [ ] Neural-immune response < 50ms

constitutional:
  - [ ] Ψ₀ Existence preservation
  - [ ] Ψ₁ Regenerative completeness
  - [ ] Ψ₂ Evolutionary continuity
  - [ ] Ψ₃ Verification capability
  - [ ] Ψ₄ Human alignment (amended)
  - [ ] Ψ₅ Truthfulness

guardian:
  - [ ] Absolute veto functional
  - [ ] All proposals logged
  - [ ] Rollback tested
```

---

## 13. Data Migration Tests

### 13.1 Migration Test Matrix

| Migration | Type | Rollback | Test Cases |
|-----------|------|----------|------------|
| Schema changes | DDL | Required | 5 |
| Data transforms | DML | Required | 10 |
| Index changes | DDL | Optional | 3 |
| Extension loads | DDL | Required | 3 |
| Seed data | DML | Required | 5 |

### 13.2 Migration Test Commands

```bash
# Run all migrations
mix ecto.migrate

# Rollback and re-migrate
mix ecto.rollback --all
mix ecto.migrate

# Verify schema
mix ecto.dump

# Test seeds
mix run priv/repo/seeds.exs
```

---

## 14. Observability Tests

### 14.1 Observability Verification

| Component | Tests | Priority |
|-----------|-------|----------|
| OTEL Traces | 15 | P1 |
| Prometheus Metrics | 20 | P1 |
| Grafana Dashboards | 10 | P1 |
| Loki Logs | 10 | P1 |
| Zenoh Telemetry | 15 | P1 |

### 14.2 Observability Test Commands

```bash
# Verify OTEL
curl http://localhost:4317/v1/traces

# Verify Prometheus
curl http://localhost:9090/api/v1/targets

# Verify Grafana
curl http://localhost:3000/api/health

# Verify Loki
curl http://localhost:3100/ready
```

---

## 15. Chaos Engineering Tests

### 15.1 Chaos Experiment Inventory

| Experiment | Blast Radius | Recovery Target | Priority |
|------------|--------------|-----------------|----------|
| Single app node stop | 1 | < 60s | P0 |
| Single app node kill | 1 | < 60s | P0 |
| Two app nodes stop | 2 | < 120s | P1 |
| Database restart | 1 | < 60s | P0 |
| Zenoh router failure | 1 | < 30s | P0 |
| Network latency 100ms | All | N/A | P1 |
| Memory pressure | 1 | N/A | P2 |
| Full cluster restart | All | < 300s | P1 |

### 15.2 Chaos Test Commands

```bash
# Run chaos tests
MIX_ENV=test mix test test/sil6/chaos/ --include chaos

# Single experiment
MIX_ENV=test mix test test/sil6/chaos/ha_mesh_chaos_test.exs:42
```

---

## 16. Regression Test Suite

### 16.1 Regression Test Categories

| Category | Tests | Frequency | Duration |
|----------|-------|-----------|----------|
| Critical Path | 100 | Every commit | 10m |
| Full Unit | 655 | Daily | 30m |
| Full Property | 315 | Daily | 20m |
| Full Integration | 250 | Daily | 45m |
| Full E2E | 100 | Weekly | 60m |
| Full Suite | 1,320 | Release | 3h |

### 16.2 Regression Commands

```bash
# Critical path (fast)
MIX_ENV=test mix test --only critical

# Full unit suite
MIX_ENV=test mix test test/indrajaal/

# Full property suite
MIX_ENV=test mix test --only property

# Full integration
MIX_ENV=test mix test --only integration

# Complete regression
MIX_ENV=test mix test
```

---

## 17. Release Verification Checklist

### 17.1 Pre-Release Checklist

```yaml
# GA Release Pre-Verification Checklist

build:
  - [ ] Elixir compiles with 0 errors, 0 warnings
  - [ ] F# compiles with 0 errors
  - [ ] All container images build successfully
  - [ ] Dialyzer passes with 0 warnings
  - [ ] Credo passes with 0 issues
  - [ ] Format check passes

tests:
  - [ ] Unit tests: 100% pass
  - [ ] Property tests: 100% pass
  - [ ] Integration tests: 95%+ pass
  - [ ] E2E tests: 90%+ pass
  - [ ] Code coverage: 95%+

security:
  - [ ] Sobelow: 0 issues
  - [ ] Dependency audit: 0 vulnerabilities
  - [ ] Secret scan: 0 exposed secrets
  - [ ] OWASP Top 10: All covered

performance:
  - [ ] p99 latency < 200ms
  - [ ] Throughput > 800 RPS
  - [ ] Error rate < 0.1%

infrastructure:
  - [ ] All 4 containers healthy (prod-standalone); 14 for full-mesh
  - [ ] HA failover verified
  - [ ] Zenoh quorum verified
  - [ ] Database migrations current

documentation:
  - [ ] API docs complete
  - [ ] Changelog updated
  - [ ] Release notes written
  - [ ] Architecture docs current
```

### 17.2 Release Day Checklist

```yaml
# Release Day Checklist

staging:
  - [ ] Deploy to staging
  - [ ] Smoke tests pass
  - [ ] UAT sign-off
  - [ ] Performance validation

production:
  - [ ] Backup current state
  - [ ] Deploy to production
  - [ ] Smoke tests pass
  - [ ] Monitor for 30 minutes
  - [ ] Rollback plan ready

post-release:
  - [ ] Monitoring alerts configured
  - [ ] On-call notified
  - [ ] Release announcement sent
  - [ ] Documentation published
```

---

## 18. Test Environment Matrix

### 18.1 Environment Specifications

| Environment | Purpose | Containers | Data | Automation |
|-------------|---------|------------|------|------------|
| Local Dev | Development | 1-3 | Mock | Manual |
| CI/CD | Automated tests | 3 | Test DB | Full |
| Staging | Pre-production | 12 | Sanitized | Full |
| Production | Live | 12+ | Real | Smoke only |

### 18.2 Environment Setup

```bash
# Local development
devenv shell
sa-db  # Start database only

# CI/CD
podman-compose -f docker-compose.ci.yml up -d

# Staging (HA)
podman-compose -f lib/cepaf/artifacts/podman-compose-ha-full-mesh.yml up -d

# Production
# Managed by deployment pipeline
```

---

## 19. Defect Triage Process

### 19.1 Severity Classification

| Severity | Definition | SLA | Example |
|----------|------------|-----|---------|
| S0 - Blocker | Release blocked | Immediate | Build failure |
| S1 - Critical | Core function broken | 4h | Auth broken |
| S2 - Major | Feature broken | 24h | API returns wrong data |
| S3 - Minor | Workaround exists | 1 week | UI glitch |
| S4 - Trivial | Cosmetic | Backlog | Typo |

### 19.2 Triage Workflow

```
New Defect → Triage (2h) → Assign → Fix → Verify → Close
                ↓
           S0/S1: Escalate immediately
           S2: Next sprint
           S3/S4: Backlog
```

---

## 20. Sign-off Criteria

### 20.1 Sign-off Matrix

| Role | Responsibility | Criteria |
|------|----------------|----------|
| QA Lead | Test completion | All gates passed |
| Dev Lead | Code quality | 0 warnings, coverage met |
| Safety Engineer | SIL-6 compliance | All safety tests passed |
| Security Officer | Security | 0 critical/high vulns |
| Architect | Architecture | Design validated |
| Product Owner | Features | UAT accepted |
| Release Manager | Release | All sign-offs received |

### 20.2 Final Sign-off Form

```
┌─────────────────────────────────────────────────────────────────────────┐
│  INDRAJAAL v21.3.0-SIL6 GA RELEASE SIGN-OFF                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Release Version:  21.3.0-SIL6                                         │
│  Release Date:     ____________________                                 │
│                                                                         │
│  QUALITY GATES                                                         │
│  ─────────────                                                         │
│  Compilation:     ☐ PASS  ☐ FAIL    Signed: ______________           │
│  Unit Tests:      ☐ PASS  ☐ FAIL    Signed: ______________           │
│  Integration:     ☐ PASS  ☐ FAIL    Signed: ______________           │
│  Security:        ☐ PASS  ☐ FAIL    Signed: ______________           │
│  Performance:     ☐ PASS  ☐ FAIL    Signed: ______________           │
│  Compliance:      ☐ PASS  ☐ FAIL    Signed: ______________           │
│                                                                         │
│  STAKEHOLDER APPROVALS                                                 │
│  ─────────────────────                                                 │
│  QA Lead:         ☐ Approved        Date: _______ Sign: ____________ │
│  Dev Lead:        ☐ Approved        Date: _______ Sign: ____________ │
│  Safety Engineer: ☐ Approved        Date: _______ Sign: ____________ │
│  Security Officer:☐ Approved        Date: _______ Sign: ____________ │
│  Architect:       ☐ Approved        Date: _______ Sign: ____________ │
│  Product Owner:   ☐ Approved        Date: _______ Sign: ____________ │
│  Release Manager: ☐ Approved        Date: _______ Sign: ____________ │
│                                                                         │
│  RELEASE DECISION                                                      │
│  ────────────────                                                      │
│  ☐ GO - Release approved                                               │
│  ☐ NO-GO - Release blocked (reason: _______________________________)  │
│                                                                         │
│  Final Authorization: _________________________ Date: _______________  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Appendices

### Appendix A: Test Commands Quick Reference

```bash
# Full test suite
devenv shell
compile-strict && quality-full && test-cover

# Specific test categories
MIX_ENV=test mix test --only unit
MIX_ENV=test mix test --only property
MIX_ENV=test mix test --only integration
MIX_ENV=test mix test --only e2e
MIX_ENV=test mix test --only sil6
MIX_ENV=test mix test --only chaos

# Coverage report
MIX_ENV=test mix test --cover --export-coverage default
mix test.coverage

# F# tests
dotnet test lib/cepaf/Cepaf.Tests/

# Security scans
mix sobelow --exit
mix deps.audit

# Performance tests
k6 run scripts/testing/load/ha_load_test.js
```

### Appendix B: Test Data Generators

```elixir
# test/support/generators.ex

defmodule Indrajaal.TestGenerators do
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  def valid_email do
    PC.let([
      local <- PC.non_empty(PC.list(PC.oneof([PC.char(?a..?z), PC.char(?0..?9)]))),
      domain <- PC.non_empty(PC.list(PC.char(?a..?z))),
      tld <- PC.oneof(["com", "org", "net", "io"])
    ]) do
      "#{local}@#{domain}.#{tld}"
    end
  end

  def valid_alarm do
    PC.let([
      severity <- PC.oneof([:low, :medium, :high, :critical]),
      sia_code <- PC.oneof(["BA", "BR", "FA", "PA", "TA"]),
      message <- PC.utf8()
    ]) do
      %{severity: severity, sia_code: sia_code, message: message}
    end
  end

  def valid_site do
    PC.let([
      name <- PC.non_empty(PC.utf8()),
      address <- PC.utf8(),
      status <- PC.oneof([:active, :inactive, :pending])
    ]) do
      %{name: name, address: address, status: status}
    end
  end
end
```

### Appendix C: CI/CD Pipeline Configuration

```yaml
# .github/workflows/ga-release.yml

name: GA Release Verification

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Nix
        uses: cachix/install-nix-action@v24
      - name: Build
        run: |
          nix develop --command bash -c "compile-strict"

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Unit Tests
        run: nix develop --command bash -c "test"
      - name: Coverage
        run: nix develop --command bash -c "test-cover"

  security:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Sobelow
        run: mix sobelow --exit
      - name: Deps Audit
        run: mix deps.audit

  integration:
    needs: [test, security]
    runs-on: ubuntu-latest
    services:
      postgres:
        image: timescale/timescaledb:latest-pg17
        ports:
          - 5433:5432
    steps:
      - name: Integration Tests
        run: MIX_ENV=test mix test --only integration

  release:
    needs: integration
    runs-on: ubuntu-latest
    steps:
      - name: Build Release
        run: MIX_ENV=prod mix release
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
```

---

**END OF GA RELEASE COMPREHENSIVE TEST PLAN**

*Document ID: TP-GA-21.3.0-001*
*Generated by Claude Sonnet 4.6 for Indrajaal v21.3.0-SIL6 GA Release*
*Total Pages: ~100*
*Total Test Cases: 3,000+*
*Coverage Target: 95%+*
