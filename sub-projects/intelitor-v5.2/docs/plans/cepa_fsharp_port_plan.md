# CEPA to F# (Cepaf#) Translation Plan

**Date**: 2025-12-23
**Source**: Dart (lib/cepa)
**Target**: F# (lib/cepaf#)
**Objective**: Port the Cybernetic Execution and Performance Architect (CEPA) from Dart to F# to leverage .NET ecosystem, strong typing, and functional paradigms.

## 1.0 Executive Summary

The `cepaf#` application will replicate the functionality of the Dart-based CEPA orchestrator, transforming the object-oriented "Hybrid Pipeline" into a functional "Railway Oriented" workflow. It will maintain the OODA loop architecture (Observe-Orient-Decide-Act) but utilizes F#'s robust type system to enforce valid states.

## 2.0 Tech Stack Mapping

| Component | Dart Implementation | F# Implementation | Rationale |
| :--- | :--- | :--- | :--- |
| **CLI Parsing** | `package:args` | **`Argu`** | Powerful, type-safe argument parsing with Discriminated Unions. |
| **Orchestration** | `CepaHybridPipeline` (Class) | **`AsyncResult` Pipeline** | Composition of async functions returning `Result<unit, Error>`. |
| **Process Mgmt** | `Process.start` / custom wrapper | **`CliWrap`** | Fluent, async-friendly process execution handling stdout/stderr streams cleanly. |
| **Logging** | `talker` | **`Serilog`** | Structured logging with sinks for Console/File. |
| **YAML Parsing** | `package:yaml` | **`YamlDotNet`** | Robust YAML serialization/deserialization. |
| **UI Automation** | `puppeteer` | **`PuppeteerSharp`** | 1:1 .NET port of Puppeteer for Headless Chrome. |
| **Dependency Inj.** | `GetIt` | **Partial Application** | Functions as dependencies (Reader Monad pattern if needed, but simple partial application is preferred). |
| **Testing** | `test`, `mockito` | **`Expecto`**, **`FsUnit`** | Property-based testing and fluent assertions. |

## 3.0 Architecture: Functional OODA Loop

The application will be structured as a sequence of transformations on a `SystemState` type.

```fsharp
type SystemState = {
    Config: CepaConfig
    Log: ILogger
    // ... execution context
}

// The Pipeline
let runPipeline config =
    config
    |> Infrastructure.verify    // Phase 0
    >>= VTO.sterilize           // Phase 1
    >>= Builder.buildImages     // Phase 2
    >>= Verifier.verifyEnvs     // Phase 3
    >>= Tester.runUnitTests     // Phase 4
    >>= UITester.runBrowserCheck // Phase 5
```

## 4.0 Directory Structure

We will create a new solution `cepaf#` in `lib/cepaf#/`.

```
lib/cepaf#/
├── Cepaf.sln
├── src/
│   └── Cepaf/
│       ├── Cepaf.fsproj
│       ├── Program.fs          # Entry point, Argu setup
│       ├── Domain.fs           # Types (Config, Environment, Service)
│       ├── Infrastructure.fs   # Process Runner (CliWrap), Logger
│       ├── Phases/
│       │   ├── VTO.fs          # Sterilization Logic
│       │   ├── Builder.fs      # Image Building (OODA retry logic)
│       │   └── Verifier.fs     # AceVerifier (YAML parsing, Health checks)
│       └── Orchestrator.fs     # Pipeline composition
└── test/
    └── Cepaf.Tests/
        ├── Cepaf.Tests.fsproj
        └── ...
```

## 5.0 Implementation Phases

### Phase 1: Foundation & Infrastructure
**Goal**: Establish the F# project, logging, and basic process execution.
1.  Initialize `dotnet new console -lang "F#"` in `lib/cepaf#/src/Cepaf`.
2.  Install dependencies: `Argu`, `CliWrap`, `Serilog`, `Serilog.Sinks.Console`.
3.  Implement `ProcessRunner` module using `CliWrap` to stream output to Serilog.
4.  Implement `Domain` module with `Environment` and `Config` types.

### Phase 2: Core Logic Port (VTO & Builder)
**Goal**: Port `VTOOrchestrator` and `ImageBuilder`.
1.  Implement `VTO.sterilize` to run `podman-compose down -v`.
2.  Implement `Builder.buildImages`.
    *   Port the Topological Sort logic (using a simple recursive function or `FSharpx.Collections`).
    *   Port the OODA retry logic (Self-correction of `RUNN` -> `RUN` typos).

### Phase 3: Verification Logic (AceVerifier)
**Goal**: Port `AceVerifier` and YAML parsing.
1.  Install `YamlDotNet`.
2.  Implement `Verifier.parseCompose` to read `podman-compose.yml`.
3.  Implement dependency graph resolution.
4.  Implement `Verifier.verifyEnv` to run `podman-compose up` and check health.
5.  Port the `wait_for_database` and `check_port` logic.

### Phase 4: UI & CLI
**Goal**: Port `Puppeteer` checks and finalize CLI.
1.  Install `PuppeteerSharp`.
2.  Implement `UITester.verify` to launch browser and check localhost:4000.
3.  Wire everything up in `Program.fs` using `Argu` for flags (`--env`, `--sterilize`, etc.).

### Phase 5: Testing & Validation
1.  Create `Cepaf.Tests` project.
2.  Write unit tests for the Topological Sort and Config parsing.
3.  Run the new `cepaf#` against the existing `indrajaal` infrastructure to verify parity with the Dart version.

## 6.0 Actionable Next Steps
1.  Scaffold the .NET Solution.
2.  Begin Phase 1 Implementation.
