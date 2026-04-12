# Planning Page — Complete Specification
# योजना पृष्ठ — सम्पूर्ण विनिर्देश

**Date**: 2026-04-12 | **Version**: v22.6.1-DHARMA | **Page**: `/planning`
**Design**: Concept F (Adaptive Cockpit Hybrid) — Score: 0.905

---

# PART 1: PAGE STATE MACHINE

## 1.1 Page States

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PLANNING PAGE STATE DIAGRAM                      │
│                                                                      │
│                         ┌──────────┐                                │
│                    ┌───>│ LOADING  │<────────────────┐              │
│                    │    └────┬─────┘                  │              │
│                    │         │                        │              │
│                    │    WsConnect              Recover│              │
│                    │         │                        │              │
│                    │         v                        │              │
│              WsReconnect  ┌──────────────┐     ┌─────┴────┐        │
│                    │      │  CONNECTED   │────>│  ERROR   │        │
│                    │      │              │     └──────────┘        │
│                    │      │ .view=Grid   │                          │
│                    │      │ .view=Kanban │                          │
│                    │      │ .view=Timeline                          │
│                    │      │ .view=Analytics                         │
│                    │      │ .view=Fractal│                          │
│                    │      └──┬───┬───┬───┘                          │
│                    │         │   │   │                               │
│              ┌─────┴──────┐  │   │   │                              │
│              │DISCONNECTED│<─┘   │   │                              │
│              └────────────┘      │   │                               │
│                                  │   │                               │
│                    FilterLayer   │   │ ClickTask                    │
│                         │        │   │                               │
│                         v        │   v                               │
│                   ┌──────────┐   │  ┌────────────┐                  │
│                   │ FILTERED │   │  │ DETAIL_OPEN│                  │
│                   └──────────┘   │  └──────┬─────┘                  │
│                         │        │         │                         │
│                    ClearFilter   │    OpenChat                       │
│                         │        │         │                         │
│                         v        │         v                         │
│                   ┌──────────┐   │  ┌────────────┐                  │
│                   │CONNECTED │   │  │ CHAT_OPEN  │                  │
│                   └──────────┘   │  └────────────┘                  │
│                                  │                                   │
│                            Search│                                   │
│                                  v                                   │
│                           ┌──────────┐                              │
│                           │SEARCHING │                              │
│                           └──────────┘                              │
│                                                                      │
│  3s no WS message:  CONNECTED ──> STALE ──> DISCONNECTED           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 1.2 View Sub-State Machine

```
┌───────────────────────────────────────────────┐
│           VIEW SUB-STATES                      │
│                                                │
│   ┌──────┐  "2"  ┌────────┐  "3"  ┌────────┐ │
│   │ GRID │──────>│ KANBAN │──────>│TIMELINE│ │
│   │  "1" │<──────│        │<──────│        │ │
│   └──┬───┘       └────────┘       └────────┘ │
│      │ "4"                           "5"  ^   │
│      v                                    │   │
│   ┌──────────┐              ┌─────────┐   │   │
│   │ANALYTICS │──────────────│FRACTAL  │───┘   │
│   └──────────┘     "5"     └─────────┘        │
│                                                │
│   All views reachable from all views           │
│   Keyboard: 1=Grid, 2=Kanban, 3=Timeline,     │
│             4=Analytics, 5=Fractal             │
│   Tab clicks also work                         │
└───────────────────────────────────────────────┘
```

## 1.3 Viewport Adaptation State Machine

```
┌──────────────────────────────────────────────────────────────┐
│              VIEWPORT ADAPTATION                              │
│                                                               │
│   window.innerWidth triggers CSS @media:                      │
│                                                               │
│   <768px          768-1023px       1024-1399px      >=1400px │
│   ┌──────────┐   ┌──────────┐    ┌──────────┐    ┌────────┐ │
│   │ MOBILE   │   │ TABLET   │    │ DESKTOP  │    │  WIDE  │ │
│   │          │   │          │    │          │    │        │ │
│   │ Layout:  │   │ Layout:  │    │ Layout:  │    │Layout: │ │
│   │ Triage   │   │ Kanban   │    │ Bloomberg│    │Bloom+  │ │
│   │ (Concept │   │ 2-column │    │ Grid     │    │Fractal │ │
│   │  D)      │   │ (Concept │    │ (Concept │    │Sidebar │ │
│   │          │   │  B)      │    │  A)      │    │(A+E)   │ │
│   │ Bottom   │   │ View     │    │ View     │    │View    │ │
│   │ nav bar  │   │ tabs     │    │ tabs     │    │tabs    │ │
│   │ visible  │   │ visible  │    │ visible  │    │visible │ │
│   │ Sidebar  │   │ Sidebar  │    │ Sidebar  │    │Sidebar │ │
│   │ hidden   │   │ hidden   │    │ hidden   │    │VISIBLE │ │
│   └──────────┘   └──────────┘    └──────────┘    └────────┘ │
│                                                               │
│   Same HTML, CSS controls visibility:                         │
│     .triage-zones  { display:none -> block on <768 }         │
│     .kanban-board  { display:none -> flex on 768-1023 }      │
│     .task-grid     { display:none -> block on >=1024 }       │
│     .fractal-sidebar { display:none -> block on >=1400 }     │
└──────────────────────────────────────────────────────────────┘
```

---

# PART 2: COMPONENT STATE MACHINES WITH DUMMY DATA

---

## C1: WEATHER BAR

### State Diagram

```
┌───────────────────────────────────────────────────────┐
│                C1 WEATHER BAR STATES                   │
│                                                        │
│                    ┌─────────┐                         │
│               ┌───>│ LOADING │<────────┐              │
│               │    └────┬────┘         │              │
│               │         │              │              │
│          WsReconnect    │ DataUpdate   │ Timeout      │
│               │         │              │              │
│               │    ┌────v────┐    ┌────┴──────────┐   │
│               │    │         │    │               │   │
│               ├────│ HEALTHY │    │ DISCONNECTED  │   │
│               │    │ h>=85   │    │               │   │
│               │    └────┬────┘    └───────────────┘   │
│               │         │              ^              │
│               │    DataUpdate(h<85)     │              │
│               │         │          WsDisconnect       │
│               │    ┌────v────┐         │              │
│               │    │DEGRADED │─────────┤              │
│               │    │70<=h<85 │         │              │
│               │    └────┬────┘         │              │
│               │         │              │              │
│               │    DataUpdate(h<70)     │              │
│               │         │              │              │
│               │    ┌────v────┐         │              │
│               └────│CRITICAL │─────────┘              │
│                    │  h<70   │                         │
│                    └─────────┘                         │
└───────────────────────────────────────────────────────┘
```

### State: LOADING
```
Desktop (1440px):
┌════════════════════════════════════════════════════════════════════┐
│ C3I   ░░░   Act: --   Blk: --   P0: --   Health: -- ░░░░░░░░░░  │
│ [dim]       [shimmer] [shimmer] [shimmer]            [shimmer]   │
└════════════════════════════════════════════════════════════════════┘
Behavior: All metrics show "--" with shimmer animation (gradient sweep L->R, 1.5s cycle).
Live dot: gray, not animated. No data source connected yet.

Mobile (375px):
┌───────────────────────────────────┐
│ [C3I]  ░░░  Health: --  [AI] [=] │
└───────────────────────────────────┘
```

