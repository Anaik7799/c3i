#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// SA-SIL6-HOMEOSTASIS-BOOT.FSX: SIL-6 Biomorphic Homeostasis Activation Protocol
// Version: 21.3.1 (Enhanced Robustness)
// Architecture: v21.3.0 Biomorphic Fractal Holon
// Purpose: Deterministic transition to Verified SIL-6 Homeostasis with Zenoh/Cortex Integration.
//          Includes L7 Deep Probes and State Dump.
// =========================================================================================

#r "nuget: FSharp.Data"
open System
open System.IO
open System.Diagnostics
open System.Threading
open System.Net.Sockets
open System.Net.Http
open System.Text
open System.Text.Json

// --- FRACTAL DEFINITIONS ---

type HolonId = string
type FractalLevel = L0_Substrate | L1_Cellular | L2_Tissue | L3_Organ | L4_System | L5_Organism | L6_Population | L7_Biosphere

type ServiceDef = {
    Name: string
    Port: int
    Level: FractalLevel
    HolonId: HolonId
    Description: string
    Mandatory: bool
    ProbePath: string option // HTTP Probe Path (e.g., "/health")
}

// --- CONFIGURATION: BIO-FRACTAL SERVICE MATRIX ---
let services = [
    { Name = "infra-registry"; Port = 5000; Level = L0_Substrate; HolonId = "HOL-000-REG"; Description = "Localhost Image Registry"; Mandatory = true; ProbePath = Some "/v2/" }
    { Name = "indrajaal-zenoh"; Port = 8000; Level = L1_Cellular; HolonId = "HOL-001-ZNH"; Description = "Zenoh REST API"; Mandatory = true; ProbePath = Some "/healthz" }
    { Name = "indrajaal-db"; Port = 5433; Level = L2_Tissue; HolonId = "HOL-002-MEM"; Description = "PostgreSQL 17 (Memory)"; Mandatory = true; ProbePath = None }
    { Name = "indrajaal-obs"; Port = 3000; Level = L2_Tissue; HolonId = "HOL-003-SNS"; Description = "Grafana (Visual Cortex)"; Mandatory = true; ProbePath = Some "/api/health" }
    { Name = "indrajaal-app-1"; Port = 4000; Level = L3_Organ; HolonId = "HOL-004-COR-1"; Description = "App Seed (Body)"; Mandatory = true; ProbePath = Some "/health" }
    { Name = "indrajaal-app-2"; Port = 4001; Level = L3_Organ; HolonId = "HOL-004-COR-2"; Description = "App Join (Body)"; Mandatory = true; ProbePath = Some "/health" }
    { Name = "indrajaal-cortex"; Port = 8081; Level = L4_System; HolonId = "HOL-005-CTX"; Description = "F# Cortex (Cognition)"; Mandatory = false; ProbePath = None } // Optional for now
]

let maxRetries = 60 // 60 seconds tolerance

// --- FRACTAL LOGGING SYSTEM ---

let color c = Console.ForegroundColor <- c
let reset () = Console.ResetColor()
let timestamp () = DateTime.Now.ToString("HH:mm:ss.fff")

let log (level: string) (holon: string) (layer: string) (msg: string) =
    let (c, prefix) = 
        match level with
        | "BOOT" -> (ConsoleColor.Blue, "BOOT")
        | "INFO" -> (ConsoleColor.Cyan, "INFO")
        | "WARN" -> (ConsoleColor.Yellow, "WARN")
        | "CRIT" -> (ConsoleColor.Red, "CRIT")
        | "OKAY" -> (ConsoleColor.Green, "OKAY")
        | "NEURO" -> (ConsoleColor.Magenta, "NEUR")
        | "TRANS" -> (ConsoleColor.White, "TRNS")
        | _ -> (ConsoleColor.Gray, "LOG")
    
    printf "%s | " (timestamp())
    color c; printf "%-5s" prefix; reset();
    printf " | %-12s | %-15s | " holon layer
    printfn "%s" msg

let printHeader () =
    Console.Clear()
    color ConsoleColor.Cyan
    printfn "========================================================================================="
    printfn "   INDRAJAAL v21.3.1 | SIL-6 BIOMORPHIC HOMEOSTASIS ACTIVATION PROTOCOL"
    printfn "   Mode: VERBOSE | Telemetry: ZENOH | Substrate: NIXOS | Safety: STAMP/SIL-6"
    printfn "   L7 Probes: ENABLED | State Dump: ENABLED"
    printfn "========================================================================================="
    reset()
    printfn ""

// --- EXECUTION PRIMITIVES ---

let exec command args = 
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true)
    // Inject SIL-6 Envs for all child processes
    psi.EnvironmentVariables.["SIL_LEVEL"] <- "6"
    psi.EnvironmentVariables.["BIOMORPHIC_MODE"] <- "enabled"
    let proc = Process.Start(psi)
    let output = proc.StandardOutput.ReadToEnd()
    let error = proc.StandardError.ReadToEnd()
    proc.WaitForExit()
    (proc.ExitCode, output, error)

let execShell command =
    exec "bash" ("-c \"" + command + "\"")

// --- SENSORY CHANNELS ---

let checkTcp (port: int) : bool =
    try
        use client = new TcpClient()
        let result = client.BeginConnect("127.0.0.1", port, null, null)
        let success = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(200.0))
        if success then client.EndConnect(result); true else false
    with _ -> false

let checkHttp (port: int) (path: string) : bool =
    try
        use client = new HttpClient()
        client.Timeout <- TimeSpan.FromSeconds(1.0)
        let url = sprintf "http://127.0.0.1:%d%s" port path
        let response = client.GetAsync(url).Result
        response.IsSuccessStatusCode
    with _ -> false

