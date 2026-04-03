// =============================================================================
// Prajna C3I Cockpit - Aerospace Theme
// =============================================================================
// STAMP: SC-THEME-001 to SC-THEME-005, SC-HMI-001
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | SC-THEME-*, NASA-STD-3000, MIL-STD-1472H |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Themes

open Avalonia.Media
open Cepaf.Cockpit.Avalonia.Domain.Types

/// <summary>
/// Aerospace-grade theme for safety-critical C3I operations
/// Designed per NASA-STD-3000 and MIL-STD-1472H HMI standards
/// </summary>
module AerospaceTheme =

    // =========================================================================
    // Color Palette (MIL-STD-1472H Compliant)
    // =========================================================================

    /// Primary cyan for active elements
    let primaryCyan = Color.Parse("#00BCD4")

    /// Secondary blue-grey for backgrounds
    let secondaryBlueGrey = Color.Parse("#263238")

    /// Accent orange for highlighting
    let accentOrange = Color.Parse("#FF9800")

    /// Deep space background
    let backgroundDeep = Color.Parse("#0A0A0A")

    /// Surface panels
    let surfacePanel = Color.Parse("#1A1A2E")

    /// Error/critical red
    let errorRed = Color.Parse("#FF5252")

    /// Warning amber
    let warningAmber = Color.Parse("#FFD740")

    /// Success green
    let successGreen = Color.Parse("#69F0AE")

    /// Info blue
    let infoBlue = Color.Parse("#40C4FF")

    /// Terminal green for text (classic aerospace)
    let terminalGreen = Color.Parse("#00FF00")

    /// White for primary text on dark
    let textPrimary = Color.Parse("#FFFFFF")

    /// Muted grey for secondary text
    let textSecondary = Color.Parse("#B0B0B0")

    // =========================================================================
    // Severity Colors (SC-HMI-001)
    // =========================================================================

    /// Get color for health status
    let healthStatusColor (status: HealthStatus) : Color =
        match status with
        | Healthy -> successGreen
        | Degraded -> warningAmber
        | Critical -> errorRed
        | Unknown -> textSecondary

    /// Get color for alarm severity
    let alarmSeverityColor (severity: AlarmSeverity) : Color =
        match severity with
        | AlarmSeverity.Critical -> errorRed
        | AlarmSeverity.High -> accentOrange
        | AlarmSeverity.Medium -> warningAmber
        | AlarmSeverity.Low -> infoBlue
        | AlarmSeverity.Info -> textSecondary

    /// Get color for threat severity
    let threatSeverityColor (severity: ThreatSeverity) : Color =
        match severity with
        | Extinction -> Color.Parse("#FF0000")  // Bright red
        | ThreatSeverity.Critical -> errorRed
        | ThreatSeverity.High -> accentOrange
        | ThreatSeverity.Medium -> warningAmber
        | ThreatSeverity.Low -> infoBlue

    /// Get color for OODA phase
    let oodaPhaseColor (phase: OodaPhase) : Color =
        match phase with
        | Observe -> primaryCyan
        | Orient -> infoBlue
        | Decide -> warningAmber
        | Act -> successGreen
        | Complete -> Color.Parse("#9E9E9E")

    /// Get color for connection status
    let connectionStatusColor (status: ConnectionStatus) : Color =
        match status with
        | Connected -> successGreen
        | Connecting -> warningAmber
        | Disconnected -> textSecondary
        | Error _ -> errorRed

    // =========================================================================
    // Gradient Definitions
    // =========================================================================

    /// Create gradient for gauge fill
    let gaugeGradient (value: float) : IBrush =
        let color =
            if value >= 0.9 then successGreen
            elif value >= 0.7 then primaryCyan
            elif value >= 0.5 then warningAmber
            else errorRed

        SolidColorBrush(color) :> IBrush

    /// Create gradient for health indicator
    let healthGradient (status: HealthStatus) : IBrush =
        SolidColorBrush(healthStatusColor status) :> IBrush

    // =========================================================================
    // Typography (NASA-STD-3000)
    // =========================================================================

    /// Monospace font for data display
    let monoFont = "JetBrains Mono, Fira Code, Consolas, monospace"

    /// Sans-serif font for labels
    let sansFont = "Inter, Segoe UI, sans-serif"

    /// Font sizes per HMI standards
    let fontSizeXL = 24.0
    let fontSizeL = 18.0
    let fontSizeM = 14.0
    let fontSizeS = 12.0
    let fontSizeXS = 10.0

    // =========================================================================
    // Spacing (8px grid)
    // =========================================================================

    let spacingXS = 4.0
    let spacingS = 8.0
    let spacingM = 16.0
    let spacingL = 24.0
    let spacingXL = 32.0
    let spacingXXL = 48.0

    // =========================================================================
    // Border Radii
    // =========================================================================

    let radiusS = 4.0
    let radiusM = 8.0
    let radiusL = 12.0
    let radiusFull = 9999.0  // Pill shape

    // =========================================================================
    // Shadows (subtle for dark theme)
    // =========================================================================

    let shadowElevation1 = "0 1px 3px rgba(0,0,0,0.3)"
    let shadowElevation2 = "0 2px 6px rgba(0,0,0,0.4)"
    let shadowElevation3 = "0 4px 12px rgba(0,0,0,0.5)"

    // =========================================================================
    // Animation Durations
    // =========================================================================

    let durationFast = 150   // ms
    let durationNormal = 300 // ms
    let durationSlow = 500   // ms

    // =========================================================================
    // Glow Effects (Aerospace style)
    // =========================================================================

    /// Create glow brush for active elements
    let glowBrush (color: Color) : IBrush =
        // In production, use DropShadowEffect
        SolidColorBrush(color) :> IBrush

    /// Pulsing animation for alerts
    let pulseAnimation = {| Duration = 1000; AutoReverse = true |}

    // =========================================================================
    // Status Indicators
    // =========================================================================

    type StatusIndicator = {
        Color: Color
        GlowColor: Color
        PulseEnabled: bool
    }

    let createStatusIndicator (status: HealthStatus) : StatusIndicator =
        let color = healthStatusColor status
        {
            Color = color
            GlowColor = color
            PulseEnabled = status = Critical
        }

    // =========================================================================
    // ColorScheme Export
    // =========================================================================

    let colorScheme : ColorScheme = {
        Primary = "#00BCD4"
        Secondary = "#263238"
        Accent = "#FF9800"
        Background = "#0A0A0A"
        Surface = "#1A1A2E"
        Error = "#FF5252"
        Warning = "#FFD740"
        Success = "#69F0AE"
        Info = "#40C4FF"
        OnPrimary = "#000000"
        OnBackground = "#00FF00"
        OnSurface = "#FFFFFF"
    }
