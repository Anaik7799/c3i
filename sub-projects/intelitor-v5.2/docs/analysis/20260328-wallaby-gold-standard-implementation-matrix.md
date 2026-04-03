# Wallaby Gold Standard — Implementation Matrix & Constraints

**Date**: 20260328-1700 CEST
**Author**: Claude Opus 4.6
**STAMP**: SC-COV-008, SC-HMI-011

---

## 1. New STAMP Constraints for Gold Standard Coverage

### SC-COV-009 through SC-COV-016 (New)

| ID | Constraint | Severity | Description |
|----|------------|----------|-------------|
| SC-COV-009 | C1 (Page Structure) coverage MANDATORY per Wallaby file | HIGH | Every Wallaby test must verify h1 heading and navigation |
| SC-COV-010 | C2 (Status/Badge) coverage MANDATORY per Wallaby file | HIGH | Dynamic badges and severity indicators tested |
| SC-COV-011 | C3 (Data Grid) coverage MANDATORY per Wallaby file | HIGH | Key-value data display verified |
| SC-COV-012 | C4 (Timeline/History) coverage MANDATORY where applicable | MEDIUM | Ordered events and audit trail tested |
| SC-COV-013 | C5 (Interactive) coverage MANDATORY for form-bearing pages | HIGH | Form submission and DOM mutation verified |
| SC-COV-014 | C6 (Media) coverage MANDATORY for media-bearing pages | MEDIUM | Video, charts, SVG tested |
| SC-COV-015 | C7 (AI/Advisory) coverage MANDATORY for AI panels | HIGH | SC-AI-001 ADVISORY disclaimer verified |
| SC-COV-016 | C8 (Actions) DUAL verification MANDATORY | CRITICAL | Every action button tested for BOTH status change AND flash message |

### SC-COV-017 through SC-COV-020 (Quality Gates)

| ID | Constraint | Severity | Description |
|----|------------|----------|-------------|
| SC-COV-017 | Minimum 30 features per safety-critical page Wallaby file | CRITICAL | P0 pages must have ≥30 features |
| SC-COV-018 | Minimum 20 features per interactive page Wallaby file | HIGH | P1 pages must have ≥20 features |
| SC-COV-019 | Two-step commit pages require arm→confirm→cancel test sequence | CRITICAL | SC-SAFETY-001 compliance verification |
| SC-COV-020 | PubSub-driven pages require refresh stability test | HIGH | Sleep past interval, re-assert data presence |

### AOR-COV-008 through AOR-COV-015 (New Operating Rules)

| ID | Rule | Description |
|----|------|-------------|
| AOR-COV-008 | Source-first selectors: Read LiveView .ex source BEFORE writing Wallaby selectors | Prevents selector mismatch |
| AOR-COV-009 | Every action button in C8 MUST be tested twice (status + flash) | Dual verification pattern |
| AOR-COV-010 | Two-step commit flows MUST test all 3 states (idle→armed→executing/cancelled) | Full state machine coverage |
| AOR-COV-011 | Wallaby tests MUST use `@moduletag :wallaby` and `async: false` | Test isolation |
| AOR-COV-012 | Coverage entropy H ≥ 2.5 bits per file (balanced categories) | Anti-pattern: all C1, no C8 |
| AOR-COV-013 | New LiveView pages MUST include Wallaby test in same commit | TDG-style |
| AOR-COV-014 | FMEA-discovered bugs (F-001 to F-007) MUST have regression tests | FMEA-driven testing |
| AOR-COV-015 | PubSub topic changes MUST update corresponding Wallaby tests | Topic coupling |

---

## 2. Per-Page Implementation Plan (Detailed)

### Wave 1 — Safety-Critical (P0, 8 pages)

#### CommandsLive (25→45 features, +20)
```
NEW C2: +2 (target status badge, armed indicator)
NEW C3: +3 (target grid values, command history entries)
NEW C4: +3 (command result log: success, failure, timeout)
NEW C5: +2 (confirmation text input, update_confirmation)
NEW C8: +10 (ARM/FIRE: arm→armed+flash, confirm→executed+flash, cancel→cancelled+flash, 5 targets select)
```

