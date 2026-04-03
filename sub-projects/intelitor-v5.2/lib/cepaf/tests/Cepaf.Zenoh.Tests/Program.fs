// =============================================================================
// Program.fs - Test Runner Entry Point
// =============================================================================
// STAMP: SC-TDG-001, SC-TDG-002
// AOR: AOR-TEST-001
// Criticality: Level 1 (CRITICAL) - Test Execution Entry Point
// =============================================================================

module Cepaf.Zenoh.Tests.Program

open Expecto

[<EntryPoint>]
let main args =
    // Run all tests with default configuration
    runTestsWithCLIArgs [] args (testList "Zenoh Test Suite" [
        PropertyTests.zenohTypesProperties
        PropertyTests.zenohEnvelopeProperties
        PropertyTests.quorumProperties
        PropertyTests.twoOfThreeProperties
        PropertyTests.voteMessageProperties
        PropertyTests.federationProperties
        PropertyTests.sil6SafetyProperties
        ZenohTypesTests.connectionStatusTests
        ZenohTypesTests.sessionConfigTests
        ZenohTypesTests.publisherConfigTests
        ZenohTypesTests.subscriberConfigTests
        ZenohTypesTests.zenohSampleTests
        ZenohTypesTests.zenohErrorTests
        ZenohTypesTests.zenohHealthTests
        ZenohTypesTests.lifecycleEventTests
        ZenohQuorumTests.quorumCalculatorTests
        ZenohQuorumTests.quorumResultTests
        ZenohQuorumTests.twoOfThreeTests
        ZenohQuorumTests.channelVoteTests
        ZenohQuorumTests.voteChannelsTests
        ZenohQuorumTests.voteMessageTests
        ZenohQuorumTests.quorumSessionTests
        ZenohQuorumTests.barrierSessionTests
        SIL6SafetyTests.pfhModelingTests
        SIL6SafetyTests.neuralImmuneResponseTests
        SIL6SafetyTests.twoOfThreeIntegrityTests
        SIL6SafetyTests.connectionTimeoutTests
        SIL6SafetyTests.reconnectDelayTests
        SIL6SafetyTests.reconnectionAttemptsTests
        SIL6SafetyTests.quorumFormulaTests
        SIL6SafetyTests.callbackTimeoutTests
        SIL6SafetyTests.dualChannelTests
        SIL6SafetyTests.replayProtectionTests
        SIL6SafetyTests.stateMachineSafetyTests
        SIL6SafetyTests.errorHandlingSafetyTests
    ])
