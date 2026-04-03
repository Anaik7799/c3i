module Cepaf.Tests.Unit.Cockpit.FSharpDAPTests

open System
open Expecto

module DAP = Cepaf.Cockpit.FSharpDAP

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let freshSession () = DAP.createSession ()

let makeRequest seq cmd args : DAP.DapRequest =
    { Seq = seq; Command = cmd; Arguments = args }

// ---------------------------------------------------------------------------
// createSession
// ---------------------------------------------------------------------------

[<Tests>]
let createSessionTests =
    testList "DAP-SESSION: createSession" [

        test "DAP-SESSION-001: createSession returns Initialized = false" {
            let session = freshSession ()
            Expect.isFalse session.Initialized "New session must not be initialized"
        }

        test "DAP-SESSION-002: createSession returns Launched = false" {
            let session = freshSession ()
            Expect.isFalse session.Launched "New session must not be launched"
        }

        test "DAP-SESSION-003: createSession returns empty breakpoints list" {
            let session = freshSession ()
            Expect.isEmpty session.Breakpoints "New session must have empty breakpoints"
        }

        test "DAP-SESSION-004: createSession returns None for CurrentFrame" {
            let session = freshSession ()
            Expect.isNone session.CurrentFrame "New session CurrentFrame must be None"
        }

        test "DAP-SESSION-005: createSession generates unique SessionId" {
            let s1 = freshSession ()
            let s2 = freshSession ()
            Expect.notEqual s1.SessionId s2.SessionId "Each session must have a unique SessionId"
        }

        test "DAP-SESSION-006: SessionId is non-empty" {
            let session = freshSession ()
            Expect.isTrue (session.SessionId.Length > 0) "SessionId must be non-empty"
        }
    ]

// ---------------------------------------------------------------------------
// handleInitialize
// ---------------------------------------------------------------------------

[<Tests>]
let handleInitializeTests =
    testList "DAP-INIT: handleInitialize" [

        test "DAP-INIT-001: handleInitialize sets Initialized = true" {
            let session = freshSession ()
            let (updated, _) = DAP.handleInitialize session
            Expect.isTrue updated.Initialized "After Initialize, session must be Initialized = true"
        }

        test "DAP-INIT-002: handleInitialize response Success = true" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            Expect.isTrue response.Success "Initialize response must have Success = true"
        }

        test "DAP-INIT-003: handleInitialize response Command = initialize" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            Expect.equal response.Command "initialize" "Initialize response Command must be 'initialize'"
        }

        test "DAP-INIT-004: handleInitialize response Body contains capabilities" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            Expect.isSome response.Body "Initialize response must have a Body"
            Expect.stringContains response.Body.Value "supportsBreakpoints"
                "Initialize body must advertise supportsBreakpoints capability"
        }
    ]

// ---------------------------------------------------------------------------
// handleLaunch
// ---------------------------------------------------------------------------

[<Tests>]
let handleLaunchTests =
    testList "DAP-LAUNCH: handleLaunch" [

        test "DAP-LAUNCH-001: handleLaunch sets Launched = true" {
            let session = freshSession ()
            let (updated, _) = DAP.handleLaunch session None
            Expect.isTrue updated.Launched "After Launch, session must be Launched = true"
        }

        test "DAP-LAUNCH-002: handleLaunch response Success = true" {
            let session = freshSession ()
            let (_, response) = DAP.handleLaunch session None
            Expect.isTrue response.Success "Launch response must have Success = true"
        }

        test "DAP-LAUNCH-003: handleLaunch with args also succeeds" {
            let session = freshSession ()
            let args = Some """{"program":"/usr/bin/fsi","args":[]}"""
            let (updated, response) = DAP.handleLaunch session args
            Expect.isTrue updated.Launched "Launch with args must set Launched = true"
            Expect.isTrue response.Success "Launch with args must succeed"
        }
    ]

// ---------------------------------------------------------------------------
// handleSetBreakpoints
// ---------------------------------------------------------------------------

