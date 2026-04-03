/// CEPAF Agent Operating Rules (AOR) Enforcement Engine
/// Implements AOR rule evaluation, violation detection, and compliance checking.
///
/// WHAT: Validates Agent Operating Rules for CEPAF operations
/// WHY: Ensures all agents comply with safety-critical system requirements
/// CONSTRAINTS: Violations trigger immediate halt per AOR-SAF-001 (<1s)
///
/// STAMP Compliance: AOR-SAF-001, AOR-CNT-001, AOR-QUA-001, AOR-GEM-001
/// Version: 1.0.0
module Cepaf.Modules.AOREngine

open System
open System.Diagnostics
open Cepaf.Observability
open Cepaf.Core.Units  // SC-FSH-004: Units of Measure for type safety
open Cepaf.Core.Composition  // SC-FSH-010: Function composition

// ============================================================================
// TYPE-SAFE SAFETY THRESHOLDS (SC-FSH-004)
// ============================================================================

/// AOR-SAF-001: Emergency halt must complete within 1 second
let private haltThreshold = Timeout.fromSec 1.0<sec>

/// AOR-SAF-001: Halt threshold in milliseconds (for comparison)
let private haltThresholdMs = Timeout.toRawMs haltThreshold

// ============================================================================
// TYPES - Rule Severity Levels
// ============================================================================

/// Severity levels for AOR violations (aligned with STAMP requirements)
[<RequireQualifiedAccess>]
type RuleSeverity =
    /// Immediate halt required (<1s per AOR-SAF-001)
    | Critical
    /// Must fix before continuing
    | High
    /// Should fix, may continue with warning
    | Medium
    /// Advisory only, logged for review
    | Low

/// Convert severity to numeric priority (lower = more severe)
let severityToPriority = function
    | RuleSeverity.Critical -> 1
    | RuleSeverity.High -> 2
    | RuleSeverity.Medium -> 3
    | RuleSeverity.Low -> 4

// ============================================================================
// TYPES - Rule Categories
// ============================================================================

/// Categories of Agent Operating Rules
[<RequireQualifiedAccess>]
type RuleCategory =
    /// Executive authority rules (AOR-EXE-*)
    | Executive
    /// Safety rules (AOR-SAF-*)
    | Safety
    /// Container rules (AOR-CNT-*)
    | Container
    /// Quality rules (AOR-QUA-*)
    | Quality
    /// Agent rules (AOR-AGT-*)
    | Agent
    /// Database rules (AOR-DB-*)
    | Database
    /// Documentation rules (AOR-DOC-*)
    | Documentation
    /// Batch operation rules (AOR-BATCH-*)
    | Batch
    /// Gemini rules (AOR-GEM-*)
    | Gemini

// ============================================================================
// TYPES - Rule Context
// ============================================================================

/// Operation type being checked
[<RequireQualifiedAccess>]
type OperationType =
    | ContainerStart
    | ContainerStop
    | Compilation
    | Testing
    | DatabaseMigration
    | FileEdit
    | BatchOperation
    | AgentTask
    | ExecutiveCommand
    | SafetyCheck
    | VtoPhase

/// Context for rule evaluation
type RuleContext = {
    /// Type of operation being performed
    Operation: OperationType
    /// Agent performing the operation (if applicable)
    AgentId: string option
    /// Target of the operation (file, container, etc.)
    Target: string option
    /// Additional context data as key-value pairs
    Data: Map<string, obj>
    /// Timestamp when context was created
    Timestamp: DateTimeOffset
    /// Previous operation in chain (for sequence validation)
    PreviousOperation: OperationType option
}

/// Create a new rule context
let createContext operation =
    {
        Operation = operation
        AgentId = None
        Target = None
        Data = Map.empty
        Timestamp = DateTimeOffset.UtcNow
        PreviousOperation = None
    }

/// Add agent ID to context
let withAgentId agentId ctx = { ctx with AgentId = Some agentId }

/// Add target to context
let withTarget target ctx = { ctx with Target = Some target }

/// Add data to context
let withData key value ctx =
    { ctx with Data = ctx.Data |> Map.add key (value :> obj) }

/// Add previous operation to context
let withPreviousOperation op ctx = { ctx with PreviousOperation = Some op }

// ============================================================================
// TYPES - Evaluation Result
// ============================================================================

/// Result of a single rule evaluation
[<RequireQualifiedAccess>]
type EvaluationResult =
    /// Rule passed with optional details
    | Passed of details: string option
    /// Rule failed with reason
    | Failed of reason: string
    /// Rule was skipped (not applicable to this context)
    | Skipped of reason: string
    /// Rule evaluation encountered an error
    | Error of exn: Exception

