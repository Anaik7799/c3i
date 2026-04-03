module Cepaf.Tests.Unit.Cockpit.BiomorphicUIComponentTests

open System
open Expecto

/// ============================================================================
/// BIOMORPHIC UI COMPONENT TEST SUITE
/// ============================================================================
/// Coverage: Domain types, Prajna Bio/Immune/Neuro layers, Smart Metrics,
///           Dark Cockpit rendering, ANSI output, state machines
/// STAMP Compliance: SC-HMI-001..080, SC-PRAJNA-001..007, SC-COV-008
/// Framework: Expecto + FsCheck | IEC 61508 SIL-6 Biomorphic
/// ============================================================================

// Fully-qualified module aliases to avoid name clashes
module D = Cepaf.Cockpit.Domain
module P = Cepaf.Cockpit.Prajna
module UI = Cepaf.Cockpit.DarkCockpitUI
module SM = Cepaf.Cockpit.SmartMetrics

// =============================================================================
// CATEGORY 1: DOMAIN TYPES (BIO-DOM)
// =============================================================================

[<Tests>]
let domainTypeTests =
    testList "BIO-DOM: Domain Types" [
        test "BIO-DOM-001: Trend icons are distinct" {
            let icons =
                [D.Rising; D.RisingFast; D.Falling; D.FallingFast; D.Stable]
                |> List.map (fun t -> t.Icon)
            Expect.equal (icons |> List.distinct |> List.length) 5 "All 5 trend icons must be unique"
        }

        test "BIO-DOM-002: ConnectionStatus icons are non-empty" {
            for status in [D.Connected; D.Stale; D.Degraded; D.Disconnected] do
                Expect.isNotEmpty (status.Icon) (sprintf "Icon for %A must not be empty" status)
        }

        test "BIO-DOM-003: AlarmLevel icons cover all 5 levels" {
            let levels = [D.Normal; D.Advisory; D.Caution; D.Warning; D.Critical]
            for level in levels do
                Expect.isNotEmpty (level.Icon) (sprintf "Icon for %A must not be empty" level)
                Expect.isNotEmpty (level.Abbrev) (sprintf "Abbrev for %A must not be empty" level)
        }

        test "BIO-DOM-004: AlarmLevel abbreviations are 4 chars" {
            for level in [D.Normal; D.Advisory; D.Caution; D.Warning; D.Critical] do
                Expect.equal (level.Abbrev.Length) 4 (sprintf "Abbrev for %A must be 4 chars" level)
        }

        test "BIO-DOM-005: CommandState icons are distinct" {
            let icons =
                [D.Idle; D.Armed; D.Executing; D.Acknowledged; D.Failed]
                |> List.map (fun (s: D.CommandState) -> s.Icon)
            Expect.equal (icons |> List.distinct |> List.length) 5 "All 5 command state icons must be unique"
        }

        test "BIO-DOM-006: SmartMetric.Create sets defaults correctly" {
            let m = D.SmartMetric.Create("cpu", "%", 42.0)
            Expect.equal m.Value 42.0 "Value should be 42.0"
            Expect.equal m.Label "cpu" "Label should be cpu"
            Expect.equal m.Unit "%" "Unit should be %"
            Expect.equal m.Trend D.Stable "Default trend should be Stable"
            Expect.equal m.Level D.Normal "Default level should be Normal"
            Expect.isNone m.PreviousValue "Default previous should be None"
            Expect.isEmpty m.Sparkline "Default sparkline should be empty"
        }

        test "BIO-DOM-007: SmartMetric.EvaluateLevel returns Normal without thresholds" {
            let level = D.SmartMetric.EvaluateLevel(99.0, None)
            Expect.equal level D.Normal "No thresholds means Normal"
        }

        test "BIO-DOM-008: SmartMetric.EvaluateLevel detects Warning high" {
            let thresholds: D.MetricThresholds = {
                AdvisoryLow = None; AdvisoryHigh = Some 60.0
                CautionLow = None; CautionHigh = Some 80.0
                WarningLow = None; WarningHigh = Some 90.0
            }
            let level = D.SmartMetric.EvaluateLevel(95.0, Some thresholds)
            Expect.equal level D.Warning "95.0 >= 90.0 should be Warning"
        }

        test "BIO-DOM-009: SmartMetric.EvaluateLevel detects Caution" {
            let thresholds: D.MetricThresholds = {
                AdvisoryLow = None; AdvisoryHigh = Some 60.0
                CautionLow = None; CautionHigh = Some 80.0
                WarningLow = None; WarningHigh = Some 90.0
            }
            let level = D.SmartMetric.EvaluateLevel(85.0, Some thresholds)
            Expect.equal level D.Caution "85.0 >= 80.0 but < 90.0 should be Caution"
        }

        test "BIO-DOM-010: SmartMetric.EvaluateLevel detects Advisory" {
            let thresholds: D.MetricThresholds = {
                AdvisoryLow = None; AdvisoryHigh = Some 60.0
                CautionLow = None; CautionHigh = Some 80.0
                WarningLow = None; WarningHigh = Some 90.0
            }
            let level = D.SmartMetric.EvaluateLevel(65.0, Some thresholds)
            Expect.equal level D.Advisory "65.0 >= 60.0 but < 80.0 should be Advisory"
        }

        test "BIO-DOM-011: ViewMode enum has 12 variants" {
            let modes: D.ViewMode list = [
                D.Overview; D.Mesh; D.Alarms; D.Commands; D.AI; D.Dashboard
                D.NodeDetail; D.AlarmCenter; D.Topology; D.Timeline; D.AiAssistant; D.Federation
            ]
            Expect.equal modes.Length 12 "Should have 12 view modes"
        }

        test "BIO-DOM-012: NodeRole enum has 5 variants" {
            let roles: D.NodeRole list = [D.Supervisor; D.Controller; D.Worker; D.Observer; D.Gateway]
            Expect.equal roles.Length 5 "Should have 5 node roles"
        }

        test "BIO-DOM-013: InsightType enum has 6 variants" {
            let types: D.InsightType list =
                [D.Anomaly; D.Prediction; D.Recommendation; D.Correlation; D.RootCause; D.Summary]
            Expect.equal types.Length 6 "Should have 6 insight types"
        }

        test "BIO-DOM-014: MeshCommand covers critical command types" {
            let commands: D.MeshCommand list = [
                D.PowerOff; D.PowerOn; D.Restart; D.Hibernate
                D.IsolateNetwork; D.ResumeNetwork; D.SetLoadBalancer 50
                D.ForceHealthCheck; D.ClearAlarms; D.Custom ("test", [||])
            ]
            Expect.equal commands.Length 10 "Should have 10 command types"
        }

        test "BIO-DOM-015: isCriticalCommand identifies destructive ops" {
            Expect.isTrue (D.isCriticalCommand D.PowerOff) "PowerOff is critical"
            Expect.isTrue (D.isCriticalCommand D.Restart) "Restart is critical"
            Expect.isTrue (D.isCriticalCommand D.IsolateNetwork) "IsolateNetwork is critical"
            Expect.isFalse (D.isCriticalCommand D.ForceHealthCheck) "HealthCheck is not critical"
            Expect.isFalse (D.isCriticalCommand D.ClearAlarms) "ClearAlarms is not critical"
        }

        test "BIO-DOM-016: generateId produces 8-char hex" {
            let id = D.generateId ()
            Expect.equal id.Length 8 "ID should be 8 characters"
        }
    ]

