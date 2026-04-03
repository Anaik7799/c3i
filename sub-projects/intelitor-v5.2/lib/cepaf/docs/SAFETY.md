# Cepaf.Podman Safety Documentation

**Version**: 1.0.0
**Reference**: GEMINI.md Section 5.0 - Unified Safety Constraints
**Compliance**: IEC 61508 SIL-2, ISO 27001

This document describes the STAMP (Systems-Theoretic Accident Model and Processes) safety constraints implemented in the Cepaf.Podman library to ensure safe container operations in production environments.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Safety Constraint Identifiers](#2-safety-constraint-identifiers)
3. [Validation Functions](#3-validation-functions)
4. [Safe Operations](#4-safe-operations)
5. [Emergency Operations](#5-emergency-operations)
6. [Compliance Requirements](#6-compliance-requirements)
7. [Integration Patterns](#7-integration-patterns)

---

## 1. Overview

The Safety module (`Cepaf.Podman.Safety.Constraints`) implements STAMP-based safety constraints to prevent hazardous conditions during container operations. All constraints are derived from the enterprise safety specification (GEMINI.md).

### Key Principles

1. **Defense in Depth**: Multiple validation layers before operations
2. **Fail-Safe Defaults**: Operations fail closed on constraint violations
3. **Audit Trail**: All violations are timestamped and classified
4. **Graceful Degradation**: Warnings allow operation; criticals block

### Severity Levels

| Severity | Action | Description |
|----------|--------|-------------|
| **Critical** | Operation BLOCKED | Must fix before operation can proceed |
| **Warning** | Operation ALLOWED | Should fix, but operation continues |
| **Info** | Logged only | Informational, no action required |

---

## 2. Safety Constraint Identifiers

### 2.1 Container Constraints (SC-CNT-*)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-CNT-009 | NixOS/Podman Only | All operations must use NixOS/Podman, not Docker | Critical |
| SC-CNT-010 | Localhost Registry | Images must use `localhost/` registry only | Critical |
| SC-CNT-012 | Rootless Mode | Podman must run in rootless mode | Critical |

### 2.2 Pod/Container Constraints (SC-POD-*)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-POD-001 | Naming Convention | Containers/pods should follow `indrajaal-*` naming | Warning |
| SC-POD-002 | Resource Limits | CPU/memory limits must be specified | Warning |
| SC-POD-003 | Health Check Required | Containers must have health checks | Warning |
| SC-POD-004 | Restart Policy | Restart policy should be specified | Info |
| SC-POD-005 | Image Source | Images must use explicit version tags | Warning |
| SC-POD-006 | Network Isolation | Network namespace should be specified | Info |
| SC-POD-007 | Volume Mounts | Volume mounts outside /home/ flagged | Warning |
| SC-POD-008 | Security Context | Security context should be configured | Warning |

### 2.3 Performance Constraints (SC-PRF-*)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-PRF-050 | Response Latency | API responses must complete in <50ms | Warning |
| SC-PRF-055 | No Blocking Ops | No blocking operations in async paths | Warning |

### 2.4 Emergency Constraints (SC-EMR-*)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-EMR-057 | Stop Timeout | Container stop must complete in <5s | Critical |
| SC-EMR-060 | Rollback Capability | Must support rollback to previous state | Warning |

---

## 3. Validation Functions

### 3.1 Namespace and Types

```fsharp
namespace Cepaf.Podman.Safety

open Cepaf.Podman.Domain

module Constraints =

    /// Safety constraint identifier
    type ConstraintId =
        | SC_CNT_009  // NixOS/Podman only
        | SC_CNT_010  // Localhost registry only
        | SC_CNT_012  // Rootless mode
        | SC_POD_001  // Pod naming convention
        | SC_POD_002  // Resource limits required
        | SC_POD_003  // Health check required
        | SC_POD_004  // Restart policy required
        | SC_POD_005  // Image source validation
        | SC_POD_006  // Network isolation
        | SC_POD_007  // Volume mount validation
        | SC_POD_008  // Security context required
        | SC_PRF_050  // Response latency < 50ms
        | SC_PRF_055  // No blocking operations
        | SC_EMR_057  // Stop < 5s
        | SC_EMR_060  // Rollback capability

    /// Constraint violation
    type Violation = {
        Constraint: ConstraintId
        Resource: string
        Message: string
        Severity: ViolationSeverity
        Timestamp: DateTimeOffset
    }

    and ViolationSeverity =
        | Critical  // Must fix before operation
        | Warning   // Should fix, operation allowed
        | Info      // Informational only

    /// Validation result
    type ValidationResult =
        | Valid
        | Invalid of Violation list
```

### 3.2 Container Spec Validation

```fsharp
/// Validate container specification against all safety constraints
val validateContainerSpec: ContainerSpec -> ValidationResult
```

**Checks Performed:**

1. **SC-POD-005**: Image must start with `localhost/`
2. **SC-POD-001**: Container name should follow naming convention
3. **SC-POD-002**: Memory limits should be specified
4. **SC-POD-003**: Health check should be configured
5. **SC-POD-004**: Restart policy should be specified
6. **SC-POD-007**: Volume mounts outside `/home/` are flagged
7. **SC-POD-008**: Security context should be configured

**Example:**

```fsharp
open Cepaf.Podman.Safety.Constraints

let spec =
    ContainerSpec.create "docker.io/nginx:latest"  // VIOLATION: not localhost/
    |> ContainerSpec.withName "nginx"              // VIOLATION: not indrajaal-*
    // No memory limit - VIOLATION
    // No health check - VIOLATION

match validateContainerSpec spec with
| Valid ->
    printfn "All constraints passed"
| Invalid violations ->
    for v in violations do
        printfn "[%A] %s: %s"
            v.Severity
            (sprintf "%A" v.Constraint)
            v.Message
    // Output:
    // [Critical] SC_POD_005: Image 'docker.io/nginx:latest' must use localhost/ registry (SC-POD-005)
    // [Warning] SC_POD_001: Container name 'nginx' should follow naming convention (SC-POD-001)
    // [Warning] SC_POD_002: Memory limit not specified (SC-POD-002)
    // [Warning] SC_POD_003: Health check not configured (SC-POD-003)
```

### 3.3 Pod Spec Validation

```fsharp
/// Validate pod specification against safety constraints
val validatePodSpec: PodSpec -> ValidationResult
```

**Checks Performed:**

1. **SC-POD-001**: Pod name should start with `indrajaal-`
2. **SC-POD-006**: Network namespace should be specified

### 3.4 Image Reference Validation

```fsharp
/// Validate image reference for registry compliance
val validateImageReference: string -> ValidationResult
```

**Checks Performed:**

1. **SC-CNT-010**: Image must use `localhost/` registry
2. **SC-POD-005**: Image should use explicit version tag (not `:latest`)

**Example:**

```fsharp
// Valid
validateImageReference "localhost/myapp:1.2.3"  // Valid

// Invalid - wrong registry
validateImageReference "docker.io/nginx:1.24"
// Invalid [{
//     Constraint = SC_CNT_010
//     Resource = "docker.io/nginx:1.24"
//     Message = "Image 'docker.io/nginx:1.24' must use localhost/ registry (SC-CNT-010)"
//     Severity = Critical
//     ...
// }]

// Invalid - no version tag
validateImageReference "localhost/myapp"
// Invalid [{
//     Constraint = SC_POD_005
//     Resource = "localhost/myapp"
//     Message = "Image should use explicit version tag, not ':latest' (SC-POD-005)"
//     Severity = Warning
//     ...
// }]
```

### 3.5 Runtime Validation

```fsharp
/// Validate client is using rootless Podman on Linux
val validateRootless: PodmanClient -> AsyncPodmanResult<ValidationResult>

/// Validate container is healthy
val validateContainerHealth: PodmanClient -> containerId: string -> AsyncPodmanResult<ValidationResult>

/// Validate all running containers meet safety requirements
val validateAllContainers: PodmanClient -> AsyncPodmanResult<ValidationResult>
```

**Example:**

```fsharp
async {
    // Check runtime environment
    let! rootlessResult = Constraints.validateRootless client
    match rootlessResult with
    | Ok Valid -> printfn "Rootless mode confirmed"
    | Ok (Invalid vs) ->
        for v in vs do printfn "WARNING: %s" v.Message
    | Error e -> printfn "ERROR: %s" (PodmanError.toMessage e)

    // Validate all running containers
    let! allResult = Constraints.validateAllContainers client
    match allResult with
    | Ok Valid -> printfn "All containers meet safety requirements"
    | Ok (Invalid violations) ->
        printfn "Found %d violations:" violations.Length
        for v in violations do
            printfn "  - [%A] %s" v.Severity v.Message
    | Error e -> printfn "Validation failed: %s" (PodmanError.toMessage e)
}
```

### 3.6 Validation Result Combinators

```fsharp
module ValidationResult =
    /// Check if validation passed
    val isValid: ValidationResult -> bool

    /// Get list of violations
    val violations: ValidationResult -> Violation list

    /// Combine two validation results
    val combine: ValidationResult -> ValidationResult -> ValidationResult

    /// Combine list of validation results
    val combineAll: ValidationResult list -> ValidationResult
```

**Example:**

```fsharp
let containerValidation = validateContainerSpec spec
let imageValidation = validateImageReference spec.Image

let combined = ValidationResult.combine containerValidation imageValidation

match combined with
| Valid -> printfn "All validations passed"
| Invalid vs -> printfn "Total violations: %d" vs.Length
```

---

## 4. Safe Operations

Safe operations are pre-validated wrappers around standard API operations that enforce safety constraints before execution.

### 4.1 Safe Container Creation

```fsharp
/// Create container with validation (blocks on Critical violations)
val safeCreateContainer: PodmanClient -> ContainerSpec -> AsyncPodmanResult<string>

/// Create and start container with validation
val safeCreateAndStart: PodmanClient -> ContainerSpec -> AsyncPodmanResult<string>
```

**Behavior:**

1. Validates `ContainerSpec` against all constraints
2. If any **Critical** violations exist, returns `Error (ValidationFailed [messages])`
3. If only **Warning/Info** violations exist, proceeds with operation
4. On success, returns container ID

**Example:**

```fsharp
async {
    let spec =
        ContainerSpec.create "localhost/myapp:1.0.0"
        |> ContainerSpec.withName "indrajaal-myapp"
        |> ContainerSpec.withMemoryLimitMB 512
        |> ContainerSpec.withHttpHealthCheck "http://localhost/health" (TimeSpan.FromSeconds(30.0)) 3
        |> ContainerSpec.withRestartAlways

    let! result = Constraints.safeCreateAndStart client spec

    match result with
    | Ok containerId ->
        printfn "Container created: %s" containerId
    | Error (PodmanError.ValidationFailed errors) ->
        printfn "Validation failed:"
        for e in errors do printfn "  - %s" e
    | Error e ->
        printfn "Operation failed: %s" (PodmanError.toMessage e)
}
```

### 4.2 Safe Image Pull

```fsharp
/// Pull image with registry validation (localhost/ only)
val safePullImage: PodmanClient -> reference: string -> AsyncPodmanResult<string>
```

**Behavior:**

1. Validates image reference against `SC-CNT-010` (localhost registry)
2. If reference does not start with `localhost/`, returns `Error (RegistryNotAllowed ...)`
3. Otherwise, proceeds with pull operation

**Example:**

```fsharp
async {
    // This will succeed
    let! result1 = Constraints.safePullImage client "localhost/myapp:1.0.0"

    // This will fail - wrong registry
    let! result2 = Constraints.safePullImage client "docker.io/nginx:latest"
    // Error (RegistryNotAllowed "Image 'docker.io/nginx:latest' must use localhost/ registry (SC-CNT-010)")
}
```

### 4.3 Safe Pod Creation

```fsharp
/// Create pod with validation
val safeCreatePod: PodmanClient -> PodSpec -> AsyncPodmanResult<string>
```

**Behavior:**

1. Validates `PodSpec` against all pod constraints
2. Blocks on Critical violations
3. Proceeds with Warning/Info violations

---

## 5. Emergency Operations

Emergency operations are designed for fast, safe shutdown of containers when immediate action is required.

### 5.1 Emergency Stop (SC-EMR-057)

```fsharp
/// Stop container within timeout, force kill if necessary
val emergencyStop: PodmanClient -> containerId: string -> timeoutSeconds: int -> AsyncPodmanResult<unit>
```

**Behavior:**

1. Attempts graceful stop with specified timeout
2. If graceful stop fails, sends SIGKILL
3. Guarantees container termination within timeout + 1s

**Example:**

```fsharp
async {
    // Stop container within 5 seconds (per SC-EMR-057)
    let! result = Constraints.emergencyStop client "mycontainer" 5
    match result with
    | Ok () -> printfn "Container stopped"
    | Error e -> printfn "Emergency stop failed: %s" (PodmanError.toMessage e)
}
```

### 5.2 Emergency Remove (SC-EMR-060)

```fsharp
/// Stop and remove container with all associated resources
val emergencyRemove: PodmanClient -> containerId: string -> AsyncPodmanResult<unit>
```

**Behavior:**

1. Calls `emergencyStop` with 5-second timeout
2. Force removes container including volumes
3. Cleans up associated resources

### 5.3 Emergency Stop All

```fsharp
/// Emergency stop all running containers
val emergencyStopAll: PodmanClient -> AsyncPodmanResult<int>
```

**Behavior:**

1. Lists all running containers
2. Sends emergency stop to each in parallel
3. Returns count of stopped containers

**Example:**

```fsharp
async {
    printfn "EMERGENCY: Stopping all containers..."
    let! result = Constraints.emergencyStopAll client
    match result with
    | Ok count -> printfn "Stopped %d containers" count
    | Error e -> printfn "Emergency stop failed: %s" (PodmanError.toMessage e)
}
```

---

## 6. Compliance Requirements

### 6.1 Registry Restriction (SC-CNT-010)

**Requirement**: All container images MUST be sourced from the `localhost/` registry only.

**Rationale**:
- Prevents supply chain attacks from external registries
- Ensures all images are pre-validated and trusted
- Supports air-gapped deployments

**Implementation**:
- `Images.pull` function checks registry prefix
- `validateImageReference` enforces this constraint
- Non-compliant references return `Error (RegistryNotAllowed ...)`

**Acceptable Image References**:
```
localhost/myapp:1.0.0
localhost/nginx:1.24-alpine
localhost/postgres:15.2
```

**Rejected Image References**:
```
docker.io/nginx:latest      <- External registry
ghcr.io/org/app:1.0         <- External registry
nginx:1.24                   <- Implicit docker.io
myapp:1.0.0                  <- No registry prefix
```

### 6.2 Rootless Mode (SC-CNT-012)

**Requirement**: Podman MUST run in rootless mode.

**Rationale**:
- Reduces attack surface
- Limits container escape impact
- Follows principle of least privilege

**Detection**:
```fsharp
// Check socket path for rootless indicator
match client.Config.Socket with
| PodmanSocket.Rootless (uid, path) ->
    // Running in rootless mode (e.g., /run/user/1000/podman/podman.sock)
    printfn "Rootless mode: user %s" uid
| PodmanSocket.Rootful path ->
    // Running as root (e.g., /run/podman/podman.sock)
    printfn "WARNING: Running as root"
```

### 6.3 Resource Limits (SC-POD-002)

**Requirement**: All containers SHOULD have resource limits defined.

**Rationale**:
- Prevents runaway containers from exhausting host resources
- Enables fair resource sharing
- Supports capacity planning

**Recommended Limits**:
```fsharp
let spec =
    ContainerSpec.create "localhost/myapp:1.0.0"
    |> ContainerSpec.withMemoryLimitMB 512        // Memory: 512 MB
    |> ContainerSpec.withResources {
        ResourceConfig.empty with
            Cpu = Some { CpuConfig.empty with Shares = Some 1024UL }
            PidsLimit = Some 100L
    }
```

### 6.4 Health Checks (SC-POD-003)

**Requirement**: All containers SHOULD have health checks configured.

**Rationale**:
- Enables automated health monitoring
- Supports orchestration decisions
- Provides early warning of container issues

**Standard Health Check**:
```fsharp
let spec =
    ContainerSpec.create "localhost/myapp:1.0.0"
    |> ContainerSpec.withHttpHealthCheck
        "http://localhost:8080/health"
        (TimeSpan.FromSeconds(30.0))  // Interval
        3                               // Retries
```

### 6.5 Version Tags (SC-POD-005)

**Requirement**: Images SHOULD use explicit version tags, not `:latest`.

**Rationale**:
- Ensures reproducible deployments
- Prevents unintended updates
- Supports rollback operations

**Good**:
```
localhost/myapp:1.2.3
localhost/myapp:1.2.3-alpine
localhost/myapp:2024.12.23
```

**Bad**:
```
localhost/myapp:latest
localhost/myapp            <- Implies :latest
```

---

## 7. Integration Patterns

### 7.1 Pre-Flight Validation

Validate all specifications before deployment:

```fsharp
let deployWithValidation (client: PodmanClient) (spec: ContainerSpec) = async {
    // Step 1: Validate spec
    let validation = Constraints.validateContainerSpec spec
    match validation with
    | Invalid violations when violations |> List.exists (fun v -> v.Severity = Critical) ->
        let messages = violations |> List.map (fun v -> v.Message)
        return Error (PodmanError.ValidationFailed messages)
    | Invalid violations ->
        // Log warnings but continue
        for v in violations do
            printfn "[WARN] %s" v.Message
        return! Containers.createAndStart client spec
    | Valid ->
        return! Containers.createAndStart client spec
}
```

### 7.2 Validation Middleware

Create a validation wrapper for all operations:

```fsharp
type SafePodmanClient = {
    Inner: PodmanClient
}

module SafePodmanClient =

    let createContainer (client: SafePodmanClient) (spec: ContainerSpec) =
        Constraints.safeCreateContainer client.Inner spec

    let pullImage (client: SafePodmanClient) (reference: string) =
        Constraints.safePullImage client.Inner reference

    let createPod (client: SafePodmanClient) (spec: PodSpec) =
        Constraints.safeCreatePod client.Inner spec
```

### 7.3 Violation Reporting

Generate compliance reports:

```fsharp
let generateComplianceReport (client: PodmanClient) = async {
    let! containersResult = Containers.listAll client
    match containersResult with
    | Error e -> return Error e
    | Ok containers ->
        let report = StringBuilder()
        report.AppendLine("=== Container Compliance Report ===") |> ignore
        report.AppendLine(sprintf "Generated: %O" DateTimeOffset.UtcNow) |> ignore
        report.AppendLine(sprintf "Total Containers: %d" containers.Length) |> ignore
        report.AppendLine() |> ignore

        for container in containers do
            report.AppendLine(sprintf "Container: %s (%s)" (container.Names.[0]) container.Id) |> ignore

            // Check image reference
            let imageValidation = Constraints.validateImageReference container.Image
            match imageValidation with
            | Valid -> report.AppendLine("  [OK] Image reference valid") |> ignore
            | Invalid vs ->
                for v in vs do
                    report.AppendLine(sprintf "  [%A] %s" v.Severity v.Message) |> ignore

            // Check health status
            let! healthResult = Containers.healthCheck client container.Id
            match healthResult with
            | Ok HealthStatus.Healthy ->
                report.AppendLine("  [OK] Health: Healthy") |> ignore
            | Ok HealthStatus.NoHealthcheck ->
                report.AppendLine("  [WARN] Health: No health check configured") |> ignore
            | Ok (HealthStatus.Unhealthy _) ->
                report.AppendLine("  [CRIT] Health: Unhealthy") |> ignore
            | _ -> ()

            report.AppendLine() |> ignore

        return Ok (report.ToString())
}
```

### 7.4 Violation Formatting

```fsharp
/// Format violation for logging
val formatViolation: Violation -> string

/// Get violation summary
val violationSummary: ValidationResult -> string
```

**Example:**

```fsharp
let result = validateContainerSpec spec

printfn "%s" (Constraints.violationSummary result)
// Output: "Violations: 1 critical, 2 warnings, 1 info"

match result with
| Valid -> ()
| Invalid violations ->
    for v in violations do
        printfn "%s" (Constraints.formatViolation v)
        // Output: "[CRIT] SC_POD_005: Image 'docker.io/nginx' must use localhost/ registry (SC-POD-005) (docker.io/nginx)"
```

### 7.5 Emergency Response Integration

```fsharp
/// Emergency response handler
let emergencyHandler (client: PodmanClient) (containerId: string) (reason: string) = async {
    printfn "EMERGENCY: %s - Container: %s" reason containerId

    // Log the event
    let timestamp = DateTimeOffset.UtcNow.ToString("O")
    printfn "[%s] Initiating emergency stop..." timestamp

    // Stop within SLA (5 seconds per SC-EMR-057)
    let! stopResult = Constraints.emergencyStop client containerId 5

    match stopResult with
    | Ok () ->
        printfn "[%s] Container stopped successfully" (DateTimeOffset.UtcNow.ToString("O"))
    | Error e ->
        printfn "[%s] WARNING: Emergency stop failed: %s"
            (DateTimeOffset.UtcNow.ToString("O"))
            (PodmanError.toMessage e)

        // Force remove as last resort
        let! removeResult = Constraints.emergencyRemove client containerId
        match removeResult with
        | Ok () -> printfn "Container forcefully removed"
        | Error e2 -> printfn "CRITICAL: Failed to remove container: %s" (PodmanError.toMessage e2)
}
```

---

## Appendix A: Constraint Quick Reference

| Constraint | Severity | Validation Function | Safe Operation |
|------------|----------|---------------------|----------------|
| SC-CNT-009 | Critical | validateRootless | - |
| SC-CNT-010 | Critical | validateImageReference | safePullImage |
| SC-CNT-012 | Critical | validateRootless | - |
| SC-POD-001 | Warning | validateContainerSpec, validatePodSpec | safeCreateContainer, safeCreatePod |
| SC-POD-002 | Warning | validateContainerSpec | safeCreateContainer |
| SC-POD-003 | Warning | validateContainerSpec, validateContainerHealth | safeCreateContainer |
| SC-POD-004 | Info | validateContainerSpec | safeCreateContainer |
| SC-POD-005 | Critical/Warning | validateImageReference, validateContainerSpec | safePullImage, safeCreateContainer |
| SC-POD-006 | Info | validatePodSpec | safeCreatePod |
| SC-POD-007 | Warning | validateContainerSpec | safeCreateContainer |
| SC-POD-008 | Warning/Info | validateContainerSpec | safeCreateContainer |
| SC-EMR-057 | Critical | - | emergencyStop |
| SC-EMR-060 | Warning | - | emergencyRemove |

---

## Appendix B: Error Messages

| Constraint | Error Message Format |
|------------|---------------------|
| SC-CNT-010 | "Image '{image}' must use localhost/ registry (SC-CNT-010)" |
| SC-POD-001 | "Container name '{name}' should follow naming convention (SC-POD-001)" |
| SC-POD-002 | "Memory limit not specified (SC-POD-002)" |
| SC-POD-003 | "Health check not configured (SC-POD-003)" |
| SC-POD-004 | "Restart policy not specified (SC-POD-004)" |
| SC-POD-005 | "Image should use explicit version tag, not ':latest' (SC-POD-005)" |
| SC-POD-006 | "Network namespace not specified (SC-POD-006)" |
| SC-POD-007 | "Mount source '{path}' outside /home/ may be sensitive (SC-POD-007)" |
| SC-POD-008 | "Security context not configured (SC-POD-008)" |
| SC-POD-008 | "Root filesystem should be read-only (SC-POD-008)" |

---

*Generated from Cepaf.Podman.Safety source code. Last updated: 2025-12-23*