/// Check if evaluation passed
let isPassed = function
    | EvaluationResult.Passed _ -> true
    | _ -> false

/// Check if evaluation failed
let isFailed = function
    | EvaluationResult.Failed _ -> true
    | _ -> false

// ============================================================================
// TYPES - AOR Violation
// ============================================================================

/// Record of an AOR violation
type AORViolation = {
    /// Rule ID (e.g., "AOR-SAF-001")
    RuleId: string
    /// Rule name for display
    RuleName: string
    /// Violation message
    Message: string
    /// Severity of the violation
    Severity: RuleSeverity
    /// Context when violation occurred
    Context: RuleContext
    /// Timestamp of violation
    Timestamp: DateTimeOffset
    /// Suggested remediation
    Remediation: string option
}

/// Create a violation record
let createViolation ruleId ruleName message severity context remediation =
    {
        RuleId = ruleId
        RuleName = ruleName
        Message = message
        Severity = severity
        Context = context
        Timestamp = DateTimeOffset.UtcNow
        Remediation = remediation
    }

// ============================================================================
// TYPES - AOR Rule Definition
// ============================================================================

/// AOR Rule definition with evaluation function
type AORRule = {
    /// Unique rule ID (e.g., "AOR-SAF-001")
    Id: string
    /// Human-readable name
    Name: string
    /// Description of what the rule enforces
    Description: string
    /// Severity when violated
    Severity: RuleSeverity
    /// Rule category
    Category: RuleCategory
    /// Operations this rule applies to
    ApplicableOperations: OperationType list
    /// Evaluation function
    Evaluate: RuleContext -> EvaluationResult
    /// Is this rule enabled?
    Enabled: bool
}

/// Create a new AOR rule
let defineRule id name description severity category operations evaluator =
    {
        Id = id
        Name = name
        Description = description
        Severity = severity
        Category = category
        ApplicableOperations = operations
        Evaluate = evaluator
        Enabled = true
    }

/// Enable a rule
let enableRule rule = { rule with Enabled = true }

/// Disable a rule
let disableRule rule = { rule with Enabled = false }

/// Check if rule applies to operation
let isApplicable ctx rule =
    rule.Enabled && List.contains ctx.Operation rule.ApplicableOperations

// ============================================================================
// TYPES - Compliance Report
// ============================================================================

/// Overall compliance status
[<RequireQualifiedAccess>]
type ComplianceStatus =
    /// All applicable rules passed
    | Compliant
    /// Some rules failed but no critical violations
    | NonCompliant of violationCount: int
    /// Critical violation detected, requires immediate halt
    | CriticalViolation

/// Comprehensive compliance report
type ComplianceReport = {
    /// Overall compliance status
    Status: ComplianceStatus
    /// Rules that were checked
    RulesChecked: string list
    /// Rules that passed
    RulesPassed: string list
    /// Rules that were skipped (not applicable)
    RulesSkipped: string list
    /// Violations detected
    Violations: AORViolation list
    /// Report generation timestamp
    GeneratedAt: DateTimeOffset
    /// Time taken to run all checks (ms)
    CheckDurationMs: int64
    /// Context that was checked
    Context: RuleContext
}

// ============================================================================
// CORE AOR RULE DEFINITIONS
// ============================================================================

/// AOR-EXE-001: Executive has supreme authority
let ruleExe001 =
    defineRule
        "AOR-EXE-001"
        "Executive Supreme Authority"
        "Executive agent has supreme authority over all operations"
        RuleSeverity.Critical
        RuleCategory.Executive
        [OperationType.ExecutiveCommand; OperationType.AgentTask]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "is_executive_override" with
            | Some (:? bool as isOverride) when isOverride ->
                EvaluationResult.Passed (Some "Executive override in effect")
            | _ ->
                // Check if operation respects executive authority
                match ctx.Data |> Map.tryFind "executive_authorization" with
                | Some (:? bool as isAuthorized) when isAuthorized ->
                    EvaluationResult.Passed (Some "Executive authorized")
                | Some (:? bool as isAuthorized) when not isAuthorized ->
                    EvaluationResult.Failed "Operation not authorized by executive"
                | _ ->
                    // No explicit authorization needed for most operations
                    EvaluationResult.Passed None
        )