[<Tests>]
let handleSetBreakpointsTests =
    testList "DAP-BP: handleSetBreakpoints" [

        test "DAP-BP-001: handleSetBreakpoints with no args returns Ok response" {
            let session = freshSession ()
            let (_, response) = DAP.handleSetBreakpoints session None
            Expect.isTrue response.Success "SetBreakpoints with no args must succeed"
        }

        test "DAP-BP-002: handleSetBreakpoints with valid JSON adds breakpoints to session" {
            let session = freshSession ()
            let args = Some """{"source":{"path":"/src/Foo.fs"},"breakpoints":[{"line":10},{"line":25}]}"""
            let (updated, response) = DAP.handleSetBreakpoints session (Some args.Value)
            Expect.isTrue response.Success "SetBreakpoints must succeed"
            Expect.equal updated.Breakpoints.Length 2 "Two breakpoints must be registered"
        }

        test "DAP-BP-003: breakpoints have Verified = true" {
            let session = freshSession ()
            let args = """{"source":{"path":"/src/Bar.fs"},"breakpoints":[{"line":5}]}"""
            let (updated, _) = DAP.handleSetBreakpoints session (Some args)
            Expect.isTrue (updated.Breakpoints |> List.forall (fun bp -> bp.Verified))
                "All stub breakpoints must be Verified"
        }

        test "DAP-BP-004: response Body contains breakpoints array" {
            let session = freshSession ()
            let args = """{"source":{"path":"/src/Baz.fs"},"breakpoints":[{"line":1}]}"""
            let (_, response) = DAP.handleSetBreakpoints session (Some args)
            Expect.isSome response.Body "SetBreakpoints response must have Body"
            Expect.stringContains response.Body.Value "breakpoints"
                "Response body must contain breakpoints key"
        }
    ]

// ---------------------------------------------------------------------------
// handleEvaluate
// ---------------------------------------------------------------------------

[<Tests>]
let handleEvaluateTests =
    testList "DAP-EVAL: handleEvaluate" [

        test "DAP-EVAL-001: handleEvaluate returns Ok response" {
            let session = freshSession ()
            let (_, response) = DAP.handleEvaluate session "1 + 1"
            Expect.isTrue response.Success "Evaluate must succeed"
        }

        test "DAP-EVAL-002: handleEvaluate does not mutate session" {
            let session = freshSession ()
            let (updated, _) = DAP.handleEvaluate session "someExpr"
            Expect.equal updated.SessionId session.SessionId "Evaluate must not change SessionId"
            Expect.equal updated.Initialized session.Initialized "Evaluate must not change Initialized"
        }

        test "DAP-EVAL-003: evaluate response body contains stub result" {
            let session = freshSession ()
            let (_, response) = DAP.handleEvaluate session "x + y"
            Expect.isSome response.Body "Evaluate response must have Body"
            Expect.stringContains response.Body.Value "stub" "Evaluate body must contain stub marker"
        }
    ]

// ---------------------------------------------------------------------------
// handleRequest (dispatch)
// ---------------------------------------------------------------------------

[<Tests>]
let handleRequestTests =
    testList "DAP-DISPATCH: handleRequest" [

        test "DAP-DISPATCH-001: Initialize request sets Initialized" {
            let session = freshSession ()
            let req = makeRequest 1 DAP.DapCommand.Initialize None
            let (updated, response) = DAP.handleRequest session req
            Expect.isTrue updated.Initialized "Dispatched Initialize must set Initialized"
            Expect.isTrue response.Success "Dispatched Initialize must succeed"
        }

        test "DAP-DISPATCH-002: response RequestSeq mirrors request Seq" {
            let session = freshSession ()
            let req = makeRequest 42 DAP.DapCommand.Initialize None
            let (_, response) = DAP.handleRequest session req
            Expect.equal response.RequestSeq 42 "Response RequestSeq must mirror request Seq"
        }

        test "DAP-DISPATCH-003: Disconnect resets session state" {
            let session = { freshSession () with Initialized = true; Launched = true }
            let req = makeRequest 5 DAP.DapCommand.Disconnect None
            let (updated, response) = DAP.handleRequest session req
            Expect.isFalse updated.Initialized "Disconnect must reset Initialized"
            Expect.isFalse updated.Launched    "Disconnect must reset Launched"
            Expect.isTrue response.Success     "Disconnect must succeed"
        }

        test "DAP-DISPATCH-004: Continue response has allThreadsContinued body" {
            let session = freshSession ()
            let req = makeRequest 3 DAP.DapCommand.Continue None
            let (_, response) = DAP.handleRequest session req
            Expect.isTrue response.Success "Continue must succeed"
            Expect.isSome response.Body "Continue must have body"
            Expect.stringContains response.Body.Value "allThreadsContinued"
                "Continue body must contain allThreadsContinued"
        }
    ]

