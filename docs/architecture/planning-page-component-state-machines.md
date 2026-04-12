# Planning Page — Component State Machines, Dummy Data & Concept Rendering
# योजना पृष्ठ — घटक स्थिति यन्त्र, नमूना आँकड़ा एवं अवधारणा प्रतिपादन

**Date**: 2026-04-12
**Version**: v22.6.1-DHARMA
**Page**: `/planning` (Concept F: Adaptive Cockpit Hybrid)

---

## 1. Page-Level State Machine

### 1.1 Page LTS (Labeled Transition System)

```
LTS(Planning) = (S, Sigma, ->, s0)

States S = {
  Loading,          -- Initial page load, fetching data
  Connected,        -- WebSocket connected, data flowing
  Stale,            -- No WS update for >3s
  Disconnected,     -- WebSocket lost, polling fallback
  Error,            -- NIF/API failure
  Filtered,         -- Fractal layer filter active
  Searching,        -- AI search active (Ctrl+K)
  DetailOpen,       -- Task detail panel visible
  ChatOpen,         -- Gemma AI chat panel visible
}

Labels Sigma = {
  PageLoad, WsConnect, WsHeartbeat, WsUpdate, WsDisconnect,
  WsReconnect, FilterLayer(L), ClearFilter, Search(q), ClearSearch,
  ClickTask(id), CloseDetail, OpenChat, CloseChat, SwitchView(v),
  TaskUpdate(id, field, old, new), Error(msg), Recover
}

Initial state s0 = Loading

Transitions -> = {
  Loading       --PageLoad-->       Loading
  Loading       --WsConnect-->      Connected
  Loading       --Error-->          Error
  Connected     --WsHeartbeat-->    Connected
  Connected     --WsUpdate-->       Connected
  Connected     --WsDisconnect-->   Disconnected
  Connected     --FilterLayer-->    Filtered
  Connected     --Search-->         Searching
  Connected     --ClickTask-->      DetailOpen
  Connected     --OpenChat-->       ChatOpen
  Connected     --SwitchView-->     Connected
  Filtered      --ClearFilter-->    Connected
  Filtered      --FilterLayer-->    Filtered  (switch layer)
  Filtered      --ClickTask-->      DetailOpen
  Searching     --ClearSearch-->    Connected
  Searching     --ClickTask-->      DetailOpen
  DetailOpen    --CloseDetail-->    Connected | Filtered
  ChatOpen      --CloseChat-->      Connected
  Disconnected  --WsReconnect-->    Connected
  Disconnected  --Error-->          Error
  Error         --Recover-->        Loading
  Stale         --WsUpdate-->       Connected
  Stale         --WsDisconnect-->   Disconnected
  Connected     --[3s no msg]-->    Stale
}
```

### 1.2 Page State Diagram

```
                    PageLoad
                       |
                       v
                  +---------+
                  | Loading |
                  +---------+
                   /       \
          WsConnect         Error
                 /             \
                v               v
        +------------+    +---------+
        | Connected  |<-->|  Error  |
        +------------+    +---------+
          |   |   |  \        ^
  Filter  |   |   |   \       |
          v   |   |    \      |
     +----------+ |  WsDisc  Recover
     | Filtered | |     \     |
     +----------+ |      v   |
          |       | +---------------+
   ClickTask  Search| Disconnected  |
          |       | +---------------+
          v       v        |
     +----------+ +----------+  WsReconnect
     |DetailOpen| | Searching |-----+
     +----------+ +----------+
          |
      OpenChat
          v
     +----------+
     | ChatOpen |
     +----------+
```

### 1.3 View Sub-States

```
Connected.view in {Grid, Kanban, Timeline, Analytics, Fractal}

Connected.Grid     --press "2"--> Connected.Kanban
Connected.Kanban   --press "1"--> Connected.Grid
Connected.Grid     --press "3"--> Connected.Timeline
Connected.Grid     --press "4"--> Connected.Analytics
Connected.Grid     --press "5"--> Connected.Fractal
(all views reachable from all views -- complete graph)
```

---

## 2. Component C1: Weather Bar

### 2.1 State Machine

```
LTS(C1) = (S, Sigma, ->, s0)

S = {Healthy, Degraded, Critical, Disconnected, Loading}

Sigma = {
  DataUpdate(health, active, blocked, p0, dHdt),
  WsConnect, WsDisconnect, Timeout
}

s0 = Loading

-> = {
  Loading       --DataUpdate(h>=85)--> Healthy
  Loading       --DataUpdate(70<=h<85)--> Degraded
  Loading       --DataUpdate(h<70)--> Critical
  Loading       --Timeout--> Disconnected
  Healthy       --DataUpdate(h>=85)--> Healthy
  Healthy       --DataUpdate(70<=h<85)--> Degraded
  Healthy       --DataUpdate(h<70)--> Critical
  Healthy       --WsDisconnect--> Disconnected
  Degraded      --DataUpdate(h>=85)--> Healthy
  Degraded      --DataUpdate(h<70)--> Critical
  Degraded      --WsDisconnect--> Disconnected
  Critical      --DataUpdate(h>=85)--> Healthy
  Critical      --DataUpdate(70<=h<85)--> Degraded
  Critical      --WsDisconnect--> Disconnected
  Disconnected  --WsConnect--> Loading
}
```

### 2.2 States with Dummy Data

**STATE: Loading**
```
Desktop:
+================================================================================+
| C3I  [...]  Act: --  Blk: --  P0: --  Health: --  ░░░░░░░░░░  OODA: --       |
+================================================================================+
Behavior: Shimmer animation on metric placeholders. Gray dots. No live indicator.

Mobile:
+-------------------------------------------+
| [C3I]  [...]  Health: --   [AI]   [=]     |
+-------------------------------------------+
```

**STATE: Healthy (health=92, active=47, blocked=12, p0=3, dHdt=+0.3)**
```
Desktop:
+================================================================================+
| C3I  [*]Live  Act: 47  Blk: 12  P0: 3   Health: 92 ████████░░ ▲+0.3/h  28ms |
|      [grn]    [grn]    [red]    [red+pulse]  [green bar]   [green arrow]       |
+================================================================================+
Data: NIF plan_status() -> {"active":47,"blocked":12,"completed":234,"pending":85,"p0":3}
      health_calculus.derivative() -> +0.3
Colors: Health>=85 -> all green. P0>0 -> red pulse badge.
Live dot: 5px green, CSS pulse animation (1s cycle).
Update: Every 1s via WS heartbeat/update.

Mobile:
+-------------------------------------------+
| [C3I]  [*]Live  Health: 92  [AI]   [=]    |
|         [grn]    [green]                   |
+-------------------------------------------+
Compact: Only brand + live dot + health score. No Act/Blk/P0 (shown in zones).
```

