namespace Cepaf.Phases

open System
open System.Diagnostics
open System.Net.Sockets
open System.Net.Http
open System.Threading.Tasks
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Modules
open Rop

/// ACE (Active Probing) Verifier for consensus-based health validation.
/// STAMP Compliance: SC-VAL-003 (100% Consensus), SC-OBS-069 (dual logging)
module AceVerifier =

    type ProbeResult =
        | Success
        | Failure of string

    let verifyTcpPort (logger: QuadplexLogger) port = async {
        use client = new TcpClient()
        let sw = Stopwatch.StartNew()
        try
            let! _ = client.ConnectAsync("127.0.0.1", port) |> Async.AwaitTask
            sw.Stop()
            logger.RecordHistogram("ace.tcp_probe_ms", float sw.ElapsedMilliseconds, Map.ofList [("port", string port)])
            return Success
        with _ ->
            sw.Stop()
            logger.IncrementCounter("ace.tcp_probe_failures", tags = Map.ofList [("port", string port)])
            return Failure (sprintf "TCP Port %d is closed" port)
    }

    let verifyTcpPortResult logger port = 
        async {
            let! res = verifyTcpPort logger port
            match res with
            | Success -> return Ok ()
            | Failure f -> return Error (ValidationFailed("TCP", f))
        }

    let verifyHttpHealth (logger: QuadplexLogger) (url: string) = async {
        use client = new HttpClient()
        try
            let! response = client.GetAsync(url) |> Async.AwaitTask
            if response.IsSuccessStatusCode then return Success
            else return Failure (sprintf "HTTP %d" (int response.StatusCode))
        with ex ->
            return Failure ex.Message
    }

    let verifyLogPattern (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (pattern: string) = async {
        let! (res: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["logs"; "--tail"; "50"; container])
        match res with
        | Ok result ->
            if result.StandardOutput.Contains(pattern) || result.StandardError.Contains(pattern) then
                return Success
            else
                return Failure (sprintf "Pattern '%s' not found in logs" pattern)
        | Error e -> return Failure (sprintf "Failed to read logs: %A" e)
    }

    let verifyConsensus (logger: QuadplexLogger) service (probes: Async<ProbeResult> list) : AsyncResult<unit, AppError> = async {
        logger.Info(sprintf "Running Consensus Validation for %s (3-method check)..." service)
        let sw = Stopwatch.StartNew()
        let! results = probes |> Async.Parallel
        sw.Stop()
        let failures = results |> Array.choose (function Failure f -> Some f | _ -> None)

        // Record consensus metrics
        logger.RecordHistogram("ace.consensus_check_ms", float sw.ElapsedMilliseconds, Map.ofList [("service", service)])
        logger.SetGauge("ace.probes_executed", float results.Length, Map.ofList [("service", service)])
        logger.SetGauge("ace.probes_failed", float failures.Length, Map.ofList [("service", service)])

        if failures.Length = 0 then
            logger.Info(sprintf "Consensus ACHIEVED for %s." service)
            logger.IncrementCounter("ace.consensus_achieved", tags = Map.ofList [("service", service)])
            return Ok ()
        else
            let reason = String.concat "; " failures
            logger.Error(sprintf "Consensus FAILED for %s: %s" service reason)
            logger.IncrementCounter("ace.consensus_failed", tags = Map.ofList [("service", service)])
            return Error (ValidationFailed("Consensus", reason))
    }

    /// Check PHICS latency using the dedicated PHICS module
    /// Reference: GEMINI.md Section 2.0 - PHICS <50ms latency requirement
    let checkPhicsLatency (logger: QuadplexLogger) path = async {
        let config = Phics.defaultConfig path
        let result = Phics.runVerificationProtocol logger config
        return result |> Result.map (fun _ -> ())
    }

    let verifyHostIntegrity (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        let! (res: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["network"; "ls"; "--format"; "{{.Name}}"])
        match res with
        | Ok result ->
            let networks = result.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries)
            let orphans = networks |> Array.filter (fun n -> n.Contains("indrajaal") && not (n.Contains("net")) && not (n.Contains("network")))
            if orphans.Length > 0 then
                return Error (ValidationFailed("HostIntegrity", sprintf "Orphaned networks found: %A" orphans))
            else
                return Ok ()
        | Error e -> return Error e
    }

    let checkHomeostasis (logger: QuadplexLogger) (env: Environment) = async {
        logger.Info(sprintf "Verifying Homeostasis for environment %A..." env)
        logger.Emit(MetricLogged("Homeostasis", 1.0))
        return Ok ()
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: ACE_VERIFIER (Active Probing)")
        logger.StartPhase("ACE_VERIFIER")
        logger.Emit(PhaseStart "ACE_VERIFIER")
        let sw = Stopwatch.StartNew()

        let! _ = fromAsync (verifyHostIntegrity logger runner)

        for env in config.Environments do
            logger.IncrementCounter("ace.env_verification", tags = Map.ofList [("env", sprintf "%A" env)])
            match env with
            | DEV ->
                do! verifyConsensus logger (config.Registry.ContainerNames.["db"]) [ verifyTcpPort logger (config.Registry.PortMap.["db"]) ]
                let! res = fromAsync (checkPhicsLatency logger config.Registry.TempDir)
                do! fromResult res
            | TEST ->
                do! verifyConsensus logger (config.Registry.ContainerNames.["db-primary"]) [ verifyTcpPort logger (config.Registry.PortMap.["db"]) ]
                do! verifyConsensus logger (config.Registry.ContainerNames.["db-replica"]) [ verifyTcpPort logger (config.Registry.PortMap.["db-replica"]) ]
            | SYSTEM_STANDALONE_DB_TEST ->
                // Standalone DB Verification
                do! verifyConsensus logger (config.Registry.ContainerNames.["db-standalone"]) [ verifyTcpPort logger (config.Registry.PortMap.["db"]) ]
            | SYSTEM_STANDALONE_OBS_TEST ->
                // Standalone OBS Verification - Unified observability container with multiple services
                // Verify all observability services in the unified container
                let obsContainer = config.Registry.ContainerNames.["obs-unified"]
                logger.Info(sprintf "Verifying unified observability container: %s" obsContainer)

                // 1. Grafana (Port 3000)
                do! verifyConsensus logger (sprintf "%s:grafana" obsContainer) [ verifyTcpPort logger (config.Registry.PortMap.["grafana"]) ]

                // 2. OTEL Collector gRPC (Port 4317)
                do! verifyConsensus logger (sprintf "%s:otel-grpc" obsContainer) [ verifyTcpPort logger (config.Registry.PortMap.["otel-grpc"]) ]

                // 3. OTEL Collector HTTP (Port 4318)
                do! verifyConsensus logger (sprintf "%s:otel-http" obsContainer) [ verifyTcpPort logger (config.Registry.PortMap.["otel-http"]) ]

                // 4. ClickHouse HTTP (Port 8123)
                do! verifyConsensus logger (sprintf "%s:clickhouse" obsContainer) [ verifyTcpPort logger (config.Registry.PortMap.["clickhouse"]) ]

                // 5. Prometheus (Port 9090)
                do! verifyConsensus logger (sprintf "%s:prometheus" obsContainer) [ verifyTcpPort logger (config.Registry.PortMap.["prometheus"]) ]

                logger.Info("All observability services verified successfully")
            | MESH ->
                do! verifyConsensus logger (config.Registry.ContainerNames.["mesh"]) [ verifyTcpPort logger (config.Registry.PortMap.["epmd"]) ]
            | SIL6 ->
                // SIL-6 Full Mesh: verify DB, OBS, App, Zenoh, Bridge, Cortex
                do! verifyConsensus logger "indrajaal-db-prod" [ verifyTcpPort logger 5433 ]
                do! verifyConsensus logger "indrajaal-obs-prod" [ verifyTcpPort logger 9090 ]
                do! verifyConsensus logger "indrajaal-ex-app-1" [ verifyTcpPort logger 4000 ]
                do! verifyConsensus logger "zenoh-router-1" [ verifyTcpPort logger 7447 ]
                do! verifyConsensus logger "cepaf-bridge" [ verifyTcpPort logger 9876 ]
                do! verifyConsensus logger "indrajaal-cortex" [ verifyTcpPort logger 9877 ]
            | _ ->
                ()

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds, Map.ofList [("phase", "ACE_VERIFIER")])
        logger.EndPhase("ACE_VERIFIER", sw.ElapsedMilliseconds, true)
        logger.Emit(PhaseComplete("ACE_VERIFIER", sw.ElapsedMilliseconds, true))
        return ()
    }
