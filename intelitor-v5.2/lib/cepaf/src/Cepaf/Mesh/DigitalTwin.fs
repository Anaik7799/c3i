// =============================================================================
// DigitalTwin.fs - SIL-4 Compliant Mesh State Management
// =============================================================================
// STAMP: SC-CLU-002, SC-SIL4-001, SC-SIL4-004, SC-SIL4-005, SC-HOLON-001
// AOR: AOR-SIL4-001, AOR-SIL4-005, AOR-HOLON-001 to AOR-HOLON-020
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-04 |
// | Author | Cybernetic Architect |
// | Reference | SIL4_MESH_TUI_IMPLEMENTATION_PLAN.md |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.IO
open System.Collections.Generic
open System.Security.Cryptography
open System.Text
open System.Text.Json
open System.Text.Json.Serialization

/// <summary>
/// Container health status for the digital twin
/// </summary>
type ContainerHealth =
    | Unknown
    | Starting
    | Healthy
    | Unhealthy
    | Lameduck
    | Stopping
    | Stopped
    | Failed of reason: string

/// <summary>
/// Container role in the mesh topology
/// </summary>
type ContainerRole =
    | Primary       // Database primary
    | Seed          // Application seed node
    | Satellite     // Application replica
    | Controller    // Observability/control plane
    | Worker        // FLAME/background worker

/// <summary>
/// Startup phase for tracking boot sequence
/// </summary>
type StartupPhase =
    | NotStarted
    | Preflight
    | PortScour
    | DependencyCheck
    | Booting
    | HealthCheck
    | Ready
    | FailedStartup of reason: string

/// <summary>
/// Shutdown phase for tracking graceful termination
/// </summary>
type ShutdownPhase =
    | Running
    | PreShutdown of timeoutAt: DateTimeOffset
    | Draining of activeConnections: int * timeoutAt: DateTimeOffset
    | Stopping of timeoutAt: DateTimeOffset
    | Killing
    | Terminated of exitCode: int

/// <summary>
/// HolonGenotype - Static configuration (immutable)
/// Represents the "DNA" of a container in the mesh
/// </summary>
[<CLIMutable>]
type HolonGenotype = {
    /// Unique identifier for this holon type
    [<JsonPropertyName("id")>]
    Id: string

    /// Human-readable name
    [<JsonPropertyName("name")>]
    Name: string

    /// Role in the mesh
    [<JsonPropertyName("role")>]
    Role: ContainerRole

    /// Podman image to use
    [<JsonPropertyName("image")>]
    Image: string

    /// Port mappings (host:container)
    [<JsonPropertyName("ports")>]
    Ports: (int * int) list

    /// Environment variables
    [<JsonPropertyName("environment")>]
    Environment: Map<string, string>

    /// Dependencies (must start before this)
    [<JsonPropertyName("after")>]
    After: string list

    /// Required dependencies (hard requirement)
    [<JsonPropertyName("requires")>]
    Requires: string list

    /// Optional dependencies (soft requirement)
    [<JsonPropertyName("wants")>]
    Wants: string list

    /// Health check command
    [<JsonPropertyName("healthCheck")>]
    HealthCheck: string option

    /// Health check interval in milliseconds
    [<JsonPropertyName("healthInterval")>]
    HealthIntervalMs: int

    /// Memory limit in MB
    [<JsonPropertyName("memoryMb")>]
    MemoryMB: int

    /// CPU limit (fractional)
    [<JsonPropertyName("cpuLimit")>]
    CPULimit: float

    /// Network name
    [<JsonPropertyName("network")>]
    Network: string

    /// Static IP address
    [<JsonPropertyName("ipAddress")>]
    IPAddress: string option

    /// Start delay (for jitter)
    [<JsonPropertyName("startDelayMs")>]
    StartDelayMs: int

    /// Max jitter in milliseconds
    [<JsonPropertyName("maxJitterMs")>]
    MaxJitterMs: int
}

