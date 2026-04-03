// =============================================================================
// StandaloneChaya.fs - Fully Independent Digital Twin with Planning Capabilities
// =============================================================================
// STAMP: SC-CHAYA-001, SC-HOLON-001, SC-OODA-001
// AOR: AOR-CHAYA-001, AOR-HOLON-001
// Criticality: Level 4 (REQUIRED) - Standalone Operation
// =============================================================================
// Chaya runs INDEPENDENTLY of the rest of the system with:
// - Self-contained SQLite persistence (holon sovereignty)
// - Full task management capabilities
// - OODA cycle execution engine
// - Task distribution and mesh simulation
// - Local health monitoring
// =============================================================================

namespace Cepaf.Planning.Chaya

open System
open System.IO
open Microsoft.Data.Sqlite
open Cepaf.Planning.Core
open Cepaf.Planning.Core.Ids
open Cepaf.Planning.Domain

/// Chaya configuration for standalone operation
type ChayaConfig = {
    DataPath: string                // Base path for SQLite/DuckDB files
    NodeId: string                  // This node's identifier
    NodeName: string                // Human-readable name
    MaxConcurrentTasks: int         // Maximum concurrent tasks
    OODACycleTargetMs: int64        // Target OODA cycle time (SC-OODA-001: <100ms)
    EnableTelemetry: bool           // Whether to publish telemetry
}

module ChayaConfig =
    /// Default configuration for standalone operation
    let defaultConfig () = {
        DataPath = "data/chaya"
        NodeId = Guid.NewGuid().ToString("N").Substring(0, 8)
        NodeName = "chaya-standalone"
        MaxConcurrentTasks = 10
        OODACycleTargetMs = 100L
        EnableTelemetry = false
    }

/// Internal task representation for Chaya
type ChayaTask = {
    Id: string
    Title: string
    Description: string option
    Status: string
    Priority: string
    CreatedAt: DateTimeOffset
    UpdatedAt: DateTimeOffset
    DueDate: DateTimeOffset option
    AssignedNode: string option
    EstimatedMinutes: int option
    Tags: string list
}

/// OODA cycle state for Chaya
type ChayaOODACycle = {
    Id: string
    Phase: string
    StartedAt: DateTimeOffset
    CompletedAt: DateTimeOffset option
    Observations: string list
    SelectedAction: string option
    CycleTimeMs: int64 option
}

/// Health status of Chaya
type ChayaHealth = {
    Status: string
    Uptime: TimeSpan
    TaskCount: int
    ActiveCycles: int
    LastOODACycleMs: int64 option
    MemoryUsageMB: int64
    LastCheck: DateTimeOffset
}

