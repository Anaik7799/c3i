# Standalone Runtime Testing Plan - 5-Level Comprehensive Framework
**Version**: 1.0.0 | **Date**: 2025-12-29 | **Status**: ACTIVE
**Framework**: SOPv5.11 + STAMP + TDG + OODA
**Scope**: 100% Dataflow, Control Flow, Cockpit Runtime, Evolvability

---

## L1: Executive Summary (System Level)

### Mission Objective
Execute comprehensive runtime testing of the standalone CEPAF/Cockpit environment achieving:
- 100% Dataflow Coverage (all data paths validated)
- 100% Control Flow Coverage (all decision branches exercised)
- 100% Cockpit Operational Scenarios (all user journeys validated)
- Evolvability Assessment (extensibility, maintainability, adaptability)

### Success Criteria Matrix

| Dimension | Target | Measurement |
|-----------|--------|-------------|
| Dataflow Coverage | 100% | All DB/API/Event paths traced |
| Control Flow Coverage | 100% | All branches/conditions exercised |
| Cockpit Scenarios | 100% | All user journeys completed |
| UX Heuristics | >85% | Nielsen's 10 heuristics score |
| UI Consistency | >95% | Design system compliance |
| CX Net Promoter | >70 | User satisfaction score |
| DX Efficiency | <5min | Time to first meaningful action |
| Evolvability Index | >0.8 | Architectural fitness score |

### Test Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    L1: RUNTIME TEST ORCHESTRATOR                     │
│                    (scripts/testing/runtime_test_orchestrator.exs)   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                           ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│ L2: DATAFLOW  │         │ L2: CONTROL   │         │ L2: COCKPIT   │
│    TESTS      │         │  FLOW TESTS   │         │    TESTS      │
└───────────────┘         └───────────────┘         └───────────────┘
        │                         │                         │
   ┌────┴────┐               ┌────┴────┐               ┌────┴────┐
   ▼         ▼               ▼         ▼               ▼         ▼
┌─────┐  ┌─────┐         ┌─────┐  ┌─────┐         ┌─────┐  ┌─────┐
│ DB  │  │ API │         │OODA │  │Event│         │ UX  │  │ DX  │
│Flow │  │Flow │         │Loop │  │Flow │         │Tests│  │Tests│
└─────┘  └─────┘         └─────┘  └─────┘         └─────┘  └─────┘
```

---

## L2: Container/Domain Level

### 2.1 Dataflow Test Domains

| Domain | Data Entities | Flow Paths | Priority |
|--------|---------------|------------|----------|
| DB Layer | Repo, Queries, Migrations | CRUD → Ecto → PG | P0 |
| API Layer | REST, GraphQL, WebSocket | Request → Handler → Response | P0 |
| Event Layer | PubSub, Telemetry, OODA | Emit → Route → Handle | P0 |
| Cache Layer | ETS, Cachex, Session | Write → Store → Read | P1 |
| File Layer | Uploads, Exports, Logs | Input → Process → Output | P1 |
| External Layer | OpenRouter, Zenoh, OTEL | Request → External → Callback | P2 |

### 2.2 Control Flow Test Domains

| Domain | Decision Points | Branch Coverage | Priority |
|--------|-----------------|-----------------|----------|
| OODA Loop | Observe/Orient/Decide/Act | 4 states × transitions | P0 |
| Circuit Breaker | Closed/Open/Half-Open | 3 states × triggers | P0 |
| Rate Limiter | Allow/Throttle/Block | Window-based decisions | P0 |
| Health Monitor | Healthy/Degraded/Failed | State machine coverage | P1 |
| Auth Flow | Login/Logout/Refresh/Revoke | Token lifecycle | P1 |
| Error Handling | Try/Catch/Rescue/Fallback | Exception paths | P1 |

### 2.3 Cockpit Test Domains

| Domain | Scenarios | User Types | Priority |
|--------|-----------|------------|----------|
| Dashboard | View/Filter/Drill-down | Operator, Admin | P0 |
| AI Copilot | Query/Response/Feedback | All users | P0 |
| Alerts | View/Acknowledge/Resolve | Operator | P0 |
| Settings | View/Edit/Save/Reset | Admin | P1 |
| Reports | Generate/Export/Schedule | Manager | P1 |
| Navigation | Menu/Breadcrumb/Search | All users | P1 |

---

## L3: Component Level

### 3.1 Dataflow Test Scenarios (100%)

#### 3.1.1 Database Dataflow (DF-DB-*)

```yaml
DF-DB-001:
  name: "CRUD Lifecycle - Complete Entity"
  flow: Create → Read → Update → Delete
  entities: [User, Device, Alarm, Site, Policy]
  validations:
    - Insert returns {:ok, entity}
    - Select returns entity with all fields
    - Update reflects changes
    - Delete removes from table
  coverage: 100% of Ash resources

