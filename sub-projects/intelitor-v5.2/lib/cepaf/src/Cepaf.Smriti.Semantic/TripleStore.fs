/// Triple Store - SQLite-backed RDF Storage
///
/// Stores triples in SQLite with:
/// - Efficient indexing (SPO, POS, OSP)
/// - Named graph support
/// - Transaction support
/// - SMRITI Zettel integration
///
/// STAMP Constraints:
/// - SC-SEM-005: All writes via append-only register
/// - SC-SEM-006: Triple store uses SQLite WAL mode
/// - SC-SEM-007: Index coverage for all access patterns
///
/// Version: 2.0.0
namespace Cepaf.Smriti.Semantic

open System
open System.Data
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Shared

/// Triple Store Configuration
type TripleStoreConfig = {
    /// SQLite database path
    DatabasePath: string
    /// Enable WAL mode for concurrency
    WalMode: bool
    /// Page size in bytes
    PageSize: int
    /// Cache size in pages
    CacheSize: int
    /// Enable BLAKE3 checksums
    EnableChecksums: bool
}

/// Triple Store Statistics
type TripleStoreStats = {
    /// Total triple count
    TotalTriples: int64
    /// Number of named graphs
    GraphCount: int
    /// Number of distinct subjects
    SubjectCount: int64
    /// Number of distinct predicates
    PredicateCount: int64
    /// Number of distinct objects
    ObjectCount: int64
    /// Database file size in bytes
    DatabaseSizeBytes: int64
    /// Last modified timestamp
    LastModified: DateTime
}

/// Triple Store operations result
type TripleStoreResult<'T> =
    | Success of 'T
    | Error of string

