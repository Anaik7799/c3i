// =============================================================================
// ZenohConsensus.fs - Raft-Lite Consensus Protocol
// =============================================================================
// STAMP: SC-OP-005, SC-OP-006, SC-CONS-001 to SC-CONS-005
// AOR: AOR-ZENOH-013, AOR-ZENOH-014
// Criticality: Level 6 (CRITICAL) - Distributed Consensus
// =============================================================================
// Provides Raft-lite consensus for cluster coordination:
// - Leader election with term management (SC-CONS-001)
// - Heartbeat-based leadership maintenance (SC-CONS-002)
// - Log replication for state synchronization (SC-CONS-003)
// - Split-brain prevention (SC-CONS-004)
// - Graceful leadership transfer (SC-CONS-005)
// =============================================================================

namespace Cepaf.Zenoh.Cluster

open System
open System.Threading
open System.Threading.Tasks
open System.Collections.Concurrent
open Cepaf.Zenoh.Core

/// Node role in the Raft consensus
[<RequireQualifiedAccess>]
type NodeRole =
    | Follower
    | Candidate
    | Leader

    override this.ToString() =
        match this with
        | Follower -> "follower"
        | Candidate -> "candidate"
        | Leader -> "leader"

/// Election term (Raft epoch)
type Term = int64

/// Log entry index
type LogIndex = int64

/// Log entry for state machine replication
type LogEntry<'T> = {
    /// Term when entry was received by leader
    Term: Term
    /// Position in the log
    Index: LogIndex
    /// Command to be applied to state machine
    Command: 'T
    /// Timestamp when entry was created
    Timestamp: DateTimeOffset
}

module LogEntry =
    let create (term: Term) (index: LogIndex) (command: 'T) : LogEntry<'T> = {
        Term = term
        Index = index
        Command = command
        Timestamp = DateTimeOffset.UtcNow
    }

/// Request Vote RPC (Raft)
type RequestVoteArgs = {
    /// Candidate's term
    Term: Term
    /// Candidate requesting vote
    CandidateId: string
    /// Index of candidate's last log entry
    LastLogIndex: LogIndex
    /// Term of candidate's last log entry
    LastLogTerm: Term
}

type RequestVoteResult = {
    /// Current term, for candidate to update itself
    Term: Term
    /// True means candidate received vote
    VoteGranted: bool
    /// ID of voting node
    VoterId: string
}

/// Append Entries RPC (Raft)
type AppendEntriesArgs<'T> = {
    /// Leader's term
    Term: Term
    /// So follower can redirect clients
    LeaderId: string
    /// Index of log entry immediately preceding new ones
    PrevLogIndex: LogIndex
    /// Term of prevLogIndex entry
    PrevLogTerm: Term
    /// Log entries to store (empty for heartbeat)
    Entries: LogEntry<'T> list
    /// Leader's commitIndex
    LeaderCommit: LogIndex
}

type AppendEntriesResult = {
    /// Current term, for leader to update itself
    Term: Term
    /// True if follower contained entry matching prevLogIndex and prevLogTerm
    Success: bool
    /// ID of responding node
    FollowerId: string
    /// Index of last entry appended (for leader to track)
    MatchIndex: LogIndex
}

/// Consensus state for a node
type ConsensusState<'T> = {
    /// Current role
    Role: NodeRole
    /// Current term
    CurrentTerm: Term
    /// CandidateId that received vote in current term (or None)
    VotedFor: string option
    /// Log entries
    Log: LogEntry<'T> list
    /// Index of highest log entry known to be committed
    CommitIndex: LogIndex
    /// Index of highest log entry applied to state machine
    LastApplied: LogIndex
    /// Current leader (if known)
    CurrentLeader: string option
    /// For each server, index of next log entry to send
    NextIndex: Map<string, LogIndex>
    /// For each server, index of highest log entry known to be replicated
    MatchIndex: Map<string, LogIndex>
}

