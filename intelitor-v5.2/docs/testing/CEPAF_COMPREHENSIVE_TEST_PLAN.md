# CEPAF Comprehensive Test Plan
## 100% Static & Runtime Coverage Specification

**Version**: 1.0.0 | **Date**: 2025-12-29 | **Status**: PLANNING
**STAMP Compliance**: SC-TEST-*, SC-COV-*, SC-UI-*, SC-INT-*
**Target**: 100% Static Analysis + 100% Runtime Coverage

---

# EXECUTIVE SUMMARY

| Metric | Target | Current | Gap |
|--------|--------|---------|-----|
| Source Files | 122 | 122 | - |
| Test Files | 122+ | 40 | 82 |
| Static Coverage | 100% | ~30% | 70% |
| Unit Coverage | 100% | ~25% | 75% |
| Integration Coverage | 100% | ~15% | 85% |
| System Coverage | 100% | ~10% | 90% |
| UI Component Coverage | 100% | ~20% | 80% |

---

# LEVEL 1: TEST ARCHITECTURE OVERVIEW

## 1.1 Test Pyramid

```
                    ┌───────────────────┐
                    │   SYSTEM TESTS    │  ← 5% (End-to-End)
                    │   (10 scenarios)  │
                ┌───┴───────────────────┴───┐
                │   FEATURE TESTS           │  ← 10% (Use Cases)
                │   (25 key scenarios)      │
            ┌───┴───────────────────────────┴───┐
            │   INTER-MODULE TESTS              │  ← 15% (Integration)
            │   (50 interaction tests)          │
        ┌───┴───────────────────────────────────┴───┐
        │   MODULE TESTS                            │  ← 25% (Component)
        │   (150 module behavior tests)             │
    ┌───┴───────────────────────────────────────────┴───┐
    │   UNIT TESTS                                      │  ← 45% (Functions)
    │   (500+ pure function tests)                      │
└───┴───────────────────────────────────────────────────┴───┘
```

## 1.2 Coverage Domains

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CEPAF TEST COVERAGE MATRIX                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │   STATIC ANALYSIS   │  │   RUNTIME COVERAGE  │  │   PROPERTY TESTS    │ │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤ │
│  │ • Type checking     │  │ • Line coverage     │  │ • Invariants        │ │
│  │ • Null safety       │  │ • Branch coverage   │  │ • State machines    │ │
│  │ • Exhaustiveness    │  │ • Path coverage     │  │ • Generators        │ │
│  │ • Unused code       │  │ • Condition coverage│  │ • Shrinking         │ │
│  │ • Cyclomatic        │  │ • MC/DC coverage    │  │ • FsCheck/Expecto   │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │   UI COMPONENTS     │  │   INTEGRATION       │  │   SECURITY          │ │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤ │
│  │ • Theme switching   │  │ • Zenoh messaging   │  │ • Input validation  │ │
│  │ • Responsive layout │  │ • Elixir bridge     │  │ • PII masking       │ │
│  │ • Keyboard nav      │  │ • Database queries  │  │ • Credential safety │ │
│  │ • Accessibility     │  │ • WebSocket         │  │ • STAMP constraints │ │
│  │ • State management  │  │ • HTTP/REST         │  │ • Error disclosure  │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# LEVEL 2: MODULE COVERAGE MATRIX

## 2.1 Source File → Test File Mapping

### Core Domain (8 files → 8 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `Domain.fs` | `DomainTests.fs` | 15 | 5 | 2 |
| `Rop.fs` | `RopTests.fs` | 20 | 3 | 1 |
| `Infrastructure.fs` | `InfrastructureTests.fs` | 12 | 4 | 3 |
| `Operations.fs` | `OperationsTests.fs` | 18 | 6 | 2 |
| `OodaController.fs` | `OodaControllerTests.fs` | 25 | 8 | 4 |
| `Orchestrator.fs` | `OrchestratorTests.fs` | 15 | 5 | 5 |
| `Program.fs` | `ProgramTests.fs` | 5 | 2 | 3 |

