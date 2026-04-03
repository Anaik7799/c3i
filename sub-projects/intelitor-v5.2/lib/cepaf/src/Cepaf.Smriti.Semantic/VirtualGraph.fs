/// Virtual Graph - Stardog-Inspired SQL-to-RDF Mapping
///
/// Maps external data sources (SQLite, DuckDB) to RDF graphs
/// WITHOUT copying data - queries are translated on-the-fly.
///
/// Key Features:
/// - R2RML-inspired mapping syntax
/// - Query-time translation (no ETL)
/// - Cache layer for performance
/// - SMRITI integration (Zettels as virtual nodes)
///
/// STAMP Constraints:
/// - SC-SEM-010: Virtual graphs are read-only by default
/// - SC-SEM-011: Cache invalidation on source change
/// - SC-SEM-012: Query translation < 10ms
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open System.Collections.Generic
open System.Text.RegularExpressions
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared

/// Cache entry for virtual graph results
type CacheEntry = {
    Triples: Triple list
    CachedAt: DateTime
    ExpiresAt: DateTime
    QueryHash: string
}

/// Virtual Graph Engine
/// Note: Module named VirtualGraphEngine to avoid conflict with VirtualGraph type
module VirtualGraphEngine =

    /// In-memory cache (production would use Redis/ETS)
    let private cache = Dictionary<string, CacheEntry>()

    /// Compile subject template to SQL expression
    /// Template: "http://indrajaal.ai/person/{id}" + row["id"] = "123"
    /// Result: "http://indrajaal.ai/person/123"
    let compileSubjectTemplate (template: string) (row: IDictionary<string, obj>) : string =
        let mutable result = template
        let pattern = Regex(@"\{(\w+)\}")
        for m in pattern.Matches(template) do
            let columnName = m.Groups.[1].Value
            match row.TryGetValue(columnName) with
            | true, value -> result <- result.Replace(m.Value, value.ToString())
            | false, _ -> ()
        result

    /// Generate SELECT clause for a table mapping
    let generateSelect (mapping: TableMapping) : string =
        let columns =
            mapping.Columns
            |> List.map (fun c -> c.Column)
            |> String.concat ", "
        $"SELECT {columns} FROM {mapping.TableName}"

    /// Generate WHERE clause if filter exists
    let generateWhere (mapping: TableMapping) : string =
        match mapping.Filter with
        | Some filter -> $" WHERE {filter}"
        | None -> ""

    /// Execute SQL and convert rows to triples
    let executeMapping (conn: SqliteConnection) (mapping: TableMapping) : Triple list =
        let sql = generateSelect mapping + generateWhere mapping
        use cmd = new SqliteCommand(sql, conn)
        use reader = cmd.ExecuteReader()

        let triples = ResizeArray<Triple>()
        let classIri = mapping.RdfClass

        while reader.Read() do
            // Build row dictionary
            let row = Dictionary<string, obj>()
            for i in 0 .. reader.FieldCount - 1 do
                if not (reader.IsDBNull(i)) then
                    row.[reader.GetName(i)] <- reader.GetValue(i)

            // Generate subject IRI
            let subjectUri = compileSubjectTemplate mapping.SubjectTemplate row
            let subject = IriTerm (FullIRI subjectUri)

            // Add rdf:type triple
            triples.Add(Triple.isA (FullIRI subjectUri) classIri)

            // Add property triples
            for colMapping in mapping.Columns do
                if not colMapping.IsSubject then
                    match row.TryGetValue(colMapping.Column) with
                    | true, value when value <> null ->
                        let obj =
                            match colMapping.Datatype with
                            | Some dt ->
                                LiteralTerm {
                                    Value = value.ToString()
                                    Language = None
                                    Datatype = Some dt
                                }
                            | None ->
                                LiteralTerm {
                                    Value = value.ToString()
                                    Language = None
                                    Datatype = None
                                }
                        triples.Add({
                            Subject = subject
                            Predicate = colMapping.Predicate
                            Object = obj
                        })
                    | _ -> ()

        triples |> Seq.toList

    /// Query a virtual graph with caching
    let queryVirtualGraph
        (virtualGraph: VirtualGraph)
        (pattern: TriplePattern option)
        : TripleStoreResult<Triple list> =

        try
            // Check cache first
            let cacheKey = $"{virtualGraph.Name.AsString()}:{pattern}"
            match cache.TryGetValue(cacheKey) with
            | true, entry when entry.ExpiresAt > DateTime.UtcNow ->
                Success entry.Triples
            | _ ->
                // Open connection
                use conn = new SqliteConnection(virtualGraph.ConnectionString)
                conn.Open()

                // Execute all mappings
                let allTriples =
                    virtualGraph.Mappings
                    |> List.collect (executeMapping conn)

                // Filter by pattern if provided
                let filtered =
                    match pattern with
                    | Some p ->
                        allTriples
                        |> List.filter (fun t ->
                            let matchSubject =
                                match p.Subject with
                                | Variable _ -> true
                                | other -> t.Subject = other
                            let matchPredicate =
                                match p.Predicate with
                                | Variable _ -> true
                                | IriTerm iri -> t.Predicate = iri
                                | _ -> true
                            let matchObject =
                                match p.Object with
                                | Variable _ -> true
                                | other -> t.Object = other
                            matchSubject && matchPredicate && matchObject
                        )
                    | None -> allTriples

                // Cache results
                if virtualGraph.CacheTTL > 0 then
                    let entry = {
                        Triples = filtered
                        CachedAt = DateTime.UtcNow
                        ExpiresAt = DateTime.UtcNow.AddSeconds(float virtualGraph.CacheTTL)
                        QueryHash = cacheKey
                    }
                    cache.[cacheKey] <- entry

                Success filtered
        with ex ->
            Error $"Virtual graph query failed: {ex.Message}"

    /// Create a virtual graph for SMRITI Zettels
    let smritiZettelMapping : TableMapping =
        {
            Id = "smriti-zettel"
            TableName = "zettels"
            RdfClass = IRI.indrajaal "Zettel"
            SubjectTemplate = "http://indrajaal.ai/smriti/zettel/{id}"
            Columns = [
                { Column = "id"; Predicate = IRI.indrajaal "id"; Datatype = None; IsSubject = true }
                { Column = "title"; Predicate = PrefixedIRI ("dc", "title"); Datatype = None; IsSubject = false }
                { Column = "content"; Predicate = PrefixedIRI ("dc", "description"); Datatype = None; IsSubject = false }
                { Column = "entropy"; Predicate = IRI.indrajaal "entropy"; Datatype = Some (PrefixedIRI ("xsd", "float")); IsSubject = false }
                { Column = "created_at"; Predicate = PrefixedIRI ("dc", "created"); Datatype = Some (PrefixedIRI ("xsd", "dateTime")); IsSubject = false }
                { Column = "modified_at"; Predicate = PrefixedIRI ("dc", "modified"); Datatype = Some (PrefixedIRI ("xsd", "dateTime")); IsSubject = false }
            ]
            Filter = None
        }

    /// Create a virtual graph for SMRITI backlinks
    let smritiBacklinkMapping : TableMapping =
        {
            Id = "smriti-backlink"
            TableName = "zettel_links"
            RdfClass = IRI.indrajaal "ZettelLink"
            SubjectTemplate = "http://indrajaal.ai/smriti/link/{source_id}_{target_id}"
            Columns = [
                { Column = "source_id"; Predicate = IRI.indrajaal "source"; Datatype = None; IsSubject = false }
                { Column = "target_id"; Predicate = IRI.indrajaal "target"; Datatype = None; IsSubject = false }
                { Column = "link_type"; Predicate = IRI.indrajaal "linkType"; Datatype = None; IsSubject = false }
                { Column = "weight"; Predicate = IRI.indrajaal "weight"; Datatype = Some (PrefixedIRI ("xsd", "float")); IsSubject = false }
            ]
            Filter = None
        }

    /// Create SMRITI virtual graph definition
    let createSmritiVirtualGraph (dbPath: string) : VirtualGraph =
        {
            Name = FullIRI "http://indrajaal.ai/smriti/graph"
            SourceType = "SQLite"
            ConnectionString = $"Data Source={dbPath}"
            Mappings = [smritiZettelMapping; smritiBacklinkMapping]
            CacheTTL = 60  // 60 second cache
            Enabled = true
        }

    /// Translate SPARQL-like pattern to SQL WHERE clause
    let translatePatternToSql (mapping: TableMapping) (pattern: TriplePattern) : string option =
        let conditions = ResizeArray<string>()

        // Subject condition
        match pattern.Subject with
        | IriTerm (FullIRI uri) when uri.StartsWith(mapping.SubjectTemplate.Replace("{id}", "")) ->
            let id = uri.Substring(mapping.SubjectTemplate.Replace("{id}", "").Length)
            // Find the subject column
            match mapping.Columns |> List.tryFind (fun c -> c.IsSubject) with
            | Some col -> conditions.Add($"{col.Column} = '{id}'")
            | None -> ()
        | Variable _ -> ()  // Wildcard
        | _ -> ()

        // Predicate/Object conditions would need more complex translation
        // This is a simplified version

        if conditions.Count > 0 then
            Some (String.Join(" AND ", conditions))
        else
            None

    /// Invalidate cache for a virtual graph
    let invalidateCache (graphUri: string) =
        let keysToRemove =
            cache.Keys
            |> Seq.filter (fun k -> k.StartsWith(graphUri))
            |> Seq.toList
        for key in keysToRemove do
            cache.Remove(key) |> ignore

    /// Get cache statistics
    let getCacheStats () =
        let total = cache.Count
        let expired =
            cache.Values
            |> Seq.filter (fun e -> e.ExpiresAt < DateTime.UtcNow)
            |> Seq.length
        {|
            TotalEntries = total
            ExpiredEntries = expired
            ActiveEntries = total - expired
        |}


