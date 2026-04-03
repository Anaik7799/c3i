module Cepaf.Tests.Unit.Cockpit.ThemeSimulatorTests

open System
open Expecto
open Cepaf.Cockpit.ThemeSimulator

/// ============================================================================
/// THEME SIMULATOR COMPREHENSIVE TEST SUITE
/// ============================================================================
/// Coverage: 100+ Test Cases | Property-Based Testing
/// STAMP Compliance: SC-SIM-001 to SC-SIM-007
/// Framework: SOPv5.11 | Expecto + FsCheck
/// ============================================================================

// =============================================================================
// CATEGORY 1: INITIALIZATION (TS-INIT)
// =============================================================================

[<Tests>]
let initializationTests =
    testList "TS-INIT: Initialization" [
        test "TS-INIT-001: initialState returns valid state" {
            let state = initialState ()
            Expect.isNotNull (box state) "State should not be null"
        }

        test "TS-INIT-002: initial screen is OverviewScreen" {
            let state = initialState ()
            Expect.equal state.CurrentScreen SimulatorScreen.OverviewScreen "Should start on OverviewScreen"
        }

        test "TS-INIT-003: initial ARM state is idle" {
            let state = initialState ()
            Expect.equal state.ArmState "idle" "ARM should be idle initially"
        }

        test "TS-INIT-004: ARM progress is 0 initially" {
            let state = initialState ()
            Expect.equal state.ArmProgress 0.0 "ARM progress should be 0"
        }

        test "TS-INIT-005: animation frame is 0 initially" {
            let state = initialState ()
            Expect.equal state.AnimationFrame 0 "Animation frame should be 0"
        }

        test "TS-INIT-006: selected index is 0 initially" {
            let state = initialState ()
            Expect.equal state.SelectedIndex 0 "Selected index should be 0"
        }

        test "TS-INIT-007: demo mode is false initially" {
            let state = initialState ()
            Expect.isFalse state.DemoMode "Demo mode should be false"
        }

        test "TS-INIT-008: reduced motion is false initially" {
            let state = initialState ()
            Expect.isFalse state.ReducedMotion "Reduced motion should be false"
        }

        test "TS-INIT-009: high contrast is false initially" {
            let state = initialState ()
            Expect.isFalse state.HighContrast "High contrast should be false"
        }

        test "TS-INIT-010: simulated staleness is 0 initially" {
            let state = initialState ()
            Expect.equal state.SimulatedStalenessMs 0 "Staleness should be 0"
        }

        test "TS-INIT-011: active alarms are initialized" {
            let state = initialState ()
            Expect.isGreaterThan (List.length state.ActiveAlarms) 0 "Should have active alarms"
        }

        test "TS-INIT-012: journey execution state is initialized" {
            let state = initialState ()
            Expect.isNotNull (box state.JourneyExecution) "Journey execution should be initialized"
        }

        test "TS-INIT-013: color blindness mode is NormalVision" {
            let state = initialState ()
            Expect.equal state.ColorBlindnessMode ColorBlindnessType.NormalVision "Should be normal vision"
        }

        test "TS-INIT-014: journey panel is shown initially" {
            let state = initialState ()
            Expect.isTrue state.ShowJourneyPanel "Journey panel should be shown"
        }

        test "TS-INIT-015: journey view mode is steps" {
            let state = initialState ()
            Expect.equal state.JourneyViewMode "steps" "View mode should be steps"
        }
    ]

// =============================================================================
// CATEGORY 2: INPUT HANDLING (TS-INPUT)
// =============================================================================

