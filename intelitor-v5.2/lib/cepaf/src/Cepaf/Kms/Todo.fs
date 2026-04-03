namespace Cepaf.Kms

open System
open System.ComponentModel.DataAnnotations.Schema

[<Table("kms_todos")>]
type Todo = {
    [<Column("id")>] Id: Guid
    [<Column("title")>] Title: string
    [<Column("description")>] Description: string
    [<Column("status")>] Status: string
    [<Column("priority")>] Priority: string
    [<Column("layer")>] Layer: string
    [<Column("readable_id")>] ReadableId: int
    [<Column("points")>] Points: Nullable<int>
    
    // JSON Serialized Fields (SQLite Text)
    [<Column("custom_fields")>] CustomFields: string
    [<Column("tags")>] Tags: string
    [<Column("payload")>] Payload: string
    
    [<Column("inserted_at")>] InsertedAt: DateTime
    [<Column("updated_at")>] UpdatedAt: DateTime
}

module TodoRepository =
    let getActiveTasks (connString: string) =
        // Dapper query placeholder
        sprintf "SELECT * FROM kms_todos WHERE status = 'in_progress'"