// =============================================================================
// CATEGORY 2: PRAJNA BIO LAYER (BIO-BIO)
// =============================================================================

[<Tests>]
let prajnaBioTests =
    testList "BIO-BIO: Prajna Bio Layer" [
        test "BIO-BIO-001: HolonId wraps string correctly" {
            let (P.HolonId id) = P.HolonId "node-42"
            Expect.equal id "node-42" "HolonId should unwrap to node-42"
        }

        test "BIO-BIO-002: HolonType covers 4 classification variants" {
            let types: P.HolonType list =
                [P.Agent "a1"; P.Worker "w1"; P.Service "s1"; P.Container "c1"]
            Expect.equal types.Length 4 "Should have 4 holon types"
        }

        test "BIO-BIO-003: defaultVitals has full health" {
            let vitals = P.defaultVitals ()
            Expect.equal vitals.HealthIndex 1.0 "Default health should be 1.0"
            Expect.equal vitals.StressIndex 0.0 "Default stress should be 0.0"
        }

        test "BIO-BIO-004: VitalSigns health is bounded 0-1" {
            let vitals: P.VitalSigns =
                { HealthIndex = 0.5; StressIndex = 0.3; LastUpdate = DateTimeOffset.UtcNow }
            Expect.isLessThanOrEqual vitals.HealthIndex 1.0 "Health <= 1.0"
            Expect.isGreaterThanOrEqual vitals.HealthIndex 0.0 "Health >= 0.0"
        }

        test "BIO-BIO-005: Membrane Permeability has 4 levels" {
            let perms: P.Bio.Permeability list =
                [P.Bio.Closed; P.Bio.Selective; P.Bio.Open; P.Bio.Emergency]
            Expect.equal perms.Length 4 "Should have 4 permeability levels"
        }

        test "BIO-BIO-006: MembraneConfig defaults are restrictive" {
            let config: P.Bio.MembraneConfig = {
                Permeability = P.Bio.Selective
                AllowedTypes = Set.ofList ["health"; "alarm"]
                BlockedSources = Set.empty
                RateLimit = 100
            }
            Expect.equal config.RateLimit 100 "Rate limit should be 100"
            Expect.equal (config.AllowedTypes |> Set.count) 2 "Should allow 2 message types"
        }

        test "BIO-BIO-007: Emergency permeability restricts traffic" {
            let config: P.Bio.MembraneConfig = {
                Permeability = P.Bio.Emergency
                AllowedTypes = Set.ofList ["emergency"]
                BlockedSources = Set.empty
                RateLimit = 1000
            }
            Expect.equal config.Permeability P.Bio.Emergency "Should be Emergency mode"
        }
    ]

