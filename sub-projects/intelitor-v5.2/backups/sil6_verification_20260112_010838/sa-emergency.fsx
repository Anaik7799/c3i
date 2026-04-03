#!/usr/bin/env -S dotnet fsi
// sa-emergency.fsx - Biomorphic SIL-6 Emergency Stop
// DELEGATE: lib/cepaf/src/Cepaf/Cepaf.fsproj (Single Source of Truth)
// Compliance: SC-EMR-057

open System.Diagnostics

let exec command args =
    let psi = ProcessStartInfo(FileName = command, Arguments = args, UseShellExecute = false)
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let args = fsi.CommandLineArgs |> Array.skip 1 |> String.concat " "
let exitCode = exec "dotnet" ("run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh emergency " + args)
System.Environment.Exit(exitCode)