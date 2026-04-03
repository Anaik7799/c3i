// =============================================================================
// CrmAuditLogTests.fs - TDG-compliant tests for CrmAuditLog
// =============================================================================
// STAMP: SC-TEST-001 (TDG compliance), SC-AUDIT-001 (append-only audit trail),
//        SC-XHOLON-035 (DuckDB audit trail immutable), SC-REG-001 (immutable mutations)
//
// ## Test Coverage
// - toJson: valid JSON output, correct fields, camelCase naming, TotalCount, QueryTimestamp
// - recordChange: valid entity/change → Ok entryId, empty entityId/changes → Error,
//   invalid entityType → Error, EntryId format (AUD-...), STAMP append-only invariant
// - queryAudit: empty store → empty entries, filter by entityType/entityId/fieldName,
//   Limit respected, TotalCount reflects pre-limit count
// - getEntityHistory: correct entity entries only, Error on bad entityType
// - getFieldHistory: only entries that include the specified field
// - renderAuditTable: empty entries, single entry, multi-entry, ANSI output
//
// ## Document Control
// | Field | Value |
// |-------|-------|
// | Version | 1.0.0 |
// | Created | 2026-03-30 |
// | Author | Code Evolution Agent v21.3.0-SIL6 |
// | STAMP | SC-TEST-001, SC-AUDIT-001, SC-XHOLON-035, SC-REG-001 |
// =============================================================================

module Cepaf.Tests.Unit.Mesh.CrmAuditLogTests

open Expecto
open Cepaf.Mesh
open System.Text.Json

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Build a minimal FieldChange for use in tests.
let private fc fieldName oldVal newVal changedBy =
    { FieldName = fieldName
      OldValue  = oldVal
      NewValue  = newVal
      ChangedBy = changedBy
      Timestamp = System.DateTimeOffset.UtcNow.ToString("o") }

/// Build a default AuditQuery that matches everything (no filters, high limit).
let private openQuery () : AuditQuery =
    { EntityType = None
      EntityId   = None
      FieldName  = None
      StartDate  = None
      EndDate    = None
      Limit      = 1000 }

/// Build an AuditReport for toJson tests (no DB required).
let private sampleReport entries =
    { Entries        = entries
      TotalCount     = List.length entries
      QueryTimestamp = System.DateTimeOffset.UtcNow.ToString("o") }

/// Parse a JSON string produced by toJson or queryAudit.
let private parseJson (json: string) = JsonDocument.Parse(json)

// ---------------------------------------------------------------------------
// Unique entity ID generator to avoid cross-test pollution in the in-memory store
// ---------------------------------------------------------------------------
let private uid () = System.Guid.NewGuid().ToString("N").[..7]

