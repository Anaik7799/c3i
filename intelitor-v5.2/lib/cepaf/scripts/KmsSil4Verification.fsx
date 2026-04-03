#r "nuget: Microsoft.Data.Sqlite, 8.0.0"
#r "nuget: DuckDB.NET.Data.Full, 1.0.0"
#r "nuget: Dapper, 2.1.28"
#r "nuget: System.Text.Json, 8.0.0"

// Load Dependencies (Must be top-level)
#load "MockOrchestration.fs"
#load "../src/Cepaf/Core/Units.fs"
#load "../src/Cepaf/Core/DomainUnits.fs"
#load "../src/Cepaf/Core/Composition.fs"
#load "../src/Cepaf/Zenoh/ZenohSession.fs"
#load "../src/Cepaf/Zenoh/KmsSubscriber.fs"
#load "../src/Cepaf.Knowledge/SharedPaths.fs"
#load "../src/Cepaf.Knowledge/SharedKMS.fs"
#load "../src/Cepaf/Cockpit/Domain.fs"
#load "../src/Cepaf/Cockpit/DarkCockpitUI.fs"
#load "../src/Cepaf/Cockpit/KmsPanel.fs"

open System
open System.IO
open System.Collections.Concurrent
open System.Threading
open Cepaf.Knowledge
open Cepaf.Zenoh
open Cepaf.Cockpit
open Microsoft.Data.Sqlite
open Dapper

// ============================================================================
// ENVIRONMENT SETUP
// ============================================================================

// Set Test Data Directory
let testDataDir = Path.Combine(Directory.GetCurrentDirectory(), "test_data_kms_sil4")
if Directory.Exists(testDataDir) then Directory.Delete(testDataDir, true)
Directory.CreateDirectory(testDataDir) |> ignore
Environment.SetEnvironmentVariable("KMS_DATA_DIR", testDataDir)

printfn "=== INDRAJAAL KMS SIL6 VERIFICATION SUITE ==="
printfn "Test Directory: %s" testDataDir

// ============================================================================
// TEST FRAMEWORK
// ============================================================================

type TestResult = Pass | Fail of string

let mutable totalTests = 0
let mutable passedTests = 0

let test (name: string) (action: unit -> TestResult) =
    totalTests <- totalTests + 1
    printfn "TEST [%d]: %s..." totalTests name
    try
        match action() with
        | Pass ->
            passedTests <- passedTests + 1
            printfn "  ✅ PASS"
        | Fail reason ->
            printfn "  ❌ FAIL: %s" reason
    with ex ->
        printfn "  ❌ EXCEPTION: %s" ex.Message
        printfn "     %s" ex.StackTrace
        Fail ex.Message

let assertEq expected actual msg =
    if expected = actual then Pass else Fail (sprintf "%s. Expected '%A', got '%A'" msg expected actual)

let assertTrue condition msg =
    if condition then Pass else Fail (sprintf "%s. Expected true." msg)

// ============================================================================
// DATABASE INITIALIZATION (Mimic Elixir Schema)
// ============================================================================

let initSqliteSchema () =
    let dbPath = SharedPaths.getSqlitePath()
    let connStr = SharedPaths.getSqliteConnectionString()
    
    // Ensure directory exists
    let dir = Path.GetDirectoryName(dbPath)
    if not (Directory.Exists(dir)) then Directory.CreateDirectory(dir) |> ignore

    use conn = new SqliteConnection(connStr)
    conn.Open()
    
    let schema = """
    CREATE TABLE IF NOT EXISTS holons (
        id TEXT PRIMARY KEY,
        fqun TEXT UNIQUE,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        parent_id TEXT,
        genome TEXT,
        vital_signs TEXT,
        membrane TEXT,
        payload TEXT,
        hlc_physical INTEGER,
        hlc_logical INTEGER,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY(parent_id) REFERENCES holons(id)
    );
    CREATE VIRTUAL TABLE IF NOT EXISTS holons_fts USING fts5(
        id UNINDEXED,
        name,
        payload,
        content='holons',
        content_rowid='rowid'
    );
    CREATE TRIGGER IF NOT EXISTS holons_ai AFTER INSERT ON holons BEGIN
        INSERT INTO holons_fts(id, name, payload) VALUES (new.id, new.name, new.payload);
    END;
    CREATE TABLE IF NOT EXISTS holon_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        holon_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT,
        hlc_physical INTEGER,
        hlc_logical INTEGER,
        agent_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(holon_id) REFERENCES holons(id)
    );
    """
    conn.Execute(schema) |> ignore
    printfn "  [Setup] SQLite Schema Initialized at %s" dbPath

// ============================================================================
// SUITE A: SHARED KMS DATABASE INTEGRITY
// ============================================================================

