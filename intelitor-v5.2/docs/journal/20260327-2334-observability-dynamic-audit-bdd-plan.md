# Observability Dashboard Dynamic Audit, BDD Plan & Test Agent Integration

| Field | Value |
|-------|-------|
| Date | 2026-03-27 23:34 CEST |
| Author | Claude Opus 4.6 |
| Module | `IndrajaalWeb.Prajna.ObservabilityLive` |
| Route | `/cockpit/observability` |
| Version | 1.0.0 |
| Sprint | 88 |
| STAMP | SC-HMI-001, SC-OBS-069, SC-OBS-071, SC-PRF-050, SC-TEL-003, SC-COV-008 |

---

## 1. Executive Summary

Deep code audit of the Observability LiveView page (`lib/indrajaal_web/live/prajna/observability_live.ex`) reveals **4 critical dynamic gaps** where elements are static when they should update in real-time. 12 elements are correctly wired to dynamic data (6 via BEAM intrinsics, 6 via jitter simulation). A comprehensive BDD test plan with **35 scenarios across 11 sections** is defined. Two external tools — `partarstu/ui-test-execution-agent` (LLM+vision-based GUI testing) and `anthropics/skills` (Agent Skills with `webapp-testing` Playwright skill) — are evaluated for integration into the test suite.

---

## 2. Problem Statement

The Observability dashboard is the primary C3I operator screen for system health monitoring. Several elements render once at mount and never update, violating SC-PRF-050 (updates < 50ms latency) and the Dark Cockpit / Color Rich mechanism (SC-HMI-001, SC-HMI-010). An operator relying on this screen would see stale trace data, frozen SigNoz metrics, and a hardcoded node count — undermining situational awareness. Additionally, the existing test suite has only 5 structural tests (module exists, functions exported) with zero dynamic behavior coverage (SC-COV-006: Puppeteer screenshots for all pages).

---

## 3. Architecture Context

### Page Structure
- **Header Bar**: Health score, uptime, node count, alarm count, timestamp
- **Tab Navigation**: Metrics | Traces | Logs | SigNoz Integration
- **Metrics Tab**: 3 KPI cards (Request Rate, Error Rate, P99 Latency) + 3 Resource cards (Active Connections, DB Pool, FLAME Utilization)
- **Traces Tab**: Trace explorer with expandable span details
- **Logs Tab**: Redirect link to Diagnostics
- **SigNoz Tab**: OTEL module status + SigNoz integration health
- **Action Bar**: Open SigNoz + Export Metrics buttons

### Update Mechanism
- Timer: `500ms` interval via `:timer.send_interval`
- PubSub: `"prajna:metrics"` and `"prajna:traces"` channels
- Handler: `handle_info(:refresh)` calls `update_metrics/1`, `update_traces/1`, `update_otel_status/1`

### Component Dependencies
- `IndrajaalWeb.PrajnaComponents`: `prajna_header`, `prajna_nav`, `status_icon`, `trend_indicator`, `sparkline`, `gauge`, `metric_card`

---

## 4. Dynamic Behavior Audit

### 4.1 Elements That ARE Dynamic (Working)

| # | Element | Data Source | Mechanism | Real/Simulated |
|---|---------|-------------|-----------|----------------|
| 1 | Request Rate | `jitter(±5)` | Timer 500ms | Simulated |
| 2 | Error Rate | `jitter(±0.01)` | Timer 500ms | Simulated |
| 3 | P99 Latency | `jitter(±3)` | Timer 500ms | Simulated |
| 4 | Active Connections | `length(:erlang.ports())` | Timer 500ms | **Real BEAM** |
| 5 | DB Pool Usage | `jitter(±2)` | Timer 500ms | Simulated |
| 6 | FLAME Utilization | `run_queue * 20 / schedulers + process_count / 500` | Timer 500ms | **Real BEAM** |
| 7-12 | All 6 sparklines | `add_to_history/2` | Timer 500ms | Rolling 30-pt window |
| 13 | Trend indicators | `calculate_trend/1` | Computed from history slope | Derived |
| 14 | Header health score | `calculate_health_score/1` | Derived from error_rate + latency | Derived |
| 15 | Header alarm count | `count_alarms/1` | Threshold: error_rate > 0.5 or latency > 100 | Derived |
| 16 | Header uptime | `:erlang.statistics(:wall_clock)` | Per-render | **Real BEAM** |
| 17 | OTEL module loaded? | `Code.ensure_loaded?/1` | Timer 500ms | **Real BEAM** |

### 4.2 Elements That Are STATIC (Bugs)

| # | Bug | Location | Current Behavior | Expected Behavior |
|---|-----|----------|-----------------|-------------------|
| **BUG-1** | Traces never update | `update_traces/1` line 630-633 | Returns `socket` unchanged (no-op) | Wire to BEAM telemetry or generate realistic trace rotation |
| **BUG-2** | SigNoz status never updated | `handle_info(:refresh)` line 73-79 | No `update_signoz_status/1` call | Add to refresh handler, derive from OTEL/port checks |
| **BUG-3** | OTEL metric values are strings | `update_otel_status/1` line 647-648 | Shows "active"/"not loaded" | Show real span/query counts from `:telemetry` or ETS counters |
| **BUG-4** | Node count hardcoded | `render/1` line 127-128 | Always shows `5/5` | Wire to `length(Node.list()) + 1` and configured total |

---

## 5. Root Cause Analysis (5-Why)

### BUG-1: Traces static
1. **Why are traces static?** — `update_traces/1` returns socket unchanged
2. **Why is it a no-op?** — Comment says "In production, would fetch real traces"
3. **Why weren't real traces wired?** — No OTEL trace collector GenServer exists in this holon
4. **Why no collector?** — Traces flow to SigNoz externally, not aggregated in-process
5. **Root cause**: Missing in-process trace sampling/aggregation mechanism

### BUG-2: SigNoz status static
1. **Why is SigNoz status static?** — No `update_signoz_status/1` function called in refresh
2. **Why wasn't it included?** — Oversight during initial implementation
3. **Root cause**: Missing call in `handle_info(:refresh)` pipeline

### BUG-3: OTEL metrics are strings
1. **Why are metric values strings?** — `update_otel_status/1` only checks `Code.ensure_loaded?`
2. **Why not real counts?** — No `:telemetry` counter aggregation in place
3. **Root cause**: Missing telemetry counter integration for OTEL span/query rates

### BUG-4: Node count hardcoded
1. **Why hardcoded to 5?** — Set directly in render template, not from assigns
2. **Root cause**: Copy-paste from template, never wired to BEAM cluster info

---

## 6. BDD Test Plan — 11 Sections, 35 Scenarios

### Section 1: Header Bar Dynamic Behavior (6 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 1.1 | Health score updates when error_rate/latency change | `@header @health-score` | Score = 100 - penalties; penalties from error_rate and latency thresholds |
| 1.2 | Health score threshold transitions | `@header @threshold` | HEALTHY(>=90)/DEGRADED(>=70)/WARNING(>=50)/CRITICAL(<50) with correct colors |
| 1.3 | Uptime reflects real BEAM wall clock | `@header @uptime @real-beam` | Non-zero "Xd Yh" format from `:erlang.statistics(:wall_clock)` |
| 1.4 | Alarm count appears/disappears at thresholds | `@header @alarm-count` | 0 alarms when normal; +1 at error_rate>0.5; +1 at latency>100 |
| 1.5 | **Node count reflects real cluster** | `@header @BUG-STATIC` | Must wire to `Node.list()`, NOT hardcoded 5/5 |
| 1.6 | Timestamp advances on re-render | `@header @timestamp` | DateTime advances between renders |

### Section 2: KPI Cards — Metrics Tab (5 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 2.1 | Request Rate jitters ±5 and sparkline shifts | `@metrics @request-rate` | Value changes on refresh; sparkline prepends new value, drops oldest |
| 2.2 | Error Rate alarm colors at thresholds | `@metrics @error-rate @threshold` | Normal(<0.5)=white, Caution(0.5-1.0)=amber, Warning(>1.0)=red |
| 2.3 | P99 Latency alarm colors at thresholds | `@metrics @p99-latency @threshold` | Normal(<50)=white, Caution(50-100)=amber, Warning(>100)=red |
| 2.4 | Trend indicator reflects history slope | `@metrics @trend-indicator` | ↑↑(>20%)/↑(>5%)/→(±5%)/↓(<-5%)/↓↓(<-20%) with correct colors |
| 2.5 | Sparkline 30-point rolling window | `@metrics @sparkline` | Exactly 30 points; oldest dropped; Unicode ▁▂▃▄▅▆▇█ chars |

### Section 3: Resource Cards — Metrics Tab (4 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 3.1 | Active Connections = real BEAM ports | `@metrics @real-beam` | Value matches `length(:erlang.ports())` |
| 3.2 | DB Pool gauge reflects ratio | `@metrics @db-pool` | Gauge bar proportional to current/max |
| 3.3 | FLAME from real BEAM schedulers | `@metrics @flame @real-beam` | Derived from run_queue and process_count, clamped 5-95 |
| 3.4 | Resource alarm at 75%/90% | `@metrics @threshold` | Normal(<75%)=white, Caution(75-90%)=amber, Warning(>90%)=red |

### Section 4: Traces Tab (8 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 4.1 | **Traces update on refresh** | `@traces @BUG-STATIC` | Currently NO-OP; must generate/rotate traces |
| 4.2 | Click trace expands spans | `@traces @click-expand` | phx-click="view_trace" sets selected_trace; spans render |
| 4.3 | Sorted slowest first | `@traces @sort-order` | Duration descending |
| 4.4 | Border amber if >100ms | `@traces @border` | `border-amber-700` vs `border-border-theme-primary` |
| 4.5 | Status "⚠ slow"/"✓ normal" | `@traces @status` | 100ms threshold |
| 4.6 | Duration text coloring | `@traces @latency` | >100=red, >50=amber, else=green |
| 4.7 | Empty state message | `@traces @empty` | "No traces captured yet" centered |
| 4.8 | **PubSub trace_added** | `@traces @pubsub @BUG-STATIC` | Currently calls no-op update_traces |

### Section 5: SigNoz Tab (4 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 5.1 | OTEL modules reflect loaded status | `@signoz @real-beam` | `Code.ensure_loaded?` per module |
| 5.2 | **OTEL metric values real counts** | `@signoz @BUG-STATIC` | Not "active"/"not loaded" strings |
| 5.3 | OTLP endpoint status live | `@signoz @endpoint` | Connected/Disconnected |
| 5.4 | **SigNoz metrics update** | `@signoz @BUG-STATIC` | traces_per_min, metrics_per_min must update |

### Section 6: Tab Navigation (3 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 6.1 | Tab switch changes content | `@tabs` | phx-click="switch_tab" shows correct panel |
| 6.2 | All 4 tabs render | `@tabs @all` | metrics/traces/logs/signoz each render |
| 6.3 | Active tab styling | `@tabs @styling` | bg-surface-secondary active, text-content-muted inactive |

### Section 7: Action Bar (2 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 7.1 | Open SigNoz flash | `@actions` | Flash with "Opening SigNoz at http://localhost:3301" |
| 7.2 | Export Metrics flash | `@actions` | Flash with dated filename |

### Section 8: Logs Tab (1 scenario)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 8.1 | Diagnostics redirect link | `@logs` | "GO TO DIAGNOSTICS" → `/cockpit/diagnostics` |

### Section 9: PubSub Integration (3 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 9.1 | metric_update triggers refresh | `@pubsub` | `{:metric_update, name, value}` on "prajna:metrics" |
| 9.2 | trace_added triggers refresh | `@pubsub @BUG` | `{:trace_added, trace}` on "prajna:traces" (no-op) |
| 9.3 | Subscriptions on connect | `@pubsub` | Both topics + 500ms timer |

### Section 10: Timer & Refresh (2 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 10.1 | Refresh within 50ms budget | `@timer @SC-PRF-050` | Full handle_info(:refresh) < 50ms |
| 10.2 | No timer in static mode | `@timer` | Disconnected = no timer, no PubSub |

### Section 11: Edge Cases (5 scenarios)

| # | Scenario | Tags | Tests |
|---|----------|------|-------|
| 11.1 | Empty sparkline shows padding | `@edge` | ░ repeated to width |
| 11.2 | Trend stable with <3 values | `@edge` | Default `:stable` |
| 11.3 | Jitter stays in bounds | `@edge` | request_rate ±5 from base |
| 11.4 | Error rate 2 decimal places | `@edge` | `Float.round(value, 2)` |
| 11.5 | Resource card max=0 safe | `@edge` | `max(1, max)` prevents div/0 |

