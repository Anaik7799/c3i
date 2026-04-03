namespace Indrajaal.Ark

open System
open Indrajaal.Ark.Domain

module ImmuneSystem =

    let private SHARD_SIZE = 1024 * 1024 // 1 MB Shards for granularity

    /// XORs two byte arrays. Assumes equal length.
    let private xorBlock (a: byte[]) (b: byte[]) : byte[] =
        let len = a.Length
        let result = Array.zeroCreate len
        // Optimization: Use SIMD in production, simple loop for clarity here
        for i = 0 to len - 1 do
            result.[i] <- a.[i] ^^^ b.[i]
        result

    /// Hardens the payload by sharding and adding parity (RAID-5 style logic)
    /// Simplification: All data XORed together = Global Parity Block.
    /// Allows recovery of ANY single missing data block.
    let harden (payload: byte[]) : Result<DnaArchive> =
        try
            let totalSize = payload.LongLength
            let shardCount = (int totalSize + SHARD_SIZE - 1) / SHARD_SIZE
            
            // 1. Create Data Shards
            let dataShards = 
                [| 0 .. shardCount - 1 |]
                |> Array.map (fun i ->
                    let offset = i * SHARD_SIZE
                    let remaining = int totalSize - offset
                    let count = Math.Min(SHARD_SIZE, remaining)
                    
                    let buffer = Array.zeroCreate SHARD_SIZE // Pad to uniform size
                    Array.Copy(payload, int64 offset, buffer, 0, int64 count)
                    
                    { Id = i; Type = Data; Data = buffer; Checksum = sha256 buffer }
                )

            // 2. Calculate Parity (XOR of all Data Shards)
            let parityData = 
                dataShards 
                |> Array.map (fun s -> s.Data)
                |> Array.reduce xorBlock

            let parityShard = {
                Id = shardCount // ID follows last data shard
                Type = Parity
                Data = parityData
                Checksum = sha256 parityData
            }

            let allShards = Array.append dataShards [| parityShard |] |> Array.toList

            let manifest = {
                Timestamp = DateTime.UtcNow
                TotalSize = totalSize
                ShardSize = SHARD_SIZE
                DataShardCount = shardCount
                ParityShardCount = 1
                OriginalHash = sha256 payload
            }

            Success { Manifest = manifest; Shards = allShards }
        with e ->
            Failure $"Hardening failed: {e.Message}"

    /// Validates integrity and heals corruption
    let heal (archive: DnaArchive) : Result<byte[]> =
        try
            printfn "🔍 [IMMUNE] Scanning DNA Shards for corruption..."
            
            // 1. Identify Valid vs Corrupted Shards
            let validationResults = 
                archive.Shards
                |> List.map (fun s -> 
                    let currentHash = sha256 s.Data
                    if currentHash = s.Checksum then (s.Id, true) else (s.Id, false)
                )
                |> Map.ofList

            let corruptedIds = 
                validationResults 
                |> Map.filter (fun _ valid -> not valid) 
                |> Map.keys 
                |> Seq.toList

            match corruptedIds with
            | [] -> 
                printfn "✅ [IMMUNE] DNA Integrity: 100%. No healing required."
                // Reassemble
                let finalBytes = Array.zeroCreate (int archive.Manifest.TotalSize)
                archive.Shards 
                |> List.filter (fun s -> s.Type = Data)
                |> List.sortBy (fun s -> s.Id)
                |> List.iter (fun s -> 
                    let offset = s.Id * archive.Manifest.ShardSize
                    let remaining = int archive.Manifest.TotalSize - offset
                    let count = Math.Min(archive.Manifest.ShardSize, remaining)
                    Array.Copy(s.Data, 0, finalBytes, offset, count)
                )
                Success finalBytes

            | [badId] ->
                printfn $"⚠️ [IMMUNE] CORRUPTION DETECTED in Shard {badId}. Initiating Biomorphic Repair..."
                
                // 2. Repair Logic (XOR Math)
                // If A ^ B ^ C = P, then B = A ^ C ^ P
                // Missing Block = XOR(All other blocks including Parity)
                
                let goodShards = 
                    archive.Shards 
                    |> List.filter (fun s -> s.Id <> badId)
                
                let recoveredData = 
                    goodShards
                    |> List.map (fun s -> s.Data)
                    |> List.reduce xorBlock

                printfn "🧬 [IMMUNE] Shard Regenerated from Parity Cloud."

                // Reassemble with recovered block
                let finalBytes = Array.zeroCreate (int archive.Manifest.TotalSize)
                
                let getShardData id = 
                    if id = badId then recoveredData
                    else (archive.Shards |> List.find (fun s -> s.Id = id)).Data

                for i = 0 to archive.Manifest.DataShardCount - 1 do
                    let data = getShardData i
                    let offset = i * archive.Manifest.ShardSize
                    let remaining = int archive.Manifest.TotalSize - offset
                    let count = Math.Min(archive.Manifest.ShardSize, remaining)
                    Array.Copy(data, 0, finalBytes, offset, count)
                
                // Verify Reconstruction
                let reconHash = sha256 finalBytes
                if reconHash = archive.Manifest.OriginalHash then
                    printfn "✅ [IMMUNE] Recovery Verified. Genetic Sequence Intact."
                    Success finalBytes
                else
                    Failure "CRITICAL: Recovery failed hash verification. Too much damage?"

            | _ ->
                Failure $"CRITICAL: Multiple failures ({corruptedIds.Length}). This implementation supports Single Block Failure (RAID-5). System is irretrievable."

        with e ->
            Failure $"Healing failed: {e.Message}"
