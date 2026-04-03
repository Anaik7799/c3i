/// SMRITI Semantic Types - RDF/Graph Database Primitives
///
/// Combines best practices from:
/// - Stardog: Virtual graph mapping, query-time reasoning
/// - GraphDB: Materialized inference, forward-chaining
///
/// STAMP Constraints:
/// - SC-SEM-001: All triples are immutable
/// - SC-SEM-002: IRIs use Indrajaal namespace
/// - SC-SEM-003: Inference rules are versioned
/// - SC-SEM-004: Cross-runtime compatible (F#/Elixir)
///
/// Version: 2.0.0
/// Author: Claude Opus 4.5
namespace Cepaf.Smriti.Semantic

open System
open System.Text.Json.Serialization
open Cepaf.Smriti.Shared

// ============================================================================
// RDF Core Types (W3C Standard Compatible)
// ============================================================================

/// IRI (Internationalized Resource Identifier)
/// Similar to URI but with Unicode support
type IRI =
    | FullIRI of string                     // <http://indrajaal.ai/ontology#Person>
    | PrefixedIRI of prefix: string * local: string  // foaf:Person

    member this.AsString () =
        match this with
        | FullIRI uri -> uri
        | PrefixedIRI (p, l) -> $"{p}:{l}"

/// RDF Literal Value
type Literal = {
    /// String value
    Value: string
    /// Optional language tag (e.g., "en", "hi")
    Language: string option
    /// Optional datatype IRI (e.g., xsd:integer)
    Datatype: IRI option
}

/// RDF Term - can be IRI, Blank Node, or Literal
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type RdfTerm =
    | IriTerm of IRI
    | BlankNode of string           // _:b0
    | LiteralTerm of Literal
    | Variable of string            // ?x (for queries)

/// RDF Triple (Subject-Predicate-Object)
/// The fundamental unit of knowledge in RDF
type Triple = {
    Subject: RdfTerm
    Predicate: IRI
    Object: RdfTerm
}

/// Named Graph - collection of triples with a name
type NamedGraph = {
    Name: IRI
    Triples: Triple list
    CreatedAt: DateTime
    ModifiedAt: DateTime
}

/// Quad = Triple + Graph Name
type Quad = {
    Subject: RdfTerm
    Predicate: IRI
    Object: RdfTerm
    Graph: IRI
}

// ============================================================================
// Inference & Reasoning Types
// ============================================================================

/// Reasoning strategy (Stardog vs GraphDB philosophy)
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type ReasoningStrategy =
    /// Stardog-style: Compute inferences at query time
    | QueryTime = 0
    /// GraphDB-style: Compute inferences at load time
    | LoadTime = 1
    /// Hybrid: Critical paths at load, complex at query
    | Hybrid = 2

/// OWL/RDFS Reasoning Profile
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type ReasoningProfile =
    | RDFS = 0              // Basic: subClass, subProperty, domain, range
    | OWLRL = 1             // OWL RL (rule-based subset)
    | OWLEL = 2             // OWL EL (description logic)
    | OWLQL = 3             // OWL QL (query answering)
    | Custom = 4            // Custom rules only

/// Triple pattern with variables (for queries and inference rules)
type TriplePattern = {
    Subject: RdfTerm
    Predicate: RdfTerm   // Can be variable
    Object: RdfTerm
}

/// Inference Rule (If-Then Logic)
/// Stardog Rules style - easier than SWRL
type InferenceRule = {
    /// Unique rule ID
    Id: string
    /// Human-readable name
    Name: string
    /// Antecedent (IF part) - triple patterns (can contain Variables)
    If: TriplePattern list
    /// Consequent (THEN part) - patterns to infer (can contain Variables)
    Then: TriplePattern list
    /// Priority (higher = runs first)
    Priority: int
    /// Is this rule active?
    Enabled: bool
    /// Namespace this rule applies to
    Namespace: IRI option
}

/// Materialized Inference Result
type InferredTriple = {
    /// The inferred triple
    Triple: Triple
    /// Rule that produced this inference
    SourceRule: string
    /// Original triples used as evidence
    Evidence: Triple list
    /// When this was inferred
    InferredAt: DateTime
    /// Confidence score (0.0 to 1.0)
    Confidence: float
}

// ============================================================================
// Virtual Graph Types (Stardog-Inspired)
// ============================================================================

/// SQL-to-RDF Column Mapping
type ColumnMapping = {
    /// SQL column name
    Column: string
    /// RDF predicate IRI
    Predicate: IRI
    /// Optional datatype conversion
    Datatype: IRI option
    /// Is this column the subject ID?
    IsSubject: bool
}

