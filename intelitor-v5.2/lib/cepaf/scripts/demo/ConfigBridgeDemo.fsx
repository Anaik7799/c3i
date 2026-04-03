#!/usr/bin/env -S dotnet fsi
// =============================================================================
// ConfigBridge Demo Script
// =============================================================================
// Demonstrates F# ↔ Elixir configuration synchronization
//
// Usage:
//   dotnet fsi scripts/demo/ConfigBridgeDemo.fsx
//
// STAMP: SC-CONSOL-006, SC-CONFIG-001
// =============================================================================

#r "../../lib/cepaf/src/Cepaf.Config/bin/Debug/net10.0/Cepaf.Config.dll"

open System
open Cepaf.Config
open Cepaf.Config.ConfigBridge

printfn ""
printfn "═══════════════════════════════════════════════════════════════"
printfn "  CEPAF CONFIG BRIDGE DEMONSTRATION"
printfn "═══════════════════════════════════════════════════════════════"
printfn ""

// 1. Export to Elixir format
printfn "1. Exporting F# MeshConfig to Elixir format..."
let elixirConfig = exportToElixir ()
printfn "   ✓ Exported %d configuration sections" (
    [elixirConfig.Network; elixirConfig.Timeouts; elixirConfig.Containers;
     elixirConfig.Environment; elixirConfig.Quorum; elixirConfig.Animation;
     elixirConfig.Boot; elixirConfig.Metadata]
    |> List.length
)
printfn ""

// 2. Generate config.exs file
printfn "2. Generating Elixir config.exs file..."
match generateConfigExs "data/config/demo_config.exs" with
| Ok () ->
    printfn "   ✓ Config file written to: data/config/demo_config.exs"
| Error err ->
    printfn "   ✗ Error: %A" err
printfn ""

// 3. Detect configuration drift
printfn "3. Detecting configuration drift..."
let driftReport = detectDrift ()
printDriftReport driftReport
printfn ""

// 4. Publish to Zenoh
printfn "4. Publishing configuration to Zenoh..."
match publishToZenoh () |> Async.RunSynchronously with
| Ok () ->
    printfn "   ✓ Configuration published to Zenoh topic: indrajaal/config/mesh/full"
| Error (ZenohError msg) ->
    printfn "   ⚠ Zenoh error: %s" msg
| Error err ->
    printfn "   ✗ Error: %A" err
printfn ""

// 5. Synchronize configurations
printfn "5. Synchronizing configurations (F# → Elixir)..."
match syncConfigs () with
| Ok report ->
    printfn "   ✓ Sync completed successfully"
    printfn "   - Changes applied: %d" report.ChangesApplied
    printfn "   - F# → Elixir: %d" report.FSharpToElixir
    printfn "   - Synced at: %s" (report.SyncedAt.ToString("yyyy-MM-dd HH:mm:ss UTC"))
    for msg in report.Messages do
        printfn "   - %s" msg
| Error err ->
    printfn "   ✗ Sync error: %A" err
printfn ""

// 6. Show sample configuration values
printfn "6. Sample configuration values:"
printfn "   Phoenix Port: %A" (elixirConfig.Network.["ports"] :?> Map<string, obj>).["phoenix_primary"]
printfn "   PostgreSQL Port: %A" (elixirConfig.Network.["ports"] :?> Map<string, obj>).["postgres"]
printfn "   Zenoh Router 1 TCP: %A" (elixirConfig.Network.["ports"] :?> Map<string, obj>).["zenoh_router_1_tcp"]
printfn "   Boot Timeout: %A ms" (elixirConfig.Timeouts.["boot"] :?> Map<string, obj>).["total_timeout_ms"]
printfn "   OODA Cycle Max: %A ms" (elixirConfig.Timeouts.["runtime"] :?> Map<string, obj>).["ooda_cycle_max_ms"]
printfn "   Zenoh Quorum: %A" elixirConfig.Quorum.["zenoh_quorum"]
printfn ""

printfn "═══════════════════════════════════════════════════════════════"
printfn "  DEMO COMPLETE"
printfn "═══════════════════════════════════════════════════════════════"
printfn ""

printfn "Files generated:"
printfn "  - data/config/demo_config.exs (Elixir config)"
printfn "  - data/config/mesh_config.json (JSON export)"
printfn "  - data/config/elixir_runtime_config.json (Runtime sync)"
printfn "  - data/config/generated_config.exs (Generated config)"
printfn ""
