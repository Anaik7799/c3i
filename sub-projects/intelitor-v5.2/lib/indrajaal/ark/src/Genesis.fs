namespace Indrajaal.Ark

open System.IO
open Indrajaal.Ark.Domain

module Genesis =

    // Simple binary serialization format for the DNA file
    // [Header: 4b][ManifestLen: 4b][ManifestBytes][ShardCount: 4b][Shard1Len][Shard1Bytes]...

    let save (archive: DnaArchive) (path: string) : Result<string> =
        try
            use fs = new FileStream(path, FileMode.Create)
            use writer = new BinaryWriter(fs)

            // 1. Magic Bytes (ARK1)
            writer.Write([| 0x41uy; 0x52uy; 0x4Buy; 0x31uy |])

            // 2. Manifest (JSON serialized for readability/debuggability in hex editor)
            let manifestJson = System.Text.Json.JsonSerializer.Serialize(archive.Manifest)
            writer.Write(manifestJson) // BinaryWriter handles length prefix for strings

            // 3. Shards
            writer.Write(archive.Shards.Length)
            for shard in archive.Shards do
                writer.Write(shard.Id)
                writer.Write(match shard.Type with Data -> 0uy | Parity -> 1uy)
                writer.Write(shard.Checksum)
                writer.Write(shard.Data.Length)
                writer.Write(shard.Data)

            Success path
        with e ->
            Failure $"Save failed: {e.Message}"

    let load (path: string) : Result<DnaArchive> =
        try
            use fs = new FileStream(path, FileMode.Open)
            use reader = new BinaryReader(fs)

            // 1. Magic
            let magic = reader.ReadBytes(4)
            if magic <> [| 0x41uy; 0x52uy; 0x4Buy; 0x31uy |] then
                failwith "Invalid DNA File Format"

            // 2. Manifest
            let manifestJson = reader.ReadString()
            let manifest = 
                match System.Text.Json.JsonSerializer.Deserialize<DnaManifest>(manifestJson) with
                | null -> failwith "Invalid Manifest"
                | m -> m

            // 3. Shards
            let count = reader.ReadInt32()
            let mutable shards = []
            
            for _ in 1 .. count do
                let id = reader.ReadInt32()
                let typeByte = reader.ReadByte()
                let sType = if typeByte = 0uy then Data else Parity
                let checksum = reader.ReadString()
                let len = reader.ReadInt32()
                let data = reader.ReadBytes(len)
                
                shards <- { Id = id; Type = sType; Data = data; Checksum = checksum } :: shards

            Success { Manifest = manifest; Shards = List.rev shards }
        with e ->
            Failure $"Load failed: {e.Message}"