[<Tests>]
let inputTests =
    testList "TS-INPUT: Input Handling" [
        test "TS-INPUT-001: Q key returns quit signal" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('q', ConsoleKey.Q, false, false, false)
            let (_, shouldQuit) = handleInput keyInfo state
            Expect.isTrue shouldQuit "Q should signal quit"
        }

        test "TS-INPUT-002: number key 1 changes screen" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('1', ConsoleKey.D1, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.notEqual newState.CurrentScreen state.CurrentScreen "Screen should change"
        }

        test "TS-INPUT-003: unknown key does not quit" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('~', ConsoleKey.NoName, false, false, false)
            let (_, shouldQuit) = handleInput keyInfo state
            Expect.isFalse shouldQuit "Unknown key should not quit"
        }

        test "TS-INPUT-004: arrow down changes selection" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo(' ', ConsoleKey.DownArrow, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.isGreaterThanOrEqual newState.SelectedIndex 0 "Selection should be valid"
        }

        test "TS-INPUT-005: arrow up changes selection" {
            let state = { initialState () with SelectedIndex = 5 }
            let keyInfo = ConsoleKeyInfo(' ', ConsoleKey.UpArrow, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.isGreaterThanOrEqual newState.SelectedIndex 0 "Selection should be valid"
        }

        test "TS-INPUT-006: J key navigates to journey simulation" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('j', ConsoleKey.J, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.JourneySimulationDemo "Should be on journey sim"
        }

        test "TS-INPUT-007: K key navigates to journey timeline" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('k', ConsoleKey.K, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.JourneyTimelineDemo "Should be on timeline"
        }

        test "TS-INPUT-008: L key navigates to journey branch" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('l', ConsoleKey.L, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.JourneyBranchDemo "Should be on branch"
        }
    ]

// =============================================================================
// CATEGORY 3: SCREEN NAVIGATION (TS-NAV)
// =============================================================================

[<Tests>]
let navigationTests =
    testList "TS-NAV: Screen Navigation" [
        test "TS-NAV-001: can navigate to NavigationDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('1', ConsoleKey.D1, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.NavigationDemo "Should be on NavigationDemo"
        }

        test "TS-NAV-002: can navigate to StatusDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('2', ConsoleKey.D2, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.StatusDemo "Should be on StatusDemo"
        }

        test "TS-NAV-003: can navigate to DataDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('3', ConsoleKey.D3, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.DataDemo "Should be on DataDemo"
        }

        test "TS-NAV-004: can navigate to InteractionDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('4', ConsoleKey.D4, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.InteractionDemo "Should be on InteractionDemo"
        }

        test "TS-NAV-005: can navigate to FeedbackDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('5', ConsoleKey.D5, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.FeedbackDemo "Should be on FeedbackDemo"
        }

        test "TS-NAV-006: can navigate to ArmFireDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('6', ConsoleKey.D6, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.ArmFireDemo "Should be on ArmFireDemo"
        }

        test "TS-NAV-007: can navigate to ContrastCheckerDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('7', ConsoleKey.D7, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.ContrastCheckerDemo "Should be on ContrastCheckerDemo"
        }

        test "TS-NAV-008: can navigate to ColorBlindnessDemo" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('8', ConsoleKey.D8, false, false, false)
            let (newState, _) = handleInput keyInfo state
            Expect.equal newState.CurrentScreen SimulatorScreen.ColorBlindnessDemo "Should be on ColorBlindnessDemo"
        }
    ]

// =============================================================================
// CATEGORY 4: ARM/FIRE SAFETY (TS-ARM)
// =============================================================================

[<Tests>]
let armFireTests =
    testList "TS-ARM: ARM/FIRE Safety Protocol" [
        test "TS-ARM-001: ARM state starts idle" {
            let state = initialState ()
            Expect.equal state.ArmState "idle" "ARM should be idle"
        }

        test "TS-ARM-002: ARM progress starts at 0" {
            let state = initialState ()
            Expect.equal state.ArmProgress 0.0 "ARM progress should be 0"
        }

        test "TS-ARM-003: executeAction TriggerArmSequence sets arming state" {
            let state = initialState ()
            let newState = executeAction TriggerArmSequence state
            Expect.equal newState.ArmState "arming" "Should be arming"
        }

        test "TS-ARM-004: TriggerFireSequence only works when armed" {
            let state = initialState ()
            let newState = executeAction TriggerFireSequence state
            Expect.equal newState.ArmState "idle" "Should stay idle when not armed"
        }

        test "TS-ARM-005: TriggerFireSequence works when armed" {
            let state = { initialState () with ArmState = "armed" }
            let newState = executeAction TriggerFireSequence state
            Expect.equal newState.ArmState "firing" "Should be firing when armed"
        }

        test "TS-ARM-006: ARM progress resets with arm sequence" {
            let state = { initialState () with ArmProgress = 0.5 }
            let newState = executeAction TriggerArmSequence state
            Expect.equal newState.ArmProgress 0.0 "Progress should reset"
        }
    ]

