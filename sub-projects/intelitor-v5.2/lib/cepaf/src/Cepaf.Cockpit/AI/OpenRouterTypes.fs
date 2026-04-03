// =============================================================================
// OpenRouterTypes.fs - Schemas for AI Integration
// =============================================================================
// Phase 3: Cognitive Expansion
// STAMP: SC-NEURO-001 (Simplex Architecture)
// Criticality: Level 3 (HIGH) - AI Communication
// =============================================================================

namespace Cepaf.Cockpit.AI

open System

/// Model identifier
type ModelId = string

/// Message role
type Role =
    | System
    | User
    | Assistant
    | Tool

/// Chat message
type Message = {
    Role: string
    Content: string
    Name: string option
}

/// Request payload
type ChatCompletionRequest = {
    Model: ModelId
    Messages: Message list
    Temperature: float
    MaxTokens: int
    Stream: bool
}

/// Response choice
type Choice = {
    Message: Message
    FinishReason: string
}

/// Usage statistics
type Usage = {
    PromptTokens: int
    CompletionTokens: int
    TotalTokens: int
}

/// Response payload
type ChatCompletionResponse = {
    Id: string
    Choices: Choice list
    Created: int64
    Model: string
    Usage: Usage option
}

/// AI Proposal for Guardian Validation
type AIProposal = {
    Id: Guid
    Reasoning: string
    ActionType: string
    Parameters: Map<string, string>
    Confidence: float
    ModelUsed: string
    GeneratedAt: DateTime
}
