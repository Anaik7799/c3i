namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Observability.Fractal

/// Key Expression Engine Tests
/// STAMP Compliance: SC-LOG-009 (Key aliases pre-registered)
/// AOR Compliance: AOR-LOG-003 (Zenoh-style wildcards)
/// Test Coverage: Compilation, matching, validation, selectors
module FractalKeyExpressionTests =

    // ========================================================================
    // COMPILATION TESTS
    // ========================================================================

    [<Fact>]
    let ``compile succeeds for exact match expression`` () =
        let result = KeyExpression.compile "Indrajaal/Alarms/create"
        Assert.True(Result.isOk result)
        match result with
        | Ok compiled ->
            Assert.True(compiled.IsExact)
            Assert.False(compiled.HasWildcard)
            Assert.False(compiled.HasDoubleWildcard)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``compile succeeds for single wildcard expression`` () =
        let result = KeyExpression.compile "Indrajaal/*/create"
        Assert.True(Result.isOk result)
        match result with
        | Ok compiled ->
            Assert.True(compiled.HasWildcard)
            Assert.False(compiled.HasDoubleWildcard)
            Assert.False(compiled.IsExact)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``compile succeeds for double wildcard expression`` () =
        let result = KeyExpression.compile "Indrajaal/**"
        Assert.True(Result.isOk result)
        match result with
        | Ok compiled ->
            Assert.True(compiled.HasDoubleWildcard)
            Assert.False(compiled.HasWildcard)
            Assert.False(compiled.IsExact)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``compile succeeds for infix wildcard expression`` () =
        let result = KeyExpression.compile "Indrajaal/$*Handler"
        Assert.True(Result.isOk result)
        match result with
        | Ok compiled ->
            Assert.True(compiled.HasInfixWildcard)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``compile normalizes dot separators to slashes`` () =
        let result = KeyExpression.compile "Indrajaal.Alarms.create"
        Assert.True(Result.isOk result)
        match result with
        | Ok compiled ->
            Assert.Equal(3, compiled.Segments.Length)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``compileOrThrow throws for invalid expression`` () =
        Assert.Throws<Exception>(fun () ->
            KeyExpression.compileOrThrow "***" |> ignore
        ) |> ignore

    // ========================================================================
    // EXACT MATCHING TESTS
    // ========================================================================

    [<Fact>]
    let ``matches returns true for exact match`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/Alarms/create"
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms/create")

    [<Fact>]
    let ``matches returns false for different key`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/Alarms/create"
        Assert.False(KeyExpression.matches compiled "Indrajaal/Alarms/delete")

    [<Fact>]
    let ``matches handles dot-to-slash normalization`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/Alarms/create"
        Assert.True(KeyExpression.matches compiled "Indrajaal.Alarms.create")

    // ========================================================================
    // SINGLE WILDCARD (*) MATCHING TESTS
    // ========================================================================

    [<Fact>]
    let ``single wildcard matches one segment`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/*/create"
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms/create")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Security/create")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Accounts/create")

    [<Fact>]
    let ``single wildcard does not match multiple segments`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/*/create"
        Assert.False(KeyExpression.matches compiled "Indrajaal/Alarms/Sub/create")

    [<Fact>]
    let ``single wildcard does not match empty segment`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/*/create"
        Assert.False(KeyExpression.matches compiled "Indrajaal//create")

    // ========================================================================
    // DOUBLE WILDCARD (**) MATCHING TESTS
    // ========================================================================

    [<Fact>]
    let ``double wildcard matches zero segments`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/**"
        Assert.True(KeyExpression.matches compiled "Indrajaal")

    [<Fact>]
    let ``double wildcard matches one segment`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/**"
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms")

    [<Fact>]
    let ``double wildcard matches multiple segments`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/**"
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms/Handler/create")

    [<Fact>]
    let ``double wildcard at end matches any suffix`` () =
        let compiled = KeyExpression.compileOrThrow "**/create"
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms/create")
        Assert.True(KeyExpression.matches compiled "Other/Module/create")
        Assert.True(KeyExpression.matches compiled "create")

    [<Fact>]
    let ``double wildcard in middle matches any path`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/**/error"
        Assert.True(KeyExpression.matches compiled "Indrajaal/error")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Alarms/error")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Deep/Nested/Path/error")

    // ========================================================================
    // INFIX WILDCARD ($*) MATCHING TESTS
    // ========================================================================

    [<Fact>]
    let ``infix wildcard matches suffix pattern`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/$*Handler"
        Assert.True(KeyExpression.matches compiled "Indrajaal/AlarmHandler")
        Assert.True(KeyExpression.matches compiled "Indrajaal/SecurityHandler")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Handler")

    [<Fact>]
    let ``infix wildcard does not match across segments`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/$*Handler"
        Assert.False(KeyExpression.matches compiled "Indrajaal/Alarms/Handler")

    // ========================================================================
    // MATCHESEXPR (CONVENIENCE) TESTS
    // ========================================================================

    [<Fact>]
    let ``matchesExpr compiles and matches in one call`` () =
        Assert.True(KeyExpression.matchesExpr "Indrajaal/**" "Indrajaal/Alarms/create")
        Assert.False(KeyExpression.matchesExpr "Other/**" "Indrajaal/Alarms/create")

    // ========================================================================
    // INTERSECTION TESTS
    // ========================================================================

    [<Fact>]
    let ``intersects returns true for matching exact expressions`` () =
        let a = KeyExpression.compileOrThrow "Indrajaal/Alarms"
        let b = KeyExpression.compileOrThrow "Indrajaal/Alarms"
        Assert.True(KeyExpression.intersects a b)

    [<Fact>]
    let ``intersects returns true when one has double wildcard`` () =
        let a = KeyExpression.compileOrThrow "Indrajaal/**"
        let b = KeyExpression.compileOrThrow "Indrajaal/Alarms/create"
        Assert.True(KeyExpression.intersects a b)

    [<Fact>]
    let ``intersects returns false for non-overlapping exact expressions`` () =
        let a = KeyExpression.compileOrThrow "Indrajaal/Alarms"
        let b = KeyExpression.compileOrThrow "Other/Module"
        Assert.False(KeyExpression.intersects a b)

    // ========================================================================
    // SELECTOR PARSING TESTS
    // ========================================================================

    [<Fact>]
    let ``parseSelector succeeds for simple expression`` () =
        let result = KeyExpression.parseSelector "Indrajaal/**"
        Assert.True(Result.isOk result)
        match result with
        | Ok selector ->
            Assert.True(selector.Parameters.IsEmpty)
            Assert.True(selector.Filters.IsEmpty)
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``parseSelector extracts query parameters`` () =
        let result = KeyExpression.parseSelector "Indrajaal/**?limit=100&offset=50"
        Assert.True(Result.isOk result)
        match result with
        | Ok selector ->
            Assert.Equal(2, selector.Parameters.Count)
            Assert.Equal("100", selector.Parameters.["limit"])
            Assert.Equal("50", selector.Parameters.["offset"])
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``parseSelector extracts filter parameters`` () =
        let result = KeyExpression.parseSelector "Indrajaal/**?filter.user_id=123&filter.tenant=abc"
        Assert.True(Result.isOk result)
        match result with
        | Ok selector ->
            Assert.Equal(2, selector.Filters.Count)
            Assert.Equal("123", selector.Filters.["user_id"])
            Assert.Equal("abc", selector.Filters.["tenant"])
        | Error _ -> Assert.Fail("Expected Ok")

    [<Fact>]
    let ``getParameter returns value for existing key`` () =
        match KeyExpression.parseSelector "**?limit=100" with
        | Ok selector ->
            let value = KeyExpression.getParameter selector "limit"
            Assert.True(value.IsSome)
            Assert.Equal("100", value.Value)
        | Error _ -> Assert.Fail("Parse failed")

    [<Fact>]
    let ``getParameter returns None for missing key`` () =
        match KeyExpression.parseSelector "**" with
        | Ok selector ->
            let value = KeyExpression.getParameter selector "limit"
            Assert.True(value.IsNone)
        | Error _ -> Assert.Fail("Parse failed")

    [<Fact>]
    let ``getFilter returns value for existing filter`` () =
        match KeyExpression.parseSelector "**?filter.user_id=123" with
        | Ok selector ->
            let value = KeyExpression.getFilter selector "user_id"
            Assert.True(value.IsSome)
            Assert.Equal("123", value.Value)
        | Error _ -> Assert.Fail("Parse failed")

    // ========================================================================
    // KEY BUILDING TESTS
    // ========================================================================

    [<Fact>]
    let ``buildKey creates correct format`` () =
        let key = KeyExpression.buildKey "Indrajaal.Alarms" "create"
        Assert.Equal("Indrajaal.Alarms/create", key)

    [<Fact>]
    let ``buildKeyWithEvent includes event type`` () =
        let key = KeyExpression.buildKeyWithEvent "Indrajaal.Alarms" "process" "entry"
        Assert.Equal("Indrajaal.Alarms/process/entry", key)

    [<Fact>]
    let ``extractModule returns first segment`` () =
        let result = KeyExpression.extractModule "Indrajaal/Alarms/create"
        Assert.True(result.IsSome)
        Assert.Equal("Indrajaal", result.Value)

    [<Fact>]
    let ``extractFunction returns last segment`` () =
        let result = KeyExpression.extractFunction "Indrajaal/Alarms/create"
        Assert.True(result.IsSome)
        Assert.Equal("create", result.Value)

    // ========================================================================
    // PREDEFINED PATTERNS TESTS
    // ========================================================================

    [<Fact>]
    let ``Patterns allInModule creates correct expression`` () =
        let pattern = KeyExpression.Patterns.allInModule "Indrajaal.Alarms"
        Assert.Equal("Indrajaal.Alarms/**", pattern)

    [<Fact>]
    let ``Patterns allCreate is correct`` () =
        Assert.Equal("**/create", KeyExpression.Patterns.allCreate)

    [<Fact>]
    let ``Patterns allErrors is correct`` () =
        Assert.Equal("**/error", KeyExpression.Patterns.allErrors)

    [<Fact>]
    let ``Patterns functionInAny creates correct expression`` () =
        let pattern = KeyExpression.Patterns.functionInAny "handle_call"
        Assert.Equal("**/handle_call", pattern)

    [<Fact>]
    let ``Patterns anyHandler matches handler suffix`` () =
        let compiled = KeyExpression.compileOrThrow KeyExpression.Patterns.anyHandler
        Assert.True(KeyExpression.matches compiled "Indrajaal/AlarmHandler")

    [<Fact>]
    let ``Patterns cortexCognitive matches cortex paths`` () =
        let compiled = KeyExpression.compileOrThrow KeyExpression.Patterns.cortexCognitive
        Assert.True(KeyExpression.matches compiled "Indrajaal/Cortex/analyze")
        Assert.True(KeyExpression.matches compiled "Indrajaal/Cortex/Deep/Module/think")

    // ========================================================================
    // VALIDATION TESTS
    // ========================================================================

    [<Fact>]
    let ``validate returns Ok for valid expression`` () =
        let result = KeyExpression.validate "Indrajaal/**"
        Assert.True(Result.isOk result)

    [<Fact>]
    let ``validate returns Error for empty expression`` () =
        let result = KeyExpression.validate ""
        Assert.True(Result.isError result)

    [<Fact>]
    let ``validate returns Error for invalid characters`` () =
        let result = KeyExpression.validate "Indrajaal/<invalid>"
        Assert.True(Result.isError result)

    [<Fact>]
    let ``validate returns Error for triple wildcard`` () =
        let result = KeyExpression.validate "***"
        Assert.True(Result.isError result)

    [<Fact>]
    let ``validate returns Error for leading slash`` () =
        let result = KeyExpression.validate "/Indrajaal/Alarms"
        Assert.True(Result.isError result)

    [<Fact>]
    let ``validate returns Error for trailing slash`` () =
        let result = KeyExpression.validate "Indrajaal/Alarms/"
        Assert.True(Result.isError result)

    [<Fact>]
    let ``isValid returns true for valid expression`` () =
        Assert.True(KeyExpression.isValid "Indrajaal/**")
        Assert.True(KeyExpression.isValid "Indrajaal/*/create")
        Assert.True(KeyExpression.isValid "**/error")

    [<Fact>]
    let ``isValid returns false for invalid expression`` () =
        Assert.False(KeyExpression.isValid "")
        Assert.False(KeyExpression.isValid "***")
        Assert.False(KeyExpression.isValid "/leading")

    // ========================================================================
    // COMPILED EXPRESSION METADATA TESTS
    // ========================================================================

    [<Fact>]
    let ``compiled expression preserves original string`` () =
        let expr = "Indrajaal/Alarms/**"
        let compiled = KeyExpression.compileOrThrow expr
        Assert.Equal(expr, compiled.Original)

    [<Fact>]
    let ``compiled expression has timestamp`` () =
        let compiled = KeyExpression.compileOrThrow "**"
        Assert.True(compiled.CompiledAt <= DateTimeOffset.UtcNow)
        Assert.True(compiled.CompiledAt > DateTimeOffset.UtcNow.AddMinutes(-1.0))

    [<Fact>]
    let ``compiled expression has correct segment count`` () =
        let compiled = KeyExpression.compileOrThrow "Indrajaal/Alarms/Handler/create"
        Assert.Equal(4, compiled.Segments.Length)

