#!/usr/bin/env dotnet fsi
// CockpitOperations.fsx - v2.1.0
// WHAT: Unified CEPAF Cockpit operations interface for production-equivalent environment
// WHY: Single entry point for deploy, test, monitor, and operate workflows
// CONSTRAINTS: Requires .NET SDK 8.0+, Podman 5.4.1+, OpenRouter API key
// SOPv5.11 Compliance: SC-OODA-001, SC-CNT-009, SC-UX-001, SC-METRICS-003
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

open System
open System.IO
open System.Diagnostics

// =============================================================================
// CONFIGURATION
// =============================================================================

module Config =
    let Version = "2.0.0"
    let ProjectRoot = Environment.GetEnvironmentVariable("PROJECT_ROOT")
                      |> Option.ofObj
                      |> Option.defaultValue (Directory.GetCurrentDirectory() + "/../../..")
    let ScriptsDir = Path.Combine(ProjectRoot, "lib/cepaf/scripts")
    let ArtifactsDir = Path.Combine(ProjectRoot, "lib/cepaf/artifacts")
    let ReportsDir = Path.Combine(ProjectRoot, "reports")

    // Ensure reports directory exists
    if not (Directory.Exists(ReportsDir)) then
        Directory.CreateDirectory(ReportsDir) |> ignore

// =============================================================================
// UTILITIES
// =============================================================================

module Shell =
    // SC-METRICS-003: Mandatory parallelization environment variables
    let mandatoryEnvVars = [
        ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
        ("NO_TIMEOUT", "true")
        ("PATIENT_MODE", "enabled")
        ("INFINITE_PATIENCE", "true")
        ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
        ("SKIP_ZENOH_NIF", "0")
    ]

    let injectMandatoryEnv (psi: ProcessStartInfo) =
        for (key, value) in mandatoryEnvVars do
            psi.EnvironmentVariables.[key] <- value

    let exec (command: string) (args: string) : int * string * string =
        let psi = ProcessStartInfo(
            FileName = command,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        )
        injectMandatoryEnv psi  // SC-METRICS-003: Inject mandatory env vars
        use proc = new Process(StartInfo = psi)
        proc.Start() |> ignore
        let output = proc.StandardOutput.ReadToEnd()
        let error = proc.StandardError.ReadToEnd()
        proc.WaitForExit()
        (proc.ExitCode, output, error)

    let execAsync (command: string) (args: string) : unit =
        let psi = ProcessStartInfo(
            FileName = command,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = false
        )
        injectMandatoryEnv psi  // SC-METRICS-003: Inject mandatory env vars
        use proc = new Process(StartInfo = psi)
        proc.Start() |> ignore

module Console =
    let printHeader (title: string) =
        printfn ""
        printfn "╔══════════════════════════════════════════════════════════════════╗"
        printfn "║  %s" (title.PadRight(64))
        printfn "╚══════════════════════════════════════════════════════════════════╝"
        printfn ""

    let printSection (title: string) =
        printfn ""
        printfn "─────────────────────────────────────────────────────────────────────"
        printfn "  %s" title
        printfn "─────────────────────────────────────────────────────────────────────"

    let printSuccess (msg: string) = printfn "✅ %s" msg
    let printError (msg: string) = printfn "❌ %s" msg
    let printWarning (msg: string) = printfn "⚠️  %s" msg
    let printInfo (msg: string) = printfn "ℹ️  %s" msg
    let printStep (step: int) (msg: string) = printfn "[%d] %s" step msg

// =============================================================================
// OPERATIONS
// =============================================================================