---

## 7. Required Code Fixes

| Fix | File | Lines | Description | Priority |
|-----|------|-------|-------------|----------|
| FIX-1 | `observability_live.ex` | 630-633 | Wire `update_traces/1` to generate traces from BEAM telemetry | P0 |
| FIX-2 | `observability_live.ex` | 73-79 | Add `update_signoz_status/1` call in `handle_info(:refresh)` | P0 |
| FIX-3 | `observability_live.ex` | 635-653 | Make OTEL `metric_value` show real counts from `:telemetry` | P1 |
| FIX-4 | `observability_live.ex` | 127-128 | Wire `node_count` to `length(Node.list()) + 1` | P1 |

---

## 8. External Test Agent Integration Analysis

### 8.1 partarstu/ui-test-execution-agent

**Repository**: https://github.com/partarstu/ui-test-execution-agent
**Status**: ARCHIVED (Dec 2025) — migrated to `partarstu/test-execution-agents`

**What it is**: A Java 25 AI agent that executes GUI test cases written in **natural language** using LLM + computer vision + vector DB (Chroma) instead of CSS/XPath selectors.

**Architecture**: 10 specialized sub-agents:
| Agent | Role |
|---|---|
| PreconditionActionAgent | Sets up test preconditions |
| PreconditionVerificationAgent | Validates preconditions via vision |
| TestStepActionAgent | Executes individual test actions |
| TestStepVerificationAgent | Validates expected results via vision |
| ElementBoundingBoxAgent | Vision-based element location |
| ElementSelectionAgent | Disambiguates multiple candidates |
| UiElementDescriptionAgent | RAG element metadata generation |
| UiStateCheckAgent | Overall UI state validation |
| PageDescriptionAgent | Page context for element selection |
| TestCaseExtractionAgent | JSON test case parsing |

**Key technologies**: Java 25, LangChain4j 1.9.1, OpenCV 4.10.0, Chroma DB, multiple LLM providers (Google, Azure, Anthropic, Groq), A2A JSON-RPC protocol for server mode.

**Test case format** — natural language JSON:
```json
{
  "testCaseName": "Verify observability sparklines animate",
  "preconditions": "Browser open on observability page",
  "testSteps": [
    {
      "stepDescription": "Observe the Request Rate sparkline for 2 seconds",
      "expectedResults": "The sparkline characters should change between observations"
    }
  ]
}
```

**Integration path for Indrajaal**:
- **Server mode** (A2A JSON-RPC): Run Java agent as sidecar, call from ExUnit via HTTP
- **Budget management**: Configurable token/time/tool-call limits prevent CI runaway costs
- **Attended mode**: Operator trains element recognition via Chroma vector DB
- **Unattended mode**: Autonomous CI/CD execution against known elements

**Constraints**:
- Requires display (X11/VNC), no pure headless — problematic for CI
- Java 25 runtime + ~330MB shaded JAR
- Linux OpenCV issues noted by author (unresolved)
- Successor repo (`test-execution-agents`) adds API testing + Neo4j

**Verdict**: Concepts are valuable (NL test cases, vision verification, RAG element memory), but Java dependency + display requirement + archive status make it **unsuitable for direct integration**. The pattern of NL test definitions + vision verification should be replicated natively using the Anthropic skills approach.

### 8.2 anthropics/skills — webapp-testing Skill

**Repository**: https://github.com/anthropics/skills
**Stars**: 105k | **Status**: Active, officially maintained by Anthropic

**What it is**: Official Agent Skills standard — self-contained, installable capability packages extending Claude's behavior. 17 skills available; the critical one for our purposes is **`webapp-testing`**.

**`webapp-testing` skill provides**:
- **Playwright (Python sync API)** browser automation
- `with_server.py` — server lifecycle management (start/stop/wait for port)
- `element_discovery.py` — inventory all buttons, links, inputs by role/type/text
- `console_logging.py` — capture browser console events
- `static_html_automation.py` — test local HTML via `file://`
- Headless Chromium, 1920x1080 viewport
- Pattern: navigate → wait `networkidle` → screenshot → discover → interact

