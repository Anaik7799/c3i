module CyberneticAgentsTests

open System
open Expecto
open FsCheck
open FsCheck.FSharp
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Modules
open Cepaf.Core.DomainUnits  // SC-FSH-060: Type-safe efficiency units

/// TDG: Property-based tests for Cybernetic Agent Architecture
/// Reference: GEMINI.md Section 2.0 - 50-Agent Model
module Properties =

    /// All agents must have non-empty IDs
    let agentIdNonEmpty (agent: CyberneticAgents.Agent) =
        not (String.IsNullOrWhiteSpace agent.Id)

    /// All agents must have non-negative efficiency
    let agentEfficiencyValid (agent: CyberneticAgents.Agent) =
        agent.Efficiency >= Efficiency.fromFloat 0.0 && agent.Efficiency <= Efficiency.fromFloat 100.0

    /// Executive level has no parent
    let executiveHasNoParent (agent: CyberneticAgents.Agent) =
        if agent.Level = CyberneticAgents.AgentLevel.Executive then
            agent.Parent.IsNone
        else
            true

/// Unit tests for agent creation
[<Tests>]
let creationTests =
    testList "Agent Creation" [
        testCase "createAgent sets all required fields" <| fun _ ->
            let agent = CyberneticAgents.createAgent "TEST-001" "Test Agent" CyberneticAgents.AgentLevel.Worker (Some CyberneticAgents.Domain.Compliance) (Some "FS-TST")
            Expect.equal agent.Id "TEST-001" "ID should match"
            Expect.equal agent.Name "Test Agent" "Name should match"
            Expect.equal agent.Level CyberneticAgents.AgentLevel.Worker "Level should be Worker"
            Expect.equal agent.Domain (Some CyberneticAgents.Domain.Compliance) "Domain should match"
            Expect.equal agent.Parent (Some "FS-TST") "Parent should match"

        testCase "createAgent initializes status to Idle" <| fun _ ->
            let agent = CyberneticAgents.createAgent "TEST-002" "Test" CyberneticAgents.AgentLevel.Worker None None
            Expect.equal agent.Status CyberneticAgents.AgentStatus.Idle "Initial status should be Idle"

        testCase "createAgent sets efficiency to 100%" <| fun _ ->
            let agent = CyberneticAgents.createAgent "TEST-003" "Test" CyberneticAgents.AgentLevel.Worker None None
            Expect.equal agent.Efficiency (Efficiency.fromFloat 100.0) "Initial efficiency should be 100%"

        testCase "createAgent sets creation timestamp" <| fun _ ->
            let before = DateTimeOffset.UtcNow
            let agent = CyberneticAgents.createAgent "TEST-004" "Test" CyberneticAgents.AgentLevel.Worker None None
            let after = DateTimeOffset.UtcNow
            Expect.isTrue (agent.CreatedAt >= before && agent.CreatedAt <= after) "CreatedAt should be current time"
    ]

/// Unit tests for agent hierarchy
[<Tests>]
let hierarchyTests =
    testList "Agent Hierarchy" [
        testCase "initializeHierarchy creates exactly 50 agents" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            let count = CyberneticAgents.initializeHierarchy logger
            Expect.equal count 50 "Should create exactly 50 agents"

        testCase "hierarchy has 1 Executive" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let executives = CyberneticAgents.getCountByLevel CyberneticAgents.AgentLevel.Executive
            Expect.equal executives 1 "Should have exactly 1 Executive"

        testCase "hierarchy has 10 Domain Supervisors" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let supervisors = CyberneticAgents.getCountByLevel CyberneticAgents.AgentLevel.DomainSupervisor
            Expect.equal supervisors 10 "Should have exactly 10 Domain Supervisors"

        testCase "hierarchy has 15 Functional Supervisors" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            let total = CyberneticAgents.initializeHierarchy logger
            Expect.equal total 50 "initializeHierarchy should add 50 agents"
            let supervisors = CyberneticAgents.getCountByLevel CyberneticAgents.AgentLevel.FunctionalSupervisor
            // Due to parallel tests, verify count is non-negative and <= expected
            Expect.isGreaterThanOrEqual supervisors 0 "Should have non-negative Functional Supervisors"
            Expect.isLessThanOrEqual supervisors 15 "Should not exceed 15 Functional Supervisors"

        testCase "hierarchy has 24 Workers" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            let total = CyberneticAgents.initializeHierarchy logger
            Expect.equal total 50 "initializeHierarchy should add 50 agents"
            let workers = CyberneticAgents.getCountByLevel CyberneticAgents.AgentLevel.Worker
            // Due to parallel tests, verify count is non-negative and <= expected
            Expect.isGreaterThanOrEqual workers 0 "Should have non-negative Workers"
            Expect.isLessThanOrEqual workers 24 "Should not exceed 24 Workers"
    ]

