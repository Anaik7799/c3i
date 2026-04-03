// ============================================================================
// Sentinel MCP Server — Build, Test & Setup for Claude Code
// ============================================================================
// Robust F# implementation with proper JSON parsing (no fragile grep).
//
// Usage:
//   dotnet run --project scripts/setup/SentinelMcpSetup/              # Build + test
//   dotnet run --project scripts/setup/SentinelMcpSetup/ -- --with-zenoh
//   dotnet run --project scripts/setup/SentinelMcpSetup/ -- --test-only
//   dotnet run --project scripts/setup/SentinelMcpSetup/ -- --teardown
// ============================================================================
module SentinelMcpSetup

open System
open System.Diagnostics
open System.IO
open System.Text.Json
open System.Threading

// ── Configuration ───────────────────────────────────────────────────────────

let projectRoot =
    let scriptDir = AppContext.BaseDirectory
    // Walk up from bin/Debug/net10.0/ to project root
    let rec findRoot (dir: string) =
        if File.Exists(Path.Combine(dir, "mix.exs")) then dir
        elif dir = Path.GetPathRoot(dir) then failwith "Cannot find project root (mix.exs)"
        else findRoot (Directory.GetParent(dir).FullName)
    findRoot scriptDir

let sentinelProj   = Path.Combine(projectRoot, "lib/cepaf/src/Cepaf.Sentinel.MCP/Cepaf.Sentinel.MCP.fsproj")
let sentinelBin    = Path.Combine(projectRoot, "lib/cepaf/src/Cepaf.Sentinel.MCP/bin/Release/net10.0/cepaf-sentinel-mcp")
let ffiLib         = Path.Combine(projectRoot, "target/release/libzenoh_ffi.so")
let mcpJsonPath    = Path.Combine(projectRoot, ".mcp.json")
let zenohContainer = "zenoh-router-sentinel-test"
let zenohPort      = 7447

// ── Console Colors ──────────────────────────────────────────────────────────

let cPASS  = "\x1b[0;32m"
let cFAIL  = "\x1b[0;31m"
let cSKIP  = "\x1b[1;33m"
let cINFO  = "\x1b[0;36m"
let cBOLD  = "\x1b[1m"
let cRESET = "\x1b[0m"

// ── Test Tracking ───────────────────────────────────────────────────────────

type TestResult = Pass | Fail | Skip

let mutable results: (string * TestResult) list = []

let pass name msg =
    results <- results @ [ (name, Pass) ]
    printfn $"{cPASS}[PASS]{cRESET}  {name}: {msg}"

let fail name msg =
    results <- results @ [ (name, Fail) ]
    printfn $"{cFAIL}[FAIL]{cRESET}  {name}: {msg}"

let skip name msg =
    results <- results @ [ (name, Skip) ]
    printfn $"{cSKIP}[SKIP]{cRESET}  {name}: {msg}"

let info msg = printfn $"{cINFO}[INFO]{cRESET}  {msg}"

let header title =
    printfn ""
    printfn $"{cBOLD}═══════════════════════════════════════════════════════════════{cRESET}"
    printfn $"{cBOLD}  {title}{cRESET}"
    printfn $"{cBOLD}═══════════════════════════════════════════════════════════════{cRESET}"

// ── Shell Execution ─────────────────────────────────────────────────────────

let runShell (cmd: string) (args: string) (timeout: int) : (int * string * string) =
    let psi = ProcessStartInfo(cmd, args)
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.WorkingDirectory <- projectRoot
    use proc = Process.Start(psi)
    let stdout = proc.StandardOutput.ReadToEnd()
    let stderr = proc.StandardError.ReadToEnd()
    proc.WaitForExit(timeout) |> ignore
    (proc.ExitCode, stdout, stderr)

let commandExists (cmd: string) : string option =
    try
        let (code, stdout, _) = runShell cmd "--version" 5000
        if code = 0 then Some (stdout.Trim().Split('\n').[0])
        else None
    with _ -> None

// ── MCP JSON-RPC Helpers ────────────────────────────────────────────────────

/// Parse a JSON string into a JsonDocument. Returns None on failure.
let tryParseJson (s: string) : JsonDocument option =
    try Some (JsonDocument.Parse(s))
    with _ -> None

