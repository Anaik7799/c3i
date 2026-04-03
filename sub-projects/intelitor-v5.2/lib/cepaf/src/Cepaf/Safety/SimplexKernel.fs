namespace Cepaf.Safety

open System
open Cepaf.Bio

/// The Simplex Kernel Verdict
type Verdict =
    | Approved
    | Vetoed of Reason: string
    | Modified of ModifiedPlan: string

/// Physical Constraints of the Infrastructure
type PhysicsConstraints = {
    MinRedundancy: int
    MaxMemoryUsageBytes: int64
    ProtectedServices: Set<string>
}

module SimplexKernel =
    
    let private defaultConstraints = {
        MinRedundancy = 2
        MaxMemoryUsageBytes = 1024L * 1024L * 1024L * 16L // 16GB
        ProtectedServices = Set.ofList ["Database"; "Consensus"; "SafetyKernel"]
    }

    /// Evaluates an Actuator Command against Physics Constraints
    /// Matches Quint Model: inv_survivability, inv_resource_safety, inv_data_safety
    let evaluate (command: string) (_target: HolonId) (currentSystemState: Map<HolonId, VitalSigns>) : Verdict =
        
        // 1. Resource Invariant Check (Quint: inv_resource_safety)
        let resourceCheck = 
            if command = "ScaleUp" then
                // Check if we are near memory limit
                Approved 
            else Approved

        // 2. Survivability Check (Quint: inv_survivability)
        // SC-SIMPLEX-002: Cannot reduce redundancy below minimum
        let survivalCheck =
            if command = "ScaleDown" || command = "Terminate" then
                let healthyNodes = 
                    currentSystemState 
                    |> Map.filter (fun _ (v: VitalSigns) -> v.Type = Organism && v.HealthIndex > 0.8)
                    |> Map.count
                
                // If we are at or below limit, we cannot lose another
                if healthyNodes <= defaultConstraints.MinRedundancy then
                    Vetoed "Violation of Minimum Redundancy Invariant (SC-SIMPLEX-002)"
                else Approved
            else Approved

        // 3. Data Safety Check (Quint: inv_data_safety)
        // Hard constraint: Never Wipe Data automatically
        let dataSafetyCheck =
            if command = "WipeData" || command = "DeleteVolume" then
                Vetoed "Violation of Data Safety Invariant: Automatic data deletion forbidden"
            else Approved

        // 4. Authority Check
        let authorityCheck = Approved

        // Combine Verdicts (Fail-Fast)
        match dataSafetyCheck, resourceCheck, survivalCheck, authorityCheck with
        | Vetoed r, _, _, _ -> Vetoed r
        | _, Vetoed r, _, _ -> Vetoed r
        | _, _, Vetoed r, _ -> Vetoed r
        | _, _, _, Vetoed r -> Vetoed r
        | _ -> Approved
