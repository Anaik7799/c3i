# UI Remediation Fractal Plan — Full System UI/UX/HX Alignment

**Date**: 20260327-1410 CEST
**Author**: Claude Opus 4.6
**Version**: v21.3.0-SIL6
**Journal**: `docs/journal/20260327-1410-full-system-ui-audit-browser-verification.md`
**Compliance**: SC-HMI-001 to SC-HMI-080, SC-FUNC-002, SC-VER-042

---

## 1.0 Scope & Objective

Remediate all UI issues discovered during the exhaustive Puppeteer browser audit:
- **10 pages** returning 500 Internal Server Error
- **7 phantom routes** returning 404 Not Found
- **1 header nav** link pointing to 404
- **8 sparse pages** with no live data
- **1 unicode escape** bug
- **Sentinel bridge** not polling
- **Redis** not running (readiness probe failing)

**Target**: 100% of NavigationPortal routes rendering without error.

---

## 2.0 Wave Execution Plan (4 Waves, Priority-Ordered)

### Wave 1: P0 — Fix 500 Errors (10 pages)

**Goal**: All routed LiveView pages render without crashing.
**Strategy**: Add defensive `mount/3` with try/rescue, graceful degradation assigns.

| Task | Route | Module | Fix Strategy |
|------|-------|--------|-------------|
| W1-T1 | `/operations/alarms` | `Operations.ActiveAlarmsLive` | Rescue mount, show "No alarms data" |
| W1-T2 | `/cockpit/cluster` | `Prajna.ClusterLive` | Rescue mount, show "Cluster unavailable" |
| W1-T3 | `/cockpit/video` | `Prajna.VideoLive` | Rescue mount, show "Video service offline" |
| W1-T4 | `/cockpit/compliance` | `Prajna.ComplianceLive` | Rescue mount, show "Compliance data loading" |
| W1-T5 | `/operations/video` | `Operations.VideoWallLive` | Rescue mount, show "Video wall offline" |
| W1-T6 | `/monitoring` | `MonitoringDashboardLive` | Rescue mount, show "Monitoring initializing" |
| W1-T7 | `/cockpit/knowledge/developer` | `Knowledge.DeveloperLive` | Rescue mount, show "Knowledge base loading" |
| W1-T8 | `/cockpit/knowledge/product` | `Knowledge.ProductLive` | Rescue mount, show "Knowledge base loading" |
| W1-T9 | `/cockpit/knowledge/sre` | `Knowledge.SreLive` | Rescue mount, show "Knowledge base loading" |
| W1-T10 | `/api/v1/health` | API Controller | Add rescue clause to controller action |

**Verification**: Puppeteer navigate + screenshot each page = 200 OK.

### Wave 2: P1 — Fix Navigation (7 phantom routes + 1 header link)

**Goal**: No NavigationPortal route returns 404.
**Strategy**: Remove phantom routes from @route_categories or add stub modules.

| Task | Route | Action |
|------|-------|--------|
| W2-T1 | `/dev/dashboard` | Remove from NavigationPortal AND app.html.heex header |
| W2-T2 | `/dev/mailbox` | Remove from NavigationPortal |
| W2-T3 | `/operations/devices` | Remove from NavigationPortal (separate from /cockpit/devices which works) |
| W2-T4 | `/operations/maintenance` | Remove from NavigationPortal |
| W2-T5 | `/cockpit/singularity` | Remove from NavigationPortal |
| W2-T6 | `/cockpit/homeostasis` | Remove from NavigationPortal |
| W2-T7 | `/analytics/reports` | Remove from NavigationPortal |
| W2-T8 | app.html.heex header | Replace `/dev/dashboard` with `/cockpit/dashboard` |

**Verification**: All NavigationPortal routes return 200 or redirect (no 404s).

### Wave 3: P2 — Fix Data Wiring (Sentinel + Redis + Unicode)

| Task | Target | Fix |
|------|--------|-----|
| W3-T1 | Sentinel bridge | Ensure SentinelBridge GenServer starts and polls |
| W3-T2 | Redis readiness | Make `/ready` probe Redis-optional or add Redis to stack |
| W3-T3 | Unicode escape | Fix `\u26A0` literal on shutdown page → `⚠` character |
| W3-T4 | OTEL traces | Verify OTEL collector receiving traces |

### Wave 4: P3 — Wire Sparse Pages + Dynamic Data

**Goal**: All 8 sparse pages show live data.