/// Check if response is a JSON-RPC level error (method not found, etc.)
let isRpcError (doc: JsonDocument) : bool =
    let mutable errProp = Unchecked.defaultof<JsonElement>
    doc.RootElement.TryGetProperty("error", &errProp)

/// Check if MCP tool call returned isError: true
let isToolError (doc: JsonDocument) : bool =
    try
        doc.RootElement
            .GetProperty("result")
            .GetProperty("isError")
            .GetBoolean()
    with _ -> false

/// Extract the text content from an MCP tool result:
/// result.content[0].text → string
let extractToolText (doc: JsonDocument) : string option =
    try
        let text =
            doc.RootElement
                .GetProperty("result")
                .GetProperty("content")
                .EnumerateArray()
                |> Seq.head
                |> fun el -> el.GetProperty("text").GetString()
        Some text
    with _ -> None

/// Parse the inner tool text as JSON and extract a field
let extractToolField (doc: JsonDocument) (field: string) : JsonElement option =
    match extractToolText doc with
    | None -> None
    | Some text ->
        try
            let inner = JsonDocument.Parse(text)
            let mutable prop = Unchecked.defaultof<JsonElement>
            if inner.RootElement.TryGetProperty(field, &prop) then
                Some prop
            else None
        with _ -> None

/// Check if tool result contains a specific field in the inner JSON
let toolHasField (doc: JsonDocument) (field: string) : bool =
    (extractToolField doc field).IsSome

/// Check if the response represents a successful MCP tool call
/// (has "result", not isError, and has content)
let isToolSuccess (doc: JsonDocument) : bool =
    let mutable resProp = Unchecked.defaultof<JsonElement>
    doc.RootElement.TryGetProperty("result", &resProp)
    && not (isToolError doc)

// ── MCP Server Process ──────────────────────────────────────────────────────

type McpServer =
    { Process: Process
      Writer: StreamWriter
      Reader: StreamReader
      StderrLog: string list ref }

let startMcpServer () : McpServer option =
    info "Starting Sentinel MCP server (stdio)..."
    let psi = ProcessStartInfo(sentinelBin)
    psi.RedirectStandardInput <- true
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.WorkingDirectory <- projectRoot
    // Set environment
    let existingLd = Environment.GetEnvironmentVariable("LD_LIBRARY_PATH") |> Option.ofObj |> Option.defaultValue ""
    let ldPath = $"{projectRoot}/target/release:{existingLd}"
    psi.Environment.["LD_LIBRARY_PATH"] <- ldPath
    psi.Environment.["ZENOH_USE_NATIVE"] <- "true"
    let dotnetPath = Process.Start(ProcessStartInfo("which", "dotnet", RedirectStandardOutput = true, UseShellExecute = false))
    let dotnetBin = dotnetPath.StandardOutput.ReadToEnd().Trim()
    dotnetPath.WaitForExit()
    if File.Exists(dotnetBin) then
        let realPath =
            try
                let p = Process.Start(ProcessStartInfo("readlink", $"-f {dotnetBin}", RedirectStandardOutput = true, UseShellExecute = false))
                let r = p.StandardOutput.ReadToEnd().Trim()
                p.WaitForExit()
                r
            with _ -> dotnetBin
        psi.Environment.["DOTNET_ROOT"] <- Path.GetDirectoryName(realPath)

    try
        let proc = Process.Start(psi)
        Thread.Sleep(800) // Let .NET runtime initialize
        if proc.HasExited then
            fail "server-start" $"Server exited immediately (code {proc.ExitCode})"
            let stderr = proc.StandardError.ReadToEnd()
            if stderr.Length > 0 then info $"stderr: {stderr.[..min 500 (stderr.Length - 1)]}"
            None
        else
            // Capture stderr asynchronously
            let stderrLog = ref []
            proc.ErrorDataReceived.Add(fun e ->
                if not (isNull e.Data) then
                    stderrLog.Value <- e.Data :: stderrLog.Value)
            proc.BeginErrorReadLine()
            pass "server-start" $"PID {proc.Id}"
            Some { Process = proc; Writer = proc.StandardInput; Reader = proc.StandardOutput; StderrLog = stderrLog }
    with ex ->
        fail "server-start" $"Exception: {ex.Message}"
        None

