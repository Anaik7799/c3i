/// Z-KMS Shared Domain Types
/// Defines the core data structures for the Zettelkasten Knowledge Management System
///
/// STAMP Constraints:
/// - SC-KMS-001: All types are immutable records
/// - SC-KMS-002: Cross-runtime compatible (F#/Elixir via JSON)
/// - SC-KMS-003: Entropy ranges from 0.0 (fresh) to 1.0 (rotting)
namespace Cepaf.Smriti.Shared

open System
open System.Text.Json.Serialization

// ============================================================================
// Core Types
// ============================================================================

/// Link type between Zettels
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type LinkType =
    /// Explicit wiki-style link [[target]]
    | WikiLink = 0
    /// Vector cosine similarity > threshold
    | SemanticSimilar = 1
    /// Code import or function call reference
    | CodeReference = 2
    /// Reverse of a WikiLink (automatic)
    | Backlink = 3

/// Holon level in the fractal hierarchy
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type HolonLevel =
    | Atomic = 0      // L1: Single note/function
    | Molecular = 1   // L2: Related notes cluster
    | Organism = 2    // L3: Topic/domain
    | Ecosystem = 3   // L4: System-wide

/// Decay rate classification
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type DecayRate =
    | Fast = 0    // API docs, config (decay in days)
    | Medium = 1  // Design docs (decay in weeks)
    | Slow = 2    // Architecture, principles (decay in months)

// ============================================================================
// Zettel Types
// ============================================================================

/// Atomic unit of knowledge in the Zettelkasten
type Zettel = {
    /// Unique identifier (UUID)
    Id: Guid
    /// Human-readable title
    Title: string
    /// Markdown content
    Content: string
    /// Classification tags
    Tags: string list
    /// IDs of Zettels that link TO this one
    Backlinks: Guid list
    /// Entropy score: 0.0 (fresh/verified) to 1.0 (rotting/stale)
    Entropy: float
    /// Fractal level classification
    Level: HolonLevel
    /// Decay rate for entropy calculation
    DecayRate: DecayRate
    /// Creation timestamp
    CreatedAt: DateTime
    /// Last modification timestamp
    ModifiedAt: DateTime
    /// Last verification timestamp (human or test passed)
    VerifiedAt: DateTime option
    /// Content hash for change detection
    ContentHash: string
}

/// Graph edge connecting two Zettels
type ZettelLink = {
    /// Source Zettel ID
    Source: Guid
    /// Target Zettel ID
    Target: Guid
    /// Type of link
    LinkType: LinkType
    /// Link strength (increases with usage/traversal)
    Weight: float
    /// When this link was established
    CreatedAt: DateTime
}

/// Node representation for graph visualization
type ZettelNode = {
    /// Zettel ID
    Id: Guid
    /// Display label (title)
    Label: string
    /// Entropy score for coloring
    Entropy: float
    /// Optional cluster name for grouping
    Cluster: string option
    /// Fractal level
    Level: HolonLevel
    /// Number of backlinks (popularity)
    BacklinkCount: int
}

/// Complete graph data for Cytoscape.js visualization
type GraphData = {
    /// All nodes in the graph
    Nodes: ZettelNode list
    /// All edges in the graph
    Edges: ZettelLink list
    /// Graph generation timestamp
    GeneratedAt: DateTime
}

// ============================================================================
// Search Types
// ============================================================================

/// How a search result was matched
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type SearchMatchType =
    | FullText = 0      // FTS5 match
    | Semantic = 1      // Vector similarity
    | TagMatch = 2      // Exact tag match
    | TitleMatch = 3    // Title contains query

/// Search result with relevance scoring
type SearchResult = {
    /// The matched Zettel
    Zettel: Zettel
    /// Relevance score (higher is more relevant)
    Score: float
    /// Highlighted matching snippets
    Highlights: string list
    /// Search type that matched
    MatchType: SearchMatchType
}

/// Vector search request
type VectorSearchRequest = {
    /// Query text to vectorize
    Query: string
    /// Maximum results to return
    Limit: int
    /// Minimum similarity threshold (0.0 to 1.0)
    Threshold: float
    /// Optional tag filter
    Tags: string list option
}

// ============================================================================
// API Response Types
// ============================================================================

