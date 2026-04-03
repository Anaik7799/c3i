# 2026-01-17T10:00:00Z - F# Comprehensive Test Plan

## Context
- **Branch**: main
- **Version**: 21.3.0-SIL6
- **Scope**: 30 F# Projects | 520+ Source Files | 3 UI Interfaces | 40+ Integration Points
- **Target**: 100% Runtime Coverage with ALL Elixir + F# Services Running

## Summary

Comprehensive test plan for the entire F# codebase including CEPAF, Cockpit (TUI/GUI/WebUI), and all system interactions across 10 fractal verification layers with 100% runtime coverage.

---

## LEVEL 1: Executive Overview

### 1.1 Test Architecture

| Level | Name | Scope | Target Coverage |
|-------|------|-------|-----------------|
| **L1** | Unit | Individual functions | 100% |
| **L2** | Module | Module interactions | 100% |
| **L3** | Component | UI components | 100% |
| **L4** | Integration | F#↔F# services | 100% |
| **L5** | Bridge | F#↔Elixir | 100% |
| **L6** | System | Full stack | 100% |
| **L7** | Chaos | Failure injection | 80% |
| **L8** | Performance | Load/stress | 100% SLA |
| **L9** | Security | Penetration | 100% |
| **L10** | Compliance | SIL-6 + STAMP | 600/600 |

### 1.2 Interface Coverage

| Feature | TUI | GUI | WebUI | Backend |
|---------|-----|-----|-------|---------|
| Dashboard | ✓ | ✓ | ✓ | Health API |
| Alarms | ✓ | ✓ | ✓ | Alarm API |
| Guardian | ✓ | ✓ | ✓ | Guardian API |
| Sentinel | ✓ | ✓ | ✓ | Sentinel API |
| Devices | - | ✓ | ✓ | Device API |
| AI Copilot | ✓ | ✓ | ✓ | Copilot API |

### 1.3 Success Criteria

- All unit tests pass (0 failures)
- Code coverage ≥95%
- STAMP constraints verified: 600/600
- E2E scenarios pass: 50/50
- Performance SLAs met: 100%
- Security vulnerabilities: 0 critical/high

---

## LEVEL 2: Project Inventory

### 2.1 Tier 1: Core Orchestration (175+ files)

| Project | Files | Purpose | Test Priority |
|---------|-------|---------|---------------|
| Cepaf | 175 | Main orchestrator | P0 |
| Cepaf.Cockpit | 68 | Safety cockpit | P0 |
| Cepaf.Bridge | 8 | Elixir bridge | P0 |

### 2.2 Tier 2: UI Implementations (54+ files)

| Project | Files | Framework | Test Priority |
|---------|-------|-----------|---------------|
| Cepaf.Cockpit.Web | 23 | Bolero/Blazor | P0 |
| Cepaf.Cockpit.Avalonia | 31 | Fabulous/Avalonia | P1 |

### 2.3 Tier 3: Infrastructure (21+ files)

| Project | Files | Purpose | Test Priority |
|---------|-------|---------|---------------|
| Cepaf.Podman | 21 | Container mgmt | P1 |
| Cepaf.Zenoh | 12 | Mesh telemetry | P0 |

### 2.4 Tier 4: Knowledge (41+ files)

| Project | Files | Purpose | Test Priority |
|---------|-------|---------|---------------|
| Cepaf.Smriti | 25 | Knowledge graph | P1 |
| Cepaf.Smriti.Semantic | 10 | Vector search | P1 |
| Cepaf.Smriti.API | 6 | REST handlers | P1 |

### 2.5 Tier 5: AI Layer (29+ files)

| Project | Files | Purpose | Test Priority |
|---------|-------|---------|---------------|
| Cepaf.Planning | 21 | Task management | P1 |
| Indrajaal.Cortex | 8 | AI cognitive | P2 |

---

## LEVEL 3: Test Specifications

### 3.1 Unit Tests (900+ tests)

#### Cepaf.Cockpit (200 tests)
```
Domain/
├── Model.fs          # 25 tests: State transitions, defaults
├── Messages.fs       # 20 tests: Message routing, validation
├── Types.fs          # 15 tests: Type construction, equality
└── Services/         # 40 tests: Service logic

AI/
├── AiCopilot.fs      # 30 tests: AI reasoning, prompts
└── AiFounder.fs      # 20 tests: Directive compliance

Verification/
├── SmartMetrics.fs   # 25 tests: Metric calculations
└── SignalArrows.fs   # 25 tests: Reactive operators
```

