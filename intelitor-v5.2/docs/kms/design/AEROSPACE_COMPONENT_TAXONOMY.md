# Aerospace/Space Mission Control Component Taxonomy
**Version**: 1.0.0 | **Date**: 2025-12-30 | **Classification**: Design System Specification
**Depth**: 5-Level Hierarchical Decomposition

---

## TAXONOMY STRUCTURE

```
L1 DOMAIN          → High-level functional category
L2 COMPONENT       → Component type within domain
L3 VARIANT         → Specific implementation style
L4 STATE           → Behavioral states
L5 MICRO           → Animations, transitions, micro-interactions
```

---

# L1: NAVIGATION DOMAIN

## L2: Mission Selector (Primary Navigation)

### L3: Tab Bar (Horizontal)
```
IDLE STATE:
┌─────────────────────────────────────────────────────────────────────────────┐
│  [F1] FLIGHT    [F2] ORBIT     [F3] SIM       [F4] BLACK    [F5] TOIL      │
│       PLANS          DYNAMICS       CHAMBER        BOX           METRICS    │
└─────────────────────────────────────────────────────────────────────────────┘

SELECTED STATE (F1 active):
┌─────────────────────────────────────────────────────────────────────────────┐
│  [F1] FLIGHT ◀  [F2] ORBIT     [F3] SIM       [F4] BLACK    [F5] TOIL      │
│  ════════════        DYNAMICS       CHAMBER        BOX           METRICS    │
│  ▀▀▀▀▀▀▀▀▀▀▀▀                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

HOVER STATE (F2 hovered):
┌─────────────────────────────────────────────────────────────────────────────┐
│  [F1] FLIGHT    [F2] ORBIT ░░  [F3] SIM       [F4] BLACK    [F5] TOIL      │
│       PLANS     ░░░ DYNAMICS        CHAMBER        BOX           METRICS    │
└─────────────────────────────────────────────────────────────────────────────┘

ALERT STATE (F4 has incident):
┌─────────────────────────────────────────────────────────────────────────────┐
│  [F1] FLIGHT    [F2] ORBIT     [F3] SIM       [F4] BLACK ●  [F5] TOIL      │
│       PLANS          DYNAMICS       CHAMBER        BOX  (3)      METRICS    │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### L4: Tab States
| State | Visual | Behavior |
|-------|--------|----------|
| IDLE | Dim text | No action |
| HOVER | Glow/highlight | Preview tooltip |
| SELECTED | Underline + bright | Active view |
| DISABLED | Grayed out | No interaction |
| ALERT | Pulsing badge | Requires attention |

#### L5: Micro-Interactions
```
SELECTION ANIMATION (150ms ease-out):
T+0ms:   [F1] FLIGHT     ← Click detected
T+50ms:  [F1] FLIGHT ░   ← Highlight flash
T+100ms: [F1] FLIGHT ▄   ← Underline grows
T+150ms: [F1] FLIGHT ▀   ← Full underline

BADGE PULSE (1000ms loop):
T+0ms:    ●   ← Full opacity
T+500ms:  ○   ← 50% opacity
T+1000ms: ●   ← Full opacity (repeat)
```

### L3: Sidebar (Vertical)
```
COLLAPSED STATE:
┌───┐
│ ◈ │ ← Flight Plans
│ ◇ │ ← Orbit Dynamics
│ ◆ │ ← Sim Chamber
│ ■ │ ← Black Box
│ ▣ │ ← Toil Metrics
└───┘

EXPANDED STATE:
┌─────────────────────┐
│ ◈ Flight Plans      │
│ ◇ Orbit Dynamics    │
│ ◆ Sim Chamber       │
│ ■ Black Box         │
│ ▣ Toil Metrics      │
└─────────────────────┘

EXPANDED + SELECTED:
┌─────────────────────┐
│▐◈ Flight Plans     ▐│ ← Selected (highlight bar)
│ ◇ Orbit Dynamics    │
│ ◆ Sim Chamber       │
│ ■ Black Box         │
│ ▣ Toil Metrics      │
└─────────────────────┘
```

### L3: Breadcrumb Trail
```
DEPTH 1:
◈ MISSION CONTROL

DEPTH 2:
◈ MISSION CONTROL › ◇ FLIGHT PLANS

DEPTH 3:
◈ MISSION CONTROL › ◇ FLIGHT PLANS › ▷ DB_FAILOVER

DEPTH 4 (truncated):
◈ ... › ◇ FLIGHT PLANS › ▷ DB_FAILOVER › ◉ STEP 2

HOVER ON SEGMENT:
◈ MISSION CONTROL › ◇ FLIGHT PLANS › ▷ DB_FAILOVER
                     ▲
                     └─ [Click to navigate]
