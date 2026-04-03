#!/usr/bin/env -S dotnet fsi
// sa-clean.fsx - Biomorphic SIL-6 Mesh Cleanup
// DELEGATE: lib/cepaf/src/Cepaf/Cepaf.fsproj (Single Source of Truth)
// Compliance: SC-SIL6-003
//
// CONTAINERS: 5 Shutdown & Cleaned (Volumes Removed)
// 1. db-primary
// 2. app-1
// 3. app-2
// 4. app-3
// 5. indrajaal-obs
//
// ARTIFACT: lib/cepaf/artifacts/podman-compose-fractal-cluster.yml

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let args = fsi.CommandLineArgs |> Array.skip 1 |> String.concat " "
let exitCode = exec "dotnet" ("run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh clean " + args)
System.Environment.Exit(exitCode)