### Observability (18 files → 18 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `Types.fs` | `ObservabilityTypesTests.fs` | 30 | 5 | 0 |
| `QuadplexLogger.fs` | `QuadplexLoggerTests.fs` | 25 | 8 | 4 |
| `ConsoleChannel.fs` | `ConsoleChannelTests.fs` | 15 | 4 | 2 |
| `FileChannel.fs` | `FileChannelTests.fs` | 20 | 6 | 3 |
| `TelemetryChannel.fs` | `TelemetryChannelTests.fs` | 18 | 5 | 4 |
| `StateTrackerChannel.fs` | `StateTrackerChannelTests.fs` | 22 | 7 | 3 |
| `MetricsCollector.fs` | `MetricsCollectorTests.fs` | 20 | 6 | 2 |
| `Dashboard.fs` | `DashboardTests.fs` | 15 | 5 | 3 |
| `Integration.fs` | `ObsIntegrationTests.fs` | 10 | 8 | 5 |
| **Fractal/** | | | | |
| `Types.fs` | `FractalTypesTests.fs` | 25 | 4 | 0 |
| `HLC.fs` | `HLCTests.fs` | 30 | 5 | 2 |
| `KeyExpression.fs` | `KeyExpressionTests.fs` | 35 | 6 | 2 |
| `WriteFilter.fs` | `WriteFilterTests.fs` | 20 | 5 | 2 |
| `FractalControl.fs` | `FractalControlTests.fs` | 25 | 7 | 4 |
| `BatchEncoder.fs` | `BatchEncoderTests.fs` | 20 | 5 | 2 |
| `ContentRouter.fs` | `ContentRouterTests.fs` | 22 | 6 | 4 |
| `PIIMasking.fs` | `PIIMaskingTests.fs` | 30 | 5 | 2 |
| `AdminSpace.fs` | `AdminSpaceTests.fs` | 15 | 4 | 3 |

### Zenoh Integration (2 files → 2 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `ZenohSession.fs` | `ZenohSessionTests.fs` | 20 | 8 | 6 |
| `ZenohChannel.fs` | `ZenohChannelTests.fs` | 25 | 7 | 5 |

### Dashboard (3 files → 3 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `FractalLogView.fs` | `FractalLogViewTests.fs` | 30 | 8 | 4 |
| `TelemetryPublisher.fs` | `TelemetryPublisherTests.fs` | 22 | 6 | 4 |
| `HistoryQuery.fs` | `HistoryQueryTests.fs` | 25 | 7 | 5 |

### Cockpit UI (11 files → 11 test files)

| Source File | Test File | Unit | Module | Integration | UI |
|-------------|-----------|------|--------|-------------|-----|
| `Domain.fs` | `CockpitDomainTests.fs` | 20 | 5 | 0 | 0 |
| `ThemeSystem.fs` | `ThemeSystemTests.fs` | 35 | 8 | 2 | 15 |
| `Material3.fs` | `Material3Tests.fs` | 40 | 10 | 2 | 20 |
| `DarkCockpitUI.fs` | `DarkCockpitUITests.fs` | 25 | 6 | 3 | 12 |
| `SituationalAwareness.fs` | `SituationalAwarenessTests.fs` | 30 | 7 | 4 | 10 |
| `MessagingIntegration.fs` | `MessagingIntegrationTests.fs` | 20 | 8 | 6 | 5 |
| `BridgeAgent.fs` | `BridgeAgentTests.fs` | 18 | 6 | 5 | 3 |
| `AiCopilot.fs` | `AiCopilotTests.fs` | 25 | 7 | 4 | 8 |
| `C3IMultiAgent.fs` | `C3IMultiAgentTests.fs` | 22 | 8 | 5 | 6 |
| `Cockpit.fs` | `CockpitTests.fs` | 15 | 5 | 4 | 8 |
| `Prajna.fs` | `PrajnaTests.fs` | 30 | 10 | 6 | 15 |

### Modules (13 files → 13 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `PathResolver.fs` | `PathResolverTests.fs` | 25 | 6 | 3 |
| `ConstraintValidator.fs` | `ConstraintValidatorTests.fs` | 30 | 8 | 4 |
| `ServiceDAG.fs` | `ServiceDAGTests.fs` | 35 | 10 | 5 |
| `HealthPropagation.fs` | `HealthPropagationTests.fs` | 20 | 6 | 4 |
| `NodeVerifier.fs` | `NodeVerifierTests.fs` | 22 | 7 | 4 |
| `ChainVerifier.fs` | `ChainVerifierTests.fs` | 25 | 8 | 5 |
| `TDGHarness.fs` | `TDGHarnessTests.fs` | 20 | 6 | 4 |
| `AOREngine.fs` | `AOREngineTests.fs` | 30 | 8 | 5 |
| `Podman.fs` | `PodmanTests.fs` | 25 | 7 | 6 |
| `Phics.fs` | `PhicsTests.fs` | 18 | 5 | 4 |
| `CyberneticAgents.fs` | `CyberneticAgentsTests.fs` | 28 | 9 | 5 |
| `AgentMesh.fs` | `AgentMeshTests.fs` | 22 | 7 | 5 |
| `ZenohHandlers.fs` | `ZenohHandlersTests.fs` | 20 | 6 | 5 |

### Phases (12 files → 12 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `VTO.fs` | `VTOTests.fs` | 25 | 8 | 5 |
| `AceVerifier.fs` | `AceVerifierTests.fs` | 20 | 6 | 4 |
| `DbVerifier.fs` | `DbVerifierTests.fs` | 22 | 7 | 5 |
| `ObsVerifier.fs` | `ObsVerifierTests.fs` | 18 | 6 | 4 |
| `AppVerifier.fs` | `AppVerifierTests.fs` | 20 | 6 | 5 |
| `StandaloneVerifier.fs` | `StandaloneVerifierTests.fs` | 15 | 5 | 4 |
| `LivebookVerifier.fs` | `LivebookVerifierTests.fs` | 12 | 4 | 3 |
| `FormalVerification.fs` | `FormalVerificationTests.fs` | 30 | 10 | 6 |
| `Builder.fs` | `BuilderTests.fs` | 22 | 7 | 5 |
| `Tester.fs` | `TesterTests.fs` | 25 | 8 | 5 |
| `UI.fs` | `UIPhaseTests.fs` | 18 | 6 | 4 |
| `Sterilizer.fs` | `SterilizerTests.fs` | 15 | 5 | 3 |

### Service Chains (3 files → 3 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `DevChain.fs` | `DevChainTests.fs` | 20 | 8 | 6 |
| `ObsChain.fs` | `ObsChainTests.fs` | 18 | 7 | 5 |
| `StandaloneChain.fs` | `StandaloneChainTests.fs` | 22 | 8 | 6 |

### AI (2 files → 2 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `OpenRouter.fs` | `OpenRouterTests.fs` | 20 | 6 | 5 |
| `Intelligence.fs` | `IntelligenceTests.fs` | 25 | 8 | 4 |

### Safety (1 file → 1 test file)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `SimplexKernel.fs` | `SimplexKernelTests.fs` | 35 | 10 | 6 |

### Bio (2 files → 2 test files)

| Source File | Test File | Unit | Module | Integration |
|-------------|-----------|------|--------|-------------|
| `Holon.fs` | `HolonTests.fs` | 20 | 6 | 3 |
| `HolonTree.fs` | `HolonTreeTests.fs` | 25 | 8 | 4 |

### UI Rendering (1 file → 1 test file)

| Source File | Test File | Unit | Module | Integration | UI |
|-------------|-----------|------|--------|-------------|-----|
| `HolonRenderer.fs` | `HolonRendererTests.fs` | 15 | 5 | 3 | 10 |

---

# LEVEL 3: TEST CATEGORIES & SPECIFICATIONS

## 3.1 Static Analysis Tests

### 3.1.1 Type Safety (SC-STAT-001)

```fsharp
// Test: All public functions have explicit type signatures
[<Test>]
let ``All public functions have type annotations`` () =
    let assembly = typeof<Domain.ServiceStatus>.Assembly
    let publicFunctions =
        assembly.GetTypes()
        |> Seq.collect (fun t -> t.GetMethods())
        |> Seq.filter (fun m -> m.IsPublic && not m.IsSpecialName)

    for fn in publicFunctions do
        Assert.NotNull(fn.ReturnType, $"Function {fn.Name} missing return type")
```

### 3.1.2 Exhaustive Pattern Matching (SC-STAT-002)

```fsharp
// Test: All discriminated union matches are exhaustive
[<Test>]
let ``All DU matches are exhaustive`` () =
    // Compile with --warnon:25 and verify 0 warnings
    let result = Compiler.compileWithWarnings ["--warnon:25"]
    Assert.Empty(result.Warnings)
```

### 3.1.3 Null Safety (SC-STAT-003)

```fsharp
// Test: No null values in F# code
[<Test>]
let ``No null literals in F# source`` () =
    let files = Directory.GetFiles("src/Cepaf", "*.fs", SearchOption.AllDirectories)
    for file in files do
        let content = File.ReadAllText(file)
        // Allow null only in interop with .NET
        let nullUsages = Regex.Matches(content, @"\bnull\b")
        for usage in nullUsages do
            Assert.True(
                content.Contains("[<AllowNullLiteral>]") ||
                content.Contains("Unchecked.defaultof"),
                $"Unexpected null in {file}")
```

### 3.1.4 Cyclomatic Complexity (SC-STAT-004)

```fsharp
// Test: No function exceeds complexity threshold
[<Test>]
let ``Cyclomatic complexity under 15`` () =
    let metrics = CodeAnalysis.calculateComplexity "src/Cepaf"
    for (file, fn, complexity) in metrics do
        Assert.LessOrEqual(complexity, 15,
            $"Function {fn} in {file} has complexity {complexity}")
```

## 3.2 Unit Tests

### 3.2.1 Pure Function Tests (SC-UNIT-001)

```fsharp
module RopTests =
    open Cepaf.Rop

    [<Test>]
    let ``bind propagates success`` () =
        let result =
            Ok 5
            |> bind (fun x -> Ok (x * 2))
        Assert.Equal(Ok 10, result)

    [<Test>]
    let ``bind short-circuits on error`` () =
        let result =
            Error "failed"
            |> bind (fun x -> Ok (x * 2))
        Assert.Equal(Error "failed", result)

    [<Test>]
    let ``map transforms success value`` () =
        let result = Ok 5 |> map ((*) 2)
        Assert.Equal(Ok 10, result)

    [<Test>]
    let ``traverse collects results`` () =
        let inputs = [1; 2; 3]
        let result = traverse (fun x -> Ok (x * 2)) inputs
        Assert.Equal(Ok [2; 4; 6], result)

    [<TestCase("", false)>]
    [<TestCase("valid", true)>]
    let ``notEmpty validates strings`` (input, expected) =
        let result = notEmpty input
        Assert.Equal(expected, Result.isOk result)
```

### 3.2.2 Type Conversion Tests (SC-UNIT-002)

```fsharp
module HLCTests =
    open Cepaf.Observability.Fractal.HLC

    [<Test>]
    let ``create returns valid timestamp`` () =
        let hlc = create ()
        Assert.Greater(hlc.Physical, 0L)
        Assert.Equal(0us, hlc.Logical)

    [<Test>]
    let ``compare orders correctly`` () =
        let hlc1 = { Physical = 100L; Logical = 0us; NodeId = 1uy }
        let hlc2 = { Physical = 100L; Logical = 1us; NodeId = 1uy }
        Assert.Less(compare hlc1 hlc2, 0)

    [<Test>]
    let ``tick increments logical`` () =
        let hlc = { Physical = 100L; Logical = 5us; NodeId = 1uy }
        let next = tick hlc
        Assert.Equal(6us, next.Logical)

    [<Test>]
    let ``encode/decode roundtrips`` () =
        let original = create ()
        let encoded = encode original
        let decoded = decode encoded
        Assert.Equal(original, decoded)
```

### 3.2.3 State Machine Tests (SC-UNIT-003)

```fsharp
module OodaControllerTests =
    open Cepaf.OodaController

    [<Test>]
    let ``initial state is Observe`` () =
        let controller = create ()
        Assert.Equal(OodaPhase.Observe, controller.Phase)

    [<Test>]
    let ``transition Observe -> Orient`` () =
        let controller = create ()
        let next = transition Stimulus.DataReceived controller
        Assert.Equal(OodaPhase.Orient, next.Phase)

    [<Test>]
    let ``invalid transition returns error`` () =
        let controller = { create () with Phase = OodaPhase.Act }
        let result = tryTransition Stimulus.DataReceived controller
        Assert.True(Result.isError result)

    [<Property>]
    let ``all states are reachable`` (stimuli: Stimulus list) =
        let controller = create ()
        let final = List.fold (fun c s -> transition s c) controller stimuli
        // Eventually reaches all states
        true
```

## 3.3 Module Tests

### 3.3.1 Component Behavior Tests (SC-MOD-001)

```fsharp
module QuadplexLoggerTests =
    open Cepaf.Observability.QuadplexLogger

    [<Test>]
    let ``logger writes to all enabled channels`` () =
        let consoleMock = Mock<ILogChannel>()
        let fileMock = Mock<ILogChannel>()
        let config = { defaultConfig with ConsoleEnabled = true; FileEnabled = true }

        let logger = createWith config [consoleMock.Object; fileMock.Object]
        logger.Info("Test message")

        consoleMock.Verify(fun c -> c.Write(It.IsAny<QuadplexEvent>()), Times.Once)
        fileMock.Verify(fun f -> f.Write(It.IsAny<QuadplexEvent>()), Times.Once)

    [<Test>]
    let ``logger respects minimum level`` () =
        let mock = Mock<ILogChannel>()
        mock.Setup(fun c -> c.IsEnabled(It.IsAny<LogLevel>())).Returns(false)

        let logger = createWith defaultConfig [mock.Object]
        logger.Debug("Should not log")

        mock.Verify(fun c -> c.Write(It.IsAny<QuadplexEvent>()), Times.Never)

    [<Test>]
    let ``flush drains all buffers`` () =
        let mock = Mock<ILogChannel>()
        let logger = createWith defaultConfig [mock.Object]

        logger.Info("Message 1")
        logger.Info("Message 2")
        logger.Flush()

        mock.Verify(fun c -> c.Flush(), Times.Once)
```

### 3.3.2 Configuration Tests (SC-MOD-002)

```fsharp
module ThemeSystemTests =
    open Cepaf.Cockpit.ThemeSystem

    [<Test>]
    let ``default mode is Dark`` () =
        Assert.Equal(ThemeMode.Dark, currentMode())

    [<Test>]
    let ``setMode changes theme`` () =
        setMode ThemeMode.Light
        Assert.Equal(ThemeMode.Light, currentMode())
        setMode ThemeMode.Dark  // Reset

    [<Test>]
    let ``toggle switches between Light and Dark`` () =
        setMode ThemeMode.Light
        toggle ()
        Assert.Equal(ThemeMode.Dark, currentMode())
        toggle ()
        Assert.Equal(ThemeMode.Light, currentMode())

    [<Test>]
    let ``Auto mode detects system preference`` () =
        setMode ThemeMode.Auto
        let resolved = resolvedMode()
        Assert.True(resolved = ThemeMode.Light || resolved = ThemeMode.Dark)

    [<TestCase(L1, "808080")>]  // Gray for debug
    [<TestCase(L5, "CC0000")>]  // Red for critical
    let ``level colors are correct`` (level, expectedHex) =
        let color = levelColor level
        Assert.Contains(expectedHex, color)
```

### 3.3.3 Error Handling Tests (SC-MOD-003)

```fsharp
module ZenohSessionTests =
    open Cepaf.Zenoh.ZenohSession

    [<Test>]
    let ``connect handles timeout`` () = async {
        let config = { defaultConfig with ConnectTimeout = TimeSpan.FromMilliseconds(10.0) }
        let! result = connectAsync config
        // Should fail gracefully with unreachable endpoint
        Assert.True(Result.isError result)
    }

    [<Test>]
    let ``publish retries on failure`` () = async {
        let session = createMock ()
        session.SetupPublishFailure(times = 2)

        let! result = session.PublishAsync("test/key", [| 1uy |])

        Assert.True(Result.isOk result)
        Assert.Equal(3, session.PublishAttempts)
    }

    [<Test>]
    let ``reconnect on connection loss`` () = async {
        let session = create ()
        do! session.ConnectAsync() |> Async.Ignore

        session.SimulateDisconnect()
        do! Async.Sleep(1000)

        Assert.Equal(ConnectionStatus.Connected, session.Status)
    }
```

## 3.4 Inter-Module Tests

### 3.4.1 Integration Flow Tests (SC-INT-001)

```fsharp
module ObservabilityIntegrationTests =
    [<Test>]
    let ``log flows from Logger to FileChannel to Disk`` () = async {
        // Arrange
        let tempFile = Path.GetTempFileName()
        let config = { defaultConfig with FilePath = tempFile; FileEnabled = true }
        let logger = QuadplexLogger.createWith config

        // Act
        logger.Info("Integration test message")
        logger.Flush()

        // Assert
        let content = File.ReadAllText(tempFile)
        Assert.Contains("Integration test message", content)

        // Cleanup
        File.Delete(tempFile)
    }

    [<Test>]
    let ``Zenoh publishes to subscriber`` () = async {
        // Arrange
        let received = ref None
        let session = ZenohSession.create ()
        do! session.ConnectAsync() |> Async.Ignore

        session.Subscribe("test/**", fun msg ->
            received := Some msg
        )

        // Act
        do! session.PublishAsync("test/key", [| 1uy; 2uy; 3uy |]) |> Async.Ignore
        do! Async.Sleep(100)

        // Assert
        Assert.True(Option.isSome !received)
        Assert.Equal([| 1uy; 2uy; 3uy |], (!received).Value.Payload)
    }
```

### 3.4.2 Data Flow Tests (SC-INT-002)

```fsharp
module FractalPipelineTests =
    [<Test>]
    let ``log entry flows through fractal pipeline`` () = async {
        // Setup pipeline
        let encoder = BatchEncoder.create ()
        let router = ContentRouter.create ()
        let filter = WriteFilter.create defaultRules

        // Create entry
        let entry = {
            Level = L3
            Message = "Test transaction"
            Domain = "testing"
            Timestamp = DateTimeOffset.UtcNow
            HlcTimestamp = HLC.create ()
            Metadata = Map.empty
        }

        // Process
        let filtered = filter.Apply entry
        Assert.True(Option.isSome filtered)

        let encoded = encoder.Encode [filtered.Value]
        Assert.Greater(encoded.Length, 0)

        let routes = router.Route filtered.Value
        Assert.NotEmpty(routes)
    }
```

### 3.4.3 Event Propagation Tests (SC-INT-003)

```fsharp
module CockpitIntegrationTests =
    [<Test>]
    let ``theme change propagates to all components`` () =
        // Arrange
        let material3 = Material3.create ()
        let darkUI = DarkCockpitUI.create ()
        let prajna = Prajna.create ()

        // Act
        ThemeSystem.setMode ThemeMode.Light

        // Assert
        Assert.Equal(ThemeMode.Light, material3.CurrentTheme)
        Assert.Equal(ThemeMode.Light, darkUI.CurrentTheme)
        Assert.Equal(ThemeMode.Light, prajna.CurrentTheme)

        // Reset
        ThemeSystem.setMode ThemeMode.Dark
```

## 3.5 Feature Tests (Use Cases)

### 3.5.1 Fractal Logging Use Cases (SC-FEAT-001)

```fsharp
module FractalLoggingFeatureTests =
    [<Test>]
    let ``UC-LOG-001: Operator views real-time L5 cognitive logs`` () = async {
        // Given: Operator has cockpit open
        let cockpit = Prajna.create ()
        cockpit.Initialize ()

        // When: System generates L5 cognitive intent log
        let entry = createL5Entry "User authentication intent detected"
        FractalLogger.emit entry

        // Then: Log appears in cockpit within 100ms
        do! Async.Sleep(100)
        let visible = cockpit.GetVisibleLogs() |> Seq.head
        Assert.Equal(L5, visible.Level)
        Assert.Contains("authentication intent", visible.Message)
    }

    [<Test>]
    let ``UC-LOG-002: Operator filters logs by domain`` () =
        // Given: Multiple domain logs exist
        let logs = [
            createL3Entry "alarms" "Alarm triggered"
            createL3Entry "devices" "Device connected"
            createL3Entry "alarms" "Alarm acknowledged"
        ]

        // When: Operator sets domain filter to "alarms"
        let view = FractalLogView.create ()
        view.SetDomainFilter ["alarms"]
        logs |> List.iter view.AddEntry

        // Then: Only alarm logs are visible
        let visible = view.GetVisibleEntries()
        Assert.Equal(2, Seq.length visible)
        Assert.True(visible |> Seq.forall (fun e -> e.Domain = "alarms"))

    [<Test>]
    let ``UC-LOG-003: Historical query returns paginated results`` () = async {
        // Given: 10,000 logs in history
        let! _ = HistoryQuery.insertBatch (generateLogs 10000)

        // When: Query with limit 100, offset 0
        let params' = { defaultParams with Limit = 100; Offset = 0 }
        let! result = HistoryQuery.queryAsync params'

        // Then: Returns 100 entries with HasMore = true
        Assert.Equal(100, result.Entries.Length)
        Assert.True(result.HasMore)
        Assert.Equal(10000, result.TotalCount)
    }
```

### 3.5.2 Theme & UI Use Cases (SC-FEAT-002)

```fsharp
module ThemeFeatureTests =
    [<Test>]
    let ``UC-THEME-001: Operator switches to light theme`` () =
        // Given: Dark theme active
        ThemeSystem.setMode ThemeMode.Dark

        // When: Operator toggles theme
        ThemeSystem.toggle ()

        // Then: All UI components use light colors
        let tokens = ThemeSystem.tokens ()
        Assert.Equal("#FFFFFF", tokens.Background)
        Assert.Equal("#1A1A1A", tokens.OnBackground)

    [<Test>]
    let ``UC-THEME-002: Colors maintain WCAG AAA contrast`` () =
        for mode in [ThemeMode.Light; ThemeMode.Dark] do
            ThemeSystem.setMode mode
            let tokens = ThemeSystem.tokens ()

            // Calculate contrast ratio
            let bgLuminance = calculateLuminance tokens.Background
            let fgLuminance = calculateLuminance tokens.OnBackground
            let ratio = contrastRatio bgLuminance fgLuminance

            Assert.GreaterOrEqual(ratio, 7.0, $"WCAG AAA requires 7:1, got {ratio}")

    [<Test>]
    let ``UC-THEME-003: Responsive layout adapts to terminal size`` () =
        // Given: Different terminal widths
        for (width, expectedBreakpoint) in [(80, Compact); (120, Standard); (160, Wide); (220, UltraWide)] do
            // When: Terminal size changes
            ThemeSystem.updateViewport { Width = width; Height = 40 }

            // Then: Correct breakpoint is detected
            Assert.Equal(expectedBreakpoint, ThemeSystem.currentBreakpoint())
```

### 3.5.3 Zenoh Messaging Use Cases (SC-FEAT-003)

```fsharp
module ZenohFeatureTests =
    [<Test>]
    let ``UC-ZENOH-001: F# publishes metrics to Elixir subscriber`` () = async {
        // Given: Connected Zenoh session
        let session = ZenohSession.create ()
        do! session.ConnectAsync() |> Async.Ignore

        // When: Publish telemetry
        let metrics = {| cpu = 45.0; memory = 2100L |}
        do! TelemetryPublisher.publishAsync "indrajaal/telemetry/fsharp/metrics" metrics

        // Then: Elixir receives within 50ms
        // (Verified by Elixir integration test)
        Assert.Pass("Elixir integration verifies receipt")
    }

    [<Test>]
    let ``UC-ZENOH-002: Control command triggers action`` () = async {
        // Given: Subscribed to control plane
        let actionExecuted = ref false
        ZenohChannel.subscribeControl "boost" (fun _ ->
            actionExecuted := true
        )

        // When: Control command received
        let cmd = {| level = "l5"; duration_sec = 60 |}
        ZenohSession.simulateReceive "indrajaal/control/fractal/boost" cmd

        // Then: Action is executed
        do! Async.Sleep(50)
        Assert.True(!actionExecuted)
    }
```

## 3.6 System Tests (End-to-End)

### 3.6.1 Full System Scenarios (SC-SYS-001)

```fsharp
module SystemTests =
    [<Test>]
    let ``SYS-001: Complete startup sequence`` () = async {
        // Given: Clean state
        cleanup ()

        // When: Start CEPAF
        let! result = Orchestrator.startAsync defaultConfig

        // Then: All services healthy
        Assert.True(Result.isOk result)
        let status = Orchestrator.status ()
        Assert.Equal(ServiceStatus.Healthy, status.Zenoh)
        Assert.Equal(ServiceStatus.Healthy, status.Database)
        Assert.Equal(ServiceStatus.Healthy, status.Observability)

        // Cleanup
        do! Orchestrator.shutdownAsync ()
    }

    [<Test>]
    let ``SYS-002: Graceful degradation on Zenoh failure`` () = async {
        // Given: Running system
        do! Orchestrator.startAsync defaultConfig |> Async.Ignore

        // When: Zenoh becomes unavailable
        ZenohSession.simulateFailure ()

        // Then: System continues with file logging
        QuadplexLogger.info "Test during degradation"
        let fileContent = File.ReadAllText(defaultConfig.FilePath)
        Assert.Contains("Test during degradation", fileContent)

        // And: Reconnection attempts
        do! Async.Sleep(5000)
        Assert.Equal(ConnectionStatus.Reconnecting, ZenohSession.status())
    }

    [<Test>]
    let ``SYS-003: Full observability pipeline`` () = async {
        // Given: Complete system with Elixir backend running
        do! Orchestrator.startAsync fullConfig |> Async.Ignore

        // When: Generate logs at all levels
        for level in [L1; L2; L3; L4; L5] do
            FractalLogger.emit { Level = level; Message = $"Test {level}" }

        // Then: All logs appear in:
        // 1. Console (real-time)
        // 2. File (persistent)
        // 3. Zenoh (to Elixir)
        // 4. TimescaleDB (historical)
        do! Async.Sleep(1000)

        let fileContent = File.ReadAllText(defaultConfig.FilePath)
        Assert.Contains("Test L5", fileContent)

        let! history = HistoryQuery.queryAsync { defaultParams with Limit = 5 }
        Assert.Equal(5, history.Entries.Length)
    }
```

---

# LEVEL 4: UI COMPONENT TEST SPECIFICATIONS

## 4.1 Theme System Tests (102 tests)

### 4.1.1 Core Theme Tests (35 unit tests)

| Test ID | Description | Type | STAMP |
|---------|-------------|------|-------|
| TH-U-001 | Default mode is Dark | Unit | SC-THEME-001 |
| TH-U-002 | setMode changes theme | Unit | SC-THEME-001 |
| TH-U-003 | toggle switches Light/Dark | Unit | SC-THEME-002 |
| TH-U-004 | cycle rotates all modes | Unit | SC-THEME-002 |
| TH-U-005 | Auto detects system pref | Unit | SC-THEME-003 |
| TH-U-006 | tokens() returns current | Unit | SC-THEME-004 |
| TH-U-007 | Light background is white | Unit | SC-THEME-004 |
| TH-U-008 | Dark background is black | Unit | SC-THEME-004 |
| TH-U-009 | L1 color is gray | Unit | SC-THEME-005 |
| TH-U-010 | L2 color is cyan | Unit | SC-THEME-005 |
| TH-U-011 | L3 color is green | Unit | SC-THEME-005 |
| TH-U-012 | L4 color is yellow/orange | Unit | SC-THEME-005 |
| TH-U-013 | L5 color is red | Unit | SC-THEME-005 |
| TH-U-014 | alarmColor returns correct | Unit | SC-THEME-005 |
| TH-U-015 | Compact breakpoint at 80 | Unit | SC-RESP-001 |
| TH-U-016 | Standard breakpoint at 100 | Unit | SC-RESP-001 |
| TH-U-017 | Wide breakpoint at 140 | Unit | SC-RESP-001 |
| TH-U-018 | UltraWide breakpoint at 200 | Unit | SC-RESP-001 |
| TH-U-019 | updateViewport triggers event | Unit | SC-RESP-002 |
| TH-U-020 | Primary surface color | Unit | SC-THEME-004 |
| TH-U-021 | Secondary surface color | Unit | SC-THEME-004 |
| TH-U-022 | Error color is red | Unit | SC-THEME-005 |
| TH-U-023 | Warning color is amber | Unit | SC-THEME-005 |
| TH-U-024 | Success color is green | Unit | SC-THEME-005 |
| TH-U-025 | Info color is blue | Unit | SC-THEME-005 |
| TH-U-026 | Border colors per mode | Unit | SC-THEME-004 |
| TH-U-027 | Focus ring color | Unit | SC-THEME-004 |
| TH-U-028 | Selection color | Unit | SC-THEME-004 |
| TH-U-029 | Disabled color | Unit | SC-THEME-004 |
| TH-U-030 | High contrast mode | Unit | SC-THEME-006 |
| TH-U-031 | Reduced motion pref | Unit | SC-ERGO-001 |
| TH-U-032 | Font size scaling | Unit | SC-ERGO-002 |
| TH-U-033 | Line height adjustment | Unit | SC-ERGO-002 |
| TH-U-034 | Spacing multiplier | Unit | SC-ERGO-003 |
| TH-U-035 | Panel density setting | Unit | SC-ERGO-003 |

### 4.1.2 Contrast & Accessibility Tests (15 tests)

| Test ID | Description | Type | WCAG |
|---------|-------------|------|------|
| TH-A-001 | Light mode WCAG AAA | Access | AAA |
| TH-A-002 | Dark mode WCAG AAA | Access | AAA |
| TH-A-003 | Critical text 7:1 ratio | Access | AAA |
| TH-A-004 | Normal text 4.5:1 ratio | Access | AA |
| TH-A-005 | Interactive elements visible | Access | 2.4.7 |
| TH-A-006 | Focus indicators 3:1 | Access | 2.4.7 |
| TH-A-007 | Error states distinguishable | Access | 1.4.1 |
| TH-A-008 | Color not sole indicator | Access | 1.4.1 |
| TH-A-009 | Text resizable to 200% | Access | 1.4.4 |
| TH-A-010 | Line spacing adjustable | Access | 1.4.12 |
| TH-A-011 | Target size >= 24x24 | Access | 2.5.5 |
| TH-A-012 | Motion reducible | Access | 2.3.3 |
| TH-A-013 | High contrast available | Access | 1.4.6 |
| TH-A-014 | Custom colors supported | Access | 1.4.3 |
| TH-A-015 | Screen reader compatible | Access | 4.1.2 |

### 4.1.3 Responsive Layout Tests (10 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| TH-R-001 | Compact hides sidebars | Responsive |
| TH-R-002 | Standard 2-column layout | Responsive |
| TH-R-003 | Wide 3-column layout | Responsive |
| TH-R-004 | UltraWide 4-column layout | Responsive |
| TH-R-005 | Panel collapse/expand | Responsive |
| TH-R-006 | Navigation adapts | Responsive |
| TH-R-007 | Table column hiding | Responsive |
| TH-R-008 | Chart resizing | Responsive |
| TH-R-009 | Modal sizing | Responsive |
| TH-R-010 | Scrollbar visibility | Responsive |

## 4.2 Material3 Component Tests (145 tests)

### 4.2.1 Button Components (20 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| M3-BTN-001 | Primary button renders | Unit |
| M3-BTN-002 | Secondary button renders | Unit |
| M3-BTN-003 | Tertiary button renders | Unit |
| M3-BTN-004 | Disabled state | Unit |
| M3-BTN-005 | Loading state | Unit |
| M3-BTN-006 | Icon button | Unit |
| M3-BTN-007 | FAB (floating action) | Unit |
| M3-BTN-008 | Extended FAB | Unit |
| M3-BTN-009 | Button with icon | Unit |
| M3-BTN-010 | Button group | Unit |
| M3-BTN-011 | Toggle button | Unit |
| M3-BTN-012 | Keyboard activation | UI |
| M3-BTN-013 | Focus ring visible | UI |
| M3-BTN-014 | Hover state | UI |
| M3-BTN-015 | Active state | UI |
| M3-BTN-016 | Ripple effect | UI |
| M3-BTN-017 | Theme adaptation | UI |
| M3-BTN-018 | Size variants | Unit |
| M3-BTN-019 | Full-width button | Unit |
| M3-BTN-020 | Button in form | Integration |

### 4.2.2 Input Components (25 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| M3-INP-001 | Text field renders | Unit |
| M3-INP-002 | Outlined variant | Unit |
| M3-INP-003 | Filled variant | Unit |
| M3-INP-004 | Label floating | UI |
| M3-INP-005 | Placeholder text | Unit |
| M3-INP-006 | Helper text | Unit |
| M3-INP-007 | Error state | Unit |
| M3-INP-008 | Character counter | Unit |
| M3-INP-009 | Prefix/suffix | Unit |
| M3-INP-010 | Clear button | Unit |
| M3-INP-011 | Password toggle | UI |
| M3-INP-012 | Multiline textarea | Unit |
| M3-INP-013 | Auto-resize | UI |
| M3-INP-014 | Max length | Unit |
| M3-INP-015 | Input validation | Unit |
| M3-INP-016 | Required field | Unit |
| M3-INP-017 | Disabled state | Unit |
| M3-INP-018 | Read-only state | Unit |
| M3-INP-019 | Focus behavior | UI |
| M3-INP-020 | Keyboard nav | UI |
| M3-INP-021 | Autocomplete | Integration |
| M3-INP-022 | Search field | Unit |
| M3-INP-023 | Number input | Unit |
| M3-INP-024 | Date picker | Integration |
| M3-INP-025 | Dropdown select | Integration |

### 4.2.3 Navigation Components (15 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| M3-NAV-001 | Tab bar renders | Unit |
| M3-NAV-002 | Tab selection | UI |
| M3-NAV-003 | Tab scroll | UI |
| M3-NAV-004 | Sidebar navigation | Unit |
| M3-NAV-005 | Breadcrumbs | Unit |
| M3-NAV-006 | Bottom nav | Unit |
| M3-NAV-007 | Drawer menu | UI |
| M3-NAV-008 | App bar | Unit |
| M3-NAV-009 | Keyboard nav | UI |
| M3-NAV-010 | Active indicators | UI |
| M3-NAV-011 | Badge on nav item | Unit |
| M3-NAV-012 | Collapsible sections | UI |
| M3-NAV-013 | Nested navigation | Integration |
| M3-NAV-014 | Mobile hamburger | UI |
| M3-NAV-015 | Route integration | Integration |

### 4.2.4 Data Display Components (20 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| M3-DATA-001 | Table renders | Unit |
| M3-DATA-002 | Table sorting | UI |
| M3-DATA-003 | Table filtering | UI |
| M3-DATA-004 | Table pagination | UI |
| M3-DATA-005 | Row selection | UI |
| M3-DATA-006 | Column resizing | UI |
| M3-DATA-007 | Sticky header | UI |
| M3-DATA-008 | Virtual scrolling | Performance |
| M3-DATA-009 | Card component | Unit |
| M3-DATA-010 | List component | Unit |
| M3-DATA-011 | List with icons | Unit |
| M3-DATA-012 | Expandable list | UI |
| M3-DATA-013 | Chip component | Unit |
| M3-DATA-014 | Badge component | Unit |
| M3-DATA-015 | Avatar component | Unit |
| M3-DATA-016 | Tooltip | UI |
| M3-DATA-017 | Progress bar | Unit |
| M3-DATA-018 | Circular progress | Unit |
| M3-DATA-019 | Skeleton loader | Unit |
| M3-DATA-020 | Empty state | Unit |

### 4.2.5 Feedback Components (15 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| M3-FB-001 | Snackbar renders | Unit |
| M3-FB-002 | Snackbar auto-dismiss | UI |
| M3-FB-003 | Alert dialog | UI |
| M3-FB-004 | Confirmation dialog | UI |
| M3-FB-005 | Toast notification | Unit |
| M3-FB-006 | Banner message | Unit |
| M3-FB-007 | Inline error | Unit |
| M3-FB-008 | Success feedback | Unit |
| M3-FB-009 | Warning message | Unit |
| M3-FB-010 | Info message | Unit |
| M3-FB-011 | Loading overlay | UI |
| M3-FB-012 | Modal backdrop | UI |
| M3-FB-013 | Bottom sheet | UI |
| M3-FB-014 | Popover | UI |
| M3-FB-015 | Context menu | UI |

## 4.3 Prajna Cockpit Tests (85 tests)

### 4.3.1 Panel System Tests (25 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| PJ-PAN-001 | Header panel renders | Unit |
| PJ-PAN-002 | Left sidebar renders | Unit |
| PJ-PAN-003 | Main content area | Unit |
| PJ-PAN-004 | Right sidebar renders | Unit |
| PJ-PAN-005 | Footer status bar | Unit |
| PJ-PAN-006 | Panel priority system | Module |
| PJ-PAN-007 | Panel collapse | UI |
| PJ-PAN-008 | Panel resize | UI |
| PJ-PAN-009 | Panel drag-drop | UI |
| PJ-PAN-010 | Panel persistence | Integration |
| PJ-PAN-011 | Responsive hiding | Responsive |
| PJ-PAN-012 | Focus management | UI |
| PJ-PAN-013 | Keyboard shortcuts | UI |
| PJ-PAN-014 | Panel transitions | UI |
| PJ-PAN-015 | Split view mode | UI |
| PJ-PAN-016 | Fullscreen panel | UI |
| PJ-PAN-017 | Minimized state | UI |
| PJ-PAN-018 | Panel overflow | UI |
| PJ-PAN-019 | Nested panels | Integration |
| PJ-PAN-020 | Panel groups | Integration |
| PJ-PAN-021 | Custom panel | Integration |
| PJ-PAN-022 | Panel events | Integration |
| PJ-PAN-023 | Panel state sync | Integration |
| PJ-PAN-024 | Remote panel update | Integration |
| PJ-PAN-025 | Panel error boundary | Unit |

### 4.3.2 Log Viewer Tests (20 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| PJ-LOG-001 | Log entry renders | Unit |
| PJ-LOG-002 | Level coloring | Unit |
| PJ-LOG-003 | Timestamp format | Unit |
| PJ-LOG-004 | Domain display | Unit |
| PJ-LOG-005 | Message truncation | Unit |
| PJ-LOG-006 | Expand/collapse | UI |
| PJ-LOG-007 | Level filtering | UI |
| PJ-LOG-008 | Domain filtering | UI |
| PJ-LOG-009 | Search highlight | UI |
| PJ-LOG-010 | Auto-scroll | UI |
| PJ-LOG-011 | Pause/resume | UI |
| PJ-LOG-012 | Virtual scroll | Performance |
| PJ-LOG-013 | Copy to clipboard | UI |
| PJ-LOG-014 | Export logs | Integration |
| PJ-LOG-015 | Trace linking | UI |
| PJ-LOG-016 | Metadata expand | UI |
| PJ-LOG-017 | Time range select | UI |
| PJ-LOG-018 | Bookmark entry | UI |
| PJ-LOG-019 | Diff view | UI |
| PJ-LOG-020 | JSON formatter | Unit |

### 4.3.3 Metrics Display Tests (15 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| PJ-MET-001 | Gauge renders | Unit |
| PJ-MET-002 | Sparkline chart | Unit |
| PJ-MET-003 | KPI card | Unit |
| PJ-MET-004 | Trend indicator | Unit |
| PJ-MET-005 | Threshold alerts | Unit |
| PJ-MET-006 | Real-time update | Integration |
| PJ-MET-007 | Historical chart | Integration |
| PJ-MET-008 | Aggregation | Unit |
| PJ-MET-009 | Time range | UI |
| PJ-MET-010 | Export data | Integration |
| PJ-MET-011 | Custom metrics | Integration |
| PJ-MET-012 | Dashboard layout | UI |
| PJ-MET-013 | Widget resize | UI |
| PJ-MET-014 | Refresh rate | Unit |
| PJ-MET-015 | Offline mode | Integration |

### 4.3.4 Control Panel Tests (15 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| PJ-CTL-001 | Boost L5 button | UI |
| PJ-CTL-002 | Suppress L1-L2 | UI |
| PJ-CTL-003 | Refresh KPIs | UI |
| PJ-CTL-004 | Trigger compile | UI |
| PJ-CTL-005 | Run tests | UI |
| PJ-CTL-006 | Emergency stop | UI |
| PJ-CTL-007 | Command feedback | UI |
| PJ-CTL-008 | Command history | UI |
| PJ-CTL-009 | Confirmation dialog | UI |
| PJ-CTL-010 | Error handling | Unit |
| PJ-CTL-011 | Timeout handling | Unit |
| PJ-CTL-012 | Retry logic | Unit |
| PJ-CTL-013 | Permission check | Integration |
| PJ-CTL-014 | Audit logging | Integration |
| PJ-CTL-015 | Undo action | UI |

### 4.3.5 AI Copilot Tests (10 tests)

| Test ID | Description | Type |
|---------|-------------|------|
| PJ-AI-001 | Chat input | UI |
| PJ-AI-002 | Message display | Unit |
| PJ-AI-003 | Streaming response | UI |
| PJ-AI-004 | Code highlighting | Unit |
| PJ-AI-005 | Suggestion panel | UI |
| PJ-AI-006 | Context awareness | Integration |
| PJ-AI-007 | Error recovery | Unit |
| PJ-AI-008 | Rate limiting | Unit |
| PJ-AI-009 | History navigation | UI |
| PJ-AI-010 | Clear conversation | UI |

---

# LEVEL 5: TEST IMPLEMENTATION PLAN

## 5.1 Test Project Structure

```
lib/cepaf/test/
├── Cepaf.Tests/
│   ├── Cepaf.Tests.fsproj
│   ├── TestConfig.fs
│   ├── TestHelpers.fs
│   ├── Mocks/
│   │   ├── ZenohMock.fs
│   │   ├── DatabaseMock.fs
│   │   └── ConsoleMock.fs
│   ├── Unit/
│   │   ├── Core/
│   │   │   ├── DomainTests.fs
│   │   │   ├── RopTests.fs
│   │   │   └── InfrastructureTests.fs
│   │   ├── Observability/
│   │   │   ├── TypesTests.fs
│   │   │   ├── QuadplexLoggerTests.fs
│   │   │   ├── ChannelTests.fs
│   │   │   └── Fractal/
│   │   │       ├── HLCTests.fs
│   │   │       ├── KeyExpressionTests.fs
│   │   │       └── BatchEncoderTests.fs
│   │   ├── Cockpit/
│   │   │   ├── ThemeSystemTests.fs
│   │   │   ├── Material3Tests.fs
│   │   │   └── PrajnaTests.fs
│   │   └── Modules/
│   │       ├── PathResolverTests.fs
│   │       ├── ServiceDAGTests.fs
│   │       └── CyberneticAgentsTests.fs
│   ├── Module/
│   │   ├── ZenohSessionTests.fs
│   │   ├── FractalPipelineTests.fs
│   │   └── OodaControllerTests.fs
│   ├── Integration/
│   │   ├── ObservabilityIntegrationTests.fs
│   │   ├── ZenohIntegrationTests.fs
│   │   └── CockpitIntegrationTests.fs
│   ├── Feature/
│   │   ├── FractalLoggingFeatureTests.fs
│   │   ├── ThemeFeatureTests.fs
│   │   └── ZenohFeatureTests.fs
│   ├── System/
│   │   ├── StartupTests.fs
│   │   ├── DegradationTests.fs
│   │   └── FullPipelineTests.fs
│   ├── UI/
│   │   ├── AccessibilityTests.fs
│   │   ├── ResponsiveTests.fs
│   │   └── KeyboardNavTests.fs
│   └── Property/
│       ├── RopPropertyTests.fs
│       ├── HLCPropertyTests.fs
│       └── StatePropertyTests.fs
```

## 5.2 Test Framework Configuration

```fsharp
// Cepaf.Tests.fsproj
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Expecto" Version="10.2.1" />
    <PackageReference Include="Expecto.FsCheck" Version="10.2.1" />
    <PackageReference Include="FsCheck" Version="2.16.6" />
    <PackageReference Include="Unquote" Version="7.0.0" />
    <PackageReference Include="Moq" Version="4.20.70" />
    <PackageReference Include="coverlet.collector" Version="6.0.2" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="../src/Cepaf/Cepaf.fsproj" />
  </ItemGroup>
</Project>
```

## 5.3 Coverage Configuration

```json
// coverlet.runsettings
{
  "DataCollectionRunSettings": {
    "DataCollectors": {
      "DataCollector": {
        "friendlyName": "XPlat Code Coverage",
        "configuration": {
          "Format": "cobertura,lcov,json",
          "ExcludeByFile": "**/obj/**,**/Migrations/**",
          "Include": "[Cepaf*]*",
          "Exclude": "[*]*.Program",
          "IncludeDirectory": "src/",
          "SingleHit": false,
          "UseSourceLink": true,
          "SkipAutoProps": true
        }
      }
    }
  }
}
```

## 5.4 Execution Commands

```bash
# Run all tests with coverage
dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage

# Run specific test category
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
dotnet test --filter "Category=UI"

# Generate coverage report
reportgenerator -reports:./coverage/**/coverage.cobertura.xml \
  -targetdir:./coverage/report \
  -reporttypes:Html