/// Virtual Graph for DuckDB (Analytics/History)
module VirtualGraphDuckDB =

    open DuckDB.NET.Data

    /// Execute DuckDB query and convert to triples
    let executeAnalyticsQuery (connString: string) (sql: string) (mapping: TableMapping) : Triple list =
        use conn = new DuckDBConnection(connString)
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- sql

        use reader = cmd.ExecuteReader()
        let triples = ResizeArray<Triple>()

        while reader.Read() do
            let row = Dictionary<string, obj>()
            for i in 0 .. reader.FieldCount - 1 do
                if not (reader.IsDBNull(i)) then
                    row.[reader.GetName(i)] <- reader.GetValue(i)

            let subjectUri = VirtualGraphEngine.compileSubjectTemplate mapping.SubjectTemplate row
            let subject = IriTerm (FullIRI subjectUri)

            // Add class triple
            triples.Add(Triple.isA (FullIRI subjectUri) mapping.RdfClass)

            // Add properties
            for colMapping in mapping.Columns do
                if not colMapping.IsSubject then
                    match row.TryGetValue(colMapping.Column) with
                    | true, value when value <> null ->
                        let obj = LiteralTerm {
                            Value = value.ToString()
                            Language = None
                            Datatype = colMapping.Datatype
                        }
                        triples.Add({
                            Subject = subject
                            Predicate = colMapping.Predicate
                            Object = obj
                        })
                    | _ -> ()

        triples |> Seq.toList

    /// Time-series query (replaces TimescaleDB)
    let timeSeriesAsTriples
        (connString: string)
        (tableName: string)
        (timeColumn: string)
        (valueColumn: string)
        (startTime: DateTime)
        (endTime: DateTime)
        : Triple list =

        let sql = $"""
            SELECT
                {timeColumn} as timestamp,
                {valueColumn} as value,
                row_number() OVER (ORDER BY {timeColumn}) as id
            FROM {tableName}
            WHERE {timeColumn} BETWEEN '{startTime:O}' AND '{endTime:O}'
            ORDER BY {timeColumn}
        """

        let mapping = {
            Id = "timeseries"
            TableName = tableName
            RdfClass = IRI.indrajaal "TimeSeriesPoint"
            SubjectTemplate = $"http://indrajaal.ai/timeseries/{tableName}/{{id}}"
            Columns = [
                { Column = "id"; Predicate = IRI.indrajaal "id"; Datatype = None; IsSubject = true }
                { Column = "timestamp"; Predicate = IRI.indrajaal "timestamp"; Datatype = Some (PrefixedIRI ("xsd", "dateTime")); IsSubject = false }
                { Column = "value"; Predicate = IRI.indrajaal "value"; Datatype = Some (PrefixedIRI ("xsd", "double")); IsSubject = false }
            ]
            Filter = None
        }

        executeAnalyticsQuery connString sql mapping

    /// ASOF join query (DuckDB specialty, replaces TimescaleDB)
    let asofJoinAsTriples
        (connString: string)
        (leftTable: string)
        (rightTable: string)
        (leftTimeCol: string)
        (rightTimeCol: string)
        : Triple list =

        let sql = $"""
            SELECT
                l.*,
                r.*
            FROM {leftTable} l
            ASOF JOIN {rightTable} r
            ON l.{leftTimeCol} >= r.{rightTimeCol}
        """

        use conn = new DuckDBConnection(connString)
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- sql

        use reader = cmd.ExecuteReader()
        let triples = ResizeArray<Triple>()
        let mutable rowNum = 0

        while reader.Read() do
            rowNum <- rowNum + 1
            let subject = FullIRI $"http://indrajaal.ai/asof/{leftTable}/{rowNum}"

            // Add class
            triples.Add(Triple.isA subject (IRI.indrajaal "AsofJoinResult"))

            // Add all columns as properties
            for i in 0 .. reader.FieldCount - 1 do
                if not (reader.IsDBNull(i)) then
                    let colName = reader.GetName(i)
                    let value = reader.GetValue(i)
                    triples.Add(Triple.withLiteral subject (IRI.indrajaal colName) (value.ToString()))

        triples |> Seq.toList
