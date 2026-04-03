# Wallaby E2E Comprehensive Test Plan — All 46 LiveView Pages

**Date**: 20260328-1400 CEST
**Author**: Claude Opus 4.6
**Version**: v21.3.1-SIL6
**Branch**: main
**STAMP**: SC-COV-008, SC-HMI-011, SC-HMI-010, SC-SYNC-DOC-002
**Status**: PLAN (pre-execution)
**Predecessor**: Wallaby infrastructure wired (Waves 1-3, journal 20260328-1200)

---

## 1. Objective

Achieve **100% Wallaby E2E browser test coverage** for all 46 LiveView pages across 39 routes. Each page gets a dedicated test module verifying: page load, navigation, dynamic elements, event handlers, flash messages, real-time updates, and STAMP constraint compliance.

**Current state**: 1/46 pages covered (observability — 13 features).
**Target state**: 46/46 pages covered (~350-400 features total).

---

## 2. Architecture

### 2.1 Test File Convention

```
test/indrajaal_web/live/
├── navigation_portal_live_wallaby_test.exs
├── prajna_live_wallaby_test.exs
├── monitoring_dashboard_live_wallaby_test.exs
├── performance_dashboard_live_wallaby_test.exs
├── system_status_live_wallaby_test.exs
├── config_management_live_wallaby_test.exs
├── access_control_monitoring_live_wallaby_test.exs
├── permissions_management_live_wallaby_test.exs
├── stamp_tdg_gde_dashboard_live_wallaby_test.exs
├── stamp_tdg_gde_advanced_analytics_live_wallaby_test.exs
├── crm/
│   └── dashboard_live_wallaby_test.exs
├── operations/
│   ├── active_alarms_live_wallaby_test.exs
│   ├── alarm_investigation_live_wallaby_test.exs
│   ├── access_dashboard_live_wallaby_test.exs
│   ├── dispatch_console_live_wallaby_test.exs
│   └── video_wall_live_wallaby_test.exs
└── prajna/
    ├── alarms_live_wallaby_test.exs
    ├── analytics_live_wallaby_test.exs
    ├── access_control_live_wallaby_test.exs
    ├── cluster_live_wallaby_test.exs
    ├── commands_live_wallaby_test.exs
    ├── compliance_live_wallaby_test.exs
    ├── containers_live_wallaby_test.exs
    ├── copilot_live_wallaby_test.exs
    ├── devices_live_wallaby_test.exs
    ├── diagnostics_live_wallaby_test.exs
    ├── git_intelligence_live_wallaby_test.exs
    ├── guardian_dashboard_live_wallaby_test.exs
    ├── guardian_live_wallaby_test.exs
    ├── health_sparkline_live_wallaby_test.exs
    ├── knowledge_live_wallaby_test.exs
    ├── mesh_live_wallaby_test.exs
    ├── observability_live_wallaby_test.exs    # ← EXISTS (13 features)
    ├── register_live_wallaby_test.exs
    ├── sentinel_dashboard_live_wallaby_test.exs
    ├── settings_live_wallaby_test.exs
    ├── shutdown_live_wallaby_test.exs
    ├── startup_live_wallaby_test.exs
    ├── test_cockpit_live_wallaby_test.exs
    ├── threat_live_wallaby_test.exs
    ├── video_live_wallaby_test.exs
    └── knowledge/
        ├── developer_live_wallaby_test.exs
        ├── product_live_wallaby_test.exs
        └── sre_live_wallaby_test.exs
```

### 2.2 Module Template

Every test file follows this structure:

```elixir
defmodule IndrajaalWeb.Prajna.PageNameWallabyTest do
  @moduledoc """
  Wallaby E2E browser tests for PageName LiveView.
  Run with: WALLABY_ENABLED=true mix test --only wallaby
  ## STAMP: SC-COV-008, SC-HMI-011
  """

  use IndrajaalWeb.FeatureCase, async: false
  @moduletag :wallaby

  # ── Page Load ────────────────────────────────────────────
  feature "renders page with expected heading", %{session: session} do
    session |> visit("/route") |> assert_has(css("h1", text: "HEADING"))
  end

  # ── Navigation ───────────────────────────────────────────
  # Tab switching, sidebar links, breadcrumbs

  # ── Dynamic Elements ─────────────────────────────────────
  # Real-time updates, metric cards, status indicators

  # ── Event Handlers ───────────────────────────────────────
  # Button clicks (phx-click), form submissions (phx-submit)

  # ── Flash Messages ───────────────────────────────────────
  # Action feedback, success/error alerts

  # ── Edge Cases ───────────────────────────────────────────
  # Empty states, error states, boundary conditions
end
```

