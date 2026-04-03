# BDD Feature: Zenoh 7-Level Integration
# Comprehensive testing of Zenoh NIF across all fractal layers (L1-L7)
# STAMP: SC-ZENOH-*, SC-NIF-*, SC-BRIDGE-*, SC-SIL4-*, SC-FRAC-*
# AOR: AOR-ZENOH-*, AOR-NIF-*, AOR-MESH-*

@zenoh_integration @sil6 @safety-critical
Feature: Zenoh 7-Level Integration
  As a biomorphic safety-critical system
  I want Zenoh NIF to provide reliable pub/sub across all 7 fractal layers
  So that real-time coordination and observability are guaranteed

# ============================================================================
# L1: FFI LAYER - Native Handle Management
# ============================================================================

@l1_ffi @memory_safety @critical
Feature: L1 FFI Layer - Native Handle Creation and Management
  All Zenoh NIF operations must maintain memory safety through the FFI boundary

  Background:
    Given the Zenoh NIF library is compiled with Rustler 0.37.2+
    And Cargo is available in PATH
    And the system has no orphaned Zenoh handles

  # SC-NIF-001: Native Binding Safety
  @sc-nif-001 @handle_creation
  Scenario: Create native Zenoh session handle
    Given a valid Zenoh configuration map
      """
      %{
        "connect" => ["tcp/127.0.0.1:7447"],
        "mode" => "client",
        "multicast_scouting" => true
      }
      """
    When I call Indrajaal.Native.Zenoh.open_session/1
    Then the function should return {:ok, session_ref}
    And session_ref should be a Rustler ResourceArc
    And the session should be registered in the BEAM VM resource counter
    And subsequent calls should use the same session_ref

  # SC-NIF-002: Resource Cleanup on Drop
  @sc-nif-002 @resource_lifecycle
  Scenario: Session handle is cleaned up on process exit
    Given an open Zenoh session
    When the owning process exits
    Then the native session resource should be deallocated
    And no memory leak should be detected by valgrind
    And the Zenoh session should close gracefully

  # SC-NIF-003: Error Code Translation
  @sc-nif-003 @error_handling
  Scenario: Native error codes are translated to Elixir atoms
    Given a configuration with invalid endpoint "invalid://endpoint"
    When I call open_session/1
    Then the function should return {:error, reason}
    And reason should be a descriptive atom like :connection_refused
    And not a raw C error code

  # SC-NIF-004: Dirty Scheduler Compliance
  @sc-nif-004 @performance @scheduler
  Scenario: I/O operations execute on dirty scheduler
    Given a running Zenoh session
    When I call Indrajaal.Native.Zenoh.publish/3 with large payload
    Then the NIF should be scheduled with "DirtyCpu"
    And the BEAM scheduler should not block on I/O
    And message latency should be <1ms

  # SC-NIF-005: Type Safety at FFI Boundary
  @sc-nif-005 @type_safety
  Scenario: Invalid argument types are rejected at FFI boundary
    Given a Zenoh session reference
    When I call publish with invalid argument types:
      | Arg | Type | Expected Error |
      | session | string | {:error, :bad_arg} |
      | key_expr | number | {:error, :bad_arg} |
      | payload | atom | {:error, :bad_arg} |
    Then each call should fail with :bad_arg
    And the BEAM VM should not crash
    And error context should indicate the problematic argument

  # SC-NIF-006: Concurrent Handle Safety
  @sc-nif-006 @concurrent @thread_safety
  Scenario: Multiple threads access same session handle safely
    Given 10 concurrent tasks referencing the same session
    When each task calls Zenoh NIF functions simultaneously
    Then no race conditions should occur
    And no segmentation faults
    And message delivery should be complete and correct

# ============================================================================
# L2: CORE LAYER - Session and Pub/Sub Operations
# ============================================================================

