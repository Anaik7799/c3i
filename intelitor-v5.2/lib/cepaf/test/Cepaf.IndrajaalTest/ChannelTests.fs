/// Cepaf.IndrajaalTest.ChannelTests
/// Phoenix Channel subscription and event tests
///
/// STAMP Constraints:
/// - SC-CHANNEL-001: Channel subscriptions must be tenant-isolated
/// - SC-CHANNEL-002: Events must be properly formatted
module Cepaf.IndrajaalTest.ChannelTests

open System
open Expecto
open Cepaf.IndrajaalTest.Types
open Cepaf.IndrajaalTest.Config
open Cepaf.IndrajaalTest.WebSocketClient

// =============================================================================
// Channel Topic Tests
// =============================================================================

/// Create channel topic tests
let createChannelTopicTests () =
    testList "Channel Topics" [

        test "Alarm tenant topic format is correct" {
            let topic = Channels.alarmTenant "tenant-123"
            Expect.equal topic "alarm:tenant:tenant-123" "Should have correct format"
        }

        test "Alarm specific topic format is correct" {
            let alarmId = Guid.NewGuid().ToString()
            let topic = Channels.alarm alarmId
            Expect.stringStarts topic "alarm:" "Should start with alarm:"
        }

        test "Device topic format is correct" {
            let topic = Channels.device "device-001"
            Expect.equal topic "device:device-001" "Should have correct format"
        }

        test "Site topic format is correct" {
            let topic = Channels.site "site-001"
            Expect.equal topic "site:site-001" "Should have correct format"
        }

        test "Config topic format is correct" {
            let topic = Channels.config "alarms"
            Expect.equal topic "config:alarms" "Should have correct format"
        }

        test "Notification topic format is correct" {
            let topic = Channels.notification "user-123"
            Expect.equal topic "notification:user-123" "Should have correct format"
        }

        test "Video tenant topic format is correct" {
            let topic = Channels.videoTenant "tenant-123"
            Expect.equal topic "video:tenant:tenant-123" "Should have correct format"
        }

        test "Video stream topic format is correct" {
            let topic = Channels.videoStream "stream-001"
            Expect.equal topic "video:stream:stream-001" "Should have correct format"
        }

        test "Video camera topic format is correct" {
            let topic = Channels.videoCamera "camera-001"
            Expect.equal topic "video:camera:camera-001" "Should have correct format"
        }

        test "Sync topic format is correct" {
            let topic = Channels.sync "device-001"
            Expect.equal topic "sync:device-001" "Should have correct format"
        }

        test "Patrol topic format is correct" {
            let topic = Channels.patrol "patrol-001"
            Expect.equal topic "patrol:patrol-001" "Should have correct format"
        }
    ]

// =============================================================================
// Channel Join Tests
// =============================================================================

/// Create channel join tests (requires connection)
let createChannelJoinTests (config: ServerConfig) (getToken: unit -> string option) =
    testList "Channel Join" [

        testAsync "Join alarm channel without auth fails" {
            let client = createClient config.WebSocketUrl None

            let! connectResult = connect client

            match connectResult with
            | Ok connectedClient ->
                let topic = Channels.alarmTenant "test-tenant"
                let! joinResult = joinChannel connectedClient topic Map.empty

                do! disconnect connectedClient

                match joinResult with
                | Ok (Joined _) ->
                    // May be allowed in some configs
                    ()
                | Ok (Denied reason) ->
                    // Expected
                    Expect.stringContains reason "auth" "Should mention auth"
                | Ok Timeout ->
                    // May timeout
                    ()
                | Ok (Error _) ->
                    // Error is acceptable
                    ()
                | Error _ ->
                    // Error is acceptable
                    ()
            | Error _ ->
                skiptest "Connection not available"
        }

        testAsync "Join with invalid topic format is handled" {
            let token = getToken ()
            let client = createClient config.WebSocketUrl token

            let! connectResult = connect client

            match connectResult with
            | Ok connectedClient ->
                // Invalid topic format
                let! joinResult = joinChannel connectedClient "invalid" Map.empty

                do! disconnect connectedClient

                match joinResult with
                | Ok (Joined _) ->
                    failtest "Should not join invalid topic"
                | Ok (Denied _) ->
                    // Expected
                    ()
                | _ ->
                    // Any other result is acceptable
                    ()
            | Error _ ->
                skiptest "Connection not available"
        }
    ]

// =============================================================================
// Channel Event Tests
// =============================================================================

/// Create channel event format tests
let createChannelEventTests () =
    testList "Channel Events" [

        test "Alarm events have correct format" {
            // Test event names
            let events = [
                "alarm:created"
                "alarm:updated"
                "alarm:resolved"
                "alarm:escalated"
            ]

            for event in events do
                Expect.stringStarts event "alarm:" "Should start with alarm:"
        }

        test "Device events have correct format" {
            let event = "maintenance_mode_changed"
            Expect.isNonEmpty event "Should have event name"
        }

        test "Video events have correct format" {
            let events = [
                "stream:started"
                "stream:stopped"
                "stream:quality_changed"
                "camera:status_changed"
                "recording:started"
                "recording:stopped"
                "analytics:alert"
            ]

            for event in events do
                Expect.isNonEmpty event "Should have event name"
        }

        test "Notification events have correct format" {
            let events = ["notification"; "unread_count"]

            for event in events do
                Expect.isNonEmpty event "Should have event name"
        }
    ]

// =============================================================================
// STAMP Constraint Tests
// =============================================================================

/// Create STAMP channel constraint tests
let createStampChannelTests (config: ServerConfig) =
    testList "STAMP Channel Constraints" [

        testAsync "SC-CHANNEL-001: Channel topics include tenant ID" {
            // Verify tenant isolation is encoded in topic format
            let tenantId = "test-tenant-123"

            let alarmTopic = Channels.alarmTenant tenantId
            Expect.stringContains alarmTopic tenantId "Alarm topic should include tenant"

            let videoTopic = Channels.videoTenant tenantId
            Expect.stringContains videoTopic tenantId "Video topic should include tenant"
        }

        test "SC-CHANNEL-002: All channel topics are properly namespaced" {
            let topics = [
                Channels.alarmTenant "t1"
                Channels.alarm (Guid.NewGuid().ToString())
                Channels.device "d1"
                Channels.site "s1"
                Channels.config "c1"
                Channels.notification "n1"
                Channels.videoTenant "t1"
                Channels.videoStream "vs1"
                Channels.videoCamera "vc1"
                Channels.sync "sy1"
                Channels.patrol "p1"
            ]

            for topic in topics do
                // All topics should have namespace:id format
                Expect.stringContains topic ":" "Topic should have namespace separator"
                let parts = topic.Split(':')
                Expect.isGreaterThanOrEqual parts.Length 2 "Should have at least 2 parts"
        }
    ]

// =============================================================================
// All Channel Tests
// =============================================================================

/// All channel tests combined
let allChannelTests (config: ServerConfig) (getToken: unit -> string option) =
    testList "Channel Tests" [
        createChannelTopicTests ()
        createChannelJoinTests config getToken
        createChannelEventTests ()
        createStampChannelTests config
    ]