```

---

## L2: Quick Launch (Function Keys)

### L3: Quick Launch Bar
```
IDLE STATE:
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ F1 ◆   │ │ F2 ◆   │ │ F3 ◆   │ │ F4 ◆   │ │ F5 ◆   │ │ F6 ◆   │
│ DB     │ │ REDIS  │ │ K8S    │ │ NET    │ │ DISK   │ │ MEM    │
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘

ACTIVE STATE (F1 pressed):
┌════════┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
║ F1 ◆◀  ║ │ F2 ◆   │ │ F3 ◆   │ │ F4 ◆   │ │ F5 ◆   │ │ F6 ◆   │
║ DB     ║ │ REDIS  │ │ K8S    │ │ NET    │ │ DISK   │ │ MEM    │
└════════┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘

EXECUTING STATE:
┌════════┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
║ F1 ◎   ║ │ F2 ◆   │ │ F3 ◆   │ │ F4 ◆   │ │ F5 ◆   │ │ F6 ◆   │
║ DB ▰▱▱ ║ │ REDIS  │ │ K8S    │ │ NET    │ │ DISK   │ │ MEM    │
└════════┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

#### L4: Quick Launch States
| State | Icon | Border | Content |
|-------|------|--------|---------|
| IDLE | ◆ | thin | Label only |
| HOVER | ◆ glow | medium | Label + tooltip |
| PRESSED | ◆◀ | thick | Inverted colors |
| EXECUTING | ◎ spin | thick | Mini progress |
| SUCCESS | ✓ | green | Flash green |
| FAILURE | ✗ | red | Flash red |

---

# L1: STATUS DOMAIN

## L2: System Status Indicator

### L3: Traffic Light Indicator
```
ALL NOMINAL:
┌───────────────────────────────────────┐
│ ● PWR   ● NET   ● DB    ● AUTH       │
│ NOM     NOM     NOM     NOM          │
└───────────────────────────────────────┘

ONE WARNING:
┌───────────────────────────────────────┐
│ ● PWR   ● NET   ◐ DB    ● AUTH       │
│ NOM     NOM     WARN    NOM          │
└───────────────────────────────────────┘

ONE CRITICAL:
┌───────────────────────────────────────┐
│ ● PWR   ● NET   ○ DB    ● AUTH       │
│ NOM     NOM     CRIT    NOM          │
└───────────────────────────────────────┘

MULTIPLE ISSUES:
┌───────────────────────────────────────┐
│ ● PWR   ◐ NET   ○ DB    ◐ AUTH       │
│ NOM     WARN    CRIT    WARN         │
└───────────────────────────────────────┘
```

#### L4: Status States
| State | Symbol | Color | Animation |
|-------|--------|-------|-----------|
| NOMINAL | ● | Green | None |
| WARNING | ◐ | Amber | Slow pulse |
| CRITICAL | ○ | Red | Fast pulse |
| UNKNOWN | ◌ | Gray | None |
| OFFLINE | ⊗ | Dark gray | None |

#### L5: Status Pulse Animation
```
NOMINAL (no animation):
T+0ms:    ●   ← Solid

WARNING (2000ms cycle):
T+0ms:    ◐   ← Full
T+1000ms: ◑   ← Dim
T+2000ms: ◐   ← Full (repeat)

CRITICAL (500ms cycle):
T+0ms:    ○   ← Full
T+250ms: (○)  ← Bright flash
T+500ms:  ○   ← Full (repeat)
```

### L3: Gauge Indicator
```
NOMINAL (85%):
┌─────────────────┐
│ CPU             │
│ ▰▰▰▰▰▰▰▰▱▱  85% │
│ NOMINAL         │
└─────────────────┘

WARNING (72%):
┌─────────────────┐
│ CPU             │
│ ▰▰▰▰▰▰▰▱▱▱  72% │
│ WARNING         │
└─────────────────┘

CRITICAL (95%):
┌─────────────────┐
│ CPU             │
│ ▰▰▰▰▰▰▰▰▰▰  95% │
│ CRITICAL        │
└─────────────────┘

OVERLOAD (100%+):
┌─────────────────┐
│ CPU             │
│ ████████████ !  │
│ OVERLOAD        │
└─────────────────┘
```

### L3: Sparkline Trend
```
STABLE TREND:
▁▂▂▃▂▂▃▂▂▃  ← Low variance

RISING TREND:
▁▂▃▄▅▆▇█▇▆  ← Increasing

FALLING TREND:
█▇▆▅▄▃▂▁▁▁  ← Decreasing

VOLATILE TREND:
▁█▂▇▃▆▁▇▂█  ← High variance

SPIKE DETECTED:
▁▁▁█▁▁▁▁▁▁  ← Anomaly
    ▲
    └─ Alert trigger
```