### 2.3 Run Commands

```bash
# All Wallaby E2E tests
test-e2e

# Single page
WALLABY_ENABLED=true mix test test/indrajaal_web/live/prajna/alarms_live_wallaby_test.exs

# By wave
WALLABY_ENABLED=true mix test --only wallaby_wave_1

# By domain
WALLABY_ENABLED=true mix test test/indrajaal_web/live/prajna/ --only wallaby

# With screenshots on failure
WALLABY_ENABLED=true WALLABY_HEADLESS=true mix test --only wallaby
```

---

## 3. Execution Waves

### Wave 1: Critical Path (P0) — 8 Pages, ~65 Features

High-traffic cockpit pages with real-time data and safety implications.

| # | Page | Route | Features | Priority | Rationale |
|---|------|-------|----------|----------|-----------|
| 1 | **NavigationPortalLive** | `/` | 10 | P0 | Entry point, links to all pages |
| 2 | **PrajnaLive** | `/cockpit` | 10 | P0 | Main cockpit dashboard |
| 3 | **Prajna.AlarmsLive** | `/cockpit/alarms` | 12 | P0 | Safety-critical alarm management |
| 4 | **Prajna.SentinelDashboardLive** | `/cockpit/sentinel` | 8 | P0 | Security threat monitoring |
| 5 | **Prajna.GuardianDashboardLive** | `/cockpit/guardian` | 8 | P0 | Constitutional guardian |
| 6 | **Prajna.ClusterLive** | `/cockpit/cluster` | 7 | P0 | Quorum and split-brain visibility |
| 7 | **Prajna.ContainersLive** | `/cockpit/containers` | 5 | P0 | Container lifecycle management |
| 8 | **Prajna.StartupLive** | `/cockpit/startup` | 5 | P0 | Boot sequence monitoring |

#### Detailed Feature Specifications — Wave 1