#### ShutdownLive (20→42 features, +22)
```
NEW C2: +2 (mode badge, phase indicator)
NEW C3: +3 (timeout display, mode values)
NEW C4: +4 (phase progress entries per shutdown phase)
NEW C5: +2 (update_mode select, update_timeout input)
NEW C8: +11 (initiate→started+flash, abort→aborted+flash, force_arm→ARMED+flash, force_confirm→executing+flash, force_cancel→cancelled+flash)
```

#### GuardianLive (44→52 features, +8)
```
NEW C2: +2 (proposal priority badges P0-P3)
NEW C4: +2 (audit trail after approve/veto)
NEW C8: +4 (request_approve→modal, confirm_action→approved+flash, request_veto→modal, cancel_confirm→dismissed)
```

#### AlarmsLive (20→48 features, +28)
```
NEW C2: +2 (storm status, filter indicator)
NEW C3: +4 (severity counts: Critical/Warning/Caution/Advisory)
NEW C4: +3 (workflow entries: Pending/InProgress/Escalated/Resolved)
NEW C5: +2 (search input, status select)
NEW C7: +2 (sentinel health, KPI metrics)
NEW C8: +15 (9 events × dual verification: filter×2, search, acknowledge, silence, escalate, select, ack_all, storm_ack, export, configure)
```

#### ThreatLive (22→42 features, +20)
```
NEW C2: +2 (severity filter indicator, threat count badge)
NEW C3: +3 (threat detail: source, timestamp, confidence)
NEW C4: +2 (threat timeline entries)
NEW C8: +13 (7 events × dual: filter×2, select, close, acknowledge, dismiss, acknowledge_all)
```

#### ClusterLive (20→44 features, +24)
```
NEW C2: +2 (quorum status, autoscale indicator)
NEW C3: +3 (node list, pool size)
NEW C5: +2 (scale input, add_node form)
NEW C8: +17 (7 events × dual + TWO-STEP FIX for force_election)
```

#### ActiveAlarmsLive (12→44 features, +32)
```
NEW C1: +2 (heading, breadcrumb)
NEW C2: +3 (severity badges, count, filter indicator)
NEW C3: +4 (alarm table rows: severity, source, timestamp, status)
NEW C5: +3 (search, status select, batch checkboxes)
NEW C8: +20 (9 events × dual + batch operations)
```

#### AccessDashboardLive (~13→42 features, +29)
```
NEW C1: +2 (heading, zone map section)
NEW C2: +2 (zone status badges, access point indicators)
NEW C3: +4 (access point detail, event log entries)
NEW C5: +2 (point selection, zone filter)
NEW C8: +16 (8 events × dual + TWO-STEP FIX for lockdown_zone)
NEW REGRESSION: +3 (F-005 flash in handle_info tests)
```

### Wave 2 — High-Interaction (P1, 10 pages)

#### SettingsLive (16→46 features, +30)
```
11 events × dual verification + envelope two-step (3 states) + tab coverage
```

#### DiagnosticsLive (32→48 features, +16)
```
10 events: add missing C6 (media), tab switching completeness, dual flash verification
```

#### TestCockpitLive (~18→44 features, +26)
```
8 events + 3 PubSub topics + evolution state machine coverage
```

#### DispatchConsoleLive (14→48 features, +34)
```
12 events × dual + unit lifecycle (dispatch→arrive→complete)
```

#### VideoWallLive (11→40 features, +29)
```
9 events × dual + layout switching + recording lifecycle
```

#### CopilotLive (48→52 features, +4)
```
Already gold standard. Add: model switch verification, streaming toggle, context load
```

#### KnowledgeLive (17→42 features, +25)
```
9 events + zettel CRUD lifecycle + graph view + vault export/import
```

#### SentinelDashboardLive (18→38 features, +20)
```
6 events × dual + tab coverage + auto-response toggle
```

#### AnalyticsLive (30→42 features, +12)
```
7 events: add missing C4 (timeline), realtime toggle, metric selection
```

