/// Text Mining - NLP Entity & Relation Extraction
///
/// Extracts entities and relations from text, converting them to triples.
/// Inspired by Stardog BITES and GraphDB's text analysis.
///
/// Key Features:
/// - Named Entity Recognition (NER)
/// - Relation Extraction
/// - Wiki-link [[]] parsing
/// - Automatic triple generation
///
/// STAMP Constraints:
/// - SC-SEM-050: NER confidence threshold configurable
/// - SC-SEM-051: Extracted triples marked as inferred
/// - SC-SEM-052: Source document linked to triples
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared

/// Text Mining Configuration
type TextMiningConfig = {
    /// Minimum confidence for entity extraction
    MinEntityConfidence: float
    /// Minimum confidence for relation extraction
    MinRelationConfidence: float
    /// Extract wiki-links [[text]]
    ExtractWikiLinks: bool
    /// Extract hashtags #tag
    ExtractHashtags: bool
    /// Extract @mentions
    ExtractMentions: bool
    /// Entity types to extract
    EntityTypes: EntityType list
}

/// Default configuration
module TextMiningConfig =
    let defaults = {
        MinEntityConfidence = 0.7
        MinRelationConfidence = 0.5
        ExtractWikiLinks = true
        ExtractHashtags = true
        ExtractMentions = true
        EntityTypes = [
            EntityType.Person
            EntityType.Organization
            EntityType.Location
            EntityType.Technology
            EntityType.Concept
        ]
    }