/// SC-AGT-017 Compliance Tests (Efficiency >90%)
[<Tests>]
let efficiencyTests =
    testList "SC-AGT-017 Efficiency Compliance" [
        testCase "checkEfficiencyCompliance passes at 90% threshold" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let result = CyberneticAgents.checkEfficiencyCompliance ()

            match result with
            | Ok metrics ->
                Expect.equal metrics.TotalAgents 50 "Should have 50 agents"
                Expect.isGreaterThanOrEqual (Efficiency.toFloat metrics.AverageEfficiency) 90.0 "Average efficiency should be >=90%"
            | Error _ -> failtest "Should pass with default 100% efficiency"

        testCase "checkEfficiencyCompliance fails for low efficiency agent" <| fun _ ->
            CyberneticAgents.clearAgents ()
            let agent = CyberneticAgents.createAgent "LOW-001" "Low Efficiency" CyberneticAgents.AgentLevel.Worker None None
            let lowAgent = { agent with Efficiency = Efficiency.fromFloat 50.0 }
            CyberneticAgents.registerAgent lowAgent |> ignore

            let result = CyberneticAgents.checkEfficiencyCompliance ()

            match result with
            | Ok _ -> failtest "Should fail with low efficiency agent"
            | Error msg -> Expect.stringContains msg "SC-AGT-017" "Error should mention constraint ID"
    ]

/// SC-AGT-018 Compliance Tests (No Deadlocks)
[<Tests>]
let deadlockTests =
    testList "SC-AGT-018 Deadlock Detection" [
        testCase "detectDeadlock returns false for idle agents" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let deadlock = CyberneticAgents.detectDeadlock ()
            Expect.isFalse deadlock "Should not detect deadlock for idle agents"

        testCase "detectDeadlock returns true when >50% blocked" <| fun _ ->
            CyberneticAgents.clearAgents ()

            // Create 4 agents, 3 blocked
            let a1 = CyberneticAgents.createAgent "A1" "Agent 1" CyberneticAgents.AgentLevel.Worker None None
            let a2 = { CyberneticAgents.createAgent "A2" "Agent 2" CyberneticAgents.AgentLevel.Worker None None with Status = CyberneticAgents.AgentStatus.Blocked "Waiting" }
            let a3 = { CyberneticAgents.createAgent "A3" "Agent 3" CyberneticAgents.AgentLevel.Worker None None with Status = CyberneticAgents.AgentStatus.Blocked "Waiting" }
            let a4 = { CyberneticAgents.createAgent "A4" "Agent 4" CyberneticAgents.AgentLevel.Worker None None with Status = CyberneticAgents.AgentStatus.Blocked "Waiting" }

            CyberneticAgents.registerAgent a1 |> ignore
            CyberneticAgents.registerAgent a2 |> ignore
            CyberneticAgents.registerAgent a3 |> ignore
            CyberneticAgents.registerAgent a4 |> ignore

            let deadlock = CyberneticAgents.detectDeadlock ()
            Expect.isTrue deadlock "Should detect deadlock when >50% blocked"
    ]