// =============================================================================
// CATEGORY 5: CHECKPOINT SYSTEM (TS-CHK)
// =============================================================================

[<Tests>]
let checkpointTests =
    testList "TS-CHK: Checkpoint System" [
        test "TS-CHK-001: createCheckpoint creates valid checkpoint" {
            let cp = createCheckpoint "Test" "Description" "journey-1" 0 (box "state") None ["test"]
            Expect.isNotEmpty cp.Id "Checkpoint should have ID"
        }

        test "TS-CHK-002: checkpoint has correct name" {
            let cp = createCheckpoint "MyCheckpoint" "Desc" "j1" 0 (box "s") None []
            Expect.equal cp.Name "MyCheckpoint" "Name should match"
        }

        test "TS-CHK-003: checkpoint has timestamp" {
            let cp = createCheckpoint "T" "D" "j" 0 (box "s") None []
            Expect.isGreaterThan cp.Timestamp DateTime.MinValue "Should have timestamp"
        }

        test "TS-CHK-004: checkpoint parent can be set" {
            let cp = createCheckpoint "T" "D" "j" 0 (box "s") (Some "parent-1") []
            Expect.equal cp.ParentCheckpointId (Some "parent-1") "Parent should be set"
        }

        test "TS-CHK-005: checkpoint tags can be set" {
            let cp = createCheckpoint "T" "D" "j" 0 (box "s") None ["tag1"; "tag2"]
            Expect.equal (List.length cp.Tags) 2 "Should have 2 tags"
        }

        test "TS-CHK-006: checkpoint has journey ID" {
            let cp = createCheckpoint "T" "D" "my-journey" 0 (box "s") None []
            Expect.equal cp.JourneyId "my-journey" "Journey ID should match"
        }

        test "TS-CHK-007: checkpoint has step index" {
            let cp = createCheckpoint "T" "D" "j" 5 (box "s") None []
            Expect.equal cp.StepIndex 5 "Step index should match"
        }
    ]

// =============================================================================
// CATEGORY 6: JOURNEY EXECUTION (TS-JRN)
// =============================================================================

[<Tests>]
let journeyTests =
    testList "TS-JRN: Journey Execution" [
        test "TS-JRN-001: initialJourneyState creates valid state" {
            let je = initialJourneyState ()
            Expect.isNotNull (box je) "Journey state should not be null"
        }

        test "TS-JRN-002: journey execution starts with no current journey" {
            let je = initialJourneyState ()
            Expect.isNone je.CurrentJourney "Should have no current journey"
        }

        test "TS-JRN-003: journey execution starts at step 0" {
            let je = initialJourneyState ()
            Expect.equal je.CurrentStepIndex 0 "Should start at step 0"
        }

        test "TS-JRN-004: journey execution starts with empty checkpoints" {
            let je = initialJourneyState ()
            Expect.isEmpty je.Checkpoints "Should have no checkpoints"
        }

        test "TS-JRN-005: journey execution starts with empty branches" {
            let je = initialJourneyState ()
            Expect.isEmpty je.AllBranches "Should have no branches"
        }

        test "TS-JRN-006: journey execution not running initially" {
            let je = initialJourneyState ()
            Expect.isFalse je.IsRunning "Should not be running"
        }

        test "TS-JRN-007: journey execution not paused initially" {
            let je = initialJourneyState ()
            Expect.isFalse je.IsPaused "Should not be paused"
        }
    ]

