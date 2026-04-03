namespace Cepaf.Kms

open System
open System.Data.SQLite
open System.Text.Json
open System.Text.Json.Serialization

module HolonRepository =

    let connectionString = "Data Source=data/kms/core.db;Version=3;"

    // Initialize the database schema (Idempotent)
    let init () =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        let schema = """
        CREATE TABLE IF NOT EXISTS holons (
            id TEXT PRIMARY KEY,
            fqun TEXT UNIQUE NOT NULL,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            parent_id TEXT,
            genome TEXT DEFAULT '{}',
            vital_signs TEXT DEFAULT '{}',
            membrane TEXT DEFAULT '{}',
            payload TEXT DEFAULT '{}',
            hlc_physical INTEGER NOT NULL,
            hlc_logical INTEGER NOT NULL,
            created_at TEXT,
            updated_at TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_holons_fqun ON holons(fqun);
        """
        use cmd = new SQLiteCommand(schema, conn)
        cmd.ExecuteNonQuery() |> ignore

    // Map SQLite DataReader to Domain Holon
    let private mapReader (reader: SQLiteDataReader) : Holon =
        let getJson (col: string) =
            try 
                let json = reader.[col].ToString()
                if String.IsNullOrWhiteSpace(json) then Map.empty 
                else JsonSerializer.Deserialize<Map<string, obj>>(json)
            with _ -> Map.empty

        let getVitalSigns (col: string) =
            try
                let json = reader.[col].ToString()
                if String.IsNullOrWhiteSpace(json) then { Health = 1.0; Stress = 0.0; Energy = 1.0 }
                else JsonSerializer.Deserialize<VitalSigns>(json)
            with _ -> { Health = 1.0; Stress = 0.0; Energy = 1.0 }

        {
            Id = reader.["id"].ToString()
            Fqun = reader.["fqun"].ToString()
            Type = HolonType.FromString(reader.["type"].ToString())
            Name = reader.["name"].ToString()
            ParentId = if reader.["parent_id"] = DBNull.Value then None else Some(reader.["parent_id"].ToString())
            Genome = getJson "genome"
            VitalSigns = getVitalSigns "vital_signs"
            Membrane = getJson "membrane"
            Payload = getJson "payload"
            HlcPhysical = int64 (reader.["hlc_physical"])
            HlcLogical = int64 (reader.["hlc_logical"])
            CreatedAt = DateTime.Parse(reader.["created_at"].ToString())
            UpdatedAt = DateTime.Parse(reader.["updated_at"].ToString())
        }

    // Get Holon by ID
    let getById (id: string) : Holon option =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        use cmd = new SQLiteCommand("SELECT * FROM holons WHERE id = @id", conn)
        cmd.Parameters.AddWithValue("@id", id) |> ignore
        
        use reader = cmd.ExecuteReader()
        if reader.Read() then Some(mapReader reader) else None

    // Get Holon by FQUN
    let getByFqun (fqun: string) : Holon option =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        use cmd = new SQLiteCommand("SELECT * FROM holons WHERE fqun = @fqun", conn)
        cmd.Parameters.AddWithValue("@fqun", fqun) |> ignore
        
        use reader = cmd.ExecuteReader()
        if reader.Read() then Some(mapReader reader) else None

    // Insert or Update Holon (Upsert)
    let upsert (holon: Holon) =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        
        let sql = """
        INSERT INTO holons (id, fqun, type, name, parent_id, genome, vital_signs, membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
        VALUES (@id, @fqun, @type, @name, @parent_id, @genome, @vital_signs, @membrane, @payload, @hlc_p, @hlc_l, @created, @updated)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            genome = excluded.genome,
            vital_signs = excluded.vital_signs,
            membrane = excluded.membrane,
            payload = excluded.payload,
            hlc_physical = excluded.hlc_physical,
            hlc_logical = excluded.hlc_logical,
            updated_at = excluded.updated_at
        """
        
        use cmd = new SQLiteCommand(sql, conn)
        cmd.Parameters.AddWithValue("@id", holon.Id) |> ignore
        cmd.Parameters.AddWithValue("@fqun", holon.Fqun) |> ignore
        cmd.Parameters.AddWithValue("@type", holon.Type.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@name", holon.Name) |> ignore
        cmd.Parameters.AddWithValue("@parent_id", match holon.ParentId with Some p -> box p | None -> DBNull.Value) |> ignore
        cmd.Parameters.AddWithValue("@genome", JsonSerializer.Serialize(holon.Genome)) |> ignore
        cmd.Parameters.AddWithValue("@vital_signs", JsonSerializer.Serialize(holon.VitalSigns)) |> ignore
        cmd.Parameters.AddWithValue("@membrane", JsonSerializer.Serialize(holon.Membrane)) |> ignore
        cmd.Parameters.AddWithValue("@payload", JsonSerializer.Serialize(holon.Payload)) |> ignore
        cmd.Parameters.AddWithValue("@hlc_p", holon.HlcPhysical) |> ignore
        cmd.Parameters.AddWithValue("@hlc_l", holon.HlcLogical) |> ignore
        cmd.Parameters.AddWithValue("@created", holon.CreatedAt.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("@updated", DateTime.UtcNow.ToString("o")) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore
