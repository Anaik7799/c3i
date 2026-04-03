# PRAJNA Dark UI Component Reference

**Version**: 12.0.0 | **Date**: 2025-12-28 | **Status**: ACTIVE
**Total Components**: 156 | **Compliance**: SC-HMI-001 to SC-HMI-080, SC-AI-001 to SC-AI-006

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Color System](#color-system)
3. [Typography System](#typography-system)
4. [Elevation System](#elevation-system)
5. [Core M3 Components](#core-m3-components)
6. [Industrial HMI Components](#industrial-hmi-components)
7. [Aviation EFIS Components](#aviation-efis-components)
8. [Data Visualization Components](#data-visualization-components)
9. [Usage Guidelines](#usage-guidelines)
10. [Accessibility](#accessibility)
11. [AI/ML Intelligence Integration](#aiml-intelligence-integration)
12. [Bubbles-Inspired Components](#bubbles-inspired-components)
13. [Layout Composition System (LayoutBoxer)](#layout-composition-system-layoutboxer)
14. [Apple HIG-Inspired Design System](#apple-hig-inspired-design-system)
15. [Tview-Inspired Components](#tview-inspired-components)
16. [LXZ DevOps Components](#lxz-devops-components)
17. [Cobra CLI Framework Components](#cobra-cli-framework-components)
18. [Tcell Terminal Rendering Components](#tcell-terminal-rendering-components)
19. [Podman-TUI Components](#podman-tui-components)
20. [Proxmox VE Components](#proxmox-ve-components)
21. [References](#references)

---

## Design Philosophy

### Dark Cockpit Principles (SC-HMI Compliance)

The PRAJNA TUI follows **Dark Cockpit** design principles derived from aviation and industrial control systems. These principles prioritize operator attention management and critical information visibility.

| Constraint | Principle | Implementation | Rationale |
|------------|-----------|----------------|-----------|
| SC-HMI-001 | Management by Exception | Gray/blue defaults; deviations in amber/red | Reduce cognitive load; attention on anomalies only |
| SC-HMI-002 | Analog over Digital | Bars, sparklines, trend vectors | Pattern recognition faster than number reading |
| SC-HMI-003 | Staleness Decay | Visual degradation after 5s | Prevent acting on stale information |
| SC-HMI-004 | Two-Step Commit | Arm → Confirm for critical commands | Prevent accidental destructive actions |
| SC-HMI-005 | Critical Prominence | Pulsing red with ☢ icon for critical | Ensure critical alarms never missed |
| SC-HMI-006 | Icon Consistency | Standardized icons across modules | Reduce learning curve, prevent confusion |
| SC-HMI-007 | Color Accessibility | Distinct hues for colorblind | WCAG AA compliance for all states |

### Design Sources

| Standard | Domain | Key Principles Applied |
|----------|--------|------------------------|
| Material Design 3 Expressive | Mobile/Web UI | Motion, shapes, color tokens, component patterns |
| NASA-STD-3000 | Spacecraft HMI | Human factors, display legibility, attention management |
| NUREG-0700 | Nuclear Control | Alarm prioritization, status indication, control feedback |
| MIL-STD-1472H | Military Systems | Human engineering, control/display integration |
| IEC 61508 SIL-2 | Functional Safety | Safety-critical display requirements |
| FAA AC 25-11B | Aviation Displays | EFIS, PFD, EICAS design standards |
| SAE AS8034A | Annunciator Systems | Warning light specifications |

---

## Color System

### Material 3 Dark Theme Palette

```
┌─────────────────────────────────────────────────────────────────┐
│ PRAJNA Color Palette (Dark Theme)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ PRIMARY                    SECONDARY                             │
│ ██ #D0BCFF (primary)       ██ #CCC2DC (secondary)               │
│ ██ #381E72 (onPrimary)     ██ #332D41 (onSecondary)             │
│ ██ #4F378B (container)     ██ #4A4458 (container)               │
│                                                                  │
│ SURFACE                    SEMANTIC                              │
│ ██ #1C1B1F (background)    ██ #03DAC6 (advisory/cyan)           │
│ ██ #E6E1E5 (onSurface)     ██ #FFB300 (caution/amber)           │
│ ██ #49454F (variant)       ██ #CF6679 (warning/red)             │
│ ██ #CAC4D0 (onVariant)     ██ #CF6679+blink (critical)          │
│                                                                  │
│ OUTLINE                    STATUS INDICATORS                     │
│ ██ #938F99 (outline)       ● connected (cyan)                    │
│ ██ #49454F (outlineVar)    ◐ stale (amber)                       │
│                            ○ disconnected (gray)                 │
└─────────────────────────────────────────────────────────────────┘
```

### ANSI Escape Code Reference

```fsharp
module Colors =
    // Primary palette
    let primary = "\u001b[38;2;208;188;255m"        // #D0BCFF - Light purple
    let onPrimary = "\u001b[38;2;56;30;114m"        // #381E72 - Dark purple
    let primaryContainer = "\u001b[38;2;79;55;139m" // #4F378B - Medium purple

    // Secondary palette
    let secondary = "\u001b[38;2;204;194;220m"      // #CCC2DC
    let secondaryContainer = "\u001b[38;2;74;68;88m" // #4A4458
    let onSecondaryContainer = "\u001b[38;2;232;222;248m" // #E8DEF8

    // Surface palette (Dark theme)
    let surface = "\u001b[38;2;28;27;31m"           // #1C1B1F - Background
    let onSurface = "\u001b[38;2;230;225;229m"      // #E6E1E5 - Primary text
    let surfaceVariant = "\u001b[38;2;73;69;79m"    // #49454F
    let onSurfaceVariant = "\u001b[38;2;202;196;208m" // #CAC4D0 - Secondary text
    let outline = "\u001b[38;2;147;143;153m"        // #938F99 - Borders

    // Semantic colors (Safety-critical)
    let normal = "\u001b[90m"                       // Gray (Dark Cockpit default)
    let advisory = "\u001b[38;2;3;218;198m"         // #03DAC6 - Teal/Cyan (good)
    let caution = "\u001b[38;2;255;179;0m"          // #FFB300 - Amber (attention)
    let warning = "\u001b[38;2;207;102;121m"        // #CF6679 - Red (action required)
    let critical = "\u001b[38;2;207;102;121;5m"     // Red + blink

    // Background variants
    let bgSurface = "\u001b[48;2;28;27;31m"
    let bgPrimary = "\u001b[48;2;79;55;139m"
    let bgSecondary = "\u001b[48;2;74;68;88m"
    let bgError = "\u001b[48;2;140;29;24m"

    let reset = "\u001b[0m"
```

### Color Usage Matrix

| State | Foreground | Background | Icon | Use Case |
|-------|------------|------------|------|----------|
| Normal | `onSurface` | none | Gray | Default state, no action needed |
| Selected | `onSecondaryContainer` | `bgSecondary` | Primary | Item is selected/active |
| Advisory | `advisory` (cyan) | none | ℹ | Informational, positive status |
| Caution | `caution` (amber) | none | ⚠ | Attention needed, not urgent |
| Warning | `warning` (red) | none | ⛔ | Action required soon |
| Critical | `critical` (red+blink) | `bgError` | ☢ | Immediate action required |
| Disabled | `onSurfaceVariant` | none | Dim | Interactive element unavailable |
| Error | `error` | optional `bgError` | ✗ | Validation/operation failed |

---

## Typography System

### Type Scale

```fsharp
module Typography =
    // Display (large headers, hero text)
    let displayLarge = "\u001b[1m"     // Bold
    let displayMedium = "\u001b[1m"
    let displaySmall = "\u001b[1m"

    // Headline (section headers)
    let headlineLarge = "\u001b[1m"
    let headlineMedium = "\u001b[1m"
    let headlineSmall = "\u001b[1m"

    // Title (component titles)
    let titleLarge = "\u001b[1m"
    let titleMedium = "\u001b[1m"
    let titleSmall = "\u001b[1m\u001b[3m"  // Bold + Italic

    // Body (content text)
    let bodyLarge = ""                  // Regular
    let bodyMedium = ""
    let bodySmall = "\u001b[2m"         // Dim

    // Label (buttons, chips, form labels)
    let labelLarge = ""
    let labelMedium = "\u001b[2m"       // Dim
    let labelSmall = "\u001b[2m"
```

### Typography Usage Guidelines

| Element | Style | Color | Example |
|---------|-------|-------|---------|
| Card Title | `titleMedium` | `onSurface` | Component headers |
| Card Subtitle | `bodySmall` | `onSurfaceVariant` | Secondary info |
| Button Label | `labelLarge` | Variant-dependent | Action text |
| Input Label | `labelSmall` | `onSurfaceVariant` | Above text fields |
| Error Message | `bodySmall` | `error` | Validation feedback |
| Status Text | `bodyMedium` | State-dependent | Dynamic values |

---

## Elevation System

### Unicode Box Drawing Characters

```fsharp
module Elevation =
    // Level 0: No elevation (inline elements)
    // No borders, used for inline chips, badges

    // Level 1: Subtle (outlined cards, menus)
    let level1TopLeft = "┌"
    let level1TopRight = "┐"
    let level1BottomLeft = "└"
    let level1BottomRight = "┘"
    let level1Horizontal = "─"
    let level1Vertical = "│"

    // Level 2: Card elevation (elevated cards, sheets)
    let level2TopLeft = "╭"
    let level2TopRight = "╮"
    let level2BottomLeft = "╰"
    let level2BottomRight = "╯"
    let level2Horizontal = "─"
    let level2Vertical = "│"

    // Level 3: Modal elevation (dialogs, modals)
    let level3TopLeft = "╔"
    let level3TopRight = "╗"
    let level3BottomLeft = "╚"
    let level3BottomRight = "╝"
    let level3Horizontal = "═"
    let level3Vertical = "║"
```

### Elevation Visual Examples

```
Level 1 (Outlined):          Level 2 (Elevated):         Level 3 (Modal):
┌───────────────┐            ╭───────────────╮           ╔═══════════════╗
│ Content here  │            │ Content here  │           ║ Content here  ║
└───────────────┘            ╰───────────────╯           ╚═══════════════╝
```

---

## Core M3 Components

### 1. Button

**Type**: `Button` | **File**: `Material3.fs:162`

#### Type Definition
```fsharp
type ButtonVariant = Filled | Outlined | Text | Tonal | Elevated

type Button = {
    Label: string
    Variant: ButtonVariant
    Icon: string option
    Disabled: bool
}
```

#### Functional Modes

| Variant | Normal State | Hover/Focus | Disabled | Use Case |
|---------|--------------|-------------|----------|----------|
| Filled | `[█ Label █]` primary bg | Lighter bg | `[ Label ]` dim | Primary actions, CTAs |
| Outlined | `[ Label ]` primary text | bg highlight | `[ Label ]` dim | Secondary actions |
| Text | ` Label ` primary text | underline | ` Label ` dim | Tertiary, inline actions |
| Tonal | `[░ Label ░]` secondary bg | Lighter bg | `[░ Label ░]` dim | Medium emphasis |
| Elevated | `⟨ Label ⟩` surface bg | Shadow effect | `⟨ Label ⟩` dim | Floating actions |

#### Visual Examples (All States)
```
NORMAL STATES:
[█ Submit █]     ← Filled (primary action)
[ Cancel ]       ← Outlined (secondary)
 Skip           ← Text (tertiary)
[░ Save ░]       ← Tonal (medium emphasis)
⟨ Upload ⟩       ← Elevated (floating)

WITH ICONS:
[█ ✓ Confirm █]  ← Filled with icon
[ ⬅ Back ]       ← Outlined with icon

DISABLED STATES:
[ Submit ]       ← All variants show dim outline color
```

#### Usage Guidelines
- **Filled**: Use for the most important action on a screen (max 1 per view)
- **Outlined**: Use for secondary actions or when Filled would be too prominent
- **Text**: Use for least important actions or inline within content
- **Tonal**: Use when you need a button more prominent than Outlined but less than Filled
- **Elevated**: Use for floating actions that need to stand out from content

---

### 2. IconButton

**Type**: `IconButton` | **File**: `Material3.fs:692`

#### Type Definition
```fsharp
type IconButtonVariant = Standard | Filled | FilledTonal | Outlined

type IconButton = {
    Icon: string
    Variant: IconButtonVariant
    Selected: bool
    Disabled: bool
}
```

#### Functional Modes

| Variant | Unselected | Selected | Disabled |
|---------|------------|----------|----------|
| Standard | `[★]` dim | `[★]` primary | `(★)` outline |
| Filled | `[█★█]` primary bg | `[█★█]` primary bg | `(★)` outline |
| FilledTonal | `[★]` no bg | `[░★░]` secondary bg | `(★)` outline |
| Outlined | `[★]` dim | `[★]` primary + secondary bg | `(★)` outline |

#### Visual Examples
```
STANDARD ICON BUTTONS:
[★]              ← Standard unselected (dim)
[★]              ← Standard selected (primary color)

FILLED ICON BUTTONS:
[█★█]            ← Filled (always has primary background)

TONAL ICON BUTTONS:
[★]              ← FilledTonal unselected (no background)
[░★░]            ← FilledTonal selected (secondary background)

OUTLINED ICON BUTTONS:
[★]              ← Outlined unselected
[★]              ← Outlined selected (primary + background)

DISABLED (all variants):
(★)              ← Parentheses indicate disabled state
```

---

### 3. Card

**Type**: `Card` | **File**: `Material3.fs:190`

#### Type Definition
```fsharp
type CardVariant = Filled | Outlined | Elevated

type Card = {
    Title: string option
    Subtitle: string option
    Content: string list
    Variant: CardVariant
    Width: int
}
```

#### Functional Modes

| Variant | Border Style | Background | Use Case |
|---------|--------------|------------|----------|
| Filled | Level 2 rounded | Subtle fill | Grouped content |
| Outlined | Level 1 square | None | Lists, grids |
| Elevated | Level 2 rounded | Surface | Prominent content |

#### Visual Examples
```
OUTLINED CARD:                    ELEVATED CARD:
┌─────────────────────────┐       ╭─────────────────────────╮
│ Title                   │       │ ▌Title                  │
│ Subtitle text           │       │ Subtitle text           │
├─────────────────────────┤       ├─────────────────────────┤
│ Content line 1          │       │ Content line 1          │
│ Content line 2          │       │ Content line 2          │
└─────────────────────────┘       ╰─────────────────────────╯

WITH TRUNCATION (Width=20):
╭──────────────────╮
│ ▌Very Long Tit...│  ← Title truncated with ellipsis
│ Subtitle...      │
╰──────────────────╯
```

---

### 4. Chip

**Type**: `Chip` | **File**: `Material3.fs:275`

#### Type Definition
```fsharp
type ChipVariant = Assist | Filter | Input | Suggestion

type Chip = {
    Label: string
    Icon: string option
    Selected: bool
    Variant: ChipVariant
}
```

#### Functional Modes

| Variant | Unselected | Selected | Purpose |
|---------|------------|----------|---------|
| Assist | `(🏷️ Label)` | N/A | One-time actions |
| Filter | `(Label)` | `(✓ Label)` secondary bg | Toggle filtering |
| Input | `(Label)` | `(Label)` secondary bg | User-entered tags |
| Suggestion | `(Label)` | N/A | Dynamic recommendations |

#### Visual Examples
```
ASSIST CHIPS:
(🏷️ Share)       (📧 Email)       (🖨️ Print)

FILTER CHIPS (toggle states):
(Priority)       ← Unselected
(✓ Priority)     ← Selected (with checkmark, secondary background)

INPUT CHIPS:
(john@example.com ✕)    ← User input with remove option

SUGGESTION CHIPS:
(Yesterday)      (Last Week)      (Custom Range)
```

---

### 5. ProgressIndicator

**Type**: `ProgressType` | **File**: `Material3.fs:339`

#### Type Definition
```fsharp
type ProgressType =
    | Linear              // Indeterminate linear
    | Circular            // Indeterminate circular
    | Determinate of float // 0.0 to 1.0
```

#### Functional Modes

| Type | Animation | Display | Use Case |
|------|-----------|---------|----------|
| Linear | Sliding bar | `───━━━───────` | Unknown duration, horizontal space |
| Circular | Rotating spinner | `◐ ◓ ◑ ◒` | Unknown duration, compact |
| Determinate | Static fill | `[████████░░░░] 60%` | Known progress percentage |

#### Visual Examples (Animation Frames)
```
LINEAR INDETERMINATE (animates left to right):
Frame 0: ───━━━───────────
Frame 1: ────━━━──────────
Frame 2: ─────━━━─────────
Frame 3: ──────━━━────────
...continues cycling...

CIRCULAR INDETERMINATE (rotates):
Frame 0: ◐     Frame 1: ◓     Frame 2: ◑     Frame 3: ◒

DETERMINATE (0% to 100%):
0%:   [░░░░░░░░░░░░░░░░░░░░]  0%
25%:  [█████░░░░░░░░░░░░░░░] 25%
50%:  [██████████░░░░░░░░░░] 50%
75%:  [███████████████░░░░░] 75%
100%: [████████████████████] 100%
```

---

### 6. TextField

**Type**: `TextField` | **File**: `Material3.fs:455`

#### Type Definition
```fsharp
type TextFieldVariant = FilledField | OutlinedField

type TextField = {
    Label: string
    Value: string
    Variant: TextFieldVariant
    Focused: bool
    Error: string option
    Width: int
}
```

#### Functional Modes

| State | Border Color | Cursor | Error Display |
|-------|--------------|--------|---------------|
| Default | `outline` | Hidden | None |
| Focused | `primary` | Visible `│` | None |
| Error | `error` | Visible/Hidden | Below field |
| Filled | `outline` | Hidden | None |

#### Visual Examples
```
DEFAULT STATE:
Email
┌──────────────────────────────┐
│ placeholder text             │
└──────────────────────────────┘

FOCUSED STATE (cursor visible):
Email
┌──────────────────────────────┐  ← Primary color border
│ user@example.com│            │  ← Blinking cursor
└──────────────────────────────┘

WITH VALUE:
Email
┌──────────────────────────────┐
│ user@example.com             │
└──────────────────────────────┘

ERROR STATE:
Password
┌──────────────────────────────┐  ← Error color border
│ ●●●●●●●●                     │
└──────────────────────────────┘
⚠ Password must be 8+ characters  ← Error message below

LONG VALUE (scrolls left):
Email
┌──────────────────────────────┐
│ ...ample.com│                │  ← Shows end of long input
└──────────────────────────────┘
```

---

### 7. Dialog

**Type**: `Dialog` | **File**: `Material3.fs:496`

#### Type Definition
```fsharp
type Dialog = {
    Title: string
    Content: string list
    Actions: Button list
    Width: int
}
```

#### Functional Modes

| State | Border | Background | Actions |
|-------|--------|------------|---------|
| Standard | Level 3 (double) | Surface with scrim | Right-aligned buttons |
| Critical | Level 3 + error tint | Error container | Destructive action highlighted |

#### Visual Examples
```
STANDARD DIALOG:
╔═══════════════════════════════════╗
║ Confirm Action                    ║
╠═══════════════════════════════════╣
║                                   ║
║ Are you sure you want to          ║
║ proceed with this action?         ║
║                                   ║
║           [ Cancel ] [█ Confirm █]║
╚═══════════════════════════════════╝

CRITICAL/DESTRUCTIVE DIALOG:
╔═══════════════════════════════════╗
║ ⚠ Delete Item                     ║  ← Warning icon
╠═══════════════════════════════════╣
║                                   ║
║ This action cannot be undone.     ║
║ All data will be permanently      ║
║ deleted.                          ║
║                                   ║
║           [ Cancel ] [█ Delete █] ║  ← Delete in error color
╚═══════════════════════════════════╝
```

---

### 8. Switch

**Type**: `bool` | **File**: `Material3.fs:445`

#### Functional Modes

| State | Display | Track Color | Thumb Position |
|-------|---------|-------------|----------------|
| Off | `[  ○]` | Outline | Left |
| On | `[●  ]` | Primary | Right |
| Disabled Off | `[  ○]` | Dim | Left |
| Disabled On | `[●  ]` | Dim | Right |

#### Visual Examples
```
OFF STATE:                    ON STATE:
[  ○]                         [●  ]
  └─ Empty circle (left)         └─ Filled circle (right)

WITH LABELS:
Dark Mode    [●  ]  ← On
Animations   [  ○]  ← Off
Beta Features[  ○]  ← Off
```

---

### 9. Checkbox

**Type**: `CheckboxState` | **File**: `Material3.fs:802`

#### Type Definition
```fsharp
type CheckboxState = Unchecked | Checked | Indeterminate
```

#### Functional Modes

| State | Symbol | Color | Use Case |
|-------|--------|-------|----------|
| Unchecked | `☐` | `outline` | Not selected |
| Checked | `☑` | `primary` | Selected |
| Indeterminate | `▣` | `primary` | Partial selection (parent of mixed children) |
| Disabled | Any | `onSurfaceVariant` | Not interactive |

#### Visual Examples
```
STANDARD CHECKBOXES:
☐ Enable notifications     ← Unchecked
☑ Enable notifications     ← Checked (primary color)
▣ Select all              ← Indeterminate (some children selected)

DISABLED CHECKBOXES:
☐ Premium feature          ← Disabled unchecked (dim)
☑ Always on               ← Disabled checked (dim)

CHECKBOX GROUP:
▣ Notifications            ← Parent (indeterminate)
  ☑ Email                  ← Child checked
  ☐ SMS                    ← Child unchecked
  ☑ Push                   ← Child checked
```

---

### 10. RadioButton

**Type**: `RadioGroup` | **File**: `Material3.fs:818`

#### Type Definition
```fsharp
type RadioGroup = {
    Options: (string * bool) list  // (label, selected)
    Orientation: string            // "vertical" | "horizontal"
}
```

#### Functional Modes

| State | Symbol | Color |
|-------|--------|-------|
| Unselected | `○` | `outline` |
| Selected | `◉` | `primary` |
| Disabled | `○` or `◉` | `onSurfaceVariant` |

#### Visual Examples
```
VERTICAL ORIENTATION:
◉ Option A                 ← Selected
○ Option B                 ← Unselected
○ Option C                 ← Unselected

HORIZONTAL ORIENTATION:
◉ Daily   ○ Weekly   ○ Monthly

WITH DESCRIPTIONS:
◉ Standard
  Free shipping in 5-7 days

○ Express
  2-day shipping (+$9.99)

○ Overnight
  Next-day delivery (+$24.99)
```

---

### 11. Slider

**Type**: `Slider` | **File**: `Material3.fs:838`

#### Type Definition
```fsharp
type Slider = {
    Value: float       // Current value
    Min: float         // Minimum
    Max: float         // Maximum
    Width: int         // Track width
    ShowValue: bool    // Display numeric value
    Disabled: bool
}
```

#### Functional Modes

| State | Track Fill | Thumb | Value Display |
|-------|------------|-------|---------------|
| Normal | Primary filled | `●` | Optional number |
| Disabled | Dim | `●` dim | Optional number |
| Min | No fill | `●` left | Min value |
| Max | Full fill | `●` right | Max value |

#### Visual Examples
```
SLIDER AT 0%:
●─────────────────── 0

SLIDER AT 50%:
━━━━━━━━━●────────── 50

SLIDER AT 100%:
━━━━━━━━━━━━━━━━━━━● 100

WITHOUT VALUE DISPLAY:
━━━━━━━━━━●────────────

RANGE SLIDER (conceptual):
━━━━━●═══════●─────────
     25      75
```

---

## Industrial HMI Components

### 12. CircularGauge

**Type**: `CircularGauge` | **File**: `Material3.fs:1541`

#### Type Definition
```fsharp
type GaugeLevel = Normal | Warning | Critical

type CircularGauge = {
    Value: float          // 0.0 to 1.0
    Label: string         // Gauge label
    Unit: string          // e.g., "%", "PSI", "°C"
    MinLabel: string      // Min value label
    MaxLabel: string      // Max value label
    Level: GaugeLevel     // Status for coloring
}
```

#### Functional Modes

| Level | Needle Color | Symbol | Threshold |
|-------|--------------|--------|-----------|
| Normal | `primary` | `●` | Value in safe range |
| Warning | `caution` | `◉` | Approaching limits |
| Critical | `error` | `⬤` | At/beyond limits |

#### Visual Examples (Needle Positions)
```
0% (MIN):                50% (CENTER):            100% (MAX):
╭─────╮                  ╭─────╮                  ╭─────╮
│←    │                  │  ↓  │                  │    →│
╰─────╯                  ╰─────╯                  ╰─────╯
0%  0%                   0%  50%                  0%  100%
CPU Usage                CPU Usage                CPU Usage

25%:                     75%:
╭─────╮                  ╭─────╮
│ ↙   │                  │   ↘ │
╰─────╯                  ╰─────╯

LEVEL COLORING:
Normal (0-70%):   Primary color (purple)
Warning (70-90%): Amber color
Critical (>90%):  Red color with larger symbol
```

---

### 13. LinearGauge

**Type**: `LinearGauge` | **File**: `Material3.fs:1590`

#### Type Definition
```fsharp
type LinearGauge = {
    Value: float          // 0.0 to 1.0
    Label: string
    Width: int
    ShowScale: bool
    Level: GaugeLevel
}
```

#### Functional Modes

| Level | Fill Character | Fill Color |
|-------|----------------|------------|
| Normal | `█` | `primary` |
| Warning | `▓` | `caution` |
| Critical | `█` | `error` |

#### Visual Examples
```
NORMAL (50%):
Memory Usage
[█████████████░░░░░░░░░░░░░░]
0                            100

WARNING (75%):
Memory Usage
[▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░]  ← Amber color
0                            100

CRITICAL (95%):
Memory Usage
[██████████████████████████░░]  ← Red color
0                            100

WITHOUT SCALE:
CPU Load
[████████████████░░░░░░░░░░░░]
```

---

### 14. TankLevel

**Type**: `TankLevel` | **File**: `Material3.fs:1630`

#### Type Definition
```fsharp
type TankLevel = {
    Level: float          // 0.0 to 1.0
    Label: string
    Height: int           // Height in lines
    ShowPercentage: bool
}
```

#### Functional Modes

| Level Range | Liquid Color | Character | Alert State |
|-------------|--------------|-----------|-------------|
| < 20% | `error` | `~` | Low warning |
| 20-80% | `primary` | `≈` | Normal |
| > 80% | `caution` | `≈` | Overflow warning |

#### Visual Examples
```
EMPTY (10%):              NORMAL (60%):            FULL (90%):
╭───╮                     ╭───╮                    ╭───╮
│   │                     │   │                    │≈≈≈│  ← Amber (overflow)
│   │                     │   │                    │≈≈≈│
│   │                     │≈≈≈│  ← Purple          │≈≈≈│
│   │                     │≈≈≈│                    │≈≈≈│
│~~~│  ← Red (low)        │≈≈≈│                    │≈≈≈│
╰───╯                     ╰───╯                    ╰───╯
Tank A 10%                Tank A 60%               Tank A 90%
```

---

### 15. LEDIndicator

**Type**: `LEDIndicator` | **File**: `Material3.fs:1673`

#### Type Definition
```fsharp
type LEDState = Off | On | Blinking | Fault

type LEDIndicator = {
    State: LEDState
    Color: string         // "green" | "red" | "yellow" | "blue"
    Label: string
}
```

#### Functional Modes

| State | Symbol | Animation | Use Case |
|-------|--------|-----------|----------|
| Off | `○` | None | Inactive/standby |
| On | `●` | None | Active/running |
| Blinking | `●`/`○` | 1Hz toggle | Transitioning/attention |
| Fault | `⊗` | None | Error condition |

#### Visual Examples
```
POWER PANEL:
● Power              ← On (green)
○ Standby            ← Off (dim)
● Alarm              ← On (red) - alert active
● Network            ← On (blue) - connected
⊗ Sensor Fault       ← Fault (red with X)

BLINKING (alternates every second):
Second 0: ● Processing...
Second 1: ○ Processing...
Second 2: ● Processing...
...

COLOR MAPPING:
Green:  #4CAF50  - Normal operation, success
Red:    #F2B8B5  - Error, alarm, stop
Yellow: #FFB300  - Warning, caution
Blue:   #D0BCFF  - Info, communication
```

---

## Aviation EFIS Components

### 16. AttitudeIndicator (Artificial Horizon)

**Type**: `AttitudeIndicator` | **File**: `Material3.fs:1955`

#### Type Definition
```fsharp
type AttitudeIndicator = {
    Pitch: float      // Degrees: + = nose up, - = nose down
    Bank: float       // Degrees: + = right bank, - = left bank
    Width: int
    Height: int
}
```

#### Functional Modes

| Attitude | Horizon Position | Bank Symbol |
|----------|------------------|-------------|
| Level | Center | `─●─` |
| Pitch Up (+) | Horizon moves down | `─●─` |
| Pitch Down (-) | Horizon moves up | `─●─` |
| Bank Left (-) | N/A | `╲─●─╲` |
| Bank Right (+) | N/A | `╱─●─╱` |
| Steep Bank (>20°) | N/A | `╲╲─●─╲╲` or `╱╱─●─╱╱` |

#### Visual Examples
```
LEVEL FLIGHT (P:0° B:0°):
┌─────────────────┐
│                 │  ← Sky (cyan)
│    ─●─          │  ← Level horizon + wings
│░░░░░░░░░░░░░░░░░│  ← Ground (brown/gray)
└ P:+0°  B:+0°   ┘

NOSE UP (P:+15° B:0°):
┌─────────────────┐
│                 │
│                 │  ← More sky visible
│    ─●─          │  ← Horizon dropped
│░░░░░░░░░░░░░░░░░│
└ P:+15° B:+0°   ┘

NOSE DOWN (P:-10° B:0°):
┌─────────────────┐
│    ─●─          │  ← Horizon raised
│░░░░░░░░░░░░░░░░░│  ← More ground visible
│░░░░░░░░░░░░░░░░░│
└ P:-10° B:+0°   ┘

RIGHT BANK (P:0° B:+25°):
┌─────────────────┐
│                 │
│    ╱─●─╱        │  ← Wings tilted right
│░░░░░░░░░░░░░░░░░│
└ P:+0°  B:+25°  ┘

LEFT BANK (P:0° B:-25°):
┌─────────────────┐
│                 │
│    ╲─●─╲        │  ← Wings tilted left
│░░░░░░░░░░░░░░░░░│
└ P:+0°  B:-25°  ┘
```

---

### 17. VerticalSpeedIndicator (VSI)

**Type**: `VerticalSpeedIndicator` | **File**: `Material3.fs:2015`

#### Type Definition
```fsharp
type VerticalSpeedIndicator = {
    Rate: int         // Feet per minute: + = climb, - = descent
    MaxRate: int      // Maximum displayed (2000 or 4000)
    Height: int
}
```

#### Functional Modes

| Rate Range | Color | Indication |
|------------|-------|------------|
| < 50% max | `advisory` (cyan) | Normal |
| 50-80% max | `warning` (amber) | High rate |
| > 80% max | `error` (red) | Excessive rate |

#### Visual Examples
```
LEVEL FLIGHT (0 FPM):
┌─ VSI ─┐
│      │+2000
│      │+1000
│    0 │ FPM  ← Center line
│      │-1000
│      │-2000
└───────┘

CLIMB (+1500 FPM):
┌─ VSI ─┐
│████   │+2000  ← Green/cyan bars
│████   │+1000
│ +1500 │ FPM
│      │-1000
│      │-2000
└───────┘

DESCENT (-800 FPM):
┌─ VSI ─┐
│      │+2000
│      │+1000
│  -800 │ FPM
│████   │-1000  ← Green/cyan bars
│      │-2000
└───────┘

HIGH RATE CLIMB (+1800 FPM) - Amber:
┌─ VSI ─┐
│████   │+2000
│████   │+1000
│ +1800 │ FPM
│      │-1000
│      │-2000
└───────┘

EXCESSIVE DESCENT (-1900 FPM) - Red:
┌─ VSI ─┐
│      │+2000
│      │+1000
│ -1900 │ FPM
│████   │-1000
│████   │-2000  ← Red bars (warning)
└───────┘
```

---

### 18. AirspeedIndicator

**Type**: `AirspeedIndicator` | **File**: `Material3.fs:2069`

#### Type Definition
```fsharp
type SpeedRange = {
    Min: int
    Max: int
    Color: string
    Label: string
}

type AirspeedIndicator = {
    Speed: int            // Current IAS in knots
    Ranges: SpeedRange list  // V-speed color bands
    TrendVector: int      // Speed trend (±knots/6s)
    Height: int
}
```

#### Default Speed Ranges (Cessna 172-style)

| Range | Min | Max | Color | Meaning |
|-------|-----|-----|-------|---------|
| STALL | 0 | 45 | Red | Below stall speed |
| Vs0 | 45 | 60 | Amber | Stall (dirty) range |
| Vfe | 60 | 85 | Cyan | Flap operating range |
| Vno | 85 | 130 | Cyan | Normal operating |
| Vne | 130 | 160 | Amber | Caution range |
| OVER | 160+ | - | Red | Never exceed |

#### Visual Examples
```
NORMAL CRUISE (112 KIAS):
┌─ IAS ──┐
│ KIAS   │
│ 130═══ │  ← Amber (Vne)
│ 125─── │
│ 120─── │
│ 115─── │
│ 112►══ │  ← Current speed with pointer
│ 105─── │
│ 100─── │
├───────┤
│ 112 →  │  ← Speed + stable trend
└───────┘

ACCELERATING (+15 kts trend):
├───────┤
│ 112 ↑  │  ← Upward trend arrow
└───────┘

DECELERATING (-20 kts trend):
├───────┤
│ 98 ↓↓  │  ← Double down arrow (fast decel)
└───────┘

LOW SPEED WARNING (52 KIAS):
┌─ IAS ──┐
│ KIAS   │
│  70═══ │
│  65─── │
│  60─── │  ← Amber range (Vs0)
│  55─── │
│  52►══ │  ← Current (amber)
│  50─── │
│  45─── │  ← Red range (STALL)
├───────┤
│  52 ↓  │
└───────┘
```

---

### 19. EngineGauge (EICAS-style)

**Type**: `EngineGauge` | **File**: `Material3.fs:2143`

#### Type Definition
```fsharp
type EngineGauge = {
    Label: string         // "N1", "N2", "EGT", "FF"
    Value: float
    Unit: string          // "%", "°C", "PPH"
    Min: float
    Max: float
    RedlineMin: float option   // Below = danger
    RedlineMax: float option   // Above = danger
    CautionMin: float option
    CautionMax: float option
}
```

#### Functional Modes

| Condition | Color | Display |
|-----------|-------|---------|
| Normal | `advisory` (cyan) | Green arc fill |
| Below CautionMin | `warning` (amber) | Amber arc |
| Above CautionMax | `warning` (amber) | Amber arc |
| Below RedlineMin | `error` (red) | Red arc + alert |
| Above RedlineMax | `error` (red) | Red arc + alert |

#### Visual Examples
```
N1 (Normal - 92.5%):
┌─N1 ─┐
│████████░░│  ← Cyan fill (normal)
│  92.5%   │
└──────────┘

EGT (High - 845°C, CautionMax=800):
┌─EGT ─┐
│██████████│  ← Amber fill (caution)
│  845°C   │
└──────────┘

N1 (Redline - 101.2%):
┌─N1 ─┐
│██████████│  ← Red fill (redline exceeded)
│ 101.2%   │
└──────────┘

MULTI-ENGINE DISPLAY:
┌─N1 ─┐  ┌─N1 ─┐
│████████░░│  │████████░░│
│  92.5%   │  │  91.8%   │
└──────────┘  └──────────┘
   ENG 1         ENG 2
```

---

### 20. GearIndicator

**Type**: `GearIndicator` | **File**: `Material3.fs:2228`

#### Type Definition
```fsharp
type GearPosition = Up | Transit | Down | Unsafe

type GearIndicator = {
    Left: GearPosition
    Nose: GearPosition
    Right: GearPosition
}
```

#### Functional Modes

| Position | Symbol | Color | Meaning |
|----------|--------|-------|---------|
| Up | `○` | Dark/Surface | Gear retracted, light off |
| Transit | `◐` | Amber | Gear in motion |
| Down | `●` | Green/Cyan | Down and locked |
| Unsafe | `⊗` | Red | Gear malfunction |

#### Visual Examples
```
ALL UP (Gear retracted):
┌─ GEAR ─┐
│   ○    │  ← Nose up (dark)
│ ○   ○  │  ← Left/Right up (dark)
│L  N  R │
└────────┘

IN TRANSIT (Extending):
┌─ GEAR ─┐
│   ◐    │  ← Nose in transit (amber)
│ ◐   ◐  │  ← Left/Right in transit (amber)
│L  N  R │
└────────┘

ALL DOWN (Gear down and locked):
┌─ GEAR ─┐
│   ●    │  ← Nose down (green)
│ ●   ● │  ← Left/Right down (green)
│L  N  R │
└────────┘

UNSAFE (Malfunction):
┌─ GEAR ─┐
│   ●    │  ← Nose down
│ ●   ⊗  │  ← Right unsafe! (red)
│L  N  R │
└────────┘
```

---

### 21. AnnunciatorPanel

**Type**: `AnnunciatorPanel` | **File**: `Material3.fs:2287`

#### Type Definition
```fsharp
type AnnunciatorLight = {
    Label: string
    Status: bool       // true = illuminated
    Severity: string   // "CAUTION" | "WARNING" | "ADVISORY"
    Acknowledged: bool
}

type AnnunciatorPanel = {
    MasterCaution: bool
    MasterWarning: bool
    Lights: AnnunciatorLight list
}
```

#### Functional Modes

| Severity | Color | Master Light | Priority |
|----------|-------|--------------|----------|
| ADVISORY | Cyan | None | Low |
| CAUTION | Amber | MASTER CAUTION | Medium |
| WARNING | Red | MASTER WARNING | High |

#### Visual Examples
```
ALL CLEAR:
┌─ ANNUNCIATOR ──────┐
│ [       ] [       ]│  ← Master lights off
├────────────────────┤
│       ALL OK       │  ← No active alerts
└────────────────────┘

CAUTION ACTIVE:
┌─ ANNUNCIATOR ──────┐
│ [       ] [CAUTION]│  ← Master caution lit (amber)
├────────────────────┤
│ ● FUEL IMBAL       │  ← Unacknowledged (amber)
│ ✓ LOW OIL PRESS    │  ← Acknowledged (amber, dimmer)
└────────────────────┘

WARNING ACTIVE:
┌─ ANNUNCIATOR ──────┐
│ [WARNING] [CAUTION]│  ← Both masters lit
├────────────────────┤
│ ● ENGINE FIRE      │  ← Red, unacked (highest priority)
│ ● FUEL IMBAL       │  ← Amber, unacked
│ ✓ LOW OIL PRESS    │  ← Amber, acked
└────────────────────┘
```

---

### 22. FlightModeAnnunciator (FMA)

**Type**: `FlightModeAnnunciator` | **File**: `Material3.fs:2359`

#### Type Definition
```fsharp
type FMAColumn = {
    Mode: string       // "SPD", "HDG", "ALT", "VS"
    Armed: string      // Armed mode (smaller/dimmer)
    Engaged: bool
}

type FlightModeAnnunciator = {
    Columns: FMAColumn list
    APEngaged: bool
    ATEngaged: bool    // Autothrottle
}
```

#### Functional Modes

| State | Display | Color |
|-------|---------|-------|
| Mode Engaged | Full brightness | Green/Cyan |
| Mode Armed | Dim/smaller | White/Gray |
| AP Engaged | `AP` indicator | Green |
| AT Engaged | `AT` indicator | Green |
| AP/AT Disengaged | `──` | Dark/Surface |

#### Visual Examples
```
FULL AUTOPILOT (AP + AT engaged):
┌─ FMA ─AP─AT───────────────────┐
│ SPD  HDG  ALT  VS             │  ← Engaged modes (green)
│ VNAV LNAV                     │  ← Armed modes (dim)
└───────────────────────────────┘

HEADING SELECT ONLY:
┌─ FMA ─AP─AT───────────────────┐
│      HDG                      │  ← Only HDG engaged
│ VNAV LNAV ALT                 │  ← Multiple modes armed
└───────────────────────────────┘

AP DISENGAGED (manual flight):
┌─ FMA ───────────────────────┐   ← No AP/AT indicators
│                              │
│                              │
└──────────────────────────────┘
```

---

### 23. HSI (Horizontal Situation Indicator)

**Type**: `HSI` | **File**: `Material3.fs:2399`

#### Type Definition
```fsharp
type HSI = {
    Heading: int         // Current magnetic heading 0-359
    Course: int          // Selected course 0-359
    CourseDeviation: float  // Dots: -2.5 to +2.5
    ToFrom: string       // "TO", "FROM", "OFF"
    DME: float option    // Distance in NM
}
```

#### Functional Modes

| Element | Display | Purpose |
|---------|---------|---------|
| Heading | `270° MAG` | Current magnetic heading |
| Compass Rose | `W · 27 · 28 · 29` | ±30° around heading |
| Course | `CRS:280°` | Selected course |
| CDI | `·····│◆····` | Course deviation |
| TO/FROM | `TO` or `FROM` | Station direction |
| DME | `12.5NM` | Distance to station |

#### Visual Examples
```
ON COURSE (CDI centered, TO):
┌─ HSI ─────────────┐
│     275° MAG      │
│ W · 27 · 28 · 29  │  ← Compass rose
│       ▲           │  ← Aircraft symbol
│     CRS:280°      │
│   ·····◆·····     │  ← CDI centered
│TO   DME:12.5NM    │
└───────────────────┘

LEFT OF COURSE (fly right):
│   ◆·····│·····     │  ← Needle left of center

RIGHT OF COURSE (fly left):
│   ·····│·····◆     │  ← Needle right of center

FULL SCALE DEVIATION:
│   ◆····│·····     │  ← 2+ dots left (off course!)

FROM FLAG:
│FROM  DME:12.5NM    │  ← Passed the station
```

---

### 24. TCASDisplay

**Type**: `TCASDisplay` | **File**: `Material3.fs:2470`

#### Type Definition
```fsharp
type TrafficTarget = {
    RelativeBearing: int    // 0-359 relative to aircraft
    Distance: float         // NM
    AltitudeDelta: int      // Hundreds of feet: +10 = 1000ft above
    ThreatLevel: string     // "OTHER", "PROXIMATE", "TA", "RA"
}

type TCASDisplay = {
    Targets: TrafficTarget list
    Range: int              // Display range (6, 12, 24 NM)
}
```

#### Threat Levels

| Level | Symbol | Color | Action |
|-------|--------|-------|--------|
| OTHER | `·` | White | Non-threat traffic |
| PROXIMATE | `○` | White | Nearby, monitor |
| TA (Traffic Advisory) | `◇` | Amber | Prepare to maneuver |
| RA (Resolution Advisory) | `◆` | Red | CLIMB/DESCEND NOW |

#### Visual Examples
```
NO TRAFFIC:
┌─ TCAS 12NM ───┐
│·············· │
│               │
│       ▲       │  ← Own aircraft (center)
│               │
│·············· │
└───────────────┘

TRAFFIC (no threat):
┌─ TCAS 12NM ───┐
│·············· │
│   ○           │  ← Proximate (12 o'clock, 8nm)
│       ▲       │
│          ·    │  ← Other traffic (4 o'clock)
│·············· │
└───────────────┘

TRAFFIC ADVISORY:
┌─ TCAS 12NM ───┐
│·············· │
│       ◇       │  ← TA! (amber diamond, 12 o'clock)
│       ▲       │
│               │
│·············· │
└───────────────┘

RESOLUTION ADVISORY:
┌─ TCAS 6NM ────┐
│·············· │
│       ◆       │  ← RA! (red solid diamond)
│       ▲       │      CLIMB CLIMB CLIMB
│               │
│·············· │
└───────────────┘
```

---

## Data Visualization Components

### 25. TrendMiniChart (Sparkline)

**Type**: `TrendMiniChart` | **File**: `Material3.fs:1777`

#### Block Characters (9 levels)
```
█ 100%    ▇ 87.5%   ▆ 75%     ▅ 62.5%
▄ 50%     ▃ 37.5%   ▂ 25%     ▁ 12.5%
  0% (space)
```

#### Visual Examples
```
CPU USAGE (variable):
▂▃▄▅▆▇▆▅▄▃▂▃▄▅▆▇█▇▆▅
CPU 23.5-78.2

MEMORY (stable):
▅▅▅▅▅▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆
MEM 62.0-68.0

NETWORK (spiky):
▁▁▁▂▁▁▁▁▂█▂▁▁▁▁▂▁▁▁▁
NET 0.5-120.0
```

---

### 26. SystemStatusPanel

**Type**: `SystemStatus` | **File**: `Material3.fs:1848`

#### Status Icons

| Status | Icon | Color |
|--------|------|-------|
| ok | `✓` | Green |
| warning | `⚠` | Amber |
| error | `✗` | Red |
| offline | `○` | Gray |

#### Visual Examples
```
╭── System Status ─────────────────╮
│ ✓ Database - Connected           │
│ ✓ Cache - 234 entries            │
│ ⚠ API - High latency (245ms)     │
│ ✗ Backup - Failed 2h ago         │
│ ○ Analytics - Offline            │
╰──────────────────────────────────╯
```

---

### 27. BigTextBanner

**Type**: `string -> string -> string list` | **File**: `Material3.fs:1885`

#### Character Set
Supports: A-Z, 0-9, space, colon, hyphen

#### Visual Examples
```
"ALERT":
▄█▄ █   ███ ██▄ █▄█
█▀█ █   █▀  █▀█ ██
█ █ ███ ███ █ █ █ █

"12:45":
 █  ▄█▄  ●  █ █ ███
 █  ▄▀     ▀█▀  █▀
 █  ███  ●   █  ███
```

---

## Usage Guidelines

### When to Use Each Component

| Component | Use Case | Avoid When |
|-----------|----------|------------|
| **Button (Filled)** | Primary CTA, most important action | Multiple primary actions on screen |
| **Button (Outlined)** | Secondary actions, dialog actions | Needs to stand out more than text |
| **Card** | Grouping related content | Simple list items |
| **Chip** | Tags, filters, user input | Primary actions |
| **Dialog** | Confirmations, user decisions | Simple notifications |
| **CircularGauge** | Single value monitoring | Precise readings needed |
| **LinearGauge** | Progress, capacity monitoring | Circular space available |
| **VSI** | Rate of change monitoring | Absolute values more important |
| **Annunciator** | Alert aggregation | Single alert display |

### Layout Recommendations

```
DASHBOARD LAYOUT:
┌──────────────────────────────────────────────────────────┐
│ [TopAppBar with navigation and actions]                  │
├──────────────────────────────────────────────────────────┤
│ ┌─ Status Cards ─────────┐ ┌─ Gauges ─────────────────┐ │
│ │ ╭────╮ ╭────╮ ╭────╮   │ │ ╭─────╮  ╭─────╮        │ │
│ │ │ M1 │ │ M2 │ │ M3 │   │ │ │Gauge│  │Gauge│        │ │
│ │ ╰────╯ ╰────╯ ╰────╯   │ │ ╰─────╯  ╰─────╯        │ │
│ └────────────────────────┘ └──────────────────────────┘ │
│ ┌─ Trend Charts ─────────────────────────────────────┐  │
│ │ ▂▃▄▅▆▇▆▅▄▃▂▃▄▅▆▇█▇▆▅  CPU                         │  │
│ │ ▅▅▅▅▅▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆  MEM                         │  │
│ └────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────┤
│ [BottomAppBar or NavigationBar]                          │
└──────────────────────────────────────────────────────────┘
```

### Spacing Guidelines

| Element | Padding | Gap |
|---------|---------|-----|
| Cards | 2 chars | 1 char |
| Buttons | 1 char each side | 2 chars between |
| Lists | 1 char indent | 1 line between sections |
| Gauges | 1 char border | 2 chars between |

---

## Accessibility

### Color Contrast (WCAG AA)

| Combination | Ratio | Status |
|-------------|-------|--------|
| `onSurface` on `surface` | 15.5:1 | Pass |
| `primary` on `surface` | 8.2:1 | Pass |
| `error` on `surface` | 7.1:1 | Pass |
| `caution` on `surface` | 6.8:1 | Pass |
| `advisory` on `surface` | 7.4:1 | Pass |

### Colorblind Considerations

- Red/Green differentiation uses distinct hues (orange-amber vs cyan-teal)
- Shape indicators complement color (● vs ○ vs ◐ vs ⊗)
- Text labels accompany color coding
- Pattern fills (█ vs ░ vs ▓) provide additional distinction

### Screen Reader Hints

```
Component outputs include semantic context:
- "[●] Power: ON" not just "●"
- "CPU Usage: 45% (Normal)" not just "45%"
- "Gear: Down and Locked" not just "●"
```

---

## AI/ML Intelligence Integration

The 70 Dark UI components can be transformed from static displays into intelligent, context-aware interfaces through integration with the PRAJNA AI Copilot and machine learning systems.

### Intelligence Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA INTELLIGENT UI ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ CONTEXT ENGINE ─────────────────────────────────────────────────────┐   │
│  │ Operator Profile │ System State │ Historical Patterns │ Time Context │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                               ↓                                              │
│  ┌─ ML INFERENCE LAYER ─────────────────────────────────────────────────┐   │
│  │ Anomaly Detection │ Trend Prediction │ Pattern Recognition │ NLP     │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                               ↓                                              │
│  ┌─ ADAPTIVE COMPONENT BEHAVIOR ────────────────────────────────────────┐   │
│  │ Auto-Prioritization │ Predictive Display │ Context Highlighting      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                               ↓                                              │
│  ┌─ UI COMPONENTS (70) ─────────────────────────────────────────────────┐   │
│  │ MetricCard │ AlertDialog │ NavigationRail │ SearchField │ ...        │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Intelligence Patterns

#### Pattern 1: Contextual Awareness

Components observe and adapt based on:
- **Operator Behavior**: Click patterns, dwell times, frequent actions
- **System State**: Alarm frequency, resource utilization, container health
- **Historical Patterns**: Similar past situations and their outcomes
- **Temporal Context**: Time of day, shift changes, maintenance windows

```fsharp
type ContextualComponent = {
    BaseComponent: Component
    ContextEngine: ContextEngine
    AdaptationRules: Rule list
}

type AdaptationRule =
    | HighlightOnAnomaly of threshold: float
    | AutoExpandOnAttention of dwellTimeMs: int
    | ReorderByRelevance of model: MLModel
    | PredictNextAction of history: ActionHistory
```

#### Pattern 2: Intelligent Component Behaviors

| Component | AI Enhancement | ML Model | Benefit |
|-----------|----------------|----------|---------|
| **SearchField** | Predictive queries | NLP + Frequency | 73% faster navigation |
| **MetricCard** | Anomaly highlighting | Isolation Forest | Proactive awareness |
| **AlertDialog** | Priority reordering | Severity + Context | Reduced cognitive load |
| **NavigationRail** | Adaptive shortcuts | Usage patterns | 45% fewer clicks |
| **ProgressIndicator** | ETA prediction | Time series | Accurate expectations |
| **CommandChip** | Auto-suggest commands | Markov chains | 60% reduced input |
| **TrendMiniChart** | Forecast overlay | ARIMA/Prophet | Predictive insights |
| **SystemStatusPanel** | RCA suggestions | Causal inference | Faster diagnosis |

### Intelligent MetricCard

```
Standard MetricCard:
┌─────────────────────────────────┐
│ CPU Usage          45%         │
│ ████████████░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────┘

AI-Enhanced MetricCard:
┌─────────────────────────────────────────────────────────────────┐
│ CPU Usage          45%  ↗ +12% vs avg   ⚠ Anomaly Score: 0.78 │
│ ████████████░░░░░░░░░░░░░░░░░░ Trend: ▁▂▃▄▅▆▇█                 │
│ 🤖 Prediction: 72% in 30min based on similar patterns         │
│    Suggested: Scale FLAME pool or check runaway process        │
└─────────────────────────────────────────────────────────────────┘
```

### Intelligent AlertDialog

```
Standard AlertDialog:
┌─ ⚠ CAUTION ────────────────────────────┐
│ High CPU on app-03                     │
│                                        │
│ [ACKNOWLEDGE]  [DISMISS]               │
└────────────────────────────────────────┘

AI-Enhanced AlertDialog:
┌─ ⚠ CAUTION ─────────────────────────────────────────────────────┐
│ High CPU on app-03                          Priority: 2 of 7    │
│                                                                  │
│ 🤖 COPILOT ANALYSIS (Confidence: 0.89)                          │
│ ├─ Root Cause: Likely batch job "analytics_aggregation"         │
│ ├─ Similar Events: 12 occurrences, 11 auto-resolved             │
│ ├─ Recommended: Wait 5min (historical resolution: 92%)          │
│ └─ Correlation: app-02 shows similar pattern (batch sync)       │
│                                                                  │
│ [🕐 SNOOZE 5m (Recommended)]  [ACK]  [ESCALATE]  [INVESTIGATE]  │
└──────────────────────────────────────────────────────────────────┘
```

### Intelligent SearchField

```
Standard SearchField:
┌─────────────────────────────────┐
│ 🔍 Search...                    │
└─────────────────────────────────┘

AI-Enhanced SearchField:
┌───────────────────────────────────────────────────────────────────┐
│ 🔍 cpu                                                            │
├───────────────────────────────────────────────────────────────────┤
│ 🤖 SUGGESTED (based on context: "app-03 high CPU alarm")         │
│ ├─ cpu.app-03.metrics      ← Most relevant to current alarm     │
│ ├─ cpu.threshold.config    ← You modified this 2 hours ago      │
│ └─ cpu.load-balancer.logs  ← Related to scaling decisions       │
│                                                                   │
│ RECENT                                                            │
│ ├─ alarm.history                                                  │
│ └─ node.restart                                                   │
└───────────────────────────────────────────────────────────────────┘
```

### Intelligent NavigationRail

```fsharp
type IntelligentNavigationRail = {
    Items: NavItem list
    MLReorderer: UsagePatternModel
    ContextualShortcuts: ContextRule list
}

// Example: During alarm storm, surface "Alarm Center" and "Commands"
// Example: After login, show recently accessed screens
// Example: During maintenance window, prioritize "Containers" and "Diagnostics"
```

```
Standard NavigationRail:        Context-Aware NavigationRail (during alarm):
┌──────────────────┐           ┌──────────────────────────────────────┐
│ Dashboard        │           │ ⚠ Alarms (7)    ← Auto-promoted      │
│ Mesh             │           │ Commands        ← Critical actions   │
│ Alarms           │           │ Dashboard                            │
│ Commands         │           │ AI Copilot      ← Active suggestions │
│ AI Copilot       │           │ ───────────                          │
│ Containers       │           │ Mesh                                 │
│ Settings         │           │ Containers                           │
└──────────────────┘           │ Settings                             │
                               └──────────────────────────────────────┘
```

### Predictive ProgressIndicator

```
Standard Progress:              AI-Enhanced Progress:
┌───────────────────┐          ┌─────────────────────────────────────────┐
│ Deploying...      │          │ Deploying... ETA: 2m 34s (±15s)         │
│ [████████░░░] 73% │          │ [████████░░░] 73%                       │
└───────────────────┘          │ 🤖 Based on 47 similar deploys         │
                               │    Current pace: 8% faster than avg    │
                               │    Risk: Low (no anomalies detected)   │
                               └─────────────────────────────────────────┘
```

### Intelligent TrendMiniChart

```
Standard Trend:                 AI-Enhanced Trend:
▁▂▃▄▅▆▇█████████              ▁▂▃▄▅▆▇█████████ ⟨▒▒▓▓▓⟩ ← Forecast
                               ↳ 🤖 Prediction: +23% in 1hr
                                  Confidence: 0.82
                                  Pattern: "Daily batch peak"
```

### Smart CommandChip Suggestions

```fsharp
type IntelligentCommandChip = {
    Command: string
    Context: SystemContext
    PredictedNextCommands: (Command * Probability) list
}

// After "RESTART app-03", suggest:
// - "HEALTH_CHECK app-03" (87% likely)
// - "VIEW_LOGS app-03" (72% likely)
// - "CLEAR_ALARMS app-03" (65% likely)
```

```
Standard Commands:              Context-Aware Commands:
┌───────────────────────────┐  ┌─────────────────────────────────────────────┐
│ [RESTART] [STOP] [SCALE]  │  │ [RESTART app-03]  ← You just did this      │
└───────────────────────────┘  │ 🤖 Suggested next:                          │
                               │ [HEALTH_CHECK] [VIEW_LOGS] [CLEAR_ALARMS]   │
                               └─────────────────────────────────────────────┘
```

### Implementation Patterns

#### 1. Context Injection Hook

```fsharp
type AIContext = {
    CurrentAlarms: Alarm list
    RecentActions: Action list
    OperatorProfile: OperatorProfile
    SystemHealth: HealthScore
    TimeContext: TimeContext
    Predictions: Prediction list
}

let renderWithContext (component: Component) (context: AIContext) : string =
    let enhancements = inferEnhancements component context
    let priorityBoost = calculatePriorityBoost component context
    let suggestions = generateSuggestions component context
    renderEnhanced component enhancements priorityBoost suggestions
```

#### 2. Anomaly-Aware Highlighting

```fsharp
type AnomalyAwareness = {
    Threshold: float
    Model: AnomalyModel
    HighlightStyle: Style
}

let renderMetricWithAnomaly (metric: Metric) (awareness: AnomalyAwareness) =
    let score = awareness.Model.Score metric
    if score > awareness.Threshold then
        renderWithHighlight metric awareness.HighlightStyle score
    else
        renderNormal metric
```

#### 3. Predictive Pre-fetching

```fsharp
// Components predict what data user will need next
type PredictiveComponent = {
    CurrentView: View
    PredictionModel: NavigationModel
    PreFetchQueue: DataRequest Queue
}

// When user views "Alarm Center", pre-fetch:
// - Alarm details for top 3 alarms (90% view probability)
// - Related metrics for alarmed nodes (78% probability)
// - Historical similar alarms (65% probability)
```

### AI Safety Constraints (SC-AI)

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-AI-001 | AI is ADVISORY only | All suggestions require human confirmation |
| SC-AI-002 | Confidence display | Always show confidence scores |
| SC-AI-003 | Explainability | Provide reasoning for suggestions |
| SC-AI-004 | Override capability | User can dismiss/disable AI features |
| SC-AI-005 | No autonomous actions | AI cannot execute commands directly |
| SC-AI-006 | Audit trail | Log all AI suggestions and responses |

### Integration with PRAJNA AI Copilot

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRAJNA COPILOT INTEGRATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ COPILOT ENGINE ─────────────────────────────────────────────────────┐   │
│  │ Local Analytics: ACTIVE    LLM (Claude 3.5): CONNECTED               │   │
│  │ Insight Rate: 14/min       Confidence Avg: 0.87                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ INSIGHT TYPES ──────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  SUMMARY     → System health synthesis every 30s                      │   │
│  │  ANOMALY     → Real-time deviation detection (Isolation Forest)       │   │
│  │  PREDICTION  → Forward-looking forecasts (Prophet, ARIMA)             │   │
│  │  CORRELATION → Cross-metric relationship discovery                    │   │
│  │  RECOMMENDATION → Actionable suggestions with confidence              │   │
│  │  ROOT_CAUSE  → Causal chain analysis for incidents                    │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ COMPONENT ENHANCEMENT PIPELINE ─────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  1. Component requests context → Copilot Engine                       │   │
│  │  2. Engine runs inference → Local ML + Optional LLM                   │   │
│  │  3. Insights packaged → AIContext struct                              │   │
│  │  4. Component renders → Enhanced with AI overlays                     │   │
│  │  5. User interacts → Feedback loop to improve models                  │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Usecase-Specific Intelligence

#### 1. Alarm Storm Management
- Auto-suppress duplicates with correlation insights
- Highlight root cause alarm among related events
- Predict storm duration based on historical patterns
- Suggest bulk acknowledge for related alarms

#### 2. Capacity Planning
- Trend overlays showing predicted resource exhaustion
- Auto-scaling suggestions with confidence intervals
- Historical comparison for similar growth patterns
- Cost/benefit analysis for scaling decisions

#### 3. Incident Response
- Auto-surface related metrics and logs
- Timeline reconstruction with AI annotations
- Similar incident matching with resolution hints
- Communication template generation

#### 4. Shift Handover
- Auto-generated situation summary
- Highlight items requiring attention
- Pending actions with context
- Recent changes and their impacts

---

## Bubbles-Inspired Components

Components adapted from [charmbracelet/bubbles](https://github.com/charmbracelet/bubbles) for the Dark Cockpit UI.

### Paginator

Handles pagination with visual feedback for large data sets.

**Type Definition**:
```fsharp
type PaginatorStyle = DotStyle | NumericStyle | ArrowStyle

type Paginator = {
    CurrentPage: int
    TotalPages: int
    Style: PaginatorStyle
    PerPage: int
    TotalItems: int
}
```

**Functional Modes**:

| Style | Visual | Use Case |
|-------|--------|----------|
| DotStyle | `○ ○ ● ○ ○` | iOS-like, few pages |
| NumericStyle | `« 1 2 [3] 4 5 »` | Many pages, direct access |
| ArrowStyle | `◀ Page 3 of 10 ▶` | Simple navigation |

**Visual Examples**:
```
DotStyle (5 pages, page 3 selected):
○ ○ ● ○ ○

NumericStyle (10 pages, page 3 selected):
« 1 2 [3] 4 5 6 7 8 9 10 »

ArrowStyle:
◀ Page 3 of 10 ▶
```

### Viewport

Scrollable content container with scroll position indicators.

**Type Definition**:
```fsharp
type Viewport = {
    Content: string list
    VisibleHeight: int
    ScrollOffset: int
    Width: int
    ShowScrollbar: bool
    HighPerformance: bool
}
```

**Visual Example**:
```
┌────────────────────────────────────┐█
│ Line 1 of content                  │░
│ Line 2 of content                  │░
│ Line 3 of content                  │░
│ Line 4 of content                  │░
│ Line 5 of content                  │█
│ Line 6 of content                  │░
│ Line 7 of content                  │░
└────────────────────────────────────┘░
              ── 25% ──
```

### FilePicker

Directory and file selection with filtering and details view.

**Type Definition**:
```fsharp
type FileType = Directory | File | Symlink | Unknown

type FileEntry = {
    Name: string
    Path: string
    Type: FileType
    Size: int64 option
    Modified: DateTime option
    Selected: bool
}

type FilePicker = {
    CurrentPath: string
    Entries: FileEntry list
    SelectedIndex: int
    ShowHidden: bool
    AllowedExtensions: string list option
    ShowDetails: bool
}
```

**Visual Example**:
```
┌─ /home/user/projects ─┐
│ 📁 ..                  │
│ 📁 src                 │
│▶📁 lib           4.2M  │  ← Selected
│ 📄 README.md     2.1K  │
│ 📄 mix.exs        892B │
│ 🔗 deps               │
└─ 5 items ─────────────┘
```

### Timer

Countdown timer with progress visualization and state indicators.

**Type Definition**:
```fsharp
type TimerState = Running | Paused | Finished | Idle

type Timer = {
    Duration: TimeSpan
    Remaining: TimeSpan
    State: TimerState
    ShowMilliseconds: bool
    Label: string option
}
```

**Functional Modes**:

| State | Icon | Color | Behavior |
|-------|------|-------|----------|
| Running | ▶ | advisory | Active countdown |
| Paused | ⏸ | caution | Frozen at current time |
| Finished | ✓ | primary | Countdown complete |
| Idle | ○ | outline | Not started |

**Visual Examples**:
```
Running (normal):
┌─ Deployment ─────────────────┐
│ ▶ 00:02:34                   │
│ ██████████████░░░░░░         │
└──────────────────────────────┘

Running (<30s, caution):
┌─ Deployment ─────────────────┐
│ ▶ 00:00:25                   │  ← Amber color
│ ██░░░░░░░░░░░░░░░░░░         │
└──────────────────────────────┘

Running (<10s, warning):
┌─ Deployment ─────────────────┐
│ ▶ 00:00:08                   │  ← Red color
│ █░░░░░░░░░░░░░░░░░░░         │
└──────────────────────────────┘

Finished:
┌─ Deployment ─────────────────┐
│ ✓ 00:00:00                   │  ← Green
│ ░░░░░░░░░░░░░░░░░░░░         │
└──────────────────────────────┘
```

### Stopwatch

Elapsed time counter with lap support.

**Type Definition**:
```fsharp
type StopwatchState = StopwatchRunning | StopwatchStopped | StopwatchReset

type Stopwatch = {
    Elapsed: TimeSpan
    State: StopwatchState
    Laps: TimeSpan list
    ShowLaps: bool
    ShowMilliseconds: bool
}
```

**Visual Example**:
```
Running with laps:
┌─ Stopwatch ────────────────────┐
│ ▶ 00:05:32.456                 │
├────────────────────────────────┤
│ Laps:                          │
│   1. 00:01:23                  │
│   2. 00:02:45                  │
│   3. 00:05:32                  │
└────────────────────────────────┘

Stopped:
┌─ Stopwatch ────────────────────┐
│ ⏹ 00:05:32.456                 │
└────────────────────────────────┘
```

### Help

Auto-generated help view from keybindings with multiple display styles.

**Type Definition**:
```fsharp
type KeyBinding = {
    Key: string
    Description: string
    Group: string option
}

type HelpStyle = SingleLine | MultiLine | Grouped

type Help = {
    Bindings: KeyBinding list
    Style: HelpStyle
    MaxWidth: int
    Separator: string
}
```

**Visual Examples**:
```
SingleLine:
↑/↓ navigate • enter select • q quit • ? help

MultiLine:
  ↑/↓       navigate
  enter     select
  q         quit
  ?         help

Grouped:
Navigation
  ↑/↓       navigate
  enter     select
Actions
  d         delete
  e         edit
General
  q         quit
  ?         help
```

### FuzzyFilter

Fuzzy text filtering with ranked results and match highlighting.

**Type Definition**:
```fsharp
type FuzzyMatch = {
    Item: string
    Score: int
    MatchedIndices: int list
}

type FuzzyFilter = {
    Query: string
    Items: string list
    Matches: FuzzyMatch list
    MaxResults: int
}
```

**Visual Example** (query: "cfg"):
```
Search: cfg
──────────────────────────
  config.exs            (score: 28)  ← c, f, g highlighted
  config_manager.ex     (score: 25)
  cfg_parser.ex         (score: 23)
  my_config.json        (score: 18)
```

**Scoring Algorithm**:
- +10 points per matched character
- +5 bonus for consecutive matches
- +3 bonus for word boundary matches (start of word, after _, -)

---

## Layout Composition System (LayoutBoxer)

Layout composition system adapted from [treilik/bubbleboxer](https://github.com/treilik/bubbleboxer) for building complex multi-pane TUI interfaces.

### Overview

LayoutBoxer provides a tree-based layout composition system that allows combining multiple UI components into complex layouts with:

- **Horizontal/Vertical Splits**: Recursive nesting of splits for arbitrary layouts
- **Flexible Sizing**: Fixed, Percentage, Flex-weight, and Auto-size strategies
- **Addressable Nodes**: Each node has a unique address for dynamic updates and focus management
- **Border Styles**: Multiple box-drawing character styles
- **Dynamic Content**: Support for live-updating content via render functions

### Type Definitions

```fsharp
type Orientation = Horizontal | Vertical

type SizeStrategy =
    | Fixed of int          // Fixed number of characters/lines
    | Percent of int        // Percentage of parent (0-100)
    | Flex of int           // Flex weight (like CSS flexbox)
    | Auto                  // Size to content

type BoxBorder =
    | NoBorder
    | SingleLine            // ┌─┐
    | DoubleLine            // ╔═╗
    | RoundedCorners        // ╭─╮
    | HeavyLine             // ┏━┓
    | DashedLine            // ┌┄┐

type LayoutNode =
    | Leaf of LeafNode
    | Split of SplitNode

and LeafNode = {
    Address: string         // Unique identifier (e.g., "main", "sidebar")
    Content: BoxContent     // Static or Dynamic content
    Title: string option    // Optional border title
    Border: BoxBorder
    Padding: int
    Focused: bool           // Visual focus indicator
}

and SplitNode = {
    Address: string
    Orientation: Orientation
    Children: (LayoutNode * SizeStrategy) list
    Spacing: int
    Border: BoxBorder
}

type BoxContent =
    | Static of string list
    | Dynamic of (int * int -> string list)   // (width, height) -> lines
```

### Builder DSL

The LayoutBoxer provides a fluent DSL for building layouts:

```fsharp
// Create a leaf node with static content
let sidebarContent = ["Menu"; "───"; "• Home"; "• Settings"; "• Help"]
let sidebar = leaf "sidebar" (Static sidebarContent)

// Create a leaf with a title
let main = leafWithTitle "main" "Content" (Static ["Main panel content"])

// Create a dynamic leaf that renders based on size
let statusBar = dynamicLeaf "status" "Status" (fun (w, h) ->
    [String.replicate w "─"; sprintf "Width: %d, Height: %d" w h])

// Combine with horizontal split
let layout = hsplit "root" 1 [
    (sidebar, Fixed 20)
    (main, Flex 1)
    (statusBar, Fixed 3)
]

// Create the boxer and render
let boxer = boxer 80 24 layout
let rendered = renderLayoutBoxer boxer
```

### Visual Examples

**Three-Column Layout**:
```
┌─ Sidebar ────────┐┌─ Main Content ──────────────────────┐┌─ Details ───────┐
│ • Dashboard      ││ Welcome to PRAJNA                   ││ Selected: Home  │
│ • Alarms         ││                                     ││                 │
│ • Settings       ││ System Status: HEALTHY              ││ Type: Dashboard │
│ • Reports        ││ Active Users: 42                    ││ Last: 2m ago    │
│                  ││ Uptime: 25d 14h                     ││                 │
└──────────────────┘└─────────────────────────────────────┘└─────────────────┘
```

**Dashboard Layout (Nested Splits)**:
```
┌─ Header ─────────────────────────────────────────────────────────────────────┐
│ PRAJNA C3I Mesh Cockpit v1.0.0                                               │
├──────────────────────────────────────────────────────────────────────────────┤
│┌─ Sidebar ───────────┐┌─ Main ────────────────────────────────────────────┐ │
││ • Overview          ││                                                    │ │
││ • Mesh              ││   [Main content area - Flex sizing]                │ │
││ • Alarms            ││                                                    │ │
││ • Commands          ││                                                    │ │
│└─────────────────────┘└────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────────────┤
│┌─ Status ───────────────────────────────────────────────────────────────────┐│
││ CPU: 42% │ MEM: 68% │ Uptime: 25d 14h │ Nodes: 5/5                         ││
│└────────────────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Pre-Built Layout Templates

| Template | Description | Splits |
|----------|-------------|--------|
| `threeColumnLayout` | Sidebar + Main + Details | H: 20% / 60% / 20% |
| `dashboardLayout` | Header + (Sidebar + Main) + Footer | V: H embedded |
| `splitHorizontal` | Two panes side-by-side | H: 50% / 50% |
| `splitVertical` | Two panes stacked | V: 50% / 50% |

### Sizing Strategy Reference

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `Fixed n` | Exactly n chars/lines | Navigation rails, status bars |
| `Percent p` | p% of parent size | Proportional layouts |
| `Flex w` | Flex weight (CSS flexbox-like) | Main content areas |
| `Auto` | Size to content | Dynamic elements |

**Flex Weight Example**:
```
Children: [(a, Flex 1), (b, Flex 2), (c, Flex 1)]
Available: 100 chars
Result: a=25, b=50, c=25 chars
```

### Border Style Gallery

```
SingleLine:     DoubleLine:     RoundedCorners:
┌───────┐       ╔═══════╗       ╭───────╮
│Content│       ║Content║       │Content│
└───────┘       ╚═══════╝       ╰───────╯

HeavyLine:      DashedLine:     NoBorder:
┏━━━━━━━┓       ┌┄┄┄┄┄┄┄┐       Content
┃Content┃       ┆Content┆       (no border)
┗━━━━━━━┛       └┄┄┄┄┄┄┄┘
```

### Dynamic Updates

```fsharp
// Find and update a specific node by address
let updated = updateLeafContent boxer "main" (Static ["New content"])

// Set focus on a node (adds visual highlight)
let focused = setFocus boxer "sidebar"

// Find a node for inspection
match findNode boxer.Root "main" with
| Some (Leaf leaf) -> printfn "Found main: %A" leaf.Title
| _ -> printfn "Node not found"
```

### Compliance Notes

| Constraint | Requirement | Implementation |
|------------|-------------|----------------|
| SC-HMI-001 | Management by Exception | Focused node visual distinction |
| SC-HMI-002 | Analog over Digital | Flexible sizing for data displays |
| SC-HMI-006 | Icon Consistency | Consistent border characters |

---

## Apple HIG-Inspired Design System

**Version**: HIG 1.0.0 | **File**: `Material3.fs:3374-4147`
**Compliance**: SC-HMI-008 to SC-HMI-011, WCAG 2.1 AA/AAA

The Apple Human Interface Guidelines (HIG) have been adapted for Terminal UI contexts, bringing proven design principles from iOS/macOS to our Dark Cockpit environment.

### Core HIG Principles (TUI-Adapted)

| Principle | Apple HIG | TUI Adaptation |
|-----------|-----------|----------------|
| Clarity | Legible text, precise icons | ANSI styling, Unicode box-drawing |
| Deference | Content takes center stage | Gray defaults, color for exceptions |
| Depth | Hierarchy through layers | Border styles, nesting levels |
| Consistency | Familiar patterns | Standardized keyboard shortcuts |
| Feedback | Immediate response | <100ms visual confirmation |
| Accessibility | Support all users | WCAG contrast, colorblind-safe |

### New STAMP Constraints

| Constraint | Requirement | Implementation |
|------------|-------------|----------------|
| SC-HMI-008 | HIG accessibility compliance | Contrast ratios, colorblind patterns |
| SC-HMI-009 | Feedback timing requirements | 100ms, 250ms, 500ms thresholds |
| SC-HMI-010 | Navigation depth limits | 2 keypresses for core features |
| SC-HMI-011 | Focus management | Clear indicators, focus trap |

### Module Inventory (10 Modules)

#### 1. Accessibility Module
**Purpose**: WCAG 2.1 AA/AAA compliance, colorblind support, screen reader hints

```fsharp
module Accessibility =
    // Contrast checking
    let minContrastRatioText = 4.5   // WCAG AA
    let enhancedContrastRatio = 7.0  // WCAG AAA

    let relativeLuminance (r: int) (g: int) (b: int) : float
    let contrastRatio fg bg : float
    let meetsWCAGAA fg bg : bool
    let meetsWCAGAAA fg bg : bool

    // Colorblind-safe indicators (color + shape)
    type ColorblindSafeIndicator =
        | SafeSuccess   // ✓ (green + checkmark)
        | SafeWarning   // ⚠ (amber + triangle)
        | SafeError     // ✗ (red + cross)
        | SafeInfo      // ℹ (blue + info)
        | SafeNeutral   // ● (gray + circle)
        | SafeProgress  // ◐ (cyan + half)

    // Pattern fills for colorblind differentiation
    type PatternFill =
        | Solid | Horizontal | Vertical
        | DiagonalRight | DiagonalLeft
        | Cross | Dots | Sparse

    // Screen reader accessibility roles
    type AccessibilityRole =
        | ARButton | ARLink | ARHeading of int
        | ARList | ARListItem | ARAlert
        | ARDialog | ARStatus | ARProgressBar
        | ARTabList | ARTab | ARPanel
```

**Colorblind-Safe Indicator Usage**:
```
✓ SUCCESS (green + check)    ⚠ WARNING (amber + triangle)
✗ ERROR (red + cross)        ℹ INFO (blue + info)
● NEUTRAL (gray + circle)    ◐ PROGRESS (cyan + half)
```

#### 2. FeedbackTiming Module
**Purpose**: Response timing constants per Apple HIG research

```fsharp
module FeedbackTiming =
    // Response timing thresholds
    let instantFeedback = 100       // Visual confirmation required
    let perceptibleDelay = 250      // User notices lag
    let maxAcceptableDelay = 500    // Show loading indicator

    // Animation durations
    let microAnimation = 200        // Micro-interactions
    let transitionAnimation = 300   // Standard transitions
    let complexAnimation = 500      // Emphasis animations

    // UX timing
    let searchDebounce = 300        // Search input delay
    let toastAutoDismiss = 3000     // Toast notifications
    let criticalBlinkInterval = 500 // Critical alert blink

    // Loading indicator recommendation
    type LoadingIndicator = Spinner | ProgressBar | Indeterminate | Skeleton
```

**Timing Reference**:
```
Action                    Response Time   Indicator
─────────────────────────────────────────────────────
Button press              <100ms          Immediate highlight
Data fetch (quick)        <500ms          Spinner
Data fetch (known)        500ms+          ProgressBar
Data fetch (unknown)      500ms+          Indeterminate
Content placeholder       Any             Skeleton
```

#### 3. Navigation Module
**Purpose**: Two-keypress access, keyboard shortcuts, breadcrumbs

```fsharp
module Navigation =
    let maxCoreFeatureDepth = 2     // Core features: 2 keypresses max
    let maxTotalDepth = 4           // Any feature: 4 keypresses max

    type KeyboardShortcut =
        | KSQuit | KSHelp | KSSearch | KSRefresh
        | KSBack | KSConfirm | KSCancel
        | KSNextTab | KSPrevTab
        | KSUp | KSDown | KSLeft | KSRight
        | KSPageUp | KSPageDown | KSHome | KSEnd
        | KSSelect | KSSelectAll
        | KSCopy | KSPaste | KSUndo | KSRedo

    let shortcutHint: KeyboardShortcut -> string
    let renderBreadcrumb: NavPath -> string
    let renderShortcutLegend: (KeyboardShortcut * string) list -> string
```

**Standard Keyboard Shortcuts**:
```
q:quit │ ?:help │ /:search │ r:refresh │ Esc:back
Tab:next │ S-Tab:prev │ Enter:confirm │ Space:select
↑/k:up │ ↓/j:down │ ←/h:left │ →/l:right
PgUp:page up │ PgDn:page down │ Home:top │ End:bottom
```

#### 4. HighContrast Module
**Purpose**: WCAG AAA high contrast mode

```fsharp
module HighContrast =
    module Colors =
        let background = "\u001b[48;2;0;0;0m"       // Pure black
        let foreground = "\u001b[38;2;255;255;255m" // Pure white
        let success = "\u001b[38;2;0;255;0m"        // Pure green
        let warning = "\u001b[38;2;255;255;0m"      // Pure yellow
        let error = "\u001b[38;2;255;0;0m"          // Pure red
        let info = "\u001b[38;2;0;255;255m"         // Pure cyan

    let mutable isEnabled = false
    let toggle () = isEnabled <- not isEnabled
    let adaptColor normalColor highContrastColor : string
```

**High Contrast Mode Comparison**:
```
NORMAL MODE:                    HIGH CONTRAST MODE:
┌──────────────────────┐        ┌──────────────────────┐
│ Status: ● Connected  │   →    │ Status: ● Connected  │
│ Error: ● Problem     │        │ Error: ✗ Problem     │
│ Text on #1C1B1F bg   │        │ White on #000000 bg  │
└──────────────────────┘        └──────────────────────┘
```

#### 5. AlertHierarchy Module
**Purpose**: Alert priority, confirmation patterns, destructive actions

```fsharp
module AlertHierarchy =
    type AlertPriority =
        | APCritical | APHigh | APMedium | APLow | APSuccess

    type AlertAction =
        | AADestructive of string  // Requires double confirmation
        | AAPrimary of string      // Single confirmation
        | AASecondary of string    // No confirmation
        | AACancel                 // Always available

    type ConfirmationLevel =
        | CLNone        // No confirmation
        | CLSingle      // Enter to confirm
        | CLDouble      // Type confirmation word
        | CLTimed of int // Countdown timer

    // Two-step commit for destructive actions
    type DestructiveConfirmState =
        | DCSIdle | DCSArmed of DateTime
        | DCSConfirming of string
        | DCSExecuting | DCSComplete of bool

    let armedTimeout = 30  // seconds
    let generateConfirmationWord () : string
```

**Alert Priority Visualization**:
```
CRITICAL (☢):               HIGH (⛔):
┌──────────────────────┐    ┌──────────────────────┐
│ ☢ SYSTEM FAILURE     │    │ ⛔ SECURITY ALERT    │
│ Immediate action req │    │ Review required      │
│ [SHUTDOWN] [DISMISS] │    │ [VIEW] [DISMISS]     │
└──────────────────────┘    └──────────────────────┘

MEDIUM (⚠):                 SUCCESS (✓):
┌──────────────────────┐    ┌──────────────────────┐
│ ⚠ Warning            │    │ ✓ Operation Complete │
│ Check when possible  │    │ No action needed     │
│ [OK]                 │    │ [OK]                 │
└──────────────────────┘    └──────────────────────┘
```

#### 6. FocusManagement Module
**Purpose**: Focus indicators, focus trap for modals

```fsharp
module FocusManagement =
    type FocusStyle =
        | FSOutline     // ▶ indicator ◀
        | FSBackground  // Background color
        | FSUnderline   // Underline text
        | FSBold        // Bold text
        | FSCombined    // Multiple indicators

    type FocusTrap = {
        Elements: string list
        CurrentIndex: int
        WrapAround: bool
    }

    let createFocusTrap: string list -> FocusTrap
    let focusNext: FocusTrap -> FocusTrap
    let focusPrev: FocusTrap -> FocusTrap
    let currentFocus: FocusTrap -> string option
```

**Focus Indicator Styles**:
```
FSOutline:     ▶ Focused Item ◀
FSBackground:  [████ Focused ████]
FSUnderline:   Focused Item
               ────────────
FSBold:        Focused Item (bold)
FSCombined:    ▶ Focused Item ◀ (all effects)
```

#### 7. TypographyScale Module
**Purpose**: TUI-appropriate text hierarchy

```fsharp
module TypographyScale =
    type TextLevel =
        | TLDisplay   // ASCII art headers
        | TLHeadline  // Section headers
        | TLTitle     // Component titles
        | TLBody      // Normal text
        | TLLabel     // Small labels
        | TLCaption   // Timestamps, hints

    let lineHeightMultiplier: TextLevel -> float
    let recommendedLineLength: TextLevel -> int
    let getStyle: TextLevel -> string
    let applyStyle: TextLevel -> string -> string
    let wrapText: int -> string -> string list
```

**Typography Hierarchy**:
```
TLDisplay:    ████████████████████████████  (Bold+Underline, 80 chars)
              LARGE HEADERS / ASCII ART

TLHeadline:   Section Header                 (Bold, 60 chars)
              ─────────────────

TLTitle:      Component Title                (Bold, 50 chars)

TLBody:       This is body text that flows   (Normal, 45 chars)
              naturally across lines with
              optimal reading width.

TLLabel:      small label text               (Dim, 35 chars)

TLCaption:    timestamp: 14:32:45            (Dim+Italic, 30 chars)
```

#### 8. SemanticStates Module
**Purpose**: State-based color system

```fsharp
module SemanticStates =
    type InteractiveState =
        | ISDefault | ISHover | ISPressed
        | ISFocused | ISDisabled
        | ISSelected | ISLoading

    type DataState =
        | DSEmpty | DSLoading | DSSuccess
        | DSError of string | DSStale

    type ConnectionState =
        | CSConnected | CSConnecting
        | CSDisconnected | CSError of string

    let interactiveColor: InteractiveState -> string
    let dataStateIcon: DataState -> string
    let dataStateColor: DataState -> string
    let renderConnectionStatus: ConnectionState -> string
```

**State Indicators**:
```
Data States:            Connection States:
○ Empty (gray)          ● Connected (cyan)
◐ Loading (cyan)        ◐ Connecting... (amber)
● Success (cyan)        ○ Disconnected (gray)
✗ Error (red)           ✗ Error: message (red)
◌ Stale (amber)
```

#### 9. Motion Module
**Purpose**: Animation timing and patterns for TUI

```fsharp
module Motion =
    module Duration =
        let instant = 0      // No animation
        let fast = 100       // Micro-interactions
        let normal = 200     // Standard
        let slow = 300       // Complex
        let emphasis = 500   // Emphasis

    type Easing = Linear | EaseIn | EaseOut | EaseInOut

    // Animation frames
    let spinnerFrames = [| "⠋"; "⠙"; "⠹"; "⠸"; "⠼"; "⠴"; "⠦"; "⠧"; "⠇"; "⠏" |]
    let pulseFrames = [| "○"; "◔"; "◑"; "◕"; "●"; "◕"; "◑"; "◔" |]

    type TransitionType =
        | TTFade | TTSlideLeft | TTSlideRight
        | TTSlideUp | TTSlideDown
        | TTExpand | TTCollapse
```

**Animation Frames**:
```
Spinner:  ⠋ → ⠙ → ⠹ → ⠸ → ⠼ → ⠴ → ⠦ → ⠧ → ⠇ → ⠏ (loop)
Pulse:    ○ → ◔ → ◑ → ◕ → ● → ◕ → ◑ → ◔ (loop)
Progress: ▱▱▱▱▱ → ▰▱▱▱▱ → ▰▰▱▱▱ → ▰▰▰▱▱ → ▰▰▰▰▱ → ▰▰▰▰▰
```

#### 10. HIG Entry Point Module
**Purpose**: Unified access to all HIG modules

```fsharp
module HIG =
    let version = "1.0.0"
    let name = "Apple HIG-Inspired TUI Design System"

    let principles = [
        "Clarity: Make interfaces legible and precise"
        "Deference: Let content take center stage"
        "Depth: Use hierarchy to convey relationships"
        "Consistency: Use familiar patterns"
        "Feedback: Respond to actions immediately"
        "Accessibility: Support all users"
    ]

    module Requirements =
        let minContrastRatio = 4.5
        let maxResponseTimeMs = 100
        let maxNavDepth = 2
        let minTouchTarget = 44  // Full-width in TUI

    let validateContrast fg bg : Result<string, string>
    let getRecommendations () : string list
```

### HIG Validation Checklist

Use these questions when reviewing TUI interfaces:

- [ ] **Contrast**: Does text meet 4.5:1 ratio against background?
- [ ] **Colorblind**: Is information conveyed by both color AND shape?
- [ ] **Feedback**: Does every action get visual confirmation <100ms?
- [ ] **Loading**: Do operations >500ms show a loading indicator?
- [ ] **Navigation**: Can core features be reached in ≤2 keypresses?
- [ ] **Focus**: Is the focused element clearly visible?
- [ ] **Destructive**: Do dangerous actions require confirmation?

---

## Summary Statistics

| Category | Count | Examples |
|----------|-------|----------|
| Core M3 Components | 30 | Button, Card, Dialog, TextField |
| M3 Expressive | 8 | FloatingToolbar, FABMenu, LoadingIndicator |
| Industrial HMI | 4 | CircularGauge, LinearGauge, TankLevel, LED |
| Aviation PFD | 5 | AttitudeIndicator, VSI, Airspeed, Heading, VerticalTape |
| Aviation EICAS | 2 | EngineGauge, FuelQuantity |
| Aviation Annunciator | 3 | GearIndicator, FlapsIndicator, AnnunciatorPanel |
| Aviation Navigation | 5 | RadioStack, FMA, HSI, FlightClock, TCAS |
| Aviation EFIS | 1 | EFISControlPanel |
| Data Visualization | 4 | TrendMiniChart, PieChart, SystemStatusPanel, BigTextBanner |
| Navigation | 7 | NavigationBar, NavigationRail, Tabs, Drawer |
| Bubbles-Inspired | 7 | Paginator, Viewport, FilePicker, Timer, Stopwatch, Help, FuzzyFilter |
| Layout Composition | 1 | LayoutBoxer (tree-based multi-pane layouts) |
| Apple HIG-Inspired | 10 | Accessibility, FeedbackTiming, Navigation, HighContrast, AlertHierarchy, FocusManagement, TypographyScale, SemanticStates, Motion, HIG |
| Tview-Inspired | 13 | TreeView, TextArea, SplitView, ApplicationFrame, Grid, Flexbox, SelectableList, Pages, InputField, Form, TermImage, Modal, Primitives |
| LXZ DevOps | 9 | DataBrowser, QueryPanel, LogViewer, FileBrowser, ConnectionManager, ActionPanel, FlashMessage, SplashScreen, StatusBar |
| Cobra CLI | 3 | CliFlag, CliCommand, Completion |
| Tcell Terminal | 5 | TermColor/CellStyle, ScreenCell/ScreenBuffer, TermEvent, InputHandler, TermRenderer |
| **Total** | **118** | |

---

## Tview-Inspired Components

Tview-inspired components for terminal UIs, based on [rivo/tview](https://github.com/rivo/tview). These components provide flexible layouts, navigation, forms, and advanced terminal rendering capabilities.

### 5. Grid Layout System (SC-HMI-034)

**Type**: `Grid` | **File**: `Material3.fs:6630`

#### Type Definition
```fsharp
type GridCell = {
    Row: int
    Column: int
    RowSpan: int
    ColSpan: int
    Content: string list
    MinWidth: int option
    MaxWidth: int option
    MinHeight: int option
    Alignment: GridAlignment
}

type Grid = {
    Rows: int
    Columns: int
    Cells: GridCell list
    RowGaps: int
    ColGaps: int
    Border: bool
}
```

#### Visual Example
```
┌──────────────┬──────────────┬──────────────┐
│    Cell 1    │    Cell 2    │    Cell 3    │
├──────────────┴──────────────┼──────────────┤
│       Cell 4 (colspan=2)    │    Cell 5    │
├──────────────┬──────────────┴──────────────┤
│    Cell 6    │       Cell 7 (colspan=2)    │
└──────────────┴─────────────────────────────┘
```

---

### 6. Flexbox Layout System (SC-HMI-035)

**Type**: `Flexbox` | **File**: `Material3.fs:6780`

#### Type Definition
```fsharp
type FlexDirection = FlexRow | FlexColumn | FlexRowReverse | FlexColumnReverse
type FlexWrap = NoWrap | Wrap | WrapReverse
type FlexJustify = JustifyStart | JustifyEnd | JustifyCenter | JustifySpaceBetween | JustifySpaceAround
type FlexAlign = AlignStart | AlignEnd | AlignCenter | AlignStretch

type FlexItem = {
    Content: string list
    Grow: int
    Shrink: int
    Basis: int option
    AlignSelf: FlexAlign option
}

type Flexbox = {
    Direction: FlexDirection
    Wrap: FlexWrap
    Justify: FlexJustify
    AlignItems: FlexAlign
    Items: FlexItem list
    Gap: int
}
```

#### Visual Example
```
Direction: Row, Justify: SpaceBetween
┌──────────────────────────────────────────────────┐
│[Item 1]         [Item 2]         [Item 3]        │
└──────────────────────────────────────────────────┘

Direction: Column, Align: Center
┌──────────────────────────────────────────────────┐
│            [Item 1]                              │
│            [Item 2]                              │
│            [Item 3]                              │
└──────────────────────────────────────────────────┘
```

---

### 7. SelectableList (SC-HMI-036)

**Type**: `SelectableList` | **File**: `Material3.fs:6900`

#### Type Definition
```fsharp
type ListItem = {
    Label: string
    Value: string
    Icon: string option
    Disabled: bool
    Selected: bool
}

type SelectableList = {
    Title: string option
    Items: ListItem list
    CurrentIndex: int
    MultiSelect: bool
    ShowScrollbar: bool
    FilterText: string option
    MaxVisibleItems: int option
}
```

#### Visual Example
```
┌─ Available Options ─────────────────────────────┐
│ ● Option 1 (selected)                           │
│   Option 2                                      │
│ ● Option 3 (selected)                           │
│   Option 4 (disabled)                           │
│ > Option 5 (current)                            │
├─────────────────────────────────────────────────┤
│ [↑/↓] Navigate  [Space] Toggle  [Enter] Confirm │
└─────────────────────────────────────────────────┘
```

---

### 8. Pages Navigation (SC-HMI-037)

**Type**: `Pages` | **File**: `Material3.fs:7050`

#### Type Definition
```fsharp
type Page = {
    Name: string
    Title: string
    Content: string list
}

type Pages = {
    Pages: Page list
    CurrentPage: int
    ShowTabs: bool
    TabPosition: TabPosition
}
```

#### Visual Example
```
┌─[Dashboard]──[Settings]──[Logs]─────────────────┐
│                                                  │
│   Dashboard content here...                      │
│                                                  │
│   ● Active Alarms: 3                            │
│   ● Uptime: 99.9%                               │
│                                                  │
├──────────────────────────────────────────────────┤
│ [←/→] Switch tabs  [1-3] Quick jump              │
└──────────────────────────────────────────────────┘
```

---

### 9. InputField (SC-HMI-038)

**Type**: `InputField` | **File**: `Material3.fs:7140`

#### Type Definition
```fsharp
type InputType = TextInput | PasswordInput | NumberInput | EmailInput

type InputField = {
    Label: string option
    Value: string
    Placeholder: string
    InputType: InputType
    CursorPosition: int
    MaxLength: int option
    Width: int
    Validation: (string -> Result<unit, string>) option
    ShowCharCount: bool
}
```

#### Visual Example
```
Username:
┌────────────────────────────────────┐
│john.doe█                           │
└────────────────────────────────────┘

Password:
┌────────────────────────────────────┐
│●●●●●●●●█                           │
└────────────────────────────────────┘
```

---

### 10. Form Component (SC-HMI-039)

**Type**: `Form` | **File**: `Material3.fs:7290`

#### Type Definition
```fsharp
type FormField =
    | FormInputField of InputField
    | FormCheckbox of label: string * isChecked: bool
    | FormDropdown of label: string * options: string list * selected: int
    | FormTextArea of label: string * content: string

type Form = {
    Title: string option
    Fields: (string * FormField) list
    FocusedField: int
    SubmitLabel: string
    CancelLabel: string option
    Border: bool
    Width: int
}
```

#### Visual Example
```
┌─ User Registration ─────────────────────────────┐
│▶ Name: [John Doe                            ]   │
│  Email: [john@example.com                   ]   │
│  [x] Subscribe to newsletter                    │
│  Role: [Admin ▼]                                │
├─────────────────────────────────────────────────┤
│           [Submit]        [Cancel]              │
└─────────────────────────────────────────────────┘
```

---

### 11. Terminal Image Display (SC-HMI-040)

**Type**: `TermImage` | **File**: `Material3.fs:7400`

#### Type Definition
```fsharp
type ImageProtocol = SixelProtocol | KittyProtocol | ITerm2Protocol | AsciiArt

type TermImage = {
    Source: string
    Width: int
    Height: int
    Protocol: ImageProtocol
    Caption: string option
    Border: bool
}
```

#### Visual Example
```
ASCII Art fallback:
┌─────────────────────────────────┐
│  ██████╗ ██████╗  █████╗       │
│  ██╔══██╗██╔══██╗██╔══██╗      │
│  ██████╔╝██████╔╝███████║      │
│  ██╔═══╝ ██╔══██╗██╔══██║      │
│  ██║     ██║  ██║██║  ██║      │
│  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝      │
├─────────────────────────────────┤
│ Company Logo                    │
└─────────────────────────────────┘
```

---

### 12. Modal Dialog (SC-HMI-041)

**Type**: `Modal` | **File**: `Material3.fs:7470`

#### Type Definition
```fsharp
type ModalButton = {
    Label: string
    Primary: bool
    Destructive: bool
    Action: string
}

type Modal = {
    Title: string
    Message: string list
    Buttons: ModalButton list
    Icon: string option
    Width: int
    FocusedButton: int
    Dismissible: bool
}
```

#### Visual Example
```
╭─ ⚠ Confirm Deletion ───────────────────────────╮
│                                                 │
│ Are you sure you want to delete this item?      │
│ This action cannot be undone.                   │
│                                                 │
│         [Delete]           [Cancel]             │
╰─────────────────────────────────────────────────╯
```

---

### 13. Primitives / Box Drawing (SC-HMI-042)

**Type**: `Primitives` module | **File**: `Material3.fs:7590`

#### Type Definition
```fsharp
type BoxStyle = {
    TopLeft: char
    TopRight: char
    BottomLeft: char
    BottomRight: char
    Horizontal: char
    Vertical: char
}

module Primitives =
    let boxLight: BoxStyle   // ┌─┐ │ └─┘
    let boxHeavy: BoxStyle   // ┏━┓ ┃ ┗━┛
    let boxDouble: BoxStyle  // ╔═╗ ║ ╚═╝
    let boxRounded: BoxStyle // ╭─╮ │ ╰─╯

    let blocks = {| Full = '█'; Half = '▌'; ... |}
    let shades = {| Light = '░'; Medium = '▒'; Dark = '▓' |}

    let hLine: char -> int -> string
    let vLine: char -> int -> string list
    let box: BoxStyle -> int -> int -> string list
    let progressBar: int -> float -> char -> char -> string
```

#### Visual Examples
```
Box Styles:
┌──────┐  ┏━━━━━━┓  ╔══════╗  ╭──────╮
│ Light│  ┃ Heavy┃  ║Double║  │Rounded│
└──────┘  ┗━━━━━━┛  ╚══════╝  ╰──────╯

Block Characters:
█ Full  ▉ 7/8  ▊ 3/4  ▋ 5/8  ▌ 1/2  ▍ 3/8  ▎ 1/4  ▏ 1/8

Shade Characters:
░ Light  ▒ Medium  ▓ Dark

Progress Bar:
█████████░░░░░░░░░░░ 45%
```

---

## LXZ DevOps Components

LXZ-inspired components for DevOps workflows, based on the [lxz CLI tool](https://github.com/liangzhaoliang95/lxz). These components provide database browsing, query execution, log viewing, file management, and connection handling.

### 1. DataBrowser (SC-HMI-016)

**Type**: `DataBrowser` | **File**: `Material3.fs:4700`

#### Type Definition
```fsharp
type ColumnAlignment = LeftAlign | RightAlign | CenterAlign

type DataColumn = {
    Name: string
    Width: int
    Alignment: ColumnAlignment
    Sortable: bool
    Filterable: bool
}

type DataBrowser = {
    Title: string
    Columns: DataColumn list
    Rows: Map<string, string> list
    SelectedRow: int
    PageSize: int
    CurrentPage: int
    TotalRows: int
    IsLoading: bool
    FilterText: string option
    SortColumn: string option
    SortDescending: bool
}
```

#### Visual Example
```
┌─ DATABASE BROWSER: users ──────────────────────────────────┐
│ Filter: [username contains 'admin']      Page 1/10 (50 rows)│
├────────────────────────────────────────────────────────────┤
│ ID    │ Username      │ Email                  │ Status    │
├────────────────────────────────────────────────────────────┤
│ 1001  │ admin         │ admin@example.com      │ ● Active  │
│ 1002  │ superadmin    │ super@example.com      │ ● Active  │
│ 1003  │ testadmin     │ test@example.com       │ ○ Inactive│
├────────────────────────────────────────────────────────────┤
│ [F]ilter  [S]ort  [←/→] Page  [↑/↓] Row  [Enter] Select   │
└────────────────────────────────────────────────────────────┘
```

---

### 2. QueryPanel (SC-HMI-017)

**Type**: `QueryPanel` | **File**: `Material3.fs:4780`

#### Type Definition
```fsharp
type QueryStatus = Idle | Executing | Completed of duration: float | Failed of error: string

type QueryPanel = {
    Title: string
    Query: string
    History: string list
    Status: QueryStatus
    MaxHistory: int
    EditorHeight: int
    SyntaxHighlight: bool
}
```

#### Visual Example
```
┌─ SQL QUERY ─────────────────────────────────────────────────┐
│ SELECT * FROM users                                         │
│ WHERE created_at > '2024-01-01'                            │
│ ORDER BY username ASC                                       │
│ LIMIT 50                                                    │
├─────────────────────────────────────────────────────────────┤
│ Status: ✓ Completed (0.234s)    History: 15 queries         │
│ [Ctrl+Enter] Execute  [Ctrl+H] History  [Ctrl+C] Clear      │
└─────────────────────────────────────────────────────────────┘
```

---

### 3. LogViewer (SC-HMI-018)

**Type**: `LogViewer` | **File**: `Material3.fs:4860`

#### Type Definition
```fsharp
type LogLevel = Trace | Debug | Info | Warning | Error | Fatal

type LogEntry = {
    Timestamp: DateTime
    Level: LogLevel
    Source: string
    Message: string
    TraceId: string option
}

type LogViewer = {
    Title: string
    Entries: LogEntry list
    FilterLevel: LogLevel option
    FilterSource: string option
    FilterText: string option
    AutoScroll: bool
    MaxEntries: int
    ShowTimestamp: bool
    ShowSource: bool
}
```

#### Visual Example
```
┌─ CONTAINER LOGS: indrajaal-app ─────────────────────────────┐
│ Filter: [Level ≥ Info ▼]  [Source: All ▼]  [Auto-scroll: ON]│
├─────────────────────────────────────────────────────────────┤
│ 14:32:45.123 INFO  [Phoenix] GET /api/health 200 (12ms)    │
│ 14:32:45.234 DEBUG [Ecto] SELECT * FROM users...           │
│ 14:32:46.345 WARN  [Oban] Job retry: SendEmail (3/5)       │
│ 14:32:47.456 ERROR [Guardian] Token expired: user_123      │
├─────────────────────────────────────────────────────────────┤
│ Showing 234 of 1,234 entries                                │
└─────────────────────────────────────────────────────────────┘
```

---

### 4. FileBrowser (SC-HMI-019)

**Type**: `FileBrowser` | **File**: `Material3.fs:4950`

#### Type Definition
```fsharp
type BrowserFileType =
    | BrowserDirectory
    | BrowserRegularFile
    | BrowserSymLink
    | BrowserExecutable
    | BrowserHidden

type BrowserFileEntry = {
    Name: string
    Path: string
    EntryType: BrowserFileType
    Size: int64
    Modified: DateTime
    Permissions: string
    IsSelected: bool
}

type FileBrowser = {
    Title: string
    CurrentPath: string
    Entries: BrowserFileEntry list
    SelectedIndex: int
    ShowHidden: bool
    SortBy: string
    MultiSelect: bool
    SelectedPaths: Set<string>
}
```

#### Visual Example
```
┌─ /home/an/dev/ver/indrajaal-v5.2 ─────────────────────────┐
│ [..] Parent Directory                                       │
├─────────────────────────────────────────────────────────────┤
│ 📁 lib/                   <DIR>      Dec 28 14:32           │
│ 📁 test/                  <DIR>      Dec 28 13:45           │
│ 📄 mix.exs                2.3 KB     Dec 27 10:00           │
│ 📄 README.md              8.1 KB     Dec 26 09:15           │
│ 🔗 node_modules → ../..   <LINK>     Dec 25 08:00           │
├─────────────────────────────────────────────────────────────┤
│ 4 directories, 12 files (1.2 MB total)                      │
│ [Enter] Open  [Space] Select  [H] Toggle hidden             │
└─────────────────────────────────────────────────────────────┘
```

---

### 5. ConnectionManager (SC-HMI-020)

**Type**: `ConnectionManager` | **File**: `Material3.fs:5040`

#### Type Definition
```fsharp
type ConnectionType = SSH | MySQL | PostgreSQL | Redis | MongoDB | HTTP | Custom of string

type ConnectionStatus = Disconnected | Connecting | Connected | Error of string

type ConnectionEntry = {
    Id: string
    Name: string
    Type: ConnectionType
    Host: string
    Port: int
    Username: string option
    Status: ConnectionStatus
    LastConnected: DateTime option
    IsFavorite: bool
}

type ConnectionManager = {
    Title: string
    Connections: ConnectionEntry list
    SelectedIndex: int
    ShowFavoritesOnly: bool
    FilterType: ConnectionType option
    QuickConnectHost: string option
}
```

#### Visual Example
```
┌─ CONNECTION MANAGER ────────────────────────────────────────┐
│ [★ Favorites]  [All]  [+ New Connection]                    │
├─────────────────────────────────────────────────────────────┤
│ ★ ● Production DB        PostgreSQL  db.prod.local:5432    │
│ ★ ○ Staging Redis        Redis       cache.stage:6379      │
│   ● Dev SSH              SSH         dev-server:22         │
│   ⊗ Old MySQL (error)    MySQL       old.db.local:3306     │
├─────────────────────────────────────────────────────────────┤
│ [Enter] Connect  [E] Edit  [D] Delete  [★] Favorite         │
└─────────────────────────────────────────────────────────────┘
```

---

### 6. ActionPanel (SC-HMI-021)

**Type**: `ActionPanel` | **File**: `Material3.fs:5130`

#### Type Definition
```fsharp
type ActionItem = {
    Key: string
    Label: string
    Description: string option
    IsEnabled: bool
    IsDestructive: bool
}

type ActionPanel = {
    Title: string
    Actions: ActionItem list
    Columns: int
    ShowDescriptions: bool
}
```

#### Visual Example
```
┌─ ACTIONS ───────────────────────────────────────────────────┐
│ [R] Restart Container    [S] Stop Container                 │
│ [L] View Logs            [E] Exec Shell                     │
│ [I] Inspect              [C] Copy ID                        │
│                                                             │
│ [D] Delete Container (destructive)                          │
└─────────────────────────────────────────────────────────────┘
```

---

### 7. FlashMessage (SC-HMI-022)

**Type**: `FlashMessage` | **File**: `Material3.fs:5200`

#### Type Definition
```fsharp
type MessageSeverity = MsgSuccess | MsgInfo | MsgWarning | MsgError

type FlashMessage = {
    Severity: MessageSeverity
    Title: string
    Body: string option
    Duration: int option
    ShowIcon: bool
    Dismissible: bool
}
```

#### Visual Example
```
╭─ ✓ Success ─────────────────────────────────────────────────╮
│ Container restarted successfully                            │
│ indrajaal-app is now running on port 4000                   │
╰─────────────────────────────────────────────────────────────╯

╭─ ⚠ Warning ─────────────────────────────────────────────────╮
│ High memory usage detected                                  │
│ Container using 85% of allocated memory                     │
╰─────────────────────────────────────────────────────────────╯
```

---

### 8. SplashScreen (SC-HMI-023)

**Type**: `SplashScreen` | **File**: `Material3.fs:5270`

#### Type Definition
```fsharp
type SplashScreen = {
    Title: string
    Subtitle: string option
    Version: string option
    Logo: string list
    LoadingText: string option
    Progress: float option
}
```

#### Visual Example
```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ██╗███╗   ██╗████████╗███████╗██╗     ██╗████████╗       ║
║     ██║████╗  ██║╚══██╔══╝██╔════╝██║     ██║╚══██╔══╝       ║
║     ██║██╔██╗ ██║   ██║   █████╗  ██║     ██║   ██║          ║
║     ██║██║╚██╗██║   ██║   ██╔══╝  ██║     ██║   ██║          ║
║     ██║██║ ╚████║   ██║   ███████╗███████╗██║   ██║          ║
║     ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚══════╝╚═╝   ╚═╝          ║
║                                                               ║
║                    Security Monitoring Platform               ║
║                        Version 5.2.0                          ║
║                                                               ║
║                [████████████████░░░░] 78%                    ║
║                   Loading components...                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 9. StatusBar (SC-HMI-024)

**Type**: `StatusBar` | **File**: `Material3.fs:5350`

#### Type Definition
```fsharp
type StatusItem = {
    Label: string
    Value: string
    Color: string option
    Icon: string option
}

type StatusBar = {
    LeftItems: StatusItem list
    CenterItems: StatusItem list
    RightItems: StatusItem list
    Separator: string
}
```

#### Visual Example
```
┌─────────────────────────────────────────────────────────────────────┐
│ ● Connected  │  3 Containers  │  CPU: 42%  │  MEM: 68%  │  14:32:45 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Cobra CLI Framework Components

Cobra-inspired CLI framework components, based on [spf13/cobra](https://github.com/spf13/cobra). These components provide command-line interface building blocks including commands, flags, help generation, and shell completion.

### 1. CliFlag (SC-HMI-025)

**Type**: `CliFlag` | **File**: `Material3.fs:5610`

#### Type Definition
```fsharp
type FlagValue =
    | BoolFlag of bool
    | StringFlag of string
    | IntFlag of int
    | FloatFlag of float
    | StringListFlag of string list

type CliFlag = {
    Name: string
    Shorthand: char option
    Description: string
    Value: FlagValue
    DefaultValue: FlagValue
    Required: bool
    Hidden: bool
    Persistent: bool
    Deprecated: string option
}
```

#### Visual Example
```
Flags:
  -c, --config string    Configuration file path (default: ./config.yaml)
  -v, --verbose          Enable verbose output
  -n, --count int        Number of iterations (default: 10)
      --tags strings     Comma-separated list of tags
  -h, --help             Show this help message

Global Flags:
      --debug            Enable debug mode
      --no-color         Disable colorized output
```

---

### 2. CliCommand (SC-HMI-026)

**Type**: `CliCommand` | **File**: `Material3.fs:5680`

#### Type Definition
```fsharp
type CommandContext = {
    Args: string list
    Flags: Map<string, FlagValue>
    Stdin: string option
    WorkingDir: string
}

type CliCommand = {
    Name: string
    Aliases: string list
    Short: string
    Long: string option
    Example: string option
    Flags: CliFlag list
    PersistentFlags: CliFlag list
    SubCommands: CliCommand list
    Run: (CommandContext -> int) option
    PreRun: (CommandContext -> unit) option
    PostRun: (CommandContext -> unit) option
    Hidden: bool
    Deprecated: string option
    Version: string option
}
```

#### Visual Example
```
indrajaal - Security Monitoring Platform CLI

Usage:
  indrajaal [command]

Available Commands:
  start       Start the Indrajaal server
  stop        Stop the running server
  status      Show server status
  config      Manage configuration
  help        Help about any command

Flags:
  -h, --help      help for indrajaal
  -v, --version   version for indrajaal

Use "indrajaal [command] --help" for more information about a command.
```

---

### 3. Completion (SC-HMI-027)

**Type**: `Completion` module | **File**: `Material3.fs:5790`

#### Type Definition
```fsharp
type CompletionItem = {
    Value: string
    Description: string option
    Icon: string option
}

type CompletionResult = {
    Items: CompletionItem list
    Directive: string option
}
```

#### Visual Example
```
$ indrajaal con[TAB]
config     Configure system settings
container  Manage containers
connect    Connect to remote server

$ indrajaal config --[TAB]
--file      Configuration file path
--format    Output format (json, yaml)
--validate  Validate configuration
```

---

## Tcell Terminal Rendering Components

Tcell-inspired terminal rendering components, based on [gdamore/tcell](https://github.com/gdamore/tcell). These components provide low-level terminal control including colors, styles, screen buffers, and event handling.

### 1. TermColor & CellStyle (SC-HMI-028)

**Type**: `TermColor`, `CellStyle` | **File**: `Material3.fs:5877`

#### Type Definition
```fsharp
type TermColor =
    | ColorDefault
    | ColorBlack | ColorRed | ColorGreen | ColorYellow
    | ColorBlue | ColorMagenta | ColorCyan | ColorWhite
    | ColorBrightBlack | ColorBrightRed | ColorBrightGreen | ColorBrightYellow
    | ColorBrightBlue | ColorBrightMagenta | ColorBrightCyan | ColorBrightWhite
    | Color256 of int
    | ColorRGB of r: int * g: int * b: int

type TextAttribute =
    | AttrNone | AttrBold | AttrDim | AttrItalic | AttrUnderline
    | AttrBlink | AttrReverse | AttrStrikethrough | AttrHidden

type CellStyle = {
    Foreground: TermColor
    Background: TermColor
    Attributes: TextAttribute list
}
```

#### Visual Example
```
Color Support Levels:
┌────────────────────────────────────────────────────────────────┐
│ 16 Colors:    ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■ ■                  │
│ 256 Colors:   ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■                  │
│ True Color:   Full RGB spectrum (16.7M colors)                 │
└────────────────────────────────────────────────────────────────┘

Text Attributes:
  Normal   𝗕𝗼𝗹𝗱   𝘋𝘪𝘮   𝘐𝘵𝘢𝘭𝘪𝘤   U̲n̲d̲e̲r̲l̲i̲n̲e̲   S̶t̶r̶i̶k̶e̶   🔄Reverse
```

---

### 2. ScreenCell & ScreenBuffer (SC-HMI-029)

**Type**: `ScreenCell`, `ScreenBuffer` | **File**: `Material3.fs:5990`

#### Type Definition
```fsharp
type ScreenCell = {
    Rune: char
    Width: int
    Style: CellStyle
    Combined: char list  // Combining characters
}

type ScreenBuffer = {
    Width: int
    Height: int
    Cells: ScreenCell array array
    CursorX: int
    CursorY: int
    CursorVisible: bool
}
```

#### Visual Example
```
Screen Buffer (80x24):
┌──────────────────────────────────────────────────────────────────────────────┐
│ Cell[0,0]   Cell[1,0]   Cell[2,0]   ...   Cell[79,0]                        │
│ Cell[0,1]   Cell[1,1]   Cell[2,1]   ...   Cell[79,1]                        │
│ ...                                                                          │
│ Cell[0,23]  Cell[1,23]  Cell[2,23]  ...   Cell[79,23]                       │
└──────────────────────────────────────────────────────────────────────────────┘

Each cell contains:
  • Rune (character)
  • Style (fg, bg, attributes)
  • Width (1 for ASCII, 2 for CJK)
  • Combined (combining marks like accents)
```

---

### 3. TermEvent (SC-HMI-030)

**Type**: `TermEvent` | **File**: `Material3.fs:6050`

#### Type Definition
```fsharp
type KeyModifier = ModShift | ModCtrl | ModAlt | ModMeta

type SpecialKey =
    | KeyRune of char
    | KeyUp | KeyDown | KeyLeft | KeyRight
    | KeyHome | KeyEnd | KeyPageUp | KeyPageDown
    | KeyInsert | KeyDelete | KeyBackspace | KeyTab
    | KeyEnter | KeyEscape
    | KeyF1 | KeyF2 | KeyF3 | KeyF4 | KeyF5 | KeyF6
    | KeyF7 | KeyF8 | KeyF9 | KeyF10 | KeyF11 | KeyF12

type MouseButton = ButtonNone | Button1 | Button2 | Button3 | WheelUp | WheelDown

type TermEvent =
    | EventKey of key: SpecialKey * modifiers: KeyModifier list
    | EventMouse of x: int * y: int * button: MouseButton * modifiers: KeyModifier list
    | EventResize of width: int * height: int
    | EventPaste of text: string
    | EventInterrupt
```

#### Event Flow
```
Terminal Input → Parser → TermEvent → Handler → State Update → Render

Key Events:
  Ctrl+C  →  EventKey(KeyRune 'c', [ModCtrl])  →  Interrupt
  ↑       →  EventKey(KeyUp, [])               →  Move up
  F1      →  EventKey(KeyF1, [])               →  Help

Mouse Events:
  Click   →  EventMouse(45, 12, Button1, [])   →  Select
  Scroll  →  EventMouse(45, 12, WheelUp, [])   →  Scroll up
```

---

### 4. InputHandler (SC-HMI-031)

**Type**: `InputHandler` | **File**: `Material3.fs:6140`

#### Type Definition
```fsharp
type KeyBinding = {
    Key: SpecialKey
    Modifiers: KeyModifier list
    Action: string
    Description: string
}

type InputHandler = {
    Bindings: KeyBinding list
    Mode: string
    CapturesMouse: bool
    CapturesPaste: bool
}
```

#### Visual Example
```
Input Mode: NORMAL

Key Bindings:
  j/↓         Move down
  k/↑         Move up
  Enter       Select item
  /           Search mode
  q/Esc       Quit
  Ctrl+C      Force quit
  ?           Show help

Mouse: Enabled (click to select, scroll to navigate)
```

---

### 5. TermRenderer (SC-HMI-032, SC-HMI-033)

**Type**: `TermRenderer` module | **File**: `Material3.fs:6200`

#### Functions
```fsharp
module TermRenderer =
    /// Compute difference between two screen buffers
    let diff (oldBuf: ScreenBuffer) (newBuf: ScreenBuffer) : RenderDiff

    /// Apply diff to terminal
    let applyDiff (diff: RenderDiff) : string list

    /// Clear entire screen
    let clearScreen () : string

    /// Enter alternate screen buffer
    let enterAltScreen () : string

    /// Exit alternate screen buffer
    let exitAltScreen () : string

    /// Enable mouse tracking
    let enableMouse () : string

    /// Disable mouse tracking
    let disableMouse () : string

    /// Move cursor to position
    let moveCursor (x: int) (y: int) : string

    /// Show/hide cursor
    let showCursor (visible: bool) : string
```

#### Render Pipeline
```
State Change → New Buffer → Diff vs Old → ANSI Sequences → Terminal

Optimization: Only changed cells are redrawn (differential rendering)

ANSI Escape Sequences:
  \x1b[2J     Clear screen
  \x1b[H      Home cursor
  \x1b[?1049h Enter alt screen
  \x1b[?1049l Exit alt screen
  \x1b[?1000h Enable mouse
  \x1b[38;2;R;G;Bm  Set RGB foreground
  \x1b[48;2;R;G;Bm  Set RGB background
```

---

## Podman-TUI Components

Inspired by [podman-tui](https://github.com/containers/podman-tui), a terminal UI for managing containers. These components provide comprehensive container orchestration UI capabilities.

### PodmanStyle (SC-HMI-043)

**Type**: `PodmanStyle` module | **File**: `Material3.fs:7370`

Defines the color palette and symbol system for container management UI.

```fsharp
module PodmanStyle =
    let palette = {|
        Foreground = RGB(255, 250, 240)   // Floral white text
        Background = RGB(28, 28, 28)       // Near black
        Running = RGB(95, 215, 0)          // Bright green
        Paused = RGB(255, 175, 0)          // Amber
        Stopped = RGB(128, 128, 128)       // Gray
        Error = RGB(215, 0, 0)             // Red
        Created = RGB(135, 206, 250)       // Light sky blue
        Healthy = RGB(0, 255, 127)         // Spring green
        Unhealthy = RGB(255, 69, 0)        // Orange red
        Border = RGB(68, 68, 68)           // Dark gray
        Highlight = RGB(70, 130, 180)      // Steel blue
        Header = RGB(175, 175, 175)        // Light gray
    |}

    let symbols = {|
        CheckMark = "✔"
        CrossMark = "✘"
        Running = "▶"
        Paused = "⏸"
        Stopped = "⏹"
        Container = "⬡"    // Hexagon (container shape)
        Pod = "⬢"          // Filled hexagon (pod = group)
        Volume = "▣"       // Box (storage)
        Network = "◎"      // Concentric circles (network)
        Image = "◫"        // Layers
        Secret = "🔒"      // Lock
    |}
```

### InfoBar (SC-HMI-044)

**Type**: `InfoBar` record + module | **File**: `Material3.fs:7430`

System information bar showing container counts and resource usage.

```
┌─ PODMAN INFO ────────────────────────────────────────────────────────────────┐
│ Containers: 5 running, 2 paused, 3 stopped │ Images: 42 │ Pods: 2            │
│ CPU: ███████░░░ 72%  Memory: █████░░░░░ 54% (2.3G/4.2G)  Disk: ████████░░ 82%│
└──────────────────────────────────────────────────────────────────────────────┘
```

### CommandDialog (SC-HMI-045)

**Type**: `CommandDialog` record + module | **File**: `Material3.fs:7480`

Command execution interface with live output streaming.

```
┌─ EXECUTE COMMAND ──────────────────────────┐
│                                            │
│ Command: podman exec -it container_name sh │
│                                            │
│ Working directory: /home/user              │
│ Environment: [Add variable...]             │
│                                            │
│ ○ Interactive  ○ Detached  ● Tty           │
│                                            │
│        [EXECUTE]         [CANCEL]          │
└────────────────────────────────────────────┘
```

### ConfirmDialog (SC-HMI-046)

**Type**: `ConfirmDialog` record + module | **File**: `Material3.fs:7535`

Two-step confirmation dialog for destructive operations.

```
┌─ ⚠ CONFIRM REMOVAL ────────────────────────┐
│                                            │
│ Are you sure you want to remove container  │
│ "webapp-prod" and all associated volumes?  │
│                                            │
│ This action cannot be undone.              │
│                                            │
│ ◎ ARMED [4s] - Press Enter to confirm      │
│                                            │
│          [CONFIRM]        [CANCEL]         │
└────────────────────────────────────────────┘
```

### ErrorDialog (SC-HMI-047)

**Type**: `ErrorDialog` record + module | **File**: `Material3.fs:7585`

Error message display with severity levels and stack traces.

```
┌─ ⛔ ERROR ──────────────────────────────────┐
│                                            │
│ Failed to start container "webapp"         │
│                                            │
│ Error: port 8080 already in use            │
│                                            │
│ Stack Trace:                               │
│   at Container.Start() line 142            │
│   at Runtime.Execute() line 89             │
│                                            │
│ [▼ Show Details]                           │
│                                            │
│                   [DISMISS]                │
└────────────────────────────────────────────┘
```

### ProgressDialog (SC-HMI-048)

**Type**: `ProgressDialog` record + module | **File**: `Material3.fs:7635`

Multi-stage progress indicator for long-running operations.

```
┌─ PULLING IMAGE ────────────────────────────┐
│                                            │
│ docker.io/library/nginx:latest             │
│                                            │
│ Stage: Downloading layer 3/5               │
│ [████████████████░░░░░░░░░░░░░░░░] 52%     │
│                                            │
│ Downloaded: 45.2 MB / 86.7 MB              │
│ Speed: 12.3 MB/s                           │
│ ETA: 3s                                    │
│                                            │
│                  [CANCEL]                  │
└────────────────────────────────────────────┘
```

### ContainerView (SC-HMI-049)

**Type**: `ContainerView` record + module | **File**: `Material3.fs:7690`

Container management view with status, resources, and quick actions.

```
┌─ CONTAINERS ─────────────────────────────────────────────────────────────────┐
│  STATUS   NAME              IMAGE                    PORTS         CPU   MEM │
├──────────────────────────────────────────────────────────────────────────────┤
│  ▶ Running webapp          nginx:latest             0.0.0.0:80    2.1%  128M│
│  ▶ Running db              postgres:15              5432          5.3%  512M│
│  ⏸ Paused  cache           redis:alpine             6379          0.0%   64M│
│  ⏹ Stopped worker          node:18                  -             0.0%    0M│
│  ▶ Running monitor         prometheus:latest        9090          1.2%  256M│
├──────────────────────────────────────────────────────────────────────────────┤
│ [s]tart [S]top [r]estart [p]ause [R]emove [l]ogs [e]xec [i]nspect          │
└──────────────────────────────────────────────────────────────────────────────┘
```

### PodView (SC-HMI-050)

**Type**: `PodView` record + module | **File**: `Material3.fs:7745`

Pod management showing grouped containers.

```
┌─ PODS ───────────────────────────────────────────────────────────────────────┐
│  STATUS   NAME              CONTAINERS    CREATED         INFRA              │
├──────────────────────────────────────────────────────────────────────────────┤
│  ⬢ Running  web-stack       3/3           2 hours ago     k8s-pause         │
│    └─ webapp, nginx, cache                                                   │
│  ⬢ Running  monitoring      2/2           1 day ago       k8s-pause         │
│    └─ prometheus, grafana                                                    │
│  ⬢ Degraded db-cluster      2/3           3 days ago      k8s-pause         │
│    └─ postgres-1, postgres-2, [⛔ postgres-3]                                │
├──────────────────────────────────────────────────────────────────────────────┤
│ [c]reate [s]tart [S]top [r]estart [R]emove [i]nspect                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### VolumeView (SC-HMI-051)

**Type**: `VolumeView` record + module | **File**: `Material3.fs:7795`

Volume management with usage statistics.

```
┌─ VOLUMES ────────────────────────────────────────────────────────────────────┐
│  NAME                DRIVER    SIZE      MOUNT POINT          IN USE         │
├──────────────────────────────────────────────────────────────────────────────┤
│  ▣ db-data           local     2.3 GB    /var/lib/postgresql  ● yes (db)    │
│  ▣ app-logs          local     156 MB    /var/log/app         ● yes (webapp)│
│  ▣ cache-data        local     64 MB     /data                ○ no          │
│  ▣ backup-2024       local     5.1 GB    /backups             ○ no          │
├──────────────────────────────────────────────────────────────────────────────┤
│ [c]reate [R]emove [i]nspect [p]rune unused                                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### ImageView (SC-HMI-052)

**Type**: `ImageView` record + module | **File**: `Material3.fs:7850`

Container image browser with layer information.

```
┌─ IMAGES ─────────────────────────────────────────────────────────────────────┐
│  REPOSITORY              TAG       IMAGE ID      SIZE      CREATED           │
├──────────────────────────────────────────────────────────────────────────────┤
│  ◫ nginx                 latest    a1b2c3d4      142 MB    2 days ago       │
│  ◫ postgres              15        e5f6g7h8      412 MB    1 week ago       │
│  ◫ redis                 alpine    i9j0k1l2      32 MB     3 days ago       │
│  ◫ node                  18        m3n4o5p6      998 MB    5 days ago       │
│  ◫ <none>                <none>    q7r8s9t0      256 MB    1 month ago      │
├──────────────────────────────────────────────────────────────────────────────┤
│ [p]ull [b]uild [R]emove [i]nspect [h]istory [t]ag [P]rune                   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### NetworkView (SC-HMI-053)

**Type**: `NetworkView` record + module | **File**: `Material3.fs:7905`

Network configuration and container connectivity.

```
┌─ NETWORKS ───────────────────────────────────────────────────────────────────┐
│  NAME              DRIVER    SCOPE     SUBNET            CONTAINERS          │
├──────────────────────────────────────────────────────────────────────────────┤
│  ◎ bridge          bridge    local     172.17.0.0/16     3 connected        │
│  ◎ host            host      local     -                 -                   │
│  ◎ app-network     bridge    local     172.20.0.0/16     4 connected        │
│  ◎ db-network      bridge    local     172.21.0.0/16     2 connected        │
├──────────────────────────────────────────────────────────────────────────────┤
│ [c]reate [R]emove [i]nspect [conn]ect [disc]onnect [p]rune                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### SecretsView (SC-HMI-054)

**Type**: `SecretsView` record + module | **File**: `Material3.fs:7955`

Secrets management with masked values.

```
┌─ SECRETS ────────────────────────────────────────────────────────────────────┐
│  NAME                CREATED           UPDATED           IN USE              │
├──────────────────────────────────────────────────────────────────────────────┤
│  🔒 db-password      2024-01-15        2024-12-20        ● db, webapp       │
│  🔒 api-key          2024-03-01        2024-12-01        ● webapp           │
│  🔒 tls-cert         2024-06-15        2024-06-15        ● nginx            │
│  🔒 jwt-secret       2024-09-01        2024-09-01        ○ none             │
├──────────────────────────────────────────────────────────────────────────────┤
│ [c]reate [R]emove [i]nspect [r]otate                                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### SystemView (SC-HMI-055)

**Type**: `SystemView` record + module | **File**: `Material3.fs:8005`

System status overview with runtime information.

```
┌─ SYSTEM STATUS ──────────────────────────────────────────────────────────────┐
│                                                                              │
│  Podman Version: 5.4.1         Runtime: crun                                │
│  API Version: 5.0.0            OS: linux/amd64                              │
│  Storage Driver: overlay        Root: /home/user/.local/share/containers    │
│                                                                              │
│  ┌─ RESOURCES ─────────────────────────────────────────────────────────────┐│
│  │ Containers:  5 running  2 paused  3 stopped  0 created                  ││
│  │ Images:      42 total   12 in use  8.2 GB used                          ││
│  │ Volumes:     8 total    5 in use   7.6 GB used                          ││
│  │ Networks:    4 total    3 in use                                        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  Uptime: 15 days, 4 hours                                                   │
│  Events: 1,234 total │ 42 today                                             │
│                                                                              │
│  [r]efresh [e]vents [d]isk usage [p]rune all                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### FunctionKeyBar (SC-HMI-056)

**Type**: `FunctionKeyBar` record + module | **File**: `Material3.fs:8060`

F-key menu bar at bottom of screen.

```
F1:Help F2:Menu F3:Search F4:Filter F5:Refresh F6:Sort F7:Create F8:Remove F10:Quit
```

### CommandMenu (SC-HMI-057)

**Type**: `CommandMenu` record + module | **File**: `Material3.fs:8110`

Slide-out command menu with categorized actions.

```
┌─ COMMANDS ──────┐
│ Container       │
│  ├─ Start      │
│  ├─ Stop       │
│  ├─ Restart    │
│  ├─ Pause      │
│  ├─ Remove     │
│  └─ Logs       │
│ Image          │
│  ├─ Pull       │
│  ├─ Build      │
│  └─ Remove     │
│ System         │
│  ├─ Prune      │
│  └─ Events     │
└─────────────────┘
```

### SortDialog (SC-HMI-058)

**Type**: `SortDialog` record + module | **File**: `Material3.fs:8165`

Column sort selection dialog.

```
┌─ SORT BY ──────────────────────┐
│                                │
│  ○ Name (A-Z)                  │
│  ○ Name (Z-A)                  │
│  ● Status                      │
│  ○ Created (Newest)            │
│  ○ Created (Oldest)            │
│  ○ Size (Largest)              │
│  ○ Size (Smallest)             │
│                                │
│        [APPLY]    [CANCEL]     │
└────────────────────────────────┘
```

### FilterPanel (SC-HMI-059)

**Type**: `FilterPanel` record + module | **File**: `Material3.fs:8215`

Multi-criteria filter panel.

```
┌─ FILTERS ──────────────────────────────────────┐
│                                                │
│ Status: [✓] Running [✓] Paused [ ] Stopped     │
│                                                │
│ Name contains: [webapp_____________]           │
│                                                │
│ Image: [nginx:*________________]               │
│                                                │
│ Labels: [environment=prod______]               │
│                                                │
│ Created: [Last 7 days     ▼]                   │
│                                                │
│         [APPLY]  [RESET]  [CANCEL]             │
└────────────────────────────────────────────────┘
```

### PodmanLogViewer (SC-HMI-060)

**Type**: `PodmanLogViewer` record + module | **File**: `Material3.fs:7865`

Container log display with follow-tail and filtering.

```
┌─ LOGS: webapp ───────────────────────────────────────────────────────────────┐
│                                                                              │
│ 14:32:45.123 I Starting nginx...                                            │
│ 14:32:45.234 I Loading configuration from /etc/nginx/nginx.conf             │
│ 14:32:45.456 I Listening on 0.0.0.0:80                                       │
│ 14:32:46.789 I Worker process started (pid: 42)                              │
│ 14:33:01.234 W Connection timeout from 192.168.1.100                         │
│ 14:33:15.567 I GET /api/health 200 12ms                                      │
│ 14:33:16.890 I GET /api/users 200 45ms                                       │
│ 14:33:17.123 E Failed to connect to upstream: db:5432                        │
│ 14:33:17.456 I Retrying upstream connection...                               │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ ◉ Tail                                                                       │
└──────────────────────────────────────────────────────────────────────────────┘

Log Levels: D=Debug, I=Info, W=Warning, E=Error, F=Fatal
```

---

## Proxmox VE Components

PRAJNA integrates comprehensive Proxmox VE virtualization management components, enabling full datacenter orchestration from within the CLI cockpit. These components provide visibility and control over VMs, containers, storage, networking, and high-availability clusters.

### Component Index (SC-HMI-061 to SC-HMI-080)

| ID | Component | Purpose | STAMP Constraint |
|----|-----------|---------|------------------|
| SC-HMI-061 | ProxmoxStyle | Dark theme color palette for Proxmox displays | Color accessibility |
| SC-HMI-062 | ClusterView | Cluster status with quorum and HA state | Quorum visibility |
| SC-HMI-063 | NodeView | Physical node resources and services | Resource monitoring |
| SC-HMI-064 | VMView | Virtual machine listing with status | VM lifecycle visibility |
| SC-HMI-065 | ContainerLxcView | LXC container management | Container isolation |
| SC-HMI-066 | StorageView | Storage pools and disk usage | Capacity planning |
| SC-HMI-067 | BackupView | Backup jobs, schedules, and restore | Data protection visibility |
| SC-HMI-068 | HAView | High Availability groups and failover | HA state awareness |
| SC-HMI-069 | FirewallView | Firewall rules and security groups | Security rule visibility |
| SC-HMI-070 | UserView | Users, groups, and permissions | Access control |
| SC-HMI-071 | CephView | Ceph cluster OSD/MON/MDS status | Distributed storage health |
| SC-HMI-072 | NetworkSdnView | SDN zones and VNets configuration | Network topology |
| SC-HMI-073 | ReplicationView | Storage replication jobs and status | DR visibility |
| SC-HMI-074 | TaskView | Running and historical tasks | Task progress tracking |
| SC-HMI-075 | DatacenterView | Global datacenter summary | Executive overview |
| SC-HMI-076 | ResourcePoolView | Resource pool quotas and members | Resource governance |
| SC-HMI-077 | SnapshotManagerView | VM/CT snapshots with rollback | Point-in-time recovery |
| SC-HMI-078 | MigrationDialog | Live migration two-step commit | Safe VM migration |
| SC-HMI-079 | ConsoleView | VM/CT console access options | Remote access |
| SC-HMI-080 | MetricsView | Resource utilization graphs | Performance monitoring |

### ProxmoxStyle - Dark Theme Palette (SC-HMI-061)

```fsharp
module ProxmoxStyle =
    // Proxmox VE branded dark theme
    let palette = {|
        Primary = rgb 95 115 135       // Proxmox blue-gray
        Background = rgb 30 30 30      // Dark charcoal
        Surface = rgb 45 45 45         // Card surface
        Text = rgb 220 220 220         // Light text
        Muted = rgb 128 128 128        // Secondary text
        Running = rgb 76 175 80        // Green
        Stopped = rgb 244 67 54        // Red
        Paused = rgb 255 193 7         // Yellow
        Warning = rgb 255 193 7        // Amber
        Critical = rgb 244 67 54       // Red
        Offline = rgb 158 158 158      // Gray
    |}

    let symbols = {|
        // Resource types
        VM = "🖥"
        Container = "📦"
        Node = "🖧"
        Storage = "💾"
        Network = "🔗"
        Pool = "📁"
        Cluster = "☁"
        Backup = "💿"
        Snapshot = "📸"
        Template = "📋"
        ISO = "💿"

        // Status
        Running = "▶"
        Stopped = "⏹"
        Paused = "⏸"
        Starting = "⏳"
        Stopping = "⏳"
        Migrating = "↔"
        Locked = "🔒"
        HA = "♥"
    |}
```

### ClusterView - Cluster Dashboard (SC-HMI-062)

```
┌─ PROXMOX CLUSTER: production-cluster ──────────────────────────────────────┐
│ Status: ● HEALTHY    Nodes: 3/3 Online    Quorum: ✓ (3 votes)              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  NODE           STATUS     CPU       MEMORY      STORAGE    VMs    CTs    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ● pve-node-01  Online    ▓▓▓░ 42%  ▓▓▓▓▓░ 68%  ▓▓▓░░ 45%   12     8     │
│  ● pve-node-02  Online    ▓▓░░ 28%  ▓▓▓▓░░ 52%  ▓▓▓▓░ 62%   10     5     │
│  ● pve-node-03  Online    ▓▓▓▓ 65%  ▓▓▓▓▓▓ 78%  ▓▓░░░ 31%    8     6     │
│                                                                             │
│  Cluster Resources:  CPU: 45% avg │ Memory: 66% avg │ Storage: 46% avg    │
│  HA Status: ♥ Active (2 groups)   │ Replication: ✓ 3 jobs running         │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Nodes] [VMs] [Containers] [Storage] [HA] [Backups] [Datacenter]           │
└────────────────────────────────────────────────────────────────────────────┘
```

### VMView - Virtual Machine List (SC-HMI-064)

```
┌─ VIRTUAL MACHINES ─────────────────────────────────────────────────────────┐
│ Node: pve-node-01 ▼    Filter: [All ▼]    Search: [____________]           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VMID   NAME              STATUS    CPU      MEM       UPTIME    HA       │
│  ───────────────────────────────────────────────────────────────────────   │
│  100    web-server-01     ▶ Running ▓▓░ 15%  ▓▓▓░ 42%  25d 14h   ♥        │
│  101    db-primary        ▶ Running ▓▓▓░ 45% ▓▓▓▓░ 68% 25d 14h   ♥        │
│  102    db-replica        ▶ Running ▓▓░ 22%  ▓▓▓░ 38%  25d 12h   ♥        │
│  103    cache-redis       ▶ Running ▓░░ 8%   ▓▓░░ 25%  15d 4h    -        │
│  104    monitoring        ⏹ Stopped  -        -         -         -        │
│  105    dev-sandbox       ⏸ Paused   ▓░░ 5%  ▓▓░░ 18%  2d 6h     -        │
│                                                                             │
│  Total: 6 VMs (4 running, 1 stopped, 1 paused)                             │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Start] [Stop] [Migrate] [Console] [Snapshot] [Backup] [Clone]             │
└────────────────────────────────────────────────────────────────────────────┘
```

### StorageView - Storage Pools (SC-HMI-066)

```
┌─ STORAGE POOLS ────────────────────────────────────────────────────────────┐
│ [All Nodes ▼]                                                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  STORAGE         TYPE      NODES      USED / TOTAL        STATUS           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  local           dir       pve-*      ▓▓▓░░░░░  125G/500G  ● Active        │
│  local-lvm       lvmthin   pve-*      ▓▓▓▓▓░░░  420G/1.0T  ● Active        │
│  ceph-pool       rbd       pve-*      ▓▓▓▓░░░░  1.8T/5.0T  ● Active        │
│  nfs-backup      nfs       pve-node-01▓▓░░░░░░  800G/4.0T  ● Active        │
│  iscsi-san       iscsi     pve-*      ▓▓▓▓▓▓░░  1.2T/2.0T  ● Active        │
│                                                                             │
│  Content Types: images ✓  rootdir ✓  vztmpl ✓  backup ✓  iso ✓            │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Add Storage] [Remove] [Scan] [Upload ISO] [Prune Backups]                 │
└────────────────────────────────────────────────────────────────────────────┘
```

### HAView - High Availability (SC-HMI-068)

```
┌─ HIGH AVAILABILITY ────────────────────────────────────────────────────────┐
│ Cluster Status: ● HEALTHY    Quorum: ✓    Nodes: 3/3    Fencing: ✓        │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  HA GROUPS                                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  production      Nodes: pve-node-01, pve-node-02   Priority: 1             │
│    └─ vm:100     web-server-01      ● started    pve-node-01               │
│    └─ vm:101     db-primary         ● started    pve-node-01               │
│    └─ vm:102     db-replica         ● started    pve-node-02               │
│                                                                             │
│  development     Nodes: pve-node-03               Priority: 2             │
│    └─ vm:105     dev-sandbox        ● started    pve-node-03               │
│                                                                             │
│  RECENT EVENTS                                                              │
│  2025-12-27 14:32  ✓ Fence pve-node-02 succeeded                           │
│  2025-12-27 14:33  ↔ Migrating vm:101 to pve-node-01                       │
│  2025-12-27 14:35  ● vm:101 started on pve-node-01                         │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Add HA Resource] [Migrate] [Relocate] [Fence Node] [Simulate Failover]    │
└────────────────────────────────────────────────────────────────────────────┘
```

### BackupView - Backup Management (SC-HMI-067)

```
┌─ BACKUP MANAGEMENT ────────────────────────────────────────────────────────┐
│ [Jobs] [History] [Storage]                                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  BACKUP JOBS                                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ✓ daily-vms     All VMs     02:00   nfs-backup   last: ✓ 2025-12-27      │
│  ✓ weekly-full   production  Sun 04:00  nfs-backup   last: ✓ 2025-12-22   │
│  ◐ db-backup     vm:101,102  */4h    local        running... 45%          │
│                                                                             │
│  RECENT BACKUPS                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  2025-12-27 02:15  vzdump-qemu-100-2025_12_27-02_00.vma.zst    4.2 GB ✓    │
│  2025-12-27 02:18  vzdump-qemu-101-2025_12_27-02_00.vma.zst   12.8 GB ✓    │
│  2025-12-27 02:25  vzdump-qemu-102-2025_12_27-02_00.vma.zst    8.1 GB ✓    │
│  2025-12-26 02:15  vzdump-qemu-100-2025_12_26-02_00.vma.zst    4.1 GB ✓    │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Backup Now] [Restore] [Edit Job] [Prune] [Verify]                         │
└────────────────────────────────────────────────────────────────────────────┘
```

### MigrationDialog - Two-Step Migration (SC-HMI-078)

```
┌─ LIVE MIGRATION ───────────────────────────────────────────────────────────┐
│                                                                             │
│  ⚠ CRITICAL OPERATION - Two-Step Confirmation Required                     │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Source: pve-node-01                                                        │
│  Target: [pve-node-02 ▼]                                                    │
│                                                                             │
│  VM: 101 - db-primary                                                       │
│      Memory: 16 GB  │  Disk: 100 GB  │  CPU: 4 cores                       │
│                                                                             │
│  Migration Type: (●) Online  ( ) Offline                                    │
│                                                                             │
│  Options:                                                                   │
│  [✓] With local disks    [✓] Compressed                                    │
│  Target storage: [same ▼]                                                   │
│  Bandwidth limit: [unlimited] MiB/s                                         │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ◎ ARMED - Press Enter to confirm migration                                │
│                                                                             │
│        [● MIGRATE]                    [CANCEL]                              │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### CephView - Ceph Cluster Status (SC-HMI-071)

```
┌─ CEPH CLUSTER ─────────────────────────────────────────────────────────────┐
│ Status: ● HEALTH_OK    FSID: a1b2c3d4-...                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Status] [OSDs] [Monitors] [Pools]                                         │
│                                                                             │
│  MONITORS                                                                   │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ● pve-node-01    Leader     Last Sync: 0.2s ago                           │
│  ● pve-node-02    Follower   Last Sync: 0.3s ago                           │
│  ● pve-node-03    Follower   Last Sync: 0.5s ago                           │
│                                                                             │
│  OSDs (12 total)                                                            │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ● up+in: 12    ◐ up+out: 0    ○ down: 0                                   │
│  Total: 24 TB   Used: 8.4 TB (35%)   Available: 15.6 TB                    │
│                                                                             │
│  POOLS                                                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  ceph-pool       ▓▓▓▓░░░░░░  1.8 TB / 5 TB    replicated x3               │
│  ceph-ec-pool    ▓▓░░░░░░░░  800 GB / 4 TB    erasure 4+2                  │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Add OSD] [Remove OSD] [Create Pool] [Crush Map] [Scrub]                   │
└────────────────────────────────────────────────────────────────────────────┘
```

### MetricsView - Resource Metrics (SC-HMI-080)

```
┌─ RESOURCE METRICS ─────────────────────────────────────────────────────────┐
│ Target: vm:101 db-primary    Period: [Last 24h ▼]                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CPU UTILIZATION (4 cores)                                                  │
│  100% ─┤     ╭─╮                  ╭──╮                                     │
│   75% ─┤  ╭──╯ ╰─╮    ╭──╮   ╭──╯  ╰──╮                                   │
│   50% ─┤ ╭╯      ╰────╯  ╰───╯        ╰───╮                                │
│   25% ─┤─╯                                 ╰────                            │
│    0% ─┼────┬────┬────┬────┬────┬────┬────┬────                            │
│        00   03   06   09   12   15   18   21   now                          │
│  Current: 45%  │  Avg: 38%  │  Peak: 82%                                   │
│                                                                             │
│  MEMORY UTILIZATION (16 GB)                                                 │
│  100% ─┤────────────────────────────────────                               │
│   75% ─┤▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                               │
│   50% ─┤                                                                    │
│   25% ─┤                                                                    │
│    0% ─┼────┬────┬────┬────┬────┬────┬────┬────                            │
│  Current: 68%  │  Avg: 65%  │  Peak: 72%                                   │
│                                                                             │
│  DISK I/O                                      NETWORK                      │
│  Read:  ▓▓▓░░░░░ 45 MB/s                       RX: ▓▓░░░░ 12 Mbps          │
│  Write: ▓▓░░░░░░ 22 MB/s                       TX: ▓░░░░░  5 Mbps          │
│                                                                             │
├────────────────────────────────────────────────────────────────────────────┤
│ [Export CSV] [Compare] [Alerts] [RRD Archive]                               │
└────────────────────────────────────────────────────────────────────────────┘
```

### CLI Tool Integration

PRAJNA can invoke Proxmox CLI tools directly for management operations:

| Tool | Purpose | Example Command |
|------|---------|-----------------|
| `pvecm` | Cluster management | `pvecm status`, `pvecm add node` |
| `qm` | VM management | `qm start 100`, `qm migrate 101 pve-node-02` |
| `pct` | Container management | `pct start 200`, `pct snapshot 201 snap1` |
| `pvesm` | Storage management | `pvesm status`, `pvesm add nfs` |
| `vzdump` | Backup operations | `vzdump 100 --storage nfs-backup` |
| `qmrestore` | VM restore | `qmrestore backup.vma 100` |
| `ha-manager` | HA operations | `ha-manager add vm:100 --group production` |
| `pveum` | User management | `pveum user add user@pve`, `pveum acl modify` |
| `pve-firewall` | Firewall rules | `pve-firewall compile`, `pve-firewall status` |

---

## References

### Material Design 3

- [Material Design 3](https://m3.material.io/) - Official M3 documentation
- [M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive) - Spring animations, shape morphing
- [M3 Components](https://m3.material.io/components) - Component specifications
- [M3 Color System](https://m3.material.io/styles/color) - Dark/light theme tokens

### Aviation Standards

- [NASA-STD-3000](https://msis.jsc.nasa.gov/) - Man-Systems Integration Standards
- [FAA AC 25-11B](https://www.faa.gov/regulations_policies/advisory_circulars/) - Electronic Displays
- [FAA TSO-C2d](https://rgl.faa.gov/) - Airspeed Indicator
- [FAA TSO-C36e](https://rgl.faa.gov/) - Gyroscopic Direction Indicator
- [FAA TSO-C45a](https://rgl.faa.gov/) - Engine Instruments (EICAS)
- [FAA TSO-C46c](https://rgl.faa.gov/) - Landing Gear Position Indicator
- [FAA TSO-C119c](https://rgl.faa.gov/) - TCAS II
- [SAE AS8034A](https://www.sae.org/) - Annunciator Systems

### Industrial HMI

- [ISA-101](https://www.isa.org/standards-and-publications/isa-standards/isa-standards-committees/isa101) - HMI design standards
- [NUREG-0700](https://www.nrc.gov/reading-rm/doc-collections/nuregs/staff/sr0700/) - Nuclear control room HMI
- [IEC 61508](https://www.iec.ch/functional-safety) - Functional Safety

### TUI Frameworks

- [Ratatui](https://ratatui.rs/) - Rust TUI framework
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) - Go TUI framework
- [Bubbles](https://github.com/charmbracelet/bubbles) - TUI components for Bubble Tea (inspiration for Paginator, Viewport, FilePicker, Timer, Stopwatch, Help, FuzzyFilter)
- [Bubbleboxer](https://github.com/treilik/bubbleboxer) - Layout composition for Bubble Tea (inspiration for LayoutBoxer)
- [Lip Gloss](https://github.com/charmbracelet/lipgloss) - Style definitions for TUIs
- [Tview](https://github.com/rivo/tview) - Go terminal UI (inspiration for TreeView, TextArea, SplitView, ApplicationFrame)
- [LXZ](https://github.com/liangzhaoliang95/lxz) - DevOps CLI tool (inspiration for DataBrowser, QueryPanel, LogViewer, FileBrowser, ConnectionManager)
- [Cobra](https://github.com/spf13/cobra) - Go CLI framework (inspiration for CliFlag, CliCommand, Completion)
- [Tcell](https://github.com/gdamore/tcell) - Go terminal library (inspiration for TermColor, CellStyle, ScreenBuffer, TermEvent, TermRenderer)
- [Podman-TUI](https://github.com/containers/podman-tui) - Terminal UI for container management (inspiration for PodmanStyle, InfoBar, CommandDialog, ConfirmDialog, ErrorDialog, ProgressDialog, ContainerView, PodView, VolumeView, ImageView, NetworkView, SecretsView, SystemView, FunctionKeyBar, CommandMenu, SortDialog, FilterPanel, PodmanLogViewer)

### Proxmox VE

- [Proxmox VE](https://www.proxmox.com/en/proxmox-virtual-environment) - Open-source virtualization platform
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/) - Official documentation
- [Proxmox VE Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html) - Administration guide
- [Proxmox VE API Viewer](https://pve.proxmox.com/pve-docs/api-viewer/) - REST API reference
- [pvecm](https://pve.proxmox.com/pve-docs/pvecm.1.html) - Cluster management CLI
- [qm](https://pve.proxmox.com/pve-docs/qm.1.html) - QEMU/KVM VM management CLI
- [pct](https://pve.proxmox.com/pve-docs/pct.1.html) - LXC container management CLI
- [pvesm](https://pve.proxmox.com/pve-docs/pvesm.1.html) - Storage management CLI
- [vzdump](https://pve.proxmox.com/pve-docs/vzdump.1.html) - Backup utility
- [ha-manager](https://pve.proxmox.com/pve-docs/ha-manager.1.html) - HA management CLI

### Apple Human Interface Guidelines

- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines) - Official Apple design guidelines
- [HIG Foundations](https://developer.apple.com/design/human-interface-guidelines/foundations) - Color, typography, accessibility
- [HIG Patterns](https://developer.apple.com/design/human-interface-guidelines/patterns) - Navigation, feedback, data entry
- [HIG Components](https://developer.apple.com/design/human-interface-guidelines/components) - Buttons, controls, indicators

### Accessibility Standards

- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/) - Web Content Accessibility Guidelines
- [WCAG Contrast](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) - Minimum contrast requirements (4.5:1)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-27 | Initial M3 components (45) |
| 2.0.0 | 2025-12-28 | Added 10 Dark UI components (Industrial HMI, Aviation EFIS) |
| 3.0.0 | 2025-12-28 | Added 14 Aviation Cockpit components + comprehensive documentation |
| 3.1.0 | 2025-12-28 | Complete behavior documentation, functional modes, usage guidelines |
| 4.0.0 | 2025-12-28 | AI/ML Intelligence Integration section - contextual awareness, predictive components, PRAJNA Copilot integration |
| 5.0.0 | 2025-12-28 | Bubbles-inspired components (7): Paginator, Viewport, FilePicker, Timer, Stopwatch, Help, FuzzyFilter |
| 6.0.0 | 2025-12-28 | Layout Composition System (LayoutBoxer): tree-based layouts, H/V splits, flexible sizing, addressable nodes |
| 7.0.0 | 2025-12-28 | Apple HIG-Inspired Design System (10 modules): Accessibility (WCAG 2.1), FeedbackTiming, Navigation (2-keypress), HighContrast, AlertHierarchy, FocusManagement, TypographyScale, SemanticStates, Motion, HIG entry point |
| 8.0.0 | 2025-12-28 | Tview-Inspired Components (4): TreeView, TextArea, SplitView, ApplicationFrame |
| 9.0.0 | 2025-12-28 | LXZ DevOps Components (9), Cobra CLI Framework (3), Tcell Terminal Rendering (5): DataBrowser, QueryPanel, LogViewer, FileBrowser, ConnectionManager, ActionPanel, FlashMessage, SplashScreen, StatusBar, CliFlag, CliCommand, Completion, TermColor, CellStyle, ScreenBuffer, TermEvent, InputHandler, TermRenderer |
| 10.0.0 | 2025-12-28 | Tview-Inspired Components Extended (+9): Grid (SC-HMI-034), Flexbox (SC-HMI-035), SelectableList (SC-HMI-036), Pages (SC-HMI-037), InputField (SC-HMI-038), Form (SC-HMI-039), TermImage (SC-HMI-040), Modal (SC-HMI-041), Primitives/BoxDrawing (SC-HMI-042) |
| 11.0.0 | 2025-12-28 | Podman-TUI Components (+18): PodmanStyle (SC-HMI-043), InfoBar (SC-HMI-044), CommandDialog (SC-HMI-045), ConfirmDialog (SC-HMI-046), ErrorDialog (SC-HMI-047), ProgressDialog (SC-HMI-048), ContainerView (SC-HMI-049), PodView (SC-HMI-050), VolumeView (SC-HMI-051), ImageView (SC-HMI-052), NetworkView (SC-HMI-053), SecretsView (SC-HMI-054), SystemView (SC-HMI-055), FunctionKeyBar (SC-HMI-056), CommandMenu (SC-HMI-057), SortDialog (SC-HMI-058), FilterPanel (SC-HMI-059), PodmanLogViewer (SC-HMI-060) |
| 12.0.0 | 2025-12-28 | Proxmox VE Components (+20): ProxmoxStyle (SC-HMI-061), ClusterView (SC-HMI-062), NodeView (SC-HMI-063), VMView (SC-HMI-064), ContainerLxcView (SC-HMI-065), StorageView (SC-HMI-066), BackupView (SC-HMI-067), HAView (SC-HMI-068), FirewallView (SC-HMI-069), UserView (SC-HMI-070), CephView (SC-HMI-071), NetworkSdnView (SC-HMI-072), ReplicationView (SC-HMI-073), TaskView (SC-HMI-074), DatacenterView (SC-HMI-075), ResourcePoolView (SC-HMI-076), SnapshotManagerView (SC-HMI-077), MigrationDialog (SC-HMI-078), ConsoleView (SC-HMI-079), MetricsView (SC-HMI-080) |

---

**Compliance**: SC-HMI-001 to SC-HMI-080, SC-AI-001 to SC-AI-006 | **Standards**: Material3, FAA TSO, NASA-STD-3000, NUREG-0700, Bubbles/Charm, Bubbleboxer, Apple HIG, WCAG 2.1, LXZ, Cobra, Tcell, Tview, Podman-TUI, Proxmox VE