**STATE: Degraded (health=72, active=30, blocked=28, p0=7, dHdt=-1.2)**
```
Desktop:
+================================================================================+
| C3I  [*]Live  Act: 30  Blk: 28  P0: 7   Health: 72 █████░░░░░ ▼-1.2/h  45ms |
|      [grn]    [amber]  [red]    [red+pulse]  [amber bar]  [red arrow]          |
+================================================================================+
Colors: Health 70-84 -> amber bar, amber Act badge. P0=7 -> large red pulse.
dHdt negative -> red down arrow (system degrading).
OODA latency 45ms -> still within 100ms budget (green).

Mobile:
+-------------------------------------------+
| [C3I]  [*]Live  Health: 72  [AI]   [=]    |
|         [grn]    [amber]                   |
+-------------------------------------------+
```

**STATE: Critical (health=45, active=10, blocked=55, p0=15, dHdt=-3.8)**
```
Desktop:
+================================================================================+
| C3I  [!]ALERT  Act: 10  Blk: 55  P0: 15  Health: 45 ██░░░░░░░░ ▼-3.8/h 120ms|
|      [red]     [red]    [red]    [red+pulse]  [red bar]  [red arrow]  [red!]   |
+================================================================================+
Colors: Health<70 -> all red. OODA 120ms -> over budget (red).
Live dot replaced with red exclamation pulse.
Background flash: subtle red pulse on entire header (CSS animation, 2s cycle).

Mobile:
+-------------------------------------------+
| [C3I]  [!]ALERT  Health: 45  [AI]  [=]    |
|         [red+pulse]   [red]                |
+-------------------------------------------+
```

**STATE: Disconnected**
```
Desktop:
+================================================================================+
| C3I  [x]OFFLINE  Act: 47  Blk: 12  P0: 3  Health: 92  ████████░░  --  STALE  |
|      [red]       [gray]   [gray]   [gray]   [gray bar] [gray]     [red]       |
+================================================================================+
All metrics grayed out (last known values, may be stale).
"STALE" label in red at right end.
Live dot: red X, no animation.
Reconnect countdown: "Retry in 4s..." shown in muted text.

Mobile:
+-------------------------------------------+
| [C3I]  [x]OFF  Health: 92?  [AI]   [=]    |
|        [red]   [gray+"?"]                  |
+-------------------------------------------+
```

### 2.3 Transitions & Animations

| From | To | Trigger | Animation | Duration |
|------|----|---------|-----------|----------|
| Loading -> Healthy | WsConnect + data | Fade in metrics, dot turns green | 300ms |
| Healthy -> Degraded | health drops below 85 | Bar color transitions green->amber | 500ms ease |
| Degraded -> Critical | health drops below 70 | Bar turns red, header flashes red pulse | 500ms + continuous |
| Any -> Disconnected | WS close event | Metrics gray out, dot turns red X | 200ms |
| Disconnected -> Loading | WS reconnect | Shimmer animation returns | 200ms |
| Healthy -> Healthy | WS update (same health) | No animation (diff detection) | 0ms |
| Healthy -> Healthy | WS update (health changed) | Number counter animation (old->new) | 300ms |

---

## 3. Component C2: Progress Rings

### 3.1 State Machine

```
S = {Loading, Normal, AllBlocked, AllComplete, Empty}

-> = {
  Loading        --DataUpdate(a>0,b>0,c>0)--> Normal
  Loading        --DataUpdate(a=0,b>0)--> AllBlocked
  Loading        --DataUpdate(b=0,c>0)--> AllComplete
  Loading        --DataUpdate(a=0,b=0,c=0)--> Empty
  Normal         --DataUpdate--> Normal | AllBlocked | AllComplete
  AllBlocked     --DataUpdate--> Normal | AllComplete
  AllComplete    --DataUpdate--> Normal | AllBlocked
}
```

### 3.2 States with Dummy Data

**STATE: Normal (active=47, blocked=12, completed=234, total=378)**
```
  Active: 47        Blocked: 12       Completed: 234
  ┌─────────┐      ┌─────────┐      ┌─────────┐
  │  ╭───╮  │      │  ╭───╮  │      │  ╭───╮  │
  │ ╱ 47  ╲ │      │ ╱ 12  ╲ │      │ ╱234  ╲ │
  │ ╲     ╱ │      │ ╲     ╱ │      │ ╲     ╱ │
  │  ╰───╯  │      │  ╰───╯  │      │  ╰───╯  │
  └─────────┘      └─────────┘      └─────────┘
   [blue 12%]       [red 3%]         [green 62%]
   
Ring: SVG circle with stroke-dasharray = 2*pi*r * (count/total).
Center text: count number, 18px bold.
Below ring: percentage text, 12px muted.
Ring stroke: 6px, rounded linecap.
Sizes: Mobile 70px, Tablet 90px, Desktop 100px, Wide 110px.
```

**STATE: AllBlocked (active=0, blocked=88, completed=0)**
```
  Active: 0         Blocked: 88       Completed: 0
  ┌─────────┐      ┌─────────┐      ┌─────────┐
  │  ╭───╮  │      │  ╭───╮  │      │  ╭───╮  │
  │ ╱  0  ╲ │      │ ╱ 88  ╲ │      │ ╱  0  ╲ │
  │ ╲     ╱ │      │ ╲     ╱ │      │ ╲     ╱ │
  │  ╰───╯  │      │  ╰───╯  │      │  ╰───╯  │
  └─────────┘      └─────────┘      └─────────┘
   [gray 0%]       [RED 100%+pulse]   [gray 0%]

Blocked ring: full circle, red, CSS pulse animation.
Active/Completed: empty rings, gray stroke only.
ALERT: This state triggers cockpit escalation to Bright mode.
```

**STATE: AllComplete (active=0, blocked=0, completed=378)**
```
  Active: 0         Blocked: 0        Completed: 378
  ┌─────────┐      ┌─────────┐      ┌─────────┐
  │  ╭───╮  │      │  ╭───╮  │      │  ╭───╮  │
  │ ╱  0  ╲ │      │ ╱  0  ╲ │      │ ╱378  ╲ │
  │ ╲     ╱ │      │ ╲     ╱ │      │ ╲     ╱ │
  │  ╰───╯  │      │  ╰───╯  │      │  ╰───╯  │
  └─────────┘      └─────────┘      └─────────┘
   [gray 0%]        [gray 0%]       [GREEN 100%]

Dark Cockpit mode: only Completed ring visible. Minimal noise.
```

---

## 4. Component C4: Task Grid (Bloomberg)

### 4.1 State Machine

```
S = {Loading, Populated, Filtered, Sorted, Empty, RowHighlight, Error}

-> = {
  Loading        --DataLoad(rows>0)--> Populated
  Loading        --DataLoad(rows=0)--> Empty
  Loading        --Error--> Error
  Populated      --ClickHeader(col)--> Sorted
  Populated      --FilterLayer(L)--> Filtered
  Populated      --Search(q)--> Filtered
  Populated      --WsTaskUpdate(id)--> RowHighlight
  Filtered       --ClearFilter--> Populated
  Filtered       --FilterLayer(L2)--> Filtered
  Sorted         --ClickHeader(col)--> Sorted (toggle ASC/DESC)
  Sorted         --FilterLayer--> Filtered+Sorted
  RowHighlight   --[1.8s timeout]--> Populated
  Empty          --DataLoad(rows>0)--> Populated
  Error          --Retry--> Loading
}
```

