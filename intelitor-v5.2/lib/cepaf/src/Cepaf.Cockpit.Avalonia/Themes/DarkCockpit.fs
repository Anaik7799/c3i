// =============================================================================
// Prajna C3I Cockpit - Dark Cockpit Theme
// =============================================================================
// STAMP: SC-THEME-001 to SC-THEME-005
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Themes

open Avalonia.Media
open Cepaf.Cockpit.Avalonia.Domain.Types

/// <summary>
/// Dark theme for standard cockpit operations
/// Material Design 3 compliant with AtomUI integration
/// </summary>
module DarkCockpit =

    let primary = Color.Parse("#64B5F6") // Lightened for dark mode (AAA)
    let secondary = Color.Parse("#B0BEC5") // Lightened for contrast
    let accent = Color.Parse("#FF8A65") // Lightened accent
    let background = Color.Parse("#000000") // Pure black for max contrast
    let surface = Color.Parse("#121212") // Darker surface
    let error = Color.Parse("#EF9A9A") // Lightened error
    let warning = Color.Parse("#FFCC80")
    let success = Color.Parse("#A5D6A7")
    let info = Color.Parse("#90CAF9")
    let onPrimary = Color.Parse("#000000") // Black text on light primary
    let onBackground = Color.Parse("#FFFFFF") // White text on black
    let onSurface = Color.Parse("#FFFFFF")

    let colorScheme : ColorScheme = {
        Primary = "#64B5F6"
        Secondary = "#B0BEC5"
        Accent = "#FF8A65"
        Background = "#000000"
        Surface = "#121212"
        Error = "#EF9A9A"
        Warning = "#FFCC80"
        Success = "#A5D6A7"
        Info = "#90CAF9"
        OnPrimary = "#000000"
        OnBackground = "#FFFFFF"
        OnSurface = "#FFFFFF"
    }
