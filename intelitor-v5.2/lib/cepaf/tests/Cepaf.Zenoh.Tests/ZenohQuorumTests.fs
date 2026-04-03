// =============================================================================
// ZenohQuorumTests.fs - Unit Tests for Quorum Voting (L6)
// =============================================================================
// STAMP: SC-OP-005, SC-QUORUM-001, SC-SIL6-001, SC-TDG-001
// AOR: AOR-TEST-001, AOR-MESH-003
// Criticality: Level 6 (CRITICAL) - Safety-Critical Consensus Tests
// =============================================================================

module Cepaf.Zenoh.Tests.ZenohQuorumTests

open System
open Expecto
open Cepaf.Zenoh.Core
open Cepaf.Zenoh.Cluster

// =============================================================================
// QuorumCalculator Tests (SC-OP-005)
// =============================================================================

[<Tests>]
let quorumCalculatorTests =
    testList "QuorumCalculator" [
        test "requiredVotes for 1 node is 1" {
            Expect.equal (QuorumCalculator.requiredVotes 1) 1 "1-node quorum"
        }

        test "requiredVotes for 2 nodes is 2" {
            Expect.equal (QuorumCalculator.requiredVotes 2) 2 "2-node quorum"
        }

        test "requiredVotes for 3 nodes is 2 (SC-OP-005)" {
            Expect.equal (QuorumCalculator.requiredVotes 3) 2 "3-node quorum"
        }

        test "requiredVotes for 4 nodes is 3" {
            Expect.equal (QuorumCalculator.requiredVotes 4) 3 "4-node quorum"
        }

        test "requiredVotes for 5 nodes is 3" {
            Expect.equal (QuorumCalculator.requiredVotes 5) 3 "5-node quorum"
        }

        test "requiredVotes for 7 nodes is 4" {
            Expect.equal (QuorumCalculator.requiredVotes 7) 4 "7-node quorum"
        }

        test "hasQuorum returns true when votes >= required" {
            Expect.isTrue (QuorumCalculator.hasQuorum 2 3) "2/3 has quorum"
            Expect.isTrue (QuorumCalculator.hasQuorum 3 3) "3/3 has quorum"
        }

        test "hasQuorum returns false when votes < required" {
            Expect.isFalse (QuorumCalculator.hasQuorum 1 3) "1/3 no quorum"
            Expect.isFalse (QuorumCalculator.hasQuorum 2 5) "2/5 no quorum"
        }

        test "calculate returns Approved when yes votes have quorum" {
            let votes = [
                VoteMessage.create "q1" "n1" true
                VoteMessage.create "q1" "n2" true
            ]
            match QuorumCalculator.calculate votes 3 with
            | QuorumResult.Approved (yes, total, nodes) ->
                Expect.equal yes 2 "Yes votes"
                Expect.equal total 2 "Total votes"
                Expect.equal nodes 3 "Total nodes"
            | _ -> failtest "Expected Approved"
        }

        test "calculate returns Rejected when no votes have quorum" {
            let votes = [
                VoteMessage.create "q1" "n1" false
                VoteMessage.create "q1" "n2" false
            ]
            match QuorumCalculator.calculate votes 3 with
            | QuorumResult.Rejected (no, total, nodes) ->
                Expect.equal no 2 "No votes"
                Expect.equal total 2 "Total votes"
                Expect.equal nodes 3 "Total nodes"
            | _ -> failtest "Expected Rejected"
        }

        test "calculate returns Inconclusive when no quorum" {
            let votes = [
                VoteMessage.create "q1" "n1" true
            ]
            match QuorumCalculator.calculate votes 3 with
            | QuorumResult.Inconclusive (total, required, nodes) ->
                Expect.equal total 1 "Total votes"
                Expect.equal required 2 "Required votes"
                Expect.equal nodes 3 "Total nodes"
            | _ -> failtest "Expected Inconclusive"
        }
    ]

// =============================================================================
// QuorumResult Tests
// =============================================================================

[<Tests>]
let quorumResultTests =
    testList "QuorumResult" [
        test "IsDecided is true for Approved" {
            let result = QuorumResult.Approved (2, 2, 3)
            Expect.isTrue result.IsDecided "Approved is decided"
        }

        test "IsDecided is true for Rejected" {
            let result = QuorumResult.Rejected (2, 2, 3)
            Expect.isTrue result.IsDecided "Rejected is decided"
        }

        test "IsDecided is false for Inconclusive" {
            let result = QuorumResult.Inconclusive (1, 2, 3)
            Expect.isFalse result.IsDecided "Inconclusive is not decided"
        }

        test "IsDecided is false for TimedOut" {
            let result = QuorumResult.TimedOut (1, 2, 5000)
            Expect.isFalse result.IsDecided "TimedOut is not decided"
        }

        test "WasApproved is true only for Approved" {
            Expect.isTrue (QuorumResult.Approved (2, 2, 3)).WasApproved "Approved"
            Expect.isFalse (QuorumResult.Rejected (2, 2, 3)).WasApproved "Rejected"
            Expect.isFalse (QuorumResult.Inconclusive (1, 2, 3)).WasApproved "Inconclusive"
        }

        test "WasRejected is true only for Rejected" {
            Expect.isFalse (QuorumResult.Approved (2, 2, 3)).WasRejected "Approved"
            Expect.isTrue (QuorumResult.Rejected (2, 2, 3)).WasRejected "Rejected"
            Expect.isFalse (QuorumResult.Inconclusive (1, 2, 3)).WasRejected "Inconclusive"
        }
    ]

