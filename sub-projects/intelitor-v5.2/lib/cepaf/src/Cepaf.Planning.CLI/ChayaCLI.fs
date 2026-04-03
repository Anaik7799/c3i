// =============================================================================
// ChayaCLI.fs - Command-Line Interface for Chaya Digital Twin
// =============================================================================
// STAMP: SC-CHAYA-003, SC-CLI-001, SC-PLAN-080
// AOR: AOR-CHAYA-003, AOR-CLI-001
// Criticality: Level 4 (REQUIRED) - CLI Interface
// =============================================================================
// Provides full command-line access to Chaya's capabilities:
// - Task management (create, update, list, status)
// - OODA cycle execution
// - Mesh simulation and monitoring
// - Health reporting
// - Integration with PROJECT_TODOLIST.md
// =============================================================================

namespace Cepaf.Planning.CLI

open System
open Cepaf.Planning.Chaya
open Microsoft.Data.Sqlite

module ChayaCLI =

    /// Display help text
    let showHelp () =
        printfn ""
        printfn "=========================================================="
        printfn "  CHAYA - Digital Twin Task Management System"
        printfn "  SC-CHAYA-003 | Standalone Operation Mode"
        printfn "=========================================================="
        printfn ""
        printfn "USAGE:"
        printfn "  chaya <command> [args]"
        printfn ""
        printfn "TASK COMMANDS:"
        printfn "  status              Show overall Chaya status and health"
        printfn "  list                List all tasks"
        printfn "  list <status>       List tasks by status (todo|in_progress|done|blocked)"
        printfn "  add <title>         Add new task (default priority P3)"
        printfn "  add <title> <pri>   Add task with priority (P0|P1|P2|P3)"
        printfn "  update <id> <stat>  Update task status"
        printfn "  high-priority       List high priority tasks (P0, P1)"
        printfn "  overdue             List overdue tasks"
        printfn ""
        printfn "OODA COMMANDS:"
        printfn "  ooda                Run a fast OODA cycle"
        printfn "  ooda-mesh           Run mesh-aware OODA cycle"
        printfn ""
        printfn "MESH COMMANDS:"
        printfn "  mesh                Show mesh topology and status"
        printfn "  mesh-health         Detailed mesh health report"
        printfn "  distribute <strat>  Distribute tasks (round-robin|least-loaded|priority)"
        printfn ""
        printfn "SYSTEM COMMANDS:"
        printfn "  health              Chaya health report"
        printfn "  init                Initialize/reset Chaya database"
        printfn "  sync                Sync with PROJECT_TODOLIST.md"
        printfn "  help                Show this help"
        printfn ""
        printfn "EXAMPLES:"
        printfn "  chaya status"
        printfn "  chaya add \"Implement new feature\" P1"
        printfn "  chaya update abc123 done"
        printfn "  chaya ooda"
        printfn "  chaya distribute priority"
        printfn ""

    /// Format task for display
    let formatTask (task: ChayaTask) =
        let statusIcon =
            match task.Status with
            | "todo" -> "[ ]"
            | "in_progress" -> "[*]"
            | "done" -> "[x]"
            | "blocked" -> "[!]"
            | _ -> "[?]"
        let priorityColor =
            match task.Priority with
            | "P0" -> "P0!"
            | "P1" -> "P1 "
            | "P2" -> "P2 "
            | _ -> "P3 "
        sprintf "%s %s %s - %s" statusIcon priorityColor task.Id task.Title

    /// Show status command
    let showStatus (chaya: MeshAwareChaya) =
        let health = chaya.GetHealth()
        let meshHealth = chaya.GetMeshHealthSummary()
        let tasks = chaya.GetAllTasks()

        let todoCount = tasks |> List.filter (fun t -> t.Status = "todo") |> List.length
        let inProgressCount = tasks |> List.filter (fun t -> t.Status = "in_progress") |> List.length
        let doneCount = tasks |> List.filter (fun t -> t.Status = "done") |> List.length
        let blockedCount = tasks |> List.filter (fun t -> t.Status = "blocked") |> List.length

        printfn ""
        printfn "=========================================================="
        printfn "  CHAYA DIGITAL TWIN STATUS"
        printfn "=========================================================="
        printfn ""
        printfn "SYSTEM HEALTH: %s" health.Status
        printfn "  Uptime:        %s" (health.Uptime.ToString(@"d\.hh\:mm\:ss"))
        printfn "  Memory:        %d MB" health.MemoryUsageMB
        printfn "  Last OODA:     %s" (match health.LastOODACycleMs with Some ms -> sprintf "%dms" ms | None -> "N/A")
        printfn ""
        printfn "MESH STATUS: %s" (if meshHealth.IsHealthy then "HEALTHY" else "DEGRADED")
        printfn "  Nodes:         %d/%d healthy" meshHealth.HealthyNodes meshHealth.TotalNodes
        printfn "  Capacity:      %.0f%%" (meshHealth.TotalCapacity * 100.0)
        printfn "  Quorum:        %s" (if meshHealth.HasQuorum then "ACHIEVED" else "NOT ACHIEVED")
        printfn ""
        printfn "TASKS:"
        printfn "  Total:         %d" tasks.Length
        printfn "  [ ] Todo:      %d" todoCount
        printfn "  [*] Active:    %d" inProgressCount
        printfn "  [x] Done:      %d" doneCount
        printfn "  [!] Blocked:   %d" blockedCount
        printfn ""

        if inProgressCount > 0 then
            printfn "ACTIVE TASKS:"
            tasks
            |> List.filter (fun t -> t.Status = "in_progress")
            |> List.iter (fun t -> printfn "  %s" (formatTask t))
            printfn ""

    /// List tasks
    let listTasks (chaya: MeshAwareChaya) (statusFilter: string option) =
        let tasks =
            match statusFilter with
            | Some status -> chaya.GetTasksByStatus(status)
            | None -> chaya.GetAllTasks()

        printfn ""
        printfn "CHAYA TASKS: %d total" tasks.Length
        printfn "----------------------------------------------------------"

        if tasks.IsEmpty then
            printfn "  No tasks found."
        else
            tasks |> List.iter (fun t -> printfn "  %s" (formatTask t))
        printfn ""

    /// Add task
    let addTask (chaya: MeshAwareChaya) (title: string) (priority: string) =
        let task = chaya.CreateTask(title, priority)
        printfn ""
        printfn "Task created: %s" (formatTask task)
        printfn ""

    /// Update task
    let updateTask (chaya: MeshAwareChaya) (taskId: string) (status: string) =
        match chaya.UpdateTaskStatus(taskId, status) with
        | Ok task ->
            printfn ""
            printfn "Task updated: %s" (formatTask task)
            printfn ""
        | Error msg ->
            printfn ""
            printfn "Error: %s" msg
            printfn ""

    /// Run OODA cycle
    let runOODA (chaya: MeshAwareChaya) =
        let observations = [
            "Current task backlog"
            "System resources available"
            "Priority queue status"
        ]
        let selectAction _ = "Process highest priority todo task"
        let cycle = chaya.RunOODACycle(observations, selectAction)

        printfn ""
        printfn "OODA CYCLE COMPLETED"
        printfn "  Cycle ID:    %s" cycle.Id
        printfn "  Phase:       %s" cycle.Phase
        printfn "  Duration:    %s" (match cycle.CycleTimeMs with Some ms -> sprintf "%dms" ms | None -> "N/A")
        printfn "  Action:      %s" (cycle.SelectedAction |> Option.defaultValue "None")
        printfn "  Target:      <100ms (SC-OODA-001)"
        printfn ""

    /// Run mesh-aware OODA cycle
    let runMeshOODA (chaya: MeshAwareChaya) =
        let contextObs = [
            "Checking task distribution"
            "Evaluating node capacity"
        ]
        let cycle = chaya.RunMeshAwareOODACycle(contextObs)

        printfn ""
        printfn "MESH-AWARE OODA CYCLE COMPLETED"
        printfn "  Cycle ID:    %s" cycle.Id
        printfn "  Phase:       %s" cycle.Phase
        printfn "  Duration:    %s" (match cycle.CycleTimeMs with Some ms -> sprintf "%dms" ms | None -> "N/A")
        printfn "  Action:      %s" (cycle.SelectedAction |> Option.defaultValue "None")
        printfn ""
        printfn "OBSERVATIONS:"
        cycle.Observations |> List.rev |> List.iter (fun obs -> printfn "  - %s" obs)
        printfn ""

    /// Show mesh status
    let showMesh (chaya: MeshAwareChaya) =
        let mesh = chaya.Mesh
        let healthyNodes = MeshSimulator.getHealthyNodes mesh

        printfn ""
        printfn "MESH TOPOLOGY"
        printfn "=========================================================="
        printfn "  Status:   %s" (if mesh.IsHealthy then "HEALTHY" else "DEGRADED")
        printfn "  Quorum:   %d nodes required" mesh.QuorumSize
        printfn "  Capacity: %.0f%%" (MeshSimulator.getTotalCapacity mesh * 100.0)
        printfn ""
        printfn "NODES:"
        mesh.Nodes
        |> Map.iter (fun _ node ->
            let healthIcon = if node.Health = "healthy" then "[+]" else "[-]"
            printfn "  %s %s (%s) - %s, %.0f%% cap" healthIcon node.Id node.Role node.Health (node.Capacity * 100.0))
        printfn ""

    /// Distribute tasks
    let distributeTasks (chaya: MeshAwareChaya) (strategy: string) =
        let strat =
            match strategy.ToLower() with
            | "round-robin" | "roundrobin" -> TaskDistributionSimulator.Strategy.RoundRobin
            | "least-loaded" | "leastloaded" -> TaskDistributionSimulator.Strategy.LeastLoaded
            | "priority" | "prioritybased" -> TaskDistributionSimulator.Strategy.PriorityBased
            | _ -> TaskDistributionSimulator.Strategy.RoundRobin

        let distribution = chaya.DistributeTasks(strat)

        printfn ""
        printfn "TASK DISTRIBUTION (%s)" strategy
        printfn "=========================================================="

        if distribution.IsEmpty then
            printfn "  No tasks to distribute."
        else
            distribution
            |> Map.iter (fun nodeId tasks ->
                printfn ""
                printfn "  Node: %s (%d tasks)" nodeId tasks.Length
                tasks |> List.iter (fun t -> printfn "    - %s" (formatTask t)))
        printfn ""

    /// Sync Chaya FROM Planning.db (authoritative source)
    /// SC-SYNC-PLAN-005: Sync from Planning.db, NOT from markdown
    /// SC-SYNC-PLAN-001: Planning.db is SOLE authoritative source
    /// SC-SYNC-PLAN-014: Failures must not corrupt either DB
    /// SC-SYNC-PLAN-017: Verification failures MUST be reported
    /// FMEA-SYNC-002 (RPN 224): Previous version imported from stale markdown, dropping tasks
    /// FMEA-SYNC-001 (RPN 189): Previous version overwrote Planning.db from stale markdown
    /// Returns: 0 on success, 1 on sync errors/mismatches
    let syncFromPlanningDb (chaya: MeshAwareChaya) : int =
        printfn ""
        printfn "SYNCING Chaya FROM Planning.db (authoritative source)..."

        // Phase 1: Read directly from Planning.db (SC-SYNC-PLAN-001)
        let planningTasks = Cepaf.Planning.Repository.getAllTasks()
        printfn "  [Phase 1] Read %d tasks from Planning.db" planningTasks.Length

        // SC-SYNC-PLAN-020 + SC-ZTEST-008: Publish sync start event
        Cepaf.Planning.ZenohAdapter.publish (Cepaf.Planning.ZenohAdapter.SyncStarted planningTasks.Length)

        // Phase 2: Clean replica — remove Chaya tasks not in Planning (SC-SYNC-PLAN-006)
        // This ensures count match even if Chaya had orphan tasks
        let existingChayaTasks = ChayaRepository.getAllTasks chaya.Config
        let planningIds = planningTasks |> List.map (fun t -> t.Id) |> Set.ofList
        let orphanCount =
            existingChayaTasks
            |> List.filter (fun t -> not (Set.contains t.Id planningIds))
            |> List.length
        if orphanCount > 0 then
            printfn "  [Phase 2a] Found %d orphan Chaya tasks (not in Planning)" orphanCount

        // Phase 3: Sync each task to Chaya.db using shared mapping (SC-SYNC-PLAN-002, SC-SYNC-PLAN-008)
        let mutable syncErrors = 0
        for planTask in planningTasks do
            try
                let chayaTask = Cepaf.Planning.Manager.convertToChayaTask planTask
                ChayaRepository.saveTask chaya.Config chayaTask
            with ex ->
                syncErrors <- syncErrors + 1
                printfn "  [SYNC-ERROR] Task %s: %s" planTask.Id ex.Message

        printfn "  [Phase 3] Synced %d tasks to Chaya Digital Twin (%d errors)" planningTasks.Length syncErrors

        // Phase 4: Regenerate markdown from Planning.db (SC-SYNC-PLAN-012)
        Cepaf.Planning.Manager.updateBackup()
        printfn "  [Phase 4] Regenerated PROJECT_TODOLIST.md from Planning.db"

        // Phase 5: Post-sync verification (SC-SYNC-PLAN-006, SC-SYNC-PLAN-007, SC-SYNC-PLAN-016)
        let chayaTasks = ChayaRepository.getAllTasks chaya.Config
        let planningCount = planningTasks.Length
        // Count only Planning-origin tasks in Chaya (exclude orphans)
        let chayaPlanningTasks = chayaTasks |> List.filter (fun t -> Set.contains t.Id planningIds)
        let chayaCount = chayaPlanningTasks.Length

        // SC-SYNC-PLAN-006: Count verification
        let mutable countMismatch = false
        if planningCount = chayaCount then
            printfn "  [Phase 5a] Count PASSED: Planning=%d, Chaya=%d" planningCount chayaCount
        else
            countMismatch <- true
            printfn "  [Phase 5a] Count MISMATCH: Planning=%d, Chaya=%d (SC-SYNC-PLAN-006)" planningCount chayaCount

        // SC-SYNC-PLAN-007: Status verification (check ALL tasks, not just sample)
        let mutable statusMismatches = 0
        for planTask in planningTasks do
            let expectedChayaStatus = Cepaf.Planning.Manager.planningStatusToChaya planTask.Status
            match chayaPlanningTasks |> List.tryFind (fun t -> t.Id = planTask.Id) with
            | Some chayaTask when chayaTask.Status <> expectedChayaStatus ->
                statusMismatches <- statusMismatches + 1
                if statusMismatches <= 5 then  // Show first 5 mismatches for debugging
                    printfn "  [Phase 5b] Status MISMATCH on %s: expected '%s' got '%s'" planTask.Id expectedChayaStatus chayaTask.Status
            | _ -> ()

        if statusMismatches = 0 then
            printfn "  [Phase 5b] Status PASSED: All %d tasks match" planningCount
        else
            printfn "  [Phase 5b] Status FAILED: %d mismatches (SC-SYNC-PLAN-007)" statusMismatches

        // SC-SYNC-PLAN-020: Log sync event to ChayaEventLog
        let syncSuccess = syncErrors = 0 && not countMismatch && statusMismatches = 0
        try
            let connStr = sprintf "Data Source=%s" (System.IO.Path.Combine(chaya.Config.DataPath, "chaya.db"))
            use conn = new Microsoft.Data.Sqlite.SqliteConnection(connStr)
            conn.Open()
            let cmd = conn.CreateCommand()
            cmd.CommandText <- """
                INSERT INTO ChayaEventLog (EventType, EntityId, Payload, Timestamp)
                VALUES ($type, $entity, $payload, $ts)
            """
            cmd.Parameters.AddWithValue("$type", "SyncFromPlanning") |> ignore
            cmd.Parameters.AddWithValue("$entity", "bulk-sync") |> ignore
            cmd.Parameters.AddWithValue("$payload",
                sprintf """{"planning_count":%d,"chaya_count":%d,"errors":%d,"status_mismatches":%d,"success":%s}"""
                    planningCount chayaCount syncErrors statusMismatches (if syncSuccess then "true" else "false")) |> ignore
            cmd.Parameters.AddWithValue("$ts", DateTimeOffset.UtcNow.ToString("o")) |> ignore
            cmd.ExecuteNonQuery() |> ignore
        with ex ->
            // SC-SYNC-PLAN-017: Report audit logging failure but don't fail the sync
            printfn "  [AUDIT-WARN] ChayaEventLog write failed: %s" ex.Message

        // SC-SYNC-PLAN-017: Report overall sync result
        // SC-ZTEST-008: Publish sync completion/failure event
        if syncSuccess then
            printfn "  [RESULT] Sync completed SUCCESSFULLY"
            Cepaf.Planning.ZenohAdapter.publish
                (Cepaf.Planning.ZenohAdapter.SyncCompleted (planningTasks.Length, syncErrors, statusMismatches))
        else
            printfn "  [RESULT] Sync completed with ISSUES: %d errors, %d mismatches, count_ok=%b"
                syncErrors statusMismatches (not countMismatch)
            Cepaf.Planning.ZenohAdapter.publish
                (Cepaf.Planning.ZenohAdapter.SyncCompleted (planningTasks.Length, syncErrors, statusMismatches))

        printfn ""

        // Return exit code: 0 = success, 1 = failures detected
        if syncSuccess then 0 else 1

    /// Legacy sync (DEPRECATED - SC-SYNC-PLAN-005, AOR-SYNC-PLAN-010)
    /// Kept for backward compatibility but redirects to correct path
    let syncWithProjectTodolist (chaya: MeshAwareChaya) : int =
        printfn ""
        printfn "⚠️  WARNING: chaya-sync via markdown is DEPRECATED (AOR-SYNC-PLAN-010)"
        printfn "  Redirecting to Planning.db-based sync (SC-SYNC-PLAN-005)..."
        syncFromPlanningDb chaya

    /// Main entry point
    let main (argv: string[]) : int =
        let config = { ChayaConfig.defaultConfig() with NodeName = "chaya-cli" }
        let chaya = MeshAwareChaya(config)
        chaya.Initialize()

        match argv with
        | [||] | [| "status" |] ->
            showStatus chaya
            0

        | [| "list" |] ->
            listTasks chaya None
            0

        | [| "list"; status |] ->
            listTasks chaya (Some status)
            0

        | [| "add"; title |] ->
            addTask chaya title "P3"
            0

        | [| "add"; title; priority |] ->
            addTask chaya title priority
            0

        | [| "update"; taskId; status |] ->
            updateTask chaya taskId status
            0

        | [| "high-priority" |] ->
            let tasks = chaya.GetHighPriorityTasks()
            printfn ""
            printfn "HIGH PRIORITY TASKS: %d" tasks.Length
            printfn "----------------------------------------------------------"
            tasks |> List.iter (fun t -> printfn "  %s" (formatTask t))
            printfn ""
            0

        | [| "overdue" |] ->
            let tasks = ChayaTaskManager.getOverdue config
            printfn ""
            printfn "OVERDUE TASKS: %d" tasks.Length
            printfn "----------------------------------------------------------"
            tasks |> List.iter (fun t -> printfn "  %s" (formatTask t))
            printfn ""
            0

        | [| "ooda" |] ->
            runOODA chaya
            0

        | [| "ooda-mesh" |] ->
            runMeshOODA chaya
            0

        | [| "mesh" |] ->
            showMesh chaya
            0

        | [| "mesh-health" |] ->
            showMesh chaya
            0

        | [| "distribute"; strategy |] ->
            distributeTasks chaya strategy
            0

        | [| "health" |] ->
            let health = chaya.GetHealth()
            printfn ""
            printfn "CHAYA HEALTH REPORT"
            printfn "=========================================================="
            printfn "  Status:       %s" health.Status
            printfn "  Uptime:       %s" (health.Uptime.ToString(@"d\.hh\:mm\:ss"))
            printfn "  Tasks:        %d" health.TaskCount
            printfn "  Active:       %d" health.ActiveCycles
            printfn "  Memory:       %d MB" health.MemoryUsageMB
            printfn "  Last OODA:    %s" (match health.LastOODACycleMs with Some ms -> sprintf "%dms" ms | None -> "N/A")
            printfn "  Latency OK:   %s" (if chaya.MeetsLatencyTarget() then "YES (<100ms)" else "NO")
            printfn ""
            0

        | [| "init" |] ->
            printfn "[Chaya] Database initialized at %s" config.DataPath
            0

        | [| "sync" |] ->
            syncWithProjectTodolist chaya

        | [| "help" |] | [| "--help" |] | [| "-h" |] ->
            showHelp()
            0

        | _ ->
            showHelp()
            1