@l2_core @pubsub @operational
Feature: L2 Core Layer - Session and Pub/Sub Core Operations
  Session management, publishing, and subscription form the foundation

  Background:
    Given Zenoh router is running on tcp/127.0.0.1:7447
    And we have a working Zenoh session

  # SC-ZENOH-SES-001: Single Session per Node
  @sc-zenoh-ses-001 @session_management
  Scenario: Single authoritative session per node
    When I create multiple session open attempts
    Then only one should succeed
    And subsequent attempts should return the existing session
    And all threads should share the same session reference

  # SC-ZENOH-SES-002: Session Connection Options
  @sc-zenoh-ses-002 @configuration
  Scenario: Session accepts various connection configurations
    When I create sessions with configurations:
      | Mode | Connect | Multicast | Expected |
      | client | tcp/zenoh:7447 | true | {:ok, session} |
      | peer | tcp/zenoh:7447 | false | {:ok, session} |
      | router | tcp/zenoh:7447 | true | {:ok, session} |
      | client | tcp/127.0.0.1:7447 | false | {:ok, session} |
    Then each configuration should be accepted
    And the session should connect to the specified endpoint
    And multicast discovery should be enabled/disabled accordingly

  # SC-ZENOH-SES-003: Graceful Shutdown with Drain
  @sc-zenoh-ses-003 @shutdown @graceful
  Scenario: Session closes gracefully with in-flight message drain
    Given a session with 100 pending messages
    When I call Indrajaal.Native.Zenoh.close_session/1
    Then all pending messages should be flushed
    And the session should acknowledge receipt on subscribers
    And close should complete within 5 seconds
    And the native resource should be freed

  # SC-PUB-001: Publisher Creation and Disposal
  @sc-pub-001 @publisher @lifecycle
  Scenario: Create and dispose publisher for topic
    When I create a publisher for "indrajaal/test/l2"
    Then the publisher should be a valid resource reference
    And I should be able to publish messages
    When I dispose the publisher
    Then subsequent publishes should fail with :not_found
    And the resource should be freed

  # SC-PUB-002: Message Publishing
  @sc-pub-002 @publish @core
  Scenario: Publish message to topic
    Given a publisher for "indrajaal/metrics/cpu"
    When I publish payload "{ cpu: 45.2 }"
    Then the message should be delivered immediately
    And subscribers should receive the message
    And no acknowledgment should be required
    And throughput should exceed 1000 msg/sec

  # SC-PUB-003: Batch Publishing
  @sc-pub-003 @batch @performance
  Scenario: Batch publish multiple messages atomically
    Given a publisher for "indrajaal/batch/test"
    When I publish batch of 100 messages
      | Message | Payload | Timestamp |
      | 1 | data_1 | 1000000 |
      | 2 | data_2 | 1000001 |
      | ... | ... | ... |
      | 100 | data_100 | 1000099 |
    Then all 100 messages should be delivered
    And message order should be preserved
    And latency should be <50ms for entire batch
    And no messages should be lost

  # SC-SUB-001: Subscriber Creation
  @sc-sub-001 @subscriber @lifecycle
  Scenario: Create subscriber for topic pattern
    When I create subscriber for "indrajaal/health/**"
    Then the subscriber should be a valid resource
    And it should accept wildcard patterns
    And the subscription should be registered with Zenoh router
    And I should receive a subscription confirmation

  # SC-SUB-002: Message Reception
  @sc-sub-002 @subscribe @receive
  Scenario: Receive published messages
    Given a subscriber for "indrajaal/test/messages"
    When a message is published to "indrajaal/test/messages"
    Then I should receive the message via callback
    And the callback should include key expression and payload
    And the callback should receive timestamp metadata

  # SC-SUB-003: Subscriber Cleanup
  @sc-sub-003 @unsubscribe @lifecycle
  Scenario: Unsubscribe and dispose subscriber
    Given an active subscriber
    When I dispose the subscriber
    Then subsequent messages should not trigger callbacks
    And the subscription should be removed from Zenoh
    And the resource should be freed
    And no memory leaks

  # SC-SUB-004: Multiple Concurrent Subscribers
  @sc-sub-004 @concurrent @fan_out
  Scenario: Multiple subscribers receive same message
    When 5 subscribers listen to "indrajaal/broadcast/alert"
    And a message is published
    Then all 5 subscribers should receive the message
    And messages should arrive in order
    And no message loss or duplication

  # SC-QRY-001: Query Store Data
  @sc-qry-001 @query @read
  Scenario: Query stored data from Zenoh store
    Given Zenoh has stored data under "indrajaal/kpi/**"
    When I call Indrajaal.Native.Zenoh.get/2 with pattern
    Then I should receive all matching key-value pairs
    And results should include metadata (timestamp, source)
    And query should complete within 100ms

  # SC-QRY-002: Query with Timeout
  @sc-qry-002 @query @timeout
  Scenario: Query with timeout protection
    Given Zenoh router is slow to respond
    When I call get_timeout with timeout_ms = 500
    Then the operation should timeout after 500ms
    And return {:error, :timeout}
    And not block the calling thread