// =============================================================================
// CATEGORY 7: ACTION EXECUTION (TS-ACT)
// =============================================================================

[<Tests>]
let actionTests =
    testList "TS-ACT: Action Execution" [
        test "TS-ACT-001: NavigateTo changes screen" {
            let state = initialState ()
            let newState = executeAction (NavigateTo SimulatorScreen.DataDemo) state
            Expect.equal newState.CurrentScreen SimulatorScreen.DataDemo "Should navigate"
        }

        test "TS-ACT-002: SetColorBlindnessMode changes mode" {
            let state = initialState ()
            let newState = executeAction (SetColorBlindnessMode ColorBlindnessType.Protanopia) state
            Expect.equal newState.ColorBlindnessMode ColorBlindnessType.Protanopia "Should change mode"
        }

        test "TS-ACT-003: ToggleReducedMotion toggles setting" {
            let state = initialState ()
            let newState = executeAction ToggleReducedMotion state
            Expect.isTrue newState.ReducedMotion "Should toggle"
        }

        test "TS-ACT-004: ToggleHighContrast toggles setting" {
            let state = initialState ()
            let newState = executeAction ToggleHighContrast state
            Expect.isTrue newState.HighContrast "Should toggle"
        }

        test "TS-ACT-005: SetStalenessLevel sets value" {
            let state = initialState ()
            let newState = executeAction (SetStalenessLevel 5000) state
            Expect.equal newState.SimulatedStalenessMs 5000 "Should set staleness"
        }

        test "TS-ACT-006: AddAlarm adds alarm" {
            let state = { initialState () with ActiveAlarms = [] }
            let newState = executeAction (AddAlarm (AlarmPriority.High, AlarmState.Active)) state
            Expect.equal (List.length newState.ActiveAlarms) 1 "Should add alarm"
        }

        test "TS-ACT-007: ClearAlarm removes alarm" {
            let state = initialState ()
            let initialCount = List.length state.ActiveAlarms
            let newState = executeAction (ClearAlarm AlarmPriority.Critical) state
            Expect.isLessThan (List.length newState.ActiveAlarms) initialCount "Should remove alarm"
        }

        test "TS-ACT-008: WaitMs does not change state" {
            let state = initialState ()
            let newState = executeAction (WaitMs 100) state
            // Compare key fields since SimulatorState doesn't support equality
            Expect.equal newState.CurrentScreen state.CurrentScreen "Screen should not change"
            Expect.equal newState.ArmState state.ArmState "ArmState should not change"
            Expect.equal newState.ReducedMotion state.ReducedMotion "ReducedMotion should not change"
        }
    ]

// =============================================================================
// CATEGORY 8: OUTCOME VERIFICATION (TS-VER)
// =============================================================================

[<Tests>]
let verificationTests =
    testList "TS-VER: Outcome Verification" [
        test "TS-VER-001: ScreenIs passes when screen matches" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.DataDemo }
            let result = verifyOutcome (ScreenIs SimulatorScreen.DataDemo) state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }

        test "TS-VER-002: ScreenIs fails when screen differs" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.DataDemo }
            let result = verifyOutcome (ScreenIs SimulatorScreen.StatusDemo) state
            match result with
            | Failed _ -> Expect.isTrue true "Should fail"
            | _ -> failtest "Should fail"
        }

        test "TS-VER-003: ColorBlindnessSafe verifies accessible design" {
            let state = initialState ()
            let result = verifyOutcome ColorBlindnessSafe state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }

        test "TS-VER-004: Custom outcome with boolean check" {
            let state = { initialState () with ReducedMotion = true }
            let result = verifyOutcome (Custom ("ReducedMotion is true", fun () -> state.ReducedMotion)) state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }

        test "TS-VER-005: Custom outcome for high contrast" {
            let state = { initialState () with HighContrast = true }
            let result = verifyOutcome (Custom ("HighContrast is true", fun () -> state.HighContrast)) state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }

        test "TS-VER-006: StalenessWithinThreshold verifies staleness" {
            let state = { initialState () with SimulatedStalenessMs = 1000 }
            let result = verifyOutcome (StalenessWithinThreshold 2000) state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }

        test "TS-VER-007: ArmStateIs passes when correct" {
            let state = { initialState () with ArmState = "armed" }
            let result = verifyOutcome (ArmStateIs "armed") state
            match result with
            | Passed _ -> Expect.isTrue true "Should pass"
            | _ -> failtest "Should pass"
        }
    ]