/// Paginated list response
type PagedResult<'T> = {
    /// Items in this page
    Items: 'T list
    /// Total count across all pages
    Total: int
    /// Current page (1-indexed)
    Page: int
    /// Items per page
    PageSize: int
    /// Whether there are more pages
    HasMore: bool
}

/// Entropy metrics for dashboard
type EntropyMetrics = {
    /// Average entropy across all Zettels
    AverageEntropy: float
    /// Count of fresh Zettels (entropy < 0.3)
    FreshCount: int
    /// Count of aging Zettels (0.3 <= entropy < 0.6)
    AgingCount: int
    /// Count of rotting Zettels (entropy >= 0.6)
    RottingCount: int
    /// Top N most rotting Zettels
    TopRotting: ZettelNode list
    /// Metrics generation timestamp
    GeneratedAt: DateTime
}

/// Cluster information for graph navigation
type ClusterInfo = {
    /// Cluster name/identifier
    Name: string
    /// Number of Zettels in cluster
    ZettelCount: int
    /// Average entropy of cluster
    AverageEntropy: float
    /// Representative tags
    TopTags: string list
}

// ============================================================================
// MCP Types (Model Context Protocol for AI Agents)
// ============================================================================

/// MCP metadata
type McpMetadata = {
    /// Zettel ID
    Id: Guid
    /// Title
    Title: string
    /// Tags
    Tags: string list
    /// Entropy score
    Entropy: float
    /// Last modified
    ModifiedAt: DateTime
}

/// MCP read_zettel response
type McpZettelContext = {
    /// Main content
    Content: string
    /// Metadata
    Metadata: McpMetadata
    /// Related context (backlink titles)
    RelatedContext: string list
}

/// MCP search response
type McpSearchResult = {
    /// Title
    Title: string
    /// Truncated content
    ContentPreview: string
    /// Relevance score
    Score: float
    /// Zettel ID for follow-up queries
    Id: Guid
}

// ============================================================================
// Utility Functions
// ============================================================================

module Zettel =
    /// Create a new Zettel with defaults
    let create title content tags =
        let now = DateTime.UtcNow
        {
            Id = Guid.NewGuid()
            Title = title
            Content = content
            Tags = tags
            Backlinks = []
            Entropy = 0.0
            Level = HolonLevel.Atomic
            DecayRate = DecayRate.Medium
            CreatedAt = now
            ModifiedAt = now
            VerifiedAt = Some now
            ContentHash = content.GetHashCode().ToString("X8")
        }

    /// Check if Zettel is fresh (low entropy)
    let isFresh (z: Zettel) = z.Entropy < 0.3

    /// Check if Zettel is rotting (high entropy)
    let isRotting (z: Zettel) = z.Entropy >= 0.6

module Entropy =
    /// Map entropy to color for visualization
    /// Uses Tailwind CSS color palette
    let toColor (entropy: float) =
        match entropy with
        | e when e < 0.2 -> "#22c55e"  // green-500 (fresh)
        | e when e < 0.4 -> "#84cc16"  // lime-500
        | e when e < 0.6 -> "#eab308"  // yellow-500 (aging)
        | e when e < 0.8 -> "#f97316"  // orange-500 (stale)
        | _ -> "#ef4444"               // red-500 (rotting)

    /// Get human-readable label for entropy
    let toLabel (entropy: float) =
        if entropy < 0.3 then "Fresh"
        elif entropy < 0.6 then "Aging"
        else "Rotting"

    /// Calculate entropy based on age and decay rate
    let calculate (modifiedAt: DateTime) (verifiedAt: DateTime option) (decayRate: DecayRate) =
        let age = (DateTime.UtcNow - modifiedAt).TotalDays
        let rateMultiplier =
            match decayRate with
            | DecayRate.Fast -> 0.05
            | DecayRate.Medium -> 0.01
            | DecayRate.Slow -> 0.001
            | _ -> 0.01
        let verificationBonus =
            match verifiedAt with
            | Some v when (DateTime.UtcNow - v).TotalDays < 30.0 -> 0.5
            | Some _ -> 0.8
            | None -> 1.0
        Math.Clamp(age * rateMultiplier * verificationBonus, 0.0, 1.0)
