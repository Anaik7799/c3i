namespace Cepaf.Tests.Observability.Fractal

open Xunit
open Cepaf.Observability.Fractal
open System

/// TDG Test Suite for Fractal PII Masking
/// STAMP Compliance: SC-LOG-003 (PII masking at decorator)
/// Total: 55 tests covering pattern matching, masking strategies, and entry masking
module FractalPIIMaskingTests =

    // ============================================================
    // EMAIL PATTERN (8 tests)
    // ============================================================

    [<Fact>]
    let ``email pattern masks standard email`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "user@example.com"
        Assert.True(result.WasMasked)
        Assert.Contains("***", result.Masked)
        Assert.Equal(Some PIIMasking.SensitiveCategory.PII, result.Category)

    [<Fact>]
    let ``email pattern preserves domain`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "john.doe@company.com"
        Assert.Contains("@company.com", result.Masked)

    [<Fact>]
    let ``email pattern preserves prefix`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "john@example.com"
        Assert.True(result.Masked.StartsWith("joh"))

    [<Fact>]
    let ``email pattern handles short local part`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "jo@example.com"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``email pattern handles subdomains`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "user@mail.company.co.uk"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``email pattern handles plus addressing`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "user+tag@example.com"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``email in text is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "Contact: user@example.com for help"
        Assert.True(result.WasMasked)
        Assert.Contains("***", result.Masked)
        Assert.Contains("for help", result.Masked)

    [<Fact>]
    let ``multiple emails are masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "From: a@x.com To: b@y.com"
        Assert.True(result.WasMasked)
        Assert.DoesNotContain("a@x.com", result.Masked)
        Assert.DoesNotContain("b@y.com", result.Masked)

    // ============================================================
    // PHONE PATTERN (6 tests)
    // ============================================================

    [<Fact>]
    let ``phone pattern masks US format`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "555-123-4567"
        Assert.True(result.WasMasked)
        Assert.EndsWith("4567", result.Masked)

    [<Fact>]
    let ``phone pattern masks international format`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "+1-555-123-4567"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``phone pattern masks parentheses format`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "(555) 123-4567"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``phone pattern preserves last 4 digits`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "555-123-9876"
        Assert.Contains("9876", result.Masked)

    [<Fact>]
    let ``phone in text is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "Call me at 555-123-4567 please"
        Assert.True(result.WasMasked)
        Assert.Contains("please", result.Masked)

    [<Fact>]
    let ``phone pattern handles dots`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "555.123.4567"
        Assert.True(result.WasMasked)

    // ============================================================
    // CREDIT CARD PATTERN (6 tests)
    // ============================================================

    [<Fact>]
    let ``credit card pattern masks 16 digits`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "4111111111111111"
        Assert.True(result.WasMasked)
        Assert.Equal(Some PIIMasking.SensitiveCategory.PCI, result.Category)

    [<Fact>]
    let ``credit card pattern preserves last 4`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "4111111111111234"
        Assert.EndsWith("1234", result.Masked)

    [<Fact>]
    let ``credit card pattern handles dashes`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "4111-1111-1111-1111"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``credit card pattern handles spaces`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "4111 1111 1111 1111"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``credit card in text is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "Card: 4111111111111111 expires 12/25"
        Assert.True(result.WasMasked)
        Assert.Contains("expires", result.Masked)

    [<Fact>]
    let ``credit card pattern has high priority`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "4111111111111111"
        Assert.Equal(Some "credit_card", result.PatternName)

    // ============================================================
    // SSN PATTERN (5 tests)
    // ============================================================

    [<Fact>]
    let ``SSN pattern masks with dashes`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "123-45-6789"
        Assert.True(result.WasMasked)
        Assert.Equal("[REDACTED]", result.Masked)

    [<Fact>]
    let ``SSN pattern masks with spaces`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "123 45 6789"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``SSN pattern masks without separators`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "123456789"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``SSN in text is fully redacted`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "SSN: 123-45-6789"
        Assert.Contains("[REDACTED]", result.Masked)

    [<Fact>]
    let ``SSN pattern identified correctly`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "123-45-6789"
        Assert.Equal(Some "ssn", result.PatternName)

    // ============================================================
    // API KEY / TOKEN PATTERN (6 tests)
    // ============================================================

    [<Fact>]
    let ``API key pattern masks api_key=`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "api_key=sk_live_1234567890abcdefgh"
        Assert.True(result.WasMasked)
        Assert.Equal(Some PIIMasking.SensitiveCategory.APISecrets, result.Category)

    [<Fact>]
    let ``API key pattern masks token:`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "token: abc123def456ghi789jkl"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``API key pattern preserves prefix and suffix`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "secret=abcdefghijklmnopqrstuvwxyz"
        Assert.True(result.Masked.StartsWith("secret=abcd"))
        Assert.True(result.Masked.EndsWith("wxyz"))

    [<Fact>]
    let ``API key pattern ignores short values`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "api_key=short"
        // Short keys (< 16 chars) should not match
        Assert.False(result.WasMasked)

    [<Fact>]
    let ``Bearer token is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "bearer=abc123def456ghi789jkl"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``API key has highest priority`` () =
        // API secrets should be caught first
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "api_key=1234567890123456"
        Assert.Equal(Some "api_key", result.PatternName)

    // ============================================================
    // PASSWORD PATTERN (5 tests)
    // ============================================================

    [<Fact>]
    let ``password pattern masks password=`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "password=secretpass123"
        Assert.True(result.WasMasked)
        Assert.Contains("[REDACTED]", result.Masked)

    [<Fact>]
    let ``password pattern masks pwd:`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "pwd: mypassword"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``password pattern masks passwd`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "passwd=hunter2"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``password in URL is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "postgres://user:password=secret@host"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``password pattern is credentials category`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "password=test"
        Assert.Equal(Some PIIMasking.SensitiveCategory.Credentials, result.Category)

    // ============================================================
    // JWT PATTERN (4 tests)
    // ============================================================

    [<Fact>]
    let ``JWT pattern masks valid JWT`` () =
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig jwt
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``JWT preserves structure hint`` () =
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig jwt
        Assert.True(result.Masked.StartsWith("eyJhbGciOiJ"))

    [<Fact>]
    let ``JWT in authorization header is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``JWT pattern is API secrets category`` () =
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig jwt
        Assert.Equal(Some PIIMasking.SensitiveCategory.APISecrets, result.Category)

    // ============================================================
    // IP ADDRESS PATTERN (4 tests)
    // ============================================================

    [<Fact>]
    let ``IP address pattern masks IPv4`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "192.168.1.100"
        Assert.True(result.WasMasked)

    [<Fact>]
    let ``IP address preserves suffix`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "10.0.0.123"
        Assert.EndsWith("123", result.Masked)

    [<Fact>]
    let ``IP address in log line is masked`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "Connection from 192.168.1.100 accepted"
        Assert.True(result.WasMasked)
        Assert.Contains("accepted", result.Masked)

    [<Fact>]
    let ``IP address is PII category`` () =
        let result = PIIMasking.maskWithDefaults PIIMasking.defaultConfig "192.168.1.100"
        Assert.Equal(Some PIIMasking.SensitiveCategory.PII, result.Category)

    // ============================================================
    // CONFIGURATION (5 tests)
    // ============================================================

    [<Fact>]
    let ``masking can be disabled`` () =
        let config = { PIIMasking.defaultConfig with Enabled = false }
        let result = PIIMasking.maskWithDefaults config "user@example.com"
        Assert.False(result.WasMasked)
        Assert.Equal("user@example.com", result.Masked)

    [<Fact>]
    let ``correlation hash included when enabled`` () =
        let config = { PIIMasking.defaultConfig with IncludeCorrelationHash = true }
        let result = PIIMasking.maskWithDefaults config "user@example.com"
        Assert.True(result.CorrelationHash.IsSome)

    [<Fact>]
    let ``correlation hash excluded when disabled`` () =
        let config = { PIIMasking.defaultConfig with IncludeCorrelationHash = false }
        let result = PIIMasking.maskWithDefaults config "user@example.com"
        Assert.True(result.CorrelationHash.IsNone)

    [<Fact>]
    let ``sensitive keys are always masked`` () =
        Assert.True(PIIMasking.isSensitiveKey PIIMasking.defaultConfig "password")
        Assert.True(PIIMasking.isSensitiveKey PIIMasking.defaultConfig "api_key")
        Assert.True(PIIMasking.isSensitiveKey PIIMasking.defaultConfig "secret_token")

    [<Fact>]
    let ``exempt keys are not masked`` () =
        Assert.True(PIIMasking.isExemptKey PIIMasking.defaultConfig "timestamp")
        Assert.True(PIIMasking.isExemptKey PIIMasking.defaultConfig "level")
        Assert.True(PIIMasking.isExemptKey PIIMasking.defaultConfig "module")

    // ============================================================
    // LOG ENTRY MASKING (SC-LOG-003) (6 tests)
    // ============================================================

    [<Fact>]
    let ``maskKeyValue masks sensitive key`` () =
        let result = PIIMasking.maskKeyValue PIIMasking.defaultConfig "password" (box "secret123")
        Assert.Equal(box "[REDACTED]", result)

    [<Fact>]
    let ``maskKeyValue preserves exempt key`` () =
        let result = PIIMasking.maskKeyValue PIIMasking.defaultConfig "timestamp" (box "2024-01-01")
        Assert.Equal(box "2024-01-01", result)

    [<Fact>]
    let ``maskKeyValue masks PII in value`` () =
        let result = PIIMasking.maskKeyValue PIIMasking.defaultConfig "message" (box "Email: user@example.com")
        let masked = result :?> string
        Assert.Contains("***", masked)

    [<Fact>]
    let ``maskPayload masks text payload`` () =
        let payload = FractalPayload.Text "Contact user@example.com"
        let masked = PIIMasking.maskPayload PIIMasking.defaultConfig payload
        match masked with
        | FractalPayload.Text t -> Assert.Contains("***", t)
        | _ -> Assert.Fail("Should be text")

    [<Fact>]
    let ``maskPayload leaves binary unchanged`` () =
        let payload = FractalPayload.Binary [|1uy;2uy;3uy|]
        let masked = PIIMasking.maskPayload PIIMasking.defaultConfig payload
        Assert.Equal(payload, masked)

    [<Fact>]
    let ``maskBatch processes all entries`` () =
        let entry = {
            Key = "test"
            KeyAlias = None
            HLC = { Physical = 1000L; Counter = 0; NodeId = "node" }
            FractalLevel = FractalLevel.L3
            Priority = Priority.P0
            EventType = EventType.Entry
            TraceId = None
            SpanId = None
            ParentSpanId = None
            Baggage = Map.ofList [("email", "user@example.com")]
            Payload = FractalPayload.Text "user@example.com"
            Tags = []
            Timestamp = DateTimeOffset.UtcNow
            Duration = None
            Node = "node"
            Module = "M"
            Function = "f"
            Arity = 0
        }
        let masked = PIIMasking.maskBatch PIIMasking.defaultConfig [entry; entry]
        Assert.Equal(2, masked.Length)

    // ============================================================
    // VALIDATION (SC-LOG-003) (2 tests)
    // ============================================================

    [<Fact>]
    let ``validateMasking passes for working masking`` () =
        let result = PIIMasking.validateMasking()
        Assert.True(result.Passed)
        Assert.Equal(SafetyConstraints.scLog003, result.ConstraintId)

    [<Fact>]
    let ``getMaskingStats returns pattern info`` () =
        let stats = PIIMasking.getMaskingStats()
        Assert.True(stats.PatternCount > 0)
        Assert.True(stats.EnabledPatterns > 0)

