namespace Cepaf.Podman.Benchmarks

open System
open BenchmarkDotNet.Running
open BenchmarkDotNet.Configs
open BenchmarkDotNet.Jobs
open BenchmarkDotNet.Diagnosers
open BenchmarkDotNet.Exporters
open BenchmarkDotNet.Exporters.Json
open BenchmarkDotNet.Columns

/// Program entry point for running benchmarks
module Program =

    /// Custom benchmark configuration
    let createConfig () =
        ManualConfig
            .CreateEmpty()
            .AddExporter(JsonExporter.Full)
            .AddExporter(MarkdownExporter.GitHub)
            .AddExporter(HtmlExporter.Default)
            .AddDiagnoser(MemoryDiagnoser.Default)
            .AddColumn(StatisticColumn.AllStatistics)
            .AddColumn(RankColumn.Arabic)
            .WithOptions(ConfigOptions.DisableLogFile)

    /// Run all benchmarks
    let runAll () =
        printfn "=============================================="
        printfn "  Cepaf.Podman Benchmark Suite"
        printfn "=============================================="
        printfn ""
        printfn "Available benchmark categories:"
        printfn "  1. JSON Parsing Benchmarks"
        printfn "  2. Compose File Parsing Benchmarks"
        printfn "  3. Serialization Benchmarks"
        printfn "  4. Health Probe Benchmarks"
        printfn "  5. Run All Benchmarks"
        printfn ""

        let config = createConfig()

        BenchmarkSwitcher
            .FromAssembly(typeof<JsonParsingBenchmarks>.Assembly)
            .RunAllJoined(config)

    /// Run specific benchmark by type
    let runBenchmark<'T when 'T : not struct> () =
        let config = createConfig()
        BenchmarkRunner.Run<'T>(config)

    [<EntryPoint>]
    let main args =
        printfn ""
        printfn "  _____ ______ _____        ______   _____           _                       "
        printfn " / ____|  ____|  __ \\  /\\  |  ____| |  __ \\         | |                      "
        printfn "| |    | |__  | |__) |/  \\ | |__    | |__) |__   __| |_ __ ___   __ _ _ __  "
        printfn "| |    |  __| |  ___// /\\ \\|  __|   |  ___/ _ \\ / _` | '_ ` _ \\ / _` | '_ \\ "
        printfn "| |____| |____| |   / ____ \\ |      | |  | (_) | (_| | | | | | | (_| | | | |"
        printfn " \\_____|______|_|  /_/    \\_\\_|     |_|   \\___/ \\__,_|_| |_| |_|\\__,_|_| |_|"
        printfn ""
        printfn "  Benchmark Suite v1.0.0"
        printfn "  ====================="
        printfn ""

        match args with
        | [| "--json" |] ->
            printfn "Running JSON Parsing benchmarks..."
            runBenchmark<JsonParsingBenchmarks>() |> ignore

        | [| "--compose" |] ->
            printfn "Running Compose Parsing benchmarks..."
            runBenchmark<ComposeParseBenchmarks>() |> ignore

        | [| "--serialization" |] ->
            printfn "Running Serialization benchmarks..."
            runBenchmark<SerializationBenchmarks>() |> ignore

        | [| "--health" |] ->
            printfn "Running Health Probe benchmarks..."
            runBenchmark<HealthProbeBenchmarks>() |> ignore

        | [| "--all" |] | [| |] ->
            printfn "Running ALL benchmarks..."
            printfn "This may take several minutes."
            printfn ""
            runAll() |> ignore

        | [| "--help" |] | [| "-h" |] ->
            printfn "Usage: dotnet run [OPTIONS]"
            printfn ""
            printfn "Options:"
            printfn "  --json           Run JSON parsing benchmarks only"
            printfn "  --compose        Run Compose file parsing benchmarks only"
            printfn "  --serialization  Run serialization benchmarks only"
            printfn "  --health         Run health probe benchmarks only"
            printfn "  --all            Run all benchmarks (default)"
            printfn "  --help, -h       Show this help message"
            printfn ""
            printfn "Examples:"
            printfn "  dotnet run -c Release              # Run all benchmarks"
            printfn "  dotnet run -c Release -- --json    # Run JSON benchmarks only"
            printfn "  dotnet run -c Release -- --compose # Run Compose benchmarks only"
            printfn ""
            printfn "Note: Benchmarks should be run in Release configuration for accurate results."

        | _ ->
            printfn "Unknown option. Use --help for usage information."

        0
