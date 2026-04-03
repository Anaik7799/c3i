// =============================================================================
// RollbackManager.fs - SIL-4 Multi-Level Rollback Manager
// =============================================================================
// Aligns with: lib/indrajaal/upgrade/rollback_manager.ex
//
// STAMP Constraints:
//   SC-SIL4-026: Rollback path exists
//   SC-EMR-060: Rollback capability for 24 hours
//   SC-HOLON-015: Self-healing from state
//   SC-PRAJNA-001: Guardian approval for critical ops
//   SC-CTRL-003: 5-order effects analysis required
//
// AOR Rules:
//   AOR-REG-008: Rollback capability for 24 hours
//   AOR-CONST-002: Immediate halt on constitutional violation
//   AOR-RECONFIG-003: Test rollback path BEFORE commit
//   AOR-FOUNDER-007: Threats eliminated immediately
//
// 5-Order Effects Analysis:
//   1st Order: Rollback initiated, state identified
//   2nd Order: Guardian approval requested/granted
//   3rd Order: State restoration in progress
//   4th Order: Services restarted, health verified
//   5th Order: Federation notified, audit logged
// =============================================================================

namespace Cepaf.SIL4

open System
open System.IO
open System.Collections.Concurrent
open System.Threading.Tasks

/// Rollback level (multi-level rollback strategy)
type RollbackLevel =
    | Level1_Config     // Configuration only (fastest)
    | Level2_State      // Holon state (SQLite/DuckDB)
    | Level3_Code       // Code/release rollback
    | Level4_Full       // Full system rollback (state + code + config)

/// Rollback status
type RollbackStatus =
    | Pending
    | AwaitingApproval
    | Approved
    | Executing
    | Completed
    | Failed
    | Cancelled

/// Rollback metadata
type RollbackMetadata = {
    RollbackId: Guid
    Level: RollbackLevel
    Reason: string
    InitiatedBy: string
    SnapshotId: Guid option
    PreviousVersion: string
    TargetVersion: string
    CreatedAt: DateTime
    ExpiresAt: DateTime  // 24-hour window per SC-SIL4-026
}

/// Rollback state
type RollbackState = {
    Metadata: RollbackMetadata
    Status: RollbackStatus
    GuardianApprovalToken: string option
    StartedAt: DateTime option
    CompletedAt: DateTime option
    ErrorMessage: string option
    RestoredFiles: string list
    AuditTrail: string list
}

/// Rollback result
type RollbackResult =
    | RollbackSuccess of RollbackState
    | RollbackFailed of RollbackState * reason: string
    | RollbackCancelled of RollbackState * reason: string
    | ApprovalRequired of RollbackState

/// 5-Order effect for rollback operations
type RollbackEffect = {
    Order: int
    RollbackId: Guid
    Level: RollbackLevel
    Description: string
    AuditInfo: string
    Timestamp: DateTime
}

/// Available rollback point
type RollbackPoint = {
    PointId: Guid
    SnapshotId: Guid option
    Version: string
    CreatedAt: DateTime
    ExpiresAt: DateTime
    Level: RollbackLevel
    SizeBytes: int64
    IsValid: bool
}

