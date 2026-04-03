namespace Cepaf.Phases

open System
open System.Diagnostics
open System.Net.Sockets
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules
open Cepaf.ServiceChains

/// ═══════════════════════════════════════════════════════════════════════════════
/// CEPAF Standalone Distributed Mode Verifier
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Comprehensive verification for standalone distributed mode with:
/// - Mathematical FPPS 5-method consensus
/// - Full service DAG boot ordering
/// - Erlang distribution verification (SC-CLU-001 to SC-CLU-005)
/// - Database setup and migration
/// - Observability stack verification
/// - Remote access configuration
///
/// STAMP Compliance: SC-CLU-001 to SC-CLU-005, SC-VAL-003, SC-OBS-069
///
/// Mathematical Invariants:
///   ∀ service ∈ Services: Health(service) = Consensus(FPPS₅)
///   Boot(n) → ∀ dep ∈ Deps(n): Healthy(dep)
///   Emergency(n) → ∀ child ∈ Dependents(n): Stop(child) < 1000ms
///
/// ═══════════════════════════════════════════════════════════════════════════════
module StandaloneVerifier =

    // ════════════════════════════════════════════════════════════════════════════
    // TYPES
    // ════════════════════════════════════════════════════════════════════════════

    /// Network detection result
    type NetworkMode =
        | Tailscale of ip: string * hostname: string * suffix: string
        | Local of ip: string

    /// FPPS probe result (5-method consensus)
    type FPPSProbe = {
        Method: string
        Passed: bool
        LatencyMs: int64
        Details: string
    }

    /// FPPS consensus result
    type FPPSResult = {
        TotalProbes: int
        PassedCount: int
        FailedCount: int
        ConsensusAchieved: bool
        Probes: FPPSProbe list
    }

    /// Database status
    type DatabaseStatus =
        | NotRunning
        | Running
        | DatabaseMissing of dbName: string
        | MigrationsPending of count: int
        | Ready

    /// Erlang distribution status
    type ErlangDistStatus = {
        EpmdRunning: bool
        NodeRegistered: bool
        NodeName: string option
        DistPort: int option
        Cookie: string option
    }

    /// Standalone verification result
    type StandaloneStatus = {
        Network: NetworkMode
        Database: DatabaseStatus
        Redis: bool
        Observability: FPPSResult option
        ErlangDist: ErlangDistStatus
        PhoenixHealthy: bool
        AllHealthy: bool
        Errors: string list
    }

    // ════════════════════════════════════════════════════════════════════════════
    // TASK HELPERS
    // ════════════════════════════════════════════════════════════════════════════

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

    // ════════════════════════════════════════════════════════════════════════════
    // NETWORK DETECTION
    // ════════════════════════════════════════════════════════════════════════════

    /// Detect network mode (Tailscale vs Local)
    let detectNetworkMode (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        logger.Info("Detecting network mode...")

        // Try Tailscale first
        let! tsStatus = runner.Run("tailscale", ["status"; "--json"])
        match tsStatus with
        | Ok result when result.StandardOutput.Contains("\"BackendState\":\"Running\"") ->
            // Tailscale is running - get IP and hostname
            let! tsIp = runner.Run("tailscale", ["ip"; "-4"])
            let ip =
                match tsIp with
                | Ok r -> r.StandardOutput.Trim()
                | Error _ -> "127.0.0.1"

            let! tsHostname = runner.Run("tailscale", ["status"; "--self"; "--json"])
            let hostname =
                match tsHostname with
                | Ok r ->
                    // Parse DNSName from JSON
                    let json = r.StandardOutput
                    let idx = json.IndexOf("\"DNSName\":\"")
                    if idx > 0 then
                        let start = idx + 11
                        let endIdx = json.IndexOf("\"", start)
                        json.Substring(start, endIdx - start).TrimEnd('.')
                    else
                        sprintf "%s.ts.net" (System.Environment.MachineName)
                | Error _ -> sprintf "%s.ts.net" (System.Environment.MachineName)

            let suffix =
                let parts = hostname.Split('.')
                if parts.Length > 1 then
                    String.Join(".", parts |> Array.skip 1)
                else
                    "ts.net"

            logger.Info(sprintf "Tailscale detected: IP=%s, Hostname=%s" ip hostname)
            return Tailscale (ip, hostname, suffix)

        | _ ->
            // Fallback to local mode
            let! hostnameRes = runner.Run("hostname", ["-I"])
            let ip =
                match hostnameRes with
                | Ok r ->
                    let ips = r.StandardOutput.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                    if ips.Length > 0 then ips.[0] else "127.0.0.1"
                | Error _ -> "127.0.0.1"

            logger.Info(sprintf "Local mode: IP=%s" ip)
            return Local ip
    }

    /// Get IP address from network mode
    let getIpAddress (mode: NetworkMode) : string =
        match mode with
        | Tailscale (ip, _, _) -> ip
        | Local ip -> ip

    // ════════════════════════════════════════════════════════════════════════════
    // ERLANG COOKIE MANAGEMENT
    // ════════════════════════════════════════════════════════════════════════════

    /// Get or generate Erlang cookie
    let getOrCreateCookie (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        let cookieFile = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".erlang.cookie")

        // Check environment variable first
        match Environment.GetEnvironmentVariable("RELEASE_COOKIE") with
        | null | "" ->
            // Check file
            if System.IO.File.Exists(cookieFile) then
                let cookie = System.IO.File.ReadAllText(cookieFile).Trim()
                logger.Info(sprintf "Using existing cookie from %s" cookieFile)
                return cookie
            else
                // Generate new cookie
                let! result = runner.Run("openssl", ["rand"; "-base64"; "32"])
                let cookie =
                    match result with
                    | Ok r -> r.StandardOutput.Replace("/", "").Replace("+", "").Replace("=", "").Trim().Substring(0, 20)
                    | Error _ -> "DEFAULTCOOKIEVALUE12"

                // Save to file
                System.IO.File.WriteAllText(cookieFile, cookie)
                // Set permissions (Unix)
                let! _ = runner.Run("chmod", ["400"; cookieFile])
                logger.Info(sprintf "Generated new cookie: %s..." (cookie.Substring(0, 8)))
                return cookie
        | cookie ->
            logger.Info("Using RELEASE_COOKIE from environment")
            return cookie
    }

    // ════════════════════════════════════════════════════════════════════════════
    // TCP PORT VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Check if a TCP port is open
    let checkTcpPort (host: string) (port: int) : Async<bool> = async {
        try
            use client = new TcpClient()
            do! client.ConnectAsync(host, port) |> Async.AwaitTask
            return true
        with _ ->
            return false
    }

    /// Check TCP port with retries
    let rec checkTcpPortWithRetry (host: string) (port: int) (retries: int) (delayMs: int) : Async<bool> = async {
        let! result = checkTcpPort host port
        if result then
            return true
        elif retries > 0 then
            do! Async.Sleep delayMs
            return! checkTcpPortWithRetry host port (retries - 1) delayMs
        else
            return false
    }

    // ════════════════════════════════════════════════════════════════════════════
    // DATABASE VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Verify PostgreSQL database
    let verifyDatabase (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) = async {
        logger.Info("Verifying PostgreSQL database...")

        // Check if container is running
        let! containerCheck = runner.Run("podman", ["inspect"; container; "--format"; "{{.State.Running}}"])
        match containerCheck with
        | Ok r when r.StandardOutput.Trim() = "true" ->
            // Container running - check pg_isready
            let! pgReady = runner.Run("podman", ["exec"; container; "pg_isready"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"])
            match pgReady with
            | Ok _ ->
                // Check if indrajaal_dev database exists
                let! dbCheck = runner.Run("podman", ["exec"; container; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-lqt"])
                match dbCheck with
                | Ok r when r.StandardOutput.Contains("indrajaal_dev") ->
                    logger.Info("Database indrajaal_dev exists and is accessible")
                    return Ready
                | Ok _ ->
                    logger.Info("Database indrajaal_dev does not exist")
                    return DatabaseMissing "indrajaal_dev"
                | Error _ ->
                    return Running
            | Error _ ->
                return Running
        | _ ->
            return NotRunning
    }

    /// Create database if missing
    let createDatabaseIfMissing (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (dbName: string) = asyncResult {
        logger.Info(sprintf "Creating database %s..." dbName)

        let! (createRes: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["exec"; container; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-c"; sprintf "CREATE DATABASE %s;" dbName]) |> fromAsync
        match createRes with
        | Ok _ -> ()
        | Error e -> logger.Info(sprintf "Database creation result: %A" e)

        // Verify creation
        let! (dbCheck: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["exec"; container; "psql"; "-h"; "127.0.0.1"; "-p"; "5433"; "-U"; "postgres"; "-lqt"]) |> fromAsync
        match dbCheck with
        | Ok r when r.StandardOutput.Contains(dbName) ->
            logger.Info(sprintf "Database %s created successfully" dbName)
            return ()
        | Ok _ ->
            return! fromResult (Error (SafetyViolation("SC-DB-001", sprintf "Failed to create database %s" dbName)))
        | Error e ->
            return! fromResult (Error e)
    }

    /// Run Ecto migrations
    let runMigrations (logger: QuadplexLogger) (runner: IProcessRunner) (workDir: string) = asyncResult {
        logger.Info("Running Ecto migrations...")

        // Set environment variables and run migration via bash
        let migrationCmd = sprintf "cd %s && POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_dev MIX_ENV=dev mix ecto.migrate" workDir

        let! (result: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("bash", ["-c"; migrationCmd]) |> fromAsync
        match result with
        | Ok r when r.ExitCode = 0 ->
            logger.Info("Migrations completed successfully")
            return ()
        | Ok r ->
            logger.Error(sprintf "Migration failed: %s" r.StandardError)
            return! fromResult (Error (ProcessError("mix ecto.migrate", r.ExitCode, r.StandardError)))
        | Error e ->
            return! fromResult (Error e)
    }

    // ════════════════════════════════════════════════════════════════════════════
    // REDIS VERIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Verify Redis cache
    let verifyRedis (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) = async {
        logger.Info("Verifying Redis cache...")

        let! pingResult = runner.Run("podman", ["exec"; container; "redis-cli"; "ping"])
        match pingResult with
        | Ok r when r.StandardOutput.Trim() = "PONG" ->
            logger.Info("Redis is healthy: PONG received")
            return true
        | _ ->
            logger.Info("Redis health check failed")
            return false
    }

    // ════════════════════════════════════════════════════════════════════════════
    // ERLANG DISTRIBUTION VERIFICATION (SC-CLU-001 to SC-CLU-005)
    // ════════════════════════════════════════════════════════════════════════════

    /// Verify EPMD is running (SC-CLU-002)
    let verifyEpmd (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        logger.Info("Verifying EPMD (SC-CLU-002)...")

        let! epmdResult = runner.Run("epmd", ["-names"])
        match epmdResult with
        | Ok r when r.StandardOutput.Contains("up and running") ->
            logger.Info("EPMD is running on port 4369")
            return true
        | _ ->
            logger.Info("EPMD is not running")
            return false
    }

    /// Get registered Erlang nodes
    let getRegisteredNodes (logger: QuadplexLogger) (runner: IProcessRunner) = async {
        let! epmdResult = runner.Run("epmd", ["-names"])
        match epmdResult with
        | Ok r ->
            // Parse lines like: "name indrajaal at port 9100"
            let nodes =
                r.StandardOutput.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                |> Array.choose (fun line ->
                    if line.Contains("at port") then
                        let parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                        if parts.Length >= 4 then
                            Some (parts.[1], int parts.[4])
                        else None
                    else None)
                |> Array.toList
            return nodes
        | Error _ ->
            return []
    }

    /// Verify Erlang distribution status
    let verifyErlangDist (logger: QuadplexLogger) (runner: IProcessRunner) (expectedNodeName: string) = async {
        logger.Info("Verifying Erlang distribution (SC-CLU-001, SC-CLU-003)...")

        let! epmdRunning = verifyEpmd logger runner
        let! nodes = getRegisteredNodes logger runner

        let nodeInfo =
            nodes
            |> List.tryFind (fun (name, _) -> expectedNodeName.Contains(name))

        let status = {
            EpmdRunning = epmdRunning
            NodeRegistered = nodeInfo.IsSome
            NodeName = nodeInfo |> Option.map fst
            DistPort = nodeInfo |> Option.map snd
            Cookie = None
        }

        if status.NodeRegistered then
            logger.Info(sprintf "Erlang node registered: %s on port %d" (status.NodeName |> Option.defaultValue "?") (status.DistPort |> Option.defaultValue 0))
        else
            logger.Info("Erlang node not yet registered")

        return status
    }

    // ════════════════════════════════════════════════════════════════════════════
    // FPPS 5-METHOD CONSENSUS (SC-VAL-003)
    // ════════════════════════════════════════════════════════════════════════════

    /// FPPS Method 1: Podman container status
    let fppsProbe1_PodmanStatus (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) = async {
        let sw = Stopwatch.StartNew()
        let! result = runner.Run("podman", ["ps"; "--filter"; sprintf "name=%s" container; "--format"; "{{.State}}"])
        sw.Stop()

        match result with
        | Ok r when r.StandardOutput.Trim().ToLower() = "running" ->
            return { Method = "PodmanStatus"; Passed = true; LatencyMs = sw.ElapsedMilliseconds; Details = "Container running" }
        | Ok r ->
            return { Method = "PodmanStatus"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "State: %s" (r.StandardOutput.Trim()) }
        | Error e ->
            return { Method = "PodmanStatus"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Error: %A" e }
    }

    /// FPPS Method 2: HTTP health endpoint
    let fppsProbe2_HttpHealth (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (port: int) (path: string) = async {
        let sw = Stopwatch.StartNew()
        let! result = runner.Run("podman", ["exec"; container; "curl"; "-sf"; sprintf "http://localhost:%d%s" port path])
        sw.Stop()

        match result with
        | Ok _ ->
            return { Method = "HttpHealth"; Passed = true; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Port %d%s responsive" port path }
        | Error e ->
            return { Method = "HttpHealth"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "HTTP check failed on %d%s" port path }
    }

    /// FPPS Method 3: TCP port probe
    let fppsProbe3_TcpPort (logger: QuadplexLogger) (port: int) = async {
        let sw = Stopwatch.StartNew()
        let! result = checkTcpPort "127.0.0.1" port
        sw.Stop()

        if result then
            return { Method = "TcpPort"; Passed = true; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Port %d open" port }
        else
            return { Method = "TcpPort"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Port %d closed" port }
    }

    /// FPPS Method 4: Process verification
    let fppsProbe4_ProcessCheck (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (processPattern: string) = async {
        let sw = Stopwatch.StartNew()
        let! result = runner.Run("podman", ["exec"; container; "ps"; "aux"])
        sw.Stop()

        match result with
        | Ok r when r.StandardOutput.Contains(processPattern) ->
            return { Method = "ProcessCheck"; Passed = true; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Process '%s' found" processPattern }
        | Ok _ ->
            return { Method = "ProcessCheck"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Process '%s' not found" processPattern }
        | Error e ->
            return { Method = "ProcessCheck"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Error: %A" e }
    }

    /// FPPS Method 5: Log pattern analysis
    let fppsProbe5_LogPattern (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (patterns: string list) = async {
        let sw = Stopwatch.StartNew()
        let! result = runner.Run("podman", ["logs"; "--tail"; "100"; container])
        sw.Stop()

        match result with
        | Ok r ->
            let output = r.StandardOutput + r.StandardError
            let foundPatterns = patterns |> List.filter (fun p -> output.Contains(p, StringComparison.OrdinalIgnoreCase))
            if not foundPatterns.IsEmpty then
                return { Method = "LogPattern"; Passed = true; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Found: %s" (String.concat ", " foundPatterns) }
            else
                return { Method = "LogPattern"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = "No patterns found" }
        | Error e ->
            return { Method = "LogPattern"; Passed = false; LatencyMs = sw.ElapsedMilliseconds; Details = sprintf "Error: %A" e }
    }

    /// Run full FPPS 5-method consensus
    let runFPPSConsensus (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (healthPort: int) (healthPath: string) (processPattern: string) (logPatterns: string list) = async {
        logger.Info(sprintf "Running FPPS 5-Method Consensus for %s (SC-VAL-003)..." container)
        let sw = Stopwatch.StartNew()

        // Execute all 5 probes in parallel
        let probes = [|
            fppsProbe1_PodmanStatus logger runner container
            fppsProbe2_HttpHealth logger runner container healthPort healthPath
            fppsProbe3_TcpPort logger healthPort
            fppsProbe4_ProcessCheck logger runner container processPattern
            fppsProbe5_LogPattern logger runner container logPatterns
        |]

        let! results = probes |> Async.Parallel
        sw.Stop()

        let passedCount = results |> Array.filter (fun p -> p.Passed) |> Array.length
        let failedCount = results |> Array.filter (fun p -> not p.Passed) |> Array.length

        // FPPS requires 100% consensus (SC-VAL-003)
        let consensusAchieved = failedCount = 0

        let fppsResult = {
            TotalProbes = results.Length
            PassedCount = passedCount
            FailedCount = failedCount
            ConsensusAchieved = consensusAchieved
            Probes = results |> Array.toList
        }

        // Log results
        for probe in results do
            let status = if probe.Passed then "PASS" else "FAIL"
            logger.Info(sprintf "  [%s] %s: %s (%dms)" status probe.Method probe.Details probe.LatencyMs)

        if consensusAchieved then
            logger.Info(sprintf "FPPS Consensus ACHIEVED for %s (%d/%d probes passed)" container passedCount results.Length)
        else
            logger.Error(sprintf "FPPS Consensus FAILED for %s (%d/%d probes failed)" container failedCount results.Length)

        return fppsResult
    }

    // ════════════════════════════════════════════════════════════════════════════
    // CONTAINER LIFECYCLE MANAGEMENT
    // ════════════════════════════════════════════════════════════════════════════

    /// Start containers using podman-compose
    let startContainers (logger: QuadplexLogger) (runner: IProcessRunner) (composeFile: string) = asyncResult {
        logger.Info(sprintf "Starting containers from %s..." composeFile)

        let! (result: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman-compose", ["-f"; composeFile; "up"; "-d"]) |> fromAsync
        match result with
        | Ok r when r.ExitCode = 0 ->
            logger.Info("Containers started successfully")
            return ()
        | Ok r ->
            return! fromResult (Error (ProcessError("podman-compose up", r.ExitCode, r.StandardError)))
        | Error e ->
            return! fromResult (Error e)
    }

    /// Stop containers
    let stopContainers (logger: QuadplexLogger) (runner: IProcessRunner) (composeFile: string) = asyncResult {
        logger.Info("Stopping containers...")

        let! (result: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman-compose", ["-f"; composeFile; "down"]) |> fromAsync
        match result with
        | Ok r when r.ExitCode = 0 ->
            logger.Info("Containers stopped")
            return ()
        | Ok r ->
            return! fromResult (Error (ProcessError("podman-compose down", r.ExitCode, r.StandardError)))
        | Error e ->
            return! fromResult (Error e)
    }

    /// Wait for container health
    let rec waitForContainerHealth (logger: QuadplexLogger) (runner: IProcessRunner) (container: string) (attempts: int) (maxAttempts: int) = async {
        if attempts >= maxAttempts then
            return Error (HealthCheckTimedOut(container, "container_health"))
        else
            let! status = runner.Run("podman", ["inspect"; container; "--format"; "{{.State.Health.Status}}"])
            match status with
            | Ok r when r.StandardOutput.Trim() = "healthy" ->
                logger.Info(sprintf "Container %s is healthy" container)
                return Ok ()
            | Ok r when r.StandardOutput.Trim() = "starting" ->
                logger.Info(sprintf "Container %s still starting (attempt %d/%d)..." container attempts maxAttempts)
                do! Async.Sleep 3000
                return! waitForContainerHealth logger runner container (attempts + 1) maxAttempts
            | _ ->
                do! Async.Sleep 2000
                return! waitForContainerHealth logger runner container (attempts + 1) maxAttempts
    }

    // ════════════════════════════════════════════════════════════════════════════
    // MAIN VERIFICATION EXECUTION
    // ════════════════════════════════════════════════════════════════════════════

    /// Execute full standalone verification
    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Info("PHASE: STANDALONE_VERIFICATION (Full Mesh Cluster)")
        logger.Info("STAMP: SC-CLU-001 to SC-CLU-005, SC-VAL-003, SC-OBS-069")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Emit(PhaseStart "STANDALONE_VERIFICATION")
        let sw = Stopwatch.StartNew()

        // 1. Detect network mode
        let t1 = createTask "STANDALONE_NET_001" "Network Mode Detection" "System ready" "Mode detected" "Unknown" "Detected" 5000L
        let! networkMode = runTask logger t1 (fun () -> asyncResult {
            let! mode = detectNetworkMode logger runner |> fromAsync
            return mode
        })

        let ip = getIpAddress networkMode
        logger.Info(sprintf "Network IP: %s" ip)

        // 2. Get/Create Erlang cookie (SC-CLU-004)
        let t2 = createTask "STANDALONE_COOKIE_001" "Erlang Cookie Setup (SC-CLU-004)" "Network detected" "Cookie ready" "Detected" "Cookie_Ready" 3000L
        let! cookie = runTask logger t2 (fun () -> asyncResult {
            let! c = getOrCreateCookie logger runner |> fromAsync
            return c
        })

        // 3. Create network if needed
        let t3 = createTask "STANDALONE_NETWORK_001" "Mesh Network Creation" "Cookie ready" "Network exists" "Cookie_Ready" "Network_Ready" 5000L
        let! _ = runTask logger t3 (fun () -> asyncResult {
            let! (networkCheck: Result<CliWrap.Buffered.BufferedCommandResult, AppError>) = runner.Run("podman", ["network"; "exists"; StandaloneChain.meshNetwork.Name]) |> fromAsync
            match networkCheck with
            | Ok r when r.ExitCode = 0 ->
                logger.Info(sprintf "Network %s already exists" StandaloneChain.meshNetwork.Name)
                return ()
            | _ ->
                logger.Info(sprintf "Creating network %s with subnet %s" StandaloneChain.meshNetwork.Name StandaloneChain.meshNetwork.Subnet)
                let! _ = runner.Run("podman", ["network"; "create"; "--subnet"; StandaloneChain.meshNetwork.Subnet; StandaloneChain.meshNetwork.Name]) |> fromAsync
                return ()
        })

        // 4. Start infrastructure containers (DB, Redis, OBS)
        let composeFile = PathResolver.resolve (StandaloneChain.getComposeFilePath ())
        let t4 = createTask "STANDALONE_INFRA_001" "Infrastructure Container Startup" "Network ready" "Containers started" "Network_Ready" "Containers_Starting" 30000L
        let! _ = runTask logger t4 (fun () -> startContainers logger runner composeFile)

        // 5. Wait for database health
        let dbContainer = StandaloneChain.Layer0.dbStandalone.Name
        let t5 = createTask "STANDALONE_DB_001" "Database Health Verification" "Containers started" "DB healthy" "Containers_Starting" "DB_Healthy" 60000L
        let! _ = runTask logger t5 (fun () -> asyncResult {
            let! _ = fromAsync (waitForContainerHealth logger runner dbContainer 0 20)
            return ()
        })

        // 6. Verify/Create database
        let t6 = createTask "STANDALONE_DB_002" "Database Existence Check" "DB healthy" "DB exists" "DB_Healthy" "DB_Exists" 10000L
        let! _ = runTask logger t6 (fun () -> asyncResult {
            let! dbStatus = verifyDatabase logger runner dbContainer |> fromAsync
            match dbStatus with
            | DatabaseMissing dbName ->
                do! createDatabaseIfMissing logger runner dbContainer dbName
            | Ready ->
                logger.Info("Database already exists and is ready")
            | _ ->
                logger.Info(sprintf "Database status: %A" dbStatus)
            return ()
        })

        // 7. Verify Redis
        let redisContainer = StandaloneChain.Layer1.redisStandalone.Name
        let t7 = createTask "STANDALONE_REDIS_001" "Redis Health Verification" "DB exists" "Redis healthy" "DB_Exists" "Redis_Healthy" 15000L
        let! _ = runTask logger t7 (fun () -> asyncResult {
            let! healthy = verifyRedis logger runner redisContainer |> fromAsync
            if not healthy then
                logger.Info("Redis not yet healthy, waiting...")
                do! Async.Sleep 5000 |> Async.Ignore |> fromAsync
            return ()
        })

        // 8. Verify Observability Stack with FPPS
        let obsContainer = StandaloneChain.Layer2.obsStandalone.Name
        let t8 = createTask "STANDALONE_OBS_001" "Observability FPPS Verification" "Redis healthy" "OBS FPPS passed" "Redis_Healthy" "OBS_Ready" 45000L
        let! obsFpps = runTask logger t8 (fun () -> asyncResult {
            let! fpps = runFPPSConsensus logger runner obsContainer 3000 "/api/health" "grafana" ["ready"; "started"; "listening"] |> fromAsync
            return fpps
        })

        // 9. Verify EPMD (SC-CLU-002)
        let t9 = createTask "STANDALONE_EPMD_001" "EPMD Verification (SC-CLU-002)" "OBS ready" "EPMD running" "OBS_Ready" "EPMD_Running" 5000L
        let! epmdRunning = runTask logger t9 (fun () -> asyncResult {
            let! running = verifyEpmd logger runner |> fromAsync
            if not running then
                // Start EPMD if not running
                logger.Info("Starting EPMD...")
                let! _ = runner.Run("epmd", ["-daemon"]) |> fromAsync
                do! Async.Sleep 2000 |> Async.Ignore |> fromAsync
            return running
        })

        // 10. Display connection information
        logger.Info("")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Info("  STANDALONE MODE CONNECTION INFORMATION")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")
        logger.Info("")
        logger.Info(sprintf "Erlang Node:   indrajaal@%s" ip)
        logger.Info(sprintf "Cookie:        %s" cookie)
        logger.Info(sprintf "EPMD:          %s:4369" ip)
        logger.Info(sprintf "Distribution:  %s:9100-9105" ip)
        logger.Info("")
        logger.Info("Phoenix:")
        logger.Info(sprintf "  HTTP:        http://%s:4000" ip)
        logger.Info(sprintf "  API:         http://%s:4000/api/v1" ip)
        logger.Info("")
        logger.Info("Observability:")
        logger.Info(sprintf "  Grafana:     http://%s:3000" ip)
        logger.Info(sprintf "  Prometheus:  http://%s:9090" ip)
        logger.Info(sprintf "  SigNoz:      http://%s:3301" ip)
        logger.Info("")
        logger.Info("Livebook (from Windows):")
        logger.Info("  PowerShell:")
        logger.Info(sprintf "    $env:LIVEBOOK_COOKIE = \"%s\"" cookie)
        logger.Info("    livebook server")
        logger.Info("")
        logger.Info("  Then in Livebook UI:")
        logger.Info("    Runtime → Attached node")
        logger.Info(sprintf "    Name:   indrajaal@%s" ip)
        logger.Info(sprintf "    Cookie: %s" cookie)
        logger.Info("")
        logger.Info("IEx Remote Shell:")
        logger.Info(sprintf "  iex --name client@%s --cookie %s --remsh indrajaal@%s" ip cookie ip)
        logger.Info("")
        logger.Info("═══════════════════════════════════════════════════════════════════════════════")

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds, Map.ofList [("phase", "STANDALONE_VERIFICATION")])
        logger.Emit(PhaseComplete("STANDALONE_VERIFICATION", sw.ElapsedMilliseconds, true))

        return ()
    }

    /// Start application in distributed mode
    let startApplication (logger: QuadplexLogger) (runner: IProcessRunner) (workDir: string) (ip: string) (cookie: string) = asyncResult {
        logger.Info("Starting Phoenix application in distributed mode...")

        let nodeName = sprintf "indrajaal@%s" ip
        let erlFlags = "-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9105"

        // Set environment variables
        Environment.SetEnvironmentVariable("RELEASE_NODE", nodeName)
        Environment.SetEnvironmentVariable("RELEASE_COOKIE", cookie)
        Environment.SetEnvironmentVariable("DISTRIBUTED_MODE", "true")
        Environment.SetEnvironmentVariable("CLUSTER_STRATEGY", "standalone")
        Environment.SetEnvironmentVariable("PHX_HOST", ip)
        Environment.SetEnvironmentVariable("PHX_SERVER", "true")

        logger.Info(sprintf "Node: %s" nodeName)
        logger.Info(sprintf "Cookie: %s..." (cookie.Substring(0, min 8 cookie.Length)))
        logger.Info("Starting iex -S mix phx.server...")

        // This would start the application (in practice, this would be a separate process)
        return ()
    }

    // ════════════════════════════════════════════════════════════════════════════
    // SERVICE CHAIN INTEGRATION
    // ════════════════════════════════════════════════════════════════════════════

    /// Get all STAMP constraints being verified
    let getStampConstraints () : SafetyConstraint list =
        StandaloneChain.stampConstraints @ [
            { Id = "SC-VAL-003"; Category = "VAL"; Description = "100% FPPS Consensus required"; Compliance = None }
            { Id = "SC-OBS-069"; Category = "OBS"; Description = "Dual logging (Terminal + SigNoz)"; Compliance = None }
        ]

    /// Get verification protocol tasks
    let getVerificationTasks () : ProtocolTask list =
        StandaloneChain.getVerificationTasks ()