---

## L2: Mission Status Banner

### L3: Phase Indicator
```
PRE-FLIGHT:
┌─────────────────────────────────────────────────────────────┐
│ ◇ PRE-FLIGHT │ ○ IN FLIGHT │ ○ DEBRIEF │ ○ ARCHIVED       │
│ ═════════════                                               │
└─────────────────────────────────────────────────────────────┘

IN FLIGHT:
┌─────────────────────────────────────────────────────────────┐
│ ✓ PRE-FLIGHT │ ◈ IN FLIGHT │ ○ DEBRIEF │ ○ ARCHIVED       │
│ ══════════════════════════════                              │
└─────────────────────────────────────────────────────────────┘

COMPLETE:
┌─────────────────────────────────────────────────────────────┐
│ ✓ PRE-FLIGHT │ ✓ IN FLIGHT │ ✓ DEBRIEF │ ◈ ARCHIVED       │
│ ════════════════════════════════════════════════════════    │
└─────────────────────────────────────────────────────────────┘
```

### L3: Mission Timer
```
T-MINUS (countdown):
┌───────────────────┐
│ T-MINUS           │
│   15:00           │
│   ▼ COUNTING      │
└───────────────────┘

T-PLUS (elapsed):
┌───────────────────┐
│ T+ ELAPSED        │
│   04:23           │
│   ▲ RUNNING       │
└───────────────────┘

HOLDING:
┌───────────────────┐
│ T-MINUS           │
│   02:30           │
│   ║ HOLD          │
└───────────────────┘

PAUSED:
┌───────────────────┐
│ T+ ELAPSED        │
│   04:23           │
│   ▌▌ PAUSED       │
└───────────────────┘
```

#### L5: Timer Animations
```
NORMAL TICK (1000ms):
T+0ms:    04:23
T+1000ms: 04:24  ← Digit changes

CRITICAL COUNTDOWN (500ms flash):
T+0ms:    00:10  ← Normal
T+250ms:  00:10  ← Highlight flash
T+500ms:  00:10  ← Normal
T+1000ms: 00:09  ← Next second

HOLD STATE (blink):
T+0ms:    02:30 HOLD
T+500ms:  02:30      ← "HOLD" hidden
T+1000ms: 02:30 HOLD ← "HOLD" visible
```

---

# L1: DATA DISPLAY DOMAIN

## L2: Table (Mission Roster)

### L3: Standard Data Table
```
IDLE STATE:
╔═══════════════════════════════════════════════════════════════════╗
║ ID      │ CALLSIGN              │ CLASS     │ AUTO │ T-AVG │ STS ║
╟─────────┼───────────────────────┼───────────┼──────┼───────┼─────╢
║ REC-01  │ DATABASE_FAILOVER     │ RECOVERY  │ SEMI │ 15:00 │ ◈   ║
║ REC-02  │ REDIS_RESTART         │ RECOVERY  │ MAN  │ 08:30 │ ◈   ║
║ SCL-05  │ POD_AUTOSCALE         │ SCALING   │ FULL │ 02:15 │ ◈   ║
╚═══════════════════════════════════════════════════════════════════╝

ROW SELECTED:
╔═══════════════════════════════════════════════════════════════════╗
║ ID      │ CALLSIGN              │ CLASS     │ AUTO │ T-AVG │ STS ║
╟─────────┼───────────────────────┼───────────┼──────┼───────┼─────╢
║▐REC-01 ▐│▐DATABASE_FAILOVER    ▐│▐RECOVERY ▐│▐SEMI▐│▐15:00▐│▐◈  ▐║
║ REC-02  │ REDIS_RESTART         │ RECOVERY  │ MAN  │ 08:30 │ ◈   ║
║ SCL-05  │ POD_AUTOSCALE         │ SCALING   │ FULL │ 02:15 │ ◈   ║
╚═══════════════════════════════════════════════════════════════════╝

ROW EXECUTING:
╔═══════════════════════════════════════════════════════════════════╗
║ ID      │ CALLSIGN              │ CLASS     │ AUTO │ T-AVG │ STS ║
╟─────────┼───────────────────────┼───────────┼──────┼───────┼─────╢
║ REC-01  │ DATABASE_FAILOVER     │ RECOVERY  │ SEMI │ 15:00 │ ◎   ║
║ REC-02  │ REDIS_RESTART         │ RECOVERY  │ MAN  │ 08:30 │ ◈   ║
╚═══════════════════════════════════════════════════════════════════╝
     ▲
     └─ Spinner animating

SORTED COLUMN (ascending):
╔═══════════════════════════════════════════════════════════════════╗
║ ID      │ CALLSIGN         ▲    │ CLASS     │ AUTO │ T-AVG │ STS ║
╚═══════════════════════════════════════════════════════════════════╝
                              ▲
                              └─ Sort indicator
```

