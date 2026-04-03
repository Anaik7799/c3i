module Cepaf.Knowledge.DuckDB

open System
open DuckDB.NET.Data
open Dapper
open Cepaf.Knowledge.Schema

type KnowledgeStore(connectionString: string) =
    
    let getConnection () = new DuckDBConnection(connectionString)

    member this.Initialize() =
        use conn = getConnection()
        conn.Open()
        
        // Schema Definition (v2.0 - Content Added)
        let sql = """
            CREATE TABLE IF NOT EXISTS holons (
                uuid UUID PRIMARY KEY,
                path VARCHAR,
                title VARCHAR,
                holon_level VARCHAR,
                entropy_score DOUBLE,
                last_verified TIMESTAMP,
                meta JSON,
                content_hash VARCHAR,
                content TEXT  -- Full markdown content
            );

            CREATE TABLE IF NOT EXISTS relations (
                source UUID,
                target UUID,
                type VARCHAR,
                weight DOUBLE,
                FOREIGN KEY(source) REFERENCES holons(uuid),
                FOREIGN KEY(target) REFERENCES holons(uuid)
            );
            
            CREATE TABLE IF NOT EXISTS vectors (
                uuid UUID,
                vector_id VARCHAR,
                model VARCHAR,
                embedding BLOB,
                FOREIGN KEY(uuid) REFERENCES holons(uuid)
            );
        """
        conn.Execute(sql) |> ignore

    member this.UpsertHolon(holon: Holon, path: string, contentHash: string) =
        use conn = getConnection()
        conn.Open()
        
        // Added content field to Upsert
        let sql = """
            INSERT INTO holons (uuid, path, title, holon_level, entropy_score, last_verified, content_hash, content)
            VALUES (@Uuid, @Path, @Title, @Level, @Entropy, @Verified, @Hash, @Content)
            ON CONFLICT (uuid) DO UPDATE SET
                path = excluded.path,
                title = excluded.title,
                holon_level = excluded.holon_level,
                entropy_score = excluded.entropy_score,
                last_verified = excluded.last_verified,
                content_hash = excluded.content_hash,
                content = excluded.content;
        """
        
        let param = {|
            Uuid = holon.Identity.Uuid
            Path = path
            Title = holon.Identity.Title
            Level = holon.FractalStruct.HolonLevel.ToString()
            Entropy = holon.Evolution.EntropyScore
            Verified = holon.Evolution.LastVerified
            Hash = contentHash
            Content = holon.Content
        |}
        
        conn.Execute(sql, param) |> ignore

    member this.GetEntropyReport(threshold: float) =
        use conn = getConnection()
        conn.Open()
        let sql = "SELECT * FROM holons WHERE entropy_score > @Threshold ORDER BY entropy_score DESC"
        conn.Query(sql, {| Threshold = threshold |})

    // Retrieve content for RAG
    member this.GetHolonContent(uuid: Guid) =
        use conn = getConnection()
        conn.Open()
        let sql = "SELECT content FROM holons WHERE uuid = @Uuid"
        conn.QueryFirstOrDefault<string>(sql, {| Uuid = uuid |})