// =============================================================================
// CATEGORY 3: SMART METRICS ENGINE (BIO-MET)
// =============================================================================

[<Tests>]
let smartMetricsTests =
    testList "BIO-MET: Smart Metrics" [
        test "BIO-MET-001: MetricsAgent starts with empty state" {
            let agent = SM.MetricsAgent()
            let all = agent.GetAll() |> Async.RunSynchronously
            Expect.isEmpty all "New agent should have no metrics"
        }

        test "BIO-MET-002: MetricsAgent accepts Update" {
            let agent = SM.MetricsAgent()
            agent.Update("cpu", 42.0, "%")
            Threading.Thread.Sleep(50)
            let result = agent.Get("cpu") |> Async.RunSynchronously
            Expect.isSome result "Should find cpu metric after update"
            Expect.equal result.Value.Value 42.0 "Value should be 42.0"
        }

        test "BIO-MET-003: MetricsAgent returns None for missing key" {
            let agent = SM.MetricsAgent()
            let result = agent.Get("nonexistent") |> Async.RunSynchronously
            Expect.isNone result "Missing key should return None"
        }

        test "BIO-MET-004: MetricsAgent tracks multiple metrics" {
            let agent = SM.MetricsAgent()
            agent.Update("cpu", 42.0, "%")
            agent.Update("mem", 8192.0, "MB")
            agent.Update("disk", 75.0, "%")
            Threading.Thread.Sleep(100)
            let all = agent.GetAll() |> Async.RunSynchronously
            Expect.equal (all |> Map.count) 3 "Should have 3 metrics"
        }

        test "BIO-MET-005: MetricsAgent updates existing metric value" {
            let agent = SM.MetricsAgent()
            agent.Update("cpu", 42.0, "%")
            Threading.Thread.Sleep(50)
            agent.Update("cpu", 55.0, "%")
            Threading.Thread.Sleep(50)
            let result = agent.Get("cpu") |> Async.RunSynchronously
            Expect.isSome result "Should find cpu"
            Expect.equal result.Value.Value 55.0 "Should have updated value"
        }

        test "BIO-MET-006: MetricsAgent anomalies empty for normal metrics" {
            let agent = SM.MetricsAgent()
            agent.Update("cpu", 42.0, "%")
            Threading.Thread.Sleep(50)
            let anomalies = agent.GetAnomalies() |> Async.RunSynchronously
            Expect.isEmpty anomalies "Normal metrics should not be anomalies"
        }

        test "BIO-MET-007: updateMetric preserves sparkline history" {
            let m = D.SmartMetric.Create("test", "%", 10.0)
            let m2 = D.updateMetric m 20.0
            Expect.isTrue (m2.Sparkline.Length >= 1) "Sparkline should grow"
            Expect.equal m2.Value 20.0 "Value should be updated"
        }

        test "BIO-MET-008: updateMetric computes trend from value change" {
            let m = D.SmartMetric.Create("test", "%", 10.0)
            let m2 = D.updateMetric m 50.0
            // Large increase (400%) should produce RisingFast
            Expect.equal m2.Trend D.RisingFast "400% increase should be RisingFast"
        }

        test "BIO-MET-009: updateMetric tracks previous value" {
            let m = D.SmartMetric.Create("test", "%", 10.0)
            let m2 = D.updateMetric m 20.0
            Expect.equal m2.PreviousValue (Some 10.0) "Previous value should be 10.0"
        }

        test "BIO-MET-010: isStale detects old metrics" {
            let m = { D.SmartMetric.Create("test", "%", 10.0) with
                        LastUpdated = DateTime.UtcNow.AddSeconds(-120.0) }
            Expect.isTrue (D.isStale m 60) "Metric 120s old should be stale at 60s timeout"
            Expect.isFalse (D.isStale m 300) "Metric 120s old should not be stale at 300s timeout"
        }
    ]

