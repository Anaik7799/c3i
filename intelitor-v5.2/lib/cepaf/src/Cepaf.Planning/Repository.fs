namespace Cepaf.Planning

open System
open System.IO
open System.Data
open Dapper
open Cepaf.Planning
open Cepaf.Planning.Integration
open Cepaf.Substrate

module Repository =

    let private dbPath = "data/smriti/planning.db"

    let ensureDbExists () =
        let dir = Path.GetDirectoryName(dbPath)
        if not (Directory.Exists(dir)) then
            Directory.CreateDirectory(dir) |> ignore
        
        let sql = """
            CREATE TABLE IF NOT EXISTS Tasks (
                Id TEXT PRIMARY KEY,
                Title TEXT NOT NULL,
                Status TEXT NOT NULL,
                Priority TEXT NOT NULL,
                ParentId TEXT,
                Owner TEXT,
                Created TEXT NOT NULL,
                RawLines TEXT -- JSON or delimited blob for restoration
            );
            CREATE INDEX IF NOT EXISTS idx_status ON Tasks(Status);
            CREATE INDEX IF NOT EXISTS idx_parent ON Tasks(ParentId);
        """
        DuckDBHub.executeAsync sql [] |> Async.RunSynchronously |> ignore

    let saveTask (task: TaskItem) =
        let sql = """
            INSERT OR REPLACE INTO Tasks (Id, Title, Status, Priority, ParentId, Owner, Created, RawLines)
            VALUES (@Id, @Title, @Status, @Priority, @ParentId, @Owner, @Created, @RawLines)
        """
        // Simple serialization for RawLines list - newline delimited
        let rawLinesBlob = String.Join("\n", task.RawLines)
        
        let statusStr = task.Status.ToString()
        let priorityStr = task.Priority.ToString()
        let createdStr = task.Created.ToString("o")
        let param = [
            ("Id", box task.Id)
            ("Title", box task.Title)
            ("Status", box statusStr)
            ("Priority", box priorityStr)
            ("ParentId", box (Option.toObj task.ParentId))
            ("Owner", box (Option.toObj task.Owner))
            ("Created", box createdStr)
            ("RawLines", box rawLinesBlob)
        ]
        DuckDBHub.executeAsync sql param |> Async.RunSynchronously |> ignore

    let getTask (id: string) : TaskItem option =
        let sql = "SELECT * FROM Tasks WHERE Id = @Id"
        let table = DuckDBHub.queryAsync sql [("Id", box id)] |> Async.RunSynchronously
        
        if table.Rows.Count = 0 then None
        else
            let row = table.Rows.[0]
            Some {
                Id = row.["Id"] :?> string
                Title = row.["Title"] :?> string
                Status = DomainHelpers.parseStatus (row.["Status"] :?> string)
                Priority = DomainHelpers.parsePriority (row.["Priority"] :?> string)
                ParentId = if row.IsNull("ParentId") then None else Some (row.["ParentId"] :?> string)
                Owner = if row.IsNull("Owner") then None else Some (row.["Owner"] :?> string)
                Created = DateTime.Parse(row.["Created"] :?> string)
                RawLines = (row.["RawLines"] :?> string).Split('\n') |> Array.toList
            }

    let getAllTasks () : TaskItem list =
        let sql = "SELECT * FROM Tasks"
        let table = DuckDBHub.queryAsync sql [] |> Async.RunSynchronously

        [ for row in table.Rows ->
            {
                Id = row.["Id"] :?> string
                Title = row.["Title"] :?> string
                Status = DomainHelpers.parseStatus (row.["Status"] :?> string)
                Priority = DomainHelpers.parsePriority (row.["Priority"] :?> string)
                ParentId = if row.IsNull("ParentId") then None else Some (row.["ParentId"] :?> string)
                Owner = if row.IsNull("Owner") then None else Some (row.["Owner"] :?> string)
                Created = DateTime.Parse(row.["Created"] :?> string)
                RawLines = (row.["RawLines"] :?> string).Split('\n') |> Array.toList
            }
        ]

    /// Import tasks from PROJECT_TODOLIST.md using AI-assisted parsing
    /// SC-PLAN-070: Uses OpenRouter for intelligent parsing with regex fallback
    let importFromMarkdown (filePath: string) : int =
        ensureDbExists()

        if not (File.Exists(filePath)) then
            printfn "[Repository] File not found: %s" filePath
            0
        else
            let tasks = OpenRouterParser.parseFile filePath
            printfn "[Repository] Parsed %d tasks from %s" tasks.Length filePath

            for task in tasks do
                saveTask task

            tasks.Length

    /// Import from default PROJECT_TODOLIST.md location
    /// SC-TODO-001: Audit logged — direct access to PROJECT_TODOLIST.md
    /// SC-ENFORCE-001: PlanningEnforcer access check required
    let importFromProjectTodolist () : int =
        let ctx : RequestContext = {
            AgentType = SystemProcess "repository-import"
            RequestedPath = dbPath
            Operation = "cold_start_import"
            Timestamp = DateTime.UtcNow
            StackTrace = Some (System.Diagnostics.StackTrace(true).ToString())
            IpAddress = None
            AdditionalContext = Map.ofList [
                ("action", "importFromProjectTodolist")
                ("target_file", "PROJECT_TODOLIST.md")
                ("audit_reason", "SC-TODO-001: Markdown import for cold start only")
            ]
        }
        match PlanningEnforcer.enforceAccess ctx with
        | Denied (reason, _) ->
            printfn "[Repository] ACCESS DENIED on importFromProjectTodolist: %s" reason
            0
        | CircuitOpen (agent, count) ->
            printfn "[Repository] CIRCUIT OPEN on importFromProjectTodolist: %s (%d violations)" agent count
            0
        | Allowed _ ->
            let projectRoot =
                let currentDir = Directory.GetCurrentDirectory()
                let rec findRoot dir =
                    let filePath = Path.Combine(dir, "PROJECT_TODOLIST.md")
                    if File.Exists(filePath) then Some dir
                    else
                        let parent = Directory.GetParent(dir)
                        if parent = null then None
                        else findRoot parent.FullName
                findRoot currentDir
                |> Option.defaultValue currentDir
            let todoPath = Path.Combine(projectRoot, "PROJECT_TODOLIST.md")
            importFromMarkdown todoPath

    /// Clear all tasks from database
    /// SC-SAFETY-001: Requires SafetyKernel validation (destructive operation)
    /// SC-ENFORCE-001: PlanningEnforcer access check required
    let clearAllTasks () =
        let ctx : RequestContext = {
            AgentType = SystemProcess "repository-internal"
            RequestedPath = dbPath
            Operation = "delete_all"
            Timestamp = DateTime.UtcNow
            StackTrace = Some (System.Diagnostics.StackTrace(true).ToString())
            IpAddress = None
            AdditionalContext = Map.ofList [("action", "clearAllTasks"); ("destructive", "true")]
        }
        match PlanningEnforcer.enforceAccess ctx with
        | Allowed _ ->
            let proposal : OperationProposal = {
                Operation = "clear_all_tasks"
                Agent = "repository-internal"
                Payload = Map.ofList [
                    ("details", "DELETE all tasks from Planning.db" :> obj)
                    ("rollback_available", true :> obj)
                    ("audit_logging", true :> obj)
                    ("rollback_path", "Planning.db.bak" :> obj)
                ]
                Priority = "P0"
                Timestamp = DateTime.UtcNow
                RequiresGuardian = true
                RequiresConstitutional = true
            }
            match SafetyKernel.validateOperation proposal with
            | Ok _ ->
                DuckDBHub.executeAsync "DELETE FROM Tasks" [] |> Async.RunSynchronously |> ignore
                printfn "[Repository] Cleared all tasks (SC-SAFETY-001: approved)"
            | Error reason ->
                printfn "[Repository] SAFETY VETO on clearAllTasks: %s" reason
        | Denied (reason, _) ->
            printfn "[Repository] ACCESS DENIED on clearAllTasks: %s" reason
        | CircuitOpen (agent, count) ->
            printfn "[Repository] CIRCUIT OPEN on clearAllTasks: %s (%d violations)" agent count
