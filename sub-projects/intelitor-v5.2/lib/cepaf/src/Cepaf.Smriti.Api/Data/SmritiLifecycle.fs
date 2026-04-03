/// SMRITI Lifecycle Manager - Full Zettel CRUD & Lifecycle Operations
///
/// STAMP Constraints:
/// - SC-HOLON-001: SQLite is authoritative holon state
/// - SC-HOLON-019: Evolution history is append-only
/// - SC-REG-001: All state changes via append-only register
module Cepaf.Smriti.Api.Data.SmritiLifecycle

open System
open System.Security.Cryptography
open System.Text
open Microsoft.Data.Sqlite
open Dapper
open Cepaf.Smriti.Shared

/// SMRITI configuration
type SmritiConfig = {
    SqlitePath: string
    EnableAudit: bool
    EnableFTS: bool
}

/// Holon update request
type UpdateRequest = {
    Title: string option
    Content: string option
    Tags: string list option
    Level: HolonLevel option
    DecayRate: DecayRate option
    Cluster: string option
}

/// Link creation request
type LinkRequest = {
    SourceId: Guid
    TargetId: Guid
    LinkType: LinkType
    Weight: float option
}

/// Operation result
type SmritiResult<'T> =
    | Ok of 'T
    | NotFound of string
    | Conflict of string
    | Error of string

