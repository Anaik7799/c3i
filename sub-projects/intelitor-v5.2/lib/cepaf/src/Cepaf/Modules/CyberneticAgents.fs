namespace Cepaf.Modules

open System
open System.Collections.Concurrent
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Core.DomainUnits    // SC-FSH-060: Type-safe efficiency units
open Cepaf.Core.DomainPatterns // SC-FSH-050: Active patterns for agent classification

/// Cybernetic Agent Architecture (50-Agent Model)
/// Reference: GEMINI.md Section 2.0 - System Architecture
/// Compliance: SC-AGT-017 (Efficiency >90%), SC-AGT-018 (No deadlocks), SC-AGT-019 (Exec Authority)
///
/// WHAT: 50-agent hierarchical system with type-safe efficiency monitoring
/// WHY: Ensures all agents meet SC-AGT-017 threshold with compile-time safety
/// CONSTRAINTS:
///   - SC-FSH-060: All efficiency values use float<efficiency> units
///   - SC-FSH-050: Agent status uses DomainPatterns for classification
///   - SC-AGT-017: Efficiency MUST be >90% (uses Efficiency.threshold)
///   - SC-AGT-018: No deadlocks (detected via pattern matching)
module CyberneticAgents =

    // ========================================================================
    // Agent Type Definitions (Per GEMINI.md 50-Agent Model)
    // ========================================================================

    /// Agent hierarchy levels
    type AgentLevel =
        | Executive      // 1 agent - Supreme authority (AOR-EXE-001)
        | DomainSupervisor  // 10 agents - Domain-specific coordination
        | FunctionalSupervisor  // 15 agents - Functional area management
        | Worker         // 24 agents - Task execution

    /// Agent status for monitoring
    type AgentStatus =
        | Idle
        | Active of task: string
        | Blocked of reason: string
        | Failed of error: string
        | Terminated

    /// Domain categories (10 domains per GEMINI.md)
    type Domain =
        | AccessControl
        | Alarms
        | Analytics
        | Authentication
        | Compliance
        | Devices
        | Integration
        | Intelligence
        | Observability
        | Security

    /// Agent definition with type-safe efficiency (SC-FSH-060)
    type Agent = {
        Id: string
        Name: string
        Level: AgentLevel
        Domain: Domain option
        Status: AgentStatus
        Parent: string option
        Children: string list
        TaskQueue: string list
        CreatedAt: DateTimeOffset
        LastActivityAt: DateTimeOffset option
        Efficiency: float<efficiency>  // SC-AGT-017: >90% required, SC-FSH-060: Type-safe unit
    }

    // ========================================================================
    // Agent Classification (SC-FSH-050: Active Patterns)
    // ========================================================================

    /// Classify agent status using DomainPatterns
    let classifyAgentStatus (agent: Agent) =
        let statusString =
            match agent.Status with
            | Idle -> "idle"
            | Active _ -> "active"
            | Blocked _ -> "blocked"
            | Failed _ -> "failed"
            | Terminated -> "terminated"
        match statusString with
        | AgentIdle -> "IDLE"
        | AgentBusy -> "BUSY"
        | AgentBlocked -> "BLOCKED"
        | AgentFailed -> "FAILED"

    /// Classify agent efficiency using DomainPatterns (SC-AGT-017)
    let classifyEfficiency (eff: float<efficiency>) =
        let rawEff = Efficiency.toFloat eff
        match rawEff with
        | EfficiencyCompliant -> "COMPLIANT"
        | EfficiencyWarning -> "WARNING"
        | EfficiencyViolation -> "VIOLATION"

    /// Get efficiency compliance status with type safety
    let getEfficiencyStatus (agent: Agent) =
        {|
            AgentId = agent.Id
            Efficiency = agent.Efficiency
            RawValue = Efficiency.toFloat agent.Efficiency
            IsCompliant = Efficiency.isCompliant agent.Efficiency
            IsWarning = Efficiency.isWarning agent.Efficiency
            IsCritical = Efficiency.isCritical agent.Efficiency
            Classification = classifyEfficiency agent.Efficiency
        |}

    /// Agent metrics for monitoring with type-safe efficiency (SC-FSH-060)
    type AgentMetrics = {
        TotalAgents: int
        ActiveAgents: int
        IdleAgents: int
        BlockedAgents: int
        FailedAgents: int
        AverageEfficiency: float<efficiency>  // SC-FSH-060: Type-safe unit
        DeadlockDetected: bool  // SC-AGT-018
        ComplianceStatus: string  // SC-AGT-017: COMPLIANT/WARNING/VIOLATION
    }

    // ========================================================================
    // Agent Registry (Thread-Safe)
    // ========================================================================

    /// Thread-safe agent registry
    let private agents = ConcurrentDictionary<string, Agent>()

    /// Create a new agent with type-safe efficiency (SC-FSH-060)
    let createAgent (id: string) (name: string) (level: AgentLevel) (domain: Domain option) (parent: string option) : Agent =
        {
            Id = id
            Name = name
            Level = level
            Domain = domain
            Status = Idle
            Parent = parent
            Children = []
            TaskQueue = []
            CreatedAt = DateTimeOffset.UtcNow
            LastActivityAt = None
            Efficiency = Efficiency.fromFloat 100.0  // SC-FSH-060: Initialize with max efficiency
        }

    /// Register an agent in the registry
    let registerAgent (agent: Agent) =
        agents.TryAdd(agent.Id, agent) |> ignore
        agent

    /// Get an agent by ID
    let getAgent (id: string) : Agent option =
        match agents.TryGetValue(id) with
        | true, agent -> Some agent
        | false, _ -> None

    /// Update an agent's status
    let updateAgentStatus (id: string) (status: AgentStatus) =
        match agents.TryGetValue(id) with
        | true, agent ->
            let updated = { agent with Status = status; LastActivityAt = Some DateTimeOffset.UtcNow }
            agents.TryUpdate(id, updated, agent) |> ignore
            Some updated
        | false, _ -> None

    /// Update an agent's efficiency with type-safe unit (SC-FSH-060)
    let updateAgentEfficiency (id: string) (efficiency: float<efficiency>) =
        match agents.TryGetValue(id) with
        | true, agent ->
            let updated = { agent with Efficiency = efficiency; LastActivityAt = Some DateTimeOffset.UtcNow }
            agents.TryUpdate(id, updated, agent) |> ignore
            Some updated
        | false, _ -> None

    /// Update an agent's efficiency from raw float (convenience wrapper)
    let updateAgentEfficiencyRaw (id: string) (efficiencyRaw: float) =
        let typedEfficiency = Efficiency.fromFloat efficiencyRaw
        updateAgentEfficiency id typedEfficiency

    /// Get all agents
    let getAllAgents () : Agent list =
        agents.Values |> Seq.toList

    /// Clear agent registry (for testing)
    let clearAgents () =
        agents.Clear()

    // ========================================================================
    // 50-Agent Hierarchy Initialization
    // ========================================================================

    /// Initialize the complete 50-agent hierarchy
    let initializeHierarchy (logger: QuadplexLogger) =
        logger.Info("============================================================")
        logger.Info("[CYBERNETIC] Initializing 50-Agent Hierarchy")
        logger.Info("============================================================")

        clearAgents ()

        let mutable addedCount = 0

        // 1. Executive Director (1 agent)
        let executive = createAgent "EXEC-001" "Executive Director" Executive None None
        registerAgent executive |> ignore
        addedCount <- addedCount + 1
        logger.Info("[CYBERNETIC] Registered Executive Director: EXEC-001")

        // 2. Domain Supervisors (10 agents)
        let domains = [
            ("DS-ACC", "Access Control Supervisor", AccessControl)
            ("DS-ALR", "Alarms Supervisor", Alarms)
            ("DS-ANA", "Analytics Supervisor", Analytics)
            ("DS-AUT", "Authentication Supervisor", Authentication)
            ("DS-CMP", "Compliance Supervisor", Compliance)
            ("DS-DEV", "Devices Supervisor", Devices)
            ("DS-INT", "Integration Supervisor", Integration)
            ("DS-INL", "Intelligence Supervisor", Intelligence)
            ("DS-OBS", "Observability Supervisor", Observability)
            ("DS-SEC", "Security Supervisor", Security)
        ]

        for (id, name, domain) in domains do
            let supervisor = createAgent id name DomainSupervisor (Some domain) (Some "EXEC-001")
            registerAgent supervisor |> ignore
            addedCount <- addedCount + 1
            logger.Info(sprintf "[CYBERNETIC] Registered Domain Supervisor: %s (%A)" id domain)

        // 3. Functional Supervisors (15 agents)
        let functionalSupervisors = [
            ("FS-BLD", "Build Supervisor", Some Compliance)
            ("FS-TST", "Test Supervisor", Some Compliance)
            ("FS-DEP", "Deploy Supervisor", Some Integration)
            ("FS-MON", "Monitor Supervisor", Some Observability)
            ("FS-LOG", "Logging Supervisor", Some Observability)
            ("FS-MET", "Metrics Supervisor", Some Analytics)
            ("FS-AUD", "Audit Supervisor", Some Compliance)
            ("FS-VAL", "Validation Supervisor", Some Compliance)
            ("FS-SEC", "Security Scan Supervisor", Some Security)
            ("FS-NET", "Network Supervisor", Some Integration)
            ("FS-DB", "Database Supervisor", Some Integration)
            ("FS-API", "API Supervisor", Some Integration)
            ("FS-UI", "UI Supervisor", Some Devices)
            ("FS-DOC", "Documentation Supervisor", Some Compliance)
            ("FS-REL", "Release Supervisor", Some Integration)
        ]

        for (id, name, domain) in functionalSupervisors do
            let parentId =
                match domain with
                | Some d ->
                    let ds = domains |> List.tryFind (fun (_, _, dom) -> dom = d)
                    ds |> Option.map (fun (id, _, _) -> id)
                | None -> Some "EXEC-001"
            let supervisor = createAgent id name FunctionalSupervisor domain parentId
            registerAgent supervisor |> ignore
            addedCount <- addedCount + 1
            logger.Info(sprintf "[CYBERNETIC] Registered Functional Supervisor: %s" id)

        // 4. Workers (24 agents)
        let workers = [
            ("WK-001", "Compile Worker 1", Some Compliance, "FS-BLD")
            ("WK-002", "Compile Worker 2", Some Compliance, "FS-BLD")
            ("WK-003", "Test Worker 1", Some Compliance, "FS-TST")
            ("WK-004", "Test Worker 2", Some Compliance, "FS-TST")
            ("WK-005", "Test Worker 3", Some Compliance, "FS-TST")
            ("WK-006", "Deploy Worker 1", Some Integration, "FS-DEP")
            ("WK-007", "Deploy Worker 2", Some Integration, "FS-DEP")
            ("WK-008", "Monitor Worker 1", Some Observability, "FS-MON")
            ("WK-009", "Monitor Worker 2", Some Observability, "FS-MON")
            ("WK-010", "Log Worker 1", Some Observability, "FS-LOG")
            ("WK-011", "Metrics Worker 1", Some Analytics, "FS-MET")
            ("WK-012", "Metrics Worker 2", Some Analytics, "FS-MET")
            ("WK-013", "Audit Worker 1", Some Compliance, "FS-AUD")
            ("WK-014", "Validation Worker 1", Some Compliance, "FS-VAL")
            ("WK-015", "Validation Worker 2", Some Compliance, "FS-VAL")
            ("WK-016", "Security Worker 1", Some Security, "FS-SEC")
            ("WK-017", "Security Worker 2", Some Security, "FS-SEC")
            ("WK-018", "Network Worker 1", Some Integration, "FS-NET")
            ("WK-019", "Database Worker 1", Some Integration, "FS-DB")
            ("WK-020", "Database Worker 2", Some Integration, "FS-DB")
            ("WK-021", "API Worker 1", Some Integration, "FS-API")
            ("WK-022", "API Worker 2", Some Integration, "FS-API")
            ("WK-023", "UI Worker 1", Some Devices, "FS-UI")
            ("WK-024", "Release Worker 1", Some Integration, "FS-REL")
        ]

        for (id, name, domain, parent) in workers do
            let worker = createAgent id name Worker domain (Some parent)
            registerAgent worker |> ignore
            addedCount <- addedCount + 1
            logger.Info(sprintf "[CYBERNETIC] Registered Worker: %s" id)

        logger.Info("============================================================")
        logger.Info(sprintf "[CYBERNETIC] Hierarchy Initialized: %d agents" addedCount)
        logger.Info("[CYBERNETIC] - Executive: 1")
        logger.Info("[CYBERNETIC] - Domain Supervisors: 10")
        logger.Info("[CYBERNETIC] - Functional Supervisors: 15")
        logger.Info("[CYBERNETIC] - Workers: 24")
        logger.Info("============================================================")

        addedCount

    // ========================================================================
    // SC-AGT-017: Efficiency Monitoring (>90% Required)
    // ========================================================================

    /// Check if all agents meet efficiency threshold using type-safe units (SC-FSH-060, SC-AGT-017)
    let checkEfficiencyCompliance () : Result<AgentMetrics, string> =
        let allAgents = getAllAgents ()
        // Use DomainUnits.Efficiency.threshold (90%) per SC-AGT-017
        let lowEfficiency = allAgents |> List.filter (fun a -> not (Efficiency.isCompliant a.Efficiency))

        let avgEfficiency =
            if List.isEmpty allAgents then
                Efficiency.fromFloat 0.0
            else
                let sum = allAgents |> List.sumBy (fun a -> Efficiency.toFloat a.Efficiency)
                Efficiency.fromFloat (sum / float allAgents.Length)

        let complianceStatus = classifyEfficiency avgEfficiency

        if List.isEmpty lowEfficiency then
            Ok {
                TotalAgents = List.length allAgents
                ActiveAgents = allAgents |> List.filter (fun a -> match a.Status with Active _ -> true | _ -> false) |> List.length
                IdleAgents = allAgents |> List.filter (fun a -> a.Status = Idle) |> List.length
                BlockedAgents = allAgents |> List.filter (fun a -> match a.Status with Blocked _ -> true | _ -> false) |> List.length
                FailedAgents = allAgents |> List.filter (fun a -> match a.Status with Failed _ -> true | _ -> false) |> List.length
                AverageEfficiency = avgEfficiency
                DeadlockDetected = false
                ComplianceStatus = complianceStatus
            }
        else
            let violators = lowEfficiency |> List.map (fun a ->
                sprintf "%s (%.1f%% - %s)" a.Id (Efficiency.toFloat a.Efficiency) (classifyEfficiency a.Efficiency))
            Error (sprintf "SC-AGT-017 VIOLATION: Agents below %.0f%% efficiency threshold: %s"
                          (Efficiency.toFloat Efficiency.threshold)
                          (String.concat ", " violators))

    // ========================================================================
    // SC-AGT-018: Deadlock Detection
    // ========================================================================

    /// Simple deadlock detection (agents blocked waiting for each other)
    let detectDeadlock () : bool =
        let allAgents = getAllAgents ()
        let blockedAgents = allAgents |> List.filter (fun a ->
            match a.Status with Blocked _ -> true | _ -> false)

        // Simple check: if >50% of agents are blocked, likely deadlock
        let blockedRatio = float blockedAgents.Length / float (max 1 allAgents.Length)
        blockedRatio > 0.5

    // ========================================================================
    // SC-AGT-019: Executive Authority Verification
    // ========================================================================

    /// Verify executive has supreme authority
    let verifyExecutiveAuthority () : Result<unit, string> =
        match getAgent "EXEC-001" with
        | Some exec when exec.Level = Executive ->
            Ok ()
        | Some _ ->
            Error "SC-AGT-019 VIOLATION: Executive agent has incorrect level"
        | None ->
            Error "SC-AGT-019 VIOLATION: Executive agent not found"

    // ========================================================================
    // Metrics Collection
    // ========================================================================

    /// Get comprehensive agent metrics with type-safe units (SC-FSH-060)
    let getMetrics () : AgentMetrics =
        let allAgents = getAllAgents ()
        let avgEfficiency =
            if List.isEmpty allAgents then
                Efficiency.fromFloat 0.0
            else
                let sum = allAgents |> List.sumBy (fun a -> Efficiency.toFloat a.Efficiency)
                Efficiency.fromFloat (sum / float allAgents.Length)
        let complianceStatus = classifyEfficiency avgEfficiency
        {
            TotalAgents = List.length allAgents
            ActiveAgents = allAgents |> List.filter (fun a -> match a.Status with Active _ -> true | _ -> false) |> List.length
            IdleAgents = allAgents |> List.filter (fun a -> a.Status = Idle) |> List.length
            BlockedAgents = allAgents |> List.filter (fun a -> match a.Status with Blocked _ -> true | _ -> false) |> List.length
            FailedAgents = allAgents |> List.filter (fun a -> match a.Status with Failed _ -> true | _ -> false) |> List.length
            AverageEfficiency = avgEfficiency
            DeadlockDetected = detectDeadlock ()
            ComplianceStatus = complianceStatus
        }

    /// Get agent count by level
    let getCountByLevel (level: AgentLevel) : int =
        getAllAgents () |> List.filter (fun a -> a.Level = level) |> List.length

    /// Get agents by domain
    let getAgentsByDomain (domain: Domain) : Agent list =
        getAllAgents () |> List.filter (fun a -> a.Domain = Some domain)
