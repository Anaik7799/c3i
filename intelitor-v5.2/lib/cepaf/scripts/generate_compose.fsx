#!/usr/bin/env dotnet fsi

/// =============================================================================
/// COMPOSE GENERATOR CLI
/// =============================================================================
///
/// WHAT: Command-line tool to generate podman-compose.yml files
/// WHY: Single source of truth for container orchestration
///
/// Usage:
///   # Generate SIL-6 full mesh
///   dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6
///
///   # Generate with validation
///   dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6 --validate
///
///   # Generate to custom output
///   dotnet fsi lib/cepaf/scripts/generate_compose.fsx --mesh sil6 --output custom.yml
///
/// STAMP: SC-CONSOL-004, SC-CONFIG-001, SC-CONFIG-002
/// =============================================================================

#r "nuget: System.Text.Json, 10.0.1"

#load "../src/Cepaf.Config/MeshConfig.fs"
#load "../src/Cepaf.Config/ComposeGenerator.fs"

open System
open System.IO
open Cepaf.Config.ComposeGenerator
open Cepaf.Config.MeshConfigBuilder
open Cepaf.Config.ComposeTypes

/// Command-line options
type Options = {
    MeshType: string
    OutputPath: string option
    Validate: bool
    Verbose: bool
}

/// Default options
let defaultOptions = {
    MeshType = "sil6"
    OutputPath = None
    Validate = false
    Verbose = false
}

/// Parse command-line arguments
let rec parseArgs args options =
    match args with
    | [] -> options
    | "--mesh" :: meshType :: rest ->
        parseArgs rest { options with MeshType = meshType }
    | "--output" :: path :: rest ->
        parseArgs rest { options with OutputPath = Some path }
    | "--validate" :: rest ->
        parseArgs rest { options with Validate = true }
    | "--verbose" :: rest ->
        parseArgs rest { options with Verbose = true }
    | "--help" :: _ ->
        printfn "Usage: generate_compose.fsx [OPTIONS]"
        printfn ""
        printfn "Options:"
        printfn "  --mesh TYPE        Mesh type (sil6, fractal, standalone) [default: sil6]"
        printfn "  --output PATH      Output file path [default: auto]"
        printfn "  --validate         Validate generated YAML"
        printfn "  --verbose          Verbose output"
        printfn "  --help             Show this help"
        printfn ""
        exit 0
    | unknown :: _ ->
        printfn "ERROR: Unknown option: %s" unknown
        printfn "Use --help for usage information"
        exit 1

/// Get default output path for mesh type
let getDefaultOutputPath meshType =
    match meshType with
    | "sil6" -> "lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml"
    | "fractal" -> "lib/cepaf/artifacts/podman-compose-fractal-cluster.yml"
    | "standalone" -> "lib/cepaf/artifacts/podman-compose-standalone-full.yml"
    | _ -> $"lib/cepaf/artifacts/podman-compose-{meshType}.yml"

/// Create configuration for mesh type
let createConfigForMesh meshType =
    match meshType with
    | "sil6" -> createSil6FullMesh ()
    | _ ->
        printfn "ERROR: Unknown mesh type: %s" meshType
        printfn "Supported types: sil6, fractal, standalone"
        exit 1

/// Print configuration summary
let printConfigSummary (config: MeshConfig) verbose =
    printfn ""
    printfn "Configuration Summary:"
    printfn "  Version: %s" config.Version
    printfn "  Networks: %d" (List.length config.Networks)
    printfn "  Volumes: %d" (List.length config.Volumes)
    printfn "  Services: %d" (List.length config.Services)

    if verbose then
        printfn ""
        printfn "Networks:"
        config.Networks |> List.iter (fun net ->
            printfn "  - %s (%s)" net.Name net.Driver
            match net.Subnet with
            | Some subnet -> printfn "    Subnet: %s" subnet
            | None -> ()
        )

        printfn ""
        printfn "Services by Wave:"
        config.Services
        |> List.groupBy (fun s -> s.Wave)
        |> List.sortBy fst
        |> List.iter (fun (wave, services) ->
            printfn "  Wave %d:" wave
            services
            |> List.sortBy (fun s -> s.Name)
            |> List.iter (fun s ->
                printfn "    - %s" s.Name
                if verbose then
                    printfn "      Image: %s" s.Image
                    printfn "      Ports: %d" (List.length s.Ports)
                    printfn "      Depends: %d" (List.length s.DependsOn)
            )
        )

