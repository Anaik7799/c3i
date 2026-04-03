// =============================================================================
// ZenohQuorum.fs - Quorum-Based Voting and 2oo3 Consensus
// =============================================================================
// STAMP: SC-OP-005, SC-QUORUM-001, SC-SIL6-001
// AOR: AOR-ZENOH-011, AOR-ZENOH-012
// Criticality: Level 6 (CRITICAL) - Safety-Critical Consensus
// =============================================================================
// Provides quorum voting and 2oo3 consensus for SIL-6 compliance:
// - Standard quorum voting (floor(N/2) + 1)
// - 2oo3 voting for safety-critical decisions (SC-QUORUM-001)
// - Vote replay protection
// - Timeout handling
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core

/// Vote message for quorum voting
type VoteMessage = {
    /// Unique quorum session identifier
    QuorumId: string
    /// Voting node identifier
    NodeId: string
    /// The vote (true = approve, false = reject)
    Vote: bool
    /// Vote confidence (0.0 - 1.0)
    Confidence: float
    /// Timestamp of vote
    Timestamp: DateTimeOffset
    /// Nonce to prevent replay attacks
    Nonce: Guid
    /// Optional reason for the vote
    Reason: string option
}

module VoteMessage =
    /// Create a vote message
    let create (quorumId: string) (nodeId: string) (vote: bool) : VoteMessage = {
        QuorumId = quorumId
        NodeId = nodeId
        Vote = vote
        Confidence = 1.0
        Timestamp = DateTimeOffset.UtcNow
        Nonce = Guid.NewGuid()
        Reason = None
    }

    /// Create vote with confidence level
    let createWithConfidence (quorumId: string) (nodeId: string) (vote: bool) (confidence: float) : VoteMessage =
        { create quorumId nodeId vote with Confidence = confidence }

    /// Create vote with reason
    let createWithReason (quorumId: string) (nodeId: string) (vote: bool) (reason: string) : VoteMessage =
        { create quorumId nodeId vote with Reason = Some reason }

/// Quorum calculation result
[<RequireQualifiedAccess>]
type QuorumResult =
    /// Quorum achieved with approval
    | Approved of yesVotes: int * totalVotes: int * totalNodes: int
    /// Quorum achieved with rejection
    | Rejected of noVotes: int * totalVotes: int * totalNodes: int
    /// Not enough votes to determine outcome
    | Inconclusive of votes: int * required: int * totalNodes: int
    /// Voting timed out
    | TimedOut of votes: int * required: int * timeoutMs: int
    /// Quorum error
    | Error of message: string

    /// Check if quorum was decided (approved or rejected)
    member this.IsDecided =
        match this with Approved _ | Rejected _ -> true | _ -> false

    /// Check if result represents an approval (semantic wrapper for IsApproved pattern)
    member this.WasApproved =
        match this with Approved _ -> true | _ -> false

    /// Check if result represents a rejection (semantic wrapper for IsRejected pattern)
    member this.WasRejected =
        match this with Rejected _ -> true | _ -> false

/// Quorum calculator (SC-OP-005)
module QuorumCalculator =

    /// Calculate required quorum votes: floor(N/2) + 1
    let requiredVotes (totalNodes: int) : int =
        (totalNodes / 2) + 1

    /// Check if quorum is achieved
    let hasQuorum (votes: int) (totalNodes: int) : bool =
        votes >= requiredVotes totalNodes

    /// Calculate quorum result from votes
    let calculate (votes: VoteMessage list) (totalNodes: int) : QuorumResult =
        let yesVotes = votes |> List.filter (fun v -> v.Vote) |> List.length
        let noVotes = votes |> List.filter (fun v -> not v.Vote) |> List.length
        let totalVotes = votes.Length
        let required = requiredVotes totalNodes

        if yesVotes >= required then
            QuorumResult.Approved (yesVotes, totalVotes, totalNodes)
        elif noVotes >= required then
            QuorumResult.Rejected (noVotes, totalVotes, totalNodes)
        elif totalVotes >= totalNodes then
            // All votes received but no quorum - inconclusive
            QuorumResult.Inconclusive (totalVotes, required, totalNodes)
        else
            QuorumResult.Inconclusive (totalVotes, required, totalNodes)

/// 2oo3 (Two-out-of-Three) voting result (SC-QUORUM-001)
[<RequireQualifiedAccess>]
type TwoOfThreeResult =
    /// All three channels agree
    | Unanimous of value: bool
    /// Two channels agree, one disagrees
    | TwoOfThree of value: bool * dissenter: string
    /// Complete disagreement (should not happen with boolean votes)
    | Disagreement of votes: (string * bool) list
    /// One or more channels failed
    | ChannelFailure of failedChannels: string list * reason: string

    member this.Value =
        match this with
        | Unanimous v -> Some v
        | TwoOfThree (v, _) -> Some v
        | _ -> None

    member this.IsApproved =
        match this.Value with Some true -> true | _ -> false

    member this.IsDecided =
        match this with
        | Unanimous _ | TwoOfThree _ -> true
        | _ -> false