# ============================================================================
# L3: ENVELOPE LAYER - Type-Safe Message Serialization
# ============================================================================

@l3_envelope @serialization @type_safety
Feature: L3 Envelope Layer - Type-Safe Message Serialization
  Messages must be serialized safely with schema validation

  Background:
    Given a working Zenoh session
    And message serialization module is loaded

  # SC-ENV-001: Envelope Structure
  @sc-env-001 @schema @serialization
  Scenario: Message envelope includes type information
    When I create envelope for metric message
      """
      %{
        "version" => 1,
        "type" => "metric",
        "payload" => %{"cpu" => 45.2},
        "timestamp" => 1704873600000,
        "source" => "node-1"
      }
      """
    Then envelope should serialize to valid JSON
    And envelope should deserialize without data loss
    And type field should enable runtime validation
    And schema version should enable forward compatibility

  # SC-ENV-002: Schema Validation
  @sc-env-002 @validation @schema
  Scenario: Reject envelopes with invalid schema
    Given valid message schema for "metric" type
    When I try to deserialize malformed envelope
      | Issue | Example |
      | missing_required_field | no "type" field |
      | wrong_type | "payload" is string not object |
      | invalid_version | version 999 |
    Then deserialization should fail
    And error should indicate schema violation
    And original message should not be processed

  # SC-ENV-003: Versioned Envelopes
  @sc-env-003 @versioning @compatibility
  Scenario: Handle multiple envelope versions
    Given messages with versions 1, 2, and 3
    When I deserialize all versions
    Then version 1 should be parsed with default values
    And version 2 should be parsed correctly
    And version 3 should be parsed correctly
    And migration from v1→v2→v3 should be transparent

  # SC-ENV-004: Binary vs JSON Envelopes
  @sc-env-004 @encoding @format
  Scenario: Support both binary and JSON encodings
    When I serialize envelope as JSON
    Then payload should be human-readable
    And file size should be reasonable
    When I serialize envelope as binary
    Then payload size should be 30-40% smaller
    And both formats should deserialize to identical objects

# ============================================================================
# L4: BRIDGE LAYER - Elixir-F# Message Passing
# ============================================================================

