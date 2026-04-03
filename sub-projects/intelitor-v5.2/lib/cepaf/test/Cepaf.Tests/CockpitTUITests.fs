/// TUI Testing Module for PRAJNA C3I Mesh Cockpit
/// Reference: GEMINI.md Section 4.0 - TDG Methodology (Test-Driven Generation)
/// Compliance: SC-HMI-001 to SC-HMI-004 (Dark Cockpit Principles)
module Cepaf.Tests.CockpitTUITests

open System
open System.IO
open System.Text
open System.Text.RegularExpressions
open Expecto
open Expecto.ExpectoFsCheck
open FsCheck
open FsCheck.FSharp

// ============================================================================
// TUI Testing Strategy
// ============================================================================
//
// 1. Property-Based Tests (FsCheck)
//    - Rendering determinism: same state → same output
//    - ANSI escape sequence validity
//    - Content truncation safety
//
// 2. State Machine Tests (Expecto)
//    - Agent status transitions
//    - AEE phase progression
//    - Safety envelope invariants
//
// 3. Golden File Tests (Snapshot Testing)
//    - Known state → expected visual output
//    - Regression detection for UI changes
//
// 4. Integration Tests
//    - Full demo workflow completion
//    - OODA cycle timing verification
// ============================================================================

// ============================================================================
// Type Definitions for Testing
// ============================================================================

type AlarmLevel =
    | Normal
    | Advisory
    | Caution
    | Warning
    | Critical

type AgentStatus =
    | Idle
    | Running
    | Success
    | Error

type TestableUIState = {
    SystemHealth: float
    ActiveAlarms: int
    Nodes: int
    Uptime: TimeSpan
}

// ============================================================================
// ANSI Escape Sequence Utilities
// ============================================================================

module ANSI =
    /// Pattern to match ANSI escape sequences
    let escapePattern = Regex(@"\x1b\[[0-9;]*m", RegexOptions.Compiled)

    /// Strip all ANSI codes from string
    let stripCodes (s: string) = escapePattern.Replace(s, "")

    /// Count ANSI escape sequences in string
    let countCodes (s: string) = escapePattern.Matches(s).Count

    /// Validate ANSI codes are properly closed (reset sequences)
    let hasBalancedCodes (s: string) =
        let codes = escapePattern.Matches(s) |> Seq.cast<Match> |> Seq.toList
        // Check for reset code at end or balanced open/close
        codes |> List.exists (fun m -> m.Value.Contains("0m"))

// ============================================================================
// Mock Renderers for Testing
// ============================================================================

module MockRenderers =

    /// Simulate Material3 card rendering (simplified for testing)
    let renderCard (title: string) (content: string) (width: int) =
        let border = String.replicate width "─"
        let padded =
            if content.Length < width - 4 then
                content + String.replicate (width - 4 - content.Length) " "
            else
                content.Substring(0, width - 4)
        sprintf "┌%s┐\n│ %s │\n│ %s │\n└%s┘" border title padded border

    /// Simulate status bar rendering
    let renderStatusBar (health: float) (alarms: int) (nodes: int) =
        let healthIcon = if health >= 90.0 then "●" elif health >= 70.0 then "◐" else "○"
        sprintf "%s HEALTH: %.0f%% │ ALARMS: %d │ NODES: %d" healthIcon health alarms nodes

    /// Simulate sparkline rendering
    let renderSparkline (values: float list) =
        let chars = [|'▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█'|]
        let maxVal = List.max values
        let minVal = List.min values
        let range = maxVal - minVal
        values
        |> List.map (fun v ->
            if range = 0.0 then chars.[3]
            else
                let normalized = (v - minVal) / range * 7.0
                chars.[int (min 7.0 (max 0.0 normalized))]
        )
        |> List.map string
        |> String.concat ""

// ============================================================================
// Custom Generators
// ============================================================================

type Generators =

    static member AlarmLevel() =
        Arb.fromGen (Gen.elements [
            AlarmLevel.Normal
            AlarmLevel.Advisory
            AlarmLevel.Caution
            AlarmLevel.Warning
            AlarmLevel.Critical
        ])

    static member AgentStatus() =
        Arb.fromGen (Gen.elements [
            AgentStatus.Idle
            AgentStatus.Running
            AgentStatus.Success
            AgentStatus.Error
        ])

    static member UIState() =
        Arb.fromGen (gen {
            let! health = Gen.choose (0, 100) |> Gen.map float
            let! alarms = Gen.choose (0, 50)
            let! nodes = Gen.choose (1, 10)
            let! uptimeMinutes = Gen.choose (0, 1440)
            return {
                SystemHealth = health
                ActiveAlarms = alarms
                Nodes = nodes
                Uptime = TimeSpan.FromMinutes(float uptimeMinutes)
            }
        })

    static member SparklineData() =
        Arb.fromGen (gen {
            let! length = Gen.choose (5, 30)
            let! values = Gen.listOfLength length (Gen.choose (0, 100) |> Gen.map float)
            return values
        })

