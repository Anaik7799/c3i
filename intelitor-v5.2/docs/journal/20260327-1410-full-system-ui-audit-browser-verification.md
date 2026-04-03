# Full System UI Audit & Browser Verification — UNICON Cross-Reference

**Date**: 20260327-1410 CEST
**Author**: Claude Opus 4.6 (Cybernetic Architect)
**Version**: v21.3.0-SIL6
**Reference**: `docs/journal/20260327-1330-unicon-ui-ux-hx-formal-verification-unification.md` (Gemini CLI)
**Compliance**: SC-HMI-001 to SC-HMI-080, SC-VER-042, SC-SYNC-DOC-001

---

## 1.0 Requirements — What Was Asked

The user requested a comprehensive system audit covering:

| # | Requirement | Source |
|---|-------------|--------|
| R1 | Verify UNICON document claims against codebase | User Mandate |
| R2 | Test ALL GUI pages with a browser (Puppeteer MCP) | User Mandate |
| R3 | Create detailed fractal plan for UI/UX/HX + formal verification | User Mandate |
| R4 | Use MCP, Zenoh, OTEL for system state + closed-loop actions | User Mandate |
| R5 | Create detailed journal entry (requirements, design, implementation, testing) | User Mandate |
| R6 | Create progress dashboard | User Mandate |
| R7 | Review full system comprehensively | User Mandate |
| R8 | Align Prajna to current system state | User Mandate |
| R9 | Update NavigationPortal and all related pages | User Mandate |
| R10 | Ensure all dynamic data is dynamically updating | User Mandate |
| R11 | Create tests verifying dynamic behavior of each element | User Mandate |

---

## 2.0 Design — System Architecture Verified

### 2.1 UI Architecture Stack (4 Stacks)

| Stack | Technology | Location | Status |
|-------|-----------|----------|--------|
| **Elixir LiveView** | Phoenix 1.8 + LiveView | `lib/indrajaal_web/live/` | PRIMARY — 56 NavigationPortal routes |
| **F# Bolero** | Blazor WebAssembly MVU | `lib/cepaf/src/Cepaf.Cockpit.Web/` | PLANNED — Not deployed |
| **F# Avalonia** | Fabulous MVU Desktop | `lib/cepaf/src/Cepaf.Cockpit.Avalonia/` | PLANNED — Not deployed |
| **Elixir TUI** | ANSI terminal rendering | `lib/indrajaal/cockpit/prajna/` | PLANNED — Not deployed |

### 2.2 Theme System (7 Interface Profiles)

Source: `lib/indrajaal_web/contexts/theme_context.ex:22`

| Profile | Atom | Status |
|---------|------|--------|
| Light | `:light` | Implemented |
| Dark | `:dark` | Implemented |
| High Contrast | `:high_contrast` | Implemented |
| System | `:system` | Implemented |
| **Color Rich** | `:color_rich` | **DEFAULT** — Active paradigm |
| Google Compliant | `:google_compliant` | Implemented |
| Functionally Clean | `:functionally_clean` | Implemented |

### 2.3 Route Architecture

- **Router file**: `lib/indrajaal_web/router.ex` (466 lines)
- **NavigationPortal routes**: 56 across 7 categories
- **Total Phoenix routes**: 400+ (including API, admin, health)
- **Prajna LiveView modules**: 28 files in `lib/indrajaal_web/live/prajna/`
- **Knowledge sub-modules**: 3 files (`developer_live.ex`, `product_live.ex`, `sre_live.ex`)

---

## 3.0 Implementation — UNICON Document Verification

### 3.1 Claim-by-Claim Cross-Reference

| # | UNICON Claim | Actual Finding | Verdict |
|---|-------------|----------------|---------|
| C1 | "46+ routes reachable via NavigationPortalLive" | 56 routes in @route_categories across 7 categories | **FALSE** — Understated by 10 |
| C2 | "4 selectable options: Dark, Color Rich, Google, Clean" | 7 profiles: light, dark, high_contrast, system, color_rich, google_compliant, functionally_clean | **FALSE** — Missing 3 profiles |
| C3 | "Resolved `to` variable collision in Quint" | `action` was renamed to `operation` in guardian_state_machine.qnt:86, not `to` | **FALSE** — Wrong variable name |
| C4 | "Transition from Dark Cockpit to Color Rich Mechanism" | Default theme is `:color_rich` in theme_context.ex:23 | **TRUE** |
| C5 | "F# Bolero views in Cepaf.Cockpit.Web" | F# Bolero project exists in codebase | **TRUE** |
| C6 | "Resolved scoping error in Agda SecurityContext" | Agda file exists with module alignment | **PARTIALLY TRUE** |