/// AOR-SAF-001: Halt <1s on STAMP violation
let ruleSaf001 =
    defineRule
        "AOR-SAF-001"
        "Safety Halt Threshold"
        "System must halt within 1 second on any STAMP violation"
        RuleSeverity.Critical
        RuleCategory.Safety
        [OperationType.SafetyCheck; OperationType.ContainerStart; OperationType.ContainerStop]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "halt_duration_ms" with
            | Some (:? int64 as durationMs) when durationMs > int64 haltThresholdMs ->
                EvaluationResult.Failed (sprintf "Halt took %dms, exceeds %dms threshold (SC-FSH-004)" durationMs haltThresholdMs)
            | Some (:? int64 as durationMs) ->
                EvaluationResult.Passed (Some (sprintf "Halt completed in %dms" durationMs))
            | Some (:? int as durationMs) when durationMs > haltThresholdMs ->
                EvaluationResult.Failed (sprintf "Halt took %dms, exceeds %dms threshold (SC-FSH-004)" durationMs haltThresholdMs)
            | Some (:? int as durationMs) ->
                EvaluationResult.Passed (Some (sprintf "Halt completed in %dms" durationMs))
            | _ ->
                // No halt duration data, cannot verify
                EvaluationResult.Skipped "No halt duration data available"
        )

/// AOR-CNT-001: Podman ONLY (no Docker)
let ruleCnt001 =
    defineRule
        "AOR-CNT-001"
        "Podman Only"
        "Container operations must use Podman exclusively, Docker is prohibited"
        RuleSeverity.Critical
        RuleCategory.Container
        [OperationType.ContainerStart; OperationType.ContainerStop]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "container_runtime" with
            | Some (:? string as runtime) ->
                let runtimeLower = runtime.ToLowerInvariant()
                if runtimeLower.Contains("podman") then
                    EvaluationResult.Passed (Some "Using Podman runtime")
                elif runtimeLower.Contains("docker") then
                    EvaluationResult.Failed "Docker runtime detected. Podman ONLY is allowed per SC-CNT-001"
                else
                    EvaluationResult.Failed (sprintf "Unknown runtime: %s. Only Podman is allowed" runtime)
            | _ ->
                // Check default runtime assumption
                match ctx.Data |> Map.tryFind "is_podman" with
                | Some (:? bool as isPodman) when isPodman ->
                    EvaluationResult.Passed (Some "Podman runtime confirmed")
                | Some (:? bool as isPodman) when not isPodman ->
                    EvaluationResult.Failed "Non-Podman runtime detected"
                | _ ->
                    EvaluationResult.Skipped "Container runtime not specified in context"
        )

/// AOR-QUA-001: Zero warnings mandatory
let ruleQua001 =
    defineRule
        "AOR-QUA-001"
        "Zero Warnings"
        "Compilation must produce zero warnings"
        RuleSeverity.High
        RuleCategory.Quality
        [OperationType.Compilation]
        (fun ctx ->
            let errors =
                match ctx.Data |> Map.tryFind "error_count" with
                | Some (:? int as count) -> count
                | _ -> 0
            let warnings =
                match ctx.Data |> Map.tryFind "warning_count" with
                | Some (:? int as count) -> count
                | _ -> 0

            if errors > 0 then
                EvaluationResult.Failed (sprintf "Compilation has %d errors" errors)
            elif warnings > 0 then
                EvaluationResult.Failed (sprintf "Compilation has %d warnings (must be 0)" warnings)
            else
                EvaluationResult.Passed (Some "Zero errors and warnings")
        )

/// AOR-AGT-001: Code must compile before task complete
let ruleAgt001 =
    defineRule
        "AOR-AGT-001"
        "Compile Before Complete"
        "Code must compile successfully before marking task as complete"
        RuleSeverity.High
        RuleCategory.Agent
        [OperationType.AgentTask]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "compilation_verified" with
            | Some (:? bool as verified) when verified ->
                EvaluationResult.Passed (Some "Compilation verified before task completion")
            | Some (:? bool as verified) when not verified ->
                EvaluationResult.Failed "Task marked complete without compilation verification"
            | _ ->
                // Check if task involves code changes
                match ctx.Data |> Map.tryFind "involves_code_changes" with
                | Some (:? bool as involvesCode) when involvesCode ->
                    EvaluationResult.Failed "Code changes require compilation verification"
                | _ ->
                    EvaluationResult.Passed (Some "Task does not involve code changes")
        )

