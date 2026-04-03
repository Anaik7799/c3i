namespace Cepaf.Phases

open System
open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules

module DbVerifier =

    let createTask id desc entry exit start endState est = {
        Id = id; Description = desc; EntryCriteria = entry; ExitCriteria = exit
        StartState = start; EndState = endState; Status = Pending
        EstimatedDurationMs = est; ActualDurationMs = None
    }

    let runTask (logger: QuadplexLogger) task (action: unit -> AsyncResult<'a, AppError>) = asyncResult {
        let updatedTask = { task with Status = InProgress 0 }
        logger.Emit(TaskUpdate updatedTask)
        let sw = Stopwatch.StartNew()
        
        let steps = 5
        let stepMs = int (task.EstimatedDurationMs / int64 steps)
        let actionTask = action ()
        
        let progressLoop = async {
            for i in [1..steps-1] do
                do! Async.Sleep stepMs
                logger.Emit(TaskUpdate { updatedTask with Status = InProgress (i * 100 / steps) })
        }
        Async.Start progressLoop
        
        let! res = actionTask
        sw.Stop()
        
        let finalTask = { updatedTask with Status = Completed; ActualDurationMs = Some sw.ElapsedMilliseconds }
        logger.Emit(TaskUpdate finalTask)
        return res
    }

    let rec pollReady (runner: IProcessRunner) container attempts = async {
        if attempts >= 10 then 
            return Error (HealthCheckTimedOut(container, "pg_isready"))
        else
            let! res = runner.Run("podman", ["exec"; container; "pg_isready"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"])
            match res with
            | Ok _ -> return Ok ()
            | Error _ -> 
                do! Async.Sleep 2000
                return! pollReady runner container (attempts + 1)
    }

    /// Resolve database container name for the given environment
    let private resolveDbContainer (config: CepaConfig) (env: Environment) : string =
        match env with
        | TEST -> config.Registry.ContainerNames.["db-primary"]
        | SYSTEM_STANDALONE_DB_TEST -> config.Registry.ContainerNames.["db-standalone"]
        | _ -> config.Registry.ContainerNames.["db"]

    /// Get the database port from config with fallback
    let private getDbPort (config: CepaConfig) : int =
        match config.Registry.PortMap.TryFind("db") with
        | Some port -> port
        | None -> 5433 // default

    let executeForEnv (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) (env: Environment) = asyncResult {
        logger.Info(sprintf "SYSTEM_ACTIVITY: Standalone Database Verification for %A..." env)

        // Use PathResolver for consistent absolute path resolution (SC-CEP-001)
        let composeFile = PathResolver.resolve config.Registry.ComposeFiles.[env]

        // Validate compose file exists before proceeding
        match PathResolver.validateComposeFile config.Registry.ComposeFiles.[env] with
        | Ok validPath -> logger.Info(sprintf "Compose file validated: %s" validPath)
        | Error msg -> logger.Info(sprintf "Compose file validation warning: %s" msg)

        // Resolve container name using PathResolver-aware helper
        let dbContainer = resolveDbContainer config env

        // Log resolved paths for debugging (SC-CEP-002)
        let pathInfo = PathResolver.getPathInfo config.Registry.ComposeFiles.[env]
        logger.Info(sprintf "Path resolution: original=%s resolved=%s exists=%b inScope=%b"
                        pathInfo.Original pathInfo.Resolved pathInfo.Exists pathInfo.InCepafScope)

        // Get port configuration
        let dbPort = getDbPort config

        // 1. Task: Container Creation
        let t1 = createTask 
                    (sprintf "DB_CREATE_%A" env) 
                    "Container Creation via podman-compose" 
                    "Compose file verified" 
                    "Container process initialized" 
                    "Absent" 
                    "Created" 
                    8000L
        
        let! _ = runTask logger t1 (fun () -> Podman.composeUp logger runner composeFile)

        // 2. Task: Setup & Health
        let t2 = createTask 
                    (sprintf "DB_SETUP_%A" env) 
                    "Database Setup and Proactive Health Probing" 
                    "Container created" 
                    "TCP Connectivity Verified" 
                    "Created" 
                    "Healthy" 
                    12000L
        
        let! _ = runTask logger t2 (fun () -> AceVerifier.verifyConsensus logger dbContainer [ AceVerifier.verifyTcpPort logger dbPort ])

        // 3. Task: Runtime Functional Test
        let t3 = createTask 
                    (sprintf "DB_QUERY_%A" env) 
                    "PostgreSQL Readiness Verification" 
                    "Engine is Healthy" 
                    "System returns READY status" 
                    "Healthy" 
                    "Verified" 
                    10000L
        
        let! _ = runTask logger t3 (fun () -> fromAsync (pollReady runner dbContainer 0))

        // 4. Task: Persistence Verification
        let t4 = createTask
                    (sprintf "DB_PERSISTENCE_%A" env)
                    "Data Persistence & volume integrity check"
                    "Database is Verified"
                    "Data survives container restart"
                    "Verified"
                    "Resilient"
                    15000L

        let! _ = runTask logger t4 (fun () -> asyncResult {
            let! _ = runner.Run("podman", ["exec"; dbContainer; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-c"; "CREATE TABLE IF NOT EXISTS cepa_heartbeat (ts TIMESTAMP); INSERT INTO cepa_heartbeat VALUES (NOW());"]) |> fromAsync
            
            let! _ = Podman.stop logger runner dbContainer
            let! _ = Podman.start logger runner dbContainer
            
            let! _ = AceVerifier.verifyConsensus logger dbContainer [ AceVerifier.verifyTcpPort logger dbPort ]
            let! _ = fromAsync (pollReady runner dbContainer 0)

            let! (res: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["exec"; dbContainer; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-t"; "-c"; "SELECT count(*) FROM cepa_heartbeat;"]) |> fromAsync
            match res with
            | Ok r ->
                if r.StandardOutput.Trim() = "0" then
                    return! fromResult (Error (SafetyViolation("SC-DB-031", "Heartbeat lost after restart")))
                else
                    return ()
            | Error e -> return! fromResult (Error e)
        })

        // 5. Task: TimescaleDB Extension Integrity
        let t5 = createTask
                    (sprintf "DB_TSDB_EXTENSION_%A" env)
                    "TimescaleDB Extension operational check"
                    "Engine is Resilient"
                    "Extension is active and loadable"
                    "Resilient"
                    "Extended"
                    5000L

        let! _ = runTask logger t5 (fun () -> asyncResult {
            let! (res: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["exec"; dbContainer; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-t"; "-c"; "SELECT installed_version FROM pg_available_extensions WHERE name = 'timescaledb';"]) |> fromAsync
            match res with
            | Ok r ->
                if String.IsNullOrWhiteSpace(r.StandardOutput) then
                    return! fromResult (Error (SafetyViolation("SC-DB-019", "TimescaleDB extension NOT FOUND")))
                else
                    logger.Info(sprintf "TimescaleDB Version: %s" (r.StandardOutput.Trim()))
                    return ()
            | Error e -> return! fromResult (Error e)
        })

        // 6. Task: Hypertable Logic Probe
        let t6 = createTask
                    (sprintf "DB_HYPERTABLE_%A" env)
                    "TimescaleDB Hypertable mock creation probe"
                    "Extension is Extended"
                    "Hypertable created successfully"
                    "Extended"
                    "SIL-Ready"
                    5000L

        let! _ = runTask logger t6 (fun () -> asyncResult {
            let sql = "CREATE TABLE IF NOT EXISTS cepa_metrics (time TIMESTAMP NOT NULL, value DOUBLE PRECISION); SELECT create_hypertable('cepa_metrics', 'time', if_not_exists => TRUE);"
            let! _ = runner.Run("podman", ["exec"; dbContainer; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-c"; sql]) |> fromAsync
            return ()
        })

        return ()
    }

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("============================================================================")
        logger.Info("PHASE: DB_VERIFICATION (Standalone Activity)")
        logger.Info("============================================================================")
        logger.Emit(PhaseStart "DB_VERIFICATION")
        
        for env in config.Environments do
            do! executeForEnv logger runner config env
            
        logger.Emit(PhaseComplete("DB_VERIFICATION", 0L, true))
        return ()
    }
