namespace Cepaf.Podman.Benchmarks

open System
open BenchmarkDotNet.Attributes
open BenchmarkDotNet.Diagnosers
open BenchmarkDotNet.Jobs
open Cepaf.Podman.Client
open Cepaf.Podman.Domain

/// Benchmarks for spec serialization to JSON
[<MemoryDiagnoser>]
[<SimpleJob(RuntimeMoniker.Net90)>]
[<RPlotExporter>]
type SerializationBenchmarks() =

    // ========================================================================
    // Test Data
    // ========================================================================

    let mutable simpleContainerSpec: ContainerSpec = Unchecked.defaultof<_>
    let mutable complexContainerSpec: ContainerSpec = Unchecked.defaultof<_>
    let mutable simplePodSpec: PodSpec = Unchecked.defaultof<_>
    let mutable complexPodSpec: PodSpec = Unchecked.defaultof<_>
    let mutable networkSpec: NetworkSpec = Unchecked.defaultof<_>
    let mutable volumeSpec: VolumeSpec = Unchecked.defaultof<_>

    [<GlobalSetup>]
    member _.Setup() =
        simpleContainerSpec <- TestData.createSimpleContainerSpec()
        complexContainerSpec <- TestData.createComplexContainerSpec()
        simplePodSpec <- TestData.createSimplePodSpec()
        complexPodSpec <- TestData.createComplexPodSpec()
        networkSpec <- TestData.createNetworkSpec()
        volumeSpec <- TestData.createVolumeSpec()

    // ========================================================================
    // Container Spec Serialization Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Serialize simple container spec")>]
    member _.SerializeSimpleContainerSpec() =
        Serialization.serializeContainerSpec simpleContainerSpec

    [<Benchmark(Description = "Serialize complex container spec", Baseline = true)>]
    member _.SerializeComplexContainerSpec() =
        Serialization.serializeContainerSpec complexContainerSpec

    // ========================================================================
    // Pod Spec Serialization Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Serialize simple pod spec")>]
    member _.SerializeSimplePodSpec() =
        Serialization.serializePodSpec simplePodSpec

    [<Benchmark(Description = "Serialize complex pod spec")>]
    member _.SerializeComplexPodSpec() =
        Serialization.serializePodSpec complexPodSpec

    // ========================================================================
    // Network Spec Serialization Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Serialize network spec")>]
    member _.SerializeNetworkSpec() =
        Serialization.serializeNetworkSpec networkSpec

    // ========================================================================
    // Volume Spec Serialization Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Serialize volume spec")>]
    member _.SerializeVolumeSpec() =
        Serialization.serializeVolumeSpec volumeSpec

    // ========================================================================
    // Roundtrip Benchmarks (Serialize then Parse)
    // ========================================================================

    [<Benchmark(Description = "Container spec roundtrip (serialize + parse)")>]
    member this.ContainerSpecRoundtrip() =
        let json = Serialization.serializeContainerSpec complexContainerSpec
        // Note: We don't have a direct ContainerSpec parser since specs are sent to the API
        // This benchmark measures the serialization output size/complexity
        json.Length

    // ========================================================================
    // Type Conversion Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Port protocol to string")>]
    member _.PortProtocolToString() =
        PortProtocol.toString PortProtocol.TCP

    [<Benchmark(Description = "Mount type to string")>]
    member _.MountTypeToString() =
        MountType.toString MountType.Bind

    [<Benchmark(Description = "Network driver to string")>]
    member _.NetworkDriverToString() =
        NetworkDriver.toString NetworkDriver.Bridge

    [<Benchmark(Description = "Volume driver to string")>]
    member _.VolumeDriverToString() =
        VolumeDriver.toString VolumeDriver.Local

    [<Benchmark(Description = "Container status parse")>]
    member _.ContainerStatusParse() =
        ContainerStatus.parse "running"

    [<Benchmark(Description = "Health status parse")>]
    member _.HealthStatusParse() =
        HealthStatus.parse "healthy"

    [<Benchmark(Description = "Pod status parse")>]
    member _.PodStatusParse() =
        PodStatus.parse "running"

    // ========================================================================
    // JSON Options Access Benchmark
    // ========================================================================

    [<Benchmark(Description = "Access JSON options (cached)")>]
    member _.AccessJsonOptions() =
        Serialization.jsonOptions.PropertyNamingPolicy
