# Aerospace/Space Mission Control Component Taxonomy
**Version**: 2.0.0-COMPLETE | **Date**: 2025-12-30 | **Classification**: Exhaustive Design System
**Depth**: 5-Level × 12-Dimension Matrix

---

## TAXONOMY MATRIX

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    12 DIMENSIONS                            │
                    ├────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┤
                    │VIS │CLR │TYP │SPC │BDR │ANI │SND │INT │ACC │RSP │THM │DAT │
┌───────────────────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
│ L1 NAVIGATION     │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ○  │
│ L1 STATUS         │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │
│ L1 DATA           │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ○  │ ●  │ ●  │ ●  │ ●  │ ●  │
│ L1 INTERACTION    │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │
│ L1 FEEDBACK       │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │ ●  │
│ L1 LAYOUT         │ ●  │ ○  │ ○  │ ●  │ ●  │ ●  │ ○  │ ●  │ ●  │ ●  │ ●  │ ○  │
│ L1 TYPOGRAPHY     │ ●  │ ●  │ ●  │ ●  │ ○  │ ●  │ ○  │ ○  │ ●  │ ●  │ ●  │ ○  │
│ L1 ICONOGRAPHY    │ ●  │ ●  │ ○  │ ●  │ ○  │ ●  │ ○  │ ●  │ ●  │ ●  │ ●  │ ○  │
└───────────────────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘

DIMENSIONS:
VIS = Visual Structure    CLR = Color System       TYP = Typography
SPC = Spacing/Layout      BDR = Borders/Edges      ANI = Animation
SND = Sound Design        INT = Interaction        ACC = Accessibility
RSP = Responsive          THM = Theming            DAT = Data States
```

---

# DIMENSION 1: COLOR SYSTEM

## Color Palette (Aerospace Theme)

### Primary Colors
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRIMARY PALETTE                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ VOID BLACK        #0a0a0f    ████████  Base background                     │
│ DEEP SPACE        #12121a    ████████  Panel background                    │
│ NEBULA DARK       #1a1a2e    ████████  Card background                     │
│ STARFIELD         #2d2d44    ████████  Elevated surface                    │
│                                                                             │
│ PLASMA BLUE       #00afff    ████████  Primary accent                      │
│ CYAN GLOW         #00ffff    ████████  Highlight/Focus                     │
│ ICE WHITE         #e0e0e0    ████████  Primary text                        │
│ GHOST WHITE       #888899    ████████  Secondary text                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Semantic Colors
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SEMANTIC PALETTE                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ STATUS COLORS                                                               │
│ ───────────────────────────────────────────────────────────────────────     │
│ NOMINAL GREEN     #00ff88    ████████  Success, healthy, go                │
│ CAUTION AMBER     #ffaa00    ████████  Warning, attention                  │
│ ALERT RED         #ff4444    ████████  Error, critical, stop               │
│ UNKNOWN GRAY      #666677    ████████  Unknown, offline                    │
│                                                                             │
│ SEVERITY GRADIENT                                                           │
│ ───────────────────────────────────────────────────────────────────────     │
│ SEV-0 (INFO)      #00afff    ████████  Informational                       │
│ SEV-1 (LOW)       #00ff88    ████████  Low priority                        │
│ SEV-2 (MEDIUM)    #ffff00    ████████  Medium priority                     │
│ SEV-3 (HIGH)      #ffaa00    ████████  High priority                       │
│ SEV-4 (CRITICAL)  #ff4444    ████████  Critical                            │
│ SEV-5 (EMERGENCY) #ff0000    ████████  Emergency (pulsing)                 │
│                                                                             │
│ CATEGORY COLORS                                                             │
│ ───────────────────────────────────────────────────────────────────────     │
│ RECOVERY          #ffaa00    ████████  Recovery operations                 │
│ SCALING           #00afff    ████████  Scaling operations                  │
│ DEPLOYMENT        #00ff88    ████████  Deployment operations               │
│ SECURITY          #ff4444    ████████  Security operations                 │
│ DIAGNOSTICS       #aa00ff    ████████  Debug/diagnostic                    │
│ MAINTENANCE       #888899    ████████  Maintenance tasks                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Color Application Rules
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ APPLICATION RULES                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ CONTRAST RATIOS (WCAG 2.1 AA)                                              │
│ ───────────────────────────────────────────────────────────────────────     │
│ Text on VOID BLACK:     ICE WHITE (#e0e0e0)     Ratio: 12.5:1 ✓           │
│ Text on DEEP SPACE:     ICE WHITE (#e0e0e0)     Ratio: 10.2:1 ✓           │
│ Text on NEBULA DARK:    ICE WHITE (#e0e0e0)     Ratio: 8.1:1  ✓           │
│ Status on dark bg:      NOMINAL GREEN           Ratio: 7.4:1  ✓           │
│                                                                             │
│ COLOR BLINDNESS SUPPORT                                                     │
│ ───────────────────────────────────────────────────────────────────────     │
│ Never use color alone - always pair with:                                   │
│   • Shape (● ◐ ○ for status)                                               │
│   • Text label (NOMINAL, WARNING, CRITICAL)                                │
│   • Pattern (solid, striped, dotted)                                       │
│                                                                             │
│ GLOW/BLOOM EFFECTS (GPU)                                                    │
│ ───────────────────────────────────────────────────────────────────────     │
│ Focus glow:    box-shadow: 0 0 20px rgba(0, 255, 255, 0.5)                 │
│ Alert pulse:   box-shadow: 0 0 30px rgba(255, 68, 68, 0.8)                 │
│ Success flash: box-shadow: 0 0 40px rgba(0, 255, 136, 0.6)                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 2: TYPOGRAPHY

## Font Stack
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FONT HIERARCHY                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ PRIMARY (Monospace - Terminal/Data)                                         │
│   Font: "JetBrains Mono", "Fira Code", "SF Mono", monospace                │
│   Use: Code, data tables, timestamps, IDs                                   │
│                                                                             │
│ SECONDARY (Sans-serif - UI)                                                 │
│   Font: "Inter", "SF Pro", "Segoe UI", system-ui, sans-serif              │
│   Use: Labels, buttons, navigation                                          │
│                                                                             │
│ DISPLAY (Condensed - Headers)                                               │
│   Font: "Barlow Condensed", "Roboto Condensed", sans-serif                 │
│   Use: Section headers, status banners                                      │
│                                                                             │
│ NUMERIC (Tabular - Metrics)                                                 │
│   Font: "JetBrains Mono" with font-feature-settings: "tnum"                │
│   Use: Numbers that need to align vertically                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Type Scale
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TYPE SCALE (1.25 ratio)                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ DISPLAY-1    32px / 40px    ████████████████████████████████               │
│              MISSION CONTROL                                                │
│                                                                             │
│ DISPLAY-2    24px / 32px    ████████████████████████                       │
│              Database Failover                                              │
│                                                                             │
│ HEADING-1    20px / 28px    ████████████████████                           │
│              Flight Sequence                                                │
│                                                                             │
│ HEADING-2    16px / 24px    ████████████████                               │
│              Step Details                                                   │
│                                                                             │
│ BODY         14px / 20px    ██████████████                                 │
│              Regular content text                                           │
│                                                                             │
│ CAPTION      12px / 16px    ████████████                                   │
│              Timestamps, hints                                              │
│                                                                             │
│ MICRO        10px / 14px    ██████████                                     │
│              Badges, tiny labels                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Text Styles
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEXT TREATMENTS                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NORMAL          Regular weight, standard tracking                           │
│                 The quick brown fox jumps                                   │
│                                                                             │
│ EMPHASIZED      Medium weight, tight tracking                               │
│                 The quick brown fox jumps                                   │
│                                                                             │
│ STRONG          Bold weight, normal tracking                                │
│                 The quick brown fox jumps                                   │
│                                                                             │
│ CODE            Monospace, background highlight                             │
│                 kubectl scale deploy/api                                    │
│                                                                             │
│ LABEL           All caps, wide tracking (0.1em)                            │
│                 STATUS  MODE  CATEGORY                                      │
│                                                                             │
│ NUMERIC         Tabular figures, right-aligned                              │
│                   12,450                                                    │
│                    1,234                                                    │
│                      567                                                    │
│                                                                             │
│ TIMESTAMP       Monospace, dim color                                        │
│                 14:23:45.123                                                │
│                                                                             │
│ COUNTDOWN       Tabular, large, bold                                        │
│                 T-MINUS 00:15:00                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 3: SPACING & LAYOUT

## Spacing Scale
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SPACING TOKENS (4px base)                                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ space-0     0px     │                          None                        │
│ space-1     4px     │▌                         Tight                       │
│ space-2     8px     │██                        Compact                     │
│ space-3     12px    │███                       Default                     │
│ space-4     16px    │████                      Comfortable                 │
│ space-5     24px    │██████                    Spacious                    │
│ space-6     32px    │████████                  Section gap                 │
│ space-7     48px    │████████████              Panel gap                   │
│ space-8     64px    │████████████████          Region gap                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Layout Grid
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 12-COLUMN GRID SYSTEM                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ FULL WIDTH (12 cols)                                                        │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ SIDEBAR + MAIN (3 + 9 cols)                                                │
│ ┌─────────────┬─────────────────────────────────────────────────────────┐  │
│ │   SIDEBAR   │                        MAIN                             │  │
│ │   (3 col)   │                       (9 col)                           │  │
│ └─────────────┴─────────────────────────────────────────────────────────┘  │
│                                                                             │
│ THREE PANEL (4 + 4 + 4 cols)                                               │
│ ┌─────────────────────┬─────────────────────┬─────────────────────┐       │
│ │       PANEL 1       │       PANEL 2       │       PANEL 3       │       │
│ │       (4 col)       │       (4 col)       │       (4 col)       │       │
│ └─────────────────────┴─────────────────────┴─────────────────────┘       │
│                                                                             │
│ MASTER-DETAIL (4 + 8 cols)                                                 │
│ ┌─────────────────────┬─────────────────────────────────────────────┐     │
│ │       LIST          │                  DETAIL                     │     │
│ │      (4 col)        │                 (8 col)                     │     │
│ └─────────────────────┴─────────────────────────────────────────────┘     │
│                                                                             │
│ DASHBOARD GRID (mixed)                                                      │
│ ┌───────────────────────────────────────┬───────────────────────────┐     │
│ │            STATUS BANNER (8)          │      ALERTS (4)           │     │
│ ├─────────────────────┬─────────────────┼───────────────────────────┤     │
│ │    CARD (4)         │    CARD (4)     │      CARD (4)             │     │
│ ├─────────────────────┴─────────────────┴───────────────────────────┤     │
│ │                        TABLE (12)                                  │     │
│ └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Density Modes
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DENSITY VARIANTS                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ COMPACT (High density - power users)                                        │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ID    │CALLSIGN           │CLASS    │AUTO│T-AVG│STS│                   │  │
│ │REC-01│DATABASE_FAILOVER  │RECOVERY │SEMI│15:00│ ◈ │                   │  │
│ │REC-02│REDIS_RESTART      │RECOVERY │MAN │08:30│ ◈ │                   │  │
│ │SCL-05│POD_AUTOSCALE      │SCALING  │FULL│02:15│ ◈ │                   │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ Row height: 24px, Padding: 4px, Font: 12px                                 │
│                                                                             │
│ COMFORTABLE (Default - balanced)                                            │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ ID      │ CALLSIGN              │ CLASS     │ AUTO │ T-AVG │ STS     │  │
│ │         │                       │           │      │       │         │  │
│ │ REC-01  │ DATABASE_FAILOVER     │ RECOVERY  │ SEMI │ 15:00 │ ◈       │  │
│ │         │                       │           │      │       │         │  │
│ │ REC-02  │ REDIS_RESTART         │ RECOVERY  │ MAN  │ 08:30 │ ◈       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ Row height: 40px, Padding: 8px, Font: 14px                                 │
│                                                                             │
│ SPACIOUS (Low density - accessibility)                                      │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │  ID        CALLSIGN                  CLASS       AUTO    T-AVG   STS │  │
│ │                                                                       │  │
│ │  REC-01    DATABASE_FAILOVER         RECOVERY    SEMI    15:00   ◈  │  │
│ │                                                                       │  │
│ │  REC-02    REDIS_RESTART             RECOVERY    MAN     08:30   ◈  │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│ Row height: 56px, Padding: 16px, Font: 16px                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 4: BORDERS & EDGES

## Border Styles
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ BORDER VOCABULARY                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ THIN SINGLE (default)                                                       │
│ ┌────────────────────────────────────────────────────────────────────┐     │
│ │ Content area                                                       │     │
│ └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
│ DOUBLE LINE (emphasis)                                                      │
│ ╔════════════════════════════════════════════════════════════════════╗     │
│ ║ Content area                                                       ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ ROUNDED CORNERS                                                             │
│ ╭────────────────────────────────────────────────────────────────────╮     │
│ │ Content area                                                       │     │
│ ╰────────────────────────────────────────────────────────────────────╯     │
│                                                                             │
│ HEAVY/THICK (focus/selected)                                                │
│ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓     │
│ ┃ Content area                                                       ┃     │
│ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛     │
│                                                                             │
│ DASHED (placeholder/pending)                                                │
│ ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐     │
│ ╎ Content area                                                       ╎     │
│ └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘     │
│                                                                             │
│ MIXED (header emphasis)                                                     │
│ ╔════════════════════════════════════════════════════════════════════╗     │
│ ║ HEADER                                                             ║     │
│ ╠════════════════════════════════════════════════════════════════════╣     │
│ │ Content area                                                       │     │
│ └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Border Semantics
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SEMANTIC BORDERS                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NOMINAL (green glow)                                                        │
│ ╔═[#00ff88]══════════════════════════════════════════════════════════════╗ │
│ ║ System operating normally                                          ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ WARNING (amber glow)                                                        │
│ ╔═[#ffaa00]══════════════════════════════════════════════════════════════╗ │
│ ║ Attention required                                                 ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ CRITICAL (red glow + pulse)                                                 │
│ ╔═[#ff4444]══════════════════════════════════════════════════════════════╗ │
│ ║ Immediate action required                                          ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ ARMED (amber + animated)                                                    │
│ ╔═[#ffaa00]═[blink]═════════════════════════════════════════════════════╗  │
│ ║ ⚠ SYSTEM ARMED - Ready to fire                                    ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ FOCUS (cyan glow)                                                           │
│ ╔═[#00ffff]══════════════════════════════════════════════════════════════╗ │
│ ║ Currently focused element                                          ║     │
│ ╚════════════════════════════════════════════════════════════════════╝     │
│                                                                             │
│ DISABLED (dim, no glow)                                                     │
│ ┌─[#444444]──────────────────────────────────────────────────────────────┐ │
│ │ Inactive element                                                   │     │
│ └────────────────────────────────────────────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 5: ANIMATION

## Timing Functions
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ EASING CURVES                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ EASE-OUT (default for enter)                                                │
│ ████▓▓▓░░░░░░░░░░░░░░  Fast start, smooth stop                             │
│ Duration: 150ms                                                             │
│                                                                             │
│ EASE-IN (for exit)                                                          │
│ ░░░░░░░░░░░░░░▓▓▓████  Gradual start, fast end                             │
│ Duration: 100ms                                                             │
│                                                                             │
│ EASE-IN-OUT (for transforms)                                                │
│ ░░░▓▓████████▓▓░░░░░  Smooth start and end                                 │
│ Duration: 200ms                                                             │
│                                                                             │
│ LINEAR (for progress bars)                                                  │
│ ████████████████████  Constant speed                                       │
│ Duration: varies                                                            │
│                                                                             │
│ SPRING (for interactive feedback)                                           │
│ ████▓▓░▓██▓░▓█░░░░░  Overshoot + settle                                   │
│ Duration: 300ms                                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Animation Catalog
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TRANSITION ANIMATIONS                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ FADE IN                                                                     │
│ T+0ms:   ░░░░░░░░░░  opacity: 0                                            │
│ T+75ms:  ▓▓▓▓░░░░░░  opacity: 0.5                                          │
│ T+150ms: ██████████  opacity: 1                                            │
│                                                                             │
│ FADE OUT                                                                    │
│ T+0ms:   ██████████  opacity: 1                                            │
│ T+50ms:  ▓▓▓▓░░░░░░  opacity: 0.5                                          │
│ T+100ms: ░░░░░░░░░░  opacity: 0                                            │
│                                                                             │
│ SLIDE IN (from right)                                                       │
│ T+0ms:                          │████│  x: 100%                            │
│ T+75ms:                 │████│          x: 50%                             │
│ T+150ms: │████│                         x: 0                               │
│                                                                             │
│ SLIDE OUT (to right)                                                        │
│ T+0ms:   │████│                         x: 0                               │
│ T+50ms:              │████│             x: 50%                             │
│ T+100ms:                       │████│   x: 100%                            │
│                                                                             │
│ SCALE UP (modal appear)                                                     │
│ T+0ms:        ▪         scale: 0.8, opacity: 0                             │
│ T+100ms:     ███        scale: 0.95                                        │
│ T+200ms:   ███████      scale: 1                                           │
│                                                                             │
│ SCALE DOWN (modal dismiss)                                                  │
│ T+0ms:     ███████      scale: 1                                           │
│ T+100ms:    █████       scale: 0.95, opacity: 0.5                          │
│ T+150ms:      ▪         scale: 0.8, opacity: 0                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Looping Animations
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ CONTINUOUS ANIMATIONS                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ SPINNER (loading)                                                           │
│ T+0ms:    ◐    T+250ms:  ◓    T+500ms:  ◑    T+750ms:  ◒    (repeat)      │
│                                                                             │
│ PULSE (attention)                                                           │
│ T+0ms:    ●     opacity: 1                                                 │
│ T+500ms:  ○     opacity: 0.3                                               │
│ T+1000ms: ●     opacity: 1    (repeat)                                     │
│                                                                             │
│ FAST PULSE (critical)                                                       │
│ T+0ms:    ●     opacity: 1                                                 │
│ T+250ms:  ○     opacity: 0.3                                               │
│ T+500ms:  ●     opacity: 1    (repeat)                                     │
│                                                                             │
│ BLINK (armed state)                                                         │
│ T+0ms:    ARMED     visible                                                │
│ T+500ms:  _____     hidden                                                 │
│ T+1000ms: ARMED     visible   (repeat)                                     │
│                                                                             │
│ SCAN LINE (processing)                                                      │
│ T+0ms:    ▁░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                       │
│ T+500ms:  ░░░░░░░░░░░░░░░░░░░▁░░░░░░░░░░░░░░░░░░░░░░                       │
│ T+1000ms: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▁░░░  (repeat)             │
│                                                                             │
│ BREATHE (idle indicator)                                                    │
│ T+0ms:    ●     opacity: 0.6                                               │
│ T+2000ms: ●     opacity: 1.0                                               │
│ T+4000ms: ●     opacity: 0.6  (repeat)                                     │
│                                                                             │
│ PROGRESS BAR SHIMMER (indeterminate)                                        │
│ T+0ms:    ░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                      │
│ T+500ms:  ░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░                       │
│ T+1000ms: ░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░  (repeat)            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## State Transition Choreography
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ARM & FIRE SEQUENCE (3000ms total)                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ PHASE 1: IDLE → ARMED (400ms)                                              │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ T+0ms:    Border: #444 → (transitioning)                            │    │
│ │ T+100ms:  Border: #ffaa00, Warning icon fades in                    │    │
│ │ T+200ms:  "ARMED" badge slides down (y: -20 → 0)                    │    │
│ │ T+300ms:  Progress bar materializes (opacity: 0 → 1)                │    │
│ │ T+400ms:  Countdown timer starts, BLINK animation begins            │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│ PHASE 2: ARMED → ENGAGING (user holds SPACE, 3000ms)                       │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ T+0ms:    Progress: 0%, bar fill begins                             │    │
│ │           Border glow intensity: 0.3                                │    │
│ │                                                                     │    │
│ │ T+1000ms: Progress: 33%                                             │    │
│ │           ▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     │    │
│ │           Border glow intensity: 0.5                                │    │
│ │           Haptic: short pulse                                       │    │
│ │                                                                     │    │
│ │ T+2000ms: Progress: 66%                                             │    │
│ │           ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░░░░░░░     │    │
│ │           Border glow intensity: 0.8                                │    │
│ │           Sound: rising tone                                        │    │
│ │           Haptic: medium pulse                                      │    │
│ │                                                                     │    │
│ │ T+2900ms: Progress: 97%                                             │    │
│ │           ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░     │    │
│ │           Border: pulsing rapidly                                   │    │
│ │                                                                     │    │
│ │ T+3000ms: Progress: 100%                                            │    │
│ │           ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰     │    │
│ │           FLASH: 50ms white overlay                                 │    │
│ │           Sound: confirmation beep                                  │    │
│ │           Haptic: strong pulse                                      │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│ PHASE 3: EXECUTING → COMPLETE (300ms)                                      │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ T+0ms:    Spinner stops                                             │    │
│ │ T+100ms:  ✓ checkmark draws (stroke animation)                      │    │
│ │ T+200ms:  Border: #ffaa00 → #00ff88                                 │    │
│ │ T+300ms:  Success glow pulse emanates outward                       │    │
│ │           Sound: success chime                                      │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│ PHASE 3-ALT: EXECUTING → FAILURE (400ms)                                   │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ T+0ms:    Spinner stops abruptly                                    │    │
│ │ T+100ms:  ✗ X mark draws with shake (x: -5 → 5 → -3 → 3 → 0)       │    │
│ │ T+200ms:  Border: #ffaa00 → #ff4444                                 │    │
│ │ T+300ms:  Error glow pulse                                          │    │
│ │ T+400ms:  Error details panel slides in from bottom                 │    │
│ │           Sound: error tone (descending)                            │    │
│ │           Haptic: error pattern (long-short-short)                  │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│ ABORT (user releases early or ESC)                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ T+0ms:    Progress freezes                                          │    │
│ │ T+100ms:  Progress bar fades out                                    │    │
│ │ T+200ms:  Border: #ffaa00 → #444                                    │    │
│ │ T+300ms:  Returns to ARMED or IDLE state                            │    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 6: SOUND DESIGN

## Audio Feedback Palette
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ SOUND EFFECTS                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ INTERACTION SOUNDS                                                          │
│ ───────────────────────────────────────────────────────────────────────     │
│ click.wav        50ms   Soft click, button press                           │
│ select.wav       80ms   Selection confirmation                              │
│ hover.wav        30ms   Subtle tick (optional)                             │
│ type.wav         20ms   Keyboard typing feedback                            │
│ toggle.wav       60ms   Switch on/off                                       │
│                                                                             │
│ STATUS SOUNDS                                                               │
│ ───────────────────────────────────────────────────────────────────────     │
│ success.wav      200ms  Rising two-tone chime                              │
│ warning.wav      300ms  Attention tone, single note                        │
│ error.wav        400ms  Descending two-tone                                │
│ critical.wav     500ms  Urgent alarm (repeating)                           │
│                                                                             │
│ PROGRESS SOUNDS                                                             │
│ ───────────────────────────────────────────────────────────────────────     │
│ progress_tick.wav   30ms   Progress milestone                              │
│ countdown_tick.wav  50ms   Each second of countdown                        │
│ countdown_end.wav   200ms  Countdown complete                              │
│ charging.wav        loop   Rising tone during ARM & FIRE                   │
│                                                                             │
│ MISSION SOUNDS                                                              │
│ ───────────────────────────────────────────────────────────────────────     │
│ arm.wav          150ms  System armed confirmation                          │
│ fire.wav         100ms  Execution initiated                                │
│ abort.wav        300ms  Mission aborted                                    │
│ complete.wav     500ms  Mission accomplished fanfare                       │
│                                                                             │
│ AMBIENT SOUNDS (optional)                                                   │
│ ───────────────────────────────────────────────────────────────────────     │
│ hum.wav          loop   Low background hum                                 │
│ beep_idle.wav    loop   Periodic idle beep (slow)                          │
│ alert_loop.wav   loop   Alert state ambient                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Sound Triggers
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER MAPPING                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ ACTION                          SOUND              CONDITION                │
│ ───────────────────────────────────────────────────────────────────────     │
│ Button click                    click.wav          Always                   │
│ Row select                      select.wav         Always                   │
│ Tab switch                      select.wav         Always                   │
│ Modal open                      (none)             -                        │
│ Modal close                     click.wav          If success               │
│                                                                             │
│ Toast: success                  success.wav        Always                   │
│ Toast: warning                  warning.wav        If first occurrence      │
│ Toast: error                    error.wav          Always                   │
│                                                                             │
│ Status: nominal→warning         warning.wav        Once per transition      │
│ Status: *→critical              critical.wav       Loop until acknowledged  │
│                                                                             │
│ ARM & FIRE: arm                 arm.wav            On arm                   │
│ ARM & FIRE: holding             charging.wav       Loop while holding       │
│ ARM & FIRE: 1s mark             progress_tick.wav  At 33%                   │
│ ARM & FIRE: 2s mark             progress_tick.wav  At 66%                   │
│ ARM & FIRE: execute             fire.wav           On execute               │
│ ARM & FIRE: abort               abort.wav          On cancel                │
│                                                                             │
│ Mission complete                complete.wav       On success               │
│ Mission failed                  error.wav          On failure               │
│                                                                             │
│ Countdown: each second          countdown_tick.wav T-10 to T-1             │
│ Countdown: T-0                  countdown_end.wav  At zero                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 7: INTERACTION PATTERNS

## Input Methods
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ KEYBOARD INTERACTION                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NAVIGATION                                                                  │
│ ───────────────────────────────────────────────────────────────────────     │
│ ↑/↓         Move selection in list/table                                   │
│ ←/→         Switch tabs, move between panes                                │
│ Tab         Next focusable element                                          │
│ Shift+Tab   Previous focusable element                                      │
│ Home/End    First/last item in list                                         │
│ PgUp/PgDn   Page through large lists                                        │
│ g g         Go to top (vim-style)                                          │
│ G           Go to bottom (vim-style)                                        │
│                                                                             │
│ ACTIONS                                                                     │
│ ───────────────────────────────────────────────────────────────────────     │
│ Enter       Select/confirm/execute                                          │
│ Space       Toggle, ARM & FIRE hold                                         │
│ Escape      Cancel, close modal, go back                                    │
│ Delete      Delete selected item (with confirm)                             │
│ Backspace   Go back in navigation                                           │
│                                                                             │
│ COMMANDS                                                                    │
│ ───────────────────────────────────────────────────────────────────────     │
│ /           Open search                                                     │
│ :           Open command mode                                               │
│ Ctrl+K      Open command palette                                            │
│ Ctrl+S      Save                                                            │
│ Ctrl+Z      Undo                                                            │
│ Ctrl+Y      Redo                                                            │
│ ?           Show help/shortcuts                                             │
│                                                                             │
│ QUICK ACTIONS                                                               │
│ ───────────────────────────────────────────────────────────────────────     │
│ e           Execute selected runbook                                        │
│ n           New runbook                                                     │
│ d           Duplicate                                                       │
│ r           Rename                                                          │
│ a           Arm (in execution context)                                      │
│ s           Skip step                                                       │
│ F1-F6       Quick launch slots                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ MOUSE INTERACTION                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Click            Select item, activate button                               │
│ Double-click     Execute/open selected item                                 │
│ Right-click      Context menu                                               │
│ Hover            Show tooltip, highlight                                    │
│ Drag             Reorder items (if supported)                               │
│ Scroll           Navigate lists, zoom charts                                │
│ Ctrl+Click       Multi-select                                               │
│ Shift+Click      Range select                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TOUCH INTERACTION (tablet mode)                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Tap              Select item, activate button                               │
│ Double-tap       Execute/open                                               │
│ Long-press       Context menu, ARM & FIRE                                   │
│ Swipe left       Delete/archive (with confirm)                              │
│ Swipe right      Quick action (execute)                                     │
│ Two-finger zoom  Zoom charts                                                │
│ Pull-down        Refresh                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Focus Management
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FOCUS STATES                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ UNFOCUSED                                                                   │
│ ┌────────────────────────────────────────────┐                             │
│ │ Database Failover                          │                             │
│ └────────────────────────────────────────────┘                             │
│                                                                             │
│ FOCUSED (keyboard navigation)                                               │
│ ╔════════════════════════════════════════════╗  ← Cyan border              │
│ ║ Database Failover                          ║    + glow effect            │
│ ╚════════════════════════════════════════════╝                             │
│                                                                             │
│ FOCUSED + ACTIVE (being interacted with)                                   │
│ ╔════════════════════════════════════════════╗  ← Thicker border           │
│ ║▐Database Failover                         ▐║    + inverted section       │
│ ╚════════════════════════════════════════════╝                             │
│                                                                             │
│ FOCUS TRAP (modal)                                                          │
│ ┌────────────────────────────────────────────┐                             │
│ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← Background dimmed         │
│ │ ░░╔════════════════════════════════╗░░░░ │                               │
│ │ ░░║  Modal content (focus trapped) ║░░░░ │                               │
│ │ ░░╚════════════════════════════════╝░░░░ │                               │
│ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │                               │
│ └────────────────────────────────────────────┘                             │
│                                                                             │
│ FOCUS ORDER                                                                 │
│ ┌────────────────────────────────────────────────────────────────────────┐ │
│ │  [1]Header   [2]Search   [3]Tab1   [4]Tab2   [5]Tab3                  │ │
│ │  ┌──────────────────────────────────────────────────────────────────┐ │ │
│ │  │ [6]Row1  [7]Row2  [8]Row3                                        │ │ │
│ │  └──────────────────────────────────────────────────────────────────┘ │ │
│ │  [9]Button1   [10]Button2                                             │ │
│ └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 8: ACCESSIBILITY

## WCAG 2.1 AA Compliance
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ACCESSIBILITY REQUIREMENTS                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ COLOR & CONTRAST                                                            │
│ ───────────────────────────────────────────────────────────────────────     │
│ ✓ 4.5:1 contrast ratio for normal text                                     │
│ ✓ 3:1 contrast ratio for large text (>18px)                                │
│ ✓ 3:1 contrast ratio for UI components                                     │
│ ✓ Color never used as sole indicator                                       │
│                                                                             │
│ KEYBOARD                                                                    │
│ ───────────────────────────────────────────────────────────────────────     │
│ ✓ All functionality available via keyboard                                 │
│ ✓ Visible focus indicator (2px minimum)                                    │
│ ✓ No keyboard traps (except intentional modals)                            │
│ ✓ Skip links for main content                                              │
│ ✓ Logical tab order                                                        │
│                                                                             │
│ SCREEN READERS                                                              │
│ ───────────────────────────────────────────────────────────────────────     │
│ ✓ Proper heading hierarchy (h1 → h2 → h3)                                  │
│ ✓ ARIA labels for icons and non-text content                               │
│ ✓ Live regions for dynamic updates                                         │
│ ✓ Role attributes for custom widgets                                       │
│ ✓ Descriptive link text                                                    │
│                                                                             │
│ MOTION & ANIMATION                                                          │
│ ───────────────────────────────────────────────────────────────────────     │
│ ✓ Respect prefers-reduced-motion                                           │
│ ✓ No content flashes more than 3 times/second                              │
│ ✓ Pause/stop controls for animations                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Accessible Status Indicators
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STATUS WITH MULTIPLE INDICATORS                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NOMINAL (3 indicators: color + shape + label)                              │
│ ┌────────────────────────────────────────┐                                 │
│ │ ● NOMINAL                              │  Green circle + text            │
│ │   System operating normally            │  + descriptive text             │
│ └────────────────────────────────────────┘                                 │
│ ARIA: role="status" aria-label="System status: Nominal"                    │
│                                                                             │
│ WARNING (3 indicators: color + shape + label)                              │
│ ┌────────────────────────────────────────┐                                 │
│ │ ◐ WARNING                              │  Amber half-circle + text       │
│ │   Attention required                   │  + descriptive text             │
│ └────────────────────────────────────────┘                                 │
│ ARIA: role="alert" aria-label="Warning: Attention required"                │
│                                                                             │
│ CRITICAL (4 indicators: color + shape + label + animation)                 │
│ ┌────────────────────────────────────────┐                                 │
│ │ ○ CRITICAL (pulsing)                   │  Red empty circle + text        │
│ │   Immediate action required            │  + pulse + descriptive text     │
│ └────────────────────────────────────────┘                                 │
│ ARIA: role="alert" aria-live="assertive"                                   │
│       aria-label="Critical: Immediate action required"                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Reduced Motion Mode
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ MOTION PREFERENCES                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ STANDARD MODE (prefers-reduced-motion: no-preference)                      │
│ ───────────────────────────────────────────────────────────────────────     │
│ • Full animations enabled                                                   │
│ • Transitions: 150-300ms                                                   │
│ • Looping animations active                                                 │
│ • Progress bar fills smoothly                                               │
│                                                                             │
│ REDUCED MOTION MODE (prefers-reduced-motion: reduce)                       │
│ ───────────────────────────────────────────────────────────────────────     │
│ • Instant state changes (no transitions)                                   │
│ • Spinners replaced with static indicators: ◐ → ◈                          │
│ • Pulse animations disabled, use icon change instead                       │
│ • Progress bar updates in discrete steps                                   │
│                                                                             │
│ COMPARISON:                                                                 │
│                                                                             │
│ Standard:  ░░░░▓▓▓▓░░░░░░░░░░░░░░░░  (animating shimmer)                  │
│ Reduced:   ▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░  (static bar)                         │
│                                                                             │
│ Standard:  ◐ → ◓ → ◑ → ◒ (spinning)                                        │
│ Reduced:   ◈ LOADING... (static with text)                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 9: RESPONSIVE BEHAVIOR

## Breakpoints
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ RESPONSIVE BREAKPOINTS                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ TERMINAL (80-120 columns)                                                   │
│ ───────────────────────────────────────────────────────────────────────     │
│ • Full feature set                                                          │
│ • Side-by-side panels                                                       │
│ • Full keyboard navigation                                                  │
│                                                                             │
│ NARROW TERMINAL (40-79 columns)                                            │
│ ───────────────────────────────────────────────────────────────────────     │
│ • Stacked layouts                                                           │
│ • Collapsed sidebar                                                         │
│ • Abbreviated labels                                                        │
│                                                                             │
│ MINIMUM (24+ columns)                                                       │
│ ───────────────────────────────────────────────────────────────────────     │
│ • Essential features only                                                   │
│ • Single column                                                             │
│ • Icons replace text                                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Layout Adaptations
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ WIDE (120+ cols)                                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌────────┬────────────────────────────────────────────────────────────────┐ │
│ │SIDEBAR │                           MAIN CONTENT                         │ │
│ │        │ ┌────────────────────┬────────────────────┬──────────────────┐ │ │
│ │ Flight │ │      Card 1        │      Card 2        │     Card 3       │ │ │
│ │ Plans  │ └────────────────────┴────────────────────┴──────────────────┘ │ │
│ │        │ ┌───────────────────────────────────────────────────────────┐ │ │
│ │ SLOs   │ │                       Data Table                          │ │ │
│ │        │ │                                                           │ │ │
│ │ Chaos  │ └───────────────────────────────────────────────────────────┘ │ │
│ └────────┴────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ MEDIUM (80-119 cols)                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ ┌───┬──────────────────────────────────────────────────────────────────────┐│
│ │ ◈ │                         MAIN CONTENT                                 ││
│ │ ◇ │ ┌──────────────────────────┬──────────────────────────┐             ││
│ │ ◆ │ │         Card 1           │         Card 2           │             ││
│ │   │ └──────────────────────────┴──────────────────────────┘             ││
│ │   │ ┌─────────────────────────────────────────────────────┐             ││
│ │   │ │                    Data Table                        │             ││
│ │   │ └─────────────────────────────────────────────────────┘             ││
│ └───┴──────────────────────────────────────────────────────────────────────┘│
│ ▲ Collapsed sidebar (icons only)                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ NARROW (40-79 cols)                              │
├──────────────────────────────────────────────────┤
│ [◈][◇][◆][■][▣]  ← Tab bar instead of sidebar   │
│ ┌──────────────────────────────────────────────┐ │
│ │             Card 1                           │ │
│ └──────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────┐ │
│ │             Card 2                           │ │
│ └──────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────┐ │
│ │         Data Table (scrollable)              │ │
│ └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘

┌────────────────────────┐
│ MINIMUM (24-39 cols)   │
├────────────────────────┤
│ [◈][◇][◆] ...         │
│ ┌──────────────────┐   │
│ │ DB_FAILOVER      │   │
│ │ ◐ SEMI │ 15m     │   │
│ │ ▰▰▰▰▰▰▰▰▱▱ 85%   │   │
│ ├──────────────────┤   │
│ │ REDIS_RESTART    │   │
│ │ ○ MAN │ 8m       │   │
│ │ ▰▰▰▰▰▰▰▰▰▰ 100%  │   │
│ └──────────────────┘   │
│ [E]xec [/]Search       │
└────────────────────────┘
```