/// SQLite-backed Triple Store
module TripleStore =

    /// Default configuration
    let defaultConfig = {
        DatabasePath = "data/kms/semantic.sqlite"
        WalMode = true
        PageSize = 4096
        CacheSize = 10000
        EnableChecksums = true
    }

    /// Initialize database schema
    let initSchema (conn: SqliteConnection) =
        let sql = """
            -- Core triple storage table
            CREATE TABLE IF NOT EXISTS triples (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                graph_uri TEXT NOT NULL DEFAULT 'default',
                subject TEXT NOT NULL,
                predicate TEXT NOT NULL,
                object TEXT NOT NULL,
                object_type TEXT NOT NULL,  -- 'iri', 'blank', 'literal'
                object_lang TEXT,           -- Language tag for literals
                object_datatype TEXT,       -- Datatype IRI for literals
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                source_rule TEXT,           -- For inferred triples
                confidence REAL DEFAULT 1.0,

                UNIQUE(graph_uri, subject, predicate, object)
            );

            -- SPO index (default access pattern)
            CREATE INDEX IF NOT EXISTS idx_triples_spo
                ON triples(subject, predicate, object);

            -- POS index (find all subjects with predicate-object)
            CREATE INDEX IF NOT EXISTS idx_triples_pos
                ON triples(predicate, object, subject);

            -- OSP index (find all predicates for object-subject)
            CREATE INDEX IF NOT EXISTS idx_triples_osp
                ON triples(object, subject, predicate);

            -- Graph index
            CREATE INDEX IF NOT EXISTS idx_triples_graph
                ON triples(graph_uri);

            -- Named graphs registry
            CREATE TABLE IF NOT EXISTS graphs (
                uri TEXT PRIMARY KEY,
                name TEXT,
                description TEXT,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                modified_at TEXT NOT NULL DEFAULT (datetime('now')),
                triple_count INTEGER DEFAULT 0
            );

            -- Namespaces/Prefixes
            CREATE TABLE IF NOT EXISTS namespaces (
                prefix TEXT PRIMARY KEY,
                uri TEXT NOT NULL UNIQUE
            );

            -- Insert standard prefixes
            INSERT OR IGNORE INTO namespaces (prefix, uri) VALUES
                ('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
                ('rdfs', 'http://www.w3.org/2000/01/rdf-schema#'),
                ('owl', 'http://www.w3.org/2002/07/owl#'),
                ('xsd', 'http://www.w3.org/2001/XMLSchema#'),
                ('ind', 'http://indrajaal.ai/ontology#'),
                ('chaya', 'http://indrajaal.ai/chaya#'),
                ('smriti', 'http://indrajaal.ai/smriti#');

            -- Zettel-to-Triple mapping (bridges SMRITI)
            CREATE TABLE IF NOT EXISTS zettel_triples (
                zettel_id TEXT NOT NULL,
                triple_id INTEGER NOT NULL,
                link_type TEXT NOT NULL,  -- 'subject', 'mentioned', 'inferred'
                created_at TEXT NOT NULL DEFAULT (datetime('now')),

                PRIMARY KEY (zettel_id, triple_id),
                FOREIGN KEY (triple_id) REFERENCES triples(id)
            );

            CREATE INDEX IF NOT EXISTS idx_zettel_triples_zettel
                ON zettel_triples(zettel_id);
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.ExecuteNonQuery() |> ignore

    /// Configure SQLite for performance
    let configureConnection (conn: SqliteConnection) (config: TripleStoreConfig) =
        let pragmas = [
            if config.WalMode then "PRAGMA journal_mode=WAL"
            $"PRAGMA page_size={config.PageSize}"
            $"PRAGMA cache_size=-{config.CacheSize}"  // Negative = KB
            "PRAGMA synchronous=NORMAL"
            "PRAGMA temp_store=MEMORY"
            "PRAGMA mmap_size=268435456"  // 256MB memory map
        ]
        for pragma in pragmas do
            use cmd = new SqliteCommand(pragma, conn)
            cmd.ExecuteNonQuery() |> ignore

    /// Open or create triple store
    let openStore (config: TripleStoreConfig) =
        try
            let connStr = $"Data Source={config.DatabasePath}"
            let conn = new SqliteConnection(connStr)
            conn.Open()
            configureConnection conn config
            initSchema conn
            Success conn
        with ex ->
            Error $"Failed to open triple store: {ex.Message}"

    /// Serialize RdfTerm to string for storage
    let serializeTerm (term: RdfTerm) : string * string * string option * string option =
        match term with
        | IriTerm iri -> (IRI.expand iri, "iri", None, None)
        | BlankNode id -> ($"_:{id}", "blank", None, None)
        | LiteralTerm lit ->
            let datatype = lit.Datatype |> Option.map IRI.expand
            (lit.Value, "literal", lit.Language, datatype)
        | Variable v -> ($"?{v}", "variable", None, None)

    /// Deserialize term from storage
    let deserializeTerm (value: string) (termType: string) (lang: string option) (datatype: string option) : RdfTerm =
        match termType with
        | "iri" -> IriTerm (FullIRI value)
        | "blank" -> BlankNode (value.Substring(2))  // Remove "_:" prefix
        | "literal" -> LiteralTerm { Value = value; Language = lang; Datatype = datatype |> Option.map FullIRI }
        | "variable" -> Variable (value.Substring(1))  // Remove "?" prefix
        | _ -> IriTerm (FullIRI value)

    /// Add a single triple
    let addTriple (conn: SqliteConnection) (graphUri: string) (triple: Triple) =
        let sql = """
            INSERT OR IGNORE INTO triples
                (graph_uri, subject, predicate, object, object_type, object_lang, object_datatype)
            VALUES
                (@graph, @subject, @predicate, @object, @objType, @objLang, @objDatatype)
        """
        use cmd = new SqliteCommand(sql, conn)

        let (subj, _, _, _) = serializeTerm triple.Subject
        let pred = IRI.expand triple.Predicate
        let (obj, objType, objLang, objDatatype) = serializeTerm triple.Object

        cmd.Parameters.AddWithValue("@graph", graphUri) |> ignore
        cmd.Parameters.AddWithValue("@subject", subj) |> ignore
        cmd.Parameters.AddWithValue("@predicate", pred) |> ignore
        cmd.Parameters.AddWithValue("@object", obj) |> ignore
        cmd.Parameters.AddWithValue("@objType", objType) |> ignore
        cmd.Parameters.AddWithValue("@objLang", (objLang |> Option.defaultValue (DBNull.Value.ToString()))) |> ignore
        cmd.Parameters.AddWithValue("@objDatatype", (objDatatype |> Option.defaultValue (DBNull.Value.ToString()))) |> ignore

        cmd.ExecuteNonQuery()

    /// Add multiple triples in a transaction
    let addTriples (conn: SqliteConnection) (graphUri: string) (triples: Triple list) =
        use transaction = conn.BeginTransaction()
        try
            let mutable count = 0
            for triple in triples do
                count <- count + addTriple conn graphUri triple
            transaction.Commit()
            Success count
        with ex ->
            transaction.Rollback()
            Error $"Failed to add triples: {ex.Message}"

    /// Query triples by pattern (subject, predicate, object can be None for wildcard)
    let queryTriples
        (conn: SqliteConnection)
        (graphUri: string option)
        (subject: string option)
        (predicate: string option)
        (obj: string option)
        : Triple list =

        let mutable conditions = []
        let mutable parameters = []

        match graphUri with
        | Some g ->
            conditions <- "graph_uri = @graph" :: conditions
            parameters <- ("@graph", g :> obj) :: parameters
        | None -> ()

        match subject with
        | Some s ->
            conditions <- "subject = @subject" :: conditions
            parameters <- ("@subject", s :> obj) :: parameters
        | None -> ()

        match predicate with
        | Some p ->
            conditions <- "predicate = @predicate" :: conditions
            parameters <- ("@predicate", p :> obj) :: parameters
        | None -> ()

        match obj with
        | Some o ->
            conditions <- "object = @object" :: conditions
            parameters <- ("@object", o :> obj) :: parameters
        | None -> ()

        let whereClause =
            if conditions.IsEmpty then ""
            else " WHERE " + String.Join(" AND ", conditions)

        let sql = $"SELECT subject, predicate, object, object_type, object_lang, object_datatype FROM triples{whereClause}"

        use cmd = new SqliteCommand(sql, conn)
        for (name, value) in parameters do
            cmd.Parameters.AddWithValue(name, value) |> ignore

        use reader = cmd.ExecuteReader()
        let results = ResizeArray<Triple>()

        while reader.Read() do
            let subj = reader.GetString(0)
            let pred = reader.GetString(1)
            let obj = reader.GetString(2)
            let objType = reader.GetString(3)
            let objLang = if reader.IsDBNull(4) then None else Some (reader.GetString(4))
            let objDatatype = if reader.IsDBNull(5) then None else Some (reader.GetString(5))

            results.Add({
                Subject = deserializeTerm subj "iri" None None
                Predicate = FullIRI pred
                Object = deserializeTerm obj objType objLang objDatatype
            })

        results |> Seq.toList

    /// Get all triples for a subject (for graph exploration)
    let getSubjectTriples (conn: SqliteConnection) (subject: string) =
        queryTriples conn None (Some subject) None None

    /// Get all triples with predicate (for property queries)
    let getPredicateTriples (conn: SqliteConnection) (predicate: string) =
        queryTriples conn None None (Some predicate) None

    /// Get all triples pointing to object (backlinks)
    let getObjectTriples (conn: SqliteConnection) (obj: string) =
        queryTriples conn None None None (Some obj)

    /// Delete triples matching pattern
    let deleteTriples
        (conn: SqliteConnection)
        (graphUri: string option)
        (subject: string option)
        (predicate: string option)
        (obj: string option)
        : int =

        let mutable conditions = []
        let mutable parameters = []

        match graphUri with
        | Some g ->
            conditions <- "graph_uri = @graph" :: conditions
            parameters <- ("@graph", g :> obj) :: parameters
        | None -> ()

        match subject with
        | Some s ->
            conditions <- "subject = @subject" :: conditions
            parameters <- ("@subject", s :> obj) :: parameters
        | None -> ()

        match predicate with
        | Some p ->
            conditions <- "predicate = @predicate" :: conditions
            parameters <- ("@predicate", p :> obj) :: parameters
        | None -> ()

        match obj with
        | Some o ->
            conditions <- "object = @object" :: conditions
            parameters <- ("@object", o :> obj) :: parameters
        | None -> ()

        if conditions.IsEmpty then
            0  // Safety: don't delete all without explicit conditions
        else
            let whereClause = " WHERE " + String.Join(" AND ", conditions)
            let sql = $"DELETE FROM triples{whereClause}"

            use cmd = new SqliteCommand(sql, conn)
            for (name, value) in parameters do
                cmd.Parameters.AddWithValue(name, value) |> ignore

            cmd.ExecuteNonQuery()

    /// Get store statistics
    let getStats (conn: SqliteConnection) : TripleStoreStats =
        let countSql = "SELECT COUNT(*) FROM triples"
        let graphSql = "SELECT COUNT(DISTINCT graph_uri) FROM triples"
        let subjectSql = "SELECT COUNT(DISTINCT subject) FROM triples"
        let predSql = "SELECT COUNT(DISTINCT predicate) FROM triples"
        let objSql = "SELECT COUNT(DISTINCT object) FROM triples"

        let executeCount sql =
            use cmd = new SqliteCommand(sql, conn)
            cmd.ExecuteScalar() :?> int64

        {
            TotalTriples = executeCount countSql
            GraphCount = executeCount graphSql |> int
            SubjectCount = executeCount subjectSql
            PredicateCount = executeCount predSql
            ObjectCount = executeCount objSql
            DatabaseSizeBytes = 0L  // Would need file system access
            LastModified = DateTime.UtcNow
        }

    /// Link a Zettel to a triple
    let linkZettelToTriple (conn: SqliteConnection) (zettelId: Guid) (tripleId: int64) (linkType: string) =
        let sql = """
            INSERT OR IGNORE INTO zettel_triples (zettel_id, triple_id, link_type)
            VALUES (@zettelId, @tripleId, @linkType)
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@zettelId", zettelId.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@tripleId", tripleId) |> ignore
        cmd.Parameters.AddWithValue("@linkType", linkType) |> ignore
        cmd.ExecuteNonQuery()

    /// Get all triples linked to a Zettel
    let getZettelTriples (conn: SqliteConnection) (zettelId: Guid) =
        let sql = """
            SELECT t.subject, t.predicate, t.object, t.object_type, t.object_lang, t.object_datatype
            FROM triples t
            INNER JOIN zettel_triples zt ON t.id = zt.triple_id
            WHERE zt.zettel_id = @zettelId
        """
        use cmd = new SqliteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@zettelId", zettelId.ToString()) |> ignore

        use reader = cmd.ExecuteReader()
        let results = ResizeArray<Triple>()

        while reader.Read() do
            let subj = reader.GetString(0)
            let pred = reader.GetString(1)
            let obj = reader.GetString(2)
            let objType = reader.GetString(3)
            let objLang = if reader.IsDBNull(4) then None else Some (reader.GetString(4))
            let objDatatype = if reader.IsDBNull(5) then None else Some (reader.GetString(5))

            results.Add({
                Subject = deserializeTerm subj "iri" None None
                Predicate = FullIRI pred
                Object = deserializeTerm obj objType objLang objDatatype
            })

        results |> Seq.toList

    /// Convert RdfTerm to query string (None for Variables = wildcard)
    let private termToQueryString (term: RdfTerm) : string option =
        match term with
        | Variable _ -> None  // Wildcards match anything
        | IriTerm iri -> Some (IRI.expand iri)
        | BlankNode bn -> Some $"_:{bn}"
        | LiteralTerm lit -> Some lit.Value

    /// Query triples using a TriplePattern (Variables become wildcards)
    let queryByPattern
        (conn: SqliteConnection)
        (graphUri: string option)
        (pattern: TriplePattern)
        : Triple list =

        let subj = termToQueryString pattern.Subject
        let pred = termToQueryString pattern.Predicate
        let obj = termToQueryString pattern.Object

        queryTriples conn graphUri subj pred obj
