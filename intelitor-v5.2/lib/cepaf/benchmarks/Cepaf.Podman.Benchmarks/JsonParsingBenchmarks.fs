namespace Cepaf.Podman.Benchmarks

open System
open BenchmarkDotNet.Attributes
open BenchmarkDotNet.Diagnosers
open BenchmarkDotNet.Jobs
open Cepaf.Podman.Client
open Cepaf.Podman.Domain

/// Benchmarks for JSON parsing operations
[<MemoryDiagnoser>]
[<SimpleJob(RuntimeMoniker.Net90)>]
[<RPlotExporter>]
type JsonParsingBenchmarks() =

    // ========================================================================
    // Test Data (generated once per benchmark run)
    // ========================================================================

    let mutable containerJson1: string = ""
    let mutable containerJson10: string = ""
    let mutable containerJson50: string = ""
    let mutable containerJson100: string = ""

    let mutable imageJson1: string = ""
    let mutable imageJson10: string = ""
    let mutable imageJson50: string = ""
    let mutable imageJson100: string = ""

    let mutable volumeJson10: string = ""
    let mutable volumeJson50: string = ""

    let mutable networkJson10: string = ""
    let mutable networkJson50: string = ""

    [<GlobalSetup>]
    member _.Setup() =
        // Pre-generate all test JSON data
        containerJson1 <- TestData.generateContainerListJson 1
        containerJson10 <- TestData.generateContainerListJson 10
        containerJson50 <- TestData.generateContainerListJson 50
        containerJson100 <- TestData.generateContainerListJson 100

        imageJson1 <- TestData.generateImageListJson 1
        imageJson10 <- TestData.generateImageListJson 10
        imageJson50 <- TestData.generateImageListJson 50
        imageJson100 <- TestData.generateImageListJson 100

        volumeJson10 <- TestData.generateVolumeListJson 10
        volumeJson50 <- TestData.generateVolumeListJson 50

        networkJson10 <- TestData.generateNetworkListJson 10
        networkJson50 <- TestData.generateNetworkListJson 50

    // ========================================================================
    // Container List Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse 1 container JSON")>]
    member _.ParseContainerList_1() =
        Serialization.parseContainerList containerJson1

    [<Benchmark(Description = "Parse 10 containers JSON")>]
    member _.ParseContainerList_10() =
        Serialization.parseContainerList containerJson10

    [<Benchmark(Description = "Parse 50 containers JSON")>]
    member _.ParseContainerList_50() =
        Serialization.parseContainerList containerJson50

    [<Benchmark(Description = "Parse 100 containers JSON", Baseline = true)>]
    member _.ParseContainerList_100() =
        Serialization.parseContainerList containerJson100

    // ========================================================================
    // Image List Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse 1 image JSON")>]
    member _.ParseImageList_1() =
        Serialization.parseImageList imageJson1

    [<Benchmark(Description = "Parse 10 images JSON")>]
    member _.ParseImageList_10() =
        Serialization.parseImageList imageJson10

    [<Benchmark(Description = "Parse 50 images JSON")>]
    member _.ParseImageList_50() =
        Serialization.parseImageList imageJson50

    [<Benchmark(Description = "Parse 100 images JSON")>]
    member _.ParseImageList_100() =
        Serialization.parseImageList imageJson100

    // ========================================================================
    // Volume List Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse 10 volumes JSON")>]
    member _.ParseVolumeList_10() =
        Serialization.parseVolumeList volumeJson10

    [<Benchmark(Description = "Parse 50 volumes JSON")>]
    member _.ParseVolumeList_50() =
        Serialization.parseVolumeList volumeJson50

    // ========================================================================
    // Network List Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse 10 networks JSON")>]
    member _.ParseNetworkList_10() =
        Serialization.parseNetworkList networkJson10

    [<Benchmark(Description = "Parse 50 networks JSON")>]
    member _.ParseNetworkList_50() =
        Serialization.parseNetworkList networkJson50