**Integration path for Indrajaal**:
1. Install via: `/plugin marketplace add anthropics/skills && /plugin install example-skills`
2. `with_server.py` wraps `mix phx.server` or connects to existing container port 4000
3. For each Prajna page, the skill can:
   - Take baseline screenshot
   - Discover all interactive elements (tabs, buttons, trace rows)
   - Wait 2s, take diff screenshot to verify dynamic updates
   - Assert sparkline Unicode chars changed between screenshots
   - Validate tab switching, trace expansion, flash messages

**Custom Indrajaal skill** (via `skill-creator`):
```yaml
---
name: prajna-liveview-testing
description: Tests Prajna C3I cockpit LiveView pages for dynamic updates, Color Rich compliance, and SC-HMI verification. Use when testing any /cockpit/* route.
compatibility: Requires Phoenix app running on port 4000, Python 3.11+, Playwright installed.
---
```

**Other relevant skills**:
- `frontend-design` — relevant to Prajna cockpit aesthetic direction (SC-HMI-010)
- `mcp-builder` — relevant to sentinel-zenoh MCP server implementation
- `skill-creator` — meta-skill for building custom Indrajaal testing skills

**Verdict**: **Directly usable**. The `webapp-testing` skill integrates naturally with the existing Chrome DevTools MCP already configured in `.mcp.json`. A custom `prajna-liveview-testing` skill should be created for Indrajaal-specific test patterns.

### 8.3 Recommended 3-Tier Test Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY TEST TIERS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TIER 1: ExUnit LiveView Tests (In-process, fast)               │
│  ├─ Phoenix.LiveViewTest — render, assert, send events          │
│  ├─ 35 BDD scenarios from Section 6 above                      │
│  ├─ handle_info(:refresh) timer behavior                        │
│  ├─ PubSub message handling                                     │
│  ├─ Threshold transitions and edge cases                        │
│  └─ Runs in: mix test (<1s per test)                            │
│                                                                  │
│  TIER 2: Anthropic webapp-testing Skill (Browser, Playwright)   │
│  ├─ Headless Chromium screenshots at 1920x1080                  │
│  ├─ Element discovery (tabs, buttons, sparklines)               │
│  ├─ Dynamic update verification (screenshot diff over 2s)       │
│  ├─ Tab switching + trace expansion interaction                 │
│  ├─ Console log capture (LiveView WebSocket errors)             │
│  └─ Runs in: python with_server.py (~10s per page)              │
│                                                                  │
│  TIER 3: Chrome DevTools MCP (Visual, live inspection)          │
│  ├─ mcp__chrome-devtools__take_screenshot — full page capture   │
│  ├─ mcp__chrome-devtools__evaluate_script — DOM assertions      │
│  ├─ mcp__chrome-devtools__wait_for — dynamic element waits      │
│  ├─ mcp__chrome-devtools__get_console_message — error checks    │
│  ├─ Color Rich verification (SC-HMI-010)                        │
│  └─ Runs in: agent session (interactive, operator-guided)       │
│                                                                  │
│  OPTIONAL: NL Vision Agent (partarstu pattern, future)          │
│  ├─ Natural language test case definitions                      │
│  ├─ Vision-based element location (no selectors)                │
│  ├─ RAG-backed element memory across sessions                   │
│  └─ Reimplement in Elixir/Nx when Bumblebee vision matures     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Test Coverage Matrix (8x8 Fractal — SC-HMI-011)

| Element \ Layer | L1-Render | L2-Timer | L3-PubSub | L4-BEAM | L5-Threshold | L6-Sparkline | L7-Trend | L8-Edge |
|-----------------|-----------|----------|-----------|---------|-------------|-------------|---------|---------|
| Request Rate | 2.1 | 2.1 | 9.1 | — | 2.2 | 2.5 | 2.4 | 11.3 |
| Error Rate | 2.2 | 2.1 | 9.1 | — | 2.2 | 2.5 | 2.4 | 11.4 |
| P99 Latency | 2.3 | 2.1 | 9.1 | — | 2.3 | 2.5 | 2.4 | — |
| Active Conn | 3.1 | 3.1 | — | 3.1 | 3.4 | 2.5 | — | — |
| DB Pool | 3.2 | 3.2 | — | — | 3.4 | 2.5 | — | 11.5 |
| FLAME Util | 3.3 | 3.3 | — | 3.3 | 3.4 | 2.5 | — | — |
| Traces | 4.2-4.7 | **4.1** | **4.8** | — | 4.4-4.6 | — | — | 4.7 |
| SigNoz | 5.1,5.3 | **5.4** | — | 5.1 | — | — | — | — |

