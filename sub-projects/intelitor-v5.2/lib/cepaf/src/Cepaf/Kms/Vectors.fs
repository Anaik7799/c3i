namespace Cepaf.Kms

open System
open System.Text.Json
open System.Text.Json.Serialization
open System.Data.SQLite

// --- VECTOR DOMAIN MODEL ---

type Vector = {
    Id: string // Reference to Holon ID
    Dimensions: int
    Embedding: float[]
    Model: string
    CreatedAt: DateTime
}

// --- VECTOR REPOSITORY ---

module VectorRepository =
    
    // Vectors are stored in a separate DB for performance/partitioning if needed,
    // but for now we co-locate in core.db or use a specialized one.
    // Given the previous Elixir code used 'vectors.ex', let's stick to 'core.db' for simplicity or 'vectors.db'
    // Elixir code had `data/kms/holons.db` for everything.
    // Let's use `vectors.db` to keep it clean and allow for future extension (e.g. specialized vector DB).
    
    let connectionString = "Data Source=data/kms/vectors.db;Version=3;"

    let init () =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        // SQLite doesn't have native vector types, we store as BLOB or JSON
        // Using JSON for interoperability, BLOB for speed. Let's use JSON for now.
        let schema = """
        CREATE TABLE IF NOT EXISTS vectors (
            holon_id TEXT PRIMARY KEY,
            dimensions INTEGER NOT NULL,
            embedding TEXT NOT NULL, -- JSON array of floats
            model TEXT NOT NULL,
            created_at TEXT
        );
        """
        use cmd = new SQLiteCommand(schema, conn)
        cmd.ExecuteNonQuery() |> ignore

    let upsert (vector: Vector) =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        let sql = """
        INSERT INTO vectors (holon_id, dimensions, embedding, model, created_at)
        VALUES (@id, @dim, @emb, @model, @created)
        ON CONFLICT(holon_id) DO UPDATE SET
            embedding = excluded.embedding,
            model = excluded.model,
            created_at = excluded.created_at
        """
        
        use cmd = new SQLiteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@id", vector.Id) |> ignore
        cmd.Parameters.AddWithValue("@dim", vector.Dimensions) |> ignore
        cmd.Parameters.AddWithValue("@emb", JsonSerializer.Serialize(vector.Embedding)) |> ignore
        cmd.Parameters.AddWithValue("@model", vector.Model) |> ignore
        cmd.Parameters.AddWithValue("@created", vector.CreatedAt.ToString("o")) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore

    let get (holonId: string) : Vector option =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        use cmd = new SQLiteCommand("SELECT * FROM vectors WHERE holon_id = @id", conn)
        cmd.Parameters.AddWithValue("@id", holonId) |> ignore
        
        use reader = cmd.ExecuteReader()
        if reader.Read() then
            Some {
                Id = reader.["holon_id"].ToString()
                Dimensions = int (reader.["dimensions"])
                Embedding = JsonSerializer.Deserialize<float[]>(reader.["embedding"].ToString())
                Model = reader.["model"].ToString()
                CreatedAt = DateTime.Parse(reader.["created_at"].ToString())
            }
        else None

    // Naive Cosine Similarity (In-Memory)
    // For large scale, we'd need a real Vector DB or an extension (sqlite-vec)
    // But this matches the current Elixir 'vectors.ex' likely capability without NIFs.
    let cosineSimilarity (v1: float[]) (v2: float[]) =
        let dot = Array.map2 (*) v1 v2 |> Array.sum
        let mag1 = Math.Sqrt(v1 |> Array.map (fun x -> x * x) |> Array.sum)
        let mag2 = Math.Sqrt(v2 |> Array.map (fun x -> x * x) |> Array.sum)
        if mag1 = 0.0 || mag2 = 0.0 then 0.0 else dot / (mag1 * mag2)

    let search (queryVec: float[]) (limit: int) =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        use cmd = new SQLiteCommand("SELECT * FROM vectors", conn)
        use reader = cmd.ExecuteReader()
        
        let candidates = 
            [ while reader.Read() do
                let vec = JsonSerializer.Deserialize<float[]>(reader.["embedding"].ToString())
                let id = reader.["holon_id"].ToString()
                yield (id, vec) ]
        
        candidates
        |> List.map (fun (id, vec) -> (id, cosineSimilarity queryVec vec))
        |> List.sortByDescending snd
        |> List.take (min limit (List.length candidates))
