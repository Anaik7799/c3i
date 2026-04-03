# Journal Entry: CEPA Hybrid Architecture & Unified Pipeline Refactor

**Date**: 2025-12-23
**Status**: ✅ Completed
**Context**: Transition from "Classic" shell-script-based verification to a robust, testable, Dart-based "Hybrid" architecture.
**Authors**: Cybernetic Architect (Gemini)

## 1.0 Architecture Overview

The **Cybernetic Execution and Performance Architect (CEPA)** has been refactored into a unified, modular Dart application. It now supports a **Hybrid Pipeline** model that integrates legacy container orchestration with modern infrastructure verification, testing, and UI automation.

### 1.1 Architectural Principles
1.  **Unified Entry Point**: A single CLI (`lib/cepa/cepa.dart`) handles all verification modes (Classic, Hybrid, Mixed).
2.  **Dependency Injection (DI)**: Uses `get_it` to decouple logic from infrastructure (Process execution, Network I/O, Logging). This enables 100% testability.
3.  **Layered Abstraction**:
    *   **Presentation Layer**: CLI Argument Parsing, User Prompts.
    *   **Orchestration Layer**: `CepaHybridPipeline` manages the sequence of operations.
    *   **Component Layer**: Specialized classes (`VTOOrchestrator`, `ImageBuilder`, `AceVerifier`) handle specific domains.
    *   **Infrastructure Layer**: Wrappers around system calls (`ProcessRunner`, `NetworkService`).
4.  **Observability First**: Integrated `talker` for structured, leveled logging and `timing` for precise performance tracking.

---

## 2.0 Modules & Code Organization

The codebase is organized to promote separation of concerns and maintainability.

### 2.1 Directory Structure
```
/
├── lib/
│   └── cepa/
│       ├── cepa.dart          # Entry point, DI setup, CLI parsing, Shared Utilities
│       └── orchestrator.dart  # Pipeline logic, Component classes, Data structures
├── bin/
│   └── (removed)              # logic moved to lib for library-level access
└── test/
    └── cepa/
        ├── cepa_test.dart     # Comprehensive integration tests
        └── cepa_test.mocks.dart # Generated mocks (Mockito)
```

### 2.2 Key Classes (Level 3 Detail)

#### `CepaHybridPipeline` (The Brain)
*   **Responsibility**: Executes the verification phases in the correct order based on configuration.
*   **Dependencies**: `VTOOrchestrator`, `ImageBuilder`, `AceVerifier`, `ProcessRunner`, `NetworkService`.
*   **Configuration**: Accepts a `CepaConfig` object defining which phases to run.

#### `ProcessRunner` (The Hands)
*   **Responsibility**: Wraps `Process.start` and `Process.run`.
*   **Features**:
    *   Streams stdout/stderr to `Talker` in real-time.
    *   Tracks execution time using `SyncTimeTracker`.
    *   Provides a standardized error handling mechanism.

#### `AceVerifier` (The Inspector)
*   **Responsibility**: Verifies the state of running environments (containers, ports, logs).
*   **Logic**: Parses `podman-compose.yml`, builds a dependency graph, and verifies services in topological order.

---

## 3.0 Data Flow

How information moves through the system:

1.  **Input**: User runs `dart lib/cepa/cepa.dart [flags]`.
2.  **Parsing**: `ArgParser` converts flags to an `ArgResults` map.
3.  **Configuration**:
    *   `runPipeline` logic determines active environments by checking file existence.
    *   `CepaConfig` is instantiated with boolean flags (e.g., `runTests: true`).
4.  **Execution**:
    *   `CepaHybridPipeline` reads `CepaConfig`.
    *   It calls methods on Components (e.g., `_verifier.verifyAllEnvironments()`).
5.  **Infrastructure Interaction**:
    *   Components call `ProcessRunner.run()`.
    *   `ProcessRunner` spawns OS processes (`podman`, `mix`).
6.  **Feedback**:
    *   Process output is streamed to `Talker`.
    *   `Talker` formats logs (colors, timestamps) and prints to Console.
    *   Exceptions bubble up to `runPipeline`, which catches them and logs a "PROTOCOL FAILED" summary.

---

## 4.0 Control Flow (OODA Loop)

The execution follows a strict sequence, mimicking an OODA loop (Observe-Orient-Decide-Act).

### 4.1 Initialization
1.  **Setup**: `setupServiceLocator()` registers singletons in `GetIt`.
2.  **Identity**: Log Process ID (`posix.getpid()`).
3.  **UI**: Clear screen, print Banner.

### 4.2 Decision Phase (`runPipeline`)
1.  **Environment Discovery**: Check for `podman-compose.*.yml` files.
2.  **User Confirmation**: If destructive actions (sterilize/build) are enabled and `-y` is missing, prompt user.
3.  **Config Construction**: Build `CepaConfig`.