@l4_bridge @interop @performance
Feature: L4 Bridge Layer - Elixir-F# Message Passing
  Messages must traverse between Elixir and F# safely

  Background:
    Given Zenoh session is connected
    And CEPAF F# Cortex is running
    And bridge is initialized

  # SC-BRIDGE-001: Outbound Elixir→F# Message
  @sc-bridge-001 @elixir_to_fsharp @outbound
  Scenario: Elixir publishes message received by F# subscriber
    When I publish Elixir message to "indrajaal/cortex/command"
      """
      %{
        "command" => "analyze",
        "data" => [1, 2, 3, 4, 5],
        "id" => "cmd-123"
      }
      """
    Then CEPAF Cortex should receive the message
    And message should deserialize correctly in F#
    And Cortex should acknowledge receipt
    And round-trip latency should be <50ms

  # SC-BRIDGE-002: Inbound F#→Elixir Message
  @sc-bridge-002 @fsharp_to_elixir @inbound
  Scenario: F# publishes message received by Elixir
    When CEPAF Cortex publishes result to "indrajaal/cortex/response"
      """
      {"result": [1,1,2,3,5,8], "status": "ok"}
      """
    Then Elixir subscriber should receive the message
    And message should deserialize to Elixir map
    And Elixir should process result correctly
    And latency should be <50ms

  # SC-BRIDGE-003: Buffer Management
  @sc-bridge-003 @buffering @flow_control
  Scenario: Bridge manages message buffers under load
    When Elixir publishes 1000 messages rapidly
    And F# processes messages at slower rate
    Then messages should queue in buffer
    And buffer should not overflow
    And oldest messages should be processed first
    And new messages should not be dropped

  # SC-BRIDGE-004: Latency Requirement
  @sc-bridge-004 @performance @latency
  Scenario: Bridge maintains <50ms latency budget
    When I measure message latency for 100 messages
    Then:
      | Metric | Target | Actual |
      | p50 latency | 20ms | <20ms |
      | p95 latency | 40ms | <40ms |
      | p99 latency | 45ms | <45ms |
      | max latency | 50ms | <50ms |
    And 100% of messages should meet latency requirement

  # SC-BRIDGE-005: Zenoh Topic Mapping
  @sc-bridge-005 @topic_mapping @routing
  Scenario: Topics are correctly mapped between systems
    Given Elixir publishes to "indrajaal/cortex/request"
    When message flows through bridge
    Then F# should receive via Zenoh topic "indrajaal/cortex/request"
    When F# responds on "indrajaal/cortex/response"
    Then Elixir should receive via same topic
    And no topic mangling or translation

# ============================================================================
# L5: LIFECYCLE LAYER - Connection State Machine
# ============================================================================

@l5_lifecycle @state_machine @resilience
Feature: L5 Lifecycle Layer - Connection State Machine
  System manages connection state with reconnection and health monitoring

  Background:
    Given a Zenoh router at tcp/127.0.0.1:7447

  # SC-LIFE-001: Initial Connection
  @sc-life-001 @startup @connection
  Scenario: Initialize connection state machine
    When I create a lifecycle manager
    Then initial state should be :disconnected
    When I call connect()
    Then state should transition to :connecting
    Then state should transition to :connected
    And health_check() should return {:ok, healthy}

  # SC-LIFE-002: Connection Lost Detection
  @sc-life-002 @detection @failure
  Scenario: Detect connection loss
    Given a connected session
    When Zenoh router stops
    Then connection should be detected as lost within 5 seconds
    And state should transition to :disconnected
    And health_check() should return {:error, :disconnected}

  # SC-LIFE-003: Automatic Reconnection with Backoff
  @sc-life-003 @reconnect @backoff
  Scenario: Reconnect with exponential backoff
    Given connection is disconnected
    When reconnection logic is triggered
    Then retry schedule should be:
      | Attempt | Wait Time | Cumulative |
      | 1 | 100ms | 100ms |
      | 2 | 200ms | 300ms |
      | 3 | 400ms | 700ms |
      | 4 | 800ms | 1500ms |
      | 5 | 1600ms | 3100ms |
    And max backoff should cap at 10 seconds
    And total retry window should be 5 minutes

  # SC-LIFE-004: Successful Reconnection
  @sc-life-004 @recovery @resilience
  Scenario: Recover to connected state after temporary outage
    Given connection is active
    When Zenoh router restarts
    Then connection should be detected as lost
    When Zenoh router comes back online
    Then lifecycle should detect recovery within 10 seconds
    And state should return to :connected
    And pending messages should be retransmitted

  # SC-LIFE-005: Persistent Connection Failure
  @sc-life-005 @failure @escalation
  Scenario: Escalate after max retries exhausted
    Given all reconnection attempts are exhausted
    When max_retries = 5 is reached
    Then state should transition to :failed
    And Sentinel should be notified
    And alert should be generated with severity :critical
    And operator intervention required flag should be set

  # SC-LIFE-006: Health Monitoring
  @sc-life-006 @health @monitoring
  Scenario: Continuous health monitoring
    Given a connected session
    When health check runs every 10 seconds
    Then:
      | Check | Verifies |
      | session_valid | NIF resource still exists |
      | router_reachable | Can reach Zenoh router |
      | subscribers_active | Callbacks fire correctly |
      | throughput | Messages flowing at expected rate |
    And all checks should pass
    And health_score should be >= 95%

  # SC-LIFE-007: Graceful Shutdown
  @sc-life-007 @shutdown @cleanup
  Scenario: Graceful shutdown sequence
    Given a fully connected lifecycle
    When shutdown() is called
    Then state should transition to :shutting_down
    And all pending operations should complete
    And subscriptions should be unsubscribed
    And session should be closed
    And state should transition to :disconnected
    And all resources should be freed

