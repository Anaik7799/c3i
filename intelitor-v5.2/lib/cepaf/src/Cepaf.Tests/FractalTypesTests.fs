namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Observability.Fractal

/// Fractal Types Unit Tests
/// STAMP Compliance: SC-LOG-001 to SC-LOG-010, TDG-001, TDG-002, TDG-003
/// AOR Compliance: AOR-LOG-001 (Patient Mode), AOR-LOG-002 (Level Validation)
/// Test Coverage: All Fractal core types, safety constraint validators
module FractalTypesTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS (TDG-001)
    // ========================================================================

    /// Create a valid HLC timestamp
    let makeHLCTimestamp () : HLCTimestamp = {
        Physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L
        Counter = 0
        NodeId = "node-001"
    }

    /// Create a valid Lens
    let makeLens () : Lens = {
        Target = "Indrajaal/Alarms/**"
        Depth = FractalLevel.L3
        Filter = Map.empty
        TtlMs = 300_000L
    }

    /// Create a valid Boost
    let makeBoost () : Boost = {
        Id = "boost-001"
        KeyExpr = "Indrajaal/Security/**"
        CompiledPattern = None
        Depth = FractalLevel.L2
        Filter = Map.empty
        CreatedAt = DateTimeOffset.UtcNow
        ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(5.0)
        CreatedBy = "test-agent"
    }

    /// Create a boost with custom TTL
    let makeBoostWithTtl (ttlMs: int64) : Boost =
        let now = DateTimeOffset.UtcNow
        {
            Id = sprintf "boost-%d" (now.ToUnixTimeMilliseconds())
            KeyExpr = "**"
            CompiledPattern = None
            Depth = FractalLevel.L1
            Filter = Map.empty
            CreatedAt = now
            ExpiresAt = now.AddMilliseconds(float ttlMs)
            CreatedBy = "test"
        }

    /// Create a valid FractalLogEntry
    let makeLogEntry (level: FractalLevel) : FractalLogEntry = {
        Key = "Indrajaal/Alarms/create"
        KeyAlias = None
        HLC = makeHLCTimestamp ()
        FractalLevel = level
        Priority = Priority.fromLevel level
        EventType = EventType.Entry
        TraceId = Some "trace-12345678"
        SpanId = Some "span-1234"
        ParentSpanId = None
        Payload = FractalPayload.Text "Test log entry"
        Baggage = Map.empty
        Tags = ["alarm"; "create"]
        Timestamp = DateTimeOffset.UtcNow
        Duration = None
        Node = "node-001"
        Module = "Indrajaal.Alarms"
        Function = "create"
        Arity = 2
    }

    /// Create an expired boost
    let makeExpiredBoost () : Boost = {
        Id = "expired-001"
        KeyExpr = "**"
        CompiledPattern = None
        Depth = FractalLevel.L1
        Filter = Map.empty
        CreatedAt = DateTimeOffset.UtcNow.AddMinutes(-10.0)
        ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-5.0)
        CreatedBy = "test"
    }

    // ========================================================================
    // FRACTAL LEVEL TESTS (5 Levels: L1-L5)
    // ========================================================================

    [<Fact>]
    let ``FractalLevel toInt returns correct values for all levels`` () =
        Assert.Equal(1, FractalLevel.toInt FractalLevel.L1)
        Assert.Equal(2, FractalLevel.toInt FractalLevel.L2)
        Assert.Equal(3, FractalLevel.toInt FractalLevel.L3)
        Assert.Equal(4, FractalLevel.toInt FractalLevel.L4)
        Assert.Equal(5, FractalLevel.toInt FractalLevel.L5)

    [<Fact>]
    let ``FractalLevel fromInt returns correct level`` () =
        Assert.Equal(FractalLevel.L1, FractalLevel.fromInt 1)
        Assert.Equal(FractalLevel.L2, FractalLevel.fromInt 2)
        Assert.Equal(FractalLevel.L3, FractalLevel.fromInt 3)
        Assert.Equal(FractalLevel.L4, FractalLevel.fromInt 4)
        Assert.Equal(FractalLevel.L5, FractalLevel.fromInt 5)

    [<Fact>]
    let ``FractalLevel fromInt defaults to L5 for invalid values`` () =
        Assert.Equal(FractalLevel.L5, FractalLevel.fromInt 0)
        Assert.Equal(FractalLevel.L5, FractalLevel.fromInt 6)
        Assert.Equal(FractalLevel.L5, FractalLevel.fromInt -1)

    [<Theory>]
    [<InlineData("L1", true)>]
    [<InlineData("L2", true)>]
    [<InlineData("L3", true)>]
    [<InlineData("L4", true)>]
    [<InlineData("L5", true)>]
    [<InlineData("l1", true)>]
    [<InlineData("l5", true)>]
    [<InlineData("X1", false)>]
    [<InlineData("", false)>]
    [<InlineData("L6", false)>]
    let ``FractalLevel parse handles valid and invalid inputs`` (input: string) (shouldSucceed: bool) =
        let result = FractalLevel.parse input
        Assert.Equal(shouldSucceed, result.IsSome)

    [<Fact>]
    let ``FractalLevel toString roundtrips correctly`` () =
        for level in [FractalLevel.L1; FractalLevel.L2; FractalLevel.L3; FractalLevel.L4; FractalLevel.L5] do
            let str = FractalLevel.toString level
            let parsed = FractalLevel.parse str
            Assert.True(parsed.IsSome)
            Assert.Equal(level, parsed.Value)

    [<Fact>]
    let ``FractalLevel description contains meaningful text`` () =
        Assert.Contains("Atomic", FractalLevel.description FractalLevel.L1)
        Assert.Contains("Component", FractalLevel.description FractalLevel.L2)
        Assert.Contains("Transactional", FractalLevel.description FractalLevel.L3)
        Assert.Contains("Systemic", FractalLevel.description FractalLevel.L4)
        Assert.Contains("Cognitive", FractalLevel.description FractalLevel.L5)

    // ========================================================================
    // PRIORITY TESTS (P0-P3 mapping)
    // ========================================================================

    [<Fact>]
    let ``Priority fromLevel returns P0 for L4 and L5`` () =
        Assert.Equal(Priority.P0, Priority.fromLevel FractalLevel.L4)
        Assert.Equal(Priority.P0, Priority.fromLevel FractalLevel.L5)

    [<Fact>]
    let ``Priority fromLevel returns P1 for L3`` () =
        Assert.Equal(Priority.P1, Priority.fromLevel FractalLevel.L3)

    [<Fact>]
    let ``Priority fromLevel returns P2 for L2`` () =
        Assert.Equal(Priority.P2, Priority.fromLevel FractalLevel.L2)

    [<Fact>]
    let ``Priority fromLevel returns P3 for L1`` () =
        Assert.Equal(Priority.P3, Priority.fromLevel FractalLevel.L1)

    [<Fact>]
    let ``Priority samplingRate returns correct values`` () =
        Assert.Equal(1.0, Priority.samplingRate Priority.P0)   // Never drop
        Assert.Equal(0.10, Priority.samplingRate Priority.P1)  // 10% sampling
        Assert.Equal(0.01, Priority.samplingRate Priority.P2)  // 1% sampling
        Assert.Equal(0.0, Priority.samplingRate Priority.P3)   // Disabled

    [<Fact>]
    let ``Priority toInt and fromInt roundtrip`` () =
        for p in [Priority.P0; Priority.P1; Priority.P2; Priority.P3] do
            let i = Priority.toInt p
            let back = Priority.fromInt i
            Assert.Equal(p, back)

    // ========================================================================
    // LENS TESTS (Directed Telescope Control)
    // ========================================================================

    [<Fact>]
    let ``Lens defaultLens has correct values`` () =
        let lens = Lens.defaultLens
        Assert.Equal("**", lens.Target)
        Assert.Equal(FractalLevel.L4, lens.Depth)
        Assert.True(lens.Filter.IsEmpty)
        Assert.Equal(300_000L, lens.TtlMs)

    [<Fact>]
    let ``Lens focus creates correct lens`` () =
        let lens = Lens.focus "Indrajaal/Alarms/**" FractalLevel.L2 60_000L
        Assert.Equal("Indrajaal/Alarms/**", lens.Target)
        Assert.Equal(FractalLevel.L2, lens.Depth)
        Assert.Equal(60_000L, lens.TtlMs)
        Assert.True(lens.Filter.IsEmpty)

    [<Fact>]
    let ``Lens withFilter adds filter correctly`` () =
        let lens =
            Lens.defaultLens
            |> Lens.withFilter "user_id" "123"
            |> Lens.withFilter "tenant_id" "tenant-abc"

        Assert.Equal(2, lens.Filter.Count)
        Assert.Equal("123", lens.Filter.["user_id"])
        Assert.Equal("tenant-abc", lens.Filter.["tenant_id"])

    // ========================================================================
    // BOOST TESTS (SC-LOG-005: TTL Mandatory)
    // ========================================================================

    [<Fact>]
    let ``Boost create sets default 5 minute TTL`` () =
        let boost = Boost.create "**" FractalLevel.L1 "test-creator"
        let ttlMs = (boost.ExpiresAt - boost.CreatedAt).TotalMilliseconds
        Assert.True(ttlMs >= 299_000.0 && ttlMs <= 301_000.0)  // ~5 minutes

    [<Fact>]
    let ``Boost createWithTtl sets custom TTL`` () =
        let customTtl = 120_000  // 2 minutes (int, not int64)
        let boost = Boost.createWithTtl "**" FractalLevel.L2 customTtl "test"
        let ttlMs = (boost.ExpiresAt - boost.CreatedAt).TotalMilliseconds
        Assert.True(ttlMs >= 119_000.0 && ttlMs <= 121_000.0)

    [<Fact>]
    let ``Boost isExpired returns false for active boost`` () =
        let boost = makeBoost ()
        Assert.False(Boost.isExpired boost)

    [<Fact>]
    let ``Boost isExpired returns true for expired boost`` () =
        let boost = makeExpiredBoost ()
        Assert.True(Boost.isExpired boost)

    [<Fact>]
    let ``Boost withFilter adds filter correctly`` () =
        let boost =
            makeBoost ()
            |> Boost.withFilter "trace_flag" "debug"

        Assert.Equal(1, boost.Filter.Count)
        Assert.Equal("debug", boost.Filter.["trace_flag"])

    [<Fact>]
    let ``Boost Id is 8 characters`` () =
        let boost = Boost.create "**" FractalLevel.L1 "test"
        Assert.Equal(8, boost.Id.Length)

    // ========================================================================
    // HLC TIMESTAMP TESTS (SC-LOG-006: L3+ must use HLC)
    // ========================================================================

    [<Fact>]
    let ``HLCTimestamp compare orders by physical time first`` () =
        let a = { Physical = 1000L; Counter = 5; NodeId = "a" }
        let b = { Physical = 2000L; Counter = 1; NodeId = "b" }
        Assert.True(HLCTimestamp.compare a b < 0)
        Assert.True(HLCTimestamp.compare b a > 0)

    [<Fact>]
    let ``HLCTimestamp compare uses counter when physical equal`` () =
        let a = { Physical = 1000L; Counter = 1; NodeId = "a" }
        let b = { Physical = 1000L; Counter = 5; NodeId = "b" }
        Assert.True(HLCTimestamp.compare a b < 0)
        Assert.True(HLCTimestamp.compare b a > 0)

    [<Fact>]
    let ``HLCTimestamp compare returns 0 for equal timestamps`` () =
        let a = { Physical = 1000L; Counter = 1; NodeId = "a" }
        let b = { Physical = 1000L; Counter = 1; NodeId = "b" }
        Assert.Equal(0, HLCTimestamp.compare a b)

    [<Fact>]
    let ``HLCTimestamp fromPhysical creates valid timestamp`` () =
        let hlc = HLCTimestamp.fromPhysical 12345678L
        Assert.Equal(12345678L, hlc.Physical)
        Assert.Equal(0, hlc.Counter)
        Assert.Equal("", hlc.NodeId)

    // ========================================================================
    // EVENT TYPE TESTS
    // ========================================================================

    [<Fact>]
    let ``EventType toInt returns correct values`` () =
        Assert.Equal(0, EventType.toInt EventType.Entry)
        Assert.Equal(1, EventType.toInt EventType.Exit)
        Assert.Equal(2, EventType.toInt EventType.Exception)
        Assert.Equal(3, EventType.toInt EventType.State)
        Assert.Equal(4, EventType.toInt EventType.Metric)
        Assert.Equal(5, EventType.toInt EventType.Intent)

    [<Fact>]
    let ``EventType fromInt roundtrips correctly`` () =
        for i in 0..5 do
            let evt = EventType.fromInt i
            let back = EventType.toInt evt
            Assert.Equal(i, back)

    // ========================================================================
    // FRACTAL PAYLOAD TESTS
    // ========================================================================

    [<Fact>]
    let ``FractalPayload Empty is distinct`` () =
        let payload = FractalPayload.Empty
        match payload with
        | FractalPayload.Empty -> Assert.True(true)
        | _ -> Assert.Fail("Expected Empty payload")

    [<Fact>]
    let ``FractalPayload Text contains message`` () =
        let payload = FractalPayload.Text "Hello World"
        match payload with
        | FractalPayload.Text msg -> Assert.Equal("Hello World", msg)
        | _ -> Assert.Fail("Expected Text payload")

    [<Fact>]
    let ``FractalPayload Json contains valid JSON`` () =
        let json = """{"key": "value"}"""
        let payload = FractalPayload.Json json
        match payload with
        | FractalPayload.Json j -> Assert.Contains("key", j)
        | _ -> Assert.Fail("Expected Json payload")

    [<Fact>]
    let ``FractalPayload Binary contains bytes`` () =
        let bytes = [| 0x01uy; 0x02uy; 0x03uy |]
        let payload = FractalPayload.Binary bytes
        match payload with
        | FractalPayload.Binary b -> Assert.Equal(3, b.Length)
        | _ -> Assert.Fail("Expected Binary payload")

    [<Fact>]
    let ``FractalPayload Structured contains key-value pairs`` () =
        let fields = [("name", box "test"); ("count", box 42)]
        let payload = FractalPayload.Structured fields
        match payload with
        | FractalPayload.Structured f ->
            Assert.Equal(2, f.Length)
            Assert.Equal("name", fst f.[0])
        | _ -> Assert.Fail("Expected Structured payload")

    // ========================================================================
    // SAFETY CONSTRAINT VALIDATION TESTS (SC-LOG-005, SC-LOG-006)
    // ========================================================================

    [<Fact>]
    let ``SC-LOG-005 validateBoostTtl passes for valid boost`` () =
        let boost = makeBoost ()
        let result = SafetyConstraints.validateBoostTtl boost
        Assert.True(result.Passed)
        Assert.Equal("SC-LOG-005", result.ConstraintId)
        Assert.Contains("TTL", result.Details)

    [<Fact>]
    let ``SC-LOG-005 validateBoostTtl fails for invalid TTL`` () =
        let invalidBoost = {
            makeBoost () with
                ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-1.0)
                CreatedAt = DateTimeOffset.UtcNow
        }
        let result = SafetyConstraints.validateBoostTtl invalidBoost
        Assert.False(result.Passed)
        Assert.Equal("SC-LOG-005", result.ConstraintId)

    [<Fact>]
    let ``SC-LOG-006 validateHLCPresent passes for L3+ with HLC`` () =
        let entry = makeLogEntry FractalLevel.L3
        let result = SafetyConstraints.validateHLCPresent entry
        Assert.True(result.Passed)
        Assert.Equal("SC-LOG-006", result.ConstraintId)

    [<Fact>]
    let ``SC-LOG-006 validateHLCPresent passes for L4 with HLC`` () =
        let entry = makeLogEntry FractalLevel.L4
        let result = SafetyConstraints.validateHLCPresent entry
        Assert.True(result.Passed)

    [<Fact>]
    let ``SC-LOG-006 validateHLCPresent passes for L5 with HLC`` () =
        let entry = makeLogEntry FractalLevel.L5
        let result = SafetyConstraints.validateHLCPresent entry
        Assert.True(result.Passed)

    [<Fact>]
    let ``SC-LOG-006 validateHLCPresent passes for L1/L2 without HLC`` () =
        let entry = { makeLogEntry FractalLevel.L1 with HLC = { Physical = 0L; Counter = 0; NodeId = "" } }
        let result = SafetyConstraints.validateHLCPresent entry
        Assert.True(result.Passed)  // L1/L2 don't require HLC

    [<Fact>]
    let ``SC-LOG-006 validateHLCPresent fails for L3+ without HLC`` () =
        let entry = { makeLogEntry FractalLevel.L3 with HLC = { Physical = 0L; Counter = 0; NodeId = "" } }
        let result = SafetyConstraints.validateHLCPresent entry
        Assert.False(result.Passed)
        Assert.Contains("missing HLC", result.Details)

    // ========================================================================
    // SAFETY CONSTRAINT IDS TESTS
    // ========================================================================

    [<Fact>]
    let ``SafetyConstraints has all 10 constraint IDs`` () =
        Assert.Equal("SC-LOG-001", SafetyConstraints.scLog001)
        Assert.Equal("SC-LOG-002", SafetyConstraints.scLog002)
        Assert.Equal("SC-LOG-003", SafetyConstraints.scLog003)
        Assert.Equal("SC-LOG-004", SafetyConstraints.scLog004)
        Assert.Equal("SC-LOG-005", SafetyConstraints.scLog005)
        Assert.Equal("SC-LOG-006", SafetyConstraints.scLog006)
        Assert.Equal("SC-LOG-007", SafetyConstraints.scLog007)
        Assert.Equal("SC-LOG-008", SafetyConstraints.scLog008)
        Assert.Equal("SC-LOG-009", SafetyConstraints.scLog009)
        Assert.Equal("SC-LOG-010", SafetyConstraints.scLog010)

    // ========================================================================
    // FRACTAL LOG ENTRY TESTS
    // ========================================================================

    [<Fact>]
    let ``FractalLogEntry has all required fields`` () =
        let entry = makeLogEntry FractalLevel.L3
        Assert.NotNull(entry.Key)
        Assert.True(entry.HLC.Physical > 0L)
        Assert.NotNull(entry.Node)
        Assert.NotNull(entry.Module)
        Assert.NotNull(entry.Function)

    [<Theory>]
    [<InlineData(1)>]
    [<InlineData(2)>]
    [<InlineData(3)>]
    [<InlineData(4)>]
    [<InlineData(5)>]
    let ``FractalLogEntry priority matches level`` (level: int) =
        let fractalLevel = FractalLevel.fromInt level
        let entry = makeLogEntry fractalLevel
        let expectedPriority = Priority.fromLevel fractalLevel
        Assert.Equal(expectedPriority, entry.Priority)

    [<Fact>]
    let ``FractalLogEntry with TraceId is valid`` () =
        let entry = makeLogEntry FractalLevel.L3
        Assert.True(entry.TraceId.IsSome)
        Assert.Equal("trace-12345678", entry.TraceId.Value)

    [<Fact>]
    let ``FractalLogEntry tags are preserved`` () =
        let entry = makeLogEntry FractalLevel.L3
        Assert.Equal(2, entry.Tags.Length)
        Assert.Contains("alarm", entry.Tags)
        Assert.Contains("create", entry.Tags)

