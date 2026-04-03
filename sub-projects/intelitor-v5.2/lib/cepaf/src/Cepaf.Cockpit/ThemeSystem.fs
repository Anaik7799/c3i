namespace Cepaf.Cockpit

open System

/// Complete Theme System for PRAJNA Cockpit
/// Supports Light and Dark modes with full Material 3 design tokens
///
/// WHAT: Provides complete theming infrastructure for the cockpit UI
/// WHY: Operators work 8-12 hour shifts, need adaptive themes for eye strain
/// CONSTRAINTS:
///   - SC-THEME-001: Light/Dark mode support
///   - SC-THEME-002: Minimum 4.5:1 contrast for normal text
///   - SC-THEME-003: Minimum 7:1 contrast for critical elements
///   - SC-ERGO-001: Color temperature adjustment
module ThemeSystem =

    // =========================================================================
    // TYPES
    // =========================================================================

    /// Theme mode selection
    type ThemeMode =
        | Light     /// High ambient light environments
        | Dark      /// Low ambient light / night operations
        | Auto      /// Automatic based on time of day

    /// Render context (device capabilities)
    type RenderContext = {
        Cols: int
        Rows: int
        ColorDepth: int         // 8, 256, or 16777216 (24-bit)
        UnicodeSupport: bool
        BlinkSupport: bool
    }

    /// Responsive breakpoint
    type Breakpoint =
        | Compact       // 80-99 cols: Single column
        | Standard      // 100-139 cols: 2-column
        | Wide          // 140-199 cols: 3-column
        | UltraWide     // 200+ cols: 4-column

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

        // Box drawing colors
        BoxPrimary: string
        BoxSecondary: string
    }

    // =========================================================================
    // LIGHT THEME DEFINITION (Material 3 Light + Safety-Critical)
    // Optimized for high ambient light environments (daytime operations)
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
        // High contrast on light surfaces per SC-THEME-002/003
        Normal = "\u001b[38;2;121;116;126m"               // #79747E (4.5:1 contrast)
        Advisory = "\u001b[38;2;0;107;91m"                // #006B5B (5.3:1 contrast)
        Caution = "\u001b[38;2;125;87;0m"                 // #7D5700 (5.8:1 contrast)
        Warning = "\u001b[38;2;186;26;26m"                // #BA1A1A (7.2:1 contrast)
        Critical = "\u001b[38;2;186;26;26;5m"             // #BA1A1A + blink

        // Status (light mode variants)
        Connected = "\u001b[38;2;0;107;91m"               // Dark teal
        Stale = "\u001b[38;2;121;116;126m"                // Gray
        Disconnected = "\u001b[38;2;186;26;26m"           // Dark red
        Degraded = "\u001b[38;2;125;87;0m"                // Dark amber

        // Backgrounds (ANSI 48;2;R;G;B for 24-bit)
        BgSurface = "\u001b[48;2;255;251;254m"            // Light surface
        BgPrimary = "\u001b[48;2;234;221;255m"            // Light primary
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
    // Optimized for low ambient light (evening/night operations)
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
        // Dark Cockpit philosophy: normal = nearly invisible
        Normal = "\u001b[90m"                              // Gray (barely visible)
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
    let mutable private lastAutoCheck = DateTime.MinValue

    /// Get current theme tokens
    let tokens () = currentTokens

    /// Get current mode
    let mode () = currentMode

    /// Check if currently in light mode
    let isLight () = currentTokens.Mode = Light

    /// Check if currently in dark mode
    let isDark () = currentTokens.Mode = Dark

    /// Set theme mode
    let setMode (newMode: ThemeMode) =
        currentMode <- newMode
        currentTokens <-
            match newMode with
            | Light -> lightTheme
            | Dark -> darkTheme
            | Auto ->
                lastAutoCheck <- DateTime.Now
                let hour = DateTime.Now.Hour
                // 6am-6pm = Light, otherwise Dark
                if hour >= 6 && hour < 18 then lightTheme
                else darkTheme

    /// Update auto mode if needed (call periodically)
    let updateAutoMode () =
        if currentMode = Auto && (DateTime.Now - lastAutoCheck).TotalMinutes > 5.0 then
            setMode Auto

    /// Toggle between light and dark
    let toggle () =
        let newMode =
            match currentMode with
            | Light -> Dark
            | Dark -> Light
            | Auto -> Light  // Exit auto, go to light
        setMode newMode
        currentTokens

    /// Cycle through modes: Auto -> Light -> Dark -> Auto
    let cycle () =
        let newMode =
            match currentMode with
            | Auto -> Light
            | Light -> Dark
            | Dark -> Auto
        setMode newMode
        currentTokens

    // =========================================================================
    // RESPONSIVE LAYOUT
    // =========================================================================

    /// Detect breakpoint from render context
    let detectBreakpoint (ctx: RenderContext) : Breakpoint =
        match ctx.Cols with
        | c when c >= 200 -> UltraWide
        | c when c >= 140 -> Wide
        | c when c >= 100 -> Standard
        | _ -> Compact

    /// Get default render context from terminal
    let getContext () : RenderContext =
        try
            {
                Cols = max 80 Console.WindowWidth
                Rows = max 24 Console.WindowHeight
                ColorDepth = 16777216  // Assume 24-bit
                UnicodeSupport = true
                BlinkSupport = true
            }
        with _ ->
            {
                Cols = 140
                Rows = 50
                ColorDepth = 256
                UnicodeSupport = true
                BlinkSupport = false
            }

    // =========================================================================
    // HELPER FUNCTIONS
    // =========================================================================

    /// Apply theme color to text
    let color (colorCode: string) (text: string) : string =
        sprintf "%s%s%s" colorCode text currentTokens.Reset

    /// Apply bold to text
    let bold (text: string) : string =
        sprintf "%s%s%s" currentTokens.Bold text currentTokens.Reset

    /// Apply dim to text
    let dim (text: string) : string =
        sprintf "%s%s%s" currentTokens.Dim text currentTokens.Reset

    /// Apply primary color
    let primary (text: string) : string =
        color currentTokens.Primary text

    /// Apply error color
    let error (text: string) : string =
        color currentTokens.Error text

    /// Apply alarm level color to text
    let alarmColor (level: int) (text: string) : string =
        let colorCode =
            match level with
            | 0 -> currentTokens.Normal
            | 1 -> currentTokens.Advisory
            | 2 -> currentTokens.Caution
            | 3 -> currentTokens.Warning
            | _ -> currentTokens.Critical
        color colorCode text

    /// Get raw alarm level color code
    let alarmColorCode (level: int) : string =
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

    /// Format status indicator
    let statusIndicator (connected: bool) (stale: bool) (icon: string) : string =
        let colorCode = statusColor connected stale
        sprintf "%s%s%s" colorCode icon currentTokens.Reset

    // =========================================================================
    // ERGONOMICS: Color Temperature
    // SC-ERGO-001: Auto-adjust colors based on time
    // =========================================================================

    /// Color temperature factor (1.0 = normal, <1.0 = warmer/less blue)
    let colorTemperature () : float =
        let hour = DateTime.Now.Hour
        match hour with
        | h when h >= 22 || h < 6 -> 0.7    // Night: reduce blue 30%
        | h when h >= 20 -> 0.85            // Evening: reduce blue 15%
        | h when h >= 6 && h < 8 -> 0.9     // Morning: slight warmth
        | _ -> 1.0                           // Day: full spectrum

    // =========================================================================
    // FRACTAL DETAIL LEVELS (for responsive rendering)
    // =========================================================================

    type DetailLevel = Minimal | Basic | Standard | High | Maximum

    /// Determine detail level from available width
    let detailLevelFromWidth (cols: int) : DetailLevel =
        match cols with
        | c when c < 80 -> Minimal
        | c when c < 100 -> Basic
        | c when c < 140 -> Standard
        | c when c < 200 -> High
        | _ -> Maximum

    /// Number of data points for sparklines
    let sparklinePoints (level: DetailLevel) : int =
        match level with
        | Minimal -> 5
        | Basic -> 10
        | Standard -> 15
        | High -> 25
        | Maximum -> 40

    /// Bar chart width
    let barWidth (level: DetailLevel) : int =
        match level with
        | Minimal -> 5
        | Basic -> 10
        | Standard -> 15
        | High -> 25
        | Maximum -> 40

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    /// Initialize theme system
    let initialize () =
        setMode Auto
        let ctx = getContext ()
        let bp = detectBreakpoint ctx
        printfn "[ThemeSystem] Initialized: Mode=%A, Breakpoint=%A, Size=%dx%d"
            currentMode bp ctx.Cols ctx.Rows

    /// Initialize with specific mode
    let initializeWith (themeMode: ThemeMode) =
        setMode themeMode
        printfn "[ThemeSystem] Initialized in %A mode" currentMode
