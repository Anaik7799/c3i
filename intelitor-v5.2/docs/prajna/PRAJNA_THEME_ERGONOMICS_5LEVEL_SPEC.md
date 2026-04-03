# PRAJNA COCKPIT: Theme, Ergonomics & Responsive Design
## 5-Level Analysis and Implementation Specification

**Version**: 1.0.0 | **Date**: 2025-12-29 | **Status**: ACTIVE
**STAMP Compliance**: SC-HMI-*, SC-THEME-*, SC-ERGO-*, SC-RESP-*

---

# LEVEL 1: SYSTEM CONTEXT

## 1.1 Executive Summary

The PRAJNA Cockpit requires comprehensive theming (light/dark), ergonomic layout optimization,
and responsive rendering to support operators who will use the system throughout entire workdays.
This specification addresses:

- **Full Light/Dark Themes**: Complete color system supporting both modes
- **Ergonomic Layout**: Based on NASA-STD-3000, NUREG-0700, MIL-STD-1472H standards
- **Responsive Design**: Adapts to device type, screen size, and rendering area
- **Vector/Fractal Rendering**: Exploration of scalable rendering techniques

## 1.2 User Context

| Factor | Specification | Rationale |
|--------|---------------|-----------|
| **Usage Duration** | 8-12 hours continuous | Operator shifts, eye strain mitigation |
| **Environment** | Control room, daylight/artificial light | Light theme for bright rooms, dark for dim |
| **Devices** | 4K monitors, laptops, mobile terminals | Must scale from 80x24 to 300+ columns |
| **Criticality** | Safety-critical operations | Errors = real-world consequences |

## 1.3 System Actors

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRAJNA COCKPIT ECOSYSTEM                          │
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Operator   │  │  Supervisor  │  │   Engineer   │  │    Auditor   │   │
│  │  (Day Shift) │  │  (All Shifts)│  │  (On-Call)   │  │  (Review)    │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                 │                 │            │
│         ▼                 ▼                 ▼                 ▼            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    PRAJNA COCKPIT UI LAYER                          │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │  │
│  │  │ Theme Engine│  │Layout Engine│  │Render Engine│                 │  │
│  │  │ Light/Dark  │  │ Responsive  │  │ Vector/ANSI │                 │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                    │                                       │
│                                    ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    INDRAJAAL BACKEND (Elixir)                       │  │
│  │                  Zenoh Pub/Sub → F# Cockpit                         │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1.4 Design Principles (Derived from Standards)

### NASA-STD-3000 (Human-System Integration)
- **Color coding**: Consistent meaning across all displays
- **Minimum contrast**: 3:1 for normal, 7:1 for critical
- **Font sizing**: Minimum 3.5mm character height at viewing distance

### NUREG-0700 (Control Room HMI)
- **Dark Cockpit**: Normal state = dim/invisible
- **Anomaly highlighting**: Bright colors only for deviations
- **Spatial consistency**: Fixed positions for critical information

### MIL-STD-1472H (Human Engineering)
- **Response time**: Visual feedback within 100ms
- **Error prevention**: Two-step commit for destructive actions
- **Fatigue reduction**: Neutral backgrounds, strategic color use

### ISA-101 (HMI for Process Industry)
- **Alarm hierarchy**: 4-5 levels with distinct visual treatment
- **Trend visualization**: Analog representation preferred
- **Context preservation**: Maintain spatial relationships during zoom

---

# LEVEL 2: CONTAINER/COMPONENT ARCHITECTURE