#### L4: Row States
| State | Visual | Interaction |
|-------|--------|-------------|
| IDLE | Normal text | Clickable |
| HOVER | Subtle highlight | Preview |
| SELECTED | Inverted/highlight bar | Active |
| EXECUTING | Spinner in status | Read-only |
| SUCCESS | Flash green | Auto-dismiss |
| FAILURE | Flash red | Show error |
| DISABLED | Grayed text | No interaction |

### L3: Hierarchical Tree Table
```
COLLAPSED:
◇ RECOVERY (3)
◇ SCALING (2)
◇ DEPLOY (1)

EXPANDED:
◈ RECOVERY (3)
├─ REC-01 DATABASE_FAILOVER     SEMI  15:00  ◈
├─ REC-02 REDIS_RESTART         MAN   08:30  ◈
└─ REC-03 CACHE_INVALIDATION    FULL  02:00  ◈
◇ SCALING (2)
◇ DEPLOY (1)

NESTED EXPANSION:
◈ RECOVERY (3)
├─ REC-01 DATABASE_FAILOVER     SEMI  15:00  ◈
│  ◈ STEPS (5)
│  ├─ 1. Verify replica         SAFE        ✓
│  ├─ 2. Halt traffic           CRITICAL    ◉
│  ├─ 3. Promote replica        CRITICAL    ○
│  ├─ 4. Resume traffic         CAUTION     ○
│  └─ 5. Verify health          SAFE        ○
├─ REC-02 REDIS_RESTART         MAN   08:30  ◈
└─ REC-03 CACHE_INVALIDATION    FULL  02:00  ◈
```

---

## L2: Cards (Grid Layout)

### L3: Summary Card
```
IDLE STATE:
┌─────────────────────────┐
│ ◆ DATABASE FAILOVER     │
│ ═══════════════════════ │
│ MODE   ◐ SEMI-AUTO      │
│ RUNS   047              │
│ T-AVG  15:00            │
│ OWNER  @alice           │
│ ▰▰▰▰▰▰▰▰▱▱ 85%          │
└─────────────────────────┘

HOVER STATE:
┌═════════════════════════┐
│ ◆ DATABASE FAILOVER     │
│ ═══════════════════════ │
│ MODE   ◐ SEMI-AUTO      │
│ RUNS   047              │
│ T-AVG  15:00            │
│ OWNER  @alice           │
│ ▰▰▰▰▰▰▰▰▱▱ 85%          │
│ [ENTER] Execute         │
└═════════════════════════┘

SELECTED STATE:
╔═════════════════════════╗
║▐◆ DATABASE FAILOVER    ▐║
║ ═══════════════════════ ║
║ MODE   ◐ SEMI-AUTO      ║
║ RUNS   047              ║
║ T-AVG  15:00            ║
║ OWNER  @alice           ║
║ ▰▰▰▰▰▰▰▰▱▱ 85%          ║
╚═════════════════════════╝

EXECUTING STATE:
╔═════════════════════════╗
║ ◎ DATABASE FAILOVER     ║
║ ═══════════════════════ ║
║ ▰▰▰▰▰░░░░░░░░░░ 33%     ║
║ T+ 05:12                ║
║ STEP 2/5                ║
║ ◈ Halting traffic...    ║
╚═════════════════════════╝
```

### L3: Metric Card
```
NOMINAL:
┌─────────────────────────┐
│ ◈ API GATEWAY           │
│                         │
│    99.97%               │
│    ───────              │
│    TARGET: 99.95%       │
│                         │
│ BUDGET: +0.02%          │
│ TREND:  ▁▂▃▄▅▆▇█▇▆      │
│ STATUS: ◈ NOMINAL       │
└─────────────────────────┘

WARNING:
┌─────────────────────────┐
│ ⚠ AUTH SERVICE          │
│                         │
│    99.98%               │
│    ───────              │
│    TARGET: 99.99%       │
│                         │
│ BUDGET: -0.01%          │
│ TREND:  █▇▆▆▅▄▄▃▃▂      │
│ STATUS: ⚠ WARNING       │
└─────────────────────────┘

CRITICAL:
┌─────────────────────────┐
│ ✗ BACKGROUND JOBS       │
│                         │
│    99.20%               │
│    ───────              │
│    TARGET: 99.90%       │
│                         │
│ BUDGET: -0.70% ▲▲       │
│ TREND:  ▅▄▃▂▁▁▁▂▁▁      │
│ STATUS: ✗ BREACH        │
│ EXHAUST: T-8 DAYS       │
└─────────────────────────┘
```