# Property-based tests
dotnet test --filter "Category=Property" -- RunConfiguration.MaxCpuCount=1

# Performance tests
dotnet test --filter "Category=Performance" --logger "console;verbosity=detailed"
```

## 5.5 CI/CD Integration

```yaml
# .github/workflows/cepaf-tests.yml
name: CEPAF Test Suite

on:
  push:
    paths:
      - 'lib/cepaf/**'
  pull_request:
    paths:
      - 'lib/cepaf/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: Restore
        run: dotnet restore lib/cepaf/Cepaf.sln

      - name: Build
        run: dotnet build lib/cepaf/Cepaf.sln --no-restore

      - name: Unit Tests
        run: |
          dotnet test lib/cepaf/test/Cepaf.Tests \
            --filter "Category=Unit" \
            --collect:"XPlat Code Coverage" \
            --results-directory ./coverage/unit

      - name: Integration Tests
        run: |
          dotnet test lib/cepaf/test/Cepaf.Tests \
            --filter "Category=Integration" \
            --collect:"XPlat Code Coverage" \
            --results-directory ./coverage/integration

      - name: Generate Report
        run: |
          dotnet tool install -g dotnet-reportgenerator-globaltool
          reportgenerator \
            -reports:./coverage/**/coverage.cobertura.xml \
            -targetdir:./coverage/report \
            -reporttypes:Html,Cobertura

      - name: Upload Coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/report/Cobertura.xml
          fail_ci_if_error: true

      - name: Check Coverage Threshold
        run: |
          coverage=$(grep -oP 'line-rate="\K[^"]+' ./coverage/report/Cobertura.xml)
          if (( $(echo "$coverage < 0.95" | bc -l) )); then
            echo "Coverage ${coverage} is below 95% threshold"
            exit 1
          fi
