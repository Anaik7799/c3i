// [AGENT_RECREATION_GENOME]
// Purpose: Universal DuckDB/SQLite Concurrency Hub v2.0.
// Function: Provides thread-safe, multi-reader/single-writer access.
// Implementation: Actor-based write serialization + Parallel read pool using DataReader.
// Protocol: SC-DB-CONCUR-001, SIL-6 Compliant.
// [/AGENT_RECREATION_GENOME]

namespace Cepaf.Substrate

open System
open System.Data
open System.Collections.Concurrent
open System.Threading.Tasks
open Microsoft.Data.Sqlite

type DBRequest =
    | Query of sql: string * parameters: (string * obj) list * reply: TaskCompletionSource<DataTable>
    | Execute of sql: string * parameters: (string * obj) list * reply: TaskCompletionSource<int>
    | Transaction of actions: (string * (string * obj) list) list * reply: TaskCompletionSource<bool>

module DuckDBHub =
    
    let private smritiDbPath = "data/smriti/Smriti.db"
    let private connectionString = sprintf "Data Source=%s;Cache=Shared" smritiDbPath
    
    // The Master Connection: Persistent for write performance and locking
    let private masterConn = new SqliteConnection(connectionString)
    
    let private initDb () =
        if masterConn.State <> ConnectionState.Open then
            masterConn.Open()
            // Enable WAL mode for better concurrency (N-Readers/1-Writer)
            use cmd = masterConn.CreateCommand()
            cmd.CommandText <- "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;"
            cmd.ExecuteNonQuery() |> ignore

    // The MailboxProcessor handles all MUTATING operations sequentially
    let private writerActor = MailboxProcessor<DBRequest>.Start(fun inbox ->
        async {
            initDb()
            while true do
                let! msg = inbox.Receive()
                match msg with
                | Execute(sql, paramsList, reply) ->
                    try
                        use cmd = masterConn.CreateCommand()
                        cmd.CommandText <- sql
                        for (k, v) in paramsList do
                            let value = if obj.ReferenceEquals(v, null) then box DBNull.Value else v
                            cmd.Parameters.AddWithValue(k, value) |> ignore
                        let res = cmd.ExecuteNonQuery()
                        reply.SetResult(res)
                    with ex ->
                        reply.SetException(ex)
                
                | Transaction(actions, reply) ->
                    use tx = masterConn.BeginTransaction()
                    try
                        for (sql, paramsList) in actions do
                            use cmd = masterConn.CreateCommand()
                            cmd.Transaction <- tx
                            cmd.CommandText <- sql
                            for (k, v) in paramsList do
                                let value = if obj.ReferenceEquals(v, null) then box DBNull.Value else v
                                cmd.Parameters.AddWithValue(k, value) |> ignore
                            cmd.ExecuteNonQuery() |> ignore
                        tx.Commit()
                        reply.SetResult(true)
                    with ex ->
                        tx.Rollback()
                        reply.SetException(ex)
                
                | Query(sql, paramsList, reply) ->
                    try
                        use cmd = masterConn.CreateCommand()
                        cmd.CommandText <- sql
                        for (k, v) in paramsList do
                            let value = if obj.ReferenceEquals(v, null) then box DBNull.Value else v
                            cmd.Parameters.AddWithValue(k, value) |> ignore
                        use reader = cmd.ExecuteReader()
                        let table = new DataTable()
                        table.Load(reader)
                        reply.SetResult(table)
                    with ex ->
                        reply.SetException(ex)
        })

    /// Execute a non-query command (Write/Update/Delete) - Serialized
    let executeAsync sql paramsList =
        let tcs = TaskCompletionSource<int>()
        writerActor.Post(Execute(sql, paramsList, tcs))
        tcs.Task |> Async.AwaitTask

    /// Execute a transaction of multiple commands - Atomic/Serialized
    let transactionAsync actions =
        let tcs = TaskCompletionSource<bool>()
        writerActor.Post(Transaction(actions, tcs))
        tcs.Task |> Async.AwaitTask

    /// Execute a query (Read) - Concurrent-safe
    let queryAsync sql paramsList =
        async {
            try
                use conn = new SqliteConnection(connectionString)
                conn.Open()
                use cmd = conn.CreateCommand()
                cmd.CommandText <- sql
                for (k, v) in paramsList do
                    let value = if obj.ReferenceEquals(v, null) then box DBNull.Value else v
                    cmd.Parameters.AddWithValue(k, value) |> ignore
                use reader = cmd.ExecuteReader()
                let table = new DataTable()
                table.Load(reader)
                return table
            with ex ->
                // Fallback to serialized read if connection pool is exhausted or locked
                let tcs = TaskCompletionSource<DataTable>()
                writerActor.Post(Query(sql, paramsList, tcs))
                return! tcs.Task |> Async.AwaitTask
        }
