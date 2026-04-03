/// KMS Repository - SQLite data access for Zettels
///
/// STAMP Constraints:
/// - SC-KMS-001: Read-only access to holons.db
/// - SC-KMS-002: Cross-runtime (F#/Elixir) data access
/// - SC-HOLON-001: SQLite is authoritative holon state
module Cepaf.Smriti.Api.Data.KmsRepository

open System
open Microsoft.Data.Sqlite
open Dapper
open Cepaf.Smriti.Shared

/// Repository configuration
type KmsConfig = {
    SqlitePath: string
    ConnectionTimeout: int
}

/// Default configuration from environment
let defaultConfig () = {
    SqlitePath =
        Environment.GetEnvironmentVariable("SQLITE_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/holons.db"
    ConnectionTimeout = 30
}

/// Create SQLite connection
let private createConnection (config: KmsConfig) =
    let connStr = $"Data Source={config.SqlitePath};Mode=ReadOnly"
    new SqliteConnection(connStr)

// Database row types for Dapper mapping
[<CLIMutable>]
type DbZettel = {
    holon_uuid: string
    title: string
    content: string
    tags: string
    entropy: float
    level: string
    decay_rate: string
    inserted_at: string
    updated_at: string
    verified_at: string
    content_hash: string
    cluster: string
    backlink_count: int
}

[<CLIMutable>]
type DbLink = {
    source_id: string
    target_id: string
    link_type: string
    weight: float
    created_at: string
}

[<CLIMutable>]
type DbNode = {
    holon_uuid: string
    title: string
    entropy: float
    level: string
    cluster: string
    backlink_count: int
}

[<CLIMutable>]
type DbSearchResult = {
    holon_uuid: string
    title: string
    content: string
    tags: string
    entropy: float
    level: string
    decay_rate: string
    inserted_at: string
    updated_at: string
    verified_at: string
    content_hash: string
    cluster: string
    backlink_count: int
    score: float
    highlight: string
}

[<CLIMutable>]
type DbEntropyStats = {
    avg_entropy: float
    fresh_count: int
    aging_count: int
    rotting_count: int
}

[<CLIMutable>]
type DbCluster = {
    name: string
    zettel_count: int
    avg_entropy: float
    all_tags: string
}

/// Map database row to Zettel
let private mapToZettel (row: DbZettel) : Zettel =
    {
        Id = Guid.Parse(row.holon_uuid)
        Title = row.title
        Content = row.content
        Tags =
            if String.IsNullOrEmpty(row.tags) then []
            else row.tags.Split(',', StringSplitOptions.RemoveEmptyEntries) |> Array.toList
        Backlinks = []  // Loaded separately
        Entropy = row.entropy
        Level =
            match row.level with
            | "atomic" -> HolonLevel.Atomic
            | "molecular" -> HolonLevel.Molecular
            | "organism" -> HolonLevel.Organism
            | "ecosystem" -> HolonLevel.Ecosystem
            | _ -> HolonLevel.Atomic
        DecayRate =
            match row.decay_rate with
            | "fast" -> DecayRate.Fast
            | "medium" -> DecayRate.Medium
            | "slow" -> DecayRate.Slow
            | _ -> DecayRate.Medium
        CreatedAt = DateTime.Parse(row.inserted_at)
        ModifiedAt = DateTime.Parse(row.updated_at)
        VerifiedAt =
            if String.IsNullOrEmpty(row.verified_at) then None
            else Some(DateTime.Parse(row.verified_at))
        ContentHash = row.content_hash
    }

/// Map database row to ZettelLink
let private mapToLink (row: DbLink) : ZettelLink =
    {
        Source = Guid.Parse(row.source_id)
        Target = Guid.Parse(row.target_id)
        LinkType =
            match row.link_type with
            | "wiki" -> LinkType.WikiLink
            | "semantic" -> LinkType.SemanticSimilar
            | "code" -> LinkType.CodeReference
            | "backlink" -> LinkType.Backlink
            | _ -> LinkType.WikiLink
        Weight = row.weight
        CreatedAt = DateTime.Parse(row.created_at)
    }

/// Map database row to ZettelNode (for graph visualization)
let private mapToNode (row: DbNode) : ZettelNode =
    {
        Id = Guid.Parse(row.holon_uuid)
        Label = row.title
        Entropy = row.entropy
        Cluster =
            if String.IsNullOrEmpty(row.cluster) then None
            else Some(row.cluster)
        Level =
            match row.level with
            | "atomic" -> HolonLevel.Atomic
            | "molecular" -> HolonLevel.Molecular
            | "organism" -> HolonLevel.Organism
            | "ecosystem" -> HolonLevel.Ecosystem
            | _ -> HolonLevel.Atomic
        BacklinkCount = row.backlink_count
    }

/// Repository interface
type IKmsRepository =
    abstract GetZettel: Guid -> Async<Zettel option>
    abstract GetAllZettels: int * int -> Async<Zettel list * int>
    abstract GetBacklinks: Guid -> Async<Zettel list>
    abstract GetGraphData: unit -> Async<GraphData>
    abstract GetClusterGraph: string -> Async<GraphData>
    abstract FullTextSearch: string * int -> Async<SearchResult list>
    abstract GetEntropyMetrics: int -> Async<EntropyMetrics>
    abstract GetClusters: unit -> Async<ClusterInfo list>

/// SQLite-based repository implementation
type SqliteKmsRepository(config: KmsConfig) =

    interface IKmsRepository with

        /// Get a single Zettel by ID
        member _.GetZettel(id: Guid) = async {
            use conn = createConnection config
            conn.Open()

            let sql = """
                SELECT h.*,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                WHERE h.holon_uuid = @id
            """

            let! result = conn.QueryFirstOrDefaultAsync<DbZettel>(sql, {| id = id.ToString() |}) |> Async.AwaitTask

            match box result with
            | null -> return None
            | _ -> return Some(mapToZettel result)
        }

        /// Get paginated list of Zettels
        member _.GetAllZettels(page: int, pageSize: int) = async {
            use conn = createConnection config
            conn.Open()

            let offset = (page - 1) * pageSize

            let countSql = "SELECT COUNT(*) FROM holons"
            let! total = conn.ExecuteScalarAsync<int>(countSql) |> Async.AwaitTask

            let sql = """
                SELECT h.*,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                ORDER BY h.updated_at DESC
                LIMIT @limit OFFSET @offset
            """

            let! rows = conn.QueryAsync<DbZettel>(sql, {| limit = pageSize; offset = offset |}) |> Async.AwaitTask
            let zettels = rows |> Seq.map mapToZettel |> Seq.toList

            return (zettels, total)
        }

        /// Get all Zettels that link to the given Zettel
        member _.GetBacklinks(id: Guid) = async {
            use conn = createConnection config
            conn.Open()

            let sql = """
                SELECT h.*,
                       (SELECT COUNT(*) FROM holon_edges e2 WHERE e2.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                JOIN holon_edges e ON e.source_id = h.holon_uuid
                WHERE e.target_id = @id
            """

            let! rows = conn.QueryAsync<DbZettel>(sql, {| id = id.ToString() |}) |> Async.AwaitTask
            return rows |> Seq.map mapToZettel |> Seq.toList
        }

        /// Get full graph data for visualization
        member _.GetGraphData() = async {
            use conn = createConnection config
            conn.Open()

            let nodesSql = """
                SELECT h.holon_uuid, h.title, h.entropy, h.level, h.cluster,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
            """

            let edgesSql = """
                SELECT source_id, target_id, link_type, weight, created_at
                FROM holon_edges
            """

            let! nodeRows = conn.QueryAsync<DbNode>(nodesSql) |> Async.AwaitTask
            let! edgeRows = conn.QueryAsync<DbLink>(edgesSql) |> Async.AwaitTask

            return {
                Nodes = nodeRows |> Seq.map mapToNode |> Seq.toList
                Edges = edgeRows |> Seq.map mapToLink |> Seq.toList
                GeneratedAt = DateTime.UtcNow
            }
        }

        /// Get graph data for a specific cluster
        member _.GetClusterGraph(clusterName: string) = async {
            use conn = createConnection config
            conn.Open()

            let nodesSql = """
                SELECT h.holon_uuid, h.title, h.entropy, h.level, h.cluster,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                WHERE h.cluster = @cluster
            """

            let! nodeRows = conn.QueryAsync<DbNode>(nodesSql, {| cluster = clusterName |}) |> Async.AwaitTask
            let nodeIds = nodeRows |> Seq.map (fun r -> r.holon_uuid) |> Seq.toArray

            let edgesSql = """
                SELECT source_id, target_id, link_type, weight, created_at
                FROM holon_edges
                WHERE source_id IN @ids OR target_id IN @ids
            """

            let! edgeRows = conn.QueryAsync<DbLink>(edgesSql, {| ids = nodeIds |}) |> Async.AwaitTask

            return {
                Nodes = nodeRows |> Seq.map mapToNode |> Seq.toList
                Edges = edgeRows |> Seq.map mapToLink |> Seq.toList
                GeneratedAt = DateTime.UtcNow
            }
        }

        /// Full-text search using FTS5
        member _.FullTextSearch(query: string, limit: int) = async {
            use conn = createConnection config
            conn.Open()

            let sql = """
                SELECT h.*, bm25(holons_fts) as score,
                       snippet(holons_fts, -1, '<mark>', '</mark>', '...', 64) as highlight,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                JOIN holons_fts fts ON fts.rowid = h.rowid
                WHERE holons_fts MATCH @query
                ORDER BY bm25(holons_fts)
                LIMIT @limit
            """

            let! rows = conn.QueryAsync<DbSearchResult>(sql, {| query = query; limit = limit |}) |> Async.AwaitTask

            return rows |> Seq.map (fun row ->
                let zettel: Zettel = {
                    Id = Guid.Parse(row.holon_uuid)
                    Title = row.title
                    Content = row.content
                    Tags =
                        if String.IsNullOrEmpty(row.tags) then []
                        else row.tags.Split(',', StringSplitOptions.RemoveEmptyEntries) |> Array.toList
                    Backlinks = []
                    Entropy = row.entropy
                    Level =
                        match row.level with
                        | "atomic" -> HolonLevel.Atomic
                        | "molecular" -> HolonLevel.Molecular
                        | "organism" -> HolonLevel.Organism
                        | "ecosystem" -> HolonLevel.Ecosystem
                        | _ -> HolonLevel.Atomic
                    DecayRate =
                        match row.decay_rate with
                        | "fast" -> DecayRate.Fast
                        | "medium" -> DecayRate.Medium
                        | "slow" -> DecayRate.Slow
                        | _ -> DecayRate.Medium
                    CreatedAt = DateTime.Parse(row.inserted_at)
                    ModifiedAt = DateTime.Parse(row.updated_at)
                    VerifiedAt =
                        if String.IsNullOrEmpty(row.verified_at) then None
                        else Some(DateTime.Parse(row.verified_at))
                    ContentHash = row.content_hash
                }
                {
                    Zettel = zettel
                    Score = abs(row.score)
                    Highlights = [row.highlight]
                    MatchType = SearchMatchType.FullText
                }
            ) |> Seq.toList
        }

        /// Get entropy metrics for dashboard
        member _.GetEntropyMetrics(topN: int) = async {
            use conn = createConnection config
            conn.Open()

            let statsSql = """
                SELECT
                    AVG(entropy) as avg_entropy,
                    SUM(CASE WHEN entropy < 0.3 THEN 1 ELSE 0 END) as fresh_count,
                    SUM(CASE WHEN entropy >= 0.3 AND entropy < 0.6 THEN 1 ELSE 0 END) as aging_count,
                    SUM(CASE WHEN entropy >= 0.6 THEN 1 ELSE 0 END) as rotting_count
                FROM holons
            """

            let topSql = """
                SELECT h.holon_uuid, h.title, h.entropy, h.level, h.cluster,
                       (SELECT COUNT(*) FROM holon_edges e WHERE e.target_id = h.holon_uuid) as backlink_count
                FROM holons h
                ORDER BY h.entropy DESC
                LIMIT @limit
            """

            let! stats = conn.QueryFirstAsync<DbEntropyStats>(statsSql) |> Async.AwaitTask
            let! topRows = conn.QueryAsync<DbNode>(topSql, {| limit = topN |}) |> Async.AwaitTask

            return {
                AverageEntropy = stats.avg_entropy
                FreshCount = stats.fresh_count
                AgingCount = stats.aging_count
                RottingCount = stats.rotting_count
                TopRotting = topRows |> Seq.map mapToNode |> Seq.toList
                GeneratedAt = DateTime.UtcNow
            }
        }

        /// Get all cluster info
        member _.GetClusters() = async {
            use conn = createConnection config
            conn.Open()

            let sql = """
                SELECT
                    cluster as name,
                    COUNT(*) as zettel_count,
                    AVG(entropy) as avg_entropy,
                    GROUP_CONCAT(DISTINCT tags) as all_tags
                FROM holons
                WHERE cluster IS NOT NULL
                GROUP BY cluster
                ORDER BY zettel_count DESC
            """

            let! rows = conn.QueryAsync<DbCluster>(sql) |> Async.AwaitTask

            return rows |> Seq.map (fun row ->
                {
                    Name = row.name
                    ZettelCount = row.zettel_count
                    AverageEntropy = row.avg_entropy
                    TopTags =
                        if String.IsNullOrEmpty(row.all_tags) then []
                        else
                            row.all_tags.Split(',', StringSplitOptions.RemoveEmptyEntries)
                            |> Array.distinct
                            |> Array.truncate 5
                            |> Array.toList
                }
            ) |> Seq.toList
        }

/// Create repository with default config
let create () = SqliteKmsRepository(defaultConfig()) :> IKmsRepository