### 4.3 Action Phase (`CepaHybridPipeline.run`)
1.  **Infra Check** (Optional): Verify `podman` and `mix` versions.
2.  **Sterilization** (Optional): `podman-compose down -v`.
3.  **Build** (Optional): `podman build` loop with topological sort.
4.  **Environment Verification** (Optional):
    *   Start dependencies (DB, Obs).
    *   Wait for health checks.
    *   Start App.
    *   Verify HTTP/TCP accessibility.
5.  **Tests** (Optional): `mix test`.
6.  **UI Check** (Optional): Launch Puppeteer, navigate to localhost, verify title.

---

## 5.0 Test Setup & Execution

Achieving 100% coverage required a robust mocking strategy.

### 5.1 Test Infrastructure
*   **Framework**: `package:test`.
*   **Mocking**: `package:mockito` with `build_runner`.
*   **Dependency Injection**: `GetIt` allows swapping real implementations with Mocks in `setUp()`.

### 5.2 The `cepa_test.dart` Strategy
1.  **Isolation**: `setUp` calls `getIt.reset()` to ensure a clean state for every test.
2.  **Mock Registration**:
    ```dart
    getIt.registerLazySingleton<ProcessRunner>(() => MockProcessRunner());
    // ... register other mocks
    ```
3.  **Stubbing**:
    *   `when(mockRunner.run(...))` stubs shell command execution.
    *   `when(mockNetwork.connect(...))` stubs TCP socket connections.
    *   `when(mockRunner.runProcess('podman', ['ps'...]))` returns specific `ProcessResult` to simulate container states (Running/Stopped).
4.  **Verification**:
    *   `verify(mockRunner.run('mix', ['test'])).called(1)` ensures the pipeline actually attempted the action.
5.  **Output Capture**:
    *   `runZoned` with `ZoneSpecification` intercepts `print` calls (used by `printColor`) to validate CLI output strings.

---

## 6.0 CLI Flow & Usage

The unified CLI supports mix-and-match of all features.

### 6.1 Flags
| Flag | Abbr | Default | Description |
|------|------|---------|-------------|
| `--help` | `-h` | - | Show usage |
| `--yes` | `-y` | false | Skip confirmation prompts |
| `--env` | `-e` | - | Target specific envs (DEV, TEST...) |
| `--infra` | `-i` | true | Verify system tools (Podman/Mix) |
| `--test` | `-t` | false | Run Elixir unit tests |
| `--ui` | - | false | Run Puppeteer UI check |
| `--sterilize` | - | true | Run cleanup phase |
| `--build` | - | true | Run build phase |

### 6.2 Usage Scenarios

**Scenario A: Full Dev Verification (Classic)**
*   User wants to wipe everything, rebuild, and check the DEV environment.
*   Command: `dart lib/cepa/cepa.dart --env DEV --yes`

**Scenario B: CI/CD Quick Check (Hybrid)**
*   User wants to verify infrastructure tools and run unit tests without rebuilding containers.
*   Command: `dart lib/cepa/cepa.dart --infra --test --no-sterilize --no-build`

**Scenario C: UI Smoke Test**
*   User wants to verify the web page loads.
*   Command: `dart lib/cepa/cepa.dart --ui --no-sterilize --no-build`

---

## 7.0 5-Level Detail: Deep Dive into `AceVerifier`

To illustrate the depth of the system, here is a breakdown of the `AceVerifier` component.

### Level 1: Purpose
`AceVerifier` ensures that the target environment (Dev, Test, Prod) is actually running and healthy.

### Level 2: Component Interaction
It interacts with `ProcessRunner` to execute `podman` commands and `NetworkService` to check TCP ports. It parses `YAML` configuration to understand service dependencies.

### Level 3: Logic Flow (`_verifyDevEnvironment`)
1.  **Start DB**: `podman-compose up -d db`.
2.  **Wait Loop**: Loops up to 12 times (5s delay), running `mix run -e Ecto...` to check connectivity.
3.  **Start Obs**: `podman-compose up -d obs`.
4.  **Start App**: Uses `iex -S mix phx.server`.
5.  **Stream Analysis**: Listens to stdout for "Access IndrajaalWeb.Endpoint".
6.  **Cleanup**: Ensures `serverProcess.kill()` is called in `finally` block.

### Level 4: Dependency Resolution (Topological Sort)
For containerized environments, it:
1.  Reads `podman-compose.yml`.
2.  Extracts `services` and `depends_on`.
3.  Builds a directed graph: `Node(Service) -> Edges(Dependencies)`.
4.  Uses `package:graphs` `topologicalSort` to determine the correct startup order (e.g., `Base -> DB -> Obs -> App`).
5.  Iterates through the sorted list to start containers sequentially.

### Level 5: Infrastructure Abstraction
It never calls `Process.start` directly. It asks `GetIt` for the `ProcessRunner` singleton.
*   **Real Execution**: `ProcessRunner` uses `SyncTimeTracker` to measure the exact millisecond duration of the `podman` command and logs it via `Talker` with `LogLevel.info`.
*   **Test Execution**: `MockProcessRunner` intercepts the call. It matches the arguments `['podman', 'up', ...]` and returns a `Future<void>` immediately (or after a simulated delay), allowing the test to verify the *intent* without spinning up a real container.