---

## L2: Charts

### L3: Line Chart (Telemetry)
```
BASIC LINE:
     ^
100% │          ╭─╮
 75% │      ╭──╯  ╰──╮
 50% │   ╭─╯         ╰─╮
 25% │──╯               ╰──
  0% └─────────────────────→
     T-30m            NOW

WITH THRESHOLD:
     ^
100% │          ╭─╮
 75% │      ╭──╯  ╰──╮
 50% │───────────────────── ← THRESHOLD
 25% │──╯               ╰──
  0% └─────────────────────→

BREACH HIGHLIGHT:
     ^
100% │          ████
 75% │      ╭──█████──╮
 50% │───────────────────── ← THRESHOLD
 25% │──╯               ╰──
  0% └─────────────────────→
            ▲▲▲▲
            └─ Breach zone highlighted
```

### L3: Bar Chart
```
HORIZONTAL BARS:
API GATEWAY  ████████████████████ 99.97%
AUTH SERVICE ████████████████████ 99.98%
BG JOBS      ████████████████     99.20%  ← Below threshold
DATABASE     ████████████████████ 99.99%

VERTICAL BARS:
    ██
    ██  ██      ██
    ██  ██      ██
    ██  ██  ░░  ██
    ──────────────
    API AUTH BG  DB
            ▲
            └─ Below threshold (different color)
```

### L3: Burn-Down Chart
```
ERROR BUDGET BURN:

100% │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 75% │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░
 50% │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░  ← CURRENT: 42%
 25% │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  (projected)
  0% └─────────────────────────────────────────────────────
      T+1      T+7      T+14     T+21     T+28     T+30
                                          ▲
                                          └─ Projected exhaustion
```

---

# L1: INTERACTION DOMAIN

## L2: Command Input

### L3: Search Field
```
IDLE:
┌─────────────────────────────────────────────────────────┐
│ ◈ Search runbooks...                                    │
└─────────────────────────────────────────────────────────┘

FOCUSED:
╔═════════════════════════════════════════════════════════╗
║ ◈ █                                                     ║
╚═════════════════════════════════════════════════════════╝

TYPING:
╔═════════════════════════════════════════════════════════╗
║ ◈ database█                                             ║
╚═════════════════════════════════════════════════════════╝

WITH RESULTS:
╔═════════════════════════════════════════════════════════╗
║ ◈ database█                                             ║
╟─────────────────────────────────────────────────────────╢
║ ▶ DATABASE_FAILOVER         RECOVERY    ◐ SEMI         ║
║   DATABASE_RESTORE          RECOVERY    ○ MAN          ║
║   DATABASE_BACKUP           MAINTENANCE ● AUTO         ║
╚═════════════════════════════════════════════════════════╝

NO RESULTS:
╔═════════════════════════════════════════════════════════╗
║ ◈ xyzabc█                                               ║
╟─────────────────────────────────────────────────────────╢
║   No runbooks match "xyzabc"                            ║
╚═════════════════════════════════════════════════════════╝
```

### L3: Command Palette
```
CLOSED:
[Press Ctrl+K or /]

OPEN:
╔═════════════════════════════════════════════════════════╗
║ > █                                                     ║
╟─────────────────────────────────────────────────────────╢
║ RECENT COMMANDS                                         ║
║ ▶ Execute: DATABASE_FAILOVER                           ║
║   View: SLO Dashboard                                   ║
║   Navigate: Black Box                                   ║
╟─────────────────────────────────────────────────────────╢
║ ACTIONS                                                 ║
║   New Runbook                           Ctrl+N          ║
║   Execute Selected                      Enter           ║
║   Open Settings                         Ctrl+,          ║
╚═════════════════════════════════════════════════════════╝

FILTERED:
╔═════════════════════════════════════════════════════════╗
║ > exec█                                                 ║
╟─────────────────────────────────────────────────────────╢
║ ▶ Execute: DATABASE_FAILOVER            Ctrl+E         ║
║   Execute: REDIS_RESTART                Ctrl+E         ║
║   Execute: POD_AUTOSCALE                Ctrl+E         ║
╚═════════════════════════════════════════════════════════╝
```

---

## L2: Buttons

### L3: Primary Action Button
```
IDLE:
┌─────────────────┐
│ ▶ LAUNCH        │
└─────────────────┘

HOVER:
╔═════════════════╗
║ ▶ LAUNCH        ║
╚═════════════════╝

PRESSED:
╔═════════════════╗
║▐▶ LAUNCH       ▐║
╚═════════════════╝

LOADING:
╔═════════════════╗
║ ◎ LAUNCHING...  ║
╚═════════════════╝

DISABLED:
┌─────────────────┐
│ ▷ LAUNCH        │ ← Grayed out
└─────────────────┘
```

