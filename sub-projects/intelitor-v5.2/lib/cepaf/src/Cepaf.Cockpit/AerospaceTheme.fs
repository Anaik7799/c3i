namespace Cepaf.Cockpit

open System

/// ═══════════════════════════════════════════════════════════════════════════════
/// AEROSPACE COMPONENT TAXONOMY - COMPLETE F# DATA STRUCTURE
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// WHAT: Comprehensive type system capturing all 17 dimensions of the aerospace
///       theme taxonomy for GPU-accelerated OLED terminal rendering.
///
/// WHY: Safety-critical HMI requires formalized, type-safe theme definitions that
///      can be validated at compile-time and serialized for configuration.
///
/// STANDARDS COMPLIANCE:
///   - MIL-STD-1472G (Human Engineering)
///   - NASA-STD-3000 (Man-Systems Integration)
///   - DO-178C (Software Considerations)
///   - WCAG 2.1 AA (Accessibility)
///   - IEC 61508 (Functional Safety)
///   - ISO 11064 (Control Centre Ergonomics)
///   - NUREG-0700 (Nuclear HMI Guidelines)
///
/// STAMP Constraints:
///   - SC-THEME-001: All colors must have WCAG 2.1 AA contrast ratios
///   - SC-THEME-002: OLED optimization requires true black (#000000)
///   - SC-THEME-003: GPU glow effects must degrade gracefully
///   - SC-THEME-004: Animation timing must respect reduced-motion preferences
///   - SC-THEME-005: Sound triggers must have visual equivalents
///
/// ═══════════════════════════════════════════════════════════════════════════════
module AerospaceTheme =

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 1: STANDARDS COMPLIANCE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Industry standard identifier
    type StandardId =
        // Military Standards
        | MIL_STD_1472G      // Human Engineering
        | MIL_STD_1472H      // Human Engineering (Updated)
        | MIL_STD_810H       // Environmental Engineering

        // Aerospace Standards
        | NASA_STD_3000      // Man-Systems Integration
        | NASA_STD_3001      // Human Integration Design
        | DO_178C            // Software Considerations in Airborne Systems
        | DO_254             // Design Assurance for Airborne Electronic Hardware
        | SAE_ARP_4754A      // Development of Civil Aircraft Systems
        | SAE_ARP_4761       // Safety Assessment Process
        | RTCA_DO_326A       // Airworthiness Security

        // Safety Standards
        | IEC_61508          // Functional Safety
        | IEC_62443          // Industrial Cybersecurity
        | ISO_26262          // Road Vehicle Functional Safety
        | ISO_13849          // Safety of Machinery
        | EN_50131           // Alarm Systems

        // Nuclear Standards
        | NUREG_0700         // Human-System Interface Design
        | IEEE_603           // Nuclear Safety Systems

        // Industrial Standards
        | ISA_101            // HMI for Process Automation
        | ISA_18_2           // Alarm Management
        | EEMUA_191          // Alarm Systems Guide
        | IEC_62682          // Management of Alarm Systems

        // Accessibility Standards
        | WCAG_2_1_AA        // Web Content Accessibility Guidelines
        | WCAG_2_1_AAA       // Enhanced Accessibility
        | Section_508        // US Federal Accessibility
        | EN_301_549         // EU Accessibility Requirements

    /// Standards compliance record
    type StandardsCompliance = {
        Standard: StandardId
        Version: string
        ComplianceLevel: string  // "Full", "Partial", "Targeted"
        CoveredClauses: string list
        CertificationDate: DateTime option
        Notes: string option
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 2: COLOR SYSTEM (OLED-Optimized, DCI-P3 Wide Gamut)
    // ═══════════════════════════════════════════════════════════════════════════

    /// RGB color with full precision
    [<Struct>]
    type RgbColor = {
        R: byte
        G: byte
        B: byte
    } with
        member this.ToHex() = sprintf "#%02X%02X%02X" this.R this.G this.B
        member this.ToAnsi() = sprintf "\u001b[38;2;%d;%d;%dm" this.R this.G this.B
        member this.ToAnsiBg() = sprintf "\u001b[48;2;%d;%d;%dm" this.R this.G this.B
        member this.ToTview() = sprintf "[#%02X%02X%02X]" this.R this.G this.B
        member this.ToTviewBg() = sprintf "[:#%02X%02X%02X]" this.R this.G this.B
        static member FromHex(hex: string) =
            let h = hex.TrimStart('#')
            { R = Convert.ToByte(h.Substring(0, 2), 16)
              G = Convert.ToByte(h.Substring(2, 2), 16)
              B = Convert.ToByte(h.Substring(4, 2), 16) }
        static member Black = { R = 0uy; G = 0uy; B = 0uy }
        static member White = { R = 255uy; G = 255uy; B = 255uy }

    /// Color space specification
    type ColorSpace =
        | SRGB              // Standard RGB (most terminals)
        | DisplayP3         // Wide gamut (modern displays)
        | AdobeRGB          // Print/professional
        | Rec2020           // HDR/broadcast

    /// Color with metadata
    type ThemeColor = {
        Name: string
        Rgb: RgbColor
        ColorSpace: ColorSpace
        ContrastRatioOnBlack: float
        ContrastRatioOnWhite: float
        OledSafe: bool          // True if won't cause burn-in at 100% brightness
        P3Enhanced: bool        // True if benefits from P3 wide gamut
        Description: string
    }

    /// Core color palette (OLED-optimized)
    type CorePalette = {
        // Backgrounds (OLED Black = true black)
        VoidBlack: ThemeColor           // #000000 - True OLED black
        SpaceBlack: ThemeColor          // #0a0a0f - Near black with hint of blue
        DeepSpace: ThemeColor           // #0d1117 - GitHub dark background
        NightSky: ThemeColor            // #151520 - Elevated surfaces
        Twilight: ThemeColor            // #1e1e2e - Cards/panels
        Dusk: ThemeColor                // #252530 - Borders/dividers

        // Primary Accents (P3 Enhanced)
        PlasmaCyan: ThemeColor          // #00ffff - Primary accent
        QuantumBlue: ThemeColor         // #00afff - Secondary accent
        ElectricBlue: ThemeColor        // #0080ff - Tertiary accent
        NeonPurple: ThemeColor          // #bf00ff - AI/special elements

        // Semantic Status Colors
        NominalGreen: ThemeColor        // #00ff88 - Success/Go/Healthy
        CautionAmber: ThemeColor        // #ffaa00 - Warning/Attention
        AlertRed: ThemeColor            // #ff4444 - Error/Critical
        AdvisoryCyan: ThemeColor        // #00dddd - Informational

        // Text Colors
        BrightText: ThemeColor          // #ffffff - Primary text
        NormalText: ThemeColor          // #e0e0e0 - Body text
        MutedText: ThemeColor           // #808090 - Secondary text
        DimText: ThemeColor             // #505060 - Disabled/hint text

        // Data Visualization
        DataBlue: ThemeColor            // #4488ff - Primary data
        DataGreen: ThemeColor           // #44ff88 - Secondary data
        DataPurple: ThemeColor          // #aa44ff - Tertiary data
        DataOrange: ThemeColor          // #ff8844 - Quaternary data
        DataPink: ThemeColor            // #ff44aa - Quinary data
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 3: SEMANTIC COLORS (Status, Phase, Subsystem)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Operational status colors
    type StatusColors = {
        // Health Status
        Nominal: ThemeColor             // System healthy
        Degraded: ThemeColor            // Reduced capability
        Impaired: ThemeColor            // Significant issues
        Critical: ThemeColor            // Immediate action required
        Failed: ThemeColor              // System failure
        Unknown: ThemeColor             // Status unavailable

        // Connection Status
        Connected: ThemeColor           // Active connection
        Connecting: ThemeColor          // Establishing connection
        Stale: ThemeColor              // Data age exceeded threshold
        Disconnected: ThemeColor        // No connection
        Timeout: ThemeColor             // Connection timed out

        // Process Status
        Idle: ThemeColor               // Waiting for input
        Active: ThemeColor             // Currently processing
        Paused: ThemeColor             // Temporarily stopped
        Completed: ThemeColor          // Successfully finished
        Aborted: ThemeColor            // Forcibly terminated
        Error: ThemeColor              // Error state
    }

    /// Mission phase colors
    type PhaseColors = {
        // Pre-Mission
        Initialization: ThemeColor      // System starting up
        Configuration: ThemeColor       // Being configured
        Calibration: ThemeColor         // Calibrating sensors
        Standby: ThemeColor            // Ready, waiting

        // Active Mission
        Launch: ThemeColor             // Mission start
        Cruise: ThemeColor             // Normal operation
        Approach: ThemeColor           // Approaching target
        Engagement: ThemeColor         // Active engagement

        // Post-Mission
        Recovery: ThemeColor           // Returning to normal
        Analysis: ThemeColor           // Post-operation analysis
        Maintenance: ThemeColor        // Maintenance mode
        Shutdown: ThemeColor           // Orderly shutdown
    }

    /// Subsystem identification colors
    type SubsystemColors = {
        // Core Systems
        Power: ThemeColor              // Power management
        Thermal: ThemeColor            // Thermal control
        Propulsion: ThemeColor         // Propulsion systems
        Navigation: ThemeColor         // Navigation systems

        // Communication Systems
        Uplink: ThemeColor             // Ground-to-vehicle
        Downlink: ThemeColor           // Vehicle-to-ground
        Intercom: ThemeColor           // Internal communication
        Relay: ThemeColor              // Relay/mesh networks

        // Payload Systems
        Sensors: ThemeColor            // Sensor arrays
        Effectors: ThemeColor          // Actuators/effectors
        Storage: ThemeColor            // Data storage
        Processing: ThemeColor         // Compute systems

        // Safety Systems
        LifeSupport: ThemeColor        // Life support
        Emergency: ThemeColor          // Emergency systems
        Backup: ThemeColor             // Redundant systems
        Override: ThemeColor           // Manual override
    }

    /// Complete semantic color system
    type SemanticColors = {
        Status: StatusColors
        Phase: PhaseColors
        Subsystem: SubsystemColors
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 4: TYPOGRAPHY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Font weight specification
    type FontWeight =
        | Thin          // 100
        | ExtraLight    // 200
        | Light         // 300
        | Regular       // 400
        | Medium        // 500
        | SemiBold      // 600
        | Bold          // 700
        | ExtraBold     // 800
        | Black         // 900

    /// Font style specification
    type FontStyle =
        | Normal
        | Italic
        | Oblique

    /// Font family with fallbacks
    type FontFamily = {
        Primary: string
        Fallbacks: string list
        Category: string  // "monospace", "sans-serif", "serif"
    }

    /// Type scale step
    type TypeScaleStep = {
        Name: string            // "xs", "sm", "base", "lg", "xl", etc.
        SizeMultiplier: float   // Relative to base size
        LineHeightMultiplier: float
        LetterSpacing: float    // In em units
        Weight: FontWeight
    }

    /// Text treatment/decoration
    type TextTreatment =
        | NoDecoration  // No text decoration
        | Underline
        | Overline
        | LineThrough
        | DoubleUnderline
        | Dotted
        | Dashed
        | Wavy

    /// Typography system
    type TypographySystem = {
        // Font Families
        MonospaceFamily: FontFamily     // Primary (code, data)
        SansSerifFamily: FontFamily     // Secondary (UI elements)
        DisplayFamily: FontFamily       // Headlines/titles

        // Base Configuration
        BaseSizePx: int                 // Usually 14-16px
        BaseLineHeight: float           // Usually 1.4-1.6

        // Type Scale (modular scale ratio, e.g., 1.25 = major third)
        ScaleRatio: float
        ScaleSteps: TypeScaleStep list

        // ANSI Codes for Terminal
        AnsiReset: string
        AnsiBold: string
        AnsiDim: string
        AnsiItalic: string
        AnsiUnderline: string
        AnsiBlink: string
        AnsiReverse: string
        AnsiHidden: string
        AnsiStrikethrough: string
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 5: SPACING & LAYOUT (8px Grid, 12-Column Responsive)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Spacing unit (based on 8px grid)
    [<Struct>]
    type SpacingUnit = {
        Name: string        // "none", "xs", "sm", "md", "lg", "xl", "2xl", etc.
        Multiplier: int     // Multiple of base unit (8px)
        Pixels: int         // Actual pixel value
        Characters: int     // Terminal character equivalent
    }

    /// Spacing scale
    type SpacingScale = {
        BaseUnit: int           // 8px
        None: SpacingUnit       // 0
        Xs: SpacingUnit         // 4px (0.5x)
        Sm: SpacingUnit         // 8px (1x)
        Md: SpacingUnit         // 16px (2x)
        Lg: SpacingUnit         // 24px (3x)
        Xl: SpacingUnit         // 32px (4x)
        Xxl: SpacingUnit        // 48px (6x)
        Xxxl: SpacingUnit       // 64px (8x)
    }

    /// Responsive breakpoint
    type Breakpoint = {
        Name: string            // "compact", "standard", "wide", "ultrawide"
        MinColumns: int         // Minimum terminal columns
        MaxColumns: int option  // Maximum (None = unlimited)
        LayoutColumns: int      // Number of layout columns (1, 2, 3, 4)
        SidebarWidth: int option
        ContentMaxWidth: int option
    }

    /// Grid system configuration
    type GridSystem = {
        Columns: int                    // 12 columns
        GutterWidth: SpacingUnit        // Space between columns
        MarginWidth: SpacingUnit        // Outer margins
        Breakpoints: Breakpoint list    // Responsive breakpoints
    }

    /// Layout system
    type LayoutSystem = {
        Spacing: SpacingScale
        Grid: GridSystem

        // Panel dimensions
        MinPanelWidth: int
        MaxPanelWidth: int
        PanelPadding: SpacingUnit

        // Header/Footer
        HeaderHeight: int
        FooterHeight: int
        StatusBarHeight: int
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 6: BORDERS & VISUAL HIERARCHY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Border style specification
    type BorderStyle =
        | NoBorder    // No border
        | Solid
        | Double
        | Dashed
        | Dotted
        | Rounded     // Uses Unicode rounded corners

    /// Border weight
    type BorderWeight =
        | Hairline    // Thin line
        | Light       // Light box drawing
        | Medium      // Standard box drawing
        | Heavy       // Heavy/bold box drawing

    /// Box drawing character set
    type BoxDrawingSet = {
        // Corners
        TopLeft: char
        TopRight: char
        BottomLeft: char
        BottomRight: char

        // Lines
        Horizontal: char
        Vertical: char

        // T-Junctions
        TeeDown: char
        TeeUp: char
        TeeRight: char
        TeeLeft: char

        // Cross
        Cross: char

        // Rounded corners (optional)
        RoundedTopLeft: char option
        RoundedTopRight: char option
        RoundedBottomLeft: char option
        RoundedBottomRight: char option
    }

    /// Border configuration
    type BorderConfig = {
        Style: BorderStyle
        Weight: BorderWeight
        Color: ThemeColor
        Characters: BoxDrawingSet
    }

    /// Visual hierarchy levels
    type HierarchyLevel =
        | Surface       // Base layer
        | Elevated1     // First elevation
        | Elevated2     // Second elevation
        | Elevated3     // Third elevation (modals/overlays)
        | Floating      // Tooltips, dropdowns

    /// Visual hierarchy configuration
    type VisualHierarchy = {
        Level: HierarchyLevel
        BackgroundColor: ThemeColor
        BorderColor: ThemeColor
        ShadowColor: ThemeColor option
        ShadowOffset: int * int     // (x, y) in characters
        ZIndex: int
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 7: GPU GLOW EFFECTS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Glow intensity level
    type GlowIntensity =
        | Subtle        // 0.2 opacity
        | Medium        // 0.4 opacity
        | Strong        // 0.6 opacity
        | Intense       // 0.8 opacity
        | Maximum       // 1.0 opacity

    /// Glow effect specification
    type GlowEffect = {
        Name: string
        Color: ThemeColor
        Intensity: GlowIntensity
        BlurRadius: int             // Pixels
        SpreadRadius: int           // Pixels
        OffsetX: int
        OffsetY: int
        Inset: bool                 // Inner glow
        Pulsing: bool               // Animated pulsing
        PulseFrequencyHz: float option
    }

    /// GPU glow presets
    type GlowPresets = {
        // Status Glows
        NominalGlow: GlowEffect     // Subtle green
        CautionGlow: GlowEffect     // Medium amber pulse
        AlertGlow: GlowEffect       // Strong red pulse
        CriticalGlow: GlowEffect    // Intense red rapid pulse

        // Interaction Glows
        FocusGlow: GlowEffect       // Cyan focus ring
        HoverGlow: GlowEffect       // Subtle highlight
        ActiveGlow: GlowEffect      // Press feedback
        SelectedGlow: GlowEffect    // Selected item

        // Special Effects
        AiGlow: GlowEffect          // Purple AI indicator
        DataStreamGlow: GlowEffect  // Blue data flow
        TransmitGlow: GlowEffect    // Uplink indicator
        ReceiveGlow: GlowEffect     // Downlink indicator

        // Terminal ASCII Fallback (when GPU unavailable)
        AsciiHighlight: string      // e.g., ">>" or "**"
        AsciiFocus: string          // e.g., "[ ]" or "< >"
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 8: ANIMATION SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    /// Easing function type
    type EasingFunction =
        | Linear
        | EaseIn
        | EaseOut
        | EaseInOut
        | EaseInQuad
        | EaseOutQuad
        | EaseInOutQuad
        | EaseInCubic
        | EaseOutCubic
        | EaseInOutCubic
        | EaseInQuart
        | EaseOutQuart
        | EaseInOutQuart
        | EaseInExpo
        | EaseOutExpo
        | EaseInOutExpo
        | EaseInCirc
        | EaseOutCirc
        | EaseInOutCirc
        | EaseInBack
        | EaseOutBack
        | EaseInOutBack
        | EaseInElastic
        | EaseOutElastic
        | EaseInOutElastic
        | EaseInBounce
        | EaseOutBounce
        | EaseInOutBounce
        | Spring of stiffness: float * damping: float

    /// Animation timing specification
    type AnimationTiming = {
        DurationMs: int
        DelayMs: int
        Easing: EasingFunction
        Iterations: int         // -1 for infinite
        Direction: string       // "normal", "reverse", "alternate"
        FillMode: string        // "none", "forwards", "backwards", "both"
    }

    /// Animation keyframe
    type Keyframe = {
        Offset: float           // 0.0 to 1.0
        Properties: Map<string, string>
    }

    /// Animation definition
    type Animation = {
        Name: string
        Timing: AnimationTiming
        Keyframes: Keyframe list
        ReducedMotionFallback: Animation option
    }

    /// Animation catalog
    type AnimationCatalog = {
        // Entrance Animations
        FadeIn: Animation
        SlideInLeft: Animation
        SlideInRight: Animation
        SlideInUp: Animation
        SlideInDown: Animation
        ScaleIn: Animation
        PopIn: Animation

        // Exit Animations
        FadeOut: Animation
        SlideOutLeft: Animation
        SlideOutRight: Animation
        SlideOutUp: Animation
        SlideOutDown: Animation
        ScaleOut: Animation
        PopOut: Animation

        // Attention Animations
        Pulse: Animation
        Shake: Animation
        Bounce: Animation
        Flash: Animation
        Heartbeat: Animation
        Wobble: Animation

        // Status Animations
        Spin: Animation
        Progress: Animation
        Ripple: Animation
        Wave: Animation
        Breathe: Animation

        // Data Animations
        CountUp: Animation
        BarGrow: Animation
        ChartDraw: Animation
        Sparkle: Animation

        // Transition Presets
        StateChangeTransition: AnimationTiming
        HoverTransition: AnimationTiming
        FocusTransition: AnimationTiming
        ColorTransition: AnimationTiming
    }

    /// Animation choreography for multi-element sequences
    type Choreography = {
        Name: string
        Description: string
        Steps: (string * Animation * int) list  // (element, animation, delayMs)
        TotalDurationMs: int
    }

    /// ARM & FIRE protocol animation choreography
    type ArmFireChoreography = {
        // ARM Phase (3 seconds)
        ArmInitiate: Animation          // Button changes state
        ArmCountdown: Animation         // 3-2-1 countdown
        ArmPulse: Animation            // Pulsing while armed
        ArmCancel: Animation           // Cancel animation

        // FIRE Phase
        FireConfirm: Animation         // Confirmation flash
        FireExecute: Animation         // Action executing
        FireComplete: Animation        // Success feedback
        FireFailed: Animation          // Failure feedback

        // Timing
        ArmHoldDurationMs: int          // 3000ms minimum
        FireWindowMs: int               // Window to confirm (5000ms)
        CooldownMs: int                 // Cooldown before re-arm
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 9: SOUND DESIGN
    // ═══════════════════════════════════════════════════════════════════════════

    /// Sound wave type
    type WaveType =
        | Sine
        | Square
        | Triangle
        | Sawtooth
        | Noise
        | Custom of string  // Custom waveform data

    /// Sound specification
    type SoundSpec = {
        Name: string
        FrequencyHz: float
        DurationMs: int
        Volume: float               // 0.0 to 1.0
        WaveType: WaveType
        AttackMs: int               // ADSR envelope
        DecayMs: int
        SustainLevel: float
        ReleaseMs: int
        PanPosition: float          // -1.0 (left) to 1.0 (right)
    }

    /// Sound trigger event
    type SoundTrigger =
        // UI Interactions
        | Click
        | DoubleClick
        | KeyPress
        | FocusIn
        | FocusOut
        | Submit
        | Cancel

        // Status Changes
        | StatusNominal
        | StatusCaution
        | StatusWarning
        | StatusCritical
        | StatusCleared

        // Notifications
        | NotificationInfo
        | NotificationSuccess
        | NotificationWarning
        | NotificationError

        // ARM & FIRE
        | ArmInitiated
        | ArmCountdownTick
        | ArmCancelled
        | FireConfirmed
        | FireExecuting
        | FireSuccess
        | FireFailed

        // System Events
        | SystemStartup
        | SystemShutdown
        | ConnectionEstablished
        | ConnectionLost
        | DataReceived
        | DataTransmitted

    /// Sound theme
    type SoundTheme = {
        // UI Sounds
        Click: SoundSpec
        Hover: SoundSpec
        Focus: SoundSpec
        Success: SoundSpec
        Error: SoundSpec
        Warning: SoundSpec

        // Notification Sounds
        NotificationInfo: SoundSpec
        NotificationAlert: SoundSpec
        NotificationCritical: SoundSpec

        // ARM & FIRE Sounds
        ArmTone: SoundSpec
        CountdownTick: SoundSpec
        FireConfirm: SoundSpec

        // Ambient/System
        Startup: SoundSpec
        Shutdown: SoundSpec
        Heartbeat: SoundSpec
        DataPulse: SoundSpec

        // Sound Enabled Flags
        Enabled: bool
        MasterVolume: float
        CategoryVolumes: Map<string, float>
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSIONS 10-14: COMPONENT LIBRARY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Component state
    type ComponentState =
        | Default
        | Hover
        | Focus
        | Active
        | Selected
        | Disabled
        | Loading
        | Error
        | Success
        | Warning

    /// Component size variant
    type ComponentSize =
        | Xs
        | Sm
        | Md
        | Lg
        | Xl
        | Full

    /// Base component definition
    type ComponentDef = {
        Name: string
        Category: string
        Description: string
        States: ComponentState list
        Sizes: ComponentSize list
        DefaultSize: ComponentSize
        Variants: string list
        AccessibilityRole: string
        KeyboardShortcut: string option
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIMENSION 10: NAVIGATION COMPONENTS (4 types, 11 variants)
    // ─────────────────────────────────────────────────────────────────────────

    /// Tab bar style
    type TabBarStyle =
        | Underline         // Underline active tab
        | Pill              // Pill-shaped background
        | Segment           // Segmented control
        | Boxed             // Boxed tabs

    /// Tab bar component
    type TabBar = {
        Base: ComponentDef
        Style: TabBarStyle
        Orientation: string     // "horizontal", "vertical"
        Scrollable: bool
        ShowIcons: bool
        ShowBadges: bool
        TabMinWidth: int
        TabMaxWidth: int option
        AnimatedIndicator: bool
    }

    /// Breadcrumb separator style
    type BreadcrumbSeparator =
        | Slash             // /
        | Arrow             // >
        | Chevron           // ›
        | Dot               // •
        | Custom of string

    /// Breadcrumb component
    type Breadcrumb = {
        Base: ComponentDef
        Separator: BreadcrumbSeparator
        MaxItems: int option
        CollapseBehavior: string    // "none", "ellipsis", "dropdown"
        ShowHomeIcon: bool
        TruncateItems: bool
    }

    /// Sidebar component
    type Sidebar = {
        Base: ComponentDef
        Position: string            // "left", "right"
        Collapsible: bool
        CollapsedWidth: int
        ExpandedWidth: int
        ShowLabels: bool
        Nested: bool
        StickyHeader: bool
    }

    /// Command palette component
    type CommandPalette = {
        Base: ComponentDef
        SearchPlaceholder: string
        MaxResults: int
        ShowShortcuts: bool
        ShowCategories: bool
        ShowRecent: bool
        FuzzySearch: bool
        HighlightMatches: bool
    }

    /// Navigation components collection
    type NavigationComponents = {
        TabBar: TabBar
        TabBarPill: TabBar
        TabBarSegment: TabBar
        TabBarVertical: TabBar
        Breadcrumb: Breadcrumb
        BreadcrumbCompact: Breadcrumb
        Sidebar: Sidebar
        SidebarMini: Sidebar
        SidebarNested: Sidebar
        CommandPalette: CommandPalette
        CommandPaletteCompact: CommandPalette
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIMENSION 11: STATUS COMPONENTS (6 types, 18 variants)
    // ─────────────────────────────────────────────────────────────────────────

    /// Status badge shape
    type BadgeShape =
        | Circle
        | Pill
        | Square
        | Dot

    /// Status badge component
    type StatusBadge = {
        Base: ComponentDef
        Shape: BadgeShape
        ShowIcon: bool
        ShowCount: bool
        MaxCount: int option
        Pulsing: bool
        GlowEnabled: bool
    }

    /// Progress indicator type
    type ProgressType =
        | LinearBar     // Renamed to avoid conflict with EasingFunction.Linear
        | Circular
        | Semicircular
        | Steps

    /// Progress indicator component
    type ProgressIndicator = {
        Base: ComponentDef
        Type: ProgressType
        Indeterminate: bool
        ShowPercentage: bool
        ShowLabel: bool
        Striped: bool
        Animated: bool
        Thickness: int
    }

    /// Health gauge style
    type GaugeStyle =
        | Arc
        | Dial
        | LinearVertical
        | LinearHorizontal
        | Donut

    /// Health gauge component
    type HealthGauge = {
        Base: ComponentDef
        Style: GaugeStyle
        MinValue: float
        MaxValue: float
        Thresholds: (float * ThemeColor) list   // (value, color)
        ShowNeedle: bool
        ShowTicks: bool
        ShowValue: bool
        ShowUnit: bool
        Unit: string
    }

    /// Sparkline component
    type Sparkline = {
        Base: ComponentDef
        DataPoints: int
        ShowMinMax: bool
        ShowCurrentValue: bool
        FillArea: bool
        Smoothed: bool
        ReferenceLines: float list
    }

    /// Alert banner position
    type BannerPosition =
        | Top
        | Bottom
        | Inline

    /// Alert banner component
    type AlertBanner = {
        Base: ComponentDef
        Position: BannerPosition
        Dismissible: bool
        ShowIcon: bool
        AutoDismissMs: int option
        ActionButtons: string list
        Expandable: bool
    }

    /// Connection indicator component
    type ConnectionIndicator = {
        Base: ComponentDef
        ShowLatency: bool
        ShowThroughput: bool
        ShowQuality: bool
        CompactMode: bool
        AnimatedPulse: bool
    }

    /// Status components collection
    type StatusComponents = {
        // Status Badges
        BadgeCircle: StatusBadge
        BadgePill: StatusBadge
        BadgeSquare: StatusBadge
        BadgeDot: StatusBadge
        BadgePulsing: StatusBadge

        // Progress Indicators
        ProgressLinear: ProgressIndicator
        ProgressCircular: ProgressIndicator
        ProgressSemiCircular: ProgressIndicator
        ProgressSteps: ProgressIndicator

        // Gauges
        GaugeArc: HealthGauge
        GaugeDial: HealthGauge
        GaugeLinear: HealthGauge
        GaugeDonut: HealthGauge

        // Charts
        SparklineBasic: Sparkline
        SparklineFilled: Sparkline

        // Alerts
        AlertBannerTop: AlertBanner
        AlertBannerInline: AlertBanner

        // Connection
        ConnectionIndicator: ConnectionIndicator
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIMENSION 12: DATA COMPONENTS (4 types, 14 variants)
    // ─────────────────────────────────────────────────────────────────────────

    /// Table row style
    type TableRowStyle =
        | Plain
        | Striped
        | Bordered
        | Hoverable

    /// Data table component
    type DataTable = {
        Base: ComponentDef
        RowStyle: TableRowStyle
        Sortable: bool
        Filterable: bool
        Selectable: bool
        Paginated: bool
        VirtualScroll: bool
        StickyHeader: bool
        StickyFirstColumn: bool
        CompactMode: bool
        ShowRowNumbers: bool
        ColumnResizable: bool
    }

    /// Tree view component
    type TreeView = {
        Base: ComponentDef
        ShowLines: bool
        ShowIcons: bool
        Selectable: bool
        MultiSelect: bool
        Draggable: bool
        LazyLoad: bool
        ShowCheckboxes: bool
        ExpandOnSelect: bool
    }

    /// Key-value pair display style
    type KeyValueStyle =
        | Inline
        | Stacked
        | Table

    /// Key-value display component
    type KeyValueDisplay = {
        Base: ComponentDef
        Style: KeyValueStyle
        KeyWidth: int option
        ValueAlignment: string  // "left", "right"
        ShowSeparator: bool
        Copyable: bool
    }

    /// Log viewer component
    type LogViewer = {
        Base: ComponentDef
        ShowTimestamp: bool
        ShowLevel: bool
        ShowSource: bool
        AutoScroll: bool
        Searchable: bool
        Filterable: bool
        Wrap: bool
        MaxLines: int
        SyntaxHighlight: bool
        VirtualScroll: bool
    }

    /// Data components collection
    type DataComponents = {
        // Tables
        TablePlain: DataTable
        TableStriped: DataTable
        TableBordered: DataTable
        TableCompact: DataTable
        TableVirtual: DataTable

        // Trees
        TreeBasic: TreeView
        TreeSelectable: TreeView
        TreeCheckbox: TreeView
        TreeDraggable: TreeView

        // Key-Value
        KeyValueInline: KeyValueDisplay
        KeyValueStacked: KeyValueDisplay
        KeyValueTable: KeyValueDisplay

        // Logs
        LogViewerBasic: LogViewer
        LogViewerAdvanced: LogViewer
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIMENSION 13: INTERACTION COMPONENTS (6 types, 23 variants)
    // ─────────────────────────────────────────────────────────────────────────

    /// Button variant
    type ButtonVariant =
        | Primary
        | Secondary
        | Tertiary
        | Ghost
        | Danger
        | SuccessBtn   // Renamed to avoid conflict with ComponentState.Success

    /// Button component
    type Button = {
        Base: ComponentDef
        Variant: ButtonVariant
        IconPosition: string option     // "left", "right", "only"
        Loading: bool
        Rounded: bool
        FullWidth: bool
        RippleEffect: bool
    }

    /// Input type
    type InputType =
        | Text
        | Number
        | Password
        | Search
        | Email
        | Tel
        | Url
        | Multiline

    /// Text input component
    type TextInput = {
        Base: ComponentDef
        InputType: InputType
        Placeholder: string option
        Prefix: string option
        Suffix: string option
        Clearable: bool
        ShowCount: bool
        MaxLength: int option
        Validation: string option
    }

    /// Toggle switch component
    type ToggleSwitch = {
        Base: ComponentDef
        ShowLabels: bool
        OnLabel: string
        OffLabel: string
        Animated: bool
    }

    /// Slider component
    type Slider = {
        Base: ComponentDef
        Min: float
        Max: float
        Step: float
        ShowValue: bool
        ShowTicks: bool
        Range: bool         // Dual handle range
        Vertical: bool
    }

    /// Dropdown style
    type DropdownStyle =
        | Standard
        | Searchable
        | MultiSelect
        | Cascading

    /// Dropdown component
    type Dropdown = {
        Base: ComponentDef
        Style: DropdownStyle
        Placeholder: string
        Searchable: bool
        Clearable: bool
        MaxHeight: int option
        VirtualScroll: bool
        GroupHeaders: bool
    }

    /// Modal size
    type ModalSize =
        | Small
        | Medium
        | Large
        | FullScreen
        | Auto

    /// Modal component
    type Modal = {
        Base: ComponentDef
        ModalSize: ModalSize
        Closeable: bool
        CloseOnBackdrop: bool
        CloseOnEscape: bool
        ShowHeader: bool
        ShowFooter: bool
        Centered: bool
        Animated: bool
        Draggable: bool
    }

    /// ARM & FIRE button component (safety-critical)
    type ArmFireButton = {
        Base: ComponentDef
        HoldDurationMs: int         // 3000ms minimum per protocol
        ShowCountdown: bool
        ShowProgress: bool
        RequireDoubleConfirm: bool
        CooldownMs: int
        SoundEnabled: bool
        HapticEnabled: bool
    }

    /// Interaction components collection
    type InteractionComponents = {
        // Buttons
        ButtonPrimary: Button
        ButtonSecondary: Button
        ButtonTertiary: Button
        ButtonGhost: Button
        ButtonDanger: Button
        ButtonSuccess: Button
        ButtonIcon: Button
        ButtonLoading: Button

        // Inputs
        InputText: TextInput
        InputNumber: TextInput
        InputPassword: TextInput
        InputSearch: TextInput
        InputMultiline: TextInput

        // Toggles
        ToggleSwitch: ToggleSwitch
        ToggleLabeled: ToggleSwitch

        // Sliders
        SliderBasic: Slider
        SliderRange: Slider
        SliderVertical: Slider

        // Dropdowns
        DropdownStandard: Dropdown
        DropdownSearchable: Dropdown
        DropdownMulti: Dropdown

        // Modals
        ModalSmall: Modal
        ModalLarge: Modal
        ModalFullscreen: Modal

        // Safety-Critical
        ArmFireButton: ArmFireButton
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DIMENSION 14: FEEDBACK COMPONENTS (2 types, 9 variants)
    // ─────────────────────────────────────────────────────────────────────────

    /// Toast position
    type ToastPosition =
        | TopLeft
        | TopCenter
        | TopRight
        | BottomLeft
        | BottomCenter
        | BottomRight

    /// Toast notification component
    type Toast = {
        Base: ComponentDef
        Position: ToastPosition
        Duration: int option        // None = persistent
        ShowProgress: bool
        ShowIcon: bool
        Dismissible: bool
        Stacked: bool
        MaxVisible: int
    }

    /// Tooltip placement
    type TooltipPlacement =
        | Top
        | Bottom
        | Left
        | Right
        | TopStart
        | TopEnd
        | BottomStart
        | BottomEnd

    /// Tooltip component
    type Tooltip = {
        Base: ComponentDef
        Placement: TooltipPlacement
        Delay: int
        Arrow: bool
        MaxWidth: int option
        Interactive: bool
        Trigger: string             // "hover", "click", "focus"
    }

    /// Feedback components collection
    type FeedbackComponents = {
        // Toasts
        ToastInfo: Toast
        ToastSuccess: Toast
        ToastWarning: Toast
        ToastError: Toast
        ToastAction: Toast

        // Tooltips
        TooltipBasic: Tooltip
        TooltipRich: Tooltip
        TooltipInteractive: Tooltip
        TooltipKeyboard: Tooltip
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 15: ACCESSIBILITY
    // ═══════════════════════════════════════════════════════════════════════════

    /// Reduced motion preference
    type MotionPreference =
        | Full              // All animations
        | Reduced           // Essential only
        | Minimal           // Opacity changes only
        | NoMotion          // No motion

    /// Contrast mode
    type ContrastMode =
        | Normal            // Standard contrast
        | High              // High contrast
        | Inverted          // Color inversion
        | Custom of float   // Custom ratio multiplier

    /// Screen reader optimization
    type ScreenReaderOptimization = {
        AriaLabels: bool
        LiveRegions: bool
        RoleAttributes: bool
        FocusManagement: bool
        SkipLinks: bool
        HeadingHierarchy: bool
        LandmarkRegions: bool
    }

    /// Keyboard navigation config
    type KeyboardNavigation = {
        TabIndex: bool
        ArrowKeyNav: bool
        ShortcutsEnabled: bool
        FocusVisible: bool
        FocusTrap: bool         // For modals
        RotorNavigation: bool   // For screen readers
    }

    /// Color blindness accommodation
    type ColorBlindnessMode =
        | Normal
        | Protanopia        // Red-blind
        | Deuteranopia      // Green-blind
        | Tritanopia        // Blue-blind
        | Achromatopsia     // Total color blindness

    /// Accessibility configuration
    type AccessibilityConfig = {
        MotionPreference: MotionPreference
        ContrastMode: ContrastMode
        ColorBlindnessMode: ColorBlindnessMode
        ScreenReader: ScreenReaderOptimization
        Keyboard: KeyboardNavigation

        // Text
        MinFontSize: int
        LineHeightMultiplier: float
        LetterSpacing: float

        // Timing
        FocusDelayMs: int
        TooltipDelayMs: int
        AnimationDurationMultiplier: float

        // Audio
        AudioDescriptions: bool
        SoundAlternatives: bool     // Visual alternatives to sounds
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 16: THEMES (4 Variants)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Theme variant identifier
    type ThemeVariant =
        | AerospaceDark         // Primary: OLED-optimized dark theme
        | AerospaceLight        // Secondary: High-ambient light theme
        | RetroGreenCRT         // Retro: Green phosphor CRT simulation
        | RetroAmberCRT         // Retro: Amber phosphor CRT simulation
        | Custom of string      // Custom user theme

    /// Theme metadata
    type ThemeMetadata = {
        Id: string
        Name: string
        Variant: ThemeVariant
        Version: string
        Author: string
        Description: string
        Created: DateTime
        Modified: DateTime
        Tags: string list
        PreviewImage: string option
    }

    /// Complete theme definition
    type ThemeDefinition = {
        Metadata: ThemeMetadata

        // Dimension 1: Standards
        StandardsCompliance: StandardsCompliance list

        // Dimension 2: Core Palette
        Palette: CorePalette

        // Dimension 3: Semantic Colors
        Semantic: SemanticColors

        // Dimension 4: Typography
        Typography: TypographySystem

        // Dimension 5: Layout
        Layout: LayoutSystem

        // Dimension 6: Borders
        Borders: Map<HierarchyLevel, BorderConfig>
        Hierarchy: Map<HierarchyLevel, VisualHierarchy>

        // Dimension 7: Glow Effects
        Glows: GlowPresets

        // Dimension 8: Animations
        Animations: AnimationCatalog
        ArmFireChoreography: ArmFireChoreography

        // Dimension 9: Sounds
        Sounds: SoundTheme

        // Dimensions 10-14: Components
        Navigation: NavigationComponents
        Status: StatusComponents
        Data: DataComponents
        Interaction: InteractionComponents
        Feedback: FeedbackComponents

        // Dimension 15: Accessibility
        Accessibility: AccessibilityConfig
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DIMENSION 17: TVIEW IMPLEMENTATION MAPPING
    // ═══════════════════════════════════════════════════════════════════════════

    /// tview primitive type mapping
    type TviewPrimitive =
        | Box
        | Button
        | Checkbox
        | DropDown
        | Flex
        | Form
        | Frame
        | Grid
        | Image
        | InputField
        | List
        | Modal
        | Pages
        | ProgressBar
        | Table
        | TextArea
        | TextView
        | TreeView

    /// tview style mapping
    type TviewStyleMapping = {
        Primitive: TviewPrimitive
        ForegroundColor: string     // tview color string
        BackgroundColor: string
        BorderColor: string
        TitleColor: string
        GraphicsColor: string
        Attributes: string list     // "Bold", "Underline", etc.
    }

    /// tview color syntax helper
    type TviewColorSyntax = {
        /// Format: [#RRGGBB] or [colorname]
        FgColor: ThemeColor -> string
        /// Format: [:#RRGGBB] or [:colorname]
        BgColor: ThemeColor -> string
        /// Format: [#RRGGBB:#RRGGBB] (fg:bg)
        FgBgColor: ThemeColor -> ThemeColor -> string
        /// Reset: [-]
        Reset: string
        /// Bold: [::b]
        Bold: string
        /// Underline: [::u]
        Underline: string
        /// Blink: [::l]
        Blink: string
        /// Dim: [::d]
        Dim: string
        /// Reverse: [::r]
        Reverse: string
    }

    /// Terminal capability detection
    type TerminalCapabilities = {
        TrueColor: bool             // 24-bit color support
        Color256: bool              // 256 color support
        Unicode: bool               // Full Unicode support
        BraillePatterns: bool       // Braille character support
        BoxDrawing: bool            // Box drawing characters
        GpuAccelerated: bool        // GPU rendering (Kitty, Alacritty, etc.)
        Sixel: bool                 // Sixel graphics
        Kitty: bool                 // Kitty graphics protocol
        Hyperlinks: bool            // OSC 8 hyperlinks
        TerminalWidth: int
        TerminalHeight: int
    }

    /// tview implementation helpers
    module TviewHelpers =

        /// Create tview color string from ThemeColor
        let toTviewFg (color: ThemeColor) : string =
            color.Rgb.ToTview()

        /// Create tview background color string
        let toTviewBg (color: ThemeColor) : string =
            color.Rgb.ToTviewBg()

        /// Create combined fg/bg color string
        let toTviewFgBg (fg: ThemeColor) (bg: ThemeColor) : string =
            sprintf "[%s:%s]"
                (fg.Rgb.ToHex())
                (bg.Rgb.ToHex())

        /// tview reset code
        let reset = "[-]"

        /// tview bold attribute
        let bold = "[::b]"

        /// tview underline attribute
        let underline = "[::u]"

        /// tview blink attribute
        let blink = "[::l]"

        /// tview dim attribute
        let dim = "[::d]"

        /// tview reverse attribute
        let reverse = "[::r]"

        /// Escape tview tags in text
        let escape (text: string) : string =
            text.Replace("[", "[[]").Replace("]", "[]]")

        /// Build styled text
        let styled (color: ThemeColor) (attrs: string) (text: string) : string =
            sprintf "%s%s%s%s" (toTviewFg color) attrs text reset

    // ═══════════════════════════════════════════════════════════════════════════
    // THEME PRESETS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Create default OLED-optimized color
    let private mkColor name r g b desc contrast oled p3 =
        {
            Name = name
            Rgb = { R = r; G = g; B = b }
            ColorSpace = if p3 then DisplayP3 else SRGB
            ContrastRatioOnBlack = contrast
            ContrastRatioOnWhite = 21.0 / contrast  // Approximate inverse
            OledSafe = oled
            P3Enhanced = p3
            Description = desc
        }

    /// Default Aerospace Dark palette
    let defaultDarkPalette : CorePalette = {
        // Backgrounds
        VoidBlack = mkColor "Void Black" 0uy 0uy 0uy "True OLED black" 1.0 true false
        SpaceBlack = mkColor "Space Black" 10uy 10uy 15uy "Near black with blue hint" 1.05 true false
        DeepSpace = mkColor "Deep Space" 13uy 17uy 23uy "GitHub dark background" 1.1 true false
        NightSky = mkColor "Night Sky" 21uy 21uy 32uy "Elevated surfaces" 1.2 true false
        Twilight = mkColor "Twilight" 30uy 30uy 46uy "Cards and panels" 1.4 true false
        Dusk = mkColor "Dusk" 37uy 37uy 48uy "Borders and dividers" 1.6 true false

        // Primary Accents
        PlasmaCyan = mkColor "Plasma Cyan" 0uy 255uy 255uy "Primary accent" 16.75 false true
        QuantumBlue = mkColor "Quantum Blue" 0uy 175uy 255uy "Secondary accent" 10.5 false true
        ElectricBlue = mkColor "Electric Blue" 0uy 128uy 255uy "Tertiary accent" 7.2 false true
        NeonPurple = mkColor "Neon Purple" 191uy 0uy 255uy "AI/special elements" 5.8 false true

        // Semantic
        NominalGreen = mkColor "Nominal Green" 0uy 255uy 136uy "Success/Go/Healthy" 14.2 false true
        CautionAmber = mkColor "Caution Amber" 255uy 170uy 0uy "Warning/Attention" 11.3 false true
        AlertRed = mkColor "Alert Red" 255uy 68uy 68uy "Error/Critical" 5.9 false true
        AdvisoryCyan = mkColor "Advisory Cyan" 0uy 221uy 221uy "Informational" 13.8 false true

        // Text
        BrightText = mkColor "Bright Text" 255uy 255uy 255uy "Primary text" 21.0 false false
        NormalText = mkColor "Normal Text" 224uy 224uy 224uy "Body text" 17.4 true false
        MutedText = mkColor "Muted Text" 128uy 128uy 144uy "Secondary text" 7.2 true false
        DimText = mkColor "Dim Text" 80uy 80uy 96uy "Disabled/hint" 3.8 true false

        // Data Visualization
        DataBlue = mkColor "Data Blue" 68uy 136uy 255uy "Primary data" 7.5 false true
        DataGreen = mkColor "Data Green" 68uy 255uy 136uy "Secondary data" 13.8 false true
        DataPurple = mkColor "Data Purple" 170uy 68uy 255uy "Tertiary data" 5.2 false true
        DataOrange = mkColor "Data Orange" 255uy 136uy 68uy "Quaternary data" 8.1 false true
        DataPink = mkColor "Data Pink" 255uy 68uy 170uy "Quinary data" 6.4 false true
    }

    /// Create default spacing unit
    let private mkSpacing name mult px chars =
        { Name = name; Multiplier = mult; Pixels = px; Characters = chars }

    /// Default spacing scale
    let defaultSpacingScale : SpacingScale = {
        BaseUnit = 8
        None = mkSpacing "none" 0 0 0
        Xs = mkSpacing "xs" 1 4 0      // Half unit - rounds to 0 chars
        Sm = mkSpacing "sm" 1 8 1
        Md = mkSpacing "md" 2 16 2
        Lg = mkSpacing "lg" 3 24 3
        Xl = mkSpacing "xl" 4 32 4
        Xxl = mkSpacing "xxl" 6 48 6
        Xxxl = mkSpacing "xxxl" 8 64 8
    }

    /// Default breakpoints
    let defaultBreakpoints : Breakpoint list = [
        { Name = "compact"; MinColumns = 80; MaxColumns = Some 99;
          LayoutColumns = 1; SidebarWidth = None; ContentMaxWidth = Some 78 }
        { Name = "standard"; MinColumns = 100; MaxColumns = Some 139;
          LayoutColumns = 2; SidebarWidth = Some 24; ContentMaxWidth = Some 110 }
        { Name = "wide"; MinColumns = 140; MaxColumns = Some 199;
          LayoutColumns = 3; SidebarWidth = Some 28; ContentMaxWidth = Some 160 }
        { Name = "ultrawide"; MinColumns = 200; MaxColumns = None;
          LayoutColumns = 4; SidebarWidth = Some 32; ContentMaxWidth = None }
    ]

    /// Light box drawing characters
    let lightBoxDrawing : BoxDrawingSet = {
        TopLeft = '┌'; TopRight = '┐'
        BottomLeft = '└'; BottomRight = '┘'
        Horizontal = '─'; Vertical = '│'
        TeeDown = '┬'; TeeUp = '┴'
        TeeRight = '├'; TeeLeft = '┤'
        Cross = '┼'
        RoundedTopLeft = Some '╭'; RoundedTopRight = Some '╮'
        RoundedBottomLeft = Some '╰'; RoundedBottomRight = Some '╯'
    }

    /// Heavy box drawing characters
    let heavyBoxDrawing : BoxDrawingSet = {
        TopLeft = '┏'; TopRight = '┓'
        BottomLeft = '┗'; BottomRight = '┛'
        Horizontal = '━'; Vertical = '┃'
        TeeDown = '┳'; TeeUp = '┻'
        TeeRight = '┣'; TeeLeft = '┫'
        Cross = '╋'
        RoundedTopLeft = None; RoundedTopRight = None
        RoundedBottomLeft = None; RoundedBottomRight = None
    }

    /// Double box drawing characters
    let doubleBoxDrawing : BoxDrawingSet = {
        TopLeft = '╔'; TopRight = '╗'
        BottomLeft = '╚'; BottomRight = '╝'
        Horizontal = '═'; Vertical = '║'
        TeeDown = '╦'; TeeUp = '╩'
        TeeRight = '╠'; TeeLeft = '╣'
        Cross = '╬'
        RoundedTopLeft = None; RoundedTopRight = None
        RoundedBottomLeft = None; RoundedBottomRight = None
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SERIALIZATION HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Serialize theme to JSON-compatible format
    let serializeTheme (theme: ThemeDefinition) : string =
        // Simple serialization - in production use System.Text.Json
        sprintf """{"id":"%s","name":"%s","variant":"%A","version":"%s"}"""
            theme.Metadata.Id
            theme.Metadata.Name
            theme.Metadata.Variant
            theme.Metadata.Version

    /// Export theme colors to CSS custom properties format
    let exportToCss (palette: CorePalette) : string =
        let lines = [
            sprintf "  --void-black: %s;" (palette.VoidBlack.Rgb.ToHex())
            sprintf "  --space-black: %s;" (palette.SpaceBlack.Rgb.ToHex())
            sprintf "  --plasma-cyan: %s;" (palette.PlasmaCyan.Rgb.ToHex())
            sprintf "  --quantum-blue: %s;" (palette.QuantumBlue.Rgb.ToHex())
            sprintf "  --nominal-green: %s;" (palette.NominalGreen.Rgb.ToHex())
            sprintf "  --caution-amber: %s;" (palette.CautionAmber.Rgb.ToHex())
            sprintf "  --alert-red: %s;" (palette.AlertRed.Rgb.ToHex())
        ]
        sprintf ":root {\n%s\n}" (String.concat "\n" lines)

    /// Export theme colors to ANSI escape code module
    let exportToAnsi (palette: CorePalette) : string =
        let lines = [
            sprintf "let voidBlack = \"%s\"" (palette.VoidBlack.Rgb.ToAnsi())
            sprintf "let plasmaCyan = \"%s\"" (palette.PlasmaCyan.Rgb.ToAnsi())
            sprintf "let nominalGreen = \"%s\"" (palette.NominalGreen.Rgb.ToAnsi())
            sprintf "let cautionAmber = \"%s\"" (palette.CautionAmber.Rgb.ToAnsi())
            sprintf "let alertRed = \"%s\"" (palette.AlertRed.Rgb.ToAnsi())
            sprintf "let reset = \"\\u001b[0m\""
        ]
        String.concat "\n" lines

    /// Export for tview (Go)
    let exportToTview (palette: CorePalette) : string =
        let lines = [
            "// Aerospace Theme Colors for tview"
            "var AerospaceColors = struct {"
            sprintf "    VoidBlack    string // %s" (palette.VoidBlack.Rgb.ToHex())
            sprintf "    PlasmaCyan   string // %s" (palette.PlasmaCyan.Rgb.ToHex())
            sprintf "    NominalGreen string // %s" (palette.NominalGreen.Rgb.ToHex())
            sprintf "    CautionAmber string // %s" (palette.CautionAmber.Rgb.ToHex())
            sprintf "    AlertRed     string // %s" (palette.AlertRed.Rgb.ToHex())
            "}{"
            sprintf "    VoidBlack:    \"%s\"," (palette.VoidBlack.Rgb.ToTview())
            sprintf "    PlasmaCyan:   \"%s\"," (palette.PlasmaCyan.Rgb.ToTview())
            sprintf "    NominalGreen: \"%s\"," (palette.NominalGreen.Rgb.ToTview())
            sprintf "    CautionAmber: \"%s\"," (palette.CautionAmber.Rgb.ToTview())
            sprintf "    AlertRed:     \"%s\"," (palette.AlertRed.Rgb.ToTview())
            "}"
        ]
        String.concat "\n" lines