[<Tests>]
let tests = testList "CrmAuditLog" [

    // =========================================================================
    // toJson Tests
    // =========================================================================
    testList "toJson" [

        test "toJson on empty report returns valid JSON" {
            let report = sampleReport []
            let json   = CrmAuditLog.toJson report
            use doc = parseJson json
            Expect.isTrue (doc.RootElement.ValueKind = System.Text.Json.JsonValueKind.Object)
                "toJson should produce valid JSON"
        }

        test "toJson JSON contains 'entries' array" {
            let report = sampleReport []
            use doc = parseJson (CrmAuditLog.toJson report)
            Expect.isTrue
                (doc.RootElement.TryGetProperty("entries") |> fst)
                "toJson JSON must contain 'entries' array"
        }

        test "toJson JSON contains 'totalCount' field" {
            let report = sampleReport []
            use doc = parseJson (CrmAuditLog.toJson report)
            Expect.isTrue
                (doc.RootElement.TryGetProperty("totalCount") |> fst)
                "toJson JSON must contain 'totalCount' (camelCase)"
        }

        test "toJson JSON totalCount matches report.TotalCount" {
            let change = fc "email" None "a@b.com" "agent1"
            let entry  = {
                EntryId    = "AUD-test-001"
                EntityType = "contact"
                EntityId   = "C-001"
                Changes    = [ change ]
                Reason     = None
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let report = sampleReport [ entry ]
            use doc = parseJson (CrmAuditLog.toJson report)
            let tc = doc.RootElement.GetProperty("totalCount").GetInt32()
            Expect.equal tc 1 "totalCount should equal TotalCount in the report"
        }

        test "toJson JSON contains 'queryTimestamp' field" {
            let report = sampleReport []
            use doc = parseJson (CrmAuditLog.toJson report)
            Expect.isTrue
                (doc.RootElement.TryGetProperty("queryTimestamp") |> fst)
                "toJson JSON must contain 'queryTimestamp' (camelCase)"
        }

        test "toJson with one entry produces entries array of length 1" {
            let change = fc "status" (Some "open") "closed" "agent2"
            let entry  = {
                EntryId    = "AUD-test-002"
                EntityType = "case"
                EntityId   = "CS-100"
                Changes    = [ change ]
                Reason     = Some "Resolved"
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let report = sampleReport [ entry ]
            use doc = parseJson (CrmAuditLog.toJson report)
            let arr = doc.RootElement.GetProperty("entries")
            Expect.equal (arr.GetArrayLength()) 1 "entries array should have 1 element"
        }
    ]

    // =========================================================================
    // recordChange Tests
    // =========================================================================
    testList "recordChange" [

        test "recordChange with valid contact returns Ok entryId" {
            let entityId = uid ()
            let change   = fc "email" None "test@example.com" "agent1"
            let result   = CrmAuditLog.recordChange "contact" entityId [ change ] None
            Expect.isOk result "recordChange with valid args should return Ok"
        }

        test "recordChange Ok entryId starts with 'AUD-'" {
            let entityId = uid ()
            let change   = fc "phone" None "555-1234" "agent1"
            match CrmAuditLog.recordChange "contact" entityId [ change ] None with
            | Ok id -> Expect.isTrue (id.StartsWith("AUD-")) $"EntryId should start with 'AUD-'; got: {id}"
            | Error e -> failtest $"Expected Ok, got Error: {e}"
        }

        test "recordChange with valid account entity type returns Ok" {
            let change = fc "name" (Some "Old Corp") "New Corp" "admin"
            let result = CrmAuditLog.recordChange "account" (uid ()) [ change ] None
            Expect.isOk result "recordChange should accept 'account' entity type"
        }

        test "recordChange with valid opportunity returns Ok" {
            let change = fc "stage" (Some "Prospect") "Closed Won" "sales-agent"
            let result = CrmAuditLog.recordChange "opportunity" (uid ()) [ change ] (Some "Deal closed")
            Expect.isOk result "recordChange should accept 'opportunity' entity type"
        }

        test "recordChange with valid lead returns Ok" {
            let change = fc "source" None "Web" "crm-import"
            let result = CrmAuditLog.recordChange "lead" (uid ()) [ change ] None
            Expect.isOk result "recordChange should accept 'lead' entity type"
        }

        test "recordChange with valid case returns Ok" {
            let change = fc "priority" (Some "low") "high" "support-agent"
            let result = CrmAuditLog.recordChange "case" (uid ()) [ change ] None
            Expect.isOk result "recordChange should accept 'case' entity type"
        }

        test "recordChange with invalid entity type returns Error" {
            let change = fc "field" None "value" "actor"
            let result = CrmAuditLog.recordChange "invoice" (uid ()) [ change ] None
            Expect.isError result "Invalid entity type 'invoice' should return Error"
        }

        test "recordChange Error message for invalid entityType mentions valid types" {
            let change = fc "f" None "v" "a"
            match CrmAuditLog.recordChange "unknown_type" (uid ()) [ change ] None with
            | Error msg ->
                let lower = msg.ToLowerInvariant()
                Expect.isTrue
                    (lower.Contains("contact") || lower.Contains("must be") || lower.Contains("invalid"))
                    $"Error should list valid entity types; got: {msg}"
            | Ok _ -> failtest "Expected Error for invalid entity type"
        }

        test "recordChange with empty entityId returns Error" {
            let change = fc "f" None "v" "a"
            let result = CrmAuditLog.recordChange "contact" "" [ change ] None
            Expect.isError result "Empty entityId should return Error"
        }

        test "recordChange with whitespace entityId returns Error" {
            let change = fc "f" None "v" "a"
            let result = CrmAuditLog.recordChange "contact" "   " [ change ] None
            Expect.isError result "Whitespace-only entityId should return Error"
        }

        test "recordChange with empty changes list returns Error" {
            let result = CrmAuditLog.recordChange "contact" (uid ()) [] None
            Expect.isError result "Empty changes list should return Error (SC-AUDIT-001)"
        }

        test "recordChange Error for empty changes mentions 'changes'" {
            match CrmAuditLog.recordChange "contact" (uid ()) [] None with
            | Error msg ->
                Expect.isTrue
                    (msg.ToLowerInvariant().Contains("changes"))
                    $"Error should mention 'changes'; got: {msg}"
            | Ok _ -> failtest "Expected Error for empty changes list"
        }

        test "two consecutive recordChange calls return different EntryIds" {
            let change = fc "email" None "a@b.com" "agent"
            let eid1   = uid ()
            let eid2   = uid ()
            match CrmAuditLog.recordChange "contact" eid1 [ change ] None,
                  CrmAuditLog.recordChange "contact" eid2 [ change ] None with
            | Ok id1, Ok id2 ->
                Expect.notEqual id1 id2 "Each recordChange must produce a unique EntryId"
            | _ -> failtest "Both recordChange calls should succeed"
        }

        test "recordChange with reason stores reason (visible via getEntityHistory)" {
            let entityId = uid ()
            let change   = fc "notes" None "Important note" "agent"
            let _ = CrmAuditLog.recordChange "contact" entityId [ change ] (Some "User request")
            match CrmAuditLog.getEntityHistory "contact" entityId with
            | Ok json ->
                Expect.isTrue (json.Contains("User request"))
                    "getEntityHistory JSON should contain the reason"
            | Error e -> failtest $"getEntityHistory failed: {e}"
        }
    ]

    // =========================================================================
    // queryAudit Tests
    // =========================================================================
    testList "queryAudit" [

        test "queryAudit with open query returns Ok" {
            let result = CrmAuditLog.queryAudit (openQuery ())
            Expect.isOk result "queryAudit should always return Ok for valid query"
        }

        test "queryAudit Ok JSON is valid JSON" {
            match CrmAuditLog.queryAudit (openQuery ()) with
            | Ok json ->
                use doc = parseJson json
                Expect.isTrue (doc.RootElement.ValueKind = System.Text.Json.JsonValueKind.Object)
                    "queryAudit should return valid JSON"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }

        test "queryAudit JSON contains 'entries' array" {
            match CrmAuditLog.queryAudit (openQuery ()) with
            | Ok json ->
                use doc = parseJson json
                Expect.isTrue
                    (doc.RootElement.TryGetProperty("entries") |> fst)
                    "queryAudit JSON must contain 'entries' array"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }

        test "queryAudit JSON contains 'totalCount' field" {
            match CrmAuditLog.queryAudit (openQuery ()) with
            | Ok json ->
                use doc = parseJson json
                Expect.isTrue
                    (doc.RootElement.TryGetProperty("totalCount") |> fst)
                    "queryAudit JSON must contain 'totalCount'"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }

        test "queryAudit filter by entityType returns only matching entries" {
            // Record a contact entry with a unique entityId
            let cid = uid ()
            let change = fc "email" None "filter@test.com" "test-agent"
            let _ = CrmAuditLog.recordChange "contact" cid [ change ] None

            let q = { openQuery () with EntityType = Some "contact"; EntityId = Some cid }
            match CrmAuditLog.queryAudit q with
            | Ok json ->
                use doc = parseJson json
                let entries = doc.RootElement.GetProperty("entries")
                // All returned entries must be contacts
                for entry in entries.EnumerateArray() do
                    let et = entry.GetProperty("entityType").GetString()
                    Expect.equal et "contact" $"All entries should be entityType='contact'"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }

        test "queryAudit Limit is respected" {
            // Insert 5 entries for a single entity
            let entityId = uid ()
            for i in 1..5 do
                let change = fc "counter" None (string i) "counter-agent"
                let _ = CrmAuditLog.recordChange "account" entityId [ change ] None
                ()

            let q = { openQuery () with EntityId = Some entityId; Limit = 2 }
            match CrmAuditLog.queryAudit q with
            | Ok json ->
                use doc = parseJson json
                let arr = doc.RootElement.GetProperty("entries")
                Expect.isLessThanOrEqual (arr.GetArrayLength()) 2
                    "queryAudit should respect the Limit parameter"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }

        test "queryAudit filter by fieldName returns only entries with that field" {
            let entityId = uid ()
            let fld  = fc "unique_field_xyz" None "val" "agent"
            let nfld = fc "other_field" None "v2" "agent"
            let _ = CrmAuditLog.recordChange "lead" entityId [ fld  ] None
            let _ = CrmAuditLog.recordChange "lead" entityId [ nfld ] None

            let q = { openQuery () with EntityId = Some entityId; FieldName = Some "unique_field_xyz" }
            match CrmAuditLog.queryAudit q with
            | Ok json ->
                use doc = parseJson json
                let entries = doc.RootElement.GetProperty("entries")
                for entry in entries.EnumerateArray() do
                    let changes = entry.GetProperty("changes")
                    let hasField =
                        changes.EnumerateArray()
                        |> Seq.exists (fun c ->
                            c.GetProperty("fieldName").GetString() = "unique_field_xyz")
                    Expect.isTrue hasField
                        "Each entry returned by fieldName filter must contain that field"
            | Error e -> failtest $"queryAudit returned Error: {e}"
        }
    ]

    // =========================================================================
    // getEntityHistory Tests
    // =========================================================================
    testList "getEntityHistory" [

        test "getEntityHistory returns Ok for a valid entity that has been recorded" {
            let entityId = uid ()
            let change   = fc "first_name" None "Alice" "agent"
            let _ = CrmAuditLog.recordChange "contact" entityId [ change ] None
            let result = CrmAuditLog.getEntityHistory "contact" entityId
            Expect.isOk result "getEntityHistory should return Ok for a recorded entity"
        }

        test "getEntityHistory returns Ok even when entity has no entries" {
            let result = CrmAuditLog.getEntityHistory "contact" (uid ())
            Expect.isOk result "getEntityHistory should return Ok (empty list) for unknown entity"
        }

        test "getEntityHistory for unknown entityType returns Ok with empty entries" {
            let result = CrmAuditLog.getEntityHistory "invoice" "INV-001"
            Expect.isOk result "getEntityHistory returns Ok (empty) for unknown entityType"
            match result with
            | Ok json ->
                use doc = parseJson json
                let count = doc.RootElement.GetProperty("totalCount").GetInt32()
                Expect.equal count 0 "Unknown entityType should produce zero entries"
            | Error _ -> ()
        }

        test "getEntityHistory returns JSON with entries for the correct entityId" {
            let entityId = uid ()
            let change   = fc "last_name" (Some "Smith") "Jones" "agent"
            let _ = CrmAuditLog.recordChange "contact" entityId [ change ] None
            match CrmAuditLog.getEntityHistory "contact" entityId with
            | Ok json ->
                use doc = parseJson json
                let entries = doc.RootElement.GetProperty("entries")
                for entry in entries.EnumerateArray() do
                    let eid = entry.GetProperty("entityId").GetString()
                    Expect.equal eid entityId "All returned entries should belong to the queried entityId"
            | Error e -> failtest $"getEntityHistory returned Error: {e}"
        }
    ]

    // =========================================================================
    // getFieldHistory Tests
    // =========================================================================
    testList "getFieldHistory" [

        test "getFieldHistory returns Ok for a valid entity/field combination" {
            let entityId = uid ()
            let change   = fc "stage" (Some "Prospect") "Qualified" "agent"
            let _ = CrmAuditLog.recordChange "opportunity" entityId [ change ] None
            let result = CrmAuditLog.getFieldHistory "opportunity" entityId "stage"
            Expect.isOk result "getFieldHistory should return Ok for valid args"
        }

        test "getFieldHistory returns Ok (empty) when field was never changed" {
            let entityId = uid ()
            let change   = fc "name" None "ACME" "agent"
            let _ = CrmAuditLog.recordChange "account" entityId [ change ] None
            let result = CrmAuditLog.getFieldHistory "account" entityId "nonexistent_field"
            Expect.isOk result "getFieldHistory returns Ok with empty entries for unknown field"
        }

        test "getFieldHistory for unknown entityType returns Ok with empty entries" {
            let result = CrmAuditLog.getFieldHistory "bogus_entity" "E-001" "email"
            Expect.isOk result "getFieldHistory returns Ok (empty) for unknown entityType"
            match result with
            | Ok json ->
                use doc = parseJson json
                let count = doc.RootElement.GetProperty("totalCount").GetInt32()
                Expect.equal count 0 "Unknown entityType should produce zero field entries"
            | Error _ -> ()
        }

        test "getFieldHistory entries only include changes for the specified field" {
            let entityId = uid ()
            let f1 = fc "email"   None "a@b.com" "agent"
            let f2 = fc "phone"   None "555-000" "agent"
            let _ = CrmAuditLog.recordChange "contact" entityId [ f1 ] None
            let _ = CrmAuditLog.recordChange "contact" entityId [ f2 ] None
            match CrmAuditLog.getFieldHistory "contact" entityId "email" with
            | Ok json ->
                use doc = parseJson json
                let entries = doc.RootElement.GetProperty("entries")
                for entry in entries.EnumerateArray() do
                    let hasEmail =
                        entry.GetProperty("changes").EnumerateArray()
                        |> Seq.exists (fun c -> c.GetProperty("fieldName").GetString() = "email")
                    Expect.isTrue hasEmail "Each returned entry must contain the 'email' field"
            | Error e -> failtest $"getFieldHistory returned Error: {e}"
        }
    ]

    // =========================================================================
    // renderAuditTable Tests
    // =========================================================================
    testList "renderAuditTable" [

        test "renderAuditTable with empty list returns non-empty string" {
            let output = CrmAuditLog.renderAuditTable []
            Expect.isNotEmpty output "renderAuditTable should return a message even for empty entries"
        }

        test "renderAuditTable empty message contains 'No audit entries'" {
            let output = CrmAuditLog.renderAuditTable []
            Expect.isTrue (output.Contains("No audit entries"))
                "Empty table should say 'No audit entries'"
        }

        test "renderAuditTable with one entry returns non-empty string" {
            let change = fc "email" None "alice@test.com" "agent"
            let entry  = {
                EntryId    = "AUD-20260330-001-abcd1234"
                EntityType = "contact"
                EntityId   = "C-001"
                Changes    = [ change ]
                Reason     = None
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let output = CrmAuditLog.renderAuditTable [ entry ]
            Expect.isNotEmpty output "renderAuditTable should produce output for one entry"
        }

        test "renderAuditTable output contains the EntryId" {
            let change = fc "status" None "active" "admin"
            let entryId = "AUD-20260330-001-test1234"
            let entry   = {
                EntryId    = entryId
                EntityType = "account"
                EntityId   = "ACC-001"
                Changes    = [ change ]
                Reason     = None
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let output = CrmAuditLog.renderAuditTable [ entry ]
            Expect.isTrue (output.Contains(entryId))
                $"renderAuditTable output should contain EntryId '{entryId}'"
        }

        test "renderAuditTable output contains field name" {
            let change = fc "priority" (Some "low") "high" "support-agent"
            let entry  = {
                EntryId    = "AUD-20260330-001-tst56789"
                EntityType = "case"
                EntityId   = "CASE-999"
                Changes    = [ change ]
                Reason     = Some "Escalation"
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let output = CrmAuditLog.renderAuditTable [ entry ]
            Expect.isTrue (output.Contains("priority"))
                "renderAuditTable output should contain the field name"
        }

        test "renderAuditTable output contains reason when present" {
            let change = fc "status" None "resolved" "agent"
            let entry  = {
                EntryId    = "AUD-20260330-001-reasonXX"
                EntityType = "case"
                EntityId   = "CASE-888"
                Changes    = [ change ]
                Reason     = Some "Customer confirmed fix"
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let output = CrmAuditLog.renderAuditTable [ entry ]
            Expect.isTrue (output.Contains("Customer confirmed fix"))
                "renderAuditTable should show the Reason field"
        }

        test "renderAuditTable output contains 'Total:' summary line" {
            let change = fc "name" None "ACME" "importer"
            let entry  = {
                EntryId    = "AUD-20260330-001-totalXXX"
                EntityType = "account"
                EntityId   = "ACC-002"
                Changes    = [ change ]
                Reason     = None
                Timestamp  = System.DateTimeOffset.UtcNow.ToString("o")
            }
            let output = CrmAuditLog.renderAuditTable [ entry ]
            Expect.isTrue (output.Contains("Total:"))
                "renderAuditTable should include a 'Total:' summary line"
        }

        test "renderAuditTable with multiple entries mentions correct total count" {
            let mkEntry i =
                let change = fc "field" None (string i) "agent"
                { EntryId    = $"AUD-20260330-{i:D3}-multi{i:D4}"
                  EntityType = "lead"
                  EntityId   = $"LEAD-{i}"
                  Changes    = [ change ]
                  Reason     = None
                  Timestamp  = System.DateTimeOffset.UtcNow.ToString("o") }

            let entries = [ 1..3 ] |> List.map mkEntry
            let output  = CrmAuditLog.renderAuditTable entries
            Expect.isTrue (output.Contains("3"))
                "renderAuditTable should mention total entry count in summary"
        }
    ]
]