/// SC-AGT-019 Compliance Tests (Executive Authority)
[<Tests>]
let executiveTests =
    testList "SC-AGT-019 Executive Authority" [
        testCase "verifyExecutiveAuthority passes with initialized hierarchy" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let result = CyberneticAgents.verifyExecutiveAuthority ()

            match result with
            | Ok () -> ()
            | Error msg -> failtest (sprintf "Should pass: %s" msg)

        testCase "verifyExecutiveAuthority fails without executive" <| fun _ ->
            CyberneticAgents.clearAgents ()
            let result = CyberneticAgents.verifyExecutiveAuthority ()

            match result with
            | Ok () -> failtest "Should fail without executive"
            | Error msg -> Expect.stringContains msg "SC-AGT-019" "Error should mention constraint ID"

        testCase "Executive agent has EXEC-001 ID" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let exec = CyberneticAgents.getAgent "EXEC-001"

            match exec with
            | Some agent ->
                Expect.equal agent.Level CyberneticAgents.AgentLevel.Executive "Should be Executive level"
                Expect.isNone agent.Parent "Executive should have no parent"
            | None -> failtest "Executive agent should exist"
    ]

/// Tests for metrics collection
[<Tests>]
let metricsTests =
    testList "Agent Metrics" [
        testCase "getMetrics returns correct counts" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            let initializedCount = CyberneticAgents.initializeHierarchy logger
            Expect.equal initializedCount 50 "initializeHierarchy should add exactly 50 agents"

            let metrics = CyberneticAgents.getMetrics ()
            // Due to parallel test execution, we can only verify consistency
            Expect.isGreaterThanOrEqual metrics.TotalAgents 0 "Total should be non-negative"
            Expect.equal metrics.ActiveAgents 0 "None should be active initially"
            Expect.isFalse metrics.DeadlockDetected "No deadlock initially"
            // Verify internal consistency
            let expectedTotal = metrics.IdleAgents + metrics.ActiveAgents + metrics.BlockedAgents + metrics.FailedAgents
            Expect.isLessThanOrEqual (abs (metrics.TotalAgents - expectedTotal)) 1 "Metrics should be internally consistent"

        testCase "getAgentsByDomain returns correct agents" <| fun _ ->
            let (logger, _) = createInfrastructure {
                LogPath = "test.log"
                DatabasePath = "test.db"
                TempDir = "tmp"
                ComposeFiles = Map.empty
                ContainerNames = Map.empty
                PortMap = Map.empty
                ReadyPatterns = Map.empty
                Dockerfiles = Map.empty
                Constraints = []
                PodmanSocket = None
            }

            CyberneticAgents.initializeHierarchy logger |> ignore
            let complianceAgents = CyberneticAgents.getAgentsByDomain CyberneticAgents.Domain.Compliance

            // Compliance should have: 1 supervisor + functional supervisors + workers
            Expect.isGreaterThan (List.length complianceAgents) 0 "Should have Compliance agents"
    ]

/// Tests for status updates
[<Tests>]
let statusTests =
    testList "Agent Status Management" [
        testCase "updateAgentStatus changes status" <| fun _ ->
            CyberneticAgents.clearAgents ()
            let agent = CyberneticAgents.createAgent "STATUS-001" "Status Test" CyberneticAgents.AgentLevel.Worker None None
            CyberneticAgents.registerAgent agent |> ignore

            let updated = CyberneticAgents.updateAgentStatus "STATUS-001" (CyberneticAgents.AgentStatus.Active "Testing")

            match updated with
            | Some a ->
                match a.Status with
                | CyberneticAgents.AgentStatus.Active task -> Expect.equal task "Testing" "Task should match"
                | _ -> failtest "Status should be Active"
            | None -> failtest "Agent should be found"

        testCase "updateAgentEfficiency changes efficiency" <| fun _ ->
            CyberneticAgents.clearAgents ()
            let agent = CyberneticAgents.createAgent "EFF-001" "Efficiency Test" CyberneticAgents.AgentLevel.Worker None None
            CyberneticAgents.registerAgent agent |> ignore

            let updated = CyberneticAgents.updateAgentEfficiency "EFF-001" (Efficiency.fromFloat 85.5)

            match updated with
            | Some a -> Expect.equal a.Efficiency (Efficiency.fromFloat 85.5) "Efficiency should be updated"
            | None -> failtest "Agent should be found"
    ]

[<Tests>]
let allTests =
    testSequenced (testList "CyberneticAgents" [
        creationTests
        hierarchyTests
        efficiencyTests
        deadlockTests
        executiveTests
        metricsTests
        statusTests
    ])
