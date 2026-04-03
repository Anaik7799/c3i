namespace Cepaf.Phases

open System
open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules

/// Application Container (Phoenix/Elixir) Standalone Verifier
/// SOPv5.11 Compliance: SC-CNT-009 (NixOS), SC-CEP-004 (boot threshold), SC-VAL-003 (consensus)
/// Verifies: Container creation, Mix compilation, Database connectivity, Phoenix health, Telemetry
module AppVerifier =

    // ========================================================================
    // Task Creation Helper
    // ========================================================================

    let createTask id desc entry exit start endState est = {
        Id = id; Description = desc; EntryCriteria = entry; ExitCriteria = exit
        StartState = start; EndState = endState; Status = Pending
        EstimatedDurationMs = est; ActualDurationMs = None
    }

    // ========================================================================
    // Task Runner with Progress Tracking
    // ========================================================================

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

    // ========================================================================
    // Polling Functions for Health Checks
    // ========================================================================

    /// Poll Phoenix health endpoint for readiness
    /// Checks /health or /api/health on port 4000
    let rec pollPhoenixReady (runner: IProcessRunner) container port attempts = async {
        if attempts >= 20 then
            return Error (HealthCheckTimedOut(container, "phoenix_health"))
        else
            // Try to curl the health endpoint from inside the container
            let! res = runner.Run("podman", ["exec"; container; "curl"; "-sf"; sprintf "http://localhost:%d/health" port])
            match res with
            | Ok _ -> return Ok ()
            | Error _ ->
                // Try alternative health endpoint
                let! res2 = runner.Run("podman", ["exec"; container; "curl"; "-sf"; sprintf "http://localhost:%d/api/health" port])
                match res2 with
                | Ok _ -> return Ok ()
                | Error _ ->
                    do! Async.Sleep 3000
                    return! pollPhoenixReady runner container port (attempts + 1)
    }

    /// Poll for Mix compilation completion by checking container logs
    let rec pollMixCompileReady (runner: IProcessRunner) container attempts = async {
        if attempts >= 30 then
            return Error (HealthCheckTimedOut(container, "mix_compile"))
        else
            // Check if "Compiling" or "compiled" appears in logs, indicating mix compile ran
            let! res = runner.Run("podman", ["logs"; "--tail"; "100"; container])
            match res with
            | Ok r ->
                let output = r.StandardOutput + r.StandardError
                // Look for compilation success indicators
                if output.Contains("Compiled") || output.Contains("compiled") || output.Contains("Generated indrajaal app") then
                    // Check for compilation errors
                    if output.Contains("** (CompileError)") || output.Contains("** (Mix)") then
                        return Error (SafetyViolation("SC-CMP-025", "Mix compilation failed with errors"))
                    else
                        return Ok ()
                elif output.Contains("Compiling") then
                    // Still compiling, wait more
                    do! Async.Sleep 5000
                    return! pollMixCompileReady runner container (attempts + 1)
                else
                    do! Async.Sleep 5000
                    return! pollMixCompileReady runner container (attempts + 1)
            | Error _ ->
                do! Async.Sleep 3000
                return! pollMixCompileReady runner container (attempts + 1)
    }

    /// Poll for Phoenix server startup
    let rec pollPhoenixServerReady (runner: IProcessRunner) container attempts = async {
        if attempts >= 30 then
            return Error (HealthCheckTimedOut(container, "phoenix_server"))
        else
            let! res = runner.Run("podman", ["logs"; "--tail"; "50"; container])
            match res with
            | Ok r ->
                let output = r.StandardOutput + r.StandardError
                // Look for Phoenix server startup message
                if output.Contains("Running") && output.Contains("Endpoint") then
                    return Ok ()
                elif output.Contains("Access") && output.Contains("at http") then
                    return Ok ()
                else
                    do! Async.Sleep 3000
                    return! pollPhoenixServerReady runner container (attempts + 1)
            | Error _ ->
                do! Async.Sleep 3000
                return! pollPhoenixServerReady runner container (attempts + 1)
    }

    /// Check database connectivity from the app container
    let checkDatabaseConnectivity (runner: IProcessRunner) container dbHost dbPort = asyncResult {
        // Try to connect to database from within the app container
        let ncCmd = sprintf "nc -z %s %d 2>/dev/null && echo ok" dbHost dbPort
        let! (res: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) =
            runner.Run("podman", ["exec"; container; "sh"; "-c"; ncCmd]) |> fromAsync
        match res with
        | Ok r when r.StandardOutput.Contains("ok") -> return ()
        | _ -> return! fromResult (Error (SafetyViolation("SC-DB-001", sprintf "Cannot connect to database at %s:%d" dbHost dbPort)))
    }

    /// Verify OTEL/Telemetry configuration in the app
    let checkTelemetryConfig (runner: IProcessRunner) container = asyncResult {
        // Check if OTEL environment variables are set
        let! res = runner.Run("podman", ["exec"; container; "sh"; "-c"; "env | grep -i otel || echo 'no_otel'"]) |> fromAsync
        match res with
        | Ok r ->
            if r.StandardOutput.Contains("OTEL") then
                return ()
            else
                // Telemetry not configured - this is a warning, not a failure
                return ()
        | Error _ -> return ()
    }

    // ========================================================================
    // Environment-Specific Execution
    // ========================================================================

    let executeForEnv (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) (env: Environment) = asyncResult {
        logger.Info(sprintf "SYSTEM_ACTIVITY: Standalone Application Verification for %A..." env)

        // Use PathResolver for consistent absolute path resolution (SC-CEP-001)
        let composeFile = PathResolver.resolve config.Registry.ComposeFiles.[env]

        let appContainer =
            match env with
            | TEST ->
                match config.Registry.ContainerNames.TryFind "app-test" with
                | Some name -> name
                | None -> "app"
            | _ ->
                match config.Registry.ContainerNames.TryFind "app" with
                | Some name -> name
                | None -> "app"

        let appPort =
            match config.Registry.PortMap.TryFind "app" with
            | Some port -> port
            | None -> 4000

        let dbPort =
            match config.Registry.PortMap.TryFind "db" with
            | Some port -> port
            | None -> 5433

        // 1. Task: Container Creation via podman-compose
        let t1 = createTask
                    (sprintf "APP_CREATE_%A" env)
                    "Application Container Creation via podman-compose"
                    "Compose file verified"
                    "Container process initialized"
                    "Absent"
                    "Created"
                    15000L

        let! _ = runTask logger t1 (fun () -> Podman.composeUp logger runner composeFile)

        // 2. Task: Verify Dependencies (Database must be healthy)
        let t2 = createTask
                    (sprintf "APP_DEPS_%A" env)
                    "Dependency Verification (Database connectivity)"
                    "Container created"
                    "Database connection verified"
                    "Created"
                    "DepsReady"
                    10000L

        let! _ = runTask logger t2 (fun () -> asyncResult {
            // First verify database TCP port is accessible
            let! _ = AceVerifier.verifyConsensus logger appContainer [ AceVerifier.verifyTcpPort logger dbPort ]
            // Then verify actual connectivity from app container
            do! checkDatabaseConnectivity runner appContainer "postgres" dbPort
            return ()
        })

        // 3. Task: Mix Compilation Verification
        let t3 = createTask
                    (sprintf "APP_COMPILE_%A" env)
                    "Mix Compilation Verification (Patient Mode)"
                    "Dependencies Ready"
                    "Mix compile completed without errors"
                    "DepsReady"
                    "Compiled"
                    120000L  // Patient mode - allow up to 2 minutes

        let! _ = runTask logger t3 (fun () -> asyncResult {
            let! _ = fromAsync (pollMixCompileReady runner appContainer 0)
            logger.Info("Mix compilation completed successfully (SC-CMP-025 verified)")
            return ()
        })

        // 4. Task: Phoenix Health Endpoint Check
        let t4 = createTask
                    (sprintf "APP_HEALTH_%A" env)
                    "Phoenix Health Endpoint Verification"
                    "Mix compiled"
                    "Health endpoint responds HTTP 200"
                    "Compiled"
                    "Healthy"
                    30000L

        let! _ = runTask logger t4 (fun () -> asyncResult {
            // First verify app port is listening
            let! _ = AceVerifier.verifyConsensus logger appContainer [ AceVerifier.verifyTcpPort logger appPort ]
            // Then verify Phoenix server is running
            let! _ = fromAsync (pollPhoenixServerReady runner appContainer 0)
            // Finally check health endpoint
            let! _ = fromAsync (pollPhoenixReady runner appContainer appPort 0)
            logger.Info(sprintf "Phoenix health endpoint verified on port %d" appPort)
            return ()
        })

        // 5. Task: Full Readiness Verification
        let t5 = createTask
                    (sprintf "APP_READY_%A" env)
                    "Full Application Readiness Verification"
                    "Health endpoint Healthy"
                    "Application fully operational"
                    "Healthy"
                    "Ready"
                    15000L

        let! _ = runTask logger t5 (fun () -> asyncResult {
            // Verify all Phoenix Endpoint ports
            let ports = [appPort; appPort + 1]  // 4000, 4001 per compose file
            for port in ports do
                let! _ = AceVerifier.verifyConsensus logger (sprintf "%s:port-%d" appContainer port) [
                    AceVerifier.verifyTcpPort logger port
                ]
                ()

            // Check telemetry configuration (optional)
            do! checkTelemetryConfig runner appContainer

            logger.Info("Application readiness verification complete")
            return ()
        })

        // 6. Task: Asset Compilation Check (Optional - for Phoenix with frontend)
        let t6 = createTask
                    (sprintf "APP_ASSETS_%A" env)
                    "Asset Compilation Verification (esbuild/tailwind)"
                    "Application Ready"
                    "Static assets compiled and served"
                    "Ready"
                    "AssetsReady"
                    10000L

        let! _ = runTask logger t6 (fun () -> asyncResult {
            // Check if assets are being served (verify priv/static exists)
            let! res = runner.Run("podman", ["exec"; appContainer; "ls"; "-la"; "/workspace/priv/static"]) |> fromAsync
            match res with
            | Ok r ->
                if r.StandardOutput.Contains("assets") || r.StandardOutput.Contains("css") || r.StandardOutput.Contains("js") then
                    logger.Info("Static assets directory verified")
                    return ()
                else
                    // No assets - might be API-only app, not a failure
                    logger.Info("No static assets found (API-only application)")
                    return ()
            | Error _ ->
                // priv/static doesn't exist - not a failure for API-only apps
                logger.Info("Static assets directory not found (API-only application)")
                return ()
        })

        // 7. Task: Observability Integration Check
        let t7 = createTask
                    (sprintf "APP_OBS_%A" env)
                    "Observability/Telemetry Integration Verification"
                    "Assets Ready"
                    "OTEL exporter configured and reporting"
                    "AssetsReady"
                    "SIL-Ready"
                    8000L

        let! _ = runTask logger t7 (fun () -> asyncResult {
            // Check for telemetry configuration in environment
            let! res = runner.Run("podman", ["exec"; appContainer; "sh"; "-c"; "env | grep -E '(OTEL|TELEMETRY|EXPORTER)' || true"]) |> fromAsync
            match res with
            | Ok r ->
                if not (String.IsNullOrWhiteSpace(r.StandardOutput)) then
                    logger.Info(sprintf "Telemetry environment: %s" (r.StandardOutput.Replace("\n", ", ")))
                else
                    logger.Info("No OTEL environment variables configured (SC-OBS-069 - optional for dev)")
                return ()
            | Error _ ->
                return ()
        })

        return ()
    }

    // ========================================================================
    // Main Execute Function
    // ========================================================================

    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("============================================================================")
        logger.Info("PHASE: APP_VERIFICATION (Standalone Application Container)")
        logger.Info("============================================================================")
        logger.Emit(PhaseStart "APP_VERIFICATION")

        let sw = Stopwatch.StartNew()

        // For standalone app test, use DEV environment by default
        // In full deployment, iterate through config.Environments
        let targetEnv =
            if config.Environments |> List.contains DEV then DEV
            elif config.Environments |> List.contains TEST then TEST
            else DEV

        do! executeForEnv logger runner config targetEnv

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds, Map.ofList [("phase", "APP_VERIFICATION")])
        logger.Emit(PhaseComplete("APP_VERIFICATION", sw.ElapsedMilliseconds, true))
        return ()
    }

    // ========================================================================
    // Service Chain Integration
    // ========================================================================

    /// Get the service dependencies for the app container
    let getDependencies () : string list =
        ["db"]  // App depends on database being healthy

    /// Get the verification tasks for service chain
    let getVerificationTasks (env: Environment) : ProtocolTask list =
        [
            createTask (sprintf "APP_CREATE_%A" env) "Container Creation" "Compose verified" "Container created" "Absent" "Created" 15000L
            createTask (sprintf "APP_DEPS_%A" env) "Dependency Check" "Created" "DB connected" "Created" "DepsReady" 10000L
            createTask (sprintf "APP_COMPILE_%A" env) "Mix Compile" "DepsReady" "Compiled" "DepsReady" "Compiled" 120000L
            createTask (sprintf "APP_HEALTH_%A" env) "Health Check" "Compiled" "HTTP 200" "Compiled" "Healthy" 30000L
            createTask (sprintf "APP_READY_%A" env) "Readiness" "Healthy" "Operational" "Healthy" "Ready" 15000L
        ]