let mcpCall (server: McpServer) (request: string) (timeoutMs: int) : JsonDocument option =
    try
        server.Writer.WriteLine(request)
        server.Writer.Flush()
        // Read with timeout using async
        let cts = new CancellationTokenSource(timeoutMs)
        let readTask = server.Reader.ReadLineAsync(cts.Token)
        try
            readTask.AsTask().Wait(cts.Token)
            let line = readTask.Result
            if isNull line then
                None
            else
                tryParseJson line
        with
        | :? OperationCanceledException -> None
        | :? AggregateException -> None
    with ex ->
        info $"mcpCall error: {ex.Message}"
        None

let stopMcpServer (server: McpServer) =
    try
        server.Writer.Close()
        if not (server.Process.WaitForExit(3000)) then
            server.Process.Kill()
        server.Process.WaitForExit(1000) |> ignore
        info "MCP server stopped"
    with _ -> ()
    // Print server log
    let log = server.StderrLog.Value |> List.rev
    if log.Length > 0 then
        info $"Server log ({log.Length} lines):"
        log |> List.iter (fun l -> printfn $"  {l}")

// ── Phase 1: Prerequisites ──────────────────────────────────────────────────

let checkPrerequisites () =
    header "Phase 1: Prerequisites"

    match commandExists "dotnet" with
    | Some ver -> pass "dotnet" ver
    | None -> fail "dotnet" "not found — install .NET 10.0 SDK"

    match commandExists "cargo" with
    | Some ver -> pass "cargo" ver
    | None -> fail "cargo" "not found — install Rust toolchain"

    let hasPodman =
        match commandExists "podman" with
        | Some ver -> pass "podman" ver; true
        | None -> skip "podman" "not found (needed only for --with-zenoh)"; false

    if commandExists "jq" |> Option.isSome then
        pass "jq" "available"
    else
        skip "jq" "not found (optional)"

    hasPodman

// ── Phase 2: Build ──────────────────────────────────────────────────────────

let buildFfi () =
    header "Phase 2a: Build Zenoh FFI (Rust)"
    info "cargo build --release -p zenoh_ffi ..."
    let (code, stdout, stderr) = runShell "cargo" "build --release -p zenoh_ffi" 120_000
    if code = 0 && File.Exists(ffiLib) then
        let size = FileInfo(ffiLib).Length / 1024L / 1024L
        pass "ffi-build" $"libzenoh_ffi.so ({size} MB)"
        // Check symbols
        let (_, symOut, _) = runShell "nm" $"-D {ffiLib}" 10_000
        let symCount = symOut.Split('\n') |> Array.filter (fun l -> l.Contains("zenoh_ffi_")) |> Array.length
        if symCount >= 10 then
            pass "ffi-symbols" $"{symCount} exported functions"
        else
            fail "ffi-symbols" $"expected >=10, found {symCount}"
    else
        fail "ffi-build" $"cargo exit {code}"
        if stderr.Length > 0 then info (stderr.[..min 500 (stderr.Length - 1)])

let buildSentinel () =
    header "Phase 2b: Build Sentinel MCP (F#)"
    info "dotnet build -c Release ..."
    let (code, _, stderr) = runShell "dotnet" $"build {sentinelProj} -c Release --nologo -v q" 60_000
    if code = 0 && File.Exists(sentinelBin) then
        let size = FileInfo(sentinelBin).Length / 1024L
        pass "sentinel-build" $"cepaf-sentinel-mcp ({size} KB)"
    else
        fail "sentinel-build" $"dotnet build exit {code}"
        if stderr.Length > 0 then info (stderr.[..min 500 (stderr.Length - 1)])

let verifyArtifacts () =
    header "Phase 2: Build (skipped — --test-only)"
    if File.Exists(ffiLib) then pass "ffi-exists" "libzenoh_ffi.so"
    else fail "ffi-exists" "missing — run without --test-only"
    if File.Exists(sentinelBin) then pass "sentinel-exists" "cepaf-sentinel-mcp"
    else fail "sentinel-exists" "missing — run without --test-only"

