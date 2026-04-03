#!/usr/bin/env -S dotnet fsi
// sa-up.fsx - Biomorphic SIL-6 Mesh Boot
// DELEGATE: sa-mesh.fsx (Comprehensive Orchestrator)
// Compliance: SC-SIL6-001, SC-METRICS-003
//
// CONTAINERS: 14 Started (Full HA Mesh)
// 1. indrajaal-db-prod
// 2. indrajaal-obs-prod
// 3. zenoh-router-1
// 4. zenoh-router-2
// 5. zenoh-router-3
// 6. cepaf-bridge
// 7. indrajaal-cortex
// 8. indrajaal-ex-app-1 (Primary)
// 9. indrajaal-ex-app-2 (Secondary)
// 10. indrajaal-ex-app-3 (Tertiary)
// 11. indrajaal-chaya (Digital Twin)
// 12. indrajaal-ml-runner-1 (Satellite 1)
// 13. indrajaal-ml-runner-2 (Satellite 2)
// 14. zenoh-router (proxy)
//
// ARTIFACT: lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let args = fsi.CommandLineArgs |> Array.skip 1 |> String.concat " "
// Delegate to the comprehensive mesh orchestrator
let exitCode = exec "dotnet" ("fsi sa-mesh.fsx up " + args)
System.Environment.Exit(exitCode)