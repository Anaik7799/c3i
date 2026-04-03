namespace Cepaf.Podman.Grpc

open System
open System.Net
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Hosting
open Microsoft.AspNetCore.Server.Kestrel.Core
open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.Logging
open Cepaf.Podman.Domain
open Cepaf.Podman.Client
open Cepaf.Podman.Grpc.Services

/// Configuration for the gRPC server
module Configuration =

    /// Server configuration
    type ServerConfig = {
        /// gRPC port (default: 50051)
        GrpcPort: int
        /// Podman socket path (auto-detected if not specified)
        PodmanSocket: PodmanSocket option
        /// API version
        ApiVersion: string
        /// Request timeout
        Timeout: TimeSpan
        /// Enable reflection for grpcurl/grpcui
        EnableReflection: bool
        /// Log level
        LogLevel: LogLevel
    }

    /// Default configuration
    let defaultConfig = {
        GrpcPort = 50051
        PodmanSocket = None
        ApiVersion = "5.7.0"
        Timeout = TimeSpan.FromSeconds(30.0)
        EnableReflection = true
        LogLevel = LogLevel.Information
    }

    /// Load configuration from environment
    let loadFromEnvironment () =
        let getEnvInt name defaultValue =
            match Environment.GetEnvironmentVariable(name) with
            | null | "" -> defaultValue
            | value ->
                match Int32.TryParse(value) with
                | true, v -> v
                | false, _ -> defaultValue

        let getEnvBool name defaultValue =
            match Environment.GetEnvironmentVariable(name) with
            | null | "" -> defaultValue
            | value ->
                match Boolean.TryParse(value) with
                | true, v -> v
                | false, _ -> defaultValue

        let socketPath =
            match Environment.GetEnvironmentVariable("PODMAN_SOCKET") with
            | null | "" -> None
            | path ->
                if path.Contains("rootless") || path.Contains("/run/user/") then
                    let uid = Environment.GetEnvironmentVariable("UID") |> Option.ofObj |> Option.defaultValue "1000"
                    Some (PodmanSocket.Rootless(uid, path))
                else
                    Some (PodmanSocket.Rootful path)

        {
            GrpcPort = getEnvInt "GRPC_PORT" 50051
            PodmanSocket = socketPath
            ApiVersion = Environment.GetEnvironmentVariable("PODMAN_API_VERSION") |> Option.ofObj |> Option.defaultValue "5.7.0"
            Timeout = TimeSpan.FromSeconds(float (getEnvInt "PODMAN_TIMEOUT" 30))
            EnableReflection = getEnvBool "GRPC_ENABLE_REFLECTION" true
            LogLevel =
                match Environment.GetEnvironmentVariable("LOG_LEVEL") with
                | "Debug" -> LogLevel.Debug
                | "Warning" -> LogLevel.Warning
                | "Error" -> LogLevel.Error
                | _ -> LogLevel.Information
        }

