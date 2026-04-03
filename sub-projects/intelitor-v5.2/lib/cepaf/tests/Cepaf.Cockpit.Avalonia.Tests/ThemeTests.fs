/// Avalonia GUI Theme Tests
/// Tests for Dark Cockpit, Light, and Aerospace themes
module Cepaf.Cockpit.Avalonia.Tests.ThemeTests

open System
open Expecto

// ============================================================================
// Theme Definitions
// ============================================================================

type ThemeId = DarkCockpit | LightCockpit | AerospaceTheme

type ColorPalette = {
    Background: string
    Surface: string
    Primary: string
    Secondary: string
    Accent: string
    Error: string
    Warning: string
    Success: string
    TextPrimary: string
    TextSecondary: string
}

type ThemeConfig = {
    Id: ThemeId
    Name: string
    Palette: ColorPalette
    FontFamily: string
    BorderRadius: int
}

// ============================================================================
// Dark Cockpit Theme (NASA-STD-3000)
// ============================================================================

let darkCockpitPalette = {
    Background = "#0D0D0D"      // Near black
    Surface = "#1A1A1A"         // Dark gray
    Primary = "#00FF00"         // Green (status OK)
    Secondary = "#00BFFF"       // Deep sky blue
    Accent = "#FFD700"          // Gold (highlights)
    Error = "#FF0000"           // Red (critical)
    Warning = "#FFA500"         // Orange (warning)
    Success = "#32CD32"         // Lime green (success)
    TextPrimary = "#00FF00"     // Green text
    TextSecondary = "#808080"   // Gray text
}

let darkCockpitTheme = {
    Id = DarkCockpit
    Name = "Dark Cockpit"
    Palette = darkCockpitPalette
    FontFamily = "Consolas, 'Courier New', monospace"
    BorderRadius = 2
}

// ============================================================================
// Light Cockpit Theme
// ============================================================================

let lightCockpitPalette = {
    Background = "#FFFFFF"
    Surface = "#F5F5F5"
    Primary = "#1976D2"         // Blue
    Secondary = "#424242"       // Dark gray
    Accent = "#FF5722"          // Deep orange
    Error = "#D32F2F"           // Red
    Warning = "#F57C00"         // Orange
    Success = "#388E3C"         // Green
    TextPrimary = "#212121"     // Near black
    TextSecondary = "#757575"   // Gray
}

let lightCockpitTheme = {
    Id = LightCockpit
    Name = "Light Mode"
    Palette = lightCockpitPalette
    FontFamily = "'Segoe UI', Roboto, sans-serif"
    BorderRadius = 4
}

// ============================================================================
// Aerospace Theme
// ============================================================================

let aerospacePalette = {
    Background = "#0A1628"      // Dark navy
    Surface = "#132035"         // Navy
    Primary = "#4FC3F7"         // Light blue
    Secondary = "#81D4FA"       // Sky blue
    Accent = "#FFB300"          // Amber
    Error = "#FF5252"           // Red
    Warning = "#FFB74D"         // Orange
    Success = "#69F0AE"         // Mint green
    TextPrimary = "#E3F2FD"     // Light blue-white
    TextSecondary = "#90A4AE"   // Blue gray
}

let aerospaceTheme = {
    Id = AerospaceTheme
    Name = "Aerospace"
    Palette = aerospacePalette
    FontFamily = "'JetBrains Mono', Consolas, monospace"
    BorderRadius = 3
}

// ============================================================================
// Theme Lookup
// ============================================================================

let getTheme (id: ThemeId) =
    match id with
    | DarkCockpit -> darkCockpitTheme
    | LightCockpit -> lightCockpitTheme
    | AerospaceTheme -> aerospaceTheme

let allThemes = [darkCockpitTheme; lightCockpitTheme; aerospaceTheme]

// ============================================================================
// Color Utility Functions
// ============================================================================

let parseHexColor (hex: string) =
    let hex = hex.TrimStart('#')
    if hex.Length = 6 then
        let r = Convert.ToInt32(hex.Substring(0, 2), 16)
        let g = Convert.ToInt32(hex.Substring(2, 2), 16)
        let b = Convert.ToInt32(hex.Substring(4, 2), 16)
        Some (r, g, b)
    else
        None

let calculateLuminance (r: int) (g: int) (b: int) =
    // Relative luminance formula
    let rs = float r / 255.0
    let gs = float g / 255.0
    let bs = float b / 255.0
    0.2126 * rs + 0.7152 * gs + 0.0722 * bs

let contrastRatio (lum1: float) (lum2: float) =
    let lighter = max lum1 lum2
    let darker = min lum1 lum2
    (lighter + 0.05) / (darker + 0.05)