/// SQL Table-to-RDF Class Mapping (R2RML-inspired)
type TableMapping = {
    /// Unique mapping ID
    Id: string
    /// SQL table name
    TableName: string
    /// RDF class for instances
    RdfClass: IRI
    /// Subject IRI template (e.g., "http://indrajaal.ai/person/{id}")
    SubjectTemplate: string
    /// Column mappings
    Columns: ColumnMapping list
    /// Optional SQL filter (WHERE clause)
    Filter: string option
}

/// Virtual Graph Definition
/// Maps external data source to RDF without copying
type VirtualGraph = {
    /// Unique graph name
    Name: IRI
    /// Source type (SQLite, DuckDB, PostgreSQL, etc.)
    SourceType: string
    /// Connection string
    ConnectionString: string
    /// Table mappings
    Mappings: TableMapping list
    /// Cache TTL in seconds (0 = no cache)
    CacheTTL: int
    /// Is this virtual graph active?
    Enabled: bool
}

// ============================================================================
// Query Types (SPARQL-Inspired)
// ============================================================================

/// SPARQL Query Type
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type QueryType =
    | Select = 0    // SELECT ?x ?y WHERE { ... }
    | Construct = 1 // CONSTRUCT { ... } WHERE { ... }
    | Ask = 2       // ASK { ... } → boolean
    | Describe = 3  // DESCRIBE <uri>

/// Graph Pattern (BGP, OPTIONAL, UNION, etc.)
type GraphPattern =
    | BasicGraphPattern of TriplePattern list
    | Optional of GraphPattern
    | Union of GraphPattern list
    | Filter of expression: string * pattern: GraphPattern
    | Bind of variable: string * expression: string * pattern: GraphPattern

/// SPARQL-like Query
type SemanticQuery = {
    /// Query type
    Type: QueryType
    /// Variables to select
    Select: string list
    /// Graph pattern (WHERE clause)
    Where: GraphPattern
    /// ORDER BY clause
    OrderBy: (string * bool) list  // (variable, ascending)
    /// LIMIT
    Limit: int option
    /// OFFSET
    Offset: int option
    /// Named graphs to query
    From: IRI list
    /// Enable reasoning?
    Reasoning: bool
}

/// Query Result Binding
type Binding = {
    Variable: string
    Value: RdfTerm
}

/// Query Result Row
type ResultRow = Binding list

/// Query Results
type QueryResult = {
    /// Column names
    Variables: string list
    /// Result rows
    Rows: ResultRow list
    /// Query execution time in ms
    ExecutionTimeMs: int64
    /// Was reasoning applied?
    ReasoningApplied: bool
    /// Inferences used
    InferencesUsed: int
}

// ============================================================================
// Text Mining / NLP Types (GraphDB-Inspired)
// ============================================================================

/// Named Entity Type
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type EntityType =
    | Person = 0
    | Organization = 1
    | Location = 2
    | Date = 3
    | Money = 4
    | Technology = 5
    | Concept = 6
    | Custom = 99

/// Extracted Entity from Text
type ExtractedEntity = {
    /// The entity text
    Text: string
    /// Entity type
    Type: EntityType
    /// Start position in source
    StartOffset: int
    /// End position in source
    EndOffset: int
    /// Confidence score
    Confidence: float
    /// Optional linked IRI (if entity resolution succeeded)
    LinkedIri: IRI option
}

/// Extracted Relation between Entities
type ExtractedRelation = {
    /// Subject entity
    Subject: ExtractedEntity
    /// Predicate text
    PredicateText: string
    /// Suggested predicate IRI
    PredicateIri: IRI option
    /// Object entity
    Object: ExtractedEntity
    /// Confidence score
    Confidence: float
}

/// Text Mining Result
type TextMiningResult = {
    /// Source document ID
    SourceId: string
    /// Extracted entities
    Entities: ExtractedEntity list
    /// Extracted relations
    Relations: ExtractedRelation list
    /// Generated triples
    Triples: Triple list
    /// Processing time in ms
    ProcessingTimeMs: int64
}

// ============================================================================
// Vector Similarity Types
// ============================================================================

/// Vector embedding
type Embedding = {
    /// Entity IRI this embedding represents
    Entity: IRI
    /// Vector dimensions
    Vector: float array
    /// Embedding model used
    Model: string
    /// When this was generated
    GeneratedAt: DateTime
}

/// Similarity result
type SimilarityResult = {
    /// The similar entity
    Entity: IRI
    /// Cosine similarity score (0.0 to 1.0)
    Score: float
    /// Optional label
    Label: string option
}

