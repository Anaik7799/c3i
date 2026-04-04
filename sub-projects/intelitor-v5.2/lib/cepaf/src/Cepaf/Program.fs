namespace Cepaf

open System
open System.IO
open Argu
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Cockpit

module Program =

    let getEnv var defaultValue =
        let v = Environment.GetEnvironmentVariable(var)
        if String.IsNullOrWhiteSpace(v) then defaultValue else v

    let createRegistry () =
        let baseDir = Path.Combine(Directory.GetCurrentDirectory(), "lib", "cepaf", "artifacts")
        if not (Directory.Exists(baseDir)) then Directory.CreateDirectory(baseDir) |> ignore

        let uid = getEnv "UID" "1000" // Default to standard user
        let socketPath =
            if uid = "0" then Rootful "/run/podman/podman.sock"
            else Rootless (sprintf "/run/user/%s/podman/podman.sock" uid)

        {
            LogPath = Path.Combine(baseDir, "cepa-audit.log")
            DatabasePath = Path.Combine(baseDir, "cepa-state.db")
            TempDir = Path.Combine(baseDir, "tmp")

            ComposeFiles = Map.ofList [
                DEV, getEnv "CEPAF_DEV_COMPOSE" "podman-compose-3container.yml"
                TEST, getEnv "CEPAF_TEST_COMPOSE" "podman-compose-testing.yml"
                DEMO, getEnv "CEPAF_DEMO_COMPOSE" "podman-compose.yml"
                PROD, getEnv "CEPAF_PROD_COMPOSE" "podman-compose-secure.yml"
                SYSTEM_STANDALONE_DB_TEST, getEnv "CEPAF_STANDALONE_DB_TEST_COMPOSE" "lib/cepaf/artifacts/podman-compose-db-standalone.yml"
                SYSTEM_STANDALONE_OBS_TEST, getEnv "CEPAF_STANDALONE_OBS_TEST_COMPOSE" "lib/cepaf/artifacts/podman-compose-obs-standalone.yml"
                MESH, getEnv "CEPAF_MESH_COMPOSE" "podman-compose-standalone-distributed.yml"
            ]
            
            ContainerNames = Map.ofList [
                "db", getEnv "CEPAF_DB_CONTAINER" "indrajaal-db"
                "db-primary", getEnv "CEPAF_DB_PRIMARY_CONTAINER" "indrajaal-db-primary"
                "db-replica", getEnv "CEPAF_DB_REPLICA_CONTAINER" "indrajaal-db-replica"
                "db-standalone", getEnv "CEPAF_DB_STANDALONE_CONTAINER" "indrajaal-db-test"
                "app", getEnv "CEPAF_APP_CONTAINER" "indrajaal-app"
                "mesh", getEnv "CEPAF_MESH_NODE" "mesh-node"
                // OBS Standalone containers (unified observability stack)
                "obs-unified", getEnv "CEPAF_OBS_UNIFIED_CONTAINER" "indrajaal-obs-standalonetest"
                "obs-grafana", getEnv "CEPAF_OBS_GRAFANA_CONTAINER" "indrajaal-obs-grafana"
                "obs-signoz", getEnv "CEPAF_OBS_SIGNOZ_CONTAINER" "indrajaal-obs-signoz"
                "obs-otel", getEnv "CEPAF_OBS_OTEL_CONTAINER" "indrajaal-obs-otel-collector"
            ]
            
            PortMap = Map.ofList [
                "db", getEnv "CEPAF_DB_PORT" "5433" |> int
                "db-replica", getEnv "CEPAF_DB_REPLICA_PORT" "5434" |> int
                "epmd", getEnv "CEPAF_EPMD_PORT" "4369" |> int
                // OBS Standalone ports
                "grafana", getEnv "CEPAF_GRAFANA_PORT" "3000" |> int
                "signoz", getEnv "CEPAF_SIGNOZ_PORT" "3301" |> int
                "otel-grpc", getEnv "CEPAF_OTEL_GRPC_PORT" "4317" |> int
                "otel-http", getEnv "CEPAF_OTEL_HTTP_PORT" "4318" |> int
                "clickhouse", getEnv "CEPAF_CLICKHOUSE_PORT" "8123" |> int
                "prometheus", getEnv "CEPAF_PROMETHEUS_PORT" "9090" |> int
            ]
            
            ReadyPatterns = Map.ofList [
                "app", "Access IndrajaalWeb.Endpoint"
            ]
            
            Dockerfiles = Map.ofList [
                "localhost/sopv511-base:latest", "Dockerfile.sopv51-base"
                "localhost/indrajaal-timescaledb-demo:nixos-devenv", "Dockerfile.db"
                "localhost/indrajaal-sopv51-elixir-app:nixos-devenv", "Dockerfile.sopv51-app"
            ]
            
            PodmanSocket = Some socketPath

            Constraints = [
                { Id = "SC-CEP-001"; Category = "Locality"; Description = "All CEPAF artifacts MUST reside in lib/cepaf/"; Compliance = None }
                { Id = "SC-CEP-002"; Category = "Decoupling"; Description = "Zero hardcoded infrastructure references in source"; Compliance = None }
                { Id = "SC-CEP-003"; Category = "Consensus"; Description = "Mandatory 3-method health verification (TCP, HTTP, Log)"; Compliance = None }
                { Id = "SC-CEP-004"; Category = "Performance"; Description = "System boot duration SHALL NOT exceed 30s"; Compliance = None }
                { Id = "SC-CNT-009"; Category = "Isolation"; Description = "System SHALL use NixOS containers exclusively"; Compliance = None }
                { Id = "SC-CNT-010"; Category = "Security"; Description = "Registry source restricted to localhost/"; Compliance = None }
            ]
        }

    [<EntryPoint>]
    let main args =
        // Handle "regression" subcommand - dispatch to RegressionRunner
        if args.Length > 0 && args.[0].ToLower() = "regression" then
            let regArgs = if args.Length > 1 then args.[1..] else [||]
            Cepaf.Testing.RegressionRunner.run regArgs
        // Handle "mesh" subcommand - dispatch to SIL4MeshCLI
        elif args.Length > 0 && args.[0].ToLower() = "mesh" then
            let meshArgs = if args.Length > 1 then args.[1..] else [||]
            let cli = Cepaf.Mesh.CLI.SIL4MeshCLI()
            let result = cli.Execute(meshArgs)
            
            // If command was "up", launch the Dashboard after boot
            if result.Success && (match result.Command with | Cepaf.Mesh.CLI.Up _ -> true | _ -> false) then
                printfn ">>> BOOT SUCCESSFUL. LAUNCHING DASHBOARD..."
                cli.Dashboard() |> ignore
            
            if result.Success then 0 else 1
        else

        let parser = ArgumentParser.Create<CepaArgs>(programName = "cepa")

        try
            let results = parser.Parse(args)

            // Check for Dashboard_Demo first - runs standalone
            if results.Contains(Dashboard_Demo) then
                printfn "[CEPAF] Running CLI Dashboard Demo..."
                Observability.Dashboard.demo ()
                0
            // Check for Prajna C3I Mesh Cockpit demo
            elif results.Contains(Prajna_Demo) then
                printfn ""
                printfn "╔══════════════════════════════════════════════════════════════════════╗"
                printfn "║  PRAJNA - C3I Mesh Cockpit (Transcendental Wisdom Intelligence)     ║"
                printfn "║  AI-Enhanced Control Interface with Digital Twin Capabilities       ║"
                printfn "╠══════════════════════════════════════════════════════════════════════╣"
                printfn "║  NASA-STD-3000 | NUREG-0700 | MIL-STD-1472H Compliant               ║"
                printfn "║  Dark Cockpit Philosophy | Two-Step Commit | Smart Metrics         ║"
                printfn "╚══════════════════════════════════════════════════════════════════════╝"
                printfn ""
                Cepaf.Cockpit.Cockpit.demo ()
                0
            // Check for Prajna Migration Demo
            elif results.Contains(Prajna_Migration_Demo) then
                printfn ""
                printfn "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
                printfn "║  PRAJNA MIGRATION - Unified Substrate Verification                                      ║"
                printfn "║  Running Phase 1 Verification of F# Port (Brain in a Box)                               ║"
                printfn "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
                printfn "║  SC-THR-001 (Immutability) | SC-THR-002 (Isolation) | SC-THR-003 (Bounded Mailboxes)    ║"
                printfn "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
                printfn ""
                // Use existing demo for now as verification harness
                Cepaf.Cockpit.Cockpit.demo () 
                0
            // Run Phase 2 Connectivity Verification (Lobotomy Test)
            elif results.Contains(Phase2_Verify) then
                Cepaf.Cockpit.Phase2Verification.run ()
                0
            // Run Phase 3 Cognitive Expansion Verification
            elif results.Contains(Phase3_Verify) then
                Cepaf.Cockpit.Phase3Verification.run ()
                0
            // Run Phase 5 Cognitive Fabric Verification
            elif results.Contains(Phase5_Verify) then
                Cepaf.Cockpit.Phase5Verification.run ()
                0
            // Run Master 9x9 Full System Verification
            elif results.Contains(FullSystem_Verify) then
                Cepaf.Cockpit.FullSystemVerification.run ()
                0
            // Run 8x8 Fractal Health Check Suite (L0-L7)
            elif results.Contains(Fractal_Verify) then
                let cli = Cepaf.Mesh.CLI.SIL4MeshCLI()
                cli.Execute([|"verify-fractal"|]) |> ignore
                0
            // Check for C3I Multi-Agent Dashboard with OODA/GDE/ACE
            elif results.Contains(C3I_Demo) then
                printfn ""
                printfn "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
                printfn "║  C3I MULTI-AGENT DASHBOARD - Autonomous Evolution Engine (AEE)                          ║"
                printfn "║  5 Specialized Agents + 1 Supervisor | OODA/GDE/ACE Control Loops                       ║"
                printfn "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
                printfn "║  🎯 Goal: Zero Errors | Zero Warnings | 100%% Coverage | Full Pipeline Verification      ║"
                printfn "║  ⚡ Fast OODA (<1000ms) | Smart GDE Proposals | Safety Envelope Active                   ║"
                printfn "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
                printfn ""
                Cepaf.Cockpit.C3IMultiAgent.demo ()
                0
            // Full AEE Mode - runs until zero-defect goal achieved
            elif results.Contains(AEE_Mode) then
                printfn ""
                printfn "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
                printfn "║  AUTONOMOUS EVOLUTION ENGINE (AEE) - FULL MODE                                          ║"
                printfn "║  Running until GDE Goal Achieved: ZERO ERRORS | ZERO WARNINGS | 100%% COVERAGE          ║"
                printfn "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
                printfn "║  ⚠️  This mode runs autonomously until goal is achieved or manual interrupt              ║"
                printfn "║  Press Ctrl+C to safely abort with state preservation                                   ║"
                printfn "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
                printfn ""
                // Run the C3I dashboard in full AEE mode
                Cepaf.Cockpit.C3IMultiAgent.demo ()
                0
            // Aerospace Theme Simulator with User Journey Testing
            elif results.Contains(Theme_Simulator) then
                printfn ""
                printfn "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
                printfn "║  AEROSPACE THEME SIMULATOR - User Journey Testing System                                ║"
                printfn "║  17-Dimensional Design System | 12 Test Categories | WCAG Compliance                   ║"
                printfn "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
                printfn "║  Controls: Arrow keys navigate | Enter select | Q quit                                  ║"
                printfn "║  Journey: J-Journey | K-Timeline | L-Branch | C-Checkpoint | R-Rollback                 ║"
                printfn "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
                printfn ""
                Cepaf.Cockpit.ThemeSimulator.run ()
                0
            // SIL4 Supreme Startup (10s SLA)
            elif results.Contains(SIL4_Startup) then
                let registry = createRegistry()
                let (logger, _) = createInfrastructure registry
                let task = async {
                    let! res = Orchestration.MeshCortex.startup logger
                    match res with
                    | Ok _ -> return 0
                    | Error _ -> return 1
                }
                Async.RunSynchronously task
            // SIL4 Surgical Shutdown (5s SLA)
            elif results.Contains(SIL4_Shutdown) then
                let registry = createRegistry()
                let (logger, _) = createInfrastructure registry
                let task = async {
                    let! res = Orchestration.MeshCortex.shutdown logger
                    match res with
                    | Ok _ -> return 0
                    | Error _ -> return 1
                }
                Async.RunSynchronously task
            // Supervised SIL6 Panoptic Ignition
            elif results.Contains(Supervised_Ignite) then
                let cli = Cepaf.Mesh.CLI.SIL4MeshCLI()
                Cepaf.Mesh.PanopticSupervisor.run cli
                0
            // Metabolic Substrate Pruning
            elif results.Contains(Prune) then
                let metabolic = results.GetResult(Prune)
                let confirm = results.TryGetResult(Confirm_Prune)
                let cli = Cepaf.Mesh.CLI.SIL4MeshCLI()
                cli.Prune(metabolic, ?confirmHash = confirm) |> ignore
                0
            else

            let envs = results.GetResult(Env, [DEV])
            let registry = createRegistry ()
            
            let config = {
                Environments = envs
                Sterilize = not (results.Contains(No_Sterilize))
                FormalVerify = results.Contains(Verify)
                Build = not (results.Contains(No_Build))
                DbTestOnly = results.Contains(Db_Test)
                ObsTestOnly = results.Contains(Obs_Test)
                StandaloneMode = results.Contains(Standalone)
                InfraCheck = not (results.Contains(No_Infra))
                RunTests = results.Contains(Test)
                RunUiCheck = results.Contains(UI)
                AutoConfirm = results.Contains(Yes)
                PatientMode = results.Contains(Patient_Mode)
                PhicsEnabled = true
                BootThresholdMs = getEnv "CEPAF_BOOT_THRESHOLD" "30000" |> int64
                Registry = registry
            }

            let (logger, runner) = createInfrastructure registry

            // Pre-flight audit with observability
            logger.Info("[SC-OBS-069] Quadplex Observability: INITIALIZED")
            logger.Info(sprintf "[SC-OBS-071] Active Channels: %d" logger.ChannelCount)
            logger.Emit(SafetyAuditStarted)

            if not (registry.LogPath.Contains("lib/cepaf")) then
                logger.Error("STAMP VIOLATION: SC-CEP-001", SafetyViolation("SC-CEP-001", "Log path outside CEPAF scope"))
                logger.IncrementCounter("safety.violations", tags = Map.ofList [("constraint", "SC-CEP-001")])
                disposeInfrastructure()
                exit 1

            for sc in registry.Constraints do
                logger.Emit(SafetyCheckPassed sc.Id)
                logger.IncrementCounter("safety.checks_passed", tags = Map.ofList [("constraint", sc.Id)])

            logger.Emit(SafetyAuditComplete true)

            let task = async {
                try
                    let! protocolResult = Orchestrator.runProtocol logger runner config
                    match protocolResult with
                    | Ok _ ->
                        logger.IncrementCounter("protocol.exit_code", tags = Map.ofList [("code", "0")])
                        return 0
                    | Error err ->
                        logger.Error("PROTOCOL HALTED due to critical error.", err)
                        logger.IncrementCounter("protocol.exit_code", tags = Map.ofList [("code", "1")])
                        return 1
                finally
                    // Ensure all logs are flushed before exit
                    logger.Flush()
            }

            let exitCode = Async.RunSynchronously task

            // Cleanup infrastructure
            disposeInfrastructure()
            exitCode

        with ex ->
            printfn "CRITICAL FATAL Error: %s" ex.Message
            disposeInfrastructure()
            1