### State: HEALTHY (health=92)
```
Desktop:
┌════════════════════════════════════════════════════════════════════┐
│ C3I  ●Live  Act: 47   Blk: 12   P0: 3    Health: 92 ████████░░  │
│      [grn]  [grn bg]  [red bg]  [red      [grn txt]  [green bar] │
│                                  pulse]               ▲+0.3/h    │
│                                                       OODA:28ms  │
└════════════════════════════════════════════════════════════════════┘
Data source: NIF plan_status() = {active:47, blocked:12, completed:234, pending:85, p0:3}
             health_calculus.derivative() = +0.3
             ooda_cycle.latency() = 28ms
Live dot: 5px green circle, CSS pulse animation (scale 1.0->1.3->1.0, 2s)
Health bar: 120px wide, filled 92%, green (#3dd68c)
P0 badge: red background, white text, pulse animation when p0>0
dH/dt arrow: ▲ green (positive = improving)
Update: Every 1s via WebSocket. Only re-render changed values (React-style diff).

Mobile:
┌───────────────────────────────────┐
│ [C3I]  ●Live  Health: 92  [AI][=]│
│         [grn]  [green]           │
└───────────────────────────────────┘
```

### State: DEGRADED (health=72)
```
Desktop:
┌════════════════════════════════════════════════════════════════════┐
│ C3I  ●Live  Act: 30   Blk: 28   P0: 7    Health: 72 █████░░░░░  │
│      [grn]  [amb bg]  [red bg]  [red      [amb txt]  [amber bar] │
│                                  pulse]               ▼-1.2/h    │
│                                                       OODA:45ms  │
└════════════════════════════════════════════════════════════════════┘
Changes from Healthy: Act badge turns amber. Health bar amber. dH/dt arrow red (▼ declining).
Transition animation: bar color green->amber over 500ms ease.
```

### State: CRITICAL (health=45)
```
Desktop:
┌════════════════════════════════════════════════════════════════════┐
│ C3I  ⚠ALERT Act: 10   Blk: 55   P0: 15   Health: 45 ██░░░░░░░  │
│      [RED]  [red bg]  [red bg]  [red       [red txt]  [RED bar]  │
│      [pulse]                     pulse]                ▼-3.8/h   │
│                                                        OODA:120ms│
│                                                        [RED!]    │
└════════════════════════════════════════════════════════════════════┘
Changes: Live dot replaced with red ⚠ exclamation, pulsing.
Entire header has subtle red background pulse (rgba(255,71,87,0.05) -> 0.15, 2s cycle).
OODA 120ms exceeds 100ms budget -> shown in red.
All metric badges turn red.
```

### State: DISCONNECTED
```
Desktop:
┌════════════════════════════════════════════════════════════════════┐
│ C3I  ✕OFF   Act: 47?  Blk: 12?  P0: 3?   Health: 92? ████████░ │
│      [RED]  [gray]    [gray]    [gray]     [gray txt] [gray bar] │
│      [static]                                          STALE     │
│                                              Retry in 4s...      │
└════════════════════════════════════════════════════════════════════┘
All values suffixed with "?" (may be stale). All colors grayed out.
"STALE" label in red. Countdown to next reconnect attempt.
No animations (static — no data flowing).
```

---

## C2: PROGRESS RINGS

### State Diagram

```
┌───────────────────────────────────────────┐
│          C2 PROGRESS RINGS STATES          │
│                                            │
│              ┌─────────┐                   │
│              │ LOADING  │                  │
│              └────┬─────┘                  │
│                   │ DataUpdate             │
│              ┌────┴────┐                   │
│              │         │                   │
│    ┌─────────┤ NORMAL  ├──────────┐       │
│    │         │ a>0,b>0 │          │       │
│    │         └─────────┘          │       │
│    │              │               │       │
│    │ a=0,b=all    │           b=0,c=all   │
│    │              │               │       │
│    v              │               v       │
│ ┌───────────┐     │        ┌───────────┐  │
│ │ALL_BLOCKED│     │        │ALL_COMPLETE│  │
│ │ (crisis)  │     │        │(dark cock.)│  │
│ └───────────┘     │        └───────────┘  │
│                   │                        │
│              a=0,b=0,c=0                   │
│                   │                        │
│              ┌────v────┐                   │
│              │  EMPTY  │                   │
│              └─────────┘                   │
└───────────────────────────────────────────┘
```

### State: NORMAL (active=47, blocked=12, completed=234)
```
     Active           Blocked         Completed
    ╭──────╮         ╭──────╮         ╭──────╮
   ╱ ╭────╮ ╲      ╱ ╭────╮ ╲      ╱ ╭────╮ ╲
  │ │  47  │ │    │ │  12  │ │    │ │ 234  │ │
   ╲ ╰────╯ ╱      ╲ ╰────╯ ╱      ╲ ╰────╯ ╱
    ╰──────╯         ╰──────╯         ╰──────╯
   [blue 12%]       [red 3%]       [green 62%]
    47/378            12/378          234/378

Ring spec:
  SVG circle: r=45 (desktop), stroke-width=6, stroke-linecap=round
  Background ring: #1e2a3a (border color)
  Fill ring: stroke-dasharray = 2*pi*r * (count/total)
  Center text: count, 18px bold, ring color
  Below: label 12px, percentage 12px muted
  Sizes: 70px mobile, 90px tablet, 100px desktop, 110px wide
  Animation: dasharray transitions over 300ms on data update
```

### State: ALL_BLOCKED (active=0, blocked=88, completed=0)
```
     Active           Blocked         Completed
    ╭──────╮         ╭──────╮         ╭──────╮
   ╱ ╭────╮ ╲      ╱ ╭────╮ ╲      ╱ ╭────╮ ╲
  │ │   0  │ │    │ │  88  │ │    │ │   0  │ │
   ╲ ╰────╯ ╱      ╲ ╰────╯ ╱      ╲ ╰────╯ ╱
    ╰──────╯         ╰──────╯         ╰──────╯
   [gray empty]   [RED 100% PULSE]  [gray empty]

Blocked ring: full circle, red, CSS pulse (scale 1.0->1.05->1.0, 1s).
Active + Completed: empty gray rings.
This state triggers cockpit escalation to Bright/Emergency mode.
```

### State: ALL_COMPLETE (active=0, blocked=0, completed=378)
```
     Active           Blocked         Completed
    ╭──────╮         ╭──────╮         ╭──────╮
   ╱        ╲      ╱        ╲      ╱ ╭────╮ ╲
  │          │    │          │    │ │ 378  │ │
   ╲        ╱      ╲        ╱      ╲ ╰────╯ ╱
    ╰──────╯         ╰──────╯         ╰──────╯
   [hidden]         [hidden]       [GREEN 100%]

Dark Cockpit: Active and Blocked rings hidden (opacity:0).
Only Completed ring shown, full green circle.
```

---

## C4: TASK GRID

### State Diagram