/// <summary>
/// HolonPhenotype - Runtime state (mutable)
/// Represents the current "expression" of the holon
/// </summary>
type HolonPhenotype = {
    /// Genotype reference
    GenotypeId: string

    /// Container ID from Podman
    ContainerId: string option

    /// Process ID inside container
    Pid: int option

    /// Current health status
    Health: ContainerHealth

    /// Current startup phase
    StartupPhase: StartupPhase

    /// Current shutdown phase
    ShutdownPhase: ShutdownPhase

    /// Diagnostic coverage percentage
    DiagnosticCoverage: float

    /// Proof token for PROMETHEUS verification
    ProofToken: string

    /// Start timestamp
    StartedAt: DateTimeOffset option

    /// Last health check timestamp
    LastHealthCheck: DateTimeOffset option

    /// Last heartbeat received
    LastHeartbeat: DateTimeOffset option

    /// Active connection count (for draining)
    ActiveConnections: int

    /// Error messages
    Errors: string list

    /// Custom metrics
    Metrics: Map<string, float>
}

/// <summary>
/// Startup wave for parallel boot
/// </summary>
type StartupWave = {
    /// Wave number (0 = first)
    Order: int

    /// Holons in this wave (can start in parallel)
    Holons: string list

    /// Maximum parallelism
    MaxParallel: int
}

/// <summary>
/// Topology cache for validated startup order
/// SC-SIL4-005: DAG validated on boot
/// </summary>
type TopologyCache = {
    /// Cache version
    Version: string

    /// SHA256 hash of genotype configuration
    ConfigHash: string

    /// Computed startup waves
    StartOrder: StartupWave list

    /// Computed shutdown order (reverse of startup)
    ShutdownOrder: StartupWave list

    /// Timestamp of cache creation
    CreatedAt: DateTimeOffset

    /// Timestamp of last validation
    ValidatedAt: DateTimeOffset option

    /// Is cache valid
    IsValid: bool
}

/// <summary>
/// State checkpoint for dying gasp recovery
/// SC-SIL4-004: Checkpoint on shutdown
/// </summary>
type StateCheckpoint = {
    /// Checkpoint ID
    Id: string

    /// Timestamp
    Timestamp: DateTimeOffset

    /// SHA256 hash of state
    StateHash: string

    /// All holon states
    Holons: Map<string, HolonPhenotype>

    /// Active operation IDs
    ActiveOperations: string list

    /// Pending writes
    PendingWrites: (string * byte[]) list

    /// Reason for checkpoint
    Reason: string
}

/// <summary>
/// Digital Twin - Full mesh state manager
/// </summary>
type DigitalTwin = {
    /// All genotypes (static config)
    Genotypes: Map<string, HolonGenotype>

    /// All phenotypes (runtime state)
    mutable Phenotypes: Map<string, HolonPhenotype>

    /// Topology cache
    mutable Cache: TopologyCache option

    /// Last checkpoint
    mutable LastCheckpoint: StateCheckpoint option

    /// Mesh version
    Version: string

    /// Created timestamp
    CreatedAt: DateTimeOffset
}

