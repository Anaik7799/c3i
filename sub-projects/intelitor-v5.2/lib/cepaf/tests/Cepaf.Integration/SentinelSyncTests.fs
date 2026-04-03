/// Sentinel Sync Integration Tests
/// Tests for threat detection and mitigation synchronization
module Cepaf.Integration.SentinelSyncTests

open System
open Expecto

// ============================================================================
// Threat Model
// ============================================================================

type ThreatSeverity = Low | Medium | High | Critical

type ThreatStatus =
    | Detected
    | Analyzing
    | Confirmed
    | Mitigating
    | Mitigated
    | FalsePositive

type Threat = {
    Id: string
    Category: string
    Description: string
    Source: string
    Severity: ThreatSeverity
    Status: ThreatStatus
    RPN: int
    DetectedAt: DateTime
    MitigatedAt: DateTime option
}

let defaultThreat = {
    Id = ""
    Category = ""
    Description = ""
    Source = ""
    Severity = Low
    Status = Detected
    RPN = 0
    DetectedAt = DateTime.UtcNow
    MitigatedAt = None
}

// ============================================================================
// RPN Calculation Tests
// ============================================================================

let severityScore (severity: ThreatSeverity) =
    match severity with
    | Low -> 1
    | Medium -> 4
    | High -> 7
    | Critical -> 10

let calculateRPN (severity: int) (occurrence: int) (detection: int) =
    severity * occurrence * detection

let rpnCategory (rpn: int) =
    if rpn >= 200 then "Critical"
    elif rpn >= 100 then "High"
    elif rpn >= 50 then "Medium"
    else "Low"

let requiresImmediateAction (rpn: int) =
    rpn >= 100

let requiresEscalation (rpn: int) =
    rpn >= 50  // Per AOR-IMMUNE-004

[<Tests>]
let rpnTests =
    testList "RPNCalculation" [
        test "should calculate RPN correctly" {
            Expect.equal (calculateRPN 10 8 5) 400 "Critical RPN"
            Expect.equal (calculateRPN 5 5 5) 125 "Medium RPN"
            Expect.equal (calculateRPN 1 1 1) 1 "Low RPN"
        }

        test "should categorize RPN" {
            Expect.equal (rpnCategory 400) "Critical" ">= 200"
            Expect.equal (rpnCategory 150) "High" ">= 100"
            Expect.equal (rpnCategory 75) "Medium" ">= 50"
            Expect.equal (rpnCategory 25) "Low" "< 50"
        }

        test "should identify immediate action threshold" {
            Expect.isTrue (requiresImmediateAction 100) "100 requires action"
            Expect.isTrue (requiresImmediateAction 200) "200 requires action"
            Expect.isFalse (requiresImmediateAction 50) "50 doesn't require immediate"
        }

        test "should identify escalation threshold (AOR-IMMUNE-004)" {
            Expect.isTrue (requiresEscalation 50) "50 requires escalation"
            Expect.isTrue (requiresEscalation 100) "100 requires escalation"
            Expect.isFalse (requiresEscalation 49) "49 doesn't require escalation"
        }
    ]

// ============================================================================
// Threat State Machine Tests
// ============================================================================

type ThreatTransition =
    | StartAnalysis
    | ConfirmThreat
    | StartMitigation
    | CompleteMitigation
    | MarkFalsePositive

let canTransition (current: ThreatStatus) (transition: ThreatTransition) =
    match current, transition with
    | Detected, StartAnalysis -> true
    | Analyzing, ConfirmThreat -> true
    | Analyzing, MarkFalsePositive -> true
    | Confirmed, StartMitigation -> true
    | Mitigating, CompleteMitigation -> true
    | _ -> false

let applyTransition (current: ThreatStatus) (transition: ThreatTransition) =
    if canTransition current transition then
        match current, transition with
        | Detected, StartAnalysis -> Some Analyzing
        | Analyzing, ConfirmThreat -> Some Confirmed
        | Analyzing, MarkFalsePositive -> Some FalsePositive
        | Confirmed, StartMitigation -> Some Mitigating
        | Mitigating, CompleteMitigation -> Some Mitigated
        | _ -> None
    else None

