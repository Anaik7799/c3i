// =============================================================================
// Synapse.fs - Neuro-Symbolic Mediator (Enhanced)
// =============================================================================
// Phase 5: Cognitive Fabric
// STAMP: SC-NEURO-001 (Simplex Architecture), SC-NEURO-004 (Shadow Mode)
// AOR: AOR-NEURO-001 (Guardian Check), AOR-NEURO-002 (Log Veto)
// Criticality: Level 2 (HIGH) - AI Orchestration
// =============================================================================

namespace Cepaf.Cockpit.Cortex

open System
open Cepaf.Cockpit.Domain
open Cepaf.Cockpit.Safety
open Cepaf.Cockpit.AI
open Cepaf.Cockpit.Orchestrator
open Cepaf.Cockpit.Cortex.Memory

module Synapse = 

    type SynapseMsg = 
        | AnalyzeState of CockpitState
        | SuggestFix of string * string // Context, Error
        | ExecuteProposal of AIProposal
        | ToggleShadowMode of bool

    type SynapseAgent(orchestrator: OrchestratorAgent, guardian: GuardianAgent, aiClient: OpenRouterClient) = 
        
        let mutable shadowMode = true // Default to safe mode
        let memory = new MemoryAgent() // Phase 5: Local Memory Agent

        let agent = MailboxProcessor.Start(fun inbox ->
            let rec loop () = async {
                let! msg = inbox.Receive()
                match msg with 
                | ToggleShadowMode mode ->
                    shadowMode <- mode
                    return! loop ()

                | AnalyzeState state ->
                    // Heuristic analysis of state
                    if state.Alarms.Count > 0 then
                        // Simulate AI finding an issue
                        let proposal = {
                            Id = Guid.NewGuid()
                            Reasoning = "High alarm count detected."
                            ActionType = "AnalyzeLogs"
                            Parameters = Map.empty
                            Confidence = 0.85
                            ModelUsed = "mock-model"
                            GeneratedAt = DateTime.UtcNow
                        }
                        // Self-post to execute
                        inbox.Post(ExecuteProposal proposal)
                    return! loop ()

                | SuggestFix (context, error) ->
                    // Phase 5: RAG Retrieval
                    // 1. Recall relevant history
                    let! history = memory.Recall(error)
                    let historyContext = 
                        if history.IsEmpty then "No prior history."
                        else 
                            history 
                            |> List.map (fun h -> sprintf "- %s (Relevance: %.2f)" h.Content h.Relevance)
                            |> String.concat "\n"

                    // 2. Construct Augmented Prompt
                    let request = {
                        Model = "anthropic/claude-3.5-sonnet"
                        Messages = [
                            { Role = "system"; Content = "You are a Site Reliability Engineer. Use the provided history to suggest a fix."; Name = None }
                            { Role = "user"; Content = sprintf "Context: %s\nError: %s\n\nRelevant History:\n%s" context error historyContext; Name = None }
                        ]
                        Temperature = 0.2
                        MaxTokens = 500
                        Stream = false
                    }
                    
                    // 3. Async call to AI
                    let! result = Async.AwaitTask (aiClient.ChatCompletionAsync(request))
                    match result with 
                    | Ok response ->
                        let fix = response.Choices.[0].Message.Content
                        printfn "[Synapse] AI Suggestion (RAG-Enhanced): %s" fix
                        
                        // Phase 5: Remember the fix for future reference
                        memory.Remember(sprintf "Fix for '%s': %s" error fix, ["fix"; "error"])

                        // Create proposal from suggestion
                        let proposal = {
                            Id = Guid.NewGuid()
                            Reasoning = fix
                            ActionType = "ManualFix"
                            Parameters = Map.ofList [("fix", fix)]
                            Confidence = 0.9
                            ModelUsed = response.Model
                            GeneratedAt = DateTime.UtcNow
                        }
                        inbox.Post(ExecuteProposal proposal)
                    | Error e ->
                        printfn "[Synapse] AI Error: %s" e
                    
                    return! loop ()

                | ExecuteProposal proposal ->
                    // SC-NEURO-001: Simplex Principle - Validate via Guardian
                    // Convert AIProposal to Domain Proposal
                    let domainProposal = {
                        Id = proposal.Id.ToString()
                        Action = 
                            match proposal.ActionType with
                            | "AnalyzeLogs" -> ProposalAction.ExecCommand "grep -r error /var/log"
                            | "ManualFix" -> ProposalAction.Custom ("ManualFix", box proposal.Reasoning)
                            | _ -> ProposalAction.Custom ("Unknown", box proposal)
                        Source = sprintf "Synapse:%s" proposal.ModelUsed
                        Timestamp = proposal.GeneratedAt
                    }

                    // Ask Guardian
                    let! validation = guardian.Validate(domainProposal)
                    
                    match validation with
                    | Approved _ ->
                        if shadowMode then
                            printfn "[Synapse] [SHADOW] Proposal APPROVED but not executed: %A" proposal
                        else
                            printfn "[Synapse] Executing Proposal: %A" proposal
                            // orchestrator.Execute(domainProposal) // If such method existed
                    | Vetoed (reason, fallback) ->
                        printfn "[Synapse] Proposal VETOED: %A. Fallback: %A" reason fallback
                        // Phase 5: Remember the Veto (Negative Feedback)
                        memory.Remember(sprintf "Guardian VETOED proposal '%s' due to %A" proposal.Reasoning reason, ["veto"; "safety"])
                    
                    return! loop ()
            }
            loop ()
        )

        member this.Analyze(state) = agent.Post(AnalyzeState state)
        member this.Suggest(context, error) = agent.Post(SuggestFix(context, error))
        member this.SetShadowMode(enabled) = agent.Post(ToggleShadowMode enabled)