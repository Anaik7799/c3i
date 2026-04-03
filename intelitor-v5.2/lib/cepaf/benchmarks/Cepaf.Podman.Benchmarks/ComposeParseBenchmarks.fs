namespace Cepaf.Podman.Benchmarks

open System
open BenchmarkDotNet.Attributes
open BenchmarkDotNet.Diagnosers
open BenchmarkDotNet.Jobs
open Cepaf.Podman.Compose

/// Benchmarks for Compose file YAML parsing
[<MemoryDiagnoser>]
[<SimpleJob(RuntimeMoniker.Net90)>]
[<RPlotExporter>]
type ComposeParseBenchmarks() =

    // ========================================================================
    // Test Data
    // ========================================================================

    let mutable simpleComposeYaml: string = ""
    let mutable complexComposeYaml5: string = ""
    let mutable complexComposeYaml10: string = ""
    let mutable complexComposeYaml20: string = ""

    [<GlobalSetup>]
    member _.Setup() =
        simpleComposeYaml <- TestData.generateSimpleComposeYaml()
        complexComposeYaml5 <- TestData.generateComplexComposeYaml 5
        complexComposeYaml10 <- TestData.generateComplexComposeYaml 10
        complexComposeYaml20 <- TestData.generateComplexComposeYaml 20

    // ========================================================================
    // Compose Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse simple compose (2 services)")>]
    member _.ParseSimpleCompose() =
        Parser.parse simpleComposeYaml

    [<Benchmark(Description = "Parse complex compose (5 services)")>]
    member _.ParseComplexCompose_5() =
        Parser.parse complexComposeYaml5

    [<Benchmark(Description = "Parse complex compose (10 services)", Baseline = true)>]
    member _.ParseComplexCompose_10() =
        Parser.parse complexComposeYaml10

    [<Benchmark(Description = "Parse complex compose (20 services)")>]
    member _.ParseComplexCompose_20() =
        Parser.parse complexComposeYaml20

    // ========================================================================
    // Duration Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse duration string (30s)")>]
    member _.ParseDuration_Seconds() =
        Parser.parseDuration "30s"

    [<Benchmark(Description = "Parse duration string (5m)")>]
    member _.ParseDuration_Minutes() =
        Parser.parseDuration "5m"

    [<Benchmark(Description = "Parse duration string (2h)")>]
    member _.ParseDuration_Hours() =
        Parser.parseDuration "2h"

    [<Benchmark(Description = "Parse duration string (500ms)")>]
    member _.ParseDuration_Milliseconds() =
        Parser.parseDuration "500ms"

    // ========================================================================
    // Memory Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse memory string (512M)")>]
    member _.ParseMemory_Megabytes() =
        Parser.parseMemory "512M"

    [<Benchmark(Description = "Parse memory string (2G)")>]
    member _.ParseMemory_Gigabytes() =
        Parser.parseMemory "2G"

    [<Benchmark(Description = "Parse memory string (1024KB)")>]
    member _.ParseMemory_Kilobytes() =
        Parser.parseMemory "1024K"

    // ========================================================================
    // Port String Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse port string (8080:80)")>]
    member _.ParsePort_Simple() =
        Parser.parsePort "8080:80"

    [<Benchmark(Description = "Parse port string (8080:80/tcp)")>]
    member _.ParsePort_WithProtocol() =
        Parser.parsePort "8080:80/tcp"

    [<Benchmark(Description = "Parse port string (8080:80/udp)")>]
    member _.ParsePort_UDP() =
        Parser.parsePort "8080:80/udp"

    // ========================================================================
    // Volume String Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse volume string (./data:/app/data)")>]
    member _.ParseVolume_Bind() =
        Parser.parseVolume "./data:/app/data"

    [<Benchmark(Description = "Parse volume string (data_vol:/app/data)")>]
    member _.ParseVolume_Named() =
        Parser.parseVolume "data_vol:/app/data"

    [<Benchmark(Description = "Parse volume string (./data:/app/data:ro)")>]
    member _.ParseVolume_ReadOnly() =
        Parser.parseVolume "./data:/app/data:ro"

    // ========================================================================
    // Deployment Order Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Get deployment order (5 services)")>]
    member this.GetDeploymentOrder_5() =
        match Parser.parse complexComposeYaml5 with
        | Ok compose -> Parser.getDeploymentOrder compose
        | Error _ -> []

    [<Benchmark(Description = "Get deployment order (10 services)")>]
    member this.GetDeploymentOrder_10() =
        match Parser.parse complexComposeYaml10 with
        | Ok compose -> Parser.getDeploymentOrder compose
        | Error _ -> []

    [<Benchmark(Description = "Get deployment order (20 services)")>]
    member this.GetDeploymentOrder_20() =
        match Parser.parse complexComposeYaml20 with
        | Ok compose -> Parser.getDeploymentOrder compose
        | Error _ -> []