### 4.2 States with Dummy Data

**STATE: Populated (15 tasks visible, sorted by status then priority)**
```
+------+----------------------------------+--------+----+-------+------+---------+
| ID   | Title                            | Status | P  | Owner | Age  | Layer   |
+------+----------------------------------+--------+----+-------+------+---------+
| T001 | Guardian NIF crash isolation      | BLOCK  | P0 | AN   | 3d   | o L0    |
| T005 | Build pipeline podman fix         | BLOCK  | P0 | AN   | 5d   | o L4    |
| T009 | Zenoh quorum split-brain          | BLOCK  | P0 | CL   | 1d   | o L6    |
| T012 | Auth timeout middleware           | BLOCK  | P1 | AN   | 2d   | o L3    |
| T017 | DNS resolution flaky             | BLOCK  | P1 | --   | 4d   | o L4    |
| T028 | DB migration stuck               | BLOCK  | P1 | AN   | 2d   | o L3    |
+------+----------------------------------+--------+----+-------+------+---------+
| T002 | Zenoh multi-region federation     | ACTIVE | P1 | AN   | 12h  | o L6    |
| T003 | Hot reload beam code server       | ACTIVE | P1 | CL   | 1d   | o L4    |
| T015 | SQLite WAL checkpoint tuning      | ACTIVE | P2 | AN   | 4h   | o L3    |
| T045 | OTel trace span correlation       | ACTIVE | P1 | CL   | 6h   | o L1    |
| T067 | A2UI wave2 catalog completion     | ACTIVE | P2 | AN   | 8h   | o L2    |
+------+----------------------------------+--------+----+-------+------+---------+
| T023 | MCP tool dispatch wiring          | PEND   | P1 | --   | 3d   | o L5    |
| T034 | Badge component CSS polish        | PEND   | P2 | --   | 1d   | o L2    |
| T078 | Mesh topology visualization       | PEND   | P1 | --   | 5d   | o L6    |
| T090 | Gateway version vector sync       | PEND   | P2 | --   | 3d   | o L7    |
+------+----------------------------------+--------+----+-------+------+---------+

Row colors: Even rows #0e121c, odd transparent.
Status left border: 3px (red/blue/gray).
Status badge: filled rounded rect with status color.
Priority badge: small rounded rect (P0=red, P1=amber, P2=green).
Age: green(<1d), amber(1-7d), red(>7d).
Layer dot: 5px colored dot + layer code in layer color.
```

**STATE: Filtered (L4 System only — 5 tasks)**
```
+------+----------------------------------+--------+----+-------+------+---------+
| ID   | Title                            | Status | P  | Owner | Age  | Layer   |
+------+----------------------------------+--------+----+-------+------+---------+
| T005 | Build pipeline podman fix         | BLOCK  | P0 | AN   | 5d   | o L4    |
| T017 | DNS resolution flaky             | BLOCK  | P1 | --   | 4d   | o L4    |
| T003 | Hot reload beam code server       | ACTIVE | P1 | CL   | 1d   | o L4    |
| T032 | TLS cert rotation                 | BLOCK  | P1 | --   | 6d   | o L4    |
| T041 | Podman health false positive      | BLOCK  | P2 | AN   | 1d   | o L4    |
+------+----------------------------------+--------+----+-------+------+---------+
| Showing 5 of 5 L4 tasks                 | [Clear Filter: L4 System]            |
+------+----------------------------------+--------+----+-------+------+---------+

Filter indicator: "L4 System" chip with X button at bottom of grid.
URL: /planning?layer=4
Fractal sidebar: L4 row has accent left border.
```

**STATE: RowHighlight (T002 just changed status)**
```
| T002 | Zenoh multi-region federation     | ACTIVE | P1 | AN   | 12h  | o L6    |
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
         [row-changed CSS class: background transition #1a2a35 -> transparent, 1.8s]

Data source: WS "task_update" message: {"id":"T002","field":"status","old":"pending","new":"active"}
Animation: Row background flashes accent-tinted (#1a2a35) then fades to normal over 1.8s.
Grid: snapshotData() captures before-state, findChangedIds() identifies T002, highlightChangedRows() applies CSS.
```

**STATE: Sorted (by Age DESC)**
```
+------+----------------------------------+--------+----+-------+------+---------+
| ID   | Title                            | Status | P  | Owner | Age v| Layer   |
+------+----------------------------------+--------+----+-------+------+---------+
| T032 | TLS cert rotation                | BLOCK  | P1 | --   | 6d   | o L4    |
| T005 | Build pipeline podman fix         | BLOCK  | P0 | AN   | 5d   | o L4    |
| T078 | Mesh topology visualization       | PEND   | P1 | --   | 5d   | o L6    |
| T017 | DNS resolution flaky             | BLOCK  | P1 | --   | 4d   | o L4    |
| ...  |                                  |        |    |       |      |         |

Sort indicator: "v" arrow on Age column header (DESC). Click again -> "^" (ASC).
Tabulator handles sort natively. URL: /planning?sort=age&dir=desc
```

**STATE: Empty (all tasks completed or filtered to empty set)**
```
+------+----------------------------------+--------+----+-------+------+---------+
| ID   | Title                            | Status | P  | Owner | Age  | Layer   |
+------+----------------------------------+--------+----+-------+------+---------+
|                                                                                 |
|                    No tasks match current filters                               |
|                                                                                 |
|              Try clearing filters or broadening your search                     |
|                                                                                 |
+------+----------------------------------+--------+----+-------+------+---------+

Centered muted text. If filtered: shows "Clear Filter" button.
```

---

## 5. Component C4.zones: Triage Zones (Mobile)

### 5.1 State Machine

```
S = {Loading, Normal, NoCritical, AllNominal, AllCritical}

-> = {
  Loading       --DataLoad(p0>0, blk>0)--> Normal
  Loading       --DataLoad(p0=0, blk>0)--> NoCritical
  Loading       --DataLoad(blk=0)--> AllNominal
  Loading       --DataLoad(p0=all)--> AllCritical
  Normal        --TaskActivate(last_p0)--> NoCritical
  NoCritical    --TaskEscalate--> Normal
  Normal        --AllUnblocked--> AllNominal
  AllNominal    --NewBlock--> Normal | NoCritical
}
```

### 5.2 States with Dummy Data