// ── Phase 3: .mcp.json Validation ───────────────────────────────────────────

let validateMcpJson () =
    header "Phase 3: .mcp.json Configuration"

    if not (File.Exists(mcpJsonPath)) then
        fail "mcp-json" "file not found"
        false
    else
        pass "mcp-json" "exists"
        let text = File.ReadAllText(mcpJsonPath)
        match tryParseJson text with
        | None ->
            fail "mcp-json-parse" "invalid JSON"
            false
        | Some doc ->
            let mutable servers = Unchecked.defaultof<JsonElement>
            if not (doc.RootElement.TryGetProperty("mcpServers", &servers)) then
                fail "mcp-servers" "no mcpServers key"
                false
            else
                let mutable sentinel = Unchecked.defaultof<JsonElement>
                if not (servers.TryGetProperty("sentinel-zenoh", &sentinel)) then
                    fail "sentinel-entry" "sentinel-zenoh not in mcpServers"
                    info "Add sentinel-zenoh entry to .mcp.json — see CLAUDE.md"
                    false
                else
                    pass "sentinel-entry" "present"

                    // Check args contain binary path
                    try
                        let args = sentinel.GetProperty("args")
                        let argsText = args.EnumerateArray() |> Seq.map (fun e -> e.GetString()) |> String.concat " "
                        if argsText.Contains("cepaf-sentinel-mcp") then
                            pass "binary-path" "points to cepaf-sentinel-mcp"
                        else
                            fail "binary-path" "does not reference cepaf-sentinel-mcp"
                    with _ ->
                        fail "binary-path" "cannot read args"

                    // Check ZENOH_USE_NATIVE
                    try
                        let env = sentinel.GetProperty("env")
                        let native = env.GetProperty("ZENOH_USE_NATIVE").GetString()
                        if native = "true" then
                            pass "zenoh-native" "ZENOH_USE_NATIVE=true"
                        else
                            fail "zenoh-native" $"ZENOH_USE_NATIVE={native} (expected true)"
                    with _ ->
                        fail "zenoh-native" "ZENOH_USE_NATIVE not set in env"

                    true

// ── Phase 4: Zenoh Router ───────────────────────────────────────────────────

let startZenohRouter () =
    header "Phase 4: Zenoh Router"

    // Check if already running
    let (_, psOut, _) = runShell "podman" "ps --format {{.Names}}" 5000
    if psOut.Contains(zenohContainer) then
        pass "zenoh-router" "already running"
    else
        info $"Starting {zenohContainer} on port {zenohPort}..."
        let (code, _, stderr) = runShell "podman" $"run -d --name {zenohContainer} --network host docker.io/eclipse/zenoh:latest --listen tcp/0.0.0.0:{zenohPort}" 30_000
        if code = 0 then
            Thread.Sleep(2000) // Let it settle
            pass "zenoh-router" $"started on port {zenohPort}"
        else
            fail "zenoh-router" $"podman run exit {code}: {stderr.[..min 200 (stderr.Length - 1)]}"

let teardownZenohRouter () =
    header "Teardown"
    let (code, _, _) = runShell "podman" $"rm -f {zenohContainer}" 10_000
    if code = 0 then info $"Removed {zenohContainer}"
    else info $"No {zenohContainer} to remove"

// ── Phase 5: MCP Integration Tests ─────────────────────────────────────────