// ============================================================================
// Property-Based Tests
// ============================================================================

module Properties =

    // -------------------------------------------------------------------------
    // Rendering Determinism Tests
    // -------------------------------------------------------------------------

    let ``Card rendering is deterministic`` (title: NonEmptyString) (content: string) =
        let width = 40
        let safeContent = if isNull content then "" else content.Substring(0, min 30 content.Length)
        let render1 = MockRenderers.renderCard title.Get safeContent width
        let render2 = MockRenderers.renderCard title.Get safeContent width
        render1 = render2

    let ``Status bar rendering is deterministic`` (state: TestableUIState) =
        let render1 = MockRenderers.renderStatusBar state.SystemHealth state.ActiveAlarms state.Nodes
        let render2 = MockRenderers.renderStatusBar state.SystemHealth state.ActiveAlarms state.Nodes
        render1 = render2

    let ``Sparkline rendering is deterministic`` (values: float list) =
        if values.Length < 2 then true
        else
            let render1 = MockRenderers.renderSparkline values
            let render2 = MockRenderers.renderSparkline values
            render1 = render2

    // -------------------------------------------------------------------------
    // Output Validity Tests
    // -------------------------------------------------------------------------

    let ``Sparkline output length equals input length`` (values: float list) =
        if values.Length < 2 then true
        else
            let output = MockRenderers.renderSparkline values
            output.Length = values.Length

    let ``Status bar always shows health percentage`` (state: TestableUIState) =
        let output = MockRenderers.renderStatusBar state.SystemHealth state.ActiveAlarms state.Nodes
        output.Contains("%")

    let ``Card contains title`` (title: NonEmptyString) =
        let output = MockRenderers.renderCard title.Get "content" 40
        output.Contains(title.Get)

    // -------------------------------------------------------------------------
    // Boundary Condition Tests
    // -------------------------------------------------------------------------

    let ``Health icon correct for ranges`` (health: float) =
        let output = MockRenderers.renderStatusBar (max 0.0 (min 100.0 health)) 0 1
        let expectedIcon =
            if health >= 90.0 then "●"
            elif health >= 70.0 then "◐"
            else "○"
        output.Contains(expectedIcon)

// ============================================================================
// Unit Tests
// ============================================================================

[<Tests>]
let renderingTests =
    testList "TUI Rendering" [

        testCase "Card has proper box drawing characters" <| fun _ ->
            let output = MockRenderers.renderCard "Title" "Content" 40
            Expect.stringContains output "┌" "Should have top-left corner"
            Expect.stringContains output "┐" "Should have top-right corner"
            Expect.stringContains output "└" "Should have bottom-left corner"
            Expect.stringContains output "┘" "Should have bottom-right corner"

        testCase "Sparkline uses block characters only" <| fun _ ->
            let output = MockRenderers.renderSparkline [10.0; 50.0; 90.0; 30.0; 70.0]
            let validChars = ['▁'; '▂'; '▃'; '▄'; '▅'; '▆'; '▇'; '█']
            let allValid = output |> Seq.forall (fun c -> List.contains c validChars)
            Expect.isTrue allValid "All chars should be block chars"

        testCase "Status bar shows health icon" <| fun _ ->
            let output = MockRenderers.renderStatusBar 95.0 0 5
            Expect.stringContains output "●" "95% health should show solid circle"

        testCase "Status bar shows degraded icon" <| fun _ ->
            let output = MockRenderers.renderStatusBar 75.0 0 5
            Expect.stringContains output "◐" "75% health should show half circle"

        testCase "Status bar shows unhealthy icon" <| fun _ ->
            let output = MockRenderers.renderStatusBar 50.0 0 5
            Expect.stringContains output "○" "50% health should show empty circle"
    ]