**UNICON Accuracy Score**: 2.5/6 (42%) — Document contains significant inaccuracies.

### 3.2 Formal Verification State

| Gate | Tool | File | Status |
|------|------|------|--------|
| G1 | Quint | `docs/formal_specs/guardian_state_machine.qnt` | Modified (action→operation rename), locally testable |
| G2 | Agda | `docs/formal_specs/agda_proofs.agda` | Modified, type-check status unknown |

---

## 4.0 Testing — Exhaustive Browser Verification (Puppeteer MCP)

### 4.1 Test Methodology

- **Tool**: Puppeteer MCP (puppeteer_navigate + puppeteer_screenshot)
- **Target**: `http://localhost:4000` (Phoenix LiveView)
- **Scope**: 55 of 56 NavigationPortal routes tested
- **Duration**: ~45 minutes across 2 sessions

### 4.2 Results Summary

| Category | Count | Percentage |
|----------|-------|------------|
| Working Rich (full functionality) | 26 | 47% |
| Health Probes (API endpoints) | 4 | 7% |
| Sparse/Shell (renders but minimal content) | 8 | 15% |
| 404 Not Found (phantom routes) | 7 | 13% |
| 500 Internal Server Error | 10 | 18% |
| **Total Tested** | **55** | **100%** |

### 4.3 Detailed Page Status

#### Working Rich Pages (26) — Full UI with Data
| Route | Status | Key Elements |
|-------|--------|-------------|
| `/` | OK | NavigationPortal with 7 categories, 56 routes |
| `/cockpit` | OK | Prajna C3I dashboard |
| `/cockpit/dashboard` | OK | System dashboard |
| `/cockpit/mesh` | OK | Mesh topology view |
| `/cockpit/ai-copilot` | OK | AI copilot chat interface |
| `/cockpit/alarms` | OK | Alarm management |
| `/cockpit/commands` | OK | Command console |
| `/cockpit/observability` | OK | OTEL metrics |
| `/cockpit/settings` | OK | System settings |
| `/cockpit/diagnostics` | OK | Diagnostics panel |
| `/cockpit/test-evolution` | OK | Test evolution dashboard |
| `/cockpit/shutdown` | OK | Shutdown panel (unicode `\u26A0` bug) |
| `/cockpit/threat` | OK | Threat assessment |
| `/cockpit/health-sparklines` | OK | Health sparkline charts |
| `/cockpit/devices` | OK | Device management |
| `/cockpit/access-control` | OK | Access control panel |
| `/cockpit/analytics` | OK | Analytics view |
| `/cockpit/startup` | OK | Startup sequence |
| `/cockpit/guardian-approval` | OK | Guardian approval workflow |
| `/cockpit/containers` | OK | Container management |
| `/analytics/dashboard` | OK | Analytics dashboard |
| `/analytics/stamp-tdg-gde-advanced` | OK | Advanced STAMP/TDG/GDE |
| `/operations/access` | OK | Access operations |
| `/operations/dispatch` | OK | Dispatch console |
| `/admin/system-status` | OK | System status admin |
| `/admin/access_control` | OK | Access control admin |

#### Health Probes (4)
| Route | Response | Status |
|-------|----------|--------|
| `/healthz` | `"ok"` | Healthy |
| `/health` | JSON health object | Healthy |
| `/startup` | `{"status":"started","uptime_seconds":327}` | Healthy |
| `/ready` | `{"status":"not_ready"}` | **Not Ready** — Redis dependency failing |

#### Sparse/Shell Pages (8) — Render but Minimal Content
| Route | Issue |
|-------|-------|
| `/cockpit/sentinel` | Shell with no active data (Sentinel bridge not polling) |
| `/cockpit/guardian` | Shell with no active proposals |
| `/cockpit/knowledge` | Shell with knowledge categories but no data |
| `/cockpit/register` | Shell with empty register view |
| `/cockpit/git-intelligence` | Shell with git metrics pending |
| `/admin/permissions` | Shell with permission matrix |
| `/admin/config` | Shell with config view |
| `/performance` | Shell with performance metrics |

