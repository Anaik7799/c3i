namespace Cepaf.Cockpit.Web

open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Hosting
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Bolero.Server
open Cepaf.Cockpit.Web.Hubs

/// =============================================================================
/// PRAJNA C3I WebUI - ASP.NET Core Startup
/// =============================================================================
/// Configures services and middleware for Bolero + SignalR hosting.
/// STAMP: SC-COCKPIT-002 (F# WebUI), SC-CNT-009 (Container deployment)
/// =============================================================================

module Startup =

    /// Configure services
    let configureServices (services: IServiceCollection) =
        // AddServerSideBlazor registers CircuitRegistry and other Blazor Server services
        // Required for MapBlazorHub() in .NET 10 — AddBoleroHost alone is insufficient
        services.AddServerSideBlazor() |> ignore

        services
            .AddBoleroHost()
            |> ignore

        services
            .AddSignalR()
            |> ignore

        // Add HTTP client for Elixir backend
        services.AddHttpClient() |> ignore

        // Add logging
        services.AddLogging() |> ignore

    /// Configure middleware pipeline (.NET 10 WebApplication pattern)
    let configure (app: WebApplication) =
        if app.Environment.IsDevelopment() then
            app.UseDeveloperExceptionPage() |> ignore

        app.UseStaticFiles() |> ignore
        app.UseRouting() |> ignore

        // SignalR hub for Zenoh bridge
        app.MapHub<ZenohHub>("/zenoh-hub") |> ignore
        // Bolero/Blazor — MapBlazorHub on WebApplication registers _framework/blazor.server.js
        app.MapBlazorHub() |> ignore
        app.MapFallbackToFile("index.html") |> ignore