/// <summary>
/// DigitalTwin operations module
/// </summary>
module DigitalTwin =

    /// Default proof token value
    let private unverifiedToken = "UNVERIFIED"

    /// Compute SHA256 hash of string
    let private computeHash (input: string) : string =
        use sha256 = SHA256.Create()
        let bytes = Encoding.UTF8.GetBytes(input)
        let hash = sha256.ComputeHash(bytes)
        Convert.ToHexString(hash).ToLowerInvariant()

    /// Create initial phenotype for genotype
    let private createPhenotype (genotype: HolonGenotype) : HolonPhenotype =
        {
            GenotypeId = genotype.Id
            ContainerId = None
            Pid = None
            Health = Unknown
            StartupPhase = NotStarted
            ShutdownPhase = Running
            DiagnosticCoverage = 0.0
            ProofToken = unverifiedToken
            StartedAt = None
            LastHealthCheck = None
            LastHeartbeat = None
            ActiveConnections = 0
            Errors = []
            Metrics = Map.empty
        }

    /// Create SIL-6 Full Mesh genotypes (15 containers, biomorphic fractal mesh)
    /// Tier 0: Data (DB), Tier 1: Observability, Tier 2: Mesh Control (Zenoh 2oo3),
    /// Tier 3: Cognitive (Bridge + Cortex), Tier 4: App HA Cluster (3 nodes),
    /// Tier 5: Digital Twin (Chaya), Tier 6: ML Satellites (FLAME runners)
    let private createSIL6Genotypes () : Map<string, HolonGenotype> =
        let sil6Network = "indrajaal-sil6-mesh"

        // Tier 0: Data Layer
        let db = {
            Id = "indrajaal-db-prod"; Name = "indrajaal-db-prod"
            Role = Primary; Image = "localhost/indrajaal-db:latest"
            Ports = [(5433, 5432)]
            Environment = Map.ofList [ ("POSTGRES_DB", "indrajaal_prod") ]
            After = []; Requires = []; Wants = []
            HealthCheck = Some "pg_isready -p 5433 -U postgres"
            HealthIntervalMs = 5000; MemoryMB = 4096; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.20"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        // Tier 1: Observability
        let obs = {
            Id = "indrajaal-obs-prod"; Name = "indrajaal-obs-prod"
            Role = Controller; Image = "localhost/indrajaal-obs:latest"
            Ports = [(4317, 4317); (4318, 4318); (9090, 9090); (3000, 3000); (3100, 3100)]
            Environment = Map.empty
            After = []; Requires = []; Wants = []
            HealthCheck = Some "curl -sf http://localhost:9090/-/healthy"
            HealthIntervalMs = 10000; MemoryMB = 4096; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.30"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        // Tier 2: Zenoh 2oo3 Quorum (3 routers + proxy)
        let zenoh1 = {
            Id = "zenoh-router-1"; Name = "zenoh-router-1"
            Role = Controller; Image = "eclipse/zenoh:latest"
            Ports = [(7447, 7447); (8000, 8000)]
            Environment = Map.empty
            After = []; Requires = []; Wants = []
            HealthCheck = Some "nc -z localhost 8000"
            HealthIntervalMs = 10000; MemoryMB = 512; CPULimit = 1.0
            Network = sil6Network; IPAddress = Some "172.28.0.40"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let zenoh2 = {
            Id = "zenoh-router-2"; Name = "zenoh-router-2"
            Role = Controller; Image = "eclipse/zenoh:latest"
            Ports = [(7448, 7447); (8001, 8000)]
            Environment = Map.empty
            After = []; Requires = []; Wants = []
            HealthCheck = Some "nc -z localhost 8000"
            HealthIntervalMs = 10000; MemoryMB = 512; CPULimit = 1.0
            Network = sil6Network; IPAddress = Some "172.28.0.41"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let zenoh3 = {
            Id = "zenoh-router-3"; Name = "zenoh-router-3"
            Role = Controller; Image = "eclipse/zenoh:latest"
            Ports = [(7449, 7447); (8002, 8000)]
            Environment = Map.empty
            After = []; Requires = []; Wants = []
            HealthCheck = Some "nc -z localhost 8000"
            HealthIntervalMs = 10000; MemoryMB = 512; CPULimit = 1.0
            Network = sil6Network; IPAddress = Some "172.28.0.42"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let zenohProxy = {
            Id = "zenoh-router"; Name = "zenoh-router"
            Role = Controller; Image = "eclipse/zenoh:latest"
            Ports = []
            Environment = Map.empty
            After = ["zenoh-router-1"; "zenoh-router-2"; "zenoh-router-3"]
            Requires = ["zenoh-router-1"; "zenoh-router-2"; "zenoh-router-3"]; Wants = []
            HealthCheck = Some "nc -z localhost 8000"
            HealthIntervalMs = 10000; MemoryMB = 512; CPULimit = 1.0
            Network = sil6Network; IPAddress = Some "172.28.0.43"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        // Tier 3: Cognitive Plane
        let bridge = {
            Id = "cepaf-bridge"; Name = "cepaf-bridge"
            Role = Controller; Image = "localhost/cepaf-bridge:latest"
            Ports = [(9876, 9876)]
            Environment = Map.ofList [
                ("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router:7447")
                ("PODMAN_SOCKET", "/run/user/1000/podman/podman.sock")
            ]
            After = ["zenoh-router"]; Requires = ["zenoh-router"]; Wants = []
            HealthCheck = Some "pgrep -f cepaf-bridge"
            HealthIntervalMs = 15000; MemoryMB = 1024; CPULimit = 1.0
            Network = sil6Network; IPAddress = Some "172.28.0.50"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let cortex = {
            Id = "indrajaal-cortex"; Name = "indrajaal-cortex"
            Role = Controller; Image = "localhost/indrajaal-cortex:latest"
            Ports = [(9877, 9877)]
            Environment = Map.ofList [
                ("CORTEX_PORT", "9877")
                ("ZENOH_ROUTER_ENDPOINT", "tcp/zenoh-router:7447")
                ("CEPAF_BRIDGE_URL", "http://cepaf-bridge:9876")
            ]
            After = ["zenoh-router"; "cepaf-bridge"]
            Requires = ["zenoh-router"]; Wants = ["cepaf-bridge"]
            HealthCheck = Some "curl -sf http://localhost:9877/health"
            HealthIntervalMs = 15000; MemoryMB = 2048; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.60"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        // Tier 4: Application HA Cluster (3 nodes)
        let app1 = {
            Id = "indrajaal-ex-app-1"; Name = "indrajaal-ex-app-1"
            Role = Seed; Image = "localhost/indrajaal-app:latest"
            Ports = [(4000, 4000); (4001, 4001)]
            Environment = Map.ofList [
                ("CLUSTER_SEED", "true")
                ("RELEASE_NODE", "indrajaal@indrajaal-ex-app-1")
                ("SKIP_ZENOH_NIF", "0")
                ("CEPAF_BRIDGE_URL", "http://cepaf-bridge:9876")
                ("CORTEX_URL", "http://indrajaal-cortex:9877")
            ]
            After = ["indrajaal-db-prod"; "indrajaal-obs-prod"; "zenoh-router"]
            Requires = ["indrajaal-db-prod"; "zenoh-router"]; Wants = ["indrajaal-obs-prod"]
            HealthCheck = Some "curl -sf http://localhost:4000/health"
            HealthIntervalMs = 5000; MemoryMB = 4096; CPULimit = 4.0
            Network = sil6Network; IPAddress = Some "172.28.0.10"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let app2 = {
            Id = "indrajaal-ex-app-2"; Name = "indrajaal-ex-app-2"
            Role = Satellite; Image = "localhost/indrajaal-app:latest"
            Ports = [(4003, 4000); (4004, 4001)]
            Environment = Map.ofList [
                ("RELEASE_NODE", "indrajaal@indrajaal-ex-app-2")
                ("SKIP_ZENOH_NIF", "0")
            ]
            After = ["indrajaal-ex-app-1"]
            Requires = ["indrajaal-ex-app-1"]; Wants = []
            HealthCheck = Some "curl -sf http://localhost:4000/health"
            HealthIntervalMs = 5000; MemoryMB = 4096; CPULimit = 4.0
            Network = sil6Network; IPAddress = Some "172.28.0.11"
            StartDelayMs = 2000; MaxJitterMs = 500
        }
        let app3 = {
            Id = "indrajaal-ex-app-3"; Name = "indrajaal-ex-app-3"
            Role = Satellite; Image = "localhost/indrajaal-app:latest"
            Ports = [(4005, 4000); (4006, 4001)]
            Environment = Map.ofList [
                ("RELEASE_NODE", "indrajaal@indrajaal-ex-app-3")
                ("SKIP_ZENOH_NIF", "0")
            ]
            After = ["indrajaal-ex-app-2"]
            Requires = ["indrajaal-ex-app-2"]; Wants = []
            HealthCheck = Some "curl -sf http://localhost:4000/health"
            HealthIntervalMs = 5000; MemoryMB = 4096; CPULimit = 4.0
            Network = sil6Network; IPAddress = Some "172.28.0.12"
            StartDelayMs = 4000; MaxJitterMs = 500
        }

        // Tier 5: Digital Twin (Chaya)
        let chaya = {
            Id = "indrajaal-chaya"; Name = "indrajaal-chaya"
            Role = Satellite; Image = "localhost/indrajaal-app:latest"
            Ports = [(4002, 4002)]
            Environment = Map.ofList [
                ("CHAYA_MODE", "true")
                ("RELEASE_NODE", "chaya@indrajaal-chaya")
                ("SKIP_ZENOH_NIF", "0")
            ]
            After = ["indrajaal-ex-app-1"; "zenoh-router"]
            Requires = ["indrajaal-ex-app-1"]; Wants = ["zenoh-router"]
            HealthCheck = Some "curl -sf http://localhost:4002/"
            HealthIntervalMs = 5000; MemoryMB = 2048; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.70"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        // Tier 6: ML Satellite Runners (FLAME)
        let mlRunner1 = {
            Id = "indrajaal-ml-runner-1"; Name = "indrajaal-ml-runner-1"
            Role = Worker; Image = "localhost/indrajaal-app:latest"
            Ports = []
            Environment = Map.ofList [
                ("FLAME_PARENT", "indrajaal@indrajaal-ex-app-1")
                ("RELEASE_NODE", "runner1@indrajaal-ml-runner-1")
                ("SKIP_ZENOH_NIF", "0")
                ("PHX_SERVER", "false")
            ]
            After = ["indrajaal-ex-app-1"]
            Requires = ["indrajaal-ex-app-1"]; Wants = []
            HealthCheck = Some "pgrep -f 'sleep infinity'"
            HealthIntervalMs = 30000; MemoryMB = 2048; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.80"
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let mlRunner2 = {
            Id = "indrajaal-ml-runner-2"; Name = "indrajaal-ml-runner-2"
            Role = Worker; Image = "localhost/indrajaal-app:latest"
            Ports = []
            Environment = Map.ofList [
                ("FLAME_PARENT", "indrajaal@indrajaal-ex-app-1")
                ("RELEASE_NODE", "runner2@indrajaal-ml-runner-2")
                ("SKIP_ZENOH_NIF", "0")
                ("PHX_SERVER", "false")
            ]
            After = ["indrajaal-ml-runner-1"]
            Requires = ["indrajaal-ml-runner-1"]; Wants = []
            HealthCheck = Some "pgrep -f 'sleep infinity'"
            HealthIntervalMs = 30000; MemoryMB = 2048; CPULimit = 2.0
            Network = sil6Network; IPAddress = Some "172.28.0.81"
            StartDelayMs = 0; MaxJitterMs = 0
        }

        [
            db; obs;
            zenoh1; zenoh2; zenoh3; zenohProxy;
            bridge; cortex;
            app1; app2; app3;
            chaya;
            mlRunner1; mlRunner2
        ]
        |> List.map (fun g -> (g.Id, g))
        |> Map.ofList

    /// Create default genotypes for prod-standalone topology (SC-CLU-002 MANDATORY)
    let createTierGenotypes (mode: MeshMode) : Map<string, HolonGenotype> =
        // Prod-standalone: 4 containers (zenoh-router, indrajaal-db-prod, indrajaal-obs-prod, indrajaal-ex-app-1)
        let zenoh = {
            Id = "zenoh-router"
            Name = "zenoh-router"
            Role = Controller
            Image = "eclipse/zenoh:latest"
            Ports = [(7447, 7447)]
            Environment = Map.empty
            After = []; Requires = []; Wants = []
            HealthCheck = None
            HealthIntervalMs = 10000; MemoryMB = 512; CPULimit = 1.0
            Network = "indrajaal-mesh"; IPAddress = None
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let db = {
            Id = "indrajaal-db-prod"
            Name = "indrajaal-db-prod"
            Role = Primary
            Image = "localhost/indrajaal-db:latest"
            Ports = [(5433, 5432)]
            Environment = Map.ofList [ ("POSTGRES_DB", "indrajaal_dev") ]
            After = ["zenoh-router"]; Requires = []; Wants = ["zenoh-router"]
            HealthCheck = Some "pg_isready -U postgres"
            HealthIntervalMs = 5000; MemoryMB = 2048; CPULimit = 2.0
            Network = "indrajaal-mesh"; IPAddress = None
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let obs = {
            Id = "indrajaal-obs-prod"
            Name = "indrajaal-obs-prod"
            Role = Controller
            Image = "localhost/indrajaal-obs:latest"
            Ports = [(4317, 4317); (9090, 9090); (3000, 3000); (3100, 3100)]
            Environment = Map.empty
            After = ["indrajaal-db-prod"]; Requires = []; Wants = ["indrajaal-db-prod"]
            HealthCheck = None; HealthIntervalMs = 10000; MemoryMB = 4096; CPULimit = 2.0
            Network = "indrajaal-mesh"; IPAddress = None
            StartDelayMs = 0; MaxJitterMs = 0
        }
        let app1 = {
            Id = "indrajaal-ex-app-1"
            Name = "indrajaal-ex-app-1"
            Role = Seed
            Image = "localhost/indrajaal-app:latest"
            Ports = [(4000, 4000); (4001, 4001)]
            Environment = Map.ofList [ ("CLUSTER_SEED", "true") ]
            After = ["indrajaal-db-prod"; "indrajaal-obs-prod"]
            Requires = ["indrajaal-db-prod"]; Wants = ["indrajaal-obs-prod"]
            HealthCheck = Some "curl -f http://localhost:4000/health"
            HealthIntervalMs = 5000; MemoryMB = 4096; CPULimit = 2.0
            Network = "indrajaal-mesh"; IPAddress = None
            StartDelayMs = 0; MaxJitterMs = 0
        }
        match mode with
        | Dev | Cluster | Fractal ->
            Map.ofList [(zenoh.Id, zenoh); (db.Id, db); (obs.Id, obs); (app1.Id, app1)]
        | SIL6 ->
            createSIL6Genotypes ()

    /// Create with mode-specific topology
    let createForMode (mode: MeshMode) : DigitalTwin =
        let genotypes = createTierGenotypes mode
        let phenotypes = genotypes |> Map.map (fun _ g -> createPhenotype g)
        {
            Genotypes = genotypes
            Phenotypes = phenotypes
            Cache = None; LastCheckpoint = None
            Version = "2.0.0"
            CreatedAt = DateTimeOffset.UtcNow
        }

    /// Create a new digital twin
    let create (genotypes: Map<string, HolonGenotype>) : DigitalTwin =
        let phenotypes =
            genotypes
            |> Map.map (fun _ g -> createPhenotype g)

        {
            Genotypes = genotypes
            Phenotypes = phenotypes
            Cache = None
            LastCheckpoint = None
            Version = "1.0.0"
            CreatedAt = DateTimeOffset.UtcNow
        }

    /// Create with default 3-container topology
    let createDefault () : DigitalTwin =
        create (createTierGenotypes Dev)

    /// Topological sort for dependency DAG
    let private topologicalSort (genotypes: Map<string, HolonGenotype>) : Result<string list, string> =
        let inDegree = Dictionary<string, int>()
        let adjacency = Dictionary<string, string list>()

        // Initialize
        for KeyValue(id, _) in genotypes do
            inDegree.[id] <- 0
            adjacency.[id] <- []

        // Build graph
        for KeyValue(id, g) in genotypes do
            for dep in g.After @ g.Requires do
                if genotypes.ContainsKey(dep) then
                    inDegree.[id] <- inDegree.[id] + 1
                    adjacency.[dep] <- id :: adjacency.[dep]

        // Kahn's algorithm
        let queue = Queue<string>()
        for KeyValue(id, degree) in inDegree do
            if degree = 0 then queue.Enqueue(id)

        let mutable result = []
        while queue.Count > 0 do
            let current = queue.Dequeue()
            result <- result @ [current]
            for neighbor in adjacency.[current] do
                inDegree.[neighbor] <- inDegree.[neighbor] - 1
                if inDegree.[neighbor] = 0 then
                    queue.Enqueue(neighbor)

        if result.Length = genotypes.Count then
            Ok result
        else
            Error "Cycle detected in dependency graph"

    /// Group into parallel waves
    let private groupIntoWaves (genotypes: Map<string, HolonGenotype>) (sortedIds: string list) : StartupWave list =
        let waves = ResizeArray<StartupWave>()
        let started = HashSet<string>()
        let mutable remaining = sortedIds
        let mutable waveOrder = 0

        while remaining.Length > 0 do
            let wave = ResizeArray<string>()
            let stillRemaining = ResizeArray<string>()

            for id in remaining do
                let g = genotypes.[id]
                let deps = g.After @ g.Requires
                let allDepsStarted = deps |> List.forall (fun d -> not (genotypes.ContainsKey(d)) || started.Contains(d))

                if allDepsStarted then
                    wave.Add(id)
                else
                    stillRemaining.Add(id)

            if wave.Count = 0 && stillRemaining.Count > 0 then
                // Stuck - should not happen after topo sort
                failwith "Dependency resolution failed"

            for id in wave do
                started.Add(id) |> ignore

            waves.Add({
                Order = waveOrder
                Holons = wave |> Seq.toList
                MaxParallel = wave.Count
            })

            waveOrder <- waveOrder + 1
            remaining <- stillRemaining |> Seq.toList

        waves |> Seq.toList

    /// Compute and cache topology
    let computeTopology (twin: DigitalTwin) : Result<TopologyCache, string> =
        let configJson = JsonSerializer.Serialize(twin.Genotypes)
        let configHash = computeHash configJson

        match topologicalSort twin.Genotypes with
        | Error e -> Error e
        | Ok sorted ->
            let startWaves = groupIntoWaves twin.Genotypes sorted
            let shutdownWaves =
                startWaves
                |> List.rev
                |> List.mapi (fun i w -> { w with Order = i })

            let cache = {
                Version = twin.Version
                ConfigHash = configHash
                StartOrder = startWaves
                ShutdownOrder = shutdownWaves
                CreatedAt = DateTimeOffset.UtcNow
                ValidatedAt = Some DateTimeOffset.UtcNow
                IsValid = true
            }

            twin.Cache <- Some cache
            Ok cache

    /// Validate existing cache against current config
    let validateCache (twin: DigitalTwin) : bool =
        match twin.Cache with
        | None -> false
        | Some cache ->
            let configJson = JsonSerializer.Serialize(twin.Genotypes)
            let currentHash = computeHash configJson
            cache.ConfigHash = currentHash && cache.IsValid

    /// Get or compute cache
    let getOrComputeCache (twin: DigitalTwin) : Result<TopologyCache, string> =
        if validateCache twin then
            Ok twin.Cache.Value
        else
            computeTopology twin

    /// Update phenotype state
    let updatePhenotype (twin: DigitalTwin) (id: string) (updater: HolonPhenotype -> HolonPhenotype) : unit =
        match Map.tryFind id twin.Phenotypes with
        | None -> ()
        | Some p ->
            twin.Phenotypes <- Map.add id (updater p) twin.Phenotypes

    /// Set container as starting
    let setStarting (twin: DigitalTwin) (id: string) : unit =
        updatePhenotype twin id (fun p ->
            { p with
                Health = Starting
                StartupPhase = Booting
                StartedAt = Some DateTimeOffset.UtcNow
            })

    /// Set container as healthy
    let setHealthy (twin: DigitalTwin) (id: string) (containerId: string) : unit =
        updatePhenotype twin id (fun p ->
            { p with
                Health = Healthy
                ContainerId = Some containerId
                StartupPhase = Ready
                LastHealthCheck = Some DateTimeOffset.UtcNow
                ProofToken = "PROVEN"
            })

    /// Set container as lameduck (for shutdown)
    let setLameduck (twin: DigitalTwin) (id: string) : unit =
        updatePhenotype twin id (fun p ->
            { p with
                Health = Lameduck
                ShutdownPhase = PreShutdown (DateTimeOffset.UtcNow.AddSeconds(5.0))
            })

    /// Set container as draining
    let setDraining (twin: DigitalTwin) (id: string) (connections: int) (timeoutSeconds: float) : unit =
        updatePhenotype twin id (fun p ->
            { p with
                ShutdownPhase = Draining (connections, DateTimeOffset.UtcNow.AddSeconds(timeoutSeconds))
            })

    /// Set container as stopped
    let setStopped (twin: DigitalTwin) (id: string) (exitCode: int) : unit =
        updatePhenotype twin id (fun p ->
            { p with
                Health = Stopped
                StartupPhase = NotStarted
                ShutdownPhase = Terminated exitCode
                ContainerId = None
                Pid = None
            })

    /// Create state checkpoint (dying gasp)
    let createCheckpoint (twin: DigitalTwin) (reason: string) : StateCheckpoint =
        let stateJson = JsonSerializer.Serialize(twin.Phenotypes)
        let stateHash = computeHash stateJson

        let checkpoint = {
            Id = Guid.NewGuid().ToString("N")
            Timestamp = DateTimeOffset.UtcNow
            StateHash = stateHash
            Holons = twin.Phenotypes
            ActiveOperations = []
            PendingWrites = []
            Reason = reason
        }

        twin.LastCheckpoint <- Some checkpoint
        checkpoint

    /// Get mesh status summary
    let getStatus (twin: DigitalTwin) : Map<string, string> =
        twin.Phenotypes
        |> Map.map (fun _ p ->
            match p.Health with
            | ContainerHealth.Unknown -> "UNKNOWN"
            | ContainerHealth.Starting -> "STARTING"
            | ContainerHealth.Healthy -> "HEALTHY"
            | ContainerHealth.Unhealthy -> "UNHEALTHY"
            | ContainerHealth.Lameduck -> "LAMEDUCK"
            | ContainerHealth.Stopping -> "STOPPING"
            | ContainerHealth.Stopped -> "STOPPED"
            | ContainerHealth.Failed r -> sprintf "FAILED: %s" r)

    /// Check if all containers are healthy
    let allHealthy (twin: DigitalTwin) : bool =
        twin.Phenotypes
        |> Map.forall (fun _ p -> p.Health = Healthy)

    /// Check if any container is unhealthy
    let anyUnhealthy (twin: DigitalTwin) : bool =
        twin.Phenotypes
        |> Map.exists (fun _ p ->
            match p.Health with
            | Unhealthy | Failed _ -> true
            | _ -> false)

    /// Get containers by health status
    let getByHealth (twin: DigitalTwin) (health: ContainerHealth) : string list =
        twin.Phenotypes
        |> Map.filter (fun _ p -> p.Health = health)
        |> Map.keys
        |> Seq.toList

    /// Print dashboard view
    let printDashboard (twin: DigitalTwin) : unit =
        printfn ""
        printfn "\u001b[35m\u001b[1m>>> INDRAJAAL DIGITAL TWIN DASHBOARD <<<\u001b[0m"
        printfn "NODE           ROLE         STATE        DC%%      PROOF"
        printfn "-------------- ------------ ------------ -------- --------"

        for KeyValue(id, phenotype) in twin.Phenotypes do
            let genotype = twin.Genotypes.[id]
            let roleStr =
                match genotype.Role with
                | Primary -> "PRIMARY"
                | Seed -> "SEED"
                | Satellite -> "SAT"
                | Controller -> "CTRL"
                | Worker -> "WORKER"

            let stateStr, color =
                match phenotype.Health with
                | Healthy -> "HEALTHY", "\u001b[32m"
                | Starting -> "STARTING", "\u001b[33m"
                | Lameduck -> "LAMEDUCK", "\u001b[33m"
                | Stopped -> "STOPPED", "\u001b[90m"
                | Failed _ -> "FAILED", "\u001b[31m"
                | _ -> "UNKNOWN", "\u001b[37m"

            printfn "%-14s %-12s %s%-12s\u001b[0m %.1f%%     %s"
                id roleStr color stateStr phenotype.DiagnosticCoverage phenotype.ProofToken
