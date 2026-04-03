# Fractal Logging System - Agent Operating Rules (AOR)

**Version**: 1.0.0 | **STAMP Compliant** | **Date**: 2025-12-25
**Framework**: SOPv5.11 + STAMP + TDG

## Overview

This document defines the Agent Operating Rules (AOR) for the Fractal Logging System.
All agents operating on or with the Fractal Logging System MUST adhere to these rules.

---

## AOR-LOG-001: Patient Mode for Log Operations

**Category**: Operational Constraint
**Severity**: CRITICAL
**STAMP Mapping**: SC-LOG-001

### Rule

All log emission operations MUST be non-blocking (async dispatch).
Agents MUST NOT perform synchronous log operations that could block request processing.

### Implementation

```fsharp
// CORRECT: Async dispatch (AOR-LOG-001 compliant)
let emitLog entry = async {
    do! FractalControl.emit entry
}

// INCORRECT: Blocking dispatch (AOR-LOG-001 violation)
let emitLogBlocking entry =
    FractalControl.emit entry |> Async.RunSynchronously  // VIOLATION!
```

### Validation

```bash
# Check for synchronous log calls
rg "RunSynchronously.*emit" lib/cepaf/
```

---

## AOR-LOG-002: Level Validation Before Emit

**Category**: Data Integrity
**Severity**: HIGH
**STAMP Mapping**: SC-LOG-006

### Rule

Agents MUST validate fractal level before log emission:
- L1/L2: MAY use wall-clock timestamps
- L3+: MUST include HLC timestamp (SC-LOG-006)

### Implementation

```fsharp
// CORRECT: Level-aware emission
let emitWithLevel level entry =
    if FractalLevel.toInt level >= 3 then
        // L3+ requires HLC
        let hlc = HLC.now ()
        { entry with HLC = hlc }
    else
        entry
```

### Validation

```fsharp
SafetyConstraints.validateHLCPresent entry
```

---

## AOR-LOG-003: Zenoh-Style Key Expression Compliance

**Category**: Naming Convention
**Severity**: MEDIUM
**STAMP Mapping**: SC-LOG-009

### Rule

All log keys MUST follow Zenoh-style key expression format:
- Use `/` as separator (dots auto-normalized)
- Support wildcards: `*` (single), `**` (any), `$*` (infix)
- Pre-register common aliases at startup

### Valid Patterns

```
Indrajaal/Alarms/create        # Exact
Indrajaal/*/create             # Single wildcard
Indrajaal/**                   # Multi-segment wildcard
Indrajaal/$*Handler            # Infix wildcard
**/error                       # Suffix match
```

### Invalid Patterns

```
/Indrajaal/Alarms/             # No leading/trailing slashes
***                            # Invalid triple wildcard
Indrajaal/<invalid>            # No angle brackets
```

---

## AOR-LOG-004: Retention Policy Enforcement

**Category**: Data Lifecycle
**Severity**: HIGH
**STAMP Mapping**: SC-LOG-010

### Rule

Agents MUST respect retention policies based on fractal level:

| Level | Min Retention | Max Retention | Archive |
|-------|--------------|---------------|---------|
| L1    | 5 min        | 1 hour        | No      |
| L2    | 1 hour       | 1 day         | No      |
| L3    | 7 days       | 30 days       | Yes     |
| L4    | 30 days      | 1 year        | Yes     |
| L5    | 1 year       | 10 years      | Yes     |

### Implementation

Content router automatically applies retention based on level.

---

## AOR-LOG-005: Backend Health Awareness

**Category**: Reliability
**Severity**: HIGH
**STAMP Mapping**: SC-LOG-001, SC-LOG-002

### Rule

Agents MUST:
1. Check backend health before routing
2. Fall back to Console if all backends unhealthy
3. Never drop P0/P1 priority logs

### Implementation

```fsharp
let route entry =
    let healthyBackends = filterHealthyBackends decision.Backends
    if healthyBackends.IsEmpty then
        [Backend.Console]  // Fallback
    else
        healthyBackends
```

---

## AOR-LOG-006: Admin Operations Require Authentication

**Category**: Security
**Severity**: CRITICAL
**STAMP Mapping**: SC-LOG-010

### Rule

All administrative operations on the Fractal Logging System MUST:
1. Authenticate via AdminSpace
2. Check authorization for the specific operation
3. Audit all operations (success and failure)

### Protected Operations