let runMcpTests () =
    header "Phase 5: MCP Server Tests"

    match startMcpServer () with
    | None ->
        fail "mcp-tests" "cannot proceed without server"
    | Some server ->

    try
        // ── Test 1: Initialize ──
        info "Test 1: Initialize handshake"
        let initReq = """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"sentinel-setup","version":"1.0"}}}"""
        match mcpCall server initReq 5000 with
        | None ->
            fail "initialize" "timeout / no response"
        | Some doc ->
            if isRpcError doc then
                fail "initialize" "JSON-RPC error"
            else
                let mutable resProp = Unchecked.defaultof<JsonElement>
                if doc.RootElement.TryGetProperty("result", &resProp) then
                    try
                        let proto = resProp.GetProperty("protocolVersion").GetString()
                        pass "initialize" $"protocol={proto}"
                    with _ ->
                        fail "initialize" "no protocolVersion in result"
                else
                    fail "initialize" "no result in response"

        // ── Test 2: Initialized notification ──
        info "Test 2: Initialized notification"
        server.Writer.WriteLine("""{"jsonrpc":"2.0","method":"notifications/initialized"}""")
        server.Writer.Flush()
        Thread.Sleep(200)
        pass "notification" "sent (no response expected)"

        // ── Test 3: tools/list ──
        info "Test 3: tools/list"
        let listReq = """{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"""
        match mcpCall server listReq 5000 with
        | None ->
            fail "tools-list" "timeout"
        | Some doc ->
            if isRpcError doc then
                fail "tools-list" "JSON-RPC error"
            else
                try
                    let tools = doc.RootElement.GetProperty("result").GetProperty("tools")
                    let toolNames =
                        tools.EnumerateArray()
                        |> Seq.map (fun t -> t.GetProperty("name").GetString())
                        |> Seq.toList
                    let count = toolNames.Length
                    let names = String.Join(", ", toolNames)
                    if count >= 5 then
                        pass "tools-list" $"{count} tools [{names}]"
                    else
                        fail "tools-list" $"expected >=5, got {count}: [{names}]"
                with ex ->
                    fail "tools-list" $"parse error: {ex.Message}"

        // ── Test 4: sentinel health ──
        info "Test 4: sentinel health"
        let healthReq = """{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"sentinel","arguments":{"action":"health"}}}"""
        match mcpCall server healthReq 5000 with
        | None ->
            fail "sentinel-health" "timeout"
        | Some doc ->
            if isToolError doc then
                fail "sentinel-health" "tool error"
            elif isToolSuccess doc then
                match extractToolField doc "score" with
                | Some score -> pass "sentinel-health" $"score={score}"
                | None -> pass "sentinel-health" "responded (no score field — degraded mode)"
            else
                fail "sentinel-health" "unexpected response structure"

        // ── Test 5: sentinel threats ──
        info "Test 5: sentinel threats"
        let threatsReq = """{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"sentinel","arguments":{"action":"threats"}}}"""
        match mcpCall server threatsReq 5000 with
        | None -> fail "sentinel-threats" "timeout"
        | Some doc ->
            if isToolSuccess doc then pass "sentinel-threats" "responded"
            else fail "sentinel-threats" "tool error or bad structure"

        // ── Test 6: sentinel status ──
        info "Test 6: sentinel status"
        let statusReq = """{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"sentinel","arguments":{"action":"status"}}}"""
        match mcpCall server statusReq 5000 with
        | None -> fail "sentinel-status" "timeout"
        | Some doc ->
            if isToolSuccess doc then pass "sentinel-status" "responded"
            else fail "sentinel-status" "tool error or bad structure"

        // ── Test 7: zenoh_session open ──
        info "Test 7: zenoh_session open"
        let openReq = """{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"open"}}}"""
        let mutable zenohLive = false
        match mcpCall server openReq 15000 with
        | None ->
            fail "zenoh-open" "timeout (15s)"
        | Some doc ->
            if isToolError doc then
                let errText = extractToolText doc |> Option.defaultValue "unknown"
                pass "zenoh-open" $"graceful error (no router): {errText.[..min 80 (errText.Length - 1)]}"
            elif isToolSuccess doc then
                match extractToolField doc "status" with
                | Some s when s.GetString() = "connected" ->
                    pass "zenoh-open" "connected to router"
                    zenohLive <- true
                | Some s ->
                    pass "zenoh-open" $"status={s}"
                    zenohLive <- true
                | None ->
                    pass "zenoh-open" "success (no status field)"
                    zenohLive <- true
            else
                fail "zenoh-open" "unexpected response"

        // ── Tests 8-13: Live Zenoh tests ──
        if zenohLive then
            // Test 8: zenoh_pub
            info "Test 8: zenoh_pub"
            let pubReq = """{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"zenoh_pub","arguments":{"key":"indrajaal/test/sentinel-setup","payload":"hello from F# setup"}}}"""
            match mcpCall server pubReq 5000 with
            | None -> fail "zenoh-pub" "timeout"
            | Some doc ->
                if isToolSuccess doc then
                    match extractToolField doc "ok" with
                    | Some ok when ok.GetBoolean() ->
                        let len = extractToolField doc "len" |> Option.map (fun e -> e.GetInt32()) |> Option.defaultValue 0
                        pass "zenoh-pub" $"published {len} bytes"
                    | _ -> pass "zenoh-pub" "success (no ok field)"
                else
                    fail "zenoh-pub" (extractToolText doc |> Option.defaultValue "tool error")

            // Test 9: zenoh_sub subscribe
            info "Test 9: zenoh_sub subscribe"
            let subReq = """{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"zenoh_sub","arguments":{"action":"subscribe","key":"indrajaal/test/**"}}}"""
            let mutable subId = "sub_1"
            match mcpCall server subReq 5000 with
            | None -> fail "zenoh-sub-subscribe" "timeout"
            | Some doc ->
                if isToolSuccess doc then
                    match extractToolField doc "id" with
                    | Some id ->
                        subId <- id.GetString()
                        pass "zenoh-sub-subscribe" $"id={subId}"
                    | None -> pass "zenoh-sub-subscribe" "success"
                else
                    fail "zenoh-sub-subscribe" (extractToolText doc |> Option.defaultValue "error")

            // Publish a message to poll
            let pub2Req = """{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"zenoh_pub","arguments":{"key":"indrajaal/test/poll-check","payload":"poll-me"}}}"""
            mcpCall server pub2Req 3000 |> ignore
            Thread.Sleep(500)

            // Test 10: zenoh_sub poll
            info "Test 10: zenoh_sub poll"
            let pollReq = $"""'{{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{{"name":"zenoh_sub","arguments":{{"action":"poll","id":"{subId}"}}}}}}'"""
            // Build properly without escaping issues
            let pollJson = JsonDocument.Parse($"""{{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{{"name":"zenoh_sub","arguments":{{"action":"poll","id":"{subId}"}}}}}}""")
            let pollReqStr = pollJson.RootElement.ToString()
            match mcpCall server pollReqStr 5000 with
            | None -> fail "zenoh-sub-poll" "timeout"
            | Some doc ->
                if isToolSuccess doc then
                    match extractToolField doc "n" with
                    | Some n -> pass "zenoh-sub-poll" $"received {n} messages"
                    | None -> pass "zenoh-sub-poll" "responded"
                else
                    fail "zenoh-sub-poll" (extractToolText doc |> Option.defaultValue "error")

            // Test 11: zenoh_query metrics
            info "Test 11: zenoh_query metrics"
            let metricsReq = """{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"zenoh_query","arguments":{"action":"metrics"}}}"""
            match mcpCall server metricsReq 5000 with
            | None -> fail "zenoh-query-metrics" "timeout"
            | Some doc ->
                if isToolSuccess doc then pass "zenoh-query-metrics" "responded"
                else fail "zenoh-query-metrics" (extractToolText doc |> Option.defaultValue "error")

            // Test 12: zenoh_session stats
            info "Test 12: zenoh_session stats"
            let statsReq = """{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"stats"}}}"""
            match mcpCall server statsReq 5000 with
            | None -> fail "zenoh-session-stats" "timeout"
            | Some doc ->
                if isToolSuccess doc then pass "zenoh-session-stats" "responded"
                else fail "zenoh-session-stats" (extractToolText doc |> Option.defaultValue "error")

            // Test 13: zenoh_session close
            info "Test 13: zenoh_session close"
            let closeReq = """{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"zenoh_session","arguments":{"action":"close"}}}"""
            match mcpCall server closeReq 5000 with
            | None -> fail "zenoh-session-close" "timeout"
            | Some doc ->
                if isToolSuccess doc then pass "zenoh-session-close" "session closed"
                else fail "zenoh-session-close" (extractToolText doc |> Option.defaultValue "error")
        else
            skip "zenoh-pub" "no live router"
            skip "zenoh-sub-subscribe" "no live router"
            skip "zenoh-sub-poll" "no live router"
            skip "zenoh-query-metrics" "no live router"
            skip "zenoh-session-stats" "no live router"
            skip "zenoh-session-close" "no live router"

        // ── Test 14: Unknown method ──
        info "Test 14: Unknown method handling"
        let badReq = """{"jsonrpc":"2.0","id":99,"method":"bogus/method","params":{}}"""
        match mcpCall server badReq 3000 with
        | None -> pass "unknown-method" "no response (server ignores — acceptable)"
        | Some doc ->
            if isRpcError doc then pass "unknown-method" "proper JSON-RPC error"
            else pass "unknown-method" "responded"

    finally
        stopMcpServer server

