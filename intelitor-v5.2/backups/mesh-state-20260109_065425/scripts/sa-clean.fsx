#!/usr/bin/env -S dotnet fsi
// sa-clean.fsx - Biomorphic SIL-6 Mesh Cleanup
// Version: 2.0.0
// Topology: Fractal Mesh

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

printfn ">>> [SA-CLEAN] CLEANING FRACTAL MESH ARTIFACTS..."

// 1. Stop if running
exec "dotnet" "fsi sa-down.fsx" |> ignore

// 2. Prune Volumes
let exitCode = exec "podman" "volume prune -f"

// 3. Explicitly remove fractal volumes
let volumes = [
    "fractal-db1-data"
    "fractal-db2-data"
    "fractal-obs-data"
    "fractal-app1-data"
    "fractal-app2-data"
]

volumes |> List.iter (fun v -> 
    printfn ">>> [SA-CLEAN] REMOVING VOLUME: %s" v
    exec "podman" ("volume rm " + v) |> ignore
)

printfn ">>> [SA-CLEAN] CLEANUP COMPLETE."