/// Standalone Chaya repository (SQLite-based, holon sovereign)
module ChayaRepository =

    let private getConnectionString (config: ChayaConfig) =
        let dbPath = Path.Combine(config.DataPath, "chaya.db")
        sprintf "Data Source=%s"  dbPath

    /// Ensure database and schema exist
    let ensureDatabase (config: ChayaConfig) =
        // Create data directory
        if not (Directory.Exists(config.DataPath)) then
            Directory.CreateDirectory(config.DataPath) |> ignore

        let connStr = getConnectionString config
        use conn = new SqliteConnection(connStr)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            -- Tasks table (holon-sovereign state)
            CREATE TABLE IF NOT EXISTS ChayaTasks (
                Id TEXT PRIMARY KEY,
                Title TEXT NOT NULL,
                Description TEXT,
                Status TEXT NOT NULL DEFAULT 'todo',
                Priority TEXT NOT NULL DEFAULT 'P3',
                CreatedAt TEXT NOT NULL,
                UpdatedAt TEXT NOT NULL,
                DueDate TEXT,
                AssignedNode TEXT,
                EstimatedMinutes INTEGER,
                Tags TEXT
            );

            -- OODA cycles table
            CREATE TABLE IF NOT EXISTS ChayaOODACycles (
                Id TEXT PRIMARY KEY,
                Phase TEXT NOT NULL,
                StartedAt TEXT NOT NULL,
                CompletedAt TEXT,
                Observations TEXT,
                SelectedAction TEXT,
                CycleTimeMs INTEGER
            );

            -- Event log for immutable history
            CREATE TABLE IF NOT EXISTS ChayaEventLog (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                EventType TEXT NOT NULL,
                EntityId TEXT NOT NULL,
                Payload TEXT NOT NULL,
                Timestamp TEXT NOT NULL
            );

            -- Health snapshots
            CREATE TABLE IF NOT EXISTS ChayaHealthSnapshots (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                Status TEXT NOT NULL,
                TaskCount INTEGER NOT NULL,
                ActiveCycles INTEGER NOT NULL,
                MemoryUsageMB INTEGER NOT NULL,
                Timestamp TEXT NOT NULL
            );

            -- Indexes for performance
            CREATE INDEX IF NOT EXISTS idx_tasks_status ON ChayaTasks(Status);
            CREATE INDEX IF NOT EXISTS idx_tasks_priority ON ChayaTasks(Priority);
            CREATE INDEX IF NOT EXISTS idx_cycles_phase ON ChayaOODACycles(Phase);
            CREATE INDEX IF NOT EXISTS idx_events_entity ON ChayaEventLog(EntityId);
        """
        cmd.ExecuteNonQuery() |> ignore
        printfn "[Chaya] Database initialized at %s" config.DataPath

    /// Save a task
    let saveTask (config: ChayaConfig) (task: ChayaTask) =
        let connStr = getConnectionString config
        use conn = new SqliteConnection(connStr)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO ChayaTasks
            (Id, Title, Description, Status, Priority, CreatedAt, UpdatedAt, DueDate, AssignedNode, EstimatedMinutes, Tags)
            VALUES ($id, $title, $desc, $status, $priority, $created, $updated, $due, $node, $est, $tags)
        """
        cmd.Parameters.AddWithValue("$id", task.Id) |> ignore
        cmd.Parameters.AddWithValue("$title", task.Title) |> ignore
        cmd.Parameters.AddWithValue("$desc", task.Description |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("$status", task.Status) |> ignore
        cmd.Parameters.AddWithValue("$priority", task.Priority) |> ignore
        cmd.Parameters.AddWithValue("$created", task.CreatedAt.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("$updated", task.UpdatedAt.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("$due", task.DueDate |> Option.map (fun d -> d.ToString("o")) |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("$node", task.AssignedNode |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("$est", task.EstimatedMinutes |> Option.defaultValue 0) |> ignore
        cmd.Parameters.AddWithValue("$tags", String.Join(",", task.Tags)) |> ignore
        cmd.ExecuteNonQuery() |> ignore

        // Log event
        let evtCmd = conn.CreateCommand()
        evtCmd.CommandText <- """
            INSERT INTO ChayaEventLog (EventType, EntityId, Payload, Timestamp)
            VALUES ($type, $entity, $payload, $ts)
        """
        evtCmd.Parameters.AddWithValue("$type", "TaskSaved") |> ignore
        evtCmd.Parameters.AddWithValue("$entity", task.Id) |> ignore
        evtCmd.Parameters.AddWithValue("$payload", sprintf """{"title":"%s","status":"%s"}""" task.Title task.Status) |> ignore
        evtCmd.Parameters.AddWithValue("$ts", DateTimeOffset.UtcNow.ToString("o")) |> ignore
        evtCmd.ExecuteNonQuery() |> ignore

    /// Get all tasks
    let getAllTasks (config: ChayaConfig) : ChayaTask list =
        let connStr = getConnectionString config
        use conn = new SqliteConnection(connStr)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- "SELECT * FROM ChayaTasks ORDER BY Priority, CreatedAt"
        use reader = cmd.ExecuteReader()

        let mutable tasks = []
        while reader.Read() do
            let task = {
                Id = reader.GetString(0)
                Title = reader.GetString(1)
                Description = let v = reader.GetString(2) in if String.IsNullOrEmpty(v) then None else Some v
                Status = reader.GetString(3)
                Priority = reader.GetString(4)
                CreatedAt = DateTimeOffset.Parse(reader.GetString(5))
                UpdatedAt = DateTimeOffset.Parse(reader.GetString(6))
                DueDate = let v = reader.GetString(7) in if String.IsNullOrEmpty(v) then None else Some (DateTimeOffset.Parse(v))
                AssignedNode = let v = reader.GetString(8) in if String.IsNullOrEmpty(v) then None else Some v
                EstimatedMinutes = let v = reader.GetInt32(9) in if v = 0 then None else Some v
                Tags = let v = reader.GetString(10) in if String.IsNullOrEmpty(v) then [] else v.Split(',') |> Array.toList
            }
            tasks <- task :: tasks
        tasks |> List.rev

    /// Get task by ID
    let getTask (config: ChayaConfig) (id: string) : ChayaTask option =
        getAllTasks config |> List.tryFind (fun t -> t.Id = id)

    /// Save OODA cycle
    let saveOODACycle (config: ChayaConfig) (cycle: ChayaOODACycle) =
        let connStr = getConnectionString config
        use conn = new SqliteConnection(connStr)
        conn.Open()

        let cmd = conn.CreateCommand()
        cmd.CommandText <- """
            INSERT OR REPLACE INTO ChayaOODACycles
            (Id, Phase, StartedAt, CompletedAt, Observations, SelectedAction, CycleTimeMs)
            VALUES ($id, $phase, $started, $completed, $obs, $action, $time)
        """
        cmd.Parameters.AddWithValue("$id", cycle.Id) |> ignore
        cmd.Parameters.AddWithValue("$phase", cycle.Phase) |> ignore
        cmd.Parameters.AddWithValue("$started", cycle.StartedAt.ToString("o")) |> ignore
        cmd.Parameters.AddWithValue("$completed", cycle.CompletedAt |> Option.map (fun d -> d.ToString("o")) |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("$obs", String.Join("|", cycle.Observations)) |> ignore
        cmd.Parameters.AddWithValue("$action", cycle.SelectedAction |> Option.defaultValue "") |> ignore
        cmd.Parameters.AddWithValue("$time", cycle.CycleTimeMs |> Option.defaultValue 0L) |> ignore
        cmd.ExecuteNonQuery() |> ignore

/// Standalone OODA engine for Chaya
module ChayaOODAEngine =

    /// Start a new OODA cycle
    let startCycle (context: string) : ChayaOODACycle =
        {
            Id = Guid.NewGuid().ToString("N").Substring(0, 12)
            Phase = "OBSERVE"
            StartedAt = DateTimeOffset.UtcNow
            CompletedAt = None
            Observations = []
            SelectedAction = None
            CycleTimeMs = None
        }

    /// Add observation to cycle
    let observe (observation: string) (cycle: ChayaOODACycle) : ChayaOODACycle =
        { cycle with Observations = observation :: cycle.Observations }

    /// Move to Orient phase with analysis
    let orient (cycle: ChayaOODACycle) : ChayaOODACycle =
        { cycle with Phase = "ORIENT" }

    /// Move to Decide phase
    let decide (action: string) (cycle: ChayaOODACycle) : ChayaOODACycle =
        { cycle with Phase = "DECIDE"; SelectedAction = Some action }

    /// Move to Act phase
    let act (cycle: ChayaOODACycle) : ChayaOODACycle =
        { cycle with Phase = "ACT" }

    /// Complete the cycle
    let complete (cycle: ChayaOODACycle) : ChayaOODACycle =
        let now = DateTimeOffset.UtcNow
        let cycleTime = (now - cycle.StartedAt).TotalMilliseconds |> int64
        { cycle with
            Phase = "COMPLETE"
            CompletedAt = Some now
            CycleTimeMs = Some cycleTime }

    /// Run a fast OODA cycle (SC-OODA-001: <100ms target)
    let runFastCycle (config: ChayaConfig) (observations: string list) (selectAction: string list -> string) : ChayaOODACycle =
        let cycle =
            startCycle "fast-cycle"
            |> fun c -> observations |> List.fold (fun acc obs -> observe obs acc) c
            |> orient
            |> fun c -> decide (selectAction observations) c
            |> act
            |> complete

        // Persist cycle
        ChayaRepository.saveOODACycle config cycle
        cycle

/// Task management for standalone Chaya
module ChayaTaskManager =

    /// Create a new task
    let createTask (config: ChayaConfig) (title: string) (priority: string) (description: string option) : ChayaTask =
        let now = DateTimeOffset.UtcNow
        let task = {
            Id = Guid.NewGuid().ToString("N").Substring(0, 8)
            Title = title
            Description = description
            Status = "todo"
            Priority = priority
            CreatedAt = now
            UpdatedAt = now
            DueDate = None
            AssignedNode = Some config.NodeId
            EstimatedMinutes = None
            Tags = []
        }
        ChayaRepository.saveTask config task
        task

    /// Update task status
    let updateStatus (config: ChayaConfig) (taskId: string) (newStatus: string) : Result<ChayaTask, string> =
        match ChayaRepository.getTask config taskId with
        | Some task ->
            let updated = { task with Status = newStatus; UpdatedAt = DateTimeOffset.UtcNow }
            ChayaRepository.saveTask config updated
            Ok updated
        | None -> Error (sprintf "Task %s not found" taskId)

    /// Get tasks by status
    let getByStatus (config: ChayaConfig) (status: string) : ChayaTask list =
        ChayaRepository.getAllTasks config
        |> List.filter (fun t -> t.Status = status)

    /// Get high priority tasks
    let getHighPriority (config: ChayaConfig) : ChayaTask list =
        ChayaRepository.getAllTasks config
        |> List.filter (fun t -> t.Priority = "P0" || t.Priority = "P1")

    /// Get overdue tasks
    let getOverdue (config: ChayaConfig) : ChayaTask list =
        let now = DateTimeOffset.UtcNow
        ChayaRepository.getAllTasks config
        |> List.filter (fun t ->
            match t.DueDate with
            | Some due -> due < now && t.Status <> "done"
            | None -> false)

/// Health monitoring for standalone Chaya
module ChayaHealthMonitor =

    let private startTime = DateTimeOffset.UtcNow
    let mutable private lastCycleTime: int64 option = None

    /// Update last cycle time
    let recordCycleTime (ms: int64) =
        lastCycleTime <- Some ms

    /// Get current health status
    let getHealth (config: ChayaConfig) : ChayaHealth =
        let tasks = ChayaRepository.getAllTasks config
        let activeTasks = tasks |> List.filter (fun t -> t.Status = "in_progress")

        {
            Status = "healthy"
            Uptime = DateTimeOffset.UtcNow - startTime
            TaskCount = tasks.Length
            ActiveCycles = activeTasks.Length
            LastOODACycleMs = lastCycleTime
            MemoryUsageMB = GC.GetTotalMemory(false) / (1024L * 1024L)
            LastCheck = DateTimeOffset.UtcNow
        }

    /// Check if OODA cycles meet latency target
    let meetsLatencyTarget (config: ChayaConfig) : bool =
        match lastCycleTime with
        | Some ms -> ms <= config.OODACycleTargetMs
        | None -> true

/// Main standalone Chaya runtime
type StandaloneChaya(config: ChayaConfig) =
    let mutable isRunning = false

    /// Initialize Chaya
    member _.Initialize() =
        printfn "[Chaya] Initializing standalone instance: %s (%s)" config.NodeName config.NodeId
        ChayaRepository.ensureDatabase config
        isRunning <- true
        printfn "[Chaya] Ready for standalone operation"

    /// Get current configuration
    member _.Config = config

    /// Check if running
    member _.IsRunning = isRunning

    /// Create a task
    member _.CreateTask(title, priority, ?description) =
        ChayaTaskManager.createTask config title priority description

    /// Update task status
    member _.UpdateTaskStatus(taskId, status) =
        ChayaTaskManager.updateStatus config taskId status

    /// Get all tasks
    member _.GetAllTasks() =
        ChayaRepository.getAllTasks config

    /// Get tasks by status
    member _.GetTasksByStatus(status) =
        ChayaTaskManager.getByStatus config status

    /// Get high priority tasks
    member _.GetHighPriorityTasks() =
        ChayaTaskManager.getHighPriority config

    /// Run OODA cycle
    member _.RunOODACycle(observations: string list, selectAction: string list -> string) =
        let cycle = ChayaOODAEngine.runFastCycle config observations selectAction
        cycle.CycleTimeMs |> Option.iter ChayaHealthMonitor.recordCycleTime
        cycle

    /// Get health status
    member _.GetHealth() =
        ChayaHealthMonitor.getHealth config

    /// Check latency compliance
    member _.MeetsLatencyTarget() =
        ChayaHealthMonitor.meetsLatencyTarget config

    /// Shutdown
    member _.Shutdown() =
        printfn "[Chaya] Shutting down %s" config.NodeName
        isRunning <- false

/// Factory for creating standalone Chaya instances
module ChayaFactory =

    /// Create with default configuration
    let createDefault () =
        let chaya = StandaloneChaya(ChayaConfig.defaultConfig())
        chaya.Initialize()
        chaya

    /// Create with custom configuration
    let create (config: ChayaConfig) =
        let chaya = StandaloneChaya(config)
        chaya.Initialize()
        chaya

    /// Create for testing (in-memory style)
    let createForTesting (testId: string) =
        let config = {
            ChayaConfig.defaultConfig() with
                DataPath = sprintf "data/chaya-test-%s" testId
                NodeId = sprintf "test-%s" testId
                NodeName = sprintf "chaya-test-%s" testId
        }
        create config
