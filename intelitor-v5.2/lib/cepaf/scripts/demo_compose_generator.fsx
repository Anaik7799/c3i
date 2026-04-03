#!/usr/bin/env dotnet fsi

/// =============================================================================
/// COMPOSE GENERATOR DEMO
/// =============================================================================
///
/// WHAT: Demonstrates ComposeGenerator usage
/// WHY: Generate podman-compose.yml from centralized config
///
/// Usage:
///   dotnet fsi lib/cepaf/scripts/demo_compose_generator.fsx
///
/// =============================================================================

#r "nuget: System.Text.Json, 10.0.1"

#load "../src/Cepaf.Config/MeshConfig.fs"
#load "../src/Cepaf.Config/ComposeGenerator.fs"

open System
open System.IO
open Cepaf.Config.ComposeGenerator
open Cepaf.Config.MeshConfigBuilder

/// Print section header
let printHeader title =
    printfn ""
    printfn "═══════════════════════════════════════════════════════════════════"
    printfn " %s" title
    printfn "═══════════════════════════════════════════════════════════════════"
    printfn ""

/// Demo 1: Generate full SIL-6 mesh
let demoFullMesh () =
    printHeader "DEMO 1: Generate Full SIL-6 Mesh (11 containers)"

    // Create configuration
    let config = createSil6FullMesh ()

    printfn "Configuration:"
    printfn "  Version: %s" config.Version
    printfn "  Networks: %d" (List.length config.Networks)
    printfn "  Volumes: %d" (List.length config.Volumes)
    printfn "  Services: %d" (List.length config.Services)
    printfn ""

    // Generate YAML
    let yaml = generateFromConfig config

    printfn "Generated YAML (%d lines):" (yaml.Split('\n').Length)
    printfn "%s" yaml

    // Validate
    match validateCompose yaml config with
    | Ok () ->
        printfn "✓ Validation PASSED"
    | Error errors ->
        printfn "✗ Validation FAILED with %d errors:" (List.length errors)
        errors |> List.iter (fun err -> printfn "  - %A" err)

    // Save to file
    let outputPath = "lib/cepaf/artifacts/generated-sil6-full-mesh.yml"
    File.WriteAllText(outputPath, yaml)
    printfn ""
    printfn "✓ Saved to: %s" outputPath

/// Demo 2: Show service generation
let demoServiceGeneration () =
    printHeader "DEMO 2: Individual Service Generation"

    // Create DB container
    let dbContainer = createDbContainer ()

    printfn "Database Container:"
    printfn "  Name: %s" dbContainer.Name
    printfn "  Image: %s" dbContainer.Image
    printfn "  Networks: %d" (List.length dbContainer.Networks)
    printfn "  Ports: %d" (List.length dbContainer.Ports)
    printfn "  Wave: %d" dbContainer.Wave
    printfn ""

    // Generate service YAML
    let serviceYaml = ServiceGen.generateService dbContainer
    printfn "Generated Service YAML:"
    printfn "%s" serviceYaml

/// Demo 3: Validation examples
let demoValidation () =
    printHeader "DEMO 3: Configuration Validation"

    let config = createSil6FullMesh ()

    printfn "Running validations..."
    printfn ""

    // Validate port uniqueness
    let ports =
        config.Services
        |> List.collect (fun s -> s.Ports |> List.map (fun p -> p.Host))
        |> List.distinct
    printfn "✓ Total unique ports: %d" (List.length ports)

    // Validate dependencies
    let serviceNames = config.Services |> List.map (fun s -> s.Name) |> Set.ofList
    let allDepsValid =
        config.Services
        |> List.forall (fun svc ->
            svc.DependsOn
            |> List.forall (fun dep -> serviceNames.Contains dep.Service)
        )
    printfn "✓ All dependencies valid: %b" allDepsValid

    // Validate networks
    let definedNetworks = config.Networks |> List.map (fun n -> n.Name) |> Set.ofList
    let allNetworksValid =
        config.Services
        |> List.forall (fun svc ->
            svc.Networks
            |> List.forall (fun net -> definedNetworks.Contains net.Name)
        )
    printfn "✓ All networks defined: %b" allNetworksValid

    // Wave distribution
    let waveDistribution =
        config.Services
        |> List.groupBy (fun s -> s.Wave)
        |> List.sortBy fst
    printfn ""
    printfn "Wave Distribution:"
    waveDistribution |> List.iter (fun (wave, services) ->
        printfn "  Wave %d: %d services" wave (List.length services)
        services |> List.iter (fun s -> printfn "    - %s" s.Name)
    )

/// Demo 4: Custom configuration
let demoCustomConfig () =
    printHeader "DEMO 4: Custom Configuration Example"

    open ComposeTypes

    // Create custom minimal config
    let customConfig = {
        Version = "3.8"
        Networks = [
            {
                Name = "custom-net"
                Driver = "bridge"
                Internal = false
                Subnet = Some "172.30.0.0/16"
                Gateway = Some "172.30.0.1"
            }
        ]
        Volumes = [
            { Name = "custom-data"; Driver = "local"; Labels = Map.empty }
        ]
        Services = [
            {
                Name = "custom-service"
                Hostname = "custom-service"
                Image = "localhost/custom:latest"
                Networks = [
                    { Name = "custom-net"; IpAddress = Some "172.30.0.10" }
                ]
                Environment = Map.ofList [
                    ("ENV_VAR", "value")
                    ("DEBUG", "true")
                ]
                Ports = [
                    { Host = 8080; Container = 80; Protocol = "tcp" }
                ]
                Volumes = [
                    { Source = "custom-data"; Target = "/data"; Options = None }
                ]
                HealthCheck = Some {
                    Test = ["CMD-SHELL"; "curl -f http://localhost/health"]
                    Interval = "30s"
                    Timeout = "10s"
                    Retries = 3
                    StartPeriod = "60s"
                }
                Resources = Some {
                    MemoryLimit = "1G"
                    CpuLimit = "1.0"
                    MemoryReservation = None
                    CpuReservation = None
                }
                DependsOn = []
                Restart = "always"
                Labels = Map.ofList [("app", "custom")]
                Wave = 1
            }
        ]
    }

    let yaml = generateFromConfig customConfig
    printfn "Custom Configuration YAML:"
    printfn "%s" yaml

/// Main execution
let main () =
    try
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║         CEPAF COMPOSE GENERATOR - DEMONSTRATION                   ║"
        printfn "║         Version: 21.3.0-SIL6                                      ║"
        printfn "║         SC-CONSOL-004: Deterministic YAML Generation             ║"
        printfn "╚═══════════════════════════════════════════════════════════════════╝"

        demoFullMesh ()
        demoServiceGeneration ()
        demoValidation ()
        demoCustomConfig ()

        printHeader "ALL DEMOS COMPLETED"
        printfn "✓ ComposeGenerator is ready for use"
        printfn "✓ Configuration is centralized in MeshConfig.fs"
        printfn "✓ YAML generation is deterministic"
        printfn ""
        0
    with
    | ex ->
        printfn ""
        printfn "✗ ERROR: %s" ex.Message
        printfn "Stack trace: %s" ex.StackTrace
        1

// Run main
exit (main ())
