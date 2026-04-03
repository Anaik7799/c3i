namespace Cepaf.Modules

open System
open System.Collections.Concurrent
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop

/// Zenoh Coordinator Handlers Module
/// Provides F# handlers for Elixir ZenohCoordinator pub/sub operations.
/// Reference: lib/indrajaal/observability/zenoh_coordinator.ex
/// STAMP Compliance: SC-ZENOH-INT-001 to SC-ZENOH-INT-004
module ZenohHandlers =

    // ========================================================================
    // ZENOH TYPES
    // ========================================================================

    /// Zenoh key expression with optional wildcards
    type KeyExpression = {
        Expression: string
        CompiledPattern: System.Text.RegularExpressions.Regex option
        IsWildcard: bool
    }

    /// Zenoh message payload
    type ZenohPayload =
        | Text of string
        | Json of string
        | Binary of byte[]
        | Structured of Map<string, obj>

    /// Subscription handler function type
    type SubscriptionHandler = KeyExpression -> ZenohPayload -> unit

    /// Subscriber registration
    type Subscriber = {
        Id: string
        KeyExpr: KeyExpression
        Handler: SubscriptionHandler
        CreatedAt: DateTimeOffset
        MessageCount: int64 ref
    }

    /// Publisher registration
    type Publisher = {
        Id: string
        KeyExpr: string
        CreatedAt: DateTimeOffset
        PublishCount: int64 ref
    }

    /// Message for the internal queue
    type ZenohMessage = {
        Key: string
        Payload: ZenohPayload
        Timestamp: DateTimeOffset
        SourceNode: string
    }

    /// Zenoh subsystem status
    type ZenohStatus = {
        Supervisor: string
        Publisher: string
        Subscriber: string
        Heartbeat: string
        Integration: string
        SubscriberCount: int
        PublisherCount: int
        MessageCount: int64
    }

    /// Barrier synchronization state
    type BarrierState = {
        Name: string
        RequiredCount: int
        CurrentCount: int ref
        Participants: ConcurrentDictionary<string, DateTimeOffset>
        CreatedAt: DateTimeOffset
        CompletedAt: DateTimeOffset option ref
    }

    // ========================================================================
    // KEY EXPRESSION CONSTANTS (from ZenohCoordinator)
    // ========================================================================

    /// Data plane key expressions
    let dataPlaneKeys = [
        "indrajaal/kpi/compilation"
        "indrajaal/kpi/tests"
        "indrajaal/kpi/containers"
        "indrajaal/kpi/performance"
        "indrajaal/kpi/progress"
        "indrajaal/kpi/stamp"
        "indrajaal/kpi/todos"
        "indrajaal/kpi/agents"
    ]

    /// Control plane key expressions
    let controlPlaneKeys = [
        "indrajaal/control/refresh"
        "indrajaal/control/mode"
        "indrajaal/control/agent/**"
    ]

    /// Coordination plane key expressions
    let coordinationPlaneKeys = [
        "indrajaal/coord/heartbeat"
        "indrajaal/coord/sync"
        "indrajaal/coord/barrier/**"
    ]

    /// Evolution plane key expressions (SC-ZENOH-EVO-001)
    let evolutionPlaneKeys = [
        "indrajaal/evolution/shadow/*/execution"
        "indrajaal/evolution/shadow/*/comparison"
        "indrajaal/evolution/shadow/*/promotion"
        "indrajaal/evolution/gym/episode/*"
        "indrajaal/evolution/gym/stats"
        "indrajaal/evolution/guardian/validations"
        "indrajaal/evolution/openrouter/calls"
        "indrajaal/evolution/stats"
    ]

    /// Key prefixes
    let coordPrefix = "indrajaal/coord"
    let dataPrefix = "indrajaal/kpi"
    let controlPrefix = "indrajaal/control"
    let evolutionPrefix = "indrajaal/evolution"

    // ========================================================================
    // STATE MANAGEMENT
    // ========================================================================

    /// Thread-safe subscriber registry
    let private subscribers = ConcurrentDictionary<string, Subscriber>()

    /// Thread-safe publisher registry
    let private publishers = ConcurrentDictionary<string, Publisher>()

    /// Message buffer for async dispatch
    let private messageBuffer = ConcurrentQueue<ZenohMessage>()

    /// Barrier registry for synchronization
    let private barriers = ConcurrentDictionary<string, BarrierState>()

    /// Total message counter
    let private messageCounter = ref 0L

    /// Heartbeat interval in milliseconds (SC-ZENOH-INT-004)
    let heartbeatIntervalMs = 10_000

    /// Last heartbeat timestamp
    let mutable private lastHeartbeat = DateTimeOffset.UtcNow

    // ========================================================================
    // KEY EXPRESSION HELPERS
    // ========================================================================

    /// Compile a key expression with wildcards
    let compileKeyExpr (expr: string) : KeyExpression =
        let hasWildcard = expr.Contains("*")

        let compiled =
            if hasWildcard then
                try
                    let pattern =
                        expr
                            .Replace(".", "\\.")
                            .Replace("$*", "([^/]*)")
                            .Replace("**", "(.*)")
                            .Replace("*", "([^/]+)")
                    Some(System.Text.RegularExpressions.Regex($"^{pattern}$"))
                with _ -> None
            else
                None

        { Expression = expr; CompiledPattern = compiled; IsWildcard = hasWildcard }

    /// Check if a key matches an expression
    let keyMatches (expr: KeyExpression) (key: string) : bool =
        match expr.CompiledPattern with
        | Some regex -> regex.IsMatch(key)
        | None -> key = expr.Expression || expr.Expression = "**"

    // ========================================================================
    // ZENOH HANDLERS
    // ========================================================================

    /// Zenoh_Subscribe: Subscribe to messages matching a key expression
    let subscribe (keyExpr: string) (handler: SubscriptionHandler) (logger: QuadplexLogger)
                  : Result<string, string> =
        let id = Guid.NewGuid().ToString("N").[..7]
        let compiled = compileKeyExpr keyExpr

        let sub = {
            Id = id
            KeyExpr = compiled
            Handler = handler
            CreatedAt = DateTimeOffset.UtcNow
            MessageCount = ref 0L
        }

        if subscribers.TryAdd(id, sub) then
            logger.Info(sprintf "[Zenoh] Subscribed to: %s (id: %s)" keyExpr id)
            logger.IncrementCounter("zenoh.subscriptions", tags = Map.ofList [("key_expr", keyExpr)])
            Ok id
        else
            Error "Failed to register subscription"

    /// Zenoh_Unsubscribe: Remove a subscription
    let unsubscribe (subscriptionId: string) (logger: QuadplexLogger) : Result<unit, string> =
        let mutable removed = Unchecked.defaultof<Subscriber>
        if subscribers.TryRemove(subscriptionId, &removed) then
            logger.Info(sprintf "[Zenoh] Unsubscribed: %s" subscriptionId)
            Ok ()
        else
            Error "Subscription not found"

    /// Zenoh_Publish: Publish a message to a key
    let publish (key: string) (payload: ZenohPayload) (logger: QuadplexLogger) : Result<unit, string> =
        let msg = {
            Key = key
            Payload = payload
            Timestamp = DateTimeOffset.UtcNow
            SourceNode = Environment.MachineName
        }

        // Increment global counter
        System.Threading.Interlocked.Increment(messageCounter) |> ignore

        // Find matching subscribers and dispatch async
        let matchingSubscribers =
            subscribers.Values
            |> Seq.filter (fun sub -> keyMatches sub.KeyExpr key)
            |> Seq.toList

        for sub in matchingSubscribers do
            // Async dispatch (SC-LOG-001: never block)
            System.Threading.ThreadPool.QueueUserWorkItem(fun _ ->
                try
                    System.Threading.Interlocked.Increment(sub.MessageCount) |> ignore
                    sub.Handler sub.KeyExpr payload
                with ex ->
                    logger.Error(sprintf "[Zenoh] Handler error for %s: %s" sub.Id ex.Message)
            ) |> ignore

        logger.IncrementCounter("zenoh.publishes", tags = Map.ofList [("key", key)])
        Ok ()

    /// Zenoh_PublishCoord: Publish to coordination plane
    let publishCoord (key: string) (payload: ZenohPayload) (logger: QuadplexLogger) : Result<unit, string> =
        let fullKey = sprintf "%s/%s" coordPrefix key
        publish fullKey payload logger

    /// Zenoh_SubscribeCoord: Subscribe to coordination plane
    let subscribeCoord (keyExpr: string) (handler: SubscriptionHandler) (logger: QuadplexLogger)
                       : Result<string, string> =
        let fullExpr = sprintf "%s/%s" coordPrefix keyExpr
        subscribe fullExpr handler logger

    /// Zenoh_DeclarePublisher: Register as a publisher for a key expression
    let declarePublisher (keyExpr: string) (logger: QuadplexLogger) : Result<string, string> =
        let id = Guid.NewGuid().ToString("N").[..7]

        let pub = {
            Id = id
            KeyExpr = keyExpr
            CreatedAt = DateTimeOffset.UtcNow
            PublishCount = ref 0L
        }

        if publishers.TryAdd(id, pub) then
            logger.Info(sprintf "[Zenoh] Declared publisher: %s (id: %s)" keyExpr id)
            Ok id
        else
            Error "Failed to register publisher"

    // ========================================================================
    // BARRIER SYNCHRONIZATION
    // ========================================================================

    /// Zenoh_Barrier: Create or join a barrier synchronization point
    let barrier (name: string) (count: int) (participantId: string) (timeoutMs: int)
                (logger: QuadplexLogger) : Async<Result<unit, string>> =
        async {
            // Get or create barrier
            let barrierState =
                barriers.GetOrAdd(name, fun _ -> {
                    Name = name
                    RequiredCount = count
                    CurrentCount = ref 0
                    Participants = ConcurrentDictionary<string, DateTimeOffset>()
                    CreatedAt = DateTimeOffset.UtcNow
                    CompletedAt = ref None
                })

            // Register participant
            barrierState.Participants.[participantId] <- DateTimeOffset.UtcNow
            System.Threading.Interlocked.Increment(barrierState.CurrentCount) |> ignore

            logger.Info(sprintf "[Zenoh] Barrier %s: %d/%d participants"
                name (!barrierState.CurrentCount) barrierState.RequiredCount)

            // Wait for barrier or timeout
            let deadline = DateTimeOffset.UtcNow.AddMilliseconds(float timeoutMs)
            let mutable completed = false

            while not completed && DateTimeOffset.UtcNow < deadline do
                if !barrierState.CurrentCount >= barrierState.RequiredCount then
                    completed <- true
                    barrierState.CompletedAt := Some DateTimeOffset.UtcNow
                else
                    do! Async.Sleep(100)

            if completed then
                logger.Info(sprintf "[Zenoh] Barrier %s completed" name)
                return Ok ()
            else
                logger.Error(sprintf "[Zenoh] Barrier %s timed out" name)
                return Error "Barrier timeout"
        }

    // ========================================================================
    // HEARTBEAT MANAGEMENT (SC-ZENOH-INT-004)
    // ========================================================================

    /// Publish heartbeat message
    let publishHeartbeat (logger: QuadplexLogger) =
        let payload = Structured (Map.ofList [
            "timestamp", DateTimeOffset.UtcNow.ToString("o") :> obj
            "status", "alive" :> obj
            "node", Environment.MachineName :> obj
            "uptime", (DateTimeOffset.UtcNow - lastHeartbeat).TotalSeconds :> obj
        ])

        publishCoord "heartbeat" payload logger |> ignore
        lastHeartbeat <- DateTimeOffset.UtcNow

    /// Start heartbeat loop (should be called from Task.Run)
    let startHeartbeatLoop (logger: QuadplexLogger) (cancellationToken: System.Threading.CancellationToken) =
        async {
            while not cancellationToken.IsCancellationRequested do
                try
                    publishHeartbeat logger
                with ex ->
                    logger.Error(sprintf "[Zenoh] Heartbeat error: %s" ex.Message)

                do! Async.Sleep(heartbeatIntervalMs)
        }

    // ========================================================================
    // STATUS & METRICS
    // ========================================================================

    /// Get Zenoh subsystem status
    let getStatus () : ZenohStatus =
        {
            Supervisor = "running"
            Publisher = "active"
            Subscriber = "active"
            Heartbeat = "active"
            Integration = "full"
            SubscriberCount = subscribers.Count
            PublisherCount = publishers.Count
            MessageCount = !messageCounter
        }

    /// Get all registered key expressions
    let listKeyExpressions () =
        {|
            DataPlane = dataPlaneKeys
            ControlPlane = controlPlaneKeys
            CoordinationPlane = coordinationPlaneKeys
            EvolutionPlane = evolutionPlaneKeys
            ActiveSubscriptions = subscribers.Values |> Seq.map (fun s -> s.KeyExpr.Expression) |> Seq.toList
            ActivePublishers = publishers.Values |> Seq.map (fun p -> p.KeyExpr) |> Seq.toList
        |}

    /// Get subscriber statistics
    let getSubscriberStats () =
        subscribers.Values
        |> Seq.map (fun s -> {|
            Id = s.Id
            KeyExpr = s.KeyExpr.Expression
            MessageCount = !s.MessageCount
            CreatedAt = s.CreatedAt
        |})
        |> Seq.toList

    /// Get publisher statistics
    let getPublisherStats () =
        publishers.Values
        |> Seq.map (fun p -> {|
            Id = p.Id
            KeyExpr = p.KeyExpr
            PublishCount = !p.PublishCount
            CreatedAt = p.CreatedAt
        |})
        |> Seq.toList

    /// Force synchronization of all components
    let syncNow (logger: QuadplexLogger) =
        // Publish sync message
        let payload = Structured (Map.ofList [
            "triggered_at", DateTimeOffset.UtcNow.ToString("o") :> obj
        ])
        publishCoord "sync" payload logger |> ignore
        logger.Info("[Zenoh] Sync triggered")

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    /// Initialize the Zenoh handlers module
    let initialize (logger: QuadplexLogger) =
        logger.Info("[ZenohHandlers] Initializing Zenoh subsystem - SC-ZENOH-INT-001")
        logger.Info(sprintf "[ZenohHandlers] Heartbeat interval: %dms" heartbeatIntervalMs)
        logger.IncrementCounter("zenoh.initialized")

    /// Reset state (for testing)
    let reset () =
        subscribers.Clear()
        publishers.Clear()
        barriers.Clear()
        messageCounter := 0L
        lastHeartbeat <- DateTimeOffset.UtcNow