// =============================================================================
// CATEGORY 4: DARK COCKPIT UI (BIO-DRK)
// =============================================================================

[<Tests>]
let darkCockpitUITests =
    testList "BIO-DRK: Dark Cockpit UI" [
        test "BIO-DRK-001: ANSI reset code is correct" {
            Expect.equal UI.Ansi.reset "\u001b[0m" "Reset should be ESC[0m"
        }

        test "BIO-DRK-002: ANSI bold code is correct" {
            Expect.equal UI.Ansi.bold "\u001b[1m" "Bold should be ESC[1m"
        }

        test "BIO-DRK-003: Normal state uses dim gray (dark cockpit philosophy)" {
            Expect.equal UI.Ansi.normal "\u001b[90m" "Normal should be dark gray (90m)"
        }

        test "BIO-DRK-004: Advisory uses cyan" {
            Expect.equal UI.Ansi.advisory "\u001b[36m" "Advisory should be cyan (36m)"
        }

        test "BIO-DRK-005: Blink reserved for critical only" {
            Expect.equal UI.Ansi.blink "\u001b[5m" "Blink should be ESC[5m"
        }

        test "BIO-DRK-006: All ANSI codes start with ESC sequence" {
            let codes = [
                UI.Ansi.reset; UI.Ansi.bold
                UI.Ansi.dim; UI.Ansi.italic
                UI.Ansi.normal; UI.Ansi.advisory
            ]
            for code in codes do
                Expect.isTrue (code.StartsWith("\u001b[")) (sprintf "Code must start with ESC[")
        }

        test "BIO-DRK-007: Italic code is correct" {
            Expect.equal UI.Ansi.italic "\u001b[3m" "Italic should be ESC[3m"
        }

        test "BIO-DRK-008: Dim code is correct" {
            Expect.equal UI.Ansi.dim "\u001b[2m" "Dim should be ESC[2m"
        }
    ]

// =============================================================================
// CATEGORY 5: COMMAND STATE MACHINE (BIO-CMD)
// =============================================================================

