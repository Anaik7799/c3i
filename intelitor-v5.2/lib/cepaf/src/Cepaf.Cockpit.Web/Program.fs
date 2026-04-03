namespace Cepaf.Cockpit.Web

open System
open System.IO
open System.Reflection
open Microsoft.AspNetCore.Builder
open Microsoft.Extensions.Hosting
open Serilog

/// =============================================================================
/// PRAJNA C3I WebUI - Application Entry Point
/// =============================================================================
/// ASP.NET Core + Bolero (F# Blazor) application entry point.
/// STAMP: SC-COCKPIT-002 (WebUI MUST be F#), SC-CNT-009 (Container)
/// =============================================================================

module Program =

    [<EntryPoint>]
    let main args =
        // Configure Serilog
        Log.Logger <-
            LoggerConfiguration()
                .MinimumLevel.Information()
                .WriteTo.Console()
                .CreateLogger()

        try
            try
                Log.Information("Starting Prajna C3I WebUI (F# Bolero)")

                // Set content root to project directory (where wwwroot lives)
                let projectDir =
                    Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)
                    |> fun binDir ->
                        // Walk up from bin/Debug/net10.0 to project root
                        let projectRoot = Path.Combine(binDir, "..", "..", "..")
                        Path.GetFullPath(projectRoot)

                let options = WebApplicationOptions(Args = args, ContentRootPath = projectDir)
                let builder = WebApplication.CreateBuilder(options)

                // Configure services
                Startup.configureServices builder.Services

                let app = builder.Build()

                // Configure middleware (.NET 10 WebApplication pattern)
                Startup.configure app

                Log.Information("Prajna WebUI running on http://localhost:5000")
                app.Run()

                0  // Exit code

            with ex ->
                Log.Fatal(ex, "Application terminated unexpectedly")
                1
        finally
            Log.CloseAndFlush()