/// AOR-DB-001: Use BaseResource
let ruleDb001 =
    defineRule
        "AOR-DB-001"
        "Use BaseResource"
        "Database resources must extend BaseResource"
        RuleSeverity.High
        RuleCategory.Database
        [OperationType.DatabaseMigration; OperationType.AgentTask]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "uses_base_resource" with
            | Some (:? bool as usesBase) when usesBase ->
                EvaluationResult.Passed (Some "Resource extends BaseResource")
            | Some (:? bool as usesBase) when not usesBase ->
                EvaluationResult.Failed "Resource must extend Indrajaal.BaseResource"
            | _ ->
                // Check if operation involves database resources
                match ctx.Data |> Map.tryFind "involves_db_resource" with
                | Some (:? bool as involvesDb) when involvesDb ->
                    EvaluationResult.Failed "Database resource operations require BaseResource verification"
                | _ ->
                    EvaluationResult.Skipped "Operation does not involve database resources"
        )

/// AOR-DOC-001: Read moduledoc before edit
let ruleDoc001 =
    defineRule
        "AOR-DOC-001"
        "Read Before Edit"
        "Must read moduledoc documentation before editing module"
        RuleSeverity.Medium
        RuleCategory.Documentation
        [OperationType.FileEdit]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "moduledoc_read" with
            | Some (:? bool as read) when read ->
                EvaluationResult.Passed (Some "Moduledoc was read before edit")
            | Some (:? bool as read) when not read ->
                EvaluationResult.Failed "Must read moduledoc before editing module"
            | _ ->
                // Check if target is a module file
                match ctx.Target with
                | Some target when target.EndsWith(".ex") || target.EndsWith(".exs") ->
                    // Elixir module files require doc reading
                    match ctx.Data |> Map.tryFind "file_content_read" with
                    | Some (:? bool as contentRead) when contentRead ->
                        EvaluationResult.Passed (Some "File content was read (includes moduledoc)")
                    | _ ->
                        EvaluationResult.Failed "Must read file content (including moduledoc) before editing"
                | _ ->
                    EvaluationResult.Skipped "Target is not an Elixir module"
        )

/// AOR-BATCH-001: Batch size <= 10
let ruleBatch001 =
    defineRule
        "AOR-BATCH-001"
        "Batch Size Limit"
        "Batch operations must not exceed 10 changes"
        RuleSeverity.High
        RuleCategory.Batch
        [OperationType.BatchOperation; OperationType.FileEdit]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "batch_size" with
            | Some (:? int as size) when size <= 10 ->
                EvaluationResult.Passed (Some (sprintf "Batch size %d is within limit" size))
            | Some (:? int as size) ->
                EvaluationResult.Failed (sprintf "Batch size %d exceeds maximum of 10" size)
            | _ ->
                // No batch size specified, assume single operation
                EvaluationResult.Passed (Some "Single operation (implicit batch size 1)")
        )

/// AOR-GEM-001: Plan => Verify
let ruleGem001 =
    defineRule
        "AOR-GEM-001"
        "Plan Implies Verify"
        "Every plan must have corresponding verification"
        RuleSeverity.High
        RuleCategory.Gemini
        [OperationType.AgentTask; OperationType.VtoPhase]
        (fun ctx ->
            match ctx.Data |> Map.tryFind "has_verification" with
            | Some (:? bool as hasVerify) when hasVerify ->
                EvaluationResult.Passed (Some "Plan has corresponding verification")
            | Some (:? bool as hasVerify) when not hasVerify ->
                EvaluationResult.Failed "Plan must have corresponding verification step"
            | _ ->
                // Check if this is a planning operation
                match ctx.Data |> Map.tryFind "is_planning_operation" with
                | Some (:? bool as isPlanning) when isPlanning ->
                    EvaluationResult.Failed "Planning operation requires verification plan"
                | _ ->
                    EvaluationResult.Skipped "Not a planning operation"
        )

/// All defined AOR rules
let allRules = [
    ruleExe001
    ruleSaf001
    ruleCnt001
    ruleQua001
    ruleAgt001
    ruleDb001
    ruleDoc001
    ruleBatch001
    ruleGem001
]

// ============================================================================
// RULE EVALUATION ENGINE
// ============================================================================