/// Application entry point
module Program =

    /// Create Podman client from configuration
    let createPodmanClient (config: Configuration.ServerConfig) : PodmanClient =
        let clientConfig = {
            PodmanClientConfig.defaultConfig with
                Socket = config.PodmanSocket |> Option.defaultValue (PodmanSocket.detect())
                ApiVersion = config.ApiVersion
                Timeout = config.Timeout
        }
        HttpClient.createClient clientConfig

    /// Configure services
    let configureServices (config: Configuration.ServerConfig) (services: IServiceCollection) =
        // Register Podman client as singleton
        let client = createPodmanClient config
        services.AddSingleton<PodmanClient>(client) |> ignore

        // Add gRPC services
        services.AddGrpc(fun options ->
            options.EnableDetailedErrors <- config.LogLevel <= LogLevel.Debug
            options.MaxReceiveMessageSize <- 16 * 1024 * 1024  // 16 MB
            options.MaxSendMessageSize <- 16 * 1024 * 1024     // 16 MB
        ) |> ignore

        // Add gRPC reflection for tooling support
        if config.EnableReflection then
            services.AddGrpcReflection() |> ignore

        services

    /// Configure endpoints
    let configureApp (config: Configuration.ServerConfig) (app: IApplicationBuilder) =
        app.UseRouting() |> ignore

        app.UseEndpoints(fun endpoints ->
            // Map gRPC services
            endpoints.MapGrpcService<ContainerServiceImpl>() |> ignore
            endpoints.MapGrpcService<ImageServiceImpl>() |> ignore
            endpoints.MapGrpcService<HealthServiceImpl>() |> ignore

            // Map reflection service
            if config.EnableReflection then
                endpoints.MapGrpcReflectionService() |> ignore

            // Health check endpoint (HTTP for Kubernetes probes)
            endpoints.MapGet("/health", fun context ->
                task {
                    context.Response.StatusCode <- 200
                    do! context.Response.WriteAsync("OK")
                }) |> ignore

            // Ready check endpoint
            endpoints.MapGet("/ready", fun context ->
                task {
                    // Check Podman connectivity
                    let client = context.RequestServices.GetService<PodmanClient>()
                    try
                        let! result =
                            Cepaf.Podman.Api.System.ping client
                            |> Async.StartAsTask

                        match result with
                        | Ok true ->
                            context.Response.StatusCode <- 200
                            do! context.Response.WriteAsync("Ready")
                        | _ ->
                            context.Response.StatusCode <- 503
                            do! context.Response.WriteAsync("Not Ready - Podman unavailable")
                    with _ ->
                        context.Response.StatusCode <- 503
                        do! context.Response.WriteAsync("Not Ready - Connection failed")
                }) |> ignore
        ) |> ignore

        app

    /// Configure Kestrel
    let configureKestrel (config: Configuration.ServerConfig) (options: KestrelServerOptions) =
        options.Listen(IPAddress.Any, config.GrpcPort, fun listenOptions ->
            listenOptions.Protocols <- HttpProtocols.Http2
        )

    /// Build and run the host
    let buildHost (config: Configuration.ServerConfig) =
        Host.CreateDefaultBuilder()
            .ConfigureLogging(fun logging ->
                logging.SetMinimumLevel(config.LogLevel) |> ignore
                logging.AddConsole() |> ignore
            )
            .ConfigureWebHostDefaults(fun webBuilder ->
                webBuilder
                    .ConfigureKestrel(configureKestrel config)
                    .ConfigureServices(configureServices config)
                    .Configure(configureApp config)
                |> ignore
            )
            .Build()

    /// Print startup banner
    let printBanner (config: Configuration.ServerConfig) =
        printfn ""
        printfn "  ======================================"
        printfn "  Cepaf.Podman.Grpc Service v1.0.0"
        printfn "  ======================================"
        printfn ""
        printfn "  gRPC Port:      %d" config.GrpcPort
        printfn "  Podman Socket:  %s" (
            match config.PodmanSocket with
            | Some s -> PodmanSocket.getPath s
            | None -> "auto-detect"
        )
        printfn "  API Version:    %s" config.ApiVersion
        printfn "  Reflection:     %b" config.EnableReflection
        printfn "  Log Level:      %A" config.LogLevel
        printfn ""
        printfn "  Services:"
        printfn "    - ContainerService"
        printfn "    - ImageService"
        printfn "    - HealthService"
        printfn ""
        printfn "  Endpoints:"
        printfn "    - gRPC:   http://0.0.0.0:%d" config.GrpcPort
        printfn "    - Health: http://0.0.0.0:%d/health" config.GrpcPort
        printfn "    - Ready:  http://0.0.0.0:%d/ready" config.GrpcPort
        printfn ""
        printfn "  Use grpcurl to test:"
        printfn "    grpcurl -plaintext localhost:%d list" config.GrpcPort
        printfn ""

    [<EntryPoint>]
    let main args =
        try
            // Load configuration
            let config = Configuration.loadFromEnvironment()

            // Print banner
            printBanner config

            // Build and run host
            let host = buildHost config
            host.Run()

            0
        with ex ->
            eprintfn "Fatal error: %s" ex.Message
            eprintfn "%s" ex.StackTrace
            1