```
┌───────────────────────────────────────────────────────────┐
│                 C4 TASK GRID STATES                        │
│                                                            │
│              ┌─────────┐                                   │
│         ┌───>│ LOADING  │<──── Retry                      │
│         │    └────┬─────┘                                  │
│         │         │ DataLoad                               │
│         │    ┌────v─────────┐       ┌────────┐            │
│         │    │  POPULATED   │──────>│ ERROR  │            │
│         │    │  (15 rows)   │       └────────┘            │
│         │    └──┬──┬──┬──┬──┘                              │
│         │       │  │  │  │                                 │
│         │  ClickHeader │  │  WsTaskUpdate(id)             │
│         │       │  │  │  │                                 │
│         │  ┌────v──┘  │  └──────┐                         │
│         │  │ SORTED   │         │                         │
│         │  │ (col,dir)│    ┌────v──────────┐              │
│         │  └──────────┘    │ ROW_HIGHLIGHT │              │
│         │                  │  (id, 1.8s)   │              │
│      FilterLayer           └───────────────┘              │
│         │                       │ 1.8s timeout            │
│    ┌────v──────┐                v                         │
│    │ FILTERED  │          POPULATED                       │
│    │ (layer=L) │                                          │
│    └────┬──────┘         ┌─────────┐                     │
│         │ DataLoad(0)    │  EMPTY  │                     │
│         └───────────────>│         │                     │
│                          └─────────┘                     │
│                                                            │
│  Search(q) -> Filtered by query (same state as FILTERED)  │
└───────────────────────────────────────────────────────────┘
```

### State: POPULATED — Dummy Data (15 rows)
```
┌──────┬──────────────────────────────┬────────┬────┬───────┬──────┬─────────┐
│ ID   │ Title                        │ Status │ P  │ Owner │ Age  │ Layer   │
├══════╪══════════════════════════════╪════════╪════╪═══════╪══════╪═════════┤
│▌T001 │ Guardian NIF crash isolation │ BLOCK  │ P0 │ AN    │ 3d   │ ● L0   │
│▌T005 │ Build pipeline podman fix    │ BLOCK  │ P0 │ AN    │ 5d   │ ● L4   │
│▌T009 │ Zenoh quorum split-brain     │ BLOCK  │ P0 │ CL    │ 1d   │ ● L6   │
│▌T012 │ Auth timeout middleware      │ BLOCK  │ P1 │ AN    │ 2d   │ ● L3   │
│▌T017 │ DNS resolution flaky         │ BLOCK  │ P1 │ --    │ 4d   │ ● L4   │
│▌T028 │ DB migration stuck           │ BLOCK  │ P1 │ AN    │ 2d   │ ● L3   │
├──────┼──────────────────────────────┼────────┼────┼───────┼──────┼─────────┤
│▌T002 │ Zenoh multi-region federat.  │ ACTIVE │ P1 │ AN    │ 12h  │ ● L6   │
│▌T003 │ Hot reload beam code server  │ ACTIVE │ P1 │ CL    │ 1d   │ ● L4   │
│▌T015 │ SQLite WAL checkpoint tune   │ ACTIVE │ P2 │ AN    │ 4h   │ ● L3   │
│▌T045 │ OTel trace span correlation  │ ACTIVE │ P1 │ CL    │ 6h   │ ● L1   │
│▌T067 │ A2UI wave2 catalog complete  │ ACTIVE │ P2 │ AN    │ 8h   │ ● L2   │
├──────┼──────────────────────────────┼────────┼────┼───────┼──────┼─────────┤
│ T023 │ MCP tool dispatch wiring     │ PEND   │ P1 │ --    │ 3d   │ ● L5   │
│ T034 │ Badge component CSS polish   │ PEND   │ P2 │ --    │ 1d   │ ● L2   │
│ T078 │ Mesh topology visualization  │ PEND   │ P1 │ --    │ 5d   │ ● L6   │
│ T090 │ Gateway version vector sync  │ PEND   │ P2 │ --    │ 3d   │ ● L7   │
└──────┴──────────────────────────────┴────────┴────┴───────┴──────┴─────────┘

Legend: ▌= left border color (red=BLOCKED, blue=ACTIVE, gray=PENDING)
        ● = layer color dot
        Status: filled badge (BLOCK=red bg, ACTIVE=blue bg, PEND=gray bg)
        P: badge (P0=red, P1=amber, P2=green, P3=gray)
        Age: green(<1d), amber(1-7d), red(>7d)
        Sort default: Status ASC (blocked first), then Priority ASC, then Age DESC
        Row height: 36px. Alternating: even=#0e121c, odd=transparent.
        Click row -> opens C9 Detail Panel.
```

### State: FILTERED (L4 System — 5 tasks)
```
┌──────┬──────────────────────────────┬────────┬────┬───────┬──────┬─────────┐
│ ID   │ Title                        │ Status │ P  │ Owner │ Age  │ Layer   │
├══════╪══════════════════════════════╪════════╪════╪═══════╪══════╪═════════┤
│▌T005 │ Build pipeline podman fix    │ BLOCK  │ P0 │ AN    │ 5d   │ ● L4   │
│▌T017 │ DNS resolution flaky         │ BLOCK  │ P1 │ --    │ 4d   │ ● L4   │
│▌T032 │ TLS cert rotation            │ BLOCK  │ P1 │ --    │ 6d   │ ● L4   │
│▌T003 │ Hot reload beam code server  │ ACTIVE │ P1 │ CL    │ 1d   │ ● L4   │
│▌T041 │ Podman health false positive │ BLOCK  │ P2 │ AN    │ 1d   │ ● L4   │
└──────┴──────────────────────────────┴────────┴────┴───────┴──────┴─────────┘
│ Showing 5 of 5 L4 tasks                    ┌──────────────────────────────┐│
│                                             │ Filter: L4 System       [✕] ││
│                                             └──────────────────────────────┘│

Filter chip at bottom. URL: /planning?layer=4. Click [✕] to clear.
```

### State: ROW_HIGHLIGHT (T002 status changed)
```
│▌T002 │ Zenoh multi-region federat.  │ ACTIVE │ P1 │ AN    │ 12h  │ ● L6   │
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Background: #1a2a35 (accent-tinted) fading to transparent over 1.8s
  Triggered by: WS "task_update" message with id=T002
```