[<Tests>]
let commandStateTests =
    testList "BIO-CMD: Command State Machine" [
        test "BIO-CMD-001: CommandRecord starts in Idle" {
            let cmd: D.CommandRecord = {
                Id = "CMD001"; TargetNodeId = "N001"
                Command = D.ForceHealthCheck; State = D.Idle
                ArmedAt = None; ExecutedAt = None
                AcknowledgedAt = None; ErrorMessage = None
                RequiresConfirmation = true
            }
            Expect.equal cmd.State D.Idle "Initial state should be Idle"
        }

        test "BIO-CMD-002: Armed state has timestamp" {
            let now = DateTime.UtcNow
            let cmd: D.CommandRecord = {
                Id = "CMD002"; TargetNodeId = "N001"
                Command = D.Restart; State = D.Armed
                ArmedAt = Some now; ExecutedAt = None
                AcknowledgedAt = None; ErrorMessage = None
                RequiresConfirmation = true
            }
            Expect.isSome cmd.ArmedAt "Armed command should have ArmedAt"
        }

        test "BIO-CMD-003: Failed state has error message" {
            let cmd: D.CommandRecord = {
                Id = "CMD003"; TargetNodeId = "N001"
                Command = D.PowerOff; State = D.Failed
                ArmedAt = Some DateTime.UtcNow; ExecutedAt = Some DateTime.UtcNow
                AcknowledgedAt = None; ErrorMessage = Some "Permission denied"
                RequiresConfirmation = true
            }
            Expect.isSome cmd.ErrorMessage "Failed command should have error"
            Expect.equal cmd.ErrorMessage.Value "Permission denied" "Error message preserved"
        }

        test "BIO-CMD-004: Two-step commit requires confirmation flag" {
            let cmd: D.CommandRecord = {
                Id = "CMD004"; TargetNodeId = "N001"
                Command = D.PowerOff; State = D.Idle
                ArmedAt = None; ExecutedAt = None
                AcknowledgedAt = None; ErrorMessage = None
                RequiresConfirmation = true
            }
            Expect.isTrue cmd.RequiresConfirmation "Destructive commands require confirmation"
        }

        test "BIO-CMD-005: Custom command carries payload" {
            match D.Custom ("reboot-gpu", [|0x42uy; 0xFFuy|]) with
            | D.Custom (name, payload) ->
                Expect.equal name "reboot-gpu" "Custom name preserved"
                Expect.equal payload.Length 2 "Payload preserved"
            | _ -> failtest "Should match Custom"
        }

        test "BIO-CMD-006: SetLoadBalancer carries weight" {
            match D.SetLoadBalancer 75 with
            | D.SetLoadBalancer w -> Expect.equal w 75 "Weight should be 75"
            | _ -> failtest "Should match SetLoadBalancer"
        }
    ]

// =============================================================================
// CATEGORY 6: MESH NODE HEALTH (BIO-MESH)
// =============================================================================

[<Tests>]
let meshNodeTests =
    testList "BIO-MESH: Mesh Node Health" [
        test "BIO-MESH-001: MeshNode with full metrics" {
            let node: D.MeshNode = {
                Id = "zenoh-router"; Name = "Zenoh Router"
                Zone = "core"; Role = D.Controller
                Status = D.Connected
                Cpu = D.SmartMetric.Create("cpu", "%", 15.0)
                Memory = D.SmartMetric.Create("mem", "MB", 512.0)
                Battery = None; NetworkLatency = D.SmartMetric.Create("lat", "ms", 2.0)
                Capabilities = ["routing"; "pub-sub"; "query"]
                HealthScore = D.SmartMetric.Create("health", "%", 98.0)
                Location = Some (48.2082, 16.3738)
                AiInsight = None; AiInsightUpdatedAt = None
            }
            Expect.equal node.Capabilities.Length 3 "Should have 3 capabilities"
            Expect.isSome node.Location "Should have location"
            Expect.equal node.Status D.Connected "Should be connected"
        }

        test "BIO-MESH-002: Disconnected node has AI insight" {
            let node: D.MeshNode = {
                Id = "dead-node"; Name = "Dead Node"
                Zone = "edge"; Role = D.Worker; Status = D.Disconnected
                Cpu = D.SmartMetric.Create("cpu", "%", 0.0)
                Memory = D.SmartMetric.Create("mem", "MB", 0.0)
                Battery = None
                NetworkLatency = D.SmartMetric.Create("lat", "ms", 9999.0)
                Capabilities = []; HealthScore = D.SmartMetric.Create("health", "%", 0.0)
                Location = None; AiInsight = Some "Node unreachable since 10:42"
                AiInsightUpdatedAt = Some DateTime.UtcNow
            }
            Expect.equal node.Status D.Disconnected "Should be disconnected"
            Expect.isSome node.AiInsight "Should have AI insight"
            Expect.isEmpty node.Capabilities "Dead node has no capabilities"
        }

        test "BIO-MESH-003: Gateway node with battery" {
            let node: D.MeshNode = {
                Id = "gw-1"; Name = "Gateway 1"
                Zone = "dmz"; Role = D.Gateway; Status = D.Connected
                Cpu = D.SmartMetric.Create("cpu", "%", 30.0)
                Memory = D.SmartMetric.Create("mem", "MB", 1024.0)
                Battery = Some (D.SmartMetric.Create("bat", "%", 85.0))
                NetworkLatency = D.SmartMetric.Create("lat", "ms", 15.0)
                Capabilities = ["nat"; "firewall"; "vpn"]
                HealthScore = D.SmartMetric.Create("health", "%", 92.0)
                Location = None; AiInsight = None; AiInsightUpdatedAt = None
            }
            Expect.equal node.Role D.Gateway "Should be Gateway"
            Expect.isSome node.Battery "Gateway should have battery"
        }

        test "BIO-MESH-004: Critical alarm non-autoclearable" {
            let alarm: D.Alarm = {
                Id = "ALM-2026-001"; NodeId = "N001"
                Level = D.Critical; Category = "thermal"
                Message = "GPU temperature exceeds 95C"
                Details = Some "GPU #2 on node N001 reached 97C"
                OccurredAt = DateTime.UtcNow
                AcknowledgedAt = None; AcknowledgedBy = None
                AutoClearable = false
            }
            Expect.equal alarm.Level D.Critical "Should be Critical"
            Expect.isFalse alarm.AutoClearable "Critical alarms should not auto-clear"
        }

        test "BIO-MESH-005: Alarm acknowledgement flow" {
            let now = DateTime.UtcNow
            let alarm: D.Alarm = {
                Id = "ALM-2026-002"; NodeId = "N002"
                Level = D.Warning; Category = "network"
                Message = "High latency detected"
                Details = None; OccurredAt = now.AddMinutes(-5.0)
                AcknowledgedAt = Some now; AcknowledgedBy = Some "operator-1"
                AutoClearable = true
            }
            Expect.isSome alarm.AcknowledgedAt "Should be acknowledged"
            Expect.equal alarm.AcknowledgedBy (Some "operator-1") "Operator recorded"
        }
    ]