// =============================================================================
// TwoOfThree Voting Tests (SC-QUORUM-001, SC-SIL6-001)
// =============================================================================

[<Tests>]
let twoOfThreeTests =
    testList "TwoOfThreeVoting" [
        test "All true returns Unanimous true" {
            match TwoOfThreeVoting.vote true true true with
            | TwoOfThreeResult.Unanimous true -> ()
            | _ -> failtest "Expected Unanimous true"
        }

        test "All false returns Unanimous false" {
            match TwoOfThreeVoting.vote false false false with
            | TwoOfThreeResult.Unanimous false -> ()
            | _ -> failtest "Expected Unanimous false"
        }

        test "Two true, one false returns TwoOfThree true" {
            match TwoOfThreeVoting.vote true true false with
            | TwoOfThreeResult.TwoOfThree (true, dissenter) ->
                Expect.equal dissenter "arbiter" "Dissenter should be arbiter"
            | _ -> failtest "Expected TwoOfThree true"
        }

        test "One true, two false returns TwoOfThree false" {
            match TwoOfThreeVoting.vote true false false with
            | TwoOfThreeResult.TwoOfThree (false, dissenter) ->
                Expect.equal dissenter "primary" "Dissenter should be primary"
            | _ -> failtest "Expected TwoOfThree false"
        }

        test "Primary dissenter identified correctly" {
            match TwoOfThreeVoting.vote false true true with
            | TwoOfThreeResult.TwoOfThree (true, dissenter) ->
                Expect.equal dissenter "primary" "Primary is dissenter"
            | _ -> failtest "Expected TwoOfThree with primary dissenter"
        }

        test "Secondary dissenter identified correctly" {
            match TwoOfThreeVoting.vote true false true with
            | TwoOfThreeResult.TwoOfThree (true, dissenter) ->
                Expect.equal dissenter "secondary" "Secondary is dissenter"
            | _ -> failtest "Expected TwoOfThree with secondary dissenter"
        }

        test "Result Value is Some for decided" {
            let result = TwoOfThreeVoting.vote true true false
            Expect.isSome result.Value "Value should be Some"
            Expect.equal result.Value (Some true) "Value should be true"
        }

        test "IsApproved true for majority true" {
            let result = TwoOfThreeVoting.vote true true false
            Expect.isTrue result.IsApproved "Should be approved"
        }

        test "IsApproved false for majority false" {
            let result = TwoOfThreeVoting.vote true false false
            Expect.isFalse result.IsApproved "Should not be approved"
        }

        test "IsDecided true for all voting outcomes" {
            Expect.isTrue (TwoOfThreeVoting.vote true true true).IsDecided "All true"
            Expect.isTrue (TwoOfThreeVoting.vote false false false).IsDecided "All false"
            Expect.isTrue (TwoOfThreeVoting.vote true true false).IsDecided "2-1 true"
            Expect.isTrue (TwoOfThreeVoting.vote true false false).IsDecided "1-2 false"
        }
    ]

// =============================================================================
// ChannelVote Tests
// =============================================================================

[<Tests>]
let channelVoteTests =
    testList "ChannelVote" [
        test "create has correct defaults" {
            let vote = ChannelVote.create "primary" true
            Expect.equal vote.ChannelId "primary" "Channel ID"
            Expect.isTrue vote.Value "Value"
            Expect.equal vote.Confidence 1.0 "Confidence"
            Expect.isNone vote.Diagnostics "No diagnostics"
        }

        test "timestamp is not in future" {
            let vote = ChannelVote.create "primary" true
            Expect.isLessThanOrEqual vote.Timestamp (DateTimeOffset.UtcNow.AddSeconds(1.0)) "Timestamp"
        }
    ]

// =============================================================================
// voteChannels Tests
// =============================================================================

[<Tests>]
let voteChannelsTests =
    testList "voteChannels" [
        test "returns ChannelFailure for wrong number of votes" {
            let votes = [ChannelVote.create "primary" true]
            match TwoOfThreeVoting.voteChannels votes with
            | TwoOfThreeResult.ChannelFailure (_, reason) ->
                Expect.stringContains reason "Expected 3" "Error message"
            | _ -> failtest "Expected ChannelFailure"
        }

        test "returns ChannelFailure for missing channel" {
            let votes = [
                ChannelVote.create "primary" true
                ChannelVote.create "secondary" true
                ChannelVote.create "unknown" true  // Wrong channel name
            ]
            match TwoOfThreeVoting.voteChannels votes with
            | TwoOfThreeResult.ChannelFailure (missing, _) ->
                Expect.contains missing "arbiter" "Missing arbiter"
            | _ -> failtest "Expected ChannelFailure"
        }

        test "returns correct result for valid votes" {
            let votes = [
                ChannelVote.create "primary" true
                ChannelVote.create "secondary" true
                ChannelVote.create "arbiter" false
            ]
            match TwoOfThreeVoting.voteChannels votes with
            | TwoOfThreeResult.TwoOfThree (true, "arbiter") -> ()
            | _ -> failtest "Expected TwoOfThree true with arbiter dissenter"
        }
    ]