### State: EMPTY
```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                                                                              │
│                     No tasks match current filters                           │
│                                                                              │
│                Try clearing filters or broadening search                     │
│                                                                              │
│                         [Clear All Filters]                                  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## C4.zones: MOBILE TRIAGE

### State Diagram

```
┌────────────────────────────────────────────────┐
│           C4.zones TRIAGE STATES                │
│                                                 │
│           ┌─────────┐                           │
│           │ LOADING  │                          │
│           └────┬─────┘                          │
│                │                                │
│      ┌─────────┼──────────┬──────────┐         │
│      │         │          │          │         │
│      v         v          v          v         │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │
│ │ NORMAL │ │NO_CRIT │ │ALL_NOM │ │ALL_CRIT│  │
│ │p0>0    │ │p0=0    │ │blk=0   │ │p0=all  │  │
│ │blk>0   │ │blk>0   │ │        │ │        │  │
│ └───┬────┘ └────────┘ └────────┘ └────────┘  │
│     │                                         │
│     │ Activate last P0                        │
│     └─────────────> NO_CRITICAL               │
│                                                │
│     All unblocked -> ALL_NOMINAL               │
│     (Dark Cockpit mode)                        │
└────────────────────────────────────────────────┘
```

### State: NORMAL (3 critical, 9 attention, 166 nominal)
```
┌───────────────────────────────────────┐
│ [C3I] ●Live  Health: 92   [AI]  [≡]  │ 44px header
├───────────────────────────────────────┤
│▐ ⚠ CRITICAL (3)                      │ red left border 4px
│▐                                      │
│▐ ┌─────────────────────────────────┐  │
│▐ │ T001  Guardian NIF crash   [P0] │  │ 80px card
│▐ │ L0 Constitutional · 3d ago     │  │
│▐ │ ┌──────┐ ┌────────┐ ┌──────┐  │  │ 44px buttons
│▐ │ │Activ.│ │Escalate│ │Detail│  │  │
│▐ │ └──────┘ └────────┘ └──────┘  │  │
│▐ └─────────────────────────────────┘  │
│▐ ┌─────────────────────────────────┐  │
│▐ │ T005  Build pipeline fix  [P0]  │  │
│▐ │ L4 System · 5d ago              │  │
│▐ │ ┌──────┐ ┌────────┐ ┌──────┐  │  │
│▐ │ │Activ.│ │Escalate│ │Detail│  │  │
│▐ │ └──────┘ └────────┘ └──────┘  │  │
│▐ └─────────────────────────────────┘  │
│▐ ┌─────────────────────────────────┐  │
│▐ │ T009  Zenoh quorum split  [P0]  │  │
│▐ │ L6 Ecosystem · 1d ago           │  │
│▐ │ ┌──────┐ ┌────────┐ ┌──────┐  │  │
│▐ │ │Activ.│ │Escalate│ │Detail│  │  │
│▐ │ └──────┘ └────────┘ └──────┘  │  │
│▐ └─────────────────────────────────┘  │
├───────────────────────────────────────┤
│▐ ⏳ ATTENTION (9)     [amber border]  │
│▐ ┌─────────────────────────────────┐  │
│▐ │ T012  Auth timeout    [Blocked] │  │ 72px card
│▐ │ L3 Transaction · 2d ago         │  │
│▐ │ ┌──────┐ ┌────────┐ ┌──────┐  │  │
│▐ │ │Unblk.│ │Reassign│ │Detail│  │  │
│▐ │ └──────┘ └────────┘ └──────┘  │  │
│▐ └─────────────────────────────────┘  │
│▐ (+ 8 more, tap header to expand)    │
├───────────────────────────────────────┤
│  ✓ NOMINAL (166)  [collapsed]   [▼]  │
├───────────────────────────────────────┤
│   Search    │    Grid    │     AI     │ 44px bottom nav
└─────────────┴────────────┴────────────┘
```

### State: ALL_NOMINAL (0 blocked, Dark Cockpit)
```
┌───────────────────────────────────────┐
│ [C3I] ●Live  Health: 98   [AI]  [≡]  │
├───────────────────────────────────────┤
│                                       │
│         ╭──────────╮                  │
│        ╱   ╭────╮   ╲                 │
│       │   │ 178  │   │                │
│        ╲   ╰────╯   ╱                 │
│         ╰──────────╯                  │
│                                       │
│      ALL SYSTEMS NOMINAL              │
│      0 blocked · 178 tasks            │
│                                       │
│      Dark Cockpit Mode Active         │
│                                       │
├───────────────────────────────────────┤
│  ✓ NOMINAL (178)  [expanded]    [▲]  │
│  ┌─────────────────────────────────┐  │
│  │ T002  Zenoh federation [Act P1] │  │
│  └─────────────────────────────────┘  │
│  (+ 177 more)                        │
├───────────────────────────────────────┤
│   Search    │    Grid    │     AI     │
└─────────────┴────────────┴────────────┘
```

---

## C5: KANBAN BOARD

### State Diagram

```
┌────────────────────────────────────────────┐
│            C5 KANBAN STATES                 │
│                                             │
│          ┌─────────┐                        │
│          │ LOADING  │                       │
│          └────┬─────┘                       │
│               │                             │
│        ┌──────┼──────┐                     │
│        │      │      │                     │
│        v      v      v                     │
│  ┌────────┐ ┌──────┐ ┌──────────────┐     │
│  │ NORMAL │ │EMPTY │ │SINGLE_COLUMN │     │
│  │ 4-col  │ │      │ │  (mobile)    │     │
│  └──┬──┬──┘ └──────┘ └──────────────┘     │
│     │  │                                   │
│     │  │ ClickDone                         │
│     │  v                                   │
│     │ ┌──────────────┐                     │
│     │ │DONE_EXPANDED │                     │
│     │ └──────────────┘                     │
│     │                                      │
│     │ col.count > 20                       │
│     v                                      │
│  ┌──────────┐                              │
│  │ OVERFLOW │ (virtual scroll active)      │
│  └──────────┘                              │
└────────────────────────────────────────────┘
```

### State: NORMAL — Dummy Data (desktop 4-column)
```
┌────────────────┬────────────────┬────────────────┬───────────────┐
│ BLOCKED (12)   │ PENDING (85)   │ ACTIVE (47)    │ DONE (234)    │
│ ████████████   │ ░░░░░░░░░░░░   │ ████████████   │ ████████████  │
├────────────────┼────────────────┼────────────────┼───────────────┤
│ ┌────────────┐ │ ┌────────────┐ │ ┌────────────┐ │               │
│ │ T001  [P0] │ │ │ T023  [P1] │ │ │ T002  [P1] │ │  234 tasks   │
│ │ Guardian   │ │ │ MCP tool   │ │ │ Zenoh fed  │ │  completed   │
│ │ NIF crash  │ │ │ dispatch   │ │ │ multi-reg  │ │               │
│ │ ● L0  3d   │ │ │ ● L5  3d   │ │ │ ● L6  12h  │ │  [tap to    │
│ │ ▄▄▄▄▄▄▄▄▄▄ │ │ │            │ │ │            │ │   expand]   │
│ └────────────┘ │ └────────────┘ │ └────────────┘ │               │
│ ┌────────────┐ │ ┌────────────┐ │ ┌────────────┐ │               │
│ │ T005  [P0] │ │ │ T034  [P2] │ │ │ T003  [P1] │ │               │
│ │ Build pipe │ │ │ Badge CSS  │ │ │ Hot reload │ │               │
│ │ podman fix │ │ │ polish     │ │ │ beam code  │ │               │
│ │ ● L4  5d   │ │ │ ● L2  1d   │ │ │ ● L4  1d   │ │               │
│ └────────────┘ │ └────────────┘ │ └────────────┘ │               │
│ ┌────────────┐ │ ┌────────────┐ │ ┌────────────┐ │               │
│ │ T009  [P0] │ │ │ T056  [P2] │ │ │ T015  [P2] │ │               │
│ │ Zenoh quor │ │ │ OODA opt   │ │ │ SQLite WAL │ │               │
│ │ split-brain│ │ │            │ │ │ checkpoint │ │               │
│ │ ● L6  1d   │ │ │ ● L5  2d   │ │ │ ● L3  4h   │ │               │
│ └────────────┘ │ └────────────┘ │ └────────────┘ │               │
│ (+9 more)      │ (+82 more)     │ (+44 more)     │               │
└────────────────┴────────────────┴────────────────┴───────────────┘