#### 404 Not Found — Phantom Routes (7)
| Route | Listed In | Router Entry |
|-------|-----------|-------------|
| `/dev/dashboard` | NavigationPortal + app.html.heex header | **NONE** |
| `/dev/mailbox` | NavigationPortal | **NONE** |
| `/operations/devices` | NavigationPortal | **NONE** |
| `/operations/maintenance` | NavigationPortal | **NONE** |
| `/cockpit/singularity` | NavigationPortal | **NONE** |
| `/cockpit/homeostasis` | NavigationPortal | **NONE** |
| `/analytics/reports` | NavigationPortal | **NONE** |

#### 500 Internal Server Error (10)
| Route | LiveView Module | Probable Cause |
|-------|----------------|---------------|
| `/operations/alarms` | `Operations.ActiveAlarmsLive` | Service dependency crash |
| `/cockpit/cluster` | `Prajna.ClusterLive` | Cluster state unavailable |
| `/cockpit/video` | `Prajna.VideoLive` | Video service dependency |
| `/cockpit/compliance` | `Prajna.ComplianceLive` | Compliance data unavailable |
| `/operations/video` | `Operations.VideoWallLive` | Video service dependency |
| `/monitoring` | `MonitoringDashboardLive` | Monitoring service crash |
| `/cockpit/knowledge/developer` | `Knowledge.DeveloperLive` | Knowledge base unavailable |
| `/cockpit/knowledge/product` | `Knowledge.ProductLive` | Knowledge base unavailable |
| `/cockpit/knowledge/sre` | `Knowledge.SreLive` | Knowledge base unavailable |
| `/api/v1/health` | API controller | API health check crash |

### 4.4 MCP System State During Testing

| System | Status | Details |
|--------|--------|---------|
| **Zenoh** | Connected | tcp/localhost:7447, 2 subs, 0 published, uptime 1484s |
| **Sentinel** | Not Polling | score=0, status="unknown", updated="never" |
| **Phoenix** | Running | Port 4000, LiveView operational |
| **Redis** | **DOWN** | /ready reports not_ready |
| **PostgreSQL** | Running | Port 5433, DB healthy |

---

## 5.0 Goals Asked vs Goals Achieved

| # | Goal | Status | Achievement | Notes |
|---|------|--------|-------------|-------|
| R1 | Verify UNICON document | **DONE** | 100% | 6 claims checked, 2.5/6 accurate (42%) |
| R2 | Test ALL GUI pages with browser | **DONE** | 98% | 55/56 routes tested via Puppeteer MCP |
| R3 | Create fractal plan | **IN PROGRESS** | 50% | Plan document being created |
| R4 | Use MCP/Zenoh/OTEL for system state | **DONE** | 80% | Zenoh connected, Sentinel queried, OTEL not probed |
| R5 | Create detailed journal entry | **DONE** | 100% | This document |
| R6 | Create progress dashboard | **PENDING** | 0% | Planned for fractal plan |
| R7 | Review full system | **DONE** | 90% | All routes tested, state checked |
| R8 | Align Prajna to current state | **IN PROGRESS** | 30% | Issues identified, fixes pending |
| R9 | Update NavigationPortal | **IN PROGRESS** | 20% | Phantom routes identified, removal pending |
| R10 | Ensure dynamic data updating | **ASSESSED** | 40% | 8 sparse pages need data wiring |
| R11 | Create tests for dynamic behavior | **PENDING** | 0% | Test specs defined in fractal plan |

**Overall Completion: 55%**

---

## 6.0 Critical Findings & Remediation Priority

### 6.1 P0 — Fix 500 Errors (10 pages)
All 10 pages have router entries and LiveView modules that exist but crash on mount. Root causes are likely:
- Missing GenServer/service processes that the mount function tries to call
- PubSub subscription to topics with no publisher
- Pattern match failures on nil/missing data in assigns

### 6.2 P1 — Remove Phantom Routes (7 routes)
7 routes in NavigationPortalLive's @route_categories have no corresponding router entry. They should be:
- Removed from @route_categories, OR
- Added to the router with proper LiveView modules

### 6.3 P1 — Fix app.html.heex Header
The `/dev/dashboard` link in the global header returns 404. Must be replaced with a working route.