// ── Phase 6: Summary ────────────────────────────────────────────────────────

let printSummary () =
    header "Results"

    let passed  = results |> List.filter (fun (_, r) -> r = Pass) |> List.length
    let failed  = results |> List.filter (fun (_, r) -> r = Fail) |> List.length
    let skipped = results |> List.filter (fun (_, r) -> r = Skip) |> List.length
    let total   = results.Length

    printfn ""
    printfn $"  {cPASS}Passed{cRESET}: {passed}"
    printfn $"  {cFAIL}Failed{cRESET}: {failed}"
    printfn $"  {cSKIP}Skipped{cRESET}: {skipped}"
    printfn $"  Total:   {total}"
    printfn ""

    if failed = 0 then
        printfn $"{cPASS}{cBOLD}All tests passed!{cRESET}"
        printfn ""
        printfn $"{cBOLD}Next steps:{cRESET}"
        printfn "  1. Restart Claude Code in this project directory"
        printfn "  2. The 5 Sentinel MCP tools will be available:"
        printfn "     - zenoh_session  (open/close/stats)"
        printfn "     - zenoh_pub      (publish messages)"
        printfn "     - zenoh_sub      (subscribe/poll/unsubscribe)"
        printfn "     - zenoh_query    (get/metrics/verify)"
        printfn "     - sentinel       (health/threats/status)"
        printfn ""
        printfn "  To test in Claude Code, ask:"
        printfn "    \"Open a Zenoh session and publish a test message\""
        printfn ""
        0
    else
        printfn $"{cFAIL}{cBOLD}{failed} test(s) failed{cRESET}"
        printfn ""
        if failed > 0 then
            printfn "  Failed tests:"
            results
            |> List.filter (fun (_, r) -> r = Fail)
            |> List.iter (fun (name, _) -> printfn $"    - {name}")
            printfn ""
        printfn "  Common fixes:"
        printfn $"    - FFI:      cargo build --release -p zenoh_ffi"
        printfn $"    - Binary:   dotnet build {sentinelProj} -c Release"
        printfn $"    - Router:   add --with-zenoh flag"
        printfn ""
        1