Card spec:
  Width: column_width - 16px. Height: 90px (auto-expand for long titles).
  Line 1: Task ID (muted) + Priority badge (top-right, colored).
  Line 2-3: Title (14px bold, max 2 lines, ellipsis overflow).
  Line 4: Layer dot + layer name + " · " + age.
  P0 cards: 2px red border + box-shadow: 0 0 8px rgba(255,71,87,0.3).
  P1 cards: 1px amber border. P2: 1px blue. P3: 1px gray.
  Background: #141922. Hover: border brightens + subtle shadow.
  Click: opens C9 detail panel.
  ▄▄▄ under P0 card = glow effect indicator.
```

---

## C7: ANALYTICS DASHBOARD

### State Diagram

```
┌──────────────────────────────────────────┐
│          C7 ANALYTICS STATES              │
│                                           │
│        ┌──────────┐                       │
│   ┌───>│ LOADING  │                      │
│   │    └────┬─────┘                      │
│   │         │ DataComputed                │
│   │    ┌────v──────────┐                  │
│   │    │  POPULATED    │──── Error ──┐   │
│   │    │  (5 charts)   │             │   │
│   │    └────┬──────────┘        ┌────v─┐ │
│   │         │ 5s timer          │ERROR │ │
│   │    ┌────v──────────┐        └──────┘ │
│   │    │  REFRESHING   │                  │
│   │    └────┬──────────┘                  │
│   │         │ DataComputed                │
│   └─────────┘                             │
└──────────────────────────────────────────┘
```

### State: POPULATED — 5 Charts with Dummy Data

**Chart 1: Health Trajectory (7-day sparkline)**
```
100│
 95│                                    ╱────
 90│                               ╱───╱
 85│                          ╱───╱
 80│                     ╱───╱
 75│                ╱───╱
 70│           ╱───╱
   └────┬────┬────┬────┬────┬────┬────┬──
    Apr6 Apr7 Apr8 Apr9  10   11   12

   Score: 72 ──────> 92  (+27.8%)
   Area: green fill, 20% opacity under curve
   Line: 2px green, rounded joins
```

**Chart 2: Priority Distribution**
```
   P0  ███                           3   (3.4%)  [red]
   P1  █████████████████            28  (31.8%)  [amber]
   P2  ██████████████████████████   45  (51.1%)  [green]
   P3  ████████                     12  (13.6%)  [gray]
       0    10    20    30    40    50
```

**Chart 3: Age Histogram**
```
   <1d  ██████████████████████████████   47  (26.4%)  [green]
  1-3d  ████████████████████████████████████████   85  (47.8%)  [blue]
  3-7d  ████████████████████           34  (19.1%)  [amber]
   >7d  ████████                       12   (6.7%)  [red]