**1. NavigationPortalLive (`/`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-NAV-001 | Page renders with Indrajaal branding | `h1` or hero text contains "INDRAJAAL" |
| W1-NAV-002 | All 3 service plane tabs present | "Data Plane", "Control Plane", "Cognitive Plane" buttons |
| W1-NAV-003 | Data Plane tab shows service cards | At least 3 service cards with descriptions |
| W1-NAV-004 | Control Plane tab switches content | Click → control plane services visible |
| W1-NAV-005 | Cognitive Plane tab switches content | Click → cognitive services visible |
| W1-NAV-006 | Cockpit link navigates to /cockpit | Click cockpit card → URL changes to `/cockpit` |
| W1-NAV-007 | Deep link support — hash routing | Visit `/#control` → Control Plane tab active |
| W1-NAV-008 | All navigation cards have valid routes | Every card's `href` or `navigate` is non-empty |
| W1-NAV-009 | Theme applied (dark cockpit) | `html` element has `data-theme="dark"` or class `dark` |
| W1-NAV-010 | Responsive layout at 1920x1080 | No horizontal scroll, all cards visible |

**2. PrajnaLive (`/cockpit`, `/cockpit/dashboard`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-PRA-001 | Dashboard renders with sidebar | Sidebar nav with cockpit section links |
| W1-PRA-002 | KPI summary cards present | System health, threat level, container count cards |
| W1-PRA-003 | Sidebar links navigate correctly | Click "Alarms" → `/cockpit/alarms` |
| W1-PRA-004 | Dashboard action navigates | Click "dashboard" → `/cockpit/dashboard` |
| W1-PRA-005 | Real-time health indicator | Health status badge present (green/yellow/red) |
| W1-PRA-006 | Zenoh connection status shown | Zenoh indicator visible in header or status bar |
| W1-PRA-007 | Guardian status visible | Guardian approval pending count visible |
| W1-PRA-008 | Theme toggle works | Click theme toggle → CSS class changes |
| W1-PRA-009 | All sidebar links present | 20+ sidebar links for cockpit pages |
| W1-PRA-010 | /cockpit and /cockpit/dashboard both work | Both routes render the same dashboard |

**3. Prajna.AlarmsLive (`/cockpit/alarms`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-ALM-001 | Alarm list renders | Table or list container present |
| W1-ALM-002 | Severity filter works | Click "Critical" filter → only critical alarms shown |
| W1-ALM-003 | Status filter works | Click "Active" filter → only active alarms |
| W1-ALM-004 | Search input filters alarms | Type in search → alarm list narrows |
| W1-ALM-005 | Acknowledge button triggers action | Click "Acknowledge" → flash "Alarm acknowledged" |
| W1-ALM-006 | Silence button with duration | Click "Silence" → duration picker appears |
| W1-ALM-007 | Escalate button works | Click "Escalate" → flash "Alarm escalated" |
| W1-ALM-008 | Alarm detail expands on click | Click alarm row → detail panel visible |
| W1-ALM-009 | Bulk acknowledge (ack all) | Click "Ack All Advisory" → flash confirmation |
| W1-ALM-010 | Export report button | Click "Export" → flash "Report exported" |
| W1-ALM-011 | Storm detection indicator | Storm indicator present (may show "No storms") |
| W1-ALM-012 | Real-time update (PubSub) | Wait 3s → alarm count may change (page stays alive) |

**4. Prajna.SentinelDashboardLive (`/cockpit/sentinel`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-SEN-001 | Page renders with Sentinel heading | "SENTINEL" in heading |
| W1-SEN-002 | Threat level indicator present | Threat level badge (DEFCON/color) |
| W1-SEN-003 | Active threat count displayed | Numeric threat count visible |
| W1-SEN-004 | PatternHunter status shown | PatternHunter health indicator |
| W1-SEN-005 | SymbioticDefense status shown | Defense subsystem status |
| W1-SEN-006 | Threat history list | At least 1 threat entry or "No threats" |
| W1-SEN-007 | Refresh button works | Click refresh → data updates (page stays alive) |
| W1-SEN-008 | Bridge status visible | Sentinel↔Zenoh bridge health indicator |

**5. Prajna.GuardianDashboardLive (`/cockpit/guardian`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-GUA-001 | Page renders with Guardian heading | "GUARDIAN" in heading |
| W1-GUA-002 | Pending proposals count | Proposal count badge or "0 pending" |
| W1-GUA-003 | Proposal list renders | Proposal table or card list |
| W1-GUA-004 | Constitutional invariants display | Psi-0 through Psi-5 status indicators |
| W1-GUA-005 | Founder's Directive (Omega-0) visible | Omega-0 status indicator |
| W1-GUA-006 | Approve button present | "Approve" or "Accept" button on proposals |
| W1-GUA-007 | Veto button present | "Veto" or "Reject" button on proposals |
| W1-GUA-008 | Decision triggers flash | Click approve/veto → flash message appears |

**6. Prajna.ClusterLive (`/cockpit/cluster`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-CLU-001 | Page renders with cluster heading | "CLUSTER" in heading |
| W1-CLU-002 | Node list displays | At least 1 node entry |
| W1-CLU-003 | Quorum status indicator | Quorum badge (e.g., "2/3 nodes") |
| W1-CLU-004 | Node health colors | Health indicators with colors |
| W1-CLU-005 | 2-second auto-refresh | Wait 3s → page still alive, data may change |
| W1-CLU-006 | Split-brain detection status | Split-brain indicator visible |
| W1-CLU-007 | Node detail on click | Click node → expanded details |

**7. Prajna.ContainersLive (`/cockpit/containers`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-CON-001 | Page renders with containers heading | "CONTAINERS" in heading |
| W1-CON-002 | Container list displays | At least 1 container card/row |
| W1-CON-003 | Container status badges | Status indicators (running/stopped/created) |
| W1-CON-004 | Container ports visible | Port mappings displayed |
| W1-CON-005 | Refresh button works | Click refresh → data reloads |

**8. Prajna.StartupLive (`/cockpit/startup`)**

| TC-ID | Feature | Assertion |
|-------|---------|-----------|
| W1-STA-001 | Page renders with startup heading | "STARTUP" in heading |
| W1-STA-002 | Boot phase indicators | Phase labels (1-5) visible |
| W1-STA-003 | Phase status colors | Green/yellow/red per phase |
| W1-STA-004 | DAG visualization present | Boot DAG or wave diagram |
| W1-STA-005 | Start button present | "Start" or "Boot" action button |

---

### Wave 2: Core Cockpit (P1) — 12 Pages, ~80 Features

Cockpit pages with moderate complexity and user interaction.

| # | Page | Route | Features | Priority |
|---|------|-------|----------|----------|
| 9 | **Prajna.ObservabilityLive** | `/cockpit/observability` | 13 | P1 (DONE) |
| 10 | **Prajna.MeshLive** | `/cockpit/mesh` | 8 | P1 |
| 11 | **Prajna.DiagnosticsLive** | `/cockpit/diagnostics` | 7 | P1 |
| 12 | **Prajna.CommandsLive** | `/cockpit/commands` | 8 | P1 |
| 13 | **Prajna.ThreatLive** | `/cockpit/threat` | 6 | P1 |
| 14 | **Prajna.HealthSparklineLive** | `/cockpit/health-sparklines` | 7 | P1 |
| 15 | **Prajna.RegisterLive** | `/cockpit/register` | 6 | P1 |
| 16 | **Prajna.SettingsLive** | `/cockpit/settings` | 7 | P1 |
| 17 | **Prajna.ShutdownLive** | `/cockpit/shutdown` | 5 | P1 |
| 18 | **Prajna.GuardianLive** | `/cockpit/guardian-approval` | 6 | P1 |
| 19 | **Prajna.DevicesLive** | `/cockpit/devices` | 5 | P1 |
| 20 | **Prajna.GitIntelligenceLive** | `/cockpit/git-intelligence` | 7 | P1 |

#### Key Feature Specs — Wave 2 (Selected)

**Prajna.MeshLive (`/cockpit/mesh`)**

| TC-ID | Feature |
|-------|---------|
| W2-MSH-001 | Page renders with mesh heading |
| W2-MSH-002 | Zenoh router status displayed |
| W2-MSH-003 | Node topology visualization |
| W2-MSH-004 | Pub/sub topic list |
| W2-MSH-005 | Subscription count per topic |
| W2-MSH-006 | Mesh health indicator |
| W2-MSH-007 | Refresh triggers data reload |
| W2-MSH-008 | Node click shows detail |

**Prajna.CommandsLive (`/cockpit/commands`)**

| TC-ID | Feature |
|-------|---------|
| W2-CMD-001 | Page renders with commands heading |
| W2-CMD-002 | Command input field present |
| W2-CMD-003 | Command categories displayed |
| W2-CMD-004 | Submit command triggers execution |
| W2-CMD-005 | Command output displayed |
| W2-CMD-006 | Command history visible |
| W2-CMD-007 | Help/autocomplete works |
| W2-CMD-008 | Error command shows error flash |

**Prajna.ShutdownLive (`/cockpit/shutdown`)**

| TC-ID | Feature |
|-------|---------|
| W2-SHT-001 | Page renders with shutdown heading |
| W2-SHT-002 | Arm & Fire multi-step visible (SC-SAFETY-001) |
| W2-SHT-003 | Arm button requires confirmation |
| W2-SHT-004 | Shutdown phases displayed (6 phases) |
| W2-SHT-005 | Checkpoint status before shutdown |

---

### Wave 3: Knowledge & Analytics (P2) — 10 Pages, ~60 Features

Knowledge management, analytics, and secondary cockpit pages.

| # | Page | Route | Features | Priority |
|---|------|-------|----------|----------|
| 21 | **Prajna.KnowledgeLive** | `/cockpit/knowledge` | 6 | P2 |
| 22 | **Prajna.Knowledge.DeveloperLive** | `/cockpit/knowledge/developer` | 6 | P2 |
| 23 | **Prajna.Knowledge.ProductLive** | `/cockpit/knowledge/product` | 5 | P2 |
| 24 | **Prajna.Knowledge.SRELive** | `/cockpit/knowledge/sre` | 5 | P2 |
| 25 | **Prajna.AnalyticsLive** | `/cockpit/analytics` | 7 | P2 |
| 26 | **Prajna.ComplianceLive** | `/cockpit/compliance` | 6 | P2 |
| 27 | **Prajna.CopilotLive** | `/cockpit/ai-copilot` | 7 | P2 |
| 28 | **Prajna.TestCockpitLive** | `/cockpit/test-evolution` | 6 | P2 |
| 29 | **Prajna.VideoLive** | `/cockpit/video` | 5 | P2 |
| 30 | **Prajna.AccessControlLive** | `/cockpit/access-control` | 7 | P2 |

---

### Wave 4: Operations Center (P2) — 5 Pages, ~40 Features

Operations-oriented pages for incident management.

| # | Page | Route | Features | Priority |
|---|------|-------|----------|----------|
| 31 | **Operations.ActiveAlarmsLive** | `/operations/alarms` | 10 | P2 |
| 32 | **Operations.AlarmInvestigationLive** | `/operations/alarms/:id` | 8 | P2 |
| 33 | **Operations.AccessDashboardLive** | `/operations/access` | 7 | P2 |
| 34 | **Operations.DispatchConsoleLive** | `/operations/dispatch` | 8 | P2 |
| 35 | **Operations.VideoWallLive** | `/operations/video` | 7 | P2 |

---

### Wave 5: Admin & System (P3) — 11 Pages, ~65 Features

Admin panels, system dashboards, and analytics pages.

| # | Page | Route | Features | Priority |
|---|------|-------|----------|----------|
| 36 | **MonitoringDashboardLive** | `/monitoring` | 7 | P3 |
| 37 | **PerformanceDashboardLive** | `/performance` | 7 | P3 |
| 38 | **SystemStatusLive** | `/admin/system-status` | 6 | P3 |
| 39 | **ConfigManagementLive** | `/admin/config` | 8 | P3 |
| 40 | **AccessControlMonitoringLive** | `/admin/access_control` | 6 | P3 |
| 41 | **PermissionsManagementLive** | `/admin/permissions` | 7 | P3 |
| 42 | **StampTdgGdeDashboardLive** | `/analytics/dashboard` | 6 | P3 |
| 43 | **StampTdgGdeAdvancedAnalyticsLive** | `/analytics/stamp-tdg-gde-advanced` | 7 | P3 |
| 44 | **Crm.DashboardLive** | *(CRM internal)* | 5 | P3 |
| 45 | **Prajna.PrometheusLive** | *(internal)* | 3 | P3 |
| 46 | **Prajna.TopologyLive** | *(internal)* | 3 | P3 |

---

## 4. Test Categories

Every page test module MUST include features from these 6 categories:

### Category A: Page Load & Render (Mandatory for ALL pages)
- Page responds with 200 (no crash, no 500 error)
- Primary heading/title visible
- Theme applied (dark cockpit CSS class)
- No JavaScript console errors

### Category B: Navigation & Tabs
- Tab switching changes visible content
- Sidebar/breadcrumb links navigate correctly
- Back button works (browser history)
- Deep links load correct tab state

### Category C: Dynamic Elements
- Real-time data indicators present
- PubSub-driven updates (wait + verify page still alive)
- Timer-driven refresh (verify values change or page persists)
- Status badges render with correct semantic colors

### Category D: Event Handlers (phx-click, phx-submit, phx-change)
- Button clicks trigger expected server events
- Form submissions produce expected results
- Filter/search inputs narrow displayed data
- Dropdown selections change view state

### Category E: Flash Messages & Feedback
- Success actions produce info/success flash
- Error conditions produce error flash
- Flash auto-dismisses or has close button
- Flash uses `[role='alert']` for accessibility

### Category F: Edge Cases & Safety
- Empty state renders gracefully (no data scenario)
- Error state shows user-friendly message
- Multi-step destructive actions (Arm & Fire — SC-SAFETY-001)
- Guardian-gated actions show approval status

---

## 5. Feature Count Summary

| Wave | Pages | Features | Status |
|------|-------|----------|--------|
| Wave 1: Critical Path (P0) | 8 | ~65 | 13 DONE (observability counted in W2) |
| Wave 2: Core Cockpit (P1) | 12 | ~80 | 13 DONE (observability) |
| Wave 3: Knowledge & Analytics (P2) | 10 | ~60 | Pending |
| Wave 4: Operations Center (P2) | 5 | ~40 | Pending |
| Wave 5: Admin & System (P3) | 11 | ~65 | Pending |
| **TOTAL** | **46** | **~310** | **13/~310 (4.2%)** |

---

## 6. Page Objects Module

To reduce duplication across 46 test files, create `test/support/wallaby_page_objects.ex`:

```elixir
defmodule IndrajaalWeb.WallabyPageObjects do
  @moduledoc """
  Page object helpers for Wallaby E2E tests.
  Provides reusable selectors and navigation helpers.
  """

  import Wallaby.Query

  # ── Common Selectors ────────────────────────────────────────────

  def heading(text), do: css("h1, h2, h3", text: text)
  def flash_alert, do: css("[role='alert']")
  def flash_alert(text), do: css("[role='alert']", text: text)
  def sidebar_link(text), do: css("nav a, aside a", text: text)
  def tab_button(tab_value), do: css("button[phx-value-tab='#{tab_value}']")
  def action_button(text), do: css("button", text: text)
  def status_badge, do: css("[data-role='status-badge']")
  def metric_card(label), do: css("span", text: label)
  def table_rows, do: css("tbody tr")
  def search_input, do: css("input[type='search'], input[name='search'], input[phx-change]")
  def theme_class, do: css("html.dark, [data-theme='dark']")

  # ── Navigation Helpers ──────────────────────────────────────────

  def cockpit_pages do
    [
      {"Dashboard", "/cockpit"},
      {"Alarms", "/cockpit/alarms"},
      {"Containers", "/cockpit/containers"},
      {"Commands", "/cockpit/commands"},
      {"Mesh", "/cockpit/mesh"},
      {"Cluster", "/cockpit/cluster"},
      {"Observability", "/cockpit/observability"},
      {"Diagnostics", "/cockpit/diagnostics"},
      {"Sentinel", "/cockpit/sentinel"},
      {"Guardian", "/cockpit/guardian"},
      {"Settings", "/cockpit/settings"},
      {"Knowledge", "/cockpit/knowledge"},
      {"Analytics", "/cockpit/analytics"},
      {"Compliance", "/cockpit/compliance"},
      {"AI Copilot", "/cockpit/ai-copilot"},
      {"Health Sparklines", "/cockpit/health-sparklines"},
      {"Register", "/cockpit/register"},
      {"Threat", "/cockpit/threat"},
      {"Git Intelligence", "/cockpit/git-intelligence"},
      {"Access Control", "/cockpit/access-control"},
      {"Devices", "/cockpit/devices"},
      {"Video", "/cockpit/video"},
      {"Startup", "/cockpit/startup"},
      {"Shutdown", "/cockpit/shutdown"},
      {"Test Evolution", "/cockpit/test-evolution"},
      {"Guardian Approval", "/cockpit/guardian-approval"}
    ]
  end

  def operations_pages do
    [
      {"Alarms", "/operations/alarms"},
      {"Access", "/operations/access"},
      {"Video", "/operations/video"},
      {"Dispatch", "/operations/dispatch"}
    ]
  end

  def admin_pages do
    [
      {"System Status", "/admin/system-status"},
      {"Configuration", "/admin/config"},
      {"Access Control", "/admin/access_control"},
      {"Permissions", "/admin/permissions"}
    ]
  end
end
```

---

## 7. Cross-Cutting Test Suites

In addition to per-page tests, create cross-cutting test modules:

### 7.1 Smoke Test — All Routes Respond (1 test file, 39 features)

```elixir
defmodule IndrajaalWeb.WallabySmokeSuiteTest do
  @moduledoc "Verify all 39 routes render without 500 errors."
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag [:wallaby, :smoke]

  @all_routes [
    "/", "/cockpit", "/cockpit/dashboard", "/cockpit/alarms",
    "/cockpit/sentinel", "/cockpit/guardian", "/cockpit/cluster",
    "/cockpit/containers", "/cockpit/startup", "/cockpit/mesh",
    "/cockpit/diagnostics", "/cockpit/commands", "/cockpit/threat",
    "/cockpit/health-sparklines", "/cockpit/register", "/cockpit/settings",
    "/cockpit/shutdown", "/cockpit/guardian-approval", "/cockpit/devices",
    "/cockpit/git-intelligence", "/cockpit/observability",
    "/cockpit/knowledge", "/cockpit/knowledge/developer",
    "/cockpit/knowledge/product", "/cockpit/knowledge/sre",
    "/cockpit/analytics", "/cockpit/compliance", "/cockpit/ai-copilot",
    "/cockpit/test-evolution", "/cockpit/video", "/cockpit/access-control",
    "/operations/alarms", "/operations/access", "/operations/video",
    "/operations/dispatch", "/monitoring", "/performance",
    "/admin/system-status", "/admin/config", "/admin/access_control",
    "/admin/permissions", "/analytics/dashboard",
    "/analytics/stamp-tdg-gde-advanced"
  ]

  for route <- @all_routes do
    feature "#{route} renders without crash", %{session: session} do
      session
      |> visit(unquote(route))
      |> refute_has(css("h1", text: "Internal Server Error"))
    end
  end
end
```

### 7.2 Theme Consistency — All Pages Dark Cockpit

```elixir
defmodule IndrajaalWeb.WallabyThemeConsistencyTest do
  @moduledoc "Verify SC-HMI-001 dark cockpit theme on all pages."
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag [:wallaby, :theme]

  @cockpit_routes ["/cockpit", "/cockpit/alarms", "/cockpit/sentinel", ...]

  for route <- @cockpit_routes do
    feature "#{route} has dark cockpit theme", %{session: session} do
      session
      |> visit(unquote(route))
      |> assert_has(css("[data-theme='dark'], html.dark"))
    end
  end
end
```

### 7.3 Navigation Integrity — All Sidebar Links Work

```elixir
defmodule IndrajaalWeb.WallabyNavigationIntegrityTest do
  @moduledoc "Verify all sidebar navigation links resolve correctly."
  use IndrajaalWeb.FeatureCase, async: false
  @moduletag [:wallaby, :navigation]

  feature "cockpit sidebar links all resolve", %{session: session} do
    session = visit(session, "/cockpit")

    for {label, _route} <- IndrajaalWeb.WallabyPageObjects.cockpit_pages() do
      assert_has(session, css("a", text: label, minimum: 0))
    end
  end
end
```

---

## 8. Prerequisites & Dependencies

### 8.1 Infrastructure (MUST be running)

| Dependency | Command | Port | Required For |
|-----------|---------|------|-------------|
| PostgreSQL | `podman start indrajaal-db-prod` | 5433 | All tests (Ecto Sandbox) |
| Chromium | `which chromium` (NixOS) | — | Browser rendering |
| chromedriver | `which chromedriver` (NixOS) | 9515 | WebDriver protocol |
| devenv shell | `devenv shell` | — | NixOS packages on PATH |

### 8.2 Optional (Enhance test fidelity)

| Dependency | Command | Required For |
|-----------|---------|-------------|
| Zenoh router | `podman start zenoh-router` | Real-time PubSub tests |
| Observability stack | `podman start indrajaal-obs-prod` | OTEL trace tests |
| Full mesh (`sa-up`) | `sa-up` | Container status, cluster tests |

### 8.3 Environment Variables

```bash
WALLABY_ENABLED=true          # Activate Wallaby infrastructure
SKIP_ZENOH_NIF=0              # Real Zenoh NIF (production parity)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test"
NO_TIMEOUT=true
PATIENT_MODE=enabled
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
MIX_ENV=test
```

All env vars pre-configured in the `test-e2e` devenv command.

---

## 9. Acceptance Criteria

### 9.1 Per-Wave Gates

| Gate | Wave 1 | Wave 2 | Wave 3 | Wave 4 | Wave 5 |
|------|--------|--------|--------|--------|--------|
| All features pass | Required | Required | Required | Required | Required |
| Zero JS console errors | Required | Required | Best effort | Best effort | Best effort |
| Screenshots on failure | Required | Required | Required | Required | Required |
| Page load < 5s | Required | Required | Required | Required | Best effort |
| No 500 errors | Required | Required | Required | Required | Required |

### 9.2 Global Gates (After all waves)

| Gate | Threshold | Metric |
|------|-----------|--------|
| Page coverage | 46/46 (100%) | All LiveView pages have Wallaby tests |
| Feature count | >= 300 | Total `feature` blocks across all files |
| Smoke suite | 39/39 routes pass | All routes render without crash |
| Theme consistency | 26/26 cockpit pages | Dark cockpit theme verified |
| SC-COV-008 | SATISFIED | Wallaby E2E tests exist for all LiveView pages |
| SC-HMI-011 | ADVANCED | 8x8 matrix paths partially covered via tab tests |

### 9.3 Known Limitations

- Tests run against **test data** (Ecto Sandbox), not production data
- Real-time PubSub tests verify page survival, not specific data values
- Zenoh telemetry tests require `zenoh-router` container (optional dependency)
- `/cockpit/knowledge/developer` may 500 if SMRITI not initialized (known bug)
- Alarm investigation (`/operations/alarms/:id`) needs seed data in setup

---

## 10. Schedule Estimate

| Wave | Pages | Est. Features | Dependency |
|------|-------|---------------|------------|
| Wave 1 | 8 | ~65 | PostgreSQL container |
| Wave 2 | 12 | ~80 | Wave 1 complete |
| Wave 3 | 10 | ~60 | Wave 2 complete |
| Wave 4 | 5 | ~40 | Wave 2 complete (parallel with W3) |
| Wave 5 | 11 | ~65 | Wave 3 complete |
| Cross-cutting | 3 suites | ~80 | After Wave 1 |
| Page objects | 1 module | — | Before Wave 1 |

Waves 3 and 4 can execute in parallel since they cover different page domains (Knowledge/Analytics vs Operations).

---

## 11. STAMP & Constitutional Alignment

| Constraint | How Satisfied |
|-----------|---------------|
| **SC-COV-008** | Wallaby E2E browser tests for ALL 46 LiveView pages |
| **SC-HMI-011** | 8x8 Matrix: tab paths × page elements verified per page |
| **SC-HMI-010** | Color Rich: CSS class assertions for semantic colors |
| **SC-HMI-001** | Dark Cockpit: theme consistency suite across all cockpit pages |
| **SC-SAFETY-001** | Arm & Fire: multi-step destructive actions tested on shutdown page |
| **SC-PORTAL-001** | Navigation Portal: all route links verified |
| **AOR-COV-006** | All LiveView pages have Wallaby E2E tests |
| **AOR-E2E-001** | All tests use `IndrajaalWeb.FeatureCase` |
| **AOR-E2E-002** | Normal `mix test` excludes wallaby (`:wallaby` tag) |
| **Psi-3 (Verification)** | New verification dimension: real browser interaction |
| **Omega-3 (Zero-Defect)** | Every page verified to render without 500 errors |

---

## 12. Risk Matrix

| Risk | Severity | Likelihood | Mitigation |
|------|----------|-----------|------------|
| PostgreSQL container not running | HIGH | MEDIUM | `test-e2e` script checks, clear error message |
| chromedriver version mismatch | HIGH | LOW | NixOS pins matching versions |
| LiveView mount crashes on test data | MEDIUM | MEDIUM | FeatureCase setup seeds minimal data |
| Flaky tests from timing | MEDIUM | HIGH | Use `assert_has` with `max_wait_time: 30_000` |
| `/cockpit/knowledge/developer` 500 | LOW | HIGH | Skip with `@tag :skip_known_500` until fixed |
| Chrome sandbox conflicts in CI | MEDIUM | MEDIUM | `--no-sandbox` flag in wallaby.exs |
| Context window pressure (46 files) | LOW | LOW | Page objects module reduces duplication |

---

## 13. Verification Commands

```bash
# Pre-flight check
which chromium && which chromedriver && echo "Browsers OK"
podman ps --filter name=indrajaal-db-prod --format "{{.Status}}" | grep -q "Up" && echo "DB OK"

# Run all E2E tests
test-e2e

# Run single wave (using tags)
WALLABY_ENABLED=true mix test --only wallaby_wave_1

# Run smoke suite only
WALLABY_ENABLED=true mix test --only smoke --only wallaby

# Run with verbose output
WALLABY_ENABLED=true mix test --only wallaby --trace

# Run with screenshots (always on by default for failures)
ls test/wallaby/screenshots/

# Count features
grep -r "feature " test/indrajaal_web/live/*wallaby* | wc -l
```