# ============================================================================
# L6: CLUSTER LAYER - Quorum Voting and Consensus
# ============================================================================

@l6_cluster @quorum @consensus @sil4
Feature: L6 Cluster Layer - Quorum Voting and 2oo3 Consensus
  Multiple nodes must achieve consensus safely

  Background:
    Given 3 Zenoh routers running on ports 7447, 7448, 7449
    And proxy connecting all three routers
    And cluster monitoring enabled
    And quorum_size = 2 (2oo3)

  # SC-QUORUM-001: Quorum Achievement
  @sc-quorum-001 @consensus @quorum
  Scenario: All 3 nodes establish quorum
    When cluster boots and all 3 nodes join
    Then each node should see the other 2 nodes
    And quorum voting should be enabled
    And consensus_status should be :achieved
    And leader election should complete
    And cluster_version should be agreed

  # SC-QUORUM-002: Single Node Failure
  @sc-quorum-002 @degraded @failover
  Scenario: Quorum maintained with 1 node down
    Given 3-node cluster with quorum established
    When node-1 crashes
    Then node-2 and node-3 should detect failure within 3 seconds
    And quorum_status should be :degraded
    And cluster should remain operational
    And messages should continue flowing
    And no split-brain condition
    And alerts should be generated

  # SC-QUORUM-003: Quorum Lost
  @sc-quorum-003 @quorum_loss @failure
  Scenario: System detects quorum loss (2+ nodes down)
    Given 3-node cluster with quorum
    When node-1 and node-2 crash
    Then node-3 should detect failure
    And quorum_status should transition to :lost
    And write operations should block
    And read-only mode should activate
    And priority alert should trigger
    And operator notification should be immediate

  # SC-QUORUM-004: Vote Replay Protection
  @sc-quorum-004 @vote_safety @anti_replay
  Scenario: Prevent vote replay attacks
    Given 3-node cluster with votes logged
    When replaying old vote messages
    Then system should detect stale votes by:
      | Check | Mechanism |
      | sequence_number | Increment counter |
      | timestamp | Compare to system time |
      | nonce | Unique per vote instance |
      | signature | Cryptographic verification |
    And replayed votes should be rejected
    And log should show rejection reason
    And security alert should be generated

  # SC-QUORUM-005: Leader Election
  @sc-quorum-005 @election @leadership
  Scenario: Elect leader from 3 node quorum
    Given 3 nodes with equal priority
    When leader election runs
    Then all nodes should agree on leader
    And elected leader should have:
      | Property | Value |
      | lease_duration | 30 seconds |
      | term_number | monotonically increasing |
      | heartbeat_interval | 5 seconds |
    And if leader dies, new election completes within 15 seconds
    And no split-brain scenarios

  # SC-QUORUM-006: Message Ordering in Quorum
  @sc-quorum-006 @ordering @consistency
  Scenario: Messages delivered in order across quorum
    When 3 nodes receive messages M1, M2, M3, M4, M5
    And messages arrive in different order at each node
    Then:
      | Node | Delivery Order |
      | node-1 | M1, M2, M3, M4, M5 |
      | node-2 | M1, M2, M3, M4, M5 |
      | node-3 | M1, M2, M3, M4, M5 |
    And all nodes deliver in canonical order
    And no reordering in distributed system

  # SC-QUORUM-007: Two-Phase Commit
  @sc-quorum-007 @commit @atomicity
  Scenario: Two-phase commit across quorum
    When transaction T1 is proposed
    Then Phase 1 (Prepare):
      - All 3 nodes vote to accept or reject
      - Votes are logged durably
      - Majority (2 of 3) required to proceed
    Then Phase 2 (Commit):
      - Leader broadcasts commit
      - All nodes execute T1
      - Acknowledgments collected
      - Transaction considered durable
    And if Phase 2 communication fails, rollback occurs
    And all nodes see consistent final state

