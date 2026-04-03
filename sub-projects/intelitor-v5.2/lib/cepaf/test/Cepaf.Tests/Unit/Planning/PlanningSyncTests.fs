// =============================================================================
// PlanningSyncTests.fs - Planning <-> Chaya Sync Verification Tests
// =============================================================================
// STAMP: SC-SYNC-PLAN-001 to SC-SYNC-PLAN-020
// AOR: AOR-SYNC-PLAN-001 to AOR-SYNC-PLAN-015
// FMEA: FMEA-SYNC-001 to FMEA-SYNC-010
// Coverage: 100% of sync mapping, cold start, and verification logic
// =============================================================================

namespace Cepaf.Tests.Unit.Planning

open System
open Expecto
open Cepaf.Planning

// Alias to disambiguate from Cepaf DU cases with same names
type TS = Cepaf.Planning.TaskStatus
type PR = Cepaf.Planning.Priority

module PlanningSyncTests =

    // =========================================================================
    // SC-SYNC-PLAN-008: Bijective Status Enum Mapping Tests
    // =========================================================================

    [<Tests>]
    let statusMappingTests =
        testList "SC-SYNC-PLAN-008: Status Enum Mapping" [

            testCase "Pending maps to 'todo'" <| fun _ ->
                Expect.equal (Manager.planningStatusToChaya TS.Pending) "todo" "Pending -> todo"

            testCase "InProgress maps to 'in_progress'" <| fun _ ->
                Expect.equal (Manager.planningStatusToChaya TS.InProgress) "in_progress" "InProgress -> in_progress"

            testCase "Completed maps to 'done'" <| fun _ ->
                Expect.equal (Manager.planningStatusToChaya TS.Completed) "done" "Completed -> done"

            testCase "Blocked maps to 'blocked'" <| fun _ ->
                Expect.equal (Manager.planningStatusToChaya TS.Blocked) "blocked" "Blocked -> blocked"

            testCase "Unknown maps to 'todo' (safe default)" <| fun _ ->
                Expect.equal (Manager.planningStatusToChaya (TS.Unknown "weird")) "todo" "Unknown -> todo"

            testCase "All 4 known statuses have distinct Chaya values" <| fun _ ->
                let statuses = [TS.Pending; TS.InProgress; TS.Completed; TS.Blocked]
                let chayaValues = statuses |> List.map Manager.planningStatusToChaya
                let distinctCount = chayaValues |> List.distinct |> List.length
                Expect.equal distinctCount 4 "All 4 known statuses must map to distinct values"
        ]

    // =========================================================================
    // SC-SYNC-PLAN-007: Reverse Mapping (Verification Only)
    // =========================================================================

    [<Tests>]
    let reverseStatusMappingTests =
        testList "SC-SYNC-PLAN-007: Reverse Status Mapping (Verification)" [

            testCase "'todo' maps to Pending" <| fun _ ->
                Expect.equal (Manager.chayaStatusToPlanning "todo") TS.Pending "todo -> Pending"

            testCase "'in_progress' maps to InProgress" <| fun _ ->
                Expect.equal (Manager.chayaStatusToPlanning "in_progress") TS.InProgress "in_progress -> InProgress"

            testCase "'done' maps to Completed" <| fun _ ->
                Expect.equal (Manager.chayaStatusToPlanning "done") TS.Completed "done -> Completed"

            testCase "'blocked' maps to Blocked" <| fun _ ->
                Expect.equal (Manager.chayaStatusToPlanning "blocked") TS.Blocked "blocked -> Blocked"

            testCase "Unknown string maps to Unknown DU" <| fun _ ->
                match Manager.chayaStatusToPlanning "weird" with
                | TS.Unknown s -> Expect.equal s "weird" "Unknown preserves string"
                | _ -> failwith "Expected Unknown"
        ]

    // =========================================================================
    // Bijective Roundtrip Tests (TDG-SYNC-001)
    // =========================================================================

    [<Tests>]
    let bijectiveRoundtripTests =
        testList "TDG-SYNC-001: Bijective Roundtrip" [

            testCase "Forward->Reverse roundtrip for Pending" <| fun _ ->
                let result = Manager.planningStatusToChaya TS.Pending |> Manager.chayaStatusToPlanning
                Expect.equal result TS.Pending "Pending roundtrip"

            testCase "Forward->Reverse roundtrip for InProgress" <| fun _ ->
                let result = Manager.planningStatusToChaya TS.InProgress |> Manager.chayaStatusToPlanning
                Expect.equal result TS.InProgress "InProgress roundtrip"

            testCase "Forward->Reverse roundtrip for Completed" <| fun _ ->
                let result = Manager.planningStatusToChaya TS.Completed |> Manager.chayaStatusToPlanning
                Expect.equal result TS.Completed "Completed roundtrip"

            testCase "Forward->Reverse roundtrip for Blocked" <| fun _ ->
                let result = Manager.planningStatusToChaya TS.Blocked |> Manager.chayaStatusToPlanning
                Expect.equal result TS.Blocked "Blocked roundtrip"

            testCase "Reverse->Forward roundtrip for 'todo'" <| fun _ ->
                let result = Manager.chayaStatusToPlanning "todo" |> Manager.planningStatusToChaya
                Expect.equal result "todo" "todo roundtrip"

            testCase "Reverse->Forward roundtrip for 'in_progress'" <| fun _ ->
                let result = Manager.chayaStatusToPlanning "in_progress" |> Manager.planningStatusToChaya
                Expect.equal result "in_progress" "in_progress roundtrip"

            testCase "Reverse->Forward roundtrip for 'done'" <| fun _ ->
                let result = Manager.chayaStatusToPlanning "done" |> Manager.planningStatusToChaya
                Expect.equal result "done" "done roundtrip"

            testCase "Reverse->Forward roundtrip for 'blocked'" <| fun _ ->
                let result = Manager.chayaStatusToPlanning "blocked" |> Manager.planningStatusToChaya
                Expect.equal result "blocked" "blocked roundtrip"
        ]

    // =========================================================================
    // SC-SYNC-PLAN-008: Priority Mapping Tests
    // =========================================================================

    [<Tests>]
    let priorityMappingTests =
        testList "SC-SYNC-PLAN-008: Priority Mapping" [

            testCase "P0_Critical maps to 'P0'" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya PR.P0_Critical) "P0" "P0_Critical -> P0"

            testCase "P1_High maps to 'P1'" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya PR.P1_High) "P1" "P1_High -> P1"

            testCase "P2_Medium maps to 'P2'" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya PR.P2_Medium) "P2" "P2_Medium -> P2"

            testCase "P3_Low maps to 'P3'" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya PR.P3_Low) "P3" "P3_Low -> P3"

            testCase "P4_Minimal maps to 'P4'" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya PR.P4_Minimal) "P4" "P4_Minimal -> P4"

            testCase "Unknown priority maps to 'P3' (safe default)" <| fun _ ->
                Expect.equal (Manager.planningPriorityToChaya (PR.Unknown "X")) "P3" "Unknown -> P3"

            testCase "All 5 known priorities have distinct Chaya values" <| fun _ ->
                let priorities = [PR.P0_Critical; PR.P1_High; PR.P2_Medium; PR.P3_Low; PR.P4_Minimal]
                let chayaValues = priorities |> List.map Manager.planningPriorityToChaya
                let distinctCount = chayaValues |> List.distinct |> List.length
                Expect.equal distinctCount 5 "All 5 known priorities must map to distinct values"
        ]

    // =========================================================================
    // convertToChayaTask Tests
    // =========================================================================

    [<Tests>]
    let convertToChayaTaskTests =
        testList "SC-SYNC-PLAN-008: convertToChayaTask" [

            testCase "Converts all fields correctly" <| fun _ ->
                let planTask: TaskItem = {
                    Id = "test-123"
                    Title = "Test Task"
                    Status = TS.Completed
                    Priority = PR.P1_High
                    ParentId = Some "parent-1"
                    Owner = Some "agent"
                    Created = DateTime(2026, 3, 18, 12, 0, 0, DateTimeKind.Utc)
                    RawLines = ["line1"]
                }
                let chayaTask = Manager.convertToChayaTask planTask

                Expect.equal chayaTask.Id "test-123" "ID preserved"
                Expect.equal chayaTask.Title "Test Task" "Title preserved"
                Expect.equal chayaTask.Status "done" "Status mapped"
                Expect.equal chayaTask.Priority "P1" "Priority mapped"
                Expect.isNone chayaTask.Description "Description defaults to None"
                Expect.isNone chayaTask.DueDate "DueDate defaults to None"
                Expect.isNone chayaTask.AssignedNode "AssignedNode defaults to None"
                Expect.isNone chayaTask.EstimatedMinutes "EstimatedMinutes defaults to None"
                Expect.isEmpty chayaTask.Tags "Tags defaults to empty"

            testCase "CreatedAt uses UTC offset" <| fun _ ->
                let planTask: TaskItem = {
                    Id = "utc-test"
                    Title = "UTC Test"
                    Status = TS.Pending
                    Priority = PR.P3_Low
                    ParentId = None
                    Owner = None
                    Created = DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                    RawLines = []
                }
                let chayaTask = Manager.convertToChayaTask planTask
                Expect.equal chayaTask.CreatedAt.Offset TimeSpan.Zero "CreatedAt uses UTC offset"

            testCase "Handles all status values in conversion" <| fun _ ->
                let statuses = [TS.Pending; TS.InProgress; TS.Completed; TS.Blocked; TS.Unknown "x"]
                let expectedChaya = ["todo"; "in_progress"; "done"; "blocked"; "todo"]
                for (status, expected) in List.zip statuses expectedChaya do
                    let planTask: TaskItem = {
                        Id = "s-test"; Title = "t"; Status = status
                        Priority = PR.P3_Low; ParentId = None; Owner = None
                        Created = DateTime.UtcNow; RawLines = []
                    }
                    let chayaTask = Manager.convertToChayaTask planTask
                    Expect.equal chayaTask.Status expected (sprintf "Status %A -> %s" status expected)
        ]

    // =========================================================================
    // SC-SYNC-PLAN-009: Sync Idempotency Tests
    // =========================================================================

    [<Tests>]
    let idempotencyTests =
        testList "SC-SYNC-PLAN-009: Sync Idempotency" [

            testCase "Converting same task twice produces equivalent ChayaTasks" <| fun _ ->
                let planTask: TaskItem = {
                    Id = "idem-1"
                    Title = "Idempotent Test"
                    Status = TS.InProgress
                    Priority = PR.P0_Critical
                    ParentId = None
                    Owner = None
                    Created = DateTime(2026, 3, 18, 0, 0, 0, DateTimeKind.Utc)
                    RawLines = ["test"]
                }
                let first = Manager.convertToChayaTask planTask
                let second = Manager.convertToChayaTask planTask

                Expect.equal first.Id second.Id "ID idempotent"
                Expect.equal first.Title second.Title "Title idempotent"
                Expect.equal first.Status second.Status "Status idempotent"
                Expect.equal first.Priority second.Priority "Priority idempotent"
                Expect.equal first.CreatedAt second.CreatedAt "CreatedAt idempotent"

            testCase "Status mapping is deterministic" <| fun _ ->
                for _ in 1..100 do
                    Expect.equal (Manager.planningStatusToChaya TS.Completed) "done" "Deterministic"
                    Expect.equal (Manager.chayaStatusToPlanning "done") TS.Completed "Deterministic reverse"
        ]

    // =========================================================================
    // SC-SYNC-PLAN-004: Cold Start Guard Tests
    // =========================================================================

    [<Tests>]
    let coldStartGuardTests =
        testList "SC-SYNC-PLAN-004: Cold Start Guard" [

            testCase "DomainHelpers.parseStatus handles all known statuses" <| fun _ ->
                Expect.equal (DomainHelpers.parseStatus "pending") TS.Pending "pending"
                Expect.equal (DomainHelpers.parseStatus "in_progress") TS.InProgress "in_progress"
                Expect.equal (DomainHelpers.parseStatus "completed") TS.Completed "completed"
                Expect.equal (DomainHelpers.parseStatus "blocked") TS.Blocked "blocked"

            testCase "DomainHelpers.parseStatus handles case insensitivity" <| fun _ ->
                Expect.equal (DomainHelpers.parseStatus "PENDING") TS.Pending "PENDING"
                Expect.equal (DomainHelpers.parseStatus "Completed") TS.Completed "Completed"

            testCase "DomainHelpers.parseStatus unknown returns Unknown DU" <| fun _ ->
                match DomainHelpers.parseStatus "xyz_unknown" with
                | TS.Unknown s -> Expect.equal s "xyz_unknown" "Unknown preserves original string"
                | _ -> failwith "Expected Unknown"

            testCase "DomainHelpers.parsePriority handles all known priorities" <| fun _ ->
                Expect.equal (DomainHelpers.parsePriority "P0") PR.P0_Critical "P0"
                Expect.equal (DomainHelpers.parsePriority "P1") PR.P1_High "P1"
                Expect.equal (DomainHelpers.parsePriority "P2") PR.P2_Medium "P2"
                Expect.equal (DomainHelpers.parsePriority "P3") PR.P3_Low "P3"
                Expect.equal (DomainHelpers.parsePriority "P4") PR.P4_Minimal "P4"

            testCase "DomainHelpers.parsePriority unknown returns Priority.Unknown" <| fun _ ->
                match DomainHelpers.parsePriority "PX" with
                | PR.Unknown s -> Expect.equal s "PX" "Unknown preserves original string"
                | _ -> failwith "Expected Priority.Unknown"
        ]

    // =========================================================================
    // FMEA-SYNC-003: Status Enum Mismatch Prevention
    // =========================================================================

    [<Tests>]
    let fmeaStatusMismatchTests =
        testList "FMEA-SYNC-003: Status Mismatch Prevention" [

            testCase "No Planning status produces empty Chaya string" <| fun _ ->
                let allStatuses = [TS.Pending; TS.InProgress; TS.Completed; TS.Blocked; TS.Unknown "test"]
                for status in allStatuses do
                    let chaya = Manager.planningStatusToChaya status
                    Expect.isNotEmpty chaya (sprintf "Status %A must not map to empty" status)

            testCase "No Chaya status produces null Planning result" <| fun _ ->
                let allChaya = ["todo"; "in_progress"; "done"; "blocked"; "unknown_value"]
                for chaya in allChaya do
                    let planning = Manager.chayaStatusToPlanning chaya
                    Expect.isNotNull (box planning) (sprintf "Chaya '%s' must not produce null" chaya)

            testCase "All standard Chaya values are recognized (not Unknown)" <| fun _ ->
                let standard = ["todo"; "in_progress"; "done"; "blocked"]
                for chaya in standard do
                    match Manager.chayaStatusToPlanning chaya with
                    | TS.Unknown _ -> failwithf "Standard Chaya status '%s' should not map to Unknown" chaya
                    | _ -> ()

            testCase "No Priority produces empty Chaya string" <| fun _ ->
                let allPriorities = [PR.P0_Critical; PR.P1_High; PR.P2_Medium; PR.P3_Low; PR.P4_Minimal; PR.Unknown "X"]
                for p in allPriorities do
                    let chaya = Manager.planningPriorityToChaya p
                    Expect.isNotEmpty chaya (sprintf "Priority %A must not map to empty" p)
        ]

    // =========================================================================
    // SC-SYNC-PLAN-018: Task ID Format Consistency
    // =========================================================================

    [<Tests>]
    let taskIdFormatTests =
        testList "SC-SYNC-PLAN-018: ID Format Consistency" [

            testCase "convertToChayaTask preserves task ID exactly" <| fun _ ->
                let ids = ["46.1.0.0.0"; "abc12345"; "task-1"; "1"; "a"; "123.456.789"]
                for id in ids do
                    let planTask: TaskItem = {
                        Id = id; Title = "t"; Status = TS.Pending
                        Priority = PR.P3_Low; ParentId = None; Owner = None
                        Created = DateTime.UtcNow; RawLines = []
                    }
                    let chayaTask = Manager.convertToChayaTask planTask
                    Expect.equal chayaTask.Id id (sprintf "ID '%s' must be preserved exactly" id)

            testCase "convertToChayaTask preserves title exactly" <| fun _ ->
                let titles = ["Simple"; "Has Spaces"; "Has-Dashes"; "Has_Underscores"; "Has.Dots"; "Unicode: test"]
                for title in titles do
                    let planTask: TaskItem = {
                        Id = "t1"; Title = title; Status = TS.Pending
                        Priority = PR.P3_Low; ParentId = None; Owner = None
                        Created = DateTime.UtcNow; RawLines = []
                    }
                    let chayaTask = Manager.convertToChayaTask planTask
                    Expect.equal chayaTask.Title title (sprintf "Title '%s' must be preserved exactly" title)
        ]

    // =========================================================================
    // SC-SYNC-PLAN-019: Timestamp Format Tests
    // =========================================================================

    [<Tests>]
    let timestampFormatTests =
        testList "SC-SYNC-PLAN-019: Timestamp UTC" [

            testCase "CreatedAt offset is always Zero (UTC)" <| fun _ ->
                let dates = [
                    DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
                    DateTime(2025, 12, 31, 23, 59, 59, DateTimeKind.Utc)
                    DateTime.UtcNow
                ]
                for dt in dates do
                    let planTask: TaskItem = {
                        Id = "ts-test"; Title = "t"; Status = TS.Pending
                        Priority = PR.P3_Low; ParentId = None; Owner = None
                        Created = dt; RawLines = []
                    }
                    let chayaTask = Manager.convertToChayaTask planTask
                    Expect.equal chayaTask.CreatedAt.Offset TimeSpan.Zero "Must be UTC"

            testCase "CreatedAt preserves the original datetime value" <| fun _ ->
                let dt = DateTime(2026, 6, 15, 14, 30, 45, DateTimeKind.Utc)
                let planTask: TaskItem = {
                    Id = "ts-val"; Title = "t"; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = dt; RawLines = []
                }
                let chayaTask = Manager.convertToChayaTask planTask
                Expect.equal chayaTask.CreatedAt.Year 2026 "Year preserved"
                Expect.equal chayaTask.CreatedAt.Month 6 "Month preserved"
                Expect.equal chayaTask.CreatedAt.Day 15 "Day preserved"
                Expect.equal chayaTask.CreatedAt.Hour 14 "Hour preserved"
                Expect.equal chayaTask.CreatedAt.Minute 30 "Minute preserved"
                Expect.equal chayaTask.CreatedAt.Second 45 "Second preserved"
        ]

    // =========================================================================
    // SC-SYNC-PLAN-008: Unknown Status Data Loss Documentation
    // =========================================================================

    [<Tests>]
    let unknownStatusDataLossTests =
        testList "SC-SYNC-PLAN-008: Unknown Status Data Loss (Documented)" [

            testCase "Unknown status collapses to 'todo' — intentional safe default" <| fun _ ->
                // SC-SYNC-PLAN-008: Unknown(s) -> "todo" is a DOCUMENTED lossy mapping
                // The original string is NOT preserved in Chaya. This is by design.
                let original = TS.Unknown "custom_workflow_state"
                let chaya = Manager.planningStatusToChaya original
                Expect.equal chaya "todo" "Unknown collapses to todo"
                let roundtrip = Manager.chayaStatusToPlanning chaya
                Expect.equal roundtrip TS.Pending "Roundtrip loses Unknown, becomes Pending"

            testCase "Unknown priority collapses to 'P3' — intentional safe default" <| fun _ ->
                // Priority.Unknown(s) -> "P3" is a DOCUMENTED lossy mapping
                let original = PR.Unknown "urgent"
                let chaya = Manager.planningPriorityToChaya original
                Expect.equal chaya "P3" "Unknown priority collapses to P3"

            testCase "Multiple distinct Unknown strings all collapse to same Chaya value" <| fun _ ->
                let unknowns = ["foo"; "bar"; "baz"; ""; "  "]
                let chayaValues = unknowns |> List.map (fun s -> Manager.planningStatusToChaya (TS.Unknown s))
                Expect.allEqual chayaValues "todo" "All Unknown variants collapse to todo"

            testCase "Empty string Unknown is handled safely" <| fun _ ->
                let result = Manager.planningStatusToChaya (TS.Unknown "")
                Expect.equal result "todo" "Empty Unknown -> todo"

            testCase "Whitespace Unknown is handled safely" <| fun _ ->
                let result = Manager.planningStatusToChaya (TS.Unknown "   ")
                Expect.equal result "todo" "Whitespace Unknown -> todo"
        ]

    // =========================================================================
    // SC-SYNC-PLAN-014: syncTaskToChaya Error Handling
    // =========================================================================

    [<Tests>]
    let syncTaskToChayaResultTests =
        testList "SC-SYNC-PLAN-014: syncTaskToChaya Returns Result" [

            testCase "syncTaskToChaya returns Result type" <| fun _ ->
                // Verify the function signature returns Result<unit, string>
                // This can only succeed if the Chaya data directory exists.
                // In test env without data/chaya, it should return Error (not throw).
                let planTask: TaskItem = {
                    Id = "result-test"; Title = "Test"; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let result = Manager.syncTaskToChaya planTask
                // In test env, this will likely Error (no DB), which is the correct behavior
                match result with
                | Ok () -> () // If data/chaya exists, this is fine
                | Error msg ->
                    Expect.isNotEmpty msg "Error message should not be empty"
                    Expect.stringContains msg "sync task" "Error should mention sync task"
        ]

    // =========================================================================
    // DomainHelpers Edge Cases
    // =========================================================================

    [<Tests>]
    let domainHelpersEdgeCaseTests =
        testList "DomainHelpers Edge Cases" [

            testCase "parseStatus handles extra whitespace" <| fun _ ->
                Expect.equal (DomainHelpers.parseStatus "  pending  ") TS.Pending "Whitespace trimmed"
                Expect.equal (DomainHelpers.parseStatus "\tblocked\t") TS.Blocked "Tabs trimmed"

            testCase "parseStatus handles mixed case" <| fun _ ->
                Expect.equal (DomainHelpers.parseStatus "PENDING") TS.Pending "Uppercase"
                Expect.equal (DomainHelpers.parseStatus "In_Progress") TS.InProgress "Mixed case"
                Expect.equal (DomainHelpers.parseStatus "COMPLETED") TS.Completed "Uppercase completed"
                Expect.equal (DomainHelpers.parseStatus "Blocked") TS.Blocked "Title case blocked"

            testCase "parseStatus returns Unknown for unrecognized values" <| fun _ ->
                let unknownInputs = [""; "  "; "invalid"; "pendng"; "compete"]
                for input in unknownInputs do
                    match DomainHelpers.parseStatus input with
                    | TS.Unknown _ -> ()
                    | other -> failwithf "Expected Unknown for '%s', got %A" input other

            testCase "parsePriority handles extra whitespace" <| fun _ ->
                Expect.equal (DomainHelpers.parsePriority "  P0  ") PR.P0_Critical "Whitespace trimmed"
                Expect.equal (DomainHelpers.parsePriority "\tP4\t") PR.P4_Minimal "Tabs trimmed"

            testCase "parsePriority handles lowercase" <| fun _ ->
                Expect.equal (DomainHelpers.parsePriority "p0") PR.P0_Critical "lowercase p0"
                Expect.equal (DomainHelpers.parsePriority "p1") PR.P1_High "lowercase p1"
                Expect.equal (DomainHelpers.parsePriority "p2") PR.P2_Medium "lowercase p2"

            testCase "parsePriority returns Unknown for unrecognized values" <| fun _ ->
                let unknownInputs = [""; "  "; "P5"; "P9"; "high"; "critical"]
                for input in unknownInputs do
                    match DomainHelpers.parsePriority input with
                    | PR.Unknown _ -> ()
                    | other -> failwithf "Expected Priority.Unknown for '%s', got %A" input other
        ]

    // =========================================================================
    // Priority Roundtrip Tests
    // =========================================================================

    [<Tests>]
    let priorityRoundtripTests =
        testList "Priority Roundtrip" [

            testCase "All 5 known priorities roundtrip through ToString -> parsePriority" <| fun _ ->
                let priorities = [PR.P0_Critical; PR.P1_High; PR.P2_Medium; PR.P3_Low; PR.P4_Minimal]
                for p in priorities do
                    let str = p.ToString()
                    let parsed = DomainHelpers.parsePriority str
                    Expect.equal parsed p (sprintf "Priority %A roundtrips through ToString" p)

            testCase "All 4 known statuses roundtrip through ToString -> parseStatus" <| fun _ ->
                let statuses = [TS.Pending; TS.InProgress; TS.Completed; TS.Blocked]
                for s in statuses do
                    let str = s.ToString()
                    let parsed = DomainHelpers.parseStatus str
                    Expect.equal parsed s (sprintf "Status %A roundtrips through ToString" s)

            testCase "planningPriorityToChaya -> parsePriority roundtrip for all known" <| fun _ ->
                let priorities = [PR.P0_Critical; PR.P1_High; PR.P2_Medium; PR.P3_Low; PR.P4_Minimal]
                for p in priorities do
                    let chayaStr = Manager.planningPriorityToChaya p
                    let parsed = DomainHelpers.parsePriority chayaStr
                    Expect.equal parsed p (sprintf "Priority %A roundtrips through Chaya mapping" p)
        ]

    // =========================================================================
    // convertToChayaTask Field Completeness Tests
    // =========================================================================

    [<Tests>]
    let convertFieldCompletenessTests =
        testList "convertToChayaTask Field Completeness" [

            testCase "ParentId is NOT propagated (Chaya has no ParentId)" <| fun _ ->
                // Verify that having a ParentId doesn't cause errors
                let planTask: TaskItem = {
                    Id = "parent-test"; Title = "Child Task"
                    Status = TS.Pending; Priority = PR.P2_Medium
                    ParentId = Some "parent-123"; Owner = Some "agent-1"
                    Created = DateTime.UtcNow; RawLines = ["line1"; "line2"]
                }
                let chayaTask = Manager.convertToChayaTask planTask
                // ParentId, Owner, RawLines are not part of ChayaTask
                Expect.equal chayaTask.Id "parent-test" "ID preserved despite ParentId"
                Expect.equal chayaTask.Title "Child Task" "Title preserved"

            testCase "Minimum viable TaskItem converts without error" <| fun _ ->
                let minimal: TaskItem = {
                    Id = "min"; Title = ""; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.MinValue; RawLines = []
                }
                let chayaTask = Manager.convertToChayaTask minimal
                Expect.equal chayaTask.Id "min" "Minimal ID preserved"
                Expect.equal chayaTask.Title "" "Empty title preserved"
                Expect.equal chayaTask.Status "todo" "Minimal status mapped"

            testCase "Long title preserves all content" <| fun _ ->
                let longTitle = String.replicate 100 "Long Title Segment "
                let planTask: TaskItem = {
                    Id = "long-t"; Title = longTitle; Status = TS.InProgress
                    Priority = PR.P1_High; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let chayaTask = Manager.convertToChayaTask planTask
                Expect.equal chayaTask.Title longTitle "Long title preserved completely"

            testCase "Special characters in title preserved" <| fun _ ->
                let special = "Task with 'quotes', \"double quotes\", <angle>, & ampersand"
                let planTask: TaskItem = {
                    Id = "spec-t"; Title = special; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let chayaTask = Manager.convertToChayaTask planTask
                Expect.equal chayaTask.Title special "Special chars preserved"

            testCase "All priority values produce valid Chaya priority strings" <| fun _ ->
                let allPriorities = [PR.P0_Critical; PR.P1_High; PR.P2_Medium; PR.P3_Low; PR.P4_Minimal; PR.Unknown "X"]
                let expectedStrings = ["P0"; "P1"; "P2"; "P3"; "P4"; "P3"]
                for (p, expected) in List.zip allPriorities expectedStrings do
                    let planTask: TaskItem = {
                        Id = "pri-t"; Title = "t"; Status = TS.Pending
                        Priority = p; ParentId = None; Owner = None
                        Created = DateTime.UtcNow; RawLines = []
                    }
                    let chayaTask = Manager.convertToChayaTask planTask
                    Expect.equal chayaTask.Priority expected (sprintf "Priority %A -> %s" p expected)
        ]

    // =========================================================================
    // Reverse Mapping Edge Cases (SC-SYNC-PLAN-007)
    // =========================================================================

    [<Tests>]
    let reverseEdgeCaseTests =
        testList "SC-SYNC-PLAN-007: Reverse Mapping Edge Cases" [

            testCase "Empty string maps to Unknown" <| fun _ ->
                match Manager.chayaStatusToPlanning "" with
                | TS.Unknown s -> Expect.equal s "" "Empty string preserved in Unknown"
                | _ -> failwith "Expected Unknown for empty string"

            testCase "Whitespace-only maps to Unknown" <| fun _ ->
                match Manager.chayaStatusToPlanning "   " with
                | TS.Unknown s -> Expect.equal s "   " "Whitespace preserved in Unknown"
                | _ -> failwith "Expected Unknown for whitespace"

            testCase "Case-sensitive: 'TODO' maps to Unknown (not Pending)" <| fun _ ->
                match Manager.chayaStatusToPlanning "TODO" with
                | TS.Unknown s -> Expect.equal s "TODO" "Uppercase TODO is Unknown"
                | _ -> failwith "Expected Unknown for uppercase TODO"

            testCase "Case-sensitive: 'Done' maps to Unknown (not Completed)" <| fun _ ->
                match Manager.chayaStatusToPlanning "Done" with
                | TS.Unknown s -> Expect.equal s "Done" "Title-case Done is Unknown"
                | _ -> failwith "Expected Unknown for Done"
        ]

    // =========================================================================
    // SC-ZTEST-008: Zenoh Dual-Write Integration Tests
    // =========================================================================

    [<Tests>]
    let zenohAdapterTests =
        testList "SC-ZTEST-008: Zenoh Adapter Integration" [

            testCase "TaskCreated event serializes to valid JSON" <| fun _ ->
                let task: TaskItem = {
                    Id = "z-test-1"; Title = "Zenoh Test"
                    Status = TS.Pending; Priority = PR.P1_High
                    ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.TaskCreated task)
                Expect.stringContains json "\"type\":\"TaskCreated\"" "Contains type field"
                Expect.stringContains json "\"id\":\"z-test-1\"" "Contains task ID"
                Expect.stringContains json "\"title\":\"Zenoh Test\"" "Contains title"
                Expect.stringContains json "\"status\":\"pending\"" "Contains status"
                Expect.stringContains json "\"priority\":\"P1\"" "Contains priority"

            testCase "TaskUpdated event serializes to valid JSON" <| fun _ ->
                let task: TaskItem = {
                    Id = "z-test-2"; Title = "Updated"
                    Status = TS.Completed; Priority = PR.P0_Critical
                    ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.TaskUpdated task)
                Expect.stringContains json "\"type\":\"TaskUpdated\"" "Contains type"
                Expect.stringContains json "\"status\":\"completed\"" "Contains updated status"

            testCase "TaskCompleted event serializes to valid JSON" <| fun _ ->
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.TaskCompleted "done-123")
                Expect.stringContains json "\"type\":\"TaskCompleted\"" "Contains type"
                Expect.stringContains json "\"id\":\"done-123\"" "Contains ID"

            testCase "SyncStarted event serializes to valid JSON" <| fun _ ->
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.SyncStarted 42)
                Expect.stringContains json "\"type\":\"SyncStarted\"" "Contains type"
                Expect.stringContains json "\"task_count\":42" "Contains task count"

            testCase "SyncCompleted event serializes with success flag" <| fun _ ->
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.SyncCompleted (10, 0, 0))
                Expect.stringContains json "\"type\":\"SyncCompleted\"" "Contains type"
                Expect.stringContains json "\"synced\":10" "Contains synced count"
                Expect.stringContains json "\"errors\":0" "Contains error count"
                Expect.stringContains json "\"success\":true" "Success flag true when 0 errors"

            testCase "SyncCompleted event marks failure when errors > 0" <| fun _ ->
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.SyncCompleted (10, 2, 1))
                Expect.stringContains json "\"success\":false" "Success flag false with errors"
                Expect.stringContains json "\"errors\":2" "Error count"
                Expect.stringContains json "\"mismatches\":1" "Mismatch count"

            testCase "SyncFailed event escapes quotes in reason" <| fun _ ->
                let json = ZenohAdapter.serializeEvent (ZenohAdapter.SyncFailed "DB \"connection\" failed")
                Expect.stringContains json "\"type\":\"SyncFailed\"" "Contains type"
                Expect.stringContains json "\\\"connection\\\"" "Quotes escaped in reason"

            testCase "All event types have unique checkpoint IDs (SC-ZTEST-001)" <| fun _ ->
                let dummyTask: TaskItem = {
                    Id = "cp-test"; Title = "t"; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let events = [
                    ZenohAdapter.TaskCreated dummyTask
                    ZenohAdapter.TaskUpdated dummyTask
                    ZenohAdapter.TaskCompleted "x"
                    ZenohAdapter.SyncStarted 0
                    ZenohAdapter.SyncCompleted (0, 0, 0)
                    ZenohAdapter.SyncFailed "err"
                ]
                let checkpointIds = events |> List.map ZenohAdapter.getCheckpointId
                let distinct = checkpointIds |> List.distinct
                Expect.equal distinct.Length events.Length "All checkpoint IDs must be unique"

            testCase "Checkpoint IDs follow CP-{DOMAIN}-{NN} format (SC-ZTEST-013)" <| fun _ ->
                let dummyTask: TaskItem = {
                    Id = "fmt-test"; Title = "t"; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let events = [
                    ZenohAdapter.TaskCreated dummyTask
                    ZenohAdapter.TaskUpdated dummyTask
                    ZenohAdapter.TaskCompleted "x"
                    ZenohAdapter.SyncStarted 0
                    ZenohAdapter.SyncCompleted (0, 0, 0)
                    ZenohAdapter.SyncFailed "err"
                ]
                for event in events do
                    let cpId = ZenohAdapter.getCheckpointId event
                    Expect.isTrue (cpId.StartsWith("CP-PLAN")) (sprintf "Checkpoint '%s' must start with CP-PLAN" cpId)

            testCase "Task events use planning topic, sync events use sync topic" <| fun _ ->
                let dummyTask: TaskItem = {
                    Id = "topic-test"; Title = "t"; Status = TS.Pending
                    Priority = PR.P3_Low; ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.TaskCreated dummyTask)) "indrajaal/planning/events" "TaskCreated topic"
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.TaskUpdated dummyTask)) "indrajaal/planning/events" "TaskUpdated topic"
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.TaskCompleted "x")) "indrajaal/planning/events" "TaskCompleted topic"
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.SyncStarted 0)) "indrajaal/planning/sync" "SyncStarted topic"
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.SyncCompleted (0, 0, 0))) "indrajaal/planning/sync" "SyncCompleted topic"
                Expect.equal (ZenohAdapter.getTopic (ZenohAdapter.SyncFailed "x")) "indrajaal/planning/sync" "SyncFailed topic"

            testCase "Topics have depth <= 6 levels (SC-ZTEST-017)" <| fun _ ->
                let topics = [
                    ZenohAdapter.getTopic (ZenohAdapter.TaskCreated { Id = "x"; Title = "t"; Status = TS.Pending; Priority = PR.P3_Low; ParentId = None; Owner = None; Created = DateTime.UtcNow; RawLines = [] })
                    ZenohAdapter.getTopic (ZenohAdapter.SyncStarted 0)
                ]
                for topic in topics do
                    let depth = topic.Split('/').Length
                    Expect.isLessThanOrEqual depth 6 (sprintf "Topic '%s' has %d levels (max 6)" topic depth)

            testCase "publish fires without exception (SC-ZTEST-004: non-blocking)" <| fun _ ->
                let task: TaskItem = {
                    Id = "fire-test"; Title = "Non-blocking test"
                    Status = TS.InProgress; Priority = PR.P2_Medium
                    ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                // These should not throw — they use fire-and-forget
                ZenohAdapter.publish (ZenohAdapter.TaskCreated task)
                ZenohAdapter.publish (ZenohAdapter.TaskUpdated task)
                ZenohAdapter.publish (ZenohAdapter.TaskCompleted "fire-test")
                ZenohAdapter.publish (ZenohAdapter.SyncStarted 1)
                ZenohAdapter.publish (ZenohAdapter.SyncCompleted (1, 0, 0))
                ZenohAdapter.publish (ZenohAdapter.SyncFailed "test failure")

            testCase "tryPublish returns Ok for all event types" <| fun _ ->
                let task: TaskItem = {
                    Id = "try-test"; Title = "Result test"
                    Status = TS.Blocked; Priority = PR.P4_Minimal
                    ParentId = None; Owner = None
                    Created = DateTime.UtcNow; RawLines = []
                }
                let events = [
                    ZenohAdapter.TaskCreated task
                    ZenohAdapter.TaskUpdated task
                    ZenohAdapter.TaskCompleted "try-test"
                    ZenohAdapter.SyncStarted 5
                    ZenohAdapter.SyncCompleted (5, 0, 0)
                    ZenohAdapter.SyncFailed "intentional"
                ]
                for event in events do
                    match ZenohAdapter.tryPublish event with
                    | Ok () -> ()
                    | Error msg -> failwithf "tryPublish failed for %A: %s" event msg
        ]

    // =========================================================================
    // Aggregate test list for registration
    // =========================================================================

    [<Tests>]
    let allPlanningSyncTests =
        testList "Planning <-> Chaya Sync" [
            statusMappingTests
            reverseStatusMappingTests
            bijectiveRoundtripTests
            priorityMappingTests
            convertToChayaTaskTests
            idempotencyTests
            coldStartGuardTests
            fmeaStatusMismatchTests
            taskIdFormatTests
            timestampFormatTests
            unknownStatusDataLossTests
            syncTaskToChayaResultTests
            domainHelpersEdgeCaseTests
            priorityRoundtripTests
            convertFieldCompletenessTests
            reverseEdgeCaseTests
            zenohAdapterTests
        ]
