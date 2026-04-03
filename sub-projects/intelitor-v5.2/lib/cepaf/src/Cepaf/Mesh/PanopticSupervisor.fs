// =============================================================================
// PanopticSupervisor.fs - Autonomic Homeostasis Maintainer (SIL-6)
// =============================================================================
// STAMP: SC-SIL6-001, SC-PROM-003, SC-IGNITE-002
// AOR: AOR-SUPERVISOR-001, AOR-MESH-010
//
// ## Purpose
// Long-running supervisor agent that ensures the SIL-6 mesh remains in
// Homeostasis. It uses the PanopticIgnition module for recovery.
// =============================================================================

namespace Cepaf.Mesh

open System
open System.Threading
open Cepaf.Zenoh.Messaging
open Cepaf.Mesh.CLI

module PanopticSupervisor =

    let private pollInterval = 30000 // 30s

    /// <summary>
    /// Core Autonomic Loop: Observe -> Orient -> Decide -> Act
    /// </summary>
    let run (cli: SIL4MeshCLI) =
        printfn "\u001b[35m[SUPERVISOR]\u001b[0m Entering autonomic homeostasis loop..."
        
        while true do
            printfn "\u001b[34m[OBSERVE]\u001b[0m Probing mesh substrate..."
            
            let statusResult = cli.Status()
            
            if statusResult.Success then
                printfn "\u001b[32m[ORIENT]\u001b[0m Homeostasis DETECTED. All nodes operational."
                ZenohPublish.publish "CP-HEARTBEAT" "indrajaal/mesh/heartbeat" "STABLE" "{\"status\": \"healthy\"}"
            else
                printfn "\u001b[31m[ORIENT]\u001b[0m SUBSTRATE DRIFT DETECTED. Quorum compromised."
                printfn "\u001b[33m[DECIDE]\u001b[0m Triggering Panoptic Ignition recovery sequence..."
                
                let igniteResult = cli.Ignite()
                if igniteResult.Success then
                    printfn "\u001b[32m[ACT]\u001b[0m Homeostasis RESTORED."
                else
                    printfn "\u001b[31m[ACT]\u001b[0m Recovery FAILED. Escalating to 7-Level RCA..."
                    PanopticIgnition.performFractalRCA "Supervised Recovery Failed" igniteResult.Message |> ignore
            
            Thread.Sleep(pollInterval)
