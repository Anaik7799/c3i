# Immutable Register - Append-Only Cryptographic Ledger (Prajna Cockpit)
# STAMP: SC-REG-001 through SC-REG-015 (Register constraints)
# AOR: AOR-REG-001 through AOR-REG-012 (Register operating rules)
# Author: Cybernetic Architect (GEMINI)
# Date: 2026-01-02
# Sprint: 31.2.1
# Priority: P1 (Safety Critical - SIL-4)

@immutable_register @SC-REG @SIL4 @critical
Feature: Immutable Register - Cryptographically Verified Append-Only Ledger
  As the Prajna Cockpit state management layer
  I must maintain an append-only ledger of all state mutations
  So that all changes are cryptographically verified, tamper-evident, and auditable
  And constitutional invariants are preserved throughout system evolution

  Background:
    Given the ImmutableState GenServer is initialized
    And the Ed25519 keypair is generated and loaded
    And the DuckDB persistence layer is active
    And the genesis hash is "0000000000000000000000000000000000000000000000000000000000000000"
    And the protocol version is "21.1.0"
    And the Reed-Solomon codec is RS(255,223) with t=16
    And the chain integrity is verified


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 1: BLOCK APPEND - SC-REG-001, SC-REG-003, SC-REG-006
  # ══════════════════════════════════════════════════════════════════════════════════

  @block_append @SC-REG-001 @critical @AOR-REG-001
  Scenario: Append a single block with cryptographic signature
    Given an empty register with 0 blocks
    And a state change: {change_type: :config_change, module: "Test", key: "param", new_value: 42}
    When the state change is recorded
    Then the block should be appended to the register
    And block_index should be 0
    And block.prev_hash should equal the genesis hash
    And block.timestamp should be recorded (CEST/CET precise)
    And block.signature should be Ed25519 signed (SC-REG-003)
    And block.rs_parity should be generated (SC-REG-006)
    And block should be persisted to DuckDB immediately (SC-REG-001)
    And the block_hash should be computed as SHA3-256(prev_hash|content_hash|index|timestamp)

  @block_append @SC-REG-001 @critical @AOR-REG-001
  Scenario: Append multiple blocks sequentially
    Given an empty register with 0 blocks
    When 5 state changes are recorded in sequence:
      | Change_Type | Module | Key | New_Value |
      | config_change | Guardian | threshold | 0.85 |
      | guardian_decision | Guardian | action_1 | APPROVED |
      | config_change | Sentinel | health_check_interval | 30000 |
      | repair_event | ImmutableState | rs_repair | {block_index: 0} |
      | config_change | PrometheusVerifier | timeout | 5000 |
    Then the register should contain 5 blocks
    And block_0.index should be 0
    And block_1.prev_hash should equal block_0.block_hash
    And block_2.prev_hash should equal block_1.block_hash
    And block_3.prev_hash should equal block_2.block_hash
    And block_4.prev_hash should equal block_3.block_hash
    And all 5 blocks should have Ed25519 signatures (SC-REG-003)
    And all 5 blocks should be persisted to DuckDB (SC-REG-001)

  @block_append @SC-REG-001 @SC-REG-003 @critical
  Scenario: Guardian decision recording
    Given a config_change_pending for "increase_agent_count"
    When Guardian reviews and APPROVES the change
    Then a guardian_decision block should be recorded with:
      | Field | Content |
      | change_type | guardian_decision |
      | action | increase_agent_count |
      | decision | APPROVED |
      | reason | Meets Founder's Directive alignment (Ω₀.1) |
      | timestamp | Current CEST/CET time |
      | signature | Ed25519 signed |
    And the block_hash should form unbroken chain

  @block_append @SC-REG-001 @critical
  Scenario: Cannot append to unverified chain
    Given the register's verified flag is FALSE
    When a state change is attempted to be recorded
    Then the record operation should be REJECTED
    And error should be :chain_not_verified
    And the block should NOT be appended
    And no DuckDB entry should be created


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 2: HASH CHAIN VERIFICATION - SC-REG-002, SC-REG-003
  # ══════════════════════════════════════════════════════════════════════════════════

  @chain_verification @SC-REG-002 @critical @AOR-REG-002
  Scenario: Verify unbroken hash chain on startup
    Given 10 blocks already persisted in DuckDB
    When ImmutableState initializes (startup)
    Then all 10 blocks should be loaded from DuckDB
    And the hash chain should be verified:
      | Check | Constraint |
      | Genesis hash matches | SC-REG-002 |
      | Each block.prev_hash == previous.block_hash | SC-REG-002 |
      | Each block.content_hash verified | SC-REG-002 |
      | Each block.block_hash recomputed and verified | SC-REG-002 |
      | Ed25519 signature verified for each block | SC-REG-003 |
    And state.verified should be set to TRUE
    And telemetry event should be emitted: :chain_verified

  @chain_verification @SC-REG-002 @critical
  Scenario: Detect chain break - prev_hash mismatch
    Given a register with 5 blocks
    And block_2.prev_hash is modified to incorrect value
    When verify_chain() is called
    Then verification should FAIL
    And error should be "{:invalid, "Chain broken at block 2: expected X, got Y"}"
    And state.verified should remain FALSE
    And telemetry should emit: :verification_failed
    And system should HALT before accepting new records (SC-REG-002)

  @chain_verification @SC-REG-002 @critical
  Scenario: Detect chain break - content_hash mismatch
    Given a register with 3 blocks
    And block_1.content is modified (corrupted)
    And block_1.content_hash is NOT updated
    When verify_chain() is called
    Then content_hash verification should FAIL
    And error should indicate block_1 content_hash mismatch
    And chain verification should ABORT at block_1

  @chain_verification @SC-REG-002 @critical
  Scenario: Empty chain is valid
    Given a new register with 0 blocks
    When verify_chain() is called
    Then result should be :valid
    And state.verified should be TRUE

  @chain_verification @SC-REG-002 @critical @AOR-REG-002
  Scenario: Full chain verification on startup (SC-SIL4-003)
    Given 100 blocks in DuckDB (production-scale)
    And verify_on_startup flag is TRUE (SC-SIL4-003)
    When ImmutableState.init() is called
    Then all 100 blocks should be verified in sequence
    And each block signature verified (SC-REG-003)
    And no gaps in block indices
    And chain integrity verified within 5 seconds (SC-PROM-005)
    And telemetry should log: blocks_verified=100, verification_time_ms=X


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 3: TAMPERING DETECTION - Block Integrity
  # ══════════════════════════════════════════════════════════════════════════════════

  @tampering_detection @critical @security
  Scenario: Detect tampering - block_hash modified
    Given a valid block with block_hash = ABC123
    When block_hash is modified to XYZ789
    And verify_chain() is called
    Then block_hash verification should FAIL
    And error should indicate block_hash recompute mismatch
    And tampering detection should be logged
    And system should HALT (SC-REG-002)

  @tampering_detection @critical @security
  Scenario: Detect tampering - signature forged
    Given a valid block with Ed25519 signature
    When block.signature is replaced with forged signature
    And verify_block_signature() is called
    Then signature verification should FAIL
    And error should include "Ed25519 signature invalid (SC-REG-003)"
    And system should mark chain as UNVERIFIED
    And Guardian should be notified

  @tampering_detection @critical @security
  Scenario: Detect tampering - content modified
    Given a guardian_decision block
    And block.content.decision = "APPROVED"
    When adversary modifies block.content.decision to "REJECTED"
    And content_hash is NOT recalculated
    Then verify_chain() should detect mismatch
    And error should indicate content integrity violation
    And tampered block should be REJECTED

  @tampering_detection @critical @security
  Scenario: Detect tampering - prev_hash broken
    Given blocks in sequence: [Block0, Block1, Block2, Block3]
    When Block1.prev_hash is modified (severing link to Block0)
    And verify_chain() is called
    Then verification should FAIL at Block1
    And Block2 and Block3 cannot be verified (chain broken)
    And entire tail becomes UNVERIFIED


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 4: ED25519 SIGNATURES - SC-REG-003
  # ══════════════════════════════════════════════════════════════════════════════════

  @ed25519_signatures @SC-REG-003 @critical
  Scenario: All blocks signed with Ed25519
    Given 5 blocks in the register
    When examining each block
    Then each block should have:
      | Field | Type | Size | Constraint |
      | signature | Base64-encoded | 88 chars | SC-REG-003 |
      | keypair | {pub_key, secret_key} | {32, 32} bytes | Generated by :crypto |
      | public_key | Ed25519 public key | 32 bytes | Derived from keypair |
    And all signatures should be verifiable against public_key
    And no block should have signature = null

  @ed25519_signatures @SC-REG-003 @critical
  Scenario: Keypair persistence
    Given ImmutableState initialized with new keypair
    When keypair is generated
    Then it should be saved to file: data/holons/prajna_keypair.bin
    And file should contain {:erlang.term_to_binary({pub, sec})}
    And on next startup, same keypair should be loaded
    And public_key should remain constant across restarts

  @ed25519_signatures @SC-REG-003 @critical
  Scenario: Signature verification on chain load
    Given 10 blocks persisted in DuckDB
    When ImmutableState starts and loads blocks
    Then signature verification should be called for each block
    And public_key should match stored keypair
    And invalid signatures should FAIL chain verification
    And chain loading should ABORT if any signature invalid


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 5: REED-SOLOMON ERROR CORRECTION - SC-REG-006, SC-REG-008
  # ══════════════════════════════════════════════════════════════════════════════════

  @reed_solomon @SC-REG-006 @critical @AOR-REG-009
  Scenario: Generate Reed-Solomon parity for new block
    Given a block with binary data: "test_block_content"
    When the block is created
    Then Reed-Solomon parity should be generated:
      | Parameter | Value | Constraint |
      | n (total symbols) | 255 | RS(255,223) |
      | k (data symbols) | 223 | SC-REG-006 |
      | parity symbols | 32 | t = 16 error correction |
      | implementation | Layered checksums | Multiple redundancy |
    And parity should include:
      | Layer | Description |
      | Layer 1 | CRC-32 of full data |
      | Layer 2 | CRC-32 of each chunk |
      | Layer 3 | SHA-256 content hash |
      | Layer 4 | XOR position check |
    And block.rs_parity should be stored in DuckDB (SC-REG-006)

  @reed_solomon @SC-REG-006 @critical
  Scenario: Verify block integrity with Reed-Solomon parity
    Given a block with rs_parity
    When verify_block_rs(block) is called
    Then parity verification should check:
      | Check | Constraint |
      | CRC-32 matches | Data integrity |
      | Size matches stored | SC-REG-006 |
      | SHA-256 matches | Content verification |
      | XOR check matches | Position integrity |
      | Chunk CRCs match | Localized corruption detection |
    And result should be :ok if all checks pass
    And telemetry should be emitted: :rs_verification

  @reed_solomon @SC-REG-006 @critical
  Scenario: Detect corrupted block with Reed-Solomon
    Given a valid block with rs_parity
    And the block data is corrupted (16 bytes flipped)
    When verify_block_rs(block) is called
    Then parity check should FAIL
    And error should identify error type:
      | Error Type | Detection |
      | CRC mismatch | Layer 1 check |
      | Size mismatch | Layer 1 check |
      | SHA mismatch | Layer 3 check |
      | XOR mismatch | Layer 4 check |
      | Chunk error | Layer 2 check |
    And system should attempt repair (SC-REG-008)

  @reed_solomon @SC-REG-006 @critical @AOR-REG-009
  Scenario: Attempt repair using Reed-Solomon parity
    Given a corrupted block with repairable error count <= 16
    When attempt_repair(block, parity, error_info) is called
    Then repair algorithm should:
      | Step | Action |
      | 1 | Identify error type (chunk vs global) |
      | 2 | If chunk errors only, attempt localized repair |
      | 3 | Log repair attempt to telemetry |
      | 4 | Return {:repaired, fixed_data, repair_info} if successful |
      | 5 | Return {:error, :unrepairable} if exceeds correction capability |
    And repair_info should contain:
      | Field | Content |
      | original_error_count | Number of errors detected |
      | repair_method | Algorithm used |
      | timestamp | When repair occurred |
      | constraint | "SC-REG-006" |

  @reed_solomon @SC-REG-006 @critical
  Scenario: Unrepairable corruption exceeds correction capability
    Given a block with 20 byte errors (exceeds t=16)
    When verify_block_rs(block) is called
    Then parity check should FAIL
    And attempt_repair should return {:error, :unrepairable}
    And block should be marked CORRUPT
    And system should HALT recovery and require manual intervention
    And error details should be logged for forensics


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 6: REPAIR EVENT LOGGING - SC-REG-008
  # ══════════════════════════════════════════════════════════════════════════════════

  @repair_events @SC-REG-008 @AOR-REG-008
  Scenario: Record repair event when block is repaired
    Given a corrupted block_3 that is successfully repaired
    When repair is completed
    Then a repair_event block should be appended to register
    And repair_event should contain:
      | Field | Content |
      | change_type | repair_event |
      | repaired_block_index | 3 |
      | repair_info | {method, timestamp} |
      | metadata.constraint | "SC-REG-008" |
      | signature | Ed25519 signed |
    And repair_event should be persisted to DuckDB
    And repair_event should form part of hash chain

  @repair_events @SC-REG-008 @critical @AOR-REG-008
  Scenario: Chain verification with repair with Reed-Solomon
    Given a register with 5 blocks
    And block_2 is corrupted but repairable
    When verify_chain_with_repair(state) is called
    Then:
      | Step | Action | Constraint |
      | 1 | Load all blocks | SC-REG-002 |
      | 2 | Verify each block with RS parity | SC-REG-006 |
      | 3 | Detect corruption in block_2 | SC-REG-006 |
      | 4 | Attempt repair using parity | SC-REG-006 |
      | 5 | Record repair event | SC-REG-008 |
      | 6 | Verify repaired block | SC-REG-002 |
      | 7 | Re-verify chain integrity | SC-REG-002 |
    And return {:ok, state_with_repairs} if successful
    And telemetry should show repair_count, blocks_verified, repairs_made

  @repair_events @SC-REG-008 @AOR-REG-008
  Scenario: Complete audit trail of all repairs
    Given multiple repair events over time
    When retrieving repair history
    Then get_blocks_by_type(:repair_event) should return all repairs
    And each repair_event should contain:
      | Field | Type |
      | timestamp | DateTime |
      | repaired_block_index | Integer |
      | repair_info | Map |
      | index | Sequential |
    And repair events should be immutable (append-only)
    And repair history should be auditable and tamper-evident


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 7: DUCKDB PERSISTENCE - SC-REG-001, SC-REG-007, SC-HOLON-019
  # ══════════════════════════════════════════════════════════════════════════════════

  @duckdb_persistence @SC-REG-001 @critical @AOR-REG-001
  Scenario: Blocks persisted to DuckDB immediately
    Given an empty register
    When a state change is recorded
    Then block should be:
      | Action | Timing |
      | Created in memory | Instant |
      | Persisted to DuckDB | Before return |
      | Persisted to disk | DuckDB fsync |
    And DuckDB should contain table: prajna_immutable_blocks
    And block fields should map:
      | Field | DuckDB Column | Type |
      | index | block_index | INTEGER PRIMARY KEY |
      | timestamp | timestamp | TIMESTAMP |
      | prev_hash | prev_hash | VARCHAR(64) |
      | content_hash | content_hash | VARCHAR(64) |
      | block_hash | block_hash | VARCHAR(64) |
      | signature | signature | VARCHAR(128) |
      | content | content | JSON |
      | protocol_version | protocol_version | VARCHAR(20) |
      | rs_parity | rs_parity | BLOB |

  @duckdb_persistence @SC-REG-001 @critical @AOR-REG-001
  Scenario: Load blocks from DuckDB on startup
    Given 50 blocks persisted in DuckDB
    When ImmutableState initializes
    Then blocks should be loaded in order:
      | Action | Constraint |
      | Query DuckDB ordered by block_index ASC | SC-REG-001 |
      | Parse each row to block struct | SC-REG-001 |
      | Reconstruct chain metadata | SC-REG-002 |
      | Rebuild state.blocks | SC-REG-001 |
    And all 50 blocks should be in memory
    And last_index should be 49
    And last_hash should match block_49.block_hash

  @duckdb_persistence @SC-HOLON-019 @critical
  Scenario: DuckDB history is append-only, no updates
    Given blocks in DuckDB
    When attempting to UPDATE any existing block
    Then operation should be REJECTED (DuckDB design)
    And no DELETE operations should be permitted on register table
    And only INSERT is allowed
    And immutability constraint SC-HOLON-019 is enforced by schema

  @duckdb_persistence @critical
  Scenario: DuckDB schema migration for rs_parity column
    Given legacy blocks without rs_parity column
    When ImmutableState initializes
    Then ensure_parity_column() should:
      | Step | Action |
      | 1 | Check if rs_parity column exists |
      | 2 | If missing, ALTER TABLE ADD COLUMN |
      | 3 | Set rs_parity=NULL for legacy blocks |
      | 4 | New blocks have rs_parity generated |
    And schema migration should NOT break existing blocks
    And index should be created if missing


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 8: STATE QUERIES & ANALYSIS - SC-REG-001
  # ══════════════════════════════════════════════════════════════════════════════════

  @state_queries @SC-REG-001 @critical
  Scenario: Get block by index
    Given a register with 10 blocks
    When calling get_block(5)
    Then should return:
      | Field | Value |
      | index | 5 |
      | timestamp | DateTime |
      | block_hash | Valid SHA3-256 |
      | signature | Valid Ed25519 |
      | content | Original change_type |

  @state_queries @SC-REG-001 @critical
  Scenario: Get blocks by change type
    Given a register with mixed block types:
      | Type | Count |
      | config_change | 30 |
      | guardian_decision | 15 |
      | repair_event | 5 |
      | audit_event | 10 |
    When calling get_blocks_by_type(:guardian_decision)
    Then should return 15 blocks
    And all blocks should have content.change_type == :guardian_decision
    And blocks should be in chronological order

  @state_queries @critical
  Scenario: Compute Merkle root for state verification
    Given a register with 20 blocks
    When compute_merkle_root() is called
    Then should:
      | Step | Action |
      | 1 | Collect all content_hashes |
      | 2 | Build balanced binary tree |
      | 3 | Hash pairs recursively |
      | 4 | Return single root hash |
    And root should be deterministic (same input = same root)
    And used for SC-REG-011 Merkle proofs


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 9: IMMUTABLE REGISTER CORE (SC-REG-004, SC-REG-005)
  # ══════════════════════════════════════════════════════════════════════════════════

  @immutability @SC-REG-004 @SC-REG-005 @critical @AOR-REG-003 @AOR-REG-004
  Scenario: No UPDATE operations on immutable blocks
    Given a block in the register
    When attempting block.content UPDATE
    Then operation should be REJECTED
    And error should be clear: "Immutable blocks cannot be updated (SC-REG-004)"
    And only append-only INSERT is allowed
    And DuckDB schema prevents UPDATE via PRIMARY KEY

  @immutability @SC-REG-005 @critical
  Scenario: No DELETE operations on immutable blocks
    Given blocks in the register
    When attempting DELETE block WHERE index=5
    Then operation should be REJECTED
    And error should be: "Immutable blocks cannot be deleted (SC-REG-005)"
    And blocks are permanent record
    And audit trail is complete and unalterable

  @immutability @critical
  Scenario: Blocks are cryptographically immutable
    Given block_3 in the register
    When attempting to modify block_3.content
    Then:
      | Impact | Constraint |
      | block_3.content_hash changes | Detected by verify_chain |
      | block_3.block_hash invalidates | Detected by verify_chain |
      | block_4.prev_hash no longer matches | Chain breaks |
      | Entire tail becomes unverifiable | SC-REG-002 failure |
    And cryptographic binding enforces immutability


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 10: CROSS-HOLON FEDERATION - SC-REG-013
  # ══════════════════════════════════════════════════════════════════════════════════

  @federation @SC-REG-013 @high
  Scenario: Cross-holon attestation for federation
    Given ImmutableState with complete block chain
    When sync_to_register(block) is called
    Then should:
      | Step | Action |
      | 1 | Format block for core ImmutableRegister |
      | 2 | Include prajna_block_hash, index, content_type, signature |
      | 3 | Append to core register (if available) |
      | 4 | Return {:ok, block_hash} on success |
      | 5 | Return {:ok, :skipped} if register not running |
    And federation peers can verify Prajna blocks via core register

  @federation @SC-REG-013 @high
  Scenario: Attest with core ImmutableRegister
    Given multiple holons with Immutable Registers
    When attest_with_register() is called (SC-REG-013)
    Then should:
      | Data | Source |
      | our_head (last_hash) | Prajna ImmutableState |
      | register_head | Core ImmutableRegister |
      | register_pubkey | Core keypair |
      | attestation | Cryptographic proof |
      | timestamp | UTC time |
    And attestation enables federation trust verification


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 11: COMPLIANCE & VERIFICATION
  # ══════════════════════════════════════════════════════════════════════════════════

  @compliance @SC-REG @critical @SIL4
  Scenario: SC-REG compliance verification
    Given ImmutableState fully initialized
    When running compliance check
    Then all constraints should be satisfied:
      | ID | Constraint | Status | Check |
      | SC-REG-001 | All state changes via append-only register | ✓ | insert_only |
      | SC-REG-002 | Hash chain unbroken | ✓ | verify_chain |
      | SC-REG-003 | All blocks Ed25519 signed | ✓ | signatures_valid |
      | SC-REG-004 | Blocks are immutable (no UPDATE) | ✓ | schema_enforces |
      | SC-REG-005 | Blocks cannot be deleted | ✓ | schema_enforces |
      | SC-REG-006 | Reed-Solomon parity required | ✓ | rs_parity_stored |
      | SC-REG-007 | Verify before trust | ✓ | chain_verification |
      | SC-REG-008 | Repair events recorded | ✓ | repair_blocks_logged |
      | SC-REG-013 | Cross-holon attestation | ✓ | attest_with_register |
      | SC-REG-015 | Capability tokens unforgeable | ✓ | Ed25519_signature |

  @compliance @SIL4 @critical
  Scenario: SIL-4 Resilience - Prajna ImmutableState
    Given the safety requirements for SIL-4 (ISO 61508 Level 4)
    Then ImmutableState must satisfy:
      | Requirement | Implementation | Constraint |
      | Chain verification on startup | Full cryptographic check | SC-SIL4-003 |
      | Persistent storage | DuckDB + fsync | SC-SIL4-002 |
      | Error detection | RS(255,223) parity | SC-REG-006 |
      | Repair capability | Automated RS repair | SC-REG-006 |
      | Audit trail | Complete block history | SC-REG-001 |
      | Tamper detection | Ed25519 signatures | SC-REG-003 |
      | Recovery path | Regenerate from DuckDB | SC-REG-007 |

  @compliance @certification
  Scenario: Immutable Register capability checklist
    Given new deployment of Indrajaal Prajna
    When validating capability deployment
    Then operator should verify:
      | Capability | Validation |
      | Append-only ledger | Check DuckDB insert-only schema |
      | Cryptographic signing | Verify Ed25519 keypair exists |
      | Hash chain integrity | Call verify_chain(), expect :valid |
      | Parity generation | Create new block, check rs_parity NOT NULL |
      | Block persistence | Confirm DuckDB file created |
      | Chain verification on startup | Restart and check state.verified==true |
      | Repair functionality | Inject error and test repair path |
      | Cross-holon attestation | Verify sync_to_register works |


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 12: ERROR SCENARIOS & RECOVERY
  # ══════════════════════════════════════════════════════════════════════════════════

  @error_recovery @critical
  Scenario: Recover from DuckDB connection failure
    Given ImmutableState initialized with active DuckDB
    When DuckDB connection is lost
    And a new state_change is recorded
    Then record operation should:
      | Action | Result |
      | Attempt to persist | Fails (conn lost) |
      | Emit telemetry: persist_failed | Logged |
      | Return {:error, :persist_failed} | Client notified |
      | Retain block in memory (not appended) | Transient state |
    And on reconnection, retry persistence
    And block should eventually reach DuckDB

  @error_recovery @critical
  Scenario: Handle corrupted DuckDB file
    Given DuckDB file is corrupted
    When ImmutableState tries to initialize
    Then:
      | Step | Action |
      | 1 | Attempt to open DuckDB | Fails |
      | 2 | Log error: "DuckDB open failed" | Logged |
      | 3 | Return {:error, {:duckdb_open_failed, reason}} | Caller sees error |
      | 4 | Supervisor should attempt restart | Restart logic |
      | 5 | Manual intervention required | Operational alert |
    And corrupted DB should be backed up
    And recovery procedure should be documented

  @error_recovery @critical @AOR-REG-004
  Scenario: Halt on constitutional violation
    Given an operation that would violate constitutional invariants
    When validation detects violation (Ψ₀-Ψ₅)
    Then:
      | Step | Action | Constraint |
      | 1 | Reject operation | AOR-CONST-001 |
      | 2 | Log as CRITICAL | AOR-CONST-002 |
      | 3 | Halt execution | AOR-CONST-002 |
      | 4 | Notify Guardian | AOR-CONST-003 |
      | 5 | Rollback any partial changes | Atomic |
    And system should NOT continue normal operation


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 13: PERFORMANCE & SCALABILITY
  # ══════════════════════════════════════════════════════════════════════════════════

  @performance @high
  Scenario: Record 1000 blocks within latency budget
    Given empty register
    When recording 1000 state changes in rapid succession
    Then:
      | Metric | Target | Constraint |
      | Per-block latency | < 5ms | SC-PROM-005 |
      | Total time | < 5 seconds | Scalability |
      | DuckDB writes | Batched or async | Performance |
      | Ed25519 signing | 64-bit ops | Fast crypto |
      | RS parity generation | < 1ms per block | Practical |
    And telemetry should show performance metrics

  @performance @high
  Scenario: Load 10000 blocks from DuckDB at startup
    Given 10,000 blocks persisted in DuckDB
    When initializing ImmutableState
    Then:
      | Task | Target | Constraint |
      | Load blocks from DuckDB | < 2 seconds | SC-PROM-005 |
      | Parse JSON content | < 100ms | Parsing |
      | Build in-memory index | < 500ms | Indexing |
      | Verify chain integrity | < 5 seconds | SC-SIL4-003 |
      | Total startup | < 10 seconds | Operational |
    And state should be ready for operation


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 14: INTEGRATION & END-TO-END
  # ══════════════════════════════════════════════════════════════════════════════════

  @integration @E2E @critical
  Scenario: Complete workflow - Guardian decision recorded and verified
    Given the Prajna Cockpit is running
    And ImmutableState is initialized
    When a Guardian decision is made:
      | Step | Action |
      | 1 | User requests resource allocation change |
      | 2 | Prajna generates recommendation |
      | 3 | Guardian reviews and approves |
      | 4 | Decision state change is prepared |
    Then complete workflow:
      | Step | Action | Verification |
      | 1 | Record guardian_decision block | Block appended |
      | 2 | Ed25519 sign the block | Signature valid |
      | 3 | Generate RS parity | Parity not null |
      | 4 | Persist to DuckDB | Row inserted |
      | 5 | Verify hash chain | Chain valid |
      | 6 | Emit telemetry | Events logged |
      | 7 | Notify other Prajna components | Distributed knowledge |
    And entire decision history is cryptographically auditable

  @integration @E2E @critical
  Scenario: System recovery from unclean shutdown
    Given Prajna running with 100 blocks in register
    When system crashes during block append (at step: persist to DuckDB)
    And system restarts
    Then recovery:
      | Step | Action | Result |
      | 1 | Load blocks from DuckDB | 99 blocks (incomplete) |
      | 2 | Verify chain integrity | :valid (chain unbroken) |
      | 3 | Last attempted block lost | Lost (not persisted) |
      | 4 | No data corruption | Cryptography ensured |
      | 5 | Resume operations | Ready to accept new records |
    And durability is achieved through DuckDB fsync
    And consistency through cryptographic verification
    And no phantom blocks


  # ══════════════════════════════════════════════════════════════════════════════════
  # SECTION 15: AUDIT & FORENSICS
  # ══════════════════════════════════════════════════════════════════════════════════

  @audit @forensics
  Scenario: Complete audit trail for security investigation
    Given a security incident involving Prajna state changes
    When forensic investigation begins
    Then auditor can retrieve:
      | Query | Results |
      | get_blocks_by_type(:guardian_decision) | All approval decisions |
      | get_blocks_by_type(:repair_event) | All repairs |
      | compute_merkle_root() | State verification proof |
      | verify_chain() | Integrity status |
      | get_block(N) | Specific block details |
    And each block includes:
      | Field | Forensic Value |
      | timestamp | When change occurred |
      | signature | Who authorized it |
      | content | What changed |
      | prev_hash | Chain position |
    And immutability ensures evidence cannot be altered

  @audit
  Scenario: Export register for external audit
    Given a complete register with 500 blocks
    When export_register() is called
    Then should produce:
      | Format | Content |
      | JSON | All blocks with metadata |
      | CSV | Tabular summary for analysis |
      | Hash summary | Merkle root + key hashes |
    And export should include:
      | Item | Purpose |
      | Public key | Signature verification |
      | Genesis hash | Chain validation |
      | Merkle root | State proof |
      | Repair history | RS operation audit |
    And auditor can independently verify chain in external tool
