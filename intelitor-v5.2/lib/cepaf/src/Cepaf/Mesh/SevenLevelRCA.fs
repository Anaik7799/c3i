// =============================================================================
// SevenLevelRCA.fs - 7-Level Root Cause Analysis for SIL-6 Boot Sequence
// =============================================================================
// STAMP: SC-BOOT-011, SC-BOOT-012, SC-RCA-001, SC-RCA-002
// AOR: AOR-RCA-001, AOR-TPS-001 (5-Why methodology)
//
// ## 7-Level RCA Matrix
// | Level | Name | Scope | Question | Focus |
// |-------|------|-------|----------|-------|
// | L1 | Symptom | Observable | What failed? | Immediate error |
// | L2 | Local | Immediate | Why here? | Local context |
// | L3 | Logic | Code | Why this code? | Code path |
// | L4 | Module | Component | Why this module? | Module design |
// | L5 | System | Cross-module | Why systemic? | Integration |
// | L6 | Design | Pattern | Why this design? | Architecture |
// | L7 | Architecture | Structural | Why architecture? | Specification |
//
// ## TPS Integration
// - Jidoka (自働化): Stop immediately on defect, fix at root cause
// - 5-Why: Trace through L1→L7 asking "Why?" at each level
// - Kaizen: Use findings to prevent recurrence
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
open System.Collections.Generic

/// 7-Level RCA Matrix Levels
type RCALevel =
    /// L1: What failed? Observable symptom
    | L1_Symptom
    /// L2: Why here? Immediate local context
    | L2_Local
    /// L3: Why this code? Code logic path
    | L3_Logic
    /// L4: Why this module? Module/component level
    | L4_Module
    /// L5: Why systemic? Cross-module integration
    | L5_System
    /// L6: Why this design? Design pattern level
    | L6_Design
    /// L7: Why architecture? Structural/specification level
    | L7_Architecture

/// Single RCA finding at a specific level
type RCAFinding = {
    /// RCA level this finding belongs to
    Level: RCALevel
    /// Question asked at this level
    Question: string
    /// Finding/answer discovered
    Finding: string
    /// Supporting evidence (log lines, stack traces, etc.)
    Evidence: string list
    /// Suggested remediation if applicable
    Remediation: string option
    /// Timestamp of analysis
    Timestamp: DateTime
}

/// Complete RCA report for an issue
type RCAReport = {
    /// Issue identifier
    IssueId: string
    /// Issue summary/title
    Issue: string
    /// All findings from L1 to L7
    Findings: RCAFinding list
    /// Identified root cause level
    RootCauseLevel: RCALevel
    /// Root cause summary
    RootCauseSummary: string
    /// Recommended fix
    RecommendedFix: string
    /// Prevention strategy
    PreventionStrategy: string
    /// Report timestamp
    ReportTimestamp: DateTime
    /// Total analysis duration
    AnalysisDurationMs: int64
}

/// Severity classification for RCA issues
type RCASeverity =
    | Critical  // System down, boot failure
    | High      // Major functionality impaired
    | Medium    // Degraded performance
    | Low       // Minor inconvenience