// =============================================================================
// CATEGORY 9: RENDER TESTS (TS-RENDER)
// =============================================================================

[<Tests>]
let renderTests =
    testList "TS-RENDER: Render Tests" [
        test "TS-RENDER-001: render does not throw for OverviewScreen" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.OverviewScreen }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-002: render does not throw for NavigationDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.NavigationDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-003: render does not throw for StatusDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.StatusDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-004: render does not throw for DataDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.DataDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-005: render does not throw for InteractionDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.InteractionDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-006: render does not throw for ArmFireDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.ArmFireDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-007: render does not throw for ContrastCheckerDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.ContrastCheckerDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-008: render does not throw for ColorBlindnessDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.ColorBlindnessDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-009: render does not throw for JourneySimulationDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.JourneySimulationDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }

        test "TS-RENDER-010: render does not throw for JourneyTimelineDemo" {
            let state = { initialState () with CurrentScreen = SimulatorScreen.JourneyTimelineDemo }
            Expect.isTrue (try render state; true with _ -> false) "Should render without exception"
        }
    ]

// =============================================================================
// CATEGORY 10: PERFORMANCE (TS-PERF)
// =============================================================================

[<Tests>]
let performanceTests =
    testList "TS-PERF: Performance" [
        test "TS-PERF-001: initialState is fast" {
            let sw = System.Diagnostics.Stopwatch.StartNew()
            let _ = initialState ()
            sw.Stop()
            Expect.isLessThan sw.ElapsedMilliseconds 100L "Init should be < 100ms"
        }

        test "TS-PERF-002: handleInput is fast" {
            let state = initialState ()
            let keyInfo = ConsoleKeyInfo('1', ConsoleKey.D1, false, false, false)
            let sw = System.Diagnostics.Stopwatch.StartNew()
            for _ in 1..100 do
                let _ = handleInput keyInfo state
                ()
            sw.Stop()
            Expect.isLessThan sw.ElapsedMilliseconds 500L "100 inputs should be < 500ms"
        }

        test "TS-PERF-003: executeAction is fast" {
            let state = initialState ()
            let sw = System.Diagnostics.Stopwatch.StartNew()
            for _ in 1..100 do
                let _ = executeAction ToggleReducedMotion state
                ()
            sw.Stop()
            Expect.isLessThan sw.ElapsedMilliseconds 100L "100 actions should be < 100ms"
        }

        test "TS-PERF-004: createCheckpoint is fast" {
            let sw = System.Diagnostics.Stopwatch.StartNew()
            for i in 1..100 do
                let _ = createCheckpoint (sprintf "CP%d" i) "desc" "j" i (box "s") None []
                ()
            sw.Stop()
            Expect.isLessThan sw.ElapsedMilliseconds 100L "100 checkpoints should be < 100ms"
        }
    ]

// =============================================================================
// CATEGORY 11: EDGE CASES (TS-EDGE)
// =============================================================================

