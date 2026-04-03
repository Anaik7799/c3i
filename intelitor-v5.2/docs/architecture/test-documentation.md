# Indrajaal Test Documentation

**Version**: 1.0.0
**Last Updated**: 2025-12-19
**Framework**: CAFE (Cybernetic Architect Framework for Execution)
**Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131

---

## Table of Contents

1. [Overview](#1-overview)
2. [CAFE Test Framework](#2-cafe-test-framework)
3. [Test Criticality Levels](#3-test-criticality-levels)
4. [Test Directory Structure](#4-test-directory-structure)
5. [Running Tests](#5-running-tests)
6. [Formal Verification Tests](#6-formal-verification-tests)
7. [Property-Based Testing](#7-property-based-testing)
8. [Integration Testing](#8-integration-testing)
9. [Performance Testing](#9-performance-testing)
10. [Test Factories and Fixtures](#10-test-factories-and-fixtures)
11. [Coverage Requirements](#11-coverage-requirements)
12. [CI/CD Pipeline](#12-cicd-pipeline)

---

## 1. Overview

### 1.1 Testing Philosophy

Indrajaal employs a **Test-Driven Generation (TDG)** methodology where tests are written before code implementation. This approach is enforced by the SOPv5.11 framework and STAMP safety constraints.

```
┌─────────────────────────────────────────────────────────────────┐
│                    TDG WORKFLOW                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. TEST FIRST ──────► Write tests BEFORE code                  │
│         │                                                        │
│         ▼                                                        │
│  2. AI GENERATION ───► Generate code to satisfy tests           │
│         │                                                        │
│         ▼                                                        │
│  3. VALIDATION ──────► Ensure all tests pass                    │
│         │                                                        │
│         ▼                                                        │
│  4. COMPILATION ─────► 0 errors, 0 warnings                     │
│         │                                                        │
│         ▼                                                        │
│  5. REFACTOR ────────► Improve while maintaining coverage       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Test Suite Statistics

| Metric | Value | Notes |
|--------|-------|-------|
| **Total Test Files** | 514+ | Across 6 test directories |
| **Formal Verification Tests** | 286 | Safety-critical validation |
| **Target Pass Rate** | >95% | In container environment |
| **Coverage Target** | >95% | Line coverage requirement |
| **Execution Time** | ~8 min | Full suite with parallelization |

### 1.3 Framework Components

- **SOPv5.11**: 6-Phase Execution Model
- **OODA**: Fast Loop (<100ms) Monitoring
- **TPS**: 5-Level Root Cause Analysis
- **STAMP**: Safety Constraint Validation
- **TDG**: Test-First Methodology
- **GDE**: Goal-Directed Adaptive Optimization
- **AEE**: Autonomous Tool Execution
- **PHICS**: Container Hot-Reload Integration

---

## 2. CAFE Test Framework

### 2.1 Overview

CAFE (Cybernetic Architect Framework for Execution) is the primary test execution framework that provides:

- Parallel multi-agent execution (15 agents)
- Criticality-based test sequencing
- Real-time dashboard updates
- Baseline JSON generation

### 2.2 CAFE Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAFE SUPERVISOR HIERARCHY                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 0: CAFE Executive                                        │
│      └── Framework Orchestrator                                  │
│                                                                  │
│  Layer 1: Supervisor Agents (3)                                 │
│      ├── Helper-1: OODA Controller                              │
│      │   └── Fast loop monitoring, decision synthesis           │
│      ├── Helper-2: TPS Analyzer                                 │
│      │   └── Failure analysis, root cause tracking              │
│      └── Helper-3: Dashboard Monitor                            │
│          └── Metric collection, SigNoz export                   │
│                                                                  │
│  Layer 2: Worker Agents (12)                                    │
│      ├── Workers W1-W4: C1/C2 Critical Tests                    │
│      ├── Workers W5-W8: C3 Integration Tests                    │
│      └── Workers W9-W12: C4/C5 + Metrics Collection             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Running CAFE

```bash
# Full CAFE execution with all frameworks
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
INFINITE_PATIENCE=true \
POSTGRES_USER=indrajaal \
POSTGRES_PASSWORD=indrajaal_test \
DATABASE_URL="ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test" \
MIX_ENV=test mix cafe.execute --parallel --agents=15 --dashboard

# Dry run to see test manifest
mix cafe.execute --dry-run

# Run only critical tests
mix cafe.execute --criticality c1

# Run with specific agent count
mix cafe.execute --agents=8
```

### 2.4 CAFE Options

| Option | Default | Description |
|--------|---------|-------------|
| `--parallel` | true | Enable parallel execution |
| `--agents N` | 15 | Number of worker agents |
| `--dashboard` | true | Enable dashboard output |
| `--baseline` | true | Generate baseline JSON |
| `--criticality LEVEL` | all | Filter by criticality (c1-c5) |
| `--dry-run` | false | Show manifest without executing |

### 2.5 CAFE Output

```
╔═══════════════════════════════════════════════════════════════════╗
║                    CAFE EXECUTION RESULTS                          ║
╠═══════════════════════════════════════════════════════════════════╣
║  Total Tests:        514                                           ║
║  Passed:              81 ✓                                         ║
║  Failed:             432 ✗                                         ║
║  Errors:               0                                           ║
║  Timeouts:             1                                           ║
║  Pass Rate:        15.76%                                          ║
║  Execution Time:     7.8m                                          ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## 3. Test Criticality Levels

### 3.1 Criticality Classification

| Level | ID Range | Tests | Batch Size | Priority | Timeout |
|-------|----------|-------|------------|----------|---------|
| **C1-CRITICAL** | 001-100 | ~41 | 5 | 1 (First) | 5 min |
| **C2-HIGH** | 101-250 | ~150 | 10 | 2 | 3 min |
| **C3-MEDIUM** | 251-450 | ~200 | 20 | 3 | 2 min |
| **C4-LOW** | 451-600 | ~150 | 30 | 4 | 1 min |
| **C5-OPTIONAL** | 601+ | ~60 | 50 | 5 (Last) | 30 sec |

### 3.2 C1 Critical Tests (Formal Verification)

These tests validate safety-critical properties per IEC 61508 SIL-2:

```
001 compliance/sil_compliance_test.exs          # IEC 61508 SIL-2
002 validation/fpps_consensus_test.exs          # EP-110 Prevention
003 devices/device_failsafe_test.exs            # EN 50131
004 safety/fmea_hazard_analysis_test.exs        # IEC 60812
005 authentication/auth_security_test.exs       # SC-SEC-*
006 access_control/rbac_state_machine_test.exs  # SC-AGT-018
007 communication/safety_critical_comm_test.exs # LTL Properties
008 cluster/quorum_sentinel_test.exs            # SC-CLU-*
```

### 3.3 C2 High Priority Tests

Security and accounts domain tests:

- Authentication tests (MFA, JWT, SSO)
- Authorization tests (RBAC, permissions)
- Access control tests (anti-passback, time fencing)
- Session security tests

### 3.4 C3 Medium Priority Tests

Integration and API tests:

- API endpoint tests
- Communication domain tests
- Observability integration tests
- Container TDG compliance tests

### 3.5 C4 Low Priority Tests

Demo and performance tests:

- Demo execution tests
- Performance baseline tests
- Load testing scenarios

### 3.6 C5 Optional Tests

General domain tests:

- Analytics tests
- Sites tests
- Visitor management tests
- Utility helper tests

---

## 4. Test Directory Structure

```
test/
├── indrajaal/                    # Core domain tests
│   ├── access_control/           # RBAC, permissions, anti-passback
│   ├── accounts/                 # User, team, tenant tests
│   ├── alarms/                   # Alarm processing, lifecycle
│   ├── analytics/                # Reports, dashboards, ML
│   ├── authentication/           # MFA, JWT, SSO
│   ├── authorization/            # Policy engine, permissions
│   ├── cluster/                  # Quorum, sentinel, distributed
│   ├── communication/            # Safety-critical messaging
│   ├── compliance/               # SIL, ISO, GDPR
│   ├── cortex/                   # Homeostasis, sensors
│   ├── devices/                  # Failsafe, hardware
│   ├── observability/            # Telemetry, tracing
│   ├── safety/                   # FMEA, hazard analysis
│   └── validation/               # FPPS, consensus
│
├── demo/                         # Demo script tests
│   ├── *_enterprise_demo_test.exs
│   └── *_comprehensive_coverage_test.exs
│
├── integration/                  # Full-stack integration
│   ├── api_comprehensive_coverage_test.exs
│   └── real_time_comprehensive_coverage_test.exs
│
├── advanced/                     # Advanced scenarios
│   ├── *_domain_signoz_test.exs
│   └── stamp_tdg_gde_advanced_testing.exs
│
├── containers/                   # Container compliance
│   ├── tdg_compliance/           # TDG methodology tests
│   └── stamp_safety_test.exs
│
├── security_intelligence/        # ML threat detection
│   ├── behavioral_analytics_test.exs
│   └── ml_threat_detection_test.exs
│
└── support/                      # Test helpers
    ├── data_case.ex              # Database test case
    ├── conn_case.ex              # Connection test case
    ├── factory.ex                # Test factories
    └── fixtures/                 # Domain fixtures
```

---

## 5. Running Tests

### 5.1 Standard Test Execution

```bash
# Run all tests
MIX_ENV=test mix test

# Run with Patient Mode (recommended)
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
INFINITE_PATIENCE=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
MIX_ENV=test mix test

# Run specific test file
MIX_ENV=test mix test test/indrajaal/accounts/user_test.exs

# Run specific test line
MIX_ENV=test mix test test/indrajaal/accounts/user_test.exs:42

# Run tests matching pattern
MIX_ENV=test mix test --only tag:critical
```

### 5.2 Database Configuration

```bash
# Set database environment
export POSTGRES_USER=indrajaal
export POSTGRES_PASSWORD=indrajaal_test
export DATABASE_URL="ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test"

# Reset test database
MIX_ENV=test mix ecto.reset

# Run migrations
MIX_ENV=test mix ecto.migrate
```

### 5.3 Parallel Test Execution

```bash
# Run with 4 parallel partitions
MIX_ENV=test mix test --partitions 4

# Run specific partition
MIX_ENV=test mix test --partitions 4 --partition 1
```

### 5.4 Test Tags

```elixir
# In test file
@moduletag :critical
@moduletag :integration
@tag :slow

# Run with tags
mix test --only critical
mix test --exclude slow
mix test --include integration
```

---

## 6. Formal Verification Tests

### 6.1 Three-Layer Verification Pyramid

```
┌─────────────────────────────────────────────────────────────────┐
│                    VERIFICATION PYRAMID                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 3: Agda                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Purpose: Eternal Constructive Proofs                    │    │
│  │ Scope: Core Invariants                                  │    │
│  │ Guarantee: ∀ executions (infinite)                      │    │
│  │ Files: docs/formal_specs/agda_proofs.agda              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 2: Quint                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Purpose: Bounded State Exploration                      │    │
│  │ Scope: State Machines + LTL                            │    │
│  │ Guarantee: Up to N steps (model checking)              │    │
│  │ Files: docs/formal_specs/quint_specifications.qnt      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Layer 1: ExUnit (Runtime)                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Purpose: Runtime Validation                             │    │
│  │ Scope: STAMP/FMEA/Temporal                             │    │
│  │ Guarantee: Empirical coverage                          │    │
│  │ Files: test/indrajaal/**/*_test.exs                    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 STAMP Safety Constraint Tests

```elixir
# test/indrajaal/compliance/sil_compliance_test.exs
defmodule Indrajaal.Compliance.SILComplianceTest do
  use ExUnit.Case, async: false

  @moduletag :critical
  @moduletag :stamp

  describe "SC-VAL-001: Patient Mode Compilation" do
    test "compilation uses patient mode environment" do
      assert System.get_env("PATIENT_MODE") == "enabled"
      assert System.get_env("NO_TIMEOUT") == "true"
    end
  end

  describe "SC-VAL-003: FPPS Consensus" do
    test "all 5 validation methods must agree" do
      results = run_fpps_validation()
      assert consensus_achieved?(results)
    end
  end

  describe "SC-CNT-009: Container Execution" do
    test "runtime is Podman in container" do
      assert container_runtime() == :podman
    end
  end
end
```

### 6.3 FMEA Hazard Analysis Tests

```elixir
# test/indrajaal/safety/fmea_hazard_analysis_test.exs
defmodule Indrajaal.Safety.FMEAHazardAnalysisTest do
  use ExUnit.Case, async: false

  @moduletag :critical
  @moduletag :fmea

  describe "Power Failure Hazards (PFH-FMEA-*)" do
    test "UPS backup activates within threshold" do
      # RPN = 40 (Severity: 10, Occurrence: 2, Detection: 2)
      assert backup_activation_time_ms() < 500
    end

    test "battery monitoring detects low state" do
      # RPN = 48 (Severity: 8, Occurrence: 2, Detection: 3)
      assert battery_monitoring_active?()
      assert alert_threshold_configured?()
    end
  end

  describe "Tamper Detection Hazards (TDH-FMEA-*)" do
    test "tamper switch bypass prevention" do
      # RPN = 108 (CRITICAL - requires mitigation)
      assert end_of_line_resistors_configured?()
      assert cable_cut_detection_enabled?()
    end
  end
end
```

### 6.4 LTL Temporal Property Tests

```elixir
# test/indrajaal/communication/safety_critical_comm_test.exs
defmodule Indrajaal.Communication.SafetyCriticalCommTest do
  use ExUnit.Case, async: false

  @moduletag :critical
  @moduletag :ltl

  describe "LTL-ALARM-001: Alarm Delivery Liveness" do
    # □[AlarmGenerated ⟹ ◇AlarmDelivered]
    test "generated alarms are eventually delivered" do
      alarm = generate_test_alarm()

      # Wait for delivery with timeout
      assert eventually_delivered?(alarm, timeout: 30_000)
    end
  end

  describe "LTL-ACK-001: Acknowledgment Liveness" do
    # □[AlarmDelivered ⟹ ◇(Acknowledged ∨ Escalated)]
    test "delivered alarms are acknowledged or escalated" do
      alarm = deliver_test_alarm()

      assert eventually_acknowledged_or_escalated?(alarm)
    end
  end
end
```

### 6.5 Running Formal Verification Tests

```bash
# Run all formal verification tests
MIX_ENV=test mix test \
  test/indrajaal/compliance/sil_compliance_test.exs \
  test/indrajaal/validation/fpps_consensus_test.exs \
  test/indrajaal/devices/device_failsafe_test.exs \
  test/indrajaal/safety/fmea_hazard_analysis_test.exs \
  test/indrajaal/authentication/auth_security_test.exs \
  test/indrajaal/access_control/rbac_state_machine_test.exs \
  test/indrajaal/communication/safety_critical_comm_test.exs \
  test/indrajaal/cluster/quorum_sentinel_test.exs

# Run with STAMP tag
MIX_ENV=test mix test --only stamp

# Run with FMEA tag
MIX_ENV=test mix test --only fmea
```

---

## 7. Property-Based Testing

### 7.1 Dual Library Approach

Indrajaal uses both PropCheck and StreamData for property-based testing:

```elixir
# Using PropCheck
defmodule Indrajaal.Accounts.UserPropertyTest do
  use ExUnit.Case
  use PropCheck

  property "email normalization is idempotent" do
    forall email <- email_generator() do
      normalized = normalize_email(email)
      normalize_email(normalized) == normalized
    end
  end

  def email_generator do
    let {local, domain} <- {non_empty_string(), domain_generator()} do
      "#{local}@#{domain}"
    end
  end
end

# Using StreamData
defmodule Indrajaal.Alarms.AlarmPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "alarm priority is always valid" do
    check all priority <- StreamData.member_of([:critical, :high, :medium, :low]) do
      assert valid_priority?(priority)
    end
  end

  property "alarm timestamps are monotonically increasing" do
    check all alarms <- StreamData.list_of(alarm_generator(), min_length: 2) do
      timestamps = Enum.map(alarms, & &1.inserted_at)
      assert Enum.sort(timestamps) == timestamps
    end
  end
end
```

### 7.2 Property Test Categories

| Category | Purpose | Libraries |
|----------|---------|-----------|
| **Domain Invariants** | Business rule validation | PropCheck |
| **State Machines** | Transition correctness | PropCheck.FSM |
| **Data Generation** | Input validation | StreamData |
| **Concurrency** | Race condition detection | PropCheck |

### 7.3 Running Property Tests

```bash
# Run all property tests
MIX_ENV=test mix test --only property

# Run with increased iterations
PROPCHECK_NUMTESTS=1000 MIX_ENV=test mix test --only property

# Clean PropCheck cache
MIX_ENV=test mix propcheck.clean
```

---

## 8. Integration Testing

### 8.1 API Integration Tests

```elixir
# test/indrajaal/api_integration_test.exs
defmodule Indrajaal.APIIntegrationTest do
  use IndrajaalWeb.ConnCase, async: false

  @moduletag :integration

  setup %{conn: conn} do
    # Authenticate and get token
    {:ok, token} = authenticate_user(@valid_credentials)
    conn = put_req_header(conn, "authorization", "Bearer #{token}")
    {:ok, conn: conn}
  end

  describe "Alarm workflow integration" do
    test "complete alarm lifecycle", %{conn: conn} do
      # Create alarm
      conn = post(conn, "/api/v1/alarms", alarm_params())
      assert %{"id" => alarm_id} = json_response(conn, 201)

      # Verify alarm exists
      conn = get(conn, "/api/v1/alarms/#{alarm_id}")
      assert json_response(conn, 200)["status"] == "active"

      # Acknowledge alarm
      conn = post(conn, "/api/v1/alarms/#{alarm_id}/acknowledge")
      assert json_response(conn, 200)["status"] == "acknowledged"

      # Resolve alarm
      conn = post(conn, "/api/v1/alarms/#{alarm_id}/resolve")
      assert json_response(conn, 200)["status"] == "resolved"
    end
  end
end
```

### 8.2 Database Integration Tests

```elixir
# test/support/data_case.ex
defmodule Indrajaal.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Indrajaal.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Indrajaal.DataCase
      import Indrajaal.Factory
    end
  end

  setup tags do
    Indrajaal.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Indrajaal.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
```

### 8.3 LiveView Integration Tests

```elixir
# test/indrajaal_web/live/monitoring_dashboard_live_test.exs
defmodule IndrajaalWeb.MonitoringDashboardLiveTest do
  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :liveview

  describe "Real-time alarm updates" do
    test "displays new alarms in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/monitoring")

      # Simulate alarm broadcast
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "alarms:updates",
        {:new_alarm, test_alarm()}
      )

      # Verify alarm appears
      assert render(view) =~ "New Alarm"
    end
  end
end
```

---

## 9. Performance Testing

### 9.1 Load Testing with Artillery

```yaml
# scripts/performance/artillery-config.yml
config:
  target: "http://localhost:4001"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
    - duration: 60
      arrivalRate: 100
      name: "Spike test"
  defaults:
    headers:
      Authorization: "Bearer {{ $processEnvironment.TEST_TOKEN }}"

scenarios:
  - name: "Alarm retrieval"
    flow:
      - get:
          url: "/api/v1/alarms"
          expect:
            - statusCode: 200

  - name: "Access grant verification"
    flow:
      - post:
          url: "/api/v1/access/verify"
          json:
            card_number: "{{ $randomString(10) }}"
          expect:
            - statusCode: 200
```

### 9.2 Running Performance Tests

```bash
# Run Artillery load test
artillery run scripts/performance/artillery-config.yml

# Run soak test (extended duration)
artillery run scripts/performance/artillery-soak-config.yml

# Run spike test
artillery run scripts/performance/artillery-spike-config.yml
```

### 9.3 Benchmarking with Benchee

```elixir
# benchmarks/alarm_processing_bench.exs
Benchee.run(%{
  "single alarm" => fn ->
    Indrajaal.Alarms.process_alarm(test_alarm())
  end,
  "batch alarms" => fn ->
    Indrajaal.Alarms.process_batch(test_alarms(100))
  end
}, parallel: 4, time: 10)
```

### 9.4 Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| API Response Time (p95) | <100ms | Standard endpoints |
| API Response Time (p99) | <500ms | Complex queries |
| Alarm Processing | <50ms | End-to-end |
| WebSocket Latency | <20ms | Real-time updates |
| Concurrent Users | 100+ | Without degradation |

---

## 10. Test Factories and Fixtures

### 10.1 Factory Pattern

```elixir
# test/support/factory.ex
defmodule Indrajaal.Factory do
  use ExMachina.Ecto, repo: Indrajaal.Repo

  def tenant_factory do
    %Indrajaal.Accounts.Tenant{
      name: sequence(:name, &"Tenant #{&1}"),
      subdomain: sequence(:subdomain, &"tenant#{&1}"),
      status: :active
    }
  end

  def user_factory do
    %Indrajaal.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      first_name: "Test",
      last_name: "User",
      tenant: build(:tenant),
      role: :operator
    }
  end

  def alarm_factory do
    %Indrajaal.Alarms.Alarm{
      code: sequence(:code, &"ALM#{&1}"),
      priority: :high,
      status: :active,
      source_type: "motion_detector",
      tenant: build(:tenant)
    }
  end

  def access_grant_factory do
    %Indrajaal.AccessControl.AccessGrant{
      card_number: sequence(:card, &"CARD#{String.pad_leading(to_string(&1), 8, "0")}"),
      holder_name: "Test Holder",
      valid_from: DateTime.utc_now(),
      valid_until: DateTime.add(DateTime.utc_now(), 365, :day),
      tenant: build(:tenant)
    }
  end
end
```

### 10.2 Using Factories

```elixir
# In tests
defmodule Indrajaal.Alarms.AlarmTest do
  use Indrajaal.DataCase
  import Indrajaal.Factory

  test "creates alarm with valid attributes" do
    tenant = insert(:tenant)
    alarm = insert(:alarm, tenant: tenant, priority: :critical)

    assert alarm.priority == :critical
    assert alarm.tenant_id == tenant.id
  end

  test "builds alarm without persisting" do
    alarm = build(:alarm)
    assert alarm.id == nil
  end

  test "creates multiple alarms" do
    alarms = insert_list(10, :alarm)
    assert length(alarms) == 10
  end
end
```

### 10.3 Fixtures Pattern

```elixir
# test/support/fixtures/accounts_fixtures.ex
defmodule Indrajaal.AccountsFixtures do
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: "user#{System.unique_integer()}@example.com",
      password: "ValidPassword123!",
      first_name: "Test",
      last_name: "User"
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Indrajaal.Accounts.create_user()

    user
  end
end
```

---

## 11. Coverage Requirements

### 11.1 Coverage Configuration

```elixir
# mix.exs
def project do
  [
    ...
    test_coverage: [
      tool: ExCoveralls,
      minimum_coverage: 95.0,
      ignore_modules: [
        ~r/^Indrajaal\.Release/,
        ~r/^IndrajaalWeb\..*View$/
      ]
    ],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.html": :test
    ]
  ]
end
```

### 11.2 Running Coverage

```bash
# Generate coverage report
MIX_ENV=test mix coveralls

# Generate HTML report
MIX_ENV=test mix coveralls.html

# Generate detailed report
MIX_ENV=test mix coveralls.detail

# Check coverage threshold
MIX_ENV=test mix coveralls --check-coverage
```

### 11.3 Coverage Targets by Domain

| Domain | Target | Notes |
|--------|--------|-------|
| **Core Business Logic** | 98% | Alarms, Access Control |
| **Authentication** | 95% | Security-critical |
| **API Controllers** | 90% | Public interfaces |
| **LiveView** | 85% | UI components |
| **Utilities** | 80% | Helper functions |

---

## 12. CI/CD Pipeline

### 12.1 GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: timescale/timescaledb:latest-pg17
        ports:
          - 5433:5432
        env:
          POSTGRES_USER: indrajaal
          POSTGRES_PASSWORD: indrajaal_test
          POSTGRES_DB: indrajaal_test

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.19'
          otp-version: '28'

      - name: Install Dependencies
        run: mix deps.get

      - name: Compile
        run: mix compile --warnings-as-errors
        env:
          MIX_ENV: test

      - name: Run Tests
        run: mix test
        env:
          MIX_ENV: test
          POSTGRES_USER: indrajaal
          POSTGRES_PASSWORD: indrajaal_test
          DATABASE_URL: ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test

      - name: Check Coverage
        run: mix coveralls.github
        env:
          MIX_ENV: test
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 12.2 Formal Verification Pipeline

```yaml
# .github/workflows/formal-verification.yml
name: Formal Verification

on:
  push:
    branches: [main]
  release:
    types: [created]

jobs:
  verify:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Gate 1: Specification Validity
      - name: G1 - Parse Quint Specs
        run: quint parse docs/formal_specs/quint_specifications.qnt

      # Gate 2: Proof Verification
      - name: G2 - Verify Agda Proofs
        run: agda --safe docs/formal_specs/agda_proofs.agda

      # Gate 3: Property Verification
      - name: G3 - Model Check Properties
        run: quint verify --invariant=masterInvariant --max-steps=100

      # Gate 4: Safety Analysis
      - name: G4 - Run Safety Tests
        run: |
          MIX_ENV=test mix test \
            test/indrajaal/compliance/sil_compliance_test.exs \
            test/indrajaal/validation/fpps_consensus_test.exs \
            test/indrajaal/safety/fmea_hazard_analysis_test.exs
```

### 12.3 Pre-commit Hooks

```bash
# .git/hooks/pre-commit
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Format check
mix format --check-formatted

# Compile with warnings as errors
MIX_ENV=test mix compile --warnings-as-errors

# Run fast tests
MIX_ENV=test mix test --only unit --max-failures 1

echo "Pre-commit checks passed!"
```

---

## Appendix A: Test Command Reference

### Quick Reference

```bash
# Standard test execution
MIX_ENV=test mix test

# Run with Patient Mode
NO_TIMEOUT=true PATIENT_MODE=enabled MIX_ENV=test mix test

# Run CAFE framework
MIX_ENV=test mix cafe.execute

# Run specific criticality
MIX_ENV=test mix cafe.execute --criticality c1

# Run formal verification tests only
MIX_ENV=test mix test --only stamp --only fmea --only ltl

# Generate coverage report
MIX_ENV=test mix coveralls.html

# Run property tests
MIX_ENV=test mix test --only property

# Run integration tests
MIX_ENV=test mix test --only integration

# Performance baseline
artillery run scripts/performance/artillery-config.yml
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MIX_ENV` | Environment | `test` |
| `POSTGRES_USER` | Database user | `indrajaal` |
| `POSTGRES_PASSWORD` | Database password | `indrajaal_test` |
| `DATABASE_URL` | Full connection URL | `ecto://...` |
| `NO_TIMEOUT` | Disable timeouts | `true` |
| `PATIENT_MODE` | Enable patient mode | `enabled` |
| `PROPCHECK_NUMTESTS` | Property test iterations | `1000` |

---

## Appendix B: STAMP Constraint Coverage

| Constraint | Test File | Status |
|------------|-----------|--------|
| SC-VAL-001 | sil_compliance_test.exs | Covered |
| SC-VAL-003 | fpps_consensus_test.exs | Covered |
| SC-CNT-009 | stamp_safety_test.exs | Covered |
| SC-AGT-018 | rbac_state_machine_test.exs | Covered |
| SC-CLU-001 | quorum_sentinel_test.exs | Covered |
| SC-SEC-001 | auth_security_test.exs | Covered |
| SC-DEV-001 | device_failsafe_test.exs | Covered |
| SC-FMEA-001 | fmea_hazard_analysis_test.exs | Covered |

---

**Document Maintained By**: Claude Code (Opus 4.5)
**Framework**: SOPv5.11 + CAFE + STAMP + TDG
**Compliance**: IEC 61508 SIL-2, ISO 27001, GDPR, EN 50131