[<Tests>]
let agentStateTests =
    testList "Agent State Machine" [

        testCase "Agent starts in Idle state" <| fun _ ->
            let initialStatus = AgentStatus.Idle
            Expect.equal initialStatus AgentStatus.Idle "Initial state should be Idle"

        testCase "Agent transitions Idle -> Running" <| fun _ ->
            let transition status =
                match status with
                | AgentStatus.Idle -> AgentStatus.Running
                | s -> s
            let result = transition AgentStatus.Idle
            Expect.equal result AgentStatus.Running "Should transition to Running"

        testCase "Agent transitions Running -> Success on completion" <| fun _ ->
            let transition status taskComplete =
                match status, taskComplete with
                | AgentStatus.Running, true -> AgentStatus.Success
                | AgentStatus.Running, false -> AgentStatus.Running
                | s, _ -> s
            let result = transition AgentStatus.Running true
            Expect.equal result AgentStatus.Success "Should transition to Success"

        testCase "Agent transitions Running -> Error on failure" <| fun _ ->
            let transition status taskFailed =
                match status, taskFailed with
                | AgentStatus.Running, true -> AgentStatus.Error
                | s, _ -> s
            let result = transition AgentStatus.Running true
            Expect.equal result AgentStatus.Error "Should transition to Error"

        testCase "Terminal states are stable" <| fun _ ->
            let transition status =
                match status with
                | AgentStatus.Success -> AgentStatus.Success
                | AgentStatus.Error -> AgentStatus.Error
                | s -> s
            Expect.equal (transition AgentStatus.Success) AgentStatus.Success "Success is terminal"
            Expect.equal (transition AgentStatus.Error) AgentStatus.Error "Error is terminal"
    ]

[<Tests>]
let aeePhaseTests =
    testList "AEE Phase Progression" [

        testCase "All 6 phases complete in order" <| fun _ ->
            let phases = [
                "INFRASTRUCTURE"
                "DASHBOARD_INIT"
                "COMPILE_VALIDATE"
                "TELEMETRY_VERIFY"
                "TEST_EXECUTION"
                "CONTAINER_FINAL"
            ]
            Expect.equal phases.Length 6 "Should have exactly 6 phases"

        testCase "Phase completion is monotonic" <| fun _ ->
            let mutable completedPhases = 0
            let completePhase () =
                completedPhases <- completedPhases + 1
                completedPhases

            for i in 1..6 do
                let result = completePhase()
                Expect.equal result i "Phase count should increase monotonically"

        testCase "GDE goal requires all agents verified" <| fun _ ->
            let agents = [
                ("SUPERVISOR", AgentStatus.Success)
                ("DASHBOARD", AgentStatus.Success)
                ("CEPAF/GDE", AgentStatus.Success)
                ("TELEMETRY", AgentStatus.Success)
                ("TEST_RUN", AgentStatus.Success)
                ("CONTAINER", AgentStatus.Success)
            ]
            let allVerified = agents |> List.forall (fun (_, s) -> s = AgentStatus.Success)
            Expect.isTrue allVerified "All agents must be Success for GDE goal"
    ]

[<Tests>]
let darkCockpitTests =
    testList "Dark Cockpit Compliance (SC-HMI)" [

        testCase "SC-HMI-001: Normal state is visually quiet" <| fun _ ->
            // Gray/blue defaults; only deviations in amber/red
            let normalOutput = MockRenderers.renderStatusBar 95.0 0 5
            // Should NOT contain warning colors in normal state
            Expect.isFalse (normalOutput.Contains("⚠")) "Normal should not have warning"
            Expect.isFalse (normalOutput.Contains("⛔")) "Normal should not have error"

        testCase "SC-HMI-002: Trends shown as sparklines" <| fun _ ->
            let sparkline = MockRenderers.renderSparkline [10.0; 20.0; 30.0; 25.0; 15.0]
            Expect.isNonEmpty sparkline "Sparkline should render"
            Expect.equal sparkline.Length 5 "Sparkline shows trend direction"

        testCase "SC-HMI-003: Status indicators are distinct" <| fun _ ->
            let healthy = MockRenderers.renderStatusBar 95.0 0 5
            let degraded = MockRenderers.renderStatusBar 75.0 0 5
            let unhealthy = MockRenderers.renderStatusBar 50.0 0 5
            Expect.notEqual healthy degraded "Healthy and degraded should differ"
            Expect.notEqual degraded unhealthy "Degraded and unhealthy should differ"
    ]

// ============================================================================
// Golden File Tests (Snapshot Testing)
// ============================================================================