// Database types
[<CLIMutable>]
type DbHolon = {
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
type DbClusterStat = {
    cluster: string
    count: int
    avg_entropy: float
}

/// Default configuration
let defaultConfig () : SmritiConfig =
    let path =
        Environment.GetEnvironmentVariable("SMRITI_DB_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/smriti.db"
    { SqlitePath = path; EnableAudit = true; EnableFTS = true }

/// Create connection
let private createConnection (config: SmritiConfig) =
    let connStr = sprintf "Data Source=%s;Mode=ReadWrite" config.SqlitePath
    new SqliteConnection(connStr)

/// Level to string
let private levelToString (level: HolonLevel) : string =
    match level with
    | HolonLevel.Atomic -> "atomic"
    | HolonLevel.Molecular -> "molecular"
    | HolonLevel.Organism -> "organism"
    | HolonLevel.Ecosystem -> "ecosystem"
    | _ -> "atomic"

/// String to level
let private stringToLevel (s: string) : HolonLevel =
    match s with
    | "molecular" -> HolonLevel.Molecular
    | "organism" -> HolonLevel.Organism
    | "ecosystem" -> HolonLevel.Ecosystem
    | _ -> HolonLevel.Atomic

/// Decay rate to string
let private decayToString (decay: DecayRate) : string =
    match decay with
    | DecayRate.Slow -> "slow"
    | DecayRate.Medium -> "medium"
    | DecayRate.Fast -> "fast"
    | _ -> "medium"

/// String to decay rate
let private stringToDecay (s: string) : DecayRate =
    match s with
    | "slow" -> DecayRate.Slow
    | "fast" -> DecayRate.Fast
    | _ -> DecayRate.Medium

/// Compute hash
let private computeHash (content: string) : string =
    use sha256 = SHA256.Create()
    let bytes = Encoding.UTF8.GetBytes(content)
    let hashBytes = sha256.ComputeHash(bytes)
    BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant()

/// Map DB row to Zettel
let private mapToZettel (row: DbHolon) : Zettel =
    let tags =
        if String.IsNullOrEmpty row.tags then []
        else row.tags.Split(',') |> Array.map (fun s -> s.Trim()) |> Array.toList
    let verifiedAt =
        if String.IsNullOrEmpty row.verified_at then None
        else Some (DateTime.Parse(row.verified_at))
    { Id = Guid.Parse(row.holon_uuid)
      Title = row.title
      Content = row.content
      Tags = tags
      Backlinks = []
      Entropy = row.entropy
      Level = stringToLevel row.level
      DecayRate = stringToDecay row.decay_rate
      CreatedAt = DateTime.Parse(row.inserted_at)
      ModifiedAt = DateTime.Parse(row.updated_at)
      VerifiedAt = verifiedAt
      ContentHash = row.content_hash }

/// Create a new zettel
let create (config: SmritiConfig) (title: string) (content: string) (tags: string list) (level: HolonLevel) (cluster: string option) : SmritiResult<Guid> =
    try
        use conn = createConnection config
        conn.Open()

        let id = Guid.NewGuid()
        let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
        let hash = computeHash content
        let clusterVal = cluster |> Option.defaultValue "default"

        let sql = "INSERT INTO holons (holon_uuid, title, content, tags, entropy, level, decay_rate, inserted_at, updated_at, content_hash, cluster) VALUES (@uuid, @title, @content, @tags, @entropy, @level, @decay_rate, @inserted_at, @updated_at, @hash, @cluster)"

        conn.Execute(sql, {|
            uuid = id.ToString()
            title = title
            content = content
            tags = String.Join(",", tags)
            entropy = 0.0
            level = levelToString level
            decay_rate = "medium"
            inserted_at = now
            updated_at = now
            hash = hash
            cluster = clusterVal
        |}) |> ignore

        Ok id
    with ex ->
        Error (sprintf "Create failed: %s" ex.Message)

/// Get a zettel by ID
let get (config: SmritiConfig) (id: Guid) : SmritiResult<Zettel> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT * FROM holons WHERE holon_uuid = @id"
        let result = conn.QueryFirstOrDefault<DbHolon>(sql, {| id = id.ToString() |})

        match box result with
        | null -> NotFound (sprintf "Holon %O not found" id)
        | _ -> Ok (mapToZettel result)
    with ex ->
        Error (sprintf "Get failed: %s" ex.Message)

/// List holons with pagination
let list (config: SmritiConfig) (page: int) (pageSize: int) (cluster: string option) (level: HolonLevel option) : SmritiResult<Zettel list * int> =
    try
        use conn = createConnection config
        conn.Open()

        let offset = (page - 1) * pageSize
        let whereClause =
            match cluster, level with
            | Some c, Some l -> sprintf "WHERE cluster = '%s' AND level = '%s'" c (levelToString l)
            | Some c, None -> sprintf "WHERE cluster = '%s'" c
            | None, Some l -> sprintf "WHERE level = '%s'" (levelToString l)
            | None, None -> ""

        let countSql = "SELECT COUNT(*) FROM holons " + whereClause
        let total = conn.ExecuteScalar<int>(countSql)

        let sql = "SELECT * FROM holons " + whereClause + " ORDER BY updated_at DESC LIMIT @limit OFFSET @offset"
        let rows = conn.Query<DbHolon>(sql, {| limit = pageSize; offset = offset |})
        let zettels = rows |> Seq.map mapToZettel |> Seq.toList

        Ok (zettels, total)
    with ex ->
        Error (sprintf "List failed: %s" ex.Message)

/// Search holons using FTS5
let search (config: SmritiConfig) (query: string) (limit: int) : SmritiResult<Zettel list> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT h.* FROM holons h JOIN holons_fts fts ON fts.rowid = h.rowid WHERE holons_fts MATCH @query ORDER BY bm25(holons_fts) LIMIT @limit"
        let rows = conn.Query<DbHolon>(sql, {| query = query; limit = limit |})
        Ok (rows |> Seq.map mapToZettel |> Seq.toList)
    with ex ->
        Error (sprintf "Search failed: %s" ex.Message)

/// Update a zettel
let update (config: SmritiConfig) (id: Guid) (req: UpdateRequest) : SmritiResult<unit> =
    try
        use conn = createConnection config
        conn.Open()

        let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
        let mutable updated = false

        if req.Title.IsSome then
            conn.Execute("UPDATE holons SET title = @val, updated_at = @now WHERE holon_uuid = @id", {| val' = req.Title.Value; now = now; id = id.ToString() |}) |> ignore
            updated <- true

        if req.Content.IsSome then
            let hash = computeHash req.Content.Value
            conn.Execute("UPDATE holons SET content = @val, content_hash = @hash, updated_at = @now WHERE holon_uuid = @id", {| val' = req.Content.Value; hash = hash; now = now; id = id.ToString() |}) |> ignore
            updated <- true

        if req.Tags.IsSome then
            let tags = String.Join(",", req.Tags.Value)
            conn.Execute("UPDATE holons SET tags = @val, updated_at = @now WHERE holon_uuid = @id", {| val' = tags; now = now; id = id.ToString() |}) |> ignore
            updated <- true

        if req.Level.IsSome then
            conn.Execute("UPDATE holons SET level = @val, updated_at = @now WHERE holon_uuid = @id", {| val' = levelToString req.Level.Value; now = now; id = id.ToString() |}) |> ignore
            updated <- true

        if req.Cluster.IsSome then
            conn.Execute("UPDATE holons SET cluster = @val, updated_at = @now WHERE holon_uuid = @id", {| val' = req.Cluster.Value; now = now; id = id.ToString() |}) |> ignore
            updated <- true

        if updated then Ok () else NotFound "No fields to update"
    with ex ->
        Error (sprintf "Update failed: %s" ex.Message)

/// Delete a zettel
let delete (config: SmritiConfig) (id: Guid) (cascade: bool) : SmritiResult<unit> =
    try
        use conn = createConnection config
        conn.Open()

        if cascade then
            conn.Execute("DELETE FROM holon_edges WHERE source_id = @id OR target_id = @id", {| id = id.ToString() |}) |> ignore

        let affected = conn.Execute("DELETE FROM holons WHERE holon_uuid = @id", {| id = id.ToString() |})
        if affected = 0 then NotFound "Holon not found"
        else Ok ()
    with ex ->
        Error (sprintf "Delete failed: %s" ex.Message)

/// Create a link
let createLink (config: SmritiConfig) (req: LinkRequest) : SmritiResult<unit> =
    try
        use conn = createConnection config
        conn.Open()

        let now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
        let linkType =
            match req.LinkType with
            | LinkType.WikiLink -> "wiki"
            | LinkType.SemanticSimilar -> "semantic"
            | LinkType.CodeReference -> "code"
            | LinkType.Backlink -> "backlink"
            | _ -> "wiki"
        let weight = req.Weight |> Option.defaultValue 1.0

        let sql = "INSERT INTO holon_edges (source_id, target_id, link_type, weight, created_at) VALUES (@src, @tgt, @lt, @w, @now)"
        conn.Execute(sql, {| src = req.SourceId.ToString(); tgt = req.TargetId.ToString(); lt = linkType; w = weight; now = now |}) |> ignore
        Ok ()
    with ex ->
        Error (sprintf "CreateLink failed: %s" ex.Message)

/// Get links for a holon
let getLinks (config: SmritiConfig) (id: Guid) : SmritiResult<ZettelLink list> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT source_id, target_id, link_type, weight, created_at FROM holon_edges WHERE source_id = @id OR target_id = @id"
        let rows = conn.Query<DbLink>(sql, {| id = id.ToString() |})

        let links =
            rows
            |> Seq.map (fun row ->
                let lt =
                    match row.link_type with
                    | "wiki" -> LinkType.WikiLink
                    | "semantic" -> LinkType.SemanticSimilar
                    | "code" -> LinkType.CodeReference
                    | "backlink" -> LinkType.Backlink
                    | _ -> LinkType.WikiLink
                { Source = Guid.Parse(row.source_id)
                  Target = Guid.Parse(row.target_id)
                  LinkType = lt
                  Weight = row.weight
                  CreatedAt = DateTime.Parse(row.created_at) })
            |> Seq.toList

        Ok links
    with ex ->
        Error (sprintf "GetLinks failed: %s" ex.Message)

/// Delete a link
let deleteLink (config: SmritiConfig) (sourceId: Guid) (targetId: Guid) : SmritiResult<unit> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "DELETE FROM holon_edges WHERE source_id = @src AND target_id = @tgt"
        let affected = conn.Execute(sql, {| src = sourceId.ToString(); tgt = targetId.ToString() |})
        if affected = 0 then NotFound "Link not found"
        else Ok ()
    with ex ->
        Error (sprintf "DeleteLink failed: %s" ex.Message)

/// Find orphan holons (no links)
let findOrphans (config: SmritiConfig) : SmritiResult<Zettel list> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT h.* FROM holons h WHERE NOT EXISTS (SELECT 1 FROM holon_edges e WHERE e.source_id = h.holon_uuid OR e.target_id = h.holon_uuid)"
        let rows = conn.Query<DbHolon>(sql)
        Ok (rows |> Seq.map mapToZettel |> Seq.toList)
    with ex ->
        Error (sprintf "FindOrphans failed: %s" ex.Message)

/// Find stale holons
let findStale (config: SmritiConfig) (threshold: float) : SmritiResult<Zettel list> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT * FROM holons WHERE entropy >= @threshold ORDER BY entropy DESC"
        let rows = conn.Query<DbHolon>(sql, {| threshold = threshold |})
        Ok (rows |> Seq.map mapToZettel |> Seq.toList)
    with ex ->
        Error (sprintf "FindStale failed: %s" ex.Message)

/// Get cluster statistics
let getClusterStats (config: SmritiConfig) : SmritiResult<Map<string, int * float>> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "SELECT cluster, COUNT(*) as count, AVG(entropy) as avg_entropy FROM holons WHERE cluster IS NOT NULL AND cluster != '' GROUP BY cluster"
        let rows = conn.Query<DbClusterStat>(sql)
        let stats = rows |> Seq.map (fun r -> (r.cluster, (r.count, r.avg_entropy))) |> Map.ofSeq
        Ok stats
    with ex ->
        Error (sprintf "GetClusterStats failed: %s" ex.Message)

/// Recalculate entropy for all holons
let recalculateEntropy (config: SmritiConfig) : SmritiResult<int> =
    try
        use conn = createConnection config
        conn.Open()

        let sql = "UPDATE holons SET entropy = MIN(1.0, CAST((julianday('now') - julianday(updated_at)) AS REAL) / 180.0)"
        let affected = conn.Execute(sql)
        Ok affected
    with ex ->
        Error (sprintf "RecalculateEntropy failed: %s" ex.Message)