# ============================================================================
# L7: FEDERATION LAYER - Cross-Holon Communication
# ============================================================================

@l7_federation @cross_holon @integration @sil6
Feature: L7 Federation Layer - Cross-Holon Attestation & Protocol Negotiation
  Multiple holons (instances) coordinate safely

  Background:
    Given holon-1 (Indrajaal primary) is running
    And holon-2 (Indrajaal replica) is running
    And holon-3 (External system) wants to join federation
    And Zenoh federation mesh is active

  # SC-FED-001: Cross-Holon Attestation
  @sc-fed-001 @attestation @authentication
  Scenario: Holons attest to each other hourly
    When holon-1 receives heartbeat from holon-2
    Then holon-1 should verify:
      | Check | Mechanism |
      | identity | Digital certificate |
      | integrity | Hash chain verification |
      | authority | Capability token |
      | liveness | Timestamp freshness |
    And verification should complete within 100ms
    And attestation should be logged to federation ledger
    And trust_score for holon-2 should increase
    And failed attestation triggers alert

  # SC-FED-002: Protocol Negotiation
  @sc-fed-002 @handshake @compatibility
  Scenario: Negotiate compatible protocol version
    Given holon-1 (v21.2.0) and holon-2 (v21.1.5) meet
    When federation_join is requested
    Then holon-1 should propose protocol_version 21.2.0
    When holon-2 responds with supported 21.0.0-21.1.5
    Then they should find common ground 21.1.5
    And negotiate message format compatibility:
      | Feature | holon-1 | holon-2 | Agreed |
      | envelope_version | 3 | 2 | 2 |
      | compression | zstd | gzip | gzip |
      | encoding | msgpack | json | json |
    And establish protocol_agreement with agreed version

  # SC-FED-003: Message Routing in Federation
  @sc-fed-003 @routing @distribution
  Scenario: Messages route across holon boundaries
    When holon-1 publishes to "federation/global/alert"
    Then message should be routed to:
      | Holon | Route | Latency |
      | holon-1 | local | 1ms |
      | holon-2 | tcp/holon-2:7447 | 50ms |
      | holon-3 | relay through holon-2 | 100ms |
    And routing should follow shortest path
    And message should not loop back to sender
    And routing table should age out dead routes

  # SC-FED-004: Federation Join Handshake
  @sc-fed-004 @join @bootstrapping
  Scenario: New holon joins federation safely
    Given holon-3 starting up and wants to join
    When holon-3 publishes join_request to "federation/join"
    Then holon-1 and holon-2 should receive request
    And they should:
      1. Verify holon-3 identity and credentials
      2. Check holon-3 is not already member
      3. Verify holon-3 version compatibility
      4. Check resource availability
      5. Vote on acceptance (2oo3)
    And on acceptance:
      - holon-3 receives federation_state snapshot
      - holon-3 syncs to latest federation_version
      - holon-3 becomes active member
      - existence is broadcast to all members
    And on rejection:
      - holon-3 receives reason in :federation_rejected message
      - holon-3 enters :quarantine state

  # SC-FED-005: Federation Member Leave
  @sc-fed-005 @leave @graceful_exit
  Scenario: Holon leaves federation gracefully
    Given holon-2 is active federation member
    When holon-2 initiates graceful shutdown
    Then holon-2 should:
      1. Publish leave_notification
      2. Drain in-flight messages (up to 10 seconds)
      3. Transfer subscriptions to other members
      4. Submit final state snapshot
      5. Close federation session
    And holon-1 and holon-3 should:
      1. Receive leave_notification
      2. Update membership_list
      3. Redistribute responsibilities
      4. Broadcast new federation_state
      5. Confirm holon-2 offline
    And holon-2 should transition to :disconnected state

  # SC-FED-006: Data Consistency Across Federation
  @sc-fed-006 @consistency @replication
  Scenario: Data replication ensures consistency
    When holon-1 mutates state X at timestamp T1
    Then:
      - Change should be logged to immutable_register
      - Version vector should be incremented
      - Replication message should be published
      - holon-2 should receive and apply change
      - holon-3 should receive and apply change
    And all holons should:
      - Have identical state_hash
      - Agree on version_vector
      - Have consistent federation_timestamp
    And query to any holon returns same result
    And staleness should be < 100ms

  # SC-FED-007: Federation Split and Heal
  @sc-fed-007 @partition @healing
  Scenario: Network partition heals and federation rejoins
    Given holon-1 and holon-2 connected
    And holon-3 isolated from network
    When network partition occurs:
      - holon-1 and holon-2 form subcluster
      - holon-3 detects isolation
    Then:
      - holon-1 and holon-2 maintain quorum
      - holon-3 enters :isolated state
      - holon-3 logs decisions locally but doesn't write remotely
    When network heals:
      - holon-3 detects connectivity restored
      - holon-3 initiates rejoin sequence
      - holon-1 and holon-2 acknowledge
      - holon-3 receives delta of missed updates
      - holon-3 applies delta and returns to :connected
    And final state should be:
      - All 3 holons connected again
      - Consistent state_hash
      - No data loss or duplication
      - Federation version incremented

  # SC-FED-008: Cross-Holon Query (Read Consistency)
  @sc-fed-008 @query @read_consistency
  Scenario: Queries see consistent data across holons
    When holon-1 publishes version 100 of resource R
    And holon-2 receives replication
    And holon-3 receives replication via relay
    When all holons receive query for R
    Then:
      | Holon | Result | Version | Timestamp |
      | holon-1 | correct | 100 | T1 |
      | holon-2 | correct | 100 | T1 |
      | holon-3 | correct | 100 | T1+50ms |
    And all results should be identical
    And version numbers should match
    And staleness should be acceptable

  # SC-FED-009: Resource Synchronization on Catchup
  @sc-fed-009 @catchup @sync
  Scenario: Node catching up syncs efficiently
    Given holon-2 was offline for 5 minutes
    When holon-2 comes back online
    Then holon-2 should:
      1. Query federation_state from holon-1
      2. Receive delta since last known version
      3. Apply delta atomically
      4. Verify state_hash matches
      5. Mark as synced
    And sync should complete within:
      - Small delta (10 updates): <1 second
      - Medium delta (1000 updates): <10 seconds
      - Large delta (100K updates): <60 seconds
    And holon-2 should not serve reads until synced
    And no data loss or corruption

