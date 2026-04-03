/// Analytics Queries - DuckDB OLAP for feature evolution and metrics
///
/// STAMP Constraints:
/// - SC-KMS-003: Entropy calculation matches Gardener.fs
/// - SC-HOLON-003: Holon evolution history in DuckDB
module Cepaf.Smriti.Api.Data.AnalyticsQuery

open System
open DuckDB.NET.Data
open Cepaf.Smriti.Shared

/// DuckDB configuration
type AnalyticsConfig = {
    DuckDbPath: string
}

/// Default configuration from environment
let defaultConfig () = {
    DuckDbPath =
        Environment.GetEnvironmentVariable("DUCKDB_PATH")
        |> Option.ofObj
        |> Option.defaultValue "data/kms/analytics.duckdb"
}

/// Feature evolution event
type EvolutionEvent = {
    HolonId: Guid
    Title: string
    EventType: string        // created, modified, verified, linked
    Timestamp: DateTime
    OldEntropy: float option
    NewEntropy: float option
    Details: string
}

/// Source code info for rendering
type SourceCodeInfo = {
    HolonId: Guid
    FilePath: string
    Language: string         // elixir, fsharp, markdown
    StartLine: int option
    EndLine: int option
    Content: string
    Functions: string list   // Extracted function names
}

/// Mental model connection
type MentalModelNode = {
    Id: Guid
    Label: string
    NodeType: string         // concept, code, doc, test
    X: float                 // Layout position
    Y: float
    Size: float              // Based on importance/connections
    Color: string            // Based on entropy
}

/// Mental model edge with semantic type
type MentalModelEdge = {
    Source: Guid
    Target: Guid
    EdgeType: string         // depends_on, implements, tests, documents
    Strength: float
    Label: string option
}

/// Mind map data structure
type MindMapData = {
    CentralConcept: string
    Nodes: MentalModelNode list
    Edges: MentalModelEdge list
    Clusters: ClusterInfo list
    GeneratedAt: DateTime
}

/// Analytics repository interface
type IAnalyticsRepository =
    abstract GetFeatureEvolution: Guid * int -> Async<EvolutionEvent list>
    abstract GetRecentEvolution: int -> Async<EvolutionEvent list>
    abstract GetSourceCodeInfo: Guid -> Async<SourceCodeInfo option>
    abstract GetMindMap: string option -> Async<MindMapData>
    abstract GetEntropyTimeline: Guid * int -> Async<(DateTime * float) list>
    abstract GetClusterEvolution: string * int -> Async<(DateTime * int * float) list>

