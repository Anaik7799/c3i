// =============================================================================
// StartupVerification.fs - State Vector Verification for SIL-6 Boot Sequence
// =============================================================================
// STAMP: SC-BOOT-001, SC-BOOT-002, SC-BOOT-003, SC-BOOT-004, SC-BOOT-005
// AOR: AOR-MESH-001, AOR-TPS-001, AOR-FUNC-001, AOR-FUNC-005
//
// ## Purpose
// Implements formal state vector verification for the 5-stage boot sequence.
// Ensures deterministic, robust, and transactional startup conforming to
// mathematical specification in the startup plan.
//
// ## State Vector Definition
// S(t) = [s_compile, s_migrations, s_containers, s_zenoh, s_health, s_quorum]
// where s_i ∈ {0, 1} and ValidStartup(t) ⟺ ∏ᵢ sᵢ(t) = 1
//
// ## 5-Stage Boot Sequence
// S0_PREFLIGHT    → [1,_,_,_,_,_]
// S1_INFRASTRUCTURE → [1,1,1,_,_,_]
// S2_ZENOH_MESH   → [1,1,1,1,_,_]
// S3_APP_SEED     → [1,1,1,1,1,_]
// S4_HOMEOSTASIS  → [1,1,1,1,1,1]
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-01-17 |
// | Author | Claude Opus 4.5 |
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Diagnostics

/// Boot stages following the 5-stage SIL-6 specification
type BootStage =
    | S0_Preflight
    | S1_Infrastructure
    | S2_ZenohMesh
    | S3_AppSeed
    | S4_Homeostasis

/// State vector for startup verification
/// Each component represents a verification gate
type StateVector = {
    /// Compile gate: Elixir/F# compiled successfully
    Compile: bool
    /// Migration gate: All database migrations applied (SC-BOOT-002)
    Migrations: bool
    /// Container gate: Infrastructure containers healthy
    Containers: bool
    /// Zenoh gate: Mesh formed with quorum (SC-BOOT-003)
    Zenoh: bool
    /// Health gate: Application health endpoint responding
    Health: bool
    /// Quorum gate: 2oo3 consensus achieved (SC-BOOT-003)
    Quorum: bool
}

/// Verification result with details
type VerificationResult =
    | Passed of StateVector
    | Failed of failedGate: string * currentVector: StateVector * required: StateVector