# ============================================================================
# INTEGRATION TESTS - Cross-Layer Scenarios
# ============================================================================

@integration @cross_layer @e2e
Feature: Integration - End-to-End Zenoh Scenarios
  Complex scenarios spanning multiple layers

  Background:
    Given full Zenoh infrastructure operational
    And all 7 layers initialized
    And monitoring enabled

  # SC-E2E-001: Publish-Subscribe Through All Layers
  @sc-e2e-001 @pubsub @integration
  Scenario: Message flows through all 7 layers correctly
    When Elixir code publishes metric to "indrajaal/metrics/cpu"
    Then message should:
      - L1 FFI: Pass through native NIF
      - L2 Core: Be published via Zenoh session
      - L3 Envelope: Be wrapped in versioned envelope
      - L4 Bridge: Cross Elixir→F# boundary
      - L5 Lifecycle: Confirm connection active
      - L6 Cluster: Be replicated to 2oo3 nodes
      - L7 Federation: Be distributed to federation peers
    And message should reach:
      - Direct subscribers in-process: <1ms
      - Local node subscribers: <5ms
      - Remote cluster nodes: <50ms
      - Federation peers: <100ms
    And message should not be duplicated or lost

  # SC-E2E-002: Failure Recovery Through Layers
  @sc-e2e-002 @resilience @failure_recovery
  Scenario: System recovers from failures across layers
    When component fails at L5 (lifecycle/connection):
      - L1-L4 are unaffected
      - L5 detects failure
      - Reconnection triggers (L5)
      - L6 cluster adjusts
      - L7 federation notified
    Then recovery should:
      1. Restart connection (L5)
      2. Verify health (L5)
      3. Resync cluster state (L6)
      4. Notify federation peers (L7)
      5. Resume message flow
    And total recovery time should be <15 seconds
    And no permanent state should be lost
    And all layers should resume normal operation

  # SC-E2E-003: Load Under Pressure
  @sc-e2e-003 @performance @stress
  Scenario: System handles sustained high message volume
    When publishing 1000 msg/sec for 60 seconds
    Then:
      - L1 NIF should maintain <1% CPU overhead
      - L2 session should not saturate
      - L3 serialization should be <1ms/msg
      - L4 bridge buffer should stay <100ms backlog
      - L5 connection should remain healthy
      - L6 cluster should replicate all messages
      - L7 federation should not lag >100ms
    And no messages should be dropped
    And no memory leaks should occur
    And max latency should stay <50ms

  # SC-E2E-004: Byzantine Failure Handling
  @sc-e2e-004 @byzantine @safety_critical
  Scenario: System survives Byzantine node behavior
    Given holon-2 is malicious and sends:
      - Duplicate messages
      - Out-of-order votes
      - Conflicting state claims
    Then system should:
      1. L6 quorum should ignore conflicting votes
      2. Merkle tree verification should catch duplicates
      3. Version vectors should reject out-of-order
      4. Holon-2 should be marked :untrusted
      5. L7 federation should isolate holon-2
    And service should continue normally
    And no data corruption
    And alert should be generated
    And holon-2 should be quarantined until human review

  # SC-E2E-005: Full System Restart
  @sc-e2e-005 @restart @recovery
  Scenario: System boots and restores from saved state
    Given system has been running with persistent state
    When entire system is shut down
    And restarted cold
    Then:
      - L1 NIFs reload
      - L2 sessions reconnect to routers
      - L3 envelopes deserialize from storage
      - L4 bridge re-establishes
      - L5 lifecycle detects state from disk
      - L6 cluster rejoins quorum
      - L7 federation rejoins peers
    And system should:
      - Report healthy within 30 seconds
      - Recover all non-volatile state
      - Restore all subscriptions
      - Resume message flow
      - Sync with federation peers
    And zero data loss
    And all services operational

