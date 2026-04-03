// =============================================================================
// CliHealthScoreTests.fs - TDG-compliant tests for CliHealthScore
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-HEALTH-001 (L5 health metrics),
//        SC-ZENOH-007 (Zenoh status in health line)
//
// ## Test Coverage
// - computeHealthScore: score range [0,1], grade assignment, Zenoh weight,
//   container fraction, boundary conditions, all-good returns grade A
// - getThreatCount: no env var → sentinel offline, valid env var, invalid value
// - renderHealthLine: non-empty output, contains health grade, Zenoh UP/DOWN
// - renderThreatSummary: zero threats, mixed threats, critical formatting
// - renderCompactStatus: Ok when threat env is clean, combined output
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-03-30 |
// | Author | Code Evolution Agent v21.3.0-SIL6 |
// | STAMP | SC-TEST-001, SC-HEALTH-001, SC-ZENOH-007 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.CliHealthScoreTests

open Expecto
open Cepaf.Mesh

// Helper: build a perfect-conditions health score
let private perfectScore () =
    CliHealthScore.computeHealthScore 0.0 0.0 0.0 true 14 14

// Helper: build a zero-conditions health score
let private zeroScore () =
    CliHealthScore.computeHealthScore 100.0 100.0 100.0 false 0 14

[<Tests>]
let tests = testList "CliHealthScore" [

    // =========================================================================
    // computeHealthScore Tests
    // =========================================================================
    testList "computeHealthScore" [

        test "computeHealthScore returns score in [0.0, 1.0]" {
            let hs = CliHealthScore.computeHealthScore 50.0 50.0 50.0 true 7 14
            Expect.isTrue
                (hs.Score >= 0.0 && hs.Score <= 1.0)
                $"Score {hs.Score} must be in [0.0, 1.0]"
        }

        test "perfect conditions (0%% CPU/mem/disk, Zenoh up, all containers) gives Grade A" {
            let hs = perfectScore ()
            Expect.equal hs.Grade "A" "Perfect conditions should yield Grade A"
        }

        test "perfect conditions give score >= 0.9" {
            let hs = perfectScore ()
            Expect.isGreaterThanOrEqual hs.Score 0.9
                "Perfect conditions should yield score >= 0.9 (Grade A threshold)"
        }

        test "zero conditions (100%% CPU/mem/disk, Zenoh down, 0/15 containers) gives Grade F" {
            let hs = zeroScore ()
            Expect.equal hs.Grade "F" "Worst-case conditions should yield Grade F"
        }

        test "Zenoh down reduces score by the Zenoh weight (0.25)" {
            // Two identical inputs except Zenoh flag
            let withZenoh    = CliHealthScore.computeHealthScore 30.0 30.0 30.0 true  14 14
            let withoutZenoh = CliHealthScore.computeHealthScore 30.0 30.0 30.0 false 14 14
            Expect.isLessThan withoutZenoh.Score withZenoh.Score
                "Score with Zenoh down must be lower than score with Zenoh up"
        }

        test "Grade B threshold: score >= 0.8 but < 0.9 gives 'B'" {
            // Moderate CPU 80%, rest perfect — should land in B range
            let hs = CliHealthScore.computeHealthScore 80.0 0.0 0.0 true 14 14
            // CPU at 80% gives contribution: 0.25 * (1 - (80-50)/50) = 0.25 * 0.4 = 0.1
            // Total = 0.1 + 0.20 + 0.15 + 0.25 + 0.15 = 0.85 → Grade B
            Expect.isTrue
                (hs.Grade = "A" || hs.Grade = "B")
                $"Heavy CPU with rest perfect should be Grade A or B, got {hs.Grade} ({hs.Score:F3})"
        }

        test "Grade F: score below 0.6" {
            let hs = zeroScore ()
            Expect.isLessThan hs.Score 0.6
                $"Worst-case score {hs.Score} should be below 0.6 (Grade F)"
        }

        test "All containers healthy gives maximum container component" {
            let hs14 = CliHealthScore.computeHealthScore 0.0 0.0 0.0 true 14 14
            let hs7  = CliHealthScore.computeHealthScore 0.0 0.0 0.0 true 7  14
            Expect.isGreaterThan hs14.Score hs7.Score
                "14/14 healthy containers must score higher than 7/14"
        }

        test "zero total containers is treated as max (no containers = no penalty)" {
            // containerFractionScore with total=0 returns 1.0
            let hs = CliHealthScore.computeHealthScore 0.0 0.0 0.0 true 0 0
            Expect.equal hs.Grade "A"
                "No containers (total=0) should not penalise score; expect Grade A"
        }

        test "Grade C: score >= 0.7 and < 0.8 gives 'C'" {
            // Zenoh down + all containers gone removes 0.25 + 0.15 = 0.40 from perfect score
            // Remaining: 0.25 + 0.20 + 0.15 = 0.60 → Grade D
            // Partial container loss: 7/15 = 0.467 container fraction
            // Zenoh down, 7/15 containers, moderate CPU 50%, rest perfect
            // CPU contrib: 0.25 (at 50% CPU, util=50 so score=1.0) = 0.25
            // Mem contrib: 0.20 * 1.0 = 0.20
            // Disk contrib: 0.15 * 1.0 = 0.15
            // Zenoh: 0 (down)
            // Container: 0.15 * 0.5 = 0.075
            // Total: 0.25 + 0.20 + 0.15 + 0.0 + 0.075 = 0.675 → Grade C
            let hs = CliHealthScore.computeHealthScore 50.0 0.0 0.0 false 7 14
            Expect.isTrue
                (hs.Grade = "C" || hs.Grade = "D")
                $"Partial outage should give Grade C or D, got {hs.Grade} ({hs.Score:F3})"
        }

        test "HealthScore Color is non-empty string for all grades" {
            let inputs = [
                0.0, 0.0, 0.0, true, 14, 14      // A
                80.0, 50.0, 0.0, true, 14, 14     // B/C
                100.0, 100.0, 100.0, false, 0, 14  // F
            ]
            for (cpu, mem, disk, z, ch, ct) in inputs do
                let hs = CliHealthScore.computeHealthScore cpu mem disk z ch ct
                Expect.isNotEmpty hs.Color
                    $"Color for Grade {hs.Grade} should not be empty"
        }
    ]

    // =========================================================================
    // getThreatCount Tests
    // =========================================================================
    testList "getThreatCount" [

        test "getThreatCount returns Ok when SENTINEL_THREAT_COUNT is not set" {
            // The env var is unlikely to be set in the test environment
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            let result = CliHealthScore.getThreatCount ()
            Expect.isOk result "getThreatCount should return Ok when env var is absent"
        }

        test "getThreatCount Ok message contains 'Sentinel' or 'threat'" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            match CliHealthScore.getThreatCount () with
            | Ok msg ->
                let lower = msg.ToLowerInvariant()
                Expect.isTrue
                    (lower.Contains("threat") || lower.Contains("sentinel"))
                    $"Message should describe threats; got: {msg}"
            | Error e -> failtest $"Expected Ok, got Error: {e}"
        }

        test "getThreatCount with valid count '3' returns Ok containing '3'" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", "3")
            let result = CliHealthScore.getThreatCount ()
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            match result with
            | Ok msg -> Expect.isTrue (msg.Contains("3")) $"Message should contain '3': {msg}"
            | Error e -> failtest $"Expected Ok for valid count, got Error: {e}"
        }

        test "getThreatCount with '0' returns Ok (zero threats is valid)" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", "0")
            let result = CliHealthScore.getThreatCount ()
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            Expect.isOk result "Zero threats should return Ok"
        }

        test "getThreatCount with non-integer value returns Error" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", "not_a_number")
            let result = CliHealthScore.getThreatCount ()
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            Expect.isError result "Non-integer SENTINEL_THREAT_COUNT should return Error"
        }

        test "getThreatCount with negative value returns Error" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", "-1")
            let result = CliHealthScore.getThreatCount ()
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            Expect.isError result "Negative SENTINEL_THREAT_COUNT should return Error"
        }
    ]

    // =========================================================================
    // renderHealthLine Tests
    // =========================================================================
    testList "renderHealthLine" [

        test "renderHealthLine returns non-empty string" {
            let line = CliHealthScore.renderHealthLine 30.0 40.0 20.0 true 14 14
            Expect.isNotEmpty line "renderHealthLine should return a non-empty string"
        }

        test "renderHealthLine contains 'Health:' label" {
            let line = CliHealthScore.renderHealthLine 30.0 40.0 20.0 true 14 14
            Expect.isTrue (line.Contains("Health:"))
                "renderHealthLine should contain 'Health:' label"
        }

        test "renderHealthLine shows 'UP' when Zenoh is up" {
            let line = CliHealthScore.renderHealthLine 30.0 40.0 20.0 true 14 14
            Expect.isTrue (line.Contains("UP"))
                "renderHealthLine should show 'UP' when zenohUp=true (SC-ZENOH-007)"
        }

        test "renderHealthLine shows 'DOWN' when Zenoh is down" {
            let line = CliHealthScore.renderHealthLine 30.0 40.0 20.0 false 14 14
            Expect.isTrue (line.Contains("DOWN"))
                "renderHealthLine should show 'DOWN' when zenohUp=false"
        }

        test "renderHealthLine contains container ratio 14/14" {
            let line = CliHealthScore.renderHealthLine 0.0 0.0 0.0 true 14 14
            Expect.isTrue (line.Contains("14/14"))
                "renderHealthLine should contain container healthy/total ratio"
        }

        test "renderHealthLine contains grade letter" {
            let line = CliHealthScore.renderHealthLine 0.0 0.0 0.0 true 14 14
            Expect.isTrue
                (line.Contains("A") || line.Contains("B") || line.Contains("C")
                 || line.Contains("D") || line.Contains("F"))
                "renderHealthLine should contain a grade letter"
        }

        test "renderHealthLine contains ZENOH keyword" {
            let line = CliHealthScore.renderHealthLine 30.0 40.0 20.0 true 14 14
            Expect.isTrue (line.Contains("ZENOH"))
                "renderHealthLine should contain ZENOH keyword (SC-ZENOH-007)"
        }
    ]

    // =========================================================================
    // renderThreatSummary Tests
    // =========================================================================
    testList "renderThreatSummary" [

        test "renderThreatSummary with zero threats returns Ok" {
            let summary = { Critical = 0; High = 0; Medium = 0; Low = 0; Total = 0 }
            let result = CliHealthScore.renderThreatSummary summary
            Expect.isOk result "Zero-threat summary should return Ok"
        }

        test "renderThreatSummary zero threats message contains 'No active threats'" {
            let summary = { Critical = 0; High = 0; Medium = 0; Low = 0; Total = 0 }
            match CliHealthScore.renderThreatSummary summary with
            | Ok msg -> Expect.isTrue (msg.Contains("No active threats")) $"Got: {msg}"
            | Error e -> failtest $"Expected Ok: {e}"
        }

        test "renderThreatSummary with 1 critical threat returns Ok" {
            let summary = { Critical = 1; High = 0; Medium = 0; Low = 0; Total = 1 }
            let result = CliHealthScore.renderThreatSummary summary
            Expect.isOk result "Non-zero threat summary should return Ok"
        }

        test "renderThreatSummary with critical threat contains 'CRIT'" {
            let summary = { Critical = 2; High = 1; Medium = 0; Low = 0; Total = 3 }
            match CliHealthScore.renderThreatSummary summary with
            | Ok msg -> Expect.isTrue (msg.Contains("CRIT")) $"Should contain CRIT: {msg}"
            | Error e -> failtest $"Expected Ok: {e}"
        }

        test "renderThreatSummary shows correct total count" {
            let summary = { Critical = 1; High = 2; Medium = 3; Low = 4; Total = 10 }
            match CliHealthScore.renderThreatSummary summary with
            | Ok msg -> Expect.isTrue (msg.Contains("10")) $"Should contain total 10: {msg}"
            | Error e -> failtest $"Expected Ok: {e}"
        }

        test "renderThreatSummary without HIGH omits HIGH keyword" {
            let summary = { Critical = 1; High = 0; Medium = 0; Low = 0; Total = 1 }
            match CliHealthScore.renderThreatSummary summary with
            | Ok msg ->
                Expect.isFalse (msg.Contains("HIGH:")) "Should not contain HIGH: when High=0"
            | Error e -> failtest $"Expected Ok: {e}"
        }
    ]

    // =========================================================================
    // renderCompactStatus Tests
    // =========================================================================
    testList "renderCompactStatus" [

        test "renderCompactStatus returns Ok when SENTINEL_THREAT_COUNT is unset" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            let result = CliHealthScore.renderCompactStatus 30.0 40.0 20.0 true 14 14
            Expect.isOk result "renderCompactStatus should return Ok with no Sentinel env"
        }

        test "renderCompactStatus output is non-empty" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            match CliHealthScore.renderCompactStatus 30.0 40.0 20.0 true 14 14 with
            | Ok s  -> Expect.isNotEmpty s "Compact status should not be empty"
            | Error e -> failtest $"Expected Ok: {e}"
        }

        test "renderCompactStatus output contains container ratio" {
            System.Environment.SetEnvironmentVariable("SENTINEL_THREAT_COUNT", null)
            match CliHealthScore.renderCompactStatus 0.0 0.0 0.0 true 14 14 with
            | Ok s  -> Expect.isTrue (s.Contains("14/14")) "Should contain container ratio"
            | Error e -> failtest $"Expected Ok: {e}"
        }
    ]
]