/// Evaluate a single rule against context
let evaluate (logger: UnifiedLogger) (rule: AORRule) (ctx: RuleContext) : AORViolation option =
    if not (isApplicable ctx rule) then
        logger.LogWithCategory(
            sprintf "AOR Rule %s skipped (not applicable to %A)" rule.Id ctx.Operation,
            EventCategory.Safety, LogLevel.Debug)
        None
    else
        logger.LogWithCategory(
            sprintf "AOR Evaluating: %s - %s" rule.Id rule.Name,
            EventCategory.Safety, LogLevel.Debug)

        match rule.Evaluate ctx with
        | EvaluationResult.Passed details ->
            let msg =
                match details with
                | Some d -> sprintf "AOR PASSED [%s]: %s" rule.Id d
                | None -> sprintf "AOR PASSED [%s]" rule.Id
            logger.LogWithCategory(msg, EventCategory.Safety, LogLevel.Info)
            logger.IncrementCounter("aor.rules.passed", tags = Map.ofList ["rule_id", rule.Id])
            None

        | EvaluationResult.Failed reason ->
            let violation = createViolation rule.Id rule.Name reason rule.Severity ctx None
            logger.LogWithCategory(
                sprintf "AOR FAILED [%s]: %s" rule.Id reason,
                EventCategory.Safety, LogLevel.Error)
            logger.IncrementCounter("aor.rules.failed", tags = Map.ofList ["rule_id", rule.Id; "severity", sprintf "%A" rule.Severity])
            Some violation

        | EvaluationResult.Skipped reason ->
            logger.LogWithCategory(
                sprintf "AOR SKIPPED [%s]: %s" rule.Id reason,
                EventCategory.Safety, LogLevel.Debug)
            None

        | EvaluationResult.Error ex ->
            logger.LogWithCategory(
                sprintf "AOR ERROR [%s]: %s" rule.Id ex.Message,
                EventCategory.Safety, LogLevel.Error)
            // Treat errors as violations for safety
            Some (createViolation rule.Id rule.Name (sprintf "Evaluation error: %s" ex.Message) RuleSeverity.High ctx None)

/// Check compliance against all applicable rules
let checkCompliance (logger: UnifiedLogger) (rules: AORRule list) (ctx: RuleContext) : ComplianceReport =
    logger.StartPhase("AOR Compliance Check")
    let sw = Stopwatch.StartNew()

    let mutable rulesChecked = []
    let mutable rulesPassed = []
    let mutable rulesSkipped = []
    let mutable violations = []

    for rule in rules do
        if rule.Enabled then
            if isApplicable ctx rule then
                rulesChecked <- rule.Id :: rulesChecked
                match evaluate logger rule ctx with
                | Some v ->
                    violations <- v :: violations
                | None ->
                    rulesPassed <- rule.Id :: rulesPassed
            else
                rulesSkipped <- rule.Id :: rulesSkipped

    sw.Stop()

    let status =
        if List.isEmpty violations then
            ComplianceStatus.Compliant
        elif violations |> List.exists (fun v -> v.Severity = RuleSeverity.Critical) then
            ComplianceStatus.CriticalViolation
        else
            ComplianceStatus.NonCompliant (List.length violations)

    let report = {
        Status = status
        RulesChecked = List.rev rulesChecked
        RulesPassed = List.rev rulesPassed
        RulesSkipped = List.rev rulesSkipped
        Violations = List.rev violations
        GeneratedAt = DateTimeOffset.UtcNow
        CheckDurationMs = sw.ElapsedMilliseconds
        Context = ctx
    }

    // Log summary
    logger.LogWithCategory(
        sprintf "AOR Compliance: %d checked, %d passed, %d violations in %dms"
            (List.length rulesChecked) (List.length rulesPassed) (List.length violations) sw.ElapsedMilliseconds,
        EventCategory.Safety, LogLevel.Info)

    // Record metrics
    logger.RecordHistogram("aor.compliance.duration_ms", float sw.ElapsedMilliseconds)
    logger.IncrementCounter("aor.compliance.checks", int64 (List.length rulesChecked))

    match status with
    | ComplianceStatus.Compliant ->
        logger.IncrementCounter("aor.compliance.compliant")
    | ComplianceStatus.NonCompliant count ->
        logger.IncrementCounter("aor.compliance.non_compliant", int64 count)
    | ComplianceStatus.CriticalViolation ->
        logger.IncrementCounter("aor.compliance.critical")

    logger.EndPhase("AOR Compliance Check", sw.ElapsedMilliseconds, (status = ComplianceStatus.Compliant))

    report

/// Run compliance check with all standard rules
let checkAllRules (logger: UnifiedLogger) ctx =
    checkCompliance logger allRules ctx

// ============================================================================
// ENFORCEMENT - HALT IMPLEMENTATION (AOR-SAF-001)
// ============================================================================

/// Result of halt operation
type HaltResult = {
    Success: bool
    DurationMs: int64
    Message: string
}