**STATE: Normal (3 critical, 9 attention, 166 nominal)**
```
+-------------------------------------------+
| [C3I] o Live  Health: 92  [AI]   [=]      | 44px
+-------------------------------------------+
| !!! CRITICAL (3)              [red border] |
| +---------------------------------------+ |
| | T001  Guardian NIF crash      [P0]    | |
| | L0 Constitutional . 3d ago            | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
| +---------------------------------------+ |
| | T005  Build pipeline fix      [P0]    | |
| | L4 System . 5d ago                    | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
| +---------------------------------------+ |
| | T009  Zenoh quorum split      [P0]    | |
| | L6 Ecosystem . 1d ago                 | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
+-------------------------------------------+
| !! ATTENTION (9)            [amber border] |
| +---------------------------------------+ |
| | T012  Auth timeout        [Blocked]   | |
| | L3 Transaction . 2d ago              | |
| | [Unblock] [Reassign] [Detail]        | |
| +---------------------------------------+ |
| (+ 8 more, tap to expand)               |
+-------------------------------------------+
| OK NOMINAL (166)   [collapsed]    [v]     |
+-------------------------------------------+
|  [Search]    |   [Grid]    |   [AI]       | 44px
+-------------------------------------------+
```

**STATE: NoCritical (0 critical, 12 attention, 166 nominal)**
```
+-------------------------------------------+
| [C3I] o Live  Health: 92  [AI]   [=]      |
+-------------------------------------------+
| OK No critical issues              [grn]  |
+-------------------------------------------+
| !! ATTENTION (12)           [amber border] |
| +---------------------------------------+ |
| | T012  Auth timeout        [Blocked]   | |
| | L3 Transaction . 2d ago              | |
| | [Unblock] [Reassign] [Detail]        | |
| +---------------------------------------+ |
| (+ 11 more, tap to expand)              |
+-------------------------------------------+
| OK NOMINAL (166)   [collapsed]    [v]     |
+-------------------------------------------+
|  [Search]    |   [Grid]    |   [AI]       |
+-------------------------------------------+

Zone 1 replaced with green "No critical issues" banner.
Attention zone gets more vertical space.
```

**STATE: AllNominal (0 critical, 0 attention, 178 nominal)**
```
+-------------------------------------------+
| [C3I] o Live  Health: 98  [AI]   [=]      |
+-------------------------------------------+
|                                           |
|         ALL SYSTEMS NOMINAL               |
|         ___                               |
|        /   \  178 tasks                   |
|        \___/  0 blocked                   |
|                                           |
|       Dark Cockpit Mode Active            |
|                                           |
+-------------------------------------------+
| OK NOMINAL (178)   [expanded]    [^]      |
| +---------------------------------------+ |
| | T002  Zenoh federation   [Active P1]  | |
| +---------------------------------------+ |
| | T003  Hot reload beam    [Active P1]  | |
| +---------------------------------------+ |
| (+ 176 more)                             |
+-------------------------------------------+
|  [Search]    |   [Grid]    |   [AI]       |
+-------------------------------------------+

Dark Cockpit: suppresses noise. Big green ring + "ALL SYSTEMS NOMINAL".
Nominal zone auto-expands since it's the only content.
```

---

## 6. Component C5: Kanban Board

### 6.1 State Machine

```
S = {Loading, Normal, Overflow, SingleColumn, Empty, DoneExpanded}

-> = {
  Loading       --DataLoad(tasks>0)--> Normal
  Loading       --DataLoad(tasks=0)--> Empty
  Normal        --Resize(<768px)--> SingleColumn
  Normal        --ColumnCount>20--> Overflow
  Normal        --ClickDone--> DoneExpanded
  DoneExpanded  --ClickDone--> Normal
  SingleColumn  --Resize(>=768px)--> Normal
  Overflow      --VirtualScroll--> Overflow
}
```

### 6.2 States with Dummy Data

**STATE: Normal (4-column, desktop)**
```
+--------------------+--------------------+--------------------+------------------+
| BLOCKED (12)       | PENDING (85)       | ACTIVE (47)        | DONE (234)       |
| [red header]       | [gray header]      | [blue header]      | [green, coll.]   |
+--------------------+--------------------+--------------------+------------------+
| +----------------+ | +----------------+ | +----------------+ |                  |
| | T001       [P0]| | | T023       [P1]| | | T002       [P1]| | 234 completed    |
| | Guardian NIF   | | | MCP wire       | | | Zenoh fed      | | [tap expand]     |
| | o L0 Const 3d  | | | o L5 Cog  3d   | | | o L6 Eco  12h  | |                  |
| | [red glow bdr] | | |                | | | [blue border]  | |                  |
| +----------------+ | +----------------+ | +----------------+ |                  |
|                    |                    |                    |                  |
| +----------------+ | +----------------+ | +----------------+ |                  |
| | T005       [P0]| | | T034       [P2]| | | T003       [P1]| |                  |
| | Build pipe     | | | Badge CSS      | | | Hot reload     | |                  |
| | o L4 Syst 5d   | | | o L2 Comp 1d   | | | o L4 Syst 1d   | |                  |
| +----------------+ | +----------------+ | +----------------+ |                  |
|                    |                    |                    |                  |
| (+ 10 more)       | (+ 83 more)        | (+ 45 more)       |                  |
+--------------------+--------------------+--------------------+------------------+

Card dimensions: column_width - 16px padding, 90px height.
Card layout: Line1: ID + P badge. Line2: Title (14px, 2-line max). Line3: layer dot + name + age.
P0 cards: 2px red border + box-shadow glow.
DONE column: collapsed, shows count + "tap expand" text.
```

**STATE: SingleColumn (mobile <768px)**
```
+-------------------------------------------+
| BLOCKED (12) [red]                        |
+-------------------------------------------+
| +---------------------------------------+ |
| | T001 [P0]  Guardian NIF crash         | |
| | o L0 Constitutional . 3d ago          | |
| | [red glow]                            | |
| +---------------------------------------+ |
| +---------------------------------------+ |
| | T005 [P0]  Build pipeline fix         | |
| | o L4 System . 5d ago                  | |
| +---------------------------------------+ |
| (+ 10 more blocked)                      |
+-------------------------------------------+
| ACTIVE (47) [blue]                        |
+-------------------------------------------+
| +---------------------------------------+ |
| | T002 [P1]  Zenoh multi-region         | |
| | o L6 Ecosystem . 12h ago              | |
| +---------------------------------------+ |
| (+ 46 more active)                       |
+-------------------------------------------+
| PENDING (85) [collapsed]          [v]     |
| DONE (234) [collapsed]           [v]     |
+-------------------------------------------+

Columns stack vertically. Each column is full-width.
PENDING and DONE collapsed by default on mobile.
```

---

## 7. Component C6: Timeline

### 7.1 State Machine

```
S = {Loading, Normal, Zoomed, Filtered, Empty}

-> = {
  Loading    --DataLoad--> Normal
  Normal     --Scroll--> Normal
  Normal     --Zoom(in/out)--> Zoomed
  Normal     --FilterLayer--> Filtered
  Filtered   --ClearFilter--> Normal
  Empty      --DataLoad--> Normal
}
```

### 7.2 States with Dummy Data