[<Tests>]
let threatStateMachineTests =
    testList "ThreatStateMachine" [
        test "should transition from Detected to Analyzing" {
            let result = applyTransition Detected StartAnalysis
            Expect.equal result (Some Analyzing) "Detected -> Analyzing"
        }

        test "should transition from Analyzing to Confirmed" {
            let result = applyTransition Analyzing ConfirmThreat
            Expect.equal result (Some Confirmed) "Analyzing -> Confirmed"
        }

        test "should allow false positive marking" {
            let result = applyTransition Analyzing MarkFalsePositive
            Expect.equal result (Some FalsePositive) "Analyzing -> FalsePositive"
        }

        test "should complete mitigation" {
            let result = applyTransition Mitigating CompleteMitigation
            Expect.equal result (Some Mitigated) "Mitigating -> Mitigated"
        }

        test "should block invalid transitions" {
            let result = applyTransition Detected CompleteMitigation
            Expect.isNone result "Cannot complete from Detected"
        }
    ]

// ============================================================================
// Pattern Hunter Tests (SC-IMMUNE-004)
// ============================================================================

type PatternSignature = {
    Id: string
    Pattern: string
    Confidence: float
    Category: string
}

type PreErrorDetection = {
    Signature: PatternSignature
    DetectedAt: DateTime
    PredictedError: string
    TimeToError: TimeSpan option
}

let isHighConfidence (detection: PreErrorDetection) =
    detection.Signature.Confidence >= 0.8

let shouldAlert (detection: PreErrorDetection) =
    detection.Signature.Confidence >= 0.7 ||
    detection.TimeToError.IsSome && detection.TimeToError.Value < TimeSpan.FromMinutes(5.0)

let patternMatchScore (actual: string) (pattern: string) =
    // Simplified pattern matching
    if actual.Contains(pattern) then 1.0
    elif pattern.Length > 0 && actual.StartsWith(pattern.Substring(0, 1)) then 0.5
    else 0.0

[<Tests>]
let patternHunterTests =
    testList "PatternHunter" [
        test "should detect high confidence" {
            let detection = {
                Signature = { Id = "1"; Pattern = ""; Confidence = 0.9; Category = "" }
                DetectedAt = DateTime.UtcNow
                PredictedError = "Memory leak"
                TimeToError = Some (TimeSpan.FromMinutes(2.0))
            }
            Expect.isTrue (isHighConfidence detection) "0.9 is high confidence"
        }

        test "should alert on confidence threshold" {
            let highConf = {
                Signature = { Id = "1"; Pattern = ""; Confidence = 0.75; Category = "" }
                DetectedAt = DateTime.UtcNow
                PredictedError = ""
                TimeToError = None
            }
            Expect.isTrue (shouldAlert highConf) "0.75 triggers alert"
        }

        test "should alert on imminent error" {
            let imminent = {
                Signature = { Id = "1"; Pattern = ""; Confidence = 0.5; Category = "" }
                DetectedAt = DateTime.UtcNow
                PredictedError = ""
                TimeToError = Some (TimeSpan.FromMinutes(2.0))
            }
            Expect.isTrue (shouldAlert imminent) "Imminent error triggers alert"
        }
    ]

// ============================================================================
// Symbiotic Defense Tests
// ============================================================================

type DefenseAction =
    | Isolate of target: string
    | RateLimit of target: string * limit: int
    | BlockIP of ip: string
    | KillProcess of pid: int
    | RestartService of service: string
    | NotifyAdmin of message: string

type DefenseResponse = {
    ThreatId: string
    Actions: DefenseAction list
    ExecutedAt: DateTime
    Success: bool
}

let actionSeverity (action: DefenseAction) =
    match action with
    | KillProcess _ -> 10
    | BlockIP _ -> 8
    | Isolate _ -> 7
    | RestartService _ -> 5
    | RateLimit _ -> 3
    | NotifyAdmin _ -> 1

let isDestructiveAction (action: DefenseAction) =
    match action with
    | KillProcess _ | BlockIP _ | Isolate _ -> true
    | _ -> false

let requiresApproval (actions: DefenseAction list) =
    actions |> List.exists isDestructiveAction