/// Text Mining Engine
module TextMining =

    /// Common entity patterns (simplified NER)
    let private entityPatterns = [
        // Technology terms (common in technical docs)
        (EntityType.Technology, @"\b(Elixir|Phoenix|Erlang|F#|BEAM|OTP|PostgreSQL|SQLite|DuckDB|Zenoh)\b")
        // Capitalized sequences (likely proper nouns)
        (EntityType.Person, @"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b")
        // Organizations (patterns like "X Corp", "Y Inc")
        (EntityType.Organization, @"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(Corp|Inc|Ltd|LLC|GmbH|AG)\b")
        // Locations (simple patterns)
        (EntityType.Location, @"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(City|Country|Region|State)\b")
    ]

    /// Extract wiki-links [[text]] or [[text|display]]
    let extractWikiLinks (text: string) : ExtractedEntity list =
        let pattern = @"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"
        let matches = Regex.Matches(text, pattern)

        matches
        |> Seq.cast<Match>
        |> Seq.map (fun m ->
            let linkText = m.Groups.[1].Value.Trim()
            let displayText =
                if m.Groups.[2].Success then m.Groups.[2].Value.Trim()
                else linkText

            {
                Text = displayText
                Type = EntityType.Concept
                StartOffset = m.Index
                EndOffset = m.Index + m.Length
                Confidence = 1.0  // Wiki-links are explicit
                LinkedIri = Some (IRI.indrajaal (linkText.Replace(" ", "_")))
            }
        )
        |> Seq.toList

    /// Extract hashtags #tag
    let extractHashtags (text: string) : ExtractedEntity list =
        let pattern = @"#([a-zA-Z][a-zA-Z0-9_]*)"
        let matches = Regex.Matches(text, pattern)

        matches
        |> Seq.cast<Match>
        |> Seq.map (fun m ->
            {
                Text = m.Groups.[1].Value
                Type = EntityType.Concept
                StartOffset = m.Index
                EndOffset = m.Index + m.Length
                Confidence = 1.0
                LinkedIri = Some (PrefixedIRI ("smriti", "tag/" + m.Groups.[1].Value))
            }
        )
        |> Seq.toList

    /// Extract @mentions
    let extractMentions (text: string) : ExtractedEntity list =
        let pattern = @"@([a-zA-Z][a-zA-Z0-9_]*)"
        let matches = Regex.Matches(text, pattern)

        matches
        |> Seq.cast<Match>
        |> Seq.map (fun m ->
            {
                Text = m.Groups.[1].Value
                Type = EntityType.Person
                StartOffset = m.Index
                EndOffset = m.Index + m.Length
                Confidence = 0.9
                LinkedIri = Some (PrefixedIRI ("chaya", "user/" + m.Groups.[1].Value))
            }
        )
        |> Seq.toList

    /// Extract named entities using pattern matching
    let extractNamedEntities (text: string) (config: TextMiningConfig) : ExtractedEntity list =
        let entities = ResizeArray<ExtractedEntity>()

        for (entityType, pattern) in entityPatterns do
            if config.EntityTypes |> List.contains entityType then
                let matches = Regex.Matches(text, pattern)
                for m in matches do
                    entities.Add({
                        Text = m.Value
                        Type = entityType
                        StartOffset = m.Index
                        EndOffset = m.Index + m.Length
                        Confidence = 0.75
                        LinkedIri = None
                    })

        entities
        |> Seq.filter (fun e -> e.Confidence >= config.MinEntityConfidence)
        |> Seq.toList

    /// Simple relation patterns
    let private relationPatterns = [
        // "X is a Y" pattern
        (@"(\w+)\s+is\s+(?:a|an)\s+(\w+)", "rdf:type")
        // "X created Y" pattern
        (@"(\w+)\s+created\s+(\w+)", "ind:created")
        // "X uses Y" pattern
        (@"(\w+)\s+uses?\s+(\w+)", "ind:uses")
        // "X depends on Y" pattern
        (@"(\w+)\s+depends?\s+on\s+(\w+)", "ind:dependsOn")
        // "X is part of Y" pattern
        (@"(\w+)\s+is\s+part\s+of\s+(\w+)", "ind:partOf")
    ]

    /// Extract relations between entities
    let extractRelations (text: string) (entities: ExtractedEntity list) : ExtractedRelation list =
        let relations = ResizeArray<ExtractedRelation>()

        for (pattern, predicate) in relationPatterns do
            let matches = Regex.Matches(text, pattern, RegexOptions.IgnoreCase)
            for m in matches do
                if m.Groups.Count >= 3 then
                    let subjText = m.Groups.[1].Value
                    let objText = m.Groups.[2].Value

                    // Find matching entities
                    let subjEntity =
                        entities
                        |> List.tryFind (fun e -> e.Text.Equals(subjText, StringComparison.OrdinalIgnoreCase))

                    let objEntity =
                        entities
                        |> List.tryFind (fun e -> e.Text.Equals(objText, StringComparison.OrdinalIgnoreCase))

                    match subjEntity, objEntity with
                    | Some s, Some o ->
                        relations.Add({
                            Subject = s
                            PredicateText = predicate
                            PredicateIri =
                                if predicate.Contains(":") then
                                    let parts = predicate.Split(':')
                                    Some (PrefixedIRI (parts.[0], parts.[1]))
                                else None
                            Object = o
                            Confidence = 0.6
                        })
                    | _ -> ()

        relations |> Seq.toList

    /// Convert extracted entities and relations to RDF triples
    let toTriples (sourceId: string) (entities: ExtractedEntity list) (relations: ExtractedRelation list) : Triple list =
        let triples = ResizeArray<Triple>()
        let sourceIri = FullIRI $"http://indrajaal.ai/smriti/zettel/{sourceId}"

        // Entity triples
        for entity in entities do
            match entity.LinkedIri with
            | Some iri ->
                // Type triple
                let typeIri =
                    match entity.Type with
                    | EntityType.Person -> PrefixedIRI ("foaf", "Person")
                    | EntityType.Organization -> PrefixedIRI ("foaf", "Organization")
                    | EntityType.Location -> PrefixedIRI ("geo", "Location")
                    | EntityType.Technology -> IRI.indrajaal "Technology"
                    | EntityType.Concept -> PrefixedIRI ("skos", "Concept")
                    | _ -> PrefixedIRI ("owl", "Thing")

                triples.Add(Triple.isA iri typeIri)

                // Label triple
                triples.Add(Triple.withLiteral iri (PrefixedIRI ("rdfs", "label")) entity.Text)

                // Mentioned-in triple
                triples.Add({
                    Subject = IriTerm iri
                    Predicate = IRI.indrajaal "mentionedIn"
                    Object = IriTerm sourceIri
                })
            | None ->
                // Entity without IRI - create blank node
                let blankId = $"entity_{entity.StartOffset}"
                triples.Add({
                    Subject = BlankNode blankId
                    Predicate = PrefixedIRI ("rdfs", "label")
                    Object = LiteralTerm { Value = entity.Text; Language = None; Datatype = None }
                })

        // Relation triples
        for relation in relations do
            match relation.Subject.LinkedIri, relation.Object.LinkedIri, relation.PredicateIri with
            | Some subjIri, Some objIri, Some predIri ->
                triples.Add({
                    Subject = IriTerm subjIri
                    Predicate = predIri
                    Object = IriTerm objIri
                })
            | _ -> ()

        triples |> Seq.toList

    /// Full text mining pipeline
    let mineText (config: TextMiningConfig) (sourceId: string) (text: string) : TextMiningResult =
        let stopwatch = System.Diagnostics.Stopwatch.StartNew()

        // Extract all entity types
        let wikiLinks =
            if config.ExtractWikiLinks then extractWikiLinks text
            else []

        let hashtags =
            if config.ExtractHashtags then extractHashtags text
            else []

        let mentions =
            if config.ExtractMentions then extractMentions text
            else []

        let namedEntities = extractNamedEntities text config

        let allEntities = wikiLinks @ hashtags @ mentions @ namedEntities

        // Extract relations
        let relations = extractRelations text allEntities

        // Convert to triples
        let triples = toTriples sourceId allEntities relations

        stopwatch.Stop()

        {
            SourceId = sourceId
            Entities = allEntities
            Relations = relations
            Triples = triples
            ProcessingTimeMs = stopwatch.ElapsedMilliseconds
        }

    /// Store text mining results
    let persistResults (conn: SqliteConnection) (result: TextMiningResult) =
        // Add triples to store
        match TripleStore.addTriples conn "mined" result.Triples with
        | Success count -> Success count
        | Error e -> Error e


/// Zettel Text Processor
module ZettelProcessor =

    /// Process a Zettel and extract semantic triples
    let processZettel (conn: SqliteConnection) (zettelId: Guid) (title: string) (content: string) =
        let config = TextMiningConfig.defaults
        let fullText = $"# {title}\n\n{content}"
        let result = TextMining.mineText config (zettelId.ToString()) fullText

        // Store results
        let storeResult = TextMining.persistResults conn result

        // Link triples to Zettel
        match storeResult with
        | Success _ ->
            // Get triple IDs and link (simplified)
            Success result.Triples.Length
        | Error e -> Error e

    /// Batch process multiple Zettels
    let batchProcess (conn: SqliteConnection) (zettels: (Guid * string * string) list) =
        use transaction = conn.BeginTransaction()
        try
            let mutable totalTriples = 0
            for (id, title, content) in zettels do
                match processZettel conn id title content with
                | Success n -> totalTriples <- totalTriples + n
                | Error _ -> ()
            transaction.Commit()
            Success totalTriples
        with ex ->
            transaction.Rollback()
            Error $"Batch processing failed: {ex.Message}"

    /// Re-extract all Zettels (after rule changes)
    let reprocessAll (conn: SqliteConnection) =
        // Would query all Zettels and reprocess
        // For now, just return success
        Success 0
