namespace Cepaf.KmsCatalog.Tests

open System.IO
open NUnit.Framework
open Cepaf.KmsCatalog
open Cepaf.KmsCatalog.Domain
open Microsoft.Data.Sqlite

// LEVEL 3: PERSISTENCE & STORAGE VERIFICATION
// Tests SQLite interactions via HolonMapper.

[<TestFixture>]
type Level3_PersistenceTests() =

    let dbPath = "test_l3.db"
    let connStr = sprintf "Data Source=%s" dbPath

    [<SetUp>]
    member this.Setup() =
        // Initialize schema
        use conn = new SqliteConnection(connStr)
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- """
            CREATE TABLE IF NOT EXISTS holons (
                id TEXT PRIMARY KEY,
                fqun TEXT UNIQUE,
                type TEXT,
                name TEXT,
                payload JSON,
                vital_signs JSON,
                updated_at DATETIME
            )
        """
        cmd.ExecuteNonQuery() |> ignore

    [<TearDown>]
    member this.Teardown() =
        if File.Exists(dbPath) then File.Delete(dbPath)

    [<Test>]
    member this.``HolonMapper should upsert and retrieve entity``() =
        let entity = {
            ApiVersion = "v1"
            Kind = KindComponent
            Metadata = { Name = "db-service"; Namespace = "default"; Uid = None; Title = None; Description = None; Tags = []; Labels = Map.empty; Annotations = Map.empty; Links = Map.empty }
            Spec = Generic Map.empty
        }

        HolonMapper.upsertHolon connStr entity
        
        // Manual verification via SQL
        use conn = new SqliteConnection(connStr)
        conn.Open()
        use cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT count(*) FROM holons WHERE name = 'db-service'"
        let count = cmd.ExecuteScalar() :?> int64
        Assert.AreEqual(1L, count)
