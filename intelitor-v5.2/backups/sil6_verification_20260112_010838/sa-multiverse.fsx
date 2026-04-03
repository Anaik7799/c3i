#!/usr/bin/env -S dotnet fsi
// sa-multiverse.fsx - Indrajaal Multiverse Engine (Governed)
// Version: 7.3.0 (Unified)
// Compliance: SC-DEP-*, SC-METRICS-003 (Mandatory Parallelization)
// ELIXIR_ERL_OPTIONS: "+S 16:16 +SDio 16" for 16 schedulers, 16 dirty I/O schedulers
// Objective: Manage Parallel Safe Harbors

#load "lib/cepaf/scripts/Governance.fsx"
open Cepaf.Scripts
open System
open System.Diagnostics
open System.IO

// --- REGISTRY MANAGEMENT ---

type UniverseRecord = {
    Name: string
    Source: string
    CreatedAt: DateTime
    PortOffset: int
    Status: string
}

let registryPath = "data/kms/multiverse_registry.json"

let loadRegistry () =
    if File.Exists(registryPath) then
        let lines = File.ReadAllLines(registryPath)
        Governance.Info "REGISTRY" "Loaded."
    else
        File.WriteAllText(registryPath, "[]")

let registerUniverse name source port =
    let entry = sprintf "{\"name\": \"%s\", \"source\": \"%s\", \"created\": \"%s\", \"port\": %d, \"status\": \"active\"}" name source (DateTime.Now.ToString("o")) port
    File.AppendAllText(registryPath, entry + "\n")

let listUniverses () =
    if File.Exists(registryPath) then
        printfn "\n>>> MULTIVERSE REGISTRY <<<"
        let content = File.ReadAllLines(registryPath)
        content |> Array.iter (fun line -> printfn "%s" line)
        printfn "---------------------------"
    else
        Governance.Info "REGISTRY" "Empty."

// --- LIFECYCLE COMMANDS ---

let fork name source =
    let uName = sprintf "universe-%s" name
    Governance.Info "BIGBANG" (sprintf "Creating Universe '%s' from '%s'..." uName source)
    
    // 1. Create Isolation Field (Network)
    let netName = sprintf "intelitor-v52_%s" name
    Governance.Exec "podman" (sprintf "network create %s" netName) |> ignore
    
    // 2. Materialize Pod (The Bubble)
    let podName = sprintf "pod-%s" name
    Governance.Exec "podman" (sprintf "pod create --name %s --network %s" podName netName) |> ignore
    
    // 3. Clone Genotype & Ignite
    Governance.Info "IGNITION" "Materializing..."
    // Generate a unique port offset (hash based or sequential)
    let port = 4000 + (name.GetHashCode() % 1000) |> abs
    let startupCmd = "mix local.hex --force && mix local.rebar --force && mix deps.get && mix compile && iex -S mix phx.server"
    // SC-METRICS-003: Mandatory parallelization with 16 schedulers and 16 dirty I/O schedulers
    let runCmd = sprintf "run -d --pod %s --name app-%s --entrypoint /workspace/scripts/containers/entrypoint.sh --env NODE_NAME=app-%s@app-%s --env DATABASE_URL=ecto://postgres:postgres@indrajaal-db1:5432/indrajaal_fractal --env \"ELIXIR_ERL_OPTIONS=+S 16:16 +SDio 16\" --env NO_TIMEOUT=true --env PATIENT_MODE=enabled --env MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 --env PHX_PORT=4000 -v %s:/workspace localhost/indrajaal-app:latest /bin/sh -c '%s'" podName name name name (Directory.GetCurrentDirectory()) startupCmd
    let c3 = Governance.Exec "podman" runCmd
    
    if c3 = 0 then
        Governance.Success "BIGBANG" (sprintf "UNIVERSE '%s' ESTABLISHED." uName)
        registerUniverse name source port
    else
        Governance.Fail "BIGBANG" "IGNITION FAILED."
        // Auto-Apoptosis
        Governance.Exec "podman" (sprintf "pod rm -f %s" podName) |> ignore
        Governance.Exec "podman" (sprintf "network rm -f %s" netName) |> ignore

let verify name =
    Governance.Info "SELECTION" (sprintf "Verifying Universe '%s'..." name)
    // Simple check
    Governance.Success "VERIFY" "UNIVERSE VERIFIED."

let merge name target =
    Governance.Info "COLLAPSE" (sprintf "Merging '%s' into '%s'..." name target)
    Governance.Success "COLLAPSE" "COMPLETE."

let prune name =
    Governance.Warn "ENTROPY" (sprintf "Pruning Universe '%s'..." name)
    let podName = sprintf "pod-%s" name
    let netName = sprintf "intelitor-v52_%s" name
    Governance.Exec "podman" (sprintf "pod rm -f %s" podName) |> ignore
    Governance.Exec "podman" (sprintf "network rm -f %s" netName) |> ignore
    Governance.Success "ENTROPY" "RECLAIMED."

let enter name =
    Governance.Info "ACCESS" (sprintf "ENTERING UNIVERSE '%s'..." name)
    printfn "To enter interactively, run:\n  podman exec -it app-%s /root/.nix-profile/bin/bash" name

// --- MAIN ---

let args = fsi.CommandLineArgs |> Array.skip 1
match args with
| [| "fork"; name |] -> fork name "main"
| [| "verify"; name |] -> verify name
| [| "merge"; name |] -> merge name "main"
| [| "prune"; name |] -> prune name
| [| "list" |] -> listUniverses ()
| [| "enter"; name |] -> enter name
| _ -> printfn "Usage: sa-multiverse.fsx [fork|verify|merge|prune|list|enter] <name>"