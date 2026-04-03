namespace Cepaf.Observability

open System
open Microsoft.Data.Sqlite

module KmsTodos =
    // SIL-6: Dedicated Todo Database (SC-HOLON-001)
    let connectionString = "Data Source=data/kms/todos.db"

    type Todo = {
        Id: string
        Title: string
        Status: string
        Priority: string
        Layer: string
    }

    let listTodos () =
        use connection = new SqliteConnection(connectionString)
        connection.Open()

        let command = connection.CreateCommand()
        // Simple direct query on dedicated table
        command.CommandText <- "
            SELECT 
                id, 
                name, 
                status,
                priority,
                layer
            FROM todos 
            ORDER BY priority ASC"

        use reader = command.ExecuteReader()
        let mutable todos = []

        while reader.Read() do
            let todo = {
                Id = if reader.IsDBNull(0) then "" else reader.GetString(0)
                Title = if reader.IsDBNull(1) then "" else reader.GetString(1)
                Status = if reader.IsDBNull(2) then "pending" else reader.GetString(2)
                Priority = if reader.IsDBNull(3) then "P2" else reader.GetString(3)
                Layer = if reader.IsDBNull(4) then "L1" else reader.GetString(4)
            }
            todos <- todo :: todos

        todos |> List.rev