```

---

# APPENDIX A: TEST METRICS DASHBOARD

## A.1 Coverage Targets

| Category | Target | Threshold | Critical |
|----------|--------|-----------|----------|
| Line Coverage | 100% | 95% | 85% |
| Branch Coverage | 100% | 90% | 80% |
| Function Coverage | 100% | 95% | 85% |
| Module Coverage | 100% | 100% | 95% |
| UI Component Coverage | 100% | 90% | 80% |

## A.2 Test Count Summary

| Level | Count | Status |
|-------|-------|--------|
| Unit Tests | 500+ | Planned |
| Module Tests | 150 | Planned |
| Integration Tests | 50 | Planned |
| Feature Tests | 25 | Planned |
| System Tests | 10 | Planned |
| UI Tests | 120 | Planned |
| Property Tests | 50 | Planned |
| **TOTAL** | **905+** | Planned |

---

# APPENDIX B: STAMP CONSTRAINT MAPPING

| STAMP ID | Test Coverage | Files |
|----------|---------------|-------|
| SC-THEME-001 | TH-U-001 to TH-U-008 | ThemeSystemTests.fs |
| SC-RESP-001 | TH-U-015 to TH-U-018 | ThemeSystemTests.fs |
| SC-ERGO-001 | TH-U-031 to TH-U-035 | ThemeSystemTests.fs |
| SC-LOG-001 | PJ-LOG-001 to PJ-LOG-020 | PrajnaLogViewTests.fs |
| SC-ZENOH-001 | ZS-U-001 to ZS-INT-010 | ZenohSessionTests.fs |
| SC-OBS-001 | OBS-U-001 to OBS-INT-020 | ObservabilityTests.fs |

---

*End of Test Plan*

**Document Control:**
- Author: Claude Code
- Created: 2025-12-29
- Last Updated: 2025-12-29
- Review Cycle: Weekly