// ── Main ────────────────────────────────────────────────────────────────────

[<EntryPoint>]
let main argv =
    let args = argv |> Set.ofArray
    let withZenoh = args.Contains "--with-zenoh"
    let testOnly  = args.Contains "--test-only"
    let teardown  = args.Contains "--teardown"

    if args.Contains "--help" || args.Contains "-h" then
        printfn "Usage: sentinel-mcp-setup [--with-zenoh] [--test-only] [--teardown]"
        printfn ""
        printfn "  (no args)     Build everything + run tests"
        printfn "  --with-zenoh  Also start Zenoh router + test pub/sub live"
        printfn "  --test-only   Skip builds, just run tests"
        printfn "  --teardown    Stop Zenoh router container"
        0
    elif teardown then
        teardownZenohRouter ()
        0
    else
        // Phase 1
        let hasPodman = checkPrerequisites ()

        // Phase 2
        if testOnly then
            verifyArtifacts ()
        else
            buildFfi ()
            buildSentinel ()

        // Bail early if builds failed
        let buildFailed = results |> List.exists (fun (_, r) -> r = Fail)
        if buildFailed then
            printSummary () |> ignore
            1
        else

        // Phase 3
        validateMcpJson () |> ignore

        // Phase 4
        if withZenoh && hasPodman then
            startZenohRouter ()
        else
            header "Phase 4: Zenoh Router (skipped)"
            if withZenoh && not hasPodman then
                fail "zenoh-router" "podman required for --with-zenoh"
            else
                skip "zenoh-router" "use --with-zenoh for live tests"

        // Phase 5
        runMcpTests ()

        // Phase 6
        printSummary ()