| Task | Route | Data Source Needed |
|------|-------|--------------------|
| W4-T1 | `/cockpit/sentinel` | Wire to Sentinel MCP health polling |
| W4-T2 | `/cockpit/guardian` | Wire to Guardian proposal queue |
| W4-T3 | `/cockpit/knowledge` | Wire to SMRITI knowledge base |
| W4-T4 | `/cockpit/register` | Wire to Immutable Register |
| W4-T5 | `/cockpit/git-intelligence` | Wire to GitIntelligence Zenoh telemetry |
| W4-T6 | `/admin/permissions` | Wire to Ash authorization |
| W4-T7 | `/admin/config` | Wire to system config |
| W4-T8 | `/performance` | Wire to OTEL performance metrics |

---

## 3.0 Test Plan

### 3.1 Browser Verification Tests (Puppeteer)

For each of 56 routes:
1. Navigate to route
2. Assert HTTP 200 (no 404 or 500)
3. Screenshot page
4. Assert page contains expected elements (heading, data sections)
5. Wait 3s, re-screenshot (verify dynamic updates)

### 3.2 Dynamic Behavior Tests (ExUnit)

```elixir
# For each LiveView page:
test "page renders without error", %{conn: conn} do
  {:ok, view, html} = live(conn, "/cockpit/alarms")
  assert html =~ "Alarms"
end

test "page receives PubSub updates", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/cockpit/alarms")
  Phoenix.PubSub.broadcast(Indrajaal.PubSub, "alarms:updates", {:new_alarm, %{}})
  assert render(view) =~ "updated content"
end
```

### 3.3 8x8 Matrix Verification

For each of 64 cells (8 elements x 8 layers):
- L0: Module file exists
- L1: mount/3 succeeds without crash
- L2: render/1 produces HTML
- L3: PubSub subscriptions active
- L4: Container hosting service is healthy
- L5-L7: N/A for single-node deployment

---

## 4.0 Progress Dashboard

```
╔══════════════════════════════════════════════════════════════╗
║  UI REMEDIATION PROGRESS                      [20260327]    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Wave 1 (P0 — 500 Errors):     ░░░░░░░░░░░░░░░░░░░░  0/10  ║
║  Wave 2 (P1 — Phantom Routes): ░░░░░░░░░░░░░░░░░░░░  0/8   ║
║  Wave 3 (P2 — Data Wiring):    ░░░░░░░░░░░░░░░░░░░░  0/4   ║
║  Wave 4 (P3 — Sparse Pages):   ░░░░░░░░░░░░░░░░░░░░  0/8   ║
║                                                              ║
║  Total: 0/30 tasks (0%)                                      ║
║                                                              ║
║  8x8 Matrix:  47% → target 100%                             ║
║  Route Health: 47% OK → target 100%                         ║
║  UNICON Score: 42% accurate                                  ║
║                                                              ║
║  MCP State:                                                  ║
║    Zenoh:    ✓ Connected (2 subs)                            ║
║    Sentinel: ✗ Not polling (score=0)                         ║
║    Redis:    ✗ Down (/ready=not_ready)                       ║
║    Phoenix:  ✓ Running (port 4000)                           ║
║    PG:       ✓ Running (port 5433)                           ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 5.0 FMEA Risk Analysis

| Failure Mode | S | O | D | RPN | Mitigation |
|-------------|---|---|---|-----|------------|
| Mount crash (no rescue) | 9 | 8 | 3 | 216 | Add try/rescue to all mount/3 |
| Phantom route 404 | 5 | 7 | 2 | 70 | Remove from NavigationPortal |
| Sentinel not polling | 7 | 9 | 4 | 252 | Start SentinelBridge GenServer |
| Redis down | 6 | 8 | 3 | 144 | Make readiness Redis-optional |
| Unicode escape | 3 | 10 | 2 | 60 | Replace `\u26A0` with `⚠` |

**Critical RPNs (≥200)**: W1 mount crashes (216), Sentinel polling (252)

---

## 6.0 Success Criteria

| Metric | Current | Target | Gate |
|--------|---------|--------|------|
| Pages returning 200 | 30/56 (54%) | 56/56 (100%) | MANDATORY |
| Pages with live data | 26/56 (46%) | 48/56 (86%) | HIGH |
| 8x8 Matrix coverage | 47% | 90%+ | HIGH |
| Sentinel health score | 0 | >70 | MEDIUM |
| /ready probe | not_ready | ready | MEDIUM |
| UNICON accuracy | 42% | 100% (new doc) | LOW |
