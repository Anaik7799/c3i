namespace Cepaf.Bio

open System

/// Recursive Definition of a System Entity
/// This is the "DNA" of the Fractal Interface.
type Holon = {
    Id: Guid
    Name: string
    Type: HolonType
    
    // Core Vital Signs (0.0 - 1.0)
    Health: float
    Stress: float
    
    // Intelligence (AI-Derived)
    Prediction: float option // Predicted Health in +5 mins
    Salience: float          // How important is this right now?
    
    // Fractal Structure
    Children: Holon list
}

and HolonType =
    | System
    | Cluster
    | Node
    | Service
    | Metric

module Holon =
    
    /// Calculate aggregate health from children (Bottom-Up)
    let rec aggregateHealth (h: Holon) : float =
        match h.Children with
        | [] -> h.Health
        | kids -> 
            let childHealth = kids |> List.averageBy aggregateHealth
            (h.Health + childHealth) / 2.0

    /// Sort children by Salience (Smart Sorting)
    let sortChildren (h: Holon) : Holon =
        { h with Children = h.Children |> List.sortByDescending (fun c -> c.Salience) }
