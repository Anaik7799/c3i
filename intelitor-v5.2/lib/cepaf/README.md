# CEPAF - Cybernetic Execution and Performance Architect Framework

**Version**: 20.0
**Language**: F# (.NET 8.0)
**License**: Proprietary - Indrajaal Project
**STAMP Compliance**: IEC 61508 SIL-2, ISO 27001

## 1. Overview

CEPAF (Cybernetic Execution and Performance Architect Framework) is a safety-critical F# framework for container orchestration, health verification, and test-driven code generation. It integrates deeply with the Indrajaal system's STAMP (Systems-Theoretic Accident Model and Processes) safety constraints.

### Key Features

- **STAMP Safety Constraints**: 20+ safety constraints enforced at runtime
- **FPPS 5-Method Consensus**: Five-Point Probing System for health verification
- **OODA Loop Controller**: Observe-Orient-Decide-Act cybernetic control
- **TDG (Test-Driven Generation)**: Tests must exist before code generation
- **AOR Engine**: Agent Operating Rules enforcement
- **Quadplex Observability**: 4-channel logging (Console, File, Telemetry, State)
- **Rootless Podman Integration**: Native socket communication via Unix sockets

### Architecture Diagram

```
+------------------------------------------------------------------+
|                     CEPAF Architecture                            |
+------------------------------------------------------------------+
|                                                                   |
|  +-------------+     +----------------+     +------------------+  |
|  |   Elixir    |     |   CEPAF F#     |     |    Podman        |  |
|  |   (OTP)     |<--->|   Framework    |<--->|    Socket        |  |
|  +-------------+     +----------------+     +------------------+  |
|        ^                     |                      |             |
|        |                     v                      v             |
|        |            +--------+--------+     +---------------+     |
|        |            |                 |     |   Container   |     |
|        |            |  Orchestrator   |     |   Runtime     |     |
|        |            |                 |     +---------------+     |
|        |            +--------+--------+            |              |
|        |                     |                     v              |
|  +-----+------+      +-------+-------+     +---------------+      |
|  | CepafPort  |      | Quadplex     |      | indrajaal-app |      |
|  | CepafClient|      | Logger       |      | indrajaal-db  |      |
|  +------------+      +--------------+      | indrajaal-obs |      |
|                              |             +---------------+      |
|                              v                                    |
|                      +---------------+                            |
|                      | 4 Channels:   |                            |
|                      | - Console     |                            |
|                      | - File        |                            |
|                      | - Telemetry   |                            |
|                      | - StateTracker|                            |
|                      +---------------+                            |
|                                                                   |
+------------------------------------------------------------------+
|  STAMP Safety Layer: SC-CNT-*, SC-CEP-*, SC-VAL-*, SC-AGT-*      |
+------------------------------------------------------------------+
```

## 2. Modules

### Core Modules

| Module | File | Purpose |
|--------|------|---------|
| Domain | `Domain.fs` | Core type definitions (Environment, ContainerState, AppError, TelemetryEvent) |
| Rop | `Rop.fs` | Railway-Oriented Programming utilities (AsyncResult, bind, map, tee) |
| Infrastructure | `Infrastructure.fs` | Process runner, circuit breaker, task execution |
| Orchestrator | `Orchestrator.fs` | Main protocol execution with AOR enforcement |
| OodaController | `OodaController.fs` | OODA loop for cybernetic container management |
| PathResolver | `Modules/PathResolver.fs` | Centralized path resolution (SC-CEP-001, SC-CEP-002) |

### Safety and Verification Modules

| Module | File | Purpose |
|--------|------|---------|
| ConstraintValidator | `Modules/ConstraintValidator.fs` | STAMP constraint validation at compile and runtime |
| Constraints | `Safety/Constraints.fs` | Container-specific STAMP constraints (Podman) |
| ServiceDAG | `Modules/ServiceDAG.fs` | Dependency graph with topological ordering |
| HealthPropagation | `Modules/HealthPropagation.fs` | Health state propagation through DAG |
| ChainVerifier | `Modules/ChainVerifier.fs` | FPPS 5-method consensus verification |
| TDGHarness | `Modules/TDGHarness.fs` | Test-Driven Generation enforcement |
| AOREngine | `Modules/AOREngine.fs` | Agent Operating Rules evaluation |

### Observability Modules