### L3: Danger Button
```
IDLE:
┌─────────────────┐
│ ⚠ ABORT         │
└─────────────────┘

HOVER:
╔═════════════════╗
║ ⚠ ABORT         ║ ← Red highlight
╚═════════════════╝

CONFIRMING:
╔═════════════════════════════╗
║ ⚠ CONFIRM ABORT? [Y/N]      ║
╚═════════════════════════════╝
```

### L3: Toggle Button
```
OFF STATE:
┌───────────────────────────┐
│ ○ AUTO-APPROVE    [OFF]   │
└───────────────────────────┘

ON STATE:
┌───────────────────────────┐
│ ● AUTO-APPROVE    [ON]    │
└───────────────────────────┘

TRANSITIONING:
┌───────────────────────────┐
│ ◐ AUTO-APPROVE    [...]   │
└───────────────────────────┘
```

---

## L2: Modal Dialogs

### L3: Confirmation Modal
```
STANDARD:
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ◈ CONFIRM EXECUTION                                     ║
║                                                           ║
║   Execute DATABASE_FAILOVER?                              ║
║                                                           ║
║   This will affect 12,450 connections.                    ║
║                                                           ║
║            [Cancel]              [Execute]                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

DANGER:
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ⚠ DESTRUCTIVE ACTION                                   ║
║                                                           ║
║   This action cannot be undone.                           ║
║                                                           ║
║   Type "CONFIRM" to proceed:                              ║
║   ┌─────────────────────────────────────────────────┐    ║
║   │ CONFIR█                                         │    ║
║   └─────────────────────────────────────────────────┘    ║
║                                                           ║
║            [Cancel]              [Delete]                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

### L3: ARM & FIRE Modal
```
IDLE (before arming):
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║                    ◇ READY TO ARM                         ║
║                                                           ║
║   OPERATION: Halt Application Traffic                     ║
║   IMPACT: 12,450 connections                              ║
║                                                           ║
║              Press [A] or [SPACE] to ARM                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

ARMED (waiting for fire):
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ▲▲▲ SYSTEM ARMED ▲▲▲                        ║
║                                                           ║
║   OPERATION: Halt Application Traffic                     ║
║   IMPACT: 12,450 connections                              ║
║                                                           ║
║              HOLD [SPACE] FOR 3 SECONDS                   ║
║                                                           ║
║   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0%      ║
║                                                           ║
║              T-MINUS 10s AUTO-ABORT                       ║
║                                                           ║
║              [ESC] Cancel                                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

ENGAGING (holding space):
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ▲▲▲ ENGAGING ▲▲▲                            ║
║                                                           ║
║   OPERATION: Halt Application Traffic                     ║
║   IMPACT: 12,450 connections                              ║
║                                                           ║
║              ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░  65%     ║
║                                                           ║
║              1.05s REMAINING                              ║
║                                                           ║
║              RELEASE TO CANCEL                            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

EXECUTED (flash then dismiss):
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✓ EXECUTED                                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

#### L5: ARM & FIRE Animation Sequence
```
T+0ms:     IDLE         → User presses [A]
T+100ms:   ░ flash      → Border changes to amber
T+200ms:   ARMED        → Warning text appears
T+300ms:   Timer starts → "T-MINUS 10s" begins countdown

[User holds SPACE]
T+0ms:     0%           → Progress bar starts
T+1000ms:  33%          → ▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░░░
T+2000ms:  66%          → ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░
T+3000ms:  100%         → ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰
T+3050ms:  FLASH        → Screen flash (50ms)
T+3100ms:  EXECUTED     → Success state
T+3500ms:  DISMISS      → Modal closes
```

---

# L1: FEEDBACK DOMAIN

## L2: Notifications

### L3: Toast Notification
```
SUCCESS:
┌─────────────────────────────────────────────┐
│ ✓ Runbook executed successfully             │
│   DATABASE_FAILOVER completed in 04:23      │
└─────────────────────────────────────────────┘

WARNING:
┌─────────────────────────────────────────────┐
│ ⚠ SLO budget declining                      │
│   BG_JOBS at -0.7% (T-8 days to exhaust)    │
└─────────────────────────────────────────────┘

ERROR:
┌─────────────────────────────────────────────┐
│ ✗ Execution failed                          │
│   Step 3: Permission denied                 │
│   [View Details]                            │
└─────────────────────────────────────────────┘

INFO:
┌─────────────────────────────────────────────┐
│ ◈ New runbook available                     │
│   SSL_ROTATION_V2 ready for review          │
└─────────────────────────────────────────────┘
```

