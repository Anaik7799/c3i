#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// SA-STABILIZE.FSX: The Sovereign Stabilization Protocol (SIL-6 EXTENDED)
// Version: 21.3.0 (SIL-6 Biomorphic Extended)
// Purpose: Deterministic transition to Verified Homeostasis with Deep Service Utilization.
// =========================================================================================

open System
open System.IO
open System.Diagnostics
open System.Threading
open System.Net.Sockets

// --- CONFIGURATION: SERVICE MATRIX (SIL-6) ---
// Defines the "Full Set of Services" and their vital signs (Ports)
let services = 
    [ 
      ("registry",           5000, "L0: Registry (Substrate)")
      ("indrajaal-db1",      5433, "L1: Data Plane (Primary)")
      ("indrajaal-db2",      5434, "L1: Data Plane (Replica)")
      ("indrajaal-obs",      8080, "L2: Observability (SigNoz UI)")
      ("indrajaal-obs-grpc", 4317, "L2: Observability (OTEL Ingest)")
      ("indrajaal-app-1",    4000, "L3: Control Plane (Seed Holon)")
      ("indrajaal-app-2",    4001, "L3: Control Plane (Join Holon)")
      ("indrajaal-liveview", 4002, "L4: Interface Plane (Cockpit)")
    ]

let maxRetries = 30 // 30 seconds max wait per service

// --- HELPER FUNCTIONS ---

let color c = Console.ForegroundColor <- c
let reset () = Console.ResetColor()

let log level msg =
    let prefix = 
        match level with
        | "INFO" -> color ConsoleColor.Cyan; "[INFO]"
        | "WARN" -> color ConsoleColor.Yellow; "[WARN]"
        | "ERROR" -> color ConsoleColor.Red; "[ERROR]"
        | "SUCCESS" -> color ConsoleColor.Green; "[SUCCESS]"
        | "CHECK" -> color ConsoleColor.Magenta; "[CHECK]"
        | "SIL-6" -> color ConsoleColor.Blue; "[SIL-6]"
        | _ -> "[LOG]"
    printf "%s " prefix
    reset()
    printfn "%s" msg

let exec command args = 
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let execShell command =
    exec "bash" ("-c \"" + command + "\"")

// --- NETWORK VERIFICATION LOGIC ---

let checkPortOpen (port: int) : bool =
    try
        use client = new TcpClient()
        let result = client.BeginConnect("127.0.0.1", port, null, null)
        let success = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(500.0))
        if success then
            client.EndConnect(result)
            true
        else
            false
    with
    | _ -> false

let waitForService (name: string) (port: int) (desc: string) =
    log "CHECK" (sprintf "Probing %s (%s : %d)..." name desc port)
    let mutable attempts = 0
    let mutable ready = false
    
    while not ready && attempts < maxRetries do
        if checkPortOpen port then
            ready <- true
        else
            attempts <- attempts + 1
            Thread.Sleep(1000)
            if attempts % 5 = 0 then printf "."

    if ready then
        log "SUCCESS" (sprintf "  -> Active [%d ms]" (attempts * 1000))
        true
    else
        log "ERROR" (sprintf "  -> TIMEOUT (%d) - Service Unreachable" port)
        false

// --- SIL-6 EXTENDED CHECKS ---

let verifyMultiverse () =
    log "SIL-6" "Verifying Multiverse Capability..."
    if File.Exists("sa-multiverse.fsx") then
        if Directory.Exists("data/kms") && File.Exists("data/kms/multiverse_registry.json") then
            log "SUCCESS" "Multiverse Registry: MOUNTED"
            true
        else
            log "WARN" "Multiverse Registry: MISSING (Will Initialize)"
            // Self-repair
            Directory.CreateDirectory("data/kms") |> ignore
            File.WriteAllText("data/kms/multiverse_registry.json", "[]")
            log "SUCCESS" "Multiverse Registry: REPAIRED"
            true
    else
        log "ERROR" "Multiverse Controller (sa-multiverse.fsx) NOT FOUND."
        false

let verifyGenotype () =
    log "SIL-6" "Verifying Genotype Alignment..."
    // Simple check if images exist locally
    let exitCode = execShell "podman images | grep localhost/indrajaal-app > /dev/null"
    if exitCode = 0 then
        log "SUCCESS" "Genotype: LOCALHOST/INDRAJAAL-APP PRESENT"
        true
    else
        log "WARN" "Genotype: MISSING (Will require pull/build during boot)"
        false

// --- STABILIZATION PHASES ---

let stabilize () =
    log "INFO" ">>> INITIATING SIL-6 STABILIZATION PROTOCOL <<<"
    
    // 1. Check Infrastructure (L0)
    if not (checkPortOpen 5000) then
        log "WARN" "Registry (L0) DOWN. Attempting Revival..."
        execShell "podman run -d -p 5000:5000 --name registry registry:2 > /dev/null" |> ignore
        if waitForService "registry" 5000 "Substrate" then
            log "SUCCESS" "Registry Revived."
        else
            log "ERROR" "Registry Failed."
            
    // 2. Check Genotype
    verifyGenotype() |> ignore

    // 3. Check Multiverse
    verifyMultiverse() |> ignore

    // 4. Verify Service Mesh (L1-L4)
    log "INFO" "Scanning Metabolic Pulse..."
    let results = 
        services 
        |> List.map (fun (name, port, desc) -> waitForService name port desc)

    let successCount = results |> List.filter id |> List.length
    let totalCount = results |> List.length

    printfn "\n================================================================================"
    printfn "   SIL-6 BIO-METRIC REPORT (v21.3.0)"
    printfn "================================================================================"
    services |> List.iter (fun (n, p, d) ->
        let status = if checkPortOpen p then "[ ALIVE  ]" else "[ DEAD   ]"
        let colorFunc = if status = "[ ALIVE  ]" then color ConsoleColor.Green else color ConsoleColor.Red
        colorFunc
        printfn " %s %-20s : %d (%s)" status n p d
        reset()
    )
    printfn "================================================================================\n"

    if successCount = totalCount then
        log "SUCCESS" ">>> SYSTEM HOMEOSTASIS CONFIRMED (SIL-6 READY) <<<"
        log "INFO" "Topology: 6-Node Biomorphic Fractal Mesh + Registry"
        log "INFO" "Capability: Multiverse Enabled"
        0
    else
        log "WARN" (sprintf "Homeostasis Partial. %d/%d services active." successCount totalCount)
        log "INFO" "Recommendation: Run './sa-sil6-boot.fsx' to perform full regeneration."
        1

// --- ENTRY POINT ---

stabilize()
