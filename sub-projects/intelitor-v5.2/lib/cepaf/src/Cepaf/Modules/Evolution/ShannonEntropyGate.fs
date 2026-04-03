namespace Cepaf.Modules.Evolution

open System
open System.Collections.Generic
open Cepaf.Modules.HealthPropagation

/// Shannon Entropy Gate (SC-EVO-002)
/// Purpose: Calculate and enforce system-wide entropy thresholds for GA release v21.3.0-SIL6.
/// Formula: H(S) = -sum(p_i * log2(p_i))
module ShannonEntropyGate =

    /// Calculate Shannon Entropy based on health distribution
    let calculateEntropy (summary: HealthSummary) : float =
        if summary.TotalNodes = 0 then 0.0
        else
            let total = float summary.TotalNodes
            let p_healthy = float summary.HealthyCount / total
            let p_degraded = float summary.DegradedCount / total
            let p_failed = float summary.FailedCount / total
            let p_absent = float summary.AbsentCount / total
            let p_starting = float summary.StartingCount / total
            let p_created = float summary.CreatedCount / total

            let probs = [p_healthy; p_degraded; p_failed; p_absent; p_starting; p_created]
            
            probs 
            |> List.filter (fun p -> p > 0.0)
            |> List.sumBy (fun p -> -p * Math.Log(p, 2.0))

    /// Verify if system is below the GA release threshold (H(S) < 0.2)
    let isReleaseReady (summary: HealthSummary) : bool =
        let entropy = calculateEntropy summary
        entropy < 0.2

    /// Format entropy report for GA sign-off
    let formatEntropyReport (summary: HealthSummary) : string =
        let entropy = calculateEntropy summary
        let readyStatus = if entropy < 0.2 then "READY" else "REJECTED"
        sprintf """Shannon Entropy Report [v21.3.0-SIL6]
  System Entropy H(S): %.4f
  Release Threshold:   < 0.2000
  Status:              %s
  Total Nodes:         %d
  Healthy Nodes:       %d""" 
            entropy 
            readyStatus 
            summary.TotalNodes 
            summary.HealthyCount
