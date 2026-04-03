#!/usr/bin/env -S dotnet fsi

// =========================================================================================
// INDRAJAAL BIOMORPHIC PATCHER: CUBDB METABOLIC HARDENING
// Version: 1.0.0
// Purpose: Resolve Elixir 1.19 struct update warnings in dependencies
// =========================================================================================

open System
open System.IO

let cubdbPath = "deps/cubdb/lib/cubdb.ex"

printfn ">>> [CORTEX] INITIATING CUBDB PATCH..."

if File.Exists(cubdbPath) then
    let content = File.ReadAllText(cubdbPath)
    
    // BACKUP
    let backupPath = cubdbPath + ".bak"
    File.WriteAllText(backupPath, content)
    printfn ">>> [CORTEX] BACKUP CREATED: %s" backupPath

    // MUTATION: Inject struct pattern matching into handle_call/handle_cast/etc.
    // This is a high-fidelity replacement targeting the specific CubDB functions
    let mutations = [
        ("handle_call(msg, from, state)", "handle_call(msg, from, %State{} = state)")
        ("handle_cast(msg, state)", "handle_cast(msg, %State{} = state)")
        ("handle_info(msg, state)", "handle_info(msg, %State{} = state)")
        ("checkin_reader(from, ref, state)", "checkin_reader(from, ref, %State{} = state)")
        ("checkout_reader(from, state)", "checkout_reader(from, %State{} = state)")
        ("clean_up_when_possible(state)", "clean_up_when_possible(%State{} = state)")
        ("advance_write_queue(state)", "advance_write_queue(%State{} = state)")
    ]

    let mutable patchedContent = content
    for (oldVal, newVal) in mutations do
        if patchedContent.Contains(oldVal) then
            patchedContent <- patchedContent.Replace(oldVal, newVal)
            printfn ">>> [CORTEX] APPLIED MUTATION: %s -> %s" oldVal newVal
        else
            printfn ">>> [CORTEX] PATTERN NOT FOUND: %s" oldVal

    File.WriteAllText(cubdbPath, patchedContent)
    printfn ">>> [CORTEX] GENOTYPE HARDENING COMPLETE."
else
    printfn ">>> [ERROR] CUBDB GENOTYPE NOT FOUND AT: %s" cubdbPath
    Environment.Exit(1)
