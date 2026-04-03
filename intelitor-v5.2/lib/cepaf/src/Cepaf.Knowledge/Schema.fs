module Cepaf.Knowledge.Schema

open System

// Level 1: Fractal Layer
type HolonLevel = 
    | Atomic      // 0
    | Molecular   // 1
    | Organism    // 2
    | Ecosystem   // 3

type FractalStruct = {
    HolonLevel: HolonLevel
    ParentHolonId: Guid option
    ChildHolonIds: Guid list
    FractalPath: string
}

// Level 2: Evolutionary Layer
type DecayRate = 
    | Fast    // 0.05/day
    | Medium  // 0.01/day
    | Slow    // 0.001/day

type Evolution = {
    CreatedAt: DateTime
    LastModified: DateTime
    Version: string
    Status: string
    EntropyScore: float
    DecayRate: DecayRate
    Genealogy: Guid list
    LastVerified: DateTime option
}

// Level 3: Richness Layer
type RhetoricalFunction = 
    | Axiom 
    | Hypothesis 
    | Evidence 
    | CounterArgument 
    | Synthesis
    | Description

type Semantics = {
    RhetoricalFunction: RhetoricalFunction
    ConfidenceScore: int
    AmbiguityFlag: bool
    Keywords: string list
    Vectors: string list // Vector IDs
}

// Level 4: Actionable Layer
type Actionable = {
    PotentialOutput: string list
    BridgeCandidates: Guid list
    AgentComments: string list
    StampConstraints: string list
}

type Identity = {
    Uuid: Guid
    Title: string
    Aliases: string list
}

// The Root Holon Type
type Holon = {
    Identity: Identity
    FractalStruct: FractalStruct
    Evolution: Evolution
    Semantics: Semantics
    Graph: Actionable // Mapped to 'Actionable' in logic, 'graph' in YAML
    Content: string // The raw markdown body
}
