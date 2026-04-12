# Planning Page — User Journeys & Component Specifications
# योजना पृष्ठ — उपयोगकर्ता यात्राएँ एवं घटक विनिर्देश

**Date**: 2026-04-12
**Version**: v22.6.1-DHARMA
**Page**: `/planning` (Concept F: Adaptive Cockpit Hybrid)
**Compliance**: SC-AGUI-UI-001..015, SC-HMI-001..080

---

## 1. Persona Definitions

| ID | Persona | Context | Device | Primary Goal | Frequency |
|----|---------|---------|--------|-------------|-----------|
| P1 | **Abhijit (Founder/Operator)** | On-call, incident response | iPhone 15 Pro (393x852) | Triage blocked P0 tasks instantly | 5-10x/day |
| P2 | **Abhijit (Architect)** | Architecture review, sprint planning | MacBook Air 13" (1440x900) | Analyze fractal layer health, plan interventions | 2-3x/day |
| P3 | **Claude/Gemini (AI Agent)** | Autonomous task execution | API (JSON) | Claim tasks, report progress, query status | Continuous |
| P4 | **Stakeholder (Demo)** | Board presentation, investor review | iPad Pro 12.9" (1024x1366) | Understand system health trends, velocity | 1x/week |
| P5 | **New Team Member** | Onboarding, learning the system | Desktop 1920x1080 | Understand task structure, find what to work on | First week |

---

## 2. Journey Map Overview

| # | Journey | Persona | Viewport | Duration | Components Used |
|---|---------|---------|----------|----------|-----------------|
| J1 | On-Call Triage | P1 | Mobile | 30-90s | C1,C4.zones,C9,C8 |
| J2 | Morning Standup | P2 | Desktop | 2-5min | C1,C2,C4,C5,C12,C11 |
| J3 | Sprint Planning | P2 | Desktop | 15-30min | C5,C7,C12,C9,C10,C8 |
| J4 | Incident Investigation | P1 | Desktop | 5-15min | C4,C9,C12,C11,C10,C8 |
| J5 | Architecture Health Review | P2 | Wide | 10-20min | C7,C12(fractal sidebar),C4,C9 |
| J6 | AI Agent Task Cycle | P3 | API | <1s | API:status,list,update |
| J7 | Stakeholder Demo | P4 | Tablet | 5-10min | C7,C1,C2,C5 |
| J8 | New Member Onboarding | P5 | Desktop | 15-30min | C4,C9,C5,C12,C10,C8 |
| J9 | End-of-Day Review | P2 | Desktop | 3-5min | C7,C11,C1,C4 |
| J10 | Cross-Layer Dependency Resolution | P2 | Wide | 10-20min | C12(sidebar),C4,C9,C6,C11 |

---

## 3. Journey J1: On-Call Triage (Mobile, 30-90s)

### 3.1 Scenario
Abhijit's phone buzzes at 2:47 AM. Telegram notification: "P0 BLOCKED: Guardian NIF crash isolation — L0 Constitutional". He opens the planning page on his iPhone to assess and act.

### 3.2 Step-by-Step Flow

```
STEP 1: Page Load (0-1.5s)
  Action: Open https://vm-1.tail55d152.ts.net:4100/planning on mobile
  Viewport: 393x852 (iPhone 15 Pro)
  Layout: Concept D (Triage) activates via CSS @media (max-width: 767px)
  
  Component C1 renders:
    ┌─────────────────────────────────────────┐
    │ [C3I] ● Live  Health: 92  [AI]   [≡]   │  44px
    └─────────────────────────────────────────┘
  
  KPI: T_fA < 1.5s (first paint)
  Data source: NIF plan_status() -> {active: 47, blocked: 12, p0: 3}
  WebSocket: Connects to /ws/planning, receives initial snapshot
```

**C1: Weather Bar (Mobile Compact)**
| Spec | Value |
|------|-------|
| Height | 44px |
| Elements | Brand mark (C3I), live dot (green 5px animated), health score, AI button, hamburger |
| Touch targets | AI: 44x44px, Hamburger: 44x44px |
| Data binding | `plan_status().health` -> health number |
| Update frequency | 1s via WebSocket heartbeat |
| Color logic | Health >= 90: green, >= 70: amber, < 70: red |
| WCAG | Contrast ratio >= 4.5:1 on all text |

```
STEP 2: Scan Critical Zone (1.5-3s)
  Action: Eyes scan Zone 1 (CRITICAL) — no scroll needed
  Zone 1 appears immediately below header
  
  Component C4.critical renders:
    ┌─────────────────────────────────────────┐
    │ !!! CRITICAL (3)              [expand]  │  28px, red bg
    ├─────────────────────────────────────────┤
    │ ┌─────────────────────────────────────┐ │
    │ │ T001  Guardian NIF crash      [P0]  │ │  80px card
    │ │ L0 Constitutional · 3 days ago      │ │
    │ │                                     │ │
    │ │ [Activate]  [Escalate]  [Detail]    │ │  44px buttons
    │ └─────────────────────────────────────┘ │
    │ ┌─────────────────────────────────────┐ │
    │ │ T005  Build pipeline fix      [P0]  │ │  80px card
    │ │ L4 System · 5 days ago              │ │
    │ │                                     │ │
    │ │ [Activate]  [Escalate]  [Detail]    │ │
    │ └─────────────────────────────────────┘ │
    │ ┌─────────────────────────────────────┐ │
    │ │ T009  Zenoh quorum split      [P0]  │ │  80px card
    │ │ L6 Ecosystem · 1 day ago            │ │
    │ │                                     │ │
    │ │ [Activate]  [Escalate]  [Detail]    │ │
    │ └─────────────────────────────────────┘ │
    └─────────────────────────────────────────┘
  
  KPI: S_b = 0px (blocked tasks visible without scroll)
  KPI: C_L = 3 visual groups (Critical/Attention/Nominal)
```

