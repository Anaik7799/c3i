namespace Cepaf.Bio

open System

/// The Universal Holon Identifier
type HolonId = Guid

/// Biological Classification of the Holon
type HolonType =
    | Cell        // Single Process
    | Tissue      // Supervision Tree
    | Organ       // Service / Container
    | Organism    // Node
    | Colony      // Cluster

/// The Standardized Vital Signs Vector
/// Mirrors Elixir: Prajna.Bio.VitalSigns
type VitalSigns = {
    Id: HolonId
    Type: HolonType
    Generation: uint32
    
    // Physiology (Normalized 0.0 - 1.0)
    HealthIndex: float
    StressIndex: float
    EnergyIndex: float // Resource Usage vs Quota
    
    // Teleology
    Intent: string
    Timestamp: DateTimeOffset
}

module Holon =
    /// Creating a new VitalSigns record with defaults
    let create id hType = 
        {
            Id = id
            Type = hType
            Generation = 0u
            HealthIndex = 1.0
            StressIndex = 0.0
            EnergyIndex = 0.0
            Intent = "Initializing"
            Timestamp = DateTimeOffset.UtcNow
        }

    /// Check if a Holon is in a pathological state
    let isPathological (vitals: VitalSigns) =
        vitals.HealthIndex < 0.2 || vitals.StressIndex > 0.95
