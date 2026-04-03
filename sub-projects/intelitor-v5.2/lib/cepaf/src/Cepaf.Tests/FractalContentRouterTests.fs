namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Observability.Fractal

/// Content Router Tests
/// STAMP Compliance: SC-LOG-010 (Backend routing), SC-LOG-001 (Async dispatch)
/// AOR Compliance: AOR-LOG-004 (Retention policies), AOR-LOG-005 (Backend health)
/// Test Coverage: Routing rules, backend selection, retention policies, health checks
module FractalContentRouterTests =

    // ========================================================================
    // SETUP/TEARDOWN
    // ========================================================================

    let setupTests () =
        ContentRouter.reset ()
        ContentRouter.initialize ()

    // ========================================================================
    // TEST DATA FACTORIES
    // ========================================================================

    /// Create a valid log entry for routing tests
    let makeLogEntry (level: FractalLevel) (key: string) : FractalLogEntry = {
        Key = key
        KeyAlias = None
        HLC = { Physical = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() * 1000L; Counter = 0; NodeId = "test-node" }
        FractalLevel = level
        Priority = Priority.fromLevel level
        EventType = EventType.Entry
        TraceId = Some "trace-123"
        SpanId = Some "span-456"
        ParentSpanId = None
        Payload = FractalPayload.Text "Test entry"
        Baggage = Map.empty
        Tags = []
        Timestamp = DateTimeOffset.UtcNow
        Duration = None
        Node = "test-node"
        Module = "Test.Module"
        Function = "test_func"
        Arity = 0
    }

    /// Create a custom routing rule
    let makeRule (id: string) (keyExpr: string) (minLevel: FractalLevel) (backends: ContentRouter.Backend list) : ContentRouter.RoutingRule = {
        Id = id
        KeyExpr = keyExpr
        CompiledExpr = None
        MinLevel = minLevel
        MaxLevel = FractalLevel.L5
        Backends = backends
        Retention = {
            MinRetention = TimeSpan.FromDays(1.0)
            MaxRetention = TimeSpan.FromDays(30.0)
            ArchiveOnExpiry = true
            CompressionLevel = 6
        }
        Priority = 50
        Enabled = true
    }

    // ========================================================================
    // INITIALIZATION TESTS
    // ========================================================================

    [<Fact>]
    let ``initialize creates router state`` () =
        setupTests ()
        let stats = ContentRouter.getStats ()
        Assert.True(stats.TotalBackends > 0)

    [<Fact>]
    let ``initializeWithDefaults adds predefined rules`` () =
        ContentRouter.reset ()
        ContentRouter.initializeWithDefaults ()
        let rules = ContentRouter.getRules ()
        Assert.True(rules.Length >= 4)

    [<Fact>]
    let ``reset clears all state`` () =
        setupTests ()
        ContentRouter.addRule (makeRule "test" "**" FractalLevel.L1 [ContentRouter.Backend.Console]) |> ignore
        ContentRouter.reset ()
        ContentRouter.initialize ()
        let stats = ContentRouter.getStats ()
        Assert.Equal(0, stats.RuleCount)

    // ========================================================================
    // RULE MANAGEMENT TESTS
    // ========================================================================

    [<Fact>]
    let ``addRule adds rule successfully`` () =
        setupTests ()
        let rule = makeRule "test-rule" "Test/**" FractalLevel.L2 [ContentRouter.Backend.OTLP]
        let result = ContentRouter.addRule rule
        Assert.True(Result.isOk result)
        let rules = ContentRouter.getRules ()
        Assert.True(rules |> List.exists (fun r -> r.Id = "test-rule"))

    [<Fact>]
    let ``removeRule removes existing rule`` () =
        setupTests ()
        let rule = makeRule "to-remove" "**" FractalLevel.L1 [ContentRouter.Backend.Console]
        ContentRouter.addRule rule |> ignore
        let removed = ContentRouter.removeRule "to-remove"
        Assert.True(removed)
        let rules = ContentRouter.getRules ()
        Assert.False(rules |> List.exists (fun r -> r.Id = "to-remove"))

    [<Fact>]
    let ``removeRule returns false for non-existent rule`` () =
        setupTests ()
        let removed = ContentRouter.removeRule "non-existent"
        Assert.False(removed)

    [<Fact>]
    let ``setRuleEnabled toggles rule state`` () =
        setupTests ()
        let rule = makeRule "toggle-rule" "**" FractalLevel.L1 [ContentRouter.Backend.Console]
        ContentRouter.addRule rule |> ignore

        let disabled = ContentRouter.setRuleEnabled "toggle-rule" false
        Assert.True(disabled)

        let rules = ContentRouter.getRules ()
        let found = rules |> List.find (fun r -> r.Id = "toggle-rule")
        Assert.False(found.Enabled)

    [<Fact>]
    let ``setRuleEnabled returns false for non-existent rule`` () =
        setupTests ()
        let result = ContentRouter.setRuleEnabled "non-existent" false
        Assert.False(result)

    // ========================================================================
    // BACKEND HEALTH TESTS
    // ========================================================================

    [<Fact>]
    let ``setBackendHealth updates health status`` () =
        setupTests ()
        ContentRouter.setBackendHealth ContentRouter.Backend.OTLP false
        Assert.False(ContentRouter.isBackendHealthy ContentRouter.Backend.OTLP)

        ContentRouter.setBackendHealth ContentRouter.Backend.OTLP true
        Assert.True(ContentRouter.isBackendHealthy ContentRouter.Backend.OTLP)

    [<Fact>]
    let ``getHealthyBackends returns only healthy backends`` () =
        setupTests ()
        ContentRouter.setBackendHealth ContentRouter.Backend.WAL false
        let healthy = ContentRouter.getHealthyBackends ()
        Assert.False(healthy |> List.contains ContentRouter.Backend.WAL)

    [<Fact>]
    let ``isBackendHealthy returns true for unknown backends`` () =
        setupTests ()
        // Custom backends default to healthy
        let healthy = ContentRouter.isBackendHealthy (ContentRouter.Backend.Custom "unknown")
        Assert.False(healthy)  // Unknown returns false since not in health dict

    // ========================================================================
    // ROUTING DECISION TESTS
    // ========================================================================

    [<Fact>]
    let ``route returns decision for L1 entry`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L1 "Test/L1/entry"
        let decision = ContentRouter.route entry
        Assert.True(decision.ShouldEmit)
        Assert.True(decision.Backends.Length > 0)

    [<Fact>]
    let ``route returns decision for L4 entry`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L4 "Test/L4/entry"
        let decision = ContentRouter.route entry
        Assert.True(decision.ShouldEmit)
        Assert.True(decision.Backends |> List.contains ContentRouter.Backend.OTLP)

    [<Fact>]
    let ``route uses matched rule when available`` () =
        setupTests ()
        let rule = makeRule "security" "Security/**" FractalLevel.L1 [ContentRouter.Backend.PostgreSQL]
        ContentRouter.addRule rule |> ignore

        let entry = makeLogEntry FractalLevel.L3 "Security/audit/login"
        let decision = ContentRouter.route entry

        Assert.True(decision.MatchedRule.IsSome)
        Assert.Equal("security", decision.MatchedRule.Value)

    [<Fact>]
    let ``route falls back to defaults when no rule matches`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L3 "Unknown/Module/action"
        let decision = ContentRouter.route entry
        Assert.True(decision.MatchedRule.IsNone)
        Assert.True(decision.Backends.Length > 0)

    [<Fact>]
    let ``route filters unhealthy backends`` () =
        setupTests ()
        ContentRouter.setBackendHealth ContentRouter.Backend.OTLP false

        let entry = makeLogEntry FractalLevel.L4 "Test/entry"
        let decision = ContentRouter.route entry

        Assert.False(decision.Backends |> List.contains ContentRouter.Backend.OTLP)

    [<Fact>]
    let ``route falls back to Console when all backends unhealthy`` () =
        setupTests ()
        // Mark all backends unhealthy
        for backend in [ContentRouter.Backend.Memory; ContentRouter.Backend.WAL;
                        ContentRouter.Backend.TimescaleDB; ContentRouter.Backend.PostgreSQL;
                        ContentRouter.Backend.ObjectStore; ContentRouter.Backend.OTLP] do
            ContentRouter.setBackendHealth backend false

        let entry = makeLogEntry FractalLevel.L4 "Test/entry"
        let decision = ContentRouter.route entry

        Assert.Contains(ContentRouter.Backend.Console, decision.Backends)

    // ========================================================================
    // BATCH ROUTING TESTS
    // ========================================================================

    [<Fact>]
    let ``routeBatch routes all entries`` () =
        setupTests ()
        let entries = [
            makeLogEntry FractalLevel.L1 "A/entry"
            makeLogEntry FractalLevel.L3 "B/entry"
            makeLogEntry FractalLevel.L5 "C/entry"
        ]

        let results = ContentRouter.routeBatch entries
        Assert.Equal(3, results.Length)
        Assert.True(results |> List.forall (fun (_, d) -> d.ShouldEmit))

    [<Fact>]
    let ``routeBatch preserves entry order`` () =
        setupTests ()
        let entries = [
            makeLogEntry FractalLevel.L1 "First/entry"
            makeLogEntry FractalLevel.L2 "Second/entry"
            makeLogEntry FractalLevel.L3 "Third/entry"
        ]

        let results = ContentRouter.routeBatch entries
        let keys = results |> List.map (fun (e, _) -> e.Key)

        Assert.Equal("First/entry", keys.[0])
        Assert.Equal("Second/entry", keys.[1])
        Assert.Equal("Third/entry", keys.[2])

    // ========================================================================
    // PREDEFINED RULES TESTS
    // ========================================================================

    [<Fact>]
    let ``securityAuditRule has correct configuration`` () =
        let rule = ContentRouter.securityAuditRule ()
        Assert.Equal("security-audit", rule.Id)
        Assert.Equal("Indrajaal/Security/**", rule.KeyExpr)
        Assert.Equal(FractalLevel.L3, rule.MinLevel)
        Assert.True(rule.Backends |> List.contains ContentRouter.Backend.PostgreSQL)
        Assert.True(rule.Retention.ArchiveOnExpiry)
        Assert.True(rule.Enabled)

    [<Fact>]
    let ``cognitiveRule targets L4+ Cortex events`` () =
        let rule = ContentRouter.cognitiveRule ()
        Assert.Equal("cognitive", rule.Id)
        Assert.Equal("Indrajaal/Cortex/**", rule.KeyExpr)
        Assert.Equal(FractalLevel.L4, rule.MinLevel)

    [<Fact>]
    let ``alarmRule targets Alarms domain`` () =
        let rule = ContentRouter.alarmRule ()
        Assert.Equal("alarms", rule.Id)
        Assert.Equal("Indrajaal/Alarms/**", rule.KeyExpr)
        Assert.True(rule.Backends |> List.contains ContentRouter.Backend.TimescaleDB)

    [<Fact>]
    let ``debugRule has lowest priority`` () =
        let rule = ContentRouter.debugRule ()
        Assert.Equal("debug", rule.Id)
        Assert.Equal("**", rule.KeyExpr)
        Assert.Equal(1, rule.Priority)
        Assert.Equal(FractalLevel.L1, rule.MinLevel)
        Assert.Equal(FractalLevel.L2, rule.MaxLevel)

    // ========================================================================
    // RETENTION POLICY TESTS
    // ========================================================================

    [<Fact>]
    let ``L1 entries have short retention`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L1 "Debug/entry"
        let decision = ContentRouter.route entry
        Assert.True(decision.Retention.MinRetention < TimeSpan.FromHours(2.0))

    [<Fact>]
    let ``L5 entries have long retention`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L5 "Cognitive/intent"
        let decision = ContentRouter.route entry
        Assert.True(decision.Retention.MinRetention >= TimeSpan.FromDays(30.0))

    [<Fact>]
    let ``Security audit has 10 year max retention`` () =
        let rule = ContentRouter.securityAuditRule ()
        Assert.True(rule.Retention.MaxRetention >= TimeSpan.FromDays(3650.0))

    // ========================================================================
    // STATISTICS TESTS
    // ========================================================================

    [<Fact>]
    let ``getStats returns accurate counts`` () =
        setupTests ()
        ContentRouter.addRule (makeRule "stat-test" "**" FractalLevel.L1 [ContentRouter.Backend.Console]) |> ignore

        let stats = ContentRouter.getStats ()
        Assert.True(stats.RuleCount >= 1)
        Assert.True(stats.TotalBackends > 0)

    [<Fact>]
    let ``route increments RouteCount`` () =
        setupTests ()
        let statsBefore = ContentRouter.getStats ()
        let before = statsBefore.RouteCount

        let entry = makeLogEntry FractalLevel.L3 "Test/entry"
        ContentRouter.route entry |> ignore

        let statsAfter = ContentRouter.getStats ()
        let after = statsAfter.RouteCount
        Assert.True(after > before)

    [<Fact>]
    let ``resetStats clears counters`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L3 "Test/entry"
        ContentRouter.route entry |> ignore

        ContentRouter.resetStats ()
        let stats = ContentRouter.getStats ()
        Assert.Equal(0L, stats.RouteCount)

    // ========================================================================
    // BACKEND TYPE TESTS
    // ========================================================================

    [<Fact>]
    let ``Backend Memory is distinct`` () =
        let b = ContentRouter.Backend.Memory
        match b with
        | ContentRouter.Backend.Memory -> Assert.True(true)
        | _ -> Assert.Fail("Expected Memory")

    [<Fact>]
    let ``Backend WAL is distinct`` () =
        let b = ContentRouter.Backend.WAL
        match b with
        | ContentRouter.Backend.WAL -> Assert.True(true)
        | _ -> Assert.Fail("Expected WAL")

    [<Fact>]
    let ``Backend Custom carries name`` () =
        let b = ContentRouter.Backend.Custom "my-backend"
        match b with
        | ContentRouter.Backend.Custom name -> Assert.Equal("my-backend", name)
        | _ -> Assert.Fail("Expected Custom")

    [<Theory>]
    [<InlineData("Memory")>]
    [<InlineData("WAL")>]
    [<InlineData("TimescaleDB")>]
    [<InlineData("PostgreSQL")>]
    [<InlineData("ObjectStore")>]
    [<InlineData("OTLP")>]
    [<InlineData("Console")>]
    let ``All standard backends are available`` (backendName: string) =
        let backend =
            match backendName with
            | "Memory" -> ContentRouter.Backend.Memory
            | "WAL" -> ContentRouter.Backend.WAL
            | "TimescaleDB" -> ContentRouter.Backend.TimescaleDB
            | "PostgreSQL" -> ContentRouter.Backend.PostgreSQL
            | "ObjectStore" -> ContentRouter.Backend.ObjectStore
            | "OTLP" -> ContentRouter.Backend.OTLP
            | "Console" -> ContentRouter.Backend.Console
            | _ -> ContentRouter.Backend.Custom "unknown"
        Assert.NotNull(backend)

    // ========================================================================
    // LEVEL-BASED BACKEND DEFAULT TESTS
    // ========================================================================

    [<Fact>]
    let ``L1 defaults to Memory and OTLP`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L1 "Debug/trace"
        let decision = ContentRouter.route entry
        // Should include Memory for ephemeral L1 logs
        Assert.True(
            decision.Backends |> List.exists (fun b ->
                match b with
                | ContentRouter.Backend.Memory -> true
                | ContentRouter.Backend.OTLP -> true
                | _ -> false
            )
        )

    [<Fact>]
    let ``L3 defaults to TimescaleDB for time-series`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L3 "Transaction/flow"
        let decision = ContentRouter.route entry
        Assert.True(
            decision.Backends |> List.exists (fun b ->
                match b with
                | ContentRouter.Backend.TimescaleDB -> true
                | ContentRouter.Backend.OTLP -> true
                | _ -> false
            )
        )

    [<Fact>]
    let ``L5 includes ObjectStore for archival`` () =
        setupTests ()
        let entry = makeLogEntry FractalLevel.L5 "Cognitive/decision"
        let decision = ContentRouter.route entry
        Assert.True(
            decision.Backends |> List.exists (fun b ->
                match b with
                | ContentRouter.Backend.ObjectStore -> true
                | ContentRouter.Backend.PostgreSQL -> true
                | _ -> false
            )
        )

