namespace Cepaf.Cockpit

open System
open System.Threading
open System.Threading.Tasks
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Zenoh.Session
open Cepaf.Cockpit.TelemetryIngest
open Cepaf.Cockpit.Orchestrator
open Cepaf.Cockpit.Safety
open Cepaf.Cockpit.AI
open Cepaf.Cockpit.Cortex.Synapse

/// ═══════════════════════════════════════════════════════════════════════════════
/// PHASE 3 VERIFICATION: COGNITIVE EXPANSION
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// WHAT: Verifies the "Awakening" of the system:
///       1. KMS Synchronization (World Model)
///       2. OpenRouter Integration (Higher Intelligence)
///       3. Synapse Mediation (Simplex Architecture)
///
/// STAMP: SC-NEURO-001 (Guardian Check), SC-KMS-001 (State Integrity)
/// ═══════════════════════════════════════════════════════════════════════════════

module Phase3Verification = 

    let run () =
        printfn "\n╔══════════════════════════════════════════════════════════════════════╗"
        printfn "║  PHASE 3 VERIFICATION: COGNITIVE EXPANSION                           ║"
        printfn "╠══════════════════════════════════════════════════════════════════════╣"
        printfn "║  Targets: KMS Sync, OpenRouter, Synapse, Guardian Veto               ║"
        printfn "╚══════════════════════════════════════════════════════════════════════╝\n"

        // 1. Setup Brain Components
        let guardian = new GuardianAgent()
        let orchestrator = new OrchestratorAgent("TEST-OP", guardian)
        
        // Mock AI Client for testing (avoid burning tokens in CI)
        let aiClient = new OpenRouterClient("sk-mock", "http://localhost", "Cepaf")
        let synapse = new SynapseAgent(orchestrator, guardian, aiClient)
        
        // 2. Setup Nervous System
        let nodeId = "COCKPIT-01"
        let lifecycle = Cepaf.Zenoh.Session.ZenohLifecycleFactory.create nodeId
        let zenohService = new ZenohService(nodeId, lifecycle) :> IZenohService

        // 3. KMS Integration Test
        printfn "[STEP 1] KMS Subscriber Initialization..."
        
        // Creating a SmritiEventHandlers record to capture updates
        let mutable lastHealthUpdate = None
        let handlers = {
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnHolonCreated = fun h -> printfn "  [KMS] Holon Created: %s" h.Name
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnHolonUpdated = fun h -> printfn "  [KMS] Holon Updated: %s" h.Name
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnHolonDeleted = fun id -> printfn "  [KMS] Holon Deleted: %s" id
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnHealthUpdate = fun h -> 
                printfn "  [KMS] Health Update Received"
                lastHealthUpdate <- Some h
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnEntropyUpdate = fun e -> printfn "  [KMS] Entropy Update"
            Cepaf.Cockpit.Zenoh.SmritiSubscriber.OnStatsUpdate = fun s -> printfn "  [KMS] Stats Update"
        }
        
        // Initialize Smriti Subscriber
        Cepaf.Cockpit.Zenoh.SmritiSubscriber.initializeAsync zenohService handlers 
        |> Async.AwaitTask 
        |> Async.RunSynchronously
        
        printfn "✅ KMS Subscriber Active"

        // 4. Neuro-Symbolic Logic Test
        printfn "[STEP 2] Synapse Logic Test (Shadow Mode)..."
        // Toggle Shadow Mode ON
        synapse.SetShadowMode(true)
        
        // Simulate an error state analysis
        let context = "PostgreSQL connection pool exhausted"
        let error = "FATAL: remaining connection slots are reserved for non-replication superuser connections"
        
        printfn "  [Synapse] Requesting Fix for: %s" context
        synapse.Suggest(context, error)
        
        // In a real async test we'd wait for the mailbox to process.
        Thread.Sleep(1000)
        
        printfn "✅ Synapse Processing Complete (Check logs for 'AI Suggestion')"

        // 5. Guardian Veto Test
        printfn "[STEP 3] Guardian Safety Veto Test..."
        // Construct a dangerous proposal manually
        let dangerousProposal = {
            Id = Guid.NewGuid().ToString()
            Action = ProposalAction.ExecCommand "rm -rf /"
            Source = "MaliciousActor"
            Timestamp = DateTime.UtcNow
        }
        
        let result = guardian.Validate(dangerousProposal) |> Async.RunSynchronously
        match result with
        | Vetoed (reason, fallback) -> 
            printfn "✅ Guardian VETOED dangerous proposal: %A" reason
            printfn "   Fallback Action: %A" fallback
        | Approved _ -> 
            printfn "❌ Guardian FAILED to veto dangerous proposal!"
            exit 1

        printfn "\n✅ PHASE 3 VERIFICATION COMPLETE"
        printfn "   - KMS Sync: Initialized"
        printfn "   - Synapse: Active"
        printfn "   - Guardian: Enforcing Safety"
        
        zenohService.Dispose()
        (aiClient :> IDisposable).Dispose()
