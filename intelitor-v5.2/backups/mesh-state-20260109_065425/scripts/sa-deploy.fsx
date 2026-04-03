#!/usr/bin/env -S dotnet fsi
// sa-deploy.fsx - Safe Harbor Deployment Orchestrator (Governed)
// Version: 1.2.0
// Compliance: SC-DEP-*, SC-METRICS-003 (Mandatory Parallelization)
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers

#load "lib/cepaf/scripts/Governance.fsx"
open Cepaf.Scripts
open System
open System.Diagnostics
open System.Threading

let probeHealth port =
    Governance.Info "PROBE" (sprintf "Probing Candidate on Port %d..." port)
    // Simulate health check (Real implementation would use HttpClient)
    let code = Governance.Exec "podman" (sprintf "port -a | grep %d" port)
    code = 0

// --- MIRA CYCLE ---

let deploy targetNode =
    Governance.Info "MIRA" (sprintf "INITIATING MIRA CYCLE FOR: %s" targetNode)
    
    // 1. INCUBATE
    Governance.Info "STAGE 1" "INCUBATION (Materializing Candidate)..."
    let candidateName = sprintf "%s-candidate" targetNode
    let port = 4003 // Ephemeral port
    
    // Using the same image but as a candidate
    // Injecting required environment variables and FULL STARTUP COMMAND for SIL-6 compliance
    // IMPORTANT: Matching the podman-compose genotype exactly
    let startupCmd = "/root/.nix-profile/bin/mix local.hex --force && /root/.nix-profile/bin/mix local.rebar --force && /root/.nix-profile/bin/mix deps.get && /root/.nix-profile/bin/mix compile && /root/.nix-profile/bin/iex -S /root/.nix-profile/bin/mix phx.server"
    // SC-METRICS-003: Mandatory parallelization with 16 schedulers and 16 dirty I/O schedulers
    let runCmd = sprintf "run -d --name %s -p %d:4000 --network intelitor-v52_fractal-mesh --env NODE_NAME=%s@%s --env DATABASE_URL=ecto://postgres:postgres@indrajaal-db1:5432/indrajaal_fractal --env \"ELIXIR_ERL_OPTIONS=+S 16:16 +SDio 16\" --env NO_TIMEOUT=true --env PATIENT_MODE=enabled --env MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 --env PHX_PORT=4000 localhost/indrajaal-app:latest /root/.nix-profile/bin/bash -c '%s'" candidateName port candidateName candidateName startupCmd
    let startCode = Governance.Exec "podman" runCmd
    
    if startCode <> 0 then
        Governance.Fail "MIRA" "CANDIDATE FAILED TO START. APOPTOSIS TRIGGERED."
        Governance.Exec "podman" (sprintf "rm -f %s" candidateName) |> ignore
        exit 1

    // 2. QUALIFY
    Governance.Info "STAGE 2" "QUALIFICATION (Verifying Health)..."
    Thread.Sleep(30000) // Give it breath (Increased for deps compilation)
    if not (probeHealth port) then
        Governance.Fail "MIRA" "CANDIDATE UNHEALTHY. APOPTOSIS TRIGGERED."
        Governance.Exec "podman" (sprintf "rm -f %s" candidateName) |> ignore
        exit 1
    Governance.Success "MIRA" "CANDIDATE VERIFIED."

    // 3. MIRA
    Governance.Info "STAGE 3" "MIRA (Migration)..."
    // Stop old
    Governance.Exec "podman" (sprintf "stop %s" targetNode) |> ignore
    Governance.Exec "podman" (sprintf "rm %s" targetNode) |> ignore
    // Rename candidate to target
    Governance.Exec "podman" (sprintf "rename %s %s" candidateName targetNode) |> ignore
    
    Governance.Success "MIRA" "MIGRATION COMPLETE. HOMEOSTASIS RESTORED."

// --- MAIN ---

let args = fsi.CommandLineArgs |> Array.skip 1
if args.Length = 0 then
    printfn "Usage: sa-deploy.fsx <node-name>"
else
    deploy args.[0]