let meetsWCAGAA (contrastRatio: float) =
    contrastRatio >= 4.5

let meetsWCAGAAA (contrastRatio: float) =
    contrastRatio >= 7.0

// ============================================================================
// Theme Tests
// ============================================================================

[<Tests>]
let darkCockpitTests =
    testList "DarkCockpitTheme" [
        test "should have correct name" {
            Expect.equal darkCockpitTheme.Name "Dark Cockpit" "Name"
        }

        test "should use monospace font" {
            Expect.stringContains darkCockpitTheme.FontFamily "Consolas" "Monospace font"
        }

        test "should have dark background" {
            match parseHexColor darkCockpitPalette.Background with
            | Some (r, g, b) ->
                let lum = calculateLuminance r g b
                Expect.isLessThan lum 0.1 "Background should be dark"
            | None ->
                failtest "Invalid background color"
        }

        test "should have green primary color" {
            Expect.equal darkCockpitPalette.Primary "#00FF00" "Primary is green"
        }

        test "should have minimal border radius" {
            Expect.equal darkCockpitTheme.BorderRadius 2 "Sharp corners for cockpit aesthetic"
        }
    ]

[<Tests>]
let lightCockpitTests =
    testList "LightCockpitTheme" [
        test "should have correct name" {
            Expect.equal lightCockpitTheme.Name "Light Mode" "Name"
        }

        test "should use sans-serif font" {
            Expect.stringContains lightCockpitTheme.FontFamily "Roboto" "Sans-serif font"
        }

        test "should have light background" {
            match parseHexColor lightCockpitPalette.Background with
            | Some (r, g, b) ->
                let lum = calculateLuminance r g b
                Expect.isGreaterThan lum 0.9 "Background should be light"
            | None ->
                failtest "Invalid background color"
        }

        test "should have blue primary color" {
            Expect.stringContains lightCockpitPalette.Primary "1976D2" "Primary is blue"
        }
    ]

[<Tests>]
let aerospaceTests =
    testList "AerospaceTheme" [
        test "should have correct name" {
            Expect.equal aerospaceTheme.Name "Aerospace" "Name"
        }

        test "should have navy background" {
            match parseHexColor aerospacePalette.Background with
            | Some (r, g, b) ->
                Expect.isLessThan g b "Blue component should dominate"
            | None ->
                failtest "Invalid background color"
        }

        test "should use JetBrains Mono font" {
            Expect.stringContains aerospaceTheme.FontFamily "JetBrains" "JetBrains Mono font"
        }
    ]

// ============================================================================
// Color Contrast Tests (WCAG Compliance)
// ============================================================================

let testColorContrast name theme textColor bgColor =
    test name {
        match parseHexColor textColor, parseHexColor bgColor with
        | Some (tr, tg, tb), Some (br, bg, bb) ->
            let textLum = calculateLuminance tr tg tb
            let bgLum = calculateLuminance br bg bb
            let ratio = contrastRatio textLum bgLum
            Expect.isTrue (meetsWCAGAA ratio) (sprintf "Contrast ratio %.2f should meet WCAG AA (4.5)" ratio)
        | _ ->
            failtest "Invalid color format"
    }

[<Tests>]
let contrastTests =
    testList "ColorContrast" [
        testColorContrast "Dark: primary on background"
            darkCockpitTheme
            darkCockpitPalette.TextPrimary
            darkCockpitPalette.Background

        testColorContrast "Light: primary on background"
            lightCockpitTheme
            lightCockpitPalette.TextPrimary
            lightCockpitPalette.Background

        testColorContrast "Aerospace: primary on background"
            aerospaceTheme
            aerospacePalette.TextPrimary
            aerospacePalette.Background

        test "All error colors should be visible on backgrounds" {
            for theme in allThemes do
                match parseHexColor theme.Palette.Error, parseHexColor theme.Palette.Background with
                | Some (er, eg, eb), Some (br, bg, bb) ->
                    let errorLum = calculateLuminance er eg eb
                    let bgLum = calculateLuminance br bg bb
                    let ratio = contrastRatio errorLum bgLum
                    Expect.isGreaterThan ratio 3.0 (sprintf "%s error color should be visible" theme.Name)
                | _ ->
                    failtest "Invalid color format"
        }
    ]

// ============================================================================
// Theme Consistency Tests
// ============================================================================

