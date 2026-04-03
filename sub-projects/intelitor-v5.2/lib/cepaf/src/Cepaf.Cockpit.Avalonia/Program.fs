// =============================================================================
// Prajna C3I Cockpit - Desktop Application Entry Point
// =============================================================================
// STAMP: SC-HMI-001 to SC-HMI-011
// Standards: NASA-STD-3000, NUREG-0700, MIL-STD-1472H, IEC 61508
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-03 |
// | Author | Cybernetic Architect |
// | Reference | HOLON_FOUNDERS_DIRECTIVE |
// =============================================================================

namespace Cepaf.Cockpit.Avalonia

open System
open Avalonia
open Avalonia.Controls
open Avalonia.Controls.ApplicationLifetimes
open Avalonia.Themes.Fluent
open Fabulous.Avalonia

/// <summary>
/// Prajna C3I Cockpit Desktop Application
/// Safety-critical HMI following aerospace and nuclear industry standards
/// </summary>
module Program =

    // =========================================================================
    // Application Configuration
    // =========================================================================

    /// Application configuration for safety-critical HMI
    type CockpitConfig = {
        /// Elixir backend URL
        ElixirUrl: string
        /// Zenoh router address
        ZenohRouter: string
        /// Dashboard refresh interval in milliseconds
        RefreshIntervalMs: int
        /// Enable telemetry collection
        TelemetryEnabled: bool
        /// OTEL endpoint for observability
        OtelEndpoint: string
        /// Configuration profile (development, test, production, sil4)
        Profile: string
    }

    /// Default configuration
    let defaultConfig = {
        ElixirUrl = "http://localhost:4000"
        ZenohRouter = "tcp/localhost:7447"
        RefreshIntervalMs = 30000
        TelemetryEnabled = true
        OtelEndpoint = "http://localhost:4317"
        Profile = "development"
    }

    // =========================================================================
    // Avalonia Application
    // =========================================================================

    /// Avalonia application class
    type PrajnaCockpitApp() =
        inherit Application()

        override this.Initialize() =
            // Apply Fluent theme (Material Design 3 compatible)
            this.Styles.Add(FluentTheme())

            // Set request culture for accessibility
            this.RequestedThemeVariant <- Styling.ThemeVariant.Dark

        override this.OnFrameworkInitializationCompleted() =
            match this.ApplicationLifetime with
            | :? IClassicDesktopStyleApplicationLifetime as desktop ->
                // Create main window
                let window = Window(
                    Title = "Prajna C3I Cockpit - Indrajaal v21.1.0",
                    Width = 1600.0,
                    Height = 900.0,
                    MinWidth = 1024.0,
                    MinHeight = 768.0,
                    WindowStartupLocation = WindowStartupLocation.CenterScreen
                )

                // Set Fabulous program content
                let content = FabulousAppBuilder.Configure(App.program)
                window.Content <- content

                // Set as main window
                desktop.MainWindow <- window

                // Log startup
                printfn "[Prajna] C3I Cockpit starting..."
                printfn "[Prajna] Elixir backend: %s" defaultConfig.ElixirUrl
                printfn "[Prajna] Zenoh router: %s" defaultConfig.ZenohRouter
                printfn "[Prajna] Profile: %s" defaultConfig.Profile

            | :? ISingleViewApplicationLifetime as singleView ->
                // Mobile/web single view mode
                let content = FabulousAppBuilder.Configure(App.program)
                singleView.MainView <- content :?> Control

            | _ -> ()

            base.OnFrameworkInitializationCompleted()

    // =========================================================================
    // Application Builder
    // =========================================================================

    /// Build Avalonia application with safety-critical configuration
    let buildApp (args: string array) =
        AppBuilder
            .Configure<PrajnaCockpitApp>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace()

    // =========================================================================
    // Entry Point
    // =========================================================================

    /// <summary>
    /// Main entry point for Prajna C3I Cockpit
    /// </summary>
    /// <param name="args">Command line arguments</param>
    /// <returns>Exit code (0 = success)</returns>
    [<EntryPoint>]
    let main (args: string array) =
        try
            // Print banner
            printfn ""
            printfn "    ●╮       ╭●"
            printfn "     ╰╮ ╭─╮ ╭╯"
            printfn "  ●───◉─┤◈├─◉───●   PRAJNA C3I COCKPIT"
            printfn "     ╭╯ ╰─╯ ╰╮       Indrajaal v21.1.0"
            printfn "    ●╯       ╰●       Founder's Covenant"
            printfn ""
            printfn "  Safety-Critical HMI for Cybernetic Security"
            printfn "  Standards: NASA-STD-3000 | NUREG-0700 | IEC 61508"
            printfn ""

            // Parse command line arguments
            let mutable config = defaultConfig

            for arg in args do
                match arg with
                | "--production" ->
                    config <- { config with Profile = "production" }
                | "--sil4" ->
                    config <- { config with Profile = "sil4" }
                | "--test" ->
                    config <- { config with Profile = "test" }
                | arg when arg.StartsWith("--elixir=") ->
                    config <- { config with ElixirUrl = arg.Substring(9) }
                | arg when arg.StartsWith("--zenoh=") ->
                    config <- { config with ZenohRouter = arg.Substring(8) }
                | "--no-telemetry" ->
                    config <- { config with TelemetryEnabled = false }
                | "--help" | "-h" ->
                    printfn "Usage: prajna-cockpit [OPTIONS]"
                    printfn ""
                    printfn "Options:"
                    printfn "  --production      Use production profile"
                    printfn "  --sil4            Use SIL-4 safety-critical profile"
                    printfn "  --test            Use test profile"
                    printfn "  --elixir=URL      Set Elixir backend URL"
                    printfn "  --zenoh=ADDR      Set Zenoh router address"
                    printfn "  --no-telemetry    Disable telemetry collection"
                    printfn "  --help, -h        Show this help message"
                    printfn ""
                    0
                | _ -> ()

            // Start application
            printfn "[Prajna] Configuration loaded: %s profile" config.Profile
            printfn "[Prajna] Starting Avalonia desktop application..."

            buildApp(args).StartWithClassicDesktopLifetime(args)

        with
        | ex ->
            printfn "[Prajna] FATAL ERROR: %s" ex.Message
            printfn "[Prajna] Stack trace: %s" ex.StackTrace
            1
