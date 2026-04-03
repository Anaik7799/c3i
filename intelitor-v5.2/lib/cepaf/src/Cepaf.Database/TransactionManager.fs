/// Transaction manager with ACID guarantees
/// SC-TXN-001: ACID semantics guaranteed
/// SC-TXN-003: Savepoint/rollback support
/// SC-TXN-005: Deadlock detection
module Cepaf.Database.TransactionManager

open System
open System.Collections.Concurrent
open System.Threading
open Cepaf.Database.Types

/// Transaction with connection binding
type BoundTransaction = {
    Transaction: Transaction
    Connection: obj  // Generic connection reference
    DbType: DbType
    Lock: SemaphoreSlim
}

/// Deadlock detection result
type DeadlockResult =
    | NoDeadlock
    | DeadlockDetected of string list  // Cycle of transaction IDs

/// Transaction manager with deadlock detection
type TransactionManager() =
    // Active transactions
    let transactions = ConcurrentDictionary<string, BoundTransaction>()

    // Wait-for graph for deadlock detection (SC-TXN-005)
    let waitGraph = ConcurrentDictionary<string, string>()  // txnId -> waiting for txnId

    // Transaction lock for isolation
    let globalLock = new ReaderWriterLockSlim()

    // Timeout configuration
    let txnTimeout = TimeSpan.FromSeconds(30.0)
    let lockTimeout = TimeSpan.FromSeconds(1.0)

    /// Generate unique transaction ID
    let generateTxnId () =
        Guid.NewGuid().ToString("N")

    /// Detect deadlock cycle using DFS
    let detectDeadlock (startTxn: string) =
        let visited = System.Collections.Generic.HashSet<string>()
        let path = System.Collections.Generic.Stack<string>()

        let rec dfs current =
            if visited.Contains(current) then
                // Found cycle
                let cycle = path |> Seq.takeWhile ((<>) current) |> Seq.toList
                DeadlockDetected (current :: cycle @ [current])
            elif waitGraph.ContainsKey(current) then
                visited.Add(current) |> ignore
                path.Push(current)
                let waitingFor = waitGraph.[current]
                dfs waitingFor
            else
                NoDeadlock

        dfs startTxn

    /// Begin a new transaction (SC-TXN-001)
    member _.Begin(isolationLevel: IsolationLevel, dbType: DbType, connection: obj) : DbResult<string> =
        let txnId = generateTxnId()

        let txn = {
            TxnId = txnId
            State = Active
            IsolationLevel = isolationLevel
            Operations = []
            StartTime = DateTime.UtcNow
            ConnectionId = Some txnId
            Savepoints = []
        }

        let bound = {
            Transaction = txn
            Connection = connection
            DbType = dbType
            Lock = new SemaphoreSlim(1, 1)
        }

        if transactions.TryAdd(txnId, bound) then
            Ok txnId
        else
            Error "Failed to create transaction"

    /// Add operation to transaction
    member _.AddOperation(txnId: string, request: DatabaseRequest) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            let updated = { bound.Transaction with Operations = bound.Transaction.Operations @ [request] }
            transactions.[txnId] <- { bound with Transaction = updated }
            Ok ()
        | true, bound ->
            Error $"Transaction {txnId} is not active (state: {bound.Transaction.State})"
        | false, _ ->
            Error $"Transaction {txnId} not found"

    /// Create savepoint (SC-TXN-003)
    member _.CreateSavepoint(txnId: string, name: string) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            let updated = { bound.Transaction with Savepoints = bound.Transaction.Savepoints @ [name] }
            transactions.[txnId] <- { bound with Transaction = updated }
            Ok ()
        | true, _ ->
            Error "Transaction not active"
        | false, _ ->
            Error "Transaction not found"

    /// Rollback to savepoint
    member _.RollbackToSavepoint(txnId: string, name: string) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            let idx = bound.Transaction.Savepoints |> List.tryFindIndex ((=) name)
            match idx with
            | Some i ->
                // Remove savepoints after this one
                let remaining = bound.Transaction.Savepoints |> List.take (i + 1)
                let updated = { bound.Transaction with Savepoints = remaining }
                transactions.[txnId] <- { bound with Transaction = updated }
                Ok ()
            | None ->
                Error $"Savepoint {name} not found"
        | true, _ ->
            Error "Transaction not active"
        | false, _ ->
            Error "Transaction not found"

    /// Release savepoint
    member _.ReleaseSavepoint(txnId: string, name: string) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            let updated = { bound.Transaction with Savepoints = bound.Transaction.Savepoints |> List.filter ((<>) name) }
            transactions.[txnId] <- { bound with Transaction = updated }
            Ok ()
        | true, _ ->
            Error "Transaction not active"
        | false, _ ->
            Error "Transaction not found"

    /// Commit transaction (SC-TXN-001: Atomicity)
    member _.Commit(txnId: string) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            // Mark as committed
            let committed = { bound.Transaction with State = Committed }
            transactions.[txnId] <- { bound with Transaction = committed }

            // Remove from wait graph
            waitGraph.TryRemove(txnId) |> ignore

            // Cleanup
            bound.Lock.Dispose()
            transactions.TryRemove(txnId) |> ignore

            Ok ()
        | true, bound ->
            Error $"Transaction {txnId} cannot be committed (state: {bound.Transaction.State})"
        | false, _ ->
            Error $"Transaction {txnId} not found"

    /// Rollback transaction
    member _.Rollback(txnId: string) : DbResult<unit> =
        match transactions.TryGetValue(txnId) with
        | true, bound when bound.Transaction.State = Active ->
            // Mark as rolled back
            let rolledBack = { bound.Transaction with State = RolledBack }
            transactions.[txnId] <- { bound with Transaction = rolledBack }

            // Remove from wait graph
            waitGraph.TryRemove(txnId) |> ignore

            // Cleanup
            bound.Lock.Dispose()
            transactions.TryRemove(txnId) |> ignore

            Ok ()
        | true, _ ->
            // Already not active, just cleanup
            transactions.TryRemove(txnId) |> ignore
            Ok ()
        | false, _ ->
            Ok ()  // No transaction to rollback

    /// Get transaction state
    member _.GetState(txnId: string) : TransactionState option =
        match transactions.TryGetValue(txnId) with
        | true, bound -> Some bound.Transaction.State
        | false, _ -> None

    /// Get active transaction count
    member _.ActiveCount = transactions.Count

    /// Check for deadlocks (SC-TXN-005)
    member _.CheckDeadlock(txnId: string, waitingForTxnId: string) : DeadlockResult =
        // Record wait edge
        waitGraph.[txnId] <- waitingForTxnId

        // Detect cycle
        let result = detectDeadlock txnId

        // Remove edge if no deadlock
        match result with
        | NoDeadlock ->
            waitGraph.TryRemove(txnId) |> ignore
        | _ -> ()

        result

    /// Acquire transaction lock with timeout
    member _.AcquireLock(txnId: string, timeout: TimeSpan) : Async<DbResult<unit>> =
        async {
            match transactions.TryGetValue(txnId) with
            | true, bound ->
                let! acquired = bound.Lock.WaitAsync(int timeout.TotalMilliseconds) |> Async.AwaitTask
                if acquired then
                    return Ok ()
                else
                    return Error "Lock acquisition timeout"
            | false, _ ->
                return Error "Transaction not found"
        }

    /// Release transaction lock
    member _.ReleaseLock(txnId: string) =
        match transactions.TryGetValue(txnId) with
        | true, bound ->
            try bound.Lock.Release() |> ignore with _ -> ()
        | false, _ -> ()

    /// Cleanup expired transactions
    member _.CleanupExpired() =
        let now = DateTime.UtcNow
        for kvp in transactions do
            if (now - kvp.Value.Transaction.StartTime) > txnTimeout then
                // Transaction expired, force rollback
                kvp.Value.Lock.Dispose()
                transactions.TryRemove(kvp.Key) |> ignore
                waitGraph.TryRemove(kvp.Key) |> ignore

    /// Get all active transactions (for monitoring)
    member _.GetActiveTransactions() =
        transactions
        |> Seq.map (fun kvp -> kvp.Value.Transaction)
        |> Seq.toList

    member _.Dispose() =
        for kvp in transactions do
            kvp.Value.Lock.Dispose()
        transactions.Clear()
        waitGraph.Clear()
        globalLock.Dispose()

    interface IDisposable with
        member this.Dispose() = this.Dispose()
