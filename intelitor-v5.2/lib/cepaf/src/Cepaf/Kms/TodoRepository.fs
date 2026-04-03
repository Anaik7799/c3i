namespace Cepaf.Kms

open System
open System.Data.SQLite
open System.Text.Json
open System.Text.Json.Serialization

// --- DOMAIN TYPES ---

type TaskStatus = 
    | Backlog | InProgress | Done | Blocked | Archived 
    static member FromString(s: string) = 
        match s with
        | "backlog" -> Backlog
        | "in_progress" -> InProgress
        | "done" -> Done
        | "blocked" -> Blocked
        | "archived" -> Archived
        | _ -> Backlog

type TaskPriority = P0 | P1 | P2 | P3 | P4

type Todo = {
    Id: Guid
    Title: string
    Status: TaskStatus
    Priority: TaskPriority
    CustomFields: Map<string, string>
    Children: Todo list
}

// --- REPOSITORY ---

module TodoRepository =
    
    let connectionString = "Data Source=data/kms/todos.db;Version=3;"

    let private mapReader (reader: SQLiteDataReader) =
        {
            Id = Guid.Parse(reader.["id"].ToString())
            Title = reader.["title"].ToString()
            Status = TaskStatus.FromString(reader.["status"].ToString())
            Priority = P2 // Parser needed
            CustomFields = Map.empty // JSON Parser needed
            Children = []
        }

    let getActiveTasks () =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        let cmd = new SQLiteCommand("SELECT * FROM kms_todos WHERE status = 'in_progress'", conn)
        use reader = cmd.ExecuteReader()
        
        [ while reader.Read() do yield mapReader reader ]

    let createSystemTask (title: string) (priority: string) =
        use conn = new SQLiteConnection(connectionString)
        conn.Open()
        let id = Guid.NewGuid()
        let cmd = new SQLiteCommand("INSERT INTO kms_todos (id, title, status, priority, layer, inserted_at, updated_at) VALUES (@id, @title, 'backlog', @prio, 'l1', @now, @now)", conn)
        cmd.Parameters.AddWithValue("@id", id.ToString()) |> ignore
        cmd.Parameters.AddWithValue("@title", title) |> ignore
        cmd.Parameters.AddWithValue("@prio", priority) |> ignore
        cmd.Parameters.AddWithValue("@now", DateTime.UtcNow) |> ignore
        
        cmd.ExecuteNonQuery() |> ignore
        id
