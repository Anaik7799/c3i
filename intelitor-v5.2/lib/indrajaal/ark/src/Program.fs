namespace Indrajaal.Ark

open System
open Indrajaal.Ark.Domain

module Program =

    [<EntryPoint>]
    let main args =
        Console.OutputEncoding <- System.Text.Encoding.UTF8
        printfn "🧬 INDRAJAAL ARK [Level 4 Persistence]"
        printfn "   Biomorphic Erasure-Coded Storage System"
        printfn "   ---------------------------------------"

        match args with
        | [| "preserve"; source; dest |] ->
            printfn $"[1] Harvesting: {source}"
            match CryoCore.preserve source with
            | Failure err -> 
                printfn $"❌ Error: {err}"
                1
            | Success blob ->
                printfn $"[2] Compressing: Raw size {blob.Length / 1024} KB"
                printfn $"[3] Hardening: Generating Parity Shards (RAID-5 Logic)..."
                match ImmuneSystem.harden blob with
                | Failure err -> 
                    printfn $"❌ Error: {err}"
                    1
                | Success archive ->
                    printfn $"[4] Writing DNA: {archive.Shards.Length} shards (1 Parity)"
                    match Genesis.save archive dest with
                    | Success path -> 
                        printfn $"✅ DNA SAVED: {path}"
                        0
                    | Failure err -> 
                        printfn $"❌ Error: {err}"
                        1

        | [| "restore"; dnaPath; targetDir |] ->
            printfn $"[1] Reading DNA: {dnaPath}"
            match Genesis.load dnaPath with
            | Failure err -> 
                printfn $"❌ Error: {err}"
                1
            | Success archive ->
                printfn $"[2] Immune System Check: Verifying Integrity..."
                match ImmuneSystem.heal archive with
                | Failure err ->
                    printfn $"❌ FATAL: {err}"
                    1
                | Success payload ->
                    printfn $"[3] Rehydrating: Extracting to {targetDir}..."
                    match CryoCore.rehydrate payload targetDir with
                    | Success _ -> 
                        printfn $"✅ SYSTEM RESTORED."
                        0
                    | Failure err ->
                        printfn $"❌ Error: {err}"
                        1

        | [| "corrupt"; dnaPath; shardId |] ->
            // Utility to simulate corruption for testing
            printfn $"[TEST] Simulating Corruption on Shard {shardId}..."
            match Genesis.load dnaPath with
            | Success archive ->
                let corruptedShards = 
                    archive.Shards 
                    |> List.map (fun s -> 
                        if s.Id = int shardId then 
                            { s with Data = Array.zeroCreate s.Data.Length } // Wipe data
                        else s
                    )
                let corruptedArchive = { archive with Shards = corruptedShards }
                Genesis.save corruptedArchive dnaPath |> ignore
                printfn "⚠️  DNA CORRUPTED."
                0
            | _ -> 1

        | _ ->
            printfn "Usage:"
            printfn "  preserve <source_dir> <output.dna>"
            printfn "  restore  <input.dna>  <target_dir>"
            printfn "  corrupt  <input.dna>  <shard_id>"
            1
