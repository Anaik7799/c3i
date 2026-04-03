/// Z-KMS API Server Entry Point
///
/// Giraffe-based REST API for the Zettelkasten Knowledge Management System
///
/// STAMP Constraints:
/// - SC-KMS-001: Read-only access to holons.db
/// - SC-KMS-004: MCP endpoints for agent access
/// - SC-KMS-006: Container isolation
module Cepaf.Smriti.Api.Program

open System
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Hosting
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Logging
open Giraffe
open Cepaf.Smriti.Api.Data.KmsRepository
open Cepaf.Smriti.Api.Data.AnalyticsQuery
open Cepaf.Smriti.Api.Routes

/// Configure CORS for SPA access
let configureCors (services: IServiceCollection) =
    services.AddCors(fun options ->
        options.AddDefaultPolicy(fun builder ->
            builder
                .AllowAnyOrigin()
                .AllowAnyMethod()
                .AllowAnyHeader()
            |> ignore
        )
    ) |> ignore

/// Configure logging
let configureLogging (logging: ILoggingBuilder) =
    logging
        .AddConsole()
        .AddDebug()
        .SetMinimumLevel(LogLevel.Information)
    |> ignore

/// Configure services
let configureServices (services: IServiceCollection) =
    // Add Giraffe
    services.AddGiraffe() |> ignore

    // Add CORS
    configureCors services

    // Add repositories as singletons
    services.AddSingleton<IKmsRepository>(fun _ -> Cepaf.Smriti.Api.Data.KmsRepository.create()) |> ignore
    services.AddSingleton<IAnalyticsRepository>(fun _ -> Cepaf.Smriti.Api.Data.AnalyticsQuery.create()) |> ignore

/// Configure application
let configureApp (app: IApplicationBuilder) =
    // Get repositories from DI
    let kmsRepo = app.ApplicationServices.GetRequiredService<IKmsRepository>()
    let analyticsRepo = app.ApplicationServices.GetRequiredService<IAnalyticsRepository>()

    app
        .UseCors()
        .UseGiraffe(webApp kmsRepo analyticsRepo)

[<EntryPoint>]
let main args =
    let builder = WebApplication.CreateBuilder(args)

    // Configure services
    configureServices builder.Services
    configureLogging builder.Logging

    // Build app
    let app = builder.Build()

    // Configure middleware
    configureApp app

    // Get port from environment or default
    let port =
        Environment.GetEnvironmentVariable("PORT")
        |> Option.ofObj
        |> Option.bind (fun s -> Int32.TryParse s |> function true, n -> Some n | _ -> None)
        |> Option.defaultValue 5001

    printfn $"Z-KMS API Server starting on port {port}..."
    printfn "Endpoints:"
    printfn "  - GET  /health             - Health check"
    printfn "  - GET  /api/zettels        - List Zettels"
    printfn "  - GET  /api/graph          - Graph data"
    printfn "  - GET  /api/search?q=...   - Search"
    printfn "  - GET  /mcp/tools          - MCP tools list"
    printfn ""

    app.Urls.Add($"http://*:{port}")
    app.Run()
    0