#### Cepaf.Cockpit.Web (150 tests)
```
Components/
├── HealthGauge.fs    # 20 tests: Gauge rendering
├── AlarmCard.fs      # 15 tests: Card states
├── ProposalCard.fs   # 15 tests: Approval flow
├── ThreatCard.fs     # 15 tests: Threat display
└── DeviceCard.fs     # 15 tests: Device status

Pages/
├── Dashboard.fs      # 20 tests: Dashboard load
├── Alarms.fs         # 15 tests: Alarm filtering
├── Guardian.fs       # 15 tests: Proposal workflow
├── Sentinel.fs       # 10 tests: Threat management
└── Devices.fs        # 10 tests: Device grid
```

#### Cepaf.Cockpit.Avalonia (100 tests)
```
Views/
├── DashboardView.fs  # 25 tests: View rendering
├── AlarmsView.fs     # 20 tests: List behavior
├── GuardianView.fs   # 20 tests: Approval UI
├── SentinelView.fs   # 20 tests: Threat UI
└── DevicesView.fs    # 15 tests: Device grid
```

### 3.2 Integration Tests (325+ tests)

#### F#↔Elixir HTTP Bridge (100 tests)
```fsharp
// ElixirBridgeTests.fs
[<Tests>]
let healthApiTests = testList "Health API" [
    test "GET /api/health returns 200" { ... }
    test "Health endpoint timeout handling" { ... }
    test "Health endpoint retry on failure" { ... }
]

[<Tests>]
let guardianApiTests = testList "Guardian API" [
    test "POST /api/prajna/guardian/submit approval" { ... }
    test "POST /api/prajna/guardian/submit veto" { ... }
    test "Guardian constitutional check" { ... }
]

[<Tests>]
let sentinelApiTests = testList "Sentinel API" [
    test "POST /api/prajna/sentinel/health sync" { ... }
    test "Sentinel threat detection" { ... }
]
```

#### Zenoh Mesh Integration (75 tests)
```fsharp
// ZenohMeshTests.fs
[<Tests>]
let pubsubTests = testList "Zenoh Pub/Sub" [
    test "Subscribe to indrajaal/fractal/l1..l7/**" { ... }
    test "Publish to prajna/metrics/smart" { ... }
    test "Real-time alarm delivery" { ... }
    test "10s heartbeat timing" { ... }
]
```

#### Cross-Interface Consistency (50 tests)
```fsharp
// CrossInterfaceTests.fs
[<Tests>]
let consistencyTests = testList "Cross-Interface" [
    test "Health score matches TUI/GUI/WebUI" { ... }
    test "Alarm list ordering consistent" { ... }
    test "Proposal status syncs within 1s" { ... }
    test "Connection status unified" { ... }
]
```

### 3.3 E2E Scenarios (50 user journeys)

#### Dashboard Journey (10)
1. Initial load with all metrics
2. Health score degradation alert
3. Metric trend changes
4. Stale data visual decay
5. Connection loss/reconnect
6. Theme switching
7. Refresh rate changes
8. Multi-user concurrent view
9. Browser tab switch/return
10. Session timeout/refresh

#### Alarm Management (10)
1. New alarm notification
2. Alarm acknowledgment flow
3. Alarm storm detection
4. Filter by severity
5. Search by node/zone
6. Escalation timeout
7. Bulk acknowledgment
8. Historical view
9. Correlation display
10. Sound/visual toggle

#### Guardian Approval (10)
1. Proposal submission
2. Approval with reason
3. Veto with reason
4. Constitutional failure
5. Founder alignment
6. Multi-voter quorum
7. Proposal timeout
8. Emergency override
9. Audit trail
10. Rollback after approval

#### Sentinel Threat (10)
1. New threat detection
2. RPN score display
3. Mitigation trigger
4. Escalation path
5. Pattern Hunter detection
6. Symbiotic Defense
7. False positive marking
8. History query
9. Active dashboard
10. Trend analysis

#### Device Management (10)
1. Device discovery
2. Health matrix
3. Offline detection
4. Reconnection
5. Metric drilling
6. Batch operations
7. Firmware tracking
8. Zone filtering
9. Topology view
10. Device comparison

