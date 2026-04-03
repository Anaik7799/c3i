#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL RESTORATION ARTIFACT
// Version: 1.0.0 (SIL-6 Compliance)
// Purpose: Re-materialize the v21.3.0 Fractal Mesh from a Total Void State
// =========================================================================================

open System
open System.Diagnostics
open System.IO

// --- CONFIGURATION ---
let RESET_COLOR = "\u001b[0m"
let CYAN = "\u001b[36m"
let GREEN = "\u001b[32m"
let YELLOW = "\u001b[33m"
let RED = "\u001b[31m"

let log info msg = 
    let color = match info with "INFO" -> GREEN | "WARN" -> YELLOW | "ERROR" -> RED | _ -> CYAN
    printfn $"{color}[{DateTime.Now:HH:mm:ss} {info}] {msg}{RESET_COLOR}"

let exec command args ignoreError =
    log "EXEC" $"{command} {args}"
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    if proc.ExitCode <> 0 && not ignoreError then
        log "ERROR" $"Command failed with exit code {proc.ExitCode}"
        Environment.Exit(proc.ExitCode)
    proc.ExitCode

// --- PHASE 1: SUBSTRATE APOPTOSIS (TOTAL SCOUR) ---
let phase1_Scour () =
    log "INFO" ">>> PHASE 1: SUBSTRATE APOPTOSIS (NUCLEAR SCOUR) <<<"
    log "WARN" "This will destroy ALL running containers and networks."
    
    // 1. Remove all containers (Force)
    exec "podman" "rm -af" true |> ignore
    
    // 2. Remove all pods (Force)
    exec "podman" "pod" "rm -af" true |> ignore
    
    // 3. Prune networks (Force) - Clears IPAM deadlocks
    exec "podman" "network" "prune -f" true |> ignore
    
    log "INFO" "Substrate is now STERILE (Total Void State)."

// --- PHASE 2: INFRASTRUCTURE REALIGNMENT ---
let phase2_Infra () =
    log "INFO" ">>> PHASE 2: INFRASTRUCTURE & GENOTYPE ALIGNMENT <<<"
    
    // 1. Materialize Registry Holon (Required for Image Resolution)
    // We check if it's already running (unlikely after scour, but safe)
    log "INFO" "Materializing Localhost Registry..."
    exec "podman" "run -d -p 5000:5000 --name registry docker.io/library/registry:2" true |> ignore
    
    // 2. Align Genotypes (Tagging)
    // Ensuring 'latest' tags map to the verified 'nixos-devenv' builds
    log "INFO" "Aligning App Genotype..."
    exec "podman" "tag localhost/indrajaal-app-unified:nixos-devenv localhost/indrajaal-app:latest" false |> ignore
    
    log "INFO" "Aligning Obs Genotype..."
    exec "podman" "tag localhost/indrajaal-obs-unified:nixos-devenv localhost/indrajaal-obs:latest" false |> ignore
    
    log "INFO" "Infrastructure Materialized."

// --- PHASE 3: SUBSTRATE IGNITION ---
let phase3_Ignition () =
    log "INFO" ">>> PHASE 3: SUBSTRATE IGNITION (5-STAGE BOOT) <<<"
    
    // Using the existing F# Orchestrator for the boot sequence
    // This script (sa-up.fsx) handles the transactional start of the 6 nodes
    let scriptPath = "sa-up.fsx"
    if File.Exists(scriptPath) then
        exec "dotnet" $"fsi {scriptPath}" false |> ignore
    else
        log "ERROR" $"Ignition script not found at {scriptPath}"
        Environment.Exit(1)

// --- PHASE 4: VERIFICATION ---
let phase4_Verify () =
    log "INFO" ">>> PHASE 4: METABOLIC VERIFICATION <<<"
    
    // Running the status check
    let scriptPath = "sa-status.fsx"
    if File.Exists(scriptPath) then
        exec "dotnet" $"fsi {scriptPath}" false |> ignore
    else
        log "WARN" "Status script not found, running manual audit..."
        exec "podman" "ps -a" false |> ignore

// --- MAIN ---
try
    phase1_Scour()
    phase2_Infra()
    phase3_Ignition()
    phase4_Verify()
    
    log "INFO" "========================================================"
    log "INFO" "   SYSTEM RESTORATION COMPLETE: SIL-6 HOMEOSTASIS"
    log "INFO" "========================================================"
with
| ex -> 
    log "ERROR" $"Fatal Exception: {ex.Message}"
    Environment.Exit(1)