---

# DIMENSION 10: THEMING

## Theme Variants
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ THEME: AEROSPACE DARK (default)                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Background:  #0a0a0f (Void Black)                                          │
│ Surface:     #12121a (Deep Space)                                          │
│ Primary:     #00afff (Plasma Blue)                                         │
│ Text:        #e0e0e0 (Ice White)                                           │
│                                                                             │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ ◈ MISSION CONTROL                                    ● PWR ● NET   │    │
│ │ ┌─────────────────────────────────────────────────────────────────┐│    │
│ │ │ DATABASE_FAILOVER                                   ◐ SEMI      ││    │
│ │ │ ▰▰▰▰▰▰▰▰▱▱ 85%                                                  ││    │
│ │ └─────────────────────────────────────────────────────────────────┘│    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ THEME: AEROSPACE LIGHT (high ambient)                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Background:  #f0f2f5 (Cloud White)                                         │
│ Surface:     #ffffff (Pure White)                                          │
│ Primary:     #0066cc (Deep Blue)                                           │
│ Text:        #1a1a2e (Dark Navy)                                           │
│                                                                             │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ ◈ MISSION CONTROL                                    ● PWR ● NET   │    │
│ │ ┌─────────────────────────────────────────────────────────────────┐│    │
│ │ │ DATABASE_FAILOVER                                   ◐ SEMI      ││    │
│ │ │ ▰▰▰▰▰▰▰▰▱▱ 85%                                                  ││    │
│ │ └─────────────────────────────────────────────────────────────────┘│    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ THEME: RETRO GREEN (CRT emulation)                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Background:  #0a0a0a (Pure Black)                                          │
│ Surface:     #0f0f0f (Near Black)                                          │
│ Primary:     #00ff00 (Phosphor Green)                                      │
│ Text:        #00cc00 (Screen Green)                                        │
│ + Scanline overlay                                                          │
│ + CRT curvature effect                                                      │
│ + Phosphor glow                                                             │
│                                                                             │
│ ┌─────────────────────────────────────────────────────────────────────┐    │
│ │ > MISSION CONTROL                                   [PWR] [NET]    │    │
│ │ ┌─────────────────────────────────────────────────────────────────┐│    │
│ │ │ DATABASE_FAILOVER                                  [SEMI]       ││    │
│ │ │ [========  ] 85%                                                ││    │
│ │ └─────────────────────────────────────────────────────────────────┘│    │
│ └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ THEME: HIGH CONTRAST (accessibility)                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ Background:  #000000 (True Black)                                          │
│ Surface:     #000000 (True Black)                                          │
│ Primary:     #ffff00 (Yellow)                                              │
│ Text:        #ffffff (True White)                                          │
│ Borders:     #ffffff (True White, 2px)                                     │
│                                                                             │
│ ╔═════════════════════════════════════════════════════════════════════╗    │
│ ║ ◈ MISSION CONTROL                                    ● PWR ● NET   ║    │
│ ║ ╔═════════════════════════════════════════════════════════════════╗║    │
│ ║ ║ DATABASE_FAILOVER                                   ◐ SEMI      ║║    │
│ ║ ║ ████████░░ 85%                                                  ║║    │
│ ║ ╚═════════════════════════════════════════════════════════════════╝║    │
│ ╚═════════════════════════════════════════════════════════════════════╝    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 11: DATA STATES