| Operation         | Minimum Level |
|-------------------|---------------|
| ViewMetrics       | ReadOnly      |
| ExportConfig      | ReadOnly      |
| CreateBoost       | Operator      |
| DeleteBoost       | Operator      |
| ModifyRouting     | Admin         |
| ImportConfig      | SuperAdmin    |

### Implementation

```fsharp
let executeAdminOp token operation =
    match AdminSpace.authenticate token with
    | Authenticated principal ->
        match AdminSpace.authorize principal operation with
        | Ok () -> executeOperation operation
        | Error reason -> failwith reason
    | _ -> failwith "Authentication failed"
```

---

## AOR-LOG-007: PII Masking at Entry Point

**Category**: Privacy/Compliance
**Severity**: CRITICAL
**STAMP Mapping**: SC-LOG-003

### Rule

Agents MUST mask PII data BEFORE log entry creation:
1. Apply PIIMasking.maskLogEntry to all entries
2. Never log raw PII in any level
3. Use correlation hashes for debugging

### Protected Data Categories

- **PII**: Email, Phone, SSN, IP Address
- **PCI**: Credit card numbers
- **PHI**: Health information
- **Credentials**: Passwords, tokens, API keys

### Implementation

```fsharp
let createEntry data =
    let rawEntry = buildEntry data
    PIIMasking.maskLogEntry defaultConfig rawEntry
```

---

## AOR-LOG-008: Boost TTL Enforcement

**Category**: Resource Management
**Severity**: HIGH
**STAMP Mapping**: SC-LOG-005

### Rule

All boosts MUST have a TTL:
- Default: 5 minutes
- Maximum: 1 hour
- Never create infinite boosts

### Implementation

```fsharp
let createBoost keyExpr depth =
    Boost.create keyExpr depth "agent"  // Auto 5min TTL

// For custom TTL
let createBoostCustom keyExpr depth ttlMs =
    if ttlMs > 3600000L then
        failwith "TTL exceeds maximum (1 hour)"
    Boost.createWithTtl keyExpr depth ttlMs "agent"
```

---

## AOR-LOG-009: Load Shedding Compliance

**Category**: Resilience
**Severity**: HIGH
**STAMP Mapping**: SC-LOG-002

### Rule

When load shedding is active:
1. Drop L1 (P3) logs immediately
2. Sample L2 (P2) at 1%
3. Sample L3 (P1) at 10%
4. Never drop L4/L5 (P0) logs

### Thresholds

- CPU > 90%: Activate shedding
- Memory > 85%: Activate shedding

---

## AOR-LOG-010: Batch Flush Timing

**Category**: Performance
**Severity**: MEDIUM
**STAMP Mapping**: SC-LOG-007

### Rule

Batch accumulator MUST flush within 10ms:
- Max batch size: 100 entries
- Max batch age: 10ms
- Flush immediately if either threshold met

---

## Compliance Matrix

| AOR Rule    | STAMP Constraint | Implementation | Tests |
|-------------|------------------|----------------|-------|
| AOR-LOG-001 | SC-LOG-001       | ✅ FractalControl.fs | ✅ |
| AOR-LOG-002 | SC-LOG-006       | ✅ Types.fs | ✅ |
| AOR-LOG-003 | SC-LOG-009       | ✅ KeyExpression.fs | ✅ |
| AOR-LOG-004 | SC-LOG-010       | ✅ ContentRouter.fs | ✅ |
| AOR-LOG-005 | SC-LOG-001/002   | ✅ ContentRouter.fs | ✅ |
| AOR-LOG-006 | SC-LOG-010       | ✅ AdminSpace.fs | Pending |
| AOR-LOG-007 | SC-LOG-003       | ✅ PIIMasking.fs | Pending |
| AOR-LOG-008 | SC-LOG-005       | ✅ Types.fs/Boost | ✅ |
| AOR-LOG-009 | SC-LOG-002       | ✅ FractalControl.fs | Pending |
| AOR-LOG-010 | SC-LOG-007       | ✅ BatchEncoder.fs | Pending |

---

## Enforcement

Agents violating these rules will:
1. Have operations rejected
2. Be logged in audit trail
3. Trigger STAMP constraint violations
4. Potentially trigger emergency protocols (SC-EMR)

---

## Version History

| Version | Date       | Author        | Changes |
|---------|------------|---------------|---------|
| 1.0.0   | 2025-12-25 | Claude Opus 4.5 | Initial release |

