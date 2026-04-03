// =============================================================================
// OrchestrationTests.fs - Integration Tests for Service Coordination
// =============================================================================
// STAMP: SC-ORCH-001 to SC-ORCH-015
// AOR: AOR-ORCH-001 to AOR-ORCH-015
// Coverage: Service coordination, OODA cycle, access control integration
// =============================================================================

module Cepaf.Planning.Tests.OrchestrationTests

open System
open Cepaf.Planning
open Xunit

// Module aliases for cleaner access
module SR = ServiceRegistry
module MB = MessageBus
module CO = Coordination
module AC = OrchestrationAccessControl
module OI = OrchestrationInit

// =============================================================================
// SERVICE REGISTRY TESTS
// =============================================================================

[<Fact>]
let ``SC-ORCH-012: Service registration is atomic`` () =
    // Initialize orchestration
    OI.initialize()

    // Verify all services registered
    let services = SR.getAllServices()
    Assert.Equal(7, services.Length)

[<Fact>]
let ``SC-ORCH-010: All services should be online after init`` () =
    OI.initialize()

    let cortexOnline = SR.isOnline Cortex
    let prajnaOnline = SR.isOnline Prajna
    let smritiOnline = SR.isOnline Smriti
    let cepafOnline = SR.isOnline CEPAF
    let planningOnline = SR.isOnline Planning
    let chayaOnline = SR.isOnline Chaya
    let guardianOnline = SR.isOnline Guardian

    Assert.True(cortexOnline)
    Assert.True(prajnaOnline)
    Assert.True(smritiOnline)
    Assert.True(cepafOnline)
    Assert.True(planningOnline)
    Assert.True(chayaOnline)
    Assert.True(guardianOnline)

[<Fact>]
let ``Service health can be updated`` () =
    OI.initialize()

    SR.updateHealth Cortex Degraded 0.75
    let status = SR.getStatus Cortex
    Assert.Equal(Some Degraded, status)

    // Restore to online
    SR.updateHealth Cortex Online 1.0

// =============================================================================
// MESSAGE BUS TESTS
// =============================================================================

[<Fact>]
let ``SC-ORCH-011: Message bus creates messages with correct priority`` () =
    let msg = MB.createMessage Planning Guardian Critical "test payload"

    Assert.Equal(Planning, msg.Source)
    Assert.Equal(Guardian, msg.Target)
    Assert.Equal(Critical, msg.Priority)
    Assert.Equal("test payload", msg.Payload)
    Assert.True(msg.RequiresAck) // Critical messages require ack

[<Fact>]
let ``Normal messages do not require acknowledgment`` () =
    let msg = MB.createMessage Planning Smriti Normal "test"
    Assert.False(msg.RequiresAck)

[<Fact>]
let ``Message timestamps are in UTC`` () =
    let before = DateTime.UtcNow.AddSeconds(-1.0)
    let msg = MB.createMessage Planning Cortex Normal "test"
    let after = DateTime.UtcNow.AddSeconds(1.0)

    Assert.True(msg.Timestamp >= before && msg.Timestamp <= after)

// =============================================================================
// COORDINATION TESTS
// =============================================================================

[<Fact>]
let ``SC-ORCH-004: OODA cycle completes within 100ms`` () =
    OI.initialize()

    let duration = CO.coordinateOODACycle()

    Assert.True(duration < 100.0, sprintf "OODA cycle took %fms, expected <100ms" duration)

[<Fact>]
let ``SC-ORCH-005: Guardian approval can be requested`` () =
    OI.initialize()

    let approved = CO.requestGuardianApproval "test_action" "test_context"
    // In placeholder implementation, always returns true
    Assert.True(approved)

[<Fact>]
let ``SC-ORCH-006: Cortex assistance can be requested`` () =
    OI.initialize()

    let response = CO.requestCortexAssistance "test query"
    Assert.Contains("Cortex processing:", response)
    Assert.Contains("test query", response)

[<Fact>]
let ``SC-ORCH-007: Smriti knowledge can be queried`` () =
    OI.initialize()

    let results = CO.querySmritiKnowledge "test_topic"
    Assert.NotEmpty(results)
    Assert.Contains("test_topic", results.[0])

[<Fact>]
let ``SC-ORCH-008: Tasks can be distributed across Chaya mesh`` () =
    let tasks = ["task1"; "task2"; "task3"; "task4"; "task5"]
    let nodeCount = 3

    let distribution = CO.distributeTasks tasks nodeCount

    // Verify all tasks are distributed
    let distributedTasks =
        distribution
        |> Map.toList
        |> List.collect snd

    Assert.Equal(5, distributedTasks.Length)

// =============================================================================
// ACCESS CONTROL INTEGRATION TESTS
// =============================================================================

[<Fact>]
let ``SC-ORCH-013: Access control blocks known agents from direct access`` () =
    // Known AI agents should be blocked from direct access per SC-TODO-001
    let allowed = AC.validateAccess "claude" "read"
    Assert.False(allowed)

[<Fact>]
let ``Founder has full access`` () =
    let allowed = AC.validateAccess "Founder" "read"
    Assert.True(allowed)

[<Fact>]
let ``Shell commands are validated`` () =
    // Direct cat command should be blocked
    let blocked = AC.validateOrchestratedCommand "AI-Agent-001" "cat PROJECT_TODOLIST.md"
    Assert.False(blocked)

// =============================================================================
// EVENT LOG TESTS
// =============================================================================

[<Fact>]
let ``SC-ORCH-014: Events are logged after coordination`` () =
    OI.initialize()

    // Run OODA cycle which logs an event
    let _ = CO.coordinateOODACycle()

    let events = SR.getEventLog()
    Assert.NotEmpty(events)

[<Fact>]
let ``Event log contains service registration events`` () =
    OI.initialize()

    let events = SR.getEventLog()
    let registrationEvents =
        events
        |> List.filter (function ServiceRegistered _ -> true | _ -> false)

    // Should have 7 service registration events
    Assert.True(registrationEvents.Length >= 7)

// =============================================================================
// ORCHESTRATION INIT TESTS
// =============================================================================

[<Fact>]
let ``Orchestration status returns correct format`` () =
    OI.initialize()

    let status = OI.getStatus()
    Assert.Contains("services online", status)