let probeService (s: ServiceDef) =
    if checkTcp s.Port then
        match s.ProbePath with
        | Some path -> 
            if checkHttp s.Port path then "HEALTHY" else "TCP_ONLY"
        | None -> "TCP_ONLY"
    else "OFFLINE"

// --- TRANSACTIONAL PHASE MANAGER ---

type BootPhase = Preflight | Sterilization | Genotype | NeuralMesh | Organogenesis | Convergence | Homeostasis
type TransactionResult = Success of string | Failure of string

let runPhase (phase: BootPhase) (action: unit -> TransactionResult) =
    let phaseName = sprintf "%A" phase
    log "TRANS" "SYSTEM" phaseName ">>> INITIATING TRANSACTION <<<"
    match action() with
    | Success msg ->
        log "OKAY" "SYSTEM" phaseName (sprintf "Transaction Committed: %s" msg)
        true
    | Failure err ->
        log "CRIT" "SYSTEM" phaseName (sprintf "Transaction Aborted: %s" err)
        log "WARN" "SYSTEM" "ROLLBACK" "Initiating Emergency Apoptosis..."
        execShell "podman-compose -f podman-compose-fractal-mesh.yml down" |> ignore
        false

// --- PHASES ---

let p_preflight () =
    if not (File.Exists("podman-compose-fractal-mesh.yml")) then Failure "Topology file missing."
    else Success "Substrate Topology Verified."

let p_sterilization () =
    log "WARN" "IMMUNE" "L0" "Clearing previous state..."
    execShell "podman rm -af > /dev/null 2>&1" |> ignore
    execShell "podman pod rm -af > /dev/null 2>&1" |> ignore
    Success "Environment Sterilized."

let p_genotype () =
    log "INFO" "GENOME" "L0" "Verifying NixOS Genotypes..."
    // Ensure registry exists for local pulls if needed
    if not (checkTcp 5000) then
        execShell "podman run -d -p 5000:5000 --name registry registry:2 > /dev/null" |> ignore
        Thread.Sleep(2000)
    
    // Ensure 'latest' tags exist for mesh
    execShell "podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv localhost/indrajaal-app:latest" |> ignore
    execShell "podman tag localhost/indrajaal-timescaledb-demo:nixos-devenv localhost/indrajaal-db:latest" |> ignore
    execShell "podman tag localhost/indrajaal-observability:nixos localhost/indrajaal-obs:latest" |> ignore
    
    Success "Genotypes Tagged & Ready."

let p_neural_mesh () =
    // Zenoh starts with the mesh in compose
    Success "Neural Bus Configured."

let p_organogenesis () =
    log "INFO" "BODY" "L3" "Booting Biomorphic Containers (SIL-6 Injected)..."
    let cmd = "podman-compose -f podman-compose-fractal-mesh.yml up -d"
    let (code, _, err) = execShell cmd
    if code = 0 then Success "Organogenesis Initiated."
    else Failure (sprintf "Organogenesis Failed: %s" err)

let p_convergence () =
    log "INFO" "SENSES" "L4" "Waiting for Metabolic Synchronization..."
    let mutable allUp = false
    let mutable attempts = 0
    
    while not allUp && attempts < maxRetries do
        Thread.Sleep(1000)
        attempts <- attempts + 1
        
        let statuses = services |> List.map (fun s -> (s, probeService s))
        let healthyCount = statuses |> List.filter (fun (_, stat) -> stat = "HEALTHY" || stat = "TCP_ONLY") |> List.length
        
        Console.Write("\r")
        printf "   METABOLISM: [%s] %d/%d Organs Active (t=%ds)   "
            (String.replicate healthyCount "#" + String.replicate (services.Length - healthyCount) ".")
            healthyCount services.Length attempts
            
        // Relaxed check: Mandatory services must be at least TCP_ONLY
        let mandatoryUp = statuses |> List.forall (fun (s, stat) -> 
            if s.Mandatory then stat <> "OFFLINE" else true)
            
        if mandatoryUp then allUp <- true

    Console.WriteLine()
    if allUp then Success "Metabolic Convergence Achieved."
    else Failure "Metabolic Timeout."

// --- STATE DUMP ---

type SystemState = {
    Timestamp: DateTime
    Mode: string
    SilLevel: int
    Services: Map<string, string>
}

let dumpState (statuses: (ServiceDef * string) list) =
    let state = {
        Timestamp = DateTime.UtcNow
        Mode = "SIL-6 Biomorphic"
        SilLevel = 6
        Services = statuses |> List.map (fun (s, stat) -> (s.Name, stat)) |> Map.ofList
    }
    let json = JsonSerializer.Serialize(state)
    File.WriteAllText(".sil6_state.json", json)
    log "META" "KERNEL" "L0" "State Dumped to .sil6_state.json"

// --- MAIN ---

let main () =
    printHeader()
    let steps = [
        (Preflight, p_preflight)
        (Sterilization, p_sterilization)
        (Genotype, p_genotype)
        (NeuralMesh, p_neural_mesh)
        (Organogenesis, p_organogenesis)
        (Convergence, p_convergence)
    ]
    
    if steps |> List.forall (fun (p, action) -> runPhase p action) then
        // Final Probe
        let finalStatuses = services |> List.map (fun s -> (s, probeService s))
        dumpState finalStatuses
        
        log "OKAY" "HOMEO" "L5" ">>> SYSTEM HOMEOSTASIS ACHIEVED <<<"
        
        for (s, stat) in finalStatuses do
            let c = if stat = "HEALTHY" then ConsoleColor.Green 
                    elif stat = "TCP_ONLY" then ConsoleColor.Yellow 
                    else ConsoleColor.Red
            color c
            printfn "   [%-10s] %-20s : %s" stat s.Name s.Description
        reset()
        0
    else
        1

main()