| Module | File | Purpose |
|--------|------|---------|
| QuadplexLogger | `Observability/QuadplexLogger.fs` | 4-channel logging coordinator |
| ConsoleChannel | `Observability/ConsoleChannel.fs` | Terminal output with ANSI colors |
| FileChannel | `Observability/FileChannel.fs` | Persistent file logging |
| TelemetryChannel | `Observability/TelemetryChannel.fs` | OpenTelemetry integration |
| StateTrackerChannel | `Observability/StateTrackerChannel.fs` | SQLite state persistence |
| MetricsCollector | `Observability/MetricsCollector.fs` | Prometheus-style metrics |

### Podman Integration Modules

| Module | File | Purpose |
|--------|------|---------|
| UnixSocket | `Client/UnixSocket.fs` | Unix socket HTTP client |
| HttpClient | `Client/HttpClient.fs` | Podman REST API client |
| Containers | `Api/Containers.fs` | Container lifecycle operations |
| Images | `Api/Images.fs` | Image management |
| Pods | `Api/Pods.fs` | Pod operations |
| Volumes | `Api/Volumes.fs` | Volume management |
| Networks | `Api/Networks.fs` | Network management |
| Probes | `Health/Probes.fs` | Health check probes |
| Stream | `Events/Stream.fs` | Event streaming from Podman |

### Phase Execution Modules

| Module | File | Purpose |
|--------|------|---------|
| VTO | `Phases/VTO.fs` | VTO (Verified Teardown and Orchestration) sterilization |
| Builder | `Phases/Builder.fs` | Container image building |
| Tester | `Phases/Tester.fs` | Test execution phase |
| AceVerifier | `Phases/AceVerifier.fs` | ACE lifecycle verification |
| DbVerifier | `Phases/DbVerifier.fs` | Database standalone verification |
| ObsVerifier | `Phases/ObsVerifier.fs` | Observability standalone verification |
| FormalVerification | `Phases/FormalVerification.fs` | Formal verification gate |

## 3. STAMP Constraints

CEPAF implements the following STAMP safety constraints:

### Container Constraints (SC-CNT-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-CNT-009 | NixOS/Podman only - no Docker/Alpine | Critical | Runtime validation |
| SC-CNT-010 | Localhost registry (`localhost/`) only | Critical | Image reference validation |
| SC-CNT-012 | Rootless Podman (5.4.1+) | Critical | Socket path detection |

### CEPAF Constraints (SC-CEP-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-CEP-001 | Path locality - all paths within CEPAF scope | High | PathResolver validation |
| SC-CEP-002 | Path decoupling - use PathResolver for all paths | High | Code analysis |
| SC-CEP-003 | FPPS 5-method consensus for health verification | Critical | ChainVerifier |
| SC-CEP-004 | Mandatory dependency blocking on failure | Critical | HealthPropagation |

### Validation Constraints (SC-VAL-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-VAL-003 | 100% consensus required for verification pass | Critical | All 5 FPPS methods must agree |

### Agent Constraints (SC-AGT-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-AGT-018 | No deadlocks - cycle detection in dependencies | Critical | ServiceDAG cycle detection |

### Performance Constraints (SC-PRF-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-PRF-050 | Response time < 50ms for health checks | High | Timeout enforcement |
| SC-PRF-055 | No blocking operations in async paths | High | AsyncBlockingDetector |

### Emergency Constraints (SC-EMR-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-EMR-057 | Emergency stop within 5 seconds | Critical | Timeout enforcement |
| SC-EMR-060 | Rollback capability required | Critical | Transaction support |

### Observability Constraints (SC-OBS-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-OBS-069 | Dual logging (Terminal + SigNoz) | High | QuadplexLogger |
| SC-OBS-071 | 4 OTEL channels active | High | Channel count validation |

### Pod Constraints (SC-POD-*)

| ID | Description | Severity | Enforcement |
|----|-------------|----------|-------------|
| SC-POD-001 | Pod naming convention (prefix: `indrajaal-`) | Warning | Name validation |
| SC-POD-002 | Resource limits required | Warning | Spec validation |
| SC-POD-003 | Health check required | Warning | Spec validation |
| SC-POD-004 | Restart policy required | Info | Spec validation |
| SC-POD-005 | Image source validation | Critical | Registry check |
| SC-POD-006 | Network isolation | Info | Namespace check |
| SC-POD-007 | Volume mount validation | Warning | Path validation |
| SC-POD-008 | Security context required | Warning | ReadOnly rootfs check |

## 4. Elixir Integration

### CepafPort Usage

The `CepafPort` module provides a GenServer-based Port interface to the F# CLI:

```elixir
# Start the port (typically via supervision tree)
{:ok, _pid} = Indrajaal.Integration.CepafPort.start_link([])

# List all containers
{:ok, containers} = CepafPort.list_containers()

# Inspect specific container
{:ok, info} = CepafPort.inspect_container("indrajaal-db")

# Check container health
{:ok, :healthy} = CepafPort.container_health("indrajaal-db")

# Get system info
{:ok, info} = CepafPort.system_info()

# Ping Podman service
:ok = CepafPort.ping()
```

### CepafClient API

The `CepafClient` module provides a high-level cached interface:

```elixir
# Start the client
{:ok, _pid} = Indrajaal.Integration.CepafClient.start_link([])

# List running containers (cached for 15 seconds)
{:ok, running} = CepafClient.list_running_containers()

# Get specific container (cached for 30 seconds)
{:ok, container} = CepafClient.get_container("indrajaal-db")

# Check if container is healthy
true = CepafClient.container_healthy?("indrajaal-db")

# Get health summary
{:ok, summary} = CepafClient.health_summary()

# Convenience methods
{:ok, db} = CepafClient.database_container()
{:ok, app} = CepafClient.app_container()
{:ok, obs} = CepafClient.observability_container()

# Cache management
:ok = CepafClient.invalidate_cache()
:ok = CepafClient.invalidate_container("indrajaal-db")
stats = CepafClient.cache_stats()  # %{size: 15, hits: 42, misses: 8, hit_ratio: 0.84}
```

### Telemetry Events

Both modules emit telemetry events for observability:

```elixir
# CepafPort events
[:indrajaal, :cepaf_port, :command, :start]
[:indrajaal, :cepaf_port, :command, :stop]
[:indrajaal, :cepaf_port, :command, :timeout]

# CepafClient events
[:indrajaal, :cepaf_client, :list_containers, :start]
[:indrajaal, :cepaf_client, :list_containers, :stop]
[:indrajaal, :cepaf_client, :get_container, :start]
[:indrajaal, :cepaf_client, :get_container, :stop]
[:indrajaal, :cepaf_client, :health_summary, :start]
[:indrajaal, :cepaf_client, :health_summary, :stop]
```

## 5. Testing

### Test Coverage Summary

| Test Project | Tests | Coverage |
|--------------|-------|----------|
| Cepaf.Tests | 127 | Core framework tests |
| Cepaf.Podman.Tests | 245 | Podman API tests |
| Cepaf.Tests (src) | 99 | Module unit tests |
| **Total** | **471** | Property + Unit tests |

### Running Tests

```bash
# Run all tests
cd lib/cepaf
dotnet test

# Run with verbose output
dotnet test --verbosity normal

# Run specific test project
dotnet test tests/Cepaf.Podman.Tests/Cepaf.Podman.Tests.fsproj

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run property tests only (FsCheck)
dotnet test --filter "Category=Property"
```

### Adding New Tests

1. Create test file in appropriate test project:

```fsharp
module Cepaf.Tests.MyModuleTests

open Xunit
open FsCheck
open FsCheck.Xunit
open Cepaf.Modules.MyModule

[<Fact>]
let ``should validate constraint`` () =
    let result = validateSomething input
    Assert.True(result)

[<Property>]
let ``property: always maintains invariant`` (input: int) =
    let result = process input
    result >= 0
```

2. Add to `.fsproj` file:

```xml
<Compile Include="MyModuleTests.fs" />
```

3. Run tests to verify:

```bash
dotnet test --filter "FullyQualifiedName~MyModuleTests"
```

## 6. Building

### Prerequisites

- .NET 8.0 SDK
- Podman 5.4.1+ (rootless)
- F# language support

### Build Commands

```bash
# Navigate to CEPAF directory
cd lib/cepaf

# Restore dependencies
dotnet restore

# Build all projects (Debug)
dotnet build

# Build for Release
dotnet build -c Release

# Build specific project
dotnet build src/Cepaf/Cepaf.fsproj

# Publish self-contained executable
dotnet publish src/Cepaf/Cepaf.fsproj -c Release -r linux-x64 --self-contained

# Clean build artifacts
dotnet clean
```

### Running the CLI

```bash
# Run via dotnet
dotnet run --project src/Cepaf/Cepaf.fsproj -- --help

# Run with environment flags
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y --verify

# Available CLI options:
#   -e, --env <ENV>      Target environments (DEV, TEST, DEMO, PROD)
#   -y, --yes            Auto-confirm prompts
#   -i, --no-infra       Skip infrastructure checks
#   --no-sterilize       Skip VTO sterilization
#   --no-build           Skip container build
#   -v, --verify         Enable formal verification
#   -d, --db-test        Standalone database test mode
#   -o, --obs-test       Standalone observability test mode
#   --test               Run Elixir test suite
#   --ui                 Run UI verification
#   -p, --patient-mode   Enable patient mode (extended timeouts)

# Run standalone DB test
dotnet run --project src/Cepaf/Cepaf.fsproj -- -d -y

# Run with formal verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -v -p
```