// ---------------------------------------------------------------------------
// Capabilities
// ---------------------------------------------------------------------------

[<Tests>]
let capabilitiesTests =
    testList "DAP-CAP: Capabilities" [

        test "DAP-CAP-001: supportsBreakpoints is true" {
            Expect.isTrue DAP.Capabilities.supportsBreakpoints
                "supportsBreakpoints must be true"
        }

        test "DAP-CAP-002: toJson returns valid JSON" {
            let json = DAP.Capabilities.toJson ()
            Expect.isTrue (json.TrimStart().StartsWith("{"))
                "Capabilities JSON must be a valid object"
        }

        test "DAP-CAP-003: toJson contains supportsBreakpoints" {
            let json = DAP.Capabilities.toJson ()
            Expect.stringContains json "supportsBreakpoints"
                "Capabilities JSON must contain supportsBreakpoints"
        }
    ]

// ---------------------------------------------------------------------------
// parseRequest
// ---------------------------------------------------------------------------

[<Tests>]
let parseRequestTests =
    testList "DAP-PARSE: parseRequest" [

        test "DAP-PARSE-001: valid initialize JSON parses successfully" {
            let json = """{"seq":1,"type":"request","command":"initialize"}"""
            let result = DAP.parseRequest json
            Expect.isOk result "Valid initialize JSON must parse successfully"
        }

        test "DAP-PARSE-002: empty string returns Error" {
            let result = DAP.parseRequest ""
            Expect.isError result "Empty request must return Error"
        }

        test "DAP-PARSE-003: whitespace-only string returns Error" {
            let result = DAP.parseRequest "   "
            Expect.isError result "Whitespace-only request must return Error"
        }

        test "DAP-PARSE-004: unknown command returns Error" {
            let json = """{"seq":1,"type":"request","command":"unknownCmd999"}"""
            let result = DAP.parseRequest json
            Expect.isError result "Unknown command must return Error"
        }

        test "DAP-PARSE-005: missing seq field returns Error" {
            let json = """{"type":"request","command":"initialize"}"""
            let result = DAP.parseRequest json
            Expect.isError result "Missing seq field must return Error"
        }

        test "DAP-PARSE-006: parsed request has correct command" {
            let json = """{"seq":7,"type":"request","command":"launch"}"""
            match DAP.parseRequest json with
            | Ok req -> Expect.equal req.Command DAP.DapCommand.Launch "Parsed command must be Launch"
            | Error e -> failtest (sprintf "Unexpected parse error: %s" e)
        }
    ]

// ---------------------------------------------------------------------------
// toJson (serialization)
// ---------------------------------------------------------------------------

[<Tests>]
let toJsonTests =
    testList "DAP-JSON: toJson" [

        test "DAP-JSON-001: toJson returns valid JSON object" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            let json = DAP.toJson response
            Expect.isTrue (json.TrimStart().StartsWith("{")) "toJson must return JSON object"
        }

        test "DAP-JSON-002: toJson includes type:response field" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            let json = DAP.toJson response
            Expect.stringContains json "\"type\":\"response\"" "JSON must contain type:response"
        }

        test "DAP-JSON-003: toJson includes success field" {
            let session = freshSession ()
            let (_, response) = DAP.handleInitialize session
            let json = DAP.toJson response
            Expect.stringContains json "\"success\":true" "JSON must contain success:true"
        }
    ]

// ---------------------------------------------------------------------------
// Aggregate
// ---------------------------------------------------------------------------

[<Tests>]
let allFSharpDAPTests =
    testList "FSharp DAP" [
        createSessionTests
        handleInitializeTests
        handleLaunchTests
        handleSetBreakpointsTests
        handleEvaluateTests
        handleRequestTests
        capabilitiesTests
        parseRequestTests
        toJsonTests
    ]