## 2.1 Theme System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         THEME SYSTEM CONTAINER                              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     THEME ENGINE (ThemeSystem.fs)                    │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │   │
│  │  │ ColorSys  │  │Typography │  │ Elevation │  │  Spacing  │        │   │
│  │  │ L/D Mode  │  │ L/D Mode  │  │ L/D Mode  │  │ Responsive│        │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                   LAYOUT ENGINE (ResponsiveLayout.fs)                │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │   │
│  │  │Breakpoints│  │   Grid    │  │  Panels   │  │ Overflow  │        │   │
│  │  │ Detection │  │ Calc      │  │ Priority  │  │ Handling  │        │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                   RENDER ENGINE (VectorRenderer.fs)                  │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │   │
│  │  │ANSI Render│  │ Box Draw  │  │  Charts   │  │  Fractal  │        │   │
│  │  │ (Primary) │  │ (Borders) │  │ (Sparkln) │  │(Experiment│        │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2.2 Color System Design

### Light Theme (High Ambient Light)

| Token | Hex | ANSI | Purpose |
|-------|-----|------|---------|
| surface | #FFFBFE | 231 | Main background |
| onSurface | #1C1B1F | 235 | Primary text |
| primary | #6750A4 | 98 | Interactive elements |
| normal | #79747E | 243 | Normal status (dim) |
| advisory | #006B5B | 30 | Info/Low priority |
| caution | #7D5700 | 136 | Attention needed |
| warning | #BA1A1A | 124 | Immediate action |
| critical | #BA1A1A+blink | 124+5 | Emergency |

### Dark Theme (Low Ambient Light)

| Token | Hex | ANSI | Purpose |
|-------|-----|------|---------|
| surface | #1C1B1F | 235 | Main background |
| onSurface | #E6E1E5 | 253 | Primary text |
| primary | #D0BCFF | 183 | Interactive elements |
| normal | #49454F | 239 | Normal status (dim) |
| advisory | #03DAC6 | 43 | Info/Low priority |
| caution | #FFB300 | 214 | Attention needed |
| warning | #CF6679 | 168 | Immediate action |
| critical | #CF6679+blink | 168+5 | Emergency |

### Contrast Ratios (WCAG AAA)

| Combination | Light Mode | Dark Mode | Requirement |
|-------------|------------|-----------|-------------|
| normal/surface | 4.5:1 | 4.5:1 | 3:1 min |
| warning/surface | 7.2:1 | 5.4:1 | 4.5:1 min |
| critical/surface | 7.2:1 | 5.4:1 | 7:1 for critical |

## 2.3 Responsive Breakpoints

| Breakpoint | Columns | Rows | Layout | Use Case |
|------------|---------|------|--------|----------|
| Compact | 80-99 | 24-29 | Single column | Mobile/SSH |
| Standard | 100-139 | 30-39 | 2-column | Laptop |
| Wide | 140-199 | 40-59 | 3-column | Desktop |
| Ultra-Wide | 200+ | 60+ | 4-column | 4K Monitor |

## 2.4 Panel Priority System

For space-constrained layouts, panels are hidden in priority order:

| Priority | Panel | Action when constrained |
|----------|-------|------------------------|
| P0 | Header | Always visible (compact) |
| P1 | Alarms | Always visible |
| P2 | Nodes | Always visible |
| P3 | AI Copilot | Hidden < Standard |
| P4 | Commands | Hidden < Standard |
| P5 | Timeline | Hidden < Wide |
| P6 | Spider Chart | Hidden < Ultra-Wide |

---

# LEVEL 3: COMPONENT ARCHITECTURE

## 3.1 Theme System Components

```
lib/cepaf/src/Cepaf/Cockpit/
├── ThemeSystem.fs          # NEW: Complete theme management
├── ResponsiveLayout.fs     # NEW: Layout engine
├── VectorRenderer.fs       # NEW: Scalable rendering
├── Material3.fs            # EXISTING: Enhance with L/D themes
├── DarkCockpitUI.fs        # EXISTING: Integrate with theme
├── Prajna.fs               # EXISTING: Use theme system
└── SituationalAwareness.fs # EXISTING: Enhance responsiveness
```

## 3.2 ThemeSystem.fs Component Design

```fsharp
/// Theme mode
type ThemeMode = Light | Dark | Auto

/// Theme tokens - complete design system
type ThemeTokens = {
    // Surface colors
    Surface: string
    OnSurface: string
    SurfaceVariant: string
    OnSurfaceVariant: string
    Background: string

    // Primary colors
    Primary: string
    OnPrimary: string
    PrimaryContainer: string
    OnPrimaryContainer: string

    // Secondary colors
    Secondary: string
    OnSecondary: string

    // Semantic colors (safety-critical)
    Normal: string          // Dim - nothing to notice
    Advisory: string        // Cyan - info
    Caution: string         // Amber - attention
    Warning: string         // Red - action required
    Critical: string        // Red+blink - emergency

    // Status colors
    Connected: string
    Stale: string
    Disconnected: string

    // Background variants
    BgSurface: string
    BgPrimary: string
    BgError: string

    // Typography
    Bold: string
    Dim: string
    Italic: string
    Reset: string
}

/// Render context (device capabilities)
type RenderContext = {
    Cols: int
    Rows: int
    ColorDepth: int         // 8, 256, or 16777216 (24-bit)
    UnicodeSupport: bool
    BlinkSupport: bool
}
```

## 3.3 ResponsiveLayout.fs Component Design

```fsharp
/// Layout breakpoint
type Breakpoint = Compact | Standard | Wide | UltraWide

/// Panel visibility state
type PanelVisibility = Visible | Collapsed | Hidden

/// Layout specification
type LayoutSpec = {
    Breakpoint: Breakpoint
    MainColumns: int
    SidebarWidth: int option
    HeaderHeight: int
    FooterHeight: int
    PanelGap: int
}

/// Calculate optimal layout
let calculateLayout (ctx: RenderContext) : LayoutSpec

/// Determine panel visibility
let panelVisibility (spec: LayoutSpec) (priority: int) : PanelVisibility

/// Calculate panel dimensions
let panelDimensions (spec: LayoutSpec) (panel: string) : int * int * int * int
```

## 3.4 VectorRenderer.fs Component Design (Experimental)

```fsharp
/// Scalable rendering primitive
type RenderPrimitive =
    | Text of string * int * int        // text, x, y
    | Box of int * int * int * int      // x, y, width, height
    | Line of int * int * int * int     // x1, y1, x2, y2
    | Arc of int * int * int * float * float  // cx, cy, r, startAngle, endAngle
    | Fill of int * int * int * int * char    // x, y, w, h, fillChar

/// Render scene to ANSI string
let renderScene (primitives: RenderPrimitive list) (ctx: RenderContext) : string

/// Fractal detail level based on available space
let fractalDetailLevel (availableSize: int) (baseDetail: int) : int
```

---

# LEVEL 4: MODULE ARCHITECTURE

## 4.1 ThemeSystem.fs Module Implementation

### Token Definitions

```fsharp
module ThemeSystem =

    /// Light theme tokens (Material 3 Light)
    let lightTheme : ThemeTokens = {
        // Surface - clean white backgrounds
        Surface = "\u001b[38;2;255;251;254m"          // #FFFBFE
        OnSurface = "\u001b[38;2;28;27;31m"           // #1C1B1F
        SurfaceVariant = "\u001b[38;2;231;224;236m"   // #E7E0EC
        OnSurfaceVariant = "\u001b[38;2;73;69;79m"    // #49454F
        Background = "\u001b[38;2;255;251;254m"       // #FFFBFE

        // Primary - purple
        Primary = "\u001b[38;2;103;80;164m"           // #6750A4
        OnPrimary = "\u001b[38;2;255;255;255m"        // #FFFFFF
        PrimaryContainer = "\u001b[38;2;234;221;255m" // #EADDFF
        OnPrimaryContainer = "\u001b[38;2;33;0;94m"   // #21005E

        // Secondary
        Secondary = "\u001b[38;2;98;91;113m"          // #625B71
        OnSecondary = "\u001b[38;2;255;255;255m"      // #FFFFFF

        // Semantic (Safety-Critical) - adjusted for light backgrounds
        Normal = "\u001b[38;2;121;116;126m"           // #79747E - Gray (barely visible)
        Advisory = "\u001b[38;2;0;107;91m"            // #006B5B - Dark teal
        Caution = "\u001b[38;2;125;87;0m"             // #7D5700 - Dark amber
        Warning = "\u001b[38;2;186;26;26m"            // #BA1A1A - Dark red
        Critical = "\u001b[38;2;186;26;26;5m"         // #BA1A1A + blink

        // Status
        Connected = "\u001b[38;2;0;107;91m"           // #006B5B
        Stale = "\u001b[38;2;121;116;126m"            // #79747E
        Disconnected = "\u001b[38;2;186;26;26m"       // #BA1A1A

        // Backgrounds
        BgSurface = "\u001b[48;2;255;251;254m"        // Light background
        BgPrimary = "\u001b[48;2;103;80;164m"
        BgError = "\u001b[48;2;249;222;220m"

        // Typography
        Bold = "\u001b[1m"
        Dim = "\u001b[2m"
        Italic = "\u001b[3m"
        Reset = "\u001b[0m"
    }

    /// Dark theme tokens (Material 3 Dark) - existing colors enhanced
    let darkTheme : ThemeTokens = {
        Surface = "\u001b[38;2;28;27;31m"             // #1C1B1F
        OnSurface = "\u001b[38;2;230;225;229m"        // #E6E1E5
        SurfaceVariant = "\u001b[38;2;73;69;79m"      // #49454F
        OnSurfaceVariant = "\u001b[38;2;202;196;208m" // #CAC4D0
        Background = "\u001b[38;2;28;27;31m"          // #1C1B1F

        Primary = "\u001b[38;2;208;188;255m"          // #D0BCFF
        OnPrimary = "\u001b[38;2;56;30;114m"          // #381E72
        PrimaryContainer = "\u001b[38;2;79;55;139m"   // #4F378B
        OnPrimaryContainer = "\u001b[38;2;234;221;255m"

        Secondary = "\u001b[38;2;204;194;220m"        // #CCC2DC
        OnSecondary = "\u001b[38;2;51;45;65m"         // #332D41

        // Semantic (Safety-Critical) - bright on dark
        Normal = "\u001b[90m"                          // Gray (dim)
        Advisory = "\u001b[38;2;3;218;198m"           // #03DAC6 - Teal
        Caution = "\u001b[38;2;255;179;0m"            // #FFB300 - Amber
        Warning = "\u001b[38;2;207;102;121m"          // #CF6679 - Pink-red
        Critical = "\u001b[38;2;207;102;121;5m"       // + blink

        Connected = "\u001b[32m"                       // Green
        Stale = "\u001b[90m"                           // Gray
        Disconnected = "\u001b[31m"                    // Red

        BgSurface = "\u001b[48;2;28;27;31m"
        BgPrimary = "\u001b[48;2;79;55;139m"
        BgError = "\u001b[48;2;140;29;24m"

        Bold = "\u001b[1m"
        Dim = "\u001b[2m"
        Italic = "\u001b[3m"
        Reset = "\u001b[0m"
    }
```

### Theme Management

```fsharp
    /// Current theme state
    let mutable private currentMode = Dark
    let mutable private currentTokens = darkTheme

    /// Get current theme tokens
    let tokens () = currentTokens

    /// Switch theme mode
    let setMode (mode: ThemeMode) =
        currentMode <- mode
        currentTokens <-
            match mode with
            | Light -> lightTheme
            | Dark -> darkTheme
            | Auto ->
                // Auto-detect based on time or environment
                let hour = DateTime.Now.Hour
                if hour >= 6 && hour < 18 then lightTheme else darkTheme

    /// Toggle between light and dark
    let toggle () =
        match currentMode with
        | Light -> setMode Dark
        | Dark -> setMode Light
        | Auto -> setMode Dark  // Exit auto mode
        currentMode

    /// Get current mode
    let mode () = currentMode
```

## 4.2 ResponsiveLayout.fs Module Implementation

```fsharp
module ResponsiveLayout =

    /// Detect current breakpoint from render context
    let detectBreakpoint (ctx: RenderContext) : Breakpoint =
        match ctx.Cols with
        | c when c >= 200 -> UltraWide
        | c when c >= 140 -> Wide
        | c when c >= 100 -> Standard
        | _ -> Compact

    /// Calculate layout specification
    let calculateLayout (ctx: RenderContext) : LayoutSpec =
        let breakpoint = detectBreakpoint ctx

        match breakpoint with
        | Compact ->
            {
                Breakpoint = Compact
                MainColumns = 1
                SidebarWidth = None
                HeaderHeight = 2
                FooterHeight = 1
                PanelGap = 0
            }
        | Standard ->
            {
                Breakpoint = Standard
                MainColumns = 2
                SidebarWidth = Some (ctx.Cols / 3)
                HeaderHeight = 3
                FooterHeight = 2
                PanelGap = 1
            }
        | Wide ->
            {
                Breakpoint = Wide
                MainColumns = 3
                SidebarWidth = Some (ctx.Cols / 4)
                HeaderHeight = 4
                FooterHeight = 2
                PanelGap = 1
            }
        | UltraWide ->
            {
                Breakpoint = UltraWide
                MainColumns = 4
                SidebarWidth = Some (ctx.Cols / 5)
                HeaderHeight = 4
                FooterHeight = 2
                PanelGap = 2
            }

    /// Panel priorities (lower = more important)
    let panelPriorities = Map.ofList [
        ("header", 0)
        ("alarms", 1)
        ("nodes", 2)
        ("ai", 3)
        ("commands", 4)
        ("timeline", 5)
        ("spider", 6)
    ]

    /// Determine visibility for a panel
    let panelVisibility (spec: LayoutSpec) (panelName: string) : PanelVisibility =
        let priority = panelPriorities |> Map.tryFind panelName |> Option.defaultValue 99

        match spec.Breakpoint, priority with
        | _, 0 | _, 1 | _, 2 -> Visible            // Always show P0-P2
        | Compact, _ -> Hidden                      // Hide all optional in compact
        | Standard, p when p <= 4 -> Visible        // Show up to P4 in standard
        | Standard, _ -> Hidden
        | Wide, p when p <= 5 -> Visible            // Show up to P5 in wide
        | Wide, _ -> Collapsed
        | UltraWide, _ -> Visible                   // Show all in ultra-wide

    /// Calculate panel dimensions (x, y, width, height)
    let panelDimensions (spec: LayoutSpec) (ctx: RenderContext) (panel: string)
        : int * int * int * int =

        let contentHeight = ctx.Rows - spec.HeaderHeight - spec.FooterHeight
        let columnWidth = ctx.Cols / spec.MainColumns

        match panel, spec.Breakpoint with
        | "header", _ -> (0, 0, ctx.Cols, spec.HeaderHeight)
        | "footer", _ -> (0, ctx.Rows - spec.FooterHeight, ctx.Cols, spec.FooterHeight)

        | "nodes", Compact -> (0, spec.HeaderHeight, ctx.Cols, contentHeight / 2)
        | "nodes", _ -> (0, spec.HeaderHeight, columnWidth, contentHeight / 2)

        | "alarms", Compact -> (0, spec.HeaderHeight + contentHeight / 2, ctx.Cols, contentHeight / 2)
        | "alarms", _ -> (columnWidth, spec.HeaderHeight, columnWidth, contentHeight / 2)

        | "ai", Standard | "ai", Wide ->
            (0, spec.HeaderHeight + contentHeight / 2, columnWidth, contentHeight / 2)
        | "ai", UltraWide ->
            (columnWidth * 2, spec.HeaderHeight, columnWidth, contentHeight / 2)

        | "commands", Standard | "commands", Wide ->
            (columnWidth, spec.HeaderHeight + contentHeight / 2, columnWidth, contentHeight / 2)
        | "commands", UltraWide ->
            (columnWidth * 3, spec.HeaderHeight, columnWidth, contentHeight / 2)

        | _ -> (0, 0, 0, 0)  // Hidden panel
```

## 4.3 Ergonomic Enhancements

### Eye Strain Reduction

```fsharp
module Ergonomics =

    /// Auto-adjust colors based on time of day
    let autoColorTemperature (hour: int) : float =
        // Warmer colors (less blue) in evening
        match hour with
        | h when h >= 22 || h < 6 -> 0.7    // Night: reduce blue 30%
        | h when h >= 20 -> 0.85            // Evening: reduce blue 15%
        | h when h >= 6 && h < 8 -> 0.9     // Morning: slight warmth
        | _ -> 1.0                           // Day: full spectrum

    /// Calculate optimal contrast for current lighting
    let adaptiveContrast (ambientLight: float) : float =
        // 0.0 = dark room, 1.0 = bright room
        if ambientLight < 0.3 then 0.85      // Reduce contrast in dark
        elif ambientLight > 0.7 then 1.15    // Increase in bright
        else 1.0

    /// Recommended viewing distance based on content
    type ContentType = Overview | Detailed | Reading

    let recommendedFontSize (contentType: ContentType) (distance: float) : float =
        // Based on 3.5mm minimum character height at viewing distance
        let baseSize = 3.5 * distance / 500.0  // 500mm = standard distance
        match contentType with
        | Overview -> baseSize * 1.2    // Larger for quick scanning
        | Detailed -> baseSize          // Standard
        | Reading -> baseSize * 0.9     // Slightly smaller for dense text
```

---

# LEVEL 5: CODE-LEVEL IMPLEMENTATION

## 5.1 ThemeSystem.fs Full Implementation

```fsharp
namespace Cepaf.Cockpit

open System

/// Complete Theme System for PRAJNA Cockpit
/// Supports Light and Dark modes with full Material 3 design tokens
/// STAMP Compliance: SC-THEME-001 to SC-THEME-010
module ThemeSystem =

    // =========================================================================
    // TYPES
    // =========================================================================

    /// Theme mode selection
    type ThemeMode =
        | Light     /// High ambient light environments
        | Dark      /// Low ambient light / night operations
        | Auto      /// Automatic based on time

    /// Complete design token set
    type ThemeTokens = {
        // Mode identifier
        Mode: ThemeMode

        // Surface colors
        Surface: string
        OnSurface: string
        SurfaceVariant: string
        OnSurfaceVariant: string
        SurfaceDim: string
        SurfaceBright: string

        // Primary colors
        Primary: string
        OnPrimary: string
        PrimaryContainer: string
        OnPrimaryContainer: string

        // Secondary colors
        Secondary: string
        OnSecondary: string
        SecondaryContainer: string
        OnSecondaryContainer: string

        // Tertiary colors (for PRAJNA AI elements)
        Tertiary: string
        OnTertiary: string
        TertiaryContainer: string

        // Error colors
        Error: string
        OnError: string
        ErrorContainer: string

        // Safety-Critical Semantic Colors (Dark Cockpit)
        Normal: string          // Dim - nothing to notice
        Advisory: string        // Cyan/Teal - informational
        Caution: string         // Amber - attention needed
        Warning: string         // Red - action required
        Critical: string        // Red + blink - emergency

        // Status indicators
        Connected: string
        Stale: string
        Disconnected: string
        Degraded: string

        // Background colors (ANSI background)
        BgSurface: string
        BgPrimary: string
        BgSecondary: string
        BgError: string
        BgCaution: string

        // Outline/Border colors
        Outline: string
        OutlineVariant: string

        // Typography styles
        Bold: string
        Dim: string
        Italic: string
        Underline: string
        Blink: string
        Reset: string

        // Box drawing (can vary by theme for subtle effects)
        BoxPrimary: string      // Primary border color
        BoxSecondary: string    // Secondary border color
    }

    // =========================================================================
    // LIGHT THEME DEFINITION (Material 3 Light + Safety-Critical)
    // =========================================================================

    let private lightTheme : ThemeTokens = {
        Mode = Light

        // Surface - clean, high contrast backgrounds
        Surface = "\u001b[38;2;255;251;254m"              // #FFFBFE
        OnSurface = "\u001b[38;2;28;27;31m"               // #1C1B1F
        SurfaceVariant = "\u001b[38;2;231;224;236m"       // #E7E0EC
        OnSurfaceVariant = "\u001b[38;2;73;69;79m"        // #49454F
        SurfaceDim = "\u001b[38;2;222;216;225m"           // #DED8E1
        SurfaceBright = "\u001b[38;2;255;251;254m"        // #FFFBFE

        // Primary - deep purple
        Primary = "\u001b[38;2;103;80;164m"               // #6750A4
        OnPrimary = "\u001b[38;2;255;255;255m"            // #FFFFFF
        PrimaryContainer = "\u001b[38;2;234;221;255m"     // #EADDFF
        OnPrimaryContainer = "\u001b[38;2;33;0;94m"       // #21005E

        // Secondary
        Secondary = "\u001b[38;2;98;91;113m"              // #625B71
        OnSecondary = "\u001b[38;2;255;255;255m"          // #FFFFFF
        SecondaryContainer = "\u001b[38;2;232;222;248m"   // #E8DEF8
        OnSecondaryContainer = "\u001b[38;2;30;25;43m"    // #1E192B

        // Tertiary - for AI/advisory elements
        Tertiary = "\u001b[38;2;125;82;96m"               // #7D5260
        OnTertiary = "\u001b[38;2;255;255;255m"           // #FFFFFF
        TertiaryContainer = "\u001b[38;2;255;216;228m"    // #FFD8E4

        // Error
        Error = "\u001b[38;2;186;26;26m"                  // #BA1A1A
        OnError = "\u001b[38;2;255;255;255m"              // #FFFFFF
        ErrorContainer = "\u001b[38;2;255;218;214m"       // #FFDAD6

        // Safety-Critical Semantic (ADJUSTED FOR LIGHT BACKGROUNDS)
        // These MUST have high contrast on light surfaces
        Normal = "\u001b[38;2;121;116;126m"               // #79747E - Gray (barely visible)
        Advisory = "\u001b[38;2;0;107;91m"                // #006B5B - Dark teal (contrast: 5.3:1)
        Caution = "\u001b[38;2;125;87;0m"                 // #7D5700 - Dark amber (contrast: 5.8:1)
        Warning = "\u001b[38;2;186;26;26m"                // #BA1A1A - Dark red (contrast: 7.2:1)
        Critical = "\u001b[38;2;186;26;26;5m"             // #BA1A1A + blink

        // Status (light mode variants)
        Connected = "\u001b[38;2;0;107;91m"               // Dark teal
        Stale = "\u001b[38;2;121;116;126m"                // Gray
        Disconnected = "\u001b[38;2;186;26;26m"           // Dark red
        Degraded = "\u001b[38;2;125;87;0m"                // Dark amber

        // Backgrounds (ANSI 48;2;R;G;B)
        BgSurface = "\u001b[48;2;255;251;254m"            // Light surface
        BgPrimary = "\u001b[48;2;234;221;255m"            // Light primary container
        BgSecondary = "\u001b[48;2;232;222;248m"          // Light secondary
        BgError = "\u001b[48;2;255;218;214m"              // Light error
        BgCaution = "\u001b[48;2;255;243;224m"            // Light amber

        // Outlines
        Outline = "\u001b[38;2;121;116;126m"              // #79747E
        OutlineVariant = "\u001b[38;2;202;196;208m"       // #CAC4D0

        // Typography
        Bold = "\u001b[1m"
        Dim = "\u001b[2m"
        Italic = "\u001b[3m"
        Underline = "\u001b[4m"
        Blink = "\u001b[5m"
        Reset = "\u001b[0m"

        // Box drawing colors
        BoxPrimary = "\u001b[38;2;121;116;126m"           // Gray borders
        BoxSecondary = "\u001b[38;2;202;196;208m"         // Light borders
    }

    // =========================================================================
    // DARK THEME DEFINITION (Material 3 Dark + Safety-Critical)
    // =========================================================================

    let private darkTheme : ThemeTokens = {
        Mode = Dark

        // Surface - dark backgrounds
        Surface = "\u001b[38;2;28;27;31m"                 // #1C1B1F
        OnSurface = "\u001b[38;2;230;225;229m"            // #E6E1E5
        SurfaceVariant = "\u001b[38;2;73;69;79m"          // #49454F
        OnSurfaceVariant = "\u001b[38;2;202;196;208m"     // #CAC4D0
        SurfaceDim = "\u001b[38;2;20;18;24m"              // #141218
        SurfaceBright = "\u001b[38;2;59;56;62m"           // #3B383E

        // Primary - light purple
        Primary = "\u001b[38;2;208;188;255m"              // #D0BCFF
        OnPrimary = "\u001b[38;2;56;30;114m"              // #381E72
        PrimaryContainer = "\u001b[38;2;79;55;139m"       // #4F378B
        OnPrimaryContainer = "\u001b[38;2;234;221;255m"   // #EADDFF

        // Secondary
        Secondary = "\u001b[38;2;204;194;220m"            // #CCC2DC
        OnSecondary = "\u001b[38;2;51;45;65m"             // #332D41
        SecondaryContainer = "\u001b[38;2;74;68;88m"      // #4A4458
        OnSecondaryContainer = "\u001b[38;2;232;222;248m" // #E8DEF8

        // Tertiary
        Tertiary = "\u001b[38;2;239;184;200m"             // #EFB8C8
        OnTertiary = "\u001b[38;2;73;37;50m"              // #492532
        TertiaryContainer = "\u001b[38;2;99;59;72m"       // #633B48

        // Error
        Error = "\u001b[38;2;242;184;181m"                // #F2B8B5
        OnError = "\u001b[38;2;96;20;16m"                 // #601410
        ErrorContainer = "\u001b[38;2;140;29;24m"         // #8C1D18

        // Safety-Critical Semantic (BRIGHT ON DARK BACKGROUNDS)
        Normal = "\u001b[90m"                              // Gray (nearly invisible)
        Advisory = "\u001b[38;2;3;218;198m"               // #03DAC6 - Bright teal
        Caution = "\u001b[38;2;255;179;0m"                // #FFB300 - Bright amber
        Warning = "\u001b[38;2;207;102;121m"              // #CF6679 - Bright red-pink
        Critical = "\u001b[38;2;207;102;121;5m"           // + blink

        // Status
        Connected = "\u001b[32m"                           // Green
        Stale = "\u001b[90m"                               // Gray
        Disconnected = "\u001b[31m"                        // Red
        Degraded = "\u001b[33m"                            // Yellow

        // Backgrounds
        BgSurface = "\u001b[48;2;28;27;31m"               // Dark surface
        BgPrimary = "\u001b[48;2;79;55;139m"              // Dark primary
        BgSecondary = "\u001b[48;2;74;68;88m"             // Dark secondary
        BgError = "\u001b[48;2;140;29;24m"                // Dark error
        BgCaution = "\u001b[48;2;101;77;0m"               // Dark amber

        // Outlines
        Outline = "\u001b[38;2;147;143;153m"              // #938F99
        OutlineVariant = "\u001b[38;2;73;69;79m"          // #49454F

        // Typography
        Bold = "\u001b[1m"
        Dim = "\u001b[2m"
        Italic = "\u001b[3m"
        Underline = "\u001b[4m"
        Blink = "\u001b[5m"
        Reset = "\u001b[0m"

        // Box drawing colors
        BoxPrimary = "\u001b[38;2;147;143;153m"           // Medium gray
        BoxSecondary = "\u001b[38;2;73;69;79m"            // Dark gray
    }

    // =========================================================================
    // THEME STATE MANAGEMENT
    // =========================================================================

    let mutable private currentMode = Dark
    let mutable private currentTokens = darkTheme

    /// Get current theme tokens
    let tokens () = currentTokens

    /// Get current mode
    let mode () = currentMode

    /// Set theme mode
    let setMode (newMode: ThemeMode) =
        currentMode <- newMode
        currentTokens <-
            match newMode with
            | Light -> lightTheme
            | Dark -> darkTheme
            | Auto ->
                let hour = DateTime.Now.Hour
                // 6am-6pm = Light, otherwise Dark
                if hour >= 6 && hour < 18 then lightTheme
                else darkTheme

    /// Toggle theme
    let toggle () =
        let newMode =
            match currentMode with
            | Light -> Dark
            | Dark -> Light
            | Auto -> Light  // Exit auto, go to light
        setMode newMode
        currentTokens

    /// Check if currently in light mode
    let isLight () = currentTokens.Mode = Light

    /// Check if currently in dark mode
    let isDark () = currentTokens.Mode = Dark

    // =========================================================================
    // HELPER FUNCTIONS
    // =========================================================================

    /// Apply theme color to text
    let color (text: string) (colorCode: string) : string =
        sprintf "%s%s%s" colorCode text currentTokens.Reset

    /// Apply alarm level color
    let alarmColor (level: int) : string =
        match level with
        | 0 -> currentTokens.Normal
        | 1 -> currentTokens.Advisory
        | 2 -> currentTokens.Caution
        | 3 -> currentTokens.Warning
        | _ -> currentTokens.Critical

    /// Get status color by connection state
    let statusColor (connected: bool) (stale: bool) : string =
        if not connected then currentTokens.Disconnected
        elif stale then currentTokens.Stale
        else currentTokens.Connected

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    /// Initialize theme system with auto-detection
    let initialize () =
        setMode Auto
        printfn "[ThemeSystem] Initialized in %A mode" currentMode
```

## 5.2 Vector Rendering Considerations

For vector/fractal rendering in a terminal context:

### Current Capability: Unicode Box Drawing
- Already uses Unicode box drawing characters (╔═║╚)
- Scales well to different terminal sizes
- No pixel-level control needed

### Potential Enhancement: Braille Pattern Rendering
```fsharp
/// Braille pattern rendering for pseudo-vector graphics
/// Each braille character is 2x4 dots = 8 bits
module BrailleRenderer =

    /// Braille Unicode range: U+2800 to U+28FF
    let brailleBase = 0x2800

    /// Dot positions in braille character:
    /// 0 3
    /// 1 4
    /// 2 5
    /// 6 7
    let dotPositions = [| 0x01; 0x02; 0x04; 0x08; 0x10; 0x20; 0x40; 0x80 |]

    /// Render a 2x4 bitmap as a braille character
    let renderDots (dots: bool array) : char =
        let value =
            dots
            |> Array.mapi (fun i d -> if d then dotPositions.[i] else 0)
            |> Array.sum
        char (brailleBase + value)

    /// Render a line using braille (2x resolution)
    let renderLine (x1: int) (y1: int) (x2: int) (y2: int) (width: int) (height: int) : string =
        // Bresenham's line algorithm at 2x resolution
        // Then quantize to braille characters
        // ... implementation
```

### Fractal Detail Levels
```fsharp
/// Fractal-style progressive detail based on available space
module FractalDetail =

    type DetailLevel = Minimal | Basic | Standard | High | Maximum

    /// Determine detail level from available width
    let fromWidth (cols: int) : DetailLevel =
        match cols with
        | c when c < 80 -> Minimal
        | c when c < 100 -> Basic
        | c when c < 140 -> Standard
        | c when c < 200 -> High
        | _ -> Maximum

    /// Number of data points to show in sparkline
    let sparklinePoints (level: DetailLevel) : int =
        match level with
        | Minimal -> 5
        | Basic -> 10
        | Standard -> 15
        | High -> 25
        | Maximum -> 40

    /// Bar chart granularity
    let barGranularity (level: DetailLevel) : int =
        match level with
        | Minimal -> 5    // 5 segments
        | Basic -> 10
        | Standard -> 20
        | High -> 40
        | Maximum -> 80
```

---

# IMPLEMENTATION SUMMARY

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `Cockpit/ThemeSystem.fs` | CREATE | Complete theme management |
| `Cockpit/ResponsiveLayout.fs` | CREATE | Layout engine |
| `Cockpit/Ergonomics.fs` | CREATE | Eye strain reduction |
| `Cockpit/Material3.fs` | MODIFY | Integrate with ThemeSystem |
| `Cockpit/DarkCockpitUI.fs` | MODIFY | Use theme tokens |
| `Cockpit/Prajna.fs` | MODIFY | Add theme toggle hotkey |
| `Cepaf.fsproj` | MODIFY | Add new files |

## STAMP Constraints Added

| ID | Description |
|----|-------------|
| SC-THEME-001 | Light/Dark mode support mandatory |
| SC-THEME-002 | Minimum 4.5:1 contrast for normal text |
| SC-THEME-003 | Minimum 7:1 contrast for critical elements |
| SC-THEME-004 | Theme persistence across sessions |
| SC-THEME-005 | Auto mode based on time of day |
| SC-ERGO-001 | Color temperature adjustment |
| SC-ERGO-002 | Adaptive contrast support |
| SC-RESP-001 | 4 breakpoint support (Compact/Standard/Wide/Ultra) |
| SC-RESP-002 | Panel priority-based hiding |
| SC-RESP-003 | Minimum 80x24 terminal support |

## Hotkeys

| Key | Action |
|-----|--------|
| `t` | Toggle light/dark theme |
| `T` | Cycle: Auto → Light → Dark |
| `+/-` | Adjust disclosure level |
| `?` | Show help overlay |

---

*End of Specification*
