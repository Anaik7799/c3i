/// WebUI Component Tests
/// Tests for Bolero/Blazor component rendering and behavior
module Cepaf.Cockpit.Web.Tests.ComponentTests

open System
open Expecto

// ============================================================================
// Health Gauge Component Tests
// ============================================================================

type HealthGaugeState = {
    Value: float
    Label: string
    ShowPercentage: bool
}

let healthGaugeClass (state: HealthGaugeState) =
    if state.Value >= 90.0 then "gauge healthy"
    elif state.Value >= 70.0 then "gauge warning"
    elif state.Value >= 50.0 then "gauge degraded"
    else "gauge critical"

let healthGaugeText (state: HealthGaugeState) =
    if state.ShowPercentage then
        sprintf "%.0f%%" state.Value
    else
        state.Label

[<Tests>]
let healthGaugeTests =
    testList "HealthGauge" [
        test "should have healthy class for >=90%" {
            let state = { Value = 95.0; Label = "Health"; ShowPercentage = true }
            let cls = healthGaugeClass state
            Expect.stringContains cls "healthy" "Should have healthy class"
        }

        test "should have warning class for 70-89%" {
            let state = { Value = 75.0; Label = "Health"; ShowPercentage = true }
            let cls = healthGaugeClass state
            Expect.stringContains cls "warning" "Should have warning class"
        }

        test "should have degraded class for 50-69%" {
            let state = { Value = 55.0; Label = "Health"; ShowPercentage = true }
            let cls = healthGaugeClass state
            Expect.stringContains cls "degraded" "Should have degraded class"
        }

        test "should have critical class for <50%" {
            let state = { Value = 30.0; Label = "Health"; ShowPercentage = true }
            let cls = healthGaugeClass state
            Expect.stringContains cls "critical" "Should have critical class"
        }

        test "should display percentage when enabled" {
            let state = { Value = 85.0; Label = "Health"; ShowPercentage = true }
            let text = healthGaugeText state
            Expect.equal text "85%" "Should show percentage"
        }

        test "should display label when percentage disabled" {
            let state = { Value = 85.0; Label = "System Health"; ShowPercentage = false }
            let text = healthGaugeText state
            Expect.equal text "System Health" "Should show label"
        }
    ]

// ============================================================================
// Alarm Card Component Tests
// ============================================================================

type AlarmLevel =
    | Info
    | Warning
    | Critical

type AlarmCardState = {
    Id: string
    Level: AlarmLevel
    Message: string
    NodeId: string
    OccurredAt: DateTime
    IsAcknowledged: bool
}

let alarmCardClass (state: AlarmCardState) =
    let levelClass =
        match state.Level with
        | Info -> "info"
        | Warning -> "warning"
        | Critical -> "critical"
    let ackClass = if state.IsAcknowledged then " acknowledged" else ""
    sprintf "alarm-card %s%s" levelClass ackClass

let alarmLevelAbbrev level =
    match level with
    | Info -> "INFO"
    | Warning -> "WARN"
    | Critical -> "CRIT"

[<Tests>]
let alarmCardTests =
    testList "AlarmCard" [
        test "should have critical class for critical alarm" {
            let state = {
                Id = "alarm-1"
                Level = Critical
                Message = "CPU overload"
                NodeId = "node-1"
                OccurredAt = DateTime.UtcNow
                IsAcknowledged = false
            }
            let cls = alarmCardClass state
            Expect.stringContains cls "critical" "Should have critical class"
        }

        test "should have acknowledged class when acked" {
            let state = {
                Id = "alarm-2"
                Level = Warning
                Message = "Memory high"
                NodeId = "node-1"
                OccurredAt = DateTime.UtcNow
                IsAcknowledged = true
            }
            let cls = alarmCardClass state
            Expect.stringContains cls "acknowledged" "Should have acknowledged class"
        }

        test "should not have acknowledged class when not acked" {
            let state = {
                Id = "alarm-3"
                Level = Warning
                Message = "Memory high"
                NodeId = "node-1"
                OccurredAt = DateTime.UtcNow
                IsAcknowledged = false
            }
            let cls = alarmCardClass state
            Expect.isFalse (cls.Contains("acknowledged")) "Should not have acknowledged class"
        }

        test "should format level abbreviation" {
            Expect.equal (alarmLevelAbbrev Critical) "CRIT" "Critical should be CRIT"
            Expect.equal (alarmLevelAbbrev Warning) "WARN" "Warning should be WARN"
            Expect.equal (alarmLevelAbbrev Info) "INFO" "Info should be INFO"
        }
    ]

