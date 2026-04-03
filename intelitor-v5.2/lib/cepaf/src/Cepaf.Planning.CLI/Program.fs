// =============================================================================
// Program.fs - Unified CLI for Planning and Chaya Systems
// =============================================================================
// STAMP: SC-CLI-001, SC-PLAN-001, SC-CHAYA-001
// AOR: AOR-CLI-001
// Criticality: Level 4 (REQUIRED) - Main Entry Point
// =============================================================================
// Provides unified command-line interface for:
// - PROJECT_TODOLIST.md management (sa-plan)
// - Chaya Digital Twin operations (chaya)
// =============================================================================

open System
open Cepaf.Planning
open Cepaf.Planning.CLI

/// Show unified help
let showHelp () =
    printfn ""
    printfn "=========================================================="
    printfn "  INDRAJAAL PLANNING SYSTEM"
    printfn "  SC-PLAN-001 | F# Unified Task Management"
    printfn "=========================================================="
    printfn ""
    printfn "MODES:"
    printfn "  plan    Manage PROJECT_TODOLIST.md tasks"
    printfn "  chaya   Chaya Digital Twin operations"
    printfn ""
    printfn "PLANNING COMMANDS (sa-plan):"
    printfn "  status               Show project task status"
    printfn "  add <title>          Add new task"
    printfn "  update <id> <status> Update task status"
    printfn "  backup               Create timestamped backup"
    printfn "  sync                 Sync PROJECT_TODOLIST.md to git"
    printfn ""
    printfn "CHAYA COMMANDS (chaya):"
    printfn "  status               Show Chaya status and health"
    printfn "  list [status]        List tasks (optionally by status)"
    printfn "  add <title> [pri]    Add task with optional priority"
    printfn "  update <id> <status> Update task status"
    printfn "  ooda                 Run OODA cycle"
    printfn "  mesh                 Show mesh topology"
    printfn "  sync                 Sync with PROJECT_TODOLIST.md"
    printfn "  help                 Show full Chaya help"
    printfn ""
    printfn "EXAMPLES:"
    printfn "  sa-plan status"
    printfn "  sa-plan add \"New feature\""
    printfn "  chaya status"
    printfn "  chaya add \"Task\" P1"
    printfn "  chaya ooda"
    printfn ""

/// Unified helper for access enforcement
let enforceAccess op path =
    let ctx : Cepaf.Planning.RequestContext = {
        AgentType = SystemProcess "sa-plan-cli"
        RequestedPath = path
        Operation = op
        Timestamp = DateTime.UtcNow
        StackTrace = None
        IpAddress = None
        AdditionalContext = Map.empty
    }
    match PlanningEnforcer.enforceAccess ctx with
    | Cepaf.Planning.Allowed _ -> true
    | Cepaf.Planning.Denied (reason, _) ->
        printfn "🚫 ACCESS DENIED: %s" reason
        false
    | Cepaf.Planning.CircuitOpen (agent, count) ->
        printfn "🛑 CIRCUIT OPEN: Agent %s blocked after %d violations" agent count
        false

