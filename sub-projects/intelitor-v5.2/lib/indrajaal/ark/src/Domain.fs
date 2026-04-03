namespace Indrajaal.Ark

open System
open System.Security.Cryptography

module Domain =
    
    type ShardId = int
    
    type ShardType = 
        | Data 
        | Parity

    type Shard = {
        Id: ShardId
        Type: ShardType
        Data: byte[]
        Checksum: string // SHA256 Hash for integrity
    }

    type DnaManifest = {
        Timestamp: DateTime
        TotalSize: int64
        ShardSize: int
        DataShardCount: int
        ParityShardCount: int
        OriginalHash: string // Hash of the pre-sharded tarball
    }

    type DnaArchive = {
        Manifest: DnaManifest
        Shards: Shard list
    }

    // Result type for safety
    type Result<'T> = 
        | Success of 'T
        | Failure of string

    let sha256 (data: byte[]) : string =
        using (SHA256.Create()) (fun sha ->
            let bytes = sha.ComputeHash(data)
            BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant())
