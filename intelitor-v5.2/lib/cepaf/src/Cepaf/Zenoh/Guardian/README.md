# Constitutional Checker Module (FM-002)

## Overview

This module implements validation of Ψ₀-Ψ₅ constitutional invariants and Ω₀ Founder's Directive for the Indrajaal biomorphic organism.

**Location**: `/lib/cepaf/src/Cepaf/Zenoh/Guardian/ConstitutionalChecker.fs`

**Target Framework**: net10.0

## STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-013 | Constitutional checks MUST pass before holon operations | CRITICAL |
| SC-CONST-001 | Verify constitution BEFORE any reconfiguration | CRITICAL |
| SC-CONST-002 | Immediate halt on constitutional violation | CRITICAL |
| SC-CONST-003 | Guardian has absolute veto | CRITICAL |
| SC-CONST-004 | Ψ₀-Ψ₅ are hardcoded, cannot be modified | CRITICAL |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-CONST-001 | Constitutional check before reconfiguration |
| AOR-CONST-002 | Immediate halt on violation |
| AOR-CONST-003 | Guardian supremacy - absolute veto |
| AOR-CONST-004 | Axiom protection - Ψ₀-Ψ₅ hardcoded |
| AOR-FOUNDER-001 | Founder's benefit evaluated FIRST |

## Components

### 1. ConstitutionalInvariant (Ψ₀-Ψ₅)

```fsharp
type ConstitutionalInvariant =
    | Psi0_Existence      // System must survive ALL operations
    | Psi1_Regeneration   // State recoverable from SQLite/DuckDB
    | Psi2_History        // Complete history preserved
    | Psi3_Verification   // Cryptographically verifiable
    | Psi4_HumanAlignment // Serves Founder's lineage
    | Psi5_Truthfulness   // No deception
```

### 2. Operation Types

```fsharp
type Operation =
    | HolonJoin of HolonIdentity
    | Reconfigure of layer: int * proposal: string
    | StateMutation of changeId: string * data: obj
    | CodeEvolution of moduleId: string * diff: string
    | GenomeModification of aspect: string * change: string
    | ResourceAllocation of amount: decimal * beneficiary: string
    | TerminateLineage
```

### 3. SystemState

```fsharp
type SystemState = {
    IsCompiled: bool
    IsRunning: bool
    ContainersHealthy: bool
    SqliteIntact: bool
    DuckDbIntact: bool
    RegisterChainValid: bool
    LineageTracked: bool
    Uptime: TimeSpan
    LastVerified: DateTime
    LayerHealth: Map<int, float>
}
```

### 4. IGuardianValidator Interface

```fsharp
type IGuardianValidator =
    abstract ValidateHolonJoin: HolonIdentity -> Task<Result<unit, string>>
    abstract ValidateConstitutional: Operation -> Task<Result<unit, string>>
    abstract ValidateFounderDirective: Operation -> Task<Result<unit, string>>
```

### 5. ConstitutionalChecker

Main validation engine that checks all Ψ₀-Ψ₅ invariants:

- `CheckPsi0_Existence` - System survival
- `CheckPsi1_Regeneration` - State recoverability
- `CheckPsi2_History` - History preservation
- `CheckPsi3_Verification` - Cryptographic verification
- `CheckPsi4_HumanAlignment` - Founder's lineage alignment
- `CheckPsi5_Truthfulness` - No deception
- `ValidateAll` - Checks all invariants

### 6. FounderDirectiveValidator

Validates operations against Ω₀ sub-directives:

- `CheckResourceAcquisition` (Ω₀.1) - Founder enrichment
- `CheckGeneticPerpetuity` (Ω₀.2) - Lineage preservation
- `CheckSymbioticBinding` (Ω₀.3) - Co-evolution as ONE
- `CheckCoEvolution` (Ω₀.4) - Evolution together
- `CheckMutualTermination` (Ω₀.5) - Mutual fate
- `CheckSentiencePursuit` (Ω₀.6) - Intelligence growth
- `CheckPowerAccumulation` (Ω₀.7) - Power increase
- `ValidateAll` - Checks all directives

## Usage Examples

### Example 1: Create Guardian Validator

