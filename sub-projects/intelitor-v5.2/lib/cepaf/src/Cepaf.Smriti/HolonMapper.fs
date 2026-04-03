namespace Cepaf.Smriti

open System
open System.Text.Json
open Microsoft.Data.Sqlite
open Cepaf.Smriti.Domain

// Run 3: Storage Hardening - SQLite Interop

module HolonMapper =

    // Data Transfer Object to avoid Discriminated Union serialization issues in System.Text.Json
    [<CLIMutable>]
    type HolonPayloadDto = {
        ApiVersion: string
        Kind: string
        Name: string
        Namespace: string
        Description: string
        Owner: string
        Lifecycle: string
    }

    let toDto (entity: CatalogEntity) : HolonPayloadDto =
        let owner, lifecycle = 
            match entity.Spec with
            | Component c -> c.Owner, c.Lifecycle.ToString()
            | Api a -> a.Owner, a.Lifecycle.ToString()
            | _ -> "unknown", "experimental"

        {
            ApiVersion = entity.ApiVersion
            Kind = entity.Kind.ToString()
            Name = entity.Metadata.Name
            Namespace = entity.Metadata.Namespace
            Description = defaultArg entity.Metadata.Description ""
            Owner = owner
            Lifecycle = lifecycle
        }

    let private serializePayload (entity: CatalogEntity) =
        let dto = toDto entity
        JsonSerializer.Serialize(dto)

    let private getFqun (e: CatalogEntity) =
        sprintf "kms/l3/%O/%s/%s" e.Kind e.Metadata.Namespace e.Metadata.Name

    let upsertHolon (connString: string) (entity: CatalogEntity) =
        use conn = new SqliteConnection(connString)
        conn.Open()
        
        let fqun = getFqun entity
        let typeStr = entity.Kind.ToString().ToLower()
        let name = entity.Metadata.Name
        let payload = serializePayload entity
        
        let vitalSigns = """{"health": 1.0, "compliance": 0.0, "drift": 0.0}"""

        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT INTO holons (id, fqun, type, name, payload, vital_signs, updated_at)
            VALUES (@id, @fqun, @type, @name, @payload, @vitals, datetime('now'))
            ON CONFLICT(fqun) DO UPDATE SET
                payload = excluded.payload,
                updated_at = datetime('now');
        """
        
        cmd.Parameters.AddWithValue("@id", fqun) |> ignore
        cmd.Parameters.AddWithValue("@fqun", fqun) |> ignore
        cmd.Parameters.AddWithValue("@type", typeStr) |> ignore
        cmd.Parameters.AddWithValue("@name", name) |> ignore
        cmd.Parameters.AddWithValue("@payload", payload) |> ignore
        cmd.Parameters.AddWithValue("@vitals", vitalSigns) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore
        printfn "[KMS] Upserted Holon: %s" fqun