/// Validate configuration
let validateConfig config verbose =
    if verbose then
        printfn ""
        printfn "Running validation..."

    // Check port uniqueness
    let ports =
        config.Services
        |> List.collect (fun s -> s.Ports |> List.map (fun p -> p.Host))
    let uniquePorts = ports |> List.distinct
    let portConflicts = ports.Length <> uniquePorts.Length

    if portConflicts then
        printfn "  ✗ Port conflicts detected"
        ports
        |> List.groupBy id
        |> List.filter (fun (_, group) -> List.length group > 1)
        |> List.iter (fun (port, _) -> printfn "    Duplicate port: %d" port)
        false
    else
        if verbose then printfn "  ✓ All ports unique"
        true

    // Check dependencies
    && (
        let serviceNames = config.Services |> List.map (fun s -> s.Name) |> Set.ofList
        let invalidDeps = ResizeArray<string * string>()

        config.Services |> List.iter (fun svc ->
            svc.DependsOn |> List.iter (fun dep ->
                if not (serviceNames.Contains dep.Service) then
                    invalidDeps.Add(svc.Name, dep.Service)
            )
        )

        if invalidDeps.Count > 0 then
            printfn "  ✗ Invalid dependencies detected"
            invalidDeps |> Seq.iter (fun (svc, dep) ->
                printfn "    %s depends on undefined service: %s" svc dep
            )
            false
        else
            if verbose then printfn "  ✓ All dependencies valid"
            true
    )

    // Check networks
    && (
        let definedNetworks = config.Networks |> List.map (fun n -> n.Name) |> Set.ofList
        let undefinedNets = ResizeArray<string>()

        config.Services |> List.iter (fun svc ->
            svc.Networks |> List.iter (fun net ->
                if not (definedNetworks.Contains net.Name) then
                    undefinedNets.Add(net.Name)
            )
        )

        if undefinedNets.Count > 0 then
            printfn "  ✗ Undefined networks detected"
            undefinedNets |> Seq.distinct |> Seq.iter (fun net ->
                printfn "    Undefined network: %s" net
            )
            false
        else
            if verbose then printfn "  ✓ All networks defined"
            true
    )

/// Main execution
let main args =
    try
        // Parse arguments
        let options = parseArgs (Array.toList args) defaultOptions

        // Header
        printfn ""
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║         CEPAF COMPOSE GENERATOR                                   ║"
        printfn "║         Version: 21.3.0-SIL6                                      ║"
        printfn "║         SC-CONSOL-004: Deterministic YAML Generation             ║"
        printfn "╚═══════════════════════════════════════════════════════════════════╝"

        // Create configuration
        if options.Verbose then
            printfn ""
            printfn "Creating configuration for mesh: %s" options.MeshType

        let config = createConfigForMesh options.MeshType

        // Print summary
        printConfigSummary config options.Verbose

        // Validate if requested
        if options.Validate then
            printfn ""
            printfn "Validating configuration..."
            if validateConfig config options.Verbose then
                printfn "✓ Validation PASSED"
            else
                printfn "✗ Validation FAILED"
                exit 1

        // Generate YAML
        if options.Verbose then
            printfn ""
            printfn "Generating YAML..."

        let yaml = generateFromConfig config
        let lineCount = yaml.Split('\n').Length

        if options.Verbose then
            printfn "  Generated %d lines" lineCount

        // Determine output path
        let outputPath =
            match options.OutputPath with
            | Some path -> path
            | None -> getDefaultOutputPath options.MeshType

        // Ensure directory exists
        let directory = Path.GetDirectoryName(outputPath)
        if not (String.IsNullOrEmpty(directory)) && not (Directory.Exists(directory)) then
            Directory.CreateDirectory(directory) |> ignore

        // Write file
        File.WriteAllText(outputPath, yaml)

        printfn ""
        printfn "✓ Successfully generated: %s" outputPath
        printfn "  Lines: %d" lineCount
        printfn "  Size: %d bytes" (File.ReadAllText(outputPath).Length)

        // Validate generated file against config
        if options.Validate then
            printfn ""
            printfn "Validating generated YAML against configuration..."
            match validateCompose yaml config with
            | Ok () ->
                printfn "✓ Generated YAML is valid"
            | Error errors ->
                printfn "✗ Generated YAML has errors:"
                errors |> List.iter (fun err -> printfn "  - %A" err)
                exit 1

        printfn ""
        0

    with
    | ex ->
        printfn ""
        printfn "✗ ERROR: %s" ex.Message
        if fsi.CommandLineArgs |> Array.contains "--verbose" then
            printfn ""
            printfn "Stack trace:"
            printfn "%s" ex.StackTrace
        printfn ""
        1

// Run main with command-line arguments
exit (main (fsi.CommandLineArgs.[1..]))