#### L5: Toast Animation
```
ENTRY (300ms slide-in):
T+0ms:    ─────────────────────────────────────│ (off-screen right)
T+100ms:  ─────────────────────────────│────────
T+200ms:  ───────────────────│──────────────────
T+300ms:  │ ✓ Runbook executed successfully    │ (final position)

DISMISS (200ms fade-out):
T+0ms:    │ ✓ Runbook executed successfully    │ (100% opacity)
T+100ms:  │ ✓ Runbook executed successfully    │ (50% opacity)
T+200ms:  (removed from DOM)
```

### L3: Inline Alert
```
INFO:
┌──────────────────────────────────────────────────────────────┐
│ ◈ This runbook requires manual approval before step 3       │
└──────────────────────────────────────────────────────────────┘

WARNING:
┌──────────────────────────────────────────────────────────────┐
│ ⚠ 2 steps marked as CRITICAL - ARM & FIRE required         │
└──────────────────────────────────────────────────────────────┘

ERROR:
┌──────────────────────────────────────────────────────────────┐
│ ✗ Cannot proceed: Database replica not available            │
│   [Retry] [Skip] [Abort]                                    │
└──────────────────────────────────────────────────────────────┘

SUCCESS:
┌──────────────────────────────────────────────────────────────┐
│ ✓ Pre-flight checks complete - Ready for launch             │
└──────────────────────────────────────────────────────────────┘
```

---

## L2: Progress Indicators

### L3: Linear Progress Bar
```
INDETERMINATE:
░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ (animating)

DETERMINATE:
▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░░░ 45%

COMPLETE:
▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰ 100% ✓

ERROR:
▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░░░ 45% ✗

SEGMENTED (steps):
[▰▰▰▰][▰▰▰▰][▰▰░░][░░░░][░░░░] Step 3/5
```

### L3: Circular/Spinner
```
IDLE:
○

LOADING (spinning):
◐ → ◓ → ◑ → ◒ → (repeat 250ms intervals)

COMPLETE:
✓

ERROR:
✗
```

### L3: Step Progress
```
NOT STARTED:
○ Step 1 › ○ Step 2 › ○ Step 3 › ○ Step 4 › ○ Step 5

IN PROGRESS:
✓ Step 1 › ◎ Step 2 › ○ Step 3 › ○ Step 4 › ○ Step 5

CURRENT STEP CRITICAL:
✓ Step 1 › ◈ Step 2 ARMED › ○ Step 3 › ○ Step 4 › ○ Step 5

PARTIAL COMPLETE:
✓ Step 1 › ✓ Step 2 › ✓ Step 3 › ◎ Step 4 › ○ Step 5

ALL COMPLETE:
✓ Step 1 › ✓ Step 2 › ✓ Step 3 › ✓ Step 4 › ✓ Step 5

WITH FAILURE:
✓ Step 1 › ✓ Step 2 › ✗ Step 3 › ⊗ Step 4 › ⊗ Step 5
                       ▲          ▲
                       │          └─ Blocked
                       └─ Failed
```

---

## L2: Log/Stream Output

### L3: Command Log
```
LIVE STREAM:
╔═══════════════════════════════════════════════════════════════╗
║ 14:23:12.001 [CMD] pg_isready -h replica -p 5432              ║
║ 14:23:12.234 [OUT] replica:5432 - accepting connections       ║
║ 14:23:12.235 [SYS] Step 1 COMPLETE                            ║
║ 14:23:12.300 [SYS] Arming Step 2...                           ║
║ 14:23:15.000 [USR] Key hold detected                          ║
║ 14:23:18.001 [SYS] Executing Step 2...                        ║
║ 14:23:18.050 [CMD] kubectl scale deploy/api --replicas=0      ║
║ 14:23:19.200 [OUT] deployment.apps/api scaled                 ║
║ 14:23:19.201 [SYS] Step 2 COMPLETE                            ║
║ █                                                             ║
╚═══════════════════════════════════════════════════════════════╝

WITH SEVERITY COLORS:
║ 14:23:12.001 [INFO]  Starting execution...                    ║
║ 14:23:12.234 [OK]    Replica ready                            ║
║ 14:23:15.000 [WARN]  High latency detected (250ms)            ║
║ 14:23:18.050 [ERROR] Connection refused                       ║
║ 14:23:18.100 [CRIT]  Step failed - manual intervention needed ║
```

