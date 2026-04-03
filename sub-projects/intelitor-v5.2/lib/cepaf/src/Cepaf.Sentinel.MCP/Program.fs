namespace Cepaf.Sentinel.MCP

open System
open System.Text.Json
open Cepaf.Sentinel.MCP.Protocol
open Cepaf.Sentinel.MCP.Tools

/// MCP Server entry point — stdio JSON-RPC 2.0 transport.
///
/// Implements the Model Context Protocol for Claude Code integration:
///   1. Reads JSON-RPC lines from stdin
///   2. Dispatches to Zenoh or Sentinel tool handlers
///   3. Writes JSON-RPC responses to stdout
///   4. Logs diagnostics to stderr (never stdout)
///
/// Lifecycle:
///   initialize → notifications/initialized → tools/list → tools/call* → (exit)
///
/// STAMP: SC-ZEN-001 (Zenoh unified IPC), SC-PRAJNA-004 (Sentinel integration)
/// AOR: AOR-SYNC-007 (Sentinel health sync)
module Program =

    /// Write a response line to stdout (MCP transport)
    let private respond (line: string) =
        Console.Out.WriteLine(line)
        Console.Out.Flush()

    /// Log to stderr (diagnostic, never visible to MCP client protocol)
    let private log (msg: string) =
        Console.Error.WriteLine(sprintf "[sentinel-zenoh-mcp] %s" msg)
        Console.Error.Flush()

    /// Build the tools/list response combining all tool modules
    let private handleToolsList (id: JsonElement option) : string =
        let allTools =
            (ZenohTools.toolDefinitions @
             SentinelTools.toolDefinitions @
             TestTools.toolDefinitions @
             MultiverseTools.toolDefinitions @
             CpuGovernorTools.toolDefinitions @
             ContainerVerificationTools.toolDefinitions @
             SwarmVerificationTools.toolDefinitions)
            |> List.map (fun t ->
                {| name = t.Name
                   description = t.Description
                   inputSchema = t.InputSchema |})
        let result = {| tools = allTools |}
        McpProtocol.successResponse id result

    /// Dispatch a tools/call request
    let private handleToolsCall
        (zenohState: ZenohTools.SessionState)
        (sentinelState: SentinelTools.SentinelState)
        (testState: TestTools.TestToolsState)
        (multiverseState: MultiverseTools.MultiverseState)
        (cpuGovState: CpuGovernorTools.GovernorState)
        (containerVerifyState: ContainerVerificationTools.VerificationState)
        (swarmVerifyState: SwarmVerificationTools.SwarmVerificationState)
        (id: JsonElement option)
        (params': JsonElement option)
        : string =
        match McpProtocol.extractToolCall params' with
        | Error e ->
            McpProtocol.invalidParams id e
        | Ok (toolName, args) ->
            log (sprintf "tools/call: %s" toolName)

            // Dispatch chain: Zenoh → Sentinel → Test → Multiverse → CpuGovernor → ContainerVerification
            match ZenohTools.dispatch zenohState toolName args id with
            | Some response -> response
            | None ->
                match SentinelTools.dispatch sentinelState zenohState.SessionHandle toolName args id with
                | Some response -> response
                | None ->
                    match TestTools.dispatch testState toolName args id with
                    | Some response -> response
                    | None ->
                        match MultiverseTools.dispatch multiverseState toolName args id with
                        | Some response -> response
                        | None ->
                            match CpuGovernorTools.dispatch cpuGovState zenohState.SessionHandle toolName args id with
                            | Some response -> response
                            | None ->
                                match ContainerVerificationTools.dispatch containerVerifyState toolName args id with
                                | Some response -> response
                                | None ->
                                    match SwarmVerificationTools.dispatch swarmVerifyState toolName args id with
                                    | Some response -> response
                                    | None ->
                                        McpProtocol.methodNotFound id (sprintf "tool: %s" toolName)

    /// Main request dispatcher
    let private handleRequest
        (zenohState: ZenohTools.SessionState)
        (sentinelState: SentinelTools.SentinelState)
        (testState: TestTools.TestToolsState)
        (multiverseState: MultiverseTools.MultiverseState)
        (cpuGovState: CpuGovernorTools.GovernorState)
        (containerVerifyState: ContainerVerificationTools.VerificationState)
        (swarmVerifyState: SwarmVerificationTools.SwarmVerificationState)
        (req: McpProtocol.McpRequest)
        : string option =
        match req.Method with
        | "initialize" ->
            Some (McpProtocol.initializeResponse req.Id)

        | "notifications/initialized" ->
            // Client acknowledgment — no response required (notification)
            log "Client initialized."
            None

        | "tools/list" ->
            Some (handleToolsList req.Id)

        | "tools/call" ->
            Some (handleToolsCall zenohState sentinelState testState multiverseState cpuGovState containerVerifyState swarmVerifyState req.Id req.Params)

        | method' when method'.StartsWith("notifications/") ->
            // All notifications are fire-and-forget (no response)
            log (sprintf "Notification: %s" method')
            None

        | method' ->
            // Unknown method — only respond if it has an id (request vs notification)
            match req.Id with
            | Some _ -> Some (McpProtocol.methodNotFound req.Id method')
            | None -> None

    /// Main stdio loop
    [<EntryPoint>]
    let main _argv =
        log "Starting Indrajaal Sentinel+Zenoh MCP Server v21.3.1"
        log (sprintf "PID: %d | FFI available: %b" (Environment.ProcessId) (Cepaf.Zenoh.Core.ZenohFfiBridge.isAvailable()))

        let zenohState = ZenohTools.createState()
        let sentinelState = SentinelTools.createState()
        let testState = TestTools.createState()
        let multiverseState = MultiverseTools.createState()
        let cpuGovState = CpuGovernorTools.createState()
        let containerVerifyState = ContainerVerificationTools.createState()
        let swarmVerifyState = SwarmVerificationTools.createState()

        try
            let mutable running = true

            while running do
                let line = Console.In.ReadLine()

                if isNull line then
                    // EOF — client closed stdin
                    log "EOF received, shutting down."
                    running <- false
                elif line.Trim().Length = 0 then
                    () // Skip empty lines
                else
                    match McpProtocol.parseRequest line with
                    | Ok req ->
                        match handleRequest zenohState sentinelState testState multiverseState cpuGovState containerVerifyState swarmVerifyState req with
                        | Some response -> respond response
                        | None -> () // Notification — no response
                    | Error e ->
                        log (sprintf "Parse error: %s" e)
                        // JSON-RPC parse error
                        let errResp = McpProtocol.errorResponse None -32700 (sprintf "Parse error: %s" e)
                        respond errResp
        finally
            // Cleanup
            log "Cleaning up..."

            // Close Zenoh session and subscriptions
            if zenohState.SessionHandle <> nativeint 0 then
                zenohState.Subscriptions |> Map.iter (fun _ subHandle ->
                    Cepaf.Zenoh.Core.ZenohFfiBridge.unsubscribe subHandle)
                Cepaf.Zenoh.Core.ZenohFfiBridge.closeSession zenohState.SessionHandle
                log "Zenoh session closed."

            // Stop Sentinel bridge
            SentinelTools.shutdown sentinelState
            log "Sentinel bridge stopped."

            log "Shutdown complete."

        0
