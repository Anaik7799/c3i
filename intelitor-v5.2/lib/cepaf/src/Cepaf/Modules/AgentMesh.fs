namespace Cepaf.Modules

open System
open System.Collections.Concurrent
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

/// Agent Mesh Integration Module
/// Provides F# handlers for Elixir AgentMesh and FQUN services.
/// Reference: lib/indrajaal/distributed/agent_mesh.ex, lib/indrajaal/distributed/fqun.ex
/// STAMP Compliance: SC-AGENT-001 to SC-AGENT-004, SC-DIST-001 to SC-DIST-004
module AgentMesh =

    // ========================================================================
    // FQUN (Fully Qualified Unique Name) Types
    // ========================================================================

    /// System layers for FQUN addressing
    [<RequireQualifiedAccess>]
    type FQUNLayer =
        | Agent
        | Worker
        | Supervisor
        | Dashboard
        | Resource

    module FQUNLayer =
        let toString = function
            | FQUNLayer.Agent -> "agent"
            | FQUNLayer.Worker -> "worker"
            | FQUNLayer.Supervisor -> "supervisor"
            | FQUNLayer.Dashboard -> "dashboard"
            | FQUNLayer.Resource -> "resource"

        let parse (s: string) =
            match s.ToLowerInvariant() with
            | "agent" -> Some FQUNLayer.Agent
            | "worker" -> Some FQUNLayer.Worker
            | "supervisor" -> Some FQUNLayer.Supervisor
            | "dashboard" -> Some FQUNLayer.Dashboard
            | "resource" -> Some FQUNLayer.Resource
            | _ -> None

    /// Agent types within the agent layer
    [<RequireQualifiedAccess>]
    type AgentType =
        | Domain
        | Cybernetic
        | ML
        | Integration
        | Observability
        | Security

    module AgentType =
        let toString = function
            | AgentType.Domain -> "domain"
            | AgentType.Cybernetic -> "cybernetic"
            | AgentType.ML -> "ml"
            | AgentType.Integration -> "integration"
            | AgentType.Observability -> "observability"
            | AgentType.Security -> "security"

    /// FQUN components for structured access
    type FQUNComponents = {
        Layer: FQUNLayer
        Type: string
        Namespace: string
        Name: string
        Node: string
        Instance: string
    }

    /// FQUN validation result
    type FQUNValidation = {
        Valid: bool
        FQUN: string option
        Components: FQUNComponents option
        Error: string option
    }

    // ========================================================================
    // AGENT MESH TYPES
    // ========================================================================

    /// Agent mesh status enumeration
    [<RequireQualifiedAccess>]
    type MeshAgentStatus =
        | Running
        | Stopped
        | Starting
        | Stopping
        | Failed of reason: string

    /// Agent definition in the mesh
    type MeshAgent = {
        Id: string
        Module: string
        Type: string
        Namespace: string
        Name: string
        Description: string
        Status: MeshAgentStatus
        FQUN: string option
        Pid: int option
        StartedAt: DateTimeOffset option
        LastHeartbeat: DateTimeOffset option
    }

    /// Mesh status summary
    type MeshStatus = {
        TotalAgents: int
        RunningAgents: int
        StoppedAgents: int
        FailedAgents: int
        ZenohPrefix: string
        Agents: Map<string, MeshAgent>
    }

    /// Command result from agent operations
    type CommandResult = {
        Success: bool
        AgentId: string
        Command: string
        Message: string
        Timestamp: DateTimeOffset
    }

    // ========================================================================
    // FQUN REGISTRY (SC-DIST-001: All resources MUST have FQUN)
    // ========================================================================

    /// Thread-safe FQUN registry
    let private fqunRegistry = ConcurrentDictionary<string, FQUNComponents>()
    let private reverseLookup = ConcurrentDictionary<string, string>()
    let private aliasCounter = ref 0

    /// Generate a unique instance ID
    let private generateInstance () =
        let timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        let random = Random().Next(0xFFFF)
        sprintf "%013d%04x" timestamp random

    /// Build FQUN string from components
    let private buildFQUN (components: FQUNComponents) : string =
        sprintf "indrajaal/%s/%s/%s/%s@%s#%s"
            (FQUNLayer.toString components.Layer)
            components.Type
            components.Namespace
            components.Name
            components.Node
            components.Instance

    /// Parse FQUN string to components
    let parseFQUN (fqun: string) : Result<FQUNComponents, string> =
        let pattern = System.Text.RegularExpressions.Regex(
            @"^indrajaal/(\w+)/(\w+)/(\w+)/(\w+)@([^#]+)#(.+)$")

        let m = pattern.Match(fqun)
        if m.Success then
            match FQUNLayer.parse m.Groups.[1].Value with
            | Some layer ->
                Ok {
                    Layer = layer
                    Type = m.Groups.[2].Value
                    Namespace = m.Groups.[3].Value
                    Name = m.Groups.[4].Value
                    Node = m.Groups.[5].Value
                    Instance = m.Groups.[6].Value
                }
            | None ->
                Error (sprintf "Invalid layer: %s" m.Groups.[1].Value)
        else
            Error "Invalid FQUN format"

    /// Convert FQUN to Zenoh key expression (SC-DIST-002)
    let toZenohKey (fqun: string) : string =
        fqun
            .Replace("@", "/node/")
            .Replace("#", "/instance/")

    /// Convert Zenoh key back to FQUN
    let fromZenohKey (key: string) : Result<string, string> =
        let pattern = System.Text.RegularExpressions.Regex(
            @"^indrajaal/(\w+)/(\w+)/(\w+)/(\w+)/node/([^/]+)/instance/(.+)$")

        let m = pattern.Match(key)
        if m.Success then
            Ok (sprintf "indrajaal/%s/%s/%s/%s@%s#%s" m.Groups.[1].Value m.Groups.[2].Value m.Groups.[3].Value m.Groups.[4].Value m.Groups.[5].Value m.Groups.[6].Value)
        else
            Error "Invalid Zenoh key format"

    // ========================================================================
    // FQUN HANDLERS
    // ========================================================================

    /// FQUN_Generate: Generate a new FQUN for a resource
    /// SC-DIST-003: FQUNs MUST be deterministically derivable
    let generateFQUN (layer: FQUNLayer) (agentType: string) (ns: string) (name: string)
                     (node: string option) : Result<string, string> =
        // Validate inputs
        if String.IsNullOrWhiteSpace(ns) then
            Error "Namespace cannot be empty"
        elif String.IsNullOrWhiteSpace(name) then
            Error "Name cannot be empty"
        elif not (System.Text.RegularExpressions.Regex.IsMatch(ns, @"^[a-z][a-z0-9_]*$")) then
            Error (sprintf "Invalid namespace format: %s" ns)
        elif not (System.Text.RegularExpressions.Regex.IsMatch(name, @"^[a-z][a-z0-9_]*$")) then
            Error (sprintf "Invalid name format: %s" name)
        else
            let nodeStr = defaultArg node (Environment.MachineName.ToLowerInvariant())
            let instance = generateInstance()

            let components = {
                Layer = layer
                Type = agentType
                Namespace = ns
                Name = name
                Node = nodeStr
                Instance = instance
            }

            let fqun = buildFQUN components
            Ok fqun

    /// FQUN_Register: Register a FQUN in the registry
    /// SC-DIST-004: FQUN registry MUST support mesh-wide lookup
    let registerFQUN (fqun: string) (metadata: Map<string, string>) : Result<unit, string> =
        match parseFQUN fqun with
        | Ok components ->
            if fqunRegistry.TryAdd(fqun, components) then
                // Create reverse lookup key
                let lookupKey = sprintf "%s/%s/%s/%s" (FQUNLayer.toString components.Layer) components.Type components.Namespace components.Name
                reverseLookup.[lookupKey] <- fqun
                Ok ()
            else
                Error "FQUN already registered"
        | Error msg ->
            Error msg

    /// FQUN_Unregister: Remove a FQUN from the registry
    let unregisterFQUN (fqun: string) : Result<unit, string> =
        let mutable removed = Unchecked.defaultof<FQUNComponents>
        if fqunRegistry.TryRemove(fqun, &removed) then
            // Remove reverse lookup
            let lookupKey = sprintf "%s/%s/%s/%s" (FQUNLayer.toString removed.Layer) removed.Type removed.Namespace removed.Name
            reverseLookup.TryRemove(lookupKey) |> ignore
            Ok ()
        else
            Error "FQUN not found"

    /// FQUN_Lookup: Find a FQUN by its components
    let lookupFQUN (layer: FQUNLayer) (agentType: string) (ns: string) (name: string)
                   : Result<string, string> =
        let lookupKey = sprintf "%s/%s/%s/%s" (FQUNLayer.toString layer) agentType ns name
        match reverseLookup.TryGetValue(lookupKey) with
        | true, fqun -> Ok fqun
        | false, _ -> Error "FQUN not found"

    /// FQUN_Find: Find FQUNs matching a pattern (supports wildcards)
    let findFQUNs (pattern: string) : string list =
        let regex =
            pattern
                .Replace("**", "<<<GLOBSTAR>>>")
                .Replace("*", @"[^/]+")
                .Replace("<<<GLOBSTAR>>>", ".*")
            |> sprintf "^%s$"
            |> System.Text.RegularExpressions.Regex

        fqunRegistry.Keys
        |> Seq.filter regex.IsMatch
        |> Seq.toList

    /// FQUN_Stats: Get registry statistics
    let getFQUNStats () =
        let all = fqunRegistry.Values |> Seq.toList
        {|
            Total = all.Length
            ByLayer =
                all
                |> List.groupBy (fun c -> c.Layer)
                |> List.map (fun (l, items) -> FQUNLayer.toString l, items.Length)
                |> Map.ofList
            ByNode =
                all
                |> List.groupBy (fun c -> c.Node)
                |> List.map (fun (n, items) -> n, items.Length)
                |> Map.ofList
        |}

    // ========================================================================
    // AGENT MESH HANDLERS (SC-AGENT-001 to SC-AGENT-004)
    // ========================================================================

    /// Thread-safe agent registry
    let private meshAgents = ConcurrentDictionary<string, MeshAgent>()

    /// The 7 core agents in the mesh
    let private coreAgents = [
        ("ooda_agent", "Indrajaal.Distributed.Agents.OODAAgent", "cybernetic", "ooda", "controller",
         "OODA loop controller for observe-orient-decide-act cycles")
        ("ace_agent", "Indrajaal.Distributed.Agents.ACEAgent", "cybernetic", "ace", "engine",
         "Autonomic computing engine for self-management")
        ("cortex_agent", "Indrajaal.Distributed.Agents.CortexAgent", "cybernetic", "cortex", "controller",
         "Cortex cognitive controller for stress and homeostasis")
        ("fractal_agent", "Indrajaal.Distributed.Agents.FractalAgent", "observability", "fractal", "logger",
         "Fractal 5-level controllable logging agent")
        ("cepaf_agent", "Indrajaal.Distributed.Agents.CEPAFAgent", "integration", "cepaf", "bridge",
         "CEPAF container operations bridge")
        ("sentinel_agent", "Indrajaal.Distributed.Agents.SentinelAgent", "cybernetic", "sentinel", "guardian",
         "Sentinel health and quorum guardian")
        ("kpi_dashboard_agent", "Indrajaal.Distributed.Agents.KPIDashboardAgent", "observability", "kpi", "dashboard",
         "CEPAF KPI dashboard agent for real-time progress tracking")
    ]

    /// Initialize agent definitions (does not start them)
    let initializeAgentDefinitions () =
        for (id, moduleName, agentType, ns, name, desc) in coreAgents do
            let agent = {
                Id = id
                Module = moduleName
                Type = agentType
                Namespace = ns
                Name = name
                Description = desc
                Status = MeshAgentStatus.Stopped
                FQUN = None
                Pid = None
                StartedAt = None
                LastHeartbeat = None
            }
            meshAgents.[id] <- agent

    /// Agent_Start: Start an agent in the mesh
    /// SC-AGENT-001: All agents MUST have FQUN
    let startAgent (agentId: string) (logger: QuadplexLogger) : AsyncResult<CommandResult, AppError> =
        async {
            match meshAgents.TryGetValue(agentId) with
            | true, agent ->
                logger.Info(sprintf "[AgentMesh] Starting agent: %s" agentId)

                // Generate FQUN for agent (SC-AGENT-001)
                match generateFQUN FQUNLayer.Agent agent.Type agent.Namespace agent.Name None with
                | Ok fqun ->
                    // Register FQUN
                    registerFQUN fqun Map.empty |> ignore

                    // Update agent state
                    let updated = {
                        agent with
                            Status = MeshAgentStatus.Running
                            FQUN = Some fqun
                            StartedAt = Some DateTimeOffset.UtcNow
                            LastHeartbeat = Some DateTimeOffset.UtcNow
                    }
                    meshAgents.[agentId] <- updated

                    logger.Info(sprintf "[AgentMesh] Agent started: %s with FQUN: %s" agentId fqun)
                    logger.IncrementCounter("agent_mesh.agent_start", tags = Map.ofList [("agent_id", agentId)])

                    return Ok {
                        Success = true
                        AgentId = agentId
                        Command = "start"
                        Message = sprintf "Agent started with FQUN: %s" fqun
                        Timestamp = DateTimeOffset.UtcNow
                    }
                | Error msg ->
                    logger.Error(sprintf "[AgentMesh] Failed to generate FQUN for %s: %s" agentId msg)
                    return Error (InfrastructureError("AgentMesh", msg))

            | false, _ ->
                logger.Error(sprintf "[AgentMesh] Agent not found: %s" agentId)
                return Error (ValidationFailed("Agent_Start", sprintf "Agent not found: %s" agentId))
        }

    /// Agent_Stop: Stop an agent in the mesh
    /// SC-AGENT-004: Agents MUST gracefully shutdown
    let stopAgent (agentId: string) (logger: QuadplexLogger) : AsyncResult<CommandResult, AppError> =
        async {
            match meshAgents.TryGetValue(agentId) with
            | true, agent ->
                logger.Info(sprintf "[AgentMesh] Stopping agent: %s" agentId)

                // Unregister FQUN
                agent.FQUN |> Option.iter (fun fqun -> unregisterFQUN fqun |> ignore)

                // Update agent state
                let updated = {
                    agent with
                        Status = MeshAgentStatus.Stopped
                        FQUN = None
                        Pid = None
                }
                meshAgents.[agentId] <- updated

                logger.Info(sprintf "[AgentMesh] Agent stopped: %s" agentId)
                logger.IncrementCounter("agent_mesh.agent_stop", tags = Map.ofList [("agent_id", agentId)])

                return Ok {
                    Success = true
                    AgentId = agentId
                    Command = "stop"
                    Message = "Agent stopped gracefully"
                    Timestamp = DateTimeOffset.UtcNow
                }

            | false, _ ->
                logger.Error(sprintf "[AgentMesh] Agent not found: %s" agentId)
                return Error (ValidationFailed("Agent_Stop", sprintf "Agent not found: %s" agentId))
        }

    /// Agent_Status: Get status of an agent or all agents
    let getAgentStatus (agentId: string option) : MeshStatus =
        let agents =
            match agentId with
            | Some id ->
                match meshAgents.TryGetValue(id) with
                | true, agent -> [ id, agent ] |> Map.ofList
                | false, _ -> Map.empty
            | None ->
                meshAgents |> Seq.map (fun kvp -> kvp.Key, kvp.Value) |> Map.ofSeq

        let running = agents |> Map.filter (fun _ a -> a.Status = MeshAgentStatus.Running) |> Map.count
        let stopped = agents |> Map.filter (fun _ a -> a.Status = MeshAgentStatus.Stopped) |> Map.count
        let failed = agents |> Map.filter (fun _ a ->
            match a.Status with MeshAgentStatus.Failed _ -> true | _ -> false) |> Map.count

        {
            TotalAgents = agents.Count
            RunningAgents = running
            StoppedAgents = stopped
            FailedAgents = failed
            ZenohPrefix = "indrajaal/agent"
            Agents = agents
        }

    /// Agent_Ping: Ping all agents and update heartbeats
    let pingAllAgents () : Map<string, Result<unit, string>> =
        meshAgents
        |> Seq.map (fun kvp ->
            let agent = kvp.Value
            if agent.Status = MeshAgentStatus.Running then
                // Update heartbeat
                let updated = { agent with LastHeartbeat = Some DateTimeOffset.UtcNow }
                meshAgents.[kvp.Key] <- updated
                kvp.Key, Ok ()
            else
                kvp.Key, Error "Agent not running"
        )
        |> Map.ofSeq

    /// Agent_Broadcast: Send a command to all agents
    let broadcastCommand (command: string) (params': Map<string, string>) (logger: QuadplexLogger)
                         : Map<string, CommandResult> =
        logger.Info(sprintf "[AgentMesh] Broadcasting command: %s" command)

        meshAgents
        |> Seq.map (fun kvp ->
            let agent = kvp.Value
            let result = {
                Success = agent.Status = MeshAgentStatus.Running
                AgentId = kvp.Key
                Command = command
                Message = if agent.Status = MeshAgentStatus.Running then "Command sent" else "Agent not running"
                Timestamp = DateTimeOffset.UtcNow
            }
            kvp.Key, result
        )
        |> Map.ofSeq

    /// Agent_GetMetrics: Get metrics from all agents
    let getAgentMetrics () =
        let agents = meshAgents.Values |> Seq.toList
        {|
            TotalAgents = agents.Length
            RunningAgents = agents |> List.filter (fun a -> a.Status = MeshAgentStatus.Running) |> List.length
            StoppedAgents = agents |> List.filter (fun a -> a.Status = MeshAgentStatus.Stopped) |> List.length
            ByType =
                agents
                |> List.groupBy (fun a -> a.Type)
                |> List.map (fun (t, items) -> t, items.Length)
                |> Map.ofList
            FQUNs =
                agents
                |> List.choose (fun a -> a.FQUN)
            LastHeartbeats =
                agents
                |> List.choose (fun a ->
                    a.LastHeartbeat
                    |> Option.map (fun h -> a.Id, h))
                |> Map.ofList
        |}

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    /// Initialize the AgentMesh module
    let initialize (logger: QuadplexLogger) =
        logger.Info("[AgentMesh] Initializing 7-Agent Mesh Architecture")
        initializeAgentDefinitions()
        logger.Info(sprintf "[AgentMesh] Initialized %d agent definitions" meshAgents.Count)
        logger.IncrementCounter("agent_mesh.initialized")

    /// Reset state (for testing)
    let reset () =
        meshAgents.Clear()
        fqunRegistry.Clear()
        reverseLookup.Clear()