[<Tests>]
let symbioticDefenseTests =
    testList "SymbioticDefense" [
        test "should rank action severity" {
            Expect.equal (actionSeverity (KillProcess 1234)) 10 "KillProcess is most severe"
            Expect.equal (actionSeverity (NotifyAdmin "")) 1 "Notify is least severe"
        }

        test "should identify destructive actions" {
            Expect.isTrue (isDestructiveAction (KillProcess 1)) "Kill is destructive"
            Expect.isTrue (isDestructiveAction (BlockIP "1.2.3.4")) "Block is destructive"
            Expect.isFalse (isDestructiveAction (NotifyAdmin "")) "Notify is not destructive"
        }

        test "should require approval for destructive actions" {
            let destructive = [KillProcess 1; NotifyAdmin ""]
            let nonDestructive = [RateLimit ("api", 100); NotifyAdmin ""]

            Expect.isTrue (requiresApproval destructive) "Destructive requires approval"
            Expect.isFalse (requiresApproval nonDestructive) "Non-destructive doesn't require approval"
        }
    ]

// ============================================================================
// Sentinel Health Sync Tests (SC-PRAJNA-004)
// ============================================================================

type SentinelHealth = {
    NodeId: string
    Status: string
    ActiveThreats: int
    MitigatedLast24h: int
    PatternHunterActive: bool
    SymbioticDefenseActive: bool
    LastSync: DateTime
}

let isSentinelHealthy (health: SentinelHealth) =
    health.Status = "healthy" &&
    health.PatternHunterActive &&
    health.SymbioticDefenseActive

let isHealthSyncRequired (health: SentinelHealth) =
    // Sync every 30s per SC-PRAJNA-004
    DateTime.UtcNow - health.LastSync > TimeSpan.FromSeconds(30.0)

let healthSyncPayload (health: SentinelHealth) =
    sprintf """{"nodeId":"%s","status":"%s","activeThreats":%d,"lastSync":"%s"}"""
        health.NodeId health.Status health.ActiveThreats (health.LastSync.ToString("o"))

[<Tests>]
let sentinelHealthTests =
    testList "SentinelHealth" [
        test "should determine healthy status" {
            let healthy = {
                NodeId = "n-1"
                Status = "healthy"
                ActiveThreats = 0
                MitigatedLast24h = 5
                PatternHunterActive = true
                SymbioticDefenseActive = true
                LastSync = DateTime.UtcNow
            }
            Expect.isTrue (isSentinelHealthy healthy) "Should be healthy"
        }

        test "should detect unhealthy when components inactive" {
            let unhealthy = {
                NodeId = "n-1"
                Status = "healthy"
                ActiveThreats = 0
                MitigatedLast24h = 0
                PatternHunterActive = false  // Inactive
                SymbioticDefenseActive = true
                LastSync = DateTime.UtcNow
            }
            Expect.isFalse (isSentinelHealthy unhealthy) "PatternHunter inactive"
        }

        test "should require sync after 30s (SC-PRAJNA-004)" {
            let stale = {
                NodeId = "n-1"
                Status = "healthy"
                ActiveThreats = 0
                MitigatedLast24h = 0
                PatternHunterActive = true
                SymbioticDefenseActive = true
                LastSync = DateTime.UtcNow.AddSeconds(-35.0)
            }
            Expect.isTrue (isHealthSyncRequired stale) "Stale requires sync"
        }

        test "should not require sync within 30s" {
            let fresh = {
                NodeId = "n-1"
                Status = "healthy"
                ActiveThreats = 0
                MitigatedLast24h = 0
                PatternHunterActive = true
                SymbioticDefenseActive = true
                LastSync = DateTime.UtcNow
            }
            Expect.isFalse (isHealthSyncRequired fresh) "Fresh doesn't require sync"
        }
    ]

// ============================================================================
// Threat Timeline Tests
// ============================================================================

type ThreatEvent = {
    ThreatId: string
    EventType: string
    Timestamp: DateTime
    Details: string
}

type ThreatTimeline = {
    ThreatId: string
    Events: ThreatEvent list
}

let addEvent (event: ThreatEvent) (timeline: ThreatTimeline) =
    { timeline with Events = timeline.Events @ [event] }

