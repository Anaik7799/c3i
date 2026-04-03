#!/usr/bin/env -S dotnet fsi
// sa-health.fsx - Biomorphic SIL-6 Mesh Health (FPPS)
// DELEGATE: lib/cepaf/src/Cepaf/Cepaf.fsproj (Single Source of Truth)
// Compliance: SC-SIL6-005

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let args = fsi.CommandLineArgs |> Array.skip 1 |> String.concat " "
let exitCode = exec "dotnet" ("run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh health " + args)
System.Environment.Exit(exitCode)