```fsharp
open Cepaf.Zenoh.Guardian.ConstitutionalChecker

// Create with healthy state
let guardian = createHealthyGuardianValidator()

// Or with custom state provider
let getSystemState() =
    {
        IsCompiled = true
        IsRunning = true
        ContainersHealthy = true
        SqliteIntact = true
        DuckDbIntact = true
        RegisterChainValid = true
        LineageTracked = true
        Uptime = TimeSpan.FromHours(24.0)
        LastVerified = DateTime.UtcNow
        LayerHealth = Map.ofList [(0, 1.0); (1, 1.0); (2, 1.0); (3, 1.0)]
    }

let customGuardian = createGuardianValidator getSystemState
```

### Example 2: Validate Holon Join

```fsharp
task {
    let holonIdentity = {
        HolonId = Guid.NewGuid()
        Name = "new-holon-1"
        PublicKey = Array.zeroCreate 32
        Capabilities = Set.ofList ["read"; "write"]
        CreatedAt = DateTime.UtcNow
    }

    let! result = guardian.ValidateHolonJoin(holonIdentity)
    match result with
    | Ok () -> printfn "Holon join approved"
    | Error reason -> printfn "Holon join rejected: %s" reason
}
```

### Example 3: Validate Constitutional Operation

```fsharp
task {
    let operation = Operation.StateMutation("CHG-001", box "new_data")

    let! result = guardian.ValidateConstitutional(operation)
    match result with
    | Ok () -> printfn "Operation constitutionally sound"
    | Error reason -> printfn "Constitutional violation: %s" reason
}
```

### Example 4: Validate Founder's Directive

```fsharp
task {
    let operation = Operation.ResourceAllocation(1000m, "Founder")

    let! result = guardian.ValidateFounderDirective(operation)
    match result with
    | Ok () -> printfn "Operation serves Founder's interests"
    | Error reason -> printfn "Founder directive violation: %s" reason
}
```

### Example 5: Full Validation Pipeline

```fsharp
let validateOperation (guardian: IGuardianValidator) (operation: Operation) =
    task {
        // Step 1: Constitutional check (SC-CONST-001)
        let! constResult = guardian.ValidateConstitutional(operation)
        match constResult with
        | Error reason ->
            // AOR-CONST-002: Immediate halt
            return Error $"Constitutional halt: {reason}"
        | Ok () ->
            // Step 2: Founder's Directive check (AOR-FOUNDER-001)
            let! founderResult = guardian.ValidateFounderDirective(operation)
            match founderResult with
            | Error reason ->
                return Error $"Founder directive violation: {reason}"
            | Ok () ->
                return Ok ()
    }
```

## Integration with Elixir Backend

The Guardian validator can be integrated with the Elixir backend via:

1. **HTTP API**: Call Guardian validation endpoints
2. **Zenoh Messages**: Publish validation requests to `indrajaal/guardian/validate`
3. **Direct Integration**: Use via CEPAF-Elixir bridge

## Testing

```fsharp
// Test constitutional violation detection
let testPsi0Violation() =
    let state() = createMockSystemState false
    let checker = ConstitutionalChecker(state)
    let operation = Operation.Reconfigure(0, "change_constitution")

    match checker.CheckPsi0_Existence(operation) with
    | Error violation ->
        assert (violation.Invariant = ConstitutionalInvariant.Psi0_Existence)
        assert (violation.Severity = Critical)
    | Ok () -> failwith "Expected violation"

// Test Founder's Directive validation
let testFounderDirective() =
    let validator = FounderDirectiveValidator()
    let operation = Operation.ResourceAllocation(1000m, "NotFounder")

    match validator.CheckResourceAcquisition(operation) with
    | Error msg -> assert msg.Contains("Founder first")
    | Ok () -> failwith "Expected violation"
```

## Related Documents

- **CLAUDE.md** - §1.0 Fundamental Axioms (Ψ₀-Ψ₅, Ω₀-Ω₉)
- **HOLON_FOUNDERS_DIRECTIVE.md** - Ω₀ Supreme Directive details
- **HOLON_CONSTITUTIONAL_RECONFIGURATION.md** - Reconfiguration protocol

## Change History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0.0 | 2026-01-15 | Claude Opus 4.5 | Initial implementation (FM-002) |
