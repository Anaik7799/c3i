namespace Cepaf.Podman.Benchmarks

open System
open BenchmarkDotNet.Attributes
open BenchmarkDotNet.Diagnosers
open BenchmarkDotNet.Jobs
open Cepaf.Podman.Domain
open Cepaf.Podman.Health

/// Benchmarks for health probe operations
/// Note: These benchmarks test the in-memory logic, not actual container health checks
[<MemoryDiagnoser>]
[<SimpleJob(RuntimeMoniker.Net90)>]
[<RPlotExporter>]
type HealthProbeBenchmarks() =

    // ========================================================================
    // Test Data
    // ========================================================================

    let mutable probeResults: Probes.ProbeResult list = []
    let mutable healthyResults: Probes.ProbeResult list = []
    let mutable mixedResults: Probes.ProbeResult list = []

    [<GlobalSetup>]
    member _.Setup() =
        // Generate test probe results
        probeResults <-
            [ for i in 0 .. 99 ->
                {
                    ContainerId = sprintf "container_%d" i
                    ContainerName = sprintf "container_name_%d" i
                    Status =
                        match i % 5 with
                        | 0 -> HealthStatus.Healthy
                        | 1 -> HealthStatus.Starting
                        | 2 -> HealthStatus.Unhealthy (i % 3)
                        | 3 -> HealthStatus.NoHealthcheck
                        | _ -> HealthStatus.Unknown "custom"
                    Message = if i % 3 = 0 then Some "Health check passed" else None
                    Timestamp = DateTimeOffset.UtcNow
                    Duration = TimeSpan.FromMilliseconds(float (50 + i * 2))
                }
            ]

        healthyResults <-
            [ for i in 0 .. 49 ->
                {
                    ContainerId = sprintf "healthy_%d" i
                    ContainerName = sprintf "healthy_name_%d" i
                    Status = HealthStatus.Healthy
                    Message = None
                    Timestamp = DateTimeOffset.UtcNow
                    Duration = TimeSpan.FromMilliseconds(float (30 + i))
                }
            ]

        mixedResults <-
            [ for i in 0 .. 49 ->
                {
                    ContainerId = sprintf "mixed_%d" i
                    ContainerName = sprintf "mixed_name_%d" i
                    Status = if i % 2 = 0 then HealthStatus.Healthy else HealthStatus.Unhealthy 1
                    Message = if i % 2 = 1 then Some "Health check failed" else None
                    Timestamp = DateTimeOffset.UtcNow
                    Duration = TimeSpan.FromMilliseconds(float (40 + i * 2))
                }
            ]

    // ========================================================================
    // Probe Config Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Create default probe config")>]
    member _.CreateDefaultProbeConfig() =
        Probes.ProbeConfig.defaults

    [<Benchmark(Description = "Configure probe with options")>]
    member _.ConfigureProbeWithOptions() =
        Probes.ProbeConfig.defaults
        |> Probes.ProbeConfig.withInterval (TimeSpan.FromSeconds(15.0))
        |> Probes.ProbeConfig.withTimeout (TimeSpan.FromSeconds(10.0))
        |> Probes.ProbeConfig.withRetries 5
        |> Probes.ProbeConfig.withStartPeriod (TimeSpan.FromSeconds(30.0))

    // ========================================================================
    // Health Status Classification Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Filter healthy results from 100 items")>]
    member _.FilterHealthyFrom100() =
        probeResults
        |> List.filter (fun p -> p.Status = HealthStatus.Healthy)
        |> List.length

    [<Benchmark(Description = "Filter unhealthy results from 100 items", Baseline = true)>]
    member _.FilterUnhealthyFrom100() =
        probeResults
        |> List.filter (fun p ->
            match p.Status with
            | HealthStatus.Unhealthy _ -> true
            | _ -> false)
        |> List.length

    [<Benchmark(Description = "Classify all 100 results by status")>]
    member _.ClassifyAllResultsByStatus() =
        let healthy = probeResults |> List.filter (fun p -> p.Status = HealthStatus.Healthy) |> List.length
        let unhealthy = probeResults |> List.filter (fun p -> match p.Status with HealthStatus.Unhealthy _ -> true | _ -> false) |> List.length
        let starting = probeResults |> List.filter (fun p -> p.Status = HealthStatus.Starting) |> List.length
        let none = probeResults |> List.filter (fun p -> p.Status = HealthStatus.NoHealthcheck) |> List.length
        (healthy, unhealthy, starting, none)

    // ========================================================================
    // Result Aggregation Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Calculate average duration from 100 results")>]
    member _.CalculateAverageDuration() =
        probeResults
        |> List.averageBy (fun p -> p.Duration.TotalMilliseconds)

    [<Benchmark(Description = "Find max duration from 100 results")>]
    member _.FindMaxDuration() =
        probeResults
        |> List.maxBy (fun p -> p.Duration)

    [<Benchmark(Description = "Group results by status")>]
    member _.GroupResultsByStatus() =
        probeResults
        |> List.groupBy (fun p -> p.Status)
        |> List.map (fun (status, results) -> (status, results.Length))

    // ========================================================================
    // Map Operations (Simulating Monitor State Updates)
    // ========================================================================

    [<Benchmark(Description = "Build result map from 50 results")>]
    member _.BuildResultMapFrom50() =
        healthyResults
        |> List.map (fun r -> (r.ContainerId, r))
        |> Map.ofList

    [<Benchmark(Description = "Build result map from 100 results")>]
    member _.BuildResultMapFrom100() =
        probeResults
        |> List.map (fun r -> (r.ContainerId, r))
        |> Map.ofList

    [<Benchmark(Description = "Update single entry in 100-entry map")>]
    member _.UpdateSingleMapEntry() =
        let initialMap =
            probeResults
            |> List.map (fun r -> (r.ContainerId, r))
            |> Map.ofList

        let newResult = { probeResults.[50] with Status = HealthStatus.Unhealthy 1 }
        initialMap |> Map.add newResult.ContainerId newResult

    // ========================================================================
    // Status Comparison Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Detect status changes in 50 pairs")>]
    member _.DetectStatusChanges() =
        List.zip healthyResults mixedResults
        |> List.filter (fun (prev, curr) -> prev.Status <> curr.Status)
        |> List.length

    [<Benchmark(Description = "Count consecutive failures")>]
    member _.CountConsecutiveFailures() =
        let mutable failures = Map.empty<string, int>
        for result in mixedResults do
            match result.Status with
            | HealthStatus.Unhealthy _ ->
                let count = failures |> Map.tryFind result.ContainerId |> Option.defaultValue 0
                failures <- failures |> Map.add result.ContainerId (count + 1)
            | HealthStatus.Healthy ->
                failures <- failures |> Map.remove result.ContainerId
            | _ -> ()
        failures

    // ========================================================================
    // Health Status Parsing Benchmarks
    // ========================================================================

    [<Benchmark(Description = "Parse 'healthy' status")>]
    member _.ParseHealthyStatus() =
        HealthStatus.parse "healthy"

    [<Benchmark(Description = "Parse 'unhealthy' status")>]
    member _.ParseUnhealthyStatus() =
        HealthStatus.parse "unhealthy"

    [<Benchmark(Description = "Parse 'starting' status")>]
    member _.ParseStartingStatus() =
        HealthStatus.parse "starting"

    [<Benchmark(Description = "Parse 'none' status")>]
    member _.ParseNoneStatus() =
        HealthStatus.parse "none"

    [<Benchmark(Description = "Parse unknown status")>]
    member _.ParseUnknownStatus() =
        HealthStatus.parse "custom-status"