**STATE: Normal (7-day view, 15 tasks)**
```
        Apr 6    Apr 7    Apr 8    Apr 9    Apr 10   Apr 11   Apr 12
          |        |        |        |        |        |    NOW |
T001 ████████████████████████████████████████████████████ BLOCKED (P0, L0)
T005 ████████████████████████████████████████████████████████████ BLK (P0, L4)
T009                                          ██████████████████ BLOCKED (P0, L6)
T012                                 ██████████████████████████ BLOCKED (P1, L3)
T002                                                    ████████ ACTIVE (P1, L6)
T003                                                     ███████ ACTIVE (P1, L4)
T015                                                         ███ ACTIVE (P2, L3)
T045                                                       █████ ACTIVE (P1, L1)
T023                              ██████████████████████████████ PENDING (P1, L5)
                                                            |
                                                          NOW line (dashed, labeled)

Bar colors: red=BLOCKED, blue=ACTIVE, gray=PENDING, green=COMPLETED.
Bar height: 24px, 4px gap between bars.
P0 left marker: red dot on bar start.
Y-axis: tasks sorted by creation date (oldest top).
X-axis: 7-day window, today = right edge.
Hover tooltip: "T001 — Guardian NIF crash isolation — BLOCKED — 3d — P0 — L0 Constitutional"
Click: opens C9 detail panel.
```

---

## 8. Component C7: Analytics Dashboard

### 8.1 State Machine

```
S = {Loading, Populated, Refreshing, Error}

-> = {
  Loading     --DataComputed--> Populated
  Populated   --[5s timer]--> Refreshing
  Refreshing  --DataComputed--> Populated
  Refreshing  --Error--> Error
  Error       --Retry--> Loading
}
```

### 8.2 Charts with Dummy Data

**Chart 1: Health Trajectory (7-day sparkline)**
```
100 |
 95 |                              ___/```
 90 |                         ___/
 85 |                    ___/
 80 |               ___/
 75 |          ___/
 70 |     ___/
    +----+----+----+----+----+----+----
    Apr6  Apr7  Apr8  Apr9  10   11   12

Data: [72, 74, 78, 80, 83, 85, 85, 87, 88, 90, 92]
Score label: "85 -> 92  (+8.2%)" in green
Area fill: green with 20% opacity
Sparkline: 2px green stroke, rounded joins
```

**Chart 2: Priority Distribution (horizontal bars)**
```
P0  ███                          3  (3.4%)
P1  █████████████████           28  (31.8%)
P2  ████████████████████████    45  (51.1%)
P3  ████████                    12  (13.6%)
    0        10        20       30       40       50

Colors: P0=red, P1=amber, P2=green, P3=gray
Labels: count + percentage
Bar: rounded 3px corners, width proportional to count/max
```

**Chart 3: Age Histogram (4 buckets)**
```
<1d  ████████████████████████████████  47  (26.4%)  [green]
1-3d ████████████████████████████████████████████  85  (47.8%)  [blue]
3-7d ████████████████████            34  (19.1%)  [amber]
>7d  ████████                        12  (6.7%)   [red]