---

## LEVEL 4: Technical Implementation

### 4.1 Test Project Structure

```
lib/cepaf/tests/
├── Cepaf.Tests/                      # Existing (28 files)
├── Cepaf.IndrajaalTest/              # Existing (25 files)
├── Cepaf.Podman.Tests/               # Existing (8 files)
├── Cepaf.Zenoh.Tests/                # Existing (12 files)
├── Cepaf.Planning.Tests/             # Existing (1 file)
├── Cepaf.Smriti.Semantic.Tests/      # Existing (7 files)
│
├── Cepaf.Cockpit.Tests/              # NEW
│   ├── Cepaf.Cockpit.Tests.fsproj
│   ├── DarkCockpitUITests.fs
│   ├── SmartMetricTests.fs
│   ├── SignalArrowsTests.fs
│   └── ZenohIntegrationTests.fs
│
├── Cepaf.Cockpit.Web.Tests/          # NEW
│   ├── Cepaf.Cockpit.Web.Tests.fsproj
│   ├── ComponentTests.fs
│   ├── PageTests.fs
│   ├── ServiceTests.fs
│   └── E2ETests.fs
│
├── Cepaf.Cockpit.Avalonia.Tests/     # NEW
│   ├── Cepaf.Cockpit.Avalonia.Tests.fsproj
│   ├── ViewTests.fs
│   ├── ThemeTests.fs
│   └── HeadlessTests.fs
│
└── Cepaf.Integration/                # NEW
    ├── Cepaf.Integration.fsproj
    ├── ElixirBridgeTests.fs
    ├── ZenohMeshTests.fs
    ├── GuardianFlowTests.fs
    ├── SentinelSyncTests.fs
    └── CrossInterfaceTests.fs
```

### 4.2 Test Project Configuration

```xml
<!-- Cepaf.Cockpit.Tests.fsproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Expecto" Version="10.*" />
    <PackageReference Include="Expecto.FsCheck" Version="10.*" />
    <PackageReference Include="FsCheck" Version="3.*" />
    <PackageReference Include="Unquote" Version="7.*" />
    <PackageReference Include="Foq" Version="2.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\src\Cepaf.Cockpit\Cepaf.Cockpit.fsproj" />
  </ItemGroup>
</Project>
```

### 4.3 Required Services (Infrastructure)

```yaml
# All services must be running for integration tests
services:
  # Elixir Stack
  indrajaal-app-prod:
    ports: [4000]
    healthcheck: /api/health

  indrajaal-db-prod:
    ports: [5433]
    image: postgres:17

  indrajaal-obs-prod:
    ports: [4317, 9090, 3000, 3100]

  # Zenoh Mesh
  zenoh-router-1:
    ports: [7447]
  zenoh-router-2:
    ports: [7448]
  zenoh-router-3:
    ports: [7449]

  # F# Services
  cepaf-bridge:
    ports: [9876]
  indrajaal-cortex:
    ports: [9877]
```

### 4.4 Test Execution Commands

```bash
# Phase 1: Unit Tests (Parallel)
dotnet test lib/cepaf/tests/Cepaf.Tests/
dotnet test lib/cepaf/tests/Cepaf.Cockpit.Tests/
dotnet test lib/cepaf/tests/Cepaf.Cockpit.Web.Tests/
dotnet test lib/cepaf/tests/Cepaf.Cockpit.Avalonia.Tests/

# Phase 2: Integration Tests (Sequential - requires infrastructure)
devenv shell
sa-up
dotnet test lib/cepaf/tests/Cepaf.Integration/

# Phase 3: E2E Tests
dotnet run --project lib/cepaf/tests/Cepaf.IndrajaalTest/ -- --all

# Full Suite with Coverage
dotnet test lib/cepaf/tests/ /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
```

---

## LEVEL 5: STAMP Constraints & Compliance

### 5.1 Critical Constraints (P0)