### L3: Telemetry Stream
```
SPLIT VIEW (log + metrics):
┌─────────────────────────────┬───────────────────────────────┐
│ COMMAND LOG                 │ TELEMETRY                     │
├─────────────────────────────┼───────────────────────────────┤
│ 14:23:12 [CMD] pg_isready   │ CONNECTIONS: 12,450           │
│ 14:23:12 [OK]  accepting    │ ERROR RATE:  0.1%             │
│ 14:23:15 [ARM] Step 2       │ LATENCY:     185ms            │
│ 14:23:18 [EXE] kubectl      │                               │
│ 14:23:19 [OK]  scaled       │ CPU:  ▰▰▰▰▰░░░░░ 45%         │
│ █                           │ MEM:  ▰▰▰▰▰▰░░░░ 62%         │
│                             │ DISK: ▰▰▰▰▰▰▰▰░░ 78%         │
└─────────────────────────────┴───────────────────────────────┘
```

---

# L1: SPECIAL COMPONENTS

## L2: Timeline

### L3: Vertical Timeline
```
T+14:00 ─●─ ◆ DEPLOY v2.4.1
         │  └─ OAuth token change
         │
T+14:05 ─●─ ◈ ANOMALY DETECTED
         │  └─ Error rate: 0.1% → 52%
         │
T+14:08 ─●─ ◇ ALERT TRIGGERED
         │  └─ @alice acknowledged
         │
T+14:15 ─●─ ◆ ROOT CAUSE IDENTIFIED
         │  └─ Token expiry off-by-one
         │
T+14:30 ─●─ ◈ HOTFIX DEPLOYED
         │  └─ Error rate normalized
         │
T+14:45 ─●─ ✓ ALL CLEAR
```

### L3: Horizontal Timeline
```
  DEPLOY    ANOMALY    ALERT    ROOT CAUSE   HOTFIX    ALL CLEAR
    │          │         │          │          │          │
    ●──────────●─────────●──────────●──────────●──────────●
    │          │         │          │          │          │
 T+14:00   T+14:05   T+14:08    T+14:15    T+14:30    T+14:45
    │          │                                          │
    └──────────┴──────────── INCIDENT DURATION ───────────┘
                              45 minutes
```

---

## L2: Diff View

### L3: Side-by-Side Diff
```
┌─────────────────────────────┬─────────────────────────────┐
│ BEFORE                      │ AFTER                       │
├─────────────────────────────┼─────────────────────────────┤
│ replicas: 5                 │ replicas: 0                 │
│ timeout: 30s                │ timeout: 30s                │
│ - healthCheck: /health      │ + healthCheck: /ready       │
│   interval: 10s             │   interval: 10s             │
└─────────────────────────────┴─────────────────────────────┘
```

### L3: Unified Diff
```
┌─────────────────────────────────────────────────────────────┐
│ deployment.yaml                                             │
├─────────────────────────────────────────────────────────────┤
│   spec:                                                     │
│ -   replicas: 5                                            │
│ +   replicas: 0                                            │
│     container:                                              │
│ -     healthCheck: /health                                 │
│ +     healthCheck: /ready                                  │
│       interval: 10s                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## L2: Keyboard Shortcut Display

### L3: Inline Hint
```
[E]xecute  [N]ew  [/]Search  [?]Help
```

### L3: Key Combination
```
Ctrl+K    Open command palette
Ctrl+E    Execute selected
Ctrl+S    Save
Ctrl+Z    Undo
ESC       Cancel / Back
```

### L3: Chord Display
```
Current chord: g → _

Available:
  g g  → Go to top
  g e  → Go to end
  g n  → Go to next error
  g p  → Go to previous error
```

---

## COMPONENT STATE SUMMARY

| Component | States | Transitions |
|-----------|--------|-------------|
| Tab | IDLE, HOVER, SELECTED, DISABLED, ALERT | 150ms ease |
| Button | IDLE, HOVER, PRESSED, LOADING, DISABLED | 100ms ease |
| Status | NOMINAL, WARNING, CRITICAL, UNKNOWN, OFFLINE | 500ms pulse |
| Progress | 0-100%, INDETERMINATE, COMPLETE, ERROR | 100ms linear |
| Modal | CLOSED, OPEN, CONFIRMING | 200ms slide |
| ARM & FIRE | IDLE, ARMED, ENGAGING, EXECUTED, CANCELLED | 3000ms hold |
| Toast | HIDDEN, ENTERING, VISIBLE, EXITING | 300ms slide |
| Card | IDLE, HOVER, SELECTED, EXECUTING | 100ms ease |
| Table Row | IDLE, HOVER, SELECTED, EXECUTING, SUCCESS, FAILURE | 100ms ease |
| Search | IDLE, FOCUSED, TYPING, RESULTS, NO_RESULTS | immediate |

---

## DOCUMENT CONTROL

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-30 | Claude | Initial 5-level taxonomy |