### Project Structure

```
lib/cepaf/
+-- src/
|   +-- Cepaf/                 # Core framework
|   |   +-- Domain.fs          # Type definitions
|   |   +-- Rop.fs             # Railway-oriented programming
|   |   +-- Infrastructure.fs  # Process runner, circuit breaker
|   |   +-- Orchestrator.fs    # Main protocol
|   |   +-- OodaController.fs  # OODA cybernetic loop
|   |   +-- Modules/           # Core modules
|   |   +-- Phases/            # Execution phases
|   |   +-- Observability/     # Logging & metrics
|   |   +-- Program.fs         # CLI entry point
|   |
|   +-- Cepaf.Podman/          # Podman API client
|   |   +-- Domain/            # Podman types
|   |   +-- Client/            # HTTP/Socket clients
|   |   +-- Api/               # API operations
|   |   +-- Safety/            # STAMP constraints
|   |   +-- Health/            # Health probes
|   |   +-- Events/            # Event streaming
|   |
|   +-- Cepaf.Bridge/          # Elixir bridge (JSON-RPC)
|   +-- Cepaf.Tests/           # Unit tests
|
+-- tests/
|   +-- Cepaf.Podman.Tests/    # Podman integration tests
|
+-- services/
|   +-- Cepaf.Podman.Grpc/     # gRPC service (alternative to Port)
|
+-- tools/
|   +-- Cepaf.Podman.Cli/      # Standalone CLI tool
|
+-- benchmarks/
|   +-- Cepaf.Podman.Benchmarks/  # Performance benchmarks
|
+-- artifacts/                 # Build outputs, state DB
+-- README.md                  # This file
```

## 7. Configuration

### System Registry

The `SystemRegistry` type defines all paths and configuration:

```fsharp
type SystemRegistry = {
    LogPath: string                           // e.g., "lib/cepaf/artifacts/cepa.log"
    DatabasePath: string                      // e.g., "lib/cepaf/artifacts/cepa-state.db"
    TempDir: string                           // e.g., "lib/cepaf/artifacts/tmp"
    ComposeFiles: Map<Environment, string>    // Compose file per environment
    ContainerNames: Map<string, string>       // Container name mappings
    PortMap: Map<string, int>                 // Service ports
    ReadyPatterns: Map<string, string>        // Log patterns for readiness
    Dockerfiles: Map<string, string>          // Dockerfile paths
    Constraints: SafetyConstraint list        // Active STAMP constraints
    PodmanSocket: PodmanSocket option         // Unix socket path
}
```

### Environment Variables

```bash
# Patient Mode (extended timeouts)
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16"

# Podman socket (rootless)
export XDG_RUNTIME_DIR=/run/user/$(id -u)
# Socket at: $XDG_RUNTIME_DIR/podman/podman.sock
```

## 8. Safety Guarantees

CEPAF provides the following safety guarantees:

1. **Cycle-Free Dependencies**: DAG validation prevents circular dependencies (SC-AGT-018)
2. **Consensus-Based Health**: 5-method FPPS verification with 100% agreement (SC-VAL-003)
3. **Emergency Stop**: All dependents stopped within 1 second (AOR-SAF-001)
4. **Registry Isolation**: Only `localhost/` images allowed (SC-CNT-010)
5. **Rootless Operation**: No root privileges required (SC-CNT-012)
6. **Test-Before-Code**: TDG enforces tests exist before generation (Omega_4)
7. **Zero Warnings**: Compilation must produce zero warnings (AOR-QUA-001)
8. **Dual Logging**: All events logged to console and file (SC-OBS-069)

## 9. Related Documentation

- [GEMINI.md](../../GEMINI.md) - Full system specification
- [CLAUDE.md](../../CLAUDE.md) - Agent instructions
- [PROJECT_TODOLIST.md](../../PROJECT_TODOLIST.md) - Project task tracking
- [SOPv5.11 Phases](../../scripts/sopv511/) - Deployment procedures

---

**The Cybernetic Pledge**: "I recognize the Codebase as a Living Graph. I pledge to fight Entropy with Simplicity, fragility with Resilience, and blindness with Observability. I am the Architect of the Loop."