module ConsensusState =
    let empty<'T> : ConsensusState<'T> = {
        Role = NodeRole.Follower
        CurrentTerm = 0L
        VotedFor = None
        Log = []
        CommitIndex = 0L
        LastApplied = 0L
        CurrentLeader = None
        NextIndex = Map.empty
        MatchIndex = Map.empty
    }

    let lastLogIndex (state: ConsensusState<'T>) : LogIndex =
        match state.Log with
        | [] -> 0L
        | log -> log |> List.maxBy (fun e -> e.Index) |> fun e -> e.Index

    let lastLogTerm (state: ConsensusState<'T>) : Term =
        match state.Log with
        | [] -> 0L
        | log -> log |> List.maxBy (fun e -> e.Index) |> fun e -> e.Term

    let getEntry (index: LogIndex) (state: ConsensusState<'T>) : LogEntry<'T> option =
        state.Log |> List.tryFind (fun e -> e.Index = index)

    let appendEntry (entry: LogEntry<'T>) (state: ConsensusState<'T>) : ConsensusState<'T> =
        { state with Log = state.Log @ [entry] }

    let truncateFrom (index: LogIndex) (state: ConsensusState<'T>) : ConsensusState<'T> =
        { state with Log = state.Log |> List.filter (fun e -> e.Index < index) }

/// Consensus event for state machine
[<RequireQualifiedAccess>]
type ConsensusEvent<'T> =
    | BecameLeader of term: Term
    | BecameFollower of term: Term * leaderId: string option
    | BecameCandidate of term: Term
    | LogCommitted of entry: LogEntry<'T>
    | LeaderChanged of newLeader: string option
    | TermChanged of oldTerm: Term * newTerm: Term
    | VoteReceived of fromNode: string * granted: bool
    | HeartbeatSent
    | HeartbeatReceived of fromLeader: string

/// Raft-lite consensus node (SC-CONS-001 to SC-CONS-005)
type RaftNode<'T>(nodeId: string, clusterNodes: string list, ?electionTimeoutMs: int, ?heartbeatIntervalMs: int) =
    let electionTimeoutMs = defaultArg electionTimeoutMs 150
    let heartbeatIntervalMs = defaultArg heartbeatIntervalMs 50
    let mutable state = ConsensusState.empty<'T>
    let lockObj = obj()
    let mutable electionTimer: Timer option = None
    let mutable heartbeatTimer: Timer option = None
    let random = Random()
    let eventHandlers = ResizeArray<ConsensusEvent<'T> -> unit>()

    // Vote tracking for candidate
    let votesReceived = ConcurrentDictionary<string, bool>()

    let raiseEvent event =
        for handler in eventHandlers do
            try handler event with _ -> ()

    let randomElectionTimeout () =
        // Randomize election timeout to prevent split votes (SC-CONS-004)
        electionTimeoutMs + random.Next(electionTimeoutMs)

    /// Node identifier
    member _.NodeId = nodeId

    /// Current state (immutable snapshot)
    member _.State = state

    /// Current role
    member _.Role = state.Role

    /// Current term
    member _.CurrentTerm = state.CurrentTerm

    /// Current leader
    member _.CurrentLeader = state.CurrentLeader

    /// Is this node the leader?
    member _.IsLeader = state.Role = NodeRole.Leader

    /// Subscribe to consensus events
    member _.OnEvent(handler: ConsensusEvent<'T> -> unit) =
        eventHandlers.Add(handler)

    /// Start the consensus node
    member this.Start() =
        lock lockObj (fun () ->
            this.ResetElectionTimer()
        )

    /// Stop the consensus node
    member _.Stop() =
        electionTimer |> Option.iter (fun t -> t.Dispose())
        heartbeatTimer |> Option.iter (fun t -> t.Dispose())
        electionTimer <- None
        heartbeatTimer <- None

    /// Reset election timer (called on heartbeat or vote)
    member private this.ResetElectionTimer() =
        electionTimer |> Option.iter (fun t -> t.Dispose())
        let timeout = randomElectionTimeout()
        electionTimer <- Some (new Timer(
            TimerCallback(fun _ -> this.OnElectionTimeout()),
            null,
            timeout,
            Timeout.Infinite))

    /// Start heartbeat timer (leader only)
    member private this.StartHeartbeatTimer() =
        heartbeatTimer |> Option.iter (fun t -> t.Dispose())
        heartbeatTimer <- Some (new Timer(
            TimerCallback(fun _ -> this.SendHeartbeat()),
            null,
            0,
            heartbeatIntervalMs))

    /// Stop heartbeat timer
    member private _.StopHeartbeatTimer() =
        heartbeatTimer |> Option.iter (fun t -> t.Dispose())
        heartbeatTimer <- None

    /// Handle election timeout - become candidate
    member private this.OnElectionTimeout() =
        lock lockObj (fun () ->
            if state.Role <> NodeRole.Leader then
                // Start new election (SC-CONS-001)
                let newTerm = state.CurrentTerm + 1L
                raiseEvent (ConsensusEvent.TermChanged (state.CurrentTerm, newTerm))

                state <- {
                    state with
                        Role = NodeRole.Candidate
                        CurrentTerm = newTerm
                        VotedFor = Some nodeId
                        CurrentLeader = None
                }

                votesReceived.Clear()
                votesReceived.[nodeId] <- true  // Vote for self

                raiseEvent (ConsensusEvent.BecameCandidate newTerm)

                // Request votes from all other nodes
                // (In real implementation, this would send RPCs)
                this.ResetElectionTimer()
        )

    /// Send heartbeat to all followers (leader only) (SC-CONS-002)
    member private this.SendHeartbeat() =
        lock lockObj (fun () ->
            if state.Role = NodeRole.Leader then
                raiseEvent ConsensusEvent.HeartbeatSent
                // In real implementation, send AppendEntries RPCs to all nodes
        )

    /// Handle RequestVote RPC
    member this.HandleRequestVote(args: RequestVoteArgs) : RequestVoteResult =
        lock lockObj (fun () ->
            // Update term if needed
            if args.Term > state.CurrentTerm then
                state <- {
                    state with
                        CurrentTerm = args.Term
                        Role = NodeRole.Follower
                        VotedFor = None
                        CurrentLeader = None
                }
                raiseEvent (ConsensusEvent.BecameFollower (args.Term, None))

            let voteGranted =
                args.Term >= state.CurrentTerm &&
                (state.VotedFor.IsNone || state.VotedFor = Some args.CandidateId) &&
                // Candidate's log is at least as up-to-date as receiver's log
                (args.LastLogTerm > ConsensusState.lastLogTerm state ||
                 (args.LastLogTerm = ConsensusState.lastLogTerm state &&
                  args.LastLogIndex >= ConsensusState.lastLogIndex state))

            if voteGranted then
                state <- { state with VotedFor = Some args.CandidateId }
                this.ResetElectionTimer()

            raiseEvent (ConsensusEvent.VoteReceived (args.CandidateId, voteGranted))

            {
                Term = state.CurrentTerm
                VoteGranted = voteGranted
                VoterId = nodeId
            }
        )

    /// Handle RequestVote response (as candidate)
    member this.HandleVoteResponse(result: RequestVoteResult) =
        lock lockObj (fun () ->
            if state.Role = NodeRole.Candidate && result.Term = state.CurrentTerm then
                if result.VoteGranted then
                    votesReceived.[result.VoterId] <- true

                    // Check if we have majority
                    let votesCount = votesReceived.Values |> Seq.filter id |> Seq.length
                    let majority = (clusterNodes.Length / 2) + 1

                    if votesCount >= majority then
                        // Become leader (SC-CONS-001)
                        state <- {
                            state with
                                Role = NodeRole.Leader
                                CurrentLeader = Some nodeId
                                // Initialize nextIndex for all followers
                                NextIndex =
                                    clusterNodes
                                    |> List.filter ((<>) nodeId)
                                    |> List.map (fun n -> n, ConsensusState.lastLogIndex state + 1L)
                                    |> Map.ofList
                                MatchIndex =
                                    clusterNodes
                                    |> List.filter ((<>) nodeId)
                                    |> List.map (fun n -> n, 0L)
                                    |> Map.ofList
                        }

                        raiseEvent (ConsensusEvent.BecameLeader state.CurrentTerm)
                        raiseEvent (ConsensusEvent.LeaderChanged (Some nodeId))
                        this.StopHeartbeatTimer()
                        this.StartHeartbeatTimer()

            elif result.Term > state.CurrentTerm then
                // Step down to follower
                state <- {
                    state with
                        CurrentTerm = result.Term
                        Role = NodeRole.Follower
                        VotedFor = None
                        CurrentLeader = None
                }
                raiseEvent (ConsensusEvent.BecameFollower (result.Term, None))
                this.StopHeartbeatTimer()
                this.ResetElectionTimer()
        )

    /// Handle AppendEntries RPC
    member this.HandleAppendEntries(args: AppendEntriesArgs<'T>) : AppendEntriesResult =
        lock lockObj (fun () ->
            // Update term if needed
            if args.Term > state.CurrentTerm then
                state <- {
                    state with
                        CurrentTerm = args.Term
                        Role = NodeRole.Follower
                        VotedFor = None
                }

            let success =
                args.Term >= state.CurrentTerm &&
                // Check if we have the previous entry
                (args.PrevLogIndex = 0L ||
                 match ConsensusState.getEntry args.PrevLogIndex state with
                 | Some entry -> entry.Term = args.PrevLogTerm
                 | None -> false)

            if success then
                // Accept leader
                state <- { state with CurrentLeader = Some args.LeaderId }

                if state.Role <> NodeRole.Follower then
                    state <- { state with Role = NodeRole.Follower }
                    raiseEvent (ConsensusEvent.BecameFollower (args.Term, Some args.LeaderId))
                    this.StopHeartbeatTimer()

                raiseEvent (ConsensusEvent.HeartbeatReceived args.LeaderId)
                this.ResetElectionTimer()

                // Append new entries
                for entry in args.Entries do
                    // Delete conflicting entries
                    match ConsensusState.getEntry entry.Index state with
                    | Some existing when existing.Term <> entry.Term ->
                        state <- ConsensusState.truncateFrom entry.Index state
                    | _ -> ()

                    // Append if not already present
                    if ConsensusState.getEntry entry.Index state |> Option.isNone then
                        state <- ConsensusState.appendEntry entry state

                // Update commit index
                if args.LeaderCommit > state.CommitIndex then
                    let lastNewIndex =
                        match args.Entries with
                        | [] -> state.CommitIndex
                        | entries -> entries |> List.maxBy (fun e -> e.Index) |> fun e -> e.Index
                    state <- { state with CommitIndex = min args.LeaderCommit lastNewIndex }

            {
                Term = state.CurrentTerm
                Success = success
                FollowerId = nodeId
                MatchIndex = ConsensusState.lastLogIndex state
            }
        )

    /// Propose a command to be replicated (leader only)
    member this.ProposeAsync(command: 'T) : Task<Result<LogEntry<'T>, string>> =
        task {
            if state.Role <> NodeRole.Leader then
                return Error "Not leader"
            else
                let entry = lock lockObj (fun () ->
                    let index = ConsensusState.lastLogIndex state + 1L
                    let entry = LogEntry.create state.CurrentTerm index command
                    state <- ConsensusState.appendEntry entry state
                    entry
                )
                // In real implementation, replicate to followers
                return Ok entry
        }

    /// Apply committed entries to state machine
    member this.ApplyCommitted(apply: LogEntry<'T> -> unit) =
        lock lockObj (fun () ->
            while state.LastApplied < state.CommitIndex do
                let nextIndex = state.LastApplied + 1L
                match ConsensusState.getEntry nextIndex state with
                | Some entry ->
                    apply entry
                    raiseEvent (ConsensusEvent.LogCommitted entry)
                    state <- { state with LastApplied = nextIndex }
                | None -> ()
        )

    /// Transfer leadership to another node (SC-CONS-005)
    member this.TransferLeadership(targetNodeId: string) : Result<unit, string> =
        lock lockObj (fun () ->
            if state.Role <> NodeRole.Leader then
                Error "Not leader"
            elif targetNodeId = nodeId then
                Error "Cannot transfer to self"
            elif not (List.contains targetNodeId clusterNodes) then
                Error "Target node not in cluster"
            else
                // Stop accepting new proposals
                // Send TimeoutNow to target (in real implementation)
                this.StopHeartbeatTimer()
                state <- {
                    state with
                        Role = NodeRole.Follower
                        CurrentLeader = None
                }
                raiseEvent (ConsensusEvent.BecameFollower (state.CurrentTerm, Some targetNodeId))
                this.ResetElectionTimer()
                Ok ()
        )

    interface IDisposable with
        member this.Dispose() =
            this.Stop()

/// Cluster membership management
type ClusterMembership(nodeId: string, initialNodes: string list) =
    let mutable nodes = Set.ofList initialNodes
    let lockObj = obj()

    /// Current cluster nodes
    member _.Nodes = nodes |> Set.toList

    /// Node count
    member _.NodeCount = nodes.Count

    /// Quorum size
    member _.QuorumSize = (nodes.Count / 2) + 1

    /// Check if node is in cluster
    member _.Contains(id: string) = nodes.Contains(id)

    /// Add node to cluster
    member _.AddNode(id: string) =
        lock lockObj (fun () ->
            nodes <- Set.add id nodes
        )

    /// Remove node from cluster
    member _.RemoveNode(id: string) =
        lock lockObj (fun () ->
            if id <> nodeId then  // Can't remove self
                nodes <- Set.remove id nodes
        )

    /// Check if we have quorum
    member _.HasQuorum(respondingNodes: string list) =
        let count = respondingNodes |> List.filter nodes.Contains |> List.length
        count >= (nodes.Count / 2) + 1

