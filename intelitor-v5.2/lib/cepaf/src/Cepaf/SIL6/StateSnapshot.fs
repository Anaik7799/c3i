// =============================================================================
// StateSnapshot.fs - SIL-4 State Snapshot Manager
// =============================================================================
// Aligns with: lib/indrajaal/upgrade/state_snapshot.ex
//
// STAMP Constraints:
//   SC-SIL4-026: Rollback path exists
//   SC-HOLON-017: SHA256 checksum integrity
//   SC-HOLON-007: DuckDB for analytics/history
//   SC-HOLON-009: Holon state fully portable
//
// AOR Rules:
//   AOR-HOLON-003: Portability - Single file copy
//   AOR-HOLON-015: Backup Priority - SQLite/DuckDB files are PRIMARY
//   AOR-HOLON-017: Integrity Verification - SHA256 checksum
//
// 5-Order Effects Analysis:
//   1st Order: State captured to snapshot file
//   2nd Order: SHA256 integrity hash calculated
//   3rd Order: Compression applied, storage optimized
//   4th Order: Retention policy enforced
//   5th Order: Federation snapshot registry updated
// =============================================================================

namespace Cepaf.SIL4

open System
open System.IO
open System.IO.Compression
open System.Security.Cryptography
open System.Text
open System.Collections.Concurrent

/// Snapshot type
type SnapshotType =
    | Full
    | StateOnly
    | ConfigOnly
    | CodeOnly

/// Snapshot metadata
type SnapshotMetadata = {
    SnapshotId: Guid
    SnapshotType: SnapshotType
    CreatedAt: DateTime
    SizeBytes: int64
    CompressedSizeBytes: int64
    Sha256Hash: string
    HolonId: string
    Version: string
    Description: string
    Files: string list
}

/// Snapshot state
type SnapshotState = {
    Metadata: SnapshotMetadata
    FilePath: string
    IsVerified: bool
    LastVerifiedAt: DateTime option
}

/// Snapshot result
type SnapshotResult =
    | SnapshotSuccess of SnapshotState
    | SnapshotFailed of error: string
    | SnapshotCorrupted of SnapshotMetadata * reason: string

/// Restore result
type RestoreResult =
    | RestoreSuccess of SnapshotMetadata
    | RestoreFailed of error: string
    | RestoreRolledBack of reason: string

/// 5-Order effect for snapshots
type SnapshotEffect = {
    Order: int
    SnapshotId: Guid
    Description: string
    SizeInfo: string
    Timestamp: DateTime
}