// ============================================================================
// Proposal Card Component Tests
// ============================================================================

type ProposalSeverity =
    | Low
    | Medium
    | High
    | Critical

type ProposalCardState = {
    Id: string
    Title: string
    Description: string
    Category: string
    Severity: ProposalSeverity
    Votes: int
    RequiredVotes: int
}

let proposalProgress (state: ProposalCardState) =
    if state.RequiredVotes = 0 then 0.0
    else float state.Votes / float state.RequiredVotes * 100.0

let canApprove (state: ProposalCardState) =
    state.Votes >= state.RequiredVotes

let proposalCardClass (state: ProposalCardState) =
    let severityClass =
        match state.Severity with
        | Low -> "low"
        | Medium -> "medium"
        | High -> "high"
        | Critical -> "critical"
    sprintf "proposal-card %s" severityClass

[<Tests>]
let proposalCardTests =
    testList "ProposalCard" [
        test "should calculate progress percentage" {
            let state = {
                Id = "prop-1"
                Title = "Test"
                Description = ""
                Category = ""
                Severity = Medium
                Votes = 2
                RequiredVotes = 4
            }
            let progress = proposalProgress state
            Expect.floatClose Accuracy.medium progress 50.0 "Should be 50%"
        }

        test "should be approvable when votes >= required" {
            let state = {
                Id = "prop-2"
                Title = "Test"
                Description = ""
                Category = ""
                Severity = Low
                Votes = 3
                RequiredVotes = 3
            }
            Expect.isTrue (canApprove state) "Should be approvable"
        }

        test "should not be approvable when votes < required" {
            let state = {
                Id = "prop-3"
                Title = "Test"
                Description = ""
                Category = ""
                Severity = Low
                Votes = 1
                RequiredVotes = 3
            }
            Expect.isFalse (canApprove state) "Should not be approvable"
        }

        test "should have correct severity class" {
            let state = {
                Id = "prop-4"
                Title = "Test"
                Description = ""
                Category = ""
                Severity = Critical
                Votes = 0
                RequiredVotes = 3
            }
            let cls = proposalCardClass state
            Expect.stringContains cls "critical" "Should have critical class"
        }
    ]

// ============================================================================
// Threat Card Component Tests
// ============================================================================

type ThreatSeverity =
    | Low
    | Medium
    | High
    | Critical

type ThreatCardState = {
    Id: string
    Category: string
    Description: string
    Source: string
    Severity: ThreatSeverity
    IsMitigated: bool
}

let calculateRPN (severity: ThreatSeverity) (occurrence: int) (detection: int) =
    let severityScore =
        match severity with
        | Low -> 1
        | Medium -> 4
        | High -> 7
        | Critical -> 10
    severityScore * occurrence * detection

let threatCardClass (state: ThreatCardState) =
    let severityClass =
        match state.Severity with
        | Low -> "low"
        | Medium -> "medium"
        | High -> "high"
        | Critical -> "critical"
    let mitigatedClass = if state.IsMitigated then " mitigated" else ""
    sprintf "threat-card %s%s" severityClass mitigatedClass