| ID | Constraint | Test Type | Automation |
|----|------------|-----------|------------|
| SC-PRAJNA-001 | Guardian pre-approval | Integration | GuardianFlowTests |
| SC-BRIDGE-001 | FIFO message ordering | Unit | ZenohMeshTests |
| SC-PRF-050 | <50ms latency | Performance | BenchmarkDotNet |
| SC-IMMUNE-001 | Sentinel monitoring | Integration | SentinelSyncTests |
| SC-REG-001 | Append-only register | Unit | RegisterTests |
| SC-FOUNDER-004 | Ω₀ enforcement | Integration | ConstitutionalTests |

### 5.2 Constraint Coverage by Category

| Range | Count | Test File |
|-------|-------|-----------|
| SC-HMI-* | 11 | UIAutomationTests.fs |
| SC-ZENOH-* | 15 | ZenohMeshTests.fs |
| SC-SYNC-* | 9 | CrossInterfaceTests.fs |
| SC-CTRL-* | 7 | ControlTests.fs |
| SC-MON-* | 6 | ObservabilityTests.fs |
| SC-COV-* | 8 | CoverageTests.fs |
| SC-TEST-* | 10 | TestFrameworkTests.fs |

### 5.3 Performance SLAs

| Operation | Target | Max | Test |
|-----------|--------|-----|------|
| UI render | <16ms | 33ms | FrameTimingBenchmark |
| API call | <50ms | 100ms | HttpLatencyBenchmark |
| Zenoh msg | <10ms | 50ms | PubSubLatencyBenchmark |
| DB query | <5ms | 20ms | SqliteLatencyBenchmark |

### 5.4 Security Tests

| Vector | Test | Tool |
|--------|------|------|
| SQL Injection | Malformed queries | Custom |
| XSS | Script injection | OWASP ZAP |
| CSRF | Cross-site requests | Manual |
| Auth bypass | Token manipulation | Custom |

### 5.5 Constitutional Invariants (Ψ₀-Ψ₅)

| Invariant | Test | Validation |
|-----------|------|------------|
| Ψ₀ Existence | Self-termination prevention | Cannot delete core |
| Ψ₁ Regeneration | State restore from SQLite | Full restore |
| Ψ₂ History | DuckDB append-only | No deletions |
| Ψ₃ Verification | Hash chain integrity | Chain validates |
| Ψ₄ Human Alignment | Founder Directive check | Ω₀ enforced |
| Ψ₅ Truthfulness | Audit trail accuracy | No tampering |

---

## Implementation Phases

### Phase 1: Test Infrastructure (Week 1)
- [ ] Create new test project structure
- [ ] Configure Expecto + FsCheck
- [ ] Setup CI/CD test pipeline
- [ ] Configure coverage reporting

### Phase 2: Unit Tests (Weeks 2-3)
- [ ] Cepaf.Cockpit unit tests (200 tests)
- [ ] Cepaf.Cockpit.Web unit tests (150 tests)
- [ ] Cepaf.Cockpit.Avalonia unit tests (100 tests)

### Phase 3: Integration Tests (Weeks 4-5)
- [ ] F#↔Elixir HTTP bridge tests (100 tests)
- [ ] Zenoh pub/sub integration (75 tests)
- [ ] Guardian/Sentinel flow tests (50 tests)

### Phase 4: UI Tests (Weeks 6-7)
- [ ] TUI automation tests (50 tests)
- [ ] Avalonia headless tests (100 tests)
- [ ] Puppeteer WebUI tests (75 tests)

### Phase 5: E2E & Performance (Week 8)
- [ ] 50 user journey scenarios
- [ ] Performance benchmarks
- [ ] Load/stress tests

### Phase 6: Chaos & Security (Week 9)
- [ ] Mara chaos scenarios
- [ ] OWASP security scan
- [ ] Penetration testing

### Phase 7: Compliance (Week 10)
- [ ] STAMP constraint verification (600+)
- [ ] Constitutional invariant tests
- [ ] SIL-6 compliance evidence

---

## References

- **Full Plan**: `/home/an/.claude/plans/recursive-growing-pudding.md`
- **Existing Test Docs**: `docs/testing/CEPAF_COMPREHENSIVE_TEST_PLAN.md`
- **9x9 Matrix**: `docs/testing/TEST_PLAN_9x9_COMPREHENSIVE.md`
- **Five-Level Rules**: `.claude/rules/five-level-testing.md`

---

## Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Date | 2026-01-17 |
| Author | Claude Opus 4.5 |
| STAMP | SC-TEST-*, SC-COV-*, SC-TDG-* |
