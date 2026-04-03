# CEPAF Testing Guide

**Version**: 1.0.0
**Framework**: xUnit 2.6.3 with .NET 8.0
**STAMP Compliance**: SC-CEP-003, SC-VAL-003, SC-AGT-018, SC-OBS-069, SC-OBS-071

## Table of Contents

1. [Test Architecture](#1-test-architecture)
2. [Test Categories](#2-test-categories)
3. [Running Tests](#3-running-tests)
4. [Writing New Tests](#4-writing-new-tests)
5. [Test Coverage by Module](#5-test-coverage-by-module)
6. [CI/CD Integration](#6-cicd-integration)

---

## 1. Test Architecture

### 1.1 Test Project Structure

CEPAF follows a multi-project test structure with clear separation of concerns:

```
lib/cepaf/
+-- src/
|   +-- Cepaf.Tests/              # Core framework unit tests (737 tests)
|       +-- PathResolverTests.fs
|       +-- ServiceDAGTests.fs
|       +-- ChainVerifierTests.fs
|       +-- DevChainTests.fs
|       +-- ObsChainTests.fs
|       +-- ObsVerifierTests.fs
|       +-- TDGHarnessTests.fs
|       +-- AOREngineTests.fs
|       +-- HealthPropagationTests.fs
|       +-- NodeVerifierTests.fs
|       +-- ConstraintValidatorTests.fs
|
+-- test/
|   +-- Cepaf.Tests/              # Additional integration tests
|       +-- OodaTests.fs
|       +-- RopTests.fs
|       +-- OodaControllerTests.fs
|       +-- ConstraintsTests.fs
|       +-- BuilderTests.fs
|       +-- OrchestratorTests.fs
|       +-- PhicsTests.fs
|       +-- CyberneticAgentsTests.fs
|
+-- tests/
    +-- Cepaf.Podman.Tests/       # Podman API integration tests
        +-- PropertyTests.fs
        +-- ContainerLifecycleTests.fs
        +-- ImageBuildTests.fs
        +-- NetworkTests.fs
        +-- VolumeTests.fs
        +-- ComposeIntegrationTests.fs
        +-- StressTests.fs
```

### 1.2 xUnit Integration

CEPAF uses xUnit as the primary testing framework with the following packages:

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
  <PackageReference Include="xunit" Version="2.6.3" />
  <PackageReference Include="xunit.runner.visualstudio" Version="2.5.5" />
  <PackageReference Include="coverlet.collector" Version="6.0.0" />
</ItemGroup>
```

### 1.3 Factory Function Pattern

CEPAF tests use a **factory function pattern** instead of static module-level values. This is critical for xUnit compatibility.

**Why Factory Functions?**

xUnit initializes test classes/modules before running tests. Module-level `let` bindings in F# execute during this initialization, which can cause issues:

1. Side effects during test discovery
2. Shared mutable state between tests
3. Initialization failures blocking entire test runs

**Pattern Example:**

```fsharp
// BAD: Static module-level value
module Tests =
    let container = {
        Name = "db"
        Image = "localhost/db:nixos"
        // ... static initialization
    }

    [<Fact>]
    let ``test uses container`` () =
        Assert.Equal("db", container.Name)

// GOOD: Factory function pattern
module Tests =
    /// Factory: Database container - Layer 0 (no dependencies)
    let makeDbContainer () : ContainerDef = {
        Name = "indrajaal-db"
        Image = "localhost/indrajaal-db:nixos"
        DependsOn = []
        DependencyTypes = Map.empty
        Layer = Some 0
    }

    [<Fact>]
    let ``test uses container`` () =
        let container = makeDbContainer ()
        Assert.Equal("indrajaal-db", container.Name)
```

**Factory Naming Conventions:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `make*` | Create test data | `makeDbContainer ()` |
| `makeHealthy*` | Create healthy state | `makeHealthySigNozStatus ()` |
| `makeUnhealthy*` | Create failure state | `makeUnhealthyGrafanaStatus ()` |
| `makeMixed*` | Create partial state | `makeMixedFPPS_3Pass2Fail ()` |
| `makeFailing*` | Create test failure | `makeFailingTestResult ()` |

---

## 2. Test Categories

### 2.1 Unit Tests

Unit tests verify individual functions in isolation. Each module has corresponding unit tests.

**Structure:**
- One test file per source module
- Tests organized in sections with clear headers
- Usecase naming convention: `UC-CATEGORY-NNN`

**Example: PathResolverTests.fs**
```fsharp
// ============================================================================
// BASIC PATH RESOLUTION TESTS
// ============================================================================

[<Fact>]
let ``resolve returns absolute path unchanged`` () =
    let absolutePath = "/home/user/project/file.yml"
    let result = PathResolver.resolve absolutePath
    Assert.Equal(absolutePath, result)
```

### 2.2 FPPS Consensus Tests

Tests for the Five-Point Probing System (FPPS) verification:

1. **PodmanStatus** - Container state from Podman
2. **HealthEndpoint** - HTTP health check
3. **PortProbe** - TCP port connectivity
4. **ProcessCheck** - Process running check
5. **LogAnalysis** - Log error pattern detection

**STAMP Compliance: SC-CEP-003, SC-VAL-003**

```fsharp
[<Fact>]
let ``UC-FPPS-001: All 5 methods agree healthy achieves consensus`` () =
    let fpps = makeAllHealthyFPPS ()
    Assert.True(fpps.ConsensusAchieved)
    Assert.Equal(5, fpps.MethodsAgreeHealthy)
    Assert.Equal(0, fpps.MethodsAgreeUnhealthy)

[<Theory>]
[<InlineData(0, false)>]
[<InlineData(3, true)>]   // Majority threshold
[<InlineData(5, true)>]
let ``checkConsensusAgreement majority threshold is 3 of 5`` (passCount: int) (expected: bool) =
    let results = createResults passCount
    let consensus = checkConsensusAgreement results false
    Assert.Equal(expected, consensus)
```

### 2.3 STAMP Compliance Tests

Tests verifying STAMP safety constraints:

| Constraint | Description | Test Location |
|------------|-------------|---------------|
| SC-CNT-009 | NixOS/Podman only | DevChainTests, ObsChainTests |
| SC-CNT-010 | Localhost registry | DevChainTests, ObsChainTests |
| SC-CNT-012 | Rootless Podman | DevChainTests |
| SC-AGT-018 | No deadlocks (cycle detection) | ServiceDAGTests, ChainVerifierTests |
| SC-CEP-003 | FPPS 5-method consensus | ChainVerifierTests, ObsVerifierTests |
| SC-VAL-003 | 100% consensus required | ChainVerifierTests |
| SC-OBS-069 | Dual logging | ObsChainTests |
| SC-OBS-071 | 4 OTEL modules | ObsChainTests |

```fsharp
[<Fact>]
let ``UC-STAMP-003: All images use localhost registry (SC-CNT-010)`` () =
    fullContainers
    |> List.iter (fun c ->
        Assert.True(c.Image.StartsWith("localhost/"),
            sprintf "Container %s uses non-localhost registry: %s" c.Name c.Image))
```

### 2.4 Integration Tests

Integration tests verify component interactions:

- **ChainVerifier**: DAG construction + FPPS + Health propagation
- **DevChain**: Boot sequence + Dependency resolution + STAMP compliance
- **ObsChain**: Observability stack + SigNoz + Grafana

### 2.5 TDG (Test-Driven Generation) Tests

Tests for the TDG harness that enforces:
- TDG-001: Tests must exist before code generation
- TDG-002: Dual property tests (PropCheck + ExUnitProperties)
- TDG-003: 95% coverage threshold

---

## 3. Running Tests

### 3.1 Full Test Suite

```bash
# Navigate to CEPAF directory
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf

# Run all tests
dotnet test

# Run with verbose output
dotnet test --verbosity normal

# Run with detailed logging
dotnet test --logger "console;verbosity=detailed"
```

### 3.2 Specific Test Projects

```bash
# Core framework tests (737 tests)
dotnet test src/Cepaf.Tests/Cepaf.Tests.fsproj

# Podman API tests
dotnet test tests/Cepaf.Podman.Tests/Cepaf.Podman.Tests.fsproj

# Additional integration tests
dotnet test test/Cepaf.Tests/Cepaf.Tests.fsproj
```

### 3.3 Filter Tests

```bash
# Run tests matching a pattern
dotnet test --filter "FullyQualifiedName~PathResolver"

# Run specific test class/module
dotnet test --filter "FullyQualifiedName~DevChainTests"

# Run tests by category (using display name)
dotnet test --filter "DisplayName~UC-FPPS"

# Run tests by STAMP constraint
dotnet test --filter "DisplayName~SC-CNT-010"
```

### 3.4 Test with Coverage

```bash
# Run with XPlat coverage collection
dotnet test --collect:"XPlat Code Coverage"

# Coverage output location
# ./test-results/GUID/coverage.cobertura.xml

# Generate coverage report (requires reportgenerator tool)
dotnet tool install -g dotnet-reportgenerator-globaltool
reportgenerator \
  -reports:./test-results/*/coverage.cobertura.xml \
  -targetdir:./coverage-report \
  -reporttypes:Html
```

### 3.5 Test Results Output

```bash
# Output TRX test results
dotnet test \
  --logger "trx;LogFileName=test-results.trx" \
  --results-directory ./test-results

# Output JUnit format (for CI)
dotnet test \
  --logger "junit;LogFileName=test-results.xml" \
  --results-directory ./test-results
```

---

## 4. Writing New Tests

### 4.1 Test File Template

```fsharp
namespace Cepaf.Tests

open System
open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.YourModule

/// YourModule Unit Tests
/// STAMP Compliance: SC-XXX-NNN, SC-YYY-NNN
/// AOR Compliance: AOR-SAF-001, AOR-QUA-001
/// Test Coverage: Feature 1, Feature 2, Feature 3
module YourModuleTests =

    // ========================================================================
    // TEST DATA FACTORY FUNCTIONS
    // Factories avoid xUnit initialization issues with module-level values
    // ========================================================================

    /// Create valid input for testing
    let makeValidInput () : InputType = {
        Field1 = "value"
        Field2 = 42
    }

    /// Create invalid input for error testing
    let makeInvalidInput () : InputType = {
        Field1 = ""
        Field2 = -1
    }

    // ========================================================================
    // SECTION 1: BASIC FUNCTIONALITY TESTS (UC-BASIC-*)
    // ========================================================================

    [<Fact>]
    let ``UC-BASIC-001: Function handles valid input`` () =
        // Arrange
        let input = makeValidInput ()

        // Act
        let result = YourModule.process input

        // Assert
        Assert.True(result.IsOk)

    [<Fact>]
    let ``UC-BASIC-002: Function rejects invalid input`` () =
        // Arrange
        let input = makeInvalidInput ()

        // Act
        let result = YourModule.process input

        // Assert
        match result with
        | Error msg -> Assert.Contains("invalid", msg.ToLower())
        | Ok _ -> Assert.Fail("Expected Error, got Ok")

    // ========================================================================
    // SECTION 2: STAMP COMPLIANCE TESTS (UC-STAMP-*)
    // ========================================================================

    [<Fact>]
    let ``UC-STAMP-001: SC-XXX-NNN constraint enforced`` () =
        // Arrange
        let input = makeValidInput ()

        // Act & Assert
        Assert.True(YourModule.checkConstraint input)

    // ========================================================================
    // SECTION 3: PARAMETERIZED TESTS
    // ========================================================================

    [<Theory>]
    [<InlineData("value1", 1, true)>]
    [<InlineData("value2", 2, true)>]
    [<InlineData("", 0, false)>]
    let ``Parameterized validation`` (field1: string) (field2: int) (expected: bool) =
        // Arrange
        let input = { Field1 = field1; Field2 = field2 }

        // Act
        let result = YourModule.validate input

        // Assert
        Assert.Equal(expected, result)
```

### 4.2 Usecase Naming Convention

Tests should follow the `UC-CATEGORY-NNN` naming pattern:

| Category | Description | Example |
|----------|-------------|---------|
| UC-START | Startup usecases | `UC-START-001: Clean start produces valid DAG` |
| UC-HEALTH | Health check usecases | `UC-HEALTH-001: DB health config has correct port` |
| UC-FPPS | FPPS consensus usecases | `UC-FPPS-001: All 5 methods agree healthy` |
| UC-DEP | Dependency usecases | `UC-DEP-001: Mandatory dep - app depends on db` |
| UC-STOP | Shutdown usecases | `UC-STOP-001: Shutdown order is reverse of boot` |
| UC-VAL | Validation usecases | `UC-VAL-001: Dev chain validates successfully` |
| UC-BOOT | Boot sequence usecases | `UC-BOOT-001: Minimal obs chain produces valid DAG` |
| UC-STAMP | STAMP compliance usecases | `UC-STAMP-001: SC-OBS-069 dual logging compliance` |
| UC-SIGNOZ | SigNoz verification | `UC-SIGNOZ-001: Container creation verification` |
| UC-GRAFANA | Grafana verification | `UC-GRAFANA-001: Container health endpoint` |
| UC-ERR | Error handling | `UC-ERR-001: Network failure captured` |

### 4.3 Factory Function Best Practices

1. **Pure Functions**: Factories should have no side effects
2. **Descriptive Names**: Use clear prefixes (`makeHealthy*`, `makeUnhealthy*`)
3. **Document Purpose**: Add XML doc comments explaining factory purpose
4. **Parameterized Factories**: Support custom values when needed

```fsharp
/// Create SigNoz status with specific port failures
let makeSigNozWithPortFailure (failingPort: string) : SigNozStatus = {
    ContainerRunning = true
    OtlpGrpcAvailable = failingPort <> "4317"
    OtlpHttpAvailable = failingPort <> "4318"
    UiAvailable = failingPort <> "8080"
    // ...
}
```

### 4.4 Assertion Best Practices

```fsharp
// Pattern matching for Result types
match result with
| Ok value -> Assert.Equal(expected, value)
| Error msg -> Assert.Fail($"Expected Ok, got Error: {msg}")

// Pattern matching for Option types
Assert.True(result.IsSome)
Assert.Equal(expected, result.Value)

// Collection assertions
Assert.Contains(item, collection)
Assert.DoesNotContain(item, collection)
Assert.Empty(collection)
Assert.Single(collection) |> ignore

// List type disambiguation
Assert.Equal<string list>(expected, actual)
```

---

## 5. Test Coverage by Module

### 5.1 Core Framework Tests (src/Cepaf.Tests)

| Test File | Tests | Coverage Areas |
|-----------|-------|----------------|
| PathResolverTests.fs | 64 | Path resolution, compose files, validation, containers |
| ServiceDAGTests.fs | 87 | DAG construction, cycles, topological sort, layers, dependencies |
| ChainVerifierTests.fs | 93 | Chain status, FPPS consensus, cycle detection, boot sequence |
| DevChainTests.fs | 74 | Dev environment, boot sequence, health, dependencies, STAMP |
| ObsChainTests.fs | 65 | Observability chain, boot sequence, health, STAMP compliance |
| ObsVerifierTests.fs | 82 | FPPS consensus, SigNoz, Grafana, STAMP, error handling |
| TDGHarnessTests.fs | 63 | TDG constraints, coverage, test execution, reports |
| AOREngineTests.fs | 45 | Agent Operating Rules evaluation |
| HealthPropagationTests.fs | 38 | Health state propagation through DAG |
| NodeVerifierTests.fs | 52 | Individual node verification |
| ConstraintValidatorTests.fs | 74 | STAMP constraint validation |

**Total: ~737 tests**

### 5.2 Test Categories

```
FPPS Consensus:        ~95 tests
STAMP Compliance:      ~85 tests
DAG Operations:        ~120 tests
Health Verification:   ~90 tests
Chain Management:      ~150 tests
TDG Validation:        ~65 tests
Path Resolution:       ~65 tests
Error Handling:        ~67 tests
```

---

## 6. CI/CD Integration

### 6.1 GitHub Actions Workflow

The project uses `.github/workflows/cepaf-podman.yml` for CI/CD:

```yaml
name: Cepaf.Podman CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        dotnet-version: ['8.0.x']

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ matrix.dotnet-version }}

      - name: Restore dependencies
        run: dotnet restore Cepaf.sln

      - name: Build solution
        run: dotnet build Cepaf.sln --configuration Release --no-restore

      - name: Run Cepaf.Tests
        run: |
          dotnet test src/Cepaf.Tests/Cepaf.Tests.fsproj \
            --configuration Release \
            --no-build \
            --logger "trx;LogFileName=cepaf-tests.trx" \
            --results-directory ./test-results

      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: ./test-results/*.trx
```

### 6.2 Test Reporting

Test results are:
1. Uploaded as artifacts (TRX format)
2. Displayed using `dorny/test-reporter@v1`
3. Retained for 30 days

### 6.3 Coverage Thresholds

The project enforces:
- **Minimum Coverage**: 95% (TDG-003 constraint)
- **Zero Warnings**: Build fails on warnings (AOR-QUA-001)
- **Format Check**: `dotnet format --verify-no-changes`

### 6.4 Local Pre-Commit Testing

```bash
# Run before committing
cd lib/cepaf

# Full validation
dotnet build -c Release /warnaserror && \
dotnet test --no-build -c Release && \
dotnet format --verify-no-changes

# Quick check
dotnet test --filter "Category=Unit"
```

---

## Appendix A: STAMP Constraints Reference

| ID | Description | Test Coverage |
|----|-------------|---------------|
| SC-CNT-009 | NixOS/Podman only | DevChainTests, ObsChainTests |
| SC-CNT-010 | Localhost registry only | All chain tests |
| SC-CNT-012 | Rootless Podman | DevChainTests |
| SC-CEP-001 | Path locality | PathResolverTests |
| SC-CEP-002 | Path decoupling | PathResolverTests |
| SC-CEP-003 | FPPS 5-method consensus | ChainVerifierTests, ObsVerifierTests |
| SC-CEP-004 | Mandatory dep blocking | HealthPropagationTests |
| SC-VAL-003 | 100% consensus required | ChainVerifierTests |
| SC-AGT-018 | No deadlocks (cycles) | ServiceDAGTests, ChainVerifierTests |
| SC-OBS-069 | Dual logging | ObsChainTests |
| SC-OBS-071 | 4 OTEL modules | ObsChainTests |

## Appendix B: AOR Compliance Reference

| ID | Description | Enforcement |
|----|-------------|-------------|
| AOR-SAF-001 | Halt < 1s on STAMP violation | Integration tests |
| AOR-CNT-001 | Podman only | All container tests |
| AOR-QUA-001 | Zero warnings | CI build |
| AOR-AGT-001 | Compile before complete | TDGHarnessTests |