DF-DB-002:
  name: "Transaction Atomicity"
  flow: Begin → Operations → Commit/Rollback
  scenarios:
    - Multi-entity transaction success
    - Partial failure with rollback
    - Nested transaction handling
  coverage: All Repo.transaction calls

DF-DB-003:
  name: "Query Optimization"
  flow: Query → Plan → Execute → Result
  validations:
    - No N+1 queries
    - Index utilization verified
    - Query time < 100ms (95th percentile)
  coverage: All complex queries

DF-DB-004:
  name: "Migration Integrity"
  flow: Migrate Up → Verify → Migrate Down → Verify
  validations:
    - Schema matches expectations
    - Data preserved on rollback
    - Indexes created correctly
  coverage: All migrations
```

#### 3.1.2 API Dataflow (DF-API-*)

```yaml
DF-API-001:
  name: "REST Endpoint Coverage"
  flow: Request → Auth → Validate → Process → Response
  endpoints:
    - GET /api/v1/* (list, show)
    - POST /api/v1/* (create)
    - PUT/PATCH /api/v1/* (update)
    - DELETE /api/v1/* (delete)
  validations:
    - Status codes correct
    - Response schema validated
    - Error responses structured
  coverage: 100% of REST routes

DF-API-002:
  name: "WebSocket Channel Flow"
  flow: Connect → Join → Push → Receive → Leave
  channels:
    - UserSocket
    - PrajnaChannel
    - AlertChannel
    - DashboardChannel
  validations:
    - Connection authenticated
    - Messages delivered
    - Presence tracked
  coverage: 100% of channels

DF-API-003:
  name: "GraphQL Query/Mutation Flow"
  flow: Parse → Validate → Resolve → Format
  operations:
    - Queries with arguments
    - Mutations with input
    - Subscriptions
  validations:
    - Schema compliance
    - Error handling
    - Performance < 200ms
  coverage: 100% of GraphQL schema
```

#### 3.1.3 Event Dataflow (DF-EVT-*)

```yaml
DF-EVT-001:
  name: "Telemetry Event Flow"
  flow: Emit → Handle → Aggregate → Report
  events:
    - phoenix.endpoint.*
    - indrajaal.*.*
    - ooda.*.cycle
  validations:
    - Events emitted correctly
    - Handlers invoked
    - Metrics recorded
  coverage: 100% of telemetry events

DF-EVT-002:
  name: "PubSub Message Flow"
  flow: Publish → Route → Subscribe → Receive
  topics:
    - alarm:*
    - user:*
    - system:*
  validations:
    - Messages delivered
    - No message loss
    - Order preserved (where required)
  coverage: 100% of PubSub topics

DF-EVT-003:
  name: "OODA Observation Flow"
  flow: Sensor → Observe → Orient → Decide → Act
  sensors:
    - System metrics
    - User actions
    - External events
  validations:
    - Observations recorded
    - Orientation computed
    - Decisions logged
  coverage: All OODA sensors
```

### 3.2 Control Flow Test Scenarios (100%)

#### 3.2.1 OODA Loop Control (CF-OODA-*)

```yaml
CF-OODA-001:
  name: "Normal OODA Cycle"
  states: [Idle, Observing, Orienting, Deciding, Acting]
  transitions:
    - Idle → Observing (on: trigger)
    - Observing → Orienting (on: data_collected)
    - Orienting → Deciding (on: context_analyzed)
    - Deciding → Acting (on: decision_made)
    - Acting → Idle (on: action_complete)
  validations:
    - Each transition logged
    - Cycle time < 100ms (SC-OODA-001)
    - No state skipping

CF-OODA-002:
  name: "Hysteresis Mode (SC-OODA-005)"
  conditions:
    - Decision within 10% of threshold
    - Hold for 3 consecutive cycles
  validations:
    - No oscillation between states
    - Hysteresis margin respected
    - Hold counter accurate

CF-OODA-003:
  name: "AI Orientation Fallback (SC-OODA-006)"
  conditions:
    - AI timeout (> 20ms)
    - AI unavailable
    - Anomaly threshold exceeded
  validations:
    - Fallback to local heuristics
    - No decision delay
    - Telemetry emitted
```

#### 3.2.2 Circuit Breaker Control (CF-CB-*)

```yaml
CF-CB-001:
  name: "Circuit Breaker State Machine"
  states: [Closed, Open, HalfOpen]
  transitions:
    - Closed → Open (on: failure_threshold)
    - Open → HalfOpen (on: timeout)
    - HalfOpen → Closed (on: success)
    - HalfOpen → Open (on: failure)
  validations:
    - State changes logged
    - Failure count accurate
    - Recovery behavior correct

CF-CB-002:
  name: "Membrane Protection (SC-BIO-002)"
  scenarios:
    - Rate limit exceeded
    - Health check failed
    - External service down
  validations:
    - Requests blocked correctly
    - Fallback responses provided
    - Recovery automatic
```

#### 3.2.3 Authentication Control (CF-AUTH-*)

```yaml
CF-AUTH-001:
  name: "JWT Token Lifecycle"
  states: [None, Valid, Expired, Revoked]
  flows:
    - Login → Issue → Use → Refresh → Use
    - Login → Issue → Use → Expire → Refresh
    - Login → Issue → Revoke → Reject
  validations:
    - Token validation correct
    - Refresh token rotation
    - Revocation immediate

CF-AUTH-002:
  name: "MFA Flow"
  states: [Initial, Challenged, Verified, Failed]
  methods: [TOTP, Backup Code, Recovery]
  validations:
    - Challenge issued correctly
    - Verification accurate
    - Lockout after failures
```

### 3.3 Cockpit Runtime Scenarios (100%)

#### 3.3.1 User Journey: Operator (CK-OP-*)

```yaml
CK-OP-001:
  name: "Morning Shift Startup"
  journey:
    - Login with credentials
    - View dashboard summary
    - Review overnight alerts
    - Acknowledge critical alerts
    - Check system health
  duration: < 2 minutes
  validations:
    - All data loads correctly
    - Alerts sorted by severity
    - Actions logged

CK-OP-002:
  name: "Alert Response"
  journey:
    - Receive alert notification
    - View alert details
    - Access related entity
    - Take remediation action
    - Mark alert resolved
  duration: < 1 minute
  validations:
    - Alert details complete
    - Navigation intuitive
    - Resolution recorded

CK-OP-003:
  name: "AI Copilot Query"
  journey:
    - Open copilot interface
    - Ask operational question
    - Review AI response
    - Execute suggested action
    - Provide feedback
  duration: < 30 seconds
  validations:
    - Response relevant
    - Actions executable
    - Feedback recorded
```

#### 3.3.2 User Journey: Admin (CK-AD-*)

```yaml
CK-AD-001:
  name: "User Management"
  journey:
    - Navigate to user admin
    - Search for user
    - View user profile
    - Modify permissions
    - Save and verify
  validations:
    - Search accurate
    - Permissions saved
    - Audit logged

CK-AD-002:
  name: "System Configuration"
  journey:
    - Access settings
    - Modify configuration
    - Preview changes
    - Apply configuration
    - Verify effect
  validations:
    - Changes preview accurate
    - Rollback available
    - Effect immediate

CK-AD-003:
  name: "Report Generation"
  journey:
    - Select report type
    - Configure parameters
    - Generate report
    - Review output
    - Export/share
  validations:
    - Report accurate
    - Export formats work
    - Scheduling functional
```

---

## L4: Module Level - UX/UI/CX/DX Evaluation

### 4.1 UX Heuristics Evaluation (Nielsen's 10)

| # | Heuristic | Test Method | Pass Criteria |
|---|-----------|-------------|---------------|
| H1 | Visibility of System Status | Check loading indicators, progress bars | All async ops show status |
| H2 | Match with Real World | Review terminology, icons | Domain terms used correctly |
| H3 | User Control & Freedom | Test undo, cancel, back | All destructive ops reversible |
| H4 | Consistency & Standards | Audit UI patterns | 95% pattern compliance |
| H5 | Error Prevention | Test edge cases | Confirmations on destructive ops |
| H6 | Recognition over Recall | Check navigation, hints | All actions discoverable |
| H7 | Flexibility & Efficiency | Test shortcuts, customization | Power user features exist |
| H8 | Aesthetic & Minimalist | Visual audit | No unnecessary elements |
| H9 | Error Recovery | Test error states | Clear error messages, recovery paths |
| H10 | Help & Documentation | Check help system | Contextual help available |

### 4.2 UI Consistency Audit

```yaml
UI-CON-001:
  name: "Color Palette Compliance"
  checks:
    - Primary colors match design system
    - Semantic colors (success, error, warning) consistent
    - Dark mode colors correct
    - Contrast ratios WCAG AA compliant
  tools: [axe-core, lighthouse]

UI-CON-002:
  name: "Typography Consistency"
  checks:
    - Font family correct
    - Size scale followed
    - Line heights consistent
    - Heading hierarchy clear
  tools: [style-dictionary audit]

UI-CON-003:
  name: "Component Library Compliance"
  checks:
    - All buttons use Button component
    - All forms use Form components
    - All modals use Modal component
    - All tables use Table component
  tools: [credo-ui-audit]

UI-CON-004:
  name: "Spacing & Layout"
  checks:
    - Grid system followed
    - Spacing scale consistent
    - Responsive breakpoints correct
    - Touch targets 44px minimum
  tools: [visual regression]
```

### 4.3 CX (Customer Experience) Metrics

```yaml
CX-MET-001:
  name: "Task Completion Rate"
  measurement: % of users completing key tasks
  target: > 95%
  tasks:
    - View dashboard
    - Respond to alert
    - Generate report

CX-MET-002:
  name: "Time on Task"
  measurement: Average time to complete tasks
  targets:
    - Login: < 10s
    - Find alert: < 5s
    - Resolve alert: < 30s
    - Generate report: < 60s

CX-MET-003:
  name: "Error Rate"
  measurement: User errors per session
  target: < 2 errors per session
  tracking:
    - Form validation errors
    - Navigation dead ends
    - Failed actions

CX-MET-004:
  name: "System Usability Scale (SUS)"
  measurement: 10-question standardized survey
  target: > 80 (excellent)
  frequency: After major flows
```

### 4.4 DX (Developer Experience) Metrics

```yaml
DX-MET-001:
  name: "Time to First Meaningful Action"
  measurement: From git clone to running test
  target: < 5 minutes
  steps:
    - Clone repo
    - Setup environment
    - Start containers
    - Run first test

DX-MET-002:
  name: "Documentation Coverage"
  measurement: % of modules with docs
  target: 100%
  checks:
    - moduledoc present
    - function docs present
    - Examples in docs

DX-MET-003:
  name: "API Discoverability"
  measurement: Can find API without external docs
  target: 100% discoverable
  methods:
    - iex introspection
    - h Module.function
    - @doc attributes

DX-MET-004:
  name: "Error Message Quality"
  measurement: Actionable error messages
  target: 100% actionable
  criteria:
    - What went wrong
    - Why it failed
    - How to fix it
```

### 4.5 Ergonomic Assessment

```yaml
ERG-001:
  name: "Keyboard Navigation"
  tests:
    - Tab order logical
    - Focus visible
    - Shortcuts documented
    - No keyboard traps
  compliance: WCAG 2.1 AA

ERG-002:
  name: "Information Density"
  tests:
    - Critical info above fold
    - Progressive disclosure used
    - Scanning patterns supported (F, Z)
    - Cognitive load reasonable
  target: < 7 items per view

ERG-003:
  name: "Feedback Latency"
  tests:
    - Button feedback < 100ms
    - Loading indicator < 1s
    - Complete response < 3s
  compliance: RAIL model

ERG-004:
  name: "Dark Mode / Light Mode"
  tests:
    - Both modes complete
    - Smooth transition
    - User preference persisted
    - System preference respected
```

### 4.6 Information Architecture Assessment

```yaml
IA-001:
  name: "Navigation Structure"
  evaluation:
    - Hierarchy depth: Max 3 levels
    - Breadcrumbs: Always present
    - Search: Global and contextual
    - Related links: Contextually relevant

IA-002:
  name: "Content Organization"
  evaluation:
    - Grouping: Related items together
    - Labeling: Clear and consistent
    - Ordering: Priority-based or alphabetical
    - Filtering: Faceted where appropriate

IA-003:
  name: "Dashboard Layout"
  evaluation:
    - KPIs: Most important top-left
    - Charts: Appropriate visualization
    - Tables: Sortable, filterable
    - Actions: Contextually placed
```

### 4.7 Aesthetic Evaluation

```yaml
AES-001:
  name: "Visual Hierarchy"
  criteria:
    - Clear focal points
    - Size indicates importance
    - Color guides attention
    - Whitespace used effectively

AES-002:
  name: "Brand Consistency"
  criteria:
    - Logo placement correct
    - Brand colors used
    - Tone of voice consistent
    - Imagery style aligned

AES-003:
  name: "Modern Design Patterns"
  criteria:
    - Clean, minimal interface
    - Appropriate use of cards
    - Consistent iconography
    - Smooth animations (60fps)
```

---

## L5: Code Level - Evolvability Assessment

### 5.1 Architectural Fitness Functions

```yaml
AF-001:
  name: "Modularity Index"
  formula: "1 - (external_deps / total_deps)"
  target: > 0.8
  measurement: mix xref graph analysis

AF-002:
  name: "Coupling Score"
  formula: "fan_in + fan_out per module"
  target: < 10 per module
  measurement: Credo complexity checks

AF-003:
  name: "Cohesion Score"
  formula: "related_functions / total_functions"
  target: > 0.7
  measurement: Module function analysis

AF-004:
  name: "Test Coverage"
  target: > 95%
  measurement: mix test --cover
```

### 5.2 Extensibility Checks

```yaml
EXT-001:
  name: "Plugin Architecture"
  checks:
    - Behaviour definitions exist
    - New implementations addable
    - Configuration-driven loading
  domains: [Notifications, Authentication, Storage]

EXT-002:
  name: "Feature Flags"
  checks:
    - Runtime toggleable
    - Gradual rollout supported
    - A/B testing possible

EXT-003:
  name: "API Versioning"
  checks:
    - Version in URL/header
    - Backward compatibility
    - Deprecation warnings
```

### 5.3 Maintainability Checks

```yaml
MNT-001:
  name: "Code Complexity"
  tools: [credo, dialyzer]
  targets:
    - Cyclomatic complexity < 10
    - ABC metric < 50
    - Function length < 50 lines

MNT-002:
  name: "Technical Debt"
  tracking:
    - TODO/FIXME count
    - Deprecation warnings
    - Sobelow findings
  target: Decrease over time

MNT-003:
  name: "Documentation Currency"
  checks:
    - Docs match implementation
    - Examples compile
    - No dead links
```

### 5.4 Adaptability Checks

```yaml
ADP-001:
  name: "Configuration Externalization"
  checks:
    - All config in config/*.exs
    - Runtime config supported
    - Secrets via env vars

ADP-002:
  name: "Database Agnosticism"
  checks:
    - Ecto abstractions used
    - No raw SQL (except where necessary)
    - Migration reversibility

ADP-003:
  name: "UI Theming"
  checks:
    - CSS variables used
    - Theme switching works
    - Custom themes possible
```

---

## Execution Plan

### Phase 1: Environment Setup (Day 1)

```bash
# 1. Start standalone environment
elixir scripts/testing/standalone_test_env.exs --full

# 2. Verify all services running
./scripts/testing/cockpit_manual_test.sh --status

# 3. Initialize test database
MIX_ENV=test mix ecto.setup
```

### Phase 2: Dataflow Testing (Days 2-3)

```bash
# Run dataflow tests
mix test test/runtime/dataflow/ --trace

# Generate dataflow coverage report
mix test.dataflow --coverage-report
```

### Phase 3: Control Flow Testing (Days 4-5)

```bash
# Run control flow tests
mix test test/runtime/control_flow/ --trace

# Run state machine verification
mix test test/runtime/state_machines/ --trace
```

### Phase 4: Cockpit Testing (Days 6-8)

```bash
# Run LiveView tests
MIX_ENV=test mix test test/indrajaal_web/live/prajna/ --trace

# Run accessibility audit
mix a11y.audit

# Run visual regression
mix test.visual
```

### Phase 5: Evolvability Assessment (Days 9-10)

```bash
# Run architectural fitness
mix fitness.check

# Run code quality
mix credo --strict

# Generate report
mix evolvability.report
```

---

## Test Execution Scripts

### Main Orchestrator

```elixir
# scripts/testing/runtime_test_orchestrator.exs
# To be created - orchestrates all runtime tests
```

### Individual Test Runners

| Script | Purpose | Command |
|--------|---------|---------|
| `dataflow_tester.exs` | Run dataflow tests | `elixir scripts/testing/dataflow_tester.exs` |
| `control_flow_tester.exs` | Run control flow tests | `elixir scripts/testing/control_flow_tester.exs` |
| `cockpit_scenario_runner.exs` | Run cockpit scenarios | `elixir scripts/testing/cockpit_scenario_runner.exs` |
| `ux_heuristic_evaluator.exs` | Evaluate UX heuristics | `elixir scripts/testing/ux_heuristic_evaluator.exs` |
| `evolvability_assessor.exs` | Assess evolvability | `elixir scripts/testing/evolvability_assessor.exs` |

---

## Reporting

### Test Report Structure

```
reports/runtime_test_YYYYMMDD/
├── summary.md              # Executive summary
├── dataflow/
│   ├── db_coverage.html
│   ├── api_coverage.html
│   └── event_coverage.html
├── control_flow/
│   ├── ooda_coverage.html
│   ├── circuit_breaker.html
│   └── auth_flow.html
├── cockpit/
│   ├── scenarios.html
│   ├── ux_heuristics.html
│   └── accessibility.html
├── evolvability/
│   ├── fitness_functions.html
│   └── maintainability.html
└── screenshots/
    └── visual_regression/
```

---

## References

- `journal/2025-12/20251229-1700-autonomous-agent-credo-biomorphic-mission.md`
- `docs/architecture/PRAJNA_5_LEVEL_SPECIFICATION.md`
- `docs/architecture/PRAJNA_C3I_COCKPIT.md`
- `CLAUDE.md` (STAMP Constraints)
- Nielsen's 10 Usability Heuristics
- WCAG 2.1 Guidelines
- RAIL Performance Model