## Empty States
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ EMPTY STATES                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NO DATA (initial)                                                           │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │                              ◇                                        │  │
│ │                                                                       │  │
│ │                     No runbooks yet                                   │  │
│ │                                                                       │  │
│ │              Create your first runbook to get started                 │  │
│ │                                                                       │  │
│ │                    [+ Create Runbook]                                 │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ NO RESULTS (search)                                                         │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │                              ◌                                        │  │
│ │                                                                       │  │
│ │              No runbooks match "xyzabc"                               │  │
│ │                                                                       │  │
│ │              Try different keywords or                                │  │
│ │              [Clear Search]                                           │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ ERROR STATE                                                                 │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │                              ✗                                        │  │
│ │                                                                       │  │
│ │              Failed to load runbooks                                  │  │
│ │                                                                       │  │
│ │              Connection error: timeout after 30s                      │  │
│ │                                                                       │  │
│ │                    [Retry]  [Report Issue]                            │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ OFFLINE STATE                                                               │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │                              ⊗                                        │  │
│ │                                                                       │  │
│ │              You're offline                                           │  │
│ │                                                                       │  │
│ │              Showing cached data from 5 min ago                       │  │
│ │                                                                       │  │
│ │                    [Retry Connection]                                 │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Loading States
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LOADING STATES                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ INITIAL LOAD (full page)                                                    │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │                                                                       │  │
│ │                              ◐                                        │  │
│ │                                                                       │  │
│ │                     Loading runbooks...                               │  │
│ │                                                                       │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ SKELETON LOADING (preserves layout)                                         │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                           │  │  │
│ │ │ ░░░░░░░░░░░░░░░░░░░░░                                           │  │  │
│ │ │ ░░░░░░░░░░░░░                                                   │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                           │  │  │
│ │ │ ░░░░░░░░░░░░░░░░░░░░░                                           │  │  │
│ │ │ ░░░░░░░░░░░░░                                                   │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ INLINE LOADING (within element)                                             │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ DATABASE_FAILOVER                                    ◐ Executing...  │  │
│ │ ░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ BUTTON LOADING                                                              │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ [◐ Saving...]  ← Spinner replaces icon, text changes                 │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ INCREMENTAL LOADING (streaming)                                             │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ DATABASE_FAILOVER               ◈                                    │  │
│ │ REDIS_RESTART                   ◈                                    │  │
│ │ POD_AUTOSCALE                   ◈                                    │  │
│ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ← Loading more...                 │  │
│ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                                     │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Validation States
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FORM VALIDATION                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ PRISTINE (untouched)                                                        │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Runbook Name                                                          │  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │                                                                 │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ VALID (passes validation)                                                   │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Runbook Name                                              ✓          │  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │ DATABASE_FAILOVER_V2                                            │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ │ ✓ Name is unique and valid                                           │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ INVALID (fails validation)                                                  │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Runbook Name                                              ✗          │  │
│ │ ╔═════════════════════════════════════════════════════════════════╗  │  │
│ │ ║ DATABASE FAILOVER                                               ║  │  │
│ │ ╚═════════════════════════════════════════════════════════════════╝  │  │
│ │ ✗ Name cannot contain spaces. Use underscores instead.              │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ VALIDATING (async check)                                                    │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Runbook Name                                              ◐          │  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │ DATABASE_FAILOVER_V2                                            │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ │ ◐ Checking if name is unique...                                      │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│ WARNING (valid but concerning)                                              │
│ ┌───────────────────────────────────────────────────────────────────────┐  │
│ │ Timeout (seconds)                                         ⚠          │  │
│ │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│ │ │ 3600                                                            │  │  │
│ │ └─────────────────────────────────────────────────────────────────┘  │  │
│ │ ⚠ Timeout of 1 hour is unusually long. Are you sure?                │  │
│ └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# DIMENSION 12: ICONOGRAPHY

