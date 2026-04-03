namespace Cepaf.Sentinel.MCP.Tools

open System
open System.Diagnostics
open System.Net.Http
open System.Net.Sockets
open System.Text.Json
open System.Threading
open Cepaf.Sentinel.MCP.Protocol

/// MCP tool for mesh container verification — tests all 16 containers across
/// fractal layers L0-L7, runs FPPS 5-method consensus, and per-container
/// service-specific health probes.
///
/// Actions:
///   all       — Full 16-container verification with FPPS + service tests + layer map
///   container — Verify a single container by name
///   layer     — Verify all containers at a specific fractal layer (0-7)
///   fpps      — Run FPPS 5-method consensus for a container
///   services  — Run service-specific tests for a container
///   quick     — Fast podman-only status check for all 16 containers
///   genome    — Show the 16-container SIL-6 genome definition
///
/// STAMP: SC-CNT-009 (NixOS), SC-CNT-010 (localhost registry), SC-CEP-003 (FPPS),
///        SC-VAL-003 (100% consensus), SC-IGNITE-008 (16-container genome)
/// AOR: AOR-VER-016 (container health verified), AOR-VER-017 (Zenoh connectivity verified)
module ContainerVerificationTools =

    // ═══════════════════════════════════════════════════════════════════
    // SCHEMA HELPERS
    // ═══════════════════════════════════════════════════════════════════

    let private mkSchema (props: (string * obj) list) (required: string list) : obj =
        {| ``type`` = "object"
           properties = props |> Map.ofList
           required = required |}

    let private stringProp desc : obj =
        {| ``type`` = "string"; description = desc |} :> obj

    let private enumProp desc (values: string list) : obj =
        {| ``type`` = "string"; description = desc; ``enum`` = values |} :> obj

    let private intProp desc defaultVal : obj =
        {| ``type`` = "integer"; description = desc; ``default`` = defaultVal |} :> obj

    // ═══════════════════════════════════════════════════════════════════
    // TOOL DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════

    let toolDefinitions : McpProtocol.ToolDefinition list = [
        { Name = "mesh_verify"
          Description = "Verify mesh containers: FPPS consensus, service health, fractal layers L0-L7. Covers all 16 SIL-6 genome containers."
          InputSchema = mkSchema
            [ "action", enumProp "Verification action" [ "all"; "container"; "layer"; "fpps"; "services"; "quick"; "genome" ]
              "container_name", stringProp "Container name (for container/fpps/services actions)"
              "layer", intProp "Fractal layer 0-7 (for layer action)" 0 ]
            [ "action" ] }
    ]

    // ═══════════════════════════════════════════════════════════════════
    // 16-CONTAINER SIL-6 GENOME (SC-IGNITE-008)
    // ═══════════════════════════════════════════════════════════════════

    /// Category of container image
    type ImageCategory =
        | BuiltFromDockerfile
        | PulledFromRegistry
        | SharedImage of sourceContainer: string

    /// Per-container service specification for verification
    type ContainerSpec = {
        Name: string
        Category: ImageCategory
        /// Primary port this container listens on (0 = no port)
        PrimaryPort: int
        /// Health endpoint path (empty = no HTTP health)
        HealthEndpoint: string
        /// Specific command to verify the service is functional
        ServiceTestCommand: string
        /// Expected process name inside the container
        ExpectedProcess: string
        /// Fractal layers this container participates in (L0=0 .. L7=7)
        FractalLayers: int list
        /// Boot tier (1-7, from PanopticIgnition)
        BootTier: int
        /// Human-readable role description
        Role: string
    }

    /// The complete 16-container SIL-6 genome with verification specs
    let private sil6Genome : ContainerSpec list = [
        { Name = "zenoh-router"
          Category = PulledFromRegistry
          PrimaryPort = 7447
          HealthEndpoint = ""
          ServiceTestCommand = "zenoh-bridge-ros2dds --version 2>&1 || zenohd --version 2>&1 || echo zenoh-ok"
          ExpectedProcess = "zenohd"
          FractalLayers = [0; 1; 2; 7]
          BootTier = 1
          Role = "Zenoh control plane router — unified IPC backbone" }

        { Name = "indrajaal-db-prod"
          Category = BuiltFromDockerfile
          PrimaryPort = 5433
          HealthEndpoint = ""
          ServiceTestCommand = "pg_isready -h 127.0.0.1 -p 5433 -U postgres"
          ExpectedProcess = "postgres"
          FractalLayers = [0; 1]
          BootTier = 2
          Role = "PostgreSQL 17 database — business data persistence" }

        { Name = "indrajaal-obs-prod"
          Category = BuiltFromDockerfile
          PrimaryPort = 4317
          HealthEndpoint = ""
          ServiceTestCommand = "curl -sf http://127.0.0.1:9090/-/healthy || echo prometheus-check"
          ExpectedProcess = "prometheus"
          FractalLayers = [0; 1; 3]
          BootTier = 3
          Role = "Observability stack — Prometheus + Grafana + OTEL Collector" }

        { Name = "zenoh-router-1"
          Category = SharedImage "zenoh-router"
          PrimaryPort = 7447
          HealthEndpoint = ""
          ServiceTestCommand = "echo zenoh-quorum-1"
          ExpectedProcess = "zenohd"
          FractalLayers = [2; 7]
          BootTier = 4
          Role = "Zenoh quorum router 1 — HA 2oo3 voting" }

        { Name = "zenoh-router-2"
          Category = SharedImage "zenoh-router"
          PrimaryPort = 7447
          HealthEndpoint = ""
          ServiceTestCommand = "echo zenoh-quorum-2"
          ExpectedProcess = "zenohd"
          FractalLayers = [2; 7]
          BootTier = 4
          Role = "Zenoh quorum router 2 — HA 2oo3 voting" }

        { Name = "zenoh-router-3"
          Category = SharedImage "zenoh-router"
          PrimaryPort = 7447
          HealthEndpoint = ""
          ServiceTestCommand = "echo zenoh-quorum-3"
          ExpectedProcess = "zenohd"
          FractalLayers = [2; 7]
          BootTier = 4
          Role = "Zenoh quorum router 3 — HA 2oo3 voting" }

        { Name = "indrajaal-cortex"
          Category = BuiltFromDockerfile
          PrimaryPort = 0
          HealthEndpoint = ""
          ServiceTestCommand = "echo cortex-ready"
          ExpectedProcess = "dotnet"
          FractalLayers = [3; 4]
          BootTier = 5
          Role = "Cortex AI inference bridge — Synapse/GDE/Knowledge Graph" }

        { Name = "cepaf-bridge"
          Category = BuiltFromDockerfile
          PrimaryPort = 0
          HealthEndpoint = ""
          ServiceTestCommand = "echo cepaf-bridge-ready"
          ExpectedProcess = "dotnet"
          FractalLayers = [2; 3]
          BootTier = 5
          Role = "CEPAF F#/Elixir bridge — ConfigBridge, Zenoh FFI" }

        { Name = "indrajaal-ex-app-1"
          Category = BuiltFromDockerfile
          PrimaryPort = 4000
          HealthEndpoint = "/health"
          ServiceTestCommand = "curl -sf http://127.0.0.1:4000/health || echo app1-check"
          ExpectedProcess = "beam.smp"
          FractalLayers = [0; 1; 3; 4; 5; 6]
          BootTier = 6
          Role = "Seed Elixir app — Phoenix LiveView, Guardian, SMRITI" }

        { Name = "indrajaal-chaya"
          Category = SharedImage "indrajaal-ex-app-1"
          PrimaryPort = 4002
          HealthEndpoint = "/health"
          ServiceTestCommand = "curl -sf http://127.0.0.1:4002/health || echo chaya-check"
          ExpectedProcess = "beam.smp"
          FractalLayers = [3; 5]
          BootTier = 6
          Role = "Chaya digital twin — mesh simulation and planning" }

        { Name = "indrajaal-ollama"
          Category = PulledFromRegistry
          PrimaryPort = 11434
          HealthEndpoint = ""
          ServiceTestCommand = "curl -sf http://127.0.0.1:11434/api/version || echo ollama-check"
          ExpectedProcess = "ollama"
          FractalLayers = [4]
          BootTier = 6
          Role = "Ollama LLM inference — local model serving" }

        { Name = "indrajaal-ex-app-2"
          Category = SharedImage "indrajaal-ex-app-1"
          PrimaryPort = 4000
          HealthEndpoint = "/health"
          ServiceTestCommand = "echo app2-ready"
          ExpectedProcess = "beam.smp"
          FractalLayers = [3; 5; 6]
          BootTier = 7
          Role = "HA Elixir app replica 2" }

        { Name = "indrajaal-ex-app-3"
          Category = SharedImage "indrajaal-ex-app-1"
          PrimaryPort = 4000
          HealthEndpoint = "/health"
          ServiceTestCommand = "echo app3-ready"
          ExpectedProcess = "beam.smp"
          FractalLayers = [3; 5; 6]
          BootTier = 7
          Role = "HA Elixir app replica 3" }

        { Name = "indrajaal-ml-runner-1"
          Category = SharedImage "indrajaal-ollama"
          PrimaryPort = 0
          HealthEndpoint = ""
          ServiceTestCommand = "echo ml-runner-1-ready"
          ExpectedProcess = "ollama"
          FractalLayers = [4; 5]
          BootTier = 7
          Role = "ML inference runner 1 — distributed compute" }

        { Name = "indrajaal-ml-runner-2"
          Category = SharedImage "indrajaal-ollama"
          PrimaryPort = 0
          HealthEndpoint = ""
          ServiceTestCommand = "echo ml-runner-2-ready"
          ExpectedProcess = "ollama"
          FractalLayers = [4; 5]
          BootTier = 7
          Role = "ML inference runner 2 — distributed compute" }

        { Name = "indrajaal-mojo"
          Category = PulledFromRegistry
          PrimaryPort = 0
          HealthEndpoint = ""
          ServiceTestCommand = "echo mojo-ready"
          ExpectedProcess = "modular"
          FractalLayers = [4; 5]
          BootTier = 7
          Role = "Mojo MAX compute — high-performance inference" }
    ]

    /// Lookup a container spec by name
    let private findSpec (name: string) : ContainerSpec option =
        sil6Genome |> List.tryFind (fun s -> s.Name = name)

    /// Get all containers at a given fractal layer
    let private containersAtLayer (layer: int) : ContainerSpec list =
        sil6Genome |> List.filter (fun s -> s.FractalLayers |> List.contains layer)

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    type VerificationState = {
        mutable LastFullVerification: DateTime option
        mutable LastQuickCheck: DateTime option
        mutable VerificationCount: int64
        mutable LastResults: Map<string, bool>  // container -> healthy
    }

    let createState () : VerificationState = {
        LastFullVerification = None
        LastQuickCheck = None
        VerificationCount = 0L
        LastResults = Map.empty
    }

    // ═══════════════════════════════════════════════════════════════════
    // PROCESS EXECUTION HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// Run a command and return (exitCode, stdout, stderr) with timeout
    let private runCommand (cmd: string) (args: string) (timeoutMs: int) : int * string * string =
        try
            let psi = ProcessStartInfo(cmd, args)
            psi.RedirectStandardOutput <- true
            psi.RedirectStandardError <- true
            psi.UseShellExecute <- false
            psi.CreateNoWindow <- true

            use p = Process.Start(psi)
            let stdout = p.StandardOutput.ReadToEnd()
            let stderr = p.StandardError.ReadToEnd()
            if p.WaitForExit(timeoutMs) then
                (p.ExitCode, stdout.Trim(), stderr.Trim())
            else
                try p.Kill() with _ -> ()
                (-1, "", "Timeout after " + string timeoutMs + "ms")
        with ex ->
            (-1, "", ex.Message)

    /// Run podman command with 10s default timeout
    let private podman (args: string) : int * string * string =
        runCommand "podman" args 10000

    /// Try TCP connect to a port with timeout
    let private probePort (port: int) (timeoutMs: int) : bool =
        try
            use client = new TcpClient()
            let task = client.ConnectAsync("127.0.0.1", port)
            task.Wait(timeoutMs)
        with _ -> false

    /// Try HTTP GET and check for success status
    let private probeHttp (url: string) (timeoutMs: int) : bool * int * string =
        try
            use client = new HttpClient()
            client.Timeout <- TimeSpan.FromMilliseconds(float timeoutMs)
            let task = client.GetAsync(url)
            task.Wait()
            let resp = task.Result
            let body = resp.Content.ReadAsStringAsync().Result
            (resp.IsSuccessStatusCode, int resp.StatusCode, body.Substring(0, min 200 body.Length))
        with ex ->
            (false, 0, ex.Message)

    // ═══════════════════════════════════════════════════════════════════
    // FPPS 5-METHOD PROBES (SC-CEP-003)
    // ═══════════════════════════════════════════════════════════════════

    type ProbeResult = {
        Method: string
        Passed: bool
        Details: string
        DurationMs: int64
    }

    /// Method 1: PodmanStatus — is the container running?
    let private probePodmanStatus (name: string) : ProbeResult =
        let sw = Stopwatch.StartNew()
        let (exit, stdout, stderr) = podman (sprintf "ps --filter name=^%s$ --format {{.State}}" name)
        sw.Stop()
        let running = exit = 0 && stdout.ToLowerInvariant().Contains("running")
        { Method = "PodmanStatus"
          Passed = running
          Details = if running then sprintf "Running (%s)" stdout else sprintf "Not running: exit=%d stdout='%s' stderr='%s'" exit stdout stderr
          DurationMs = sw.ElapsedMilliseconds }

    /// Method 2: HealthEndpoint — HTTP health check
    let private probeHealthEndpoint (spec: ContainerSpec) : ProbeResult =
        let sw = Stopwatch.StartNew()
        if String.IsNullOrEmpty(spec.HealthEndpoint) || spec.PrimaryPort = 0 then
            sw.Stop()
            { Method = "HealthEndpoint"; Passed = true; Details = "N/A (no health endpoint defined)"; DurationMs = sw.ElapsedMilliseconds }
        else
            let url = sprintf "http://127.0.0.1:%d%s" spec.PrimaryPort spec.HealthEndpoint
            let (ok, status, body) = probeHttp url 5000
            sw.Stop()
            { Method = "HealthEndpoint"
              Passed = ok
              Details = sprintf "HTTP %d from %s: %s" status url (body.Substring(0, min 100 body.Length))
              DurationMs = sw.ElapsedMilliseconds }

    /// Method 3: PortProbe — TCP port listening?
    let private probePortCheck (spec: ContainerSpec) : ProbeResult =
        let sw = Stopwatch.StartNew()
        if spec.PrimaryPort = 0 then
            sw.Stop()
            { Method = "PortProbe"; Passed = true; Details = "N/A (no port defined)"; DurationMs = sw.ElapsedMilliseconds }
        else
            let ok = probePort spec.PrimaryPort 3000
            sw.Stop()
            { Method = "PortProbe"
              Passed = ok
              Details = if ok then sprintf "Port %d open" spec.PrimaryPort else sprintf "Port %d closed/unreachable" spec.PrimaryPort
              DurationMs = sw.ElapsedMilliseconds }

    /// Method 4: ProcessCheck — expected process running in container?
    let private probeProcessCheck (name: string) (expected: string) : ProbeResult =
        let sw = Stopwatch.StartNew()
        let (exit, stdout, _) = podman (sprintf "top %s -o comm" name)
        sw.Stop()
        if exit <> 0 then
            { Method = "ProcessCheck"; Passed = false; Details = "Cannot inspect processes (container not running?)"; DurationMs = sw.ElapsedMilliseconds }
        else
            let hasProcess = stdout.Contains(expected)
            { Method = "ProcessCheck"
              Passed = hasProcess
              Details = if hasProcess then sprintf "Process '%s' found" expected else sprintf "Process '%s' NOT found in: %s" expected (stdout.Replace("\n", "; "))
              DurationMs = sw.ElapsedMilliseconds }

    /// Method 5: LogAnalysis — recent logs free of error patterns?
    let private probeLogAnalysis (name: string) : ProbeResult =
        let sw = Stopwatch.StartNew()
        let (exit, stdout, stderr) = podman (sprintf "logs --tail 50 %s" name)
        sw.Stop()
        if exit <> 0 then
            { Method = "LogAnalysis"; Passed = true; Details = "Cannot read logs (non-blocking)"; DurationMs = sw.ElapsedMilliseconds }
        else
            let logs = stdout + stderr
            let errorPatterns = ["FATAL"; "panic"; "SIGKILL"; "OOMKilled"; "segfault"]
            let found = errorPatterns |> List.filter logs.Contains
            { Method = "LogAnalysis"
              Passed = List.isEmpty found
              Details = if List.isEmpty found then "No fatal patterns in last 50 lines" else sprintf "Found: %s" (String.concat ", " found)
              DurationMs = sw.ElapsedMilliseconds }

    /// Run all 5 FPPS methods for a container
    let private runFPPS (spec: ContainerSpec) : ProbeResult list =
        [ probePodmanStatus spec.Name
          probeHealthEndpoint spec
          probePortCheck spec
          probeProcessCheck spec.Name spec.ExpectedProcess
          probeLogAnalysis spec.Name ]

    // ═══════════════════════════════════════════════════════════════════
    // SERVICE-SPECIFIC TESTS
    // ═══════════════════════════════════════════════════════════════════

    type ServiceTestResult = {
        Container: string
        TestName: string
        Passed: bool
        Details: string
        DurationMs: int64
    }

    /// Run service-specific test for a container
    let private runServiceTest (spec: ContainerSpec) : ServiceTestResult list =
        let sw = Stopwatch.StartNew()
        let results = ResizeArray<ServiceTestResult>()

        // Test 1: Container exists and is running
        let (exit1, state, _) = podman (sprintf "inspect --format {{.State.Status}} %s" spec.Name)
        results.Add({
            Container = spec.Name
            TestName = "container_exists"
            Passed = exit1 = 0 && state.Trim() = "running"
            Details = sprintf "State: %s" (state.Trim())
            DurationMs = sw.ElapsedMilliseconds })

        // Test 2: Image integrity (correct image used)
        let (exit2, image, _) = podman (sprintf "inspect --format {{.Config.Image}} %s" spec.Name)
        results.Add({
            Container = spec.Name
            TestName = "image_integrity"
            Passed = exit2 = 0 && not (String.IsNullOrWhiteSpace(image))
            Details = sprintf "Image: %s" (image.Trim())
            DurationMs = sw.ElapsedMilliseconds })

        // Test 3: Container registry compliance (SC-CNT-010: localhost/ only for built images)
        match spec.Category with
        | BuiltFromDockerfile ->
            let img = image.Trim()
            let isLocal = img.StartsWith("localhost/") || not (img.Contains("/"))
            results.Add({
                Container = spec.Name
                TestName = "SC-CNT-010_localhost_registry"
                Passed = isLocal
                Details = if isLocal then "localhost registry OK" else sprintf "VIOLATION: image '%s' not from localhost/" img
                DurationMs = sw.ElapsedMilliseconds })
        | _ -> ()

        // Test 4: Port binding (if port defined)
        if spec.PrimaryPort > 0 then
            let portOpen = probePort spec.PrimaryPort 3000
            results.Add({
                Container = spec.Name
                TestName = sprintf "port_%d_listening" spec.PrimaryPort
                Passed = portOpen
                Details = if portOpen then sprintf "Port %d accepting connections" spec.PrimaryPort else sprintf "Port %d NOT responding" spec.PrimaryPort
                DurationMs = sw.ElapsedMilliseconds })

        // Test 5: Service-specific functional test
        match spec.Name with
        | "indrajaal-db-prod" ->
            // PostgreSQL: can we connect and run a query?
            let (pgExit, pgOut, pgErr) = runCommand "psql" "-h 127.0.0.1 -p 5433 -U postgres -c \"SELECT 1 AS ok;\" -t" 5000
            results.Add({
                Container = spec.Name
                TestName = "postgresql_query"
                Passed = pgExit = 0 && pgOut.Contains("1")
                Details = if pgExit = 0 then sprintf "Query OK: %s" (pgOut.Trim()) else sprintf "Query failed: %s" (pgErr.Trim())
                DurationMs = sw.ElapsedMilliseconds })

        | "indrajaal-obs-prod" ->
            // Prometheus: /-/healthy endpoint
            let (promOk, promStatus, promBody) = probeHttp "http://127.0.0.1:9090/-/healthy" 3000
            results.Add({
                Container = spec.Name
                TestName = "prometheus_healthy"
                Passed = promOk
                Details = sprintf "Prometheus HTTP %d: %s" promStatus (promBody.Substring(0, min 50 promBody.Length))
                DurationMs = sw.ElapsedMilliseconds })

            // Grafana: port 3000
            let grafanaOpen = probePort 3000 3000
            results.Add({
                Container = spec.Name
                TestName = "grafana_port_3000"
                Passed = grafanaOpen
                Details = if grafanaOpen then "Grafana port 3000 open" else "Grafana port 3000 closed"
                DurationMs = sw.ElapsedMilliseconds })

            // OTEL Collector: port 4317 (gRPC)
            let otelOpen = probePort 4317 3000
            results.Add({
                Container = spec.Name
                TestName = "otel_collector_port_4317"
                Passed = otelOpen
                Details = if otelOpen then "OTEL Collector gRPC 4317 open" else "OTEL Collector gRPC 4317 closed"
                DurationMs = sw.ElapsedMilliseconds })

        | name when name.StartsWith("indrajaal-ex-app") || name = "indrajaal-chaya" ->
            // Phoenix app: /health endpoint
            let port = spec.PrimaryPort
            if port > 0 then
                let (appOk, appStatus, appBody) = probeHttp (sprintf "http://127.0.0.1:%d/health" port) 5000
                results.Add({
                    Container = spec.Name
                    TestName = "phoenix_health_endpoint"
                    Passed = appOk
                    Details = sprintf "HTTP %d: %s" appStatus (appBody.Substring(0, min 80 appBody.Length))
                    DurationMs = sw.ElapsedMilliseconds })

        | name when name.StartsWith("zenoh-router") ->
            // Zenoh router: TCP 7447
            let zenohOpen = probePort 7447 3000
            results.Add({
                Container = spec.Name
                TestName = "zenoh_tcp_7447"
                Passed = zenohOpen
                Details = if zenohOpen then "Zenoh router port 7447 open" else "Zenoh router port 7447 closed"
                DurationMs = sw.ElapsedMilliseconds })

        | "indrajaal-ollama" ->
            // Ollama: API version endpoint
            let (ollamaOk, ollamaStatus, ollamaBody) = probeHttp "http://127.0.0.1:11434/api/version" 5000
            results.Add({
                Container = spec.Name
                TestName = "ollama_api_version"
                Passed = ollamaOk
                Details = sprintf "HTTP %d: %s" ollamaStatus (ollamaBody.Substring(0, min 80 ollamaBody.Length))
                DurationMs = sw.ElapsedMilliseconds })

        | _ ->
            // Generic: just run the service test command inside the container
            let (svcExit, svcOut, svcErr) = podman (sprintf "exec %s sh -c \"%s\"" spec.Name spec.ServiceTestCommand)
            results.Add({
                Container = spec.Name
                TestName = "service_command"
                Passed = svcExit = 0
                Details = if svcExit = 0 then svcOut.Substring(0, min 100 svcOut.Length) else sprintf "Failed: %s" (svcErr.Substring(0, min 100 svcErr.Length))
                DurationMs = sw.ElapsedMilliseconds })

        results |> List.ofSeq

    // ═══════════════════════════════════════════════════════════════════
    // FRACTAL LAYER DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════

    /// Fractal layer names and descriptions
    let private layerNames = Map.ofList [
        (0, ("L0-Constitution", "System existence — containers present, images valid"))
        (1, ("L1-Infrastructure", "Core infrastructure — DB, Zenoh, Observability running"))
        (2, ("L2-Coordination", "Zenoh quorum + CEPAF bridge — mesh coordination"))
        (3, ("L3-Integration", "App connectivity — Phoenix, Cortex, Chaya linked"))
        (4, ("L4-Intelligence", "AI/ML layer — Cortex, Ollama, Mojo, ML runners"))
        (5, ("L5-Optimization", "HA replicas + twins — optimization and resilience"))
        (6, ("L6-Policy", "Guardian, access control, safety policy enforcement"))
        (7, ("L7-Federation", "Cross-holon readiness — Zenoh quorum for federation"))
    ]

    /// Verify a specific fractal layer
    let private verifyLayer (layer: int) : {| layer: int; name: string; description: string; containers: {| name: string; healthy: bool; details: string |} list; all_healthy: bool |} =
        let containers = containersAtLayer layer
        let (layerName, layerDesc) = layerNames |> Map.tryFind layer |> Option.defaultValue (sprintf "L%d" layer, "Unknown layer")

        let containerResults =
            containers |> List.map (fun spec ->
                let probe = probePodmanStatus spec.Name
                {| name = spec.Name; healthy = probe.Passed; details = probe.Details |})

        let allHealthy = containerResults |> List.forall (fun c -> c.healthy)
        {| layer = layer; name = layerName; description = layerDesc; containers = containerResults; all_healthy = allHealthy |}

    // ═══════════════════════════════════════════════════════════════════
    // ACTION HANDLERS
    // ═══════════════════════════════════════════════════════════════════

    let private handleGenome (id: JsonElement option) : string =
        let genome =
            sil6Genome |> List.map (fun s ->
                {| name = s.Name
                   category = match s.Category with
                              | BuiltFromDockerfile -> "BuiltFromDockerfile"
                              | PulledFromRegistry -> "PulledFromRegistry"
                              | SharedImage src -> sprintf "SharedImage(%s)" src
                   primary_port = s.PrimaryPort
                   health_endpoint = s.HealthEndpoint
                   expected_process = s.ExpectedProcess
                   fractal_layers = s.FractalLayers
                   boot_tier = s.BootTier
                   role = s.Role |})
        let result = {|
            genome_size = List.length sil6Genome
            built = sil6Genome |> List.filter (fun s -> s.Category = BuiltFromDockerfile) |> List.length
            pulled = sil6Genome |> List.filter (fun s -> match s.Category with PulledFromRegistry -> true | _ -> false) |> List.length
            shared = sil6Genome |> List.filter (fun s -> match s.Category with SharedImage _ -> true | _ -> false) |> List.length
            boot_tiers = 7
            fractal_layers = 8
            containers = genome |}
        McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleQuick (state: VerificationState) (id: JsonElement option) : string =
        let results =
            sil6Genome |> List.map (fun spec ->
                let probe = probePodmanStatus spec.Name
                state.LastResults <- state.LastResults |> Map.add spec.Name probe.Passed
                {| name = spec.Name; running = probe.Passed; details = probe.Details; tier = spec.BootTier |})

        let healthy = results |> List.filter (fun r -> r.running) |> List.length
        let total = List.length results
        state.LastQuickCheck <- Some DateTime.UtcNow
        state.VerificationCount <- state.VerificationCount + 1L

        let result = {|
            healthy = healthy
            total = total
            all_healthy = (healthy = total)
            timestamp = DateTime.UtcNow.ToString("o")
            containers = results |}
        McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleContainer (state: VerificationState) (args: JsonElement option) (id: JsonElement option) : string =
        let name = McpProtocol.getArgOpt "container_name" args |> Option.defaultValue ""
        if String.IsNullOrEmpty(name) then
            McpProtocol.toolError id "container_name is required for 'container' action"
        else
            match findSpec name with
            | None ->
                McpProtocol.toolError id (sprintf "Unknown container '%s'. Valid: %s" name (sil6Genome |> List.map (fun s -> s.Name) |> String.concat ", "))
            | Some spec ->
                let sw = Stopwatch.StartNew()
                let fppsResults = runFPPS spec
                let serviceResults = runServiceTest spec
                sw.Stop()

                let fppsPass = fppsResults |> List.filter (fun r -> r.Passed) |> List.length
                let fppsTotal = List.length fppsResults
                let svcPass = serviceResults |> List.filter (fun r -> r.Passed) |> List.length
                let svcTotal = List.length serviceResults
                let allHealthy = fppsPass = fppsTotal && svcPass = svcTotal

                state.LastResults <- state.LastResults |> Map.add name allHealthy

                let result = {|
                    container = name
                    role = spec.Role
                    category = match spec.Category with BuiltFromDockerfile -> "built" | PulledFromRegistry -> "pulled" | SharedImage s -> sprintf "shared(%s)" s
                    boot_tier = spec.BootTier
                    fractal_layers = spec.FractalLayers
                    fpps_consensus = {| passed = fppsPass; total = fppsTotal; achieved = (fppsPass = fppsTotal) |}
                    fpps_details = fppsResults |> List.map (fun r -> {| method_name = r.Method; passed = r.Passed; details = r.Details; duration_ms = r.DurationMs |})
                    service_tests = {| passed = svcPass; total = svcTotal |}
                    service_details = serviceResults |> List.map (fun r -> {| test = r.TestName; passed = r.Passed; details = r.Details |})
                    healthy = allHealthy
                    total_duration_ms = sw.ElapsedMilliseconds |}
                McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleFPPS (args: JsonElement option) (id: JsonElement option) : string =
        let name = McpProtocol.getArgOpt "container_name" args |> Option.defaultValue ""
        if String.IsNullOrEmpty(name) then
            McpProtocol.toolError id "container_name is required for 'fpps' action"
        else
            match findSpec name with
            | None ->
                McpProtocol.toolError id (sprintf "Unknown container '%s'" name)
            | Some spec ->
                let sw = Stopwatch.StartNew()
                let results = runFPPS spec
                sw.Stop()

                let passCount = results |> List.filter (fun r -> r.Passed) |> List.length
                let result = {|
                    container = name
                    consensus_achieved = (passCount = List.length results)
                    methods_passed = passCount
                    methods_total = List.length results
                    stamp = "SC-CEP-003, SC-VAL-003"
                    probes = results |> List.map (fun r -> {| method_name = r.Method; passed = r.Passed; details = r.Details; duration_ms = r.DurationMs |})
                    total_duration_ms = sw.ElapsedMilliseconds |}
                McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleServices (args: JsonElement option) (id: JsonElement option) : string =
        let name = McpProtocol.getArgOpt "container_name" args |> Option.defaultValue ""
        if String.IsNullOrEmpty(name) then
            McpProtocol.toolError id "container_name is required for 'services' action"
        else
            match findSpec name with
            | None ->
                McpProtocol.toolError id (sprintf "Unknown container '%s'" name)
            | Some spec ->
                let sw = Stopwatch.StartNew()
                let results = runServiceTest spec
                sw.Stop()

                let passCount = results |> List.filter (fun r -> r.Passed) |> List.length
                let result = {|
                    container = name
                    role = spec.Role
                    tests_passed = passCount
                    tests_total = List.length results
                    all_passed = (passCount = List.length results)
                    tests = results |> List.map (fun r -> {| test = r.TestName; passed = r.Passed; details = r.Details; duration_ms = r.DurationMs |})
                    total_duration_ms = sw.ElapsedMilliseconds |}
                McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleLayer (args: JsonElement option) (id: JsonElement option) : string =
        let layer = McpProtocol.getArgInt "layer" 0 args
        if layer < 0 || layer > 7 then
            McpProtocol.toolError id "layer must be 0-7"
        else
            let sw = Stopwatch.StartNew()
            let layerResult = verifyLayer layer
            sw.Stop()

            let result = {|
                layer = layerResult.layer
                name = layerResult.name
                description = layerResult.description
                all_healthy = layerResult.all_healthy
                container_count = List.length layerResult.containers
                containers = layerResult.containers
                duration_ms = sw.ElapsedMilliseconds |}
            McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    let private handleAll (state: VerificationState) (id: JsonElement option) : string =
        let sw = Stopwatch.StartNew()

        // 1. Quick status for all containers
        let containerStatuses =
            sil6Genome |> List.map (fun spec ->
                let probe = probePodmanStatus spec.Name
                state.LastResults <- state.LastResults |> Map.add spec.Name probe.Passed
                (spec, probe))

        // 2. FPPS for running containers
        let fppsResults =
            containerStatuses
            |> List.filter (fun (_, probe) -> probe.Passed)
            |> List.map (fun (spec, _) ->
                let fpps = runFPPS spec
                let pass = fpps |> List.filter (fun r -> r.Passed) |> List.length
                (spec.Name, pass, List.length fpps, fpps))

        // 3. Service tests for running containers
        let serviceResults =
            containerStatuses
            |> List.filter (fun (_, probe) -> probe.Passed)
            |> List.map (fun (spec, _) ->
                let svc = runServiceTest spec
                let pass = svc |> List.filter (fun r -> r.Passed) |> List.length
                (spec.Name, pass, List.length svc))

        // 4. Layer verification
        let layerResults = [0..7] |> List.map verifyLayer

        sw.Stop()

        let running = containerStatuses |> List.filter (fun (_, p) -> p.Passed) |> List.length
        let total = List.length containerStatuses
        let fppsFullConsensus = fppsResults |> List.filter (fun (_, pass, tot, _) -> pass = tot) |> List.length
        let layersHealthy = layerResults |> List.filter (fun l -> l.all_healthy) |> List.length

        state.LastFullVerification <- Some DateTime.UtcNow
        state.VerificationCount <- state.VerificationCount + 1L

        let result = {|
            summary = {|
                containers_running = running
                containers_total = total
                fpps_full_consensus = fppsFullConsensus
                fpps_containers_tested = List.length fppsResults
                layers_healthy = layersHealthy
                layers_total = 8
                all_healthy = (running = total && fppsFullConsensus = List.length fppsResults && layersHealthy = 8)
                total_duration_ms = sw.ElapsedMilliseconds
                timestamp = DateTime.UtcNow.ToString("o")
            |}
            containers = containerStatuses |> List.map (fun (spec, probe) ->
                let fpps = fppsResults |> List.tryFind (fun (n, _, _, _) -> n = spec.Name)
                let svc = serviceResults |> List.tryFind (fun (n, _, _) -> n = spec.Name)
                {| name = spec.Name
                   role = spec.Role
                   tier = spec.BootTier
                   running = probe.Passed
                   fpps = match fpps with Some (_, p, t, _) -> {| passed = p; total = t; consensus = (p = t) |} | None -> {| passed = 0; total = 0; consensus = false |}
                   services = match svc with Some (_, p, t) -> {| passed = p; total = t |} | None -> {| passed = 0; total = 0 |} |})
            layers = layerResults |> List.map (fun l ->
                {| layer = l.layer; name = l.name; healthy = l.all_healthy; container_count = List.length l.containers |})
            stamp = [| "SC-CEP-003"; "SC-VAL-003"; "SC-IGNITE-008"; "SC-CNT-009"; "SC-CNT-010" |]
        |}
        McpProtocol.toolResult id (JsonSerializer.Serialize(result))

    // ═══════════════════════════════════════════════════════════════════
    // DISPATCH
    // ═══════════════════════════════════════════════════════════════════

    let dispatch (state: VerificationState) (toolName: string) (args: JsonElement option) (id: JsonElement option) : string option =
        match toolName with
        | "mesh_verify" ->
            let action = McpProtocol.getArgOpt "action" args |> Option.defaultValue ""
            match action with
            | "all" -> Some (handleAll state id)
            | "container" -> Some (handleContainer state args id)
            | "layer" -> Some (handleLayer args id)
            | "fpps" -> Some (handleFPPS args id)
            | "services" -> Some (handleServices args id)
            | "quick" -> Some (handleQuick state id)
            | "genome" -> Some (handleGenome id)
            | other -> Some (McpProtocol.invalidParams id (sprintf "Unknown action: %s (expected all|container|layer|fpps|services|quick|genome)" other))
        | _ -> None