/// SIL-4 State Snapshot Manager
/// Pre-upgrade state capture with integrity verification per SC-HOLON-017
type StateSnapshotManager(snapshotDir: string) =

    // Configuration
    let maxSnapshots = 10
    let retentionHours = 24.0  // SC-SIL4-026: 24-hour retention

    // Snapshot tracking
    let snapshots = ConcurrentDictionary<Guid, SnapshotState>()
    let effectsLog = ConcurrentDictionary<Guid, SnapshotEffect list>()

    // Ensure snapshot directory exists
    do
        if not (Directory.Exists(snapshotDir)) then
            Directory.CreateDirectory(snapshotDir) |> ignore

    /// Log 5-order effect
    member private this.LogEffect(snapshotId: Guid, order: int, desc: string, sizeInfo: string) =
        let effect = {
            Order = order
            SnapshotId = snapshotId
            Description = desc
            SizeInfo = sizeInfo
            Timestamp = DateTime.UtcNow
        }
        effectsLog.AddOrUpdate(
            snapshotId,
            [effect],
            fun _ existing -> existing @ [effect]) |> ignore

    /// Calculate SHA256 hash (SC-HOLON-017)
    member this.CalculateHash(filePath: string) =
        use sha256 = SHA256.Create()
        use stream = File.OpenRead(filePath)
        let hashBytes = sha256.ComputeHash(stream)
        BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant()

    /// Compress data using zlib/deflate
    member this.CompressData(data: byte[]) =
        use memoryStream = new MemoryStream()
        use deflateStream = new DeflateStream(memoryStream, CompressionLevel.Optimal)
        deflateStream.Write(data, 0, data.Length)
        deflateStream.Close()
        memoryStream.ToArray()

    /// Decompress data
    member this.DecompressData(compressedData: byte[]) =
        use compressedStream = new MemoryStream(compressedData)
        use deflateStream = new DeflateStream(compressedStream, CompressionMode.Decompress)
        use resultStream = new MemoryStream()
        deflateStream.CopyTo(resultStream)
        resultStream.ToArray()

    /// Capture snapshot (SC-SIL4-026)
    member this.Capture(
        snapshotType: SnapshotType,
        holonId: string,
        version: string,
        sourceFiles: string list,
        ?description: string) = async {

        let snapshotId = Guid.NewGuid()
        let desc = defaultArg description (sprintf "%A snapshot for %s" snapshotType holonId)

        // 1st Order: State capture initiated
        this.LogEffect(snapshotId, 1, sprintf "Capturing %A snapshot" snapshotType, "Initializing")

        try
            let snapshotFileName = sprintf "%s_%A_%s.snapshot" holonId snapshotType (snapshotId.ToString("N").[..7])
            let snapshotPath = Path.Combine(snapshotDir, snapshotFileName)

            // Collect files based on type
            let filesToCapture =
                match snapshotType with
                | Full -> sourceFiles
                | StateOnly -> sourceFiles |> List.filter (fun f -> f.EndsWith(".sqlite") || f.EndsWith(".duckdb"))
                | ConfigOnly -> sourceFiles |> List.filter (fun f -> f.EndsWith(".json") || f.EndsWith(".yaml") || f.EndsWith(".toml"))
                | CodeOnly -> sourceFiles |> List.filter (fun f -> f.EndsWith(".beam") || f.EndsWith(".dll"))

            // Create combined snapshot data
            use memoryStream = new MemoryStream()
            use archive = new ZipArchive(memoryStream, ZipArchiveMode.Create, true)

            let mutable totalSize = 0L

            for file in filesToCapture do
                if File.Exists(file) then
                    let entry = archive.CreateEntry(Path.GetFileName(file))
                    use entryStream = entry.Open()
                    use fileStream = File.OpenRead(file)
                    fileStream.CopyTo(entryStream)
                    totalSize <- totalSize + fileStream.Length

            archive.Dispose()

            // 2nd Order: Hash calculation
            let uncompressedData = memoryStream.ToArray()
            this.LogEffect(snapshotId, 2, "Calculating SHA256 hash", sprintf "%d bytes" uncompressedData.Length)

            let hash =
                use sha256 = SHA256.Create()
                BitConverter.ToString(sha256.ComputeHash(uncompressedData)).Replace("-", "").ToLowerInvariant()

            // 3rd Order: Compression
            this.LogEffect(snapshotId, 3, "Compressing snapshot", sprintf "Input: %d bytes" uncompressedData.Length)
            let compressedData = this.CompressData(uncompressedData)

            // Write to file
            File.WriteAllBytes(snapshotPath, compressedData)

            let metadata = {
                SnapshotId = snapshotId
                SnapshotType = snapshotType
                CreatedAt = DateTime.UtcNow
                SizeBytes = totalSize
                CompressedSizeBytes = int64 compressedData.Length
                Sha256Hash = hash
                HolonId = holonId
                Version = version
                Description = desc
                Files = filesToCapture
            }

            let state = {
                Metadata = metadata
                FilePath = snapshotPath
                IsVerified = true
                LastVerifiedAt = Some DateTime.UtcNow
            }

            snapshots.TryAdd(snapshotId, state) |> ignore

            // 4th Order: Retention enforcement
            this.LogEffect(snapshotId, 4, "Enforcing retention policy", sprintf "Max: %d snapshots" maxSnapshots)
            do! this.EnforceRetention()

            // 5th Order: Registry update
            this.LogEffect(snapshotId, 5, "Snapshot registered",
                sprintf "Compressed: %d bytes, Ratio: %.1f%%" compressedData.Length
                    (float compressedData.Length / float uncompressedData.Length * 100.0))

            return SnapshotSuccess state

        with ex ->
            this.LogEffect(snapshotId, 1, sprintf "Capture failed: %s" ex.Message, "Error")
            return SnapshotFailed ex.Message
    }

    /// Verify snapshot integrity (SC-HOLON-017)
    member this.Verify(snapshotId: Guid) =
        match snapshots.TryGetValue(snapshotId) with
        | false, _ ->
            SnapshotFailed "Snapshot not found"
        | true, state ->
            try
                if not (File.Exists(state.FilePath)) then
                    SnapshotCorrupted(state.Metadata, "Snapshot file missing")
                else
                    // Read and decompress
                    let compressedData = File.ReadAllBytes(state.FilePath)
                    let decompressedData = this.DecompressData(compressedData)

                    // Calculate hash
                    let hash =
                        use sha256 = SHA256.Create()
                        BitConverter.ToString(sha256.ComputeHash(decompressedData)).Replace("-", "").ToLowerInvariant()

                    if hash = state.Metadata.Sha256Hash then
                        let updatedState = { state with IsVerified = true; LastVerifiedAt = Some DateTime.UtcNow }
                        snapshots.[snapshotId] <- updatedState
                        SnapshotSuccess updatedState
                    else
                        SnapshotCorrupted(state.Metadata, sprintf "Hash mismatch: expected %s, got %s" state.Metadata.Sha256Hash hash)
            with ex ->
                SnapshotCorrupted(state.Metadata, ex.Message)

    /// Restore from snapshot (SC-SIL4-026)
    member this.Restore(snapshotId: Guid, targetDir: string) = async {
        match snapshots.TryGetValue(snapshotId) with
        | false, _ ->
            return RestoreFailed "Snapshot not found"
        | true, state ->
            try
                // Verify first
                match this.Verify(snapshotId) with
                | SnapshotCorrupted(_, reason) ->
                    return RestoreFailed (sprintf "Snapshot corrupted: %s" reason)
                | SnapshotFailed error ->
                    return RestoreFailed error
                | SnapshotSuccess _ ->
                    // Read and decompress
                    let compressedData = File.ReadAllBytes(state.FilePath)
                    let decompressedData = this.DecompressData(compressedData)

                    // Extract archive
                    use memoryStream = new MemoryStream(decompressedData)
                    use archive = new ZipArchive(memoryStream, ZipArchiveMode.Read)

                    if not (Directory.Exists(targetDir)) then
                        Directory.CreateDirectory(targetDir) |> ignore

                    for entry in archive.Entries do
                        let targetPath = Path.Combine(targetDir, entry.Name)
                        entry.ExtractToFile(targetPath, true)

                    return RestoreSuccess state.Metadata
            with ex ->
                return RestoreFailed ex.Message
    }

    /// Enforce retention policy
    member this.EnforceRetention() = async {
        let now = DateTime.UtcNow
        let expiredThreshold = now.AddHours(-retentionHours)

        // Remove expired snapshots
        let expired =
            snapshots.Values
            |> Seq.filter (fun s -> s.Metadata.CreatedAt < expiredThreshold)
            |> Seq.toList

        for state in expired do
            try
                if File.Exists(state.FilePath) then
                    File.Delete(state.FilePath)
                snapshots.TryRemove(state.Metadata.SnapshotId) |> ignore
            with _ -> ()

        // Remove oldest if over limit
        if snapshots.Count > maxSnapshots then
            let toRemove =
                snapshots.Values
                |> Seq.sortBy (fun s -> s.Metadata.CreatedAt)
                |> Seq.take (snapshots.Count - maxSnapshots)
                |> Seq.toList

            for state in toRemove do
                try
                    if File.Exists(state.FilePath) then
                        File.Delete(state.FilePath)
                    snapshots.TryRemove(state.Metadata.SnapshotId) |> ignore
                with _ -> ()
    }

    /// List all snapshots
    member this.List() =
        snapshots.Values
        |> Seq.map (fun s -> s.Metadata)
        |> Seq.sortByDescending (fun m -> m.CreatedAt)
        |> Seq.toList

    /// Get latest snapshot
    member this.Latest() =
        snapshots.Values
        |> Seq.sortByDescending (fun s -> s.Metadata.CreatedAt)
        |> Seq.tryHead
        |> Option.map (fun s -> s.Metadata)

    /// Get snapshot by ID
    member this.Get(snapshotId: Guid) =
        match snapshots.TryGetValue(snapshotId) with
        | true, state -> Some state
        | false, _ -> None

    /// Delete snapshot
    member this.Delete(snapshotId: Guid) =
        match snapshots.TryGetValue(snapshotId) with
        | false, _ -> false
        | true, state ->
            try
                if File.Exists(state.FilePath) then
                    File.Delete(state.FilePath)
                snapshots.TryRemove(snapshotId) |> ignore
                true
            with _ -> false

    /// Get 5-order effects for snapshot
    member this.GetEffects(snapshotId: Guid) =
        match effectsLog.TryGetValue(snapshotId) with
        | true, effects -> effects
        | false, _ -> []

    /// Get storage statistics
    member this.GetStorageStats() =
        let allSnapshots = snapshots.Values |> Seq.toList
        {|
            TotalSnapshots = allSnapshots.Length
            TotalSizeBytes = allSnapshots |> List.sumBy (fun s -> s.Metadata.SizeBytes)
            TotalCompressedBytes = allSnapshots |> List.sumBy (fun s -> s.Metadata.CompressedSizeBytes)
            OldestSnapshot = allSnapshots |> List.sortBy (fun s -> s.Metadata.CreatedAt) |> List.tryHead |> Option.map (fun s -> s.Metadata.CreatedAt)
            NewestSnapshot = allSnapshots |> List.sortByDescending (fun s -> s.Metadata.CreatedAt) |> List.tryHead |> Option.map (fun s -> s.Metadata.CreatedAt)
            ByType =
                allSnapshots
                |> List.groupBy (fun s -> s.Metadata.SnapshotType)
                |> List.map (fun (t, ss) -> t, ss.Length)
        |}
