namespace Cepaf.Planning

open System
open System.IO

module Manager =

    let private backupPath = "PROJECT_TODOLIST.md"
    let private chayaDataPath = "data/chaya"

    // =========================================================================
    // SC-SYNC-PLAN-008: Bijective status enum mapping (Planning ↔ Chaya)
    // =========================================================================
    let planningStatusToChaya (status: TaskStatus) : string =
        match status with
        | Pending -> "todo"
        | InProgress -> "in_progress"
        | Completed -> "done"
        | Blocked -> "blocked"
        | Unknown _ -> "todo"

    /// Reverse mapping for verification only (SC-SYNC-PLAN-007)
    /// NOT for data flow — Chaya→Planning is FORBIDDEN (AOR-SYNC-PLAN-004)
    let chayaStatusToPlanning (status: string) : TaskStatus =
        match status with
        | "todo" -> Pending
        | "in_progress" -> InProgress
        | "done" -> Completed
        | "blocked" -> Blocked
        | s -> Unknown s

    let planningPriorityToChaya (priority: Priority) : string =
        match priority with
        | P0_Critical -> "P0"
        | P1_High -> "P1"
        | P2_Medium -> "P2"
        | P3_Low -> "P3"
        | P4_Minimal -> "P4"
        | Priority.Unknown _ -> "P3"

    /// Convert a Planning TaskItem to a Chaya ChayaTask (SC-SYNC-PLAN-008)
    /// Single source of truth for the mapping — used by Manager and ChayaCLI
    let convertToChayaTask (task: TaskItem) : Cepaf.Planning.Chaya.ChayaTask = {
        Id = task.Id
        Title = task.Title
        Description = None
        Status = planningStatusToChaya task.Status
        Priority = planningPriorityToChaya task.Priority
        CreatedAt = DateTimeOffset(DateTime.SpecifyKind(task.Created, DateTimeKind.Utc))
        UpdatedAt = DateTimeOffset.UtcNow
        DueDate = None
        AssignedNode = None
        EstimatedMinutes = None
        Tags = []
    }

    // =========================================================================
    // SC-SYNC-PLAN-011: Sync single task to Chaya after Planning mutation
    // SC-SYNC-PLAN-014: Failures must not corrupt either DB
    // SC-SYNC-PLAN-017: Verification failures MUST be reported
    // =========================================================================
    let syncTaskToChaya (task: TaskItem) : Result<unit, string> =
        try
            let config = Cepaf.Planning.Chaya.ChayaConfig.defaultConfig()
            let chayaConfig = { config with DataPath = chayaDataPath }
            Cepaf.Planning.Chaya.ChayaRepository.ensureDatabase chayaConfig
            let chayaTask = convertToChayaTask task
            Cepaf.Planning.Chaya.ChayaRepository.saveTask chayaConfig chayaTask
            Ok ()
        with ex ->
            let msg = sprintf "Failed to sync task %s to Chaya: %s" task.Id ex.Message
            printfn "[SYNC-ALERT] %s" msg
            Error msg

    /// Update the markdown backup file from database state
    let updateBackup () =
        let tasks = Repository.getAllTasks()
        // Sort by ID or creation to maintain stability
        let sortedTasks = tasks |> List.sortBy (fun t -> t.Id)
        let markdown = MarkdownParser.generateMarkdown sortedTasks

        // Atomic write pattern (SC-SYNC-PLAN-014: failures must not corrupt)
        let tempPath = backupPath + ".tmp"
        File.WriteAllText(tempPath, markdown)
        File.Move(tempPath, backupPath, true)
        printfn "[Manager] Backup updated at %s" backupPath

    /// Create a timestamped backup in backups/todolist/
    let createTimestampedBackup () =
        let backupDir = "backups/todolist"
        Directory.CreateDirectory(backupDir) |> ignore
        let timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss")
        let destPath = Path.Combine(backupDir, sprintf "PROJECT_TODOLIST_%s.md" timestamp)
        File.Copy(backupPath, destPath, true)
        printfn "Backup created: %s" destPath
        destPath

    /// Execute git sync (add PROJECT_TODOLIST.md)
    let syncWithGit () =
        printfn "Syncing todolist with git..."
        let psi = System.Diagnostics.ProcessStartInfo("git", sprintf "add %s" backupPath)
        psi.RedirectStandardOutput <- true
        psi.UseShellExecute <- false
        let p = System.Diagnostics.Process.Start(psi)
        p.WaitForExit()
        printfn "Todolist synced with git staging"

    /// SC-SYNC-PLAN-004: Markdown import ONLY when Planning.db is empty (cold start)
    /// SC-ENFORCE-001: Cold start import audit logged for compliance
    let initialize () =
        Repository.ensureDbExists()

        let tasks = Repository.getAllTasks()
        if List.isEmpty tasks && File.Exists(backupPath) then
            // Cold start: DB empty — validate import via PlanningEnforcer (SC-ENFORCE-001)
            let ctx : RequestContext = {
                AgentType = SystemProcess "manager-cold-start"
                RequestedPath = "data/smriti/planning.db"
                Operation = "cold_start_import"
                Timestamp = DateTime.UtcNow
                StackTrace = None
                IpAddress = None
                AdditionalContext = Map.ofList [
                    ("action", "cold_start_import")
                    ("source_file", backupPath)
                    ("cold_start", "true")
                ]
            }
            match PlanningEnforcer.enforceAccess ctx with
            | Denied (reason, _) ->
                printfn "[Manager] ACCESS DENIED on cold start import: %s (SC-ENFORCE-001)" reason
                printfn "[Manager] Skipping markdown import due to access denial"
            | CircuitOpen (agent, count) ->
                printfn "[Manager] CIRCUIT OPEN on cold start import: %s (%d violations)" agent count
                printfn "[Manager] Skipping markdown import due to circuit open"
            | Allowed _ ->
                printfn "[Manager] DB empty (cold start). Importing from %s... (SC-SYNC-PLAN-004)" backupPath
                let content = File.ReadAllText(backupPath)
                let importedTasks = MarkdownParser.parse content

                for task in importedTasks do
                    Repository.saveTask task
                    ZenohAdapter.publish (ZenohAdapter.TaskCreated task)

                printfn "[Manager] Cold start: imported %d tasks." importedTasks.Length
        elif not (List.isEmpty tasks) then
            // SC-SYNC-PLAN-004: Planning.db has data — skip markdown import
            printfn "[Manager] Planning.db has %d tasks. Skipping markdown import (SC-SYNC-PLAN-004)." tasks.Length

    /// SC-SYNC-PLAN-011: Every sa-plan add MUST trigger Chaya sync
    /// SC-ENFORCE-001: Defense-in-depth enforcement at Manager layer
    let addTask (parentId: string option) (title: string) (priority: string option) =
        let ctx : RequestContext = {
            AgentType = SystemProcess "manager-internal"
            RequestedPath = "data/smriti/planning.db"
            Operation = "write"
            Timestamp = DateTime.UtcNow
            StackTrace = Some (System.Diagnostics.StackTrace(true).ToString())
            IpAddress = None
            AdditionalContext = Map.ofList [("action", "addTask"); ("title", title)]
        }
        match PlanningEnforcer.enforceAccess ctx with
        | Denied (reason, _) ->
            printfn "[Manager] ACCESS DENIED on addTask: %s" reason
            Error (sprintf "Access denied: %s" reason)
        | CircuitOpen (agent, count) ->
            printfn "[Manager] CIRCUIT OPEN on addTask: %s (%d violations)" agent count
            Error (sprintf "Circuit open: %s (%d violations)" agent count)
        | Allowed _ ->
            let id = Guid.NewGuid().ToString().Substring(0, 8)

            let p = match priority with Some s -> DomainHelpers.parsePriority s | None -> P3_Low

            let task = {
                Id = id
                Title = title
                Status = Pending
                Priority = p
                ParentId = parentId
                Owner = None
                Created = DateTime.UtcNow
                RawLines = [ sprintf "### %s - %s (%s)" id title (p.ToString())
                             sprintf "**Status**: pending | **Priority**: %s" (p.ToString()) ]
            }

            Repository.saveTask task
            ZenohAdapter.publish (ZenohAdapter.TaskCreated task)
            updateBackup()
            match syncTaskToChaya task with  // SC-SYNC-PLAN-011: Sync to Chaya
            | Ok () -> ()
            | Error msg -> printfn "[SYNC-WARN] addTask: %s" msg
            Ok task

    /// SC-SYNC-PLAN-011: Every sa-plan update MUST trigger Chaya sync
    /// SC-ENFORCE-001: Defense-in-depth enforcement at Manager layer
    let updateStatus (id: string) (statusStr: string) =
        let ctx : RequestContext = {
            AgentType = SystemProcess "manager-internal"
            RequestedPath = "data/smriti/planning.db"
            Operation = "write"
            Timestamp = DateTime.UtcNow
            StackTrace = Some (System.Diagnostics.StackTrace(true).ToString())
            IpAddress = None
            AdditionalContext = Map.ofList [("action", "updateStatus"); ("taskId", id); ("newStatus", statusStr)]
        }
        match PlanningEnforcer.enforceAccess ctx with
        | Denied (reason, _) ->
            printfn "[Manager] ACCESS DENIED on updateStatus: %s" reason
            Error (sprintf "Access denied: %s" reason)
        | CircuitOpen (agent, count) ->
            printfn "[Manager] CIRCUIT OPEN on updateStatus: %s (%d violations)" agent count
            Error (sprintf "Circuit open: %s (%d violations)" agent count)
        | Allowed _ ->
            match Repository.getTask id with
            | Some task ->
                let newStatus = DomainHelpers.parseStatus statusStr
                let updatedTask = { task with Status = newStatus }

                let updatedLines =
                    task.RawLines
                    |> List.map (fun line ->
                        if line.Contains("**Status**:") then
                            System.Text.RegularExpressions.Regex.Replace(line, @"\*\*Status\*\*:\s*\w+", sprintf "**Status**: %s" (newStatus.ToString()))
                        else line)

                let finalTask = { updatedTask with RawLines = updatedLines }

                Repository.saveTask finalTask
                ZenohAdapter.publish (ZenohAdapter.TaskUpdated finalTask)
                updateBackup()
                match syncTaskToChaya finalTask with  // SC-SYNC-PLAN-011: Sync to Chaya
                | Ok () -> ()
                | Error msg -> printfn "[SYNC-WARN] updateStatus: %s" msg
                Ok finalTask
            | None -> Error "Task not found"