// ============================================================================
// Connector Types (GraphDB-Inspired)
// ============================================================================

/// Search engine connector type
[<JsonConverter(typeof<JsonStringEnumConverter>)>]
type ConnectorType =
    | Lucene = 0
    | Elasticsearch = 1
    | Solr = 2
    | SMRITI = 3          // Our internal SMRITI connector
    | SparqlEndpoint = 4
    | Webhook = 5

/// Index field definition
type IndexField = {
    /// Field name in index
    Name: string
    /// Predicate(s) to index
    Predicates: IRI list
    /// Is this field analyzed (tokenized)?
    Analyzed: bool
    /// Is this a facet?
    Faceted: bool
}

/// Search Connector Definition
type SearchConnector = {
    /// Connector name
    Name: string
    /// Connector type
    Type: ConnectorType
    /// Connection endpoint
    Endpoint: string
    /// Fields to index
    Fields: IndexField list
    /// Auto-sync on graph changes?
    AutoSync: bool
    /// Sync interval in seconds
    SyncIntervalSec: int
}

// ============================================================================
// Utility Functions
// ============================================================================

module IRI =
    /// Indrajaal base namespace
    let indrajaalBase = "http://indrajaal.ai/ontology#"

    /// Create IRI in Indrajaal namespace
    let indrajaal local = FullIRI $"{indrajaalBase}{local}"

    /// Common prefixes
    let prefixes = Map.ofList [
        "rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        "rdfs", "http://www.w3.org/2000/01/rdf-schema#"
        "owl", "http://www.w3.org/2002/07/owl#"
        "xsd", "http://www.w3.org/2001/XMLSchema#"
        "foaf", "http://xmlns.com/foaf/0.1/"
        "dc", "http://purl.org/dc/elements/1.1/"
        "skos", "http://www.w3.org/2004/02/skos/core#"
        "ind", indrajaalBase
        "chaya", "http://indrajaal.ai/chaya#"
        "smriti", "http://indrajaal.ai/smriti#"
    ]

    /// Expand prefixed IRI
    let expand (iri: IRI) =
        match iri with
        | FullIRI uri -> uri
        | PrefixedIRI (p, l) ->
            match Map.tryFind p prefixes with
            | Some baseUri -> baseUri + l
            | None -> $"{p}:{l}"

module Triple =
    /// Create a simple triple
    let create (subject: IRI) (predicate: IRI) (obj: RdfTerm) : Triple =
        {
            Subject = IriTerm subject
            Predicate = predicate
            Object = obj
        }

    /// Create triple with literal object
    let withLiteral (subject: IRI) (predicate: IRI) (value: string) : Triple =
        {
            Subject = IriTerm subject
            Predicate = predicate
            Object = LiteralTerm { Value = value; Language = None; Datatype = None }
        }

    /// Create rdf:type triple
    let isA (subject: IRI) (rdfClass: IRI) : Triple =
        {
            Subject = IriTerm subject
            Predicate = PrefixedIRI ("rdf", "type")
            Object = IriTerm rdfClass
        }

module InferenceRule =
    /// Standard RDFS subClassOf transitivity rule
    let rdfsSubClassTransitivity = {
        Id = "rdfs-subclass-transitivity"
        Name = "SubClass Transitivity"
        If = [
            { Subject = Variable "?a"; Predicate = IriTerm (PrefixedIRI ("rdfs", "subClassOf")); Object = Variable "?b" }
            { Subject = Variable "?b"; Predicate = IriTerm (PrefixedIRI ("rdfs", "subClassOf")); Object = Variable "?c" }
        ]
        Then = [
            { Subject = Variable "?a"; Predicate = IriTerm (PrefixedIRI ("rdfs", "subClassOf")); Object = Variable "?c" }
        ]
        Priority = 100
        Enabled = true
        Namespace = None
    }

    /// Standard RDFS type inference via subClassOf
    let rdfsTypeInference = {
        Id = "rdfs-type-inference"
        Name = "Type Inference via SubClass"
        If = [
            { Subject = Variable "?x"; Predicate = IriTerm (PrefixedIRI ("rdf", "type")); Object = Variable "?a" }
            { Subject = Variable "?a"; Predicate = IriTerm (PrefixedIRI ("rdfs", "subClassOf")); Object = Variable "?b" }
        ]
        Then = [
            { Subject = Variable "?x"; Predicate = IriTerm (PrefixedIRI ("rdf", "type")); Object = Variable "?b" }
        ]
        Priority = 90
        Enabled = true
        Namespace = None
    }