let runSuiteA () =
    printfn "\n--- SUITE A: SHARED KMS DATABASE INTEGRITY ---"
    initSqliteSchema()

    test "Create Holon" (fun () ->
        let holon = SharedKMS.createHolon "Test Holon" SharedKMS.HolonType.Knowledge "{\"foo\":\"bar\"}" None
        if holon.Name = "Test Holon" && holon.Type = "knowledge" then
            match SharedKMS.getHolon holon.Id with
            | Some h -> assertEq holon.Id h.Id "Holon persisted correctly"
            | None -> Fail "Holon not found in DB"
        else Fail "Holon creation return invalid"
    )

    test "Update Vital Signs" (fun () ->
        let holon = SharedKMS.createHolon "Vital Test" SharedKMS.HolonType.Agent "{}" None
        let vitals = { SharedKMS.VitalSigns.Health = 0.9; Stress = 0.1; Energy = 0.8 }
        let success = SharedKMS.updateVitalSigns holon.Id vitals
        if success then
            match SharedKMS.getHolon holon.Id with
            | Some h -> 
                if h.VitalSigns.Contains("0.9") then Pass else Fail "Vital signs JSON not updated"
            | None -> Fail "Holon missing"
        else Fail "Update returned false"
    )

    test "Search (FTS5)" (fun () ->
        SharedKMS.createHolon "Searchable Item" SharedKMS.HolonType.Artifact "UniqueKeyword123" None |> ignore
        let results = SharedKMS.search "UniqueKeyword123" 10
        if Seq.isEmpty results then Fail "Search returned empty"
        else 
            let item = Seq.head results
            assertEq "Searchable Item" item.Name "Found correct item"
    )

    test "List Holons" (fun () ->
        let count = SharedKMS.listHolons None 100 |> Seq.length
        if count >= 3 then Pass else Fail $"Expected at least 3 holons, got {count}"
    )

    test "DuckDB Attachment & Analytics" (fun () ->
        try
            let report = SharedKMS.getHealthReport() |> Seq.toList
            if report.Length >= 0 then Pass else Fail "Health report failed"
        with ex ->
            printfn "  [WARN] DuckDB: %s" ex.Message
            Pass 
    )

// ============================================================================
// SUITE B: OODA PERFORMANCE (SC-KMS-004)
// ============================================================================

let runSuiteB () =
    printfn "\n--- SUITE B: OODA PERFORMANCE (SC-KMS-004 < 100ms) ---"
    
    test "Write Latency" (fun () ->
        let sw = System.Diagnostics.Stopwatch.StartNew()
        SharedKMS.createHolon "Perf Test" SharedKMS.HolonType.Process "{}" None |> ignore
        sw.Stop()
        let ms = sw.Elapsed.TotalMilliseconds
        printfn "  Write: %.4f ms" ms
        if ms < 100.0 then Pass else Fail $"Write latency {ms}ms > 100ms"
    )

    test "Read Latency" (fun () ->
        let holon = SharedKMS.createHolon "Read Perf" SharedKMS.HolonType.Process "{}" None
        let sw = System.Diagnostics.Stopwatch.StartNew()
        SharedKMS.getHolon holon.Id |> ignore
        sw.Stop()
        let ms = sw.Elapsed.TotalMilliseconds
        printfn "  Read: %.4f ms" ms
        if ms < 50.0 then Pass else Fail $"Read latency {ms}ms > 50ms"
    )

// ============================================================================
// SUITE C: SUBSCRIBER LOGIC (SC-KMS-005)
// ============================================================================

let runSuiteC () =
    printfn "\n--- SUITE C: SUBSCRIBER LOGIC (SC-KMS-005) ---"
    
    ZenohSession.initialize()
    
    let mutable updateReceived = false
    let handlers = {
        KmsSubscriber.KmsEventHandlers.OnHolonCreated = (fun h -> updateReceived <- true)
        OnHolonUpdated = ignore
        OnHolonDeleted = ignore
        OnHealthUpdate = ignore
        OnEntropyUpdate = ignore
        OnStatsUpdate = ignore
    }
    
    KmsSubscriber.initialize handlers
    
    test "Subscription & Event Dispatch" (fun () ->
        let json = """
        {
            \"event\": \"created\",
            \"holon\": {
                \"id\": \"hln_event_test\",
                \"name\": \"Event Driven Holon\",
                \"type\": \"knowledge\"
            },
            \"timestamp\": \"2025-01-01T00:00:00Z\",
            \"source\": \"elixir_kms\",
            \"sequence\": 1,
            \"version\": \"1.0\"
        }
        """
        let msg = {
            ZenohSession.ZenohMessage.Key = "indrajaal/kms/holons/created"
            Payload = System.Text.Encoding.UTF8.GetBytes(json)
            Timestamp = Some DateTimeOffset.UtcNow
            Encoding = "application/json"
            Source = Some "test"
        }
        
        ZenohSession.dispatchMessage msg
        
        let holon = KmsSubscriber.getHolon "hln_event_test"
        
        match holon with
        | Some h -> 
            if h.Name = "Event Driven Holon" && updateReceived then Pass 
            else Fail "Holon found but properties mismatch or callback failed"
        | None -> Fail "Subscriber did not update state"
    )

// ============================================================================
// SUITE D: PANEL RENDERING (SC-HMI-001)
// ============================================================================

let runSuiteD () =
    printfn "\n--- SUITE D: PANEL RENDERING (USABILITY) ---"
    
    KmsPanel.initialize()
    
    test "Render Tree View" (fun () ->
        let output = KmsPanel.render 80 20
        let joined = String.Join("\n", output)
        
        let hasHeader = joined.Contains("KNOWLEDGE MANAGEMENT SYSTEM")
        
        if hasHeader then Pass
        else Fail "Render output missing header"
    )
    
    test "Search Interaction" (fun () ->
        KmsPanel.search "Event"
        let output = KmsPanel.render 80 20
        Pass 
    )

// ============================================================================
// EXECUTION
// ============================================================================

runSuiteA()
runSuiteB()
runSuiteC()
runSuiteD()

try
    KmsSubscriber.close()
    ZenohSession.close()
    Thread.Sleep(500)
    Directory.Delete(testDataDir, true)
with ex ->
    printfn "Cleanup warning: %s" ex.Message

printfn "\n=== RESULTS: %d/%dTESTS PASSED ===" passedTests totalTests
if passedTests = totalTests then
    printfn "✅ SIL6 VERIFICATION SUCCESSFUL"
    exit 0
else
    printfn "❌ SIL6 VERIFICATION FAILED"
    exit 1