/// Unified helper for safety validation
let validateOperation goal details =
    let proposal : OperationProposal = {
        Operation = goal
        Agent = "sa-plan-cli"
        Payload = Map.ofList [ 
            ("details", details :> obj)
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
    | Ok _ -> true
    | Error reason ->
        printfn "🛡️ SAFETY VETO: %s" reason
        false

[<EntryPoint>]
let main argv =
    // Initialize Kernel
    SafetyKernel.activate()

    // Check if first arg indicates mode
    match argv with
    | [||] ->
        // No args - show planning status (default behavior)
        if enforceAccess "read" "Planning.db" then
            Manager.initialize()
            let tasks = Repository.getAllTasks()
            printfn "🎯 INTELITOR PROJECT TODOLIST (F# Managed)"
            printfn "==========================================="
            let active = tasks |> List.filter (fun t -> t.Status = InProgress)
            let pending = tasks |> List.filter (fun t -> t.Status = Pending)
            let completed = tasks |> List.filter (fun t -> t.Status = Completed)
            printfn "🔄 Active: %d | ⏳ Pending: %d | ✅ Completed: %d" active.Length pending.Length completed.Length
            printfn ""
            for t in active do
                printfn "  🔄 %s - %s (%s)" t.Id t.Title (t.Priority.ToString())
            0
        else 1

    | [| "chaya" |] ->
        ChayaCLI.main [||]

    | args when args.Length > 0 && args.[0] = "chaya" ->
        ChayaCLI.main (args.[1..])

    | [| "help" |] | [| "--help" |] | [| "-h" |] ->
        showHelp()
        0

    // Planning commands (default mode)
    | [| "status" |] ->
        if enforceAccess "read" "Planning.db" then
            Manager.initialize()
            let tasks = Repository.getAllTasks()
            printfn "🎯 INTELITOR PROJECT TODOLIST (F# Managed)"
            printfn "==========================================="
            let active = tasks |> List.filter (fun t -> t.Status = InProgress)
            let pending = tasks |> List.filter (fun t -> t.Status = Pending)
            let completed = tasks |> List.filter (fun t -> t.Status = Completed)
            printfn "🔄 Active: %d | ⏳ Pending: %d | ✅ Completed: %d" active.Length pending.Length completed.Length
            printfn ""
            for t in active do
                printfn "  🔄 %s - %s (%s)" t.Id t.Title (t.Priority.ToString())
            0
        else 1

    | [| "add"; title |] ->
        if enforceAccess "write" "Planning.db" && validateOperation "add_task" title then
            Manager.initialize()
            match Manager.addTask None title None with
            | Ok task ->
                printfn "✅ Task added: %s" task.Id
                0
            | Error e ->
                printfn "❌ Error: %s" e
                1
        else 1

    | [| "add"; title; priority |] ->
        if enforceAccess "write" "Planning.db" && validateOperation "add_task" title then
            Manager.initialize()
            match Manager.addTask None title (Some priority) with
            | Ok task ->
                printfn "✅ Task added: %s (%s)" task.Id priority
                0
            | Error e ->
                printfn "❌ Error: %s" e
                1
        else 1

    | [| "add"; title; priority; parentId |] ->
        if enforceAccess "write" "Planning.db" && validateOperation "add_task" title then
            Manager.initialize()
            match Manager.addTask (Some parentId) title (Some priority) with
            | Ok task ->
                printfn "✅ Task added: %s (%s) [Parent: %s]" task.Id priority parentId
                0
            | Error e ->
                printfn "❌ Error: %s" e
                1
        else 1

    | [| "update"; id; status |] ->
        if enforceAccess "write" "Planning.db" && validateOperation "update_task" $"%s{id}:%s{status}" then
            Manager.initialize()
            match Manager.updateStatus id status with
            | Ok _ ->
                printfn "✅ Task %s updated to %s" id status
                0
            | Error e ->
                printfn "❌ Error: %s" e
                1
        else 1

    | [| "list" |] ->
        if enforceAccess "read" "Planning.db" then
            Manager.initialize()
            let tasks = Repository.getAllTasks()
            printfn ""
            printfn "ALL TASKS: %d" tasks.Length
            printfn "----------------------------------------------------------"
            for t in tasks do
                let statusIcon =
                    match t.Status with
                    | TaskStatus.Pending -> "[ ]"
                    | TaskStatus.InProgress -> "[*]"
                    | TaskStatus.Completed -> "[x]"
                    | TaskStatus.Blocked -> "[!]"
                    | TaskStatus.Unknown _ -> "[?]"
                printfn "  %s %s - %s" statusIcon t.Id t.Title
            printfn ""
            0
        else 1

    | [| "list"; statusFilter |] ->
        if enforceAccess "read" "Planning.db" then
            Manager.initialize()
            let status = DomainHelpers.parseStatus statusFilter
            let tasks = Repository.getAllTasks() |> List.filter (fun t -> t.Status = status)
            printfn ""
            printfn "TASKS (%s): %d" statusFilter tasks.Length
            printfn "----------------------------------------------------------"
            for t in tasks do
                printfn "  %s - %s" t.Id t.Title
            printfn ""
            0
        else 1

    | [| "backup" |] ->
        if enforceAccess "write" "backups/planning" then
            Manager.initialize()
            Manager.createTimestampedBackup() |> ignore
            0
        else 1

    | [| "sync" |] ->
        if enforceAccess "execute" "git" && validateOperation "sync_git" "PROJECT_TODOLIST.md" then
            Manager.initialize()
            Manager.syncWithGit()
            0
        else 1

    | _ ->
        showHelp()
        1