```

**Chart 4: Fractal Distribution (L0-L7)**
```
   L0  █████               5   [#ff6b6b]
   L1  ██                  2   [#ffd93d]
   L2  ██████████         10   [#6bcb77]
   L3  █████████████████████████  25   [#4d96ff]  <-- most tasks
   L4  ██████████████     12   [#9b59b6]  <-- worst health (78%)
   L5  ████████████████   15   [#00d4aa]
   L6  ████████            8   [#e74c3c]
   L7  ████                3   [#f39c12]

   Click any bar -> filters main grid to that layer
```

**Chart 5: Status Flow (Sankey)**
```
   Pending (85) ────────┬──────────── Active (47) ────────┬──── Completed (234)
                        │                                 │
   Blocked (12) ────────┘                                 │
                                                          │
                        Velocity: 4.2 tasks/day ──────────┘
```

---

## C8: AI SEARCH

### State Diagram

```
┌──────────────────────────────────────────────┐
│              C8 AI SEARCH STATES              │
│                                               │
│  ┌────────┐  Ctrl+K   ┌────────┐             │
│  │ HIDDEN │──────────>│ ACTIVE │             │
│  └────────┘           └───┬────┘             │
│       ^                   │ Type(char)       │
│       │              ┌────v────┐             │
│       │ Esc          │ TYPING  │<──┐         │
│       │              └────┬────┘   │         │
│       │                   │ 200ms  │ Type    │
│       │              ┌────v─────┐  │         │
│       ├──────────────│SEARCHING │──┘         │
│       │              └──┬───┬───┘            │
│       │                 │   │                │
│       │       results>0 │   │ results=0      │
│       │                 │   │                │
│       │           ┌─────v─┐ ┌────v──────┐    │
│       ├───────────│RESULTS│ │NO_RESULTS │    │
│       │  Esc/Click└───────┘ └───────────┘    │
│       │                                      │
│       └──────────────────────────────────────┘
└──────────────────────────────────────────────┘
```

### State: RESULTS — Dummy Data (query="zenoh")
```
┌──────────────────────────────────────────────────┐
│ 🔍  zenoh                                  [Esc] │
├──────────────────────────────────────────────────┤
│ TASKS (3)                                        │
│ ┌──────────────────────────────────────────────┐ │
│ │ T002  Zenoh multi-region federation  ACT  P1 │ │
│ │ T009  Zenoh quorum split-brain       BLK  P0 │ │
│ │ T078  Mesh topology visualization    PND  P1 │ │
│ └──────────────────────────────────────────────┘ │
│                                                  │
│ KNOWLEDGE (3 holons)                             │
│ ┌──────────────────────────────────────────────┐ │
│ │ "Zenoh session lifecycle" (L6, molecular)    │ │
│ │ "Split-brain detection protocol" (L0, atomic)│ │
│ │ "Journal: 20260405 mesh partition" (organism) │ │
│ └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘

Search sources: NIF plan_search(q) for tasks (<1ms), FTS5 for knowledge (<4ms).
Grid behind modal filters in real-time to matching tasks.
Click task -> opens C9. Click holon -> opens content inline.
```

---

## C9: DETAIL PANEL

### State Diagram

```
┌──────────────────────────────────────────────────┐
│              C9 DETAIL PANEL STATES               │
│                                                   │
│  ┌────────┐  ClickTask  ┌─────────┐              │
│  │ CLOSED │────────────>│ OPENING │              │
│  └────────┘             │  200ms  │              │
│       ^                 └────┬────┘              │
│       │                      │                   │
│       │                 ┌────v────┐              │
│       │ Close/Esc       │  OPEN   │              │
│       ├─────────────────│ (task)  │              │
│       │                 └──┬──┬───┘              │
│       │                    │  │                   │
│       │        AIAnalysis  │  │ Related           │
│       │                    │  │                   │
│       │              ┌─────v──┐ ┌────────────┐   │
│       │              │LOADING │ │  RELATED   │   │
│       │              │  AI    │ │  SHOWN     │   │
│       │              └───┬────┘ └────────────┘   │
│       │                  │                        │
│       │            GemmaResponse                  │
│       │                  │                        │
│       │              ┌───v──────┐                 │
│       └──────────────│   AI     │                │
│                      │ COMPLETE │                │
│                      └──────────┘                │
└──────────────────────────────────────────────────┘
```

### State: OPEN — Dummy Data (T001)
```
Desktop (400px slide-in from right):
┌──────────────────────────────────────┐
│ [←]  Task Detail              [✕]   │ 44px
├──────────────────────────────────────┤
│                                      │
│ T001 — Guardian NIF crash isolation  │ 18px bold
│ ──────────────────────────────────── │
│ [BLOCKED] [P0] [L0 Constitutional]  │ badges
│ Created: 2026-04-09   Age: 3 days   │
│ Owner: AN                           │
│ ──────────────────────────────────── │
│                                      │
│ Description:                         │
│ The c3i_nif.so crashes when Guardian │
│ attempts to verify Psi-0 invariant   │
│ on cold boot. Segfault in            │
│ zenoh_session_open() when router is  │
│ unreachable.                         │
│ ──────────────────────────────────── │
│                                      │
│ STAMP References:                    │
│ • SC-NIF-003 (panic=unwind)         │
│ • SC-GUARD-002 (fail closed)        │
│ • SC-PRIME-001 (constitutional)     │
│ ──────────────────────────────────── │
│                                      │
│ ┌──────────┐  ┌──────────┐          │
│ │Knowledge │  │ Related  │          │ 44px
│ └──────────┘  └──────────┘          │
│ ┌──────────┐  ┌──────────┐          │
│ │  STAMP   │  │Sub-Tasks │          │ 44px
│ └──────────┘  └──────────┘          │
│ ┌────────────────────────┐          │
│ │     AI Analysis        │          │ 44px
│ └────────────────────────┘          │
└──────────────────────────────────────┘

Mobile: full-screen slide-up (transform: translateY(100%) -> 0).
Desktop: 400px slide-in from right (transform: translateX(400px) -> 0).
Animation: 200ms ease-out.
```

### State: AI COMPLETE — Dummy Data
```
┌──────────────────────────────────────┐
│ AI Analysis — T001      [Gemma 3]   │
├──────────────────────────────────────┤
│                                      │
│ Root Cause:                          │
│ The Zenoh session_open() call in     │
│ c3i_nif.so does not handle the case  │
│ where the router endpoint is         │
│ unreachable at boot time. The NIF    │
│ returns a panic instead of an        │
│ Erlang error tuple, violating        │
│ SC-NIF-003.                          │
│                                      │
│ Recommended Fix:                     │
│ 1. Wrap zenoh::open() in             │
│    catch_unwind()                    │
│ 2. Return {:error, :unreachable}     │
│ 3. Add 3-retry with exp. backoff    │
│                                      │
│ Confidence: 0.87                     │
│ Latency: 3.1s | gemma3:4b           │
└──────────────────────────────────────┘
```

---

## C10: GEMMA AI CHAT

### State Diagram

```
┌──────────────────────────────────────────────┐
│             C10 GEMMA CHAT STATES             │
│                                               │
│  ┌────────┐         ┌───────────┐            │
│  │ HIDDEN │────────>│ MINIMIZED │            │
│  └────────┘         └─────┬─────┘            │
│       ^                   │ Click            │
│       │              ┌────v────┐             │
│       │ Close        │  OPEN   │<──────┐     │
│       ├──────────────│(welcome)│       │     │
│       │              └────┬────┘       │     │
│       │                   │ UserType   │     │
│       │              ┌────v────┐       │     │
│       │              │ TYPING  │       │     │
│       │              └────┬────┘       │     │
│       │                   │ Send       │     │
│       │              ┌────v────┐       │     │
│       │              │ WAITING │  Complete   │
│       │              │(shimmer)│───────┘     │
│       │              └────┬────┘             │
│       │                   │ Timeout          │
│       │              ┌────v────┐             │
│       └──────────────│  ERROR  │             │
│                      └─────────┘             │
└──────────────────────────────────────────────┘
```

### State: OPEN with conversation — Dummy Data
```
┌──────────────────────────────────────┐
│ Gemma AI Assistant         [−] [✕]  │
├──────────────────────────────────────┤
│                                      │
│ System context loaded:               │
│ 178 tasks, 47 active, 12 blocked    │
│ Health: 92, trend: +0.3/h           │
│                                      │
│          What should I prioritize ┐  │
│          this week?               │  │
│                                [You] │
│                                      │
│ [Gemma 3, 3.2s]                     │
│ Based on current state:             │
│                                      │
│ 1. L4 System (78% health)          │
│    Unblock T005 Build pipeline.     │
│    Blocks 3 downstream tasks.       │
│                                      │
│ 2. L0 Constitutional               │
│    T001 Guardian NIF is safety-     │
│    critical (SC-NIF-003).           │
│                                      │
│ 3. L6 Ecosystem                     │
│    T009 Zenoh quorum affects mesh   │
│    connectivity (SC-ZENOH-001).     │
│                                      │
├──────────────────────────────────────┤
│ │ Type a message...        [Send] │  │
└──────────────────────────────────────┘

Position: bottom-right 400x500px floating panel (desktop).
Full-screen overlay on mobile.
System prompt enriched with live data every message.
Cascade: Gemma 3 (port 11434, 15s) -> Gemma 4 (port 11435, 15s) -> NIF fallback.
```

---

## C11: CHANGE LOG

### State Diagram

```
┌──────────────────────────────────────────────┐
│             C11 CHANGE LOG STATES             │
│                                               │
│           ┌─────────┐                         │
│           │  EMPTY  │                        │
│           └────┬────┘                        │
│                │ NewEntry                     │
│         ┌──────┴──────┐                      │
│   Desktop│            │Mobile                │
│         v            v                       │
│   ┌──────────┐  ┌──────────┐                 │
│   │ TICKER   │  │  TOAST   │                 │
│   │ (20px    │  │ (3s auto │                 │
│   │  bottom  │  │  dismiss)│                 │
│   │  bar)    │  └──────────┘                 │
│   └────┬─────┘                               │
│        │ Click                               │
│   ┌────v─────┐                               │
│   │ EXPANDED │                               │
│   │ (300px   │                               │
│   │  panel)  │                               │
│   └────┬─────┘                               │
│        │ Click Collapse                      │
│        └──> TICKER                           │
└──────────────────────────────────────────────┘
```

### State: EXPANDED — Dummy Data (10 entries)
```
┌════════════════════════════════════════════════════════════════════┐
│ CHANGE LOG (50 entries)                          [Collapse ▲]    │
├────────────────────────────────────────────────────────────────────┤
│ [09:15] T003  active -> completed     (AN)         status_change │
│ [09:01] T002  pending -> active       (claude-1)   status_change │
│ [08:45] T067  pending -> active       (gemini-2)   status_change │
│ [08:30] T099  active -> completed     (claude-1)   status_change │
│ [08:15] T089  priority: P2 -> P1      (AN)       priority_change │
│ [08:00] T101  created: "New CRDT test" P2          (AN) new_task │
│ [07:45] T045  pending -> active       (claude-1)   status_change │
│ [07:30] T032  owner: -- -> AN         (AN)            data_diff │
│ [07:15] T078  description updated     (gemini-2)      data_diff │
│ [07:00] System restart: 3 tasks re-queued         system_event   │
└════════════════════════════════════════════════════════════════════┘

Color coding: status_change=#00d4aa, priority_change=#f5a623,
             new_task=#3dd68c, data_diff=#7a8fa6, system_event=#4d96ff
```

---

## C12: FRACTAL FILTER

### State Diagram

```
┌──────────────────────────────────────────────────┐
│              C12 FRACTAL FILTER STATES             │
│                                                    │
│   ┌────────────┐  ClickLayer(L)  ┌──────────────┐ │
│   │  ALL_SHOWN │────────────────>│LAYER_SELECTED│ │
│   │            │<────────────────│   (layer=L)  │ │
│   └────────────┘  ClickLayer(L)  └──────┬───────┘ │
│                    (same=toggle)         │         │
│                                  ClickLayer(L2)   │
│                                          │         │
│                                  ┌───────v───────┐ │
│                                  │LAYER_SELECTED │ │
│                                  │  (layer=L2)   │ │
│                                  └───────────────┘ │
│                                                    │
│   Synced: sidebar click <-> chip click <-> URL    │
└──────────────────────────────────────────────────┘
```

### State: ALL_SHOWN — Dummy Data (sidebar)
```
┌────────────────────┐
│ FRACTAL HEALTH     │
├────────────────────┤
│ ● L0 CONST    95%  │
│ ████████████████░░ │
│ 3 blk  2 act       │
├────────────────────┤
│ ● L1 ATOM     88%  │
│ ██████████████░░░░ │
│ 1 blk  1 act       │
├────────────────────┤
│ ● L2 COMP     92%  │
│ ████████████████░░ │
│ 0 blk  5 act       │
├────────────────────┤
│ ● L3 TRANS    85%  │
│ ██████████████░░░░ │
│ 4 blk  8 act       │
├────────────────────┤
│ ● L4 SYST     78%  │  ← RED (lowest)
│ █████████████░░░░░ │
│ 2 blk  3 act  [!]  │
├────────────────────┤
│ ● L5 COG      91%  │
│ ████████████████░░ │
│ 1 blk  4 act       │
├────────────────────┤
│ ● L6 ECO      82%  │
│ ██████████████░░░░ │
│ 2 blk  2 act       │
├────────────────────┤
│ ● L7 FED      94%  │
│ ████████████████░░ │
│ 0 blk  1 act       │
└────────────────────┘

Health formula: health(L) = 1 - Σ(blocked * severity_weight) / Σ(total * max_weight)
  where severity_weight = {P0:3, P1:2, P2:1, P3:0.5}
Bar colors: <80% red, <90% amber, >=90% green
Click layer -> filters main grid. Active layer gets 4px accent left border.
Width: 180px (wide desktop only, @media min-width: 1400px).
```

### Chips bar (controls row):
```
ALL_SHOWN:     [All*] [L0] [L1] [L2] [L3] [L4] [L5] [L6] [L7]
                ^^^^
                filled accent bg, dark text

L4 SELECTED:   [All]  [L0] [L1] [L2] [L3] [L4*] [L5] [L6] [L7]
                                              ^^^^^
                                        filled purple (#9b59b6), dark text

* = active chip. Inactive: border in layer color, text in layer color.
Click same chip again to deselect (toggle).
```

---

# PART 3: USER JOURNEYS

## J1: On-Call Triage (Mobile, 30-90 seconds)

```
PERSONA: Abhijit, iPhone 15 Pro, 2:47 AM
TRIGGER: Telegram notification "P0 BLOCKED: Guardian NIF"

Step 1 (0-1.5s): Open /planning on mobile
  → Viewport <768px → Concept D triage layout
  → C1:Loading → WsConnect → C1:Healthy(92)
  → C4.zones:Normal (3 critical, 9 attention, 166 nominal)

Step 2 (1.5-3s): Scan Critical Zone
  → Eyes: Zone 1 red border, 3 P0 cards visible
  → No scroll needed (S_b = 0px)
  → Cognitive load: 3 groups only (Critical/Attention/Nominal)

Step 3 (3-5s): Tap [Detail] on T001
  → C9:Closed → C9:Opening(200ms) → C9:Open(T001)
  → Full-screen slide-up shows title, badges, description, STAMP refs

Step 4 (5-10s): Tap [AI Analysis]
  → C9:Open → C9:LoadingAI (shimmer bars, "Gemma 3 analyzing...")
  → Wait 3.1s → C9:AIComplete
  → Shows: root cause, recommended fix, confidence 0.87

Step 5 (10-15s): Swipe back, tap [Activate] on T001
  → POST /api/v1/tasks/T001/status {"status":"active"}
  → Card animates out of Critical zone (300ms fade+slide)
  → Zone count: (3) → (2)
  → C11:Toast "T001 blocked -> active" (3s auto-dismiss)

Step 6 (15-30s): Verify count, lock phone
  → Total time: 15-30 seconds
  → Components used: C1(glance), C4.zones(primary), C9(detail), C10(inline AI), C11(toast)
```

## J2: Morning Standup (Desktop, 2-5 minutes)

```
PERSONA: Abhijit, MacBook Air 1440px, 9:00 AM

Step 1 (0-2s): Page loads Concept F hybrid
  → C1:Healthy(92) + C12:AllShown(sidebar) + C4:Populated(15 rows) + C11:Ticker

Step 2 (2-5s): Glance fractal sidebar
  → L4 SYST 78% RED → "L4 needs attention today"
  → 0 clicks to identify worst layer

Step 3 (5-10s): Click L4 in sidebar
  → C12:AllShown → C12:LayerSelected(L4)
  → C4:Populated → C4:Filtered(L4, 5 tasks)
  → Grid shows 2 blocked + 3 active in L4

Step 4 (10-30s): Press "2" → switch to Kanban
  → View:Grid → View:Kanban
  → C5:Normal, 4 columns visible
  → See blocked column: P0 red glow cards at top

Step 5 (30s-1min): Glance change log ticker
  → C11:Ticker shows "[08:45] T067 active (gemini-2), [08:30] T099 completed (claude-1)"
  → Insight: AI agents productive overnight

Step 6 (1-2min): Ctrl+K → search "zenoh"
  → C8:Hidden → C8:Active → C8:Typing → C8:Results
  → 3 tasks + 3 knowledge holons matching "zenoh"
  → Click T009 → C9:Open(T009)

Components used: C1, C4, C5, C8, C9, C11, C12
```

## J3: Sprint Planning (Desktop, 15-30 minutes)

```
Step 1: Press "4" → Analytics view
  → C7:Populated (5 charts)
  → Health trajectory: 72 → 92 (+27.8% this week)
  → Priority dist: P0=3, P1=28, P2=45, P3=12
  → Age histogram: 12 stale (>7d) → click red bar to filter

Step 2: Click >7d bar in age histogram
  → C4:Filtered(age>7d, 12 tasks)
  → Identify: 3 of 12 are in L4 (build issues)

Step 3: Open Gemma chat → ask prioritization
  → C10:Hidden → C10:Open → C10:Typing → C10:Waiting → C10:Response
  → Gemma: "Fix L4 first (T005), then L0 (T001), then L6 (T009)"

Components used: C7(primary), C4, C8, C10, C12
```

## J4: Incident Investigation (Desktop, 5-15 minutes)

```
Step 1: Ctrl+K "zenoh" → 3 tasks + 14 holons
Step 2: Filter L6 → 8 tasks (2 blocked, 2 active)
Step 3: Open T009 detail → STAMP: SC-SIL4-015, SC-ZENOH-001
Step 4: Click [Related] → T002 depends on T009
Step 5: Click [Knowledge] → prior journal entry about same issue
Step 6: Press "3" → Timeline view → see T009 created 1d ago
Step 7: AI Analysis → "Check zenoh-router-2 memory pressure"

Components used: C8, C12, C4, C9(detail+5 actions), C6(timeline), C10
```

## J5-J10: (See planning-page-user-journeys.md for full details)

---

# PART 4: FULL PAGE COMPOSITE RENDERS

## Composite 1: Nominal Desktop (1440px)

```
┌════════════════════════════════════════════════════════════════════════════════┐
│ C3I ●Live  Act:47 Blk:12 P0:3  Health:92 ████████░░ ▲+0.3/h  OODA:28ms    │
├════════════════════════════════════════════════════════════════════════════════┤
│ [Grid*] [Kanban] [Timeline] [Analytics] [Fractal]  | Ctrl+K _____ | [All*] │
├────────────┬══════════════════════════════════════════════════════════════════┤
│ FRACTAL    │ ID   │ Title                        │ Status │ P  │ Age │ L   │
│ HEALTH     │══════╪══════════════════════════════╪════════╪════╪═════╪═════│
│            │▌T001 │ Guardian NIF crash isolation  │ BLOCK  │ P0 │ 3d  │ ●L0 │
│ ●L0 95%   │▌T005 │ Build pipeline podman fix     │ BLOCK  │ P0 │ 5d  │ ●L4 │
│ ████████░░ │▌T009 │ Zenoh quorum split-brain      │ BLOCK  │ P0 │ 1d  │ ●L6 │
│ 3blk 2act  │▌T012 │ Auth timeout middleware       │ BLOCK  │ P1 │ 2d  │ ●L3 │
│            │▌T002 │ Zenoh multi-region federation │ ACTIVE │ P1 │ 12h │ ●L6 │
│ ●L1 88%   │▌T003 │ Hot reload beam code server   │ ACTIVE │ P1 │ 1d  │ ●L4 │
│ ████████░░ │▌T015 │ SQLite WAL checkpoint tune    │ ACTIVE │ P2 │ 4h  │ ●L3 │
│ 1blk 1act  │▌T045 │ OTel trace span correlation   │ ACTIVE │ P1 │ 6h  │ ●L1 │
│            │▌T067 │ A2UI wave2 catalog complete    │ ACTIVE │ P2 │ 8h  │ ●L2 │
│ ●L2 92%   │ T023 │ MCP tool dispatch wiring      │ PEND   │ P1 │ 3d  │ ●L5 │
│ ████████░░ │ T034 │ Badge component CSS polish    │ PEND   │ P2 │ 1d  │ ●L2 │
│ 0blk 5act  │ T078 │ Mesh topology visualization   │ PEND   │ P1 │ 5d  │ ●L6 │
│            │ T090 │ Gateway version vector sync   │ PEND   │ P2 │ 3d  │ ●L7 │
│ ●L3 85%   │      │                              │        │    │     │     │
│ ██████░░░░ │      │                              │        │    │     │     │
│ 4blk 8act  │      │                              │        │    │     │     │
│            │      │                              │        │    │     │     │
│ ●L4 78% ! │      │                              │        │    │     │     │
│ █████░░░░░ │      │                              │        │    │     │     │
│ 2blk 3act  │      │                              │        │    │     │     │
│            │      │                              │        │    │     │     │
│ ●L5 91%   │      │                              │        │    │     │     │
│ ████████░░ │      │                              │        │    │     │     │
│ 1blk 4act  │      │                              │        │    │     │     │
│            │      │                              │        │    │     │     │
│ ●L6 82%   │      │                              │        │    │     │     │
│ ██████░░░░ │      │                              │        │    │     │     │
│ 2blk 2act  │      │                              │        │    │     │     │
│            │      │                              │        │    │     │     │
│ ●L7 94%   │      │                              │        │    │     │     │
│ ████████░░ │      │                              │        │    │     │     │
│ 0blk 1act  │      │                              │        │    │     │     │
├────────────┴══════════════════════════════════════════════════════════════════┤
│ d(H)/dt:+0.3/h IMPROVING │ SLO:99.2% budget:0.8% │ ●WS Connected 1s ago   │
└════════════════════════════════════════════════════════════════════════════════┘

Active components: C1:Healthy, C4:Populated, C11:Ticker, C12:AllShown(sidebar)
```

## Composite 2: Dark Cockpit (health=98, 0 blocked)

```
┌════════════════════════════════════════════════════════════════════════════════┐
│ C3I ●Live  Act:47 Blk:0 P0:0  Health:98 ██████████ ▲+0.1/h  OODA:12ms     │
├════════════════════════════════════════════════════════════════════════════════┤
│ [Grid*] [Kanban] [Timeline] [Analytics] [Fractal]  | Ctrl+K _____ | [All*] │
├────────────┬══════════════════════════════════════════════════════════════════┤
│ FRACTAL    │                                                                 │
│ HEALTH     │                                                                 │
│            │                    ╭──────────╮                                 │
│ ●L0 98%   │                   ╱   ╭────╮   ╲                                │
│ ██████████ │                  │   │ 178  │   │                               │
│            │                   ╲   ╰────╯   ╱                                │
│ ●L1 97%   │                    ╰──────────╯                                 │
│ ██████████ │                                                                 │
│            │                ALL SYSTEMS NOMINAL                              │
│ ●L2 99%   │                0 blocked · 178 tasks                            │
│ ██████████ │                Health: stable (+0.1/h)                          │
│            │                                                                 │
│ ●L3 96%   │                Dark Cockpit Mode Active                         │
│ ██████████ │                                                                 │
│            │                [Show all tasks]                                  │
│ ●L4 95%   │                                                                 │
│ ██████████ │                                                                 │
│            │                                                                 │
│ ●L5 98%   │                                                                 │
│ ██████████ │                                                                 │
│            │                                                                 │
│ ●L6 97%   │                                                                 │
│ ██████████ │                                                                 │
│            │                                                                 │
│ ●L7 99%   │                                                                 │
│ ██████████ │                                                                 │
├────────────┴══════════════════════════════════════════════════════════════════┤
│ d(H)/dt:+0.1/h STABLE │ SLO:99.9% budget:0.1% │ ●Connected 1s ago         │
└════════════════════════════════════════════════════════════════════════════════┘

Dark Cockpit: blocked=0, health>95 → suppress task grid, show centered status.
This IS homeostasis (SC-BIO-EVO-001). The void is the goal (Musashi: Ku).
```