/// Channel vote for 2oo3 voting
type ChannelVote = {
    /// Channel identifier: "primary" | "secondary" | "arbiter"
    ChannelId: string
    /// The vote value
    Value: bool
    /// Vote confidence (0.0 - 1.0)
    Confidence: float
    /// Timestamp of vote
    Timestamp: DateTimeOffset
    /// Optional diagnostic data
    Diagnostics: string option
}

module ChannelVote =
    let create (channelId: string) (value: bool) : ChannelVote = {
        ChannelId = channelId
        Value = value
        Confidence = 1.0
        Timestamp = DateTimeOffset.UtcNow
        Diagnostics = None
    }

/// 2oo3 Voting system for SIL-6 compliance (SC-QUORUM-001, SC-SIL6-001)
module TwoOfThreeVoting =

    /// Channel identifiers
    let [<Literal>] Primary = "primary"
    let [<Literal>] Secondary = "secondary"
    let [<Literal>] Arbiter = "arbiter"

    /// Execute 2oo3 vote with three boolean values
    let vote (primary: bool) (secondary: bool) (arbiter: bool) : TwoOfThreeResult =
        let votes = [
            (Primary, primary)
            (Secondary, secondary)
            (Arbiter, arbiter)
        ]

        let yesCount = votes |> List.filter snd |> List.length
        let noCount = 3 - yesCount

        if yesCount = 3 then
            TwoOfThreeResult.Unanimous true
        elif noCount = 3 then
            TwoOfThreeResult.Unanimous false
        elif yesCount >= 2 then
            let dissenter = votes |> List.find (fun (_, v) -> not v) |> fst
            TwoOfThreeResult.TwoOfThree (true, dissenter)
        elif noCount >= 2 then
            let dissenter = votes |> List.find (fun (_, v) -> v) |> fst
            TwoOfThreeResult.TwoOfThree (false, dissenter)
        else
            TwoOfThreeResult.Disagreement votes

    /// Execute 2oo3 vote with channel votes
    let voteChannels (votes: ChannelVote list) : TwoOfThreeResult =
        if votes.Length <> 3 then
            TwoOfThreeResult.ChannelFailure ([], sprintf "Expected 3 votes, got %d" votes.Length)
        else
            let primary = votes |> List.tryFind (fun v -> v.ChannelId = Primary)
            let secondary = votes |> List.tryFind (fun v -> v.ChannelId = Secondary)
            let arbiter = votes |> List.tryFind (fun v -> v.ChannelId = Arbiter)

            match primary, secondary, arbiter with
            | Some p, Some s, Some a ->
                vote p.Value s.Value a.Value
            | _ ->
                let missing =
                    [ if primary.IsNone then Primary
                      if secondary.IsNone then Secondary
                      if arbiter.IsNone then Arbiter ]
                TwoOfThreeResult.ChannelFailure (missing, "Missing channel votes")

    /// Execute 2oo3 vote with async channel functions
    let voteAsync
        (primary: unit -> Task<Result<bool, string>>)
        (secondary: unit -> Task<Result<bool, string>>)
        (arbiter: unit -> Task<Result<bool, string>>) : Task<TwoOfThreeResult> =
        task {
            // Execute all three channels in parallel
            let! results = Task.WhenAll([|
                primary()
                secondary()
                arbiter()
            |])

            let channelResults = [
                (Primary, results.[0])
                (Secondary, results.[1])
                (Arbiter, results.[2])
            ]

            // Check for failures
            let failures =
                channelResults
                |> List.choose (fun (ch, r) ->
                    match r with
                    | Error msg -> Some (ch, msg)
                    | Ok _ -> None)

            if failures.Length > 1 then
                // More than one channel failed - cannot determine result
                let failedChannels = failures |> List.map fst
                let reasons = failures |> List.map snd |> String.concat "; "
                return TwoOfThreeResult.ChannelFailure (failedChannels, reasons)
            else
                // At least 2 channels succeeded
                let votes =
                    channelResults
                    |> List.choose (fun (ch, r) ->
                        match r with
                        | Ok v -> Some (ChannelVote.create ch v)
                        | Error _ -> None)

                if votes.Length >= 2 then
                    // Can make decision with 2 votes if they agree
                    let yesCount = votes |> List.filter (fun v -> v.Value) |> List.length
                    let noCount = votes.Length - yesCount

                    if votes.Length = 3 then
                        return voteChannels votes
                    elif yesCount = 2 || noCount = 2 then
                        // 2 votes and they agree
                        let value = yesCount >= noCount
                        let dissenter =
                            failures
                            |> List.tryHead
                            |> Option.map fst
                            |> Option.defaultValue "unknown"
                        return TwoOfThreeResult.TwoOfThree (value, dissenter)
                    else
                        // 2 votes but they disagree - need arbiter
                        let failedChannels = failures |> List.map fst
                        return TwoOfThreeResult.ChannelFailure (failedChannels, "Arbiter required but failed")
                else
                    let failedChannels = failures |> List.map fst
                    return TwoOfThreeResult.ChannelFailure (failedChannels, "Too many channels failed")
        }

