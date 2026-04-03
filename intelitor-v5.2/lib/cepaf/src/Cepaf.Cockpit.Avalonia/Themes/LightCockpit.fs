// =============================================================================
// Prajna C3I Cockpit - Light Cockpit Theme
// =============================================================================
// STAMP: SC-THEME-001 to SC-THEME-005
// =============================================================================

namespace Cepaf.Cockpit.Avalonia.Themes

open Avalonia.Media
open Cepaf.Cockpit.Avalonia.Domain.Types

/// <summary>
/// Light theme for bright environment operations
/// Material Design 3 compliant with AtomUI integration
/// </summary>
module LightCockpit =

    let primary = Color.Parse("#1976D2")
    let secondary = Color.Parse("#757575")
    let accent = Color.Parse("#FF5722")
    let background = Color.Parse("#FAFAFA")
    let surface = Color.Parse("#FFFFFF")
    let error = Color.Parse("#B00020")
    let warning = Color.Parse("#FFA000")
    let success = Color.Parse("#388E3C")
    let info = Color.Parse("#1976D2")
    let onPrimary = Color.Parse("#FFFFFF")
    let onBackground = Color.Parse("#212121")
    let onSurface = Color.Parse("#212121")

    let colorScheme : ColorScheme = {
        Primary = "#1976D2"
        Secondary = "#757575"
        Accent = "#FF5722"
        Background = "#FAFAFA"
        Surface = "#FFFFFF"
        Error = "#B00020"
        Warning = "#FFA000"
        Success = "#388E3C"
        Info = "#1976D2"
        OnPrimary = "#FFFFFF"
        OnBackground = "#212121"
        OnSurface = "#212121"
    }