## Icon System
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STATUS ICONS                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ SYSTEM STATUS                                                               │
│ ●  Nominal/Online/Active          ◈  Ready/Standby                         │
│ ◐  Warning/Degraded               ◇  Idle/Inactive                         │
│ ○  Critical/Error                 ◌  Unknown/Loading                       │
│ ⊗  Offline/Disabled               ⊘  Blocked/Unavailable                   │
│                                                                             │
│ EXECUTION STATUS                                                            │
│ ○  Pending/Not started            ◎  Executing/In progress                 │
│ ✓  Complete/Success               ✗  Failed/Error                          │
│ ⏭  Skipped                        ⊗  Blocked                               │
│ ◈  Armed                          ◉  Engaging                              │
│                                                                             │
│ PRIORITY/SEVERITY                                                           │
│ ▲  High priority                  ▼  Low priority                          │
│ ◆  Critical                       ◇  Normal                                │
│ ⚠  Warning                        ◈  Info                                  │
│                                                                             │
│ AUTOMATION LEVEL                                                            │
│ ●  Full Auto                      ◐  Semi-Auto                             │
│ ○  Manual                         ◌  Conditional                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ ACTION ICONS                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ NAVIGATION                                                                  │
│ ◀  Back                           ▶  Forward/Next                          │
│ ▲  Up/Previous                    ▼  Down/Next                             │
│ ◁  Collapse                       ▷  Expand                                │
│ ⌂  Home                           ↩  Return                                │
│                                                                             │
│ OPERATIONS                                                                  │
│ ▷  Play/Execute                   ‖  Pause                                 │
│ ■  Stop                           ↻  Refresh/Retry                         │
│ +  Add/New                        ✕  Close/Remove                          │
│ ✎  Edit                           ⚙  Settings                              │
│                                                                             │
│ DATA                                                                        │
│ ↑  Upload/Export                  ↓  Download/Import                       │
│ ⟳  Sync                           ◎  Filter                                │
│ ⌕  Search                         ≡  Menu/List                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ CATEGORY ICONS                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ RUNBOOK CATEGORIES                                                          │
│ ◆  Recovery operations            ◇  Scaling operations                    │
│ ▶  Deployment operations          ◈  Security operations                   │
│ ◎  Diagnostic operations          ▣  Maintenance operations                │
│                                                                             │
│ RESOURCE TYPES                                                              │
│ ⬡  Database                       ⬢  Cache                                 │
│ ◉  Container/Pod                  ◎  Service                               │
│ ▣  Storage                        ◈  Network                               │
│ ⚡  Function                       ◇  Queue                                 │
│                                                                             │
│ AEROSPACE                                                                   │
│ ◈  Command center                 ▷  Launch/Execute                        │
│ ◎  Orbit/Status                   ◆  Impact/Chaos                          │
│ ◇  Telemetry                      ▣  Archive/Log                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ PROGRESS INDICATORS                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ BAR SEGMENTS                                                                │
│ ▰  Filled segment                 ▱  Empty segment                         │
│ ░  Light fill (10-25%)            ▒  Medium fill (25-75%)                  │
│ ▓  Heavy fill (75-100%)           █  Full block                            │
│                                                                             │
│ SPINNERS                                                                    │
│ ◐ ◓ ◑ ◒  (rotating sequence)                                               │
│ ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏  (braille spinner)                                    │
│ ─ ╲ │ ╱  (line spinner)                                                    │
│                                                                             │
│ CHARTS                                                                      │
│ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █  (bar chart levels)                                        │
│ ╭ ─ ╮ │ ╰ ╯ ╱ ╲  (line chart)                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Icon States
```
┌─────────────────────────────────────────────────────────────────────────────┐
│ ICON VISUAL STATES                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ IDLE              ◇     Normal color, normal opacity                       │
│ HOVER             ◇     Brighter, slight scale (1.1x)                      │
│ ACTIVE            ◆     Filled/inverted                                    │
│ DISABLED          ◇     Dimmed (50% opacity)                               │
│ LOADING           ◐     Animated spin                                      │
│                                                                             │
│ SEMANTIC COLORS APPLIED:                                                    │
│                                                                             │
│ Default (blue):   ◇     #00afff                                            │
│ Success (green):  ◇     #00ff88                                            │
│ Warning (amber):  ◇     #ffaa00                                            │
│ Error (red):      ◇     #ff4444                                            │
│ Neutral (gray):   ◇     #666677                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# COMPLETE COMPONENT CATALOG

## Summary Matrix
```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ COMPONENT INVENTORY                                                                │
├────────────────────┬─────────┬────────┬────────┬────────┬────────┬────────────────┤
│ Component          │ Variants│ States │ Sizes  │ Themes │ A11y   │ Animations     │
├────────────────────┼─────────┼────────┼────────┼────────┼────────┼────────────────┤
│ Tab Bar            │    3    │   5    │   3    │   4    │  ✓     │ 2 (select/hover)│
│ Sidebar            │    2    │   4    │   2    │   4    │  ✓     │ 1 (expand)     │
│ Breadcrumb         │    2    │   3    │   2    │   4    │  ✓     │ 0              │
│ Quick Launch       │    2    │   6    │   2    │   4    │  ✓     │ 2              │
│ Status Light       │    3    │   5    │   3    │   4    │  ✓     │ 3 (pulse)      │
│ Gauge              │    3    │   4    │   3    │   4    │  ✓     │ 1 (fill)       │
│ Sparkline          │    2    │   2    │   2    │   4    │  ✓     │ 1 (draw)       │
│ Timer              │    3    │   4    │   3    │   4    │  ✓     │ 2 (tick/blink) │
│ Data Table         │    4    │   7    │   3    │   4    │  ✓     │ 3              │
│ Tree Table         │    2    │   5    │   3    │   4    │  ✓     │ 2 (expand)     │
│ Card               │    4    │   6    │   3    │   4    │  ✓     │ 3              │
│ Metric Card        │    3    │   4    │   3    │   4    │  ✓     │ 2              │
│ Line Chart         │    3    │   3    │   3    │   4    │  ✓     │ 2 (draw/update)│
│ Bar Chart          │    2    │   3    │   3    │   4    │  ✓     │ 1 (grow)       │
│ Search             │    2    │   5    │   2    │   4    │  ✓     │ 2              │
│ Command Palette    │    1    │   4    │   2    │   4    │  ✓     │ 2 (open/close) │
│ Button             │    5    │   5    │   3    │   4    │  ✓     │ 2              │
│ Toggle             │    2    │   3    │   2    │   4    │  ✓     │ 1              │
│ Modal              │    4    │   4    │   3    │   4    │  ✓     │ 2 (open/close) │
│ ARM & FIRE Modal   │    1    │   5    │   2    │   4    │  ✓     │ 5 (complex)    │
│ Toast              │    4    │   3    │   2    │   4    │  ✓     │ 2 (in/out)     │
│ Alert              │    4    │   2    │   2    │   4    │  ✓     │ 1              │
│ Progress Bar       │    3    │   4    │   3    │   4    │  ✓     │ 2              │
│ Spinner            │    3    │   3    │   3    │   4    │  ✓     │ 1 (spin)       │
│ Step Progress      │    2    │   6    │   2    │   4    │  ✓     │ 2              │
│ Log Stream         │    3    │   3    │   2    │   4    │  ✓     │ 1 (scroll)     │
│ Timeline           │    2    │   2    │   2    │   4    │  ✓     │ 1              │
│ Diff View          │    2    │   2    │   2    │   4    │  ✓     │ 0              │
│ Keyboard Hints     │    3    │   2    │   2    │   4    │  ✓     │ 1              │
├────────────────────┼─────────┼────────┼────────┼────────┼────────┼────────────────┤
│ TOTALS             │   77    │  117   │   72   │  116   │  29/29 │ 48             │
└────────────────────┴─────────┴────────┴────────┴────────┴────────┴────────────────┘
```

---

## DOCUMENT CONTROL

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.0 | 2025-12-30 | Claude | Complete 12-dimension taxonomy |

---

## APPENDIX: tview COMPONENT MAPPING

| Aerospace Component | tview Primitive | GPU Enhancement |
|--------------------|-----------------|-----------------|
| Tab Bar | tview.Flex + tview.Button | Glow on selection |
| Sidebar | tview.List | Hover highlight |
| Data Table | tview.Table | Row hover glow |
| Tree Table | tview.TreeView | Expand animation |
| Card | tview.Frame | Border glow |
| Modal | tview.Modal | Backdrop blur |
| ARM & FIRE | tview.Modal + custom | Progress gradient |
| Search | tview.InputField | Focus glow |
| Progress Bar | tview.TextView | Gradient fill |
| Log Stream | tview.TextView | Scroll fade |
| Chart | tview.TextView (ASCII) | Color gradients |
| Toast | tview.Modal | Slide animation |
| Status Light | Custom draw | Pulse animation |
| Timer | tview.TextView | Digit flip |