Insight: "Median age: 2.1 days. 12 tasks stale (>7d)."
```

**Chart 4: Fractal Distribution (8 bars, layer-colored)**
```
L0  █████          5   [#ff6b6b]
L1  ██             2   [#ffd93d]
L2  ████████████  10   [#6bcb77]
L3  ████████████████████████  25   [#4d96ff]
L4  ██████████████  12   [#9b59b6]
L5  ████████████████  15   [#00d4aa]
L6  ████████        8   [#e74c3c]
L7  ████            3   [#f39c12]
    0     5    10    15    20    25

Click bar -> filter grid to that layer.
Highlight: bar with highest blocked count gets red outline.
```

**Chart 5: Status Flow Sankey**
```
Pending (85) ──────┬─────────── Active (47) ──────┬──── Completed (234)
                   │                              │
Blocked (12) ──────┘                              │
                                                  │
                   Velocity: 4.2 tasks/day ───────┘

Flow widths proportional to task counts.
Color transitions: gray->blue->green
```

---

## 9. Component C8: AI Search

### 9.1 State Machine

```
S = {Hidden, Active, Typing, Searching, Results, NoResults}

-> = {
  Hidden     --Ctrl+K / ClickSearch--> Active
  Active     --Type(char)--> Typing
  Active     --Esc--> Hidden
  Typing     --[200ms debounce]--> Searching
  Typing     --Type(char)--> Typing (reset debounce)
  Typing     --Esc--> Hidden
  Searching  --Results(>0)--> Results
  Searching  --Results(0)--> NoResults
  Results    --Type(char)--> Typing
  Results    --ClickResult--> Hidden (+ open detail/navigate)
  Results    --Esc--> Hidden
  NoResults  --Type(char)--> Typing
  NoResults  --Esc--> Hidden
}
```

### 9.2 States with Dummy Data

**STATE: Active (empty input, focused)**
```
+----------------------------------------------------+
| [magnify]  |                                [Esc]   |
+----------------------------------------------------+
|                                                     |
|  Type to search tasks and knowledge...              |
|  Shortcuts: Ctrl+K to open, Esc to close           |
|                                                     |
+----------------------------------------------------+
```

**STATE: Results (query="zenoh", 3 tasks + 3 knowledge)**
```
+----------------------------------------------------+
| [magnify]  zenoh                            [Esc]   |
+----------------------------------------------------+
| TASKS (3)                                           |
| +------------------------------------------------+ |
| | T002  Zenoh multi-region federation    [ACT P1] | |
| | T009  Zenoh quorum split-brain         [BLK P0] | |
| | T078  Mesh topology visualization      [PND P1] | |
| +------------------------------------------------+ |
|                                                     |
| KNOWLEDGE (3 holons)                                |
| +------------------------------------------------+ |
| | Zenoh session lifecycle (L6, molecular)         | |
| | Split-brain detection protocol (L0, atomic)     | |
| | Journal: 20260405 mesh partition RCA (organism)  | |
| +------------------------------------------------+ |
+----------------------------------------------------+

Tasks: Click -> opens C9 detail panel.
Knowledge: Click -> opens holon content in detail panel.
Real-time: Grid behind modal filters to matching tasks (live preview).
```

**STATE: NoResults (query="xyznonexistent")**
```
+----------------------------------------------------+
| [magnify]  xyznonexistent                   [Esc]   |
+----------------------------------------------------+
|                                                     |
|  No tasks or knowledge matching "xyznonexistent"    |
|                                                     |
|  Try: broader terms, task IDs, or STAMP refs        |
|                                                     |
+----------------------------------------------------+
```

---

## 10. Component C9: Detail Panel

### 10.1 State Machine

```
S = {Closed, Opening, Open, LoadingAI, AIComplete, LoadingRelated, RelatedShown}

-> = {
  Closed        --ClickTask(id)--> Opening
  Opening       --[200ms anim]--> Open
  Open          --Close / Esc--> Closed
  Open          --ClickAIAnalysis--> LoadingAI
  Open          --ClickRelated--> LoadingRelated
  Open          --ClickKnowledge--> LoadingRelated (reuse)
  LoadingAI     --GemmaResponse--> AIComplete
  LoadingAI     --Timeout(15s)--> AIComplete (with error)
  AIComplete    --Close--> Closed
  LoadingRelated --DataLoad--> RelatedShown
  RelatedShown   --ClickRelatedTask--> Open (new task)
  RelatedShown   --Close--> Closed
}
```

### 10.2 States with Dummy Data

**STATE: Open (task T001)**
```
Desktop (400px slide-in from right):
+------------------------------------------+
| [<-]  Task Detail                [X]     | 44px
+------------------------------------------+
|                                          |
| T001 — Guardian NIF crash isolation      | 18px bold
| ---------------------------------------- |
| [BLOCKED]  [P0]  [L0 Constitutional]    | badges
| Created: 2026-04-09   Age: 3 days       | 14px
| Owner: AN                               | 14px
| ---------------------------------------- |
|                                          |
| Description:                            |
| The c3i_nif.so crashes when Guardian    | 14px, wrap
| attempts to verify Psi-0 invariant on   |
| cold boot. Segfault in zenoh_session_   |
| open() when router is unreachable.      |
| ---------------------------------------- |
|                                          |
| STAMP References:                       |
| * SC-NIF-003 (panic=unwind)             | 13px, accent
| * SC-GUARD-002 (fail closed)            |
| * SC-PRIME-001 (constitutional axiom)   |
| ---------------------------------------- |
|                                          |
| 5 Actions:                              |
| +----------+ +----------+              |
| |Knowledge | | Related  |              | 44px
| +----------+ +----------+              |
| +----------+ +----------+              |
| |  STAMP   | |Sub-Tasks |              | 44px
| +----------+ +----------+              |
| +------------------------+             |
| |    AI Analysis         |             | 44px
| +------------------------+             |
+------------------------------------------+
```

**STATE: LoadingAI**
```
+------------------------------------------+
| AI Analysis — T001                       |
| ---------------------------------------- |
|                                          |
| [Gemma 3 — analyzing...]                |
| ████████░░░░░░░░░░░░ (shimmer)           |
| ████████████░░░░░░░░ (shimmer)           |
| ████░░░░░░░░░░░░░░░░ (shimmer)           |
|                                          |
| Timeout: 15s  Model: gemma3:4b          |
+------------------------------------------+

Shimmer: CSS gradient animation sliding left-to-right.
3 shimmer bars at 80%, 60%, 40% width.
Timeout countdown visible.
```

**STATE: AIComplete (success)**
```
+------------------------------------------+
| AI Analysis — T001           [Gemma 3]   |
| ---------------------------------------- |
|                                          |
| Root Cause:                              |
| The Zenoh session_open() call in         |
| c3i_nif.so does not handle the case      |
| where the router endpoint is             |
| unreachable at boot time. The NIF        |
| returns a panic instead of an Erlang     |
| error tuple, violating SC-NIF-003.       |
|                                          |
| Recommended Fix:                         |
| 1. Wrap zenoh::open() in catch_unwind()  |
| 2. Return {:error, :zenoh_unreachable}   |
| 3. Add 3-retry with exponential backoff  |
|                                          |
| Confidence: 0.87                         |
| Latency: 3.1s | Model: gemma3:4b        |
+------------------------------------------+
```

**STATE: AIComplete (timeout/error)**
```
+------------------------------------------+
| AI Analysis — T001              [Error]  |
| ---------------------------------------- |
|                                          |
| AI analysis unavailable.                |
|                                          |
| Gemma 3 timed out (15s).                |
| Gemma 4 timed out (15s).                |
|                                          |
| Alternative: Use [Knowledge] search     |
| to find related patterns in             |
| Zettelkasten (2,060 holons).            |
|                                          |
| [Retry AI Analysis]                     |
+------------------------------------------+
```

---

## 11. Component C10: Gemma AI Chat

### 11.1 State Machine

```
S = {Hidden, Minimized, Open, Typing, Waiting, ResponseStreaming, Error}

-> = {
  Hidden       --ClickAI / Inline trigger--> Open
  Open         --Minimize--> Minimized
  Minimized    --Click--> Open
  Open         --Close--> Hidden
  Open         --UserType--> Typing
  Typing       --SendMessage--> Waiting
  Waiting      --GemmaChunk--> ResponseStreaming
  Waiting      --Timeout--> Error
  ResponseStreaming --Complete--> Open
  Error        --Retry--> Waiting
  Error        --Close--> Hidden
}
```

### 11.2 States with Dummy Data

**STATE: Open (empty, ready)**
```
+--------------------------------------+
| Gemma AI Assistant        [-]  [X]   |
+--------------------------------------+
|                                      |
| Welcome! I have access to:          |
| * 178 tasks (47 active, 12 blocked) |
| * 2,060 Zettelkasten holons         |
| * System health: 92 (+0.3/h)        |
|                                      |
| Ask me anything about the system.   |
|                                      |
+--------------------------------------+
| [Type a message...           [Send]] |
+--------------------------------------+
```

**STATE: Waiting (user sent message, shimmer)**
```
+--------------------------------------+
| Gemma AI Assistant        [-]  [X]   |
+--------------------------------------+
|                                      |
|              What should I prioritize|
|              this week?        [You] |
|                                      |
| [Gemma 3]                           |
| ████████████░░░░░ (shimmer)          |
| ██████░░░░░░░░░░░ (shimmer)          |
|                                      |
+--------------------------------------+
| [Type a message...           [Send]] |
+--------------------------------------+

Shimmer: 3 bars, gradient animation.
Model label: "Gemma 3" badge (small, muted).
```

**STATE: ResponseStreaming (response received)**
```
+--------------------------------------+
| Gemma AI Assistant        [-]  [X]   |
+--------------------------------------+
|                                      |
|              What should I prioritize|
|              this week?        [You] |
|                                      |
| [Gemma 3, 3.2s]                     |
| Based on current state (47 active,  |
| 12 blocked, health 92):             |
|                                      |
| 1. L4 System (78%) — Unblock T005   |
|    Build pipeline. Blocks 3 tasks.  |
|                                      |
| 2. L0 Constitutional — T001 NIF is  |
|    safety-critical (SC-NIF-003).    |
|                                      |
| 3. L6 Ecosystem — T009 Zenoh quorum |
|    affects mesh (SC-ZENOH-001).     |
|                                      |
+--------------------------------------+
| [Type a message...           [Send]] |
+--------------------------------------+

Message: left-aligned, card_bg, 14px.
Model badge: "Gemma 3, 3.2s" (model + latency).
User message: right-aligned, accent bg, dark text.
```

---

## 12. Component C11: Change Log

### 12.1 State Machine

```
S = {Empty, Ticker, Expanded, Toast}

-> = {
  Empty      --NewEntry--> Ticker (desktop) | Toast (mobile)
  Ticker     --NewEntry--> Ticker (prepend)
  Ticker     --Click--> Expanded
  Expanded   --Click--> Ticker
  Toast      --[3s timeout]--> Empty (mobile)
  Toast      --NewEntry--> Toast (replace)
}
```

### 12.2 States with Dummy Data

**STATE: Ticker (desktop, 3 recent entries)**
```
+================================================================================+
| [09:01] T002 status: pending->active (claude-1) | [08:45] T067 pending->acti..|
+================================================================================+

Single line, horizontal scroll. Latest entry shown first.
Auto-scrolls when new entry arrives.
```

**STATE: Expanded (desktop, 10 entries visible)**
```
+================================================================================+
| CHANGE LOG (50 entries)                                         [Collapse ^]   |
+--------------------------------------------------------------------------------+
| [09:15] T003 status: active -> completed (AN)         [status_change]         |
| [09:01] T002 status: pending -> active (claude-1)     [status_change]         |
| [08:45] T067 status: pending -> active (gemini-2)     [status_change]         |
| [08:30] T099 status: active -> completed (claude-1)   [status_change]         |
| [08:15] T089 priority: P2 -> P1 (AN)                  [priority_change]       |
| [08:00] T101 created: "New CRDT merge test" P2        [new_task]              |
| [07:45] T045 status: pending -> active (claude-1)     [status_change]         |
| [07:30] T032 owner: -- -> AN                          [data_diff]             |
| [07:15] T078 description updated (gemini-2)           [data_diff]             |
| [07:00] System restart: 3 tasks re-queued             [system_event]          |
+--------------------------------------------------------------------------------+

Entry types color-coded:
  status_change: accent
  priority_change: amber
  new_task: green
  task_removed: red
  data_diff: muted
  system_event: blue
Height: 300px with scroll. Click "Collapse" to return to ticker.
```

**STATE: Toast (mobile, single entry)**
```
                    +-------------------------------+
                    | T002 pending -> active        |
                    | by claude-1 at 09:01          |
                    +-------------------------------+
                    
Position: bottom of screen, above bottom nav.
Duration: 3s, then fade out (500ms).
New toast replaces current (no stack).
```

---

## 13. Component C12: Fractal Filter

### 13.1 State Machine

```
S = {AllShown, LayerSelected(L), MultipleSelected}

-> = {
  AllShown          --ClickLayer(L)--> LayerSelected(L)
  LayerSelected(L)  --ClickLayer(L)--> AllShown  (toggle off)
  LayerSelected(L)  --ClickLayer(L2)--> LayerSelected(L2) (switch)
  LayerSelected(L)  --ClickAll--> AllShown
}
```

### 13.2 States with Dummy Data

**STATE: AllShown (sidebar, no filter active)**
```
FRACTAL HEALTH
+-------------------+
| o L0 CONST        |
| ████████████  95%  |
| 3 blk  2 act      |
+-------------------+
| o L1 ATOM         |
| ██████████   88%   |
| 1 blk  1 act      |
+-------------------+
| o L2 COMP         |
| ████████████  92%  |
| 0 blk  5 act      |
+-------------------+
| o L3 TRANS        |
| ██████████   85%   |
| 4 blk  8 act      |
+-------------------+
| o L4 SYST    [!]  |
| ██████       78%   |
| 2 blk  3 act      |
+-------------------+
| o L5 COG          |
| ████████████  91%  |
| 1 blk  4 act      |
+-------------------+
| o L6 ECO          |
| ████████     82%   |
| 2 blk  2 act      |
+-------------------+
| o L7 FED          |
| ████████████  94%  |
| 0 blk  1 act      |
+-------------------+

Health bar colors: <80%=red, <90%=amber, >=90%=green.
[!] indicator on L4 (lowest health).
No row has accent border (no filter active).
```

**STATE: LayerSelected(L4) — L4 filtered**
```
FRACTAL HEALTH
+-------------------+
| o L0 CONST        |
| ████████████  95%  |
|                    |  <- counts hidden for non-selected
+-------------------+
| o L1 ATOM         |
| ██████████   88%   |
|                    |
+-------------------+
| o L2 COMP         |
| ████████████  92%  |
|                    |
+-------------------+
| o L3 TRANS        |
| ██████████   85%   |
|                    |
+-------------------+
|[accent border 4px] |
| o L4 SYST    [!]  |  <- SELECTED: accent left border
| ██████       78%   |
| 2 blk  3 act      |  <- counts visible
| [active bg]        |
+-------------------+
| o L5 COG          |
| ████████████  91%  |
|                    |
+-------------------+
| o L6 ECO          |
| ████████     82%   |
|                    |
+-------------------+
| o L7 FED          |
| ████████████  94%  |
|                    |
+-------------------+

Selected layer: accent left border (4px), darker background, counts shown.
Non-selected: health bar only, counts hidden (cleaner view).
Main grid: filtered to L4 tasks only.
URL: /planning?layer=4
Chips bar: L4 chip filled with layer color.
```

**Chips bar (controls row, all viewports >= 768px):**
```
AllShown:       [All*] [L0] [L1] [L2] [L3] [L4] [L5] [L6] [L7]
L4 Selected:    [All]  [L0] [L1] [L2] [L3] [L4*] [L5] [L6] [L7]
                                               ^^^^
                                         filled purple bg, dark text

* = active chip (filled background)
Inactive: border in layer color, text in layer color
Active: filled with layer color, dark text
```

---

## 14. Full Page Composite States

### 14.1 Nominal Operation (Desktop 1440px)
```
Page: Connected, View: Grid, Filter: None, Detail: Closed, Chat: Hidden
+================================================================================+
| C3I o Live Act:47 Blk:12 P0:3 Health:92 ████████░░ ▲+0.3/h OODA:28ms        | C1:Healthy
| [Grid*] [Kanban] [Timeline] [Analytics] [Fractal] | Ctrl+K _____ | [All*]    | C12:AllShown
+--------+-----------------------------------------------------------------------+
|FRACTAL | ID  | Title              | Status | P | Owner| Age| L                | C4:Populated
|HEALTH  | T001| Guardian NIF...    | BLOCK  | 0 | AN   | 3d | L0               |
| L0 95% | T005| Build pipeline...  | BLOCK  | 0 | AN   | 5d | L4               |
| L1 88% | T009| Zenoh quorum...    | BLOCK  | 0 | CL   | 1d | L6               | C12:Sidebar
| L2 92% | T002| Zenoh federation   | ACTIVE | 1 | AN   |12h | L6               |
| L3 85% | T003| Hot reload...      | ACTIVE | 1 | CL   | 1d | L4               |
| L4 78% | T015| SQLite WAL...      | ACTIVE | 2 | AN   | 4h | L3               |
| L5 91% | T023| MCP tool wire...   | PEND   | 1 | --   | 3d | L5               |
| L6 82% | ... |                    |        |   |      |    |                  |
| L7 94% |     |                    |        |   |      |    |                  |
+--------+-----------------------------------------------------------------------+
| d(H)/dt:+0.3/h IMPROVING | SLO:99.2% budget:0.8% | o WS Connected 1s ago    | C11:Ticker
+================================================================================+
```

### 14.2 Incident Mode (Desktop, L4 filtered, detail open, AI running)
```
Page: Connected, View: Grid, Filter: L4, Detail: Open(T005), Chat: Hidden
+================================================================================+
| C3I o Live Act:47 Blk:12 P0:3 Health:92 ████████░░ ▲+0.3/h OODA:28ms        | C1:Healthy
| [Grid*] [Kanban] [Timeline] [Analytics] [Fractal] | Ctrl+K _____ | [L4*]     | C12:L4 Selected
+--------+----------------------------------------------+---------------------------+
|FRACTAL | ID  | Title              | Status | P |Age| L| Task Detail      [X]   | C9:Open
|HEALTH  | T005| Build pipeline fix | BLOCK  | 0 | 5d|L4|                        |
| L0 95% | T017| DNS resolution     | BLOCK  | 1 | 4d|L4| T005 — Build pipeline  |
| L1 88% | T003| Hot reload beam    | ACTIVE | 1 | 1d|L4| [BLOCKED] [P0] [L4]    |
| L2 92% | T032| TLS cert rotation  | BLOCK  | 1 | 6d|L4| Age: 5d  Owner: AN    |
| L3 85% | T041| Podman health fp   | BLOCK  | 2 | 1d|L4| ----------------       | C4:Filtered(L4)
|[L4 sel]|     | 5 of 5 L4 tasks    |        |   |   |  | Description:           |
| L5 91% |     |                    |        |   |   |  | Podman build fails     |
| L6 82% |     |                    |        |   |   |  | with cache miss...     |
| L7 94% |     |                    |        |   |   |  |                        |
|        |     |                    |        |   |   |  | AI Analysis:           | C10:Inline
|        |     |                    |        |   |   |  | [Gemma 3 analyzing...] |
|        |     |                    |        |   |   |  | ████████░░░ (shimmer)  |
+--------+----------------------------------------------+---------------------------+
| d(H)/dt:+0.3/h | SLO:99.2% | [09:01] T002 pending->active (claude-1)          | C11:Ticker
+================================================================================+
```

### 14.3 Mobile Triage (393x852, 3 P0 critical)
```
Page: Connected, View: Triage, Filter: None
+-------------------------------------------+
| [C3I] o Live  Health: 92  [AI]   [=]      | C1:Healthy(mobile)
+-------------------------------------------+
| !!! CRITICAL (3)              [red border] | C4.zones:Normal
| +---------------------------------------+ |
| | T001  Guardian NIF crash      [P0]    | |
| | L0 Constitutional . 3d ago            | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
| +---------------------------------------+ |
| | T005  Build pipeline fix      [P0]    | |
| | L4 System . 5d ago                    | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
| +---------------------------------------+ |
| | T009  Zenoh quorum split      [P0]    | |
| | L6 Ecosystem . 1d ago                 | |
| | [Activate] [Escalate] [Detail]        | |
| +---------------------------------------+ |
| !! ATTENTION (9)            [amber border] |
| +---------------------------------------+ |
| | T012  Auth timeout        [Blocked]   | |
| | L3 Transaction . 2d ago              | |
| | [Unblock] [Reassign] [Detail]        | |
| +---------------------------------------+ |
| (+ 8 more)                               |
| OK NOMINAL (166)  [collapsed]     [v]     |
+-------------------------------------------+
|  [Search]    |   [Grid]    |   [AI]       | C8/C4/C10
+-------------------------------------------+
```

### 14.4 Dark Cockpit (health=98, 0 blocked, all nominal)
```
Desktop:
+================================================================================+
| C3I o Live Act:47 Blk:0 P0:0  Health:98 ██████████ ▲+0.1/h OODA:12ms        | C1:Healthy
| [Grid*] [Kanban] [Timeline] [Analytics] [Fractal] | Ctrl+K _____ | [All*]    |
+--------+-----------------------------------------------------------------------+
|FRACTAL |                                                                       |
|HEALTH  |                     ALL SYSTEMS NOMINAL                               |
| L0 98% |                                                                       |
| L1 97% |                     0 blocked tasks                                   |
| L2 99% |                     47 active, 131 pending                            |
| L3 96% |                     Health trend: +0.1/h (stable)                     |
| L4 95% |                                                                       |
| L5 98% |                     Dark Cockpit Mode: suppressing nominal noise      |
| L6 97% |                                                                       |
| L7 99% |  [Show all tasks]                                                     |
+--------+-----------------------------------------------------------------------+
| d(H)/dt:+0.1/h STABLE | SLO:99.9% budget:0.1% | o Connected 1s ago           |
+================================================================================+

Dark Cockpit: When blocked=0 and health>95, suppress the task grid.
Show centered "ALL SYSTEMS NOMINAL" message.
[Show all tasks] button to override and show full grid.
This IS homeostasis (SC-BIO-EVO-001).
```

---

## 15. Transition Timing Budget

| Transition | Target | Max | CSS Property |
|-----------|--------|-----|-------------|
| Page load -> first paint | 1.0s | 1.5s | N/A (SSR) |
| WS connect -> data shown | 200ms | 500ms | N/A (JS) |
| View switch (tab click) | 100ms | 200ms | display:none/block |
| Filter apply | 50ms | 100ms | Tabulator setFilter |
| Row highlight fade | 1.8s | 2.0s | background-color transition |
| Detail panel slide | 200ms | 300ms | transform: translateX |
| Detail panel close | 150ms | 200ms | transform: translateX |
| Search modal open | 100ms | 150ms | opacity + transform |
| Chat panel open | 200ms | 300ms | transform: translateY |
| Toast appear | 200ms | 200ms | transform: translateY |
| Toast disappear | 500ms | 500ms | opacity |
| Health bar color change | 500ms | 800ms | background-color transition |
| Ring dasharray update | 300ms | 500ms | stroke-dasharray transition |
| Shimmer animation cycle | 1.5s | 1.5s | background-position |

---

## 16. Error States (all components)

| Component | Error State | Display | Recovery |
|-----------|------------|---------|----------|
| C1 | NIF plan_status() fails | "Health: --" gray, red dot | Auto-retry 5s |
| C2 | No data | Empty rings, gray | Shows on data load |
| C4 | API timeout | "Loading tasks..." spinner | Retry button |
| C5 | No tasks in column | "No {status} tasks" text | N/A |
| C6 | No temporal data | "No timeline data" | N/A |
| C7 | Computation error | "Analytics unavailable" | Retry 30s |
| C8 | NIF search fails | "Search error: {msg}" | Show input |
| C9 | Task not found | "Task {id} not found" | Close panel |
| C10 | Both Gemma offline | "AI unavailable. Use Knowledge." | Retry button |
| C11 | WS disconnected | "Log paused — reconnecting..." | Auto-reconnect |
| C12 | No layer data | All bars at 0%, gray | Shows on data |