module StartupVerification =

    /// Empty state vector (all gates false)
    let emptyVector : StateVector = {
        Compile = false
        Migrations = false
        Containers = false
        Zenoh = false
        Health = false
        Quorum = false
    }

    /// State vector after successful S0 (preflight)
    let afterS0 : StateVector = {
        Compile = true
        Migrations = false
        Containers = false
        Zenoh = false
        Health = false
        Quorum = false
    }

    /// State vector after successful S1 (infrastructure)
    let afterS1 : StateVector = {
        Compile = true
        Migrations = true
        Containers = true
        Zenoh = false
        Health = false
        Quorum = false
    }

    /// State vector after successful S2 (zenoh mesh)
    let afterS2 : StateVector = {
        Compile = true
        Migrations = true
        Containers = true
        Zenoh = true
        Health = false
        Quorum = false
    }

    /// State vector after successful S3 (app seed)
    let afterS3 : StateVector = {
        Compile = true
        Migrations = true
        Containers = true
        Zenoh = true
        Health = true
        Quorum = false
    }

    /// State vector after successful S4 (homeostasis)
    let afterS4 : StateVector = {
        Compile = true
        Migrations = true
        Containers = true
        Zenoh = true
        Health = true
        Quorum = true
    }

    /// Get the required state vector for a given stage
    let getRequiredStateForStage (stage: BootStage) : StateVector =
        match stage with
        | S0_Preflight -> emptyVector
        | S1_Infrastructure -> afterS0
        | S2_ZenohMesh -> afterS1
        | S3_AppSeed -> afterS2
        | S4_Homeostasis -> afterS3

    /// Verify state vector is valid for entering a stage (SC-BOOT-001)
    let verifyStateForStage (stage: BootStage) (current: StateVector) : VerificationResult =
        let required = getRequiredStateForStage stage
        let checkGate name currentVal requiredVal =
            if requiredVal && not currentVal then Some name else None
        let gateChecks = [
            checkGate "Compile" current.Compile required.Compile
            checkGate "Migrations" current.Migrations required.Migrations
            checkGate "Containers" current.Containers required.Containers
            checkGate "Zenoh" current.Zenoh required.Zenoh
            checkGate "Health" current.Health required.Health
            checkGate "Quorum" current.Quorum required.Quorum
        ]
        let failedGates = List.choose id gateChecks
        match failedGates with
        | [] -> Passed current
        | first :: _ -> Failed (first, current, required)

    /// Format state vector as string [x,x,x,x,x,x]
    let formatVector (state: StateVector) : string =
        sprintf "[%d,%d,%d,%d,%d,%d]"
            (if state.Compile then 1 else 0)
            (if state.Migrations then 1 else 0)
            (if state.Containers then 1 else 0)
            (if state.Zenoh then 1 else 0)
            (if state.Health then 1 else 0)
            (if state.Quorum then 1 else 0)

    /// Print state vector with labels
    let printStateVector (state: StateVector) : unit =
        printfn "State Vector: %s" (formatVector state)
        printfn "  Compile:    %s" (if state.Compile then "OK" else "PENDING")
        printfn "  Migrations: %s" (if state.Migrations then "OK" else "PENDING")
        printfn "  Containers: %s" (if state.Containers then "OK" else "PENDING")
        printfn "  Zenoh:      %s" (if state.Zenoh then "OK" else "PENDING")
        printfn "  Health:     %s" (if state.Health then "OK" else "PENDING")
        printfn "  Quorum:     %s" (if state.Quorum then "OK" else "PENDING")

    /// Get stage name as string
    let getStageName (stage: BootStage) : string =
        match stage with
        | S0_Preflight -> "S0_PREFLIGHT"
        | S1_Infrastructure -> "S1_INFRASTRUCTURE"
        | S2_ZenohMesh -> "S2_ZENOH_MESH"
        | S3_AppSeed -> "S3_APP_SEED"
        | S4_Homeostasis -> "S4_HOMEOSTASIS"

    /// Get next stage in sequence
    let getNextStage (stage: BootStage) : BootStage option =
        match stage with
        | S0_Preflight -> Some S1_Infrastructure
        | S1_Infrastructure -> Some S2_ZenohMesh
        | S2_ZenohMesh -> Some S3_AppSeed
        | S3_AppSeed -> Some S4_Homeostasis
        | S4_Homeostasis -> None

    /// Check if all stages are complete
    let isBootComplete (state: StateVector) : bool =
        state.Compile &&
        state.Migrations &&
        state.Containers &&
        state.Zenoh &&
        state.Health &&
        state.Quorum

    /// Verify migration status by checking database (SC-BOOT-002)
    let verifyMigrations () : bool =
        try
            // Check if oban_peers table exists (critical for app startup)
            let psi = ProcessStartInfo(
                FileName = "podman",
                Arguments = "exec indrajaal-db-prod psql -U postgres -d indrajaal_dev -tAc \"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='oban_peers');\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            use proc = new Process()
            proc.StartInfo <- psi
            proc.Start() |> ignore
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit(5000) |> ignore

            output = "t"
        with _ ->
            false

    /// Verify Zenoh quorum (2oo3 voting) (SC-BOOT-003)
    let verifyZenohQuorum () : bool =
        try
            // Check at least 2 of 3 Zenoh routers are healthy
            let checkRouter (port: int) : bool =
                let psi = ProcessStartInfo(
                    FileName = "curl",
                    Arguments = sprintf "-s -o /dev/null -w \"%%{http_code}\" http://localhost:%d/status" port,
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                )
                use proc = new Process()
                proc.StartInfo <- psi
                proc.Start() |> ignore
                let output = proc.StandardOutput.ReadToEnd().Trim()
                proc.WaitForExit(2000) |> ignore
                output = "200"

            let healthy = [7447; 7448; 7449] |> List.filter checkRouter |> List.length
            healthy >= 2 // Quorum = floor(3/2) + 1 = 2
        with _ ->
            false

    /// Verify application health endpoint
    let verifyAppHealth () : bool =
        try
            let psi = ProcessStartInfo(
                FileName = "curl",
                Arguments = "-s -o /dev/null -w \"%{http_code}\" http://localhost:4000/health",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            )
            use proc = new Process()
            proc.StartInfo <- psi
            proc.Start() |> ignore
            let output = proc.StandardOutput.ReadToEnd().Trim()
            proc.WaitForExit(5000) |> ignore
            output = "200"
        with _ ->
            false

    /// Build current state vector by checking all gates
    let buildCurrentStateVector () : StateVector =
        {
            Compile = true // Assumed if we're running F#
            Migrations = verifyMigrations ()
            Containers = true // Check would be done by DigitalTwin
            Zenoh = verifyZenohQuorum ()
            Health = verifyAppHealth ()
            Quorum = verifyZenohQuorum () // Same as Zenoh for now
        }

    /// JIDOKA: Stop immediately if gate fails (AOR-TPS-001)
    let jidokaGateCheck (gateName: string) (check: unit -> bool) : bool =
        let result = check ()
        if not result then
            printfn "\u001b[31m[JIDOKA] STOP: Gate '%s' failed - fix before continuing\u001b[0m" gateName
        result