// =============================================================================
// VoteMessage Tests
// =============================================================================

[<Tests>]
let voteMessageTests =
    testList "VoteMessage" [
        test "create has correct fields" {
            let vote = VoteMessage.create "quorum-1" "node-1" true
            Expect.equal vote.QuorumId "quorum-1" "Quorum ID"
            Expect.equal vote.NodeId "node-1" "Node ID"
            Expect.isTrue vote.Vote "Vote"
            Expect.equal vote.Confidence 1.0 "Default confidence"
            Expect.isNone vote.Reason "No reason"
        }

        test "nonce is unique per creation" {
            let v1 = VoteMessage.create "q1" "n1" true
            let v2 = VoteMessage.create "q1" "n1" true
            Expect.notEqual v1.Nonce v2.Nonce "Nonces should be different"
        }

        test "createWithConfidence sets confidence" {
            let vote = VoteMessage.createWithConfidence "q1" "n1" true 0.75
            Expect.equal vote.Confidence 0.75 "Confidence"
        }

        test "createWithReason sets reason" {
            let vote = VoteMessage.createWithReason "q1" "n1" true "approved"
            Expect.equal vote.Reason (Some "approved") "Reason"
        }
    ]

// =============================================================================
// QuorumSession Tests
// =============================================================================

[<Tests>]
let quorumSessionTests =
    testList "QuorumSession" [
        test "initial state is not decided" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            Expect.isFalse session.IsDecided "Not decided initially"
            Expect.isNone session.Result "No result initially"
            Expect.equal session.VoteCount 0 "No votes initially"
        }

        test "CastVote records own vote" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            let vote = session.CastVote(true)
            Expect.equal session.VoteCount 1 "One vote"
            Expect.equal vote.NodeId "n1" "Correct node ID"
            Expect.isTrue vote.Vote "Vote value"
        }

        test "RecordVote accepts votes with matching quorum ID" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            let vote = VoteMessage.create "q1" "n2" true
            session.RecordVote(vote)
            Expect.equal session.VoteCount 1 "Vote recorded"
        }

        test "RecordVote ignores votes with wrong quorum ID" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            let vote = VoteMessage.create "other" "n2" true
            session.RecordVote(vote)
            Expect.equal session.VoteCount 0 "Vote ignored"
        }

        test "RecordVote ignores duplicate nonces" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            let vote = VoteMessage.create "q1" "n2" true
            session.RecordVote(vote)
            session.RecordVote(vote)  // Same nonce
            Expect.equal session.VoteCount 1 "Only one vote counted"
        }

        test "Session becomes decided when quorum reached" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            session.CastVote(true) |> ignore
            session.RecordVote(VoteMessage.create "q1" "n2" true)
            Expect.isTrue session.IsDecided "Decided after quorum"
            Expect.isSome session.Result "Has result"
        }

        test "Votes property returns recorded votes" {
            let session = QuorumSession("q1", "n1", 3, 5000)
            session.CastVote(true) |> ignore
            session.RecordVote(VoteMessage.create "q1" "n2" false)
            Expect.equal session.Votes.Length 2 "Two votes"
        }
    ]

// =============================================================================
// BarrierSession Tests
// =============================================================================

[<Tests>]
let barrierSessionTests =
    testList "BarrierSession" [
        test "initial state is not released" {
            let barrier = BarrierSession("b1", "n1", 3, 5000)
            Expect.isFalse barrier.IsReleased "Not released initially"
            Expect.equal barrier.ArrivedCount 0 "No arrivals"
        }

        test "Arrive records this node" {
            let barrier = BarrierSession("b1", "n1", 3, 5000)
            barrier.Arrive()
            Expect.equal barrier.ArrivedCount 1 "One arrival"
            Expect.contains barrier.ArrivedNodes "n1" "This node arrived"
        }

        test "RecordArrival accepts other nodes" {
            let barrier = BarrierSession("b1", "n1", 3, 5000)
            barrier.RecordArrival("n2")
            Expect.equal barrier.ArrivedCount 1 "One arrival"
            Expect.contains barrier.ArrivedNodes "n2" "Other node arrived"
        }

        test "Barrier releases when all nodes arrive" {
            let barrier = BarrierSession("b1", "n1", 3, 5000)
            barrier.Arrive()
            barrier.RecordArrival("n2")
            barrier.RecordArrival("n3")
            Expect.isTrue barrier.IsReleased "Released after all arrive"
        }
    ]