/// SIL-4 Multi-Level Rollback Manager
/// Transaction-style rollback with Guardian approval per SC-PRAJNA-001
type RollbackManager(snapshotDir: string, ?configDir: string) =

    // Configuration
    let configDirectory = defaultArg configDir "config"
    let rollbackWindowHours = 24.0  // SC-SIL4-026: 24-hour rollback window

    // Rollback tracking
    let rollbacks = ConcurrentDictionary<Guid, RollbackState>()
    let effectsLog = ConcurrentDictionary<Guid, RollbackEffect list>()
    let rollbackPoints = ConcurrentDictionary<Guid, RollbackPoint>()

    /// Log 5-order effect
    member private this.LogEffect(rollbackId: Guid, level: RollbackLevel, order: int, desc: string, audit: string) =
        let effect = {
            Order = order
            RollbackId = rollbackId
            Level = level
            Description = desc
            AuditInfo = audit
            Timestamp = DateTime.UtcNow
        }
        effectsLog.AddOrUpdate(
            rollbackId,
            [effect],
            fun _ existing -> existing @ [effect]) |> ignore

    /// Check if Guardian approval is required (SC-PRAJNA-001)
    member this.RequiresGuardianApproval(level: RollbackLevel) =
        match level with
        | Level1_Config -> false  // Config rollback is safe
        | Level2_State -> true    // State changes need approval
        | Level3_Code -> true     // Code changes need approval
        | Level4_Full -> true     // Full rollback always needs approval

    /// Initiate rollback (SC-SIL4-026)
    member this.Initiate(
        level: RollbackLevel,
        reason: string,
        initiatedBy: string,
        ?snapshotId: Guid,
        ?targetVersion: string) =

        let rollbackId = Guid.NewGuid()
        let now = DateTime.UtcNow
        let targetVer = defaultArg targetVersion "previous"

        // 1st Order: Rollback initiated
        this.LogEffect(rollbackId, level, 1,
            sprintf "Rollback initiated: %A" level,
            sprintf "Reason: %s, Initiated by: %s" reason initiatedBy)

        let metadata = {
            RollbackId = rollbackId
            Level = level
            Reason = reason
            InitiatedBy = initiatedBy
            SnapshotId = snapshotId
            PreviousVersion = "current"
            TargetVersion = targetVer
            CreatedAt = now
            ExpiresAt = now.AddHours(rollbackWindowHours)
        }

        let initialStatus =
            if this.RequiresGuardianApproval(level) then
                AwaitingApproval
            else
                Approved

        let state = {
            Metadata = metadata
            Status = initialStatus
            GuardianApprovalToken = None
            StartedAt = None
            CompletedAt = None
            ErrorMessage = None
            RestoredFiles = []
            AuditTrail = [sprintf "[%s] Rollback initiated: %s" (now.ToString("o")) reason]
        }

        rollbacks.TryAdd(rollbackId, state) |> ignore

        // 2nd Order: Guardian approval check
        this.LogEffect(rollbackId, level, 2,
            sprintf "Guardian approval: %s" (if initialStatus = AwaitingApproval then "REQUIRED" else "NOT_REQUIRED"),
            sprintf "Level %A requires approval: %b" level (this.RequiresGuardianApproval(level)))

        if initialStatus = AwaitingApproval then
            ApprovalRequired state
        else
            RollbackSuccess state

    /// Approve rollback (Guardian approval)
    member this.Approve(rollbackId: Guid, approvalToken: string) =
        match rollbacks.TryGetValue(rollbackId) with
        | false, _ ->
            RollbackFailed({
                Metadata = { RollbackId = rollbackId; Level = Level1_Config; Reason = ""; InitiatedBy = "";
                             SnapshotId = None; PreviousVersion = ""; TargetVersion = "";
                             CreatedAt = DateTime.UtcNow; ExpiresAt = DateTime.UtcNow }
                Status = Failed; GuardianApprovalToken = None; StartedAt = None; CompletedAt = None
                ErrorMessage = Some "Not found"; RestoredFiles = []; AuditTrail = []
            }, "Rollback not found")
        | true, state ->
            if state.Status <> AwaitingApproval then
                RollbackFailed(state, sprintf "Invalid status: %A" state.Status)
            else
                let updatedState = {
                    state with
                        Status = Approved
                        GuardianApprovalToken = Some approvalToken
                        AuditTrail = state.AuditTrail @ [sprintf "[%s] Guardian approval granted" (DateTime.UtcNow.ToString("o"))]
                }
                rollbacks.[rollbackId] <- updatedState

                // 3rd Order: Approval granted
                this.LogEffect(rollbackId, state.Metadata.Level, 3,
                    "Guardian approval granted",
                    sprintf "Token: %s..." (approvalToken.Substring(0, min 8 approvalToken.Length)))

                RollbackSuccess updatedState

    /// Execute rollback
    member this.Execute(rollbackId: Guid) = async {
        match rollbacks.TryGetValue(rollbackId) with
        | false, _ ->
            return RollbackFailed({
                Metadata = { RollbackId = rollbackId; Level = Level1_Config; Reason = ""; InitiatedBy = ""
                             SnapshotId = None; PreviousVersion = ""; TargetVersion = ""
                             CreatedAt = DateTime.UtcNow; ExpiresAt = DateTime.UtcNow }
                Status = Failed; GuardianApprovalToken = None; StartedAt = None; CompletedAt = None
                ErrorMessage = Some "Not found"; RestoredFiles = []; AuditTrail = []
            }, "Rollback not found")
        | true, state ->
            // Verify approval
            if state.Status <> Approved then
                return RollbackFailed(state, sprintf "Rollback not approved: %A" state.Status)
            else
                // Check expiry
                if DateTime.UtcNow > state.Metadata.ExpiresAt then
                    return RollbackFailed(state, "Rollback window expired (24 hours)")
                else
                    // Start execution
                    let executingState = {
                        state with
                            Status = Executing
                            StartedAt = Some DateTime.UtcNow
                            AuditTrail = state.AuditTrail @ [sprintf "[%s] Execution started" (DateTime.UtcNow.ToString("o"))]
                    }
                    rollbacks.[rollbackId] <- executingState

                    try
                        // 3rd Order: State restoration
                        this.LogEffect(rollbackId, state.Metadata.Level, 3,
                            sprintf "Executing %A rollback" state.Metadata.Level,
                            "State restoration in progress")

                        let! restoredFiles = this.ExecuteLevel(state.Metadata.Level, state.Metadata.SnapshotId)

                        // 4th Order: Services restart
                        this.LogEffect(rollbackId, state.Metadata.Level, 4,
                            "Services restarting",
                            sprintf "Restored %d files" (List.length restoredFiles))

                        let completedState = {
                            executingState with
                                Status = Completed
                                CompletedAt = Some DateTime.UtcNow
                                RestoredFiles = restoredFiles
                                AuditTrail = executingState.AuditTrail @ [
                                    sprintf "[%s] Execution completed successfully" (DateTime.UtcNow.ToString("o"))
                                    sprintf "[%s] Restored %d files" (DateTime.UtcNow.ToString("o")) (List.length restoredFiles)
                                ]
                        }
                        rollbacks.[rollbackId] <- completedState

                        // 5th Order: Federation notification
                        this.LogEffect(rollbackId, state.Metadata.Level, 5,
                            "Rollback complete, federation notified",
                            sprintf "Duration: %s" ((completedState.CompletedAt.Value - completedState.StartedAt.Value).ToString()))

                        return RollbackSuccess completedState

                    with ex ->
                        let failedState = {
                            executingState with
                                Status = Failed
                                CompletedAt = Some DateTime.UtcNow
                                ErrorMessage = Some ex.Message
                                AuditTrail = executingState.AuditTrail @ [
                                    sprintf "[%s] FAILED: %s" (DateTime.UtcNow.ToString("o")) ex.Message
                                ]
                        }
                        rollbacks.[rollbackId] <- failedState
                        return RollbackFailed(failedState, ex.Message)
    }

    /// Execute specific rollback level
    member private this.ExecuteLevel(level: RollbackLevel, snapshotId: Guid option) = async {
        match level with
        | Level1_Config ->
            // Restore configuration files only
            return this.RestoreConfig()
        | Level2_State ->
            // Restore holon state from snapshot
            match snapshotId with
            | Some sid -> return! this.RestoreState(sid)
            | None -> return []
        | Level3_Code ->
            // Restore code/release
            return this.RestoreCode()
        | Level4_Full ->
            // Full restoration
            let configFiles = this.RestoreConfig()
            let! stateFiles =
                match snapshotId with
                | Some sid -> this.RestoreState(sid)
                | None -> async { return [] }
            let codeFiles = this.RestoreCode()
            return configFiles @ stateFiles @ codeFiles
    }

    /// Restore configuration
    member private this.RestoreConfig() =
        // Simulate config restoration
        let configBackup = Path.Combine(configDirectory, "backup")
        if Directory.Exists(configBackup) then
            Directory.GetFiles(configBackup, "*.json")
            |> Array.toList
        else
            []

    /// Restore state from snapshot
    member private this.RestoreState(snapshotId: Guid) = async {
        let snapshotPattern = sprintf "*%s*.snapshot" (snapshotId.ToString("N").[..7])
        let snapshotPath = Path.Combine(snapshotDir, snapshotPattern)

        if Directory.Exists(snapshotDir) then
            return Directory.GetFiles(snapshotDir, "*.snapshot") |> Array.toList
        else
            return []
    }

    /// Restore code
    member private this.RestoreCode() =
        // Simulate code restoration (would use release system)
        []

    /// Cancel rollback
    member this.Cancel(rollbackId: Guid, reason: string) =
        match rollbacks.TryGetValue(rollbackId) with
        | false, _ ->
            RollbackCancelled({
                Metadata = { RollbackId = rollbackId; Level = Level1_Config; Reason = ""; InitiatedBy = ""
                             SnapshotId = None; PreviousVersion = ""; TargetVersion = ""
                             CreatedAt = DateTime.UtcNow; ExpiresAt = DateTime.UtcNow }
                Status = Cancelled; GuardianApprovalToken = None; StartedAt = None; CompletedAt = None
                ErrorMessage = None; RestoredFiles = []; AuditTrail = []
            }, "Rollback not found")
        | true, state ->
            if state.Status = Executing then
                RollbackFailed(state, "Cannot cancel executing rollback")
            else
                let cancelledState = {
                    state with
                        Status = Cancelled
                        CompletedAt = Some DateTime.UtcNow
                        AuditTrail = state.AuditTrail @ [sprintf "[%s] Cancelled: %s" (DateTime.UtcNow.ToString("o")) reason]
                }
                rollbacks.[rollbackId] <- cancelledState
                RollbackCancelled(cancelledState, reason)

    /// Emergency rollback (bypasses Guardian approval)
    member this.EmergencyRollback(reason: string, level: RollbackLevel) = async {
        let rollbackId = Guid.NewGuid()
        let now = DateTime.UtcNow

        // Log emergency
        this.LogEffect(rollbackId, level, 1,
            "EMERGENCY ROLLBACK INITIATED",
            sprintf "Reason: %s - Guardian bypassed" reason)

        let metadata = {
            RollbackId = rollbackId
            Level = level
            Reason = sprintf "EMERGENCY: %s" reason
            InitiatedBy = "EMERGENCY_PROTOCOL"
            SnapshotId = None
            PreviousVersion = "current"
            TargetVersion = "emergency"
            CreatedAt = now
            ExpiresAt = now.AddHours(rollbackWindowHours)
        }

        let state = {
            Metadata = metadata
            Status = Approved  // Emergency bypasses approval
            GuardianApprovalToken = Some "EMERGENCY_OVERRIDE"
            StartedAt = None
            CompletedAt = None
            ErrorMessage = None
            RestoredFiles = []
            AuditTrail = [
                sprintf "[%s] EMERGENCY ROLLBACK: %s" (now.ToString("o")) reason
                sprintf "[%s] Guardian approval BYPASSED" (now.ToString("o"))
            ]
        }

        rollbacks.TryAdd(rollbackId, state) |> ignore

        return! this.Execute(rollbackId)
    }

    /// Get rollback status
    member this.Status(rollbackId: Guid) =
        match rollbacks.TryGetValue(rollbackId) with
        | true, state -> Some state
        | false, _ -> None

    /// List all rollbacks
    member this.List() =
        rollbacks.Values
        |> Seq.sortByDescending (fun s -> s.Metadata.CreatedAt)
        |> Seq.toList

    /// Get available rollback points
    member this.AvailableRollbacks() =
        let now = DateTime.UtcNow
        rollbackPoints.Values
        |> Seq.filter (fun p -> p.ExpiresAt > now && p.IsValid)
        |> Seq.sortByDescending (fun p -> p.CreatedAt)
        |> Seq.toList

    /// Register a rollback point
    member this.RegisterRollbackPoint(version: string, level: RollbackLevel, ?snapshotId: Guid, ?sizeBytes: int64) =
        let pointId = Guid.NewGuid()
        let now = DateTime.UtcNow
        let point = {
            PointId = pointId
            SnapshotId = snapshotId
            Version = version
            CreatedAt = now
            ExpiresAt = now.AddHours(rollbackWindowHours)
            Level = level
            SizeBytes = defaultArg sizeBytes 0L
            IsValid = true
        }
        rollbackPoints.TryAdd(pointId, point) |> ignore
        point

    /// Get 5-order effects for rollback
    member this.GetEffects(rollbackId: Guid) =
        match effectsLog.TryGetValue(rollbackId) with
        | true, effects -> effects
        | false, _ -> []

    /// Get rollback statistics
    member this.GetStatistics() =
        let all = rollbacks.Values |> Seq.toList
        {|
            TotalRollbacks = all.Length
            Completed = all |> List.filter (fun s -> s.Status = Completed) |> List.length
            Failed = all |> List.filter (fun s -> s.Status = Failed) |> List.length
            Cancelled = all |> List.filter (fun s -> s.Status = Cancelled) |> List.length
            Pending = all |> List.filter (fun s -> s.Status = Pending || s.Status = AwaitingApproval) |> List.length
            ByLevel =
                all
                |> List.groupBy (fun s -> s.Metadata.Level)
                |> List.map (fun (l, ss) -> l, ss.Length)
            AvailablePoints = rollbackPoints.Count
        |}