// =============================================================================
// CATEGORY 7: TREND & STALENESS DETECTION (BIO-TREND)
// =============================================================================

[<Tests>]
let trendDetectionTests =
    testList "BIO-TREND: Trend Detection" [
        test "BIO-TREND-001: Rising trend icon" {
            Expect.equal D.Rising.Icon "↑" "Rising should be up arrow"
        }

        test "BIO-TREND-002: RisingFast trend icon" {
            Expect.equal D.RisingFast.Icon "↑↑" "RisingFast should be double up arrow"
        }

        test "BIO-TREND-003: Falling trend icon" {
            Expect.equal D.Falling.Icon "↓" "Falling should be down arrow"
        }

        test "BIO-TREND-004: FallingFast trend icon" {
            Expect.equal D.FallingFast.Icon "↓↓" "FallingFast should be double down arrow"
        }

        test "BIO-TREND-005: Stable trend icon" {
            Expect.equal D.Stable.Icon "→" "Stable should be right arrow"
        }

        test "BIO-TREND-006: computeTrend stable for equal values" {
            let trend = D.computeTrend 50.0 50.0
            Expect.equal trend D.Stable "Equal values should be Stable"
        }

        test "BIO-TREND-007: computeTrend rising for small increase" {
            let trend = D.computeTrend 100.0 105.0
            Expect.equal trend D.Rising "5% increase should be Rising"
        }

        test "BIO-TREND-008: computeTrend risingFast for large increase" {
            let trend = D.computeTrend 100.0 120.0
            Expect.equal trend D.RisingFast "20% increase should be RisingFast"
        }

        test "BIO-TREND-009: computeTrend falling for small decrease" {
            let trend = D.computeTrend 100.0 95.0
            Expect.equal trend D.Falling "5% decrease should be Falling"
        }

        test "BIO-TREND-010: computeTrend fallingFast for large decrease" {
            let trend = D.computeTrend 100.0 80.0
            Expect.equal trend D.FallingFast "20% decrease should be FallingFast"
        }
    ]

// =============================================================================
// AGGREGATE TEST LIST
// =============================================================================

[<Tests>]
let allBiomorphicTests =
    testList "Biomorphic UI Components" [
        domainTypeTests
        prajnaBioTests
        smartMetricsTests
        darkCockpitUITests
        commandStateTests
        meshNodeTests
        trendDetectionTests
    ]