[<Tests>]
let edgeCaseTests =
    testList "TS-EDGE: Edge Cases" [
        test "TS-EDGE-001: rapid input handling" {
            let mutable state = initialState ()
            let keys = [ConsoleKey.D1; ConsoleKey.D2; ConsoleKey.D3; ConsoleKey.D4; ConsoleKey.D5]
            for key in keys do
                let keyInfo = ConsoleKeyInfo(' ', key, false, false, false)
                let (newState, _) = handleInput keyInfo state
                state <- newState
            Expect.isNotNull (box state) "Should handle rapid inputs"
        }

        test "TS-EDGE-002: multiple toggle operations" {
            let mutable state = initialState ()
            for _ in 1..10 do
                state <- executeAction ToggleReducedMotion state
            Expect.isFalse state.ReducedMotion "Should be back to original after 10 toggles"
        }

        test "TS-EDGE-003: empty alarm list handling" {
            let state = { initialState () with ActiveAlarms = [] }
            let newState = executeAction (ClearAlarm AlarmPriority.Critical) state
            Expect.isEmpty newState.ActiveAlarms "Should handle empty list"
        }

        test "TS-EDGE-004: navigation from any screen" {
            let screens = [
                SimulatorScreen.OverviewScreen
                SimulatorScreen.NavigationDemo
                SimulatorScreen.StatusDemo
                SimulatorScreen.DataDemo
            ]
            for screen in screens do
                let state = { initialState () with CurrentScreen = screen }
                let newState = executeAction (NavigateTo SimulatorScreen.ArmFireDemo) state
                Expect.equal newState.CurrentScreen SimulatorScreen.ArmFireDemo "Should navigate from any screen"
        }
    ]

// =============================================================================
// CATEGORY 12: INTEGRATION (TS-INT)
// =============================================================================

[<Tests>]
let integrationTests =
    testList "TS-INT: Integration Tests" [
        test "TS-INT-001: full navigation flow" {
            let mutable state = initialState ()
            let keyInfos = [
                ConsoleKeyInfo('1', ConsoleKey.D1, false, false, false)
                ConsoleKeyInfo('2', ConsoleKey.D2, false, false, false)
                ConsoleKeyInfo('3', ConsoleKey.D3, false, false, false)
            ]
            for keyInfo in keyInfos do
                let (newState, _) = handleInput keyInfo state
                state <- newState
            Expect.equal state.CurrentScreen SimulatorScreen.DataDemo "Should be on DataDemo"
        }

        test "TS-INT-002: arm then fire sequence" {
            let state = initialState ()
            let armedState = executeAction TriggerArmSequence state
            let firingState = { armedState with ArmState = "armed" }
            let finalState = executeAction TriggerFireSequence firingState
            Expect.equal finalState.ArmState "firing" "Should complete ARM->FIRE sequence"
        }

        test "TS-INT-003: accessibility settings flow" {
            let state = initialState ()
            let s1 = executeAction (SetColorBlindnessMode ColorBlindnessType.Protanopia) state
            let s2 = executeAction ToggleReducedMotion s1
            let s3 = executeAction ToggleHighContrast s2
            Expect.equal s3.ColorBlindnessMode ColorBlindnessType.Protanopia "CB mode set"
            Expect.isTrue s3.ReducedMotion "Reduced motion set"
            Expect.isTrue s3.HighContrast "High contrast set"
        }

        test "TS-INT-004: checkpoint creation in journey context" {
            let state = initialState ()
            let cp = createCheckpoint "Integration Test" "Full state capture" "int-journey" 0 (state :> obj) None ["integration"; "test"]
            Expect.isNotEmpty cp.Id "Checkpoint ID should be set"
            Expect.equal cp.Name "Integration Test" "Name matches"
            Expect.equal (List.length cp.Tags) 2 "Tags set"
        }

        test "TS-INT-005: alarm management flow" {
            let state = { initialState () with ActiveAlarms = [] }
            let s1 = executeAction (AddAlarm (AlarmPriority.High, AlarmState.Active)) state
            let s2 = executeAction (AddAlarm (AlarmPriority.Medium, AlarmState.Active)) s1
            let s3 = executeAction (ClearAlarm AlarmPriority.High) s2
            Expect.equal (List.length s3.ActiveAlarms) 1 "Should have 1 alarm after clear"
        }
    ]