/// Enforce immediate halt on critical violation (AOR-SAF-001 compliant)
let enforceHalt (logger: UnifiedLogger) (violation: AORViolation) : HaltResult =
    let sw = Stopwatch.StartNew()

    logger.LogWithCategory(
        sprintf "AOR ENFORCING HALT: [%s] %s" violation.RuleId violation.Message,
        EventCategory.Safety, LogLevel.Critical)

    // Log violation details
    logger.LogWithCategory(
        sprintf "Violation Severity: %A" violation.Severity,
        EventCategory.Safety, LogLevel.Critical)
    logger.LogWithCategory(
        sprintf "Violation Context: Operation=%A, Agent=%s, Target=%s"
            violation.Context.Operation
            (violation.Context.AgentId |> Option.defaultValue "N/A")
            (violation.Context.Target |> Option.defaultValue "N/A"),
        EventCategory.Safety, LogLevel.Critical)

    // Record halt initiation
    logger.IncrementCounter("aor.halt.initiated", tags = Map.ofList ["rule_id", violation.RuleId])

    // Perform halt operations (in order of priority)
    // 1. Flush all logs immediately
    logger.Flush()

    // 2. Record the halt event
    logger.IncrementCounter("aor.halt.completed", tags = Map.ofList ["rule_id", violation.RuleId])

    sw.Stop()

    // Verify halt time compliance (SC-FSH-004: using type-safe threshold)
    let haltTimeMs = sw.ElapsedMilliseconds
    let isCompliant = haltTimeMs < int64 haltThresholdMs

    logger.RecordHistogram("aor.halt.duration_ms", float haltTimeMs, Map.ofList ["rule_id", violation.RuleId])

    if not isCompliant then
        logger.LogWithCategory(
            sprintf "AOR-SAF-001 VIOLATION: Halt took %dms (threshold: %dms) (SC-FSH-004)" haltTimeMs haltThresholdMs,
            EventCategory.Safety, LogLevel.Critical)

    {
        Success = isCompliant
        DurationMs = haltTimeMs
        Message =
            if isCompliant then
                sprintf "Halt completed in %dms (within %dms threshold) (SC-FSH-004)" haltTimeMs haltThresholdMs
            else
                sprintf "HALT THRESHOLD EXCEEDED: %dms > %dms (SC-FSH-004)" haltTimeMs haltThresholdMs
    }

/// Check if report requires halt
let requiresHalt (report: ComplianceReport) : bool =
    match report.Status with
    | ComplianceStatus.CriticalViolation -> true
    | _ -> false

/// Process report and enforce halt if necessary
let processReportWithHalt (logger: UnifiedLogger) (report: ComplianceReport) : HaltResult option =
    if requiresHalt report then
        let criticalViolation =
            report.Violations
            |> List.find (fun v -> v.Severity = RuleSeverity.Critical)
        Some (enforceHalt logger criticalViolation)
    else
        None

// ============================================================================
// REPORT GENERATION
// ============================================================================

/// Generate human-readable compliance report
let generateReport (report: ComplianceReport) : string =
    let sb = System.Text.StringBuilder()

    sb.AppendLine("═══════════════════════════════════════════════════════════════") |> ignore
    sb.AppendLine("              CEPAF AOR COMPLIANCE REPORT") |> ignore
    sb.AppendLine("═══════════════════════════════════════════════════════════════") |> ignore
    sb.AppendLine() |> ignore

    // Status
    let statusStr =
        match report.Status with
        | ComplianceStatus.Compliant -> "COMPLIANT"
        | ComplianceStatus.NonCompliant count -> sprintf "NON-COMPLIANT (%d violations)" count
        | ComplianceStatus.CriticalViolation -> "CRITICAL VIOLATION - HALT REQUIRED"
    sb.AppendLine(sprintf "Status: %s" statusStr) |> ignore
    sb.AppendLine(sprintf "Generated: %s" (report.GeneratedAt.ToString("o"))) |> ignore
    sb.AppendLine(sprintf "Check Duration: %dms" report.CheckDurationMs) |> ignore
    sb.AppendLine() |> ignore

    // Summary
    sb.AppendLine("─── SUMMARY ───") |> ignore
    sb.AppendLine(sprintf "Rules Checked: %d" (List.length report.RulesChecked)) |> ignore
    sb.AppendLine(sprintf "Rules Passed:  %d" (List.length report.RulesPassed)) |> ignore
    sb.AppendLine(sprintf "Rules Skipped: %d" (List.length report.RulesSkipped)) |> ignore
    sb.AppendLine(sprintf "Violations:    %d" (List.length report.Violations)) |> ignore
    sb.AppendLine() |> ignore

    // Violations (if any)
    if not (List.isEmpty report.Violations) then
        sb.AppendLine("─── VIOLATIONS ───") |> ignore
        for v in report.Violations do
            let severityMark =
                match v.Severity with
                | RuleSeverity.Critical -> "[CRITICAL]"
                | RuleSeverity.High -> "[HIGH]"
                | RuleSeverity.Medium -> "[MEDIUM]"
                | RuleSeverity.Low -> "[LOW]"
            sb.AppendLine(sprintf "%s %s: %s" severityMark v.RuleId v.RuleName) |> ignore
            sb.AppendLine(sprintf "    Message: %s" v.Message) |> ignore
            match v.Remediation with
            | Some r -> sb.AppendLine(sprintf "    Remediation: %s" r) |> ignore
            | None -> ()
            sb.AppendLine() |> ignore

    // Passed rules
    if not (List.isEmpty report.RulesPassed) then
        sb.AppendLine("─── PASSED RULES ───") |> ignore
        for ruleId in report.RulesPassed do
            sb.AppendLine(sprintf "  [PASS] %s" ruleId) |> ignore
        sb.AppendLine() |> ignore

    // Context
    sb.AppendLine("─── CONTEXT ───") |> ignore
    sb.AppendLine(sprintf "Operation: %A" report.Context.Operation) |> ignore
    sb.AppendLine(sprintf "Agent: %s" (report.Context.AgentId |> Option.defaultValue "N/A")) |> ignore
    sb.AppendLine(sprintf "Target: %s" (report.Context.Target |> Option.defaultValue "N/A")) |> ignore
    sb.AppendLine() |> ignore

    sb.AppendLine("═══════════════════════════════════════════════════════════════") |> ignore

    sb.ToString()