### 6.4 P2 — Wire Sentinel Bridge
Sentinel MCP returns score=0, status="unknown" — the bridge is not actively polling system health. The Sentinel LiveView pages are sparse because of this.

### 6.5 P2 — Fix Unicode Escape
`/cockpit/shutdown` displays `\u26A0` as literal text instead of the warning symbol.

### 6.6 P2 — Start Redis or Remove Dependency
`/ready` probe reports not_ready because Redis health check fails. Either start Redis in the container stack or make the readiness probe Redis-optional.

### 6.7 P3 — Wire 8 Sparse Pages
8 pages render but show minimal/no data. These need their data sources connected.

---

## 7.0 8x8 Fractal Matrix Audit (SC-HMI-011)

### 7.1 Matrix: 8 Elements x 8 Layers

| Element | L0 Code | L1 Function | L2 Component | L3 Holon | L4 Container | L5 Node | L6 Cluster | L7 Federation |
|---------|---------|-------------|--------------|----------|--------------|---------|------------|----------------|
| **Alarms** | Module exists | mount crashes | 500 error | PubSub missing | Container ok | N/A | N/A | N/A |
| **Guardian** | Module exists | Renders shell | Sparse content | No proposals | Container ok | N/A | N/A | N/A |
| **Sentinel** | Module exists | Renders shell | No data | Bridge not polling | Container ok | N/A | N/A | N/A |
| **Knowledge** | Module exists | mount crashes | 500 error | Knowledge base N/A | Container ok | N/A | N/A | N/A |
| **Mesh/Cluster** | Module exists | mount crashes | 500 error | Cluster state N/A | Container ok | N/A | N/A | N/A |
| **Video** | Module exists | mount crashes | 500 error | Video service N/A | Container ok | N/A | N/A | N/A |
| **Compliance** | Module exists | mount crashes | 500 error | Compliance data N/A | Container ok | N/A | N/A | N/A |
| **Navigation** | Module exists | Renders fully | 56 routes | Portal working | Container ok | Node ok | N/A | N/A |

### 7.2 Matrix Score
- **L0 (Code)**: 8/8 modules exist (100%)
- **L1 (Function)**: 3/8 render correctly (37.5%)
- **L2 (Component)**: 3/8 show content (37.5%)
- **L3 (Holon)**: 1/8 has full data flow (12.5%)
- **L4-L7**: Not applicable for current single-node deployment

**Overall Matrix Coverage**: 47% (significant gaps at L1-L3)

---

## 8.0 STAMP Constraint Compliance

| Constraint | Description | Status |
|------------|-------------|--------|
| SC-HMI-001 | Dark Cockpit / Color Rich compliance | PARTIAL — Color Rich default set but 10 pages crash |
| SC-HMI-008 | Theme-aware layout | PASS — app.html.heex uses theme CSS classes |
| SC-HMI-010 | Color Rich Mechanism | PASS — Default theme is :color_rich |
| SC-HMI-011 | 8x8 Fractal Matrix Audit | FAIL — 47% coverage (target: 100%) |
| SC-VER-042 | All CLI commands functional | PARTIAL — Web UI subset failing |
| SC-FUNC-001 | System MUST compile at all times | PASS — Compiles successfully |
| SC-FUNC-002 | Core services MUST be operational | FAIL — 10 pages returning 500 |

---

## 9.0 Recommendations

1. **Immediate**: Fix 10 x 500 errors by adding defensive `mount/3` with try/rescue and graceful degradation
2. **Short-term**: Remove 7 phantom routes from NavigationPortalLive or create stub modules
3. **Short-term**: Fix app.html.heex header `/dev/dashboard` → `/cockpit/dashboard`
4. **Medium-term**: Wire Sentinel bridge for active health polling
5. **Medium-term**: Start Redis in container stack or make readiness probe Redis-optional
6. **Long-term**: Wire all 8 sparse pages to live data sources

---

**Status**: Audit complete. Remediation plan in `doc/plans/20260327-1410-ui-remediation-fractal-plan.md`.
**STAMP**: SC-HMI-001, SC-HMI-011, SC-VER-042, SC-FUNC-002
**Layer**: L1-CODE(2), L2-DOMAIN(3), L3-SYSTEM(2)
**Impact Score**: 18 (MEDIUM RISK — service availability)