/// DuckDB-based analytics implementation
type DuckDbAnalytics(config: AnalyticsConfig) =

    let createConnection () =
        new DuckDBConnection($"Data Source={config.DuckDbPath}")

    interface IAnalyticsRepository with

        /// Get evolution history for a specific holon
        member _.GetFeatureEvolution(holonId: Guid, limit: int) = async {
            use conn = createConnection ()
            conn.Open()

            use cmd = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT holon_id, title, event_type, timestamp,
                       old_entropy, new_entropy, details
                FROM holon_events
                WHERE holon_id = $1
                ORDER BY timestamp DESC
                LIMIT $2
            """
            cmd.Parameters.Add(new DuckDBParameter("$1", holonId.ToString())) |> ignore
            cmd.Parameters.Add(new DuckDBParameter("$2", limit)) |> ignore

            use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask
            let events = ResizeArray<EvolutionEvent>()

            while reader.Read() do
                events.Add({
                    HolonId = Guid.Parse(reader.GetString(0))
                    Title = reader.GetString(1)
                    EventType = reader.GetString(2)
                    Timestamp = reader.GetDateTime(3)
                    OldEntropy = if reader.IsDBNull(4) then None else Some(reader.GetDouble(4))
                    NewEntropy = if reader.IsDBNull(5) then None else Some(reader.GetDouble(5))
                    Details = reader.GetString(6)
                })

            return events |> Seq.toList
        }

        /// Get most recent evolution events across all holons
        member _.GetRecentEvolution(limit: int) = async {
            use conn = createConnection ()
            conn.Open()

            use cmd = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT holon_id, title, event_type, timestamp,
                       old_entropy, new_entropy, details
                FROM holon_events
                ORDER BY timestamp DESC
                LIMIT $1
            """
            cmd.Parameters.Add(new DuckDBParameter("$1", limit)) |> ignore

            use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask
            let events = ResizeArray<EvolutionEvent>()

            while reader.Read() do
                events.Add({
                    HolonId = Guid.Parse(reader.GetString(0))
                    Title = reader.GetString(1)
                    EventType = reader.GetString(2)
                    Timestamp = reader.GetDateTime(3)
                    OldEntropy = if reader.IsDBNull(4) then None else Some(reader.GetDouble(4))
                    NewEntropy = if reader.IsDBNull(5) then None else Some(reader.GetDouble(5))
                    Details = reader.GetString(6)
                })

            return events |> Seq.toList
        }

        /// Get source code info for a holon
        member _.GetSourceCodeInfo(holonId: Guid) = async {
            use conn = createConnection ()
            conn.Open()

            use cmd = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT holon_id, file_path, language, start_line, end_line,
                       content, functions
                FROM source_code
                WHERE holon_id = $1
            """
            cmd.Parameters.Add(new DuckDBParameter("$1", holonId.ToString())) |> ignore

            use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask

            if reader.Read() then
                return Some {
                    HolonId = Guid.Parse(reader.GetString(0))
                    FilePath = reader.GetString(1)
                    Language = reader.GetString(2)
                    StartLine = if reader.IsDBNull(3) then None else Some(reader.GetInt32(3))
                    EndLine = if reader.IsDBNull(4) then None else Some(reader.GetInt32(4))
                    Content = reader.GetString(5)
                    Functions =
                        if reader.IsDBNull(6) then []
                        else reader.GetString(6).Split(',', StringSplitOptions.RemoveEmptyEntries) |> Array.toList
                }
            else
                return None
        }

        /// Generate mind map data for visualization
        member _.GetMindMap(centralConcept: string option) = async {
            use conn = createConnection ()
            conn.Open()

            // Get nodes with layout positions (computed by force-directed layout)
            use nodesCmd = conn.CreateCommand()
            nodesCmd.CommandText <- """
                SELECT holon_id, title, node_type, x_pos, y_pos,
                       importance * 10 as size, entropy
                FROM holon_layout
                ORDER BY importance DESC
                LIMIT 100
            """

            use! nodesReader = nodesCmd.ExecuteReaderAsync() |> Async.AwaitTask
            let nodes = ResizeArray<MentalModelNode>()

            while nodesReader.Read() do
                let entropy = nodesReader.GetDouble(6)
                nodes.Add({
                    Id = Guid.Parse(nodesReader.GetString(0))
                    Label = nodesReader.GetString(1)
                    NodeType = nodesReader.GetString(2)
                    X = nodesReader.GetDouble(3)
                    Y = nodesReader.GetDouble(4)
                    Size = nodesReader.GetDouble(5)
                    Color = Entropy.toColor entropy
                })

            // Get semantic edges
            use edgesCmd = conn.CreateCommand()
            edgesCmd.CommandText <- """
                SELECT source_id, target_id, edge_type, strength, label
                FROM semantic_edges
            """

            use! edgesReader = edgesCmd.ExecuteReaderAsync() |> Async.AwaitTask
            let edges = ResizeArray<MentalModelEdge>()

            while edgesReader.Read() do
                edges.Add({
                    Source = Guid.Parse(edgesReader.GetString(0))
                    Target = Guid.Parse(edgesReader.GetString(1))
                    EdgeType = edgesReader.GetString(2)
                    Strength = edgesReader.GetDouble(3)
                    Label = if edgesReader.IsDBNull(4) then None else Some(edgesReader.GetString(4))
                })

            // Get cluster info
            use clustersCmd = conn.CreateCommand()
            clustersCmd.CommandText <- """
                SELECT name, zettel_count, avg_entropy
                FROM clusters
                ORDER BY zettel_count DESC
            """

            use! clustersReader = clustersCmd.ExecuteReaderAsync() |> Async.AwaitTask
            let clusters = ResizeArray<ClusterInfo>()

            while clustersReader.Read() do
                clusters.Add({
                    Name = clustersReader.GetString(0)
                    ZettelCount = clustersReader.GetInt32(1)
                    AverageEntropy = clustersReader.GetDouble(2)
                    TopTags = []
                })

            return {
                CentralConcept = centralConcept |> Option.defaultValue "Knowledge Graph"
                Nodes = nodes |> Seq.toList
                Edges = edges |> Seq.toList
                Clusters = clusters |> Seq.toList
                GeneratedAt = DateTime.UtcNow
            }
        }

        /// Get entropy timeline for a holon
        member _.GetEntropyTimeline(holonId: Guid, days: int) = async {
            use conn = createConnection ()
            conn.Open()

            use cmd = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT date_trunc('day', timestamp) as day, AVG(new_entropy) as entropy
                FROM holon_events
                WHERE holon_id = $1
                  AND timestamp >= current_date - interval '$2 days'
                  AND new_entropy IS NOT NULL
                GROUP BY date_trunc('day', timestamp)
                ORDER BY day
            """
            cmd.Parameters.Add(new DuckDBParameter("$1", holonId.ToString())) |> ignore
            cmd.Parameters.Add(new DuckDBParameter("$2", days)) |> ignore

            use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask
            let timeline = ResizeArray<DateTime * float>()

            while reader.Read() do
                timeline.Add((reader.GetDateTime(0), reader.GetDouble(1)))

            return timeline |> Seq.toList
        }

        /// Get cluster growth over time
        member _.GetClusterEvolution(clusterName: string, days: int) = async {
            use conn = createConnection ()
            conn.Open()

            use cmd = conn.CreateCommand()
            cmd.CommandText <- """
                SELECT date_trunc('day', e.timestamp) as day,
                       COUNT(DISTINCT e.holon_id) as count,
                       AVG(e.new_entropy) as entropy
                FROM holon_events e
                JOIN holons h ON h.holon_uuid = e.holon_id
                WHERE h.cluster = $1
                  AND e.timestamp >= current_date - interval '$2 days'
                GROUP BY date_trunc('day', e.timestamp)
                ORDER BY day
            """
            cmd.Parameters.Add(new DuckDBParameter("$1", clusterName)) |> ignore
            cmd.Parameters.Add(new DuckDBParameter("$2", days)) |> ignore

            use! reader = cmd.ExecuteReaderAsync() |> Async.AwaitTask
            let evolution = ResizeArray<DateTime * int * float>()

            while reader.Read() do
                evolution.Add((
                    reader.GetDateTime(0),
                    reader.GetInt32(1),
                    reader.GetDouble(2)
                ))

            return evolution |> Seq.toList
        }

/// Create analytics repository with default config
let create () = DuckDbAnalytics(defaultConfig()) :> IAnalyticsRepository