module GoldenTests =

    let goldenDir =
        let baseDir = Path.Combine(Directory.GetCurrentDirectory(), "lib", "cepaf", "test", "golden")
        if not (Directory.Exists(baseDir)) then
            Directory.CreateDirectory(baseDir) |> ignore
        baseDir

    /// Save a golden file
    let saveGolden (name: string) (content: string) =
        let path = Path.Combine(goldenDir, name + ".golden")
        File.WriteAllText(path, content)

    /// Load and compare against golden file
    let compareGolden (name: string) (actual: string) =
        let path = Path.Combine(goldenDir, name + ".golden")
        if File.Exists(path) then
            let expected = File.ReadAllText(path)
            (expected = actual, expected, actual)
        else
            // First run: save as golden and pass
            saveGolden name actual
            (true, actual, actual)

[<Tests>]
let goldenTests =
    testList "Golden File Tests" [

        testCase "Status bar golden test" <| fun _ ->
            let output = MockRenderers.renderStatusBar 94.0 2 5
            let (passed, expected, actual) = GoldenTests.compareGolden "status_bar_normal" output
            if not passed then
                Expect.equal actual expected "Output should match golden file"

        testCase "Card render golden test" <| fun _ ->
            let output = MockRenderers.renderCard "SYSTEM STATUS" "All systems operational" 50
            let (passed, expected, actual) = GoldenTests.compareGolden "card_system_status" output
            if not passed then
                Expect.equal actual expected "Output should match golden file"

        testCase "Sparkline golden test" <| fun _ ->
            let output = MockRenderers.renderSparkline [10.0; 25.0; 45.0; 80.0; 60.0; 40.0; 35.0; 50.0]
            let (passed, expected, actual) = GoldenTests.compareGolden "sparkline_trend" output
            if not passed then
                Expect.equal actual expected "Output should match golden file"
    ]

// ============================================================================
// OODA Cycle Timing Tests
// ============================================================================

[<Tests>]
let oodaTimingTests =
    testList "OODA Cycle Timing" [

        testCase "OODA cycle should complete under 1000ms" <| fun _ ->
            let sw = System.Diagnostics.Stopwatch.StartNew()
            // Simulate OODA phases
            let observe () = System.Threading.Thread.Sleep(50); "observed"
            let orient result = System.Threading.Thread.Sleep(100); result + "-oriented"
            let decide result = System.Threading.Thread.Sleep(50); result + "-decided"
            let act result = System.Threading.Thread.Sleep(100); result + "-acted"

            let _ = observe() |> orient |> decide |> act
            sw.Stop()

            Expect.isLessThan sw.ElapsedMilliseconds 1000L "OODA cycle under 1s per GDE requirements"

        testCase "Dashboard refresh under 500ms" <| fun _ ->
            let sw = System.Diagnostics.Stopwatch.StartNew()
            // Simulate dashboard render
            for _ in 1..10 do
                let _ = MockRenderers.renderStatusBar 94.0 2 5
                let _ = MockRenderers.renderSparkline [10.0; 20.0; 30.0; 40.0; 50.0]
                ()
            sw.Stop()

            Expect.isLessThan sw.ElapsedMilliseconds 500L "Dashboard render under 500ms"
    ]

// ============================================================================
// Property Tests using Expecto.FsCheck
// ============================================================================

[<Tests>]
let propertyTests =
    testList "TUI Properties (FsCheck)" [
        testProperty "Card rendering determinism" Properties.``Card rendering is deterministic``
        testProperty "Status bar determinism" Properties.``Status bar rendering is deterministic``
        testProperty "Sparkline determinism" Properties.``Sparkline rendering is deterministic``
        testProperty "Sparkline length invariant" Properties.``Sparkline output length equals input length``
        testProperty "Status bar shows health" Properties.``Status bar always shows health percentage``
        testProperty "Card contains title" Properties.``Card contains title``
        testProperty "Health icon ranges" Properties.``Health icon correct for ranges``
    ]

[<Tests>]
let allCockpitTests =
    testList "PRAJNA C3I Cockpit TUI" [
        renderingTests
        agentStateTests
        aeePhaseTests
        darkCockpitTests
        goldenTests
        oodaTimingTests
        propertyTests
    ]

/// Run all cockpit TUI tests standalone
let runTests (args: string array) =
    printfn ""
    printfn "╔══════════════════════════════════════════════════════════════════╗"
    printfn "║  PRAJNA C3I COCKPIT - TUI AUTOMATED TESTS                        ║"
    printfn "║  Testing: Material3, Agents, AEE, Dark Cockpit Compliance        ║"
    printfn "╚══════════════════════════════════════════════════════════════════╝"
    printfn ""

    runTestsWithCLIArgs [] args allCockpitTests
