#!/usr/bin/env -S dotnet fsi
// sa-scour.fsx - Biomorphic SIL-6 Mesh Nuclear Clean (Scour)
// DELEGATE: lib/cepaf/src/Cepaf/Cepaf.fsproj (Single Source of Truth)
// Compliance: SC-SIL6-007
//
// CONTAINERS: 4 Shutdown & Cleaned (prod-standalone)
// 1. zenoh-router
// 2. indrajaal-db-prod
// 3. indrajaal-obs-prod
// 4. indrajaal-ex-app-1
//
// NOTE: Maps to 'mesh clean' in CLI which performs 'down -v'
// ARTIFACT: lib/cepaf/artifacts/podman-compose-prod-standalone.yml

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let args = fsi.CommandLineArgs |> Array.skip 1 |> String.concat " "
let exitCode = exec "dotnet" ("run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh clean " + args)
System.Environment.Exit(exitCode)