module Operations =
    let deploy () =
        Console.printHeader "DEPLOYING PROD-STANDALONE MESH ENVIRONMENT"

        let targetFile = Path.Combine(Config.ArtifactsDir, "podman-compose-prod-standalone.yml")
        
        Console.printInfo $"Using artifact: {targetFile}"

        if File.Exists(targetFile) then
            let (code, output, error) = Shell.exec "podman-compose" $"-f {targetFile} up -d"
            if code = 0 then
                Console.printSuccess "Deployment initiated"
                printfn "%s" output
            else
                Console.printError $"Deployment failed: {error}"
        else
            Console.printError $"Compose file not found: {targetFile}"

    let status () =
        Console.printHeader "ENVIRONMENT STATUS"

        Console.printSection "Container Status"
        let (code, output, _) = Shell.exec "podman" "ps --filter label=project=indrajaal --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
        if code = 0 then
            printfn "%s" output
        else
            Console.printWarning "No Indrajaal containers running"

        Console.printSection "Health Checks (SC-CLU-002: Prod-Standalone)"
        // Prod-standalone container names per podman-compose-prod-standalone.yml
        let containers = ["zenoh-router"; "indrajaal-db-prod"; "indrajaal-obs-prod"; "indrajaal-ex-app-1"]
        for container in containers do
            let (code, output, _) = Shell.exec "podman" $"inspect {container} --format '{{{{.State.Health.Status}}}}'"
            let status = if code = 0 then output.Trim() else "not running"
            let icon = if status = "healthy" then "✅" else if status = "starting" then "⏳" else "❌"
            printfn "  %s %s: %s" icon container status

    let test () =
        Console.printHeader "RUN COMPREHENSIVE TESTS"

        Console.printSection "Available Test Suites"
        printfn "  1. Comprehensive Runtime Tests (75+ scenarios)"
        printfn "  2. UX/UI/CX/DX Evaluation (7 categories)"
        printfn "  3. Original Runtime Test Orchestrator"
        printfn ""

        Console.printSection "Running Comprehensive Tests..."

        let testScript = Path.Combine(Config.ScriptsDir, "ComprehensiveRuntimeTests.fsx")
        if File.Exists(testScript) then
            let (code, output, error) = Shell.exec "dotnet" $"fsi {testScript} --mode swarm"
            if code = 0 then
                Console.printSuccess "Tests completed"
                printfn "%s" output
            else
                Console.printError $"Tests failed: {error}"
                printfn "%s" output
        else
            Console.printError $"Test script not found: {testScript}"

    let ux () =
        Console.printHeader "UX/UI/CX/DX EVALUATION"

        let uxScript = Path.Combine(Config.ScriptsDir, "CockpitUXEvaluator.fsx")
        if File.Exists(uxScript) then
            let (code, output, error) = Shell.exec "dotnet" $"fsi {uxScript}"
            if code = 0 then
                Console.printSuccess "UX evaluation completed"
                printfn "%s" output
            else
                Console.printError $"UX evaluation failed: {error}"
        else
            Console.printError $"UX script not found: {uxScript}"

    let monitor () =
        Console.printHeader "MONITORING ENDPOINTS"

        Console.printSection "Access Points"
        let endpoints = [
            ("Phoenix App", "http://localhost:4000")
            ("Health Check", "http://localhost:4001/health")
            ("Prajna Cockpit", "http://localhost:4000/prajna")
            ("AI Copilot", "http://localhost:4000/prajna/copilot")
            ("Grafana", "http://localhost:3000")
            ("Prometheus", "http://localhost:9090")
            ("Loki", "http://localhost:3100")
            ("SigNoz", "http://localhost:3301")
            ("SigNoz API", "http://localhost:8080")
            ("ClickHouse", "http://localhost:8123")
        ]

        for (name, url) in endpoints do
            printfn "  %-20s %s" name url

        Console.printSection "Quick Health Check"
        use client = new System.Net.Http.HttpClient()
        client.Timeout <- System.TimeSpan.FromSeconds(5.0)
        for (name, url) in endpoints |> List.take 3 do
            let isUp = 
                try
                    let response = client.GetAsync(url).Result
                    response.IsSuccessStatusCode
                with _ -> false
            let status = if isUp then "✅ UP" else "❌ DOWN"
            printfn "  %s %s" status name

    let logs (container: string option) =
        Console.printHeader "CONTAINER LOGS"
        // SC-CLU-002: Default to seed node in fractal-cluster
        let target = container |> Option.defaultValue "indrajaal-app-1"
        Console.printInfo $"Showing logs for: {target}"
        printfn ""

        Shell.execAsync "podman" $"logs -f {target}"

    let cleanup () =
        Console.printHeader "CLEANUP MESH ENVIRONMENT"

        let targetFile = Path.Combine(Config.ArtifactsDir, "podman-compose-prod-standalone.yml")

        if File.Exists(targetFile) then
            let (code, output, error) = Shell.exec "podman-compose" $"-f {targetFile} down -v"
            if code = 0 then
                Console.printSuccess "Cleanup completed"
                printfn "%s" output
            else
                Console.printError $"Cleanup failed: {error}"
        else
            // Fallback: stop individual prod-standalone containers (SC-CLU-002)
            let containers = ["zenoh-router"; "indrajaal-db-prod";
                             "indrajaal-obs-prod"; "indrajaal-ex-app-1"]
            for c in containers do
                let _ = Shell.exec "podman" $"stop {c}"
                let _ = Shell.exec "podman" $"rm {c}"
                ()
            Console.printSuccess "Containers stopped and removed"

    let reports () =
        Console.printHeader "GENERATED REPORTS"

        if Directory.Exists(Config.ReportsDir) then
            let files = Directory.GetFiles(Config.ReportsDir, "*.md")
                        |> Array.sortByDescending File.GetLastWriteTime
                        |> Array.truncate 10

            if files.Length > 0 then
                printfn "  Recent reports (latest 10):"
                printfn ""
                for f in files do
                    let info = FileInfo(f)
                    printfn "    %s  %s" (info.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) info.Name
            else
                Console.printInfo "No reports generated yet"
        else
            Console.printInfo "Reports directory does not exist"

    let help () =
        Console.printHeader $"CEPAF COCKPIT OPERATIONS v{Config.Version}"

        printfn "Usage: dotnet fsi CockpitOperations.fsx <command> [options]"
        printfn ""

        Console.printSection "Commands"
        let commands = [
            ("deploy", "Deploy production-equivalent environment")
            ("status", "Show environment status and health")
            ("test", "Run comprehensive runtime tests (75+ scenarios)")
            ("ux", "Run UX/UI/CX/DX evaluation")
            ("monitor", "Show monitoring endpoints")
            ("logs [container]", "Stream container logs (default: indrajaal-app-1)")
            ("cleanup", "Stop and remove all containers")
            ("reports", "List generated reports")
            ("help", "Show this help message")
        ]

        for (cmd, desc) in commands do
            printfn "  %-20s %s" cmd desc

        Console.printSection "Environment Variables"
        printfn "  OPENROUTER_API_KEY    OpenRouter API key for AI validation"
        printfn "  PROJECT_ROOT          Project root directory (auto-detected)"

        Console.printSection "Examples"
        printfn "  dotnet fsi CockpitOperations.fsx deploy"
        printfn "  dotnet fsi CockpitOperations.fsx status"
        printfn "  OPENROUTER_API_KEY=sk-xxx dotnet fsi CockpitOperations.fsx test"
        printfn "  dotnet fsi CockpitOperations.fsx logs db-primary"

        Console.printSection "Quick Start"
        Console.printStep 1 "export OPENROUTER_API_KEY='sk-or-v1-...'"
        Console.printStep 2 "dotnet fsi CockpitOperations.fsx deploy"
        Console.printStep 3 "dotnet fsi CockpitOperations.fsx status"
        Console.printStep 4 "dotnet fsi CockpitOperations.fsx test"
        Console.printStep 5 "dotnet fsi CockpitOperations.fsx ux"
        Console.printStep 6 "dotnet fsi CockpitOperations.fsx reports"

// =============================================================================
// MAIN
// =============================================================================

let args = fsi.CommandLineArgs |> Array.skip 1

match args |> Array.tryHead with
| Some "deploy" -> Operations.deploy ()
| Some "status" -> Operations.status ()
| Some "test" -> Operations.test ()
| Some "ux" -> Operations.ux ()
| Some "monitor" -> Operations.monitor ()
| Some "logs" -> Operations.logs (args |> Array.tryItem 1)
| Some "cleanup" -> Operations.cleanup ()
| Some "reports" -> Operations.reports ()
| Some "help" | None -> Operations.help ()
| Some cmd ->
    Console.printError $"Unknown command: {cmd}"
    printfn "Run 'dotnet fsi CockpitOperations.fsx help' for usage"