/// Generate JSON compliance report
let generateJsonReport (report: ComplianceReport) : string =
    let violationsJson =
        report.Violations
        |> List.map (fun v ->
            sprintf """{"ruleId":"%s","ruleName":"%s","message":"%s","severity":"%A"}"""
                v.RuleId
                (v.RuleName.Replace("\"", "\\\""))
                (v.Message.Replace("\"", "\\\""))
                v.Severity)
        |> String.concat ","

    sprintf """{
  "status": "%A",
  "generatedAt": "%s",
  "checkDurationMs": %d,
  "rulesChecked": %d,
  "rulesPassed": %d,
  "rulesSkipped": %d,
  "violationCount": %d,
  "violations": [%s],
  "context": {
    "operation": "%A",
    "agentId": %s,
    "target": %s
  }
}"""
        report.Status
        (report.GeneratedAt.ToString("o"))
        report.CheckDurationMs
        (List.length report.RulesChecked)
        (List.length report.RulesPassed)
        (List.length report.RulesSkipped)
        (List.length report.Violations)
        violationsJson
        report.Context.Operation
        (report.Context.AgentId |> Option.map (sprintf "\"%s\"") |> Option.defaultValue "null")
        (report.Context.Target |> Option.map (sprintf "\"%s\"") |> Option.defaultValue "null")

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/// Quick compliance check for container operations
let checkContainerCompliance (logger: UnifiedLogger) (runtime: string) (isPodman: bool) =
    let ctx =
        createContext OperationType.ContainerStart
        |> withData "container_runtime" runtime
        |> withData "is_podman" isPodman
    checkAllRules logger ctx

/// Quick compliance check for compilation
let checkCompilationCompliance (logger: UnifiedLogger) (errors: int) (warnings: int) =
    let ctx =
        createContext OperationType.Compilation
        |> withData "error_count" errors
        |> withData "warning_count" warnings
    checkAllRules logger ctx

/// Quick compliance check for batch operations
let checkBatchCompliance (logger: UnifiedLogger) (batchSize: int) =
    let ctx =
        createContext OperationType.BatchOperation
        |> withData "batch_size" batchSize
    checkAllRules logger ctx

/// Quick compliance check for file editing
let checkFileEditCompliance (logger: UnifiedLogger) (target: string) (contentRead: bool) =
    let ctx =
        createContext OperationType.FileEdit
        |> withTarget target
        |> withData "file_content_read" contentRead
        |> withData "moduledoc_read" contentRead
    checkAllRules logger ctx

/// Get all critical violations from a report
let getCriticalViolations (report: ComplianceReport) =
    report.Violations |> List.filter (fun v -> v.Severity = RuleSeverity.Critical)

/// Get rule by ID
let getRuleById ruleId =
    allRules |> List.tryFind (fun r -> r.Id = ruleId)

/// Get rules by category
let getRulesByCategory category =
    allRules |> List.filter (fun r -> r.Category = category)

// ============================================================================
// PATTERN-BASED CLASSIFICATION (SC-FSH-050)
// ============================================================================

