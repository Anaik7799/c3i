/// CEPAF Concurrent Cockpit Module
/// STM-based concurrent state management for lock-free cockpit updates.
///
/// WHAT: Software Transactional Memory, Actors, Concurrent collections
/// WHY: Handle concurrent telemetry updates without locks or race conditions
/// CONSTRAINTS:
///   - SC-STM-001: Transactions must be atomic and isolated
///   - SC-STM-002: Retry on conflict, no deadlocks
///   - SC-STM-003: State must be consistent after every transaction
///   - SC-STM-004: Actors must process messages in order
///
/// STAMP Compliance: SC-STM-001 to SC-STM-008
/// Version: 1.0.0
namespace Cepaf.Cockpit

open System
open System.Threading
open Cepaf.Cockpit.Domain

// ============================================================================
// TRANSACTIONAL VARIABLE (TVar)
// ============================================================================

/// Version-tracked transactional variable
type TVar<'T> = {
    mutable Value: 'T
    Lock: obj
    mutable Version: int
    Id: int
}

module TVar =
    /// Counter for unique TVar IDs
    let private tvarIdCounter = ref 0

    /// Create new transactional variable
    let create (initial: 'T) : TVar<'T> =
        let id = Interlocked.Increment(tvarIdCounter)
        { Value = initial; Lock = obj(); Version = 0; Id = id }

    /// Read value (outside transaction)
    let read (tvar: TVar<'T>) : 'T =
        lock tvar.Lock (fun () -> tvar.Value)

    /// Write value (outside transaction) - NOT recommended, use STM
    let write (value: 'T) (tvar: TVar<'T>) : unit =
        lock tvar.Lock (fun () ->
            tvar.Value <- value
            tvar.Version <- tvar.Version + 1
        )

    /// Modify value atomically (outside transaction)
    let modify (f: 'T -> 'T) (tvar: TVar<'T>) : unit =
        lock tvar.Lock (fun () ->
            tvar.Value <- f tvar.Value
            tvar.Version <- tvar.Version + 1
        )

// ============================================================================
// STM TRANSACTION LOG
// ============================================================================

/// Transaction log entry
type TLogEntry = {
    TVar: obj  // Boxed TVar
    TVarId: int
    ReadVersion: int
    NewValue: obj option  // None = read only, Some = write
}

/// STM monad - composable transactions
type STM<'A> = STM of (Map<int, TLogEntry> -> STMResult<'A> * Map<int, TLogEntry>)

and STMResult<'A> =
    | Success of 'A
    | Retry  // Conflict detected, retry transaction
    | Abort of exn

module STM =
    /// Return pure value
    let pure' (x: 'A) : STM<'A> =
        STM (fun log -> (Success x, log))

    /// Bind (flatMap)
    let bind (f: 'A -> STM<'B>) (STM ma) : STM<'B> =
        STM (fun log ->
            match ma log with
            | (Success a, log') ->
                let (STM mb) = f a
                mb log'
            | (Retry, log') -> (Retry, log')
            | (Abort ex, log') -> (Abort ex, log')
        )

    /// Map
    let map (f: 'A -> 'B) (m: STM<'A>) : STM<'B> =
        bind (f >> pure') m

    /// Read TVar in transaction
    let readTVar (tvar: TVar<'T>) : STM<'T> =
        STM (fun log ->
            match Map.tryFind tvar.Id log with
            | Some entry ->
                // Already in log, return logged value
                match entry.NewValue with
                | Some v -> (Success (unbox v), log)
                | None -> (Success (unbox entry.TVar), log)
            | None ->
                // First access, record in log
                let value = lock tvar.Lock (fun () -> tvar.Value)
                let version = lock tvar.Lock (fun () -> tvar.Version)
                let entry = { TVar = box tvar; TVarId = tvar.Id; ReadVersion = version; NewValue = None }
                (Success value, Map.add tvar.Id entry log)
        )

    /// Write TVar in transaction
    let writeTVar (value: 'T) (tvar: TVar<'T>) : STM<unit> =
        STM (fun log ->
            match Map.tryFind tvar.Id log with
            | Some entry ->
                // Update existing entry
                let entry' = { entry with NewValue = Some (box value) }
                (Success (), Map.add tvar.Id entry' log)
            | None ->
                // First access
                let version = lock tvar.Lock (fun () -> tvar.Version)
                let entry = { TVar = box tvar; TVarId = tvar.Id; ReadVersion = version; NewValue = Some (box value) }
                (Success (), Map.add tvar.Id entry log)
        )

    /// Modify TVar in transaction
    let modifyTVar (f: 'T -> 'T) (tvar: TVar<'T>) : STM<unit> =
        bind (fun v -> writeTVar (f v) tvar) (readTVar tvar)

    /// Retry transaction (will wait for changes)
    let retry<'A> : STM<'A> =
        STM (fun log -> (Retry, log))

    /// Or else - try first, if retry then try second
    let orElse (STM m1) (STM m2) : STM<'A> =
        STM (fun log ->
            match m1 log with
            | (Retry, _) -> m2 log
            | result -> result
        )

    /// Run transaction atomically
    let atomically (STM m) : 'A =
        let maxRetries = 1000
        let rec go retries =
            if retries >= maxRetries then
                failwith "STM: max retries exceeded"

            // Execute transaction
            let (result, log) = m Map.empty

            match result with
            | Abort ex -> raise ex
            | Retry ->
                Thread.Sleep(1)  // Brief pause before retry
                go (retries + 1)
            | Success a ->
                // Validate and commit
                let valid = validateLog log
                if valid then
                    commitLog log
                    a
                else
                    go (retries + 1)

        and validateLog log =
            // Check all read versions still match
            log
            |> Map.forall (fun _ entry ->
                let tvar = entry.TVar
                let currentVersion =
                    // Get version based on actual type
                    let t = tvar.GetType()
                    if t.IsGenericType then
                        let versionField = t.GetField("Version@")
                        if versionField <> null then
                            unbox<int> (versionField.GetValue(tvar))
                        else entry.ReadVersion
                    else entry.ReadVersion
                currentVersion = entry.ReadVersion
            )

        and commitLog log =
            // Acquire all locks in order to prevent deadlock
            let sortedEntries = log |> Map.toList |> List.sortBy fst
            let locks = sortedEntries |> List.map (fun (_, e) ->
                let t = e.TVar.GetType()
                if t.IsGenericType then
                    let lockField = t.GetField("Lock@")
                    if lockField <> null then lockField.GetValue(e.TVar) else obj()
                else obj()
            )

            // Lock all
            let rec lockAll = function
                | [] -> ()
                | l :: ls ->
                    Monitor.Enter(l)
                    lockAll ls

            let rec unlockAll = function
                | [] -> ()
                | l :: ls ->
                    Monitor.Exit(l)
                    unlockAll ls

            try
                lockAll locks

                // Write all changes
                for (_, entry) in sortedEntries do
                    match entry.NewValue with
                    | None -> ()  // Read only
                    | Some newVal ->
                        let t = entry.TVar.GetType()
                        if t.IsGenericType then
                            let valueField = t.GetField("Value@")
                            let versionField = t.GetField("Version@")
                            if valueField <> null && versionField <> null then
                                valueField.SetValue(entry.TVar, newVal)
                                let oldVersion = unbox<int> (versionField.GetValue(entry.TVar))
                                versionField.SetValue(entry.TVar, oldVersion + 1)
            finally
                unlockAll (List.rev locks)

        go 0

/// STM computation expression builder
type STMBuilder() =
    member _.Return(x) = STM.pure' x
    member _.ReturnFrom(m) = m
    member _.Bind(m, f) = STM.bind f m
    member _.Zero() = STM.pure' ()
    member _.Combine(m1, m2) = STM.bind (fun () -> m2) m1
    member _.Delay(f) = f ()

module STMComputation =
    let stm = STMBuilder()

// ============================================================================
// COCKPIT STATE TVARS
// ============================================================================

/// Concurrent cockpit state using TVars
type ConcurrentCockpitState = {
    Nodes: TVar<Map<NodeId, MeshNode>>
    Alarms: TVar<Map<AlarmId, Alarm>>
    PendingCommands: TVar<Map<CommandId, CommandRecord>>
    Insights: TVar<AiInsight list>
    MessageCount: TVar<int64>
    LastUpdate: TVar<DateTime option>
    CurrentView: TVar<ViewMode>
    SelectedNode: TVar<NodeId option>
    Federation: TVar<FederationHealth option>
}

module ConcurrentCockpit =
    open STMComputation

    /// Create new concurrent cockpit state
    let create () : ConcurrentCockpitState =
        {
            Nodes = TVar.create Map.empty
            Alarms = TVar.create Map.empty
            PendingCommands = TVar.create Map.empty
            Insights = TVar.create []
            MessageCount = TVar.create 0L
            LastUpdate = TVar.create None
            CurrentView = TVar.create Dashboard
            SelectedNode = TVar.create None
            Federation = TVar.create None
        }

    /// Update node atomically
    let updateNode (nodeId: NodeId) (node: MeshNode) (state: ConcurrentCockpitState) : unit =
        STM.atomically (stm {
            let! nodes = STM.readTVar state.Nodes
            do! STM.writeTVar (Map.add nodeId node nodes) state.Nodes
            let! count = STM.readTVar state.MessageCount
            do! STM.writeTVar (count + 1L) state.MessageCount
            do! STM.writeTVar (Some DateTime.UtcNow) state.LastUpdate
        })

    /// Update node metrics only (optimistic update)
    let updateNodeMetrics (nodeId: NodeId) (cpu: float) (memory: float) (latency: float) (state: ConcurrentCockpitState) : bool =
        try
            STM.atomically (stm {
                let! nodes = STM.readTVar state.Nodes
                match Map.tryFind nodeId nodes with
                | None -> return false
                | Some node ->
                    let updated = {
                        node with
                            Cpu = updateMetric cpu node.Cpu
                            Memory = updateMetric memory node.Memory
                            NetworkLatency = updateMetric latency node.NetworkLatency
                            Status = Connected
                    }
                    do! STM.writeTVar (Map.add nodeId updated nodes) state.Nodes
                    return true
            })
        with _ -> false

    /// Add alarm atomically
    let addAlarm (alarm: Alarm) (state: ConcurrentCockpitState) : unit =
        STM.atomically (stm {
            let! alarms = STM.readTVar state.Alarms
            do! STM.writeTVar (Map.add alarm.Id alarm alarms) state.Alarms
        })

    /// Acknowledge alarm atomically
    let acknowledgeAlarm (alarmId: AlarmId) (operatorId: string) (state: ConcurrentCockpitState) : bool =
        STM.atomically (stm {
            let! alarms = STM.readTVar state.Alarms
            match Map.tryFind alarmId alarms with
            | None -> return false
            | Some alarm ->
                let updated = { alarm with AcknowledgedAt = Some DateTime.UtcNow; AcknowledgedBy = Some operatorId }
                do! STM.writeTVar (Map.add alarmId updated alarms) state.Alarms
                return true
        })

    /// Update federation health atomically
    let updateFederation (health: FederationHealth) (state: ConcurrentCockpitState) : unit =
        STM.atomically (stm {
            do! STM.writeTVar (Some health) state.Federation
            let! count = STM.readTVar state.MessageCount
            do! STM.writeTVar (count + 1L) state.MessageCount
            do! STM.writeTVar (Some DateTime.UtcNow) state.LastUpdate
        })

    /// Get snapshot of all nodes (read-only)
    let getNodes (state: ConcurrentCockpitState) : Map<NodeId, MeshNode> =
        TVar.read state.Nodes

    /// Get snapshot of alarms
    let getAlarms (state: ConcurrentCockpitState) : Map<AlarmId, Alarm> =
        TVar.read state.Alarms

    /// Batch update multiple nodes (single transaction)
    let batchUpdateNodes (updates: (NodeId * MeshNode) list) (state: ConcurrentCockpitState) : unit =
        STM.atomically (stm {
            let! nodes = STM.readTVar state.Nodes
            let updated = updates |> List.fold (fun m (id, n) -> Map.add id n m) nodes
            do! STM.writeTVar updated state.Nodes
            let! count = STM.readTVar state.MessageCount
            do! STM.writeTVar (count + int64 (List.length updates)) state.MessageCount
        })

// ============================================================================
// ACTOR SYSTEM (SC-STM-004)
// ============================================================================

/// Actor message types
type CockpitActorMsg =
    | UpdateNodeMsg of NodeId * MeshNode
    | UpdateMetricsMsg of NodeId * float * float * float  // cpu, mem, latency
    | AddAlarmMsg of Alarm
    | AckAlarmMsg of AlarmId * string * AsyncReplyChannel<bool>
    | GetNodesMsg of AsyncReplyChannel<Map<NodeId, MeshNode>>
    | GetAlarmsMsg of AsyncReplyChannel<Map<AlarmId, Alarm>>
    | NavigateMsg of ViewMode
    | SelectNodeMsg of NodeId option
    | UpdateFederationMsg of FederationHealth
    | ShutdownMsg

/// Cockpit actor - serializes all state updates
type CockpitActor(state: ConcurrentCockpitState) =
    let agent = MailboxProcessor<CockpitActorMsg>.Start(fun inbox ->
        let rec loop () = async {
            let! msg = inbox.Receive()
            match msg with
            | UpdateNodeMsg (nodeId, node) ->
                ConcurrentCockpit.updateNode nodeId node state
                return! loop ()

            | UpdateMetricsMsg (nodeId, cpu, mem, latency) ->
                ConcurrentCockpit.updateNodeMetrics nodeId cpu mem latency state |> ignore
                return! loop ()

            | AddAlarmMsg alarm ->
                ConcurrentCockpit.addAlarm alarm state
                return! loop ()

            | AckAlarmMsg (alarmId, operatorId, reply) ->
                let result = ConcurrentCockpit.acknowledgeAlarm alarmId operatorId state
                reply.Reply(result)
                return! loop ()

            | GetNodesMsg reply ->
                reply.Reply(ConcurrentCockpit.getNodes state)
                return! loop ()

            | GetAlarmsMsg reply ->
                reply.Reply(ConcurrentCockpit.getAlarms state)
                return! loop ()

            | NavigateMsg view ->
                TVar.write view state.CurrentView
                return! loop ()

            | SelectNodeMsg nodeId ->
                TVar.write nodeId state.SelectedNode
                return! loop ()

            | UpdateFederationMsg health ->
                ConcurrentCockpit.updateFederation health state
                return! loop ()

            | ShutdownMsg ->
                return ()  // Exit loop
        }
        loop ()
    )

    /// Post update (fire-and-forget)
    member _.UpdateNode(nodeId, node) = agent.Post(UpdateNodeMsg (nodeId, node))

    /// Post metrics update
    member _.UpdateMetrics(nodeId, cpu, mem, latency) =
        agent.Post(UpdateMetricsMsg (nodeId, cpu, mem, latency))

    /// Post alarm
    member _.AddAlarm(alarm) = agent.Post(AddAlarmMsg alarm)

    /// Acknowledge alarm (with reply)
    member _.AcknowledgeAlarm(alarmId, operatorId) =
        agent.PostAndReply(fun rc -> AckAlarmMsg (alarmId, operatorId, rc))

    /// Get nodes (with reply)
    member _.GetNodes() =
        agent.PostAndReply(GetNodesMsg)

    /// Get alarms (with reply)
    member _.GetAlarms() =
        agent.PostAndReply(GetAlarmsMsg)

    /// Navigate to view
    member _.Navigate(view) = agent.Post(NavigateMsg view)

    /// Select node
    member _.SelectNode(nodeId) = agent.Post(SelectNodeMsg nodeId)

    /// Update federation
    member _.UpdateFederation(health) = agent.Post(UpdateFederationMsg health)

    /// Shutdown actor
    member _.Shutdown() = agent.Post(ShutdownMsg)

// ============================================================================
// CONCURRENT COLLECTIONS
// ============================================================================

/// Thread-safe bounded queue for telemetry buffering
type BoundedQueue<'T>(capacity: int) =
    let items = System.Collections.Concurrent.ConcurrentQueue<'T>()
    let count = ref 0

    member _.Enqueue(item: 'T) =
        if Interlocked.Increment(count) <= capacity then
            items.Enqueue(item)
            true
        else
            Interlocked.Decrement(count) |> ignore
            false

    member _.TryDequeue() =
        match items.TryDequeue() with
        | (true, item) ->
            Interlocked.Decrement(count) |> ignore
            Some item
        | (false, _) -> None

    member _.Count = !count

    member _.Clear() =
        while items.TryDequeue() |> fst do ()
        count := 0

/// Ring buffer for sparkline data
type RingBuffer<'T>(capacity: int) =
    let buffer = Array.zeroCreate<'T> capacity
    let mutable writePos = 0
    let lockObj = obj()

    member _.Add(item: 'T) =
        lock lockObj (fun () ->
            buffer.[writePos] <- item
            writePos <- (writePos + 1) % capacity
        )

    member _.ToList() =
        lock lockObj (fun () ->
            let result = ResizeArray<'T>()
            let mutable pos = writePos
            for _ in 1..capacity do
                pos <- (pos - 1 + capacity) % capacity
                result.Add(buffer.[pos])
            result |> Seq.toList
        )

    member _.Latest =
        lock lockObj (fun () ->
            let pos = (writePos - 1 + capacity) % capacity
            buffer.[pos]
        )

// ============================================================================
// TELEMETRY PROCESSOR
// ============================================================================

/// High-throughput telemetry processor using actors
type TelemetryProcessor(state: ConcurrentCockpitState) =
    let buffer = BoundedQueue<TelemetryMsg>(10000)

    let processor = MailboxProcessor.Start(fun inbox ->
        let rec loop () = async {
            let! _ = inbox.Receive()

            // Process batch from buffer
            let batch = ResizeArray<TelemetryMsg>()
            let mutable msg = buffer.TryDequeue()
            while Option.isSome msg && batch.Count < 100 do
                batch.Add(Option.get msg)
                msg <- buffer.TryDequeue()

            // Group by node and apply updates
            if batch.Count > 0 then
                let nodeUpdates =
                    batch
                    |> Seq.choose (function
                        | NodeMetrics (id, m) -> Some (id, m)
                        | _ -> None)
                    |> Seq.groupBy fst
                    |> Seq.map (fun (id, updates) ->
                        let latest = updates |> Seq.map snd |> Seq.last
                        (id, latest))
                    |> Seq.toList

                // Batch update
                if not (List.isEmpty nodeUpdates) then
                    let nodes = TVar.read state.Nodes
                    let updatedNodes =
                        nodeUpdates
                        |> List.fold (fun m (id, metrics) ->
                            match Map.tryFind id m with
                            | None -> m
                            | Some node ->
                                let updated = {
                                    node with
                                        Cpu = updateMetric metrics.Cpu node.Cpu
                                        Memory = updateMetric metrics.Memory node.Memory
                                        NetworkLatency = updateMetric metrics.NetworkLatency node.NetworkLatency
                                        Status = Connected
                                }
                                Map.add id updated m
                        ) nodes
                    ConcurrentCockpit.batchUpdateNodes (updatedNodes |> Map.toList) state

                // Process alarms
                batch
                |> Seq.iter (function
                    | AlarmEvent alarm -> ConcurrentCockpit.addAlarm alarm state
                    | FederationHealthMsg health -> ConcurrentCockpit.updateFederation health state
                    | _ -> ())

            return! loop ()
        }
        loop ()
    )

    /// Submit telemetry for processing
    member _.Submit(msg: TelemetryMsg) =
        if buffer.Enqueue(msg) then
            processor.Post(())  // Signal processor

    /// Submit batch
    member _.SubmitBatch(msgs: TelemetryMsg seq) =
        for msg in msgs do
            buffer.Enqueue(msg) |> ignore
        processor.Post(())

    /// Get buffer stats
    member _.BufferCount = buffer.Count