**Bold** = BUG scenarios that will fail until fixes applied.

---

## 10. Impact Analysis

| Order | Effect |
|-------|--------|
| 1st (Immediate) | Operator sees stale trace data, wrong node count, frozen SigNoz metrics |
| 2nd (Seconds) | Reduced situational awareness — slow traces not visible in real-time |
| 3rd (Minutes) | Missed performance degradation — no trace rotation means no new slow queries surface |
| 4th (Hours) | SLA violations go unnoticed if operator trusts frozen metrics |
| 5th (Days) | Compliance gap — SC-HMI-001 Dark Cockpit requires live data for all visible elements |

---

## 11. Decision Log

| Decision | Rationale |
|----------|-----------|
| Jitter-based simulation acceptable for Request Rate, Error Rate, P99 Latency | Real OTEL metrics pipeline not yet integrated; jitter provides visual dynamism |
| Real BEAM data for Active Connections and FLAME | `:erlang.ports()` and `:erlang.statistics(:run_queue)` are zero-cost and accurate |
| Trace rotation via simulation | Full OTEL trace collector is out of scope; simulated rotation demonstrates dynamism |
| 500ms refresh interval | Matches SC-PRF-050 (<50ms latency per update); 2 FPS is sufficient for monitoring |
| Anthropic webapp-testing skill for Tier 2 | Direct Playwright integration, officially maintained, headless Chromium, fits existing MCP toolchain |
| partarstu agent concepts only (not direct integration) | Java 25 + display requirement + archived status — pattern is valuable but stack is incompatible |
| 3-tier test architecture | Separates fast in-process (Tier 1), browser visual (Tier 2), operator-guided (Tier 3) |

---

## 12. Verification Criteria

- [ ] All 4 BUG-STATIC scenarios pass after code fixes
- [ ] All 35 BDD scenarios pass in ExUnit (Tier 1)
- [ ] Playwright webapp-testing skill captures before/after screenshots showing dynamic updates (Tier 2)
- [ ] Chrome DevTools MCP visual inspection confirms all sparklines animate (Tier 3)
- [ ] `mix compile` — 0 errors, 0 warnings
- [ ] `mix format --check-formatted` — pass
- [ ] Browser verification: all 6 sparklines animate, traces rotate, SigNoz metrics change
- [ ] Refresh cycle < 50ms (SC-PRF-050)

---

## 13. Retrospective Notes

### What Went Well
- BEAM intrinsics (ports, run_queue, process_count, wall_clock) provide zero-cost real data for 4 elements
- Sparkline component with Unicode block chars (▁▂▃▄▅▆▇█) gives excellent visual feedback
- Trend calculation from history slope is elegant and informative
- PubSub integration architecture is correct (just needs the update functions to be non-trivial)
- The `anthropics/skills` webapp-testing Playwright skill is directly applicable with minimal setup

### What Needs Improvement
- 4 static elements violate the "everything dynamic" principle for a monitoring dashboard
- `update_traces/1` being a no-op is a significant gap — traces are the #1 observability artifact
- SigNoz integration tab has zero dynamic data — entire tab is frozen at init values
- Existing test suite only checks module structure (5 tests) — no dynamic behavior coverage
- No Tier 2 (browser) or Tier 3 (visual) test coverage exists for any Prajna page

### Action Items
1. **P0**: Implement FIX-1 through FIX-4 (make all elements dynamic)
2. **P0**: Write ExUnit LiveView tests for all 35 BDD scenarios (Tier 1)
3. **P1**: Install `anthropics/skills` webapp-testing and create `prajna-liveview-testing` custom skill
4. **P1**: Write Gherkin feature file for BDD Level 5 coverage
5. **P2**: Create natural language test cases inspired by partarstu pattern
6. **P2**: Browser-verify all dynamic elements with Chrome DevTools MCP (Tier 3)
7. **P3**: Prototype Elixir/Nx vision-based element verification (future)