# ============================================================================
# SAFETY AND VERIFICATION
# ============================================================================

@safety @verification @formal
Feature: Safety and Formal Verification
  Formal properties that must hold

  # SC-SAFE-001: Safety Property - No Segfaults
  @sc-safe-001 @memory_safety
  Scenario: No segmentation faults under any condition
    When system runs continuous fuzz testing
    With 1 million random inputs per layer
    Then zero segmentation faults
    And zero memory errors (valgrind clean)
    And zero undefined behavior detected

  # SC-SAFE-002: Liveness Property - Message Delivery
  @sc-safe-002 @liveness @delivery
  Scenario: All messages eventually delivered (no deadlock)
    When system publishes message M1
    And subscriber is waiting for M1
    Then within 100ms M1 will be delivered
    And system never enters deadlock state
    And progress is always being made

  # SC-SAFE-003: Consistency Property - ACID
  @sc-safe-003 @consistency @acid
  Scenario: Messages are delivered atomically
    When batch of 100 messages published
    Then subscribers see:
      - All 100 (Atomic)
      - In original order (Consistent)
      - No partial batches (Isolated)
      - Persisted if required (Durable)
    And consistency holds across failure

  # SC-SAFE-004: SIL-6 Compliance
  @sc-safe-004 @sil6 @compliance
  Scenario: System meets SIL-6 safety levels
    Given failure rates:
      | Component | PFH Target | Actual |
      | NIF | <10⁻¹² | <10⁻¹³ |
      | Session | <10⁻¹² | <10⁻¹³ |
      | Quorum | <10⁻¹² | <10⁻¹³ |
    Then overall system PFH < 10⁻¹²
    And dangerous failures < 10⁻¹⁵ per hour
    And warning failures < 10⁻¹² per hour
    And diagnostic coverage > 99%
    And safe failure rate > 99%