/// Classify severity (SC-FSH-050)
let classifySeverity (severity: RuleSeverity) : string =
    match severity with
    | RuleSeverity.Critical -> "CRITICAL"
    | RuleSeverity.High -> "HIGH"
    | RuleSeverity.Medium -> "MEDIUM"
    | RuleSeverity.Low -> "LOW"

/// Classify operation type using active patterns (SC-FSH-050)
let classifyOperationType (op: OperationType) : string =
    match op with
    | OperationType.ContainerStart | OperationType.ContainerStop -> "CONTAINER"
    | OperationType.Compilation -> "BUILD"
    | OperationType.Testing -> "TEST"
    | OperationType.DatabaseMigration -> "DATABASE"
    | OperationType.FileEdit | OperationType.BatchOperation -> "FILE"
    | OperationType.AgentTask -> "AGENT"
    | OperationType.ExecutiveCommand -> "EXECUTIVE"
    | OperationType.SafetyCheck -> "SAFETY"
    | OperationType.VtoPhase -> "VTO"

/// Classify rule category using active patterns (SC-FSH-050)
let classifyRuleCategory (category: RuleCategory) : string =
    match category with
    | RuleCategory.Executive -> "EXECUTIVE"
    | RuleCategory.Safety -> "SAFETY"
    | RuleCategory.Container -> "CONTAINER"
    | RuleCategory.Quality -> "QUALITY"
    | RuleCategory.Agent -> "AGENT"
    | RuleCategory.Database -> "DATABASE"
    | RuleCategory.Documentation -> "DOCUMENTATION"
    | RuleCategory.Batch -> "BATCH"
    | RuleCategory.Gemini -> "GEMINI"

/// Get compliance classification using active patterns (SC-FSH-050)
let classifyCompliance (report: ComplianceReport) : string =
    match report.Status with
    | ComplianceStatus.Compliant -> "COMPLIANT"
    | ComplianceStatus.NonCompliant count when count >= 5 -> "CRITICAL_NON_COMPLIANT"
    | ComplianceStatus.NonCompliant count when count >= 3 -> "SEVERELY_NON_COMPLIANT"
    | ComplianceStatus.NonCompliant _ -> "NON_COMPLIANT"
    | ComplianceStatus.CriticalViolation -> "CRITICAL_VIOLATION"

/// Get sorted violations by severity using type-safe comparison (SC-FSH-050)
let getViolationsBySeverity (report: ComplianceReport) : AORViolation list =
    report.Violations
    |> List.sortBy (fun v -> severityToPriority v.Severity)

/// Get compliance summary with pattern classification (SC-FSH-050)
let getComplianceSummary (report: ComplianceReport) =
    let criticalCount = report.Violations |> List.filter (fun v -> v.Severity = RuleSeverity.Critical) |> List.length
    let highCount = report.Violations |> List.filter (fun v -> v.Severity = RuleSeverity.High) |> List.length
    let mediumCount = report.Violations |> List.filter (fun v -> v.Severity = RuleSeverity.Medium) |> List.length
    let lowCount = report.Violations |> List.filter (fun v -> v.Severity = RuleSeverity.Low) |> List.length

    {|
        TotalViolations = List.length report.Violations
        CriticalCount = criticalCount
        HighCount = highCount
        MediumCount = mediumCount
        LowCount = lowCount
        Classification = classifyCompliance report
        RequiresHalt = requiresHalt report
        SeverityScore = criticalCount * 100 + highCount * 10 + mediumCount * 3 + lowCount
        PassedRules = List.length report.RulesPassed
        CheckedRules = List.length report.RulesChecked
        CompliancePercentage =
            if List.length report.RulesChecked > 0 then
                float (List.length report.RulesPassed) / float (List.length report.RulesChecked) * 100.0
            else 100.0
    |}

/// Check if violations match specific patterns (SC-FSH-050)
let hasViolationPattern (pattern: string) (report: ComplianceReport) : bool =
    report.Violations
    |> List.exists (fun v ->
        v.RuleId.Contains(pattern) || v.Message.Contains(pattern))

/// Get violations by rule ID pattern (SC-FSH-050)
let getViolationsByPattern (pattern: string) (report: ComplianceReport) : AORViolation list =
    report.Violations
    |> List.filter (fun v -> v.RuleId.StartsWith(pattern))

/// Get safety violations (AOR-SAF-*) (SC-FSH-050)
let getSafetyViolations = getViolationsByPattern "AOR-SAF"

/// Get container violations (AOR-CNT-*) (SC-FSH-050)
let getContainerViolations = getViolationsByPattern "AOR-CNT"

/// Get quality violations (AOR-QUA-*) (SC-FSH-050)
let getQualityViolations = getViolationsByPattern "AOR-QUA"