let timelineisOrdered (timeline: ThreatTimeline) =
    let timestamps = timeline.Events |> List.map (fun e -> e.Timestamp)
    timestamps = List.sort timestamps

let timeToDtection (timeline: ThreatTimeline) =
    let detected = timeline.Events |> List.tryFind (fun e -> e.EventType = "detected")
    let confirmed = timeline.Events |> List.tryFind (fun e -> e.EventType = "confirmed")
    match detected, confirmed with
    | Some d, Some c -> Some (c.Timestamp - d.Timestamp)
    | _ -> None

let timeToMitigation (timeline: ThreatTimeline) =
    let confirmed = timeline.Events |> List.tryFind (fun e -> e.EventType = "confirmed")
    let mitigated = timeline.Events |> List.tryFind (fun e -> e.EventType = "mitigated")
    match confirmed, mitigated with
    | Some c, Some m -> Some (m.Timestamp - c.Timestamp)
    | _ -> None

[<Tests>]
let threatTimelineTests =
    testList "ThreatTimeline" [
        test "should add events in order" {
            let timeline = { ThreatId = "t-1"; Events = [] }
            let e1 = { ThreatId = "t-1"; EventType = "detected"; Timestamp = DateTime.UtcNow; Details = "" }
            let e2 = { ThreatId = "t-1"; EventType = "analyzed"; Timestamp = DateTime.UtcNow.AddMinutes(1.0); Details = "" }

            let updated = timeline |> addEvent e1 |> addEvent e2
            Expect.equal updated.Events.Length 2 "Should have 2 events"
            Expect.isTrue (timelineisOrdered updated) "Should be ordered"
        }

        test "should calculate time to detection" {
            let timeline = {
                ThreatId = "t-1"
                Events = [
                    { ThreatId = "t-1"; EventType = "detected"; Timestamp = DateTime(2026, 1, 1, 10, 0, 0); Details = "" }
                    { ThreatId = "t-1"; EventType = "confirmed"; Timestamp = DateTime(2026, 1, 1, 10, 5, 0); Details = "" }
                ]
            }
            let ttd = timeToDtection timeline
            Expect.isSome ttd "Should have TTD"
            Expect.equal ttd.Value.TotalMinutes 5.0 "TTD should be 5 minutes"
        }
    ]

// ============================================================================
// Alert Correlation Tests
// ============================================================================

type CorrelatedThreat = {
    PrimaryThreatId: string
    RelatedThreatIds: string list
    CorrelationScore: float
    CommonSource: string option
}

let correlateThreats (threats: Threat list) =
    // Group by source
    threats
    |> List.groupBy (fun t -> t.Source)
    |> List.filter (fun (_, group) -> group.Length > 1)
    |> List.map (fun (source, group) ->
        {
            PrimaryThreatId = group.[0].Id
            RelatedThreatIds = group |> List.skip 1 |> List.map (fun t -> t.Id)
            CorrelationScore = 0.8
            CommonSource = Some source
        })

let isHighlyCorrelated (correlation: CorrelatedThreat) =
    correlation.CorrelationScore >= 0.7

[<Tests>]
let correlationTests =
    testList "ThreatCorrelation" [
        test "should correlate threats by source" {
            let threats = [
                { defaultThreat with Id = "t-1"; Source = "192.168.1.100" }
                { defaultThreat with Id = "t-2"; Source = "192.168.1.100" }
                { defaultThreat with Id = "t-3"; Source = "192.168.1.200" }
            ]
            let correlated = correlateThreats threats
            Expect.equal correlated.Length 1 "Should have 1 correlation"
            Expect.equal correlated.[0].RelatedThreatIds.Length 1 "Should have 1 related"
        }

        test "should identify high correlation" {
            let high = { PrimaryThreatId = "t-1"; RelatedThreatIds = ["t-2"]; CorrelationScore = 0.9; CommonSource = None }
            let low = { PrimaryThreatId = "t-3"; RelatedThreatIds = []; CorrelationScore = 0.3; CommonSource = None }

            Expect.isTrue (isHighlyCorrelated high) "0.9 is highly correlated"
            Expect.isFalse (isHighlyCorrelated low) "0.3 is not highly correlated"
        }
    ]