[<Tests>]
let consistencyTests =
    testList "ThemeConsistency" [
        test "All themes should have unique IDs" {
            let ids = allThemes |> List.map (fun t -> t.Id)
            let uniqueIds = ids |> List.distinct
            Expect.equal ids.Length uniqueIds.Length "IDs should be unique"
        }

        test "All themes should have non-empty names" {
            for theme in allThemes do
                Expect.isNotEmpty theme.Name (sprintf "Theme %A should have name" theme.Id)
        }

        test "All themes should have non-empty font families" {
            for theme in allThemes do
                Expect.isNotEmpty theme.FontFamily (sprintf "Theme %A should have font" theme.Id)
        }

        test "All themes should have positive border radius" {
            for theme in allThemes do
                Expect.isGreaterThanOrEqual theme.BorderRadius 0 (sprintf "Theme %A border radius" theme.Id)
        }

        test "All color values should be valid hex" {
            for theme in allThemes do
                let colors = [
                    theme.Palette.Background
                    theme.Palette.Surface
                    theme.Palette.Primary
                    theme.Palette.Secondary
                    theme.Palette.Accent
                    theme.Palette.Error
                    theme.Palette.Warning
                    theme.Palette.Success
                    theme.Palette.TextPrimary
                    theme.Palette.TextSecondary
                ]
                for color in colors do
                    Expect.isTrue (parseHexColor color).IsSome (sprintf "%s: %s should be valid hex" theme.Name color)
        }
    ]

// ============================================================================
// Theme Switching Tests
// ============================================================================

type ThemeState = {
    CurrentTheme: ThemeId
    SystemPrefersDark: bool
    UserPreference: ThemeId option
}

let resolveTheme (state: ThemeState) =
    match state.UserPreference with
    | Some pref -> pref
    | None ->
        if state.SystemPrefersDark then DarkCockpit
        else LightCockpit

let themeTransition (from: ThemeId) (to': ThemeId) =
    // Validate transition (any transition is valid)
    true

[<Tests>]
let themeSwitchingTests =
    testList "ThemeSwitching" [
        test "should respect user preference" {
            let state = { CurrentTheme = DarkCockpit; SystemPrefersDark = false; UserPreference = Some AerospaceTheme }
            Expect.equal (resolveTheme state) AerospaceTheme "User preference wins"
        }

        test "should fall back to system preference" {
            let darkSystem = { CurrentTheme = LightCockpit; SystemPrefersDark = true; UserPreference = None }
            let lightSystem = { CurrentTheme = DarkCockpit; SystemPrefersDark = false; UserPreference = None }

            Expect.equal (resolveTheme darkSystem) DarkCockpit "Dark for dark system"
            Expect.equal (resolveTheme lightSystem) LightCockpit "Light for light system"
        }

        test "should lookup themes correctly" {
            Expect.equal (getTheme DarkCockpit).Name "Dark Cockpit" "Dark lookup"
            Expect.equal (getTheme LightCockpit).Name "Light Mode" "Light lookup"
            Expect.equal (getTheme AerospaceTheme).Name "Aerospace" "Aerospace lookup"
        }
    ]

// ============================================================================
// Status Color Tests
// ============================================================================

let healthStatusColor (theme: ThemeConfig) (health: float) =
    if health >= 90.0 then theme.Palette.Success
    elif health >= 70.0 then theme.Palette.Warning
    else theme.Palette.Error

let alarmStatusColor (theme: ThemeConfig) (severity: string) =
    match severity.ToLower() with
    | "critical" -> theme.Palette.Error
    | "warning" -> theme.Palette.Warning
    | "info" -> theme.Palette.Primary
    | _ -> theme.Palette.TextSecondary

[<Tests>]
let statusColorTests =
    testList "StatusColors" [
        test "Health colors should match thresholds" {
            let theme = darkCockpitTheme
            Expect.equal (healthStatusColor theme 95.0) theme.Palette.Success "95% is success"
            Expect.equal (healthStatusColor theme 75.0) theme.Palette.Warning "75% is warning"
            Expect.equal (healthStatusColor theme 50.0) theme.Palette.Error "50% is error"
        }

        test "Alarm colors should match severity" {
            let theme = darkCockpitTheme
            Expect.equal (alarmStatusColor theme "critical") theme.Palette.Error "Critical is error"
            Expect.equal (alarmStatusColor theme "warning") theme.Palette.Warning "Warning is warning"
            Expect.equal (alarmStatusColor theme "info") theme.Palette.Primary "Info is primary"
        }

        test "Status colors should work across all themes" {
            for theme in allThemes do
                // All themes should have distinct status colors
                Expect.notEqual (healthStatusColor theme 95.0) (healthStatusColor theme 50.0)
                    (sprintf "%s should have distinct health colors" theme.Name)
        }
    ]