**C4.critical: Critical Zone**
| Spec | Value |
|------|-------|
| Placement | Immediately below C1 header, no scroll |
| Left border | 4px solid #ff4757 (red) |
| Zone header | 28px, dark red background (#321010), white text |
| Card height | 80px (title + layer/age + action row) |
| Card border | 2px solid #ff4757 + box-shadow: 0 0 8px rgba(255,71,87,0.3) |
| Card content | Line 1: Task ID + Title (16px, #e0e6ed) |
| | Line 2: Layer name + " · " + age (14px, #7a8fa6) |
| | Line 3: 3 action buttons (equal width, 44px height) |
| Priority badge | 36x20px, top-right corner, P0=#ff4757, P1=#ffa502, P2=#2ed573 |
| Max cards shown | 5 (scroll within zone if more) |
| Data source | NIF plan_list_by_status("blocked") filtered by priority == 0 |
| Sort order | Priority ASC, then age DESC (oldest first) |
| Touch target | Card: full width tap -> detail panel. Buttons: 44px min |

**C4.critical Action Buttons**
| Button | Label | Color | Width | Action | API Call |
|--------|-------|-------|-------|--------|----------|
| Activate | "Activate" | #3dd68c (green) | 33% - 4px | Move task to active status | POST /api/v1/tasks/{id}/status {"status": "active"} |
| Escalate | "Escalate" | #f5a623 (amber) | 33% - 4px | Move to P0 + send notification | POST /api/v1/tasks/{id}/escalate |
| Detail | "Detail" | #4d96ff (blue) | 33% - 4px | Open full detail panel (C9) | Client-side navigation |

```
STEP 3: Tap Detail on T001 (3-5s)
  Action: Tap [Detail] button on "Guardian NIF crash isolation"
  
  Component C9 renders (full-screen slide-up on mobile):
    ┌─────────────────────────────────────────┐
    │ [←]  Task Detail              [Close]   │  44px header
    ├─────────────────────────────────────────┤
    │                                         │
    │ T001 — Guardian NIF crash isolation      │  Title
    │ ─────────────────────────────────────── │
    │ Status: BLOCKED  [P0]  L0 Constitutional│  Meta row
    │ Created: 2026-04-09  Age: 3 days        │
    │ Owner: AN                               │
    │ ─────────────────────────────────────── │
    │                                         │
    │ Description:                            │
    │ The c3i_nif.so crashes when Guardian    │
    │ attempts to verify Psi-0 invariant on   │
    │ cold boot. Segfault in zenoh_session_   │
    │ open() when router is unreachable.      │
    │ ─────────────────────────────────────── │
    │                                         │
    │ STAMP References:                       │
    │ • SC-NIF-003 (panic=unwind)             │
    │ • SC-GUARD-002 (fail closed)            │
    │ • SC-PRIME-001 (constitutional axiom)   │
    │ ─────────────────────────────────────── │
    │                                         │
    │ 5 Actions:                              │
    │ ┌──────────┐ ┌──────────┐              │
    │ │Knowledge │ │ Related  │              │  44px
    │ └──────────┘ └──────────┘              │
    │ ┌──────────┐ ┌──────────┐              │
    │ │  STAMP   │ │Sub-Tasks │              │  44px
    │ └──────────┘ └──────────┘              │
    │ ┌──────────────────────┐               │
    │ │    AI Analysis       │               │  44px
    │ └──────────────────────┘               │
    │                                         │
    └─────────────────────────────────────────┘
```

**C9: Detail Panel (Mobile Full-Screen)**
| Spec | Value |
|------|-------|
| Presentation | Full-screen slide-up (transform: translateY) |
| Animation | 200ms ease-out slide from bottom |
| Header | 44px, back arrow (left) + close X (right) |
| Content sections | Title, Meta (status/priority/layer/age/owner), Description, STAMP refs, Actions |
| Title font | 18px bold, #e0e6ed |
| Meta row | Inline badges: status badge + priority badge + layer badge |
| Description | 14px, #e0e6ed, max-height 200px with scroll |
| STAMP refs | Bulleted list, each ref is tappable (links to constraint doc) |
| 5 Actions | Grid of 5 buttons (2x2 + 1 full-width) |
| Action: Knowledge | Search Zettelkasten for related holons. API: GET /api/v1/knowledge/search?q={title} |
| Action: Related | Find tasks in same fractal layer. API: GET /api/v1/tasks?layer={layer} |
| Action: STAMP | Show all STAMP constraints referenced by this task |
| Action: Sub-Tasks | List child tasks (hierarchical numbering) |
| Action: AI Analysis | Send task to Gemma for root cause analysis. API: POST /api/v1/ai/analyze |
| Close | Tap back arrow, close X, or swipe down |
| Data source | NIF plan_get(task_id) -> full task JSON |

```
STEP 4: Tap AI Analysis (5-10s)
  Action: Tap [AI Analysis] button
  
  Component C10 activates within C9:
    ┌─────────────────────────────────────────┐
    │ AI Analysis — T001                      │
    │ ─────────────────────────────────────── │
    │                                         │
    │ [Gemma 3 — analyzing...]                │
    │ ████████░░░░░░░░░░░░ (shimmer)          │
    │                                         │
    │ (after 3-5s):                           │
    │                                         │
    │ Root Cause: The Zenoh session_open()    │
    │ call in c3i_nif.so does not handle the  │
    │ case where the router endpoint is       │
    │ unreachable at boot time. The NIF       │
    │ returns a panic instead of an Erlang    │
    │ error tuple, violating SC-NIF-003.      │
    │                                         │
    │ Recommended Fix:                        │
    │ 1. Wrap zenoh::open() in catch_unwind() │
    │ 2. Return {:error, :zenoh_unreachable}  │
    │ 3. Add 3-retry with exponential backoff │
    │                                         │
    │ Confidence: 0.87 (Gemma 3, 3.1s)       │
    │ [model: gemma3:4b]                      │
    └─────────────────────────────────────────┘
```

**C10: Gemma AI Chat (Inline Analysis Mode)**
| Spec | Value |
|------|-------|
| Trigger | "AI Analysis" action button in C9 |
| Mode | Inline within detail panel (not separate widget) |
| Loading | Shimmer animation bar, "Gemma 3 — analyzing..." text |
| Timeout | 15s AbortController. If timeout: try Gemma 4 (port 11435) |
| System prompt | "You are analyzing task {id}: {title}. Context: {description}. Status: {status}. Layer: {layer}. STAMP: {stamp_refs}. Current system: {plan_status_json}. Provide root cause analysis and recommended fix." |
| API | POST http://localhost:11434/api/chat with message array |
| Response display | Markdown-formatted, 14px, max-height 300px scroll |
| Confidence | Displayed as float (model's self-assessment if available) |
| Model label | Shows which Gemma responded (3 or 4) |
| Fallback | If both models offline: "AI analysis unavailable. Use Knowledge search instead." |

```
STEP 5: Act — Tap Activate (10-15s)
  Action: Navigate back to triage, tap [Activate] on T001
  
  Result:
    - API call: POST /api/v1/tasks/T001/status {"status": "active"}
    - sa-plan-daemon updates Smriti.db
    - WebSocket pushes updated status to all clients
    - Card animates out of Critical zone (300ms fade + slide)
    - Critical count updates: (3) -> (2)
    - Change log entry added: "T001 status: blocked -> active"
    - OTel span published: indrajaal/otel/spans/planning/task_activate
  
  Component C11 updates:
    ┌─────────────────────────────────────────┐
    │ [2:48 AM] T001 blocked -> active (by AN)│
    └─────────────────────────────────────────┘
```

**C11: Change Log (Mobile — Minimal)**
| Spec | Value |
|------|-------|
| Visibility | Hidden on mobile by default. Shown as toast notification (3s) |
| Toast position | Bottom of screen, above bottom nav bar |
| Toast content | Timestamp + task ID + change description |
| Toast animation | Slide up 200ms, hold 3s, fade out 500ms |
| Max entries | 50 in memory, most recent first |
| Entry format | `[HH:MM] T{id} {field}: {old} -> {new} (by {actor})` |
| Data source | WebSocket "update" messages with diff detection |

```
STEP 6: Done — Lock Phone (15-30s total)
  Action: Verify Critical count is now (2), lock phone
  Total journey time: 15-30 seconds
  Tasks completed: 1 task moved from blocked to active
  Cognitive load: Minimal (3 zones, 3 buttons per card)
```

### 3.3 Journey J1 Component Summary

| Component | Usage | Duration Visible | Interactions |
|-----------|-------|-----------------|--------------|
| C1 Weather Bar | Ambient health awareness | Entire journey | 0 (glance only) |
| C4.critical Zone | Primary decision surface | Steps 2-5 | 2 (scan + tap) |
| C9 Detail Panel | Deep dive on one task | Steps 3-4 | 3 (open, AI, close) |
| C10 Gemma AI | Root cause analysis | Step 4 | 1 (auto-triggered) |
| C11 Change Log | Confirmation feedback | Step 5 | 0 (toast auto-shown) |

---

## 4. Journey J2: Morning Standup (Desktop, 2-5min)

### 4.1 Scenario
Abhijit opens the planning page at 9:00 AM on his MacBook to prepare for the morning standup. He needs to know: what's blocked, what progressed overnight, and what to prioritize today.

### 4.2 Step-by-Step Flow

```
STEP 1: Page Load (0-2s)
  Viewport: 1440x900 (MacBook Air)
  Layout: Concept F hybrid — Bloomberg grid + Fractal sidebar
  
  Full layout renders:
    ┌────────────────────────────────────────────────────────────────────┐
    │ C3I ● Live  Act:47 Blk:12 P0:3  Health:92 ▲+0.3/h  OODA:28ms   │ C1
    ├────────────────────────────────────────────────────────────────────┤
    │ [Grid]* [Kanban] [Timeline] [Analytics] [Fractal] | Ctrl+K | L3▼ │ Controls
    ├──────────┬─────────────────────────────────────────────────────────┤
    │ FRACTAL  │ ID  | Title              | Status | P | Owner| Age| L │ C4
    │ HEALTH   │ T001| Guardian NIF...    | BLOCK  | 0 | AN   | 3d | L0│
    │          │ T005| Build pipeline...  | BLOCK  | 0 | AN   | 5d | L4│
    │ L0 95%   │ T009| Zenoh quorum...    | BLOCK  | 0 | CL   | 1d | L6│
    │ L1 88%   │ T012| Auth timeout...    | BLOCK  | 1 | AN   | 2d | L3│
    │ L2 92%   │ ... | (15 visible rows)  |        |   |      |    |   │
    │ L3 85%   │     |                    |        |   |      |    |   │
    │ L4 78% ! │     |                    |        |   |      |    |   │
    │ L5 91%   │     |                    |        |   |      |    |   │
    │ L6 82%   │     |                    |        |   |      |    |   │
    │ L7 94%   │     |                    |        |   |      |    |   │
    ├──────────┴─────────────────────────────────────────────────────────┤
    │ d(H)/dt: +0.3/h  IMPROVING  SLO:99.2%  Budget:0.8%  WS:1s ago   │ C11
    └────────────────────────────────────────────────────────────────────┘
```

**C1: Weather Bar (Desktop Full)**
| Spec | Value |
|------|-------|
| Height | 32px |
| Layout | Flex row, space-between |
| Left group | Brand "C3I" (accent bg), live dot (animated green), "Live" label |
| Center group | Act:{n} (green badge), Blk:{n} (red badge), P0:{n} (red pulse badge) |
| Right group | Health:{n} (color-coded), d(H)/dt trend arrow, OODA latency |
| Health bar | 120px horizontal bar, filled proportionally, color by health score |
| d(H)/dt | Arrow: ▲ green if positive, ▼ red if negative, ► amber if zero |
| Data source | NIF plan_status() + health_calculus derivative |
| Update | 1s WebSocket, only re-render on change (diff detection) |

**C12: Fractal Sidebar (Wide Desktop Only)**
| Spec | Value |
|------|-------|
| Width | 180px fixed, left side |
| Visibility | @media (min-width: 1400px) only |
| Header | "FRACTAL HEALTH" in accent color, 12px |
| Layers | 8 rows (L0-L7), each 90px tall |
| Per-layer content | Layer dot (color) + short name (e.g., "L0 CONST") |
| | Health bar: 120px wide, color by health (red<80, amber<90, green>=90) |
| | Health percentage text (e.g., "95%") |
| | Blocked/active counts (e.g., "3 blk  2 act") in red/blue |
| Layer separator | 0.5px border-bottom, #1e2a3a |
| Click behavior | Click layer -> filter main grid to only that layer's tasks |
| Active filter | Selected layer has accent left border (4px) |
| Clear filter | Click selected layer again, or click "All" chip |
| Data source | Computed from task list: group by layer, count by status |
| Health formula | `health(L) = 1 - (blocked_count * severity_weight) / total_count` |

```
STEP 2: Glance at Fractal Health (2-5s)
  Action: Eyes scan the fractal sidebar
  Insight: L4 SYSTEM at 78% (RED) — 2 blocked tasks
  Decision: L4 needs attention today
  
  Component C12 fractal sidebar highlights:
    L4 SYST  ███████░░░░  78%  [!]
             2 blk  3 act
  
  KPI: 0 clicks to see which layer is degraded
```

```
STEP 3: Filter by L4 (5-10s)
  Action: Click "L4 SYST" in fractal sidebar
  
  Result:
    - Main grid filters to L4 tasks only
    - Fractal sidebar: L4 row gets accent left border
    - Grid shows: T005 (Build pipeline, BLOCKED, P0, 5d)
                  T003 (Hot reload, ACTIVE, P1, 1d)
                  T017 (DNS resolution, BLOCKED, P1, 4d)
    - URL updates: /planning?layer=4 (shareable)
    - OTel span: indrajaal/otel/spans/planning/filter_layer
```

**C4: Task Grid (Desktop Bloomberg)**
| Spec | Value |
|------|-------|
| Position | Right of fractal sidebar (or full width if sidebar hidden) |
| Columns | ID (60px), Title (flex-grow), Status (80px), P (40px), Owner (60px), Age (50px), Layer (80px) |
| Column headers | Accent color text, sortable (click to toggle ASC/DESC) |
| Header filters | Text input per column header (Tabulator headerFilter) |
| Row height | 36px |
| Row alternation | Even rows: #0e121c, Odd rows: transparent |
| Status left border | 3px solid: red=BLOCKED, blue=ACTIVE, gray=PENDING, green=COMPLETED |
| Status badge | Rounded rect, filled with status color, dark text |
| Priority badge | Small rounded rect: P0=red, P1=amber, P2=green, P3=gray |
| Layer indicator | Color dot (5px) + layer short name in layer color |
| Age coloring | Green: <1d, Amber: 1-7d, Red: >7d |
| Hover | Row background: #1a2030, cursor: pointer |
| Click | Opens C9 detail panel (slide-in from right, 400px wide) |
| Sort default | Status ASC (BLOCKED first), then Priority ASC, then Age DESC |
| Pagination | None — continuous virtual scroll (Tabulator) |
| Row count | Visible: ~15 rows at 36px in 540px grid height |
| Data source | NIF plan_list_by_status("all") or filtered by fractal layer |
| Update | WebSocket diff detection — changed rows get "row-changed" CSS class (1.8s fade) |
| Export | Footer buttons: CSV, JSON |
| Empty state | "No tasks match current filters" in muted text, centered |

```
STEP 4: Switch to Kanban View (10-30s)
  Action: Press keyboard "2" or click [Kanban] tab
  
  Layout changes to Concept B:
    ┌────────────────────────────────────────────────────────────────────┐
    │ C3I ● Live  Act:47 Blk:12 P0:3  Health:92 ▲+0.3/h  OODA:28ms   │
    ├────────────────────────────────────────────────────────────────────┤
    │ [Grid] [Kanban]* [Timeline] [Analytics] [Fractal] | Ctrl+K | L3▼ │
    ├────────────────┬────────────────┬────────────────┬─────────────────┤
    │ BLOCKED (12)   │ PENDING (85)   │ ACTIVE (47)    │ DONE (234)     │
    │ [red header]   │ [gray header]  │ [blue header]  │ [green, coll.] │
    │ ┌────────────┐ │ ┌────────────┐ │ ┌────────────┐ │                │
    │ │T001 [P0]   │ │ │T023 [P1]   │ │ │T002 [P1]   │ │ 234 completed  │
    │ │Guard NIF   │ │ │MCP wire    │ │ │Zenoh fed   │ │ [tap expand]   │
    │ │L0 · 3d     │ │ │L5 · 3d     │ │ │L6 · 12h    │ │                │
    │ │[red glow]  │ │ │            │ │ │[blue bdr]  │ │                │
    │ └────────────┘ │ └────────────┘ │ └────────────┘ │                │
    │ ┌────────────┐ │ ┌────────────┐ │ ┌────────────┐ │                │
    │ │T005 [P0]   │ │ │T034 [P2]   │ │ │T003 [P1]   │ │                │
    │ │Build pipe  │ │ │Badge CSS   │ │ │Hot reload  │ │                │
    │ │L4 · 5d     │ │ │L2 · 1d     │ │ │L4 · 1d     │ │                │
    │ └────────────┘ │ └────────────┘ │ └────────────┘ │                │
    │ (+ 10 more)    │ (+ 83 more)    │ (+ 45 more)    │                │
    ├────────────────┴────────────────┴────────────────┴─────────────────┤
    │ P0:3 P1:28 P2:45 P3:12  Avg:4.2d  OODA:28ms  ● Connected        │
    └────────────────────────────────────────────────────────────────────┘
```

**C5: Kanban Board (Desktop 4-Column)**
| Spec | Value |
|------|-------|
| Layout | 4 equal-width columns, flex row |
| Column headers | Full-width rounded rect with status color, white text |
| Column order | BLOCKED, PENDING, ACTIVE, DONE |
| Card width | Column width - 16px padding |
| Card height | 90px (auto-expand for long titles) |
| Card content | Line 1: ID + priority badge (right-aligned) |
| | Line 2: Title (14px, bold, #e0e6ed, max 2 lines with ellipsis) |
| | Line 3: Layer dot + layer short name + " · " + age |
| Card border | P0: 2px red + glow shadow. P1: 1px amber. P2: 1px blue. P3: 1px gray |
| Card background | #141922 |
| Card hover | Border brightens, subtle elevation shadow |
| Card click | Opens C9 detail panel |
| Column scroll | Independent vertical scroll per column |
| DONE column | Collapsed by default (shows count + "tap to expand") |
| Drag-drop | NOT YET IMPLEMENTED (P2 roadmap). Visual drag cursor but no action. |
| Virtual scroll | Cards lazy-loaded: first 20 per column, load more on scroll |
| Empty column | "No {status} tasks" in muted centered text |
| Fractal filter | Active filter (from C12 or chips) applies to all columns |

```
STEP 5: Check Change Log (30s-1min)
  Action: Glance at bottom ticker bar
  
  Component C11 shows:
    [9:01] T002 status: pending -> active (by claude-1)
    [8:45] T067 status: pending -> active (by gemini-2)
    [8:30] T099 status: active -> completed (by claude-1)
  
  Insight: AI agents were productive overnight
```

**C11: Change Log (Desktop Ticker)**
| Spec | Value |
|------|-------|
| Position | Bottom bar, 20-24px height |
| Layout | Horizontal scrolling text (marquee-style) or static last entry |
| Entry format | `[HH:MM] T{id} {field}: {old} -> {new} (by {actor})` |
| Entry types | status_change, priority_change, new_task, task_removed, data_diff |
| Max entries | 50 in memory, newest first |
| Auto-scroll | Latest entry shown, scrolls left to reveal history |
| Expandable | Click to expand into full change log panel (300px height) |
| Data source | WebSocket "update" messages with before/after diff |
| Timestamps | HH:MM format (local timezone) |
| Actor | "AN" for human, "claude-1" / "gemini-2" for AI agents |

```
STEP 6: Search for Specific Task (1-2min)
  Action: Press Ctrl+K, type "zenoh"
  
  Component C8 activates:
    ┌────────────────────────────────────────┐
    │ 🔍 zenoh                        [Esc] │  Search input
    ├────────────────────────────────────────┤
    │ T002  Zenoh multi-region federation   │  Result 1
    │ T009  Zenoh quorum split-brain        │  Result 2
    │ T078  Mesh topology visualization     │  Result 3 (keyword match)
    │                                       │
    │ Zettelkasten: 14 holons matching      │  Knowledge results
    │ • "Zenoh session lifecycle" (L6)      │
    │ • "Split-brain detection" (L0)        │
    └────────────────────────────────────────┘
```

**C8: AI Search (Desktop Overlay)**
| Spec | Value |
|------|-------|
| Trigger | Ctrl+K keyboard shortcut, or click search input in controls bar |
| Presentation | Modal overlay, 600px wide, centered horizontally, 200px from top |
| Input | Full-width text input, 44px height, auto-focus, monospace font |
| Debounce | 200ms after last keystroke before firing search |
| Search sources | 1. Task title/description (NIF plan_search). 2. Zettelkasten FTS5 |
| Result groups | "Tasks" section (max 10) + "Knowledge" section (max 5) |
| Result format | Task: ID + title + status badge. Knowledge: title + layer badge |
| Result click | Task: opens C9 detail. Knowledge: opens in new tab or inline |
| Grid filter | While search active, main grid filters to matching tasks in real-time |
| Empty state | "No matches for '{query}'" |
| Close | Esc key, click outside, or clear input |
| API | NIF plan_search(query) for tasks, GET /api/v1/knowledge/search for Zettelkasten |
| Latency | Task search: <1ms (NIF). Zettelkasten: <4ms (FTS5 RAG) |

---

## 5. Journey J3: Sprint Planning (Desktop, 15-30min)

### 5.1 Scenario
Abhijit reviews the full task board to plan the week's sprint. He needs to assess priority distribution, identify stale tasks, analyze by fractal layer, and consult AI for prioritization advice.

### 5.2 Key Steps

```
STEP 1: Open Analytics View (keyboard "4")
  
  Component C7 renders:
    ┌─────────────────────────────┬─────────────────────────┬──────────────────┐
    │ HEALTH TRAJECTORY           │ PRIORITY DISTRIBUTION   │ AGE HISTOGRAM    │
    │                             │                         │                  │
    │      ___/```                │ P0 ███ 3                │ <1d ████████ 47  │
    │  ___/                       │ P1 ████████████ 28      │ 1-3d ██████ 85   │
    │ /    85 -> 92 (+8.2%)       │ P2 ██████████████ 45    │ 3-7d ████ 34     │
    │                             │ P3 █████ 12             │ >7d ██ 12        │
    ├─────────────────────────────┴─────────────────────────┴──────────────────┤
    │                                                                          │
    │ FRACTAL DISTRIBUTION            │ STATUS FLOW (SANKEY)                   │
    │                                 │                                        │
    │ L0 ████ 5 tasks                 │ Pending ──┬── Active ──┬── Completed  │
    │ L1 ██ 2 tasks                   │           │            │              │
    │ L2 ████████ 10 tasks            │     85 ───┤──── 47 ────┤──── 234     │
    │ L3 ████████████ 25 tasks        │           │            │              │
    │ L4 ██████ 12 tasks              │ Blocked ──┘            │              │
    │ L5 ████████ 15 tasks            │     12 ────────────────┘              │
    │ L6 ████ 8 tasks                 │                                        │
    │ L7 ██ 3 tasks                   │ Velocity: 4.2 tasks/day               │
    └─────────────────────────────────┴────────────────────────────────────────┘
```

**C7: Analytics Dashboard**
| Spec | Value |
|------|-------|
| Layout | 2-row grid. Row 1: 3 charts. Row 2: 2 charts |
| Row 1 heights | 200px per chart |
| Row 2 heights | 300px per chart |
| Chart: Health Trajectory | Sparkline, 7-day window, green area fill, score labels at start/end |
| Chart: Priority Dist | Horizontal bar chart, 4 bars (P0-P3), color-coded, count labels |
| Chart: Age Histogram | 4 buckets (<1d, 1-3d, 3-7d, >7d), color-coded (green->red), count labels |
| Chart: Fractal Dist | 8 bars (L0-L7), layer-colored, task count labels, click to filter |
| Chart: Status Flow | Sankey diagram: Pending->Active->Completed, Blocked->Active, width=count |
| Render | Pure CSS/SVG (no chart library). Bars are div elements with width%. |
| Data source | Computed from plan_list("all"): group by priority/age/layer/status |
| Update | 5s interval (analytics don't need 1s refresh) |
| Interactions | Click bar segment -> filter grid to that segment |

```
STEP 2: Identify Stale Tasks (1-2min)
  Action: Click ">7d" bar in Age Histogram
  Result: Grid filters to 12 tasks older than 7 days
  
  Insight: 3 of 12 stale tasks are in L4 (System) — build pipeline issues
  Action: Right-click task -> "Escalate to P0" or "Mark as blocked"
```

```
STEP 3: Consult Gemma for Prioritization (2-3min)
  Action: Open AI chat (click [AI] in header)
  
  Component C10 renders as floating panel:
    ┌──────────────────────────────────────┐
    │ Gemma AI Assistant          [−] [×]  │
    ├──────────────────────────────────────┤
    │                                      │
    │ You: What should I prioritize this   │
    │ week given current system health?    │
    │                                      │
    │ Gemma 3 (3.2s):                      │
    │ Based on current state (47 active,   │
    │ 12 blocked, health 92):              │
    │                                      │
    │ 1. L4 System (78% health) — Unblock  │
    │    T005 Build pipeline first. It     │
    │    blocks 3 downstream tasks.        │
    │                                      │
    │ 2. L0 Constitutional — T001 Guardian │
    │    NIF is safety-critical (SC-NIF).  │
    │    Resolve before any deploy.        │
    │                                      │
    │ 3. L6 Ecosystem — T009 Zenoh quorum  │
    │    affects mesh connectivity for all │
    │    telemetry (SC-ZENOH-001).         │
    │                                      │
    │ ┌──────────────────────────────────┐ │
    │ │ Type a message...          [Send]│ │
    │ └──────────────────────────────────┘ │
    └──────────────────────────────────────┘
```

**C10: Gemma AI Chat (Desktop Floating Panel)**
| Spec | Value |
|------|-------|
| Position | Bottom-right corner, 400px wide, 500px tall |
| Presentation | Floating panel with minimize/close buttons |
| Minimize | Collapses to 44px icon in bottom-right |
| Message history | Scrollable list, max 50 messages |
| User message | Right-aligned, accent background, dark text |
| AI message | Left-aligned, card background, light text |
| Typing indicator | 3-dot shimmer animation while waiting for response |
| Model label | Small badge showing "Gemma 3" or "Gemma 4" |
| Input | Full-width text input, 44px, "Type a message..." placeholder |
| Send | Enter key or Send button |
| System prompt | Enriched with live data: `"Status: {total} tasks, {active} active, {blocked} blocked, health {score}. Layer health: {L0: 95%, L1: 88%, ..., L7: 94%}."` |
| API | POST http://localhost:11434/api/chat (Gemma 3, 15s timeout) -> fallback POST http://localhost:11435/api/chat (Gemma 4) |
| Context | Last 5 messages + system prompt + current task data |

---

## 6. Journey J4: Incident Investigation (Desktop, 5-15min)

### 6.1 Scenario
A Zenoh mesh partition is detected. Abhijit needs to find all related tasks, understand the dependency chain, and identify the root cause.

```
STEP 1: Search "zenoh" (Ctrl+K)
  -> 3 task results + 14 Zettelkasten holons
  
STEP 2: Filter by L6 Ecosystem (click L6 in sidebar)
  -> Grid shows 8 L6 tasks: 2 blocked, 2 active, 4 pending
  
STEP 3: Open T009 "Zenoh quorum split-brain" detail (C9)
  -> See STAMP refs: SC-SIL4-015, SC-ZENOH-001, SC-ZENOH-002
  -> See related tasks in same layer
  
STEP 4: Click "Related" action in C9
  -> Shows: T002 (Zenoh federation, ACTIVE), T078 (Mesh topo, PENDING)
  -> Dependency: T009 blocks T002 (can't federate with split-brain)
  
STEP 5: Click "Knowledge" action in C9
  -> Zettelkasten search: "Zenoh quorum split-brain"
  -> Returns: 3 holons including prior journal entry about similar issue
  -> Journal from 2026-04-05: "Resolved by restarting zenoh-router-2"
  
STEP 6: Switch to Timeline view (keyboard "3")
  -> See temporal view of all L6 tasks
  -> T009 created 1 day ago, T002 active for 12h, T078 pending 5d
  
STEP 7: AI Analysis on T009 (C10)
  -> Gemma suggests: "Check if zenoh-router-2 lost quorum due to memory pressure.
     Prior incident (2026-04-05) was same root cause."
```

**C6: Timeline View**
| Spec | Value |
|------|-------|
| Layout | Horizontal Gantt-style bars |
| Y-axis | Tasks, sorted by creation date (oldest top) |
| X-axis | Time (7-day window, today = right edge) |
| Bar color | Status-coded: red=BLOCKED, blue=ACTIVE, gray=PENDING, green=COMPLETED |
| Bar height | 24px with 4px gap |
| Bar start | Task creation date |
| Bar end | Current time (for active/blocked) or completion date |
| Priority indicator | Left edge marker: P0=red dot, P1=amber dot |
| Hover | Tooltip: task title, status, age, priority |
| Click | Opens C9 detail panel |
| Scroll | Horizontal scroll for time, vertical scroll for tasks |
| Today line | Vertical dashed line at current time, labeled "Now" |
| Fractal filter | Active filter applies (shows only filtered layer's tasks) |
| Mobile | Hidden (too narrow for Gantt). Switch to list sorted by date. |

---

## 7. Journey J5: Architecture Health Review (Wide Desktop, 10-20min)

```
STEP 1: Wide viewport (1440px+) — Fractal sidebar visible
  Scan all 8 layers: L0=95%, L1=88%, L2=92%, L3=85%, L4=78%(!), L5=91%, L6=82%, L7=94%
  
STEP 2: Click L4 SYSTEM in sidebar -> grid filters to L4
  See: 2 blocked (T005, T017), 3 active (T003, T032, T041)
  Health formula: 1 - (2 * 3 + 0 * 2) / (5 * 3) = 1 - 6/15 = 0.60... wait, that's lower
  Actual: considers severity weights and total including pending
  
STEP 3: Switch to Analytics (keyboard "4")
  Fractal Distribution chart: L3 has most tasks (25), L4 has worst health
  Status Flow sankey: 12 blocked tasks bottleneck the pipeline
  
STEP 4: Switch to Fractal View (keyboard "5")
  Full Concept E layout: 8 horizontal lanes
  Visual: L4 lane has 2 red-bordered chips (blocked), 3 blue chips (active)
  L3 lane most crowded (25 tasks) but health is 85% (only 4 blocked)
  
STEP 5: Export data (CSV from grid footer)
  Click CSV -> downloads planning_export_20260412.csv
  Contains: all tasks with ID, title, status, priority, layer, age, owner
```

**C12: Fractal Filter Chips (Controls Bar)**
| Spec | Value |
|------|-------|
| Position | Right side of controls bar, after search |
| Layout | Horizontal chip group |
| Chips | "All" + L0-L7 (8 layer chips) |
| Chip size | 50x24px, rounded corners |
| Chip color | Border in layer color, text in layer color |
| Active chip | Filled background in layer color, dark text |
| Click | Toggle filter — single-select (click same to clear) |
| Keyboard | No keyboard shortcut (use Ctrl+K search instead) |
| State sync | Synced with fractal sidebar — clicking sidebar updates chips and vice versa |
| URL | Filter state reflected in URL query: ?layer=4 |

---

## 8. Journey J6: AI Agent Task Cycle (API, <1s)

### 8.1 Scenario
Claude agent claims a task, works on it, and reports completion — entirely via API.

```
STEP 1: Query status
  GET /api/v1/planning/status
  Response: {"active": 47, "blocked": 12, "pending": 85, "completed": 234, "p0": 3}
  
STEP 2: List pending P1 tasks
  GET /api/v1/planning/tasks?status=pending&priority=1
  Response: [{"id": "T023", "title": "MCP tool dispatch wiring", "layer": 5}, ...]
  
STEP 3: Claim task
  POST /api/v1/planning/tasks/T023/status
  Body: {"status": "active", "actor": "claude-1"}
  Response: {"ok": true, "task": {...}}
  
STEP 4: (Agent works on task — 5-30 minutes)
  
STEP 5: Complete task
  POST /api/v1/planning/tasks/T023/status
  Body: {"status": "completed", "actor": "claude-1"}
  Response: {"ok": true}
  
  Side effects:
    - WebSocket pushes update to all clients
    - Change log entry added
    - OTel span published
    - Smriti.db updated atomically
```

**API Endpoints (Wisp REST)**
| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| /api/v1/planning/status | GET | Summary counts | JSON: active, blocked, pending, completed, p0, health |
| /api/v1/planning/tasks | GET | List tasks with filters | JSON array, params: status, priority, layer, limit |
| /api/v1/planning/tasks/{id} | GET | Single task detail | JSON object with all fields |
| /api/v1/planning/tasks/{id}/status | POST | Update status | JSON: {status: "active"/"completed"/"blocked"} |
| /api/v1/planning/tasks/{id}/escalate | POST | Escalate to P0 | JSON: {ok: true} |
| /api/v1/planning/search?q={query} | GET | Search tasks + knowledge | JSON: {tasks: [...], knowledge: [...]} |
| /api/v1/planning/export | GET | CSV/JSON export | File download, params: format=csv/json |
| /ws/planning | WS | Real-time updates | Bidirectional: ping/search/status |

---

## 9. Journey J7: Stakeholder Demo (Tablet, 5-10min)

```
STEP 1: Tablet viewport (1024x1366) -> Concept A grid (no sidebar)
  Show: clean grid with status badges, priority colors
  
STEP 2: Switch to Analytics (tap Analytics tab)
  Show: Health trajectory chart — "We improved from 85 to 92 this week"
  Show: Priority distribution — "Only 3 P0 critical issues remain"
  Show: Age histogram — "Most tasks are under 3 days old"
  
STEP 3: Switch to Kanban (tap Kanban tab)
  Show: Visual workflow — "12 blocked, 47 active, 234 completed"
  Show: P0 red glow cards — "These 3 need attention"
  
STEP 4: Open Gemma chat
  Ask: "Summarize system health in one paragraph for the board"
  Gemma: "The C3I mesh is operating at 92% health with a positive
          improvement trend of +0.3%/hour. 47 tasks are actively being
          processed by AI agents, with only 3 P0 critical blockers
          remaining. The primary risk is L4 System layer at 78% health
          due to build pipeline issues, expected to resolve within 24h."
```

---

## 10. Journey J8: New Member Onboarding (Desktop, 15-30min)

```
STEP 1: Land on /planning — see Bloomberg grid
  Overwhelm: 178 tasks visible. Where to start?
  
STEP 2: Click fractal filter "L3" (Transaction)
  Grid filters to 25 L3 tasks — familiar territory for a backend dev
  
STEP 3: Sort by Priority (click P column header)
  See: P1 tasks in L3 that are pending — these are claimable
  
STEP 4: Open task detail (click T015 "SQLite WAL checkpoint tuning")
  See: Description explains the task clearly
  See: STAMP refs link to constraint documentation
  Action: "Knowledge" -> finds 3 Zettelkasten holons about SQLite WAL
  
STEP 5: Ask Gemma for help (AI chat)
  "What do I need to know about SQLite WAL mode in this system?"
  Gemma explains: SC-XHOLON-030 (no data loss on crash), WAL mandatory,
  checkpoint interval tuning affects write latency
  
STEP 6: Switch to Kanban to understand workflow
  See: tasks flow Pending -> Active -> Completed
  Understand: claim a pending task, work on it, mark complete
```

---

## 11. Journey J9: End-of-Day Review (Desktop, 3-5min)

```
STEP 1: Open Analytics view
  Health trajectory: started at 90, now 92 (+2.2% today)
  Tasks completed today: 8 (4 by claude-1, 3 by gemini-2, 1 manual)
  
STEP 2: Expand change log (click ticker bar)
  See full day's mutations:
    [17:30] T067 completed (claude-1)
    [16:15] T045 completed (claude-1)
    [15:00] T003 active -> completed (AN)
    [14:30] T089 pending -> active (gemini-2)
    ...
  
STEP 3: Check stale tasks (sort by Age DESC in grid)
  Identify: T032 "TLS cert rotation" — 6 days old, still blocked
  Action: Escalate to P0 or add blocker note
  
STEP 4: Glance at fractal sidebar
  L4 still at 78% — didn't improve today
  Decision: Tomorrow's focus = L4 System tasks
```

---

## 12. Journey J10: Cross-Layer Dependency Resolution (Wide, 10-20min)

```
STEP 1: Fractal sidebar shows L4=78% (worst layer)
  Click L4 -> see T005 (Build pipeline, BLOCKED, P0)
  
STEP 2: Open T005 detail -> "Related" action
  Shows: T003 (Hot reload, ACTIVE, L4) depends on T005
  Shows: T017 (DNS resolution, BLOCKED, L4) is independent
  
STEP 3: Click T003 in related list
  See: T003 is ACTIVE but can't complete until T005 (build pipeline) is fixed
  Dependency chain: T005 (build) -> T003 (hot reload) -> T015 (WAL tuning, L3)
  
STEP 4: Switch to Timeline view
  See: T005 created 5d ago, T003 created 1d ago
  T003 is waiting on T005 — visible as overlapping bars
  
STEP 5: AI Analysis on dependency chain
  Ask Gemma: "What's the fastest path to unblock L4?"
  Gemma: "Fix T005 first (build pipeline). This unblocks T003 (hot reload),
          which in turn allows T015 (WAL tuning) to proceed. Estimated
          impact: L4 health improves from 78% to ~90% if T005 + T017 resolved."
  
STEP 6: Filter by multiple layers (clear L4, click L3)
  See L3 tasks: T012 (Auth timeout) and T028 (DB migration) are blocked
  Cross-reference: T028 depends on T005 (same build pipeline)
  
  Insight: T005 is a CROSS-LAYER BLOCKER affecting L3 + L4
  Action: Escalate T005 to highest priority
```

---

## 13. Component Cross-Reference Matrix

| Component | J1 Triage | J2 Standup | J3 Planning | J4 Incident | J5 Arch | J6 API | J7 Demo | J8 Onboard | J9 Review | J10 Deps |
|-----------|-----------|-----------|-------------|-------------|---------|--------|---------|-----------|-----------|----------|
| C1 Weather Bar | Glance | Glance | Glance | Glance | Glance | - | Show | Glance | Glance | Glance |
| C2 Progress Rings | - | Glance | Show | - | Show | - | Show | - | - | - |
| C4 Task Grid | - | Primary | Filter | Primary | Filter | API | Show | Explore | Sort | Filter |
| C4.zones (Triage) | Primary | - | - | - | - | - | - | - | - | - |
| C5 Kanban | - | Switch | Primary | - | - | - | Show | Learn | - | - |
| C6 Timeline | - | - | Reference | Switch | - | - | - | - | - | Primary |
| C7 Analytics | - | - | Primary | - | Primary | - | Primary | - | Primary | - |
| C8 AI Search | Possible | Search | Search | Primary | - | - | - | Search | - | - |
| C9 Detail Panel | Deep-dive | Click | Click | Primary | Click | - | - | Primary | Click | Primary |
| C10 Gemma Chat | Inline | - | Consult | Consult | - | - | Consult | Consult | - | Consult |
| C11 Change Log | Toast | Glance | - | Monitor | - | - | - | - | Primary | - |
| C12 Fractal | - | Primary | Filter | Filter | Primary | - | - | Filter | Glance | Primary |

---

## 14. Responsive Behavior Summary

| Viewport | Primary Layout | View Tabs | Sidebar | Bottom Nav | Keyboard |
|----------|---------------|-----------|---------|------------|----------|
| Mobile (<768px) | D: Triage zones | Hidden | Hidden | Visible (Search/Grid/AI) | Limited |
| Tablet (768-1024px) | B: Kanban 2-col | Visible | Hidden | Hidden | Partial |
| Desktop (1024-1400px) | A: Bloomberg grid | Visible | Hidden | Hidden | Full |
| Wide (1400px+) | A+E: Grid + Sidebar | Visible | Visible | Hidden | Full |

---

## 15. WebSocket Protocol Specification

| Message Type | Direction | Payload | Trigger |
|-------------|-----------|---------|---------|
| "connected" | Server->Client | Initial status snapshot JSON | On WS open |
| "ping" | Client->Server | Empty or "ping" string | Client timer (1s) |
| "heartbeat" | Server->Client | `{"type":"heartbeat","seq":N}` | When status unchanged |
| "update" | Server->Client | Full status + active + blocked JSON | When status changed |
| "search" | Client->Server | `{"type":"search","q":"query"}` | User types in search |
| "search_result" | Server->Client | `{"type":"search","results":[...]}` | After NIF search |
| "task_update" | Server->Client | `{"type":"task_update","id":"T001","field":"status","old":"blocked","new":"active"}` | Any task mutation |

**Diff Detection**: Server compares `JSON.stringify(status)` with last sent. If identical, sends heartbeat (100 bytes). If different, sends full update (2-50KB).

**Reconnect**: Exponential backoff (1s, 2s, 4s, 8s, max 30s). Falls back to HTTP polling (5s) when WS disconnected.

---

## 16. Data Freshness Contract

| Data Source | Max Staleness | Indicator | Action on Stale |
|-------------|--------------|-----------|-----------------|
| Task counts | 2s | Green heartbeat dot | Amber dot at 3s, red at 10s |
| Task list | 5s | Grid header timestamp | Amber banner at 10s |
| Health score | 5s | Weather bar color | Flash amber warning |
| Analytics | 30s | Chart timestamp footer | "Data from Xs ago" label |
| Gemma response | N/A (on-demand) | Model label + latency | Timeout error message |
| Zettelkasten | N/A (on-demand) | Result count | "Search failed" error |

---

## 17. Accessibility Requirements (per WCAG 2.1 AA)

| Requirement | Spec | Verification |
|------------|------|-------------|
| Touch targets | >= 44x44px on all interactive elements | Pixel measurement |
| Color contrast | >= 4.5:1 text, >= 3:1 large text | Contrast checker |
| Keyboard navigation | All views navigable via Tab/Enter/Esc/Arrow keys | Manual test |
| Screen reader | All badges have aria-label, all grids have role="grid" | aXe audit |
| Reduced motion | @media (prefers-reduced-motion: reduce) disables animations | CSS check |
| Focus visible | 2px accent outline on focused elements | Visual check |
| Error identification | All error states have text labels (not just color) | Visual check |

---

## 18. Performance Budgets

| Metric | Mobile | Tablet | Desktop | Wide |
|--------|--------|--------|---------|------|
| First Paint | <1.5s | <1.5s | <1.0s | <1.0s |
| Interactive | <3.0s | <2.5s | <2.0s | <1.5s |
| JS Bundle | <100KB | <100KB | <100KB | <100KB |
| CSS | <20KB | <20KB | <20KB | <20KB |
| WS Heartbeat | <100B | <100B | <100B | <100B |
| WS Update | <50KB | <50KB | <50KB | <50KB |
| Gemma Response | <15s | <15s | <15s | <15s |
| NIF Search | <1ms | <1ms | <1ms | <1ms |
