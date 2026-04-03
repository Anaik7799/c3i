namespace Cepaf.Cockpit.AI

open System

// =============================================================================
// MemoryTypes.fs - Cognitive Fabric Schema
// =============================================================================
// Phase: 5 (Cognitive Fabric)
// Criticality: P1
// =============================================================================

/// A unit of memory
type MemoryItem = {
    Id: Guid
    Content: string
    Embedding: float[] // Vector representation
    Tags: string list
    Created: DateTime
    AccessCount: int
    Relevance: float   // Transient score for retrieval
}

/// Request to recall information
type RecallRequest = {
    Query: string
    Limit: int
    MinRelevance: float
}

/// Interface for storage backends
type IMemoryStore =
    abstract member Add: MemoryItem -> Async<unit>
    abstract member Search: RecallRequest -> Async<MemoryItem list>
    abstract member Count: unit -> Async<int64>