/// Quorum session for distributed voting
type QuorumSession(quorumId: string, nodeId: string, expectedNodes: int, timeoutMs: int) =
    let votes = ConcurrentDictionary<string, VoteMessage>()
    let mutable result: QuorumResult option = None
    let completionSource = TaskCompletionSource<QuorumResult>()
    let lockObj = obj()

    /// Quorum session ID
    member _.QuorumId = quorumId

    /// This node's ID
    member _.NodeId = nodeId

    /// Expected number of nodes
    member _.ExpectedNodes = expectedNodes

    /// Current vote count
    member _.VoteCount = votes.Count

    /// Get all votes
    member _.Votes = votes.Values |> Seq.toList

    /// Record a vote
    member _.RecordVote(vote: VoteMessage) =
        if vote.QuorumId = quorumId then
            // Check for replay (same node can only vote once with same nonce)
            match votes.TryGetValue(vote.NodeId) with
            | true, existing when existing.Nonce = vote.Nonce ->
                ()  // Duplicate - ignore
            | _ ->
                votes.[vote.NodeId] <- vote

                // Check if we have enough votes
                lock lockObj (fun () ->
                    if result.IsNone then
                        let currentVotes = votes.Values |> Seq.toList
                        let calcResult = QuorumCalculator.calculate currentVotes expectedNodes

                        match calcResult with
                        | QuorumResult.Approved _ | QuorumResult.Rejected _ ->
                            result <- Some calcResult
                            completionSource.TrySetResult(calcResult) |> ignore
                        | _ when currentVotes.Length >= expectedNodes ->
                            result <- Some calcResult
                            completionSource.TrySetResult(calcResult) |> ignore
                        | _ -> ()
                )

    /// Cast this node's vote
    member this.CastVote(vote: bool, ?confidence: float, ?reason: string) =
        let msg: VoteMessage = {
            QuorumId = quorumId
            NodeId = nodeId
            Vote = vote
            Confidence = defaultArg confidence 1.0
            Timestamp = DateTimeOffset.UtcNow
            Nonce = Guid.NewGuid()
            Reason = reason
        }
        this.RecordVote(msg)
        msg

    /// Wait for quorum result
    member _.WaitForResultAsync() : Task<QuorumResult> =
        task {
            use cts = new CancellationTokenSource(timeoutMs)
            let token: CancellationToken = cts.Token

            try
                let! result = completionSource.Task.WaitAsync(token)
                return result
            with
            | :? OperationCanceledException ->
                let currentVotes = votes.Count
                let required = QuorumCalculator.requiredVotes expectedNodes
                return QuorumResult.TimedOut (currentVotes, required, timeoutMs)
        }

    /// Get current result (if decided)
    member _.Result = result

    /// Check if quorum is decided
    member _.IsDecided = result.IsSome

/// Barrier synchronization for cluster coordination
type BarrierSession(barrierId: string, nodeId: string, expectedNodes: int, timeoutMs: int) =
    let arrivedNodes = ConcurrentDictionary<string, DateTimeOffset>()
    let completionSource = TaskCompletionSource<bool>()
    let lockObj = obj()
    let mutable released = false

    /// Barrier ID
    member _.BarrierId = barrierId

    /// This node's ID
    member _.NodeId = nodeId

    /// Expected number of nodes
    member _.ExpectedNodes = expectedNodes

    /// Current arrived count
    member _.ArrivedCount = arrivedNodes.Count

    /// Arrived nodes
    member _.ArrivedNodes = arrivedNodes.Keys |> Seq.toList

    /// Check if barrier is released
    member _.IsReleased = released

    /// Record node arrival
    member _.RecordArrival(nodeId: string) =
        arrivedNodes.[nodeId] <- DateTimeOffset.UtcNow

        lock lockObj (fun () ->
            if not released && arrivedNodes.Count >= expectedNodes then
                released <- true
                completionSource.TrySetResult(true) |> ignore
        )

    /// Arrive at barrier (this node)
    member this.Arrive() =
        this.RecordArrival(nodeId)

    /// Wait at barrier
    member _.WaitAsync() : Task<Result<unit, ZenohError>> =
        task {
            use cts = new CancellationTokenSource(timeoutMs)
            let token: CancellationToken = cts.Token

            try
                let! _ = completionSource.Task.WaitAsync(token)
                return Ok ()
            with
            | :? OperationCanceledException ->
                return Error (ZenohError.BarrierTimeout (barrierId, timeoutMs))
        }
