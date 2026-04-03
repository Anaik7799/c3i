namespace Cepaf.Podman.Events

open System
open System.IO
open System.Net.Http
open System.Threading
open System.Threading.Tasks
open System.Collections.Generic
open Cepaf.Podman.Domain
open Cepaf.Podman.Client

/// Event streaming operations
module Stream =

    // ========================================================================
    // Stream Implementation
    // ========================================================================

    /// Create event stream
    let stream (client: PodmanClient) (filter: EventFilter) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<PodmanEvent>> =
        let query = EventFilter.toQueryString filter
        let url = client.BasePath + "/events" + query

        { new IAsyncEnumerable<PodmanResult<PodmanEvent>> with
            member _.GetAsyncEnumerator(ct) =
                let combinedCt = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, ct).Token
                let mutable httpResponse: HttpResponseMessage option = None
                let mutable reader: StreamReader option = None
                let mutable current: PodmanResult<PodmanEvent> = Error PodmanError.OperationCancelled
                let mutable disposed = false

                { new IAsyncEnumerator<PodmanResult<PodmanEvent>> with
                    member _.Current = current

                    member self.MoveNextAsync() =
                        ValueTask<bool>(task {
                            try
                                if disposed then
                                    return false
                                else
                                    // Initialize stream on first call
                                    if reader.IsNone then
                                        let! response = client.HttpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, combinedCt)
                                        httpResponse <- Some response
                                        let! contentStream = response.Content.ReadAsStreamAsync(combinedCt)
                                        reader <- Some (new StreamReader(contentStream))

                                    match reader with
                                    | Some r when not r.EndOfStream ->
                                        let! line = r.ReadLineAsync(combinedCt).AsTask()
                                        if String.IsNullOrWhiteSpace(line) then
                                            return! self.MoveNextAsync().AsTask()
                                        else
                                            match Serialization.parseEventString line with
                                            | Ok event ->
                                                current <- Ok event
                                                return true
                                            | Error e ->
                                                current <- Error e
                                                return true
                                    | _ ->
                                        return false
                            with
                            | :? OperationCanceledException ->
                                current <- Error PodmanError.OperationCancelled
                                return false
                            | :? HttpRequestException as ex ->
                                current <- Error (PodmanError.ConnectionRefused ex.Message)
                                return false
                            | ex ->
                                current <- Error (PodmanError.InternalError ex.Message)
                                return false
                        })

                    member _.DisposeAsync() =
                        ValueTask(task {
                            if not disposed then
                                disposed <- true
                                match reader with
                                | Some r -> r.Dispose()
                                | Option.None -> ()
                                match httpResponse with
                                | Some r -> r.Dispose()
                                | Option.None -> ()
                        })
                }
        }

    /// Stream all events
    let streamAll (client: PodmanClient) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<PodmanEvent>> =
        stream client EventFilter.empty cancellationToken

    /// Stream container events only
    let streamContainers (client: PodmanClient) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<PodmanEvent>> =
        let filter = EventFilter.empty |> EventFilter.containerEvents
        stream client filter cancellationToken

    /// Stream pod events only
    let streamPods (client: PodmanClient) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<PodmanEvent>> =
        let filter = EventFilter.empty |> EventFilter.podEvents
        stream client filter cancellationToken

    /// Stream image events only
    let streamImages (client: PodmanClient) (cancellationToken: CancellationToken) : IAsyncEnumerable<PodmanResult<PodmanEvent>> =
        let filter = EventFilter.empty |> EventFilter.imageEvents
        stream client filter cancellationToken

    // ========================================================================
    // One-Shot Event Query
    // ========================================================================

    /// Get events between two timestamps (non-streaming)
    let getEvents (client: PodmanClient) (since: DateTimeOffset) (until: DateTimeOffset) : AsyncPodmanResult<PodmanEvent list> = async {
        let filter =
            EventFilter.empty
            |> EventFilter.since since
            |> EventFilter.until until
        let query = EventFilter.toQueryString filter
        let! result = HttpClient.getRaw client ("/events" + query)
        return result |> Result.bind (fun response ->
            try
                let events =
                    response.Split([| '\n' |], StringSplitOptions.RemoveEmptyEntries)
                    |> Array.toList
                    |> List.choose (fun line ->
                        match Serialization.parseEventString line with
                        | Ok e -> Some e
                        | Error _ -> Option.None
                    )
                Ok events
            with ex ->
                Error (PodmanError.JsonParseError ex.Message)
        )
    }

    /// Get events from last N seconds
    let getRecentEvents (client: PodmanClient) (seconds: int) : AsyncPodmanResult<PodmanEvent list> =
        let now = DateTimeOffset.UtcNow
        let since = now.AddSeconds(float -seconds)
        getEvents client since now

    // ========================================================================
    // Event Callbacks
    // ========================================================================

    /// Event handler type
    type StreamEventHandler = PodmanEvent -> unit

    /// Event subscription
    type EventSubscription = {
        Id: Guid
        Handler: StreamEventHandler
        Filter: EventFilter
        CancellationTokenSource: CancellationTokenSource
    }

    /// Start listening for events with callback
    let subscribe (client: PodmanClient) (handler: StreamEventHandler) (filter: EventFilter) : EventSubscription =
        let cts = new CancellationTokenSource()
        let subscription = {
            Id = Guid.NewGuid()
            Handler = handler
            Filter = filter
            CancellationTokenSource = cts
        }

        // Start background task to process events
        Task.Run(fun () ->
            task {
                let events = stream client filter cts.Token
                let enumerator = events.GetAsyncEnumerator(cts.Token)

                try
                    while not cts.Token.IsCancellationRequested do
                        let! hasNext = enumerator.MoveNextAsync().AsTask()
                        if hasNext then
                            match enumerator.Current with
                            | Ok event -> handler event
                            | Error _ -> ()  // Skip errors in subscription mode
                finally
                    enumerator.DisposeAsync().AsTask() |> ignore
            } :> Task
        ) |> ignore

        subscription

    /// Unsubscribe from events
    let unsubscribe (subscription: EventSubscription) : unit =
        subscription.CancellationTokenSource.Cancel()
        subscription.CancellationTokenSource.Dispose()

    /// Subscribe to container start events
    let onContainerStart (client: PodmanClient) (handler: PodmanEvent -> unit) : EventSubscription =
        let filter = EventFilter.empty |> EventFilter.containerEvents |> EventFilter.forEvents ["start"]
        subscribe client (fun e ->
            if e.Action = "start" then handler e
        ) filter

    /// Subscribe to container stop events
    let onContainerStop (client: PodmanClient) (handler: PodmanEvent -> unit) : EventSubscription =
        let filter = EventFilter.empty |> EventFilter.containerEvents |> EventFilter.forEvents ["stop"]
        subscribe client (fun e ->
            if e.Action = "stop" then handler e
        ) filter

    /// Subscribe to container die events
    let onContainerDie (client: PodmanClient) (handler: PodmanEvent -> unit) : EventSubscription =
        let filter = EventFilter.empty |> EventFilter.containerEvents |> EventFilter.forEvents ["die"]
        subscribe client (fun e ->
            if e.Action = "die" then handler e
        ) filter