[<Tests>]
let threatCardTests =
    testList "ThreatCard" [
        test "should calculate RPN correctly" {
            let rpn = calculateRPN Critical 8 5
            Expect.equal rpn 400 "RPN should be 400"
        }

        test "should have mitigated class when mitigated" {
            let state = {
                Id = "threat-1"
                Category = "Security"
                Description = "Test threat"
                Source = "unknown"
                Severity = High
                IsMitigated = true
            }
            let cls = threatCardClass state
            Expect.stringContains cls "mitigated" "Should have mitigated class"
        }

        test "should not have mitigated class when active" {
            let state = {
                Id = "threat-2"
                Category = "Security"
                Description = "Test threat"
                Source = "unknown"
                Severity = High
                IsMitigated = false
            }
            let cls = threatCardClass state
            Expect.isFalse (cls.Contains("mitigated")) "Should not have mitigated class"
        }
    ]

// ============================================================================
// Device Card Component Tests
// ============================================================================

type DeviceStatus =
    | Online
    | Offline
    | Maintenance
    | Unknown

type DeviceCardState = {
    Id: string
    Name: string
    Status: DeviceStatus
    Health: float
    LastSeen: DateTime
}

let deviceStatusIcon (status: DeviceStatus) =
    match status with
    | Online -> "●"
    | Offline -> "○"
    | Maintenance -> "◐"
    | Unknown -> "?"

let deviceCardClass (state: DeviceCardState) =
    let statusClass =
        match state.Status with
        | Online -> "online"
        | Offline -> "offline"
        | Maintenance -> "maintenance"
        | Unknown -> "unknown"
    sprintf "device-card %s" statusClass

let isDeviceStale (state: DeviceCardState) (threshold: TimeSpan) =
    DateTime.UtcNow - state.LastSeen > threshold

[<Tests>]
let deviceCardTests =
    testList "DeviceCard" [
        test "should show correct status icon" {
            Expect.equal (deviceStatusIcon Online) "●" "Online should be filled circle"
            Expect.equal (deviceStatusIcon Offline) "○" "Offline should be empty circle"
            Expect.equal (deviceStatusIcon Maintenance) "◐" "Maintenance should be half circle"
        }

        test "should have correct status class" {
            let state = {
                Id = "dev-1"
                Name = "Camera-1"
                Status = Online
                Health = 95.0
                LastSeen = DateTime.UtcNow
            }
            let cls = deviceCardClass state
            Expect.stringContains cls "online" "Should have online class"
        }

        test "should detect stale device" {
            let state = {
                Id = "dev-2"
                Name = "Camera-2"
                Status = Online
                Health = 95.0
                LastSeen = DateTime.UtcNow.AddMinutes(-10.0)
            }
            let isStale = isDeviceStale state (TimeSpan.FromMinutes(5.0))
            Expect.isTrue isStale "Should be stale after 5 minutes"
        }

        test "should not be stale within threshold" {
            let state = {
                Id = "dev-3"
                Name = "Camera-3"
                Status = Online
                Health = 95.0
                LastSeen = DateTime.UtcNow.AddMinutes(-2.0)
            }
            let isStale = isDeviceStale state (TimeSpan.FromMinutes(5.0))
            Expect.isFalse isStale "Should not be stale within 5 minutes"
        }
    ]

// ============================================================================
// Badge Component Tests
// ============================================================================

type BadgeVariant =
    | Primary
    | Success
    | Warning
    | Danger
    | Info

let badgeClass (variant: BadgeVariant) (count: int) =
    let variantClass =
        match variant with
        | Primary -> "primary"
        | Success -> "success"
        | Warning -> "warning"
        | Danger -> "danger"
        | Info -> "info"
    let pulseClass = if count > 0 then " pulse" else ""
    sprintf "badge %s%s" variantClass pulseClass

[<Tests>]
let badgeTests =
    testList "Badge" [
        test "should have pulse class when count > 0" {
            let cls = badgeClass Danger 5
            Expect.stringContains cls "pulse" "Should pulse when count > 0"
        }

        test "should not pulse when count = 0" {
            let cls = badgeClass Warning 0
            Expect.isFalse (cls.Contains("pulse")) "Should not pulse when count = 0"
        }

        test "should have correct variant class" {
            let cls = badgeClass Success 1
            Expect.stringContains cls "success" "Should have success class"
        }
    ]
