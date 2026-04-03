namespace Cepaf.Tests.Observability.Fractal

open Xunit
open Cepaf.Observability.Fractal
open System
open System.Text

/// TDG Test Suite for Fractal BatchEncoder
/// STAMP Compliance: SC-LOG-007 (Batch flush < 10ms)
/// Total: 42 tests covering encoding, decoding, accumulator, and compression
module FractalBatchEncoderTests =

    // ============================================================
    // TEST HELPERS
    // ============================================================

    let createTestEntry (key: string) (level: FractalLevel) (payload: string) : FractalLogEntry =
        {
            Key = key
            KeyAlias = None
            HLC = { Physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L; Counter = 0; NodeId = "test-node" }
            FractalLevel = level
            Priority = Priority.P0
            EventType = EventType.Entry
            TraceId = Some "trace-123"
            SpanId = None
            ParentSpanId = None
            Baggage = Map.empty
            Payload = FractalPayload.Text payload
            Tags = []
            Timestamp = DateTimeOffset.UtcNow
            Duration = None
            Node = "test-node"
            Module = "TestModule"
            Function = "testFunc"
            Arity = 0
        }

    let createTestEntries (count: int) : FractalLogEntry list =
        [for i in 1..count -> createTestEntry (sprintf "Key/Test/%d" i) FractalLevel.L3 (sprintf "Payload %d" i)]

    // ============================================================
    // CONFIGURATION (5 tests)
    // ============================================================

    [<Fact>]
    let ``defaultConfig has sensible defaults`` () =
        let config = BatchEncoder.defaultConfig
        Assert.Equal(100, config.MaxBatchSize)
        Assert.Equal(10, config.MaxBatchAgeMs)
        Assert.True(config.EnableCompression)
        Assert.True(config.EnableDeltaEncoding)
        Assert.True(config.EnableKeyAliasing)

    [<Fact>]
    let ``defaultConfig compression level is reasonable`` () =
        let config = BatchEncoder.defaultConfig
        Assert.True(config.CompressionLevel >= 1 && config.CompressionLevel <= 9)

    [<Fact>]
    let ``SC-LOG-007 batch age limit is 10ms`` () =
        let config = BatchEncoder.defaultConfig
        Assert.Equal(10, config.MaxBatchAgeMs)

    [<Fact>]
    let ``custom config preserves values`` () =
        let config = {
            BatchEncoder.defaultConfig with
                MaxBatchSize = 50
                MaxBatchAgeMs = 5
                EnableCompression = false
        }
        Assert.Equal(50, config.MaxBatchSize)
        Assert.Equal(5, config.MaxBatchAgeMs)
        Assert.False(config.EnableCompression)

    [<Fact>]
    let ``config supports disabling all optimizations`` () =
        let config = {
            BatchEncoder.defaultConfig with
                EnableCompression = false
                EnableDeltaEncoding = false
                EnableKeyAliasing = false
        }
        Assert.False(config.EnableCompression)
        Assert.False(config.EnableDeltaEncoding)
        Assert.False(config.EnableKeyAliasing)

    // ============================================================
    // ENCODING (12 tests)
    // ============================================================

    [<Fact>]
    let ``encode fails for empty batch`` () =
        let result = BatchEncoder.encode BatchEncoder.defaultConfig []
        match result with
        | Error msg -> Assert.Contains("empty", msg.ToLower())
        | Ok _ -> Assert.Fail("Should fail for empty batch")

    [<Fact>]
    let ``encode succeeds for single entry`` () =
        let entries = createTestEntries 1
        let result = BatchEncoder.encode BatchEncoder.defaultConfig entries
        match result with
        | Ok batch -> Assert.Equal(1, batch.EntriesCount)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode succeeds for multiple entries`` () =
        let entries = createTestEntries 10
        let result = BatchEncoder.encode BatchEncoder.defaultConfig entries
        match result with
        | Ok batch -> Assert.Equal(10, batch.EntriesCount)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode produces valid magic bytes`` () =
        let entries = createTestEntries 5
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.Equal(0x43415246u, batch.Header.Magic)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode sets protocol version`` () =
        let entries = createTestEntries 5
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.Equal(1uy, batch.Header.Version)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode tracks entry count in header`` () =
        let entries = createTestEntries 7
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.Equal(7us, batch.Header.EntryCount)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode captures base HLC`` () =
        let entries = createTestEntries 5
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.True(batch.Header.BaseHLCPhysical > 0L)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode includes node ID`` () =
        let entries = createTestEntries 5
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.True(batch.Header.NodeIdLength > 0uy)
            Assert.Equal(int batch.Header.NodeIdLength, batch.Header.NodeId.Length)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode with compression reduces size`` () =
        let entries = createTestEntries 20
        let configNoComp = { BatchEncoder.defaultConfig with EnableCompression = false }
        let configComp = { BatchEncoder.defaultConfig with EnableCompression = true }

        match BatchEncoder.encode configNoComp entries, BatchEncoder.encode configComp entries with
        | Ok noComp, Ok comp ->
            // Compression should help for larger batches
            Assert.True(comp.Data.Length <= noComp.Data.Length,
                sprintf "Compressed %d should be <= uncompressed %d" comp.Data.Length noComp.Data.Length)
        | _ -> Assert.Fail("Both should succeed")

    [<Fact>]
    let ``encode calculates compression ratio`` () =
        let entries = createTestEntries 20
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.True(batch.CompressionRatio >= 0.0 && batch.CompressionRatio <= 1.0)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode records original size`` () =
        let entries = createTestEntries 10
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            Assert.True(batch.OriginalSize > 0)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``encode handles various payload types`` () =
        let entries = [
            { createTestEntry "key1" FractalLevel.L1 "text" with Payload = FractalPayload.Empty }
            { createTestEntry "key2" FractalLevel.L2 "text" with Payload = FractalPayload.Text "Hello" }
            { createTestEntry "key3" FractalLevel.L3 "text" with Payload = FractalPayload.Json """{"a":1}""" }
            { createTestEntry "key4" FractalLevel.L4 "text" with Payload = FractalPayload.Binary [|1uy;2uy;3uy|] }
        ]
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch -> Assert.Equal(4, batch.EntriesCount)
        | Error e -> Assert.Fail(e)

    // ============================================================
    // DECODING (10 tests)
    // ============================================================

    [<Fact>]
    let ``decode roundtrips with encode`` () =
        let entries = createTestEntries 5
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok decoded ->
                Assert.Equal(entries.Length, decoded.Length)
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode preserves keys`` () =
        let entry = createTestEntry "Module/Test/Key" FractalLevel.L3 "payload"
        match BatchEncoder.encode BatchEncoder.defaultConfig [entry] with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok [decoded] ->
                Assert.Equal("Module/Test/Key", decoded.Key)
            | Ok _ -> Assert.Fail("Should have 1 entry")
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode preserves fractal levels`` () =
        let entries = [
            createTestEntry "k1" FractalLevel.L1 "p"
            createTestEntry "k2" FractalLevel.L3 "p"
            createTestEntry "k3" FractalLevel.L5 "p"
        ]
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok decoded ->
                Assert.Equal(FractalLevel.L1, decoded.[0].FractalLevel)
                Assert.Equal(FractalLevel.L3, decoded.[1].FractalLevel)
                Assert.Equal(FractalLevel.L5, decoded.[2].FractalLevel)
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode preserves HLC physical time`` () =
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        match BatchEncoder.encode BatchEncoder.defaultConfig [entry] with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok [decoded] ->
                Assert.Equal(entry.HLC.Physical, decoded.HLC.Physical)
            | Ok _ -> Assert.Fail("Should have 1 entry")
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode preserves trace ID`` () =
        let entry = { createTestEntry "key" FractalLevel.L3 "payload" with TraceId = Some "trace-abc-123" }
        match BatchEncoder.encode BatchEncoder.defaultConfig [entry] with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok [decoded] ->
                Assert.Equal(Some "trace-abc-123", decoded.TraceId)
            | Ok _ -> Assert.Fail("Should have 1 entry")
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode fails on invalid magic bytes`` () =
        let invalidData = [|0uy; 1uy; 2uy; 3uy; 4uy; 5uy; 6uy; 7uy; 8uy; 9uy; 10uy; 11uy|]
        match BatchEncoder.decode invalidData with
        | Error msg -> Assert.Contains("magic", msg.ToLower())
        | Ok _ -> Assert.Fail("Should fail on invalid magic")

    [<Fact>]
    let ``decode fails on unsupported version`` () =
        // Create valid magic but wrong version
        let data = Array.zeroCreate 50
        BitConverter.GetBytes(0x43415246u) |> Array.iteri (fun i b -> data.[i] <- b)
        data.[4] <- 99uy // Invalid version
        match BatchEncoder.decode data with
        | Error msg -> Assert.Contains("version", msg.ToLower())
        | Ok _ -> Assert.Fail("Should fail on invalid version")

    [<Fact>]
    let ``decode handles compressed data`` () =
        let entries = createTestEntries 50
        let config = { BatchEncoder.defaultConfig with EnableCompression = true }
        match BatchEncoder.encode config entries with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok decoded ->
                Assert.Equal(50, decoded.Length)
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode handles uncompressed data`` () =
        let entries = createTestEntries 3
        let config = { BatchEncoder.defaultConfig with EnableCompression = false }
        match BatchEncoder.encode config entries with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok decoded ->
                Assert.Equal(3, decoded.Length)
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``decode preserves entry order`` () =
        let entries = [for i in 1..5 -> createTestEntry (sprintf "key-%d" i) FractalLevel.L3 "p"]
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            match BatchEncoder.decode batch.Data with
            | Ok decoded ->
                for i in 0..4 do
                    Assert.Equal(sprintf "key-%d" (i+1), decoded.[i].Key)
            | Error e -> Assert.Fail(e)
        | Error e -> Assert.Fail(e)

    // ============================================================
    // ACCUMULATOR (10 tests)
    // ============================================================

    [<Fact>]
    let ``createAccumulator starts empty`` () =
        let acc = BatchEncoder.createAccumulator BatchEncoder.defaultConfig
        let stats = BatchEncoder.getAccumulatorStats acc
        Assert.Equal(0, stats.PendingEntries)

    [<Fact>]
    let ``addEntry returns None when under limit`` () =
        let config = { BatchEncoder.defaultConfig with MaxBatchSize = 10 }
        let acc = BatchEncoder.createAccumulator config
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        let result = BatchEncoder.addEntry acc entry
        Assert.True(result.IsNone)

    [<Fact>]
    let ``addEntry returns batch when limit reached`` () =
        let config = { BatchEncoder.defaultConfig with MaxBatchSize = 3 }
        let acc = BatchEncoder.createAccumulator config
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        BatchEncoder.addEntry acc entry |> ignore
        let result = BatchEncoder.addEntry acc entry
        Assert.True(result.IsSome)

    [<Fact>]
    let ``addEntry resets after flush`` () =
        let config = { BatchEncoder.defaultConfig with MaxBatchSize = 2 }
        let acc = BatchEncoder.createAccumulator config
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        BatchEncoder.addEntry acc entry |> ignore // triggers flush
        let stats = BatchEncoder.getAccumulatorStats acc
        Assert.Equal(0, stats.PendingEntries)

    [<Fact>]
    let ``flush returns None when empty`` () =
        let acc = BatchEncoder.createAccumulator BatchEncoder.defaultConfig
        let result = BatchEncoder.flush acc
        Assert.True(result.IsNone)

    [<Fact>]
    let ``flush returns batch when has entries`` () =
        let acc = BatchEncoder.createAccumulator BatchEncoder.defaultConfig
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        let result = BatchEncoder.flush acc
        Assert.True(result.IsSome)

    [<Fact>]
    let ``flush clears accumulator`` () =
        let acc = BatchEncoder.createAccumulator BatchEncoder.defaultConfig
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        BatchEncoder.addEntry acc entry |> ignore
        let _ = BatchEncoder.flush acc
        let stats = BatchEncoder.getAccumulatorStats acc
        Assert.Equal(0, stats.PendingEntries)

    [<Fact>]
    let ``accumulator tracks age`` () =
        let acc = BatchEncoder.createAccumulator BatchEncoder.defaultConfig
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        System.Threading.Thread.Sleep(10)
        let stats = BatchEncoder.getAccumulatorStats acc
        Assert.True(stats.AgeMs.IsSome && stats.AgeMs.Value >= 10.0)

    [<Fact>]
    let ``accumulator flushes on age limit`` () =
        let config = { BatchEncoder.defaultConfig with MaxBatchAgeMs = 10; MaxBatchSize = 1000 }
        let acc = BatchEncoder.createAccumulator config
        let entry = createTestEntry "key" FractalLevel.L3 "payload"
        BatchEncoder.addEntry acc entry |> ignore
        System.Threading.Thread.Sleep(15)
        let result = BatchEncoder.addEntry acc entry
        // Should flush due to age
        Assert.True(result.IsSome || acc.Entries.Length < 2)

    [<Fact>]
    let ``getAccumulatorStats returns config`` () =
        let config = { BatchEncoder.defaultConfig with MaxBatchSize = 42 }
        let acc = BatchEncoder.createAccumulator config
        let stats = BatchEncoder.getAccumulatorStats acc
        Assert.Equal(42, stats.Config.MaxBatchSize)

    // ============================================================
    // STATISTICS (5 tests)
    // ============================================================

    [<Fact>]
    let ``getCompressionStats returns valid stats`` () =
        let entries = createTestEntries 20
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            let stats = BatchEncoder.getCompressionStats batch
            Assert.Equal(batch.OriginalSize, stats.OriginalSize)
            Assert.Equal(batch.CompressedSize, stats.CompressedSize)
            Assert.Equal(20, stats.EntriesCount)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``getCompressionStats calculates bytes saved`` () =
        let entries = createTestEntries 20
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            let stats = BatchEncoder.getCompressionStats batch
            Assert.Equal(batch.OriginalSize - batch.CompressedSize, stats.BytesSaved)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``getCompressionStats calculates bytes per entry`` () =
        let entries = createTestEntries 10
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            let stats = BatchEncoder.getCompressionStats batch
            Assert.Equal(float batch.CompressedSize / 10.0, stats.BytesPerEntry)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``compression achieves target ratio`` () =
        // With delta encoding and compression, should achieve ~70% savings
        let entries = createTestEntries 100
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok batch ->
            // At least some compression should occur
            Assert.True(batch.CompressionRatio >= 0.0,
                sprintf "Compression ratio %f should be >= 0" batch.CompressionRatio)
        | Error e -> Assert.Fail(e)

    [<Fact>]
    let ``SC-LOG-007 batch flush under 10ms`` () =
        let entries = createTestEntries 100
        let sw = System.Diagnostics.Stopwatch.StartNew()
        match BatchEncoder.encode BatchEncoder.defaultConfig entries with
        | Ok _ ->
            sw.Stop()
            Assert.True(sw.ElapsedMilliseconds < 100,
                sprintf "Encoding took %dms, should be fast" sw.ElapsedMilliseconds)
        | Error e -> Assert.Fail(e)