module SevenLevelRCA =

    /// Get question for each RCA level
    let getLevelQuestion (level: RCALevel) : string =
        match level with
        | L1_Symptom -> "What failed? What is the observable error?"
        | L2_Local -> "Why here? What is the immediate context?"
        | L3_Logic -> "Why this code? What logic path led here?"
        | L4_Module -> "Why this module? What module design issue?"
        | L5_System -> "Why systemic? What cross-module integration issue?"
        | L6_Design -> "Why this design? What design pattern issue?"
        | L7_Architecture -> "Why architecture? What specification gap?"

    /// Get level name
    let getLevelName (level: RCALevel) : string =
        match level with
        | L1_Symptom -> "SYMPTOM"
        | L2_Local -> "LOCAL"
        | L3_Logic -> "LOGIC"
        | L4_Module -> "MODULE"
        | L5_System -> "SYSTEM"
        | L6_Design -> "DESIGN"
        | L7_Architecture -> "ARCHITECTURE"

    /// Get level number
    let getLevelNumber (level: RCALevel) : int =
        match level with
        | L1_Symptom -> 1
        | L2_Local -> 2
        | L3_Logic -> 3
        | L4_Module -> 4
        | L5_System -> 5
        | L6_Design -> 6
        | L7_Architecture -> 7

    /// All RCA levels in order
    let allLevels = [
        L1_Symptom
        L2_Local
        L3_Logic
        L4_Module
        L5_System
        L6_Design
        L7_Architecture
    ]

    /// Create a finding at a specific level
    let createFinding (level: RCALevel) (finding: string) (evidence: string list) (remediation: string option) : RCAFinding =
        {
            Level = level
            Question = getLevelQuestion level
            Finding = finding
            Evidence = evidence
            Remediation = remediation
            Timestamp = DateTime.UtcNow
        }

    /// Known startup issue patterns and their RCA chains
    type KnownIssue = {
        Pattern: string
        L1: string
        L2: string
        L3: string
        L4: string
        L5: string
        L6: string
        L7: string
        RootLevel: RCALevel
        Fix: string
        Prevention: string
    }

    /// Known startup failure patterns
    let knownIssues = [
        {
            Pattern = "oban_peers"
            L1 = "App container enters restart loop"
            L2 = "Oban GenServer crashes: 'oban_peers table undefined'"
            L3 = "Database migrations not verified before app start"
            L4 = "MeshStartup.fs has no migration verification gate"
            L5 = "No state vector check before proceeding to next stage"
            L6 = "Startup lacks formal pre-condition/post-condition contracts"
            L7 = "No mathematical startup specification to conform against"
            RootLevel = L7_Architecture
            Fix = "Add migration gate (SC-BOOT-002) before app startup"
            Prevention = "Implement state vector verification (SC-BOOT-001)"
        }
        {
            Pattern = "port conflict"
            L1 = "Container fails to start with bind error"
            L2 = "Port already in use by another process"
            L3 = "No port scouring before container start"
            L4 = "MeshStartup.fs missing port isolation"
            L5 = "No substrate cleanup in boot sequence"
            L6 = "Boot assumes clean slate without verification"
            L7 = "No port isolation specification (SC-BOOT-007)"
            RootLevel = L6_Design
            Fix = "Run port scouring in S0_PREFLIGHT stage"
            Prevention = "Add scourPorts() call before any container start"
        }
        {
            Pattern = "quorum"
            L1 = "Cluster formation timeout"
            L2 = "Only 1 of 3 Zenoh routers healthy"
            L3 = "Health checks passing but cluster incomplete"
            L4 = "HealthCoordinator not verifying quorum"
            L5 = "No 2oo3 voting enforcement in boot"
            L6 = "Quorum verification not in critical path"
            L7 = "Missing quorum specification (SC-BOOT-003)"
            RootLevel = L5_System
            Fix = "Require 2oo3 quorum before S3_APP_SEED"
            Prevention = "Add quorum gate to verifyStateForStage"
        }
        {
            Pattern = "health timeout"
            L1 = "Container marked unhealthy after start"
            L2 = "Health check failing with timeout"
            L3 = "App still compiling during health check"
            L4 = "HealthCheckTimeoutMs too short for compilation"
            L5 = "Patient Mode not propagating to health checks"
            L6 = "Health config doesn't account for compile time"
            L7 = "Missing patient mode in health specification"
            RootLevel = L4_Module
            Fix = "Increase appHealthMaxWait to 300000ms (5 min)"
            Prevention = "Configure startPeriod = 900 in health check"
        }
        {
            Pattern = "zenoh nif"
            L1 = "Tests skip Zenoh functionality"
            L2 = "SKIP_ZENOH_NIF=1 in environment"
            L3 = "NIF disabled to work around compilation"
            L4 = "Zenoh NIF not loaded at runtime"
            L5 = "Test environment differs from production"
            L6 = "No enforcement of NIF requirement"
            L7 = "Missing SC-ZENOH-001 enforcement"
            RootLevel = L3_Logic
            Fix = "Set SKIP_ZENOH_NIF=0 in all environments"
            Prevention = "Add NIF check to preflight (AOR-TEST-NIF-001)"
        }
    ]

    /// Find matching known issue by pattern
    let findKnownIssue (errorText: string) : KnownIssue option =
        knownIssues
        |> List.tryFind (fun ki -> errorText.ToLower().Contains(ki.Pattern.ToLower()))

    /// Build RCA findings from known issue
    let buildFindingsFromKnown (ki: KnownIssue) : RCAFinding list =
        [
            createFinding L1_Symptom ki.L1 [] None
            createFinding L2_Local ki.L2 [] None
            createFinding L3_Logic ki.L3 [] None
            createFinding L4_Module ki.L4 [] None
            createFinding L5_System ki.L5 [] None
            createFinding L6_Design ki.L6 [] None
            createFinding L7_Architecture ki.L7 [] (Some ki.Fix)
        ]

    /// Analyze an error with 7-level RCA
    let analyze (issue: string) (errorText: string) (context: Map<string, obj>) : RCAReport =
        let sw = System.Diagnostics.Stopwatch.StartNew()
        let issueId = sprintf "RCA-%s-%d" (DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")) (abs (issue.GetHashCode()) % 10000)

        // Check for known patterns first
        let (findings, rootLevel, fix, prevention) =
            match findKnownIssue errorText with
            | Some ki ->
                (buildFindingsFromKnown ki, ki.RootLevel, ki.Fix, ki.Prevention)
            | None ->
                // Generic analysis for unknown issues
                let findings = [
                    createFinding L1_Symptom issue [errorText] None
                    createFinding L2_Local "Error occurred in startup sequence" [] None
                    createFinding L3_Logic "Further analysis required" [] None
                    createFinding L4_Module "Module analysis required" [] None
                    createFinding L5_System "System integration analysis required" [] None
                    createFinding L6_Design "Design review recommended" [] None
                    createFinding L7_Architecture "Specification review may be needed" [] None
                ]
                (findings, L3_Logic, "Manual investigation required", "Add error pattern to knownIssues")

        sw.Stop()

        {
            IssueId = issueId
            Issue = issue
            Findings = findings
            RootCauseLevel = rootLevel
            RootCauseSummary = findings |> List.tryFind (fun f -> f.Level = rootLevel) |> Option.map (fun f -> f.Finding) |> Option.defaultValue "Unknown"
            RecommendedFix = fix
            PreventionStrategy = prevention
            ReportTimestamp = DateTime.UtcNow
            AnalysisDurationMs = sw.ElapsedMilliseconds
        }

    /// Print RCA report with ANSI colors
    let printReport (report: RCAReport) : unit =
        let reset = "\u001b[0m"
        let bold = "\u001b[1m"
        let red = "\u001b[31m"
        let yellow = "\u001b[33m"
        let cyan = "\u001b[36m"
        let green = "\u001b[32m"
        let magenta = "\u001b[35m"

        printfn ""
        printfn "%s%s╔═══════════════════════════════════════════════════════════════════════════════╗%s" magenta bold reset
        printfn "%s%s║  7-LEVEL ROOT CAUSE ANALYSIS                                                  ║%s" magenta bold reset
        printfn "%s%s╚═══════════════════════════════════════════════════════════════════════════════╝%s" magenta bold reset
        printfn ""
        printfn "%sIssue ID:%s %s" cyan reset report.IssueId
        printfn "%sIssue:%s %s" cyan reset report.Issue
        printfn "%sAnalysis Time:%s %dms" cyan reset report.AnalysisDurationMs
        printfn ""

        // Print findings chain
        printfn "%s7-LEVEL RCA CHAIN (5-Why Methodology):%s" yellow reset
        printfn ""

        for finding in report.Findings do
            let levelNum = getLevelNumber finding.Level
            let levelName = getLevelName finding.Level
            let isRoot = finding.Level = report.RootCauseLevel

            let levelColor = if isRoot then red else cyan
            let arrow = if levelNum < 7 then "↓ WHY?" else ""

            printfn "  %s%sL%d (%s)%s" levelColor bold levelNum levelName reset
            printfn "     %s→%s %s" levelColor reset finding.Finding
            if not (List.isEmpty finding.Evidence) then
                printfn "       Evidence: %s" (String.Join("; ", finding.Evidence |> List.truncate 2))
            if isRoot then
                printfn "       %s%s▲ ROOT CAUSE IDENTIFIED%s" red bold reset
            elif arrow <> "" then
                printfn "     %s%s%s" cyan arrow reset
            printfn ""

        // Print summary
        printfn "%s%sSUMMARY%s" green bold reset
        printfn "  Root Cause Level: %sL%d (%s)%s"
            red (getLevelNumber report.RootCauseLevel) (getLevelName report.RootCauseLevel) reset
        printfn "  Root Cause: %s" report.RootCauseSummary
        printfn ""
        printfn "%s%sREMEDIATION%s" green bold reset
        printfn "  %sRecommended Fix:%s %s" yellow reset report.RecommendedFix
        printfn "  %sPrevention:%s %s" yellow reset report.PreventionStrategy
        printfn ""

    /// Analyze startup failure and print report
    let analyzeAndPrint (issue: string) (errorText: string) : RCAReport =
        let report = analyze issue errorText Map.empty
        printReport report
        report

    /// Quick analyze from error string only
    let quickAnalyze (errorText: string) : RCAReport =
        analyzeAndPrint "Startup Failure" errorText