#### ComplianceLive (16→34 features, +18)
```
5 events × dual + tab coverage + audit lifecycle
```

### Wave 3 — Infrastructure (P2, 8 pages)

#### ContainersLive (17→36 features, +19)
#### DevicesLive (15→32 features, +17)
#### MeshLive (25→38 features, +13)
#### StartupLive (15→30 features, +15)
#### ObservabilityLive (13→34 features, +21)
#### RegisterLive (13→30 features, +17)
#### GitIntelligenceLive (14→30 features, +16)
#### GuardianDashboardLive (26→38 features, +12)

### Wave 4 — Missing Pages (P2, 10 pages, ~300 features NEW)

#### PrajnaLive — `/cockpit` (0→30 features, NEW)
#### SystemStatusLive — `/admin/system-status` (0→25 features, NEW)
#### ConfigManagementLive — `/admin/config` (0→35 features, NEW)
#### Knowledge.DeveloperLive (0→28 features, NEW)
#### Knowledge.ProductLive (0→28 features, NEW)
#### Knowledge.SRELive (0→28 features, NEW)
#### TopologyLive UPGRADE (12→30 features, +18)
#### PrometheusLive UPGRADE (12→30 features, +18)
#### HealthSparklineLive UPGRADE (13→25 features, +12)
#### ZenohMeshHealth UPGRADE (13→28 features, +15)

### Wave 5 — Admin & Analytics (P3, 4 pages, ~80 features)

#### StampTdgGdeDashboardLive (0→20 features, NEW)
#### StampTdgGdeAdvancedAnalyticsLive (0→20 features, NEW)
#### PermissionsManagementLive (0→20 features, NEW)
#### Crm.DashboardLive (0→20 features, NEW)

---

## 3. Agent Deployment Strategy

### 11-Agent Parallel Execution

| Agent | Scope | Model | Files/Wave |
|-------|-------|-------|------------|
| A1 | Commands + Shutdown | sonnet | Wave 1 |
| A2 | Guardian + Alarms | sonnet | Wave 1 |
| A3 | Threat + Cluster | sonnet | Wave 1 |
| A4 | ActiveAlarms + Access | sonnet | Wave 1 |
| A5 | Settings + Diagnostics | haiku | Wave 2 |
| A6 | TestCockpit + Dispatch | haiku | Wave 2 |
| A7 | VideoWall + Copilot + Knowledge | haiku | Wave 2 |
| A8 | Sentinel + Analytics + Compliance | haiku | Wave 2 |
| A9 | Containers + Devices + Mesh + Startup | haiku | Wave 3 |
| A10 | Observability + Register + Git + Guardian Dashboard | haiku | Wave 3 |
| A11 | ALL missing pages (Wave 4+5) | haiku | Wave 4-5 |

### Quality Gate Per File
```
1. Read LiveView .ex source first (source-first selectors)
2. Write test with all 8 categories (where applicable)
3. Verify feature count ≥ threshold (P0: 30, P1: 20, P2: 15)
4. Verify C8 dual verification (status + flash) for every action
5. Verify two-step sequences where applicable
6. Calculate coverage entropy H ≥ 2.5 bits
7. Compile check
```

---

## 4. Aggregate Target Metrics

| Metric | Current | Target | Delta |
|--------|---------|--------|-------|
| Total Wallaby files | 33 | 47 | +14 |
| Total features | ~605 | ~1,486 | +881 |
| Gold standard files (≥40) | 3 | 20+ | +17 |
| Silver files (25-39) | 5 | 15+ | +10 |
| Missing pages | 14 | 0 | -14 |
| C8 dual verification coverage | ~15% | 100% | +85pp |
| Two-step test coverage | 4/7 pages | 7/7 pages | +3 |
| FMEA regression tests | 0 | 7 | +7 |
| Coverage entropy avg | ~1.8 bits | ≥2.5 bits | +0.7 |
| Risk-Weighted Coverage | ~32% | ≥85% | +53pp |
| Fractal Self-Similarity | ~0.35 | ≥0.75 | +0.40 |
